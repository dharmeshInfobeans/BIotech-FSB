import { LightningElement } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import headerFixCss from '@salesforce/resourceUrl/prospectAllocationHeaderFix';
import getProspects from '@salesforce/apex/ProspectAllocationController.getProspects';
import getCityWiseMappings from '@salesforce/apex/ProspectAllocationController.getCityWiseMappings';
import getFilterOptions from '@salesforce/apex/ProspectAllocationController.getFilterOptions';
import saveAllocations from '@salesforce/apex/ProspectAllocationController.saveAllocations';
import getCurrentUserEditPermissions from '@salesforce/apex/ProspectAllocationController.getCurrentUserEditPermissions';

const NO_MATCH_LABEL = 'No mapped user';
const PAGE_SIZE = 50;
const FILTER_DEBOUNCE_MS = 400;

// The real business hierarchy, most specific to broadest: City -> State ->
// Zone -> Country -> Vertical, matching LeadsProductGroupHandler's own
// waterfall (see Apex). Owner/RSM/ZSM/NSM/GSRO each sit at exactly one tier
// (Owner=City, RSM=State, ZSM=Zone, NSM=Country, GSRO=Vertical). The FIRST
// tier, starting from City, that has ANY matching CityWise__c row for a given
// Prospect wins outright and supplies every role listed here at or above it -
// there is no merging across tiers, so e.g. a Zone-level match never mixes in
// a role that happened to be on some other Country-level row.
const TIER_ROLES = {
    city: ['owner', 'rsm', 'zsm', 'nsm', 'gsro'],
    state: ['rsm', 'zsm', 'nsm', 'gsro'],
    zone: ['zsm', 'nsm', 'gsro'],
    country: ['nsm', 'gsro'],
    vertical: ['gsro']
};
// All 5 roles, in the same hierarchy order used above (low to high). Owner
// behaves exactly like the other four here - its own "saved value" (OwnerId)
// is simply never blank on a real Lead, so it always resolves without needing
// special-casing.
const ALL_ROLES = ['owner', 'rsm', 'zsm', 'nsm', 'gsro'];
// LeadsProductGroupHandler's State tier is a documented quirk: it does NOT
// require the CityWise row's own Division to match - it only requires the
// Prospect's Division be one of these three (PHAKIC/TRIO are excluded from
// ever falling back to State). Kept isolated here rather than folded into a
// general rule, since every other tier DOES require an exact Division match.
const STATE_TIER_DIVISIONS = ['GT', 'COH', 'ORTHO'];

const ID_FIELD = { rsm: 'RSM__c', zsm: 'ZSM__c', nsm: 'NSM__c', gsro: 'GSRO__c', owner: 'District_Level__c' };
const REL_FIELD = { rsm: 'RSM__r', zsm: 'ZSM__r', nsm: 'NSM__r', gsro: 'GSRO__r', owner: 'District_Level__r' };
const FIELD_API = { rsm: 'RSM_New__c', zsm: 'ZSM_New__c', nsm: 'NSM_New__c', gsro: 'GSRO_New__c', owner: 'OwnerId' };
const ROLE_LABEL = { rsm: 'RSM', zsm: 'ZSM', nsm: 'NSM', gsro: 'GSRO', owner: 'Owner' };
// The Lead__c-side relationship for each already-saved value's display name
// (distinct from REL_FIELD, which is CityWise__c's own relationship names).
const LEAD_REL_FIELD = { rsm: 'RSM_New__r', zsm: 'ZSM_New__r', nsm: 'NSM_New__r', gsro: 'GSRO_New__r' };

// A saved value on the Lead is always a real assignment and must always be
// shown correctly - even when it's no longer (or never was) one of the
// tier-matched candidates - otherwise the combobox has no label for it
// and silently falls back to the "no mapped user" placeholder, which reads as
// "nobody is assigned" when someone actually is.
function ensureSavedValueIsAnOption(options, savedValue, savedName) {
    if (!savedValue || options.some((o) => o.value === savedValue)) {
        return options;
    }
    return [...options, { label: savedName || savedValue, value: savedValue }];
}

// CityWise__c disambiguates several rows for the same place with a trailing
// suffix - parenthetical on City__c ("AHMEDABAD(1)", "AHMEDABAD(2)") or
// "-<number>" on State__c ("Gujarat-1", "Gujarat-2") - while the Prospect's
// own field just holds the plain name. Stripping both suffix styles means
// both sides compare on the same base name, so every disambiguated row still
// surfaces as a candidate instead of the match silently coming back empty.
function stripSuffix(value) {
    if (!value) {
        return '';
    }
    return value
        .trim()
        .toUpperCase()
        .replace(/\s*\([^)]*\)\s*$/, '')
        .replace(/-\s*\d+\s*$/, '');
}

// Country needs a different fix: CityWise__c mixes ISO codes ("IN") and full
// names ("INDIA") for the very same country, while the Prospect always stores
// the picklist's code. countryNormalizeMap (built from the Country__c
// picklist itself - see loadFilterOptions) maps EITHER spelling to the same
// canonical code, so "IN" and "INDIA" are recognized as equal.
function normalizeCountry(value, countryNormalizeMap) {
    const key = stripSuffix(value);
    if (!key) {
        return '';
    }
    return (countryNormalizeMap && countryNormalizeMap.get(key)) || key;
}

// Finds the single most specific tier (City -> State -> Zone -> Country ->
// Vertical) that has at least one matching CityWise__c row for this
// Prospect's own City/State/Zone/Country/Vertical + Division, and returns
// ONLY that tier's rows - mirroring LeadsProductGroupHandler, which never
// merges roles from two different tiers onto the same Prospect.
function resolveTier(mappings, criteria, countryNormalizeMap) {
    const { city, state, zone, country, vertical, division } = criteria;
    const nCity = stripSuffix(city);
    const nState = stripSuffix(state);
    const nZone = stripSuffix(zone);
    const nCountry = normalizeCountry(country, countryNormalizeMap);
    const nVertical = stripSuffix(vertical);

    if (nCity) {
        const rows = mappings.filter((m) => stripSuffix(m.City__c) === nCity && m.Division__c === division);
        if (rows.length) {
            return { tier: 'city', rows };
        }
    }
    if (nState && STATE_TIER_DIVISIONS.includes(division)) {
        const rows = mappings.filter((m) => stripSuffix(m.State__c) === nState);
        if (rows.length) {
            return { tier: 'state', rows };
        }
    }
    if (nZone) {
        const rows = mappings.filter((m) => stripSuffix(m.Zone__c) === nZone && m.Division__c === division);
        if (rows.length) {
            return { tier: 'zone', rows };
        }
    }
    if (nCountry) {
        const rows = mappings.filter(
            (m) => normalizeCountry(m.Country__c, countryNormalizeMap) === nCountry && m.Division__c === division
        );
        if (rows.length) {
            return { tier: 'country', rows };
        }
    }
    if (nVertical) {
        const rows = mappings.filter((m) => stripSuffix(m.Vertical_Code__c) === nVertical && m.Division__c === division);
        if (rows.length) {
            return { tier: 'vertical', rows };
        }
    }
    return { tier: null, rows: [] };
}

// Distinct candidates for one role, drawn from an already tier-scoped row
// pool (see resolveTier). Every eligible role at a given tier shares this
// SAME pool, which is what keeps an RSM/ZSM pairing honest - they can only
// ever come from rows that also matched this Prospect's own geography and
// Division, never an arbitrary independent match.
function distinctOptions(rows, role) {
    const byId = new Map();
    rows.forEach((r) => {
        const id = r[ID_FIELD[role]];
        if (id) {
            byId.set(id, r[REL_FIELD[role]] ? r[REL_FIELD[role]].Name : id);
        }
    });
    return Array.from(byId.entries()).map(([value, label]) => ({ label, value }));
}

// Once a role within the tier's eligible set is known (manual pick, saved
// server value, or auto-selected because it was the only candidate), find the
// ONE row in the SAME tier pool that actually produced it and pull every
// eligible role ABOVE it (eligibleRoles is already in hierarchy order) from
// that same row - injecting a synthetic option into that role's own list if
// its own distinct-candidates pass didn't happen to include it. Never fills a
// role at or below the known one, and never overwrites a role that already
// has a value.
function deriveFromMatchingRow(rows, eligibleRoles, values, sources, optionsByRole) {
    eligibleRoles.forEach((known, knownIdx) => {
        const knownValue = values[known];
        if (!knownValue) {
            return;
        }
        const matchRow = rows.find((r) => r[ID_FIELD[known]] === knownValue);
        if (!matchRow) {
            return;
        }
        eligibleRoles.forEach((target, targetIdx) => {
            if (targetIdx <= knownIdx || values[target]) {
                return;
            }
            const targetValue = matchRow[ID_FIELD[target]];
            if (targetValue) {
                values[target] = targetValue;
                sources[target] = 'auto';
                if (optionsByRole) {
                    const label = matchRow[REL_FIELD[target]] ? matchRow[REL_FIELD[target]].Name : null;
                    optionsByRole[target] = ensureSavedValueIsAnOption(optionsByRole[target], targetValue, label);
                }
            }
        });
    });
}

export default class ProspectAllocation extends LightningElement {
    rows = [];
    loading = true;
    totalCount = 0;

    // pageCursors[i] is the "afterId" used to fetch page i (0-indexed); pageCursors[0] is null.
    pageCursors = [null];
    currentPage = 0;
    hasNextPage = false;

    mappings = [];

    allCityOptions = [];
    allStateOptions = [];
    zoneOptions = [];
    countryOptions = [];
    verticalOptions = [];
    assignmentStageOptions = [];
    campaignOptions = [];

    // City -> State, City -> Country, State -> Country, built from the
    // distinct City/State/Country combinations actually in use, so picking a
    // City can auto-fill State+Country and picking a State can auto-fill
    // Country - and the City list itself can narrow to the picked State.
    // Country values in these maps (and in filterCountry) are always the
    // friendly LABEL (e.g. "INDIA") - see countryLabelToValue below for why.
    cityToState = new Map();
    cityToCountry = new Map();
    stateToCountry = new Map();

    // c-searchable-combobox displays whatever it's given as its "value" once
    // an option is picked (not the option's label) - so for Country, the
    // combobox's own value/options are keyed by LABEL ("INDIA") purely for
    // correct display, and this map translates back to the real picklist API
    // value ("IN") only at the moment a request is actually sent to Apex.
    countryLabelToValue = new Map();

    // Matching (not display) uses this one instead: maps EITHER the picklist
    // code ("IN") or its label ("INDIA") - both uppercased - to the same
    // canonical code, since CityWise__c mixes both spellings for the same
    // country. See normalizeCountry.
    countryNormalizeMap = new Map();

    // Same reasoning as Country above: the combobox's value/options are keyed
    // by campaign NAME for correct display, translated back to the actual
    // Campaign__c Id(s) only when a request is sent to Apex. Campaign names
    // aren't unique - CampaignTriggerHelper auto-generates them from
    // date/zone/city/country, so several distinct Campaign__c records can
    // share one visible name - so a name maps to EVERY Id sharing it, and
    // Apex matches with an IN clause rather than equality.
    campaignNameToIds = new Map();

    filterCity = '';
    filterState = '';
    filterZone = '';
    filterCountry = '';
    filterVertical = '';
    filterAssignmentStage = '';
    filterCampaign = '';

    pendingChanges = new Map();

    // Bumped on every loadPage() call; a response is only applied if it's
    // still the most recent request, so an in-flight initial/unfiltered load
    // can never clobber a later filtered one that resolves first.
    loadRequestId = 0;

    // Filters auto-apply after a short pause instead of requiring an Apply
    // button click - each filter change (re)schedules this timer.
    filterDebounceTimer = null;

    // Which of the 5 role fields the logged-in user may edit, based on their
    // Role Hierarchy tier (see ProspectAllocationController.getCurrentUserEditPermissions).
    // Defaults to no edit access at all until the real permissions load.
    editPermissions = { owner: false, rsm: false, zsm: false, nsm: false, gsro: false };

    async connectedCallback() {
        loadStyle(this, headerFixCss).catch(() => {
            // Non-critical cosmetic fix - if it fails to load, the page header just stays visible.
        });
        await Promise.all([this.loadMappings(), this.loadFilterOptions(), this.loadEditPermissions()]);
        await this.loadPage(0);
    }

    async loadEditPermissions() {
        try {
            const perms = await getCurrentUserEditPermissions();
            this.editPermissions = {
                owner: perms.canEditOwner,
                rsm: perms.canEditRsm,
                zsm: perms.canEditZsm,
                nsm: perms.canEditNsm,
                gsro: perms.canEditGsro
            };
        } catch (error) {
            this.notify('Error loading edit permissions', this.errorMessage(error), 'error');
        }
    }

    async loadMappings() {
        try {
            this.mappings = await getCityWiseMappings();
        } catch (error) {
            this.notify('Error loading CityWise mappings', this.errorMessage(error), 'error');
        }
    }

    async loadFilterOptions() {
        try {
            const options = await getFilterOptions();
            this.allCityOptions = options.cities.map((v) => ({ label: v, value: v }));
            this.allStateOptions = options.states.map((v) => ({ label: v, value: v }));
            this.zoneOptions = options.zones.map((v) => ({ label: v, value: v }));
            this.verticalOptions = options.verticals.map((v) => ({ label: v, value: v }));
            this.assignmentStageOptions = options.assignmentStages.map((v) => ({ label: v, value: v }));

            // Campaign: value is the NAME (so the combobox displays it
            // correctly once picked), and campaignNameToIds translates back to
            // every Campaign__c Id sharing that name only when calling Apex.
            const campaignNameToIds = new Map();
            options.campaigns.forEach((c) => {
                if (!campaignNameToIds.has(c.name)) {
                    campaignNameToIds.set(c.name, []);
                }
                campaignNameToIds.get(c.name).push(c.id);
            });
            // Dedupe by name so a name shared by several Ids only appears once in the dropdown.
            this.campaignOptions = Array.from(campaignNameToIds.keys()).map((name) => ({ label: name, value: name }));
            this.campaignNameToIds = campaignNameToIds;

            // Country: value is the LABEL (so the combobox displays it
            // correctly once picked), and countryLabelToValue translates back
            // to the real picklist API value only when calling Apex.
            const countryLabelToValue = new Map();
            const countryValueToLabel = new Map();
            options.countryOptions.forEach((o) => {
                countryLabelToValue.set(o.label, o.value);
                countryValueToLabel.set(o.value, o.label);
            });
            this.countryOptions = options.countryOptions.map((o) => ({ label: o.label, value: o.label }));
            this.countryLabelToValue = countryLabelToValue;

            // CityWise__c mixes ISO codes ("IN") and full names ("INDIA") for
            // the same country - map both spellings (uppercased) to the
            // canonical code so tier matching treats them as equal.
            const countryNormalizeMap = new Map();
            options.countryOptions.forEach((o) => {
                const code = o.value.trim().toUpperCase();
                countryNormalizeMap.set(code, code);
                countryNormalizeMap.set(o.label.trim().toUpperCase(), code);
            });
            this.countryNormalizeMap = countryNormalizeMap;

            const cityToState = new Map();
            const cityToCountry = new Map();
            const stateToCountry = new Map();
            options.cityLocations.forEach((loc) => {
                const countryLabel = countryValueToLabel.get(loc.country) || loc.country;
                if (loc.state && !cityToState.has(loc.city)) {
                    cityToState.set(loc.city, loc.state);
                }
                if (countryLabel && !cityToCountry.has(loc.city)) {
                    cityToCountry.set(loc.city, countryLabel);
                }
                if (loc.state && countryLabel && !stateToCountry.has(loc.state)) {
                    stateToCountry.set(loc.state, countryLabel);
                }
            });
            this.cityToState = cityToState;
            this.cityToCountry = cityToCountry;
            this.stateToCountry = stateToCountry;
            console.log('OUTPUT  this.cityToState: ', this.cityToState);
            console.log('OUTPUT  this.cityToCountry: ', this.cityToCountry);
            console.log('OUTPUT  this.stateToCountry: ', this.stateToCountry);
        } catch (error) {
            this.notify('Error loading filter options', this.errorMessage(error), 'error');
        }
    }

    get cityOptions() {
        let options = this.allCityOptions;
        if (this.filterState) {
            options = options.filter((opt) => this.cityToState.get(opt.value) === this.filterState);
        }
        if (this.filterCountry) {
            options = options.filter((opt) => this.cityToCountry.get(opt.value) === this.filterCountry);
        }
        return options;
    }

    get stateOptions() {
        if (!this.filterCountry) {
            return this.allStateOptions;
        }
        return this.allStateOptions.filter((opt) => this.stateToCountry.get(opt.value) === this.filterCountry);
    }

    currentFilter() {
        return {
            city: this.filterCity,
            state: this.filterState,
            zone: this.filterZone,
            // filterCountry holds the label ("INDIA") for display; Apex needs the picklist API value ("IN").
            country: this.countryLabelToValue.get(this.filterCountry) || this.filterCountry,
            vertical: this.filterVertical,
            assignmentStage: this.filterAssignmentStage,
            // filterCampaign holds the campaign name for display; Apex needs every Campaign__c Id sharing that name.
            campaignIds: this.campaignNameToIds.get(this.filterCampaign) || []
        };
    }

    async loadPage(pageIndex) {
        this.loading = true;
        const requestId = ++this.loadRequestId;
        const filterSent = this.currentFilter();
        try {
            const afterId = this.pageCursors[pageIndex];
            const page = await getProspects({
                afterId,
                city: filterSent.city,
                state: filterSent.state,
                zone: filterSent.zone,
                country: filterSent.country,
                vertical: filterSent.vertical,
                assignmentStage: filterSent.assignmentStage,
                campaignIds: filterSent.campaignIds
            });

            if (requestId !== this.loadRequestId) {
                // A newer load was kicked off while this one was in flight
                // (e.g. Apply Filters clicked before the initial load
                // finished) - discard this now-stale response.
                return;
            }

            this.totalCount = page.totalCount;
            this.rows = page.records.map((p) => this.toRow(p));
            this.currentPage = pageIndex;
            this.hasNextPage = page.records.length === PAGE_SIZE;

            if (this.hasNextPage) {
                const lastId = page.records[page.records.length - 1].Id;
                this.pageCursors[pageIndex + 1] = lastId;
            }
        } catch (error) {
            if (requestId === this.loadRequestId) {
                this.notify('Error loading Prospects', this.errorMessage(error), 'error');
            }
        } finally {
            if (requestId === this.loadRequestId) {
                this.loading = false;
            }
        }
    }

    toRow(p) {
        const criteria = {
            city: p.Billing_City__c,
            state: p.Billing_state__c,
            zone: p.ZoneNew__c,
            country: p.Country__c,
            vertical: p.Vertical_Code__c,
            division: p.Division_New__c
        };
        const { tier, rows: tierRows } = resolveTier(this.mappings, criteria, this.countryNormalizeMap);
        const eligibleRoles = tier ? TIER_ROLES[tier] : [];

        const options = {};
        ALL_ROLES.forEach((role) => {
            options[role] = eligibleRoles.includes(role) ? distinctOptions(tierRows, role) : [];
        });
        // A saved value on the Lead is always a real assignment and must
        // always be shown correctly - even when it's no longer (or never
        // was) a candidate this tier's rows would produce. Owner/City Head is
        // deliberately excluded: it's now a pure CityWise__c District Level
        // picker (the read-only Current Owner column already shows the
        // actual saved/pending owner, change-indicator and all), so its
        // dropdown must only ever offer real CityWise candidates - never a
        // synthetic entry for whatever happens to already be saved.
        ALL_ROLES.forEach((role) => {
            if (role === 'owner') {
                return;
            }
            options[role] = ensureSavedValueIsAnOption(options[role], p[FIELD_API[role]], p[LEAD_REL_FIELD[role]] ? p[LEAD_REL_FIELD[role]].Name : null);
        });

        // A pending (unsaved) edit takes priority; otherwise the already-
        // saved server value (Owner's is the Lead's actual current OwnerId,
        // which is never blank); otherwise leave blank. On initial load we
        // deliberately stop here - a role with nothing saved on the record
        // stays blank ("No mapped user") rather than being guessed from
        // CityWise__c, even when the tier pool has exactly one candidate.
        // The candidate still shows up as a pickable OPTION (see
        // ensureSavedValueIsAnOption above); it's just never pre-selected on
        // load. (The manual-edit cascade in handleComboChange is unaffected -
        // that fill-in only happens as a direct result of the user picking a
        // field, not silently on page load.) 'sources' tracks WHY each role
        // has its value, purely for future debugging.
        const pending = this.pendingChanges.get(p.Id) || {};
        const pendingSources = pending.__sources || {};
        const values = {};
        const sources = {};
        ALL_ROLES.forEach((role) => {
            if (FIELD_API[role] in pending) {
                values[role] = pending[FIELD_API[role]];
                sources[role] = pendingSources[role] || 'manual';
            } else if (p[FIELD_API[role]]) {
                values[role] = p[FIELD_API[role]];
                sources[role] = 'server';
            } else {
                values[role] = null;
                sources[role] = null;
            }
        });

        const row = {
            id: p.Id,
            name: p.Name,
            url: `/lightning/r/Lead__c/${p.Id}/view`,
            company: p.Company__c,
            productFamily: p.Product_Family__c,
            city: p.Billing_City__c,
            state: p.Billing_state__c,
            zone: p.ZoneNew__c,
            country: p.Country__c,
            vertical: p.Vertical_Code__c,
            division: p.Division_New__c,
            tier,
            tierRows,
            sources
        };
        ALL_ROLES.forEach((role) => {
            row[`${role}Options`] = options[role];
            row[`${role}Value`] = values[role];
            row[`${role}Disabled`] = options[role].length === 0 || !this.editPermissions[role];
            row[`${role}Placeholder`] = options[role].length === 0 ? NO_MATCH_LABEL : `Select ${ROLE_LABEL[role]}`;
        });

        // The read-only "Current Owner" column always compares against the
        // Lead's actual saved OwnerId/name (never the pending one), so it can
        // tell whether the City Head/RSM/ZSM/NSM/GSRO picks in THIS session
        // are about to change who owns the record.
        row.savedOwnerId = p.OwnerId;
        row.savedOwnerName = p.Owner ? p.Owner.Name : null;
        this.refreshCurrentOwnerDisplay(row);

        return row;
    }

    // Current Owner is read-only display now (the City Head column is what's
    // actually editable) - this keeps its label/change-indicator in sync
    // with row.ownerValue, which changes either from a direct City Head pick
    // or from applyOwnerFollowsPick after an RSM/ZSM/NSM/GSRO pick.
    refreshCurrentOwnerDisplay(row) {
        const currentId = row.ownerValue;
        const changed = !!currentId && currentId !== row.savedOwnerId;
        let label = row.savedOwnerName || row.savedOwnerId || NO_MATCH_LABEL;
        if (changed) {
            const opt = (row.ownerOptions || []).find((o) => o.value === currentId);
            label = opt ? opt.label : currentId;
        }
        row.currentOwnerLabel = label;
        row.currentOwnerChanged = changed;
        row.currentOwnerTooltip = changed ? `Owner will change - was: ${row.savedOwnerName || row.savedOwnerId || 'Unassigned'}` : '';
    }

    handleComboChange(event) {
        const rowId = event.target.dataset.rowId;
        const field = event.target.dataset.field;
        const newValue = event.detail.value;

        const rowIndex = this.rows.findIndex((r) => r.id === rowId);
        if (rowIndex === -1) {
            return;
        }
        const row = { ...this.rows[rowIndex] };
        const tier = row.tier;
        const tierRows = row.tierRows || [];
        const eligibleRoles = tier ? TIER_ROLES[tier] : [];

        const sources = { ...row.sources };
        const values = {};
        ALL_ROLES.forEach((role) => {
            values[role] = row[`${role}Value`];
        });
        values[field] = newValue;
        sources[field] = 'manual';

        // If the changed field isn't part of THIS row's tier-linked chain
        // (e.g. Owner when the tier is State/Zone/Country/Vertical, or any
        // field at all when nothing matched) it has no relationship to the
        // other roles - just record the change (and still make the picked
        // person the new Owner, per applyOwnerFollowsPick below).
        if (!eligibleRoles.includes(field)) {
            row[`${field}Value`] = newValue;
            const changed = { [FIELD_API[field]]: newValue };
            if (field !== 'owner') {
                this.applyOwnerFollowsPick(row, newValue, row[`${field}Options`], sources, changed);
            }
            this.refreshCurrentOwnerDisplay(row);
            row.sources = sources;
            this.commitRowChange(rowIndex, row, changed, [], sources);
            return;
        }

        // Owner is never a TARGET of the tier cascade itself (picking
        // RSM/ZSM/NSM/GSRO must never pull a District Level value onto
        // Owner) - chainRoles is the set that participates in the CityWise
        // cross-derivation: the full eligible set when Owner itself was
        // edited, otherwise everything except Owner. Separately, whoever
        // was just picked at ANY level always becomes the new Owner outright
        // (see applyOwnerFollowsPick after this chain is resolved) - that's
        // independent of, and not limited by, the CityWise-derived chain.
        const chainRoles = field === 'owner' ? eligibleRoles : eligibleRoles.filter((role) => role !== 'owner');

        // Clear every OTHER role in the chain (LeadsProductGroupHandler
        // nulls every field before recomputing) and rebuild each one's
        // options fresh from the tier's row pool, so no stale synthetic
        // entry from an earlier edit can linger.
        const fieldIndex = chainRoles.indexOf(field);
        chainRoles.forEach((role) => {
            if (role !== field) {
                values[role] = null;
                sources[role] = null;
            }
        });
        const optionsByRole = {};
        chainRoles.forEach((role) => {
            optionsByRole[role] = role === field ? row[`${role}Options`] : distinctOptions(tierRows, role);
        });
        // Only auto-select/derive into roles at or above the changed one -
        // roles below it must stay cleared, not silently re-derived.
        chainRoles.forEach((role, idx) => {
            if (idx < fieldIndex) {
                return;
            }
            if (role !== field && !values[role] && optionsByRole[role].length === 1) {
                values[role] = optionsByRole[role][0].value;
                sources[role] = 'auto';
            }
        });
        deriveFromMatchingRow(tierRows, chainRoles, values, sources, optionsByRole);
        // deriveFromMatchingRow only ever fills roles ABOVE the known one, so
        // this is belt-and-suspenders - kept as a guarantee that every role
        // below the changed one ends up blank regardless.
        chainRoles.forEach((role, idx) => {
            if (idx < fieldIndex) {
                values[role] = null;
                sources[role] = null;
            }
        });

        const changed = {};
        const clearedFields = [];
        chainRoles.forEach((role) => {
            row[`${role}Value`] = values[role];
            row[`${role}Options`] = optionsByRole[role];
            row[`${role}Disabled`] = optionsByRole[role].length === 0 || !this.editPermissions[role];
            row[`${role}Placeholder`] = optionsByRole[role].length === 0 ? NO_MATCH_LABEL : `Select ${ROLE_LABEL[role]}`;
            if (values[role]) {
                changed[FIELD_API[role]] = values[role];
            } else {
                clearedFields.push(FIELD_API[role]);
            }
        });
        if (field !== 'owner') {
            this.applyOwnerFollowsPick(row, newValue, optionsByRole[field], sources, changed);
        }
        this.refreshCurrentOwnerDisplay(row);
        row.sources = sources;
        this.commitRowChange(rowIndex, row, changed, clearedFields, sources);
    }

    // Picking a person at any non-Owner role level (RSM/ZSM/NSM/GSRO) also
    // makes them the new Owner of the prospect outright - Owner always
    // follows the most recently picked role, not just whatever CityWise__c's
    // District Level happens to say. `optionsForLabel` is the picked field's
    // own options list, used only to look up a friendly display name.
    applyOwnerFollowsPick(row, newValue, optionsForLabel, sources, changed) {
        const pickedOption = (optionsForLabel || []).find((o) => o.value === newValue);
        row.ownerValue = newValue;
        row.ownerOptions = ensureSavedValueIsAnOption(row.ownerOptions || [], newValue, pickedOption ? pickedOption.label : null);
        row.ownerDisabled = row.ownerOptions.length === 0 || !this.editPermissions.owner;
        row.ownerPlaceholder = row.ownerOptions.length === 0 ? NO_MATCH_LABEL : 'Select Owner';
        sources.owner = 'manual';
        changed[FIELD_API.owner] = newValue;
    }

    commitRowChange(rowIndex, row, changed, clearedFields, sources) {
        const newRows = [...this.rows];
        newRows[rowIndex] = row;
        this.rows = newRows;

        const existing = this.pendingChanges.get(row.id) || { Id: row.id };
        Object.assign(existing, changed);
        clearedFields.forEach((apiField) => {
            delete existing[apiField];
        });
        existing.__sources = sources;
        this.pendingChanges.set(row.id, existing);
    }

    async handleSave() {
        if (this.pendingChanges.size === 0) {
            this.notify('Nothing to save', 'No allocations were changed.', 'info');
            return;
        }

        // Strip the internal __sources bookkeeping - Apex only expects real Lead__c fields.
        const updatedRecords = Array.from(this.pendingChanges.values()).map(({ __sources, ...record }) => record);

        this.loading = true;
        try {
            await saveAllocations({ updatedRecords });
            this.pendingChanges = new Map();
            this.notify('Success', 'Allocations saved.', 'success');
            await this.loadPage(this.currentPage);
        } catch (error) {
            this.notify('Error saving allocations', this.errorMessage(error), 'error');
            this.loading = false;
        }
    }

    handleFilterCityChange(event) {
        this.filterCity = event.detail.value;
        if (this.filterCity) {
            const state = this.cityToState.get(this.filterCity);
            const country = this.cityToCountry.get(this.filterCity);
            if (state) {
                this.filterState = state;
            }
            if (country) {
                this.filterCountry = country;
            }
        }
        this.scheduleApplyFilters();
    }

    handleFilterStateChange(event) {
        this.filterState = event.detail.value;
        if (this.filterState) {
            const country = this.stateToCountry.get(this.filterState);
            if (country) {
                this.filterCountry = country;
            }
            if (this.filterCity && this.cityToState.get(this.filterCity) !== this.filterState) {
                this.filterCity = '';
            }
        }
        this.scheduleApplyFilters();
    }

    handleFilterZoneChange(event) {
        this.filterZone = event.detail.value;
        this.scheduleApplyFilters();
    }

    handleFilterCountryChange(event) {
        this.filterCountry = event.detail.value;
        // If the currently-picked State/City don't belong to this country,
        // they're no longer valid choices - clear them rather than leave a
        // stale selection that's now invisible in its own (filtered) dropdown.
        if (this.filterCountry) {
            if (this.filterState && this.stateToCountry.get(this.filterState) !== this.filterCountry) {
                this.filterState = '';
            }
            if (this.filterCity && this.cityToCountry.get(this.filterCity) !== this.filterCountry) {
                this.filterCity = '';
            }
        }
        this.scheduleApplyFilters();
    }

    handleFilterVerticalChange(event) {
        this.filterVertical = event.detail.value;
        this.scheduleApplyFilters();
    }

    handleFilterAssignmentStageChange(event) {
        this.filterAssignmentStage = event.detail.value;
        this.scheduleApplyFilters();
    }

    handleFilterCampaignChange(event) {
        this.filterCampaign = event.detail.value;
        this.scheduleApplyFilters();
    }

    // Filters auto-apply a short pause after the last change, instead of
    // requiring an explicit Apply button click.
    scheduleApplyFilters() {
        clearTimeout(this.filterDebounceTimer);
        this.filterDebounceTimer = setTimeout(() => {
            this.pageCursors = [null];
            this.loadPage(0);
        }, FILTER_DEBOUNCE_MS);
    }

    // The searchable combobox filters its own dropdown by whatever text is
    // currently in the box, so once a value is picked "All" is no longer
    // reachable by reopening it - this resets just that one field.
    handleClearField(event) {
        const field = event.currentTarget.dataset.field;
        const propByField = {
            city: 'filterCity',
            state: 'filterState',
            zone: 'filterZone',
            country: 'filterCountry',
            vertical: 'filterVertical',
            assignmentStage: 'filterAssignmentStage',
            campaign: 'filterCampaign'
        };
        this[propByField[field]] = '';
        this.scheduleApplyFilters();
    }

    async handleClearFilters() {
        clearTimeout(this.filterDebounceTimer);
        this.filterCity = '';
        this.filterState = '';
        this.filterZone = '';
        this.filterCountry = '';
        this.filterVertical = '';
        this.filterAssignmentStage = '';
        this.filterCampaign = '';
        this.pageCursors = [null];
        await this.loadPage(0);
    }

    async handlePrevious() {
        if (this.currentPage > 0) {
            await this.loadPage(this.currentPage - 1);
        }
    }

    async handleNext() {
        if (this.hasNextPage) {
            await this.loadPage(this.currentPage + 1);
        }
    }

    errorMessage(error) {
        return (error && error.body && error.body.message) || (error && error.message) || 'Unknown error';
    }

    notify(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get tableWrapperClass() {
        return this.loading ? 'table-scroll-wrapper is-loading' : 'table-scroll-wrapper';
    }

    get noActiveFilters() {
        return !(this.filterCity || this.filterState || this.filterZone || this.filterCountry
            || this.filterVertical || this.filterAssignmentStage || this.filterCampaign);
    }

    get isPreviousDisabled() {
        return this.currentPage === 0;
    }

    get isNextDisabled() {
        return !this.hasNextPage;
    }

    get rangeLabel() {
        if (this.totalCount === 0) {
            return 'No records';
        }
        const start = this.currentPage * PAGE_SIZE + 1;
        const end = start + this.rows.length - 1;
        return `Showing ${start}-${end} of ${this.totalCount}`;
    }
}
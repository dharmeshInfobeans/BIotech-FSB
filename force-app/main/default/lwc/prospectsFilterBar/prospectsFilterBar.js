import { LightningElement } from 'lwc';
import getFilterOptions from '@salesforce/apex/ProspectsDashboardController.getFilterOptions';

// Period filter removed from the UI per request - replaced by Year (see prospectsFilterBar.html).
// The options/state/handler that used to drive it are kept here, commented out, so Period can be
// restored later without rebuilding it from scratch - see also the matching commented-out logic
// (resolveDateRange/resolveEffectiveYear/resolvePeriodPreset) in ProspectsDashboardController.
// const PERIOD_OPTIONS = [
//     { label: 'All', value: 'All' },
//     { label: 'This Year', value: 'ThisYear' },
//     { label: 'Last Year', value: 'LastYear' },
//     { label: 'This Quarter', value: 'ThisQuarter' },
//     { label: 'Last Quarter', value: 'LastQuarter' },
//     { label: 'This Month', value: 'ThisMonth' },
//     { label: 'Last Month', value: 'LastMonth' },
//     { label: 'Last 7 Days', value: 'Last7Days' },
//     { label: 'Last 30 Days', value: 'Last30Days' }
// ];

const TEAM_OPTIONS = [
    { label: 'Sales Lead', value: 'Sales Lead' },
    { label: 'Marketing Lead', value: 'Marketing Lead' },
    { label: 'Digital Marketing Leads', value: 'Digital Marketing Leads' }
];

const QUARTER_OPTIONS = [
    { label: 'Q1', value: 'Q1' },
    { label: 'Q2', value: 'Q2' },
    { label: 'Q3', value: 'Q3' },
    { label: 'Q4', value: 'Q4' }
];

const MONTH_NAMES = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
];
const MONTH_OPTIONS = MONTH_NAMES.map((name, i) => ({ label: name, value: String(i + 1) }));

const WEEK_OPTIONS = Array.from({ length: 52 }, (_, i) => ({ label: 'Week ' + (i + 1), value: String(i + 1) }));

export default class ProspectsFilterBar extends LightningElement {
    teamOptions = TEAM_OPTIONS;
    quarterOptions = QUARTER_OPTIONS;
    monthOptions = MONTH_OPTIONS;
    weekOptions = WEEK_OPTIONS;

    zoneOptions = [];
    countryOptions = [];
    ownerOptions = [];
    yearOptions = [];

    // Period disabled - see the commented-out PERIOD_OPTIONS above and handlePeriodChange below.
    // period = 'All';
    teams = [];
    zones = [];
    countries = [];
    ownerIds = [];
    years = [];
    quarters = [];
    months = [];
    weeks = [];

    connectedCallback() {
        this.loadFilterOptions();
    }

    // Zone/Country/Owner are dynamic/cascading: whichever of the OTHER data-derived filters are
    // currently selected narrows each dropdown's available values, so e.g. picking Country=India
    // narrows Owner down to India-relevant people. This means options must be re-fetched from
    // Apex on every filter change (imperatively) rather than loaded once via a static @wire.
    loadFilterOptions() {
        getFilterOptions({ filtersJson: JSON.stringify(this.currentFilters()) })
            .then((data) => {
                this.zoneOptions = data.zones.map((z) => ({ label: z, value: z }));
                const sortedCountries = [...data.countries].sort((a, b) => a.label.localeCompare(b.label));
                this.countryOptions = sortedCountries.map((c) => ({ label: c.label, value: c.value }));
                const sortedOwners = [...data.owners].sort((a, b) => a.name.localeCompare(b.name));
                this.ownerOptions = sortedOwners.map((o) => ({ label: o.name, value: o.id }));
                this.yearOptions = (data.years || []).map((y) => ({ label: String(y), value: String(y) }));
            })
            .catch((error) => {
                // eslint-disable-next-line no-console
                console.error('Failed to load filter options', error);
            });
    }

    // Period disabled - handler kept (commented) so it's easy to re-wire once Period returns.
    // handlePeriodChange(event) {
    //     this.period = event.detail.value;
    //     this.loadFilterOptions();
    //     this.notifyChange();
    // }

    handleTeamChange(event) {
        this.teams = event.detail.value;
        this.loadFilterOptions();
        this.notifyChange();
    }

    handleZoneChange(event) {
        this.zones = event.detail.value;
        this.loadFilterOptions();
        this.notifyChange();
    }

    handleCountryChange(event) {
        this.countries = event.detail.value;
        this.loadFilterOptions();
        this.notifyChange();
    }

    handleOwnerChange(event) {
        this.ownerIds = event.detail.value;
        this.loadFilterOptions();
        this.notifyChange();
    }

    handleYearChange(event) {
        this.years = event.detail.value;
        this.loadFilterOptions();
        this.notifyChange();
    }

    handleQuarterChange(event) {
        this.quarters = event.detail.value;
        this.loadFilterOptions();
        this.notifyChange();
    }

    handleMonthChange(event) {
        this.months = event.detail.value;
        this.loadFilterOptions();
        this.notifyChange();
    }

    handleWeekChange(event) {
        this.weeks = event.detail.value;
        this.loadFilterOptions();
        this.notifyChange();
    }

    handleClearAll() {
        // this.period = 'All'; // Period disabled - see above.
        this.teams = [];
        this.zones = [];
        this.countries = [];
        this.ownerIds = [];
        this.years = [];
        this.quarters = [];
        this.months = [];
        this.weeks = [];
        this.loadFilterOptions();
        this.notifyChange();
    }

    currentFilters() {
        return {
            // period: this.period, // Period disabled - see above.
            teams: this.teams,
            zones: this.zones,
            countries: this.countries,
            ownerIds: this.ownerIds,
            years: this.years.map((y) => parseInt(y, 10)),
            quarters: this.quarters,
            months: this.months.map((m) => parseInt(m, 10)),
            weeks: this.weeks.map((w) => parseInt(w, 10))
        };
    }

    notifyChange() {
        this.dispatchEvent(new CustomEvent('filterschange', { detail: this.currentFilters() }));
    }
}
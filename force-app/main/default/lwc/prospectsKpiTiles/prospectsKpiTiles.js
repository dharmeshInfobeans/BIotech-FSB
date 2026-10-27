import { LightningElement, api } from 'lwc';
import getKpiSummary from '@salesforce/apex/ProspectsDashboardController.getKpiSummary';

export default class ProspectsKpiTiles extends LightningElement {
    summary;
    loadCount = 0;
    _filters;

    @api
    get filters() {
        return this._filters;
    }

    set filters(value) {
        this._filters = value;
        this.loadSummary();
    }

    loadSummary() {
        this.loadCount += 1;
        const requestId = this.loadCount;
        getKpiSummary({ filtersJson: JSON.stringify(this._filters || {}) })
            .then((result) => {
                if (requestId !== this.loadCount) {
                    return;
                }
                this.summary = result;
            })
            .catch(() => {
                if (requestId !== this.loadCount) {
                    return;
                }
                this.summary = undefined;
            });
    }

    get tiles() {
        if (!this.summary) {
            return [];
        }
        const s = this.summary;
        const defs = [
            { key: 'total', label: 'Total Prospects', value: s.totalProspects, pct: null, cssClass: 'tile tile-total' },
            { key: 'unqualified', label: 'Unqualified Prospects', value: s.unqualifiedProspects, pct: s.unqualifiedPct, cssClass: 'tile tile-warning' },
            { key: 'net', label: 'Net Prospects', value: s.netProspects, pct: s.netPct, cssClass: 'tile tile-info' },
            { key: 'oppCount', label: 'Opp Count', value: s.oppCount, pct: null, cssClass: 'tile tile-total' },
            { key: 'wonOpp', label: 'Won Opp', value: s.wonOpp, pct: s.wonOppPct, cssClass: 'tile tile-success' },
            { key: 'lostOpp', label: 'Lost Opp', value: s.lostOpp, pct: s.lostOppPct, cssClass: 'tile tile-danger' },
            { key: 'noFollowUp', label: 'No Follow Up Prospects', value: s.noFollowUpProspects, pct: s.noFollowUpPct, cssClass: 'tile tile-warning' },
            { key: 'opportunityUntouch', label: 'No Follow Up Opp', value: s.opportunityUntouchCount, pct: s.opportunityUntouchPct, cssClass: 'tile tile-warning' },
            { key: 'expiredOpp', label: 'Expired Opp', value: s.expiredOpp, pct: s.expiredOppPct, cssClass: 'tile tile-info' },
            { key: 'closed', label: 'Prospects Closed', value: s.prospectsClosed, pct: s.closedPct, cssClass: 'tile tile-info' },
            { key: 'uniqueFamilyProspects', label: 'Unique Family Prospects', value: s.uniqueFamilyProspects, pct: null, cssClass: 'tile tile-total' }
        ];
        // pctText always has a rendered line, even for tiles with no percentage (a non-breaking
        // space rather than an empty string, which some browsers collapse to zero height) - every
        // tile then reserves the same vertical slot for that line, so tiles don't come out visibly
        // taller/shorter depending on whether they happen to carry a percentage.
        return defs.map((tile) => ({ ...tile, pctText: tile.pct === null || tile.pct === undefined ? ' ' : tile.pct + '%' }));
    }
}
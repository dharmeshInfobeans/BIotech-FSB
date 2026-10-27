import { LightningElement, track, api } from 'lwc';
import { NavigationMixin }             from 'lightning/navigation';
import getDashboardData                from '@salesforce/apex/LeadershipDashboardController.getDashboardData';

export default class LeadershipDashboard extends NavigationMixin(LightningElement) {

    @api pendingReportId = '';
    @api historyReportId = '';
    @api agingReportId   = '';

    // ── State ─────────────────────────────────────────────────────────────────
    @track _data         = null;
    @track isLoading     = false;
    @track loadError     = null;
    @track lastRefreshed = null;

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    connectedCallback() {
        this._load();
    }

    // ── Data load ─────────────────────────────────────────────────────────────
    async _load() {
        this.isLoading = true;
        this.loadError = null;
        try {
            this._data       = await getDashboardData();
            this.lastRefreshed = new Intl.DateTimeFormat('en-GB', {
                day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit'
            }).format(new Date());
        } catch (e) {
            this.loadError = this._msg(e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Computed properties ───────────────────────────────────────────────────
    get hasData()          { return !!this._data && !this.isLoading; }
    get kpi()              { return this._data?.kpi            ?? {}; }
    get byStage()          { return this._data?.byStage         ?? []; }
    get byCountry()        { return this._data?.byCountry       ?? []; }
    get trends()           { return this._data?.trends          ?? []; }
    get overdueRequests()  { return this._data?.overdueRequests ?? []; }

    get noActiveRequests() { return this.byStage.length   === 0; }
    get noCountryData()    { return this.byCountry.length === 0; }
    get hasOverdue()       { return this.overdueRequests.length > 0; }
    get overdueCount()     { return this.overdueRequests.length; }

    // ── Handlers ──────────────────────────────────────────────────────────────
    handleRefresh() {
        this._load();
    }

    handleOpenRequest(event) {
        const recId = event.currentTarget.dataset.recid;
        if (!recId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/leadership-request-detail?recordId=${recId}`
            }
        });
    }

    handleViewReport(event) {
        const report   = event.currentTarget.dataset.report;
        const reportId = report === 'pending' ? this.pendingReportId
                       : report === 'history' ? this.historyReportId
                       : this.agingReportId;
        if (!reportId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId   : reportId,
                actionName : 'view'
            }
        });
    }

    reportIdFor(report) {
        if (report === 'pending') return this.pendingReportId;
        if (report === 'history') return this.historyReportId;
        if (report === 'aging')   return this.agingReportId;
        return '';
    }

    // ── Error helper ──────────────────────────────────────────────────────────
    _msg(error) {
        if (typeof error === 'string') return error;
        if (error?.body?.message)      return error.body.message;
        if (error?.message)            return error.message;
        return 'An unexpected error occurred.';
    }
}
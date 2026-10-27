import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getRequests      from '@salesforce/apex/FunctionalHeadQueueController.getRequests';
import getPastRequests  from '@salesforce/apex/FunctionalHeadQueueController.getPastRequests';

const FLIP = { asc: 'desc', desc: 'asc' };

export default class FunctionalHeadQueue extends NavigationMixin(LightningElement) {

    @track allRequests  = [];
    @track searchTerm   = '';
    @track filterCountry     = '';
    @track filterDistributor = '';
    @track filterPriority    = '';
    @track sortField     = 'submittedDate';
    @track sortDirection = 'desc';

    @track showPastRequests  = false;
    @track pastRequests      = [];
    @track pastLoading       = false;
    @track pastError         = '';
    @track pastSearchTerm    = '';
    @track pastFilterStatus  = '';
    @track pastSortField     = 'submittedDate';
    @track pastSortDirection = 'desc';

    error;
    _wiredResult;

    @wire(getRequests)
    wiredRequests(result) {
        this._wiredResult = result;
        if (result.data) {
            this.allRequests = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error.body?.message || 'Failed to load requests.';
            this.allRequests = [];
        }
    }

    get totalCount()   { return this.filteredRequests.length; }
    get overdueCount() { return this.allRequests.filter(r => r.isOverdue).length; }

    get countryOptions() {
        const unique = [...new Set(this.allRequests.map(r => r.country).filter(Boolean))].sort();
        return [{ label: 'All Countries', value: '' }, ...unique.map(c => ({ label: c, value: c }))];
    }

    get distributorOptions() {
        const unique = [...new Set(this.allRequests.map(r => r.distributorName).filter(Boolean))].sort();
        return [{ label: 'All Distributors', value: '' }, ...unique.map(d => ({ label: d, value: d }))];
    }

    get priorityOptions() {
        return [
            { label: 'All Priorities', value: '' },
            { label: 'High (>30 days)',     value: 'High'   },
            { label: 'Medium (15–30 days)', value: 'Medium' },
            { label: 'Low (<15 days)',      value: 'Low'    },
        ];
    }

    get filteredRequests() {
        const term = (this.searchTerm || '').toLowerCase();
        let rows = this.allRequests.filter(r => {
            if (term) {
                const match =
                    (r.name            || '').toLowerCase().includes(term) ||
                    (r.distributorName || '').toLowerCase().includes(term) ||
                    (r.country         || '').toLowerCase().includes(term) ||
                    (r.productName     || '').toLowerCase().includes(term);
                if (!match) return false;
            }
            if (this.filterCountry     && r.country         !== this.filterCountry)     return false;
            if (this.filterDistributor && r.distributorName !== this.filterDistributor)  return false;
            if (this.filterPriority    && this._getPriority(r.daysPending) !== this.filterPriority) return false;
            return true;
        });

        const field = this.sortField;
        const dir   = this.sortDirection === 'asc' ? 1 : -1;
        rows = [...rows].sort((a, b) => {
            const va = a[field] ?? '';
            const vb = b[field] ?? '';
            if (va < vb) return -dir;
            if (va > vb) return  dir;
            return 0;
        });

        return rows.map(r => {
            const priority = this._getPriority(r.daysPending);
            return {
                ...r,
                priority,
                priorityClass:    this._priorityClass(priority),
                rowClass:         r.isOverdue ? 'queue-row row-overdue' : 'queue-row',
                formattedDate:    this._formatDate(r.submittedDate),
                daysPendingLabel: r.daysPending != null ? `${r.daysPending}d` : '—',
                daysPendingClass: (r.daysPending || 0) > 30 ? 'days-overdue'
                                : (r.daysPending || 0) >= 15 ? 'days-warning' : ''
            };
        });
    }

    get hasResults() { return this.filteredRequests.length > 0; }

    get hasFilters() {
        return !!(this.searchTerm || this.filterCountry || this.filterDistributor || this.filterPriority);
    }

    get resultsLabel() {
        const n = this.filteredRequests.length;
        return `${n} request${n !== 1 ? 's' : ''}`;
    }

    get sortArrow_name()          { return this._arrow('name'); }
    get sortArrow_distributorName(){ return this._arrow('distributorName'); }
    get sortArrow_country()       { return this._arrow('country'); }
    get sortArrow_productName()   { return this._arrow('productName'); }
    get sortArrow_submittedDate() { return this._arrow('submittedDate'); }
    get sortArrow_daysPending()   { return this._arrow('daysPending'); }

    _arrow(field) {
        if (this.sortField !== field) return '⇅';
        return this.sortDirection === 'asc' ? '▲' : '▼';
    }

    handleSearch(e)           { this.searchTerm       = e.target.value; }
    handleCountryFilter(e)    { this.filterCountry     = e.detail.value; }
    handleDistributorFilter(e){ this.filterDistributor = e.detail.value; }
    handlePriorityFilter(e)   { this.filterPriority    = e.detail.value; }

    handleClearFilters() {
        this.searchTerm        = '';
        this.filterCountry     = '';
        this.filterDistributor = '';
        this.filterPriority    = '';
    }

    handleSort(e) {
        const field = e.currentTarget.dataset.field;
        if (this.sortField === field) {
            this.sortDirection = FLIP[this.sortDirection];
        } else {
            this.sortField     = field;
            this.sortDirection = 'asc';
        }
    }

    handleRowClick(e) {
        const recId = e.currentTarget.dataset.recid;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `/functional-head-request-detail?recordId=${recId}` }
        });
    }

    handleRefresh() {
        refreshApex(this._wiredResult).catch(e => {
            this.error = e?.body?.message || 'Refresh failed. Please try again.';
        });
    }

    // ── Past Requests ─────────────────────────────────────────────────────────
    get pastStatusOptions() {
        return [
            { label: 'All Statuses', value: '' },
            { label: 'Approved',     value: 'Approved' },
            { label: 'Sent Back',    value: 'Sent Back' },
            { label: 'Rejected',     value: 'Rejected' },
        ];
    }

    get filteredPastRequests() {
        const term = (this.pastSearchTerm || '').toLowerCase();
        let rows = this.pastRequests.filter(r => {
            if (term) {
                const match =
                    (r.name            || '').toLowerCase().includes(term) ||
                    (r.distributorName || '').toLowerCase().includes(term) ||
                    (r.country         || '').toLowerCase().includes(term) ||
                    (r.productName     || '').toLowerCase().includes(term);
                if (!match) return false;
            }
            const isSentBack = r.status === 'Sent Back';
            const isRejected = r.status === 'Rejected';
            if (this.pastFilterStatus === 'Sent Back' && !isSentBack) return false;
            if (this.pastFilterStatus === 'Rejected'  && !isRejected)  return false;
            if (this.pastFilterStatus === 'Approved'  && (isSentBack || isRejected)) return false;
            return true;
        });

        const field = this.pastSortField;
        const dir   = this.pastSortDirection === 'asc' ? 1 : -1;
        rows = [...rows].sort((a, b) => {
            const va = a[field] ?? '';
            const vb = b[field] ?? '';
            if (va < vb) return -dir;
            if (va > vb) return  dir;
            return 0;
        });

        return rows.map(r => ({
            ...r,
            formattedDate   : this._formatDate(r.submittedDate),
            fhAction        : this._fhAction(r.status),
            statusPillClass : this._pastStatusPill(r.status)
        }));
    }

    get hasPastResults()   { return this.filteredPastRequests.length > 0; }
    get pastResultsLabel() {
        const n = this.filteredPastRequests.length;
        return `${n} request${n !== 1 ? 's' : ''}`;
    }

    get pastArrow_name()          { return this._pastArrow('name'); }
    get pastArrow_distributorName(){ return this._pastArrow('distributorName'); }
    get pastArrow_country()       { return this._pastArrow('country'); }
    get pastArrow_productName()   { return this._pastArrow('productName'); }
    get pastArrow_status()        { return this._pastArrow('status'); }
    get pastArrow_submittedDate() { return this._pastArrow('submittedDate'); }

    _pastArrow(field) {
        if (this.pastSortField !== field) return '⇅';
        return this.pastSortDirection === 'asc' ? '▲' : '▼';
    }

    async handleViewPastRequests() {
        this.showPastRequests = true;
        if (this.pastRequests.length === 0) {
            this.pastLoading = true;
            this.pastError   = '';
            try {
                this.pastRequests = await getPastRequests();
            } catch (e) {
                this.pastError = e?.body?.message || 'Failed to load past requests.';
            } finally {
                this.pastLoading = false;
            }
        }
    }

    handleBackToQueue()       { this.showPastRequests = false; }
    handlePastSearch(e)       { this.pastSearchTerm   = e.target.value; }
    handlePastStatusFilter(e) { this.pastFilterStatus = e.detail.value; }

    handlePastSort(e) {
        const field = e.currentTarget.dataset.field;
        if (this.pastSortField === field) {
            this.pastSortDirection = FLIP[this.pastSortDirection];
        } else {
            this.pastSortField     = field;
            this.pastSortDirection = 'asc';
        }
    }

    _fhAction(status) {
        if (status === 'Rejected')  return 'Rejected';
        if (status === 'Sent Back') return 'Sent Back';
        return 'Approved';
    }

    _pastStatusPill(status) {
        if (status === 'Rejected')  return 'past-pill past-pill-rejected';
        if (status === 'Sent Back') return 'past-pill past-pill-sentback';
        return 'past-pill past-pill-completed';
    }

    _formatDate(dateStr) {
        if (!dateStr) return '—';
        const [year, month, day] = dateStr.split('-');
        const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        return `${day} ${months[parseInt(month, 10) - 1]} ${year}`;
    }

    _getPriority(daysPending) {
        const d = daysPending || 0;
        if (d > 30)  return 'High';
        if (d >= 15) return 'Medium';
        return 'Low';
    }

    _priorityClass(priority) {
        if (priority === 'High')   return 'priority-badge priority-high';
        if (priority === 'Medium') return 'priority-badge priority-medium';
        return 'priority-badge priority-normal';
    }
}
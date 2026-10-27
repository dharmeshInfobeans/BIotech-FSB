import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getRequests from '@salesforce/apex/LeadershipQueueController.getRequests';

const FLIP = { asc: 'desc', desc: 'asc' };

export default class LeadershipQueueManagement extends NavigationMixin(LightningElement) {

    @track allRequests = [];
    @track searchTerm = '';
    @track filterStatus = '';
    @track filterCountry = '';
    @track filterDistributor = '';
    @track filterPriority = '';
    @track sortField = 'submittedDate';
    @track sortDirection = 'desc';

    error;
    _wiredResult;

    // ─── Wire ────────────────────────────────────────────────────────────────

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

    // ─── Summary counts (always from full list, not filtered) ────────────────

    get totalCount() { return this.filteredRequests.length; }

    get pendingCount() {
        return this.allRequests.filter(
            r => r.status === 'Submitted' || r.status === 'Under Leadership Review'
        ).length;
    }

    get overdueCount() {
        return this.allRequests.filter(r => r.isOverdue).length;
    }

    get pendingApprovalCount() {
        return this.allRequests.filter(r => r.isPendingApproval).length;
    }

    // ─── Filter dropdown options (derived from loaded data) ──────────────────

    get statusOptions() {
        const unique = [...new Set(this.allRequests.map(r => r.status).filter(Boolean))].sort();
        return [
            { label: 'All Statuses', value: '' },
            ...unique.map(s => ({ label: s, value: s }))
        ];
    }

    get countryOptions() {
        const unique = [...new Set(this.allRequests.map(r => r.country).filter(Boolean))].sort();
        return [
            { label: 'All Countries', value: '' },
            ...unique.map(c => ({ label: c, value: c }))
        ];
    }

    get distributorOptions() {
        const unique = [...new Set(this.allRequests.map(r => r.distributorName).filter(Boolean))].sort();
        return [
            { label: 'All Distributors', value: '' },
            ...unique.map(d => ({ label: d, value: d }))
        ];
    }

    get priorityOptions() {
        return [
            { label: 'All Priorities', value: '' },
            { label: 'High (>30 days)',    value: 'High'   },
            { label: 'Medium (15–30 days)', value: 'Medium' },
            { label: 'Low (<15 days)',     value: 'Low'    },
        ];
    }

    // ─── Filtered + sorted + display-enriched rows ───────────────────────────

    get filteredRequests() {
        const term = (this.searchTerm || '').toLowerCase();
        let rows = this.allRequests.filter(r => {
            if (term) {
                const match =
                    (r.name            || '').toLowerCase().includes(term) ||
                    (r.distributorName || '').toLowerCase().includes(term) ||
                    (r.country         || '').toLowerCase().includes(term) ||
                    (r.productName     || '').toLowerCase().includes(term) ||
                    (r.status          || '').toLowerCase().includes(term);
                if (!match) return false;
            }
            if (this.filterStatus      && r.status        !== this.filterStatus)      return false;
            if (this.filterCountry     && r.country        !== this.filterCountry)     return false;
            if (this.filterDistributor && r.distributorName !== this.filterDistributor) return false;
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
            // tiebreaker: newest request number first
            const na = a.name ?? '';
            const nb = b.name ?? '';
            if (na < nb) return 1;
            if (na > nb) return -1;
            return 0;
        });

        return rows.map(r => {
            const priority = this._getPriority(r.daysPending);
            return {
                ...r,
                priority,
                rowClass:        this._rowClass(r),
                priorityClass:   this._priorityClass(priority),
                statusClass:     this._statusClass(r.status),
                countryRegion:   [r.country, r.region].filter(Boolean).join(' / ') || '—',
                formattedDate:   this._formatDate(r.submittedDate),
                daysPendingLabel: r.daysPending != null ? `${r.daysPending}d` : '—',
                daysPendingClass: (r.daysPending || 0) >= 14
                    ? 'days-overdue'
                    : (r.daysPending || 0) >= 7 ? 'days-warning' : ''
            };
        });
    }

    get hasResults() { return this.filteredRequests.length > 0; }

    get hasFilters() {
        return !!(this.searchTerm || this.filterStatus || this.filterCountry || this.filterDistributor || this.filterPriority);
    }

    get resultsLabel() {
        const n = this.filteredRequests.length;
        return `${n} request${n !== 1 ? 's' : ''}`;
    }

    // ─── Sort arrow getters ───────────────────────────────────────────────────

    get sortArrow_name()          { return this._arrow('name'); }
    get sortArrow_distributorName(){ return this._arrow('distributorName'); }
    get sortArrow_country()       { return this._arrow('country'); }
    get sortArrow_productName()   { return this._arrow('productName'); }
    get sortArrow_status()        { return this._arrow('status'); }
    get sortArrow_submittedDate() { return this._arrow('submittedDate'); }
    get sortArrow_daysPending()   { return this._arrow('daysPending'); }

    _arrow(field) {
        if (this.sortField !== field) return '⇅';
        return this.sortDirection === 'asc' ? '▲' : '▼';
    }

    // ─── Event handlers ───────────────────────────────────────────────────────

    handleSearch(e)          { this.searchTerm       = e.target.value; }
    handleStatusFilter(e)    { this.filterStatus      = e.detail.value; }
    handleCountryFilter(e)   { this.filterCountry     = e.detail.value; }
    handleDistributorFilter(e){ this.filterDistributor = e.detail.value; }
    handlePriorityFilter(e)  { this.filterPriority    = e.detail.value; }

    handleClearFilters() {
        this.searchTerm        = '';
        this.filterStatus      = '';
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
            attributes: { url: `/leadership-request-detail?recordId=${recId}` }
        });
    }

    handleRefresh() {
        refreshApex(this._wiredResult).catch(e => {
            this.error = e?.body?.message || 'Refresh failed. Please try again.';
        });
    }

    // ─── Display helpers ──────────────────────────────────────────────────────

    _formatDate(dateStr) {
        if (!dateStr) return '—';
        const [year, month, day] = dateStr.split('-');
        const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        return `${day} ${months[parseInt(month, 10) - 1]} ${year}`;
    }

    _rowClass(r) {
        if (r.isOverdue)        return 'queue-row row-overdue';
        if (r.isPendingApproval) return 'queue-row row-pending-approval';
        return 'queue-row';
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

    _statusClass(status) {
        const map = {
            'Submitted':              'status-pill status-submitted',
            'Under Leadership Review':'status-pill status-leadership',
            'Approved by Leadership': 'status-pill status-approved',
            'Submitted to Regulatory':'status-pill status-regulatory',
            'Under Regulatory Review':'status-pill status-regulatory',
            'Completed':              'status-pill status-completed',
            'Rejected':               'status-pill status-rejected',
            'Sent Back':              'status-pill status-sent-back',
            'On Hold':                'status-pill status-on-hold'
        };
        return map[status] || 'status-pill status-default';
    }
}
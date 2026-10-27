import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getSignedLedgers from '@salesforce/apex/SAPLedgerService.getSignedLedgers';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const SIGN_STATUS_LABEL_MAP = {
    SIGNED:   'Signed',
    PENDING:  'Pending',
    REJECTED: 'Rejected'
};

export default class SignedRequests extends  NavigationMixin(LightningElement) {

    @track ledgerData = [];
    @track pagedData = [];
    @track isLoading = false;
    @track error = '';
    @track successMessage = '';
    @track showEmptyState = false;

    selectedRows = [];
    isAllSelected = false;

    filterYear       = '';
    filterQuarter     = '';
    filterSignStatus  = '';
    filterSapCode     = '';
    filteredData      = [];

    sortDirection = 'asc';
    pageSize = 50;
    pageNumber = 1;
    totalPages = 1;

    connectedCallback() {
        this.loadRecords();
    }

    loadRecords() {
        this.isLoading = true;
        this.error = '';
        this.successMessage = '';
        this.showEmptyState = false;

        getSignedLedgers()
            .then(data => {
                if (data && data.length > 0) {
                    this.ledgerData = data.map(item => ({
                        ...item,
                        selected: false,
                        ledgerStatusClass: this.getStatusClass(item.ledgerStatus),
                        signStatusClass:   this.getSignStatusClass(item.signStatus),
                        contactName:  item.contactName  || '—',
                        contactEmail: item.contactEmail || '—',
                        ledgerStatus: item.ledgerStatus || '—',
                        signStatus:   item.signStatus   || '—',
                        sapCode:      item.sapCode      || '—'
                    }));
                    // Reset filters on a fresh load so stale filter state doesn't
                    // hide newly-loaded records.
                    this.filterYear      = '';
                    this.filterQuarter   = '';
                    this.filterSignStatus = '';
                    this.filterSapCode   = '';
                    this.pageNumber = 1;
                    this.applyFilters();
                    this.showEmptyState = false;
                } else {
                    this.ledgerData = [];
                    this.filteredData = [];
                    this.pagedData = [];
                    this.showEmptyState = true;
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.error = error?.body?.message || 'Error loading pending records.';
                this.isLoading = false;
            });
    }

    handleSortAccountName() {
        this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';

        this.ledgerData = [...this.ledgerData].sort((a, b) => {
            const nameA = (a.accountName || '').toLowerCase();
            const nameB = (b.accountName || '').toLowerCase();

            if (this.sortDirection === 'asc') {
                return nameA.localeCompare(nameB);
            }
            return nameB.localeCompare(nameA);
        });

        this.pageNumber = 1;
        this.applyFilters();
    }

    // ── Pagination (operates on the already-filtered data set) ────
    updatePageData() {
        this.updateFilteredPageData();
    }

    updateFilteredPageData() {
        const start    = (this.pageNumber - 1) * this.pageSize;
        this.pagedData = this.filteredData.slice(start, start + this.pageSize);
    }

    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.updatePageData();
        }
    }

    handlePrevious() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.updatePageData();
        }
    }

    get disablePrevious() { return this.pageNumber === 1; }
    get disableNext()     { return this.pageNumber === this.totalPages; }

    // hasResults: are there ANY base records loaded at all
    get hasResults()      { return this.ledgerData && this.ledgerData.length > 0; }

    // hasFilteredResults: does the CURRENT filter selection match anything
    get hasFilteredResults() { return this.filteredData && this.filteredData.length > 0; }

    get isSendDisabled()  { return this.selectedRows.length === 0; }

    // ── Checkbox selection ───────────────────────────────────────
    handleSelectAll(event) {
        const checked = event.target.checked;
        this.isAllSelected = checked;
        this.ledgerData = this.ledgerData.map(item => ({ ...item, selected: checked }));
        this.applyFilters();
        this.updateSelectedRows();
    }

    handleRowSelect(event) {
        const ledgerId = event.target.dataset.id;
        const checked  = event.target.checked;
        this.ledgerData = this.ledgerData.map(item =>
            item.ledgerId === ledgerId ? { ...item, selected: checked } : item
        );
        this.applyFilters();
        this.updateSelectedRows();
    }

    updateSelectedRows() {
        this.selectedRows = this.ledgerData.filter(item => item.selected);
        this.isAllSelected = this.ledgerData.length > 0 && this.ledgerData.every(item => item.selected);
    }

    get sortArrow() {
        return this.sortDirection === 'asc' ? '↑' : '↓';
    }

    // ── Send single row ──────────────────────────────────────────
    handleSendForSignRow(event) {
        const accountId = event.currentTarget.dataset.account;
        const ledgerId  = event.currentTarget.dataset.id;
        this.handleSendForSign(accountId, ledgerId);
    }

    handleSendForSign(accountId, ledgerId) {
        sendForSign({ accountId: accountId, statementDate: '' })
            .then(result => {
                this.showToast('Success', result, 'success');
                this.removeRows([ledgerId]);
            })
            .catch(error => {
                this.showToast('Error', error?.body?.message || 'Error sending request', 'error');
            });
    }

    // ── Send selected (bulk) ─────────────────────────────────────
    handleSendSelected() {
        if (!this.selectedRows || this.selectedRows.length === 0) {
            this.showToast('Warning', 'Please select at least one record.', 'warning');
            return;
        }

        const accountIds = this.selectedRows.map(row => row.accountId);
        const ledgerIds  = this.selectedRows.map(row => row.ledgerId);
        const sentCount  = ledgerIds.length;

        sendSelectedForSign({ accountIds: accountIds, statementDate: '' })
            .then(result => {
                this.showToast('Success', result, 'success');
                this.removeRows(ledgerIds);
                this.successMessage = sentCount + ' statement(s) sent successfully.';
            })
            .catch(error => {
                this.showToast('Error', error?.body?.message || 'Unexpected error occurred', 'error');
            });
    }

    // ── Filter options ───────────────────────────────────────────
    get yearOptions() {
        const currentYear = new Date().getFullYear();
        const years = [{ label: 'All Years', value: '' }];
        for (let y = currentYear; y >= currentYear - 4; y--) {
            years.push({ label: String(y), value: String(y) });
        }
        return years;
    }

    get quarterOptions() {
        return [
            { label: 'All Quarters', value: '' },
            { label: 'Q1 (Jan – Mar)', value: 'Q1' },
            { label: 'Q2 (Apr – Jun)', value: 'Q2' },
            { label: 'Q3 (Jul – Sep)', value: 'Q3' },
            { label: 'Q4 (Oct – Dec)', value: 'Q4' },
        ];
    }

    get signStatusOptions() {
        return [
            { label: 'All Statuses', value: '' },
            { label: 'Signed',   value: 'SIGNED' },
            { label: 'Pending',  value: 'PENDING' },
            { label: 'Rejected', value: 'REJECTED' }
        ];
    }

    get filterQuarterLabel() {
        const opt = this.quarterOptions.find(o => o.value === this.filterQuarter);
        return opt ? opt.label : this.filterQuarter;
    }

    get filterSignStatusLabel() {
        return SIGN_STATUS_LABEL_MAP[this.filterSignStatus] || this.filterSignStatus;
    }

    get hasActiveFilters() {
        return this.filterYear || this.filterQuarter || this.filterSignStatus || this.filterSapCode;
    }

    get displayedCount() {
        return this.filteredData.length;
    }

    // ── Filter handlers ──────────────────────────────────────────
    handleYearChange(event) {
        this.filterYear = event.detail.value;
        this.applyFilters();
    }

    handleQuarterChange(event) {
        this.filterQuarter = event.detail.value;
        this.applyFilters();
    }

    handleSignStatusChange(event) {
        this.filterSignStatus = event.detail.value;
        this.applyFilters();
    }

    handleSapCodeChange(event) {
        this.filterSapCode = event.target.value;
        this.applyFilters();
    }

    handleResetFilters() {
        this.filterYear       = '';
        this.filterQuarter    = '';
        this.filterSignStatus = '';
        this.filterSapCode    = '';
        this.applyFilters();
    }

    handleRemoveFilter(event) {
        const f = event.currentTarget.dataset.filter;
        if (f === 'year')       this.filterYear       = '';
        if (f === 'quarter')    this.filterQuarter    = '';
        if (f === 'signStatus') this.filterSignStatus = '';
        if (f === 'sapCode')    this.filterSapCode    = '';
        this.applyFilters();
    }

    // ── Parse Q and Year from ledgerName: CL-<code>-Q1-2025 ─────
    parseLedgerMeta(ledgerName) {
        if (!ledgerName) return { quarter: '', year: '' };
        // matches Q1/Q2/Q3/Q4 and 4-digit year anywhere in the string
        const qMatch = (ledgerName.match(/Q([1-4])/i) || [])[0] || '';
        const yMatch = (ledgerName.match(/\b(20\d{2})\b/) || [])[1] || '';
        return { quarter: qMatch.toUpperCase(), year: yMatch };
    }

    // ── Apply filters: recompute filteredData + reset to page 1 ──
    applyFilters() {
        const sapCode = this.filterSapCode.toLowerCase();

        this.filteredData = this.ledgerData.filter(row => {
            const meta = this.parseLedgerMeta(row.ledgerName);
            const matchYear       = !this.filterYear       || meta.year    === this.filterYear;
            const matchQuarter    = !this.filterQuarter    || meta.quarter === this.filterQuarter;
            const matchSignStatus = !this.filterSignStatus || row.signStatus === this.filterSignStatus;
            const matchSapCode    = !sapCode || (row.sapCode || '').toLowerCase().includes(sapCode);
            return matchYear && matchQuarter && matchSignStatus && matchSapCode;
        });

        this.totalPages = Math.max(1, Math.ceil(this.filteredData.length / this.pageSize));
        this.pageNumber = 1;
        this.updateFilteredPageData();
        // NOTE: showEmptyState is reserved for "no base records at all".
        // Empty-due-to-filter is handled separately via hasFilteredResults
        // in the template, so we do NOT set showEmptyState here.
    }

    // ── Remove sent rows from table ──────────────────────────────
    removeRows(ledgerIds) {
        const sentSet = new Set(ledgerIds);
        this.ledgerData = this.ledgerData.filter(item => !sentSet.has(item.ledgerId));
        this.selectedRows = [];
        this.isAllSelected = false;
        this.applyFilters();

        if (this.ledgerData.length === 0) {
            this.showEmptyState = true;
            this.successMessage = 'All pending statements have been sent. Click Refresh to reload.';
        }
    }

    // ── Download PDF ─────────────────────────────────────────────
    handleDownloadPdf(event) {
        const versionId = event.currentTarget.dataset.version;
        if (versionId) {
            window.open('/sfc/servlet.shepherd/version/download/' + versionId, '_blank');
        } else {
            this.showToast('Warning', 'No PDF available for this record.', 'warning');
        }
    }

    // ── Status badge classes ─────────────────────────────────────
    getStatusClass(status) {
        if (!status) return 'status-badge info';
        const s = status.toLowerCase();
        if (s === 'draft')    return 'status-badge warning';
        if (s === 'complete') return 'status-badge success';
        if (s === 'error')    return 'status-badge error';
        return 'status-badge info';
    }

    getSignStatusClass(status) {
        if (!status) return 'status-badge info';
        const s = status.toLowerCase();
        if (s === 'pending')  return 'status-badge warning';
        if (s === 'signed')   return 'status-badge success';
        if (s === 'rejected') return 'status-badge error';
        return 'status-badge info';
    }

    // ── Toast ────────────────────────────────────────────────────
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
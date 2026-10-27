import { LightningElement, track } from 'lwc';
import getAllLedgers from '@salesforce/apex/SAPLedgerService.getAllLedgers';
import deleteLedgers from '@salesforce/apex/SAPLedgerService.deleteLedgers';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const STATUS_VALUES = ['Fetched', 'Sent', 'Completed', 'Declined', 'Expired'];

const STATUS_LABEL_MAP = {
    Fetched:   'Fetched',
    Sent:      'Sent for Sign',
    Completed: 'Signed',
    Declined:  'Declined',
    Expired:   'Expired'
};

// CSS classes per status.
const STATUS_CLASS_MAP = {
    Fetched:   'status-badge info',
    Sent:      'status-badge warning',
    Completed: 'status-badge success',
    Declined:  'status-badge error',
    Expired:   'status-badge info'
};

// Status value that represents a fully signed / completed ledger.
const SIGNED_STATUS = 'Completed';

export default class AdminLedgerView extends LightningElement {

    @track allData        = [];
    @track filteredData   = [];
    @track pagedData      = [];
    @track isLoading      = false;
    @track error          = '';
    @track successMessage = '';
    @track showEmptyState = false;

    sortDirection = 'asc';

    // filters
    searchText   = '';
    filterStatus = '';
    filterYear   = '';
    filterQuarter = '';
    filterSapCode = '';

    // pagination
    pageSize   = 15;
    pageNumber = 1;
    totalPages = 1;

    // selection
    selectedRows  = [];
    isAllSelected = false;

    // delete modal
    @track showDeleteModal   = false;
    @track deleteTargetCount = 0;
    pendingDeleteIds = [];

    // preview modal
    @track showPreviewModal  = false;
    @track previewUrl        = '';
    @track previewVersionId  = '';
    @track previewLedgerName = '';

    connectedCallback() {
        this.loadRecords();
    }

    loadRecords() {
        this.isLoading      = true;
        this.error          = '';
        this.successMessage = '';
        this.showEmptyState = false;

        getAllLedgers()
            .then(data => {
                this.allData = (data || []).map(item => {
                    const status = item.ledgerStatus || item.status || '';
                    const isSigned = status === SIGNED_STATUS;
                    return {
                        ...item,
                        selected:      false,
                        ledgerStatus:  status || '—',
                        ledgerStatusClass: STATUS_CLASS_MAP[status] || 'status-badge info',
                        statusLabel:   STATUS_LABEL_MAP[status] || status || '—',
                        contactName:   item.contactName  || '—',
                        contactEmail:  item.contactEmail || '—',
                        sapCode:       item.sapCode || '—',
                        fromDateLabel: item.fromDate || '—',
                        toDateLabel:   item.statementDate || item.toDate || '—',
                        statementDateLabel: item.statementDate || '—',
                        // Download is only allowed once the ledger has been signed.
                        canDownload:     isSigned && !!item.versionId,
                        downloadDisabled: !(isSigned && !!item.versionId),
                        // Signed ledgers cannot be deleted.
                        canDelete:       !isSigned,
                        selectDisabled:  isSigned
                    };
                });
                this.applyFilters();
                this.isLoading = false;
            })
            .catch(err => {
                this.error     = err?.body?.message || 'Error loading records.';
                this.isLoading = false;
            });
    }

    get statusOptions() {
        return [
            { label: 'All Statuses', value: '' },
            ...STATUS_VALUES.map(v => ({ label: STATUS_LABEL_MAP[v], value: v }))
        ];
    }

    handleYearChange(event) {
        this.filterYear = event.detail.value;
        this.applyFilters();
    }

    handleQuarterChange(event) {
        this.filterQuarter = event.detail.value;
        this.applyFilters();
    }

    handleSapCodeChange(event) {
        this.filterSapCode = event.target.value;
        this.applyFilters();
    }

    get hasActiveFilters() {
        return this.searchText || this.filterStatus || this.filterYear || this.filterQuarter || this.filterSapCode;
    }

    get activeFilterCount() {
        return [this.searchText, this.filterStatus, this.filterYear, this.filterQuarter, this.filterSapCode]
            .filter(Boolean).length;
    }

    get quarterOptions() {
        return [
            { label: 'All Quarters', value: '' },
            { label: 'Q1 (Jan - Mar)', value: 'Q1' },
            { label: 'Q2 (Apr - Jun)', value: 'Q2' },
            { label: 'Q3 (Jul - Sep)', value: 'Q3' },
            { label: 'Q4 (Oct - Dec)', value: 'Q4' }
        ];
    }

    get yearOptions() {
        const currentYear = new Date().getFullYear();
        const years = [{ label: 'All Years', value: '' }];

        for (let i = currentYear; i >= currentYear - 5; i--) {
            years.push({ label: i.toString(), value: i.toString() });
        }

        return years;
    }

    handleSearchChange(event) {
        this.searchText = event.target.value;
        this.applyFilters();
    }

    handleStatusChange(event) {
        this.filterStatus = event.detail.value;
        this.applyFilters();
    }

    handleRemoveFilter(event) {
        const f = event.currentTarget.dataset.filter;
        if (f === 'search')  this.searchText   = '';
        if (f === 'status')  this.filterStatus = '';
        if (f === 'year')    this.filterYear   = '';
        if (f === 'quarter') this.filterQuarter = '';
        if (f === 'sapCode') this.filterSapCode = '';
        this.applyFilters();
    }

    handleResetFilters() {
        this.searchText    = '';
        this.filterStatus  = '';
        this.filterYear    = '';
        this.filterQuarter = '';
        this.filterSapCode = '';
        this.applyFilters();
    }

    // For the active-filter chip, show the friendly label rather than the raw value.
    get filterStatusLabel() {
        return STATUS_LABEL_MAP[this.filterStatus] || this.filterStatus;
    }

    applyFilters() {
        const search  = this.searchText.toLowerCase();
        const sapCode = this.filterSapCode.toLowerCase();

        this.filteredData = this.allData.filter(row => {
            const matchSearch = !search
                || (row.accountName || '').toLowerCase().includes(search)
                || (row.ledgerName  || '').toLowerCase().includes(search);

            const matchStatus = !this.filterStatus || row.ledgerStatus === this.filterStatus;

            const matchSapCode = !sapCode
                || (row.sapCode || '').toLowerCase().includes(sapCode);

            const date  = new Date(row.createdDate);
            const year  = isNaN(date) ? '' : date.getFullYear().toString();
            const month = isNaN(date) ? -1 : date.getMonth() + 1;

            let quarter = '';
            if (month >= 1 && month <= 3)  quarter = 'Q1';
            else if (month >= 4 && month <= 6)  quarter = 'Q2';
            else if (month >= 7 && month <= 9)  quarter = 'Q3';
            else if (month >= 10 && month <= 12) quarter = 'Q4';

            const matchYear    = !this.filterYear    || year === this.filterYear;
            const matchQuarter = !this.filterQuarter || quarter === this.filterQuarter;

            return matchSearch && matchStatus && matchYear && matchQuarter && matchSapCode;
        });

        this.totalPages = Math.max(1, Math.ceil(this.filteredData.length / this.pageSize));
        this.pageNumber = 1;
        this.isAllSelected = false;
        this.selectedRows  = [];
        this.updatePageData();
        this.showEmptyState = this.filteredData.length === 0 && !this.isLoading;
    }

    handleSortAccountName() {
        this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';

        this.allData = [...this.allData].sort((a, b) => {
            const nameA = (a.accountName || '').toLowerCase();
            const nameB = (b.accountName || '').toLowerCase();
            return this.sortDirection === 'asc'
                ? nameA.localeCompare(nameB)
                : nameB.localeCompare(nameA);
        });

        this.applyFilters();
    }

    get sortArrow() {
        return this.sortDirection === 'asc' ? '↑' : '↓';
    }

    updatePageData() {
        const start = (this.pageNumber - 1) * this.pageSize;
        this.pagedData = this.filteredData.slice(start, start + this.pageSize);
    }

    handleNext()     { if (this.pageNumber < this.totalPages) { this.pageNumber++; this.updatePageData(); } }
    handlePrevious() { if (this.pageNumber > 1)               { this.pageNumber--; this.updatePageData(); } }

    get disablePrevious() { return this.pageNumber === 1; }
    get disableNext()     { return this.pageNumber === this.totalPages; }
    get hasResults()      { return this.filteredData.length > 0; }
    get hasSelected()     { return this.selectedRows.length > 0; }

    get totalCount() { return this.allData.length; }

    get sentCount() {
        return this.allData.filter(r => r.ledgerStatus === 'Sent').length;
    }

    get signedCount() {
        return this.allData.filter(r => r.ledgerStatus === 'Completed').length;
    }

    get declinedCount() {
        return this.allData.filter(r => r.ledgerStatus === 'Declined').length;
    }

    get expiredCount() {
        return this.allData.filter(r => r.ledgerStatus === 'Expired').length;
    }

    // Only rows that are eligible for deletion (i.e. not Signed) can be selected/bulk-deleted.
    get selectableRows() {
        return this.filteredData.filter(item => item.canDelete);
    }

    handleSelectAll(event) {
        const checked      = event.target.checked;
        this.isAllSelected = checked;
        // Signed ledgers are never selectable, regardless of "select all".
        this.filteredData  = this.filteredData.map(item => ({
            ...item,
            selected: item.canDelete ? checked : false
        }));
        this.allData       = this.allData.map(item => {
            const match = this.filteredData.find(f => f.ledgerId === item.ledgerId);
            return match ? { ...item, selected: match.selected } : item;
        });
        this.updatePageData();
        this.updateSelectedRows();
    }

    handleRowSelect(event) {
        const ledgerId = event.target.dataset.id;
        const checked  = event.target.checked;
        this.filteredData = this.filteredData.map(item =>
            item.ledgerId === ledgerId && item.canDelete ? { ...item, selected: checked } : item
        );
        this.allData = this.allData.map(item =>
            item.ledgerId === ledgerId && item.canDelete ? { ...item, selected: checked } : item
        );
        this.updatePageData();
        this.updateSelectedRows();
    }

    updateSelectedRows() {
        this.selectedRows  = this.filteredData.filter(item => item.selected);
        this.isAllSelected = this.selectableRows.length > 0 &&
                             this.selectableRows.every(item => item.selected);
    }

    handleDeleteRow(event) {
        const ledgerId = event.currentTarget.dataset.id;
        const row = this.allData.find(r => r.ledgerId === ledgerId);
        if (row && !row.canDelete) {
            this.showToast('Warning', 'Signed ledgers cannot be deleted.', 'warning');
            return;
        }
        this.pendingDeleteIds  = [ledgerId];
        this.deleteTargetCount = 1;
        this.showDeleteModal   = true;
    }

    handleBulkDelete() {
        // Guard against any signed rows that may have slipped into the selection.
        const deletableSelected = this.selectedRows.filter(r => r.canDelete);
        this.pendingDeleteIds  = deletableSelected.map(r => r.ledgerId);
        this.deleteTargetCount = this.pendingDeleteIds.length;
        this.showDeleteModal   = true;
    }

    handleCancelDelete() {
        this.showDeleteModal  = false;
        this.pendingDeleteIds = [];
    }

    handleConfirmDelete() {
        this.showDeleteModal = false;
        this.isLoading       = true;

        deleteLedgers({ ledgerIds: this.pendingDeleteIds })
            .then(() => {
                const deletedSet = new Set(this.pendingDeleteIds);
                this.allData     = this.allData.filter(r => !deletedSet.has(r.ledgerId));
                this.pendingDeleteIds = [];
                this.selectedRows     = [];
                this.isAllSelected    = false;
                this.applyFilters();
                this.isLoading       = false;
                this.successMessage  = 'Record(s) deleted successfully.';
                setTimeout(() => { this.successMessage = ''; }, 4000);
            })
            .catch(err => {
             this.isLoading = false;
             const message = err?.body?.message || 'Error deleting record(s).';

            if (message.includes('Current year ledgers cannot be deleted')) {
               this.showToast('Error', message, 'error');
            } else {
               this.error = message;
            }
            });
    }

    handlePreview(event) {
        const versionId = event.currentTarget.dataset.version;
        const name      = event.currentTarget.dataset.name;
        if (!versionId) {
            this.showToast('Warning', 'No PDF available to preview.', 'warning');
            return;
        }
        this.previewVersionId  = versionId;
        this.previewLedgerName = name;
        this.previewUrl        = '/sfc/servlet.shepherd/version/renditionDownload' + '?rendition=THUMB720BY480' + '&versionId=' + versionId;
        this.showPreviewModal  = true;
    }

    handleClosePreview() {
        this.showPreviewModal = false;
        this.previewUrl       = '';
        this.previewVersionId = '';
    }

    handleDownloadFromPreview() {
        const row = this.allData.find(r => r.versionId === this.previewVersionId);
        if (row && !row.canDownload) {
            this.showToast('Warning', 'Download is only available once the ledger is signed.', 'warning');
            return;
        }
        if (this.previewVersionId) {
            window.open('/sfc/servlet.shepherd/version/download/' + this.previewVersionId, '_blank');
        }
    }

    handleDownload(event) {
        const versionId = event.currentTarget.dataset.version;
        const ledgerId  = event.currentTarget.dataset.id;
        const row = this.allData.find(r => r.ledgerId === ledgerId);

        if (row && !row.canDownload) {
            this.showToast('Warning', 'Download is only available once the ledger is signed.', 'warning');
            return;
        }
        if (versionId) {
            window.open('/sfc/servlet.shepherd/version/download/' + versionId, '_blank');
        } else {
            this.showToast('Warning', 'No PDF available.', 'warning');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
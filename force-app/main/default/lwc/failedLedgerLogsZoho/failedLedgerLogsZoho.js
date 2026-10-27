import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFailedLedgerLogs from '@salesforce/apex/SAPLedgerService.getFailedLedgerLogs';
import sendForSign from '@salesforce/apex/SAPLedgerService.sendForSign';
import sendSelectedForSign from '@salesforce/apex/SAPLedgerService.sendSelectedForSign';
import retrySAPBatch from '@salesforce/apex/SAPLedgerService.retrySAPBatch';
import getBatchJobStatus from '@salesforce/apex/SAPLedgerService.getBatchJobStatus';
import getProcessedAccounts from '@salesforce/apex/SAPLedgerService.getProcessedAccounts';

// How many records to show per page
const PAGE_SIZE = 10;

export default class FailedLedgerLogsZoho extends NavigationMixin(LightningElement) {

    @track logs           = [];
    @track filteredLogs   = [];   // full filtered list
    @track visibleLogs    = [];   // current page slice shown in table
    @track isLoading      = true;
    @track hasError       = false;
    @track errorMessage   = '';
    @track showModal      = false;
    @track selectedLog    = {};
    @track selectedRowIds = [];
    @track isSending      = false;
    @track isRetrying     = false;
    @track retryProgressText = 'Fetching Ledger from SAP...';

    pollingInterval = null;
    pollingCount = 0;
    MAX_POLLS = 30;
    currentJobId = '';
    activeStatementDate = '';
    activeAccountIds = [];

    // Current page (1-indexed)
    @track currentPage = 1;
    pageSize = PAGE_SIZE;

    statementDate = '';
    searchTerm    = '';
    triggeredByFilter = '';

    // ─── Getters ─────────────────────────────────────────────────────────────

    get viewTitle() {
        return this.triggeredByFilter === 'SAP' ? 'SAP' : 'Ledger';
    }

    get hasRecords() {
        return this.filteredLogs && this.filteredLogs.length > 0;
    }

    get hasSelectedRows() {
        return this.selectedRowIds.length > 0;
    }

    get sendSelectedLabel() {
        return this.isSAPView
            ? `Fetch Ledger (${this.selectedRowIds.length})`
            : `Send Selected (${this.selectedRowIds.length})`;
    }

    get sendRowLabel() {
        return this.isSAPView ? 'Fetch Ledger' : 'Send';
    }

    get sendRowTitle() {
        return this.isSAPView ? 'Fetch Ledger from SAP' : 'Re-send to SAP';
    }

    get filteredCount() {
        return this.filteredLogs.length;
    }

    /** Total number of pages given the current filtered list */
    get totalPages() {
        return Math.max(1, Math.ceil(this.filteredLogs.length / this.pageSize));
    }

    /** "Page X of Y" text shown in the footer */
    get pageIndicator() {
        return `Page ${this.currentPage} of ${this.totalPages}`;
    }

    get isPreviousDisabled() {
        return this.currentPage <= 1;
    }

    get isNextDisabled() {
        return this.currentPage >= this.totalPages;
    }

    /** 1-indexed position of the first record on the current page */
    get rangeStart() {
        return this.filteredLogs.length === 0
            ? 0
            : (this.currentPage - 1) * this.pageSize + 1;
    }

    /** 1-indexed position of the last record on the current page */
    get rangeEnd() {
        return Math.min(this.currentPage * this.pageSize, this.filteredLogs.length);
    }

    /**
     * True when every currently-visible row is checked.
     * Used to drive the indeterminate / checked state of the header checkbox.
     */
    get isAllSelected() {
        if (!this.visibleLogs || this.visibleLogs.length === 0) return false;
        return this.visibleLogs.every(r => this.selectedRowIds.includes(r.Id));
    }

    get selectAllTitle() {
        return this.isAllSelected ? 'Deselect all visible rows' : 'Select all visible rows';
    }

    get isZohoView() {
        return this.triggeredByFilter !== 'SAP';
    }

    get isSAPView() {
        return this.triggeredByFilter === 'SAP';
    }

    get allBtnClass() {
        return `segment-btn ${this.triggeredByFilter === '' ? 'active' : ''}`;
    }

    get zohoBtnClass() {
        return `segment-btn ${this.triggeredByFilter === 'Zoho' ? 'active' : ''}`;
    }

    get sapBtnClass() {
        return `segment-btn ${this.triggeredByFilter === 'SAP' ? 'active' : ''}`;
    }

    get isAllView() {
        return this.triggeredByFilter === '';
    }

    /** Status column header text: "Status" for All, "Zoho Status" for Zoho, "SAP Status" for SAP */
    get statusColumnLabel() {
        if (this.triggeredByFilter === '') return 'Status';
        if (this.triggeredByFilter === 'Zoho') return 'Zoho Status';
        return 'SAP Status';
    }

    // ─── Lifecycle ───────────────────────────────────────────────────────────

    connectedCallback() {
        this.loadLogs();
    }

    mapSapStatus(code) {
        switch (code) {
            case 'S': return 'Success';
            case 'E': return 'Error';
            default:  return code ?? '—';
        }
    }

    async loadLogs() {
        this.isLoading      = true;
        this.hasError       = false;
        this.currentPage    = 1;
        this.selectedRowIds = [];

        try {
            const raw = await getFailedLedgerLogs();
            this.logs = raw.map(log => {
                const accountName = log.Account__r?.Name 
                    || log.Customer_Ledger__r?.Account__r?.Name 
                    || '—';
                const accountId = log.Account__r?.Id 
                    || log.Customer_Ledger__r?.Account__r?.Id 
                    || log.Customer_Ledger__r?.Account__c 
                    || null;
                const sapCode = log.Customer_Code__c
                    || log.Account__r?.SAP_Code__c 
                    || log.Customer_Ledger__r?.Customer_Code__c 
                    || log.Customer_Ledger__r?.Account__r?.SAP_Code__c 
                    || '—';
                const companyCode = log.Company_Code__c 
                    || log.Customer_Ledger__r?.Company_Code__c 
                    || '';

                return {
                    ...log,
                    AccountName:    accountName,
                    AccountId:      accountId,
                    AccountUrl:     accountId ? `/lightning/r/Account/${accountId}/view` : null,
                    LedgerName:     log.Customer_Ledger__r?.Customer_Name__c ?? '—',
                    CompanyCode:    companyCode,
                    SAPCode:        sapCode,
                    Remarks__c:     log.Remarks__c ?? '—',
                    HTTPStatusCode: log.HTTP_Status_Code__c ?? '—',
                    SAPStatusLabel: this.mapSapStatus(log.SAP_Response_Status__c),
                    Quarter:        log.Quarter__c ?? '—',
                    FromDate:       log.From_Date__c ?? '—',
                    StatementDate:  log.Statement_Date__c ?? '—',
                    LoggedAt: log.CreatedDate
                        ? new Date(log.CreatedDate).toLocaleString('en-US', {
                            timeZone: 'Asia/Kolkata',
                            year: 'numeric',
                            month: 'long',
                            day: 'numeric',
                            hour: 'numeric',
                            minute: '2-digit',
                            second: '2-digit',
                            hour12: true
                        }) + ' IST'
                        : '—',
                    isSelected: false,
                    hasError: false,
                    inputClass: 'custom-code-input'
                };
            });
            this.applyFilters();
        } catch (e) {
            this.hasError     = true;
            this.errorMessage = e?.body?.message ?? 'Unknown error loading ledger logs.';
        } finally {
            this.isLoading = false;
        }
    }

    handleCompanyCodeChange(event) {
        const id  = event.target.dataset.id;
        const val = event.target.value;
        const updateCode = r => r.Id === id
            ? {
                  ...r,
                  CompanyCode: val,
                  hasError: val && val.trim() ? false : r.hasError,
                  inputClass: (val && val.trim() ? 'custom-code-input' : (r.hasError ? 'custom-code-input code-input-error' : 'custom-code-input'))
              }
            : r;
        this.logs         = this.logs.map(updateCode);
        this.filteredLogs = this.filteredLogs.map(updateCode);
        this.visibleLogs  = this.visibleLogs.map(updateCode);
    }

    // ─── Filters & pagination slice ──────────────────────────────────────────

    handleSearch(e) {
        this.searchTerm  = e.detail.value.toLowerCase();
        this.currentPage = 1;
        this.applyFilters();
    }

    handleTriggerChange(event) {
        this.triggeredByFilter = event.currentTarget.dataset.value;
        this.currentPage       = 1;
        this.selectedRowIds    = [];
        this.applyFilters();
    }

    handleDateChange(event) {
        this.statementDate = event.target.value;
    }

    applyFilters() {
        let result = [...this.logs];

        // Search filter
        if (this.searchTerm) {
            result = result.filter(log =>
                (log.AccountName ?? '').toLowerCase().includes(this.searchTerm) ||
                (log.SAPCode ?? '').toLowerCase().includes(this.searchTerm) ||
                String(log.HTTPStatusCode ?? '').toLowerCase().includes(this.searchTerm)
            );
        }

        // Triggered By filter
        if (this.triggeredByFilter) {
            result = result.filter(
                log => log.Triggered_By__c === this.triggeredByFilter
            );
        }

        const selectedSet = new Set(this.selectedRowIds);

        this.filteredLogs = result.map(r => ({
            ...r,
            isSelected: selectedSet.has(r.Id),
            rowClass: selectedSet.has(r.Id) ? 'table-row row-selected' : 'table-row'
        }));

        const visibleIds = new Set(this.filteredLogs.map(r => r.Id));
        this.selectedRowIds = this.selectedRowIds.filter(id => visibleIds.has(id));
        this.currentPage = Math.min(this.currentPage, this.totalPages);
        this.updateVisibleSlice();
    }

    /** Slice filteredLogs down to the current page */
    updateVisibleSlice() {
        const start = (this.currentPage - 1) * this.pageSize;
        this.visibleLogs = this.filteredLogs.slice(start, start + this.pageSize);
    }

    // ─── Pagination controls ─────────────────────────────────────────────────

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage -= 1;
            this.updateVisibleSlice();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage += 1;
            this.updateVisibleSlice();
        }
    }

    // ─── Select-All checkbox ──────────────────────────────────────────────────

    handleSelectAll(e) {
        const checked    = e.target.checked;
        const visibleIds = this.visibleLogs.map(r => r.Id);

        if (checked) {
            const toAdd = visibleIds.filter(id => !this.selectedRowIds.includes(id));
            this.selectedRowIds = [...this.selectedRowIds, ...toAdd];
        } else {
            const visibleSet = new Set(visibleIds);
            this.selectedRowIds = this.selectedRowIds.filter(id => !visibleSet.has(id));
        }

        this.syncSelectionState();
    }

    // ─── Row checkbox ─────────────────────────────────────────────────────────

    handleCheckboxChange(e) {
        const id      = e.target.dataset.id;
        const checked = e.target.checked;

        if (checked) {
            if (!this.selectedRowIds.includes(id)) {
                this.selectedRowIds = [...this.selectedRowIds, id];
            }
        } else {
            this.selectedRowIds = this.selectedRowIds.filter(r => r !== id);
        }

        this.syncSelectionState();
    }

    syncSelectionState() {
        const selectedSet = new Set(this.selectedRowIds);
        const sync = r => ({
            ...r,
            isSelected: selectedSet.has(r.Id),
            rowClass:   selectedSet.has(r.Id) ? 'table-row row-selected' : 'table-row'
        });
        this.filteredLogs = this.filteredLogs.map(sync);
        this.visibleLogs  = this.visibleLogs.map(sync);
    }

    // ─── Row actions ──────────────────────────────────────────────────────────

    handleViewDetails(e) {
        const id  = e.currentTarget.dataset.id;
        const row = this.filteredLogs.find(r => r.Id === id);
        if (row) {
            this.selectedLog = row;
            this.showModal   = true;
        }
    }

    // ─── Send selected rows ───────────────────────────────────────────────────

    handleSendSelected() {
        if (this.isSAPView) {
            this.handleSendSelectedSAP();
        } else {
            this.handleSendSelectedZoho();
        }
    }

    // SAP → calls retrySAPBatch (bulk)
    handleSendSelectedSAP() {
        if (!this.selectedRowIds.length) {
            this.showToast('Warning', 'Please select at least one record.', 'warning');
            return;
        }

        const selectedLogs = this.filteredLogs.filter(l => this.selectedRowIds.includes(l.Id));
        const accountIds   = [...new Set(selectedLogs.map(l => l.AccountId).filter(Boolean))];

        if (!accountIds.length) {
            this.showToast('Warning', 'No valid Account IDs found for selected records.', 'warning');
            return;
        }

        // Validate Company Code for selected rows
        const missingCode = selectedLogs.filter(l => !l.CompanyCode || !l.CompanyCode.trim());
        if (missingCode.length > 0) {
            const missingIds = new Set(missingCode.map(l => l.Id));
            const markError = r => missingIds.has(r.Id) ? { ...r, hasError: true, inputClass: 'custom-code-input code-input-error' } : r;
            this.logs = this.logs.map(markError);
            this.filteredLogs = this.filteredLogs.map(markError);
            this.visibleLogs = this.visibleLogs.map(markError);
            this.showToast('Missing Company Code', 'Please enter Company Code for all selected records before retrying.', 'warning');
            return;
        }

        const accountCompanyCodes = {};
        selectedLogs.forEach(l => {
            if (l.AccountId) accountCompanyCodes[l.AccountId] = l.CompanyCode.trim();
        });

        // Pull quarter and dates directly from the selected failed logs
        const firstLog = selectedLogs[0];
        const formattedDate = firstLog?.Statement_Date__c
            ? String(firstLog.Statement_Date__c).replaceAll('-', '')
            : (this.statementDate ? this.statementDate.replaceAll('-', '') : '');
        const formattedFromDate = firstLog?.From_Date__c
            ? String(firstLog.From_Date__c).replaceAll('-', '')
            : null;
        const quarter = firstLog?.Quarter__c || null;

        this.startRetryFlow(formattedDate, formattedFromDate, quarter, accountIds, accountCompanyCodes, selectedLogs);
    }

    // Zoho → calls sendSelectedForSign
    handleSendSelectedZoho() {
        if (!this.selectedRowIds.length) {
            this.showToast('Warning', 'Please select at least one record.', 'warning');
            return;
        }

        const selectedLogs = this.filteredLogs.filter(l => this.selectedRowIds.includes(l.Id));
        const accountIds   = [...new Set(selectedLogs.map(l => l.AccountId).filter(Boolean))];

        if (!accountIds.length) {
            this.showToast('Warning', 'No valid Account IDs found for selected records.', 'warning');
            return;
        }

        this.isSending = true;
        const formattedDate = this.statementDate ? this.statementDate.replaceAll('-', '') : '';

        sendSelectedForSign({ accountIds, statementDate: formattedDate })
            .then(result => {
                this.showToast('Success', result, 'success');
                const sentLogIds    = new Set(selectedLogs.map(l => l.Id));
                this.logs           = this.logs.filter(l => !sentLogIds.has(l.Id));
                this.filteredLogs   = this.filteredLogs.filter(l => !sentLogIds.has(l.Id));
                this.selectedRowIds = [];
                this.currentPage    = Math.min(this.currentPage, this.totalPages);
                this.updateVisibleSlice();
            })
            .catch(error => {
                this.showToast('Error', error?.body?.message || 'Unexpected error occurred', 'error');
            })
            .finally(() => {
                this.isSending = false;
            });
    }

    // ─── Row-level send ───────────────────────────────────────────────────────

    handleSendRow(event) {
        const id  = event.currentTarget.dataset.id;
        const row = this.filteredLogs.find(r => r.Id === id);
        if (!row) return;

        if (row.Triggered_By__c === 'SAP') {
            this.handleSendRowSAP(row);
        } else {
            this.handleSendRowZoho(row);
        }
    }

    // SAP row → retrySAPBatch (single row)
    handleSendRowSAP(row) {
        if (!row.CompanyCode || !row.CompanyCode.trim()) {
            const markError = r => r.Id === row.Id ? { ...r, hasError: true, inputClass: 'custom-code-input code-input-error' } : r;
            this.logs         = this.logs.map(markError);
            this.filteredLogs = this.filteredLogs.map(markError);
            this.visibleLogs  = this.visibleLogs.map(markError);
            this.showToast('Missing Company Code', 'Please enter the Company Code before retrying.', 'warning');
            return;
        }

        const accountCompanyCodes = {};
        accountCompanyCodes[row.AccountId] = row.CompanyCode.trim();

        const formattedDate = row.Statement_Date__c
            ? String(row.Statement_Date__c).replaceAll('-', '')
            : (this.statementDate ? this.statementDate.replaceAll('-', '') : '');
        const formattedFromDate = row.From_Date__c
            ? String(row.From_Date__c).replaceAll('-', '')
            : null;
        const quarter    = row.Quarter__c || null;
        const accountIds = [row.AccountId];

        this.startRetryFlow(formattedDate, formattedFromDate, quarter, accountIds, accountCompanyCodes, [row]);
    }

    startRetryFlow(formattedDate, formattedFromDate, quarter, accountIds, accountCompanyCodes, selectedLogs) {
        this.isRetrying = true;
        this.pollingCount = 0;
        this.retryProgressText = `Connecting to SAP for ${accountIds.length} account(s)...`;
        this.activeStatementDate = formattedDate;
        this.activeAccountIds = accountIds;

        retrySAPBatch({
            statementDate: formattedDate,
            fromDate: formattedFromDate,
            quarter: quarter,
            accountIds: accountIds,
            accountCompanyCodes: accountCompanyCodes
        })
            .then(jobId => {
                this.currentJobId = jobId;
                this.retryProgressText = `Processing SAP ledger generation...`;
                this.pollingInterval = setInterval(() => {
                    this.pollJobStatus();
                }, 3500);
            })
            .catch(error => {
                this.isRetrying = false;
                this.showToast('Error', error?.body?.message || 'Unexpected error starting retry batch', 'error');
            });
    }

    pollJobStatus() {
        this.pollingCount++;

        getBatchJobStatus({ jobId: this.currentJobId })
            .then(job => {
                const status    = job.status;
                const processed = job.processed || 0;
                const total     = job.total || 0;

                if (total > 0) {
                    const percent = Math.round((processed / total) * 100);
                    this.retryProgressText = `Fetching from SAP: chunk ${processed} of ${total} (${percent}%)...`;
                }

                if (status === 'Completed' || status === 'Failed' || status === 'Aborted') {
                    this.stopPolling();
                    this.loadRetryResults(status);
                } else if (this.pollingCount >= this.MAX_POLLS) {
                    this.stopPolling();
                    this.isRetrying = false;
                    this.showToast(
                        'Processing in Background',
                        'Statement is being fetched in the background. Please check Pending Signatures shortly.',
                        'warning'
                    );
                    this.loadLogs();
                }
            })
            .catch(error => {
                console.error('Retry batch polling error:', error);
            });
    }

    stopPolling() {
        if (this.pollingInterval) {
            clearInterval(this.pollingInterval);
            this.pollingInterval = null;
        }
    }

    loadRetryResults(jobStatus) {
        getProcessedAccounts({
            statementDate: this.activeStatementDate,
            accountIds: this.activeAccountIds,
            jobId: this.currentJobId
        })
            .then(data => {
                this.isRetrying = false;
                if (data && data.length > 0) {
                    this.showToast(
                        'Success',
                        `${data.length} statement(s) fetched successfully! Redirecting to Pending Signatures...`,
                        'success'
                    );
                    this.loadLogs();
                    setTimeout(() => {
                        this.dispatchEvent(new CustomEvent('navigatetopending'));
                    }, 1200);
                } else {
                    this.showToast(
                        'Fetch Failed',
                        'Unable to fetch statement from SAP. Check error details in the log.',
                        'warning'
                    );
                    this.loadLogs();
                }
            })
            .catch(error => {
                this.isRetrying = false;
                this.showToast('Error', error?.body?.message || 'Error checking statement results', 'error');
                this.loadLogs();
            });
    }

    // Zoho row → sendForSign (single account)
    handleSendRowZoho(row) {
        const accountId     = row.AccountId;
        const formattedDate = this.statementDate ? this.statementDate.replaceAll('-', '') : '';

        if (!accountId) {
            this.showToast('Warning', 'No linked Account found for this record.', 'warning');
            return;
        }

        sendForSign({ accountId, statementDate: formattedDate })
            .then(result => {
                this.showToast('Success', result, 'success');
                this.logs           = this.logs.filter(l => l.Id !== row.Id);
                this.filteredLogs   = this.filteredLogs.filter(l => l.Id !== row.Id);
                this.selectedRowIds = this.selectedRowIds.filter(id => id !== row.Id);
                this.currentPage    = Math.min(this.currentPage, this.totalPages);
                this.updateVisibleSlice();
            })
            .catch(error => { this.showToast('Error', error?.body?.message || 'Error sending for sign', 'error'); });
    }

    // ─── Modal ────────────────────────────────────────────────────────────────

    closeModal() {
        this.showModal   = false;
        this.selectedLog = {};
    }

    handleOverlayClick(e) {
        if (e.target === e.currentTarget) this.closeModal();
    }

    navigateToLedger() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.selectedLog.Customer_Ledger__c, actionName: 'view' }
        });
    }

    // ─── Toast ────────────────────────────────────────────────────────────────

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
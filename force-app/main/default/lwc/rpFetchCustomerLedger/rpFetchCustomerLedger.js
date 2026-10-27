import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import startLedgerBatch from '@salesforce/apex/SAPLedgerService.startLedgerBatch';
import getProcessedAccounts from '@salesforce/apex/SAPLedgerService.getProcessedAccounts';
import getBatchJobStatus from '@salesforce/apex/SAPLedgerService.getBatchJobStatus';
import sendForSign from '@salesforce/apex/SAPLedgerService.sendForSign';
import sendSelectedForSign from '@salesforce/apex/SAPLedgerService.sendSelectedForSign';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchAccounts from '@salesforce/apex/SAPLedgerService.searchAccounts';
import getStatementDateByQuarter from '@salesforce/apex/SAPLedgerService.getStatementDateByQuarter';
import getContentVersionId from '@salesforce/apex/SAPLedgerService.getContentVersionId';

export default class CustomerLedger extends NavigationMixin(LightningElement) {

    fromDate = '';     
    statementDate = '';
    selectedQuarter = '';
    accountPageSize = 15;
    accountPageNumber = 1;
    accountTotalPages = 1;
    @track pagedAccountList = [];

    @track ledgerData = [];
    @track isLoading = false;
    @track isSending = false;
    @track pagedData = [];
    @track showResultsPage = false;
    @track showPreviewModal   = false;
    @track previewUrl         = '';
    @track previewAccountName = '';
    @track previewVersionId   = '';
    @track batchProgressSubtitle = 'Retrieving data from SAP and preparing statements. Please wait.';
    
    pageSize = 15; 
    pageNumber = 1;
    totalPages = 1;

    pollingInterval;
    pollingCount = 0;
    MAX_POLLS = 100;
    currentJobId;

    activeStatementDate;
    activeAccountIds = [];
    selectedRows = [];
    isAllSelected = false;

    accountName = '';
    sapCode = '';
    regionId = '';

    @track accountList = [];
    @track selectedAccountIds = [];

    get hasResults() {
        return this.ledgerData && this.ledgerData.length > 0;
    }

    get quarterOptions() {
        return [
            { label: 'Q1', value: 'Q1' },
            { label: 'Q2', value: 'Q2' },
            { label: 'Q3', value: 'Q3' },
            { label: 'Q4', value: 'Q4' }
        ];
    }

    handleQuarterChange(event) {
        this.selectedQuarter = event.detail.value;
        this.statementDate = '';
        this.fromDate = '';
        
        if (!this.selectedQuarter) return;

        getStatementDateByQuarter({ quarter: this.selectedQuarter })
            .then(result => {
                if (result) {
                    this.statementDate = result.statementDate || '';
                    this.fromDate = result.fromDate || '';
                }
            })
            .catch(error => {
                this.statementDate = '';
                this.fromDate = '';
                this.showToast(
                    'Error',
                    error.body?.message || 'No statement dates configured for this quarter.',
                    'error'
                );
            });
    }

    get isSendDisabled() {
        return this.selectedRows.length === 0 || this.isSending;
    }

    get hasActiveFilters() {
        return (
            this.selectedQuarter ||
            this.accountName ||
            this.sapCode ||
            this.regionId ||
            this.selectedAccountIds.length > 0
        );
    }

    get isFetchDisabled() {
        return (
            !this.statementDate ||
            !this.fromDate ||
            this.selectedAccountIds.length === 0 ||
            this.selectedAccountIds.length > 1 ||
            this.isLoading
        );
    }

    updateAccountPageData() {
        const start = (this.accountPageNumber - 1) * this.accountPageSize;
        const end = start + this.accountPageSize;
        this.pagedAccountList = this.accountList.slice(start, end).map(acc => ({
            ...acc,
            inputClass: acc.hasError ? 'custom-code-input code-input-error' : 'custom-code-input'
        }));
    }

    handleAccountNext() {
        if (this.accountPageNumber < this.accountTotalPages) {
            this.accountPageNumber++;
            this.updateAccountPageData();
        }
    }

    handleAccountPrevious() {
        if (this.accountPageNumber > 1) {
            this.accountPageNumber--;
            this.updateAccountPageData();
        }
    }

    get disableAccountPrevious() {
        return this.accountPageNumber === 1;
    }

    get disableAccountNext() {
        return this.accountPageNumber === this.accountTotalPages;
    }

    get accountPageStartRecord() {
        if (this.accountList.length === 0) return 0;
        return (this.accountPageNumber - 1) * this.accountPageSize + 1;
    }

    get accountPageEndRecord() {
        return Math.min(this.accountPageNumber * this.accountPageSize, this.accountList.length);
    }

    get totalAccountsCount() {
        return this.accountList.length;
    }

    get isAllAccountsSelected() {
        return this.accountList.length > 0 && this.accountList.every(acc => acc.selected);
    }

    handleAccountName(event) {
        this.accountName = event.target.value;
    }

    handleSapCode(event) {
        this.sapCode = event.target.value;
    }

    handleResetFilters() {
        this.selectedQuarter = '';
        this.fromDate = '';
        this.statementDate = '';
        this.accountName = '';
        this.sapCode = '';
        this.accountList = [];
        this.selectedAccountIds = [];
    }

    handleRemoveFilter(event) {
        const filter = event.currentTarget.dataset.filter;
        switch (filter) {
            case 'account':
                this.accountName = '';
                break;
            case 'sap':
                this.sapCode = '';
                break;
            case 'date':
                this.selectedQuarter = '';
                this.fromDate = '';
                this.statementDate = '';
                break;
            case 'selectedAccounts':
                this.selectedAccountIds = [];
                this.accountList = this.accountList.map(acc => ({ ...acc, selected: false, hasError: false }));
                this.updateAccountPageData();
                break;
        }
    }

    handleCompanyCodeChange(event) {
        const id = event.target.dataset.id;
        const val = event.target.value;
        this.accountList = this.accountList.map(acc =>
            acc.accountId === id
                ? {
                      ...acc,
                      companyCode: val,
                      hasError: val && val.trim() ? false : acc.hasError
                  }
                : acc
        );
        this.updateAccountPageData();
    }

    handleSearchAccount() {
        const currentCompCodeMap = new Map((this.accountList || []).map(acc => [acc.accountId, acc.companyCode]));
        searchAccounts({
            accountName: this.accountName,
            sapCode: this.sapCode
        })
            .then(result => {
                // Retain selection and entered companyCode for any accounts
                this.accountList = (result || []).map(row => ({
                    ...row,
                    companyCode: currentCompCodeMap.get(row.accountId) || '',
                    hasError: false,
                    selected: this.selectedAccountIds.includes(row.accountId)
                }));

                this.accountPageNumber = 1;
                this.accountTotalPages = Math.max(1, Math.ceil(this.accountList.length / this.accountPageSize));
                this.updateAccountPageData();
            })
            .catch(error => {
                this.showToast(
                    'Error',
                    error.body?.message || 'Unable to search accounts.',
                    'error'
                );
            });
    }

    handleFetchLedger() {
        if (!this.statementDate) {
            this.showToast('Warning', 'Please select a Statement Quarter.', 'warning');
            return;
        }

        if (!this.selectedAccountIds || this.selectedAccountIds.length === 0) {
            this.showToast('Warning', 'Please select at least one Account.', 'warning');
            return;
        }

        if (this.selectedAccountIds.length > 1) {
            this.showToast('Warning', 'You can only select 1 account at a time.', 'warning');
            return;
        }

        // Validate that all SELECTED accounts have a non-blank Company Code
        const selectedAccounts = this.accountList.filter(acc => this.selectedAccountIds.includes(acc.accountId));
        const missingCompCode = selectedAccounts.filter(acc => !acc.companyCode || !acc.companyCode.trim());

        if (missingCompCode.length > 0) {
            const missingIds = new Set(missingCompCode.map(a => a.accountId));
            this.accountList = this.accountList.map(acc => ({
                ...acc,
                hasError: missingIds.has(acc.accountId)
            }));
            this.updateAccountPageData();

            this.showToast(
                'Missing Company Code',
                'Please enter the Company Code for all selected accounts before fetching ledger.',
                'warning'
            );
            return;
        }

        const accountCompanyCodes = {};
        selectedAccounts.forEach(acc => {
            accountCompanyCodes[acc.accountId] = acc.companyCode.trim();
        });

        this.ledgerData = [];
        this.isLoading = true;
        this.pollingCount = 0;
        this.selectedRows = [];
        this.isAllSelected = false;
        this.batchProgressSubtitle = `Starting batch job for ${this.selectedAccountIds.length} account(s)...`;

        this.activeStatementDate = this.statementDate ? this.statementDate.replaceAll('-', '') : '';
        const formattedFromDate  = this.fromDate ? this.fromDate.replaceAll('-', '') : '';
        this.activeAccountIds    = [...this.selectedAccountIds];

        // Pass statementDate, fromDate, quarter, accountIds, and accountCompanyCodes to the Batch
        startLedgerBatch({
            statementDate: this.activeStatementDate,
            fromDate: formattedFromDate,
            quarter: this.selectedQuarter,
            accountIds: this.activeAccountIds,
            accountCompanyCodes: accountCompanyCodes
        })
            .then(jobId => {
                this.currentJobId = jobId;
                this.showToast(                   
                    `Fetching ledger statements for ${this.selectedAccountIds.length} account(s). You can check and send them anytime from the Pending Ledgers tab.`,
                    'warning'
                );

                this.pollingInterval = setInterval(() => {
                    this.pollJobStatus();
                }, 5000);
            })
            .catch(error => {
                this.showToast('Error', error?.body?.message || 'Unexpected error occurred starting batch', 'error');
                this.isLoading = false;
            });
    }

    pollJobStatus() {
        this.pollingCount++;

        getBatchJobStatus({ jobId: this.currentJobId })
            .then(job => {
                const status = job.status;
                const processed = job.processed || 0;
                const total = job.total || 0;

                if (total > 0) {
                    const percent = Math.round((processed / total) * 100);
                    this.batchProgressSubtitle = `Processing chunk ${processed} of ${total} (${percent}%). Statements can also be sent from Pending Ledgers.`;
                }

                if (status === 'Completed' || status === 'Failed' || status === 'Aborted') {
                    this.stopPolling();
                    this.loadResults(status);
                } 
                else if (this.pollingCount === 12) {
                    clearInterval(this.pollingInterval);
                    this.pollingInterval = setInterval(() => { this.pollJobStatus(); }, 10000);
                } 
                else if (this.pollingCount >= this.MAX_POLLS) {
                    this.stopPolling();
                    this.showToast(
                        'Processing in Background',
                        'Your batch is actively generating statements from SAP in the background. You can review and send them in the Pending Ledgers tab.',
                        'warning'
                    );
                    this.loadResults(status);
                }
            })
            .catch(error => {
                console.error('Batch polling error:', error);
            });
    }

    loadResults(jobStatus) {
        this.isLoading = false;

        getProcessedAccounts({
            statementDate: this.activeStatementDate,
            accountIds: this.activeAccountIds,
            jobId: this.currentJobId
        })
            .then(data => {
                this.ledgerData = (data || []).map(item => ({
                    ...item,
                    selected: false,
                    statusClass: this.getStatusClass(item.status),
                    contactName: item.contactName || '',
                    contactEmail: item.contactEmail || ''
                }));

                this.totalPages = Math.max(1, Math.ceil(this.ledgerData.length / this.pageSize));
                this.pageNumber = 1;
                this.updatePageData();
                this.showResultsPage = this.ledgerData.length > 0;

                if (jobStatus === 'Failed' || jobStatus === 'Aborted') {
                    this.showToast(
                        'Notice',
                        `Batch job ended (${jobStatus}). ${this.ledgerData.length} statement(s) generated. Check Failed Logs for details.`,
                        'warning'
                    );
                } else if (this.ledgerData.length > 0) {
                    this.showToast(
                        'Success',
                        `${this.ledgerData.length} statement(s) generated successfully and ready to sign.`,
                        'success'
                    );
                } else if (jobStatus === 'Completed') {
                    this.showToast(
                        'Notice',
                        'Batch completed. No new statements were generated. Check Failed Logs for details.',
                        'warning'
                    );
                }
            })
            .catch(error => {
                this.showToast('Error', error?.body?.message || 'Error fetching statement results', 'error');
            });
    }

    handleSendSelected() {
        if (!this.selectedRows || this.selectedRows.length === 0) {
            this.showToast('Warning', 'Please select at least one account.', 'warning');
            return;
        }

        const accountIds = this.selectedRows.map(row => row.accountId);
        const sentIds = new Set(accountIds);

        this.isSending = true;

        sendSelectedForSign({
            accountIds: accountIds,
            statementDate: this.statementDate ? this.statementDate.replaceAll('-', '') : ''
        })
            .then(result => {
                this.showToast('Success', result, 'success');
                this.isSending = false;

                this.ledgerData = this.ledgerData.filter(item => !sentIds.has(item.accountId));
                this.selectedRows = [];
                this.isAllSelected = false;
                this.totalPages = Math.max(1, Math.ceil(this.ledgerData.length / this.pageSize));
                if (this.pageNumber > this.totalPages) {
                    this.pageNumber = this.totalPages;
                }
                this.updatePageData();

                this.showToast('Redirecting', 'Statements sent! Redirecting to Pending Requests...', 'warning');

                setTimeout(() => {
                    this.dispatchEvent(new CustomEvent('navigatetopending'));
                }, 1200);
            })
            .catch(error => {
                this.showToast('Error', error?.body?.message || 'Unexpected error occurred', 'error');
                this.isSending = false;
            });
    }

    handleSendForSignRow(event) {
        const accountId = event.currentTarget.dataset.id;
        this.handleSendForSign(accountId);
    }

    handleSendForSign(accountId) {
        this.isSending = true;

        sendForSign({
            accountId: accountId,
            statementDate: this.statementDate ? this.statementDate.replaceAll('-', '') : ''
        })
            .then(result => {
                this.showToast('Success', result, 'success');
                this.isSending = false;

                this.ledgerData = this.ledgerData.filter(item => item.accountId !== accountId);
                this.selectedRows = this.selectedRows.filter(item => item.accountId !== accountId);
                this.totalPages = Math.max(1, Math.ceil(this.ledgerData.length / this.pageSize));
                
                if (this.pageNumber > this.totalPages) {
                    this.pageNumber = this.totalPages;
                }
                this.updatePageData();

                if (this.ledgerData.length === 0) {
                    this.showResultsPage = false;
                }
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Error sending request', 'error');
                this.isSending = false;
            });
    }

    updatePageData() {
        const start = (this.pageNumber - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.pagedData = this.ledgerData.slice(start, end);
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

    get disablePrevious() {
        return this.pageNumber === 1;
    }

    get disableNext() {
        return this.pageNumber === this.totalPages;
    }

    get pageStartRecord() {
        if (this.ledgerData.length === 0) return 0;
        return (this.pageNumber - 1) * this.pageSize + 1;
    }

    get pageEndRecord() {
        return Math.min(this.pageNumber * this.pageSize, this.ledgerData.length);
    }

    get totalRecordsCount() {
        return this.ledgerData.length;
    }

    getStatusClass(status) {
        if (!status) return 'status-badge';
        const s = status.toLowerCase();
        if (s.includes('complete') || s.includes('success') || s.includes('generated') || s.includes('processed')) {
            return 'status-badge success';
        }
        if (s.includes('fail') || s.includes('error') || s.includes('rejected')) {
            return 'status-badge error';
        }
        if (s.includes('pending') || s.includes('progress') || s.includes('polling')) {
            return 'status-badge warning';
        }
        return 'status-badge info';
    }

    handleAccountSelectAll(event) {
        const checked = event.target.checked;

        if (checked && this.accountList.length > 0) {
            const firstId = this.accountList[0].accountId;
            this.selectedAccountIds = [firstId];
            this.accountList = this.accountList.map(acc => ({
                ...acc,
                selected: acc.accountId === firstId
            }));
            this.showToast('Notice', 'Only 1 account can be selected at a time.', 'warning');
        } else {
            this.selectedAccountIds = [];
            this.accountList = this.accountList.map(acc => ({
                ...acc,
                selected: false
            }));
        }

        this.updateAccountPageData();
    }

    handleAccountRowSelect(event) {
        const id = event.target.dataset.id;
        const checked = event.target.checked;

        if (checked) {
            this.selectedAccountIds = [id];
            this.accountList = this.accountList.map(acc => ({
                ...acc,
                selected: acc.accountId === id
            }));
        } else {
            this.selectedAccountIds = [];
            this.accountList = this.accountList.map(acc => ({
                ...acc,
                selected: false
            }));
        }

        this.updateAccountPageData();
    }

    handleResultSelectAll(event) {
        const checked = event.target.checked;
        this.ledgerData = this.ledgerData.map(row => ({
            ...row,
            selected: checked
        }));
        this.updatePageData();
        this.updateSelectedRows();
    }

    handleResultRowSelect(event) {
        const id = event.target.dataset.id;
        const checked = event.target.checked;
        this.ledgerData = this.ledgerData.map(row =>
            row.accountId === id ? { ...row, selected: checked } : row
        );
        this.updatePageData();
        this.updateSelectedRows();
    }

    updateSelectedRows() {
        this.selectedRows = this.ledgerData.filter(item => item.selected);
        this.isAllSelected = this.ledgerData.length > 0 && this.ledgerData.every(item => item.selected);
    }

    handleBack() {
        this.showResultsPage = false;
        this.ledgerData = [];
        this.selectedRows = [];
        this.pageNumber = 1;
    }

    handleViewAccount(event) {
        const recordId = event.currentTarget.dataset.id;
        const row = this.ledgerData.find(r => r.ledgerId === recordId);

        this.previewAccountName = row ? row.accountName : 'Document';

        getContentVersionId({ ledgerId: recordId })
            .then(versionId => {
                if (!versionId) {
                    this.showToast('Warning', 'No document found for this account.', 'warning');
                    return;
                }
                this.previewVersionId = versionId;
                this.previewUrl =
                    '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + versionId;
                this.showPreviewModal = true;
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Unable to load preview.', 'error');
            });
    }

    handleClosePreview() {
        this.showPreviewModal   = false;
        this.previewUrl         = '';
        this.previewVersionId   = '';
        this.previewAccountName = '';
    }

    handleDownloadFromPreview() {
        if (this.previewVersionId) {
            window.open('/sfc/servlet.shepherd/version/download/' + this.previewVersionId, '_blank');
        }
    }

    handleDownloadPdf(event) {
        const versionId = event.currentTarget.dataset.version;
        if (versionId) {
            window.open('/sfc/servlet.shepherd/version/download/' + versionId, '_blank');
        } else {
            this.showToast('Warning', 'No PDF version available.', 'warning');
        }
    }

    stopPolling() {
        if (this.pollingInterval) {
            clearInterval(this.pollingInterval);
            this.pollingInterval = null;
        }
        this.isLoading = false;
    }

    disconnectedCallback() {
        this.stopPolling();
    }

    showToast(title, message, variant = 'info') {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}
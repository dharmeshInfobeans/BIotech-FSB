import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getMyRequests from '@salesforce/apex/DistributorMyRequestsController.getMyRequests';
import getStatusOptions from '@salesforce/apex/DistributorMyRequestsController.getStatusOptions';

const STATUS_CLASSES = {
    'Draft':                          'status-pill pill-grey',
    'Submitted':                      'status-pill pill-blue',
    'Under Leadership Review':        'status-pill pill-orange',
    'Under Management Approval':      'status-pill pill-orange',
    'Sent Back':                      'status-pill pill-yellow',
    'On Hold':                        'status-pill pill-yellow',
    'Approved by Leadership':         'status-pill pill-green',
    'Submitted to Regulatory':        'status-pill pill-blue',
    'Under Regulatory Review':        'status-pill pill-orange',
    'Additional Documents Requested': 'status-pill pill-yellow',
    'Pending Customer Response':      'status-pill pill-yellow',
    'Completed':                      'status-pill pill-green',
    'Rejected':                       'status-pill pill-red'
};

export default class DistributorMyRequests extends NavigationMixin(LightningElement) {
    @track requests = [];
    @track filteredRequests = [];
    @track statusOptions = [];
    @track selectedStatus = 'All';
    @track searchTerm = '';
    @track isLoading = true;
    @track error = false;
    @track errorMessage = '';

    connectedCallback() {
        this.loadRequests();
        this.loadStatusOptions();
    }

    loadRequests() {
        this.isLoading = true;
        this.error = false;
        getMyRequests({ statusFilter: this.selectedStatus })
            .then(data => {
                this.requests = this.enrichRecords(data);
                this.applyFilters();
                this.isLoading = false;
            })
            .catch(err => {
                this.error = true;
                this.errorMessage = (err && err.body && err.body.message)
                    ? err.body.message
                    : 'Unable to load requests. Please refresh the page.';
                this.isLoading = false;
            });
    }

    loadStatusOptions() {
        getStatusOptions()
            .then(data => {
                this.statusOptions = data.map(opt => ({ label: opt.label, value: opt.value }));
            })
            .catch(() => {
                this.statusOptions = [
                    { label: 'All', value: 'All' },
                    { label: 'Draft', value: 'Draft' },
                    { label: 'Submitted', value: 'Submitted' },
                    { label: 'Under Leadership Review', value: 'Under Leadership Review' },
                    { label: 'Under Management Approval', value: 'Under Management Approval' },
                    { label: 'Sent Back', value: 'Sent Back' },
                    { label: 'On Hold', value: 'On Hold' },
                    { label: 'Approved by Leadership', value: 'Approved by Leadership' },
                    { label: 'Submitted to Regulatory', value: 'Submitted to Regulatory' },
                    { label: 'Under Regulatory Review', value: 'Under Regulatory Review' },
                    { label: 'Additional Documents Requested', value: 'Additional Documents Requested' },
                    { label: 'Pending Customer Response', value: 'Pending Customer Response' },
                    { label: 'Completed', value: 'Completed' },
                    { label: 'Rejected', value: 'Rejected' }
                ];
            });
    }

    enrichRecords(data) {
        return data.map(rec => ({
            ...rec,
            productName: rec.Product__r ? rec.Product__r.Name : '—',
            isAdditionalCert: rec.Request_Type__c === 'Additional Document Request',
            statusClass: STATUS_CLASSES[rec.Status__c] || 'status-pill pill-grey',
            formattedDate: rec.Submitted_Date__c
                ? new Date(rec.Submitted_Date__c).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
                : rec.CreatedDate
                    ? new Date(rec.CreatedDate).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
                    : '—'
        }));
    }

    applyFilters() {
        let result = [...this.requests];
        if (this.searchTerm) {
            const term = this.searchTerm.toLowerCase();
            result = result.filter(r =>
                (r.Name && r.Name.toLowerCase().includes(term)) ||
                (r.productName && r.productName.toLowerCase().includes(term))
            );
        }
        this.filteredRequests = result;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
        this.applyFilters();
    }

    handleStatusFilter(event) {
        this.selectedStatus = event.detail.value;
        this.loadRequests();
    }

    handleCardClick(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/request-detail?id=' + recordId }
        });
    }

    handleNewRegistration() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/registration' }
        });
    }

    get hasRecords()     { return !this.isLoading && !this.error && this.filteredRequests.length > 0; }
    get isEmpty()        { return !this.isLoading && !this.error && this.filteredRequests.length === 0; }
    get filteredCount()  { return this.filteredRequests.length; }
    get hasActiveFilter(){ return this.searchTerm !== '' || this.selectedStatus !== 'All'; }
    get noActiveFilter() { return !this.hasActiveFilter; }
}
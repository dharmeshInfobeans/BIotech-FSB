import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getQueue from '@salesforce/apex/RegulatoryQueueController.getQueue';

const STATUS_PILL_MAP = {
    'Submitted to Regulatory': 'status-pill pending',
    'Under Regulatory Review': 'status-pill review',
    'Additional Documents Requested': 'status-pill additional',
    'Pending Customer Response': 'status-pill waiting',
    'Completed': 'status-pill completed'
};

const PRIORITY_CLASS_MAP = {
    'High': 'priority-high',
    'Medium': 'priority-medium',
    'Normal': 'priority-normal'
};

const FILTER_STATUS_MAP = {
    'All': null,
    'Pending Review': ['Submitted to Regulatory'],
    'Under Review': ['Under Regulatory Review'],
    'Additional Docs': ['Additional Documents Requested', 'Pending Customer Response'],
    'Completed': ['Completed']
};

export default class RegulatoryQueueManagement extends NavigationMixin(LightningElement) {
    @track searchText = '';
    @track activeFilter = 'All';
    @track filterPriority = '';
    @track filterCountry = '';
    @track filterDocCycle = false;
    @track isLoading = true;
    @track hasError = false;

    _wiredResult;
    _rawQueue = [];

    @wire(getQueue)
    wiredQueue(result) {
        this._wiredResult = result;
        if (result.data) {
            this._rawQueue = result.data;
            this.isLoading = false;
            this.hasError = false;
        } else if (result.error) {
            this.isLoading = false;
            this.hasError = true;
            this._rawQueue = [];
        }
    }

    _getPriority(daysPending) {
        const d = daysPending || 0;
        if (d > 30)  return 'High';
        if (d >= 15) return 'Medium';
        return 'Low';
    }

    get priorityOptions() {
        return [
            { label: 'All Priorities',      value: '' },
            { label: 'High (>30 days)',     value: 'High'   },
            { label: 'Medium (15–30 days)', value: 'Medium' },
            { label: 'Low (<15 days)',      value: 'Low'    },
        ];
    }

    get countryOptions() {
        const countries = [...new Set(
            (this._rawQueue || [])
                .map(r => r.country)
                .filter(c => c)
        )].sort();
        return [
            { label: 'All Countries', value: '' },
            ...countries.map(c => ({ label: c, value: c }))
        ];
    }

    get filterDocCycleClass() {
        return this.filterDocCycle ? 'filter-btn active' : 'filter-btn';
    }

    get filteredQueue() {
        let records = this._rawQueue || [];

        const statusFilter = FILTER_STATUS_MAP[this.activeFilter];
        if (statusFilter) {
            records = records.filter(r => statusFilter.includes(r.status));
        }

        const search = this.searchText ? this.searchText.toLowerCase() : '';
        if (search) {
            records = records.filter(r =>
                (r.name && r.name.toLowerCase().includes(search)) ||
                (r.distributorName && r.distributorName.toLowerCase().includes(search)) ||
                (r.country && r.country.toLowerCase().includes(search)) ||
                (r.productName && r.productName.toLowerCase().includes(search))
            );
        }

        if (this.filterPriority) {
            records = records.filter(r => this._getPriority(r.daysPending) === this.filterPriority);
        }

        if (this.filterCountry) {
            records = records.filter(r => r.country === this.filterCountry);
        }

        if (this.filterDocCycle) {
            records = records.filter(r => (r.cycleCount || 0) > 0);
        }

        return records;
    }

    get sortedQueue() {
        return [...this.filteredQueue]
            .sort((a, b) => {
                const na = a.name ?? '';
                const nb = b.name ?? '';
                if (nb < na) return -1;
                if (nb > na) return  1;
                return (b.daysPending || 0) - (a.daysPending || 0);
            })
            .map(r => {
                const priority = this._getPriority(r.daysPending);
                return {
                    ...r,
                    priority,
                    cycleCount: r.cycleCount || 0,
                    rowClass: r.isOverdue ? 'row-overdue' : '',
                    statusPillClass: STATUS_PILL_MAP[r.status] || 'status-pill pending',
                    priorityClass: PRIORITY_CLASS_MAP[priority] || 'priority-normal'
                };
            });
    }

    get totalCount() {
        return this.sortedQueue.length;
    }

    get hasRecords()  { return this.sortedQueue.length > 0; }
    get showTable()   { return !this.isLoading && !this.hasError; }

    // Filter button class getters
    get filterBtnAll() {
        return this.activeFilter === 'All' ? 'filter-btn active' : 'filter-btn';
    }
    get filterBtnPendingReview() {
        return this.activeFilter === 'Pending Review' ? 'filter-btn active' : 'filter-btn';
    }
    get filterBtnUnderReview() {
        return this.activeFilter === 'Under Review' ? 'filter-btn active' : 'filter-btn';
    }
    get filterBtnAdditionalDocs() {
        return this.activeFilter === 'Additional Docs' ? 'filter-btn active' : 'filter-btn';
    }
    get filterBtnCompleted() {
        return this.activeFilter === 'Completed' ? 'filter-btn active' : 'filter-btn';
    }

    handleSearch(event) {
        this.searchText = event.target.value;
    }

    handleFilter(event) {
        this.activeFilter = event.target.dataset.filter;
    }

    handlePriorityFilter(event) {
        this.filterPriority = event.detail.value;
    }

    handleCountryFilter(event) {
        this.filterCountry = event.detail.value;
    }

    handleDocCycleFilter() {
        this.filterDocCycle = !this.filterDocCycle;
    }

    handleViewDetail(event) {
        const id = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/regulatory-request-detail?recordId=' + id
            }
        });
    }

    refreshData() {
        return refreshApex(this._wiredResult);
    }
}
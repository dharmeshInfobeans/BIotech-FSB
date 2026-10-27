/**
 * Customer lookup component for event planner
 * Allows searching and filtering accounts/leads by region, zone, and type
 * @fires handleShowCalendar - When a card is selected
 */
import { LightningElement, api, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { fireEvent, registerListener, unregisterAllListeners } from 'c/pubsub';
import findAccount from '@salesforce/apex/calendarPlanningMobileController.findAccount';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class EventPlannerCustomerLookup extends LightningElement {
    /**
     * List of region options
     * @type {Array<{label: string, value: string}>}
     */
    _userRegionSelectList = [];
    @api
    get userRegionSelectList() {
        return this._userRegionSelectList;
    }
    set userRegionSelectList(value) {
        this._userRegionSelectList = value;
        this._regionListReceived = true;
        // Initialize filters when data is available
        this.initializeFilters();
    }

    /**
     * List of zone options
     * @type {Array<{label: string, value: string}>}
     */
    _userZoneSelectList = [];
    @api
    get userZoneSelectList() {
        return this._userZoneSelectList;
    }
    set userZoneSelectList(value) {
        this._userZoneSelectList = value;
        this._zoneListReceived = true;
        // Initialize filters when zone data is available
        this.initializeFilters();
    }

    // Flags to track if setters have been called
    _regionListReceived = false;
    _zoneListReceived = false;

    /**
     * Custom labels object
     * @type {Object}
     */
    @api labels = {};

    // Wire pageRef for pubsub communication
    @wire(CurrentPageReference) pageRef;

    // Reactive properties (no @track needed for primitives)
    searchKey = '';
    searchInputValue = '';
    regionValue;  // For dropdown display
    regionValueToSearch = 'International';  // For wire adapter parameter - initialize to trigger wire
    zoneValue;
    objectType = 'All';  // 'All', 'Lead', or 'Account'
    showZoneDropdown = false;
    contactName = '';
    showRegionZoneFilters = true;

    // Only use @track for arrays that will be mutated
    @track accounts = [];

    // Loading and error states
    isLoading = false;
    hasError = false;
    errorMessage = '';
    noResults = false;

    // Wire result reference for refreshApex
    wiredAccountData;

    // Debounce timeout reference
    debounceTimeout;

    // Flag to track if we've initialized
    _isInitialized = false;

    /**
     * Component initialization
     */
    connectedCallback() {
        // Register listeners ONCE in connectedCallback (NOT renderedCallback)
        registerListener('resetSearchBar', this.handleResetSearchBar, this);
        registerListener('handleShowTabs', this.handleShowTabs, this);
        registerListener('handleBackFromTabScreen', this.handleHideTabs, this);
        registerListener('refreshSearch', this.handleRefreshSearch, this);
        registerListener('homeScreen', this.handleBackClick, this);
    }

    /**
     * Initialize filters when region and zone lists are available
     */
    initializeFilters() {
        if (this._isInitialized) {
            return; // Already initialized
        }

        // Wait for BOTH setters to be called at least once
        if (!this._regionListReceived || !this._zoneListReceived) {
            return;
        }

        // Check if region list has data - REQUIRED
        if (!this.userRegionSelectList || this.userRegionSelectList.length === 0) {
            return;
        }

        // Set region to first available region
        // For lightning-combobox, value must match the 'value' field in options
        this.regionValue = this.userRegionSelectList[0].value;

        // Auto-populate zone if available (matching old component behavior)
        // For lightning-combobox, value must match the 'value' field in options
        this.zoneValue = this.userZoneSelectList.length > 0 ? this.userZoneSelectList[0].value : '';

        // Determine what to send to wire adapter based on region type
        if (this.regionValue === 'Domestic') {
            this.showZoneDropdown = true;
            // If we have a zone, set regionValueToSearch to enable wire adapter
            // If no zone, regionValueToSearch remains null until zone is selected
            if (this.zoneValue) {
                this.regionValueToSearch = this.regionValue;
            } else {
                this.regionValueToSearch = null;
            }
        } else {
            this.showZoneDropdown = false;
            this.regionValueToSearch = this.regionValue;
        }

        this._isInitialized = true;

        // Force wire adapter to refresh with new values
        if (this.wiredAccountData) {
            refreshApex(this.wiredAccountData)
                .catch(error => {
                    console.error('refreshApex error:', error);
                });
        }
    }


    /**
     * Component cleanup
     */
    disconnectedCallback() {
        unregisterAllListeners(this);
        clearTimeout(this.debounceTimeout);
    }


    /**
     * Handle back button click - navigate back to calendar
     */
    handleBackClick() {
        fireEvent(this.pageRef, 'homeScreen', true);
    }

    /**
     * Computed property for object type filter options
     */
    get objectTypeOptions() {
        return [
            { label: 'All', value: 'All' },
            { label: 'Prospect', value: 'Lead' },
            { label: 'Opportunity', value: 'Opportunity' },
            { label: 'Account', value: 'Account' }
        ];
    }

    /**
     * Computed property for region options
     */
    get regionOptions() {
        return this.userRegionSelectList || [];
    }

    /**
     * Computed property for zone options
     */
    get zoneOptions() {
        return this.userZoneSelectList || [];
    }


    /**
     * Check if accounts array has data
     */
    get hasAccounts() {
        return this.accounts && this.accounts.length > 0;
    }

    /**
     * Check if legend should be displayed (only when "All" filter is selected)
     * @returns {Boolean} True if objectType is 'All'
     */
    get showLegend() {
        return this.objectType === 'All';
    }

    /**
     * Dynamic search label based on selected object type
     * @returns {String} Search label text
     */
    get searchLabel() {
        switch(this.objectType) {
            case 'Lead':
                return 'Search Prospects';
            case 'Account':
                return 'Search Accounts';
            case 'Opportunity':
                return 'Search Opportunities';
            default:
                return 'Search';
        }
    }

    /**
     * Dynamic search placeholder based on selected object type
     * @returns {String} Placeholder text showing search criteria
     */
    get searchPlaceholder() {
        switch(this.objectType) {
            case 'Lead':
                return 'Search by prospect name or phone number...';
            case 'Account':
                return 'Search by account name or phone number...';
            case 'Opportunity':
                return 'Search by opportunity name or account name...';
            default:
                return 'Search by name or phone number...';
        }
    }

    /**
     * Helper text explaining search criteria
     * @returns {String} Helper text for search input
     */
    get searchHelpText() {
        switch(this.objectType) {
            case 'Lead':
                return 'You can search by prospect name or phone number';
            case 'Account':
                return 'You can search by account name, phone number, city, or country';
            case 'Opportunity':
                return 'You can search by opportunity name or associated account name';
            default:
                return 'You can search by name, phone number, city, or country';
        }
    }

    /**
     * Wire adapter to fetch accounts from Apex
     */
    @wire(findAccount, {
        searchKey: '$searchKey',
        region: '$regionValueToSearch',
        selectedZone: '$zoneValue',
        ObjectName: '$objectType'
    })
    wiredFindAccount(result) {
        this.wiredAccountData = result;

        if (result.data) {
            this.accounts = result.data || [];
            this.contactName = result.ContactName || '';
            this.noResults = this.accounts.length === 0;
            this.hasError = false;
            this.isLoading = false;
        } else if (result.error) {
            this.hasError = true;
            this.errorMessage = this.extractErrorMessage(result.error);
            this.accounts = [];
            this.isLoading = false;
            this.showToast('Error', this.errorMessage, 'error');
        }
    }

    /**
     * Handle object type change (All/Lead/Account)
     */
    handleObjectTypeChange(event) {
        this.objectType = event.detail.value;
        this.updateFilterVisibility();
    }

    /**
     * Update visibility of region/zone filters based on object type
     */
    updateFilterVisibility() {
        this.showRegionZoneFilters =
            this.objectType === 'All' || this.objectType === 'Account';
    }

    /**
     * Handle region dropdown change
     */
    handleRegionChange(event) {
        this.regionValue = event.detail.value;

        if (this.regionValue === 'Domestic') {
            this.showZoneDropdown = true;
            this.zoneValue = null;
            this.regionValueToSearch = null;  // Don't search until zone selected
        } else {
            this.showZoneDropdown = false;
            this.zoneValue = null;
            this.regionValueToSearch = this.regionValue;  // Search with new region
        }
    }

    /**
     * Handle zone dropdown change
     */
    handleZoneChange(event) {
        this.zoneValue = event.detail.value;
        // Now that zone is selected, enable search with region
        if (this.regionValue === 'Domestic') {
            this.regionValueToSearch = this.regionValue;
        }
    }

    /**
     * Handle search input change with debouncing
     */
    handleSearchChange(event) {
        this.searchInputValue = event.target.value;

        // Clear previous timeout
        clearTimeout(this.debounceTimeout);

        // Set new timeout (300ms debounce)
        this.debounceTimeout = setTimeout(() => {
            this.searchKey = this.searchInputValue;
            // isLoading will be set by wire adapter response, not here
        }, 300);
    }

    /**
     * Handle static card click (Leave/Holiday)
     */
    handleStaticCardClick(event) {
        const cardType = event.currentTarget.dataset.cardType;
        this.fireCardSelectedEvent(cardType, null);
    }

    /**
     * Handle keyboard navigation on static cards
     */
    handleStaticCardKeydown(event) {
        // Support Enter or Space key
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleStaticCardClick(event);
        }
    }

    /**
     * Fire handleShowCalendar event when card is selected
     */
    fireCardSelectedEvent(cardType, accountData) {
        const payload = {
            accountdata: cardType,
            ContactName: this.contactName,
            cerating: '',
            cisrating: '',
            contactList: false,
            ...(accountData && { accountname: accountData.Name })
        };

        fireEvent(this.pageRef, 'handleShowCalendar', payload);
    }

    /**
     * Handle retry button click on error state
     */
    handleRetry() {
        this.hasError = false;
        this.isLoading = true;
        refreshApex(this.wiredAccountData);
    }

    /**
     * Event handler: Reset search bar
     */
    handleResetSearchBar() {
        this.searchKey = '';
        this.searchInputValue = '';
    }

    /**
     * Event handler: Refresh search
     */
    handleRefreshSearch() {
        this.searchKey = '';
        this.searchInputValue = '';
        return refreshApex(this.wiredAccountData);
    }

    /**
     * Event handler: Show tabs (preserved for compatibility)
     */
    handleShowTabs() {
        // Currently unused but preserved for backward compatibility
    }

    /**
     * Event handler: Hide tabs
     */
    handleHideTabs(data) {
        if (data === 'homeFromTab') {
            fireEvent(this.pageRef, 'homeScreen', true);
        }
    }

    /**
     * Extract error message from error object
     */
    extractErrorMessage(error) {
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        } else if (error.body && error.body.message) {
            return error.body.message;
        }
        return 'An unknown error occurred';
    }

    /**
     * Show toast notification
     */
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant  // 'success', 'error', 'warning', 'info'
            })
        );
    }
}
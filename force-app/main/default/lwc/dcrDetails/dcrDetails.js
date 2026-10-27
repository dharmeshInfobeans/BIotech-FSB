import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { wire } from 'lwc';
import getEventDetailsForDCR from '@salesforce/apex/DcrDetailsController.getEventDetailsForDCR';
import saveDCR from '@salesforce/apex/DcrDetailsController.saveDCR';
import submitDCR from '@salesforce/apex/DcrDetailsController.submitDCR';
import checkOutWithDCR from '@salesforce/apex/DcrDetailsController.checkOutWithDCR';
import updateLeadStage from '@salesforce/apex/DcrDetailsController.updateLeadStage';
import updateOpportunityStatus from '@salesforce/apex/DcrDetailsController.updateOpportunityStatus';
import uploadBrandingFile from '@salesforce/apex/DcrDetailsController.uploadBrandingFile';
import getProductsBySubCallType from '@salesforce/apex/calendarPlanningMobileController.getProductsBySubCallType';

/**
 * @description DCR Details Second Page - displays after check-in for DCR data entry
 * @author Priyam Shah
 * @date 2026-01-20
 */
export default class DcrDetails extends NavigationMixin(LightningElement) {
    // Public property - can be set from parent or URL state
    @api eventId;

    // Tracked properties for reactivity
    @track eventData = {};
    @track invoiceList = [];
    @track productList = [];
    @track productOptions = [];
    @track enableProductOption = false;
    @track dcrCurrentCallType = '';
    @track bdTrackerList = [];
    @track leadDataList = [];
    @track opportunityData = null;
    @track opportunityStatusSelections = {}; // oppId -> status
    @track opportunityStageOptions = [];
    @track translations = {};

    // Form state
    @track dcrRemark = '';
    @track followUpDate = '';
    @track selectedProducts = [];
    @track leadStageSelections = {}; // leadId -> stage
    @track bdSelections = {}; // bdId -> { checked, remark, delayReason, skipReason, bdStage, lostReason }

    // Branding file state (In Clinic Branding only)
    brandingFileData = null; // { base64: string, fileName: string }
    @track brandingFileName = '';

    // UI state
    @track isLoading = true;
    @track isSaveEnabled = true;
    @track isSubmitEnabled = false;
    @track isCheckoutEnabled = false;
    @track userLocation = null;
    @track profileName = '';
    @track isExcludedCountry = false;
    @track originalOpportunityStatuses = {};
    // Error messages
    @track remarkError = false;
    @track showSapWarning = false;
    @track sapWarningMessage = '';
    @track leadUnqualifiedReasonSelections = {};
    @track unqualifiedReasonOptions = [];
    @track leadUnqualifiedRemarksSelections = {};
    // NEW: Opportunity "Closed Lost" reason tracking (oppId -> reason text)
    @track opportunityLostReasonSelections = {};
    @track opportunityCloseDateSelections = {};
    @track equipmentCompanyByOpportunity = {};
    @track equipmentProductByOpportunity = {};
    

  

    get hasBackwardOpportunityMove() {
        if (!this.isOpportunityEvent || !this.opportunityData || this.opportunityData.length === 0) {
            return false;
        }

        return this.opportunityData.some(opp => {
            const selectedStatus = this.opportunityStatusSelections[opp.Id];
            if (!selectedStatus || selectedStatus === 'None') {
                return false;
            }
            const currentRank = this.STAGE_ORDER[this.originalOpportunityStatuses[opp.Id]];
            const newRank = this.STAGE_ORDER[selectedStatus];
            return currentRank != null && newRank != null && newRank < currentRank;
        });
    }



    // Invoice table columns
    invoiceColumns = [
        { label: 'Product Code', fieldName: 'Dummy_Product_Code__c', type: 'text' },
        { label: 'Product Name', fieldName: 'productName', type: 'text' },
        { label: 'Quantity', fieldName: 'Quantity__c', type: 'number' },
        { label: 'Amount', fieldName: 'Amount__c', type: 'currency' }
    ];

    // Lead stage options for different customer types
    newCustomerStages = [
        { label: '--None--', value: 'None' },
        { label: 'Appointments', value: 'Appointments' },
        { label: 'Unqualified', value: 'Unqualified' },
        //{ label: 'Converted', value: 'Converted' }
    ];

    existingCustomerStages = [
        { label: '--None--', value: 'None' },
        { label: 'Appointments', value: 'Appointments' },
        { label: 'Unqualified', value: 'Unqualified' },
        //{ label: 'Converted', value: 'Converted' }
    ];

    marketingStages = [
        { label: '--None--', value: 'None' },
        { label: 'CME', value: 'CME' },
        { label: 'RTM', value: 'RTM' },
        { label: 'User Meeting', value: 'User Meeting' },
        { label: 'High Impact CME', value: 'High Impact CME' },
        { label: 'KOL/FOL Development', value: 'KOL/FOL Development' },
        { label: 'Virtual exp. Lab', value: 'Virtual exp. Lab' },
        { label: 'Wet Labs', value: 'Wet Labs' },
        { label: 'Testimonial', value: 'Testimonial' },
        { label: 'CTP', value: 'CTP' },
        { label: 'Focus', value: 'Focus' },
        { label: 'Decode', value: 'Decode' },
        { label: 'Inclinic Branding', value: 'Inclinic Branding' }
    ];

    bdPlanStatusOptions = [
        { label: 'Won', value: 'Won' },
        { label: 'Closed Lost', value: 'Closed Lost' }
    ];

    // Opportunity statuses excluded during check-in.
    // "Closed Lost" is intentionally selectable now (with a Lost Reason capture);
    // "Closed Won" remains hidden from this in-DCR flow.
    excludedOpportunityStatuses = [];

    // Track previous eventId to detect changes
    _previousEventId = null;
    // Track if data has been loaded in current render cycle
    _dataLoadedForCurrentEvent = false;

    // Wire to get page reference for URL state
    @wire(CurrentPageReference)
    setCurrentPageReference(pageRef) {
        if (pageRef && pageRef.state) {
            // Get eventId from URL state
            const newEventId = pageRef.state.c__eventId || this.eventId;
            if (newEventId && newEventId !== this.eventId) {
                this.eventId = newEventId;
                this._dataLoadedForCurrentEvent = false;
            }
            if (this.eventId && !this._dataLoadedForCurrentEvent) {
                this._previousEventId = this.eventId;
                this._dataLoadedForCurrentEvent = true;
                this.loadEventData();
            }
        }
    }

    connectedCallback() {
        this.getUserLocation();
        // Reset data loaded flag when component connects
        this._dataLoadedForCurrentEvent = false;
        // If eventId is already set (via @api), load data
        if (this.eventId) {
            this._previousEventId = this.eventId;
            this._dataLoadedForCurrentEvent = true;
            this.loadEventData();
        }
    }

    /**
     * @description Public API method to refresh data - can be called by parent component
     * This forces a reload even if the eventId hasn't changed
     */
    @api
    refreshData() {
        this._dataLoadedForCurrentEvent = false;
        if (this.eventId) {
            this.loadEventData();
        }
    }

    // ==================== GETTERS ====================

    get isDataLoaded() {
        return !this.isLoading;
    }
    get showTargetValue() {
        return this.eventData?.Target__c !== null &&
            this.eventData?.Target__c !== undefined &&
            this.eventData?.Target__c !== '';
    }
    get targetValue() {
        return this.eventData?.Target__r?.Name || null;
    }

    get customerName() {
        if (this.eventData.Leads__r?.Name) {
            return this.eventData.Leads__r.Name;
        }
        if (this.eventData.WhatId && this.eventData.What?.Type === 'Opportunity__c') {
            return this.eventData.What?.Name || 'Opportunity';
        }
        return this.eventData.Account__r?.Name || '';
    }

    get accountName() {
        if (this.isOpportunityEvent && this.opportunityData?.Account__r?.Name) {
            return this.opportunityData.Account__r.Name;
        }
        return this.eventData.Account__r?.Name || '';
    }

    get currentOpportunity() {
        if (!this.isOpportunityEvent || !this.opportunityData) {
            return null;
        }
        const linkedOppId = this.eventData.Opportunity__c || this.eventData.WhatId;
        return this.opportunityData.find(opp => opp.Id === linkedOppId) || null;
    }

    get ceCisRating() {
        if (this.eventData.Leads__r?.CE_CIS_Rating__c) {
            return this.eventData.Leads__r.CE_CIS_Rating__c;
        }
        if (this.currentOpportunity?.CE_CIS_Rating__c) {
            return this.currentOpportunity.CE_CIS_Rating__c;
        }
        return this.eventData.CE_Rating__c || '-';
    }

    get phakicRating() {
        if (this.eventData.Leads__r?.Phakic_Rating__c) {
            return this.eventData.Leads__r.Phakic_Rating__c;
        }
        if (this.currentOpportunity?.Phakic_Rating__c) {
            return this.currentOpportunity.Phakic_Rating__c;
        }
        return this.eventData.CIS_Rating__c || '-';
    }

    get isOpportunityEvent() {
        return this.eventData.WhatId != null &&
            this.eventData.What?.Type === 'Opportunity__c';
    }

    get hasOpportunityData() {
        return this.isOpportunityEvent && this.opportunityData != null;
    }

    get hasLeadsOrOpportunity() {
        return this.hasLeads || this.hasOpportunityData;
    }

    get stageManagementIcon() {
        if (this.hasLeads) {
            return 'standard:lead';
        }
        if (this.hasOpportunityData) {
            return 'standard:opportunity';
        }
        return 'standard:lead';
    }

    get stageManagementTitle() {
        if (this.hasLeads) {
            return 'Prospect Stage';
        }
        if (this.hasOpportunityData) {
            return 'Opportunity Status';
        }
        return 'Prospect Stage';
    }

    get tableColumnName() {
        if (this.hasLeads) {
            return 'Prospect Name';
        }
        if (this.hasOpportunityData) {
            return 'Opportunity Name';
        }
        return 'Name';
    }

    get tableColumnCurrentStage() {
        if (this.hasLeads) {
            return 'Previous Stage';
        }
        if (this.hasOpportunityData) {
            return 'Previous Stage';
        }
        return 'Previous Stage';
    }

    get tableColumnSelectStage() {
        if (this.hasLeads) {
            return 'Current Stage';
        }
        if (this.hasOpportunityData) {
            return 'Current Stage';
        }
        return 'Current Stage';
    }

    get opportunityStatus() {
        return this.opportunityData?.Status__c || '-';
    }

    get opportunityAccountName() {
        return this.opportunityData?.Account__r?.Name || '-';
    }

    get isCheckedIn() {
        return this.eventData?.Cheked_In__c === true && this.eventData?.Check_Out__c !== true;
    }

    // Equipment Record Type opportunities only ever show these 4 stages (plus --None--).
    EQUIPMENT_STAGE_VALUES = ['Meeting', 'Demo', 'Proposal Submitted', 'Negotiation', 'Closed Lost', 'Closed Won'];
    STAGE_VALUES = ['Presentation', 'Demo', 'Evaluation', 'Negotiation', 'Closed Lost', 'Closed Won'];

    getStageOptionsForOpportunity(isEquipmentType) {
        if (!this.opportunityStageOptions || this.opportunityStageOptions.length === 0) {
            return [];
        }

        let options = this.opportunityStageOptions;

        // If checked in, exclude Closed Won only (Closed Lost is now selectable with a reason).
        if (this.isCheckedIn) {
            options = options.filter(option =>
                !this.excludedOpportunityStatuses.includes(option.value)
            );
        }

        // Equipment Record Type: restrict to Demo, Negotiation, Closed Lost, Closed Won only.
        if (isEquipmentType) {
            options = options.filter(option =>
                option.value === 'None' || this.EQUIPMENT_STAGE_VALUES.includes(option.value)
            );
        } else {
            options = options.filter(option =>
                option.value === 'None' || this.STAGE_VALUES.includes(option.value)
            );
        }

        // Move "Closed Won" to sit immediately after "Closed Lost"; everything else stays in place.
        options = this.reorderClosedWonAfterClosedLost(options);

        // Shorten the displayed label only — underlying value stays 'Closed Won'/'Closed Lost'.
        return this.simplifyClosedLabels(options);
    }

    simplifyClosedLabels(options) {
        return options.map(opt => {
            if (opt.value === 'Closed Won') {
                return { ...opt, label: 'Won' };
            }
            if (opt.value === 'Closed Lost') {
                return { ...opt, label: 'Lost' };
            }
            return opt;
        });
    }

    reorderClosedWonAfterClosedLost(options) {
        const closedLostIndex = options.findIndex(opt => opt.value === 'Closed Lost');
        const closedWonIndex = options.findIndex(opt => opt.value === 'Closed Won');

        // If either option is missing, or Closed Won is already right after Closed Lost, do nothing
        if (closedLostIndex === -1 || closedWonIndex === -1 || closedWonIndex === closedLostIndex + 1) {
            return options;
        }

        const reordered = [...options];
        const [closedWonOption] = reordered.splice(closedWonIndex, 1);
        const newClosedLostIndex = reordered.findIndex(opt => opt.value === 'Closed Lost');
        reordered.splice(newClosedLostIndex + 1, 0, closedWonOption);
        return reordered;
    }

    get hasInvoices() {
        return this.invoiceList && this.invoiceList.length > 0;
    }

    get hasLeads() {
        return this.leadDataList && this.leadDataList.length > 0;
    }

    get hasBdTracker() {
        return this.bdTrackerList && this.bdTrackerList.length > 0;
    }

    get isMarketingUser() {
        return this.profileName === 'Marketing User';
    }

    get productOptions() {
        return this.productList.map(prod => ({
            label: prod.Name,
            value: prod.Name
        }));
    }

    get isInClinicBranding() {
        return this.eventData && this.eventData.Call_Type__c === 'In Clinic Branding';
    }

    /**
     * @description Returns semicolon-separated string of selected products for multiSelectPicklistWithSearch
     */
    get productNamesString() {
        return this.selectedProducts && this.selectedProducts.length > 0
            ? this.selectedProducts.join(';')
            : '';
    }

    get formattedSelectedProducts() {
        return this.selectedProducts && this.selectedProducts.length > 0
            ? this.selectedProducts.join(', ')
            : '';
    }

    get leadProductFamily() {
        return this.leadDataList.length > 0 ? (this.leadDataList[0].Lead_Product_Family__c || '') : '';
    }

    get leadProductGroup() {
        return this.leadDataList.length > 0 ? (this.leadDataList[0].Lead_Products__c || '') : '';
    }

    get displayProductFamily() {
        if (this.isOpportunityEvent) {
            return this.opportunityData && this.opportunityData.length > 0
                ? (this.opportunityData[0].Opps_Product_Family__c || '') : '';
        }
        if (this.accountProductFamily) {
            return this.accountProductFamily;
        }
        return this.leadProductFamily;
    }
    get accountProductFamily() {
        const eventData = this.eventData;

        if (eventData?.What?.Type === 'Account') {

            return eventData.Product_Family__c ?? null;
        }

        return null;
    }

    get displayProductGroup() {
        if (this.isOpportunityEvent) {
            return this.opportunityData && this.opportunityData.length > 0
                ? (this.opportunityData[0].Opps_Products__c || '') : '';
        }



        return this.leadProductGroup;
    }

    get formattedInvoiceList() {
        return this.invoiceList.map(inv => ({
            ...inv,
            productName: inv.Product__r?.Name || ''
        }));
    }

    get remarkClass() {
        return this.remarkError ? 'slds-has-error' : '';
    }

    get isSubmitDisabled() {
        return this.hasBackwardOpportunityMove;
    }
    // Translation getters with fallbacks
    get labelCustomerDetails() {
        return this.translations.Customer_Details__c || 'Customer Details';
    }

    get labelCustomerName() {
        return this.translations.Customer_Name__c || 'Customer Name';
    }

    get labelLastInvoices() {
        return this.translations.Last_5_Invoices_Details__c || 'Last 5 Invoices';
    }

    get labelSubject() {
        return this.translations.Subject__c || 'Subject';
    }

    get labelFollowUpDate() {
        return this.translations.Follow_up_Date__c || 'Follow-up Date';
    }

    get labelCallType() {
        return this.translations.Call_type__c || 'Call Type';
    }

    get labelProduct() {
        return this.translations.Product__c || 'Product';
    }

    get labelRemark() {
        return this.translations.Remark__c || 'Remark';
    }

    get labelSubmit() {
        return this.translations.Check_Out__c || 'Check Out';
    }

    get labelCancel() {
        return this.translations.Cancel__c || 'Cancel';
    }
    get isAccountNotEvent() {
        return this.accountProductFamily == null ? true : false;
    }

    // ==================== DATA LOADING ====================

    async loadEventData() {
        this.isLoading = true;

        // Clear previous data first to ensure clean state
        this.selectedProducts = [];

        try {
            const result = await getEventDetailsForDCR({ eventId: this.eventId });
            console.log('result event data ', result);
            this.eventData = result.eventData || {};
            this.invoiceList = result.lastFiveInvoices || [];
            this.productList = result.productList || [];
            this.bdTrackerList = result.bdTrackerList || [];
            this.leadDataList = result.leadDataList || [];
            this.opportunityData = result.opportunityData || null;
            this.opportunityStageOptions = result.opportunityStatusOptions || [];
            this.equipmentCompanyByOpportunity = result.equipmentCompanyByOpportunity || {};
            this.equipmentProductByOpportunity = result.equipmentProductByOpportunity || {};
            this.translations = result.translations || {};
            this.profileName = result.profileName || '';
            this.isExcludedCountry = result.isExcludedCountry || false;

            // Pre-populate form fields from event data
            this.dcrRemark = this.eventData.DCR_Description__c || '';
            this.followUpDate = this.eventData.Follow_Up_Date__c || '';

            // in loadEventData(), alongside the other result.* assignments
            this.unqualifiedReasonOptions = result.unqualifiedReasonOptions || [];

            // Parse existing products - always initialize to an array
            if (this.eventData.Product__c) {
                this.selectedProducts = this.eventData.Product__c.split(';').filter(p => p && p.trim());
            } else {
                this.selectedProducts = [];
            }

            // Load product options for the picker
            await this.loadProductOptions();

            // Initialize BD tracker selections
            this.initializeBdSelections();

            // Initialize lead stage selections
            this.initializeLeadStageSelections();

            // Initialize opportunity status selection
            this.initializeOpportunityStatusSelection();

        } catch (error) {
            console.error('Error loading event data:', error);
            this.showToast('Error', error.body?.message || 'Failed to load event data', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    initializeBdSelections() {
        const selections = {};
        this.bdTrackerList.forEach(bd => {
            selections[bd.Id] = {
                checked: bd.isUpdate__c || false,
                remark: bd.Remark__c || '',
                delayReason: bd.milestone_delay_reason__c || '',
                skipReason: bd.Reason_for_Evaluation_Skip__c || '',
                bdStage: bd.BD_Plan_Status__c || 'Won',
                lostReason: bd.Reason__c || ''
            };
        });
        this.bdSelections = selections;
    }

    initializeLeadStageSelections() {
        const selections = {};
        const reasonSel = {};
        const remarksSel = {};
        this.leadDataList.forEach(lead => {
            selections[lead.Id] = lead.Lead_Stage__c || 'None';
            reasonSel[lead.Id] = lead.Disqualified_Reason__c || '';
            remarksSel[lead.Id] = lead.Unqualified_Remarks__c || '';
        });
        this.leadStageSelections = selections;
        this.leadUnqualifiedReasonSelections = reasonSel;
        this.leadUnqualifiedRemarksSelections = remarksSel;
    }

    initializeOpportunityStatusSelection() {
        if (this.isOpportunityEvent && this.opportunityData && this.opportunityData.length > 0) {
            const selections = {};
            const baseline = {};
            const lostReasons = {};
            const closeDates = {};
            this.opportunityData.forEach(opp => {
                selections[opp.Id] = opp.Status__c || 'None';
                baseline[opp.Id] = opp.Status__c || 'None';
                lostReasons[opp.Id] = opp.Lost_Reason__c || '';   // CHANGED: pre-fill existing saved reason
                closeDates[opp.Id] = opp.Close_Date__c || '';     // already correct, unchanged
            });
            this.opportunityStatusSelections = selections;
            this.originalOpportunityStatuses = baseline;
            this.opportunityLostReasonSelections = lostReasons;
            this.opportunityCloseDateSelections = closeDates;
        }
    }
    STAGE_ORDER = {
        'Presentation': 1,
        'Demo': 2,
        'Evaluation': 3,
        'Negotiation': 4,
        'Closed Won': 5,
        'Closed Lost': 5
    };

    // NEW: an Opportunity that was ALREADY Closed Won/Closed Lost before this
    // DCR visit is frozen — no further stage/reason/date edits allowed.
    isOppFrozen(oppId) {
        const baseline = this.originalOpportunityStatuses[oppId];
        return baseline === 'Closed Won' || baseline === 'Closed Lost';
    }

    handleOpportunityStatusChange(event) {

        const oppId = event.target.dataset.oppid;
        const newStatus = event.target.value;

        if (this.isOppFrozen(oppId)) {   // NEW: already closed — revert and block
            event.target.value = this.originalOpportunityStatuses[oppId];
            this.showToast('Info', 'This Opportunity is already closed and cannot be changed.', 'info');
            return;
        }

        const oppRecord = (this.opportunityData || []).find(o => o.Id === oppId);
        const currentStatus = this.originalOpportunityStatuses[oppId];
        const currentRank = this.STAGE_ORDER[currentStatus];
        const newRank = this.STAGE_ORDER[newStatus];

        if (currentRank != null && newRank != null && newRank < currentRank) {
            this.showToast('Warning', `Cannot move stage backward from ${currentStatus} to ${newStatus}`, 'warning');
            event.target.value = currentStatus; // revert the combobox visually
            return;
        }

        this.opportunityStatusSelections = {
            ...this.opportunityStatusSelections,
            [oppId]: newStatus
        };

        // Clear any previously entered Lost Reason if user moves away from Closed Lost
        if (newStatus !== 'Closed Lost' && this.opportunityLostReasonSelections[oppId]) {
            this.opportunityLostReasonSelections = {
                ...this.opportunityLostReasonSelections,
                [oppId]: ''
            };
        }

        // Clear any previously entered Close Date if user moves away from both Closed states
        if (newStatus !== 'Closed Won' && newStatus !== 'Closed Lost' && this.opportunityCloseDateSelections[oppId]) {
            this.opportunityCloseDateSelections = {
                ...this.opportunityCloseDateSelections,
                [oppId]: ''
            };
        }
    }

    // NEW: handle typing into the Lost Reason field for an Opportunity
    handleOpportunityLostReasonChange(event) {
        const oppId = event.target.dataset.oppid;
        const value = event.target.value;
        this.opportunityLostReasonSelections = {
            ...this.opportunityLostReasonSelections,
            [oppId]: value
        };
    }

    // NEW: handle picking the Close Date for an Opportunity (Closed Won or Closed Lost)
    handleOpportunityCloseDateChange(event) {
        const oppId = event.target.dataset.oppid;
        const value = event.target.value;
        this.opportunityCloseDateSelections = {
            ...this.opportunityCloseDateSelections,
            [oppId]: value
        };
    }

    async updateOpportunityStatusAsync(oppId, newStatus) {
        try {
            const result = await updateOpportunityStatus({
                opportunityId: oppId,
                newStatus: newStatus,
                isCheckedIn: this.isCheckedIn
            });
            if (result.startsWith('WARNING:')) {
                this.showToast('Warning', result.replace('WARNING: ', ''), 'warning');
            }
        } catch (error) {
            console.error('Error updating opportunity status:', error);
            this.showToast('Error', 'Failed to update opportunity status', 'error');
        }
    }

    // ==================== EVENT HANDLERS ====================

    handleBack() {
        // Dispatch event to parent component to go back
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleCancel() {
        // Navigate back without saving
        this.handleBack();
    }

    handleRemarkChange(event) {
        this.dcrRemark = event.target.value;
        this.remarkError = false;
    }

    handleDateChange(event) {
        this.followUpDate = event.target.value;
    }

    handleOpenBrandingFilePicker() {
        this.template.querySelector('[data-id="brandingFileInput"]').click();
    }

    handleBrandingFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;

        const allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'mp4', 'mov'];
        const fileExtension = file.name.split('.').pop().toLowerCase();

        if (!allowedExtensions.includes(fileExtension)) {
            this.showToast('Error', 'Only PDF, Images (JPG/PNG), or Videos (MP4/MOV) are allowed.', 'error');
            event.target.value = '';
            return;
        }

        const maxSize = 3.5 * 1024 * 1024;
        if (file.size > maxSize) {
            this.showToast('Error', 'Please upload a file less than 3.5 MB.', 'error');
            event.target.value = '';
            return;
        }

        const reader = new FileReader();
        reader.onload = (evt) => {
            this.brandingFileData = {
                base64: evt.target.result.split(',')[1],
                fileName: file.name
            };
            this.brandingFileName = file.name;
        };
        reader.readAsDataURL(file);
    }

    handleProductChange(event) {
        this.selectedProducts = event.detail.value || [];
    }

    async loadProductOptions() {
        try {
            if (this.isInClinicBranding && this.eventData.Sub_Call_Type__c) {
                const result = await getProductsBySubCallType({ subCallType: this.eventData.Sub_Call_Type__c });
                this.productOptions = result.map(p => ({ label: p.label, value: p.value }));
            } else {
                this.productOptions = this.productList.map(p => ({ label: p.Name, value: p.Name }));
            }
        } catch (error) {
            console.error('Error loading product options:', error);
            this.productOptions = this.productList.map(p => ({ label: p.Name, value: p.Name }));
        }
    }
    handleUnqualifiedReasonChange(event) {
        const leadId = event.target.dataset.leadid;
        const value = event.detail.value;
        this.leadUnqualifiedReasonSelections = {
            ...this.leadUnqualifiedReasonSelections,
            [leadId]: value
        };
    }
    handleUnqualifiedRemarksChange(event) {
        const leadId = event.target.dataset.leadid;
        const value = event.target.value;
        this.leadUnqualifiedRemarksSelections = {
            ...this.leadUnqualifiedRemarksSelections,
            [leadId]: value
        };
    }
    handleLeadStageChange(event) {
        const leadId = event.target.dataset.leadid;
        const newStage = event.target.value;

        // Update local state
        this.leadStageSelections = {
            ...this.leadStageSelections,
            [leadId]: newStage
        };
        if (newStage !== 'Unqualified' && this.leadUnqualifiedReasonSelections[leadId]) {
            this.leadUnqualifiedReasonSelections = {
                ...this.leadUnqualifiedReasonSelections,
                [leadId]: ''
            };
            if (this.leadUnqualifiedRemarksSelections[leadId]) {
                this.leadUnqualifiedRemarksSelections = { ...this.leadUnqualifiedRemarksSelections, [leadId]: '' };
            }
        }

        // Get lead SAP code for validation
        const lead = this.leadDataList.find(l => l.Id === leadId);

        // Show SAP warning if needed
        if (this.isExcludedCountry && (newStage === 'Evaluations' || newStage === 'Commercialization')) {
            if (!lead?.SAP_Code__c) {
                this.showSapWarning = true;
                this.sapWarningMessage = newStage === 'Evaluations'
                    ? 'Kindly initiate the customer code in SAP'
                    : 'Kindly please fill the SAP code before marking Commercialization';
            }
        } else {
            this.showSapWarning = false;
        }
    }

    async updateLeadStageAsync(leadId, newStage) {
        try {
            const result = await updateLeadStage({ leadId, newStage });
            if (result.startsWith('WARNING:')) {
                this.showToast('Warning', result.replace('WARNING: ', ''), 'warning');
            }
        } catch (error) {
            console.error('Error updating lead stage:', error);
        }
    }

    // BD Tracker handlers
    handleBdCheckboxChange(event) {
        const bdId = event.target.dataset.bdid;
        const isChecked = event.target.checked;
        const bdItem = this.bdTrackerList.find(bd => bd.Id === bdId);

        // Validate BD sequence (PD -> EV -> CM)
        if (isChecked && !this.validateBdSequence(bdId, bdItem.BD_Tracker_Phase__c)) {
            event.target.checked = false;
            return;
        }

        // Update selection
        this.bdSelections = {
            ...this.bdSelections,
            [bdId]: {
                ...this.bdSelections[bdId],
                checked: isChecked
            }
        };

        // If unchecking Product Discussion, uncheck dependent phases
        if (!isChecked && this.isProductDiscussion(bdItem.BD_Tracker_Phase__c)) {
            this.uncheckDependentPhases(bdItem);
        }
    }

    handleBdRemarkChange(event) {
        const bdId = event.target.dataset.bdid;
        const value = event.target.value;

        this.bdSelections = {
            ...this.bdSelections,
            [bdId]: {
                ...this.bdSelections[bdId],
                remark: value
            }
        };
    }

    handleBdDelayReasonChange(event) {
        const bdId = event.target.dataset.bdid;
        const value = event.target.value;

        this.bdSelections = {
            ...this.bdSelections,
            [bdId]: {
                ...this.bdSelections[bdId],
                delayReason: value
            }
        };
    }

    handleBdStageChange(event) {
        const bdId = event.target.dataset.bdid;
        const value = event.target.value;

        this.bdSelections = {
            ...this.bdSelections,
            [bdId]: {
                ...this.bdSelections[bdId],
                bdStage: value
            }
        };
    }

    handleBdSkipReasonChange(event) {
        const bdId = event.target.dataset.bdid;
        const value = event.target.value;

        this.bdSelections = {
            ...this.bdSelections,
            [bdId]: {
                ...this.bdSelections[bdId],
                skipReason: value
            }
        };
    }

    handleBdLostReasonChange(event) {
        const bdId = event.target.dataset.bdid;
        const value = event.target.value;

        this.bdSelections = {
            ...this.bdSelections,
            [bdId]: {
                ...this.bdSelections[bdId],
                lostReason: value
            }
        };
    }

    // ==================== BD TRACKER VALIDATION ====================

    isProductDiscussion(phase) {
        const pdPhases = ['Product Discussion', 'Ürün Tartışması', 'Discussão sobre produtos', 'Discusión de producto'];
        return pdPhases.includes(phase);
    }

    isEvaluation(phase) {
        const evPhases = ['Evaluation', 'Değerlendirme', 'Avaliação', 'Evaluación'];
        return evPhases.includes(phase);
    }

    isCommercialization(phase) {
        const cmPhases = ['Commercialization', 'Ticarileştirme', 'Comercialização', 'Comercialización'];
        return cmPhases.includes(phase);
    }

    validateBdSequence(bdId, phase) {
        const bdItem = this.bdTrackerList.find(bd => bd.Id === bdId);
        if (!bdItem) return true;

        const whatName = bdItem.What?.Name;

        // Find related BD items (same WhatId)
        const relatedItems = this.bdTrackerList.filter(bd => bd.What?.Name === whatName);

        // Check if trying to select Evaluation without Product Discussion
        if (this.isEvaluation(phase)) {
            const pdItem = relatedItems.find(bd => this.isProductDiscussion(bd.BD_Tracker_Phase__c));
            if (pdItem && !this.bdSelections[pdItem.Id]?.checked) {
                this.showToast('Warning', 'Please select Product Discussion first', 'warning');
                return false;
            }
        }

        // Check if trying to select Commercialization without Product Discussion
        if (this.isCommercialization(phase)) {
            const pdItem = relatedItems.find(bd => this.isProductDiscussion(bd.BD_Tracker_Phase__c));
            if (pdItem && !this.bdSelections[pdItem.Id]?.checked) {
                this.showToast('Warning', 'Please select Product Discussion first', 'warning');
                return false;
            }
        }

        return true;
    }

    uncheckDependentPhases(pdItem) {
        const whatName = pdItem.What?.Name;
        const relatedItems = this.bdTrackerList.filter(bd => bd.What?.Name === whatName);

        relatedItems.forEach(bd => {
            if (this.isEvaluation(bd.BD_Tracker_Phase__c) || this.isCommercialization(bd.BD_Tracker_Phase__c)) {
                this.bdSelections = {
                    ...this.bdSelections,
                    [bd.Id]: {
                        ...this.bdSelections[bd.Id],
                        checked: false
                    }
                };
            }
        });
    }

    // Check if evaluation skip reason should be shown
    shouldShowSkipReason(bdItem) {
        if (!this.isCommercialization(bdItem.BD_Tracker_Phase__c)) return false;
        if (!this.bdSelections[bdItem.Id]?.checked) return false;

        // Find related Evaluation
        const whatName = bdItem.What?.Name;
        const evItem = this.bdTrackerList.find(
            bd => bd.What?.Name === whatName && this.isEvaluation(bd.BD_Tracker_Phase__c)
        );

        // Show skip reason if Commercialization is checked but Evaluation is not
        return evItem && !this.bdSelections[evItem.Id]?.checked;
    }

    // ==================== CHECK OUT HANDLER ====================

    /**
     * @description Check Out - validates, saves DCR data, submits, and performs checkout in one action
     * This combines the functionality of the old Save, Submit, and Check Out buttons
     */
    async handleSubmit() {
        // Block checkout if any opportunity stage was moved backward
        if (this.hasBackwardOpportunityMove) {
            this.showToast('Error', 'Cannot check out — an Opportunity stage was moved backward. Please correct it first.', 'error');
            return;
        }
        // Validate remark
        if (!this.dcrRemark || this.dcrRemark.trim() === '') {
            this.remarkError = true;
            this.showToast('Error', 'Please enter the DCR remark', 'error');
            return;
        }

        // Validate lead stage selection
        if (this.hasLeads && this.eventData.Leads__c) {
            const leadStage = this.leadStageSelections[this.eventData.Leads__c];
            if (!leadStage || leadStage === 'None') {
                this.showToast('Error', 'Please select a lead stage', 'error');
                return;
            }
        }
        for (const lead of this.leadDataList) {
            const stage = this.leadStageSelections[lead.Id];
            if (stage === 'Unqualified') {
                const reason = this.leadUnqualifiedReasonSelections[lead.Id];
                if (!reason || !reason.trim()) {
                    this.showToast('Error', `Please enter Unqualified Reason for ${lead.Name}`, 'error');
                    return;
                }
            }
        }

        // Validate opportunity status selection
        if (this.isOpportunityEvent && this.opportunityData && this.opportunityData.length > 0) {
            const hasAnyStatus = Object.values(this.opportunityStatusSelections).some(s => s && s !== 'None');
            if (!hasAnyStatus) {
                this.showToast('Error', 'Please select an opportunity status', 'error');
                return;
            }

            // NEW: require a Lost Reason for any Opportunity moved to Closed Lost
            for (const opp of this.opportunityData) {
                if (this.isOppFrozen(opp.Id)) continue; // CHANGED: skip already-closed opps
                const status = this.opportunityStatusSelections[opp.Id];
                if (status === 'Closed Lost') {
                    const reason = this.opportunityLostReasonSelections[opp.Id];
                    if (!reason || !reason.trim()) {
                        this.showToast('Error', `Please enter a Lost Reason for ${opp.Name}`, 'error');
                        return;
                    }
                }
            }

            // Close Date is mandatory only when moving an Opportunity to Closed Won.
            for (const opp of this.opportunityData) {
                if (this.isOppFrozen(opp.Id)) continue; // skip already-closed opps
                const status = this.opportunityStatusSelections[opp.Id];
                if (status === 'Closed Won') {
                    const closeDate = this.opportunityCloseDateSelections[opp.Id];
                    if (!closeDate || !closeDate.trim()) {
                        this.showToast('Error', `Please select a Close Date for ${opp.Name}`, 'error');
                        return;
                    }
                }
            }
        } // CLOSES: if (this.isOpportunityEvent && this.opportunityData && this.opportunityData.length > 0)

        // Validate branding file — required for In Clinic Branding unless exempt sub call type
        const exemptSubCallTypes = ['Patient Education Videos', 'Vision Simulator'];
        if (this.isInClinicBranding && !exemptSubCallTypes.includes(this.eventData.Sub_Call_Type__c)) {
            if (!this.brandingFileData) {
                this.showToast('Error', 'Branding document is mandatory for In Clinic Branding before checkout', 'error');
                return;
            }
        }

        this.isLoading = true;

        try {
            // Step 1: Save DCR data (equivalent to old Save button)
            const dcrData = this.buildDcrData();
            const saveResult = await saveDCR({ dcrData });

            if (saveResult !== 'SUCCESS') {
                this.showToast('Error', saveResult, 'error');
                this.isLoading = false;
                return;
            }

            // Step 2: Submit DCR (equivalent to old Submit button)
            const submitData = {
                eventId: this.eventId,
                remark: this.dcrRemark,
                followUpDate: this.followUpDate,
                product: this.leadProductGroup
            };
            const submitResult = await submitDCR({ dcrData: submitData });

            if (submitResult !== 'SUCCESS') {
                this.showToast('Error', submitResult, 'error');
                this.isLoading = false;
                return;
            }

            // Step 3: Check Out (equivalent to old Check Out button)
            const checkoutData = this.buildCheckoutData();
            const checkoutResult = await checkOutWithDCR({ checkoutData });

            if (checkoutResult.success) {
                // Upload branding file after successful checkout (if provided)
                if (this.brandingFileData) {
                    try {
                        await uploadBrandingFile({
                            eventId: this.eventId,
                            fileName: this.brandingFileData.fileName,
                            base64Data: this.brandingFileData.base64
                        });
                    } catch (uploadError) {
                        console.error('Branding file upload failed:', uploadError);
                    }
                }

                this.showToast('Success', 'Check out successful', 'success');

                // Navigate back
                this.handleBack();
            } else {
                this.showToast('Error', checkoutResult.message, 'error');
                this.isLoading = false;
            }
        } catch (error) {
            console.error('Error during check out:', error);
            this.showToast('Error', error.body?.message || 'Failed to check out', 'error');
            this.isLoading = false;
        }
    }

    // ==================== DATA BUILDERS ====================

    buildDcrData() {
        // Build BD Plan data string (id:remark,id:remark,...)
        const bdPlanEntries = [];
        const bdReasonEntries = [];
        const skipReasonEntries = [];
        const leadStageEntries = [];
        const unqualifiedReasonEntries = [];
        const unqualifiedRemarkEntries = [];

        Object.keys(this.bdSelections).forEach(bdId => {
            const sel = this.bdSelections[bdId];
            if (sel.checked) {
                bdPlanEntries.push(`${bdId}:${sel.remark || 'Null'}`);
                if (sel.delayReason) {
                    bdReasonEntries.push(`${bdId}:${sel.delayReason}`);
                }
                if (sel.skipReason) {
                    skipReasonEntries.push(`${bdId}:${sel.skipReason}`);
                }
            } else {
                bdPlanEntries.push(`${bdId}:Null`);
            }
        });

        Object.keys(this.leadStageSelections).forEach(leadId => {
            const stage = this.leadStageSelections[leadId];
            if (stage && stage !== 'None') {
                leadStageEntries.push(`${leadId}:${stage}`);
            }
            if (stage === 'Unqualified') {
                const reason = this.leadUnqualifiedReasonSelections[leadId] || '';
                if (reason.trim()) {
                    unqualifiedReasonEntries.push(`${leadId}::${reason.trim()}`); // double-colon delimiter, see note below
                }
                const remarks = this.leadUnqualifiedRemarksSelections[leadId] || '';   // NEW
                if (remarks.trim()) unqualifiedRemarkEntries.push(`${leadId}::${remarks.trim()}`);
            }
        });

        // Add all Opportunity statuses
        const oppStatusEntries = [];
        const oppLostReasonEntries = []; // NEW
        const oppCloseDateEntries = [];  // NEW
        if (this.isOpportunityEvent) {
            Object.keys(this.opportunityStatusSelections).forEach(oppId => {
                if (this.isOppFrozen(oppId)) return; // NEW: don't resend already-closed opps
                const status = this.opportunityStatusSelections[oppId];
                if (status && status !== 'None') {
                    oppStatusEntries.push(`${oppId}:${status}`);
                }
                if (status === 'Closed Lost') {
                    const reason = this.opportunityLostReasonSelections[oppId] || '';
                    if (reason.trim()) {
                        oppLostReasonEntries.push(`${oppId}::${reason.trim()}`);
                    }
                }
                if (status === 'Closed Won' || status === 'Closed Lost') {
                    const closeDate = this.opportunityCloseDateSelections[oppId] || '';
                    if (closeDate.trim()) {
                        oppCloseDateEntries.push(`${oppId}::${closeDate.trim()}`);
                    }
                }
            });
        }

        return {
            eventId: this.eventId,
            remark: this.dcrRemark,
            followUpDate: this.followUpDate,
            product: this.leadProductGroup,
            BDPlan: bdPlanEntries.join(','),
            BDReason: bdReasonEntries.join(','),
            skipReason: skipReasonEntries.join(','),
            leadStages: leadStageEntries.join(','),
            opportunityStatuses: oppStatusEntries.join(','),
            unqualifiedReasons: unqualifiedReasonEntries.join('|'),
            unqualifiedRemarks: unqualifiedRemarkEntries.join('|'),
            opportunityLostReasons: oppLostReasonEntries.join('|'), // NEW
            opportunityCloseDates: oppCloseDateEntries.join('|')    // NEW
        };
    }

    buildCheckoutData() {
        const bdPlanEntries = [];
        const bdReasonEntries = [];
        const skipReasonEntries = [];
        const bdStageEntries = [];
        const lostReasonEntries = [];


        Object.keys(this.bdSelections).forEach(bdId => {
            const sel = this.bdSelections[bdId];
            if (sel.checked) {
                bdPlanEntries.push(`${bdId}:${sel.remark || ''}`);
                if (sel.delayReason) {
                    bdReasonEntries.push(`${bdId}:${sel.delayReason}`);
                }
                if (sel.skipReason) {
                    skipReasonEntries.push(`${bdId}:${sel.skipReason}`);
                }
                if (sel.bdStage) {
                    bdStageEntries.push(`${bdId}:${sel.bdStage}`);
                }
                if (sel.lostReason) {
                    lostReasonEntries.push(`${bdId}:${sel.lostReason}`);
                }
            }
        });

        // Get lead stage
        let leadStage = 'None';
        let leadUnqualifiedReason = '';
        let leadUnqualifiedRemarks = '';
        if (this.eventData.Leads__c && this.leadStageSelections[this.eventData.Leads__c]) {
            leadStage = this.leadStageSelections[this.eventData.Leads__c];
            if (leadStage === 'Unqualified') {
                leadUnqualifiedReason = this.leadUnqualifiedReasonSelections[this.eventData.Leads__c] || '';
                leadUnqualifiedRemarks = this.leadUnqualifiedRemarksSelections[this.eventData.Leads__c] || '';
            }
        }

        // Get status for the event's primary linked opportunity
        let oppStatus = 'None';
        let oppLostReason = ''; // NEW
        let oppCloseDate = '';  // NEW
        if (this.isOpportunityEvent) {
            const linkedOppId = this.eventData.Opportunity__c || this.eventData.WhatId;
            if (linkedOppId && this.opportunityStatusSelections[linkedOppId] && !this.isOppFrozen(linkedOppId)) { // CHANGED: skip if frozen
                oppStatus = this.opportunityStatusSelections[linkedOppId];
                if (oppStatus === 'Closed Lost') {
                    oppLostReason = this.opportunityLostReasonSelections[linkedOppId] || '';
                }
                if (oppStatus === 'Closed Won' || oppStatus === 'Closed Lost') {
                    oppCloseDate = this.opportunityCloseDateSelections[linkedOppId] || '';
                }
            }
        }

        return {
            eventId: this.eventId,
            CheckOutLat: this.userLocation?.latitude,
            CheckOutLong: this.userLocation?.longitude,
            BDPlan: bdPlanEntries.join(','),
            BDReason: bdReasonEntries.join(','),
            skipReason: skipReasonEntries.join(','),
            BDStage: bdStageEntries.join(','),
            LostStageReason: lostReasonEntries.join(','),
            Stage: leadStage,
            UnqualifiedReason: leadUnqualifiedReason,
            UnqualifiedRemarks: leadUnqualifiedRemarks,
            OpportunityStatus: oppStatus,
            OpportunityLostReason: oppLostReason, // NEW
            OpportunityCloseDate: oppCloseDate,   // NEW
            whatId: this.eventData.WhatId,
            Marketing: this.isMarketingUser ? this.leadStageSelections[this.eventData.Leads__c] : null
        };
    }

    validateBdRemarks() {
        let isValid = true;

        Object.keys(this.bdSelections).forEach(bdId => {
            const sel = this.bdSelections[bdId];
            if (sel.checked && (!sel.remark || sel.remark.trim() === '')) {
                isValid = false;
            }
        });

        if (!isValid) {
            this.showToast('Error', 'Please fill in remarks for all selected BD Tracker items', 'error');
        }

        return isValid;
    }

    // ==================== HELPER METHODS ====================

    getUserLocation() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    this.userLocation = {
                        latitude: position.coords.latitude,
                        longitude: position.coords.longitude
                    };
                },
                (error) => {
                    console.error('Geolocation error:', error.message);
                    this.userLocation = null;
                },
                {
                    enableHighAccuracy: true,
                    timeout: 10000,
                    maximumAge: 0
                }
            );
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }

    // BD Tracker helper getters for template {this is commmented by varish and added change 
    //logic below if anything breaks plese check logic and uncomment use this again}
    // get processedBdTrackerList() {
    //     return this.bdTrackerList.map(bd => {
    //         const sel = this.bdSelections[bd.Id] || {};
    //         return {
    //             ...bd,
    //             isChecked: sel.checked || false,
    //             remarkValue: sel.remark || '',
    //             delayReasonValue: sel.delayReason || '',
    //             skipReasonValue: sel.skipReason || '',
    //             bdStageValue: sel.bdStage || 'Won',
    //             lostReasonValue: sel.lostReason || '',
    //             showDelayReason: bd.Milestone_Stage__c === 'Delay',
    //             showBdPlanStatus: this.isCommercialization(bd.BD_Tracker_Phase__c),
    //             showSkipReason: this.shouldShowSkipReason(bd),
    //             contactName: bd.Who?.Name || ''
    //         };
    //     });
    // }

    get processedLeadList() {
        return this.leadDataList.map(lead => {
            const stageOptions = lead.New_Customer__c
                ? this.newCustomerStages
                : lead.Existing_customer__c
                    ? this.existingCustomerStages
                    : this.newCustomerStages;
            const selectedStage = this.leadStageSelections[lead.Id] || 'None';
            const isUnqualified = selectedStage === 'Unqualified';
            return {
                ...lead,
                stageOptions: this.isMarketingUser ? this.marketingStages : stageOptions,
                selectedStage: this.leadStageSelections[lead.Id] || 'None',
                isUnqualified,                         // NEW
                isReasonDisabled: !isUnqualified,       // NEW — disabled unless Unqualified
                unqualifiedReasonValue: this.leadUnqualifiedReasonSelections[lead.Id] || '',
                unqualifiedRemarksValue: this.leadUnqualifiedRemarksSelections[lead.Id] || ''
            };
        });
    }

    get processedLeadList() {
        return this.leadDataList.map(lead => {
            const stageOptions = lead.New_Customer__c
                ? this.newCustomerStages
                : lead.Existing_customer__c
                    ? this.existingCustomerStages
                    : this.newCustomerStages;
            const selectedStage = this.leadStageSelections[lead.Id] || 'None';
            const isUnqualified = selectedStage === 'Unqualified';
            const isConverted = lead.Lead_Stage__c === 'Converted'; // NEW: previous stage already Converted — row is frozen
            return {
                ...lead,
                stageOptions: this.isMarketingUser ? this.marketingStages : stageOptions,
                selectedStage: this.leadStageSelections[lead.Id] || 'None',
                isUnqualified,
                isConverted,                                    // NEW
                isReasonDisabled: !isUnqualified || isConverted, // CHANGED: also disabled when previous stage is Converted
                unqualifiedReasonValue: this.leadUnqualifiedReasonSelections[lead.Id] || '',
                unqualifiedRemarksValue: this.leadUnqualifiedRemarksSelections[lead.Id] || ''
            };
        });
    }



    get processedOpportunityList() {
        return (this.opportunityData || []).map(opp => {
            const selectedStatus = this.opportunityStatusSelections[opp.Id] || 'None';
            const isFrozen = this.isOppFrozen(opp.Id);
            const showLostReason = selectedStatus === 'Closed Lost' && !isFrozen;
            const showCloseDate =
                (selectedStatus === 'Closed Won' || selectedStatus === 'Closed Lost') &&
                !isFrozen;
            const isEquipmentType =
                opp.RecordType && opp.RecordType.Name === 'Equipment';

            return {
                ...opp,
                selectedStatus,
                isFrozen,
                showLostReason,
                lostReasonValue: this.opportunityLostReasonSelections[opp.Id] || '',
                showCloseDate,
                isClosedWon: selectedStatus === 'Closed Won', // <-- Added
                closeDateValue: this.opportunityCloseDateSelections[opp.Id] || '',
                stageOptions: this.getStageOptionsForOpportunity(isEquipmentType),
                isEquipmentType,
                equipmentCompany: this.equipmentCompanyByOpportunity[opp.Id] || '',
                equipmentProduct: this.equipmentProductByOpportunity[opp.Id] || ''
            };
        });
    }
}
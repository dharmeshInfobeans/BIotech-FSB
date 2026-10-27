import { LightningElement, wire, track, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import getLightningPickListValues from '@salesforce/apex/CommonutiltiyClass.getLightningPickListValues';
import getdailyactivity from '@salesforce/apex/CommonutiltiyClass.getdailyactivity';
import getloginlogoutmodule from '@salesforce/apex/CommonutiltiyClass.getCustomLabels';
import leadCreate from '@salesforce/apex/CustomLeadCreationController.leadCreate';
import getProductGroupsByFamily from '@salesforce/apex/CustomLeadCreationController.getProductGroupsByFamily';
import getProductGroups from '@salesforce/apex/TargetProductConfiguratorController.getProductGroups';
import createLeadProductsForLead from '@salesforce/apex/CustomLeadCreationController.createLeadProductsForLead';
import FORM_FACTOR from '@salesforce/client/formFactor';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import { fireEvent } from 'c/pubsub';
import getAccountId from '@salesforce/apex/CustomLeadCreationController.getAccountId';
import getCountryMappingData from '@salesforce/apex/CustomLeadCreationController.getCountryMappingData';
import getCityMappingData from '@salesforce/apex/CustomLeadCreationController.getCityMappingData';
import getCustomLabels from '@salesforce/apex/CustomLeadCreationController.getCustomLabels';
import getUserInformation from '@salesforce/apex/CommonutiltiyClass.getUserInformation';
import { deleteRecord } from 'lightning/uiRecordApi';

export default class CustomLeadForm extends NavigationMixin(LightningElement) {

    // ── Standard tracked props ─────────────────────────────────
    @track leadSoruceList = [];
    @track billingCountryList = [];
    @track productList = [];
    @track subjectList = [];
    @track meetingTypeList = [];
    @track callTypeList = [];
    @track spinner = true;
    @track insEventMap = {};
    @track accountId = '';
    @track leadMap = {};
    @track activity = true;
    @track showFooter = true;
    @track showLead = true;
    @track eventFields = false;
    @track leadId = '';
    @api recordId;
    @api selectedRecord;
    @track dateShowMap = {};
    @track leadSaveUpdate = false;
    @track leadUpdateMap = new Map();
    @track showContact = false;
    @track isClosed = false;
    @track accCheckid = '';
    @track accountAddress = [];
    @track existingLead = 'false';
    @track newLead = 'true';
    @track productDemo = false;
    @track appointmentDemo = false;
    @track presentationDemo = false;
    @track eventAddress = true;
    @track stateList = [];
    @track cityList = [];
    @track eventFieldsRequired = false;
    @track addressspinner = false;
    @track countryError    = '';
    @track stateError      = '';
    @track cityError       = '';
    @track labels = {};
    @track getloginlogoutlabel = {};
    @track evalutaionWeek = false;
    @track commerializationWeek = false;
    @track showMeetingDetails = false;
    @track showDetails = false;
    @track sapCode = false;
    @track userMap = {};
    @track currentEventAddress = '';
    @track leadRelatedData = [];
    @track showRelatedLead = false;
    @track leadEventList = [];
    @track parentaccountId = '';
    @track currentrecord = {};
    @track formFactor = FORM_FACTOR;
    @track isEmbeddedModal = false;
    _embeddedChecked = false;

    // ── Step 2 state ───────────────────────────────────────────
    @track showProductStep = false;
    @track showFamilyDropdown = false;
    @track showProductDropdown = false;
    @track productFamilyOptions = [];
    @track familyProductMap = {};
    @track isSaveClicked=false;

    // ── Error display guard — prevents red borders on initial load ──
    @track showErrors = false;
    allProductGroups = []; 

    // ── Lifecycle ──────────────────────────────────────────────

    loadProductGroups() {
    getProductGroups()
        .then(result => {
            this.allProductGroups = result || [];
            const families = [...new Set(
                this.allProductGroups.map(r => r.Product_Family__c).filter(f => f)
            )];
            this.productFamilyOptions = families.map(fam => ({
                label: fam,
                value: fam,
                selected: false,
                dropItemClass: 'sp2-drop-item',
                checkClass: 'sp2-item-check'
            }));
        })
        .catch(error => {
            console.error('Error loading product groups:', error);
        });
}

connectedCallback() {
        this.leadUpdateMap = undefined;
        this.spinner = true;
        this.insEventMap['CallType'] = '';
        this.insEventMap['MeetingType'] = '';
        this.insEventMap['Subject'] = '';
         this.loadProductGroups();

        if (this.recordId == undefined) {
            this.recordId = '';
        } else {
            getAccountId({ recordId: this.recordId }).then(result => {
                this.currentrecord = result;
                if (result.LeadList != undefined) {
                    this.leadRelatedData = result.LeadList;
                    this.showRelatedLead = true;
                }
                if (result.AccountId != undefined) {
                    this.recordId = result.AccountId;
                    this.accountId = result.AccountId;
                    this.accCheckid = result.AccountId;
                }
                this.showFooter = false;
                if (result.Lead == 'true') {
                    this.newLead = 'true';
                    this.showLead = true;
                    this.eventFields = true;
                    this.showMeetingDetails = true;
                    this.leadId = result.LeadId;
                    this.dateShowMap['productWeek']           = result.DemoWeek;
                    this.dateShowMap['presentationWeek']      = result.Presentatinweek;
                    this.dateShowMap['appointmentWeek']       = result.AppointmentWeek;
                    this.dateShowMap['EvaluationWeek']        = result.EvaluationWeek;
                    this.dateShowMap['CommercializationWeek'] = result.CommercializationWeek;
                    this.dateShowMap['UpgradeWeek']           = result.UpgradeWeek;
                    if (!this.productDemo || !this.presentationDemo || !this.appointmentDemo ||
                        !this.evalutaionWeek || !this.commerializationWeek) {
                        this.eventFields = false;
                    }
                    this.leadUpdateMap = result;
                    if (result.AccountId == undefined) {
                        this.leadMap['createddate']       = result.CreatedDate;
                        this.leadMap['First_Name__c']     = result.FirstName;
                        this.leadMap['Last_Name__c']      = result.lastName;
                        this.leadMap['Email__c']          = result.email;
                        this.leadMap['Billing_Street__c'] = result.billingStreet;
                        this.leadMap['Country__c']        = result.Country;
                        this.leadMap['Billing_state__c']  = result.BillingState;
                        this.leadMap['Billing_City__c']   = result.billingCity;
                        this.leadMap['Mobile__c']         = result.Mobile;
                        this.leadMap['Company__c']        = result.Company;
                        this.leadMap['Product__c']        = result.Product;
                        this.leadMap['Billing_code__c']   = result.ZipCode;
                        this.leadMap['Lead_Stage__c']     = result.LeadStage;
                        this.getCountryWiseData(this.leadMap['Country__c'], this.leadMap['Billing_state__c'], 'false');
                        this.eventAddress = true;
                    }
                }
            }).catch(error => console.log('error', error));
        }
        this.spinner = false;
    }


handleContainerClick() {
        if (this.showFamilyDropdown || this.showProductDropdown) {
            this.showFamilyDropdown = false;
            this.showProductDropdown = false;
        }
    }

    renderedCallback() {
        if (!this._embeddedChecked) {
            this._embeddedChecked = true;
            const host = this.template.host;
            this.isEmbeddedModal = !!(host && host.closest && host.closest('.slds-modal__container'));
        }
    }
    
    // ── Form factor ────────────────────────────────────────────
    get isDesktop() { return this.formFactor === 'Large'; }
    get isPhone()   { return this.formFactor === 'Small'; }

    get lfContainerClass() {
        return this.isEmbeddedModal ? 'lf-container lf-embedded' : 'lf-container';
    }
    get sp2ContainerClass() {
        return this.isEmbeddedModal ? 'sp2-container lf-embedded' : 'sp2-container';
    }


    @wire(CurrentPageReference) pageRef;

    @wire(getCustomLabels)
    getLabels({ data, error }) {
        this.spinner = true;
        if (data) { this.labels = data; this.spinner = false; }
        if (error) console.log('error', error);
    }

    @wire(getloginlogoutmodule)
    getloginlogout({ data, error }) {
        this.spinner = true;
        if (data) { this.getloginlogoutlabel = data; this.spinner = false; }
        if (error) console.log('error', error);
    }

    @wire(getUserInformation)
    getUserData({ data, error }) {
        if (data) { this.userMap = data; this.sapCode = false; }
        if (error) console.log('Error in getting user info', error);
    }

    @wire(getdailyactivity)
    getactivity({ data, error }) {
        try {
            if (data) {
                if (data.activity) {
                    this.activity = true;
                } else {
                    const evt = new ShowToastEvent({
                        title: this.getloginlogoutlabel.Warning__c,
                        message: this.getloginlogoutlabel.Kindly_do_the_Login_before_performing_th__c,
                        variant: this.getloginlogoutlabel.Warning__c
                    });
                    this.dispatchEvent(evt);
                    this.activity = false;
                    if (this.recordId) {
                        this[NavigationMixin.Navigate]({
                            type: 'standard__recordPage',
                            attributes: { recordId: this.recordId, objectApiName: 'Account', actionName: 'view' }
                        });
                    } else {
                        this[NavigationMixin.Navigate]({
                            type: 'standard__objectPage',
                            attributes: { objectApiName: 'Lead__c', actionName: 'list' },
                            state: { filterName: 'Recent' }
                        });
                    }
                }
            }
        } catch (e) { console.log('error', e); }
    }

    @wire(getLightningPickListValues)
    getPickListData({ data, error }) {
        try {
            this.spinner = true;
            if (data) {
                // NOTE: Product Family picklist loaded for Step 2 internally,
                // but the field is NOT shown on Step 1 form anymore.
                this.leadSoruceList     = (data.Lead_Stage__c || []).filter(i => i.value !== 'Upgrade');
                this.billingCountryList = data.Country__c;
                this.productList        = data.Product__c;
                this.subjectList        = data.Subject;
                this.meetingTypeList    = data.Meeting_Type__c;
                this.callTypeList       = data.Call_Type__c;
                // this.productFamilyOptions = (data.Product_Family__c || []).map(f => ({
                //     label: f.label,
                //     value: f.value,
                //     selected: false,
                //     dropItemClass: 'sp2-drop-item',
                //     checkClass: 'sp2-item-check'
                // }));
                 this.spinner = false;
            }
        } catch (e) { console.log('error', e); }
    }

    // ── Step 2 getters ─────────────────────────────────────────
    get selectedFamilies() {
        return this.productFamilyOptions.filter(f => f.selected).map(f => f.value);
    }
    get hasSelectedFamilies() { return this.selectedFamilies.length > 0; }
    get selectedFamilyCount() { return this.selectedFamilies.length; }

    get selectedFamilyPills() {
        return this.productFamilyOptions
            .filter(f => f.selected)
            .map(f => ({ label: f.label, value: f.value }));
    }

    get allProductOptions() {
        const opts = [];
        for (const fam of this.selectedFamilies) {
            const block = this.familyProductMap[fam] || {};
            for (const o of (block.options || [])) {
                opts.push({
                    ...o,
                    key: fam + '_' + o.value,
                    family: fam,
                    dropItemClass: o.selected ? 'sp2-drop-item sp2-drop-item-selected' : 'sp2-drop-item',
                    checkClass: o.selected ? 'sp2-item-check sp2-item-check-active' : 'sp2-item-check'
                });
            }
        }
        return opts;
    }

    get hasAllProductOptions() { return this.allProductOptions.length > 0; }

    get anyFamilyLoading() {
        return this.selectedFamilies.some(fam => {
            const b = this.familyProductMap[fam];
            return b && b.loading;
        });
    }

    get totalSelectedProducts() {
        return Object.values(this.familyProductMap)
            .reduce((sum, b) => sum + (b.options || []).filter(o => o.selected).length, 0);
    }

    get hasSelectedProducts() { return this.totalSelectedProducts > 0; }

    get selectedProductPills() {
        const pills = [];
        for (const fam of this.selectedFamilies) {
            const block = this.familyProductMap[fam] || {};
            for (const o of (block.options || []).filter(o => o.selected)) {
                pills.push({ key: fam + '_' + o.value, label: o.label, value: o.value, family: fam });
            }
        }
        return pills;
    }

    get progressStyle() {
        return `width: ${(this.hasSelectedFamilies ? 50 : 0) + (this.totalSelectedProducts > 0 ? 50 : 0)}%`;
    }

    get step2DotClass() {
        return this.totalSelectedProducts > 0 ? 'sp2-step-dot sp2-dot-active' : 'sp2-step-dot sp2-dot-inactive';
    }
    get step2LabelClass() {
        return this.totalSelectedProducts > 0 ? 'sp2-step-label sp2-label-active' : 'sp2-step-label sp2-label-inactive';
    }

    get summaryFamilyText()    { return this.hasSelectedFamilies ? `${this.selectedFamilyCount}` : 'None'; }
    get summaryFamClass()      { return this.hasSelectedFamilies ? 'sp2-summary-value sp2-summary-value-active' : 'sp2-summary-value'; }
    get summaryTotalProducts() { return this.totalSelectedProducts > 0 ? `${this.totalSelectedProducts}` : 'None'; }
    get summaryGrpClass()      { return this.totalSelectedProducts > 0 ? 'sp2-summary-value sp2-summary-value-active' : 'sp2-summary-value'; }

    get saveSelectionDisabled() {
        if(this.isSaveClicked){
            return true;
        }
        if (!this.hasSelectedFamilies) return true;
        for (const fam of this.selectedFamilies) {
            const block = this.familyProductMap[fam];
            if (block && !block.loading && block.options && block.options.length > 0) {
                if (!block.options.some(o => o.selected)) return true;
            }
        }
        return false;
    }

    // ── showErrors getter — passed to c-searchable-combobox as attribute ──
    // Use in template as: show-errors={showErrors}
    // The child component should suppress red borders when this is false.
    get suppressErrors() { return !this.showErrors; }

    // ── Field error class getters ──────────────────────────────
    get countryFieldClass() { return (this.showErrors && this.countryError) ? 'slds-form-element slds-has-error' : 'slds-form-element'; }
    get stateFieldClass()   { return (this.showErrors && this.stateError)   ? 'slds-form-element slds-has-error' : 'slds-form-element'; }
    get cityFieldClass()    { return (this.showErrors && this.cityError)     ? 'slds-form-element slds-has-error' : 'slds-form-element'; }

    // ── Dropdown toggles ───────────────────────────────────────
    toggleFamilyDropdown(event) {
        event.stopPropagation();
        this.showFamilyDropdown = !this.showFamilyDropdown;
        this.showProductDropdown = false;
    }

    toggleProductDropdown(event) {
        event.stopPropagation();
        this.showProductDropdown = !this.showProductDropdown;
        this.showFamilyDropdown = false;
    }

    // ── Family toggle ──────────────────────────────────────────
    handleFamilyToggle(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        this.productFamilyOptions = this.productFamilyOptions.map(f => {
            if (f.value === val) {
                const nowSelected = !f.selected;
                if (nowSelected && !this.familyProductMap[val]) {
                    this._loadProductNamesForFamily(val);
                }
                return {
                    ...f,
                    selected: nowSelected,
                    dropItemClass: nowSelected ? 'sp2-drop-item sp2-drop-item-selected' : 'sp2-drop-item',
                    checkClass: nowSelected ? 'sp2-item-check sp2-item-check-active' : 'sp2-item-check'
                };
            }
            return f;
        });
    }

    handleRemoveFamily(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        this.productFamilyOptions = this.productFamilyOptions.map(f =>
            f.value === val
                ? { ...f, selected: false, dropItemClass: 'sp2-drop-item', checkClass: 'sp2-item-check' }
                : f
        );
        const block = this.familyProductMap[val];
        if (block) {
            this.familyProductMap = {
                ...this.familyProductMap,
                [val]: { ...block, options: (block.options || []).map(o => ({ ...o, selected: false })) }
            };
        }
    }

    _loadProductNamesForFamily(family) {
        this.familyProductMap = { ...this.familyProductMap, [family]: { loading: true, options: [] } };
        getProductGroupsByFamily({ productFamily: family })
            .then(result => {
                const opts = (result || []).map(o => ({
                    label: o.label, value: o.value, selected: false,
                    dropItemClass: 'sp2-drop-item', checkClass: 'sp2-item-check'
                }));
                this.familyProductMap = { ...this.familyProductMap, [family]: { loading: false, options: opts } };
            })
            .catch(err => {
                console.log('error loading product names for', family, err);
                this.familyProductMap = { ...this.familyProductMap, [family]: { loading: false, options: [] } };
            });
    }

    // ── Product name toggle ────────────────────────────────────
    handleProductNameToggle(event) {
        event.stopPropagation();
        const family = event.currentTarget.dataset.family;
        const val    = event.currentTarget.dataset.value;
        const block  = this.familyProductMap[family];
        if (!block) return;
        const updatedOpts = block.options.map(o => o.value === val ? { ...o, selected: !o.selected } : o);
        this.familyProductMap = { ...this.familyProductMap, [family]: { ...block, options: updatedOpts } };
    }

    handleRemoveProductName(event) {
        event.stopPropagation();
        const family = event.currentTarget.dataset.family;
        const val    = event.currentTarget.dataset.value;
        const block  = this.familyProductMap[family];
        if (!block) return;
        const updatedOpts = block.options.map(o => o.value === val ? { ...o, selected: false } : o);
        this.familyProductMap = { ...this.familyProductMap, [family]: { ...block, options: updatedOpts } };
    }



    handleClearAll() {
        this.productFamilyOptions = this.productFamilyOptions.map(f => ({
            ...f, selected: false, dropItemClass: 'sp2-drop-item', checkClass: 'sp2-item-check'
        }));
        const cleared = {};
        Object.keys(this.familyProductMap).forEach(fam => {
            cleared[fam] = {
                ...this.familyProductMap[fam],
                options: (this.familyProductMap[fam].options || []).map(o => ({ ...o, selected: false }))
            };
        });
        this.familyProductMap = cleared;
    }
        handleProductBack() {
          this.leadMap['Country__c']=this.getLabelFromValue(this.leadMap['Country__c']);
        this.showProductStep = false;
        this.showFamilyDropdown = false;
        this.showProductDropdown = false;
        // No navigation — just goes back to Step 1
        }

    // ══════════════════════════════════════════════════════════════
    // HANDLE NEXT — validates ALL fields including Country/State/City
    // ══════════════════════════════════════════════════════════════
    handleNext() {
        // Enable error display from this point on
        this.showErrors = true;
     
        // 1. Validate standard lightning-input + lightning-combobox fields
        const standardInputs = [
            ...this.template.querySelectorAll('lightning-input.NewForm'),
            ...this.template.querySelectorAll('lightning-combobox.NewForm')
        ];
        let allValid = standardInputs.reduce((valid, input) => {
            if (typeof input.reportValidity === 'function') {
                return input.reportValidity() && valid;
            }
            return valid;
        }, true);

        // 2. Validate c-searchable-combobox fields (Country, State, City)

        if (!allValid) {
            this.showErrorMessage('Please fill all required fields before proceeding.');
            return;
        }

        // 3. Mobile validation
        if (!this.leadMap['Mobile__c'] || this.leadMap['Mobile__c'].trim() === '') {
            this.showErrorMessage('Please Enter Mobile number');
            return;
        }
        const createdDate = this.leadMap['createddate'] ? new Date(this.leadMap['createddate']) : null;
        if ((createdDate && createdDate >= new Date('2025-05-07')) || !this.leadMap['createddate']) {
            if (!/^\d+$/.test(this.leadMap['Mobile__c'])) {
                this.showErrorMessage('Please Enter a valid Mobile number');
                return;
            }
        }

        // 4. Country / State / City — manual inline errors
        this.countryError = '';
        this.stateError   = '';
        this.cityError    = '';

        if (!this.leadMap['Country__c'] || !this.leadMap['Country__c'].trim()) {
            this.countryError = 'Please fill the Country';
            this.showErrorMessage('Please fill the Country');
            return;
        }
        if (!this.leadMap['Billing_state__c'] || !this.leadMap['Billing_state__c'].trim()) {
            this.stateError = 'Please fill the State / Province';
            this.showErrorMessage('Please fill the State / Province');
            return;
        }
        if (this.leadMap['Billing_state__c']) {
            if (!this.stateList.find(d => d.label === this.leadMap['Billing_state__c'])) {
                this.leadMap['Billing_City__c']  = '';
                this.leadMap['Billing_state__c'] = '';
                this.stateError = 'Please fill the correct state and city';
                this.showErrorMessage('Please fill the correct state and city');
                return;
            }
        }
        if (!this.leadMap['Billing_City__c'] || !this.leadMap['Billing_City__c'].trim()) {
            this.cityError = 'Please fill the City';
            this.showErrorMessage('Please fill the City');
            return;
        }
        if (this.leadMap['Billing_City__c']) {
            if (!this.cityList.find(d => d.label === this.leadMap['Billing_City__c'])) {
                this.leadMap['Billing_City__c'] = '';
                this.cityError = 'Please fill the correct city';
                this.showErrorMessage('Please fill the correct city');
                return;
            }
        }

        // 5. Remaining required fields
        if (!this.leadMap['Billing_code__c']) {
            this.showErrorMessage('Please fill the Zip code');
            return;
        }
        if (!this.leadMap['Company__c']) {
            this.showErrorMessage('Please fill the Hospital/Clinic Name');
            return;
        }

        if (
            this.leadMap.Planned_Product_Demo_Week__c ||
            this.leadMap.Planned_Presentation_Week__c ||
            this.leadMap.Planned_Appointments_Week__c
        ) {
            if (!this.insEventMap.CallType)    { this.showErrorMessage(this.labels.Please_fill_the_call_type__c); return; }
            if (!this.insEventMap.MeetingType) { this.showErrorMessage(this.labels.Please_fill_the_meeting_type__c); return; }
            if (!this.insEventMap.Subject)     { this.showErrorMessage(this.labels.Please_fill_the_subject__c); return; }
        }

        if (!this.leadMap['Billing_Street__c'] || !this.leadMap['Billing_Street__c'].trim()) {
            this.showErrorMessage(this.labels.Street_error__c);
            return;
        }

        const email = this.leadMap['Email__c'];
        if (!email || !email.trim()) { this.showErrorMessage('Please Enter Email'); return; }
        if (/\s/.test(email) || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
            this.showErrorMessage(this.labels.Email_invalid_Error_message__c);
            return;
        }
           this.leadMap['Country__c']=this.getValueFromLabel(this.leadMap['Country__c']);
        this.leadMap['New_Customer__c']      = true;
        this.leadMap['Existing_customer__c'] = false;
        if (this.accountId) this.leadMap['Account__c'] = this.accountId;

        // All valid — open product step
        this.showProductStep = true;
    }

    // ── SAVE SELECTION ────────────────────────────────────────
    handleSaveSelection() {
        console.log('is saved clicked');
        if (this.isSaveClicked) { return; }
        this.isSaveClicked = true;
        if (!this.hasSelectedFamilies) {
            this.showErrorMessage('Please select at least one Product Family');
            this.isSaveClicked = false;
            return;
        }
        for (const fam of this.selectedFamilies) {
            const block = this.familyProductMap[fam];
            if (block && !block.loading && block.options && block.options.length > 0) {
                if (!block.options.some(o => o.selected)) {
                    this.showErrorMessage(`Please select at least one Product Name for: ${fam}`);
                    this.isSaveClicked = false;
                    return;
                }
            }
        }
        console.log('currentEventAddress',this.currentEventAddress);
        this.leadSaveUpdate = true;
        this.spinner = true;

        const firstName = this.leadMap['First_Name__c'] || '';
        const lastName  = this.leadMap['Last_Name__c']  || '';
        const baseName  = (firstName + ' ' + lastName).trim() || this.leadMap['Company__c'] || 'New Prospect';
        let rollbackLeadIds = [];
        let chain = Promise.resolve([]);

        this.selectedFamilies.forEach(fam => {
            chain = chain.then(createdIds => {
                const block = this.familyProductMap[fam];
                const groupNames = (block && block.options)
                    ? block.options.filter(o => o.selected).map(o => o.value)
                    : [];

                const familyLeadMap = Object.assign({}, this.leadMap);
                familyLeadMap['Product_Family__c'] = fam;
                familyLeadMap['Name']              = `${baseName} - ${fam}`;


                return leadCreate({
                    leadData:        familyLeadMap,
                    dataMap:         this.insEventMap,
                    accountId:       this.accountId,
                    leadId:          '',
                    existingLead:    'false',
                    newLead:         'true',
                    eventAdress:     this.currentEventAddress,
                    leadEventList:   this.leadEventList,
                    parentaccountId: this.parentaccountId
                }).then(newLeadId => {
                    if (!newLeadId) throw new Error(`Prospect was not created for family: ${fam}`);
                    rollbackLeadIds.push(newLeadId);
                    return createLeadProductsForLead({
                        leadId:        newLeadId,
                        productFamily: fam,
                        groupNames
                    }).then(() => [...createdIds, newLeadId]);
                });
            });
        });

        chain.then(createdIds => {
            this.spinner = false;
            this.isSaveClicked = false;
            this.showSuccessMessage('Prospect updated successfully');
            this.dispatchEvent(new CloseActionScreenEvent());
            if (createdIds.length > 0) {
            this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: { recordId: createdIds[0], objectApiName: 'Lead__c', actionName: 'view' }
                });
            }
        }).catch(error => {
            if (rollbackLeadIds.length > 0) {
                Promise.all(rollbackLeadIds.map(id => deleteRecord(id)))
                    .then(() => console.log('Rollback successful: Deleted orphaned leads.'))
                    .catch(delErr => console.error('Failed to rollback leads:', delErr));
            }
            this.spinner = false;
            this.leadSaveUpdate = false;
            this.isSaveClicked = false;
            const msg = error?.body?.message
                || error?.body?.pageErrors?.[0]?.message
                || error?.message
                || 'Something went wrong while saving.';
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: msg, variant: 'error', mode: 'dismissable' }));
        });
    }

    // ── UPDATE (existing lead) ────────────────────────────────
    handleLeadSave() {
        // Enable error display from this point on
        this.showErrors = true;

        const standardInputs = [
            ...this.template.querySelectorAll('lightning-input.NewForm'),
            ...this.template.querySelectorAll('lightning-combobox.NewForm')
        ];
        let allValid = standardInputs.reduce((valid, input) => {
            if (typeof input.reportValidity === 'function') return input.reportValidity() && valid;
            return valid;
        }, true);

        // Also validate c-searchable-combobox

        if (!allValid) { this.showErrorMessage('Please fill all required fields before saving.'); return; }

        if (!this.leadMap['Mobile__c'] || !this.leadMap['Mobile__c'].trim()) {
            this.showErrorMessage('Please Enter Mobile number'); return;
        }
        const createdDate = this.leadMap['createddate'] ? new Date(this.leadMap['createddate']) : null;
        if ((createdDate && createdDate >= new Date('2025-05-07')) || !this.leadMap['createddate']) {
            if (!/^\d+$/.test(this.leadMap['Mobile__c'])) {
                this.showErrorMessage('Please Enter a valid Mobile number'); return;
            }
        }

        this.countryError = '';
        this.stateError   = '';
        this.cityError    = '';

        if (!this.leadMap['Country__c'] || !this.leadMap['Country__c'].trim()) {
            this.countryError = 'Please fill the Country';
            this.showErrorMessage('Please fill the Country'); return;
        }
        if (!this.leadMap['Billing_state__c'] || !this.leadMap['Billing_state__c'].trim()) {
            this.stateError = 'Please fill the State / Province';
            this.showErrorMessage('Please fill the State / Province'); return;
        }
        if (this.leadMap['Billing_state__c'] &&
            !this.stateList.find(d => d.label === this.leadMap['Billing_state__c'])) {
            this.leadMap['Billing_City__c']  = '';
            this.leadMap['Billing_state__c'] = '';
            this.stateError = 'Please fill the correct state and city';
            this.showErrorMessage('Please fill the correct state and city'); return;
        }
        if (!this.leadMap['Billing_City__c'] || !this.leadMap['Billing_City__c'].trim()) {
            this.cityError = 'Please fill the City';
            this.showErrorMessage('Please fill the City'); return;
        }
        if (this.leadMap['Billing_City__c'] &&
            !this.cityList.find(d => d.label === this.leadMap['Billing_City__c'])) {
            this.leadMap['Billing_City__c'] = '';
            this.cityError = 'Please fill the correct city';
            this.showErrorMessage('Please fill the correct city'); return;
        }

        if (!this.leadMap['Billing_code__c']) { this.showErrorMessage('Please fill the Zip code'); return; }
        if (!this.leadMap['Company__c'])       { this.showErrorMessage('Please fill the Hospital/Clinic Name'); return; }
        if (!this.leadMap['Billing_Street__c'] || !this.leadMap['Billing_Street__c'].trim()) {
            this.showErrorMessage(this.labels.Street_error__c); return;
        }
        const email = this.leadMap['Email__c'];
        if (!email || !email.trim()) { this.showErrorMessage('Please Enter Email'); return; }
        if (/\s/.test(email) || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
            this.showErrorMessage(this.labels.Email_invalid_Error_message__c); return;
        }

        this.leadMap['New_Customer__c']      = true;
        this.leadMap['Existing_customer__c'] = false;
        this.spinner = false;

        leadCreate({
            leadData:        this.leadMap,
            dataMap:         this.insEventMap,
            accountId:       this.accountId,
            leadId:          this.leadId,
            existingLead:    this.existingLead,
            newLead:         this.newLead,
            eventAdress:     this.currentEventAddress,
            leadEventList:   this.leadEventList,
            parentaccountId: this.parentaccountId
        }).then(result => {
            this.leadSaveUpdate = true;
            this.spinner = false;
            this.showSuccessMessage('Prospect updated successfully');
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: result, objectApiName: 'Lead__c', actionName: 'view' }
            });
        }).catch(error => {
            this.spinner = false;
            this.leadSaveUpdate = false;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body.pageErrors[0].message,
                variant: 'error',
                mode: 'dismissable'
            }));
        });
    }

    // ── Shared handlers ───────────────────────────────────────
    handleInslead(event) {
        
         
        console.log('target Name ',event.target.name,'target value',event.target.value);
        if(event.target.name === 'Country__c'){
            
             let values=this.getLabelFromValue(event.target.value);
              console.log('values',values,'event.target.value',event.target.value);
              
            //  this.leadMap[event.target.name] = values;
             this.leadMap = { ...this.leadMap, [event.target.name]: values };
        }else{
              this.leadMap[event.target.name] = event.target.value;
        }
       
      
        if (this.accountId) this.leadMap['Account__c'] = this.accountId;
        this.eventFieldsRequired = !!(
            this.leadMap.Planned_Product_Demo_Week__c ||
            this.leadMap.Planned_Presentation_Week__c ||
            this.leadMap.Planned_Appointments_Week__c
        );

        if (event.target.name === 'Country__c') {
            console.log('billingCountryList',this.billingCountryList,'countryName',this.leadMap);
            this.countryError = '';
            getCountryMappingData({ country: event.target.value }).then(result => {
                this.leadMap['Billing_state__c'] = '';
                this.leadMap['Billing_City__c']  = '';
                this.stateList    = result.State;
                this.cityList     = [];
                this.addressspinner = false;
            }).catch(e => console.log('error', e));
        } else if (event.target.name === 'Billing_state__c') {
            this.stateError = '';
            getCityMappingData({ state: this.leadMap['Billing_state__c'] }).then(result => {
                this.leadMap['Billing_City__c'] = '';
                this.cityList = result.city;
            }).catch(e => console.log('error', e));
        } else if (event.target.name === 'Billing_City__c') {
            this.cityError = '';
        }
    }

    handleCheckbox(event) {
        this.leadMap = { ...this.leadMap, [event.target.name]: event.target.checked };
    }

    handleInsEvent(event) {
        this.currentEventAddress = '';
        switch (event.target.name) {
            case 'CallType':     this.insEventMap['CallType']     = event.target.value; break;
            case 'Subject':      this.insEventMap['Subject']      = event.target.value; break;
            case 'MeetingType':  this.insEventMap['MeetingType']  = event.target.value; break;
            case 'EventAddress': this.currentEventAddress         = event.target.value; break;
        }
    }

    parentRecord(event) {
        const sel = JSON.parse(JSON.stringify(event.detail.selectedRecord));
        if (sel) this.parentaccountId = sel.Id;
    }

      /*  handleCancel() {
            this.showProductStep = false;
            this.showContact = false;

            this.dispatchEvent(new CustomEvent('close'));

            // Navigate to Lead list view, then reload
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: { objectApiName: 'Lead__c', actionName: 'list' },
                state: { filterName: 'Recent' }
            });
        }*/

handleCancel() {
    // Actually close/hide the form itself — don't depend on the parent to do it
    this.isClosed = true;
    this.showProductStep = false;
    this.showContact = false;
    this.showFamilyDropdown = false;
    this.showProductDropdown = false;

    // Fires for Aura wrapper (listens via onclose="{!c.closeqa}")
    this.dispatchEvent(new CustomEvent('close'));

    // Fires for native LWC platform action panel (object-level "New" override)
    this.dispatchEvent(new CloseActionScreenEvent());

    // Navigate back to the Lead / Prospect list view
    this[NavigationMixin.Navigate]({
        type: 'standard__objectPage',
        attributes: { objectApiName: 'Lead__c', actionName: 'list' },
        state: { filterName: 'Recent' }
    });
}

    handleShowContact() { this.showContact = !!(this.accountId); }

    handleGetContactId(event) {
        this.spinner = true;
        if (event.detail) fireEvent(this.pageRef, 'contId', event.detail);
        this.showContact = false;
        this.spinner = false;
    }

    showErrorMessage(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message, variant: 'error', mode: 'dismissable' }));
    }
    showSuccessMessage(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'success', message, variant: 'success', mode: 'dismissable' }));
    }

    getCountryWiseData(country, state) {
        if (country) {
            getCountryMappingData({ country }).then(result => {
                this.stateList      = result.State || [];
                this.cityList       = [];
                this.addressspinner = false;
            }).catch(e => console.log('error', e));
        }
        if (state) {
            getCityMappingData({ state }).then(result => {
                this.cityList = result.city || [];
            }).catch(e => console.log('error', e));
        }
    }

    handleChangeLead(event) {
        const id = event.currentTarget.dataset.id;
        if (event.target.checked) { this.leadEventList.push(id); }
        else { this.leadEventList.splice(this.leadEventList.indexOf(id), 1); }
    }
    getLabelFromValue(selectedValue) {
        const matchedOption = this.billingCountryList.find(option => option.value === selectedValue);
        return matchedOption ? matchedOption.label : null;
    }
    getValueFromLabel(selectedLabel) {
    const matchedOption = this.billingCountryList.find(option => option.label === selectedLabel);
    return matchedOption ? matchedOption.value : null;
}
    
    
}
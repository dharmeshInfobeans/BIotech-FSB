import { LightningElement, api, track, wire } from 'lwc';
import getRecordTypeNameWithId from '@salesforce/apex/ProductConfiguratorController.getRecordTypeNameWithId';
import getFieldSets from '@salesforce/apex/ProductConfiguratorController.getFieldSets';
import getLineItem from '@salesforce/apex/ProductConfiguratorController.getLineItem';
import createMemberAndProductRecord from '@salesforce/apex/ProductConfiguratorController.createMemberAndProductRecord';
import getContactNameById from '@salesforce/apex/ProductConfiguratorController.getContactNameById';
import { getRecord } from 'lightning/uiRecordApi';
import NAME_FIELD from '@salesforce/schema/Campaign__c.Activity_Type__c';
import checkDuplicateMember from '@salesforce/apex/ProductConfiguratorController.checkDuplicateMember';
import { CurrentPageReference } from 'lightning/navigation';
import getAccountCommercialName from '@salesforce/apex/ProductConfiguratorController.getAccountCommercialName';
import getRelatedContactIds from '@salesforce/apex/ProductConfiguratorController.getRelatedContactIds';
import getCountries from '@salesforce/apex/ProductConfiguratorController.getCountries';
import getStates from '@salesforce/apex/ProductConfiguratorController.getStates';
import getCities from '@salesforce/apex/ProductConfiguratorController.getCities';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import CAMPAIGN_OBJECT from '@salesforce/schema/Campaign__c';
import COUNTRY_FIELD from '@salesforce/schema/Campaign__c.Country__c';

// Fields rendered as custom cascade comboboxes — excluded from lightning-input-field
const CASCADE_FIELDS = ['Lead_Country__c', 'Lead_State_Province__c', 'Lead_City__c'];

export default class CreateCampaignMember extends LightningElement {

    @track newcampaignMember = false;
    @api campaignMemberRecordId;
    @api recordId = '';
    @track activityType = '';
    @track selectedFieldSetName = 'CreateCampaignMember';
    @track accountContacts = [];
    @track isLoadingContacts = false;
    @track selectedContactName = '';
    @track selectedAccountId = null;
    @track accountIdForFilter = null;
     recordTypeId;

    @track system_var_Boolean_1 = {
        isShowRecordTypePage: true,
        isShowCreateRecord: false,
        isShowCampaignProduct: false,
        isCampaignMemberFormLoaded: false
    };
    @track system_var_1 = {
        recordTypeList: [],
        selectedRecordTypeId: '',
        campaignMemberRecord: [],
        selectedAccountId: '',
        selectedContactId: '',
        campaignMemberData: {},
        productData: [],
        selectedRows: []
    };

    // ── Country / State / City cascade ────────────────────────────────────
    @track countryOptions = [];
    @track stateOptions = [];
    @track cityOptions = [];
    @track selectedCountry = '';
    @track selectedState = '';
    @track selectedCity = '';

    // NEW — also locks when in Existing member mode
    get isStateDisabled() { return this.newcampaignMember || !this.selectedCountry; }
    get isCityDisabled() { return this.newcampaignMember || !this.selectedState; }
    get isCountryDisabled() { return this.newcampaignMember; }
    // ──────────────────────────────────────────────────────────────────────

    get filter() {
        if (this.system_var_1?.selectedAccountId) {
            return { criteria: [{ fieldPath: 'AccountId', operator: 'eq', value: this.system_var_1.selectedAccountId }] };
        }
        return { criteria: [] };
    }
    get data() { return this.system_var_1.productData; }

    @track productColumn = [
        { label: 'Campaign Line Item Name', fieldName: 'Name' },
        { label: 'Product Family', fieldName: 'Product_Family__c' },
        { label: 'Product Group Name', fieldName: 'GroupName' },
        { label: 'Product Brand', fieldName: 'BrandName' }
    ];

    @wire(getRecord, { recordId: '$recordId', fields: [NAME_FIELD] })
    wiredAccount({ error, data }) {
        if (data) {
            this.activityType = data?.fields?.Activity_Type__c?.value || null;
        } else if (error) {
            console.log('error ', error);
        }
    }
     @wire(getObjectInfo, { objectApiName: CAMPAIGN_OBJECT })
    objectInfo({ data, error }) {
        if (data) {
            this.recordTypeId = data.defaultRecordTypeId;
            console.log('Record Type Id:', this.recordTypeId);
        } else if (error) {
            console.error('Object Info Error:', error);
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$recordTypeId',
        fieldApiName: COUNTRY_FIELD
    })
    wiredCountryValues({ data, error }) {
        if (data) {
               this.countryOptions = data.values.map(d => ({
            label: d.label,
            value: d.value
        }));
            console.log('Country Options:',this.countryOptions);
        } else if (error) {
            console.error('Picklist Error:', JSON.stringify(error));
        }
    }

    get disableContactFilter() { return !this.accountIdForFilter; }
    get disableFirstScreenButton() { return !this.system_var_1?.selectedRecordTypeId; }
    get recordTypeOptions() { return this.system_var_1.recordTypeList || []; }

    get noContactsFound() {
        return !this.isLoadingContacts && this.accountContacts.length === 0;
    }
    get contactInputPlaceholder() {
        if (this.disableContactFilter) return 'Select an Account first...';
        return this.noContactsFound ? 'No contacts found...' : 'Select Contact...';
    }
    get contactComboOptions() {
        return (this.accountContacts || []).map(c => ({ label: c.Name, value: c.Id }));
    }

    // ── Wires ──────────────────────────────────────────────────────────────
    @wire(CurrentPageReference)
    currentPageRef({ state }) {
        if (state) { this.recordId = state.recordId || state.c__recordId; }
    }

    @wire(getRecordTypeNameWithId, { ObjectApiName: 'Campaign_Member__c' })
    recordTypes({ data, error }) {
        if (data) { this.system_var_1.recordTypeList = data; }
        else if (error) { console.log('error while loading record Type', error); }
    }

    @wire(getLineItem, { recordId: '$recordId' })
    lineItem({ data, error }) {
        if (data) {
            this.system_var_1 = {
                ...this.system_var_1,
                productData: data.map(item => ({
                    ...item,
                    BrandName: item.Product_Group__r?.Brand__c,
                    GroupName: item.Product_Group__r?.Name,
                    Product_Family__c: item.Product_Group__r?.Product_Family__c
                }))
            };
            console.log('productData loaded from wire:', this.system_var_1.productData.length);
        } else if (error) { 
            console.log('error57', error); 
        }
    }

    // ── Load fields ────────────────────────────────────────────────────────
    async loadCampaignMemberFields() {
        // Reset cascade state every time the form rebuilds
        this.selectedCountry = '';
        this.selectedState = '';
        this.selectedCity = '';
        this.stateOptions = [];
        this.cityOptions = [];

        try {
            const data = await getFieldSets({
                objectName: 'Campaign_Member__c',
                fieldSetName: this.selectedFieldSetName
            });

            let tempArray = data.map(field => ({
                fieldName: field.fieldName,
                fieldValue: null,
                isDisable: false,
                isRequired: field.isRequired,
                // Flag cascade fields so the template can branch on them
                isCountryField: field.fieldName === 'Lead_Country__c',
                isStateField: field.fieldName === 'Lead_State_Province__c',
                isCityField: field.fieldName === 'Lead_City__c'
            }));

            tempArray.forEach(field => {
                if (field.fieldName === 'Campaign1__c') { field.fieldValue = this.recordId; }
                if (field.fieldName === 'Activity_type__c') { field.fieldValue = this.activityType; }
                if (field.fieldName === 'Account__c') { field.isRequired = true; }

                if (this.newcampaignMember) {           // Existing Member flow
                    if (field.fieldName === 'Account__c') {
                        field.isDisable = false;
                    } else if (field.fieldName === 'Lead_Hospital_Clinic_Name__c') {
                        field.isDisable = true;
                    } else {
                        field.isDisable = true;
                    }
                } else {                                 // New Member flow
                    field.isDisable = false;
                }
            });

            // Insert the Contact combobox placeholder after Account
            const accountIndex = tempArray.findIndex(f => f.fieldName === 'Account__c');
            const insertAt = accountIndex >= 0 ? accountIndex + 1 : tempArray.length;
            tempArray.splice(insertAt, 0, {
                fieldName: 'SalesArea',
                isContactLookup: true,
                isDisable: false
            });

            this.system_var_1.campaignMemberRecord = tempArray;

            // Load countries ONCE — after the field array is ready
            getCountries()
                .then(res => {
                    // this.countryOptions = res.map(d => ({ label: d.label, value: d.value }));
                    console.log('OUTPUT : this.countryOptions', this.countryOptions);
                })
                .catch(() => { });

        } catch (error) {
            console.error('Error loading field set', error);
        }
    }

    // ── Account helpers ────────────────────────────────────────────────────
    async loadAccountContacts(accountId) {
        if (!accountId) return;
        this.isLoadingContacts = true;
        this.accountContacts = [];
        try {
            const contacts = await getRelatedContactIds({ accountId });
            this.accountContacts = (contacts || []).map(c => ({ Id: c.Id, Name: c.Name }));
        } catch (error) {
            console.error('getRelatedContactIds ERROR:', JSON.stringify(error));
            this.accountContacts = [];
        } finally {
            this.isLoadingContacts = false;
        }
    }

    async loadAccountName(accountId) {
        try {
            const clinicName = await getAccountCommercialName({ accountId });
            this.system_var_1 = {
                ...this.system_var_1,
                campaignMemberRecord: this.system_var_1.campaignMemberRecord.map(field =>
                    field.fieldName === 'Lead_Hospital_Clinic_Name__c'
                        ? { ...field, fieldValue: clinicName || null }
                        : field
                )
            };
        } catch (error) {
            console.error('Error fetching account commercial name:', error);
        }
    }

    // ── Cascade handlers ───────────────────────────────────────────────────
    handleCountryChange(event) {
        this.selectedCountry = event.detail.value;
        this.selectedState = '';
        this.selectedCity = '';
        this.stateOptions = [];
        this.cityOptions = [];

        this._syncCascadeField('Lead_Country__c', this.selectedCountry);
        this._syncCascadeField('Lead_State_Province__c', '');
        this._syncCascadeField('Lead_City__c', '');

        if (!this.selectedCountry) return;
        getStates({ country: this.selectedCountry })
            .then(res => { this.stateOptions = res.map(d => ({ label: d.label, value: d.value })); })
            .catch(() => { });
    }

    handleStateChange(event) {
        this.selectedState = event.detail.value;
        this.selectedCity = '';
        this.cityOptions = [];

        this._syncCascadeField('Lead_State_Province__c', this.selectedState);
        this._syncCascadeField('Lead_City__c', '');

        if (!this.selectedState) return;
        getCities({ country: this.selectedCountry, state: this.selectedState })
            .then(res => {
                console.log('city options=============>',res);
                 this.cityOptions = res.map(d => ({ label: d.label, value: d.value })); 
                 })
            .catch(() => { });
    }

    handleCityChange(event) {
        this.selectedCity = event.detail.value;
        this._syncCascadeField('Lead_City__c', this.selectedCity);
    }

    _syncCascadeField(fieldName, value) {
        this.system_var_1 = {
            ...this.system_var_1,
            campaignMemberRecord: this.system_var_1.campaignMemberRecord.map(f =>
                f.fieldName === fieldName ? { ...f, fieldValue: value } : f
            )
        };
    }

    // ── Contact change / prefill ───────────────────────────────────────────
    // handleContactComboChange(event) {
    //     const contactId = event.detail.value;
    //     this.system_var_1 = { ...this.system_var_1, selectedContactId: contactId };
    //     const selected = this.accountContacts.find(c => c.Id === contactId);
    //     this.selectedContactName = selected ? selected.Name : '';
    //     if (contactId) { this.fetchContactName(contactId); }
    // }

    handleContactComboChange(event) {
        const contactId = event.detail.value;

        if (!contactId) {
            this.clearContactFields();
            return;
        }

        this.system_var_1 = { ...this.system_var_1, selectedContactId: contactId };
        const selected = this.accountContacts.find(c => c.Id === contactId);
        this.selectedContactName = selected ? selected.Name : '';
        this.fetchContactName(contactId);
    }

    async fetchContactName(contactId) {
        try {
            const contactNames = await getContactNameById({ contactId });
            console.log('contactNames======>',contactNames)
            this.updateCampaignMemberFields(contactNames);
        } catch (error) {
            console.error('Error fetching contact name:', error);
        }
    }

    updateCampaignMemberFields(contactNames) {
        // 1. Update all non-cascade fields
        const updatedFields = this.system_var_1.campaignMemberRecord.map(field => {
            switch (field.fieldName) {
                case 'Lead_First_Name__c': return { ...field, fieldValue: contactNames.FirstName };
                case 'Lead_Last_Name__c': return { ...field, fieldValue: contactNames.LastName };
                case 'Lead_Email__c': return { ...field, fieldValue: contactNames.Email };
                case 'Lead_Mobile_Number__c': return { ...field, fieldValue: contactNames.MobilePhone };
                case 'Lead_Street__c': return { ...field, fieldValue: contactNames.MailingStreet };
                case 'Lead_Zip_Postal_Code__c': return { ...field, fieldValue: contactNames.MailingPostalCode };
                default: return field;
            }
        });
        this.system_var_1 = { ...this.system_var_1, campaignMemberRecord: updatedFields };

        // 2. Cascade — must load options FIRST, then set value
        const country = contactNames.MailingCountryCode || contactNames.MailingCountry;
        const state = contactNames.MailingStateCode || contactNames.MailingState;
        const city = contactNames.MailingCity;

        if (!country) return;

        getCountries()
            .then(res => {
                // this.countryOptions = res.map(d => ({ label: d.label, value: d.value }));
                this.selectedCountry = this._resolveOptionValue(this.countryOptions, country);
                this._syncCascadeField('Lead_Country__c', this.selectedCountry);

                return getStates({ country: this.selectedCountry });
            })
            .then(res => {
                this.stateOptions = res.map(d => ({ label: d.label, value: d.value }));
                this.selectedState = this._resolveOptionValue(this.stateOptions, state);
                if (this.selectedState) {
                    this._syncCascadeField('Lead_State_Province__c', this.selectedState);
                    return getCities({ country: this.selectedCountry, state: this.selectedState });
                }
                return null;
            })
            .then(res => {
                if (!res) return;
                this.cityOptions = res.map(d => ({ label: d.label, value: d.value }));
                this.selectedCity = this._resolveOptionValue(this.cityOptions, city);
                if (this.selectedCity) {
                    console.log('Lead_City__c',this.selectedCity)
                    this._syncCascadeField('Lead_City__c', this.selectedCity);
                }
            })
            .catch(err => console.error('Cascade prefill error:', err));
    }

    // ── Campaign field change ──────────────────────────────────────────────
    handleCampaignChange(event) {
        const tempList = ['Account__c', 'Campaign1__c'];
        const fieldName = event?.target?.dataset?.field || event?.target?.fieldName;
        const fieldValue = event?.detail?.value;

        if (fieldName === 'Account__c') {
            const accountId = [...(event.detail.value ?? [])][0] ?? null;
            this.accountIdForFilter = accountId;

            if (accountId) {
                this.selectedAccountId = accountId;
                this.system_var_1 = {
                    ...this.system_var_1,
                    selectedAccountId: accountId,
                    selectedContactId: null,
                    campaignMemberRecord: this.system_var_1.campaignMemberRecord.map(f =>
                        f.fieldName === 'Account__c' ? { ...f, fieldValue: accountId } : f
                    )
                };
                this.selectedContactName = '';
                this.loadAccountContacts(accountId);
                this.loadAccountName(accountId);
            } else {
                this.selectedAccountId = null;
                this.system_var_1 = {
                    ...this.system_var_1,
                    selectedAccountId: null,
                    selectedContactId: null,
                    campaignMemberRecord: this.system_var_1.campaignMemberRecord.map(f =>
                        f.fieldName === 'Account__c' ? { ...f, fieldValue: null } : f
                    )
                };
                this.selectedContactName = '';
                // this.accountContacts = [];
                this.clearContactFields();
                this.clearSalesAreaSection();
            }
            return;
        }

        this.system_var_1 = {
            ...this.system_var_1,
            campaignMemberRecord: this.system_var_1.campaignMemberRecord.map(field =>
                field.fieldName === fieldName
                    ? {
                        ...field, fieldValue: tempList.includes(field.fieldName)
                            ? (Array.isArray(fieldValue) ? fieldValue[0] : fieldValue)
                            : fieldValue
                    }
                    : field
            )
        };
    }
    _resolveOptionValue(options, rawValue) {
        if (!rawValue) return '';
        const match = options.find(o =>
            o.value === rawValue ||
            o.label?.toLowerCase() === rawValue?.toLowerCase() ||
            o.value?.toLowerCase() === rawValue?.toLowerCase()
        );
        return match ? match.value : '';
    }
    // ── Save ───────────────────────────────────────────────────────────────
    async handleSaveCampaingMemberAndCampaignMemberProduct() {
        try {
            const selectedRT = this.system_var_1.recordTypeList.find(
                rt => rt.value === this.system_var_1.selectedRecordTypeId
            );

            if (selectedRT?.label === 'New member') {
                const requiredFields = [
                    'Lead_Mobile_Number__c', 'Lead_Email__c', 'Lead_Country__c',
                    'Lead_Zip_Postal_Code__c', 'Lead_Street__c', 'Lead_State_Province__c',
                    'Lead_City__c', 'Lead_Last_Name__c', 'Lead_First_Name__c',
                    'Lead_Hospital_Clinic_Name__c'
                ];
                const allValid = requiredFields.every(fn => {
                    const f = this.system_var_1.campaignMemberRecord.find(r => r.fieldName === fn);
                    return f?.fieldValue !== null && f?.fieldValue !== undefined && f?.fieldValue !== '';
                });

                if (!allValid) {
                    this.template.querySelectorAll('lightning-input-field').forEach(i => i.reportValidity());
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Missing Required Fields', message: 'Please fill the required fields', variant: 'error'
                    }));
                    return;
                }
                // } else if (selectedRT?.label === 'Existing member') {
                //     if (!this.system_var_1.selectedAccountId) {
                //         this.dispatchEvent(new ShowToastEvent({
                //             title: 'Missing Required Fields', message: 'Please select an Account', variant: 'error'
                //         }));
                //         return;
                //     }
                //     if (!this.system_var_1.selectedContactId) {
                //         this.dispatchEvent(new ShowToastEvent({
                //             title: 'Missing Required Fields', message: 'Please select a Contact Person/Dr. Name', variant: 'error'
                //         }));
                //         return;
                //     }
                //     const clinicField = this.system_var_1.campaignMemberRecord.find(
                //         f => f.fieldName === 'Lead_Hospital_Clinic_Name__c'
                //     );
                //     if (!clinicField?.fieldValue) {
                //         this.dispatchEvent(new ShowToastEvent({
                //             title: 'Missing Required Fields', message: 'Please fill the Hospital/Clinic Name', variant: 'error'
                //         }));
                //         return;
                //     }
                // }
            } else if (selectedRT?.label === 'Existing member') {
                if (!this.system_var_1.selectedAccountId) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Missing Required Fields', message: 'Please select an Account', variant: 'error'
                    }));
                    return;
                }
                if (!this.system_var_1.selectedContactId) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Missing Required Fields', message: 'Please select a Contact Person/Dr. Name', variant: 'error'
                    }));
                    return;
                }
                // ── Hospital / Clinic Name ────────────────────────────────────────
                const clinicField = this.system_var_1.campaignMemberRecord.find(f => f.fieldName === 'Lead_Hospital_Clinic_Name__c');
                if (!clinicField?.fieldValue) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Missing Required Fields', message: 'Hospital / Clinic Name is required', variant: 'error'
                    }));
                    return;
                }

                // ── First Name ────────────────────────────────────────────────────
                const firstNameField = this.system_var_1.campaignMemberRecord.find(f => f.fieldName === 'Lead_First_Name__c');
                if (!firstNameField?.fieldValue) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Missing Required Fields', message: 'First Name is required', variant: 'error'
                    }));
                    return;
                }

                // ── Last Name ─────────────────────────────────────────────────────
                const lastNameField = this.system_var_1.campaignMemberRecord.find(f => f.fieldName === 'Lead_Last_Name__c');
                if (!lastNameField?.fieldValue) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Missing Required Fields', message: 'Last Name is required', variant: 'error'
                    }));
                    return;
                }

                // ── Email ─────────────────────────────────────────────────────────
                const emailField = this.system_var_1.campaignMemberRecord.find(f => f.fieldName === 'Lead_Email__c');
                if (!emailField?.fieldValue) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Missing Required Fields', message: 'Email is required', variant: 'error'
                    }));
                    return;
                }

                // ── Mobile Number ─────────────────────────────────────────────────
                const mobileField = this.system_var_1.campaignMemberRecord.find(f => f.fieldName === 'Lead_Mobile_Number__c');
                if (!mobileField?.fieldValue) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Missing Required Fields', message: 'Mobile Number is required', variant: 'error'
                    }));
                    return;
                }

                // ── Country ───────────────────────────────────────────────────────
                if (!this.selectedCountry) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Missing Required Fields', message: 'Country is required', variant: 'error'
                    }));
                    return;
                }

                // ── State ─────────────────────────────────────────────────────────
                if (!this.selectedState) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Missing Required Fields', message: 'State / Province is required', variant: 'error'
                    }));
                    return;
                }

                // ── City ──────────────────────────────────────────────────────────
                if (!this.selectedCity) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Missing Required Fields', message: 'City is required', variant: 'error'
                    }));
                    return;
                }

               

                // ── Zip / Postal Code ─────────────────────────────────────────────
                const zipField = this.system_var_1.campaignMemberRecord.find(f => f.fieldName === 'Lead_Zip_Postal_Code__c');
                if (!zipField?.fieldValue) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Missing Required Fields', message: 'Zip / Postal Code is required', variant: 'error'
                    }));
                    return;
                }

                // Validate ALL non-disabled fields that have a fieldName (skip SalesArea / lookup placeholders)
                // const allValid = this.system_var_1.campaignMemberRecord.every(f => {
                //     if (f.isContactLookup || !f.fieldName || f.isDisable) return true; // skip disabled/lookup
                //     if (!f.isRequired) return true;                                     // skip non-required
                //     return f.fieldValue !== null && f.fieldValue !== undefined && f.fieldValue !== '';
                // });

                // if (!allValid) {
                //     this.dispatchEvent(new ShowToastEvent({
                //         title: 'Missing Required Fields', message: 'Please fill all required fields', variant: 'error'
                //     }));
                //     return;
                // }
            }

            const skipFields = ['SalesArea'];
            let tempData = this.system_var_1.campaignMemberRecord.reduce((acc, item) => {
                if (!skipFields.includes(item.fieldName)) { acc[item.fieldName] = item.fieldValue; }
                return acc;
            }, {});

            tempData['Contact__c'] = this.system_var_1.selectedContactId;
            tempData['Campaign1__c'] = this.recordId;
            tempData['RecordTypeId'] = this.system_var_1.selectedRecordTypeId;
            tempData['Activity_Type__c'] = this.activityType;

            const firstName = tempData['Lead_First_Name__c'];
            const lastName = tempData['Lead_Last_Name__c'];
            this.system_var_1.campaignMemberData = tempData;

            const isDuplicate = await checkDuplicateMember({ campaignId: this.recordId, firstName, lastName });
            if (isDuplicate) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Duplicate Member',
                    message: `A Campaign Member with name "${firstName} ${lastName}" already exists for this Campaign.`,
                    variant: 'error'
                }));
                return;
            }

            await createMemberAndProductRecord({
                campaignMember: JSON.stringify(this.system_var_1.campaignMemberData),
                selectedRows: this.system_var_1.selectedRows
            });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success', message: 'Campaign Member saved successfully', variant: 'success'
            }));
            this.handleCancelPrompt();

        } catch (error) {
            console.error('Error while saving:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Error saving Campaign Member',
                variant: 'error'
            }));
        }
    }

    // ── Navigation & record type ───────────────────────────────────────────
    handleRecordTypeSelect(event) {
        this.system_var_1.selectedRecordTypeId = event.detail.value;
        const selectedRT = this.system_var_1.recordTypeList.find(rt => rt.value === this.system_var_1.selectedRecordTypeId);
        this.newcampaignMember = selectedRT?.label === 'Existing member';
        this.selectedFieldSetName = selectedRT?.label === 'New member' ? 'NewCampaignMember' : 'CreateCampaignMember';
        this.loadCampaignMemberFields();
    }

    handleGoToRecordCreateScreen() {
        console.log('productData on Next click:', JSON.stringify(this.system_var_1.productData));

        if (!this.system_var_1.productData || this.system_var_1.productData.length === 0) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'No Campaign Line Items',
                message: 'Please add Products before adding Campaign Members.',
                variant: 'error'
            }));
            return;
        }

        this.system_var_Boolean_1.isShowRecordTypePage = false;
        this.system_var_Boolean_1.isShowCampaignProduct = false;
        this.system_var_Boolean_1.isShowCreateRecord = true;

        const selectedRT = this.system_var_1.recordTypeList.find(rt => rt.value === this.system_var_1.selectedRecordTypeId);
        this.newcampaignMember = selectedRT?.label === 'Existing member';
        this.selectedFieldSetName = selectedRT?.label === 'New member' ? 'NewCampaignMember' : 'CreateCampaignMember';

        this.accountIdForFilter = null;
        this.selectedAccountId = null;
        this.selectedContactName = '';
        this.accountContacts = [];
        this.loadCampaignMemberFields();
    }

    handleGoBackToRecordTypeScreen() {
        this.system_var_Boolean_1.isShowCreateRecord = false;
        this.system_var_Boolean_1.isShowRecordTypePage = true;
    }

    handleGoBackToRecordCreateScreen() {
        this.system_var_Boolean_1.isShowCampaignProduct = false;
        this.system_var_Boolean_1.isShowCreateRecord = true;
    }

    handleRowSelection(event) { this.system_var_1.selectedRows = event.detail.selectedRows; }

    handleLoadCampaignMemberForm() { this.system_var_Boolean_1.isCampaignMemberFormLoaded = false; }

    handleCancelPrompt() {
        window.history.back();
        setTimeout(() => { window.location.reload(); }, 300);
    }

    clearSalesAreaSection() {
        const recordPicker = this.template.querySelector('.SalesArea-record-picker');
        if (recordPicker) { recordPicker.clearSelection(); }
    }

    clearContactFields() {
        this.selectedCountry = '';
        this.selectedState = '';
        this.selectedCity = '';
        this.stateOptions = [];
        this.cityOptions = [];

        const fieldsToClear = [
            'Lead_First_Name__c', 'Lead_Last_Name__c', 'Lead_Email__c',
            'Lead_Mobile_Number__c', 'Lead_Street__c', 'Lead_Zip_Postal_Code__c',
            'Lead_Country__c', 'Lead_State_Province__c', 'Lead_City__c',
            'Lead_Hospital_Clinic_Name__c'
        ];

        this.system_var_1 = {
            ...this.system_var_1,
            selectedContactId: null,
            campaignMemberRecord: this.system_var_1.campaignMemberRecord.map(f =>
                fieldsToClear.includes(f.fieldName) ? { ...f, fieldValue: null } : f
            )
        };
        this.selectedContactName = '';
    }

connectedCallback() { 
    console.log('recordId', this.recordId);
    console.log('productData at connected:', JSON.stringify(this.system_var_1.productData));
}
}
import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getRecordTypes from '@salesforce/apex/CampaignMemberCtrl.getRecordTypes';
import fetchCampaignData from '@salesforce/apex/CampaignMemberCtrl.fetchCampaignData';
import saveCampaignMember from '@salesforce/apex/CampaignMemberCtrl.saveCampaignMember';
import getAccountDetails from '@salesforce/apex/CampaignMemberCtrl.getAccountDetails';
import getContactDetails from '@salesforce/apex/CampaignMemberCtrl.getContactDetails';

import getCountries from '@salesforce/apex/CampaignMemberCtrl.getCountries';
import getStates from '@salesforce/apex/CampaignMemberCtrl.getStates';
import getCities from '@salesforce/apex/CampaignMemberCtrl.getCities';

export default class CustomCampaignMember extends NavigationMixin(LightningElement) {

    /* ================= API ================= */
    @api recordId;

    /* ================= UI STATE ================= */
    @track step = 1;
    @track isLoading = false;

    /*---------- Edit mode-----------*/
    @track alreadyrecord = false;



    @track isEditMode = false;
    @track existingtype = false;

    selectedRecordTypeId;
    recordTypeOptions = [];
    @track recordTypeName;

    /* ================= DATA MAP ================= */
    @track dynamicFieldValues = {};

    /* ================= LOCATION ================= */
    @track countryOptions = [];
    @track stateOptions = [];
    @track cityOptions = [];

    selectedCountry;
    selectedState;
    selectedCity;

    /* ================= INIT ================= */
    connectedCallback() {
        //console.log('recordId => ', this.recordId);
        this.isLoading = true;

       

       // if (this.recordId || this.recordId == undefined) {
           this.loadCountries();
           console.log('countryOptions line 123',this.countryOptions);
           this.loadData();
      //  } else {
            //this.isLoading = false;

       // }
    }

    /* ================= COMMON GETTERS ================= */

    get isCampaignReadonly() {
        // Campaign locked when opened from Campaign / Edit
        return !!this.recordId;
    }

    get isStepOne() {
        return this.step === 1 && !this.isEditMode;
    }

    get isStepTwo() {
        return this.step === 2;
    }

    get disableNext() {
        return !this.selectedRecordTypeId;
    }

    get isStateDisabled() {
        return !this.stateOptions.length;
    }

    get isCityDisabled() {
        return !this.cityOptions.length;
    }

    get isContactDisabled() {
        return !this.dynamicFieldValues.Account__c;
    }

    get contactFilter() {
        return this.dynamicFieldValues.Account__c
            ? {
                criteria: [
                    {
                        fieldPath: 'AccountId',
                        operator: 'eq',
                        value: this.dynamicFieldValues.Account__c
                    }
                ]
            }
            : null;
    }

    /* ================= LOAD MASTER DATA ================= */

    loadCountries() {
        getCountries()
            .then(res => {
                this.countryOptions = res.map(c => ({ label: c, value: c }));
            })
            .catch(err => console.error('Country error', err));
    }

    /* ================= LOAD RECORD CONTEXT ================= */

  async loadData() {
    this.isLoading = true;

    try {
        console.log('recordId : ',this.recordId);
        const result = await fetchCampaignData({ recordId: this.recordId });
        console.log('fetchCampaignData => ', JSON.stringify(result));

        this.memberTypeOptions = result.memberTypePicklist || [];
        this.campaignProductOptions = result.cmpaignProductList || [];
         const data = { ...result.data };

        // ===== EDIT CAMPAIGN MEMBER =====
        if (result.type === 'CampaignMember') {
            this.alreadyrecord = true;

           
            this.normalizeLookups(data);

            if (data.Attended__c) {
                this.showToast(
                    'Info',
                    'This Campaign Member is already attended.',
                    'info'
                );
                this.dispatchEvent(new CustomEvent('close'));
                return;
            }

            this.existingtype =
                data.RecordtypeName?.Name === 'Existing member';

            // multipicklist
            if (typeof data.Campaign_Product__c === 'string') {
                data.Campaign_Product__c =
                    data.Campaign_Product__c.split(';');
            }

            // assign base data FIRST
            this.dynamicFieldValues = data;
            this.isEditMode = true;
            this.step = 2;

            // 🔥 AUTO-POPULATE (NOW VALID)
            if (this.existingtype) {
                if (data.Account__c) {
                    await this.populateFromAccount(data.Account__c); // ✅ ID already
                }
                if (data.Contact__c) {
                    await this.populateFromContact(data.Contact__c); // ✅ ID already
                }
            }

            this.prefillLocationFields(this.dynamicFieldValues);
        }

        // ===== FROM CAMPAIGN =====
        else if (result.type === 'Campaign') {
            this.alreadyrecord = false;
            this.dynamicFieldValues = {
                Campaign1__c: result.data.Id,
                Campaign_Name__c: result.data.Name
            };
            this.step = 1;
        }else if(result.type === 'Newcampaignmember'){

             this.dynamicFieldValues = data;

            console.log('result--> : ',JSON.stringify(result));

        }

    } catch (err) {
        console.error('loadData error', err);
    } finally {
        this.isLoading = false;
    }
}



    normalizeLookups(data) {
    const lookups = ['Account__c', 'Contact__c', 'Campaign1__c'];

    lookups.forEach(field => {
        if (data[field]?.Id) {
            data[field] = data[field].Id;
        }
    });
}

async populateFromAccount(accountId) {
    if (!accountId) return;

    const acc = await getAccountDetails({ accountId });

    this.dynamicFieldValues = {
        ...this.dynamicFieldValues,
        Account__c: accountId,
        Lead_Hospital_Clinic_Name__c: acc.Name,
        Lead_Country__c: acc.BillingCountry,
        Lead_State_Province__c: acc.BillingState,
        Lead_City__c: acc.BillingCity,
        Lead_Street__c: acc.BillingStreet,
        CampaignPhone__c: acc.Phone,
        Lead_Zip_Postal_Code__c: acc.BillingPostalCode
    };

    this.prefillLocationFields(this.dynamicFieldValues);
}


async populateFromContact(contactId) {
    if (!contactId) return;

    const con = await getContactDetails({ contactId });

    this.dynamicFieldValues = {
        ...this.dynamicFieldValues,
        Contact__c: contactId,
        Lead_First_Name__c: con?.FirstName ?? this.dynamicFieldValues.Lead_First_Name__c,
        Lead_Last_Name__c: con?.LastName ?? this.dynamicFieldValues.Lead_Last_Name__c,
        Lead_Email__c: con?.Email ?? this.dynamicFieldValues.Lead_Email__c,
        Lead_Mobile_Number__c: con?.MobilePhone ?? this.dynamicFieldValues.Lead_Mobile_Number__c,
        CampaignPhone__c: con?.MobilePhone ?? this.dynamicFieldValues.CampaignPhone__c
    };
}



    /* ================= RECORD TYPE ================= */

    @wire(getRecordTypes)
    wiredRecordTypes({ data }) {
        if (data) {
            this.recordTypeOptions = data.map(rt => ({
                label: rt.name,
                value: rt.id
            }));
        }
    }

    get isSaveDisabled() {
        return this.dynamicFieldValues?.Attended__c === true;
    }


    handleRecordTypeChange(event) {
        this.selectedRecordTypeId = event.detail.value;
        console.log('this.selectedRecordTypeId : ', this.selectedRecordTypeId);

        const rt = this.recordTypeOptions.find(
            r => r.value === this.selectedRecordTypeId
        );

        this.recordTypeName = rt?.label;
        this.existingtype = this.recordTypeName === 'Existing member';

        this.dynamicFieldValues = {
            ...this.dynamicFieldValues,
            recordtypeId : this.selectedRecordTypeId
        };
        console.log('this.recordTypeName : ', this.recordTypeName);

        console.log('this.dynamicFieldValues--> : ', JSON.stringify(this.dynamicFieldValues));

    }

    /* ================= RECORD PICKERS ================= */

    handleCampaignChange(event) {
        this.dynamicFieldValues = {
            ...this.dynamicFieldValues,
            Campaign1__c: event.detail.recordId
        };
    }

    async handleAccountChange(event) {
        const accountId = event.detail.recordId;

        if (!accountId) return;
        this.isLoading = true;

        try {
            const acc = await getAccountDetails({ accountId });

            console.log('acc--> : ', JSON.stringify(acc));

            this.dynamicFieldValues = {
                ...this.dynamicFieldValues,
                Account__c: accountId,
                Contact__c: null,
                Lead_Hospital_Clinic_Name__c: acc.Name,
                Lead_Country__c: acc.BillingCountry,
                Lead_State_Province__c: acc.BillingState,
                Lead_City__c: acc.BillingCity,
                Lead_Street__c: acc.BillingStreet,
                CampaignPhone__c: acc.Phone,
                Lead_Zip_Postal_Code__c: acc.BillingPostalCode
            };

            this.prefillLocationFields(this.dynamicFieldValues);

        } catch (error) {
            console.error('Account fetch error', error);
        }
        finally {
            this.isLoading = false;
        }
    }


    async handleContactChange(event) {
        const contactId = event.detail.recordId;
        if (!contactId) return;

        this.isLoading = true;

        try {
            const con = await getContactDetails({ contactId });

            this.dynamicFieldValues = {
                ...this.dynamicFieldValues,
                Contact__c: contactId,

                // 🔥 Auto-fill Lead fields (only if present)
                Lead_First_Name__c: con?.FirstName ?? this.dynamicFieldValues.Lead_First_Name__c,
                Lead_Last_Name__c: con?.LastName ?? this.dynamicFieldValues.Lead_Last_Name__c,
                Lead_Email__c: con?.Email ?? this.dynamicFieldValues.Lead_Email__c,
                CampaignPhone__c: con?.MobilePhone ?? this.dynamicFieldValues.CampaignPhone__c,
                Lead_Mobile_Number__c: con?.MobilePhone ?? this.dynamicFieldValues.Lead_Mobile_Number__c,
            };

            this.prefillLocationFields(this.dynamicFieldValues);

        } catch (error) {
            console.error('Contact fetch error', error);
            // optional toast
            // this.showToast('Error', 'Unable to fetch contact details', 'error');
        }
        finally {
            this.isLoading = false;
        }
    }


    /* ================= LOCATION ================= */

    handleCountryChange(event) {
        this.selectedCountry = event.detail.value;

        this.dynamicFieldValues = {
            ...this.dynamicFieldValues,
            Lead_Country__c: this.selectedCountry,
            Lead_State_Province__c: null,
            Lead_City__c: null
        };

        this.resetStateCity();

        getStates({ country: this.selectedCountry })
            .then(res => {
                this.stateOptions = res.map(s => ({ label: s, value: s }));
            })
            .catch(err => console.error('State error', err));
    }

    handleStateChange(event) {
        this.selectedState = event.detail.value;

        this.dynamicFieldValues = {
            ...this.dynamicFieldValues,
            Lead_State_Province__c: this.selectedState,
            Lead_City__c: null
        };

        this.cityOptions = [];
        this.selectedCity = null;

        getCities({ state: this.selectedState })
            .then(res => {
                this.cityOptions = res.map(c => ({ label: c, value: c }));
            })
            .catch(err => console.error('City error', err));
    }

    handleCityChange(event) {
        this.selectedCity = event.detail.value;

        this.dynamicFieldValues = {
            ...this.dynamicFieldValues,
            Lead_City__c: this.selectedCity
        };
    }

    resetStateCity() {
        this.stateOptions = [];
        this.cityOptions = [];
        this.selectedState = null;
        this.selectedCity = null;
    }

    prefillLocationFields(data) {
        if (!data.Lead_Country__c) return;

        this.selectedCountry = data.Lead_Country__c;

        getStates({ country: this.selectedCountry })
            .then(states => {
                this.stateOptions = states.map(s => ({ label: s, value: s }));

                if (!data.Lead_State_Province__c) return;

                this.selectedState = data.Lead_State_Province__c;

                return getCities({ state: this.selectedState });
            })
            .then(cities => {
                if (cities) {
                    this.cityOptions = cities.map(c => ({
                        label: c,
                        value: c
                    }));
                    this.selectedCity = data.Lead_City__c;
                }
            })
            .catch(err => console.error('Prefill location error', err));
    }

    /* ================= GENERIC FIELD HANDLER ================= */

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        if (!field) return;

        let value =
            event.target.type === 'checkbox'
                ? event.target.checked
                : event.detail?.value ?? event.target.value;

        this.dynamicFieldValues = {
            ...this.dynamicFieldValues,
            [field]: value
        };
    }

    /* ================= STEP NAV ================= */

    handleNext() {
        this.step = 2;
    }

   handleBack() {
    this.step = 1;

    // 🔥 Clear Account / Contact & dependent auto-filled fields
    this.dynamicFieldValues = {
        ...this.dynamicFieldValues,

        // Lookups
        Account__c: null,
        Contact__c: null,

        // Contact-based
        Lead_First_Name__c: '',
        Lead_Last_Name__c: '',
        Lead_Email__c: '',
        Lead_Mobile_Number__c: '',

        // Account-based
        Lead_Hospital_Clinic_Name__c: '',
        CampaignPhone__c: '',
        Lead_Street__c: '',
        Lead_Zip_Postal_Code__c: '',

        // Location fields
        Lead_Country__c: null,
        Lead_State_Province__c: null,
        Lead_City__c: null
    };

    // 🔥 Reset dependent picklists
    this.selectedCountry = null;
    this.selectedState = null;
    this.selectedCity = null;

    this.stateOptions = [];
    this.cityOptions = [];
}


    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    get isIndia() {
    return this.dynamicFieldValues?.Lead_Country__c === 'INDIA';
}

    /* ================= SAVE ================= */

    async handleSave() {

        console.log('dynamicFieldValues--> : ',JSON.stringify(this.dynamicFieldValues));
        if (!this.dynamicFieldValues.Campaign1__c) {
        this.showToast('Missing Field', 'Campaign is required', 'error');
        return;
    }
        
   /* ================= ACCOUNT / CONTACT ================= */
    if (this.existingtype && !this.dynamicFieldValues.Account__c) {
        this.showToast('Missing Field', 'Account is required', 'error');
        return;
    }

    if (this.existingtype && !this.dynamicFieldValues.Contact__c) {
        this.showToast('Missing Field', 'Contact is required', 'error');
        return;
    }

    /* ================= BASIC DETAILS ================= */
    if (!this.dynamicFieldValues.Lead_First_Name__c) {
        this.showToast('Missing Field', 'First Name is required', 'error');
        return;
    }

    if (!this.dynamicFieldValues.Lead_Last_Name__c) {
        this.showToast('Missing Field', 'Last Name is required', 'error');
        return;
    }

    if (!this.dynamicFieldValues.Member_Type__c) {
        this.showToast('Missing Field', 'Member Type is required', 'error');
        return;
    }

    if (!this.dynamicFieldValues.Lead_Hospital_Clinic_Name__c) {
        this.showToast('Missing Field', 'Hospital / Clinic Name is required', 'error');
        return;
    }

    /* ================= LOCATION ================= */
    if (!this.dynamicFieldValues.Lead_Country__c) {
        this.showToast('Missing Field', 'Country is required', 'error');
        return;
    }



        // 🔥 State & City only required for India
        if (this.dynamicFieldValues.Lead_Country__c === 'INDIA') {

            if (!this.dynamicFieldValues.Lead_State_Province__c) {
                this.showToast('Missing Field', 'State is required', 'error');
                return;
            }

            if (!this.dynamicFieldValues.Lead_City__c) {
                this.showToast('Missing Field', 'City is required', 'error');
                return;
            }
        }

    // if (!this.dynamicFieldValues.Lead_State_Province__c) {
    //     this.showToast('Missing Field', 'State is required', 'error');
    //     return;
    // }

    // if (!this.dynamicFieldValues.Lead_City__c) {
    //     this.showToast('Missing Field', 'City is required', 'error');
    //     return;
    // }

    if (!this.dynamicFieldValues.Lead_Street__c) {
        this.showToast('Missing Field', 'Street is required', 'error');
        return;
    }

    if (!this.dynamicFieldValues.Lead_Zip_Postal_Code__c) {
        this.showToast('Missing Field', 'Zip / Postal Code is required', 'error');
        return;
    }

    /* ================= CONTACT INFO ================= */
    if (!this.dynamicFieldValues.Lead_Email__c) {
        this.showToast('Missing Field', 'Email is required', 'error');
        return;
    }

    if (!this.dynamicFieldValues.Lead_Mobile_Number__c) {
        this.showToast('Missing Field', 'Mobile Number is required', 'error');
        return;
    }

    /* ================= CAMPAIGN PRODUCT ================= */
    if (
        !this.dynamicFieldValues.Campaign_Product__c ||
        (Array.isArray(this.dynamicFieldValues.Campaign_Product__c) &&
         this.dynamicFieldValues.Campaign_Product__c.length === 0)
    ) {
        this.showToast('Missing Field', 'At least one Campaign Product is required', 'error');
        return;
    }

    /* ================= ALL VALID → SAVE ================= */
        this.isLoading = true;
        try {
            const payload = { ...this.dynamicFieldValues };

            // multipicklist fix
            if (Array.isArray(payload.Campaign_Product__c)) {
                payload.Campaign_Product__c =
                    payload.Campaign_Product__c.join(';');
            }

            await saveCampaignMember({
                fieldValues: payload,
                recordId: this.recordId
            });

            this.showToast('Success', 'Campaign Member saved successfully', 'success');
            this.dispatchEvent(new CustomEvent('close'));
            

        } catch (err) {
            console.error('Save error', err);
            this.showToast('Error', 'Failed to save Campaign Member', 'error');

        } finally {
            this.isLoading = false;
        }
    }



    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

}
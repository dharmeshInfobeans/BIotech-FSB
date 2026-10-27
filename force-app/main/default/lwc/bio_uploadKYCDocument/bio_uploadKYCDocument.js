// force-app/main/default/lwc/kycUploadDocuments/kycUploadDocuments.js
import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord, getFieldValue, updateRecord } from 'lightning/uiRecordApi';
import getPlantOptions from '@salesforce/apex/Bio_uploadKYCDocument.getPlantOptions';
import getKycData from '@salesforce/apex/Bio_uploadKYCDocument.getRecords';
import uploadFile from '@salesforce/apex/Bio_uploadKYCDocument.uploadFile';
import sendEmailOnUpload from '@salesforce/apex/Bio_uploadKYCDocument.sendEmailOnUpload';
import updateAccountBranch from '@salesforce/apex/Bio_uploadKYCDocument.updateAccountBranch';

import OPPORTUNITY_ACCOUNT_FIELD from '@salesforce/schema/Opportunity__c.Account__c';

// Account fields used in the Customer Details card
import ACC_COMMERCIAL_NAME from '@salesforce/schema/Account.Commercial_Account_Name__c';
import ACC_FIRST_NAME from '@salesforce/schema/Account.First_Name__c';
import ACC_LAST_NAME from '@salesforce/schema/Account.Last_Name__c';
import ACC_CONTACT_PERSON from '@salesforce/schema/Account.Contact_Person__c';
import ACC_EMAIL from '@salesforce/schema/Account.E_Mail__c';
import ACC_BILLING_STREET from '@salesforce/schema/Account.BillingStreet';
import ACC_BILLING_CITY from '@salesforce/schema/Account.BillingCity';
import ACC_BILLING_STATE from '@salesforce/schema/Account.BillingState';
import ACC_BILLING_POSTAL_CODE from '@salesforce/schema/Account.BillingPostalCode';
import ACC_BILLING_COUNTRY from '@salesforce/schema/Account.BillingCountry';

const FIELDS = [OPPORTUNITY_ACCOUNT_FIELD];
const MAX_FILE_BYTES = 5 * 1024 * 1024; // 5 MB
const DEFAULT_PLANT = 'BIOTECH CFA - BARODA';
const MISSING_TOAST_DURATION = 3000; // 3 seconds

// Countries for which the Plant field is hidden entirely (not applicable)
const HIDE_PLANT_COUNTRIES = ['BR'];

const ACCOUNT_FIELDS = [
    ACC_COMMERCIAL_NAME,
    ACC_FIRST_NAME,
    ACC_LAST_NAME,
    ACC_CONTACT_PERSON,
    ACC_EMAIL,
    ACC_BILLING_STREET,
    ACC_BILLING_CITY,
    ACC_BILLING_STATE,
    ACC_BILLING_POSTAL_CODE,
    ACC_BILLING_COUNTRY
];

const REQUIRED_CUSTOMER_FIELDS = [
    { api: 'Commercial_Account_Name__c', label: 'Hospital Name', schema: ACC_COMMERCIAL_NAME },
    { api: 'First_Name__c', label: 'First Name', schema: ACC_FIRST_NAME },
    { api: 'Last_Name__c', label: 'Last Name', schema: ACC_LAST_NAME },
    { api: 'Contact_Person__c', label: 'Contact Person', schema: ACC_CONTACT_PERSON },
    { api: 'E_Mail__c', label: 'Email', schema: ACC_EMAIL },
    { api: 'BillingStreet', label: 'Billing Street', schema: ACC_BILLING_STREET },
    { api: 'BillingCity', label: 'Billing City', schema: ACC_BILLING_CITY },
    { api: 'BillingState', label: 'Billing State', schema: ACC_BILLING_STATE },
    { api: 'BillingPostalCode', label: 'Billing Postal Code', schema: ACC_BILLING_POSTAL_CODE },
    { api: 'BillingCountry', label: 'Billing Country', schema: ACC_BILLING_COUNTRY }
];

export default class KycUploadDocuments extends LightningElement {
    @api recordId;                 // Opportunity__c Id
    @track accountRecordId;        // Derived from Opportunity__c.Account__c
    @track spinner = true;         // initial page-load spinner only

    // Plant combobox
    @track plantList = [];
    @track plant;
    @track plantCode;
    @track country;
    @track error;
    @track plantsLoaded = false;   // true once the getPlantOptions wire has resolved (data or error)

    // ---- Customer Details validation state ----
    @track customerFieldValues = {};   // { fieldApiName: value }
    @track showMissingToast = false;
    @track missingToastMessage = '';
    missingToastTimeoutId;

    // ---- Stage control ----
    @track detailsSaved = false;   // true once the Account has been saved successfully -> locks the form
    @track docsLoading = false;    // true while fetching KYC metadata after a save
    @track submitting = false;     // true while uploading / submitting for approval

    // ---- KYC fetch result (country-driven) ----
    @track records;                // table rows for upload
    @track hideUpload = false;
    @track showMoroccoFields = false;
    @track infoMessage;

    // Upload state
    fileData = {};   // { kycId: { filename, base64, recordId: accountId } }
    reqMap = {};     // { kycId: filename } -> to validate required uploads
    fileMap = {};    // { MasterLabel_clean: 'entered number' }

    // ------------- Derived getters -------------

    get missingCustomerFields() {
        return REQUIRED_CUSTOMER_FIELDS
            .filter(f => {
                const val = this.customerFieldValues[f.api];
                return val === undefined || val === null || String(val).trim() === '';
            })
            .map(f => f.label);
    }

    // True for countries where Plant should not be shown/considered at all
    get hidePlantField() {
        return HIDE_PLANT_COUNTRIES.includes((this.country || '').trim().toUpperCase());
    }

    get showPlantField() {
        return !this.hidePlantField;
    }

    // Plant is "required" (asterisk + factored into validation) only when the
    // field is shown for this country AND there is at least one option to pick.
    get plantRequired() {
        return this.showPlantField && !!(this.plantList && this.plantList.length > 0);
    }

    // When a country has zero configured plants, Plant is simply bypassed:
    // not required, not blocking Save Data.
    get isCustomerDetailsMissing() {
        const noAccount = !this.accountRecordId;
        const plantBlock = this.plantRequired && !this.plant;
        return this.missingCustomerFields.length > 0 || noAccount || plantBlock;
    }

    // Fields/footer for Customer Details are only interactive before the first successful save
    get fieldsDisabled() {
        return this.detailsSaved;
    }

    get showDetailsFooter() {
        return !this.spinner && !this.detailsSaved;
    }

    get saveDisabled() {
        if (this.spinner || this.docsLoading || this.submitting) return true;
        return this.isCustomerDetailsMissing;
    }

    // FIXED: previously only looked at the server's hideUpload flag, which is only
    // ever set true for Morocco/Egypt. Any other country with zero configured KYC
    // documents fell through every section and the Submit button vanished.
    // Now: "no documents needed" is true whenever it's not the Morocco flow AND
    // there's nothing to show in the upload table (either the server told us to
    // hide uploads, or the fetched record list is simply empty).
    get noDocumentsNeeded() {
        if (this.showMoroccoFields) return false;
        if (this.hideUpload) return true;
        return !this.records || this.records.length === 0;
    }

    get showUploadTable() {
        return (
            this.detailsSaved &&
            !this.docsLoading &&
            !this.showMoroccoFields &&
            !this.noDocumentsNeeded &&
            this.records &&
            this.records.length > 0
        );
    }

    get showMoroccoSection() {
        return this.detailsSaved && !this.docsLoading && this.showMoroccoFields;
    }

    get showNoDocsSection() {
        return this.detailsSaved && !this.docsLoading && this.noDocumentsNeeded;
    }

    get uploadDisabled() {
        if (!this.records || this.records.length === 0 || this.submitting) return true;
        const missingNumber = this.records.some(r => r.IsRequired && !this.fileMap[this.cleanKey(r.MasterLabel)]);
        const missingFile = this.records.some(r => r.IsRequired && !this.reqMap[r.Id]);
        return missingNumber || missingFile;
    }

    get computedPlaceholder() {
        return 'Select a plant';
    }

    // ------------- Wires -------------

    // Opportunity -> Account__c
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredOpp({ data, error }) {
        if (data) {
            this.accountRecordId = data.fields.Account__c.value;
            this.spinner = false;
        } else if (error) {
            this.spinner = false;
            this.showToast('Error', 'Unable to load Opportunity Account.', 'error');
        }
    }

    // Prefill Customer Details values from the Account record (so an
    // already-completed Account doesn't get falsely flagged as "missing")
    @wire(getRecord, { recordId: '$accountRecordId', fields: ACCOUNT_FIELDS })
    wiredAccountDetails({ data, error }) {
        if (data) {
            const values = { ...this.customerFieldValues };
            REQUIRED_CUSTOMER_FIELDS.forEach(f => {
                const val = getFieldValue(data, f.schema);
                if (val !== undefined && val !== null) {
                    values[f.api] = val;
                }
            });
            this.customerFieldValues = values;
            if (values.BillingCountry) {
                this.country = values.BillingCountry;   // NEW
            }
        } else if (error) {
            // Account not available yet (e.g. brand new record) - ignore
        }
    }

    // Plant options
    @wire(getPlantOptions, { country: '$country' })
    wiredPlants({ data, error }) {

        if (data) {

            this.plantsLoaded = true;
            this.plantList = data;
            this.error = undefined;

            // Current plant is no longer available for selected country
            if (
                this.plant &&
                !this.plantList.some(opt => opt.value === this.plant)
            ) {
                this.plant = undefined;
                this.plantCode = undefined;
            }

            // No plant selected -> select first plant
            if (!this.plant && this.plantList.length > 0) {

                const defaultOpt = this.plantList[0];
                if(this.country !=='IN'){
                this.plant = defaultOpt.value;
                this.plantCode = defaultOpt.code;
                }
                this.dispatchEvent(
                    new CustomEvent('change', {
                        detail: {
                            field: 'Plant__c',
                            value: this.plant
                        }
                    })
                );

            } else if (this.plant) {

                // Existing plant selected -> find its code
                const selectedOpt = this.plantList.find(
                    opt => opt.value === this.plant
                );

                if (selectedOpt) {
                    this.plantCode = selectedOpt.code;
                } else if (this.plantList.length > 0) {

                    // Fallback -> first plant
                    const defaultOpt = this.plantList[0];

                    this.plant = defaultOpt.value;
                    this.plantCode = defaultOpt.code;

                    this.dispatchEvent(
                        new CustomEvent('change', {
                            detail: {
                                field: 'Plant__c',
                                value: this.plant
                            }
                        })
                    );
                }
            }

        } else if (error) {

            this.plantsLoaded = true;
            this.error = error;
            this.plantList = [];
        }
    }

    // ------------- Customer Details handlers -------------

    handleOpportunityLoad(event) {
        try {
            const map = event.detail?.records || {};
            const oppRec = map[this.recordId];
            const accId = oppRec?.fields?.Account__c?.value;
            if (accId) this.accountRecordId = accId;
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('Opportunity onload parse error:', e);
        }
    }

    handleAccountLookupChange(event) {
        const value = event.detail?.value;
        this.accountRecordId = value;
        if (!value) {
            this.flashMissingToast('Account is missing.');
        }
    }

    handlePlantChange(event) {
        this.plant = event.detail.value;
        const selectedOpt = this.plantList.find(opt => opt.value === this.plant);
        this.plantCode = selectedOpt ? selectedOpt.code : undefined;
        this.dispatchEvent(new CustomEvent('change', {
            detail: { field: 'Plant__c', value: this.plant }
        }));
        if (this.plantRequired && !this.plant) {
            this.flashMissingToast('Plant is missing.');
        }
    }

    // Generic handler wired to every Customer Details field's onchange
    handleCustomerFieldChange(event) {
        const field = event.target.dataset.field;
        if (!field) return;
        const label = event.target.dataset.label || field;
        const value = (event.detail?.value ?? '').toString().trim();

        this.customerFieldValues = { ...this.customerFieldValues, [field]: value };
        if (field === 'BillingCountry') {
            this.country = value;   // NEW - triggers the reactive wire
        }
        if (!value) {
            this.flashMissingToast(`${label} is missing.`);
        }
    }

    // Shows a custom toast banner that auto-hides after 3 seconds
    flashMissingToast(message) {
        this.missingToastMessage = message;
        this.showMissingToast = true;

        if (this.missingToastTimeoutId) {
            clearTimeout(this.missingToastTimeoutId);
        }
        this.missingToastTimeoutId = setTimeout(() => {
            this.showMissingToast = false;
            this.missingToastTimeoutId = null;
        }, MISSING_TOAST_DURATION);
    }

    disconnectedCallback() {
        if (this.missingToastTimeoutId) {
            clearTimeout(this.missingToastTimeoutId);
        }
    }

    cleanKey(label) {
        return (label || '').replace(/ /g, '_');
    }

    // ------------- Stage 1: Save Data -------------

    handleSaveData() {
        if (this.isCustomerDetailsMissing) {
            const missing = this.missingCustomerFields[0]
                || (!this.accountRecordId
                    ? 'Account'
                    : (this.plantRequired && !this.plant) ? 'Plant' : 'Details');
            this.flashMissingToast(`${missing} is missing.`);
            return;
        }
        const form = this.template.querySelector('[data-id="accountForm"]');
        if (!form) {
            this.showToast('Error', 'Account form is missing on the page.', 'error');
            return;
        }

        form.submit();
    }

    async handleAccountSuccess() {
        this.showToast('Success', 'Customer details saved.', 'success');
        // Lock the Customer Details section: fields become read-only and the
        // Save Data / Cancel footer underneath it is removed.
        this.detailsSaved = true;
        await this.callUpdateAccountBranch();
        this.fetchKycDocuments();
    }

    handleAccountError(event) {
        const message = event?.detail?.message || 'An error occurred while saving the Account.';
        this.showToast('Save failed', message, 'error');
    }

    async callUpdateAccountBranch() {
        try {
            await updateAccountBranch({
                accountId: this.accountRecordId,
                plant: this.plant,
                plantCode: this.plantCode
            });
        } catch (e) {
            const msg = e && e.body && e.body.message
                ? e.body.message
                : 'Error updating branch details.';
            this.showToast('Error', msg, 'error');
        }
    }

    // ------------- Stage 2: fetch KYC requirements for the saved country -------------

    fetchKycDocuments() {
        this.docsLoading = true;

        // Country may have changed since the last save - clear any previous
        // upload state so it can't be applied against the wrong document set.
        this.fileData = {};
        this.reqMap = {};
        this.fileMap = {};
        this.records = undefined;

        getKycData({ recordId: this.recordId })
            .then(data => {
                console.log('OUTPUT : data', data);
                const list = data.KycData || [];
                this.records = list.map((r, idx) => ({ ...r, index: idx + 1 }));
                this.hideUpload = !!data.HideUpload;
                this.showMoroccoFields = !!data.ShowMoroccoFields;
                this.infoMessage = data.Message || (this.records.length ? undefined : 'There is no document data to upload.');
            })
            .catch(() => {
                this.showToast('Error', 'Unable to load KYC metadata.', 'error');
            })
            .finally(() => {
                this.docsLoading = false;
            });
    }

    // ------------- Stage 3a: document upload table -------------

    openfileUpload(event) {
        const file = event.target.files && event.target.files[0];
        if (!file) return;

        if (file.size > MAX_FILE_BYTES) {
            this.showToast('Error', 'File size exceeds 5 MB. Please upload a smaller file.', 'error');
            event.target.value = null;
            return;
        }

        const kycId = event.target.dataset.recordId;
        const docLabel = event.currentTarget.dataset.filename || file.name;

        const lastDot = file.name.lastIndexOf('.');
        const ext = lastDot > -1 ? file.name.substring(lastDot + 1) : '';
        const targetFileName = `${docLabel}.${ext}`;

        const reader = new FileReader();
        reader.onload = () => {
            const base64 = reader.result.split(',')[1];

            this.fileData = {
                ...this.fileData,
                [kycId]: {
                    filename: targetFileName,
                    base64,
                    recordId: this.accountRecordId
                }
            };

            this.reqMap[kycId] = targetFileName;

            // Mark row as uploaded (for green tick)
            this.records = this.records.map(row => {
                if (row.Id === kycId) {
                    return {
                        ...row,
                        uploaded: true,
                        AlreadyUpdated: true,
                        uploadedFileName: file.name
                    };
                }
                return row;
            });
        };
        reader.readAsDataURL(file);
    }

    handleDocumentNumberChange(event) {
        const label = event.target.dataset.filename || '';
        const value = (event.target.value || '').trim();
        const key = this.cleanKey(label);
        this.fileMap = { ...this.fileMap, [key]: value };
    }

    validateRequiredFiles() {
        if (!this.records) return false;
        let ok = true;
        let msg = '';
        this.records.forEach(r => {
            if (r.IsRequired && !this.reqMap[r.Id]) {
                ok = false;
                msg += `\nDocument ${r.MasterLabel} is missing. Kindly upload.`;
            }
        });
        if (!ok) this.showToast('Required', msg, 'warning');
        return ok;
    }

    async handleUploadAndSubmit() {
        if (!this.validateRequiredFiles()) return;
        if (!this.accountRecordId) {
            this.showToast('Error', 'No Account found on this Opportunity.', 'error');
            return;
        }

        this.submitting = true;
        try {
            await this.markOpportunityUploaded();

            const uploads = Object.keys(this.fileData).map(kycId => {
                const { base64, filename } = this.fileData[kycId];
                console.log('OUTPUT this.fileMap: ', this.fileMap);
                return uploadFile({
                    base64,
                    filename,
                    recordId: this.recordId,
                    accountId: this.accountRecordId,
                    fileMap: this.fileMap
                }).then(() => {
                    this.showToast('Success', `${filename} uploaded successfully.`, 'success');
                });
            });

            await Promise.all(uploads);
            await sendEmailOnUpload({ oppId: this.recordId });

            this.fileData = {};
            this.showToast('Success', 'Documents uploaded and submitted for approval.', 'success');
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (e) {
            const msg = e && e.body && e.body.message ? e.body.message : 'Error while uploading file(s).';
            this.showToast('Error', msg, 'error');
        } finally {
            this.submitting = false;
        }
    }

    // ------------- Stage 3b: Morocco (numbers only, no upload) -------------

    async handleMoroccoSuccess() {
        this.submitting = true;
        try {
            await this.markOpportunityUploaded();
            await sendEmailOnUpload({ oppId: this.recordId });
            this.showToast('Success', 'Document numbers saved and submitted for approval.', 'success');
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (e) {
            const msg = e && e.body && e.body.message ? e.body.message : 'Error submitting for approval.';
            this.showToast('Error', msg, 'error');
        } finally {
            this.submitting = false;
        }
    }

    // ------------- Stage 3c: no documents needed for this country -------------

    async handleSubmitNoDocuments() {
        this.submitting = true;
        try {
            await this.markOpportunityUploaded();
            await sendEmailOnUpload({ oppId: this.recordId });
            this.showToast('Success', 'Submitted for approval.', 'success');
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (e) {
            const msg = e && e.body && e.body.message ? e.body.message : 'Error submitting for approval.';
            this.showToast('Error', msg, 'error');
        } finally {
            this.submitting = false;
        }
    }

    // ------------- Shared helpers -------------

    async markOpportunityUploaded() {
        if (!this.recordId) return;
        const fields = {};
        fields['Id'] = this.recordId;
        fields['is_Uploaded__c'] = true;
        try {
            await updateRecord({ fields });
        } catch (error) {
            // eslint-disable-next-line no-console
            console.log('error while marking opportunity uploaded', error);
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
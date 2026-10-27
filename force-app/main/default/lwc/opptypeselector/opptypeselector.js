import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getFieldSetFields from '@salesforce/apex/OppTypeSelectorController.getFieldSetFields';
import getRecordTypeIdByName from '@salesforce/apex/OppTypeSelectorController.getRecordTypeIdByName';
import getEquipmentProducts from '@salesforce/apex/OppTypeSelectorController.getEquipmentProducts';
import getEquipmentCompanies from '@salesforce/apex/OppTypeSelectorController.getEquipmentCompanies';
import getDealPeriodOptions from '@salesforce/apex/OppTypeSelectorController.getDealPeriodOptions';
import getProductFamily from '@salesforce/apex/OppTypeSelectorController.getProductFamily';
import getProductsByFamily from '@salesforce/apex/OppTypeSelectorController.getProductsByFamily';
import saveBundleEquipment from '@salesforce/apex/OppTypeSelectorController.saveBundleEquipment';
import saveSoloEquipment from '@salesforce/apex/OppTypeSelectorController.saveSoloEquipment';
import saveOpportunityProducts from '@salesforce/apex/OppTypeSelectorController.saveOpportunityProducts';
import getRelatedContactIds from '@salesforce/apex/OppTypeSelectorController.getRelatedContactIds';
import getCurrentUserVertical from '@salesforce/apex/OppTypeSelectorController.getCurrentUserVertical';
import isEquipmentEnabledForCurrentUser from '@salesforce/apex/OppTypeSelectorController.isEquipmentEnabledForCurrentUser';
import getCustomLabels from '@salesforce/apex/OppTypeSelectorController.getCustomLabels';

const FIELD_SET_MAP = {
    Consumable_Product: 'ConsumableProduct',
    Solo: 'Solo',
    Bundle: 'Bundle'
};

const RECORD_TYPE_MAP = {
    Consumable_Product: 'Product',
    Solo: 'Equipment',
    Bundle: 'Equipment'
};

const EQUIP_OPP_TYPE_MAP = {
    Consumable_Product: null,
    Solo: 'Solo Equipment Sale',
    Bundle: 'Bundle Equipment Deal'
};

const OPTION_META = {
    Consumable_Product: {
        label: 'Consumable Product',
        description: 'Single-use or recurring consumable items billed per unit.',
        icon: 'standard:product'
    },
    Solo: {
        label: 'Solo (Equipment Only)',
        description: 'Standalone equipment opportunity.',
        icon: 'standard:opportunity'
    },
    Bundle: {
        label: 'Bundle (Equipment + Consumable Product)',
        description: 'Bundle equipment opportunity with products.',
        icon: 'standard:opportunity'
    }
};

const STEP_LABELS = {
    Consumable_Product: ['Select Type', 'Fill Details', 'Products'],
    Solo: ['Select Type', 'Fill Details', 'Equipment & Company', 'Quantities & Dates'],
    Bundle: ['Select Type', 'Fill Details', 'Equipment & Company', 'Quantities & Dates', 'Add Products']
};

const BASIC_SPLIT = 4;
const SKIP_FIELDS = new Set(['RecordTypeId']);
const OTHER_VALUE = 'Others';
const FAMILY_FIELD = 'Product_Family__c';

let rowIdCounter = 1;
let equipRowCounter = 1;
let simpleRowCounter = 1;
let userCurrencyCode = '';

const fmtINR = (value) => {
    if (value === null || value === undefined || value === '') return '-';
    const formattedNum = Number(value).toLocaleString('en-IN');
    const currency = userCurrencyCode || 'INR';
    return currency + ' ' + formattedNum;
};

const fmtINRSimple = (value) => {
    if (value === null || value === undefined || value === '') return '-';
    return Number(value).toLocaleString('en-IN');
};

const emptyProductRow = (families) => ({
    id: rowIdCounter++,
    seq: 0,
    productFamily: '',
    productId: '',
    productLabel: '',
    msp: null,
    mspFormatted: '-',
    monthlyQty: '',
    totalDealQty: null,
    totalDealQtyDisplay: '-',
    monthlyDealValue: null,
    monthlyDealValueFormatted: '-',
    totalDealValue: null,
    totalDealValueFormatted: '-',
    productOptions: [],
    familyOptions: families.map(f => ({ ...f, isSelected: false })),
    sfRecordId: null,
    isLoadingProducts: false
});

const emptySimpleRow = (family, sharedOptions) => ({
    id: simpleRowCounter++,
    productFamily: family || '',
    productId: '',
    productLabel: '',
    asp: null,
    aspFormatted: '-',
    qty: 0,
    productOptions: (sharedOptions || []).map(o => ({ ...o, isSelected: false })),
    sfRecordId: null
});

const buildRow = (productOptions, isOther = false, preselectedValue = '') => {
    const allOpts = productOptions.map(p => ({
        ...p,
        isSelected: p.value === preselectedValue
    }));
    return {
        id: equipRowCounter++,
        displayIndex: 0,
        isOther,
        selectedProductId: preselectedValue,
        selectedProductName: preselectedValue
            ? (productOptions.find(p => p.value === preselectedValue)?.label || '')
            : '',
        otherEquipmentName: '',
        otherCompanyName: '',
        selectedCompany: '',
        quantity: 1,
        equipmentValue: '',
        companyOptions: [],
        productOptions: allOpts,
        normalProductOptions: allOpts.filter(o => o.value !== OTHER_VALUE),
        otherProductOptions: isOther
            ? [{ value: OTHER_VALUE, label: 'Others', isSelected: true }]
            : allOpts.filter(o => o.value === OTHER_VALUE)
    };
};

const _reindexRows = (rows) => {
    let normalIdx = 0;
    let otherIdx = 0;
    rows.forEach(row => {
        row.displayIndex = row.isOther ? ++otherIdx : ++normalIdx;
    });
    return rows;
};

const _reseqProductRows = (rows) => {
    return rows.map((row, index) => ({ ...row, seq: index + 1 }));
};

export default class Opptypeselector extends NavigationMixin(LightningElement) {

    @track isModalOpen = false;
    @track currentStep = 1;
    @track selectedValue = '';
    @track selectedAccountId = null;
    @track selectedContactId = null;
    @track showValidationError = false;
    @track validationMessage = 'Please select an opportunity type before continuing.';

    @track allFields = [];
    @track fieldValues = {};
    @track showSpinner = false;
    @track stepSpinner = false;
    @track isSaving = false;
    @track hasSaveError = false;
    @track saveErrorMessage = '';
    @track currentRecordTypeId = null;

    @track accountContacts = [];
    @track isLoadingContacts = false;
    @track contactSearchTerm = '';
    @track contactSearchFocused = false;
    @track contactHasError = false;

    @track equipmentRows = [];
    @track showEquipmentStepError = false;
    @track equipmentStepErrorMsg = '';
    _equipmentProductOptions = [];

    @track createdRecordId = null;
    @track downPayment = '';
    @track totalDealPeriod = '';
    @track dealPeriodOptions = [];

    @track productRows = [];
    _allFamilies = [];
    _productsInitialized = false;

    @track simpleProductRows = [];
    @track consumableFamily = '';
    _sharedSimpleProductOptions = [];
    _consumableProductsInitialized = false;

    _lastPageRef = null;

    @track productFamilyOptions = [];
    @track isLoadingProductFamily = false;
    @track productFamilyHasError = false;
    @track productFamilySearchTerm = '';
    @track productFamilySearchFocused = false;
    @track userCurrencyCode = '';

    // Solo/Bundle are gated per country (SAP_Country_Config__mdt.Equipment_Enabled__c).
    // Defaults to true so the type-selection screen still renders while the check is in flight.
    @track equipmentEnabled = true;


    @track labels = {};

    @wire(getCustomLabels)
    getLabels({ data, error }) {
        if (data) { this.labels = data; }
        if (error) console.log('error', error);
    }

    @wire(CurrentPageReference)
    getPageReferenceParameters(currentPageReference) {
        if (currentPageReference) {
            const key = JSON.stringify(currentPageReference);
            if (this._lastPageRef === key) {
                if (!this.isModalOpen) {
                    this.openModal();
                }
            } else {
                this._lastPageRef = key;
                this.openModal();
            }
        }
    }

    connectedCallback() {
        this._escHandler = this.handleEscKey.bind(this);
        document.addEventListener('keydown', this._escHandler);
        this.loadDealPeriodOptions();
    }

    disconnectedCallback() {
        document.removeEventListener('keydown', this._escHandler);
    }

    handleEscKey(event) {
        if (event.key === 'Escape' && this.isModalOpen) this.handleClose();
    }

    get isWorking() {
        return this.showSpinner || this.isSaving || this.stepSpinner;
    }

    get isStep1() {
        return this.currentStep === 1;
    }

    get isConsumableStep2() {
        return this.currentStep === 2 && this.selectedValue === 'Consumable_Product';
    }

    get isSoloOrBundleStep2() {
        return this.currentStep === 2 &&
            (this.selectedValue === 'Solo' || this.selectedValue === 'Bundle');
    }

    get isConsumableProductsStep() {
        return this.currentStep === 3 && this.selectedValue === 'Consumable_Product';
    }

    get isEquipmentStep1() {
        return this.currentStep === 3 &&
            (this.selectedValue === 'Solo' || this.selectedValue === 'Bundle');
    }

    get isEquipmentStep2() {
        return this.currentStep === 4 &&
            (this.selectedValue === 'Solo' || this.selectedValue === 'Bundle');
    }

    get isAddProductsStep() {
        return this.currentStep === 5 && this.selectedValue === 'Bundle';
    }

    get isBundle() { return this.selectedValue === 'Bundle'; }
    get isConsumable() { return this.selectedValue === 'Consumable_Product'; }

    get saveButtonLabel() {
        return (this.selectedValue === 'Solo' || this.selectedValue === 'Bundle')
            ? 'Save & Continue'
            : 'Save Opportunity';
    }

    get saveEquipmentButtonLabel() {
        return this.isBundle ? 'Next: Add Products' : 'Save Record';
    }

    get hasAccountContacts() { return this.accountContacts.length > 0; }

    get filteredContactOptions() {
        const q = (this.contactSearchTerm || '').toLowerCase();
        if (!q) return this.accountContacts;
        return this.accountContacts.filter(c => c.Name.toLowerCase().includes(q));
    }

    get filteredProductFamilyOptions() {
        const q = (this.productFamilySearchTerm || '').toLowerCase();
        if (!q) return this.productFamilyOptions;
        return this.productFamilyOptions.filter(o => o.label.toLowerCase().includes(q));
    }

    get showProductFamilyDropdown() {
        return this.productFamilySearchFocused && this.filteredProductFamilyOptions.length > 0;
    }
    get selectedContactName() {
        if (!this.selectedContactId) return '';
        const found = this.accountContacts.find(c => c.Id === this.selectedContactId);
        return found ? found.Name : '';
    }

    get showContactDropdown() {
        return this.contactSearchFocused && this.filteredContactOptions.length > 0;
    }

    get totalSteps() {
        return STEP_LABELS[this.selectedValue]?.length || 2;
    }

    get modalSubtitle() {
        return `Create a new opportunity in ${this.totalSteps} step${this.totalSteps === 1 ? '' : 's'}`;
    }

    get progressSteps() {
        const labels = STEP_LABELS[this.selectedValue] || ['Select Type', 'Fill Details'];
        return labels.flatMap((label, index) => {
            const number = index + 1;
            const isDone = this.currentStep > number;
            const isActive = this.currentStep === number;
            return [{
                key: `step-${number}`,
                number,
                label,
                itemClass: `step-item${isDone ? ' step-done' : ''}${isActive ? ' step-current' : ''}`,
                showCheck: isDone,
                showLine: index < labels.length - 1,
                lineKey: `line-${number}`,
                lineFillClass: `progress-fill${isDone ? ' filled' : ''}`
            }];
        });
    }

    get radioOptions() {
        const keys = this.equipmentEnabled
            ? Object.keys(OPTION_META)
            : Object.keys(OPTION_META).filter(value => value === 'Consumable_Product');
        return keys.map((value) => ({
            value,
            label: OPTION_META[value].label,
            description: OPTION_META[value].description,
            icon: OPTION_META[value].icon,
            isSelected: this.selectedValue === value,
            cardClass: `type-card${this.selectedValue === value ? ' card-active' : ''}`
        }));
    }

    // When Equipment is disabled for the user's country, Consumable_Product is
    // auto-selected and Step 1 is skipped entirely, so there is nothing to go back to.
    get canGoBackToTypeSelection() {
        return this.equipmentEnabled && !this.createdRecordId;
    }

    get selectedTypeLabel() {
        return this.selectedValue ? OPTION_META[this.selectedValue].label : '';
    }

    get selectedTypeIcon() {
        return 'standard:opportunity';
    }

    get basicFields() { return this.allFields.slice(0, BASIC_SPLIT); }
    get additionalFields() { return this.allFields.slice(BASIC_SPLIT); }
    get hasAdditionalFields() { return this.additionalFields.length > 0; }

    get normalEquipmentRows() {
        return this.equipmentRows.filter(r => !r.isOther);
    }

    get otherEquipmentRows() {
        return this.equipmentRows.filter(r => r.isOther);
    }
get modalBodyClass() {
    return (this.isConsumableStep2 || this.isSoloOrBundleStep2)
        ? 'modal-body modal-body-overflow'
        : 'modal-body';
}
    get hasNormalRows() { return this.normalEquipmentRows.length > 0; }
    get hasOtherRows() { return this.otherEquipmentRows.length > 0; }
    get hasEquipmentRows() { return this.equipmentRows.length > 0; }
    get equipmentRowCount() { return this.equipmentRows.length; }
    get normalRowCount() { return this.normalEquipmentRows.length; }
    get otherRowCount() { return this.otherEquipmentRows.length; }

    get selectedEquipments() {
        return this.equipmentRows.map(row => ({
            id: String(row.id),
            name: row.isOther
                ? (row.otherEquipmentName || 'Others')
                : (row.selectedProductName || ''),
            selectedCompany: row.isOther
                ? (row.otherCompanyName || '')
                : (row.selectedCompany || ''),
            quantity: row.quantity,
            equipmentValue: row.equipmentValue
        }));
    }

    get isNextDisabled() {
        if (this.isWorking) return true;
        if (!this.equipmentRows.length) return true;
        return this.equipmentRows.some(row => {
            if (!row.selectedProductId) return true;
            if (row.isOther) {
                return !row.otherEquipmentName.trim() || !row.otherCompanyName.trim();
            }
            return false;
        });
    }

    get computedTotalValue() {
        return this.selectedEquipments.reduce((sum, eq) => {
            return sum + (Number(eq.equipmentValue) || 0) * (Number(eq.quantity) || 0);
        }, 0);
    }

    get computedTotalValueFormatted() { return fmtINR(this.computedTotalValue); }

    get netEquipmentFundingValue() {
        return (Number(this.computedTotalValue) || 0) - (Number(this.downPayment) || 0);
    }

    get netEquipmentFundingValueFormatted() {
        return fmtINR(this.netEquipmentFundingValue || null);
    }

    get hasDealPeriod() { return !!this.totalDealPeriod; }

    get isSaveDisabled() {
        if (this.isWorking) return true;
        if (this.selectedValue === 'Bundle' && !this.totalDealPeriod) return true;
        if (this.selectedValue === 'Solo' && !this.totalDealPeriod) return true;
        return false;
    }

    get startDate() {
        if (!this.totalDealPeriod) return null;
        return this.isoDate(new Date());
    }

    get endDate() {
        if (!this.totalDealPeriod) return null;
        const months = parseInt(this.totalDealPeriod.replace(/[^0-9]/g, ''), 10);
        if (Number.isNaN(months)) return null;
        const today = new Date();
        const end = new Date(today.getFullYear(), today.getMonth() + months, today.getDate());
        return this.isoDate(end);
    }

    get hasProductRows() { return this.productRows.length > 0; }

    get grandTotal() {
        return this.productRows.reduce((sum, row) => sum + (Number(row.totalDealValue) || 0), 0);
    }

    get grandTotalFormatted() { return fmtINR(this.grandTotal || null); }

    get dealFactor() {
        // Deal Factor = Total_Deal_Value_for_Product__c / Equipment_Net_Value__c
        // grandTotal represents Total_Deal_Value_for_Product__c (sum of product totalDealValue)
        // netEquipmentFundingValue represents Equipment_Net_Value__c (equipment total minus down payment)
        const netEquipmentValue = Number(this.netEquipmentFundingValue) || 0;
        return (this.grandTotal && netEquipmentValue) ? this.grandTotal / netEquipmentValue : null;
    }

    get dealFactorFormatted() {
        const v = this.dealFactor;
        return v === null ? '-' : v.toFixed(2);
    }

    get totalProducts() {
        return this.productRows.filter(r => r.productId).length;
    }

    get hasSimpleRows() { return this.simpleProductRows.length > 0; }

    get displaySimpleRows() {
        return this.simpleProductRows.map((row, index) => ({
            ...row,
            seq: index + 1
        }));
    }

    get simpleTotalProducts() {
        return this.simpleProductRows.filter(r => r.productId).length;
    }

    get consumableFamilyDisplay() { return this.consumableFamily || '-'; }

    get simpleReadyCount() {
        return this.simpleProductRows.filter(r =>
            r.productFamily && r.productId && r.qty != null && Number(r.qty) > 0
        ).length;
    }

    get simpleRowCountText() {
        const total = this.simpleProductRows.length;
        const ready = this.simpleReadyCount;
        return `${total} row${total !== 1 ? 's' : ''} — ${ready} selected`;
    }

    get simpleReadyText() {
        const ready = this.simpleReadyCount;
        return `${ready} product${ready !== 1 ? 's' : ''} ready to save`;
    }

    get isSimpleSaveDisabled() {
        if (this.isWorking) return true;
        if (this.simpleProductRows.length === 0) return false;
        return !this.simpleProductRows.every(r =>
            r.productFamily &&
            r.productId &&
            r.qty != null && r.qty !== '' && Number(r.qty) > 0
        );
    }

    async openModal() {
        this.isModalOpen = true;
        this.currentStep = 1;
        this.selectedValue = '';
        this.selectedAccountId = null;
        this.selectedContactId = null;
        this.createdRecordId = null;
        this.allFields = [];
        this.fieldValues = {};
        this.equipmentRows = [];
        this.productRows = [];
        this.simpleProductRows = [];
        this.consumableFamily = '';
        this.downPayment = '';
        this.totalDealPeriod = '';
        this.showValidationError = false;
        this.hasSaveError = false;
        this._productsInitialized = false;
        this._consumableProductsInitialized = false;
        this._sharedSimpleProductOptions = [];
        this.stepSpinner = false;
        this.showSpinner = false;
        this.isSaving = false;
        this.accountContacts = [];
        this.isLoadingContacts = false;
        this.contactSearchTerm = '';
        this.contactSearchFocused = false;
        this.showEquipmentStepError = false;
        this.equipmentStepErrorMsg = '';
        this.contactHasError = false;
        this.productFamilyOptions = [];
        this.isLoadingProductFamily = false;
        this.productFamilyHasError = false;
        this.productFamilySearchTerm = '';
        this.productFamilySearchFocused = false;
        this.equipmentEnabled = true;

        this.showSpinner = true;
        try {
            this.equipmentEnabled = await isEquipmentEnabledForCurrentUser();
        } catch (error) {
            // Fail open: don't block opportunity creation if the config check errors out.
            this.equipmentEnabled = true;
            console.error('[OppTypeSelector] Error checking country equipment config:', error);
        } finally {
            this.showSpinner = false;
        }

        if (!this.equipmentEnabled) {
            this.selectedValue = 'Consumable_Product';
            this.currentStep = 2;
            await this.loadFieldSet();
        }
    }

    handleCardClick(event) {
        const newValue = event.currentTarget.dataset.value;
        this.allFields = [];
        this.fieldValues = {};
        this.currentRecordTypeId = null;
        this.selectedValue = newValue;
        this.showValidationError = false;
    }

    handleCardKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            const newValue = event.currentTarget.dataset.value;
            this.allFields = [];
            this.fieldValues = {};
            this.currentRecordTypeId = null;
            this.selectedValue = newValue;
            this.showValidationError = false;
        }
    }

    handleFieldChange(event) {
        const fieldName = event.target.dataset.field;
        const value = event.detail.value;
        this.fieldValues[fieldName] = value;

        if (fieldName === FAMILY_FIELD) {
            this.consumableFamily = Array.isArray(value) ? value[0] : value;
        }

        if (fieldName === 'Account__c' || fieldName === 'AccountId') {
            const accountId = Array.isArray(value) ? value[0] : value;
            if (accountId && accountId !== this.selectedAccountId) {
                this.selectedAccountId = accountId;
                this.selectedContactId = null;
                this.accountContacts = [];
                this.contactHasError = false;
                this.loadAccountContacts(accountId);
            } else if (!accountId) {
                this.selectedAccountId = null;
                this.selectedContactId = null;
                this.accountContacts = [];
                this.contactHasError = false;
            }
        }
    }

    async loadAccountContacts(accountId) {
        if (!accountId) return;
        this.isLoadingContacts = true;
        try {
            const contacts = await getRelatedContactIds({ accountId });
            this.accountContacts = (contacts || []).map(c => ({
                Id: c.Id,
                Name: c.Name,
                isSelected: false
            }));
            if (this.accountContacts.length === 0) { this.toast('No Contact Found', 'No contacts are associated with this account. Please add a contact first.', 'info'); } //Owais
        } catch (error) {
            this.toast('Error', 'Could not load contacts: ' + this.errMsg(error), 'error');
            this.accountContacts = [];
        } finally {
            this.isLoadingContacts = false;
        }
    }

    handleContactSearchInput(event) {
        this.contactSearchTerm = event.target.value;
        this.contactSearchFocused = true;
        if (!event.target.value) {
            this.selectedContactId = null;
            this.fieldValues['Contact__c'] = null;
        }
    }

    handleContactSearchFocus() {
        this.contactSearchFocused = true;
    }

    handleContactOptionClick(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        this.selectedContactId = id;
        this.fieldValues['Contact__c'] = id;
        this.contactSearchTerm = name;
        this.contactSearchFocused = false;
        this.contactHasError = false;
    }

    handleContactClear() {
        this.selectedContactId = null;
        this.fieldValues['Contact__c'] = null;
        this.contactSearchTerm = '';
        this.contactSearchFocused = false;
    }

    handleContactBlur() {
        setTimeout(() => { this.contactSearchFocused = false; }, 200);
    }

    async _transitionStep(fn) {
        this.stepSpinner = true;
        try {
            await new Promise(resolve => setTimeout(resolve, 1000));
            await fn();
        } finally {
            this.stepSpinner = false;
        }
    }

    async handleNext() {
        if (this.isStep1) {
            if (!this.selectedValue) {
                this.validationMessage = 'Please select an opportunity type before continuing.';
                this.showValidationError = true;
                return;
            }
            await this._transitionStep(async () => {
                this.currentStep = 2;
                await this.loadFieldSet();
            });
            return;
        }

        if (this.isEquipmentStep1) {
            if (this.isNextDisabled) return;

            const missingCompany = this.equipmentRows.some(row =>
                !row.isOther && !row.selectedCompany
            );
            if (missingCompany) {
                this.showEquipmentStepError = true;
                this.equipmentStepErrorMsg = 'Please select an Equipment Company for all equipment rows.';
                return;
            }

            this.showEquipmentStepError = false;
            await this._transitionStep(async () => {
                this.currentStep = 4;
            });
        }
    }

    async handleBack() {
        if (this.isConsumableStep2 || this.isSoloOrBundleStep2) {
            if (this.createdRecordId) return;
            if (!this.canGoBackToTypeSelection) return; // no Step 1 to return to
            await this._transitionStep(async () => { this.currentStep = 1; });
            return;
        }
        if (this.isConsumableProductsStep) {
            await this._transitionStep(async () => { this.currentStep = 2; });
            return;
        }
        if (this.isEquipmentStep1) {
            if (this.createdRecordId) return;
            await this._transitionStep(async () => { this.currentStep = 2; });
            return;
        }
        if (this.isEquipmentStep2) {
            await this._transitionStep(async () => { this.currentStep = 3; });
            return;
        }
        if (this.isAddProductsStep) {
            await this._transitionStep(async () => { this.currentStep = 4; });
        }
    }

    async loadFieldSet() {
        if (!this.selectedValue) return;

        this.showSpinner = true;
        this.allFields = [];
        this.fieldValues = {};
        this.hasSaveError = false;

        try {
            const [fields, recordTypeId] = await Promise.all([
                getFieldSetFields({ fieldSetName: FIELD_SET_MAP[this.selectedValue] }),
                getRecordTypeIdByName({
                    objectApiName: 'Opportunity__c',
                    recordTypeName: RECORD_TYPE_MAP[this.selectedValue]
                })
            ]);

            this.currentRecordTypeId = recordTypeId;
            this.allFields = (fields || [])
                .filter(field => !SKIP_FIELDS.has(field.apiName))
                .map(field => ({
                    ...field,
                    defaultValue: field.apiName === 'Equipment_Opportunity_Type__c'
                        ? EQUIP_OPP_TYPE_MAP[this.selectedValue]
                        : undefined,
                    isReadOnly: field.apiName === 'Equipment_Opportunity_Type__c'
                }));
            if (this.selectedValue === 'Consumable_Product') {
                this.loadProductFamilyOptions();
            }
        } catch (error) {
            this.toast('Error', 'Could not load fields: ' + this.errMsg(error), 'error');
        } finally {
            this.showSpinner = false;
        }
    }
    async loadProductFamilyOptions() {
        this.isLoadingProductFamily = true;
        this.productFamilyHasError = false;
        try {
            const families = await getProductFamily({ opportunityId: null });
            this.productFamilyOptions = (families || []).map(f => ({
                value: f,
                label: f,
                isSelected: f === this.consumableFamily
            }));
        } catch (error) {
            this.productFamilyOptions = [];
            this.toast('Error', 'Could not load product families: ' + this.errMsg(error), 'error');
        } finally {
            this.isLoadingProductFamily = false;
        }
    }

    // handleProductFamilySelect(event) {
    //     const value = event.target.value;
    //     this.consumableFamily          = value;
    //     this.fieldValues[FAMILY_FIELD] = value;
    //     this.productFamilyOptions      = this.productFamilyOptions.map(opt => ({
    //         ...opt, isSelected: opt.value === value
    //     }));
    //     this.productFamilyHasError = false;
    // }
    handleProductFamilySearchInput(event) {
        this.productFamilySearchTerm = event.target.value;
        this.productFamilySearchFocused = true;
        if (!event.target.value) {
            this.consumableFamily = '';
            this.fieldValues[FAMILY_FIELD] = null;
        }
    }

    handleProductFamilySearchFocus() {
        this.productFamilySearchFocused = true;
    }

    handleProductFamilyOptionClick(event) {
        const value = event.currentTarget.dataset.value;
        const label = event.currentTarget.dataset.label;
        this.consumableFamily = value;
        this.fieldValues[FAMILY_FIELD] = value;
        this.productFamilySearchTerm = label;
        this.productFamilySearchFocused = false;
        this.productFamilyHasError = false;
    }

    handleProductFamilyBlur() {
        setTimeout(() => { this.productFamilySearchFocused = false; }, 200);
    }
    handleSave() {
        if (this.isWorking) return;
        this.hasSaveError = false;

        let allValid = true;
        const inputFields = this.template.querySelectorAll('lightning-input-field');
        inputFields.forEach(f => {
            if (typeof f.reportValidity === 'function') {
                const ok = f.reportValidity();
                if (ok === false) allValid = false;
            }
        });

        const requiresContact = this.isConsumable ||
            this.selectedValue === 'Solo' ||
            this.selectedValue === 'Bundle';

        if (requiresContact && !this.selectedContactId) {
            allValid = false;
            this.contactHasError = true;
        } else {
            this.contactHasError = false;
        }
        if (this.isConsumable && !this.consumableFamily) {
            allValid = false;
            this.productFamilyHasError = true;
        } else {
            this.productFamilyHasError = false;
        }
        if (!allValid) {
            return;
        }

        const submit = this.template.querySelector('[data-id="hiddenSubmit"]');
        if (submit) submit.click();
    }

    // handleFormSubmit(event) {
    //     event.preventDefault();
    //     this.isSaving = true;
    //     const fields        = event.detail.fields;
    //     const equipmentType = EQUIP_OPP_TYPE_MAP[this.selectedValue];
    //     if (equipmentType) fields.Equipment_Opportunity_Type__c = equipmentType;
    //     if (this.selectedContactId) fields.Contact__c = this.selectedContactId;
    //     if (fields[FAMILY_FIELD]) this.consumableFamily = fields[FAMILY_FIELD];
    //     this.template.querySelector('lightning-record-edit-form').submit(fields);
    // }
    handleFormSubmit(event) {
        event.preventDefault();
         const requiresContact = this.isConsumable ||
        this.selectedValue === 'Solo' ||
        this.selectedValue === 'Bundle';

    if (requiresContact && !this.selectedContactId) {
        this.contactHasError = true;
        return; // block submission
    }
    if (this.isConsumable && !this.consumableFamily) {
        this.productFamilyHasError = true;
        return; // block submission
    }

        this.isSaving = true;
        const fields = event.detail.fields;
        const equipmentType = EQUIP_OPP_TYPE_MAP[this.selectedValue];
        if (equipmentType) fields.Equipment_Opportunity_Type__c = equipmentType;
        if (this.selectedContactId) fields.Contact__c = this.selectedContactId;
        if (this.isConsumable && this.consumableFamily) {
            fields[FAMILY_FIELD] = this.consumableFamily;
        }
        if (fields[FAMILY_FIELD]) this.consumableFamily = fields[FAMILY_FIELD];
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }
    async handleFormSuccess(event) {
        this.isSaving = false;
        const recordId = event.detail.id;

        if (this.createdRecordId) {
            await this._transitionStep(async () => { this.currentStep = 3; });
            return;
        }

        this.createdRecordId = recordId;

        if (this.selectedValue === 'Consumable_Product') {
            await this._transitionStep(async () => {
                try {
                    await this.initConsumableProductsStep();
                    this.toast('Success', 'Opportunity created. Now add products.', 'success');
                    this.currentStep = 3;
                } catch (error) {
                    this.toast('Error', this.errMsg(error), 'error');
                }
            });
            return;
        }

        await this._transitionStep(async () => {
            try {
                await this.loadEquipmentProductOptions();
                this.equipmentRows = [];
                equipRowCounter = 1;
                this.toast('Success', 'Opportunity created. Continue with Equipment Products.', 'success');
                this.currentStep = 3;
            } catch (error) {
                this.toast('Error', this.errMsg(error), 'error');
            }
        });
    }

    handleFormError(event) {
        this.isSaving = false;
        this.hasSaveError = true;
        this.saveErrorMessage = event.detail?.detail || event.detail?.message || 'Save failed.';
    }

    async loadDealPeriodOptions() {
        try {
            const userInfo = await getCurrentUserVertical();
            userCurrencyCode = userInfo?.DefaultCurrencyIsoCode || '';
            this.userCurrencyCode = userCurrencyCode; // ← expose to template
        } catch (currencyError) {
            console.error('[OppTypeSelector] Error loading currency:', currencyError);
        }
        try {
            const data = await getDealPeriodOptions();
            this.dealPeriodOptions = (data || []).map(value => ({
                label: value,
                value,
                isSelected: this.totalDealPeriod === value
            }));
        } catch (error) {
            this.toast('Error', this.errMsg(error), 'error');
        }
    }

    async loadEquipmentProductOptions() {
        const oppType = EQUIP_OPP_TYPE_MAP[this.selectedValue];
        const data = await getEquipmentProducts({ opportunityType: oppType });
        const products = (data || []).map(p => ({
            value: p.Id,
            label: p.Name,
            isSelected: false
        }));
        products.push({ value: OTHER_VALUE, label: 'Others', isSelected: false });
        this._equipmentProductOptions = products;
    }

    handleAddEquipmentRow() {
        const newRow = buildRow(this._equipmentProductOptions, false);
        this.equipmentRows = _reindexRows([...this.equipmentRows, newRow]);
    }

    handleAddOthersRow() {
        const newRow = buildRow(this._equipmentProductOptions, true, OTHER_VALUE);
        this.equipmentRows = _reindexRows([...this.equipmentRows, newRow]);
    }

    handleDeleteEquipmentRow(event) {
        const id = Number(event.currentTarget.dataset.id);
        this.equipmentRows = _reindexRows(this.equipmentRows.filter(r => r.id !== id));
    }

    async handleEquipmentProductChange(event) {
        const id = Number(event.target.dataset.id);
        const value = event.target.value;
        const label = value
            ? (this._equipmentProductOptions.find(o => o.value === value)?.label || '')
            : '';
        const isOther = value === OTHER_VALUE;

        this.equipmentRows = _reindexRows(this.equipmentRows.map(row => {
            if (row.id !== id) return row;
            const updatedOpts = row.productOptions.map(o => ({
                ...o, isSelected: o.value === value
            }));
            return {
                ...row,
                selectedProductId: value,
                selectedProductName: label,
                isOther,
                selectedCompany: '',
                otherEquipmentName: '',
                otherCompanyName: '',
                companyOptions: [],
                productOptions: updatedOpts,
                normalProductOptions: updatedOpts.filter(o => o.value !== OTHER_VALUE),
                otherProductOptions: [{ value: OTHER_VALUE, label: 'Others', isSelected: true }],
                isLoadingCompany: !isOther && !!value
            };
        }));

        if (value && !isOther) {
            try {
                const companies = await getEquipmentCompanies({ equipmentProductId: value });
                const compOpts = (companies || []).map(c => ({ value: c, label: c, isSelected: false }));
                this.equipmentRows = this.equipmentRows.map(row =>
                    row.id === id
                        ? { ...row, companyOptions: compOpts, isLoadingCompany: false }
                        : row
                );
            } catch (error) {
                this.toast('Error', this.errMsg(error), 'error');
                this.equipmentRows = this.equipmentRows.map(row =>
                    row.id === id ? { ...row, isLoadingCompany: false } : row
                );
            }
        }
    }

    handleEquipmentCompanyChange(event) {
        const id = Number(event.target.dataset.id);
        const value = event.target.value;
        this.equipmentRows = this.equipmentRows.map(row => {
            if (row.id !== id) return row;
            return {
                ...row,
                selectedCompany: value,
                companyOptions: row.companyOptions.map(o => ({
                    ...o, isSelected: o.value === value
                }))
            };
        });
    }

    handleOtherEquipmentNameChange(event) {
        const id = Number(event.target.dataset.id);
        const value = event.target.value;
        this.equipmentRows = this.equipmentRows.map(row =>
            row.id === id ? { ...row, otherEquipmentName: value } : row
        );
    }

    handleOtherCompanyNameChange(event) {
        const id = Number(event.target.dataset.id);
        const value = event.target.value;
        this.equipmentRows = this.equipmentRows.map(row =>
            row.id === id ? { ...row, otherCompanyName: value } : row
        );
    }

    incrementQty(event) {
        const id = event.currentTarget.dataset.id;
        this.equipmentRows = this.equipmentRows.map(row =>
            String(row.id) === id ? { ...row, quantity: Number(row.quantity) + 1 } : row
        );
    }

    decrementQty(event) {
        const id = event.currentTarget.dataset.id;
        this.equipmentRows = this.equipmentRows.map(row =>
            (String(row.id) === id && row.quantity > 1)
                ? { ...row, quantity: Number(row.quantity) - 1 }
                : row
        );
    }

    handleEquipmentValueChange(event) {
        const id = event.currentTarget.dataset.id;
        const value = event.target.value;
        this.equipmentRows = this.equipmentRows.map(row =>
            String(row.id) === id ? { ...row, equipmentValue: value } : row
        );
    }

    handleDownPaymentChange(event) {
        this.downPayment = event.target.value;
    }

    handleDealPeriodChange(event) {
        this.totalDealPeriod = event.target.value;
        this.dealPeriodOptions = this.dealPeriodOptions.map(opt => ({
            ...opt, isSelected: opt.value === this.totalDealPeriod
        }));
        this.productRows = this.productRows.map(row => this.recalculateProductRow({ ...row }));
    }

    async handleSaveEquipment() {
        if (this.isSaveDisabled) return;

        if (this.isBundle && !this.totalDealPeriod) {
            this.toast('Error', 'Please select a Total Deal Period before continuing.', 'error');
            return;
        }

        const missingValue = this.selectedEquipments.some(eq => {
            const v = Number(eq.equipmentValue);
            return Number.isNaN(v) || v <= 0;
        });

        if (missingValue) {
            this.toast('Error', 'Please enter a Value incl. GST greater than 0 for every equipment line.', 'error');
            return;
        }

        this.isSaving = true;
        try {
            const lines = this.equipmentRows.map(row => {
                const unitValue = Number(row.equipmentValue) || 0;
                const qty = Number(row.quantity) || 1;
                return {
                    equipmentProductId: row.isOther ? null : (row.selectedProductId === 'Others' ? null : row.selectedProductId),
                    equipmentCompany: row.isOther ? row.otherCompanyName : row.selectedCompany,
                    equipmentName: row.isOther ? row.otherEquipmentName : row.selectedProductName,
                    quantity: qty,
                    equipmentValue: unitValue,
                    equipmentTotalValue: unitValue * qty
                };
            });

            if (this.isBundle) {
                await saveBundleEquipment({
                    opportunityId: this.createdRecordId,
                    totalFundingValue: this.computedTotalValue,
                    downPayment: Number(this.downPayment) || 0,
                    totalDealPeriod: this.totalDealPeriod || null,
                    startDate: this.startDate,
                    endDate: this.endDate,
                    equipmentLines: lines
                });
                await this.initProductsStep();
                this.currentStep = 5;
            } else {
                await saveSoloEquipment({
                    opportunityId: this.createdRecordId,
                    totalSoloValue: this.computedTotalValue,
                    totalDealPeriod: this.totalDealPeriod || null,
                    startDate: this.startDate,
                    endDate: this.endDate,
                    equipmentLines: lines
                });
                this.toast('Success', 'Equipment Opportunity Saved.', 'success');
                this.isModalOpen = false;
                this.navigateToRecord(this.createdRecordId);
            }
        } catch (error) {
            this.toast('Error', this.errMsg(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    async initProductsStep() {
        if (this._productsInitialized) return;
        this._productsInitialized = true;
        try {
            const families = await getProductFamily({ opportunityId: this.createdRecordId });
            this._allFamilies = (families || []).map(f => ({ value: f, label: f }));
        } catch (error) {
            this._productsInitialized = false;
            this._allFamilies = [];
            throw error;
        }
        if (!this.productRows.length) {
            this.productRows = _reseqProductRows([emptyProductRow(this._allFamilies)]);
        }
    }

    async initConsumableProductsStep() {
        if (this._consumableProductsInitialized) return;
        this._consumableProductsInitialized = true;

        if (!this.consumableFamily && this.fieldValues[FAMILY_FIELD]) {
            this.consumableFamily = this.fieldValues[FAMILY_FIELD];
        }

        if (this.consumableFamily) {
            try {
                const products = await getProductsByFamily({ productFamily: this.consumableFamily });
                this._sharedSimpleProductOptions = (products || []).map(p => ({
                    value: p.Id,
                    label: p.brandName || p.Name,
                    asp: Number(p.pfAsp || 0), // Owais
                    msp: Number(p.productMSP || 0),
                    isSelected: false
                }));
            } catch (error) {
                this._sharedSimpleProductOptions = [];
                this.toast('Error', this.errMsg(error), 'error');
            }
        } else {
            this._sharedSimpleProductOptions = [];
        }

        this.simpleProductRows = [
            emptySimpleRow(this.consumableFamily, this._sharedSimpleProductOptions)
        ];
    }

    handleAddSimpleRow() {
        this.simpleProductRows = [
            ...this.simpleProductRows,
            emptySimpleRow(this.consumableFamily, this._sharedSimpleProductOptions)
        ];
    }

    handleDeleteSimpleRow(event) {
        const id = Number(event.currentTarget.dataset.id);
        this.simpleProductRows = this.simpleProductRows.filter(r => r.id !== id);
    }

    handleSimpleProductChange(event) {
        const id = Number(event.target.dataset.id);
        const productId = event.target.value;
        const selOpt = event.target.options[event.target.selectedIndex];
        const asp = selOpt ? (Number(selOpt.dataset.asp) || Number(selOpt.dataset.msp) || 0) : 0;
        const lbl = selOpt ? selOpt.text : '';
        this.simpleProductRows = this.simpleProductRows.map(row => {
            if (row.id !== id) return row;
            return {
                ...row,
                productId,
                productLabel: lbl,
                asp,
                aspFormatted: asp ? fmtINRSimple(asp) : '-',
                productOptions: (row.productOptions || []).map(o => ({
                    ...o, isSelected: o.value === productId
                }))
            };
        });
    }

    handleSimpleQtyChange(event) {
        const id = Number(event.target.dataset.id);
        const qty = Number(event.target.value) || 0;
        this.simpleProductRows = this.simpleProductRows.map(row =>
            row.id === id ? { ...row, qty } : row
        );
    }

    async handleSaveProductsConsumable() {
        if (this.isWorking) return;

        const readyRows = this.simpleProductRows.filter(r =>
            r.productFamily && r.productId && r.qty != null && Number(r.qty) > 0
        );

        if (!readyRows.length) {
            this.toast('Warning', 'Please add at least one complete product row.', 'warning');
            return;
        }

        const inputs = readyRows.map(r => ({
            sfRecordId: r.sfRecordId || null,
            opportunityId: this.createdRecordId,
            productId: r.productId,
            productFamilyLabel: r.productFamily,
            msp: r.asp || 0,
            monthlyQty: Number(r.qty) || 0,
            totalDealPeriod: null,
            totalDealQty: 0,
            monthlyDealValue: 0,
            totalDealValue: 0
        }));

        this.isSaving = true;
        try {
            const savedIds = await saveOpportunityProducts({ inputs });
            let savedIdx = 0;
            this.simpleProductRows = this.simpleProductRows.map(row => {
                if (row.productFamily && row.productId && row.qty != null && Number(row.qty) > 0) {
                    return { ...row, sfRecordId: savedIds[savedIdx++] || row.sfRecordId };
                }
                return row;
            });
            this.toast('Success', `${readyRows.length} product(s) saved successfully.`, 'success');
            this.isModalOpen = false;
            this.navigateToRecord(this.createdRecordId);
        } catch (error) {
            this.toast('Error', this.errMsg(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleAddRow() {
        this.productRows = _reseqProductRows([...this.productRows, emptyProductRow(this._allFamilies)]);
    }

    handleDeleteRow(event) {
        const id = Number(event.currentTarget.dataset.id);
        this.productRows = _reseqProductRows(this.productRows.filter(row => row.id !== id));
    }

    handleFamilySelect(event) {
        const id = Number(event.target.dataset.id);
        const value = event.target.value;
        this.productRows = this.productRows.map(row => {
            if (row.id !== id) return row;
            return {
                ...row,
                productFamily: value,
                productId: '',
                productLabel: '',
                msp: null,
                mspFormatted: '-',
                monthlyQty: '',
                totalDealQty: null,
                totalDealQtyDisplay: '-',
                monthlyDealValue: null,
                monthlyDealValueFormatted: '-',
                totalDealValue: null,
                totalDealValueFormatted: '-',
                productOptions: [],
                isLoadingProducts: !!value,
                familyOptions: row.familyOptions.map(opt => ({
                    ...opt, isSelected: opt.value === value
                }))
            };
        });
        if (value) this.loadProductsForRow(id, value);
    }

    async loadProductsForRow(rowId, family) {
        try {
            const products = await getProductsByFamily({ productFamily: family });
            const options = (products || []).map(product => ({
                value: product.Id,
                label: product.Name,
                msp: product.productMSP || 0,
                isSelected: false
            }));
            this.productRows = this.productRows.map(row =>
                row.id === rowId
                    ? { ...row, productOptions: options, isLoadingProducts: false }
                    : row
            );
        } catch (error) {
            this.toast('Error', this.errMsg(error), 'error');
            this.productRows = this.productRows.map(row =>
                row.id === rowId ? { ...row, isLoadingProducts: false } : row
            );
        }
    }

    handleProductSelect(event) {
        const id = Number(event.target.dataset.id);
        const productId = event.target.value;
        const selectedOption = event.target.options[event.target.selectedIndex];
        const msp = productId ? Number(selectedOption.dataset.msp) || 0 : null;
        const label = productId ? selectedOption.text : '';

        this.productRows = this.productRows.map(row => {
            if (row.id !== id) return row;
            const updatedProductOptions = row.productOptions.map(opt => ({
                ...opt, isSelected: opt.value === productId
            }));
            return this.recalculateProductRow({
                ...row,
                productId,
                productLabel: label,
                msp,
                mspFormatted: msp !== null ? fmtINR(msp) : '-',
                productOptions: updatedProductOptions
            });
        });
    }

    handleProductQtyChange(event) {
        const id = Number(event.target.dataset.id);
        const qty = event.target.value !== '' ? Number(event.target.value) : null;
        this.productRows = this.productRows.map(row =>
            row.id === id ? this.recalculateProductRow({ ...row, monthlyQty: qty }) : row
        );
    }

    recalculateProductRow(row) {
        const hasProduct = !!row.productId;
        const hasQty = row.monthlyQty !== null &&
            row.monthlyQty !== '' &&
            !Number.isNaN(Number(row.monthlyQty));

        if (!hasProduct || !hasQty) {
            return {
                ...row,
                totalDealQty: null,
                totalDealQtyDisplay: '-',
                monthlyDealValue: null,
                monthlyDealValueFormatted: '-',
                totalDealValue: null,
                totalDealValueFormatted: '-'
            };
        }

        const monthlyQty = Number(row.monthlyQty);
        const msp = Number(row.msp) || 0;
        const dealPeriod = parseInt(String(this.totalDealPeriod).replace(/[^0-9]/g, ''), 10) || 0;
        const totalDealQty = monthlyQty * dealPeriod;
        const monthlyDealValue = monthlyQty * msp;
        const totalDealValue = totalDealQty * msp;

        return {
            ...row,
            totalDealQty,
            totalDealQtyDisplay: dealPeriod > 0 ? String(totalDealQty) : '-',
            monthlyDealValue,
            monthlyDealValueFormatted: fmtINR(monthlyDealValue),
            totalDealValue: dealPeriod > 0 ? totalDealValue : null,
            totalDealValueFormatted: dealPeriod > 0 ? fmtINR(totalDealValue) : '-'
        };
    }

    async handleSaveProducts() {
        if (this.isWorking) return;

        if (!this.totalDealPeriod) {
            this.toast('Error', 'Total Deal Period is missing.', 'error');
            return;
        }

        const invalidFamily = this.productRows.some(row => row.productFamily && !row.productId);
        if (invalidFamily) {
            this.toast('Error', 'Please select a Product for every row that has a Family selected.', 'error');
            return;
        }

        const validRows = this.productRows.filter(row =>
            row.productId &&
            row.monthlyQty !== null &&
            row.monthlyQty !== '' &&
            Number(row.monthlyQty) > 0
        );

        if (!validRows.length) {
            this.toast('Error', 'Please add at least one product with Monthly Qty greater than 0.', 'error');
            return;
        }

        const inputs = validRows.map(row => ({
            sfRecordId: row.sfRecordId || null,
            opportunityId: this.createdRecordId,
            productId: row.productId,
            productFamilyLabel: row.productFamily,
            msp: row.msp,
            monthlyQty: Number(row.monthlyQty),
            totalDealPeriod: this.totalDealPeriod,
            totalDealQty: row.totalDealQty,
            monthlyDealValue: row.monthlyDealValue,
            totalDealValue: row.totalDealValue
        }));

        this.isSaving = true;
        try {
            const savedIds = await saveOpportunityProducts({ inputs });
            let savedIdx = 0;
            this.productRows = this.productRows.map(row => {
                if (
                    row.productId &&
                    row.monthlyQty !== null &&
                    row.monthlyQty !== '' &&
                    Number(row.monthlyQty) > 0
                ) {
                    return { ...row, sfRecordId: savedIds[savedIdx++] || row.sfRecordId };
                }
                return row;
            });
            this.toast('Success', `${validRows.length} product(s) saved successfully.`, 'success');
            this.isModalOpen = false;
            this.navigateToRecord(this.createdRecordId);
        } catch (error) {
            this.toast('Error', this.errMsg(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleOverlayClick(event) {
        if (event.target === event.currentTarget) this.handleClose();
    }

    handleClose() {
        this.isModalOpen = false;
        if (this.createdRecordId) {
            this.navigateToRecord(this.createdRecordId);
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: { objectApiName: 'Opportunity__c', actionName: 'list' },
                state: { filterName: 'Recent' }
            });
        }
    }

    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, objectApiName: 'Opportunity__c', actionName: 'view' }
        });
    }

    isoDate(dateValue) {
        const yyyy = dateValue.getFullYear();
        const mm = String(dateValue.getMonth() + 1).padStart(2, '0');
        const dd = String(dateValue.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    errMsg(error) {
        return error?.body?.message || error?.message || (typeof error === 'string' ? error : 'Unexpected error');
    }

    get contactGridStyle() {
        return 'grid-column:2;grid-row:1';
    }


}
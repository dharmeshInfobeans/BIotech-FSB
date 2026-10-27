import { LightningElement, track } from 'lwc';
import getDistributorInfo       from '@salesforce/apex/DistributorRegistrationFormController.getDistributorInfo';
import getAgreementSignedWith   from '@salesforce/apex/DistributorRegistrationFormController.getAgreementSignedWithOptions';
import getVerticalOptions       from '@salesforce/apex/DistributorRegistrationFormController.getVerticalOptions';
import getProductsByVertical    from '@salesforce/apex/DistributorRegistrationFormController.getProductsByVertical';
import getActiveAgreementApex   from '@salesforce/apex/DistributorRegistrationFormController.getActiveAgreement';
import getCompletedRequests     from '@salesforce/apex/DistributorRegistrationFormController.getCompletedRequests';
import submitRequestApex        from '@salesforce/apex/DistributorRegistrationFormController.submitRequest';
import submitAdditionalCertApex from '@salesforce/apex/DistributorRegistrationFormController.submitAdditionalCertRequest';
import { FIELD_LABEL_TRANSLATIONS } from './distributorRegistrationForm_i18n';
import LANG from '@salesforce/i18n/lang';

const TYPE_NEW  = 'New Request';
const TYPE_CERT = 'Request Additional Documents';

const EMPTY_FORM = () => ({
    requestType         : TYPE_NEW,
    agreementSignedWith : null,
    duration            : null,
    vertical            : null,
    remarks             : '',
});

const DOCUMENT_TYPES = [
    { value: 'ISO Certificate',            label: 'ISO Certificate',            icon: 'utility:shield'      },
    { value: 'GMP',                        label: 'GMP',                        icon: 'utility:shield'      },
    { value: 'FSC',                        label: 'FSC',                        icon: 'utility:approval'    },
    { value: 'IFU',                        label: 'IFU',                        icon: 'utility:description' },
    { value: 'Bio Compatibility Study',    label: 'Bio Compatibility Study',    icon: 'utility:chart'       },
    { value: 'Clinical Study',             label: 'Clinical Study',             icon: 'utility:chart'       },
    { value: 'QSD Registration',           label: 'QSD Registration',           icon: 'utility:file'        },
    { value: 'LOA',                        label: 'LOA',                        icon: 'utility:description' },
    { value: 'CE Certificate',             label: 'CE Certificate',             icon: 'utility:approval'    },
    { value: 'Manufacturing License',      label: 'Manufacturing License',      icon: 'utility:file'        },
    { value: 'Artwork',                    label: 'Artwork',                    icon: 'utility:image'       },
    { value: 'DOC',                        label: 'DOC',                        icon: 'utility:description' },
    { value: 'Clinical Evaluation Report', label: 'Clinical Evaluation Report', icon: 'utility:description' },
    { value: 'Toxicity Report',            label: 'Toxicity Report',            icon: 'utility:warning'     },
    { value: 'Product Image',              label: 'Product Image',              icon: 'utility:image'       },
    { value: 'POA',                        label: 'POA',                        icon: 'utility:description' },
];

let _rowCounter = 0;
const newRow = () => ({ rowId: String(++_rowCounter), productId: null });

export default class DistributorRegistrationForm extends LightningElement {

    // ── State ─────────────────────────────────────────────────────────────────
    @track isLoading     = true;
    @track isSaving      = false;
    @track isSuccess     = false;
    @track errorMessage  = '';
    @track submittedName = '';

    @track distributorInfo = {};
    @track formData        = EMPTY_FORM();
    @track productRows     = [newRow()];

    @track agreementSignedWithOptions = [];
    @track verticalOptions            = [];
    @track productOptions             = [];

    @track activeAgreement  = null;
    @track selectedDocTypes = {};
    @track docProductMap    = {};  // { docType: [productId, ...] }

    // Document-product modal
    @track showDocModal       = false;
    @track pendingDocType     = null;
    @track docModalSelections = {};  // { productId: boolean }

    // Additional certificate state
    @track completedRequests       = [];
    @track selectedParentRequest   = null;
    @track alreadyProvidedDocTypes = {};

    _accountId         = null;
    _lastSubmitWasCert = false;

    // ── Static options ────────────────────────────────────────────────────────
    requestTypeOptions = [
        { label: TYPE_NEW,  value: TYPE_NEW  },
        { label: TYPE_CERT, value: TYPE_CERT }
    ];

    durationOptions = Array.from({ length: 36 }, (_, i) => ({
        label : `${i + 1} Month${i > 0 ? 's' : ''}`,
        value : String(i + 1)
    }));

    // ── Computed getters ──────────────────────────────────────────────────────
    get hasLoadError()     { return !this.isLoading && !!this.errorMessage && !this._accountId; }
    get hasNoAccount()     { return !this.isLoading && !this.errorMessage && !this._accountId; }
    get showForm()         { return !this.isLoading && !this.isSuccess && !!this._accountId; }
    get isNewRequest()     { return this.formData.requestType === TYPE_NEW; }
    get isAdditionalCert() { return this.formData.requestType === TYPE_CERT; }
    get accountId()        { return this._accountId; }

    get regionDisplay() { return this.distributorInfo.region || '—'; }

    get productRowsWithIndex() {
        const selectedIds = new Set(this.productRows.map(r => r.productId).filter(Boolean));
        return this.productRows.map((r, i) => ({
            ...r,
            displayIndex     : i + 1,
            availableOptions : this.productOptions.filter(
                o => o.value === r.productId || !selectedIds.has(o.value)
            )
        }));
    }

    get hasProducts() { return this.productOptions.length > 0; }

    get completedRequestOptions() {
        return [
            { label: '-- Select a completed request --', value: '' },
            ...this.completedRequests.map(r => ({ label: r.requestName, value: r.requestId }))
        ];
    }

    get selectedParentRequestId()   { return this.selectedParentRequest?.requestId || ''; }

    get selectedParentProducts() {
        const names = this.selectedParentRequest && this.selectedParentRequest.productNames;
        if (!names || names.length === 0) return [];
        return names.map((name, idx) => ({ key: idx, name }));
    }

    get hasSelectedParentProducts() { return this.selectedParentProducts.length > 0; }

    get remainingDurationLabel() {
        if (!this.selectedParentRequest?.validToDate) return '—';
        const expiry = new Date(this.selectedParentRequest.validToDate);
        const today  = new Date();
        today.setHours(0, 0, 0, 0);
        if (expiry <= today) return 'Expired';
        const months = Math.ceil((expiry - today) / (1000 * 60 * 60 * 24 * 30.44));
        return `${months} month${months !== 1 ? 's' : ''} remaining`;
    }

    get documentTypeCards() {
        return DOCUMENT_TYPES.map(dt => {
            const disabled        = !!this.alreadyProvidedDocTypes[dt.value];
            const selected        = !disabled && !!this.selectedDocTypes[dt.value];
            const assignedPids    = this.docProductMap[dt.value] || [];
            const assignedProducts = assignedPids.map(pid => {
                const opt = this.productOptions.find(o => o.value === pid);
                return { key: pid, label: opt ? opt.label : pid };
            });
            return {
                ...dt,
                isSelected       : selected,
                isDisabled       : disabled,
                ariaChecked      : String(selected),
                assignedProducts,
                hasAssigned      : assignedProducts.length > 0,
                cardClass        : 'doc-type-card'
                    + (disabled ? ' doc-type-card--disabled' : '')
                    + (selected ? ' doc-type-card--selected' : ''),
                iconClass        : selected ? 'doc-card-icon--selected' : '',
            };
        });
    }

    get selectedDocTypeCount() {
        return Object.values(this.selectedDocTypes).filter(Boolean).length;
    }

    get certSelectedCount() {
        return Object.values(this.docProductMap).reduce((sum, pids) => sum + pids.length, 0);
    }

    get _alreadyByProduct() {
        const map = {};
        for (const entry of (this.selectedParentRequest?.alreadyProvidedByProduct || [])) {
            map[entry.productId] = new Set(entry.uploadedDocTypes || []);
        }
        return map;
    }

    get certProductDocRows() {
        if (!this.selectedParentRequest) return [];
        const productIds   = this.selectedParentRequest.productIds   || [];
        const productNames = this.selectedParentRequest.productNames || [];
        const alreadyMap   = this._alreadyByProduct;
        return productIds.map((productId, i) => ({
            productId,
            productName: productNames[i] || productId,
            docCards: DOCUMENT_TYPES.map(dt => {
                const disabled = !!(alreadyMap[productId] && alreadyMap[productId].has(dt.value));
                const selected = !disabled && (this.docProductMap[dt.value] || []).includes(productId);
                return {
                    ...dt,
                    isSelected : selected,
                    isDisabled : disabled,
                    ariaChecked: String(selected),
                    cardClass  : 'doc-type-card'
                        + (disabled ? ' doc-type-card--disabled' : '')
                        + (selected ? ' doc-type-card--selected' : ''),
                };
            })
        }));
    }

    get selectedDocTypesString() {
        return Object.keys(this.selectedDocTypes)
            .filter(k => this.selectedDocTypes[k])
            .join(';');
    }

    // ── Modal computed ────────────────────────────────────────────────────────
    get modalTitle() {
        return this.pendingDocType ? `Select Products for "${this.pendingDocType}"` : '';
    }

    get modalProducts() {
        return this.productRows
            .filter(r => r.productId)
            .map(r => {
                const opt = this.productOptions.find(o => o.value === r.productId);
                return {
                    productId : r.productId,
                    label     : opt ? opt.label : r.productId,
                    checked   : !!this.docModalSelections[r.productId]
                };
            });
    }

    get modalAllSelected() {
        const prods = this.modalProducts;
        return prods.length > 0 && prods.every(p => !!this.docModalSelections[p.productId]);
    }

    get modalConfirmDisabled() {
        return !this.modalProducts.some(p => !!this.docModalSelections[p.productId]);
    }

    get successSubMessage() {
        return this._lastSubmitWasCert
            ? 'Your additional certificate request has been submitted and is now with the Regulatory Team.'
            : 'The Leadership Team has been notified. You will receive updates on your request status.';
    }

    // ── Language ──────────────────────────────────────────────────────────────
    userLang = 'en';
    @track langDropdownOpen = false;

    languageOptions = [
        { code: 'en', label: 'English',   badge: 'EN' },
        { code: 'zh', label: '中文',       badge: 'ZH' },
        { code: 'it', label: 'Italiano',   badge: 'IT' },
        { code: 'es', label: 'Español',    badge: 'ES' },
        { code: 'fr', label: 'Français',   badge: 'FR' },
        { code: 'ar', label: 'العربية',    badge: 'AR' },
        { code: 'pl', label: 'Polski',     badge: 'PL' },
        { code: 'pt', label: 'Português',  badge: 'PT' },
        { code: 'ru', label: 'Русский',    badge: 'RU' },
        { code: 'ur', label: 'اردو',       badge: 'UR' },
        { code: 'id', label: 'Bahasa',     badge: 'ID' },
        { code: 'de', label: 'Deutsch',    badge: 'DE' },
        { code: 'ja', label: '日本語',      badge: 'JA' },
    ];

    get currentLanguageLabel() {
        const opt = this.languageOptions.find(o => o.code === this.userLang);
        return opt ? opt.label : 'English';
    }

    get currentLanguageBadge() {
        const opt = this.languageOptions.find(o => o.code === this.userLang);
        return opt ? opt.badge : 'EN';
    }

    get languageDropdownItems() {
        return this.languageOptions.map(o => ({
            ...o,
            isSelected: o.code === this.userLang,
            itemClass: 'lang-dropdown-item' + (o.code === this.userLang ? ' lang-selected' : '')
        }));
    }

    toggleLangDropdown() {
        this.langDropdownOpen = !this.langDropdownOpen;
    }

    handleLangSelect(event) {
        const li = event.target.closest('[data-code]');
        if (!li) return;
        const code = li.dataset.code;
        if (code && code !== this.userLang) {
            this.userLang = code;
        }
        this.langDropdownOpen = false;
    }

    closeLangDropdown() {
        this.langDropdownOpen = false;
    }

    _getUserLanguage() {
        const htmlLang = document.documentElement.lang;
        if (htmlLang) {
            const hl = htmlLang.substring(0, 2).toLowerCase();
            if (hl && hl !== 'en') return hl;
        }
        if (LANG) {
            const sfLang = LANG.substring(0, 2);
            if (sfLang && sfLang !== 'en') return sfLang;
        }
        const parts = window.location.pathname.split('/');
        const langFull = parts[2];
        if (!langFull) return 'en';
        return langFull.substring(0, 2);
    }

    t(key) {
        if (this.userLang === 'en') return key;
        const entry = FIELD_LABEL_TRANSLATIONS[key];
        if (entry && entry[this.userLang]) return entry[this.userLang];
        return key;
    }

    // ── Translated label getters ─────────────────────────────────────────────
    get labelCustomerName()        { return this.t('Customer Name'); }
    get labelCustomerCode()        { return this.t('Customer Code (GSTIN)'); }
    get labelCountry()             { return this.t('Country'); }
    get labelRegion()              { return this.t('Region'); }
    get labelAddress()             { return this.t('Address'); }
    get labelEmailAddress()        { return this.t('Email Address'); }
    get labelAgreementSignedWith() { return this.t('Agreement Signed With'); }
    get labelDuration()            { return this.t('Duration for MOH (Months)'); }
    get labelRsmName()             { return this.t('RSM Name'); }
    get labelRsmEmail()            { return this.t('RSM Email'); }
    get labelCrmName()             { return this.t('CRM Name'); }
    get labelCrmEmail()            { return this.t('CRM Email'); }
    get labelTypeOfRequest()       { return this.t('Type of Request'); }
    get labelVertical()            { return this.t('Vertical'); }
    get labelCompletedRequest()    { return this.t('Completed Request'); }
    get labelRemainingDuration()   { return this.t('Remaining Duration'); }
    get labelProducts()            { return this.t('Products'); }
    get labelRemarks()             { return this.t('Remarks'); }

    // ── Translated UI strings ───────────────────────────────────────────────
    get labelPageTitle()           { return this.t('Create New Request'); }
    get labelPageSubtitle()        { return this.t('Submit a new master agreement or add products to an existing agreement.'); }
    get labelSectionRequestType()  { return this.t('Request Type'); }
    get labelSectionDistributor()  { return this.t('Distributor Information'); }
    get labelSectionAgreement()    { return this.t('Agreement Details'); }
    get labelSectionSelectCompleted() { return this.t('Select Completed Request'); }
    get labelSectionManufacturing(){ return this.t('Manufacturing'); }
    get labelSectionDocuments()    { return this.t('Required Documents'); }
    get labelSectionRemarks()      { return this.t('Remarks / Comments'); }
    get labelAddBtn()              { return this.t('+ Add'); }
    get labelSubmitRequest()       { return this.t('Submit Request'); }
    get labelDocInstruction()      { return this.t('Select all document types you will be submitting for this registration request. After selecting a document, choose which products it applies to.'); }
    get labelDocInstructionCert()  { return this.t('Select the additional document types you need for each product.'); }
    get labelRemarksInstruction()  { return this.t('Add any additional clarification or notes for the Leadership and Regulatory team.'); }
    get labelRemarksPlaceholder()  { return this.t('Enter any remarks or clarifications (optional)'); }
    get labelColNo()               { return this.t('No.'); }
    get labelColProduct()          { return this.t('Product'); }
    get labelColAction()           { return this.t('Action'); }
    get labelAlreadyProvided()     { return this.t('Already Provided'); }
    get labelSelected()            { return this.t('selected'); }
    get labelSelectVerticalHint()  { return this.t('Select a vertical above to choose products.'); }
    get labelModalSubtitle()       { return this.t('Choose which products require this document.'); }
    get labelSelectAllProducts()   { return this.t('Select All Products'); }
    get labelCancel()              { return this.t('Cancel'); }
    get labelConfirm()             { return this.t('Confirm'); }
    get labelSubmittedSuccess()    { return this.t('Request Submitted Successfully'); }
    get labelSubmitAnother()       { return this.t('Submit Another Request'); }

    get translatedRequestTypeOptions() {
        return [
            { label: this.t('New Request'),  value: TYPE_NEW  },
            { label: this.t('Request Additional Documents'), value: TYPE_CERT }
        ];
    }

    get selectedDocCountLabel() {
        return this.selectedDocTypeCount ? `${this.selectedDocTypeCount} ${this.labelSelected}` : '';
    }

    get certSelectedCountLabel() {
        return this.certSelectedCount ? `${this.certSelectedCount} ${this.labelSelected}` : '';
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    connectedCallback() {
        this.userLang = this._getUserLanguage();
        this._load();
    }

    // ── Data loading ──────────────────────────────────────────────────────────
    async _load() {
        try {
            const [info, signedOpts, vertOpts] = await Promise.all([
                getDistributorInfo(),
                getAgreementSignedWith(),
                getVerticalOptions()
            ]);
            this.distributorInfo            = info;
            this._accountId                 = info.accountId;
            this.agreementSignedWithOptions = signedOpts.map(o => ({ label: o.label, value: o.value }));
            this.verticalOptions            = vertOpts.map(o => ({ label: o.label, value: o.value }));

            if (this._accountId) {
                const ma = await getActiveAgreementApex({ accountId: this._accountId });
                this.activeAgreement = ma;
                if (ma) {
                    this.formData = {
                        ...this.formData,
                        agreementSignedWith : ma.agreementSignedWith || null,
                        duration            : ma.durationMonths ? String(ma.durationMonths) : null,
                        vertical            : ma.vertical || null,
                    };
                    if (ma.vertical) {
                        const opts = await getProductsByVertical({ vertical: ma.vertical, accountId: this._accountId });
                        this.productOptions = opts.map(o => ({ label: o.label, value: o.value }));
                    }
                }
            }
        } catch (e) {
            this.errorMessage = this._extractError(e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Event handlers ────────────────────────────────────────────────────────
    async handleRequestTypeChange(event) {
        const type    = event.detail.value;
        this.formData = { ...this.formData, requestType: type };
        this.errorMessage            = '';
        this.selectedParentRequest   = null;
        this.alreadyProvidedDocTypes = {};
        this.selectedDocTypes        = {};
        this.docProductMap           = {};
        if (type === TYPE_CERT && this._accountId && this.completedRequests.length === 0) {
            try {
                this.completedRequests = await getCompletedRequests({ accountId: this._accountId });
            } catch (e) { /* non-blocking */ }
        }
    }

    handleFieldChange(event) {
        const field   = event.target.dataset.field;
        this.formData = { ...this.formData, [field]: event.detail.value };
        this.errorMessage = '';
    }

    async handleVerticalChange(event) {
        const vertical      = event.detail.value;
        this.formData       = { ...this.formData, vertical };
        this.productRows    = [newRow()];
        this.productOptions = [];
        this.selectedDocTypes = {};
        this.docProductMap    = {};
        if (vertical) {
            try {
                const opts = await getProductsByVertical({ vertical, accountId: this._accountId });
                this.productOptions = opts.map(o => ({ label: o.label, value: o.value }));
            } catch (e) { /* non-blocking */ }
        }
    }

    handleParentRequestChange(event) {
        const requestId            = event.detail.value;
        this.selectedParentRequest = this.completedRequests.find(r => r.requestId === requestId) || null;
        this.selectedDocTypes      = {};
        if (this.selectedParentRequest?.documentTypes) {
            const provided = {};
            this.selectedParentRequest.documentTypes.split(';').forEach(t => {
                if (t.trim()) provided[t.trim()] = true;
            });
            this.alreadyProvidedDocTypes = provided;
        } else {
            this.alreadyProvidedDocTypes = {};
        }
    }

    // ── Document type selection ───────────────────────────────────────────────
    handleDocTypeToggle(event) {
        const value = event.currentTarget.dataset.value;
        if (this.alreadyProvidedDocTypes[value]) return;

        if (this.isAdditionalCert) {
            // Cert flow: flat toggle, no per-product mapping needed
            this.selectedDocTypes = {
                ...this.selectedDocTypes,
                [value]: !this.selectedDocTypes[value]
            };
            return;
        }

        if (this.selectedDocTypes[value]) {
            // Deselect: clear mapping
            const newMap = { ...this.docProductMap };
            delete newMap[value];
            this.docProductMap    = newMap;
            this.selectedDocTypes = { ...this.selectedDocTypes, [value]: false };
        } else {
            // Select: open product modal
            const selectedProductIds = this.productRows.filter(r => r.productId).map(r => r.productId);
            if (selectedProductIds.length === 0) {
                this.errorMessage = 'Please select at least one product before choosing document types.';
                return;
            }
            this.errorMessage   = '';
            this.pendingDocType = value;
            // Pre-select all if only one product
            const preSelect = {};
            if (selectedProductIds.length === 1) {
                preSelect[selectedProductIds[0]] = true;
            }
            this.docModalSelections = preSelect;
            this.showDocModal       = true;
        }
    }

    handleDocTypeKeyPress(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleDocTypeToggle(event);
        }
    }

    handleCertDocTypeToggle(event) {
        const docType   = event.currentTarget.dataset.value;
        const productId = event.currentTarget.dataset.productid;
        const alreadyMap = this._alreadyByProduct;
        if (alreadyMap[productId] && alreadyMap[productId].has(docType)) return;

        const currentPids = [...(this.docProductMap[docType] || [])];
        const idx         = currentPids.indexOf(productId);
        const newPids     = idx >= 0
            ? currentPids.filter(pid => pid !== productId)
            : [...currentPids, productId];

        const newMap = { ...this.docProductMap };
        if (newPids.length === 0) {
            delete newMap[docType];
        } else {
            newMap[docType] = newPids;
        }
        this.docProductMap = newMap;
    }

    // ── Product-document modal ────────────────────────────────────────────────
    handleModalProductToggle(event) {
        const pid     = event.target.dataset.productid;
        const checked = event.detail.checked;
        this.docModalSelections = { ...this.docModalSelections, [pid]: checked };
    }

    handleModalSelectAll(event) {
        const checked    = event.detail.checked;
        const selections = {};
        this.modalProducts.forEach(p => { selections[p.productId] = checked; });
        this.docModalSelections = selections;
    }

    handleModalConfirm() {
        const selectedPids = this.modalProducts
            .filter(p => this.docModalSelections[p.productId])
            .map(p => p.productId);
        if (selectedPids.length === 0) return;
        this.docProductMap    = { ...this.docProductMap, [this.pendingDocType]: selectedPids };
        this.selectedDocTypes = { ...this.selectedDocTypes, [this.pendingDocType]: true };
        this._closeModal();
    }

    handleModalCancel() {
        this._closeModal();
    }

    _closeModal() {
        this.showDocModal       = false;
        this.pendingDocType     = null;
        this.docModalSelections = {};
    }

    // ── Product rows ──────────────────────────────────────────────────────────
    handleProductChange(event) {
        const rowId  = event.target.dataset.rowid;
        const oldPid = this.productRows.find(r => r.rowId === rowId)?.productId;
        this.productRows = this.productRows.map(r =>
            r.rowId === rowId ? { ...r, productId: event.detail.value } : r
        );
        if (oldPid) this._cleanDocMapForProduct(oldPid);
    }

    handleAddProductRow() {
        this.productRows = [...this.productRows, newRow()];
    }

    handleRemoveProductRow(event) {
        const rowId = event.currentTarget.dataset.rowid;
        if (this.productRows.length > 1) {
            const row = this.productRows.find(r => r.rowId === rowId);
            if (row?.productId) this._cleanDocMapForProduct(row.productId);
            this.productRows = this.productRows.filter(r => r.rowId !== rowId);
        }
    }

    _cleanDocMapForProduct(removedPid) {
        const newMap      = {};
        const newSelected = { ...this.selectedDocTypes };
        Object.keys(this.docProductMap).forEach(docType => {
            const remaining = this.docProductMap[docType].filter(pid => pid !== removedPid);
            if (remaining.length > 0) {
                newMap[docType] = remaining;
            } else {
                newSelected[docType] = false;
            }
        });
        this.docProductMap    = newMap;
        this.selectedDocTypes = newSelected;
    }

    // ── Submit ────────────────────────────────────────────────────────────────
    async handleSubmit() {
        if (!this._validate()) return;
        this.errorMessage = '';
        this.isSaving     = true;
        try {
            let result;
            if (this.isAdditionalCert) {
                const certMappings = Object.keys(this.docProductMap).map(docType => ({
                    docType,
                    productIds: this.docProductMap[docType]
                }));
                const certDocTypes = Object.keys(this.docProductMap).join(';');
                result = await submitAdditionalCertApex({
                    parentRequestId   : this.selectedParentRequest.requestId,
                    documentTypes     : certDocTypes,
                    remarks           : this.formData.remarks || '',
                    docProductMappings: JSON.stringify(certMappings)
                });
                this._lastSubmitWasCert = true;
            } else {
                const productIds   = this.productRows.map(r => r.productId).filter(id => !!id);
                const docMappings  = Object.keys(this.docProductMap).map(docType => ({
                    docType,
                    productIds: this.docProductMap[docType]
                }));
                result = await submitRequestApex({
                    accountId           : this._accountId,
                    formType            : this.formData.requestType,
                    country             : this.distributorInfo.country || '',
                    vertical            : this.formData.vertical || '',
                    agreementSignedWith : this.isNewRequest ? (this.formData.agreementSignedWith || '') : '',
                    durationMonths      : this.isNewRequest && this.formData.duration
                                            ? parseInt(this.formData.duration, 10) : 0,
                    validFromDate       : null,
                    validToDate         : null,
                    productIds,
                    documentTypes       : this.selectedDocTypesString,
                    remarks             : this.formData.remarks || '',
                    docProductMappings  : JSON.stringify(docMappings)
                });
                this._lastSubmitWasCert = false;
            }
            this.submittedName = result.recordName;
            this.isSuccess     = true;
        } catch (e) {
            this.errorMessage = this._extractError(e);
        } finally {
            this.isSaving = false;
        }
    }

    handleNewRequest() {
        this.isSuccess               = false;
        this.submittedName           = '';
        this.errorMessage            = '';
        this.formData                = EMPTY_FORM();
        this.productRows             = [newRow()];
        this.productOptions          = [];
        this.selectedDocTypes        = {};
        this.docProductMap           = {};
        this.selectedParentRequest   = null;
        this.alreadyProvidedDocTypes = {};
        this._lastSubmitWasCert      = false;

        const ma = this.activeAgreement;
        if (ma) {
            this.formData = {
                ...this.formData,
                agreementSignedWith : ma.agreementSignedWith || null,
                duration            : ma.durationMonths ? String(ma.durationMonths) : null,
                vertical            : ma.vertical || null,
            };
            if (ma.vertical) {
                getProductsByVertical({ vertical: ma.vertical, accountId: this._accountId })
                    .then(opts => { this.productOptions = opts.map(o => ({ label: o.label, value: o.value })); })
                    .catch(() => {});
            }
        }
    }

    // ── Validation ────────────────────────────────────────────────────────────
    _validate() {
        if (this.isAdditionalCert) {
            if (!this.selectedParentRequest) {
                this.errorMessage = 'Please select a completed request.';
                return false;
            }
            if (Object.keys(this.docProductMap).length === 0) {
                this.errorMessage = 'Please select at least one document type for at least one product.';
                return false;
            }
            return true;
        }
        if (!this.formData.agreementSignedWith) {
            this.errorMessage = 'Please select Agreement Signed With.';
            return false;
        }
        if (!this.formData.duration) {
            this.errorMessage = 'Please select Duration for MOH (Months).';
            return false;
        }
        if (!this.formData.vertical) {
            this.errorMessage = 'Please select a Vertical.';
            return false;
        }
        if (!this.productRows.some(r => r.productId)) {
            this.errorMessage = 'Please select at least one product.';
            return false;
        }
        if (!this.selectedDocTypesString) {
            this.errorMessage = 'Please select at least one document type.';
            return false;
        }
        return true;
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    _extractError(e) {
        if (e && e.body && e.body.message) return e.body.message;
        if (e && e.message)               return e.message;
        return 'An unexpected error occurred. Please try again.';
    }
}
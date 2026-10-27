import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import getOppProductsManagerData from '@salesforce/apex/OppProductsManagerController.getOppProductsManagerData';
import saveOppProducts from '@salesforce/apex/OppProductsManagerController.saveOppProducts';
import saveEquipmentGroups from '@salesforce/apex/OppProductsManagerController.saveEquipmentGroups';
import saveDealPeriod from '@salesforce/apex/OppProductsManagerController.saveDealPeriod';
import { CurrentPageReference } from 'lightning/navigation';
import getProductFamily from '@salesforce/apex/OppTypeSelectorController.getProductFamily';
import getProductsByFamily from '@salesforce/apex/OppTypeSelectorController.getProductsByFamily';
import getEquipmentProducts from '@salesforce/apex/OppTypeSelectorController.getEquipmentProducts';
import getEquipmentCompanies from '@salesforce/apex/OppTypeSelectorController.getEquipmentCompanies';
import getCurrentUserVertical from '@salesforce/apex/OppTypeSelectorController.getCurrentUserVertical';

import getOpportunityRecordTypeName from '@salesforce/apex/OpportunityAddProductController.getOpportunityRecordTypeName';


import getCustomLabels from '@salesforce/apex/OppProductsManagerController.getCustomLabels';

// ─── Constants ────────────────────────────────────────────────────────────────

const isOtherLabel = (label) => {
    if (!label) return false;
    const l = String(label).trim().toLowerCase();
    return l === 'other' || l === 'others';
};

let userCurrencyCode = '';
// ─── Formatting ───────────────────────────────────────────────────────────────

const fmtINR = (value) => {
    if (value === null || value === undefined || value === '') return '—';
    const n = Number(value);
    if (Number.isNaN(n)) return '—';
    const formattedNum = n.toLocaleString('en-IN', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
    });
    return userCurrencyCode ? userCurrencyCode + ' ' + formattedNum : formattedNum
};

const fmtINRSimple = (value) => {
    if (value === null || value === undefined || value === '') return '—';
    const n = Number(value);
    if (Number.isNaN(n)) return '—';
    return n.toLocaleString('en-IN');
};

const calcDealFactor = (totalDealValue, equipmentNetValue) => {
    const tdv = Number(totalDealValue) || 0;
    const env = Number(equipmentNetValue) || 0;
    if (env === 0 || tdv === 0) return null;
    return tdv / env;
};

const fmtFactor = (factor) => {
    if (factor === null || factor === undefined) return '—';
    return Number(factor).toFixed(2) + 'x';
};

const picklistToNumber = (val) => {
    if (!val) return 0;
    const m = String(val).match(/\d+/);
    return m ? Number(m[0]) : 0;
};

const getSObjectFieldValue = (obj, ...candidates) => {
    if (!obj) return null;
    for (const key of candidates) {
        if (obj[key] !== undefined && obj[key] !== null) return obj[key];
        const lower = key.charAt(0).toLowerCase() + key.slice(1);
        if (obj[lower] !== undefined && obj[lower] !== null) return obj[lower];
        const upper = key.charAt(0).toUpperCase() + key.slice(1);
        if (obj[upper] !== undefined && obj[upper] !== null) return obj[upper];
    }
    return null;
};

// ─── Option builders ──────────────────────────────────────────────────────────

const buildFamilyOptions = (allFamilies, currentFamily) =>
    (allFamilies || []).map((f) => ({
        value: f.value,
        label: String(f.label || f.value || '').trim(),
        selected: f.value === currentFamily
    }));

const buildProductOptions = (rawProducts, currentProductId) =>
    (rawProducts || []).map((p) => {
        // Apex ProductOption wrapper uses capital-I "Id", capital-N "Name", "productMSP"
        const val = p.Id || p.id || p.value || p.productId || null;
        const lbl = p.brandName || p.Brand__c || p.brand__c || p.Name || p.name || p.Group_Name__c || p.group_name__c || '';
        const msp = Number(p.productMSP || p.ProductMSP || p.MSP__c || p.msp || 0);
        const asp = Number(p.PF_ASP__c || p.pfAsp || p.ASP__c || p.asp || 0);
        return {
            value: val,
            label: String(lbl).trim(),
            msp,
            asp,
            selected: val === currentProductId
        };
    });

const buildEquipmentOptions = (rawEquipment, currentId) =>
    (rawEquipment || []).map((e) => {
        const val = getSObjectFieldValue(e, 'Id', 'id', 'value');
        const lbl = getSObjectFieldValue(e, 'Name', 'name', 'label');
        return { value: val, label: String(lbl || '').trim(), selected: val === currentId };
    });

const buildNormalEquipmentOptions = (rawEquipment, currentId) =>
    buildEquipmentOptions(rawEquipment, currentId).filter((o) => !isOtherLabel(o.label));

const buildOtherEquipmentOptions = (rawEquipment, currentId) =>
    buildEquipmentOptions(rawEquipment, currentId).filter((o) => isOtherLabel(o.label));

const buildCompanyOptions = (companies, currentCompany) =>
    (companies || [])
        .map((co) => {
            const val = typeof co === 'string' ? co : co.value || co.label || String(co);
            return { value: val, label: val, selected: val === currentCompany };
        })
        .filter((co) => !isOtherLabel(co.label));

const buildDealPeriodOptions = (options, currentValue) =>
    (options || []).map((opt) => ({
        value: opt,
        label: opt,
        selected: opt === currentValue
    }));

const calcEquipTotalValue = (qty, inclGST, exGST) => {
    const q = Number(qty) || 0;
    if (inclGST != null && inclGST !== '') {
        const v = Number(inclGST);
        if (!Number.isNaN(v)) return q * v;
    }
    const v = Number(exGST) || 0;
    return q * v;
};

const isOtherEquipmentProduct = (options, productId) => {
    if (!productId) return false;
    const match = (options || []).find((o) => o.value === productId);
    return match ? isOtherLabel(match.label) : false;
};

// ─── Row builders ─────────────────────────────────────────────────────────────

const makeProductRow = (base) => ({
    ...base,
    rowKey: `prod-${base.id}-${base.productFamily || ''}-${base.productId || ''}`,
    familySelectKey: `fam-${base.id}-${base.productFamily || ''}`,
    productSelectKey: `prd-${base.id}-${base.productId || ''}`
});

const makeEquipRow = (base) => {
    const totalVal =
        base.equipmentTotalValue != null
            ? Number(base.equipmentTotalValue)
            : calcEquipTotalValue(base.quantity, base.equipmentValueInclGST, base.equipmentValue);

    const otherProduct = base.isOtherProduct != null
        ? base.isOtherProduct
        : isOtherEquipmentProduct(
            base.equipmentProductOptionsWithSelection,
            base.equipmentProductId
        );

    return {
        ...base,
        isOtherProduct: otherProduct,
        equipmentTotalValue: totalVal,
        equipmentTotalValueFormatted: fmtINR(totalVal),
        rowKey: `eq-${base.id}`,
        equipSelectKey: `eqs-${base.id}-${base.equipmentProductId || ''}`,
        companySelectKey: `co-${base.id}-${base.equipmentCompany || ''}`
    };
};

// ── makeSimpleRow: familySelectKey removed — family is now read-only text ─────
const makeSimpleRow = (base) => ({
    ...base,
    rowKey: `srow-${base.id}-${base.productFamily || ''}-${base.productId || ''}`,
    productSelectKey: `sprd-${base.id}-${base.productId || ''}`
});

let rowIdCounter = 1000;

const emptyProductRow = (allFamilies) =>
    makeProductRow({
        id: rowIdCounter++,
        sfRecordId: null,
        productFamily: '',
        productId: '',
        productLabel: '',
        msp: null,
        mspFormatted: '—',
        monthlyQty: '',
        totalDealQty: null,
        totalDealQtyDisplay: '—',
        monthlyDealValue: null,
        monthlyDealValueFormatted: '—',
        totalDealValue: null,
        totalDealValueFormatted: '—',
        dealFactor: null,
        dealFactorFormatted: '—',
        productOptions: [],
        familyOptions: buildFamilyOptions(allFamilies, ''),
        isDirty: true,
        isNew: true,
        rowNum: 0
    });

const emptyNormalEquipmentRow = (allEquipOptions) =>
    makeEquipRow({
        id: rowIdCounter++,
        sfRecordId: null,
        equipmentProductId: '',
        equipmentProductName: '',
        equipmentCompany: '',
        companyOptions: [],
        equipmentProductOptionsWithSelection: buildNormalEquipmentOptions(allEquipOptions, ''),
        quantity: 1,
        equipmentValue: '',
        equipmentValueInclGST: null,
        equipmentTotalValue: null,
        equipmentNameOther: '',
        equipmentCompanyOther: '',
        isOtherProduct: false,
        isDirty: true,
        isNew: true,
        rowNum: 0
    });

const emptyOtherEquipmentRow = (otherOption) => {
    const finalOpts = otherOption
        ? [{ value: otherOption.value, label: otherOption.label, selected: true }]
        : [];
    const preselectedId = otherOption ? otherOption.value : '';
    const preselectedName = otherOption ? otherOption.label : '';
    return makeEquipRow({
        id: rowIdCounter++,
        sfRecordId: null,
        equipmentProductId: preselectedId,
        equipmentProductName: preselectedName,
        equipmentCompany: '',
        companyOptions: [],
        equipmentProductOptionsWithSelection: finalOpts,
        quantity: 1,
        equipmentValue: '',
        equipmentValueInclGST: null,
        equipmentTotalValue: null,
        equipmentNameOther: '',
        equipmentCompanyOther: '',
        isOtherProduct: true,
        isDirty: true,
        isNew: true,
        rowNum: 0
    });
};

// ── CHANGED: emptySimpleRow now takes (oppProductFamily, sharedProductOptions)
//    Family is always fixed from the Opportunity — no family picker rendered.
//    productOptions is the shared list pre-loaded once for that family.
const emptySimpleRow = (oppProductFamily, sharedProductOptions) =>
    makeSimpleRow({
        id: rowIdCounter++,
        sfRecordId: null,
        productFamily: oppProductFamily || '',
        productId: '',
        productLabel: '',
        asp: null,
        aspFormatted: '—',
        qty: 0,
        // Give each row its own copy so selected-flag updates stay row-scoped
        productOptions: (sharedProductOptions || []).map((o) => ({ ...o, selected: false })),
        isDirty: true,
        isNew: true,
        rowNum: 0
    });

// ─── Validation helpers ───────────────────────────────────────────────────────

const isProductRowComplete = (r) =>
    !!r.productFamily &&
    !!r.productId &&
    r.msp != null && r.msp !== '' && Number(r.msp) > 0 &&
    r.monthlyQty !== '' && r.monthlyQty != null && Number(r.monthlyQty) > 0;

const isEquipRowComplete = (r) => {
    if (!r.equipmentProductId) return false;
    if (r.isOtherProduct) {
        return (
            r.equipmentNameOther && r.equipmentNameOther.trim() !== '' &&
            r.equipmentCompanyOther && r.equipmentCompanyOther.trim() !== '' &&
            r.equipmentValueInclGST != null &&
            r.equipmentValueInclGST !== '' &&
            Number(r.equipmentValueInclGST) > 0
        );
    }
    return (
        !!r.equipmentCompany &&
        r.equipmentValueInclGST != null &&
        r.equipmentValueInclGST !== '' &&
        Number(r.equipmentValueInclGST) > 0
    );
};

const isSimpleRowComplete = (r) =>
    !!r.productFamily &&
    !!r.productId &&
    r.qty != null && Number(r.qty) > 0;


// ─── Component ────────────────────────────────────────────────────────────────

export default class OppProductsManager extends LightningElement {


    @track labels = {};

    @wire(getCustomLabels)
    getLabels({ data, error }) {
        if (data) { this.labels = data; }
        if (error) console.log('error', error);
    }

    _modalStyled = false;
    _resizeInterval = null;

    renderedCallback() {
        if (this._modalStyled) return;
        this._resizeInterval = setInterval(() => {
            const modal =
                document.querySelector('.uiModal--medium .modal-container') ||
                document.querySelector('.slds-modal__container') ||
                document.querySelector('.modal-container');
            if (modal) {
                this._modalStyled = true;
                clearInterval(this._resizeInterval);
                this._resizeInterval = null;
            }
        }, 50);
        setTimeout(() => {
            if (this._resizeInterval) {
                clearInterval(this._resizeInterval);
                this._resizeInterval = null;
            }
        }, 3000);
    }

    //  _recordId;
    _loadStarted = false;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        this.recordId = currentPageReference?.state?.c__recordId
            ? currentPageReference.state.c__recordId
            : this.recordId;
        // if (!this.recordId && currentPageReference?.state?.recordId) {
        //     this.recordId = currentPageReference.state.recordId;
        // }
    }
    @api
    get recordId() { return this._recordId; }
    set recordId(value) {
        this._recordId = value;
        if (value && !this._loadStarted) {
            this._loadStarted = true;
            Promise.resolve().then(() => this.loadAll());
        }
    }

    connectedCallback() {
        this._loadStarted = false;
        if (this._recordId && !this._loadStarted) {
            this._loadStarted = true;
            Promise.resolve().then(() => this.loadAll());
        }
        this._handleKeyDown = (event) => {
            if (event.key === 'Escape' && !this.isWorking) {
                this.handleClose();
            }
        };
        document.addEventListener('keydown', this._handleKeyDown);
    }

    @track recordTypeName = '';

    @wire(getOpportunityRecordTypeName, { oppId: '$recordId' })
    wiredRecordType({ error, data }) {
        if (data) {
            this.recordTypeName = data;
        } else if (error) {
            console.error('[OPM] Error fetching record type:', JSON.stringify(error));
        }
    }

    get isProductRecordType() {
        return this.recordTypeName === 'Product';
    }

    @track opportunityName = '';
    @track dealPeriod = null;
    @track dealPeriodOptions = [];
    @track productRows = [];
    @track showProductError = false;
    @track productErrorMessage = '';
    @track equipmentRows = [];
    @track showEquipmentError = false;
    @track equipmentErrorMessage = '';
    @track isLoading = false;
    @track isSaving = false;
    @track isEditAllowed = false;
    @track simpleProductRows = [];
    @track oppProductFamily = '';
    @track oppProductDescription = '';
    @track opportunityType = '';
    @track userCurrencyCode = '';

    _productDeleteIds = [];
    _equipmentDeleteIds = [];
    _allFamilies = [];
    _rawEquipmentOptions = [];
    _allEquipmentOptions = [];
    _otherEquipmentOption = null;
    _rawDealPeriodOptions = [];

    // ── NEW: product options pre-loaded once for the Opportunity's family ──────
    // These are shared across all simple rows (each row gets its own copy).
    _sharedSimpleProductOptions = [];

    // ── Computed getters ───────────────────────────────────────────────────────

    get isWorking() { return this.isLoading || this.isSaving; }
    get hasProductRows() { return this.productRows.length > 0; }
    get hasSimpleRows() { return this.simpleProductRows.length > 0; }
    get isViewOnly() { return this.isEditAllowed === true; }

    get normalEquipmentRows() { return this.equipmentRows.filter((r) => !r.isOtherProduct); }
    get otherEquipmentRows() { return this.equipmentRows.filter((r) => r.isOtherProduct).map((r) => ({ ...r })); }
    get hasNormalEquipmentRows() { return this.normalEquipmentRows.length > 0; }
    get hasOtherEquipmentRows() { return this.otherEquipmentRows.length > 0; }
    get normalEquipmentCount() { return this.normalEquipmentRows.length; }
    get otherEquipmentCount() { return this.otherEquipmentRows.length; }
    get hasEquipmentRows() { return this.equipmentRows.length > 0; }

    get numericDealPeriod() { return picklistToNumber(this.dealPeriod); }
    get dealPeriodDisplay() { return this.dealPeriod || '—'; }

    get totalValidProductRows() { return this.productRows.filter((r) => r.productId).length; }

    get productGrandTotal() {
        return this.productRows.reduce((sum, r) => sum + (Number(r.totalDealValue) || 0), 0);
    }
    get productGrandTotalFormatted() {
        if (this.productGrandTotal === 0 && !this.dealPeriod) return '—';
        return fmtINR(this.productGrandTotal);
    }

    get equipmentTotal() {
        return this.equipmentRows.reduce((sum, r) => sum + (Number(r.equipmentTotalValue) || 0), 0);
    }
    get equipmentTotalFormatted() { return fmtINR(this.equipmentTotal); }
    get overallDealFactor() { return calcDealFactor(this.productGrandTotal, this.equipmentTotal); }
    get overallDealFactorFormatted() { return fmtFactor(this.overallDealFactor); }

    get isSaveDisabled() {
        if (this.isWorking) return true;
        if (this.isViewOnly) return true;
        if (!this.dealPeriod) return true;
        if (!this.isSoloEquipmentSale) {
            if (this.productRows.length > 0 && !this.productRows.every(isProductRowComplete)) return true;
        }
        if (this.productRows.length > 0 && !this.productRows.every(isProductRowComplete)) return true;
        if (this.equipmentRows.length > 0 && !this.equipmentRows.every(isEquipRowComplete)) return true;
        return false;
    }

    // ── Simple Product RT getters ──────────────────────────────────────────────

    get simpleTotalProducts() { return this.simpleProductRows.filter((r) => r.productId).length; }
    get simpleFirstFamily() { return this.oppProductFamily || '—'; }
    get simpleFirstDesc() { return this.oppProductDescription || '—'; }

    get simpleReadyCount() { return this.simpleProductRows.filter(isSimpleRowComplete).length; }

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
        if (this.isViewOnly) return true;
        if (this.isSoloEquipmentSale) return false;
        // 0 rows → Save is allowed (user deleted everything intentionally)
        if (this.simpleProductRows.length === 0) return false;
        // Rows exist → every row must have all 3 fields non-null
        return !this.simpleProductRows.every((r) =>
            r.productFamily &&
            r.productId &&
            r.qty != null && r.qty !== '' && Number(r.qty) > 0
        );
    }

    // ─── Data loading ──────────────────────────────────────────────────────────

    async loadAll() {
        if (!this._recordId) return;
        this.isLoading = true;
        try {
            const userInfo = await getCurrentUserVertical();
            userCurrencyCode = userInfo?.DefaultCurrencyIsoCode || '';
            this.userCurrencyCode = userCurrencyCode;

            const data = await getOppProductsManagerData({ opportunityId: this._recordId });
            console.log('[OPM] raw data =>', JSON.stringify(data));

            this.opportunityName = data.opportunityName || '';
            this.oppProductFamily = data.oppProductFamily || '';
            this.oppProductDescription = data.oppProductDescription || '';
            console.log('[OPM] oppProductFamily from line items =>', this.oppProductFamily);
            this.opportunityType = data.opportunityType || '';
            this.isEditAllowed = data.isEditAllowed === true;

            this._rawDealPeriodOptions = data.dealPeriodOptions || [];
            this.dealPeriod = data.dealPeriod || null;
            this._rebuildDealPeriodOptions();

            const families = await getProductFamily({ opportunityId: this._recordId });
            this._allFamilies = (families || []).map((f) => {
                const str = (typeof f === 'string') ? f : (f.value || f.label || String(f));
                return { value: str.trim(), label: str.trim() };
            });

            const rawEquips = await getEquipmentProducts({ opportunityType: data.opportunityType || null });
            this._rawEquipmentOptions = rawEquips || [];
            this._allEquipmentOptions = (rawEquips || []).map((e) => ({
                value: getSObjectFieldValue(e, 'Id', 'id'),
                label: String(getSObjectFieldValue(e, 'Name', 'name') || '').trim()
            }));

            this._otherEquipmentOption = this._allEquipmentOptions.find((o) => isOtherLabel(o.label)) || null;
            if (!this._otherEquipmentOption && data.otherEquipmentProductId) {
                this._otherEquipmentOption = {
                    value: data.otherEquipmentProductId,
                    label: data.otherEquipmentProductName || 'Others'
                };
            }

            // ── CHANGED: pre-load product options for the Opportunity's family ──
            // getProductsByFamily returns Product_Group__c records for that family
            // (same records OpportunityAddProduct shows in its datatable).
            // The `label` in each option = Brand__c (product description).
            if (this.oppProductFamily) {
                try {
                    const rawOpts = await getProductsByFamily({ productFamily: this.oppProductFamily });
                    console.log('[OPM] RAW first product =>', JSON.stringify(rawOpts[0]));
                    this._sharedSimpleProductOptions = buildProductOptions(rawOpts, '');
                    console.log('[OPM] built options =>', JSON.stringify(this._sharedSimpleProductOptions));
                } catch (e) {
                    console.error('[OPM] getProductsByFamily (simple) error =>', e);
                    this._sharedSimpleProductOptions = [];
                }
            } else {
                this._sharedSimpleProductOptions = [];
            }

            const existingProducts = data.opportunityProducts || [];
            const existingEquip = data.equipmentGroups || [];

            this.productRows = await this._mapExistingProductRows(existingProducts);
            // ── CHANGED: now synchronous — family & options come from the cache ──
            this.simpleProductRows = this._mapExistingSimpleRows(existingProducts);
            this.equipmentRows = await this._mapExistingEquipmentRows(existingEquip);

            this._recalcAllProductDealFactors();
            this._refreshRowNums();

        } catch (error) {
            console.error('[OPM] loadAll error =>', JSON.stringify(error));
            this.toast('Error loading records', this.errMsg(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }
    get isSoloEquipmentSale() {
        return this.opportunityType === 'Solo Equipment Sale';
    }
    _rebuildDealPeriodOptions() {
        this.dealPeriodOptions = buildDealPeriodOptions(this._rawDealPeriodOptions, this.dealPeriod);
    }

    // ── CHANGED: _mapExistingSimpleRows is now synchronous ────────────────────
    // - productFamily is always this.oppProductFamily (from the Opportunity)
    // - productOptions come from _sharedSimpleProductOptions (loaded once above)
    // - No per-row Apex call needed
    _mapExistingSimpleRows(records) {
        const family = this.oppProductFamily || '';
        const sharedOpts = this._sharedSimpleProductOptions || [];

        if (!records || records.length === 0) {
            return [makeSimpleRow({
                id: rowIdCounter++,
                sfRecordId: null,
                productFamily: family,
                productId: '',
                productLabel: '',
                asp: null,
                aspFormatted: '—',
                qty: 0,
                productOptions: sharedOpts.map((o) => ({ ...o, selected: false })),
                isDirty: true,
                isNew: true,
                rowNum: 1
            })];
        }

        // ── Check if ANY saved row belongs to a different family ───────────
        const anyMismatch = records.some((rec) => {
            const savedFamily = getSObjectFieldValue(
                rec, 'productFamily', 'ProductFamily', 'product_family__c', 'Product_Family__c'
            ) || '';
            return savedFamily && family && savedFamily !== family;
        });

        if (anyMismatch) {
            // ── Show existing rows as read-only text (old family/product/qty)
            const existingRows = records.map((rec) => {
                const savedProductId = getSObjectFieldValue(
                    rec, 'productId', 'ProductId', 'product_group__c', 'Product_Group__c', 'product2Id', 'Product2Id'
                ) || '';
                const savedFamily = getSObjectFieldValue(
                    rec, 'productFamily', 'ProductFamily', 'product_family__c', 'Product_Family__c'
                ) || '';
                const qty = Number(
                    getSObjectFieldValue(rec, 'monthlyQty', 'MonthlyQty', 'monthly_qty', 'Quantity__c') || 0
                );
                const productLabel = getSObjectFieldValue(rec, 'productLabel', 'productName', 'ProductName') || '';
                const asp = Number(getSObjectFieldValue(rec, 'asp', 'ASP', 'PF_ASP__c', 'msp', 'MSP__c') || 0);
                return makeSimpleRow({
                    id: rowIdCounter++,
                    sfRecordId: getSObjectFieldValue(rec, 'sfRecordId', 'SfRecordId', 'Id', 'id') || null,
                    productFamily: savedFamily,
                    productId: savedProductId,
                    productLabel,
                    asp,
                    aspFormatted: asp ? fmtINRSimple(asp) : '—',
                    qty: qty || 0,
                    productOptions: [],
                    isMismatched: true,
                    isDirty: false,
                    isNew: false,
                    rowNum: 0
                });
            });

            // ── Plus one fresh blank row for the new family ────────────────
            /* const newBlankRow = makeSimpleRow({
                 id:             rowIdCounter++,
                 sfRecordId:     null,
                 productFamily:  family,
                 productId:      '',
                 productLabel:   '',
                 asp:            null,
                 aspFormatted:   '—',
                 qty:            0,
                 productOptions: sharedOpts.map((o) => ({ ...o, selected: false })),
                 isMismatched:   false,
                 isDirty:        true,
                 isNew:          true,
                 rowNum:         0
             });*/

            return [...existingRows];
        }

        // ── Families match — load existing rows normally ───────────────────
        return records.map((rec) => {
            const savedProductId = getSObjectFieldValue(
                rec, 'productId', 'ProductId', 'product_group__c', 'Product_Group__c', 'product2Id', 'Product2Id'
            ) || '';

            const rowOpts = sharedOpts.map((o) => ({ ...o, selected: o.value === savedProductId }));
            const matchOpt = rowOpts.find((o) => o.selected);

            const asp = matchOpt
                ? (matchOpt.asp || 0)
                : Number(getSObjectFieldValue(rec, 'asp', 'ASP', 'PF_ASP__c') || 0);

            const qty = Number(
                getSObjectFieldValue(rec, 'monthlyQty', 'MonthlyQty', 'monthly_qty', 'Quantity__c') || 0
            );

            const productLabel = matchOpt
                ? matchOpt.label
                : (getSObjectFieldValue(rec, 'productLabel', 'productName', 'ProductName') || '');

            return makeSimpleRow({
                id: rowIdCounter++,
                sfRecordId: getSObjectFieldValue(rec, 'sfRecordId', 'SfRecordId', 'Id', 'id') || null,
                productFamily: family,
                productId: savedProductId,
                productLabel,
                asp,
                aspFormatted: asp ? fmtINRSimple(asp) : '—',
                qty: qty || 0,
                productOptions: rowOpts,
                isMismatched: false,
                isDirty: false,
                isNew: false,
                rowNum: 0
            });
        });
    }
    // ── Deal Period change ─────────────────────────────────────────────────────

    handleDealPeriodChange(event) {
        this.dealPeriod = event.target.value || null;
        this._rebuildDealPeriodOptions();
        this.productRows = this.productRows.map((r) =>
            makeProductRow({ ...r, isDirty: true, ...this._calcProductValues(r.monthlyQty, r.msp || 0) })
        );
        this._recalcAllProductDealFactors();
    }

    // ── Full product row mapping (unchanged — non-Product RT) ──────────────────

    async _mapExistingProductRows(records) {
        if (!records || records.length === 0) return [];
        const rows = [];
        for (const rec of records) {
            const family = getSObjectFieldValue(rec, 'productFamily', 'ProductFamily', 'family') || '';
            let rawProductOptions = [];
            if (family) {
                try { rawProductOptions = await getProductsByFamily({ productFamily: family }); }
                catch (e) { console.error('[OPM] getProductsByFamily error =>', e); }
            }
            const savedProductId = getSObjectFieldValue(rec, 'productId', 'ProductId', 'product2Id', 'Product2Id') || '';
            const normOptions = buildProductOptions(rawProductOptions, savedProductId);
            const matchedOpt = normOptions.find((o) => o.selected);
            const msp = matchedOpt
                ? matchedOpt.msp
                : Number(getSObjectFieldValue(rec, 'msp', 'MSP', 'MSP__c', 'productMSP') || 0);
            const monthlyQty = Number(getSObjectFieldValue(rec, 'monthlyQty', 'MonthlyQty', 'monthly_qty') || 0);
            const storedMonthlyDealValue = getSObjectFieldValue(rec, 'monthlyDealValue', 'MonthlyDealValue');
            const storedTotalDealValue = getSObjectFieldValue(rec, 'totalDealValue', 'TotalDealValue');
            const storedTotalDealQty = getSObjectFieldValue(rec, 'totalDealQty', 'TotalDealQty');
            const rowDealPeriod = getSObjectFieldValue(rec, 'rowDealPeriod', 'RowDealPeriod');
            const effectivePeriod = Number(rowDealPeriod) || this.numericDealPeriod || 0;
            const monthlyDealValue =
                (storedMonthlyDealValue !== null && storedMonthlyDealValue !== undefined)
                    ? Number(storedMonthlyDealValue) : monthlyQty * msp;
            const totalDealValue =
                (storedTotalDealValue !== null && storedTotalDealValue !== undefined)
                    ? Number(storedTotalDealValue)
                    : (effectivePeriod > 0 ? monthlyDealValue * effectivePeriod : null);
            const totalDealQty =
                (storedTotalDealQty !== null && storedTotalDealQty !== undefined)
                    ? Number(storedTotalDealQty) : monthlyQty * effectivePeriod;
            const productLabel = matchedOpt
                ? matchedOpt.label
                : (getSObjectFieldValue(rec, 'productLabel', 'productName', 'ProductName') || '');
            rows.push(makeProductRow({
                id: rowIdCounter++,
                sfRecordId: getSObjectFieldValue(rec, 'sfRecordId', 'SfRecordId', 'Id', 'id') || null,
                productFamily: family, productId: savedProductId, productLabel,
                msp, mspFormatted: msp ? fmtINR(msp) : '—',
                monthlyQty: monthlyQty || '',
                totalDealQty,
                totalDealQtyDisplay: (totalDealQty > 0) ? String(totalDealQty) : '—',
                monthlyDealValue,
                monthlyDealValueFormatted: monthlyDealValue > 0 ? fmtINR(monthlyDealValue) : '—',
                totalDealValue,
                totalDealValueFormatted: (totalDealValue !== null && totalDealValue > 0) ? fmtINR(totalDealValue) : '—',
                dealFactor: null, dealFactorFormatted: '—',
                familyOptions: buildFamilyOptions(this._allFamilies, family),
                productOptions: normOptions,
                isDirty: false, isNew: false, rowNum: 0
            }));
        }
        return rows;
    }

    // ── Equipment row mapping (unchanged) ─────────────────────────────────────

    async _mapExistingEquipmentRows(records) {
        if (!records || records.length === 0) return [];
        const rows = [];
        for (const rec of records) {
            const savedEquipId = getSObjectFieldValue(
                rec, 'equipmentProductId', 'EquipmentProductId', 'equipmentId', 'Id', 'id'
            ) || '';
            const apexFlaggedOther = rec.isOtherProduct === true || rec.IsOtherProduct === true;
            const labelFlaggedOther = isOtherEquipmentProduct(this._allEquipmentOptions, savedEquipId);
            const isOther = apexFlaggedOther || labelFlaggedOther;
            let finalEquipOpts;
            if (isOther) {
                finalEquipOpts = this._otherEquipmentOption
                    ? [{ value: this._otherEquipmentOption.value, label: this._otherEquipmentOption.label, selected: true }]
                    : [{ value: savedEquipId, label: getSObjectFieldValue(rec, 'equipmentProductName', 'EquipmentProductName') || 'Others', selected: true }];
            } else {
                const normalOpts = buildNormalEquipmentOptions(this._allEquipmentOptions, savedEquipId);
                const hasMatch = normalOpts.some((o) => o.value === savedEquipId);
                finalEquipOpts = savedEquipId && !hasMatch
                    ? [...normalOpts, { value: savedEquipId, label: getSObjectFieldValue(rec, 'equipmentProductName', 'EquipmentProductName') || savedEquipId, selected: true }]
                    : normalOpts.map((o) => ({ ...o, selected: o.value === savedEquipId }));
            }
            let companyOptions = [];
            if (savedEquipId && !isOther) {
                try {
                    const companies = await getEquipmentCompanies({ equipmentProductId: savedEquipId });
                    const savedCompany = getSObjectFieldValue(rec, 'equipmentCompany', 'EquipmentCompany', 'company') || '';
                    companyOptions = buildCompanyOptions(companies, savedCompany);
                } catch (e) { console.error('[OPM] getEquipmentCompanies error =>', e); }
            }
            const savedCompany = getSObjectFieldValue(rec, 'equipmentCompany', 'EquipmentCompany', 'company') || '';
            const qty = Number(getSObjectFieldValue(rec, 'quantity', 'Quantity') || 1);
            const val = Number(getSObjectFieldValue(rec, 'equipmentValue', 'EquipmentValue') || 0);
            const rawInclGST = rec.equipmentValueInclGST != null ? rec.equipmentValueInclGST : null;
            const rawTotalVal = rec.equipmentTotalValue != null ? rec.equipmentTotalValue : null;
            const inclGST = rawInclGST !== null ? Number(rawInclGST) : null;
            const eqTotal = rawTotalVal !== null ? Number(rawTotalVal) : calcEquipTotalValue(qty, inclGST, val);
            const equipmentNameOther = getSObjectFieldValue(rec, 'equipmentNameOther', 'EquipmentNameOther') || '';
            const equipmentCompanyOther = getSObjectFieldValue(rec, 'equipmentCompanyOther', 'EquipmentCompanyOther') || '';
            rows.push(makeEquipRow({
                id: rowIdCounter++,
                sfRecordId: getSObjectFieldValue(rec, 'sfRecordId', 'SfRecordId', 'Id', 'id') || null,
                equipmentProductId: savedEquipId,
                equipmentProductName: getSObjectFieldValue(rec, 'equipmentProductName', 'EquipmentProductName', 'productName') || '',
                equipmentCompany: savedCompany, companyOptions,
                equipmentProductOptionsWithSelection: finalEquipOpts,
                quantity: qty, equipmentValue: val,
                equipmentValueInclGST: inclGST, equipmentTotalValue: eqTotal,
                equipmentNameOther, equipmentCompanyOther,
                isOtherProduct: isOther,
                isDirty: false, isNew: false, rowNum: 0
            }));
        }
        return rows;
    }

    // ── Row numbering ──────────────────────────────────────────────────────────

    _refreshRowNums() {
        this.productRows = this.productRows.map((r, i) => ({ ...r, rowNum: i + 1 }));
        this.simpleProductRows = this.simpleProductRows.map((r, i) => ({ ...r, rowNum: i + 1 }));
        let ni = 0, oi = 0;
        this.equipmentRows = this.equipmentRows.map((r) => ({
            ...r, rowNum: r.isOtherProduct ? ++oi : ++ni
        }));
    }

    handleClose() {
        document.removeEventListener('keydown', this._handleKeyDown);
        window.location.href = '/' + this.recordId;
    }

    // ── NEW: backdrop click closes the modal; clicking inside the modal itself shouldn't ──
    handleBackdropClick() {
        if (this.isWorking) return;
        this.handleClose();
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // SIMPLE PRODUCT ROWS (Product Record Type)
    // ══════════════════════════════════════════════════════════════════════════

    // ── CHANGED: new rows get the fixed Opp family + shared product options ───
    handleAddSimpleRow() {
        if (this.isViewOnly) return;
        this.simpleProductRows = [
            ...this.simpleProductRows,
            emptySimpleRow(this.oppProductFamily, this._sharedSimpleProductOptions)
        ];
        this._refreshRowNums();
    }

    handleDeleteSimpleRow(event) {
        if (this.isViewOnly) return;
        const id = Number(event.currentTarget.dataset.id);
        const row = this.simpleProductRows.find((r) => r.id === id);
        if (row && row.sfRecordId) this._productDeleteIds.push(row.sfRecordId);
        this.simpleProductRows = this.simpleProductRows.filter((r) => r.id !== id);
        this._refreshRowNums();
    }

    // ── REMOVED: handleSimpleFamilyChange — family is now read-only.
    //    The method is gone; the template must NOT render a family dropdown
    //    for simple rows. Instead show row.productFamily as plain text.

    // ── CHANGED: product options already exist in the row from the shared cache.
    //    Just update the selected flag and capture asp/label from the chosen opt.
    handleSimpleProductChange(event) {
        if (this.isViewOnly) return;
        const id = Number(event.target.dataset.id);
        const productId = event.target.value;
        const selOpt = event.target.options[event.target.selectedIndex];
        const asp = selOpt ? (Number(selOpt.dataset.asp) || 0) : 0;
        const lbl = selOpt ? selOpt.text : '';
        this.simpleProductRows = this.simpleProductRows.map((r) => {
            if (r.id !== id) return r;
            return makeSimpleRow({
                ...r,
                productId,
                productLabel: lbl,
                asp,
                aspFormatted: asp ? fmtINRSimple(asp) : '—',
                productOptions: (r.productOptions || []).map((opt) => ({
                    ...opt,
                    selected: opt.value === productId
                })),
                isDirty: true
            });
        });
    }

    handleSimpleQtyChange(event) {
        if (this.isViewOnly) return;
        const id = Number(event.target.dataset.id);
        const qty = Number(event.target.value) || 0;
        this.simpleProductRows = this.simpleProductRows.map((r) => {
            if (r.id !== id) return r;
            return makeSimpleRow({ ...r, qty, isDirty: true });
        });
    }

    async handleSimpleSave() {
        if (this.isViewOnly) return;

        // 0 rows = user deleted everything → just save deletes and close
        if (this.simpleProductRows.length === 0) {
            if (this._productDeleteIds.length === 0) {
                this.dispatchEvent(new CloseActionScreenEvent());
                eval("$A.get('e.force:refreshView').fire()");
                return;
            }
            this.isSaving = true;
            try {
                await saveOppProducts({ inputs: [], deleteIds: this._productDeleteIds });
                this._productDeleteIds = [];
                this.toast('Success', 'Products saved successfully!', 'success');
                setTimeout(() => {
                    this.handleClose();
                    this.dispatchEvent(new CloseActionScreenEvent());
                    // eslint-disable-next-line no-eval
                    eval("$A.get('e.force:refreshView').fire()");
                }, 1200);
            } catch (error) {
                this.toast('Error', this.errMsg(error), 'error');
            } finally {
                this.isSaving = false;
            }
            return;
        }

        const readyRows = this.simpleProductRows.filter(isSimpleRowComplete);
        if (readyRows.length === 0) {
            this.toast('Warning', 'Please add at least one complete product row.', 'warning');
            return;
        }

        const inputs = readyRows.map((r) => ({
            sfRecordId: r.sfRecordId || null,
            opportunityId: this._recordId,
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
            const savedIds = await saveOppProducts({ inputs, deleteIds: this._productDeleteIds });
            this._productDeleteIds = [];
            if (savedIds && savedIds.length) {
                this.simpleProductRows = this.simpleProductRows.map((r, i) =>
                    makeSimpleRow({ ...r, sfRecordId: r.sfRecordId || (savedIds[i] || null), isDirty: false, isNew: false })
                );
            }
            this.toast('Success', 'Products saved successfully!', 'success');
            setTimeout(() => {
                this.handleClose();
                this.dispatchEvent(new CloseActionScreenEvent());
                // eslint-disable-next-line no-eval
                eval("$A.get('e.force:refreshView').fire()");
            }, 1200);
            //  this.dispatchEvent(new CloseActionScreenEvent());
            // eslint-disable-next-line no-eval
            //  eval("$A.get('e.force:refreshView').fire()");
        } catch (error) {
            this.toast('Error', this.errMsg(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // FULL PRODUCTS (Non-Product Record Type) — unchanged
    // ══════════════════════════════════════════════════════════════════════════

    handleAddProductRow() {
        if (this.isViewOnly) return;
        this.productRows = [...this.productRows, emptyProductRow(this._allFamilies)];
        this._refreshRowNums();
    }

    handleDeleteProductRow(event) {
        if (this.isViewOnly) return;
        const id = Number(event.currentTarget.dataset.id);
        const row = this.productRows.find((r) => r.id === id);
        if (row && row.sfRecordId) this._productDeleteIds.push(row.sfRecordId);
        this.productRows = this.productRows.filter((r) => r.id !== id);
        this._refreshRowNums();
    }

    async handleFamilySelect(event) {
        if (this.isViewOnly) return;
        const id = Number(event.target.dataset.id);
        const family = event.target.value;
        let rawProductOptions = [];
        if (family) {
            try { rawProductOptions = await getProductsByFamily({ productFamily: family }); }
            catch (e) { console.error('[OPM] getProductsByFamily error =>', e); }
        }
        this.productRows = this.productRows.map((r) => {
            if (r.id !== id) return r;
            return makeProductRow({
                ...r, productFamily: family, productId: '', productLabel: '',
                msp: null, mspFormatted: '—',
                totalDealQtyDisplay: '—', monthlyDealValueFormatted: '—', totalDealValueFormatted: '—',
                dealFactor: null, dealFactorFormatted: '—',
                familyOptions: buildFamilyOptions(this._allFamilies, family),
                productOptions: buildProductOptions(rawProductOptions, ''),
                isDirty: true
            });
        });
    }

    handleProductSelect(event) {
        if (this.isViewOnly) return;
        const id = Number(event.target.dataset.id);
        const productId = event.target.value;
        const selOpt = event.target.options[event.target.selectedIndex];
        const msp = selOpt ? Number(selOpt.dataset.msp) || 0 : 0;
        this.productRows = this.productRows.map((r) => {
            if (r.id !== id) return r;
            return makeProductRow({
                ...r, productId, productLabel: selOpt ? selOpt.label : '',
                msp, mspFormatted: msp ? fmtINR(msp) : '—',
                productOptions: (r.productOptions || []).map((opt) => ({ ...opt, selected: opt.value === productId })),
                isDirty: true,
                ...this._calcProductValues(r.monthlyQty, msp)
            });
        });
    }

    handleProductQtyChange(event) {
        if (this.isViewOnly) return;
        const id = Number(event.target.dataset.id);
        const qty = event.target.value;
        this.productRows = this.productRows.map((r) => {
            if (r.id !== id) return r;
            return makeProductRow({ ...r, monthlyQty: qty, isDirty: true, ...this._calcProductValues(qty, r.msp || 0) });
        });
    }

    _calcProductValues(monthlyQty, msp) {
        const mq = Number(monthlyQty) || 0;
        const period = this.numericDealPeriod || 0;
        const mspN = Number(msp) || 0;
        const totalQty = mq * period;
        const monthlyVal = mq * mspN;
        const totalVal = totalQty * mspN;
        const factor = calcDealFactor(totalVal, this.equipmentTotal);
        return {
            totalDealQty: totalQty,
            totalDealQtyDisplay: (mq > 0 && period > 0) ? String(totalQty) : '—',
            monthlyDealValue: monthlyVal,
            monthlyDealValueFormatted: monthlyVal > 0 ? fmtINR(monthlyVal) : '—',
            totalDealValue: period > 0 ? totalVal : null,
            totalDealValueFormatted: (period > 0 && totalVal > 0) ? fmtINR(totalVal) : '—',
            dealFactor: factor,
            dealFactorFormatted: fmtFactor(factor)
        };
    }

    // ══════════════════════════════════════════════════════════════════════════
    // EQUIPMENT — unchanged
    // ══════════════════════════════════════════════════════════════════════════

    handleAddNormalEquipmentRow() {
        if (this.isViewOnly) return;
        this.equipmentRows = [...this.equipmentRows, emptyNormalEquipmentRow(this._allEquipmentOptions)];
        this._refreshRowNums();
    }

    handleAddOtherEquipmentRow() {
        if (this.isViewOnly) return;
        let otherOpt = this._otherEquipmentOption;
        if (!otherOpt) {
            otherOpt = (this._allEquipmentOptions || []).find((o) => isOtherLabel(o.label)) || null;
            if (otherOpt) this._otherEquipmentOption = otherOpt;
        }
        if (!otherOpt) {
            const rawMatch = (this._rawEquipmentOptions || []).find((e) => {
                const lbl = String(getSObjectFieldValue(e, 'Name', 'name', 'label') || '').trim().toLowerCase();
                return lbl === 'other' || lbl === 'others';
            });
            if (rawMatch) {
                otherOpt = {
                    value: getSObjectFieldValue(rawMatch, 'Id', 'id', 'value'),
                    label: String(getSObjectFieldValue(rawMatch, 'Name', 'name', 'label') || '').trim()
                };
                this._otherEquipmentOption = otherOpt;
            }
        }
        this.equipmentRows = [...this.equipmentRows, emptyOtherEquipmentRow(otherOpt)];
        this._refreshRowNums();
    }

    handleDeleteEquipmentRow(event) {
        if (this.isViewOnly) return;
        const id = Number(event.currentTarget.dataset.id);
        const row = this.equipmentRows.find((r) => r.id === id);
        if (row && row.sfRecordId) this._equipmentDeleteIds.push(row.sfRecordId);
        this.equipmentRows = this.equipmentRows.filter((r) => r.id !== id);
        this._refreshRowNums();
        this._recalcAllProductDealFactors();
    }

    async handleEquipmentProductSelect(event) {
        if (this.isViewOnly) return;
        const id = Number(event.target.dataset.id);
        const equipmentProdId = event.target.value;
        const row = this.equipmentRows.find((r) => r.id === id);
        const isOther = row ? row.isOtherProduct : false;
        const newEquipOpts = isOther
            ? (this._otherEquipmentOption
                ? [{ value: this._otherEquipmentOption.value, label: this._otherEquipmentOption.label, selected: true }]
                : [])
            : buildNormalEquipmentOptions(this._allEquipmentOptions, equipmentProdId);
        let companyOptions = [];
        if (equipmentProdId && !isOther) {
            try {
                const companies = await getEquipmentCompanies({ equipmentProductId: equipmentProdId });
                companyOptions = buildCompanyOptions(companies, '');
            } catch (e) { console.error('[OPM] getEquipmentCompanies error =>', e); }
        }
        this.equipmentRows = this.equipmentRows.map((r) => {
            if (r.id !== id) return r;
            return makeEquipRow({
                ...r, equipmentProductId: equipmentProdId,
                equipmentCompany: '', companyOptions,
                equipmentProductOptionsWithSelection: newEquipOpts,
                equipmentNameOther: '', equipmentCompanyOther: '',
                isOtherProduct: isOther, isDirty: true
            });
        });
        this._refreshRowNums();
    }

    handleEquipmentCompanySelect(event) {
        if (this.isViewOnly) return;
        const id = Number(event.target.dataset.id);
        const company = event.target.value;
        this.equipmentRows = this.equipmentRows.map((r) => {
            if (r.id !== id) return r;
            return makeEquipRow({
                ...r, equipmentCompany: company,
                companyOptions: (r.companyOptions || []).map((co) => ({ ...co, selected: co.value === company })),
                isDirty: true
            });
        });
    }

    handleEquipmentNameOtherChange(event) {
        if (this.isViewOnly) return;
        const id = Number(event.target.dataset.id);
        const val = event.target.value;
        this.equipmentRows = this.equipmentRows.map((r) => {
            if (r.id !== id) return r;
            return { ...r, equipmentNameOther: val, isDirty: true };
        });
    }

    handleEquipmentCompanyOtherChange(event) {
        if (this.isViewOnly) return;
        const id = Number(event.target.dataset.id);
        const val = event.target.value;
        this.equipmentRows = this.equipmentRows.map((r) => {
            if (r.id !== id) return r;
            return { ...r, equipmentCompanyOther: val, isDirty: true };
        });
    }

    incrementEquipQty(event) {
        if (this.isViewOnly) return;
        const id = Number(event.currentTarget.dataset.id);
        this.equipmentRows = this.equipmentRows.map((r) => {
            if (r.id !== id) return r;
            return makeEquipRow({ ...r, quantity: (r.quantity || 1) + 1, equipmentTotalValue: null, isDirty: true });
        });
        this._recalcAllProductDealFactors();
    }

    decrementEquipQty(event) {
        if (this.isViewOnly) return;
        const id = Number(event.currentTarget.dataset.id);
        this.equipmentRows = this.equipmentRows.map((r) => {
            if (r.id !== id) return r;
            return makeEquipRow({ ...r, quantity: Math.max(1, (r.quantity || 1) - 1), equipmentTotalValue: null, isDirty: true });
        });
        this._recalcAllProductDealFactors();
    }

    handleEquipmentValueInclGSTChange(event) {
        if (this.isViewOnly) return;
        const id = Number(event.target.dataset.id);
        const val = event.target.value;
        this.equipmentRows = this.equipmentRows.map((r) => {
            if (r.id !== id) return r;
            return makeEquipRow({ ...r, equipmentValueInclGST: val === '' ? null : Number(val), equipmentTotalValue: null, isDirty: true });
        });
        this._recalcAllProductDealFactors();
    }

    handleEquipmentTotalValueChange(event) {
        if (this.isViewOnly) return;
        const id = Number(event.target.dataset.id);
        const val = event.target.value;
        this.equipmentRows = this.equipmentRows.map((r) => {
            if (r.id !== id) return r;
            return makeEquipRow({ ...r, equipmentTotalValue: val === '' ? null : Number(val), isDirty: true });
        });
        this._recalcAllProductDealFactors();
    }

    _recalcAllProductDealFactors() {
        const equipNetTotal = this.equipmentTotal;
        this.productRows = this.productRows.map((r) => {
            const factor = calcDealFactor(Number(r.totalDealValue) || 0, equipNetTotal);
            return makeProductRow({ ...r, dealFactor: factor, dealFactorFormatted: fmtFactor(factor) });
        });
    }

    // ══════════════════════════════════════════════════════════════════════════
    // SAVE — unchanged
    // ══════════════════════════════════════════════════════════════════════════

    async handleSaveAll() {
        if (this.isViewOnly) return;
        try {
            console.log('recordId1221' + this._recordId);
            console.log('deal period' + this.dealPeriod);
            await saveDealPeriod({ opportunityId: this._recordId, dealPeriod: this.dealPeriod || null });
            console.log('deal period----' + this.dealPeriod);
        } catch (error) {
            this.toast('Error', 'Failed to save Deal Period: ' + this.errMsg(error), 'error');
            return;
        }
        const productOk = await this._saveProducts();
        console.log('deal period' + this.dealPeriod);
        if (!productOk) return;
        const equipOk = await this._saveEquipment();
        console.log('deal period' + this.dealPeriod);
        if (equipOk) {
            setTimeout(() => {
                this.handleClose();
                this.dispatchEvent(new CloseActionScreenEvent());
                eval("$A.get('e.force:refreshView').fire()");
            }, 1200);
        }
    }

    async _saveProducts() {
        this.showProductError = false;
        const inputs = this.productRows
            .filter((r) => r.productId)
            .map((r) => ({
                sfRecordId: r.sfRecordId || null,
                opportunityId: this._recordId,
                productId: r.productId,
                productFamilyLabel: r.productFamily,
                msp: r.msp || 0,
                monthlyQty: Number(r.monthlyQty) || 0,
                totalDealPeriod: this.numericDealPeriod ? String(this.numericDealPeriod) : null,
                totalDealQty: r.totalDealQty || 0,
                monthlyDealValue: r.monthlyDealValue || 0,
                totalDealValue: r.totalDealValue || 0
            }));
        this.isSaving = true;
        try {
            const savedIds = await saveOppProducts({ inputs, deleteIds: this._productDeleteIds });
            this._productDeleteIds = [];
            if (savedIds && savedIds.length) {
                this.productRows = this.productRows.map((r, i) =>
                    makeProductRow({ ...r, sfRecordId: r.sfRecordId || (savedIds[i] || null), isDirty: false, isNew: false })
                );
            }
            return true;
        } catch (error) {
            this.showProductError = true;
            this.productErrorMessage = this.errMsg(error);
            this.toast('Error', this.errMsg(error), 'error');
            return false;
        } finally {
            this.isSaving = false;
        }
    }

    async _saveEquipment() {
        this.showEquipmentError = false;
        const inputs = this.equipmentRows
            .filter((r) => r.equipmentProductId)
            .map((r) => ({
                sfRecordId: r.sfRecordId || null,
                opportunityId: this._recordId,
                equipmentProductId: r.equipmentProductId,
                equipmentCompany: r.isOtherProduct ? null : (r.equipmentCompany || 'Others'),
                quantity: r.quantity || 1,
                equipmentValue: Number(r.equipmentValue) || 0,
                equipmentValueInclGST: r.equipmentValueInclGST != null ? Number(r.equipmentValueInclGST) : null,
                equipmentTotalValue: r.equipmentTotalValue != null ? Number(r.equipmentTotalValue) : null,
                equipmentNameOther: r.isOtherProduct ? (r.equipmentNameOther || null) : null,
                equipmentCompanyOther: r.isOtherProduct ? (r.equipmentCompanyOther || null) : null
            }));
        this.isSaving = true;
        try {
            console.log('inputs==================>',inputs);
            const savedIds = await saveEquipmentGroups({ inputs, deleteIds: this._equipmentDeleteIds });
            this._equipmentDeleteIds = [];
            if (savedIds && savedIds.length) {
                this.equipmentRows = this.equipmentRows.map((r, i) =>
                    makeEquipRow({ ...r, sfRecordId: r.sfRecordId || (savedIds[i] || null), isDirty: false, isNew: false })
                );
            }
            this.toast('Success', 'Records saved successfully!', 'success');
            return true;
        } catch (error) {
            this.showEquipmentError = true;
            this.equipmentErrorMessage = this.errMsg(error);
            this.toast('Error', this.errMsg(error), 'error');
            return false;
        } finally {
            this.isSaving = false;
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    errMsg(error) {
        return error?.body?.message || error?.message ||
            (typeof error === 'string' ? error : 'An unexpected error occurred.');
    }
}
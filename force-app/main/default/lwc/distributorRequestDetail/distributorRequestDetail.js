import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getRequestDetail           from '@salesforce/apex/DistributorRequestDetailController.getRequestDetail';
import getResubmitData            from '@salesforce/apex/DistributorRequestDetailController.getResubmitData';
import resubmitWithUpdates        from '@salesforce/apex/DistributorRequestDetailController.resubmitWithUpdates';
import resubmitAdditionalRequest          from '@salesforce/apex/DistributorRequestDetailController.resubmitAdditionalRequest';
import resubmitToRegulatory               from '@salesforce/apex/DistributorRequestDetailController.resubmitToRegulatory';
import resubmitToRegulatoryWithUpdates    from '@salesforce/apex/DistributorRequestDetailController.resubmitToRegulatoryWithUpdates';
import getProductsByVertical   from '@salesforce/apex/DistributorRegistrationFormController.getProductsByVertical';
import getProductsForCertUpload from '@salesforce/apex/CertificateVerificationController.getProductsForCertUpload';
import getContentVersionId       from '@salesforce/apex/CertificateVerificationController.getContentVersionId';
import submitGovernmentResponse from '@salesforce/apex/CertificateVerificationController.submitGovernmentResponse';
import removeCertificate        from '@salesforce/apex/CertificateVerificationController.removeCertificate';

const STATUS_PILL = {
    'Draft':                            'status-pill pill-grey',
    'Submitted':                        'status-pill pill-blue',
    'Under Functional Head Review':     'status-pill pill-orange',
    'Under Leadership Review':          'status-pill pill-orange',
    'Under Management Approval':        'status-pill pill-orange',
    'Sent Back':                        'status-pill pill-yellow',
    'On Hold':                          'status-pill pill-yellow',
    'Approved by Leadership':           'status-pill pill-green',
    'Submitted to Regulatory':          'status-pill pill-blue',
    'Under Regulatory Review':          'status-pill pill-orange',
    'Additional Documents Requested':   'status-pill pill-yellow',
    'Pending Customer Response':        'status-pill pill-yellow',
    'Completed':                        'status-pill pill-green',
    'Rejected':                         'status-pill pill-red'
};

const FUNCTIONAL_HEAD_DONE = new Set([
    'Submitted',
    'Under Leadership Review', 'Under Management Approval',
    'Approved by Leadership', 'Submitted to Regulatory',
    'Under Regulatory Review', 'Additional Documents Requested',
    'Pending Customer Response', 'Completed'
]);

const LEADERSHIP_DONE = new Set([
    'Approved by Leadership', 'Submitted to Regulatory',
    'Under Regulatory Review', 'Additional Documents Requested',
    'Pending Customer Response', 'Completed'
]);

const REGULATORY_DONE = new Set([
    'Under Regulatory Review', 'Additional Documents Requested',
    'Pending Customer Response', 'Completed'
]);

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

let _rowId = 0;
const newRow = () => ({ rowId: String(++_rowId), productId: null });

export default class DistributorRequestDetail extends NavigationMixin(LightningElement) {
    @track _recordId;
    @track detail;
    @track isLoading = false;
    @track error;
    @track toastMessage;
    @track toastVariant = 'success';
    _toastTimer;

    // ── Re-submit form state ───────────────────────────────────────────────────
    @track showResubmitForm          = false;
    @track resubmitFormLoading       = false;
    @track _resubmitData             = null;
    @track _resubmitAvailableProds   = [];
    @track _rsExistingProdAddedDocs  = {}; // { productId: { docType: true/false } }
    @track _rsNewProdRows            = []; // [{ rowId, productId, selectedDocTypes: {} }]
    @track _rsNote                   = '';
    @track isResubmitting            = false;
    @track _resubmittingChildId      = null;

    @wire(CurrentPageReference)
    wiredPageRef(pageRef) {
        const id = pageRef?.state?.id ?? pageRef?.attributes?.recordId;
        if (id && id !== this._recordId) {
            this._recordId = id;
            this._load();
        }
    }

    async _load() {
        if (!this._recordId) return;
        this.isLoading = true;
        this.error = null;
        this.detail = null;
        try {
            this.detail = await getRequestDetail({ recordId: this._recordId });
            if (this.detail?.status === 'Completed') {
                this._loadCertProducts();
            }
        } catch (e) {
            this.error = e?.body?.message || 'Failed to load request details. Please refresh the page.';
        } finally {
            this.isLoading = false;
        }
    }

    // ── Detail getters ────────────────────────────────────────────────────────
    get hasDetail()          { return !!this.detail && !this.showResubmitForm; }
    get hasError()           { return !!this.error; }
    get isLoadingOnly()      { return this.isLoading && !this.detail && !this.error; }
    get statusClass()        { return STATUS_PILL[this.detail?.status] || 'status-pill pill-grey'; }
    get isRejected()            { return this.detail?.status === 'Rejected'; }
    get isSentBack()            { return this.detail?.status === 'Sent Back'; }
    get isSentBackByRA()        { return this.isSentBack && this.detail?.currentStage === 'Regulatory Processing'; }
    get isSentBackByLeadership(){ return this.isSentBack && this.detail?.currentStage !== 'Regulatory Processing'; }
    get hasRejectionBanner()    { return (this.isRejected || this.isSentBack) && !!this.detail?.rejectionComments; }
    get hasBasket()          { return !!this.detail?.basket; }
    get hasDocuments()       { return !!(this.detail?.documents?.length > 0); }

    get noDocuments()        { return !this.hasDocuments; }
    get hasChildren()        { return !!(this.detail?.childRequests?.length > 0); }
    get childRequests() {
        return (this.detail?.childRequests || []).map(c => ({
            ...c,
            isSentBack         : c.status === 'Sent Back',
            isResubmittingThis : this._resubmittingChildId === c.id
        }));
    }
    get hasRemarks()         { return !!this.detail?.remarks; }
    get hasDocTypes()            { return !!this.detail?.documentTypes; }
    get hasDocumentsByProduct()  { return (this.detail?.documentsByProduct?.length || 0) > 0; }
    get hasParent()          { return !!this.detail?.parentRequestId; }
    get hasBasketRARemarks() { return !!this.detail?.basket?.raRemarks; }
    get hasBasketDueDate()   { return !!this.detail?.basket?.dueDate; }

    get documentTypeList() {
        if (!this.detail?.documentTypes) return [];
        return this.detail.documentTypes.split(';')
            .map((v, i) => ({ key: i, label: v.trim() }))
            .filter(d => d.label);
    }

    get documents() {
        return (this.detail?.documents || []).map(doc => ({
            ...doc,
            downloadUrl: '/sfc/servlet.shepherd/document/download/' + doc.contentDocumentId
        }));
    }

    get raZipDoc() {
        const zip = (this.detail?.documents || []).find(
            d => d.fileType && d.fileType.toUpperCase() === 'ZIP'
        );
        if (!zip) return null;
        return { ...zip, downloadUrl: '/sfc/servlet.shepherd/document/download/' + zip.contentDocumentId };
    }

    get hasRaZip() { return !!this.raZipDoc; }

    get step1Class() { return 'progress-step done'; }
    get step2Class() { return 'progress-step' + (FUNCTIONAL_HEAD_DONE.has(this.detail?.status) ? ' done' : ''); }
    get step3Class() { return 'progress-step' + (LEADERSHIP_DONE.has(this.detail?.status) ? ' done' : ''); }
    get step4Class() { return 'progress-step' + (REGULATORY_DONE.has(this.detail?.status) ? ' done' : ''); }
    get step5Class() { return 'progress-step' + (this.detail?.status === 'Completed' ? ' done' : ''); }

    get toastClass() {
        return 'toast-msg ' + (this.toastVariant === 'error' ? 'toast-error' : 'toast-success');
    }

    // ── Handlers ──────────────────────────────────────────────────────────────
    handleBack() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/my-requests' }
        });
    }

    handleViewParent() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/request-detail?id=' + this.detail.parentRequestId }
        });
    }

    dismissToast() {
        this.toastMessage = null;
    }

    // ── Certificate Upload Section ───────────────────────────────────────────
    @track certProducts = [];
    @track certLoading = false;
    @track _pendingUploads = {};
    @track _productComments = {};
    @track _certValidityPickers = {};

    monthOptions = [
        { label: 'January',   value: '1'  },
        { label: 'February',  value: '2'  },
        { label: 'March',     value: '3'  },
        { label: 'April',     value: '4'  },
        { label: 'May',       value: '5'  },
        { label: 'June',      value: '6'  },
        { label: 'July',      value: '7'  },
        { label: 'August',    value: '8'  },
        { label: 'September', value: '9'  },
        { label: 'October',   value: '10' },
        { label: 'November',  value: '11' },
        { label: 'December',  value: '12' }
    ];

    get certYearOptions() {
        const cur = new Date().getFullYear();
        const years = [];
        for (let y = cur; y <= cur + 15; y++) years.push({ label: String(y), value: String(y) });
        return years;
    }

    get isCompleted()       { return this.detail?.status === 'Completed'; }
    get hasCertProducts()   { return this.certProducts.length > 0; }
    get certAcceptedFormats() { return '.pdf,.jpg,.jpeg,.png'; }

    async _loadCertProducts() {
        if (!this._recordId || !this.isCompleted) return;
        this.certLoading = true;
        try {
            const products = await getProductsForCertUpload({ requestId: this._recordId });
            // Pre-populate validity pickers from any already-saved dates
            const newPickers = {};
            products.forEach(p => {
                const from = p.confirmedValidFrom ? new Date(p.confirmedValidFrom) : null;
                const to   = p.confirmedValidTo   ? new Date(p.confirmedValidTo)   : null;
                if (from || to) {
                    newPickers[p.productId] = {
                        fromMonth: from ? String(from.getUTCMonth() + 1) : '',
                        fromYear : from ? String(from.getUTCFullYear())  : '',
                        toMonth  : to   ? String(to.getUTCMonth() + 1)  : '',
                        toYear   : to   ? String(to.getUTCFullYear())    : ''
                    };
                }
            });
            this._certValidityPickers = { ...this._certValidityPickers, ...newPickers };

            this.certProducts = products.map(p => {
                const pickers = this._certValidityPickers[p.productId] || {};
                return {
                    ...p,
                    requestId: this._recordId,
                    canUpload: p.certificateStatus === 'Pending Upload' || p.certificateStatus === 'Rejected',
                    isSubmitted: p.certificateStatus === 'Uploaded',
                    isUnderReview: p.certificateStatus === 'Under CRM Review',
                    isVerified: p.certificateStatus === 'Verified',
                    isRejected: p.certificateStatus === 'Rejected',
                    hasFeedback: !!p.rejectionComments,
                    statusClass: this._certStatusClass(p.certificateStatus),
                    hasCerts: (p.certificates || []).length > 0,
                    pendingFiles: this._pendingUploads[p.productId] || [],
                    govComment: this._productComments[p.productId] || '',
                    hasConfirmedValidity: !!p.confirmedValidFrom,
                    confirmedValidFromLabel: this._fmtMonthYear(p.confirmedValidFrom),
                    confirmedValidToLabel  : this._fmtMonthYear(p.confirmedValidTo),
                    certUploadLabel: this.detail?.noRegistrationRequired
                        ? 'Upload Certificates (optional)'
                        : 'Upload Certificates',
                    validFromMonth: pickers.fromMonth || '',
                    validFromYear : pickers.fromYear  || '',
                    validToMonth  : pickers.toMonth   || '',
                    validToYear   : pickers.toYear    || ''
                };
            });
        } catch (e) {
            this._showToast('Failed to load certificate status.', 'error');
        } finally {
            this.certLoading = false;
        }
    }

    _certStatusClass(status) {
        const map = {
            'Pending Upload':    'cert-pill cert-pill-pending',
            'Uploaded':          'cert-pill cert-pill-uploaded',
            'Under CRM Review':  'cert-pill cert-pill-review',
            'Verified':          'cert-pill cert-pill-verified',
            'Rejected':          'cert-pill cert-pill-rejected'
        };
        return map[status] || 'cert-pill cert-pill-pending';
    }

    handleCertUploadFinished(event) {
        const productId = event.target.dataset.productId;
        const files = event.detail.files;
        if (!files || files.length === 0) return;
        const newEntries = files.map(f => ({
            id:   f.contentDocumentId || f.documentId,
            name: f.name || 'certificate'
        }));
        const existing = this._pendingUploads[productId] || [];
        const merged   = [...existing, ...newEntries];
        this._pendingUploads = { ...this._pendingUploads, [productId]: merged };
        this.certProducts = this.certProducts.map(p =>
            p.productId === productId ? { ...p, pendingFiles: merged } : p
        );
        this._showToast(newEntries.length + ' file(s) selected. Click Submit to RA to confirm.', 'success');
    }

    handleCommentChange(event) {
        const productId = event.target.dataset.productId;
        const val = event.target.value;
        this._productComments = { ...this._productComments, [productId]: val };
        this.certProducts = this.certProducts.map(p =>
            p.productId === productId ? { ...p, govComment: val } : p
        );
    }

    handleCertFromMonthChange(e) {
        const pid = e.target.dataset.productId;
        const cur = this._certValidityPickers[pid] || {};
        this._certValidityPickers = { ...this._certValidityPickers, [pid]: { ...cur, fromMonth: e.detail.value } };
        this.certProducts = this.certProducts.map(p =>
            p.productId === pid ? { ...p, validFromMonth: e.detail.value } : p
        );
    }

    handleCertFromYearChange(e) {
        const pid = e.target.dataset.productId;
        const cur = this._certValidityPickers[pid] || {};
        this._certValidityPickers = { ...this._certValidityPickers, [pid]: { ...cur, fromYear: e.detail.value } };
        this.certProducts = this.certProducts.map(p =>
            p.productId === pid ? { ...p, validFromYear: e.detail.value } : p
        );
    }

    handleCertToMonthChange(e) {
        const pid = e.target.dataset.productId;
        const cur = this._certValidityPickers[pid] || {};
        this._certValidityPickers = { ...this._certValidityPickers, [pid]: { ...cur, toMonth: e.detail.value } };
        this.certProducts = this.certProducts.map(p =>
            p.productId === pid ? { ...p, validToMonth: e.detail.value } : p
        );
    }

    handleCertToYearChange(e) {
        const pid = e.target.dataset.productId;
        const cur = this._certValidityPickers[pid] || {};
        this._certValidityPickers = { ...this._certValidityPickers, [pid]: { ...cur, toYear: e.detail.value } };
        this.certProducts = this.certProducts.map(p =>
            p.productId === pid ? { ...p, validToYear: e.detail.value } : p
        );
    }

    async handleSubmitToRA(event) {
        const productId = event.target.dataset.productId;
        const comments = (this._productComments[productId] || '').trim();
        if (!comments) {
            this._showToast('A comment is required before submitting.', 'error');
            return;
        }
        // Validate validity dates (mandatory)
        const pickers = this._certValidityPickers[productId] || {};
        const { fromMonth, fromYear, toMonth, toYear } = pickers;
        if (!fromMonth || !fromYear || !toMonth || !toYear) {
            this._showToast('Please select both Valid From and Valid To dates before submitting.', 'error');
            return;
        }
        const validFromDate = `${fromYear}-${String(fromMonth).padStart(2, '0')}-01`;
        const lastDay       = new Date(parseInt(toYear, 10), parseInt(toMonth, 10), 0).getDate();
        const validToDate   = `${toYear}-${String(toMonth).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;

        const pending = this._pendingUploads[productId] || [];
        const certRequired = !this.detail?.noRegistrationRequired;
        const existingCerts = (this.certProducts || []).find(p => p.productId === productId)?.certificates || [];
        if (certRequired && pending.length === 0 && existingCerts.length === 0) {
            this._showToast('Please upload at least one government-approved certificate before submitting.', 'error');
            return;
        }
        const contentDocumentIds = pending.map(f => f.id);
        const certNames          = pending.map(f => f.name);
        try {
            await submitGovernmentResponse({ productId, comments, contentDocumentIds, certNames, validFromDate, validToDate });
            const uploads = { ...this._pendingUploads };
            delete uploads[productId];
            this._pendingUploads = uploads;
            const comms = { ...this._productComments };
            delete comms[productId];
            this._productComments = comms;
            this._showToast('Government approval submitted successfully.', 'success');
            await this._loadCertProducts();
        } catch (e) {
            this._showToast(e?.body?.message || 'Submission failed.', 'error');
        }
    }

    async handleRemoveCert(event) {
        const certId = event.target.dataset.certId;
        try {
            await removeCertificate({ certId: certId });
            this._showToast('Certificate removed.', 'success');
            await this._loadCertProducts();
        } catch (e) {
            this._showToast(e?.body?.message || 'Failed to remove certificate.', 'error');
        }
    }

    // ── Re-submit form ────────────────────────────────────────────────────────
    async handleOpenResubmit() {
        this.showResubmitForm         = true;
        this.resubmitFormLoading      = true;
        this._resubmitData            = null;
        this._resubmitAvailableProds  = [];
        this._rsExistingProdAddedDocs = {};
        this._rsNewProdRows           = [];
        this._rsNote                  = '';
        try {
            this._resubmitData = await getResubmitData({ recordId: this._recordId });
            const { vertical, accountId } = this._resubmitData || {};
            if (vertical && accountId) {
                this._resubmitAvailableProds = await getProductsByVertical({ vertical, accountId });
            }
        } catch (e) {
            this._showToast(e?.body?.message || 'Failed to load re-submit form.', 'error');
            this.showResubmitForm = false;
        } finally {
            this.resubmitFormLoading = false;
        }
    }

    handleCancelResubmit() {
        this.showResubmitForm = false;
    }

    handleRsNote(e)  { this._rsNote = e.target.value; }

    // Toggle doc type for an existing product
    handleRsExistingProdDocToggle(e) {
        const prodId    = e.currentTarget.dataset.prodId;
        const dt        = e.currentTarget.dataset.docType;
        const prod      = (this._resubmitData?.existingProducts || []).find(p => p.value === prodId);
        const lockedSet = new Set(prod?.docTypes || []);
        if (lockedSet.has(dt)) return; // can't remove existing
        const current = this._rsExistingProdAddedDocs[prodId] || {};
        this._rsExistingProdAddedDocs = {
            ...this._rsExistingProdAddedDocs,
            [prodId]: { ...current, [dt]: !current[dt] }
        };
    }

    // Toggle doc type for a new product row
    handleRsNewProdDocToggle(e) {
        const rowId = e.currentTarget.dataset.rowId;
        const dt    = e.currentTarget.dataset.docType;
        this._rsNewProdRows = this._rsNewProdRows.map(r => {
            if (r.rowId !== rowId) return r;
            const current = r.selectedDocTypes || {};
            return { ...r, selectedDocTypes: { ...current, [dt]: !current[dt] } };
        });
    }

    // Product rows
    handleRsAddProduct() {
        this._rsNewProdRows = [...this._rsNewProdRows, newRow()];
    }

    handleRsProductChange(e) {
        const rowId = e.currentTarget.dataset.rowId;
        const val   = e.detail.value;
        this._rsNewProdRows = this._rsNewProdRows.map(r =>
            r.rowId === rowId ? { ...r, productId: val } : r
        );
    }

    handleRsRemoveRow(e) {
        const rowId = e.currentTarget.dataset.rowId;
        this._rsNewProdRows = this._rsNewProdRows.filter(r => r.rowId !== rowId);
    }

    // Submit
    async handleConfirmResubmit() {
        if (this.resubmitSubmitDisabled) return;
        this.isResubmitting = true;
        try {
            if (this.isSentBackByRA) {
                // Applies to both New Registration and Additional Document Request —
                // Apex picks the notification type from Request_Type__c
                const existingProdAddedDocs = (this._resubmitData?.existingProducts || [])
                    .map(p => ({
                        productId  : p.value,
                        addDocTypes: Object.entries(this._rsExistingProdAddedDocs[p.value] || {})
                            .filter(([, v]) => v).map(([k]) => k)
                    }))
                    .filter(e => e.addDocTypes.length > 0);
                const newProdEntries = this._rsNewProdRows
                    .filter(r => r.productId)
                    .map(r => ({
                        productId: r.productId,
                        docTypes : Object.entries(r.selectedDocTypes || {})
                            .filter(([, v]) => v).map(([k]) => k)
                    }));
                await resubmitToRegulatoryWithUpdates({
                    requestId                : this._recordId,
                    existingProdAddedDocsJson: JSON.stringify(existingProdAddedDocs),
                    newProdEntriesJson       : JSON.stringify(newProdEntries),
                    resubmitNote             : this._rsNote || ''
                });
                this._showToast('Request re-submitted. The Regulatory Team has been notified.', 'success');
            } else {
                const existingProdAddedDocs = (this._resubmitData?.existingProducts || [])
                    .map(p => ({
                        productId  : p.value,
                        addDocTypes: Object.entries(this._rsExistingProdAddedDocs[p.value] || {})
                            .filter(([, v]) => v).map(([k]) => k)
                    }))
                    .filter(e => e.addDocTypes.length > 0);

                const newProdEntries = this._rsNewProdRows
                    .filter(r => r.productId)
                    .map(r => ({
                        productId: r.productId,
                        docTypes : Object.entries(r.selectedDocTypes || {})
                            .filter(([, v]) => v).map(([k]) => k)
                    }));

                await resubmitWithUpdates({
                    recordId                 : this._recordId,
                    validFromDate            : null,
                    validToDate              : null,
                    existingProdAddedDocsJson: JSON.stringify(existingProdAddedDocs),
                    newProdEntriesJson       : JSON.stringify(newProdEntries),
                    resubmitNote             : this._rsNote || ''
                });
                this._showToast('Request re-submitted successfully. The Functional Head has been notified.', 'success');
            }
            this.showResubmitForm = false;
            await this._load();
        } catch (e) {
            this._showToast(e?.body?.message || 'Re-submission failed. Please try again.', 'error');
        } finally {
            this.isResubmitting = false;
        }
    }

    // ── Resubmit Additional Document Request ─────────────────────────────────
    async handleResubmitChild(event) {
        const childId = event.currentTarget.dataset.childId;
        this._resubmittingChildId = childId;
        try {
            await resubmitAdditionalRequest({ childRequestId: childId });
            this._showToast('Request resubmitted. The RA Team has been notified.', 'success');
            await this._load();
        } catch (e) {
            this._showToast(e?.body?.message || 'Resubmission failed. Please try again.', 'error');
        } finally {
            this._resubmittingChildId = null;
        }
    }

    // ── Re-submit form getters ────────────────────────────────────────────────
    get resubmitButtonLabel() { return this.isSentBackByRA ? 'Re-submit to Regulatory' : 'Re-submit to Functional Head'; }

    get resubmitSubmitDisabled() {
        return (this.isResubmitting || this.resubmitFormLoading) ? true : null;
    }

    get resubmitAgreementLabel() {
        return this._resubmitData?.agreementSignedWith || '—';
    }

    get resubmitDurationLabel() {
        const d = this._resubmitData?.durationMonths;
        return d ? `${d} Month${d !== 1 ? 's' : ''}` : '—';
    }

    // Existing products with per-product doc type chip data
    get resubmitExistingProductsWithDocs() {
        return (this._resubmitData?.existingProducts || []).map(prod => {
            const lockedSet = new Set(prod.docTypes || []);
            const addedMap  = this._rsExistingProdAddedDocs[prod.value] || {};
            const chips = DOCUMENT_TYPES.map(dt => {
                const isLocked   = lockedSet.has(dt.value);
                const isAdded    = !isLocked && !!addedMap[dt.value];
                const isSelected = isLocked || isAdded;
                return {
                    ...dt,
                    key       : dt.value,
                    isLocked,
                    isSelected,
                    chipClass : isLocked   ? 'rs-chip rs-chip-locked'
                              : isSelected ? 'rs-chip rs-chip-selected'
                              : 'rs-chip'
                };
            });
            return { ...prod, key: prod.value, chips };
        });
    }

    // New product rows with per-row doc chip data
    get resubmitNewProdRows() {
        const existingIds    = new Set((this._resubmitData?.existingProducts || []).map(p => p.value));
        const selectedNewIds = new Set(this._rsNewProdRows.map(r => r.productId).filter(Boolean));
        return this._rsNewProdRows.map(r => {
            const selectedDocs = r.selectedDocTypes || {};
            const chips = DOCUMENT_TYPES.map(dt => ({
                ...dt,
                key       : dt.value,
                isSelected: !!selectedDocs[dt.value],
                chipClass : selectedDocs[dt.value] ? 'rs-chip rs-chip-selected' : 'rs-chip'
            }));
            return {
                ...r,
                hasProduct      : !!r.productId,
                chips,
                availableOptions: this._resubmitAvailableProds.filter(
                    o => !existingIds.has(o.value) && (o.value === r.productId || !selectedNewIds.has(o.value))
                )
            };
        });
    }

    _fmtMonthYear(dateStr) {
        if (!dateStr) return '—';
        try {
            const d = new Date(dateStr);
            return d.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
        } catch (e) { return dateStr; }
    }

    @track _showPreview    = false;
    @track _previewLoading = false;
    @track _previewIsImage = false;
    @track _previewDataUrl = '';

    @track _showPreview    = false;
    @track _previewLoading = false;
    @track _previewPages   = [];
    _previewVersionId      = null;

    get _hasPreviewPages() { return this._previewPages.length > 0; }

    async handlePreview(event) {
        event.preventDefault();
        const docId = event.currentTarget.dataset.docId;
        this._showPreview      = true;
        this._previewLoading   = true;
        this._previewPages     = [];
        this._previewVersionId = null;
        try {
            const vId = await getContentVersionId({ contentDocumentId: docId });
            this._previewVersionId = vId;
            const base = '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + vId;
            this._previewPages = [{ key: '0', url: base + '&page=0' }];
        } catch (e) {
            this._showPreview = false;
            this._showToast(e?.body?.message || 'Failed to load preview.', 'error');
        } finally {
            this._previewLoading = false;
        }
    }

    handlePageLoad(event) {
        const idx  = parseInt(event.target.dataset.pageIndex, 10);
        const next = idx + 1;
        if (this._previewVersionId && next < 50) {
            const base = '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + this._previewVersionId;
            this._previewPages = [...this._previewPages, { key: String(next), url: base + '&page=' + next }];
        }
    }

    handlePreviewError(event) {
        const idx = parseInt(event.target.dataset.pageIndex, 10);
        if (idx === 0) {
            this._previewPages = [];
        } else {
            event.target.style.display = 'none';
        }
    }

    closePreview() {
        this._showPreview      = false;
        this._previewPages     = [];
        this._previewVersionId = null;
    }
    stopPreviewProp(event) { event.stopPropagation(); }
    stopPreviewProp(event) { event.stopPropagation(); }

    // ── Shared helper ─────────────────────────────────────────────────────────
    _showToast(message, variant) {
        if (this._toastTimer) clearTimeout(this._toastTimer);
        this.toastMessage = message;
        this.toastVariant = variant;
        this._toastTimer = setTimeout(() => { this.toastMessage = null; }, 4000);
    }
}
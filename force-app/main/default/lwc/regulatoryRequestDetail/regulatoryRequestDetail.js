import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getRequestDetail    from '@salesforce/apex/RegulatoryRequestDetailController.getRequestDetail';
import startReview         from '@salesforce/apex/RegulatoryActionController.startReview';
import resumeReview        from '@salesforce/apex/RegulatoryActionController.resumeReview';
import markCompleted       from '@salesforce/apex/RegulatoryActionController.markCompleted';
import markCertificateUploaded from '@salesforce/apex/RegulatoryActionController.markCertificateUploaded';
import updateRARemarks     from '@salesforce/apex/RegulatoryActionController.updateRARemarks';
import deleteDocument           from '@salesforce/apex/RegulatoryActionController.deleteDocument';
import resetCertificateUploaded from '@salesforce/apex/RegulatoryActionController.resetCertificateUploaded';
import linkDocumentToSlot       from '@salesforce/apex/RegulatoryActionController.linkDocumentToSlot';
import getUserDocumentAccess  from '@salesforce/apex/DocumentSecurityController.getUserDocumentAccess';
import enforceVisibility      from '@salesforce/apex/DocumentSecurityService.enforceVisibility';
import shareWithDistributor   from '@salesforce/apex/DocumentSecurityService.shareWithDistributor';
import getProductsForRAReview from '@salesforce/apex/CertificateVerificationController.getProductsForRAReview';
import forwardProductToCRM   from '@salesforce/apex/CertificateVerificationController.forwardProductToCRM';
import sendBackCertificate   from '@salesforce/apex/CertificateVerificationController.sendBackCertificate';
import rejectCertificate     from '@salesforce/apex/CertificateVerificationController.rejectCertificate';
import unlockProductOrder     from '@salesforce/apex/CertificateVerificationController.unlockProductOrder';
import getCertFileData        from '@salesforce/apex/CertificateVerificationController.getCertFileData';
import removeCertificate     from '@salesforce/apex/CertificateVerificationController.removeCertificate';
import saveForecastWeek          from '@salesforce/apex/RegulatoryActionController.saveForecastWeek';
import confirmProductValidity    from '@salesforce/apex/CertificateVerificationController.confirmProductValidity';
import returnAdditionalRequest      from '@salesforce/apex/RegulatoryActionController.returnAdditionalRequest';
import returnRegistrationRequest    from '@salesforce/apex/RegulatoryActionController.returnRegistrationRequest';
import rejectRegistrationRequest   from '@salesforce/apex/RegulatoryActionController.rejectRegistrationRequest';

const STATUS_CLASS_MAP = {
    'Submitted to Regulatory':          'status-pill pending',
    'Under Regulatory Review':          'status-pill review',
    'Additional Documents Requested':   'status-pill additional',
    'Pending Customer Response':        'status-pill waiting',
    'Completed':                        'status-pill completed'
};

const BASKET_CLASS_MAP = {
    'Pending':                    'basket-badge pending',
    'Under Review':               'basket-badge review',
    'Additional Documents Required': 'basket-badge additional',
    'Approved':                   'basket-badge approved'
};

export default class RegulatoryRequestDetail extends NavigationMixin(LightningElement) {
    @api recordId;

    @track _resolvedId;
    @track detail;
    @track isLoading = true;
    @track hasError  = false;
    @track errorMessage;
    @track actionInProgress = false;

    @track showMarkCompletedForm = false;
    @track actionComments = '';
    @track remarksInput   = '';

    @track toastMessage;
    @track toastVariant = 'success';
    @track _accessLevel       = 'FULL';
    @track _typeFileMap       = {}; // uploadKey → uploaded file object (session-level tracking)
    @track _certDeleted       = false; // optimistic flag so upload button shows immediately on Re-upload
    @track _docTypesByProduct = [];
    _certTrackedId = null;        // contentDocumentId of cert uploaded this session (survives refreshApex)
    _toastTimer;
    @track _zipFileInfo = null;

    // ── Reject Registration Request state ────────────────────────────────────
    @track _showRejectModal    = false;
    @track _rejectComments     = '';
    @track _isRejecting        = false;

    // ── Return Registration Request state ────────────────────────────────────
    @track _showMainReturnModal   = false;
    @track _mainReturnComments    = '';
    @track _isMainReturning       = false;

    // ── Return Additional Request state ───────────────────────────────────────
    @track _showReturnModal   = false;
    @track _returnChildId     = null;
    @track _returnComments    = '';
    @track _isReturning       = false;

    // ── Forecast Week edit state ──────────────────────────────────────────────
    @track _editingForecast   = false;
    @track _editForecastWeek  = '';
    @track _editForecastYear  = '';
    @track _isSavingForecast  = false;

    @track _raValidityEdit    = {}; // { [productId]: { fromMonth, fromYear, toMonth, toYear } }
    @track _raValidityEditing = {}; // { [productId]: true } — products currently in edit mode

    _wiredResult;

    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        if (pageRef) {
            const id = pageRef.attributes?.recordId ?? pageRef.state?.recordId;
            if (id) this._resolvedId = id;
        }
    }

    get _recordId() {
        return this._resolvedId || this.recordId;
    }

    @wire(getRequestDetail, { recordId: '$_recordId' })
    wiredDetail(result) {
        this._wiredResult = result;
        this.isLoading = false;
        if (result.data) {
            this.hasError = false;
            this.detail   = this._processDetail(result.data);
            this._preloadTypeFileMap();
            this._computeDocTypesByProduct();
            this.remarksInput = result.data.basket?.raRemarks ?? '';
            if (result.data.basket?.id) {
                this._loadAccessLevel(result.data.basket.id);
            }
            if (result.data.status === 'Completed') {
                this._loadCertProducts();
            }
            // Restore ZIP info from already-uploaded basket documents
            if (!this._zipFileInfo) {
                const zipDoc = (result.data.documents || []).find(
                    d => d.fileType && d.fileType.toUpperCase() === 'ZIP'
                );
                if (zipDoc) {
                    this._zipFileInfo = {
                        name             : zipDoc.title,
                        contentDocumentId: zipDoc.contentDocumentId
                    };
                }
            }
        } else if (result.error) {
            this.hasError     = true;
            this.errorMessage = result.error?.body?.message ?? 'Failed to load request details.';
        }
    }

    _processDetail(raw) {
        const d = Object.assign({}, raw);
        if (d.submittedDate) {
            try {
                d._submittedDate = new Date(d.submittedDate);
            } catch (e) { /* ignore */ }
        }
        if (d.documents) {
            d.documents = d.documents.map(doc => {
                const copy = Object.assign({}, doc);
                copy.cssClass    = 'doc-item' + (doc.isCertificate ? ' is-cert' : '');
                copy.downloadUrl = '/sfc/servlet.shepherd/document/download/' + doc.contentDocumentId;
                copy.fileSizeLabel = doc.contentSize
                    ? (doc.contentSize < 1024 ? doc.contentSize + ' B'
                        : doc.contentSize < 1048576 ? Math.round(doc.contentSize / 1024) + ' KB'
                        : (doc.contentSize / 1048576).toFixed(1) + ' MB')
                    : '';
                return copy;
            });
        }
        if (d.childRequests) {
            d.childRequests = d.childRequests.map(c => {
                const copy = Object.assign({}, c);
                copy.statusPill = STATUS_CLASS_MAP[c.status] || 'status-pill';
                copy.canReturn  = c.status !== 'Sent Back' && c.status !== 'Completed' && c.status !== 'Rejected';
                return copy;
            });
        }
        return d;
    }

    get formattedSubmittedDate() {
        if (!this.detail?.submittedDate) return '—';
        try {
            return new Date(this.detail.submittedDate).toLocaleDateString('en-IN', {
                day: '2-digit', month: 'short', year: 'numeric'
            });
        } catch (e) { return this.detail.submittedDate; }
    }

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

    get yearOptions() {
        const cur = new Date().getFullYear();
        const years = [];
        for (let y = cur; y <= cur + 15; y++) {
            years.push({ label: String(y), value: String(y) });
        }
        return years;
    }

    get weekOptions() {
        const opts = [];
        for (let w = 1; w <= 52; w++) {
            opts.push({ label: 'Week ' + w, value: String(w) });
        }
        return opts;
    }

    get forecastYearOptions() {
        const cur = new Date().getFullYear();
        const opts = [];
        for (let y = cur; y <= cur + 5; y++) {
            opts.push({ label: String(y), value: String(y) });
        }
        return opts;
    }

    _getLastDayOfWeek(weekNum, year) {
        // Week N spans days (N-1)*7+1 to N*7 of the year; last day = Jan (7*N) with overflow
        const lastDay = new Date(year, 0, weekNum * 7);
        const dec31   = new Date(year, 11, 31);
        return lastDay > dec31 ? dec31 : lastDay;
    }

    _formatDate(d) {
        return d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
    }

    get forecastWeekLabel() {
        const w = this.detail?.forecastWeek;
        const y = this.detail?.forecastYear;
        if (!w || !y) return '—';
        const lastDay = this._getLastDayOfWeek(w, y);
        return 'Week ' + w + ', ' + y + ' · ' + this._formatDate(lastDay);
    }

    get forecastPreviewDate() {
        const w = parseInt(this._editForecastWeek, 10);
        const y = parseInt(this._editForecastYear, 10);
        if (!w || !y) return '';
        return 'Last day: ' + this._formatDate(this._getLastDayOfWeek(w, y));
    }

    get actualCompletionLabel() {
        const w = this.detail?.actualCompletionWeek;
        const y = this.detail?.actualCompletionYear;
        if (!w || !y) return '—';
        const lastDay = this._getLastDayOfWeek(w, y);
        return 'Week ' + w + ', ' + y + ' · ' + this._formatDate(lastDay);
    }

    get editingForecast()    { return this._editingForecast; }
    get notEditingForecast() { return !this._editingForecast; }

    handleEditForecast() {
        this._editForecastWeek = this.detail?.forecastWeek ? String(this.detail.forecastWeek) : '';
        this._editForecastYear = this.detail?.forecastYear ? String(this.detail.forecastYear) : '';
        this._editingForecast  = true;
    }

    handleForecastWeekChange(e) { this._editForecastWeek = e.detail.value; }
    handleForecastYearChange(e) { this._editForecastYear = e.detail.value; }

    handleCancelForecast() { this._editingForecast = false; }

    async handleSaveForecast() {
        if (!this._editForecastWeek || !this._editForecastYear) {
            this._showToast('Please select both a week and a year.', 'error');
            return;
        }
        this._isSavingForecast = true;
        try {
            await saveForecastWeek({
                recordId: this._recordId,
                weekNum : parseInt(this._editForecastWeek, 10),
                yr      : parseInt(this._editForecastYear, 10)
            });
            this._editingForecast = false;
            this._showToast('Forecast week saved.', 'success');
            this._refresh();
        } catch (e) {
            this._showToast(e?.body?.message ?? 'Failed to save forecast week.', 'error');
        } finally {
            this._isSavingForecast = false;
        }
    }

    _formatMonthYear(dateStr) {
        if (!dateStr) return '—';
        try {
            const d = new Date(dateStr);
            return d.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
        } catch (e) { return dateStr; }
    }

    get statusClass() {
        return STATUS_CLASS_MAP[this.detail?.status] || 'status-pill';
    }

    get basketStatusClass() {
        return BASKET_CLASS_MAP[this.detail?.basket?.status] || 'basket-badge';
    }

    get acceptedFormats() {
        return ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.jpg', '.jpeg', '.png'];
    }

    get zipAcceptedFormats() { return ['.zip']; }
    get canReturnRequest()          { return this.detail?.status === 'Under Regulatory Review'; }
    get canRejectRequest()          { return this.detail?.status === 'Under Regulatory Review'; }
    get showRejectModal()           { return this._showRejectModal; }
    get rejectConfirmDisabled()     { return this._isRejecting || !this._rejectComments?.trim(); }
    get showMainReturnModal()       { return this._showMainReturnModal; }
    get mainReturnConfirmDisabled() { return this._isMainReturning || !this._mainReturnComments?.trim(); }
    get showReturnModal()       { return this._showReturnModal; }
    get returnConfirmDisabled() { return this._isReturning || !this._returnComments?.trim(); }
    get hasZipUploaded()     { return !!this._zipFileInfo; }
    get zipFileName()        { return this._zipFileInfo?.name ?? ''; }
    get zipDownloadUrl()     { return this._zipFileInfo?.contentDocumentId ? '/sfc/servlet.shepherd/document/download/' + this._zipFileInfo.contentDocumentId : '#'; }

    get hasDocuments() {
        return this.detail?.documents?.length > 0;
    }

    get docCount() {
        return this.detail?.documents?.length ?? 0;
    }

    get certDocuments() {
        return this.detail?.documents?.filter(d => d.isCertificate) ?? [];
    }

    get hasCertDocument() {
        return this.certDocuments.length > 0;
    }

    get nonCertDocuments() {
        return this.detail?.documents?.filter(d => !d.isCertificate) ?? [];
    }

    get hasNonCertDocuments() {
        return this.nonCertDocuments.length > 0;
    }

    get certAcceptedFormats() {
        return ['.pdf'];
    }

    get canDownload()      { return this._accessLevel === 'FULL'; }
    get isMetadataOnly()   { return this._accessLevel === 'METADATA_ONLY'; }
    get certNotUploaded()  { return !this.detail?.certificateUploaded || this._certDeleted; }
    get isReadOnly() {
        return this.detail?.status === 'Completed' || this.detail?.basket?.status === 'Approved';
    }
    get canUpload() { return !this.isReadOnly; }

    get showCertReupload() { return this.detail?.certificateUploaded && !this._certDeleted && this.canUpload; }
    get certDocTitle()     { return this.certDocuments[0]?.title ?? 'Registration Certificate'; }
    get certDocContentId() { return this.certDocuments[0]?.contentDocumentId ?? null; }

    _loadAccessLevel(basketId) {
        getUserDocumentAccess({ basketId })
            .then(level => { this._accessLevel = level; })
            .catch(() => { this._accessLevel = 'NONE'; });
    }

    _enforceVisibility(uploadedFiles, linkedEntityId) {
        const docIds = uploadedFiles.map(f => f.contentDocumentId || f.documentId).filter(Boolean);
        if (docIds.length > 0 && linkedEntityId) {
            enforceVisibility({ contentDocumentIds: docIds, linkedEntityId })
                .catch(() => {});
        }
        // Also link to the parent request so the Distributor can see the files
        if (docIds.length > 0 && this._recordId) {
            shareWithDistributor({ contentDocumentIds: docIds, requestId: this._recordId })
                .catch(() => {});
        }
    }

    get hasChildRequests() {
        return this.detail?.childRequests?.length > 0;
    }

    get childCount() {
        return this.detail?.childRequests?.length ?? 0;
    }

    get certIconVariant() {
        return this.detail?.certificateUploaded ? 'success' : '';
    }

    get docTypeList() {
        if (!this.detail?.documentTypes) return [];
        return this.detail.documentTypes.split(';')
            .map(t => t.trim())
            .filter(Boolean)
            .map(t => {
                const uploaded = this._typeFileMap[t];
                return {
                    key               : t,
                    name              : t,
                    uploadLabel       : 'Upload ' + t,
                    uploaded          : !!uploaded,
                    uploadedTitle     : uploaded ? uploaded.name : null,
                    uploadedDocumentId: uploaded ? uploaded.contentDocumentId : null,
                    notUploaded       : !uploaded
                };
            });
    }

    get hasDocTypes() {
        return this.docTypeList.length > 0;
    }

    get hasDocumentsByProduct() {
        return (this.detail?.documentsByProduct?.length || 0) > 0;
    }

    _preloadTypeFileMap() {
        const groups = this.detail?.documentsByProduct || [];
        const newMap = {};
        for (const group of groups) {
            for (const entry of (group.docTypes || [])) {
                if (entry && entry.uploadedDocumentId) {
                    const uploadKey = group.productName + '|' + entry.docType;
                    newMap[uploadKey] = {
                        name             : entry.uploadedDocumentName || entry.uploadedDocumentId,
                        contentDocumentId: entry.uploadedDocumentId
                    };
                }
            }
        }
        this._typeFileMap = { ...this._typeFileMap, ...newMap };
    }

    _computeDocTypesByProduct() {
        const groups = this.detail?.documentsByProduct;
        if (!groups?.length) {
            this._docTypesByProduct = [];
            return;
        }
        this._docTypesByProduct = groups.map(group => ({
            productName : group.productName,
            docItems    : (group.docTypes || []).map(entry => {
                const docType   = (entry && entry.docType) ? entry.docType : entry;
                const uploadKey = group.productName + '|' + docType;
                const uploaded  = this._typeFileMap[uploadKey];
                return {
                    key               : uploadKey,
                    name              : docType,
                    uploadLabel       : 'Upload ' + docType,
                    uploaded          : !!uploaded,
                    uploadedTitle     : uploaded ? uploaded.name : null,
                    uploadedDocumentId: uploaded ? uploaded.contentDocumentId : null,
                    notUploaded       : !uploaded
                };
            })
        }));
    }

    get nonCertDocCount() {
        return this.nonCertDocuments.length;
    }

    get hasProductDetails() { return (this.detail?.productDetails?.length || 0) > 0; }
    get productDetails()    { return this.detail?.productDetails || []; }

    get canStartReview() {
        return this.detail?.status === 'Submitted to Regulatory';
    }

    get canResumeReview() {
        return this.detail?.status === 'Additional Documents Requested'
            || this.detail?.status === 'Pending Customer Response';
    }

    get canMarkCompleted() {
        return this.detail?.status === 'Under Regulatory Review';
    }

    // ── Navigation ──────────────────────────────────────────────────────────────

    handleBack() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/regulatory-queue' }
        });
    }

    // ── Actions ──────────────────────────────────────────────────────────────────

    handleStartReview() {
        this._runAction(() => startReview({ recordId: this._recordId }), 'Review started.');
    }

    handleOpenMarkCompleted() {
        if (!this.detail?.forecastWeek || !this.detail?.forecastYear) {
            this._showToast('Please set the Forecast Week before marking as Completed.', 'error');
            return;
        }
        this.showMarkCompletedForm = true;
        this.showRequestDocsForm   = false;
        this.actionComments        = '';
    }

    handleCancelForm() {
        this.showMarkCompletedForm = false;
        this.actionComments        = '';
    }

    handleCommentsChange(event) {
        this.actionComments = event.target.value;
    }

    handleConfirmMarkCompleted() {
        this._runAction(
            () => markCompleted({ recordId: this._recordId, remarks: this.actionComments }),
            'Request marked as Completed.',
            () => { this.showMarkCompletedForm = false; this.actionComments = ''; }
        );
    }

    handleResumeReview() {
        this._runAction(() => resumeReview({ recordId: this._recordId }), 'Review resumed.');
    }

    handleMarkCertUploaded() {
        this._runAction(
            () => markCertificateUploaded({ recordId: this._recordId }),
            'Certificate marked as uploaded.'
        );
    }

    handleRemoveCert() {
        // Immediately show upload button
        this._certDeleted = true;
        // Use tracked ID from this session first, then fall back to title-matched cert doc
        const docId = this._certTrackedId || this.certDocContentId;
        resetCertificateUploaded({ recordId: this._recordId, contentDocumentId: docId })
            .then(() => { this._certTrackedId = null; this._certDeleted = false; this._refresh(); })
            .catch(() => { this._certDeleted = false; this._refresh(); });
    }

    handleRemarksChange(event) {
        this.remarksInput = event.target.value;
    }

    handleSaveRemarks() {
        this._runAction(
            () => updateRARemarks({ basketId: this.detail?.basket?.id, remarks: this.remarksInput }),
            'RA remarks saved.'
        );
    }

    handleUploadFinished(event) {
        const uploadKey = event.target.dataset.uploadkey || event.target.dataset.doctype;
        const files     = event.detail.files;
        this._enforceVisibility(files, this.detail?.basket?.id);
        this._showToast('Document uploaded successfully.', 'success');

        if (uploadKey && files && files.length > 0) {
            const f = files[0];
            const docId = f.contentDocumentId || f.documentId;
            this._typeFileMap = {
                ...this._typeFileMap,
                [uploadKey]: { name: f.name, contentDocumentId: docId }
            };
            this._computeDocTypesByProduct();

            const parts = uploadKey.split('|');
            const linkPromise = parts.length === 2
                ? linkDocumentToSlot({
                    requestId        : this._recordId,
                    productName      : parts[0],
                    docType          : parts[1],
                    contentDocumentId: docId
                  })
                : Promise.resolve();

            linkPromise.catch(() => {}).finally(() => { this._refresh(); });
        } else {
            this._refresh();
        }
    }

    handleZipUploadFinished(event) {
        const files = event.detail.files;
        if (files && files.length > 0) {
            const f = files[0];
            this._zipFileInfo = { name: f.name, contentDocumentId: f.contentDocumentId || f.documentId };
        }
        this._enforceVisibility(files, this.detail?.basket?.id);
        this._showToast('ZIP package uploaded successfully.', 'success');
    }

    handleRemoveZip() {
        const docId = this._zipFileInfo?.contentDocumentId;
        this._zipFileInfo = null;
        if (docId) {
            deleteDocument({ contentDocumentId: docId }).catch(() => {});
        }
    }

    handleRemoveTypeFile(event) {
        const uploadKey = event.target.dataset.uploadkey || event.target.dataset.doctype;
        const fileInfo  = this._typeFileMap[uploadKey];
        if (!uploadKey || !fileInfo) return;

        const updated = { ...this._typeFileMap };
        delete updated[uploadKey];
        this._typeFileMap = updated;
        this._computeDocTypesByProduct();

        const docId = fileInfo.contentDocumentId;
        const parts = uploadKey.split('|');

        const clearSlot = parts.length === 2
            ? linkDocumentToSlot({
                requestId        : this._recordId,
                productName      : parts[0],
                docType          : parts[1],
                contentDocumentId: null
              })
            : Promise.resolve();

        const deleteFile = docId
            ? deleteDocument({ contentDocumentId: docId })
            : Promise.resolve();

        Promise.all([clearSlot, deleteFile]).finally(() => { this._refresh(); });
    }

    handleCertUploadFinished(event) {
        const files = event.detail.files;
        if (files && files.length > 0) {
            const f = files[0];
            this._certTrackedId = f.contentDocumentId || f.documentId;
        }
        this._enforceVisibility(files, this.detail?.basket?.id);
        if (!this.detail?.certificateUploaded) {
            this._runAction(
                () => markCertificateUploaded({ recordId: this._recordId }),
                'Certificate uploaded. Distributor notified.'
            );
        } else {
            this._showToast('Certificate document added.', 'success');
            this._refresh();
        }
    }

    // ── Certificate Verification Section ─────────────────────────────────────
    @track certProducts = [];
    @track certLoading  = false;

    @track showCertSendBackForm = false;
    @track showCertRejectForm   = false;
    @track _certActionProductId;
    @track certSendBackComments = '';
    @track certRejectComments   = '';

    get isRequestCompleted() { return this.detail?.status === 'Completed'; }
    get hasCertProducts()    { return this.certProducts.length > 0; }
    get hasVerifiedCerts()   { return this.certProducts.some(p => p.isVerified && !p.orderUnlocked); }

    async _loadCertProducts() {
        if (!this._recordId || !this.isRequestCompleted) return;
        this.certLoading = true;
        try {
            const products = await getProductsForRAReview({ requestId: this._recordId });
            this.certProducts = products.map(p => ({
                ...p,
                hasCerts: (p.certificates || []).length > 0,
                isVerified: p.certificateStatus === 'Verified',
                isRejected: p.certificateStatus === 'Rejected',
                isUnderReview: p.certificateStatus === 'Under CRM Review',
                canUnlock: (p.certificateStatus === 'Uploaded' || p.certificateStatus === 'Verified') && !p.orderUnlocked,
                canRAAction: p.certificateStatus === 'Uploaded' && !p.orderUnlocked,
                hasDistributorComments: !!p.distributorComments,
                hasFeedback: !!p.rejectionComments,
                statusClass: this._certStatusClass(p.certificateStatus, p.orderUnlocked)
            }));
            // Pre-populate RA validity edit state from confirmed dates
            const newEdit = {};
            products.forEach(p => {
                if (p.confirmedValidFrom) {
                    const from = new Date(p.confirmedValidFrom);
                    const to   = p.confirmedValidTo ? new Date(p.confirmedValidTo) : null;
                    newEdit[p.productId] = {
                        fromMonth: String(from.getUTCMonth() + 1),
                        fromYear : String(from.getUTCFullYear()),
                        toMonth  : to ? String(to.getUTCMonth() + 1) : '',
                        toYear   : to ? String(to.getUTCFullYear()) : ''
                    };
                }
            });
            this._raValidityEdit = newEdit;
        } catch (e) {
            /* silent */
        } finally {
            this.certLoading = false;
        }
    }

    get certProductsWithValidity() {
        return this.certProducts.map(p => {
            const edit             = this._raValidityEdit[p.productId] || {};
            const hasConfirmed     = !!p.confirmedValidFrom;
            const isEditing        = !hasConfirmed || !!this._raValidityEditing[p.productId];
            return {
                ...p,
                hasConfirmedValidity   : hasConfirmed,
                confirmedValidFromLabel: this._formatMonthYear(p.confirmedValidFrom),
                confirmedValidToLabel  : this._formatMonthYear(p.confirmedValidTo),
                isEditing,
                raFromMonth: edit.fromMonth || '',
                raFromYear : edit.fromYear  || '',
                raToMonth  : edit.toMonth   || '',
                raToYear   : edit.toYear    || ''
            };
        });
    }

    handleEditProductValidity(e) {
        const pid = e.currentTarget.dataset.productId;
        this._raValidityEditing = { ...this._raValidityEditing, [pid]: true };
    }

    handleRaFromMonthChange(e) {
        const pid = e.currentTarget.dataset.productId;
        const cur = this._raValidityEdit[pid] || {};
        this._raValidityEdit = { ...this._raValidityEdit, [pid]: { ...cur, fromMonth: e.detail.value } };
    }

    handleRaFromYearChange(e) {
        const pid = e.currentTarget.dataset.productId;
        const cur = this._raValidityEdit[pid] || {};
        this._raValidityEdit = { ...this._raValidityEdit, [pid]: { ...cur, fromYear: e.detail.value } };
    }

    handleRaToMonthChange(e) {
        const pid = e.currentTarget.dataset.productId;
        const cur = this._raValidityEdit[pid] || {};
        this._raValidityEdit = { ...this._raValidityEdit, [pid]: { ...cur, toMonth: e.detail.value } };
    }

    handleRaToYearChange(e) {
        const pid = e.currentTarget.dataset.productId;
        const cur = this._raValidityEdit[pid] || {};
        this._raValidityEdit = { ...this._raValidityEdit, [pid]: { ...cur, toYear: e.detail.value } };
    }

    async handleConfirmProductValidity(event) {
        const productId = event.currentTarget.dataset.productId;
        const edit = this._raValidityEdit[productId] || {};
        if (!edit.fromMonth || !edit.fromYear || !edit.toMonth || !edit.toYear) {
            this._showToast('Please select From and To month/year before confirming.', 'error');
            return;
        }
        const fromDate = `${edit.fromYear}-${String(edit.fromMonth).padStart(2, '0')}-01`;
        const toLastDay = new Date(parseInt(edit.toYear, 10), parseInt(edit.toMonth, 10), 0).getDate();
        const toDate    = `${edit.toYear}-${String(edit.toMonth).padStart(2, '0')}-${String(toLastDay).padStart(2, '0')}`;
        try {
            await confirmProductValidity({ productId, validFromDate: fromDate, validToDate: toDate });
            const { [productId]: _removed, ...rest } = this._raValidityEditing;
            this._raValidityEditing = rest;
            this._showToast('Product validity confirmed.', 'success');
            await this._loadCertProducts();
        } catch (e) {
            this._showToast(e?.body?.message || 'Failed to confirm validity.', 'error');
        }
    }

    _certStatusClass(status, unlocked) {
        if (unlocked) return 'cv-pill cv-pill-unlocked';
        const map = {
            'Pending Upload':    'cv-pill cv-pill-pending',
            'Uploaded':          'cv-pill cv-pill-uploaded',
            'Under CRM Review':  'cv-pill cv-pill-review',
            'Verified':          'cv-pill cv-pill-verified',
            'Rejected':          'cv-pill cv-pill-rejected'
        };
        return map[status] || 'cv-pill cv-pill-pending';
    }

    @track _showPreview    = false;
    @track _previewLoading = false;
    @track _previewIsImage = false;
    @track _previewDataUrl = '';

    handlePreview(event) {
        event.preventDefault();
        const docId = event.currentTarget.dataset.docId;
        const host  = window.location.hostname.replace('.my.site.com', '.lightning.force.com');
        window.open('https://' + host + '/lightning/r/ContentDocument/' + docId + '/view', '_blank');
    }
    stopPreviewProp(event) { event.stopPropagation(); }

    async handleCertDownload(event) {
        event.preventDefault();
        event.stopPropagation();
        const docId = event.currentTarget.dataset.docId;
        try {
            const data = await getCertFileData({ contentDocumentId: docId });
            const byteChars = atob(data.body);
            const byteArrays = [];
            for (let i = 0; i < byteChars.length; i += 512) {
                const slice = byteChars.slice(i, i + 512);
                const byteNums = new Array(slice.length);
                for (let j = 0; j < slice.length; j++) byteNums[j] = slice.charCodeAt(j);
                byteArrays.push(new Uint8Array(byteNums));
            }
            const blob = new Blob(byteArrays, { type: data.mimeType });
            const url = URL.createObjectURL(blob);
            const anchor = this.template.querySelector('.cert-blob-anchor');
            anchor.href = url;
            anchor.download = data.filename;
            anchor.click();
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => URL.revokeObjectURL(url), 1000);
        } catch (e) {
            this._showToast(e?.body?.message || 'Failed to download certificate.', 'error');
        }
    }

    async handleRaCertRemove(event) {
        const certId = event.currentTarget.dataset.certId;
        try {
            await removeCertificate({ certId });
            this._showToast('Certificate removed.', 'success');
            await this._loadCertProducts();
        } catch (e) {
            this._showToast(e?.body?.message || 'Failed to remove certificate.', 'error');
        }
    }

    handleForwardProductToCRM(event) {
        const productId = event.target.dataset.productId;
        this._runAction(
            () => forwardProductToCRM({ productId }),
            'Certificate forwarded to CRM for verification.',
            () => this._loadCertProducts()
        );
    }

    handleOpenCertSendBack(event) {
        this._certActionProductId = event.target.dataset.productId;
        this.certSendBackComments = '';
        this.showCertSendBackForm = true;
    }

    handleCertSendBackChange(event) {
        this.certSendBackComments = event.detail.value;
    }

    handleCancelCertSendBack() {
        this.showCertSendBackForm = false;
        this._certActionProductId = null;
        this.certSendBackComments = '';
    }

    async handleConfirmCertSendBack() {
        if (!this.certSendBackComments.trim()) {
            this._showToast('Comments are required when sending back a certificate.', 'error');
            return;
        }
        this.actionInProgress = true;
        try {
            await sendBackCertificate({
                productId: this._certActionProductId,
                comments: this.certSendBackComments.trim()
            });
            this._showToast('Certificate sent back to distributor.', 'success');
            this.showCertSendBackForm = false;
            this._certActionProductId = null;
            this.certSendBackComments = '';
            await this._loadCertProducts();
        } catch (e) {
            this._showToast(e?.body?.message || 'Send back failed.', 'error');
        } finally {
            this.actionInProgress = false;
        }
    }

    handleOpenCertReject(event) {
        this._certActionProductId = event.target.dataset.productId;
        this.certRejectComments = '';
        this.showCertRejectForm = true;
    }

    handleCertRejectChange(event) {
        this.certRejectComments = event.detail.value;
    }

    handleCancelCertReject() {
        this.showCertRejectForm = false;
        this._certActionProductId = null;
        this.certRejectComments = '';
    }

    async handleConfirmCertReject() {
        if (!this.certRejectComments.trim()) {
            this._showToast('A reason is required for rejection.', 'error');
            return;
        }
        this.actionInProgress = true;
        try {
            await rejectCertificate({
                productId: this._certActionProductId,
                comments: this.certRejectComments.trim()
            });
            this._showToast('Certificate rejected.', 'success');
            this.showCertRejectForm = false;
            this._certActionProductId = null;
            this.certRejectComments = '';
            await this._loadCertProducts();
        } catch (e) {
            this._showToast(e?.body?.message || 'Rejection failed.', 'error');
        } finally {
            this.actionInProgress = false;
        }
    }

    _stopPropagation(event) {
        event.stopPropagation();
    }

    handleUnlockOrder(event) {
        const productId = event.target.dataset.productId;
        this._runAction(
            () => unlockProductOrder({ productId }),
            'Product order unlocked successfully.',
            () => this._loadCertProducts()
        );
    }

    // ── Reject Registration Request handlers ──────────────────────────────────

    handleOpenReject() {
        this._rejectComments = '';
        this._showRejectModal = true;
    }

    handleRejectCommentsChange(event) {
        this._rejectComments = event.target.value;
    }

    handleCancelReject() {
        this._showRejectModal = false;
        this._rejectComments  = '';
    }

    async handleConfirmReject() {
        if (!this._rejectComments.trim()) {
            this._showToast('A reason is required when rejecting a request.', 'error');
            return;
        }
        this._isRejecting = true;
        try {
            await rejectRegistrationRequest({
                requestId: this._recordId,
                comments : this._rejectComments.trim()
            });
            this._showToast('Request rejected.', 'success');
            this._showRejectModal = false;
            this._rejectComments  = '';
            this._refresh();
        } catch (e) {
            this._showToast(e?.body?.message || 'Failed to reject request.', 'error');
        } finally {
            this._isRejecting = false;
        }
    }

    // ── Return Registration Request handlers ─────────────────────────────────

    handleOpenMainReturn() {
        this._mainReturnComments = '';
        this._showMainReturnModal = true;
    }

    handleMainReturnCommentsChange(event) {
        this._mainReturnComments = event.target.value;
    }

    handleCancelMainReturn() {
        this._showMainReturnModal = false;
        this._mainReturnComments = '';
    }

    async handleConfirmMainReturn() {
        if (!this._mainReturnComments.trim()) {
            this._showToast('A comment is required when returning a request.', 'error');
            return;
        }
        this._isMainReturning = true;
        try {
            await returnRegistrationRequest({
                requestId: this._recordId,
                comments : this._mainReturnComments.trim()
            });
            this._showToast('Request returned to distributor.', 'success');
            this._showMainReturnModal = false;
            this._mainReturnComments  = '';
            this._refresh();
        } catch (e) {
            this._showToast(e?.body?.message || 'Failed to return request.', 'error');
        } finally {
            this._isMainReturning = false;
        }
    }

    // ── Return Additional Request handlers ────────────────────────────────────

    handleOpenReturn(event) {
        this._returnChildId  = event.currentTarget.dataset.childId;
        this._returnComments = '';
        this._showReturnModal = true;
    }

    handleReturnCommentsChange(event) {
        this._returnComments = event.target.value;
    }

    handleCancelReturn() {
        this._showReturnModal = false;
        this._returnChildId  = null;
        this._returnComments = '';
    }

    async handleConfirmReturn() {
        if (!this._returnComments.trim()) {
            this._showToast('A comment is required when returning a request.', 'error');
            return;
        }
        this._isReturning = true;
        try {
            await returnAdditionalRequest({
                childRequestId: this._returnChildId,
                comments      : this._returnComments.trim()
            });
            this._showToast('Request returned to distributor.', 'success');
            this._showReturnModal = false;
            this._returnChildId  = null;
            this._returnComments = '';
            this._refresh();
        } catch (e) {
            this._showToast(e?.body?.message || 'Failed to return request.', 'error');
        } finally {
            this._isReturning = false;
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────────────────

    _runAction(apexFn, successMsg, postFn) {
        this.actionInProgress = true;
        apexFn()
            .then(() => {
                this._showToast(successMsg, 'success');
                if (postFn) postFn();
                this._refresh();
            })
            .catch(err => {
                this._showToast(err?.body?.message ?? 'Action failed.', 'error');
            })
            .finally(() => {
                this.actionInProgress = false;
            });
    }

    _refresh() {
        refreshApex(this._wiredResult);
    }

    _showToast(message, variant) {
        if (this._toastTimer) clearTimeout(this._toastTimer);
        this.toastMessage = message;
        this.toastVariant = variant;
        this._toastTimer = setTimeout(() => { this.toastMessage = null; }, 4000);
    }

    dismissToast() {
        this.toastMessage = null;
    }

    get toastClass() {
        return 'toast-msg ' + (this.toastVariant === 'error' ? 'toast-error' : 'toast-success');
    }
}
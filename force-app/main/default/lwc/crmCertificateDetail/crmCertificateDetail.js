import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getProductsForCRMReview from '@salesforce/apex/CertificateVerificationController.getProductsForCRMReview';
import verifyCertificate    from '@salesforce/apex/CertificateVerificationController.verifyCertificate';
import rejectCertificate    from '@salesforce/apex/CertificateVerificationController.rejectCertificate';
import sendBackCertificate  from '@salesforce/apex/CertificateVerificationController.sendBackCertificate';
import unlockProductOrder   from '@salesforce/apex/CertificateVerificationController.unlockProductOrder';

export default class CrmCertificateDetail extends NavigationMixin(LightningElement) {
    @track _recordId;
    @track products = [];
    @track isLoading = true;
    @track hasError = false;
    @track actionInProgress = false;

    @track showRejectForm = false;
    @track rejectProductId;
    @track rejectComments = '';

    @track showSendBackForm = false;
    @track sendBackProductId;
    @track sendBackComments = '';

    @track toastMessage;
    @track toastVariant = 'success';
    _toastTimer;

    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        const id = pageRef?.state?.recordId ?? pageRef?.attributes?.recordId;
        if (id && id !== this._recordId) {
            this._recordId = id;
            this._load();
        }
    }

    async _load() {
        if (!this._recordId) return;
        this.isLoading = true;
        this.hasError = false;
        try {
            const data = await getProductsForCRMReview({ requestId: this._recordId });
            this.products = data.map(p => ({
                ...p,
                isUnderReview: p.certificateStatus === 'Under CRM Review',
                isVerified: p.certificateStatus === 'Verified',
                isRejected: p.certificateStatus === 'Rejected',
                canUnlock: p.certificateStatus === 'Verified' && !p.orderUnlocked,
                hasCerts: (p.certificates || []).length > 0,
                statusClass: this._statusClass(p.certificateStatus, p.orderUnlocked)
            }));
        } catch (e) {
            this.hasError = true;
        } finally {
            this.isLoading = false;
        }
    }

    _statusClass(status, unlocked) {
        if (unlocked) return 'crm-pill crm-pill-unlocked';
        const map = {
            'Pending':           'crm-pill crm-pill-pending',
            'Uploaded':          'crm-pill crm-pill-uploaded',
            'Under CRM Review':  'crm-pill crm-pill-review',
            'Verified':          'crm-pill crm-pill-verified',
            'Rejected':          'crm-pill crm-pill-rejected'
        };
        return map[status] || 'crm-pill crm-pill-pending';
    }

    get hasProducts() { return this.products.length > 0; }

    get toastClass() {
        return 'toast-msg ' + (this.toastVariant === 'error' ? 'toast-error' : 'toast-success');
    }

    // ── Verify ────────────────────────────────────────────────────────────────
    async handleVerify(event) {
        const productId = event.target.dataset.productId;
        this.actionInProgress = true;
        try {
            await verifyCertificate({ productId });
            this._showToast('Certificate verified successfully.', 'success');
            await this._load();
        } catch (e) {
            this._showToast(e?.body?.message || 'Verification failed.', 'error');
        } finally {
            this.actionInProgress = false;
        }
    }

    // ── Reject ────────────────────────────────────────────────────────────────
    handleOpenReject(event) {
        this.rejectProductId = event.target.dataset.productId;
        this.rejectComments = '';
        this.showRejectForm = true;
    }

    handleRejectCommentsChange(event) {
        this.rejectComments = event.target.value;
    }

    handleCancelReject() {
        this.showRejectForm = false;
        this.rejectProductId = null;
        this.rejectComments = '';
    }

    _stopPropagation(event) {
        event.stopPropagation();
    }

    // ── Send Back ─────────────────────────────────────────────────────────────
    handleOpenSendBack(event) {
        this.sendBackProductId = event.target.dataset.productId;
        this.sendBackComments = '';
        this.showSendBackForm = true;
    }

    handleSendBackCommentsChange(event) {
        this.sendBackComments = event.detail.value;
    }

    handleCancelSendBack() {
        this.showSendBackForm = false;
        this.sendBackProductId = null;
        this.sendBackComments = '';
    }

    async handleConfirmSendBack() {
        if (!this.sendBackComments.trim()) {
            this._showToast('Comments are required when sending back a certificate.', 'error');
            return;
        }
        this.actionInProgress = true;
        try {
            await sendBackCertificate({
                productId: this.sendBackProductId,
                comments: this.sendBackComments.trim()
            });
            this._showToast('Certificate sent back to distributor.', 'success');
            this.showSendBackForm = false;
            this.sendBackProductId = null;
            this.sendBackComments = '';
            await this._load();
        } catch (e) {
            this._showToast(e?.body?.message || 'Send back failed.', 'error');
        } finally {
            this.actionInProgress = false;
        }
    }

    async handleConfirmReject() {
        if (!this.rejectComments.trim()) {
            this._showToast('Please provide a reason for rejection.', 'error');
            return;
        }
        this.actionInProgress = true;
        try {
            await rejectCertificate({
                productId: this.rejectProductId,
                comments: this.rejectComments.trim()
            });
            this._showToast('Certificate rejected.', 'success');
            this.showRejectForm = false;
            this.rejectProductId = null;
            this.rejectComments = '';
            await this._load();
        } catch (e) {
            this._showToast(e?.body?.message || 'Rejection failed.', 'error');
        } finally {
            this.actionInProgress = false;
        }
    }

    // ── Unlock Order ──────────────────────────────────────────────────────────
    async handleUnlockOrder(event) {
        const productId = event.target.dataset.productId;
        this.actionInProgress = true;
        try {
            await unlockProductOrder({ productId });
            this._showToast('Order unlocked successfully.', 'success');
            await this._load();
        } catch (e) {
            this._showToast(e?.body?.message || 'Failed to unlock order.', 'error');
        } finally {
            this.actionInProgress = false;
        }
    }

    handlePreview(event) {
        event.preventDefault();
        const docId = event.currentTarget.dataset.docId;
        const host  = window.location.hostname.replace('.my.site.com', '.lightning.force.com');
        window.open('https://' + host + '/lightning/r/ContentDocument/' + docId + '/view', '_blank');
    }

    // ── Navigation ────────────────────────────────────────────────────────────
    handleBack() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/s/crm-certificate-queue' }
        });
    }

    dismissToast() {
        this.toastMessage = null;
    }

    _showToast(message, variant) {
        if (this._toastTimer) clearTimeout(this._toastTimer);
        this.toastMessage = message;
        this.toastVariant = variant;
        this._toastTimer = setTimeout(() => { this.toastMessage = null; }, 4000);
    }
}
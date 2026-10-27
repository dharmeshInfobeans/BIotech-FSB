import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getRequestDetail  from '@salesforce/apex/LeadershipRequestDetailController.getRequestDetail';
import approveRequest    from '@salesforce/apex/FunctionalHeadActionController.approveRequest';
import sendBack          from '@salesforce/apex/FunctionalHeadActionController.sendBack';
import rejectRequest     from '@salesforce/apex/FunctionalHeadActionController.rejectRequest';

const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

const STATUS_CLASS = {
    'Under Functional Head Review': 'status-pill status-fh',
    'Submitted':                    'status-pill status-submitted',
    'Under Leadership Review':      'status-pill status-leadership',
    'Approved by Leadership':       'status-pill status-approved',
    'Submitted to Regulatory':      'status-pill status-regulatory',
    'Under Regulatory Review':      'status-pill status-regulatory',
    'Completed':                    'status-pill status-completed',
    'Rejected':                     'status-pill status-rejected',
    'Sent Back':                    'status-pill status-sent-back',
};

export default class FunctionalHeadRequestDetail extends NavigationMixin(LightningElement) {

    @api recordId;
    @track detail;
    @track error;
    @track actionInProgress = false;

    @track showSendBackForm  = false;
    @track showRejectForm    = false;
    @track actionComments    = '';

    @track toastMessage;
    @track toastVariant = 'success';
    _toastTimer;
    _wiredResult;

    @wire(CurrentPageReference)
    wiredPageRef(pageRef) {
        if (this.recordId) return;
        const id = pageRef?.attributes?.recordId ?? pageRef?.state?.recordId;
        if (id) this.recordId = id;
    }

    @wire(getRequestDetail, { recordId: '$recordId' })
    wiredDetail(result) {
        this._wiredResult = result;
        if (result.data) {
            this.detail = result.data;
            this.error  = undefined;
        } else if (result.error) {
            this.error  = result.error.body?.message || 'Failed to load request details.';
            this.detail = undefined;
        }
    }

    // ── Computed ──────────────────────────────────────────────────────────────
    get hasDetail()    { return !!this.detail; }
    get isLoading()    { return !this.detail && !this.error; }
    get hasRejection() { return !!this.detail?.rejectionComments; }
    get hasDocTypes()           { return !!this.detail?.documentTypes; }
    get hasDocumentsByProduct() { return (this.detail?.documentsByProduct?.length || 0) > 0; }
    get hasRemarks()   { return !!this.detail?.remarks; }
    get hasChildren()  { return (this.detail?.childRequests?.length || 0) > 0; }
    get childCount()   { return this.detail?.childRequests?.length || 0; }

    get canTakeAction() {
        return this.detail?.status === 'Under Functional Head Review';
    }

    get showActionButtons() {
        return !this.showSendBackForm && !this.showRejectForm;
    }

    get statusClass() {
        return STATUS_CLASS[this.detail?.status] || 'status-pill status-default';
    }

    get formattedSubmittedDate() {
        return this._formatDate(this.detail?.submittedDate);
    }

    get documentTypeList() {
        if (!this.detail?.documentTypes) return [];
        return this.detail.documentTypes.split(';')
            .map((v, i) => ({ key: i, label: v.trim() }))
            .filter(d => d.label);
    }

    get childRequests() {
        return (this.detail?.childRequests || []).map(c => ({
            ...c,
            statusClass:   STATUS_CLASS[c.status] || 'status-pill status-default',
            formattedDate: this._formatDate(c.submittedDate),
        }));
    }

    // ── Navigation ────────────────────────────────────────────────────────────
    handleBack() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/functional-head-queue' }
        });
    }

    handleRefresh() {
        refreshApex(this._wiredResult).catch(e => {
            this.error = e?.body?.message || 'Refresh failed.';
        });
    }

    // ── Approve ───────────────────────────────────────────────────────────────
    handleApprove() {
        this.actionInProgress = true;
        approveRequest({ recordId: this.recordId })
            .then(() => {
                this._showToast('Request approved and forwarded to Leadership.', 'success');
                refreshApex(this._wiredResult);
            })
            .catch(e => { this._showToast(e?.body?.message || 'Approve failed.', 'error'); })
            .finally(() => { this.actionInProgress = false; });
    }

    // ── Send Back ─────────────────────────────────────────────────────────────
    handleOpenSendBack() {
        this.showSendBackForm = true;
        this.showRejectForm  = false;
        this.actionComments  = '';
    }

    handleConfirmSendBack() {
        if (!this.actionComments.trim()) {
            this._showToast('Please provide a reason for sending back.', 'error');
            return;
        }
        this.actionInProgress = true;
        sendBack({ recordId: this.recordId, comments: this.actionComments })
            .then(() => {
                this._showToast('Request sent back to distributor.', 'success');
                this.showSendBackForm = false;
                this.actionComments  = '';
                refreshApex(this._wiredResult);
            })
            .catch(e => { this._showToast(e?.body?.message || 'Send back failed.', 'error'); })
            .finally(() => { this.actionInProgress = false; });
    }

    // ── Reject ────────────────────────────────────────────────────────────────
    handleOpenReject() {
        this.showRejectForm  = true;
        this.showSendBackForm = false;
        this.actionComments  = '';
    }

    handleConfirmReject() {
        if (!this.actionComments.trim()) {
            this._showToast('Please provide a rejection reason.', 'error');
            return;
        }
        this.actionInProgress = true;
        rejectRequest({ recordId: this.recordId, comments: this.actionComments })
            .then(() => {
                this._showToast('Request rejected.', 'success');
                this.showRejectForm = false;
                this.actionComments = '';
                refreshApex(this._wiredResult);
            })
            .catch(e => { this._showToast(e?.body?.message || 'Reject failed.', 'error'); })
            .finally(() => { this.actionInProgress = false; });
    }

    handleCancelForm() {
        this.showSendBackForm = false;
        this.showRejectForm   = false;
        this.actionComments   = '';
    }

    handleCommentsChange(e) { this.actionComments = e.target.value; }

    dismissToast() { this.toastMessage = null; }

    // ── Helpers ───────────────────────────────────────────────────────────────
    _formatDate(dateStr) {
        if (!dateStr) return '—';
        const [year, month, day] = dateStr.split('-');
        return `${day} ${MONTHS[parseInt(month, 10) - 1]} ${year}`;
    }

    _showToast(message, variant) {
        if (this._toastTimer) clearTimeout(this._toastTimer);
        this.toastMessage = message;
        this.toastVariant = variant;
        this._toastTimer  = setTimeout(() => { this.toastMessage = null; }, 4000);
    }

    get toastClass() {
        return 'toast-msg ' + (this.toastVariant === 'error' ? 'toast-error' : 'toast-success');
    }
}
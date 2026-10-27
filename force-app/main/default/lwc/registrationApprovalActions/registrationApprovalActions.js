import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent }      from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { CurrentPageReference }  from 'lightning/navigation';

import getRequestInfo        from '@salesforce/apex/RegistrationApprovalController.getRequestInfo';
import checkFGCodesComplete  from '@salesforce/apex/LeadershipRequestDetailController.checkFGCodesComplete';
import forwardToLeadership   from '@salesforce/apex/RegistrationApprovalController.forwardToLeadership';
import processApproval       from '@salesforce/apex/RegistrationApprovalController.processApproval';
import submitToRegulatory    from '@salesforce/apex/RegistrationApprovalController.submitToRegulatory';
import rejectRequest         from '@salesforce/apex/RegistrationApprovalController.rejectRequest';
import sendBack              from '@salesforce/apex/RegistrationApprovalController.sendBack';
import setOnHold             from '@salesforce/apex/RegistrationApprovalController.setOnHold';
import resumeFromHold        from '@salesforce/apex/RegistrationApprovalController.resumeFromHold';
import resubmitToLeadership  from '@salesforce/apex/RegistrationApprovalController.resubmitToLeadership';

const S = {
    SUBMITTED:          'Submitted',
    LEADERSHIP_REVIEW:  'Under Leadership Review',
    APPROVED:           'Approved by Leadership',
    SUBMITTED_TO_REG:   'Submitted to Regulatory',
    UNDER_REG_REVIEW:   'Under Regulatory Review',
    COMPLETED:          'Completed',
    REJECTED:           'Rejected',
    SENT_BACK:          'Sent Back',
    ON_HOLD:            'On Hold'
};

const FORM = {
    REJECT:    'reject',
    SEND_BACK: 'sendBack'
};

export default class RegistrationApprovalActions extends LightningElement {

    @api recordId;

    @wire(CurrentPageReference)
    wiredPageRef(pageRef) {
        if (this.recordId) return;
        const id = pageRef?.attributes?.recordId ?? pageRef?.state?.recordId;
        if (id) {
            this.recordId = id;
            this._loadInfo();
        }
    }

    // ── State ─────────────────────────────────────────────────────────────────
    @track requestInfo    = null;
    @track isLoading      = false;
    @track isSaving       = false;
    @track loadError      = null;
    @track actionError    = null;

    // Shared inline action form (Reject / Send Back)
    @track showActionForm      = false;
    @track activeFormType      = null;   // FORM.REJECT | FORM.SEND_BACK
    @track actionComments      = '';

    // Confirmation overlays
    @track showApproveConfirm    = false;
    @track showRegulatoryConfirm = false;

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    connectedCallback() {
        this._loadInfo();
    }

    // ── Data load ─────────────────────────────────────────────────────────────
    async _loadInfo() {
        if (!this.recordId) return;
        this.isLoading   = true;
        this.loadError   = null;
        this.actionError = null;
        try {
            this.requestInfo = await getRequestInfo({ recordId: this.recordId });
        } catch (e) {
            this.loadError = this._msg(e);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Stage getters ─────────────────────────────────────────────────────────
    // Submitted OR Under Leadership Review — Leadership acts on both directly
    get isLeadershipStage() {
        const s = this.requestInfo?.status;
        return s === S.SUBMITTED || s === S.LEADERSHIP_REVIEW;
    }
    get isSentBackStage()   { return this.requestInfo?.status === S.SENT_BACK; }
    get isOnHoldStage()     { return this.requestInfo?.status === S.ON_HOLD; }

    get isTerminal() {
        const s = this.requestInfo?.status;
        return s === S.APPROVED
            || s === S.SUBMITTED_TO_REG
            || s === S.UNDER_REG_REVIEW
            || s === S.COMPLETED
            || s === S.REJECTED;
    }

    get terminalIcon() {
        const s = this.requestInfo?.status;
        if (s === S.REJECTED)          return 'utility:error';
        if (s === S.COMPLETED)         return 'utility:check';
        if (s === S.SUBMITTED_TO_REG)  return 'utility:send';
        if (s === S.UNDER_REG_REVIEW)  return 'utility:preview';
        return 'utility:info';
    }

    get terminalClass() {
        const s = this.requestInfo?.status;
        if (s === S.REJECTED)          return 'status-badge badge-rejected';
        if (s === S.COMPLETED)         return 'status-badge badge-completed';
        if (s === S.SUBMITTED_TO_REG)  return 'status-badge badge-regulatory';
        if (s === S.UNDER_REG_REVIEW)  return 'status-badge badge-regulatory';
        return 'status-badge';
    }

    // ── Action form getters ───────────────────────────────────────────────────
    get actionFormLabel() {
        return this.activeFormType === FORM.SEND_BACK
            ? 'Reason for Sending Back'
            : 'Rejection Reason';
    }
    get actionFormPlaceholder() {
        return this.activeFormType === FORM.SEND_BACK
            ? 'Explain what the distributor needs to revise (required)'
            : 'Enter reason for rejection (required)';
    }
    get actionFormConfirmLabel() {
        return this.activeFormType === FORM.SEND_BACK
            ? 'Confirm Send Back'
            : 'Confirm Reject';
    }
    get actionFormConfirmVariant() {
        return this.activeFormType === FORM.SEND_BACK ? 'neutral' : 'destructive';
    }
    get actionFormClass() {
        return this.activeFormType === FORM.SEND_BACK ? 'send-back-form' : 'reject-form';
    }

    // True when any confirmation overlay or inline form is visible
    // (used to hide the default action-button row)
    get showAnyOverlay()        { return this.showApproveConfirm || this.showRegulatoryConfirm || this.showActionForm; }
    get hideAnyOverlay()        { return !this.showAnyOverlay; }
    get hideActionForm()        { return !this.showActionForm; }
    get hideRegulatoryConfirm() { return !this.showRegulatoryConfirm; }

    // ── Approve confirmation ──────────────────────────────────────────────────
    async handleShowApproveConfirm() {
        this.actionError = null;
        this.isSaving    = true;
        try {
            const complete = await checkFGCodesComplete({ requestId: this.recordId });
            if (!complete) {
                this.actionError = 'Please fill in the FG Code for all products before approving.';
                return;
            }
            this.showApproveConfirm = true;
        } catch (e) {
            this.actionError = this._msg(e);
        } finally {
            this.isSaving = false;
        }
    }
    handleCancelConfirm() {
        this.showApproveConfirm = false;
    }

    // ── Regulatory confirmation ───────────────────────────────────────────────
    handleShowRegulatoryConfirm() {
        this.actionError            = null;
        this.showRegulatoryConfirm  = true;
    }
    handleCancelRegulatoryConfirm() {
        this.showRegulatoryConfirm = false;
    }

    // ── Show / hide inline form ───────────────────────────────────────────────
    handleShowReject() {
        this.activeFormType = FORM.REJECT;
        this.actionComments = '';
        this.actionError    = null;
        this.showActionForm = true;
    }
    handleShowSendBack() {
        this.activeFormType = FORM.SEND_BACK;
        this.actionComments = '';
        this.actionError    = null;
        this.showActionForm = true;
    }
    handleActionCommentsChange(e) {
        this.actionComments = e.detail.value;
    }
    handleActionFormCancel() {
        this.showActionForm = false;
        this.activeFormType = null;
        this.actionComments = '';
        this.actionError    = null;
    }
    async handleActionFormConfirm() {
        if (!this.actionComments?.trim()) {
            this.actionError = this.actionFormLabel + ' is required.';
            return;
        }
        this.actionError = null;
        this.isSaving    = true;
        try {
            if (this.activeFormType === FORM.REJECT) {
                await rejectRequest({ recordId: this.recordId, comments: this.actionComments.trim() });
                this._notify('Rejected', 'Request has been rejected.', 'warning');
            } else {
                await sendBack({ recordId: this.recordId, comments: this.actionComments.trim() });
                this._notify('Sent Back', 'Request has been sent back to the distributor.', 'warning');
            }
            this.showActionForm = false;
            this.activeFormType = null;
            this.actionComments = '';
            this._refreshRecord();
            await this._loadInfo();
        } catch (e) {
            this.actionError = this._msg(e);
        } finally {
            this.isSaving = false;
        }
    }

    // ── Forward to Leadership ─────────────────────────────────────────────────
    async handleForwardToLeadership() {
        this.actionError = null;
        this.isSaving    = true;
        try {
            await forwardToLeadership({ recordId: this.recordId });
            this._notify('Forwarded', 'Request forwarded to Leadership for review.', 'success');
            this._refreshRecord();
            await this._loadInfo();
        } catch (e) {
            this.actionError = this._msg(e);
        } finally {
            this.isSaving = false;
        }
    }

    // ── Multi-step approval (Leadership→Management or Management→Approved) ─────
    async handleProcessApproval() {
        this.actionError = null;
        this.isSaving    = true;
        try {
            await processApproval({ recordId: this.recordId });
            const msg = this.requestInfo?.status === S.LEADERSHIP_REVIEW
                ? 'Request forwarded to Management for final approval.'
                : 'Request fully approved by Leadership.';
            this._notify('Approved', msg, 'success');
            this.showApproveConfirm = false;
            this._refreshRecord();
            await this._loadInfo();
        } catch (e) {
            this.actionError = this._msg(e);
        } finally {
            this.isSaving = false;
        }
    }

    // ── Submit to Regulatory ──────────────────────────────────────────────────
    async handleSubmitToRegulatory() {
        this.actionError = null;
        this.isSaving    = true;
        try {
            await submitToRegulatory({ recordId: this.recordId });
            this._notify('Submitted', 'Request submitted to Regulatory team.', 'success');
            this.showRegulatoryConfirm = false;
            this._refreshRecord();
            await this._loadInfo();
        } catch (e) {
            this.actionError = this._msg(e);
        } finally {
            this.isSaving = false;
        }
    }

    // ── On Hold ───────────────────────────────────────────────────────────────
    async handleSetOnHold() {
        this.actionError = null;
        this.isSaving    = true;
        try {
            await setOnHold({ recordId: this.recordId });
            this._notify('On Hold', 'Request placed on hold.', 'info');
            this._refreshRecord();
            await this._loadInfo();
        } catch (e) {
            this.actionError = this._msg(e);
        } finally {
            this.isSaving = false;
        }
    }

    // ── Resume from Hold ──────────────────────────────────────────────────────
    async handleResumeFromHold() {
        this.actionError = null;
        this.isSaving    = true;
        try {
            await resumeFromHold({ recordId: this.recordId });
            this._notify('Resumed', 'Request resumed and returned to CRM queue.', 'success');
            this._refreshRecord();
            await this._loadInfo();
        } catch (e) {
            this.actionError = this._msg(e);
        } finally {
            this.isSaving = false;
        }
    }

    // ── Re-submit Sent Back request to Leadership ─────────────────────────────
    async handleResubmit() {
        this.actionError = null;
        this.isSaving    = true;
        try {
            await resubmitToLeadership({ recordId: this.recordId });
            this._notify('Re-submitted', 'Request re-submitted to Leadership for review.', 'success');
            this._refreshRecord();
            await this._loadInfo();
        } catch (e) {
            this.actionError = this._msg(e);
        } finally {
            this.isSaving = false;
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    _refreshRecord() {
        try {
            getRecordNotifyChange([{ recordId: this.recordId }]);
        } catch (e) {
            // Not available in portal context — safe to ignore
        }
        this.dispatchEvent(new CustomEvent('actioncomplete'));
    }
    _notify(title, message, variant) {
        try {
            this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
        } catch (e) {
            // ShowToastEvent not available in all portal contexts
        }
    }
    _msg(error) {
        if (typeof error === 'string')  return error;
        if (error?.body?.message)       return error.body.message;
        if (error?.message)             return error.message;
        return 'An unexpected error occurred.';
    }
}
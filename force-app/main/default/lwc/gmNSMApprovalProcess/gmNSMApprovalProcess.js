import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import getOpportunityDetails from '@salesforce/apex/initiateCustomerApprovalEmailController.getOpportunityDetails';
import savegmNSMComment from '@salesforce/apex/initiateCustomerApprovalEmailController.savegmNSMComment';
import getAccountFiles from '@salesforce/apex/initiateCustomerApprovalEmailController.getAccountFiles';
import getPublicFileUrl from '@salesforce/apex/initiateCustomerApprovalEmailController.getPublicFileUrl';
import Toast from 'lightning/toast';

export default class GmNSMApprovalProcess extends NavigationMixin(LightningElement) {

    @api recordId;
    @api previewFileId;

    @track account = {};
    @track files = [];
    comments = '';

    @wire(getOpportunityDetails, { recordId: '$recordId' })
    wiredOpp({ data, error }) {
        if (data) {
            this.account = data;
            this.comments = data.gmnsmComment;
            if (data.gmnsmApprove === true || data.gmnsmNotApprove === true) {
                this[NavigationMixin.Navigate]({
                    type: 'comm__namedPage',
                    attributes: { name: 'approvalAlreadyRecorded__c' }
                });
            }
        } else if (error) {
            console.log('GMNSM wire error:', JSON.stringify(error));
        }
    }

    @wire(getAccountFiles, { opportunityId: '$recordId' })
    wiredFiles({ data, error }) {
        if (data) {
            this.files = data;
        } else if (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && !this.recordId) {
            this.recordId = currentPageReference.state?.recordId;
            console.log('RecordId from URL:', this.recordId);
        }
    }

    connectedCallback() {
        console.log('recordId received::', this.recordId);
    }

    handleCommentChange(event) {
        this.comments = event.target.value;
    }

    handleApprove() {
    if (!this.recordId) {
        this.showToast('Error', 'Record Id is missing.', 'error');
        return;
    }

    if (!this.comments?.trim()) {
        this.showToast('Validation', 'GM NSM Comment is required.', 'warning');
        return;
    }

    if (this.account.gmnsmApprove === true || this.account.gmnsmNotApprove === true) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'approvalAlreadyRecorded__c' }
        });
        return;
    }

    savegmNSMComment({
        recordId: this.recordId,
        gmnsmcomments: this.comments.trim(),
        isApproved: true           // ✅ added
    })
    .then(() => {
        Toast.show({ label: 'GM NSM Comment saved successfully.', variant: 'success' }, this);
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'approvalThankYou__c' }
        });
    })
    .catch(error => {
        this.showToast('Error', error?.body?.message || 'Unable to save GM NSM Comment.', 'error');
    });
}

handleReject() {
    if (!this.recordId) {
        this.showToast('Error', 'Record Id is missing.', 'error');
        return;
    }

    if (!this.comments?.trim()) {
        this.showToast('Validation', 'GM NSM Comment is required.', 'warning');
        return;
    }

    if (this.account.gmnsmApprove === true || this.account.gmnsmNotApprove === true) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'approvalAlreadyRecorded__c' }
        });
        return;
    }

    savegmNSMComment({
        recordId: this.recordId,
        gmnsmcomments: this.comments.trim(),
        isApproved: false          // ✅ added
    })
    .then(() => {
        Toast.show({ label: 'GM NSM Approval Rejected successfully.', variant: 'error' }, this);
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'approvalThankYou__c' }
        });
    })
    .catch(error => {
        this.showToast('Error', error?.body?.message || 'Unable to save GM NSM Comment.', 'error');
    });
}

    handlePreview(event) {
        const contentDocumentId = event.currentTarget.dataset.id;

        getPublicFileUrl({ contentDocumentId: contentDocumentId })
            .then(url => {
                if (url) {
                    window.open(url, '_blank');
                } else {
                    this.showToast('Error', 'Unable to get file URL.', 'error');
                }
            })
            .catch(error => {
                this.showToast('Error', error?.body?.message || 'Unable to preview file.', 'error');
            });
    }

    showToast(title, message, variant) {
        Toast.show({
            label: title,
            message: message,
            variant: variant
        }, this);
    }
}
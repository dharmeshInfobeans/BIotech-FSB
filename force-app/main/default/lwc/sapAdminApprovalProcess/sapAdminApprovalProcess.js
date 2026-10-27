import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';

import getOpportunityDetails1 from '@salesforce/apex/initiateCustomerApprovalEmailController.getOpportunityDetails';
import saveSAPCode from '@salesforce/apex/initiateCustomerApprovalEmailController.saveSAPCode';
import getAccountFiles from '@salesforce/apex/initiateCustomerApprovalEmailController.getAccountFiles';
import getPublicFileUrl from '@salesforce/apex/initiateCustomerApprovalEmailController.getPublicFileUrl';
import Toast from 'lightning/toast';
import basePath from '@salesforce/community/basePath';

export default class SapAdminApprovalProcess extends NavigationMixin(LightningElement) {
    
     //@api recordId = 'a0FC3000001K4mrMAC';
    //@api objectApiName = 'Account';

    @api recordId;
    @api previewFileId;
@track files=[];
    @track account = {};
    comments = '';

    @wire(getOpportunityDetails1, { recordId: '$recordId' })
    wiredOpp({ data, error }) {
        if (data) {
            this.account = data;
            this.comments = data.sapCode;
            if (data.sapCode !== null && data.sapCode !== undefined && data.sapCode !== '') {
                this[NavigationMixin.Navigate]({
                    type: 'comm__namedPage',
                    attributes: { name: 'approvalAlreadyRecorded__c' }
                });
            }
        } else if (error) {
            console.log('SAP wire error:', JSON.stringify(error));
            this.showToast('Error', error.body.message, 'error');
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
        const numericOnly = event.target.value.replace(/[^0-9]/g, '');
    this.comments = numericOnly;
    event.target.value = numericOnly; 
    }

    handleApprove() {
        console.log(this.recordId);
        if (!this.recordId) {
            this.showToast('Error', 'Record Id is missing.', 'error');
            return;
        }

        if (!this.comments?.trim()) {
            this.showToast('Validation', 'SAP Code is required.', 'warning');
            return;
        }
 // NEW — numeric + length check
    const trimmedCode = this.comments.trim();
    if (!/^[0-9]{1,10}$/.test(trimmedCode)) {
        this.showToast('Validation', 'SAP Code must be numeric and up to 10 digits.', 'warning');
        return;
    }
       // Already recorded check — SAP Code already exists
            if (this.account.sapCode !== null && 
                this.account.sapCode !== undefined && 
                this.account.sapCode !== '') {
                this[NavigationMixin.Navigate]({
                    type: 'comm__namedPage',
                    attributes: { name: 'approvalAlreadyRecorded__c' }
                });
                return;
            }

        saveSAPCode({
            recordId: this.recordId,
            sapcode: this.comments.trim()
        })
        .then(() => {
            Toast.show({
                label: 'SAP Code saved successfully.',
                variant: 'success'
            }, this);
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: 'approvalThankYou__c'
                }
            });
        })
        .catch(error => {
            console.log('OUTPUT : error ',JSON.stringify(error));
            this.showToast('Error', error?.body?.message || 'Unable to save SAP Code.', 'error');
        });
    }

    handleReject() {
        this.showToast('Info', 'Reject flow not implemented yet.', 'info');
    }

    showToast(title, message, variant) {
        // this.dispatchEvent(
        //     new ShowToastEvent({ title, message, variant })
        // );
         Toast.show({
        label: title,
        message: message,
        variant: variant
    }, this);}

    /* 🔥 FILE PREVIEW (STANDARD SALESFORCE MODAL) */
    // handlePreview(event) {
    //     const contentVersionId = event.currentTarget.dataset.id;

    //     this[NavigationMixin.Navigate]({
    //         type: 'standard__namedPage',
    //         attributes: {
    //             pageName: 'filePreview'
    //         },
    //         state: {
    //             selectedRecordId: contentVersionId
    //         }
    //     });
    // }

    // handlePreview(event) {
    //     const contentDocumentId = event.currentTarget.dataset.id;

    //     const url = `/sfc/servlet.shepherd/document/download/${contentDocumentId}`;
    //     window.open(url, '_blank');
    // }
handlePreview(event) {
    const contentDocumentId = event.currentTarget.dataset.id;
     if (contentDocumentId) {
            // Construct the native Salesforce Shepherd URL to bypass Apex entirely
            const previewUrl = `${basePath}/sfc/servlet.shepherd/document/download/${contentDocumentId}`;

            // Open the file natively in a new browser tab
            window.open(previewUrl, '_blank');
        } else {
            this.showToast('Error', 'Unable to find the document ID.', 'error');
        }
    
    // getPublicFileUrl({ contentDocumentId: contentDocumentId })
    //     .then(url => {
    //         if (url) {
    //             window.open(url, '_blank');
    //         } else {
    //             this.showToast('Error', 'Unable to get file URL.', 'error');
    //         }
    //     })
    //     .catch(error => {
    //         this.showToast('Error', error?.body?.message || 'Unable to preview file.', 'error');
    //     });
}
    // showToast(title, message, variant) {
    //     this.dispatchEvent(
    //         new ShowToastEvent({ title, message, variant })
    //     );
    // }
}
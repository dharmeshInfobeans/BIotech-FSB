import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';

import getOpportunityDetails1 from '@salesforce/apex/initiateCustomerApprovalEmailController.getOpportunityDetails';
import saveZsmComment from '@salesforce/apex/initiateCustomerApprovalEmailController.saveZsmComment';
import getAccountFiles from '@salesforce/apex/initiateCustomerApprovalEmailController.getAccountFiles';
import Toast from 'lightning/toast';
import basePath from '@salesforce/community/basePath';

import getPublicFileUrl from '@salesforce/apex/initiateCustomerApprovalEmailController.getPublicFileUrl';

export default class ZsmApprovalProcess extends NavigationMixin(LightningElement) {

    //@api recordId = 'a0FC3000001K4mrMAC';
    //@api objectApiName = 'Account';

    @api recordId;
    @api previewFileId;
    @track files=[];
    nextOwner='';
    selectedUserId = '';
userOptions = [];
    @track account = {};
    comments = '';

    @wire(getOpportunityDetails1, { recordId: '$recordId' })
    wiredOpp({ data, error }) {
        if (data) {
            this.account = data;
        this.comments = data.zsmComment;  
        if (data.newOwnerName) {
        this.userOptions = [{ label: data.newOwnerName, value: data.newOwnerName }];
        this.selectedUserId = data.newOwnerName;
        this.nextOwner = data.newOwnerName;
    }
        if (data.zsmApprove === true || data.zsmNotApprove === true) {
                this[NavigationMixin.Navigate]({
                    type: 'comm__namedPage',
                    attributes: { name: 'approvalAlreadyRecorded__c' }
                });
            }
        } else if (error) {
            console.log('ZSM wire error:', JSON.stringify(error));
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
        console.log(this.recordId);
        console.log('this.comments2  : ',this.comments );
        if (!this.recordId) {
            this.showToast('Error', 'Record Id is missing.', 'error');
            return;
        }

         if (!this.comments?.trim()) {
            this.showToast('Validation', 'Comment is required.', 'warning');
            return;
        }

        // Already recorded check
        if (this.account.zsmApprove === true || this.account.zsmNotApprove === true) {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: 'approvalAlreadyRecorded__c'
                }
            });
            return;
        }

        saveZsmComment({
            recordId: this.recordId,
            zsmcomments: this.comments.trim(),
            isApproved: true
        })
        .then(() => {
            Toast.show({
                label: 'ZSM Comment saved successfully.',
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
            this.showToast('Error', error?.body?.message || 'Unable to save ZSM Comment.', 'error');
        });
    }

    handleReject() {
       console.log(this.recordId);
       console.log('this.comments23 : ',this.comments );
        if (!this.recordId) {
            this.showToast('Error', 'Record Id is missing.', 'error');
            return;
        }

         if (!this.comments?.trim()) {
            this.showToast('Validation', 'Comment is required.', 'warning');
            return;
        }

        // Already recorded check
        if (this.account.zsmApprove === true || this.account.zsmNotApprove === true) {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: 'approvalAlreadyRecorded__c'
                }
            });
            return;
        }

        saveZsmComment({
            recordId: this.recordId,
            zsmcomments: this.comments.trim(),
            isApproved: false
        })
        .then(() => {
            Toast.show({
                label: 'ZSM Approval Rejected successfully.',
                variant: 'error'
            }, this);
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: 'approvalThankYou__c'
                }
            });
        })
        .catch(error => {
            this.showToast('Error', error?.body?.message || 'Unable to save ZSM Comment.', 'error');
        });
    }

    // showToast(title, message, variant) {
    //     this.dispatchEvent(
    //         new ShowToastEvent({ title, message, variant })
    //     );
    // }
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

        // /*added by ankit*/
        // getPublicFileUrl({ contentDocumentId })
        // .then(url => {
        //     if (url) {
        //         window.open(url, '_blank');
        //     } else {
        //         this.showToast('Error', 'Unable to generate preview URL.', 'error');
        //     }
        // })
        // .catch(error => {
        //     this.showToast(
        //         'Error',
        //         error?.body?.message || 'Preview failed.',
        //         'error'
        //     );
        // });

        
       /* commented by Ankit 
        const url = `/sfc/servlet.shepherd/document/download/${contentDocumentId}`;
        window.open(url, '_blank'); */
    }

    // showToast(title, message, variant) {
    //     this.dispatchEvent(
    //         new ShowToastEvent({ title, message, variant })
    //     );
    // }
}
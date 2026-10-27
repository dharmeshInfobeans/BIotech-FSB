import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import getTeamOfLevelOne from '@salesforce/apex/initiateCustomerApprovalEmailController.getTeamOfLevelOne';
import getOpportunityDetails1 from '@salesforce/apex/initiateCustomerApprovalEmailController.getOpportunityDetails';
import saveRsmComment from '@salesforce/apex/initiateCustomerApprovalEmailController.saveRsmComment';
import getAccountFiles from '@salesforce/apex/initiateCustomerApprovalEmailController.getAccountFiles';
import tempgetOpportunityRecord from '@salesforce/apex/initiateCustomerApprovalEmailController.tempgetOpportunityRecord';
import getPublicFileUrl from '@salesforce/apex/initiateCustomerApprovalEmailController.getPublicFileUrl';
import Toast from 'lightning/toast';
import basePath from '@salesforce/community/basePath';


export default class RsmApprovalProcess extends NavigationMixin(LightningElement) {

    //@api recordId = 'a0FC3000001K4mrMAC';
    //@api objectApiName = 'Account';

    @api recordId;
    @api previewFileId;
    @track tempRecordId = '';

    @track account = {};
    files = [];
    comments = '';
   userOptions = [];
   selectedUserId = '';
   @track isDropdownDisabled = false;

    // @wire(getOpportunityDetails, { recordId: '$recordId' })
    // wiredOpp({ data, error }) {
    //     if (data) {
    //         console.log('working');
    //         this.account = data;
    //         this.comments = data.rsmComment;
    //         console.log('OUTPUT for getOpportunityDetails data ');
    //     } else if (error) {
    //         this.showToast('Error', error.body.message, 'error');
    //     }
    // }
    // @wire(getTeamOfLevelOne, { recordId: '$recordId' })
    // wireUserTeamList({ data, error }) {
    //     if (data) {
    //         this.userOptions = data.map(user => {
    //             const label = user.Title_Internal_Use__c  ? `${user.Name} (${user.Title_Internal_Use__c})`  : user.Name;

    //             return {  label: label, value: user.Id };
    //         });
    //         console.log('userOptions',this.userOptions);
    //     } else if (error) {
    //         this.userOptions = [];
    //         console.error('Apex Error:', error?.body?.message || error?.message);
    //     }
    // }
    @wire(getTeamOfLevelOne, { recordId: '$recordId' })
wireUserTeamList({ data, error }) {
    if (data) {
        this.userOptions = data.users.map(user => {
            const label = user.Title_Internal_Use__c
                ? `${user.Name} (${user.Title_Internal_Use__c})`
                : user.Name;
            return { label: label, value: user.Id };
        });

        this.isDropdownDisabled = data.disableDropdown;

        if (data.ownerIdToSelect) {
            this.selectedUserId = data.ownerIdToSelect;
        }

        console.log('userOptions', this.userOptions);
        console.log('disableDropdown', this.isDropdownDisabled);
    } else if (error) {
        this.userOptions = [];
        this.isDropdownDisabled = false;
        console.error('Apex Error:', error?.body?.message || error?.message);
    }
}
    handleUserChange(event) {
        this.selectedUserId = event.detail.value;
        console.log('Selected User Id:', this.selectedUserId);
    }
    @wire(getOpportunityDetails1, { recordId: '$recordId' })
    wireAcc({ data, error }) {
        if (data) {
            this.account = data;
            this.comments = data?.rsmComment;
            if (data.rsmApprove === true || data.rsmNotApprove === true) {
                this[NavigationMixin.Navigate]({
                    type: 'comm__namedPage',
                    attributes: { name: 'approvalAlreadyRecorded__c' }
                });
            }
        } else if (error) {
            console.log('RSM wire error:', JSON.stringify(error));
        }
    }


    @wire(getAccountFiles, { opportunityId: '$recordId' })
    wiredFiles({ data, error }) {
        if (data) {
            this.files = data;
            console.log('OUTPUT for getAccountFiles data ');

        } else if (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }


    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        try {
            // console.log('currentPageReference 1', currentPageReference?.state);
            if (currentPageReference && !this.recordId) {
                this.recordId = currentPageReference.state?.recordId;

                console.log('currenct record id on', this.recordId);
                // console.log('currentPageReference 2', currentPageReference?.state)
                // //this.recordId = currentPageReference.state?.c__recordId;
                // this.recordId = currentPageReference.state?.recordId;
                // // if(this.recordId) this.loadOpportunityDetails();
                // console.log('RecordId from URL3:', this.recordId, currentPageReference);
            }
        } catch (error) {
            console.log('error on record Id', error);
        }

    }

    connectedCallback() {
        tempgetOpportunityRecord()
            .then(result => {
                console.log('Apex Result chanes:', result);
            })
            .catch(error => {
                console.error('Apex Error:', error);
            });
        console.log('recordId received::', this.recordId);
    }

    handleCommentChange(event) {
        this.comments = event.target.value;
    }

    handleApprove() {
        // Already recorded check
        if (this.account.rsmApprove === true || this.account.rsmNotApprove === true) {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: 'approvalAlreadyRecorded__c'
                }
            });
            return;
        }
      if (!this.selectedUserId) {
    Toast.show({
        label: 'Select Sales Team Mapping...',
        variant: 'warning'
    }, this);
    return;
}


        try {
            saveRsmComment({
                recordId: this.recordId,
                rsmcomments: this.comments.trim(),
                isApproved: true,
                userId:this.selectedUserId
            })
            .then(() => {
                console.log('OUTPUT : >>>>> ');
                Toast.show({
                    label: 'RSM Comment saved successfully.',
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
                this.showToast('Error', error?.body?.message || 'Unable to save RSM Comment.', 'error');
            });
        } catch (error) {
            console.log('Error while saving :', error.message);
        }
    }

    handleReject() {
        // this.showToast('Info', 'Reject flow not implemented yet.', 'info');
        console.log('test1', this.recordId);
        console.log('comment1', this.comments);
        // Already recorded check
        if (this.account.rsmApprove === true || this.account.rsmNotApprove === true) {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: 'approvalAlreadyRecorded__c'
                }
            });
            return;
        }

        saveRsmComment({
            recordId: this.recordId,
            rsmcomments: this.comments.trim(),
            isApproved: false,
             userId:null
        })
        .then(() => {
            Toast.show({
                label: 'RSM Approval Rejected successfully.',
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
            this.showToast('Error', error?.body?.message || 'Unable to save RSM Comment.', 'error');
        });
    }

    showToast(title, message, variant) {
        // this.dispatchEvent(
        //     new ShowToastEvent({ title, message, variant })
        // );
         Toast.show({
        label: title,
        message: message,
        variant: variant
    }, this);
    }

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
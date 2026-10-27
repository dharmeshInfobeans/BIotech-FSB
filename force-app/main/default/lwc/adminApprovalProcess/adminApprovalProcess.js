import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getKycData from '@salesforce/apex/Bio_uploadKYCDocument.getRecords';
import sendEmailOnUpload from '@salesforce/apex/Bio_uploadKYCDocument.sendEmailOnUpload';
import uploadFileAsGuest from '@salesforce/apex/initiateCustomerApprovalEmailController.uploadFileAsGuest';
import resubmitRecord from '@salesforce/apex/initiateCustomerApprovalEmailController.resubmitRecord';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';

import getOpportunityDetails1 from '@salesforce/apex/initiateCustomerApprovalEmailController.getOpportunityDetails';
import saveAdminComment from '@salesforce/apex/initiateCustomerApprovalEmailController.saveAdminComment';
import getAccountFiles from '@salesforce/apex/initiateCustomerApprovalEmailController.getAccountFiles';
import getPublicFileUrl from '@salesforce/apex/initiateCustomerApprovalEmailController.getPublicFileUrl';
import basePath from '@salesforce/community/basePath';

import Toast from 'lightning/toast';

export default class AdminApprovalProcess extends NavigationMixin(LightningElement) {

    //@api recordId = 'a0FC3000001K4mrMAC';
    //@api objectApiName = 'Account';

    @api recordId;
    @api sendForCustomer=false;
    @api previewFileId;
    @track files = [];
    @track account = {};
    @track documents = [];
    wiredFilesResult;
    isUploading = false;
    nextOwner='';
    selectedUserId = '';
userOptions = [];
    get adminapprove() {
        console.log('this.account.adminNotApprove', this.account.adminNotApprove);
        return this.account.adminNotApprove;
    }
    get adminReadOnlyComment(){
        return this.account?.adminComment || null;
    }
    get getAccountId() {
        console.log('account Id', this.account?.accountId);
        return this.account?.accountId || null;
    }
    //  files = [];
    comments = '';

    @wire(getOpportunityDetails1, { recordId: '$recordId' })
    wiredOpp({ data, error }) {
        if (data) {

            this.account = data;
            this.comments = data.adminComment;
            console.log(' this.account', this.account);
             if (data.newOwnerName) {
        this.userOptions = [{ label: data.newOwnerName, value: data.newOwnerName }];
        this.selectedUserId = data.newOwnerName;
        this.nextOwner = data.newOwnerName;
    }
            if (data.adminApprove === true || (data.adminNotApprove == false &&  this.sendForCustomer)) {
                this[NavigationMixin.Navigate]({
                    type: 'comm__namedPage',
                    attributes: { name: 'approvalAlreadyRecorded__c' }
                });
            }
        } else if (error) {
            console.log('Admin wire error:', JSON.stringify(error));
        }
        console.log('data', this.account);
    }

    // @wire(getAccountFiles, { opportunityId: '$recordId' })
    // wiredFiles({ data, error }) {
    //     if (data) {

    //         this.files = data;
    //     } else if (error) {
    //         this.showToast('Error', error.body.message, 'error');
    //     }
    // }
    @wire(getAccountFiles, { opportunityId: '$recordId' })
    wiredFiles(result) {
        // 2. Store the entire result for refreshApex
        this.wiredFilesResult = result;

        // 3. Destructure data and error from the result
        const { data, error } = result;

        if (data) {
            this.files = data;
        } else if (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }
    get acceptedFormats() {
        return ['.pdf', '.png', '.jpg', '.jpeg'];
    }

    get resubmitDisabled() {
        if (!this.documents || !this.documents.length) return false;
        return this.documents.some(doc => {
            if (!doc.isRequired) return false;
            const hasNumber = !!(doc.documentNumber && doc.documentNumber.trim());
            const hasFile = !!doc.fileName || this.hasExistingFile(doc);
            return !hasNumber || !hasFile;
        });
    }

    // A required document only needs a freshly picked file if it doesn't already
    // have one linked to the Account (Account.Already_Uploaded__c is never actually
    // set anywhere in the org, so it can't be used as that signal - the real files
    // list from getAccountFiles is).
    hasExistingFile(doc) {
        return !!(this.files && this.files.some(f => f.title === doc.title));
    }

    // Rows for the resubmit table, annotated with whether a file already exists
    // on the Account so the "already on file" indicator can show instead of
    // forcing every required document to be re-picked.
    get documentRows() {
        return (this.documents || []).map(doc => ({
            ...doc,
            hasExistingFile: !doc.fileName && this.hasExistingFile(doc)
        }));
    }

    handleDocumentNumberChange(event) {
        const docId = event.target.dataset.id;
        const value = event.target.value || '';
        this.documents = this.documents.map(doc => {
            if (doc.id === docId) {
                return { ...doc, documentNumber: value };
            }
            return doc;
        });
    }

    fetchKycDocuments() {
        // Prevent calling if recordId isn't ready yet
        if (!this.recordId) return;

        getKycData({ recordId: this.recordId })
            .then(data => {
                console.log('OUTPUT : data', data);
                const list = data.KycData || [];

                // Transform the Apex data into the format the HTML expects
                this.documents = list.map(row => {
                    return {
                        id: row.Id,
                        title: row.MasterLabel, // Assuming MasterLabel holds the title text
                        isRequired: row.IsRequired,
                        documentNumber: row.DocumentNumber || ''
                    };
                });
            })
            .catch(error => {
                console.error('Error loading KYC data', error);
                this.showToast('Error', 'Unable to load KYC metadata.', 'error');
            });
    }

    // Stages the picked file (base64 + name) on the row only. Nothing is sent to
    // Apex here - the actual upload happens for every staged row when Re-Submit
    // is clicked, together with that row's document number.
    handleFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;

        const documentId = event.target.name;
        const currentDoc = this.documents.find(doc => doc.id === documentId);
        const docTitle = currentDoc.title;
        const extension = file.name.split('.').pop();
        const fullFileName = `${docTitle}.${extension}`;

        const reader = new FileReader();
        reader.onload = () => {
            // Strip the metadata prefix (e.g., "data:image/jpeg;base64,")
            const base64 = reader.result.split(',')[1];
            this.documents = this.documents.map(doc => {
                if (doc.id === documentId) {
                    return {
                        ...doc,
                        fileName: file.name,
                        pendingBase64: base64,
                        pendingFullFileName: fullFileName
                    };
                }
                return doc;
            });
        };
        reader.readAsDataURL(file);
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && !this.recordId) {
            console.log('currentPageReference.state?.recordId;',currentPageReference.state);
            this.recordId = currentPageReference.state?.recordId;
            this.sendForCustomer=currentPageReference.state?.sendForCustomer || false;
            console.log('RecordId from URL:', this.recordId);
        }
    }

    connectedCallback() {
        console.log('recordId received::', this.recordId);
        this.fetchKycDocuments();
    }

    handleCommentChange(event) {
        this.comments = event.target.value;
    }

    handleApprove() {
        console.log(this.recordId);
        console.log('this.comments12 : ', this.comments);

        if (!this.recordId) {
            this.showToast('Error', 'Record Id is missing.', 'error');
            return;
        }

        if (!this.comments?.trim()) {
            this.showToast('Validation', 'Comment is required.', 'warning');
            return;
        }

        // Already recorded check
        if (this.account.adminApprove === true || this.account.adminNotApprove === true) {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: 'approvalAlreadyRecorded__c'
                }
            });
            return;
        }

        saveAdminComment({
            recordId: this.recordId,
            admincomments: this.comments.trim(),
            isApproved: true
        })
            .then(() => {
                Toast.show({
                    label: 'Admin Comment saved successfully.',
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
                this.showToast('Error', error?.body?.message || 'Unable to save Admin Comment.', 'error');
            });
    }

    handleReject() {
        console.log(this.recordId);
        console.log('this.comments12 : ', this.comments);

        if (!this.recordId) {
            this.showToast('Error', 'Record Id is missing.', 'error');
            return;
        }

        if (!this.comments?.trim()) {
            this.showToast('Validation', 'Comment is required.', 'warning');
            return;
        }

        // Already recorded check
        if (this.account.adminApprove === true || this.account.adminNotApprove === true) {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: 'approvalAlreadyRecorded__c'
                }
            });
            return;
        }

        saveAdminComment({
            recordId: this.recordId,
            admincomments: this.comments.trim(),
            isApproved: false
        })
            .then(() => {
                Toast.show({
                    label: 'Admin Approval Rejected successfully.',
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
                this.showToast('Error', error?.body?.message || 'Unable to save Admin Comment.', 'error');
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
            variant: variant,
            mode: 'dismissible'
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

    //     handlePreview(event) {
    //     const contentDocumentId = event.currentTarget.dataset.id;

    //     getPublicFileUrl({ contentDocumentId: contentDocumentId })
    //         .then(url => {
    //             if (url) {
    //                 window.open(url, '_blank');
    //             } else {
    //                 this.showToast('Error', 'Unable to get file URL.', 'error');
    //             }
    //         })
    //         .catch(error => {
    //             this.showToast('Error', error?.body?.message || 'Unable to preview file.', 'error');
    //         });
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
    }
    async handleResubmit() {
        if (this.resubmitDisabled) {
            this.showToast('Validation', 'Please enter the document number and upload the file for every required document.', 'warning');
            return;
        }
        if (this.isUploading) return;

        this.isUploading = true;
        try {
            // Send every row that either has a newly picked file OR a document number
            // to save - not just rows with a new file. Otherwise a document that
            // already has a file (no pendingBase64) never gets its number saved.
            const uploads = this.documents
                .filter(doc => doc.pendingBase64 || (doc.documentNumber && doc.documentNumber.trim()))
                .map(doc =>
                    uploadFileAsGuest({
                        base64Data: doc.pendingBase64 || null,
                        documentTitle: doc.title,
                        fileName: doc.pendingFullFileName || null,
                        accountId: this.getAccountId,
                        documentNumber: doc.documentNumber
                    })
                );
            await Promise.all(uploads);
            if (uploads.length) {
                await refreshApex(this.wiredFilesResult);
            }

            await resubmitRecord({ recordId: this.recordId });

            Toast.show({
                label: 'Successfully resubmitted.',
                variant: 'success'
            }, this);

            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: 'approvalAlreadyRecorded__c'
                }
            });
        } catch (error) {
            console.error('Error in handleResubmit:', error);

            let errorMessage = 'An unknown error occurred.';
            if (error.body && error.body.message) {
                errorMessage = error.body.message;
            } else if (error.message) {
                errorMessage = error.message;
            }

            Toast.show({
                label: errorMessage,
                variant: 'error'
            }, this);
        } finally {
            this.isUploading = false;
        }
    }
    // showToast(title, message, variant) {
    //     this.dispatchEvent(
    //         new ShowToastEvent({ title, message, variant })
    //     );
}
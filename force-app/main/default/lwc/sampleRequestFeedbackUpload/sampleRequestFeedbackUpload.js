import { LightningElement, wire, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { refreshApex } from '@salesforce/apex';
import uploadFile from '@salesforce/apex/sampleRequestFeedbackUploadController.uploadFile';
import getDataTable from '@salesforce/apex/sampleRequestFeedbackUploadController.getDataTable';
import deleteContentDocument from '@salesforce/apex/sampleRequestFeedbackUploadController.deleteContentDocument';
import getCustomLabels from '@salesforce/apex/sampleRequestFeedbackUploadController.getCustomLabels';
// import submitForApproval from '@salesforce/apex/sampleRequestFeedbackUploadController.submitForApproval';



export default class SampleRequestFeedbackUpload extends NavigationMixin(LightningElement) {
    @api recordId;
    @track fileCount = 0;
    @track tabledata = [];
    @track approvalPending = false;
    @track stagedFiles = [];
    @track isSubmitting = false;
    @track labels = {};

    @wire(getCustomLabels)
    getLabels({ data, error }) {
        if (data) { this.labels = data; }
        if (error) console.log('error', error);
    }

    get hasStagedFiles() {
        return this.stagedFiles.length > 0;
    }

    get submitDisabled() {
        return !this.hasStagedFiles || this.isSubmitting;
    }

    get columns() {
        return [
            {
                label: this.labels.Sr_No__c,
                fieldName: 'srNo',
                type: 'number',
                initialWidth: 80,
                cellAttributes: { alignment: 'center' }
            },
            {
                label: this.labels.Sample_Feedback__c,
                type: 'button',
                typeAttributes: {
                    label: { fieldName: 'Title' },
                    name: 'openDocument',
                    variant: 'base'
                }
            },
            { label: this.labels.Approval_Status__c, fieldName: 'Approval_Status__c' },
            { label: this.labels.Comment__c, fieldName: 'Comments__c' },
        ];
    }

    // @wire(getDataTable, { recordId: '$recordId' })
    // wiredData(result) {
    //     this.wiredTableResult = result;
    //     if (result.data) {
    //         this.tabledata = result.data.map((row, index) => ({
    //             srNo: index + 1,
    //             Id: row.Id,
    //             Title: row.Name,
    //             Approval_Status__c: row.Approval_Status__c,
    //         }));
    //         this.fileCount = this.tabledata.length;

    //         // ── Set approvalPending ─────────────────────
    //         this.approvalPending = this.tabledata.some(
    //             row => row.Approval_Status__c === 'Pending' || row.Approval_Status__c === 'Approved'
    //         );

    //     } else if (result.error) {
    //         console.error(result.error);
    //     }
    // }

    @wire(getDataTable, { recordId: '$recordId' })
wiredData(result) {
    this.wiredTableResult = result;
    if (result.data) {
        this.tabledata = result.data.map((row, index) => ({
            srNo: index + 1,
            Id: row.Id,
            Title: row.Name,
            Approval_Status__c: row.Approval_Status__c,
            Comments__c: row.Comments__c,

        }));
        this.fileCount = this.tabledata.length;

        this.approvalPending = this.tabledata.some(
            row => row.Approval_Status__c === 'Pending' || row.Approval_Status__c === 'Approved'
        );

        // ← fire event with latest status to parent
        const latestStatus = this.tabledata.length > 0
            ? this.tabledata[this.tabledata.length - 1].Approval_Status__c
            : 'Pending';

        this.dispatchEvent(new CustomEvent('statusupdate', {
            detail: {
                recordId: this.recordId,
                status: latestStatus || 'Pending'
            }
        }));
    } else if (result.error) {
        console.error(result.error);
    }
}
    refreshModal() {
        if (this.wiredTableResult) {
            refreshApex(this.wiredTableResult);
        }
    }
    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
        // this.dispatchEvent(new CloseActionScreenEvent());
        // setTimeout(() => {
        //     window.location.reload();
        // }, 500)

    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'openDocument') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: row.Id,
                    actionName: 'view'
                }
            });
        }
    }

    handleUploadFinished(event) {
        const newFiles = event.detail.files.map(item => ({
            documentName: item.name,
            contentVersionId: item.contentVersionId,
            documentId: item.documentId
        }));
        this.stagedFiles = [...this.stagedFiles, ...newFiles];
    }

    handlePreviewFile(event) {
        const documentId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state: {
                selectedRecordId: documentId
            }
        });
    }

    handleRemoveStagedFile(event) {
        const documentId = event.currentTarget.dataset.id;
        const fileToRemove = this.stagedFiles.find(f => f.documentId === documentId);
        if (!fileToRemove) {
            return;
        }
        deleteContentDocument({ documentId })
            .then(() => {
                this.stagedFiles = this.stagedFiles.filter(f => f.documentId !== documentId);
            })
            .catch(error => {
                console.error('Remove error:', error);
                this.showToast('Error', error.body?.message || 'Unable to remove file', 'error');
            });
    }

    handleSubmit() {
        if (!this.hasStagedFiles || this.isSubmitting) {
            return;
        }
        this.isSubmitting = true;
        uploadFile({
            uplodedFile: JSON.stringify(this.stagedFiles),
            recordId: this.recordId
        })
            .then(() => {
                this.showToast('Success', 'Feedback submitted for approval', 'success');
                this.stagedFiles = [];
                this.refreshModal();
                this.handleClose();
            })
            .catch(error => {
                console.error('Upload error:', error);
                this.showToast('Error', error.body?.message || 'File upload failed', 'error');
            })
            .finally(() => {
                this.isSubmitting = false;
            });
    }

    // handleSubmitApproval() {
    //     submitForApproval({ recordId: this.recordId })
    //         .then(() => {
    //             this.showToast('Success', 'Submitted for approval', 'success');
    //             // optionally refresh the datatable
    //             return refreshApex(this.wiredTableResult);
    //         })
    //         .catch(error => {
    //             this.showToast('Error', error.body?.message, 'error');
    //         });
    // }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
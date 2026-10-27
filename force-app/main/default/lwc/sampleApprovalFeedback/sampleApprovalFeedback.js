import { LightningElement, api, wire, track } from 'lwc';
import getPendingApprovals from '@salesforce/apex/SampleRequestApprovalController.getPendingApprovals';
import processApproval from '@salesforce/apex/SampleRequestApprovalController.processApproval';
import updateFeedbackComment from '@salesforce/apex/SampleRequestApprovalController.updateFeedbackComment';
import getCustomLabels from '@salesforce/apex/SampleRequestApprovalController.getCustomLabels';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import removeRow from '@salesforce/resourceUrl/removeRow';
import { refreshApex } from '@salesforce/apex';

export default class SampleApprovalFeedback extends NavigationMixin(LightningElement) {
    @api recordId;
    @track data = [];
    @track isLoading = true;
    @track draftValues = [];
    @track labels = {};

    wiredResult;

    @wire(getCustomLabels)
    getLabels({ data, error }) {
        if (data) { this.labels = data; }
        if (error) console.log('error', error);
    }

    get columns() {
        return [
            { label: this.labels.Sr_No__c, fieldName: 'serialNo', type: 'number', cellAttributes: { alignment: 'center' }, initialWidth: 70, },
            { label: this.labels.Preview__c, type: 'button-icon', initialWidth: 80, typeAttributes: { iconName: 'utility:preview', name: 'view_file', title: 'View File', variant: 'border-filled', alternativeText: 'View' } },
            { label: this.labels.Line_Item_Name__c, fieldName: 'lineItemUrl', type: 'url', typeAttributes: { label: { fieldName: 'lineItemName' }, target: '_blank' } },
            { label: this.labels.Product__c, fieldName: 'brand' },
            { label: this.labels.Model__c, fieldName: 'model' },
            { label: this.labels.Diaptor__c, fieldName: 'diaptor' },
            { label: this.labels.Comment__c, fieldName: 'comment', type: 'text', editable: { fieldName: 'isCommentEditable' } },
            // { type: 'action', typeAttributes: { rowActions: [{ label: 'Approve', name: 'approve' }, { label: 'Reject', name: 'reject' }] } }
            { label: this.labels.Approve__c, type: 'button', initialWidth: 120, typeAttributes: { label: this.labels.Approve__c, name: 'approve', variant: { fieldName: 'approveVariant' } } },
            { label: this.labels.Reject__c, type: 'button', initialWidth: 120, typeAttributes: { label: this.labels.Reject__c, name: 'reject', variant: { fieldName: 'rejectVariant' } } }
        ];
    }

    get hasData() {
        // return this.data && this.data.length > 0;
        return true;
    }
    get showSubmitButton() {
        return this.data.some(row => row.selectedAction);
    }

    renderedCallback() {
        if (this.isCssLoaded) {
            return;
        }
        this.isCssLoaded = true;

        loadStyle(this, removeRow)
            .then(() => {
                console.log('CSS loaded');
            })
            .catch(error => {
                console.error('Error loading CSS', error);
            });
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.state.c__recordId;
            console.log('RecordId from URL:', this.recordId);
        }
    }

    @wire(getPendingApprovals, { headerId: '$recordId' })
    wiredData(result) {
        this.wiredResult = result;
        this.isLoading = true;
        if (result.data) {
            this.data = result.data.map(row => {
                return { ...row, lineItemUrl: '/' + row.lineItemId, selectedAction: null, approveVariant: 'neutral', rejectVariant: 'neutral', isCommentEditable: false };
            });
            this.isLoading = false;
        } else if (result.error) {
            console.error(result.error);
            this.isLoading = false;
        }
    }
    handleCellChange(event) {
        this.draftValues = event.detail.draftValues;

        this.draftValues.forEach(draft=>{
            const index =  this.data.findIndex(item=>item.workItemId === draft.workItemId);
            if(index !== -1){
                this.data = [...this.data.slice(0, index), {...this.data[index], comment: draft.comment}, ...this.data.slice(index+1)];
            }
        });
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'view_file') {
            if (row.fileId) {
                this[NavigationMixin.Navigate]({ type: 'standard__namedPage', attributes: { pageName: 'filePreview' }, state: { selectedRecordId: row.fileId } });
            } else {
                this.showToast('Info', 'No file attached', 'info');
            }
            return;
        }
        let isDeselecting = false;

        this.data = this.data.map(item => {
            if (item.workItemId === row.workItemId) {

                if (actionName === 'approve') {
                    if (item.selectedAction === 'Approve') {
                        isDeselecting = true;
                        return { ...item, selectedAction: null, approveVariant: 'neutral', rejectVariant: 'neutral', isCommentEditable: false, comment: '' };
                    }

                    return { ...item, selectedAction: 'Approve', approveVariant: 'success', rejectVariant: 'neutral', isCommentEditable: true };
                }

                if (actionName === 'reject') {

                    if (item.selectedAction === 'Reject') {
                        isDeselecting = true;
                        return { ...item, selectedAction: null, approveVariant: 'neutral', rejectVariant: 'neutral', isCommentEditable: false, comment: '' };
                    }

                    return { ...item, selectedAction: 'Reject', approveVariant: 'neutral', rejectVariant: 'destructive', isCommentEditable: true };
                }
            }
            return item;
        });
        if (isDeselecting) {
        this.draftValues = this.draftValues.filter(d => d.workItemId !== row.workItemId);
    }
    }

    handleSubmit() {

        // if (this.draftValues && this.draftValues.length > 0) {
        //     this.draftValues.forEach(draft => {
        //         const index = this.data.findIndex(item => item.workItemId === draft.workItemId);
        //         if (index !== -1) {
        //             this.data[index].comment = draft.comment;
        //         }
        //     });
        // }
        const selectedRows = this.data.filter(row => row.selectedAction);

        if (selectedRows.length === 0) {
            this.showToast('Error', 'Please select at least one record', 'error');
            return;
        }

        const rejectedWithoutComment = selectedRows.filter(row => row.selectedAction === 'Reject' && !row.comment?.trim());
        if (rejectedWithoutComment.length > 0) {
            const names = rejectedWithoutComment.map(row => row.lineItemName).join(', ');
            this.showToast('Error', `Comment is required for rejected item(s): ${names}`, 'error');
            return;
        }

        this.isLoading = true;

        const promises = selectedRows.map(row => {

            return Promise.all([
                updateFeedbackComment({
                    feedbackId: row.feedbackId,
                    comment: row.comment || ''
                }),
                processApproval({
                    workItemId: row.workItemId,
                    action: row.selectedAction,
                    comments: row.comment || (row.selectedAction + ' via LWC')
                })
            ]);
        });

        Promise.all(promises)
            .then(() => {
                this.showToast('Success', 'Processed successfully', 'success');
                this.draftValues = [];
                return refreshApex(this.wiredResult);
            })
            .then(() => {
                if (!this.data || this.data.length === 0) {
                    this.handleClose();
                }
            })
            .catch(error => {
                this.showToast('Error', error?.body?.message || 'Error processing approval', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    handleClose() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage', attributes: { recordId: this.recordId, objectApiName: 'Sample_Request_Header__c', actionName: 'view' }
        });
    }
}
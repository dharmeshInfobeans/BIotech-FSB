import { LightningElement, api, track, wire } from 'lwc';
import getLineItem from '@salesforce/apex/sampleRequestFeedbackUploadController.getLineItem';
import getLatestFeedbackStatus from '@salesforce/apex/sampleRequestFeedbackUploadController.getLatestFeedbackStatus';
import isSampleRequestOwner from '@salesforce/apex/sampleRequestFeedbackUploadController.isSampleRequestOwner';
import getCustomLabels from '@salesforce/apex/sampleRequestFeedbackUploadController.getCustomLabels';
import { CloseActionScreenEvent } from 'lightning/actions';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
export default class SampleRequestFeedBack extends NavigationMixin(LightningElement) {
    @api recordId;
    @track showModal = false;
    @track selectedRecordId;
    @track records = [];
    @track headerError;
    @track isLoading = true;
    @track wiredStatusResult;
    @track isOwner = false;
    @track labels = {};

    @wire(getCustomLabels)
    getLabels({ data, error }) {
        if (data) { this.labels = data; }
        if (error) console.log('error', error);
    }

    get baseColumns() {
        return [
            { label: this.labels.Sr_No__c, fieldName: 'srNo', type: 'number', fixedWidth: 80, cellAttributes: { alignment: 'center' } },
            {
                label: this.labels.Name__c,
                fieldName: 'recordUrl',
                type: 'url',
                typeAttributes: {
                    label: { fieldName: 'name' },
                    target: '_blank'
                }
            },
            { label: this.labels.Product__c, fieldName: 'Brand__c', type: 'text' },
            { label: this.labels.Model__c, fieldName: 'Group_Name__c', type: 'text' },
            { label: this.labels.Diaptor__c, fieldName: 'Diaptor__c', type: 'text' },
            { label: this.labels.Batch_No__c, fieldName: 'Batch_Number__c', type: 'text' },
            { label: this.labels.Serial_No__c, fieldName: 'Serial_Number__c', type: 'text' },
            { label: this.labels.Status__c, fieldName: 'feedbackStatus', type: 'text' }
        ];
    }

    get addFeedbackColumn() {
        return {
            label: this.labels.Add_Feedback__c,
            type: 'button-icon',
            typeAttributes: {
                iconName: 'utility:upload',
                name: 'upload',
                title: this.labels.Upload_Feedback__c,
                variant: 'brand'
            }
        };
    }

    get columns() {
        return this.isOwner ? [...this.baseColumns, this.addFeedbackColumn] : this.baseColumns;
    }

    @wire(isSampleRequestOwner, { recordId: '$recordId' })
    wiredIsOwner({ data, error }) {
        if (data !== undefined) {
            this.isOwner = data;
        } else if (error) {
            this.isOwner = false;
        }
    }

    @track statusMap = {};   // ← add this at top with other tracked props

    @wire(getLatestFeedbackStatus, { recordId: '$recordId' })
    wiredStatus(result) {
        this.wiredStatusResult = result;
        if (result.data) {
            console.log('OUTPUT FeedBack : ', result.data);
            this.statusMap = { ...result.data };
            // re-merge into records if already loaded
            if (this.records.length > 0) {
                this.records = this.records.map(rec => ({
                    ...rec,
                    // feedbackStatus: this.statusMap[rec.id] ?? 'Pending'
                    feedbackStatus: this.statusMap[rec.id] ? this.statusMap[rec.id] === 'Pending' ? 'Approval Pending' : this.statusMap[rec.id] : 'Pending'
                }));
            }
        }
    }

    @wire(CurrentPageReference)
    getStateParameters(pageRef) {
        if (!this.recordId && pageRef?.state?.c__recordId) {
            this.recordId = pageRef.state.c__recordId;
        }
    }

    @wire(getLineItem, { recordId: '$recordId' })
    wiredHeaders({ data, error }) {
        this.isLoading = true;
        console.log('OUTPUT : ', data);
        if (data) {
            this.records = data.map((rec, index) => ({
                id: rec.Id,
                srNo: index + 1,
                name: rec.Name,
                recordUrl: '/' + rec.Id,
                Brand__c: rec.Brand__c,
                Group_Name__c: rec.Group_Name__c,
                Diaptor__c: rec.Diaptor__c,
                Batch_Number__c: rec.Batch_Number__c,
                Serial_Number__c: rec.Serial_Number__c,
                feedbackStatus: this.statusMap[rec.Id] ? this.statusMap[rec.Id] === 'Pending' ? 'Approval Pending' : this.statusMap[rec.Id] : 'Pending'
            }));
            this.headerError = undefined;
            this.isLoading = false;
        } else if (error) {
            this.headerError = error?.body?.message || 'Failed to load records';
            this.records = [];
            this.isLoading = false;
        }
    }

    get noRecords() {
        return !this.records || this.records.length === 0;
    }

    handleRowAction(event) {
        const row = event.detail.row;
        this.selectedRecordId = row.id;
        this.showModal = true;
    }

    handleCloseChild() {
        this.showModal = false;
        this.selectedRecordId = null;
        if (this.wiredStatusResult) {
            refreshApex(this.wiredStatusResult);  // ← re-fetch latest status
        }
    }

    get parentModalClass() {
        return `slds-modal__container${this.showModal ? ' modal-blurred' : ''}`;
    }


    // handleClose() {
    //     this.showModal = false;
    //     this.selectedRecordId = null;

    //     // 🔥 closes quick action panel
    //     this.dispatchEvent(new CloseActionScreenEvent());
    // }

    handleClose() {
        try {
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (e) { }

        if (this.recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage', attributes: { recordId: this.recordId, objectApiName: 'Sample_Request_Header__c', actionName: 'view' }
            });
        }
    }
}
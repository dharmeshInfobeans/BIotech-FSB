import { LightningElement, wire, api, track } from 'lwc';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';
import { RefreshEvent } from 'lightning/refresh';
import getExistingComments from '@salesforce/apex/CustomApprovalProcessController.getExistingComments';
import updateApproverComments from '@salesforce/apex/CustomApprovalProcessController.updateApproverComments';
import isUserApprover from '@salesforce/apex/CustomApprovalProcessController.isUserApprover';
import getCounts from '@salesforce/apex/CustomApprovalProcessController.getCounts';
import getApprovedQuantityForProduct from '@salesforce/apex/CustomApprovalProcessController.getApprovedQuantityForProduct';
import callApprovalProcess from '@salesforce/apex/CustomApprovalProcessController.callApprovalProcess';
import getFiles from '@salesforce/apex/CustomApprovalProcessController.getFiles';
import { loadStyle } from 'lightning/platformResourceLoader';
import removeRow from '@salesforce/resourceUrl/removeRow';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import isCountryAdmin from '@salesforce/apex/CustomApprovalProcessController.isCountryAdmin';
import getCmdFile from '@salesforce/apex/CustomApprovalProcessController.getCmdFile';
import deleteCmdFile from '@salesforce/apex/CustomApprovalProcessController.deleteCmdFile';
import { refreshApex } from '@salesforce/apex';
import uploadChunkForAdmin from '@salesforce/apex/CustomApprovalProcessController.uploadChunkForAdmin';
import getCustomLabels from '@salesforce/apex/CustomApprovalProcessController.getCustomLabels';


export default class CustomApprovalProcess extends NavigationMixin(LightningElement) {
    @api recordId;
    @track labels = {};

    @wire(getCustomLabels)
    getLabels({ data, error }) {
        if (data) { this.labels = data; }
        if (error) console.log('error', error);
    }

    get columns() {
        return [
            { label: this.labels.Sr_No__c, fieldName: 'serialNumber', type: 'text', initialWidth: 80 },
            { label: `${this.labels.Comment__c || ''}*`, fieldName: 'GSM_Comments__c', type: 'text', editable: { fieldName: 'isEditable' }, required: true },
            { label: this.labels.Product__c, fieldName: 'Brand__c', initialWidth: 90, },
            { label: this.labels.Model__c, fieldName: 'Group_Name__c', initialWidth: 90, },
            { label: this.labels.Diaptor__c, fieldName: 'Diaptor__c', initialWidth: 90, },
            { label: this.labels.Quantity__c, fieldName: 'Product_Quantity__c', type: 'number', cellAttributes: { alignment: 'left' }, initialWidth: 100, },
            { label: this.labels.Backup__c, fieldName: 'backupDisplay', type: 'text', initialWidth: 90, },
            {
                label: this.labels.View_Info__c, type: 'button-icon', initialWidth: 80,
                typeAttributes: { iconName: 'utility:info', name: 'existing_comment', title: 'Track record', variant: 'bare', alternativeText: 'Information', size: 'large' }
            }
        ];
    }

    @track filePreviewLink = null;

    data = [];
    showCommentsModal = false;
    selectedProductId;
    commentsData = [];
    pendingComments = [];
    draftValues = [];
    isLoading = true;
    hasFiles = false;
    commentMap = {};
    userRole = null;
    approvedFeedbackCount = 0;
    pendingLineItemCount = 0;
    accountId;
    contactId;
    createdById;
    selectedQuantity = 0;
    isCurrentUserApprover = false;
    isCountryAdmin = false;
    adminFileExists = false;
    dataErrors = {};
    cmdFileName = '';
    stagedFile = null;
    stagedFileName = '';

    chunkSize = 750000;
    fileId = '';
    startPosition = 0;

    get commentColumns() {
        return [
            { label: this.labels.Comment__c, fieldName: 'GSM_Comments__c', initialWidth: 275 },
            { label: this.labels.Approver_Name__c, fieldName: 'ApproverName', initialWidth: 130 },
            { label: this.labels.Role__c, fieldName: 'Role__c', initialWidth: 200 },
            { label: this.labels.Status__c, fieldName: 'Approval_Status__c', initialWidth: 100 },
            { label: this.labels.Date__c, fieldName: 'Approval_Date__c', initialWidth: 140 }
        ];
    }

    gsmComment = '';
    showNewComment = false;
    showExistingComments = false;

    // ─── Lifecycle ───────────────────────────────────────────────────────────

    connectedCallback() {
        this.checkFiles();
        this.checkIsCountryAdmin();
    }

    renderedCallback() {
        if (this.isCssLoaded) return;
        this.isCssLoaded = true;
        loadStyle(this, removeRow)
            .then(() => console.log('CSS loaded'))
            .catch(error => console.error('Error loading CSS', error));
    }


    get displayFileName() {
        return this.stagedFile ? this.stagedFileName : this.cmdFileName;
    }


        @wire(getCounts, { contactId: '$contactId', createdById : '$createdById' })
        wiredCounts({ error, data }) {
            if (data) {
                console.log('OUTPUT :createdById ',this.createdById);
                this.approvedFeedbackCount = data.approvedFeedbackCount;
                this.pendingLineItemCount = data.pendingLineItemCount;
            } else if (error) {
                console.error('Error fetching counts:', error);
            }
        }

    wiredCmdFileResult;

    @wire(getCmdFile, { headerId: '$recordId' })
    wiredCmdFile(result) {
        this.wiredCmdFileResult = result;
        const { data, error } = result;
        if (data) {

            const dbFileExists = data.length > 0;
            if (dbFileExists) {
                this.adminFileExists = true;
                this.cmdFileName = data[0].Title || data[0].ContentDocument?.Title || 'report.pdf';
            } else if (!this.stagedFile) {
                this.adminFileExists = false;
                this.cmdFileName = '';
            }
        } else if (error) {
            console.error(error);
        }
    }

    @wire(getRelatedListRecords, {
        parentRecordId: '$recordId',
        relatedListId: 'Sample_Request_Line_Items__r',
        fields: [
            'Sample_Request_Line_Item__c.Product_M__c',
            'Sample_Request_Line_Item__c.Brand__c',
            'Sample_Request_Line_Item__c.Group_Name__c',
            'Sample_Request_Line_Item__c.Diaptor__c',
            'Sample_Request_Line_Item__c.Product_Quantity__c',
            'Sample_Request_Line_Item__c.Is_Backup__c',
            'Sample_Request_Line_Item__c.Sample_Request_Header__r.Opportunity__r.Account__c',
            'Sample_Request_Line_Item__c.Sample_Request_Header__r.Opportunity__r.Contact__c',
            'Sample_Request_Line_Item__c.Sample_Request_Header__c',
            'Sample_Request_Line_Item__c.CreatedById'
        ]
    })
    wiredLineItems(result) {
        this.wiredLineItemsResult = result;
        const { error, data } = result;
        if (data) {
            const productMap = new Map();

            data.records.forEach(record => {
                const productId = record.fields.Product_M__c.value;
                const quantity = record.fields.Product_Quantity__c.value || 0;
                const brand = record.fields.Brand__c.value;
                const model = record.fields.Group_Name__c.value;
                const diaptor = record.fields.Diaptor__c.value;
                const backup = record.fields.Is_Backup__c.value;
                 // const uniqueKey = backup ? record.id : productId;
 const uniqueKey = `${productId}_${backup}`;

                if (!this.accountId) {
                    this.accountId = record.fields.Sample_Request_Header__r.value?.fields.Opportunity__r.value?.fields.Account__c.value;
                }
                if (!this.contactId) {
                    this.contactId = record.fields.Sample_Request_Header__r.value?.fields.Opportunity__r.value?.fields.Contact__c.value;
                }
                if (!this.createdById) {
                    this.createdById = record.fields.CreatedById.value;
                }

                // if (!backup && productMap.has(uniqueKey)) {
                    if (productMap.has(uniqueKey)) {
                    productMap.get(uniqueKey).Product_Quantity__c += quantity;
                } else {
                    productMap.set(uniqueKey, {
                        Id: record.id,
                        lineItemId: record.id,
                        itemUrl: `/lightning/r/Sample_Request_Line_Item__c/${record.id}/view`,
                        Brand__c: brand,
                        Group_Name__c: model,
                        Diaptor__c: diaptor,
                        Product_Quantity__c: quantity,
                        GSM_Comments__c: '',
                        Is_Backup__c: backup,
                        backupDisplay: backup ? '✅' : '❌',
                        isEditable: false
                    });
                }
            });

            this.data = Array.from(productMap.values()).map((row, index) => ({ ...row, serialNumber: index + 1 }));

            this.data.forEach(row => {
                if (row.Is_Backup__c) {
                    row.isEditable = false;
                    return;
                }
                isUserApprover({ lineItemId: row.lineItemId })
                    .then(result => {
                        if (result) {
                            this.isCurrentUserApprover = true;
                            this.userRole = result;
                            row.isEditable = true;
                        } else {
                            row.isEditable = false;
                        }
                        this.data = [...this.data];
                    })
                    .catch(error => console.error(error));
            });

            this.isLoading = false;
        } else if (error) {
            console.error('Error fetching line items', JSON.stringify(error));
            this.isLoading = false;
        }
    }

    checkFiles() {
        getFiles({ recordId: this.recordId })
            .then(result => {
                this.hasFiles = result.files && result.files.length > 0;
                this.isFileUploadMandatory = result.isFileUploadMandatory;
                this.dispatchEvent(new RefreshEvent());

                if (this.isFileUploadMandatory && !this.hasFiles) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'File Required',
                        message: 'The sales rep hasn\'t uploaded the file yet. Please upload the file first to proceed.',
                        variant: 'warning',
                        mode: 'sticky'
                    }));
                }
            })
            .catch(error => {
                console.error('Error checking files:', error);
                this.hasFiles = false;
            });
    }

    checkIsCountryAdmin() {
        isCountryAdmin({ headerId: this.recordId })
            .then(result => { this.isCountryAdmin = result; })
            .catch(error => console.error('Error: COUNTRY ADMIN', error));
    }

    triggerFileInput() {
        this.refs.fileInput.click();
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = () => {
            this.stagedFileName = file.name;
            this.stagedFile = { base64: reader.result.split(',')[1], name: file.name };
            this.adminFileExists = true;
        };
        reader.readAsDataURL(file);
        console.log('reader on load ', JSON.stringify(reader));
        console.log('file on uploD', URL.createObjectURL(file));
        this.filePreviewLink = URL.createObjectURL(file);
    }


    // uploadChunks(base64Contents, fileName) {
    //     const chunk = base64Contents.substring(this.startPosition, this.startPosition + this.chunkSize);

    //     return uploadChunkForAdmin({
    //         headerId: this.recordId,
    //         base64Chunk: chunk,
    //         fileName: fileName,
    //         fileId: this.fileId
    //     }).then(result => {
    //         this.fileId = result;
    //         this.startPosition += this.chunkSize;

    //         if (this.startPosition < base64Contents.length) {
    //             return this.uploadChunks(base64Contents, fileName);
    //         }
    //         return refreshApex(this.wiredCmdFileResult);
    //     });
    // }
// In uploadChunks — skip chunking, send full base64 at once
uploadChunks(base64Contents, fileName) {
    return uploadChunkForAdmin({
        headerId: this.recordId,
        base64Chunk: base64Contents, // ← FULL file, no splitting
        fileName: fileName,
        fileId: ''
    }).then(() => {
        this.fileId = '';
        this.startPosition = 0;
        return refreshApex(this.wiredCmdFileResult);
    });
}

    handleDeleteCmdFile() {
        if (this.stagedFile) {
            this.stagedFile = null;
            this.stagedFileName = '';
            this.adminFileExists = false;
            return;
        }

        getCmdFile({ headerId: this.recordId })
            .then(result => {
                if (result.length > 0) {
                    const contentDocumentId = result[0].ContentDocumentId;
                    return deleteCmdFile({ contentDocumentId });
                }
            })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Deleted', message: 'File deleted successfully.', variant: 'success' }));
                this.adminFileExists = false;
                this.cmdFileName = '';
                return refreshApex(this.wiredCmdFileResult);
            })
            .catch(error => {
                console.error(error);
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: error.body?.message || 'Delete failed', variant: 'error' }));
            });
    }


    handlePreviewFiles() {
        getFiles({ recordId: this.recordId })
            .then(result => {
                const files = result.files;
                if (files && files.length > 0) {
                    const fileIds = files.map(file => file.ContentDocumentId);
                    this[NavigationMixin.Navigate]({
                        type: 'standard__namedPage',
                        attributes: { pageName: 'filePreview' },
                        state: { recordIds: fileIds.join(','), selectedRecordId: fileIds[0] }
                    });
                } else {
                    this.dispatchEvent(new ShowToastEvent({ title: 'No Files', message: 'No files attached to this record.', variant: 'warning' }));
                }
            })
            .catch(error => console.error('Error fetching files:', error));
    }

    handleCmdFileView() {

        const link = this.template.querySelector('.hidden-link');
        if (link) {
            link.click();
        }
        getCmdFile({ headerId: this.recordId })
            .then(result => {
                if (result.length > 0) {
                    const fileIds = result.map(file => file.ContentDocumentId);
                    this[NavigationMixin.Navigate]({
                        type: 'standard__namedPage',
                        attributes: { pageName: 'filePreview' },
                        state: { recordIds: fileIds.join(','), selectedRecordId: fileIds[0] }
                    });
                } else {
                    // this.dispatchEvent(new ShowToastEvent({ title: 'No Files', message: 'No files attached', variant: 'warning' }));
                }
            })
            .catch(error => console.error(error));
    }


    handleClick(event) {
        if (this.isProcessing) return;
        this.isProcessing = true;

        const statusValue = event.target.dataset.action === 'approve' ? 'Approved' : 'Rejected';

        const nonBackupItems = this.data.filter(row => !row.Is_Backup__c);
        const missingComments = nonBackupItems.filter(
            row => !this.commentMap[row.lineItemId] || this.commentMap[row.lineItemId].trim() === ''
        );

        if (this.isFileUploadMandatory && !this.hasFiles) {
            this.isProcessing = false;
            this.dispatchEvent(new ShowToastEvent({
                title: 'File Required',
                message: 'The sales rep hasn\'t uploaded the file yet. Please upload the file first to proceed.',
                variant: 'error'
            }));
            return;
        }

        const cmdFileReady = this.stagedFile || (this.adminFileExists && !this.stagedFile && this.cmdFileName);
        if (this.userRole === 'CMD' && !cmdFileReady) {
            this.isProcessing = false;
            this.dispatchEvent(new ShowToastEvent({ title: 'File Required', message: 'Please upload the file before proceeding.', variant: 'error' }));
            return;
        }

        if (missingComments.length > 0) {
            this.isProcessing = false;
            let rowErrors = {};
            missingComments.forEach(row => {
                rowErrors[row.Id] = { title: 'Missing Comment', messages: ['Comment is required before approval.'], fieldNames: ['GSM_Comments__c'] };
            });
            this.dataErrors = { rows: rowErrors };
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Please add comments for all non-backup products before approval.', variant: 'error' }));
            return;
        }

        this.dataErrors = {};
        this.isLoading = true;

        const uploadPromise = this.stagedFile
            ? (() => {
                this.startPosition = 0;
                this.fileId = '';
                return this.uploadChunks(this.stagedFile.base64, this.stagedFile.name);
            })()
            : Promise.resolve();

        uploadPromise
            .then(() => {
                this.stagedFile = null;
                // One call for all line items (parallel calls raced each other and the late ones threw)
                if (nonBackupItems.length === 0) return Promise.resolve();
                return updateApproverComments({
                    headerId: this.recordId,
                    commentsByLineItem: Object.fromEntries(
                        nonBackupItems.map(item => [item.lineItemId, this.commentMap[item.lineItemId]])
                    ),
                    status: statusValue
                });
            })
            .then(() => {
                if (statusValue === 'Approved') {
                    const lineItemIds = nonBackupItems.map(item => item.lineItemId);
                    return callApprovalProcess({ lineItemIds, recordId: this.recordId });
                }
                return Promise.resolve();
            })
            .then(() => {
                this.isLoading = false;
                this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: `All requests ${statusValue} successfully.`, variant: 'success' }));
                this.dispatchEvent(new RefreshEvent());
                this.dispatchEvent(new CustomEvent('close'));
                this.closeModal();
                setTimeout(() => location.reload(), 500);
            })
            .catch(error => {
                console.error('Error:', error);
                this.isLoading = false;
                this.isProcessing = false;
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: error.body?.message || 'Something went wrong', variant: 'error' }));
            });
    }

    handleDraftSave(event) {
        this.dataErrors = {};
        const drafts = event.detail.draftValues;

        drafts.forEach(draft => {
            const index = this.data.findIndex(item => item.lineItemId === draft.lineItemId);
            if (index !== -1) {
                this.data[index] = { ...this.data[index], ...draft };
                this.commentMap[this.data[index].lineItemId] = draft.GSM_Comments__c;
            }
        });

        this.data = [...this.data];
        this.draftValues = [];
        this.showCommentsModal = false;
    }

    loadApprovedQuantity() {
        getApprovedQuantityForProduct({ lineItemId: this.selectedProductId })
            .then(result => { this.selectedQuantity = result; })
            .catch(error => console.error('Error fetching approved quantity:', error));
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        this.selectedProductId = row.lineItemId;
        this.selectedQuantity = row.Product_Quantity__c;

        if (actionName === 'existing_comment') {
            this.showExistingComments = true;
            this.showNewComment = false;
            this.loadExistingComments();
            this.loadApprovedQuantity();
        }

        if (actionName === 'comment') {
            this.showNewComment = true;
            this.showExistingComments = false;
            this.gsmComment = this.commentMap[this.selectedProductId] || '';
            this.loadApprovedQuantity();
            this.showCommentsModal = true;
        }
    }

    loadExistingComments() {
        getExistingComments({ lineItemId: this.selectedProductId })
            .then(result => {
                this.commentsData = result.map(record => ({
                    Id: record.Id,
                    GSM_Comments__c: record.GSM_Comments__c,
                    ApproverName: record.Approver_Name__r ? record.Approver_Name__r.Name : '',
                    Role__c: record.Role__c,
                    Approval_Status__c: record.Approval_Status__c,
                    Approval_Date__c: record.Approval_Date__c
                }));
                this.showExistingComments = true;
                this.showCommentsModal = true;
            })
            .catch(error => console.error(error));
    }

    handleCommentChange(event) {
        this.gsmComment = event.target.value;
        this.commentMap[this.selectedProductId] = this.gsmComment;
    }

    handleCellChange(event) {
        const updatedFields = event.detail.draftValues;
        updatedFields.forEach(draft => {
            const lineItemId = draft.Id || draft.lineItemId;
            if (lineItemId && draft.GSM_Comments__c !== undefined) {
                this.commentMap[lineItemId] = draft.GSM_Comments__c;
            }
        });
    }

    saveComments() {
        if (this.showNewComment) {
            this.commentMap[this.selectedProductId] = this.gsmComment;
            this.pendingComments = [{
                Sample_Request_Line_Item__c: this.selectedProductId,
                GSM_Comments__c: this.gsmComment
            }];
        }
        this.showNewComment = false;
        this.showCommentsModal = false;
    }

    closeModal() {
        this.showCommentsModal = false;
    }

    handleClose() {
        try { this.dispatchEvent(new CloseActionScreenEvent()); } catch (e) { }
        if (this.recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: this.recordId, objectApiName: 'Sample_Request_Header__c', actionName: 'view' }
            });
        }
    }
}
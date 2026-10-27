import { LightningElement, api, track, wire } from 'lwc';
import updateFileTitle from '@salesforce/apex/OpportunityAddProductController.updateFileTitle';
import getUploadedDocumentTitles from '@salesforce/apex/OpportunityAddProductController.getUploadedDocumentTitles';
import updateOpportunity from '@salesforce/apex/OpportunityAddProductController.updateOpportunity';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {NavigationMixin} from 'lightning/navigation'


export default class EquipmentOppDocumentUploader extends NavigationMixin(LightningElement) {
      @api recordId;
    @track documentMap = new Map([
  ['Bundle Calculator', { Id: '', index: 1, title: 'Bundle Calculator', status: false, documentPreview:true }],
  ['Doctor’s Letter', { Id: '', index: 2, title: 'Doctor’s Letter', status: false, documentPreview:true }],
  ['Vendor Quotation', { Id: '', index: 3, title: 'Vendor Quotation', status: false, documentPreview:true }]

]);
@track documents=[];


    connectedCallback() {
        console.log('recordId',);
        //this.checkExistingFiles();
    }
    get acceptedFormats() {
        return ['.jpg','.jpeg','.png','.pdf', '.xls','.xlsx','.csv'];
        // .jpg, .jpeg, .png, .pdf
    }
    @wire(getUploadedDocumentTitles, {recordId: '$recordId'})
    wiredResult({data, error}){ 
        if(data){ 
            for (const [title, apexId] of Object.entries(data)) {
                const doc = this.documentMap.get(title);
                if (doc) {
                    doc.Id = apexId;
                    doc.status = true;
                    doc.documentPreview =false;
                    
                    this.documentMap.set(title, { ...doc }); // update Map
                }
            }
            this.documents = Array.from(this.documentMap.values());
            console.log('documents',this.documents);
        }
        if(error){ 
            console.log(error)
        }
    }
    /**
     * 
     *********************************************************
    @Method Name    : checkExistingFiles
    @author         : Varish Patil
    @description    : Calls Apex to check if Aadhar and PAN files
                are already uploaded for the current record.
    @date           : 30-12-2025 
    @return         : void
    *********************************************************
    */
    checkExistingFiles() {


        getUploadedDocumentTitles({ recordId: this.recordId })
            .then(data => {
                let tempDoc = [];
                if (data) {
                    this.documents.forEach(element => {
                        let tempObj = { ...element };
                        console.log('element', element);
                        data.forEach(ele => {
                            if (ele == element.title) {
                                tempObj.status = true;

                            }

                        })
                        tempDoc.push(tempObj);

                    });
                    this.documents = tempDoc;
                }
            }).catch(error => {
                console.log('error 001: ', error);
            })

        //  this.aadharUploaded = titles.includes('Aadhar');
        //  this.panUploaded = titles.includes('PAN');

    }


    /**
     *********************************************************
    @Method Name    : handleUploadFinished
    @author         :  Varish Patil
    @description    : Handles file upload and updates the title,opportunity
    @date           : 30-12-2025  
    @param          : event - Upload event
    @return         : void
    *********************************************************
    */
    async handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        const docTitle = event.target.dataset.title;
        
        if (uploadedFiles.length > 0) {
            const contentDocumentId = uploadedFiles[0].documentId;

            try {
                this.showToast(`${docTitle} Uploaded`, `${docTitle} has been uploaded successfully.`, 'success');

                console.log('uploadedFiles', uploadedFiles);
                console.log('docTitle', docTitle);
                await updateFileTitle({ contentDocumentId, newTitle: docTitle });
                let documentStatusUpdate = this.documents.find(doc => doc.title == docTitle);
                if (documentStatusUpdate) {
                    documentStatusUpdate.status = true;
                    documentStatusUpdate.documentPreview =false;
                    documentStatusUpdate.Id=contentDocumentId;

                }
            } catch (error) {
                this.showToast(`Error Occured`, `Error while uploading ${docTitle} .`, 'error');
                console.error('Error updating file title', error);
            }
        }
        if (uploadedFiles.length > 0) {
            updateOpportunity({ recordId: this.recordId, titleName: docTitle })
                .then(result => {
                    console.log('successfully update');

                });
        }
    }


 /**
     *********************************************************
    @Method Name    : previewHandler
    @author         : Varish Patil
    @description    : Handles preview of file to show file on preview button click redirect to preview screen of.
    @date           : 30-12-2025 
    @param          : event - preview event
    @return         : void
    *********************************************************
    */
    previewHandler(event){
        console.log(event.target.dataset.id);
        this[NavigationMixin.Navigate]({ 
            type:'standard__namedPage',
            attributes:{ 
                pageName:'filePreview'
            },
            state:{ 
                selectedRecordId: event.target.dataset.id
            }
        })
    }
    /**
     *********************************************************
    @Method Name    : showToast
    @author         : Varish Patil
    @description    : Used to dispatch toast message either success/Error
    @date           : 30-12-2025 
    @param          : title,message,varant
    @return         : none
    *********************************************************
    */
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant // 'success', 'error', 'warning', 'info'
            // mode: 'dismissable' 
        });
        this.dispatchEvent(evt);
    }
}
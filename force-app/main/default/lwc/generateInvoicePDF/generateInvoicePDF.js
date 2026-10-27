import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getBase64String from '@salesforce/apex/GenerateInvoicePDFController.getBase64String';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class GenerateInvoicePDF extends NavigationMixin(LightningElement) {
    @api recordId;
    error;
    isLoading = false;

    connectedCallback() {
        this.isLoading = true;
        console.log('Starting callout.');

        getBase64String({ recordId: this.recordId })
            .then(invoice => {
                console.log('Invoice--->', invoice);
                if (invoice.status_Code == 1) {
                    //console.log('Got response' + invoice.base64);
                    try {
                        this.convertBase64ToPDF(invoice.base64);
                        const closeAuraEvent = new CustomEvent('closemodal', {
                            detail: {}
                        });
                        this.dispatchEvent(closeAuraEvent);
                        this.isLoading = false;
                    } catch (error) {
                        console.error(error);
                    }
                } else {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error!',
                        message: invoice.message,
                        variant: 'error'
                    }));
                    this.isLoading = false;
                }
            })
            .catch(error => {
                console.error('Error in callout:', error);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error!',
                    message: 'An error occurred while generating the PDF.',
                    variant: 'error'
                }));
                this.isLoading = false;
            });
    }

    convertBase64ToPDF(base64String) {
        try {
            const binaryString = atob(base64String);
            const uint8Array = new Uint8Array(binaryString.length);
            for (let i = 0; i < binaryString.length; i++) {
                uint8Array[i] = binaryString.charCodeAt(i);
            }
            const blob = new Blob([uint8Array], { type: "application/pdf" });
            const urlPDF = URL.createObjectURL(blob);
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: urlPDF
                }
            })


            // // Generate URL for a Lightning page to display the PDF
            // this[NavigationMixin.GenerateUrl]({
            //     type: 'standard__namedPage',
            //     attributes: {
            //         pageName: 'filePreview'
            //     },
            //     state: {
            //         contentId: 'file-sfdc',
            //         recordIds: this.recordId,
            //         version: '1.0',
            //         title: 'Invoice PDF'
            //     }
            // }).then(url => {
            //     // Redirect to the Lightning page to display the PDF
            //     window.location.href = `${url}?isdtp=p1&sfdcIFrameHost=web`;
            // });
        } catch (error) {
            console.error(error);
            this.isLoading = false;
            throw new Error('Error converting base64 to PDF');
        }
    }
}
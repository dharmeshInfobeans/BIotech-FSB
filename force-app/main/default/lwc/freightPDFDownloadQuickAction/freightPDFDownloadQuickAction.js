import { LightningElement, api, track } from 'lwc';
import downloadFreightPDF from '@salesforce/apex/FreightPDFDownloader.downloadFreightPDF';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class FreightPDFDownloadQuickAction extends LightningElement {
    @api recordId;
    @track loading = false;

    handleDownload() {
        if (!this.recordId) {
            this.showToast('Error', 'Record Id not available.', 'error');
            return;
        }

        this.loading = true;

        downloadFreightPDF({ splitOrderId: this.recordId })
            .then((result) => {

                const data = typeof result === 'string' ? JSON.parse(result) : result;
                console.log('Apex Response:', data);

                if (data.Statuscode === 0) {
                    this.showToast('Error', data.Message || 'Failed to generate Freight PDF.', 'error');
                } else if (data.Statuscode === 1 && data.Base64PDF) {
                    // Convert Base64 → Blob → Download
                    const blob = this.base64ToBlob(data.Base64PDF, 'application/pdf');
                    const url = URL.createObjectURL(blob);
                    const link = document.createElement('a');
                    link.href = url;
                    link.download = data.FileName || 'FreightDocument.pdf';
                    document.body.appendChild(link);
                    link.click();
                    document.body.removeChild(link);

                    this.showToast('Success', data.Message || 'Freight PDF downloaded successfully.', 'success');
                } else {
                    this.showToast('Error', 'Unexpected response from server.', 'error');
                }
            })
            .catch((error) => {
                    console.error('Error:', error);
                    this.showToast('Error', error.body?.message || error.message, 'error');
                
            })
            .finally(() => {
                    this.loading = false;
                    this.closeModal();
                
            });
    }

    handleCancel() {
        this.loading = false;
        this.closeModal();
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    base64ToBlob(base64, mimeType) {
        const byteCharacters = atob(base64);
        const byteNumbers = new Array(byteCharacters.length);
        for (let i = 0; i < byteCharacters.length; i++) {
            byteNumbers[i] = byteCharacters.charCodeAt(i);
        }
        const byteArray = new Uint8Array(byteNumbers);
        return new Blob([byteArray], { type: mimeType });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
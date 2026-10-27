import { LightningElement, api } from 'lwc';

export default class PdfGenerator extends LightningElement {
     @api recordId; // pass if needed for VF

    handleGeneratePdf() {
        // Simply open VF page in a new tab — Salesforce will use current user’s language
        const vfPageUrl = `/apex/MyVFpdfPage?id=${this.recordId}`;
        window.open(vfPageUrl, '_blank');
    }
}
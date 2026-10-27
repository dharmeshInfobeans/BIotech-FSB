import { LightningElement, track } from 'lwc';
import requestChange from '@salesforce/apex/MarketXrayChangeRequestController.requestChange';
import getFormIdForCurrentUser from '@salesforce/apex/MarketXrayChangeRequestController.getFormIdForCurrentUser';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ErrorForUncheckedMarketXRay extends LightningElement {

    @track marketXrayFormId;

    connectedCallback() {
        console.log('❗ MarketXrayAccessRestricted component LOADED');
        this.loadFormId();   // Load form ID immediately
    }

    // Load Form ID for this Experience user
    loadFormId() {
        getFormIdForCurrentUser()
            .then(formId => {
                console.log("Form ID retrieved:", formId);
                this.marketXrayFormId = formId;
            })
            .catch(error => {
                console.error("Error retrieving form ID:", error);
            });
    }

    // Called when user clicks button
    handleRequestChange() {
        console.log("Request button clicked");

        if (!this.marketXrayFormId) {
            console.error("No form ID found!");
            this.dispatchEvent(new ShowToastEvent({
                title: "Form Not Found",
                message: "Unable to locate the Market X-Ray form.",
                variant: "error"
            }));
            return;
        }

        console.log("📨 Sending request to Apex for Form ID:", this.marketXrayFormId);

        requestChange({ formId: this.marketXrayFormId })
            .then(result => {
                console.log("Apex result:", result);

                this.dispatchEvent(new ShowToastEvent({
                    title: "Request Submitted",
                    message: "Your request has been sent to the Admin.",
                    variant: "success"
                }));
            })
            .catch(error => {
                console.error("Apex error:", error);

                this.dispatchEvent(new ShowToastEvent({
                    title: "Error",
                    message: error.body?.message || "Failed to send request.",
                    variant: "error",
                    mode: "sticky"
                }));
            });
    }
}
import { LightningElement, api, wire } from 'lwc';

import { CloseActionScreenEvent } from 'lightning/actions';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import {
    getRecord,
    getFieldValue
} from 'lightning/uiRecordApi';

import resyncNow from '@salesforce/apex/OrderManualResyncController.resyncNow';

import STATUS_CODE_FIELD from '@salesforce/schema/Sample_Request_Header__c.Status_Code__c';

import MESSAGE_FIELD from '@salesforce/schema/Sample_Request_Header__c.Message__c';

import RETRY_COUNT_FIELD from '@salesforce/schema/Sample_Request_Header__c.Retry_Count__c';


const FIELDS = [
    STATUS_CODE_FIELD,
    MESSAGE_FIELD,
    RETRY_COUNT_FIELD
];


export default class OrderResyncButton extends LightningElement {

    @api recordId;


    // =========================================================
    // Component State
    // =========================================================

    isLoading = false;

    showConfirm = true;

    wiredRecordResult;


    // =========================================================
    // Get Record
    // =========================================================

    @wire(getRecord, {
        recordId: '$recordId',
        fields: FIELDS
    })
    wiredRecord(result) {

        this.wiredRecordResult = result;

    }


    // =========================================================
    // Current Status Code
    // =========================================================

    get currentStatus() {

        const value = getFieldValue(
            this.wiredRecordResult?.data,
            STATUS_CODE_FIELD
        );

        return value || 'Unknown';

    }


    // =========================================================
    // Last SAP Response
    // =========================================================

    get lastMessage() {

        return getFieldValue(
            this.wiredRecordResult?.data,
            MESSAGE_FIELD
        );

    }


    // =========================================================
    // Retry Count
    // =========================================================

    get retryCount() {

        return getFieldValue(
            this.wiredRecordResult?.data,
            RETRY_COUNT_FIELD
        ) || 0;

    }


    // =========================================================
    // Status Pill
    // =========================================================

    get statusPillClass() {

        const base = 'resync-status-pill';

        const status = (this.currentStatus || '').toLowerCase();


        if (status === 'ordered') {

            return `${base} resync-status-pill_success`;

        }


        if (status === 'failed') {

            return `${base} resync-status-pill_error`;

        }


        return `${base} resync-status-pill_neutral`;

    }


    // =========================================================
    // Toast
    // =========================================================

    showToast(title, message, variant) {

        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );

    }


    // =========================================================
    // Close Popup + Reload
    // =========================================================

    closePopupAndReload() {

        // Hide custom modal
        this.showConfirm = false;


        // Close Salesforce Quick Action
        this.dispatchEvent(
            new CloseActionScreenEvent()
        );


        // Reload after toast / modal close
        setTimeout(() => {

            window.location.reload();

        }, 1000);

    }


    // =========================================================
    // Cancel
    // =========================================================

    handleCancel() {

        if (this.isLoading) {

            return;

        }

        this.closePopupAndReload();

    }


    // =========================================================
    // Confirm Resync
    // =========================================================

    async handleConfirmResync() {

        if (this.isLoading) {

            return;

        }


        this.isLoading = true;


        try {

            // =====================================================
            // Call Apex
            // =====================================================

            const result = await resyncNow({
                headerId: this.recordId
            });


            // =====================================================
            // Check Apex Response
            // =====================================================

            if (result && result.startsWith('Error:')) {

                throw new Error(result);

            }


            // =====================================================
            // SUCCESS TOAST
            // =====================================================

            this.showToast(
                'Success',
                'Order resync initiated successfully.',
                'success'
            );


        } catch (error) {

            console.error(
                'Resync failed:',
                error
            );


            // =====================================================
            // ERROR MESSAGE
            // =====================================================

            let errorMessage = 'Failed to resync order.';


            if (error?.message) {

                errorMessage = error.message;

            }


            // =====================================================
            // ERROR TOAST
            // =====================================================

            this.showToast(
                'Error',
                errorMessage,
                'error'
            );

        } finally {

            this.isLoading = false;


            // =====================================================
            // Close popup + reload
            // =====================================================

            this.closePopupAndReload();

        }

    }

}
import { LightningElement, api, track } from 'lwc';
import syncFromLWC from '@salesforce/apex/MasterAgreementSAPSync.syncFromLWC';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class SapSyncQuickAction extends LightningElement {

    _recordId;

    @track isLoading = false;
    @track responseMessage;
    @track isSuccess;

    // ✅ Reliable way to get recordId in Quick Action
    @api
    set recordId(value) {
        this._recordId = value;

        // Auto trigger once recordId is available
        if (value && !this.hasExecuted) {
            this.handleSync();
        }
    }

    get recordId() {
        return this._recordId;
    }

    handleSync() {
        if (!this.recordId) {
            this.showToast('Error', 'Record Id not found', 'error');
            return;
        }

        this.isLoading = true;

        syncFromLWC({ masterAgreementId: this.recordId })
            .then(result => {
                this.isLoading = false;

                console.log('result:', result);

                this.responseMessage = result?.Message;
                this.isSuccess = result?.Status === 1;

                this.showToast(
                    this.isSuccess ? 'Success' : 'Error',
                    this.responseMessage,
                    this.isSuccess ? 'success' : 'error'
                );

                // Auto close only on success
                if (this.isSuccess) {
                    this.dispatchEvent(new CloseActionScreenEvent());
                }
            })
            .catch(error => {
                this.isLoading = false;
                this.isSuccess = false;

                let msg = error?.body?.message || 'Unknown error';
                this.responseMessage = msg;

                this.showToast('Error', msg, 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}
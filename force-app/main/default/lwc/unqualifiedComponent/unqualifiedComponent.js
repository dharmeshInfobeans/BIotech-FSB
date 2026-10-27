import { LightningElement, track, wire, api } from 'lwc';
import updateUnuqalifiedLead from '@salesforce/apex/CustomLeadCreationController.updateUnuqalifiedLead';
import getAccountId from '@salesforce/apex/CustomLeadCreationController.getAccountId';
import getCustomLabels from '@salesforce/apex/CustomLeadCreationController.getCustomLabels';


import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {
    CurrentPageReference
} from 'lightning/navigation';
import getLightningPickListValues from '@salesforce/apex/CommonutiltiyClass.getLightningPickListValues';

export default class UnqualifiedComponent extends NavigationMixin(LightningElement) {
 
    @api leadid;
    @track unuqalifiedLeadMap = {};
    @track disable = false;
    @track unqualifiedList=[];
    @track labels = {};
    connectedCallback() {
        console.log('test');
    }
     @wire(getLightningPickListValues)
    getPickListData(result) {
        try {
            this.spinner = true;
            console.log('Pickist result', result);
            if (result.data) {
                this.unqualifiedList=result.data.Disqualified_Reason__c;
                console.log('unuqlaified list',this.unqualifiedList);
            }
            if (result.error) {
                console.log('error', result.error);
            }
        } catch (error) {
            console.log('error-->', error);
        }
    }
     @wire(getCustomLabels)
    getLabels(result) {
        this.spinner = true;
        if (result.data) {
            this.labels = result.data;
            console.log('Translation label', this.labels);
            if (this.labels != undefined) {
                this.spinner = false;
            }
        }
        if (result.error) {
            console.log('error', result.error);
        }
    }
    @wire(getAccountId, { recordId: '$leadid' })
    getData(result) {
        if (result.data) {
            console.log('data', result.data)
            if (result.data.LeadStage == 'Unqualified') {
                this.disable = true;
                const evt = new ShowToastEvent({
                    title: 'Warning',
                    message: 'Lead has already unqualified',
                    variant: 'Warning',
                    mode: 'dismissable'
                });
                this.dispatchEvent(evt);
                this.dispatchEvent(new CustomEvent('backfromunqualified', { detail: true }));
            }
        }
        if (result.error) {

        }
    }
    handleUnqualifiedLead(event) {
        this.unuqalifiedLeadMap['Id'] = this.leadid;
        this.unuqalifiedLeadMap[event.target.name] = event.target.value;
        console.log('Unqualified lead map', this.unuqalifiedLeadMap);
    }
    //update {handleUpdateLead} By gyadeen
    handleUpdateLead() {
    updateUnuqalifiedLead({ lea: this.unuqalifiedLeadMap })
        .then(result => {
            if (result === 'success') {
                const evt = new ShowToastEvent({
                    title: 'Success',
                    message: 'Lead has been marked unqualified',
                    variant: 'success',
                    mode: 'dismissable'
                });
                this.dispatchEvent(evt);
                
                // Triggering a custom event and reloading the window
                this.dispatchEvent(new CustomEvent('backfromunqualified', { detail: true }));
                window.location.reload();
            }
        })
        .catch(error => {
            // Handling errors from the server
            console.error('Error updating lead:', error);
            const evt = new ShowToastEvent({
                title: 'Error',
                message: error.body.message || 'An unknown error occurred',
                variant: 'error'
            });
            this.dispatchEvent(evt);
        });
}

    handleCancel() {
        this.dispatchEvent(new CustomEvent('backfromunqualified', { detail: true }));
    }
    get options() {
        return [
            { label: '	Govt. doctor', value: '	Govt. doctor' },
            { label: '	No surgical practice.', value: 'No surgical practice.' },
            { label: 'Chain of Hospitals', value: 'Chain of Hospitals' },
            { label: 'No Team presence', value: 'No Team presence' },
            { label: 'No potential', value: 'No potential' }
        ];
    }

}
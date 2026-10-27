import { LightningElement, track, api, wire } from 'lwc';
import insertContact from '@salesforce/apex/CustomLeadCreationController.insertContact';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {
    CurrentPageReference
} from 'lightning/navigation';
import getLightningPickListValues from '@salesforce/apex/CommonutiltiyClass.getLightningPickListValues';
import getAccountId from '@salesforce/apex/CustomLeadCreationController.getAccountId';

export default class CustomContactForm extends LightningElement {
    @wire(CurrentPageReference) pageRef;
    @track contMap = {};
    @api accid;
    @api labels;
    @track specialistData = [];
    @track showSpecialist = false;
    connectedCallBack() {
    }
    @wire(getLightningPickListValues)
    getPickListData(result) {
        this.specialistData = [];
        try {
            console.log('Pickist result', result);
            if (result.data) {
                this.specialistData = result.data.Specialities__c != undefined ? result.data.Specialities__c : [];
            }
            if (result.error) {
                console.log('error', result.error);
            }
        } catch (error) {
            console.log('error', error);
        }
    }
    @wire(getAccountId, { recordId: '$accid' })
    getAccountData(result) {
        if (result.data) {
            console.log('Account data', result.data);
            if (result.data.AccountRecordType != undefined
                && result.data.AccountRecordType == 'International -Dermal') {
                this.showSpecialist=true;
            }
        }
        if (result.error) {
            console.log('Error ', result.error);
        }
    }

    handleInsContact(event) {
        console.log('Account Id', this.accid);
        this.contMap[event.target.name] = event.target.value;
        console.log('contact map', this.contMap);
    }
    handleSaveContact() {
        console.log('test');
        insertContact({ conData: this.contMap, accountId: this.accid }).then(result => {
            console.log('result', result);
            const evt = new ShowToastEvent({
                title: 'success',
                message: 'Succesfully created records',
                variant: 'success',
                mode: 'dismissable'
            });
            this.dispatchEvent(evt);
            this.dispatchEvent(new CustomEvent('getcontid', { detail: result }));
        }).catch(error => {
            console.log('error', error);
            const evt = new ShowToastEvent({
                title: 'Error',
                message: 'Error in creating the records',
                variant: 'error',
                mode: 'dismissable'
            });
            this.dispatchEvent(evt);
        })
    }
    handleCancel() {
        this.dispatchEvent(new CustomEvent('getcontid', { detail: undefined }));
    }
}
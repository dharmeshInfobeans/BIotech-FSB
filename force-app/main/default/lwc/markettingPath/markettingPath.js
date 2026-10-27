import { LightningElement, api, wire, track } from 'lwc';
// import show toast
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// import update record api
import updateLead from '@salesforce/apex/PathController.updateLead';
import getPicklistValues from '@salesforce/apex/PathController.getPicklistValues';
import isCurrentUserAdmin from '@salesforce/apex/PathController.isCurrentUserAdmin'; // Added by Gyadeen

import getAccountId from '@salesforce/apex/CustomLeadCreationController.getAccountId';

import { refreshApex } from '@salesforce/apex';

const FIELDS = [
    'Lead.Id',
    'Lead.Status'
];
export default class MarkettingPath extends LightningElement {
    @track selectedValue;
    @track tempSeletedValue;
    @api recordId;
    @track showSpinner = true;
    @track picklistFieldValues = [];
    @track picklistValues = [];
    @track rawData;

    @track specificFieldStatus;
    @track isAdmin = false;
    @track showPath = true;
    @track showButton=true;

    @wire(isCurrentUserAdmin) // Added by Gyadeen
    wiredUserProfile({ error, data }) { // Added by Gyadeen
        console.log('data---->', data);
        if (data!=undefined) { // Added by Gyadeen

            this.showButton = data; // Added by Gyadeen
            console.log('IsAdmin:',  this.showButton); // Added by Gyadeen
            this.isAdmin=data;
        } else if (error) { // Added by Gyadeen
            console.error('Error:', error); // Added by Gyadeen
            this.showButton = data; // Added by Gyadeen
        } // Added by Gyadeen
    } // Added by Gyadeen

    @wire(getPicklistValues, { recordId: '$recordId' })
    wiredData(result) {
        this.showSpinner = false;
        console.log('path resukt : ', result);
        this.rawData = result;
        if (result.data) {
            this.picklistValues = [];
            this.selectedValue = result.data.existValue;
            this.picklistFieldValues = result.data.picklist;
            console.log('got picklist field data : ', this.picklistFieldValues);
            let selectedUpTo = 0;
            this.picklistFieldValues.forEach((item, index) => {
                console.log('item--test: ', item);

                //******************************************************************************************************************** */     


                if (item.value === 'Commercialization' && result.data.existingcustomer === true) {  // Added by Gyadeen ahirwar
                    // Yeh line se loop ka agla iteration shuru hoga, aur value ko skip karega
                    return;  // added by Gyadeen
                } // Added by gyadeen

                if (item.value === 'Upgrade' && result.data.newcustomer === true) {  // Added by Gyadeen ahirwar
                    // Yeh line se loop ka agla iteration shuru hoga, aur value ko skip karega
                    return;  // added by Gyadeen
                } //

                //******************************************************************************************************************** */     

                let classList;
                console.log('item:', item.value);
                console.log('selectedvalue', this.selectedValue);
                if (item.value === this.selectedValue) {
                    classList = 'slds-path__item slds-is-current slds-is-active';
                    selectedUpTo = index;

                } else {
                    classList = 'slds-path__item slds-is-incomplete';
                }

                console.log(classList);

                this.picklistValues.push({
                    value: item.value,
                    label: item.label,
                    classList: classList
                })
            });
            console.log('selected upto : ', selectedUpTo);
            if (selectedUpTo > 0) {
                for (let item = 0; item < selectedUpTo; item++) {
                    this.picklistValues[item].classList = 'slds-path__item slds-is-complete';
                }
            }
            console.log('piclist : ', this.picklistValues);
        }
    }

   handleSelect(event) {
        try {
            console.log('in the function', event.currentTarget.dataset.value);
            const value = event.currentTarget.dataset.value;
            if (this.tempSeletedValue == 'Unqualified') {
                getAccountId({ recordId: this.recordId }).then(result => {
                    console.log('result:--->', result.LeadStage);
                    if (result.LeadStage == 'Unqualified') {
                        this.showPath = true;
                        //****************************************************Added by GYADEEN**************************************************** */     

                    } else {
                        if (result.LeadStage == 'Won' || result.LeadStage == 'Lost') {
                            // this.showPath = true;
                            this.dispatchEvent(
                                new ShowToastEvent({
                                    title: 'error',
                                    message: 'You can not mark the lead as unqualified',
                                    variant: 'error'
                                })
                            );
                            //************************************************Added by GYADEEN******************************************************************** */     

                        } else {
                            this.showPath = false;
                        }
                    }
                })

            }
            console.log('picklistvalues:', this.picklistValues);
            this.picklistValues.forEach((item, index) => {
                if (item.value === this.selectedValue) {
                    console.log('item2 : ', item);
                    item.classList = 'slds-path__item slds-is-current';
                }
                if (item.value === value) {
                    console.log('item4 : ', item);
                    console.log('IS amdin',this.isAdmin);
                    if (value === this.selectedValue) {
                        this.showButton = false;
                    } else if (!this.isAdmin) {
                        if ((item.value == 'Lost' || item.value == 'Unqualified')) {
                            this.showButton = true;
                           // this.isnotadmin = true;
                        } if ((item.value != 'Lost' && item.value != 'Unqualified')) {
                            this.showButton = false;
                        }
                    }else {
                        this.showButton=true;
                    }

                    item.classList = 'slds-path__item slds-is-active';
                }
            });
            this.tempSeletedValue = event.currentTarget.dataset.value;

        } catch (error) {
            console.log('error', error);
        }

    }


    handleMarkAsSelected() {
        this.showSpinner = true;
        console.log('field', this.rawData.data.field);
        console.log('value', this.tempSeletedValue);
        console.log('raw data', this.rawData);
        console.log('recordId--->',this.recordId);

        updateLead({ recordId: this.recordId, field: this.rawData.data.field, value: this.tempSeletedValue })
            .then((result) => {
                console.log(result);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Status Updated!',
                        variant: 'success'
                    })
                );
                location.reload();
                console.log('success!');
                refreshApex(this.rawData);
            })
            .catch(error => {
                console.error('Error object:', error);
               console.log('Data',error.body.fieldErrors);
                if (error && error.body && error.body.pageErrors && error.body.pageErrors.length > 0) {
                    console.log('error-----', error.body.pageErrors[0].message);
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error updating status!',
                            message: error.body.pageErrors[0].message,
                            variant: 'error'
                        })
                    );
                }   

                console.error('failure => ', error);
            });
        this.showSpinner = false;
    }
    handleBack() {
        this.showPath = true;
    }
}
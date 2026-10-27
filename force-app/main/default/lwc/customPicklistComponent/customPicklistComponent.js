import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import PRODUCT_FAMILY from '@salesforce/schema/Lead__c.Product_Family__c';

export default class LeadAddProduct extends LightningElement {
    @api recordId;

    productFamilyString;
    productFamilyOptions = [];
    selectedFamily;

    @wire(getRecord, {
        recordId: '$recordId',
        fields: [PRODUCT_FAMILY]
    })
    wiredLead({ data, error }) {
        if (data) {
            this.productFamilyString =
                data.fields.Product_Family__c.value;

            if (this.productFamilyString) {
                this.productFamilyOptions =
                    this.productFamilyString.split(';').map(val => ({
                        label: val,
                        value: val
                    }));
            }
        } else if (error) {
            console.error(error);
        }
    }

    handleFamilyChange(event) {
        this.selectedFamily = event.detail.value;

        // Use this to filter products / call Apex
        this.productFamily = this.selectedFamily;
         const childEvent = new CustomEvent('childevent', {
 detail: event.detail.value
 });
 this.dispatchEvent(childEvent);
    }
}
import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getCountryMappingData from '@salesforce/apex/CustomLeadCreationController.getCountryMappingData';
import getCustomLabels from '@salesforce/apex/CustomLeadCreationController.getCustomLabels';
import getLightningPickListValues from '@salesforce/apex/CommonutiltiyClass.getLightningPickListValues';
export default class Countrystateseletion extends LightningElement {

    @track labels = {};
    @track billingCountryList = [];
    @track leadMap = {};
    @track spinner = true;
    @track leadUpdateMap = new Map();
    @track stateList = [];
    @track state= true;
    @track statevalue= '';
    @track Statedesables = true;
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
    @wire(getLightningPickListValues)
    getPickListData(result) {
        try {
            this.spinner = true;
            if (result.data) {
                this.billingCountryList = result.data.Country__c;
                this.spinner = false;
            }
            if (result.error) {
                console.log('error', result.error);
            }
        } catch (error) {
            console.log('error', error);
        }
    }
    handleInslead(event) {
        console.log('event.target.name', event.target.name);
        this.leadMap[event.target.name] = event.target.value;
        const countryname = event.target.value;
        if (event.target.name == 'Country') {
            getCountryMappingData({
                country: this.leadMap['Country']
            }).then(result => {
                //console.log('Count : ', JSON.stringify(result));
                console.log('countryname',countryname);
                
                if(countryname =='INDIA'){
                   this.Statedesables = false;
                }else{
                  this.Statedesables = true;
                  
                }
                this.stateList = result.State;
                console.log('this.stateList--56',this.stateList);
                if (!this.stateList || this.stateList.length === 0) {
                    console.log('57');
                    if(this.leadMap['state']){
                        console.log('58');
                        this.leadMap['state'] = null; // Reset state if there are no options available
                        this.state = false;
                        console.log('59');
                    }
                    
                }else{
                    this.state = true; 
                }
            }).catch(error => {
                console.log('error', error);
            })
        }

        const dataToSend = this.leadMap;
        console.log('dataToSend ', dataToSend);
        const CustomEventevent = new CustomEvent('senddatatoaura', {
            detail: { dataToSend }
        });

        // Dispatch the event to be caught by Aura
        this.dispatchEvent(CustomEventevent);
    }
    handleChange(event) {
        console.log('event.target.value : ', event.target.value);
        this.state = event.target.value;
        this.leadMap[event.target.name] = event.target.value;
        const dataToSend = this.leadMap;
        console.log('dataToSend ', dataToSend);
        const CustomEventevent = new CustomEvent('senddatatoaura', {
            detail: { dataToSend }
        });

        // Dispatch the event to be caught by Aura
        this.dispatchEvent(CustomEventevent);
    }

}
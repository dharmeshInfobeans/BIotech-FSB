import {
    LightningElement,
    api,
    track,
    wire
} from 'lwc';
import getCityData from '@salesforce/apex/AttendanceController.getCityData';
import updateCampaign from '@salesforce/apex/AttendanceController.updateCampaign';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
export default class ShowCityCmp extends LightningElement {
    @api recordId;
    @track showCampaign = true;
    @track cityData = [];
    @track city='';
    @track showCampaignError=true;


    @track cityMap = {};
    connectedCallback() {
        console.log('Record Id of the Campaign--->>', this.recordId);
    }
    @wire(getCityData, {
        cmpId: '$recordId'
    })
    getData(result) {
        console.log('Result====>26', result);
        if (result.data) {
            // console.log('Campaign data', result.data.CityList.city);
            this.cityData = result?.data?.CityList?.city;
            this.city=result?.data?.Citydata;
            console.log('City',this.city);
            if(this.city==undefined || this.city=='') {
               this.showCampaignError=true;
            }else {
                this.showCampaignError=false;
            }

        }
        if (result.error) {
            console.log('Campaign Error', result.error);
        }
    }
    showCityModal() {
        this.showCampaign = false;
    }
    handleSelectCity(event) {
        const cityValue = event.target.value;
        this.cityMap['Id'] = this.recordId;
        this.cityMap['City__c'] = cityValue;
        console.log('City Map----', this.cityMap);
    }

    handleBack() {
        this.showCampaign = true;
    }

    handleUpdateCampaign() {
        updateCampaign({cmp:this.cityMap}).then(result=>{
            console.log('result',result);
            const evt = new ShowToastEvent({
                title: ' Success',
                message: 'Succesfully updated records',
                variant: 'success',
                mode: 'dismissable'
            });
            this.dispatchEvent(evt);
            window.location.reload();

        }).catch(error=>{
            console.log('Error--',error);
        })
    }
}
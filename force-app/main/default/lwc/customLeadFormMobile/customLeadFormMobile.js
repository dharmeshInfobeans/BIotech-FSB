import {LightningElement,wire,track,api} from 'lwc';
import getLightningPickListValues from '@salesforce/apex/CommonutiltiyClass.getLightningPickListValues';
import getdailyactivity from '@salesforce/apex/CommonutiltiyClass.getdailyactivity';
import getloginlogoutmodule from '@salesforce/apex/CommonutiltiyClass.getCustomLabels';

import leadCreate from '@salesforce/apex/CustomLeadCreationController.leadCreate';
import {NavigationMixin} from 'lightning/navigation';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import {CurrentPageReference} from 'lightning/navigation';
import {registerListener,unregisterAllListeners,fireEvent} from "c/pubsub";
import LightningModal from 'lightning/modal';
import getAccountId from '@salesforce/apex/CustomLeadCreationController.getAccountId';
import getAddressData from '@salesforce/apex/CustomLeadCreationController.getAddressData';
import getCountryMappingData from '@salesforce/apex/CustomLeadCreationController.getCountryMappingData';
import getCityMappingData from '@salesforce/apex/CustomLeadCreationController.getCityMappingData';
import getCustomLabels from '@salesforce/apex/CustomLeadCreationController.getCustomLabels';
import getUserInformation from '@salesforce/apex/CommonutiltiyClass.getUserInformation';
export default class CustomLeadFormMobile extends NavigationMixin(LightningElement) {

@track leadSoruceList = []; //store lead source

@track isrequired = false; // added by Gyadeen Ahirwar

@track billingCountryList = []; //store country
@track productList = []; //store product
@track subjectList = []; //store subject values
@track meetingTypeList = []; //store meeting values
@track callTypeList = []; //store call type values
@track spinner = true;
@track insEventMap = {}; //Use to insert the Event
@track selectLead = true; //use to show the modal where the user can select the type
@track accountId = ''; //use to get the accountId 
@track leadMap = {}; //Use to insert the Lead data
@track leadType = ''; //
@track upgrade = false;
@track activity = true;//Added  BY gaydeen
@track accMap = new Map();
@track contMap = new Map();
@track showFooter = true;
@track showLead = true;
@track eventFields = false;
@track leadId = '';
@api recordId;
@api selectedRecord;

// @track filterlist = [];
result = {}; //added by gyadeen Ahirwar

@track dateShowMap = {};
@track leadSaveUpdate = false;
@track leadUpdateMap = new Map();
@track showContact = false;
@track createContact = false;
@track accCheckid = '' //Use to check if the accountId is changig
@track accountAddress = [];
@track existingLead = 'false';
@track newLead = 'false';
@track productDemo = false;
@track appointmentDemo = false;
@track presentationDemo = false;
@track eventAddress = false;
@track stateList = [];
@track cityList = [];
@track productList = [];
@track countryWiseMap = new Map();
@track eventFieldsRequired = false;
@track productOptions = [];
@track addressspinner = false;
@track labels = {};
@track getloginlogoutlabel ={};
@track evalutaionWeek = false;
@track commerializationWeek = false;
@track upgradeWeek = false;
@track showMeetingDetails = false;
@track showDetails = false;
@track sapCode = false;
@track userMap = {};
@track currentEventAddress = '';
@track leadRelatedData = [];
@track showRelatedLead = false;
@track leadEventList=[];
@track parentaccountId = '';
@track currentrecord ={};
connectedCallback() {

    this.leadUpdateMap = undefined;
    this.spinner = true;
    this.insEventMap['CallType'] = '';
    this.insEventMap['MeetingType'] = '';
    this.insEventMap['Subject'] = '';
    console.log('record Id', this.recordId);
    if (this.recordId == undefined) {
        this.recordId = '';
    } else {
        getAccountId({
            recordId: this.recordId
        }).then(result => {
            console.log('Account Id on load', result);
             this.currentrecord = result;
            if(this.currentrecord['cecisapproval'] === false &&
        (this.currentrecord['cecisrating'] === 'Nill' || this.currentrecord['phakicrating'] === 'Nill')){
             this.commerializationWeek = true;
             this.evalutaionWeek = true;
             this.upgradeWeek = true;
        }
            if (result.LeadList != undefined) {
                this.leadRelatedData = result.LeadList;
                this.showRelatedLead = true;
            }
            if (result.AccountId != undefined) {
                this.recordId = result.AccountId;
                this.accountId = result.AccountId;
                this.accCheckid = result.AccountId;

            }
            

            if (!result.NewCustomer && result.AccountId != undefined) {
                this.upgrade = true;
                this.existingLead = true;
                this.eventAddress = false;
            }
            if(result.NewCustomer && result.AccountId != undefined){
                this.upgrade = false;
                this.existingLead = false;
            } 
            this.selectLead = false;
            this.showFooter = false;
            if (this.accountId != '' && this.accountId != undefined) {
                this.createContact = true;
            }
            if (result.Lead == 'true') {
                this.newLead = 'true';
                this.showLead = true;
                this.eventFields = true;
                this.showMeetingDetails = true;
                this.leadId = result.LeadId;
                this.dateShowMap['productWeek'] = result.DemoWeek;
                this.dateShowMap['presentationWeek'] = result.Presentatinweek;
                this.dateShowMap['appointmentWeek'] = result.AppointmentWeek;
                this.dateShowMap['EvaluationWeek'] = result.EvaluationWeek;
                this.dateShowMap['CommercializationWeek'] = result.CommercializationWeek;
                this.dateShowMap['UpgradeWeek'] = result.UpgradeWeek;
                // if (result.DemoWeek != '' && result.DemoWeek != undefined) {
                //     this.productDemo = true;
                // }
                // if (result.Presentatinweek != '' && result.Presentatinweek != undefined) {
                //     this.presentationDemo = true;
                // }
                // if (result.AppointmentWeek != '' && result.AppointmentWeek != undefined) {
                //     this.appointmentDemo = true;
                // }
                // if (result.EvaluationWeek != '' && result.EvaluationWeek != undefined) {
                //     this.evalutaionWeek = true;
                // }
                // if (result.CommercializationWeek != '' && result.CommercializationWeek != undefined) {
                //     this.commerializationWeek = true;
                // }
                // if (result.UpgradeWeek != '' && result.UpgradeWeek != undefined) {
                //     this.upgradeWeek = true;
                // }
                if (this.productDemo != true || this.presentationDemo != true || this.appointmentDemo != true || this.evalutaionWeek != true || this.commerializationWeek != true || this.upgradeWeek != true) {
                    this.eventFields = false;
                    //  this.eventAddress = false;
                }
                this.leadUpdateMap = result;

                if (result.AccountId == undefined) {
                    this.leadMap['createddate'] = this.leadUpdateMap.CreatedDate;
                    this.leadMap['First_Name__c'] = this.leadUpdateMap.FirstName;
                    this.leadMap['Last_Name__c'] = this.leadUpdateMap.lastName;
                    this.leadMap['Email__c'] = this.leadUpdateMap.email;
                    this.leadMap['Billing_Street__c'] = this.leadUpdateMap.billingStreet;
                    this.leadMap['Country__c'] = this.leadUpdateMap.Country;
                    this.leadMap['Billing_state__c'] = this.leadUpdateMap.BillingState;
                    this.leadMap['Billing_City__c'] = this.leadUpdateMap.billingCity;
                    this.leadMap['Mobile__c'] = this.leadUpdateMap.Mobile;
                    // this.leadMap['Account__c'] = this.accountId;
                    this.leadMap['Company__c'] = this.leadUpdateMap.Company;
                    this.leadMap['Product__c'] = this.leadUpdateMap.Product;
                    this.leadMap['Billing_code__c'] = this.leadUpdateMap.ZipCode;
                    this.leadMap['Lead_Stage__c'] = this.leadUpdateMap.LeadStage;
                    this.getCountryWiseData(this.leadMap['Country__c'], this.leadMap['Billing_state__c'], 'false');
                    this.eventAddress = true;

                }

            } else if (result.Account == 'true') {
                this.showMeetingDetails = true;
                this.existingLead = 'true';
                this.newLead = 'false';
                this.showLead = false;
                this.eventFields = false;
                this.eventAddress = false;
                this.leadId = '';
                this.upgrade = true;
                this.sapCode = true;
            }

        }).catch(error => {
            console.log('error', error);
        })


    }

    this.spinner = false;

}


@wire(CurrentPageReference) pageRef;
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

@wire(getloginlogoutmodule)
getloginlogout(result) {
    this.spinner = true;
    if (result.data) {
        this.getloginlogoutlabel = result.data;
        console.log('Translation getloginlogoutlabel', this.getloginlogoutlabel);
        if (this.getloginlogoutlabel != undefined) {
            this.spinner = false;
        }
    }
    if (result.error) {
        console.log('error', result.error);
    }
}


@wire(getUserInformation)
getUserData(result) {
    if (result.data) {

        this.userMap = result.data;
        if (result.data.Profile == 'System Administrator') {
            this.sapCode = false;
        } else {
            this.sapCode = true;
        }
        console.log('Sap code', this.sapCode);
        console.log('Final user map', this.userMap);

    }
    if (result.error) {
        console.log('Error in getting the user information', result.error);
    }
}
//Added below wire method BY gaydeen
@wire(getdailyactivity)
getactivity(result) {
    try {
        if(result.data){
        
              if (result.data.activity) {
            console.log('activity', result);
            this.activity = true;
           
             }else{
            console.log('activity', result);
            const evt = new ShowToastEvent({
            title: this.getloginlogoutlabel.Warning__c,
            message: this.getloginlogoutlabel.Kindly_do_the_Login_before_performing_th__c,
            variant: this.getloginlogoutlabel.Warning__c
           
            });
            console.log('this.recordId',this.recordId);
            if(this.recordId !=undefined && this.recordId !='' ){
              this.dispatchEvent(evt);
              this.activity = false;
              this[NavigationMixin.Navigate]({
              type: 'standard__recordPage',
                attributes: {
             recordId: this.recordId, // Replace with the actual Account record ID
             objectApiName: 'Account',
              actionName: 'view'
                           }
            });
            }else{
            this.dispatchEvent(evt);
            this.activity = false;
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Lead__c',
                    actionName: 'list'
                },
                state: {
                    filterName: 'Recent'
                },
            });
            }
        

        }

        if (result.error) {
            console.log('error', result.error);
        }
    }
    } catch (error) {
        console.log('error', error);
    }
}
//Added Above wire method BY gaydeen

@wire(getLightningPickListValues)
getPickListData(result) {
    try {
        this.spinner = true;

        console.log('Picklist result', result);


        if (result.data) {
            this.leadSoruceList = result.data.Lead_Stage__c;
            console.log('leadSoruceList', this.leadSoruceList);
            this.billingCountryList = result.data.Country__c;
             this.productList = result.Product__c;
            this.subjectList = result.data.Subject;
            this.meetingTypeList = result.data.Meeting_Type__c;
            this.callTypeList = result.data.Call_Type__c;
            this.spinner = false;
        }

        if (result.error) {
            console.log('error', result.error);
        }
    } catch (error) {
        console.log('error', error);
    }
}
handleCheckbox(event) {
    this.leadMap = { ...this.leadMap, [event.target.name]: event.target.checked };
}

handleInslead(event) {

    this.leadMap[event.target.name] = event.target.value;
    if (this.accountId != '' && this.accountId != undefined) {

        this.leadMap['Account__c'] = this.accountId;
    }
    if (this.leadMap.Planned_Product_Demo_Week__c != undefined || this.leadMap.Planned_Presentation_Week__c != undefined || this.leadMap.Planned_Appointments_Week__c != undefined) {

        this.eventFieldsRequired = true;
    } else {
        this.eventFieldsRequired = false;
    }

    if (event.target.name == 'Country__c') {
        //  this.addressspinner = true;
        getCountryMappingData({
            country: this.leadMap['Country__c']
        }).then(result => {
            console.log('result city', result);
            this.leadMap['Billing_state__c'] = '';
            this.leadMap['Billing_City__c'] = '';
           // this.leadMap['Billing_code__c'] = '';
            this.productList = [];
            this.stateList = [];
            this.productList = result.Product;
            this.stateList = result.State;
            if (result.State == undefined) {

                this.cityList = [];
            }
            if (result.Product == undefined) {
                this.leadMap['Product__c'] = '';
            }
            this.addressspinner = false;
        }).catch(error => {
            console.log('error', error);
        })
    } else if (event.target.name == 'Billing_state__c') {

        getCityMappingData({
            state: this.leadMap['Billing_state__c']
        }).then(result => {
            console.log('result city', result);
            this.leadMap['Billing_City__c'] = '';
           // this.leadMap['Billing_code__c'] = '';
            this.cityList = [];
            this.cityList = result.city;

        }).catch(error => {
            console.log('error', error);
        })
    }

  

   



    console.log('city list', this.cityList);



    console.log('Lead map----', this.leadMap);
    
    
}

handleInsEvent(event) {

    this.currentEventAddress = '';
    switch (event.target.name) {
        case 'CallType':
            this.insEventMap['CallType'] = event.target.value;
            break;
        case 'Subject':
            this.insEventMap['Subject'] = event.target.value;
            break;
        case 'MeetingType':
            this.insEventMap['MeetingType'] = event.target.value;
            break;
        case 'EventAddress':
            this.currentEventAddress = event.target.value;
            console.log('Current Event addres', this.currentEventAddress);
            break;


    }

    console.log('Event map', this.insEventMap);
}

   
parentRecord(event) {
    let selecteddata = JSON.parse(JSON.stringify(event.detail.selectedRecord));
     console.log('Lookup reocrd', selecteddata);
   
    if (selecteddata != undefined ||selecteddata != '') {
        this.parentaccountId = selecteddata.Id;
        console.log('selecteddata ID: ',selecteddata.Id);
        console.log('Account Id: ', this.accountId);
    } else {
        console.log('No account selected.');
    }
}


handleLeadSave() {
    console.log('state', this.leadMap['Billing_state__c']);
    console.log('city', this.leadMap['Billing_City__c']);
      if (!this.leadMap['Mobile__c'] || this.leadMap['Mobile__c'].trim() === '') {
        this.showErrorMessage('Please Enter Mobile number');
        return;
    }
    const createdDateStr = this.leadMap['createddate'];
    const createdDate = createdDateStr ? new Date(createdDateStr) : null;
    const validationStartDate = new Date('2025-05-07');
    console.log('createdDate--->', createdDate);
    //const validationStartDate = new Date('2025-05-07');
    // Check if the mobile number contains only digits (no spaces, no characters)
    if ((createdDate && createdDate >= validationStartDate) || !createdDateStr) {
        if (!/^\d+$/.test(this.leadMap['Mobile__c'])) {
            this.showErrorMessage('Please Enter a valid Mobile number');
            return;
        }
    }

    if(this.leadType=='Upgrade') {
        if(this.leadMap['Account__c']==undefined ) {
        this.showErrorMessage('Please select the Account');
        return;
        } 
        if(this.leadMap['Contact_Name__c']==undefined) {
        this.showErrorMessage('Please select the Contact');
        return;
        }
       
    }

    


    if (this.leadMap['Billing_state__c'] != '') {
        this.selectedRecord = this.stateList.find(data => data.label === this.leadMap['Billing_state__c']);
        if (this.selectedRecord == undefined) {
            this.leadMap['Billing_City__c'] = '';
            this.leadMap['Billing_state__c'] = '';
            this.showErrorMessage('Please fill the correct state and city');
            return;
        }
    }
    if (this.leadMap['Billing_City__c'] != '') {
        this.selectedRecord = this.cityList.find(data => data.label === this.leadMap['Billing_City__c']);
        if (this.selectedRecord == undefined) {
            this.leadMap['Billing_City__c'] = '';
            this.showErrorMessage('Please fill the correct city');
            return;
        }
    }
     
    console.log('zipcode',this.leadMap['Billing_code__c']);
        if(this.leadMap['Billing_code__c'] == undefined || this.leadMap['Billing_code__c'] ==''){
            this.leadMap['Billing_code__c']='';
        this.showErrorMessage('Please fill the Zip code');
            return;
    }

     console.log('Hospital And clinic Name',this.leadMap['Company__c']);
        if(this.leadMap['Company__c'] == undefined || this.leadMap['Company__c'] ==''){
            this.leadMap['Company__c']='';
        this.showErrorMessage('Please fill the Hospital/Clininc Name');
            return;
    }
    
    

    if (this.leadMap.Planned_Product_Demo_Week__c != undefined || this.leadMap.Planned_Presentation_Week__c != undefined || this.leadMap.Planned_Appointments_Week__c != undefined) {

        if (this.insEventMap.CallType == '') {
            this.showErrorMessage(this.labels.Please_fill_the_call_type__c);
            return;
        }
        if (this.insEventMap.MeetingType == '') {
            this.showErrorMessage(this.labels.Please_fill_the_meeting_type__c);
            return;
        }
        if (this.insEventMap.Subject == '') {
            this.showErrorMessage(this.labels.Please_fill_the_subject__c);
            return;

        }
       
    }
    if (this.upgrade == true && this.leadMap['Account__c'] == undefined) {
        this.showErrorMessage('Please select the account');
        return;
    }
const street = this.leadMap['Billing_Street__c'];

console.log('thisBilling_Street__c', street);

if (!street || street.trim() === '') {
    this.showErrorMessage(this.labels.Street_error__c);
    return;
}

    const email = this.leadMap['Email__c'];
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    if (email === undefined || email.trim() === '') {
        this.showErrorMessage(this.labels.Email_invalid_Error_message__c);
        return;
    }

    if (/\s/.test(email) || !emailRegex.test(email)) {
        this.showErrorMessage('Email Incorrect. Please enter correct Email.');
        return;
    }

    if (this.leadType == 'New') {
        this.leadMap['New_Customer__c'] = true;
        this.leadMap['Existing_customer__c'] = false;
    } else if (this.leadType == 'Upgrade') {
        this.leadMap['Existing_customer__c'] = true;
        this.leadMap['New_Customer__c'] = false;
    }
 
    this.spinner = false; // Modified From spinner =  True --> false by Gyadeen ahirwar******************
    leadCreate({
        leadData: this.leadMap,
        dataMap: this.insEventMap,
        accountId: this.accountId,
        leadId: this.leadId,
        existingLead: this.existingLead,
        newLead: this.newLead,
        eventAdress: this.currentEventAddress,
        leadEventList  :this.leadEventList,
        parentaccountId : this.parentaccountId
    }).then(result => {

        this.leadSaveUpdate = true;
        console.log('result in---', result);
        if (result == 'success') {
            this.spinner = false;
            this.showSuccessMessage('lead created succesfully');
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Lead__c',
                    actionName: 'list'
                },
                state: {
                    filterName: 'Recent'
                },
            });

        } else {
            this.spinner = false;
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: result,
                    objectApiName: 'Lead__c',
                    actionName: 'view'
                },
            });

        }


    }).catch(error => {
        console.log('error', error);
        this.spinner = false;
        this.leadSaveUpdate = false;
        const evt = new ShowToastEvent({
            title: 'Error',
            message: error.body.pageErrors[0].message,
            variant: 'error',
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    })
}
handleCancel() {

    this[NavigationMixin.Navigate]({
        type: 'standard__objectPage',
        attributes: {
            objectApiName: 'Lead__c',
            actionName: 'list'
        },
        state: {
            filterName: 'Recent'
        },
    });
}

 get combinedValue() {
        const name = this.selectedRecord?.Name || ''; // Safe check for null or undefined
        const mobile = this.selectedRecord?.MobilePhone || ''; // Mobile number if needed
        return `${name} ${mobile}`; // Concatenate name and mobile
    }
lookupRecord(event) {

    let data = JSON.parse(JSON.stringify(event.detail.selectedRecord));
    console.log('Lookup reocrd', data);
    this.showDetails = false;
    if (event.detail.selectedRecord != "contact" && event.detail.selectedRecord != "account") {
        this.addressspinner = true;
        if (event.detail.selectedRecord.Account == 'Account') {
            if (event.detail.selectedRecord.CE_CIS_Rating__c == undefined || event.detail.selectedRecord.Phakic_Rating__c == undefined) {
                this.addressspinner = false;
                event.detail.selectedRecord = undefined;
                this.leadMap['Account__c'] = undefined;
                this.showDetails = true;
                this.showErrorMessage('Please complete the ce-cis and phakic rating to upgrade the lead');
                return;
            }

            fireEvent(this.pageRef, "accountIdData", event.detail.selectedRecord.Id);
            this.accountId = event.detail.selectedRecord.Id;
            this.leadMap['First_Name__c'] = event.detail.selectedRecord.Name; //d
            this.leadMap['Last_Name__c'] = event.detail.selectedRecord.Name;
            this.leadMap['Email__c'] = event.detail.selectedRecord.E_Mail__c;
            this.leadMap['Billing_Street__c'] = event.detail.selectedRecord.BillingStreet != undefined ? event.detail.selectedRecord.BillingStreet.toUpperCase() : '';
            this.leadMap['Country__c'] = event.detail.selectedRecord.BillingCountry != undefined ? event.detail.selectedRecord.BillingCountry.toUpperCase() : '';
            this.leadMap['Billing_state__c'] = event.detail.selectedRecord.BillingState != undefined ? event.detail.selectedRecord.BillingState.toUpperCase() : '';
            this.leadMap['Billing_City__c'] = event.detail.selectedRecord.BillingCity != undefined ? event.detail.selectedRecord.BillingCity.toUpperCase() : '';
            this.leadMap['Mobile__c'] = event.detail.selectedRecord.Phone; //d
            this.leadMap['Account__c'] = event.detail.selectedRecord.Id;
            this.leadMap['CE_CIS_Rating__c'] = event.detail.selectedRecord.CE_CIS_Rating__c;
            this.leadMap['Phakic_Rating__c'] = event.detail.selectedRecord.Phakic_Rating__c;
            this.leadMap['Company__c'] = event.detail.selectedRecord.Name;
            this.leadMap['OwnerId'] = event.detail.selectedRecord.OwnerId;
            this.leadMap['SAP_Code__c'] = event.detail.selectedRecord.SAP_Code__c;
            this.leadMap['Billing_code__c']= data.BillingPostalCode;
            this.accMap = event.detail.selectedRecord;
            //this.getCountryWiseData(this.leadMap['Country__c'],this.leadMap['Billing_state__c'],'false');
            if (this.accountId != '' && this.accountId != undefined) {
                this.isrequired = true;
                this.upgrade = true;
                this.createContact = true;
                const childComponent = this.template.querySelector('c-customcontactlookup');
                if (childComponent) {
                    console.log('test1111111111111');
                    childComponent.handleSubmit();
                }
            }
            this.addressspinner = false;
            //  this.getCountryWiseData(this.leadMap['Country__c'], this.leadMap['Billing_state__c'], 'false');
        } else if (event.detail.selectedRecord.contact == 'contact') {
            console.log('In contact data',);
            this.addressspinner = true;
            this.leadMap['First_Name__c'] = event.detail.selectedRecord.FirstName; //d
            this.leadMap['Last_Name__c'] = event.detail.selectedRecord.LastName;
            this.leadMap['Email__c'] = event.detail.selectedRecord.Email;
            this.leadMap['Billing_Street__c'] = this.accMap.BillingStreet != undefined ? this.accMap.BillingStreet.toUpperCase() : '';
            this.leadMap['Country__c'] = this.accMap.BillingCountry != undefined ? this.accMap.BillingCountry.toUpperCase() : '';
            this.leadMap['Billing_state__c'] = this.accMap.BillingState != undefined ? this.accMap.BillingState.toUpperCase() : '';
            this.leadMap['Billing_City__c'] = this.accMap.BillingCity != undefined ? this.accMap.BillingCity.toUpperCase() : '';
            this.leadMap['Mobile__c'] = event.detail.selectedRecord.MobilePhone; //d
            this.leadMap['Company__c'] = this.accMap.Name;
            this.leadMap['CE_CIS_Rating__c'] = this.accMap.CE_CIS_Rating__c;
            this.leadMap['Phakic_Rating__c'] = this.accMap.Phakic_Rating__c;
            this.leadMap['OwnerId'] = this.accMap.OwnerId;
            this.leadMap['SAP_Code__c'] = this.accMap.SAP_Code__c;
            this.leadMap['Contact_Name__c']=event.detail.selectedRecord.Id;
            this.addressspinner = false;
            this.createContact = false;
            
            console.log('In contact data',this.leadMap);
        }


    }
    if (data == 'contact') {
        console.log('in');
        this.addressspinner = true;
        this.createContact = true;
        this.leadMap['First_Name__c'] = this.accMap.Name; //d
        this.leadMap['Last_Name__c'] = this.accMap.Name;
        this.leadMap['Email__c'] = this.accMap.E_Mail__c;
        this.leadMap['Billing_Street__c'] = this.accMap.BillingStreet != undefined ? this.accMap.BillingStreet.toUpperCase() : '';
        this.leadMap['Country__c'] = this.accMap.BillingCountry != undefined ? this.accMap.BillingCountry.toUpperCase() : '';
        this.leadMap['Billing_state__c'] = this.accMap.BillingState != undefined ? this.accMap.BillingState.toUpperCase() : '';
        this.leadMap['Billing_City__c'] = this.accMap.BillingCity != undefined ? this.accMap.BillingCity.toUpperCase() : '';
        this.leadMap['Mobile__c'] = this.accMap.Phone;
        this.leadMap['Company__c'] = this.accMap.Name;
        this.leadMap['CE_CIS_Rating__c'] = this.accMap.CE_CIS_Rating__c;
        this.leadMap['Phakic_Rating__c'] = this.accMap.Phakic_Rating__c;
        this.leadMap['OwnerId'] = this.accMap.OwnerId;
        this.leadMap['SAP_Code__c'] = this.accMap.SAP_Code__c;
        this.leadMap['Contact_Name__c']=undefined;
        this.addressspinner = false;
    }
    if (data == 'account') {
        this.createContact = false;
        fireEvent(this.pageRef, "accountIdData", '');
        fireEvent(this.pageRef, "accountIdData", undefined);
        this.accountId = '';
        this.leadMap['First_Name__c'] = '' //d
        this.leadMap['Last_Name__c'] = '';
        this.leadMap['Email__c'] = '';
        this.leadMap['Billing_Street__c'] = '';
        this.leadMap['Country__c'] = '';
        this.leadMap['Billing_state__c'] = '';
        this.leadMap['Billing_City__c'] = '';
        this.leadMap['Mobile__c'] = ''; //d
        this.leadMap['Company__c'] = '';
        this.leadMap['CE_CIS_Rating__c'] = '';
        this.leadMap['Phakic_Rating__c'] = '';
        this.leadMap['Lead_Stage__c'] = '';
        this.leadMap['SAP_Code__c'] = '';
        this.leadMap['Billing_code__c'] = '';
        this.leadMap['Account__c']=undefined;
        this.accMap = new Map();
        this.createContact = false;
    }
    if ((this.leadUpdateMap != undefined && this.accCheckid == this.accountId && event.detail.selectedRecord.contact != 'contact') || (this.leadUpdateMap != undefined && data == 'account')) {
        this.addressspinner = true;
        if(this.leadUpdateMap.Contact!=undefined && data!='contact') {
            fireEvent(this.pageRef, "contId", this.leadUpdateMap.Contact);

        }
        console.log('In lead map',this.leadUpdateMap);
        this.leadMap['createddate'] = this.leadUpdateMap.createddate;
        this.leadMap['First_Name__c'] = this.leadUpdateMap.FirstName;
        this.leadMap['Last_Name__c'] = this.leadUpdateMap.lastName;
        this.leadMap['Email__c'] = this.leadUpdateMap.email;
        this.leadMap['Billing_Street__c'] = this.leadUpdateMap.billingStreet != undefined ? this.leadUpdateMap.billingStreet.toUpperCase() : '';
        this.leadMap['Country__c'] = this.leadUpdateMap.Country!= undefined ? this.leadUpdateMap.Country.toUpperCase() : '';
        this.leadMap['Billing_state__c'] = this.leadUpdateMap.BillingState != undefined ? this.leadUpdateMap.BillingState.toUpperCase() : '';
        this.leadMap['Billing_City__c'] = this.leadUpdateMap.billingCity != undefined ? this.leadUpdateMap.billingCity.toUpperCase() : '';
        this.leadMap['Mobile__c'] = this.leadUpdateMap.Mobile;
        this.leadMap['Account__c'] = this.accountId;
        this.leadMap['Company__c'] = this.leadUpdateMap.Company;
        this.leadMap['Product__c'] = this.leadUpdateMap.Product.toUpperCase();
        this.leadMap['Billing_code__c'] = this.leadUpdateMap.ZipCode;
        this.leadMap['Lead_Stage__c'] = this.leadUpdateMap.LeadStage;
        this.leadMap['Contact_Name__c'] = this.leadUpdateMap.Contact!=undefined ? this.leadUpdateMap.Contact: '';
        
        this.addressspinner = false;

    }
    this.getCountryWiseData(this.leadMap['Country__c'], this.leadMap['Billing_state__c'], 'false');

    if (this.accountId != undefined && this.accountId != '') {
        getAddressData({
            accounId: this.accountId
        }).then(result => {
            console.log('result address', result);
            this.accountAddress = result;
        }).catch(error => {
            console.log('error', error);
        })
    }
    console.log('lookup lead records', this.leadMap);




}
handleSelectLead(event) {
    this.leadType = '';
    this.leadType = event.target.value;
    console.log('Lead type', this.leadType);
}

//***********************************************added by gyadeen Ahirwar***************************************************************** */
handleNext() {
    let filterlist;
    let filterlists;

    getLightningPickListValues({})
        .then(result => {
            if (result) {
                this.leadSoruceList = result.Lead_Stage__c;
                console.log('leadSoruceList', this.leadSoruceList);
                this.billingCountryList = result.Country__c;
                // this.productList = result.data.Product__c;
                this.subjectList = result.Subject;
                this.meetingTypeList = result.Meeting_Type__c;
                this.callTypeList = result.Call_Type__c;
                this.spinner = false;

                if (this.leadType != '' && this.leadType != undefined) {
                    this.selectLead = false;

                    if (this.leadType == 'Upgrade') {
                        this.upgrade = true;
                        //*********************************************************************
                        if (this.upgrade === true) {
                            console.log('Test ----true:', this.upgrade);
                            filterlist = result.Lead_Stage__c.filter(Lead_Stage__c => Lead_Stage__c.value !== 'Commercialization');
                            this.leadSoruceList = filterlist || result.Lead_Stage__c;
                        }
                        //*********************************************************************
                        //this.upgrade = true;
                        this.existingLead = 'true';
                        this.newLead = 'false';
                        this.eventAddress = false;
                        this.showMeetingDetails = true;
                        if (this.userMap.Profile == 'System Administrator') {
                            this.sapCode = false;
                        } else {
                            this.sapCode = true;
                        }
                    } else {
                        console.log('Test ----false:', this.upgrade);
                        filterlists = result.Lead_Stage__c.filter(Lead_Stage__c => Lead_Stage__c.value !== 'Upgrade');
                        this.leadSoruceList = filterlists || result.Lead_Stage__c;
                        this.upgrade = false;
                        this.newLead = 'true';
                        this.existingLead = 'false';
                        this.eventAddress = true;
                        this.sapCode = false;
                    }
                }
            }
        })
        .catch(error => {
            console.error('Error fetching picklist values:', error);
        });
}
//***************************************************************Added by Gyadeen Ahirwar***************************************************** */
// handleNext() {
//     if (this.leadType != '' && this.leadType != undefined) {
//         this.selectLead = false;
//         if (this.leadType == 'Upgrade') {
//             this.upgrade = true;
//             this.existingLead = 'true';
//             this.newLead = 'false';
//             this.eventAddress = false;
//             this.showMeetingDetails = true;
//             if (this.userMap.Profile == 'System Administrator') {
//                 this.sapCode = false;
//             } else {
//                 this.sapCode = true;
//             }
//         } else {
//             this.upgrade = false;
//             this.newLead = 'true';
//             this.existingLead = 'false';
//             this.eventAddress = true;
//             this.sapCode = false;
//         }
//     }

// }
handleBack() {
    this.selectLead = true;
    this.upgrade = false;
}
handleShowContact() {
    if (this.accountId != '' && this.accountId != undefined) {
        this.showContact = true;
    } else {
        this.showContact = false;
    }
}
handleGetContactId(event) {
    this.spinner = true;
    console.log('contact Id', event.detail);
    if (event.detail != undefined) {
        fireEvent(this.pageRef, "contId", event.detail);
    }

    this.showContact = false;
    this.spinner = false;
}

showErrorMessage(meesage) {
    const evt = new ShowToastEvent({
        title: 'Error',
        message: meesage,
        variant: 'error',
        mode: 'dismissable'
    });
    this.dispatchEvent(evt);
}
showSuccessMessage(meesage) {
    const evt = new ShowToastEvent({
        title: 'success',
        message: meesage,
        variant: 'success',
        mode: 'dismissable'
    });
    this.dispatchEvent(evt);
}


getCountryWiseData(country, state, check) {
    if (country != '' && country != undefined) {
        getCountryMappingData({
            country: this.leadMap['Country__c']
        }).then(result => {
            this.addressspinner = true;
            console.log('result Country', result);
            this.productList = [];
            this.stateList = [];

            this.productList = result.Product;
            this.stateList = result.State;
            if (result.State == undefined) {
                this.leadMap['Billing_state__c'] = '';
                this.leadMap['Billing_City__c'] = '';
                this.cityList = [];
            }
            if (result.Product == undefined) {
                this.leadMap['Product__c'] = '';
            }

            this.addressspinner = false;
        }).catch(error => {
            console.log('error', error);
        })
        if (this.cityList == undefined) {
            this.leadMap['Billing_City__c'] = '';
        }
        if (this.stateList == undefined) {
            this.leadMap['Billing_state__c'] = '';
        }

    }
    if (state != '' && state != undefined) {
        getCityMappingData({
            state: this.leadMap['Billing_state__c']
        }).then(result => {
            console.log('result city', result);
            this.cityList = [];
            this.cityList = result.city;
            if (result.city == undefined) {
                this.leadMap['Billing_City__c'] = '';
            }
        }).catch(error => {
            console.log('error', error);
        })
    }
}


handleChangeLead(event) {
    console.log('Checked',event.target.checked);
    console.log('Current Id',event.currentTarget.dataset.id);
    if(event.target.checked) {
        this.leadEventList.push(event.currentTarget.dataset.id);
    }else {
    this.leadEventList.splice(this.leadEventList.indexOf(event.currentTarget.dataset.id));
    }
    console.log('Lead Event List',this.leadEventList);
}
}
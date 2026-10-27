/* eslint-disable no-console */
import { LightningElement, wire, api, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { fireEvent } from 'c/pubsub';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Domestic from '@salesforce/label/c.Domestic';
import getCurrentUser from '@salesforce/apex/calendarPlanningMobileController.getCurrentUser';
import getCustomlabel from '@salesforce/apex/calendarPlanningMobileController.getLabels';
import getAccountPlanRestrictions from '@salesforce/apex/calendarPlanningMobileController.getAccountPlanRestrictions';
import getUserClinicalVertical from '@salesforce/apex/calendarPlanningMobileController.getUserClinicalVertical';
export default class CustomerCard extends NavigationMixin(LightningElement) {

    @wire(CurrentPageReference) pageRef;
    customLabels = {
        Domestic
    }

   
    @track userregionname;
    @api region = '';
    @api account;
    @track openModal = false;
    @track selectedAcc;
    @track cisrating;
    @track cerating;
    @api labels = {};
    @track showDataAttribute;
    accountname;
    @track confirmation = false;
    @track confirmationmessage = {};
    //@track selectedAcc = this.account;

    //-------------------------------Added by yogi  start--------------------------------------------------//
    @track accountPlanRestrictions = {};
    @track restrictionMap = new Map();
//----------------------------------start changes by yogi 12/11/2025--------------------------------------------------//
     @track clinicalVertical = false;

      @wire(getUserClinicalVertical)
    wiredClinicalVertical({ error, data }) {
        if (data) {
            this.clinicalVertical = data.clinicalVertical;
            console.log('Clinical Vertical Status:', this.clinicalVertical);
        } else if (error) {
            console.error('Error fetching clinical vertical:', error);
        }
    }
//------------------------------End changes by yogi 12/11/2025----------------------------------------------------//




    @wire(getAccountPlanRestrictions)
    wiredRestrictions({ error, data }) {
        if (data) {
            console.log('Account Plan data:', JSON.stringify(data));

            this.restrictionMap = data;

            // data.forEach(restriction => {
            //     // Store the full record as-is
            //     this.restrictionMap.set(restriction.Name, restriction);
            // });

            console.log('Account Plan Restrictions Map:', this.restrictionMap);

        } else if (error) {
            console.error('Error fetching account plan restrictions:', error);
        }
    }

    //------------------------------End------------------------------------------------------------------------//
    @wire(getCustomlabel)
    getlabel(result) {
        this.spinner = true;
        if (result.data) {
            this.confirmationmessage = result.data;
            //console.log('Translation confirmationmessage', this.confirmationmessage);
            if (this.confirmationmessage != undefined) {
                this.spinner = false;
            }
        }
        if (result.error) {
            console.log('error', result.error);
        }
    }

    get name() {

        return this.account.Name;
    }
    @wire(getCurrentUser)
    wiredUser({ error, data }) {
        if (data) {
            this.user = data;
            //console.log("Current User ID: ", this.user.Id);
            this.userregionname = this.user.User_Type__c;

            //this.userregionname = this.user.User_Type__c;
        } else if (error) {
            console.error("Error fetching user: ", error);
        }
    }

    renderedCallback() {
        const style = document.createElement('style');
        style.innerText = `c-customer-card .slds-card {
            background-color: white;
            color: black;
            cursor: pointer;
            width: 340px;
            display: block;
            margin-left: 15px;
            margin-right: 15px;
            margin-bottom: 10px;
            border:0.5px solid black;
          
            border-radius: 20px 20px 20px 20px;
            //border-width: 0.5px;
            //border: 1px solid gray;
            /* border-color: rgb(181, 70, 10); */
            font-size: 17px;
            font-weight: 400;
            box-shadow: 1px 2px 7px 0px #707375db;
           // border-radius: 13px 13px 13px 13px;
        }`;
        this.template.querySelector('lightning-card').appendChild(style);

    }
    cardClick(event) {
        console.log("Account Id ", JSON.stringify(this.account));
        fireEvent(this.pageRef, 'ProductshowData', this.Product);
        this.accountname = this.account.Name;
        var contactList = false;

        // consol.log('Contact:',Account.contacts.name);

        if (this.account.Contacts != undefined) {
            var contacts = JSON.parse(JSON.stringify(this.account.Contacts));
            console.log('contacts ', contacts);
            contactList = contacts.map(val => {
                return { label: val.Name, value: val.Id }
            });
            console.log('contactList ', contactList);
        }
        console.log("cisrating ", event.currentTarget.dataset.cisrating);
        console.log("cerating ", event.currentTarget.dataset.cerating);
        this.cisrating = event.currentTarget.dataset.cisrating;
        this.cerating = event.currentTarget.dataset.cerating;






        this.showDataAttribute = event.currentTarget.dataset.show;
        console.log('showDataAttribute', this.showDataAttribute);

        var date1 = new Date(this.account.last_CE_date__c);
        var date2 = new Date();

        // To calculate the time difference of two dates
        var Difference_In_Time = date2.getTime() - date1.getTime();

        // To calculate the no. of days between two dates
        var Difference_In_Days = Difference_In_Time / (1000 * 3600 * 24);

        console.log("this.userregionname", this.userregionname);

        if ((this.customLabels.Domestic == this.region && ((this.cisrating == undefined || this.cerating == undefined || Difference_In_Days > 364) && this.account.RecordTypeName != 'Domestic-Distributor') && this.account.RecordType != undefined && (this.labels.Distributor__c != this.account.RecordType.DeveloperName)) || (this.cisrating == undefined || this.cerating == undefined) && ((((this.account.RecordTypeName == 'Domestic-Doctor/Hospital' || this.account.RecordTypeName == 'Domestic - Ortho') && this.account.RecordTypeName != 'Domestic-Distributor') && (this.account.show == 'Account' && this.account.show != undefined)) || (this.account.show == 'Lead' && (this.account.BillingCountry == 'INDIA' || this.account.BillingCountry == 'India')))) {
            //added by gyadeen------------------>

            if ((this.cisrating == undefined || this.cerating == undefined || Difference_In_Days > 364) && this.userregionname == 'Domestic Ortho') {


            } else {

                if (this.account.Lead == 'Lead' && this.account.Existing == false && this.account.status__c == false) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Address Approval',
                            message: this.confirmationmessage.Address_approval__c,
                            variant: 'warning'
                        })
                    );
                } else {
                    console.log('else----->115');
                    if (this.cisrating == undefined && this.cerating == undefined && this.account.Lead == 'Lead' && this.account.Existing == false) {
                        console.log('run -confirmation---->117-->true');
                        this.confirmation = true; // Show confirmation modal
                        return;
                    } else {
                        this.fireHandleShowCalendarEvent();
                    }
                    //fireEvent(this.pageRef, 'handleShowCalendar', { 'accountdata': this.account.Id, 'accountname': this.accountname, 'cerating': this.cerating, 'cisrating': this.cisrating, 'contactList': contactList, 'showDataAttribute': this.showDataAttribute, 'product': this.account.Product, 'contact': this.account.ContactName, 'customerCheck': this.account.Existing });

                }
                //added by gyadeen------------------>
                //fireEvent(this.pageRef, 'handleShowCalendar', {'accountdata':this.account.Id, 'accountname':this.accountname, 'cerating':this.cerating, 'cisrating':this.cisrating, 'contactList':contactList,'showDataAttribute':this.showDataAttribute,'product':this.account.Product,'contact':this.account.ContactName,'customerCheck':this.account.Existing});
                // this.dispatchEvent(
                //     new ShowToastEvent({
                //         title: 'CE Rating',
                //         message: 'Please complete the CE-CIS Rating and Approve it',
                //         variant: 'warning'
                //     })
                // );
            }
        } else {

            console.log('else----->139');
            if (this.account.Lead == 'Lead' && this.account.Existing == false && this.account.status__c == false) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Address Approval',
                        message: this.confirmationmessage.Address_approval__c,
                        variant: 'warning'
                    })
                );
            } else {
               
                console.log('this.account.sapcode', this.account.sapcode);
                console.log('this.account.branchaccount', this.account.branchaccount);
                // Assume restrictionMap me data jaise:
                // restrictionMap.get(account.Country) = { Name, Record_Type__c, Status__c, SAP_Code__c }

                console.log('Country Account:-->', this.account.BillingCountry);
                console.log('restrictionMap:-->', JSON.stringify(this.restrictionMap));

                const countryRestriction = this.restrictionMap[this.account.BillingCountry];
                console.log('countryRestriction:', countryRestriction);
//------------------------------If condition Added by yogi------------------------------------//
                if (this.clinicalVertical) {
                console.log('Clinical Vertical user - bypassing account restrictions');
                this.fireHandleShowCalendarEvent();
                return;
            }
//------------------------------If condition ended by yogi------------------------------------//
                if (!countryRestriction) {
                    console.log('No restriction found for', this.account.BillingCountry);
                }

                if (this.account.Account === 'Account' &&
                    this.account.branchaccount === 'false' &&
                    countryRestriction) {

                    const allowedRecordTypes = countryRestriction.Record_Type__c.split(',').map(rt => rt.trim());
                    const recordTypeMatch = allowedRecordTypes.includes(this.account.RecordTypeName);
                    console.log('recordTypeMatch:',this.recordTypeMatch);
                    const statusMismatch = this.account.status != countryRestriction.Status__c;

                    let sapCodeMissing = false;
                    if (this.account.sapcode === undefined) {
                        sapCodeMissing = countryRestriction.SAP_Code__c === true;
                    }

                    console.log('recordTypeMatch:', recordTypeMatch,
                        'statusMismatch:', statusMismatch,
                        'sapCodeMissing:', sapCodeMissing);

                    if (recordTypeMatch && (statusMismatch || sapCodeMissing)) {
                        console.log('Toast should fire now!');

                        const messageText = this.confirmationmessage?.SAP_code_not_configure_Or_Active_account__c
                            || 'SAP code not configured or account not active';

                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Validation Warning',
                                message: messageText,
                                variant: 'warning'
                            })
                        );
                    } else {
                        console.log('else----->248');
                        fireEvent(this.pageRef, 'handleShowCalendar', { 'accountdata': this.account.Id, 'accountname': this.accountname, 'cerating': this.cerating, 'cisrating': this.cisrating, 'contactList': contactList, 'showDataAttribute': this.showDataAttribute, 'product': this.account.Product, 'contact': this.account.ContactName, 'customerCheck': this.account.Existing });
                    }
                }


                else {
                    console.log('else----->149');
                    fireEvent(this.pageRef, 'handleShowCalendar', { 'accountdata': this.account.Id, 'accountname': this.accountname, 'cerating': this.cerating, 'cisrating': this.cisrating, 'contactList': contactList, 'showDataAttribute': this.showDataAttribute, 'product': this.account.Product, 'contact': this.account.ContactName, 'customerCheck': this.account.Existing });
                }


            }
        }




        //fireEvent(this.pageRef, 'refreshSearch', true);


    }
    handleContinue() {
        this.confirmation = false; // Close modal
        this.fireHandleShowCalendarEvent();
    }

    handleCancel() {
        this.confirmation = false; // Simply close the modal
    }

    fireHandleShowCalendarEvent() {
        fireEvent(this.pageRef, 'handleShowCalendar', {
            'accountdata': this.account.Id,
            'accountname': this.account.name,
            'cerating': this.cerating,
            'cisrating': this.cisrating,
            'contactList': this.contactList,
            'showDataAttribute': this.showDataAttribute,
            'product': this.account.Product,
            'contact': this.account.ContactName,
            'customerCheck': this.account.Existing
        });
    }
    closeModal() {
        this.openModal = false;
    }
    // newEntry() {
    //     this.openModal = false;
    //     let selectedAcc = this.account;
    //     console.log('selectedAcc',selectedAcc);
    //     fireEvent(this.pageRef, 'handleShow',selectedAcc);
    // }
    // addPackage() {
    //     this.openModal = false;
    //     this.selectedAcc = this.account;
    //     fireEvent(this.pageRef,'showPackage',this.selectedAcc);
    // }
}
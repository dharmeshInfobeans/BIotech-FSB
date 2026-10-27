/* eslint-disable vars-on-top */
/* eslint-disable no-console */
/* eslint-disable eqeqeq */
/**
 * @File Name          : createEvent.js
 * @Description        : 
 * @Author             : ChangeMeIn@UserSettingsUnder.SFDoc
 * @Group              : 
 * @Last Modified By   : ChangeMeIn@UserSettingsUnder.SFDoc
 * @Last Modified On   : 07-11-2020
 * @Modification Log   : 
 * Ver       Date            Author      		    Modification
 * 1.0    10/9/2019   Jyoti Singh     Initial Version
 **/
import {
    LightningElement,
    api,
    track,
    wire
} from 'lwc';
import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';
import createEvent from "@salesforce/apex/calendarPlanningMobileController.createEvent";
import getHolidayRecord from "@salesforce/apex/calendarPlanningMobileController.getHolidayRecord";
import getCallType from "@salesforce/apex/calendarPlanningMobileController.getCallType";
import getLevelTypeOptions from '@salesforce/apex/calendarPlanningMobileController.getLevelTypeOptions';
import getSubCallTypeOptions from '@salesforce/apex/calendarPlanningMobileController.getSubCallTypeOptions';

import getMeetingType from "@salesforce/apex/calendarPlanningMobileController.getMeetingType";
import getLeaveType from "@salesforce/apex/calendarPlanningMobileController.getLeaveType";
import getReviewCallType from "@salesforce/apex/calendarPlanningMobileController.getReviewCallType";
import getProducts from "@salesforce/apex/calendarPlanningMobileController.getProducts";
import getUsers from "@salesforce/apex/calendarPlanningMobileController.getUsers";
import updateEventBDPlan from "@salesforce/apex/calendarPlanningMobileController.updateEventBDPlan";
import Link_BD_Plan from '@salesforce/label/c.Link_BD_Plan';
import Selected_BD_Plans from '@salesforce/label/c.Selected_BD_Plans';
import Type_of_Planning from '@salesforce/label/c.Type_of_Planning';
import Plan_Week from '@salesforce/label/c.Plan_Week';
import Product from '@salesforce/label/c.Product';
import Contact from '@salesforce/label/c.Contact';
import MileStone_Stage from '@salesforce/label/c.MileStone_Stage';
import Plan_Year from '@salesforce/label/c.Plan_Year';
import CIS_Rating from '@salesforce/label/c.CIS_Rating';
import CE_Rating from '@salesforce/label/c.CE_Rating';
import New_DCR from '@salesforce/label/c.New_DCR';
import {
    CurrentPageReference
} from 'lightning/navigation';
import {
    registerListener,
    unregisterAllListeners,
    fireEvent
} from "c/pubsub";
import {  getPicklistValues } from 'lightning/uiObjectInfoApi';
import callType from '@salesforce/schema/Event.Account_Visit_Call_Type__c';
import MeetingType from '@salesforce/schema/Event.Meeting_Type__c';
import getAddressData from '@salesforce/apex/CustomLeadCreationController.getAddressData';

const columns = [
    { label: 'Select', fieldName: 'isSelect', type: 'checkbox' },
    { label: 'Date', fieldName: 'Date', type: 'date' },
    { label: 'Type', fieldName: 'Type', type: 'picklist' }

];
export default class CreateEvent extends LightningElement {
    @track subCallTypeOptions = [];

    @track uploadedFileName = '';




    holidaydata = [];
    columns = columns;
    levelTypeOptions = [];
    @track compensationDate = null;//changes by yogi

    customlabels = {
        Link_BD_Plan,
        Selected_BD_Plans,
        Type_of_Planning,
        Plan_Week,
        Product,
        Contact,
        MileStone_Stage,
        Plan_Year,
        CE_Rating,
        CIS_Rating,
        New_DCR
    };
    @wire(CurrentPageReference) pageRef;
    @api date;
    @track showProduct = false;
    productSelected = [];
    users_selected;
    users_selected_map = new Map();
    @track options;
    @track meetingOptions;
    @track leaveOptions;
    @track productsOptions;
    @track usersOptions;
    selected_account;
    selected_contact;
    @track isLeave = false;
    @track checkleveltype = true;
    @track isHoliday = false;
    @track isOutOfOffice = false;
    @track isCustomerVisit = false;
    @track addBdrMpdal = false;
    @track showJointAssignee = false;
    @track cofscreen = false;
    @track cofopenscreen = false;
    @track incliningbranding = false;
    @track subcalltype = false;
    @api accountId;
    @api labels;
    @api eventType;
    @api selectedValues;
    @track reviewCallOptions;
    @track selectedValue;
    fieldsMap = new Map();
    @track spinner = false;
    @track dateValueToShow;
    @track txtclassname = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
    @track saveButtonDisabled = false;

    @track callTypeOption;
    @track MeetingTypeOption;
    @track callTypeDisable = true;
    // @track fileData = {};
    @track subCallType = '';


    @track isPhakicTraining = false;
    @track selectedLevelType = false;
    @api productoptions;
    @api cisrating;
    @api cerating;
    @api contactoption;
    @api ownerid;
    @api bdplanlist;
    updateEventMap = new Map();
    selectedIdToUpdateBDPlan;
    @track cardtitle;
    @api accountname;
    @api showDataAttribute;
    @api productdata;
    @track adresslist = [];
    @track adressData = '--None--';
    @track currentAddress = '';
    @track selectedProduct = '';
    @api contactname;
    @track customercheck = false;
    @track showLevelTypeError = false;
    @track callType = '';
    @track productOptionsFromChild = [];
    @track enableproductoption = false;



    // Add this method to handle subCallType change

    handleSubCallTypeChange(event) {

        this.subCallType = event.target.value;

        this.enableproductoption = true;

    }





    handleProductOptionsChange(event) {

        console.log('Options from child:', event.detail);

        this.productOptions = event.detail;  // Now parent has dynamic options

    }



    // Method to fetch products based on subCallType



    // Add this method to load subCallType options imperatively

    loadSubCallTypeOptions() {

        getSubCallTypeOptions()

            .then(result => {

                console.log('Sub Call Type Options data---> : ', JSON.stringify(result));

                this.subCallTypeOptions = result;

                console.log('Sub Call Type Options:', this.subCallTypeOptions);

            })

            .catch(error => {

                console.error('Error fetching Sub Call Type picklist values:', error);

            });

    }



    @wire(getLevelTypeOptions)
    wiredLevelTypeOptions({ error, data }) {
        if (data) {
            // Map picklist values returned from Apex to format expected by template
            //this.levelTypeOptions = data.map(option => ({ label: option, value: option }));
            this.levelTypeOptions = Object.keys(data).map(label => {
                return {
                    label: label,      // Display label (e.g., "Sick Leave")
                    value: data[label] // API value (e.g., "SICK")
                };
            });
            console.log('this.levelTypeOptions', this.levelTypeOptions);
        } else if (error) {
            // Handle error
            console.error('Error fetching picklist values:', error);
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '0126F0000013zvNQAQ',
        fieldApiName: callType
    })
    slaFieldInfo({
        data,
        error
    }) {
        if (data) {
            this.callTypeData = data;
            console.log('this.callTypeData : ', this.callTypeData);
        }
    }
    @wire(getPicklistValues, {
        recordTypeId: '0126F0000013zvNQAQ',
        fieldApiName: MeetingType
    })
    upsellFieldInfo({
        data,
        error
    }) {
        if (data) this.MeetingTypeOption = data.values;
    }
    handleUpsellChange(event) {
        let key = this.callTypeData.controllerValues[event.target.value];
        this.callTypeOption = this.callTypeData.values.filter(opt => opt.validFor.includes(key));

    }




    @wire(getUsers)
    getUsers({
        error,
        data
    }) {
        if (error) {
            console.log("Error in getUsers");
            this.userOptions = null;
        } else if (data) {
            console.log(data);
            var userData = data;
            this.usersOptions = userData.map(val => {
                return {
                    label: val.Name,
                    value: val.Id
                }
            });
        }
    }

    @wire(getMeetingType)
    getMeetingType({
        error,
        data
    }) {
        if (error) {
            console.log("Error in getMeetingType");
            this.meetingOptions = null;
        } else if (data) {
            console.log(data);
            //var meetingTypeData = data;
            this.meetingOptions = Object.keys(data).map(label => {
                return {
                    label: label,
                    value: data[label]
                };
            });
            console.log('meetingOptions ', JSON.stringify(this.meetingOptions));
        }
    }

    @wire(getLeaveType)
    getLeaveType({
        error,
        data
    }) {
        if (error) {
            console.log("Error in getMeetingType");
            this.leaveOptions = null;
        } else if (data) {
            console.log(data);
            // var leaveOptions = data;
            this.leaveOptions = Object.keys(data).map(label => {
                return {
                    label: label,      // Display label (e.g., "Sick Leave")
                    value: data[label] // API value (e.g., "SICK")
                };
            });

            console.log('leaveOptions-----> ', this.leaveOptions);
        }
    }

    @wire(getReviewCallType)
    getReviewCallType({
        error,
        data
    }) {
        if (error) {
            console.log("Error in reviewCallOptions");
            this.reviewCallOptions = null;
        } else if (data) {
            console.log(data);
            //var leaveOptions = data;
            this.reviewCallOptions = Object.keys(data).map(label => {
                return {
                    label: label,      // Display label (e.g., "Sick Leave")
                    value: data[label] // API value (e.g., "SICK")
                };
            });
            console.log('reviewCallOptions ', this.reviewCallOptions);
        }
    }

    @wire(getCallType)
    getCallType({
        error,
        data
    }) {
        if (error) {
            console.log("Error in getCallType");
            this.options = null;
        } else if (data) {
            console.log(data);
            //var callTypeData = data;
            //console.log('Call type data',callTypeData);
            this.options = Object.keys(data).map(label => {
                return {
                    label: label,      // Display label (e.g., "Sick Leave")
                    value: data[label] // API value (e.g., "SICK")
                };
            });

            console.log('Call type options', this.options);
        }
    }

    contains(arr, value) {
        for (var i = 0; i < arr.length; i++) {
            if (arr[i] === value) {
                return true;
            }
        }
        return false;
    }

    // openfileUpload(event) {

    //     const file = event.target.files[0];

    //     console.log('file : ', JSON.stringify(file));

    //     var reader = new FileReader();



    //     reader.onload = () => {

    //         var base64 = reader.result.split(',')[1];



    //         this.fileData = {
    //             filename: file.name,
    //             base64: base64,
    //             recordId: this.recordId

    //         };

    //         this.fieldsMap['fileData'] = this.fileData;
    //         // ⭐ Set file name to show on input
    //         this.uploadedFileName = this.fileData.filename;

    //         console.log('OUTPUT : ', this.uploadedFileName);
    //         console.log(JSON.stringify(this.fileData));

    //     };
    //     reader.readAsDataURL(file);

    // }



    arrayRemove(arr, value) {

        return arr.filter(function (ele) {
            return ele != value;
        });

    }
    renderedCallback() {
        console.log('accountId ', this.accountId);
        console.log('selectedValues ', this.selectedValues);
        console.log('Show Data----', this.showDataAttribute);
        //registerListener("handleShowEventForm", this.handleShowEventFormFunction, this);
    }
    connectedCallback() {
        this.spinner = true;
        this.customercheck = false;
        this.selectedProduct = this.productdata;

        this.fieldsMap['relatedTo'] = '';
        this.fieldsMap['date'] = '';
        this.fieldsMap['subject'] = '';
        this.fieldsMap['MeetingType'] = '';
        this.fieldsMap['CallType'] = '';
        this.fieldsMap['levelType'] = '';
        this.fieldsMap['product'] = '';
        this.fieldsMap['jointassignee'] = '';
        this.fieldsMap['users'] = '';
        this.fieldsMap['notes'] = '';
        this.fieldsMap['leaveOptions'] = '';
        this.fieldsMap['reviewCallType'] = '';
        this.fieldsMap['contact'] = '';
        this.fieldsMap['ownerid'] = this.ownerid;
        this.fieldsMap['product'] = this.productdata;
        this.fieldsMap['subCallType'] = '';
        // this.fieldsMap['fileData'] = {};

        this.fieldsMap['Leveltype'] = ''; // Also add this for Phakic Training

        console.log('Product data', this.productdata);
        console.log('this.fieldsMap ', this.fieldsMap);
        console.log("Selected pro--- ", this.selectedProduct);
        console.log('connectedCallback date on Create-Event ', this.date);
        console.log('this.eventType ', this.eventType);
        console.log('contactoption ', this.contactoption);
        if (this.contactname != undefined) {
            this.customercheck = true;
        }
        if (this.date == undefined) {
            var today = new Date();
            var dd = today.getDate() < 10 ? '0' + today.getDate() : today.getDate();
            var mm = String(today.getMonth() + 1).padStart(2, '0'); //January is 0!
            var yyyy = today.getFullYear();

            today = mm + '/' + dd + '/' + yyyy;
            this.date = today;
        }
        getAddressData({ accounId: this.accountId }).then(result => {
            console.log('address list', result);
            this.adresslist = result;
            console.log('main address', this.adresslist[0].label);
            this.adressData = (this.adresslist.length > 0 && this.adresslist != undefined) ? this.adresslist[0].label : '';

        }).catch(error => {
            console.log('error', error);
        })
        console.log('bdplanlist ', this.bdplanlist);
        if (this.adresslist.length > 0 && this.adresslist != undefined && this.adressData != '--None--') {
            this.spinner = true;
        } else {
            this.spinner = false;
        }
        this.handleShowEventFormFunction();

    }

    handleSuccess(event) {
        const evt = new ShowToastEvent({
            title: "Event created",
            message: "Record ID: " + event.detail.id,
            variant: "success"
        });
        this.dispatchEvent(evt);
    }

    handleCancel() {
        fireEvent(this.pageRef, "cancelEvent", true);
        const cancelEvent = new CustomEvent(
            "cancel", {}
        );
        this.dispatchEvent(cancelEvent);

    }
    handleClickCheckbox(event) {
        console.log('Clicked ', event.target.checked);
        console.log('Id ', event.currentTarget.dataset.id);
        var selectedVal = event.currentTarget.dataset.id;
        this.bdplanlist = JSON.parse(JSON.stringify(this.bdplanlist));
        for (var item of this.bdplanlist) {
            if (event.currentTarget.dataset.id == item.Id) {
                item.isCheck = event.target.checked;
            }
        }
        console.log('this.bdplanlist ', this.bdplanlist);
        if (this.updateEventMap.has(selectedVal)) {
            this.updateEventMap.delete(selectedVal);
        } else {
            this.updateEventMap.set(selectedVal, selectedVal);
        }
        console.log('this.updateEventMap ', this.updateEventMap);
        this.selectedIdToUpdateBDPlan = Array.from(this.updateEventMap.values());
        console.log('selectedIdToUpdateBDPlan ', this.selectedIdToUpdateBDPlan);
    }

    // handleRecordSelected(event){
    //  if(event.detail.object == "Account"){
    //     this.selected_account = event.detail.recordId;
    //  }else if(event.detail.object == "Contact"){
    //     this.selected_contact = event.detail.recordId;
    //  }
    // }


    handleSelectProduct(data) {
        console.log('Selected Product Data ', data.detail);
        this.selectedProduct = data.detail;
    }

    handleSelectUser(data) {
        console.log('Selected User Data ', data.detail);
        this.users_selected = data.detail;
    }


    handleChangeField(event) {
        console.log('handleChangeField');
        console.log('Value ', event.target.value);
        console.log('Selected product', this.selectedProduct);
        console.log('Product data', JSON.stringify(this.productdata));

        console.log('calltype data:', this.fieldsMap['CallType']);

        console.log("fieldsMap ", this.fieldsMap);
        //console.log('this.fieldsMap[leaveoption]',this.fieldsMap['leaveOptions']);
        if (event.target.name == 'CallType') {

            this.callType = event.target.value;

            this.fieldsMap['CallType'] = this.callType;

            this.incliningbranding = this.callType == 'In Clinic Branding';

            if (this.callType == 'In Clinic Branding') {

                this.loadSubCallTypeOptions();

            } else {

                this.incliningbranding = false;

                this.subCallType = '';

                this.uploadedFileName = '';

                this.fieldsMap['subCallType'] = '';

                // this.fieldsMap['fileData'] = {};



                console.log('Call type', this.callType);

            }

        } else if (event.target.name == 'subCallType') {

            // Use the new method for subCallType change

            this.handleSubCallTypeChange(event);

            this.subCallType = event.target.value;

            this.fieldsMap['subCallType'] = this.subCallType;

        } else if (event.target.name == "Address") {
            this.currentAddress = event.target.value;
            console.log('Current Adress', this.currentAddress);
        } else if (event.target.name == "MeetingType") {
            if (event.target.value == 'select') {
                this.callTypeDisable = true;
                this.callTypeOption = [{
                    label: 'select',
                    value: 'select'
                }];
                this.fieldsMap[event.target.name] = '';
                this.incliningbranding = false;

                this.subCallType = '';

                this.uploadedFileName = '';

                this.fieldsMap['subCallType'] = '';

                // this.fieldsMap['fileData'] = {};
            } else {
                //this.fieldsMap['MeetingType'] = event.target.value;
                console.log('this.callTypeData---> ', JSON.stringify(this.callTypeData));
                let key = this.callTypeData.controllerValues[event.target.value];
                console.log('Key----', key);
                console.log('Call type option', this.callTypeOption);
                this.callTypeOption = this.callTypeData.values.filter(opt => opt.validFor.includes(key));
                console.log('this.callTypeOption ', this.callTypeOption);
                this.fieldsMap[event.target.name] = event.target.value;
                this.callTypeDisable = false;
            }
        }
        else if (event.target.name == "jointassignee") {
            this.fieldsMap[event.target.name] = event.target.checked;
            if (event.target.checked) {
                this.showJointAssignee = true;
            } else {
                this.showJointAssignee = false;
            }
        } else {
            this.fieldsMap[event.target.name] = event.target.value;
        }
        this.fieldsMap['relatedTo'] = this.accountId;
        this.fieldsMap['product'] = this.selectedProduct != undefined ? this.selectedProduct : '';
        this.fieldsMap['users'] = this.users_selected != undefined ? this.users_selected : '';
        this.fieldsMap['date'] = this.date;
        this.fieldsMap['subCallType'] = this.subCallType;
        console.log('this.fieldsMap leaveoption :', this.fieldsMap['leaveOptions']);
        if (this.fieldsMap['leaveOptions'] == 'Compensation off') {
            this.cofscreen = true;
        } else {
            this.cofscreen = false;
        }

        //****************Added Gyadeen  ************************* */
        if (this.fieldsMap['CallType'] == "Phakic Training") {
            this.isPhakicTraining = true;


        } else if (this.fieldsMap['CallType'] != "Phakic Training") {
            this.isPhakicTraining = false;
        }


    }

    handleSave() {
        this.saveButtonDisabled = true;
        var showPhakicError = false;
        this.fieldsMap['relatedTo'] = this.accountId;
        this.fieldsMap['product'] = this.selectedProduct != undefined ? this.selectedProduct : '';
        this.fieldsMap['users'] = this.users_selected != undefined ? this.users_selected : '';
        this.fieldsMap['date'] = this.date;
        this.fieldsMap['ownerid'] = this.ownerid;
        this.fieldsMap['subCallType'] = this.subCallType;
        this.fieldsMap['fileDate'] = this.fileDate;
        // if (this.fieldsMap['subCallType']) {
        //     // const fileObj = this.fieldsMap['fileData'];
        //     if (

        //         !fileObj ||
        //         !fileObj.filename ||
        //         !fileObj.base64 ||
        //         fileObj.base64.trim() === ''
        //     ) {
        //         this.dispatchEvent(
        //             new ShowToastEvent({
        //               title: 'Error',
        //                 message: 'Please upload the file',
        //                 variant: 'error'
        //             })

        //         );
        //         this.saveButtonDisabled = false;
        //         return;
        //     }
        // }



        if (this.fieldsMap['CallType'] != undefined && this.fieldsMap['product'] != undefined && this.fieldsMap['CallType'] == 'In Clinic Branding') {



        }

        var type = this.fieldsMap['eventType'];
        //console.log('Leveltype',this.fieldsMap['levelType']);
        var canSave = true;
        console.log('Call type', this.fieldsMap['CallType']);
        console.log('Product', this.fieldsMap['product']);

        if (this.fieldsMap['CallType'] != undefined && this.fieldsMap['product'] != undefined && this.fieldsMap['CallType'] == 'Phakic Training') {
            if (this.fieldsMap['product'].includes(';')) {
                this.fieldsMap['product'].split(';').forEach(Element => {
                    console.log('Element', Element);
                    if (!Element.includes('PHAKIC') && !Element.includes('Phakic')) {
                        showPhakicError = true;
                    }
                })
            } else {
                if (!this.fieldsMap['product'].includes('PHAKIC') && !this.fieldsMap['product'].includes('Phakic')) {
                    console.log('--->', this.fieldsMap['product']);
                    showPhakicError = true;

                }
            }
        }
        if (showPhakicError) {
            this.saveButtonDisabled = false
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error ',
                    message: 'Please select only Phakic Products',
                    variant: 'error'
                })
            );
            return;
        } else {


            if (type == 'Leave') {
                if (this.fieldsMap['notes'] == '' || this.fieldsMap['leaveOptions'] == '') {
                    canSave = false;
                }
            } else if (type == 'Holiday') {
                if (this.fieldsMap['notes'] == '') {
                    canSave = false;
                }
            } else if (type == 'Out of office') {
                if (this.fieldsMap['notes'] == '' || this.fieldsMap['reviewCallType'] == '') {
                    canSave = false;
                }
            } else if (type == 'Customer visit') {
                if (this.fieldsMap['subject'] == '' || this.fieldsMap['CallType'] == '' || this.fieldsMap['MeetingType'] == '' || this.fieldsMap['product'] == '') {
                    canSave = false;
                }
                // Validate subCallType when incliningbranding is true

                if (this.incliningbranding && (!this.fieldsMap['subCallType'] || this.fieldsMap['subCallType'] == '' || this.fieldsMap['subCallType'] == 'select')) {

                    canSave = false;

                }

            }
            console.log("canSave--2", canSave);
            console.log("fieldsMap---->", this.fieldsMap);
            console.log('CallType--->', this.fieldsMap['CallType']);
            console.log('leveltype', this.fieldsMap['Leveltype']);
            if (this.fieldsMap['CallType'] == "Phakic Training") {
                if (this.fieldsMap['Leveltype'] == "" || this.fieldsMap['Leveltype'] == "select" || this.fieldsMap['Leveltype'] == undefined) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error ',
                            message: 'please fill the Level type for Phakic training type',
                            variant: 'error'
                        })
                    );
                    this.checkleveltype = false;
                    canSave = false;

                }
                this.saveButtonDisabled = false;
                //  return;   

            }//n
            //fields.contactId = this.selected_contact;
            console.log("canSave--1", canSave);
            console.log("fieldsMap---> ", this.fieldsMap);
            console.log("canSave--2", canSave);
            if (canSave) {
                createEvent({
                    dataMap: this.fieldsMap,
                    eventAdress: this.currentAddress,
                    holidaydate: this.compensationDate
                })
                    .then(result => {
                        if (result == 'Success') {
                            console.log('Update opp ', result);
                            this.dispatchEvent(
                                new ShowToastEvent({
                                    title: 'Event Created',
                                    message: 'Event Created Successfully',
                                    variant: 'success'
                                })
                            );
                            const cancelEvent = new CustomEvent(
                                "cancel", {
                                detail: "save"
                            }
                            );
                            this.dispatchEvent(cancelEvent);
                            // fireEvent(this.pageRef, "cancelEvent", true); 
                            fireEvent(this.pageRef, "reloadEvents", this.date);
                            this.saveButtonDisabled = false;
                        }
                        if (result == 'error') {
                            this.dispatchEvent(
                                new ShowToastEvent({
                                    title: 'Error ',
                                    message: 'Please approved CE-CIS and Phakic rating before creating the events',
                                    variant: 'error'
                                })
                            );
                            this.saveButtonDisabled = false;

                        }

                        if (result == 'Address') {
                            this.dispatchEvent(
                                new ShowToastEvent({
                                    title: 'Error ',
                                    message: 'Please approved address before creating the events',
                                    variant: 'error'
                                })
                            );
                            this.saveButtonDisabled = false;

                        }
                        if (result == 'CECIS') {
                            this.dispatchEvent(
                                new ShowToastEvent({
                                    title: 'Error ',
                                    message: 'Please approved ce-cis and phakic rating before creating the events',
                                    variant: 'error'
                                })
                            );
                            this.saveButtonDisabled = false;

                        }
                        if (result == 'reject') {
                            this.dispatchEvent(
                                new ShowToastEvent({
                                    title: 'Error ',
                                    message: 'Please approved address and CE-CIS and phakic rating before creating the events',
                                    variant: 'error'
                                })
                            );
                            this.saveButtonDisabled = false;

                        }

                    })
                    .catch(error => {
                        console.log('error ', error);
                        this.dispatchEvent(
                            new ShowToastEvent({
                                message: error.body.message,
                                variant: 'error'
                            })
                        );
                    });
            } else {

                if (this.checkleveltype == true) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            message: 'Please fill the required field',
                            variant: 'warning'
                        })
                    );
                    this.saveButtonDisabled = false;
                }
            }
        }
    }


    setSelectedRecord(event) {
        var recId = event.currentTarget.dataset.id;
        var selectName = event.currentTarget.dataset.name;
        let newsObject = {
            'recId': recId,
            'recName': selectName
        };
        this.selectedRecords.push(newsObject);
        this.txtclassname = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
        let selRecords = this.selectedRecords;
        this.template.querySelectorAll('lightning-input').forEach(each => {
            each.value = '';
        });
        // const selectedEvent = new CustomEvent('selected', { detail: { selRecords }, });
        // // Dispatches the event.
        // this.dispatchEvent(selectedEvent);
    }

    removeRecord(event) {
        let selectRecId = [];
        for (let i = 0; i < this.selectedRecords.length; i++) {
            if (event.detail.name !== this.selectedRecords[i].recId)
                selectRecId.push(this.selectedRecords[i]);
        }
        this.selectedRecords = [...selectRecId];
        let selRecords = this.selectedRecords;
        // const selectedEvent = new CustomEvent('selected', { detail: { selRecords }, });
        // // Dispatches the event.
        // this.dispatchEvent(selectedEvent);
    }

    handleShowEventFormFunction() {
        this.spinner = true;
        var splitdate = this.date.split("/");
        console.log('splitdate ', splitdate);
        var day = splitdate[1];
        var mnth = splitdate[0];
        var year = splitdate[2];

        // if(day<10){
        //     day = '0'+day;
        // }
        // if(mnth<10){
        //     mnth = '0'+mnth;
        // }
        this.dateValueToShow = day + '/' + mnth + '/' + year;
        this.tempDate = year + '-' + mnth + '-' + day;
        console.log('dateValueToShow ', this.dateValueToShow);
        console.log('handleShowEventForm Date ', this.date);
        console.log('this.eventType-->', this.eventType);
        switch (this.eventType) {
            case 'Leave':
                this.cardtitle = this.labels.Leave__c + ' ' + this.labels.Details__c;
                this.isLeave = true;
                this.isHoliday = false;
                this.isOutOfOffice = false;
                this.isCustomerVisit = false;
                this.fieldsMap['eventType'] = 'Leave';
                break;
            case 'Holiday':
                this.cardtitle = this.labels.Holiday__c + ' ' + this.labels.Details__c;
                this.isLeave = false;
                this.isHoliday = true;
                this.isOutOfOffice = false;
                this.isCustomerVisit = false;
                this.fieldsMap['eventType'] = 'Holiday';
                break;
            case 'Out of office':
                this.cardtitle = this.labels.Out_Of_Office__c + ' ' + this.labels.Details__c;
                this.isLeave = false;
                this.isHoliday = false;
                this.isOutOfOffice = true;
                this.isCustomerVisit = false;
                this.fieldsMap['eventType'] = 'Out of office';
                break;
            case 'Customer visit':
                this.cardtitle = this.customlabels.New_DCR;
                this.isLeave = false;
                this.isHoliday = false;
                this.isOutOfOffice = false;
                this.isCustomerVisit = true;
                this.fieldsMap['eventType'] = 'Customer visit';
                break;
        }
        console.log('this.fieldsMap ', this.fieldsMap);
        this.spinner = false;
    }
    handleAddBdr() {
        this.addBdrMpdal = true;
    }

    handleSaveUpdateBDPlan() {
        updateEventBDPlan({
            selectedIdToUpdateBDPlan: this.selectedIdToUpdateBDPlan,
            action: 'Link'
        })
            .then(result => {
                console.log('updateEventBDPlan ', result);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'BD Plan Linked',
                        message: 'BD Plan Linked Successfully',
                        variant: 'success'
                    })
                );
                fireEvent(this.pageRef, "reloadBDPlanEvent", true);
                this.addBdrMpdal = false;
            })
            .catch(error => {
                console.log('error ', error);
                this.dispatchEvent(
                    new ShowToastEvent({
                        message: error.body.message,
                        variant: 'error'
                    })
                );
            });
    }

    closeModal() {
        this.addBdrMpdal = false;
    }
    holidaylist = [];
    handlenext() {
        getHolidayRecord({}).then(result => {
            console.log('---693---->Result ', result);
            this.holidaylist = result.holidays;
            // this.weeklydata = result.WeeklyOff;
            console.log('holidaylist', this.holidaylist);
        })
        this.isLeave = false;
        this.cofopenscreen = true;
        this.cofscreen = false;
        this.saveButtonDisabled = true;

    }

    @track selectedRowsData = [];
    handleRowSelection(event) {
        const selectionvalue = event.detail.selectedRows;

        selectionvalue.forEach(row => {
            this.compensationDate = row.Date;
        });


        console.log('this.selectedRowsData.length : ', this.selectedRowsData.length);
        console.log('selectionvalue : ', selectionvalue.length);
        if (selectionvalue.length > 1) {
            console.log('715');
            this.showToast('Error', 'Only one row can be selected at a time.', 'error');
            this.saveButtonDisabled = true;
        }
        if (selectionvalue.length > 0 && this.selectedRowsData.length > 0) {
            console.log('716 :');
            this.showToast('Error', 'Only one row can be selected at a time.', 'error');
            this.saveButtonDisabled = true;
            if (this.selectedRowsData.length == 1) {
                this.saveButtonDisabled = false;
            }

        } else {
            if (selectionvalue.length === 0 && this.selectedRowsData.length > 0) {
                console.log('714');
                this.selectedRowsData = selectionvalue;
                if (this.selectedRowsData.length > 1 || this.selectedRowsData.length == 0 || this.selectedRowsData.length == 1) {
                    this.saveButtonDisabled = true;
                }
            } else if (this.selectedRowsData.length == 0 && selectionvalue.length == 1) {
                console.log('719');
                this.selectedRowsData = selectionvalue;
                this.saveButtonDisabled = false;
            }
        }

        console.log('Selected Rows:**********--717', JSON.stringify(this.selectedRowsData));
    }
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }

}
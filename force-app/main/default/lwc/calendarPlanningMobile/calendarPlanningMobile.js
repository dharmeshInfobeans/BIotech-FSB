/* eslint-disable eqeqeq */
/* eslint-disable consistent-return */
/* eslint-disable vars-on-top */
/* eslint-disable no-unused-vars */
/* eslint-disable no-console */
// eslint-disable-next-line vars-on-top
/**
 * @File Name          : calendarPlanningMobile.js
 * @Description        : 
 * @Author             : ChangeMeIn@UserSettingsUnder.SFDoc
 * @Group              : 
 * @Last Modified By   : ChangeMeIn@UserSettingsUnder.SFDoc
 * @Last Modified On   : 07-09-2020
 * @Modification Log   : 
 * Ver       Date            Author      		    Modification
 * 1.0    10/9/2019   Jyoti Singh     Initial Version
**/
import { LightningElement, wire, track, api } from 'lwc';
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
import { registerListener, unregisterAllListeners, fireEvent } from "c/pubsub";
import getEvents from "@salesforce/apex/calendarPlanningMobileController.getEvents";
import getdailyactivity from "@salesforce/apex/calendarPlanningMobileController.getdailyactivity";//Added by Gyadeen
import refreshEvents from "@salesforce/apex/calendarPlanningMobileController.getEventsRefresh";
import getLabels from "@salesforce/apex/calendarPlanningMobileController.getLabels";
import getEventsForBDPlan from "@salesforce/apex/calendarPlanningMobileController.getEventsForBDPlan";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';//Added by Gyadeen

import { refreshApex } from "@salesforce/apex";
import getManagerAndReportee from "@salesforce/apex/calendarPlanningMobileController.getManagerAndReportee";
import Id from '@salesforce/user/Id';
import getRegionAndZone from '@salesforce/apex/calendarPlanningMobileController.getRegionAndZone';
import getloginlogoutmodule from '@salesforce/apex/CommonutiltiyClass.getCustomLabels';
import HelpDesk from '@salesforce/label/c.DCR_HelpDesk';
import DCR_past_date from '@salesforce/label/c.DCR_past_date';

export default class calendarPlanningMobile extends NavigationMixin(LightningElement) {
  @wire(CurrentPageReference) pageRef;
  @track customLabels = {
    HelpDesk, DCR_past_date
  }

  @track helpLable = '';
  @track spinner = true;
  @track getloginlogoutlabel = {};
  @track Activitydata;//Added by Gyadeen
  @track todaysEvent = [];
  @track todayFormatedDate = null;
  @track eventsDateArray;
  @track showModal = false;
  @track selectedDateEvent;
  @track showEvents = false;
  @track createEvent = false;
  @track noActiveEvent = true;
  @track activeEvent = false;
  @track selectedDateEvents = false;
  @track searchEventComponent = false;
  @track clickedDate = null;
  @track dateOnHeader = null;
  @track dateHeader = true;
  @track showDcr = false;
  @track usersOptions;
  @track showAccount = false;
  @track showCalendar = true;
  @track accountId;
  @track eventType;
  events;
  date;
  tdyEvent;
  @track skey = Id;
  @track labels;
  @track isEventCrete = true;
  @track cisrating;
  @track cerating;
  @track contactName;
  @track contactoption;
  @track userRegionSelectList;
  @track userZoneSelectList;
  @track bdplanlist;
  @track accountname;
  @track productData;
  @track customerName = '';
  @track customerCheck = false;


  @wire(getRegionAndZone)
  getRegionAndZone(result) {
    if (result.data) {
      console.log('getRegionAndZone data ', result.data);
      this.userRegionSelectList = result.data.userRegionSelectList;
      this.userZoneSelectList = result.data.userZoneSelectList

    }
  }


  @wire(getLabels)
  getLabels({ error, data }) {
    if (error) {
      console.log("Error in getUsers");
      this.labels = null;
    } else if (data) {
      console.log(data);
      this.labels = data;
      console.log('this.labels  ', this.labels);
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

  @wire(getManagerAndReportee)
  getManagerAndReportee({ error, data }) {
    this.spinner = true;
    if (error) {
      console.log("Error in getUsers");
      this.userOptions = null;
    } else if (data) {
      console.log(data);
      var userData = data;
      /*  this.usersOptions = userData.map(val =>{
         return {label:val.Name,value:val.Id}
         });*/
      this.usersOptions = data;
      console.log('usersOptions ', this.usersOptions);
    }
    this.spinner = false;
  }

  @wire(getdailyactivity)//Added by Gyadeen
  wiredData({ error, data }) {//Added by Gyadeen
    if (data) {//Added by Gyadeen
      //Added by Gyadeen
      this.Activitydata = data.activity;
      console.log('this.Activitydata', this.Activitydata);

    } else {
      //this.Activitydata = false;

    }

  }//Added by Gyadeen

  @wire(getEvents, { skey: '$skey' })
  wiredEvents(result) {
    if (result.data) {
      this.events = result;
      this.spinner = true;
      console.log("data", this.events.data);
      var dateMap = new Map();
      var arr = [];
      arr = this.events.data;
      for (var i in arr) {
        if (!dateMap.has(arr[i].VisitDate)) {
          dateMap.set(arr[i].VisitDate, 1);
        } else {
          var count = dateMap.get(arr[i].VisitDate);
          dateMap.set(arr[i].VisitDate, count + 1);
        }
      }
      this.eventsDateArray = dateMap;
      console.log("dateMap", this.eventsDateArray);
      var date = new Date();
      var todayDate = date.toLocaleDateString("en-US");
      console.log("Today Date ", todayDate);
      var splitdate = todayDate.split("/");
      console.log("Today's Splited Date ", splitdate);
      var day = splitdate[1];
      var mnth = splitdate[0];
      if (day < 10) {
        day = "0" + day;
      }
      if (mnth < 10) {
        mnth = "0" + mnth;
      }
      this.todayFormatedDate = splitdate[2] + "-" + mnth + "-" + day;
      this.dateOnHeader = day + '-' + mnth + '-' + splitdate[2];
      console.log("Today's formated Date ", this.todayFormatedDate);
      this.todaysEvent = this.events.data.filter((value) => {
        return value.VisitDate == this.todayFormatedDate;
      });
      console.log('todaysEvent ', this.todaysEvent);
      if (!this.selectedDateEvents) {
        this.activeEvent = true;
      } else {
        this.activeEvent = false;
      }
      this.noActiveEvent = false;
      console.log('activeEvent 85 ', this.activeEvent);
      //this.showCalendar = true;
      this.spinner = false;
    } else if (result.error) {
      console.log(result.error);
    }

  }

  handleRefresh() {
    refreshEvents({ skey: this.skey })
      .then(result => {
        this.events = result;
        this.spinner = true;
        console.log("data", this.events);
        var dateMap = new Map();
        var arr = [];
        arr = this.events;
        for (var i in arr) {
          if (!dateMap.has(arr[i].VisitDate)) {
            dateMap.set(arr[i].VisitDate, 1);
          } else {
            var count = dateMap.get(arr[i].VisitDate);
            dateMap.set(arr[i].VisitDate, count + 1);
          }
        }
        this.eventsDateArray = dateMap;
        console.log("dateMap", this.eventsDateArray);
        var date = new Date();
        var todayDate = date.toLocaleDateString("en-US");
        console.log("Today Date ", todayDate);
        var splitdate = todayDate.split("/");
        console.log("Today's Splited Date ", splitdate);
        var day = splitdate[1];
        var mnth = splitdate[0];
        if (day < 10) {
          day = "0" + day;
        }
        if (mnth < 10) {
          mnth = "0" + mnth;
        }
        this.todayFormatedDate = splitdate[2] + "-" + mnth + "-" + day;
        this.dateOnHeader = day + '-' + mnth + '-' + splitdate[2];
        console.log("Today's formated Date ", this.todayFormatedDate);
        this.todaysEvent = this.events.filter((value) => {
          return value.VisitDate == this.todayFormatedDate;
        });
        console.log('todaysEvent ', this.todaysEvent);
        if (!this.selectedDateEvents) {
          this.activeEvent = true;
        } else {
          this.activeEvent = false;
        }
        this.noActiveEvent = false;
        console.log('activeEvent 85 ', this.activeEvent);
        //this.showCalendar = true;
        this.spinner = false;
        alert('Event Refreshed !');
      })
      .catch(error => {
        console.log(error);
      })
  }


  connectedCallback() {
    console.log('Dcr ', this.customLabels.EvenDate);
    this.helpLable = this.customLabels.HelpDesk + ' ' + DCR_past_date + ' days';
    console.log('Helpable', this.helpLable);
  }
  renderedCallback() {
    registerListener(
      "reloadEvents",
      this.refreshAllEventData,
      this
    );
    registerListener("handleShowCalendar", this.handleShowCalendar, this);
    registerListener("selectedDate", this.selectedDate, this);
    if (this.clickedDate != null) {
      var splitdate = String(this.clickedDate).split("-");
      //this.dateOnHeader = splitdate[2]+'-'+splitdate[1]+'-'+splitdate[0];
      //console.log('this.dateOnHeader 168 ',this.dateOnHeader);
    } else {
      var splitdate = String(this.todayFormatedDate).split("-");
      //this.dateOnHeader = splitdate[2]+'-'+splitdate[1]+'-'+splitdate[0];
      //console.log('this.dateOnHeader 172 ',this.dateOnHeader);
    }
  }

  disconnectedCallback() {
    unregisterAllListeners(this);
  }

  handleShowCalendar(data) {
    this.contactName = '';
    this.customerCheck = false;
    console.log('data handleShowCalendar ', data);
    this.productData = data.product;
    console.log('FInally product', this.productData);
    console.log('Contact Name', data.contact);
    console.log('Customer Check', data.customerCheck);
    this.customerName = data.contact;
    this.customerCheck = data.customerCheck;
    this.contactName = data.ContactName;
    console.log('Contact name data--', this.contactName);
    if (data.accountdata == 'Leave' || data.accountdata == 'Holiday' || data.accountdata == 'Out of office') {
      this.eventType = data.accountdata;
      this.showCalendar = false;
      this.showAccount = false;
      this.createEvent = false;
      this.createEvent = true;
      this.accountname = data.accountname;
    } else {
      this.eventType = 'Customer visit';
      this.accountId = data.accountdata;

      getEventsForBDPlan({ accountid: this.accountId, userid: this.skey, action: 'create' })
        .then(result => {
          console.log('Result++++++++++++++> ', result);
          this.bdplanlist = JSON.parse(JSON.stringify(result));
          console.log('getEventsForBDPlan bdplanlist ', this.bdplanlist);
          this.contactoption = data.contactList;
          //  this.contactName = data.contactName;
          //  console.log('contactName',this.contactName); // Added by Gyadeen Ahirwar
          console.log('contactoption=========>', this.contactoption);// added by Gyadeen ahirwar*************************
          if (data.cerating != undefined) {
            this.cerating = data.cerating;
          } else {
            this.cerating = '';
          }

          if (data.Product != undefined) {
            this.productData = data.Product;
            console.log('Product data', this.productData);
          }
          if (data.cisrating != undefined) {
            this.cisrating = data.cisrating;
          } else {
            this.cisrating = '';
          }
          this.accountname = data.accountname;
          this.showCalendar = false;
          this.showAccount = false;
          this.createEvent = false;
          this.createEvent = true;

        })
        .catch(error => {
          console.log('error ', error);
        });

    }
  }

  //  clickBack(bool) {
  //    if (bool) {
  //      this.showModal = false;
  //      this.showEvents = false;
  //      this.createEvent = false;
  //      //this.showCalendar = true;
  //      this.searchEventComponent = false;
  //      this.dateHeader = false;
  //    }
  //  }

  refreshAllEventData(date) {
    //  if (this.selectedDateEvent != undefined) {
    //    if (this.selectedDateEvent.length > 0) {
    //      this.selectedDateEvents = true;
    //      console.log('selectedDateEvents 131 ',this.selectedDateEvents);
    //      this.noActiveEvent = false;
    //    } else {
    //      this.noActiveEvent = true;
    //      this.selectedDateEvents = false;
    //      console.log('selectedDateEvents 136 ',this.selectedDateEvents);
    //    }
    //  } else {
    //    this.noActiveEvent = true;
    //  }
    console.log("Call selectedDate, date ", date);
    //this.selectedDate(date);
    refreshApex(this.events);
    fireEvent(this.pageRef, 'reloadComponent', true);
    this.spinner = true;
    this.handleShowEvent(true);
    this.spinner = false;
  }

  handleShowEvent(bool) {
    if (bool) {
      this.spinner = true;
      this.showModal = false;
      this.showEvents = false;
      this.createEvent = false;
      this.showCalendar = true;
      //this.showCalendar = true;
      this.searchEventComponent = false;
      this.dateHeader = true;
      console.log('this.todaysEvent ', this.todaysEvent);
      console.log('this.selectedDateEvent ', this.selectedDateEvent);
      if (this.todaysEvent != undefined && this.todaysEvent.length > 0) {
        this.selectedDateEvents = false;
        console.log('selectedDateEvents 159 ', this.selectedDateEvents);
        this.activeEvent = true;
        console.log('activeEvent 158 ', this.activeEvent);
        this.noActiveEvent = false;
        console.log("this.todaysEvent");
        var splitdate = this.todayFormatedDate.split("-");
        this.dateOnHeader = splitdate[2] + '-' + splitdate[1] + '-' + splitdate[0];
        console.log('this.dateOnHeader 259 ', this.dateOnHeader);
      } else if (this.selectedDateEvent != undefined && this.selectedDateEvent.length > 0) {
        this.selectedDateEvents = true;
        console.log('selectedDateEvents 166 ', this.selectedDateEvents);
        this.noActiveEvent = false;
        this.activeEvent = false;
        console.log('activeEvent 165 ', this.activeEvent);
        console.log("this.selectedDateEvent");
      } else {
        this.noActiveEvent = true;
        this.selectedDateEvents = false;
        console.log('selectedDateEvents 174 ', this.selectedDateEvents);
        console.log("else on cancel");
      }
    }
    this.spinner = false;
  }

  selectedDate(date) {
    console.log('Selected Date Function ', date);
    this.date = date.date;
    var last6Days = new Date();
    var pastData = DCR_past_date.replace('-', '');
    last6Days.setDate(last6Days.getDate() - (parseInt(pastData) + 1));
    if (date.fulldate <= last6Days) {
      console.log('less then');
      this.isEventCrete = false;
    } else {
      this.isEventCrete = true;
      console.log('greater then');
    }
    var splitdate = String(date.date).split("-");
    //this.dateOnHeader = splitdate[2]+'-'+splitdate[1]+'-'+splitdate[0];
    // console.log('this.dateOnHeader 291 ',this.dateOnHeader);
    //  this.showCalendar = false;
    this.showModal = true;
    this.ShowEvent(date.date);
  }

  handleCancel(event) {
    console.log("cancel");
    this.dateHeader = true;
    this.createEvent = false;

    if (!event.detail) {
      this.handleShowEvent(true);
    } else {
      console.log("else on cancel");
    }
    return refreshApex(this.tdyEvent);
  }
  closeModal() {
    this.showModal = false;
  }
  showAccountComponent() {
    console.log('this.Activitydata', this.Activitydata);//Added by Gyadeen
    if (!this.Activitydata) {//Added by Gyadeen
      this.showToast(
        this.getloginlogoutlabel.Warning__c,
        this.getloginlogoutlabel.Kindly_do_the_Login_before_performing_th__c,
        this.getloginlogoutlabel.Warning__c);//Added by Gyadeen
      return;//Added by Gyadeen
    } else {//Added by Gyadeen

      this.showCalendar = false;
      this.showAccount = true;

      this.showEvents = false;
      this.activeEvent = false;
      this.noActiveEvent = false;
      this.selectedDateEvents = false;
      this.dateHeader = false;
    }
  }

  newEvent() {
    this.showEvents = false;
    this.createEvent = true;
    this.showCalendar = false;
    this.activeEvent = false;
    console.log('activeEvent 216 ', this.activeEvent);
    this.noActiveEvent = false;
    this.searchEventComponent = false;
    this.selectedDateEvents = false;
    console.log('selectedDateEvents 227 ', this.selectedDateEvents);
    this.dateHeader = false;
    fireEvent(this.pageRef, 'handleShowEventForm', true);
  }
  ShowEvent(date) {
    var formatedDate = "";
    var splitdate = date.split("/");
    console.log("Splited Date ", splitdate);
    this.dateOnHeader = splitdate[1] + '-' + splitdate[0] + '-' + splitdate[2];
    var day = splitdate[1];
    var mnth = splitdate[0];
    if (day < 10) {
      day = "0" + splitdate[1];
    }
    if (mnth < 10) {
      mnth = "0" + splitdate[0];
      console.log("Month ", mnth);
    }
    formatedDate = splitdate[2] + "-" + mnth + "-" + day;

    console.log("Formated Date ", formatedDate);
    this.clickedDate = formatedDate;
    console.log("Event Variable ", this.events.data);
    this.selectedDateEvent = this.events.data.filter((value) => {
      return value.VisitDate == formatedDate;
    });

    console.log("Selected date Event ", this.selectedDateEvent);

    if (this.selectedDateEvent.length > 0) {
      this.selectedDateEvents = true;
      console.log('selectedDateEvents 255 ', this.selectedDateEvents);
      this.activeEvent = false;
      console.log('activeEvent 249 ', this.activeEvent);
      this.noActiveEvent = false;
      this.createEvent = false;
      //this.showCalendar = true;
      this.searchEventComponent = false;
      this.dateHeader = true;
    } else {
      this.selectedDateEvents = false;
      console.log('selectedDateEvents 266 ', this.selectedDateEvents);
      this.activeEvent = false;
      console.log('activeEvent 258 ', this.activeEvent);
      this.noActiveEvent = true;
      this.createEvent = false;
      //this.showCalendar = true;
      this.searchEventComponent = false;
      this.dateHeader = true;
    }

    return refreshApex(this.allEventData);
  }
  handleSearch() {
    this.searchEventComponent = true;
    this.selectedDateEvents = false;
    console.log('selectedDateEvents 280 ', this.selectedDateEvents);
    this.activeEvent = false;
    console.log('activeEvent 272 ', this.activeEvent);
    this.noActiveEvent = false;
    this.createEvent = false;
    //this.showCalendar = false;
    this.dateHeader = true;
  }
  clickDcr() {
    this.showEvents = false;
    this.createEvent = false;
    //this.showCalendar = false;
    this.activeEvent = false;
    console.log('activeEvent 283 ', this.activeEvent);
    this.noActiveEvent = false;
    this.searchEventComponent = false;
    this.selectedDateEvents = false;
    console.log('selectedDateEvents 298 ', this.selectedDateEvents);
    this.dateHeader = false;
    this.showDcr = true;
  }

  clickBack() {
    this.showCalendar = true;
    this.showAccount = false;
    this.handleShowEvent(true);
    //  fireEvent(this.pageRef, "homeScreen", true);
  }

  handleChangeUser(event) {
    this.spinner = true;
    this.skey = event.target.value; // this is your user id
    console.log('Selected User ID: ', this.skey);

    // delay logic
    this.timeoutId = setTimeout(() => {
      this.afterDelay();

      // Fire the user selection event
      fireEvent(this.pageRef, 'userSelected', {
        userId: this.skey
      });
    }, 500);
  }

  afterDelay() {
    this.spinner = false;
  }

  showToast(title, message, variant) { //Added toast message by Gyadeen
    this.dispatchEvent(
      new ShowToastEvent({
        title: title,
        message: message,
        variant: variant
      })
    );
  }
}
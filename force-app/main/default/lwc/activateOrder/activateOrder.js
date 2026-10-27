import { LightningElement, api, track, wire } from "lwc";
import fetchDetails from "@salesforce/apex/ActivateOrderController.fetchDetails";
import fillOrderConsignDetail from "@salesforce/apex/ActivateOrderController.fillOrderConsignDetail";
import areOrderProductsSelected from "@salesforce/apex/ActivateOrderController.areOrderProductsSelected";
import checkOrderStatusforConsignee from "@salesforce/apex/ActivateOrderController.checkOrderStatusforConsignee";
import getPicklistValues from "@salesforce/apex/ActivateOrderController.getPicklistValues";

import { ShowToastEvent } from "lightning/platformShowToastEvent";
import Order_has_been_Activated_and_send_for_approval from "@salesforce/label/c.Order_has_been_Activated_and_send_for_approval";
import Order_can_only_be_activated_from_draft_Stage from "@salesforce/label/c.Order_can_only_be_activated_from_draft_Stage";
import Please_add_products_before_activating_the_order from "@salesforce/label/c.Please_add_products_before_activating_the_order";
import Order_can_be_activated_only_after_freight_is_entered from "@salesforce/label/c.Order_can_be_activated_only_after_freight_is_entered";
//import NoConsigneeAfterFreighthtRequest from "@salesforce/label/c.NoConsigneeAfterFreighthtRequest";
import { NavigationMixin } from 'lightning/navigation';
// import { getRecord, getFieldValue } from "lightning/uiRecordApi";
// import ORDER_STATUS from "@salesforce/schema/Order__c.Status__c";
// const fields = [ORDER_STATUS];

export default class ActivateOrder extends NavigationMixin(LightningElement) {
  @api orderId; // Pass the record Id from parent component

  // @wire(getRecord, { recordId: "$recordId", fields })
  // orderObj;

  // get status() {
  // 	return getFieldValue(this.orderObj.data, ORDER_STATUS);

  // }
  label = {
    Order_has_been_Activated_and_send_for_approval,
    Order_can_only_be_activated_from_draft_Stage,
    Please_add_products_before_activating_the_order,
    Order_can_be_activated_only_after_freight_is_entered
    //NoConsigneeAfterFreightRequest
  };

  errorMessageToDisplay = "";

  @track shippingAddress = [];
  @track shipCodeoptions;
  @track error;
  @track contactSelected;
  @track selectedConName;
  @track destination;
  @track city;
  @track street;
  @track state;
  @track country;
  @track zipCode;
  @track telephone;
  @track selectedDispatchMode;
  orderMessage = "On order activation, you can not add/modify order products";
  @track dispatchOptions = [];

  connectedCallback() {
    console.log('connectedCallback : ',);
    let fieldNames = ["Dispatch_Through__c"];
    getPicklistValues({ objectApiName: "Order__c", fieldApiNames: fieldNames })
      .then((result) => {
        console.log('result : ', result);
        this.dispatchOptions = result['Dispatch_Through__c'];
      })
      .catch((error) => {
        console.error('Error', error);
      })
    try {
      console.log("orderId::", this.orderId);
      checkOrderStatusforConsignee({ orderId: this.orderId })
        .then((statusResult) => {
          if (statusResult) {
            areOrderProductsSelected({ orderId: this.orderId })
              .then((result) => {
                console.log(JSON.stringify(result));
                if (!result) {
                  const event = new ShowToastEvent({
                    title: "Error Toast message",
                    message:
                      this.label.Please_add_products_before_activating_the_order,
                    variant: "error",
                    mode: "sticky"
                  });
                  this.dispatchEvent(event); // Handle the error appropriately, e.g., display an toast
                  const closeAuraEvent = new CustomEvent("closemodal", {
                    detail: {}
                  });
                  this.dispatchEvent(closeAuraEvent);
                } else {
                  fetchDetails({ orderId: this.orderId })
                    .then((result) => {
                      console.log('BG >>> result : ' + result);
                      this.shippingAddress = JSON.parse(JSON.stringify(result));
                      console.log("adress::", JSON.stringify(this.shippingAddress));
                      this.error = undefined;
                      let options = [];
                      for (var key in result) {
                        // Here key will have index of list of records starting from 0,1,2,....
                        if (result[key].Contact_Person__c) {
                          options.push({
                            label: result[key].Contact_Person__c + " (" + result[key].SAP_Code__c + ")",
                            value: result[key].Id
                          });
                        }

                        // Here Name and Id are fields from sObject list.
                      }
                      console.log("options::", options);
                      this.shipCodeoptions = options;
                    })
                    .catch((error) => {
                      this.error = error;
                      this.shippingAddress = undefined;
                      console.log("error", this.error);
                    });
                }
              })
          }
          else {
            const errorevent = new ShowToastEvent({
              title: "Error Toast message",
              message:
                "Consignee can only be added before requesting freight amount.",
              //this.label.NoConsigneeAfterFreighthtRequest,
              variant: "error",
              mode: "sticky"
            });
            this.dispatchEvent(errorevent); // Handle the error appropriately, e.g., display an toast
            const closeAuraEvent = new CustomEvent("closemodal", {
              detail: {}
            });
            this.dispatchEvent(closeAuraEvent);
          }
        })
        .catch((error) => {
          this.error = error;
          console.log("error", this.error);
        });
    } catch (error) {
      console.log(error);
    }
  }
  //console.log('recordId' + recordId);
  handleContactChange(event) {
    console.log("inside contact change");
    this.contactSelected = event.detail.value;
    console.log("id::", this.contactSelected);
    let addressDetail = this.shippingAddress.find(
      (element) => element.Id === this.contactSelected
    ); // Use .find() to get the first matching element
    console.log("address::", JSON.stringify(addressDetail));
    if (addressDetail) {
      this.city = addressDetail.ShippingCity;
      this.street = addressDetail.ShippingStreet;
      this.state = addressDetail.ShippingState;
      this.country = addressDetail.ShippingCountry;
      this.zipCode = addressDetail.ShippingPostalCode;
      this.telephone = addressDetail.First_mobile_telephone_no__c;
      this.selectedConName = addressDetail.Contact_Person__c;
      this.ConsigneeNameSelected = addressDetail.Name;
      this.destination = addressDetail.ShippingCity;
      this.consigneeCode = addressDetail.SAP_Code__c;
      //console.log('this.city', this.city);
    }
  }
  handleDispatchChnage(event) {
    this.selectedDispatchMode = event.detail.value;
    console.log(
      "selectedDispatchMode in handleChange",
      this.selectedDispatchMode
    );
  }
  handleDestination(event) {
    this.destination = event.detail.value;
  }

  navigateToNewAccountPage() {
    const closeAuraEvent = new CustomEvent("closemodal", {
      detail: {}
    });
    this.dispatchEvent(closeAuraEvent);
    this[NavigationMixin.Navigate]({
      type: 'standard__objectPage',
      attributes: {
        objectApiName: 'Account',
        actionName: 'new'
      },
    });
  }
  sendDataToApex() {
    console.log(
      "sendDataToApex::selectedDispatchMode",
      this.selectedDispatchMode
    );

    console.log("sendDataToApex ::this.destination", this.destination);

    const dataWrapper = {
      Id: this.orderId,
      selectedConName: this.selectedConName,
      consigneeNameSelected: this.ConsigneeNameSelected,
      destination: this.destination,
      city: this.city,
      street: this.street,
      state: this.state,
      country: this.country,
      zipCode: this.zipCode,
      telephone: this.telephone,
      selectedDispatchMode: this.selectedDispatchMode,
      consigneeCode: this.consigneeCode
    };
    return JSON.stringify(dataWrapper);
  }

  handleSave() {
    console.log("inside save");
    console.log(this.status);
    console.log("inside contact selected", this.contactSelected);
    if (this.selectedDispatchMode != null) {
      if (this.contactSelected != null) {
        let orderDetail = this.sendDataToApex();
        fillOrderConsignDetail({ orderDetail: orderDetail }) // Use orderDetail variable here, not this.orderDetail
          .then((result) => {
            console.log("result" + result);
            console.log(result);
            //closing the component
            const closeAuraEvent = new CustomEvent("closemodal", {
              detail: {}
            });
            this.dispatchEvent(closeAuraEvent);
            const event = new ShowToastEvent({
              title: "Success Toast message",
              message: this.label.Order_has_been_Activated_and_send_for_approval,
              variant: "success",
              mode: "sticky"
            });
            this.dispatchEvent(event);
            location.reload();
          })
          .catch((error) => {
            let finalError = "";
            console.log("error==>", JSON.stringify(error));
            if (
              error.body.duplicateResults &&
              error.body.duplicateResults.length > 0
            ) {
              finalError = error.body.duplicateResults.map((e) => e.message);
            } else if (
              error.body.fieldErrors &&
              error.body.fieldErrors.length > 0 &&
              Array.isArray(error.body.fieldErrors)
            ) {
              finalError = error.body.fieldErrors.map((e) => e.message);
            } else if (
              error.body.pageErrors &&
              error.body.pageErrors.length > 0 &&
              Array.isArray(error.body.pageErrors)
            ) {
              finalError = error.body.pageErrors.map((e) => e.message);
            } else if (Array.isArray(error.body)) {
              finalError = error.body.map((e) => e.message);
            }
            // UI API DML, Apex and network errors
            else if (error.body && typeof error.body.message === "string") {
              finalError = error.body.message;
            }
            // JS errors
            else if (typeof error.message === "string") {
              finalError = error.message;
            } else {
              // Unknown error shape so try HTTP status text
              finalError = error.statusText;
            }
            console.log(JSON.stringify(finalError));
            const event = new ShowToastEvent({
              title: "Error Toast message",
              // message: this.label.Order_can_only_be_activated_from_draft_Stage,
              message: finalError[0],
              variant: "error",
              mode: "sticky"
            });
            this.dispatchEvent(event); // Handle the error appropriately, e.g., display an toast
            const closeAuraEvent = new CustomEvent("closemodal", {
              detail: {}
            });
            this.dispatchEvent(closeAuraEvent);
          });
      }
      else {
        // console.log("inside error");
        // const event = new ShowToastEvent({
        // 			title: 'Error Toast message',
        // 			message: 'Please Select Contact Person From Model Window',
        // 			variant: 'error',
        // 		});
        // 		this.dispatchEvent(event);
        // 		const closeAuraEvent = new CustomEvent('closemodal', {
        // 			detail: {}
        // 		});
        // 		this.dispatchEvent(closeAuraEvent);
      }
    }
    else {
      const event = new ShowToastEvent({
        title: "Error Toast message",
        message: "Dispatch through is required",
        variant: "error",
        mode: "sticky"
      });
      this.dispatchEvent(event);
    }

  }

  handleCancel() {
    const closeAuraEvent = new CustomEvent("closemodal", {
      detail: {}
    });
    this.dispatchEvent(closeAuraEvent);
  }
}
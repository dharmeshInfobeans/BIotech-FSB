import { LightningElement, api, track, wire } from "lwc";
import activateOrder from "@salesforce/apex/ActivateOrderController.activateOrder";
//import checkFreightRequest from "@salesforce/apex/ActivateOrderController.checkFreightRequest";
import areOrderProductsSelected from "@salesforce/apex/ActivateOrderController.areOrderProductsSelected";
import checkOrderStatusforActivation from "@salesforce/apex/ActivateOrderController.checkOrderStatusforActivation";

import { ShowToastEvent } from "lightning/platformShowToastEvent";
import Order_has_been_Activated_and_send_for_approval from "@salesforce/label/c.Order_has_been_Activated_and_send_for_approval";
import Order_can_only_be_activated_from_draft_Stage from "@salesforce/label/c.Order_can_only_be_activated_from_draft_Stage";
import Please_add_products_before_activating_the_order from "@salesforce/label/c.Please_add_products_before_activating_the_order";
import Order_can_be_activated_only_after_freight_is_entered from "@salesforce/label/c.Order_can_be_activated_only_after_freight_is_entered";
export default class ActivateandSendForApproval extends LightningElement {
  @api orderId; // Pass the record Id from parent component

  label = {
    Order_has_been_Activated_and_send_for_approval,
    Order_can_only_be_activated_from_draft_Stage,
    Please_add_products_before_activating_the_order,
    Order_can_be_activated_only_after_freight_is_entered
  };

  errorMessageToDisplay = "";

  connectedCallback() {
    try {
      console.log("orderId::", this.orderId);
      checkOrderStatusforActivation({ orderId: this.orderId })
        .then((statusResult) => {
          if (statusResult) {

            // checkFreightRequest({ orderId: this.orderId })
            //   .then((result) => {
            //     console.log('BG >>>> 1 :', JSON.stringify(result));
            //     if (!result) {
            //       const errorevent = new ShowToastEvent({
            //         title: "Error Toast message",
            //         message:
            //           this.label.Order_can_be_activated_only_after_freight_is_entered,
            //         variant: "error",
            //         mode: "sticky"
            //       });

            //       this.dispatchEvent(errorevent); // Handle the error appropriately, e.g., display an toast
            //       const closeAuraEvent = new CustomEvent("closemodal", {
            //         detail: {}
            //       });
            //       this.dispatchEvent(closeAuraEvent);
            //     }
            //   });
            areOrderProductsSelected({ orderId: this.orderId })
              .then((result) => {
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
                }
              });
          }
          else {
            const errorevent = new ShowToastEvent({
              title: "Error Toast message",
              message:
                this.label.Order_can_only_be_activated_from_draft_Stage,
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

  handleSave() {
    console.log("inside save");
    console.log(this.status);

    activateOrder({ orderId: this.orderId }) // Use orderDetail variable here, not this.orderDetail
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
        window.location.reload();
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
          message: Array.isArray(finalError) ? finalError[0] : finalError,
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

  handleCancel() {
    const closeAuraEvent = new CustomEvent("closemodal", {
      detail: {}
    });
    this.dispatchEvent(closeAuraEvent);
  }

}
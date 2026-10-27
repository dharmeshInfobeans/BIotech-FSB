({
    /* Initialization & Get List Of Subordinates */
    doInit: function (component, event, helper) {
        console.log("In Doint");
        var urlString = window.location.href;
        var baseURL = urlString.substring(0, urlString.indexOf("/s"));
        component.set("v.cbaseURL", baseURL);
        console.log("v.recordId : ", component.get("v.recordId"));

        //Get Order Details
        var action = component.get("c.getOrderDetails");
        action.setParams({
            orderId: component.get("v.recordId")
        });
        action.setCallback(this, function (response) {
            var state = response.getState();
            console.log("response of order : ", response);
            console.log("JSON.stringify response of order : ", JSON.stringify(response));

            console.log("response of order : ", response.getReturnValue());
            if (component.isValid() && state === "SUCCESS") {
                let result = response.getReturnValue();
                component.set("v.order", result);
                component.set("v.frieght", result.Freight_Amount__c);
                var order = component.get("v.order");

                //If order is already active then error message
                if (
                    order.Status__c == "Cancel"

                ) {
                    var toastEvent = $A.get("e.force:showToast");
                    toastEvent.setParams({
                        type: "error",
                        title: $A.get("$Label.c.Error"),
                        message: $A.get(
                            "$Label.c.You_can_not_add_products_for_canceled_order"
                        ),
                        mode: "dismissible"
                    });
                    toastEvent.fire();
                    helper.closeQuickAction();
                }

                else if (
                    order.Status__c == "Approved" ||
                    order.Status__c == "Active" ||
                    order.Status__c == "Sent for Approval"
                ) {
                    var toastEvent = $A.get("e.force:showToast");
                    toastEvent.setParams({
                        type: "error",
                        title: $A.get("$Label.c.Error"),
                        message: $A.get(
                            "$Label.c.Once_order_is_active_you_can_not_make_any_change_to_it"
                        ),
                        mode: "dismissible"
                    });
                    toastEvent.fire();
                    helper.closeQuickAction();
                }

                else if (
                    !order.Buyer_Account__c
                ) {
                    var toastEvent = $A.get("e.force:showToast");
                    toastEvent.setParams({
                        type: "error",
                        title: $A.get("$Label.c.Error"),
                        message: $A.get(
                            "$Label.c.Buyer_Account_Not_Found"
                        ),
                        mode: "dismissible"
                    });
                    toastEvent.fire();
                    helper.closeQuickAction();
                }

                action = component.get("c.getOrderLineItems");
                action.setParams({
                    orderId: component.get("v.recordId")
                });
                action.setCallback(this, function (response) {
                    state = response.getState();
                    if (component.isValid() && state === "SUCCESS") {
                        let result = response.getReturnValue();
                        console.log("***result***", result);
                        helper.addExistingOLI(component, result);
                        //Get Products with less stock
                        var productListCmp = component.find("productListItemCmp");
                        var defaultSelectedProduct = productListCmp.get(
                            "v.productsWithLessStock"
                        );
                        console.log("productsWithLessStock : ", defaultSelectedProduct);
                        var defaultSelected = [];
                        if (defaultSelectedProduct.length > 0) {
                            for (var i = 0; i < defaultSelectedProduct.length; i++) {
                                let isFound = false;
                                for (var j = 0; j < result.length; j++) {
                                    if (
                                        result[j].Agreement_Product__r.Product__r
                                            .Dummy_Product_Code__c ==
                                        defaultSelectedProduct[i].Product__r.Dummy_Product_Code__c
                                    ) {
                                        isFound = true;
                                        break;
                                    }
                                }
                                if (!isFound) {
                                    defaultSelected.push(defaultSelectedProduct[i]);
                                }
                            }
                        }
                        if (defaultSelected.length > 0)
                            helper.addProductsToQLI(component, defaultSelected);
                    }
                });
                $A.enqueueAction(action);
            }
        });
        $A.enqueueAction(action);
    },

    addProductToSelectedQli: function (component, event, helper) {
        var selectedProductList = event.getParam("selectedPbeList");
        var isDefaultLoad = event.getParam("isDefaultLoad");
        helper.addProductsToQLI(component, selectedProductList);
    },

    removeSelectedQuoteItem: function (component, event, helper) {
        var removedQli = event.getParam("selectedQli");
        helper.removeQuoteItem(component, removedQli);
        helper.calculateQuoteTotalPrices(component);
    },

    handleFrieght: function (component, event, helper) {
        console.log("Frieght : ", event.detail.value);
        component.set("v.frieght", event.detail.value);
    },

    saveQuoteLineItems: function (component, event, helper) {
        var orderProducts = component.get("v.quoteLineItems");
        var frieght = component.get("v.frieght");
        var nonMslProductPresent = false;
        frieght = frieght == "" ? 0 : frieght;
        const orderData = component.get("v.order");
        console.log("Freight : ", frieght);
        console.log("order : ", orderData);
        /*if (
            orderData.incotermsRequired == true &&
            (frieght == undefined || frieght <= 0)
        ) {
            var toastEvent = $A.get("e.force:showToast");
            toastEvent.setParams({
                type: "error",
                title: $A.get("$Label.c.Error"),
                message:
                    $A.get("$Label.c.Incoterm_erro_msg") +
                    " " +
                    orderData.Incoterm +
                    "." +
                    $A.get("$Label.c.CNF_ERROR"),
                mode:"sticky"
            });
            toastEvent.fire();
            return;
        }*/
        //Check for validation
        var flag = false;
        var zeroQuantityFlag = false;
        var isValidationMessageShown = false;
        for (var i = 0; i < orderProducts.length; i++) {
            console.log('orderProducts[i].Category__c' + orderProducts[i].Category__c);

            if (orderProducts[i].Category__c == 'Non-MSL' && nonMslProductPresent != true) {
                nonMslProductPresent = true;
            }
            if (
                ($A.util.isUndefinedOrNull(orderProducts[i].subOrderProducts) ||
                    orderProducts[i].subOrderProducts.length == 0) &&
                orderProducts[i].ModelCount != 0
            ) {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    type: "error",
                    title: $A.get("$Label.c.Error"),
                    message:
                        $A.get("$Label.c.Error_in_saving_Subproducts_are_missing_for") +
                        orderProducts[i].ProductName,
                    mode: "sticky"
                });
                toastEvent.fire();
                return;
            } else {
                var actualQuantity = 0;
                var actualFoc = 0;
                orderProducts[i].InCart = false; //Added for Cart Management
                console.log("BG >>> A ", JSON.stringify(orderProducts[i]));
                console.log("BG >>> actualFoc : " + actualFoc);
                if (!$A.util.isUndefinedOrNull(orderProducts[i].subOrderProducts)) {
                    for (var j = 0; j < orderProducts[i].subOrderProducts.length; j++) {
                        orderProducts[i].subOrderProducts[j].InCart = false; //Added for Cart Management
                        actualQuantity =
                            actualQuantity +
                            parseInt(orderProducts[i].subOrderProducts[j].Quantity);
                        actualFoc =
                            actualFoc +
                            parseInt(orderProducts[i].subOrderProducts[j].FocQuantity);
                    }
                }
                if (
                    !$A.util.isUndefinedOrNull(orderProducts[i].subOrderProducts) &&
                    orderProducts[i].subOrderProducts.length != 0
                ) {
                    orderProducts[i].oldQuantity = orderProducts[i].Quantity;
                    orderProducts[i].Quantity = actualQuantity;
                    orderProducts[i].FocQuantity = actualFoc;
                    component.set("v.quoteLineItems", orderProducts);
                    console.log("BG >>> B 219 QuoteProductSelectionController.js: ", orderProducts);

                }

                //if(actualQuantity < parseInt(orderProducts[i].Quantity)){
                if (
                    parseInt(orderProducts[i].Quantity) <
                    parseInt(orderProducts[i].oldQuantity)
                ) {
                    flag = true;
                }
            }
            if (parseInt(orderProducts[i].Quantity) == 0) {
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    type: "error",
                    title: $A.get("$Label.c.Error"),
                    message: $A.get(
                        "$Label.c.Can_not_save_orders_add_product_with_zero_quantity"
                    ),
                    mode: "sticky"
                });
                toastEvent.fire();
                zeroQuantityFlag = true;
                // return;
            }
        }
        var mag =
            $A.get(
                "$Label.c.Some_Products_are_having_actual_order_quantity_less_than_the_minimum_order_quant"
            ) + $A.get("$Label.c.QtobePlaced");
        if (!isValidationMessageShown & flag) {
            var r = confirm(mag);
            isValidationMessageShown = true;
            if (r == false) {
                return;
            }
        }

        console.log("quoteLineItems:: ", JSON.stringify(orderProducts));
        if (/*orderProducts.length > 0 && */ !zeroQuantityFlag) {
            var action = component.get("c.upsertOrderProducts");
            action.setParams({
                orderProductStr: JSON.stringify(component.get("v.quoteLineItems")),
                orderId: component.get("v.recordId"),
                frieght: frieght
            });
            action.setCallback(this, function (a) {
                var state = a.getState();
                console.log('state : ', state);
                if (state === "SUCCESS") {
                    var toastEvent = $A.get("e.force:showToast");
                    toastEvent.setParams({
                        type: "success",
                        title: $A.get("$Label.c.Success"),
                        message: $A.get("$Label.c.The_record_has_been_saved_successfully"),
                        mode: "sticky"
                    });
                    toastEvent.fire();
                    if (nonMslProductPresent == true) {
                        component.set("v.showNonMSLModelPopup", true); // Trigger your modal popup
                    }

                } else if (state === "ERROR") {

                    var errors = a.getError();

                    console.error("Action failed. Errors:", errors);

                    if (errors && errors.length > 0) {
                        errors.forEach(function (error) {
                            console.error("Error message:", error.message);
                            console.error("Error details:", error);
                        });
                    }
                }


            });
            $A.enqueueAction(action);
        }
    },

    closeModal: function (component, event, helper) {
        component.set("v.showNonMSLModelPopup", false);

        helper.navigateToObject(component);//redirect to record

    },

    onRenderPbeList: function (component, event, helper) {
        component.set("v.spinner", false);
    },

    calculateQliTotalPrices: function (component, event, helper) {
        helper.calculateQuoteTotalPrices(component);
    },

    openSelectModelPopup: function (component, event, helper) {
        if (event.getParam("orderProduct")) {
            var orderProduct = event.getParam("orderProduct");
            console.log('BG  >>? orderProduct : ', JSON.stringify(orderProduct));
            component.set("v.selectedOrderProduct", orderProduct);
        }
        var showSelectModalPopup = event.getParam("showSelectModalPopup");
        component.set("v.showSelectModalPopup", showSelectModalPopup);
    },

    handleAddSubProductEvt: function (component, event, helper) {
        console.log("Inside Add Sub Product");
        var orderProduct = event.getParam("orderProduct");
        var orderProducts = component.get("v.quoteLineItems");
        for (var i = 0; i < orderProducts.length; i++) {
            if (orderProduct.UniqueKey == orderProducts[i].UniqueKey) {
                orderProducts[i] = orderProduct;
                break;
            }
        }
        component.set("v.quoteLineItems", orderProducts);
        console.log("BG >>> B 326 QuoteProductSelectionController.js: ", orderProducts);
        var showSelectModalPopup = event.getParam("showSelectModalPopup");

        component.set("v.showSelectModalPopup", showSelectModalPopup);
        helper.calculateQuoteTotalPrices(component);
        console.log("About to AutoSave");
        // this.autoSaveQuoteLineItems(component, event, helper);            //Added for Cart Management
        $A.enqueueAction(component.get("c.autoSaveQuoteLineItems"));
    },

    redirectToOrder: function (component, event, helper) {
        helper.navigateToObject(component);
    },

    autoSaveQuoteLineItems: function (component, event, helper) {
        var frieght = component.get("v.frieght");
        frieght = frieght == "" ? 0 : frieght;
        console.log("inside autoSave event handler");
        var action = component.get("c.upsertOrderProducts");
        action.setParams({
            orderProductStr: JSON.stringify(component.get("v.quoteLineItems")),
            orderId: component.get("v.recordId"),
            frieght: frieght
        });
        console.log(
            "AutoSaved Order Products: " +
            JSON.stringify(component.get("v.quoteLineItems"))
        );
        // action.setCallback(this, function (a) {
        //     console.error(JSON.stringify(a));
        //     try {
        //         var state = a.getState();
        //         if (state === "SUCCESS") {
        //             var toastEvent = $A.get("e.force:showToast");
        //             toastEvent.setParams({
        //                 type: 'success',
        //                 title: $A.get("$Lzabel.c.Success"),
        //                 message: $A.get("$Label.c.The_record_has_been_saved_successfully")

        //             });
        //             toastEvent.fire();

        //             helper.navigateToObject(component);
        //         } else {
        //             console.error(a);
        //         }
        //     } catch (error) {
        //         console.error(JSON.stringify(error));
        //     }
        // });
        $A.enqueueAction(action);
        console.log("Enqueued Action");
    }
});
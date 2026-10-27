({
    navigateToObject: function (component) {
        $A.get("e.force:closeQuickAction").fire();
        var navEvt = $A.get("e.force:navigateToSObject");
        navEvt.setParams({
            "recordId": component.get('v.recordId'),
            "slideDevName": "detail"
        });
        navEvt.fire();
        $A.get('e.force:refreshView').fire();
    },

    closeQuickAction: function () {
        $A.get("e.force:refreshView").fire();
        var dismissActionPanel = $A.get("e.force:closeQuickAction");
        dismissActionPanel.fire();
    },

    generateRandomVal: function () {
        return String(Math.round((new Date()).getTime() / 1000)) + this.generateRandomString(10);
    },

    generateRandomString: function (length) {
        var chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
        var result = '';
        for (var i = length; i > 0; --i) result += chars[Math.floor(Math.random() * chars.length)];
        return result;
    },

    removeQuoteItem: function (component, value) {
        var selectedQuoteItemList = component.get("v.quoteLineItems");
        var updatedQuoteItemList = [];
        console.log(value);
        console.log(selectedQuoteItemList);
        for (var i = 0; i < selectedQuoteItemList.length; i++) {
            if (selectedQuoteItemList[i].UniqueKey == value.UniqueKey) {
                continue;
            } else {
                updatedQuoteItemList.push(selectedQuoteItemList[i]);
            }
        }
        console.log(updatedQuoteItemList);
        component.set("v.quoteLineItems", updatedQuoteItemList);

        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            type: 'success',
            title: $A.get("$Label.c.Success"),
            message: $A.get("$Label.c.The_record_has_been_deleted_successfully")
        });

        toastEvent.fire();
    },


    showMoreRecordSpinner: function (component) {
        component.set("v.spinner", true);
    },

    hideMoreRecordSpinner: function (component) {
        component.set("v.spinner", false);
        component.set("v.isShowMoreRecordSpinner", false);
    },


    searchProduct: function (component, searchStr) {

        console.log('searchStr**' + searchStr);
        var action = component.get("c.searchProducts");
        action.setParams({ "searchStr": searchStr });
        action.setCallback(this, function (data) {
            console.log("Page %s loaded in %fms", searchStr,
                performance.now() - startTime);

            component.set("v.agreementProducts", data.getReturnValue());
            console.log('data.getReturnValue()****');
            //console.log(data.getReturnValue());
            if (data.getReturnValue().length == 0) {
                component.set('v.hasMorePbeRecord', true);
                component.set('v.msgPbeList', 'No item found.');
            } else {
                component.set('v.hasMorePbeRecord', false);
            }
        });
        var startTime = performance.now();
        $A.enqueueAction(action);
    },

    toggleFullPageSpinner: function (cmp, event) {
        var childCmp = cmp.find("productListItemCmp");

        var spinner = childCmp.find("productListSpinner");
        $A.util.toggleClass(spinner, "slds-hide");
    },

    toggleMoreRecordSpinner: function (cmp, event) {
        var childCmp = cmp.find("productListItemCmp");
        var spinner = childCmp.find("moreRecordSpinner");
        $A.util.toggleClass(spinner, "slds-hide");
    },

    addProductsToQLI: function (component, selectedProductList) {

        var alreadyAddedQuoteItems = component.get("v.quoteLineItems");

        var prodNameSet = new Set();
        for (var i = 0; i < alreadyAddedQuoteItems.length; i++) {
            prodNameSet.add(alreadyAddedQuoteItems[i].ProductName);
        }


        console.log('In the Add Products To QLI');
        var quoteItemList = component.get("v.quoteLineItems");
        var quoteItem = {};
        for (var i = 0; i < selectedProductList.length; i++) {
            quoteItem = {};
            quoteItem.UniqueKey = this.generateRandomVal();
            quoteItem.ProductName = selectedProductList[i].Product__r.Name;
            quoteItem.currencyCode = selectedProductList[i].Master_Agreement__r.Account__r.CurrencyIsoCode;
            quoteItem.Product = selectedProductList[i].Product__c;
            quoteItem.isBackup = selectedProductList[i].Is_Backup__c;

            if (prodNameSet.has(quoteItem.ProductName)) {

                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "type": "error",
                    "title": $A.get("$Label.c.Error"),
                    "message": $A.get("$Label.c.The_Product") + " " + quoteItem.ProductName + " " + $A.get("$Label.c.is_already_added")
                });
                toastEvent.fire();
                return;
            }


            quoteItem.ProductCode = selectedProductList[i].Product__r.Dummy_Product_Code__c;
            quoteItem.RecordId = '';
            quoteItem.ListPrice = selectedProductList[i].Price__c;
            quoteItem.SalesPrice = selectedProductList[i].Price__c;
            quoteItem.ProductFamily = selectedProductList[i].Family__c;
            quoteItem.Category = selectedProductList[i].Category__c;

            quoteItem.ModelCount = selectedProductList[i].Product__r.Model_Count__c;
            quoteItem.AggrementProduct = selectedProductList[i].Id;  //Agreement Product lookup not populating
            quoteItem.IsRequired = false;
            if (!$A.util.isUndefinedOrNull(selectedProductList[i])) {
                // quoteItem.Quantity =  Math.abs(selectedProductList[i].Difference__c);
                quoteItem.Quantity = 0;             //Added to set default value as 1
                quoteItem.IsRequired = true;
            } else
                quoteItem.Quantity = 0;
            quoteItem.InCart = true;
            console.log('BG >>> 1' + JSON.stringify(selectedProductList[i]));       //Initially, Item is marked as in cart
            quoteItem.FOCText = selectedProductList[i].FOC_Text__c;
            console.log('BG >>> 2');
            quoteItem.Discount = selectedProductList[i].FOC__c;

            if (selectedProductList[i].FOC__c > 0)
                quoteItem.Discount = selectedProductList[i].FOC__c;
            else
                quoteItem.Discount = 0;

            quoteItem.SubTotalPrice = quoteItem.SalesPrice * quoteItem.Quantity;
            console.log('add Product to QLI method');
            console.log(quoteItem.SubTotalPrice);

            if (quoteItem.Discount > 0)
                quoteItem.TotalPrice = quoteItem.SubTotalPrice - (quoteItem.SubTotalPrice * quoteItem.Discount / 100);
            else
                quoteItem.TotalPrice = quoteItem.SubTotalPrice;

            quoteItem.subOrderProducts = [];

            quoteItemList.push(quoteItem);
        }
        console.log("QuoteProductSelectionController->quoteItemList:->176",JSON.stringify(quoteItemList));
        component.set("v.quoteLineItems", quoteItemList);
        this.calculateQuoteTotalPrices(component);
    },

    calculateQuoteTotalPrices: function (component) {
        var quoteItemList = component.get("v.quoteLineItems");
        var qliTotalPrice = 0, qliSubTotalPrice = 0;
        for (var i = 0; i < quoteItemList.length; i++) {
            qliSubTotalPrice += quoteItemList[i].SubTotalPrice;
            qliTotalPrice += quoteItemList[i].TotalPrice;
        }
        component.set("v.qliSubTotalPrice", qliSubTotalPrice);
        component.set("v.qliTotalPrice", qliTotalPrice);

    },

    addExistingOLI: function (component, existingOLI) {
        var orderItemList = [];
        var orderItem = {}, subOrderItem = {};

        for (var i = 0; i < existingOLI.length; i++) {
            orderItem = this.getOrderItem(existingOLI[i])
            orderItem.currencyCode = component.get('v.order').CurrencyIsoCode;
            if (!$A.util.isUndefinedOrNull(existingOLI[i].Sub_Order_Products__r) && existingOLI[i].Sub_Order_Products__r.length > 0) {

                orderItem.subOrderProducts = [];
                for (var j = 0; j < existingOLI[i].Sub_Order_Products__r.length; j++) {
                    subOrderItem = this.getOrderItem(existingOLI[i].Sub_Order_Products__r[j]);
                    subOrderItem.CodeTxt = existingOLI[i].Sub_Order_Products__r[j].Code_Txt__c;
                    subOrderItem.ModelTxt = existingOLI[i].Sub_Order_Products__r[j].Model_Txt__c;
                    subOrderItem.FOCText = existingOLI[i].Sub_Order_Products__r[j].FOC_Text__c;
                    subOrderItem.Model = existingOLI[i].Sub_Order_Products__r[j].Product_Model__c;
                    subOrderItem.Code = existingOLI[i].Sub_Order_Products__r[j].Product_Model_Code__c;
                    subOrderItem.SelectedPower = existingOLI[i].Sub_Order_Products__r[j].Spherical_Power__c !== '' ? existingOLI[i].Sub_Order_Products__r[j].Spherical_Power__c : null;
                    subOrderItem.Product = existingOLI[i].Agreement_Product__r.Product__c;
                    subOrderItem.SelectedCylendricalPower = existingOLI[i].Sub_Order_Products__r[j].Cyindrical_Power__c !== '' ? existingOLI[i].Sub_Order_Products__r[j].Cyindrical_Power__c : null;
                    subOrderItem.selectedaxisAngle = existingOLI[i].Sub_Order_Products__r[j].Axis_Angle__c !== '' ? existingOLI[i].Sub_Order_Products__r[j].Axis_Angle__c : null;



                    if (!$A.util.isUndefinedOrNull(existingOLI[i].Agreement_Product__c) && !$A.util.isUndefinedOrNull(existingOLI[i].Agreement_Product__r.FOC__c)) {

                        subOrderItem.Discount = existingOLI[i].Agreement_Product__r.FOC__c;
                    }
                    subOrderItem.RecordId = existingOLI[i].Id;
                    orderItem.subOrderProducts.push(subOrderItem);
                }
            }
            orderItemList.push(orderItem);
        }
        component.set("v.quoteLineItems", orderItemList);
        this.calculateQuoteTotalPrices(component);
    },

    getOrderItem: function (oliRec) {
        var orderItem = {};
        console.log('OlI : ', oliRec);
        orderItem.UniqueKey = oliRec.Unique_Key__c;
        if (!$A.util.isUndefinedOrNull(oliRec.Agreement_Product__c) && !$A.util.isUndefinedOrNull(oliRec.Agreement_Product__r.Product__c)) {
            orderItem.ProductName = oliRec.Agreement_Product__r.Product__r.Name;
            orderItem.Product = oliRec.Agreement_Product__r.Product__c;
            orderItem.ProductCode = oliRec.Agreement_Product__r.Product__r.Dummy_Product_Code__c;
            orderItem.ListPrice = oliRec.Agreement_Product__r.Price__c;
            orderItem.Discount = oliRec.Agreement_Product__r.FOC__c;
            orderItem.ModelCount = oliRec.Agreement_Product__r.Product__r.Model_Count__c;
            orderItem.AggrementProduct = oliRec.Agreement_Product__c;
            orderItem.FOCText = oliRec.Agreement_Product__r.FOC_Text__c;
            orderItem.InCart = oliRec.InCart__c;
            orderItem.isBackup = oliRec.Agreement_Product__r.Is_Backup__c;//Added for Cart Management
        }
        orderItem.SalesPrice = oliRec.Unit_Price__c;
        orderItem.Quantity = oliRec.Quantity__c != undefined && oliRec.Quantity__c != null ? oliRec.Quantity__c : 0;
        orderItem.FocQuantity = oliRec.FOC_Quantity__c;
        //oliRec.FOC_Quantity__c != undefined && oliRec.FOC_Quantity__c != null ? oliRec.FOC_Quantity__c : 0;
        orderItem.RecordId = oliRec.Id;
        orderItem.totalQuantity = oliRec.Total_Quantities__c;//code added
        if (oliRec.Discount > 0)
            orderItem.Discount = oliRec.Discount__c;
        else
            orderItem.Discount = 0;

        orderItem.SubTotalPrice = orderItem.SalesPrice * (orderItem.Quantity - orderItem.FocQuantity);
        console.log('Inside getOrderItem method : ', orderItem);
        orderItem.TotalPrice = oliRec.Total_Price__c;




        return orderItem;
    }
})
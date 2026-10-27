({
     doInit : function(component, event, helper){
        var orderProductRecord = component.get("v.orderProductRecord");
        console.log("QuoteProductItemController->DoInit->orderProductRecord"+JSON.stringify(orderProductRecord));
                component.set("v.oldQuantity", orderProductRecord.Quantity); 
    },
    openSelectModelsPopup : function(component, event, helper) {
        var orderProductRecordProviderEvnt = component.getEvent("orderProductRecordProviderEvent");
        var orderProductRecord = component.get("v.orderProductRecord");
        console.log('orderProductRecord : ',orderProductRecord.subOrderProducts);
        orderProductRecordProviderEvnt.setParams({
            "orderProduct" :  orderProductRecord, 
            "showSelectModalPopup" : true
        });
        orderProductRecordProviderEvnt.fire();
    },
    removeQuoteItem : function(component, event, helper) {
        console.log('BG >>> event : ',event);
        var selectItemEvent = component.getEvent("removeQuoteItemEvent");
        console.log('BG >>> selectItemEvent : ',selectItemEvent);
        selectItemEvent.setParams({"selectedQli": component.get('v.orderProductRecord')});
        selectItemEvent.fire();
    },
    
    calculateQuoteItemPrice : function(component, event, helper) {
        var changedQuoteItem = component.get('v.orderProductRecord');
        changedQuoteItem.oldQuantity = component.get("v.oldQuantity");
        console.log('BG >>> add to order product as cart content  >>',changedQuoteItem);
        // 
        component.set('v.orderProductRecord', changedQuoteItem);
        //component.set("v.oldQuantity", changedQuoteItem); 

        
        helper.calculatePrices(component, changedQuoteItem);
        console.log('BG n>>> : '+JSON.stringify(changedQuoteItem));
        helper.calculateFOCquantity(component, changedQuoteItem);
	},
       
    
    onCheckBoxSelection :function(component, event, helper){
        component.set('v.ProductSelectionPopup',true);
        var productRecord = component.get('v.orderProductRecord');
        var action = component.get("c.getSubProdcts");
        action.setParams({ "productRecord": productRecord});
        action.setCallback(this, function(response){
            var state = response.getState();
            if (component.isValid() && state === "SUCCESS"){
            var result = response.getReturnValue();
            component.set('v.ListSubProductWrapper', result); 
            }
        });
        $A.enqueueAction(action);        
   },

   autoSave: function (component,event,helper) {
        console.log('On Focus Out event fired');
        try {
            var selectItemEvent = component.getEvent("autoSaveQli");
            selectItemEvent.setParams({"selectedQli": component.get('v.orderProductRecord')});
            selectItemEvent.fire();
            // console.log(JSON.stringify(component.get('v.orderProductRecord')));
            console.log('autoSaveQli fired');          
        } catch (error) {
            console.error(JSON.stringify(error));
        }
   }
   
})
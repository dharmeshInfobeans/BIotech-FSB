({
    doInit : function(component, event, helper) {
        component.set("v.showSpinner",true);
        
        if(component.get('v.selectedAccId')){
            helper.getPageData(component);
        }else{
            var currentYear = 2020;
            var yearOptions = [];
            var j = 0;
            for(j=currentYear;j<=(currentYear+5);j++){
                yearOptions.push(j);
            }
            component.set('v.yearOptionLst',yearOptions);
            //component.find("yearSelection").set("v.value", new Date().getFullYear());
            component.set("v.selectedYear", new Date().getFullYear());
            
            var action1 = component.get("c.getCurrentUserAccounts");
            action1.setCallback(this, function(response) {
                var state = response.getState();
                if(state === "SUCCESS"){
                    component.set("v.showSpinner",false);
                    var accList = response.getReturnValue();
                    if(accList.length>0){
                        
                        component.set("v.accList", accList);
                        component.set("v.selectedAccount", accList[0]);
                        component.set("v.selectedAccId", accList[0].Id);
                        var accId = component.get("v.selectedAccId");
                    }else{
                        var selectedAccount = component.get("v.selectedAccount");
                        component.set('v.selectedAccId', selectedAccId);
                    }
                    
                    
                    helper.getPageData(component);
                }
            });
            $A.enqueueAction(action1);    
        }
    },
    
    saveRecords : function(component,event,helper)  
    {
     debugger;
        var DAPRecordsList = component.get("v.allWrapperRecords");
        var j=0;
        for(j = 0; j < DAPRecordsList.length; j++){
            
            if(($A.util.isUndefinedOrNull(DAPRecordsList[j].openingStock)|| DAPRecordsList[j].openingStock=='')){
                DAPRecordsList[j].openingStock =0;
            }            
            
            var DASList = DAPRecordsList[j].dasWrapperLst;
            var k=0;
            if(!$A.util.isUndefinedOrNull(DASList)){
                for(k=0; k < DASList.length; k++){
                    
                    if(($A.util.isUndefinedOrNull(DASList[k].soldQuantity) || DASList[k].soldQuantity=='') && DASList[k].soldQuantity!=0){
                        
                        var toastEvent = $A.get("e.force:showToast");
                        toastEvent.setParams({
                            type: 'error',
                            "title": "error!",
                            "message": $A.get("$Label.c.Actual_sales_value_can_not_be_blank_for_product") +DAPRecordsList[j].productName
                        });  
                        toastEvent.fire();  
                        return;                                   
                    }                 
                    
                }
            }
        }
        
        component.set("v.showSpinner",true);
        var action = component.get("c.upsertDSMandDASRecords");
        var wrapperLSt = component.get("v.allWrapperRecords");
        var i=0;
        for(i=0;i<wrapperLSt.length;i++)
        {
            var dasWrapperList = wrapperLSt[i].dasWrapperLst;
            if(dasWrapperList.length>0)
            {
                var j=0;
                for(j=0;j<dasWrapperList.length;j++)
                { 
                    if( $A.util.isUndefinedOrNull(dasWrapperList[j].soldQuantity) || dasWrapperList[j].soldQuantity=='')
                        dasWrapperList[j].soldQuantity = 0;    
                }
            }
        }
        action.setParams(
            {
                "wrapperString" : JSON.stringify(component.get("v.allWrapperRecords"))     
            }
        );
        action.setCallback(this, function(response) {
            var state = response.getState();
            debugger;
            if(state === "SUCCESS"){
                component.set("v.showSpinner",false);
                var a = component.get('c.doInit');
                $A.enqueueAction(a);
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    type: 'success',
                    "title": $A.get("$Label.c.Success"),
                    "message": $A.get("$Label.c.The_record_has_been_updated_successfully")
                });
                toastEvent.fire();
            }
            else
            {
                component.set("v.showSpinner",false);
            }
        });
        //Adding the request to queue
        $A.enqueueAction(action);    
        
    },
    
    yearChange :function(component,event,helper) {
        helper.getPageData(component);
    },
    handleDontContinuewithSameOrder :function(component,event,helper) {
        
        component.set("v.orderCreationModal", false);
        component.set("v.continueWithExistingOrder", false);
        component.set("v.showSpinner",false);
        helper.createNewOrder(component);                
        
    },
    handleContinueWithSameOrder :function(component,event,helper) {
        
        component.set("v.orderCreationModal", false );
        component.set("v.continueWithExistingOrder", true);
        component.set("v.showSpinner",false);
        helper.createNewOrder(component);                
        
    },
    placeDealerOrder: function(component,event,helper){
        
        component.set("v.showSpinner",true);
        var draftOrdersCount=0;
        var action = component.get("c.getDraftOrderCount");
        action.setParams({
            "accountId" :   component.get('v.allWrapperRecords')[0].accountId
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if(state === "SUCCESS"){
                draftOrdersCount = response.getReturnValue();   
                
                
                if(draftOrdersCount == 1){
                    component.set("v.orderCreationModal", true);
                    component.set("v.showSpinner",false);
                    var isModelOper = component.get("v.orderCreationModal");
                    while(isModelOper == ture) {
                        isModelOper = component.get("v.orderCreationModal");
                    }
                }
                
                helper.createNewOrder(component);                
                
            }
        });
        $A.enqueueAction(action);   
        
        
        
    },
    handleCancle: function(component,event,helper){
        component.set("v.orderCreationModal", false );
    }
    
    
    
})
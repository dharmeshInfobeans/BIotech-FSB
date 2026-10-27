({
    
    getPageData : function(component){
        
        var selectedAccId =component.get("v.selectedAccId");
        var accId = component.get("v.selectedAccId");
        var selectedYear = component.find("yearSelection").get("v.value");
        var action = component.get("c.getPageData");
        action.setParams(
            {
                "selectedYear" : selectedYear,
                "accountId" : component.get("v.selectedAccId")
            }
        );
        
        //Defining the callback function
        action.setCallback(this, function(response) {
            var state = response.getState();
            
            if(state === "SUCCESS"){
                var recordArr = response.getReturnValue();
                
                var originalRecordsArr=[];
                component.set( "v.allWrapperRecords", recordArr);
                console.log('allWrapperRecords>>',component.get( "v.allWrapperRecords"));
                var i=0;
                for(i=0;i<recordArr.length;i++)
                {
                    originalRecordsArr.push(recordArr[i]);
                }
                component.set("v.allOriginalWrapperRecords",originalRecordsArr);
                component.set("v.showSpinner",false);
            }
            else if(state === "INCOMPLETE"){
                component.set("v.showSpinner",false);
            }
                else if(state === "ERROR"){
                    var errors = response.getError();
                    if(errors){
                        if(errors[0] && errors[0].message){
                            console.log("Error message: " + errors[0].message);
                        }
                    }else{
                        console.log("Unknown error");
                    }
                    component.set("v.showSpinner",false);
                }
            component.set("v.showSpinner",false);  
        });
        //Adding the request to queue
        $A.enqueueAction(action); 
    },
    
    
    
    createNewOrder : function(component){
        var r = false;
        r = component.get("v.continueWithExistingOrder");
        //Create new order
        var actionVar = component.get("c.placeOrder");
        console.log('**component.**'+component.get('v.allWrapperRecords')[0].accountId);
        var selectedAccount = component.get('v.selectedAccount');
        actionVar.setParams({
            "CurrencyIsoCode" : selectedAccount.CurrencyIsoCode,
            "accountId" :   component.get('v.allWrapperRecords')[0].accountId,
            "flag":r
        });
        actionVar.setCallback(this, function(response) {
            var state = response.getState();
            if(state === "SUCCESS"){
                var orderRec = response.getReturnValue();  
                if(orderRec!=null){
                    var navEvt = $A.get("e.force:navigateToSObject");
                    navEvt.setParams({
                        "CurrencyIsoCode" : selectedAccount.CurrencyIsoCode,
                        "recordId": orderRec.Id,
                        "slideDevName": "detail"
                        
                    });
                    navEvt.fire();
                }
                
            }
            
            component.set("v.showSpinner",false);
        });
        $A.enqueueAction(actionVar);                 
    }
})
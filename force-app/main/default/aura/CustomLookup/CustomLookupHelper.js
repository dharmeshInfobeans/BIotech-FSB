({
    searchHelper : function(component,event,getInputkeyWord) {
        
        var apiName = component.get("v.objectAPIName");
        if(apiName == 'Account'){
            // call the apex class method 
            var action = component.get("c.getAccountDetails");
            // set param to method  
            
            action.setParams({
                'strInput': getInputkeyWord,
                'ObjectName' : component.get("v.objectAPIName")
            });
            // set a callBack    
            action.setCallback(this, function(response) {
                $A.util.removeClass(component.find("mySpinner"), "slds-show");
                
                var state = response.getState();
                if (state === "SUCCESS") {
                    var storeResponse = response.getReturnValue();
                    // if storeResponse size is equal 0 ,display No Result Found... message on screen.                }
                    if (storeResponse.length == 0) {
                        component.set("v.Message", 'No Result Found...');
                    } else {
                        component.set("v.Message", '');
                    }
                    // set searchResult list with return value from server.
                    component.set("v.listOfSearchRecords", storeResponse);
                }
                
            });
            // enqueue the Action  
            $A.enqueueAction(action);
        }else if(apiName == 'contact'){
            // call the apex class method
            var accId = component.get("v.selectedAccountId");
            if(accId != null){
            var action = component.get("c.getContactDetails");
            // set param to method  
            
            action.setParams({
                'strInput': getInputkeyWord,
                'ObjectName' : component.get("v.objectAPIName"),
                'accountId' : accId
            });
            // set a callBack    
            action.setCallback(this, function(response) {
                $A.util.removeClass(component.find("mySpinner"), "slds-show");
                
                var state = response.getState();
                if (state === "SUCCESS") {
                    var storeResponse = response.getReturnValue();
                    // if storeResponse size is equal 0 ,display No Result Found... message on screen.                }
                    if (storeResponse.length == 0) {
                        component.set("v.Message", 'No Result Found...');
                    } else {
                        component.set("v.Message", '');
                    }
                    // set searchResult list with return value from server.
                    component.set("v.listOfSearchRecords", storeResponse);
                }
                
            });
            // enqueue the Action  
            $A.enqueueAction(action);
            }
        }else{
           // debugger;
            var action = component.get("c.getProductDetails");
            // set param to method  
            if(getInputkeyWord !=null){
                action.setParams({
                    'strInput': getInputkeyWord,
                    'ObjectName' : component.get("v.objectAPIName")
                });
                // set a callBack    
                action.setCallback(this, function(response) {
                    $A.util.removeClass(component.find("mySpinner"), "slds-show");
                    
                    var state = response.getState();
                    if (state === "SUCCESS") {
                        var storeResponse = response.getReturnValue();
                        // if storeResponse size is equal 0 ,display No Result Found... message on screen.                }
                        if (storeResponse.length == 0) {
                            component.set("v.Message", 'No Result Found...');
                        } else {
                            component.set("v.Message", '');
                        }
                        // set searchResult list with return value from server.
                        component.set("v.listOfSearchRecords", storeResponse);
                    }
                    
                    
                });
                // enqueue the Action  
                $A.enqueueAction(action); 
            }
        }
    },
})
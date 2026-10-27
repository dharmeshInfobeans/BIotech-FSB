({
	toggleSpinner: function (component) {
        var spinner = component.find("CESpinner");
        $A.util.toggleClass(spinner, "slds-hide");
    },
    fetchLastCE: function(component){
        var action = component.get("c.getLastCE");
        action.setParams({
            "accId" : component.get("v.recordId")
        });
        action.setCallback(this, function(response) {
            if(response.getState()=="SUCCESS") {
                var result = response.getReturnValue();
                component.set("v.statusPicklistValues", result.statusPicklistValues);    
                component.set("v.yearPicklistValues", result.yearPicklistValues);  
                component.set("v.languagePicklist", result.languagePicklist);  
                component.set("v.recordType",result.recordType);
                component.set("v.custEvaluation", result.lastCE);
                component.set("v.custEvaluation.Status__c", result.lastCE.Status__c);
                component.set("v.lastCEName", result.lastCEname);
                component.set("v.accountName", result.accountName);   
                component.set("v.isAdmin",result.isAdmin);
                component.set("v.account",result.acc);
                console.log(result.recordType);
                if(result.disableForm){
                    component.set("v.isError",true);
                	component.set("v.errorMessage",'Record is locked due to approval');
                    component.set("v.disableForm",result.disableForm);
                }
            }
        });
        $A.enqueueAction(action);
    },
    saveCE: function(component){
        //validating all fields
    	var allValid = component.find('recField').reduce(function (validSoFar, inputCmp) {
            inputCmp.showHelpMessageIfInvalid();
            return validSoFar && !inputCmp.get('v.validity').valueMissing;
        }, true);
        
        if (allValid) {
            this.toggleSpinner(component);
            
        	var cEvaluation = component.get("v.custEvaluation");
            cEvaluation.Account__c = component.get("v.recordId");
            
        	var action = component.get("c.saveCustEvaluation");
            action.setParams({
                "custEvaluationJSON": JSON.stringify(component.get("v.custEvaluation"))
            });
            action.setCallback(this, function(response) {
                this.toggleSpinner(component);
                if(response.getState()=="SUCCESS") {
                    var savedCE = response.getReturnValue();
                    if(!$A.util.isEmpty(savedCE.Id)){
                        var toastEvent = $A.get("e.force:showToast");
                        toastEvent.setParams({
                            title : $A.get("$Label.c.CE_Success"),	
                            message: $A.get("$Label.c.CE_help_Record"),
                            type: 'success'
                        });
                        toastEvent.fire();
                        var navEvt = $A.get("e.force:navigateToSObject");
                        navEvt.setParams({
                          "recordId": savedCE.Id
                        });
                        navEvt.fire();
                        
                        window.setTimeout(
                            $A.getCallback(function() {
                                console.log('refresh--');
                                $A.get('e.force:refreshView').fire();
                            }), 2000
    					);
                        
                    }
                    
                }else{
                    component.set("v.isError",true);
                	component.set("v.errorMessage",response.getError()[0].message);
                }
            });
            $A.enqueueAction(action);
        } 
        
    } 
})
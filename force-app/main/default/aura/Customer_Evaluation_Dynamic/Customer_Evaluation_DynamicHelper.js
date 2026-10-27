({
    toggleSpinner: function (component) {
        var spinner = component.find("CESpinner");
        $A.util.toggleClass(spinner, "slds-hide");
    },
	saveCE: function(component){
        //validating all fields
    	var allValid = component.find('recField').reduce(function (validSoFar, inputCmp) {
            inputCmp.showHelpMessageIfInvalid();
            return validSoFar && !inputCmp.get('v.validity').valueMissing;
        }, true);
        
        if (allValid) {
            this.toggleSpinner(component);
            
        	var cEvaluation = component.get("v.recordObject");
            cEvaluation.Account__c = component.get("v.recordId");
            
        	var action = component.get("c.saveCustEvaluation");
            action.setParams({
                "custEvaluationJSON": JSON.stringify(component.get("v.recordObject"))
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
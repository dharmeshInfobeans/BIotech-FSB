({
	onInit : function(component,event) {
		var action2 = component.get("c.checkAccountActivated");
        action2.setParams({
            accId: component.get("v.recordId")
        });
        action2.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                this.hideSpinner(component, event);                                                                                                         
                var retData = response.getReturnValue();
                
                console.log("In CreateSampleReqComp-->H-->onInit_M--> ret Acc Act?-->" +JSON.stringify(retData) );
                
                if (!$A.util.isEmpty(retData)) {
                    if(retData == 'Yes'){
                        component.set("v.showForm",true);
                        this.showSpinner(component, event);
                    }
                    
                    if(retData == 'No'){
                        //Account is draft
                        component.set("v.showForm",false);
                        component.set("v.showMessage",true);
                    }
                    
                }else{
                    this.hideSpinner(component, event);
                    component.set("v.showMessage",true);
                    component.set("v.initMessage","Account doesn't exist.");
                    console.log("In CreateSampleReqComp-->H-->onInit_M-->From Apex-->Account not found......");
                }
            }else{
                this.hideSpinner(component, event);
                component.set("v.showMessage",true);
                component.set("v.showForm",false);
				
                //component.set("v.initMessage","Please fill all the mandatory fields.");                
                console.log("In CreateSampleReqComp-->H-->onInit_M-->From Apex-->Error in apex call......");
            }
        });
        $A.enqueueAction(action2);
	},
    showSpinner : function(component,event){
        console.log('In show spinnser');
        component.set("v.showSpinner", true);
    },
    hideSpinner : function(component,event){
        component.set("v.showSpinner", false);
    },
    showToast : function(params){
        var toastEvent = $A.get("e.force:showToast");
        if(toastEvent){
            toastEvent.setParams(params);
            toastEvent.fire();
        } else{
            alert(params.message);
        }
    },
})
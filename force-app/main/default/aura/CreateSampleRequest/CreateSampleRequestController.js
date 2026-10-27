({
    doInit : function(component, event, helper) {
        console.log('In Doinit');
        helper.showSpinner(component, event);
        helper.onInit(component, event);
    },
    handleSuccess : function(component, event, helper) {
        
        helper.showToast({
            "title": "Success!!",
            "type": "success",
            "message": "New Sample Request created successfully."
        });
        var payload = event.getParams().response;
        //console.log('Handle Success Pyld Resp-->'+JSON.stringify(payload));
        console.log('Handle Success New Rec Id-->'+payload.id);
        var newlyCreatedRecId = payload.id;
        
        if(newlyCreatedRecId){
            var navLink = component.find("navService");
            var pageRef = {
                type: 'standard__recordPage',
                attributes: {
                    actionName: 'view',
                    objectApiName: 'Sample_Request__c',
                    recordId : newlyCreatedRecId 
                },
            };
            navLink.navigate(pageRef, true);    
        }
        
    },
    handleLoad : function(component, event, helper) {
        helper.hideSpinner(component, event);
        var monMap = component.get("v.monthMap");
        var d = new Date();
        var currYear = d.getFullYear().toString();
        var currMonth = monMap[d.getMonth()];
        component.find("year").set("v.value",currYear);
        component.find("month").set("v.value",currMonth);
        component.find("accId").set("v.value",component.get("v.recordId"));
    },
    onCancel : function(component, event, helper) {
        $A.get('e.force:closeQuickAction').fire();
    },
    handleSubmit : function(component, event, helper) {
        helper.showSpinner(component, event);
        console.log('In Handle submit!!!');
        // stop the form from submitting
        var fields = event.getParam('fields');
        console.log("Field Values-->"+JSON.stringify(fields));
        event.preventDefault();
        if(!$A.util.isEmpty(component.find("month").get("v.value")) && !$A.util.isEmpty(component.find("year").get("v.value"))
           && !$A.util.isEmpty(component.find("accId").get("v.value")) ){
            var action2 = component.get("c.getMonthlyPlanId");
            action2.setParams({
                "accId": component.get("v.recordId"),
                "month":component.find("month").get("v.value"),
                "year": component.find("year").get("v.value")
            });
            action2.setCallback(this, function(response) {
                var state = response.getState();
                if (state === "SUCCESS") {
                    helper.hideSpinner(component, event);                                                                                                         
                    var retData = response.getReturnValue();
                    
                    console.log("In CreateSampleReqComp-->c-->handleSubmit_M--> ret Acc Act?-->" +JSON.stringify(retData) );
                    
                    if (!$A.util.isEmpty(retData)) {
                        if(retData == 'No Mp Found'){
                            component.set("v.showMessage",true);
                            component.set("v.initMessage","No Monthly Plan found..");  
                        }else{
                            //Adding Monthly Plan id to the sample request record.
                            fields.Monthly_Plan__c = retData;
                            console.log("In CreateSampleReqComp-->c-->handleSubmit_M-->After Adding MP-->Field Values-->"+JSON.stringify(fields));
                            component.find('sampleRequestForm').submit(fields);
                        }
                    }else{
                        console.log("In CreateSampleReqComp-->c-->handleSubmit_M-->Apex-->No Response......");
                        component.set("v.showMessage",true);
                        component.set("v.initMessage","No Response From Apex.");  
                    }
                }else{
                    helper.hideSpinner(component, event);
                    console.log("In CreateSampleReqComp-->c-->handleSubmit_M-->Apex-->Error-->"+JSON.stringify(response.getError()));
                    component.set("v.showMessage",true);
                    component.set("v.initMessage","Error occured from apex..");  
                }
            });
            $A.enqueueAction(action2);    
        }else{
            helper.hideSpinner(component, event);
            component.set("v.showMessage",true);
            component.set("v.initMessage","Please fill all the mandatory fields. [Account,Month,Year]");
        }
        
    },
    onSave : function(component, event, helper) {
        console.log('In onSave !!!');
        // var fields = event.getParam('fields');
        // console.log("Field Values-->"+JSON.stringify(fields));
    },
    onREFError : function(component, event, helper) {
        helper.hideSpinner(component, event);
        console.log("In CreateSampleReqComp-->c-->onREFError_M-->On REF ERROR");
        helper.showToast({
            "title": "Oops!, Error occurred",
            "type": "error",
            "message": "Error while saving the record."
        });	
        
    },
    
})
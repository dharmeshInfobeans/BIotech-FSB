({
    onInit : function(component,event) {
        
        var accountId = component.get("v.recordId");
        var action = component.get("c.checkAccHasERLAttachmentAndCESRecord");
        action.setParams({
            accId :  accountId  
        });
        action.setCallback(this,function(response){
            var state = response.getState();
            if(state === 'SUCCESS'){
                var respData = response.getReturnValue();
                console.log("ZZ In Sub4ApprovalComp-->H-->onInit_M-->From Apex-->RESP--> " + JSON.stringify(respData));
                if(respData && (respData == 'OK')){
                    component.set("v.showButtons",true);
                }else if(respData && (respData == 'Is B2B2C')){
                    component.set("v.errorMessage",'No Approval process for Distributors customers!');
                    component.set("v.showError",true);
                    
                }else if ($A.util.isUndefinedOrNull(respData)){
                    component.set("v.showError",true);
                }else if(respData && (respData == 'Non Domestic')){
                  component.set("v.showErrorNonDom",true);  
                }
                
            }else{
                var errorMsg = response.getError();
                console.log("ZZ In Sub4ApprovalComp-->H-->onInint-->From Apex-->"+JSON.stringify(errorMsg));
            }
        });
        
        $A.enqueueAction(action);
        
    },
    updateAccount : function(component,event){
        component.set("v.showSpinner",true);
        var accountId = component.get("v.recordId");
        var action = component.get("c.setIsAccHavingERLFieldOnAccount");
        action.setParams({
            accId :  accountId  
        });
        action.setCallback(this,function(response){
            var state = response.getState();
            if(state === 'SUCCESS'){
                var respData = response.getReturnValue();
                if(respData && (respData == 'OK')){
                    component.set("v.showSpinner",false);
                    var toastEvent = $A.get("e.force:showToast");
                    toastEvent.setParams({
                        "title": $A.get("$Label.c.lex_Sub4App_toastSucssTle"),
                        "message": $A.get("$Label.c.lex_Sub4App_toastSucssMsg"),
                        "type":"success"
                    });
                    toastEvent.fire();
                    $A.get("e.force:closeQuickAction").fire();
                     location.reload();
                }else{
                    component.set("v.showSpinner",false);
                    var toastEvent = $A.get("e.force:showToast");
                    toastEvent.setParams({
                        "title": $A.get("$Label.c.lex_Sub4App_toastErrMsg"),
                        "message": JSON.stringify(respData),
                        "type":"error"
                    });
                    toastEvent.fire();
                    $A.get("e.force:closeQuickAction").fire();
                   // location.reload();
                }
       
            }else{
                component.set("v.showSpinner",false);
                var errors = response.getError();
                if (errors) {
                    console.log("ZZ In Sub4ApprovalComp-->H-->updateAcc_M-->From Apex-->Error0 " + JSON.stringify(errors[0]));
                    if (errors[0] && errors[0].message) {
                        console.log("Error message: " + errors[0].message);
                        var toastEvent = $A.get("e.force:showToast");
                        toastEvent.setParams({
                            "title": $A.get("$Label.c.lex_Sub4App_toastErrMsg"),
                            "message": JSON.stringify(errors[0].message),
                            "type": "error"
                        });
                        toastEvent.fire();
                    }else{
                        // Then It has errors[0].pageErrors
                        console.log("ZZ In Sub4ApprovalComp-->H-->updateAcc_M-->From Apex-->Error: " + JSON.stringify(errors[0].pageErrors));
                        var erMsg = errors[0].pageErrors;
                        var strMsg = erMsg.toString();
                        var toastEvent = $A.get("e.force:showToast");
                        toastEvent.setParams({
                            "title": $A.get("$Label.c.lex_Sub4App_toastErrMsg"),
                            "message": "ERROR: "+errors[0].pageErrors[0].statusCode+"     Message: "+errors[0].pageErrors[0].message,
                            "type": "error"
                        });
                        toastEvent.fire();
                    }
                    
                } else {
                    var toastEvent = $A.get("e.force:showToast");
                    toastEvent.setParams({
                        "title": $A.get("$Label.c.lex_Sub4App_toastErrMsg"),
                        "message": JSON.stringify(errors),
                        "type": "error"
                    });
                    toastEvent.fire();
                }
                
                $A.get("e.force:closeQuickAction").fire();
                location.reload();
            }
        });
        
        $A.enqueueAction(action);    
    }
    
})
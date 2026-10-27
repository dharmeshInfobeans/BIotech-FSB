({
    getMetadata : function(component) {
        var action = component.get("c.getBudgetOptions");
        action.setParams({
            "recordId" : component.get("v.recordId"),
            "headerId" : component.get("v.headerId"),
            "cisMarketType": 'Turkey'
        });
        action.setCallback(this,function(response){
            var result = response.getReturnValue();
            console.log('APEX RESP-->'+JSON.stringify(result));
            component.set("v.CISWrapperList",result.CISList);
            component.set("v.grandTotal",result.grandTotal);
            component.set("v.headerId",result.headerId);
            component.set("v.lastHeaderId",result.lastHeaderId);
            console.log('result.lastHeaderId = '+result.lastHeaderId);
            component.set("v.readOnly",result.readOnly);
            
            component.set("v.companyPicklistValues",result.companyPicklistValues);
            component.set("v.productPicklistValues",result.productPicklistValues);
            console.log(result.accountBlocked);
            if(!$A.util.isEmpty(result.error)){
                
                component.set("v.isError",true);
                component.set("v.errorMessage",result.error);
                /*if(result.error=='Customer Evaluation is not submitted for this year.'){
                    component.set("v.errorMessage", $A.get("$Label.c.CIS_apex_ce_not_submitted"));
                }
                if(result.error=='You can not submit CIS. Please contact your system admin.'){
                    component.set("v.errorMessage", $A.get("$Label.c.CIS_apex_unable_to_submit_CIS"));
                }
                 if(result.error=='CIS is locked because approval is pending.'){
                    component.set("v.errorMessage", $A.get("$Label.c.CIS_apex_cis_locked"));
                }*/
                
               // component.set("v.errorMessage",result.error);
            }
        });
        $A.enqueueAction(action);
    },
    saveCIS : function(component) {
        $A.util.removeClass(component.find("spinner"),'slds-hide');
        var CISWrapperList = component.get("v.CISWrapperList");
        for(let i=0;i<CISWrapperList.length;i++){
			var CISItemList = CISWrapperList[i].CISItemList;
            for(let j=0;j<CISItemList.length;j++){
                if($A.util.isEmpty(CISItemList[j].company)){
                    CISItemList[j].surguries = null;
                    CISItemList[j].price = null;
                }
            }
        }
        var action = component.get("c.saveCISRecord");
        action.setParams({
            "recordJSON" : JSON.stringify(CISWrapperList),
            "recordId" : component.get("v.recordId"),
            "headerId" : component.get("v.headerId"),
            "lastHeaderId" : component.get("v.lastHeaderId")
        });
        action.setCallback(this,function(response){
            $A.util.addClass(component.find("spinner"),'slds-hide');
            var result = response.getReturnValue();
            console.log(result);
            if(result.indexOf('ERROR:') == -1){
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": $A.get("$Label.c.lex_Sub4App_toastSucssTle"),
                    "type":"success",
                    "message": $A.get("$Label.c.CIS_ctrl_record_updated")
                });
                toastEvent.fire(); 
                
                $A.get("e.force:closeQuickAction").fire();
                var sObectEvent = $A.get("e.force:navigateToSObject");
                sObectEvent .setParams({
                    "recordId": result
                });
                sObectEvent.fire();
            }else{
                component.set("v.isError",true);
                component.set("v.errorMessage",result);
            }
        });
        $A.enqueueAction(action);
    }
})
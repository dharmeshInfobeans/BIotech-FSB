({
	doInit : function(component, event, helper) {
        console.log("In TurkeyCISCOMP...");
        console.log(component.get("v.recordId"));
		helper.getMetadata(component);
	},
    closeModal : function(component, event, helper) {
        if(component.get("v.approvalMode")){
            window.location.href="/"+component.get("v.headerId");
        }else{
            $A.get("e.force:closeQuickAction").fire();
        }
	},
    calculateTotalValue : function(component, event, helper) {
		var CISWrapperList = component.get("v.CISWrapperList");
        var grandTotal = 0;
        for(let i=0;i<CISWrapperList.length;i++){
            if(!$A.util.isEmpty(CISWrapperList[i].totalValue)){
                grandTotal += CISWrapperList[i].totalValue;
            }
        }
        component.set("v.grandTotal",grandTotal);
	},
    submitCIS : function(component, event, helper) {
		var CISWrapperList = component.get("v.CISWrapperList");
        var isValid = true;
        var hasValue = false;
        console.log(CISWrapperList);
        for(let i=0;i<CISWrapperList.length;i++){
            var CISItemList = CISWrapperList[i].CISItemList;
            
            for(let j=0;j<CISItemList.length;j++){
                if(!$A.util.isEmpty(CISItemList[j].company) 
                   || !$A.util.isEmpty(CISItemList[j].product)
                   || !$A.util.isEmpty(CISItemList[j].surguries)
                   || !$A.util.isEmpty(CISItemList[j].price)
                  ){
                    hasValue = true;
                    if($A.util.isEmpty(CISItemList[j].company) 
                       || $A.util.isEmpty(CISItemList[j].product)
                       || $A.util.isEmpty(CISItemList[j].surguries)
                       || $A.util.isEmpty(CISItemList[j].price)
                      ){
                        isValid=false;
                    }
                }
            }
        }
        if(!hasValue){
            component.set("v.isError",true);
            component.set("v.errorMessage",$A.get("$Label.c.CIS_ctrl_atleast"));
        }else if(!isValid){
            component.set("v.isError",true);
            component.set("v.errorMessage",$A.get("$Label.c.CIS_ctrl_require_column"));
        }else{
            component.set("v.isError",false);
            helper.saveCIS(component);
        }
    },
    approveCIS : function(component, event, helper) {
        $A.util.removeClass(component.find("spinner"),'slds-hide');
        var action = component.get("c.approveCISRecord");
        action.setParams({
            "headerId" : component.get("v.headerId"),
            "status" : component.get("v.approvalStatus"),
            "comments" : component.get("v.approvalComment")
        });
        action.setCallback(this,function(response){
            $A.util.addClass(component.find("spinner"),'slds-hide');
            var result = response.getReturnValue();
            console.log(result);
            if(result == 'SUCCESS'){
                window.location.href="/"+component.get("v.headerId");
            }else{
                if( result=='Record already approved/rejected.'){
                component.set("v.isError",true);
                component.set("v.errorMessage",'Kayıt zaten onaylandı / reddedildi.');  
                }
                
            }
        });
        $A.enqueueAction(action);
    },
    hideToast : function(component, event, helper) {
        component.set("v.isError",false);
    }
})
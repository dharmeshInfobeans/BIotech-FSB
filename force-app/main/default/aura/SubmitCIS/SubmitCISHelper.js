({
    getMetadata : function(component,month,year) {
        var action = component.get("c.getBudgetOptions");
        action.setParams({
            "recordId" : component.get("v.recordId"),
            "headerId" : component.get("v.headerId"),
            "cisMonth" : month,
            "cisYear"  : year
        });
        action.setCallback(this,function(response){
            var result = response.getReturnValue();
            console.log("apex resp-->"+JSON.stringify(result));
            //console.log("apex resp-->CISList-->"+JSON.stringify(result.CISList));
            component.set("v.showCISChildComp",true);
            component.set("v.currency",result.currencyCode);
            component.set("v.CISWrapperList",result.CISList);
            if(result.cisHeaderMonth){
            	component.set("v.selectedMonthVal",result.cisHeaderMonth);    
            }
            
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
            }
        });
        $A.enqueueAction(action);
    },
    saveCIS : function(component,selectedMonth,year) {
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
            "lastHeaderId" : component.get("v.lastHeaderId"),
            "month" : selectedMonth,
            "year"  : year,
            "currencyCode": component.get("v.currency")
        });
        action.setCallback(this,function(response){
            $A.util.addClass(component.find("spinner"),'slds-hide');
            var result = response.getReturnValue();
            console.log(result);
            if(result.indexOf('ERROR:') == -1){
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success!",
                    "type":"success",
                    "message": "The record has been updated successfully."
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
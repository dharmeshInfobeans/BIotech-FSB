({
    doInit : function(component, event, helper) {
        
        console.log('recId-->'+component.get("v.recordId"));
        console.log('headerId-->'+component.get("v.headerId"));
        
        var monMap = component.get("v.monthMap");
        var monthDrpDwnVal = [];
        var d = new Date();
        var currYear = d.getFullYear(); // Year in Integer
        //console.log('currYear-->'+currYear);
        component.set("v.currYear",currYear);
        
        var monthVal = d.getMonth(); // Month in Integer
        //monthVal = 1; // For testing Jan use value as "0" and for feb use "1"
        if(monthVal == 0){
            
            var currMonth = monMap[monthVal];
            component.set("v.currMonth",currMonth); // When Current Month is "Jan"
            component.set("v.prevMonth",monMap[11]);
            component.set("v.prev2prevMonth",monMap[10]);
            monthDrpDwnVal.push(monMap[10]);
            monthDrpDwnVal.push(monMap[11]);
            monthDrpDwnVal.push(currMonth);
            component.set("v.monthPKVL",monthDrpDwnVal);
            //console.log("curr MOnth-->"+ JSON.stringify(component.get("v.currMonth")));
            //console.log("prev MOnth-->"+ JSON.stringify(component.get("v.prevMonth")));
            //console.log("prev2previous MOnth-->"+ JSON.stringify(component.get("v.prev2prevMonth"))); 
        }else if(monthVal == 1){
            
            var currMonth = monMap[monthVal];
            component.set("v.currMonth",currMonth); // When Current Month is "Feb"
            component.set("v.prevMonth",monMap[monthVal-1]);
            component.set("v.prev2prevMonth",monMap[11]);
            
            
            monthDrpDwnVal.push(monMap[11]);
            monthDrpDwnVal.push(monMap[monthVal-1]);
            monthDrpDwnVal.push(currMonth);
            component.set("v.monthPKVL",monthDrpDwnVal);
            //console.log("curr MOnth-->"+ JSON.stringify(component.get("v.currMonth")));
            //console.log("prev MOnth-->"+ JSON.stringify(component.get("v.prevMonth")));
            //console.log("prev2previous MOnth-->"+ JSON.stringify(component.get("v.prev2prevMonth"))); 
        }else{
            
            var currMonth = monMap[monthVal];
            component.set("v.currMonth",currMonth);
            component.set("v.prevMonth",monMap[monthVal-1]);
            component.set("v.prev2prevMonth",monMap[monthVal-2]);
            
            
            monthDrpDwnVal.push(monMap[monthVal-2]);
            monthDrpDwnVal.push(monMap[monthVal-1]);
            monthDrpDwnVal.push(currMonth);
            component.set("v.monthPKVL",monthDrpDwnVal);
            //console.log("curr MOnth-->"+ JSON.stringify(component.get("v.currMonth")));
            //console.log("prev MOnth-->"+ JSON.stringify(component.get("v.prevMonth")));
            //console.log("prev2previous MOnth-->"+ JSON.stringify(component.get("v.prev2prevMonth"))); 
        }
        
        
        var drpdwnComp = component.find("monthVal");
        if(! $A.util.isUndefinedOrNull(drpdwnComp)){
            component.find("monthVal").set("v.value",component.get("v.currMonth"));
            var selectedVal = component.find("monthVal").get("v.value");
            console.log("NewSelected Month-->"+selectedVal);
            
            if(selectedVal){
                var currMonth = component.get("v.currMonth");
                console.log('currMonth'+currMonth);
                if(currMonth =='Jan' && selectedVal != 'Jan'){
                    var currYear = component.get("v.currYear");
                    var year = currYear - 1;
                    console.log("My logVK");
                    //console.log("MonthVK: "+currMonth+" YearVK: "+year);
                    helper.getMetadata(component,selectedVal,year);
                }else if(currMonth =='Feb'){
                    var currYear = component.get("v.currYear");
                    if(selectedVal != 'Feb' && selectedVal != 'Jan'){ // i.e When "Dec" is selected in Feb month
                        var year = currYear - 1;
                        console.log("My logVK1");
                        helper.getMetadata(component,selectedVal,year);
                    }else{
                    	var currYear = component.get("v.currYear");
                        console.log("My logVK2");
                    	helper.getMetadata(component,selectedVal,currYear);
                	}
                }else{
                    var currYear = component.get("v.currYear");
                    console.log("My logVK3"+currYear);
                    helper.getMetadata(component,selectedVal,currYear);
                }
                
            }
            
        }
    },
    onMonthChange : function(component, event, helper) {
        var selectedVal = component.find('monthVal').get('v.value');
        //console.log("NewSelected Month-->"+selectedVal);
        //component.set("v.selectedMonthVal",selectedVal);
        component.set("v.headerId","");
        component.set("v.showCISChildComp",false);
        component.set("v.CISWrapperList",[]);
        
        if(selectedVal){
            var currMonth = component.get("v.currMonth");
            if(currMonth =='Jan' && selectedVal != 'Jan'){
                var currYear = component.get("v.currYear");
                var year = currYear - 1;
                helper.getMetadata(component,selectedVal,year);
            }else if(currMonth =='Feb'){
                var currYear = component.get("v.currYear");
                if(selectedVal != 'Feb' && selectedVal != 'Jan'){ // i.e When "Dec" is selected in Feb month
                    var year = currYear - 1;
                    helper.getMetadata(component,selectedVal,year);
                }else{
                    var currYear = component.get("v.currYear");
                    helper.getMetadata(component,selectedVal,currYear);
                }
            }else{
                var currYear = component.get("v.currYear");
                helper.getMetadata(component,selectedVal,currYear);
            }
            
            
            
        }
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
            component.set("v.errorMessage","Please fill at least one CIS Line.");
        }else if(!isValid){
            component.set("v.isError",true);
            component.set("v.errorMessage","All columns are required for CIS Line.");
        }else{
            component.set("v.isError",false);
            
            var currMonth = component.get("v.currMonth");
            var selectedVal = component.find('monthVal').get('v.value');
            //console.log("onSubmit selectedMonthVal-->"+selectedVal);
            if(currMonth =='Jan' && selectedVal != 'Jan'){
                var currYear = component.get("v.currYear");
                var year = currYear - 1;
                helper.saveCIS(component,selectedVal,year);
                //console.log("C-->onSubmit_M-->currYear-->"+year);
            }else if(currMonth =='Feb'){
                var currYear = component.get("v.currYear");
                if(selectedVal != 'Feb' && selectedVal != 'Jan'){ // i.e When "Dec" is selected in Feb month
                    var year = currYear - 1;
                    //console.log("C-->onSubmit_M-->currYear-->"+year);
                   helper.saveCIS(component,selectedVal,year); 
                }else{ //If selected val is Jan or Feb then pass current year.
                    var currYear = component.get("v.currYear");
                   helper.saveCIS(component,selectedVal,currYear);
                }
            }else{
                var currYear = component.get("v.currYear");
                helper.saveCIS(component,selectedVal,currYear);
            }
            //console.log("C-->onSubmit_M-->selectedMonVal-->"+selectedVal);
            //console.log("C-->onSubmit_M-->currMonth-->"+currMonth);
            //console.log("C-->onSubmit_M-->currYear-->"+component.get("v.currYear"));
            //console.log("C-->onSubmit_M-->selectedMonVal-->"+selectedVal);
            ///if(currMonth = )
            
            
            //helper.saveCIS(component);
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
                component.set("v.isError",true);
                component.set("v.errorMessage",result);
            }
        });
        $A.enqueueAction(action);
    },
    hideToast : function(component, event, helper) {
        component.set("v.isError",false);
    }
})
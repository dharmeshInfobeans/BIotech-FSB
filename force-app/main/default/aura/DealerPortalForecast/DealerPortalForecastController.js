({
    doInitJquery : function(component,event,helper){
        jQuery("document").ready(function(){
            jQuery('.tblCls tbody').scroll(function(e) { //detect a scroll event on the tbody
                /*
    Setting the thead left value to the negative valule of tbody.scrollLeft will make it track the movement
    of the tbody element. Setting an elements left value to that of the tbody.scrollLeft left makes it maintain 			it's relative position at the left of the table.    
    */
                jQuery('.tblCls thead').css("left", -jQuery(".tblCls tbody").scrollLeft()); //fix the thead relative to the body scrolling
                jQuery('.tblCls thead th:nth-child(1)').css("left", jQuery(".tblCls tbody").scrollLeft()); //fix the first cell of the header
                jQuery('.tblCls tbody td:nth-child(1)').css("left", jQuery(".tblCls tbody").scrollLeft()); //fix the first column of tdbody
                jQuery('.tblCls tbody td:nth-child(2)').css("left", jQuery(".tblCls tbody").scrollLeft()); //fix the first column of tdbody
                jQuery('.tblCls thead th:nth-child(2)').css("left", jQuery(".tblCls tbody").scrollLeft()); //fix the first cell of the header
                
            });
        });
        
    },
    
    doInit : function(component,event,helper){
        var regionOptionLst=[];
        var customerOptionLst=[];        
        
        var action = component.get("c.fetchUserDetails");
        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state == "SUCCESS") {
                var result = response.getReturnValue();
                 console.log('result', result);
                 console.log('user profile name', result.Profile.Name);
                console.log('contact id', result.ContactId);
                //Call partner user's methods
                //if(result.IsPortalEnabled == true){
                    console.log('calling partner user methods');
                    
                    //fetch current user's selected region's customers/accounts
                    var action = component.get("c.fetchAccountDetails");
                    action.setParams({"contactId":result.ContactId});
                    action.setCallback(this, function (response){
                        var state = response.getState();
                        if (state == "SUCCESS") {
                            var result = response.getReturnValue();
                            for(var key in result){
                                if(key === 'agreementEndYear') {
                                    component.set("v.lastYear", result[key]);
                                    console.log('BG >>> last year',result[key],component.get("v.lastYear"));
                                }
                                else {
                                    component.set("v.customerName", result[key]); 
                                    component.set("v.selectedCustomerCode", key);
                                }
                                 
                            }
                            
                            //create month and year's picklist values
                            helper.createYearPicklist(component,event,helper);
                            helper.createMonthPicklist(component,event,helper);
                        }
                    });
                    $A.enqueueAction(action);
                //}//
            }
        });
        $A.enqueueAction(action);  
    },
    onClickGoButton : function(component,event,helper){
        var isShowRecord = component.get('v.isShowRecords');
        var fromselectedMonth = component.find("frommonthPickListValues").get("v.value");
        var fromselectedYear = component.find("fromyearPickListValues").get("v.value");
        var toselectedMonth = component.find("tomonthPickListValues").get("v.value");
        var toselectedYear = component.find("toyearPickListValues").get("v.value");
        var selectedCustomerCode = component.get("v.selectedCustomerCode");
        
        component.set("v.fromselectedMonth",fromselectedMonth);
        component.set("v.fromselectedYear",fromselectedYear);
        component.set("v.toselectedMonth",toselectedMonth);
        component.set("v.toselectedYear",toselectedYear);
        component.set("v.selectedCustomerCode",selectedCustomerCode);

        if(!isShowRecord){
            component.set("v.isShowRecords", true);       
        } 
        else{
			var childWeeklyCmpObj = component.find('childWeeklyCmp');
            childWeeklyCmpObj.getPageRecords();
        }
    }
})
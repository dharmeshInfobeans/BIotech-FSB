({
    doInit : function(component,event,helper){
        var regionOptionLst=[];
        var region ={};
        var branchOptionLst=[];
        var branch ={};
        var selectedRegionCode;
        var userId = $A.get("$SObjectType.CurrentUser.Id");
        var action = component.get("c.fetchRegionLst");
        action.setParams({"userId":userId});
        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state == "SUCCESS") {
                var result = response.getReturnValue();
                console.log('resulllt',result);                  
                for(var key in result){
                    regionOptionLst.push({"class": "optionClass",label:result[key],value:key});
                }    
                console.log('regionOptionLst',regionOptionLst);
                component.find("regionPickListValues").set("v.options", regionOptionLst);
                
                for(var key in result){
                    selectedRegionCode = key;
                    break;
                }   
                console.log('selectedRegionCode',selectedRegionCode);
                var action = component.get("c.fetchRelatedBranchLst");
                action.setParams({"selectedRegionCode":selectedRegionCode});
                action.setCallback(this, function (response) {
                    var state = response.getState();
                    if (state == "SUCCESS") {
                        var result = response.getReturnValue();
                        console.log('result',result);    
                        //branchOptionLst.push({"class": "optionClass",label:'All',value:'All'});
                        for(var key in result){
                            branchOptionLst.push({"class": "optionClass",label:key,value:result[key]});
                            //branchOptionLst.push({"class": "optionClass",label:result[key],value:key});
                        }
                        component.find("branchPickListValues").set("v.options", branchOptionLst);
                        component.set("v.branchMap",result);
                        console.log('brannn result',component.get("v.branchMap"));
                        helper.createYearPicklist(component,event,helper);
                        helper.createMonthPicklist(component,event,helper);
                    }
                });
                $A.enqueueAction(action); 
            }
        });
        $A.enqueueAction(action);        
    },
    onChangeregionPicklist : function(component,event,helper){
        var branchOptionLst=[];
        var selectedRegionCode = component.find("regionPickListValues").get("v.value"); 
        console.log('selected region',selectedRegionCode);
        var action = component.get("c.fetchRelatedBranchLst");
        action.setParams({"selectedRegionCode":selectedRegionCode});
        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state == "SUCCESS") {
                var result = response.getReturnValue();
                component.set("v.branchMap",result);
                for(var key in result){
                    branchOptionLst.push({"class": "optionClass",label:key,value:result[key]});
                    //branchOptionLst.push({"class": "optionClass",label:result[key],value:key});
                }
                component.find("branchPickListValues").set("v.options", branchOptionLst);
            }
        });
        $A.enqueueAction(action); 
    },
    onClickGoButton : function(component,event,helper){        
        //component.set("v.isShowSpinner",true);
        var isShowRecord = component.get('v.isShowRecords');
        console.log('show record : ',isShowRecord);
        var userId = $A.get("$SObjectType.CurrentUser.Id");
        var selectedRegionCode = component.find("regionPickListValues").get("v.value");
        var selectedBranchCode = component.find("branchPickListValues").get("v.value");
        //var selectedBranchName = component.find("branchPickListValues").get("v.value");
        var branchMap = component.get("v.branchMap");
        var selectedYear = component.find("yearPickListValues").get("v.value");
        var selectedMonth = component.find("monthPickListValues").get("v.value");     
        var pageNumber = component.get( 'v.pageNumber' );
        var pageSize = component.get( 'v.pageSize' );
        var selectedBranchName;
         for(var key in branchMap){
            if(selectedBranchCode == branchMap[key]){
                selectedBranchName = key;
            }
        }
        
        component.set("v.selectedMonthNumber",selectedMonth);
        component.set("v.selectedMonthYear",selectedYear);
        component.set("v.selectedBranchCode",selectedBranchCode);
        component.set("v.selectedBranchName",selectedBranchName);
        component.set("v.selectedRegionCode",selectedRegionCode);
        
        //newly added on 26/11
        var action = component.get("c.checkSubmitButton");
        action.setParams({'selectedmonthNumber' :  selectedMonth,
                          'selectedmonthYear' : selectedYear,
                          'selectedRegionCode' : selectedRegionCode,
                          'selectedBranchName' : selectedBranchName,
                          'selectedBranchCode' : selectedBranchCode});
        console.log('selected branch name for al',selectedBranchName);
        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state == "SUCCESS") {
                var result = response.getReturnValue();
                console.log('resultuu',result);
                for(var key in result){
                    component.set("v.isDisabled",key);
                    component.set("v.message",result[key]);
                } 
            }
        });
        $A.enqueueAction(action);
        
        if(!isShowRecord){
            component.set("v.isShowRecords", true);       
        } else {
            console.log('In Else condition');
			var childWeeklyCmpObj = component.find('childWeeklyCmp');
            childWeeklyCmpObj.getPageRecords();
        }
        
    },
})
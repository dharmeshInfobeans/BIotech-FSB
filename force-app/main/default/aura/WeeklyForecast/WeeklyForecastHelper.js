({
    // create year picklist
    createYearPicklist : function(component,event,helper){
        var d = new Date();
        var currentYear = d.getFullYear();
        var year=[];
        year.push({"class": "optionClass",label:currentYear, value:currentYear, selected:true});
        
        for(var i=1;i<10;i++){
            year.push({"class": "optionClass",label:currentYear + i, value: currentYear + i });
        }
        component.find("yearPickListValues").set("v.options", year);
    },
    // create month picklist
    createMonthPicklist : function(component,event,helper){
        var dt = new Date();
        var selectedMonth = dt.getMonth() + 1;
        var months = [];
        months.push({"class": "optionClass",label:"January", value:"1"},
                    {"class": "optionClass",label:"February", value:"2"},
                    {"class": "optionClass",label:"March", value:"3"},
                    {"class": "optionClass",label:"April", value:"4"},
                    {"class": "optionClass",label:"May", value:"5"},
                    {"class": "optionClass",label:"June", value:"6"},
                    {"class": "optionClass",label:"July", value:"7"},
                    {"class": "optionClass",label:"August", value:"8"},
                    {"class": "optionClass",label:"September", value:"9"},
                    {"class": "optionClass",label:"October", value:"10"},
                    {"class": "optionClass",label:"November", value:"11"},
                    {"class": "optionClass",label:"December", value:"12"});
        for(var i=0;i<months.length;i++){
            if(months[i].value == selectedMonth)
                months[i].selected = true;
        }
        
        component.find("monthPickListValues").set("v.options", months);
    },
    //fetch current month and next 2/3 months to create tables
    createTableForMonth : function(component,event,helper){
        var selectedRegionCode = component.find("regionPickListValues").get("v.value");
        var selectedBranchCode = component.find("branchPickListValues").get("v.value");
        var branchMap = component.get("v.branchMap");
        var selectedYear = component.find("yearPickListValues").get("v.value");
        var selectedMonth = component.find("monthPickListValues").get("v.value");     
        var pageNumber = component.get( 'v.pageNumber' );
        var pageSize = component.get( 'v.pageSize' );
        var selectedBranchName;
        component.set("v.selectedMonthNumber",selectedMonth);
		component.set("v.selectedMonthYear",selectedYear);
        component.set("v.selectedBranchCode",selectedBranchCode);
		component.set("v.selectedRegionCode",selectedRegionCode);
        console.log('pageNumber in helper'+pageNumber);
        console.log('pageSize in helper'+pageSize);

        for(var key in branchMap){
            if(selectedBranchCode == branchMap[key]){
                selectedBranchName = key;
            }
        }
		console.log('selectedBranchName',selectedBranchName);
        component.set("v.selectedBranchName",selectedBranchName);
        
        var userId = $A.get("$SObjectType.CurrentUser.Id");
        var today = new Date();
        var date = today.getFullYear()+'-'+(today.getMonth()+1)+'-'+today.getDate();
        console.log('today',date);
        component.set("v.currentDate",date);
        console.log('today',component.get("v.currentDate"));
         var mnthNo = today.getMonth();
         //var monthName =  helper.getMonthName(component,event,helper,mnthNo);
        var action = component.get("c.getWeeklyForecastDetails");
        /*action.setParams({'currentDate' : component.get("v.currentDate"), 
                          'monthName' : monthName,
                          'currentUserId' : userId,
                          'selectedYear' : selectedYear,
                          'selectedRegionCode' : selectedRegionCode,
                          'selectedBranchName' : selectedBranchName,
                           'selectedBranchCode' : selectedBranchCode,
                          'selectedMonth' : selectedMonth});*/
        action.setParams({'currentUserId' : userId,
                          'selectedYear' : selectedYear,
                          'selectedRegionCode' : selectedRegionCode,
                          'selectedBranchName' : selectedBranchName,
                           'selectedBranchCode' : selectedBranchCode,
                          'selectedMonth' : selectedMonth,
                          'page':pageNumber, 
                          'pageSize':pageSize});
        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state == "SUCCESS") {
                component.set("v.isShowSpinner",false);
                var result = response.getReturnValue();
                var sRessult = JSON.stringify(result);
                component.set("v.weeklyForecastWrapper", result);
                component.set('v.isShowRecords', true);
                
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
            }
        });
        $A.enqueueAction(action);                   
    },  
    getMonthName: function(component,event,helper,intMonth){
        var month = new Array();
        month[1] = "January";
        month[2] = "February";
        month[3] = "March";
        month[4] = "April";
        month[5] = "May";
        month[6] = "June";
        month[7] = "July";
        month[8] = "August";
        month[9] = "September";
        month[10] = "October";
        month[11] = "November";
        month[12] = "December";
        var n = month[intMonth];
        return n;
    },                   
})
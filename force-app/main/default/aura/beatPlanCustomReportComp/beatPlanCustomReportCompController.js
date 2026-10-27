({
    
    
    handleLwcData: function(component, event, helper) {
        var receivedData = event.getParam('dataToSend');
        component.set('v.receivedData', receivedData);
        console.log('Data',JSON.stringify(receivedData));
        if(receivedData!=undefined) {
            console.log('receivedData : ',receivedData.Country);
            component.set("v.Country", receivedData.Country);
            
            component.set("v.State", receivedData.state);
            
            
        }
        
        
        
    },
    
    
    fetchBeatPlan : function(component, event, helper) {
        var currentValue = event.getSource().get("v.value");
        console.log("Current Value:--- " + currentValue);
        // Update the attribute value if needed
        if(currentValue!="undefined") {
            component.set("v.userCurrentValue", currentValue);

        }
        helper.fetchBeatHelper(component, event, helper);
    },
    
    fetchPicklistDataPlan : function(component, event, helper) {
        helper.fetchPicklistData(component, event, helper);
    },
    //Added function "mySelectedCountry" by gyadeen Ahirwar***********************************
    mySelectedCountry: function(component, event, helper) {
        var selectedCountry = component.get("v.selectedValue5");
        console.log("Selected Country: ", selectedCountry);
        component.set("v.selectedCountry", selectedCountry); // Set selectedCountry to a component attribute
        helper.fetchStatesByCountry(component, event, selectedCountry);
    },
    
    mySelectedState: function(component, event, helper) {
        var selectedState = component.get("v.selectedValue6"); 
        console.log("Selected State: ", selectedState);
        var selectedCountry = component.get("v.selectedCountry"); // Retrieve selectedCountry from component attribute
        
    },
    myselectedRegion: function (component, event, helper) {
    	console.log(component.find("select23").get("v.value"));
       // alert(component.find("select23").get("v.value"));
       
      	var changeRegion = event.getSource().get("v.value");
        component.set("v.RegionVar",changeRegion);
    },
    
    handleClick : function (component, event, helper) {
        
        var receivedData = component.get('v.receivedData');
        var selectedMonthTab  = component.get("v.IsMonthTab");
        //console.log('selectedMonthTab-==-'+component.find("EndDateField").get("v.value"));
        //console.log('StartDateField-==-'+component.find("StartDateField").get("v.value"));
        //if(component.find("EndDateField").get("v.value") != '' && component.find("StartDateField").get("v.value") != ''){
        if(!$A.util.isUndefined(component.find("EndDateField")) && !$A.util.isUndefined(component.find("StartDateField")) && !$A.util.isEmpty(component.find("StartDateField").get("v.value")) && !$A.util.isEmpty(component.find("EndDateField").get("v.value")) )
        {  
            
            var startDate = component.find("StartDateField").get("v.value");
            var endDate = component.find("EndDateField").get("v.value");
            var startDate1 = new Date(startDate), 
                endDate1 = new Date(endDate),
                days = (endDate1-startDate1)/8.64e7;
                console.log('Days',days);
            console.log('End date',endDate1);
            console.log('Start date',startDate1);
            if(endDate1 > startDate1){
                if(days <= 30)
                {
                    var montVar = component.get("v.monthVar");
                    
                    console.log('montVar-=-=-'+montVar);//8
                    var yyrVar =  component.get("v.yrVar");//2019
                    
                    console.log('yyrVar-=-=-'+yyrVar);
                    var regVar = component.get("v.RegionVar");
                    console.log('regionVar--=-='+regVar);
                    
                    helper.fetchRecordAsPerYr(component, event, helper, montVar, yyrVar,regVar,startDate,endDate,selectedMonthTab,receivedData);
                    
                }
                else
                {
                    console.log('111111');
                    helper.showError(component, event, helper, 'Number of Days can not be greater than 30');
                } 
            }
            else{
                console.log('222111111');    
                helper.showError(component, event, helper, 'EndDate Should be greater than Start Date');
            }
            
        }
        else{
            console.log('else11');
            var montVar = component.get("v.monthVar");
            var yyrVar =  component.get("v.yrVar");
            var regVar = component.get("v.RegionVar");
            console.log('else');
            helper.fetchRecordAsPerYr(component, event, helper, montVar, yyrVar,regVar,null,null,selectedMonthTab,receivedData); 
        }
        //}
        /*else{
            console.log('33111111');
            helper.showError(component, event, helper, 'EndDate Should be greater than Start Date');
        }*/
        
        
    },
    myselectedmonth: function (component, event, helper) {
        console.log(component.find("select1").get("v.value"));
        var changeMonth = event.getSource().get("v.value");
        var currentMnth=event.getSource().get("v.label");
        component.set("v.monthVar",changeMonth);
      //  component.set("v.currentmonthNew",currentMnth);
        
    },
        handleStart: function (component, event, helper) {
//console.log(component.find("select1").get("v.value"));
        var currentDateValue = event.getSource().get("v.value");
        var data='';
        console.log('Current start',currentDateValue);
            
            
            if(currentDateValue!=undefined && currentDateValue!='') {
                var listString=currentDateValue.split("-");
                data=listString[2]+'-'+listString[1]+'-'+listString[0];
                
                console.log('data',data);
                component.set("v.sDate", data);
            }else {
                  component.set("v.sDate", '');

            }
       
      //  component.set("v.currentmonthNew",currentMnth);
        
    },
        handleEnd: function (component, event, helper) {
        var currentDateValue = event.getSource().get("v.value");
        console.log('Current End',currentDateValue);
        var data='';
        console.log('Current End',currentDateValue);
            
            
            if(currentDateValue!=undefined   && currentDateValue!='') {
                var listString=currentDateValue.split("-");
                data=listString[2]+'-'+listString[1]+'-'+listString[0];
                
                console.log('data End',data);
                component.set("v.eDate", data);
            }else {
                 component.set("v.eDate", '');

            }
       
      //  component.set("v.currentmonthNew",currentMnth);
        
    },
    
    
    myselectedYr: function (component, event, helper) {
        console.log(component.find("select2").get("v.value"));
        var changeYr = event.getSource().get("v.value");
        var currentYr=event.getSource().get("v.label");
         component.set("v.yrVar",changeYr);
        // component.set("v.currentyear",changeYr);
    },
      handleCurrentMonth: function (component, event, helper) {
        var changeYr = event.getSource().get("v.value");
        var currentYr=event.getSource().get("v.value");
        // component.set("v.yrVar",changeYr);
         component.set("v.currentmonthNew",currentYr);
    },
    myselectedRegion: function (component, event, helper) {
        //console.log(component.find("select23").get("v.value"));
        // alert(component.find("select23").get("v.value"));
        
        var changeRegion = event.getSource().get("v.value");
        component.set("v.RegionVar",changeRegion);
    },
    downloadCsv : function(component,event,helper){
        var csv = helper.convertArrayOfObjectsToCSV(component,component.get("v.test")); 
        if (csv == null){return;} 
        
        // ####--code for create a temp. <a> html tag [link tag] for download the CSV file--####     
        var hiddenElement = document.createElement('a');
        hiddenElement.href = 'data:text/csv;charset=utf-8,' + encodeURI(csv);
        hiddenElement.target = '_self'; // 
        hiddenElement.download = 'ExportData.csv';  // CSV file Name* you can change it.[only name not .csv] 
        document.body.appendChild(hiddenElement); // Required for FireFox browser
        hiddenElement.click();
    },
    // function automatic called by aura:waiting event  
    showSpinner: function(component, event, helper) {
        // make Spinner attribute true for displaying loading spinner 
        component.set("v.spinner", true); 
    },
    // function automatic called by aura:doneWaiting event 
    hideSpinner : function(component,event,helper){
        // make Spinner attribute to false for hiding loading spinner    
        component.set("v.spinner", true);
    },
    handleActiveMonth : function(component,event,helper){
        //alert('uiuiui');
        console.log('test');
             console.log('Date',component.get("v.sDate"));
        console.log('eDate',component.get("v.eDate"));   
        component.set("v.sDate", '');
        component.set("v.eDate", '');
        component.set("v.IsMonthTab", "True");
        var currentyear=component.get("v.currentyear");
        var currentmonth=component.get("v.currentmonth");
        var monthvalues=JSON.stringify(component.get("v.monthNameList"));   
        var ss=JSON.parse(monthvalues);
        var monthvalue;
        if(ss != null){
            for(var i=0;i<ss.length;i++)
            {
                if(ss[i].label==currentmonth)
                {
                    monthvalue=ss[i].value;
                    break;
                }
            }
        }
        component.set("v.selectedValue2",currentyear);
        component.set("v.selectedValue1",monthvalue); 
        console.log('monthvalue',monthvalue);
        
    },
    handleActiveDate : function(component,event,helper){
        console.log('Date',component.get("v.sDate"));
        console.log('eDate',component.get("v.eDate"));             
                    
        
        var currentyear=component.get("v.currentyear");
        var currentmonth=component.get("v.currentmonth");
        component.set("v.IsMonthTab", "false");
        
    },
    handleActiveAddress : function(component,event,helper){
        var selectedCountry=component.get("v.selectedCountry");
        var selectedState=component.get("v.selectedState");
        component.set("v.IsAddressTab", "false");
        
    },
    handleSearchCountry: function(component, event, helper) {
        var searchText = event.target.value.toLowerCase(); // Get search text
        var countryList = component.get("v.countryList"); // Get original country list
        
        if (countryList && countryList.length > 0) {
            var filteredCountries = countryList.filter(function(country) {
                // Check for label containing search text
                return country.label.toLowerCase().includes(searchText);
            });
            component.set("v.filteredCountryList", filteredCountries); // Set filtered list
        } else {
            console.log("Country list is not available or empty.");
        }
    },
    handleSearchState: function(component, event, helper) {
        var searchText = event.target.value.toLowerCase(); // Get search text
        var stateList = component.get("v.stateList"); // Get original state list
        
        if (stateList && stateList.length > 0) {
            var filteredStates = stateList.filter(function(state) {
                // Check for label containing search text
                return state.label.toLowerCase().includes(searchText);
            });
            component.set("v.filteredStateList", filteredStates); // Set filtered list
        } else {
            console.log("State list is not available or empty.");
        }
    },
    
    selectCountryOption: function(component, event, helper) {
        var selectedValue = event.target.dataset.value; 
        component.set("v.selectedCountry", selectedCountry); 
        component.set("v.filteredCountryList", []);
        helper.fetchStatesByCountry(component, event, selectedCountry);
        
    },
    selectStateOption: function(component, event, helper) {
        var selectedValue = event.target.dataset.value; 
        component.set("v.selectedState", selectedState); 
        component.set("v.filteredStateList", []); 
        helper.fetchStatesByCountry(component, event, selectedCountry);
        
    },
    searchCountries: function(component, event, helper) {
        var searchText = event.target.value.toLowerCase();
        var countryList = component.get("v.countryList");
        var filteredCountries = [];
        
        if (countryList && countryList.length > 0) {
            filteredCountries = countryList.filter(function(country) {
                return country.label.toLowerCase().includes(searchText);
            });
        }
        
        component.set("v.filteredCountryList", filteredCountries);
    },
    
    
    searchStates: function(component, event, helper) {
        var searchText = event.target.value.toLowerCase();
        var stateList = component.get("v.stateList");
        var filteredStates = [];
        
        if (stateList && stateList.length > 0) {
            filteredStates = stateList.filter(function(state) {
                return state.label.toLowerCase().includes(searchText);
            });
        }
        
        component.set("v.filteredStateList", filteredStates);
    }
    
 })   
   /* handleStart: function(component, event, helper) {
        var startDate = component.get("v.sDate");
        var endDate = component.get("v.eDate");

        if (startDate && endDate) {
            component.set("v.showMonthFilter", false);
        } else {
            component.set("v.showMonthFilter", true);
        }
    },

    handleEnd: function(component, event, helper) {
        var startDate = component.get("v.sDate");
        var endDate = component.get("v.eDate");

        if (startDate && endDate) {
            component.set("v.showMonthFilter", false);
        } else {
            component.set("v.showMonthFilter", true);
        }
    }
*/
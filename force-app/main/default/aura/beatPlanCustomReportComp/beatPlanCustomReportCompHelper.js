({
    
    convertArrayOfObjectsToCSV : function(component,objectRecords){
        // declare variables
       component.set("v.spinner", true); 
        var data = [];
        var headerArray = [];
        var csvContentArray = [];
        var fileName = "BeatPlan"
        var fielExtension = ".csv";  
        
        headerArray.push('Employee Code');
        headerArray.push('User');
        headerArray.push('User Role');
        headerArray.push('Country');
        
        headerArray.push(component.get("v.dateInMonth"));
        data.push(headerArray);
        
        for(var i=0; i<objectRecords.length; i++)
        {
            var tempArray = [];
            tempArray.push(objectRecords[i].employeecode);
            tempArray.push(objectRecords[i].Id);
            tempArray.push(objectRecords[i].userrolename);
            tempArray.push(objectRecords[i].countryname);
            
            for(var k=0; k<objectRecords[i].Value.length; k++){                
                tempArray.push(objectRecords[i].Value[k].Value);
            }
            
            data.push(tempArray);
        }
        
        for(var j=0; j<data.length; j++)
        {
            var dataString = data[j].join(",");
            csvContentArray.push(dataString);
        }        
        
        var csvContent = csvContentArray.join("\n");     
        component.set("v.spinner", false); 
        return csvContent;        
    },
    fetchBeatHelper: function(component) {  
        component.set("v.spinner", true); 
        var currentValue='';
        var data='';
        data=component.get("v.userCurrentValue");
        if(data!=undefined && data!='') {
            currentValue=data;
        }
        console.log('data',data);
        var action = component.get("c.getfetchBeatPlan");  
        action.setParams({ userName : currentValue,
                         });
        action.setCallback(this, function(response)
                          
                           {
                               var state = response.getState();
                               if (state === "SUCCESS")
                               {
                                   component.set("v.spinner", false); 
                                   var map1 = response.getReturnValue();
                                   console.log('ReturnValue 44',map1);
                                   component.set("v.currentmonth",map1.currentMonth);
                                   component.set("v.currentmonthNew",map1.currentMonthName);
                                   component.set("v.currentyear",map1.currentYear);
                                   component.set("v.currentregion",map1.currentRegion);
                                   component.set("v.ShowMonthYear",true);
                                   component.set("v.attchid",map1.attachmentId);
                                   component.set("v.monthVar",map1.currentMonth);
                                   component.set("v.yrVar",map1.currentYear);
                                   component.set("v.RegionVar",map1.currentRegion);
                                   var  employeecodemap = map1.Employeecodemap;
                                   var  userrolemap = map1.userrolemap;
                                   var  countrynamemap  = map1.countrynamemap;
                                   console.log('Country Map--',countrynamemap);
                                   //console.log('12345', userrolemap);
                                   var dateList = [];
                                   var i = 1;
                                   for (var key in map1.beatdateList) {
                                       dateList.push(i++);
                                   }
                                   component.set("v.dateInMonth",dateList);
                                   var optionsList = [];
                                   for (var key in map1.numMonthList) {
                                       if (map1.numMonthList.hasOwnProperty(key)) {
                                           optionsList.push({value: key, label: map1.numMonthList[key]});
                                       }  
                                   } 
                                   
                                   //component.set("v.wrapList",beatObjAllValues.warpObj);
                                   //console.log(component.get("v.wrapList"));
                                   
                                   component.set("v.monthNameList",optionsList);
                                   var yrList = [];
                                   for (var key in map1.yrList) {
                                       if (map1.yrList.hasOwnProperty(key)) {
                                           yrList.push({value: key, label: map1.yrList[key]});
                                       }
                                   }
                                   
                                   component.set("v.yrNameList",yrList);
                                   var regionList = [];
                                   for (var key in map1.numRegionList) {
                                       if (map1.numRegionList.hasOwnProperty(key)) {
                                           regionList.push({value: key, label: map1.numRegionList[key]});
                                       }
                                   }
                                   component.set("v.regionNameList",regionList);
                                   
                                   var map = map1.mapOfMap;
                                   var parsingWarpper=[];
                                   
                                   //Iterate over the key for Outer Map
                                   Object.keys(map).forEach(function(key) {
                                       
                                       var individualElement = {};
                                       individualElement.employeecode = employeecodemap[key];
                                       individualElement.Id = key;
                                       individualElement.userrolename = userrolemap[key];
                                       individualElement.countryname = countrynamemap[key];
                                      // if(countrynamemap[key]!=undenfined) {
                                         //  individualElement.countryname = countrynamemap[key];

                                      // }
                                       individualElement.Value =[];
                                       var innerMapObject =map[key];
                                       console.log('innerMapObject',innerMapObject);
                                       
                                       //Iterate over the key for Inner  Map
                                       Object.keys(innerMapObject).forEach(function(key2) {
                                           //console.log(key2);
                                           var innerIndivididualElement ={};
                                           innerIndivididualElement.Key = key2;
                                           innerIndivididualElement.Value = innerMapObject[key2];
                                           console.log('innerIndivididualElement.Value',innerIndivididualElement.Value);
                                           individualElement.Value.push(innerIndivididualElement);
                                       });  
                                       parsingWarpper.push(individualElement); 
                                       
                                       
                                   });
                                   console.log('parsingWarpper befor');
                                   console.log(parsingWarpper);
                                   var rr = parsingWarpper.sort();
                                   console.log('parsingWarpper after');
                                   console.log(rr);
                                   component.set("v.test",rr);
                                    component.set("v.spinner", false); 
                                   
                               }else
                               {
                                   component.set("v.spinner", true); 
                                   console.debug(response.error[0].message);
                               }
                           });
        $A.enqueueAction(action);
    },
    fetchRecordAsPerYr : function(component, event, helper, montVar, yyrVar,regVar,startDate,endDate,selectedMonthTab,receivedData) {
        console.log('receivedData------133:',JSON.stringify(receivedData));
        console.log('startDate==>' +startDate);
        console.log('component',component);
        console.log('endDate==>' +endDate);
        console.log('event==>' +event);
        console.log('helper',helper);
        console.log('montVar==>' +montVar);
        console.log('yyrVar==>' +yyrVar);
        console.log('regVar==>' +regVar);
        console.log('selectedMonthTab',selectedMonthTab);
        console.log('montVar==>' +montVar);
        
        component.set("v.spinner", true); 
        var action = component.get("c.getSearchedBeatPlan");  
         var currentValue='';
        var data=component.get("v.userCurrentValue");
        if(data!=undefined && data!='') {
            currentValue=data;
        }
        console.log('data',data);
        action.setParams({ selectedYr : yyrVar,
                          selectedMonths : montVar,
                          selectedreg : regVar,
                          startDate : startDate,
                          endDate : endDate,
                          selectedMonthTab : selectedMonthTab,
                          receivedData : JSON.stringify(receivedData),
                          userName:currentValue
                         });
        action.setCallback(this, function(response)
                           {
                               var state = response.getState();
                               if (state === "SUCCESS")
                               {	
                                   component.set("v.spinner", false); 
                                   component.set("v.dateInMonth",'');
                                   component.set("v.test",'');
                                   var map1 = response.getReturnValue();  
                                   console.log('map1');
                                   console.log('map1',map1);
                                   //component.set("v.dateInMonth",map1.beatdateListNew);
                                   var dateList = [];
                                   var i = 1;
                                   if(map1.IscurrentdateTab == false){
                                       for (var key in map1.beatdateListNew) {
                                           dateList.push(i++);
                                       }
                                       component.set("v.dateInMonth",dateList);
                                   }
                                   else{
                                       console.log('logg1');
                                       console.log(Object.values(map1.beatdateListNew).length);
                                       console.log('logg2');
                                       console.log('logg2--->',Object.values(map1.beatdateListNew));
                                       for(var i=0; i < Object.values(map1.beatdateListNew).length; i++){
                                           component.set("v.dateInMonth",Object.values(map1.beatdateListNew));       
                                       }
                                       
                                   }
                                   var  userrolemap = map1.userrolemap;
                                   var  employeecodemap = map1.Employeecodemap;
                                   var countrynamemap = map1.countrynamemap;
                                   
                                   console.log('i am in55555');
                                   console.log(component.get("v.dateInMonth"));
                                   var map = map1.mapOfMapNew;                                   
                                   var parsingWarpper=[];
                                   //console.log('i am in'); 
                                   //Iterate over the key for Outer Map
                                   Object.keys(map).forEach(function(key) {
                                       //console.log('i am in'); 
                                       
                                       var individualElement = {};
                                       individualElement.employeecode = employeecodemap[key];
                                       individualElement.userrolename = userrolemap[key];
                                       individualElement.countryname = countrynamemap[key];
                                       
                                       individualElement.Id = key;
                                       individualElement.Value =[];
                                       var innerMapObject =map[key];
                                       
                                       //Iterate over the key for Inner  Map
                                       Object.keys(innerMapObject).forEach(function(key2) {
                                           // console.log(key2);
                                           //console.log('i am in'); 
                                           var innerIndivididualElement ={};
                                           innerIndivididualElement.Key = key2;
                                           innerIndivididualElement.Value = innerMapObject[key2];
                                           //dateList.Key.push(innerIndivididualElement);
                                           individualElement.Value.push(innerIndivididualElement);
                                           console.log(individualElement); 
                                       });  
                                       parsingWarpper.push(individualElement);
                                       //console.log('parsingWarpper');                  
                                       //console.log(parsingWarpper);           
                                       
                                   });
                                   var rr = parsingWarpper.sort();
                                   console.log('Date list',JSON.stringify(component.get("v.dateInMonth")));
                                   console.log('parsingWarpper after');
                                   console.log(rr);
                                   component.set("v.test",rr);
                                   //component.set("v.test",parsingWarpper);   
                                   component.set("v.spinner", false); 
                               }else
                               {
                                   console.log(response.error[0].message);
                               }
                           });
        $A.enqueueAction(action);
    },
    showError : function(component, event, helper, displayError)
    {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            title : 'Error Message',
            message: displayError,
            messageTemplate: 'Mode is pester ,duration is 5sec and Message is overrriden',
            duration:' 5000',
            key: 'info_alt',
            type: 'error',
            mode: 'pester'
        });
        toastEvent.fire();
        
    },
    
    fetchPicklistData: function(component, event, helper) {
        var action = component.get("c.getPicklistData");
        component.set("v.spinner", true); 
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                component.set("v.spinner", false); 
                var picklistData = response.getReturnValue();
                console.log('Picklist data', picklistData);
                
                component.set("v.countryList", picklistData.Country__c);
                component.set("v.spinner", false); 
                  
            } else {
                console.log("Error fetching picklist data: " + state);
            }
        });
        $A.enqueueAction(action);
    },
    
    fetchStatesByCountry: function(component,event,selectedCountry) {
        component.set("v.spinner", true); 
        console.log('Componenet',component);
        console.log('current value',selectedCountry);
        var action = component.get("c.getStateDatas");
        action.setParams({ country: selectedCountry });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                component.set("v.spinner", false); 
                var stateData = response.getReturnValue();
                console.log('State data', stateData);
                console.log('v.stateList', component.get("v.stateList"));
                component.set("v.stateList", stateData.State);
                component.set("v.spinner", false); 
            } else {
                console.log("Error fetching state data: " + state);
            }
        });
        $A.enqueueAction(action);
    }
    
    
})
/*({
    handleInputChange : function(component, event, helper) {
       // var userInput = component.find("userName").get("c.user");
        var userInput = component.get("c.getSearchedBeatPlan"); 
        // You can use 'userInput' here or perform any other logic.
    }
})*/
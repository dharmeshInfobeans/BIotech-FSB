({
    doInit : function(component, event, helper) {
        //component.set("v.firstLoad",true);
        var monMap = component.get("v.monthMap");
        var d = new Date();
        var currYear = d.getFullYear();
        var currMonth = monMap[d.getMonth()];
        component.set("v.showTab",currMonth); // default tab--> current month
        component.set("v.month",currMonth);
        component.set("v.year",currYear);
        
        
        var lettMonthVsNumMonthMap = component.get("v.textMonthVsNumMonthMap");
        var numMonthVsLettMonthMap = component.get("v.numMonthVsTextMonthMap");
        var tabIdVsTrueOrFalse = component.get("v.passValueMap"); // This will be used to pass value (tab vs boolean(to lock/unlock )) to helper method 
        //console.log("In SalesPlanningDom-->C-->onActiveTabHandler_M-->tabIdVsTrueOrFalse MAp-->"+JSON.stringify(tabIdVsTrueOrFalse));
        var currMonthValueFromMap = lettMonthVsNumMonthMap[currMonth];
        //currMonthValueFromMap = 1;
        //console.log(currMonthValueFromMap)
        for(let key in Object.keys(lettMonthVsNumMonthMap)){
            if( key >= currMonthValueFromMap){
                //console.log("In SalesPlanningDom-->C-->onActiveTabHandler_M-->key >= -->key-->"+key);
                //console.log('key >= -->numMonthVsLettMonthMap[key]-->'+numMonthVsLettMonthMap[key]);
                tabIdVsTrueOrFalse[numMonthVsLettMonthMap[key]] = false;
                //console.log("In SalesPlanningDom-->C-->onActiveTabHandler_M-->key >= -->tabIdVsTrueOrFalse[numMonthVsLettMonthMap[key]]-->"+tabIdVsTrueOrFalse[numMonthVsLettMonthMap[key]]);
                //console.log(tabIdVsTrueOrFalse);
                //console.log(key);
            }else if(key < currMonthValueFromMap ){
                //console.log("In SalesPlanningDom-->C-->onActiveTabHandler_M-->key < --> key-->"+key);
                //console.log(numMonthVsLettMonthMap[key]);
                tabIdVsTrueOrFalse[numMonthVsLettMonthMap[key]] = true;
                //console.log("In SalesPlanningDom-->C-->onActiveTabHandler_M-->Key-->"+key);
            } 
        }
        
        
        
    },
    handleComponentEvent: function(component, event, helper) {
        console.log("In SalesPlanningDom-->C-->handleComponentEvent_M-->Comp Event Received in Parent!!");
        var nextTab = event.getParam("nextTab");
        var currTab = event.getParam("currentTab");
        console.log("In SalesPlanningDom-->C-->handleComponentEvent_M-->Comp Event Received in Parent VALUE-->Curr-->" + currTab);
        console.log("In SalesPlanningDom-->C-->handleComponentEvent_M-->Comp Event Received in Parent VALUE-->Nxt-->" + nextTab);
        
        // set the handler attributes based on event data
        component.set("v.showTab", nextTab);
        component.set("v.currentTab", currTab);
        
        
        //component.set("v.refreshChildTab",true);
        //component.set("v.firstLoad",false);
        
        //var childComp = component.find(message);
        //childComp.refreshChildMethod();
        // var numEventsHandled = parseInt(component.get("v.numEvents")) + 1;
        // component.set("v.numEvents", numEventsHandled);
    },
    
    handleChange: function(component,event,helper) {
        //console.log("In SalesPlanningDom-->C-->handleChange_M !!!");
        
        var selected = component.get("v.showTab");
        //console.log("In SalesPlanningDom-->C-->handleChange_M-->-->TAbID-->" + selected);
        component.find("salesTab").set("v.selectedTabId", selected);
        
        //console.log("In SalesPlanningDom-->C-->handleChange_M-->new/current value: " + event.getParam("value"));
        var oldTabId = event.getParam("oldValue");
        //console.log("In SalesPlanningDom-->C-->handleChange_M-->old value: " + oldTabId);
        if(!$A.util.isEmpty(oldTabId)){
            //Now Destroy The Previous Dynamically Created Tab Content Component as it will cause memory leakage if not destroyed.
            helper.handleDestroy(component,event,oldTabId);   
        }
        
    },
    onActiveTabHandler : function(component,event,helper){
        //console.log("In SalesPlanningDom-->C-->onActiveTabHandler_M Active Tab!!!");
        /* var firstLoaded = component.get("v.firstLoad");
        if(firstLoaded == false){
            console.log("In Parent-->C-->onActiveTabHandler_M--> Inside If!");
            var selectTab = component.find("salesTab").get("v.selectedTabId");
            console.log("In Parent-->C-->onActiveTabHandler_M-->Refresh Selected Tab-->"+selectTab);
            var selectedTabComp = component.find(selectTab);
            selectedTabComp.refreshChildMethod('fromParent');   
        }*/
        

        
        // This helper method will create Tab Content Dynamically each time when current tab("v.showtab" attrib value) is changed.
        helper.handleActive(component,event);
        
    },
    onTabBlur : function(component,event){
        //console.log("In SalesPlanningDom-->C-->onTabBlur_M !!!");   
        //console.log("In SalesPlanningDom-->C-->onTabBlur-->v.showTab-->"+component.get("v.showTab"));
        
        var currTabId = event.getSource().get('v.id');
        //console.log("In  SalesPlanningDom-->-->C-->onTabBlur--> currTabId-->"+currTabId);
        if(component.find(currTabId)!=null || component.find(currTabId)!='undefined'){
            //console.log("In  SalesPlanningDom-->-->C-->onTabBlur_M-->Inside Destroy!!!");
            component.find(currTabId).destroy();
            //console.log("In SalesPlanningDom-->-->C-->onTabBlur_M-->COMP-->"+currTabId+" is Destroyed...");
        }else{
            //alert(' Component is already Destroyed ');
        }        
    },
    
    
    
    
});
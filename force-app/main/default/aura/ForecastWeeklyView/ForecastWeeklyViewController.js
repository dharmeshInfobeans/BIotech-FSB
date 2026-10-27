({
    doInit : function(component, event, helper) { 
         component.set("v.isShowSpinnerChild",true);
        console.log('spinner',component.get("v.isShowSpinnerChild"));
		var pageNumber = component.get( 'v.pageNumber' );
        var pageSize = component.get( 'v.pageSize' );
        console.log('pageNumber'+pageNumber);
        console.log('pageSize'+pageSize);
       	helper.firePageChangeEvent( component, pageNumber, pageSize );
        
    },
	saveWeeklyForecastRecords : function(component, event, helper) {
        component.set("v.isShowSpinnerChild",true);
        var rec = component.get("v.weeklyForecastObj");
        var sRec = JSON.stringify(rec);
        var action = component.get("c.saveForecastRecords");
        action.setParams({'forecastWeeklyWrapper' :  sRec});
         action.setCallback(this, function (response) {
            var state = response.getState();
            if (state == "SUCCESS") {
                component.set("v.isShowSpinnerChild",false);
                var result = response.getReturnValue();
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success!",
                    "message": "The record has been updated successfully."
                });
                toastEvent.fire();
            }
        });
        $A.enqueueAction(action);   
	},
    submitWeeklyForecastRecords : function(component, event, helper){
        component.set("v.isShowSpinnerChild",true);
        var selectedBranchCode = component.get("v.selectedBranchCode");
        var selectedBranchName = component.get("v.selectedBranchName");
        var selectedRegionCode = component.get("v.selectedRegionCode");
        console.log('selected branch name in helpr',selectedBranchName);
        var action = component.get("c.submitForecastRecords");
         action.setParams({'selectedBranchName' : selectedBranchName,
                           'selectedBranchCode' :  selectedBranchCode,
                           'selectedRegionCode' : selectedRegionCode});
        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state == "SUCCESS") {
                component.set("v.isShowSpinnerChild",false);
                var result = response.getReturnValue();
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Success!",
                    "message": "The records has been submitted successfully and email has been sent to logistics team."
                });
                toastEvent.fire();
                var result = response.getReturnValue();
                console.log('resultuu',result);
                for(var key in result) {
                    component.set("v.isDisabled",key);
                    component.set("v.message",result[key]);
                }
                
                var compEvent = component.getEvent("refreshChildComponent");
				compEvent.fire();                
            }
        });
         $A.enqueueAction(action); 
    },
    
    scroll : function(component, event, helper){
        //debugger;
        console.log(component.get('v.hasMoreProductRecord'));
        if( component.get('v.hasMoreProductRecord')==true){
            
            var divObj = component.find('divScroll');
            divObj = divObj.getElement();
            console.log('scrollHeight****'+divObj.scrollHeight);
            console.log('offsetHeight*****'+divObj.offsetHeight);
            console.log('***divObj.scrollTop ***'+divObj.scrollTop);
            var threshold  = 10;
            var position  = divObj.scrollTop + divObj.offsetHeight;
            
            //if(divObj.scrollTop === (divObj.scrollHeight - divObj.offsetHeight)){
            if(position > divObj.scrollHeight-threshold){
                //debugger;
                //debugger;
                //console.log('inside div if');
                helper.getNextPage(component);
            }
        }
    },
    
    getNextPageRecords : function(component, event, helper){
        component.set("v.isShowSpinnerChild",true);
        component.set('v.hasMoreProductRecord', true);
        component.set('v.pageNumber', 0);
        //helper.getNextPage (component);
        var pageSize = component.get( 'v.pageSize' );
        var pageNumber = 1;
         component.set( 'v.pageNumber', pageNumber );
        helper.firePageChangeEvent( component, pageNumber, pageSize );
    }
})
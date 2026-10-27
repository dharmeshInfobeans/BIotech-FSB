({

    doInit : function(component, event, helper) { 
        component.set("v.isShowSpinnerChild",true);
        var pageNumber = component.get( 'v.pageNumber' );
        var pageSize = component.get( 'v.pageSize' );
        //var pageSize = 3;
        helper.firePageChangeEvent( component, pageNumber, pageSize );       
        console.log('page sixe'+pageSize);

        
    },
    
    scroll : function(component, event, helper){
        if( component.get('v.hasMoreProductRecord')==true){            
            var divObj = component.find('divScroll');
            divObj = divObj.getElement();
            var threshold  = 10;
            var position  = divObj.scrollTop + divObj.offsetHeight;
            
            if(position > divObj.scrollHeight-threshold){
                helper.getNextPage(component);
            }
        }
    },
    
    getNextPageRecords : function(component, event, helper){
        component.set("v.isShowSpinnerChild",true);
        component.set('v.hasMoreProductRecord', true);
        component.set('v.pageNumber', 0);
        var pageSize = component.get( 'v.pageSize' );
        var pageNumber = 1;
        component.set( 'v.pageNumber', pageNumber );
        helper.firePageChangeEvent( component, pageNumber, pageSize );
    },
    savePortalWeeklyForecastRecords : function(component, event, helper) {
        component.set("v.isShowSpinnerChild",true);
        var rec = component.get("v.weeklyForecastObj");
        
        for(var i = 0; i < rec.weeklyProductObj.length; i++){
            for(var j = 0; j < rec.weeklyProductObj[i].lstMonthWiseWeeks.length; j++){
                for(var k = 0 ; k < rec.weeklyProductObj[i].lstMonthWiseWeeks[j].weeklyForecastObj.length; k++){
                    if(rec.weeklyProductObj[i].lstMonthWiseWeeks[j].weeklyForecastObj[k].forecastQty == ""){
                        rec.weeklyProductObj[i].lstMonthWiseWeeks[j].weeklyForecastObj[k].forecastQty = 0; 
                    }
                    
                }
            }
        }
        component.set("v.weeklyForecastObj",rec);
        var updatedRec = component.get("v.weeklyForecastObj");
        var sRec = JSON.stringify(updatedRec);
        
        var action = component.get("c.savePortalForecastRecords");
        action.setParams({'forecastWeeklyWrapper' :  sRec});
        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state == "SUCCESS") {
                component.set("v.isShowSpinnerChild",false);
                var result = response.getReturnValue();
                console.log('method result**', result);
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": $A.get("$Label.c.Success"),
                    "message": $A.get("$Label.c.The_record_has_been_updated_successfully")
                });
                toastEvent.fire();
            }
        });
        $A.enqueueAction(action);   
    }
})
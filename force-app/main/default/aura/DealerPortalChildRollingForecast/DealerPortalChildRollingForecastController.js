({
    updateForecastTotal : function(component, event, helper) {
        var montWiseWeeksLst = component.get("v.monthWiseWeekobj");
        var totalForecastQty =0;

        for(var i=0;i<montWiseWeeksLst.length;i++){
            totalForecastQty = 0;
            for( var j=0;j<montWiseWeeksLst[i].weeklyForecastObj.length;j++){
                if(montWiseWeeksLst[i].year == montWiseWeeksLst[i].weeklyForecastObj[j].year &&
                   montWiseWeeksLst[i].monthName == montWiseWeeksLst[i].weeklyForecastObj[j].monthName){
                    console.log('qty',montWiseWeeksLst[i].weeklyForecastObj[j].forecastQty);
                    if(montWiseWeeksLst[i].weeklyForecastObj[j].forecastQty == ''){
                        montWiseWeeksLst[i].weeklyForecastObj[j].forecastQty = 0;
                    }
                    if(typeof montWiseWeeksLst[i].weeklyForecastObj[j].forecastQty !== 'undefined'){ 
                        totalForecastQty = totalForecastQty + parseInt(montWiseWeeksLst[i].weeklyForecastObj[j].forecastQty);
                        montWiseWeeksLst[i].totalForecast = totalForecastQty;
                    }
                }                
            }
        } 
        component.set("v.monthWiseWeekobj",montWiseWeeksLst);
    }
})
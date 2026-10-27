({
	updateForecastTotal : function(component, event, helper) {
        var montWiseWeeksLst = component.get("v.monthWiseWeekobj");
        console.log('montWiseWeeksLst',montWiseWeeksLst);
         var totalForecastQty =0;
        for(var i=0;i<montWiseWeeksLst.length;i++){
            totalForecastQty = 0;
            for( var j=0;j<montWiseWeeksLst[i].weeklyForecastObj.length;j++){
                if(montWiseWeeksLst[i].year == montWiseWeeksLst[i].weeklyForecastObj[j].year &&
                   montWiseWeeksLst[i].monthName == montWiseWeeksLst[i].weeklyForecastObj[j].monthName){
                    if(typeof montWiseWeeksLst[i].weeklyForecastObj[j].forecastQty !== 'undefined' && montWiseWeeksLst[i].weeklyForecastObj[j].forecastQty!= 0){ 
                        totalForecastQty = totalForecastQty + parseInt(montWiseWeeksLst[i].weeklyForecastObj[j].forecastQty);
                        montWiseWeeksLst[i].totalForecast = totalForecastQty;
                        console.log('mop',montWiseWeeksLst[i].mopValue);
                        if(typeof montWiseWeeksLst[i].mopValue !== 'undefined'){
                            montWiseWeeksLst[i].forecastActualVariance = montWiseWeeksLst[i].totalForecast - montWiseWeeksLst[i].mopValue;  
                        }
                        else{
                           montWiseWeeksLst[i].forecastActualVariance = montWiseWeeksLst[i].totalForecast;   
                        }
                    }
                }                
            }
        } 
        component.set("v.monthWiseWeekobj",montWiseWeeksLst);
	},
    updateActualTotal : function(component, event, helper) {
        var montWiseWeeksLst = component.get("v.monthWiseWeekobj");
        console.log('montWiseWeeksLst',montWiseWeeksLst);
         var totalActualQty =0;
        for(var i=0;i<montWiseWeeksLst.length;i++){
            totalActualQty = 0;
            for( var j=0;j<montWiseWeeksLst[i].weeklyForecastObj.length;j++){
                if(montWiseWeeksLst[i].year == montWiseWeeksLst[i].weeklyForecastObj[j].year &&
                   montWiseWeeksLst[i].monthName == montWiseWeeksLst[i].weeklyForecastObj[j].monthName){
                    if(montWiseWeeksLst[i].weeklyForecastObj[j].actualQty!= 'Undefined' && montWiseWeeksLst[i].weeklyForecastObj[j].actualQty!= 0){ 
                        totalActualQty = totalActualQty + parseInt(montWiseWeeksLst[i].weeklyForecastObj[j].actualQty);
                        montWiseWeeksLst[i].totalActual = totalActualQty;
                        //montWiseWeeksLst[i].forecastActualVariance = montWiseWeeksLst[i].totalForecast - montWiseWeeksLst[i].mopValue;
                        //montWiseWeeksLst[i].forecastActualVariance = montWiseWeeksLst[i].totalActual - montWiseWeeksLst[i].totalForecast;
                        //montWiseWeeksLst[i].budCons = (montWiseWeeksLst[i].forecastActualVariance / montWiseWeeksLst[i].totalForecast) * 100;
                        //montWiseWeeksLst[i].budCons = Math.round((montWiseWeeksLst[i].totalActual / montWiseWeeksLst[i].totalForecast) * 100);
                    }
                }                
            }
        } 
        component.set("v.monthWiseWeekobj",montWiseWeeksLst);
	},
})
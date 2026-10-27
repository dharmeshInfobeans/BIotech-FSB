({
    showSpinner : function(component, event) {
        component.set("v.showSpinner",true);
    },
    hideSpinner : function(component, event) {
        component.set("v.showSpinner",false); 
    },
    showToast : function(params){
        var toastEvent = $A.get("e.force:showToast");
        if(toastEvent){
            toastEvent.setParams(params);
            toastEvent.fire();
        } else{
            alert(params.message);
        }
    },
    onReset : function(component, event) {
        var resetVal = [];
        component.set("v.mpps",resetVal);
        $A.get('e.force:refreshView').fire();
        
    },
    checkLastDayForPlanningIsNotElapsed : function(lastDay){
        var d = new Date();
        var currDate = d.getDate();
        //console.log("In Trget&PlaningComp-->H-->checkLastDayForPlanningIsNotElapsed_M-->currDate-->"+currDate);
        //console.log("In Trget&PlaningComp-->H-->checkLastDayForPlanningIsNotElapsed_M-->LastDate-->"+lastDay);
        var test = (currDate <= lastDay);
        //console.log("In Trget&PlaningComp-->H-->checkLastDayForPlanningIsNotElapsed_M-->currDate <= lastDay-->"+test);
        if(currDate <= lastDay){
            return false;
        }else{
            return true;
        }  
    },
    lockAllInputTextBox: function(component,event){
        // console.log("In Trget&PlaningComp-->H-->IN lockAllInputTextBox_M !!!");
        var allIdsArray = component.get("v.allRowCellIds"); // Contains all HTML Ids of Input Textbox rendered on page.
        
        //var t1 = performance.now();
        
        for(let a = 0; a < allIdsArray.length; a++){
            document.getElementById(allIdsArray[a]).disabled = true;   
        }	    
    },
    
    lockSavedMonthlyPlanValue : function(component, event) {
        // console.log('In Trget&PlaningCompDom-->H--> In lockSavedMonthlyPlanValue_M !!');
        var elemntMap = component.get("v.testMap");
        for (var key of Object.keys(elemntMap)) {
            if(! $A.util.isEmpty(document.getElementById(key))){
                document.getElementById(key).disabled = true;
            }
        }
    },
    unlockSavedMonthlyPlanValue : function(component, event) {
        //console.log('In Trget&PlaningCompDom-->H--> In unlockSavedMonthlyPlanValue_M !!');
        var elemntMap = component.get("v.testMap");
        for (var key of Object.keys(elemntMap)) {
            if(! $A.util.isEmpty(document.getElementById(key))){
                document.getElementById(key).disabled = false;
            }
        }
    },
    updateExistingMppValueOnHtmlElement  : function(component, event) {
        //console.log('In Rendering Helper!');
        var elemntMap = component.get("v.testMap"); // stores existing mpp value's against Id(prod+acc+mp).
        console.log('MPP ARRAY SIZE-->'+Object.keys(elemntMap).length);
        console.log('MPP ARRAY VAL-->'+JSON.stringify(elemntMap));
        //var tstMap2 = component.get("v.testMap2");
        
        var productArray = component.get("v.totalTarget");
        
        //var tarHTMLElemIdMap = component.get("v.targetElemntHTMLIdMap"); // Contains Key--> ProdId And Value-->prodId+AopId
        
        //console.log("PRODUCT ARRAY-->"+JSON.stringify(productArray));
        
        //populate existing mpp value's against Id(prod+acc+mp).
        for (var key of Object.keys(elemntMap)) {
            if(! $A.util.isEmpty(document.getElementById(key))){
                document.getElementById(key).value = new Number((elemntMap[key]));
            }
        }
        
        var groupedArray = this.getGroupedArrayByProperty(productArray,'Id');
        //console.log('GROUPED ARRAY-->'+JSON.stringify(groupedArray));
        let finalMap = {};
        for (var key of Object.keys(groupedArray)) {
            //console.log(sumBYID[key]);
            finalMap[key] = groupedArray[key].reduce((a, b) => a + b, 0);
            
        }
        //console.log('FINAL MAP SUM-->'+JSON.stringify(finalMap));
        
        // USE THIS IF "Monthly_Target__c" is PRESENT on MPP Record.
        for (var k of Object.keys(finalMap)) {
            //console.log('document.getElementById('+k+').innerHTML-->'+document.getElementById(k).innerHTML);
            
            if(!$A.util.isEmpty(document.getElementById(k))){
                //document.getElementById(k).innerHTML = '';
                if(! $A.util.isEmpty(document.getElementById(k).innerHTML)){
                    //Added on 05042019 document.getElementById(k).innerHTML = (parseInt((document.getElementById(k).innerHTML) - parseInt(finalMap[k])).toString());   
                    document.getElementById(k).innerHTML = 'Remaining: '+((parseInt((document.getElementById(k).innerHTML).split(":")[1]) - parseInt(finalMap[k])).toString());   
                }    
            }
        }
        
        /* USE THIS IF "Monthly_Target__c" is NOT There on MPP Record.
         * If we use "vtargetElemntHTMLIdMap" attribute (as in this case "Monthly_Target__c" field is not there in existing MPP)
         * for (var k of Object.keys(finalMap)) {
            //console.log('document.getElementById('+k+').innerHTML-->'+document.getElementById(k).innerHTML);
            //console.log('In Targt&Plng-->H-->updateExistingMppValueOnHtmlElement_M-->k-->'+k);
            //console.log('In Targt&Plng-->H-->updateExistingMppValueOnHtmlElement_M-->tarHTMLElemIdMap[k]-->'+tarHTMLElemIdMap[k]);
            for (var x of Object.keys(tarHTMLElemIdMap)){
                if(k == x){
                    if(!$A.util.isEmpty(document.getElementById(tarHTMLElemIdMap[k]))){
                        if(! $A.util.isEmpty(document.getElementById(tarHTMLElemIdMap[k]).innerHTML)){
                            document.getElementById(tarHTMLElemIdMap[k]).innerHTML = (parseInt(document.getElementById(tarHTMLElemIdMap[k]).innerHTML) - parseInt(finalMap[k])).toString();   
                        }
                    }   
                }
            }
        }
        
        */
        /* var lastDateToPlan = component.get("v.endDayForPlanning");
        console.log("In Trget&PlaningComp-->H-->IN updateExistingMppValueOnHtmlElement_M-->Last Date2Plan-->"+lastDateToPlan);
        var lastDatePassed = this.checkLastDayForPlanningIsNotElapsed(lastDateToPlan);
        if(lastDatePassed){
        	this.lockAllInputTextBox(component,event);    
        }*/
        
        var lockThisTab = component.get("v.lockOrUnlockThisTab");
        //console.log("In Trget&PlaningComp-->H-->IN updateExistingMppValueOnHtmlElement_M-->Lock This Tab-->"+lockThisTab);
        if(!$A.util.isEmpty(lockThisTab)){
            var lastDateToPlan = component.get("v.endDayForPlanning");
            //  console.log("In Trget&PlaningComp-->H-->IN updateExistingMppValueOnHtmlElement_M-->Last Date2Plan-->"+lastDateToPlan);
            var lastDatePassed = this.checkLastDayForPlanningIsNotElapsed(lastDateToPlan);
            //   console.log("In Trget&PlaningComp-->H-->IN updateExistingMppValueOnHtmlElement_M-->Date Elapsed?-->"+lastDatePassed);
            var monMap = component.get("v.monthMap");
            var d = new Date();
            var currMonth = monMap[d.getMonth()];
            //console.log("In Trget&PlaningComp-->H-->IN updateExistingMppValueOnHtmlElement_M-->CurrMonth-->"+currMonth);
            var passedCurrMonth = component.get("v.targetMonth");
            //console.log("In Trget&PlaningComp-->H-->IN updateExistingMppValueOnHtmlElement_M-->passedCurrMonth-->"+passedCurrMonth);
            if(lockThisTab){
                this.lockAllInputTextBox(component,event);    
            }else if(lockThisTab == false && lastDatePassed == true && currMonth == passedCurrMonth){
                this.lockAllInputTextBox(component,event);
            }
        }else{
            this.lockAllInputTextBox(component,event);       
        }
        
        
        // this.lockSavedMonthlyPlanValue(component,event);
        
        // component.set("v.renderingDone",false);
        
        
    },
    getGroupedArrayByProperty :  function (objectArray, property) {
        return objectArray.reduce(function (acc, obj) {
            var key = obj[property];
            
            if (!acc[key]) {
                acc[key] = [];
            }
            acc[key].push(obj.Planned_Quantity__c);
            
            return acc;
        }, {});
    } ,
    
    getGroupedArrayByProperty2 :  function (objectArray, property) {
        console.log('In grpArrayProp2 !!!');
        return objectArray.reduce(function (acc, obj) {
            var key = obj[property];
            
            if (!acc[key]) {
                acc[key] = [];
            }
            acc[key].push(obj.colId);
            
            return acc;
        }, {});
    } ,
    updateTargetValueOfProduct : function(component,event,prodDomId,qty2Deduct){
        // var tVal = document.getElementById(prodDomId);
        // var totalTargetValOfProd = tVal.getAttribute('data-totalprodtarget');
        // console.log('Total Target VAl Of Prod From Apex-->'+totalTargetValOfProd);
        var totalTargetValOfProd = event.currentTarget.dataset.prodtarget;
        console.log("ZZ In Target&Planning-->H-->Total Prod Target Defined-->" + JSON.stringify(totalTargetValOfProd));
        //console.log("ZZ In Target&Planning-->H-->Col ID-->" + JSON.stringify(prodDomId));
        console.log('Qty 2 Deduct-->'+qty2Deduct);
        if(!$A.util.isEmpty(totalTargetValOfProd)){
            if(parseInt(totalTargetValOfProd) == parseInt(qty2Deduct)){
                document.getElementById(prodDomId).innerHTML = 0;
            }else{
                document.getElementById(prodDomId).innerHTML = 'Remaining: '+(parseInt(totalTargetValOfProd) - parseInt(qty2Deduct)).toString();        
            }
            
            /* Commented on 05042019 as per client suggested modifications
             * var comp = (parseInt(totalTargetValOfProd) > parseInt(qty2Deduct));
            if(comp){
                //console.log('2...');
                //console.log('Before  HTML Value -->'+document.getElementById(prodDomId).innerHTML);
                document.getElementById(prodDomId).innerHTML = (parseInt(totalTargetValOfProd) - parseInt(qty2Deduct)).toString();        
                //console.log('After New HTML Value Set-->'+document.getElementById(prodDomId).innerHTML);
            }else if(parseInt(totalTargetValOfProd) == parseInt(qty2Deduct)){
                document.getElementById(prodDomId).innerHTML = 0;
            }else{
                event.target.value = 0;
                this.showToast({
                    "title": "Oops!!",
                    "type": "error",
                    "message": "You cannot have more value than the target."
                });
            }*/
            
        }
        
    },
    updateProductTargetValue : function(component,event){
        var colIdMap = component.get("v.allRowIdAgainstProd");
        console.log('colIdMAp-->'+JSON.stringify(colIdMap));
        for (var k of Object.keys(colIdMap)) {
            console.log('Key-->'+k+'--Value-->'+colIdMap[k])  ;
            //console.log(document.getElementById(colIdMap[k][i]).value);
            
        }
        
    }
})
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
    onReload : function(component, event) {
        console.log("In Trget&PlaningCompInt-->H-->onReload_M !!");
        var resetVal = [];
        component.set("v.mpps",resetVal);
        $A.get('e.force:refreshView').fire();
        
    },
    handleDestroy : function(component,event,auraIdToDestroy){
        //console.log("In Trget&PlaningCompINT-->H-->handleDestroy_M !!!");
        if(!$A.util.isUndefinedOrNull(component.find(auraIdToDestroy)) || !$A.util.isEmpty(component.find(auraIdToDestroy))){
            //if( component.find(auraIdToDestroy) !=null || component.find(auraIdToDestroy)!='undefined'){
            //console.log("In Trget&PlaningCompINT-->H-->handleDestroy_M --> Inside Destroy!!");   
            component.find(auraIdToDestroy).destroy();
            // console.log("In Trget&PlaningCompINT-->H-->handleDestroy_M -->-->Comp Destroyed!!");   
        }else{
            console.log("In Trget&PlaningCompINT-->H-->handleDestroy_M -->-->Component is already Destroyed.");
        } 
        
    },
    
    lockSavedMonthlyPlanValue : function(component, event) {
        ///console.log("In Trget&PlaningCompInt-->H-->lockSavedMonthlyPlanValue_M ! -->for COMP-->"+component.get("v.targetMonth"));
        var elemntMap = component.get("v.existingMppEachCellQtyMap");
        for (var key of Object.keys(elemntMap)) {
            if(! $A.util.isEmpty(document.getElementById(key))){
                document.getElementById(key).disabled = true;
            }
        }
    },
    unlockSavedMonthlyPlanValue : function(component, event) {
        //console.log("In Trget&PlaningCompInt-->H-->unlockSavedMonthlyPlanValue_M !!");
        var elemntMap = component.get("v.existingMppEachCellQtyMap");
        for (var key of Object.keys(elemntMap)) {
            if(! $A.util.isEmpty(document.getElementById(key))){
                document.getElementById(key).disabled = false;
            }
        }
    },
    lockAllInputTextBox: function(component,event){
        //console.log("In Trget&PlaningCompINT-->H-->IN lockAllInputTextBox_M !!!");
        var allIdsArray = component.get("v.allRowCellIds"); // Contains all HTML Ids of Input Textbox rendered on page.
        
        //var t1 = performance.now();
        
        for(let a = 0; a < allIdsArray.length; a++){
            document.getElementById(allIdsArray[a]).disabled = true;   
        }	    
    },
    
    checkLastDayForPlanningIsNotElapsed : function(lastDay){
        var d = new Date();
        var currDate = d.getDate();
        //console.log("In Trget&PlaningCompINT-->H-->checkLastDayForPlanningIsNotElapsed_M-->currDate-->"+currDate);
        //console.log("In Trget&PlaningCompINT-->H-->checkLastDayForPlanningIsNotElapsed_M-->LastDate-->"+lastDay);
        var test = (currDate <= lastDay);
        //console.log("In Trget&PlaningCompINT-->H-->checkLastDayForPlanningIsNotElapsed_M-->currDate <= lastDay-->"+test);
        if(currDate <= lastDay){
            return false;
        }else{
            return true;
        }  
    },
    updateExistingMppValueOnHtmlElement  : function(component, event) {
        var t0 = performance.now();
        console.log("In Trget&PlaningCompINT-->H-->FROM Rendering Evt-->IN updateExistingMppValueOnHtmlElement_M-->!!! for COMP-->"+component.get("v.targetMonth"));
        var elemntMap = component.get("v.existingMppEachCellQtyMap");
        
        var aopLists = component.get("v.aopList");
        
        // console.log("In Trget&PlaningCompINT-->H-->IN updateExistingMppValueOnHtmlElement_M-->Target Map-->"+JSON.stringify(aopLists));
        var allInputHtmlIdMaps = component.get("v.inputHtmlIdVstargetHtmlId");
        
        var finalActiveInputTxtBx = component.get("v.activeInputTextBoxMap");
        
        //console.log("In Trget&PlaningCompINT-->H-->IN updateExistingMppValueOnHtmlElement_M-->all ID Map-->"+JSON.stringify(allInputHtmlIdMaps));
        
        /*for (var key of Object.keys(elemntMap)) {
            // aopMap[key.split(' ').join('')] = idValMap[key];
            //var targetId = key.split(' ').join('').substring(0,36).concat(component.get("v.targetMonth"));
            //var targetValue = aopLists[targetId];
            //console.log('targetId-->'+targetId+' Value-->'+targetValue);
            if(! $A.util.isEmpty(document.getElementById(key))){
                document.getElementById(key).value = new Number((elemntMap[key]));
            }
        }
        */
        
        
        
        // Now Disabling All Input TextBox 
        // And only Enabling the one's who has MPP Planned Qty (fetched from Apex)
        
        
        var allIdsArray = component.get("v.allRowCellIds"); // Contains all HTML Ids of Input Textbox rendered on page.
        
        //var t1 = performance.now();
        
        for(let a = 0; a < allIdsArray.length; a++){
            if(!$A.util.isEmpty(elemntMap)){
                for (var key of Object.keys(elemntMap)) {
                    
                    if(key == allIdsArray[a]){
                        if(! $A.util.isEmpty(document.getElementById(key))){
                            document.getElementById(key).value = new Number((elemntMap[key]));
                            finalActiveInputTxtBx[key] = '';
                        }   
                    }else{
                        if(!$A.util.isEmpty(document.getElementById(allIdsArray[a]))){
                            document.getElementById(allIdsArray[a]).disabled = true; 
                        }
                    }
                    
                }    
            }else{
                if(!$A.util.isEmpty(document.getElementById(allIdsArray[a]))){
                    document.getElementById(allIdsArray[a]).disabled = true; 
                }
            }
            
            
        }
        //var t2 = performance.now();
        
        //console.log("1st For  LOOP-->TIME--> " + ((t2 - t1) / 1000) + " seconds.");
        
        
        
        
        // Now Setting Target Value to "<P>" Html element 
        // And Enabling its parent Input Textbox.
        
        //var t3 = performance.now();
        for(let m = 0 ; m < aopLists.length; m++){
            // console.log('ID-->'+aopLists[m].Id);
            if(!$A.util.isEmpty(document.getElementById(aopLists[m].Id))){
                //console.log('HTML PRESENT');
                if($A.util.isEmpty(document.getElementById(aopLists[m].Id).innerHTML)){
                    //console.log('INNERHTML EMPTY');
                    document.getElementById(aopLists[m].Id).innerHTML = aopLists[m].Qty;  
                    var pTag = document.getElementById(aopLists[m].Id);
                    var inputTabId = pTag.getAttribute('data-inputtaghtmlid');
                    document.getElementById(inputTabId).disabled = false;
                    finalActiveInputTxtBx[inputTabId] = '';
                }
            }    
        }
        
        //var t4 = performance.now();
        
        //console.log("2nd For LOOP-->TIME--> " + ((t4 - t3) / 1000) + " seconds.");
        
        
        //console.log("TOTAL-->TIME--> " + ((t4 - t0) / 1000) + " seconds.");
        
        
        
        /*var t1 = performance.now();
        
        allIdsArray.forEach(function(element) {
  			//console.log(element);
  			if(!$A.util.isEmpty(elemntMap)){
                for (var key of Object.keys(elemntMap)) {
                    
                    if(key == element){
                        if(! $A.util.isEmpty(document.getElementById(key))){
                            document.getElementById(key).value = new Number((elemntMap[key]));
                        }   
                    }else{
                        //console.log('ELSE ELSE ELSE....');
                        if(!$A.util.isEmpty(document.getElementById(element))){
                            document.getElementById(element).disabled = true; 
                        }
                    }
                    
                }    
            }else{
                if(!$A.util.isEmpty(document.getElementById(element))){
                    document.getElementById(element).disabled = true; 
                }
            }
		});
		var t2 = performance.now();
        
        console.log("1st For EACH LOOP-->TIME--> " + ((t2 - t1) / 1000) + " seconds.");
        */
        //Setting AOP Annual Targets When Comp is Loaded
        //var aopLists = component.get("v.aopList"); // Stores List of All AOP Annual Target Qty Returned FROM APEX in the form {'Id':'[prodId+AccId]','Qty':''}
        
        // console.log("In Trget&PlaningCompINT-->H-->IN updateExistingMppValueOnHtmlElement_M-->Target Map-->"+JSON.stringify(aopLists));
        // 
        /* var t3 = performance.now();
        aopLists.forEach(function(element){
                if(!$A.util.isEmpty(document.getElementById(element.Id))){
                //console.log('HTML PRESENT');
                if($A.util.isEmpty(document.getElementById(element.Id).innerHTML)){
                    //console.log('INNERHTML EMPTY');
                    document.getElementById(element.Id).innerHTML = element.Qty;  
                    var pTag = document.getElementById(element.Id);
                    var inputTabId = pTag.getAttribute('data-inputtaghtmlid');
                    document.getElementById(inputTabId).disabled = false;
                }
            } 
            
        });
        var t4 = performance.now();
        console.log("2nd For EACH LOOP-->TIME--> " + ((t4 - t3) / 1000) + " seconds.");
        */
        
        
        //Locking Unlocking Existing Saved MPP Value
        /* var toggleIconValNew = component.get("v.toggleIcon");
        if(toggleIconValNew){
            
            this.lockSavedMonthlyPlanValue(component,event);
        }else{
            
            this.unlockSavedMonthlyPlanValue(component,event);
        }*/
        
        var lockThisTab = component.get("v.lockOrUnlockThisTab");
        //console.log("In Trget&PlaningCompINT-->H-->IN updateExistingMppValueOnHtmlElement_M-->Lock This Tab-->"+lockThisTab);
        if(!$A.util.isEmpty(lockThisTab)){
            var lastDateToPlan = component.get("v.endDay");
            //console.log("In Trget&PlaningCompINT-->H-->IN updateExistingMppValueOnHtmlElement_M-->Last Date2Plan-->"+lastDateToPlan);
            var lastDatePassed = this.checkLastDayForPlanningIsNotElapsed(lastDateToPlan);
            //console.log("In Trget&PlaningCompINT-->H-->IN updateExistingMppValueOnHtmlElement_M-->Date Elapsed?-->"+lastDatePassed);
            if(lockThisTab){
                this.lockAllInputTextBox(component,event);    
            }else if(lockThisTab == false && lastDatePassed == true){
                this.lockAllInputTextBox(component,event);
            }
        }else{
            this.lockAllInputTextBox(component,event);       
        }
        
        
        
        
        // component.set("v.renderingDone",false);
        // 
        // 
        
        
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
        //console.log('In grpArrayProp2 !!!');
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
        var tVal = document.getElementById(prodDomId);
        var totalTargetValOfProd = tVal.getAttribute('data-totalprodtarget');
        //console.log('In Target&PlaningInt-->H-->updateTargetValueOfProduct_M-->Total Target VAl Of Prod From Apex-->'+totalTargetValOfProd);
        // console.log('In Target&PlaningInt-->H-->updateTargetValueOfProduct_M-->Qty 2 Deduct-->'+qty2Deduct);
        if(!$A.util.isEmpty(totalTargetValOfProd)){
            var comp = (parseInt(totalTargetValOfProd) > parseInt(qty2Deduct));
            if(comp){
                document.getElementById(prodDomId).innerHTML = (parseInt(totalTargetValOfProd) - parseInt(qty2Deduct)).toString();        
            }else if(parseInt(totalTargetValOfProd) == parseInt(qty2Deduct)){
                document.getElementById(prodDomId).innerHTML = 0;
            }else{
                event.target.value = 0;
                this.showToast({
                    "title": "Oops!!",
                    "type": "error",
                    "message": "You cannot have more value than the target."
                });
            }
            
        }
        
    },
    updateTargetValueOfProduct2 : function(component,event,targetQtyDomId,qty2Deduct){
        //var tVal = document.getElementById(prodDomId);
        //
        //var actualAopQtyMaps = component.get("v.actualAopQtyMap");
        //var actualAopQty = actualAopQtyMaps[targetQtyDomId];
        var aopMapS = component.get("v.aopMapMod");
        var totalTargetValOfProd = aopMapS[targetQtyDomId]; //tVal.getAttribute('data-totalprodtarget');
        
        console.log('In Target&PlaningInt-->H-->updateTargetValueOfProduct2_M-->Actual AOP Qty-->'+totalTargetValOfProd);
        console.log('In Target&PlaningInt-->H-->updateTargetValueOfProduct2_M-->Total Target VAl(AopQtyRollup Qty)-->'+totalTargetValOfProd);
        console.log('In Target&PlaningInt-->H-->updateTargetValueOfProduct2_M-->Qty 2 Deduct-->'+qty2Deduct);
        if(!$A.util.isEmpty(totalTargetValOfProd)){
            //var comp = (parseInt(totalTargetValOfProd) > parseInt(qty2Deduct));
            //if(comp){
            if(Math.sign(totalTargetValOfProd) == 1 || Math.sign(totalTargetValOfProd) == 0 ){
                console.log('In +ve');
             	document.getElementById(targetQtyDomId).innerHTML = (parseInt(totalTargetValOfProd) - parseInt(qty2Deduct)).toString();               
            }else if(Math.sign(totalTargetValOfProd) == -1 ){
                console.log('In -ve');
                //var posNum = Math.abs(totalTargetValOfProd); // coverting -ve to +ve
                	
                //console.log('In -ve-->converted Number-->'+posNum);
             	document.getElementById(targetQtyDomId).innerHTML = ( parseInt(totalTargetValOfProd) - parseInt(qty2Deduct) ).toString();    
               
               
            }
                
                /* if(actualAopQty == totalTargetValOfProd){
                	document.getElementById(targetQtyDomId).innerHTML = (parseInt(totalTargetValOfProd) - parseInt(qty2Deduct)).toString();            
                }else{
                    document.getElementById(targetQtyDomId).innerHTML = (parseInt(actualAopQty) - parseInt(totalTargetValOfProd) - parseInt(qty2Deduct));            
                }*/
                
            /*}else if(parseInt(totalTargetValOfProd) == parseInt(qty2Deduct)){
                document.getElementById(targetQtyDomId).innerHTML = 0;
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
    onInit: function(component, event) {
        //console.log("In Trget&PlaningCompINT-->H-->IN onInit_M-->"+component.get("v.targetMonth")+" Comp!!!");
        //helper.onReset(component, event);
        this.showSpinner(component, event);
        
        var passedMonth = component.get("v.targetMonth");
        var monthsMap = component.get("v.monthMap");
        for (var index of Object.keys(monthsMap)) {
            if(monthsMap[index] == passedMonth)  {
                if( index == 0){
                    //var prvIf  = parseInt(index) - parseInt(1);
                    var currIf = parseInt(index);
                    var nxtIf  = parseInt(index) + parseInt(1);
                    component.set("v.nextMonth",monthsMap[nxtIf]);
                    component.set("v.prevMonth",monthsMap[11]);
                    //console.log("In Trget&PlaningCompINT-->C-->doInit_M-->IF-->Next Month-->" + component.get("v.nextMonth"));
                    //console.log("In Trget&PlaningCompINT-->C-->doInit_M-->IF-->N previous monthMAp INdex-->" + prvIf);  //parseInt(index) - parseInt(1));
                    //console.log("In Trget&PlaningCompINT-->C-->doInit_M-->IF-->N CURRENT monthMAp INdex-->" +currIf);     //+parseInt(index));
                    //console.log("In Trget&PlaningCompINT-->C-->doInit_M-->IF-->N next monthMAp INdex-->" +nxtIf)        //+parseInt(index) + parseInt(1)); 
                }else if(index == 11){
                    var prvEl = parseInt(index) - parseInt(1);
                    var currEl = parseInt(index);
                    var nxtEl = parseInt(index) * parseInt(0);
                    component.set("v.nextMonth",monthsMap[nxtEl]);
                    component.set("v.prevMonth",monthsMap[prvEl]);
                    //console.log("In Trget&PlaningCompINT-->C-->doInit_M-->ELSE IF-->Next Month-->" + component.get("v.nextMonth"));
                    //console.log("In Trget&PlaningCompINT-->C-->doInit_M-->ELSE-->N previous monthMAp INdex-->" + prvEl);  //parseInt(index) - parseInt(1));
                    //console.log("In Trget&PlaningCompINT-->C-->doInit_M-->ELSE-->N CURRENT monthMAp INdex-->" +currEl);     //+parseInt(index));
                    //console.log("In Trget&PlaningCompINT-->C-->doInit_M-->ELSE-->N next monthMAp INdex-->" +nxtEl)        //+parseInt(index) + parseInt(1)); 
                }else{
                    var prv = parseInt(index) - parseInt(1);
                    var curr = parseInt(index);
                    var nxt = parseInt(index) + parseInt(1);
                    component.set("v.nextMonth",monthsMap[nxt]);
                    component.set("v.prevMonth",monthsMap[prv]);
                    //console.log("In Trget&PlaningCompINT-->C-->doInit_M-->ELSE-->Next Month-->" + component.get("v.nextMonth"));
                    //console.log("In Trget&PlaningCompINT-->C-->doInit_M-->ELSE-->N previous monthMAp INdex-->" + prv);  //parseInt(index) - parseInt(1));
                    //console.log("In Trget&PlaningCompINT-->C-->doInit_M-->ELSE-->N CURRENT monthMAp INdex-->" +curr);     //+parseInt(index));
                    //console.log("In Trget&PlaningCompINT-->C-->doInit_M-->ELSE-->N next monthMAp INdex-->" +nxt)        //+parseInt(index) + parseInt(1)); 
                }
                
            }
        }
        
        if($A.util.isEmpty(component.get("v.targetYear"))){
            var d = new Date();
            var currYear = d.getFullYear();
            component.set("v.targetYear",currYear);    
        }
        
        this.getProductAndAnnualAop(component,event);
        
        this.getAccountAndMonthlyPlan(component,event);
        
    },
    
    getProductAndAnnualAop : function(component,event){
        console.log("In Trget&PlaningCompINT-->H-->getProductAndAnnualAop_M ! for COMP-->"+component.get("v.targetMonth"));
        //Getting  Columns 
        var action = component.get("c.getTargetAmountByUserDivision");
        action.setParams({
            // month: component.get("v.targetMonth"),
            year: component.get("v.targetYear"),
            demographic: 'International'
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                this.hideSpinner(component, event);
                var retData = response.getReturnValue();
                
                //console.log("In Trget&PlaningCompINT-->H-->getProductAndAnnualAop_M-->APEX RESP--> PRODUCTS-->" +JSON.stringify(retData));
                
                if (!$A.util.isEmpty(retData)) {
                    component.set("v.target", retData);
                    for(let i = 0; i < retData.length; i++){
                        //let aops = [];
                        var aopLists = component.get("v.aopList");
                        var aopMaps = component.get("v.aopMap");
                        var aopIdByAccId = component.get("v.aopIdByAccIdMap");
                        var currMonth = component.get("v.targetMonth");
                        var targetHtmlVsInputId = component.get("v.targetHtmlIdVsInputHtmlId");
                        //var actualAopQtyMap = component.get("v.actualAopMap");
                        
                        if(retData[i].Monthly_AOP__r){
                            let mopArray = retData[i].Monthly_AOP__r;
                            for(let j = 0; j < mopArray.length; j++){
                                
                                aopIdByAccId[mopArray[j].Account__c+mopArray[j].Product__c] = mopArray[j].Id; // This map is used to add monthly_target_Id to Monthly_Target__c property of newObj in onInputChange Method.
                                
                                if($A.util.isEmpty(mopArray[j].Remaining_Qty__c)){
                                    // Remaining_Qty__c is not there
                                    aopLists.push({"Id":mopArray[j].Product__c+mopArray[j].Account__c+currMonth,"Qty":mopArray[j].Target_Quantity__c});     
                                    aopMaps[mopArray[j].Product__c+mopArray[j].Account__c+currMonth] = mopArray[j].Target_Quantity__c;    //Setting Target HTML ID MAP
                                }else{
                                    aopLists.push({"Id":mopArray[j].Product__c+mopArray[j].Account__c+currMonth,"Qty": mopArray[j].Target_Quantity__c - mopArray[j].Remaining_Qty__c});     
                                    aopMaps[mopArray[j].Product__c+mopArray[j].Account__c+currMonth] = mopArray[j].Target_Quantity__c - mopArray[j].Remaining_Qty__c;  
                                    //actualAopQtyMap[mopArray[j].Product__c+mopArray[j].Account__c+currMonth] = mopArray[j].Target_Quantity__c; 
                                    
                                }
                                //aops.push(mopArray[j]);
                                //Below is now populating annual target value during INIT. further below Map can be used for the same.
                                
                            }   
                        }
                    }
                    //console.log("In Trget&PlaningCompINT-->C-->doInit_M-->PROD+ACC LIST VALs-->"+JSON.stringify(aopLists));
                    //console.log("In Trget&PlaningCompINT-->C-->doInit_M-->PROD+ACC MAP VALs-->"+JSON.stringify(aopMaps));
                    component.set("v.aopMapMod",aopMaps); // This Map can be used for modifying values.
                }else{
                    component.set("v.showError",true);
                    component.set("v.errorMessage","No Product found.");
                    this.showToast({
                        "title": "Error!!",
                        "type": "error",
                        "message": "No Product found. "
                    });
                }
            }else{
                console.log("In Trget&PlaningCompINT-->H-->getProductAndAnnualAop_M-->APEX Error!!");
            }
        });
        
        $A.enqueueAction(action);        
    },
    
    getAccountAndMonthlyPlan : function(component,event){
        //console.log("In Trget&PlaningCompINT-->H-->getAccountAndMonthlyPlan_M ! for COMP-->"+component.get("v.targetMonth"));
        //Getting Account rows
        var action2 = component.get("c.getAccounts");
        action2.setParams({
            month: component.get("v.targetMonth"),
            year: component.get("v.targetYear"),
            demographic: 'International'
        });
        action2.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                this.hideSpinner(component, event);
                var retData = response.getReturnValue();
                
                // console.log("In Trget&PlaningComp-->C-->doInit_M--> ret Acc-->" +JSON.stringify(retData) );
                
                if (!$A.util.isEmpty(retData)) {
                    component.set("v.account", retData);
                    for(let i = 0; i < retData.length; i++){
                        if($A.util.isEmpty(retData[i].Account__r)){
                            component.set("v.showError",true);
                            component.set("v.errorMessage","No active account found.");
                            this.showToast({
                                "title": "Error!!",
                                "type": "error",
                                "message": "No Active account found. "
                            });    
                        }
                        
                    }
                }else{
                    component.set("v.showError",true);
                    component.set("v.errorMessage","No Monthly Plan Found.");
                    this.showToast({
                        "title": "Error!!",
                        "type": "error",
                        "message": "No monthly plan found. "
                    });
                }
                
                let mpps = [];
                var mppMap = component.get("v.existingMppEachCellQtyMap");
                //var testMap = component.get("v.testMap2");
                var exstMppQtyMap = component.get("v.existingMppPlndQtyMap"); //will be used to update target value during initial comp Load. (Target - existingQty)
                var targetQty = [];
                var activeMonth = component.get("v.targetMonth");
                //  var mppMap = new Map();
                
                for(let i = 0; i < retData.length; i++){
                    if(retData[i].Monthly_Product_Plans__r){
                        let mppArray = retData[i].Monthly_Product_Plans__r;
                        for(let j = 0; j < mppArray.length; j++){
                            mpps.push(mppArray[j]);
                            mpps.push(mppArray[j].AccountId = retData[i].Account__c); // Adding extra property "AccountId" to mpp
                            exstMppQtyMap[mppArray[j].Product__c+mppArray[j].AccountId+mppArray[j].Month__c] = mppArray[j].Planned_Quantity__c; // Used For International as target is displayed below input
                            mppMap[mppArray[j].Product__c+' '+mppArray[j].AccountId+' '+retData[i].Id] = mppArray[j].Planned_Quantity__c; // Will set existing mpp's value in Input Textbox
                            
                            targetQty.push({
                                Id : mppArray[j].Product__c,
                                Planned_Quantity__c : ( (!$A.util.isEmpty(mppArray[j].Planned_Quantity__c)) ? mppArray[j].Planned_Quantity__c : 0 )
                            });
                            // testMap[mppArray[j].Product__c] =( (!$A.util.isEmpty(mppArray[j].Planned_Quantity__c)) ? mppArray[j].Planned_Quantity__c : 0);
                            
                        }   
                    }
                }
                
                //console.log("In Trget&PlaningCompINT-->C-->doInit_M-->EXISTING MPP MAp VALs-->"+JSON.stringify(mppMap));
                //console.log("In Trget&PlaningCompINT-->C-->doInit_M-->EXISTING MPP MAp VALs-->"+JSON.stringify(exstMppQtyMap));
                component.set("v.existingMppEachCellQtyMap",mppMap);
                component.set("v.existingMppPlndQtyMap",exstMppQtyMap);
                component.set("v.totalTarget",targetQty);
                
                
                // Creating Array OF HTML IDs of ALL INput TextBox
                
                var acc = component.get("v.account");
                var prod = component.get("v.target");
                //console.log('ACC-->'+JSON.stringify(acc));		    
                //console.log('PROD-->'+JSON.stringify(prod));		    
                var productColIdArray = [];
                
                var allRowCellIdArray = [];
                
                if(!$A.util.isEmpty(acc) && !$A.util.isEmpty(prod)){
                    for(let i = 0; i < acc.length;  i++){
                        for(let j = 0; j < prod.length; j++){
                            allRowCellIdArray.push(prod[j].Id+' '+acc[i].Account__c+' '+acc[i].Id);
                        }
                    }
                    component.set("v.allRowCellIds",allRowCellIdArray); 
                    
                }
            }
        });
        
        $A.enqueueAction(action2);   
    },
    
})
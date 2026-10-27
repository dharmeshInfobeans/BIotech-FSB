({
    onAnchorClick : function(component, event, helper) {
        //console.log("In Target&PlaningInt-->C-->In anchor click!!!!-->For Month-->"+component.get("v.targetMonth"));
        
        //console.log('HTML ID-->'+event.target.id);
        var accountId = event.currentTarget.dataset.accid;
        //console.log("In Target&PlaningInt-->C-->In anchor click!!!!-->AccountId-->"+accountId);
		//Opening Record In New Tab	
        window.open('/' + accountId,'_blank');
        
        //Commented this coz need to open url in new window
        /*var navLink = component.find("navService");
        var pageRef = {
            type: 'standard__recordPage',
            attributes: {
                actionName: 'view',
                objectApiName: 'Account',
                recordId : accountId 
            },
        };
        navLink.navigate(pageRef, true);*/
    },
    onProductNameClick : function(component, event, helper) {
         console.log('ZZZZZZZZZZZZZ HTML ID-->'+event.target.id);
        var productId = event.currentTarget.dataset.prodid;
        //console.log("In Target&PlaningInt-->C-->In anchor click!!!!-->AccountId-->"+accountId);
        		
        //Opening Record In New Tab	
        window.open('/' + productId,'_blank');
        
        //Commented this coz need to open url in new tab
        /*var navLink = component.find("navService");
        var pageRef = {
            type: 'standard__recordPage',
            attributes: {
                actionName: 'view',
                objectApiName: 'Product__c',
                recordId : productId 
            },
        };
        navLink.navigate(pageRef, false);*/
        
    },
    onAOPClick : function(component, event, helper) {
        
        

        var accAndProdId = event.currentTarget.dataset.accandprodid;

        var aopIdByAccProdIdMap = component.get("v.aopIdByAccIdMap");
        var monthlyAOPId = aopIdByAccProdIdMap[accAndProdId];
        console.log("In Target&PlaningInt-->C-->In onAOPClick_M-->N-->accId+AopId-->"+monthlyAOPId);
        //Opening Record In New Tab	
        window.open('/' + monthlyAOPId,'_blank');
        
        //Commented this coz need to open url in new tab
        /*var navLink = component.find("navService");
        var pageRef = {
            type: 'standard__recordPage',
            attributes: {
                actionName: 'view',
                objectApiName: 'Monthly_AOP__c',
                recordId : aopId 
            },
        };
        navLink.navigate(pageRef, true);*/    
    },
    onAOPMouseOverFireAppEvt : function(component, event, helper) {
        console.log("In Target&PlaningInt-->C-->In onAOPMouseOverFireAppEvt_M!!");
        var accAndProdId = event.currentTarget.dataset.accandprodid;
        var acctId = accAndProdId.substring(0, 18);
        var prodtId = accAndProdId.substring(18, 36);
        var fisYear = event.currentTarget.dataset.mpfisyear;
        var monplnId = event.currentTarget.dataset.mpid;
        var mnth = event.currentTarget.dataset.mpmonth;
        var aopIdByAccProdIdMap = component.get("v.aopIdByAccIdMap");
        var monthlyAOPId = aopIdByAccProdIdMap[accAndProdId];  
        console.log("In Target&PlaningInt-->C-->In onAOPMouseOverFireAppEvt_M-->monthlyAOPId-->"+monthlyAOPId);
        console.log("In Target&PlaningInt-->C-->In onAOPMouseOverFireAppEvt_M-->accId-->"+acctId);
        var appEvent = $A.get("e.c:AOPDetailAppEvt");
        appEvent.setParams({
            showDetails:true,
            accountId:acctId,
            aopId:monthlyAOPId,
            prodId:prodtId,
            mpId:monplnId,
            fiscalYear:fisYear,
            month:mnth
        });
        appEvent.fire();
    },
    onAOPMouseOutFireAppEvt : function(component, event, helper) {
        
        /* var appEvent = $A.get("e.c:AOPDetailAppEvt");
        appEvent.setParams({
            showDetails:false
        });
        appEvent.fire();*/
    },
    doInit: function(component, event, helper) {
        console.log("In Target&PlaningInt-->C-->In doInit_M!!-->For Month-->"+component.get("v.targetMonth"));
        /*component.set("v.firstTimeLoaded",true);
        var firstLoad = component.get("v.firstTimeLoaded");
        if(firstLoad){
            
        }else{
         	console.log("In Target&PlaningInt-->C-->doInit-->val of first Load-->"+firstLoad);   
        }
		*/ 
       // console.log("In Target&PlaningInt-->C-->In doInit_M!!-->For Month-->"+component.get("v.targetMonth")+"--> Val of EndDay-->"+component.get("v.endDay"));
        helper.onInit(component,event);
    },
    onToggleValueChangeHandler : function(component, event, helper){
        //console.log("In Target&PlaningInt-->c-->onToggleValueChangeHandler_M !!");
        var toggleIconValNew = component.get("v.toggleIcon");
        if(toggleIconValNew){
            //console.log('In Target&PlaningInt-->c-->onToggleValueChangeHandler_M-->In LOCKED ICON STAGE!!');
            helper.lockSavedMonthlyPlanValue(component,event);
        }else{
           // console.log('In Target&PlaningInt-->c-->onToggleValueChangeHandler_M-->In UNLOCKED ICON STAGE!!');
            helper.unlockSavedMonthlyPlanValue(component,event);
        }  
    },
    onInputChange : function(component, event, helper) {
        //console.log('In Target&PlaningInt-->C-->onInputChange_M-->!!!');
        
        component.set("v.renderingDone",false);
        
        var idVAL = event.target.id;
        //console.log('In Target&PlaningInt-->C-->onInputChange_M-->CURRENT CELL HTML ID-->'+idVAL);
        
        //var inputTag = document.getElementById(idVAL);
        // console.log('In INPUTCHANGE CURRENT CELL HTML ID-->INPUT TAg-->'+inputTag);
        // var childPTagVal = inputTag.getElementsByTagName('p').id;
        
        
        //var childPTagId = event.currentTarget.dataset.targetptaghtmlid;
        //console.log('In INPUTCHANGE CURRENT CELL HTML ID-->Child P TAg-->'+childPTagId);
        
        var index = event.currentTarget.dataset.index;  
        //console.log("In Target&PlaningInt-->C-->onInputChange_M-->INDEX No-->" + JSON.stringify(index));
        
        var val = event.target.value;
        //console.log('In Target&PlaningInt-->C-->onInputChange_M-->In INPUTCHANGE CURRENT CELL VALUE-->'+event.target.value);
        
        var prodName = event.currentTarget.dataset.prodname;
        //console.log("In Target&PlaningInt-->C-->onInputChange_M-->PROD NAME-->" + JSON.stringify(prodName));
        
        var prodId = event.currentTarget.dataset.prodid;
        //console.log("In Target&PlaningInt-->C-->onInputChange_M-->PROD ID-->" + JSON.stringify(prodId));
        
        var accId = event.currentTarget.dataset.accid;
       // console.log("In Target&PlaningInt-->C-->onInputChange_M-->Acc ID-->" + JSON.stringify(accId));
        
        var mpName = event.currentTarget.dataset.mpname;
        //console.log("In Target&PlaningInt-->C-->onInputChange_M-->MP NAME-->" + JSON.stringify(mpName));
        
        var mpID = event.currentTarget.dataset.mpid;
        //console.log("In Target&PlaningInt-->C-->onInputChange_M-->MP ID-->" + JSON.stringify(mpID));
        
        var currMonth = event.currentTarget.dataset.month;
        //console.log("In Target&PlaningInt-->C-->onInputChange_M-->Curr MONTH-->" + JSON.stringify(currMonth));
        
        var currYear = event.currentTarget.dataset.year;
        //console.log("In Target&PlaningInt-->C-->onInputChange_M-->Curr YEAR-->" + JSON.stringify(currYear));
        
        
        var ownerId = event.currentTarget.dataset.ownerid;
        //console.log("In Target&PlaningInt-->C-->onInputChange_M-->OWNER ID-->" + JSON.stringify(ownerId));
        //
        //var totalProdTarget = event.currentTarget.dataset.prodtarget;
        //console.log("In Target&PlaningInt-->C-->onInputChange_M-->Total Prod Target Defined-->" + JSON.stringify(totalProdTarget)); // NEEDS TO BE CHANGED
        
        //var monthlyAOPId = event.currentTarget.dataset.maopid;
        //console.log("In Target&PlaningInt-->C-->onInputChange_M-->MOnthly AOP ID-->" + JSON.stringify(monthlyAOPId));
        var finYearDate = event.currentTarget.dataset.finyeardate;
        console.log("In Trget&PlanningTurkeyComp-->C-->onInputChange_M-->Fin Year Date->" + JSON.stringify(finYearDate)); 
        
        var accSAPCode = event.currentTarget.dataset.accsapcode;
        console.log("In Trget&PlanningTurkeyComp-->C-->onInputChange_M-->acc SAPCODE->" + JSON.stringify(accSAPCode)); 
        
        var prodCode = event.currentTarget.dataset.prodcode;
        console.log("In Trget&PlanningTurkeyComp-->C-->onInputChange_M-->prod CODE->" + JSON.stringify(prodCode));  
        
        var aopIdByAccProdIdMap = component.get("v.aopIdByAccIdMap");
        var monthlyAOPId = aopIdByAccProdIdMap[accId+prodId];         //FOR INTERNATIONAL
        

		if(val < 0){
            event.target.value = 0; // set current cell value to 0.
            helper.showToast({
                "title": "Oops!!",
                "type": "error",
                "message": "You cannot enter negative value."
            }); 
        }
        
        
        if( !$A.util.isEmpty(prodId) && !$A.util.isEmpty(mpID) && !$A.util.isEmpty(currMonth) &&
           !$A.util.isEmpty(currYear) && !$A.util.isEmpty(ownerId) && (val >=0 )){
            //console.log('In Target&PlaningInt-->C-->onInputChange_M-->Inside VAL!!!');
            var mppArrayList = component.get("v.mpps");
            
            var pQTY = ( !$A.util.isEmpty(val) ? val : 0); // For QTY
            //console.log('In Target&PlaningInt-->C-->onInputChange_M-->Inside IF-->pQTY-->'+pQTY);
            
            var newObj = {
                Month__c: currMonth,
                Year__c: currYear,
                User__c: ownerId,
                Product__c:prodId,
                Planned_Quantity__c:pQTY,
                Monthly_Plan__c:mpID,
                Monthly_Target__c:monthlyAOPId,
                Financial_Year_Date__c:finYearDate,
                MPP_Mapping__c:currMonth+currYear+prodCode+accSAPCode,
                //AccountId:accId,
                Time: Date.now()
            }
            console.log('In Target&PlaningInt-->C-->onInputChange_M--> NEW OBJ-->'+JSON.stringify(newObj));
            //console.log('In INPUTCHANGE CURRENT CELL VALUE-->'+event.target.value);
            
            //mppArrayList.push(newObj);  
            
            if(!$A.util.isEmpty(newObj.Product__c) ){
                //var tVal = document.getElementById(newObj.Product__c);
                //var currTargetVal = tVal.getAttribute('data-totalprodtarget');
               // var aopMapS = component.get("v.aopMapMod");
                //var currTargetVal = aopMapS[newObj.Product__c+accId+newObj.Month__c];
                //console.log('In Target&PlaningInt-->C-->onInputChange_M-->-->Total TargetVal-->'+currTargetVal);
                //var currTargetVal = document.getElementById(newObj.Product__c).innerHTML; // get target value for product
              //  if(!$A.util.isEmpty(currTargetVal)){
                //    var comp = (parseInt(currTargetVal) >= parseInt(newObj.Planned_Quantity__c));
                  //  if(comp){
                        mppArrayList.push(newObj); 
                        
                        helper.updateTargetValueOfProduct2(component,event,newObj.Product__c+accId+newObj.Month__c,newObj.Planned_Quantity__c);
                        
                        /*let currColId = newObj.Product__c;
                        var getAllCellIdsAgainstAllProdId = component.get("v.allRowIdAgainstProd");
                        let columnIds = Object.keys(getAllCellIdsAgainstAllProdId); // All Column Ids
                        
                        console.log('Column Or Prod Ids-->'+columnIds);
                        console.log('CURR ColID--->'+JSON.stringify(currColId));
                        //console.log('ALL VALUES OF COL-->'+getAllCellIdsAgainstAllProdId[currColId]);
                        
                        let cellIdsInCurrCol = [];
                        cellIdsInCurrCol = getAllCellIdsAgainstAllProdId[currColId];
                        let totalSumOfCurrCol = 0;
                        console.log('total column length-->'+cellIdsInCurrCol.length);
                        for(let m = 0 ; m < cellIdsInCurrCol.length; m++){
                            
                            if(!$A.util.isEmpty(document.getElementById(cellIdsInCurrCol[m]))){
                                totalSumOfCurrCol += (!$A.util.isEmpty(document.getElementById(cellIdsInCurrCol[m]).value) ? parseInt(document.getElementById(cellIdsInCurrCol[m]).value) : 0);
                            }	 
                        }
                        
                        //(partial_sum, a) => partial_sum + a
                        console.log('Col Ids-->'+JSON.stringify(cellIdsInCurrCol));
                        console.log('N Total Sum-->'+JSON.stringify(totalSumOfCurrCol));
                        helper.updateTargetValueOfProduct(component,event,newObj.Product__c,totalSumOfCurrCol); */      
                    /*}else{
                        event.target.value = 0; // set current cell value to 0.
                        document.getElementById(newObj.Product__c+accId+newObj.Month__c).innerHTML = currTargetVal; //Reset Target Value
                        helper.showToast({
                            "title": "Oops!!",
                            "type": "error",
                            "message": "You cannot have more value than the set target quantity."
                        });
                    } 
                }else{
                    // For Now, we are pushing Product's that not target also... (Note: Every product will have target)
                    mppArrayList.push(newObj); 
                }*/
                //
            }else if(!$A.util.isEmpty(newObj.Product__c) && $A.util.isEmpty(newObj.Planned_Quantity__c) ){
                console.log("In Trget&PlaningCompInt-->C-->onInputChange_M--> WHen Planned_Quantity__c is null or undefined or blank ");
                mppArrayList.push(newObj); 
            }
            
            
            // Removing Duplicate From Array.
            for(let i = 0; i < mppArrayList.length; i++){
                
                for(let j = i+1; j < mppArrayList.length; j++){
                    
                    if(mppArrayList[j].Product__c == mppArrayList[i].Product__c && mppArrayList[j].Planned_Quantity__c == mppArrayList[i].Planned_Quantity__c &&
                       mppArrayList[j].Monthly_Plan__c == mppArrayList[i].Monthly_Plan__c ){
                        if(mppArrayList[j].Time > mppArrayList[i].Time){
                            //console.log('In Target&PlaningInt-->C-->onInputChange_M-->Inside Equal!!!!!!!! ');
                            var removedArray = mppArrayList.splice(i,1);
                            //console.log('In Target&PlaningInt-->C-->onInputChange_M-->I SPLICED Array -->'+JSON.stringify(removedArray));
                        }else{
                            //console.log('In Target&PlaningInt-->C-->onInputChange_M-->Inside Equal!!!!!!!! ');
                            var removedArray2 = mppArrayList.splice(j,1);
                            //console.log('In Target&PlaningInt-->C-->onInputChange_M-->J SPLICED Array -->'+JSON.stringify(removedArray2));
                        }
                        
                    }
                    
                    
                }
            }
            
            // Now adding the latest product quantity to the array and removing the old one
            
            for(let i = 0; i < mppArrayList.length; i++){
                
                for(let j = i+1; j < mppArrayList.length; j++){
                    
                    if(mppArrayList[j].Product__c == mppArrayList[i].Product__c && mppArrayList[j].Planned_Quantity__c != mppArrayList[i].Planned_Quantity__c &&
                       mppArrayList[j].Monthly_Plan__c == mppArrayList[i].Monthly_Plan__c ){
                        if(mppArrayList[j].Time > mppArrayList[i].Time){
                            //console.log('In Target&PlaningInt-->C-->onInputChange_M-->Inside Equal!!!!!!!! ');
                            var removedArray = mppArrayList.splice(i,1);
                            //console.log('In Target&PlaningInt-->C-->onInputChange_M-->!= I SPLICED Array -->'+JSON.stringify(removedArray));
                        }else{
                            //console.log('In Target&PlaningInt-->C-->onInputChange_M-->Inside Equal!!!!!!!! ');
                            var removedArray2 = mppArrayList.splice(j,1);
                            //console.log('In Target&PlaningInt-->C-->onInputChange_M--> != J SPLICED Array -->'+JSON.stringify(removedArray2));
                        }
                        
                    }
                    
                    
                }
            }
            console.log('In Target&PlaningInt-->C-->onInputChange_M-->ON INPUT FINAL-->'+JSON.stringify(mppArrayList));
            
            //console.log("BEFORE ASSIGNMENT-->"+ JSON.stringify(mppList));
            //let finalval = [... new Set(mppList)];
            //console.log("FINAL VAL-->"+ JSON.stringify(mppList));
            component.set("v.mpps",mppArrayList);
            
        }
        
        
    },
    
    checkObjectEquality : function(a,b){
        
        // Create arrays of property names
        var aProps = Object.getOwnPropertyNames(a);
        var bProps = Object.getOwnPropertyNames(b);
        
        // If number of properties is different,
        // objects are not equivalent
        if (aProps.length != bProps.length) {
            return false;
        }
        
        for (var i = 0; i < aProps.length; i++) {
            var propName = aProps[i];
            
            // If values of same property are not equal,
            // objects are not equivalent
            if (a[propName] !== b[propName]) {
                return false;
            }
        }
        
        // If we made it this far, objects
        // are considered equivalent
        return true;
        
    },
    
    onSave : function(component, event, helper) {
        helper.showSpinner(component, event);
        var mppArrayList = [];
        mppArrayList = component.get("v.mpps");
        //console.log("In Target&PlaningInt-->C-->onSave_M-->ON SAVE-->DATA 2Be Save-->"+JSON.stringify(mppArrayList));
        
        
        
        //Again Removing Duplicate From Array If Exist.
        
        for(let i = 0; i < mppArrayList.length; i++){
            
            for(let j = i+1; j < mppArrayList.length; j++){
                
                if(mppArrayList[j].Product__c == mppArrayList[i].Product__c && mppArrayList[j].Planned_Quantity__c == mppArrayList[i].Planned_Quantity__c &&
                   mppArrayList[j].Monthly_Plan__c == mppArrayList[i].Monthly_Plan__c ){
                    if(mppArrayList[j].Time > mppArrayList[i].Time){
                        //console.log('Inside Equal!!!!!!!! ');
                        var removedArray = mppArrayList.splice(i,1);
                        //console.log('In Target&PlaningInt-->C-->onSave_M-->I SPLICED Array -->'+JSON.stringify(removedArray));
                    }else{
                        //console.log('Inside Equal!!!!!!!! ');
                        var removedArray2 = mppArrayList.splice(j,1);
                        //console.log('In Target&PlaningInt-->C-->onSave_M-->J SPLICED Array -->'+JSON.stringify(removedArray2));
                    }
                    
                }
                
                
            }
        }
        
        // Again adding the latest product quantity to the array with same product and mp and also removing the old one
        
        for(let i = 0; i < mppArrayList.length; i++){
            
            for(let j = i+1; j < mppArrayList.length; j++){
                
                if(mppArrayList[j].Product__c == mppArrayList[i].Product__c && mppArrayList[j].Planned_Quantity__c != mppArrayList[i].Planned_Quantity__c &&
                   mppArrayList[j].Monthly_Plan__c == mppArrayList[i].Monthly_Plan__c ){
                    if(mppArrayList[j].Time > mppArrayList[i].Time){
                        // Removing Older MPP
                        var removedArray = mppArrayList.splice(i,1);
                        //console.log('In Target&PlaningInt-->C-->onSave_M-->!= I SPLICED Array -->'+JSON.stringify(removedArray));
                    }else{
                        //console.log('Inside Equal!!!!!!!! ');
                        var removedArray2 = mppArrayList.splice(j,1);
                       // console.log('In Target&PlaningInt-->C-->onSave_M-->!= J SPLICED Array -->'+JSON.stringify(removedArray2));
                    }
                    
                }
                
                
            }
        }
        console.log('In Target&PlaningInt-->C-->onSave_M-->FINAL VAL 2Be Saved-->'+JSON.stringify(mppArrayList));
        
        
        /*let newMppToLockMap = component.get("v.cloneMap"); 
        
        // console.log('CLONED ARRAY-->'+JSON.stringify(finalMppArrayList));
        
        
        
        // Removing "AccountId" property Of each Mpp Object before sending it to Apex.
        for(let i = 0; i < mppArrayList.length; i++){
            //For Locking New Mpp(Input TextBx) adding new values to Map.
            newMppToLockMap[mppArrayList[i].Product__c +' '+mppArrayList[i].AccountId+' '+mppArrayList[i].Monthly_Plan__c] = mppArrayList[i].Planned_Quantity__c;
            mppArrayList[i].AccountId = undefined;
            
        } */
        
        
        
        //var rstData = component.get("v.mpps");
        // console.log("ON SAVE-->After RST-->"+JSON.stringify(rstData));
        
        
        var action2 = component.get("c.saveMPPS");
        action2.setParams({
            mppList: mppArrayList,
            month: component.get("v.targetMonth"),
            year : component.get("v.targetYear"),
            demographic: 'International'
        });
        action2.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                helper.hideSpinner(component, event);
                //var retData = response.getReturnValue();
                
                helper.showToast({
                    "title": "Success!! Record Updated..",
                    "type": "success",
                    "message": mppArrayList.length +" Records Updated"
                });
                console.log("In Trget&PlaningCompInt-->C-->onSave_M--> Apex Resp Success!!!");
                //var resetVal = [];
                //component.set("v.mpps",resetVal);
                //$A.get('e.force:refreshView').fire();
                
                
                
                
               /* var savedInputMppValAndQtyMap = component.get("v.existingMppEachCellQtyMap"); // "testMap" holds existing Mpp value which is saved in database in the form -->(InputHtmlId vs MppValue)
                
                // If apex response is success then adding the new values(which was just saved above) to the 
                // existing Mpp value Map which holds the value which was retrieved from apex when comp is loaded.
                for (var kee of Object.keys(newMppToLockMap)){
                    savedInputMppValAndQtyMap[kee] = newMppToLockMap[kee];
                }      
                */
                
                //console.log("In Trget&PlaningCompInt-->C-->onSave_M--> NXT MONTH--> Before Firing Evt-->"+component.get("v.nextMonth"));
                var cmpEvent = component.getEvent("switchTabIntEvt");
                cmpEvent.setParams({
                    nextTab : component.get("v.nextMonth"),
                    currentTab : component.get("v.targetMonth")
                });
                //console.log('In Target&PlaningInt-->C-->onSave_M-->COMP EVENT DATA IN CHILD-->'+JSON.stringify(cmpEvent));
                cmpEvent.fire();
                
                
                
               /* window.setTimeout(
                    $A.getCallback(function() {
                        console.log('In Trget&PlaningCompInt-->C-->onSave_M--> In TimeOut Function!!');
                        component.set("v.toggleIcon",true);
                       // component.set("v.renderingDone",true);
                        //helper.lockSavedMonthlyPlanValue(component, event);
                        
                        //helper.getProductAndAnnualAop(component, event);
                       // helper.getAccountAndMonthlyPlan(component, event);
                }), 100);*/
                
                //component.set("v.toggleIcon",true);
                
                //component.set("v.renderingDone",true);
                //helper.onInit(component,event);    
                //helper.onReset(component,event);                
                //console.log("In Trget&PlaningComp-->C-->onSave_M--> Apex Success!!!-->COMP EVENT DATA IN CHILD-->"+JSON.stringify(cmpEvent));
                //  console.log("In Trget&PlaningComp-->C-->onSave_M--> Apex Success!!!-->After Save ExMpp's Input Value-->"+JSON.stringify(component.get("v.existingMppEachCellQtyMap")));
                //  console.log("In Trget&PlaningComp-->C-->onSave_M--> Apex Success!!!-->After Save ExMpp's PLanned Value-->"+JSON.stringify(component.get("v.existingMppPlndQtyMap")));
                
                
                // component.set("v.toggleIcon",true);
                
                
            }else{
                helper.hideSpinner(component, event);
                 helper.showToast({
                        "title": "Error!!",
                        "type": "error",
                        "message": "Error while saving record.. "
                    });
            }
        });
        
        $A.enqueueAction(action2);
    },
    
    onReloadHandler : function(component, event, helper) {
        helper.onReload(component,event);
        // var resetVal = [];
        // component.set("v.mpps",resetVal);
        // $A.get('e.force:refreshView').fire();
        
    },
    onResetHandler : function(component, event, helper) {
        console.log("In Trget&PlaningCompINT-->C-->In onResetHandler_M !!");
        var elemntMap = component.get("v.existingMppEachCellQtyMap");
        
        var finalActiveInputTxtBx = component.get("v.activeInputTextBoxMap");
        //console.log("In Trget&PlaningCompINT-->C-->In onResetHandler_M-->Active Input TxtBx Map-->"+JSON.stringify(finalActiveInputTxtBx));
        
        /*for (var key of Object.keys(elemntMap)) {
            if(! $A.util.isEmpty(document.getElementById(key))){
                document.getElementById(key).disabled = true;
            }
        }*/
        
        var allIdsArray = component.get("v.allRowCellIds"); // Contains all HTML Ids of Input Textbox rendered on page.
        //console.log("In Trget&PlaningCompINT-->C-->In onResetHandler_M-->All Id Array-->"+JSON.stringify(allIdsArray));
        
        var mppValueMap = component.get("v.existingMppEachCellQtyMap");
        
        for(let i = 0; i < allIdsArray.length; i++){
            for (var key of Object.keys(mppValueMap)) {
                if(key != allIdsArray[i]){
                    if((document.getElementById(allIdsArray[i]).disabled) == false ){
                        //if(!$A.util.isEmpty)
                    	document.getElementById(allIdsArray[i]).value = null;        
                    }
                }
            }    
        }


		//helper.updateExistingMppValueOnHtmlElement(component,event);
        //var t1 = performance.now();
        
        /* for(let a = 0; a < allIdsArray.length; a++){
            if(!$A.util.isEmpty(finalActiveInputTxtBx)){
                for (var key of Object.keys(finalActiveInputTxtBx)) {
                      console.log('id1-->'+key);
                      console.log('id2-->'+allIdsArray[a]);
                    if(key == allIdsArray[a]){
                         console.log('IDs are Equal!!!');
                         document.getElementById(key).value = 3; 
                        //if(! $A.util.isEmpty(document.getElementById(key))){
                        //    document.getElementById(key).value = new Number((elemntMap[key]));
                        //}   
                    }else if(key != allIdsArray[a]){
                        if(!$A.util.isEmpty(document.getElementById(allIdsArray[a]))){
                            if(document.getElementById(allIdsArray[a]).disabled){
                              // document.getElementById(allIdsArray[a]).value = 5;  
                            }else{
                              document.getElementById(allIdsArray[a]).value = 4;   
                            }
                           
                        }
                    }
                    
                }    
            }else{
                console.log('In Trget&PlaningCompINT-->C-->In onResetHandler_M-->Nothing to clear/Reset..........');
                //if(!$A.util.isEmpty(document.getElementById(allIdsArray[a]))){
                //    document.getElementById(allIdsArray[a]).value = null; 
                //}
            }
            
            
        }*/
        
        
    },
    
    onFill : function(component, event, helper) {
        
        // var prodVal =  document.getElementById('a040l000008qiVDAAY').innerHTML;
        //var prodVal = component.find("a040l000008qiVDAAYHSAS600");
        // console.log("PROD TRGT VAL 2-->"+JSON.stringify(prodVal));
        // console.log("TYPEOF PROD TRGT VAL 2-->"+typeof prodVal);
        
        //component.set("v.existingMppEachCellQtyMap",mppMap);
        //console.log("ALL ROW CELL IDs-->"+JSON.stringify(component.get("v.allRowIdAgainstProd")));
        //var allCellArray = component.get("v.allRowIdAgainstProd");      
        // console.log("In Trget&PlaningCompINT-->C-->onInputChange_M-->All RowCell Array Size-->"+allCellArray.length);
        
        //console.log("In Trget&PlaningCompINT-->C-->onFill_M-->All RowCell Array Size-->"+allCellArray.length);
        
        // console.log("In Trget&PlaningCompINT-->C-->onFill_M-->ALL ROW CELL IDs MAP-->"+JSON.stringify(component.get("v.existingMppEachCellQtyMap"))); //
        //  console.log("In Trget&PlaningCompINT-->C-->onFill_M-->Prod Id and TargetQty-->"+JSON.stringify(component.get("v.totalTarget"))); //
        
        
        
        
        
        
        
        // helper.updateProductTargetValue(component,event);
        
    },
    onRender : function(component, event, helper) {
        //console.log('In Trget&PlaningCompINT-->C-->onRender_M ! --> for COMP-->'+component.get("v.targetMonth"));
        var toDoRendering = component.get("v.renderingDone");
        if(toDoRendering){
            helper.updateExistingMppValueOnHtmlElement(component,event);
        }
    },
    onIconClick : function(component, event, helper) {
        //console.log("In Trget&PlaningCompINT-->C-->In ICON CLICK HANDLER!!");
        component.set("v.renderingDone",false); // this stops default aura framework's rendering event
        var toggleIconVal = component.get("v.toggleIcon");
        //console.log('In Trget&PlaningCompINT-->C-->onIconClick_M-->toggle val-->'+toggleIconVal);
        ((toggleIconVal) ? component.set("v.toggleIcon",false) : component.set("v.toggleIcon",true));
    },
    
    onMouseOverHandler : function(component, event, helper) {
        //console.log('In Trget&PlaningCompINT-->C-->In onMouseOverHandler_M!!!');
        var val = event.target.value;
        //console.log("In Trget&PlaningCompINT-->C-->onMouseOverHandler_M-->Planned VAL-->" + val);
        
        var pName = event.currentTarget.dataset.tprodname;
        //console.log("In Trget&PlaningCompINT-->C-->onMouseOverHandler_M-->PROD NAME-->" + JSON.stringify(pName));
        
        var prodTarget = event.currentTarget.dataset.tprodtarget;
        //console.log("In Trget&PlaningCompINT-->C-->onMouseOverHandler_M-->-->Prod Target-->" + JSON.stringify(prodTarget));
        
        var pId = event.currentTarget.dataset.tprodid;
        // var pId =  event.target.id;
        //console.log("In Trget&PlaningCompINT-->C-->onMouseOverHandler_M-->-->Prod ID-->" + JSON.stringify(pId));
        /*
        var getAllCellIdsAgainstAllProdId = component.get("v.allRowIdAgainstProd");
        let columnIds = Object.keys(getAllCellIdsAgainstAllProdId); // All Column Ids
        
        //console.log('Column Or Prod Ids-->'+columnIds);
        //console.log('CURR ColID--->'+JSON.stringify(currColId));
        //console.log('ALL VALUES OF COL-->'+getAllCellIdsAgainstAllProdId[currColId]);
        
        let cellIdsInCurrCol = [];
        cellIdsInCurrCol = getAllCellIdsAgainstAllProdId[pId];
        var totalSumOfCurrCol = 0;
        // console.log('total column length-->'+cellIdsInCurrCol.length);
        for(let m = 0 ; m < cellIdsInCurrCol.length; m++){
            
            if(!$A.util.isEmpty(document.getElementById(cellIdsInCurrCol[m]))){
                totalSumOfCurrCol += (!$A.util.isEmpty(document.getElementById(cellIdsInCurrCol[m]).value) ? parseInt(document.getElementById(cellIdsInCurrCol[m]).value) : 0);
            }	 
        }
        */
        var totalSumOfCurrCol =  0;
        var modalBody;
        //var modalFooter;
        $A.createComponents([
            ["c:TargetHighlight",
             {
                 "aura:id":pId,
                 "prodId":pId, 
                 "prodName" : pName,
                 "monthlyProdTarget": prodTarget,
                 "plannedProdTarget":totalSumOfCurrCol,
                 "demographic":"International"
                 
             }]
        ], function(components, status){
            if (status === "SUCCESS") {
                modalBody = components[0];
                // modalFooter = components[1];
                component.find("overlayLib").showCustomPopover({
                    //header: "Product Target Info",
                    body: modalBody, 
                    referenceSelector: ".mypopover", //This is imp as it is needed for showing popover next to the element For POPOver
                    cssClass: "no-pointer,popoverclass,cTargetAndPlanningInt"  
                    //cssClass: "slds-nubbin_left,slds-popover_walkthrough"  // this css for DARK THEME popover
                    //footer: modalFooter,
                    //showCloseButton: true,
                    //cssClass: "my-modal,my-custom-class,my-other-class",
                    //closeCallback: function() {
                    //    alert('You closed the alert!');
                    //}
                }).then(function (overlay) {
                    //you can timeout function like "window.setTimeout" or use directly setTimeout()
                    setTimeout(function(){ 
                        //close the popover after 2 seconds
                        overlay.close(); 
                    }, 3000);
                });
            }
        } );
    },
    onMouseOut : function(component, event, helper) {
        console.log('In Trget&PlaningCompINT-->C-->In MOUSE OUT!!!');
        //component.find("overlayLib").notifyClose();
        // var popup = window.open(location, '_self', '');
        // popup.close();
         var prodId = event.currentTarget.dataset.tprodid;
         console.log('In Trget&PlaningCompINT-->C-->onMouseOut_M-->ProdId/AuraId-->'+prodId);
        //helper.handleDestroy(component, event,prodId);
        
    },
    onParaClick : function(component, event, helper) {
       // console.log('In Trget&PlaningCompINT-->C-->In PARA CLICK Handler');
        
       // console.log('In Trget&PlaningCompINT-->C-->onParaClick_M-->HTML ID-->'+event.target.id);
    },
    onRefreshChildFuncHandler : function(component, event, helper) {
        //console.log("In Trget&PlaningCompInt-->C-->onRefreshChildFuncHandler_M !!");
        //$A.enqueueAction(component.get('c.doInit'));
        
        
        var params = event.getParam('arguments');
        if (params) {
            var param1Val = params.param1;
            if(param1Val == 'fromParent'){
                component.set("v.renderingDone",true);
                helper.onInit(component,event);    
            } 
        }
        //helper.onReset(component, event);
        
    }
});
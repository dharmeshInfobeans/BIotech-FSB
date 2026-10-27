({
    onAOPClick : function(component, event, helper) {
        console.log("In Target&Planing-->C-->In onAOPClick_M!!!!-->For Month-->"+component.get("v.targetMonth"));
        
        
        var aopId = event.currentTarget.dataset.aopid;
        //console.log("In Target&PlaningInt-->C-->onAOPClick_M-->AOP Id-->"+aopId);
        
        //Open AccountID in new Tab
        window.open('/'+aopId,'_blank');    
    },
    onAccountNameClick : function(component, event, helper) {
        console.log("In Target&Planing-->C-->In onAccountNameClick_M!!!!-->For Month-->"+component.get("v.targetMonth"));
        
        //console.log('HTML ID-->'+event.target.id);
        var accountId = event.currentTarget.dataset.accid;
        //console.log("In Target&PlaningInt-->C-->onAccountNameClick_M-->AccountId-->"+accountId);
        
        //Open AccountID in new Tab
        window.open('/'+accountId,'_blank');
        
        //Can't open url in new tab coz it is navigation so commented
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
        console.log("In Target&Planing-->C-->In onProductNameClick_M!!!!-->For Month-->"+component.get("v.targetMonth"));
        
        //console.log('HTML ID-->'+event.target.id);
        var productId = event.currentTarget.dataset.prodid;
        //console.log("In Target&PlaningInt-->C-->onProductNameClick_M-->ProductId-->"+productId);
        
        //Open productId in new Tab
        window.open('/'+productId,'_blank');
        
        //Can't open url in new tab coz it is navigation so commented
        /*
        var navLink = component.find("navService");
        var pageRef = {
            type: 'standard__recordPage',
            attributes: {
                actionName: 'view',
                objectApiName: 'Product__c',
                recordId : productId 
            },
        };
        navLink.navigate(pageRef, true);*/
    },
    doInit: function(component, event, helper) {
        if(navigator.onLine){
                console.log("In Target&PlaningComp-->C-->In doInit_M!!!!-->Internet-->Connected!");
                /*helper.showToast({
                            "title": "Success!!",
                            "type": "success",
                            "message": "You are online. "
                        });*/
        }else{
            console.log("In Target&PlaningComp-->C-->In doInit_M!!!!-->Internet-->Not Connected!");
            /*helper.showToast({
                            "title": "Error!!",
                            "type": "error",
                            "message": "Check Internet Connection."
                        });*/
        }
     
        helper.showSpinner(component, event);
        
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
                    //console.log("In Trget&PlaningComp-->C-->doInit_M-->IF-->Next Month-->" + component.get("v.nextMonth"));
                    //console.log("In Trget&PlaningComp-->C-->doInit_M-->IF-->N previous monthMAp INdex-->" + prvIf);  //parseInt(index) - parseInt(1));
                    //console.log("In Trget&PlaningComp-->C-->doInit_M-->IF-->N CURRENT monthMAp INdex-->" +currIf);     //+parseInt(index));
                    //console.log("In Trget&PlaningComp-->C-->doInit_M-->IF-->N next monthMAp INdex-->" +nxtIf)        //+parseInt(index) + parseInt(1)); 
                }else if(index == 11){
                    var prvEl = parseInt(index) - parseInt(1);
                    var currEl = parseInt(index);
                    var nxtEl = parseInt(index) * parseInt(0);
                    component.set("v.nextMonth",monthsMap[nxtEl]);
                    component.set("v.prevMonth",monthsMap[prvEl]);
                    //console.log("In Trget&PlaningComp-->C-->doInit_M-->ELSE IF-->Next Month-->" + component.get("v.nextMonth"));
                    //console.log("In Trget&PlaningComp-->C-->doInit_M-->ELSE-->N previous monthMAp INdex-->" + prvEl);  //parseInt(index) - parseInt(1));
                    //console.log("In Trget&PlaningComp-->C-->doInit_M-->ELSE-->N CURRENT monthMAp INdex-->" +currEl);     //+parseInt(index));
                    //console.log("In Trget&PlaningComp-->C-->doInit_M-->ELSE-->N next monthMAp INdex-->" +nxtEl)        //+parseInt(index) + parseInt(1)); 
                }else{
                    var prv = parseInt(index) - parseInt(1);
                    var curr = parseInt(index);
                    var nxt = parseInt(index) + parseInt(1);
                    component.set("v.nextMonth",monthsMap[nxt]);
                    component.set("v.prevMonth",monthsMap[prv]);
                    //console.log("In Trget&PlaningComp-->C-->doInit_M-->ELSE-->Next Month-->" + component.get("v.nextMonth"));
                    //console.log("In Trget&PlaningComp-->C-->doInit_M-->ELSE-->N previous monthMAp INdex-->" + prv);  //parseInt(index) - parseInt(1));
                    //console.log("In Trget&PlaningComp-->C-->doInit_M-->ELSE-->N CURRENT monthMAp INdex-->" +curr);     //+parseInt(index));
                    //console.log("In Trget&PlaningComp-->C-->doInit_M-->ELSE-->N next monthMAp INdex-->" +nxt)        //+parseInt(index) + parseInt(1)); 
                }
                
            }
        }
        
        
        
        
        
        
        if($A.util.isEmpty(component.get("v.targetYear"))){
            var d = new Date();
            var currYear = d.getFullYear();
            component.set("v.targetYear",currYear);    
        }
        
        console.log("In doInit!!!!");
        
        //Getting  Columns 
        var action = component.get("c.getTargetAmountByUserDivision");
        action.setParams({
            month: component.get("v.targetMonth"),
            year: component.get("v.targetYear"),
            demographic: 'Domestic'
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                helper.hideSpinner(component, event);
                var retData = response.getReturnValue();
                
                //console.log("In Trget&PlaningCompDOM-->C-->doInit_M--> PRODUCTS-->" +JSON.stringify(retData));
                
                let prodWithAop = [];
                var tarHTMLElemIdMap = component.get("v.targetElemntHTMLIdMap");
                if (!$A.util.isEmpty(retData)) {
                    for(var s = 0; s < retData.length; s++){
                        if(!$A.util.isEmpty(retData[s].Monthly_AOP__r)){
                            prodWithAop.push(retData[s]);
                            tarHTMLElemIdMap[retData[s].Id] = retData[s].Id+retData[s].Monthly_AOP__r[0].Id; //as only one mon AOP will be der per product
                        }    
                    }
                    //console.log("In Trget&PlaningCompDOM-->C-->doInit_M--> HTML ID MAP-->" +JSON.stringify(tarHTMLElemIdMap));
                    if(! $A.util.isEmpty(prodWithAop)){
                        //console.log('In Trget&PlaningCompDOM-->C-->doInit_M-->FILTERED PRODs With AOPs-->'+JSON.stringify(prodWithAop));
                        component.set("v.target", prodWithAop); // only Contains PROD with Aop                      
                    }else{
                        component.set("v.showError",true);
                        component.set("v.errorMessage","No AOP's for any product found.");
                        helper.showToast({
                           
                             "title": $A.get("$Label.c.Error!!"),
                            "type": "error",  
                           "message": $A.get("$Label.c.No_AOP_s_for_any_product_found")
                        });
                        
                    }
                    
                }else{
                    component.set("v.showError",true);
                    component.set("v.errorMessage","No AOP/Product found.");
                    helper.showToast({
                        "title": $A.get("$Label.c.Error!!"),
                        "type": "error",
                        "message": $A.get("$Label.c.No_AOP_Product_found")
                    });
                }
            }
            
        });
        
        $A.enqueueAction(action);
        
        //Getting Account rows
        var action2 = component.get("c.getAccounts");
        action2.setParams({
            month: component.get("v.targetMonth"),
            year: component.get("v.targetYear"),
            demographic: 'Domestic'
        });
        action2.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                helper.hideSpinner(component, event);
                var retData = response.getReturnValue();
                
                //console.log("In Trget&PlaningCompDOM-->C-->doInit_M--> ret Acc-->" +JSON.stringify(retData) );
                
                if (!$A.util.isEmpty(retData)) {
                    component.set("v.account", retData);
                    for(let i = 0; i < retData.length; i++){
                        if($A.util.isEmpty(retData[i].Account__r)){
                            component.set("v.showError",true);
                            component.set("v.errorMessage","No active account found.");
                            helper.showToast({
                                "title": $A.get("$Label.c.Error!!"),
                                "type": "error",
                                "message": $A.get("$Label.c.No_Active_account_found")
                            });    
                        }
                        
                    }
                }else{
                    component.set("v.showError",true);
                    component.set("v.errorMessage","No Monthly Plan Found.");
                    helper.showToast({
                        "title": $A.get("$Label.c.Error!!"),
                        "type": "error",
                        "message": $A.get("$Label.c.No_monthly_plan_found")
                    });
                }
                
                let mpps = [];
                var mppMap = component.get("v.testMap");
                var testMap = component.get("v.testMap2");
                var targetQty = [];
                
                
                
                for(let i = 0; i < retData.length; i++){
                    if(retData[i].Monthly_Product_Plans__r){
                        let mppArray = retData[i].Monthly_Product_Plans__r;
                        for(let j = 0; j < mppArray.length; j++){
                            mpps.push(mppArray[j]);
                            mpps.push(mppArray[j].AccountId = retData[i].Account__c); // Adding extra property "AccountId" to mpp
                            
                            mppMap[mppArray[j].Product__c+' '+mppArray[j].AccountId+' '+retData[i].Id] = mppArray[j].Planned_Quantity__c;
                            
                            /* Need to ask-->If we add "mppArray[j].Product__c+mppArray[j].Monthly_Target__c" as ID then we can avoid the use of "targetElemntHTMLIdMap" attribute as AOP will be mandatory */
                            targetQty.push({
                                Id : mppArray[j].Product__c+mppArray[j].Monthly_Target__c,
                                Planned_Quantity__c : ( (!$A.util.isEmpty(mppArray[j].Planned_Quantity__c)) ? mppArray[j].Planned_Quantity__c : 0 )
                            });
                            // testMap[mppArray[j].Product__c] =( (!$A.util.isEmpty(mppArray[j].Planned_Quantity__c)) ? mppArray[j].Planned_Quantity__c : 0);
                            
                        }   
                    }
                }
                
                component.set("v.testMap",mppMap);
                component.set("v.totalTarget",targetQty);
                if(mpps.length > 0){
                    component.set("v.mppsApex",mpps);
                    component.set("v.showExistingMPPs",true);
                    
                }
                
                //console.log("MPP's FROM APEX-->" + JSON.stringify(component.get("v.mppsApex")));
                //console.log("MAP ATTRIB VAL-->" + JSON.stringify(component.get("v.testMap")));
                //console.log("MAP VALUES-->" + JSON.stringify(mppMap));
                
                
                
                // Creating Array OF HTML ID(Row cell) against product after DOM Element is created.
                
                var acc = component.get("v.account");
                var prod = component.get("v.target");
                //console.log('ACC-->'+JSON.stringify(acc));		    
                //console.log('PROD-->'+JSON.stringify(prod));		    
                var productColIdArray = [];
                var allRowCellIdArray = [];                
                
                if(!$A.util.isEmpty(acc) && !$A.util.isEmpty(prod)){
                    
                    for(let i = 0; i < acc.length;  i++){
                        
                        for(let j = 0; j < prod.length; j++){
                            
                            if(acc[i].Account__c){
                                productColIdArray.push({"prodId":prod[j].Id, "colId":prod[j].Id+' '+acc[i].Account__c+' '+acc[i].Id});
                                allRowCellIdArray.push(prod[j].Id+' '+acc[i].Account__c+' '+acc[i].Id);
                            }
                        }
                    }
                    component.set("v.allRowCellIds",allRowCellIdArray);
                    //console.log('Prod COl IDs-->'+JSON.stringify(productColIdArray));		    
                    
                    let groupedArray2 = helper.getGroupedArrayByProperty2(productColIdArray,'prodId');
                    //console.log('GROUPED Prod COl IDs-->'+JSON.stringify(groupedArray2));
                    component.set("v.allRowIdAgainstProd",groupedArray2); // storing all row cell ids against product id.
                }
            }
        });
        
        $A.enqueueAction(action2);
    },
    onToggleValueChangeHandler : function(component, event, helper){
        console.log("In Targt&PlaningDOM-->C-->onToggleValueChangeHandler_M !!");
        var toggleIconValNew = component.get("v.toggleIcon");
        if(toggleIconValNew){
            console.log('In Targt&PlaningDOM-->C-->onToggleValueChangeHandler_M-->In LOCKED ICON STAGE!!');
            helper.lockSavedMonthlyPlanValue(component,event);
        }else{
            console.log('In Targt&PlaningDOM-->C-->-->onToggleValueChangeHandler_M-->In UNLOCKED ICON STAGE!!');
            helper.unlockSavedMonthlyPlanValue(component,event);
        }  
    },
    onInputChange : function(component, event, helper) {
        console.log('In Targt&PlaningDOM-->C-->onInputChange_M..!!!');
        
        component.set("v.renderingDone",false);
        var index = event.currentTarget.dataset.index;
        //console.log("In Targt&PlaningDOM-->C-->onInputChange_M-->INDEX No-->" + JSON.stringify(index));
        
        var val = event.target.value;
        //console.log('In Targt&PlaningDOM-->C-->onInputChange_M-->CURRENT CELL VALUE-->'+event.target.value);
        
        var prodName = event.currentTarget.dataset.prodname;
        //console.log("In Targt&PlaningDOM-->C-->onInputChange_M-->PROD NAME-->" + JSON.stringify(prodName));
        
        var prodId = event.currentTarget.dataset.prodid;
        //console.log("In Targt&PlaningDOM-->C-->onInputChange_M-->PROD ID-->" + JSON.stringify(prodId));
        
        var accId = event.currentTarget.dataset.accid;
        //console.log("In Targt&PlaningDOM-->C-->onInputChange_M-->Acc ID-->" + JSON.stringify(accId));
        
        var mpName = event.currentTarget.dataset.mpname;
        //console.log("In Targt&PlaningDOM-->C-->onInputChange_M-->MP NAME-->" + JSON.stringify(mpName));
        
        var mpID = event.currentTarget.dataset.mpid;
        //console.log("In Targt&PlaningDOM-->C-->onInputChange_M-->MP ID-->" + JSON.stringify(mpID));
        
        var currMonth = event.currentTarget.dataset.month;
        //console.log("In Targt&PlaningDOM-->C-->onInputChange_M-->MONTH-->" + JSON.stringify(currMonth));
        
        var currYear = event.currentTarget.dataset.year;
        //console.log("In Targt&PlaningDOM-->C-->onInputChange_M-->YEAR-->" + JSON.stringify(currYear));
        
        
        var ownerId = event.currentTarget.dataset.ownerid;
        //console.log("In Targt&PlaningDOM-->C-->onInputChange_M-->OWNER ID-->" + JSON.stringify(ownerId));
        //
        var totalProdTarget = event.currentTarget.dataset.prodtarget;
        //console.log("In Targt&PlaningDOM-->C-->onInputChange_M-->Total Prod Target Defined-->" + JSON.stringify(totalProdTarget));
        
        var aopRecordId = event.currentTarget.dataset.prodaopid;
        //console.log("In Targt&PlaningDOM-->C-->onInputChange_M-->AOP Record Id-->" + JSON.stringify(aopRecordId)); 
        
        var finYearDate = event.currentTarget.dataset.finyeardate;
        console.log("In Targt&PlaningDOM-->C-->onInputChange_M-->Fin Year Date->" + JSON.stringify(finYearDate)); 
        
        var accSAPCode = event.currentTarget.dataset.accsapcode;
        console.log("In Targt&PlaningDOM-->C-->onInputChange_M-->acc SAPCODE->" + JSON.stringify(accSAPCode)); 
        
        var prodCode = event.currentTarget.dataset.prodcode;
        console.log("In Targt&PlaningDOM-->C-->onInputChange_M-->prod CODE->" + JSON.stringify(prodCode)); 
        
        if(val < 0){
            event.target.value = 0; // set current cell value to 0.
            helper.showToast({
                "title": $A.get("$Label.c.Oops!!"),
                "type": "error",
                "message": $A.get("$Label.c.You_cannot_enter_negative_value")
            }); 
        }
        
        
        
        if( !$A.util.isEmpty(prodId) && !$A.util.isEmpty(mpID) && !$A.util.isEmpty(currMonth) &&
           !$A.util.isEmpty(currYear) && !$A.util.isEmpty(ownerId) && (val >=0)){
            //console.log('In Targt&PlaningDOM-->C-->onInputChange_M-->Inside VAL!!!');
            var mppArrayList = component.get("v.mpps");
            
            var newObj = {
                Month__c: currMonth,
                Year__c: currYear,
                User__c: ownerId, //account owner
                Product__c:prodId,
                Planned_Quantity__c:val,
                Monthly_Plan__c:mpID,
                Monthly_Target__c:aopRecordId,
                Financial_Year_Date__c:finYearDate,
                MPP_Mapping__c:currMonth+currYear+prodCode+accSAPCode,
                AccountId : accId,
                Time: Date.now()
            }
            console.log('In Targt&PlaningDOM-->C-->onInputChange_M-->NEW OBJ-->'+JSON.stringify(newObj));
            //console.log('In INPUTCHANGE CURRENT CELL VALUE-->'+event.target.value);
            
            //mppArrayList.push(newObj);  
            
            //if(!$A.util.isEmpty(newObj.Product__c) && !$A.util.isEmpty(newObj.Planned_Quantity__c) ){
            if(!$A.util.isEmpty(newObj.Product__c)  ){                
                // var tVal = document.getElementById(newObj.Product__c);
                // var currTargetVal = tVal.getAttribute('data-totalprodtarget');
                // console.log('Total Target VAl Of Prod From Apex-->'+currTargetVal);
                //var currTargetVal = document.getElementById(newObj.Product__c).innerHTML; // get target value for product
                if(!$A.util.isEmpty(totalProdTarget)){
                    //var comp = (parseInt(totalProdTarget) >= parseInt(newObj.Planned_Quantity__c));
                    //console.log('currTargetVal >= newObj.Planned_Quantity__c-->'+comp);
                    //if(comp){
                    mppArrayList.push(newObj); 
                    let currColId = newObj.Product__c;
                    var getAllCellIdsAgainstAllProdId = component.get("v.allRowIdAgainstProd");
                    let columnIds = Object.keys(getAllCellIdsAgainstAllProdId); // All Column Ids
                    
                    // console.log('Column Or Prod Ids-->'+columnIds);
                    // console.log('CURR ColID--->'+JSON.stringify(currColId));
                    //console.log('ALL VALUES OF COL-->'+getAllCellIdsAgainstAllProdId[currColId]);
                    
                    let cellIdsInCurrCol = [];
                    cellIdsInCurrCol = getAllCellIdsAgainstAllProdId[currColId];
                    let totalSumOfCurrCol = 0;
                    //console.log('total column length-->'+cellIdsInCurrCol.length);
                    for(let m = 0 ; m < cellIdsInCurrCol.length; m++){
                        
                        if(!$A.util.isEmpty(document.getElementById(cellIdsInCurrCol[m]))){
                            
                            totalSumOfCurrCol += ( (!$A.util.isEmpty(document.getElementById(cellIdsInCurrCol[m]).value)) ? parseInt(document.getElementById(cellIdsInCurrCol[m]).value) : 0);
                        }	 
                    }
                    
                    
                    
                    
                    //(partial_sum, a) => partial_sum + a
                    //  console.log('Col Ids-->'+JSON.stringify(cellIdsInCurrCol));
                    // console.log('N Total Sum-->'+JSON.stringify(totalSumOfCurrCol));
                    helper.updateTargetValueOfProduct(component,event,newObj.Product__c+aopRecordId,totalSumOfCurrCol);       
                    /*}else{
                        event.target.value = 0; // set current cell value to 0.
                        helper.showToast({
                            "title": "Oops!!",
                            "type": "error",
                            "message": "You cannot have more value than the target."
                        });
                    } */
                }else{
                    // For Now, we are pushing Product's that not target also... (Note: Every product will have target)
                    mppArrayList.push(newObj); 
                }
                //
            }
            
            
            // Removing Duplicate From Array.
            for(let i = 0; i < mppArrayList.length; i++){
                
                for(let j = i+1; j < mppArrayList.length; j++){
                    
                    if(mppArrayList[j].Product__c == mppArrayList[i].Product__c && mppArrayList[j].Planned_Quantity__c == mppArrayList[i].Planned_Quantity__c &&
                       mppArrayList[j].Monthly_Plan__c == mppArrayList[i].Monthly_Plan__c ){
                        if(mppArrayList[j].Time > mppArrayList[i].Time){
                            //console.log('Inside Equal!!!!!!!! ');
                            var removedArray = mppArrayList.splice(i,1);
                            // console.log('I SPLICED Array -->'+JSON.stringify(removedArray));
                        }else{
                            //console.log('Inside Equal!!!!!!!! ');
                            var removedArray2 = mppArrayList.splice(j,1);
                            // console.log('J SPLICED Array -->'+JSON.stringify(removedArray2));
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
                            //console.log('Inside Equal!!!!!!!! ');
                            var removedArray = mppArrayList.splice(i,1);
                            //console.log('!= I SPLICED Array -->'+JSON.stringify(removedArray));
                        }else{
                            //console.log('Inside Equal!!!!!!!! ');
                            var removedArray2 = mppArrayList.splice(j,1);
                            // console.log('!= J SPLICED Array -->'+JSON.stringify(removedArray2));
                        }
                        
                    }
                    
                    
                }
            }
            console.log('ON INPUT FINAL-->'+JSON.stringify(mppArrayList));
            
            
            
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
        //var rowId = document.getElementById('0010l00000ZW9GaAAL').value;
        // console.log("ROW VAL's-->"+rowId); 
        
        
        /*   var index = event.currentTarget.dataset.index;
        console.log("INDEX-->" + JSON.stringify(index));
        
        var val = event.target.value;
        console.log("VAL-->" + val);
        
        var index2 = event.currentTarget.dataset.prodname;
        console.log("PROD NAME-->" + JSON.stringify(index2));
        
         var prodId = event.currentTarget.dataset.prodid;
        console.log("PROD ID-->" + JSON.stringify(prodId));
        
        var accId = event.currentTarget.dataset.accid;
        console.log("Acc ID-->" + JSON.stringify(accId));

         var mpName = event.currentTarget.dataset.mpname;
        console.log("MP NAME-->" + JSON.stringify(mpName));*/
        var mppArrayList = [];
        mppArrayList = component.get("v.mpps");
        //console.log("ON SAVE-->DATA 2Be Save-->"+JSON.stringify(mppArrayList));
        
        
        
        //Again Removing Duplicate From Array If Exist.
        
        for(let i = 0; i < mppArrayList.length; i++){
            
            for(let j = i+1; j < mppArrayList.length; j++){
                
                if(mppArrayList[j].Product__c == mppArrayList[i].Product__c && mppArrayList[j].Planned_Quantity__c == mppArrayList[i].Planned_Quantity__c &&
                   mppArrayList[j].Monthly_Plan__c == mppArrayList[i].Monthly_Plan__c ){
                    if(mppArrayList[j].Time > mppArrayList[i].Time){
                        //console.log('Inside Equal!!!!!!!! ');
                        var removedArray = mppArrayList.splice(i,1);
                        console.log('I SPLICED Array -->'+JSON.stringify(removedArray));
                    }else{
                        //console.log('Inside Equal!!!!!!!! ');
                        var removedArray2 = mppArrayList.splice(j,1);
                        console.log('J SPLICED Array -->'+JSON.stringify(removedArray2));
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
                        //console.log('Inside Equal!!!!!!!! ');
                        var removedArray = mppArrayList.splice(i,1);
                        console.log('!= I SPLICED Array -->'+JSON.stringify(removedArray));
                    }else{
                        //console.log('Inside Equal!!!!!!!! ');
                        var removedArray2 = mppArrayList.splice(j,1);
                        console.log('!= J SPLICED Array -->'+JSON.stringify(removedArray2));
                    }
                    
                }
                
                
            }
        }
        console.log('ON SAVE FINAL-->'+JSON.stringify(mppArrayList));
        
        // This Array is used later on when apex response is success and will add to values to "testMap" attribute.
        
        let newMppToLockMap = component.get("v.cloneMap"); 
        
        // console.log('CLONED ARRAY-->'+JSON.stringify(finalMppArrayList));
        
        
        
        // Removing "AccountId" property Of each Mpp Object before sending it to Apex.
        for(let i = 0; i < mppArrayList.length; i++){
            //For Locking New Mpp(Input TextBx) adding new values to Map.
            newMppToLockMap[mppArrayList[i].Product__c +' '+mppArrayList[i].AccountId+' '+mppArrayList[i].Monthly_Plan__c] = mppArrayList[i].Planned_Quantity__c;
            mppArrayList[i].AccountId = undefined;
            
        } 
        
        
        // console.log('ON SAVE FINAL-->BEFORE APEX-->'+JSON.stringify(mppArrayList));
        //console.log('ON SAVE FINAL-->BEFORE APEX-->NEW MAP VAL-->'+JSON.stringify(newMppToLockMap));
        
        
        
        
        // console.log('BEFORE Adding New Val-->Map VAL-->'+JSON.stringify(component.get("v.testMap")));        
        
        //var rstData = component.get("v.mpps");
        // console.log("ON SAVE-->After RST-->"+JSON.stringify(rstData));
        
        
        var action2 = component.get("c.saveMPPS");
        action2.setParams({
            mppList: mppArrayList,
            month: component.get("v.targetMonth"),
            year : component.get("v.targetYear"),
            demographic: 'Domestic'
        });
        action2.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                helper.hideSpinner(component, event);
                //var retData = response.getReturnValue();
                
                helper.showToast({
                    "title": $A.get("$Label.c.Success_Record_Updated"),
                    "type": "success",
                    "message": mppArrayList.length +$A.get("$Label.c.Records_Updated")
                });
                console.log("In Trget&PlaningCompDom-->C-->onSave_M--> Apex Resp Success!!!");
                
                /*var savedInputMppValAndQtyMap = component.get("v.testMap"); // "testMap" holds existing Mpp value which is saved in database in the form -->(InputHtmlId vs MppValue)
                
                // If apex response is success then adding the new values(which was just saved above) to the 
                // existing Mpp value Map which holds the value which was retrieved from apex when comp is loaded.
                for (var kee of Object.keys(newMppToLockMap)){
                    savedInputMppValAndQtyMap[kee] = newMppToLockMap[kee];
                }      
                
                
                //console.log('After Adding New Val-->Map VAL-->'+JSON.stringify(savedInputMppValAndQtyMap));
                
                
                // It is Imp here to use timeout function coz after firing comp goes out of framework lifecycle.
                // Modifying Components Outside the Framework Lifecycle (Imp to use "$A.getCallback" for timeout)
                window.setTimeout(
                    $A.getCallback(function() {
                        console.log('In Trget&PlaningCompDom-->C-->onSave_M--> In TimeOut Function!!');
                        component.set("v.toggleIcon",true);
                        helper.lockSavedMonthlyPlanValue(component, event);
                    }), 50);*/
                
                 var cmpEvent = component.getEvent("switchTabIntEvt");
                cmpEvent.setParams({
                    nextTab : component.get("v.nextMonth"),
                    currentTab : component.get("v.targetMonth")
                });
                //console.log('In Target&Planing-->C-->onSave_M-->COMP EVENT DATA IN CHILD-->'+JSON.stringify(cmpEvent));
                cmpEvent.fire();
                
                
            }else{
                helper.hideSpinner(component, event);
                console.log('In Trget&PlaningCompDom-->C-->onSave_M--> Apex Resp-->Error Record not saved!!');
                helper.showToast({
                    "title": $A.get("$Label.c.Oops!!"),
                    "type": "error",
                    "message": $A.get('$Label.c.Error_occurred_while_saving_record')
                });
            }
        });
        
        $A.enqueueAction(action2);
    },
    
    onResetHandler : function(component, event, helper) {
        
        //console.log("IN Targt&PlnCont-->C-->onResetHandler_M !!");
        var compEvent = component.getEvent("switchTab");
        compEvent.setParams({
            refreshParent : true
        });
        compEvent.fire();
        console.log("IN Targt&PlnCont-->C-->onResetHandler_M--> Fired Comp Event !!");
        //helper.onReset(component,event);
        // var resetVal = [];
        // component.set("v.mpps",resetVal);
        // $A.get('e.force:refreshView').fire();
        
    },
    
    onFill : function(component, event, helper) {
        
        // var prodVal =  document.getElementById('a040l000008qiVDAAY').innerHTML;
        //var prodVal = component.find("a040l000008qiVDAAYHSAS600");
        // console.log("PROD TRGT VAL 2-->"+JSON.stringify(prodVal));
        // console.log("TYPEOF PROD TRGT VAL 2-->"+typeof prodVal);
        helper.updateProductTargetValue(component,event);
        
    },
    onRender : function(component, event, helper) {
        console.log('IN controller--> onRender_M !!');
        var toDoRendering = component.get("v.renderingDone");
        if(toDoRendering){
            helper.updateExistingMppValueOnHtmlElement(component,event);
        }
    },
    onIconClick : function(component, event, helper) {
        console.log("In ICON CLICK HANDLER!!");
        component.set("v.renderingDone",false); // this stops default aura framework's rendering event
        var toggleIconVal = component.get("v.toggleIcon");
        console.log('toggle val-->'+toggleIconVal);
        ((toggleIconVal) ? component.set("v.toggleIcon",false) : component.set("v.toggleIcon",true));
    },
    
    onFocusHandler : function(component, event, helper) {
        console.log('In Onfocus Handler!!!');
        var val = event.target.value;
        console.log("In Onfocus-->Planned VAL-->" + val);
        
        var pName = event.currentTarget.dataset.tprodname;
        console.log("NN In Onfocus-->PROD NAME-->" + JSON.stringify(pName));
        
        var prodTarget = event.currentTarget.dataset.tprodtarget;
        console.log("NN In Onfocus-->Prod Target-->" + JSON.stringify(prodTarget));
        
        var pId = event.currentTarget.dataset.tprodid;
        // var pId =  event.target.id;
        console.log("NN In Onfocus-->Prod ID-->" + JSON.stringify(pId));
        
        var getAllCellIdsAgainstAllProdId = component.get("v.allRowIdAgainstProd");
        let columnIds = Object.keys(getAllCellIdsAgainstAllProdId); // All Column Ids
        
        //console.log('Column Or Prod Ids-->'+columnIds);
        //console.log('CURR ColID--->'+JSON.stringify(currColId));
        //console.log('ALL VALUES OF COL-->'+getAllCellIdsAgainstAllProdId[currColId]);
        
        let cellIdsInCurrCol = [];
        cellIdsInCurrCol = getAllCellIdsAgainstAllProdId[pId];
        let totalSumOfCurrCol = 0;
        // console.log('total column length-->'+cellIdsInCurrCol.length);
        for(let m = 0 ; m < cellIdsInCurrCol.length; m++){
            
            if(!$A.util.isEmpty(document.getElementById(cellIdsInCurrCol[m]))){
                totalSumOfCurrCol += (!$A.util.isEmpty(document.getElementById(cellIdsInCurrCol[m]).value) ? parseInt(document.getElementById(cellIdsInCurrCol[m]).value) : 0);
            }	 
        }
        
        var modalBody;
        //var modalFooter;
        $A.createComponents([
            ["c:TargetHighlight",
             {
                 prodId:pId, 
                 prodName : pName,
                 monthlyProdTarget: prodTarget,
                 plannedProdTarget:totalSumOfCurrCol,
                 demographic:'Domestic'
                 
             }]
        ], function(components, status){
            if (status === "SUCCESS") {
                modalBody = components[0];
                // modalFooter = components[1];
                component.find("overlayLib").showCustomPopover({
                    //header: "Product Target Info",
                    body: modalBody, 
                    referenceSelector: ".mypopover", //This is imp as it is needed for showing popover next to the element For POPOver
                    cssClass: "slds-popover_walkthrough,slds-popover_feature,popoverclass,cTargetAndPlanning"  
                    //cssClass: "slds-nubbin_left,slds-popover_walkthrough"  // this css for DARK THEME popover
                    //footer: modalFooter,
                    //showCloseButton: true,
                    //cssClass: "my-modal,my-custom-class,my-other-class",
                    //closeCallback: function() {
                    //    alert('You closed the alert!');
                    //}
                }).then(function (overlay) {
                    setTimeout(function(){ 
                        //close the popover after 2 seconds
                        overlay.close(); 
                    }, 2000);
                });
            }
        } );
    },
    onMouseOut : function(component, event, helper) {
        console.log('In MOUSE OUT!!!');
        component.find("overlayLib").notifyClose();
        // var popup = window.open(location, '_self', '');
        // popup.close();
    }
});
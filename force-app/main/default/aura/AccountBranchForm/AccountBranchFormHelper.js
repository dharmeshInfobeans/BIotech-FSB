({
    
    
    MAX_FILE_SIZE: 4500000, //Max file size 4.5 MB 
    CHUNK_SIZE: 750000,      //Chunk Max size 750Kb
    
    showToast : function(params){
        var toastEvent = $A.get('e.force:showToast');
        if(toastEvent){
            toastEvent.setParam(params);
            toastEvent.fire();
        } else{
            alert(params.message);
        }
    },
    showSpinner : function(component, event) {
        component.set("v.showSpinner",true);
    },
    hideSpinner : function(component, event) {
        component.set("v.showSpinner",false);
    },
    fetchBranchLocationData : function(component, event) {
        var fetchBranchLocation = component.get("v.acc.Branch__c");
        var action = component.get("c.getBranchFormDataByBranchLocation");
        action.setParams({
            "branchLocation" : fetchBranchLocation
        });
        action.setCallback(this,function(response){
            var state = response.getState() ;
            if(state === 'SUCCESS'){
                var retVal =  response.getReturnValue();
                if(retVal){
                    //console.log('In AccBrnchFormComp-->H-->fetchBranchLocationData_M-->Return BranchLocDatCusSet VAL-->'+JSON.stringify(retVal));
                    var salesDisSet = new Set(); //component.get("v.salesDistrictSet");
                    var regCodeSet = new Set();//component.get("v.regionCodeSet");
                    var delPlantSet = new Set();//component.get("v.deliveryPlantSet");
                    retVal.forEach(function(element) {
                        //console.log('Each Element-->'+JSON.stringify(element));
                        salesDisSet.add(element.Sales_District__c);
                        regCodeSet.add(element.Region_Code__c);
                        delPlantSet.add(element.Delivery_Plant__c);
                    });
                    var salesDistPKVL = component.get("v.salesDistrictPKVL");
                    salesDisSet.forEach(function(element) {
                        salesDistPKVL.push(element);
                    });
                    var delPlantPKVL = component.get("v.delPlantPKVL");
                    delPlantSet.forEach(function(element) {
                        delPlantPKVL.push(element);
                    });
                    var regCodePKVL = component.get("v.regionCodePKVL");
                    regCodeSet.forEach(function(element) {
                        regCodePKVL.push(element);
                    });
                    component.set("v.regionCodePKVL",regCodePKVL);
                    component.set("v.delPlantPKVL",delPlantPKVL);
                    component.set("v.salesDistrictPKVL",salesDistPKVL);
                    //console.log('salesDistPKVL-->'+JSON.stringify(salesDistPKVL));
                    //console.log('delPlantPKVL-->'+JSON.stringify(delPlantPKVL));
                    //console.log('In AccBrnchFormComp-->H-->fetchBranchLocationData_M-->regCodeSet has VAL-->'+JSON.stringify(regCodeSet.entries()));
                    //console.log('In AccBrnchFormComp-->H-->fetchBranchLocationData_M-->delPlantSet VAL-->'+JSON.stringify(delPlantSet.entries()));
                    //component.set("v.regionCodeSet", regCodeSet);
                    //component.set("v.deliveryPlantSet", delPlantSet);
                    
                    /*for(var dataCusSet in retVal){
                    console.log('dataCusSet-->'+JSON.stringify(dataCusSet));
                    console.log('dataCusSet.Sales_District__c-->'+JSON.stringify(dataCusSet.Sales_District__c));
                    salesDisSet.push(dataCusSet.Sales_District__c);
                }*/
                    
                    //console.log('In AccBrnchFormComp-->H-->fetchBranchLocationData_M-->salesDisSet VAL-->'+JSON.stringify(component.get("v.salesDistrictSet")));
                    
                }else{
                    console.log('In AccBrnchFormComp-->H-->fetchBranchLocationData_M-->Apex Response is null');
                }
                
            }
        });
        $A.enqueueAction(action);
    },
    goToThankyouComp : function(component, event, helper) {
        console.log("In AccBranchFormComp-->H-->In-->goToThankyouComp_M!! ");
        
        var navLink = component.find("navService");
        var pageRef = {
            type: 'standard__component',
            attributes: {
                "componentName": "c__ThankYou"
            },
        };
        navLink.navigate(pageRef, true);
        console.log("In AccBranchFormComp-->H-->In-->goToThankyouComp_M-->After navigation...");
    },
    gotoThankYouPage : function(component, event) {
        console.log("ZZZ AccBrnchFormComp-->H-->gotoThankYouPage_M-->Entered!!");
        window.location.href = '/thankyoupage';
        console.log('After..............');
        var urlEvent = $A.get("e.force:navigateToURL");
        urlEvent.setParams({
            "url":"/apex/thankyoupage"
        });
        urlEvent.fire(); 
    },
    checkBranchFormMandatoryFields : function(component, event) {
        //console.log('In AccBrnchFormComp-->H-->In-->checkBranchFormMandatoryFields_M !!');
        var salesDist = component.find('sDis').get('v.value');
        var deliveryPlant = component.find('deliveryPlant').get('v.value');
        var regCode = component.find('regCode').get('v.value');
        
        
        var numOfCusMappedSAP = component.find('numOfCusMappedSAP').get('v.value');
        var numOfAccOverdue   = component.find('numOfAccOverdue').get('v.value');
        
        // var checkDollarAIsEmpty = $A.util.isEmpty(numOfCusMappedSAP);
        // console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->1st checkDollarAIsEmpty-->'+checkDollarAIsEmpty);
        
        
        var cusType1 = component.find('cusType1').get('v.value');
        var totalCusMapped = component.find('totalCusMapped').get('v.value');
        var accOverdue = component.find('accOverdue').get('v.value');
        var perAccOverdue = component.find('perAccOverdue').get('v.value');
        var colList = component.find('colList').get('v.value');
        var accOverdueLst = component.find('accOverdueLst').get('v.value');
        var perLstOverdue = component.find('perLstOverdue').get('v.value');
        var grossSales = component.find('grossSales').get('v.value');
        var grnValue = component.find('grnValue').get('v.value');
        var maxLimit = component.find('maxLimit').get('v.value');
        
        /*console.log('CUSTYPE1-->'+cusType1);
        var checkDollarAIsEmpty2 = (cusType1 == 'undefined' || cusType1 == '');
        console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->2nd checkDollarAIsEmpty-->'+checkDollarAIsEmpty2);
        
        var checkThree = $A.util.isUndefinedOrNull(grossSales);
        console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->$A.util.isUndefinedOrNull-->'+checkThree);    
        
        var checkFour = $A.util.isEmpty(grossSales);
        console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->$A.util.isEmpty-->'+checkFour); 
        
        var checkFive = $A.util.isEmpty(perLstOverdue);
        console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->$A.util.isEmpty 2-->'+checkFive);*/ 
        
        
        var cusType2 = component.find('cusType2').get('v.value');
        var totalCusMapped2 = component.find('totalCusMapped2').get('v.value');
        var accOverdue2 = component.find('accOverdue2').get('v.value');
        var perAccOverdue2 = component.find('perAccOverdue2').get('v.value');
        var colList2 = component.find('colList2').get('v.value');
        var accOverdueLst2 = component.find('accOverdueLst2').get('v.value');
        var perLstOverdue2 = component.find('perLstOverdue2').get('v.value');
        var grossSales2 = component.find('grossSales2').get('v.value');
        var grnValue2 = component.find('grnValue2').get('v.value');
        var maxLimit2 = component.find('maxLimit2').get('v.value');
        
        /*console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->salesDist  VAL-->'+salesDist);
        console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->deliveryPlant  VAL-->'+deliveryPlant );
        console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->regCode  VAL-->'+regCode );
        console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->numOfCusMappedSAP  VAL-->'+numOfCusMappedSAP );
        console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->numOfAccOverdue    VAL-->'+numOfAccOverdue   );
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->cusType1  VAL-->'+cusType1 );                    
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->totalCusMapped  VAL-->'+totalCusMapped );                    
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->accOverdue  VAL-->'+accOverdue );                    
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->perAccOverdue  VAL-->'+perAccOverdue);                    
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->colList  VAL-->'+colList );                    
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->accOverdueLst  VAL-->'+accOverdueLst);                    
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->perLstOverdue  VAL-->'+perLstOverdue );                    
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->grossSales  VAL-->'+grossSales );                    
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->grnValue  VAL-->'+grnValue );                    
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->maxLimit  VAL-->'+maxLimit);                    
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->cusType2  VAL-->'+cusType2 );                    
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->totalCusMapped2  VAL-->'+totalCusMapped2 );                    
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->accOverdue2  VAL-->'+accOverdue2 );                    
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->perAccOverdue2  VAL-->'+perAccOverdue2);                    
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->colList2  VAL-->'+colList2 );                    
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->accOverdueLst2  VAL-->'+accOverdueLst2);                    
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->perLstOverdue2  VAL-->'+perLstOverdue2 );                    
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->grossSales2  VAL-->'+grossSales2 );                    
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->grnValue2  VAL-->'+grnValue2 );                    
		console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->maxLimit2  VAL-->'+maxLimit2); */                                        
        
        if(($A.util.isEmpty(salesDist) || $A.util.isEmpty(deliveryPlant) || $A.util.isEmpty(regCode )) ||            
           ($A.util.isEmpty(numOfCusMappedSAP ) || $A.util.isEmpty(numOfAccOverdue) ||
            $A.util.isEmpty(cusType1 ) || $A.util.isEmpty(totalCusMapped ) || $A.util.isEmpty(accOverdue ) ||
            $A.util.isEmpty(colList ) || $A.util.isEmpty(accOverdueLst ) ||
            $A.util.isEmpty(grossSales) || $A.util.isEmpty(grnValue) ||
            $A.util.isEmpty(maxLimit )) || 
           ($A.util.isEmpty(cusType2 ) || $A.util.isEmpty(totalCusMapped2 ) || $A.util.isEmpty(accOverdue2 ) ||
            $A.util.isEmpty(colList2 ) || $A.util.isEmpty(accOverdueLst2 ) ||
            $A.util.isEmpty(grossSales2) || $A.util.isEmpty(grnValue2) ||
            $A.util.isEmpty(maxLimit2))){
            //console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->In If Cond');
            return false;
        }else{
            // console.log('In AccBrnchFormComp-->H-->checkBranchFormMandatoryFields_M-->In Else Cond');
            return true;
        }
        
    },
    onTotalCusMapChangeH : function(component, event) {
        
        
        var customerMappedSAP = component.find("numOfCusMappedSAP").get("v.value");
        console.log('In AccBrnchFormComp-->H-->onTotalCusMapChangeH_M-->customerMappedSAP VAL-->'+customerMappedSAP);        
        
        
        
        //var tsmVal = component.get("v.totalCusMapped1");
        var tsmVal = component.find("totalCusMapped").get("v.value");
        var accOverdueVal = component.find("accOverdue").get("v.value");
        if(! $A.util.isUndefinedOrNull(tsmVal) && tsmVal != ''){
            if(! $A.util.isUndefinedOrNull(accOverdueVal) && accOverdueVal != ''){
                component.find("perAccOverdue").set("v.value", (accOverdueVal / tsmVal) );     
            }else{
                component.find("perAccOverdue").set("v.value", 0 );      
            }
            
        }else{
            component.find("perAccOverdue").set("v.value", 0 );     
        }
        
        
        //var tsmVal2 = component.get("v.totalCusMapped1");
        var tsmVal2 = component.find("totalCusMapped2").get("v.value");
        var accOverdueVal2 = component.find("accOverdue2").get("v.value");
        if(! $A.util.isUndefinedOrNull(tsmVal2) && tsmVal2 != ''){
            if(! $A.util.isUndefinedOrNull(accOverdueVal2) && accOverdueVal2 != ''){
                component.find("perAccOverdue2").set("v.value", (accOverdueVal2 / tsmVal2) );     
            }else{
                component.find("perAccOverdue2").set("v.value", 0 );      
            }
            
        }else{
            component.find("perAccOverdue2").set("v.value", 0 );     
        }
        //console.log('ZZZZZZ TYPE of TSM-->'+ typeof tsmVal);
        //console.log('ZZZZZZ EMP_F VAL-->'+ $A.util.isEmpty(tsmVal));
        // console.log('ZZZ $A val-->'+ ($A.util.isUndefinedOrNull(tsmVal) && tsmVal == ''));
        //console.log('tsm val1 -->'+ ( ($A.util.isUndefinedOrNull(tsmVal) && tsmVal != '') ? 0 : parseFloat(tsmVal)));
        component.find("ttotalCusMapped").set("v.value", (($A.util.isEmpty(tsmVal)) ? parseFloat(0) : parseFloat(tsmVal))  + (($A.util.isEmpty(tsmVal2)) ? parseFloat(0) : parseFloat(tsmVal2)) );     
        
        var sumOfTotalCusMap1And2 = component.find("ttotalCusMapped").get("v.value");
        
        if(sumOfTotalCusMap1And2 > customerMappedSAP){
            alert("Sum of total customer mapped(Bundled + Non-Bundled) cannot be greater than No.of customer mapped in SAP");
            component.find("totalCusMapped").set("v.value","");
            component.find("totalCusMapped2").set("v.value","");
            component.find("ttotalCusMapped").set("v.value","");
        }
        
        var totalTSM = component.find("ttotalCusMapped").get("v.value"); 
        var totalAccOverdue = component.find("taccOverdue").get("v.value");
        component.find("tperAccOverdue").set("v.value", ( ($A.util.isEmpty(totalAccOverdue)) ? parseFloat(0) : parseFloat(totalAccOverdue))  / (($A.util.isEmpty(totalTSM)) ? parseFloat(0) : parseFloat(totalTSM)) );     
        
        var totalPerAccOverdueVal = component.find("tperAccOverdue").get("v.value");
        // console.log('In AccBrnchFormComp-->H-->onAccOverdueChangeH_M-->totalperAccOverdue-->'+totalPerAccOverdueVal);        
        if(typeof totalPerAccOverdueVal === 'NaN'){
            component.find("tperAccOverdue").set("v.value",0);    
        }
        
        
    },
    onAccOverdueChangeH : function(component, event) {
        
        var numOfAccOverdue = component.find("numOfAccOverdue").get("v.value");
        console.log('In AccBrnchFormComp-->H-->onTotalCusMapChangeH_M-->onAccOverdueChangeH VAL-->'+numOfAccOverdue);  
        
        var tsmVal = component.find("totalCusMapped").get("v.value");
        var accOverdueVal = component.find("accOverdue").get("v.value");
        if(! $A.util.isUndefinedOrNull(accOverdueVal) && accOverdueVal != ''){
            if(! $A.util.isUndefinedOrNull(tsmVal) && tsmVal != ''){
                component.find("perAccOverdue").set("v.value", (accOverdueVal / tsmVal) );     
            }else{
                component.find("perAccOverdue").set("v.value", 0 );      
            }
            
        }else{
            component.find("perAccOverdue").set("v.value", 0 );     
        }
        
        var tsmVal2 = component.find("totalCusMapped2").get("v.value");
        var accOverdueVal2 = component.find("accOverdue2").get("v.value");
        if(! $A.util.isUndefinedOrNull(accOverdueVal2) && accOverdueVal2 != ''){
            if(! $A.util.isUndefinedOrNull(tsmVal2) && tsmVal2 != ''){
                component.find("perAccOverdue2").set("v.value", (accOverdueVal2 / tsmVal2) );     
            }else{
                component.find("perAccOverdue2").set("v.value", 0 );      
            }
            
        }else{
            component.find("perAccOverdue2").set("v.value", 0 );     
        }
        
        component.find("taccOverdue").set("v.value", ( ($A.util.isEmpty(accOverdueVal)) ? parseFloat(0) : parseFloat(accOverdueVal))  + (($A.util.isEmpty(accOverdueVal2)) ? parseFloat(0) : parseFloat(accOverdueVal2)) );  
        
        console.log('In AccBrnchFormComp-->H-->onAccOverdueChangeH VAL-->totalAccOverdue val-->'+component.find("taccOverdue").get("v.value"));  
        var sumOfTotalAccOverdue = component.find("taccOverdue").get("v.value");
        
        if(sumOfTotalAccOverdue > numOfAccOverdue){
            alert("Sum of Account Overdues(Bundled + Non-Bundled) cannot be greater than No.of Account Overdue");
            component.find("accOverdue").set("v.value","");
            component.find("accOverdue2").set("v.value","");
            component.find("taccOverdue").set("v.value","");
        }
        
        var totalTSM = component.find("ttotalCusMapped").get("v.value"); 
        var totalAccOverdue = component.find("taccOverdue").get("v.value");
        component.find("tperAccOverdue").set("v.value", ( ($A.util.isEmpty(totalAccOverdue)) ? parseFloat(0) : parseFloat(totalAccOverdue))  / (($A.util.isEmpty(totalTSM)) ? parseFloat(0) : parseFloat(totalTSM)) );     
        
        var totalPerAccOverdueVal = component.find("tperAccOverdue").get("v.value");
        // console.log('In AccBrnchFormComp-->H-->onAccOverdueChangeH_M-->totalperAccOverdue VAL-->'+totalPerAccOverdueVal);
        if(typeof totalPerAccOverdueVal === 'NaN'){
            component.find("tperAccOverdue").set("v.value",0);    
        }
        
        
        
    },
    
    onCollectionListChangeH : function(component, event) {
        
        var tsmVal = component.find("colList").get("v.value");
        var accOverdueVal = component.find("accOverdueLst").get("v.value");
        if(! $A.util.isUndefinedOrNull(tsmVal) && tsmVal != ''){
            if(! $A.util.isUndefinedOrNull(accOverdueVal) && accOverdueVal != ''){
                component.find("perLstOverdue").set("v.value", (accOverdueVal / tsmVal) );     
            }else{
                component.find("perLstOverdue").set("v.value", 0 );      
            }
            
        }else{
            component.find("perLstOverdue").set("v.value", 0 );     
        }
        
        
        var tsmVal2 = component.find("colList2").get("v.value");
        var accOverdueVal2 = component.find("accOverdueLst2").get("v.value");
        if(! $A.util.isUndefinedOrNull(tsmVal2) && tsmVal2 != ''){
            if(! $A.util.isUndefinedOrNull(accOverdueVal2) && accOverdueVal2 != ''){
                component.find("perLstOverdue2").set("v.value", (accOverdueVal2 / tsmVal2) );     
            }else{
                component.find("perLstOverdue2").set("v.value", 0 );      
            }
            
        }else{
            component.find("perLstOverdue2").set("v.value", 0 );     
        }
        
        component.find("tcolList").set("v.value", ( ($A.util.isEmpty(tsmVal)) ? parseFloat(0) : parseFloat(tsmVal))  + (($A.util.isEmpty(tsmVal2)) ? parseFloat(0) : parseFloat(tsmVal2)) );            
        
        var totalColList = component.find("tcolList").get("v.value"); 
        var totalAccOverdueList = component.find("taccOverdueLst").get("v.value");
        component.find("tperLstOverdue").set("v.value", ( ($A.util.isEmpty(totalAccOverdueList)) ? parseFloat(0) : parseFloat(totalAccOverdueList))  / (($A.util.isEmpty(totalColList)) ? parseFloat(0) : parseFloat(totalColList)) );      
        
    },
    onAccOverdueListChangeH : function(component, event) {
        
        var tsmVal = component.find("colList").get("v.value");
        var accOverdueVal = component.find("accOverdueLst").get("v.value");
        if(! $A.util.isUndefinedOrNull(accOverdueVal) && accOverdueVal != ''){
            if(! $A.util.isUndefinedOrNull(tsmVal) && tsmVal != ''){
                component.find("perLstOverdue").set("v.value", (accOverdueVal / tsmVal) );     
            }else{
                component.find("perLstOverdue").set("v.value", 0 );      
            }
            
        }else{
            component.find("perAccOverdue").set("v.value", 0 );     
        }
        
        var tsmVal2 = component.find("colList2").get("v.value");
        var accOverdueVal2 = component.find("accOverdueLst2").get("v.value");
        if(! $A.util.isUndefinedOrNull(accOverdueVal2) && accOverdueVal2 != ''){
            if(! $A.util.isUndefinedOrNull(tsmVal2) && tsmVal2 != ''){
                component.find("perLstOverdue2").set("v.value", (accOverdueVal2 / tsmVal2) );     
            }else{
                component.find("perLstOverdue2").set("v.value", 0 );      
            }
            
        }else{
            component.find("perLstOverdue2").set("v.value", 0 );     
        }
        
        component.find("taccOverdueLst").set("v.value", ( ($A.util.isEmpty(accOverdueVal2)) ? parseFloat(0) : parseFloat(accOverdueVal2))  + (($A.util.isEmpty(accOverdueVal)) ? parseFloat(0) : parseFloat(accOverdueVal)) );            
        
        var totalColList = component.find("tcolList").get("v.value"); 
        var totalAccOverdueList = component.find("taccOverdueLst").get("v.value");
        component.find("tperLstOverdue").set("v.value", ( ($A.util.isEmpty(totalAccOverdueList)) ? parseFloat(0) : parseFloat(totalAccOverdueList))  / (($A.util.isEmpty(totalColList)) ? parseFloat(0) : parseFloat(totalColList)) );      
    },
    onGrossSalesChangeH : function(component, event) {
        
        
        
        var gs1 = component.find("grossSales").get("v.value");
        var gs2 = component.find("grossSales2").get("v.value");
        
        component.find("tgrossSales").set("v.value", ( ($A.util.isEmpty(gs1)) ? parseFloat(0) : parseFloat(gs1))  + (($A.util.isEmpty(gs2)) ? parseFloat(0) : parseFloat(gs2)) );     
        
        
    },
    onGRNValChangeH : function(component, event) {
        var gs1 = component.find("grnValue").get("v.value");
        var gs2 = component.find("grnValue2").get("v.value");
        
        component.find("tgrnValue").set("v.value", ( ($A.util.isEmpty(gs1)) ? parseFloat(0) : parseFloat(gs1))  + (($A.util.isEmpty(gs2)) ? parseFloat(0) : parseFloat(gs2)) );       
    },
    
    onMaxLmtChangeH : function(component, event) {
        var gs1 = component.find("maxLimit").get("v.value");
        var gs2 = component.find("maxLimit2").get("v.value");
        
        component.find("tmaxLimit").set("v.value", ( ($A.util.isEmpty(gs1)) ? parseFloat(0) : parseFloat(gs1))  + (($A.util.isEmpty(gs2)) ? parseFloat(0) : parseFloat(gs2)) );       
    },
    
    
    uploadHelper: function(component, event) {   
        component.set("v.showLoadingSpinner", true);
        //[return array of files]
        var fileInput = component.find("fileId").get("v.files");
        // get the first file using array index[0]  
        var file = fileInput[0];
        var self = this;
        // check the selected file size, if select file size greter then MAX_FILE_SIZE,
        // then show a alert msg to user,hide the loading spinner and return from function  
        if (file.size > self.MAX_FILE_SIZE) {
            component.set("v.showLoadingSpinner", false);
            component.set("v.fileName", 'Alert : File size cannot exceed ' + self.MAX_FILE_SIZE + ' bytes.\n' + ' Selected file size: ' + file.size);
            return;
        }
        
        // create a FileReader object 
        var objFileReader = new FileReader();
        // set onload function of FileReader object   
        objFileReader.onload = $A.getCallback(function() {
            var fileContents = objFileReader.result;
            var base64 = 'base64,';
            var dataStart = fileContents.indexOf(base64) + base64.length;
            
            fileContents = fileContents.substring(dataStart);
            // call the uploadProcess method 
            self.uploadProcess(component, file, fileContents);
        });
        
        objFileReader.readAsDataURL(file);
    },
    
    uploadProcess: function(component, file, fileContents) {
        // set a default size or startpostiton as 0 
        var startPosition = 0;
        // calculate the end size or endPostion using Math.min() function which is return the min. value   
        var endPosition = Math.min(fileContents.length, startPosition + this.CHUNK_SIZE);
        
        // start with the initial chunk, and set the attachId(last parameter)is null in begin
        this.uploadInChunk(component, file, fileContents, startPosition, endPosition, '');
    },
    
    
    uploadInChunk: function(component, file, fileContents, startPosition, endPosition, attachId) {
        // call the apex method 'saveChunk'
        var getchunk = fileContents.substring(startPosition, endPosition);
        var action = component.get("c.saveChunk");
        action.setParams({
            parentId: component.get("v.accountId"),
            fileName: file.name,
            base64Data: encodeURIComponent(getchunk),
            contentType: file.type,
            fileId: attachId
        });
        
        // set call back 
        action.setCallback(this, function(response) {
            // store the response / Attachment Id   
            attachId = response.getReturnValue();
            var state = response.getState();
            if (state === "SUCCESS") {
                // update the start position with end postion
                startPosition = endPosition;
                endPosition = Math.min(fileContents.length, startPosition + this.CHUNK_SIZE);
                // check if the start postion is still less then end postion 
                // then call again 'uploadInChunk' method , 
                // else, diaply alert msg and hide the loading spinner
                if (startPosition < endPosition) {
                    this.uploadInChunk(component, file, fileContents, startPosition, endPosition, attachId);
                } else {
                    alert('your File is uploaded successfully');
                    component.set("v.showLoadingSpinner", false);
                }
                // handel the response errors        
            } else if (state === "INCOMPLETE") {
                alert("From server: " + response.getReturnValue());
            } else if (state === "ERROR") {
                var errors = response.getError();
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        console.log("Error message: " + errors[0].message);
                    }
                } else {
                    console.log("Unknown error");
                }
            }
        });
        // enqueue the action
        $A.enqueueAction(action);
    }
})
({
    salesDistrictPKVLChange : function(component, event, helper) {
        //console.log("old value: " + event.getParam("oldValue"));
        //console.log("current value: " + event.getParam("value"));
        var fetchedPKVL = event.getParam("value");
        var filteredValues = [];
        if(fetchedPKVL){
            for(var i = 0; i < fetchedPKVL.length; i++){
                if(fetchedPKVL[i].startsWith("D0") || fetchedPKVL[i].startsWith("D1")){
                    //Since SalesDistrict which starts with value "D0" is for Domestic.
                    //console.log("VALS-->"+fetchedPKVL[i]);
                    filteredValues.push(fetchedPKVL[i]);
                    
                }
            }
        }
        //console.log("FILTERED  VAL-->"+JSON.stringify(filteredValues));
        component.set("v.filteredSalesDistrictPKVL",filteredValues);
        //console.log("FILTERED SALESDISTRICT VAL-->"+JSON.stringify(component.set("v.filteredSalesDistrictPKVL")));
    },
    onCusType1Change : function(component, event, helper) {
        var sopRow1Custype = component.find("cusType1").get("v.value");
        var sopRow2Custype = component.find("cusType2").get("v.value");
        if(sopRow1Custype == 'Non-Bundled' && (! $A.util.isUndefinedOrNull(sopRow2Custype) && sopRow2Custype != '')){
            component.find("cusType2").set("v.value","Bundled");
        }else if(sopRow1Custype == 'Bundled' && (! $A.util.isUndefinedOrNull(sopRow2Custype) && sopRow2Custype != '')){
            component.find("cusType2").set("v.value","Non-Bundled"); 
        }else{
            
        }
        
        //component.set("v.acc.Delivery_Priority__c",component.find("delPriority").get("v.value"));
    },
    onCusType2Change : function(component, event, helper) {
        var sopRow2Custype = component.find("cusType2").get("v.value");
        var sopRow1Custype = component.find("cusType1").get("v.value");
        if(sopRow2Custype == 'Non-Bundled' && (! $A.util.isUndefinedOrNull(sopRow1Custype) && sopRow1Custype != '')){
            component.find("cusType1").set("v.value","Bundled");
        }else if(sopRow2Custype == 'Bundled' && (! $A.util.isUndefinedOrNull(sopRow1Custype) && sopRow1Custype != '')){
            component.find("cusType1").set("v.value","Non-Bundled"); 
        }else{
            
        }
    },
    
    onTotalCusMapChange : function(component, event, helper) {
        helper.onTotalCusMapChangeH(component,event);
        
    },
    OnGrnAndGrossSales1Change : function(component, event, helper) {
        var grossSales1 = component.find("grossSales").get("v.value"); 
        var grnValue1 = component.find("grnValue").get("v.value");
        if(!$A.util.isUndefinedOrNull(grossSales1) && !$A.util.isUndefinedOrNull(grnValue1)){
            var newMaxLimit = grnValue1 / grossSales1;
            if(newMaxLimit <= 0.07){
                component.find("maxLimit").set("v.value",newMaxLimit); 
            }else{
                alert("Calculated limit is "+(newMaxLimit*100)+ '% which is greater than max limit, So please enter correct values.');
                component.find("grossSales").set("v.value",''); 
                component.find("grnValue").set("v.value",''); 
                component.find("maxLimit").set("v.value",''); 
            }
            
        }                                  
        helper.onGrossSalesChangeH(component,event);
        helper.onGRNValChangeH(component,event);
        helper.onMaxLmtChangeH(component,event);
    },
    OnGrnAndGrossSales2Change : function(component, event, helper) {
        console.log("In gorss2");
        var grossSales2 = component.find("grossSales2").get("v.value"); 
        var grnValue2 = component.find("grnValue2").get("v.value");
        if(!$A.util.isUndefinedOrNull(grossSales2) && !$A.util.isUndefinedOrNull(grnValue2)){
            var newMaxLimit2 = grnValue2 / grossSales2;
            console.log("newMaxLimit2 VAL-->"+newMaxLimit2);
            if(newMaxLimit2 <= 0.07){
                component.find("maxLimit2").set("v.value",newMaxLimit2); 
            }else{
                alert("Calculated limit is "+(newMaxLimit2*100)+ '% which is greater than max limit, So please enter correct values.');
                component.find("grossSales2").set("v.value",''); 
                component.find("grnValue2").set("v.value",''); 
                component.find("maxLimit2").set("v.value",''); 
            }
            
        }                                  
        helper.onGrossSalesChangeH(component,event);
        helper.onGRNValChangeH(component,event);
        helper.onMaxLmtChangeH(component,event);
    },
    onAccOverdueChange : function(component, event, helper) {
        helper.onAccOverdueChangeH(component,event);
    },
    
    onCollectionListChange : function(component, event, helper) {
        helper.onCollectionListChangeH(component,event);
        
    },
    onAccOverdueListChange : function(component, event, helper) {
        helper.onAccOverdueListChangeH(component,event);
    },
    onGrossSalesChange : function(component, event, helper) {
        helper.onGrossSalesChangeH(component,event);       
        
        
    },
    onGRNValChange : function(component, event, helper) {
        helper.onGRNValChangeH(component,event); 
    },
    
    onMaxLmtChange : function(component, event, helper) {
        helper.onMaxLmtChangeH(component,event);
    },
    
    handleFilesChange: function(component, event, helper) {
        var fileName = 'No File Selected..';
        if (event.getSource().get("v.files").length > 0) {
            fileName = event.getSource().get("v.files")[0]['name'];
        }
        component.set("v.fileName", fileName);
    },
    doInit : function(component, event, helper) {
        console.log("In AccBranchComp-->C-->In doInit_M!!");
        helper.showSpinner(component, event);
        component.set('v.columns', [
            {label: 'Employee Code', fieldName: 'employeeCode', type: 'text',sortable:false },
            {label: 'Employee Name', fieldName: 'employeeName', type: 'text',sortable:false },
            {label: 'Designation', fieldName: 'designation', type: 'text',sortable:false},
            {label: 'No. of Customer Mapped in SAP', fieldName: 'customerMapped', type: 'text'},
            {label: 'No. of Account Overdue', fieldName: 'accOverdue', type: 'text'}
            
        ]);	
        
        var acctID = component.get("v.accountId");
        console.log("In doInit-->ACC ID-->"+acctID);
        var action = component.get("c.getAccount");
        action.setParams({
            "accId" : acctID
        });
        action.setCallback(this,function(response){
            var state = response.getState() ;
            if(state === 'SUCCESS'){
                helper.hideSpinner(component, event);
                var retVal =  response.getReturnValue();
                //console.log('ZZ Return Val-->'+JSON.stringify(retVal));                
                component.set("v.acc",retVal);
                
                var branchLocationValue = component.get("v.acc.Branch__c");
                console.log('In AccBrnchFormComp-->C-->doInit_M-->AccBranchLoc VAL-->'+JSON.stringify(branchLocationValue));
                
                if(branchLocationValue){
                    helper.fetchBranchLocationData(component, event);
                }else{
                   console.log('In AccBrnchFormComp-->C-->doInit_M-->Accounts BranchLocation is "EMPTY"!!'); 
                }
                //var empData = {employeeCode:"ABC123",employeeName:retVal.Owner.Name,designation:"MEE",customerMapped:"13",accOverdue:"2"};
                
                var empData = retVal;
                /*
                empData.employeeCode='ABC123';
                empData.employeeName='SAM';
                empData.designation='MEE';
                empData.customerMapped='13';
                empData.accOverdue='2';*/
                
                
                if(empData.Owner.UserRole){
                    empData.designation = empData.Owner.UserRole.Name;
                }else{
                    empData.designation  = 'N/A';
                } 
                
                if(empData.Owner){
                    empData.employeeName = empData.Owner.Name;
                }else {
                    empData.employeeName = 'N/A';
                }    
                
                empData.employeeCode = 'ABC123';
                empData.customerMapped='13';
                empData.accOverdue = '3';
                
                
                //console.log("ZZZZZZZZZZZZ-------->"+JSON.stringify(empData));
                component.set("v.data",empData);
                
                var bundledType = component.get("v.acc.SOP_B_Customer_Type__c");
                var nonbundledType = component.get("v.acc.SOP_NB_Customer_Type__c");
                
                if(! $A.util.isUndefinedOrNull(bundledType) && (bundledType != '') ){
                    component.set("v.disableBCustomerType",true);
                    component.find("cusType1").set("v.value",bundledType);
                    component.find("totalCusMapped").set("v.value",component.get("v.acc.SOP_B_Total_Customer_Mapped__c"));
                    component.find("accOverdue").set("v.value",component.get("v.acc.SOP_B_Account_Overdue__c"));
                    component.find("perAccOverdue").set("v.value",component.get("v.acc.SOP_B_Percentage_Of_Overdue__c"));
                    component.find("colList").set("v.value",component.get("v.acc.SOP_B_Collection_List__c"));
                    component.find("accOverdueLst").set("v.value",component.get("v.acc.SOP_B_Overdue_Account_List__c"));
                    component.find("perLstOverdue").set("v.value",component.get("v.acc.SOP_B_Percentage_Of_List_Overdue__c"));
                    component.find("grossSales").set("v.value",component.get("v.acc.SOP_B_Gross_Sales__c"));
                    component.find("grnValue").set("v.value",component.get("v.acc.SOP_B_GRN_Value__c"));
                    component.find("maxLimit").set("v.value",component.get("v.acc.SOP_B_Percentage_Max_Limit__c"));
                }
                
                if(! $A.util.isUndefinedOrNull(nonbundledType) && (bundledType != '') ){
                    component.set("v.disableNBCustomerType",true);
                    component.find("cusType2").set("v.value",nonbundledType);
                    component.find("totalCusMapped2").set("v.value",component.get("v.acc.SOP_NB_Total_Customer_Mapped__c"));
                    component.find("accOverdue2").set("v.value",component.get("v.acc.SOP_NB_Account_Overdue__c"));
                    component.find("perAccOverdue2").set("v.value",component.get("v.acc.SOP_NB_Percentage_Of_Overdue__c"));
                    component.find("colList2").set("v.value",component.get("v.acc.SOP_NB_Collection_List__c"));
                    component.find("accOverdueLst2").set("v.value",component.get("v.acc.SOP_NB_Overdue_Account_List__c"));
                    component.find("perLstOverdue2").set("v.value",component.get("v.acc.SOP_NB_Percentage_Of_List_Overdue__c"));
                    component.find("grossSales2").set("v.value",component.get("v.acc.SOP_NB_Gross_Sales__c"));
                    component.find("grnValue2").set("v.value",component.get("v.acc.SOP_NB_GRN_Value__c"));
                    component.find("maxLimit2").set("v.value",component.get("v.acc.SOP_NB_Percentage_Max_Limit__c"));
                }
                //console.log("ZZZZZZZZZZZZ B VAL-------->"+JSON.stringify(component.get("v.acc.SOP_B_Customer_Type__c")));
                //console.log("ZZZZZZZZZZZZ NB VAL-------->"+JSON.stringify(component.get("v.acc.SOP_NB_Customer_Type__c")));
                //component.set("v.cusType1",component.get("v.acc.SOP_B_Customer_Type__c"));
                //component.set("v.cusType2",component.get("v.acc.SOP_NB_Customer_Type__c"));
                
                //console.log("ZZZZZZZZZZZZ cusType1 Node VAL-------->"+component.find("cusType1").get("v.value"));
                //console.log("ZZZZZZZZZZZZ cusType2 Node VAL-------->"+component.find("cusType2").get("v.value"));
                
                
                component.set("v.distChan",component.get("v.acc.Distributor_Channel__c"));
                component.set("v.cusAccGrp",component.get("v.acc.Customer_Account_Group__c"));
                component.set("v.cusGrp",component.get("v.acc.Customer_Group__c"));
                component.set("v.delPriority",component.get("v.acc.Delivery_Priority__c"));
                component.set("v.indKey",component.get("v.acc.Industry_Key__c"));
                component.set("v.termPayKey",component.get("v.acc.Terms_Of_Payment_Key__c"));
                component.set("v.subStatus",component.get("v.acc.Sub_Status__c"));
                component.set("v.salesDistrict",component.get("v.acc.Sales_District__c"));
                component.set("v.delPlant",component.get("v.acc.Delivering_Plant__c"));
                component.set("v.regionCode",component.get("v.acc.Region_Code__c"));
                
                
                helper.onTotalCusMapChangeH(component, event);
                helper.onAccOverdueChangeH(component, event);
                helper.onCollectionListChangeH(component, event);
                helper.onAccOverdueListChangeH(component, event);
                helper.onGrossSalesChangeH(component, event);
                helper.onGRNValChangeH(component, event);
                helper.onMaxLmtChangeH(component, event);
                
                
            }else{
                helper.hideSpinner(component,event);
                alert('Error-->'+JSON.stringify(response.getError()));
            }
        });
        $A.enqueueAction(action);	
        
        //$A.enqueueAction(component.get('c.onTotalCusMapChange'));
        
        
    },
    handleIdChange : function(component, event, helper) {
        console.log("numItems has changed");
        console.log("old value: " + event.getParam("oldValue"));
        console.log("current value: " + event.getParam("value"));
        component.set("v.accountId",event.getParam("value"));
        this.doInit(component, event, helper);
    },
    saveAccDet : function(component, event, helper) {
        helper.showSpinner(component, event);
        //console.log('In AccBrnchFormComp-->C-->saveAccDet_M !!');
        //var accName = component.find("chkBx").get();
        component.set("v.acc.Sub_Status__c","Submitted To Approver 2"); // Setting Sub Status to Approver 2 which triggers process builder and auto submits to approval process
        component.set("v.acc.Distributor_Channel__c",component.find("distChan").get("v.value"));
        // component.set("v.acc.Customer_Account_Group__c",component.find("cusAccGrp").get("v.value")); // deleted from comp
        component.set("v.acc.Customer_Group__c",component.find("cusGrp").get("v.value"));        
        component.set("v.acc.Industry_Key__c",component.find("indKey").get("v.value"));
        component.set("v.acc.Terms_Of_Payment_Key__c",component.find("termPayKey").get("v.value"));
        // component.set("v.acc.Delivery_Priority__c",component.find("delPriority").get("v.value")); // deleted from comp
        component.set("v.acc.Sales_District__c",component.find("sDis").get("v.value"));
        component.set("v.acc.Delivering_Plant__c",component.find("deliveryPlant").get("v.value"));
        component.set("v.acc.Region_Code__c",component.find("regCode").get("v.value"));
        //console.log('In AccBrnchFormComp-->C-->saveAccDet_M-->FINAL AccVAL-->'+JSON.stringify(component.get("v.acc")));
        
        
        var allRequiredFieldsFilled = helper.checkBranchFormMandatoryFields(component,event);
        //console.log('In AccBrnchFormComp-->C-->saveAccDet_M-->allRequiredFieldsFilled-->'+allRequiredFieldsFilled);
        if(allRequiredFieldsFilled){
            
            
            var sopRow1Custype = component.find("cusType1").get("v.value");
            var sopRow2Custype = component.find("cusType2").get("v.value");
            
            component.set("v.acc.SOP_B_Customer_Type__c",sopRow1Custype);
            component.set("v.acc.SOP_NB_Customer_Type__c",sopRow2Custype);
            
            if(sopRow1Custype == 'Non-Bundled' && sopRow2Custype == 'Bundled'){	
                
                component.set("v.acc.SOP_NB_Customer_Type__c",component.find("cusType1").get("v.value"));
                component.set("v.acc.SOP_NB_Total_Customer_Mapped__c",component.find("totalCusMapped").get("v.value"));
                component.set("v.acc.SOP_NB_Account_Overdue__c",component.find("accOverdue").get("v.value"));
                component.set("v.acc.SOP_NB_Percentage_Of_Overdue__c",component.find("perAccOverdue").get("v.value"));
                component.set("v.acc.SOP_NB_Collection_List__c",component.find("colList").get("v.value"));
                component.set("v.acc.SOP_NB_Overdue_Account_List__c",component.find("accOverdueLst").get("v.value"));
                component.set("v.acc.SOP_NB_Percentage_Of_List_Overdue__c",component.find("perLstOverdue").get("v.value"));
                component.set("v.acc.SOP_NB_Gross_Sales__c",component.find("grossSales").get("v.value"));
                component.set("v.acc.SOP_NB_GRN_Value__c",component.find("grnValue").get("v.value"));
                component.set("v.acc.SOP_NB_Percentage_Max_Limit__c",component.find("maxLimit").get("v.value"));
                
                component.set("v.acc.SOP_B_Customer_Type__c",component.find("cusType2").get("v.value"));
                component.set("v.acc.SOP_B_Total_Customer_Mapped__c",component.find("totalCusMapped2").get("v.value"));
                component.set("v.acc.SOP_B_Account_Overdue__c",component.find("accOverdue2").get("v.value"));
                component.set("v.acc.SOP_B_Percentage_Of_Overdue__c",component.find("perAccOverdue2").get("v.value"));
                component.set("v.acc.SOP_B_Collection_List__c",component.find("colList2").get("v.value"));
                component.set("v.acc.SOP_B_Overdue_Account_List__c",component.find("accOverdueLst2").get("v.value"));
                component.set("v.acc.SOP_B_Percentage_Of_List_Overdue__c",component.find("perLstOverdue2").get("v.value"));
                component.set("v.acc.SOP_B_Gross_Sales__c",component.find("grossSales2").get("v.value"));
                component.set("v.acc.SOP_B_GRN_Value__c",component.find("grnValue2").get("v.value"));
                component.set("v.acc.SOP_B_Percentage_Max_Limit__c",component.find("maxLimit2").get("v.value"));
                
            }
            
            if(sopRow1Custype == 'Bundled' && sopRow2Custype == 'Non-Bundled'){
                component.set("v.acc.SOP_B_Customer_Type__c",component.find("cusType1").get("v.value"));
                component.set("v.acc.SOP_B_Total_Customer_Mapped__c",component.find("totalCusMapped").get("v.value"));
                component.set("v.acc.SOP_B_Account_Overdue__c",component.find("accOverdue").get("v.value"));
                component.set("v.acc.SOP_B_Percentage_Of_Overdue__c",component.find("perAccOverdue").get("v.value"));
                component.set("v.acc.SOP_B_Collection_List__c",component.find("colList").get("v.value"));
                component.set("v.acc.SOP_B_Overdue_Account_List__c",component.find("accOverdueLst").get("v.value"));
                component.set("v.acc.SOP_B_Percentage_Of_List_Overdue__c",component.find("perLstOverdue").get("v.value"));
                component.set("v.acc.SOP_B_Gross_Sales__c",component.find("grossSales").get("v.value"));
                component.set("v.acc.SOP_B_GRN_Value__c",component.find("grnValue").get("v.value"));
                component.set("v.acc.SOP_B_Percentage_Max_Limit__c",component.find("maxLimit").get("v.value"));
                
                component.set("v.acc.SOP_NB_Customer_Type__c",component.find("cusType2").get("v.value"));
                component.set("v.acc.SOP_NB_Total_Customer_Mapped__c",component.find("totalCusMapped2").get("v.value"));
                component.set("v.acc.SOP_NB_Account_Overdue__c",component.find("accOverdue2").get("v.value"));
                component.set("v.acc.SOP_NB_Percentage_Of_Overdue__c",component.find("perAccOverdue2").get("v.value"));
                component.set("v.acc.SOP_NB_Collection_List__c",component.find("colList2").get("v.value"));
                component.set("v.acc.SOP_NB_Overdue_Account_List__c",component.find("accOverdueLst2").get("v.value"));
                component.set("v.acc.SOP_NB_Percentage_Of_List_Overdue__c",component.find("perLstOverdue2").get("v.value"));
                component.set("v.acc.SOP_NB_Gross_Sales__c",component.find("grossSales2").get("v.value"));
                component.set("v.acc.SOP_NB_GRN_Value__c",component.find("grnValue2").get("v.value"));
                component.set("v.acc.SOP_NB_Percentage_Max_Limit__c",component.find("maxLimit2").get("v.value"));
                
            }
            
            
            
            //console.log('In AccBrnchFormComp-->C-->saveAccDet_M-->FINAL AccVAL-->'+JSON.stringify(component.get("v.acc")));
            var action = component.get("c.saveAccount");
            action.setParams({
                acc :  component.get("v.acc")
            });
            action.setCallback(this,function(response){
                var state = response.getState() ;
                if(state === 'SUCCESS'){
                    helper.hideSpinner(component, event);
                    console.log('SUCCESS SAVE!!');
                    alert('Record Has been Updated Successfully');
                    helper.gotoThankYouPage(component, event);  
                    //helper.goToThankyouComp(component, event);  
                    
                    // var retVal =  response.getReturnValue();
                    console.log('SUCCESS SAVE!!');
                    // component.set("v.acc",retVal);
                }else if(state === 'ERROR'){
                    helper.hideSpinner(component, event);
                    let errorMsg = response.getError();
                    console.log("ZZ ERROR While Saving BranchForm-->"+JSON.stringify(errorMsg));
                    alert(JSON.stringify(errorMsg));
                }
                
            });
            $A.enqueueAction(action); 
            
            if (component.find("fileId").get("v.files").length > 0) {
                helper.uploadHelper(component, event);
            } else {
                //alert('Please Select a Valid File');
                console.log("No File Attached!!");
            }    
        }else{
            helper.hideSpinner(component, event);
            alert('Please fill all the required fields on page!');
            
            
        }
        
        
    }
})
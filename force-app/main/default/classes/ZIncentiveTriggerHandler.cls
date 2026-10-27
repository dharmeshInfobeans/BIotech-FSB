public class ZIncentiveTriggerHandler{ 
    public  void beforeInsertHandler(List<Z_Incentive__c> newLstZincentives){
        List<Product__c> prodLst = new List<Product__c>();
        List<Account> accLst = new List<Account>();
        Map<String, List<Z_Incentive__c>> prodCodeZInctLstMap = new Map<String, List<Z_Incentive__c>>();
        List<Z_Incentive__c> zInctLstForProd = new List<Z_Incentive__c>();
        Map<String, List<Z_Incentive__c>> customerZInctLstMap = new Map<String, List<Z_Incentive__c>>();
        List<Z_Incentive__c> zInctLstForAcc = new List<Z_Incentive__c>();
        Set<Id> setAccountId = new Set<Id>();
        Set<String> userEmpIdSet = new Set<String>();
        Map<String,User> empUser = new Map<String,User>();
        String salesEmployeeEmpCode, divMngrEmpCode, salesSpecilalistEmpCode, salesEmployee, divmanagers, salesSpecialist, days, sellingRate, quantity, netValue;
        List<Master_Agreement__c> masterAgreementList = new List<Master_Agreement__c>();       
        map<Id, List<Master_Agreement__c>> mapAccId_MasterAgreement = new map<Id, List<Master_Agreement__c>>(); 
        
        for(Z_Incentive__c inc:newLstZincentives){
            //Create map of dummy prodyct code and list of z inct
            if(prodCodeZInctLstMap.containsKey(inc.Dummy_Product_Code__c)){
                zInctLstForProd = prodCodeZInctLstMap.get(inc.Dummy_Product_Code__c);
                zInctLstForProd.add(inc);
            }
            else{
                zInctLstForProd = new List<Z_Incentive__c>();
                zInctLstForProd.add(inc);
                prodCodeZInctLstMap.put(inc.Dummy_Product_Code__c,zInctLstForProd);
            }
            //Create map of account sap code and list of z inct
            if(customerZInctLstMap.containsKey(inc.Customer__c)){
                zInctLstForAcc = customerZInctLstMap.get(inc.Customer__c);
                zInctLstForAcc.add(inc);
            }
            else{
                zInctLstForAcc = new List<Z_Incentive__c>();
                zInctLstForAcc.add(inc);
                customerZInctLstMap.put(inc.Customer__c,zInctLstForAcc);
            }
            //Update finacial year on z inct depending on AWB date
            if(inc.AWB_Date__c != null){
                inc.Financial_Year__c = getFiscalYear(inc.AWB_Date__c); 
            }
            //Update no. of days field from days field
            if(String.isNotBlank(inc.Days__c) && inc.Days__c.startsWith('-')){
                inc.No_Of_Days__c = Decimal.valueOf(inc.Days__c);
            }
            else if(String.isNotBlank(inc.Days__c) && inc.Days__c.contains('-')){
                days = inc.Days__c.substringBefore('-');
                days = '-'+days;
                inc.No_Of_Days__c = Decimal.valueOf(days);
            }
            else if(String.isNotBlank(inc.Days__c) && inc.Days__c.isNumeric()){
                inc.No_Of_Days__c = Decimal.valueOf(inc.Days__c);
            }
            else{
                inc.No_Of_Days__c = 0;
            }
            //Update selling rate field from selling rate text field
            if(String.isNotBlank(inc.Selling_Rate_Txt__c)){
                if(inc.Selling_Rate_Txt__c.startsWith('-')){
                    inc.Selling_Rate_DOM__c = Decimal.valueOf(inc.Selling_Rate_Txt__c);
                }
                else if(inc.Selling_Rate_Txt__c.contains('-')){
                    sellingRate = inc.Selling_Rate_Txt__c.substringBefore('-');
                    sellingRate = '-'+sellingRate;
                    inc.Selling_Rate_DOM__c = Decimal.valueOf(sellingRate);
                }
                else{
                    inc.Selling_Rate_DOM__c = Decimal.valueOf(inc.Selling_Rate_Txt__c);
                }
            }
            //Udate quantity__c field from quantity text field
            if(String.isNotBlank(inc.Quantity_Txt__c)){
                if(inc.Quantity_Txt__c.startsWith('-')){
                   inc.Quantity__c = Decimal.valueOf(inc.Quantity_Txt__c); 
                }
                else if(inc.Quantity_Txt__c.contains('-')){
                    quantity = inc.Quantity_Txt__c.substringBefore('-');
                    quantity = '-'+quantity;
                    inc.Quantity__c = Decimal.valueOf(quantity);
                }
                else{
                    inc.Quantity__c = Decimal.valueOf(inc.Quantity_Txt__c);
                }
            }
            //Udate net value item field from net value text field
            if(String.isNotBlank(inc.Net_Value_Txt__c)){
                if(inc.Net_Value_Txt__c.startsWith('-')){
                     inc.Net_Value_Item__c = Decimal.valueOf(inc.Net_Value_Txt__c);
                }
                else if(inc.Net_Value_Txt__c.contains('-')){
                    netValue = inc.Net_Value_Txt__c.substringBefore('-');
                    netValue = '-'+netValue;
                    inc.Net_Value_Item__c = Decimal.valueOf(netValue);
                }
                else{
                    inc.Net_Value_Item__c = Decimal.valueOf(inc.Net_Value_Txt__c);
                }
            }
        }
        if(!prodCodeZInctLstMap.isEmpty()){
            prodLst = [SELECT ID, Dummy_Product_Code__c,Division__c FROM Product__c where Dummy_Product_Code__c in :prodCodeZInctLstMap.keySet()];
        }
        
        //Update product lookup depending on dummy product code
        if(!prodLst.isEmpty()){
            for(Product__c prod : prodLst){
                for(Z_Incentive__c zInctToInsert : prodCodeZInctLstMap.get(prod.Dummy_Product_Code__c)){
                    zInctToInsert.Product__c = prod.Id;
                    zInctToInsert.Prod_Division__c = prod.Division__c;
                    zInctToInsert.Product__r = prod;
                    system.debug('zInctToInsert.Product__c**'+zInctToInsert.Product__c);
                    system.debug('zInctToInsert.Product__c div**'+zInctToInsert.Prod_Division__c);
                }
            } 
        }
        if(!customerZInctLstMap.isEmpty()){
            accLst = [SELECT ID, SAP_Code__c,Payment_Collection_Cycle__c FROM Account where SAP_Code__c in :customerZInctLstMap.keySet()];
        }
        
        //Update account lookup depending on account sap code  
        if(!accLst.isEmpty()){
            for(Account acc : accLst){
                for(Z_Incentive__c zInctToInsert : customerZInctLstMap.get(acc.SAP_Code__c)){
                    zInctToInsert.Account__c = acc.ID;
                    setAccountId.add(zInctToInsert.Account__c);
                    zInctToInsert.Account__r = acc;
                    
                    //Update payment received withinh cycle check box based on z incentive's no of days and acccount payment collection cycle & z incentive's billing document status
                    if(acc.Payment_Collection_Cycle__c >= zInctToInsert.No_Of_Days__c && zInctToInsert.Billing_Document_Status__c == 'Closed By Payment'){
                        zInctToInsert.Payment_Received_Within_Cycle__c = true;
                    }
                }
            }
        }
        //Create set of user employee codes depending on product division
        for(Z_Incentive__c inc:newLstZincentives){
            userEmpIdSet.add(inc.RBM_RSM__c);
            userEmpIdSet.add(inc.ASM__c);
            userEmpIdSet.add(inc.ZBM__c);
            userEmpIdSet.add(inc.ZSM_Z1__c);
            userEmpIdSet.add(inc.Product_Manager_Emp_Code__c);
            userEmpIdSet.add(inc.Application_Specialist_Emp_Code__c);
            system.debug('product division '+inc.Prod_Division__c);
            
            salesEmployeeEmpCode =  inc.Prod_Division__c != null ? inc.Prod_Division__c  == 'I' ? inc.D1_Div_1_Sales_Employee__c : inc.Prod_Division__c == 'II' ? inc.D2_Div_2_Sales_Employee__c : inc.Prod_Division__c == 'III'? inc.D3_Div_3_Sales_Employee__c :  inc.Prod_Division__c == 'IV' ? inc.D4_Div_4_Sales_Employee__c : inc.Prod_Division__c == 'V'? inc.D5_Div_5_Sales_Employee__c:null : null;
            if(salesEmployeeEmpCode != null){
                userEmpIdSet.add(salesEmployeeEmpCode);  
            } 
            
            divMngrEmpCode = inc.Prod_Division__c != null ? inc.Prod_Division__c  == 'I' ? inc.M1_Div_1_Manager__c : inc.Prod_Division__c == 'II' ? inc.M2_Div_2_Manager__c : inc.Prod_Division__c == 'III'? inc.M3_Div_3_Manager__c :  inc.Prod_Division__c == 'IV' ? inc.M4_Div_4_Manager__c : inc.Prod_Division__c == 'V'? inc.M5_Div_5_Manager__c :null : null;
            if(divMngrEmpCode != null){
                userEmpIdSet.add(divMngrEmpCode); 
            } 
            
            salesSpecilalistEmpCode = inc.Prod_Division__c != null ? inc.Prod_Division__c  == 'I' ? inc.D1_Div_1_Sales_Specialist__c : inc.Prod_Division__c == 'II' ? inc.D2_Div_2_Sales_Specialist__c : inc.Prod_Division__c == 'III'? inc.D3_Div_3_Sales_Specialist__c :  inc.Prod_Division__c == 'IV' ? inc.D4_Div_4_Sales_Specialist__c : inc.Prod_Division__c == 'V'? inc.D5_Div_5_Sales_Specialist__c :null : null;  
            if(salesSpecilalistEmpCode != null){
                userEmpIdSet.add(salesSpecilalistEmpCode); 
            }   
        }
        //Create map of employee code and employee
        if(!userEmpIdSet.isEmpty()){
            for( User u : [SELECT ID,Employee_Code__c from User where Employee_Code__c in :userEmpIdSet])
            {
                empUser.put(u.Employee_Code__c,u);
            }  
        }  
        
        //Update user lookups
        for(Z_Incentive__c inc : newLstZincentives){
            salesEmployee =  inc.Prod_Division__c != null ? inc.Prod_Division__c  == 'I' ? inc.D1_Div_1_Sales_Employee__c : inc.Prod_Division__c == 'II' ? inc.D2_Div_2_Sales_Employee__c : inc.Prod_Division__c == 'III'? inc.D3_Div_3_Sales_Employee__c :  inc.Prod_Division__c == 'IV' ? inc.D4_Div_4_Sales_Employee__c : inc.Prod_Division__c == 'V'? inc.D5_Div_5_Sales_Employee__c:null : null;
            
            //Update sales employee lookup
            if(String.isNotBlank(salesEmployee) && empUser.containsKey(salesEmployee)){
                inc.Sales_Employee__c = empUser.get(salesEmployee).Id;
            }
            
            divmanagers = inc.Prod_Division__c != null ? inc.Prod_Division__c  == 'I' ? inc.M1_Div_1_Manager__c : inc.Prod_Division__c == 'II' ? inc.M2_Div_2_Manager__c : inc.Prod_Division__c == 'III'? inc.M3_Div_3_Manager__c :  inc.Prod_Division__c == 'IV' ? inc.M4_Div_4_Manager__c : inc.Prod_Division__c == 'V'? inc.M5_Div_5_Manager__c :null : null;
            
            //Update div manager lookup
            if(String.isNotBlank(divmanagers) && empUser.containsKey(divmanagers)){
                inc.Div_Manager__c = empUser.get(divmanagers).Id;
            }
            
            salesSpecialist = inc.Prod_Division__c != null ? inc.Prod_Division__c  == 'I' ? inc.D1_Div_1_Sales_Specialist__c : inc.Prod_Division__c == 'II' ? inc.D2_Div_2_Sales_Specialist__c : inc.Prod_Division__c == 'III'? inc.D3_Div_3_Sales_Specialist__c :  inc.Prod_Division__c == 'IV' ? inc.D4_Div_4_Sales_Specialist__c : inc.Prod_Division__c == 'V'? inc.D5_Div_5_Sales_Specialist__c :null : null;
            
            //Update sales specialist lookup
            if(String.isNotBlank(salesSpecialist) && empUser.containsKey(salesSpecialist)){
                inc.Sales_Specialist__c = empUser.get(salesSpecialist).Id;                
            }
            if(String.isNotBlank(inc.ASM__c) && empUser.containsKey(inc.ASM__c)){
                inc.ASMs__c = empUser.get(inc.ASM__c).Id;                
            }
            if(String.isNotBlank(inc.RBM_RSM__c) && empUser.containsKey(inc.RBM_RSM__c)){
                inc.RSM__c = empUser.get(inc.RBM_RSM__c).Id;                
            }
            if(String.isNotBlank(inc.ZSM_Z1__c) && empUser.containsKey(inc.ZSM_Z1__c)){
                inc.ZSM__c = empUser.get(inc.ZSM_Z1__c).Id;                
            }
            if(String.isNotBlank(inc.ZBM__c) && empUser.containsKey(inc.ZBM__c)){
                inc.ZBMs__c = empUser.get(inc.ZBM__c).Id;                
            }
            if(String.isNotBlank(inc.Application_Specialist_Emp_Code__c) && empUser.containsKey(inc.Application_Specialist_Emp_Code__c)){
                inc.Application_Specialist__c = empUser.get(inc.Application_Specialist_Emp_Code__c).Id;                
            }
            if(String.isNotBlank(inc.Product_Manager_Emp_Code__c) && empUser.containsKey(inc.Product_Manager_Emp_Code__c)){
                inc.Product_Manager__c = empUser.get(inc.Product_Manager_Emp_Code__c).Id;                
            }
        }
        //CReate map of account and list of master agreements
        if(!setAccountId.isEmpty()){
            for(Master_Agreement__c masterAgreement : [SELECT Id, Account__c, Agreement_End_Date__c, Agreement_Start_Date__c, Credited_Period__c FROM
                                                       Master_Agreement__c WHERE Account__c in :setAccountId]){                
                                                           if(mapAccId_MasterAgreement.ContainsKey(masterAgreement.Account__c)){
                                                               masterAgreementList = mapAccId_MasterAgreement.get(masterAgreement.Account__c);
                                                               masterAgreementList.add(masterAgreement);
                                                           }else{
                                                               masterAgreementList = new List<Master_Agreement__c>();
                                                               masterAgreementList.add(masterAgreement);
                                                               mapAccId_MasterAgreement.put(masterAgreement.Account__c, masterAgreementList);               
                                                           }            
                                                       }  
        }
        //Update payment due date based on AWB date and valid agreement's credit period
        for(Z_Incentive__c zIncentive : newLstZincentives){
            if(mapAccId_MasterAgreement.ContainsKey(zIncentive.Account__c)){
                for(Master_Agreement__c masterAgreement : mapAccId_MasterAgreement.get(zIncentive.Account__c)){
                    if(zIncentive.AWB_Date__c != null && zIncentive.AWB_Date__c >= masterAgreement.Agreement_Start_Date__c && 
                       zIncentive.AWB_Date__c <= masterAgreement.Agreement_End_Date__c){
                           system.debug('masterAgreement.Credited_Period__c**'+masterAgreement.Credited_Period__c );
                           if(masterAgreement.Credited_Period__c != null){
                               zIncentive.Payment_Due_Date__c = zIncentive.AWB_Date__c.AddDays(Integer.valueOf(masterAgreement.Credited_Period__c));
                               //break;
                           }
                       }
                }
            }
        }
    } 
    
    public  void beforeUpdateHandler(List<Z_Incentive__c> newLstZincentives, map<Id, Z_Incentive__c> oldMapZIncentive){
        String days; 
        Set<String> userEmpIdSet = new Set<String>();
        Map<String,User> empUser = new Map<String,User>();
        
        for(Z_Incentive__c zInctToUpdate : newLstZincentives){            
            Z_Incentive__c oldZInct = oldMapZIncentive.get(zInctToUpdate.Id);
            
             //Update no. of days field from days field
            if(zInctToUpdate.Days__c != oldZInct.Days__c && String.isNotBlank(zInctToUpdate.Days__c)){
                if(zInctToUpdate.Days__c.startsWith('-')){
                    zInctToUpdate.No_Of_Days__c = Decimal.valueOf(zInctToUpdate.Days__c); 
                }
                else if(zInctToUpdate.Days__c.contains('-')){
                    days = zInctToUpdate.Days__c.substringBefore('-');
                    days = '-'+days;
                    zInctToUpdate.No_Of_Days__c = Decimal.valueOf(days); 
                }
                else if(zInctToUpdate.Days__c.isNumeric()){
                    zInctToUpdate.No_Of_Days__c = Decimal.valueOf(zInctToUpdate.Days__c);
                }
                else{
                    zInctToUpdate.No_Of_Days__c = 0;
                }
            }
            
            //Update payment received withinh cycle check box based on z incentive's no of days and acccount payment collection cycle 
            //& z incentive's billing document status
            if(((zInctToUpdate.No_Of_Days__c != oldZInct.No_Of_Days__c && oldZInct.No_Of_Days__c == null) || 
               zInctToUpdate.No_Of_Days__c != oldZInct.No_Of_Days__c) && zInctToUpdate.Billing_Document_Status__c == 'Closed By Payment'){
                   if(zInctToUpdate.Account_Payment_Collection_Cycle__c >= zInctToUpdate.No_Of_Days__c){
                       zInctToUpdate.Payment_Received_Within_Cycle__c = true;
                   }
                   else{
                       zInctToUpdate.Payment_Received_Within_Cycle__c = false;
                   } 
               }
             //Update finacial year on z inct depending on AWB date
            system.debug('zInctToUpdate.AWB_Date__c**'+zInctToUpdate.AWB_Date__c);
            if(zInctToUpdate.AWB_Date__c != null && zInctToUpdate.AWB_Date__c != oldZInct.AWB_Date__c){
                zInctToUpdate.Financial_Year__c = getFiscalYear(zInctToUpdate.AWB_Date__c); 
            }
            //Update user lookups
            if(zInctToUpdate.Prod_Division__c == 'I'){
                if(zInctToUpdate.D1_Div_1_Sales_Employee__c != oldZInct.D1_Div_1_Sales_Employee__c && String.isNotBlank(zInctToUpdate.D1_Div_1_Sales_Employee__c)){
                    userEmpIdSet.add(zInctToUpdate.D1_Div_1_Sales_Employee__c);
                }
                else if(zInctToUpdate.M1_Div_1_Manager__c != oldZInct.M1_Div_1_Manager__c && String.isNotBlank(zInctToUpdate.M1_Div_1_Manager__c)){
                    userEmpIdSet.add(zInctToUpdate.M1_Div_1_Manager__c);
                } 
                else if(zInctToUpdate.D1_Div_1_Sales_Specialist__c != oldZInct.D1_Div_1_Sales_Specialist__c && String.isNotBlank(zInctToUpdate.D1_Div_1_Sales_Specialist__c)){
                    userEmpIdSet.add(zInctToUpdate.D1_Div_1_Sales_Specialist__c);
                }                
            }
            else if(zInctToUpdate.Prod_Division__c == 'II'){
                if(zInctToUpdate.D2_Div_2_Sales_Employee__c != oldZInct.D2_Div_2_Sales_Employee__c && String.isNotBlank(zInctToUpdate.D2_Div_2_Sales_Employee__c)){
                    userEmpIdSet.add(zInctToUpdate.D2_Div_2_Sales_Employee__c);
                }
                else if(zInctToUpdate.M2_Div_2_Manager__c != oldZInct.M2_Div_2_Manager__c && String.isNotBlank(zInctToUpdate.M2_Div_2_Manager__c)){
                    userEmpIdSet.add(zInctToUpdate.M2_Div_2_Manager__c);
                } 
                else if(zInctToUpdate.D2_Div_2_Sales_Specialist__c != oldZInct.D2_Div_2_Sales_Specialist__c && String.isNotBlank(zInctToUpdate.D2_Div_2_Sales_Specialist__c)){
                    userEmpIdSet.add(zInctToUpdate.D2_Div_2_Sales_Specialist__c);
                }                
            }
            else if(zInctToUpdate.Prod_Division__c == 'III'){
                if(zInctToUpdate.D3_Div_3_Sales_Employee__c != oldZInct.D3_Div_3_Sales_Employee__c && String.isNotBlank(zInctToUpdate.D3_Div_3_Sales_Employee__c)){
                    userEmpIdSet.add(zInctToUpdate.D3_Div_3_Sales_Employee__c);
                }
                else if(zInctToUpdate.M3_Div_3_Manager__c != oldZInct.M3_Div_3_Manager__c && String.isNotBlank(zInctToUpdate.M3_Div_3_Manager__c)){
                    userEmpIdSet.add(zInctToUpdate.M3_Div_3_Manager__c);
                }
                else if(zInctToUpdate.D3_Div_3_Sales_Specialist__c != oldZInct.D3_Div_3_Sales_Specialist__c && String.isNotBlank(zInctToUpdate.D3_Div_3_Sales_Specialist__c)){
                    userEmpIdSet.add(zInctToUpdate.D3_Div_3_Sales_Specialist__c);
                }                
            }
			else if(zInctToUpdate.Prod_Division__c == 'IV'){
                if(zInctToUpdate.D4_Div_4_Sales_Employee__c != oldZInct.D4_Div_4_Sales_Employee__c && String.isNotBlank(zInctToUpdate.D4_Div_4_Sales_Employee__c)){
                    userEmpIdSet.add(zInctToUpdate.D4_Div_4_Sales_Employee__c);
                }
                else if(zInctToUpdate.M4_Div_4_Manager__c != oldZInct.M4_Div_4_Manager__c && String.isNotBlank(zInctToUpdate.M4_Div_4_Manager__c)){
                    userEmpIdSet.add(zInctToUpdate.M4_Div_4_Manager__c);
                } 
                else if(zInctToUpdate.D4_Div_4_Sales_Specialist__c != oldZInct.D4_Div_4_Sales_Specialist__c && String.isNotBlank(zInctToUpdate.D4_Div_4_Sales_Specialist__c)){
                    userEmpIdSet.add(zInctToUpdate.D4_Div_4_Sales_Specialist__c);
                }                
            }
            if(zInctToUpdate.Prod_Division__c == 'V'){
                if(zInctToUpdate.D5_Div_5_Sales_Employee__c != oldZInct.D5_Div_5_Sales_Employee__c && String.isNotBlank(zInctToUpdate.D5_Div_5_Sales_Employee__c)){
                    userEmpIdSet.add(zInctToUpdate.D5_Div_5_Sales_Employee__c);
                }
                else if(zInctToUpdate.M5_Div_5_Manager__c != oldZInct.M5_Div_5_Manager__c && String.isNotBlank(zInctToUpdate.M5_Div_5_Manager__c)){
                    userEmpIdSet.add(zInctToUpdate.M5_Div_5_Manager__c);
                } 
                else if(zInctToUpdate.D5_Div_5_Sales_Specialist__c != oldZInct.D5_Div_5_Sales_Specialist__c && String.isNotBlank(zInctToUpdate.D5_Div_5_Sales_Specialist__c)){
                    userEmpIdSet.add(zInctToUpdate.D5_Div_5_Sales_Specialist__c);
                }                
            }
            if(zInctToUpdate.ASM__c != oldZInct.ASM__c && String.isNotBlank(zInctToUpdate.ASM__c)){
                userEmpIdSet.add(zInctToUpdate.ASM__c);
            }
            if(zInctToUpdate.RBM_RSM__c != oldZInct.RBM_RSM__c && String.isNotBlank(zInctToUpdate.RBM_RSM__c)){
                userEmpIdSet.add(zInctToUpdate.RBM_RSM__c);
            }
            if(zInctToUpdate.ZSM_Z1__c != oldZInct.ZSM_Z1__c && String.isNotBlank(zInctToUpdate.ZSM_Z1__c)){
                userEmpIdSet.add(zInctToUpdate.ZSM_Z1__c);
            }
            if(zInctToUpdate.ZBM__c != oldZInct.ZBM__c && String.isNotBlank(zInctToUpdate.ZBM__c)){
                userEmpIdSet.add(zInctToUpdate.ZBM__c);
            }
            if(zInctToUpdate.Application_Specialist_Emp_Code__c != oldZInct.Application_Specialist_Emp_Code__c && String.isNotBlank(zInctToUpdate.Application_Specialist_Emp_Code__c)){
                userEmpIdSet.add(zInctToUpdate.Application_Specialist_Emp_Code__c);
            }
            if(zInctToUpdate.Product_Manager_Emp_Code__c != oldZInct.Product_Manager_Emp_Code__c && String.isNotBlank(zInctToUpdate.Product_Manager_Emp_Code__c)){
                userEmpIdSet.add(zInctToUpdate.Product_Manager_Emp_Code__c);
            }
        }
        //Create map of employee code and employee
        if(!userEmpIdSet.isEmpty()){
            for( User u : [SELECT ID,Employee_Code__c from User where Employee_Code__c in :userEmpIdSet])
            {
                empUser.put(u.Employee_Code__c,u);
            }  
        }
        //Update user lookups
        for(Z_Incentive__c zInctToUpdate : newLstZincentives){
            Z_Incentive__c oldZInct = oldMapZIncentive.get(zInctToUpdate.Id);
            if(zInctToUpdate.Prod_Division__c == 'I'){
                if(zInctToUpdate.D1_Div_1_Sales_Employee__c != oldZInct.D1_Div_1_Sales_Employee__c && String.isNotBlank(zInctToUpdate.D1_Div_1_Sales_Employee__c)
                   && empUser.containsKey(zInctToUpdate.D1_Div_1_Sales_Employee__c)){
                       zInctToUpdate.Sales_Employee__c = empUser.get(zInctToUpdate.D1_Div_1_Sales_Employee__c).Id;
                   }
                else if(zInctToUpdate.M1_Div_1_Manager__c != oldZInct.M1_Div_1_Manager__c && 
                        String.isNotBlank(zInctToUpdate.M1_Div_1_Manager__c) && empUser.containsKey(zInctToUpdate.M1_Div_1_Manager__c)){
                            zInctToUpdate.Div_Manager__c = empUser.get(zInctToUpdate.M1_Div_1_Manager__c).Id;                
                        } 
                else if(zInctToUpdate.D1_Div_1_Sales_Specialist__c != oldZInct.D1_Div_1_Sales_Specialist__c && 
                        String.isNotBlank(zInctToUpdate.D1_Div_1_Sales_Specialist__c) && empUser.containsKey(zInctToUpdate.D1_Div_1_Sales_Specialist__c)){
                            zInctToUpdate.Sales_Specialist__c = empUser.get(zInctToUpdate.D1_Div_1_Sales_Specialist__c).Id;                
                        }                
            }
            else if(zInctToUpdate.Prod_Division__c == 'II'){
                if(zInctToUpdate.D2_Div_2_Sales_Employee__c != oldZInct.D2_Div_2_Sales_Employee__c && String.isNotBlank(zInctToUpdate.D2_Div_2_Sales_Employee__c)
                   && empUser.containsKey(zInctToUpdate.D2_Div_2_Sales_Employee__c)){
                       zInctToUpdate.Sales_Employee__c = empUser.get(zInctToUpdate.D2_Div_2_Sales_Employee__c).Id;
                   }
                else if(zInctToUpdate.M2_Div_2_Manager__c != oldZInct.M2_Div_2_Manager__c && 
                        String.isNotBlank(zInctToUpdate.M2_Div_2_Manager__c) && empUser.containsKey(zInctToUpdate.M2_Div_2_Manager__c)){
                            zInctToUpdate.Div_Manager__c = empUser.get(zInctToUpdate.M2_Div_2_Manager__c).Id;                
                        }   
                else if(zInctToUpdate.D2_Div_2_Sales_Specialist__c != oldZInct.D2_Div_2_Sales_Specialist__c && 
                        String.isNotBlank(zInctToUpdate.D2_Div_2_Sales_Specialist__c) && empUser.containsKey(zInctToUpdate.D2_Div_2_Sales_Specialist__c)){
                            zInctToUpdate.Sales_Specialist__c = empUser.get(zInctToUpdate.D2_Div_2_Sales_Specialist__c).Id;                
                        }                
            }
            else if(zInctToUpdate.Prod_Division__c == 'III'){
                if(zInctToUpdate.D3_Div_3_Sales_Employee__c != oldZInct.D3_Div_3_Sales_Employee__c && String.isNotBlank(zInctToUpdate.D3_Div_3_Sales_Employee__c)
                   && empUser.containsKey(zInctToUpdate.D3_Div_3_Sales_Employee__c)){
                       zInctToUpdate.Sales_Employee__c = empUser.get(zInctToUpdate.D3_Div_3_Sales_Employee__c).Id;
                   }
                else if(zInctToUpdate.M3_Div_3_Manager__c != oldZInct.M3_Div_3_Manager__c && 
                        String.isNotBlank(zInctToUpdate.M3_Div_3_Manager__c) && empUser.containsKey(zInctToUpdate.M3_Div_3_Manager__c)){
                            zInctToUpdate.Div_Manager__c = empUser.get(zInctToUpdate.M3_Div_3_Manager__c).Id;                
                        }  
                else if(zInctToUpdate.D3_Div_3_Sales_Specialist__c != oldZInct.D3_Div_3_Sales_Specialist__c && 
                        String.isNotBlank(zInctToUpdate.D3_Div_3_Sales_Specialist__c) && empUser.containsKey(zInctToUpdate.D3_Div_3_Sales_Specialist__c)){
                            zInctToUpdate.Sales_Specialist__c = empUser.get(zInctToUpdate.D3_Div_3_Sales_Specialist__c).Id;                
                        }                
            }
            else if(zInctToUpdate.Prod_Division__c == 'IV'){
                if(zInctToUpdate.D4_Div_4_Sales_Employee__c != oldZInct.D4_Div_4_Sales_Employee__c && String.isNotBlank(zInctToUpdate.D4_Div_4_Sales_Employee__c)
                   && empUser.containsKey(zInctToUpdate.D4_Div_4_Sales_Employee__c)){
                       zInctToUpdate.Sales_Employee__c = empUser.get(zInctToUpdate.D4_Div_4_Sales_Employee__c).Id;
                   }
                else if(zInctToUpdate.M4_Div_4_Manager__c != oldZInct.M4_Div_4_Manager__c && 
                        String.isNotBlank(zInctToUpdate.M4_Div_4_Manager__c) && empUser.containsKey(zInctToUpdate.M4_Div_4_Manager__c)){
                            zInctToUpdate.Div_Manager__c = empUser.get(zInctToUpdate.M4_Div_4_Manager__c).Id;                
                        }  
                else if(zInctToUpdate.D4_Div_4_Sales_Specialist__c != oldZInct.D4_Div_4_Sales_Specialist__c && 
                        String.isNotBlank(zInctToUpdate.D4_Div_4_Sales_Specialist__c) && empUser.containsKey(zInctToUpdate.D4_Div_4_Sales_Specialist__c)){
                            zInctToUpdate.Sales_Specialist__c = empUser.get(zInctToUpdate.D4_Div_4_Sales_Specialist__c).Id;                
                        }                
            }
            else if(zInctToUpdate.Prod_Division__c == 'V'){
                if(zInctToUpdate.D5_Div_5_Sales_Employee__c != oldZInct.D5_Div_5_Sales_Employee__c && String.isNotBlank(zInctToUpdate.D5_Div_5_Sales_Employee__c)
                   && empUser.containsKey(zInctToUpdate.D5_Div_5_Sales_Employee__c)){
                       zInctToUpdate.Sales_Employee__c = empUser.get(zInctToUpdate.D5_Div_5_Sales_Employee__c).Id;
                   }
                else if(zInctToUpdate.M5_Div_5_Manager__c != oldZInct.M5_Div_5_Manager__c && 
                        String.isNotBlank(zInctToUpdate.M5_Div_5_Manager__c) && empUser.containsKey(zInctToUpdate.M5_Div_5_Manager__c)){
                            zInctToUpdate.Div_Manager__c = empUser.get(zInctToUpdate.M5_Div_5_Manager__c).Id;                
                        }
                else if(zInctToUpdate.D5_Div_5_Sales_Specialist__c != oldZInct.D5_Div_5_Sales_Specialist__c && 
                        String.isNotBlank(zInctToUpdate.D5_Div_5_Sales_Specialist__c) && empUser.containsKey(zInctToUpdate.D5_Div_5_Sales_Specialist__c)){
                            zInctToUpdate.Sales_Specialist__c = empUser.get(zInctToUpdate.D5_Div_5_Sales_Specialist__c).Id;                
                        }                
            }
            if(zInctToUpdate.ASM__c != oldZInct.ASM__c && String.isNotBlank(zInctToUpdate.ASM__c) && empUser.containsKey(zInctToUpdate.ASM__c)){
                zInctToUpdate.ASMs__c =  empUser.get(zInctToUpdate.ASM__c).Id;
            }
            if(zInctToUpdate.RBM_RSM__c != oldZInct.RBM_RSM__c && String.isNotBlank(zInctToUpdate.RBM_RSM__c) && empUser.containsKey(zInctToUpdate.RBM_RSM__c)){
                 zInctToUpdate.RSM__c =  empUser.get(zInctToUpdate.RBM_RSM__c).Id;
            }
            if(zInctToUpdate.ZSM_Z1__c != oldZInct.ZSM_Z1__c && String.isNotBlank(zInctToUpdate.ZSM_Z1__c) && empUser.containsKey(zInctToUpdate.ZSM_Z1__c)){
                zInctToUpdate.ZSM__c =  empUser.get(zInctToUpdate.ZSM_Z1__c).Id;
            }
            if(zInctToUpdate.ZBM__c != oldZInct.ZBM__c && String.isNotBlank(zInctToUpdate.ZBM__c) && empUser.containsKey(zInctToUpdate.ZBM__c)){
                zInctToUpdate.ZBMs__c =  empUser.get(zInctToUpdate.ZBM__c).Id;
            }
            if(zInctToUpdate.Application_Specialist_Emp_Code__c != oldZInct.Application_Specialist_Emp_Code__c && 
               String.isNotBlank(zInctToUpdate.Application_Specialist_Emp_Code__c) && empUser.containsKey(zInctToUpdate.Application_Specialist_Emp_Code__c)){
                zInctToUpdate.Application_Specialist__c =  empUser.get(zInctToUpdate.Application_Specialist_Emp_Code__c).Id;
            }
            if(zInctToUpdate.Product_Manager_Emp_Code__c != oldZInct.Product_Manager_Emp_Code__c && String.isNotBlank(zInctToUpdate.Product_Manager_Emp_Code__c)
              && empUser.containsKey(zInctToUpdate.Product_Manager_Emp_Code__c)){
                zInctToUpdate.Product_Manager__c =  empUser.get(zInctToUpdate.Product_Manager_Emp_Code__c).Id;
            }
        }
    }
    
    //Added by Jagdish
    public static string getFiscalYear( date dateToCalcuateFy){
        string fiscalYear;
        if(dateToCalcuateFy.month() <=3){
            fiscalYear = dateToCalcuateFy.addYears(-1).year()+'-'+dateToCalcuateFy.year();
        }else{
            fiscalYear = dateToCalcuateFy.year()+'-'+dateToCalcuateFy.addYears(1).year();
        }
        return fiscalYear;
    }
    
    public void updateRollingForecastLookups(List<Z_Incentive__c> inctLst){
        Set<Decimal> setInctYr = new Set<Decimal>();
        Set<Decimal> setcInctMonth = new Set<Decimal>();
        Set<Id> setAccountId = new Set<Id>();
        Set<Id> setProductId = new Set<Id>();
        List<Partner_Rolling_Forecast__c> lstRollingForecast = new List<Partner_Rolling_Forecast__c>();
        Map<Id,Boolean> mapProcessedInctRecords = new Map<Id,Boolean>();
	    Map<Id, Partner_Rolling_Forecast__c> mapRollingForecast = new Map<Id, Partner_Rolling_Forecast__c>();
        Map<Id, Z_Incentive__c> mapZInctToUpdate = new Map<Id, Z_Incentive__c>();
        Z_Incentive__c inc_obj = new Z_Incentive__c();
        Map<Id,Z_Incentive__c> zInct_Map = new Map<Id,Z_Incentive__c>();
        
        for(Z_Incentive__c inc : inctLst){
            if(inc.Account__c != null){
                setAccountId.add(inc.Account__c);
            }
            
            if(inc.Product__c != null){
                setProductId.add(inc.Product__c);
            }
            if(inc.Billing_Date__c != null){
                setInctYr.add(Decimal.valueOf(inc.Billing_Date__c.year()));            
                setcInctMonth.add(Decimal.valueOf(inc.Billing_Date__c.month()));
            }
        }
        system.debug('setInctYr : '+setInctYr);
        system.debug('setcInctMonth : '+setcInctMonth);
        system.debug('setAccountId : '+setAccountId);
        system.debug('setProductId : '+setProductId);
        
        if(!setProductId.isEmpty() && !setAccountId.isEmpty() && !setInctYr.isEmpty() && !setcInctMonth.isEmpty() ){            
            lstRollingForecast = [select id,Account__c,Agreement_Product__r.Product__c,Year__c,Month__c,Week_Number__c,Week_Start_Date__c,Week_End_Date__c
                                 from Partner_Rolling_Forecast__c where Account__c in: setAccountId and 
                                 Agreement_Product__r.Product__c in : setProductId and Year__c in : setInctYr and Month__c in : setcInctMonth order by Week_Number__c ASC];
            
            system.debug('lstRollingForecast'+lstRollingForecast);
        }
        if(!lstRollingForecast.isEmpty()){
            date dtMonthStartDate;
            date dtMaxDateToCheck;
            date dtMonthEndDate;
            boolean bMatchFound = false;

            for(Partner_Rolling_Forecast__c rollingForecast_obj : lstRollingForecast){
                for(Z_Incentive__c inc : inctLst){
                    if(!mapZInctToUpdate.containsKey(inc.Id)){
                        if(inc.Account__c == rollingForecast_obj.Account__c &&
                           inc.Product__c == rollingForecast_obj.Agreement_Product__r.Product__c && 
                           Decimal.valueOf(inc.Billing_Date__c.year()) == rollingForecast_obj.Year__c &&
                           Decimal.valueOf(inc.Billing_Date__c.month()) == rollingForecast_obj.Month__c){
                               dtMonthStartDate = date.newInstance(inc.Billing_Date__c.year(),inc.Billing_Date__c.month(), 1);
                               dtMaxDateToCheck = dtMonthStartDate.addDays(6);
                               dtMonthEndDate = date.newInstance(inc.Billing_Date__c.year(),inc.Billing_Date__c.month(), Date.daysInMonth(inc.Billing_Date__c.year(), inc.Billing_Date__c.month()));
                               
                               if(rollingForecast_obj.Week_Start_Date__c != null && rollingForecast_obj.Week_End_Date__c != null){
                                   if(inc.Billing_Date__c >= rollingForecast_obj.Week_Start_Date__c && 
                                      inc.Billing_Date__c <= rollingForecast_obj.Week_End_Date__c ){
                                          inc_obj = new Z_Incentive__c();
                                          inc_obj.id = inc.id;
                                          inc_obj.Partner_Rolling_Forecast__c = rollingForecast_obj.id;
                                          mapZInctToUpdate.put(inc.id, inc_obj);
                                      }
                                   else if(inc.Billing_Date__c >= dtMonthStartDate  && 
                                           inc.Billing_Date__c <= dtMaxDateToCheck  && 
                                           inc.Billing_Date__c <= rollingForecast_obj.Week_Start_Date__c){
                                               inc_obj = new Z_Incentive__c();
                                               inc_obj.id = inc.id;
                                               inc_obj.Partner_Rolling_Forecast__c = rollingForecast_obj.id;
                                               mapZInctToUpdate.put(inc.id, inc_obj);
                                           }
                                   else if( inc.Billing_Date__c.month() == 12 &&
                                           inc.Billing_Date__c <= dtMonthEndDate  && 
                                           inc.Billing_Date__c > rollingForecast_obj.Week_Start_Date__c &&
                                           inc.Billing_Date__c > rollingForecast_obj.Week_End_Date__c){
                                               system.debug('inside 12th month logic... ');
                                               inc_obj = new Z_Incentive__c();
                                               inc_obj.id = inc.id;
                                               inc_obj.Partner_Rolling_Forecast__c = rollingForecast_obj.id;
                                               mapZInctToUpdate.put(inc.id, inc_obj);
                                           }
                               }
                           } 
                    }
                    
                } 
            }			
        }
        if(!mapZInctToUpdate.isEmpty()){
            update mapZInctToUpdate.values();
        }
    }
    
    public void afterUpdateHandler(List<Z_Incentive__c> UpdatedZIncentives, map<Id, Z_Incentive__c> oldZIncentives){
        List<Z_Incentive__c> zInctLstToUpdate = new List<Z_Incentive__c>();
        Z_Incentive__c zInct;
        
        //Update payment due date to date if payment is received within collection cycle for internatinal
        for(Z_Incentive__c updatedZInct : UpdatedZIncentives){
            zInct = new Z_Incentive__c(Id = updatedZInct.Id, Payment_Received_Within_Cycle__c = updatedZInct.Payment_Received_Within_Cycle__c, 
                                      Payment_Due_Date__c = updatedZInct.Payment_Due_Date__c);
            Z_Incentive__c oldzinct = oldZIncentives.get(updatedZInct.Id);
            if(zInct.Payment_Received_Within_Cycle__c != oldzinct.Payment_Received_Within_Cycle__c && zInct.Payment_Received_Within_Cycle__c == TRUE
              && zInct.Payment_Due_Date__c != null){
                   zInct.Payment_Due_Date__c = System.today();
                   zInctLstToUpdate.add(zInct);
               }
        }
        if(!zInctLstToUpdate.isEmpty()){
           Update zInctLstToUpdate; 
        }
    }
    
    public void updateRegion(List<Z_Incentive__c> insertedInctLst){
        Set<Id> accountIdSt = new Set<Id>();
        List<Account> lstAccounts = new List<Account>();
        List<Z_Incentive__c> zinctLstToUpdate = new List<Z_Incentive__c>();
        Z_Incentive__c inc_obj = new Z_Incentive__c();
        
        if(!insertedInctLst.isEmpty()){
            for(Z_Incentive__c inct : insertedInctLst){
				accountIdSt.add(inct.Account__c);
            }  
        }
        if(!accountIdSt.isEmpty()){
            lstAccounts = [Select Id,Name,Region__c, Region__r.country_key__c From Account Where Id In : accountIdSt];
        }
        system.debug('lstAccounts'+lstAccounts);
        if(!lstAccounts.isEmpty()){
            for(Z_Incentive__c inct : insertedInctLst){
                for(Account acc : lstAccounts){
                    if(inct.Account__c == acc.Id){
                        if(acc.Region__r.country_key__c == 'IN'){
                            inc_obj = new Z_Incentive__c();
                            inc_obj.Id = inct.Id;
                            inc_obj.Region_of_Customer__c = 'Domestic';
                        }
                        if(acc.Region__r.country_key__c == 'TR'){
                            inc_obj = new Z_Incentive__c();
                            inc_obj.Id = inct.Id;
                            inc_obj.Region_of_Customer__c = 'Turkey';
                        }
                        if(acc.Region__r.country_key__c != 'IN' && acc.Region__r.country_key__c != 'TR'){
                            inc_obj = new Z_Incentive__c();
                            inc_obj.Id = inct.Id;
                            inc_obj.Region_of_Customer__c = 'International';
                        }
                        zinctLstToUpdate.add(inc_obj);
                        break;
                    } 
                } 
            }
        }
        system.debug('zinctLstToUpdate***'+zinctLstToUpdate);
        if(!zinctLstToUpdate.isEmpty()){
            Update zinctLstToUpdate;
        }
    }
}
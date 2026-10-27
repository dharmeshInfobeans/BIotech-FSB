/********************************************
* @Class Name   : CalculateMonthlyIncentive
* @Description  : This class is used to calculate monthly incentive
* @Created Date : 20-12-2019
* @Created By   : Pratiksha K. 
* ****************************************/

public class CalculateMonthlyIncentive{
	public static Date today;
    public static Date threeMonthOldStartDate,threeMonthOldEndDate;
    public static Incentive_Policy__c policyYr;
    public static List<Consumable_Incentive_Allocation__c> incentiveAllocationLst;
    public static List<Consumable_Product_Wise_Incentive_Rate__c> prodIncentiveRateLst;
    public static List<ABCD_Configuration__c> confgLst;
    public Static Map<Id, Consumable_Product_Wise_Incentive_Rate__c> prodCodeIncentiveMap = new map<Id, Consumable_Product_Wise_Incentive_Rate__c>();
    public Static Map<String,ABCD_Configuration__c> configPercentMap = new Map<String,ABCD_Configuration__c>();
    public static List<Monthly_AOP__c> mopLst = new List<Monthly_AOP__c>();
    public Static Map<String,Monthly_AOP__c> userProdMopMap = new Map<String,Monthly_AOP__c>();
    public static List<User> userLst;
    public Static Map<Id,User> userIdUserMap= new Map<Id,User>();
    public Static Map<String,List<User>> userIdUserLstMap= new Map<String,List<User>>();
    public static List<User> usrLst = new List<User>();
    public static List<String> roleNamelst = new List<String>();
    
    public static string fetchConfigurationDetails(String region, Date fromDate, Date toDate){
        today = System.today();
        threeMonthOldStartDate = fromDate;
        threeMonthOldEndDate = toDate;
        system.debug('threeMonthOldStartDate in costructor'+threeMonthOldStartDate);
        system.debug('threeMonthOldEndDate in costructor'+threeMonthOldEndDate);
        system.debug('region'+region);
        
        //Get Incentive allocation list for financial year
        incentiveAllocationLst = [Select Id,Name,Percentage_of_Allocation__c,Division__c,State_With_ZSM__c,Is_ZDM_Exists__c,Additional_Applicable_Percentage__c,
                                  Incentive_Policy_Year__c,Incentive_Type__c,Role__c From Consumable_Incentive_Allocation__c Where 
                                  Incentive_Policy_Year__r.Start_Date__c <=: threeMonthOldStartDate
                                  And Incentive_Policy_Year__r.End_Date__c >=: threeMonthOldEndDate And Incentive_Policy_Year__r.Region__c =: region];
        system.debug('incentiveAllocationLst**'+incentiveAllocationLst);
        
        //Get productwise incentive rates for financial year
        prodIncentiveRateLst = [Select Id,Name,Incentive_Per_Unit__c,Incentive_Policy_Year__c,Product__c,Product__r.Division__c,Product__r.Dummy_Product_Code__c From 
                                Consumable_Product_Wise_Incentive_Rate__c Where Incentive_Policy_Year__r.Start_Date__c <=: threeMonthOldStartDate
                                And Incentive_Policy_Year__r.End_Date__c >=: threeMonthOldEndDate And Incentive_Policy_Year__r.Region__c =: region];
        system.debug('prodIncentiveRateLst'+prodIncentiveRateLst);
        
        if(!prodIncentiveRateLst.isEmpty()){
            for(Consumable_Product_Wise_Incentive_Rate__c prodInctRate : prodIncentiveRateLst){
                prodCodeIncentiveMap.put(prodInctRate.Product__c, prodInctRate);
            }
        }
        system.debug('prodCodeIncentiveMap'+prodCodeIncentiveMap);
        
         //Get ABCD configuration for financial year
        list<ABCD_Configuration__c> confgLst = [Select Id,Percentage_Type__c,Name,Applicable_Invoice_Percentage_Closed__c,
                                                Incentive_Per_Unit__c,Incentive_Policy_Year__c 
                                                From ABCD_Configuration__c
                                                Where Incentive_Policy_Year__r.Start_Date__c <=: threeMonthOldStartDate
                                                And Incentive_Policy_Year__r.End_Date__c >=: threeMonthOldEndDate And Incentive_Policy_Year__r.Region__c =: region];
        system.debug('confgLst'+confgLst); 
        
        if(!confgLst.isEmpty()){
            for(ABCD_Configuration__c abcd : confgLst){
                configPercentMap.put(abcd.Percentage_Type__c,abcd);
            }
        }
        
         //Get monthly AOPs for financial year
        if(region == 'Domestic'){
            mopLst = [Select Id,Target_Quantity__c,Month_Number__c,Product__c,Start_Date__c,OwnerId,Region__r.country_key__c From Monthly_AOP__c 
                                           Where Month_Number__c =: threeMonthOldStartDate.month() and Start_Date__c =: threeMonthOldStartDate And
                                           Region__r.country_key__c = 'IN'];
        } 

        system.debug('mopLst'+mopLst);
        if(!mopLst.isEmpty()){
            for(Monthly_AOP__c mop : mopLst){
                userProdMopMap.put(mop.OwnerId+'_'+mop.Product__c,mop);
            }
        }
		system.debug('userProdMopMap'+userProdMopMap);
        //Get all active users for selected region 
        String userQuery = 'Select Id,IsActive,Employee_Code__c,UserRole.Name,ManagerId,User_Type__c,Date_of_Joining__c From User Where '
        	         + ' UserRole.Name !=\'\' And User_Type__c =:region'; 
        system.debug('userQuery'+userQuery);
        
        List<User> userLst = (List<User>) Database.query(userQuery);  
		system.debug('userLst'+userLst);
        
        if(!userLst.isEmpty()){
            for(User usr : userLst){
                userIdUserMap.put(usr.Id, usr);
            } 
        }
        
        //Get user rolewise mapping
		userIdUserLstMap = UserRolewiseGrouping_Class.createUserwiseGrouping(region);
        system.debug('userIdUserLstMap in constructor***'+userIdUserLstMap);
        
        for(String roleNm : userIdUserLstMap.keySet()){
           roleNamelst.add(roleNm); 
        }       
        roleNamelst.sort();
        system.debug('sorted ist'+roleNamelst);
        
        string logStatus ;
        if(!roleNamelst.isEmpty()){
            for(String roleName : roleNamelst){
                if(userIdUserLstMap.containsKey(roleName)){
                    logStatus = calculate_A_IncentiveDistribution(roleName,userIdUserLstMap.get(roleName), region);   
                    if (logStatus=='error') {
                        return 'error';
                    } else {
                        logStatus = 'success';
                    }
                } 
            }
        }
        return logStatus;
    }

     public static string calculate_A_IncentiveDistribution(String userRolename, list<User> lstUser, String region){           
         User_Wise_Incentive_Distribution__c mngrInctDistribution = new User_Wise_Incentive_Distribution__c();
         Incentive_Distribution__c mngrAInctDistribution = new Incentive_Distribution__c();
         List<Incentive_Distribution__c> lstMngrAInctDistribution = new List<Incentive_Distribution__c>();
         User_Wise_Incentive_Distribution__c userDistribution = new User_Wise_Incentive_Distribution__c();
         map<string, User_Wise_Incentive_Distribution__c> mapUniqueKey_UserWiseDistribution = new map<string, User_Wise_Incentive_Distribution__c>();
         string roleName, ownerId, productId, uniqueKey, billingStatus,query; 
         set<Id> userIds = new set<Id>();
         Date today = System.today(), userNewJoiningDate;
         Integer userJoiningYear, userNewJoiningMonth;
         
         for(User usr : lstUser){
             userIds.add(usr.Id);
         }
         system.debug('role'+userRolename);
         if(region == 'Domestic'){
             //Query z incentives related to domestic region only
             query = 'Select sum(Quantity__c) invoicedQty, Billing_Document_Status__c billingStatus,Product__c product, Product__r.Division__c productDiv,';         
             
             if(userRolename == '1_SE_SSE_BDM'){
                 query += 'Sales_Employee__c usr, Sales_Employee__r.UserRole.Name roleName,Payment_Received_Within_Cycle__c from Z_Incentive__c where Sales_Employee__c IN : userIds' 
                     +' And Billing_Date__c >=:threeMonthOldStartDate And Billing_Date__c <=: threeMonthOldEndDate'
                     +' And Cancellation__c = \'\' And Region_of_Customer__c = \'Domestic\' And Billing_type2__c = \'Sales\''
                     +' Group By Sales_Employee__c, Billing_Document_Status__c, Product__c,Sales_Employee__r.UserRole.Name, Product__r.Division__c,Payment_Received_Within_Cycle__c';
             }
             if(userRolename == '2_DM'){
                 query += 'Div_Manager__c usr, Div_Manager__r.UserRole.Name roleName,Payment_Received_Within_Cycle__c from Z_Incentive__c where Div_Manager__c IN : userIds'
                     +' And Billing_Date__c >=:threeMonthOldStartDate And Billing_Date__c <=: threeMonthOldEndDate'
                     +' And Cancellation__c = \'\' And Region_of_Customer__c = \'Domestic\' And Billing_type2__c = \'Sales\''
                     +' Group By Div_Manager__c, Billing_Document_Status__c, Product__c,Div_Manager__r.UserRole.Name, Product__r.Division__c,Payment_Received_Within_Cycle__c';
             }
             if(userRolename == '3_ASM'){
                 query += 'ASMs__c usr, ASMs__r.UserRole.Name roleName,Payment_Received_Within_Cycle__c from Z_Incentive__c where ASMs__c IN : userIds'
                     +' And Billing_Date__c >=:threeMonthOldStartDate And Billing_Date__c <=: threeMonthOldEndDate'
                     +' And Cancellation__c = \'\' And Region_of_Customer__c = \'Domestic\' And Billing_type2__c = \'Sales\''
                     +' Group By ASMs__c, Billing_Document_Status__c, Product__c,ASMs__r.UserRole.Name, Product__r.Division__c,Payment_Received_Within_Cycle__c';
             }
             if(userRolename == '4_RSM'){
                 query += 'RSM__c usr, RSM__r.UserRole.Name roleName, ZSM__c zsm,Payment_Received_Within_Cycle__c from Z_Incentive__c where RSM__c IN : userIds'
                     +' And Billing_Date__c >=:threeMonthOldStartDate And Billing_Date__c <=: threeMonthOldEndDate'
                     +' And Cancellation__c = \'\' And Region_of_Customer__c = \'Domestic\' And Billing_type2__c = \'Sales\''
                     +' Group By RSM__c, Billing_Document_Status__c, Product__c,RSM__r.UserRole.Name, Product__r.Division__c,ZSM__c,Payment_Received_Within_Cycle__c';
             }
             if(userRolename == '5_ZDM'){
                 query += 'ZBMs__c usr, ZBMs__r.UserRole.Name roleName,Payment_Received_Within_Cycle__c from Z_Incentive__c where ZBMs__c IN : userIds' 
                     +' And Billing_Date__c >=:threeMonthOldStartDate And Billing_Date__c <=: threeMonthOldEndDate'
                     +' And Cancellation__c = \'\' And Region_of_Customer__c = \'Domestic\' And Billing_type2__c = \'Sales\''
                     +' Group By ZBMs__c, Billing_Document_Status__c, Product__c,ZBMs__r.UserRole.Name, Product__r.Division__c,Payment_Received_Within_Cycle__c';
             }
             if(userRolename == '6_ZSM'){
                 query += 'ZSM__c usr,ZBMs__c zdm, ZSM__r.UserRole.Name roleName,Payment_Received_Within_Cycle__c from Z_Incentive__c where ZSM__c IN : userIds' 
                     +' And Billing_Date__c >=:threeMonthOldStartDate And Billing_Date__c <=: threeMonthOldEndDate'
                     +' And Cancellation__c = \'\' And Region_of_Customer__c = \'Domestic\' And Billing_type2__c = \'Sales\''
                     +' Group By ZSM__c, Billing_Document_Status__c, Product__c,ZSM__r.UserRole.Name, Product__r.Division__c,ZBMs__c,Payment_Received_Within_Cycle__c';
             }
             system.debug('full query for domestic: ' +query);
         }
         
         AggregateResult[]  aggrZIncentiveLst = (AggregateResult[]) Database.query(query);    
         
         system.debug('**aggrZIncentive***'+aggrZIncentiveLst);
         
         Id monthlyInctDistributionRecordTypId = Schema.SObjectType.User_Wise_Incentive_Distribution__c.getRecordTypeInfosByName().get('Monthly Incentive Distribution').getRecordTypeId();
         
         for(AggregateResult aggrZIncentive : aggrZIncentiveLst){
             ownerId = (Id) aggrZIncentive.get('usr');
             productId = (Id) aggrZIncentive.get('product');
             uniqueKey = (string) ownerId+'_'+(string)productId+'_'+threeMonthOldStartDate+'_'+threeMonthOldEndDate;
             billingStatus = (string) aggrZIncentive.get('billingStatus'); 
             userDistribution = new User_Wise_Incentive_Distribution__c();
             
             //Update closed and invoice qty depending on billing status if userwise incentive distribution already exists in map
             if(mapUniqueKey_UserWiseDistribution.containsKey(uniqueKey)) {
                 userDistribution = mapUniqueKey_UserWiseDistribution.get(uniqueKey);
                 if(aggrZIncentive.get('billingStatus') == 'Closed By Payment'){
                     if(aggrZIncentive.get('Payment_Received_Within_Cycle__c') == true){
                         if(userDistribution.Closed_Qty__c == null){
                             userDistribution.Closed_Qty__c =0;
                         }
                         userDistribution.Closed_Qty__c = userDistribution.Closed_Qty__c + (decimal) aggrZIncentive.get('invoicedQty');
                         userDistribution.Invoiced_Qty__c = userDistribution.Invoiced_Qty__c + (decimal) aggrZIncentive.get('invoicedQty');
                     }
                     else{
                         userDistribution.Invoiced_Qty__c += (decimal) aggrZIncentive.get('invoicedQty');
                     }
                 }
                 else{
                     system.debug('userDistribution.Closed_Qty__c'+userDistribution.Closed_Qty__c);
                     userDistribution.Invoiced_Qty__c += (decimal) aggrZIncentive.get('invoicedQty');
                     if(userDistribution.Closed_Qty__c == null){
                         userDistribution.Closed_Qty__c =0;
                     }//added by pk on 2/1/2020
                 }                 
             } else{
                 //Create new userwise incentive distribution records
                 //userDistribution.ownerId =  ownerId;
                 if(userIdUserMap.get(ownerId).IsActive == True){
                     userDistribution.ownerId =  ownerId;
                 }
                 else{
                     userDistribution.ownerId =  userInfo.getUserId();
                 }
                 userDistribution.RecordTypeId = monthlyInctDistributionRecordTypId;
                 userDistribution.User__c = ownerId;
                 userDistribution.Product__c =  productId;
                 userDistribution.Year__c = threeMonthOldStartDate.year();
                 userDistribution.Start_Date__c = threeMonthOldStartDate;
                 userDistribution.End_Date__c = threeMonthOldEndDate;
                 roleName = (string) aggrZIncentive.get('roleName');               
                 userDistribution.Unique_Key__c = uniqueKey;
                 userDistribution.Division__c = (string) aggrZIncentive.get('productDiv');
                 
                 //Update currencyisocode according to region
                 if(region == 'Domestic'){
                     userDistribution.CurrencyIsoCode = 'INR';
                 }
                 
                 //Update closed and invoiced qty depending on billing status
                 if(aggrZIncentive.get('billingStatus') == 'Closed By Payment'){
                     if(aggrZIncentive.get('Payment_Received_Within_Cycle__c') == true){
                         userDistribution.Closed_Qty__c = (decimal) aggrZIncentive.get('invoicedQty');
                         userDistribution.Invoiced_Qty__c = (decimal) aggrZIncentive.get('invoicedQty');
                     }
                     else{
                         userDistribution.Invoiced_Qty__c = (decimal) aggrZIncentive.get('invoicedQty');
                         if(userDistribution.Closed_Qty__c == null){
                             userDistribution.Closed_Qty__c =0;
                         }
                     }
                 }
                 else{
                     userDistribution.Invoiced_Qty__c = (decimal) aggrZIncentive.get('invoicedQty');
                     userDistribution.Closed_Qty__c = 0.0;//added by pk on 2/1/2020
                 }
                 //Update is payout applicable checkbox according to user joining date
                 //Incentive will pay to user if he has completed 6 months in organization
                 /*if(userIdUserMap.get(ownerId).Date_of_Joining__c.day() <= 15){
                     if(userIdUserMap.get(ownerId).Date_of_Joining__c.monthsBetween(today) < 6){
                         userDistribution.Is_Payout_Applicable__c = false;                        
                     }
                     else{
                         userDistribution.Is_Payout_Applicable__c = true;           
                     }
                 }
                 else{
                     userJoiningYear = userIdUserMap.get(ownerId).Date_of_Joining__c.year();
                     userNewJoiningMonth = userIdUserMap.get(ownerId).Date_of_Joining__c.addMonths(1).toStartOfMonth().month();
                     userNewJoiningDate = Date.newInstance(userJoiningYear,userNewJoiningMonth, 1);
                     if(userNewJoiningDate.monthsBetween(today) < 6){
                         userDistribution.Is_Payout_Applicable__c = false;                        
                     }
                     else{
                         userDistribution.Is_Payout_Applicable__c = true;           
                     }
                 }*////commented by pk on 5/6/20 for prod deployment        
                 
                 //Update monthly AOP
                 if(userProdMopMap.containsKey(userDistribution.User__c+'_'+userDistribution.Product__c)){
                     userDistribution.Monthly_AOP__c = userProdMopMap.get(userDistribution.User__c+'_'+userDistribution.Product__c).Id;
                 }
                 //Update product incentive rate
                 if(prodCodeIncentiveMap.containsKey(userDistribution.Product__c)){
                     userDistribution.Product_Incentive_Rate__c = prodCodeIncentiveMap.get(userDistribution.Product__c).Id;
                     userDistribution.Product_Incentive_Rate__r = prodCodeIncentiveMap.get(userDistribution.Product__c);
                 }
                 //update incentive allocation depending on user role and region
                 if(region == 'Domestic'){
                     for(Consumable_Incentive_Allocation__c incentiveAllocation : incentiveAllocationLst){
                         if(incentiveAllocation.Division__c == (string) aggrZIncentive.get('productDiv')){
                             //Update allocation for RSM depending on ZSM existance
                             if(roleName.startsWith('RSM') && incentiveAllocation.Role__c =='RSM'){
                                    if((Id)aggrZIncentive.get('zsm') != null){
                                        if(incentiveAllocation.State_With_ZSM__c == true){
                                            userDistribution.Consumable_Incentive_Allocation__c = incentiveAllocation.id;
                                            userDistribution.Consumable_Incentive_Allocation__r = incentiveAllocation;
                                            userDistribution.Role__c = incentiveAllocation.Role__c;
                                            break;
                                        }
                                        /*else{
                                            userDistribution.Consumable_Incentive_Allocation__c = incentiveAllocation.id;
                                            userDistribution.Consumable_Incentive_Allocation__r = incentiveAllocation;
                                            userDistribution.Role__c = incentiveAllocation.Role__c;
                                            break;
                                        }*///commentd on 19/2
                                    }
                                    else{
                                        if(incentiveAllocation.State_With_ZSM__c == false){
                                            userDistribution.Consumable_Incentive_Allocation__c = incentiveAllocation.id;
                                            userDistribution.Consumable_Incentive_Allocation__r = incentiveAllocation;
                                            userDistribution.Role__c = incentiveAllocation.Role__c;
                                            break;
                                        }
                                    }
                                }
                             //Update allocation for ZSM depending on ZDM existance
                             else if(roleName.startsWith('ZSM') && incentiveAllocation.Role__c =='ZSM'){
                                 if((Id)aggrZIncentive.get('zdm') != null){
                                     userDistribution.Additional_Incentive_Applicable__c = true;
                                 }
                                 userDistribution.Consumable_Incentive_Allocation__c = incentiveAllocation.id;
                                 userDistribution.Consumable_Incentive_Allocation__r = incentiveAllocation;
                                 userDistribution.Role__c = incentiveAllocation.Role__c;
                                 break;
                             }
                             else{
                                 //Update allocation for other than RSM and ZSM roles
                                 if(incentiveAllocation.Role__c.contains(';')){
                                     for(String inctAllocationRole : incentiveAllocation.Role__c.split(';')){
                                         if(userIdUserMap.get(ownerId).UserRole.Name.StartsWith(inctAllocationRole)){
                                             userDistribution.Consumable_Incentive_Allocation__c = incentiveAllocation.id;
                                             userDistribution.Consumable_Incentive_Allocation__r = incentiveAllocation;									
                                             userDistribution.Role__c = inctAllocationRole;
                                             break; 
                                         }
                                         
                                     }
                                 }
                                 else if(userIdUserMap.get(ownerId).UserRole.Name.StartsWith(incentiveAllocation.Role__c)){
                                     userDistribution.Consumable_Incentive_Allocation__c = incentiveAllocation.id;
                                     userDistribution.Consumable_Incentive_Allocation__r = incentiveAllocation;									
                                     userDistribution.Role__c = incentiveAllocation.Role__c;
                                     break;                                    
                                 }
                             }   
                         } 
                     }
                 }
                 system.debug('allocation'+userDistribution.Consumable_Incentive_Allocation__c);
                 
			//Update A configuration
             userDistribution.A_Configuration__c = configPercentMap.get('A').Id;
             userDistribution.A_Configuration__r = configPercentMap.get('A');
             }
             mapUniqueKey_UserWiseDistribution.put(userDistribution.Unique_Key__c, userDistribution);
             system.debug('mapUniqueKey_UserWiseDistribution**'+mapUniqueKey_UserWiseDistribution);
         }
         try{
             upsert mapUniqueKey_UserWiseDistribution.values() Unique_Key__c;
         }
         Catch(Exception e){
             System.debug('The following exception has occurred for monthly parent: ' + e.getMessage());
             Log_Entry__c parentErrorLog = Create_Log_Entries.createLogEntries('Batch', 'Failed', 'The following exception occur for role' +  userRolename + ':' + e.getMessage(), region, 'CalculateMonthlyIncentive', 'Consumable Incentive', 'Monthly');
             return 'error';
         }
         system.debug('parent records upserted');
         
         //Calculate A distribution for consumable monthly inentive records.
         for(User_Wise_Incentive_Distribution__c mngrIncentiveDistribution : mapUniqueKey_UserWiseDistribution.values()){
             mngrAInctDistribution = new Incentive_Distribution__c();
             mngrAInctDistribution.User_Wise_Incentive_Distribution__c =  mngrIncentiveDistribution.Id;
             mngrAInctDistribution.Percentage_Type__c = 'A';
             mngrAInctDistribution.CurrencyIsoCode = mngrIncentiveDistribution.CurrencyIsoCode;
             mngrAInctDistribution.Unique_Key__c = mngrIncentiveDistribution.Unique_Key__c+'_'+'A';
             mngrAInctDistribution.Start_Date__c = mngrIncentiveDistribution.Start_Date__c;
             mngrAInctDistribution.End_Date__c = mngrIncentiveDistribution.End_Date__c;

             if(userIdUserMap.get(mngrIncentiveDistribution.ownerId).UserRole.Name.StartsWith('ZSM')
                && mngrIncentiveDistribution.Additional_Incentive_Applicable__c == true){
                    if(mngrIncentiveDistribution.Consumable_Incentive_Allocation__r.Additional_Applicable_Percentage__c == null){
                        mngrIncentiveDistribution.Consumable_Incentive_Allocation__r.Additional_Applicable_Percentage__c = 0;
                    }
                    Decimal applicablrPercent = mngrIncentiveDistribution.Consumable_Incentive_Allocation__r.Percentage_of_Allocation__c+mngrIncentiveDistribution.Consumable_Incentive_Allocation__r.Additional_Applicable_Percentage__c;
                    mngrAInctDistribution.Possible_Payout__c = ((((mngrIncentiveDistribution.Invoiced_Qty__c*mngrIncentiveDistribution.Product_Incentive_Rate__r.Incentive_Per_Unit__c)*mngrIncentiveDistribution.A_Configuration__r.Incentive_Per_Unit__c)/100)*applicablrPercent)/100;
                    mngrAInctDistribution.Actual_Payout__c = ((((mngrIncentiveDistribution.Closed_Qty__c*mngrIncentiveDistribution.Product_Incentive_Rate__r.Incentive_Per_Unit__c)*mngrIncentiveDistribution.A_Configuration__r.Incentive_Per_Unit__c)/100)*applicablrPercent)/100;
             }
             else
             {
                 system.debug('product incentive rate'+mngrIncentiveDistribution.Product_Incentive_Rate__r.Incentive_Per_Unit__c);
                 system.debug('allocation'+mngrIncentiveDistribution.Consumable_Incentive_Allocation__r.Percentage_of_Allocation__c);
                 if(mngrIncentiveDistribution.Product_Incentive_Rate__c != null){
                     mngrAInctDistribution.Possible_Payout__c = ((((mngrIncentiveDistribution.Invoiced_Qty__c*mngrIncentiveDistribution.Product_Incentive_Rate__r.Incentive_Per_Unit__c)*mngrIncentiveDistribution.A_Configuration__r.Incentive_Per_Unit__c)/100)*mngrIncentiveDistribution.Consumable_Incentive_Allocation__r.Percentage_of_Allocation__c)/100;
                     mngrAInctDistribution.Actual_Payout__c = ((((mngrIncentiveDistribution.Closed_Qty__c*mngrIncentiveDistribution.Product_Incentive_Rate__r.Incentive_Per_Unit__c)*mngrIncentiveDistribution.A_Configuration__r.Incentive_Per_Unit__c)/100)*mngrIncentiveDistribution.Consumable_Incentive_Allocation__r.Percentage_of_Allocation__c)/100;
                 }
                 else{
                     mngrAInctDistribution.Possible_Payout__c = 0;
                     mngrAInctDistribution.Actual_Payout__c = 0;
                 }
             }
             mngrAInctDistribution.Loss__c = mngrAInctDistribution.Possible_Payout__c-mngrAInctDistribution.Actual_Payout__c;            
             lstMngrAInctDistribution.add(mngrAInctDistribution);
         }
         try{
             upsert lstMngrAInctDistribution Unique_Key__c;
             system.debug('child records upserted');
             return 'success';
         }
         Catch(Exception e){
             System.debug('The following exception has occurred for monthly child: ' + e.getMessage());
             Log_Entry__c childErrorLog = Create_Log_Entries.createLogEntries('Batch', 'Failed', 'The following exception occur for role' +  userRolename + ':' + e.getMessage(), region, 'CalculateMonthlyIncentive', 'Consumable Incentive', 'Monthly');
             return 'error';
         }
     }
}
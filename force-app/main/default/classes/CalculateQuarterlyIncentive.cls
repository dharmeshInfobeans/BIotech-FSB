/********************************************
* @Class Name   : CalculateQuarterlyIncentive
* @Description  : This class is used to calculate quarterly incentive
* @Created Date : 18-12-2019
* @Created By   : Pratiksha K. 
* ****************************************/

public class CalculateQuarterlyIncentive{
    public static Date today,startDate,endDate;
    Public static Period last2FiscQaurterStartEndDt;
    public static Incentive_Policy__c policyYr;
    public static List<Consumable_Incentive_Allocation__c> incentiveAllocationLst;
    public static List<Consumable_Product_Wise_Incentive_Rate__c> prodIncentiveRateLst;
    public static List<ABCD_Configuration__c> confgLst;
    public static Map<Id, Consumable_Product_Wise_Incentive_Rate__c> prodCodeIncentiveMap = new map<Id, Consumable_Product_Wise_Incentive_Rate__c>();
    public static Map<String,ABCD_Configuration__c> configPercentMap = new Map<String,ABCD_Configuration__c>();
    public static Map<String,List<User>> userIdUserLstMap= new Map<String,List<User>>();
    public static List<String> roleNamelst = new List<String>();
    public static Map<Id,User> userIdUserMap= new Map<Id,User>();
    public static List<User> userLst;
    public static Map<Id,Consumable_Incentive_Allocation__c> inctAlocationMap = new Map<Id,Consumable_Incentive_Allocation__c>();
    
    public static string fetchConfigurationDetails(String region, Date fromDate, Date toDate){
        today = System.today();
        
        startDate = fromDate;
        endDate = toDate; 
        
        //Get Incentive allocation list for financial year
        incentiveAllocationLst = [Select Id,Name,Percentage_of_Allocation__c,Division__c,Incentive_Policy_Year__c,Additional_Applicable_Percentage__c,Role__c,
                                  Incentive_Type__c From Consumable_Incentive_Allocation__c Where Incentive_Policy_Year__r.Start_Date__c <=: startDate
                                  And Incentive_Policy_Year__r.End_Date__c >=: endDate And Incentive_Policy_Year__r.Region__c =: region];
        if(!incentiveAllocationLst.isEmpty()){
            for(Consumable_Incentive_Allocation__c inctAllocation : incentiveAllocationLst){
                inctAlocationMap.put(inctAllocation.id,inctAllocation);
            }
        }
        
        //Get productwise incentive rates for financial year
        prodIncentiveRateLst = [Select Id,Name,Incentive_Per_Unit__c,Incentive_Policy_Year__c,Product__c,Product__r.Division__c,Product__r.Dummy_Product_Code__c From 
                                Consumable_Product_Wise_Incentive_Rate__c Where Incentive_Policy_Year__r.Start_Date__c <=: startDate
                                And Incentive_Policy_Year__r.End_Date__c >=: endDate And Incentive_Policy_Year__r.Region__c =: region];
        
        if(!prodIncentiveRateLst.isEmpty()){
            for(Consumable_Product_Wise_Incentive_Rate__c prodInctRate : prodIncentiveRateLst){
                prodCodeIncentiveMap.put(prodInctRate.Product__c, prodInctRate);
            }
        }
        
        //Get ABCD configuration for financial year
        confgLst = [Select Id,Percentage_Type__c,Name,Applicable_Invoice_Percentage_Closed__c,Incentive_Per_Unit__c,Incentive_Policy_Year__c,Greater_than_equal__c 
                    From ABCD_Configuration__c Where Incentive_Policy_Year__r.Start_Date__c <=: startDate
                    And Incentive_Policy_Year__r.End_Date__c >=: endDate And Incentive_Policy_Year__r.Region__c =: region];
        
        if(!confgLst.isEmpty()){
            for(ABCD_Configuration__c abcd : confgLst){
                configPercentMap.put(abcd.Percentage_Type__c,abcd);
            }
        }

        //Get all active users for selected region 
        String userQuery = 'Select Id,IsActive,Employee_Code__c,UserRole.Name,ManagerId,User_Type__c,Date_of_Joining__c From User Where '
            + ' UserRole.Name !=\'\' And User_Type__c =:region'; 
        system.debug('userQuery'+userQuery);
        
        List<User> userLst = (List<User>) Database.query(userQuery);
        if(!userLst.isEmpty()){
            for(User usr : userLst){
                userIdUserMap.put(usr.Id, usr);
            } 
        }
        roleNamelst.clear();//added by pk on 3/2/2020
        //Get user rolewise mapping
        userIdUserLstMap = UserRolewiseGrouping_Class.createUserwiseGrouping(region);
        for(String roleNm : userIdUserLstMap.keySet()){
            roleNamelst.add(roleNm); 
        }
        roleNamelst.sort();
        system.debug('roleNamelst'+roleNamelst);
        
        string logStatus ;
        if(!roleNamelst.isEmpty()){
            for(String roleName : roleNamelst){
                if(userIdUserLstMap.containsKey(roleName)){
                    logStatus = calculateInctForBCD(userIdUserLstMap.get(roleName),region, roleName);
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
    
    public static string calculateInctForBCD(List<User> lstUser, String region, String userRoleName){
        string roleName, ownerId, productId, uniqueKey, billingStatus;  
        User_Wise_Incentive_Distribution__c userDistribution = new User_Wise_Incentive_Distribution__c();
        map<string, User_Wise_Incentive_Distribution__c> mapUniqueKey_UserWiseDistribution = new map<string, User_Wise_Incentive_Distribution__c>();
        Incentive_Distribution__c BCDInctDistribution = new Incentive_Distribution__c();
        List<Incentive_Distribution__c> lstBCDInctDistribution = new List<Incentive_Distribution__c>();
        Decimal possiblePayout, actualPayout,targetPayout, totalMOPQty, totalInvoicedQty, totalClosedQty;
        Map<String,List<AggregateResult>> ownerProductUWIDAggrResMap = new Map<String,List<AggregateResult>>();
        List<AggregateResult> usrIncentiveDistributionAggrResLst = new List<AggregateResult>();
        decimal eligibleQty = 0.0;
        String childUniquekey;
        Integer userJoiningYear, userNewJoiningMonth;
        Date today = System.today(), userNewJoiningDate;
        
        set<Id> userIds = new set<Id>();
        for(User usr : lstUser){
            userIds.add(usr.Id);
        }
        system.debug('userIds'+userIds);
        system.debug('userRoleName**'+userRoleName);
        
        Id monthlyInctDistributionRecordTypId = Schema.SObjectType.User_Wise_Incentive_Distribution__c.getRecordTypeInfosByName().get('Monthly Incentive Distribution').getRecordTypeId();
		
        //Fire aggregate query on monthly userwise incentivedistribution records
        /*AggregateResult[] usrInctDistributionAggrResLst = [Select SUM(Closed_Qty__c) closedQty, SUM(Invoiced_Qty__c) invoicedQty, Product__c product,Id,Start_Date__c, 
                                                           Product_Incentive_Rate__c inctRate, Division__c division,User__c salesUser,Consumable_Incentive_Allocation__c inctAllocation, 
                                                           SUM(Monthly_AOP__r.Target_Quantity__c) totalMOPQty,User__r.UserRole.Name roleName,End_Date__c,Additional_Incentive_Applicable__c,
                                                           Role__c role From User_Wise_Incentive_Distribution__c
                                                           Where Start_Date__c >=: last2FiscQaurterStartEndDt.StartDate And End_Date__c <=: last2FiscQaurterStartEndDt.EndDate
                                                           and User__c IN : userIds and recordTypeId =: monthlyInctDistributionRecordTypId and Monthly_AOP__c != null
                                                           Group By Product__c,Product_Incentive_Rate__c, Division__c,User__c,Start_Date__c,End_Date__c,
                                                           Consumable_Incentive_Allocation__c,User__r.UserRole.Name,Id,Additional_Incentive_Applicable__c,Role__c];*/
        
        AggregateResult[] usrInctDistributionAggrResLst = [Select SUM(Closed_Qty__c) closedQty, SUM(Invoiced_Qty__c) invoicedQty, Product__c product,Id,Start_Date__c, 
                                                           Product_Incentive_Rate__c inctRate, Division__c division,User__c salesUser,Consumable_Incentive_Allocation__c inctAllocation, 
                                                           SUM(Monthly_AOP__r.Target_Quantity__c) totalMOPQty,User__r.UserRole.Name roleName,End_Date__c,Additional_Incentive_Applicable__c,
                                                           Role__c role From User_Wise_Incentive_Distribution__c
                                                           Where Start_Date__c >=: startDate And End_Date__c <=: endDate
                                                           and User__c IN : userIds and recordTypeId =: monthlyInctDistributionRecordTypId and Monthly_AOP__c != null
                                                           Group By Product__c,Product_Incentive_Rate__c, Division__c,User__c,Start_Date__c,End_Date__c,
                                                           Consumable_Incentive_Allocation__c,User__r.UserRole.Name,Id,Additional_Incentive_Applicable__c,Role__c];
        system.debug('iiiiiiiii'+usrInctDistributionAggrResLst);
        Id quarterlyInctDistributionRecordTypId = Schema.SObjectType.User_Wise_Incentive_Distribution__c.getRecordTypeInfosByName().get('Quarterly Incentive Distribution').getRecordTypeId();
        
        if(!usrInctDistributionAggrResLst.isEmpty()){
            for(AggregateResult usrInctDistributionAggrRes : usrInctDistributionAggrResLst){
                ownerId = (Id) usrInctDistributionAggrRes.get('salesUser');
                productId = (Id) usrInctDistributionAggrRes.get('product');
                //uniqueKey = (string) ownerId+'_'+(string)productId+'_'+last2FiscQaurterStartEndDt.StartDate+'_'+last2FiscQaurterStartEndDt.EndDate;
                uniqueKey = (string) ownerId+'_'+(string)productId+'_'+startDate+'_'+endDate;
                userDistribution = new User_Wise_Incentive_Distribution__c();
                
                if(ownerProductUWIDAggrResMap.containsKey((string) ownerId+'_'+(string)productId)){
                    usrIncentiveDistributionAggrResLst = ownerProductUWIDAggrResMap.get((string) ownerId+'_'+(string)productId);
                    usrIncentiveDistributionAggrResLst.add(usrInctDistributionAggrRes);
                }
                else
                {                    
                    usrIncentiveDistributionAggrResLst = new List<AggregateResult>();
                    usrIncentiveDistributionAggrResLst.add(usrInctDistributionAggrRes);
                    ownerProductUWIDAggrResMap.put((string) ownerId+'_'+(string)productId,usrIncentiveDistributionAggrResLst);
                }
                
                if(mapUniqueKey_UserWiseDistribution.containsKey(uniqueKey)) {
                    userDistribution = mapUniqueKey_UserWiseDistribution.get(uniqueKey); 
                    userDistribution.Invoiced_Qty__c += (Decimal)usrInctDistributionAggrRes.get('invoicedQty');
                    userDistribution.Closed_Qty__c += (Decimal)usrInctDistributionAggrRes.get('closedQty');
                    userDistribution.Total_MOP_Qty__c += (Decimal)usrInctDistributionAggrRes.get('totalMOPQty');
                }
                else{
                    //userDistribution.ownerId =  ownerId;
                    if(userIdUserMap.get(ownerId).IsActive == True){
                        userDistribution.ownerId =  ownerId;
                    }
                    else{
                        userDistribution.ownerId =  userInfo.getUserId();
                    }
                    userDistribution.User__c = ownerId;
                    userDistribution.Product__c =  productId;
                    userDistribution.Role__c = (String)usrInctDistributionAggrRes.get('role');
                    userDistribution.RecordTypeId = quarterlyInctDistributionRecordTypId;
                    /*userDistribution.Year__c = last2FiscQaurterStartEndDt.StartDate.year();
                    userDistribution.Start_Date__c = last2FiscQaurterStartEndDt.StartDate;
                    userDistribution.End_Date__c = last2FiscQaurterStartEndDt.EndDate;*/
                    userDistribution.Year__c = startDate.year();
                    userDistribution.Start_Date__c = startDate;
                    userDistribution.End_Date__c = endDate;
                    roleName = (string) usrInctDistributionAggrRes.get('roleName'); 
                    userDistribution.Invoiced_Qty__c = (Decimal) usrInctDistributionAggrRes.get('invoicedQty');
                    userDistribution.Closed_Qty__c = (Decimal) usrInctDistributionAggrRes.get('closedQty');
                    userDistribution.Unique_Key__c = uniqueKey;
                    userDistribution.Division__c = (string) usrInctDistributionAggrRes.get('division');
                    userDistribution.Total_MOP_Qty__c = (Decimal)usrInctDistributionAggrRes.get('totalMOPQty');
                    if(region == 'Domestic'){
                        userDistribution.CurrencyIsoCode = 'INR';
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
                    }*///commented by pk on 5/6/20 for prod deployment      
                    
					//not in use.Can be removed later
                    if(configPercentMap.containsKey('B')){
                        userDistribution.B_Configuration__c = configPercentMap.get('B').Id;
                        userDistribution.B_Configuration__r = configPercentMap.get('B');
                    }
                    if(configPercentMap.containsKey('C')){
                        userDistribution.C_Configuration__c = configPercentMap.get('C').Id;
                        userDistribution.C_Configuration__r = configPercentMap.get('C');
                    }
                    if(configPercentMap.containsKey('D')){
                        userDistribution.D_Configuration__c = configPercentMap.get('D').Id;
                        userDistribution.D_Configuration__r = configPercentMap.get('D');
                    }
                }
                mapUniqueKey_UserWiseDistribution.put(userDistribution.Unique_Key__c, userDistribution);
            } 
        }
        try{
            upsert mapUniqueKey_UserWiseDistribution.values() Unique_Key__c;
        }
        Catch(Exception e){
            System.debug('The following exception has occurred: ' + e.getMessage());
            Log_Entry__c parentErrorLog = Create_Log_Entries.createLogEntries('Batch', 'Failed', 'The following exception occur for role' +  userRolename + ':' + e.getMessage(), region, 'QuarterlyIncentiveCalculation', 'Consumable Incentive', 'Quarterly');
            return 'error';
        }

        Decimal applicablePercent = 0.0;
        //Calculate B,C,D distribution for quarterly userwise incentive distribution records.
        for(User_Wise_Incentive_Distribution__c userwiseIncentiveDistribution : mapUniqueKey_UserWiseDistribution.values()){
            childUniquekey = userwiseIncentiveDistribution.OwnerId+'_'+userwiseIncentiveDistribution.Product__c;
            if(ownerProductUWIDAggrResMap.containsKey(childUniquekey)){
                for(AggregateResult parentUWID : ownerProductUWIDAggrResMap.get(childUniquekey)){
                    for(ABCD_Configuration__c confg : confgLst){
                        if(confg.Percentage_Type__c != 'A'){
                            BCDInctDistribution = new Incentive_Distribution__c();
                            BCDInctDistribution.User_Wise_Incentive_Distribution__c =  userwiseIncentiveDistribution.Id;
                            BCDInctDistribution.Percentage_Type__c = confg.Percentage_Type__c;
                            BCDInctDistribution.CurrencyIsoCode = userwiseIncentiveDistribution.CurrencyIsoCode;
                            BCDInctDistribution.Unique_Key__c = userwiseIncentiveDistribution.OwnerId+'_'+userwiseIncentiveDistribution.Product__c+'_'+(Date)parentUWID.get('Start_Date__c')+'_'+(Id)parentUWID.get('Id')+'_'+confg.Percentage_Type__c;
                            
                            if(userwiseIncentiveDistribution.Total_MOP_Qty__c == 0){
                                eligibleQty = userwiseIncentiveDistribution.Closed_Qty__c;  
                            }//added on 21/1/2020 
                            else{
                                eligibleQty = (userwiseIncentiveDistribution.Closed_Qty__c / userwiseIncentiveDistribution.Total_MOP_Qty__c) * 100; 
                            }                            

                            BCDInctDistribution.Start_Date__c = (Date)parentUWID.get('Start_Date__c');
                            BCDInctDistribution.End_Date__c = (Date)parentUWID.get('End_Date__c');
                            BCDInctDistribution.A_User_Wise_Incentive_Distribution__c = (Id)parentUWID.get('Id');
                            
                            if(eligibleQty>=confg.Greater_than_equal__c){
                                if(userIdUserMap.get(userwiseIncentiveDistribution.User__c).UserRole.Name.StartsWith('ZSM')){
                                    if((Boolean)parentUWID.get('Additional_Incentive_Applicable__c') == true){
                                        applicablePercent = inctAlocationMap.get((Id)parentUWID.get('inctAllocation')).Percentage_of_Allocation__c+inctAlocationMap.get((Id)parentUWID.get('inctAllocation')).Additional_Applicable_Percentage__c;
                                        BCDInctDistribution.Possible_Payout__c = ((((Decimal)parentUWID.get('invoicedQty')*prodCodeIncentiveMap.get((Id)parentUWID.get('product')).Incentive_Per_Unit__c*confg.Incentive_Per_Unit__c)/100)*applicablePercent)/100;
                                        BCDInctDistribution.Actual_Payout__c = ((((Decimal)parentUWID.get('closedQty')*prodCodeIncentiveMap.get((Id)parentUWID.get('product')).Incentive_Per_Unit__c*confg.Incentive_Per_Unit__c)/100)*applicablePercent)/100;
                                    }
                                    else{
                                        BCDInctDistribution.Possible_Payout__c = ((((Decimal)parentUWID.get('invoicedQty')*prodCodeIncentiveMap.get((Id)parentUWID.get('product')).Incentive_Per_Unit__c*confg.Incentive_Per_Unit__c)/100)*inctAlocationMap.get((Id)parentUWID.get('inctAllocation')).Percentage_of_Allocation__c)/100;
                                        BCDInctDistribution.Actual_Payout__c = ((((Decimal)parentUWID.get('closedQty')*prodCodeIncentiveMap.get((Id)parentUWID.get('product')).Incentive_Per_Unit__c*confg.Incentive_Per_Unit__c)/100)*inctAlocationMap.get((Id)parentUWID.get('inctAllocation')).Percentage_of_Allocation__c)/100;
                                    }
                                }
                                else{
                                    BCDInctDistribution.Possible_Payout__c = ((((Decimal)parentUWID.get('invoicedQty')*prodCodeIncentiveMap.get((Id)parentUWID.get('product')).Incentive_Per_Unit__c*confg.Incentive_Per_Unit__c)/100)*inctAlocationMap.get((Id)parentUWID.get('inctAllocation')).Percentage_of_Allocation__c)/100;
                                    BCDInctDistribution.Actual_Payout__c = ((((Decimal)parentUWID.get('closedQty')*prodCodeIncentiveMap.get((Id)parentUWID.get('product')).Incentive_Per_Unit__c*confg.Incentive_Per_Unit__c)/100)*inctAlocationMap.get((Id)parentUWID.get('inctAllocation')).Percentage_of_Allocation__c)/100;
                                }
                            }
                            else{
                                BCDInctDistribution.Possible_Payout__c = 0;
                                BCDInctDistribution.Actual_Payout__c = 0; 
                            }
                            BCDInctDistribution.Loss__c = BCDInctDistribution.Possible_Payout__c-BCDInctDistribution.Actual_Payout__c;
                            lstBCDInctDistribution.add(BCDInctDistribution);
                        }
                    }
                }
            }
        }
        
        try{
            upsert lstBCDInctDistribution Unique_Key__c;
            return 'success';
        }
        Catch(Exception e){
            System.debug('The following exception has occurred for quarterly child: ' + e.getMessage());
            Log_Entry__c childErrorLog = Create_Log_Entries.createLogEntries('Batch', 'Failed', 'The following exception occur for role' +  userRolename + ':' + e.getMessage(), region, 'QuarterlyIncentiveCalculation', 'Consumable Incentive', 'Quarterly');
            return 'error';
        }
    }  
}
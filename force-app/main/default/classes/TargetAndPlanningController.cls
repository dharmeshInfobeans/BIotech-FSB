public with sharing class TargetAndPlanningController {
    
    @AuraEnabled //(cacheable=true) 
    public static List<Object> getTargetAmountByUserDivision(String month, String year, String demographic){
        List<String> divList = new  List<String>();
        
        User usr = [Select Id,Name,Division__c,Employee_Code__c From User Where Id=: UserInfo.getUserId()];
        if(usr.Division__c != null){
            String divisions = usr.Division__c;
            if(divisions.contains(';')){
                divList = divisions.split(';');    
            }else{
                //if user has only one division.
                divList.add(divisions); 
            }
            
            // System.debug('Div LIST-->'+divList);
        }
        System.debug('In ZZZ TrgtAndPlningCont-->getTargetAmountByUserDivision_M-->demographic-->'+demographic);
        
        if(demographic == Constants.DEMOGRAPHIC_DOMESTIC){
            year = Constants.CURRENT_FISCALYEAR; // Setting year as fiscal year
            List<Object> prodList = [Select Id,Name,Division__c,MSP__c,Dummy_Product_Description__c,Dummy_Product_Code__c,
                                     (Select Id,Name,Financial_Year_Date__c,Financial_Year__c,Remaining_Qty__c,Product__c,Account__c,Target_Amount__c,Target_Quantity__c,Month__c,Sales_User__c,Unique_Code__c,Year__c
                                      //     From Monthly_AOP__r Where Month__c=: month AND Year__c=: year
                                      From Monthly_AOP__r Where Month__c=: month AND Financial_Year__c=: year //Added on 05042019 
                                      AND RecordType.DeveloperName =: Constants.MONTHLYAOP_DOMESTIC_RECORDTYPE_DEVELOPERNAME
                                      AND Sales_User__c=:UserInfo.getUserId() // Added on 09042019
                                      AND Account__c = null
                                      LIMIT 1) //Setting Limit as '1' coz each product will have only one AOP record per month.
                                     From Product__c
                                     Where Division__c IN : divList
                                     AND Id IN (SELECT Product__c 
                                                FROM Monthly_AOP__c
                                                WHERE Month__c=: month 
                                                AND Financial_Year__c=:year //Added on 05042019 
                                                AND Recordtype.DeveloperName =: Constants.MONTHLYAOP_DOMESTIC_RECORDTYPE_DEVELOPERNAME
                                                // AND Product__r.Division__c IN : divList
                                                // AND (Account__r.RecordType.DeveloperName =:Constants.ACCOUNT_DOM_DISTRIBUTOR_RECORDTYPEDEVELOPERNAME
                                                //     OR Account__r.RecordType.DeveloperName =:Constants.ACCOUNT_DOM_DOCTOR_RECORDTYPEDEVELOPERNAME)
                                               )
                                    ];
            if(!prodList.isEmpty()){
                return prodList;    
            }else{
                return null;
            }    
        }else if(demographic == Constants.DEMOGRAPHIC_TURKEY){
            System.debug('In ZZZ TrgtAndPlningCont-->getTargetAmountByUserDivision_M-->demographic-->'+demographic);
            System.debug('In ZZZ TrgtAndPlningCont-->getTargetAmountByUserDivision_M-->month-->'+month);
            System.debug('In ZZZ TrgtAndPlningCont-->getTargetAmountByUserDivision_M-->year-->'+year);
            List<Object> prodList = [Select Id,Name,Division__c,MSP__c,Dummy_Product_Description__c,Dummy_Product_Code__c,
                                     (Select Id,Name,Financial_Year_Date__c,Financial_Year__c,Remaining_Qty__c,Product__c,Account__c,Target_Amount__c,Target_Quantity__c,Month__c,Sales_User__c,Unique_Code__c,Year__c
                                      From Monthly_AOP__r Where Month__c=: month AND Year__c=: year
                                      AND RecordType.DeveloperName =: Constants.MONTHLYAOP_TURKEY_RECORDTYPE_DEVELOPERNAME
                                      AND Account__c = null
                                      AND Sales_User__c=:UserInfo.getUserId() // Added on 09042019
                                      LIMIT 1) //Setting Limit as '1' coz each product will have only one AOP record per month.
                                     From Product__c
                                     Where Division__c IN : divList
                                     AND Id IN (SELECT Product__c 
                                                FROM Monthly_AOP__c
                                                WHERE Month__c=: month 
                                                AND Year__c=: year // current year no fiscal year
                                                AND Recordtype.DeveloperName =: Constants.MONTHLYAOP_TURKEY_RECORDTYPE_DEVELOPERNAME
                                                AND Sales_User__c=:UserInfo.getUserId()
                                                //AND  (Account__r.RecordType.DeveloperName =:Constants.ACCOUNT_TURKEY_DISTRIBUTOR_RECORDTYPEDEVELOPERNAME
                                                //      OR Account__r.RecordType.DeveloperName =:Constants.ACCOUNT_TURKEY_DOCTOR_RECORDTYPEDEVELOPERNAME)
                                               )
                                    ];
            System.debug('In ZZZ TrgtAndPlningCont-->getTargetAmountByUserDivision_M-->prodList-->'+prodList);
            if(!prodList.isEmpty()){
                return prodList;    
            }else{
                return null;
            }    
        }else{
            List<Object> fobjList = new  List<Object>();
            System.debug('In ZZZ TrgtAndPlningCont-->getTargetAmountByUserDivision_M-->IN INTERNATIONAL-->');
            //FOR INTERNATIONAL
            year = Constants.CURRENT_FISCALYEAR; // Setting year as fiscal year
            
            List<String> accInternationalRecTypeLst =  new List<String>();
            accInternationalRecTypeLst.add(Constants.ACCOUNT_OPTHALMICVISION_RECORDTYPE_DEVELOPERNAME);
            accInternationalRecTypeLst.add(Constants.ACCOUNT_ORTHODERMAL_RECORDTYPE_DEVELOPERNAME);
            List<Product__c> prodList2 = [Select Id,Name,Division__c,MSP__c,Dummy_Product_Description__c,Dummy_Product_Code__c,
                                          (Select Id,Name,Remaining_Qty__c,Product__c,Account__c,Target_Amount__c,Target_Quantity__c,Month__c,Sales_User__c,AOP_Mapping_code__c,Year__c,Financial_Year_Date__c,Financial_Year__c,Account__r.SAP_Code__c,Account__r.Owner.Employee_Code__c
                                           From Monthly_AOP__r 
                                           Where 
                                           //      Year__c=: year 
                                           Financial_Year__c=: year //added on 05042019
                                           AND Sales_User__c =: UserInfo.getUserId()
                                           AND Recordtype.DeveloperName =: Constants.MONTHLYAOP_INTERNATIONAL_RECORDTYPE_DEVELOPERNAME
                                           AND Account__c != NULL AND Product__c != NULL
                                           AND Account__r.RecordType.DeveloperName IN : accInternationalRecTypeLst
                                          )
                                          //AND Account__c != NULL)
                                          From Product__c
                                          Where Division__c IN : divList
                                          AND Id IN (SELECT Product__c 
                                                     FROM Monthly_AOP__c
                                                     WHERE 
                                                     //Year__c=: year
                                                     Financial_Year__c=: year //added on 05042019
                                                     AND Sales_User__c =: UserInfo.getUserId()
                                                     AND Recordtype.DeveloperName =: Constants.MONTHLYAOP_INTERNATIONAL_RECORDTYPE_DEVELOPERNAME
                                                     AND Account__c != NULL AND Product__c != NULL
                                                     AND Account__r.RecordType.DeveloperName IN : accInternationalRecTypeLst
                                                    )
                                          
                                         ];
            System.debug('In ZZZ TrgtAndPlningCont-->getTargetAmountByUserDivision_M-->PROD LST-->'+prodList2);
            if(!prodList2.isEmpty()){
					return prodList2;    
			   }else{
					return null;
			   }
                    
            
        }
        
    }
    
    // Return Account that has Monthly Plan Records otherwise the account is not activated.
    @AuraEnabled //(cacheable=true)
    public static List<Monthly_Plan__c> getAccounts( String month, String year, String demographic ){
        List<String> divList = new  List<String>();
        User usr = [Select Id,Name,Division__c From User Where Id=: UserInfo.getUserId()];
        if(usr.Division__c != null){
            String divisions = usr.Division__c;
            if(divisions.contains(';')){
                divList = divisions.split(';');    
            }else{
                //if user has only one division.
                divList.add(divisions); 
            }
            
            // System.debug('Div LIST-->'+divList);
        }
        if(demographic == Constants.DEMOGRAPHIC_DOMESTIC){
            // Not setting coz of MPP  (Year__c value on MPP is saved from Monthly Plan's Year__c field)
            //year = Constants.CURRENT_FISCALYEAR; // Setting year as fiscal year 
            System.debug('ZZZ IN Target&PlanCon-->getAcc_M--> Inside Domestic!!!');
            
            if((month == 'Jan' || month == 'Feb' || month == 'Mar') && year == Constants.CURRENT_FISCALYEAR ){
                Integer newYear = Integer.valueOf(year) + 1; 
                year = String.valueOf(newYear);
                //System.debug('ZZZ NEW YEAR-->'+year);
            }
            
            return     [ Select Name,Month__c,Year__c,Financial_Year__c,Financial_Year_Date__c,Account__c,Account__r.Name,Account__r.CE_Rating__c,Account__r.CIS_Rating__c,Account__r.OwnerId,Account__r.SAP_Code__c,Account__r.Status__c,Account__r.RecordType.DeveloperName,
                        (Select Id,Name,Month__c,Monthly_Plan__c,Year__c,Planned_Amount__c,Planned_Quantity__c,User__c,Product__c,Monthly_Target__c
                         From Monthly_Product_Plans__r Where Month__c=: month 
                         AND Year__c=: year //coz in front end while Saving MPP Year is MonthlyPlan's Year__c(mp.Year__c )
                         AND Monthly_Target__c != NULL AND Product__c != null
                         AND Monthly_Target__r.Financial_Year__c=:Constants.CURRENT_FISCALYEAR
                         AND Monthly_Target__r.Recordtype.DeveloperName =: Constants.MONTHLYAOP_DOMESTIC_RECORDTYPE_DEVELOPERNAME)
                        From Monthly_Plan__c
                        //         Where Month__c=: month AND Year__c=: year
                        Where Month__c=: month AND Financial_Year__c=: Constants.CURRENT_FISCALYEAR  // Using Fiscal Year
                        //AND Account__r.OwnerId =:UserInfo.getUserId()
                        AND Account__r.Status__c =:Constants.ACCOUNT_STATUS_ACTIVATED 
                        AND (Account__r.RecordType.DeveloperName =:Constants.ACCOUNT_DOM_DISTRIBUTOR_RECORDTYPEDEVELOPERNAME
                             OR Account__r.RecordType.DeveloperName =:Constants.ACCOUNT_DOM_DOCTOR_RECORDTYPEDEVELOPERNAME)
                        //only show mp with mpp not nulll  AND Id IN (Select Monthly_Plan__c From Monthly_Product_Plan__c Where Month__c=: month and Year__c=: year And Product__c != null AND Monthly_Plan__c != null AND Monthly_Target__c != NULL)
                        //ORDER BY  Account__r.Status__c
                       ];    
        }else if(demographic == Constants.DEMOGRAPHIC_TURKEY){
            System.debug('ZZZ IN Target&PlanCon-->getAcc_M--> Inside Turkey!!!');
            
            return     [ Select Name,Month__c,Year__c,Financial_Year__c,Financial_Year_Date__c,Account__c,Account__r.Name,Account__r.CE_Rating__c,Account__r.CIS_Rating__c,Account__r.OwnerId,Account__r.SAP_Code__c,Account__r.Status__c,Account__r.RecordType.DeveloperName,
                        (Select Id,Name,Month__c,Monthly_Plan__c,Year__c,Planned_Amount__c,Planned_Quantity__c,User__c,Product__c,Monthly_Target__c
                         From Monthly_Product_Plans__r Where Month__c=: month 
                         AND Year__c=: year //coz in front end while Saving MPP Year is MonthlyPlan's Year__c(mp.Year__c )
                         AND Monthly_Target__c != NULL AND Product__c != null
                         AND Monthly_Target__r.Recordtype.DeveloperName =: Constants.MONTHLYAOP_TURKEY_RECORDTYPE_DEVELOPERNAME)
                        From Monthly_Plan__c
                        Where Month__c=: month AND Year__c=: year
                        
                        //AND Account__r.OwnerId =:UserInfo.getUserId()
                        AND Account__r.Status__c =:Constants.ACCOUNT_STATUS_ACTIVATED 
                        AND  (Account__r.RecordType.DeveloperName =:Constants.ACCOUNT_TURKEY_DISTRIBUTOR_RECORDTYPEDEVELOPERNAME
                              OR Account__r.RecordType.DeveloperName =:Constants.ACCOUNT_TURKEY_DOCTOR_RECORDTYPEDEVELOPERNAME)
                        //only show mp with mpp not nulll  AND Id IN (Select Monthly_Plan__c From Monthly_Product_Plan__c Where Month__c=: month and Year__c=: year And Product__c != null AND Monthly_Plan__c != null AND Monthly_Target__c != NULL)
                        //ORDER BY  Account__r.Status__c
                       ];    
        }else{
            System.debug('ZZZ IN Target&PlanCon-->getAcc_M--> Inside International!!!');
            // year = Constants.CURRENT_FISCALYEAR; // Setting year as fiscal year
            if((month == 'Jan' || month == 'Feb' || month == 'Mar') && year == Constants.CURRENT_FISCALYEAR ){
                Integer newYear = Integer.valueOf(year) + 1; 
                year = String.valueOf(newYear);
                //System.debug('ZZZ NEW YEAR-->'+year);
            }
            
            // For International
            
            return     [ Select Name,Month__c,Year__c,Financial_Year__c,Financial_Year_Date__c,Account__c,Account__r.Name,Account__r.CE_Rating__c,Account__r.CIS_Rating__c,Account__r.OwnerId,Account__r.SAP_Code__c,Account__r.Status__c,
                        (Select Id,Name,Month__c,Monthly_Plan__c,Year__c,Planned_Amount__c,Planned_Quantity__c,User__c,Product__c,Monthly_Target__c,Monthly_Target__r.Account__c
                         From Monthly_Product_Plans__r
                         WHERE  Month__c=: month 
                         AND Year__c=: year 
                         AND Monthly_Target__c != NULL AND Product__c != null
                         AND Monthly_Target__r.Financial_Year__c=:Constants.CURRENT_FISCALYEAR 
                         AND Monthly_Target__r.RecordType.DeveloperName =:Constants.MONTHLYAOP_INTERNATIONAL_RECORDTYPE_DEVELOPERNAME
                         AND Monthly_Target__r.Account__c != NULL)
                        From Monthly_Plan__c
                        ////Changed on 030419   Where Month__c=: month AND Year__c=: year
                        Where Month__c=: month AND Financial_Year__c=: Constants.CURRENT_FISCALYEAR
                        AND Account__c != NULL
                        //AND Account__r.OwnerId =:UserInfo.getUserId()
                        AND Account__r.Status__c =:Constants.ACCOUNT_STATUS_ACTIVATED 
                        AND (Account__r.RecordType.DeveloperName =: Constants.ACCOUNT_OPTHALMICVISION_RECORDTYPE_DEVELOPERNAME 
                             OR Account__r.RecordType.DeveloperName =: Constants.ACCOUNT_ORTHODERMAL_RECORDTYPE_DEVELOPERNAME)
                        AND Account__c IN (Select Account__c
                                           From Monthly_AOP__c 
                                           Where 
                                           //Year__c=: year 
                                           Financial_Year__c=: Constants.CURRENT_FISCALYEAR  // added on 05042019
                                           AND Recordtype.DeveloperName =: Constants.MONTHLYAOP_INTERNATIONAL_RECORDTYPE_DEVELOPERNAME
                                           AND Account__c != NULL
                                           AND Product__c != NULL
                                           AND Product__r.Division__c IN : divList)
                       ];   
            
        }
        
        
    }
    
    /*  @AuraEnabled
public static List<Account> getAccountInt( String month, String year, String demographic ){
List<String> accInternationalRecTypeLst =  new List<String>();
accInternationalRecTypeLst.add(Constants.ACCOUNT_OPTHALMICVISION_RECORDTYPE_DEVELOPERNAME);
accInternationalRecTypeLst.add(Constants.ACCOUNT_ORTHODERMAL_RECORDTYPE_DEVELOPERNAME);
return [SELECT Id,Name,OwnerId,Status__c
FROM Account
WHERE 
];
}*/
    
    
    
    @AuraEnabled
    public static void saveMPPS(List<Monthly_Product_Plan__c> mppList,String month,String year,String demographic){
        if(demographic == Constants.DEMOGRAPHIC_DOMESTIC){
            System.debug('In Domestic!!!');
            System.debug('In ZZZ TrgtAndPlningCont-->In Domestic-->saveMPPS_M-->Recvd List-->'+mppList);
            List<Monthly_Product_Plan__c> existingMppLst = new List<Monthly_Product_Plan__c>();
            existingMppLst = TargetAndPlanningController.getExistingMPP(month,year,Constants.DEMOGRAPHIC_DOMESTIC);
            List<Monthly_Product_Plan__c> mppList2Insert = new List<Monthly_Product_Plan__c>();
            List<Monthly_Product_Plan__c> mppList2Update = new List<Monthly_Product_Plan__c>();
            
            
            System.debug('In ZZZ TrgtAndPlningCont-->In Domestic-->saveMPPS_M-->Existing List-->'+existingMppLst);
            //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Existing List () ??-->'+existingMppLst.isEmpty());
            // System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Existing List SIZE > 0 ??-->'+existingMppLst.size() > 0);
            for(Monthly_Product_Plan__c mpp : mppList ){
                if(!existingMppLst.isEmpty() && existingMppLst.size() > 0  ){
                    //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Inside 1st IF !!!!!!');
                    for(Monthly_Product_Plan__c exmpp : existingMppLst ){
                        //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->curr MPP-->'+mpp);
                        //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->exis MPP-->'+exmpp);
                        //Should add Monthly_Target__c as well below for comparison
                        if( exmpp.Month__c == mpp.Month__c && exmpp.Year__c == mpp.Year__c 
                           && exmpp.Product__c == mpp.Product__c && exmpp.Monthly_Plan__c == mpp.Monthly_Plan__c
                           && exmpp.Monthly_Target__c == mpp.Monthly_Target__c && exmpp.MPP_Mapping__c == mpp.MPP_Mapping__c){
                               //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Inside 2nd IF !!!!!!');
                               if(exmpp.Planned_Quantity__c != mpp.Planned_Quantity__c){
                                   //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Inside 3rd IF !!!!!!');
                                   exmpp.Planned_Quantity__c = mpp.Planned_Quantity__c;
                                   mppList2Update.add(exmpp);
                               }
                           }
                    }
                    
                }else{
                    //throw new TargetAndPlanningControllerException('No Existing Mpp Record Found!!');
                } 
            }
            
            for(Monthly_Product_Plan__c newMPP : mppList ){
                
                if(mppList2Update.isEmpty()){ 
                    System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->In NEW MPP  !!!!!!!!!');
                    Monthly_Product_Plan__c newmp = new Monthly_Product_Plan__c();
                    newmp.Month__c = newMPP.Month__c;
                    newmp.Year__c  = newMPP.Year__c;
                    newmp.Product__c = newMPP.Product__c;
                    newmp.Monthly_Plan__c = newMPP.Monthly_Plan__c;
                    newmp.User__c     = newMPP.User__c;
                    newmp.Planned_Quantity__c = newMPP.Planned_Quantity__c;
                    newmp.Monthly_Target__c   = newMPP.Monthly_Target__c;
                    newmp.Financial_Year_Date__c = newMPP.Financial_Year_Date__c; //Added on 03042019
                    newmp.MPP_Mapping__c    = newMPP.MPP_Mapping__c; // Added on 10042019
                    mppList2Insert.add(newmp);
                }
                
            }
            
            if(!mppList2Insert.isEmpty()){
                //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Insert List SZIE-->'+mppList2Insert.size());
                //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Insert List-->'+mppList2Insert);
                insert mppList2Insert;
            }
            
            if(!mppList2Update.isEmpty()){
                // System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Update List SIZE-->'+mppList2Update.size());
                // System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Update List-->'+mppList2Update);
                update mppList2Update;
            }
            
        }else if(demographic == Constants.DEMOGRAPHIC_TURKEY){
            System.debug('In Turkey!!!');
            System.debug('In ZZZ TrgtAndPlningCont-->In TURKEY-->saveMPPS_M-->Recvd List-->'+mppList);
            List<Monthly_Product_Plan__c> existingMppLst = new List<Monthly_Product_Plan__c>();
            existingMppLst = TargetAndPlanningController.getExistingMPP(month,year,Constants.DEMOGRAPHIC_TURKEY);
            List<Monthly_Product_Plan__c> mppList2Insert = new List<Monthly_Product_Plan__c>();
            List<Monthly_Product_Plan__c> mppList2Update = new List<Monthly_Product_Plan__c>();
            
            
            System.debug('In ZZZ TrgtAndPlningCont-->In Domestic-->saveMPPS_M-->Existing List-->'+existingMppLst);
            //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Existing List () ??-->'+existingMppLst.isEmpty());
            // System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Existing List SIZE > 0 ??-->'+existingMppLst.size() > 0);
            for(Monthly_Product_Plan__c mpp : mppList ){
                if(!existingMppLst.isEmpty() && existingMppLst.size() > 0  ){
                    //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Inside 1st IF !!!!!!');
                    for(Monthly_Product_Plan__c exmpp : existingMppLst ){
                        //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->curr MPP-->'+mpp);
                        //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->exis MPP-->'+exmpp);
                        //Should add Monthly_Target__c as well below for comparison
                        if( exmpp.Month__c == mpp.Month__c && exmpp.Year__c == mpp.Year__c 
                           && exmpp.Product__c == mpp.Product__c && exmpp.Monthly_Plan__c == mpp.Monthly_Plan__c
                           && exmpp.Monthly_Target__c == mpp.Monthly_Target__c && exmpp.MPP_Mapping__c == mpp.MPP_Mapping__c){
                               //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Inside 2nd IF !!!!!!');
                               if(exmpp.Planned_Quantity__c != mpp.Planned_Quantity__c){
                                   //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Inside 3rd IF !!!!!!');
                                   exmpp.Planned_Quantity__c = mpp.Planned_Quantity__c;
                                   mppList2Update.add(exmpp);
                               }
                           }
                    }
                    
                }else{
                    //throw new TargetAndPlanningControllerException('No Existing Mpp Record Found!!');
                } 
            }
            
            for(Monthly_Product_Plan__c newMPP : mppList ){
                
                if(mppList2Update.isEmpty()){ 
                    System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->In NEW MPP  !!!!!!!!!');
                    Monthly_Product_Plan__c newmp = new Monthly_Product_Plan__c();
                    newmp.Month__c = newMPP.Month__c;
                    newmp.Year__c  = newMPP.Year__c;
                    newmp.Product__c = newMPP.Product__c;
                    newmp.Monthly_Plan__c = newMPP.Monthly_Plan__c;
                    newmp.User__c     = newMPP.User__c;
                    newmp.Planned_Quantity__c = newMPP.Planned_Quantity__c;
                    newmp.Monthly_Target__c   = newMPP.Monthly_Target__c;
                    newmp.Financial_Year_Date__c = newMPP.Financial_Year_Date__c; //Added on 03042019
                    newmp.MPP_Mapping__c    = newMPP.MPP_Mapping__c; // Added on 10042019
                    mppList2Insert.add(newmp);
                }
                
            }
            
            if(!mppList2Insert.isEmpty()){
                //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Insert List SZIE-->'+mppList2Insert.size());
                //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Insert List-->'+mppList2Insert);
                insert mppList2Insert;
            }
            
            if(!mppList2Update.isEmpty()){
                // System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Update List SIZE-->'+mppList2Update.size());
                // System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Update List-->'+mppList2Update);
                update mppList2Update;
            }
            
        }else{
            System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->In International !!');
            //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Recvd List-->'+mppList);
            List<Monthly_Product_Plan__c> existingMppLst = new List<Monthly_Product_Plan__c>();
            existingMppLst = TargetAndPlanningController.getExistingMPP(month,year,Constants.DEMOGRAPHIC_INTERNATIONAL);
            List<Monthly_Product_Plan__c> mppList2Insert = new List<Monthly_Product_Plan__c>();
            List<Monthly_Product_Plan__c> mppList2Update = new List<Monthly_Product_Plan__c>();
            
            
            System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Existing List-->'+existingMppLst);
            // System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Existing List () ??-->'+existingMppLst.isEmpty());
            // System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Existing List SIZE > 0 ??-->'+existingMppLst.size() > 0);
            for(Monthly_Product_Plan__c mpp : mppList ){
                if(!existingMppLst.isEmpty() && existingMppLst.size() > 0){
                    // System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Inside 1st IF !!!!!!');
                    for(Monthly_Product_Plan__c exmpp : existingMppLst ){
                        // System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->curr MPP-->'+mpp);
                        // System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->exis MPP-->'+exmpp);
                        if( exmpp.Month__c == mpp.Month__c && exmpp.Year__c == mpp.Year__c 
                           && exmpp.Product__c == mpp.Product__c && exmpp.Monthly_Plan__c == mpp.Monthly_Plan__c 
                           && exmpp.Monthly_Target__c == mpp.Monthly_Target__c && exmpp.MPP_Mapping__c == mpp.MPP_Mapping__c){
                               //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Inside 2nd IF !!!!!!');
                               if(exmpp.Planned_Quantity__c != mpp.Planned_Quantity__c){
                                   //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Inside 3rd IF !!!!!!');
                                   exmpp.Planned_Quantity__c = mpp.Planned_Quantity__c;
                                   mppList2Update.add(exmpp);
                               }
                           }
                    }
                    
                }   
            }
            
            for(Monthly_Product_Plan__c newMPP : mppList ){
                if(mppList2Update.isEmpty()){ 
                    System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->INT-->In NEW MPP !!!!!!!!!');
                    Monthly_Product_Plan__c newmp = new Monthly_Product_Plan__c();
                    newmp.Month__c = newMPP.Month__c;
                    newmp.Year__c  = newMPP.Year__c;
                    newmp.Product__c = newMPP.Product__c;
                    newmp.Monthly_Plan__c = newMPP.Monthly_Plan__c;
                    newmp.User__c     = newMPP.User__c;
                    newmp.Planned_Quantity__c = newMPP.Planned_Quantity__c;
                    newmp.Monthly_Target__c = newMPP.Monthly_Target__c; // For International
                    newmp.Financial_Year_Date__c = newMPP.Financial_Year_Date__c; //Added on 03042019
                    newmp.MPP_Mapping__c    = newMPP.MPP_Mapping__c; // Added on 10042019
                    mppList2Insert.add(newmp);
                    
                }
                
                
            }
            
            if(!mppList2Insert.isEmpty()){
                //System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Insert List SZIE-->'+mppList2Insert.size());
                System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Insert List-->'+mppList2Insert);
                insert mppList2Insert;
            }
            
            if(!mppList2Update.isEmpty()){
                // System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Update List SIZE-->'+mppList2Update.size());
                System.debug('In ZZZ TrgtAndPlningCont-->saveMPPS_M-->Update List-->'+mppList2Update);
                update mppList2Update;
            }
        }
        
    }
    
    public static List<Monthly_Product_Plan__c> getExistingMPP(String month, String year,String demographic){
        if(demographic == Constants.DEMOGRAPHIC_DOMESTIC){
            //Added on 11042019 
            //Setting year as (year + 1) because Jan,Feb,March will be always (year + 1) if current year is same as fiscal year
            //And also in the frond-end we are setting MPP's year as same of Monthly Plan's "Year__c" field.
            if((month == 'Jan' || month == 'Feb' || month == 'Mar') && year == Constants.CURRENT_FISCALYEAR ){
                Integer newYear = Integer.valueOf(year) + 1; 
                year = String.valueOf(newYear);
                System.debug('ZZZ NEW YEAR-->'+year);
            }
            
            List<Monthly_Product_Plan__c> monprod = [Select Id,Name,Month__c,Monthly_Plan__c,Year__c,Planned_Amount__c,Planned_Quantity__c,User__c,Product__c,Monthly_Target__c,MPP_Mapping__c
                                                     From Monthly_Product_Plan__c
                                                     Where Month__c =: month
                                                     AND Year__c =: year
                                                     AND Monthly_Target__r.Financial_Year__c =:Constants.CURRENT_FISCALYEAR //Added on 11042019  
                                                     AND Monthly_Plan__r.Financial_Year__c =:Constants.CURRENT_FISCALYEAR
            //NEED TO ASK THIS added on15042019      AND User__c =: UserInfo.getUserId()
           /* NEED TO ASK THIS*/                     AND Monthly_Target__r.RecordType.DeveloperName =:Constants.MONTHLYAOP_DOMESTIC_RECORDTYPE_DEVELOPERNAME
                                                     AND (Monthly_Plan__r.Account__r.RecordType.DeveloperName =: Constants.ACCOUNT_DOM_DISTRIBUTOR_RECORDTYPEDEVELOPERNAME
                                                          OR Monthly_Plan__r.Account__r.RecordType.DeveloperName =: Constants.ACCOUNT_DOM_DOCTOR_RECORDTYPEDEVELOPERNAME)
                                                     
                                                    ];
            System.debug('In TargetPlanCont.cls-->getExistingMPP_M-->DOM-->SOQL Result-->'+monprod);
            if( ! monprod.isEmpty() ){
                return monprod;
            }else{
                return new List<Monthly_Product_Plan__c>();
            }
        }else if(demographic == Constants.DEMOGRAPHIC_TURKEY){
            List<Monthly_Product_Plan__c> monprod = [Select Id,Name,Month__c,Monthly_Plan__c,Year__c,Planned_Amount__c,Planned_Quantity__c,User__c,Product__c,Monthly_Target__c,MPP_Mapping__c
                                                     From Monthly_Product_Plan__c
                                                     Where Month__c =: month
                                                     AND Year__c =: year
           /* NEED TO ASK THIS*/                     AND Monthly_Target__r.RecordType.DeveloperName =:Constants.MONTHLYAOP_TURKEY_RECORDTYPE_DEVELOPERNAME
                                                    ];
            System.debug('In TargetPlanCont.cls-->getExistingMPP_M-->TURKEY-->SOQL Result-->'+monprod);
            if( ! monprod.isEmpty() ){
                return monprod;
            }else{
                return new List<Monthly_Product_Plan__c>();
            }
        }else{
            //For International
            
            List<String> accInternationalRecTypeLst =  new List<String>();
            accInternationalRecTypeLst.add(Constants.ACCOUNT_OPTHALMICVISION_RECORDTYPE_DEVELOPERNAME);
            accInternationalRecTypeLst.add(Constants.ACCOUNT_ORTHODERMAL_RECORDTYPE_DEVELOPERNAME);
            //FOR International
            System.debug('ZZZ MONTH-->'+month);
            System.debug('ZZZ YEAR-->'+year);
            
            //Added on 11042019 
            //Setting year as (year + 1) because Jan,Feb,March will be always (year + 1) if current year is same as fiscal year
            //And also in the frond-end we are setting MPP's year as same of Monthly Plan's "Year__c" field.
            if((month == 'Jan' || month == 'Feb' || month == 'Mar') && year == Constants.CURRENT_FISCALYEAR ){
                Integer newYear = Integer.valueOf(year) + 1; 
                year = String.valueOf(newYear);
                System.debug('ZZZ NEW YEAR-->'+year);
            }
            
            List<Monthly_Product_Plan__c> monprod = [Select Id,Name,MPP_Mapping__c,Financial_Year_Date__c,Month__c,Year__c,Planned_Amount__c,Planned_Quantity__c,User__c,Product__c,Monthly_Target__c,Monthly_Plan__c,Monthly_Target__r.Account__c,Monthly_Plan__r.Account__c
                                                     From Monthly_Product_Plan__c
                                                     Where Month__c =: month
                                                     AND Year__c =: year
                                                     AND Monthly_Target__r.Financial_Year__c =:Constants.CURRENT_FISCALYEAR //Added on 11042019  
                                                     AND Monthly_Plan__r.Financial_Year__c =:Constants.CURRENT_FISCALYEAR   //Added on 11042019  
                                                     AND Monthly_Target__r.RecordType.DeveloperName =:Constants.MONTHLYAOP_INTERNATIONAL_RECORDTYPE_DEVELOPERNAME
                                                     AND Monthly_Plan__r.Account__r.RecordType.DeveloperName IN :accInternationalRecTypeLst
                                                    ];
            if( ! monprod.isEmpty() ){
                return monprod;
            }else{
                return new List<Monthly_Product_Plan__c>();
            }
        }
        
    }
    
    //Used in International market
    // Now as of 15042019 used in all Markets
    @InvocableMethod(label='Rollup Planned Qty' description='This method rollup the sum of all planned qty of MPP in a AOP')
    public static void updateAOPs(List<ID> mopIds) {
        Set<ID> monthlyAopIds = new Set<ID>(mopIds);
        TargetAndPlanningController.rollUpSumOfPlannedQtyToAOP(monthlyAopIds);  
    }
    
    @future
    public static void rollUpSumOfPlannedQtyToAOP (Set<ID> aopIdsToRoll){
        new TargetAndPlanningController().summarizePlannedQtyOnAOP(aopIdsToRoll);   
    }
    
    public void summarizePlannedQtyOnAOP(Set<Id> maopIds){
        List<Monthly_AOP__c> mAopToUpdate = new List<Monthly_AOP__c>();
        
        List<Monthly_AOP__c> aops = queryAOPsById(maopIds);
        
        Map<Id,Decimal> summedQtyByAopId = getRolledUpPlannedQtyByAopId(maopIds);
        
        for(Monthly_AOP__c aop : aops){
            Decimal totalSummedQty = 0;
            
            if (summedQtyByAopId.containsKey(aop.Id)) {
                totalSummedQty = summedQtyByAopId.get(aop.Id);
            }
            
            //Determine if Total Qty has Changed
            if (aop.Remaining_Qty__c != totalSummedQty || aop.Planned_Quantity__c != totalSummedQty) {
                aop.Remaining_Qty__c = totalSummedQty;
                aop.Planned_Quantity__c = totalSummedQty;
                System.debug('AOP FIELDS-->'+aop);
                mAopToUpdate.add(aop); //Add aop to collection to be updated
            }
        }
        
        if(mAopToUpdate.isEmpty() == false){
            Database.SaveResult[] saveResults = Database.update(mAopToUpdate, false);
            System.debug(saveResults);
        }
        
        
    }
    
    
    
    private Map<Id,Decimal> getRolledUpPlannedQtyByAopId(Set<Id> mAopIds){
        Map<Id,Decimal> resultsByAopId = new Map<Id,Decimal>();
        
        
        //Summarize Won Opportunity Amounts by Account Id
        AggregateResult[] results = getAggregatePlannedQty(mAopIds);
        
        for (AggregateResult result : results) {
            Id nAOPId = (Id) result.get('AOPId');
            Decimal total = (Decimal) result.get('TotalQty');
            resultsByAopId.put(nAOPId, total);
        }
        return resultsByAopId;
    }
    
    private AggregateResult[] getAggregatePlannedQty(Set<Id> aopIds){
        return   [SELECT Monthly_Target__c AOPId  ,SUM(Planned_Quantity__c) TotalQty 
                  FROM Monthly_Product_Plan__c
                  Where Monthly_Target__c IN : aopIds
 // on 15042019   AND Monthly_Target__r.RecordType.DeveloperName =:Constants.MONTHLYAOP_INTERNATIONAL_RECORDTYPE_DEVELOPERNAME
                  GROUP BY Monthly_Target__c];
        
    }
    private List<Monthly_AOP__c> queryAOPsById(Set<Id> aopIds){
        return [Select Id,Target_Quantity__c,Remaining_Qty__c,Planned_Quantity__c	
                From Monthly_AOP__c Where Id IN : aopIds
               ];
    }
    
    
    //Test method for creating product and its unique aop using serialize and deserialize
   /* @AuraEnabled
    public static List<Object> getProductTest(String month,String year){
        List<String> divList = new  List<String>();
        List<Object> fobjList = new  List<Object>();
        List<String> finalProductString = new  List<String>();
        List<Product__c> finalProdLst = new List<Product__c>();
        User usr = [Select Id,Name,Division__c,Employee_Code__c From User Where Id=: UserInfo.getUserId()];
        if(usr.Division__c != null){
            String divisions = usr.Division__c;
            if(divisions.contains(';')){
                divList = divisions.split(';');    
            }else{
                //if user has only one division.
                divList.add(divisions); 
            }
            
            // System.debug('Div LIST-->'+divList);
        }
        
        List<Product__c> prodList = [Select Id,Name,Division__c,MSP__c,Dummy_Product_Description__c,Dummy_Product_Code__c,
                                     (Select Id,Name,Financial_Year_Date__c,Financial_Year__c,Remaining_Qty__c,Product__c,Account__c,Target_Amount__c,Target_Quantity__c,Month__c,Sales_User__c,AOP_Mapping_code__c,Year__c
                                      From Monthly_AOP__r Where Month__c=: month AND Financial_Year__c=: year //Added on 05042019 
                                      AND RecordType.DeveloperName =: Constants.MONTHLYAOP_DOMESTIC_RECORDTYPE_DEVELOPERNAME
                                      //AND Sales_User__c=:UserInfo.getUserId() // Added on 09042019
                                      AND Account__c = null
                                     )
                                     From Product__c
                                     Where Division__c IN : divList
                                     AND Id IN (SELECT Product__c 
                                                FROM Monthly_AOP__c
                                                WHERE Month__c=: month 
                                                AND Financial_Year__c=:year //Added on 05042019 
                                                AND Recordtype.DeveloperName =: Constants.MONTHLYAOP_DOMESTIC_RECORDTYPE_DEVELOPERNAME
                                               )
                                    ];
        
        for(Product__c prod : prodList){
            
            String uniqueCode = usr.Employee_Code__c+month+year+prod.Dummy_Product_Code__c;
            for(Monthly_AOP__c aopChild : prod.Monthly_AOP__r){
                if(aopChild.AOP_Mapping_code__c == uniqueCode && aopChild.Product__c == prod.Id){
                    String finalString = '';
                    String prodJson = JSON.serialize(prod);
                    //System.debug('In TrgetAndPLanninCOn-->OG prodJson-->'+prodJson);
                    //System.debug('In TrgetAndPLanninCOn-->prodJson-->{'+prodJson.substring(104,prodJson.indexOf('Monthly_AOP__r') -1)+'\"Monthly_AOP__r\"'+':[');
                    //
                    //Starting at position "104" because when you serialize you get standard sobject's REST API response format
                    //Which includes url,attribute,etc. at the start, so removing all the extra starting stuff.
                    //And stopping before child which is Monthly_AOP__r. 
                    finalString += '{'+prodJson.substring(104,prodJson.indexOf('Monthly_AOP__r') -1)+'\"Monthly_AOP__r\"'+':[';
                    String aopJSON  = JSON.serialize(aopChild);
                    //System.debug('In TrgetAndPLanninCOn-->OG aopJSON-->'+aopJSON);
                    //System.debug('In TrgetAndPLanninCOn-->cropped "" aopJSON-->{'+aopJSON.substring(112,aopJSON.lastIndexOf('"'))+'}');
                    //System.debug('In TrgetAndPLanninCOn-->cropped aopJSON-->{'+aopJSON.substring(112,aopJSON.lastIndexOf('Year__c')+15)+'}');
                    //finalString += '{'+aopJSON.substring(112,aopJSON.lastIndexOf('Year__c')+15)+'}]}';
                    finalString += '{'+aopJSON.substring(112,aopJSON.lastIndexOf('"'))+'"}]}';
                    System.debug('In TrgetAndPLanninCOn-->FinalString-->'+finalString);
                    //string.escapeSingleQuotes(theQuery)
                    //finalProductString.add(finalString);
                    
                    // Again deserializing it to object form because it adds '\' to the output string(which seems standard behaviour for apex) in the Lightning Comp's apex response.
                    Object n = JSON.deserializeUntyped(finalString); 
                    fobjList.add(n);
                    // finalProductString.add(string.escapeSingleQuotes(finalString));
                }
            }
            
        }
        //List<Product__c> n = (List<Product__c>)JSON.deserialize(finalProductString, List<Product__c>.class);
        // System.debug('In TrgetAndPLanninCOn-->FinalProdString-->'+finalProductString);\
        //for(String s : finalProductString){
        //    Object n = JSON.deserializeUntyped(s);
		//	  System.debug('Prod-->'+n);
		//	  fobjList.add(n);
        //     }
        return fobjList;
    }
     */

    public class TargetAndPlanningControllerException extends Exception {}
    
    
    
}
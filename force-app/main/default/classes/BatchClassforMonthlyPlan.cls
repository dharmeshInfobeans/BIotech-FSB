global class BatchClassforMonthlyPlan implements Database.Batchable<sObject>,Database.Stateful,Database.AllowsCallouts{
    public String fisYear;
        
    global Database.QueryLocator start(Database.BatchableContext BC)
    {
        Integer fyear = 0;
        
        String str = [SELECT FiscalYearSettings.Name FROM Period WHERE Type = 'Year' AND StartDate <= TODAY AND EndDate >= TODAY].FiscalYearSettings.Name;
        fyear = Integer.valueOf(str)-1; // calculate last fiscal year
        fisYear = String.valueOf(fyear);
        
        //string query = 'Select Id, Name, Account__c, Month__c, Financial_Year__c, Year__c, Last_Year_Monthly_Plan__c, Account__r.Status__c, Account__r.SAP_Code__c, Account__r.RecordType.DeveloperName  From Monthly_Plan__c Where Financial_Year__c=\''+fisYear+'\' AND Account__r.Status__c=\'Activated\'  AND (Account__r.RecordType.DeveloperName=\''+Constants.ACCOUNT_Customers_RECORDTYPEDEVELOPERNAME+'\' OR Account__r.RecordType.DeveloperName=\''+Constants.ACCOUNT_Distributor_RECORDTYPEDEVELOPERNAME+'\' OR Account__r.RecordType.DeveloperName=\''+Constants.ACCOUNT_B2B2C_RECORDTYPEDEVELOPERNAME+'\' )';
        Set<String> accRecordTypeDevName = new Set<String>{Constants.ACCOUNT_DOM_DISTRIBUTOR_RECORDTYPEDEVELOPERNAME,Constants.ACCOUNT_DOM_DOCTOR_RECORDTYPEDEVELOPERNAME,Constants.ACCOUNT_TURKEY_DISTRIBUTOR_RECORDTYPEDEVELOPERNAME,Constants.ACCOUNT_TURKEY_DOCTOR_RECORDTYPEDEVELOPERNAME,Constants.ACCOUNT_OPTHALMICVISION_RECORDTYPE_DEVELOPERNAME,Constants.ACCOUNT_ORTHODERMAL_RECORDTYPE_DEVELOPERNAME};
        String query = 'Select Id,Name,SAP_Code__c,Status__c,RecordType.DeveloperName, (Select Id, Name, Month__c, Financial_Year__c, Year__c, Last_Year_Monthly_Plan__c, Account__c, Account__r.SAP_Code__c  From Monthly_Plans__r Where (Financial_Year__c = \''+fisYear+'\' AND Financial_Year__c != null) ) From Account Where Status__c = \'Activated\' AND Id IN (Select Account__c From Monthly_Plan__c Where (Financial_Year__c = \''+fisYear+'\' AND Financial_Year__c != null )  ) AND RecordType.DeveloperName IN : accRecordTypeDevName';
        system.debug('In ZZZ BatchClassforMonthlyPlan.cls-->Start_M-->Query-->'+query);
        system.debug('In ZZZ BatchClassforMonthlyPlan.cls-->IN START_M-->Str FISYEAR->+'+fisYear);
        return Database.getQueryLocator(query);
        
    }
    
    global void execute(Database.BatchableContext BC, List<Account> faccList)
    {
        
        system.debug('In ZZZ BatchClassforMonthlyPlan.cls-->Str FISYEAR->+'+fisYear);
        // system.debug('In ZZZ BatchClassforMonthlyPlan.cls-->Excute_M-->MP list-->+'+mpList);
        List<AccountProcessHandler.MonthlyPlanCreationRequest> mpcrList = new List<AccountProcessHandler.MonthlyPlanCreationRequest>();
        Map<Id,List<Monthly_Plan__c>> accAndItsMP = new Map<Id,List<Monthly_Plan__c>>();
        
        // Storing all monthly plans against each account
        for(Account acc : faccList){
            if(acc.Monthly_Plans__r != null){
                accAndItsMP.put(acc.id,acc.Monthly_Plans__r);    
            } 
        }
        
        For(Id accId : accAndItsMP.keyset()){
        	   AccountProcessHandler.MonthlyPlanCreationRequest mpcr = new AccountProcessHandler.MonthlyPlanCreationRequest();
        	   mpcr.numberOfMonthlyPlanRecords = 12;
        	   mpcr.accountId = accId;
               mpcr.isFromBatch = true;
               mpcr.previousFiscalYear = fisYear; //Current FiscalYear - 1
               mpcr.mPlanList = accAndItsMP.get(accId);
               mpcrList.add(mpcr);
        }
     
            
        AccountProcessHandler.createMonthlyPlanRecords(mpcrList);
        
        
        //AccountHelperClass acc = new AccountHelperClass();
        // acc.CreateMonthlyOpportunity(optyList, new List<Account>());        
    }
    
    global void finish(Database.BatchableContext BC)
    {
        
    }
    
}
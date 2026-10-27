global class BatchAccountActivationQuaterly implements Database.Batchable<sObject>,Database.Stateful {
   	
    global static period lastFQStartEndDt = new period();
    private final date startDate,endDate ;
    private final string activationType;
    
    global BatchAccountActivationQuaterly(string batchType){
        if(batchType=='KRA'){
            lastFQStartEndDt = [Select Id,StartDate,EndDate from period where type = 'QUARTER' AND 
                                StartDate = LAST_QUARTER];
            startDate = lastFQStartEndDt.StartDate;
            endDate = lastFQStartEndDt.EndDate;   
        }else{
            startDate = system.today().toStartOfMonth().addMonths(-3);
            endDate = startDate.addMonths(3).addDays(-1);   
        }
       
        activationType = batchType;
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        String strQuery = 'SELECT Id, Name, OwnerId from Account';
        return Database.getQueryLocator(strQuery);
    }
    
    global void execute(Database.BatchableContext BC, List<Account> scope){
        
        system.debug('***startDate***'+startDate);
        
        set<id> setAccountID = new set <ID>();
        map<string, Id> accountId_Owner = new map<string, Id>();

        System.debug('scope'+scope);
        for (Account objAccount : scope) {
            setAccountID.add(objAccount.Id);
            accountId_Owner.put(objAccount.Id,objAccount.OwnerId );
        }
        
        List<z_Incentive__c> istIncentive = new List<z_Incentive__c>();
        
        AggregateResult[] aggrIncentiveResLst = [Select Count(id) cnt, Account__c accId from z_Incentive__c where
                                                 Billing_Date__c >=:startDate
                                                 and  Billing_Date__c <=: endDate
                                                 and Account__c=:setAccountID
                                                 group by Account__c];
        System.debug('aggrIncentiveResLst'+aggrIncentiveResLst);
        
        List<Account_Activation_History__c> lstHistories = new List<Account_Activation_History__c>();
        
        map<string, integer> accountId_cnt = new map<string, integer>();
        if(aggrIncentiveResLst.size() > 0) {
            for(AggregateResult aggrRes : aggrIncentiveResLst) {
                accountId_cnt.put((string)aggrRes.get('accId'), (integer)aggrRes.get('cnt'));
            }
        }
        
        system.debug('***startDate***'+startDate);
        
        Account_Activation_History__c accHistory  = new Account_Activation_History__c();
        for(Id accountId : setAccountID) {
            accHistory  = new Account_Activation_History__c();
            if(accountId_cnt.containsKey(accountId) && accountId_cnt.get(accountId)>0){
                accHistory.Status__c = 'Active';
            }else{
                accHistory.Status__c = 'In-Active';
            }
            accHistory.Account__c = accountId;
            accHistory.Activation_Type__c = activationType;
            accHistory.Sales_Employee__c = accountId_Owner.get(accountId);
            accHistory.Start_Date__c = startDate;
            accHistory.End_Date__c = endDate;
            accHistory.Batch_Execution_Date__c = system.today();
            lstHistories.add(accHistory);
        }
        
        DATABASE.insert(lstHistories);
        
        system.debug('***lstHistories***'+lstHistories);
    }
    
    global void finish(Database.BatchableContext BC){
        //Done
    }
}
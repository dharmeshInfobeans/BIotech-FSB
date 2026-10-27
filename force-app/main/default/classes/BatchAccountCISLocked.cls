global class BatchAccountCISLocked implements Database.Batchable<sObject>{
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator('SELECT Id FROM Account where Account_Locked__c=false ');
    }
    global void execute(Database.BatchableContext BC, List<Account> scope){
        CIS_Setting__c setting = CIS_Setting__c.getInstance();
        if(setting.CIS_Allowed_Till__c !=null && System.today().day() > setting.CIS_Allowed_Till__c){
        
            String year = ''+System.today().year();
            String month = SubmitCISController.monthMap.get(System.today().day());
            
            Map<String,Integer> CISCountMap = new Map<String,Integer>();
            
            Set<String> accIds = new Set<String>();
            for(Account acc : scope)
                accIds.add(acc.Id);
                
            for(AggregateResult cis : [Select count(id) cnt , Account__c FROM CIS_Header__c where Month__c=:month AND year__c =:year AND Account__c in:accIds GROUP BY Account__c ]){
                CISCountMap.put(''+cis.get('Account__c'),Integer.valueOf(cis.get('cnt')));
            }
            
            List<Account> accUpdate = new List<Account>();
            for(Account acc : scope){
                if(!CISCountMap.containsKey(acc.Id)){
                    acc.Account_Locked__c = true;
                    acc.Account_Locked_Reason__c = 'CIS Not Submitted';
                    accUpdate.add(acc);
                }
            }
            if(accUpdate.size()>0){
                update accUpdate;
            }
        }
        
    }
    
    global void finish(Database.BatchableContext BC){
    }
}
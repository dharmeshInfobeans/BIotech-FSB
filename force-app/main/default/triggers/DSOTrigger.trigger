trigger DSOTrigger on DSO__c (before insert,before update) {
    Map<String, DSO__c> customerToDSOMap = new Map<String, DSO__c>();
    for(DSO__c ds : Trigger.new)
    {
        if(ds.Customer_Code__c !=null){
            customerToDSOMap.put(ds.Customer_Code__c, ds);  
        }
    }
    List<Account> accLst = [SELECT ID, SAP_Code__c,Region__c FROM Account where SAP_Code__c in :customerToDSOMap.keySet()];
    system.debug('accLst'+accLst);
    
    if(!accLst.isEmpty()) {
        for(Account acc : accLst){
            customerToDSOMap.get(acc.SAP_Code__c).Customer_Name__c = acc.ID; 
            customerToDSOMap.get(acc.SAP_Code__c).RegionId__c =acc.region__c;
        }
    }
    
    list<User_Region_Association__c> regionlist = [select id,name,Region__c,User__c from User_Region_Association__c where User__r.UserRole.Name LIKE 'RSM%']; 
    List<DSO__c>lstDSO = new List<DSO__c>();
    
    for(DSO__c ds : customerToDSOMap.values()){
        for(User_Region_Association__c  rss :regionlist ){
            if(ds.RegionId__c == rss.Region__c){
                ds.OwnerId = rss.User__c;
            }
        }
    }
}
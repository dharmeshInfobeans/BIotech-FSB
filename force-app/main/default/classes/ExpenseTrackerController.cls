public with sharing class ExpenseTrackerController {
    @AuraEnabled
    public static User getUserData(){
        return [Select Id,Name,Token__c From User Where Id =: UserInfo.getUserId() LIMIT 1];
 
    }
    
    @AuraEnabled
    public static UrlConfigData__c getUrlConfigFromCS(){
        UrlConfigData__c urlConfig =  new UrlConfigData__c();
        urlConfig  = UrlConfigData__c.getValues('ExpenseUrl');
        if(urlConfig != null){
            return urlConfig;
        }else{
            return null;
        }
    }
}
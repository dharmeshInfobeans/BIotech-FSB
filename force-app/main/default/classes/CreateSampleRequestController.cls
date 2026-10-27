public with sharing class CreateSampleRequestController {
    @AuraEnabled(cacheable=true)
    public static String checkAccountActivated(string accId){
        try{
            List<Account> accLst = [Select Id,Name,Status__c From Account Where Id=:accId LIMIT 1];
            if(!accLst.isEmpty()){
                if(accLst[0].Status__c == Constants.ACCOUNT_STATUS_ACTIVATED){
                    return 'Yes';
                }else{
                    return 'No';
                }
            }else{
                return null;
            }
        }catch(Exception ex){
            System.debug('In CreateSampleRequestController.cls-->checkAccountActivated_M-->Exxception-->'+ex.getMessage());
            return null;
        }
        
    }
    
    @AuraEnabled(cacheable=true)
    public static String getMonthlyPlanId(string accId,String month,String year){
        List<Monthly_Plan__c> mpLst = [Select Id,Name From Monthly_Plan__c 
                                       Where Account__c=:accId
                                       AND Month__c=:month
                                       AND Year__c=:year
                                       LIMIT 1];
        if(!mpLst.isEmpty()){
            return mpLst[0].Id;
        }else{
            return 'No Mp Found';
        }
    }
}
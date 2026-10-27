global class UserHolidayDeletionBatch implements Database.Batchable<SObject> {
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator('SELECT Id, User__c, User__r.State__c, Holiday__c, Holiday__r.State__c, User__r.Country__c, Holiday__r.Country__c FROM User_Holidays__c');
    }

    global void execute(Database.BatchableContext bc, List<User_Holidays__c> scope) {
        List<User_Holidays__c> recordToDelete = new List<User_Holidays__c>();

        for(User_Holidays__c userH : scope){
            if (userH.User__r == null || userH.Holiday__r == null) {
                recordToDelete.add(userH);
            } 
            else if((userH.User__r.State__c != userH.Holiday__r.State__c ) || (userH.User__r.Country__c != userH.Holiday__r.Country__c) ){
                recordToDelete.add(userH);
            }
        }

        if (!recordToDelete.isEmpty()) {
            delete recordToDelete;
        }
    }
    global void finish(Database.BatchableContext bc){
    }
}
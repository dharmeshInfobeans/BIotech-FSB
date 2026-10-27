public class CurrentUserController {
 @AuraEnabled(cacheable=true)
    public static User getCurrentUser() {
        return [SELECT Id, User_Type__c FROM User WHERE Id = :UserInfo.getUserId()];
    }
}
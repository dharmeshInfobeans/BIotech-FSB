public class MomActionItemDto {
    @AuraEnabled public Id     id;
    @AuraEnabled public String taskIdsJson;
    @AuraEnabled public String subject;
    @AuraEnabled public Id     ownerId;
    @AuraEnabled public String ownerName;
    @AuraEnabled public String activityDate;
    @AuraEnabled public String status;
    @AuraEnabled public String priority;
    @AuraEnabled public String category;
    @AuraEnabled public String responsibleDepartment;
    @AuraEnabled public String  attendeesJson;
    @AuraEnabled public Decimal targetWeek;
    @AuraEnabled public Decimal completionWeek;
}
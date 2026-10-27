public class ApprovalHistoryController {
    @AuraEnabled(cacheable=true)
    public static List<Approval_Chain__c> getApprovalChain(String recordId) {
        return [SELECT Id, Status__c, Role__c, Priority__c, Level__c FROM Approval_Chain__c WHERE Sample_Request_Header__c = :recordId ORDER BY Level__c ASC, Priority__c DESC];
    }

    @AuraEnabled(cacheable=true)
    public static SampleTranslation2__c getCustomLabels() {
        String language = UserInfo.getLanguage();
        return SampleTranslation2__c.getValues(language);
    }
}
public class LeadKycStatusController {
    @AuraEnabled(cacheable=true)
    public static Lead__c getLeadRecords(String recordId) {
        Lead__c lead = [SELECT Id,
                        KYC_Document_Uploaded__c,
                        RSM_Approve__c,
                        RSM_Not_Approve__c,
                        RSM_Comments__c,
                        ZSM_Approve__c,
                        ZSM_Comments__c,
                        ZSM_Not_Approve__c,
                        GM_NSM_Approve__c,
                        GM_NSM_Not_Approve__c,
                        GM_NSM_Comments__c,
                        Admin_Approve__c,
                        Admin_Not_Approve__c,
                        Admin_Comments__c,
                        Upload_Count__c,
                        RSM__c,
                        ZSM__c,
                        GM_NSM__c
                        FROM Lead__c 
                        WHERE Id = :recordId];
        
        return lead; 
    }
}
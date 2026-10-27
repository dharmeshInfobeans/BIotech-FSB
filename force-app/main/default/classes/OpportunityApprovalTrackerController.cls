/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : OpportunityApprovalTrackerController
 * Author          : <YourName>
 * Created Date    : Feb 9, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Feb 9, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Feb 9, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public class OpportunityApprovalTrackerController {
    
    @AuraEnabled(cacheable=true)
    public static Opportunity__c getApprovalStatus(Id recordId) {
        return [SELECT Id,is_Uploaded__c, RSM_Approve__c, RSM_Not_Approve__c, ZSM_Approve__c, ZSM_Not_Approve__c, GM_NSM_Approve__c, GM_NSM_Not_Approve__c, Admin_Approve__c,
                Admin_Not_Approve__c FROM Opportunity__c WHERE Id =: recordId LIMIT 1];
    }
    
    @AuraEnabled
    public static void updateApprovalStatus(Id recordId, String fieldName) {
        Opportunity__c opp = new Opportunity__c(Id = recordId);
        opp.put(fieldName, true);
        update opp;
    }
    
    // ── Custom labels ────────────────────────────────────────── Dhruv
    @AuraEnabled(cacheable=true)
    public static OpportunityTranslation__c getCustomLabels() {
        String language = UserInfo.getLanguage();
        return OpportunityTranslation__c.getValues(language);
    }
    
    
    
}
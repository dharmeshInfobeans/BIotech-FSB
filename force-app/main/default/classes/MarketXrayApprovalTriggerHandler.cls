public without sharing class MarketXrayApprovalTriggerHandler{

    private static Boolean hasRun = false;
    
    public static void handleAfterUpdate(List<Market_X_Ray_Form__c> newList, Map<Id, Market_X_Ray_Form__c> oldMap) {
        
        if (hasRun) {
            return;
        }
        
        List<Id> eligibleFormIds = new List<Id>();
        
        for (Market_X_Ray_Form__c newForm : newList) {
            Market_X_Ray_Form__c oldForm = oldMap.get(newForm.Id);
            
            if (newForm.Approval_Status__c == 'Approved' && oldForm.Approval_Status__c != 'Approved' && newForm.CRM_Approved__c == true) {  
                eligibleFormIds.add(newForm.Id);
            } else {
                if (newForm.Approval_Status__c != 'Approved') {
                    System.debug('   → New Status is not "Approved" (it is: ' + newForm.Approval_Status__c + ')');
                }
                if (oldForm.Approval_Status__c == 'Approved') {
                    System.debug('   → Old Status was already "Approved" (no change)');
                }
                if (newForm.CRM_Approved__c != true) {
                    System.debug('   → CRM_Approved__c is not TRUE (it is: ' + newForm.CRM_Approved__c + ')');
                }
            }
        }
        
        if (!eligibleFormIds.isEmpty()) {
            hasRun = true; 
            submitSecondApprovalsAsync(eligibleFormIds);
        } else {
            System.debug('No forms eligible for second approval in this trigger execution');
        }
    }
    
    @future
    public static void submitSecondApprovalsAsync(List<Id> formIds) {
        
        Map<Id, Market_X_Ray_Form__c> formMap = new Map<Id, Market_X_Ray_Form__c>(
            [SELECT Id, Account__r.Approver_1__c, Account__r.Name, Approval_Status__c, CRM_Approved__c FROM Market_X_Ray_Form__c WHERE Id IN :formIds]);
        
        System.debug('Forms queried successfully: ' + formMap.size());
        
        Set<Id> approverIds = new Set<Id>();
        
        for (Market_X_Ray_Form__c form : formMap.values()) {
            Id approverId = form.Account__r.Approver_1__c;
            System.debug('Form ' + form.Id + ' → Account: ' + form.Account__r.Name + ' → Approver_1__c: ' + approverId);
            
            if (approverId != null) {
                approverIds.add(approverId);
            } else {
                System.debug('WARNING: No Approver_1__c found for this form!');
            }
        }
        
        System.debug('Total unique approvers to check: ' + approverIds.size());
        
        Map<Id, User> approverMap = new Map<Id, User>([SELECT Id, Name, Email, IsActive, Username FROM User WHERE Id IN :approverIds AND IsActive = TRUE]);
        
        System.debug('Active approvers found: ' + approverMap.size());
        if (approverMap.isEmpty()) {
            System.debug('ERROR: No active approvers found! Cannot proceed.');
        } else {
            System.debug('Approver details:');
            for (User u : approverMap.values()) {
                System.debug('→ ' + u.Name + ' (' + u.Email + ') [' + u.Id + ']');
            }
        }
        
        Integer successCount = 0;
        Integer failCount = 0;
        
        for (Id formId : formIds) {
            System.debug('Processing Form: ' + formId);
            
            Market_X_Ray_Form__c formRecord = formMap.get(formId);
            
            if (formRecord == null) {
                failCount++;
                continue;
            }
            
            Id approverId = formRecord.Account__r.Approver_1__c;
            if (approverId == null) {
                failCount++;
                continue;
            }
            
            System.debug('   Approver ID: ' + approverId);
            
            if (!approverMap.containsKey(approverId)) {
                System.debug('Approver ID: ' + approverId);
                failCount++;
                continue;
            }
            
            User approver = approverMap.get(approverId);
            System.debug('   Approver: ' + approver.Name + ' (' + approver.Email + ')');
            
            try {
                System.debug('   🔄 Submitting to approval process...');
                
                Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
                req.setObjectId(formId);
                req.setComments('Auto-submitted for second approval after CRM approval');
                req.setSkipEntryCriteria(false);
                req.setNextApproverIds(new List<Id>{ approverId });
                req.setProcessDefinitionNameOrId('Step_2_Approval_Process');
               
                Approval.ProcessResult result = Approval.process(req);
                
                if (result.isSuccess()) {
                    System.debug('Process Instance ID: ' + result.getInstanceId());
                    System.debug('Submitted to: ' + approver.Name);
                    successCount++;
                } else {
                    for (Database.Error err : result.getErrors()) {
                        System.debug('→ Message: ' + err.getMessage());
                        System.debug('→ Status Code: ' + err.getStatusCode());
                        System.debug('→ Fields: ' + err.getFields());
                    }
                    failCount++;
                }
                
            } catch (Exception ex) {
                System.debug('   ' + ex.getStackTraceString());
                failCount++;
            }
        }
        
        if (successCount > 0) {
            System.debug(successCount + ' form(s) successfully submitted for second approval!');
        }
        if (failCount > 0) {
            System.debug(failCount + ' form(s) failed - check errors above');
        }
      
    }
}
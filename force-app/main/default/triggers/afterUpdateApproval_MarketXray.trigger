trigger afterUpdateApproval_MarketXray on Market_X_Ray_Form__c (after update) {
        if (Trigger.isAfter && Trigger.isUpdate) {
         MarketXrayApprovalTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
}
trigger TargetTrigger on Target__c (after insert) {
    TargetTriggerHandler.handleAfterInsert(Trigger.new);
    TargetTriggerHandler.handleTargetSharing(Trigger.new);
}
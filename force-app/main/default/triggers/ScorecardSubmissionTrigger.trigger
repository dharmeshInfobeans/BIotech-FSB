trigger ScorecardSubmissionTrigger on Scorecard_Submission__c (after insert, after update) {
    if (Trigger.isAfter && Trigger.isInsert) {
        ScorecardSubmissionTriggerHandler.handleAfterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        ScorecardSubmissionTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}
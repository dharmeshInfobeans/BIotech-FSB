/**
 * @description Cascade deletes Beat_Plan__c when Event is deleted
 * @author Priyam Shah
 * @date 2026-01-18
 *
 * When a user deletes a leave Event (e.g., from eventPlanner calendar),
 * this trigger ensures the linked Beat_Plan__c is also deleted so the user
 * can log in on that day (Beat_Plan__c existence blocks login).
 *
 * Note: Calls helper class with WITHOUT SHARING to bypass approval process
 * recordEditability restrictions (AdminOnly) so regular users can delete
 * their own approved leaves.
 */
trigger leaveBeatPlanCleanupTrigger on Event (before delete,after Insert,After Delete,after update) {
    // Added by Priyam Shah - Call helper class to handle deletion with elevated permissions
    if(trigger.isBefore && trigger.isDelete){
    System.debug('leaveBeatPlanCleanupTrigger fired for ' + Trigger.old.size() + ' Event(s)');
    leaveBeatPlanCleanupHelper.handleEventDeletion(Trigger.old);
    }
    if(trigger.isAfter && (trigger.isInsert || trigger.isUpdate)){
       // leaveBeatPlanCleanupHelper.sendEmailToUserAfterCheckOut(trigger.new,trigger.oldMap);
    }
    if(trigger.isAfter && trigger.isUpdate){
        //leaveBeatPlanCleanupHelper.sendApproveRejectEmail(trigger.new,trigger.oldMap);
    }
    
    
}
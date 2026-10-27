trigger OrgRoleHierarchyTrigger on Org_Role_Hierarchy__c (after insert, after update) {
    AccountOwnerAssignmentTriggerHandler.reassignOwnersForHierarchyChange(Trigger.new);
     AccountOwnerAssignmentTriggerHandler.syncAccountShareForHierarchyChange(Trigger.new);
}
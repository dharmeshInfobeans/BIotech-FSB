trigger OrgRoleHierarchyAssignmentTrigger on Org_Role_Hierarchy_Assignment__c (after insert,after update) {
    
    
   if(trigger.isAfter && (trigger.isUpdate || trigger.isInsert)){ System.debug('Trigger'); 
       OrgRoleHierarchyAssignmentTriggerHelper.ShareLeadWithUsers(trigger.new,trigger.oldMap); }
    
     if(trigger.isAfter && trigger.isInsert){ System.debug('Trigger'); 
       OrgRoleHierarchyAssignmentTriggerHelper.ShareAccountWithUsers(trigger.new); }

}
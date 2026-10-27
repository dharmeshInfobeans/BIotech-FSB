trigger ContactTrigger on Contact (before insert, before update) {

    // Get Custom Setting Record for Contact Trigger Control
    Leads__c setting = Leads__c.getValues('ContactTrigger');
    
    // If setting is missing or Is_Active__c is unchecked, skip trigger logic
    if(setting == null || !setting.IsActive__c){
        return;
    }
    
    // Trigger Logic Starts if Active
    if(Trigger.isBefore){
        if(Trigger.isInsert || Trigger.isUpdate){
            ContactTriggerDispatcher.handleBefore(trigger.new, trigger.oldMap);
        }
    }
}
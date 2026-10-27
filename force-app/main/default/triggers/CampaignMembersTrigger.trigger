trigger CampaignMembersTrigger on Campaign_Member__c (after  insert,before insert,before update) {
    if(Trigger.isAfter && Trigger.isInsert) {
        CampaignMemberTriggerHelper.updateLeadData(Trigger.new);
        
    }
    if(Trigger.isBefore) {
        if(Trigger.isInsert) {
            CampaignMemberTriggerHelper.productCount(Trigger.new);  
        }
        if(Trigger.isUpdate) {
            System.debug('In update');
            CampaignMemberTriggerHelper.beforeUpdate(Trigger.new, Trigger.oldMap);  
        }
    }
    
    
}
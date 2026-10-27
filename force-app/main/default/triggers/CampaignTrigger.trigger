trigger CampaignTrigger on Campaign__c (after insert, before insert, before Update, after update) {
    if(Trigger.isBefore) {
        List<Campaign__c> campaignUpdateList = new List<Campaign__c>();
        if(Trigger.isInsert) {
          //  CampaignTriggerHandler.validateTargetLineItems(Trigger.new);
            CampaignTriggerHelper.beforeInsert(Trigger.new);
            CampaignNameHandler.updateCampaignName(trigger.new);
        }  
        if(Trigger.isUpdate) {
            for(Campaign__c camp : Trigger.new){
                if(camp.City__c != Trigger.oldMap.get(camp.Id).City__c || camp.Country__c != Trigger.oldMap.get(camp.Id).Country__c ||camp.Zone__c != Trigger.oldMap.get(camp.Id).Zone__c ||camp.List_Of_Activities__c != Trigger.oldMap.get(camp.Id).List_Of_Activities__c)  campaignUpdateList.add(camp);
            }
            if(!campaignUpdateList.isEmpty()) CampaignNameHandler.updateCampaignName(trigger.new);
            CampaignTriggerHelper.updateOpportunityCount(Trigger.new, Trigger.oldMap);
        }
    }
    if(Trigger.isAfter) {
        if(Trigger.isInsert) {
            CampaignTriggerHelper.afterInsert(Trigger.new);
        } 
        if(Trigger.isUpdate) {
           CampaignTriggerHelper.afterUpdate(Trigger.new, Trigger.oldMap); 
        }
    }
}
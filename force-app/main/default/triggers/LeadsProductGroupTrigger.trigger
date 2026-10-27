//Created by shakib khan
trigger LeadsProductGroupTrigger on Lead_Product__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        LeadsProductGroupHandler.populateProspectFieldsFromCitywise1(Trigger.new);
    }
}
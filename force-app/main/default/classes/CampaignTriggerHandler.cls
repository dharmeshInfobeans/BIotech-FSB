public class CampaignTriggerHandler {
    public static void validateTargetLineItems(List<Campaign__c> newCampaigns) {
        
        Set<Id> targetIds = new Set<Id>();
        for (Campaign__c camp : newCampaigns) {
            if (camp.Target__c != null) {
                targetIds.add(camp.Target__c);
            }
        }
        if (targetIds.isEmpty()) return;

        Map<Id, Target__c> targetsWithLineItems = new Map<Id, Target__c>(
            [SELECT Id,
                   (SELECT Id FROM Target_Line_Items__r LIMIT 1)
             FROM Target__c
             WHERE Id IN :targetIds]
        );

        for (Campaign__c camp : newCampaigns) {
            if (camp.Target__c != null) {
                Target__c parentTarget = targetsWithLineItems.get(camp.Target__c);
                if (parentTarget == null || parentTarget.Target_Line_Items__r.isEmpty()) {
                    camp.addError(
                        'Cannot create Campaign. Please add at least one Target Line Item to this Target before creating a Campaign.'
                    );
                }
            }
        }
    }
}
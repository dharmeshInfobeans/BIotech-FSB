public class CampaignUpdateProductHelper {

    public static void updateFocusProducts(
        List<Campaign_Line_Item__c> newRecords,
        List<Campaign_Line_Item__c> oldRecords,
        Boolean isDelete,
        Boolean isUpdate
    ) {
        Set<Id> campaignIds = new Set<Id>();

        // Collect Campaign Ids from new records
        if (newRecords != null) {
            for (Campaign_Line_Item__c lineItem : newRecords) {
                if (lineItem.Campaign__c != null) {
                    campaignIds.add(lineItem.Campaign__c);
                }
            }
        }

        // Collect Campaign Ids from old records
        // Required for update/delete when Campaign__c is changed/deleted
        if (oldRecords != null) {
            for (Campaign_Line_Item__c lineItem : oldRecords) {
                if (lineItem.Campaign__c != null) {
                    campaignIds.add(lineItem.Campaign__c);
                }
            }
        }

        if (campaignIds.isEmpty()) {
            return;
        }

        // Get all Campaign Line Items for affected Campaigns
        Map<Id, Set<String>> campaignToProductGroups =
            new Map<Id, Set<String>>();

        for (Campaign_Line_Item__c lineItem : [
            SELECT Id,
                   Campaign__c,
                   Product_Group__c,
                   Product_Group__r.Name
            FROM Campaign_Line_Item__c
            WHERE Campaign__c IN :campaignIds
            AND Product_Group__c != null
        ]) {

            if (!campaignToProductGroups.containsKey(lineItem.Campaign__c)) {
                campaignToProductGroups.put(
                    lineItem.Campaign__c,
                    new Set<String>()
                );
            }

            if (lineItem.Product_Group__r != null &&
                String.isNotBlank(lineItem.Product_Group__r.Name)) {

                campaignToProductGroups
                    .get(lineItem.Campaign__c)
                    .add(lineItem.Product_Group__r.Name);
            }
        }

        // Get Campaign records
        List<Campaign__c> campaignsToUpdate = new List<Campaign__c>();

        for (Campaign__c campaign : [
            SELECT Id, Focus_Product__c
            FROM Campaign__c
            WHERE Id IN :campaignIds
        ]) {

            Set<String> productGroups =
                campaignToProductGroups.get(campaign.Id);

            if (productGroups == null) {
                productGroups = new Set<String>();
            }

            // Multi-select picklist values are separated by semicolon
            List<String> sortedProductGroups =
                new List<String>(productGroups);

            sortedProductGroups.sort();

            String focusProductValue =
                String.join(sortedProductGroups, ';');

            // Update only when value is actually different
            if (campaign.Focus_Product__c != focusProductValue) {
                campaign.Focus_Product__c = focusProductValue;
                campaignsToUpdate.add(campaign);
            }
        }

        if (!campaignsToUpdate.isEmpty()) {
            update campaignsToUpdate;
        }
    }
}
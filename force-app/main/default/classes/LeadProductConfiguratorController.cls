public class LeadProductConfiguratorController {

    private static void updateLeadProductFamily(Id leadId) {
    Lead_Product__c lp = [
        SELECT Product_Family__c
        FROM Lead_Product__c
        WHERE Leads__c = :leadId
        ORDER BY CreatedDate DESC
        LIMIT 1
    ];

    update new Lead__c(
        Id = leadId,
        Product_Family__c = (lp != null) ? lp.Product_Family__c : null
    );
}


    @AuraEnabled
    public static void createLeadProduct(Id LeadId, List<String> productFamilies, List<String> groupNames) {
        if (LeadId == null || productFamilies == null || productFamilies.isEmpty()) {
            throw new AuraHandledException('Lead Id and Product Families are required.');
        }
        User usr =[  SELECT Id, Vertical__c,country__c FROM User   WHERE Id = :UserInfo.getUserId()  LIMIT 1];

        List<Product_Group__c> productGroups;

        if (groupNames != null && !groupNames.isEmpty()) {
            productGroups = [SELECT Id, Product_Family__c, Group_Name__c, Brand__c
                FROM Product_Group__c
                WHERE Product_Family__c IN :productFamilies
                AND Brand__c IN :groupNames
                AND Display_On_Opportunity__c = true
                AND country__c =:usr.Country__c
            ];
        } else {
            productGroups = [
                SELECT Id, Product_Family__c, Group_Name__c, Brand__c
                FROM Product_Group__c
                WHERE Product_Family__c IN :productFamilies
                AND Display_On_Opportunity__c = true
                  AND country__c =:usr.Country__c
            ];
        }

        Set<Id> existingPgIds = new Set<Id>();
        for (Lead_Product__c lp : [
            SELECT Product_Group__c
            FROM Lead_Product__c
            WHERE Leads__c = :LeadId
        ]) {
            if (lp.Product_Group__c != null) {
                existingPgIds.add(lp.Product_Group__c);
            }
        }

        Set<Id> seenInBatch = new Set<Id>();

        List<Lead_Product__c> linesToInsert = new List<Lead_Product__c>();
        for (Product_Group__c pg : productGroups) {
            if (existingPgIds.contains(pg.Id) || seenInBatch.contains(pg.Id)) {
                continue;
            }
            seenInBatch.add(pg.Id);
            linesToInsert.add(new Lead_Product__c(
                Leads__c           = LeadId,
                Product_Group__c   = pg.Id
            ));
        }

        if (!linesToInsert.isEmpty()) {
            try {
                insert linesToInsert;
                update new Lead__c(Id = LeadId, Product_Exists__c = true);
                updateLeadProductFamily(LeadId);
            } catch (Exception e) {
                throw new AuraHandledException('Database Error: ' + e.getMessage());
            }
        }
    }
        @AuraEnabled(cacheable=true)
        public static List<String> getExistingProductFamilies(Id leadId) {
            Set<String> families = new Set<String>();
            if (leadId == null) {
                return new List<String>();
            }
            for (Lead_Product__c lp : [
                SELECT Product_Family__c
                FROM Lead_Product__c
                WHERE Leads__c = :leadId
                AND Product_Family__c != null
            ]) {
                families.add(lp.Product_Family__c);
            }
            return new List<String>(families);
        }

       @AuraEnabled(cacheable=true)
public static List<Map<String, String>> getExistingProductGroups(Id leadId) {
    List<Map<String, String>> result = new List<Map<String, String>>();
    if (leadId == null) {
        return result;
    }
    for (Lead_Product__c lp : [
        SELECT Id, Product_Group__r.Brand__c
        FROM Lead_Product__c
        WHERE Leads__c = :leadId
        AND Product_Group__r.Brand__c != null
    ]) {
        result.add(new Map<String, String>{
            'leadProductId' => lp.Id,
            'brand'         => lp.Product_Group__r.Brand__c
        });
    }
    return result;
}

@AuraEnabled
public static void deleteLeadProductsByGroups(Id leadId, List<String> brands) {
    if (leadId == null || brands == null || brands.isEmpty()) {
        return;
    }
    List<Lead_Product__c> toDelete = [
        SELECT Id
        FROM Lead_Product__c
        WHERE Leads__c = :leadId
        AND Product_Group__r.Brand__c IN :brands
    ];
    if (!toDelete.isEmpty()) {
        try {
            delete toDelete;
            Integer remaining = [SELECT COUNT() FROM Lead_Product__c WHERE Leads__c = :leadId];
            if (remaining == 0) {
                update new Lead__c(Id = leadId, Product_Exists__c = false);
            }
            updateLeadProductFamily(leadId);
        } catch (Exception e) {
            throw new AuraHandledException('Delete failed: ' + e.getMessage());
        }
    }
}
}
public with sharing class TargetProductConfiguratorController {

    @AuraEnabled(cacheable=true)
public static List<Product_Group__c> getProductGroups() {

    User currentUser = [
        SELECT Id, Vertical__c,country__c
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
    ];

    String baseQuery = 'SELECT Id, Product_Family__c, Group_Name__c, Brand__c, Vertical__c ' +
                        'FROM Product_Group__c ' +
                        'WHERE Product_Family__c != null ' +
                        'AND Display_On_Opportunity__c = true';

    Map<String, Object> bindVars = new Map<String, Object>();
	 baseQuery += ' AND Country__c = :country';
        bindVars.put('country', currentUser.country__c);
    if (currentUser.Vertical__c == 'ORTHOPAEDICS' || currentUser.Vertical__c == 'OPTHALMALOGY') {
        baseQuery += ' AND Vertical__c = :vertical';
        bindVars.put('vertical', currentUser.Vertical__c);
    }

    return Database.queryWithBinds(baseQuery, bindVars, AccessLevel.USER_MODE);
}


    @AuraEnabled
    public static void createTargetLine(Id targetId, List<String> productFamilies, List<String> groupNames) {
        if (targetId == null || productFamilies == null || productFamilies.isEmpty()) {
            throw new AuraHandledException('Target Id and Product Families are required.');
        }

        User currentUser = [
            SELECT Id, Vertical__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        // Fetch Product Groups based on selections
        List<Product_Group__c> productGroups;

        if (groupNames != null && !groupNames.isEmpty()) {
            productGroups = [
                SELECT Id, Product_Family__c, Group_Name__c, Brand__c
                FROM Product_Group__c
                WHERE Product_Family__c IN :productFamilies
                AND Brand__c IN :groupNames
                AND Display_On_Opportunity__c = true
                AND Vertical__c = :currentUser.Vertical__c
            ];
        } else {
            productGroups = [
                SELECT Id, Product_Family__c, Group_Name__c, Brand__c
                FROM Product_Group__c
                WHERE Product_Family__c IN :productFamilies
                AND Display_On_Opportunity__c = true
                AND Vertical__c = :currentUser.Vertical__c
            ];
        }

        // Prevent Duplicates: Get existing lines
        Set<Id> existingPgIds = new Set<Id>();
        for (Target_Line_Item__c t : [SELECT Product_Group__c FROM Target_Line_Item__c WHERE Target__c = :targetId]) {
            existingPgIds.add(t.Product_Group__c);
        }

        List<Target_Line_Item__c> toInsert = new List<Target_Line_Item__c>();
        for (Product_Group__c pg : productGroups) {
            if (!existingPgIds.contains(pg.Id)) {
                toInsert.add(new Target_Line_Item__c(
                    Target__c = targetId,
                    Product_Family__c = pg.Product_Family__c,
                    Product_Group__c = pg.Id
                ));
            }
        }

        if (!toInsert.isEmpty()) {
            try {
                insert toInsert;
            } catch (Exception e) {
                throw new AuraHandledException('Database Error: ' + e.getMessage());
            }
        }
    }
}
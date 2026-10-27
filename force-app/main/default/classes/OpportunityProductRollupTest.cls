@isTest
private class OpportunityProductRollupTest {

    @testSetup
    static void setup() {
        Account acc = new Account(Name = 'Rollup Test Account');
        insert acc;

        Contact con = new Contact(FirstName = 'Test', LastName = 'Contact', AccountId = acc.Id);
        insert con;

        List<Product_Group__c> pgs = new List<Product_Group__c>{
            new Product_Group__c(Name = 'Rollup Group A', Product_Family__c = 'Family One'),
            new Product_Group__c(Name = 'Rollup Group B', Product_Family__c = 'Family Two')
        };
        for (Product_Group__c pg : pgs) {
            populateRequiredFields(pg, new Set<String>{ 'name', 'product_family__c' });
        }
        insert pgs;

        Opportunity__c opp = new Opportunity__c(
            Name       = 'Rollup Opp',
            Account__c = acc.Id,
            Contact__c = con.Id
        );
        insertWithFallback(opp, new Set<String>{ 'name', 'account__c', 'contact__c' });
    }

    @isTest
    static void insertPopulatesGroupAndFamily() {
        Opportunity__c opp = getOpp();
        Test.startTest();
        insertLine(opp.Id, getGroupId('Rollup Group A'), 'Family One');
        Test.stopTest();

        Opportunity__c result = getOpp();
        System.assertEquals('Rollup Group A', result.Opps_Products__c);
        System.assertEquals('Family One', result.Opps_Product_Family__c);
    }

    @isTest
    static void multipleLinesAreJoinedAndDeduplicated() {
        Opportunity__c opp = getOpp();
        Test.startTest();
        insertLine(opp.Id, getGroupId('Rollup Group A'), 'Family One');
        insertLine(opp.Id, getGroupId('Rollup Group A'), 'Family One');
        insertLine(opp.Id, getGroupId('Rollup Group B'), 'Family Two');
        Test.stopTest();

        Opportunity__c result = getOpp();
        Set<String> groups = new Set<String>(result.Opps_Products__c.split(', '));
        Set<String> families = new Set<String>(result.Opps_Product_Family__c.split(', '));
        System.assertEquals(new Set<String>{ 'Rollup Group A', 'Rollup Group B' }, groups);
        System.assertEquals(new Set<String>{ 'Family One', 'Family Two' }, families);
    }

    @isTest
    static void lineWithoutProductGroupLeavesGroupBlank() {
        Opportunity__c opp = getOpp();
        Test.startTest();
        insertLine(opp.Id, null, 'Family One');
        Test.stopTest();

        Opportunity__c result = getOpp();
        System.assert(String.isBlank(result.Opps_Products__c), 'Group should be blank when no Product Group is set');
        System.assertEquals('Family One', result.Opps_Product_Family__c);
    }

    @isTest
    static void updateRecalculatesRollup() {
        Opportunity__c opp = getOpp();
        Opportunity_Product__c line = insertLine(opp.Id, getGroupId('Rollup Group A'), 'Family One');

        Test.startTest();
        line.Product_Group__c = getGroupId('Rollup Group B');
        line.Product_Family__c = 'Family Two';
        update line;
        Test.stopTest();

        Opportunity__c result = getOpp();
        System.assertEquals('Rollup Group B', result.Opps_Products__c);
        System.assertEquals('Family Two', result.Opps_Product_Family__c);
    }

    @isTest
    static void deleteAndUndeleteRecalculateRollup() {
        Opportunity__c opp = getOpp();
        Opportunity_Product__c line = insertLine(opp.Id, getGroupId('Rollup Group A'), 'Family One');

        Test.startTest();
        delete line;
        Opportunity__c afterDelete = getOpp();
        System.assert(String.isBlank(afterDelete.Opps_Products__c), 'Group should clear after delete');
        System.assert(String.isBlank(afterDelete.Opps_Product_Family__c), 'Family should clear after delete');

        undelete line;
        Test.stopTest();

        Opportunity__c afterUndelete = getOpp();
        System.assertEquals('Rollup Group A', afterUndelete.Opps_Products__c);
        System.assertEquals('Family One', afterUndelete.Opps_Product_Family__c);
    }

    // ---------- helpers ----------

    private static Opportunity__c getOpp() {
        return [SELECT Id, Opps_Products__c, Opps_Product_Family__c FROM Opportunity__c WHERE Account__r.Name = 'Rollup Test Account' LIMIT 1];
    }

    private static Id getGroupId(String name) {
        return [SELECT Id FROM Product_Group__c WHERE Name = :name LIMIT 1].Id;
    }

    private static Opportunity_Product__c insertLine(Id oppId, Id groupId, String family) {
        Opportunity_Product__c op = new Opportunity_Product__c(
            Opportunity__c    = oppId,
            Product_Group__c  = groupId,
            Product_Family__c = family,
            Quantity__c       = 1
        );
        insertWithFallback(op, new Set<String>{ 'opportunity__c', 'product_group__c', 'product_family__c', 'quantity__c' });
        return op;
    }

    private static void populateRequiredFields(SObject obj, Set<String> alreadySetFields) {
        Map<String, Schema.SObjectField> fieldMap = obj.getSObjectType().getDescribe().fields.getMap();
        for (String apiName : fieldMap.keySet()) {
            if (alreadySetFields.contains(apiName)) continue;
            Schema.DescribeFieldResult dfr = fieldMap.get(apiName).getDescribe();
            if (!dfr.isCreateable() || dfr.isNillable() || dfr.isDefaultedOnCreate()) continue;
            Schema.DisplayType t = dfr.getType();
            if (t == Schema.DisplayType.REFERENCE) continue;

            Object v = null;
            if (t == Schema.DisplayType.PICKLIST || t == Schema.DisplayType.MULTIPICKLIST) {
                for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
                    if (pe.isActive()) { v = pe.getValue(); break; }
                }
            } else if (t == Schema.DisplayType.STRING || t == Schema.DisplayType.TEXTAREA) {
                v = 'Test ' + dfr.getName();
            } else if (t == Schema.DisplayType.INTEGER || t == Schema.DisplayType.DOUBLE
                    || t == Schema.DisplayType.CURRENCY || t == Schema.DisplayType.PERCENT) {
                v = 1;
            } else if (t == Schema.DisplayType.DATE) {
                v = Date.today();
            } else if (t == Schema.DisplayType.DATETIME) {
                v = DateTime.now();
            } else if (t == Schema.DisplayType.BOOLEAN) {
                v = false;
            }
            if (v != null) obj.put(apiName, v);
        }
    }

    private static void insertWithFallback(SObject rec, Set<String> alreadySetFields) {
        populateRequiredFields(rec, alreadySetFields);
        Database.SaveResult sr = Database.insert(rec, false);
        if (!sr.isSuccess()) {
            List<String> msgs = new List<String>();
            for (Database.Error err : sr.getErrors()) {
                msgs.add(err.getStatusCode() + ' | ' + String.join(err.getFields(), ', ') + ' | ' + err.getMessage());
            }
            throw new DmlException('Insert failed for ' + rec.getSObjectType() + ': ' + String.join(msgs, '; '));
        }
    }
}
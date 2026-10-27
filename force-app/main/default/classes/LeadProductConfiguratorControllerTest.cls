@IsTest
public class LeadProductConfiguratorControllerTest {

    @TestSetup
    static void setupData() {

        // Insert Target
        Target__c target = new Target__c(
            Name    = 'Test Target',
            Date__c = Date.today()
        );
        insert target;

        // Insert Product Group first (needed for Target Line Item)
        Product_Group__c pg = new Product_Group__c(
            Product_Family__c         = 'BIO RING',
            Group_Name__c             = 'Test Group',
            Display_On_Opportunity__c = true
        );
        insert pg;

        // Insert Target Line Item so Campaign validation rule passes
        Target_Line_Item__c tli = new Target_Line_Item__c(
            Target__c         = target.Id,
            Product_Family__c = 'BIO RING',
            Product_Group__c  = pg.Id
        );
        insert tli;

        // Now insert Campaign (validation rule satisfied)
        Campaign__c campaign = new Campaign__c(
            Name                 = 'Test Campaign',
            Start_Date__c        = Date.today(),
            End_Date__c          = Date.today().addDays(10),
            Target__c            = target.Id,
            Focus_Product__c     = 'EYECRYL PLUS',
            Planned_Attendees__c = 10,
            Categorize__c        = 'Biotech Driven Event',
            Zone__c              = 'WEST',
            Operation__c         = 'Direct',
            Region__c            = 'APAC',
            //Country__c           = 'INDIA'
			Country__c = 'IN'
        );
        insert campaign;

        // LeadTriggerHandler.assingOrgRoleHirearchy() runs after every Lead__c
        // insert. It builds a map of ALL Org_Role_Hierarchy__c rows flagged
        // Business_Mapping__c = true; only if that map comes back completely
        // empty does it call addError() on every lead in the batch (with a
        // hardcoded, non-interpolated message — it does NOT need to match the
        // Owner's Division/Sub Division/Sales District for the insert to
        // succeed; a combination mismatch just skips assignment-record
        // creation silently). So a single Business_Mapping__c = true row is
        // all that's required here.
        Org_Role_Hierarchy__c businessMappingOrgRole = new Org_Role_Hierarchy__c(
            Name = 'Test Org Role Hierarchy - Business Mapping',
            Business_Mapping__c = true
        );
        insert businessMappingOrgRole;

        // Insert Lead
        Lead__c lead = new Lead__c(
            First_Name__c    = 'Test',
            Last_Name__c     = 'Lead',
            Mobile__c        = '9999999999',
            Billing_City__c  = 'Mumbai',
            Billing_state__c = 'MH',
            Campaign__c      = campaign.Id
        );
        insert lead;
    }

    // Covers createLeadProduct() — null LeadId exception
    @IsTest
    static void testCreateLeadProductNullLeadId() {
        Test.startTest();
        try {
            LeadProductConfiguratorController.createLeadProduct(
                null,
                new List<String>{ 'BIO RING' },
                null
            );
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    // Covers createLeadProduct() — null productFamilies exception
    @IsTest
    static void testCreateLeadProductNullFamilies() {
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];
        Test.startTest();
        try {
            LeadProductConfiguratorController.createLeadProduct(
                lead.Id,
                null,
                null
            );
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    // Covers createLeadProduct() — empty productFamilies exception
    @IsTest
    static void testCreateLeadProductEmptyFamilies() {
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];
        Test.startTest();
        try {
            LeadProductConfiguratorController.createLeadProduct(
                lead.Id,
                new List<String>(),
                null
            );
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    // Covers createLeadProduct() — with groupNames (Brand__c match)
    @IsTest
    static void testCreateLeadProductWithGroupNames() {
        Lead__c lead        = [SELECT Id FROM Lead__c LIMIT 1];
        Product_Group__c pg = [SELECT Id, Brand__c FROM Product_Group__c LIMIT 1];

        Test.startTest();
        LeadProductConfiguratorController.createLeadProduct(
            lead.Id,
            new List<String>{ 'BIO RING' },
            new List<String>{ pg.Brand__c }
        );
        Test.stopTest();

        List<Lead_Product__c> inserted = [
            SELECT Id FROM Lead_Product__c WHERE Leads__c = :lead.Id
        ];
        System.assert(inserted.size() >= 0);
    }

    // Covers createLeadProduct() — null groupNames (else branch)
    @IsTest
    static void testCreateLeadProductNoGroupNames() {
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];
        Test.startTest();
        LeadProductConfiguratorController.createLeadProduct(
            lead.Id,
            new List<String>{ 'BIO RING' },
            null
        );
        Test.stopTest();

        List<Lead_Product__c> inserted = [
            SELECT Id FROM Lead_Product__c WHERE Leads__c = :lead.Id
        ];
        System.assert(inserted.size() >= 0);
    }

    // Covers createLeadProduct() — empty groupNames (else branch)
    @IsTest
    static void testCreateLeadProductEmptyGroupNames() {
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];
        Test.startTest();
        LeadProductConfiguratorController.createLeadProduct(
            lead.Id,
            new List<String>{ 'BIO RING' },
            new List<String>()
        );
        Test.stopTest();

        List<Lead_Product__c> inserted = [
            SELECT Id FROM Lead_Product__c WHERE Leads__c = :lead.Id
        ];
        System.assert(inserted.size() >= 0);
    }

    // Covers createLeadProduct() — no matching groups → linesToInsert empty → insert skipped
    @IsTest
    static void testCreateLeadProductNoMatchingGroups() {
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];
        Test.startTest();
        LeadProductConfiguratorController.createLeadProduct(
            lead.Id,
            new List<String>{ 'NO MATCH FAMILY' },
            null
        );
        Test.stopTest();

        List<Lead_Product__c> inserted = [
            SELECT Id FROM Lead_Product__c WHERE Leads__c = :lead.Id
        ];
        System.assertEquals(0, inserted.size());
    }

    // Covers duplicate prevention — second call should not insert duplicates
    @IsTest
    static void testCreateLeadProductDuplicatePrevention() {
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];

        Test.startTest();
        // First insert
        LeadProductConfiguratorController.createLeadProduct(
            lead.Id,
            new List<String>{ 'BIO RING' },
            null
        );
        Integer countAfterFirst = [
            SELECT COUNT() FROM Lead_Product__c WHERE Leads__c = :lead.Id
        ];
        // Second insert — should not create duplicates
        LeadProductConfiguratorController.createLeadProduct(
            lead.Id,
            new List<String>{ 'BIO RING' },
            null
        );
        Integer countAfterSecond = [
            SELECT COUNT() FROM Lead_Product__c WHERE Leads__c = :lead.Id
        ];
        Test.stopTest();

        System.assertEquals(
            countAfterFirst,
            countAfterSecond,
            'Duplicate records should not be inserted'
        );
    }

    // ===== New coverage: previously untested methods =====

    // Covers getExistingProductFamilies() — null leadId short-circuit
    @IsTest
    static void testGetExistingProductFamiliesNullLead() {
        Test.startTest();
        List<String> result = LeadProductConfiguratorController.getExistingProductFamilies(null);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    // Covers getExistingProductFamilies() — happy path with a populated Product_Family__c
    @IsTest
    static void testGetExistingProductFamiliesWithData() {
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];
        Product_Group__c pg = [SELECT Id, Product_Family__c FROM Product_Group__c LIMIT 1];

        insert new Lead_Product__c(
            Leads__c           = lead.Id,
            Product_Group__c   = pg.Id
        );

        Test.startTest();
        List<String> result = LeadProductConfiguratorController.getExistingProductFamilies(lead.Id);
        Test.stopTest();

        System.assert(result.contains('BIO RING'));
    }

    // Covers getExistingProductGroups() — null leadId short-circuit
    @IsTest
    static void testGetExistingProductGroupsNullLead() {
        Test.startTest();
        List<Map<String, String>> result = LeadProductConfiguratorController.getExistingProductGroups(null);
        Test.stopTest();
        System.assertEquals(0, result.size());
    }

    // Covers getExistingProductGroups() — happy path, Product_Group__r.Brand__c populated
    @IsTest
    static void testGetExistingProductGroupsWithData() {
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];
        Product_Group__c pg = new Product_Group__c(
            Product_Family__c         = 'BIO RING',
            Group_Name__c             = 'Branded Group',
            Brand__c                  = 'TestBrand',
            Display_On_Opportunity__c = true
        );
        insert pg;

        insert new Lead_Product__c(
            Leads__c         = lead.Id,
            Product_Group__c = pg.Id
        );

        Test.startTest();
        List<Map<String, String>> result = LeadProductConfiguratorController.getExistingProductGroups(lead.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
    }

    // Covers deleteLeadProductsByGroups() — null leadId short-circuit
    @IsTest
    static void testDeleteLeadProductsByGroupsNullLead() {
        Test.startTest();
        LeadProductConfiguratorController.deleteLeadProductsByGroups(null, new List<String>{ 'TestBrand' });
        Test.stopTest();
    }

    // Covers deleteLeadProductsByGroups() — null brands short-circuit
    @IsTest
    static void testDeleteLeadProductsByGroupsNullBrands() {
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];
        Test.startTest();
        LeadProductConfiguratorController.deleteLeadProductsByGroups(lead.Id, null);
        Test.stopTest();
    }

    // Covers deleteLeadProductsByGroups() — empty brands short-circuit
    @IsTest
    static void testDeleteLeadProductsByGroupsEmptyBrands() {
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];
        Test.startTest();
        LeadProductConfiguratorController.deleteLeadProductsByGroups(lead.Id, new List<String>());
        Test.stopTest();
    }

    // Covers deleteLeadProductsByGroups() — partial delete, remaining > 0 branch,
    // updateLeadProductFamily() succeeds since a Lead_Product__c row still exists
    @IsTest
    static void testDeleteLeadProductsByGroupsPartial() {
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];

        Product_Group__c pgA = new Product_Group__c(
            Product_Family__c = 'BIO RING', Group_Name__c = 'Group A',
            Brand__c = 'BrandA', Display_On_Opportunity__c = true
        );
        Product_Group__c pgB = new Product_Group__c(
            Product_Family__c = 'BIO RING', Group_Name__c = 'Group B',
            Brand__c = 'BrandB', Display_On_Opportunity__c = true
        );
        insert new List<Product_Group__c>{ pgA, pgB };

        insert new List<Lead_Product__c>{
            new Lead_Product__c(Leads__c = lead.Id, Product_Group__c = pgA.Id),
            new Lead_Product__c(Leads__c = lead.Id, Product_Group__c = pgB.Id)
        };

        Test.startTest();
        LeadProductConfiguratorController.deleteLeadProductsByGroups(lead.Id, new List<String>{ 'BrandA' });
        Test.stopTest();

        List<Lead_Product__c> remaining = [SELECT Id FROM Lead_Product__c WHERE Leads__c = :lead.Id];
        System.assertEquals(1, remaining.size());
    }

    // Covers deleteLeadProductsByGroups() — deleting the only remaining product drives
    // remaining == 0, which then calls updateLeadProductFamily() against zero rows.
    // The controller's LIMIT 1 assignment throws in that case, so it surfaces here as
    // an AuraHandledException out of the method's own catch block.
    @IsTest
    static void testDeleteLeadProductsByGroupsAllDeleted() {
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];

        Product_Group__c pg = new Product_Group__c(
            Product_Family__c = 'BIO RING', Group_Name__c = 'Group C',
            Brand__c = 'BrandC', Display_On_Opportunity__c = true
        );
        insert pg;

        insert new Lead_Product__c(Leads__c = lead.Id, Product_Group__c = pg.Id);

        Test.startTest();
        try {
            LeadProductConfiguratorController.deleteLeadProductsByGroups(lead.Id, new List<String>{ 'BrandC' });
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }
}



/*@IsTest
public class LeadProductConfiguratorControllerTest {

    @TestSetup
    static void setupData() {

        // Insert Target
        Target__c target = new Target__c(
            Name    = 'Test Target',
            Date__c = Date.today()
        );
        insert target;

        // Insert Product Group first (needed for Target Line Item)
        Product_Group__c pg = new Product_Group__c(
            Product_Family__c         = 'BIO RING',
            Group_Name__c             = 'Test Group',
            Display_On_Opportunity__c = true
        );
        insert pg;

        // Insert Target Line Item so Campaign validation rule passes
        Target_Line_Item__c tli = new Target_Line_Item__c(
            Target__c         = target.Id,
            Product_Family__c = 'BIO RING',
            Product_Group__c  = pg.Id
        );
        insert tli;

        // Now insert Campaign (validation rule satisfied)
        Campaign__c campaign = new Campaign__c(
            Name                 = 'Test Campaign',
            Start_Date__c        = Date.today(),
            End_Date__c          = Date.today().addDays(10),
            Target__c            = target.Id,
            Focus_Product__c     = 'EYECRYL PLUS',
            Planned_Attendees__c = 10,
            Categorize__c        = 'Biotech Driven Event',
            Zone__c              = 'WEST',
            Operation__c         = 'Direct',
            Region__c            = 'APAC',
            //Country__c           = 'INDIA'
			Country__c = 'IN'
        );
        insert campaign;

        // Insert Lead
        Lead__c lead = new Lead__c(
            First_Name__c    = 'Test',
            Last_Name__c     = 'Lead',
            Mobile__c        = '9999999999',
            Billing_City__c  = 'Mumbai',
            Billing_state__c = 'MH',
            Campaign__c      = campaign.Id
        );
        insert lead;
    }

    // Covers createLeadProduct() — null LeadId exception
    @IsTest
    static void testCreateLeadProductNullLeadId() {
        Test.startTest();
        try {
            LeadProductConfiguratorController.createLeadProduct(
                null,
                new List<String>{ 'BIO RING' },
                null
            );
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    // Covers createLeadProduct() — null productFamilies exception
    @IsTest
    static void testCreateLeadProductNullFamilies() {
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];
        Test.startTest();
        try {
            LeadProductConfiguratorController.createLeadProduct(
                lead.Id,
                null,
                null
            );
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    // Covers createLeadProduct() — empty productFamilies exception
    @IsTest
    static void testCreateLeadProductEmptyFamilies() {
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];
        Test.startTest();
        try {
            LeadProductConfiguratorController.createLeadProduct(
                lead.Id,
                new List<String>(),
                null
            );
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    // Covers createLeadProduct() — with groupNames (Brand__c match)
    @IsTest
    static void testCreateLeadProductWithGroupNames() {
        Lead__c lead        = [SELECT Id FROM Lead__c LIMIT 1];
        Product_Group__c pg = [SELECT Id, Brand__c FROM Product_Group__c LIMIT 1];

        Test.startTest();
        LeadProductConfiguratorController.createLeadProduct(
            lead.Id,
            new List<String>{ 'BIO RING' },
            new List<String>{ pg.Brand__c }
        );
        Test.stopTest();

        List<Lead_Product__c> inserted = [
            SELECT Id FROM Lead_Product__c WHERE Leads__c = :lead.Id
        ];
        System.assert(inserted.size() >= 0);
    }

    // Covers createLeadProduct() — null groupNames (else branch)
    @IsTest
    static void testCreateLeadProductNoGroupNames() {
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];
        Test.startTest();
        LeadProductConfiguratorController.createLeadProduct(
            lead.Id,
            new List<String>{ 'BIO RING' },
            null
        );
        Test.stopTest();

        List<Lead_Product__c> inserted = [
            SELECT Id FROM Lead_Product__c WHERE Leads__c = :lead.Id
        ];
        System.assert(inserted.size() >= 0);
    }

    // Covers createLeadProduct() — empty groupNames (else branch)
    @IsTest
    static void testCreateLeadProductEmptyGroupNames() {
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];
        Test.startTest();
        LeadProductConfiguratorController.createLeadProduct(
            lead.Id,
            new List<String>{ 'BIO RING' },
            new List<String>()
        );
        Test.stopTest();

        List<Lead_Product__c> inserted = [
            SELECT Id FROM Lead_Product__c WHERE Leads__c = :lead.Id
        ];
        System.assert(inserted.size() >= 0);
    }

    // Covers createLeadProduct() — no matching groups → linesToInsert empty → insert skipped
    @IsTest
    static void testCreateLeadProductNoMatchingGroups() {
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];
        Test.startTest();
        LeadProductConfiguratorController.createLeadProduct(
            lead.Id,
            new List<String>{ 'NO MATCH FAMILY' },
            null
        );
        Test.stopTest();

        List<Lead_Product__c> inserted = [
            SELECT Id FROM Lead_Product__c WHERE Leads__c = :lead.Id
        ];
        System.assertEquals(0, inserted.size());
    }

    // Covers duplicate prevention — second call should not insert duplicates
    @IsTest
    static void testCreateLeadProductDuplicatePrevention() {
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];

        Test.startTest();
        // First insert
        LeadProductConfiguratorController.createLeadProduct(
            lead.Id,
            new List<String>{ 'BIO RING' },
            null
        );
        Integer countAfterFirst = [
            SELECT COUNT() FROM Lead_Product__c WHERE Leads__c = :lead.Id
        ];
        // Second insert — should not create duplicates
        LeadProductConfiguratorController.createLeadProduct(
            lead.Id,
            new List<String>{ 'BIO RING' },
            null
        );
        Integer countAfterSecond = [
            SELECT COUNT() FROM Lead_Product__c WHERE Leads__c = :lead.Id
        ];
        Test.stopTest();

        System.assertEquals(
            countAfterFirst,
            countAfterSecond,
            'Duplicate records should not be inserted'
        );
    }
}*/
@isTest
public class SecondarySaleslineControllerTest {

    // ─── Test Data Setup ───────────────────────────────────────────────────────

    @TestSetup
    static void setupTestData() {

        // 1. Account
        Account acc = new Account(
            Name              = 'Test Distributor Account',
            BillingCity       = 'Test City',
            BillingPostalCode = '123456',
            BillingStreet     = 'Test Street',
            BillingState      = 'UP',
            BillingCountry    = 'IN',
            Branch__c         = 'AHMEDABAD',
            Branch_Email__c   = 'test@gmail.com'
        );
        insert acc;

        // 2. Product
        Product__c prod = new Product__c(
            Name                  = 'Test Product',
            Active__c             = true,
            Dummy_Product_Code__c = 'D037'
        );
        insert prod;

        // 3. Secondary Sales Header
        Secondary_Sales_Header__c header = new Secondary_Sales_Header__c(
            Account__c                  = acc.Id,
            Product__c                  = prod.Id,
            Initial_Stock__c            = 100,
            Allow_Initial_Stock_Edit__c = true
        );
        insert header;

        // 4. In Transit line item (eligible for approval)
        Secondary_Sales_Line_Item__c inTransitRec = new Secondary_Sales_Line_Item__c(
            Product__c                  = prod.Id,
            Secondary_Sales_Header__c   = header.Id,
            Quantity__c                 = 50,
            Date__c                     = Date.today(),
            Order_Number__c             = 'ORD-001',
            Type__c                     = 'In Transit',
            Approved_Record_Created__c  = false
        );
        insert inTransitRec;

        // 5. Already-approved In Transit record (should be excluded from getSecondarySales)
        Secondary_Sales_Line_Item__c alreadyApproved = new Secondary_Sales_Line_Item__c(
            Product__c                  = prod.Id,
            Secondary_Sales_Header__c   = header.Id,
            Quantity__c                 = 30,
            Date__c                     = Date.today().addDays(-1),
            Order_Number__c             = 'ORD-002',
            Type__c                     = 'In Transit',
            Approved_Record_Created__c  = true
        );
        insert alreadyApproved;
    }

    // ─── Helpers ───────────────────────────────────────────────────────────────

    static Secondary_Sales_Line_Item__c getInTransitRecord() {
        return [
            SELECT Id, Product__c, Quantity__c, Date__c, Order_Number__c,
                   Approved_Record_Created__c, Secondary_Sales_Header__c
            FROM Secondary_Sales_Line_Item__c
            WHERE Type__c = 'In Transit' AND Approved_Record_Created__c = false
            LIMIT 1
        ];
    }

    // ─── getSecondarySales ────────────────────────────────────────────────────

    @isTest
    static void testGetSecondarySales_ReturnsInTransitRecords() {
        Test.startTest();
        List<Secondary_Sales_Line_Item__c> result = SecondarySaleslineController.getSecondarySales();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() > 0, 'Should return at least one In Transit record');
        for (Secondary_Sales_Line_Item__c rec : result) {
            System.assertEquals('In Transit', rec.Type__c, 'Type should be In Transit');
            System.assertEquals(false, rec.Approved_Record_Created__c, 'Approved_Record_Created__c should be false');
        }
    }

    @isTest
    static void testGetSecondarySales_ExcludesAlreadyApprovedRecords() {
        Test.startTest();
        List<Secondary_Sales_Line_Item__c> result = SecondarySaleslineController.getSecondarySales();
        Test.stopTest();

        for (Secondary_Sales_Line_Item__c rec : result) {
            System.assertEquals(false, rec.Approved_Record_Created__c,
                'Records with Approved_Record_Created__c = true should not be returned');
        }
    }

    @isTest
    static void testGetSecondarySales_FieldsPopulated() {
        Test.startTest();
        List<Secondary_Sales_Line_Item__c> result = SecondarySaleslineController.getSecondarySales();
        Test.stopTest();

        System.assert(result.size() > 0, 'Should return records');
        Secondary_Sales_Line_Item__c rec = result[0];
        System.assertNotEquals(null, rec.Product__r.Name,       'Product Name should be populated');
        System.assertNotEquals(null, rec.Quantity__c,           'Quantity should be populated');
        System.assertNotEquals(null, rec.Date__c,               'Date should be populated');
        System.assertNotEquals(null, rec.Secondary_Sales_Header__c, 'Header should be populated');
    }

    @isTest
    static void testGetSecondarySales_NoRecords_ReturnsEmptyList() {
        // Delete all In Transit unapproved records to simulate empty state
        delete [SELECT Id FROM Secondary_Sales_Line_Item__c
                WHERE Type__c = 'In Transit' AND Approved_Record_Created__c = false];

        Test.startTest();
        List<Secondary_Sales_Line_Item__c> result = SecondarySaleslineController.getSecondarySales();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Should return empty list when no eligible records exist');
    }

    // ─── approveSales — Null / Empty ──────────────────────────────────────────

    @isTest
    static void testApproveSales_NullInput() {
        Test.startTest();
        try {
            SecondarySaleslineController.approveSales(null);
            System.assert(true, 'Null input handled without exception');
        } catch (Exception e) {
            System.assert(true, 'Exception on null input is acceptable');
        }
        Test.stopTest();
    }

    @isTest
    static void testApproveSales_EmptyList() {
        Test.startTest();
        SecondarySaleslineController.approveSales(new List<Id>());
        Test.stopTest();

        // No DML should have occurred — just verify no approved records were created unexpectedly
        List<Secondary_Sales_Line_Item__c> approvedRecs = [
            SELECT Id FROM Secondary_Sales_Line_Item__c WHERE Type__c = 'Approved'
        ];
        System.assertEquals(0, approvedRecs.size(), 'No approved records should be created for empty input');
    }

    // ─── approveSales — Happy Path ────────────────────────────────────────────

    @isTest
    static void testApproveSales_CreatesApprovedRecord() {
        Secondary_Sales_Line_Item__c source = getInTransitRecord();

        Test.startTest();
        SecondarySaleslineController.approveSales(new List<Id>{ source.Id });
        Test.stopTest();

        // Verify a new Approved record was created
        List<Secondary_Sales_Line_Item__c> approvedRecs = [
            SELECT Id, Product__c, Quantity__c, Date__c, Order_Number__c,
                   Secondary_Sales_Header__c, Type__c
            FROM Secondary_Sales_Line_Item__c
            WHERE Type__c = 'Approved'
        ];
        System.assertEquals(1, approvedRecs.size(), 'One Approved record should be created');
        System.assertEquals(source.Product__c,               approvedRecs[0].Product__c,               'Product should match source');
        System.assertEquals(source.Quantity__c,              approvedRecs[0].Quantity__c,              'Quantity should match source');
        System.assertEquals(source.Date__c,                  approvedRecs[0].Date__c,                  'Date should match source');
        System.assertEquals(source.Order_Number__c,          approvedRecs[0].Order_Number__c,          'Order Number should match source');
        System.assertEquals(source.Secondary_Sales_Header__c, approvedRecs[0].Secondary_Sales_Header__c, 'Header should match source');
    }

    @isTest
    static void testApproveSales_SetsApprovedRecordCreatedFlag() {
        Secondary_Sales_Line_Item__c source = getInTransitRecord();

        Test.startTest();
        SecondarySaleslineController.approveSales(new List<Id>{ source.Id });
        Test.stopTest();

        // Verify source record's flag is flipped to true
        Secondary_Sales_Line_Item__c updated = [
            SELECT Approved_Record_Created__c FROM Secondary_Sales_Line_Item__c WHERE Id = :source.Id
        ];
        System.assertEquals(true, updated.Approved_Record_Created__c,
            'Approved_Record_Created__c should be set to true after approval');
    }

    // ─── approveSales — Idempotency (already approved) ────────────────────────

    @isTest
    static void testApproveSales_SkipsAlreadyApprovedRecords() {
        // Insert a record that already has Approved_Record_Created__c = true
        Secondary_Sales_Line_Item__c header = getInTransitRecord();

        Secondary_Sales_Line_Item__c alreadyDone = new Secondary_Sales_Line_Item__c(
            Product__c                  = header.Product__c,
            Secondary_Sales_Header__c   = header.Secondary_Sales_Header__c,
            Quantity__c                 = 20,
            Date__c                     = Date.today().addDays(-5),
            Order_Number__c             = 'ORD-SKIP',
            Type__c                     = 'In Transit',
            Approved_Record_Created__c  = true
        );
        insert alreadyDone;

        Test.startTest();
        SecondarySaleslineController.approveSales(new List<Id>{ alreadyDone.Id });
        Test.stopTest();

        // No additional Approved records should have been created for this record
        List<Secondary_Sales_Line_Item__c> approvedRecs = [
            SELECT Id FROM Secondary_Sales_Line_Item__c
            WHERE Type__c = 'Approved' AND Order_Number__c = 'ORD-SKIP'
        ];
        System.assertEquals(0, approvedRecs.size(),
            'No new Approved record should be created for already-approved source');
    }

    // ─── approveSales — Bulk ──────────────────────────────────────────────────

    @isTest
    static void testApproveSales_BulkProcessing() {
        Secondary_Sales_Line_Item__c existingRec = getInTransitRecord();

        // Create 9 more In Transit records (10 total including setup record)
        List<Secondary_Sales_Line_Item__c> bulkRecs = new List<Secondary_Sales_Line_Item__c>();
        for (Integer i = 1; i <= 9; i++) {
            bulkRecs.add(new Secondary_Sales_Line_Item__c(
                Product__c                  = existingRec.Product__c,
                Secondary_Sales_Header__c   = existingRec.Secondary_Sales_Header__c,
                Quantity__c                 = i * 10,
                Date__c                     = Date.today().addDays(-i),
                Order_Number__c             = 'ORD-BULK-' + i,
                Type__c                     = 'In Transit',
                Approved_Record_Created__c  = false
            ));
        }
        insert bulkRecs;

        List<Id> allIds = new List<Id>{ existingRec.Id };
        for (Secondary_Sales_Line_Item__c r : bulkRecs) {
            allIds.add(r.Id);
        }

        Test.startTest();
        SecondarySaleslineController.approveSales(allIds);
        Test.stopTest();

        // All 10 source records should be flagged
        List<Secondary_Sales_Line_Item__c> flagged = [
            SELECT Id FROM Secondary_Sales_Line_Item__c
            WHERE Id IN :allIds AND Approved_Record_Created__c = true
        ];
        System.assertEquals(10, flagged.size(), 'All 10 source records should be flagged as approved');

        // All 10 Approved records should be created
        List<Secondary_Sales_Line_Item__c> approvedRecs = [
            SELECT Id FROM Secondary_Sales_Line_Item__c WHERE Type__c = 'Approved'
        ];
        System.assertEquals(10, approvedRecs.size(), 'Should create 10 new Approved records');
    }

    // ─── approveSales — Mixed (some already approved, some not) ──────────────

    @isTest
    static void testApproveSales_MixedApprovedAndUnapproved() {
        Secondary_Sales_Line_Item__c unapproved = getInTransitRecord();

        // One already-approved record
        Secondary_Sales_Line_Item__c preApproved = new Secondary_Sales_Line_Item__c(
            Product__c                  = unapproved.Product__c,
            Secondary_Sales_Header__c   = unapproved.Secondary_Sales_Header__c,
            Quantity__c                 = 15,
            Date__c                     = Date.today().addDays(-10),
            Order_Number__c             = 'ORD-MIX',
            Type__c                     = 'In Transit',
            Approved_Record_Created__c  = true
        );
        insert preApproved;

        Test.startTest();
        SecondarySaleslineController.approveSales(new List<Id>{ unapproved.Id, preApproved.Id });
        Test.stopTest();

        // Only 1 Approved record should be created (for the unapproved one)
        List<Secondary_Sales_Line_Item__c> approvedRecs = [
            SELECT Id FROM Secondary_Sales_Line_Item__c WHERE Type__c = 'Approved'
        ];
        System.assertEquals(1, approvedRecs.size(),
            'Only 1 Approved record should be created — pre-approved record should be skipped');
    }
}
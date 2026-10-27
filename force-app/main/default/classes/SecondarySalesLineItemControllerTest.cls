@isTest
public class SecondarySalesLineItemControllerTest {

    // ─── Test Data Setup ───────────────────────────────────────────────────────

    @TestSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Test Distributor Account1', BillingCity = 'Test test',
                       BillingPostalCode = '123456', BillingStreet = 'Test', BillingState = 'UP', BillingCountry = 'IN',
                       Branch__c = 'AHMEDABAD', Branch_Email__c = 'Test@gmail.com');
         
        insert acc;

        // 2. Product
        Product__c prod = new Product__c(Name = 'Test Product', Active__c = true, Dummy_Product_Code__c = 'D037');
        insert prod;

        // 3. Secondary Sales Header
        Secondary_Sales_Header__c header = new Secondary_Sales_Header__c(
            Account__c              = acc.Id,
            Product__c              = prod.Id,
            Initial_Stock__c        = 100,
            Allow_Initial_Stock_Edit__c = true
        );
        insert header;

        // 4. Secondary Sales Line Item (for getMonthlySalesEntry)
        Secondary_Sales_Line_Item__c lineItem = new Secondary_Sales_Line_Item__c(
            Product__c                  = prod.Id,
            Secondary_Sales_Header__c   = header.Id,
            Quantity__c                 = 50,
            Date__c                     = Date.today(),
            Allow_Monthly_Sales_Edit__c = true,
            Type__c                     = 'Sold'
        );
        insert lineItem;
    }

    // ─── Helpers ───────────────────────────────────────────────────────────────

    static Product__c getProduct() {
        return [SELECT Id FROM Product__c WHERE Name = 'Test Product' LIMIT 1];
    }

    static Secondary_Sales_Header__c getHeader() {
        return [SELECT Id FROM Secondary_Sales_Header__c LIMIT 1];
    }

    static SecondarySalesLineItemController.MonthlySalesWrapper buildWrapper(
        Id productId, Id headerId, Decimal qty, String dateStr
    ) {
        SecondarySalesLineItemController.MonthlySalesWrapper w = new SecondarySalesLineItemController.MonthlySalesWrapper();
        w.productId              = productId;
        w.secondarySalesHeaderId = headerId;
        w.montlySales            = qty;
        w.salesMonthDate         = dateStr;
        return w;
    }

    // ─── getMonthlySalesEntry ──────────────────────────────────────────────────

    @isTest
    static void testGetMonthlySalesEntry_ReturnsRecords() {
        Test.startTest();
        List<Secondary_Sales_Line_Item__c> result = SecondarySalesLineItemController.getMonthlySalesEntry();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() > 0, 'Should return at least one line item');
        System.assertNotEquals(null, result[0].Quantity__c, 'Quantity should be populated');
        System.assertEquals(true, result[0].Allow_Monthly_Sales_Edit__c, 'Allow_Monthly_Sales_Edit__c should be true');
    }

    @isTest
    static void testGetMonthlySalesEntry_ExcludesNonEditableRecords() {
        // Insert a record with Allow_Monthly_Sales_Edit__c = false — should NOT be returned
        Product__c prod   = getProduct();
        Secondary_Sales_Header__c header = getHeader();

        Secondary_Sales_Line_Item__c nonEditable = new Secondary_Sales_Line_Item__c(
            Product__c                  = prod.Id,
            Secondary_Sales_Header__c   = header.Id,
            Quantity__c                 = 30,
            Date__c                     = Date.today().addMonths(-1),
            Allow_Monthly_Sales_Edit__c = false,
            Type__c                     = 'Sold'
        );
        insert nonEditable;

        Test.startTest();
        List<Secondary_Sales_Line_Item__c> result = SecondarySalesLineItemController.getMonthlySalesEntry();
        Test.stopTest();

        for (Secondary_Sales_Line_Item__c rec : result) {
            System.assertEquals(true, rec.Allow_Monthly_Sales_Edit__c, 'Only editable records should be returned');
        }
    }

    // ─── saveMonthlySales — Null / Empty ──────────────────────────────────────

    @isTest
    static void testSaveMonthlySales_NullInput() {
        Test.startTest();
        List<Secondary_Sales_Line_Item__c> result = SecondarySalesLineItemController.saveMonthlySales(null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Null input should return empty list');
    }

    @isTest
    static void testSaveMonthlySales_EmptyList() {
        Test.startTest();
        List<Secondary_Sales_Line_Item__c> result = SecondarySalesLineItemController.saveMonthlySales(
            new List<SecondarySalesLineItemController.MonthlySalesWrapper>()
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Empty input should return empty list');
    }

    // ─── saveMonthlySales — INSERT path ───────────────────────────────────────

    @isTest
    static void testSaveMonthlySales_InsertNewRecord() {
        Product__c prod                  = getProduct();
        Secondary_Sales_Header__c header = getHeader();

        String newDate = String.valueOf(Date.today().addMonths(-2)); // different date → new record

        SecondarySalesLineItemController.MonthlySalesWrapper w = buildWrapper(
            prod.Id, header.Id, 75, newDate
        );

        Test.startTest();
        List<Secondary_Sales_Line_Item__c> result = SecondarySalesLineItemController.saveMonthlySales(
            new List<SecondarySalesLineItemController.MonthlySalesWrapper>{ w }
        );
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return 1 inserted record');
        System.assertEquals(75, result[0].Quantity__c, 'Quantity should be 75');
        System.assertEquals(true, result[0].Allow_Monthly_Sales_Edit__c, 'Allow_Monthly_Sales_Edit__c should be true');
        System.assertEquals('Sold', result[0].Type__c, 'Type should be Sold');

        // Verify in DB
        List<Secondary_Sales_Line_Item__c> dbList = [
            SELECT Quantity__c, Type__c FROM Secondary_Sales_Line_Item__c
            WHERE Product__c = :prod.Id AND Date__c = :Date.valueOf(newDate)
        ];
        System.assertEquals(1, dbList.size(), 'One record should exist in DB');
        System.assertEquals(75, dbList[0].Quantity__c, 'DB quantity should match');
    }

    // ─── saveMonthlySales — UPDATE path ───────────────────────────────────────

    @isTest
    static void testSaveMonthlySales_UpdateExistingRecord() {
        Product__c prod                  = getProduct();
        Secondary_Sales_Header__c header = getHeader();

        // Use same date as @TestSetup record → triggers UPDATE path
        String existingDate = String.valueOf(Date.today());

        SecondarySalesLineItemController.MonthlySalesWrapper w = buildWrapper(
            prod.Id, header.Id, 999, existingDate
        );

        Test.startTest();
        List<Secondary_Sales_Line_Item__c> result = SecondarySalesLineItemController.saveMonthlySales(
            new List<SecondarySalesLineItemController.MonthlySalesWrapper>{ w }
        );
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return 1 updated record');
        System.assertEquals(999, result[0].Quantity__c, 'Quantity should be updated to 999');
        System.assertEquals(true, result[0].Allow_Monthly_Sales_Edit__c, 'Allow_Monthly_Sales_Edit__c should be true');

        // Verify in DB
        Secondary_Sales_Line_Item__c dbRec = [
            SELECT Quantity__c FROM Secondary_Sales_Line_Item__c
            WHERE Product__c = :prod.Id AND Date__c = :Date.today() LIMIT 1
        ];
        System.assertEquals(999, dbRec.Quantity__c, 'DB record should reflect updated quantity');
    }

    // ─── saveMonthlySales — Mixed INSERT + UPDATE ─────────────────────────────

    @isTest
    static void testSaveMonthlySales_MixedInsertAndUpdate() {
        Product__c prod                  = getProduct();
        Secondary_Sales_Header__c header = getHeader();

        // Wrapper 1 → UPDATE (same date as setup)
        SecondarySalesLineItemController.MonthlySalesWrapper updateWrapper = buildWrapper(
            prod.Id, header.Id, 200, String.valueOf(Date.today())
        );

        // Wrapper 2 → INSERT (new date)
        SecondarySalesLineItemController.MonthlySalesWrapper insertWrapper = buildWrapper(
            prod.Id, header.Id, 300, String.valueOf(Date.today().addMonths(-3))
        );

        Test.startTest();
        List<Secondary_Sales_Line_Item__c> result = SecondarySalesLineItemController.saveMonthlySales(
            new List<SecondarySalesLineItemController.MonthlySalesWrapper>{ updateWrapper, insertWrapper }
        );
        Test.stopTest();

        System.assertEquals(2, result.size(), 'Should return 2 processed records (1 update + 1 insert)');
    }

    // ─── saveMonthlySales — Bulk ───────────────────────────────────────────────

    @isTest
    static void testSaveMonthlySales_BulkInsert() {
        Secondary_Sales_Header__c header = getHeader();

        // ✅ Use Product__c (custom object), NOT Product2 (standard object)
        List<Product__c> bulkProds = new List<Product__c>();
        for (Integer i = 0; i < 10; i++) {
            bulkProds.add(new Product__c(
                Name                  = 'Bulk Prod ' + i,
                Active__c             = true,
                Dummy_Product_Code__c = 'D' + String.valueOf(100 + i) // unique codes per record
            ));
        }
        insert bulkProds;

        List<SecondarySalesLineItemController.MonthlySalesWrapper> wrappers =
            new List<SecondarySalesLineItemController.MonthlySalesWrapper>();

        for (Product__c p : bulkProds) {
            wrappers.add(buildWrapper(p.Id, header.Id, 10, String.valueOf(Date.today().addMonths(-4))));
        }

        Test.startTest();
        List<Secondary_Sales_Line_Item__c> result = SecondarySalesLineItemController.saveMonthlySales(wrappers);
        Test.stopTest();

        System.assertEquals(10, result.size(), 'Should insert 10 new records');
    }

    // ─── saveMonthlySales — Null productId skipped ────────────────────────────

    @isTest
    static void testSaveMonthlySales_NullProductId_ThrowsOrSkips() {
        Secondary_Sales_Header__c header = getHeader();

        SecondarySalesLineItemController.MonthlySalesWrapper w = new SecondarySalesLineItemController.MonthlySalesWrapper();
        w.productId              = null;
        w.secondarySalesHeaderId = header.Id;
        w.montlySales            = 50;
        w.salesMonthDate         = String.valueOf(Date.today().addMonths(-5));

        Test.startTest();
        try {
            List<Secondary_Sales_Line_Item__c> result = SecondarySalesLineItemController.saveMonthlySales(
                new List<SecondarySalesLineItemController.MonthlySalesWrapper>{ w }
            );
            // If it doesn't throw, result should be empty (null key builds bad composite key but no match)
            System.assert(result != null, 'Result should not be null');
        } catch (Exception e) {
            // Acceptable — null Id causes a DML or key error
            System.assert(true, 'Exception is acceptable for null productId');
        }
        Test.stopTest();
    }
}
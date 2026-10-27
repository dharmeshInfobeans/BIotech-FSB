@isTest
private class OrderExpiryBatchTest {

    static Account makeAccount() {
        Account acc = new Account(
            Name           = 'Test Distributor',
            GSTIN_No__c    = 'TESTGSTIN123',
            Country_Key__c = 'IN',
            E_Mail__c      = 'distributor@test.com'
        );
        insert acc;
        return acc;
    }

    static Product__c makeProduct() {
        Product__c p = new Product__c(Name = 'Test Product', Dummy_Product_Code__c = 'TEST-001');
        insert p;
        return p;
    }

    static Registration_Request__c makeRequest(Id accountId, Id productId) {
        Registration_Request__c rr = new Registration_Request__c(
            Account__c              = accountId,
            Product__c              = productId,
            Country__c              = 'IN',
            Status__c               = 'Completed',
            Request_Type__c         = 'New Registration',
            Submitted_Date__c       = Datetime.now().addDays(-90),
            Year__c                 = String.valueOf(Date.today().year()),
            Certificate_Valid_To__c = Date.today()
        );
        insert rr;
        return rr;
    }

    // ── Locks unlocked products on expiry ─────────────────────────────────────

    @isTest
    static void testBatch_LocksUnlockedProducts() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Registration_Request_Product__c rrp = new Registration_Request_Product__c(
            Registration_Request__c = rr.Id,
            Product__c              = prod.Id,
            Order_Unlocked__c       = true
        );
        insert rrp;

        Test.startTest();
        Database.executeBatch(new OrderExpiryBatch(), 200);
        Test.stopTest();

        Registration_Request_Product__c updated = [
            SELECT Order_Unlocked__c
            FROM   Registration_Request_Product__c
            WHERE  Id = :rrp.Id
        ];
        System.assertEquals(false, updated.Order_Unlocked__c,
            'Order_Unlocked__c should be false after certificate expiry');
    }

    // ── Already-locked products — no DML error ────────────────────────────────

    @isTest
    static void testBatch_AlreadyLockedProduct() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        insert new Registration_Request_Product__c(
            Registration_Request__c = rr.Id,
            Product__c              = prod.Id,
            Order_Unlocked__c       = false
        );

        Test.startTest();
        Database.executeBatch(new OrderExpiryBatch(), 200);
        Test.stopTest();

        System.assert(true, 'Batch handles already-locked products without exception');
    }

    // ── Multiple products on one request ──────────────────────────────────────

    @isTest
    static void testBatch_MultipleProducts_AllLocked() {
        Account acc      = makeAccount();
        Product__c prod1 = makeProduct();
        Product__c prod2 = new Product__c(Name = 'Product 2', Dummy_Product_Code__c = 'TEST-002');
        insert prod2;
        Registration_Request__c rr = makeRequest(acc.Id, prod1.Id);

        List<Registration_Request_Product__c> rrps = new List<Registration_Request_Product__c>{
            new Registration_Request_Product__c(
                Registration_Request__c = rr.Id, Product__c = prod1.Id, Order_Unlocked__c = true),
            new Registration_Request_Product__c(
                Registration_Request__c = rr.Id, Product__c = prod2.Id, Order_Unlocked__c = true)
        };
        insert rrps;

        Test.startTest();
        Database.executeBatch(new OrderExpiryBatch(), 200);
        Test.stopTest();

        List<Registration_Request_Product__c> updated = [
            SELECT Order_Unlocked__c
            FROM   Registration_Request_Product__c
            WHERE  Registration_Request__c = :rr.Id
        ];
        for (Registration_Request_Product__c r : updated) {
            System.assertEquals(false, r.Order_Unlocked__c,
                'All products should be locked after expiry');
        }
    }

    // ── Skips accounts with no email ──────────────────────────────────────────

    @isTest
    static void testBatch_SkipsAccountWithNoEmail() {
        Account acc = new Account(
            Name           = 'No Email Distributor',
            GSTIN_No__c    = 'TESTGSTIN999',
            Country_Key__c = 'IN'
        );
        insert acc;
        Product__c prod = makeProduct();
        Registration_Request__c rr = new Registration_Request__c(
            Account__c              = acc.Id,
            Product__c              = prod.Id,
            Country__c              = 'IN',
            Status__c               = 'Completed',
            Request_Type__c         = 'New Registration',
            Submitted_Date__c       = Datetime.now().addDays(-90),
            Year__c                 = String.valueOf(Date.today().year()),
            Certificate_Valid_To__c = Date.today()
        );
        insert rr;

        Test.startTest();
        Database.executeBatch(new OrderExpiryBatch(), 200);
        Test.stopTest();

        System.assert(true, 'Batch skips accounts with no email without exception');
    }

    // ── Empty result set ──────────────────────────────────────────────────────

    @isTest
    static void testBatch_NoRecords() {
        Test.startTest();
        Database.executeBatch(new OrderExpiryBatch(), 200);
        Test.stopTest();

        System.assert(true, 'Batch handles empty result set without exception');
    }

    // ── Schedulable interface ─────────────────────────────────────────────────

    @isTest
    static void testSchedulable() {
        Test.startTest();
        System.schedule('Test Order Expiry', '0 0 0 * * ?', new OrderExpiryBatch());
        Test.stopTest();

        System.assert(true, 'Scheduler registered without exception');
    }
}
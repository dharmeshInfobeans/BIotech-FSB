@isTest
private class DistributorMyRequestsControllerTest {

    // ── Data helpers ──────────────────────────────────────────────────────────

    static Account makeAccount() {
        Account acc = new Account(
            Name              = 'Test Distributor',
            GSTIN_No__c       = 'TESTGSTIN001',
            Country_Key__c    = 'IN',
            E_Mail__c         = 'distributor@test.com',
            BillingStreet     = '123 Test Street',
            BillingCity       = 'Mumbai',
            BillingState      = 'Maharashtra',
            BillingPostalCode = '400001'
        );
        insert acc;
        return acc;
    }

    static Product__c makeProduct() {
        Product__c p = new Product__c(Name = 'Test Product', Dummy_Product_Code__c = 'TEST-001');
        insert p;
        return p;
    }

    static User makePortalUser(Account acc) {
        Contact con = new Contact(
            FirstName = 'Test',
            LastName  = 'Portal',
            AccountId = acc.Id,
            Email     = 'myreqtest@biotestdistributor.example'
        );
        insert con;

        Profile p = [
            SELECT Id FROM Profile
            WHERE  Name = 'biotech partner community'
            LIMIT  1
        ];

        User u = new User(
            ProfileId         = p.Id,
            ContactId         = con.Id,
            Username          = 'myreqtest@biotestdistributor.example.portal',
            Alias             = 'myrtest',
            Email             = 'myreqtest@biotestdistributor.example',
            FirstName         = 'Test',
            LastName          = 'Portal',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey      = 'en_US',
            TimeZoneSidKey    = 'America/Los_Angeles'
        );
        insert u;
        return u;
    }

    static Registration_Request__c makeRequest(Id accountId, Id productId, String status) {
        Registration_Request__c rr = new Registration_Request__c(
            Account__c        = accountId,
            Product__c        = productId,
            Country__c        = 'IN',
            Status__c         = status,
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert rr;
        return rr;
    }

    // ── getMyRequests — no account returns empty list ─────────────────────────

    @isTest
    static void testGetMyRequests_NoAccount_ReturnsEmpty() {
        // Current internal test user has no AccountId
        Test.startTest();
        List<Registration_Request__c> results =
            DistributorMyRequestsController.getMyRequests('All');
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assertEquals(0, results.size());
    }

    // ── getMyRequests — no filter returns all requests for account ────────────

    @isTest
    static void testGetMyRequests_NoFilter_ReturnsAll() {
        Account acc  = makeAccount();
        User portalU = makePortalUser(acc);
        Product__c prod = makeProduct();

        Registration_Request__c r1 = makeRequest(acc.Id, prod.Id, 'Draft');
        Registration_Request__c r2 = makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory');
        Registration_Request__c r3 = makeRequest(acc.Id, prod.Id, 'Completed');

        Test.startTest();
        List<Registration_Request__c> results;
        System.runAs(portalU) {
            results = DistributorMyRequestsController.getMyRequests('All');
        }
        Test.stopTest();

        System.assertEquals(3, results.size());
    }

    // ── getMyRequests — null filter behaves as All ────────────────────────────

    @isTest
    static void testGetMyRequests_NullFilter_ReturnsAll() {
        Account acc  = makeAccount();
        User portalU = makePortalUser(acc);
        Product__c prod = makeProduct();

        makeRequest(acc.Id, prod.Id, 'Draft');
        makeRequest(acc.Id, prod.Id, 'Completed');

        Test.startTest();
        List<Registration_Request__c> results;
        System.runAs(portalU) {
            results = DistributorMyRequestsController.getMyRequests(null);
        }
        Test.stopTest();

        System.assertEquals(2, results.size());
    }

    // ── getMyRequests — blank filter behaves as All ───────────────────────────

    @isTest
    static void testGetMyRequests_BlankFilter_ReturnsAll() {
        Account acc  = makeAccount();
        User portalU = makePortalUser(acc);
        Product__c prod = makeProduct();

        makeRequest(acc.Id, prod.Id, 'Draft');
        makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory');

        Test.startTest();
        List<Registration_Request__c> results;
        System.runAs(portalU) {
            results = DistributorMyRequestsController.getMyRequests('');
        }
        Test.stopTest();

        System.assertEquals(2, results.size());
    }

    // ── getMyRequests — status filter returns only matching records ───────────

    @isTest
    static void testGetMyRequests_StatusFilter_OnlyMatchingReturned() {
        Account acc  = makeAccount();
        User portalU = makePortalUser(acc);
        Product__c prod = makeProduct();

        makeRequest(acc.Id, prod.Id, 'Draft');
        makeRequest(acc.Id, prod.Id, 'Completed');
        makeRequest(acc.Id, prod.Id, 'Completed');

        Test.startTest();
        List<Registration_Request__c> results;
        System.runAs(portalU) {
            results = DistributorMyRequestsController.getMyRequests('Completed');
        }
        Test.stopTest();

        System.assertEquals(2, results.size());
        for (Registration_Request__c rr : results) {
            System.assertEquals('Completed', rr.Status__c);
        }
    }

    // ── getMyRequests — only own account records returned ─────────────────────

    @isTest
    static void testGetMyRequests_OnlyOwnAccountReturned() {
        Account acc1 = makeAccount();
        Account acc2 = new Account(
            Name              = 'Other Distributor',
            GSTIN_No__c       = 'TESTGSTIN002',
            Country_Key__c    = 'US',
            E_Mail__c         = 'other@test.com',
            BillingStreet     = '456 Other Street',
            BillingCity       = 'Delhi',
            BillingState      = 'Delhi',
            BillingPostalCode = '110001'
        );
        insert acc2;

        User portalU    = makePortalUser(acc1);
        Product__c prod = makeProduct();

        makeRequest(acc1.Id, prod.Id, 'Draft');
        makeRequest(acc1.Id, prod.Id, 'Completed');
        makeRequest(acc2.Id, prod.Id, 'Draft');  // different account — should not appear

        Test.startTest();
        List<Registration_Request__c> results;
        System.runAs(portalU) {
            results = DistributorMyRequestsController.getMyRequests('All');
        }
        Test.stopTest();

        System.assertEquals(2, results.size(),
            'Only requests for acc1 should be returned');
        // Account__c is not in the controller's SELECT — re-query to verify account scoping
        Set<Id> returnedIds = new Set<Id>();
        for (Registration_Request__c rr : results) returnedIds.add(rr.Id);
        for (Registration_Request__c rr : [SELECT Account__c FROM Registration_Request__c WHERE Id IN :returnedIds]) {
            System.assertEquals(acc1.Id, rr.Account__c);
        }
    }

    // ── getMyRequests — required fields present on returned records ───────────

    @isTest
    static void testGetMyRequests_FieldsPresent() {
        Account acc  = makeAccount();
        User portalU = makePortalUser(acc);
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        Test.startTest();
        List<Registration_Request__c> results;
        System.runAs(portalU) {
            results = DistributorMyRequestsController.getMyRequests('All');
        }
        Test.stopTest();

        System.assertEquals(1, results.size());
        Registration_Request__c rr = results[0];
        System.assertNotEquals(null, rr.Id);
        System.assertNotEquals(null, rr.Name);
        System.assertNotEquals(null, rr.Status__c);
        System.assertNotEquals(null, rr.Request_Type__c);
        System.assertEquals('Test Product', rr.Product__r.Name);
    }

    // ── getStatusOptions — always includes All as first option ────────────────

    @isTest
    static void testGetStatusOptions_IncludesAll() {
        Test.startTest();
        List<DistributorMyRequestsController.PicklistOption> options =
            DistributorMyRequestsController.getStatusOptions();
        Test.stopTest();

        System.assert(options.size() >= 1,
            'getStatusOptions should return at least the All option');
        System.assertEquals('All',  options[0].label);
        System.assertEquals('All',  options[0].value);
    }

    // ── getStatusOptions — returns active picklist values ─────────────────────

    @isTest
    static void testGetStatusOptions_ContainsActivePicklistValues() {
        Test.startTest();
        List<DistributorMyRequestsController.PicklistOption> options =
            DistributorMyRequestsController.getStatusOptions();
        Test.stopTest();

        // Should have more than just "All" since Status__c has active values
        System.assert(options.size() > 1,
            'getStatusOptions should include active picklist entries beyond All');

        Set<String> values = new Set<String>();
        for (DistributorMyRequestsController.PicklistOption opt : options) {
            System.assertNotEquals(null, opt.label);
            System.assertNotEquals(null, opt.value);
            values.add(opt.value);
        }
        System.assert(values.contains('Draft'),
            'Active picklist values should include Draft');
    }
}
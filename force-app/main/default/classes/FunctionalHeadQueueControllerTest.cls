@isTest
private class FunctionalHeadQueueControllerTest {

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

    static Registration_Request__c makeRequest(Id accountId, Id productId,
                                               String status, Integer daysAgo) {
        Registration_Request__c rr = new Registration_Request__c(
            Account__c        = accountId,
            Product__c        = productId,
            Country__c        = 'IN',
            Status__c         = status,
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Datetime.now().addDays(-daysAgo),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert rr;
        return rr;
    }

    // ── getRequests — returns pending requests ────────────────────────────────

    @isTest
    static void testGetRequests_ReturnsPendingRequests() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Under Functional Head Review', 3);

        Test.startTest();
        List<FunctionalHeadQueueController.RequestWrapper> results =
            FunctionalHeadQueueController.getRequests();
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return 1 pending request');
        System.assertEquals('Under Functional Head Review', results[0].status);
        System.assertNotEquals(null, results[0].recId);
        System.assertNotEquals(null, results[0].distributorName);
    }

    @isTest
    static void testGetRequests_ExcludesOtherStatuses() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Submitted', 2);

        Test.startTest();
        List<FunctionalHeadQueueController.RequestWrapper> results =
            FunctionalHeadQueueController.getRequests();
        Test.stopTest();

        System.assertEquals(0, results.size(),
            'getRequests should not return requests in other statuses');
    }

    @isTest
    static void testGetRequests_NoRecords_ReturnsEmptyList() {
        Test.startTest();
        List<FunctionalHeadQueueController.RequestWrapper> results =
            FunctionalHeadQueueController.getRequests();
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assertEquals(0, results.size());
    }

    // ── isOverdue flag — set when daysPending > 7 ────────────────────────────

    @isTest
    static void testGetRequests_OverdueFlag_SetWhenOver7Days() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Under Functional Head Review', 10);

        Test.startTest();
        List<FunctionalHeadQueueController.RequestWrapper> results =
            FunctionalHeadQueueController.getRequests();
        Test.stopTest();

        System.assertEquals(true, results[0].isOverdue,
            'Request submitted 10 days ago should be overdue');
        System.assert(results[0].daysPending >= 9,
            'daysPending should be at least 9');
    }

    @isTest
    static void testGetRequests_OverdueFlag_NotSetWhenUnder7Days() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Under Functional Head Review', 3);

        Test.startTest();
        List<FunctionalHeadQueueController.RequestWrapper> results =
            FunctionalHeadQueueController.getRequests();
        Test.stopTest();

        System.assertEquals(false, results[0].isOverdue,
            'Request submitted 3 days ago should not be overdue');
    }

    // ── getPastRequests — excludes Draft and pending ──────────────────────────

    @isTest
    static void testGetPastRequests_ReturnsCompletedRequests() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Completed', 30);

        Test.startTest();
        List<FunctionalHeadQueueController.RequestWrapper> results =
            FunctionalHeadQueueController.getPastRequests();
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return 1 completed request');
        System.assertEquals('Completed', results[0].status);
        System.assertEquals(false, results[0].isOverdue,
            'Past requests always have isOverdue = false');
    }

    @isTest
    static void testGetPastRequests_ExcludesFunctionalHeadPending() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Under Functional Head Review', 5);

        Test.startTest();
        List<FunctionalHeadQueueController.RequestWrapper> results =
            FunctionalHeadQueueController.getPastRequests();
        Test.stopTest();

        System.assertEquals(0, results.size(),
            'getPastRequests should exclude Under Functional Head Review');
    }

    @isTest
    static void testGetPastRequests_ReturnsRejectedRequests() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Rejected', 15);

        Test.startTest();
        List<FunctionalHeadQueueController.RequestWrapper> results =
            FunctionalHeadQueueController.getPastRequests();
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Rejected', results[0].status);
    }

    // ── Wrapper field mapping ─────────────────────────────────────────────────

    @isTest
    static void testGetRequests_WrapperFieldsPopulated() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Under Functional Head Review', 2);

        Test.startTest();
        List<FunctionalHeadQueueController.RequestWrapper> results =
            FunctionalHeadQueueController.getRequests();
        Test.stopTest();

        FunctionalHeadQueueController.RequestWrapper w = results[0];
        System.assertNotEquals(null, w.recId);
        System.assertNotEquals(null, w.name);
        System.assertEquals('Test Distributor', w.distributorName);
        System.assertEquals('IN',               w.country);
        System.assertEquals('New Registration', w.requestType);
        System.assertNotEquals(null, w.submittedDate);
    }
}
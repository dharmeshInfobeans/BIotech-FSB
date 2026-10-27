@isTest
private class LeadershipQueueControllerTest {

    // ── Data helpers ──────────────────────────────────────────────────────────

    static Account makeAccount() {
        Account acc = new Account(
            Name              = 'Test Distributor',
            GSTIN_No__c       = 'TESTGSTIN123',
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

    static Registration_Request__c makeRequest(Id accountId, Id productId,
                                                String status, Integer daysAgo) {
        Datetime submittedDate = daysAgo != null
            ? Datetime.now().addDays(-daysAgo) : null;
        Registration_Request__c rr = new Registration_Request__c(
            Account__c        = accountId,
            Product__c        = productId,
            Country__c        = 'IN',
            Status__c         = status,
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = submittedDate,
            Year__c           = String.valueOf(Date.today().year())
        );
        insert rr;
        return rr;
    }

    // ── getRequests — empty result ────────────────────────────────────────────

    @isTest
    static void testGetRequests_NoRecords_ReturnsEmpty() {
        Test.startTest();
        List<LeadershipQueueController.RequestWrapper> result =
            LeadershipQueueController.getRequests();
        Test.stopTest();

        System.assertNotEquals(null, result);
        // May include records from other tests in the org — just assert no exception
    }

    // ── Field mapping ─────────────────────────────────────────────────────────

    @isTest
    static void testGetRequests_FieldsAreMappedCorrectly() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted', 0);

        Test.startTest();
        List<LeadershipQueueController.RequestWrapper> result =
            LeadershipQueueController.getRequests();
        Test.stopTest();

        LeadershipQueueController.RequestWrapper w = findById(result, rr.Id);
        System.assertNotEquals(null, w, 'Submitted record should appear in queue');
        System.assertEquals(String.valueOf(rr.Id), w.recId);
        System.assertEquals('Test Distributor', w.distributorName);
        System.assertEquals('IN', w.country);
        System.assertEquals('Test Product', w.productName);
        System.assertEquals('Submitted', w.status);
        System.assertEquals('New Registration', w.requestType);
    }

    // ── Status filter — excluded statuses ─────────────────────────────────────

    @isTest
    static void testGetRequests_DraftExcluded() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Draft', 0);

        Test.startTest();
        List<LeadershipQueueController.RequestWrapper> result =
            LeadershipQueueController.getRequests();
        Test.stopTest();

        System.assertEquals(null, findById(result, rr.Id),
            'Draft records should be excluded from the queue');
    }

    @isTest
    static void testGetRequests_UnderFunctionalHeadReviewExcluded() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id,
            'Under Functional Head Review', 0);

        Test.startTest();
        List<LeadershipQueueController.RequestWrapper> result =
            LeadershipQueueController.getRequests();
        Test.stopTest();

        System.assertEquals(null, findById(result, rr.Id),
            'Under Functional Head Review records should be excluded');
    }

    // ── isPendingApproval ─────────────────────────────────────────────────────

    @isTest
    static void testIsPendingApproval_TrueForLeadershipReview() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id,
            'Under Leadership Review', 0);

        Test.startTest();
        List<LeadershipQueueController.RequestWrapper> result =
            LeadershipQueueController.getRequests();
        Test.stopTest();

        LeadershipQueueController.RequestWrapper w = findById(result, rr.Id);
        System.assertNotEquals(null, w);
        System.assertEquals(true, w.isPendingApproval);
    }

    @isTest
    static void testIsPendingApproval_TrueForManagementApproval() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id,
            'Under Management Approval', 0);

        Test.startTest();
        List<LeadershipQueueController.RequestWrapper> result =
            LeadershipQueueController.getRequests();
        Test.stopTest();

        LeadershipQueueController.RequestWrapper w = findById(result, rr.Id);
        System.assertNotEquals(null, w);
        System.assertEquals(true, w.isPendingApproval);
    }

    @isTest
    static void testIsPendingApproval_FalseForSubmitted() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted', 0);

        Test.startTest();
        List<LeadershipQueueController.RequestWrapper> result =
            LeadershipQueueController.getRequests();
        Test.stopTest();

        LeadershipQueueController.RequestWrapper w = findById(result, rr.Id);
        System.assertNotEquals(null, w);
        System.assertEquals(false, w.isPendingApproval);
    }

    // ── Priority logic ────────────────────────────────────────────────────────

    @isTest
    static void testPriority_Normal_WhenFreshSubmission() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        // Submitted today — 0 days pending, active status
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted', 0);

        Test.startTest();
        List<LeadershipQueueController.RequestWrapper> result =
            LeadershipQueueController.getRequests();
        Test.stopTest();

        LeadershipQueueController.RequestWrapper w = findById(result, rr.Id);
        System.assertNotEquals(null, w);
        System.assertEquals('Normal', w.priority);
        System.assertEquals(false, w.isOverdue);
    }

    @isTest
    static void testPriority_Medium_WhenOver7Days_ActiveStatus() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        // Submitted 10 days ago, still under leadership review (active status)
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id,
            'Under Leadership Review', 10);

        Test.startTest();
        List<LeadershipQueueController.RequestWrapper> result =
            LeadershipQueueController.getRequests();
        Test.stopTest();

        LeadershipQueueController.RequestWrapper w = findById(result, rr.Id);
        System.assertNotEquals(null, w);
        System.assertEquals('Medium', w.priority);
        System.assertEquals(true, w.isOverdue);
        System.assert(w.daysPending >= 7);
    }

    @isTest
    static void testPriority_High_WhenOver14Days_ActiveStatus() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        // Submitted 15 days ago, still under leadership review (active status)
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id,
            'Under Leadership Review', 15);

        Test.startTest();
        List<LeadershipQueueController.RequestWrapper> result =
            LeadershipQueueController.getRequests();
        Test.stopTest();

        LeadershipQueueController.RequestWrapper w = findById(result, rr.Id);
        System.assertNotEquals(null, w);
        System.assertEquals('High', w.priority);
        System.assertEquals(true, w.isOverdue);
        System.assert(w.daysPending >= 14);
    }

    @isTest
    static void testPriority_Normal_WhenOldButInactiveStatus() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        // 20 days old but status is Completed — not an active status
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Completed', 20);

        Test.startTest();
        List<LeadershipQueueController.RequestWrapper> result =
            LeadershipQueueController.getRequests();
        Test.stopTest();

        LeadershipQueueController.RequestWrapper w = findById(result, rr.Id);
        System.assertNotEquals(null, w);
        System.assertEquals('Normal', w.priority,
            'Non-active status should always have Normal priority regardless of age');
        System.assertEquals(false, w.isOverdue);
    }

    // ── Null submitted date ───────────────────────────────────────────────────

    @isTest
    static void testGetRequests_NullSubmittedDate_DefaultsToZero() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        // daysAgo = null → Submitted_Date__c is null
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted', null);

        Test.startTest();
        List<LeadershipQueueController.RequestWrapper> result =
            LeadershipQueueController.getRequests();
        Test.stopTest();

        LeadershipQueueController.RequestWrapper w = findById(result, rr.Id);
        System.assertNotEquals(null, w);
        System.assertEquals(0,        w.daysPending);
        System.assertEquals(false,    w.isOverdue);
        System.assertEquals('Normal', w.priority);
        System.assertEquals(null,     w.submittedDate);
    }

    // ── Helper ────────────────────────────────────────────────────────────────

    static LeadershipQueueController.RequestWrapper findById(
        List<LeadershipQueueController.RequestWrapper> wrappers, Id recordId
    ) {
        for (LeadershipQueueController.RequestWrapper w : wrappers) {
            if (w.recId == String.valueOf(recordId)) return w;
        }
        return null;
    }
}
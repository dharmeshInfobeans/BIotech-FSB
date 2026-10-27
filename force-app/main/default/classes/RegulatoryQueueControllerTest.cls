@isTest
private class RegulatoryQueueControllerTest {

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

    static RegulatoryQueueController.RequestWrapper findById(
        List<RegulatoryQueueController.RequestWrapper> wrappers, Id recordId
    ) {
        for (RegulatoryQueueController.RequestWrapper w : wrappers) {
            if (w.recId == String.valueOf(recordId)) return w;
        }
        return null;
    }

    // ── getQueue — status filter ──────────────────────────────────────────────

    @isTest
    static void testGetQueue_IncludesRegulatoryStatuses() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();

        Registration_Request__c rr1 = makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory',       0);
        Registration_Request__c rr2 = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review',       0);
        Registration_Request__c rr3 = makeRequest(acc.Id, prod.Id, 'Additional Documents Requested',0);
        Registration_Request__c rr4 = makeRequest(acc.Id, prod.Id, 'Pending Customer Response',     0);
        Registration_Request__c rr5 = makeRequest(acc.Id, prod.Id, 'Completed',                     0);

        Test.startTest();
        List<RegulatoryQueueController.RequestWrapper> result =
            RegulatoryQueueController.getQueue();
        Test.stopTest();

        System.assertNotEquals(null, findById(result, rr1.Id), 'Submitted to Regulatory should appear');
        System.assertNotEquals(null, findById(result, rr2.Id), 'Under Regulatory Review should appear');
        System.assertNotEquals(null, findById(result, rr3.Id), 'Additional Documents Requested should appear');
        System.assertNotEquals(null, findById(result, rr4.Id), 'Pending Customer Response should appear');
        System.assertNotEquals(null, findById(result, rr5.Id), 'Completed should appear');
    }

    @isTest
    static void testGetQueue_ExcludesLeadershipStatuses() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();

        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review', 0);

        Test.startTest();
        List<RegulatoryQueueController.RequestWrapper> result =
            RegulatoryQueueController.getQueue();
        Test.stopTest();

        System.assertEquals(null, findById(result, rr.Id),
            'Under Leadership Review should NOT appear in RA queue');
    }

    // ── getQueue — field mapping ──────────────────────────────────────────────

    @isTest
    static void testGetQueue_FieldsAreMapped() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id,
            'Submitted to Regulatory', 0);

        Test.startTest();
        List<RegulatoryQueueController.RequestWrapper> result =
            RegulatoryQueueController.getQueue();
        Test.stopTest();

        RegulatoryQueueController.RequestWrapper w = findById(result, rr.Id);
        System.assertNotEquals(null, w);
        System.assertEquals(String.valueOf(rr.Id), w.recId);
        System.assertEquals('Test Distributor',    w.distributorName);
        System.assertEquals('IN',                  w.country);
        System.assertEquals('Test Product',        w.productName);
        System.assertEquals('Submitted to Regulatory', w.status);
        System.assertNotEquals(null, w.submittedDate);
    }

    // ── priority logic ────────────────────────────────────────────────────────

    @isTest
    static void testPriority_Normal_FreshRecord() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id,
            'Submitted to Regulatory', 0);

        Test.startTest();
        List<RegulatoryQueueController.RequestWrapper> result =
            RegulatoryQueueController.getQueue();
        Test.stopTest();

        RegulatoryQueueController.RequestWrapper w = findById(result, rr.Id);
        System.assertNotEquals(null, w);
        System.assertEquals('Normal', w.priority);
        System.assertEquals(false,    w.isOverdue);
    }

    @isTest
    static void testPriority_Medium_15DaysActiveStatus() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        // 15 days old, active RA status — triggers Medium (>=14)
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id,
            'Under Regulatory Review', 15);

        Test.startTest();
        List<RegulatoryQueueController.RequestWrapper> result =
            RegulatoryQueueController.getQueue();
        Test.stopTest();

        RegulatoryQueueController.RequestWrapper w = findById(result, rr.Id);
        System.assertNotEquals(null, w);
        System.assertEquals('Medium', w.priority);
        System.assertEquals(true,     w.isOverdue);
        System.assert(w.daysPending >= 14);
    }

    @isTest
    static void testPriority_High_22DaysActiveStatus() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        // 22 days old, active RA status — triggers High (>=21)
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id,
            'Submitted to Regulatory', 22);

        Test.startTest();
        List<RegulatoryQueueController.RequestWrapper> result =
            RegulatoryQueueController.getQueue();
        Test.stopTest();

        RegulatoryQueueController.RequestWrapper w = findById(result, rr.Id);
        System.assertNotEquals(null, w);
        System.assertEquals('High', w.priority);
        System.assertEquals(true,   w.isOverdue);
        System.assert(w.daysPending >= 21);
    }

    @isTest
    static void testPriority_Normal_OldCompletedRecord() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        // Completed is not an active RA status — always Normal regardless of age
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Completed', 30);

        Test.startTest();
        List<RegulatoryQueueController.RequestWrapper> result =
            RegulatoryQueueController.getQueue();
        Test.stopTest();

        RegulatoryQueueController.RequestWrapper w = findById(result, rr.Id);
        System.assertNotEquals(null, w);
        System.assertEquals('Normal', w.priority);
        System.assertEquals(false,    w.isOverdue);
    }

    // ── null Submitted_Date__c ────────────────────────────────────────────────

    @isTest
    static void testGetQueue_NullSubmittedDate_Defaults() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id,
            'Submitted to Regulatory', null);

        Test.startTest();
        List<RegulatoryQueueController.RequestWrapper> result =
            RegulatoryQueueController.getQueue();
        Test.stopTest();

        RegulatoryQueueController.RequestWrapper w = findById(result, rr.Id);
        System.assertNotEquals(null, w);
        System.assertEquals(0,        w.daysPending);
        System.assertEquals(false,    w.isOverdue);
        System.assertEquals('Normal', w.priority);
        System.assertEquals(null,     w.submittedDate);
    }

    // ── hasBasket / basketStatus ──────────────────────────────────────────────

    @isTest
    static void testGetQueue_NoBasket_HasBasketFalse() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id,
            'Submitted to Regulatory', 0);

        Test.startTest();
        List<RegulatoryQueueController.RequestWrapper> result =
            RegulatoryQueueController.getQueue();
        Test.stopTest();

        RegulatoryQueueController.RequestWrapper w = findById(result, rr.Id);
        System.assertNotEquals(null, w);
        System.assertEquals(false, w.hasBasket);
        System.assertEquals(null,  w.basketStatus);
    }

    @isTest
    static void testGetQueue_WithBasket_HasBasketTrueAndStatusMapped() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id,
            'Under Regulatory Review', 0);

        Document_Basket__c basket = new Document_Basket__c(
            Registration_Request__c = rr.Id,
            Status__c               = 'Under Review'
        );
        insert basket;

        Test.startTest();
        List<RegulatoryQueueController.RequestWrapper> result =
            RegulatoryQueueController.getQueue();
        Test.stopTest();

        RegulatoryQueueController.RequestWrapper w = findById(result, rr.Id);
        System.assertNotEquals(null, w);
        System.assertEquals(true,         w.hasBasket);
        System.assertEquals('Under Review', w.basketStatus);
    }

    // ── cycleCount — child requests ───────────────────────────────────────────

    @isTest
    static void testGetQueue_CycleCount_ZeroWhenNoChildren() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id,
            'Submitted to Regulatory', 0);

        Test.startTest();
        List<RegulatoryQueueController.RequestWrapper> result =
            RegulatoryQueueController.getQueue();
        Test.stopTest();

        RegulatoryQueueController.RequestWrapper w = findById(result, rr.Id);
        System.assertNotEquals(null, w);
        System.assertEquals(0, w.cycleCount);
    }

    @isTest
    static void testGetQueue_CycleCount_ReflectsChildRequests() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c parent = makeRequest(acc.Id, prod.Id,
            'Submitted to Regulatory', 0);

        // Two child requests
        Registration_Request__c child1 = new Registration_Request__c(
            Account__c        = acc.Id,
            Product__c        = prod.Id,
            Country__c        = 'IN',
            Status__c         = 'Submitted to Regulatory',
            Request_Type__c   = 'Additional Document Request',
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year()),
            Parent_Request__c = parent.Id
        );
        Registration_Request__c child2 = new Registration_Request__c(
            Account__c        = acc.Id,
            Product__c        = prod.Id,
            Country__c        = 'IN',
            Status__c         = 'Submitted to Regulatory',
            Request_Type__c   = 'Additional Document Request',
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year()),
            Parent_Request__c = parent.Id
        );
        insert new List<Registration_Request__c>{ child1, child2 };

        Test.startTest();
        List<RegulatoryQueueController.RequestWrapper> result =
            RegulatoryQueueController.getQueue();
        Test.stopTest();

        RegulatoryQueueController.RequestWrapper w = findById(result, parent.Id);
        System.assertNotEquals(null, w);
        System.assertEquals(2, w.cycleCount,
            'cycleCount should equal the number of child requests');
    }

    // ── certificateUploaded ───────────────────────────────────────────────────

    @isTest
    static void testGetQueue_CertificateUploaded_False_ByDefault() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id,
            'Submitted to Regulatory', 0);

        Test.startTest();
        List<RegulatoryQueueController.RequestWrapper> result =
            RegulatoryQueueController.getQueue();
        Test.stopTest();

        RegulatoryQueueController.RequestWrapper w = findById(result, rr.Id);
        System.assertNotEquals(null, w);
        System.assertEquals(false, w.certificateUploaded);
    }
}
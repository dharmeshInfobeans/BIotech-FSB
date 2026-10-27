@isTest
private class RegistrationApprovalHistoryCtrlTest {

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

    static Registration_Request__c makeRequest(Id accountId, Id productId) {
        Registration_Request__c rr = new Registration_Request__c(
            Account__c        = accountId,
            Product__c        = productId,
            Country__c        = 'IN',
            Status__c         = 'Under Leadership Review',
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert rr;
        return rr;
    }

    static Registration_Approval_History__c makeHistory(Id requestId,
                                                         String action,
                                                         String fromStatus,
                                                         String toStatus,
                                                         Datetime performedDate) {
        Registration_Approval_History__c h = new Registration_Approval_History__c(
            Registration_Request__c = requestId,
            Action__c               = action,
            From_Status__c          = fromStatus,
            To_Status__c            = toStatus,
            Stage__c                = 'CRM Review',
            Performed_By__c         = UserInfo.getUserId(),
            Performed_By_Name__c    = 'Test User',
            Performed_Date__c       = performedDate
        );
        insert h;
        return h;
    }

    // ── getHistory — empty result ─────────────────────────────────────────────

    @isTest
    static void testGetHistory_NoRecords_ReturnsEmptyEntries() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Test.startTest();
        RegistrationApprovalHistoryController.HistoryResult result =
            RegistrationApprovalHistoryController.getHistory(rr.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.entries);
        System.assertNotEquals(null, result.stats);
        System.assertEquals(0,   result.entries.size());
        System.assertEquals(0,   result.stats.totalActions);
        System.assertEquals('—', result.stats.totalElapsed);
        System.assertEquals('—', result.stats.pendingDuration);
        System.assertEquals('—', result.stats.avgPerStage);
    }

    // ── getHistory — single entry ─────────────────────────────────────────────

    @isTest
    static void testGetHistory_SingleEntry_FieldsMapped() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Datetime now = Datetime.now();
        makeHistory(rr.Id, 'Forwarded to Leadership',
                    'Submitted', 'Under Leadership Review', now);

        Test.startTest();
        RegistrationApprovalHistoryController.HistoryResult result =
            RegistrationApprovalHistoryController.getHistory(rr.Id);
        Test.stopTest();

        System.assertEquals(1, result.entries.size());
        RegistrationApprovalHistoryController.HistoryEntry e = result.entries[0];

        System.assertEquals(1,                          e.entryIndex);
        System.assertEquals('Forwarded to Leadership',  e.action);
        System.assertEquals('CRM Review',               e.stage);
        System.assertEquals('Submitted',                e.fromStatus);
        System.assertEquals('Under Leadership Review',  e.toStatus);
        System.assertEquals('Test User',                e.performedByName);
        System.assertNotEquals(null, e.performedDate);
        System.assertNotEquals('',   e.performedDate);
        System.assertNotEquals(null, e.performedDateLabel);
        System.assertNotEquals('',   e.performedDateLabel);
    }

    @isTest
    static void testGetHistory_SingleEntry_FirstHasNoDuration() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        makeHistory(rr.Id, 'Forwarded to Leadership',
                    'Submitted', 'Under Leadership Review', Datetime.now());

        Test.startTest();
        RegistrationApprovalHistoryController.HistoryResult result =
            RegistrationApprovalHistoryController.getHistory(rr.Id);
        Test.stopTest();

        RegistrationApprovalHistoryController.HistoryEntry e = result.entries[0];
        System.assertEquals(0L, e.durationMinutes,
            'First entry should have 0 duration (no prior entry)');
        System.assertEquals('', e.durationLabel,
            'First entry should have empty durationLabel');
    }

    // ── getHistory — multiple entries ─────────────────────────────────────────

    @isTest
    static void testGetHistory_MultipleEntries_IndexedInOrder() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Datetime t1 = Datetime.now().addMinutes(-60);
        Datetime t2 = Datetime.now().addMinutes(-30);
        Datetime t3 = Datetime.now();

        makeHistory(rr.Id, 'Forwarded to Leadership',
                    'Submitted',              'Under Leadership Review', t1);
        makeHistory(rr.Id, 'Approved',
                    'Under Leadership Review','Submitted to Regulatory', t2);
        makeHistory(rr.Id, 'RA Started Review',
                    'Submitted to Regulatory','Under Regulatory Review', t3);

        Test.startTest();
        RegistrationApprovalHistoryController.HistoryResult result =
            RegistrationApprovalHistoryController.getHistory(rr.Id);
        Test.stopTest();

        System.assertEquals(3, result.entries.size());
        System.assertEquals(1, result.entries[0].entryIndex);
        System.assertEquals(2, result.entries[1].entryIndex);
        System.assertEquals(3, result.entries[2].entryIndex);
    }

    @isTest
    static void testGetHistory_MultipleEntries_DurationComputedBetweenActions() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Datetime t1 = Datetime.now().addMinutes(-120);
        Datetime t2 = Datetime.now().addMinutes(-60);

        makeHistory(rr.Id, 'Forwarded to Leadership',
                    'Submitted', 'Under Leadership Review', t1);
        makeHistory(rr.Id, 'Approved',
                    'Under Leadership Review', 'Submitted to Regulatory', t2);

        Test.startTest();
        RegistrationApprovalHistoryController.HistoryResult result =
            RegistrationApprovalHistoryController.getHistory(rr.Id);
        Test.stopTest();

        RegistrationApprovalHistoryController.HistoryEntry second = result.entries[1];
        System.assert(second.durationMinutes >= 55 && second.durationMinutes <= 65,
            'Duration between entries should be ~60 minutes');
        System.assert(second.durationLabel.startsWith('Waited'),
            'durationLabel should start with "Waited"');
    }

    // ── stats — totalActions ──────────────────────────────────────────────────

    @isTest
    static void testStats_TotalActions() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        makeHistory(rr.Id, 'Action 1', 'Submitted', 'Under Leadership Review',
                    Datetime.now().addHours(-3));
        makeHistory(rr.Id, 'Action 2', 'Under Leadership Review', 'Submitted to Regulatory',
                    Datetime.now().addHours(-1));

        Test.startTest();
        RegistrationApprovalHistoryController.HistoryResult result =
            RegistrationApprovalHistoryController.getHistory(rr.Id);
        Test.stopTest();

        System.assertEquals(2, result.stats.totalActions);
    }

    @isTest
    static void testStats_AvgPerStage_DashForSingleEntry() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        makeHistory(rr.Id, 'Forwarded to Leadership',
                    'Submitted', 'Under Leadership Review', Datetime.now());

        Test.startTest();
        RegistrationApprovalHistoryController.HistoryResult result =
            RegistrationApprovalHistoryController.getHistory(rr.Id);
        Test.stopTest();

        System.assertEquals('—', result.stats.avgPerStage,
            'avgPerStage should be — when there is only one entry');
    }

    @isTest
    static void testStats_AvgPerStage_ComputedForMultipleEntries() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        makeHistory(rr.Id, 'Action 1', 'Submitted', 'Under Leadership Review',
                    Datetime.now().addHours(-4));
        makeHistory(rr.Id, 'Action 2', 'Under Leadership Review', 'Submitted to Regulatory',
                    Datetime.now().addHours(-2));
        makeHistory(rr.Id, 'Action 3', 'Submitted to Regulatory', 'Completed',
                    Datetime.now());

        Test.startTest();
        RegistrationApprovalHistoryController.HistoryResult result =
            RegistrationApprovalHistoryController.getHistory(rr.Id);
        Test.stopTest();

        System.assertNotEquals('—',  result.stats.avgPerStage,
            'avgPerStage should be a computed value when multiple entries exist');
        System.assertNotEquals(null, result.stats.avgPerStage);
    }

    // ── dotClass ──────────────────────────────────────────────────────────────

    @isTest
    static void testDotClass_VariousActions() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Datetime base = Datetime.now().addHours(-10);

        makeHistory(rr.Id, 'Request Rejected',        'X', 'Rejected',
                    base.addMinutes(10));
        makeHistory(rr.Id, 'Sent Back to Distributor','Rejected', 'Sent Back',
                    base.addMinutes(20));
        makeHistory(rr.Id, 'Approved by Leadership',  'Sent Back', 'Submitted to Regulatory',
                    base.addMinutes(30));
        makeHistory(rr.Id, 'Submitted to Regulatory', 'Submitted to Regulatory', 'Under Regulatory Review',
                    base.addMinutes(40));
        makeHistory(rr.Id, 'Resumed from On Hold',    'On Hold', 'Submitted',
                    base.addMinutes(50));
        makeHistory(rr.Id, 'Forwarded to Leadership', 'Submitted', 'Under Leadership Review',
                    base.addMinutes(60));

        Test.startTest();
        RegistrationApprovalHistoryController.HistoryResult result =
            RegistrationApprovalHistoryController.getHistory(rr.Id);
        Test.stopTest();

        Map<String, String> actionToDot = new Map<String, String>();
        for (RegistrationApprovalHistoryController.HistoryEntry e : result.entries) {
            actionToDot.put(e.action, e.dotClass);
        }

        System.assertEquals('dot-rejected',    actionToDot.get('Request Rejected'));
        System.assertEquals('dot-sent-back',   actionToDot.get('Sent Back to Distributor'));
        System.assertEquals('dot-approved',    actionToDot.get('Approved by Leadership'));
        System.assertEquals('dot-regulatory',  actionToDot.get('Submitted to Regulatory'));
        System.assertEquals('dot-resumed',     actionToDot.get('Resumed from On Hold'));
        System.assertEquals('dot-forwarded',   actionToDot.get('Forwarded to Leadership'));
    }

    @isTest
    static void testDotClass_NullAction_ReturnsNeutral() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Registration_Approval_History__c h = new Registration_Approval_History__c(
            Registration_Request__c = rr.Id,
            Action__c               = 'Unknown Action',
            From_Status__c          = 'Submitted',
            To_Status__c            = 'Under Leadership Review',
            Stage__c                = 'CRM Review',
            Performed_By__c         = UserInfo.getUserId(),
            Performed_By_Name__c    = 'Test User',
            Performed_Date__c       = Datetime.now()
        );
        insert h;

        Test.startTest();
        RegistrationApprovalHistoryController.HistoryResult result =
            RegistrationApprovalHistoryController.getHistory(rr.Id);
        Test.stopTest();

        System.assertEquals('dot-forwarded', result.entries[0].dotClass,
            'Unrecognized action should produce dot-forwarded');
    }

    // ── performedByName fallback ──────────────────────────────────────────────

    @isTest
    static void testPerformedByName_FallsBackToUnknown() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Registration_Approval_History__c h = new Registration_Approval_History__c(
            Registration_Request__c = rr.Id,
            Action__c               = 'Some Action',
            From_Status__c          = 'Submitted',
            To_Status__c            = 'Under Leadership Review',
            Stage__c                = 'CRM Review',
            Performed_By__c         = UserInfo.getUserId(),
            Performed_By_Name__c    = '',
            Performed_Date__c       = Datetime.now()
        );
        insert h;

        Test.startTest();
        RegistrationApprovalHistoryController.HistoryResult result =
            RegistrationApprovalHistoryController.getHistory(rr.Id);
        Test.stopTest();

        System.assertEquals('Unknown', result.entries[0].performedByName,
            'Blank Performed_By_Name__c should fall back to "Unknown"');
    }

    // ── comments ─────────────────────────────────────────────────────────────

    @isTest
    static void testComments_Preserved() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Registration_Approval_History__c h = new Registration_Approval_History__c(
            Registration_Request__c = rr.Id,
            Action__c               = 'Rejected',
            From_Status__c          = 'Under Leadership Review',
            To_Status__c            = 'Rejected',
            Comments__c             = 'Missing GSTIN certificate',
            Stage__c                = 'Leadership Review',
            Performed_By__c         = UserInfo.getUserId(),
            Performed_By_Name__c    = 'Test User',
            Performed_Date__c       = Datetime.now()
        );
        insert h;

        Test.startTest();
        RegistrationApprovalHistoryController.HistoryResult result =
            RegistrationApprovalHistoryController.getHistory(rr.Id);
        Test.stopTest();

        System.assertEquals('Missing GSTIN certificate', result.entries[0].comments);
    }
}
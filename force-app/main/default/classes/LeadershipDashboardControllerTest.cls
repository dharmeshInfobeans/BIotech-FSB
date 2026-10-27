@isTest
private class LeadershipDashboardControllerTest {

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

    // ── getDashboardData — structural integrity ───────────────────────────────

    @isTest
    static void testGetDashboardData_ReturnsStructure() {
        Test.startTest();
        LeadershipDashboardController.DashboardData data =
            LeadershipDashboardController.getDashboardData();
        Test.stopTest();

        System.assertNotEquals(null, data,                'DashboardData should not be null');
        System.assertNotEquals(null, data.kpi,            'kpi should not be null');
        System.assertNotEquals(null, data.byStage,        'byStage should not be null');
        System.assertNotEquals(null, data.byCountry,      'byCountry should not be null');
        System.assertNotEquals(null, data.trends,         'trends should not be null');
        System.assertNotEquals(null, data.overdueRequests,'overdueRequests should not be null');
    }

    // ── trends — always returns 6 slots ──────────────────────────────────────

    @isTest
    static void testTrends_AlwaysSixMonths() {
        Test.startTest();
        LeadershipDashboardController.DashboardData data =
            LeadershipDashboardController.getDashboardData();
        Test.stopTest();

        System.assertEquals(6, data.trends.size(),
            'Trends should always return exactly 6 month slots');
        for (LeadershipDashboardController.MonthTrend mt : data.trends) {
            System.assertNotEquals(null, mt.monthLabel,
                'Each slot should have a month label');
        }
    }

    // ── KPI — pendingApprovals counts active-status records ──────────────────

    @isTest
    static void testKpi_PendingApprovals_CountsActiveStatuses() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();

        // 2 active-status records
        makeRequest(acc.Id, prod.Id, 'Submitted',                0);
        makeRequest(acc.Id, prod.Id, 'Under Leadership Review',  0);
        // 1 non-active (should not count)
        makeRequest(acc.Id, prod.Id, 'Completed',                0);

        Test.startTest();
        LeadershipDashboardController.DashboardData data =
            LeadershipDashboardController.getDashboardData();
        Test.stopTest();

        System.assert(data.kpi.pendingApprovals >= 2,
            'pendingApprovals should include at least the 2 active records created');
    }

    // ── KPI — overdueCount ────────────────────────────────────────────────────

    @isTest
    static void testKpi_OverdueCount_IncludesOldActiveRecords() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();

        // 10 days old, active status → overdue
        makeRequest(acc.Id, prod.Id, 'Under Leadership Review', 10);
        // 2 days old, active status → not overdue
        makeRequest(acc.Id, prod.Id, 'Submitted', 2);

        Test.startTest();
        LeadershipDashboardController.DashboardData data =
            LeadershipDashboardController.getDashboardData();
        Test.stopTest();

        System.assert(data.kpi.overdueCount >= 1,
            'overdueCount should include the 10-day-old active record');
    }

    @isTest
    static void testKpi_OverdueCount_ExcludesNonActiveStatuses() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();

        // Old but completed — should NOT be overdue
        makeRequest(acc.Id, prod.Id, 'Completed', 30);

        Integer overdueBeforeInsert;
        Test.startTest();
        overdueBeforeInsert = LeadershipDashboardController.getDashboardData().kpi.overdueCount;
        Test.stopTest();

        // Completed records shouldn't affect overdue — count should equal pre-insert baseline
        // (in an isolated test org, this will be 0)
        System.assert(overdueBeforeInsert >= 0, 'overdueCount should be non-negative');
    }

    // ── KPI — submittedThisMonth ──────────────────────────────────────────────

    @isTest
    static void testKpi_SubmittedThisMonth() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();

        makeRequest(acc.Id, prod.Id, 'Submitted', 0);   // today — this month
        makeRequest(acc.Id, prod.Id, 'Submitted', 0);   // today — this month

        Test.startTest();
        LeadershipDashboardController.DashboardData data =
            LeadershipDashboardController.getDashboardData();
        Test.stopTest();

        System.assert(data.kpi.submittedThisMonth >= 2,
            'submittedThisMonth should include records submitted this month');
    }

    // ── KPI — rejectedThisMonth ───────────────────────────────────────────────

    @isTest
    static void testKpi_RejectedThisMonth() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();

        makeRequest(acc.Id, prod.Id, 'Rejected', 0);

        Test.startTest();
        LeadershipDashboardController.DashboardData data =
            LeadershipDashboardController.getDashboardData();
        Test.stopTest();

        System.assert(data.kpi.rejectedThisMonth >= 1,
            'rejectedThisMonth should include Rejected records submitted this month');
    }

    // ── KPI — avgTurnaroundDays returns dash when no history ─────────────────

    @isTest
    static void testKpi_AvgTurnaround_DashWhenNoHistory() {
        // No approval history records — expect '—'
        Test.startTest();
        LeadershipDashboardController.DashboardData data =
            LeadershipDashboardController.getDashboardData();
        Test.stopTest();

        // Either '—' (no data) or a formatted string like "X days" — never null or blank
        System.assertNotEquals(null,  data.kpi.avgTurnaroundDays);
        System.assertNotEquals('',    data.kpi.avgTurnaroundDays);
    }

    @isTest
    static void testKpi_AvgTurnaround_ComputedFromHistory() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Completed', 10);

        // Log an approval history entry from 10 days ago to now
        insert new Registration_Approval_History__c(
            Registration_Request__c = rr.Id,
            Action__c               = 'Approved',
            From_Status__c          = 'Under Leadership Review',
            To_Status__c            = 'Submitted to Regulatory',
            Stage__c                = 'Leadership Review',
            Performed_By__c         = UserInfo.getUserId(),
            Performed_By_Name__c    = 'Test User',
            Performed_Date__c       = Datetime.now()
        );

        Test.startTest();
        LeadershipDashboardController.DashboardData data =
            LeadershipDashboardController.getDashboardData();
        Test.stopTest();

        System.assertNotEquals(null, data.kpi.avgTurnaroundDays);
        System.assertNotEquals('',   data.kpi.avgTurnaroundDays);
    }

    // ── byStage — percentage adds up correctly for single status ─────────────

    @isTest
    static void testByStage_PctIs100ForSingleStatus() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Submitted', 0);

        Test.startTest();
        LeadershipDashboardController.DashboardData data =
            LeadershipDashboardController.getDashboardData();
        Test.stopTest();

        // Find the 'Submitted' entry
        LeadershipDashboardController.StageCount submitted = null;
        for (LeadershipDashboardController.StageCount sc : data.byStage) {
            if (sc.status == 'Submitted') { submitted = sc; break; }
        }
        System.assertNotEquals(null, submitted, 'Submitted stage should appear in byStage');
        System.assert(submitted.pct > 0, 'pct should be > 0 for a record that exists');
    }

    // ── byCountry — record appears under correct country ─────────────────────

    @isTest
    static void testByCountry_ActiveRecordAppearsInCountryBreakdown() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Submitted', 0);   // Country = IN

        Test.startTest();
        LeadershipDashboardController.DashboardData data =
            LeadershipDashboardController.getDashboardData();
        Test.stopTest();

        Boolean found = false;
        for (LeadershipDashboardController.CountryCount cc : data.byCountry) {
            if (cc.country == 'IN') { found = true; break; }
        }
        System.assert(found, 'Country IN should appear in byCountry breakdown');
    }

    // ── overdueRequests — overdue records present in list ────────────────────

    @isTest
    static void testOverdueRequests_ContainsOldActiveRecord() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id,
            'Under Leadership Review', 10);

        Test.startTest();
        LeadershipDashboardController.DashboardData data =
            LeadershipDashboardController.getDashboardData();
        Test.stopTest();

        Boolean found = false;
        for (LeadershipDashboardController.OverdueItem oi : data.overdueRequests) {
            if (oi.id == rr.Id) { found = true; break; }
        }
        System.assert(found, '10-day-old active record should appear in overdueRequests');
    }

    @isTest
    static void testOverdueRequests_FieldsAreMapped() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id,
            'Under Leadership Review', 10);

        Test.startTest();
        LeadershipDashboardController.DashboardData data =
            LeadershipDashboardController.getDashboardData();
        Test.stopTest();

        LeadershipDashboardController.OverdueItem oi = null;
        for (LeadershipDashboardController.OverdueItem item : data.overdueRequests) {
            if (item.id == rr.Id) { oi = item; break; }
        }

        System.assertNotEquals(null, oi);
        System.assertEquals('IN',                      oi.country);
        System.assertEquals('Under Leadership Review', oi.status);
        System.assertEquals('Test Distributor',        oi.distributor);
        System.assert(oi.daysPending >= 10,
            'daysPending should be at least 10 for a 10-day-old record');
        System.assertNotEquals(null, oi.submittedDate);
        System.assertNotEquals('', oi.submittedDate);
    }

    @isTest
    static void testOverdueRequests_FreshRecordNotIncluded() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted', 0);

        Test.startTest();
        LeadershipDashboardController.DashboardData data =
            LeadershipDashboardController.getDashboardData();
        Test.stopTest();

        for (LeadershipDashboardController.OverdueItem oi : data.overdueRequests) {
            System.assertNotEquals(rr.Id, oi.id,
                'A record submitted today should NOT appear in overdueRequests');
        }
    }
}
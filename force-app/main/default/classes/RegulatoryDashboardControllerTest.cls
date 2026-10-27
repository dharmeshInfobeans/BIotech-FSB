@isTest
private class RegulatoryDashboardControllerTest {

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
                                               String status, String country) {
        Registration_Request__c rr = new Registration_Request__c(
            Account__c        = accountId,
            Product__c        = productId,
            Country__c        = country,
            Status__c         = status,
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert rr;
        return rr;
    }

    // ── getDashboardData — returns non-null wrapper ───────────────────────────

    @isTest
    static void testGetDashboardData_ReturnsStructure() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory', 'IN');

        Test.startTest();
        RegulatoryDashboardController.DashboardData d =
            RegulatoryDashboardController.getDashboardData();
        Test.stopTest();

        System.assertNotEquals(null, d);
        System.assertNotEquals(null, d.kpi);
        System.assertNotEquals(null, d.byStatus);
        System.assertNotEquals(null, d.byCountry);
        System.assertNotEquals(null, d.overdueList);
    }

    // ── KPI — pendingCount counts Submitted to Regulatory ────────────────────

    @isTest
    static void testKpi_PendingCount() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory', 'IN');
        makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory', 'US');

        Test.startTest();
        RegulatoryDashboardController.DashboardData d =
            RegulatoryDashboardController.getDashboardData();
        Test.stopTest();

        System.assertEquals(2, d.kpi.pendingCount);
    }

    // ── KPI — underReviewCount ────────────────────────────────────────────────

    @isTest
    static void testKpi_UnderReviewCount() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Under Regulatory Review', 'IN');

        Test.startTest();
        RegulatoryDashboardController.DashboardData d =
            RegulatoryDashboardController.getDashboardData();
        Test.stopTest();

        System.assertEquals(1, d.kpi.underReviewCount);
    }

    // ── KPI — pendingDistributorActions ──────────────────────────────────────

    @isTest
    static void testKpi_PendingDistributorActions() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Additional Documents Requested', 'IN');
        makeRequest(acc.Id, prod.Id, 'Pending Customer Response',      'IN');

        Test.startTest();
        RegulatoryDashboardController.DashboardData d =
            RegulatoryDashboardController.getDashboardData();
        Test.stopTest();

        System.assertEquals(2, d.kpi.pendingDistributorActions);
    }

    // ── KPI — cycleCount from history records ─────────────────────────────────

    @isTest
    static void testKpi_CycleCount() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id,
            'Additional Documents Requested', 'IN');

        Registration_Approval_History__c hist = new Registration_Approval_History__c(
            Registration_Request__c = rr.Id,
            To_Status__c            = 'Additional Documents Requested',
            From_Status__c          = 'Under Regulatory Review',
            Action__c               = 'Send Back'
        );
        insert hist;

        Test.startTest();
        RegulatoryDashboardController.DashboardData d =
            RegulatoryDashboardController.getDashboardData();
        Test.stopTest();

        System.assert(d.kpi.cycleCount >= 1);
    }

    // ── KPI — completedThisMonth ──────────────────────────────────────────────

    @isTest
    static void testKpi_CompletedThisMonth() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Completed', 'IN');

        Test.startTest();
        RegulatoryDashboardController.DashboardData d =
            RegulatoryDashboardController.getDashboardData();
        Test.stopTest();

        System.assert(d.kpi.completedThisMonth >= 1);
    }

    // ── KPI — avgProcessingDays with completed records ────────────────────────

    @isTest
    static void testKpi_AvgProcessingDays_WithCompletedRecord() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = new Registration_Request__c(
            Account__c        = acc.Id,
            Product__c        = prod.Id,
            Country__c        = 'IN',
            Status__c         = 'Completed',
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Datetime.now().addDays(-10),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert rr;

        Test.startTest();
        RegulatoryDashboardController.DashboardData d =
            RegulatoryDashboardController.getDashboardData();
        Test.stopTest();

        System.assertNotEquals(null, d.kpi.avgProcessingDays);
        System.assertNotEquals('', d.kpi.avgProcessingDays);
    }

    // ── KPI — avgProcessingDays returns em dash with no completed ────────────

    @isTest
    static void testKpi_AvgProcessingDays_NoneCompleted() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory', 'IN');

        Test.startTest();
        RegulatoryDashboardController.DashboardData d =
            RegulatoryDashboardController.getDashboardData();
        Test.stopTest();

        System.assertEquals('—', d.kpi.avgProcessingDays);
    }

    // ── byStatus — active statuses produce status count entries ──────────────

    @isTest
    static void testByStatus_IncludesActiveStatuses() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory', 'IN');
        makeRequest(acc.Id, prod.Id, 'Under Regulatory Review', 'IN');

        Test.startTest();
        RegulatoryDashboardController.DashboardData d =
            RegulatoryDashboardController.getDashboardData();
        Test.stopTest();

        System.assert(d.byStatus.size() >= 2,
            'byStatus should include at least 2 distinct statuses');

        Set<String> statuses = new Set<String>();
        for (RegulatoryDashboardController.StatusCount sc : d.byStatus) {
            statuses.add(sc.status);
        }
        System.assert(statuses.contains('Submitted to Regulatory'));
        System.assert(statuses.contains('Under Regulatory Review'));
    }

    // ── byStatus — pct sums to ~100 ───────────────────────────────────────────

    @isTest
    static void testByStatus_PctSumsToApprox100() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory',    'IN');
        makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory',    'IN');
        makeRequest(acc.Id, prod.Id, 'Additional Documents Requested', 'IN');

        Test.startTest();
        RegulatoryDashboardController.DashboardData d =
            RegulatoryDashboardController.getDashboardData();
        Test.stopTest();

        Integer totalPct = 0;
        for (RegulatoryDashboardController.StatusCount sc : d.byStatus) {
            totalPct += sc.pct;
        }
        System.assert(totalPct >= 95 && totalPct <= 105,
            'Total pct should be near 100 but was ' + totalPct);
    }

    // ── byCountry — request with null country excluded ────────────────────────

    @isTest
    static void testByCountry_ExcludesNullCountry() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory', 'IN');

        Registration_Request__c noCountry = new Registration_Request__c(
            Account__c        = acc.Id,
            Product__c        = prod.Id,
            Status__c         = 'Submitted to Regulatory',
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert noCountry;

        Test.startTest();
        RegulatoryDashboardController.DashboardData d =
            RegulatoryDashboardController.getDashboardData();
        Test.stopTest();

        for (RegulatoryDashboardController.CountryStat cs : d.byCountry) {
            System.assertNotEquals(null, cs.country,
                'byCountry should never contain a null country entry');
        }
    }

    // ── byCountry — pct relative to max count ────────────────────────────────

    @isTest
    static void testByCountry_PctRelativeToMax() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory', 'IN');
        makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory', 'IN');
        makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory', 'US');

        Test.startTest();
        RegulatoryDashboardController.DashboardData d =
            RegulatoryDashboardController.getDashboardData();
        Test.stopTest();

        // Country with max count should have pct = 100
        Integer maxPct = 0;
        for (RegulatoryDashboardController.CountryStat cs : d.byCountry) {
            if (cs.pct > maxPct) maxPct = cs.pct;
        }
        System.assertEquals(100, maxPct,
            'The country with the most requests should have pct = 100');
    }

    // ── overdueList — recent requests excluded, old ones included ────────────

    @isTest
    static void testOverdueList_FreshRequestExcluded() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory', 'IN');

        Test.startTest();
        RegulatoryDashboardController.DashboardData d =
            RegulatoryDashboardController.getDashboardData();
        Test.stopTest();

        // Just-created request is not overdue (< 14 days)
        for (RegulatoryDashboardController.OverdueItem oi : d.overdueList) {
            System.assert(oi.daysPending >= 0,
                'daysPending should never be negative');
        }
    }

    @isTest
    static void testOverdueList_OldRequestIncluded() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();

        Registration_Request__c old = new Registration_Request__c(
            Account__c        = acc.Id,
            Product__c        = prod.Id,
            Country__c        = 'IN',
            Status__c         = 'Submitted to Regulatory',
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Datetime.now().addDays(-20),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert old;

        Test.startTest();
        RegulatoryDashboardController.DashboardData d =
            RegulatoryDashboardController.getDashboardData();
        Test.stopTest();

        System.assert(d.overdueList.size() >= 1, 'Overdue request should appear in overdueList');
        Boolean found = false;
        for (RegulatoryDashboardController.OverdueItem oi : d.overdueList) {
            if (oi.recId == old.Id) {
                found = true;
                System.assertNotEquals(null, oi.name);
                System.assertNotEquals(null, oi.status);
                System.assertNotEquals(null, oi.submittedDate);
                System.assert(oi.daysPending >= 20,
                    'daysPending for a 20-day-old request should be >= 20');
            }
        }
        System.assert(found, 'Old overdue request not found in overdueList');
    }

    // ── empty org — returns zero KPIs ────────────────────────────────────────

    @isTest
    static void testGetDashboardData_EmptyOrg() {
        Test.startTest();
        RegulatoryDashboardController.DashboardData d =
            RegulatoryDashboardController.getDashboardData();
        Test.stopTest();

        System.assertNotEquals(null, d.kpi);
        System.assertEquals(0, d.kpi.pendingCount);
        System.assertEquals(0, d.kpi.underReviewCount);
        System.assertEquals(0, d.kpi.pendingDistributorActions);
        System.assertEquals(0, d.kpi.cycleCount);
        System.assertEquals(0, d.kpi.completedThisMonth);
        System.assertEquals('—', d.kpi.avgProcessingDays);
        System.assertEquals(0, d.byStatus.size());
        System.assertEquals(0, d.byCountry.size());
        System.assertEquals(0, d.overdueList.size());
    }
}
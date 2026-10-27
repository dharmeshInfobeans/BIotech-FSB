@isTest(SeeAllData=true)
private class HomeSnapshotControllerTest {
    // Same SeeAllData rationale as ProspectsDashboardControllerTest: this controller is read-only,
    // and Lead__c/Opportunity__c carry enough validation-rule complexity that synthetic DML isn't
    // worth fighting - real sandbox data is used instead.

    private static final Map<String, Integer> QUARTER_START_MONTH = new Map<String, Integer>{
        'Q1' => 1, 'Q2' => 4, 'Q3' => 7, 'Q4' => 10
    };

    private static String currentQuarter() {
        Integer month = Date.today().month();
        if (month <= 3) {
            return 'Q1';
        } else if (month <= 6) {
            return 'Q2';
        } else if (month <= 9) {
            return 'Q3';
        }
        return 'Q4';
    }

    @isTest
    static void testGetHomeSnapshotDefaultsToCurrentYearAndQuarterWhenNull() {
        Integer year = Date.today().year();
        String quarter = currentQuarter();
        // Direct comparison uses Lead_Created_Quarter_No__c (the IST-correct formula field), not
        // CALENDAR_MONTH (GMT-based) - that's exactly what buildDateCondition() uses for Lead__c
        // Quarter filtering, and the two can disagree for a handful of records sitting right on a
        // quarter boundary (see testGetHomeSnapshotDoesNotLeakOtherYears' 2026-10 production fix).
        Integer directProspects = [
            SELECT COUNT() FROM Lead__c
            WHERE CALENDAR_YEAR(CreatedDate) = :year AND Lead_Created_Quarter_No__c = :quarter
        ];

        Test.startTest();
        HomeSnapshotController.HomeSnapshot snap = HomeSnapshotController.getHomeSnapshot(null, null);
        Test.stopTest();

        System.assertEquals(year, snap.year, 'a null year should default to the current year');
        System.assertEquals(quarter, snap.quarter, 'a null quarter should default to the current quarter');
        System.assertEquals(
            directProspects,
            snap.tiles.prospectsGenerated,
            'defaulting to the current year/quarter should match a direct count for it'
        );
        System.assertEquals(3, snap.generationByMonth.labels.size(), 'a single quarter means 3 month labels');
    }

    @isTest
    static void testGetHomeSnapshotTilesMatchDirectCountsForYearAndQuarter() {
        Integer year = Date.today().year();
        String quarter = currentQuarter();
        Integer startMonth = QUARTER_START_MONTH.get(quarter);
        List<Integer> months = new List<Integer>{ startMonth, startMonth + 1, startMonth + 2 };

        // Lead__c comparisons use Lead_Created_Quarter_No__c (IST-correct), matching
        // buildDateCondition()'s own Quarter handling for Lead__c - see
        // testGetHomeSnapshotDefaultsToCurrentYearAndQuarterWhenNull for why. Opportunity__c/
        // Sample_Request_Header__c below correctly stay on CALENDAR_MONTH, since that's what the
        // controller itself uses for those two objects (no equivalent IST formula field exists).
        Integer directProspects = [
            SELECT COUNT() FROM Lead__c
            WHERE CALENDAR_YEAR(CreatedDate) = :year AND Lead_Created_Quarter_No__c = :quarter
        ];
        Integer directLost = [
            SELECT COUNT() FROM Lead__c
            WHERE CALENDAR_YEAR(CreatedDate) = :year AND Lead_Created_Quarter_No__c = :quarter AND Lead_Stage__c = 'Unqualified'
        ];
        AggregateResult wonAgg = [
            SELECT SUM(Total_PF_ASP__c) total FROM Opportunity__c
            WHERE CALENDAR_YEAR(CreatedDate) = :year AND CALENDAR_MONTH(CreatedDate) IN :months AND Status__c = 'Closed Won'
        ];
        AggregateResult notWonAgg = [
            SELECT SUM(Total_PF_ASP__c) total FROM Opportunity__c
            WHERE CALENDAR_YEAR(CreatedDate) = :year AND CALENDAR_MONTH(CreatedDate) IN :months AND Status__c != 'Closed Won'
        ];
        Decimal directWon = wonAgg.get('total') == null ? 0 : (Decimal) wonAgg.get('total');
        Decimal directNotWon = notWonAgg.get('total') == null ? 0 : (Decimal) notWonAgg.get('total');
        Integer directSamples = [
            SELECT COUNT() FROM Sample_Request_Header__c
            WHERE CALENDAR_YEAR(CreatedDate) = :year AND CALENDAR_MONTH(CreatedDate) IN :months AND Approval_Status__c = 'Approved'
        ];

        Test.startTest();
        HomeSnapshotController.HomeSnapshot snap = HomeSnapshotController.getHomeSnapshot(year, quarter);
        Test.stopTest();

        System.assertEquals(directProspects, snap.tiles.prospectsGenerated, 'prospectsGenerated should match direct Lead__c count for the quarter');
        System.assertEquals(directLost, snap.tiles.prospectsLost, 'prospectsLost should match direct Unqualified count for the quarter');
        // Within a cent, not exactly equal: the controller sums several already-rounded
        // per-Status__c SUM() subtotals, while this direct comparison is one single SUM() over
        // the same rows - the two can differ by a cent of compounding rounding even though both
        // are counting the exact same underlying records.
        System.assert(
            Math.abs(directWon - snap.tiles.opportunityRevenueWon) < 0.02,
            'opportunityRevenueWon should match direct SUM(Total_PF_ASP__c) for Closed Won (within rounding): expected ' + directWon + ', got ' + snap.tiles.opportunityRevenueWon
        );
        System.assert(
            Math.abs(directNotWon - snap.tiles.opportunityPipeline) < 0.02,
            'opportunityPipeline should match direct SUM(Total_PF_ASP__c) for everything not Closed Won (within rounding): expected ' + directNotWon + ', got ' + snap.tiles.opportunityPipeline
        );
        System.assertEquals(directSamples, snap.tiles.samplesRequested, 'samplesRequested should match direct Approved Sample_Request_Header__c count for the quarter');
    }

    @isTest
    static void testGetHomeSnapshotDoesNotLeakOtherYears() {
        Integer thisYear = Date.today().year();
        Integer otherYear = thisYear - 1;
        String quarter = currentQuarter();

        // Lead_Created_Quarter_No__c (IST-correct), not CALENDAR_MONTH (GMT-based) - matches
        // buildDateCondition()'s own Quarter handling for Lead__c. A handful of leads sitting right
        // on a quarter boundary land in different quarters under GMT vs IST, which is exactly what
        // caused this test to fail in production (CALENDAR_MONTH-based: Expected 2920, Actual 2924).
        Integer directOtherYearOnly = [
            SELECT COUNT() FROM Lead__c
            WHERE CALENDAR_YEAR(CreatedDate) = :otherYear AND Lead_Created_Quarter_No__c = :quarter
        ];

        Test.startTest();
        HomeSnapshotController.HomeSnapshot snap = HomeSnapshotController.getHomeSnapshot(otherYear, quarter);
        Test.stopTest();

        System.assertEquals(
            directOtherYearOnly,
            snap.tiles.prospectsGenerated,
            'an explicit year should match only that specific year, not every year that quarter has ever occurred in'
        );
    }

    @isTest
    static void testGetHomeSnapshotPipelineChartExcludesClosedWonAndLost() {
        Integer year = Date.today().year();
        String quarter = currentQuarter();

        Test.startTest();
        HomeSnapshotController.HomeSnapshot snap = HomeSnapshotController.getHomeSnapshot(year, quarter);
        Test.stopTest();

        for (String label : snap.pipelineByStage.labels) {
            System.assert(
                label != 'Closed Won' && label != 'Closed Lost' && label != null,
                'Pipeline by Stage should only show active, non-null stages, got: ' + label
            );
        }
    }

    @isTest
    static void testGetHomeSnapshotDashboardAccessTrueForAdminWithRealDashboardIds() {
        Test.startTest();
        HomeSnapshotController.HomeSnapshot snap = HomeSnapshotController.getHomeSnapshot(null, null);
        Test.stopTest();

        HomeSnapshotController.DashboardTileAccess access = snap.dashboardAccess;
        System.assertEquals(true, access.sampleRequestDashboard, 'admin should see every dashboard tile');
        System.assertEquals(true, access.campaignMetrics, 'admin should see every dashboard tile');
        System.assertEquals(true, access.opportunityOverview, 'admin should see every dashboard tile');
        System.assertEquals(true, access.opportunityHistoryTracking, 'admin should see every dashboard tile');
        System.assertEquals(true, access.proactivePipeline, 'admin should see every dashboard tile');

        Integer realDashboardCount = [
            SELECT COUNT() FROM Dashboard
            WHERE Title IN ('Sample Request Dashboard', 'Campaign Metrics & Target Tracking', 'Opportunity Overview', 'Opportunity History Tracking')
        ];
        if (realDashboardCount == 4) {
            System.assertNotEquals(null, access.sampleRequestDashboardId, 'a real Dashboard exists with this title, so its Id should resolve');
            System.assertNotEquals(null, access.campaignMetricsId, 'a real Dashboard exists with this title, so its Id should resolve');
            System.assertNotEquals(null, access.opportunityOverviewId, 'a real Dashboard exists with this title, so its Id should resolve');
            System.assertNotEquals(null, access.opportunityHistoryTrackingId, 'a real Dashboard exists with this title, so its Id should resolve');
        }
    }

    @isTest
    static void testGetHomeSnapshotRestrictsNonAdmin() {
        List<User> candidates = [
            SELECT Id, Profile.Name FROM User
            WHERE IsActive = true AND UserRoleId != null AND Profile.Name != 'System Administrator'
            AND Id IN (SELECT OwnerId FROM Lead__c)
            LIMIT 1
        ];
        if (candidates.isEmpty()) {
            return;
        }
        User nonAdmin = candidates[0];
        Integer orgWideProspects = [SELECT COUNT() FROM Lead__c];

        // Dashboard_Tile_Access__mdt is real deployed configuration (one row per profile), not
        // test data - whatever it says for this non-admin's profile is the correct expectation,
        // rather than assuming "no records exist yet" is always true. As of 2026-10 this org's
        // Dashboard_Tile_Access__mdt is in fact still empty, in which case getDashboardTileAccess()
        // leaves access.sampleRequestDashboard as an uninitialized Boolean - null, NOT false - so
        // comparing against a hardcoded `false` would itself fail (null != false in Apex). Coercing
        // both sides with `== true` treats null and false as the same "not visible" outcome,
        // correct either way: empty metadata (null) or a real row explicitly set to false.
        List<Dashboard_Tile_Access__mdt> configRows = [
            SELECT Sample_Request_Dashboard_Visible__c FROM Dashboard_Tile_Access__mdt
            WHERE MasterLabel = :nonAdmin.Profile.Name
            LIMIT 1
        ];
        Boolean expectedSampleRequestVisible = !configRows.isEmpty() && configRows[0].Sample_Request_Dashboard_Visible__c == true;

        Integer restrictedProspects;
        HomeSnapshotController.DashboardTileAccess restrictedAccess;
        System.runAs(nonAdmin) {
            HomeSnapshotController.HomeSnapshot snap = HomeSnapshotController.getHomeSnapshot(null, null);
            restrictedProspects = snap.tiles.prospectsGenerated;
            restrictedAccess = snap.dashboardAccess;
        }

        System.assert(restrictedProspects <= orgWideProspects, 'a non-admin\'s prospectsGenerated should never exceed the org-wide total');
        System.assertEquals(
            expectedSampleRequestVisible,
            restrictedAccess.sampleRequestDashboard == true,
            'sampleRequestDashboard visibility should match this profile\'s configured Dashboard_Tile_Access__mdt row'
        );
    }
}
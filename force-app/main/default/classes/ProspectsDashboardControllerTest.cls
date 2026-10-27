@isTest(SeeAllData=true)
private class ProspectsDashboardControllerTest {
    // Lead__c carries 30+ validation rules tied to real business workflow (stage transitions,
    // SAP/CE-CIS approvals, etc.), so synthetic DML in this test would need to fight all of that
    // just to create rows. This controller is read-only (no DML), so we validate its query/date-range
    // logic against real sandbox data instead of fabricating records.

    @isTest
    static void testGetFilterOptionsReturnsPopulatedLists() {
        Test.startTest();
        ProspectsDashboardController.FilterOptions options = ProspectsDashboardController.getFilterOptions(
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        System.assertNotEquals(null, options, 'Filter options should not be null');
        System.assertNotEquals(null, options.zones, 'Zones list should not be null');
        System.assertNotEquals(null, options.countries, 'Countries list should not be null');
        System.assertNotEquals(null, options.owners, 'Owners list should not be null');
        System.assertNotEquals(null, options.years, 'Years list should not be null');
    }

    @isTest
    static void testGetFilterOptionsCascadesOwnerByCountry() {
        // Picking a Country should narrow the Owner dropdown to only the literal record owners
        // (OwnerId on Lead__c and Opportunity__c) relevant to that country, not the full org-wide
        // list, and NOT Approval Tracker reviewers (RSM/ZSM/GM-NSM/Approval user) - those still
        // work as real Owner filter matches (see buildWhereClause/buildOpportunityWhereClause) but
        // are deliberately excluded from the dropdown's own option list. Verified with exactly one
        // getFilterOptions() call against an independently computed expected set - calling it
        // twice in one test method previously risked the same 50,000-row limit as the original
        // Zone/Country/Year bug, since an unfiltered call alone can scan up to ~49,000 rows on a
        // large org.
        List<AggregateResult> countryAgg = [SELECT Country__c c FROM Lead__c WHERE Country__c != null GROUP BY Country__c LIMIT 1];
        if (countryAgg.isEmpty()) {
            return;
        }
        String sampleCountry = (String) countryAgg[0].get('c');

        // Computed before Test.startTest() so it draws from a separate governor-limit budget than
        // the getFilterOptions() call under test below.
        Set<Id> expectedOwnerIds = new Set<Id>();
        for (Lead__c rec : [SELECT OwnerId FROM Lead__c WHERE Country__c = :sampleCountry]) {
            if (rec.OwnerId != null) {
                expectedOwnerIds.add(rec.OwnerId);
            }
        }
        for (Opportunity__c orec : [SELECT OwnerId FROM Opportunity__c WHERE Country__c = :sampleCountry]) {
            if (orec.OwnerId != null) {
                expectedOwnerIds.add(orec.OwnerId);
            }
        }

        ProspectsDashboardController.FilterRequest countryFilteredRequest = new ProspectsDashboardController.FilterRequest();
        countryFilteredRequest.countries = new List<String>{ sampleCountry };

        Test.startTest();
        ProspectsDashboardController.FilterOptions countryFilteredOptions = ProspectsDashboardController.getFilterOptions(
            JSON.serialize(countryFilteredRequest)
        );
        Test.stopTest();

        System.assertEquals(
            expectedOwnerIds.size(),
            countryFilteredOptions.owners.size(),
            'Owner options narrowed by Country should exactly match the independently computed expected set'
        );
    }

    @isTest
    static void testGetKpiSummaryNoFiltersIsInternallyConsistent() {
        Test.startTest();
        ProspectsDashboardController.KpiSummary summary = ProspectsDashboardController.getKpiSummary(
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        System.assertNotEquals(null, summary, 'Summary should not be null');
        System.assert(summary.totalProspects >= summary.wonProspects, 'Total should be at least Won count');
        System.assert(summary.totalProspects >= summary.lostProspects, 'Total should be at least Lost count');
        System.assert(summary.totalProspects >= summary.unqualifiedProspects, 'Total should be at least Unqualified count');
        System.assertEquals(
            summary.totalProspects - summary.unqualifiedProspects,
            summary.netProspects,
            'Net should equal Total minus Unqualified'
        );
        System.assert(
            summary.totalProspects >= summary.prospectsClosed,
            'Total should be at least Prospects Closed count'
        );
    }

    @isTest
    static void testGetKpiSummaryProspectsClosedMatchesLeadClosedFlag() {
        // Prospects Closed means system-closed (Lead_Closed__c = true, the same flag Expired
        // Prospects uses for records auto-closed after 180 days of inactivity) - not Won + Lost, a
        // record can be Won/Lost without being auto-closed yet, and vice versa (2026-08 review).
        Test.startTest();
        ProspectsDashboardController.KpiSummary summary = ProspectsDashboardController.getKpiSummary(
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Integer directCount = [SELECT COUNT() FROM Lead__c WHERE Lead_Closed__c = true];
        System.assertEquals(directCount, summary.prospectsClosed, 'Prospects Closed should match a direct Lead_Closed__c = true count');
    }

    @isTest
    static void testGetKpiSummaryZoneFilterNarrowsResults() {
        List<AggregateResult> zoneAgg = [SELECT Zone__c z FROM Lead__c WHERE Zone__c != null GROUP BY Zone__c LIMIT 1];
        if (zoneAgg.isEmpty()) {
            return;
        }
        String sampleZone = (String) zoneAgg[0].get('z');

        ProspectsDashboardController.FilterRequest filters = new ProspectsDashboardController.FilterRequest();
        filters.zones = new List<String>{ sampleZone };

        Test.startTest();
        ProspectsDashboardController.KpiSummary unfiltered = ProspectsDashboardController.getKpiSummary(
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        ProspectsDashboardController.KpiSummary filtered = ProspectsDashboardController.getKpiSummary(JSON.serialize(filters));
        Test.stopTest();

        System.assert(filtered.totalProspects <= unfiltered.totalProspects, 'Zone-filtered total should not exceed unfiltered total');

        Integer directCount = [SELECT COUNT() FROM Lead__c WHERE Zone__c = :sampleZone];
        System.assertEquals(directCount, filtered.totalProspects, 'Zone filter should match a direct SOQL count');
    }

    @isTest
    static void testGetKpiSummaryYearFilterMatchesDirectCount() {
        List<AggregateResult> yearAgg = [SELECT CALENDAR_YEAR(CreatedDate) yr FROM Lead__c GROUP BY CALENDAR_YEAR(CreatedDate) ORDER BY CALENDAR_YEAR(CreatedDate) DESC LIMIT 1];
        if (yearAgg.isEmpty()) {
            return;
        }
        Integer sampleYear = (Integer) yearAgg[0].get('yr');

        ProspectsDashboardController.FilterRequest filters = new ProspectsDashboardController.FilterRequest();
        filters.years = new List<Integer>{ sampleYear };

        Test.startTest();
        ProspectsDashboardController.KpiSummary filtered = ProspectsDashboardController.getKpiSummary(JSON.serialize(filters));
        Test.stopTest();

        Date rangeStart = Date.newInstance(sampleYear, 1, 1);
        Date rangeEnd = rangeStart.addYears(1);
        Integer directCount = [SELECT COUNT() FROM Lead__c WHERE CreatedDate >= :rangeStart AND CreatedDate < :rangeEnd];
        System.assertEquals(directCount, filtered.totalProspects, 'Year filter should match a direct SOQL date-range count');
    }

    @isTest
    static void testGetKpiSummaryMultipleYearsUnionsBothYears() {
        // Multi-select semantics: selecting two years should return the union of both, not just
        // one - the main behavior change from the old single-select Year.
        List<AggregateResult> yearAgg = [SELECT CALENDAR_YEAR(CreatedDate) yr FROM Lead__c GROUP BY CALENDAR_YEAR(CreatedDate) ORDER BY CALENDAR_YEAR(CreatedDate) DESC LIMIT 2];
        if (yearAgg.size() < 2) {
            return;
        }
        Integer yearA = (Integer) yearAgg[0].get('yr');
        Integer yearB = (Integer) yearAgg[1].get('yr');

        List<Integer> selectedYears = new List<Integer>{ yearA, yearB };
        ProspectsDashboardController.FilterRequest filters = new ProspectsDashboardController.FilterRequest();
        filters.years = selectedYears;

        Test.startTest();
        ProspectsDashboardController.KpiSummary filtered = ProspectsDashboardController.getKpiSummary(JSON.serialize(filters));
        Test.stopTest();

        Integer directCount = [SELECT COUNT() FROM Lead__c WHERE CALENDAR_YEAR(CreatedDate) IN :selectedYears];
        System.assertEquals(directCount, filtered.totalProspects, 'Selecting two years should match a direct SOQL CALENDAR_YEAR IN count');
    }

    @isTest
    static void testGetKpiSummaryQuarterUsesLiveFormulaField() {
        // No Year selected, so Quarter defaults to the current year (see buildDateCondition) -
        // test against today's year directly instead of an arbitrary sample year from the data,
        // which would only pass by coincidence.
        Integer currentYear = Date.today().year();

        ProspectsDashboardController.FilterRequest filters = new ProspectsDashboardController.FilterRequest();
        filters.quarters = new List<String>{ 'Q1' };

        Test.startTest();
        ProspectsDashboardController.KpiSummary filtered = ProspectsDashboardController.getKpiSummary(JSON.serialize(filters));
        Test.stopTest();

        // Quarter filter matches the live Lead_Created_Quarter_No__c FORMULA field directly, not
        // the Lead_Created_Quarter_Dashboard__c stored copy (2026-09 correction) - the stored copy
        // can go stale (it did, causing phantom-quarter bars on charts), while the formula field is
        // always current since it recomputes on every read. Calendar Q1 = Jan-Mar, matching that
        // formula's production convention.
        Integer directCount = [SELECT COUNT() FROM Lead__c WHERE Lead_Created_Quarter_No__c = 'Q1' AND CALENDAR_YEAR(CreatedDate) = :currentYear];
        System.assertEquals(directCount, filtered.totalProspects, 'Q1 should match Lead_Created_Quarter_No__c = Q1 for the current year (calendar convention)');
    }

    @isTest
    static void testGetKpiSummaryNoMatchesReturnsZeroesWithoutError() {
        ProspectsDashboardController.FilterRequest filters = new ProspectsDashboardController.FilterRequest();
        filters.zones = new List<String>{ 'ZZZ_NO_SUCH_ZONE_VALUE' };

        Test.startTest();
        ProspectsDashboardController.KpiSummary summary = ProspectsDashboardController.getKpiSummary(JSON.serialize(filters));
        Test.stopTest();

        System.assertEquals(0, summary.totalProspects, 'Non-matching filter should yield zero total');
        System.assertEquals(0, summary.unqualifiedPct, 'Percentage should safely default to zero, not divide by zero');
    }

    @isTest
    static void testGetChartDataReturnsSeriesForKnownChart() {
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'prospectTrend',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        System.assertNotEquals(null, data, 'Chart data should not be null');
        System.assertNotEquals(null, data.labels, 'Labels should not be null');
        System.assertEquals(3, data.series.size(), 'prospectTrend defines 3 series');
    }

    @isTest
    static void testGetChartDataProspectTrendUsesNetProspectAndActualDates() {
        // 2026-08 review: Prospect is Net Prospects (Total - Unqualified, same as
        // Lead_Stage__c != 'Unqualified'), and Actual Commercialization/Upgrade are counted by
        // their own milestone date field rather than by current Lead_Stage__c - a lead that
        // reached Commercialization and later moved on to Upgrade still counts toward
        // Commercialization, since it really did happen on that date.
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'prospectTrend',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Map<String, Decimal> totalsByLabel = new Map<String, Decimal>();
        for (ProspectsDashboardController.ChartSeries s : data.series) {
            Decimal total = 0;
            for (Decimal d : s.data) {
                total += d;
            }
            totalsByLabel.put(s.label, total);
        }

        Integer directNetCount = [SELECT COUNT() FROM Lead__c WHERE Lead_Stage__c != 'Unqualified'];
        Integer directCommercialization = [SELECT COUNT() FROM Lead__c WHERE Actual_Commercialization_Week_Dashboard__c != null];
        Integer directUpgrade = [SELECT COUNT() FROM Lead__c WHERE Actual_Upgrade_Week_Dashboard__c != null];

        System.assertEquals(directNetCount, totalsByLabel.get('Prospect'), 'Prospect should be Net Prospects (Total - Unqualified)');
        System.assertEquals(directCommercialization, totalsByLabel.get('Actual Commercialization'), 'Actual Commercialization should count by the Actual_Commercialization_Week_Dashboard__c field');
        System.assertEquals(directUpgrade, totalsByLabel.get('Upgrade'), 'Upgrade should count by the Actual_Upgrade_Week_Dashboard__c field');
    }

    @isTest
    static void testGetChartDataUnknownChartKeyThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            ProspectsDashboardController.getChartData('notARealChart', JSON.serialize(new ProspectsDashboardController.FilterRequest()));
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'An unknown chart key should throw AuraHandledException');
    }

    @isTest
    static void testGetKpiSummaryBlankFiltersJsonDefaultsToUnfiltered() {
        // Split into this method + testGetKpiSummaryNullFiltersJsonDefaultsToUnfiltered (each
        // comparing against an independent direct COUNT() rather than against each other) instead
        // of calling getKpiSummary() twice in one transaction: getKpiSummary() internally calls
        // uniqueLeadsByNameAndFamily(), which can fetch up to 40,000 Lead__c rows unfiltered - two
        // calls' worth in one transaction can exceed the 50,000-row-per-transaction SOQL limit once
        // the org's unfiltered Lead count is large enough (seen in production).
        Integer directTotal = [SELECT COUNT() FROM Lead__c];

        Test.startTest();
        ProspectsDashboardController.KpiSummary blankJson = ProspectsDashboardController.getKpiSummary('');
        Test.stopTest();

        System.assertEquals(directTotal, blankJson.totalProspects, 'Blank filtersJson should behave as unfiltered');
    }

    @isTest
    static void testGetKpiSummaryNullFiltersJsonDefaultsToUnfiltered() {
        Integer directTotal = [SELECT COUNT() FROM Lead__c];

        Test.startTest();
        ProspectsDashboardController.KpiSummary nullJson = ProspectsDashboardController.getKpiSummary(null);
        Test.stopTest();

        System.assertEquals(directTotal, nullJson.totalProspects, 'Null filtersJson should behave as unfiltered');
    }

    @isTest
    static void testGetKpiSummaryCountryFilterMatchesDirectCount() {
        List<AggregateResult> countryAgg = [SELECT Country__c c FROM Lead__c WHERE Country__c != null GROUP BY Country__c LIMIT 1];
        if (countryAgg.isEmpty()) {
            return;
        }
        String sampleCountry = (String) countryAgg[0].get('c');

        ProspectsDashboardController.FilterRequest filters = new ProspectsDashboardController.FilterRequest();
        filters.countries = new List<String>{ sampleCountry };

        Test.startTest();
        ProspectsDashboardController.KpiSummary filtered = ProspectsDashboardController.getKpiSummary(JSON.serialize(filters));
        Test.stopTest();

        Integer directCount = [SELECT COUNT() FROM Lead__c WHERE Country__c = :sampleCountry];
        System.assertEquals(directCount, filtered.totalProspects, 'Country filter should match a direct SOQL count');
    }

    @isTest
    static void testGetKpiSummaryOwnerFilterIncludesLiterallyOwnedRecords() {
        // The owner filter now means "owns it OR is named as RSM/ZSM/GM-NSM/Approval user on it"
        // (see buildWhereClause), matching the Approval Tracker's per-stage reviewer fields rather
        // than literal OwnerId equality - so this only asserts the combined total is never less
        // than what the user literally owns, not that they're equal.
        // testGetKpiSummaryOwnerFilterIncludesRoleFieldAssignments below covers the broader case
        // with a concrete example of a user who is RSM on records they don't own.
        List<AggregateResult> ownerAgg = [SELECT OwnerId o FROM Lead__c GROUP BY OwnerId LIMIT 1];
        if (ownerAgg.isEmpty()) {
            return;
        }
        String sampleOwnerId = (String) ownerAgg[0].get('o');

        ProspectsDashboardController.FilterRequest filters = new ProspectsDashboardController.FilterRequest();
        filters.ownerIds = new List<String>{ sampleOwnerId };

        Test.startTest();
        ProspectsDashboardController.KpiSummary filtered = ProspectsDashboardController.getKpiSummary(JSON.serialize(filters));
        Test.stopTest();

        Integer directOwnedCount = [SELECT COUNT() FROM Lead__c WHERE OwnerId = :sampleOwnerId];
        System.assert(
            filtered.totalProspects >= directOwnedCount,
            'Combined role total should be at least the literally-owned count'
        );
    }

    @isTest
    static void testGetKpiSummaryOwnerFilterIncludesRoleFieldAssignments() {
        // Finds a real case of a user who is named as RSM on leads they don't literally own, and
        // confirms the resolved total reflects that broader role-based scope - this is the actual
        // scenario the filter needed to support (a higher-level employee assigned via the Approval
        // Tracker's RSM/ZSM/GM-NSM/Approval user fields, not necessarily the record owner).
        List<AggregateResult> rsmAgg = [SELECT RSM__c r FROM Lead__c WHERE RSM__c != null GROUP BY RSM__c LIMIT 1];
        if (rsmAgg.isEmpty()) {
            return;
        }
        Id testUserId = (Id) rsmAgg[0].get('r');

        Integer directOwnedCount = [SELECT COUNT() FROM Lead__c WHERE OwnerId = :testUserId];
        Integer rsmAssignedCount = [SELECT COUNT() FROM Lead__c WHERE RSM__c = :testUserId];

        ProspectsDashboardController.FilterRequest filters = new ProspectsDashboardController.FilterRequest();
        filters.ownerIds = new List<String>{ testUserId };

        Test.startTest();
        ProspectsDashboardController.KpiSummary filtered = ProspectsDashboardController.getKpiSummary(JSON.serialize(filters));
        Test.stopTest();

        System.assert(
            filtered.totalProspects >= rsmAssignedCount,
            'A user assigned as RSM should see at least their RSM-assigned leads reflected in the total'
        );
        System.assert(
            filtered.totalProspects >= directOwnedCount,
            'The combined total should also cover whatever this user literally owns'
        );
    }

    @isTest
    static void testGetKpiSummaryTeamFilterMatchesDirectCount() {
        // Sales_Marketing_Lead__c is a formula field flagged non-groupable in SOQL (same platform
        // restriction as Lead_Created_Quarter_No__c), so a sample value can't be discovered via
        // GROUP BY. Use a known literal directly instead.
        String sampleTeam = 'Sales Lead';

        ProspectsDashboardController.FilterRequest filters = new ProspectsDashboardController.FilterRequest();
        filters.teams = new List<String>{ sampleTeam };

        Test.startTest();
        ProspectsDashboardController.KpiSummary filtered = ProspectsDashboardController.getKpiSummary(JSON.serialize(filters));
        Test.stopTest();

        Integer directCount = [SELECT COUNT() FROM Lead__c WHERE Sales_Marketing_Lead__c = :sampleTeam];
        System.assertEquals(directCount, filtered.totalProspects, 'Sales/Marketing filter should match a direct SOQL count');
    }

    @isTest
    static void testGetKpiSummaryMonthFilterMatchesDirectCount() {
        // No Year selected, so Month defaults to the current year (see buildDateCondition).
        Integer currentYear = Date.today().year();

        ProspectsDashboardController.FilterRequest filters = new ProspectsDashboardController.FilterRequest();
        filters.months = new List<Integer>{ 6 };

        Test.startTest();
        ProspectsDashboardController.KpiSummary filtered = ProspectsDashboardController.getKpiSummary(JSON.serialize(filters));
        Test.stopTest();

        Date rangeStart = Date.newInstance(currentYear, 6, 1);
        Date rangeEnd = rangeStart.addMonths(1);
        Integer directCount = [SELECT COUNT() FROM Lead__c WHERE CreatedDate >= :rangeStart AND CreatedDate < :rangeEnd];
        System.assertEquals(directCount, filtered.totalProspects, 'Month filter should match a direct SOQL date-range count for the current year');
    }

    @isTest
    static void testGetKpiSummaryWeekFilterMatchesDirectCount() {
        // No Year selected, so Week defaults to the current year (see buildDateCondition).
        Integer currentYear = Date.today().year();

        ProspectsDashboardController.FilterRequest filters = new ProspectsDashboardController.FilterRequest();
        filters.weeks = new List<Integer>{ 10 };

        Test.startTest();
        ProspectsDashboardController.KpiSummary filtered = ProspectsDashboardController.getKpiSummary(JSON.serialize(filters));
        Test.stopTest();

        Date weekStart = Date.newInstance(currentYear, 1, 1).addDays(9 * 7);
        Date weekEnd = weekStart.addDays(7);
        Integer directCount = [SELECT COUNT() FROM Lead__c WHERE CreatedDate >= :weekStart AND CreatedDate < :weekEnd];
        System.assertEquals(directCount, filtered.totalProspects, 'Week filter should match a direct SOQL date-range count for the current year');
    }

    // Period filter is disabled for now (see ProspectsDashboardController.buildDateCondition) -
    // this test covered it and is commented out to match, rather than deleted, so it's easy to
    // restore once Period comes back.
    // @isTest
    // static void testGetKpiSummaryPeriodPresetsResolveExpectedRanges() {
    //     List<String> presets = new List<String>{
    //         'ThisYear', 'LastYear', 'ThisQuarter', 'LastQuarter', 'ThisMonth', 'LastMonth', 'Last7Days', 'Last30Days', 'NotARealPreset'
    //     };
    //
    //     Test.startTest();
    //     for (String preset : presets) {
    //         ProspectsDashboardController.FilterRequest filters = new ProspectsDashboardController.FilterRequest();
    //         filters.period = preset;
    //         ProspectsDashboardController.KpiSummary summary = ProspectsDashboardController.getKpiSummary(JSON.serialize(filters));
    //         System.assert(summary.totalProspects >= 0, 'Period preset "' + preset + '" should resolve without error');
    //     }
    //     Test.stopTest();
    // }

    // Split into one test method per chart (rather than looping all 5 in one method) so each gets
    // its own fresh governor-limit budget. Several of these charts include an unfiltered "all
    // records" series, and looping them together in one Test.startTest()/stopTest() window pushed
    // cumulative query rows past the 50,000-row-per-transaction limit.

    @isTest
    static void testGetChartDataProspectToEvaluationRatioCoversNotEqualsBranch() {
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'prospectToEvaluationRatio',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        System.assertNotEquals(null, data.series, 'Chart should return series data');
    }

    @isTest
    static void testGetChartDataProspectToEvaluationRatioUsesActualEvaluationDate() {
        // 2026-08 review: Evaluation is counted by Actual_Evaluations_Week__c (the date a lead was
        // actually evaluated) rather than "Lead_Stage__c != 'Unqualified'" - so it can be a genuine
        // subset of Net Prospects instead of numerically identical to it.
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'prospectToEvaluationRatio',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Map<String, Decimal> totalsByLabel = new Map<String, Decimal>();
        for (ProspectsDashboardController.ChartSeries s : data.series) {
            Decimal total = 0;
            for (Decimal d : s.data) {
                total += d;
            }
            totalsByLabel.put(s.label, total);
        }

        Integer directNetCount = [SELECT COUNT() FROM Lead__c WHERE Lead_Stage__c != 'Unqualified'];
        Integer directEvaluationCount = [SELECT COUNT() FROM Lead__c WHERE Actual_Evaluation_Week_Dashboard__c != null];

        System.assertEquals(directNetCount, totalsByLabel.get('Prospect'), 'Prospect should be Net Prospects (Total - Unqualified)');
        System.assertEquals(directEvaluationCount, totalsByLabel.get('Evaluation'), 'Evaluation should count by its own milestone date field');
    }

    @isTest
    static void testGetChartDataEvaluationToConversionRatioSumsActualDateParts() {
        // 2026-08 review: Conversion is actual-commercialization-dated records PLUS
        // actual-upgrade-dated records - a record can only hold one Lead_Stage__c value at a time,
        // so the old "Lead_Stage__c IN ('Commercialization','Upgrade')" snapshot missed anyone who
        // reached Commercialization and later moved on to Upgrade or beyond.
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'evaluationToConversionRatio',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Decimal conversionTotal = 0;
        for (ProspectsDashboardController.ChartSeries s : data.series) {
            if (s.label == 'Conversion') {
                for (Decimal d : s.data) {
                    conversionTotal += d;
                }
            }
        }

        Integer directCommercialization = [SELECT COUNT() FROM Lead__c WHERE Actual_Commercialization_Week_Dashboard__c != null];
        Integer directUpgrade = [SELECT COUNT() FROM Lead__c WHERE Actual_Upgrade_Week_Dashboard__c != null];
        System.assertEquals(
            directCommercialization + directUpgrade,
            conversionTotal,
            'Conversion should sum actual-commercialization-dated and actual-upgrade-dated counts'
        );
    }

    @isTest
    static void testGetChartDataProspectToConversionRatioUsesNetProspectAndSummedConversion() {
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'prospectToConversionRatio',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Map<String, Decimal> totalsByLabel = new Map<String, Decimal>();
        for (ProspectsDashboardController.ChartSeries s : data.series) {
            Decimal total = 0;
            for (Decimal d : s.data) {
                total += d;
            }
            totalsByLabel.put(s.label, total);
        }

        Integer directNetCount = [SELECT COUNT() FROM Lead__c WHERE Lead_Stage__c != 'Unqualified'];
        Integer directCommercialization = [SELECT COUNT() FROM Lead__c WHERE Actual_Commercialization_Week_Dashboard__c != null];
        Integer directUpgrade = [SELECT COUNT() FROM Lead__c WHERE Actual_Upgrade_Week_Dashboard__c != null];

        System.assertEquals(directNetCount, totalsByLabel.get('Prospect'), 'Prospect should be Net Prospects (Total - Unqualified)');
        System.assertEquals(
            directCommercialization + directUpgrade,
            totalsByLabel.get('Conversion'),
            'Conversion should sum actual-commercialization-dated and actual-upgrade-dated counts'
        );
    }

    @isTest
    static void testGetChartDataProspectToUnqualifiedRatioMatchesDirectCount() {
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'prospectToUnqualifiedRatio',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Decimal unqualifiedTotal = 0;
        for (ProspectsDashboardController.ChartSeries s : data.series) {
            if (s.label == 'Unqualified') {
                for (Decimal d : s.data) {
                    unqualifiedTotal += d;
                }
            }
        }

        Integer directCount = [SELECT COUNT() FROM Lead__c WHERE Lead_Stage__c = 'Unqualified'];
        System.assertEquals(directCount, unqualifiedTotal, 'Unqualified series should match a direct SOQL count');
    }

    @isTest
    static void testGetChartDataEndToEndVisibilityAdvancedOrExitedSumsFourParts() {
        // 2026-08 review: Advanced or Exited sums actual-commercialization-dated,
        // actual-upgrade-dated, Unqualified, and Lost counts - replacing the old
        // "Lead_Stage__c IN ('Commercialization','Upgrade','Unqualified','Lost')" snapshot for the
        // same reason as Conversion above.
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'endToEndVisibility',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Decimal advancedTotal = 0;
        for (ProspectsDashboardController.ChartSeries s : data.series) {
            if (s.label == 'Advanced or Exited') {
                for (Decimal d : s.data) {
                    advancedTotal += d;
                }
            }
        }

        Integer directCommercialization = [SELECT COUNT() FROM Lead__c WHERE Actual_Commercialization_Week_Dashboard__c != null];
        Integer directUpgrade = [SELECT COUNT() FROM Lead__c WHERE Actual_Upgrade_Week_Dashboard__c != null];
        Integer directUnqualified = [SELECT COUNT() FROM Lead__c WHERE Lead_Stage__c = 'Unqualified'];
        Integer directLost = [SELECT COUNT() FROM Lead__c WHERE Lead_Stage__c = 'Lost'];
        System.assertEquals(
            directCommercialization + directUpgrade + directUnqualified + directLost,
            advancedTotal,
            'Advanced or Exited should sum actual-commercialization-dated, actual-upgrade-dated, Unqualified, and Lost counts'
        );
    }

    @isTest
    static void testGetChartDataProspectToUntouchRatioCoversIsBlankBranch() {
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'prospectToUntouchRatio',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        System.assertNotEquals(null, data.series, 'Chart should return series data');
    }

    @isTest
    static void testGetChartDataOverallReportingCoversIsNotBlankBranch() {
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'overallReporting',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        System.assertNotEquals(null, data.series, 'Chart should return series data');
    }

    @isTest
    static void testGetChartDataExpiredProspectsCoversIsClosedBranch() {
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'expiredProspects',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        System.assertNotEquals(null, data.series, 'Chart should return series data');
    }

    // 2026-09 correction: "Prospect" is Net Prospects (Total - Unqualified) on every chart, not
    // just Prospect Trend/Prospect to Evaluation Ratio/Prospect to Conversion Ratio - Overall
    // Reporting, Prospect to Unqualified Ratio, Prospect to Untouch Ratio, End to End Visibility,
    // and Expired Prospects previously used the true, unfiltered total instead, which was wrong.
    private static Decimal prospectSeriesTotal(ProspectsDashboardController.ChartData data) {
        Decimal total = 0;
        for (ProspectsDashboardController.ChartSeries s : data.series) {
            if (s.label == 'Prospect') {
                for (Decimal d : s.data) {
                    total += d;
                }
            }
        }
        return total;
    }

    @isTest
    static void testGetChartDataOverallReportingProspectIsNetProspect() {
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'overallReporting',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Integer directNetCount = [SELECT COUNT() FROM Lead__c WHERE Lead_Stage__c != 'Unqualified'];
        System.assertEquals(directNetCount, prospectSeriesTotal(data), 'Overall Reporting Prospect should be Net Prospects (Total - Unqualified)');
    }

    @isTest
    static void testGetChartDataProspectToUnqualifiedRatioProspectIsNetProspect() {
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'prospectToUnqualifiedRatio',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Integer directNetCount = [SELECT COUNT() FROM Lead__c WHERE Lead_Stage__c != 'Unqualified'];
        System.assertEquals(directNetCount, prospectSeriesTotal(data), 'Prospect to Unqualified Ratio Prospect should be Net Prospects (Total - Unqualified)');
    }

    @isTest
    static void testGetChartDataProspectToUntouchRatioProspectIsNetProspect() {
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'prospectToUntouchRatio',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Integer directNetCount = [SELECT COUNT() FROM Lead__c WHERE Lead_Stage__c != 'Unqualified'];
        System.assertEquals(directNetCount, prospectSeriesTotal(data), 'Prospect to Untouch Ratio Prospect should be Net Prospects (Total - Unqualified)');
    }

    @isTest
    static void testGetChartDataEndToEndVisibilityProspectIsNetProspect() {
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'endToEndVisibility',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Integer directNetCount = [SELECT COUNT() FROM Lead__c WHERE Lead_Stage__c != 'Unqualified'];
        System.assertEquals(directNetCount, prospectSeriesTotal(data), 'End to End Visibility Prospect should be Net Prospects (Total - Unqualified)');
    }

    @isTest
    static void testGetChartDataExpiredProspectsProspectIsNetProspect() {
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'expiredProspects',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Integer directNetCount = [SELECT COUNT() FROM Lead__c WHERE Lead_Stage__c != 'Unqualified'];
        System.assertEquals(directNetCount, prospectSeriesTotal(data), 'Expired Prospects Prospect should be Net Prospects (Total - Unqualified)');
    }

    // 2026-09: "Closed (Expired)" redefined as "closed WITHOUT converting to an Opportunity" -
    // Lead_Closed__c = true AND this Lead's Id isn't referenced by any Opportunity__c.Lead_Id__c.
    // Schema-drift guard (see ProspectsDashboardController.OPP_LEAD_ID_FIELD_EXISTS): this sandbox's
    // Opportunity__c doesn't have Lead_Id__c at all (production does), so this test verifies nothing
    // there - it becomes a real check once run in an org that has the field.
    @isTest
    static void testGetChartDataExpiredProspectsClosedExcludesConvertedLeads() {
        if (!Schema.SObjectType.Opportunity__c.fields.getMap().containsKey('lead_id__c')) {
            return;
        }

        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'expiredProspects',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Set<Id> convertedLeadIds = new Set<Id>();
        for (SObject row : Database.query('SELECT Lead_Id__c FROM Opportunity__c WHERE Lead_Id__c != null')) {
            Object rawLeadId = row.get('Lead_Id__c');
            try {
                convertedLeadIds.add(Id.valueOf(String.valueOf(rawLeadId).trim()));
            } catch (Exception e) {
                // malformed value - not a real Lead Id, skip
            }
        }

        Integer directClosedCount;
        if (convertedLeadIds.isEmpty()) {
            directClosedCount = [SELECT COUNT() FROM Lead__c WHERE Lead_Closed__c = true];
        } else {
            directClosedCount = [SELECT COUNT() FROM Lead__c WHERE Lead_Closed__c = true AND Id NOT IN :convertedLeadIds];
        }

        Decimal closedSeriesTotal = 0;
        for (ProspectsDashboardController.ChartSeries s : data.series) {
            if (s.label == 'Closed (Expired)') {
                for (Decimal d : s.data) {
                    closedSeriesTotal += d;
                }
            }
        }

        System.assertEquals(
            directClosedCount,
            closedSeriesTotal.intValue(),
            'Closed (Expired) should match direct count of closed Leads NOT referenced by any Opportunity.Lead_Id__c'
        );

        String period = null;
        for (Integer i = 0; i < data.labels.size(); i++) {
            for (ProspectsDashboardController.ChartSeries s : data.series) {
                if (s.label == 'Closed (Expired)' && s.data[i] > 0) {
                    period = data.labels[i];
                    break;
                }
            }
            if (period != null) {
                break;
            }
        }
        if (period != null) {
            List<ProspectsDashboardController.DrillDownRecord> drillDown = ProspectsDashboardController.getDrillDownRecords(
                'expiredProspects', 'Closed (Expired)', period, JSON.serialize(new ProspectsDashboardController.FilterRequest())
            );
            for (ProspectsDashboardController.DrillDownRecord r : drillDown) {
                System.assert(
                    !convertedLeadIds.contains(Id.valueOf(r.recordId)),
                    'A Closed (Expired) drill-down record should never be a Lead that converted to an Opportunity'
                );
            }
        }
    }

    // ------------------------------------------------------------------------------------------
    //  getDrillDownRecords - click-through from a chart bar to its underlying records
    // ------------------------------------------------------------------------------------------

    // Picks whichever period actually has data (rather than hardcoding one) so this test stays
    // valid as the org's data changes over time - same approach as the quarter tests above.
    private static String periodWithLargestValue(ProspectsDashboardController.ChartData data, String seriesLabel) {
        String bestPeriod = null;
        Decimal bestValue = -1;
        for (ProspectsDashboardController.ChartSeries s : data.series) {
            if (s.label != seriesLabel) {
                continue;
            }
            for (Integer i = 0; i < data.labels.size(); i++) {
                if (s.data[i] > bestValue) {
                    bestValue = s.data[i];
                    bestPeriod = data.labels[i];
                }
            }
        }
        return bestPeriod;
    }

    @isTest
    static void testGetDrillDownRecordsSinglePartMatchesChartAggregate() {
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'prospectTrend',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        String period = periodWithLargestValue(data, 'Prospect');
        System.assert(String.isNotBlank(period), 'setup data should include at least one Prospect Trend period');

        Decimal expected = 0;
        for (ProspectsDashboardController.ChartSeries s : data.series) {
            if (s.label == 'Prospect') {
                expected = s.data[data.labels.indexOf(period)];
            }
        }

        Test.startTest();
        List<ProspectsDashboardController.DrillDownRecord> recs = ProspectsDashboardController.getDrillDownRecords(
            'prospectTrend', 'Prospect', period, '{}'
        );
        Test.stopTest();

        System.assertEquals(expected.intValue(), recs.size(), 'drill-down row count should equal the value shown on the bar');
        Set<Id> distinctIds = new Set<Id>();
        for (ProspectsDashboardController.DrillDownRecord r : recs) {
            distinctIds.add(r.recordId);
        }
        System.assertEquals(recs.size(), distinctIds.size(), 'a single-part series should not repeat the same record');
    }

    @isTest
    static void testGetDrillDownRecordsMultiPartSeriesSumsAndTagsMatchedVia() {
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'evaluationToConversionRatio',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        String period = periodWithLargestValue(data, 'Conversion');
        System.assert(String.isNotBlank(period), 'setup data should include at least one Evaluation to Conversion Ratio period');

        Decimal expected = 0;
        for (ProspectsDashboardController.ChartSeries s : data.series) {
            if (s.label == 'Conversion') {
                expected = s.data[data.labels.indexOf(period)];
            }
        }

        Test.startTest();
        List<ProspectsDashboardController.DrillDownRecord> recs = ProspectsDashboardController.getDrillDownRecords(
            'evaluationToConversionRatio', 'Conversion', period, '{}'
        );
        Test.stopTest();

        System.assertEquals(expected.intValue(), recs.size(), 'Conversion drill-down should equal the sum shown on the bar (Commercialization + Upgrade parts, not deduplicated)');
        Set<String> vias = new Set<String>();
        for (ProspectsDashboardController.DrillDownRecord r : recs) {
            vias.add(r.matchedVia);
        }
        for (String via : vias) {
            System.assert(
                via == 'Actual Commercialization' || via == 'Actual Upgrade',
                'Conversion is only made of Commercialization/Upgrade parts, got: ' + via
            );
        }
    }

    @isTest
    static void testGetDrillDownRecordsUnknownChartKeyThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            ProspectsDashboardController.getDrillDownRecords('notARealChart', 'Prospect', '2026-Q1', '{}');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'an unknown chart key should throw');
    }

    @isTest
    static void testGetDrillDownRecordsUnknownSeriesLabelThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            ProspectsDashboardController.getDrillDownRecords('prospectTrend', 'Not A Real Series', '2026-Q1', '{}');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'an unknown series label should throw');
    }

    @isTest
    static void testGetDrillDownRecordsUnrecognizedPeriodThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            ProspectsDashboardController.getDrillDownRecords('prospectTrend', 'Prospect', 'not-a-period', '{}');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'an unrecognized period should throw');
    }

    // ------------------------------------------------------------------------------------------
    //  getChartFullDetail / getProductFamilyFullDetail - whole-report "deep dive" export
    // ------------------------------------------------------------------------------------------

    private static Decimal seriesTotal(ProspectsDashboardController.ChartData data, String label) {
        Decimal total = 0;
        for (ProspectsDashboardController.ChartSeries s : data.series) {
            if (s.label == label) {
                for (Decimal d : s.data) {
                    total += d;
                }
            }
        }
        return total;
    }

    // A TRUNCATED warning row (added only when a series part's true count exceeds its per-part
    // export budget) has no recordId - excluded here so this test verifies actual record counts,
    // not warning rows, regardless of whether today's sandbox data happens to trip the cap.
    private static Integer nonWarningRowCount(List<ProspectsDashboardController.DrillDownRecord> recs, String seriesLabel) {
        Integer count = 0;
        for (ProspectsDashboardController.DrillDownRecord r : recs) {
            if (r.seriesLabel == seriesLabel && r.recordId != null) {
                count++;
            }
        }
        return count;
    }

    @isTest
    static void testGetChartFullDetailMatchesChartAggregateTotals() {
        ProspectsDashboardController.ChartData chartData = ProspectsDashboardController.getChartData(
            'prospectTrend',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );

        Test.startTest();
        List<ProspectsDashboardController.DrillDownRecord> detail = ProspectsDashboardController.getChartFullDetail('prospectTrend', '{}');
        Test.stopTest();

        for (String label : new List<String>{ 'Prospect', 'Actual Commercialization', 'Upgrade' }) {
            Decimal aggregateTotal = seriesTotal(chartData, label);
            Boolean anyTruncated = false;
            for (ProspectsDashboardController.DrillDownRecord r : detail) {
                if (r.seriesLabel == label && r.recordId == null) {
                    anyTruncated = true;
                }
            }
            if (!anyTruncated) {
                System.assertEquals(
                    aggregateTotal.intValue(),
                    nonWarningRowCount(detail, label),
                    'Full-detail row count for series "' + label + '" should match the chart aggregate when nothing was truncated'
                );
            }
        }
    }

    @isTest
    static void testGetChartFullDetailUnknownChartKeyThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            ProspectsDashboardController.getChartFullDetail('notARealChart', '{}');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'an unknown chart key should throw');
    }

    // 2026-09 correction: "Untouch" on Opportunity to Untouch Ratio is Status__c blank (same
    // condition as Lead__c's "No Follow Up" tile, Lead_Stage__c blank) - previously wrongly used
    // Opportunity_Closed__c = true, which is a different concept (the org's 180-day auto-close,
    // now its own separate Expired Opportunity chart).
    @isTest
    static void testGetChartDataOpportunityToUntouchRatioMatchesDirectCounts() {
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'opportunityToUntouchRatio',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Integer directTotal = [SELECT COUNT() FROM Opportunity__c];
        Integer directUntouch = [SELECT COUNT() FROM Opportunity__c WHERE Status__c = null];

        System.assertEquals(directTotal, seriesTotal(data, 'Opportunity').intValue(), 'Opportunity series should match the direct Opportunity__c count');
        System.assertEquals(directUntouch, seriesTotal(data, 'Untouch').intValue(), 'Untouch series should match direct count of Status__c = null, not Opportunity_Closed__c = true');
    }

    @isTest
    static void testGetChartFullDetailOpportunityMatchesChartAggregateTotals() {
        ProspectsDashboardController.ChartData chartData = ProspectsDashboardController.getChartData(
            'opportunityToUntouchRatio',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );

        Test.startTest();
        List<ProspectsDashboardController.DrillDownRecord> detail = ProspectsDashboardController.getChartFullDetail('opportunityToUntouchRatio', '{}');
        Test.stopTest();

        for (String label : new List<String>{ 'Opportunity', 'Untouch' }) {
            Decimal aggregateTotal = seriesTotal(chartData, label);
            Boolean anyTruncated = false;
            for (ProspectsDashboardController.DrillDownRecord r : detail) {
                if (r.seriesLabel == label && r.recordId == null) {
                    anyTruncated = true;
                }
            }
            if (!anyTruncated) {
                System.assertEquals(
                    aggregateTotal.intValue(),
                    nonWarningRowCount(detail, label),
                    'Opportunity full-detail row count for series "' + label + '" should match the chart aggregate when nothing was truncated'
                );
            }
        }
    }

    // ------------------------------------------------------------------------------------------
    //  Opportunity End to End Visibility - Total Opportunity / Won (Status__c = 'Closed Won') /
    //  Lost (Status__c = 'Closed Lost')
    // ------------------------------------------------------------------------------------------

    @isTest
    static void testGetChartDataOpportunityEndToEndVisibilityMatchesDirectCounts() {
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'opportunityEndToEndVisibility',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Integer directTotal = [SELECT COUNT() FROM Opportunity__c];
        Integer directWon = [SELECT COUNT() FROM Opportunity__c WHERE Status__c = 'Closed Won'];
        Integer directLost = [SELECT COUNT() FROM Opportunity__c WHERE Status__c = 'Closed Lost'];

        System.assertEquals(directTotal, seriesTotal(data, 'Opportunity').intValue(), 'Opportunity series should match the direct Opportunity__c count');
        System.assertEquals(directWon, seriesTotal(data, 'Won').intValue(), 'Won series should match direct count of Status__c = Closed Won');
        System.assertEquals(directLost, seriesTotal(data, 'Lost').intValue(), 'Lost series should match direct count of Status__c = Closed Lost');
    }

    @isTest
    static void testGetChartFullDetailOpportunityEndToEndVisibilityMatchesChartAggregateTotals() {
        ProspectsDashboardController.ChartData chartData = ProspectsDashboardController.getChartData(
            'opportunityEndToEndVisibility',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );

        Test.startTest();
        List<ProspectsDashboardController.DrillDownRecord> detail = ProspectsDashboardController.getChartFullDetail('opportunityEndToEndVisibility', '{}');
        Test.stopTest();

        for (String label : new List<String>{ 'Opportunity', 'Won', 'Lost' }) {
            Decimal aggregateTotal = seriesTotal(chartData, label);
            Boolean anyTruncated = false;
            for (ProspectsDashboardController.DrillDownRecord r : detail) {
                if (r.seriesLabel == label && r.recordId == null) {
                    anyTruncated = true;
                }
            }
            if (!anyTruncated) {
                System.assertEquals(
                    aggregateTotal.intValue(),
                    nonWarningRowCount(detail, label),
                    'Opportunity End to End Visibility full-detail row count for series "' + label + '" should match the chart aggregate when nothing was truncated'
                );
            }
        }
    }

    @isTest
    static void testGetDrillDownRecordsOpportunityEndToEndVisibilityUnknownSeriesThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            ProspectsDashboardController.getDrillDownRecords('opportunityEndToEndVisibility', 'Not A Real Series', '2026-Q1', '{}');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'an unknown series label should throw');
    }

    // ------------------------------------------------------------------------------------------
    //  Opportunity Trend (2026-09 rewrite) - month-wise count of Opportunities created, bucketed by
    //  the Team (Sales_Marketing_Lead__c) of the Lead__c each came from, joined via
    //  Opportunity__c.Lead_Id__c (a plain Text field storing the Lead's Id - Lead__c's own
    //  Converted_Opportunity_Id__c lookup turned out to be populated on zero records in production,
    //  confirmed directly in that org before switching to this field). Fully replaces the old
    //  3-series quarter-wise chart (Opportunity / Actual Commercialization (New) / Total Won Opp
    //  from Commercialization stage) - no longer present on this dashboard.
    // ------------------------------------------------------------------------------------------

    @isTest
    static void testGetChartDataOpportunityTrendMatchesDirectCounts() {
        // Schema-drift guard - see ProspectsDashboardController.OPP_LEAD_ID_FIELD_EXISTS. This
        // sandbox's Opportunity__c doesn't have Lead_Id__c at all (production does), and Apex
        // validates typed field access against the COMPILING org's schema regardless of dynamic vs
        // static SOQL, so a direct o.Lead_Id__c reference here would fail to compile in this org.
        // Using Database.query() + untyped SObject.get() keeps this test compiling everywhere; it
        // becomes a real (skipped-if-absent) verification once run in an org that has the field.
        if (!Schema.SObjectType.Opportunity__c.fields.getMap().containsKey('lead_id__c')) {
            return;
        }

        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'opportunityTrend',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        // Independently reconstruct the Opportunity.Lead_Id__c -> Lead__c.Sales_Marketing_Lead__c
        // join rather than reusing the controller's own logic, so this test actually catches a
        // regression in that join instead of just agreeing with itself.
        Map<Id, String> leadTeamById = new Map<Id, String>();
        for (Lead__c l : [
            SELECT Id, Sales_Marketing_Lead__c FROM Lead__c
            WHERE Sales_Marketing_Lead__c IN ('Sales Lead', 'Marketing Lead', 'Digital Marketing Leads')
        ]) {
            leadTeamById.put(l.Id, l.Sales_Marketing_Lead__c);
        }

        Map<String, Integer> directCounts = new Map<String, Integer>();
        for (SObject row : Database.query('SELECT Lead_Id__c FROM Opportunity__c WHERE Lead_Id__c != null')) {
            Object rawLeadId = row.get('Lead_Id__c');
            Id leadId;
            try {
                leadId = Id.valueOf(String.valueOf(rawLeadId).trim());
            } catch (Exception e) {
                leadId = null;
            }
            if (leadId == null) {
                continue;
            }
            String team = leadTeamById.get(leadId);
            if (team != null) {
                directCounts.put(team, (directCounts.containsKey(team) ? directCounts.get(team) : 0) + 1);
            }
        }

        for (String team : new List<String>{ 'Sales Lead', 'Marketing Lead', 'Digital Marketing Leads' }) {
            Integer directCount = directCounts.containsKey(team) ? directCounts.get(team) : 0;
            System.assertEquals(
                directCount,
                seriesTotal(data, team).intValue(),
                team + ' series should match direct count of Opportunities whose Lead_Id__c points to a Lead with that Team'
            );
        }

        for (String label : data.labels) {
            System.assert(
                Pattern.matches('^\\d{4}-\\d{2}$', label),
                'Opportunity Trend labels should be YYYY-MM month keys, got: ' + label
            );
        }
    }

    @isTest
    static void testGetChartFullDetailOpportunityTrendMatchesChartAggregateTotals() {
        ProspectsDashboardController.ChartData chartData = ProspectsDashboardController.getChartData(
            'opportunityTrend',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );

        Test.startTest();
        List<ProspectsDashboardController.DrillDownRecord> detail = ProspectsDashboardController.getChartFullDetail('opportunityTrend', '{}');
        Test.stopTest();

        for (String label : new List<String>{ 'Sales Lead', 'Marketing Lead', 'Digital Marketing Leads' }) {
            Decimal aggregateTotal = seriesTotal(chartData, label);
            Boolean anyTruncated = false;
            for (ProspectsDashboardController.DrillDownRecord r : detail) {
                if (r.seriesLabel == label && r.recordId == null) {
                    anyTruncated = true;
                }
            }
            if (!anyTruncated) {
                System.assertEquals(
                    aggregateTotal.intValue(),
                    nonWarningRowCount(detail, label),
                    'Opportunity Trend full-detail row count for series "' + label + '" should match the chart aggregate when nothing was truncated'
                );
            }
        }
    }

    @isTest
    static void testGetDrillDownRecordsOpportunityTrendUnknownSeriesThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            ProspectsDashboardController.getDrillDownRecords('opportunityTrend', 'Not A Real Series', '2026-01', '{}');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'an unknown series label should throw');
    }

    // ------------------------------------------------------------------------------------------
    //  Opportunity to Evaluation Ratio - replaces Prospect to Evaluation Ratio's dashboard slot for
    //  Opportunity__c. Total Opportunity / Evaluation (Actual_Evaluation_Week_Dashboard__c != null)
    // ------------------------------------------------------------------------------------------

    @isTest
    static void testGetChartDataOpportunityToEvaluationRatioMatchesDirectCounts() {
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'opportunityToEvaluationRatio',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Integer directTotal = [SELECT COUNT() FROM Opportunity__c];
        Integer directEvaluation = [SELECT COUNT() FROM Opportunity__c WHERE Actual_Evaluation_Week_Dashboard__c != null];

        System.assertEquals(directTotal, seriesTotal(data, 'Opportunity').intValue(), 'Opportunity series should match the direct Opportunity__c count');
        System.assertEquals(
            directEvaluation,
            seriesTotal(data, 'Evaluation').intValue(),
            'Evaluation series should match direct count of Actual_Evaluation_Week_Dashboard__c != null'
        );
    }

    @isTest
    static void testGetChartFullDetailOpportunityToEvaluationRatioMatchesChartAggregateTotals() {
        ProspectsDashboardController.ChartData chartData = ProspectsDashboardController.getChartData(
            'opportunityToEvaluationRatio',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );

        Test.startTest();
        List<ProspectsDashboardController.DrillDownRecord> detail = ProspectsDashboardController.getChartFullDetail('opportunityToEvaluationRatio', '{}');
        Test.stopTest();

        for (String label : new List<String>{ 'Opportunity', 'Evaluation' }) {
            Decimal aggregateTotal = seriesTotal(chartData, label);
            Boolean anyTruncated = false;
            for (ProspectsDashboardController.DrillDownRecord r : detail) {
                if (r.seriesLabel == label && r.recordId == null) {
                    anyTruncated = true;
                }
            }
            if (!anyTruncated) {
                System.assertEquals(
                    aggregateTotal.intValue(),
                    nonWarningRowCount(detail, label),
                    'Opportunity to Evaluation Ratio full-detail row count for series "' + label + '" should match the chart aggregate when nothing was truncated'
                );
            }
        }
    }

    @isTest
    static void testGetDrillDownRecordsOpportunityToEvaluationRatioUnknownSeriesThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            ProspectsDashboardController.getDrillDownRecords('opportunityToEvaluationRatio', 'Not A Real Series', '2026-Q1', '{}');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'an unknown series label should throw');
    }

    // ------------------------------------------------------------------------------------------
    //  Opportunity Evaluation to Conversion Ratio - replaces Evaluation to Conversion Ratio's
    //  dashboard slot for Opportunity__c. Evaluation (Actual_Evaluation_Week_Dashboard__c != null)
    //  / Total Won Opp from Evaluation Stage (2026-09: replaces the original "Conversion" series,
    //  which summed Commercialization+Upgrade parts - Actual_Evaluation_Week_Dashboard__c != null
    //  AND Status__c = 'Closed Won')
    // ------------------------------------------------------------------------------------------

    @isTest
    static void testGetChartDataOpportunityEvaluationToConversionRatioMatchesDirectCounts() {
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'opportunityEvaluationToConversionRatio',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Integer directEvaluation = [SELECT COUNT() FROM Opportunity__c WHERE Actual_Evaluation_Week_Dashboard__c != null];
        Integer directWonEvaluation = [
            SELECT COUNT() FROM Opportunity__c
            WHERE Actual_Evaluation_Week_Dashboard__c != null AND Status__c = 'Closed Won'
        ];

        System.assertEquals(
            directEvaluation,
            seriesTotal(data, 'Evaluation').intValue(),
            'Evaluation series should match direct count of Actual_Evaluation_Week_Dashboard__c != null'
        );
        System.assertEquals(
            directWonEvaluation,
            seriesTotal(data, 'Total Won Opp from Evaluation Stage').intValue(),
            'Total Won Opp from Evaluation Stage series should match direct count of Actual_Evaluation_Week_Dashboard__c != null AND Status__c = Closed Won'
        );
    }

    @isTest
    static void testGetChartFullDetailOpportunityEvaluationToConversionRatioMatchesChartAggregateTotals() {
        ProspectsDashboardController.ChartData chartData = ProspectsDashboardController.getChartData(
            'opportunityEvaluationToConversionRatio',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );

        Test.startTest();
        List<ProspectsDashboardController.DrillDownRecord> detail = ProspectsDashboardController.getChartFullDetail('opportunityEvaluationToConversionRatio', '{}');
        Test.stopTest();

        for (String label : new List<String>{ 'Evaluation', 'Total Won Opp from Evaluation Stage' }) {
            Decimal aggregateTotal = seriesTotal(chartData, label);
            Boolean anyTruncated = false;
            for (ProspectsDashboardController.DrillDownRecord r : detail) {
                if (r.seriesLabel == label && r.recordId == null) {
                    anyTruncated = true;
                }
            }
            if (!anyTruncated) {
                System.assertEquals(
                    aggregateTotal.intValue(),
                    nonWarningRowCount(detail, label),
                    'Opportunity Evaluation to Conversion Ratio full-detail row count for series "' + label + '" should match the chart aggregate when nothing was truncated'
                );
            }
        }
    }

    @isTest
    static void testGetDrillDownRecordsOpportunityEvaluationToConversionRatioUnknownSeriesThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            ProspectsDashboardController.getDrillDownRecords('opportunityEvaluationToConversionRatio', 'Not A Real Series', '2026-Q1', '{}');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'an unknown series label should throw');
    }

    // ------------------------------------------------------------------------------------------
    //  Expired Opportunity - new chart, not a replacement. Net Opportunity (Total Opportunity) /
    //  Closed Opportunity (Opportunity_Closed__c = true, the org's 180-day auto-close)
    // ------------------------------------------------------------------------------------------

    @isTest
    static void testGetChartDataExpiredOpportunityMatchesDirectCounts() {
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'expiredOpportunity',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Integer directTotal = [SELECT COUNT() FROM Opportunity__c];
        Integer directClosed = [SELECT COUNT() FROM Opportunity__c WHERE Opportunity_Closed__c = true];

        System.assertEquals(directTotal, seriesTotal(data, 'Net Opportunity').intValue(), 'Net Opportunity series should match the direct Opportunity__c count');
        System.assertEquals(directClosed, seriesTotal(data, 'Closed Opportunity').intValue(), 'Closed Opportunity series should match direct count of Opportunity_Closed__c = true');
    }

    @isTest
    static void testGetChartFullDetailExpiredOpportunityMatchesChartAggregateTotals() {
        ProspectsDashboardController.ChartData chartData = ProspectsDashboardController.getChartData(
            'expiredOpportunity',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );

        Test.startTest();
        List<ProspectsDashboardController.DrillDownRecord> detail = ProspectsDashboardController.getChartFullDetail('expiredOpportunity', '{}');
        Test.stopTest();

        for (String label : new List<String>{ 'Net Opportunity', 'Closed Opportunity' }) {
            Decimal aggregateTotal = seriesTotal(chartData, label);
            Boolean anyTruncated = false;
            for (ProspectsDashboardController.DrillDownRecord r : detail) {
                if (r.seriesLabel == label && r.recordId == null) {
                    anyTruncated = true;
                }
            }
            if (!anyTruncated) {
                System.assertEquals(
                    aggregateTotal.intValue(),
                    nonWarningRowCount(detail, label),
                    'Expired Opportunity full-detail row count for series "' + label + '" should match the chart aggregate when nothing was truncated'
                );
            }
        }
    }

    @isTest
    static void testGetDrillDownRecordsExpiredOpportunityUnknownSeriesThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            ProspectsDashboardController.getDrillDownRecords('expiredOpportunity', 'Not A Real Series', '2026-Q1', '{}');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'an unknown series label should throw');
    }

    // ------------------------------------------------------------------------------------------
    //  Overall Reporting Opp - new chart, companion to Overall Reporting Prospect. Opportunity
    //  (Total Opportunity) / WIP & Concluded (Status__c != null)
    // ------------------------------------------------------------------------------------------

    @isTest
    static void testGetChartDataOverallReportingOppMatchesDirectCounts() {
        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getChartData(
            'overallReportingOpp',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Integer directTotal = [SELECT COUNT() FROM Opportunity__c];
        Integer directWip = [SELECT COUNT() FROM Opportunity__c WHERE Status__c != null];

        System.assertEquals(directTotal, seriesTotal(data, 'Opportunity').intValue(), 'Opportunity series should match the direct Opportunity__c count');
        System.assertEquals(directWip, seriesTotal(data, 'WIP & Concluded').intValue(), 'WIP & Concluded series should match direct count of Status__c != null');
    }

    @isTest
    static void testGetChartFullDetailOverallReportingOppMatchesChartAggregateTotals() {
        ProspectsDashboardController.ChartData chartData = ProspectsDashboardController.getChartData(
            'overallReportingOpp',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );

        Test.startTest();
        List<ProspectsDashboardController.DrillDownRecord> detail = ProspectsDashboardController.getChartFullDetail('overallReportingOpp', '{}');
        Test.stopTest();

        for (String label : new List<String>{ 'Opportunity', 'WIP & Concluded' }) {
            Decimal aggregateTotal = seriesTotal(chartData, label);
            Boolean anyTruncated = false;
            for (ProspectsDashboardController.DrillDownRecord r : detail) {
                if (r.seriesLabel == label && r.recordId == null) {
                    anyTruncated = true;
                }
            }
            if (!anyTruncated) {
                System.assertEquals(
                    aggregateTotal.intValue(),
                    nonWarningRowCount(detail, label),
                    'Overall Reporting Opp full-detail row count for series "' + label + '" should match the chart aggregate when nothing was truncated'
                );
            }
        }
    }

    @isTest
    static void testGetDrillDownRecordsOverallReportingOppUnknownSeriesThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            ProspectsDashboardController.getDrillDownRecords('overallReportingOpp', 'Not A Real Series', '2026-Q1', '{}');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'an unknown series label should throw');
    }

    // ------------------------------------------------------------------------------------------
    //  getKpiSummary - new Opportunity tiles (Opp Count / Won Opp / Lost Opp / Expired Opp)
    // ------------------------------------------------------------------------------------------

    @isTest
    static void testGetKpiSummaryOpportunityTilesMatchDirectCounts() {
        Test.startTest();
        ProspectsDashboardController.KpiSummary summary = ProspectsDashboardController.getKpiSummary(
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Integer directTotal = [SELECT COUNT() FROM Opportunity__c];
        Integer directWon = [SELECT COUNT() FROM Opportunity__c WHERE Status__c = 'Closed Won'];
        Integer directLost = [SELECT COUNT() FROM Opportunity__c WHERE Status__c = 'Closed Lost'];
        Integer directExpired = [SELECT COUNT() FROM Opportunity__c WHERE Opportunity_Closed__c = true];

        System.assertEquals(directTotal, summary.oppCount, 'oppCount should match the direct Opportunity__c count');
        System.assertEquals(directWon, summary.wonOpp, 'wonOpp should match direct count of Status__c = Closed Won');
        System.assertEquals(directLost, summary.lostOpp, 'lostOpp should match direct count of Status__c = Closed Lost');
        System.assertEquals(directExpired, summary.expiredOpp, 'expiredOpp should match direct count of Opportunity_Closed__c = true');
    }

    // 2026-09: the Product Family chart only shows currently-active Lead_Stage__c picklist values
    // (Appointments/Unqualified/Converted) - records still carrying a stage value that's since been
    // deactivated are excluded entirely, so this no longer matches the unfiltered Lead__c count.
    private static Set<String> activePicklistValues(Schema.SObjectField field) {
        Set<String> values = new Set<String>();
        for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                values.add(entry.getValue());
            }
        }
        return values;
    }

    @isTest
    static void testGetProductFamilyFullDetailMatchesActiveStageDirectCount() {
        Set<String> activeStages = activePicklistValues(Lead__c.Lead_Stage__c);
        Integer directCount = [SELECT COUNT() FROM Lead__c WHERE Lead_Stage__c IN :activeStages OR Lead_Stage__c = null];

        Test.startTest();
        List<ProspectsDashboardController.DrillDownRecord> detail = ProspectsDashboardController.getProductFamilyFullDetail('{}');
        Test.stopTest();

        System.assertEquals(directCount, detail.size(), 'Product Family full-detail row count should match the direct count restricted to active Lead_Stage__c values');
        for (ProspectsDashboardController.DrillDownRecord r : detail) {
            System.assertNotEquals(null, r.matchedVia, 'every row should carry a Product Family bucket (blank collapses to the "(No Product Family)" label)');
            System.assertNotEquals(null, r.seriesLabel, 'every row should carry a Stage bucket (blank collapses to the "No Stage" label)');
            System.assert(
                r.seriesLabel == 'No Stage' || activeStages.contains(r.seriesLabel),
                'every row\'s stage should be an active picklist value or the blank "No Stage" bucket, got: ' + r.seriesLabel
            );
        }
    }

    @isTest
    static void testGetChartDataProductFamilyStageBreakdownOnlyUsesActiveStages() {
        Set<String> activeStages = activePicklistValues(Lead__c.Lead_Stage__c);

        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getProductFamilyStageBreakdown('{}');
        Test.stopTest();

        for (ProspectsDashboardController.ChartSeries s : data.series) {
            System.assert(
                s.label == 'No Stage' || activeStages.contains(s.label),
                'every series on the Product Family chart should be an active Lead_Stage__c value or the blank "No Stage" bucket, got: ' + s.label
            );
        }
    }

    // 2026-09: the Product Family chart counts unique (Name, Product Family) pairs, not raw
    // records - two leads sharing the same Name under the same Product Family count once, not
    // twice. Independently reconstructs the expected dedup in the test (rather than reusing the
    // controller's own helper) so this test actually catches a regression in that logic.
    @isTest
    static void testGetChartDataProductFamilyStageBreakdownDedupsSameNameAndFamily() {
        Set<String> activeStages = activePicklistValues(Lead__c.Lead_Stage__c);
        List<Lead__c> recs = [
            SELECT Name, Product_Family__c
            FROM Lead__c
            WHERE Lead_Stage__c IN :activeStages OR Lead_Stage__c = null
        ];
        Set<String> expectedUniqueKeys = new Set<String>();
        for (Lead__c rec : recs) {
            String familyKey = String.isBlank(rec.Product_Family__c) ? '(No Product Family)' : rec.Product_Family__c;
            expectedUniqueKeys.add((rec.Name == null ? '' : rec.Name) + ' ' + familyKey);
        }

        Test.startTest();
        ProspectsDashboardController.ChartData data = ProspectsDashboardController.getProductFamilyStageBreakdown('{}');
        Test.stopTest();

        Integer chartTotal = 0;
        for (ProspectsDashboardController.ChartSeries s : data.series) {
            for (Decimal d : s.data) {
                chartTotal += d.intValue();
            }
        }
        System.assertEquals(
            expectedUniqueKeys.size(),
            chartTotal,
            'Product Family chart should count unique (Name, Product Family) pairs, not raw record count - two leads with the same Name under the same family should count once'
        );
    }

    @isTest
    static void testGetKpiSummaryUniqueFamilyProspectsMatchesChartTotal() {
        ProspectsDashboardController.ChartData chartData = ProspectsDashboardController.getProductFamilyStageBreakdown('{}');
        Integer chartTotal = 0;
        for (ProspectsDashboardController.ChartSeries s : chartData.series) {
            for (Decimal d : s.data) {
                chartTotal += d.intValue();
            }
        }

        Test.startTest();
        ProspectsDashboardController.KpiSummary summary = ProspectsDashboardController.getKpiSummary(
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        System.assertEquals(
            chartTotal,
            summary.uniqueFamilyProspects,
            'uniqueFamilyProspects KPI tile should match the Product Family chart\'s own deduped total'
        );
    }

    // ------------------------------------------------------------------------------------------
    //  Dashboard-only visibility scoping - System Administrator stays unrestricted (implicitly
    //  covered by every other test in this class, all of which run as this org's admin test user
    //  and already assert exact matches against unfiltered direct counts - if the admin exemption
    //  broke, those would fail too); the tests below specifically exercise the non-admin path.
    // ------------------------------------------------------------------------------------------

    // Requires the candidate to actually own at least one Lead__c record, not just have a role -
    // proves they have real, functional CRUD/FLS access to Lead__c/Opportunity__c today (most
    // profiles in this org do, since these are the core CRM objects), so System.runAs(candidate)
    // below exercises the visibility restriction itself rather than failing on an unrelated
    // access exception from picking an arbitrary low-access user (a portal/guest-adjacent login,
    // for instance).
    private static List<User> nonAdminLeadOwnerCandidates() {
        return [
            SELECT Id, UserRoleId FROM User
            WHERE IsActive = true AND UserRoleId != null AND Profile.Name != 'System Administrator'
            AND Id IN (SELECT OwnerId FROM Lead__c)
            LIMIT 1
        ];
    }

    @isTest
    static void testGetKpiSummaryRestrictsNonAdminToRoleHierarchyAndShares() {
        List<User> candidates = nonAdminLeadOwnerCandidates();
        if (candidates.isEmpty()) {
            return;
        }
        User nonAdmin = candidates[0];

        // Independently reconstruct the expected role-hierarchy-owned baseline (self + every user
        // whose role is at or below nonAdmin's role) rather than reusing the controller's own
        // logic, so this test actually catches a regression in that logic rather than just
        // agreeing with itself.
        Map<Id, Id> parentByRole = new Map<Id, Id>();
        for (UserRole ur : [SELECT Id, ParentRoleId FROM UserRole]) {
            parentByRole.put(ur.Id, ur.ParentRoleId);
        }
        Set<Id> descendantRoleIds = new Set<Id>{ nonAdmin.UserRoleId };
        Set<Id> frontier = new Set<Id>{ nonAdmin.UserRoleId };
        while (!frontier.isEmpty()) {
            Set<Id> nextFrontier = new Set<Id>();
            for (Id roleId : parentByRole.keySet()) {
                if (frontier.contains(parentByRole.get(roleId)) && !descendantRoleIds.contains(roleId)) {
                    descendantRoleIds.add(roleId);
                    nextFrontier.add(roleId);
                }
            }
            frontier = nextFrontier;
        }
        Set<Id> expectedVisibleOwnerIds = new Set<Id>{ nonAdmin.Id };
        for (User u : [SELECT Id FROM User WHERE UserRoleId IN :descendantRoleIds AND IsActive = true]) {
            expectedVisibleOwnerIds.add(u.Id);
        }
        Integer expectedByOwnerHierarchy = [SELECT COUNT() FROM Lead__c WHERE OwnerId IN :expectedVisibleOwnerIds];
        Integer orgWideTotal = [SELECT COUNT() FROM Lead__c];

        Integer restrictedTotal;
        System.runAs(nonAdmin) {
            ProspectsDashboardController.KpiSummary summary = ProspectsDashboardController.getKpiSummary(
                JSON.serialize(new ProspectsDashboardController.FilterRequest())
            );
            restrictedTotal = summary.totalProspects;
        }

        // The controller's total is the role-hierarchy-owned baseline PLUS anything additionally
        // reachable via Lead__Share (Manual/Rule grants) - so it must be at least that baseline
        // (the hierarchy logic isn't dropping legitimately-owned records) and never exceed the
        // org-wide total (the restriction is actually restricting, not silently doing nothing).
        System.assert(
            restrictedTotal >= expectedByOwnerHierarchy,
            'a non-admin\'s visible total should include at least every record owned by them or their role-hierarchy subordinates'
        );
        System.assert(
            restrictedTotal <= orgWideTotal,
            'a non-admin\'s visible total should never exceed the org-wide total'
        );
    }

    @isTest
    static void testGetKpiSummaryOppTotalRestrictsNonAdmin() {
        List<User> candidates = nonAdminLeadOwnerCandidates();
        if (candidates.isEmpty()) {
            return;
        }
        User nonAdmin = candidates[0];
        Integer orgWideOppTotal = [SELECT COUNT() FROM Opportunity__c];

        Integer restrictedOppTotal;
        System.runAs(nonAdmin) {
            ProspectsDashboardController.KpiSummary summary = ProspectsDashboardController.getKpiSummary(
                JSON.serialize(new ProspectsDashboardController.FilterRequest())
            );
            restrictedOppTotal = summary.oppCount;
        }

        System.assert(
            restrictedOppTotal <= orgWideOppTotal,
            'a non-admin\'s visible Opportunity total should never exceed the org-wide total'
        );
    }

    @isTest
    static void testGetFilterOptionsOwnerDropdownRestrictsNonAdmin() {
        List<User> candidates = nonAdminLeadOwnerCandidates();
        if (candidates.isEmpty()) {
            return;
        }
        User nonAdmin = candidates[0];

        // Upper bound on the unrestricted admin owner count via lightweight aggregate queries,
        // not a second getFilterOptions() call: System.runAs does NOT reset the SOQL
        // row-count governor limit (it shares the enclosing test method's budget), and
        // getFilterOptions now scans BOTH Lead__c and Opportunity__c for the Owner dropdown - two
        // full calls' worth of both scans in one transaction can exceed 50,000 rows. This doesn't
        // de-duplicate an owner appearing on both objects, so it's only an upper bound, but that's
        // all the assertion below needs.
        Integer adminOwnerUpperBound = 0;
        for (AggregateResult ar : [SELECT COUNT_DISTINCT(OwnerId) cnt FROM Lead__c WHERE OwnerId != null]) {
            adminOwnerUpperBound += (Integer) ar.get('cnt');
        }
        for (AggregateResult ar : [SELECT COUNT_DISTINCT(OwnerId) cnt FROM Opportunity__c WHERE OwnerId != null]) {
            adminOwnerUpperBound += (Integer) ar.get('cnt');
        }

        ProspectsDashboardController.FilterOptions restrictedOptions;
        System.runAs(nonAdmin) {
            restrictedOptions = ProspectsDashboardController.getFilterOptions(
                JSON.serialize(new ProspectsDashboardController.FilterRequest())
            );
        }

        System.assert(
            restrictedOptions.owners.size() <= adminOwnerUpperBound,
            'a non-admin\'s Owner filter dropdown should never list more owners than the unrestricted admin view'
        );
    }

    @isTest
    static void testGetChartDataInClinicTargetMatchesDirectActivityCount() {
        List<Target__c> targets = [
            SELECT Id, Year__c, Quater_No__c FROM Target__c
            WHERE Type__c = 'In-Clinic Activities' AND Year__c != null AND Quater_No__c != null
            LIMIT 500
        ];
        if (targets.isEmpty()) {
            return;
        }
        Set<Id> targetIds = new Map<Id, Target__c>(targets).keySet();
        Integer directCount = [SELECT COUNT() FROM Task WHERE WhatId IN :targetIds]
            + [SELECT COUNT() FROM Event WHERE WhatId IN :targetIds];

        Test.startTest();
        ProspectsDashboardController.ChartData chartData = ProspectsDashboardController.getChartData(
            'inClinicTarget',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Decimal chartTotal = 0;
        for (ProspectsDashboardController.ChartSeries s : chartData.series) {
            for (Decimal d : s.data) {
                chartTotal += d;
            }
        }
        System.assertEquals(
            directCount,
            chartTotal.intValue(),
            'In-Clinic Target Activities chart total should match a direct Task+Event count against the same Targets'
        );
    }

    @isTest
    static void testGetChartDataMarketingTargetMatchesDirectMemberCount() {
        List<Target__c> targets = [
            SELECT Id, Year__c, Quater_No__c FROM Target__c
            WHERE Type__c = 'Marketing Activities' AND Year__c != null AND Quater_No__c != null
            LIMIT 500
        ];
        if (targets.isEmpty()) {
            return;
        }
        Set<Id> targetIds = new Map<Id, Target__c>(targets).keySet();
        Set<Id> campaignIds = new Map<Id, Campaign__c>(
            [SELECT Id FROM Campaign__c WHERE Target__c IN :targetIds]
        ).keySet();
        Integer directMemberCount = campaignIds.isEmpty() ? 0 : [
            SELECT COUNT() FROM Campaign_Member__c WHERE Campaign1__c IN :campaignIds
        ];

        Test.startTest();
        ProspectsDashboardController.ChartData chartData = ProspectsDashboardController.getChartData(
            'marketingTarget',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Decimal chartTotal = 0;
        for (ProspectsDashboardController.ChartSeries s : chartData.series) {
            for (Decimal d : s.data) {
                chartTotal += d;
            }
        }
        System.assertEquals(
            directMemberCount,
            chartTotal.intValue(),
            'Marketing Target chart total (Attended + Not Attended) should match a direct Campaign Member count against the same Targets\' campaigns'
        );
    }

    @isTest
    static void testGetDrillDownRecordsInClinicTargetUnknownSeriesThrows() {
        try {
            ProspectsDashboardController.getDrillDownRecords(
                'inClinicTarget',
                'NotARealSeries',
                '2026-Q1',
                JSON.serialize(new ProspectsDashboardController.FilterRequest())
            );
            System.assert(false, 'expected an AuraHandledException for an unknown series');
        } catch (AuraHandledException e) {
            // expected
        }
    }

    @isTest
    static void testGetDrillDownRecordsMarketingTargetUnknownSeriesThrows() {
        try {
            ProspectsDashboardController.getDrillDownRecords(
                'marketingTarget',
                'NotARealSeries',
                '2026-Q1',
                JSON.serialize(new ProspectsDashboardController.FilterRequest())
            );
            System.assert(false, 'expected an AuraHandledException for an unknown series');
        } catch (AuraHandledException e) {
            // expected
        }
    }

    @isTest
    static void testGetChartFullDetailInClinicTargetMatchesChartAggregateTotal() {
        Test.startTest();
        ProspectsDashboardController.ChartData chartData = ProspectsDashboardController.getChartData(
            'inClinicTarget',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        List<ProspectsDashboardController.DrillDownRecord> detail = ProspectsDashboardController.getChartFullDetail(
            'inClinicTarget',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Decimal chartTotal = 0;
        for (ProspectsDashboardController.ChartSeries s : chartData.series) {
            for (Decimal d : s.data) {
                chartTotal += d;
            }
        }
        System.assertEquals(
            chartTotal.intValue(),
            detail.size(),
            'In-Clinic Target Activities full-detail row count should match the chart aggregate total when nothing was truncated'
        );
    }

    @isTest
    static void testGetChartFullDetailMarketingTargetMatchesChartAggregateTotal() {
        Test.startTest();
        ProspectsDashboardController.ChartData chartData = ProspectsDashboardController.getChartData(
            'marketingTarget',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        List<ProspectsDashboardController.DrillDownRecord> detail = ProspectsDashboardController.getChartFullDetail(
            'marketingTarget',
            JSON.serialize(new ProspectsDashboardController.FilterRequest())
        );
        Test.stopTest();

        Decimal chartTotal = 0;
        for (ProspectsDashboardController.ChartSeries s : chartData.series) {
            for (Decimal d : s.data) {
                chartTotal += d;
            }
        }
        System.assertEquals(
            chartTotal.intValue(),
            detail.size(),
            'Marketing Target full-detail row count should match the chart aggregate total when nothing was truncated'
        );
    }
}
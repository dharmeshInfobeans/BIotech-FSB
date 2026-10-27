@isTest
private class SAPDashboardControllerTest {

    private static Customer_Ledger__c createLedger(String code, String status, String signStatus) {
        Customer_Ledger__c l = new Customer_Ledger__c(
            Customer_Code__c = code,
            Status__c        = status,
            Sign_Status__c   = signStatus
        );
        insert l;
        return l;
    }

    @isTest
    static void testGetAvailableYears_IncludesCurrentAndPastYears() {
        Integer currentYear = Date.today().year();
        Integer pastYear    = currentYear - 2;

        Customer_Ledger__c pastLedger = createLedger('C1', 'Fetched', null);
        Test.setCreatedDate(
            pastLedger.Id,
            DateTime.newInstance(Date.newInstance(pastYear, 5, 15), Time.newInstance(10, 0, 0, 0))
        );

        Test.startTest();
        List<Integer> years = SAPDashboardController.getAvailableYears();
        Test.stopTest();

        System.assert(years.contains(currentYear), 'Should always include the current year');
        System.assert(years.contains(pastYear), 'Should include the year of the inserted record');

        for (Integer i = 0; i < years.size() - 1; i++) {
            System.assert(years[i] >= years[i + 1], 'Years should be sorted newest first');
        }
    }

    @isTest
    static void testGetDashboardData_FilteredByYear() {
        Integer targetYear = Date.today().year() - 1;
        DateTime withinYear = DateTime.newInstance(Date.newInstance(targetYear, 6, 15), Time.newInstance(9, 0, 0, 0));

        Customer_Ledger__c fetchedLedger  = createLedger('D1', 'Fetched', null);
        Customer_Ledger__c sentLedger     = createLedger('D2', 'Sent', null);
        Customer_Ledger__c signedLedger   = createLedger('D3', 'Completed', 'SIGNED');
        Customer_Ledger__c signedByFlag   = createLedger('D4', 'Sent', 'SIGNED'); // signed via Sign_Status__c only
        Customer_Ledger__c declinedLedger = createLedger('D5', 'Declined', null);

        for (Customer_Ledger__c l : new List<Customer_Ledger__c>{
            fetchedLedger, sentLedger, signedLedger, signedByFlag, declinedLedger
        }) {
            Test.setCreatedDate(l.Id, withinYear);
        }

        // Noise record in a different year — must not be counted
        Customer_Ledger__c otherYearLedger = createLedger('D6', 'Fetched', null);
        Test.setCreatedDate(
            otherYearLedger.Id,
            DateTime.newInstance(Date.newInstance(targetYear - 1, 3, 1), Time.newInstance(9, 0, 0, 0))
        );

        Test.startTest();
        SAPDashboardController.DashboardData data = SAPDashboardController.getDashboardData(targetYear);
        Test.stopTest();

        System.assertEquals(5, data.totalLedgers);
        System.assertEquals(1, data.fetched);
        System.assertEquals(2, data.sent);     // sentLedger + signedByFlag (both Status__c = 'Sent')
        System.assertEquals(2, data.signed);   // signedLedger (Completed) + signedByFlag (Sign_Status__c = SIGNED)
        System.assertEquals(1, data.declined);
        System.assertEquals(0, data.batchRunning);
    }

    @isTest
    static void testGetDashboardData_NoYearFilter_AggregatesAll() {
        createLedger('N1', 'Fetched', null);
        createLedger('N2', 'Declined', null);

        Test.startTest();
        SAPDashboardController.DashboardData data = SAPDashboardController.getDashboardData(null);
        Test.stopTest();

        System.assert(data.totalLedgers >= 2);
        System.assert(data.fetched >= 1);
        System.assert(data.declined >= 1);
    }

    @isTest
    static void testGetQuarterSummary_PastYear_ReturnsAllFourQuarters() {
        Integer pastYear = Date.today().year() - 3;

        Customer_Ledger__c q1Ledger = createLedger('Q1', 'Fetched', null);
        Test.setCreatedDate(
            q1Ledger.Id,
            DateTime.newInstance(Date.newInstance(pastYear, 2, 10), Time.newInstance(9, 0, 0, 0))
        );

        Customer_Ledger__c q3Ledger = createLedger('Q3', 'Completed', 'SIGNED');
        Test.setCreatedDate(
            q3Ledger.Id,
            DateTime.newInstance(Date.newInstance(pastYear, 8, 5), Time.newInstance(9, 0, 0, 0))
        );

        Test.startTest();
        List<SAPDashboardController.QuarterSummary> summaries = SAPDashboardController.getQuarterSummary(pastYear);
        Test.stopTest();

        // A specifically chosen past year should always show all 4 quarters
        System.assertEquals(4, summaries.size());

        Map<String, SAPDashboardController.QuarterSummary> byQuarter =
            new Map<String, SAPDashboardController.QuarterSummary>();
        for (SAPDashboardController.QuarterSummary qs : summaries) {
            byQuarter.put(qs.quarter, qs);
        }

        System.assertEquals(1, byQuarter.get('Q1 FY' + pastYear).totalLedgers);
        System.assertEquals(1, byQuarter.get('Q1 FY' + pastYear).fetched);
        System.assertEquals(1, byQuarter.get('Q3 FY' + pastYear).totalLedgers);
        System.assertEquals(1, byQuarter.get('Q3 FY' + pastYear).signed);
        System.assertEquals(0, byQuarter.get('Q2 FY' + pastYear).totalLedgers);
        System.assertEquals(0, byQuarter.get('Q4 FY' + pastYear).totalLedgers);
    }

    @isTest
    static void testGetQuarterSummary_CurrentYear_HidesFutureQuarters() {
        Integer currentYear    = Date.today().year();
        Integer currentQuarter = ((Date.today().month() - 1) / 3) + 1;

        Test.startTest();
        List<SAPDashboardController.QuarterSummary> summaries = SAPDashboardController.getQuarterSummary(currentYear);
        Test.stopTest();

        // Only quarters that have started (up to and including the current one) should appear
        System.assertEquals(currentQuarter, summaries.size());

        for (SAPDashboardController.QuarterSummary qs : summaries) {
            System.assert(qs.quarter.startsWith('Q'));
            System.assert(qs.quarter.endsWith('FY' + currentYear));
        }
    }
}
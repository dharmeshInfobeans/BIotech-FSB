public with sharing class SAPDashboardController {

    public class DashboardData {

        @AuraEnabled public Integer totalLedgers;
        @AuraEnabled public Integer fetched;
        @AuraEnabled public Integer sent;
        @AuraEnabled public Integer signed;
        @AuraEnabled public Integer declined;
        @AuraEnabled public Integer pending;
        @AuraEnabled public Integer batchRunning;
    }

    public class QuarterSummary {

        @AuraEnabled public String quarter;
        @AuraEnabled public Integer totalLedgers = 0;
        @AuraEnabled public Integer fetched = 0;
        @AuraEnabled public Integer sent = 0;
        @AuraEnabled public Integer signed = 0;
        @AuraEnabled public Integer declined = 0;
    }

    // ---------- Year picklist source ----------
    @AuraEnabled(cacheable=true)
    public static List<Integer> getAvailableYears() {

        Set<Integer> years = new Set<Integer>();
        years.add(Date.today().year());

        for (AggregateResult ar : [
            SELECT CALENDAR_YEAR(CreatedDate) yr
            FROM Customer_Ledger__c
            GROUP BY CALENDAR_YEAR(CreatedDate)
        ]) {
            years.add((Integer) ar.get('yr'));
        }

        List<Integer> sorted = new List<Integer>(years);
        sorted.sort();

        // newest first
        List<Integer> descending = new List<Integer>();
        for (Integer i = sorted.size() - 1; i >= 0; i--) {
            descending.add(sorted[i]);
        }
        return descending;
    }

    // ---------- Top cards ----------
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData(Integer year) {

        DashboardData data = new DashboardData();

        if (year != null) {
            DateTime startDT = DateTime.newInstance(Date.newInstance(year, 1, 1), Time.newInstance(0,0,0,0));
            DateTime endDT   = DateTime.newInstance(Date.newInstance(year, 12, 31), Time.newInstance(23,59,59,999));

            data.totalLedgers = [
                SELECT COUNT() FROM Customer_Ledger__c
                WHERE CreatedDate >= :startDT AND CreatedDate <= :endDT
            ];

            data.fetched = [
                SELECT COUNT() FROM Customer_Ledger__c
                WHERE Status__c = 'Fetched'
                AND CreatedDate >= :startDT AND CreatedDate <= :endDT
            ];

            data.sent = [
                SELECT COUNT() FROM Customer_Ledger__c
                WHERE Status__c = 'Sent'
                AND CreatedDate >= :startDT AND CreatedDate <= :endDT
            ];

            data.signed = [
                SELECT COUNT() FROM Customer_Ledger__c
                WHERE (Status__c = 'Completed' OR Sign_Status__c = 'SIGNED')
                AND CreatedDate >= :startDT AND CreatedDate <= :endDT
            ];

            data.declined = [
                SELECT COUNT() FROM Customer_Ledger__c
                WHERE Status__c = 'Declined'
                AND CreatedDate >= :startDT AND CreatedDate <= :endDT
            ];

        } else {

            data.totalLedgers = [SELECT COUNT() FROM Customer_Ledger__c];

            data.fetched = [
                SELECT COUNT() FROM Customer_Ledger__c WHERE Status__c = 'Fetched'
            ];

            data.sent = [
                SELECT COUNT() FROM Customer_Ledger__c WHERE Status__c = 'Sent'
            ];

            data.signed = [
                SELECT COUNT() FROM Customer_Ledger__c
                WHERE Status__c = 'Completed' OR Sign_Status__c = 'SIGNED'
            ];

            data.declined = [
                SELECT COUNT() FROM Customer_Ledger__c WHERE Status__c = 'Declined'
            ];
        }

        data.batchRunning = [
            SELECT COUNT() FROM AsyncApexJob WHERE Status = 'Processing'
        ];

        return data;
    }

    // ---------- Quarter table ----------
    @AuraEnabled(cacheable=true)
    public static List<QuarterSummary> getQuarterSummary(Integer year) {

        Integer currentYear = Date.today().year();
        Integer targetYear  = (year != null) ? year : currentYear;
        Boolean isCurrentYear = (targetYear == currentYear);
        Date today = Date.today();

        List<QuarterSummary> result = new List<QuarterSummary>();

        for (Integer q = 1; q <= 4; q++) {

            Date qStart = getQuarterStart(q, targetYear);

            // Only hide not-yet-started quarters when we're looking at the
            // current year. A specifically chosen past/other year always
            // shows all 4 quarters.
            if (isCurrentYear && qStart > today) {
                continue;
            }

            QuarterSummary qs = new QuarterSummary();
            qs.quarter = 'Q' + q + ' FY' + targetYear;
            fillQuarter(qs, q, targetYear);
            result.add(qs);
        }

        return result;
    }

    private static Date getQuarterStart(Integer quarter, Integer year) {
        if (quarter == 1) return Date.newInstance(year, 1, 1);
        if (quarter == 2) return Date.newInstance(year, 4, 1);
        if (quarter == 3) return Date.newInstance(year, 7, 1);
        return Date.newInstance(year, 10, 1);
    }

    private static void fillQuarter(QuarterSummary qs, Integer quarter, Integer year) {

        Date startDate;
        Date endDate;

        if (quarter == 1) {
            startDate = Date.newInstance(year, 1, 1);
            endDate   = Date.newInstance(year, 3, 31);
        } else if (quarter == 2) {
            startDate = Date.newInstance(year, 4, 1);
            endDate   = Date.newInstance(year, 6, 30);
        } else if (quarter == 3) {
            startDate = Date.newInstance(year, 7, 1);
            endDate   = Date.newInstance(year, 9, 30);
        } else {
            startDate = Date.newInstance(year, 10, 1);
            endDate   = Date.newInstance(year, 12, 31);
        }

        DateTime startDT = DateTime.newInstance(startDate, Time.newInstance(0,0,0,0));
        DateTime endDT   = DateTime.newInstance(endDate, Time.newInstance(23,59,59,999));

        qs.totalLedgers = [
            SELECT COUNT() FROM Customer_Ledger__c
            WHERE CreatedDate >= :startDT AND CreatedDate <= :endDT
        ];

        qs.fetched = [
            SELECT COUNT() FROM Customer_Ledger__c
            WHERE Status__c = 'Fetched'
            AND CreatedDate >= :startDT AND CreatedDate <= :endDT
        ];

        qs.sent = [
            SELECT COUNT() FROM Customer_Ledger__c
            WHERE Status__c = 'Sent'
            AND CreatedDate >= :startDT AND CreatedDate <= :endDT
        ];

        qs.signed = [
            SELECT COUNT() FROM Customer_Ledger__c
            WHERE (Status__c = 'Completed' OR Sign_Status__c = 'SIGNED')
            AND CreatedDate >= :startDT AND CreatedDate <= :endDT
        ];

        qs.declined = [
            SELECT COUNT() FROM Customer_Ledger__c
            WHERE Status__c = 'Declined'
            AND CreatedDate >= :startDT AND CreatedDate <= :endDT
        ];
    }
}
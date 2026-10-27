public with sharing class RegulatoryDashboardController {

    private static final Set<String> RA_ACTIVE = new Set<String>{
        'Submitted to Regulatory', 'Under Regulatory Review',
        'Additional Documents Requested', 'Pending Customer Response'
    };
    private static final Set<String> DISTRIBUTOR_PENDING = new Set<String>{
        'Additional Documents Requested', 'Pending Customer Response'
    };

    // ── Return types ──────────────────────────────────────────────────────────

    public class DashboardData {
        @AuraEnabled public KpiData           kpi;
        @AuraEnabled public List<StatusCount> byStatus;
        @AuraEnabled public List<CountryStat> byCountry;
        @AuraEnabled public List<OverdueItem> overdueList;
    }

    public class KpiData {
        @AuraEnabled public Integer pendingCount;
        @AuraEnabled public Integer underReviewCount;
        @AuraEnabled public Integer pendingDistributorActions;
        @AuraEnabled public Integer cycleCount;
        @AuraEnabled public Integer completedThisMonth;
        @AuraEnabled public String  avgProcessingDays;
    }

    public class StatusCount {
        @AuraEnabled public String  status;
        @AuraEnabled public Integer count;
        @AuraEnabled public Integer pct;
    }

    public class CountryStat {
        @AuraEnabled public String  country;
        @AuraEnabled public Integer count;
        @AuraEnabled public Integer pct;
    }

    public class OverdueItem {
        @AuraEnabled public String  recId;
        @AuraEnabled public String  name;
        @AuraEnabled public String  distributorName;
        @AuraEnabled public String  status;
        @AuraEnabled public String  submittedDate;
        @AuraEnabled public Integer daysPending;
    }

    // ── Main entry point ──────────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static DashboardData getDashboardData() {
        ElevatedQuery q = new ElevatedQuery();
        DashboardData d = new DashboardData();

        List<AggregateResult> activeByStatus = q.activeByStatus();

        d.kpi         = buildKpi(q, activeByStatus);
        d.byStatus    = buildByStatus(activeByStatus);
        d.byCountry   = buildByCountry(q);
        d.overdueList = buildOverdue(q);
        return d;
    }

    // ── Inner without-sharing query class (OWD = Private) ────────────────────

    private without sharing class ElevatedQuery {

        public List<AggregateResult> activeByStatus() {
            return [
                SELECT Status__c, COUNT(Id) cnt
                FROM   Registration_Request__c
                WHERE  Status__c IN :RA_ACTIVE
                GROUP BY Status__c
                ORDER BY COUNT(Id) DESC
            ];
        }

        public List<AggregateResult> activeByCountry() {
            return [
                SELECT Country__c, COUNT(Id) cnt
                FROM   Registration_Request__c
                WHERE  Status__c IN :RA_ACTIVE
                  AND  Country__c != null
                GROUP BY Country__c
                ORDER BY COUNT(Id) DESC
                LIMIT  10
            ];
        }

        public Integer cycleCount() {
            return [
                SELECT COUNT()
                FROM   Registration_Approval_History__c
                WHERE  To_Status__c = 'Additional Documents Requested'
                  AND  Registration_Request__r.Status__c IN :RA_ACTIVE
            ];
        }

        public Integer completedThisMonth() {
            Date startOfMonth = Date.today().toStartOfMonth();
            return [
                SELECT COUNT() FROM Registration_Request__c
                WHERE  Status__c = 'Completed'
                AND    LastModifiedDate >= :startOfMonth
            ];
        }

        public List<Registration_Request__c> recentCompleted() {
            return [
                SELECT Submitted_Date__c, LastModifiedDate
                FROM   Registration_Request__c
                WHERE  Status__c = 'Completed'
                AND    Submitted_Date__c != null
                ORDER BY LastModifiedDate DESC
                LIMIT  50
            ];
        }

        public List<Registration_Request__c> overdueRecords() {
            Datetime cutoff = Datetime.newInstance(
                Date.today().addDays(-14), Time.newInstance(23,59,59,0));
            return [
                SELECT Id, Name, Status__c, Country__c,
                       Submitted_Date__c, Account__r.Name
                FROM   Registration_Request__c
                WHERE  Status__c IN :RA_ACTIVE
                  AND  Submitted_Date__c <= :cutoff
                ORDER BY Submitted_Date__c ASC
                LIMIT  20
            ];
        }
    }

    // ── KPI builder ───────────────────────────────────────────────────────────

    private static KpiData buildKpi(ElevatedQuery q, List<AggregateResult> activeByStatus) {
        KpiData kpi = new KpiData();
        kpi.pendingCount              = 0;
        kpi.underReviewCount          = 0;
        kpi.pendingDistributorActions = 0;

        for (AggregateResult ar : activeByStatus) {
            String  s   = (String)  ar.get('Status__c');
            Integer cnt = (Integer) ar.get('cnt');
            if      (s == 'Submitted to Regulatory')       kpi.pendingCount              += cnt;
            else if (s == 'Under Regulatory Review')       kpi.underReviewCount          += cnt;
            else if (DISTRIBUTOR_PENDING.contains(s))      kpi.pendingDistributorActions += cnt;
        }

        kpi.cycleCount         = q.cycleCount();
        kpi.completedThisMonth = q.completedThisMonth();
        kpi.avgProcessingDays  = computeAvg(q);
        return kpi;
    }

    private static String computeAvg(ElevatedQuery q) {
        try {
            List<Registration_Request__c> completed = q.recentCompleted();
            if (completed.isEmpty()) return '—';
            Long    totalDays = 0;
            Integer cnt       = 0;
            for (Registration_Request__c r : completed) {
                if (r.Submitted_Date__c == null) continue;
                Long diff = (r.LastModifiedDate.getTime() - r.Submitted_Date__c.getTime())
                            / 86400000L;
                if (diff >= 0) { totalDays += diff; cnt++; }
            }
            if (cnt == 0) return '—';
            Long avg = totalDays / cnt;
            return avg + (avg == 1 ? ' day' : ' days');
        } catch (Exception e) {
            return '—';
        }
    }

    // ── Status breakdown ──────────────────────────────────────────────────────

    private static List<StatusCount> buildByStatus(List<AggregateResult> rows) {
        Integer total = 0;
        for (AggregateResult ar : rows) total += (Integer) ar.get('cnt');

        List<StatusCount> result = new List<StatusCount>();
        for (AggregateResult ar : rows) {
            StatusCount sc = new StatusCount();
            sc.status = (String)  ar.get('Status__c');
            sc.count  = (Integer) ar.get('cnt');
            sc.pct    = total > 0
                ? (Integer) Math.round((sc.count * 100.0) / total) : 0;
            result.add(sc);
        }
        return result;
    }

    // ── Country breakdown ─────────────────────────────────────────────────────

    private static List<CountryStat> buildByCountry(ElevatedQuery q) {
        List<AggregateResult> rows = q.activeByCountry();
        Integer maxCount = 1;
        for (AggregateResult ar : rows) {
            Integer c = (Integer) ar.get('cnt');
            if (c > maxCount) maxCount = c;
        }

        List<CountryStat> result = new List<CountryStat>();
        for (AggregateResult ar : rows) {
            CountryStat cs = new CountryStat();
            cs.country = (String)  ar.get('Country__c');
            cs.count   = (Integer) ar.get('cnt');
            cs.pct     = (Integer) Math.round((cs.count * 100.0) / maxCount);
            result.add(cs);
        }
        return result;
    }

    // ── Overdue requests ──────────────────────────────────────────────────────

    private static List<OverdueItem> buildOverdue(ElevatedQuery q) {
        Date today = Date.today();
        List<OverdueItem> result = new List<OverdueItem>();
        for (Registration_Request__c r : q.overdueRecords()) {
            OverdueItem oi     = new OverdueItem();
            oi.recId           = r.Id;
            oi.name            = r.Name;
            oi.distributorName = r.Account__r?.Name ?? '—';
            oi.status          = r.Status__c;
            oi.submittedDate   = r.Submitted_Date__c != null
                ? r.Submitted_Date__c.format('dd MMM yyyy') : '—';
            oi.daysPending     = r.Submitted_Date__c != null
                ? r.Submitted_Date__c.date().daysBetween(today) : 0;
            result.add(oi);
        }
        return result;
    }
}
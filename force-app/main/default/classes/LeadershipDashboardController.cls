/**
 * LeadershipDashboardController
 * Provides KPI, stage/country breakdowns, 6-month trends, and overdue
 * requests for the leadershipDashboard LWC.
 */
public with sharing class LeadershipDashboardController {

    // ── Status sets ───────────────────────────────────────────────────────────
    private static final Set<String> ACTIVE = new Set<String>{
        'Submitted', 'Under Leadership Review', 'Under Management Approval',
        'Sent Back', 'On Hold'
    };
    private static final Set<String> APPROVED_STATUSES = new Set<String>{
        'Approved by Leadership', 'Submitted to Regulatory',
        'Under Regulatory Review', 'Completed'
    };

    // ── Return types ──────────────────────────────────────────────────────────

    public class DashboardData {
        @AuraEnabled public KpiData           kpi;
        @AuraEnabled public List<StageCount>  byStage;
        @AuraEnabled public List<CountryCount>byCountry;
        @AuraEnabled public List<MonthTrend>  trends;
        @AuraEnabled public List<OverdueItem> overdueRequests;
    }

    public class KpiData {
        @AuraEnabled public Integer pendingApprovals;
        @AuraEnabled public Integer overdueCount;
        @AuraEnabled public String  avgTurnaroundDays;
        @AuraEnabled public Integer submittedThisMonth;
        @AuraEnabled public Integer approvedThisMonth;
        @AuraEnabled public Integer rejectedThisMonth;
    }

    public class StageCount {
        @AuraEnabled public String  status;
        @AuraEnabled public Integer count;
        @AuraEnabled public Integer pct;
    }

    public class CountryCount {
        @AuraEnabled public String  country;
        @AuraEnabled public Integer count;
        @AuraEnabled public Integer pct;
    }

    public class MonthTrend {
        @AuraEnabled public String  monthLabel;
        @AuraEnabled public Integer submitted;
        @AuraEnabled public Integer approved;
        @AuraEnabled public Integer submittedPct;
        @AuraEnabled public Integer approvedPct;
    }

    public class OverdueItem {
        @AuraEnabled public Id      id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  distributor;
        @AuraEnabled public String  country;
        @AuraEnabled public String  status;
        @AuraEnabled public String  submittedDate;
        @AuraEnabled public Integer daysPending;
    }

    // ── Main entry point ──────────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static DashboardData getDashboardData() {
        ElevatedQuery q   = new ElevatedQuery();
        DashboardData data = new DashboardData();

        data.kpi              = buildKpi(q);
        data.byStage          = buildByStage(q);
        data.byCountry        = buildByCountry(q);
        data.trends           = buildTrends(q);
        data.overdueRequests  = buildOverdue(q);

        return data;
    }

    // ── Inner without-sharing query class (OWD = Private) ────────────────────

    private without sharing class ElevatedQuery {

        public List<AggregateResult> activeByStatus() {
            return [
                SELECT Status__c, COUNT(Id) cnt
                FROM   Registration_Request__c
                WHERE  Status__c IN :ACTIVE
                GROUP BY Status__c
                ORDER BY COUNT(Id) DESC
            ];
        }

        public List<AggregateResult> activeByCountry() {
            return [
                SELECT Country__c, COUNT(Id) cnt
                FROM   Registration_Request__c
                WHERE  Status__c IN :ACTIVE
                  AND  Country__c != null
                GROUP BY Country__c
                ORDER BY COUNT(Id) DESC
                LIMIT  10
            ];
        }

        public List<AggregateResult> thisMonthByStatus() {
            Datetime startOfMonth = Datetime.newInstance(
                Date.today().toStartOfMonth(), Time.newInstance(0,0,0,0));
            return [
                SELECT Status__c, COUNT(Id) cnt
                FROM   Registration_Request__c
                WHERE  Submitted_Date__c >= :startOfMonth
                GROUP BY Status__c
            ];
        }

        public List<AggregateResult> submittedByMonth(Datetime since) {
            return [
                SELECT CALENDAR_YEAR(Submitted_Date__c) yr,
                       CALENDAR_MONTH(Submitted_Date__c) mo,
                       COUNT(Id) cnt
                FROM   Registration_Request__c
                WHERE  Submitted_Date__c >= :since
                GROUP BY CALENDAR_YEAR(Submitted_Date__c),
                         CALENDAR_MONTH(Submitted_Date__c)
                ORDER BY CALENDAR_YEAR(Submitted_Date__c),
                         CALENDAR_MONTH(Submitted_Date__c)
            ];
        }

        public List<AggregateResult> approvedByMonth(Datetime since) {
            return [
                SELECT CALENDAR_YEAR(Submitted_Date__c) yr,
                       CALENDAR_MONTH(Submitted_Date__c) mo,
                       COUNT(Id) cnt
                FROM   Registration_Request__c
                WHERE  Status__c IN :APPROVED_STATUSES
                  AND  Submitted_Date__c >= :since
                GROUP BY CALENDAR_YEAR(Submitted_Date__c),
                         CALENDAR_MONTH(Submitted_Date__c)
                ORDER BY CALENDAR_YEAR(Submitted_Date__c),
                         CALENDAR_MONTH(Submitted_Date__c)
            ];
        }

        public List<Registration_Request__c> overdueRecords() {
            Datetime cutoff = Datetime.newInstance(
                Date.today().addDays(-7), Time.newInstance(23,59,59,0));
            return [
                SELECT Id, Name, Status__c, Country__c,
                       Submitted_Date__c, Account__r.Name
                FROM   Registration_Request__c
                WHERE  Status__c IN :ACTIVE
                  AND  Submitted_Date__c <= :cutoff
                ORDER BY Submitted_Date__c ASC
                LIMIT  20
            ];
        }

        public List<Registration_Approval_History__c> approvalHistory(Datetime since) {
            return [
                SELECT Registration_Request__c, Performed_Date__c, To_Status__c
                FROM   Registration_Approval_History__c
                WHERE  To_Status__c IN :APPROVED_STATUSES
                  AND  Performed_Date__c >= :since
                ORDER BY Performed_Date__c ASC
                LIMIT  500
            ];
        }

        public List<Registration_Request__c> requestsById(Set<Id> ids) {
            return [
                SELECT Id, Submitted_Date__c
                FROM   Registration_Request__c
                WHERE  Id IN :ids
            ];
        }
    }

    // ── KPI Builder ───────────────────────────────────────────────────────────

    private static KpiData buildKpi(ElevatedQuery q) {
        KpiData kpi = new KpiData();

        // Pending count — sum all active statuses
        Integer pending = 0;
        for (AggregateResult ar : q.activeByStatus()) {
            pending += (Integer) ar.get('cnt');
        }
        kpi.pendingApprovals = pending;

        // Overdue count
        kpi.overdueCount = q.overdueRecords().size();

        // This-month counts
        kpi.submittedThisMonth = 0;
        kpi.approvedThisMonth  = 0;
        kpi.rejectedThisMonth  = 0;
        for (AggregateResult ar : q.thisMonthByStatus()) {
            String s   = (String)  ar.get('Status__c');
            Integer cnt = (Integer) ar.get('cnt');
            kpi.submittedThisMonth += cnt;                     // all statuses = submitted
            if (APPROVED_STATUSES.contains(s)) kpi.approvedThisMonth  += cnt;
            if (s == 'Rejected')               kpi.rejectedThisMonth  += cnt;
        }

        // Avg turnaround (last 6 months)
        kpi.avgTurnaroundDays = computeAvgTurnaround(q);

        return kpi;
    }

    private static String computeAvgTurnaround(ElevatedQuery q) {
        try {
            Datetime since = Datetime.newInstance(
                Date.today().addMonths(-6).toStartOfMonth(),
                Time.newInstance(0,0,0,0));
            List<Registration_Approval_History__c> hist = q.approvalHistory(since);
            if (hist.isEmpty()) return '—';

            Set<Id> ids = new Set<Id>();
            for (Registration_Approval_History__c h : hist) ids.add(h.Registration_Request__c);

            Map<Id, Registration_Request__c> reqMap =
                new Map<Id, Registration_Request__c>(q.requestsById(ids));

            Long totalDays = 0;
            Integer count  = 0;
            Set<Id> seen   = new Set<Id>();

            for (Registration_Approval_History__c h : hist) {
                if (seen.contains(h.Registration_Request__c)) continue;
                Registration_Request__c rr = reqMap.get(h.Registration_Request__c);
                if (rr == null || rr.Submitted_Date__c == null || h.Performed_Date__c == null)
                    continue;
                Long diffDays =
                    (h.Performed_Date__c.getTime() - rr.Submitted_Date__c.getTime())
                    / 86400000L;
                if (diffDays >= 0) {
                    totalDays += diffDays;
                    count++;
                    seen.add(h.Registration_Request__c);
                }
            }
            if (count == 0) return '—';
            Long avg = totalDays / count;
            return avg + (avg == 1 ? ' day' : ' days');
        } catch (Exception e) {
            return '—';
        }
    }

    // ── Stage breakdown ───────────────────────────────────────────────────────

    private static List<StageCount> buildByStage(ElevatedQuery q) {
        List<AggregateResult> rows = q.activeByStatus();
        Integer total = 0;
        for (AggregateResult ar : rows) total += (Integer) ar.get('cnt');

        List<StageCount> result = new List<StageCount>();
        for (AggregateResult ar : rows) {
            StageCount s = new StageCount();
            s.status = (String)  ar.get('Status__c');
            s.count  = (Integer) ar.get('cnt');
            s.pct    = total > 0
                ? (Integer) Math.round((s.count * 100.0) / total) : 0;
            result.add(s);
        }
        return result;
    }

    // ── Country breakdown ─────────────────────────────────────────────────────

    private static List<CountryCount> buildByCountry(ElevatedQuery q) {
        List<AggregateResult> rows = q.activeByCountry();
        Integer maxCount = 1;
        for (AggregateResult ar : rows) {
            Integer c = (Integer) ar.get('cnt');
            if (c > maxCount) maxCount = c;
        }

        List<CountryCount> result = new List<CountryCount>();
        for (AggregateResult ar : rows) {
            CountryCount cc = new CountryCount();
            cc.country = (String)  ar.get('Country__c');
            cc.count   = (Integer) ar.get('cnt');
            cc.pct     = (Integer) Math.round((cc.count * 100.0) / maxCount);
            result.add(cc);
        }
        return result;
    }

    // ── 6-month trends ────────────────────────────────────────────────────────

    private static List<MonthTrend> buildTrends(ElevatedQuery q) {
        Datetime since = Datetime.newInstance(
            Date.today().addMonths(-5).toStartOfMonth(),
            Time.newInstance(0,0,0,0));

        // Build 6 ordered month slots
        String[] MONTHS = new String[]{
            'Jan','Feb','Mar','Apr','May','Jun',
            'Jul','Aug','Sep','Oct','Nov','Dec'};
        List<String>              orderedKeys = new List<String>();
        Map<String, MonthTrend>   slots       = new Map<String, MonthTrend>();

        Date cursor = Date.today().addMonths(-5).toStartOfMonth();
        for (Integer i = 0; i < 6; i++) {
            String key = String.valueOf(cursor.year()) + '-'
                       + String.valueOf(cursor.month());
            MonthTrend mt   = new MonthTrend();
            mt.monthLabel   = MONTHS[cursor.month() - 1] + ' \''
                            + String.valueOf(cursor.year()).substring(2);
            mt.submitted    = 0;
            mt.approved     = 0;
            mt.submittedPct = 0;
            mt.approvedPct  = 0;
            slots.put(key, mt);
            orderedKeys.add(key);
            cursor = cursor.addMonths(1);
        }

        // Fill from queries
        for (AggregateResult ar : q.submittedByMonth(since)) {
            String key = String.valueOf(ar.get('yr')) + '-'
                       + String.valueOf(ar.get('mo'));
            if (slots.containsKey(key))
                slots.get(key).submitted = (Integer) ar.get('cnt');
        }
        for (AggregateResult ar : q.approvedByMonth(since)) {
            String key = String.valueOf(ar.get('yr')) + '-'
                       + String.valueOf(ar.get('mo'));
            if (slots.containsKey(key))
                slots.get(key).approved = (Integer) ar.get('cnt');
        }

        // Compute percentages for bar scaling
        Integer maxVal = 1;
        for (String k : orderedKeys) {
            MonthTrend mt = slots.get(k);
            if (mt.submitted > maxVal) maxVal = mt.submitted;
            if (mt.approved  > maxVal) maxVal = mt.approved;
        }
        for (String k : orderedKeys) {
            MonthTrend mt   = slots.get(k);
            mt.submittedPct = (Integer) Math.round((mt.submitted * 100.0) / maxVal);
            mt.approvedPct  = (Integer) Math.round((mt.approved  * 100.0) / maxVal);
        }

        List<MonthTrend> result = new List<MonthTrend>();
        for (String k : orderedKeys) result.add(slots.get(k));
        return result;
    }

    // ── Overdue requests ──────────────────────────────────────────────────────

    private static List<OverdueItem> buildOverdue(ElevatedQuery q) {
        Date today = Date.today();
        List<OverdueItem> result = new List<OverdueItem>();
        for (Registration_Request__c r : q.overdueRecords()) {
            OverdueItem oi    = new OverdueItem();
            oi.id             = r.Id;
            oi.name           = r.Name;
            oi.distributor    = r.Account__r?.Name ?? '—';
            oi.country        = r.Country__c ?? '—';
            oi.status         = r.Status__c;
            oi.submittedDate  = r.Submitted_Date__c != null
                ? r.Submitted_Date__c.format('dd MMM yyyy') : '—';
            oi.daysPending    = r.Submitted_Date__c != null
                ? r.Submitted_Date__c.date().daysBetween(today) : 0;
            result.add(oi);
        }
        return result;
    }
}
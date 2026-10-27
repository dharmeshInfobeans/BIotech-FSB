/**
 * RegistrationApprovalHistoryController
 * Serves approval history entries and computed duration stats to
 * the approvalHistoryTimeline LWC.
 */
public with sharing class RegistrationApprovalHistoryController {

    // ── Return types ──────────────────────────────────────────────────────────

    public class HistoryEntry {
        @AuraEnabled public String  entryId;
        @AuraEnabled public Integer entryIndex;
        @AuraEnabled public String  action;
        @AuraEnabled public String  stage;
        @AuraEnabled public String  fromStatus;
        @AuraEnabled public String  toStatus;
        @AuraEnabled public String  comments;
        @AuraEnabled public String  performedByName;
        @AuraEnabled public String  performedDate;      // ISO string for JS
        @AuraEnabled public String  performedDateLabel; // formatted display
        @AuraEnabled public String  dotClass;           // CSS class for timeline dot
        @AuraEnabled public String  durationLabel;      // time waited before this action
        @AuraEnabled public Long    durationMinutes;    // raw minutes for sorting/math
    }

    public class DurationStats {
        @AuraEnabled public Integer totalActions;
        @AuraEnabled public String  totalElapsed;       // e.g. "4d 6h"
        @AuraEnabled public String  pendingDuration;    // time since last action
        @AuraEnabled public String  avgPerStage;        // average time between actions
    }

    public class HistoryResult {
        @AuraEnabled public List<HistoryEntry> entries;
        @AuraEnabled public DurationStats      stats;
    }

    // ── Main query ────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static HistoryResult getHistory(Id recordId) {
        List<Registration_Approval_History__c> rows =
            new ElevatedQuery().fetch(recordId);

        HistoryResult result  = new HistoryResult();
        result.entries        = buildEntries(rows);
        result.stats          = buildStats(result.entries);
        return result;
    }

    // ── Inner without-sharing class (OWD is Private) ─────────────────────────

    private without sharing class ElevatedQuery {
        public List<Registration_Approval_History__c> fetch(Id requestId) {
            return [
                SELECT Id, Action__c, Stage__c, From_Status__c, To_Status__c,
                       Comments__c, Performed_By_Name__c, Performed_Date__c
                FROM   Registration_Approval_History__c
                WHERE  Registration_Request__c = :requestId
                ORDER BY Performed_Date__c ASC
                LIMIT  200
            ];
        }
    }

    // ── Build entry list with duration between consecutive actions ────────────

    private static List<HistoryEntry> buildEntries(
        List<Registration_Approval_History__c> rows
    ) {
        List<HistoryEntry> entries = new List<HistoryEntry>();
        Datetime prev = null;

        for (Integer i = 0; i < rows.size(); i++) {
            Registration_Approval_History__c r = rows[i];
            HistoryEntry e = new HistoryEntry();
            e.entryId           = r.Id;
            e.entryIndex        = i + 1;
            e.action            = r.Action__c;
            e.stage             = r.Stage__c;
            e.fromStatus        = r.From_Status__c;
            e.toStatus          = r.To_Status__c;
            e.comments          = r.Comments__c;
            e.performedByName   = String.isBlank(r.Performed_By_Name__c)
                                    ? 'Unknown' : r.Performed_By_Name__c;
            e.performedDate     = r.Performed_Date__c != null
                                    ? String.valueOf(r.Performed_Date__c) : '';
            e.performedDateLabel = r.Performed_Date__c != null
                                    ? formatDatetime(r.Performed_Date__c) : '';
            e.dotClass          = dotClassFor(r.Action__c);

            // Duration since previous entry
            if (prev != null && r.Performed_Date__c != null) {
                Long mins = prev.getTime() == null ? 0L
                    : (r.Performed_Date__c.getTime() - prev.getTime()) / 60000L;
                e.durationMinutes = mins;
                e.durationLabel   = 'Waited ' + formatMinutes(mins);
            } else {
                e.durationMinutes = 0L;
                e.durationLabel   = '';
            }

            prev = r.Performed_Date__c;
            entries.add(e);
        }
        return entries;
    }

    // ── Build summary stats ───────────────────────────────────────────────────

    private static DurationStats buildStats(List<HistoryEntry> entries) {
        DurationStats s = new DurationStats();
        s.totalActions = entries.size();

        if (entries.isEmpty()) {
            s.totalElapsed   = '—';
            s.pendingDuration = '—';
            s.avgPerStage    = '—';
            return s;
        }

        // Total elapsed: first action → last action
        Long totalMins = 0L;
        for (HistoryEntry e : entries) {
            totalMins += e.durationMinutes;
        }
        s.totalElapsed = formatMinutes(totalMins);

        // Pending duration: time since last action
        HistoryEntry last = entries[entries.size() - 1];
        if (String.isNotBlank(last.performedDate)) {
            try {
                Datetime lastDt  = Datetime.valueOf(last.performedDate.replace('T', ' '));
                Long pendMins    = (Datetime.now().getTime() - lastDt.getTime()) / 60000L;
                s.pendingDuration = formatMinutes(pendMins);
            } catch (Exception ex) {
                s.pendingDuration = '—';
            }
        } else {
            s.pendingDuration = '—';
        }

        // Average per stage (exclude first entry which has no wait)
        Integer countWithDuration = 0;
        Long sumDuration = 0L;
        for (HistoryEntry e : entries) {
            if (e.durationMinutes > 0) {
                sumDuration += e.durationMinutes;
                countWithDuration++;
            }
        }
        s.avgPerStage = countWithDuration > 0
            ? formatMinutes(sumDuration / countWithDuration) : '—';

        return s;
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static String formatMinutes(Long mins) {
        if (mins == null || mins <= 0) return '< 1 min';
        Long days = mins / 1440;
        Long hrs  = Math.mod(mins, 1440) / 60;
        Long m    = Math.mod(mins, 60);
        String result = '';
        if (days > 0) result += days + 'd ';
        if (hrs  > 0) result += hrs  + 'h ';
        if (m    > 0 && days == 0) result += m + 'm';
        return result.trim();
    }

    private static String formatDatetime(Datetime dt) {
        return dt.format('dd MMM yyyy HH:mm');
    }

    private static String dotClassFor(String action) {
        if (action == null) return 'dot-neutral';
        String a = action.toLowerCase();
        if (a.contains('reject'))           return 'dot-rejected';
        if (a.contains('sent back'))        return 'dot-sent-back';
        if (a.contains('resumed'))          return 'dot-resumed';
        if (a.contains('on hold'))          return 'dot-hold';
        if (a.contains('approved') || a.contains('final approval') || a.contains('granted'))
                                            return 'dot-approved';
        if (a.contains('regulatory'))       return 'dot-regulatory';
        return 'dot-forwarded';
    }
}
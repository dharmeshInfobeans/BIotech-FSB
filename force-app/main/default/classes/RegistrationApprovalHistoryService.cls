/**
 * RegistrationApprovalHistoryService
 * Logs every approval action on a Registration Request for compliance audit
 * and duration reporting.  Non-fatal: a logging failure never blocks workflow.
 *
 * Also stamps review-phase timestamp fields on Registration_Request__c
 * whenever the status transitions through tracked boundaries.
 */
public with sharing class RegistrationApprovalHistoryService {

    private static final Set<String> LEADERSHIP_STATUSES = new Set<String>{
        'Under Leadership Review', 'Under Management Approval'
    };

    /**
     * Log a single approval action.
     *
     * @param requestId  Registration_Request__c record Id
     * @param action     Human-readable action label  e.g. 'Forwarded to Leadership'
     * @param fromStatus Status before the action
     * @param toStatus   Status after the action
     * @param comments   Rejection/send-back reason (may be null)
     * @param stage      Workflow stage label  e.g. 'CRM Review'
     */
    public static void log(
        Id     requestId,
        String action,
        String fromStatus,
        String toStatus,
        String comments,
        String stage
    ) {
        try {
            String performedByName = resolveUserName(UserInfo.getUserId());

            insert new Registration_Approval_History__c(
                Registration_Request__c = requestId,
                Action__c               = action,
                From_Status__c          = fromStatus,
                To_Status__c            = toStatus,
                Comments__c             = String.isBlank(comments) ? null : comments.trim(),
                Performed_By__c         = UserInfo.getUserId(),
                Performed_By_Name__c    = performedByName,
                Performed_Date__c       = Datetime.now(),
                Stage__c                = stage
            );

            stampTimestamps(requestId, fromStatus, toStatus);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'RegistrationApprovalHistoryService.log failed: ' + e.getMessage());
        }
    }

    // ── Timestamp stamping ───────────────────────────────────────────────────

    private static void stampTimestamps(Id requestId, String fromStatus, String toStatus) {
        if (requestId == null) return;

        Registration_Request__c upd = new Registration_Request__c(Id = requestId);
        Boolean needsUpdate = false;
        Datetime now = Datetime.now();

        upd.Last_Stage_Change_Date__c = now;
        needsUpdate = true;

        if (toStatus == 'Under Leadership Review'
            && (fromStatus == null || !LEADERSHIP_STATUSES.contains(fromStatus))) {
            upd.Leadership_Review_Start__c = now;
            needsUpdate = true;
        }

        if (fromStatus != null && LEADERSHIP_STATUSES.contains(fromStatus)
            && !LEADERSHIP_STATUSES.contains(toStatus)) {
            upd.Leadership_Review_End__c = now;
            needsUpdate = true;
        }

        if (toStatus == 'Under Regulatory Review'
            && fromStatus != 'Under Regulatory Review') {
            upd.Regulatory_Review_Start__c = now;
            needsUpdate = true;
        }

        if (fromStatus == 'Under Regulatory Review'
            && toStatus != 'Under Regulatory Review') {
            upd.Regulatory_Review_End__c = now;
            needsUpdate = true;
        }

        if (toStatus == 'Completed') {
            upd.Completed_Date__c = now;
            needsUpdate = true;
        }

        if (needsUpdate) {
            new TimestampWriter().doUpdate(upd);
        }
    }

    private without sharing class TimestampWriter {
        void doUpdate(Registration_Request__c rec) {
            update rec;
        }
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private static String resolveUserName(Id userId) {
        try {
            return [SELECT Name FROM User WHERE Id = :userId LIMIT 1].Name;
        } catch (Exception e) {
            return 'Unknown';
        }
    }
}
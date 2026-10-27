public with sharing class RegistrationNotificationService {

    // ── Invocable input ────────────────────────────────────────────────────────
    public class NotifyInput {
        @InvocableVariable(required=true  label='Registration Request Id')
        public Id     requestId;

        @InvocableVariable(required=true  label='Notification Type')
        public String notificationType;
        // Accepted values:
        //   SUBMITTED            — distributor submits; notifies Leadership + RA Team + Distributor + RSM + CRM
        //   LEADERSHIP_REVIEW    — CRM forwards; notifies Leadership only
        //   MANAGEMENT_REVIEW    — Leadership approves stage 1; notifies Leadership only
        //   APPROVED             — Management final approval; notifies Distributor + CRM
        //   SUBMITTED_TO_REGULATORY — Leadership submits to RA; notifies RA Team + Distributor + RSM + CRM
        //   REJECTED             — any rejection; notifies Distributor + CRM
        //   SENT_BACK                  — sent back to distributor; notifies Distributor + CRM
        //   ADDITIONAL_DOCS_REQUESTED  — RA needs more docs; notifies Distributor + CRM
        //   COMPLETED                  — RA team completes; notifies Distributor + CRM + Leadership + RSM
        //   CERTIFICATE_UPLOADED            — distributor uploads cert; notifies RA Team
        //   CERTIFICATE_FORWARDED_TO_CRM    — RA forwards to CRM; notifies CRM
        //   CERTIFICATE_VERIFIED            — CRM verifies cert; notifies RA + Distributor
        //   CERTIFICATE_REJECTED            — CRM rejects cert; notifies RA + Distributor
        //   PRODUCT_ORDER_UNLOCKED          — RA unlocks order; notifies Distributor
        //   ORDER_UNLOCKED_BY_RA            — RA unlocks directly (bypass CRM); notifies CRM
    }

    @InvocableMethod(
        label='Send Registration Notification'
        description='Sends email + bell notifications, assigns record owner, and creates audit task for Registration_Request__c status changes.'
        callout=false
    )
    public static void sendNotification(List<NotifyInput> inputs) {
        for (NotifyInput inp : inputs) {
            try {
                processNotification(inp.requestId, inp.notificationType);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'RegistrationNotificationService [' + inp.notificationType + '] error: ' + e.getMessage());
            }
        }
    }

    // ── Direct Apex-to-Apex entry point (cannot call @InvocableMethod from Apex) ─
    // Dispatches to @future so the User queries run in system mode, bypassing
    // User Sharing restrictions that block portal users from seeing internal users.
    public static void notifyFromApex(Id requestId, String notificationType) {
        try {
            notifyAsync(String.valueOf(requestId), notificationType);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'RegistrationNotificationService.notifyFromApex error: ' + e.getMessage());
        }
    }

    @future
    private static void notifyAsync(String requestId, String notificationType) {
        try {
            processNotification(requestId, notificationType);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'RegistrationNotificationService.notifyAsync error: ' + e.getMessage());
        }
    }

    // ── Core dispatch ──────────────────────────────────────────────────────────
    private static void processNotification(Id requestId, String notificationType) {

        ElevatedQuery eq = new ElevatedQuery();
        Registration_Request__c rr = eq.getRequest(requestId);
        List<User> leaders  = eq.getLeadershipUsers();
        List<User> raTeam   = eq.getRATeamUsers();
        List<User> fhUsers  = eq.getFunctionalHeadUsers();
        List<User> cmdUsers = eq.getCMDUsers();

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        String auditNote;

        if (notificationType == 'SUBMITTED') {
            // Leadership — email + bell
            for (User u : leaders) {
                if (String.isNotBlank(u.Email)) {
                    emails.add(buildEmail(u.Email,
                        'New Registration Request Submitted — ' + rr.Name,
                        buildLeadershipSubmittedBody(rr)));
                }
            }

            // Assign owner to CRM
            if (rr.Account__r?.CRM__c != null) {
                assignOwner(requestId, rr.Account__r.CRM__c);
            }

            // Bell — Leadership
            sendBellNotification(
                toIdSet(leaders),
                'New Registration Request',
                rr.Name + ' submitted by ' + safeName(rr.Account__r?.Name),
                requestId, leadershipPageRef(requestId));

            // Bell — RA Team (awareness only, no email)
            if (!raTeam.isEmpty()) {
                sendBellNotification(
                    toIdSet(raTeam),
                    'New Registration Request',
                    rr.Name + ' submitted — pending Leadership approval before RA processing.',
                    requestId, raPageRef(requestId));
            }

            // Bell — Distributor (confirmation only, no email)
            if (rr.Requested_By__c != null) {
                sendBellNotification(
                    new Set<String>{ rr.Requested_By__c },
                    'Request Submitted: ' + rr.Name,
                    'Your registration request has been submitted and is under review.',
                    requestId, distributorPageRef(requestId));
            }

            auditNote = 'Status changed to Submitted. Leadership notified via email and bell. RA Team and Distributor notified via bell.';

        } else if (notificationType == 'LEADERSHIP_REVIEW') {
            for (User u : leaders) {
                if (String.isNotBlank(u.Email)) {
                    emails.add(buildEmail(u.Email,
                        'Registration Request Pending Your Review — ' + rr.Name,
                        buildLeadershipReviewBody(rr)));
                }
            }
            sendBellNotification(
                toIdSet(leaders),
                'Approval Required: ' + rr.Name,
                'Request from ' + safeName(rr.Account__r?.Name) + ' is awaiting your approval.',
                requestId, leadershipPageRef(requestId));
            auditNote = 'Forwarded to Leadership for review. Leadership team notified via email and bell.';

        } else if (notificationType == 'APPROVED') {
            if (String.isNotBlank(rr.Requested_By__r?.Email)) {
                emails.add(buildEmail(
                    rr.Requested_By__r.Email,
                    'Your Registration Request Has Been Approved — ' + rr.Name,
                    buildDistributorApprovedBody(rr)));
            }
            if (String.isNotBlank(rr.Account__r?.CRM_Email__c)) {
                emails.add(buildEmail(
                    rr.Account__r.CRM_Email__c,
                    'Registration Request Approved — ' + rr.Name,
                    buildCRMApprovedBody(rr)));
            }
            if (rr.Requested_By__c != null) {
                sendBellNotification(
                    new Set<String>{ rr.Requested_By__c },
                    'Request Approved: ' + rr.Name,
                    'Your registration request has been approved. Regulatory team will now begin processing.',
                    requestId, distributorPageRef(requestId));
            }
            auditNote = 'Approved by Leadership. Stage moved to Regulatory Processing. Distributor and CRM notified.';

        } else if (notificationType == 'REJECTED') {
            if (String.isNotBlank(rr.Requested_By__r?.Email)) {
                emails.add(buildEmail(
                    rr.Requested_By__r.Email,
                    'Your Registration Request Has Been Rejected — ' + rr.Name,
                    buildDistributorRejectedBody(rr)));
            }
            if (String.isNotBlank(rr.Account__r?.CRM_Email__c)) {
                emails.add(buildEmail(
                    rr.Account__r.CRM_Email__c,
                    'Registration Request Rejected — ' + rr.Name,
                    buildCRMRejectedBody(rr)));
            }
            if (rr.Requested_By__c != null) {
                sendBellNotification(
                    new Set<String>{ rr.Requested_By__c },
                    'Request Rejected: ' + rr.Name,
                    'Your registration request has been rejected. Please contact your CRM for details.',
                    requestId, distributorPageRef(requestId));
            }
            auditNote = 'Rejected. Reason: '
                + (String.isNotBlank(rr.Rejection_Comments__c) ? rr.Rejection_Comments__c : 'N/A')
                + '. Distributor and CRM notified.';

        } else if (notificationType == 'MANAGEMENT_REVIEW') {
            for (User u : leaders) {
                if (String.isNotBlank(u.Email)) {
                    emails.add(buildEmail(u.Email,
                        'Registration Request Awaiting Management Approval — ' + rr.Name,
                        buildManagementReviewBody(rr)));
                }
            }
            sendBellNotification(
                toIdSet(leaders),
                'Management Approval Required: ' + rr.Name,
                'Leadership has reviewed. Final management approval needed for '
                    + safeName(rr.Account__r?.Name) + '.',
                requestId, leadershipPageRef(requestId));
            auditNote = 'Forwarded to Management for final approval. Leadership team notified.';

        } else if (notificationType == 'SUBMITTED_TO_REGULATORY') {
            List<String> raCC = new List<String>();
            if (String.isNotBlank(rr.Account__r?.CRM_Email__c)) raCC.add(rr.Account__r.CRM_Email__c);
            if (String.isNotBlank(rr.Account__r?.RSM_Email__c)) raCC.add(rr.Account__r.RSM_Email__c);
            // RA Team — email + bell
            for (User u : raTeam) {
                if (String.isNotBlank(u.Email)) {
                    emails.add(buildEmail(u.Email,
                        'Registration Request Ready for Regulatory Processing — ' + rr.Name,
                        buildRATeamRegulatoryBody(rr), raCC));
                }
            }
            if (!raTeam.isEmpty()) {
                sendBellNotification(
                    toIdSet(raTeam),
                    'Action Required: ' + rr.Name,
                    'Registration request from ' + safeName(rr.Account__r?.Name)
                        + ' is ready for regulatory processing.',
                    requestId, raPageRef(requestId));
            }
            // Bell — Distributor
            if (rr.Requested_By__c != null) {
                sendBellNotification(
                    new Set<String>{ rr.Requested_By__c },
                    'Request Submitted to Regulatory: ' + rr.Name,
                    'Your registration request has been approved and submitted to the Regulatory team.',
                    requestId, distributorPageRef(requestId));
            }
            auditNote = 'Submitted to Regulatory team. RA Team notified via email and bell. Distributor notified via bell.';

        } else if (notificationType == 'SENT_BACK') {
            // ADR child records: fall back to parent's Requested_By__c for the distributor
            Id sentBackDistId = rr.Requested_By__c != null
                ? rr.Requested_By__c
                : rr.Parent_Request__r?.Requested_By__c;
            if (String.isNotBlank(rr.Requested_By__r?.Email)) {
                emails.add(buildEmail(
                    rr.Requested_By__r.Email,
                    'Your Registration Request Has Been Sent Back — ' + rr.Name,
                    buildDistributorSentBackBody(rr)));
            }
            if (String.isNotBlank(rr.Account__r?.CRM_Email__c)) {
                emails.add(buildEmail(
                    rr.Account__r.CRM_Email__c,
                    'Registration Request Sent Back to Distributor — ' + rr.Name,
                    buildCRMSentBackBody(rr)));
            }
            if (sentBackDistId != null) {
                sendBellNotification(
                    new Set<String>{ sentBackDistId },
                    'Request Sent Back: ' + rr.Name,
                    'Your registration request has been sent back. Please review comments and resubmit.',
                    requestId, distributorPageRef(requestId));
            }
            auditNote = 'Request sent back to distributor. Distributor and CRM notified.';

        } else if (notificationType == 'ADDITIONAL_DOCS_REQUESTED') {
            // Distributor — inform them to provide more docs
            if (String.isNotBlank(rr.Requested_By__r?.Email)) {
                emails.add(buildEmail(
                    rr.Requested_By__r.Email,
                    'Additional Documents Required — ' + rr.Name,
                    buildDistributorAdditionalDocsBody(rr)));
            }
            // CRM — visibility
            if (String.isNotBlank(rr.Account__r?.CRM_Email__c)) {
                emails.add(buildEmail(
                    rr.Account__r.CRM_Email__c,
                    'Additional Documents Requested — ' + rr.Name,
                    buildCRMAdditionalDocsBody(rr)));
            }
            // RSM — visibility
            if (String.isNotBlank(rr.Account__r?.RSM_Email__c)) {
                emails.add(buildEmail(
                    rr.Account__r.RSM_Email__c,
                    'Additional Documents Requested — ' + rr.Name,
                    buildCRMAdditionalDocsBody(rr)));
            }
            // Bell — Distributor
            if (rr.Requested_By__c != null) {
                sendBellNotification(
                    new Set<String>{ rr.Requested_By__c },
                    'Action Required: ' + rr.Name,
                    'The Regulatory team requires additional documents for your registration request.',
                    requestId, distributorPageRef(requestId));
            }
            auditNote = 'Additional documents requested from distributor. Distributor, CRM, and RSM notified.';

        } else if (notificationType == 'ADDITIONAL_DOCS_REQUESTED_BY_DISTRIBUTOR') {
            List<String> distReqCcList = new List<String>();
            if (String.isNotBlank(rr.Account__r?.CRM_Email__c)) distReqCcList.add(rr.Account__r.CRM_Email__c);
            if (String.isNotBlank(rr.Account__r?.RSM_Email__c)) distReqCcList.add(rr.Account__r.RSM_Email__c);
            // RA Team — email + bell (CRM + RSM in CC)
            for (User u : raTeam) {
                if (String.isNotBlank(u.Email)) {
                    emails.add(buildEmail(u.Email,
                        'Additional Document Request Submitted — ' + rr.Name,
                        buildRAAdditionalDocsRequestedBody(rr), distReqCcList));
                }
            }
            if (!raTeam.isEmpty()) {
                sendBellNotification(
                    toIdSet(raTeam),
                    'Additional Document Request: ' + rr.Name,
                    safeName(rr.Account__r?.Name) + ' has submitted an additional document request.',
                    requestId, raPageRef(requestId));
            }
            // Bell — Distributor (confirmation); ADR child records use parent's Requested_By__c
            Id distUserId = rr.Requested_By__c != null
                ? rr.Requested_By__c
                : rr.Parent_Request__r?.Requested_By__c;
            if (distUserId != null) {
                sendBellNotification(
                    new Set<String>{ distUserId },
                    'Request Resubmitted: ' + rr.Name,
                    'Your additional document request has been resubmitted to the Regulatory Team.',
                    requestId, distributorPageRef(requestId));
            }
            auditNote = 'Additional document request submitted by distributor. RA Team notified via email and bell. CRM and RSM in CC.';

        } else if (notificationType == 'COMPLETED') {
            // Distributor — email + bell (CRM + RSM in CC)
            List<String> completedCcList = new List<String>();
            if (String.isNotBlank(rr.Account__r?.CRM_Email__c)) completedCcList.add(rr.Account__r.CRM_Email__c);
            if (String.isNotBlank(rr.Account__r?.RSM_Email__c)) completedCcList.add(rr.Account__r.RSM_Email__c);
            if (String.isNotBlank(rr.Requested_By__r?.Email)) {
                emails.add(buildEmail(
                    rr.Requested_By__r.Email,
                    'Your Registration Request is Complete — ' + rr.Name,
                    buildDistributorCompletedBody(rr), completedCcList));
            }
            if (rr.Requested_By__c != null) {
                sendBellNotification(
                    new Set<String>{ rr.Requested_By__c },
                    'Request Completed: ' + rr.Name,
                    'Your registration request has been completed. Documents are now available on the portal.',
                    requestId, distributorPageRef(requestId));
            }

            // Bell — Leadership
            if (!leaders.isEmpty()) {
                sendBellNotification(
                    toIdSet(leaders),
                    'Request Completed: ' + rr.Name,
                    safeName(rr.Account__r?.Name) + ' — registration request has been completed by the Regulatory team.',
                    requestId, leadershipPageRef(requestId));
            }

            // Bell — RA Team
            if (!raTeam.isEmpty()) {
                sendBellNotification(
                    toIdSet(raTeam),
                    'Request Completed: ' + rr.Name,
                    rr.Name + ' has been marked as completed.',
                    requestId, raPageRef(requestId));
            }

            auditNote = 'Request completed. Distributor notified via email and bell. Leadership and RA Team notified via bell.';

        } else if (notificationType == 'FUNCTIONAL_HEAD_REVIEW') {
            List<String> ccList = new List<String>();
            for (User u : raTeam) {
                if (String.isNotBlank(u.Email)) ccList.add(u.Email);
            }
            if (String.isNotBlank(rr.Account__r?.CRM_Email__c)) ccList.add(rr.Account__r.CRM_Email__c);
            for (User u : fhUsers) {
                if (String.isNotBlank(u.Email)) {
                    emails.add(buildEmail(u.Email,
                        'New Registration Request for Review — ' + rr.Name,
                        buildFHReviewBody(rr), ccList));
                }
            }
            if (!fhUsers.isEmpty()) {
                sendBellNotification(
                    toIdSet(fhUsers),
                    'New Request for Your Review',
                    rr.Name + ' submitted by ' + safeName(rr.Account__r?.Name),
                    requestId, fhPageRef(requestId));
            }
            auditNote = 'Submitted by Distributor. Functional Head users notified. RA Team and CRM in CC.';

        } else if (notificationType == 'CERTIFICATE_UPLOADED') {
            List<String> certUploadCcList = new List<String>();
            if (String.isNotBlank(rr.Account__r?.CRM_Email__c)) certUploadCcList.add(rr.Account__r.CRM_Email__c);
            if (String.isNotBlank(rr.Account__r?.RSM_Email__c)) certUploadCcList.add(rr.Account__r.RSM_Email__c);
            for (User u : raTeam) {
                if (String.isNotBlank(u.Email)) {
                    emails.add(buildEmail(u.Email,
                        'Registration Certificate Uploaded — ' + rr.Name,
                        buildCertUploadedBody(rr), certUploadCcList));
                }
            }
            if (!raTeam.isEmpty()) {
                sendBellNotification(
                    toIdSet(raTeam),
                    'Certificate Uploaded: ' + rr.Name,
                    safeName(rr.Account__r?.Name) + ' has uploaded registration certificate(s). Please review.',
                    requestId, raPageRef(requestId));
            }
            auditNote = 'Registration certificate uploaded by distributor. RA Team notified via email and bell. CRM and RSM in CC.';

        } else if (notificationType == 'CERTIFICATE_FORWARDED_TO_CRM') {
            if (String.isNotBlank(rr.Account__r?.CRM_Email__c)) {
                emails.add(buildEmail(
                    rr.Account__r.CRM_Email__c,
                    'Certificate Verification Required — ' + rr.Name,
                    buildCertForwardedToCRMBody(rr)));
            }
            if (rr.Account__r?.CRM__c != null) {
                sendBellNotification(
                    new Set<String>{ rr.Account__r.CRM__c },
                    'Certificate Review Required: ' + rr.Name,
                    'Registration certificates from ' + safeName(rr.Account__r?.Name) + ' need your verification.',
                    requestId, crmCertDetailPageRef(requestId));
            }
            auditNote = 'Certificates forwarded to CRM for verification. CRM notified via email and bell.';

        } else if (notificationType == 'CERTIFICATE_VERIFIED') {
            for (User u : raTeam) {
                if (String.isNotBlank(u.Email)) {
                    emails.add(buildEmail(u.Email,
                        'Certificate Verified by CRM — ' + rr.Name,
                        buildCertVerifiedRABody(rr)));
                }
            }
            if (String.isNotBlank(rr.Requested_By__r?.Email)) {
                emails.add(buildEmail(
                    rr.Requested_By__r.Email,
                    'Your Certificate Has Been Verified — ' + rr.Name,
                    buildCertVerifiedDistributorBody(rr)));
            }
            if (!raTeam.isEmpty()) {
                sendBellNotification(
                    toIdSet(raTeam),
                    'Certificate Verified: ' + rr.Name,
                    'CRM has verified the certificate for ' + safeName(rr.Account__r?.Name) + '.',
                    requestId, raPageRef(requestId));
            }
            if (rr.Requested_By__c != null) {
                sendBellNotification(
                    new Set<String>{ rr.Requested_By__c },
                    'Certificate Verified: ' + rr.Name,
                    'Your registration certificate has been verified.',
                    requestId, distributorPageRef(requestId));
            }
            auditNote = 'Certificate verified by CRM. RA Team and Distributor notified.';

        } else if (notificationType == 'CERTIFICATE_REJECTED') {
            for (User u : raTeam) {
                if (String.isNotBlank(u.Email)) {
                    emails.add(buildEmail(u.Email,
                        'Certificate Rejected by CRM — ' + rr.Name,
                        buildCertRejectedRABody(rr)));
                }
            }
            if (!raTeam.isEmpty()) {
                sendBellNotification(
                    toIdSet(raTeam),
                    'Certificate Rejected: ' + rr.Name,
                    'CRM has rejected the certificate for ' + safeName(rr.Account__r?.Name) + '. Please review.',
                    requestId, raPageRef(requestId));
            }
            if (rr.Requested_By__c != null) {
                sendBellNotification(
                    new Set<String>{ rr.Requested_By__c },
                    'Certificate Rejected: ' + rr.Name,
                    'Your registration certificate has been rejected. Please check comments and re-upload.',
                    requestId, distributorPageRef(requestId));
            }
            auditNote = 'Certificate rejected by CRM. RA Team and Distributor notified.';

        } else if (notificationType == 'PRODUCT_ORDER_UNLOCKED') {
            if (String.isNotBlank(rr.Requested_By__r?.Email)) {
                emails.add(buildEmail(
                    rr.Requested_By__r.Email,
                    'Order Tab Activated — ' + rr.Name,
                    buildOrderUnlockedBody(rr)));
            }
            if (rr.Requested_By__c != null) {
                sendBellNotification(
                    new Set<String>{ rr.Requested_By__c },
                    'Order Tab Activated: ' + rr.Name,
                    'Your product order has been unlocked. You can now place orders through the portal.',
                    requestId, distributorPageRef(requestId));
            }
            auditNote = 'Product order unlocked. Distributor notified via email and bell.';

        } else if (notificationType == 'ORDER_UNLOCKED_BY_RA') {
            if (String.isNotBlank(rr.Account__r?.CRM_Email__c)) {
                emails.add(buildEmail(
                    rr.Account__r.CRM_Email__c,
                    'Order Unlocked by RA Team — ' + rr.Name,
                    buildOrderUnlockedByRABody(rr)));
            }
            if (rr.Account__r?.CRM__c != null) {
                sendBellNotification(
                    new Set<String>{ rr.Account__r.CRM__c },
                    'Order Unlocked: ' + rr.Name,
                    'The RA team has directly unlocked the order for ' + safeName(rr.Account__r?.Name) + '.',
                    requestId, crmCertDetailPageRef(requestId));
            }
            auditNote = 'Order unlocked by RA Team directly (bypass CRM). CRM notified via email and bell.';

        } else if (notificationType == 'CERTIFICATE_SENT_BACK') {
            if (String.isNotBlank(rr.Requested_By__r?.Email)) {
                emails.add(buildEmail(
                    rr.Requested_By__r.Email,
                    'Certificate Sent Back — Action Required — ' + rr.Name,
                    buildCertSentBackDistributorBody(rr)));
            }
            if (rr.Requested_By__c != null) {
                sendBellNotification(
                    new Set<String>{ rr.Requested_By__c },
                    'Certificate Sent Back: ' + rr.Name,
                    'Your registration certificate has been sent back. Please review the feedback and re-upload.',
                    requestId, distributorPageRef(requestId));
            }
            auditNote = 'Certificate sent back to distributor for re-upload. Distributor notified via email and bell.';

        } else if (notificationType == 'FUNCTIONAL_HEAD_APPROVED') {
            List<String> ccList = new List<String>();
            for (User u : raTeam) {
                if (String.isNotBlank(u.Email)) ccList.add(u.Email);
            }
            if (String.isNotBlank(rr.Account__r?.CRM_Email__c)) ccList.add(rr.Account__r.CRM_Email__c);
            for (User u : cmdUsers) {
                if (String.isNotBlank(u.Email)) {
                    emails.add(buildEmail(u.Email,
                        'Registration Request Approved by Functional Head — ' + rr.Name,
                        buildFHApprovedBody(rr), ccList));
                }
            }
            if (!cmdUsers.isEmpty()) {
                sendBellNotification(
                    toIdSet(cmdUsers),
                    'Request Ready for Leadership Review',
                    rr.Name + ' approved by Functional Head — awaiting your review.',
                    requestId, leadershipPageRef(requestId));
            }
            auditNote = 'Approved by Functional Head. CMD notified via email and bell. RA Team and CRM in CC.';
        } else if (notificationType == 'FORECAST_WEEK_UPDATED') {
            // Distributor — email
            if (String.isNotBlank(rr.Requested_By__r?.Email)) {
                emails.add(buildEmail(
                    rr.Requested_By__r.Email,
                    'Forecast Week Updated — ' + rr.Name,
                    buildForecastWeekUpdatedBody(rr)
                ));
            }
            // RA Team — bell only
            if (!raTeam.isEmpty()) {
                sendBellNotification(
                    toIdSet(raTeam),
                    'Forecast Week Updated',
                    'Forecast week for ' + rr.Name + ' has been updated to Week '
                        + String.valueOf(rr.Forecast_Week__c != null ? (Integer)rr.Forecast_Week__c : 0)
                        + ' / ' + String.valueOf(rr.Forecast_Year__c != null ? (Integer)rr.Forecast_Year__c : 0) + '.',
                    requestId, raPageRef(requestId));
            }
            // Leadership — bell only
            if (!leaders.isEmpty()) {
                sendBellNotification(
                    toIdSet(leaders),
                    'Forecast Week Updated',
                    'Forecast week for ' + rr.Name + ' has been updated to Week '
                        + String.valueOf(rr.Forecast_Week__c != null ? (Integer)rr.Forecast_Week__c : 0)
                        + ' / ' + String.valueOf(rr.Forecast_Year__c != null ? (Integer)rr.Forecast_Year__c : 0) + '.',
                    requestId, leadershipPageRef(requestId));
            }
            auditNote = 'Forecast week updated by RA Team. Distributor notified via email. RA Team and Leadership notified via bell.';
        }

        if (!emails.isEmpty()) {
            Id owaId = getSenderOwaId();
            if (owaId != null) {
                for (Messaging.SingleEmailMessage m : emails) {
                    m.setOrgWideEmailAddressId(owaId);
                }
            }
            Messaging.sendEmail(emails, false);
        }
    }

    // ── Bell notification ──────────────────────────────────────────────────────
    // Requires CustomNotificationType with DeveloperName = 'Registration_Portal_Notification'
    // to be created manually in Setup → Custom Notifications before use.
    public static void sendBellNotification(Set<String> recipientIds, String title, String body, Id targetId) {
        sendBellNotification(recipientIds, title, body, targetId, null);
    }

    // Overload: pass a portalPageRef JSON string to redirect to an Experience Cloud page instead of the record.
    public static void sendBellNotification(Set<String> recipientIds, String title, String body, Id targetId, String portalPageRef) {
        if (recipientIds == null || recipientIds.isEmpty()) return;
        try {
            List<CustomNotificationType> types = [
                SELECT Id FROM CustomNotificationType
                WHERE  DeveloperName = 'Registration_Portal_Notification'
                LIMIT  1
            ];
            if (types.isEmpty()) return;

            Messaging.CustomNotification notif = new Messaging.CustomNotification();
            notif.setTitle(title);
            notif.setBody(body);
            notif.setNotificationTypeId(types[0].Id);
            if (String.isNotBlank(portalPageRef)) {
                notif.setTargetPageRef(portalPageRef);
            } else {
                notif.setTargetId(targetId);
            }
            notif.send(recipientIds);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Bell notification failed: ' + e.getMessage());
        }
    }

    private static String distributorPageRef(Id requestId) {
        return '{"type":"standard__webPage","attributes":{"url":"/s/request-detail?id=' + requestId + '"}}';
    }

    private static String leadershipPageRef(Id requestId) {
        return '{"type":"standard__webPage","attributes":{"url":"/s/leadership-request-detail?recordId=' + requestId + '"}}';
    }

    private static String raPageRef(Id requestId) {
        return '{"type":"standard__webPage","attributes":{"url":"/s/regulatory-request-detail?recordId=' + requestId + '"}}';
    }

    private static String crmCertDetailPageRef(Id requestId) {
        return '{"type":"standard__webPage","attributes":{"url":"/s/crm-certificate-detail?recordId=' + requestId + '"}}';
    }

    private static String fhPageRef(Id requestId) {
        return '{"type":"standard__webPage","attributes":{"url":"/s/functional-head-request-detail?recordId=' + requestId + '"}}';
    }

    // ── User helpers (delegate to without-sharing inner class) ────────────────
    public static List<User> getLeadershipUsers() {
        return new ElevatedQuery().getLeadershipUsers();
    }

    public static List<User> getRATeamUsers() {
        return new ElevatedQuery().getRATeamUsers();
    }

    private static Set<String> toIdSet(List<User> users) {
        Set<String> ids = new Set<String>();
        for (User u : users) ids.add(u.Id);
        return ids;
    }

    private static String safeName(String s) {
        return String.isNotBlank(s) ? s : 'Unknown';
    }

    // ── Owner assignment ───────────────────────────────────────────────────────
    private static void assignOwner(Id requestId, Id ownerId) {
        try {
            update new Registration_Request__c(Id = requestId, OwnerId = ownerId);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Owner assignment failed: ' + e.getMessage());
        }
    }

    // ── Audit task ─────────────────────────────────────────────────────────────
    private static Id nonMomTaskRtId {
        get {
            if (nonMomTaskRtId == null) {
                List<RecordType> rts = [
                    SELECT Id FROM RecordType
                    WHERE SObjectType = 'Task' AND DeveloperName != 'MOM_Action_Item'
                    LIMIT 1
                ];
                nonMomTaskRtId = rts.isEmpty() ? null : rts[0].Id;
            }
            return nonMomTaskRtId;
        }
        set;
    }

    private static void createAuditTask(Id requestId, String notificationType, String note) {
        try {
            Task t = new Task(
                Subject      = '[Reg Audit] ' + notificationType,
                Description  = note,
                Status       = 'Completed',
                Priority     = 'Normal',
                WhatId       = requestId,
                OwnerId      = UserInfo.getUserId(),
                ActivityDate = Date.today()
            );
            if (nonMomTaskRtId != null) t.RecordTypeId = nonMomTaskRtId;
            insert t;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Audit task creation failed: ' + e.getMessage());
        }
    }

    // ── Generic email builder ──────────────────────────────────────────────────
    private static Messaging.SingleEmailMessage buildEmail(
        String toAddress, String subject, String htmlBody
    ) {
        return buildEmail(toAddress, subject, htmlBody, new List<String>());
    }

    private static Messaging.SingleEmailMessage buildEmail(
        String toAddress, String subject, String htmlBody, List<String> ccAddresses
    ) {
        Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
        m.setToAddresses(new List<String>{ toAddress });
        if (!ccAddresses.isEmpty()) m.setCcAddresses(ccAddresses);
        m.setSubject(subject);
        m.setHtmlBody(htmlBody);
        m.setSaveAsActivity(false);
        return m;
    }

    // ── Email body builders ────────────────────────────────────────────────────

    private static String buildFHReviewBody(Registration_Request__c rr) {
        return wrap('New Registration Request — Review Required',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello,</p>'
            + '<p style="margin:0 0 16px 0;">A new registration request requires your review as <strong>Functional Head</strong>. Please review the details below and take action.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">Please log in to the portal and <strong>Approve</strong>, <strong>Send Back</strong>, or <strong>Reject</strong> this request.</p>'
        );
    }

    private static String buildFHApprovedBody(Registration_Request__c rr) {
        return wrap('Registration Request Approved by Functional Head',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello,</p>'
            + '<p style="margin:0 0 16px 0;">The following registration request has been <strong style="color:#2e7d32;">Approved by the Functional Head</strong> and is now ready for your Leadership review.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">Please log in to the portal to review and approve.</p>'
        );
    }

    private static String buildLeadershipSubmittedBody(Registration_Request__c rr) {
        return wrap('New Registration Request Submitted',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello,</p>'
            + '<p style="margin:0 0 16px 0;">A new registration request has been submitted by <strong>' + esc(rr.Account__r?.Name) + '</strong> and is awaiting CRM review before forwarding to Leadership.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">The CRM team will review and forward to Leadership shortly.</p>'
        );
    }

    private static String buildCRMSubmittedBody(Registration_Request__c rr) {
        return wrap('New Registration Request — Your Review Required',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello ' + esc(rr.Account__r?.CRM__r?.Name) + ',</p>'
            + '<p style="margin:0 0 16px 0;">A new registration request has been submitted and requires your review.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">Please log in to Salesforce and either <strong>Forward to Leadership</strong> or <strong>Reject</strong> this request.</p>'
            + recordLink(rr.Id)
        );
    }

    private static String buildRATeamSubmittedBody(Registration_Request__c rr) {
        return wrap('New Registration Request Submitted — For Your Awareness',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello,</p>'
            + '<p style="margin:0 0 16px 0;">A new registration request has been submitted by <strong>' + esc(rr.Account__r?.Name) + '</strong>. This is for your awareness — the request is currently under CRM and Leadership review.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">You will receive a separate notification once the request is submitted to the Regulatory team for processing.</p>'
        );
    }

    private static String buildDistributorSubmittedConfirmBody(Registration_Request__c rr) {
        return wrap('Registration Request Successfully Submitted',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Dear ' + esc(rr.Account__r?.Name) + ',</p>'
            + '<p style="margin:0 0 16px 0;">Thank you! Your registration request has been successfully submitted and is now <strong>under review</strong> by our CRM team.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">You will receive email updates as your request progresses through each stage. You can also track the status on the portal at any time.</p>'
        );
    }

    private static String buildRSMSubmittedBody(Registration_Request__c rr) {
        return wrap('New Registration Request Submitted — For Your Visibility',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello,</p>'
            + '<p style="margin:0 0 16px 0;">A new registration request has been submitted by your distributor <strong>' + esc(rr.Account__r?.Name) + '</strong>.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">This is for your visibility. The CRM team will review and forward to Leadership for approval.</p>'
        );
    }

    private static String buildLeadershipReviewBody(Registration_Request__c rr) {
        return wrap('Registration Request Forwarded for Leadership Approval',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello,</p>'
            + '<p style="margin:0 0 16px 0;">The following registration request has been reviewed by the CRM team and forwarded to Leadership for final approval.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">Please log in to Salesforce to <strong>Approve</strong> or <strong>Reject</strong> this request.</p>'
        );
    }

    private static String buildDistributorApprovedBody(Registration_Request__c rr) {
        return wrap('Your Registration Request Has Been Approved',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Dear ' + esc(rr.Account__r?.Name) + ',</p>'
            + '<p style="margin:0 0 16px 0;">We are pleased to inform you that your registration request has been <strong style="color:#2e7d32;">Approved</strong>.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">Our Regulatory team will now begin processing your request. You will receive further updates as the process progresses.</p>'
        );
    }

    private static String buildCRMApprovedBody(Registration_Request__c rr) {
        return wrap('Registration Request Approved by Leadership',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello ' + esc(rr.Account__r?.CRM__r?.Name) + ',</p>'
            + '<p style="margin:0 0 16px 0;">The following registration request has been <strong style="color:#2e7d32;">Approved by Leadership</strong>.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">The request has moved to <strong>Regulatory Processing</strong> stage.</p>'
            + recordLink(rr.Id)
        );
    }

    private static String buildDistributorRejectedBody(Registration_Request__c rr) {
        return wrap('Registration Request Rejected',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Dear ' + esc(rr.Account__r?.Name) + ',</p>'
            + '<p style="margin:0 0 16px 0;">We regret to inform you that your registration request has been <strong style="color:#c62828;">Rejected</strong>.</p>'
            + requestTable(rr)
            + '<table cellspacing="0" cellpadding="0" style="width:100%;border-collapse:collapse;margin:12px 0;background:#ffffff;border-radius:4px;">'
            + row('Rejection Reason',
                String.isNotBlank(rr.Rejection_Comments__c)
                    ? esc(rr.Rejection_Comments__c)
                    : 'Please contact your CRM representative for details.')
            + '</table>'
            + '<p style="margin:16px 0 6px 0;">If you have questions, please reach out to your assigned CRM: <strong>' + esc(rr.Account__r?.CRM__r?.Name) + '</strong>.</p>'
        );
    }

    private static String buildCRMRejectedBody(Registration_Request__c rr) {
        return wrap('Registration Request Rejected',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello ' + esc(rr.Account__r?.CRM__r?.Name) + ',</p>'
            + '<p style="margin:0 0 16px 0;">The following registration request has been <strong style="color:#c62828;">Rejected</strong>.</p>'
            + requestTable(rr)
            + '<table cellspacing="0" cellpadding="0" style="width:100%;border-collapse:collapse;margin:12px 0;background:#ffffff;border-radius:4px;">'
            + row('Rejection Reason',
                String.isNotBlank(rr.Rejection_Comments__c)
                    ? esc(rr.Rejection_Comments__c)
                    : 'N/A')
            + '</table>'
            + '<p style="margin:16px 0 6px 0;">The distributor has been notified via email.</p>'
            + recordLink(rr.Id)
        );
    }

    private static String buildManagementReviewBody(Registration_Request__c rr) {
        return wrap('Registration Request Awaiting Management Approval',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello,</p>'
            + '<p style="margin:0 0 16px 0;">The following registration request has passed initial Leadership review and now requires <strong>final Management approval</strong>.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">Please log in to Salesforce to <strong>Final Approve</strong> or <strong>Reject</strong> this request.</p>'
        );
    }

    private static String buildRATeamRegulatoryBody(Registration_Request__c rr) {
        return wrap('Registration Request Ready for Regulatory Processing',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello,</p>'
            + '<p style="margin:0 0 16px 0;">The following registration request has been fully approved by Leadership and is now <strong>submitted to the Regulatory team</strong> for processing.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">Please log in to the Regulatory portal to begin processing this request.</p>'
            + raPortalLink(rr.Id)
        );
    }

    private static String buildSubmittedToRegulatoryBody(Registration_Request__c rr) {
        return wrap('Registration Request Submitted to Regulatory Team',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello,</p>'
            + '<p style="margin:0 0 16px 0;">The following registration request has been fully approved by Leadership and <strong>submitted to the Regulatory team</strong> for processing.</p>'
            + requestTable(rr)
        );
    }

    private static String buildDistributorRegulatoryBody(Registration_Request__c rr) {
        return wrap('Your Request Has Been Submitted to the Regulatory Team',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Dear ' + esc(rr.Account__r?.Name) + ',</p>'
            + '<p style="margin:0 0 16px 0;">Great news! Your registration request has been approved by our Leadership team and has been <strong style="color:#2e7d32;">submitted to the Regulatory team</strong> for processing.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">Our Regulatory team will be in touch with further updates. You may track the status of your request on the portal.</p>'
        );
    }

    private static String buildDistributorSentBackBody(Registration_Request__c rr) {
        return wrap('Registration Request Sent Back for Revision',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Dear ' + esc(rr.Account__r?.Name) + ',</p>'
            + '<p style="margin:0 0 16px 0;">Your registration request has been <strong style="color:#dd7a01;">sent back</strong> for revision.</p>'
            + requestTable(rr)
            + '<table cellspacing="0" cellpadding="0" style="width:100%;border-collapse:collapse;margin:12px 0;background:#ffffff;border-radius:4px;">'
            + row('Reason', String.isNotBlank(rr.Rejection_Comments__c)
                ? esc(rr.Rejection_Comments__c)
                : 'Please contact your CRM for details.')
            + '</table>'
            + '<p style="margin:16px 0 6px 0;">Please review the reason above and resubmit your request through the portal. Contact your CRM representative if you need assistance.</p>'
        );
    }

    private static String buildCRMSentBackBody(Registration_Request__c rr) {
        return wrap('Registration Request Sent Back to Distributor',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello ' + esc(rr.Account__r?.CRM__r?.Name) + ',</p>'
            + '<p style="margin:0 0 16px 0;">The following registration request has been <strong style="color:#dd7a01;">sent back</strong> to the distributor for revision.</p>'
            + requestTable(rr)
            + '<table cellspacing="0" cellpadding="0" style="width:100%;border-collapse:collapse;margin:12px 0;background:#ffffff;border-radius:4px;">'
            + row('Reason', String.isNotBlank(rr.Rejection_Comments__c)
                ? esc(rr.Rejection_Comments__c) : 'N/A')
            + '</table>'
            + '<p style="margin:16px 0 6px 0;">The distributor has been notified and will resubmit once the issue is resolved.</p>'
            + recordLink(rr.Id)
        );
    }

    private static String buildDistributorAdditionalDocsBody(Registration_Request__c rr) {
        return wrap('Additional Documents Required',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Dear ' + esc(rr.Account__r?.Name) + ',</p>'
            + '<p style="margin:0 0 16px 0;">Our Regulatory team has reviewed your registration request and requires <strong style="color:#dd7a01;">additional documents</strong> before processing can continue.</p>'
            + requestTable(rr)
            + '<table cellspacing="0" cellpadding="0" style="width:100%;border-collapse:collapse;margin:12px 0;background:#ffffff;border-radius:4px;">'
            + row('Required Action',
                String.isNotBlank(rr.Rejection_Comments__c)
                    ? esc(rr.Rejection_Comments__c)
                    : 'Please log in to the portal and upload the required documents.')
            + '</table>'
            + '<p style="margin:16px 0 6px 0;">Please log in to the portal, review the RA team\'s remarks in your Document Basket, and upload the requested documents at your earliest convenience.</p>'
        );
    }

    private static String buildRAAdditionalDocsRequestedBody(Registration_Request__c rr) {
        return wrap('Additional Document Request Submitted',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello,</p>'
            + '<p style="margin:0 0 16px 0;"><strong>' + esc(rr.Account__r?.Name) + '</strong> has submitted an <strong style="color:#dd7a01;">additional document request</strong> for the following registration.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">Please log in to the Regulatory portal to review and process this request.</p>'
            + raPortalLink(rr.Id)
        );
    }

    private static String buildCRMAdditionalDocsBody(Registration_Request__c rr) {
        return wrap('Additional Documents Requested from Distributor',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello,</p>'
            + '<p style="margin:0 0 16px 0;">The Regulatory team has requested <strong style="color:#dd7a01;">additional documents</strong> for the following registration request.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">The distributor has been notified and will upload the required documents via the portal.</p>'
        );
    }

    private static String buildDistributorCompletedBody(Registration_Request__c rr) {
        return wrap('Your Registration Request is Complete',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Dear ' + esc(rr.Account__r?.Name) + ',</p>'
            + '<p style="margin:0 0 16px 0;">We are pleased to inform you that your registration request has been <strong style="color:#2e7d32;">Completed</strong> by our Regulatory team.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">Approved documents are now available in the portal. Please log in to view and download your documents.</p>'
            + '<p style="margin:8px 0 6px 0;">If you have any questions, please reach out to your assigned CRM: <strong>' + esc(rr.Account__r?.CRM__r?.Name) + '</strong>.</p>'
        );
    }

    private static String buildCRMCompletedBody(Registration_Request__c rr) {
        return wrap('Registration Request Completed',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello ' + esc(rr.Account__r?.CRM__r?.Name) + ',</p>'
            + '<p style="margin:0 0 16px 0;">The following registration request has been <strong style="color:#2e7d32;">Completed</strong> by the Regulatory team.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">The distributor has been notified and documents are now available on the portal.</p>'
            + recordLink(rr.Id)
        );
    }

    private static String buildLeadershipCompletedBody(Registration_Request__c rr) {
        return wrap('Registration Request Completed',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello,</p>'
            + '<p style="margin:0 0 16px 0;">The following registration request has been <strong style="color:#2e7d32;">Completed</strong> by the Regulatory team.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">The distributor has been notified and the registration process is now closed.</p>'
        );
    }

    // ── Certificate verification email bodies ────────────────────────────────────

    private static String buildCertUploadedBody(Registration_Request__c rr) {
        return wrap('Registration Certificate Uploaded',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello,</p>'
            + '<p style="margin:0 0 16px 0;"><strong>' + esc(rr.Account__r?.Name) + '</strong> has uploaded registration certificate(s) for the following request.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">Please log in to the portal to review the uploaded certificates and forward to CRM for verification.</p>'
            + raPortalLink(rr.Id)
        );
    }

    private static String buildCertForwardedToCRMBody(Registration_Request__c rr) {
        return wrap('Certificate Verification Required',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello ' + esc(rr.Account__r?.CRM__r?.Name) + ',</p>'
            + '<p style="margin:0 0 16px 0;">Registration certificates for the following request have been reviewed by the Regulatory team and require your <strong>verification</strong>.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">Please log in to the portal to verify or reject the certificates.</p>'
        );
    }

    private static String buildCertVerifiedRABody(Registration_Request__c rr) {
        return wrap('Certificate Verified by CRM',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello,</p>'
            + '<p style="margin:0 0 16px 0;">The CRM team has <strong style="color:#2e7d32;">verified</strong> the registration certificate(s) for the following request.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">You may now unlock the product order on the portal.</p>'
            + raPortalLink(rr.Id)
        );
    }

    private static String buildCertVerifiedDistributorBody(Registration_Request__c rr) {
        return wrap('Your Certificate Has Been Verified',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Dear ' + esc(rr.Account__r?.Name) + ',</p>'
            + '<p style="margin:0 0 16px 0;">Your registration certificate has been <strong style="color:#2e7d32;">verified</strong>.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">Your order tab will be activated shortly. You will receive a notification once it is ready.</p>'
        );
    }

    private static String buildCertRejectedRABody(Registration_Request__c rr) {
        return wrap('Certificate Rejected by CRM',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello,</p>'
            + '<p style="margin:0 0 16px 0;">The CRM team has <strong style="color:#c62828;">rejected</strong> the registration certificate(s) for the following request.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">Please review the CRM\'s comments and coordinate with the distributor for re-upload.</p>'
            + raPortalLink(rr.Id)
        );
    }

    private static String buildOrderUnlockedByRABody(Registration_Request__c rr) {
        return wrap('Order Unlocked by RA Team',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Hello ' + esc(rr.Account__r?.CRM__r?.Name) + ',</p>'
            + '<p style="margin:0 0 16px 0;">The RA team has directly <strong style="color:#2e7d32;">unlocked the order</strong> for the following registration request without CRM certificate verification.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">The distributor has been notified and can now place orders for the approved product(s).</p>'
            + recordLink(rr.Id)
        );
    }

    private static String buildOrderUnlockedBody(Registration_Request__c rr) {
        return wrap('Your Order Tab Has Been Activated',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Dear ' + esc(rr.Account__r?.Name) + ',</p>'
            + '<p style="margin:0 0 16px 0;">Great news! Your <strong style="color:#2e7d32;">Order Tab has been activated</strong> for the following registration.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">You can now place orders for the approved product(s) through the portal.</p>'
        );
    }

    private static String buildCertSentBackDistributorBody(Registration_Request__c rr) {
        return wrap('Certificate Sent Back — Action Required',
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Dear ' + esc(rr.Account__r?.Name) + ',</p>'
            + '<p style="margin:0 0 16px 0;">Your registration certificate has been <strong style="color:#dd7a01;">sent back</strong> for revision. Please review the feedback below, make the necessary corrections, and re-upload your certificate.</p>'
            + requestTable(rr)
            + '<p style="margin:16px 0 6px 0;">Please log in to the portal, review the feedback provided for each product, and re-upload the corrected certificates at your earliest convenience.</p>'
        );
    }

    private static String buildForecastWeekUpdatedBody(Registration_Request__c rr) {
        String weekVal = rr.Forecast_Week__c != null ? String.valueOf((Integer)rr.Forecast_Week__c) : '—';
        String yearVal = rr.Forecast_Year__c != null ? String.valueOf((Integer)rr.Forecast_Year__c) : '—';
        return wrap('Forecast Week Updated — ' + esc(rr.Name),
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Dear ' + esc(rr.Account__r?.Name) + ',</p>'
            + '<p style="margin:0 0 16px 0;">The <strong>forecast week</strong> for your registration request has been updated by the Regulatory Affairs team.</p>'
            + requestTable(rr)
            + '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin:16px 0;">'
            + '<tr><td style="padding:12px;background:#f0f4ff;border-radius:6px;">'
            + '<p style="margin:0 0 6px 0;font-size:13px;color:#555555;">Forecast Week</p>'
            + '<p style="margin:0;font-size:20px;font-weight:bold;color:#0053a0;">Week ' + weekVal + ' &nbsp;/&nbsp; ' + yearVal + '</p>'
            + '</td></tr></table>'
            + '<p style="margin:16px 0 6px 0;">Please log in to the portal to view the full details of your registration request.</p>'
        );
    }

    // ── HTML helpers ─────────────────────────────────────────────────────────────
    private static String wrap(String headerTitle, String content) {
        return '<!doctype html><html lang="en"><head>'
            + '<meta charset="utf-8">'
            + '<meta name="viewport" content="width=device-width,initial-scale=1">'
            + '</head><body style="margin:0;padding:0;">'
            + '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:#f4f6f8;padding:24px 0;">'
            + '<tr><td align="center">'
            + '<table role="presentation" cellspacing="0" cellpadding="0" style="width:100%;max-width:620px;background:#ffffff;border-radius:6px;overflow:hidden;">'
            // Logo
            + '<tr><td style="background:#ffffff;padding:20px 0 10px 0;text-align:center;border-bottom:1px solid #e6e9ee;">'
            + '<img src="https://biotechhealthcare.com/wp-content/uploads/2024/07/logo-300x206-1.png" alt="Biotech Healthcare" style="max-width:160px;height:auto;border:0;">'
            + '</td></tr>'
            // Header bar
            + '<tr><td style="background:#244b5a;padding:18px 24px;text-align:center;">'
            + '<h2 style="margin:0;color:#ffffff;font-size:20px;font-family:Arial,sans-serif;">' + headerTitle + '</h2>'
            + '</td></tr>'
            // Content
            + '<tr><td style="padding:24px;background:#e6edf6;font-family:Arial,sans-serif;color:#111827;font-size:14px;line-height:1.6;">'
            + content
            + '</td></tr>'
            // Footer
            + '<tr><td style="padding:16px 24px;font-size:12px;color:#6b7280;border-top:3px solid #244b5a;text-align:center;background:#ffffff;">'
            + '<img src="https://lmd.biotechhealthcare.com/images/footer-logo.png" alt="Biotech" style="max-width:80px;margin-bottom:8px;display:block;margin-left:auto;margin-right:auto;"><br>'
            + '<a href="mailto:misinternational@biotechhealthcare.com" style="color:#244b5a;text-decoration:none;">misinternational@biotechhealthcare.com</a><br>'
            + '<span style="color:#707070;">&copy; Copyright Biotech / Terms Of Use - Privacy Policy</span><br>'
            + '<span style="font-size:11px;color:#707070;">This is an automated notification from the BioTech VisionCare Registration Portal. Please do not reply to this email.</span>'
            + '</td></tr>'
            + '</table></td></tr></table>'
            + '</body></html>';
    }

    private static String requestTable(Registration_Request__c rr) {
        return '<table cellspacing="0" cellpadding="0" style="width:100%;border-collapse:collapse;margin:16px 0;background:#ffffff;border-radius:4px;">'
            + row('Request No.',  esc(rr.Name))
            + row('Distributor',  esc(rr.Account__r?.Name))
            + row('Product',      esc(rr.Product__r?.Name))
            + row('Country',      esc(rr.Country__c))
            + row('Status',       esc(rr.Status__c))
            + row('Stage',        esc(rr.Current_Stage__c))
            + row('Submitted',    rr.Submitted_Date__c != null ? String.valueOf(rr.Submitted_Date__c) : '')
            + '</table>';
    }

    private static String row(String label, String val) {
        return '<tr>'
            + '<td style="padding:10px 14px;font-size:13px;border-bottom:1px solid #dde3ed;font-weight:bold;color:#374151;width:42%;vertical-align:top;">' + label + '</td>'
            + '<td style="padding:10px 14px;font-size:13px;border-bottom:1px solid #dde3ed;color:#111827;vertical-align:top;">' + (val != null ? val : '') + '</td>'
            + '</tr>';
    }

    private static String esc(String s) {
        if (s == null) return '';
        return s.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;');
    }

    private static String recordLink(Id recordId) {
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String href    = baseUrl + '/' + recordId;
        return '<div style="padding:20px 0 8px 0;">'
            + '<a href="' + href + '" style="display:inline-block;background:#244b5a;color:#ffffff;padding:11px 24px;border-radius:5px;font-weight:bold;font-size:14px;font-family:Arial,sans-serif;text-decoration:none;">'
            + 'View Record in Salesforce</a>'
            + '</div>';
    }

    private static String raPortalLink(Id recordId) {
        String portalBase = URL.getOrgDomainUrl().toExternalForm()
            .replace('my.salesforce.com', 'my.site.com');
        String href = portalBase + '/s/regulatory-request-detail?recordId=' + recordId;
        return '<div style="padding:20px 0 8px 0;">'
            + '<a href="' + href + '" style="display:inline-block;background:#244b5a;color:#ffffff;padding:11px 24px;border-radius:5px;font-weight:bold;font-size:14px;font-family:Arial,sans-serif;text-decoration:none;">'
            + 'View Request in Portal</a>'
            + '</div>';
    }

    // ── Sender OrgWideEmailAddress from MOM_Config__mdt ───────────────────────
    private static Id cachedOwaId;
    private static Boolean owaResolved = false;

    private static Id getSenderOwaId() {
        if (!owaResolved) {
            owaResolved = true;
            try {
                List<MOM_Config__mdt> configs = [
                    SELECT Sender_Email__c FROM MOM_Config__mdt
                    WHERE DeveloperName = 'Default' LIMIT 1
                ];
                if (!configs.isEmpty() && String.isNotBlank(configs[0].Sender_Email__c)) {
                    List<OrgWideEmailAddress> owas = [
                        SELECT Id FROM OrgWideEmailAddress
                        WHERE Address = :configs[0].Sender_Email__c LIMIT 1
                    ];
                    if (!owas.isEmpty()) cachedOwaId = owas[0].Id;
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'OWA lookup failed: ' + e.getMessage());
            }
        }
        return cachedOwaId;
    }

    // ── Without-sharing inner class for query ──────────────────────────────────
    private without sharing class ElevatedQuery {
        List<User> getLeadershipUsers() {
            return [
                SELECT Id, Email, Name FROM User
                WHERE  IsActive = true
                AND    Leadership_Team__c = true
                LIMIT  20
            ];
        }
        List<User> getRATeamUsers() {
            return [
                SELECT Id, Email, Name FROM User
                WHERE  IsActive = true
                AND    RA_Team__c = true
                LIMIT  20
            ];
        }
        List<User> getFunctionalHeadUsers() {
            return [
                SELECT Id, Email, Name FROM User
                WHERE  IsActive = true
                AND    Functional_Head__c = true
                LIMIT  20
            ];
        }
        List<User> getCMDUsers() {
            return [
                SELECT Id, Email, Name FROM User
                WHERE  IsActive = true
                AND    CMD__c = true
                LIMIT  20
            ];
        }
        Registration_Request__c getRequest(Id requestId) {
            return [
                SELECT  Id, Name, Status__c, Current_Stage__c, Country__c,
                        Remarks__c, Rejection_Comments__c, Submitted_Date__c,
                        Requested_By__c,
                        Requested_By__r.Name, Requested_By__r.Email,
                        Parent_Request__c,
                        Parent_Request__r.Requested_By__c,
                        Account__c,
                        Account__r.Name,
                        Account__r.CRM__c,
                        Account__r.CRM__r.Name,
                        Account__r.CRM_Email__c,
                        Account__r.RSM__c,
                        Account__r.RSM__r.Name,
                        Account__r.RSM_Email__c,
                        Product__c,
                        Product__r.Name,
                        Forecast_Week__c,
                        Forecast_Year__c
                FROM    Registration_Request__c
                WHERE   Id = :requestId
                LIMIT   1
            ];
        }
    }
}
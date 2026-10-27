public without sharing class MOMOverdueEscalationBatch implements Database.Batchable<SObject> {

    private static final String TEMPLATE_ESCALATION = 'MOM_Escalation_Notification';
    private static final String TEMPLATE_REMINDER   = 'MOM_Due_Tomorrow_Reminder';
    private String notifTypeId;

    // ─── Batchable ─────────────────────────────────────────────────────────────

    public Database.QueryLocator start(Database.BatchableContext bc) {
        List<CustomNotificationType> types = [
            SELECT Id FROM CustomNotificationType
            WHERE DeveloperName = 'MOM_Action_Item_Notification' LIMIT 1
        ];
        notifTypeId = types.isEmpty() ? null : types[0].Id;

        return Database.getQueryLocator(
            'SELECT Id, Subject, Status, ActivityDate, ' +
            '       OwnerId, Owner.Email, ' +
            '       Meeting__c, Meeting__r.Name, ' +
            '       Meeting__r.Meeting_Owner__c, ' +
            '       Meeting__r.Meeting_Owner__r.Email, ' +
            '       Meeting__r.Meeting_Owner__r.L1_Manager__c, ' +
            '       Meeting__r.Meeting_Owner__r.L2Manager__c, ' +
            '       Meeting__r.Meeting_Owner__r.L2Manager__r.Email ' +
            'FROM Task ' +
            'WHERE Meeting__c != null ' +
            '  AND Status != \'Completed\' ' +
            '  AND ActivityDate <= TOMORROW'
        );
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        Date today = Date.today();
        List<MOMEmailService.EmailRequest> emails = new List<MOMEmailService.EmailRequest>();
        List<MOMCustomNotificationService.NotificationRequest> notifs = new List<MOMCustomNotificationService.NotificationRequest>();
        List<Task> toMarkDelayed = new List<Task>();

        for (SObject so : scope) {
            Task t = (Task) so;
            if (t.ActivityDate == null) continue;

            Integer daysOverdue = t.ActivityDate.daysBetween(today);

            if (daysOverdue == -1) {
                handleDueTomorrow(t, emails, notifs);
            } else if (daysOverdue >= 1) {
                // Auto-mark as Delayed if not already
                if (t.Status != 'Delayed') {
                    toMarkDelayed.add(new Task(Id = t.Id, Status = 'Delayed'));
                }
                if (daysOverdue == 1) {
                    handleDay1(t, emails, notifs);
                } else if (daysOverdue >= 3) {
                    handleDay3Plus(t, emails, notifs);
                }
            }
        }

        if (!toMarkDelayed.isEmpty()) update toMarkDelayed;
        if (!emails.isEmpty()) MOMEmailService.sendEmail(emails);
        if (!notifs.isEmpty() && String.isNotBlank(notifTypeId)) {
            MOMCustomNotificationService.sendNotification(notifs);
        }
    }

    public void finish(Database.BatchableContext bc) {}

    // ─── Due Tomorrow: reminder to Task Owner ─────────────────────────────────

    private void handleDueTomorrow(Task t, List<MOMEmailService.EmailRequest> emails, List<MOMCustomNotificationService.NotificationRequest> notifs) {
        String taskOwnerId = String.valueOf(t.OwnerId);
        if (String.isBlank(taskOwnerId)) return;

        emails.add(buildEmailRequest(taskOwnerId, t.Id, null, TEMPLATE_REMINDER));
        notifs.add(buildNotifRequest(
            taskOwnerId, t,
            'Action Item Due Tomorrow',
            'Reminder: action item "' + t.Subject + '" is due tomorrow (' + String.valueOf(t.ActivityDate) + ').'
        ));
    }

    // ─── Day 1: Meeting Owner + Task Owner ────────────────────────────────────

    private void handleDay1(Task t, List<MOMEmailService.EmailRequest> emails, List<MOMCustomNotificationService.NotificationRequest> notifs) {
        String meetingOwnerId = getMeetingOwnerId(t);
        String taskOwnerId    = String.valueOf(t.OwnerId);

        if (String.isNotBlank(meetingOwnerId)) {
            emails.add(buildEmailRequest(meetingOwnerId, t.Id, null, TEMPLATE_ESCALATION));
            notifs.add(buildNotifRequest(meetingOwnerId, t));
        }

        // Send separately to Task Owner only if they are a different person
        if (String.isNotBlank(taskOwnerId) && taskOwnerId != meetingOwnerId) {
            emails.add(buildEmailRequest(taskOwnerId, t.Id, null, TEMPLATE_ESCALATION));
            notifs.add(buildNotifRequest(taskOwnerId, t));
        }
    }

    // ─── Day 3+: L1 Manager (To), CC: L2 Manager + BDM ───────────────────────

    private void handleDay3Plus(Task t, List<MOMEmailService.EmailRequest> emails, List<MOMCustomNotificationService.NotificationRequest> notifs) {
        String l1ManagerId = getL1ManagerId(t);
        if (String.isBlank(l1ManagerId)) return;

        List<String> ccAddresses = new List<String>();

        String l2ManagerEmail = getL2ManagerEmail(t);
        if (String.isNotBlank(l2ManagerEmail)) ccAddresses.add(l2ManagerEmail);

        String bdmEmail = getBDMEmail(t);
        if (String.isNotBlank(bdmEmail)) ccAddresses.add(bdmEmail);

        emails.add(buildEmailRequest(l1ManagerId, t.Id, ccAddresses.isEmpty() ? null : ccAddresses, TEMPLATE_ESCALATION));

        notifs.add(buildNotifRequest(l1ManagerId, t));
        String l2ManagerId = getL2ManagerId(t);
        if (String.isNotBlank(l2ManagerId)) notifs.add(buildNotifRequest(l2ManagerId, t));
        String bdmId = getBDMId(t);
        if (String.isNotBlank(bdmId)) notifs.add(buildNotifRequest(bdmId, t));
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private String getMeetingOwnerId(Task t) {
        if (t.Meeting__r == null) return null;
        return (String) t.Meeting__r.get('Meeting_Owner__c');
    }

    private String getL1ManagerId(Task t) {
        if (t.Meeting__r == null) return null;
        SObject bdmUser = t.Meeting__r.getSObject('Meeting_Owner__r');
        return bdmUser == null ? null : (String) bdmUser.get('L1_Manager__c');
    }

    private String getL2ManagerId(Task t) {
        if (t.Meeting__r == null) return null;
        SObject bdmUser = t.Meeting__r.getSObject('Meeting_Owner__r');
        return bdmUser == null ? null : (String) bdmUser.get('L2Manager__c');
    }

    private String getL2ManagerEmail(Task t) {
        if (t.Meeting__r == null) return null;
        SObject bdmUser = t.Meeting__r.getSObject('Meeting_Owner__r');
        if (bdmUser == null) return null;
        SObject l2Manager = bdmUser.getSObject('L2Manager__r');
        return l2Manager == null ? null : (String) l2Manager.get('Email');
    }

    private String getBDMId(Task t) {
        return getMeetingOwnerId(t);
    }

    private String getBDMEmail(Task t) {
        if (t.Meeting__r == null) return null;
        SObject bdmUser = t.Meeting__r.getSObject('Meeting_Owner__r');
        return bdmUser == null ? null : (String) bdmUser.get('Email');
    }

    private MOMEmailService.EmailRequest buildEmailRequest(String targetUserId, String taskId, List<String> ccAddresses, String templateName) {
        MOMEmailService.EmailRequest req = new MOMEmailService.EmailRequest();
        req.templateDeveloperName = templateName;
        req.targetObjectId        = targetUserId;
        req.whatId                = taskId;
        req.ccAddresses           = ccAddresses;
        return req;
    }

    private MOMCustomNotificationService.NotificationRequest buildNotifRequest(String recipientId, Task t) {
        return buildNotifRequest(
            recipientId, t,
            'Action Item Overdue',
            'Action item "' + t.Subject + '" is overdue since ' + String.valueOf(t.ActivityDate) + '. Immediate attention required.'
        );
    }

    private MOMCustomNotificationService.NotificationRequest buildNotifRequest(String recipientId, Task t, String title, String body) {
        MOMCustomNotificationService.NotificationRequest req = new MOMCustomNotificationService.NotificationRequest();
        req.notifTypeId  = notifTypeId;
        req.title        = title;
        req.body         = body;
        req.targetId     = t.Id;
        req.recipientId  = recipientId;
        return req;
    }
}
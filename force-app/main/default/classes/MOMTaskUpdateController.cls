public without sharing class MOMTaskUpdateController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getTaskDetails(String taskId, String token) {
        if (String.isBlank(taskId) || String.isBlank(token)) {
            throw new AuraHandledException('Invalid request parameters.');
        }

        List<Task> tasks = [
            SELECT Id, Subject, ActivityDate, Status, Description, Priority,
                   Responsible_Department__c, Attendees__c, Target_Week__c,
                   Completion_Date__c, Completion_Week__c,
                   Meeting__r.Name, Meeting__r.Meeting_Date__c, Meeting__r.Discussion_Summary__c,
                   Meeting__r.Distributor__r.Name,
                   Guest_Access_Token__c
            FROM   Task
            WHERE  Id       = :taskId
            AND    Meeting__c != null
            LIMIT  1
        ];

        if (tasks.isEmpty() || tasks[0].Guest_Access_Token__c != token) {
            throw new AuraHandledException('This link is invalid or has already expired.');
        }

        Task t = tasks[0];

        String category = '';
        if (String.isNotBlank(t.Responsible_Department__c)) {
            List<Department_Users_Emails__mdt> cmts = [
                SELECT Category__c FROM Department_Users_Emails__mdt
                WHERE Label = :t.Responsible_Department__c LIMIT 1
            ];
            if (!cmts.isEmpty()) category = cmts[0].Category__c;
        }

        String attendeesList = '';
        if (String.isNotBlank(t.Attendees__c)) {
            try {
                List<Object> atts = (List<Object>) JSON.deserializeUntyped(t.Attendees__c);
                List<String> emails = new List<String>();
                for (Object att : atts) {
                    if (att instanceof String) emails.add((String) att);
                }
                attendeesList = String.join(emails, ', ');
            } catch (Exception e) { }
        }

        Boolean isFirstVisit = String.isBlank(t.Description);

        return new Map<String, Object>{
            'id'               => t.Id,
            'subject'          => t.Subject,
            'dueDate'          => t.ActivityDate != null ? String.valueOf(t.ActivityDate) : null,
            'targetWeek'       => t.Target_Week__c,
            'completionDate'   => t.Completion_Date__c != null ? String.valueOf(t.Completion_Date__c) : null,
            'completionWeek'   => t.Completion_Week__c,
            'isFirstVisit'     => isFirstVisit,
            'status'           => t.Status,
            'description'      => t.Description,
            'priority'         => t.Priority,
            'responsibleDept'  => t.Responsible_Department__c,
            'attendees'        => attendeesList,
            'meetingName'      => t.Meeting__r != null ? t.Meeting__r.Name : '',
            'meetingDate'      => (t.Meeting__r != null && t.Meeting__r.Meeting_Date__c != null)
                                    ? String.valueOf(t.Meeting__r.Meeting_Date__c) : '',
            'discussionSummary'=> (t.Meeting__r != null && String.isNotBlank(t.Meeting__r.Discussion_Summary__c))
                                    ? t.Meeting__r.Discussion_Summary__c : '',
            'distributor'      => (t.Meeting__r != null && t.Meeting__r.Distributor__r != null)
                                    ? t.Meeting__r.Distributor__r.Name : '',
            'category'         => category
        };
    }

    @AuraEnabled
    public static void updateTask(String taskId, String token, String status, String comment, String dueDate) {
        if (String.isBlank(taskId) || String.isBlank(token)) {
            throw new AuraHandledException('Invalid request parameters.');
        }

        List<Task> tasks = [
            SELECT Id, Guest_Access_Token__c, ActivityDate, Description
            FROM   Task
            WHERE  Id       = :taskId
            AND    Meeting__c != null
            LIMIT  1
        ];

        if (tasks.isEmpty() || tasks[0].Guest_Access_Token__c != token) {
            throw new AuraHandledException('This link is invalid or has already expired.');
        }

        Task t       = tasks[0];
        Boolean isFirstVisit = String.isBlank(t.Description);

        t.Status      = status;
        t.Description = comment;

        if (String.isNotBlank(dueDate)) {
            Date parsedDate = Date.valueOf(dueDate);
            if (isFirstVisit) {
                t.ActivityDate = parsedDate;
            } else {
                t.Completion_Date__c = parsedDate;
                t.Completion_Week__c = Math.ceil(parsedDate.dayOfYear() / 7.0);
            }
        }

        if (status == 'Completed') {
            t.Guest_Access_Token__c = null;
        }
        update t;

        String templateName = null;
        if (status == 'Completed') {
            templateName = 'MOM_Completion_Notification';
        } else if (isFirstVisit && String.isNotBlank(dueDate)) {
            templateName = 'MOM_DueDate_Update_Notification';
        }

        if (String.isNotBlank(templateName)) {
            List<MOM_Config__mdt> configs = [
                SELECT Sender_Email__c FROM MOM_Config__mdt
                WHERE  DeveloperName = 'Default' LIMIT 1
            ];
            String senderEmail = (!configs.isEmpty() && String.isNotBlank(configs[0].Sender_Email__c))
                ? configs[0].Sender_Email__c : null;

            MOMAttendeeNotificationService.Request req = new MOMAttendeeNotificationService.Request();
            req.taskId                = t.Id;
            req.templateDeveloperName = templateName;
            req.senderEmail           = senderEmail;
            MOMAttendeeNotificationService.sendAttendeeNotifications(
                new List<MOMAttendeeNotificationService.Request>{ req }
            );
        }
    }

    @AuraEnabled
    public static void rejectTask(String taskId, String token, String comment) {
        if (String.isBlank(taskId) || String.isBlank(token)) {
            throw new AuraHandledException('Invalid request parameters.');
        }
        if (String.isBlank(comment)) {
            throw new AuraHandledException('Please provide a reason before submitting.');
        }

        List<Task> tasks = [
            SELECT Id, Subject, Guest_Access_Token__c, Responsible_Department__c,
                   Meeting__c, Meeting__r.Name, Meeting__r.OwnerId,
                   Meeting__r.Owner.Email, Meeting__r.Owner.FirstName
            FROM   Task
            WHERE  Id       = :taskId
            AND    Meeting__c != null
            LIMIT  1
        ];

        if (tasks.isEmpty() || tasks[0].Guest_Access_Token__c != token) {
            throw new AuraHandledException('This link is invalid or has already expired.');
        }

        Task t = tasks[0];
        sendRejectionEmail(t, comment);
        sendRejectionNotification(t, comment);
    }

    private static void sendRejectionEmail(Task t, String comment) {
        List<EmailTemplate> templates = [
            SELECT Subject, HtmlValue FROM EmailTemplate
            WHERE  DeveloperName = 'MOM_Task_Rejection_Notification'
            LIMIT  1
        ];
        if (templates.isEmpty()) return;

        List<MOM_Config__mdt> configs = [
            SELECT Sender_Email__c FROM MOM_Config__mdt
            WHERE  DeveloperName = 'Default' LIMIT 1
        ];
        String senderEmail = (!configs.isEmpty() && String.isNotBlank(configs[0].Sender_Email__c))
            ? configs[0].Sender_Email__c : null;
        List<OrgWideEmailAddress> owas = String.isNotBlank(senderEmail)
            ? [SELECT Id FROM OrgWideEmailAddress WHERE Address = :senderEmail LIMIT 1]
            : new List<OrgWideEmailAddress>();

        String meetingLink  = URL.getOrgDomainUrl().toExternalForm() + '/' + t.Meeting__c;
        String bdmFirstName = String.isNotBlank(t.Meeting__r.Owner.FirstName)
            ? t.Meeting__r.Owner.FirstName : 'Team';

        String htmlBody = templates[0].HtmlValue
            .replace('{!Receiving_User.FirstName}',       bdmFirstName)
            .replace('{!Task.Subject}',                   t.Subject != null ? t.Subject : '')
            .replace('{!Task.MOMName}',                   t.Meeting__r.Name != null ? t.Meeting__r.Name : '')
            .replace('{!Task.Responsible_Department__c}', String.isNotBlank(t.Responsible_Department__c) ? t.Responsible_Department__c : '')
            .replace('##REJECTION_COMMENT##',              comment)
            .replace('##MOM_MEETING_LINK##',              meetingLink);

        String emailSubject = templates[0].Subject
            .replace('{!Task.Subject}', t.Subject != null ? t.Subject : '')
            .replace('{!Task.MOMName}', t.Meeting__r.Name != null ? t.Meeting__r.Name : '');

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ t.Meeting__r.Owner.Email });
        mail.setSubject(emailSubject);
        mail.setHtmlBody(htmlBody);
        mail.setSaveAsActivity(false);
        if (!owas.isEmpty()) mail.setOrgWideEmailAddressId(owas[0].Id);

        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail }, false);
        } catch (Exception e) { }
    }

    private static void sendRejectionNotification(Task t, String comment) {
        List<CustomNotificationType> notifTypes = [
            SELECT Id FROM CustomNotificationType
            WHERE  DeveloperName = 'MOM_Action_Item_Notification'
            LIMIT  1
        ];
        if (notifTypes.isEmpty()) return;

        try {
            Messaging.CustomNotification notif = new Messaging.CustomNotification();
            notif.setTitle('Action Item — Assignment Not Accepted');
            notif.setBody('"' + t.Subject + '" was not accepted by the assigned user. Reason: ' + comment);
            notif.setNotificationTypeId(notifTypes[0].Id);
            notif.setTargetId(t.Meeting__c);
            notif.send(new Set<String>{ t.Meeting__r.OwnerId });
        } catch (Exception e) { }
    }
}
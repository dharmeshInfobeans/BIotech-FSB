public without sharing class MOMEmailService {

    @InvocableMethod(
        label='Send MOM Templated Email'
        description='Sends a styled HTML email for MOM Action Item notifications using stored email templates'
    )
    public static void sendEmail(List<EmailRequest> requests) {
        if (requests == null || requests.isEmpty()) return;

        Set<Id> taskIds        = new Set<Id>();
        Set<Id> userIds        = new Set<Id>();
        Set<String> tmplNames  = new Set<String>();

        for (EmailRequest req : requests) {
            if (String.isNotBlank(req.whatId))               taskIds.add((Id) req.whatId);
            if (String.isNotBlank(req.targetObjectId))       userIds.add((Id) req.targetObjectId);
            if (String.isNotBlank(req.templateDeveloperName)) tmplNames.add(req.templateDeveloperName);
        }

        Map<Id, Task> taskMap = new Map<Id, Task>();
        if (!taskIds.isEmpty()) {
            for (Task t : [
                SELECT Id, Subject, ActivityDate, Status, Priority, Description,
                       OwnerId, Owner.Name,
                       Responsible_Department__c, Attendees__c,
                       Meeting__r.Name, Meeting__r.Meeting_Topic__c,
                       Meeting__r.Distributor__r.Name,
                       Meeting__r.Meeting_Date__c, Meeting__r.Discussion_Summary__c,
                       Guest_Access_Token__c
                FROM   Task
                WHERE  Id IN :taskIds
            ]) {
                taskMap.put(t.Id, t);
            }
        }

        // Resolve Responsible_Department__c → Category__c via CMT for all tasks
        Map<String, String> deptToCategory = new Map<String, String>();
        if (!taskMap.isEmpty()) {
            Set<String> deptLabels = new Set<String>();
            for (Task t : taskMap.values()) {
                if (String.isNotBlank(t.Responsible_Department__c)) deptLabels.add(t.Responsible_Department__c);
            }
            if (!deptLabels.isEmpty()) {
                for (Department_Users_Emails__mdt rec : [
                    SELECT Label, Category__c
                    FROM   Department_Users_Emails__mdt
                    WHERE  Label IN :deptLabels
                ]) {
                    deptToCategory.put(rec.Label, rec.Category__c);
                }
            }
        }

        Map<Id, User> userMap = new Map<Id, User>();
        if (!userIds.isEmpty()) {
            for (User u : [
                SELECT Id, Email, FirstName
                FROM   User
                WHERE  Id IN :userIds
                AND    IsActive = true
            ]) {
                userMap.put(u.Id, u);
            }
        }

        Map<String, EmailTemplate> templateMap = new Map<String, EmailTemplate>();
        if (!tmplNames.isEmpty()) {
            for (EmailTemplate et : [
                SELECT DeveloperName, Subject, HtmlValue
                FROM   EmailTemplate
                WHERE  DeveloperName IN :tmplNames
            ]) {
                templateMap.put(et.DeveloperName, et);
            }
        }

        String senderEmail = null;
        for (EmailRequest req : requests) {
            if (String.isNotBlank(req.senderEmail)) { senderEmail = req.senderEmail; break; }
        }
        List<OrgWideEmailAddress> owas = String.isNotBlank(senderEmail)
            ? [SELECT Id FROM OrgWideEmailAddress WHERE Address = :senderEmail LIMIT 1]
            : new List<OrgWideEmailAddress>();
        Id owaId = owas.isEmpty() ? null : owas[0].Id;

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (EmailRequest req : requests) {
            if (String.isBlank(req.templateDeveloperName)) continue;

            String toEmail;
            User recipient = null;

            if (String.isNotBlank(req.toEmailAddress)) {
                toEmail = req.toEmailAddress;
            } else if (String.isNotBlank(req.targetObjectId)) {
                recipient = userMap.get((Id) req.targetObjectId);
                if (recipient == null || String.isBlank(recipient.Email)) continue;
                toEmail = recipient.Email;
            } else {
                continue;
            }

            EmailTemplate tmpl = templateMap.get(req.templateDeveloperName);
            if (tmpl == null) continue;

            Task task = String.isNotBlank(req.whatId) ? taskMap.get((Id) req.whatId) : null;
            String category = (task != null) ? deptToCategory.get(task.Responsible_Department__c) : null;

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ toEmail });
            mail.setSubject(resolveMergeFields(tmpl.Subject, recipient, task, category));
            mail.setHtmlBody(resolveMergeFields(tmpl.HtmlValue, recipient, task, category));
            mail.setSaveAsActivity(false);

            if (owaId != null) mail.setOrgWideEmailAddressId(owaId);
            if (req.ccAddresses != null && !req.ccAddresses.isEmpty()) {
                mail.setCcAddresses(req.ccAddresses);
            }

            emails.add(mail);
        }

        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails, false);
            } catch (Exception e) {
                // Email failure must not block flow or batch execution
            }
        }
    }

    // Resolves all {!Task.*} and {!Receiving_User.*} merge fields used in the templates.
    // More specific paths (e.g. Meeting__r.Name) are replaced before shorter ones (Meeting__r)
    // to avoid partial replacements leaving stray text.
    private static String resolveMergeFields(String text, User recipient, Task t, String category) {
        if (String.isBlank(text)) return '';

        String firstName        = (recipient != null && String.isNotBlank(recipient.FirstName)) ? recipient.FirstName : 'Team';
        String taskSubject      = (t != null && String.isNotBlank(t.Subject))                   ? t.Subject           : '';
        String meetingName      = (t != null && t.Meeting__r != null)                           ? t.Meeting__r.Name         : '';
        String meetingTopic     = (t != null && t.Meeting__r != null && String.isNotBlank(t.Meeting__r.Meeting_Topic__c)) ? t.Meeting__r.Meeting_Topic__c : meetingName;
        String distributorName  = (t != null && t.Meeting__r != null && t.Meeting__r.Distributor__r != null) ? t.Meeting__r.Distributor__r.Name : '';
        String ownerName        = (t != null && t.Owner != null)                                ? t.Owner.Name        : '';
        String dueDate          = (t != null && t.ActivityDate != null)                         ? String.valueOf(t.ActivityDate) : '';
        String status           = (t != null && String.isNotBlank(t.Status))                    ? t.Status            : '';
        String dept             = (t != null && String.isNotBlank(t.Responsible_Department__c)) ? t.Responsible_Department__c : '';
        String taskId           = (t != null)                                                   ? String.valueOf(t.Id) : '';
        String token            = (t != null && String.isNotBlank(t.Guest_Access_Token__c))     ? t.Guest_Access_Token__c : '';
        String priority         = (t != null && String.isNotBlank(t.Priority))                            ? t.Priority          : '';
        String comment          = (t != null && String.isNotBlank(t.Description))                         ? t.Description       : '';
        String meetingDate      = (t != null && t.Meeting__r != null && t.Meeting__r.Meeting_Date__c != null)
                                    //? String.valueOf(t.Meeting__r.Meeting_Date__c) : '';
                                    ? DateTime.newInstance(t.Meeting__r.Meeting_Date__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy') : '';
        String discSummary      = (t != null && t.Meeting__r != null && String.isNotBlank(t.Meeting__r.Discussion_Summary__c))
                                    ? t.Meeting__r.Discussion_Summary__c : '';
        String categoryVal      = String.isNotBlank(category) ? category : '';
        String targetWeekNum    = '';
        if (t != null && t.ActivityDate != null) {
            Date startOfYear = Date.newInstance(t.ActivityDate.year(), 1, 1);
            Integer dayOfYear = startOfYear.daysBetween(t.ActivityDate) + 1;
            targetWeekNum = String.valueOf((Integer) Math.ceil(dayOfYear / 7.0));
        }
        String attendeesList    = '';
        if (t != null && String.isNotBlank(t.Attendees__c)) {
            try {
                List<Object> atts = (List<Object>) JSON.deserializeUntyped(t.Attendees__c);
                List<String> emails = new List<String>();
                for (Object att : atts) {
                    if (att instanceof String) emails.add((String) att);
                }
                attendeesList = String.join(emails, ', ');
            } catch (Exception e) { }
        }

        return text
            .replace('{!Receiving_User.FirstName}',              firstName)
            .replace('{!Task.Subject}',                          taskSubject)
            .replace('{!Task.DistributorName}',                  distributorName)
            .replace('{!Task.Meeting__r.Distributor__r.Name}',   distributorName)
            .replace('{!Task.Meeting__r.Name}',                  meetingName)
            .replace('{!Task.MOMName}',                          meetingTopic)
            .replace('{!Task.MeetingTopic}',                     meetingTopic)
            .replace('{!Task.Meeting__r}',                       meetingName)
            .replace('{!Task.Owner.Name}',                       ownerName)
            .replace('{!Task.Owner}',                            ownerName)
            .replace('{!Task.ActivityDate}',                     dueDate)
            .replace('{!Task.Status}',                           status)
            .replace('{!Task.Responsible_Department__c}',        dept)
            .replace('{!Task.Id}',                               taskId)
            .replace('{!Task.Guest_Access_Token__c}',            token)
            .replace('{!Task.MeetingDate}',                      meetingDate)
            .replace('{!Task.DiscussionSummary}',                discSummary)
            .replace('{!Task.Priority}',                         priority)
            .replace('{!Task.Category}',                         categoryVal)
            .replace('{!Task.AttendeesList}',                    attendeesList)
            .replace('{!Task.Description}',                      comment)
            .replace('{!Task.TargetWeekNumber}',                 targetWeekNum);
    }

    public class EmailRequest {
        @InvocableVariable(required=true label='Template Developer Name')
        public String templateDeveloperName;

        @InvocableVariable(label='Sender Email (OrgWide Email Address)')
        public String senderEmail;

        @InvocableVariable(label='Target Object Id (User)')
        public String targetObjectId;

        @InvocableVariable(label='To Email Address (for non-User recipients e.g. Distributor)')
        public String toEmailAddress;

        @InvocableVariable(label='What Id (Task Id)')
        public String whatId;

        @InvocableVariable(label='CC Addresses')
        public List<String> ccAddresses;
    }
}
public without sharing class MOMWeeklySummaryBatch implements Schedulable {

    // Schedule: every Monday 8 AM
    // Expression: 0 0 8 ? * MON *
    // To schedule from Anonymous Apex:
    //   System.schedule('MOM Weekly Summary', '0 0 8 ? * MON *', new MOMWeeklySummaryBatch());

    public void execute(SchedulableContext sc) {
        sendWeeklySummary();
    }

    @TestVisible
    public static void sendWeeklySummary() {
        Date today     = Date.today();
        Date weekStart = today.addDays(-7);
        Date weekEnd   = today.addDays(-1);

        // Action items created in the last 7 days
        List<Task> tasks = [
            SELECT Id, Subject, Status, ActivityDate,
                   Meeting__r.Name, Meeting__r.Meeting_Date__c
            FROM   Task
            WHERE  Meeting__c != null
            AND    RecordType.DeveloperName = 'MOM_Action_Item'
            AND    CreatedDate >= :DateTime.newInstance(weekStart, Time.newInstance(0, 0, 0, 0))
            AND    CreatedDate <  :DateTime.newInstance(today,     Time.newInstance(0, 0, 0, 0))
        ];

        Integer totalCount     = tasks.size();
        Integer completedCount = 0;
        Integer pendingCount   = 0;

        String taskRows = '';
        Integer idx = 0;
        for (Task t : tasks) {
            String rowClass    = Math.mod(idx, 2) == 1 ? ' class="even"' : '';
            String statusCls   = t.Status == 'Completed' ? 'status-completed' : 'status-open';
            String meetingName = (t.Meeting__r != null && String.isNotBlank(t.Meeting__r.Name))
                                    ? t.Meeting__r.Name : '—';
            String meetingDate = (t.Meeting__r != null && t.Meeting__r.Meeting_Date__c != null)
                                    ? String.valueOf(t.Meeting__r.Meeting_Date__c) : '—';
            String targetDate  = t.ActivityDate != null ? String.valueOf(t.ActivityDate) : '—';

            taskRows += '<tr' + rowClass + '>'
                + '<td>' + meetingName + '</td>'
                + '<td>' + meetingDate + '</td>'
                + '<td>' + targetDate  + '</td>'
                + '<td class="' + statusCls + '">' + t.Status + '</td>'
                + '</tr>';

            if (t.Status == 'Completed') completedCount++;
            else                         pendingCount++;
            idx++;
        }

        if (String.isBlank(taskRows)) {
            taskRows = '<tr><td colspan="4" style="text-align:center;padding:16px 14px;'
                + 'color:#6b7280;font-family:Arial,sans-serif;font-size:13px;">'
                + 'No action items were assigned in the past week.</td></tr>';
        }

        List<EmailTemplate> templates = [
            SELECT Subject, HtmlValue
            FROM   EmailTemplate
            WHERE  DeveloperName = 'MOM_Weekly_Summary_Notification'
            LIMIT  1
        ];
        if (templates.isEmpty()) return;

        String weekRange = weekStart.format() + ' – ' + weekEnd.format();

        String htmlBody = templates[0].HtmlValue
            .replace('##TOTAL##',      String.valueOf(totalCount))
            .replace('##COMPLETED##',  String.valueOf(completedCount))
            .replace('##PENDING##',    String.valueOf(pendingCount))
            .replace('##WEEK_RANGE##', weekRange)
            .replace('##TASK_ROWS##',  taskRows);

        String subject = templates[0].Subject
            .replace('##WEEK_RANGE##', weekRange);

        List<OrgWideEmailAddress> owas = [
            SELECT Id FROM OrgWideEmailAddress
            WHERE  Address = 'esupport@biotechhealthcare.com' LIMIT 1
        ];
        Id owaId = owas.isEmpty() ? null : owas[0].Id;

        Set<String> recipientEmails = new Set<String>();
        for (Department_Users_Emails__mdt rec : [
            SELECT To_Mail_ID__c
            FROM   Department_Users_Emails__mdt
            WHERE  To_Mail_ID__c != null
        ]) {
            if (String.isNotBlank(rec.To_Mail_ID__c)) {
                recipientEmails.add(rec.To_Mail_ID__c.trim().toLowerCase());
            }
        }
        if (recipientEmails.isEmpty()) return;

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (String toEmail : recipientEmails) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ toEmail });
            mail.setSubject(subject);
            mail.setHtmlBody(htmlBody);
            mail.setSaveAsActivity(false);
            if (owaId != null) mail.setOrgWideEmailAddressId(owaId);
            emails.add(mail);
        }

        try {
            Messaging.sendEmail(emails, false);
        } catch (Exception e) {
            // Email failure must not block scheduler execution
        }
    }
}
public without sharing class MOMWeeklySummaryService {

    @InvocableMethod(
        label='Send MOM Weekly Summary Email'
        description='Sends weekly summary of MOM action items to all department To emails from Custom Metadata'
    )
    public static void sendWeeklySummary(List<String> inputs) {
        Date today     = Date.today();
        Date weekStart = today.addDays(-7);
        Date weekEnd   = today.addDays(-1);

        // Current ISO week number (used for WIP/Delayed colour logic)
        Integer currentWeek = weekNumber(today);

        // Load CMT records — include Category__c for Biotech Department column
        List<Department_Users_Emails__mdt> cmtRecords = [
            SELECT Label, To_Mail_ID__c, Category__c, CC_Mail_ID__c, HOD_Mail__c
            FROM   Department_Users_Emails__mdt
            WHERE  To_Mail_ID__c != null
        ];
        if (cmtRecords.isEmpty()) return;

        Set<String>         deptLabels    = new Set<String>();
        Map<String, String> deptToCategory = new Map<String, String>();
        for (Department_Users_Emails__mdt rec : cmtRecords) {
            deptLabels.add(rec.Label);
            if (String.isNotBlank(rec.Category__c)) {
                deptToCategory.put(rec.Label, rec.Category__c);
            }
        }

        // Single query for all relevant tasks
        List<Task> allTasks = [
            SELECT Id, Subject, Status, ActivityDate, Description,
                   Guest_Access_Token__c, Target_Week__c, Completion_Week__c,
                   Responsible_Department__c,
                   Meeting__r.Name, Meeting__r.Meeting_Topic__c, Meeting__r.Meeting_Date__c,
                   Meeting__r.Distributor__r.Name, Meeting__r.Region_Set__c
            FROM   Task
            WHERE  Meeting__c != null
            AND    RecordType.DeveloperName = 'MOM_Action_Item'
            AND    Responsible_Department__c IN :deptLabels
            AND    CreatedDate >= :DateTime.newInstance(weekStart, Time.newInstance(0, 0, 0, 0))
            AND    CreatedDate <  :DateTime.newInstance(today,     Time.newInstance(0, 0, 0, 0))
        ];

        // Group tasks by responsible department
        Map<String, List<Task>> tasksByDept = new Map<String, List<Task>>();
        for (Task t : allTasks) {
            if (!tasksByDept.containsKey(t.Responsible_Department__c)) {
                tasksByDept.put(t.Responsible_Department__c, new List<Task>());
            }
            tasksByDept.get(t.Responsible_Department__c).add(t);
        }

        List<EmailTemplate> templates = [
            SELECT Subject, HtmlValue
            FROM   EmailTemplate
            WHERE  DeveloperName = 'MOM_Weekly_Summary_Notification'
            LIMIT  1
        ];
        if (templates.isEmpty()) return;

        String weekRange  = weekStart.format() + ' – ' + weekEnd.format();
        String weekNumStr = String.valueOf(weekNumber(weekStart));

        String senderEmail = null;
        List<MOM_Config__mdt> configs = [
            SELECT Sender_Email__c FROM MOM_Config__mdt
            WHERE DeveloperName = 'Default' LIMIT 1
        ];
        if (!configs.isEmpty() && String.isNotBlank(configs[0].Sender_Email__c)) {
            senderEmail = configs[0].Sender_Email__c;
        }

        List<OrgWideEmailAddress> owas = String.isNotBlank(senderEmail)
            ? [SELECT Id FROM OrgWideEmailAddress WHERE Address = :senderEmail LIMIT 1]
            : new List<OrgWideEmailAddress>();
        Id owaId = owas.isEmpty() ? null : owas[0].Id;

        String baseUrl = 'https://biotechcrm--full.sandbox.my.site.com/s/mom-task';

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Department_Users_Emails__mdt rec : cmtRecords) {
            if (String.isBlank(rec.To_Mail_ID__c)) continue;

            List<Task> deptTasks = tasksByDept.containsKey(rec.Label)
                ? tasksByDept.get(rec.Label)
                : new List<Task>();
            if (deptTasks.isEmpty()) continue;

            Integer totalCount     = deptTasks.size();
            Integer completedCount = 0;
            Integer pendingCount   = 0;
            String  taskRows       = '';
            Integer rowNum         = 0;

            for (Task t : deptTasks) {
                rowNum++;

                // ── Row background (alternating) ─────────────────────────────
                String rowBg = Math.mod(rowNum, 2) == 1 ? '#C0E6F5' : '#FFFFFF';

                // ── Cell values ──────────────────────────────────────────────
                String category       = deptToCategory.containsKey(t.Responsible_Department__c)
                                            ? deptToCategory.get(t.Responsible_Department__c) : '—';
                String meetingName    = (t.Meeting__r != null && String.isNotBlank(t.Meeting__r.Meeting_Topic__c))
                                            ? t.Meeting__r.Meeting_Topic__c
                                            : (t.Meeting__r != null && String.isNotBlank(t.Meeting__r.Name) ? t.Meeting__r.Name : '—');
                String meetingDate    = (t.Meeting__r != null && t.Meeting__r.Meeting_Date__c != null)
                                            //? String.valueOf(t.Meeting__r.Meeting_Date__c) : '—';
                                            ? DateTime.newInstance(t.Meeting__r.Meeting_Date__c, Time.newInstance(0,0,0,0)).format('dd MMM yyyy') : '—';
                String distributor    = (t.Meeting__r != null && t.Meeting__r.Distributor__r != null
                                            && String.isNotBlank(t.Meeting__r.Distributor__r.Name))
                                            ? t.Meeting__r.Distributor__r.Name : '—';
                String region         = (t.Meeting__r != null && String.isNotBlank(t.Meeting__r.Region_Set__c))
                                            ? t.Meeting__r.Region_Set__c : '—';
                String actionPoints   = String.isNotBlank(t.Subject)      ? t.Subject      : '—';
                String respDept       = String.isNotBlank(t.Responsible_Department__c)
                                            ? t.Responsible_Department__c : '—';
                String comment        = String.isNotBlank(t.Description)   ? t.Description  : '—';
                String targetWeekStr  = t.Target_Week__c    != null
                                            ? String.valueOf((Integer) t.Target_Week__c)    : '—';
                String completionWkStr = t.Completion_Week__c != null
                                            ? String.valueOf((Integer) t.Completion_Week__c) : '—';

                Integer tw = t.Target_Week__c     != null ? (Integer) t.Target_Week__c     : null;
                Integer cw = t.Completion_Week__c  != null ? (Integer) t.Completion_Week__c  : null;

                // ── Status badge ─────────────────────────────────────────────
                String statusLabel;
                String statusBg;
                String statusFg;

                if (t.Status == 'No Action Required') {
                    statusLabel = 'NA';        statusBg = '#a6a6a6'; statusFg = '#ffffff';
                } else if (t.Status == 'Completed') {
                    if (tw != null && cw != null && cw <= tw) {
                        statusLabel = 'Done';      statusBg = '#00b050'; statusFg = '#ffffff';
                    } else {
                        statusLabel = 'Completed'; statusBg = '#c6efce'; statusFg = '#155724';
                    }
                    completedCount++;
                } else {
                    // Work in Progress, Delayed, Open, etc.
                    if (tw != null && currentWeek >= tw) {
                        statusLabel = 'Delayed'; statusBg = '#ffc000'; statusFg = '#000000';
                    } else {
                        statusLabel = 'WIP';     statusBg = '#ffff00'; statusFg = '#000000';
                    }
                    pendingCount++;
                }

                String statusCell = '<span style="display:inline-block;padding:3px 10px;border-radius:4px;'
                    + 'background-color:' + statusBg + ';color:' + statusFg + ';'
                    + 'font-weight:bold;font-size:11px;white-space:nowrap;">'
                    + statusLabel + '</span>';

                // ── Action cell ──────────────────────────────────────────────
                String actionCell;
                Boolean needsUpdate = (t.Status != 'Completed' && t.Status != 'No Action Required');
                if (needsUpdate && String.isNotBlank(t.Guest_Access_Token__c)) {
                    String link = baseUrl + '?taskId=' + t.Id + '&token=' + t.Guest_Access_Token__c;
                    actionCell = '<a href="' + link + '" style="display:inline-block;padding:3px 10px;'
                        + 'border-radius:4px;background-color:#156082;color:#ffffff;'
                        + 'font-weight:bold;font-size:11px;text-decoration:none;white-space:nowrap;" '
                        + 'target="_blank" rel="noopener">Update</a>';
                } else {
                    actionCell = '—';
                }

                // ── Build row ────────────────────────────────────────────────
                String tdStyle = 'padding:8px 10px;font-size:12px;font-family:Arial,sans-serif;'
                    + 'color:#111827;border-bottom:1px solid #dde3ed;vertical-align:top;';

                taskRows += '<tr style="background-color:' + rowBg + ';">'
                    + '<td style="' + tdStyle + 'text-align:center;">'  + rowNum          + '</td>'
                    + '<td style="' + tdStyle + '">' + category       + '</td>'
                    + '<td style="' + tdStyle + '">' + meetingName    + '</td>'
                    + '<td style="' + tdStyle + 'white-space:nowrap;">' + meetingDate    + '</td>'
                    + '<td style="' + tdStyle + '">' + distributor    + '</td>'
                    + '<td style="' + tdStyle + '">' + region         + '</td>'
                    + '<td style="' + tdStyle + '">' + actionPoints   + '</td>'
                    + '<td style="' + tdStyle + '">' + respDept       + '</td>'
                    + '<td style="' + tdStyle + '">' + comment        + '</td>'
                    + '<td style="' + tdStyle + 'text-align:center;">' + targetWeekStr  + '</td>'
                    + '<td style="' + tdStyle + 'text-align:center;">' + completionWkStr + '</td>'
                    + '<td style="' + tdStyle + 'text-align:center;">' + statusCell     + '</td>'
                    + '<td style="' + tdStyle + 'text-align:center;">' + actionCell     + '</td>'
                    + '</tr>';
            }

            String htmlBody = templates[0].HtmlValue
                .replace('##TOTAL##',      String.valueOf(totalCount))
                .replace('##COMPLETED##',  String.valueOf(completedCount))
                .replace('##PENDING##',    String.valueOf(pendingCount))
                .replace('##WEEK_RANGE##',   weekRange)
                .replace('##WEEK_NUMBER##', weekNumStr)
                .replace('##TASK_ROWS##',   taskRows);

            String emailSubject = templates[0].Subject
                .replace('##WEEK_RANGE##',   weekRange)
                .replace('##WEEK_NUMBER##', weekNumStr);

            List<String> ccAddresses = new List<String>();
            if (String.isNotBlank(rec.CC_Mail_ID__c)) ccAddresses.add(rec.CC_Mail_ID__c.trim());
            if (String.isNotBlank(rec.HOD_Mail__c))   ccAddresses.add(rec.HOD_Mail__c.trim());

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ rec.To_Mail_ID__c.trim() });
            if (!ccAddresses.isEmpty()) mail.setCcAddresses(ccAddresses);
            mail.setSubject(emailSubject);
            mail.setHtmlBody(htmlBody);
            mail.setSaveAsActivity(false);
            if (owaId != null) mail.setOrgWideEmailAddressId(owaId);
            emails.add(mail);
        }

        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails, false);
            } catch (Exception e) {
                // Email failure must not block flow execution
            }
        }
    }

    // ── Compute ISO week number for a given date ──────────────────────────────
    private static Integer weekNumber(Date d) {
        Date startOfYear = Date.newInstance(d.year(), 1, 1);
        Integer dayOfYear = startOfYear.daysBetween(d) + 1;
        return (Integer) Math.ceil(dayOfYear / 7.0);
    }
}
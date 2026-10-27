public with sharing class RegistrationEscalationBatch implements Database.Batchable<SObject>, Database.Stateful {

    private Integer escalationCount = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Requests stuck in Submitted or Under Leadership Review for more than 7 days
        Datetime cutoff = Datetime.now().addDays(-7);
        return Database.getQueryLocator([
            SELECT Id, Name, Status__c, Current_Stage__c, Country__c,
                   Submitted_Date__c,
                   Account__r.Name,
                   Product__r.Name
            FROM   Registration_Request__c
            WHERE  Status__c IN ('Submitted', 'Under Leadership Review', 'Under Management Approval')
            AND    Submitted_Date__c != null
            AND    Submitted_Date__c <= :cutoff
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Registration_Request__c> records) {
        List<User> leaders = RegistrationNotificationService.getLeadershipUsers();
        if (leaders.isEmpty()) return;

        Set<String> leaderIds = new Set<String>();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Task> auditTasks = new List<Task>();

        for (User u : leaders) {
            leaderIds.add(u.Id);
        }

        for (Registration_Request__c rr : records) {
            Integer daysPending = rr.Submitted_Date__c.date().daysBetween(Date.today());

            // Escalation email to each Leadership user
            for (User u : leaders) {
                if (String.isNotBlank(u.Email)) {
                    emails.add(buildEscalationEmail(u.Email, rr, daysPending));
                }
            }

            // Audit task per record
            auditTasks.add(new Task(
                Subject      = '[Reg Escalation] ' + rr.Name,
                Description  = 'Escalation triggered: request pending '
                               + daysPending + ' day(s). Status: ' + rr.Status__c,
                Status       = 'Completed',
                Priority     = 'High',
                WhatId       = rr.Id,
                OwnerId      = UserInfo.getUserId(),
                ActivityDate = Date.today()
            ));

            escalationCount++;
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false);
        }
        if (!auditTasks.isEmpty()) {
            insert auditTasks;
        }

        // Bell notification — one per record to Leadership
        for (Registration_Request__c rr : records) {
            Integer daysPending = rr.Submitted_Date__c.date().daysBetween(Date.today());
            RegistrationNotificationService.sendBellNotification(
                leaderIds,
                'Overdue Request: ' + rr.Name,
                safeName(rr.Account__r?.Name) + ' — pending ' + daysPending + ' day(s). Immediate action required.',
                rr.Id
            );
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO,
            'RegistrationEscalationBatch complete. Escalations sent: ' + escalationCount);
    }

    // ── Escalation email builder ───────────────────────────────────────────────
    private static Messaging.SingleEmailMessage buildEscalationEmail(
        String toAddress, Registration_Request__c rr, Integer daysPending
    ) {
        String subject = '[ESCALATION] Overdue Registration Request — ' + rr.Name
                         + ' (' + daysPending + ' days pending)';

        String htmlBody =
            '<div style="font-family:Arial,sans-serif;font-size:14px;color:#222;max-width:640px;">'
            + '<div style="background:#c62828;color:#fff;padding:12px 16px;border-radius:4px 4px 0 0;">'
            + '<strong>&#9888; Escalation Alert — Overdue Registration Request</strong>'
            + '</div>'
            + '<div style="border:1px solid #ddd;border-top:none;padding:16px;">'
            + '<p>The following registration request has been pending for <strong>'
            + daysPending + ' day(s)</strong> without action and requires immediate attention.</p>'
            + '<table style="border-collapse:collapse;width:100%;max-width:600px;margin:12px 0;">'
            + tableRow('Request No.',    esc(rr.Name))
            + tableRow('Distributor',    esc(rr.Account__r?.Name))
            + tableRow('Product',        esc(rr.Product__r?.Name))
            + tableRow('Country',        esc(rr.Country__c))
            + tableRow('Current Status', esc(rr.Status__c))
            + tableRow('Days Pending',   String.valueOf(daysPending))
            + tableRow('Submitted',      rr.Submitted_Date__c != null
                                         ? String.valueOf(rr.Submitted_Date__c.date()) : '')
            + '</table>'
            + '<p>Please log in to Salesforce and take action on this request immediately.</p>'
            + '</div>'
            + '<hr style="border:none;border-top:1px solid #e0e0e0;margin:20px 0;"/>'
            + '<p style="color:#9e9e9e;font-size:11px;">Automated escalation — BioTech VisionCare Registration Portal.</p>'
            + '</div>';

        Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
        m.setToAddresses(new List<String>{ toAddress });
        m.setSubject(subject);
        m.setHtmlBody(htmlBody);
        m.setSaveAsActivity(false);
        return m;
    }

    private static String tableRow(String label, String val) {
        return '<tr>'
            + '<td style="padding:6px 12px;background:#f5f7fa;border:1px solid #ddd;font-weight:bold;width:38%;">'
            + label + '</td>'
            + '<td style="padding:6px 12px;border:1px solid #ddd;">'
            + (val != null ? val : '') + '</td>'
            + '</tr>';
    }

    private static String esc(String s) {
        if (s == null) return '';
        return s.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;');
    }

    private static String safeName(String s) {
        return String.isNotBlank(s) ? s : 'Unknown';
    }
}
public with sharing class ReRegistrationReminderBatch
    implements Database.Batchable<SObject>, Schedulable {

    // Schedule (run once on the 1st of every month at 8 AM):
    // System.schedule('Renewal Reminder Monthly', '0 0 8 1 * ?', new ReRegistrationReminderBatch());
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new ReRegistrationReminderBatch(), 200);
    }

    // ── Query all completed requests that have a Valid To date ────────────────
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, Account__c,
                   Account__r.Name, Account__r.E_Mail__c,
                   Certificate_Valid_To__c
            FROM   Registration_Request__c
            WHERE  Status__c               = 'Completed'
            AND    Certificate_Valid_To__c != null
        ]);
    }

    // ── For each batch, check if reminder should fire this month ──────────────
    public void execute(Database.BatchableContext bc, List<Registration_Request__c> scope) {
        Set<Id> requestIds  = new Set<Id>();
        Set<Id> accountIds  = new Set<Id>();
        for (Registration_Request__c rr : scope) {
            requestIds.add(rr.Id);
            accountIds.add(rr.Account__c);
        }

        // Product names per request
        Map<Id, List<String>> productsByRequest = new Map<Id, List<String>>();
        for (Registration_Request_Product__c rrp : [
            SELECT Registration_Request__c, Product__r.Name
            FROM   Registration_Request_Product__c
            WHERE  Registration_Request__c IN :requestIds
            ORDER BY CreatedDate ASC
        ]) {
            Id reqId = rrp.Registration_Request__c;
            if (!productsByRequest.containsKey(reqId)) {
                productsByRequest.put(reqId, new List<String>());
            }
            if (String.isNotBlank(rrp.Product__r?.Name)) {
                productsByRequest.get(reqId).add(rrp.Product__r.Name);
            }
        }

        // Most-recent active agreement per account → duration in months
        Map<Id, Integer> durationByAccount = new Map<Id, Integer>();
        for (Master_Agreement__c ma : [
            SELECT Account__c, Agreement_Duration_In_Months__c
            FROM   Master_Agreement__c
            WHERE  Account__c      IN :accountIds
            AND    Is_Active__c     = true
            AND    Agreement_Duration_In_Months__c != null
            ORDER BY CreatedDate DESC
        ]) {
            if (!durationByAccount.containsKey(ma.Account__c)) {
                durationByAccount.put(ma.Account__c, ma.Agreement_Duration_In_Months__c.intValue());
            }
        }

        Date today = Date.today();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Registration_Request__c rr : scope) {
            String toEmail = rr.Account__r.E_Mail__c;
            if (String.isBlank(toEmail)) continue;

            Integer duration = durationByAccount.get(rr.Account__c);
            if (duration == null || duration <= 0) continue;

            // Reminder fires when today is exactly `duration` months before Valid To month
            Date targetMonth = today.addMonths(duration);
            if (rr.Certificate_Valid_To__c.month() != targetMonth.month() ||
                rr.Certificate_Valid_To__c.year()  != targetMonth.year()) {
                continue;
            }

            List<String> products = productsByRequest.get(rr.Id);
            String productStr = (products != null && !products.isEmpty())
                ? String.join(products, ', ')
                : 'N/A';

            String validToStr = DateTime.newInstance(rr.Certificate_Valid_To__c, Time.newInstance(0, 0, 0, 0))
                                        .format('MMMM yyyy');
            String durationLabel = duration == 1 ? '1 month' : (duration + ' months');

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ toEmail });
            mail.setSubject('Registration Renewal Reminder — ' + productStr);
            mail.setHtmlBody(buildEmailBody(rr, productStr, validToStr, durationLabel));
            mail.setSaveAsActivity(false);
            emails.add(mail);
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false);
        }
    }

    public void finish(Database.BatchableContext bc) {}

    // ── Email body — same template structure as RegistrationNotificationService ─
    private static String buildEmailBody(
        Registration_Request__c rr,
        String productStr,
        String validToStr,
        String durationLabel
    ) {
        String content =
            '<p style="font-size:14px;font-weight:bold;margin:0 0 12px 0;">Dear ' + esc(rr.Account__r?.Name) + ',</p>'
            + '<p style="margin:0 0 16px 0;">This is a reminder that the registration for the following product(s) is due for renewal in <strong>' + durationLabel + '</strong>. Please initiate your renewal at the earliest to ensure uninterrupted access to product ordering.</p>'
            + '<table cellspacing="0" cellpadding="0" style="width:100%;border-collapse:collapse;margin:16px 0;background:#ffffff;border-radius:4px;">'
            + row('Distributor',    esc(rr.Account__r?.Name))
            + row('Product(s)',     esc(productStr))
            + row('Valid To',       esc(validToStr))
            + row('Time to Expiry', esc(durationLabel))
            + '</table>'
            + '<p style="margin:16px 0 6px 0;">Please log in to the <strong>BioTech VisionCare Registration Portal</strong> and submit a renewal registration request before the expiry date.</p>'
            + '<p style="margin:8px 0 0 0;">If you have any questions, please contact your Regulatory Affairs team.</p>';

        return wrap('Registration Renewal Reminder', content);
    }

    // ── Helpers — same HTML structure as RegistrationNotificationService ───────
    private static String wrap(String headerTitle, String content) {
        return '<!doctype html><html lang="en"><head>'
            + '<meta charset="utf-8">'
            + '<meta name="viewport" content="width=device-width,initial-scale=1">'
            + '</head><body style="margin:0;padding:0;">'
            + '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:#f4f6f8;padding:24px 0;">'
            + '<tr><td align="center">'
            + '<table role="presentation" cellspacing="0" cellpadding="0" style="width:100%;max-width:620px;background:#ffffff;border-radius:6px;overflow:hidden;">'
            + '<tr><td style="background:#ffffff;padding:20px 0 10px 0;text-align:center;border-bottom:1px solid #e6e9ee;">'
            + '<img src="https://biotechhealthcare.com/wp-content/uploads/2024/07/logo-300x206-1.png" alt="Biotech Healthcare" style="max-width:160px;height:auto;border:0;">'
            + '</td></tr>'
            + '<tr><td style="background:#244b5a;padding:18px 24px;text-align:center;">'
            + '<h2 style="margin:0;color:#ffffff;font-size:20px;font-family:Arial,sans-serif;">' + headerTitle + '</h2>'
            + '</td></tr>'
            + '<tr><td style="padding:24px;background:#e6edf6;font-family:Arial,sans-serif;color:#111827;font-size:14px;line-height:1.6;">'
            + content
            + '</td></tr>'
            + '<tr><td style="padding:16px 24px;font-size:12px;color:#6b7280;border-top:3px solid #244b5a;text-align:center;background:#ffffff;">'
            + '<img src="https://lmd.biotechhealthcare.com/images/footer-logo.png" alt="Biotech" style="max-width:80px;margin-bottom:8px;display:block;margin-left:auto;margin-right:auto;"><br>'
            + '<a href="mailto:misinternational@biotechhealthcare.com" style="color:#244b5a;text-decoration:none;">misinternational@biotechhealthcare.com</a><br>'
            + '<span style="color:#707070;">&copy; Copyright Biotech / Terms Of Use - Privacy Policy</span><br>'
            + '<span style="font-size:11px;color:#707070;">This is an automated notification from the BioTech VisionCare Registration Portal. Please do not reply to this email.</span>'
            + '</td></tr>'
            + '</table></td></tr></table>'
            + '</body></html>';
    }

    private static String row(String label, String val) {
        return '<tr>'
            + '<td style="padding:10px 14px;font-size:13px;border-bottom:1px solid #dde3ed;font-weight:bold;color:#374151;width:42%;vertical-align:top;">' + label + '</td>'
            + '<td style="padding:10px 14px;font-size:13px;border-bottom:1px solid #dde3ed;color:#111827;vertical-align:top;">' + (val != null ? val : '') + '</td>'
            + '</tr>';
    }

    private static String esc(String s) {
        if (s == null) return '';
        return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;');
    }
}
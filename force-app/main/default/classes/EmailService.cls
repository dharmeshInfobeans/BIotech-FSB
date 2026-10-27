public class EmailService {
    public static void sendAccountSummaryEmail(Id accountId, String toAddress, Id templateId) {
        // Step 1: Render template with Account only (recipient = null)
        Messaging.SingleEmailMessage mail = Messaging.renderStoredEmailTemplate(templateId, null, accountId);

        String subject = mail.getSubject();
        String body = mail.getHtmlBody();

        // Step 2: Fetch dynamic query from Custom Label
        // Example Custom Label value: SELECT FirstName, LastName, Email, Phone FROM Contact WHERE AccountId = '{ACCOUNT_ID}' LIMIT 50
        String queryString = System.Label.Dynamic_Contact_Query;
        queryString = queryString.replace('{ACCOUNT_ID}', String.valueOf(accountId));

        // Step 3: Run dynamic query
        List<SObject> records = Database.query(queryString);

        // Step 4: Dynamically build HTML table
        String tableHtml = '';
        if (!records.isEmpty()) {
            // Get field names from first record
            Map<String, Object> firstRecordFields = records[0].getPopulatedFieldsAsMap();
            List<String> fieldNames = new List<String>(firstRecordFields.keySet());

            tableHtml = '<table border="1" cellpadding="5" style="border-collapse:collapse; font-size:13px;">';
            // Header row
            tableHtml += '<tr style="background:#f2f2f2;">';
            for (String f : fieldNames) {
                tableHtml += '<th>' + f + '</th>';
            }
            tableHtml += '</tr>';

            // Data rows
            for (SObject rec : records) {
                tableHtml += '<tr>';
                for (String f : fieldNames) {
                    Object val = rec.get(f);
                    tableHtml += '<td>' + (val != null ? String.valueOf(val) : '') + '</td>';
                }
                tableHtml += '</tr>';
            }
            tableHtml += '</table>';
        } else {
            tableHtml = '<p>No records found.</p>';
        }

        // Step 5: Replace placeholder in template body
        body = body.replace('[[CONTACT_TABLE]]', tableHtml);

        // Step 6: Send final email
        Messaging.SingleEmailMessage finalMail = new Messaging.SingleEmailMessage();
        finalMail.setToAddresses(new String[] { toAddress });
        finalMail.setSubject(subject);
        finalMail.setHtmlBody(body);
        finalMail.setSaveAsActivity(false); 

        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { finalMail });
    }
}
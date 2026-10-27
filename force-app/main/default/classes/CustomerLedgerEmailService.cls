public without sharing class CustomerLedgerEmailService {

    @InvocableMethod(label='Send Signed Ledger to Finance' description='Sends email with PDF attachment to Finance Team' category='Customer Ledger')
    public static void sendSignedLedgerToFinance(List<Id> ledgerIds) {
        if (ledgerIds == null || ledgerIds.isEmpty()) return;

        // 1. Query Ledger records
        List<Customer_Ledger__c> ledgers = [
            SELECT Id, Name, Account__c, Account__r.Name, Customer_Code__c, 
                   Company_Code__c, Quarter__c, From_Date__c, Statement_Date__c, 
                   Contact_Name__c, Signed_Date__c, Zoho_Request_Id__c, 
                   Customer_Name__c, CreatedDate
            FROM Customer_Ledger__c
            WHERE Id IN :ledgerIds
        ];

        // 2. Query Email Template
        List<EmailTemplate> templates = [
            SELECT Id, Subject, HtmlValue, Body 
            FROM EmailTemplate 
            WHERE DeveloperName = 'Customer_Ledger_Signed_Completed'
            LIMIT 1
        ];

        if (templates.isEmpty()) {
            System.debug(LoggingLevel.ERROR, 'Email Template Customer_Ledger_Signed_Finance not found.');
            return;
        }
        EmailTemplate template = templates[0];

        // 3. Query Custom Setting for Finance Emails
        Map<String, List<String>> quarterYearEmailsMap = new Map<String, List<String>>();
        Map<String, List<String>> quarterFallbackMap    = new Map<String, List<String>>();

        for (Ledger_Quarter_Date__c lqd : [
            SELECT Quarter__c, Year__c, Finance_Team_Emails__c 
            FROM Ledger_Quarter_Date__c
        ]) {
            if (String.isNotBlank(lqd.Finance_Team_Emails__c)) {
                List<String> emails = new List<String>();
                for (String em : lqd.Finance_Team_Emails__c.split('[,;]')) {
                    if (String.isNotBlank(em)) {
                        emails.add(em.trim());
                    }
                }
                if (lqd.Year__c != null) {
                    quarterYearEmailsMap.put(lqd.Quarter__c + '_' + String.valueOf(lqd.Year__c), emails);
                }
                quarterFallbackMap.put(lqd.Quarter__c, emails);
            }
        }

        // 4. Query attached PDF ContentVersion
        Map<Id, Id> ledgerToVersionIdMap = new Map<Id, Id>();
        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :ledgerIds
            ORDER BY ContentDocument.CreatedDate DESC
        ]) {
            if (!ledgerToVersionIdMap.containsKey(cdl.LinkedEntityId)) {
                ledgerToVersionIdMap.put(cdl.LinkedEntityId, cdl.ContentDocument.LatestPublishedVersionId);
            }
        }

        // 5. Get any active Contact ID for template merge context (Required for Custom Objects)
        List<Contact> dummyContacts = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Id targetContactId = !dummyContacts.isEmpty() ? dummyContacts[0].Id : null;

        // 6. Build and Send Email
        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();

        for (Customer_Ledger__c ledger : ledgers) {
            Integer targetYear = ledger.Statement_Date__c != null 
                ? ledger.Statement_Date__c.year() 
                : (ledger.CreatedDate != null ? ledger.CreatedDate.year() : Date.today().year());

            String lookupKey = ledger.Quarter__c + '_' + targetYear;

            List<String> toAddresses = quarterYearEmailsMap.containsKey(lookupKey) 
                ? quarterYearEmailsMap.get(lookupKey) 
                : quarterFallbackMap.get(ledger.Quarter__c);
            
            if (toAddresses == null || toAddresses.isEmpty()) {
                System.debug(LoggingLevel.WARN, 'No Finance Emails found for: ' + lookupKey);
                continue;
            }

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(toAddresses);
            mail.setTemplateId(template.Id);
            mail.setWhatId(ledger.Id);
            if (targetContactId != null) {
                mail.setTargetObjectId(targetContactId);
            }
            mail.setTreatTargetObjectAsRecipient(false);
            mail.setSaveAsActivity(false);

            // Attach PDF
            Id versionId = ledgerToVersionIdMap.get(ledger.Id);
            if (versionId != null) {
                mail.setEntityAttachments(new List<Id>{ versionId });
            }

            emailList.add(mail);
        }

        if (!emailList.isEmpty()) {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(emailList, false);
            for (Messaging.SendEmailResult r : results) {
                if (r.isSuccess()) {
                    System.debug('Email successfully sent to Finance Team!');
                } else {
                    for (Messaging.SendEmailError err : r.getErrors()) {
                        System.debug(LoggingLevel.ERROR, 'Email Send Error: ' + err.getStatusCode() + ' - ' + err.getMessage());
                    }
                }
            }
        }
    }
}
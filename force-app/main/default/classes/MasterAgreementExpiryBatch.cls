global class MasterAgreementExpiryBatch implements Database.Batchable<SObject>, Database.Stateful {
        
        global Database.QueryLocator start(Database.BatchableContext bc) {
            // Fetch Agreements expiring in 1, 2, or 3 months from today
            Date today = Date.today();
            List<Date> expiryDates = new List<Date>{ today.addMonths(1), today.addMonths(2), today.addMonths(3) };
                
                String query = 'SELECT Id, Agreement_Number__c, Agreement_EndDate_mmmm_format__c, Vertical__c, Months_Until_Expiration__c, ' + 
                'Account__c,Account__r.E_Mail__c,Account__r.CRM_Email__c,Account__r.CRM_2_Email__c, Account__r.Name ' +
                'FROM Master_Agreement__c ' +
                'WHERE Agreement_End_Date__c IN :expiryDates AND Is_Active__c =true';
            
            return Database.getQueryLocator(query);
        }
        
        global void execute(Database.BatchableContext bc, List<Master_Agreement__c> agreements) {
            System.debug('agreements'+agreements);
            List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
    Map<String, List<String>> AccountVSDealerportalContactEmail = new Map<String, List<String>>();
    Set<String> AccountIDSet = new Set<String>();
    
    // Collect Account IDs from agreements
    for (Master_Agreement__c agreement : agreements) {
        if (agreement.Account__c != null) {
            AccountIDSet.add(agreement.Account__c);
        }
    }
    
    // Query contacts under these accounts
    List<User> contactLst = [
        SELECT Id, ContactId, Contact.Name, Contact.Email, Contact.AccountId 
        FROM User 
        WHERE Profile.Name = 'Biotech Partner Community' 
        AND Contact.AccountId IN :AccountIDSet
    ];
    
    for (User user : contactLst) {
        if (user.ContactId != null && user.Contact.AccountId != null && !String.isBlank(user.Contact.Email)) {
            if (!AccountVSDealerportalContactEmail.containsKey(user.Contact.AccountId)) {
                AccountVSDealerportalContactEmail.put(user.Contact.AccountId, new List<String>());
            }
            AccountVSDealerportalContactEmail.get(user.Contact.AccountId).add(user.Contact.Email);
        }
    }
    
    // Get CRM Team emails and prepare emails
    for (Master_Agreement__c agreement : agreements) {
        if (String.isBlank(agreement.Account__r.E_Mail__c) && 
            (!AccountVSDealerportalContactEmail.containsKey(agreement.Account__c) || 
             AccountVSDealerportalContactEmail.get(agreement.Account__c).isEmpty())) {
            
            System.debug('Skipping Agreement ' + agreement.Id + ' as no email is available.');
            continue;
        }
    
        List<String> toAddresses = new List<String>();
    
        // Add Contact Emails if available
        if (agreement.Account__c != null && AccountVSDealerportalContactEmail.containsKey(agreement.Account__c)) {
            toAddresses.addAll(AccountVSDealerportalContactEmail.get(agreement.Account__c));
        }
    
        // Add Account Email if available
        if (!String.isBlank(agreement.Account__r.E_Mail__c)) {
            toAddresses.add(agreement.Account__r.E_Mail__c);
        }
    
        // Ensure there's at least one recipient
        if (toAddresses.isEmpty()) {
            System.debug('Skipping Agreement ' + agreement.Id + ' as no recipient is available.');
            continue;
        }
    
        // CC Addresses (CRM Emails)
        List<String> ccAddresses = new List<String>();
        if (!String.isBlank(agreement.Account__r.CRM_Email__c)) {
            ccAddresses.add(agreement.Account__r.CRM_Email__c);
        }
        if (!String.isBlank(agreement.Account__r.CRM_2_Email__c)) {
            ccAddresses.add(agreement.Account__r.CRM_2_Email__c);
        }
    
        // Create Email Message
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(toAddresses);
        if (!ccAddresses.isEmpty()) {
            email.setCcAddresses(ccAddresses);
        }
        System.debug('toAddresses'+toAddresses);
                System.debug('ccAddresses'+ccAddresses);

        email.setSubject('Reminder: Agreement Expiry - ' + agreement.Agreement_Number__c);
        email.setHtmlBody(getEmailBody(agreement));
    
        emailsToSend.add(email);
    }
    
    // Send emails in bulk
    if (!emailsToSend.isEmpty()) {
        try {
            Messaging.sendEmail(emailsToSend);
        } catch (Exception e) {
            System.debug('Error sending emails: ' + e.getMessage());
        }
    }
    
            
        }
        
        global void finish(Database.BatchableContext bc) {
            System.debug('MasterAgreementExpiryBatch execution completed.');
        }
        
        // Email Template
        private static String getEmailBody(Master_Agreement__c agreement) {
            return '<html><body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">' +
                '<table width="100%" cellspacing="0" cellpadding="10" style="max-width: 600px; margin: auto; border: 1px solid #ddd; border-radius: 8px;">' +
                '<tr><td align="center" style="padding-bottom: 5px;">' +
                '<img src="https://biotechhealthcare.com/wp-content/uploads/2024/07/logo-300x206-1.png" ' +
                'alt="BioTech Healthcare Logo" style="max-width: 150px; margin-bottom: 5px;"></td></tr>' +
                '<tr><td style="padding-top: 0;">' +
                '<p>Dear <strong>' + agreement.Account__r.Name + '</strong>,</p>' +
                '<p>We hope you are doing well. This is a friendly reminder that your agreement <strong>' + agreement.Agreement_Number__c + 
                '</strong> with us is set to expire on <strong>' + agreement.Agreement_EndDate_mmmm_format__c + '</strong>.</p>' +
                '<p>To ensure uninterrupted service, we recommend reviewing your agreement and initiating the renewal process at your earliest convenience.</p>' +
                '<h3>Agreement Details:</h3>' +
                '<p><strong>Vertical:</strong> ' + agreement.Vertical__c + '</p>' +
                '<p><strong>Remaining Validity:</strong> ' + agreement.Months_Until_Expiration__c + ' month(s)</p>' +
                '<p>We appreciate your continued partnership and look forward to assisting you.</p>' +
                '<p>Best regards,</p>' +
                '<p><strong>Biotech Team</strong></p>' +
                '</td></tr></table></body></html>';
        }
    }
public class MasterAgreementHelper {
        private static Map<String, List<String>> AccountVSDealerportalContactEmail = new Map<String, List<String>>();
      public static void generateAgreementNumbers(List<Master_Agreement__c> agreements) {
        Map<String, Integer> verticalToMaxSeq = new Map<String, Integer>();
        Set<String> verticals = new Set<String>();
    
        // Gather all verticals that are relevant for sequencing (do not alter case here)
        for (Master_Agreement__c ma : agreements) {
            if (!ma.isClone() && !String.isBlank(ma.Vertical__c)) {
                verticals.add(ma.Vertical__c.trim());
            }
        }
    
        System.debug('Verticals identified for numbering: ' + verticals);
    
        if (!verticals.isEmpty()) {
            // Query the highest agreement number for each vertical using a separate query per vertical in for loop due to
            // as time passes there will be increase in master agreement and using single query means loop through
            //  all records to find max which is not optimsed as we know there is only 3 vericals hence even through
            //   its query in looop its going to be only 3
            for (String vertical : verticals) {
                String shortVertical = vertical.trim().toUpperCase();
                if (shortVertical.length() >= 3) {
                    shortVertical = shortVertical.substring(0, 3);
                }
    
                // Query to get the highest agreement number for this vertical
              List<Master_Agreement__c> latest = [ SELECT Agreement_Number__c,Cloned_From__c,Version__c,CreatedDate 
                                                    FROM Master_Agreement__c
                                                    WHERE Agreement_Number__c LIKE :('AGT/' + shortVertical + '/%')
                                                    AND Version__c = 'V1'   //as agreement number only chnages when new agreement /renew agreement is created which both have v1 as version.
                                                    AND Cloned_From__c = null
                                                    AND CreatedDate >= 2025-04-23T00:00:00Z
                                                    ORDER BY Agreement_Number__c DESC
                                                    LIMIT 1
                                                    ALL ROWS
                                                ];
    System.debug('vertical==>>'+vertical+'latest==>>'+latest);
                // Get the highest sequence for the vertical or start from 0 if no record is found
                Integer maxSeq = 0;
                if (!latest.isEmpty()) {
                    String agrNum = latest[0].Agreement_Number__c;
                    String[] parts = agrNum.split('/');
                    if (parts.size() == 3) {
                        maxSeq = Integer.valueOf(parts[2]);
                    }
                }
    
                // Store the max sequence for this vertical
                verticalToMaxSeq.put(vertical, maxSeq);
            }
    
            // Track per-batch sequence numbers for generating new Agreement Numbers
            for (Master_Agreement__c ma : agreements) {
                if (!ma.isClone() && !String.isBlank(ma.Vertical__c)) {
                    String originalVertical = ma.Vertical__c.trim();
                    Integer currentMaxSeq = verticalToMaxSeq.get(originalVertical);
    
                    // Increment the sequence
                    Integer newSeq = currentMaxSeq + 1;
                    verticalToMaxSeq.put(originalVertical, newSeq);
    
                    // Apply formatting (e.g., "BIO" from "Biotech")
                    String shortVertical = originalVertical.toUpperCase();
                    shortVertical = shortVertical.length() >= 3 ? shortVertical.substring(0, 3) : shortVertical;
    
                    // Generate the padded sequence number
                    String paddedSeq = String.valueOf(100000 + newSeq).substring(1);
    
                    // Assign the agreement number
                    ma.Agreement_Number__c = 'AGT/' + shortVertical + '/' + paddedSeq;
    
                    System.debug('Generated Agreement Number: ' + ma.Agreement_Number__c);
                }
            }
        }
    }
     
        public static void processAgreementUpdates(List<Master_Agreement__c> newList, Map<Id, Master_Agreement__c> oldMap) {
            List<Master_Agreement__c> agreementsToProcessForOrderDeletionEmail = new List<Master_Agreement__c>();
            Set<Id> masterAgreementIdsForSAPSync = new Set<Id>();
            Set<String> AccountIDSet = new Set<String>();
            Map<Id,Profile> ProfileIdMap = new Map<Id,Profile>();

             ProfileIdMap =new Map<Id,Profile>([SELECT Id, Name FROM Profile WHERE Name IN ('System Administrator', 'Admin_Int')]);
				Id currrentUserProfileID=userinfo.getProfileId();

            // Identify agreements that meet the criteria
            for (Master_Agreement__c ma : newList) {
                Master_Agreement__c oldMa = oldMap.get(ma.Id);
                if (ma.Is_Active__c == true && oldMa != null && oldMa.Is_Active__c == false && ma.Version__c != 'V1') {
                    AccountIDSet.add(ma.Account__c);
                    agreementsToProcessForOrderDeletionEmail.add(ma);
                }
                if (ma.Is_Active__c == true && oldMa != null && oldMa.Is_Active__c == false && ma.Syned_To_SAP__c == false) {
                    masterAgreementIdsForSAPSync.add(ma.Id);
                }
                else if(ma.Is_Active__c == true && oldMa != null && oldMa.Is_Active__c == false && ma.Syned_To_SAP__c == true && !ProfileIdMap.containsKey(currrentUserProfileID)
){
                 ma.addError('Cannot re-sync already synced active Master Agreement.');
                    
                }
            }
            
            // Populate the map (without passing it every time)
            populateDealerPortalContactEmails(AccountIDSet);
            
            if (!agreementsToProcessForOrderDeletionEmail.isEmpty()) {
                // Process each qualified Master Agreement
                for (Master_Agreement__c ma : agreementsToProcessForOrderDeletionEmail) {
                    sendOrderDeletionEmail(ma);
                }        
            }
            
            
            
            if (!masterAgreementIdsForSAPSync.isEmpty() && !Test.isRunningTest()) {
                MasterAgreementSAPSync.sendExportAgreementData(masterAgreementIdsForSAPSync);
            }
        }
        
        
        private static void populateDealerPortalContactEmails(Set<String> accountIDs) {
            AccountVSDealerportalContactEmail.clear(); // Reset to avoid stale data
            
            List<User> contactLst = [
                SELECT Id, ContactId, Contact.Name, Contact.Email, Contact.AccountId 
                FROM User 
                WHERE Profile.Name = 'Biotech Partner Community' 
                AND Contact.AccountId IN :accountIDs
            ];
            
            for (User user : contactLst) {
                if (user.ContactId != null && user.Contact.AccountId != null && !String.isBlank(user.Contact.Email)) {
                    if (!AccountVSDealerportalContactEmail.containsKey(user.Contact.AccountId)) {
                        AccountVSDealerportalContactEmail.put(user.Contact.AccountId, new List<String>());
                    }
                    AccountVSDealerportalContactEmail.get(user.Contact.AccountId).add(user.Contact.Email);
                }
            }
            System.debug('AccountVSDealerportalContactEmail'+AccountVSDealerportalContactEmail);
        }
        
        private static void sendOrderDeletionEmail(Master_Agreement__c ma) {
            System.debug('AccountVSDealerportalContactEmail: ' + AccountVSDealerportalContactEmail);
            
            // Fetch draft orders
            List<Order__c> draftOrders = [
                SELECT Id, Name, Account__c, Account__r.E_Mail__c, Account__r.CRM_Email__c, Account__r.CRM_2_Email__c 
                FROM Order__c 
                WHERE Status__c = 'Draft' 
                AND Vertical__c = :ma.Vertical__c
                AND Account__c = :ma.Account__c
            ];
            
            if (draftOrders.isEmpty()) {
                System.debug('No draft orders found. Skipping email.');
                return;
            }
            
            // Generate email body using a separate method
            String emailBody = generateOrderDeletionEmailBody(ma.Agreement_Number__c, draftOrders);
            
            // Gather recipient email addresses
            Set<String> toEmails = new Set<String>();
            Set<String> ccEmails = new Set<String>();
            
            if (draftOrders[0].Account__c != null && AccountVSDealerportalContactEmail.containsKey(draftOrders[0].Account__c)) {
                toEmails.addAll(AccountVSDealerportalContactEmail.get(draftOrders[0].Account__c));
            }
            
            System.debug('Account ID: ' + draftOrders[0].Account__c);
            System.debug('To Emails: ' + toEmails);
            
            if (draftOrders[0].Account__r != null) {
                if (String.isNotBlank(draftOrders[0].Account__r.E_Mail__c)) {
                    toEmails.add(draftOrders[0].Account__r.E_Mail__c);
                }
                if (String.isNotBlank(draftOrders[0].Account__r.CRM_Email__c)) {
                    ccEmails.add(draftOrders[0].Account__r.CRM_Email__c);
                }
                if (String.isNotBlank(draftOrders[0].Account__r.CRM_2_Email__c)) {
                    ccEmails.add(draftOrders[0].Account__r.CRM_2_Email__c);
                }
            }
            
            if (toEmails.isEmpty()) {
                System.debug('No valid recipient email found. Skipping email.');
                return;
            }
            
            // Send email
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>(toEmails));
            email.setCcAddresses(new List<String>(ccEmails));
            email.setSubject('Draft Orders for Deletion');
            email.setHtmlBody(emailBody);
            
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{email});
        }
        
        // Separate method to generate the email body
        private static String generateOrderDeletionEmailBody(String maName, List<Order__c> draftOrders) {
            String emailBody = '<html><body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">' +
                '<table width="100%" cellspacing="0" cellpadding="10" style="max-width: 600px; margin: auto; border: 1px solid #ddd; border-radius: 8px;">' +
                
                // Header Section with Logo
                '<tr><td align="center" style="padding-bottom: 10px;">' +
                '<img src="https://biotechhealthcare.com/wp-content/uploads/2024/07/logo-300x206-1.png" ' +
                'alt="BioTech Healthcare Logo" style="max-width: 150px; margin-bottom: 5px;">' +
                '<h2 style="color: #007bff; margin-top: 5px;">Draft Orders Deletion Notice</h2>' +
                '</td></tr>' +
                
                '<tr><td style="padding-top: 0;">' +
                '<p>Dear Team,</p>' +
                '<p>The following draft orders need to be deleted for the Master Agreement: <strong>' + maName + '</strong>.</p>' +
                
                // Table Without Record Link Column
                '<table width="100%" style="border-collapse: collapse; margin-top: 10px; border: 1px solid #ddd;">' +
                '<thead>' +
                '<tr style="background-color: #f4f4f4; border-bottom: 1px solid #ddd; text-align: left;">' +
                '<th style="padding: 8px;">Order Number</th>' +
                '</tr>' +
                '</thead><tbody>';
            
            for (Order__c ord : draftOrders) {
                emailBody += '<tr>' +
                    '<td style="padding: 8px; border-bottom: 1px solid #ddd;">' + ord.Name + '</td>' +
                    '</tr>';
            }
            
            emailBody += '</tbody></table>' +
                '<p>If these orders should not be deleted, please reach out immediately.</p>' +
                '<p>Best regards,</p>' +
                '<p><strong>Biotech Team</strong></p>' +
                '</td></tr></table></body></html>';
            
            return emailBody;
        }
        
    }
public class ScorecardSubmissionTriggerHandler {
    
    /**
     * Handle after insert trigger event
     * Sends email to related Scorecard_Lead__c record using HTML template from static resource
     */
    public static void handleAfterInsert(List<Scorecard_Submission__c> newSubmissions) {
        try {
            // Collect Scorecard_Lead__c IDs and Submission IDs
            Set<Id> leadIds = new Set<Id>();
            Set<Id> submissionIds = new Set<Id>();
            
            for (Scorecard_Submission__c submission : newSubmissions) {
                if (submission.Scorecard_Lead__c != null) {
                    leadIds.add(submission.Scorecard_Lead__c);
                    submissionIds.add(submission.Id);
                }
            }
            
            if (leadIds.isEmpty()) {
                return;
            }
            
            // Query Scorecard_Submission__c records with Smart_Form_URL__c field
            List<Scorecard_Submission__c> submissionsWithFields = [
                SELECT Id, Scorecard_Lead__c, Smart_Form_URL__c, Name, Total_Score__c, CreatedDate
                FROM Scorecard_Submission__c
                WHERE Id IN :submissionIds
            ];
            
            // Create map keyed by Lead ID for easy lookup
            Map<Id, Scorecard_Submission__c> submissionMap = new Map<Id, Scorecard_Submission__c>();
            for (Scorecard_Submission__c sub : submissionsWithFields) {
                submissionMap.put(sub.Scorecard_Lead__c, sub);
            }
            
            // Query Scorecard_Lead__c records with email addresses
            List<Scorecard_Lead__c> leads = [
                SELECT Id, Name, Email__c, FirstName__c, LastName__c, Company__c
                FROM Scorecard_Lead__c
                WHERE Id IN :leadIds
                AND Email__c != null
            ];
            
            if (leads.isEmpty()) {
                System.debug('No Scorecard_Lead__c records found with email addresses');
                return;
            }
            
            // Get HTML email template from static resource
            String htmlBody = getEmailTemplateFromStaticResource('ScorecardSubmissionEmailTemplate');
            
            if (String.isBlank(htmlBody)) {
                System.debug('Email template not found in static resource: ScorecardSubmissionEmailTemplate');
                return;
            }
            
            // Prepare email messages
            List<Messaging.SingleEmailMessage> emailMessages = new List<Messaging.SingleEmailMessage>();
            Map<Id, Scorecard_Lead__c> leadMap = new Map<Id, Scorecard_Lead__c>();
            
            for (Scorecard_Lead__c lead : leads) {
                leadMap.put(lead.Id, lead);
                
                Scorecard_Submission__c submission = submissionMap.get(lead.Id);
                if (submission == null) {
                    continue;
                }
                
                // Replace merge fields in HTML template
                String emailBody = replaceMergeFields(htmlBody, lead, submission);
                
                // Create email message
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new List<String>{ lead.Email__c });
                email.setSubject('Distributor Scorecard Form Request');
                email.setHtmlBody(emailBody);
                // Note: setSaveAsActivity and setTargetObjectId work with standard Lead/Contact objects only
                // For custom objects, email will be sent but won't be saved as activity automatically
                
                emailMessages.add(email);
            }
            
            // Send emails
            if (!emailMessages.isEmpty()) {
                Messaging.SendEmailResult[] results = Messaging.sendEmail(emailMessages);
                
                // Track submissions that successfully sent emails to update their status
                List<Scorecard_Submission__c> submissionsToUpdate = new List<Scorecard_Submission__c>();
                
                // Log any errors and collect successful sends
                for (Integer i = 0; i < results.size(); i++) {
                    if (results[i].isSuccess()) {
                        // Email sent successfully - update submission status to "Send"
                        Scorecard_Submission__c submission = submissionMap.get(leads[i].Id);
                        if (submission != null) {
                            submission.Status__c = 'Send';
                            submissionsToUpdate.add(submission);
                        }
                    } else {
                        System.debug('Email send failed for lead: ' + leads[i].Id);
                        System.debug('Error: ' + results[i].getErrors());
                    }
                }
                
                // Update submission statuses
                if (!submissionsToUpdate.isEmpty()) {
                    try {
                        update submissionsToUpdate;
                        System.debug('Updated ' + submissionsToUpdate.size() + ' submission(s) status to "Send"');
                    } catch (DmlException e) {
                        System.debug('Error updating submission status: ' + e.getMessage());
                        // Don't throw exception - email was sent successfully, status update failure is non-critical
                    }
                }
            }
            
        } catch (Exception e) {
            System.debug('Error in ScorecardSubmissionTriggerHandler.handleAfterInsert: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            // Don't throw exception to avoid blocking record creation
        }
    }
    
    /**
     * Get HTML email template from static resource
     * @param resourceName - Name of the static resource
     * @return String - HTML content of the template
     */
    private static String getEmailTemplateFromStaticResource(String resourceName) {
        try {
            StaticResource sr = [
                SELECT Id, Body
                FROM StaticResource
                WHERE Name = :resourceName
                LIMIT 1
            ];
            
            return sr.Body.toString();
        } catch (Exception e) {
            System.debug('Error retrieving static resource ' + resourceName + ': ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Replace merge fields in HTML template with actual values
     * Supported merge fields:
     * {LeadFirstName} - First name of the lead
     * {SmartFormURL} - Smart Form URL from the submission record
     */
    private static String replaceMergeFields(String htmlBody, Scorecard_Lead__c lead, Scorecard_Submission__c submission) {
        String result = htmlBody;
        
        // Replace Lead fields
        if (lead.FirstName__c != null) {
            result = result.replace('{LeadFirstName}', lead.FirstName__c);
        } else {
            result = result.replace('{LeadFirstName}', '');
        }
        
        // Replace Submission fields - Smart Form URL
        if (submission.Smart_Form_URL__c != null && String.isNotBlank(submission.Smart_Form_URL__c)) {
            result = result.replace('{SmartFormURL}', submission.Smart_Form_URL__c);
        } else {
            // If Smart_Form_URL__c is not populated, leave placeholder or use empty string
            result = result.replace('{SmartFormURL}', '#');
            System.debug('Warning: Smart_Form_URL__c is empty for submission: ' + submission.Id);
        }
        
        return result;
    }
    
    /**
     * Handle after update trigger event
     * When status changes to "Submitted", sends email and notification to Approver_1__c
     * Updates status to "Approver 1"
     * If this is a resubmission after Approver 1 rejection, creates a new round
     */
    public static void handleAfterUpdate(List<Scorecard_Submission__c> newSubmissions, Map<Id, Scorecard_Submission__c> oldMap) {
        try {
            List<Scorecard_Submission__c> submissionsToProcess = new List<Scorecard_Submission__c>();
            Set<Id> approverIds = new Set<Id>();
            Set<Id> submissionIdsToCheck = new Set<Id>();
            
            // Find submissions where status changed to "Submitted"
            for (Scorecard_Submission__c newSub : newSubmissions) {
                Scorecard_Submission__c oldSub = oldMap.get(newSub.Id);
                
                // Check if status changed to "Submitted" and Approver_1__c is populated
                if (oldSub != null && 
                    oldSub.Status__c != 'Submitted' && 
                    newSub.Status__c == 'Submitted' && 
                    newSub.Approver_1__c != null) {
                    submissionsToProcess.add(newSub);
                    approverIds.add(newSub.Approver_1__c);
                    submissionIdsToCheck.add(newSub.Id);
                }
            }
            
            if (submissionsToProcess.isEmpty()) {
                return;
            }
            
            // Query submissions with Approval_History_Data__c to check if this is a resubmission after rejection
            Map<Id, Scorecard_Submission__c> submissionsWithHistory = new Map<Id, Scorecard_Submission__c>([
                SELECT Id, Approval_History_Data__c, Status_Approver_1__c, Status_Approver_2__c
                FROM Scorecard_Submission__c
                WHERE Id IN :submissionIdsToCheck
            ]);
            
            // Query approver users
            Map<Id, User> approverMap = new Map<Id, User>([
                SELECT Id, Name, Email, FirstName, LastName
                FROM User
                WHERE Id IN :approverIds
                AND IsActive = true
            ]);
            
            if (approverMap.isEmpty()) {
                System.debug('No active approver users found');
                return;
            }
            
            // Prepare email messages
            List<Messaging.SingleEmailMessage> emailMessages = new List<Messaging.SingleEmailMessage>();
            List<Scorecard_Submission__c> submissionsToUpdate = new List<Scorecard_Submission__c>();
            
            // Get custom notification type ID
            CustomNotificationType notificationType = getCustomNotificationType('Scorecard_Approval_Notification');
            Id notificationTypeId = notificationType != null ? notificationType.Id : null;
            
            // Get org URL for record links
            String orgUrl = URL.getOrgDomainUrl().toExternalForm();
            
            for (Scorecard_Submission__c submission : submissionsToProcess) {
                Scorecard_Submission__c subWithHistory = submissionsWithHistory.get(submission.Id);
                User approver = approverMap.get(submission.Approver_1__c);
                 System.debug('Approver1: ' + approver.Email);
                if (approver == null || String.isBlank(approver.Email)) {
                    System.debug('Approver not found or email is blank for submission: ' + submission.Id);
                    continue;
                }
                
                // Build record URL
                String recordUrl = orgUrl + '/lightning/r/Scorecard_Submission__c/' + submission.Id + '/view';
                
                // Create email message
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new List<String>{ approver.Email });
                email.setSubject('Scorecard Submission Requires Your Approval - ' + submission.Name);
                
                // Simple text email body
                String emailBody = buildApprovalEmailBody(submission, approver, recordUrl);
                email.setPlainTextBody(emailBody);
                
                emailMessages.add(email);
                
                // Send custom notification if notification type exists
                if (notificationTypeId != null) {
                    try {
                        Messaging.CustomNotification notification = new Messaging.CustomNotification();
                        notification.setTitle('Scorecard Submission Requires Approval');
                        notification.setBody('A new scorecard submission "' + submission.Name + '" requires your approval.');
                        notification.setNotificationTypeId(notificationTypeId);
                        notification.setTargetId(submission.Id);
                        
                        // Send notification to approver - send() method takes Set<String> of user IDs
                        Set<String> recipientIds = new Set<String>{ String.valueOf(approver.Id) };
                        notification.send(recipientIds);
                    } catch (Exception e) {
                        System.debug('Error sending custom notification: ' + e.getMessage());
                        // Don't fail the process if notification send fails
                    }
                }
                
                // Mark submission for status update to "Approver 1"
                // Also create new round if this is a resubmission after Approver 1 rejection
                Scorecard_Submission__c subToUpdate = new Scorecard_Submission__c(Id = submission.Id);
                subToUpdate.Status__c = 'Approver 1';
                
                // Check if this is a resubmission after Approver 1 rejection (status changed from "Draft")
                Scorecard_Submission__c oldSub = oldMap.get(submission.Id);
                if (oldSub != null && oldSub.Status__c == 'Draft' && subWithHistory != null) {
                    // This is a resubmission - check if Approver 1 rejected in previous round
                    Boolean shouldCreateNewRound = shouldCreateNewRoundAfterRejection(subWithHistory.Approval_History_Data__c);
                    if (shouldCreateNewRound) {
                        // Create new round in Approval_History_Data__c
                        String updatedHistoryJson = createNewRoundInApprovalHistory(subWithHistory.Approval_History_Data__c);
                        if (String.isNotBlank(updatedHistoryJson)) {
                            subToUpdate.Approval_History_Data__c = updatedHistoryJson;
                        }
                        // Reset approver status fields for new round
                        subToUpdate.Status_Approver_1__c = null;
                        subToUpdate.Status_Approver_2__c = null;
                    }
                }
                
                submissionsToUpdate.add(subToUpdate);
            }
            
            // Send emails
            if (!emailMessages.isEmpty()) {
               Messaging.SendEmailResult[] emailResults = Messaging.sendEmail(emailMessages);
                
                // Log email results
                for (Integer i = 0; i < emailResults.size(); i++) {
                    if (!emailResults[i].isSuccess()) {
                        System.debug('Email send failed: ' + emailResults[i].getErrors());
                    }
                }
            }
            
            // Update submission statuses to "Approver 1"
            if (!submissionsToUpdate.isEmpty()) {
                try {
                    update submissionsToUpdate;
                    System.debug('Updated ' + submissionsToUpdate.size() + ' submission(s) status to "Approver 1"');
                } catch (DmlException e) {
                    System.debug('Error updating submission status: ' + e.getMessage());
                    // Don't throw exception - email was sent, status update failure is non-critical
                }
            }
            
        } catch (Exception e) {
            System.debug('Error in ScorecardSubmissionTriggerHandler.handleAfterUpdate: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            // Don't throw exception to avoid blocking record update
        }
    }
    
    /**
     * Build plain text email body for approval request
     */
    private static String buildApprovalEmailBody(Scorecard_Submission__c submission, User approver, String recordUrl) {
        String body = 'Dear ' + (approver.FirstName != null ? approver.FirstName : approver.Name) + ',\n\n';
        body += 'A new scorecard submission requires your approval.\n\n';
        body += 'Submission Details:\n';
        body += 'Submission Name: ' + (submission.Name != null ? submission.Name : submission.Id) + '\n';
        body += 'Status: Submitted\n';
        
        if (submission.Total_Score__c != null) {
            body += 'Total Score: ' + submission.Total_Score__c + '\n';
        }
        
        body += '\n';
        body += 'Please review and approve the scorecard submission by clicking the link below:\n';
        body += recordUrl + '\n\n';
        body += 'Thank you,\n';
        body += 'Biotech Healthcare CRM Team';
        
        return body;
    }
    
    /**
     * Get custom notification type by developer name
     */
    private static CustomNotificationType getCustomNotificationType(String developerName) {
        try {
            List<CustomNotificationType> notificationTypes = [
                SELECT Id, DeveloperName
                FROM CustomNotificationType
                WHERE DeveloperName = :developerName
                LIMIT 1
            ];
            
            return notificationTypes.isEmpty() ? null : notificationTypes[0];
        } catch (Exception e) {
            System.debug('Error retrieving custom notification type: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Check if a new round should be created after rejection
     * Returns true if Approver 1 rejected in the previous round
     */
    private static Boolean shouldCreateNewRoundAfterRejection(String approvalHistoryJson) {
        if (String.isBlank(approvalHistoryJson)) {
            return false;
        }
        
        try {
            // Clean and parse JSON
            String cleanedJson = cleanJsonString(approvalHistoryJson);
            Map<String, Object> approvalHistoryData = (Map<String, Object>) JSON.deserializeUntyped(cleanedJson);
            
            // Check if rounds structure exists
            if (!approvalHistoryData.containsKey('rounds')) {
                return false;
            }
            
            List<Object> rounds = (List<Object>) approvalHistoryData.get('rounds');
            if (rounds == null || rounds.isEmpty()) {
                return false;
            }
            
            // Get current round number
            Integer currentRoundNum = 1;
            if (approvalHistoryData.containsKey('currentRound')) {
                Object currentRoundObj = approvalHistoryData.get('currentRound');
                if (currentRoundObj instanceof Integer) {
                    currentRoundNum = (Integer) currentRoundObj;
                } else if (currentRoundObj instanceof Decimal) {
                    currentRoundNum = ((Decimal) currentRoundObj).intValue();
                }
            }
            
            // Find the current round
            for (Object roundObj : rounds) {
                if (roundObj instanceof Map<String, Object>) {
                    Map<String, Object> round = (Map<String, Object>) roundObj;
                    Object roundNumObj = round.get('roundNumber');
                    Integer roundNum = (roundNumObj instanceof Integer) ? (Integer) roundNumObj : 
                                      (roundNumObj instanceof Decimal) ? ((Decimal) roundNumObj).intValue() : null;
                    
                    if (roundNum != null && roundNum == currentRoundNum) {
                        // Check if Approver 1 rejected in this round
                        if (round.containsKey('approver1')) {
                            Object approver1Obj = round.get('approver1');
                            if (approver1Obj instanceof Map<String, Object>) {
                                Map<String, Object> approver1Data = (Map<String, Object>) approver1Obj;
                                String status = approver1Data.containsKey('status') ? (String) approver1Data.get('status') : null;
                                if (status == 'Rejected') {
                                    return true;
                                }
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error checking if new round should be created: ' + e.getMessage());
            // Return false on error - don't create new round if we can't parse history
        }
        
        return false;
    }
    
    /**
     * Create a new round in approval history JSON
     * Returns updated JSON string with new round
     */
    private static String createNewRoundInApprovalHistory(String approvalHistoryJson) {
        if (String.isBlank(approvalHistoryJson)) {
            // Initialize new structure
            Map<String, Object> newHistory = new Map<String, Object>();
            List<Object> rounds = new List<Object>();
            Map<String, Object> round1 = new Map<String, Object>();
            round1.put('roundNumber', 1);
            rounds.add(round1);
            newHistory.put('rounds', rounds);
            newHistory.put('currentRound', 1);
            return JSON.serialize(newHistory);
        }
        
        try {
            // Clean and parse JSON
            String cleanedJson = cleanJsonString(approvalHistoryJson);
            Map<String, Object> approvalHistoryData = (Map<String, Object>) JSON.deserializeUntyped(cleanedJson);
            
            // Ensure rounds structure exists
            if (!approvalHistoryData.containsKey('rounds')) {
                List<Object> rounds = new List<Object>();
                approvalHistoryData.put('rounds', rounds);
            }
            
            List<Object> rounds = (List<Object>) approvalHistoryData.get('rounds');
            
            // Get current round number and increment
            Integer currentRoundNum = 1;
            if (approvalHistoryData.containsKey('currentRound')) {
                Object currentRoundObj = approvalHistoryData.get('currentRound');
                if (currentRoundObj instanceof Integer) {
                    currentRoundNum = (Integer) currentRoundObj;
                } else if (currentRoundObj instanceof Decimal) {
                    currentRoundNum = ((Decimal) currentRoundObj).intValue();
                }
            }
            
            Integer newRoundNum = currentRoundNum + 1;
            
            // Create new round
            Map<String, Object> newRound = new Map<String, Object>();
            newRound.put('roundNumber', newRoundNum);
            rounds.add(newRound);
            
            // Update current round number
            approvalHistoryData.put('currentRound', newRoundNum);
            
            // Serialize and return
            return JSON.serialize(approvalHistoryData);
        } catch (Exception e) {
            System.debug('Error creating new round in approval history: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            return approvalHistoryJson; // Return original on error
        }
    }
    
    /**
     * Clean JSON string to handle HTML entities and malformed JSON
     */
    private static String cleanJsonString(String jsonString) {
        if (String.isBlank(jsonString)) {
            return jsonString;
        }
        
        String cleaned = jsonString.trim();
        
        // Decode HTML entities manually (Apex doesn't have Html.unescapeHtml4)
        // Must replace &amp; first to avoid double-replacing
        cleaned = cleaned.replace('&amp;', '&');
        cleaned = cleaned.replace('&quot;', '"');
        cleaned = cleaned.replace('&lt;', '<');
        cleaned = cleaned.replace('&gt;', '>');
        cleaned = cleaned.replace('&apos;', '\'');
        cleaned = cleaned.replace('&#39;', '\'');
        cleaned = cleaned.replace('&#x27;', '\'');
        cleaned = cleaned.replace('&#x2F;', '/');
        
        // Find the first { and last } to extract valid JSON
        Integer startIndex = cleaned.indexOf('{');
        Integer endIndex = cleaned.lastIndexOf('}');
        
        if (startIndex >= 0 && endIndex > startIndex) {
            cleaned = cleaned.substring(startIndex, endIndex + 1);
        }
        
        return cleaned;
    }
    
}
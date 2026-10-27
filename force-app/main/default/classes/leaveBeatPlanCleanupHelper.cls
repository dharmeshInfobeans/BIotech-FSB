/**
* @description Helper class for leaveBeatPlanCleanupTrigger
* @author Priyam Shah
* @date 2026-01-18
*
* Uses WITHOUT SHARING to bypass approval process recordEditability restrictions.
* This allows regular users to delete their own approved leaves, even though the
* Beat_Plan__c approval process has recordEditability="AdminOnly".
*/
public without sharing class leaveBeatPlanCleanupHelper {
    
    /**
* @description Handles cascade deletion of Beat_Plan__c when Event is deleted
* @param eventsBeingDeleted List of Event records from Trigger.old
*/
    public static void handleEventDeletion(List<Event> eventsBeingDeleted) {
        // Added by Priyam Shah - Collect Beat Plan IDs from Events being deleted
        System.debug('leaveBeatPlanCleanupHelper.handleEventDeletion called with ' + eventsBeingDeleted.size() + ' events');
        Set<Id> beatPlanIds = new Set<Id>();
        
        for(Event ev : eventsBeingDeleted) {
            System.debug('Event Id: ' + ev.Id + ', Beat_plan__c: ' + ev.Beat_plan__c + ', Subject: ' + ev.Subject);
            // Only process Events that have linked Beat Plans
            if(ev.Beat_plan__c != null && ev.Subject == 'Leave') {
                System.debug('Queueing Beat Plan deletion for Leave Event: ' + ev.Id);
                beatPlanIds.add(ev.Beat_plan__c);
            }
        }
        
        System.debug('Found ' + beatPlanIds.size() + ' Beat Plan IDs to delete: ' + beatPlanIds);
        
        // If there are Beat Plans to delete
        if(!beatPlanIds.isEmpty()) {
            try {
                // Query all Beat Plans that need to be deleted
                // WITHOUT SHARING allows this to work regardless of user permissions
                List<Beat_Plan__c> beatPlansToDelete = [
                    SELECT Id
                    FROM Beat_Plan__c
                    WHERE Id IN :beatPlanIds
                ];
                
                // Delete the Beat Plans (allows user to log in)
                if(!beatPlansToDelete.isEmpty()) {
                    delete beatPlansToDelete;
                    System.debug('Cascade deleted ' + beatPlansToDelete.size() + ' Beat_Plan__c records');
                }
            } catch(Exception e) {
                System.debug('Error deleting Beat Plans: ' + e.getMessage());
                System.debug('Error stack trace: ' + e.getStackTraceString());
                
                // Add error to Event record so user sees the failure
                for(Event ev : eventsBeingDeleted) {
                    if(ev.Beat_plan__c != null && beatPlanIds.contains(ev.Beat_plan__c)) {
                        ev.addError('Cannot delete leave: ' + e.getMessage() + '. Please contact your administrator.');
                    }
                }
            }
        }
    }
    /* commented by Hitarth
    public static void sendEmailToUserAfterCheckOut(List<Event> eventList,Map<Id,Event> oldMapOfEvent){
        
        Set<String> callTypeSet = new Set<String>{'MKTG/Conf/In Clinic Planning'};
            User currentUser =[SELECT Id,Name,Reporting_manager_for_Inclining_branding__r.Name,Reporting_manager_for_Inclining_branding__r.Email,Reporting_manager_for_Inclining_branding__c FROM User WHERE Id =:UserInfo.getUserId() LIMIT 1]??Null;
        
        if (currentUser?.Reporting_manager_for_Inclining_branding__c == null) {  return;  }
        if (String.isBlank(currentUser.Reporting_manager_for_Inclining_branding__r.Email)) { return; }
        List<Event> filterEventList = new List<Event>();
        for(Event evt: eventList){ if(evt.Target__c == Null && !String.isBlank(evt.Product_Family__c) && callTypeSet.contains(evt.Call_Type__c) && evt.Check_Out__c && (oldMapOfEvent == Null || evt.Check_Out__c != oldMapOfEvent.get(evt.Id).Check_Out__c)){  filterEventList.add(evt);  }}
        System.debug('filterEventList----'+filterEventList);
        if (filterEventList.isEmpty()) { return; }
        String orgDomainUrl = URL.getOrgDomainUrl().toExternalForm();
        String siteDomainUrl = orgDomainUrl.replace('.my.salesforce.com', '.my.site.com');
        List<Site> sites = [  SELECT UrlPathPrefix  FROM Site  WHERE Status = 'Active' AND UrlPathPrefix = 'BioTechPortal'  LIMIT 1 ];
        
        String orgBaseUrl = !sites.isEmpty()
            ? siteDomainUrl + '/' + sites[0].UrlPathPrefix
            : siteDomainUrl;
        System.debug('orgBaseUrl'+orgBaseUrl);
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        String managerName = currentUser.Reporting_manager_for_Inclining_branding__r.Name;
        String managerEmail = currentUser.Reporting_manager_for_Inclining_branding__r.Email;
        
        
        for (Event evt : filterEventList) {
            String approvalLink = orgBaseUrl + '/eventapprovalprocess?id=' + evt.Id;
            
            String emailBody = 'Hello ' + managerName + ',<br/><br/>';
            emailBody += 'Your team member, ' + currentUser.Name + ', has submitted a request for approval of an ';
            emailBody += 'In-Clinic Branding activity that has been completed.<br/><br/>';
            emailBody += 'Please review the details and the attached document using the link below, ';
            emailBody += 'and share your comments (if any), along with your approval or rejection, ';
            emailBody += 'so the task can be closed successfully.<br/><br/>';
            emailBody += 'Link: <a href="' + approvalLink + '">' + approvalLink + '</a><br/><br/>';
            emailBody += 'Regards,<br/>Biotech Healthcare<br/><br/>';
            emailBody += '<i>(This is an auto-generated notification from the Salesforce system. Please do not reply to this email.)</i>';
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            //mail.setToAddresses(new String[] { managerEmail });
            mail.setToAddresses(new String[] { 'hitarth@creatiquetech.com' });
            mail.setSubject('Approval Request: In-Clinic Branding Activity - ' + evt.Subject);
            mail.setHtmlBody(emailBody);
            mail.setSaveAsActivity(false);
            
            emailsToSend.add(mail);
        }
        System.debug('emailsToSend'+emailsToSend);
        // 5. Send emails in bulk, with allOrNone = false so one failure doesn't block the rest
        if (!emailsToSend.isEmpty()) {
            List<Messaging.SendEmailResult> results = Messaging.sendEmail(emailsToSend, false);
            System.debug('results'+results);
            for (Messaging.SendEmailResult result : results) {
                if (!result.isSuccess()) {
                    for (Messaging.SendEmailError err : result.getErrors()) {
                        System.debug(LoggingLevel.ERROR, 'Failed to send approval email: ' + err.getMessage());
                    }
                }
            }
        }
    }
    public static void sendApproveRejectEmail(List<Event> eventList, Map<Id, Event> oldMapOfEvent) {
        
        
        
        if (oldMapOfEvent == null || oldMapOfEvent.isEmpty()) {
            return;
        }
        
         In_Clining_Branding_site_url__c urls =
            In_Clining_Branding_site_url__c.getValues('In Clining Branding');    
		      
        Set<String> approvalState = new Set<String>{ 'Approved', 'Rejected' };
            List<Event> filteredEventList = new List<Event>();
        
        for (Event evt : eventList) {
            Event oldEvt = oldMapOfEvent.get(evt.Id);
            if (approvalState.contains(evt.Approval_Status__c)  && oldEvt != null  && evt.Approval_Status__c != oldEvt.Approval_Status__c) {  filteredEventList.add(evt);  }
        }
        
        if (filteredEventList.isEmpty()) {  return;  }
        
        Set<Id> ownerIds = new Set<Id>();
        for (Event evt : filteredEventList) { ownerIds.add(evt.OwnerId);  }
        
        Map<Id, User> ownerMap = new Map<Id, User>([  SELECT Id, Name, Email  FROM User  WHERE Id IN :ownerIds]);
        
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        
        for (Event evt : filteredEventList) {
            String reApprovalLink = urls.reporty_user_page__c + evt.Id;
            User owner = ownerMap.get(evt.OwnerId);
            if (owner == null || String.isBlank(owner.Email)) {  continue; }
            String emailBody = 'Hello ' + owner.Name + ',<br/><br/>';
            emailBody += 'Your submitted a request for approval of an In-Clinic Branding activity that has been ';
            emailBody += evt.Approval_Status__c + '.<br/><br/>';
            emailBody += 'Please review the details and the attached document using the link below, ';
            emailBody += 'and share your comments (if any), along with your approval or rejection, ';
            emailBody += 'so the task can be closed successfully.<br/><br/>';
            
            if(evt.Approval_Status__c == 'Rejected'){
                 emailBody += 'Link:'+reApprovalLink;
            }
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            //  mail.setToAddresses(new String[] { 'varish@creatiquetech.com' });
            // mail.setToAddresses(new String[] { owner.Email });
            mail.setToAddresses(new String[] { 'hitarth@creatiquetech.com' });
            mail.setSubject('In-Clinic Branding Activity ' + evt.Approval_Status__c + ' - ' + evt.Subject);
            mail.setHtmlBody(emailBody);
            mail.setSaveAsActivity(false);
            emailsToSend.add(mail);
        }
        
        if (!emailsToSend.isEmpty()) {
            Messaging.sendEmail(emailsToSend, false);
        }
    }*/
}
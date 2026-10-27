public without sharing class MOMAttendeeNotificationService {

    private static final String SUMMARY_TEMPLATE = 'MOM_Meeting_Summary_Notification';

    public class Request {
        @InvocableVariable(required=true label='Task Id')
        public Id taskId;

        @InvocableVariable(label='Sender Email (OrgWide Email Address)')
        public String senderEmail;

        @InvocableVariable(label='Template Developer Name (optional, defaults to MOM_Meeting_Summary_Notification)')
        public String templateDeveloperName;
    }

    @InvocableMethod(
        label='Send Meeting Summary Notifications'
        description='Sends meeting summary to all attendees and the distributor on MOM Action Item creation'
    )
    public static void sendAttendeeNotifications(List<Request> requests) {
        if (requests == null || requests.isEmpty()) return;

        Set<Id> taskIds = new Set<Id>();
        Map<Id, String> taskIdToTemplate = new Map<Id, String>();
        for (Request req : requests) {
            if (req.taskId == null) continue;
            taskIds.add(req.taskId);
            taskIdToTemplate.put(req.taskId,
                String.isNotBlank(req.templateDeveloperName) ? req.templateDeveloperName : SUMMARY_TEMPLATE);
        }
        if (taskIds.isEmpty()) return;

        List<Task> tasks = [
            SELECT Id, Attendees__c,
                   Meeting__r.Distributor__r.E_Mail__c,
                   Meeting__r.Meeting_Attendees__c
            FROM   Task
            WHERE  Id IN :taskIds
        ];

        String senderEmail = null;
        for (Request r : requests) {
            if (String.isNotBlank(r.senderEmail)) { senderEmail = r.senderEmail; break; }
        }

        // ── Collect all attendee User IDs across all tasks ─────────────────────
        Set<Id> attendeeUserIds = new Set<Id>();
        for (Task t : tasks) {
            if (String.isBlank(t.Attendees__c)) continue;
            try {
                List<Object> atts = (List<Object>) JSON.deserializeUntyped(t.Attendees__c);
                for (Object att : atts) {
                    if (att instanceof Map<String, Object>) {
                        String userId = (String) ((Map<String, Object>) att).get('id');
                        if (String.isNotBlank(userId)) attendeeUserIds.add((Id) userId);
                    }
                }
            } catch (Exception e) {}
        }

        // ── Bulk query User emails ─────────────────────────────────────────────
        Map<Id, String> userEmailMap = new Map<Id, String>();
        if (!attendeeUserIds.isEmpty()) {
            for (User u : [SELECT Id, Email FROM User WHERE Id IN :attendeeUserIds AND IsActive = true]) {
                if (String.isNotBlank(u.Email)) userEmailMap.put(u.Id, u.Email);
            }
        }

        List<MOMEmailService.EmailRequest> emailRequests = new List<MOMEmailService.EmailRequest>();

        for (Task t : tasks) {
            Set<String> sentEmails = new Set<String>();

            // ── Send to each action item attendee ─────────────────────────────
            if (String.isNotBlank(t.Attendees__c)) {
                List<Object> attendees;
                try {
                    attendees = (List<Object>) JSON.deserializeUntyped(t.Attendees__c);
                } catch (Exception e) {
                    attendees = new List<Object>();
                }
                for (Object att : attendees) {
                    String email;
                    if (att instanceof String) {
                        email = (String) att;
                    } else {
                        Map<String, Object> attendeeMap = (Map<String, Object>) att;
                        String userId = (String) attendeeMap.get('id');
                        email = String.isNotBlank(userId) ? userEmailMap.get((Id) userId) : null;
                    }
                    if (String.isBlank(email)) continue;
                    sentEmails.add(email.toLowerCase());

                    MOMEmailService.EmailRequest req = new MOMEmailService.EmailRequest();
                    req.templateDeveloperName = taskIdToTemplate.get(t.Id);
                    req.toEmailAddress        = email;
                    req.whatId                = String.valueOf(t.Id);
                    req.senderEmail           = senderEmail;
                    emailRequests.add(req);
                }
            }

            // ── Send to meeting-level attendees (all action items) ─────────────
            if (t.Meeting__r != null && String.isNotBlank(t.Meeting__r.Meeting_Attendees__c)) {
                List<Object> meetingAtts;
                try {
                    meetingAtts = (List<Object>) JSON.deserializeUntyped(t.Meeting__r.Meeting_Attendees__c);
                } catch (Exception e) {
                    meetingAtts = new List<Object>();
                }
                for (Object att : meetingAtts) {
                    if (!(att instanceof String)) continue;
                    String email = (String) att;
                    if (String.isBlank(email) || sentEmails.contains(email.toLowerCase())) continue;
                    sentEmails.add(email.toLowerCase());

                    MOMEmailService.EmailRequest req = new MOMEmailService.EmailRequest();
                    req.templateDeveloperName = taskIdToTemplate.get(t.Id);
                    req.toEmailAddress        = email;
                    req.whatId                = String.valueOf(t.Id);
                    req.senderEmail           = senderEmail;
                    emailRequests.add(req);
                }
            }

            // ── Send to distributor ────────────────────────────────────────────
            String distributorEmail = null;
            if (t.Meeting__r != null && t.Meeting__r.Distributor__r != null) {
                distributorEmail = t.Meeting__r.Distributor__r.E_Mail__c;
            }
            if (String.isNotBlank(distributorEmail)) {
                MOMEmailService.EmailRequest req = new MOMEmailService.EmailRequest();
                req.templateDeveloperName = taskIdToTemplate.get(t.Id);
                req.toEmailAddress        = distributorEmail;
                req.whatId                = String.valueOf(t.Id);
                req.senderEmail           = senderEmail;
                emailRequests.add(req);
            }
        }

        if (!emailRequests.isEmpty()) {
            MOMEmailService.sendEmail(emailRequests);
        }
    }
}
// without sharing: required so BDMs can create Tasks owned by other users
public without sharing class MomCreateMeetingService {

    @AuraEnabled
    public static Id createMeetingWithActionItems(
        Id     distributorId,
        String meetingTopic,
        String meetingAttendeesJson,
        String meetingDate,
        String meetingType,
        String region,
        String discussionSummary,
        String actionItemsJson
    ) {
        if (String.isBlank(meetingTopic) || String.isBlank(meetingDate) || String.isBlank(meetingType) || String.isBlank(region)) {
            throw new AuraHandledException('Required meeting fields are missing.');
        }

        List<MomActionItemDto> actionItems = String.isBlank(actionItemsJson)
            ? new List<MomActionItemDto>()
            : (List<MomActionItemDto>) JSON.deserialize(actionItemsJson, List<MomActionItemDto>.class);

        List<MomActionItemDto> validItems = new List<MomActionItemDto>();
        for (MomActionItemDto dto : actionItems) {
            if (!String.isBlank(dto.subject)) {
                validItems.add(dto);
            }
        }

        Integer rowNum = 1;
        for (MomActionItemDto dto : validItems) {
            if (String.isBlank(dto.subject)) {
                throw new AuraHandledException('Row ' + rowNum + ': Description is required.');
            }
            rowNum++;
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Id currentUserId = UserInfo.getUserId();
            MOM_Meeting__c mtg        = new MOM_Meeting__c();
            mtg.Distributor__c        = distributorId;
            mtg.Meeting_Topic__c      = meetingTopic;
            mtg.Meeting_Attendees__c  = meetingAttendeesJson;
            mtg.Meeting_Owner__c      = currentUserId;
            mtg.OwnerId               = currentUserId;
            mtg.Meeting_Date__c       = Date.valueOf(meetingDate);
            mtg.Meeting_Type__c       = meetingType;
            mtg.Region_Set__c         = region;
            mtg.Discussion_Summary__c = discussionSummary;
            mtg.Status__c             = 'Draft';
            insert mtg;

            if (!validItems.isEmpty()) {
                Id rtId = Schema.SObjectType.Task
                    .getRecordTypeInfosByDeveloperName()
                    .get('MOM_Action_Item')
                    .getRecordTypeId();

                DeptUserResolution res = resolveDeptUsers(validItems);

                List<Task> tasks          = new List<Task>();
                List<String> directEmails = new List<String>();

                for (MomActionItemDto dto : validItems) {
                    Task t                      = new Task();
                    t.Subject                   = dto.subject;
                    Id ownerId                  = res.deptToUserId.get(dto.responsibleDepartment);
                    if (ownerId != null) {
                        t.OwnerId = ownerId;
                        directEmails.add(null); // SF user → flow handles assignment email
                    } else {
                        String cmtEmail = res.deptToCmtEmail.get(dto.responsibleDepartment);
                        directEmails.add(cmtEmail);
                    }
                    t.ActivityDate              = String.isNotBlank(dto.activityDate)
                                                    ? Date.valueOf(dto.activityDate) : null;
                    t.Status                    = dto.status;
                    t.Priority                  = dto.priority;
                    t.Responsible_Department__c = dto.responsibleDepartment;
                    t.Attendees__c              = dto.attendeesJson;
                    t.Meeting__c                = mtg.Id;
                    t.RecordTypeId              = rtId;
                    t.Guest_Access_Token__c     = generateToken();
                    tasks.add(t);
                }
                insert tasks;

                // Send assignment emails directly for depts with no matching SF user
                Map<Id, String> directEmailByTask = new Map<Id, String>();
                for (Integer i = 0; i < tasks.size(); i++) {
                    String email = directEmails.get(i);
                    if (String.isNotBlank(email)) {
                        directEmailByTask.put(tasks.get(i).Id, email);
                    }
                }
                sendDirectAssignmentEmails(directEmailByTask);
            }

            return mtg.Id;

        } catch (AuraHandledException e) {
            Database.rollback(sp);
            throw e;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static String generateToken() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 32);
    }

    // ── Sends assignment emails directly to CMT email addresses (non-SF users) ─
    private static void sendDirectAssignmentEmails(Map<Id, String> taskIdToEmail) {
        if (taskIdToEmail == null || taskIdToEmail.isEmpty()) return;

        String senderEmail = null;
        List<MOM_Config__mdt> configs = [
            SELECT Sender_Email__c FROM MOM_Config__mdt
            WHERE  DeveloperName = 'Default' LIMIT 1
        ];
        if (!configs.isEmpty() && String.isNotBlank(configs[0].Sender_Email__c)) {
            senderEmail = configs[0].Sender_Email__c;
        }

        List<MOMEmailService.EmailRequest> reqs = new List<MOMEmailService.EmailRequest>();
        for (Id taskId : taskIdToEmail.keySet()) {
            MOMEmailService.EmailRequest req = new MOMEmailService.EmailRequest();
            req.templateDeveloperName = 'MOM_Assignment_Notification';
            req.toEmailAddress        = taskIdToEmail.get(taskId);
            req.whatId                = taskId;
            req.senderEmail           = senderEmail;
            reqs.add(req);
        }
        MOMEmailService.sendEmail(reqs);
    }

    // ── Resolution result: SF user map + raw CMT email map ───────────────────
    private class DeptUserResolution {
        Map<String, Id>     deptToUserId   = new Map<String, Id>();
        Map<String, String> deptToCmtEmail = new Map<String, String>();
    }

    // ── Resolve CMT dept labels → SF User Ids AND raw CMT emails ─────────────
    private static DeptUserResolution resolveDeptUsers(List<MomActionItemDto> items) {
        Set<String> deptLabels = new Set<String>();
        for (MomActionItemDto dto : items) {
            if (String.isNotBlank(dto.responsibleDepartment)) {
                deptLabels.add(dto.responsibleDepartment);
            }
        }

        DeptUserResolution res = new DeptUserResolution();
        if (deptLabels.isEmpty()) return res;

        Map<String, String> deptToEmail = new Map<String, String>();
        for (Department_Users_Emails__mdt rec : [
            SELECT Label, To_Mail_ID__c
            FROM   Department_Users_Emails__mdt
            WHERE  Label IN :deptLabels
        ]) {
            if (String.isNotBlank(rec.To_Mail_ID__c)) {
                deptToEmail.put(rec.Label, rec.To_Mail_ID__c);
                res.deptToCmtEmail.put(rec.Label, rec.To_Mail_ID__c);
            }
        }

        if (deptToEmail.isEmpty()) return res;

        Set<String> emails = new Set<String>(deptToEmail.values());
        Map<String, Id> emailToUserId = new Map<String, Id>();
        for (User u : [
            SELECT Id, Email FROM User
            WHERE  Email IN :emails
            AND    IsActive = true
        ]) {
            emailToUserId.put(u.Email.toLowerCase(), u.Id);
        }

        for (String deptLabel : deptToEmail.keySet()) {
            String email = deptToEmail.get(deptLabel).toLowerCase();
            Id userId    = emailToUserId.get(email);
            if (userId != null) res.deptToUserId.put(deptLabel, userId);
        }

        return res;
    }
}
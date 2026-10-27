public without sharing class MomMeetingService {

    // ── Department options grouped by category (drives LWC category → dept flow) ─
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getDeptsByCategory() {
        Map<String, List<String>> result = new Map<String, List<String>>();
        for (Department_Users_Emails__mdt rec : [
            SELECT Label, Category__c
            FROM   Department_Users_Emails__mdt
            ORDER  BY Category__c ASC, Label ASC
        ]) {
            String cat = String.isNotBlank(rec.Category__c) ? rec.Category__c : 'Other';
            if (!result.containsKey(cat)) {
                result.put(cat, new List<String>());
            }
            result.get(cat).add(rec.Label);
        }
        return result;
    }

    // ── Fetch action items for a meeting ──────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<MomActionItemDto> getActionItems(Id meetingId) {
        if (meetingId == null) {
            throw new AuraHandledException('Meeting ID is required.');
        }
        try {
            List<Task> tasks = [
                SELECT Id, Subject, OwnerId,
                       ActivityDate, Status, Priority, Responsible_Department__c,
                       Attendees__c, Target_Week__c, Completion_Week__c
                FROM   Task
                WHERE  Meeting__c = :meetingId
                AND    RecordType.DeveloperName = 'MOM_Action_Item'
                //WITH   USER_MODE
                ORDER  BY CreatedDate ASC
            ];

            Set<Id> ownerIds = new Set<Id>();
            for (Task t : tasks) {
                if (t.OwnerId != null) ownerIds.add(t.OwnerId);
            }
            Map<Id, String> ownerNameMap = new Map<Id, String>();
            for (User u : [
                SELECT Id, Name FROM User
                WHERE  Id IN :ownerIds
                WITH   USER_MODE
            ]) {
                ownerNameMap.put(u.Id, u.Name);
            }

            // Resolve department label → category from CMT
            Set<String> deptLabels = new Set<String>();
            for (Task t : tasks) {
                if (String.isNotBlank(t.Responsible_Department__c)) {
                    deptLabels.add(t.Responsible_Department__c);
                }
            }
            Map<String, String> labelToCategory = new Map<String, String>();
            if (!deptLabels.isEmpty()) {
                for (Department_Users_Emails__mdt rec : [
                    SELECT Label, Category__c
                    FROM   Department_Users_Emails__mdt
                    WHERE  Label IN :deptLabels
                ]) {
                    labelToCategory.put(rec.Label, rec.Category__c);
                }
            }

            List<MomActionItemDto> result = new List<MomActionItemDto>();
            for (Task t : tasks) {
                MomActionItemDto dto      = new MomActionItemDto();
                dto.id                    = t.Id;
                dto.taskIdsJson           = JSON.serialize(new List<Id>{ t.Id });
                dto.subject               = t.Subject;
                dto.ownerId               = t.OwnerId;
                dto.ownerName             = ownerNameMap.get(t.OwnerId);
                dto.activityDate          = t.ActivityDate != null
                                              ? String.valueOf(t.ActivityDate) : null;
                dto.status                = t.Status;
                dto.priority              = t.Priority;
                dto.category              = labelToCategory.get(t.Responsible_Department__c);
                dto.responsibleDepartment = t.Responsible_Department__c;
                dto.attendeesJson         = t.Attendees__c;
                dto.targetWeek            = t.Target_Week__c;
                dto.completionWeek        = t.Completion_Week__c;
                result.add(dto);
            }
            return result;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Save (insert/update + delete) action items ────────────────────────────
    @AuraEnabled
    public static void saveActionItems(
        Id       meetingId,
        String   itemsToSaveJson,
        List<Id> itemsToDelete
    ) {
        if (meetingId == null) {
            throw new AuraHandledException('Meeting ID is required.');
        }
        try {
            List<MomActionItemDto> itemsToSave = String.isBlank(itemsToSaveJson)
                ? new List<MomActionItemDto>()
                : (List<MomActionItemDto>) JSON.deserialize(itemsToSaveJson, List<MomActionItemDto>.class);

            // ── Delete ────────────────────────────────────────────────────────
            if (itemsToDelete != null && !itemsToDelete.isEmpty()) {
                List<Task> toDelete = [
                    SELECT Id FROM Task
                    WHERE  Id IN :itemsToDelete
                    WITH   USER_MODE
                ];
                delete toDelete;
            }

            if (!itemsToSave.isEmpty()) {
                Id rtId = Schema.SObjectType.Task
                    .getRecordTypeInfosByDeveloperName()
                    .get('MOM_Action_Item')
                    .getRecordTypeId();

                // Resolve CMT → User Id + raw email for new items
                List<MomActionItemDto> newItems = new List<MomActionItemDto>();
                for (MomActionItemDto dto : itemsToSave) {
                    if (dto.id == null) newItems.add(dto);
                }
                DeptUserResolution newRes = resolveDeptUsers(newItems);

                // Query existing task dept values for change detection
                Set<Id> existingIds = new Set<Id>();
                for (MomActionItemDto dto : itemsToSave) {
                    if (dto.id != null) existingIds.add(dto.id);
                }
                Map<Id, Task> existingTaskMap = new Map<Id, Task>();
                if (!existingIds.isEmpty()) {
                    for (Task t : [
                        SELECT Id, Responsible_Department__c, Attendees__c
                        FROM   Task
                        WHERE  Id IN :existingIds
                        WITH   USER_MODE
                    ]) {
                        existingTaskMap.put(t.Id, t);
                    }
                }

                // Resolve new dept → User + raw email for update items where dept changed
                List<MomActionItemDto> deptChangedDtos = new List<MomActionItemDto>();
                for (MomActionItemDto dto : itemsToSave) {
                    if (dto.id != null) {
                        Task existing = existingTaskMap.get(dto.id);
                        if (existing != null && existing.Responsible_Department__c != dto.responsibleDepartment) {
                            deptChangedDtos.add(dto);
                        }
                    }
                }
                DeptUserResolution changedRes = resolveDeptUsers(deptChangedDtos);

                List<Task> toUpdate = new List<Task>();
                List<Task> toInsert = new List<Task>();
                // Tracks tasks that need a direct-email assignment notification
                // (CMT email set but no matching SF user → flow won't fire)
                Map<Id, String> directEmailByTask = new Map<Id, String>();
                // Parallel list to toInsert for non-SF-user direct emails
                List<String> insertDirectEmails   = new List<String>();

                for (MomActionItemDto dto : itemsToSave) {
                    if (dto.id != null) {
                        // ── Update existing tasks in this row ──────────────────
                        List<Id> tIds = String.isBlank(dto.taskIdsJson)
                            ? new List<Id>{ dto.id }
                            : (List<Id>) JSON.deserialize(dto.taskIdsJson, List<Id>.class);

                        Task existing    = existingTaskMap.get(dto.id);
                        Boolean deptChanged = existing != null
                            && existing.Responsible_Department__c != dto.responsibleDepartment;

                        for (Id tId : tIds) {
                            Task t                      = new Task();
                            t.Id                        = tId;
                            t.Subject                   = dto.subject;
                            t.ActivityDate              = dto.activityDate != null
                                                            ? Date.valueOf(dto.activityDate) : null;
                            t.Status                    = dto.status;
                            t.Priority                  = dto.priority;
                            t.Responsible_Department__c = dto.responsibleDepartment;
                            t.Attendees__c              = dto.attendeesJson;
                            t.Meeting__c                = meetingId;
                            t.RecordTypeId              = rtId;
                            if (deptChanged) {
                                Id newOwnerId = changedRes.deptToUserId.get(dto.responsibleDepartment);
                                if (newOwnerId != null) {
                                    t.OwnerId = newOwnerId;
                                } else {
                                    // No SF user — flow won't fire; mark for direct email
                                    String cmtEmail = changedRes.deptToCmtEmail.get(dto.responsibleDepartment);
                                    if (String.isNotBlank(cmtEmail)) {
                                        directEmailByTask.put(tId, cmtEmail);
                                    }
                                }
                                t.Guest_Access_Token__c = generateToken();
                            }
                            toUpdate.add(t);
                        }
                    } else {
                        // ── New item: one Task, owner from CMT ─────────────────
                        Task t                      = new Task();
                        t.Subject                   = dto.subject;
                        Id ownerId                  = newRes.deptToUserId.get(dto.responsibleDepartment);
                        if (ownerId != null) {
                            t.OwnerId = ownerId;
                            insertDirectEmails.add(null); // SF user → flow handles email
                        } else {
                            // No SF user — mark for direct email after insert
                            String cmtEmail = newRes.deptToCmtEmail.get(dto.responsibleDepartment);
                            insertDirectEmails.add(cmtEmail);
                        }
                        t.ActivityDate              = dto.activityDate != null
                                                        ? Date.valueOf(dto.activityDate) : null;
                        t.Status                    = dto.status;
                        t.Priority                  = dto.priority;
                        t.Responsible_Department__c = dto.responsibleDepartment;
                        t.Attendees__c              = dto.attendeesJson;
                        t.Meeting__c                = meetingId;
                        t.RecordTypeId              = rtId;
                        t.Guest_Access_Token__c     = generateToken();
                        toInsert.add(t);
                    }
                }

                if (!toUpdate.isEmpty()) update toUpdate;
                if (!toInsert.isEmpty()) {
                    insert toInsert;
                    // Collect direct emails for inserted tasks with no SF user
                    for (Integer i = 0; i < toInsert.size(); i++) {
                        String email = insertDirectEmails.get(i);
                        if (String.isNotBlank(email)) {
                            directEmailByTask.put(toInsert.get(i).Id, email);
                        }
                    }
                }

                sendDirectAssignmentEmails(directEmailByTask);
            }
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
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
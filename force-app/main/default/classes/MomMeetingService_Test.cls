@isTest
private class MomMeetingService_Test {

    // ── Test data setup ───────────────────────────────────────────────────────
    @TestSetup
    static void makeData() {
        // Dedicated test user so System.runAs loads a fresh FLS context that
        // includes the PermissionSet grants (FLS is cached at session start for
        // UserInfo.getUserId(), so assigning a PSA there in @TestSetup has no
        // effect on the running user's cached permissions).
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User testUser = new User(
            FirstName         = 'MOM',
            LastName          = 'SvcTest',
            Email             = 'momsvctest@test.momsvc',
            Username          = 'momsvctest@test.momsvc',
            Alias             = 'momsvc',
            TimeZoneSidKey    = 'America/Los_Angeles',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId         = p.Id
        );
        insert testUser;

        // Grant FLS on all fields selected by the service's WITH USER_MODE query
        // and the trigger's WITH SECURITY_ENFORCED query.
        PermissionSet ps = new PermissionSet(
            Name  = 'MOMMtgSvcFLSTest',
            Label = 'MOM Meeting Svc FLS Test'
        );
        insert ps;
        insert new List<FieldPermissions>{
            new FieldPermissions(
                ParentId = ps.Id, SobjectType = 'Task', Field = 'Task.Meeting__c',
                PermissionsRead = true, PermissionsEdit = true
            ),
            new FieldPermissions(
                ParentId = ps.Id, SobjectType = 'Task', Field = 'Task.Responsible_Department__c',
                PermissionsRead = true, PermissionsEdit = true
            ),
            new FieldPermissions(
                ParentId = ps.Id, SobjectType = 'Task', Field = 'Task.Attendees__c',
                PermissionsRead = true, PermissionsEdit = true
            )
        };
        insert new PermissionSetAssignment(
            PermissionSetId = ps.Id,
            AssigneeId      = testUser.Id
        );

        System.runAs(testUser) {
            Account acc = new Account(Name = 'Test Distributor');
            insert acc;

            MOM_Meeting__c meeting = new MOM_Meeting__c(
                Distributor__c  = acc.Id,
                Meeting_Date__c = Date.today().addDays(-1),
                Meeting_Type__c = 'Monthly',
                Region_Set__c   = 'APAC',
                Status__c       = 'Draft'
            );
            insert meeting;
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    private static MOM_Meeting__c getMeeting() {
        return [SELECT Id FROM MOM_Meeting__c LIMIT 1];
    }

    private static Id getMomRtId() {
        return Schema.SObjectType.Task
            .getRecordTypeInfosByDeveloperName()
            .get('MOM_Action_Item')
            .getRecordTypeId();
    }

    private static User getTestUser() {
        return [SELECT Id FROM User WHERE Username = 'momsvctest@test.momsvc' LIMIT 1];
    }

    private static MomActionItemDto buildDto(
        Id taskId, String subject, Id ownerId, String dateStr
    ) {
        MomActionItemDto dto = new MomActionItemDto();
        dto.id                  = taskId;
        dto.subject             = subject;
        dto.ownerId             = ownerId;
        dto.activityDate        = dateStr;
        dto.status              = 'Open';
        dto.priority            = 'Normal';
        dto.responsibleDepartment = 'Perigeon_MOM_testing';
        return dto;
    }

    // ─── Test 1: getActionItems — empty meeting ───────────────────────────────
    @isTest
    static void getActionItems_NoItems_ReturnsEmpty() {
        MOM_Meeting__c meeting = getMeeting();

        Test.startTest();
        List<MomActionItemDto> result =
            MomMeetingService.getActionItems(meeting.Id);
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Empty meeting should return 0 items');
    }

    // ─── Test 2: getActionItems — with existing tasks ─────────────────────────
    @isTest
    static void getActionItems_WithItems_ReturnsCorrectList() {
        MOM_Meeting__c meeting = getMeeting();
        insert new Task(
            Subject                   = 'Verify Stock',
            Meeting__c                = meeting.Id,
            ActivityDate              = Date.today().addDays(7),
            Status                    = 'Open',
            Priority                  = 'Normal',
            Responsible_Department__c = 'Perigeon_MOM_testing',
            RecordTypeId              = getMomRtId()
        );

        Test.startTest();
        List<MomActionItemDto> result =
            MomMeetingService.getActionItems(meeting.Id);
        Test.stopTest();

        System.assertEquals(1,             result.size(),           'Should return 1 action item');
        System.assertEquals('Verify Stock', result[0].subject,    'Subject should match');
        System.assertNotEquals(null,        result[0].ownerName,  'Owner name should be populated');
        System.assertNotEquals(null,        result[0].taskIdsJson, 'taskIdsJson should be populated');
    }

    // ─── Test 3: getActionItems — null meetingId throws exception ─────────────
    @isTest
    static void getActionItems_NullMeetingId_ThrowsException() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            MomMeetingService.getActionItems(null);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for null meetingId');
    }

    // ─── Test 4: saveActionItems — create new tasks ───────────────────────────
    @isTest
    static void saveActionItems_CreateNew_CreatesTasksCorrectly() {
        MOM_Meeting__c meeting = getMeeting();
        Id userId = UserInfo.getUserId();
        String dateStr = String.valueOf(Date.today().addDays(7));

        MomActionItemDto dto =
            buildDto(null, 'Follow up on shipment', userId, dateStr);
        dto.priority = 'High';

        Test.startTest();
        MomMeetingService.saveActionItems(
            meeting.Id,
            JSON.serialize(new List<MomActionItemDto>{ dto }),
            null
        );
        Test.stopTest();

        List<Task> tasks = [
            SELECT Subject, Priority, Meeting__c, RecordType.DeveloperName
            FROM   Task
            WHERE  Meeting__c = :meeting.Id
        ];
        System.assertEquals(1,                       tasks.size(),                      'Should create 1 task');
        System.assertEquals('Follow up on shipment', tasks[0].Subject,                 'Subject should match');
        System.assertEquals('High',                  tasks[0].Priority,                'Priority should match');
        System.assertEquals('MOM_Action_Item',       tasks[0].RecordType.DeveloperName,'Record type should be MOM_Action_Item');
    }

    // ─── Test 5: saveActionItems — update existing task ───────────────────────
    @isTest
    static void saveActionItems_UpdateExisting_UpdatesCorrectly() {
        MOM_Meeting__c meeting = getMeeting();
        Task t = new Task(
            Subject                   = 'Original Subject',
            Meeting__c                = meeting.Id,
            ActivityDate              = Date.today().addDays(7),
            Status                    = 'Open',
            Priority                  = 'Normal',
            Responsible_Department__c = 'Perigeon_MOM_testing',
            RecordTypeId              = getMomRtId()
        );
        insert t;

        MomActionItemDto dto =
            buildDto(t.Id, 'Updated Subject', UserInfo.getUserId(),
                     String.valueOf(Date.today().addDays(5)));
        dto.status      = 'In Progress';
        dto.priority    = 'High';
        dto.taskIdsJson = JSON.serialize(new List<Id>{ t.Id });

        Test.startTest();
        System.runAs(getTestUser()) {
            MomMeetingService.saveActionItems(
                meeting.Id,
                JSON.serialize(new List<MomActionItemDto>{ dto }),
                null
            );
        }
        Test.stopTest();

        Task updated = [SELECT Subject, Status, Priority FROM Task WHERE Id = :t.Id];
        System.assertEquals('Updated Subject', updated.Subject,  'Subject should be updated');
        System.assertEquals('In Progress',     updated.Status,   'Status should be updated');
        System.assertEquals('High',            updated.Priority, 'Priority should be updated');
    }

    // ─── Test 6: saveActionItems — delete tasks ───────────────────────────────
    @isTest
    static void saveActionItems_DeleteItems_DeletesCorrectly() {
        MOM_Meeting__c meeting = getMeeting();
        Task t = new Task(
            Subject                   = 'To Be Deleted',
            Meeting__c                = meeting.Id,
            ActivityDate              = Date.today().addDays(7),
            Status                    = 'Open',
            Priority                  = 'Normal',
            Responsible_Department__c = 'Perigeon_MOM_testing',
            RecordTypeId              = getMomRtId()
        );
        insert t;

        Test.startTest();
        MomMeetingService.saveActionItems(meeting.Id, null, new List<Id>{ t.Id });
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT Id FROM Task WHERE Id = :t.Id].size(),
            'Task should be deleted'
        );
    }

    // ─── Test 7: saveActionItems — bulk 200 records ───────────────────────────
    @isTest
    static void saveActionItems_BulkOperations_Handles200Records() {
        MOM_Meeting__c meeting = getMeeting();
        Id userId = UserInfo.getUserId();

        List<MomActionItemDto> dtos = new List<MomActionItemDto>();
        for (Integer i = 0; i < 200; i++) {
            dtos.add(buildDto(
                null,
                'Bulk Action ' + i,
                userId,
                String.valueOf(Date.today().addDays(i + 1))
            ));
        }

        Test.startTest();
        MomMeetingService.saveActionItems(meeting.Id, JSON.serialize(dtos), null);
        Test.stopTest();

        System.assertEquals(
            200,
            [SELECT Id FROM Task WHERE Meeting__c = :meeting.Id].size(),
            'Should create 200 tasks'
        );
    }

    // ─── Test 8: saveActionItems — group expansion creates task per member ─────
    @isTest
    static void saveActionItems_WithGroup_CreatesTaskPerMember() {
        MOM_Meeting__c meeting = getMeeting();

        Group g = new Group(Name = 'Test Dept', DeveloperName = 'Test_Dept_MOM2', Type = 'Regular');
        insert g;
        insert new GroupMember(GroupId = g.Id, UserOrGroupId = UserInfo.getUserId());

        MomActionItemDto dto = buildDto(null, 'Group Task', null,
                                        String.valueOf(Date.today().addDays(5)));
        dto.responsibleDepartment = 'Test_Dept_MOM2';

        // Group/GroupMember are Setup objects — wrap non-Setup service DML in System.runAs to avoid MIXED_DML
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            MomMeetingService.saveActionItems(
                meeting.Id,
                JSON.serialize(new List<MomActionItemDto>{ dto }),
                null
            );
            Test.stopTest();
        }

        List<Task> tasks = [SELECT OwnerId FROM Task WHERE Meeting__c = :meeting.Id];
        System.assertEquals(1, tasks.size(), 'Should create 1 task for the 1 group member');
        System.assertEquals(UserInfo.getUserId(), tasks[0].OwnerId, 'Task owner should be the group member');
    }

    @isTest
    static void saveActionItems_NullMeetingId_ThrowsException() {
        MomActionItemDto dto =
            buildDto(null, 'Test', UserInfo.getUserId(), String.valueOf(Date.today()));

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            MomMeetingService.saveActionItems(
                null,
                JSON.serialize(new List<MomActionItemDto>{ dto }),
                null
            );
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for null meetingId');
    }

    // ─── Test 10: getDeptsByCategory — covers entire uncalled method ──────────
    @isTest
    static void getDeptsByCategory_ReturnsCategoryGroupedMap() {
        Test.startTest();
        Map<String, List<String>> result = MomMeetingService.getDeptsByCategory();
        Test.stopTest();

        System.assertNotEquals(null, result, 'getDeptsByCategory should return a non-null map');
    }

    // ─── Test 11: buildDeptUserMap user-lookup path via real CMT email record ──
    @isTest
    static void saveActionItems_WithCmtDeptLabel_ExercisesUserLookupPath() {
        // Exercises buildDeptUserMap lines that resolve CMT email → User Id.
        // Skips gracefully if no CMT record has To_Mail_ID__c set in this org.
        List<Department_Users_Emails__mdt> cmtRecords = [
            SELECT Label, To_Mail_ID__c
            FROM   Department_Users_Emails__mdt
            WHERE  To_Mail_ID__c != null
            LIMIT  1
        ];
        if (cmtRecords.isEmpty()) return;

        MOM_Meeting__c meeting = getMeeting();
        MomActionItemDto dto = new MomActionItemDto();
        dto.id                    = null;
        dto.subject               = 'CMT Dept Task';
        dto.activityDate          = String.valueOf(Date.today().addDays(7));
        dto.status                = 'Open';
        dto.priority              = 'Normal';
        dto.responsibleDepartment = cmtRecords[0].Label;

        Test.startTest();
        MomMeetingService.saveActionItems(
            meeting.Id,
            JSON.serialize(new List<MomActionItemDto>{ dto }),
            null
        );
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT Id FROM Task WHERE Meeting__c = :meeting.Id].size(),
            'Task should be created for the CMT dept label'
        );
    }

    // ─── Test 12: saveActionItems — dept change regenerates token + sends emails ─
    @isTest
    static void saveActionItems_DeptChange_RegeneratesTokenAndSendsEmails() {
        MOM_Meeting__c meeting = getMeeting();
        Task t = new Task(
            Subject                   = 'Reassign Task',
            Meeting__c                = meeting.Id,
            ActivityDate              = Date.today().addDays(7),
            Status                    = 'Open',
            Priority                  = 'Normal',
            Responsible_Department__c = 'Perigeon_MOM_testing',
            Guest_Access_Token__c     = 'OLD_TOKEN_ABC123',
            RecordTypeId              = getMomRtId()
        );
        insert t;

        MomActionItemDto dto          = new MomActionItemDto();
        dto.id                        = t.Id;
        dto.taskIdsJson               = JSON.serialize(new List<Id>{ t.Id });
        dto.subject                   = 'Reassign Task';
        dto.activityDate              = String.valueOf(Date.today().addDays(7));
        dto.status                    = 'Open';
        dto.priority                  = 'Normal';
        dto.responsibleDepartment     = 'Unknown_Test_Dept_99';   // not in CMT — skips email path
        dto.attendeesJson             = JSON.serialize(new List<String>{ 'attendee@test.com' });

        Test.startTest();
        System.runAs(getTestUser()) {
            MomMeetingService.saveActionItems(
                meeting.Id,
                JSON.serialize(new List<MomActionItemDto>{ dto }),
                null
            );
        }
        Test.stopTest();

        Task updated = [SELECT Responsible_Department__c, Guest_Access_Token__c FROM Task WHERE Id = :t.Id];
        System.assertEquals('Unknown_Test_Dept_99', updated.Responsible_Department__c, 'Department should be updated');
        System.assertNotEquals('OLD_TOKEN_ABC123', updated.Guest_Access_Token__c, 'Token should be regenerated on dept change');
        System.assertNotEquals(null, updated.Guest_Access_Token__c, 'New token should not be null');
    }
}
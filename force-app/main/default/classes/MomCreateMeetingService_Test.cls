@isTest
private class MomCreateMeetingService_Test {

    // ── Test data setup ───────────────────────────────────────────────────────
    @TestSetup
    static void makeData() {
        insert new Account(Name = 'Test Distributor');
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    private static Account getAccount() {
        return [SELECT Id FROM Account LIMIT 1];
    }

    private static MomActionItemDto buildActionItem(Integer dayOffset) {
        MomActionItemDto dto = new MomActionItemDto();
        dto.subject               = 'Test Action ' + dayOffset;
        dto.ownerId               = UserInfo.getUserId();
        dto.activityDate          = String.valueOf(Date.today().addDays(dayOffset));
        dto.status                = 'Open';
        dto.priority              = 'Normal';
        dto.responsibleDepartment = 'Perigeon_MOM_testing';
        return dto;
    }

    // ─── Test 1: Create meeting with no action items ──────────────────────────
    @isTest
    static void createMeeting_NoActionItems_CreatesMeetingOnly() {
        Account acc = getAccount();
        Id meetingId;

        Test.startTest();
        try {
            meetingId = MomCreateMeetingService.createMeetingWithActionItems(
                acc.Id,
                'Test Topic',
                null,
                String.valueOf(Date.today()),
                'Monthly',
                'APAC',
                'Test summary',
                null
            );
        } catch (Exception e) {
            System.assert(false,
                'createMeeting_NoActionItems failed — check org flows/validation rules. ' +
                'Type: ' + e.getTypeName() + ' | Stack: ' + e.getStackTraceString());
        }
        Test.stopTest();

        System.assertNotEquals(null, meetingId, 'Meeting ID should be returned');
        MOM_Meeting__c mtg = [
            SELECT Distributor__c, Meeting_Type__c, Region_Set__c, Status__c, Meeting_Owner__c
            FROM   MOM_Meeting__c
            WHERE  Id = :meetingId
        ];
        System.assertEquals(acc.Id,                mtg.Distributor__c,    'Distributor should match');
        System.assertEquals('Monthly',             mtg.Meeting_Type__c,   'Meeting type should match');
        System.assertEquals('APAC', mtg.Region_Set__c,     'Region should match');
        System.assertEquals('Draft',               mtg.Status__c,         'Status should default to Draft');
        System.assertEquals(UserInfo.getUserId(),  mtg.Meeting_Owner__c,  'Owner should be the creating user');
        System.assertEquals(0,
            [SELECT Id FROM Task WHERE Meeting__c = :meetingId].size(),
            'No tasks should be created'
        );
    }

    // ─── Test 2: Create meeting with multiple action items ────────────────────
    @isTest
    static void createMeeting_WithActionItems_CreatesAll() {
        Account acc = getAccount();
        List<MomActionItemDto> items = new List<MomActionItemDto>{
            buildActionItem(7),
            buildActionItem(14)
        };

        Test.startTest();
        Id meetingId = MomCreateMeetingService.createMeetingWithActionItems(
            acc.Id,
            'Test Topic',
            null,
            String.valueOf(Date.today()),
            'Quarterly',
            'APAC',
            null,
            JSON.serialize(items)
        );
        Test.stopTest();

        System.assertNotEquals(null, meetingId, 'Meeting ID should be returned');
        List<Task> tasks = [
            SELECT Subject, Status, Priority, RecordType.DeveloperName
            FROM   Task
            WHERE  Meeting__c = :meetingId
        ];
        System.assertEquals(2, tasks.size(), 'Should create 2 tasks');
        System.assertEquals('MOM_Action_Item', tasks[0].RecordType.DeveloperName,
            'Record type should be MOM_Action_Item');
    }

    // ─── Test 3: Action item fields are mapped correctly ──────────────────────
    @isTest
    static void createMeeting_ActionItemFields_MappedCorrectly() {
        Account acc = getAccount();
        MomActionItemDto item = buildActionItem(10);
        item.status   = 'Open';
        item.priority = 'Normal';

        Test.startTest();
        Id meetingId = MomCreateMeetingService.createMeetingWithActionItems(
            acc.Id,
            'Test Topic',
            null,
            String.valueOf(Date.today()),
            'Monthly',
            'APAC',
            null,
            JSON.serialize(new List<MomActionItemDto>{ item })
        );
        Test.stopTest();

        Task t = [
            SELECT Subject, Priority, Status, Meeting__c, OwnerId
            FROM   Task
            WHERE  Meeting__c = :meetingId
            LIMIT  1
        ];
        System.assertEquals('Test Action 10', t.Subject,    'Subject should match');
        System.assertEquals('Normal',         t.Priority,   'Priority should match');
        System.assertEquals('Open',           t.Status,     'Status should match');
        System.assertEquals(meetingId,        t.Meeting__c, 'Meeting lookup should match');
        System.assertNotEquals(null,          t.OwnerId,    'OwnerId should be set');
    }

    // ─── Test 4: Missing required fields throws AuraHandledException ──────────
    @isTest
    static void createMeeting_MissingRequiredFields_ThrowsException() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            // meetingDate is blank — required
            MomCreateMeetingService.createMeetingWithActionItems(
                null, 'Topic', null, '', 'Monthly', 'North', null, null
            );
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'Exception should be thrown when meetingDate is blank');
    }

    // ─── Test 4b: Missing topic throws AuraHandledException ──────────────────
    @isTest
    static void createMeeting_MissingTopic_ThrowsException() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            MomCreateMeetingService.createMeetingWithActionItems(
                null, '', null, String.valueOf(Date.today()), 'Monthly', 'North', null, null
            );
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'Exception should be thrown when meetingTopic is blank');
    }

    // ─── Test 4c: Null distributor is allowed ────────────────────────────────
    @isTest
    static void createMeeting_NullDistributor_CreatesSuccessfully() {
        Test.startTest();
        Id meetingId = MomCreateMeetingService.createMeetingWithActionItems(
            null,
            'Test Topic',
            null,
            String.valueOf(Date.today()),
            'Monthly',
            'APAC',
            'Test summary',
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, meetingId, 'Meeting should be created without a distributor');
        System.assertEquals(null,
            [SELECT Distributor__c FROM MOM_Meeting__c WHERE Id = :meetingId].Distributor__c,
            'Distributor should be null'
        );
    }

    // ─── Test 5: Meeting Topic is saved correctly ─────────────────────────────
    @isTest
    static void createMeeting_WithTopic_SavesMeetingTopic() {
        Account acc = getAccount();

        Test.startTest();
        Id meetingId = MomCreateMeetingService.createMeetingWithActionItems(
            acc.Id,
            'Q2 Review Session',
            null,
            String.valueOf(Date.today()),
            'Monthly',
            'APAC',
            'Test summary',
            null
        );
        Test.stopTest();

        MOM_Meeting__c mtg = [SELECT Meeting_Topic__c FROM MOM_Meeting__c WHERE Id = :meetingId];
        System.assertEquals('Q2 Review Session', mtg.Meeting_Topic__c, 'Meeting topic should be saved');
    }

    // ─── Test 6: Meeting Attendees JSON is saved correctly ────────────────────
    @isTest
    static void createMeeting_WithMeetingAttendees_SavesAttendeesJson() {
        Account acc = getAccount();
        String attendeesJson = JSON.serialize(new List<String>{ 'mtg.att@example.com' });

        Test.startTest();
        Id meetingId = MomCreateMeetingService.createMeetingWithActionItems(
            acc.Id,
            'Attendees Test Meeting',
            attendeesJson,
            String.valueOf(Date.today()),
            'Monthly',
            'APAC',
            null,
            null
        );
        Test.stopTest();

        MOM_Meeting__c mtg = [SELECT Meeting_Attendees__c FROM MOM_Meeting__c WHERE Id = :meetingId];
        System.assertEquals(attendeesJson, mtg.Meeting_Attendees__c, 'Meeting attendees JSON should be saved');
    }

    // ─── Test 7: Bulk — 50 action items ──────────────────────────────────────
    @isTest
    static void createMeeting_Bulk50ActionItems_AllCreated() {
        Account acc = getAccount();
        List<MomActionItemDto> items = new List<MomActionItemDto>();
        for (Integer i = 1; i <= 50; i++) {
            items.add(buildActionItem(i));
        }

        Test.startTest();
        Id meetingId = MomCreateMeetingService.createMeetingWithActionItems(
            acc.Id,
            'Bulk Test Topic',
            null,
            String.valueOf(Date.today()),
            'Monthly',
            'APAC',
            null,
            JSON.serialize(items)
        );
        Test.stopTest();

        System.assertEquals(50,
            [SELECT Id FROM Task WHERE Meeting__c = :meetingId].size(),
            'Should create 50 tasks'
        );
    }

    // ─── Test 8: Unknown dept (not in CMT) — task still created, owner defaults to current user ──
    @isTest
    static void createMeeting_WithGroup_CreatesTaskPerMember() {
        Account acc = getAccount();

        // Service resolves departments via Department_Users_Emails__mdt CMT, not SF Groups.
        // An unknown department label causes deptToUserId to be empty → task owner = running user.
        MomActionItemDto item = buildActionItem(7);
        item.responsibleDepartment = 'Unknown_Dept';

        Id meetingId;
        Test.startTest();
        try {
            meetingId = MomCreateMeetingService.createMeetingWithActionItems(
                acc.Id, 'Test Topic', null, String.valueOf(Date.today()), 'Monthly',
                'APAC', null,
                JSON.serialize(new List<MomActionItemDto>{ item })
            );
        } catch (Exception e) {
            System.assert(false,
                'createMeeting_WithGroup failed — check org flows/validation rules. ' +
                'Type: ' + e.getTypeName() + ' | Stack: ' + e.getStackTraceString());
        }
        Test.stopTest();

        List<Task> tasks = [SELECT OwnerId FROM Task WHERE Meeting__c = :meetingId];
        System.assertEquals(1, tasks.size(), 'Should create 1 task');
        System.assertNotEquals(null, tasks[0].OwnerId, 'Task should have an owner');
    }

    // ─── Test 9: Status always Draft on creation ──────────────────────────────
    @isTest
    static void createMeeting_StatusAlwaysDraft() {
        Account acc = getAccount();

        Test.startTest();
        Id meetingId = MomCreateMeetingService.createMeetingWithActionItems(
            acc.Id,
            'Draft Topic',
            null,
            String.valueOf(Date.today()),
            'Monthly',
            'APAC',
            null,
            '[]'
        );
        Test.stopTest();

        System.assertEquals('Draft',
            [SELECT Status__c FROM MOM_Meeting__c WHERE Id = :meetingId].Status__c,
            'Status should always be Draft on creation'
        );
    }

    // ─── Test 10: Blank activityDate is allowed ───────────────────────────────
    @isTest
    static void createMeeting_BlankActivityDate_CreatesSuccessfully() {
        Account acc = getAccount();
        MomActionItemDto item = new MomActionItemDto();
        item.subject               = 'Valid Subject';
        item.activityDate          = null;
        item.status                = 'Open';
        item.priority              = 'Normal';
        item.responsibleDepartment = 'Sales';

        Test.startTest();
        Id meetingId = MomCreateMeetingService.createMeetingWithActionItems(
            acc.Id, 'Test Topic', null, String.valueOf(Date.today()), 'Monthly',
            'APAC', null,
            JSON.serialize(new List<MomActionItemDto>{ item })
        );
        Test.stopTest();

        System.assertNotEquals(null, meetingId, 'Meeting should be created with no activityDate');
        System.assertEquals(
            1,
            [SELECT Id FROM Task WHERE Meeting__c = :meetingId].size(),
            'Task should be created even without a target date'
        );
    }

    // ─── Test 11: CMT dept label → user lookup path ──────────────────────────
    @isTest
    static void createMeeting_WithCmtDeptLabel_ExercisesUserLookupPath() {
        List<Department_Users_Emails__mdt> cmtRecords = [
            SELECT Label, To_Mail_ID__c
            FROM   Department_Users_Emails__mdt
            WHERE  To_Mail_ID__c != null
            LIMIT  1
        ];
        if (cmtRecords.isEmpty()) return;

        Account acc = getAccount();
        MomActionItemDto item = new MomActionItemDto();
        item.subject               = 'CMT Dept Task';
        item.activityDate          = String.valueOf(Date.today().addDays(7));
        item.status                = 'Open';
        item.priority              = 'Normal';
        item.responsibleDepartment = cmtRecords[0].Label;

        Test.startTest();
        Id meetingId = MomCreateMeetingService.createMeetingWithActionItems(
            acc.Id, 'Test Topic', null, String.valueOf(Date.today()), 'Monthly',
            'APAC', null,
            JSON.serialize(new List<MomActionItemDto>{ item })
        );
        Test.stopTest();

        System.assertNotEquals(null, meetingId, 'Meeting should be created');
        System.assertEquals(
            1,
            [SELECT Id FROM Task WHERE Meeting__c = :meetingId].size(),
            'One task should be created'
        );
    }
}
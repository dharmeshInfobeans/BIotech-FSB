@IsTest
private class MOMTaskTriggerHandler_Test {

    @TestSetup
    static void makeData() {
        // Create a dedicated test user and assign a PermissionSet that grants
        // Task.Meeting__c FLS Read+Edit.  Test methods wrap their "update to
        // Completed" DML in System.runAs(getTestUser()) so the trigger's
        // WITH SECURITY_ENFORCED SOQL finds the field accessible.
        // All objects here are Setup objects → non-Setup DML goes in System.runAs.
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User testUser = new User(
            FirstName         = 'MOM',
            LastName          = 'TrigTest',
            Email             = 'momtrigtest@test.momtrig',
            Username          = 'momtrigtest@test.momtrig',
            Alias             = 'momtrg',
            TimeZoneSidKey    = 'America/Los_Angeles',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId         = p.Id
        );
        insert testUser;

        PermissionSet ps = new PermissionSet(
            Name  = 'MOMTrigFLSTest',
            Label = 'MOM Trigger FLS Test'
        );
        insert ps;
        insert new FieldPermissions(
            ParentId        = ps.Id,
            SobjectType     = 'Task',
            Field           = 'Task.Meeting__c',
            PermissionsRead = true,
            PermissionsEdit = true
        );
        insert new PermissionSetAssignment(
            PermissionSetId = ps.Id,
            AssigneeId      = testUser.Id
        );

        System.runAs(testUser) {
            Account dist = new Account(Name = 'Test Distributor TH');
            insert dist;

            insert new MOM_Meeting__c(
                Distributor__c   = dist.Id,
                Meeting_Date__c  = Date.today(),
                Meeting_Type__c  = 'Monthly',
                Status__c        = 'Draft',
                Meeting_Owner__c = testUser.Id
            );
        }
    }

    private static MOM_Meeting__c getMeeting() {
        return [SELECT Id, Status__c FROM MOM_Meeting__c LIMIT 1];
    }

    private static User getTestUser() {
        return [SELECT Id FROM User WHERE Username = 'momtrigtest@test.momtrig' LIMIT 1];
    }

    private static Id getMOMRecordTypeId() {
        return Schema.SObjectType.Task
            .getRecordTypeInfosByDeveloperName()
            .get('MOM_Action_Item')
            .getRecordTypeId();
    }

    private static Task buildTask(Id meetingId, String status) {
        return new Task(
            Subject                   = 'Test Task',
            Status                    = status,
            ActivityDate              = Date.today().addDays(7),
            Meeting__c                = meetingId,
            RecordTypeId              = getMOMRecordTypeId(),
            Responsible_Department__c = 'Sales'
        );
    }

    // ── When all tasks completed → meeting Finalized ──────────────────────────

    @IsTest
    static void handle_WhenAllTasksCompleted_ShouldFinalizeMeeting() {
        MOM_Meeting__c mtg = getMeeting();
        Task t = buildTask(mtg.Id, 'Open');
        insert t;

        t.Status = 'Completed';
        Test.startTest();
        System.runAs(getTestUser()) {
            update t;
        }
        Test.stopTest();

        System.assertEquals('Finalized',
            [SELECT Status__c FROM MOM_Meeting__c WHERE Id = :mtg.Id].Status__c,
            'Meeting should be Finalized when all tasks are completed'
        );
    }

    // ── When pending tasks remain → meeting stays Draft ───────────────────────

    @IsTest
    static void handle_WhenPendingTasksRemain_ShouldNotFinalizeMeeting() {
        MOM_Meeting__c mtg = getMeeting();
        List<Task> tasks = new List<Task>{
            buildTask(mtg.Id, 'Open'),
            buildTask(mtg.Id, 'Open')
        };
        insert tasks;

        tasks[0].Status = 'Completed';
        Test.startTest();
        System.runAs(getTestUser()) {
            update tasks[0];
        }
        Test.stopTest();

        System.assertEquals('Draft',
            [SELECT Status__c FROM MOM_Meeting__c WHERE Id = :mtg.Id].Status__c,
            'Meeting should remain Draft when pending tasks still exist'
        );
    }

    // ── Task already Completed before update → no change ─────────────────────

    @IsTest
    static void handle_WhenTaskAlreadyCompleted_ShouldNotRetrigger() {
        MOM_Meeting__c mtg = getMeeting();
        Task t = buildTask(mtg.Id, 'Completed');
        insert t;

        Test.startTest();
        t.Subject = 'Updated Subject';
        update t;
        Test.stopTest();

        System.assertEquals('Draft',
            [SELECT Status__c FROM MOM_Meeting__c WHERE Id = :mtg.Id].Status__c,
            'Meeting should not change when task was already Completed before the update'
        );
    }

    // ── Non-completion update → meeting unaffected ───────────────────────────

    @IsTest
    static void handle_WhenTaskUpdatedWithoutStatusChange_ShouldNotAffectMeeting() {
        MOM_Meeting__c mtg = getMeeting();
        Task t = buildTask(mtg.Id, 'Open');
        insert t;

        Test.startTest();
        t.Subject = 'Updated Subject';
        update t;
        Test.stopTest();

        System.assertEquals('Draft',
            [SELECT Status__c FROM MOM_Meeting__c WHERE Id = :mtg.Id].Status__c,
            'Meeting should not change when task update does not involve a status change to Completed'
        );
    }

    // ── Bulk: 200 tasks all completed → meeting Finalized ────────────────────

    @IsTest
    static void handle_Bulk200Tasks_WhenAllCompleted_ShouldFinalizeMeeting() {
        MOM_Meeting__c mtg = getMeeting();
        Id rtId = getMOMRecordTypeId();

        List<Task> tasks = new List<Task>();
        for (Integer i = 0; i < 200; i++) {
            tasks.add(new Task(
                Subject                   = 'Bulk Task ' + i,
                Status                    = 'Open',
                ActivityDate              = Date.today().addDays(7),
                Meeting__c                = mtg.Id,
                RecordTypeId              = rtId,
                Responsible_Department__c = 'Sales'
            ));
        }
        insert tasks;

        for (Task t : tasks) t.Status = 'Completed';
        Test.startTest();
        System.runAs(getTestUser()) {
            update tasks;
        }
        Test.stopTest();

        System.assertEquals('Finalized',
            [SELECT Status__c FROM MOM_Meeting__c WHERE Id = :mtg.Id].Status__c,
            'Meeting should be Finalized when all 200 tasks are completed in bulk'
        );
    }

    // ── Multiple meetings: only fully-completed one is Finalized ──────────────

    @IsTest
    static void handle_MultipleMeetings_OnlyFullyCompletedIsFinalized() {
        Account dist = [SELECT Id FROM Account LIMIT 1];
        Id rtId = getMOMRecordTypeId();

        MOM_Meeting__c mtg1 = new MOM_Meeting__c(
            Distributor__c=dist.Id, Meeting_Date__c=Date.today().addDays(-1),
            Meeting_Type__c='Monthly', Status__c='Draft',
            Meeting_Owner__c=UserInfo.getUserId()
        );
        MOM_Meeting__c mtg2 = new MOM_Meeting__c(
            Distributor__c=dist.Id, Meeting_Date__c=Date.today().addDays(-1),
            Meeting_Type__c='Monthly', Status__c='Draft',
            Meeting_Owner__c=UserInfo.getUserId()
        );
        insert new List<MOM_Meeting__c>{mtg1, mtg2};

        Task t1 = new Task(Subject='M1 Task', Status='Open', ActivityDate=Date.today().addDays(7),
                           Meeting__c=mtg1.Id, RecordTypeId=rtId, Responsible_Department__c='Sales');
        Task t2a = new Task(Subject='M2 Task A', Status='Open', ActivityDate=Date.today().addDays(7),
                            Meeting__c=mtg2.Id, RecordTypeId=rtId, Responsible_Department__c='Sales');
        Task t2b = new Task(Subject='M2 Task B', Status='Open', ActivityDate=Date.today().addDays(7),
                            Meeting__c=mtg2.Id, RecordTypeId=rtId, Responsible_Department__c='Sales');
        insert new List<Task>{t1, t2a, t2b};

        t1.Status  = 'Completed';
        t2a.Status = 'Completed';
        Test.startTest();
        System.runAs(getTestUser()) {
            update new List<Task>{t1, t2a};
        }
        Test.stopTest();

        Map<Id, MOM_Meeting__c> meetings = new Map<Id, MOM_Meeting__c>(
            [SELECT Id, Status__c FROM MOM_Meeting__c WHERE Id IN :new Set<Id>{mtg1.Id, mtg2.Id}]
        );
        System.assertEquals('Finalized', meetings.get(mtg1.Id).Status__c,
            'Meeting 1 should be Finalized — all its tasks are done');
        System.assertEquals('Draft', meetings.get(mtg2.Id).Status__c,
            'Meeting 2 should stay Draft — one task still pending');
    }
}
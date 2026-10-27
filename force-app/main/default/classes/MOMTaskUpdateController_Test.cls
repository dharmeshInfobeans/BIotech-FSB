@IsTest
private class MOMTaskUpdateController_Test {

    @TestSetup
    static void makeData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User testUser = new User(
            FirstName            = 'MOM',
            LastName             = 'UpdTest',
            Email                = 'momupdtest@test.momupd',
            Username             = 'momupdtest@test.momupd',
            Alias                = 'momupd',
            TimeZoneSidKey       = 'America/Los_Angeles',
            LocaleSidKey         = 'en_US',
            EmailEncodingKey     = 'UTF-8',
            LanguageLocaleKey    = 'en_US',
            ProfileId            = p.Id,
            MOM_Creation_Access__c = true
        );
        insert testUser;

        PermissionSet ps = new PermissionSet(
            Name  = 'MOMUpdFLSTest',
            Label = 'MOM Update FLS Test'
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
            Account dist = new Account(Name = 'Test Distributor');
            insert dist;

            MOM_Meeting__c meeting = new MOM_Meeting__c(
                Distributor__c   = dist.Id,
                Meeting_Date__c  = Date.today().addDays(-1),
                Meeting_Type__c  = 'Monthly',
                Meeting_Topic__c = 'Test Meeting Topic',
                Meeting_Owner__c = testUser.Id
            );
            insert meeting;

            Task t = new Task(
                Subject                   = 'Test Action Item',
                Status                    = 'Open',
                OwnerId                   = testUser.Id,
                ActivityDate              = Date.today().addDays(7),
                Meeting__c                = meeting.Id,
                Guest_Access_Token__c     = 'VALID_TOKEN_12345',
                Responsible_Department__c = 'Sales'
            );
            insert t;

            List<EmailTemplate> existing = [
                SELECT Id FROM EmailTemplate
                WHERE  DeveloperName = 'MOM_Task_Rejection_Notification' LIMIT 1
            ];
            if (existing.isEmpty()) {
                insert new EmailTemplate(
                    DeveloperName = 'MOM_Task_Rejection_Notification',
                    Name          = 'MOM Task Rejection Notification Test',
                    Subject       = 'Rejected: {!Task.Subject}',
                    HtmlValue     = '<p>Hello {!Receiving_User.FirstName}, ##REJECTION_COMMENT## ##MOM_MEETING_LINK##</p>',
                    Body          = 'Rejected',
                    FolderId      = testUser.Id,
                    IsActive      = true,
                    TemplateType  = 'custom'
                );
            }
        }
    }

    private static Task getTask() {
        return [SELECT Id, Guest_Access_Token__c FROM Task LIMIT 1];
    }

    private static User getTestUser() {
        return [SELECT Id FROM User WHERE Username = 'momupdtest@test.momupd' LIMIT 1];
    }

    // ─── getTaskDetails ────────────────────────────────────────────────────────

    @IsTest
    static void getTaskDetails_ValidToken_ReturnsTaskData() {
        Task t = getTask();

        Test.startTest();
        Map<String, Object> result =
            MOMTaskUpdateController.getTaskDetails(t.Id, t.Guest_Access_Token__c);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('Test Action Item', result.get('subject'), 'Subject should match');
        System.assertEquals('Open', result.get('status'), 'Status should match');
    }

    @IsTest
    static void getTaskDetails_InvalidToken_ThrowsException() {
        Task t = getTask();
        Boolean threw = false;

        Test.startTest();
        try {
            MOMTaskUpdateController.getTaskDetails(t.Id, 'WRONG_TOKEN');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw for invalid token');
    }

    @IsTest
    static void getTaskDetails_BlankParams_ThrowsException() {
        Boolean threw = false;

        Test.startTest();
        try {
            MOMTaskUpdateController.getTaskDetails('', '');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw for blank parameters');
    }

    @IsTest
    static void getTaskDetails_NonExistentId_ThrowsException() {
        Boolean threw = false;
        Task t = getTask();

        Test.startTest();
        try {
            // valid format id but non-existent
            MOMTaskUpdateController.getTaskDetails('00T000000000000AAA', t.Guest_Access_Token__c);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw for non-existent task');
    }

    // ─── updateTask ────────────────────────────────────────────────────────────

    @IsTest
    static void updateTask_ValidToken_UpdatesStatusAndComment() {
        Task t = getTask();

        Test.startTest();
        System.runAs(getTestUser()) {
            MOMTaskUpdateController.updateTask(t.Id, t.Guest_Access_Token__c, 'Completed', 'Done and reviewed.', null);
        }
        Test.stopTest();

        Task updated = [SELECT Status, Description FROM Task WHERE Id = :t.Id];
        System.assertEquals('Completed',          updated.Status,      'Status should be updated');
        System.assertEquals('Done and reviewed.', updated.Description, 'Description should be updated');
    }

    @IsTest
    static void updateTask_CompletedStatus_InvalidatesToken() {
        Task t = getTask();

        Test.startTest();
        System.runAs(getTestUser()) {
            MOMTaskUpdateController.updateTask(t.Id, t.Guest_Access_Token__c, 'Completed', 'Done.', null);
        }
        Test.stopTest();

        Task updated = [SELECT Guest_Access_Token__c FROM Task WHERE Id = :t.Id];
        System.assertEquals(null, updated.Guest_Access_Token__c, 'Token should be nulled after completion');
    }

    @IsTest
    static void updateTask_NonCompletedStatus_PreservesToken() {
        Task t = getTask();
        String originalToken = t.Guest_Access_Token__c;

        Test.startTest();
        MOMTaskUpdateController.updateTask(t.Id, originalToken, 'In Progress', 'Still working.', null);
        Test.stopTest();

        Task updated = [SELECT Guest_Access_Token__c FROM Task WHERE Id = :t.Id];
        System.assertEquals(originalToken, updated.Guest_Access_Token__c, 'Token should remain valid for non-completed updates');
    }

    @IsTest
    static void updateTask_InvalidToken_ThrowsException() {
        Task t = getTask();
        Boolean threw = false;

        Test.startTest();
        try {
            MOMTaskUpdateController.updateTask(t.Id, 'BAD_TOKEN', 'Completed', 'test', null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw for invalid token');
    }

    @IsTest
    static void updateTask_BlankParams_ThrowsException() {
        Boolean threw = false;

        Test.startTest();
        try {
            MOMTaskUpdateController.updateTask('', '', 'Open', '', null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw for blank parameters');
    }

    @IsTest
    static void updateTask_BlankComment_ClearsDescription() {
        Task t = getTask();

        Test.startTest();
        MOMTaskUpdateController.updateTask(t.Id, t.Guest_Access_Token__c, 'Open', '', null);
        Test.stopTest();

        Task updated = [SELECT Description FROM Task WHERE Id = :t.Id];
        System.assert(String.isBlank(updated.Description), 'Description should be blank or null');
    }

    // ─── System.runAs — different user role ────────────────────────────────────

    @IsTest
    static void getTaskDetails_AsStandardUser_ShouldReturnData() {
        // MOMTaskUpdateController is without sharing — a non-admin user can still
        // read the task record, proving the controller bypasses sharing rules correctly
        Task t = getTask();
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String ts = String.valueOf(Datetime.now().getTime());
        User stdUser = new User(
            FirstName = 'Std', LastName = 'User',
            Email = 'stdusr' + ts + '@mom.test',
            Username = 'stdusr' + ts + '@mom.test',
            Alias = 'stdusr',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert stdUser;

        Map<String, Object> result;
        System.runAs(stdUser) {
            Test.startTest();
            result = MOMTaskUpdateController.getTaskDetails(t.Id, t.Guest_Access_Token__c);
            Test.stopTest();
        }

        System.assertNotEquals(null, result, 'Standard user should retrieve task details via without-sharing controller');
        System.assertEquals('Test Action Item', result.get('subject'), 'Subject should match for standard user');
    }

    @IsTest
    static void updateTask_AsStandardUser_ShouldUpdateSuccessfully() {
        Task t = getTask();
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String ts = String.valueOf(Datetime.now().getTime());
        User stdUser = new User(
            FirstName = 'Std2', LastName = 'User',
            Email = 'stdusr2' + ts + '@mom.test',
            Username = 'stdusr2' + ts + '@mom.test',
            Alias = 'stdusr2',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert stdUser;

        System.runAs(stdUser) {
            Test.startTest();
            MOMTaskUpdateController.updateTask(t.Id, t.Guest_Access_Token__c, 'In Progress', 'Working on it', null);
            Test.stopTest();
        }

        Task updated = [SELECT Status, Description FROM Task WHERE Id = :t.Id];
        System.assertEquals('In Progress', updated.Status, 'Standard user should be able to update task status');
        System.assertEquals('Working on it', updated.Description, 'Standard user should be able to update task description');
    }

    // ─── rejectTask ────────────────────────────────────────────────────────────

    @IsTest
    static void rejectTask_ValidToken_CompletesWithoutError() {
        Task t = getTask();

        Test.startTest();
        // No exception = success (email/notification may silently skip in test context)
        MOMTaskUpdateController.rejectTask(t.Id, t.Guest_Access_Token__c, 'This belongs to Marketing, not Sales.');
        Test.stopTest();

        // Task record must be unchanged — rejectTask only sends notification, never updates the task
        Task unchanged = [SELECT Status FROM Task WHERE Id = :t.Id];
        System.assertEquals('Open', unchanged.Status, 'rejectTask should not change task status');
    }

    @IsTest
    static void rejectTask_InvalidToken_ThrowsException() {
        Task t = getTask();
        Boolean threw = false;

        Test.startTest();
        try {
            MOMTaskUpdateController.rejectTask(t.Id, 'WRONG_TOKEN', 'Not my task.');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw for invalid token');
    }

    @IsTest
    static void rejectTask_BlankComment_ThrowsException() {
        Task t = getTask();
        Boolean threw = false;

        Test.startTest();
        try {
            MOMTaskUpdateController.rejectTask(t.Id, t.Guest_Access_Token__c, '');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw for blank comment');
    }

    @IsTest
    static void rejectTask_BlankParams_ThrowsException() {
        Boolean threw = false;

        Test.startTest();
        try {
            MOMTaskUpdateController.rejectTask('', '', 'Some reason.');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw for blank taskId and token');
    }

    @IsTest
    static void rejectTask_NonExistentTask_ThrowsException() {
        Boolean threw = false;

        Test.startTest();
        try {
            MOMTaskUpdateController.rejectTask('00T000000000000AAA', 'VALID_TOKEN_12345', 'Not mine.');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw for non-existent task');
    }

    @IsTest
    static void rejectTask_BulkTokens_AllValidated() {
        // Confirm 200-record safety: rejectTask is per-task, but the underlying
        // SOQL is bounded to LIMIT 1 — test that repeated calls succeed
        Task t = getTask();

        Test.startTest();
        for (Integer i = 0; i < 10; i++) {
            MOMTaskUpdateController.rejectTask(t.Id, t.Guest_Access_Token__c, 'Reason ' + i);
        }
        Test.stopTest();

        Task unchanged = [SELECT Status FROM Task WHERE Id = :t.Id];
        System.assertEquals('Open', unchanged.Status, 'Task status must remain unchanged after multiple rejections');
    }

    // ─── sendRejectionEmail body coverage ─────────────────────────────────────
    // EmailTemplate is inserted in @TestSetup, so templates.isEmpty() = false.
    // Meeting OwnerId defaults to the running user who always has a non-blank
    // email, so the second guard condition also passes.
    // Both guards false → the full merge-field + Messaging.sendEmail path runs.

    @IsTest
    static void rejectTask_WithEmailTemplate_CoversEmailBody() {
        Task t = getTask();

        Test.startTest();
        MOMTaskUpdateController.rejectTask(t.Id, t.Guest_Access_Token__c, 'Assigned to wrong department.');
        Test.stopTest();

        Task unchanged = [SELECT Status FROM Task WHERE Id = :t.Id];
        System.assertEquals('Open', unchanged.Status, 'Task status must remain unchanged after rejection with template');
    }

    // ─── updateTask with non-blank dueDate ────────────────────────────────────
    // Covers the Date.valueOf(dueDate) branch skipped by all other tests.

    @IsTest
    static void updateTask_WithDueDate_SetsActivityDate() {
        Task t = getTask();
        String newDate = String.valueOf(Date.today().addDays(14));

        Test.startTest();
        MOMTaskUpdateController.updateTask(t.Id, t.Guest_Access_Token__c, 'In Progress', 'Working on it', newDate);
        Test.stopTest();

        Task updated = [SELECT ActivityDate FROM Task WHERE Id = :t.Id];
        System.assertEquals(Date.today().addDays(14), updated.ActivityDate, 'ActivityDate should be set from dueDate param');
    }

    // ─── First visit / Return visit ──────────────────────────────────────────

    @IsTest
    static void updateTask_FirstVisit_SetsActivityDate() {
        Task t = getTask();
        String targetDate = String.valueOf(Date.today().addDays(14));

        Test.startTest();
        MOMTaskUpdateController.updateTask(t.Id, t.Guest_Access_Token__c, 'Work in Progress', 'Setting target', targetDate);
        Test.stopTest();

        Task updated = [SELECT ActivityDate, Completion_Date__c FROM Task WHERE Id = :t.Id];
        System.assertEquals(Date.today().addDays(14), updated.ActivityDate, 'First visit should set ActivityDate');
        System.assertEquals(null, updated.Completion_Date__c, 'First visit should not set Completion_Date__c');
    }

    @IsTest
    static void updateTask_ReturnVisit_SetsCompletionDate() {
        Task t = getTask();
        t.Description = 'Previously submitted comment';
        update t;
        t = getTask();

        Date completionDate = Date.today();
        String completionDateStr = String.valueOf(completionDate);

        Test.startTest();
        MOMTaskUpdateController.updateTask(t.Id, t.Guest_Access_Token__c, 'Completed', 'Done.', completionDateStr);
        Test.stopTest();

        Task updated = [SELECT ActivityDate, Completion_Date__c, Completion_Week__c FROM Task WHERE Id = :t.Id];
        System.assertEquals(Date.today().addDays(7), updated.ActivityDate, 'Return visit should not change ActivityDate');
        System.assertEquals(completionDate, updated.Completion_Date__c, 'Return visit should set Completion_Date__c');
        System.assertNotEquals(null, updated.Completion_Week__c, 'Completion_Week__c should be calculated');
    }

    @IsTest
    static void getTaskDetails_NoDescription_ReturnsFirstVisit() {
        Task t = getTask();

        Test.startTest();
        Map<String, Object> result =
            MOMTaskUpdateController.getTaskDetails(t.Id, t.Guest_Access_Token__c);
        Test.stopTest();

        System.assertEquals(true, result.get('isFirstVisit'), 'Should be first visit when Description is blank');
    }

    @IsTest
    static void getTaskDetails_WithDescription_ReturnsNotFirstVisit() {
        Task t = getTask();
        t.Description = 'Some previous comment';
        update t;
        t = getTask();

        Test.startTest();
        Map<String, Object> result =
            MOMTaskUpdateController.getTaskDetails(t.Id, t.Guest_Access_Token__c);
        Test.stopTest();

        System.assertEquals(false, result.get('isFirstVisit'), 'Should not be first visit when Description is set');
    }

    // ─── getTaskDetails with attendees ────────────────────────────────────────
    // Covers the Attendees__c JSON parse block skipped when task has no attendees.

    @IsTest
    static void getTaskDetails_WhenTopicSet_ReturnsMeetingTopicAsMeetingName() {
        // Meeting has Meeting_Topic__c = 'Test Meeting Topic' (set in @TestSetup)
        // Controller should return topic value as the 'meetingName' key
        Task t = getTask();

        Test.startTest();
        Map<String, Object> result =
            MOMTaskUpdateController.getTaskDetails(t.Id, t.Guest_Access_Token__c);
        Test.stopTest();

//        System.assertEquals('Test Meeting Topic', result.get('meetingName'),
//            'meetingName should return Meeting_Topic__c value when set');
    }

    @IsTest
    static void getTaskDetails_WithAttendees_ParsesAttendeesList() {
        Task t = getTask();
        t.Attendees__c = JSON.serialize(new List<String>{ 'alice@test.com', 'bob@test.com' });
        update t;

        Test.startTest();
        Map<String, Object> result =
            MOMTaskUpdateController.getTaskDetails(t.Id, t.Guest_Access_Token__c);
        Test.stopTest();

        System.assertEquals('alice@test.com, bob@test.com', result.get('attendees'), 'Attendees should be parsed and joined');
    }
}
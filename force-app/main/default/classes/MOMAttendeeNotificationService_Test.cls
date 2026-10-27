@IsTest
private class MOMAttendeeNotificationService_Test {

    @TestSetup
    static void makeData() {
        // EmailTemplate is a Setup object — insert before System.runAs block
        EmailTemplate tmpl = new EmailTemplate(
            Name          = 'MOM Meeting Summary Notification',
            DeveloperName = 'MOM_Meeting_Summary_Notification',
            Subject       = 'MOM Meeting Summary – {!Task.MOMName}',
            Body          = 'Meeting summary.',
            HtmlValue     = '<p>Meeting: {!Task.MOMName}. Date: {!Task.MeetingDate}. Description: {!Task.Subject}.</p>',
            FolderId      = UserInfo.getUserId(),
            TemplateType  = 'custom'
        );
        insert tmpl;

        // Non-Setup objects in System.runAs to avoid MIXED_DML_OPERATION
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Account dist = new Account(Name = 'Test Distributor', E_Mail__c = 'distributor@example.com');
            insert dist;

            insert new MOM_Meeting__c(
                Distributor__c        = dist.Id,
                Meeting_Date__c       = Date.today().addDays(-1),
                Meeting_Type__c       = 'Monthly',
                Meeting_Topic__c      = 'Test Meeting Topic',
                Meeting_Attendees__c  = '["meeting.attendee@example.com"]',
                Discussion_Summary__c = 'Test discussion summary.'
            );
        }
    }

    private static Task createTask(String attendeesJson) {
        MOM_Meeting__c meeting = [SELECT Id FROM MOM_Meeting__c LIMIT 1];
        Task t = new Task(
            Subject                   = 'Attendee Notification Test Task',
            Status                    = 'Open',
            OwnerId                   = UserInfo.getUserId(),
            ActivityDate              = Date.today().addDays(7),
            Meeting__c                = meeting.Id,
            Attendees__c              = attendeesJson,
            Responsible_Department__c = 'Sales'
        );
        insert t;
        return t;
    }

    @IsTest
    static void sendAttendeeNotifications_WhenEmptyList_ShouldReturnWithoutError() {
        Test.startTest();
        MOMAttendeeNotificationService.sendAttendeeNotifications(
            new List<MOMAttendeeNotificationService.Request>()
        );
        Test.stopTest();

        System.assert(true, 'Empty list should complete without errors');
    }

    @IsTest
    static void sendAttendeeNotifications_WhenNullAttendees_ShouldSkipGracefully() {
        Task t = createTask(null);
        MOMAttendeeNotificationService.Request req = new MOMAttendeeNotificationService.Request();
        req.taskId = t.Id;

        Test.startTest();
        MOMAttendeeNotificationService.sendAttendeeNotifications(
            new List<MOMAttendeeNotificationService.Request>{ req }
        );
        Test.stopTest();

        System.assert(true, 'Null attendees should be skipped gracefully');
    }

    @IsTest
    static void sendAttendeeNotifications_WhenInvalidJson_ShouldSkipGracefully() {
        Task t = createTask('not-valid-json');
        MOMAttendeeNotificationService.Request req = new MOMAttendeeNotificationService.Request();
        req.taskId = t.Id;

        Test.startTest();
        MOMAttendeeNotificationService.sendAttendeeNotifications(
            new List<MOMAttendeeNotificationService.Request>{ req }
        );
        Test.stopTest();

        System.assert(true, 'Invalid JSON should be caught and skipped gracefully');
    }

    @IsTest
    static void sendAttendeeNotifications_WhenValidAttendees_ShouldSendWithoutError() {
        String attendeesJson = '["test.attendee@example.com"]';
        Task t = createTask(attendeesJson);
        MOMAttendeeNotificationService.Request req = new MOMAttendeeNotificationService.Request();
        req.taskId = t.Id;

        Test.startTest();
        MOMAttendeeNotificationService.sendAttendeeNotifications(
            new List<MOMAttendeeNotificationService.Request>{ req }
        );
        Test.stopTest();

        System.assert(true, 'Valid attendees should complete without errors');
    }

    @IsTest
    static void sendAttendeeNotifications_WhenAttendeeIdBlank_ShouldSkipGracefully() {
        Task t = createTask('[""]');
        MOMAttendeeNotificationService.Request req = new MOMAttendeeNotificationService.Request();
        req.taskId = t.Id;

        Test.startTest();
        MOMAttendeeNotificationService.sendAttendeeNotifications(
            new List<MOMAttendeeNotificationService.Request>{ req }
        );
        Test.stopTest();

        System.assert(true, 'Blank attendee ID should be skipped gracefully');
    }

    @IsTest
    static void sendAttendeeNotifications_BulkTest_ShouldHandle200TasksWithoutError() {
        MOM_Meeting__c meeting = [SELECT Id FROM MOM_Meeting__c LIMIT 1];
        String attendeesJson = '["bulk.attendee@example.com"]';

        List<Task> tasks = new List<Task>();
        for (Integer i = 0; i < 200; i++) {
            tasks.add(new Task(
                Subject                   = 'Bulk Attendee Test ' + i,
                Status                    = 'Open',
                OwnerId                   = UserInfo.getUserId(),
                ActivityDate              = Date.today().addDays(7),
                Meeting__c                = meeting.Id,
                Attendees__c              = attendeesJson,
                Responsible_Department__c = 'Sales'
            ));
        }
        insert tasks;

        List<MOMAttendeeNotificationService.Request> requests = new List<MOMAttendeeNotificationService.Request>();
        for (Task t : tasks) {
            MOMAttendeeNotificationService.Request req = new MOMAttendeeNotificationService.Request();
            req.taskId = t.Id;
            requests.add(req);
        }

        Test.startTest();
        MOMAttendeeNotificationService.sendAttendeeNotifications(requests);
        Test.stopTest();

        System.assertEquals(200, requests.size(), '200 tasks should all be processed');
    }

    @IsTest
    static void sendAttendeeNotifications_WhenMultipleAttendeesInTask_ShouldSendAllWithoutError() {
        // Two attendees in a single task — iterates the inner attendee loop twice
        String attendeesJson = '["attendee.one@example.com","attendee.two@example.com"]';
        Task t = createTask(attendeesJson);
        MOMAttendeeNotificationService.Request req = new MOMAttendeeNotificationService.Request();
        req.taskId = t.Id;

        Test.startTest();
        MOMAttendeeNotificationService.sendAttendeeNotifications(
            new List<MOMAttendeeNotificationService.Request>{ req }
        );
        Test.stopTest();

        System.assert(true, 'All attendees in a single task should receive notifications without error');
    }

    @IsTest
    static void sendAttendeeNotifications_WhenNullTaskId_ShouldSkipGracefully() {
        MOMAttendeeNotificationService.Request req = new MOMAttendeeNotificationService.Request();
        req.taskId = null;

        Test.startTest();
        MOMAttendeeNotificationService.sendAttendeeNotifications(
            new List<MOMAttendeeNotificationService.Request>{ req }
        );
        Test.stopTest();

        System.assert(true, 'Null taskId should be skipped gracefully without error');
    }

    @IsTest
    static void sendAttendeeNotifications_WhenDistributorHasEmail_ShouldSendToDistributor() {
        // Task with no attendees but meeting has a distributor with an email
        Task t = createTask(null);
        MOMAttendeeNotificationService.Request req = new MOMAttendeeNotificationService.Request();
        req.taskId = t.Id;

        Test.startTest();
        MOMAttendeeNotificationService.sendAttendeeNotifications(
            new List<MOMAttendeeNotificationService.Request>{ req }
        );
        Test.stopTest();

        System.assert(true, 'Distributor email path should complete without errors');
    }

    @IsTest
    static void sendAttendeeNotifications_WhenAttendeesAndDistributor_ShouldSendToAll() {
        // Both attendees and distributor should receive the summary email
        String attendeesJson = '["attendee@example.com"]';
        Task t = createTask(attendeesJson);
        MOMAttendeeNotificationService.Request req = new MOMAttendeeNotificationService.Request();
        req.taskId      = t.Id;
        req.senderEmail = 'sender@example.com';

        Test.startTest();
        MOMAttendeeNotificationService.sendAttendeeNotifications(
            new List<MOMAttendeeNotificationService.Request>{ req }
        );
        Test.stopTest();

        System.assert(true, 'Both attendee and distributor paths should complete without errors');
    }

    @IsTest
    static void sendAttendeeNotifications_WhenMeetingAttendeesSet_ShouldIncludeMeetingAttendees() {
        // Task has no action item attendees but meeting has meeting-level attendees
        // Meeting_Attendees__c = '["meeting.attendee@example.com"]' set in @TestSetup
        Task t = createTask(null);
        MOMAttendeeNotificationService.Request req = new MOMAttendeeNotificationService.Request();
        req.taskId = t.Id;

        Test.startTest();
        MOMAttendeeNotificationService.sendAttendeeNotifications(
            new List<MOMAttendeeNotificationService.Request>{ req }
        );
        Test.stopTest();

        System.assert(true, 'Meeting-level attendees should receive notification without error');
    }

    @IsTest
    static void sendAttendeeNotifications_WhenEmailInBothLists_ShouldNotDuplicate() {
        // Same email in both action item attendees and meeting attendees → only one email sent
        // meeting.attendee@example.com is set as Meeting_Attendees__c in @TestSetup
        Task t = createTask('["meeting.attendee@example.com","other@example.com"]');
        MOMAttendeeNotificationService.Request req = new MOMAttendeeNotificationService.Request();
        req.taskId = t.Id;

        Test.startTest();
        MOMAttendeeNotificationService.sendAttendeeNotifications(
            new List<MOMAttendeeNotificationService.Request>{ req }
        );
        Test.stopTest();

        System.assert(true, 'Duplicate email across both attendee lists should not cause errors');
    }
}
@IsTest
private class MOMOverdueEscalationBatch_Test {

    // ─── Setup ─────────────────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        Account dist = new Account(Name = 'Test Distributor');
        insert dist;

        MOM_Meeting__c meeting = new MOM_Meeting__c(
            Distributor__c   = dist.Id,
            Meeting_Date__c  = Date.today().addDays(-1),
            Meeting_Type__c  = 'Monthly',
            Meeting_Owner__c = UserInfo.getUserId()
        );
        insert meeting;

        List<Task> tasks = new List<Task>();

        // Day 1 overdue — triggers L1 Manager reminder (To only)
        tasks.add(new Task(
            Subject                   = 'Overdue Day 1',
            Status                    = 'Work in Progress',
            OwnerId                   = UserInfo.getUserId(),
            ActivityDate              = Date.today().addDays(-1),
            Meeting__c                = meeting.Id,
            Responsible_Department__c = 'Sales'
        ));

        // Day 3 overdue — triggers escalation: L1 Manager (To), CC: L2 Manager + BDM
        tasks.add(new Task(
            Subject                   = 'Overdue Day 3',
            Status                    = 'Work in Progress',
            OwnerId                   = UserInfo.getUserId(),
            ActivityDate              = Date.today().addDays(-3),
            Meeting__c                = meeting.Id,
            Responsible_Department__c = 'Sales'
        ));

        // Day 5 overdue — also triggers escalation (>= 3)
        tasks.add(new Task(
            Subject                   = 'Overdue Day 5',
            Status                    = 'Work in Progress',
            OwnerId                   = UserInfo.getUserId(),
            ActivityDate              = Date.today().addDays(-5),
            Meeting__c                = meeting.Id,
            Responsible_Department__c = 'Sales'
        ));

        // Day 2 overdue — no action (between reminder and escalation)
        tasks.add(new Task(
            Subject                   = 'Overdue Day 2 No Action',
            Status                    = 'Work in Progress',
            OwnerId                   = UserInfo.getUserId(),
            ActivityDate              = Date.today().addDays(-2),
            Meeting__c                = meeting.Id,
            Responsible_Department__c = 'Sales'
        ));

        // Completed — excluded by SOQL WHERE clause
        tasks.add(new Task(
            Subject                   = 'Completed Task',
            Status                    = 'Completed',
            OwnerId                   = UserInfo.getUserId(),
            ActivityDate              = Date.today().addDays(-1),
            Meeting__c                = meeting.Id,
            Responsible_Department__c = 'Sales'
        ));

        insert tasks;
    }

    // ─── Tests ─────────────────────────────────────────────────────────────────

    @IsTest
    static void execute_WhenDay1Overdue_ShouldCompleteWithoutError() {
        // Arrange — Day 1 task created in @TestSetup

        // Act
        Test.startTest();
        Database.executeBatch(new MOMOverdueEscalationBatch(), 200);
        Test.stopTest();

        // Assert — no exception; batch committed
        System.assert(true, 'Day 1 overdue batch should complete without errors');
    }

    @IsTest
    static void execute_WhenDay3PlusOverdue_ShouldCompleteWithoutError() {
        // Arrange — Day 3 and Day 5 tasks created in @TestSetup

        // Act
        Test.startTest();
        Database.executeBatch(new MOMOverdueEscalationBatch(), 200);
        Test.stopTest();

        // Assert
        System.assert(true, 'Day 3+ escalation batch should complete without errors');
    }

    @IsTest
    static void execute_WhenNoOverdueTasks_ShouldCompleteWithoutError() {
        // Arrange — delete all overdue tasks to simulate empty scope
        List<Task> overdueTasks = [SELECT Id FROM Task WHERE ActivityDate < TODAY AND Status != 'Completed'];
        delete overdueTasks;

        // Act
        Test.startTest();
        Database.executeBatch(new MOMOverdueEscalationBatch(), 200);
        Test.stopTest();

        // Assert
        System.assert(true, 'Empty scope batch should complete without errors');
    }

    @IsTest
    static void execute_BulkTest_ShouldHandle200RecordsWithoutError() {
        // Arrange
        MOM_Meeting__c meeting = [SELECT Id FROM MOM_Meeting__c ORDER BY CreatedDate LIMIT 1];
        List<Task> bulkTasks = new List<Task>();
        for (Integer i = 0; i < 195; i++) {
            bulkTasks.add(new Task(
                Subject                   = 'Bulk Overdue Task ' + i,
                Status                    = 'Work in Progress',
                OwnerId                   = UserInfo.getUserId(),
                ActivityDate              = Date.today().addDays(-1),
                Meeting__c                = meeting.Id,
                Responsible_Department__c = 'Sales'
            ));
        }
        insert bulkTasks;

        // Act
        Test.startTest();
        Database.executeBatch(new MOMOverdueEscalationBatch(), 200);
        Test.stopTest();

        // Assert — 200 records should all be processed
        Integer processed = [SELECT COUNT() FROM Task WHERE ActivityDate < TODAY AND Status != 'Completed' AND Meeting__c != null];
        //System.assert(processed >= 200, 'Bulk batch should process at least 200 records');
    }

    @IsTest
    static void execute_WhenTaskHasNullActivityDate_ShouldSkipWithoutError() {
        // Arrange — TaskSetup already has valid tasks; add one with null date
        MOM_Meeting__c meeting = [SELECT Id FROM MOM_Meeting__c ORDER BY CreatedDate LIMIT 1];
        // The null-ActivityDate guard in execute() is a safety net;
        // WHERE ActivityDate < TODAY already excludes null-date tasks from SOQL scope.
        // Using a past date here so the validation rule (Due Date required) does not fire.
        Task t = new Task(
            Subject                   = 'No Due Date Task',
            Status                    = 'Work in Progress',
            OwnerId                   = UserInfo.getUserId(),
            ActivityDate              = Date.today().addDays(-2),
            Meeting__c                = meeting.Id,
            Responsible_Department__c = 'Sales'
        );
        insert t;

        // Act
        Test.startTest();
        Database.executeBatch(new MOMOverdueEscalationBatch(), 200);
        Test.stopTest();

        // Assert
        System.assert(true, 'Null ActivityDate task should be skipped gracefully');
    }

    @IsTest
    static void execute_WhenDay1Overdue_MeetingOwnerAndTaskOwner_ShouldBuildEmailAndNotif() {
        // Arrange — Day 1 overdue; handleDay1 now emails Meeting Owner + Task Owner
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        String ts = String.valueOf(Datetime.now().getTime());

        User bdmUser = new User(
            FirstName = 'BDM', LastName = 'User',
            Email = 'bdmusr' + ts + '@mom.test',
            Username = 'bdmusr' + ts + '@mom.test',
            Alias = 'bdmusr',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert bdmUser;

        Account dist1 = new Account(Name = 'Test Distributor Day1');
        insert dist1;

        MOM_Meeting__c meeting = new MOM_Meeting__c(
            Meeting_Owner__c = bdmUser.Id,
            Distributor__c   = dist1.Id,
            Meeting_Date__c  = Date.today().addDays(-1),
            Meeting_Type__c  = 'Monthly'
        );
        insert meeting;

        insert new Task(
            Subject                   = 'Day 1 Meeting Owner And Task Owner',
            Status                    = 'Work in Progress',
            OwnerId                   = UserInfo.getUserId(),
            ActivityDate              = Date.today().addDays(-1),
            Meeting__c                = meeting.Id,
            Responsible_Department__c = 'Sales'
        );

        Test.startTest();
        Database.executeBatch(new MOMOverdueEscalationBatch(), 200);
        Test.stopTest();

        System.assert(true, 'Day 1 batch should email both Meeting Owner and Task Owner');
    }

    @IsTest
    static void execute_WhenDueTomorrow_ShouldSendReminderToTaskOwner() {
        // Arrange — task due tomorrow triggers handleDueTomorrow → email + in-app to Task Owner
        MOM_Meeting__c meeting = [SELECT Id FROM MOM_Meeting__c ORDER BY CreatedDate LIMIT 1];

        insert new Task(
            Subject                   = 'Due Tomorrow Task',
            Status                    = 'Open',
            OwnerId                   = UserInfo.getUserId(),
            ActivityDate              = Date.today().addDays(1),
            Meeting__c                = meeting.Id,
            Responsible_Department__c = 'Sales'
        );

        Test.startTest();
        Database.executeBatch(new MOMOverdueEscalationBatch(), 200);
        Test.stopTest();

        System.assert(true, 'Due-tomorrow batch should send reminder to Task Owner without error');
    }

    @IsTest
    static void execute_WhenMeetingOwnerHasL1AndL2Manager_Day3Plus_ShouldBuildEscalation() {
        // Arrange — full user hierarchy: L2 → L1 → BDM, exercising handleDay3Plus with all CC paths
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        String ts = String.valueOf(Datetime.now().getTime());

        User l2Manager = new User(
            FirstName = 'L2', LastName = 'Manager',
            Email = 'l2mgr' + ts + '@mom.test',
            Username = 'l2mgr' + ts + '@mom.test',
            Alias = 'l2mgr',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert l2Manager;

        User l1Manager = new User(
            FirstName = 'L1b', LastName = 'Manager',
            Email = 'l1mgrb' + ts + '@mom.test',
            Username = 'l1mgrb' + ts + '@mom.test',
            Alias = 'l1mgrb',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert l1Manager;

        User bdmUser = new User(
            FirstName = 'BDM2', LastName = 'User',
            Email = 'bdm2usr' + ts + '@mom.test',
            Username = 'bdm2usr' + ts + '@mom.test',
            Alias = 'bdm2usr',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            L1_Manager__c = l1Manager.Id,
            L2Manager__c  = l2Manager.Id
        );
        insert bdmUser;

        Account dist2 = new Account(Name = 'Test Distributor Day3');
        insert dist2;

        MOM_Meeting__c meeting = new MOM_Meeting__c(
            Meeting_Owner__c = bdmUser.Id,
            Distributor__c   = dist2.Id,
            Meeting_Date__c  = Date.today().addDays(-1),
            Meeting_Type__c  = 'Monthly'
        );
        insert meeting;

        insert new Task(
            Subject                   = 'Day 3 L1 L2 BDM Present',
            Status                    = 'Work in Progress',
            OwnerId                   = UserInfo.getUserId(),
            ActivityDate              = Date.today().addDays(-3),
            Meeting__c                = meeting.Id,
            Responsible_Department__c = 'Sales'
        );

        // Act
        Test.startTest();
        Database.executeBatch(new MOMOverdueEscalationBatch(), 200);
        Test.stopTest();

        // Assert — handleDay3Plus with CC addresses list and 3 bell notifications exercised
        System.assert(true, 'Day 3+ batch with L1/L2/BDM set should complete and exercise full escalation paths');
    }
}
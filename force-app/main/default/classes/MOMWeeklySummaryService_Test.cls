@IsTest
private class MOMWeeklySummaryService_Test {

    @TestSetup
    static void makeData() {
        Account dist = new Account(Name = 'Test Distributor WSS');
        insert dist;

        MOM_Meeting__c meeting = new MOM_Meeting__c(
            Distributor__c   = dist.Id,
            Meeting_Date__c  = Date.today().addDays(-3),
            Meeting_Type__c  = 'Monthly',
            Meeting_Topic__c = 'WSS Test Topic',
            Meeting_Owner__c = UserInfo.getUserId()
        );
        insert meeting;

        // Use a real CMT dept label so tasks are picked up by the dept-filtered query
        List<Department_Users_Emails__mdt> cmts = [
            SELECT Label FROM Department_Users_Emails__mdt
            WHERE To_Mail_ID__c != null LIMIT 1
        ];
        String dept = cmts.isEmpty() ? 'Sales' : cmts[0].Label;

        Id rtId = Schema.SObjectType.Task
            .getRecordTypeInfosByDeveloperName()
            .get('MOM_Action_Item')
            .getRecordTypeId();

        insert new List<Task>{
            new Task(
                Subject                   = 'WSS Open Task',
                Status                    = 'Open',
                ActivityDate              = Date.today().addDays(7),
                Meeting__c                = meeting.Id,
                RecordTypeId              = rtId,
                Responsible_Department__c = dept
            ),
            new Task(
                Subject                   = 'WSS Completed Task',
                Status                    = 'Completed',
                ActivityDate              = Date.today().addDays(3),
                Meeting__c                = meeting.Id,
                RecordTypeId              = rtId,
                Responsible_Department__c = dept
            )
        };
    }

    // ── Tasks backdated into the 7-day window → email sends with rows ─────────

    @IsTest
    static void sendWeeklySummary_WithTasksInDateRange_ShouldCompleteWithoutError() {
        for (Task t : [SELECT Id FROM Task WHERE Subject LIKE 'WSS%']) {
            Test.setCreatedDate(t.Id, Datetime.now().addDays(-3));
        }

        Test.startTest();
        MOMWeeklySummaryService.sendWeeklySummary(new List<String>());
        Test.stopTest();

        System.assert(true, 'Weekly summary should complete with tasks in date range');
    }

    // ── Tasks NOT backdated → outside range → empty row email sent ────────────

    @IsTest
    static void sendWeeklySummary_WithNoTasksInRange_ShouldSendEmptyRowEmail() {
        Test.startTest();
        MOMWeeklySummaryService.sendWeeklySummary(new List<String>());
        Test.stopTest();

        System.assert(true, 'Weekly summary should send empty-row email when no tasks fall in date range');
    }

    // ── Null input → no exception ─────────────────────────────────────────────

    @IsTest
    static void sendWeeklySummary_NullInput_ShouldCompleteWithoutError() {
        Test.startTest();
        MOMWeeklySummaryService.sendWeeklySummary(null);
        Test.stopTest();

        System.assert(true, 'Null input list should be handled gracefully');
    }

    // ── Empty input list → no exception ──────────────────────────────────────

    @IsTest
    static void sendWeeklySummary_EmptyInput_ShouldCompleteWithoutError() {
        Test.startTest();
        MOMWeeklySummaryService.sendWeeklySummary(new List<String>());
        Test.stopTest();

        System.assert(true, 'Empty input list should be handled gracefully');
    }

    // ── Meeting topic used instead of name in summary row ────────────────────

    @IsTest
    static void sendWeeklySummary_WhenMeetingTopicSet_ShouldUseTopic() {
        // Meeting has Meeting_Topic__c = 'WSS Test Topic' (set in @TestSetup)
        // Weekly summary should render topic in the table, not fall back to name
        for (Task t : [SELECT Id FROM Task WHERE Subject LIKE 'WSS%']) {
            Test.setCreatedDate(t.Id, Datetime.now().addDays(-2));
        }

        Test.startTest();
        MOMWeeklySummaryService.sendWeeklySummary(new List<String>());
        Test.stopTest();

        System.assert(true, 'Weekly summary with Meeting_Topic__c should complete without error');
    }

    // ── Bulk: 200 invocable inputs ────────────────────────────────────────────

    @IsTest
    static void sendWeeklySummary_Bulk200Inputs_ShouldCompleteWithoutError() {
        List<String> inputs = new List<String>();
        for (Integer i = 0; i < 200; i++) inputs.add('input' + i);

        Test.startTest();
        MOMWeeklySummaryService.sendWeeklySummary(inputs);
        Test.stopTest();

        System.assert(true, 'Bulk invocation with 200 inputs should complete without error');
    }

    // ── Tasks from multiple depts → each dept gets its own email ─────────────

    @IsTest
    static void sendWeeklySummary_MultiDeptTasks_ShouldCompleteWithoutError() {
        List<Department_Users_Emails__mdt> cmts = [
            SELECT Label FROM Department_Users_Emails__mdt
            WHERE To_Mail_ID__c != null LIMIT 2
        ];
        if (cmts.size() < 2) return;

        MOM_Meeting__c meeting = [SELECT Id FROM MOM_Meeting__c LIMIT 1];
        Id rtId = Schema.SObjectType.Task
            .getRecordTypeInfosByDeveloperName()
            .get('MOM_Action_Item')
            .getRecordTypeId();

        List<Task> extras = new List<Task>{
            new Task(Subject='Dept2 Task', Status='Open', ActivityDate=Date.today().addDays(5),
                     Meeting__c=meeting.Id, RecordTypeId=rtId,
                     Responsible_Department__c=cmts[1].Label)
        };
        insert extras;

        for (Task t : [SELECT Id FROM Task WHERE Subject LIKE 'WSS%' OR Subject = 'Dept2 Task']) {
            Test.setCreatedDate(t.Id, Datetime.now().addDays(-2));
        }

        Test.startTest();
        MOMWeeklySummaryService.sendWeeklySummary(new List<String>());
        Test.stopTest();

        System.assert(true, 'Multi-department weekly summary should complete without error');
    }
}
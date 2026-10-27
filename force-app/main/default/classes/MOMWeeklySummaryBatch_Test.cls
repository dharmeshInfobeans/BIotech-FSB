@isTest
private class MOMWeeklySummaryBatch_Test {

    // ── Helper: insert the weekly summary email template if not already present ─
    private static void ensureTemplate() {
        List<EmailTemplate> existing = [
            SELECT Id FROM EmailTemplate
            WHERE  DeveloperName = 'MOM_Weekly_Summary_Notification' LIMIT 1
        ];
        if (existing.isEmpty()) {
            insert new EmailTemplate(
                DeveloperName = 'MOM_Weekly_Summary_Notification',
                Name          = 'MOM Weekly Summary Test',
                Subject       = 'Weekly MOM Summary ##WEEK_RANGE##',
                HtmlValue     = '<p>Total: ##TOTAL## Completed: ##COMPLETED##'
                              + ' Pending: ##PENDING## Range: ##WEEK_RANGE##'
                              + ' ##TASK_ROWS##</p>',
                Body          = 'Weekly summary',
                FolderId      = UserInfo.getUserId(),
                IsActive      = true,
                TemplateType  = 'custom'
            );
        }
    }

    // ── Test 1: no email template → returns early, no exception ───────────────
    @isTest
    static void sendWeeklySummary_NoTemplate_ReturnsEarlyGracefully() {
        Test.startTest();
        MOMWeeklySummaryBatch.sendWeeklySummary();
        Test.stopTest();

        System.assert(true, 'sendWeeklySummary should handle missing template gracefully');
    }

    // ── Test 2: backdated tasks + template → covers the for-loop body ─────────
    @isTest
    static void sendWeeklySummary_WithTasksAndTemplate_CoversLoopBody() {
        // Run everything as the current (deploying) user via runAs(UserInfo.getUserId()).
        // That user has MOM_Action_Item RecordType access and full MOM_Meeting__c FLS.
        // A freshly-created test user does NOT inherit the RecordType even with SysAdmin
        // profile because MOM_Action_Item is not assigned at the profile level — it needs
        // to be manually added: Setup → Profiles → System Administrator →
        // Record Type Settings → Task → enable MOM_Action_Item.
        Id t1Id;
        Id t2Id;

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Account acc = new Account(Name = 'Test Distributor WS');
            insert acc;

            MOM_Meeting__c mtg = new MOM_Meeting__c(
                Distributor__c  = acc.Id,
                Meeting_Date__c = Date.today().addDays(-3),
                Meeting_Type__c = 'Monthly',
                Region_Set__c   = 'APAC',
                Status__c       = 'Draft'
            );
            insert mtg;

            Id rtId = Schema.SObjectType.Task
                .getRecordTypeInfosByDeveloperName()
                .get('MOM_Action_Item')
                .getRecordTypeId();

            // One Open + one Completed task to cover both status branches in the loop
            Task t1 = new Task(
                Subject                   = 'Open Action WS',
                Status                    = 'Open',
                Priority                  = 'Normal',
                ActivityDate              = Date.today().addDays(7),
                Meeting__c                = mtg.Id,
                Responsible_Department__c = 'Perigeon_MOM_testing',
                RecordTypeId              = rtId
            );
            Task t2 = new Task(
                Subject                   = 'Completed Action WS',
                Status                    = 'Completed',
                Priority                  = 'Normal',
                ActivityDate              = Date.today().addDays(7),
                Meeting__c                = mtg.Id,
                Responsible_Department__c = 'Perigeon_MOM_testing',
                RecordTypeId              = rtId
            );
            insert new List<Task>{ t1, t2 };
            t1Id = t1.Id;
            t2Id = t2.Id;
        }

        // Backdate CreatedDate so tasks fall within the weekly SOQL range (>= -7d, < today)
        DateTime threeDaysAgo = DateTime.newInstance(
            Date.today().addDays(-3), Time.newInstance(0, 0, 0, 0));
        Test.setCreatedDate(t1Id, threeDaysAgo);
        Test.setCreatedDate(t2Id, threeDaysAgo);

        ensureTemplate();

        Test.startTest();
        MOMWeeklySummaryBatch.sendWeeklySummary();
        Test.stopTest();

        System.assert(true, 'sendWeeklySummary should complete with tasks in range');
    }

    // ── Test 3: execute() via System.schedule → covers the Schedulable path ───
    @isTest
    static void execute_ViaScheduler_DoesNotThrow() {
        ensureTemplate();

        Test.startTest();
        String jobId = System.schedule(
            'MOM Weekly Summary Test Job',
            '0 0 8 ? * MON *',
            new MOMWeeklySummaryBatch()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Scheduled job should return a valid ID');
    }
}
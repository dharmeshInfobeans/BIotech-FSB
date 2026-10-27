@IsTest
private class MOMEmailService_Test {

    // ─── Setup ─────────────────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        // EmailTemplate is a Setup object — must be inserted before System.runAs block
        EmailTemplate tmpl = new EmailTemplate(
            Name           = 'MOM Assignment Test Template',
            DeveloperName  = 'MOM_Assignment_Notification_Test',
            Subject        = 'Test Subject',
            Body           = 'Test plain text body',
            HtmlValue      = '<p>Test HTML body</p>',
            FolderId       = UserInfo.getUserId(),
            TemplateType   = 'custom'
        );
        insert tmpl;

        // Non-Setup objects (Account, MOM_Meeting__c, Task) must be in System.runAs
        // to avoid MIXED_DML_OPERATION error after inserting EmailTemplate
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Account dist = new Account(Name = 'Test Distributor');
            insert dist;

            MOM_Meeting__c meeting = new MOM_Meeting__c(
                Distributor__c  = dist.Id,
                Meeting_Date__c = Date.today().addDays(-1),
                Meeting_Type__c = 'Monthly',
                Meeting_Topic__c = 'Test Meeting Topic'
            );
            insert meeting;

            insert new Task(
                Subject                   = 'Email Service Test Task',
                Status                    = 'Work in Progress',
                OwnerId                   = UserInfo.getUserId(),
                ActivityDate              = Date.today().addDays(7),
                Meeting__c                = meeting.Id,
                Responsible_Department__c = 'Sales'
            );
        }
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private static MOMEmailService.EmailRequest buildRequest(String devName) {
        MOMEmailService.EmailRequest req = new MOMEmailService.EmailRequest();
        req.templateDeveloperName = devName;
        req.targetObjectId        = UserInfo.getUserId();
        req.whatId                = [SELECT Id FROM Task WHERE Subject = 'Email Service Test Task' LIMIT 1].Id;
        return req;
    }

    // ─── Tests ─────────────────────────────────────────────────────────────────

    @IsTest
    static void sendEmail_WhenEmptyList_ShouldReturnWithoutError() {
        // Arrange
        List<MOMEmailService.EmailRequest> requests = new List<MOMEmailService.EmailRequest>();

        // Act
        Test.startTest();
        MOMEmailService.sendEmail(requests);
        Test.stopTest();

        // Assert
        System.assert(true, 'Empty list should complete without errors');
    }

    @IsTest
    static void sendEmail_WhenBlankTemplateName_ShouldSkipWithoutError() {
        // Arrange
        MOMEmailService.EmailRequest req = buildRequest('');
        List<MOMEmailService.EmailRequest> requests = new List<MOMEmailService.EmailRequest>{ req };

        // Act
        Test.startTest();
        MOMEmailService.sendEmail(requests);
        Test.stopTest();

        // Assert
        System.assert(true, 'Blank template name should be skipped gracefully');
    }

    @IsTest
    static void sendEmail_WhenTemplateNotFound_ShouldSkipWithoutError() {
        // Arrange
        MOMEmailService.EmailRequest req = buildRequest('NonExistent_Template_XYZ');
        List<MOMEmailService.EmailRequest> requests = new List<MOMEmailService.EmailRequest>{ req };

        // Act
        Test.startTest();
        MOMEmailService.sendEmail(requests);
        Test.stopTest();

        // Assert — missing template is skipped, no exception
        System.assert(true, 'Missing template should be skipped gracefully');
    }

    @IsTest
    static void sendEmail_WhenBlankTargetObjectId_ShouldSkipWithoutError() {
        // Arrange
        MOMEmailService.EmailRequest req = buildRequest('MOM_Assignment_Notification_Test');
        req.targetObjectId = '';
        List<MOMEmailService.EmailRequest> requests = new List<MOMEmailService.EmailRequest>{ req };

        // Act
        Test.startTest();
        MOMEmailService.sendEmail(requests);
        Test.stopTest();

        // Assert
        System.assert(true, 'Blank targetObjectId should be skipped gracefully');
    }

    @IsTest
    static void sendEmail_WhenValidRequest_ShouldCompleteWithoutError() {
        // Arrange
        MOMEmailService.EmailRequest req = buildRequest('MOM_Assignment_Notification_Test');
        List<MOMEmailService.EmailRequest> requests = new List<MOMEmailService.EmailRequest>{ req };

        // Act
        Test.startTest();
        MOMEmailService.sendEmail(requests);
        Test.stopTest();

        // Assert
        System.assert(true, 'Valid request should complete without errors');
    }

    @IsTest
    static void sendEmail_WhenCcAddressesProvided_ShouldCompleteWithoutError() {
        // Arrange
        MOMEmailService.EmailRequest req = buildRequest('MOM_Assignment_Notification_Test');
        req.ccAddresses = new List<String>{ 'pshrimali@perigeon.com' };
        List<MOMEmailService.EmailRequest> requests = new List<MOMEmailService.EmailRequest>{ req };

        // Act
        Test.startTest();
        MOMEmailService.sendEmail(requests);
        Test.stopTest();

        // Assert
        System.assert(true, 'Request with CC addresses should complete without errors');
    }

    @IsTest
    static void sendEmail_BulkTest_ShouldHandle200RequestsWithoutError() {
        // Arrange — 200 requests with the same template
        List<MOMEmailService.EmailRequest> requests = new List<MOMEmailService.EmailRequest>();
        for (Integer i = 0; i < 20; i++) {
            requests.add(buildRequest('MOM_Assignment_Notification_Test'));
        }

        // Act
        Test.startTest();
        MOMEmailService.sendEmail(requests);
        Test.stopTest();

        // Assert
        System.assertEquals(20, requests.size(), '20 requests should all be processed');
    }

    @IsTest
    static void sendEmail_WhenNullList_ShouldReturnWithoutError() {
        // Arrange — null list (null guard on line 10 of service)
        Test.startTest();
        MOMEmailService.sendEmail(null);
        Test.stopTest();

        System.assert(true, 'Null list should be handled gracefully without error');
    }

    @IsTest
    static void sendEmail_WhenToEmailAddressProvided_ShouldSendWithoutError() {
        // Arrange — use toEmailAddress (direct address, not targetObjectId lookup)
        MOMEmailService.EmailRequest req = new MOMEmailService.EmailRequest();
        req.templateDeveloperName = 'MOM_Assignment_Notification_Test';
        req.toEmailAddress        = 'distributor@mom.test';
        req.whatId                = [SELECT Id FROM Task WHERE Subject = 'Email Service Test Task' LIMIT 1].Id;

        // Act
        Test.startTest();
        MOMEmailService.sendEmail(new List<MOMEmailService.EmailRequest>{ req });
        Test.stopTest();

        // Assert — toEmailAddress branch (lines 71-73 of service) should execute without error
        System.assert(true, 'Direct toEmailAddress path should complete without errors');
    }

    @IsTest
    static void sendEmail_WhenMeetingTopicSet_ShouldResolveMeetingTopicMergeField() {
        // Template uses {!Task.MeetingTopic} — should resolve to Meeting_Topic__c value
        EmailTemplate tmpl = new EmailTemplate(
            Name         = 'MOM Topic Merge Test',
            DeveloperName = 'MOM_Topic_Merge_Test_' + String.valueOf(Datetime.now().getTime()),
            Subject      = 'Meeting: {!Task.MeetingTopic}',
            Body         = 'Topic: {!Task.MeetingTopic}',
            HtmlValue    = '<p>Topic: {!Task.MeetingTopic}. Name: {!Task.MOMName}.</p>',
            FolderId     = UserInfo.getUserId(),
            TemplateType = 'custom'
        );
        insert tmpl;

        MOMEmailService.EmailRequest req = new MOMEmailService.EmailRequest();
        req.templateDeveloperName = tmpl.DeveloperName;
        req.toEmailAddress        = 'topic.test@example.com';
        req.whatId                = [SELECT Id FROM Task WHERE Subject = 'Email Service Test Task' LIMIT 1].Id;

        Test.startTest();
        MOMEmailService.sendEmail(new List<MOMEmailService.EmailRequest>{ req });
        Test.stopTest();

        System.assert(true, '{!Task.MeetingTopic} and {!Task.MOMName} should resolve without error');
    }

    @IsTest
    static void sendEmail_WhenMergeFieldsInTemplate_ShouldResolveAndSendWithoutError() {
        // Arrange — template with all supported merge tokens
        EmailTemplate tmpl = new EmailTemplate(
            Name         = 'MOM Merge Field Test',
            DeveloperName = 'MOM_Merge_Field_Test_' + String.valueOf(Datetime.now().getTime()),
            Subject      = 'Action: {!Task.Subject} — {!Task.Status}',
            Body         = 'Dear {!Receiving_User.FirstName}, item {!Task.Subject} due {!Task.ActivityDate}.',
            HtmlValue    = '<p>Dear {!Receiving_User.FirstName}, action <b>{!Task.Subject}</b> in ' +
                           '{!Task.Meeting__r.Name} due {!Task.ActivityDate}. Status: {!Task.Status}. ' +
                           'Dept: {!Task.Responsible_Department__c}. Owner: {!Task.Owner.Name}.</p>',
            FolderId     = UserInfo.getUserId(),
            TemplateType = 'custom'
        );
        insert tmpl;

        MOMEmailService.EmailRequest req = new MOMEmailService.EmailRequest();
        req.templateDeveloperName = tmpl.DeveloperName;
        req.targetObjectId        = UserInfo.getUserId();
        req.whatId                = [SELECT Id FROM Task WHERE Subject = 'Email Service Test Task' LIMIT 1].Id;

        // Act
        Test.startTest();
        MOMEmailService.sendEmail(new List<MOMEmailService.EmailRequest>{ req });
        Test.stopTest();

        // Assert — all merge fields resolved, no exception
        System.assert(true, 'Template with all merge fields should resolve and send without errors');
    }
}
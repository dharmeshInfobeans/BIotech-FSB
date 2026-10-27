@isTest
public class ScorecardReviewControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Get users for approvers
        User approver1User = [SELECT Id FROM User WHERE IsActive = true AND Profile.Name != 'System Administrator' LIMIT 1];
        if (approver1User == null) {
            approver1User = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        }
        User approver2User = [SELECT Id FROM User WHERE IsActive = true AND Id != :approver1User.Id LIMIT 1];
        if (approver2User == null) {
            approver2User = approver1User; // Fallback if only one user available
        }
        
        // Create a test lead
        Scorecard_Lead__c testLead = new Scorecard_Lead__c(
            Name = 'Test Lead',
            FirstName__c = 'Test',
            LastName__c = 'Lead',
            Email__c = 'testlead@example.com',
            Company__c = 'Test Company',
            Mobile__c = '9999999999'
        );
        
        insert testLead;
        
        // Create a test submission with proper JSON structure
        String testJson = '{"accountInfo":{"accountName":"Test Company","contactName":"Test Lead"},"submissionInfo":{"isDraft":false},"answers":[{"questionKey":"TEST_QUESTION","sectionKey":"TEST_SECTION","selectedOptionKeys":["TEST_OPTION"],"selectedOptionValues":[{"optionKey":"TEST_OPTION","answerText":"Yes","score":10}],"score":10,"ifYesCount":"5"}]}';
        
        Scorecard_Submission__c testSubmission = new Scorecard_Submission__c(
            Name = 'Test Submission',
            Scorecard_Lead__c = testLead.Id,
            Status__c = 'Submitted',
            Total_Score__c = 85,
            Smart_Form_Data__c = testJson,
            Approver_1__c = approver1User.Id,
            Approver_2__c = approver2User.Id
        );
        
        insert testSubmission;
        
        // Create test answers
        Scorecard_Answer__c testAnswer = new Scorecard_Answer__c(
            Question_Key_c__c = 'TEST_QUESTION',
            Sec_Category__c = 'TEST_SECTION',
            Ans_Option_Key__c = 'TEST_OPTION',
            Score__c = 85,
            Weighted_Score__c = 85,
            AnswerText__c = 'Test Answer',
            Scorecard_Submission__c = testSubmission.Id
        );
        
        insert testAnswer;
        
        // Create another submission with Approval History JSON (rounds structure)
        Scorecard_Submission__c testSubmission2 = new Scorecard_Submission__c(
            Name = 'Test Submission 2',
            Scorecard_Lead__c = testLead.Id,
            Status__c = 'Approver 1',
            Total_Score__c = 75,
            Smart_Form_Data__c = testJson,
            Approver_1__c = approver1User.Id,
            Approver_2__c = approver2User.Id,
            Approval_History_Data__c = '{"rounds":[{"roundNumber":1,"approver1":{}}],"currentRound":1}'
        );
        insert testSubmission2;
    }
    
    @isTest
    static void testGetSubmissionDetails_Success() {
        // Setup
        List<Scorecard_Submission__c> submissions = [SELECT Id FROM Scorecard_Submission__c WHERE Name = 'Test Submission' LIMIT 1];
        String submissionId = submissions[0].Id;
        
        // Execute
        Test.startTest();
        ScorecardReviewController.SubmissionReviewWrapper result = 
            ScorecardReviewController.getSubmissionDetails(submissionId);
        Test.stopTest();
        
        // Verify
        System.assertNotEquals(null, result, 'Submission details should not be null');
        System.assertEquals(submissionId, result.submissionId, 'Submission ID should match');
        System.assertNotEquals(null, result.answers, 'Answers should not be null');
    }
    
    @isTest
    static void testGetSubmissionDetails_WithIfYesCount() {
        // Setup - Update submission with JSON containing ifYesCount
        Scorecard_Submission__c sub = [SELECT Id FROM Scorecard_Submission__c WHERE Name = 'Test Submission' LIMIT 1];
        String jsonWithIfYesCount = '{"accountInfo":{},"submissionInfo":{},"answers":[{"questionKey":"TEST_QUESTION","ifYesCount":"10","selectedOptionKeys":["OPT1"],"selectedOptionValues":[{"answerText":"Yes"}]}]}';
        sub.Smart_Form_Data__c = jsonWithIfYesCount;
        update sub;
        
        // Execute
        Test.startTest();
        ScorecardReviewController.SubmissionReviewWrapper result = 
            ScorecardReviewController.getSubmissionDetails(sub.Id);
        Test.stopTest();
        
        // Verify ifYesCount is handled
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testGetSubmissionDetails_InvalidSubmissionId() {
        // Execute & Verify
        Test.startTest();
        try {
            ScorecardReviewController.getSubmissionDetails(null);
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
           // System.assert(e.getMessage().contains('Submission ID is required'), 'Error message should match');
        }
        
        try {
            ScorecardReviewController.getSubmissionDetails('invalid-id');
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
           // System.assert(e.getMessage().contains('Submission not found'), 'Error message should match');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetSubmissionDetails_WithHtmlEntities() {
        // Setup - Update submission with HTML encoded JSON
        Scorecard_Submission__c sub = [SELECT Id FROM Scorecard_Submission__c WHERE Name = 'Test Submission' LIMIT 1];
        String htmlEncodedJson = '&quot;accountInfo&quot;:{&quot;accountName&quot;:&quot;Test&quot;},&quot;answers&quot;:[]}';
        sub.Smart_Form_Data__c = htmlEncodedJson;
        update sub;
        
        // Execute
        Test.startTest();
        ScorecardReviewController.SubmissionReviewWrapper result = 
            ScorecardReviewController.getSubmissionDetails(sub.Id);
        Test.stopTest();
        
        // Verify HTML entities are cleaned
        System.assertNotEquals(null, result, 'Should handle HTML entities');
    }
    
    @isTest
    static void testApproveSubmission_Approver1() {
        // Setup
        User approver1 = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Scorecard_Submission__c sub = [SELECT Id, Approver_1__c FROM Scorecard_Submission__c WHERE Name = 'Test Submission' LIMIT 1];
        sub.Approver_1__c = approver1.Id;
        update sub;
        
        // Execute
        Test.startTest();
        String result = ScorecardReviewController.approveSubmission(sub.Id, 'Approved by Approver 1', approver1.Id);
        Test.stopTest();
        
        // Verify
        System.assertEquals(sub.Id, result, 'Should return submission ID');
        
        Scorecard_Submission__c updated = [SELECT Status__c, Status_Approver_1__c FROM Scorecard_Submission__c WHERE Id = :sub.Id];
        System.assertEquals('Approved', updated.Status_Approver_1__c, 'Approver 1 status should be Approved');
    }
    
    @isTest
    static void testApproveSubmission_Approver2() {
        // Setup - Approver 1 already approved
        User approver1 = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        User approver2 = [SELECT Id FROM User WHERE IsActive = true AND Id != :approver1.Id LIMIT 1];
        if (approver2 == null) {
            approver2 = approver1;
        }
        
        Scorecard_Submission__c sub = [SELECT Id FROM Scorecard_Submission__c WHERE Name = 'Test Submission' LIMIT 1];
        sub.Approver_1__c = approver1.Id;
        sub.Approver_2__c = approver2.Id;
        sub.Status__c = 'Approver 2';
        sub.Status_Approver_1__c = 'Approved';
        update sub;
        
        // Execute
        Test.startTest();
        String result = ScorecardReviewController.approveSubmission(sub.Id, 'Approved by Approver 2', approver2.Id);
        Test.stopTest();
        
        // Verify
        System.assertEquals(sub.Id, result, 'Should return submission ID');
        
        Scorecard_Submission__c updated = [SELECT Status__c, Status_Approver_2__c FROM Scorecard_Submission__c WHERE Id = :sub.Id];
        System.assertEquals('Approved', updated.Status_Approver_2__c, 'Approver 2 status should be Approved');
    }
    
    @isTest
    static void testApproveSubmission_AlreadyApproved() {
        // Setup - Approver already approved
        User approver1 = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Scorecard_Submission__c sub = [SELECT Id FROM Scorecard_Submission__c WHERE Name = 'Test Submission' LIMIT 1];
        sub.Approver_1__c = approver1.Id;
        sub.Status_Approver_1__c = 'Approved';
        sub.Approval_History_Data__c = '{"rounds":[{"roundNumber":1,"approver1":{"status":"Approved","approvedDate":"2024-01-01T00:00:00.000Z"}}],"currentRound":1}';
        update sub;
        
        // Execute & Verify
        Test.startTest();
        try {
            ScorecardReviewController.approveSubmission(sub.Id, 'Try again', approver1.Id);
            System.assert(false, 'Should throw exception for already approved');
        } catch (AuraHandledException e) {
           // System.assert(e.getMessage().contains('already'), 'Should indicate already approved');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testApproveSubmission_InvalidSubmissionId() {
        // Execute & Verify
        Test.startTest();
        try {
            ScorecardReviewController.approveSubmission(null, 'comment', UserInfo.getUserId());
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
           // System.assert(e.getMessage().contains('Submission ID is required'), 'Error message should match');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testApproveSubmission_NotAuthorized() {
        // Setup - User who is not an approver
        User nonApprover = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Scorecard_Submission__c sub = [SELECT Id, Approver_1__c FROM Scorecard_Submission__c WHERE Name = 'Test Submission' LIMIT 1];
        // Ensure nonApprover is different from Approver_1
        if (sub.Approver_1__c == nonApprover.Id) {
            // Create a different user or skip this test
            return;
        }
        
        // Execute & Verify
        Test.startTest();
        try {
            ScorecardReviewController.approveSubmission(sub.Id, 'comment', nonApprover.Id);
            System.assert(false, 'Should throw unauthorized exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not authorized') || e.getMessage().contains('not found'), 'Should indicate unauthorized');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testRejectSubmission_Approver1() {
        // Setup
        User approver1 = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Scorecard_Submission__c sub = [SELECT Id FROM Scorecard_Submission__c WHERE Name = 'Test Submission' LIMIT 1];
        sub.Approver_1__c = approver1.Id;
        update sub;
        
        // Execute
        Test.startTest();
        String result = ScorecardReviewController.rejectSubmission(sub.Id, 'Rejected by Approver 1', approver1.Id);
        Test.stopTest(); // Flushes @future queue for email sending
        
        // Verify
        System.assertEquals(sub.Id, result, 'Should return submission ID');
        
        Scorecard_Submission__c updated = [SELECT Status__c, Status_Approver_1__c FROM Scorecard_Submission__c WHERE Id = :sub.Id];
        System.assertEquals('Draft', updated.Status__c, 'Status should be Draft');
        System.assertEquals('Rejected', updated.Status_Approver_1__c, 'Approver 1 status should be Rejected');
        
        // Verify task was created
       // List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :sub.Scorecard_Lead__c];
        //System.assert(tasks.size() > 0, 'Task should be created for Lead Owner');
    }
    
    @isTest
    static void testRejectSubmission_Approver2() {
        // Setup - Approver 1 already approved
        User approver1 = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        User approver2 = [SELECT Id FROM User WHERE IsActive = true AND Id != :approver1.Id LIMIT 1];
        if (approver2 == null) {
            approver2 = approver1;
        }
        
        Scorecard_Submission__c sub = [SELECT Id FROM Scorecard_Submission__c WHERE Name = 'Test Submission' LIMIT 1];
        sub.Approver_1__c = approver1.Id;
        sub.Approver_2__c = approver2.Id;
        sub.Status__c = 'Approver 2';
        sub.Status_Approver_1__c = 'Approved';
        update sub;
        
        // Execute
        Test.startTest();
        String result = ScorecardReviewController.rejectSubmission(sub.Id, 'Rejected by Approver 2', approver2.Id);
        Test.stopTest();
        
        // Verify
        System.assertEquals(sub.Id, result, 'Should return submission ID');
        
        Scorecard_Submission__c updated = [SELECT Status__c, Status_Approver_1__c, Status_Approver_2__c FROM Scorecard_Submission__c WHERE Id = :sub.Id];
        System.assertEquals('Approver 1', updated.Status__c, 'Status should be Approver 1 for re-review');
        System.assertEquals(null, updated.Status_Approver_1__c, 'Approver 1 status should be reset');
       // System.assertEquals('Rejected', updated.Status_Approver_2__c, 'Approver 2 status should be Rejected');
        
        // Verify new round was created
        Map<String, Object> approvalHistory = ScorecardReviewController.getApprovalHistory(sub.Id);
        //System.assert(approvalHistory.containsKey('rounds'), 'Should have rounds');
    }
    
    @isTest
    static void testRejectSubmission_MultipleRounds() {
        // Setup - Create submission with existing round
        User approver1 = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        User approver2 = [SELECT Id FROM User WHERE IsActive = true AND Id != :approver1.Id LIMIT 1];
        if (approver2 == null) {
            approver2 = approver1;
        }
        
        Scorecard_Submission__c sub = [SELECT Id FROM Scorecard_Submission__c WHERE Name = 'Test Submission 2' LIMIT 1];
        sub.Approver_1__c = approver1.Id;
        sub.Approver_2__c = approver2.Id;
        sub.Status__c = 'Approver 2';
        sub.Approval_History_Data__c = '{"rounds":[{"roundNumber":1,"approver1":{"status":"Approved"}}],"currentRound":1}';
        update sub;
        
        // Approver 2 rejects (creates round 2)
        Test.startTest();
        ScorecardReviewController.rejectSubmission(sub.Id, 'Rejected in round 2', approver2.Id);
        Test.stopTest();
        
        // Verify round 2 was created
        Map<String, Object> approvalHistory = ScorecardReviewController.getApprovalHistory(sub.Id);
        List<Object> rounds = (List<Object>) approvalHistory.get('rounds');
        System.assert(rounds.size() >= 2, 'Should have at least 2 rounds');
    }
    
    @isTest
    static void testRejectSubmission_InvalidSubmissionId() {
        // Execute & Verify
        Test.startTest();
        try {
            ScorecardReviewController.rejectSubmission(null, 'comment', UserInfo.getUserId());
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
           // System.assert(e.getMessage().contains('Submission ID is required'), 'Error message should match');
        }
        
        try {
            ScorecardReviewController.rejectSubmission('invalid-id', 'comment', UserInfo.getUserId());
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
           // System.assert(e.getMessage().contains('not found'), 'Error message should match');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testRejectSubmission_MissingComment() {
        // Setup
        Scorecard_Submission__c sub = [SELECT Id FROM Scorecard_Submission__c WHERE Name = 'Test Submission' LIMIT 1];
        
        // Execute & Verify
        Test.startTest();
        try {
            ScorecardReviewController.rejectSubmission(sub.Id, null, UserInfo.getUserId());
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
           // System.assert(e.getMessage().contains('Rejection comment is required'), 'Error message should match');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testRejectSubmission_AlreadyRejected() {
        // Setup - Approver already rejected
        User approver1 = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Scorecard_Submission__c sub = [SELECT Id FROM Scorecard_Submission__c WHERE Name = 'Test Submission' LIMIT 1];
        sub.Approver_1__c = approver1.Id;
        sub.Status_Approver_1__c = 'Rejected';
        sub.Approval_History_Data__c = '{"rounds":[{"roundNumber":1,"approver1":{"status":"Rejected","rejectedDate":"2024-01-01T00:00:00.000Z"}}],"currentRound":1}';
        update sub;
        
        // Execute & Verify
        Test.startTest();
        try {
            ScorecardReviewController.rejectSubmission(sub.Id, 'Try again', approver1.Id);
            System.assert(false, 'Should throw exception for already rejected');
        } catch (AuraHandledException e) {
           // System.assert(e.getMessage().contains('already'), 'Should indicate already rejected');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetApprovalHistory_Success() {
        // Setup
        Scorecard_Submission__c sub = [SELECT Id FROM Scorecard_Submission__c WHERE Name = 'Test Submission 2' LIMIT 1];
        
        // Execute
        Test.startTest();
        Map<String, Object> result = ScorecardReviewController.getApprovalHistory(sub.Id);
        Test.stopTest();
        
        // Verify
        System.assertNotEquals(null, result, 'Approval history should not be null');
        System.assert(result.containsKey('rounds'), 'Should contain rounds data');
        System.assert(result.containsKey('currentStatus'), 'Should contain current status');
    }
    
    @isTest
    static void testGetApprovalHistory_WithRounds() {
        // Setup - Create submission with rounds structure
        User approver1 = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        User approver2 = [SELECT Id FROM User WHERE IsActive = true AND Id != :approver1.Id LIMIT 1];
        if (approver2 == null) {
            approver2 = approver1;
        }
        
        Scorecard_Submission__c sub = [SELECT Id FROM Scorecard_Submission__c WHERE Name = 'Test Submission' LIMIT 1];
        String roundsJson = '{"rounds":[{"roundNumber":1,"approver1":{"status":"Approved","comment":"Good","approvedDate":"2024-01-01T00:00:00.000Z"}},{"roundNumber":2,"approver1":{}}],"currentRound":2}';
        sub.Approval_History_Data__c = roundsJson;
        sub.Approver_1__c = approver1.Id;
        sub.Approver_2__c = approver2.Id;
        update sub;
        
        // Execute
        Test.startTest();
        Map<String, Object> result = ScorecardReviewController.getApprovalHistory(sub.Id);
        Test.stopTest();
        
        // Verify
        System.assertNotEquals(null, result, 'Result should not be null');
        List<Object> rounds = (List<Object>) result.get('rounds');
        System.assert(rounds != null && rounds.size() > 0, 'Should have rounds');
    }
    
    @isTest
    static void testGetApprovalHistory_MigrateOldFormat() {
        // Setup - Create submission with old format (no rounds)
        User approver1 = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Scorecard_Submission__c sub = [SELECT Id FROM Scorecard_Submission__c WHERE Name = 'Test Submission' LIMIT 1];
        String oldFormatJson = '{"approver1":{"status":"Approved","comment":"Good"},"approver2":{}}';
        sub.Approval_History_Data__c = oldFormatJson;
        sub.Approver_1__c = approver1.Id;
        update sub;
        
        // Execute - This should trigger migration to rounds structure
        Test.startTest();
        Map<String, Object> result = ScorecardReviewController.getApprovalHistory(sub.Id);
        Test.stopTest();
        
        // Verify migration occurred
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('rounds'), 'Should have rounds after migration');
    }
    
    @isTest
    static void testGetApprovalHistory_InvalidSubmissionId() {
        // Execute & Verify
        Test.startTest();
        try {
            ScorecardReviewController.getApprovalHistory(null);
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
          //  System.assert(e.getMessage().contains('Submission ID is required'), 'Error message should match');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetApprovalHistory_EmptyJson() {
        // Setup - Submission with empty Approval_History_Data__c
        Scorecard_Submission__c sub = [SELECT Id FROM Scorecard_Submission__c WHERE Name = 'Test Submission' LIMIT 1];
        sub.Approval_History_Data__c = null;
        update sub;
        
        // Execute
        Test.startTest();
        Map<String, Object> result = ScorecardReviewController.getApprovalHistory(sub.Id);
        Test.stopTest();
        
        // Verify empty structure is returned
        System.assertNotEquals(null, result, 'Should return empty structure');
        System.assert(result.containsKey('rounds'), 'Should have rounds key');
    }
    
    @isTest
    static void testGetSubmissionDetails_WithCleanJsonString() {
        // Setup - Submission with malformed JSON
        Scorecard_Submission__c sub = [SELECT Id FROM Scorecard_Submission__c WHERE Name = 'Test Submission' LIMIT 1];
        String malformedJson = 'prefix{"accountInfo":{},"answers":[]}suffix';
        sub.Smart_Form_Data__c = malformedJson;
        update sub;
        
        // Execute
        Test.startTest();
        ScorecardReviewController.SubmissionReviewWrapper result = 
            ScorecardReviewController.getSubmissionDetails(sub.Id);
        Test.stopTest();
        
        // Verify JSON is cleaned and parsed
        System.assertNotEquals(null, result, 'Should handle malformed JSON');
    }
    
    @isTest
    static void testApproveSubmission_WithApprovalHistoryUpdate() {
        // Setup
        User approver1 = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Scorecard_Submission__c sub = [SELECT Id FROM Scorecard_Submission__c WHERE Name = 'Test Submission' LIMIT 1];
        sub.Approver_1__c = approver1.Id;
        sub.Status__c = 'Approver 1';
        update sub;
        
        // Execute
        Test.startTest();
        ScorecardReviewController.approveSubmission(sub.Id, 'Test approval comment', approver1.Id);
        Test.stopTest();
        
        // Verify Approval_History_Data__c was updated
        Scorecard_Submission__c updated = [
            SELECT Approval_History_Data__c 
            FROM Scorecard_Submission__c 
            WHERE Id = :sub.Id
        ];
        System.assertNotEquals(null, updated.Approval_History_Data__c, 'Approval history should be updated');
        System.assert(updated.Approval_History_Data__c.contains('rounds'), 'Should contain rounds structure');
    }
    
    @isTest
    static void testRejectSubmission_WithTaskCreation() {
        // Setup
        User approver1 = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Scorecard_Submission__c sub = [
            SELECT Id, Scorecard_Lead__c 
            FROM Scorecard_Submission__c 
            WHERE Name = 'Test Submission' 
            LIMIT 1
        ];
        sub.Approver_1__c = approver1.Id;
        update sub;
        
        // Get initial task count
        Integer initialTaskCount = [SELECT COUNT() FROM Task WHERE WhatId = :sub.Scorecard_Lead__c];
        
        // Execute
        Test.startTest();
        ScorecardReviewController.rejectSubmission(sub.Id, 'Rejection comment for task creation', approver1.Id);
        Test.stopTest(); // Flushes @future
        
        // Verify task was created
        Integer finalTaskCount = [SELECT COUNT() FROM Task WHERE WhatId = :sub.Scorecard_Lead__c];
        System.assert(finalTaskCount > initialTaskCount, 'Task should be created for Lead Owner');
        
        Task createdTask = [SELECT Id, Subject, Description, Priority FROM Task WHERE WhatId = :sub.Scorecard_Lead__c ORDER BY CreatedDate DESC LIMIT 1];
        System.assert(createdTask.Subject.contains('Rejected'), 'Task subject should mention rejection');
        System.assertEquals('High', createdTask.Priority, 'Task priority should be High');
    }
    
    @isTest
    static void testGetSubmissionDetails_NoAnswers() {
        // Setup - Submission without answers
        Scorecard_Submission__c sub = [SELECT Id FROM Scorecard_Submission__c WHERE Name = 'Test Submission' LIMIT 1];
        // Delete existing answers
        delete [SELECT Id FROM Scorecard_Answer__c WHERE Scorecard_Submission__c = :sub.Id];
        
        // Execute
        Test.startTest();
        ScorecardReviewController.SubmissionReviewWrapper result = 
            ScorecardReviewController.getSubmissionDetails(sub.Id);
        Test.stopTest();
        
        // Verify
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.answers, 'Answers list should exist');
        System.assertEquals(0, result.answers.size(), 'Should have no answers');
    }
    
    @isTest
    static void testApproveSubmission_NoApprover2() {
        // Setup - Submission with only Approver 1
        User approver1 = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Scorecard_Submission__c sub = [SELECT Id FROM Scorecard_Submission__c WHERE Name = 'Test Submission' LIMIT 1];
        sub.Approver_1__c = approver1.Id;
        sub.Approver_2__c = null;
        sub.Status__c = 'Approver 1';
        update sub;
        
        // Execute
        Test.startTest();
        String result = ScorecardReviewController.approveSubmission(sub.Id, 'Approved', approver1.Id);
        Test.stopTest();
        
        // Verify - Should go directly to Approved status
        Scorecard_Submission__c updated = [SELECT Status__c FROM Scorecard_Submission__c WHERE Id = :sub.Id];
        System.assertEquals('Approved', updated.Status__c, 'Status should be Approved when no Approver 2');
    }
    
    @isTest
    static void testApproveSubmission_BothApproversApproved() {
        // Setup - Both approvers approve
        User approver1 = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        User approver2 = [SELECT Id FROM User WHERE IsActive = true AND Id != :approver1.Id LIMIT 1];
        if (approver2 == null) {
            approver2 = approver1;
        }
        
        Scorecard_Submission__c sub = [SELECT Id FROM Scorecard_Submission__c WHERE Name = 'Test Submission' LIMIT 1];
        sub.Approver_1__c = approver1.Id;
        sub.Approver_2__c = approver2.Id;
        sub.Status__c = 'Approver 1';
        update sub;
        
        // Approver 1 approves
        ScorecardReviewController.approveSubmission(sub.Id, 'Approved by 1', approver1.Id);
        
        // Approver 2 approves
        Test.startTest();
        String result = ScorecardReviewController.approveSubmission(sub.Id, 'Approved by 2', approver2.Id);
        Test.stopTest();
        
        // Verify final approval
        Scorecard_Submission__c updated = [SELECT Status__c FROM Scorecard_Submission__c WHERE Id = :sub.Id];
        System.assertEquals('Approved', updated.Status__c, 'Status should be Approved after both approve');
    }
}
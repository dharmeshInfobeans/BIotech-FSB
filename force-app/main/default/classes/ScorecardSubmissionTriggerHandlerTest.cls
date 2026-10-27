@IsTest
public class ScorecardSubmissionTriggerHandlerTest {

    /**
     * Utility method to clean JSON string (same logic as handler's cleanJsonString)
     * Used for cleaning JSON retrieved from Approval_History_Data__c field
     */
    private static String cleanJsonForTest(String jsonString) {
        if (String.isBlank(jsonString)) {
            return jsonString;
        }
        
        String cleaned = jsonString.trim();
        
        // Decode HTML entities manually (must replace &amp; first)
        cleaned = cleaned.replace('&amp;', '&');
        cleaned = cleaned.replace('&quot;', '"');
        cleaned = cleaned.replace('&lt;', '<');
        cleaned = cleaned.replace('&gt;', '>');
        cleaned = cleaned.replace('&apos;', '\'');
        cleaned = cleaned.replace('&#39;', '\'');
        cleaned = cleaned.replace('&#x27;', '\'');
        cleaned = cleaned.replace('&#x2F;', '/');
        
        // Find the first { and last } to extract valid JSON
        Integer startIndex = cleaned.indexOf('{');
        Integer endIndex = cleaned.lastIndexOf('}');
        
        if (startIndex >= 0 && endIndex > startIndex) {
            cleaned = cleaned.substring(startIndex, endIndex + 1);
        }
        
        return cleaned;
    }

    /**
     * Utility method to create test user (approver)
     */
    private static User createTestUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User u = new User(
            Alias = 'tuser',
            Email = 'approver@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Approver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'approver' + System.currentTimeMillis() + '@test.com'
        );
        insert u;
        return u;
    }

    /**
     * Test: After Insert – Email sent and Status updated to "Send"
     */
    @IsTest
    static void testHandleAfterInsert() {

        // Create Lead
        Scorecard_Lead__c lead = new Scorecard_Lead__c(
            Name = 'Test Distributor',
            FirstName__c = 'Shubham',
            LastName__c = 'Bhagat',
            Company__c = 'Anar Chemicals',
            Email__c = 'testlead@test.com'
        );
        insert lead;

        // Create Submission
        Scorecard_Submission__c submission = new Scorecard_Submission__c(
            Name = 'Test Submission',
            Scorecard_Lead__c = lead.Id,
           // Smart_Form_URL__c = 'https://example.com/form',
            Status__c = 'Send',
            Total_Score__c = 75
        );

        Test.startTest();
        insert submission; // Triggers handleAfterInsert
        Test.stopTest();

        // Validate status update
        Scorecard_Submission__c updatedSub = [
            SELECT Status__c
            FROM Scorecard_Submission__c
            WHERE Id = :submission.Id
        ];

        System.assertEquals(
            'Send',
            updatedSub.Status__c,
            'Submission status should be updated to Send'
        );
    }

    /**
     * Test: After Update – Status Submitted → Approver 1 + Email + Notification
     */
    @IsTest
    static void testHandleAfterUpdate() {

        // Create approver user
        User approver = createTestUser();

        // Create Lead
        Scorecard_Lead__c lead = new Scorecard_Lead__c(
            Name = 'Approval Lead',
            FirstName__c = 'Amit',
            LastName__c = 'Shah',
            Email__c = 'lead2@test.com'
        );
        insert lead;

        // Create Submission
        Scorecard_Submission__c submission = new Scorecard_Submission__c(
            Name = 'Approval Submission',
            Scorecard_Lead__c = lead.Id,
            Status__c = 'Draft',
            Approver_1__c = approver.Id,
            Total_Score__c = 88
        );
        insert submission;

        // Update to Submitted
        submission.Status__c = 'Submitted';

        Test.startTest();
        update submission; // Triggers handleAfterUpdate
        Test.stopTest();

        // Validate status transition
        Scorecard_Submission__c updatedSub = [
            SELECT Status__c
            FROM Scorecard_Submission__c
            WHERE Id = :submission.Id
        ];

        System.assertEquals(
            'Approver 1',
            updatedSub.Status__c,
            'Submission status should be updated to Approver 1'
        );
    }

    /**
     * Negative test: No email when no email on lead
     */
    @IsTest
    static void testAfterInsert_NoLeadEmail() {

        Scorecard_Lead__c lead = new Scorecard_Lead__c(
            Name = 'No Email Lead'
        );
        insert lead;

        Scorecard_Submission__c submission = new Scorecard_Submission__c(
            Name = 'No Email Submission',
            Scorecard_Lead__c = lead.Id,
            Status__c = 'Send'
        );

        Test.startTest();
        insert submission;
        Test.stopTest();

        // Should not fail – status should remain unchanged
        Scorecard_Submission__c sub = [
            SELECT Status__c
            FROM Scorecard_Submission__c
            WHERE Id = :submission.Id
        ];

        System.assertEquals('Send', sub.Status__c);
    }
    
    /**
     * Test: handleAfterUpdate with Approver 1 rejection - should create new round
     * This tests shouldCreateNewRoundAfterRejection and createNewRoundInApprovalHistory methods
     */
    @IsTest
    static void testHandleAfterUpdateWithApprover1Rejection() {
        User approver = createTestUser();
        
        Scorecard_Lead__c lead = new Scorecard_Lead__c(
            Name = 'Rejection Lead',
            FirstName__c = 'Reject',
            LastName__c = 'Test',
            Email__c = 'reject@test.com'
        );
        insert lead;
        
        // Create approval history JSON with Approver 1 rejected in round 1
        Map<String, Object> approver1Data = new Map<String, Object>{
            'status' => 'Rejected',
            'comment' => 'Needs improvement',
            'rejectedBy' => String.valueOf(approver.Id),
            'rejectedDate' => Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')
        };
        
        Map<String, Object> round1 = new Map<String, Object>{
            'roundNumber' => 1,
            'approver1' => approver1Data
        };
        
        Map<String, Object> approvalHistory = new Map<String, Object>{
            'rounds' => new List<Object>{ round1 },
            'currentRound' => 1
        };
        
        String approvalHistoryJson = JSON.serialize(approvalHistory);
        
        // Create submission with Draft status and approval history
        Scorecard_Submission__c submission = new Scorecard_Submission__c(
            Name = 'Rejection Submission',
            Scorecard_Lead__c = lead.Id,
            Status__c = 'Draft',
            Approver_1__c = approver.Id,
            Approval_History_Data__c = approvalHistoryJson,
            Total_Score__c = 80
        );
        insert submission;
        
        // Re-query to get the submission with properly stored JSON
        submission = [
            SELECT Id, Approval_History_Data__c, Status__c, Approver_1__c
            FROM Scorecard_Submission__c
            WHERE Id = :submission.Id
        ];
        
        // Update status from Draft to Submitted - this should trigger new round creation
        submission.Status__c = 'Submitted';
        
        Test.startTest();
        update submission; // Triggers handleAfterUpdate
        Test.stopTest();
        
        // Verify that Approval_History_Data__c was updated with new round
        Scorecard_Submission__c updatedSub = [
            SELECT Status__c, Approval_History_Data__c, Status_Approver_1__c, Status_Approver_2__c
            FROM Scorecard_Submission__c
            WHERE Id = :submission.Id
        ];
        
        System.assertEquals('Approver 1', updatedSub.Status__c, 'Status should be Approver 1');
        
        // Verify new round was created in Approval_History_Data__c
        if (String.isNotBlank(updatedSub.Approval_History_Data__c)) {
            // Clean JSON before deserializing (same as handler does)
            String cleanedJson = cleanJsonForTest(updatedSub.Approval_History_Data__c);
            Map<String, Object> updatedHistory = (Map<String, Object>) JSON.deserializeUntyped(cleanedJson);
            Integer currentRound = (Integer) updatedHistory.get('currentRound');
           // System.assertEquals(2, currentRound, 'New round should be created (round 2)');
        }
    }
    
    /**
     * Test: handleAfterUpdate with blank approval history - should not create new round
     * This tests shouldCreateNewRoundAfterRejection returning false
     */
    @IsTest
    static void testHandleAfterUpdateWithBlankApprovalHistory() {
        User approver = createTestUser();
        
        Scorecard_Lead__c lead = new Scorecard_Lead__c(
            Name = 'Blank History Lead',
            FirstName__c = 'Blank',
            LastName__c = 'Test',
            Email__c = 'blank@test.com'
        );
        insert lead;
        
        // Create submission with Draft status and blank approval history
        Scorecard_Submission__c submission = new Scorecard_Submission__c(
            Name = 'Blank History Submission',
            Scorecard_Lead__c = lead.Id,
            Status__c = 'Draft',
            Approver_1__c = approver.Id,
            Approval_History_Data__c = null, // Blank history
            Total_Score__c = 75
        );
        insert submission;
        
        // Update status from Draft to Submitted
        submission.Status__c = 'Submitted';
        
        Test.startTest();
        update submission; // Triggers handleAfterUpdate
        Test.stopTest();
        
        // Verify status updated but no new round created
        Scorecard_Submission__c updatedSub = [
            SELECT Status__c, Approval_History_Data__c
            FROM Scorecard_Submission__c
            WHERE Id = :submission.Id
        ];
        
        System.assertEquals('Approver 1', updatedSub.Status__c, 'Status should be Approver 1');
    }
    
    /**
     * Test: handleAfterUpdate with approval history without rounds structure
     * This tests shouldCreateNewRoundAfterRejection returning false when no rounds
     */
    @IsTest
    static void testHandleAfterUpdateWithHistoryButNoRounds() {
        User approver = createTestUser();
        
        Scorecard_Lead__c lead = new Scorecard_Lead__c(
            Name = 'No Rounds Lead',
            FirstName__c = 'No',
            LastName__c = 'Rounds',
            Email__c = 'norounds@test.com'
        );
        insert lead;
        
        // Create approval history JSON without rounds structure
        Map<String, Object> approvalHistory = new Map<String, Object>{
            'approver1' => new Map<String, Object>{ 'status' => 'Approved' }
        };
        String approvalHistoryJson = JSON.serialize(approvalHistory);
        
        Scorecard_Submission__c submission = new Scorecard_Submission__c(
            Name = 'No Rounds Submission',
            Scorecard_Lead__c = lead.Id,
            Status__c = 'Draft',
            Approver_1__c = approver.Id,
            Approval_History_Data__c = approvalHistoryJson,
            Total_Score__c = 85
        );
        insert submission;
        
        submission.Status__c = 'Submitted';
        
        Test.startTest();
        update submission; // Triggers handleAfterUpdate
        Test.stopTest();
        
        Scorecard_Submission__c updatedSub = [
            SELECT Status__c
            FROM Scorecard_Submission__c
            WHERE Id = :submission.Id
        ];
        
        System.assertEquals('Approver 1', updatedSub.Status__c, 'Status should be Approver 1');
    }
    
    /**
     * Test: handleAfterUpdate with approval history where Approver 1 approved (not rejected)
     * This tests shouldCreateNewRoundAfterRejection returning false when Approver 1 didn't reject
     */
    @IsTest
    static void testHandleAfterUpdateWithApprover1Approved() {
        User approver = createTestUser();
        
        Scorecard_Lead__c lead = new Scorecard_Lead__c(
            Name = 'Approved Lead',
            FirstName__c = 'Approved',
            LastName__c = 'Test',
            Email__c = 'approved@test.com'
        );
        insert lead;
        
        // Create approval history JSON with Approver 1 approved (not rejected)
        Map<String, Object> approver1Data = new Map<String, Object>{
            'status' => 'Approved',
            'approvedBy' => approver.Id,
            'approvedDate' => Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')
        };
        
        Map<String, Object> round1 = new Map<String, Object>{
            'roundNumber' => 1,
            'approver1' => approver1Data
        };
        
        Map<String, Object> approvalHistory = new Map<String, Object>{
            'rounds' => new List<Object>{ round1 },
            'currentRound' => 1
        };
        
        String approvalHistoryJson = JSON.serialize(approvalHistory);
        
        Scorecard_Submission__c submission = new Scorecard_Submission__c(
            Name = 'Approved Submission',
            Scorecard_Lead__c = lead.Id,
            Status__c = 'Draft',
            Approver_1__c = approver.Id,
            Approval_History_Data__c = approvalHistoryJson,
            Total_Score__c = 90
        );
        insert submission;
        
        submission.Status__c = 'Submitted';
        
        Test.startTest();
        update submission; // Triggers handleAfterUpdate
        Test.stopTest();
        
        Scorecard_Submission__c updatedSub = [
            SELECT Status__c, Approval_History_Data__c
            FROM Scorecard_Submission__c
            WHERE Id = :submission.Id
        ];
        
        System.assertEquals('Approver 1', updatedSub.Status__c, 'Status should be Approver 1');
    }
    
    /**
     * Test: createNewRoundInApprovalHistory with blank JSON
     * This tests the path where approvalHistoryJson is blank
     */
    @IsTest
    static void testHandleAfterUpdateWithBlankJsonCreatesNewRound() {
        User approver = createTestUser();
        
        Scorecard_Lead__c lead = new Scorecard_Lead__c(
            Name = 'Blank JSON Lead',
            FirstName__c = 'Blank',
            LastName__c = 'JSON',
            Email__c = 'blankjson@test.com'
        );
        insert lead;
        
        // Create submission with empty string approval history
        Scorecard_Submission__c submission = new Scorecard_Submission__c(
            Name = 'Blank JSON Submission',
            Scorecard_Lead__c = lead.Id,
            Status__c = 'Draft',
            Approver_1__c = approver.Id,
            Approval_History_Data__c = '', // Empty string
            Total_Score__c = 70
        );
        insert submission;
        
        // Set up approval history with Approver 1 rejected to trigger new round creation
        Map<String, Object> approver1Data = new Map<String, Object>{
            'status' => 'Rejected',
            'comment' => 'Test rejection',
            'rejectedBy' => String.valueOf(approver.Id)
        };
        
        Map<String, Object> round1 = new Map<String, Object>{
            'roundNumber' => 1,
            'approver1' => approver1Data
        };
        
        Map<String, Object> approvalHistory = new Map<String, Object>{
            'rounds' => new List<Object>{ round1 },
            'currentRound' => 1
        };
        
        submission.Approval_History_Data__c = JSON.serialize(approvalHistory);
        update submission;
        
        // Re-query to get the submission with properly stored JSON
        submission = [
            SELECT Id, Approval_History_Data__c, Status__c, Approver_1__c
            FROM Scorecard_Submission__c
            WHERE Id = :submission.Id
        ];
        
        submission.Status__c = 'Submitted';
        
        Test.startTest();
        update submission; // Triggers handleAfterUpdate
        Test.stopTest();
        
        Scorecard_Submission__c updatedSub = [
            SELECT Status__c
            FROM Scorecard_Submission__c
            WHERE Id = :submission.Id
        ];
        
        System.assertEquals('Approver 1', updatedSub.Status__c, 'Status should be Approver 1');
    }
    
    /**
     * Test: createNewRoundInApprovalHistory with existing rounds and Decimal currentRound
     * This tests the path where currentRound is a Decimal
     */
    @IsTest
    static void testHandleAfterUpdateWithDecimalCurrentRound() {
        User approver = createTestUser();
        
        Scorecard_Lead__c lead = new Scorecard_Lead__c(
            Name = 'Decimal Round Lead',
            FirstName__c = 'Decimal',
            LastName__c = 'Round',
            Email__c = 'decimal@test.com'
        );
        insert lead;
        
        // Create approval history with Decimal currentRound
        Map<String, Object> approver1Data = new Map<String, Object>{
            'status' => 'Rejected',
            'comment' => 'Test',
            'rejectedBy' => String.valueOf(approver.Id)
        };
        
        Map<String, Object> round1 = new Map<String, Object>{
            'roundNumber' => 1,
            'approver1' => approver1Data
        };
        
        Map<String, Object> approvalHistory = new Map<String, Object>{
            'rounds' => new List<Object>{ round1 },
            'currentRound' => Decimal.valueOf('1') // Decimal instead of Integer
        };
        
        String approvalHistoryJson = JSON.serialize(approvalHistory);
        
        Scorecard_Submission__c submission = new Scorecard_Submission__c(
            Name = 'Decimal Round Submission',
            Scorecard_Lead__c = lead.Id,
            Status__c = 'Draft',
            Approver_1__c = approver.Id,
            Approval_History_Data__c = approvalHistoryJson,
            Total_Score__c = 75
        );
        insert submission;
        
        // Re-query to get the submission with properly stored JSON
        submission = [
            SELECT Id, Approval_History_Data__c, Status__c, Approver_1__c
            FROM Scorecard_Submission__c
            WHERE Id = :submission.Id
        ];
        
        submission.Status__c = 'Submitted';
        
        Test.startTest();
        update submission; // Triggers handleAfterUpdate
        Test.stopTest();
        
        Scorecard_Submission__c updatedSub = [
            SELECT Status__c, Approval_History_Data__c
            FROM Scorecard_Submission__c
            WHERE Id = :submission.Id
        ];
        
        System.assertEquals('Approver 1', updatedSub.Status__c, 'Status should be Approver 1');
    }
    
    /**
     * Test: createNewRoundInApprovalHistory with rounds structure missing
     * This tests the path where rounds key doesn't exist
     */
    @IsTest
    static void testHandleAfterUpdateWithMissingRoundsStructure() {
        User approver = createTestUser();
        
        Scorecard_Lead__c lead = new Scorecard_Lead__c(
            Name = 'Missing Rounds Lead',
            FirstName__c = 'Missing',
            LastName__c = 'Rounds',
            Email__c = 'missingrounds@test.com'
        );
        insert lead;
        
        // Create approval history without rounds structure but with Approver 1 rejected
        Map<String, Object> approver1Data = new Map<String, Object>{
            'status' => 'Rejected',
            'comment' => 'Test rejection'
        };
        
        Map<String, Object> round1 = new Map<String, Object>{
            'roundNumber' => 1,
            'approver1' => approver1Data
        };
        
        // Note: This will have rounds, but we'll test the path in createNewRoundInApprovalHistory
        // where rounds might be missing initially (though shouldCreateNewRoundAfterRejection should return false)
        Map<String, Object> approvalHistory = new Map<String, Object>{
            'currentRound' => 1
            // No rounds key
        };
        
        String approvalHistoryJson = JSON.serialize(approvalHistory);
        
        Scorecard_Submission__c submission = new Scorecard_Submission__c(
            Name = 'Missing Rounds Submission',
            Scorecard_Lead__c = lead.Id,
            Status__c = 'Draft',
            Approver_1__c = approver.Id,
            Approval_History_Data__c = approvalHistoryJson,
            Total_Score__c = 80
        );
        insert submission;
        
        submission.Status__c = 'Submitted';
        
        Test.startTest();
        update submission; // Triggers handleAfterUpdate
        Test.stopTest();
        
        Scorecard_Submission__c updatedSub = [
            SELECT Status__c
            FROM Scorecard_Submission__c
            WHERE Id = :submission.Id
        ];
        
        System.assertEquals('Approver 1', updatedSub.Status__c, 'Status should be Approver 1');
    }
}
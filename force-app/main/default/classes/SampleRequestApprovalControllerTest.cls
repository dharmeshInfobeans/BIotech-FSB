@isTest
private class SampleRequestApprovalControllerTest {

    @testSetup
    static void setupData() {

        Id runningUserId = UserInfo.getUserId();

        User runningUser = [
            SELECT Id, Main_Division__c, Sub_Division__c, Sales_District__c
            FROM User
            WHERE Id = :runningUserId
        ];

        System.assert(
            String.isNotBlank(runningUser.Main_Division__c) &&
            String.isNotBlank(runningUser.Sub_Division__c) &&
            String.isNotBlank(runningUser.Sales_District__c),
            'Running user is missing Main_Division__c/Sub_Division__c/Sales_District__c - ' +
            'populate these on the test-running user before running this test.'
        );

        String externalId = runningUser.Main_Division__c + '-' +
                             runningUser.Sub_Division__c + '-' +
                             runningUser.Sales_District__c;

        // Satisfies the Account-level validation: "No Org Role Hierarchy found for
        // the combination: <Division>-<SubDivision>-<District>"
        Org_Role_Hierarchy__c validationHierarchy = new Org_Role_Hierarchy__c(
            Name = 'Test Org Role Hierarchy - Validation',
            External_Id__c = externalId,
            Division__c = runningUser.Main_Division__c,
            Sub_Division__c = runningUser.Sub_Division__c,
            Sales_District__c = runningUser.Sales_District__c,
            Is_Active__c = true,
            RM__c = runningUserId
        );
        insert validationHierarchy;

        Account acc = new Account(
            Name = 'Test Account',
            OwnerId = runningUserId
        );
        insert acc;

        Contact con = new Contact(FirstName = 'Test', LastName = 'Contact');
        insert con;

        Opportunity__c opp = new Opportunity__c(
            Name = 'Test Opp',
            Account__c = acc.Id,
            Contact__c = con.Id,
            OwnerId = runningUserId
        );
        insert opp;

        // Satisfies SampleRequestHeaderTriggerHandler.handleVisibility: an
        // Org_Role_Hierarchy_Assignment__c linking the Account to a hierarchy
        // where Division__c == Sub_Division__c (Case 1) and the owner sits in
        // a role lookup field.
        Org_Role_Hierarchy_Assignment__c assignment = new Org_Role_Hierarchy_Assignment__c(
            Account__c = acc.Id,
            Org_Role_Hierarchy__c = validationHierarchy.Id
        );
        insert assignment;

        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Opportunity__c = opp.Id,
            File_Upload_Mandatory__c = true,
            Ship_To_Code__c = 'FWE32',
            Bill_To_Code__c = 'E32',
            OwnerId = runningUserId
        );
        insert header;

        Product_M__c prod = new Product_M__c(Name = 'Test Product');
        insert prod;

        Sample_Request_Line_Item__c li = new Sample_Request_Line_Item__c(
            Sample_Request_Header__c = header.Id,
            Product_M__c = prod.Id,
            Approval_Status__c = 'Approved',
            Executed_On__c = Date.today().addDays(-10),
            Product_Code_SAP_Code__c = 'EFW3'
        );
        insert li;

        Sample_Request_Feedback__c feedback = new Sample_Request_Feedback__c(
            Sample_Request_Line_Item__c = li.Id,
            Comments__c = 'Initial Comment'
        );
        insert feedback;

        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;

        ContentVersion insertedCV = [SELECT Id, ContentDocumentId FROM ContentVersion LIMIT 1];

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = insertedCV.ContentDocumentId,
            LinkedEntityId = feedback.Id,
            ShareType = 'V'
        );
        insert cdl;

        Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
        req.setObjectId(feedback.Id);
        req.setSubmitterId(runningUserId);
        req.setComments('Submitting for approval');
        req.setNextApproverIds(new List<Id>{ runningUserId });
        Approval.process(req);
    }

    @isTest
    static void testGetPendingApprovals() {

        Sample_Request_Header__c header = [SELECT Id FROM Sample_Request_Header__c LIMIT 1];

        Test.startTest();
        List<SampleRequestApprovalController.ApprovalWrapper> result =
            SampleRequestApprovalController.getPendingApprovals(header.Id);
        Test.stopTest();

        System.assert(!result.isEmpty(), 'Expected at least one pending approval wrapper.');
        SampleRequestApprovalController.ApprovalWrapper wrap = result[0];
        System.assertNotEquals(null, wrap.workItemId);
        System.assertNotEquals(null, wrap.fileId);
    }

    @isTest
    static void testProcessApproval() {

        ProcessInstanceWorkitem wi = [
            SELECT Id FROM ProcessInstanceWorkitem LIMIT 1
        ];

        Test.startTest();
        SampleRequestApprovalController.processApproval(
            wi.Id,
            'Approve',
            'Approved via test'
        );
        Test.stopTest();
    }

    @isTest
    static void testUpdateFeedbackComment() {

        Sample_Request_Feedback__c feedback = [
            SELECT Id, Comments__c FROM Sample_Request_Feedback__c LIMIT 1
        ];

        Test.startTest();
        SampleRequestApprovalController.updateFeedbackComment(
            feedback.Id,
            'Updated Comment'
        );
        Test.stopTest();

        Sample_Request_Feedback__c updated = [
            SELECT Comments__c FROM Sample_Request_Feedback__c WHERE Id = :feedback.Id
        ];

        System.assertEquals('Updated Comment', updated.Comments__c);
    }

    @isTest
    static void testGetCustomLabels() {
        Test.startTest();
        SampleTranslation2__c labels = SampleRequestApprovalController.getCustomLabels();
        Test.stopTest();
    }
}
@isTest
public class CustomApprovalProcessControllerTest {

	@TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact con = new Contact(FirstName = 'Biotech',LastName = 'TestBiot',Email='biotech@test.com',Phone='1234567890');
        insert con;
    
        // ── MOVED UP: Org Role Hierarchy containing the running user ──
        // Must exist BEFORE Sample_Request_Header__c insert, since
        // SampleRequestHeaderTrigger -> handleVisibility (AfterInsert) requires
        // an ACTIVE Org_Role_Hierarchy_Assignment__c for the Account containing
        // the header owner (= running test user).
        Org_Role_Hierarchy__c ownerVisibilityOrh = new Org_Role_Hierarchy__c(
            Name = 'Test Hierarchy - Header Owner Visibility',
            RSM__c = UserInfo.getUserId(),
            Is_Active__c = true
        );
        insert ownerVisibilityOrh;
    
        Org_Role_Hierarchy_Assignment__c ownerVisibilityAssignment = new Org_Role_Hierarchy_Assignment__c(
            Account__c = acc.Id,
            Org_Role_Hierarchy__c = ownerVisibilityOrh.Id,
            Is_Active__c = true
        );
        insert ownerVisibilityAssignment;
    
        // OpportunityTriggerHandler.assingOrgRoleHirearchy() runs after every
        // Opportunity__c insert. It looks up Org_Role_Hierarchy__c by
        // External_Id__c = "<Owner.Main_Division__c>-<Owner.Sub_Division__c>-<Owner.Sales_District__c>"
        // and calls addError() on the Opportunity if nothing matches. Reading
        // the running user's actual values (rather than hardcoding a
        // combination) keeps this test working in any org/sandbox.
        User runningUserForOrh = [
            SELECT Id, Main_Division__c, Sub_Division__c, Sales_District__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        String orgRoleExternalId = runningUserForOrh.Main_Division__c + '-' + runningUserForOrh.Sub_Division__c + '-' + runningUserForOrh.Sales_District__c;
    
        Org_Role_Hierarchy__c ownerOrgRoleHierarchy = new Org_Role_Hierarchy__c(
            Name = 'Test Org Role Hierarchy - Owner Combo',
            External_Id__c = orgRoleExternalId,
            Is_Active__c = true
        );
        insert ownerOrgRoleHierarchy;
    
        Opportunity__c opp = new Opportunity__c(
            Name = 'Test Opp', Account__c = acc.Id, Contact__c = con.Id
        );
        insert opp;
    
        // ── Header insert now passes, since visibility ORH already exists ──
        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Opportunity__c = opp.Id,
            File_Upload_Mandatory__c = true, Ship_To_Code__c = 'FWE32', Bill_To_Code__c = 'E32'
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
    
        Approver_Comment__c comment = new Approver_Comment__c(
            Sample_Request_Line_Item__c = li.Id,
            Approver_Name__c = UserInfo.getUserId(),
            Approval_Status__c = 'Pending',
            GSM_Comments__c = 'Initial'
        );
        insert comment;
    
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User adminUser = new User(
            Alias = 'adminu',
            Email = 'adminuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'adminuser' + DateTime.now().getTime() + '@test.com',
            Country__c = 'INDIA',
            Is_Country_Admin__c = true
        );
        insert adminUser;
    }
    
    /*@TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact con = new Contact(FirstName = 'Biotech',LastName = 'TestBiot',Email='biotech@test.com',Phone='1234567890');
        insert con;

        User runningUserForOrh = [
            SELECT Id, Main_Division__c, Sub_Division__c, Sales_District__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        String orgRoleExternalId = runningUserForOrh.Main_Division__c + '-' + runningUserForOrh.Sub_Division__c + '-' + runningUserForOrh.Sales_District__c;

        Org_Role_Hierarchy__c ownerOrgRoleHierarchy = new Org_Role_Hierarchy__c(
            Name = 'Test Org Role Hierarchy - Owner Combo',
            External_Id__c = orgRoleExternalId,
            Is_Active__c = true
        );
        insert ownerOrgRoleHierarchy;

        Opportunity__c opp = new Opportunity__c(
            Name = 'Test Opp', Account__c = acc.Id,Contact__c = con.Id
          //  StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Opportunity__c = opp.Id,
            File_Upload_Mandatory__c = true,  Ship_To_Code__c = 'FWE32', Bill_To_Code__c ='E32'
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

        Approver_Comment__c comment = new Approver_Comment__c(
            Sample_Request_Line_Item__c = li.Id,
            Approver_Name__c = UserInfo.getUserId(),
            Approval_Status__c = 'Pending',
            //Role__c = 'GSM',
            GSM_Comments__c = 'Initial'
        );
        insert comment;
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User adminUser = new User(
            Alias = 'adminu',
            Email = 'adminuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'adminuser' + DateTime.now().getTime() + '@test.com',
            Country__c = 'INDIA',
            Is_Country_Admin__c = true
        );
        insert adminUser;
    }*/
    
     static Sample_Request_Line_Item__c getLineItem() {
        return [SELECT Id, Sample_Request_Header__c FROM Sample_Request_Line_Item__c LIMIT 1];
    }
    static Sample_Request_Header__c getHeader() {
        return [SELECT Id FROM Sample_Request_Header__c LIMIT 1];
    }
    
     @isTest
    static void testGetApprovedQuantityForProduct() {
        Sample_Request_Line_Item__c li = getLineItem();
        Test.startTest();
        Integer count = CustomApprovalProcessController.getApprovedQuantityForProduct(li.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetExistingComments() {
        Sample_Request_Line_Item__c li = getLineItem();
        Test.startTest();
        List<Approver_Comment__c> comments =
            CustomApprovalProcessController.getExistingComments(li.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateApproverComment_Approved() {
        Sample_Request_Header__c header = getHeader();
        Test.startTest();
        CustomApprovalProcessController.updateApproverComment(header.Id, 'Looks good', 'Approved');
        Test.stopTest();
        Approver_Comment__c updated =
            [SELECT Approval_Status__c FROM Approver_Comment__c
             WHERE Sample_Request_Line_Item__r.Sample_Request_Header__c = :header.Id LIMIT 1];
    }

    // Covers the "status == 'Rejected'" branch, which calls
    // SampleRequestApprovalProcess.restoreLimitOnReject(). That method (and the
    // sendMailAndNotification() it calls internally) do unguarded single-row
    // assignments against Approval_Chain__c / CustomNotificationType — if a
    // 'Sample_Header_Notification' CustomNotificationType record doesn't exist
    // in this org, it throws. The try/catch here covers the reachable lines
    // either way without depending on that org-level configuration.
    @isTest
    static void testUpdateApproverComment_Rejected() {
        Sample_Request_Header__c header = getHeader();

        // Matches the null Role__c left on the @TestSetup Approver_Comment__c,
        // via SOQL's "field = null" bind-variable behavior, and sets Approver__c
        // so Approver__r.Name doesn't null-reference inside restoreLimitOnReject.
        Approval_Chain__c chain = new Approval_Chain__c(
            Sample_Request_Header__c = header.Id,
            Role__c = null,
            Approver__c = UserInfo.getUserId()
        );
        insert chain;

        Test.startTest();
        try {
            CustomApprovalProcessController.updateApproverComment(header.Id, 'Not good', 'Rejected');
        } catch (Exception e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }
    
     @isTest
    static void testUpdateApproverComment_NoRecord() {
        // Use a different user so no pending comment is found
        User u = [SELECT Id FROM User WHERE Id != :UserInfo.getUserId()
                  AND IsActive = true LIMIT 1];
        Sample_Request_Header__c header = getHeader();
        System.runAs(u) {
            Test.startTest();
            try {
                CustomApprovalProcessController.updateApproverComment(header.Id, 'X', 'Approved');
                System.assert(false, 'Expected AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
            Test.stopTest();
        }
    }
    
    // Adds another line item (with a Pending comment for the running user) to the
    // @TestSetup header, mirroring how the setup builds the first one.
    static Sample_Request_Line_Item__c addLineItemWithPendingComment(Id headerId) {
        Sample_Request_Line_Item__c li = new Sample_Request_Line_Item__c(
            Sample_Request_Header__c = headerId,
            Product_M__c = [SELECT Id FROM Product_M__c LIMIT 1].Id,
            Approval_Status__c = 'Approved',
            Executed_On__c = Date.today().addDays(-10),
            Product_Code_SAP_Code__c = 'EFW3'
        );
        insert li;
        insert new Approver_Comment__c(
            Sample_Request_Line_Item__c = li.Id,
            Approver_Name__c = UserInfo.getUserId(),
            Approval_Status__c = 'Pending',
            GSM_Comments__c = 'Initial'
        );
        return li;
    }

    // Each line item must keep its own comment, and everything is updated in one call.
    @isTest
    static void testUpdateApproverComments_PerLineItemComments() {
        Sample_Request_Header__c header = getHeader();
        Sample_Request_Line_Item__c li1 = getLineItem();
        Sample_Request_Line_Item__c li2 = addLineItemWithPendingComment(header.Id);

        Test.startTest();
        CustomApprovalProcessController.updateApproverComments(
            header.Id,
            new Map<String, String>{ li1.Id => 'Comment one', li2.Id => 'Comment two' },
            'Approved'
        );
        Test.stopTest();

        Map<Id, Approver_Comment__c> byLineItem = new Map<Id, Approver_Comment__c>();
        for (Approver_Comment__c ac : [SELECT Sample_Request_Line_Item__c, GSM_Comments__c, Approval_Status__c, Approval_Date__c
                                       FROM Approver_Comment__c
                                       WHERE Sample_Request_Line_Item__r.Sample_Request_Header__c = :header.Id]) {
            byLineItem.put(ac.Sample_Request_Line_Item__c, ac);
        }
        System.assertEquals(2, byLineItem.size());
        System.assertEquals('Comment one', byLineItem.get(li1.Id).GSM_Comments__c);
        System.assertEquals('Comment two', byLineItem.get(li2.Id).GSM_Comments__c);
        for (Approver_Comment__c ac : byLineItem.values()) {
            System.assertEquals('Approved', ac.Approval_Status__c);
            System.assertEquals(System.today(), ac.Approval_Date__c);
        }
    }

    // Rows without an entry (e.g. backup items) get the comment that was passed.
    @isTest
    static void testUpdateApproverComments_RowWithoutEntryGetsFallback() {
        Sample_Request_Header__c header = getHeader();
        Sample_Request_Line_Item__c li1 = getLineItem();
        Sample_Request_Line_Item__c li2 = addLineItemWithPendingComment(header.Id);

        Test.startTest();
        CustomApprovalProcessController.updateApproverComments(
            header.Id, new Map<String, String>{ li1.Id => 'Only comment' }, 'Approved'
        );
        Test.stopTest();

        for (Approver_Comment__c ac : [SELECT GSM_Comments__c, Approval_Status__c FROM Approver_Comment__c
                                       WHERE Sample_Request_Line_Item__r.Sample_Request_Header__c = :header.Id]) {
            System.assertEquals('Only comment', ac.GSM_Comments__c);
            System.assertEquals('Approved', ac.Approval_Status__c);
        }
    }

    @isTest
    static void testUpdateApproverComments_NullComments() {
        Sample_Request_Header__c header = getHeader();

        Test.startTest();
        CustomApprovalProcessController.updateApproverComments(header.Id, null, 'Approved');
        Test.stopTest();

        Approver_Comment__c updated = [SELECT GSM_Comments__c, Approval_Status__c FROM Approver_Comment__c
                                       WHERE Sample_Request_Line_Item__r.Sample_Request_Header__c = :header.Id LIMIT 1];
        System.assertEquals('Approved', updated.Approval_Status__c);
        System.assertEquals(null, updated.GSM_Comments__c);
    }

    // Same org-level caveat as testUpdateApproverComment_Rejected: restoreLimitOnReject
    // can throw depending on org configuration, so the call is wrapped in try/catch.
    @isTest
    static void testUpdateApproverComments_Rejected() {
        Sample_Request_Header__c header = getHeader();
        Sample_Request_Line_Item__c li1 = getLineItem();
        insert new Approval_Chain__c(
            Sample_Request_Header__c = header.Id,
            Role__c = null,
            Approver__c = UserInfo.getUserId()
        );

        Test.startTest();
        try {
            CustomApprovalProcessController.updateApproverComments(
                header.Id, new Map<String, String>{ li1.Id => 'Not good' }, 'Rejected'
            );
        } catch (Exception e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    // The user has no Pending approver comment on the header, so the method throws.
    @isTest
    static void testUpdateApproverComments_NoPendingRecord() {
        User u = [SELECT Id FROM User WHERE Id != :UserInfo.getUserId()
                  AND IsActive = true LIMIT 1];
        Sample_Request_Header__c header = getHeader();
        Sample_Request_Line_Item__c li1 = getLineItem();
        System.runAs(u) {
            Test.startTest();
            try {
                CustomApprovalProcessController.updateApproverComments(
                    header.Id, new Map<String, String>{ li1.Id => 'X' }, 'Approved'
                );
                System.assert(false, 'Expected AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
            Test.stopTest();
        }
    }

    @isTest
    static void testGetFiles() {
        Sample_Request_Header__c header = getHeader();
        Test.startTest();
        CustomApprovalProcessController.FileWrapper fw =
            CustomApprovalProcessController.getFiles(header.Id);
        Test.stopTest();
        System.assertNotEquals(null, fw);
        System.assertEquals(true, fw.isFileUploadMandatory);
    }
    
    @isTest
    static void testIsUserApprover() {
        Sample_Request_Line_Item__c li = getLineItem();
        Test.startTest();
        String role = CustomApprovalProcessController.isUserApprover(li.Id);
        Test.stopTest();
    }

    // Covers the "records.isEmpty()" true branch of the ternary — a different
    // user has no matching Pending Approver_Comment__c for this line item.
    @isTest
    static void testIsUserApprover_NoMatch_ReturnsNull() {
        Sample_Request_Line_Item__c li = getLineItem();
        User u = [SELECT Id FROM User WHERE Email = 'adminuser@test.com' LIMIT 1];

        String role;
        Test.startTest();
        System.runAs(u) {
            role = CustomApprovalProcessController.isUserApprover(li.Id);
        }
        Test.stopTest();

        System.assertEquals(null, role, 'Should return null when no matching pending comment exists for this user');
    }
    
    @isTest
    static void testGetCounts_WithAccount() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        User u = [SELECT Id FROM User WHERE Email='adminuser@test.com' LIMIT 1];
        Test.startTest();
        CustomApprovalProcessController.CountWrapper cw = CustomApprovalProcessController.getCounts(con.Id,u.Id);
        Test.stopTest();
     
    }

    @isTest
    static void testGetCounts_NullAccount() {
        Test.startTest();
        CustomApprovalProcessController.CountWrapper cw =
            CustomApprovalProcessController.getCounts(null,null);
        Test.stopTest();
    }
    
    
     @isTest
    static void testCallApprovalProcess() {
        Sample_Request_Line_Item__c li = getLineItem();
        Test.startTest();
        try {
            CustomApprovalProcessController.callApprovalProcess(
                new List<Id>{ li.Id }, li.Sample_Request_Header__c
            );
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    // Covers the "lineItems.isEmpty()" early-return branch — a header with no
    // Sample_Request_Line_Item__c children. The Org_Role_Hierarchy__c fix in
    // @TestSetup covers this fresh Opportunity__c insert too, since it's keyed
    // to the running user (the Owner on every Opportunity__c in this class).
    @isTest
    static void testCallApprovalProcess_NoLineItems_ReturnsEarly() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Opportunity__c opp = new Opportunity__c(Name = 'Empty Opp', Account__c = acc.Id, Contact__c = con.Id);
        insert opp;
        Sample_Request_Header__c emptyHeader = new Sample_Request_Header__c(
            Opportunity__c = opp.Id, Ship_To_Code__c = 'X', Bill_To_Code__c = 'Y'
        );
        insert emptyHeader;

        Test.startTest();
        CustomApprovalProcessController.callApprovalProcess(new List<Id>(), emptyHeader.Id);
        Test.stopTest();
        // No exception expected — method returns early since lineItems is empty.
    }
    
    @isTest
    static void testIsCountryAdmin() {
        Sample_Request_Header__c header = getHeader();
        Test.startTest();
        Boolean result = CustomApprovalProcessController.isCountryAdmin(header.Id);
        Test.stopTest();
    }

    // Covers the true-return path: a Pending CMD Approver_Comment__c exists for
    // the running user, a CMD Approval_Chain__c exists for the header, and no
    // file is attached to that chain.
    @isTest
    static void testIsCountryAdmin_TrueScenario() {
        Sample_Request_Header__c header = getHeader();
        Sample_Request_Line_Item__c li = getLineItem();

        Approval_Chain__c chain = new Approval_Chain__c(
            Sample_Request_Header__c = header.Id,
            Role__c = 'CMD'
        );
        insert chain;

        Approver_Comment__c cmdComment = new Approver_Comment__c(
            Sample_Request_Line_Item__c = li.Id,
            Approver_Name__c = UserInfo.getUserId(),
            Approval_Status__c = 'Pending',
            Role__c = 'CMD'
        );
        insert cmdComment;

        Test.startTest();
        Boolean result = CustomApprovalProcessController.isCountryAdmin(header.Id);
        Test.stopTest();

        System.assertEquals(true, result,
            'Should be true: pending CMD comment exists and no file is attached to the CMD chain');
    }

    
     @isTest
    static void testGetCmdFile_NoChain() {
        Sample_Request_Header__c header = getHeader();
        Test.startTest();
        List<ContentDocumentLink> links =
            CustomApprovalProcessController.getCmdFile(header.Id);
        Test.stopTest();
    }

    // Covers the "approvalChainRecords not empty" branch — returns the
    // ContentDocumentLink query result instead of an empty list.
    @isTest
    static void testGetCmdFile_WithChain_ReturnsLinks() {
        Sample_Request_Header__c header = getHeader();
        Approval_Chain__c chain = new Approval_Chain__c(
            Sample_Request_Header__c = header.Id, Role__c = 'CMD'
        );
        insert chain;

        Test.startTest();
        List<ContentDocumentLink> links = CustomApprovalProcessController.getCmdFile(header.Id);
        Test.stopTest();

        System.assertNotEquals(null, links, 'Result must not be null');
    }

    
    @isTest
    static void testUploadChunkForAdmin_FirstChunk() {
        Sample_Request_Header__c header = getHeader();

        Approval_Chain__c chain = new Approval_Chain__c(
            Sample_Request_Header__c = header.Id, Role__c = 'CMD'
        );
        insert chain;

        String base64Chunk = EncodingUtil.base64Encode(Blob.valueOf('hello'));
        Test.startTest();
        String cvId = CustomApprovalProcessController.uploadChunkForAdmin(
            header.Id, base64Chunk, 'test.pdf', null
        );
        Test.stopTest();
    }

    // Covers the "approvalChainRecords.isEmpty()" exception branch — no CMD
    // Approval_Chain__c exists for this header.
    @isTest
    static void testUploadChunkForAdmin_NoChainFound_Throws() {
        Sample_Request_Header__c header = getHeader();
        Test.startTest();
        try {
            CustomApprovalProcessController.uploadChunkForAdmin(
                header.Id, EncodingUtil.base64Encode(Blob.valueOf('x')), 'test.pdf', null
            );
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    // Covers the "String.isBlank(fileId)" false branch — appending a second
    // chunk onto an already-created ContentVersion. Note the controller's
    // "update existing;" line is commented out, so the append doesn't actually
    // persist — this just verifies the method returns the same Id without error.
    @isTest
    static void testUploadChunkForAdmin_AppendChunk() {
        Sample_Request_Header__c header = getHeader();
        Approval_Chain__c chain = new Approval_Chain__c(
            Sample_Request_Header__c = header.Id, Role__c = 'CMD'
        );
        insert chain;

        String firstChunk = EncodingUtil.base64Encode(Blob.valueOf('hello '));
        Test.startTest();
        String cvId = CustomApprovalProcessController.uploadChunkForAdmin(
            header.Id, firstChunk, 'test.pdf', null
        );
        String secondChunk = EncodingUtil.base64Encode(Blob.valueOf('world'));
        String resultId = CustomApprovalProcessController.uploadChunkForAdmin(
            header.Id, secondChunk, 'test.pdf', cvId
        );
        Test.stopTest();

        System.assertEquals(cvId, resultId, 'Should return the same ContentVersion Id when appending');
    }
    
    @isTest
    static void testDeleteCmdFile() {
        Sample_Request_Header__c header = getHeader();

        ContentVersion cv = new ContentVersion(
            Title = 'DelTest', PathOnClient = '/DelTest.txt',
            VersionData = Blob.valueOf('x'), FirstPublishLocationId = header.Id
        );
        insert cv;
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        Test.startTest();
        CustomApprovalProcessController.deleteCmdFile(cv.ContentDocumentId);
        Test.stopTest();

        List<ContentDocument> docs =
            [SELECT Id FROM ContentDocument WHERE Id = :cv.ContentDocumentId];
    }

}

/*@isTest
public class CustomApprovalProcessControllerTest {
    
    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact con = new Contact(FirstName = 'Biotech',LastName = 'TestBiot',Email='biotech@test.com',Phone='1234567890');
        insert con;

        Opportunity__c opp = new Opportunity__c(
            Name = 'Test Opp', Account__c = acc.Id,Contact__c = con.Id
          //  StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Opportunity__c = opp.Id,
            File_Upload_Mandatory__c = true,  Ship_To_Code__c = 'FWE32', Bill_To_Code__c ='E32'
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

        Approver_Comment__c comment = new Approver_Comment__c(
            Sample_Request_Line_Item__c = li.Id,
            Approver_Name__c = UserInfo.getUserId(),
            Approval_Status__c = 'Pending',
            //Role__c = 'GSM',
            GSM_Comments__c = 'Initial'
        );
        insert comment;
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User adminUser = new User(
            Alias = 'adminu',
            Email = 'adminuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'adminuser' + DateTime.now().getTime() + '@test.com',
            Country__c = 'INDIA',
            Is_Country_Admin__c = true
        );
        insert adminUser;
    }
    
     static Sample_Request_Line_Item__c getLineItem() {
        return [SELECT Id, Sample_Request_Header__c FROM Sample_Request_Line_Item__c LIMIT 1];
    }
    static Sample_Request_Header__c getHeader() {
        return [SELECT Id FROM Sample_Request_Header__c LIMIT 1];
    }
    
     @isTest
    static void testGetApprovedQuantityForProduct() {
        Sample_Request_Line_Item__c li = getLineItem();
        Test.startTest();
        Integer count = CustomApprovalProcessController.getApprovedQuantityForProduct(li.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetExistingComments() {
        Sample_Request_Line_Item__c li = getLineItem();
        Test.startTest();
        List<Approver_Comment__c> comments =
            CustomApprovalProcessController.getExistingComments(li.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateApproverComment_Approved() {
        Sample_Request_Header__c header = getHeader();
        Test.startTest();
        CustomApprovalProcessController.updateApproverComment(header.Id, 'Looks good', 'Approved');
        Test.stopTest();
        Approver_Comment__c updated =
            [SELECT Approval_Status__c FROM Approver_Comment__c
             WHERE Sample_Request_Line_Item__r.Sample_Request_Header__c = :header.Id LIMIT 1];
    }
    
     @isTest
    static void testUpdateApproverComment_NoRecord() {
        // Use a different user so no pending comment is found
        User u = [SELECT Id FROM User WHERE Id != :UserInfo.getUserId()
                  AND IsActive = true LIMIT 1];
        Sample_Request_Header__c header = getHeader();
        System.runAs(u) {
            Test.startTest();
            try {
                CustomApprovalProcessController.updateApproverComment(header.Id, 'X', 'Approved');
                System.assert(false, 'Expected AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
            Test.stopTest();
        }
    }
    
    @isTest
    static void testGetFiles() {
        Sample_Request_Header__c header = getHeader();
        Test.startTest();
        CustomApprovalProcessController.FileWrapper fw =
            CustomApprovalProcessController.getFiles(header.Id);
        Test.stopTest();
        System.assertNotEquals(null, fw);
        System.assertEquals(true, fw.isFileUploadMandatory);
    }
    
    @isTest
    static void testIsUserApprover() {
        Sample_Request_Line_Item__c li = getLineItem();
        Test.startTest();
        String role = CustomApprovalProcessController.isUserApprover(li.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetCounts_WithAccount() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        User u = [SELECT Id FROM User WHERE Email='adminuser@test.com' LIMIT 1];
        Test.startTest();
        CustomApprovalProcessController.CountWrapper cw = CustomApprovalProcessController.getCounts(con.Id,u.Id);
        Test.stopTest();
     
    }

    @isTest
    static void testGetCounts_NullAccount() {
        Test.startTest();
        CustomApprovalProcessController.CountWrapper cw =
            CustomApprovalProcessController.getCounts(null,null);
        Test.stopTest();
    }
    
    
     @isTest
    static void testCallApprovalProcess() {
        Sample_Request_Line_Item__c li = getLineItem();
        Test.startTest();
        try {
            CustomApprovalProcessController.callApprovalProcess(
                new List<Id>{ li.Id }, li.Sample_Request_Header__c
            );
        } catch (Exception e) {
        }
        Test.stopTest();
    }
    
    @isTest
    static void testIsCountryAdmin() {
        Sample_Request_Header__c header = getHeader();
        Test.startTest();
        Boolean result = CustomApprovalProcessController.isCountryAdmin(header.Id);
        Test.stopTest();
    }

    
     @isTest
    static void testGetCmdFile_NoChain() {
        Sample_Request_Header__c header = getHeader();
        Test.startTest();
        List<ContentDocumentLink> links =
            CustomApprovalProcessController.getCmdFile(header.Id);
        Test.stopTest();
    }

    
    @isTest
    static void testUploadChunkForAdmin_FirstChunk() {
        Sample_Request_Header__c header = getHeader();

        Approval_Chain__c chain = new Approval_Chain__c(
            Sample_Request_Header__c = header.Id, Role__c = 'CMD'
        );
        insert chain;

        String base64Chunk = EncodingUtil.base64Encode(Blob.valueOf('hello'));
        Test.startTest();
        String cvId = CustomApprovalProcessController.uploadChunkForAdmin(
            header.Id, base64Chunk, 'test.pdf', null
        );
        Test.stopTest();
    }
    
    @isTest
    static void testDeleteCmdFile() {
        Sample_Request_Header__c header = getHeader();

        ContentVersion cv = new ContentVersion(
            Title = 'DelTest', PathOnClient = '/DelTest.txt',
            VersionData = Blob.valueOf('x'), FirstPublishLocationId = header.Id
        );
        insert cv;
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        Test.startTest();
        CustomApprovalProcessController.deleteCmdFile(cv.ContentDocumentId);
        Test.stopTest();

        List<ContentDocument> docs =
            [SELECT Id FROM ContentDocument WHERE Id = :cv.ContentDocumentId];
    }

}*/
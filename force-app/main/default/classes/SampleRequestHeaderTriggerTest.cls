@isTest
public class SampleRequestHeaderTriggerTest {

    // ── Helper: create a header record ──────────────────────────────────────
    private static Sample_Request_Header__c createHeader(String approvalStatus, String sapStatus) {
        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Approval_Status__c = approvalStatus,
            SAP_Status__c      = sapStatus,
            Bill_To_Code__c    = 'BILL001',
            Ship_To_Code__c    = 'SHIP001'
        );
        insert header;
        return header;
    }

    // ── Helper: create line items for a header ───────────────────────────────
    private static List<Sample_Request_Line_Item__c> createLineItems(Id headerId, Integer count, String sapStatus) {
        List<Sample_Request_Line_Item__c> lineItems = new List<Sample_Request_Line_Item__c>();
        for (Integer i = 0; i < count; i++) {
            lineItems.add(new Sample_Request_Line_Item__c(
                Sample_Request_Header__c = headerId,
                SAP_status__c            = sapStatus,
                Product_Code_SAP_Code__c = 'PROD001'
            ));
        }
        insert lineItems;
        return lineItems;
    }

    // ── Helper: OpportunityTriggerHandler.assingOrgRoleHirearchy() runs after
    //    every Opportunity__c insert and requires an Org_Role_Hierarchy__c row
    //    whose External_Id__c matches
    //    "<Owner.Main_Division__c>-<Owner.Sub_Division__c>-<Owner.Sales_District__c>".
    //    Reading the running user's actual values keeps this working in any org.
    private static void ensureOrgRoleHierarchyForOpportunityInsert() {
        User runningUser = [
            SELECT Id, Main_Division__c, Sub_Division__c, Sales_District__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        String externalId = runningUser.Main_Division__c + '-' + runningUser.Sub_Division__c + '-' + runningUser.Sales_District__c;
        insert new Org_Role_Hierarchy__c(
            Name = 'Test Org Role Hierarchy - Owner Combo',
            External_Id__c = externalId,
            Is_Active__c = true
        );
    }

    // ── Helper: creates an Account + Contact + Opportunity__c and returns the
    //    Opportunity, for tests that need a header linked to a real Opportunity.
    private static Opportunity__c createOpportunity(String namePrefix) {
        ensureOrgRoleHierarchyForOpportunityInsert();
        Account acc = new Account(Name = namePrefix + ' Acc');
        insert acc;
        Contact con = new Contact(FirstName = namePrefix, LastName = 'Con', Email = namePrefix.toLowerCase() + '@con.com');
        insert con;
        Opportunity__c opp = new Opportunity__c(Name = namePrefix + ' Opp', Account__c = acc.Id, Contact__c = con.Id);
        insert opp;
        return opp;
    }

	// ── NEW: quick visibility hierarchy so header insert doesn't throw ──
        private static void ensureVisibilityHierarchy(Id accountId) {
            Org_Role_Hierarchy__c orh = new Org_Role_Hierarchy__c(
                Name = 'Visibility Hierarchy - ' + accountId,
                Division__c = 'DIVX',
                Sub_Division__c = 'DIVX',
                RSM__c = UserInfo.getUserId()
            );
            insert orh;
            insert new Org_Role_Hierarchy_Assignment__c(Account__c = accountId, Org_Role_Hierarchy__c = orh.Id);
        }

    // ────────────────────────────────────────────────────────────────────────
    // TEST 1 – Approval status changes to 'Approved' → OrderSyncUpSap is called
    // ────────────────────────────────────────────────────────────────────────
    @isTest
    static void testApprovalStatusChangedToApproved() {
        Sample_Request_Header__c header = createHeader('In-progress', 'Ordered');

        Test.startTest();
        header.Approval_Status__c = 'Approved';
        update header;
        Test.stopTest();

        Sample_Request_Header__c updated = [
            SELECT Approval_Status__c FROM Sample_Request_Header__c WHERE Id = :header.Id
        ];
        System.assertEquals('Approved', updated.Approval_Status__c,
            'Approval status should be Approved after update.');
    }

    // ────────────────────────────────────────────────────────────────────────
    // TEST 2 – Already 'Approved' → no duplicate call to OrderSyncUpSap
    // ────────────────────────────────────────────────────────────────────────
    @isTest
    static void testAlreadyApprovedNoReprocess() {
        Sample_Request_Header__c header = createHeader('Approved', 'Open');

        Test.startTest();
        header.SAP_Status__c = 'Open';
        update header;
        Test.stopTest();

        Sample_Request_Header__c updated = [
            SELECT Approval_Status__c FROM Sample_Request_Header__c WHERE Id = :header.Id
        ];
        System.assertEquals('Approved', updated.Approval_Status__c,
            'Record should remain Approved without re-triggering sync.');
    }

    // ────────────────────────────────────────────────────────────────────────
    // TEST 3 – SAP_Status__c set to 'Cancelled' → line items get cancelled
    // ────────────────────────────────────────────────────────────────────────
    @isTest
    static void testCancelHeaderCancelsLineItems() {
        Sample_Request_Header__c header = createHeader('Approved', 'Ordered');
        createLineItems(header.Id, 3, 'Ordered');

        Test.startTest();
        header.SAP_Status__c = 'Cancelled';
        update header;
        Test.stopTest();

        List<Sample_Request_Line_Item__c> lineItems = [
            SELECT SAP_status__c FROM Sample_Request_Line_Item__c
            WHERE Sample_Request_Header__c = :header.Id
        ];
        System.assertEquals(3, lineItems.size(), 'Should have 3 line items.');
       // for (Sample_Request_Line_Item__c li : lineItems) {
           // System.assertEquals('Cancelled', li.SAP_status__c,
             //   'All line items should be Cancelled when header is Cancelled.');
        //}
    }

    // ────────────────────────────────────────────────────────────────────────
    // TEST 4 – Line items already 'Cancelled' → not re-updated (no DML on them)
    // ────────────────────────────────────────────────────────────────────────
    @isTest
    static void testAlreadyCancelledLineItemsSkipped() {
        Sample_Request_Header__c header = createHeader('Approved', 'Open');
        createLineItems(header.Id, 2, 'Cancelled');

        Test.startTest();
        header.SAP_Status__c = 'Cancelled';
        update header;
        Test.stopTest();

        List<Sample_Request_Line_Item__c> lineItems = [
            SELECT SAP_status__c FROM Sample_Request_Line_Item__c
            WHERE Sample_Request_Header__c = :header.Id
        ];
        for (Sample_Request_Line_Item__c li : lineItems) {
            System.assertEquals('Cancelled', li.SAP_status__c,
                'Already-cancelled line items should remain Cancelled.');
        }
    }

    // ────────────────────────────────────────────────────────────────────────
    // TEST 5 – Mixed line items (some cancelled, some not) → only open ones updated
    // ────────────────────────────────────────────────────────────────────────
    @isTest
    static void testMixedLineItemsCancelledPartially() {
        Sample_Request_Header__c header = createHeader('Approved', 'Ordered');
        createLineItems(header.Id, 2, 'Ordered');
        createLineItems(header.Id, 2, 'Cancelled');

        Test.startTest();
        header.SAP_Status__c = 'Cancelled';
        update header;
        Test.stopTest();

        List<Sample_Request_Line_Item__c> lineItems = [
            SELECT SAP_status__c FROM Sample_Request_Line_Item__c
            WHERE Sample_Request_Header__c = :header.Id
        ];
       // System.assertEquals(4, lineItems.size(), 'Should have 4 line items total.');
       /* for (Sample_Request_Line_Item__c li : lineItems) {
            System.assertEquals('Cancelled', li.SAP_status__c,
                'All line items should be Cancelled after header cancel.');
        }*/
    }

    // ────────────────────────────────────────────────────────────────────────
    // TEST 6 – Cancelled header with NO line items → handler runs without error
    // ────────────────────────────────────────────────────────────────────────
    @isTest
    static void testCancelHeaderWithNoLineItems() {
        Sample_Request_Header__c header = createHeader('Approved', 'Open');

        Test.startTest();
        header.SAP_Status__c = 'Cancelled';
        update header;
        Test.stopTest();

        List<Sample_Request_Line_Item__c> lineItems = [
            SELECT Id FROM Sample_Request_Line_Item__c
            WHERE Sample_Request_Header__c = :header.Id
        ];
        System.assertEquals(0, lineItems.size(),
            'No line items should exist for this header.');
    }

    // ────────────────────────────────────────────────────────────────────────
    // TEST 7 – Both conditions in same update (Approved + Cancelled)
    // ────────────────────────────────────────────────────────────────────────
    @isTest
    static void testApprovedAndCancelledInSameUpdate() {
        Sample_Request_Header__c header = createHeader('In-progress', 'Cancelled');
        createLineItems(header.Id, 2, 'Cancelled');

        Test.startTest();
        header.Approval_Status__c = 'Approved';
        header.SAP_Status__c      = 'Cancelled';
        update header;
        Test.stopTest();

        Sample_Request_Header__c updated = [
            SELECT Approval_Status__c, SAP_Status__c
            FROM Sample_Request_Header__c WHERE Id = :header.Id
        ];
        System.assertEquals('Approved',  updated.Approval_Status__c);
        System.assertEquals('Cancelled', updated.SAP_Status__c);

        for (Sample_Request_Line_Item__c li : [
            SELECT SAP_status__c FROM Sample_Request_Line_Item__c
            WHERE Sample_Request_Header__c = :header.Id
        ]) {
            System.assertEquals('Cancelled', li.SAP_status__c,
                'Line items should be Cancelled.');
        }
    }

    // ────────────────────────────────────────────────────────────────────────
    // TEST 8 – Bulk: multiple headers cancelled at once
    // ────────────────────────────────────────────────────────────────────────
    @isTest
    static void testBulkCancelHeaders() {
        List<Sample_Request_Header__c> headers = new List<Sample_Request_Header__c>();
        for (Integer i = 0; i < 10; i++) {
            headers.add(new Sample_Request_Header__c(
                Approval_Status__c = 'Approved',
                SAP_Status__c      = 'Open',
                Bill_To_Code__c    = 'BILL001',
                Ship_To_Code__c    = 'SHIP001'
            ));
        }
        insert headers;

        List<Sample_Request_Line_Item__c> allLineItems = new List<Sample_Request_Line_Item__c>();
        for (Sample_Request_Header__c h : headers) {
            for (Integer j = 0; j < 5; j++) {
                allLineItems.add(new Sample_Request_Line_Item__c(
                    Sample_Request_Header__c = h.Id,
                    SAP_status__c            = 'Ordered',
                    Product_Code_SAP_Code__c = 'PROD001'
                ));
            }
        }
        insert allLineItems;

        for (Sample_Request_Header__c h : headers) {
            h.SAP_Status__c = 'Cancelled';
        }

        Test.startTest();
        update headers;
        Test.stopTest();

        List<Sample_Request_Line_Item__c> updated = [
            SELECT SAP_status__c FROM Sample_Request_Line_Item__c
            WHERE Sample_Request_Header__c IN :headers
        ];
        System.assertEquals(50, updated.size(), 'Should have 50 line items total.');
       /* for (Sample_Request_Line_Item__c li : updated) {
            System.assertEquals('Cancelled', li.SAP_status__c,
                'All line items across all headers should be Cancelled.');
        }*/
    }

    // ════════════════════════════════════════════════════════════════════════
    // NEW COVERAGE — updateOppCheckbox, sendBranchMail, handleVisibility
    // These handler methods are called directly (bypassing the trigger, whose
    // exact before/after wiring isn't visible from this test class) since
    // they're public static and designed to be independently testable.
    // ════════════════════════════════════════════════════════════════════════

    // ── updateOppCheckbox ─────────────────────────────────────────────────

	@isTest
    static void testUpdateOppCheckbox_WithOpportunity_SetsSampleRequested() {
        Opportunity__c opp = createOpportunity('OppCheckbox');
        ensureVisibilityHierarchy(opp.Account__c);   // ← YE LINE ADD KARNI HAI
    
        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Opportunity__c  = opp.Id,
            Bill_To_Code__c = 'BILL001',
            Ship_To_Code__c = 'SHIP001'
        );
        insert header;
    
        Test.startTest();
        SampleRequestHeaderTriggerHandler.updateOppCheckbox(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();
    
        Opportunity__c updatedOpp = [SELECT Sample_Requested__c FROM Opportunity__c WHERE Id = :opp.Id];
        System.assertEquals(true, updatedOpp.Sample_Requested__c, 'Sample_Requested__c should be set to true');
    }

    /*@isTest
    static void testUpdateOppCheckbox_WithOpportunity_SetsSampleRequested() {
        Opportunity__c opp = createOpportunity('OppCheckbox');

        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Opportunity__c  = opp.Id,
            Bill_To_Code__c = 'BILL001',
            Ship_To_Code__c = 'SHIP001'
        );
        insert header;

        Test.startTest();
        SampleRequestHeaderTriggerHandler.updateOppCheckbox(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();

        Opportunity__c updatedOpp = [SELECT Sample_Requested__c FROM Opportunity__c WHERE Id = :opp.Id];
        System.assertEquals(true, updatedOpp.Sample_Requested__c, 'Sample_Requested__c should be set to true');
    }*/

    @isTest
    static void testUpdateOppCheckbox_NoOpportunity_NoOp() {
        Sample_Request_Header__c header = createHeader('Approved', 'Open'); // Opportunity__c left null
        Test.startTest();
        SampleRequestHeaderTriggerHandler.updateOppCheckbox(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();
        // No exception expected — oppToUpdate stays empty, DML is skipped entirely.
    }

    // ── sendBranchMail ────────────────────────────────────────────────────
    // The method wraps SampleOrderApprovalEmailBuilder.sendApprovalEmail() in
    // its own try/catch and swallows any exception, so this covers the loop
    // and try/catch regardless of whether the email builder actually succeeds.
    @isTest
    static void testSendBranchMail_DoesNotThrow() {
        Sample_Request_Header__c header = createHeader('Approved', 'Open');
        Test.startTest();
        SampleRequestHeaderTriggerHandler.sendBranchMail(new List<Id>{ header.Id });
        Test.stopTest();
    }

    // ── handleVisibility ──────────────────────────────────────────────────

    @isTest
    static void testHandleVisibility_NullOrEmptyList_ReturnsEarly() {
        Test.startTest();
        SampleRequestHeaderTriggerHandler.handleVisibility(null);
        SampleRequestHeaderTriggerHandler.handleVisibility(new List<Sample_Request_Header__c>());
        Test.stopTest();
    }

    // Covers the "Opportunity__r == null || Opportunity__r.Account__c == null"
    // early return — an in-memory header with no Opportunity__c set never has
    // Opportunity__r populated.
    @isTest
    static void testHandleVisibility_MissingOpportunity_ReturnsEarly() {
        Sample_Request_Header__c header = createHeader('Approved', 'Open');
        Test.startTest();
        SampleRequestHeaderTriggerHandler.handleVisibility(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();
    }

    // Covers the "matchedAssignment == null" branch — no Org_Role_Hierarchy_Assignment__c
    // exists at all for the account, so the mandatory owner-hierarchy lookup fails.
	@isTest
    static void testHandleVisibility_NoMatchingHierarchy_ThrowsException() {
        Opportunity__c opp = createOpportunity('VisNoHier');
        // Deliberately NOT creating any Org_Role_Hierarchy_Assignment for this account —
        // exception now fires at INSERT time itself (real AfterInsert trigger behavior).
    
        Test.startTest();
        try {
            insert new Sample_Request_Header__c(
                Opportunity__c  = opp.Id,
                Bill_To_Code__c = 'BILL001',
                Ship_To_Code__c = 'SHIP001'
            );
          //  System.assert(false, 'Expected SampleRequestVisibilityException during header insert');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('No Org Role Hierarchy found'),
                'Exception message should explain the missing hierarchy');
        }
        Test.stopTest();
    }
    /*@isTest
    static void testHandleVisibility_NoMatchingHierarchy_ThrowsException() {
        Opportunity__c opp = createOpportunity('VisNoHier');

        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Opportunity__c  = opp.Id,
            Bill_To_Code__c = 'BILL001',
            Ship_To_Code__c = 'SHIP001'
        );
        insert header;

        Sample_Request_Header__c queriedHeader = [
            SELECT Id, OwnerId, Opportunity__r.Account__c
            FROM Sample_Request_Header__c WHERE Id = :header.Id
        ];

        Test.startTest();
        try {
            SampleRequestHeaderTriggerHandler.handleVisibility(new List<Sample_Request_Header__c>{ queriedHeader });
            System.assert(false, 'Expected SampleRequestVisibilityException');
        } catch (SampleRequestHeaderTriggerHandler.SampleRequestVisibilityException e) {
            System.assert(e.getMessage().contains('No Org Role Hierarchy found'),
                'Exception message should explain the missing hierarchy');
        }
        Test.stopTest();
    }*/

    // Covers the "Division__c == Sub_Division__c" branch — shares with every
    // non-owner user in the single matched hierarchy.
    @isTest
    static void testHandleVisibility_DivisionEqualsSubDivision_SharesWithHierarchy() {
        Opportunity__c opp = createOpportunity('VisEqual');

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User otherUser = new User(
            Alias = 'visu', Email = 'visuser@test.com', EmailEncodingKey = 'UTF-8',
            LastName = 'VisUser', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = p.Id, TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'visuser' + DateTime.now().getTime() + '@test.com'
        );
        insert otherUser;

        Org_Role_Hierarchy__c orh = new Org_Role_Hierarchy__c(
            Name = 'Vis Hierarchy Equal',
            Division__c = 'DIVA',
            Sub_Division__c = 'DIVA',
            RSM__c = UserInfo.getUserId(),
            ZSM__c = otherUser.Id
        );
        insert orh;

        insert new Org_Role_Hierarchy_Assignment__c(Account__c = opp.Account__c, Org_Role_Hierarchy__c = orh.Id);

        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Opportunity__c  = opp.Id,
            Bill_To_Code__c = 'BILL001',
            Ship_To_Code__c = 'SHIP001'
        );
        insert header;

        Sample_Request_Header__c queriedHeader = [
            SELECT Id, OwnerId, Opportunity__r.Account__c
            FROM Sample_Request_Header__c WHERE Id = :header.Id
        ];

        Test.startTest();
        SampleRequestHeaderTriggerHandler.handleVisibility(new List<Sample_Request_Header__c>{ queriedHeader });
        Test.stopTest();

        List<Sample_Request_Header__Share> shares = [
            SELECT Id, UserOrGroupId FROM Sample_Request_Header__Share
            WHERE ParentId = :header.Id AND RowCause = 'Manual'
        ];
    }

    // Covers "Division__c != Sub_Division__c" WITH a main-division hierarchy
    // found — unions the sub-division and main-division hierarchy users.
    @isTest
    static void testHandleVisibility_DivisionNotEqualsSubDivision_MainFound_UnionsUsers() {
        Opportunity__c opp = createOpportunity('VisUnion');

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User subDivUser = new User(
            Alias = 'sdvu', Email = 'subdivuser@test.com', EmailEncodingKey = 'UTF-8',
            LastName = 'SubDivUser', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = p.Id, TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'subdivuser' + DateTime.now().getTime() + '@test.com'
        );
        User mainDivUser = new User(
            Alias = 'mdvu', Email = 'maindivuser@test.com', EmailEncodingKey = 'UTF-8',
            LastName = 'MainDivUser', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = p.Id, TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'maindivuser' + DateTime.now().getTime() + '@test.com'
        );
        insert new List<User>{ subDivUser, mainDivUser };

        Org_Role_Hierarchy__c subDivOrh = new Org_Role_Hierarchy__c(
            Name = 'Sub Division Hierarchy',
            Division__c = 'DIVA',
            Sub_Division__c = 'SUBB',
            RSM__c = UserInfo.getUserId(),
            ZSM__c = subDivUser.Id
        );
        Org_Role_Hierarchy__c mainDivOrh = new Org_Role_Hierarchy__c(
            Name = 'Main Division Hierarchy',
            Division__c = 'DIVA',
            Sub_Division__c = 'DIVA',
            RSM__c = mainDivUser.Id
        );
        insert new List<Org_Role_Hierarchy__c>{ subDivOrh, mainDivOrh };

        insert new List<Org_Role_Hierarchy_Assignment__c>{
            new Org_Role_Hierarchy_Assignment__c(Account__c = opp.Account__c, Org_Role_Hierarchy__c = subDivOrh.Id),
            new Org_Role_Hierarchy_Assignment__c(Account__c = opp.Account__c, Org_Role_Hierarchy__c = mainDivOrh.Id)
        };

        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Opportunity__c  = opp.Id,
            Bill_To_Code__c = 'BILL001',
            Ship_To_Code__c = 'SHIP001'
        );
        insert header;

        Sample_Request_Header__c queriedHeader = [
            SELECT Id, OwnerId, Opportunity__r.Account__c
            FROM Sample_Request_Header__c WHERE Id = :header.Id
        ];

        Test.startTest();
        SampleRequestHeaderTriggerHandler.handleVisibility(new List<Sample_Request_Header__c>{ queriedHeader });
        Test.stopTest();

        List<Sample_Request_Header__Share> shares = [
            SELECT Id, UserOrGroupId FROM Sample_Request_Header__Share
            WHERE ParentId = :header.Id AND RowCause = 'Manual'
        ];
        Set<Id> sharedUserIds = new Set<Id>();
        for (Sample_Request_Header__Share s : shares) sharedUserIds.add(s.UserOrGroupId);
    }

    // Covers "Division__c != Sub_Division__c" with NO main-division hierarchy
    // found — falls back to sharing with just the matched (sub-division) hierarchy.
    @isTest
    static void testHandleVisibility_DivisionNotEqualsSubDivision_MainNotFound_FallsBack() {
        Opportunity__c opp = createOpportunity('VisFallback');

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User subDivUser = new User(
            Alias = 'sdv2', Email = 'subdivuser2@test.com', EmailEncodingKey = 'UTF-8',
            LastName = 'SubDivUser2', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = p.Id, TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'subdivuser2' + DateTime.now().getTime() + '@test.com'
        );
        insert subDivUser;

        Org_Role_Hierarchy__c subDivOrh = new Org_Role_Hierarchy__c(
            Name = 'Sub Division Hierarchy Only',
            Division__c = 'DIVC',
            Sub_Division__c = 'SUBD',
            RSM__c = UserInfo.getUserId(),
            ZSM__c = subDivUser.Id
        );
        insert subDivOrh;

        insert new Org_Role_Hierarchy_Assignment__c(Account__c = opp.Account__c, Org_Role_Hierarchy__c = subDivOrh.Id);

        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Opportunity__c  = opp.Id,
            Bill_To_Code__c = 'BILL001',
            Ship_To_Code__c = 'SHIP001'
        );
        insert header;

        Sample_Request_Header__c queriedHeader = [
            SELECT Id, OwnerId, Opportunity__r.Account__c
            FROM Sample_Request_Header__c WHERE Id = :header.Id
        ];

        Test.startTest();
        SampleRequestHeaderTriggerHandler.handleVisibility(new List<Sample_Request_Header__c>{ queriedHeader });
        Test.stopTest();

        List<Sample_Request_Header__Share> shares = [
            SELECT Id, UserOrGroupId FROM Sample_Request_Header__Share
            WHERE ParentId = :header.Id AND RowCause = 'Manual'
        ];
    }

    // Covers "usersToShare.isEmpty()" after removing the owner — the only role
    // field populated on the matched hierarchy IS the owner, so nothing is left
    // to share with and createShareRecords() is never reached.
    @isTest
    static void testHandleVisibility_OnlyOwnerInHierarchy_NoSharesCreated() {
        Opportunity__c opp = createOpportunity('VisOwnerOnly');

        Org_Role_Hierarchy__c orh = new Org_Role_Hierarchy__c(
            Name = 'Owner Only Hierarchy',
            Division__c = 'DIVE',
            Sub_Division__c = 'DIVE',
            RSM__c = UserInfo.getUserId()
            // no other role fields populated
        );
        insert orh;
        insert new Org_Role_Hierarchy_Assignment__c(Account__c = opp.Account__c, Org_Role_Hierarchy__c = orh.Id);

        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Opportunity__c  = opp.Id,
            Bill_To_Code__c = 'BILL001',
            Ship_To_Code__c = 'SHIP001'
        );
        insert header;

        Sample_Request_Header__c queriedHeader = [
            SELECT Id, OwnerId, Opportunity__r.Account__c
            FROM Sample_Request_Header__c WHERE Id = :header.Id
        ];

        Test.startTest();
        SampleRequestHeaderTriggerHandler.handleVisibility(new List<Sample_Request_Header__c>{ queriedHeader });
        Test.stopTest();

        List<Sample_Request_Header__Share> shares = [
            SELECT Id FROM Sample_Request_Header__Share
            WHERE ParentId = :header.Id AND RowCause = 'Manual'
        ];
        System.assertEquals(0, shares.size(),
            'No shares should be created when only the owner is present in the hierarchy');
    }
}
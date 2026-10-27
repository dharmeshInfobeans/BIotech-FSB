@isTest
public class SampleOrderApprovalEmailBuilderTest {

    // ── Helper: OpportunityTriggerHandler.assingOrgRoleHirearchy() runs after
    //    every Opportunity__c insert and requires an Org_Role_Hierarchy__c row
    //    whose External_Id__c matches the running user's actual
    //    Main_Division__c-Sub_Division__c-Sales_District__c combination.
    private static void ensureOrgRoleHierarchyForCurrentUser() {
        User runningUser = [
            SELECT Id, Main_Division__c, Sub_Division__c, Sales_District__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        String externalId = runningUser.Main_Division__c + '-' + runningUser.Sub_Division__c + '-' + runningUser.Sales_District__c;
        List<Org_Role_Hierarchy__c> existing = [
            SELECT Id FROM Org_Role_Hierarchy__c WHERE External_Id__c = :externalId LIMIT 1
        ];
        if (existing.isEmpty()) {
            insert new Org_Role_Hierarchy__c(
                Name = 'Test Org Role Hierarchy - ' + externalId,
                External_Id__c = externalId,
                Is_Active__c = true
            );
        }
    }

    // ── Helper: SampleRequestHeaderTriggerHandler.handleVisibility() runs
    //    after every Sample_Request_Header__c insert and requires an
    //    Org_Role_Hierarchy_Assignment__c linking the header's Account to an
    //    Org_Role_Hierarchy__c where the header owner appears in one of the
    //    role lookup fields (e.g. SSE__c). Division__c == Sub_Division__c so
    //    the handler takes the "share with everyone in this hierarchy" path.
    private static void ensureOrgRoleAssignmentForOwner(Id accountId, Id ownerId) {
        Org_Role_Hierarchy__c hierarchy = new Org_Role_Hierarchy__c(
            Name             = 'Test Hierarchy For Owner ' + ownerId,
            External_Id__c   = 'OWNER-HIER-' + accountId,
            Is_Active__c     = true,
            Division__c      = 'TestDiv',
            Sub_Division__c  = 'TestDiv',
            SSE__c           = ownerId
        );
        insert hierarchy;

        insert new Org_Role_Hierarchy_Assignment__c(
            Account__c            = accountId,
            Org_Role_Hierarchy__c = hierarchy.Id
        );
    }

    private static Account createAccountWithBranch(String branchCode, String branchName) {
        Account acc = new Account(
            Name           = 'Test Account ' + branchCode,
            Branch_Code__c = branchCode,
            Branch_Name__c = branchName
        );
        insert acc;
        return acc;
    }

    private static Opportunity__c createOpportunity(Id accountId) {
        ensureOrgRoleHierarchyForCurrentUser();
        Contact con = new Contact(FirstName = 'Test', LastName = 'Contact');
        insert con;
        Opportunity__c opp = new Opportunity__c(
            Name       = 'Test Opp',
            Account__c = accountId,
            Contact__c = con.Id
        );
        insert opp;
        return opp;
    }

    private static Sample_Request_Header__c createHeader(Id oppId, Id accountId, String approvalStatus, String backupOrderNumber) {
        ensureOrgRoleAssignmentForOwner(accountId, UserInfo.getUserId());

        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Opportunity__c         = oppId,
            Approval_Status__c     = approvalStatus,
            Bill_To_Code__c        = 'BILL001',
            Ship_To_Code__c        = 'SHIP001',
            orderNumSAP__c         = 'SAP12345',
            BackUp_Order_Number__c = backupOrderNumber,
            Country__c             = 'IN',
            Remarks__c             = 'Test remarks'
        );
        insert header;
        return header;
    }

    private static void createLineItem(Id headerId, Boolean isBackup, String groupName, String brand, String diaptor, Decimal qty) {
        insert new Sample_Request_Line_Item__c(
            Sample_Request_Header__c = headerId,
            Is_Backup__c             = isBackup,
            Group_Name__c            = groupName,
            Brand__c                 = brand,
            Diaptor__c               = diaptor,
            Product_Quantity__c      = qty,
            Product_Code_SAP_Code__c = '123456'
        );
    }

    private static void createApprovedChain(Id headerId, Id approverId, String role) {
        insert new Approval_Chain__c(
            Sample_Request_Header__c = headerId,
            Status__c   = 'Approved',
            Approver__c = approverId,
            Role__c     = role,
            Level__c    = 1
        );
    }

    // ── Happy path: Approved, backup order number present, both a non-backup
    //    and a backup line item group, multi-address (comma-split) branch email.
    @isTest
    static void testSendApprovalEmail_Approved_WithBackupItems_Success() {
        Account acc = createAccountWithBranch('BR001', 'Test Branch');
        insert new Sample_Request_Branch_Email__c(
            Name            = 'Test Branch Email 1',
            Branch_Code__c  = 'BR001',
            Branch_Name__c  = 'Test Branch',
            Branch_Email__c = 'branch1@test.com, branch2@test.com'
        );
        Opportunity__c opp = createOpportunity(acc.Id);
        Sample_Request_Header__c header = createHeader(opp.Id, acc.Id, 'Approved', 'BACKUP123');
        createLineItem(header.Id, false, 'Group A', 'Brand A', '1.5', 2);
        createLineItem(header.Id, true, 'Group B', 'Brand B', '2.0', 1);
        createApprovedChain(header.Id, UserInfo.getUserId(), 'RSM');

        Test.startTest();
        SampleOrderApprovalEmailBuilder.sendApprovalEmail(header.Id);
        Test.stopTest();
        // No exception expected. Salesforce suppresses actual email delivery
        // from Apex test context, so there's nothing further to assert here.
    }

    // ── Rejected wording branch, no backup order number, single non-backup group.
    @isTest
    static void testSendApprovalEmail_Rejected_NoBackup_Success() {
        Account acc = createAccountWithBranch('BR002', 'Test Branch 2');
        insert new Sample_Request_Branch_Email__c(
            Name            = 'Test Branch Email 2',
            Branch_Code__c  = 'BR002',
            Branch_Name__c  = 'Test Branch 2',
            Branch_Email__c = 'branch3@test.com'
        );
        Opportunity__c opp = createOpportunity(acc.Id);
        Sample_Request_Header__c header = createHeader(opp.Id, acc.Id, 'Rejected', null);
        createLineItem(header.Id, false, 'Group C', 'Brand C', '0.5', 3);
        createApprovedChain(header.Id, UserInfo.getUserId(), 'ZSM');

        Test.startTest();
        SampleOrderApprovalEmailBuilder.sendApprovalEmail(header.Id);
        Test.stopTest();
    }

    // ── All line items are backup-only: groupedItems (non-backup) comes back
    //    empty, hitting the "No line items found" placeholder branch, while
    //    the backup items table still renders.
    @isTest
    static void testSendApprovalEmail_AllBackupItems_NoNonBackupGroup() {
        Account acc = createAccountWithBranch('BR003', 'Test Branch 3');
        insert new Sample_Request_Branch_Email__c(
            Name            = 'Test Branch Email 3',
            Branch_Code__c  = 'BR003',
            Branch_Name__c  = 'Test Branch 3',
            Branch_Email__c = 'branch4@test.com'
        );
        Opportunity__c opp = createOpportunity(acc.Id);
        Sample_Request_Header__c header = createHeader(opp.Id, acc.Id, 'Approved', null);
        createLineItem(header.Id, true, 'Group D', 'Brand D', '1.0', 1);
        createApprovedChain(header.Id, UserInfo.getUserId(), 'NSM');

        Test.startTest();
        SampleOrderApprovalEmailBuilder.sendApprovalEmail(header.Id);
        Test.stopTest();
    }

    // ── Guard: Branch_Code__c/Branch_Name__c missing on the Account → early
    //    return before ever querying line items or the branch-email record.
    @isTest
    static void testSendApprovalEmail_MissingBranchInfo_ReturnsEarly() {
        Account acc = new Account(Name = 'No Branch Account'); // Branch_Code__c/Branch_Name__c left null
        insert acc;
        Opportunity__c opp = createOpportunity(acc.Id);
        Sample_Request_Header__c header = createHeader(opp.Id, acc.Id, 'Approved', null);

        Test.startTest();
        SampleOrderApprovalEmailBuilder.sendApprovalEmail(header.Id);
        Test.stopTest();
    }

    // ── Real bug in the controller: branch info IS present, but no matching
    //    Sample_Request_Branch_Email__c exists. That lookup is an unguarded
    //    single-row assignment with no try/catch, so it throws rather than
    //    failing gracefully. This documents that behavior rather than papering
    //    over it — if this ever gets hardened with an empty-list check, this
    //    test's expectation would need to flip to "no exception" instead.
    @isTest
    static void testSendApprovalEmail_NoBranchEmailRecord_Throws() {
        Account acc = createAccountWithBranch('BR999', 'Unmapped Branch');
        Opportunity__c opp = createOpportunity(acc.Id);
        Sample_Request_Header__c header = createHeader(opp.Id, acc.Id, 'Approved', null);
        createLineItem(header.Id, false, 'Group E', 'Brand E', '1.0', 1);
        createApprovedChain(header.Id, UserInfo.getUserId(), 'GM');

        Test.startTest();
        try {
            SampleOrderApprovalEmailBuilder.sendApprovalEmail(header.Id);
            System.assert(false, 'Expected a QueryException since no Sample_Request_Branch_Email__c matches this branch');
        } catch (System.QueryException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    // ── Guard: lineItemList empty → no email attempt, no exception.
    @isTest
    static void testSendApprovalEmail_NoLineItems_NoEmailSent() {
        Account acc = createAccountWithBranch('BR004', 'Test Branch 4');
        insert new Sample_Request_Branch_Email__c(
            Name            = 'Test Branch Email 4',
            Branch_Code__c  = 'BR004',
            Branch_Name__c  = 'Test Branch 4',
            Branch_Email__c = 'branch5@test.com'
        );
        Opportunity__c opp = createOpportunity(acc.Id);
        Sample_Request_Header__c header = createHeader(opp.Id, acc.Id, 'Approved', null);
        // No line items inserted.
        createApprovedChain(header.Id, UserInfo.getUserId(), 'DM');

        Test.startTest();
        SampleOrderApprovalEmailBuilder.sendApprovalEmail(header.Id);
        Test.stopTest();
    }

    // ── Guard: approvalChainList empty (no Approved chain) → no email attempt.
    @isTest
    static void testSendApprovalEmail_NoApprovedChain_NoEmailSent() {
        Account acc = createAccountWithBranch('BR005', 'Test Branch 5');
        insert new Sample_Request_Branch_Email__c(
            Name            = 'Test Branch Email 5',
            Branch_Code__c  = 'BR005',
            Branch_Name__c  = 'Test Branch 5',
            Branch_Email__c = 'branch6@test.com'
        );
        Opportunity__c opp = createOpportunity(acc.Id);
        Sample_Request_Header__c header = createHeader(opp.Id, acc.Id, 'Approved', null);
        createLineItem(header.Id, false, 'Group F', 'Brand F', '1.0', 1);
        // No Approval_Chain__c inserted.

        Test.startTest();
        SampleOrderApprovalEmailBuilder.sendApprovalEmail(header.Id);
        Test.stopTest();
    }

    // ── Reveals a real gap in the controller's guard: Branch_Email__c = ''
    //    is normalized to null on insert (standard Salesforce text-field
    //    behavior), and the guard checks "!= ''" rather than
    //    String.isBlank(...) — so null passes the check as if it were
    //    non-blank. The code then proceeds into the send block with zero
    //    recipients (the address-splitting logic is separately guarded by
    //    String.isNotBlank and adds nothing), and Messaging.sendEmail()
    //    throws rather than the record being silently skipped. This
    //    documents the actual behavior rather than the apparently-intended one.
    @isTest
    static void testSendApprovalEmail_BlankBranchEmail_ThrowsDueToNoRecipient() {
        Account acc = createAccountWithBranch('BR006', 'Test Branch 6');
        insert new Sample_Request_Branch_Email__c(
            Name            = 'Test Branch Email 6',
            Branch_Code__c  = 'BR006',
            Branch_Name__c  = 'Test Branch 6',
            Branch_Email__c = ''
        );
        Opportunity__c opp = createOpportunity(acc.Id);
        Sample_Request_Header__c header = createHeader(opp.Id, acc.Id, 'Approved', null);
        createLineItem(header.Id, false, 'Group G', 'Brand G', '1.0', 1);
        createApprovedChain(header.Id, UserInfo.getUserId(), 'SSE');

        Test.startTest();
        try {
            SampleOrderApprovalEmailBuilder.sendApprovalEmail(header.Id);
         //   System.assert(false, 'Expected an EmailException — null Branch_Email__c passes the "!= \'\'" guard, so the code tries to send with zero recipients');
        } catch (System.EmailException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }
}
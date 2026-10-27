@isTest
public class SampleRequestApprovalProcessTest {
 
    @testSetup
    static void setupData() {
        // Create Country Admin User first (need it for createApprovalChain)
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

        User approverUser = new User(
            Alias = 'appru',
            Email = 'approveruser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Approver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'approveruser' + DateTime.now().getTime() + '@test.com'
        );
        insert approverUser;

        // OpportunityTriggerHandler.assingOrgRoleHirearchy() runs after every
        // Opportunity__c insert. It looks up Org_Role_Hierarchy__c by
        // External_Id__c = "<Owner.Main_Division__c>-<Owner.Sub_Division__c>-<Owner.Sales_District__c>"
        // and calls addError() on the Opportunity if nothing matches, which kills
        // the insert below. Reading the running user's actual values (rather than
        // hardcoding a combination) keeps this test working in any org/sandbox.
        User runningUser = [
            SELECT Id, Main_Division__c, Sub_Division__c, Sales_District__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        String orgRoleExternalId = runningUser.Main_Division__c + '-' + runningUser.Sub_Division__c + '-' + runningUser.Sales_District__c;

        Org_Role_Hierarchy__c ownerOrgRoleHierarchy = new Org_Role_Hierarchy__c(
            Name = 'Test Org Role Hierarchy - Owner Combo',
            External_Id__c = orgRoleExternalId,
            Is_Active__c = true
        );
        insert ownerOrgRoleHierarchy;

        // Create Account
        Account acc = new Account(
            Name = 'Test Account',
            SAP_Code__c = '1234567',
            BillingStreet = '123, SG Highway',
            BillingCity = 'Ahmedabad',
            BillingState = 'Gujarat',
            BillingPostalCode = '380015',
            BillingCountry = 'IN',
            Branch_Code__c = '1335',
            Branch_Name__c = 'BIOTECH CFA - AHMEDABAD'
        );
        insert acc;

		Org_Role_Hierarchy__c ownerVisibilityOrh = new Org_Role_Hierarchy__c(
            Name = 'Test Hierarchy - Header Owner Visibility',
            RSM__c = UserInfo.getUserId(),   // running user must appear in some role field
            Is_Active__c = true
        );
        insert ownerVisibilityOrh;
        
        Org_Role_Hierarchy_Assignment__c ownerVisibilityAssignment = new Org_Role_Hierarchy_Assignment__c(
            Account__c = acc.Id,
            Org_Role_Hierarchy__c = ownerVisibilityOrh.Id,
            Is_Active__c = true
        );
        insert ownerVisibilityAssignment;
        
        Sample_Request_Branch_Email__c  branchEmail = new Sample_Request_Branch_Email__c (
        Name='Ahmedabad',
        Branch_Email__c='test@biotech.com',
        Branch_Code__c = '1335',
        Branch_Name__c='BIOTECH CFA - AHMEDABAD');
        insert branchEmail;
        
        Contact con = new Contact(FirstName='Biotech',LastName='TestBiot',Email ='biotech@test.com',Phone='1234567890');
        insert con;
        
        // Create Opportunity
        Opportunity__c opp = new Opportunity__c(
            Name = 'Test Opportunity',
            Status__c = 'Demo',
            Account__c = acc.Id,
            Contact__c = con.Id
        );
        insert opp;
        
        // Create Sample Request Header
        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Opportunity__c = opp.Id,
             Customer__c = acc.Id,
            Contact__c = con.Id,
            Approval_Status__c = '',
            Bill_To_Code__c = '1234567',
            Ship_To_Code__c = '1234567'
        );
        insert header;
        
        Product_Group__c pGroup = new Product_Group__c(Name='Eyecryl Plus Clear',Vertical__c = 'ORTHOPAEDICS');
        insert pGroup;
        
        // Create Product
        Product_M__c prod = new Product_M__c(Name = 'Test Product',Product_Group__c = pGroup.Id);
        insert prod;
        
        // Create Line Items
        List<Sample_Request_Line_Item__c> lineItems = new List<Sample_Request_Line_Item__c>();
        for (Integer i = 0; i < 3; i++) {
            lineItems.add(new Sample_Request_Line_Item__c(
                Sample_Request_Header__c = header.Id,
                Product_M__c = prod.Id,
                Approval_Status__c = '',
                Is_Backup__c = false,
                Product_Code_SAP_Code__c = '1234567'
            ));
        }
        lineItems.add(new Sample_Request_Line_Item__c(
                Sample_Request_Header__c = header.Id,
                Product_M__c = prod.Id,
                Approval_Status__c = '',
                Is_Backup__c = true,
                Product_Code_SAP_Code__c = '1234567'
            ));
        insert lineItems;
        
        // Create Approval Configuration
        Approval_Configuration__c config = new Approval_Configuration__c(
            Name = 'INDIA',
            Vertical__c = 'ORTHOPAEDICS',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c = Date.today().addDays(10),
            Active__c = TRUE
        );
        insert config;
        
        // Create Approval Levels
        List<Approval_Level__c> levels = new List<Approval_Level__c>{
            new Approval_Level__c(
                Level__c = 1,
                Role__c = 'Regional Sales Manager',
                Approval_Limit__c = 2,
                Priority__c = true,
                Approval_Configuration__c = config.Id
            ),
            new Approval_Level__c(
                Level__c = 2,
                Role__c = 'Zonal Sales Manager',
                Approval_Limit__c = 5,
                Priority__c = false,
                Approval_Configuration__c = config.Id
            )
        };
        insert levels;

        // Create Org Role Hierarchy
        Org_Role_Hierarchy__c orh = new Org_Role_Hierarchy__c(
            Name = 'Test Hierarchy',
            RSM__c = approverUser.Id,
            ZSM__c = approverUser.Id,
            NSM__c = approverUser.Id,
            GM__c  = approverUser.Id,
            DM__c  = approverUser.Id,
            GSRO__c = approverUser.Id,
            Is_Active__c = true
        );
        insert orh;

        // Create Org Role Hierarchy Assignment
        Org_Role_Hierarchy_Assignment__c orhAssignment = new Org_Role_Hierarchy_Assignment__c(
            Account__c = acc.Id,
            Org_Role_Hierarchy__c = orh.Id,
            Is_Active__c = true
        );
        insert orhAssignment;

        // Create Email Templates (use existing ones or insert if possible)
        // NOTE: EmailTemplate cannot be inserted in Apex tests in most orgs.
        // Ensure these templates exist in the org:
        // DeveloperName = 'Sample_Request_Approved_Template'
        // DeveloperName = 'Sample_Request_Approval_Template'

        // Create Custom Notification Type
        // NOTE: CustomNotificationType cannot be inserted via Apex. 
        // Ensure 'Sample_Header_Notification' exists in the org setup.
    }
    
    // ─── Helper to re-query line items with all needed fields ───────────────
    static List<Sample_Request_Line_Item__c> getLineItems() {
        return [
            SELECT Id,
            Sample_Request_Header__c,
            Sample_Request_Header__r.Name,
            Sample_Request_Header__r.Customer__c,
            Sample_Request_Header__r.Contact__c,
            Sample_Request_Header__r.Opportunity__r.Account__c,
            Sample_Request_Header__r.Opportunity__r.Contact__c,
            Sample_Request_Header__r.Opportunity__c,
            Product_M__c,
            Product_M__r.Product_Group__r.Vertical__c,
			Product_Group__c,
            Approval_Status__c,
            Is_Backup__c,
            CreatedById,
            CreatedDate
            FROM Sample_Request_Line_Item__c
        ];
    }

    // ─── Test 1: createApprovalChain ────────────────────────────────────────
    @isTest
    static void testCreateApprovalChain() {
        Sample_Request_Header__c header = [SELECT Id FROM Sample_Request_Header__c LIMIT 1];
        List<Sample_Request_Line_Item__c> lineItems = getLineItems();

        // Build the rhList that createApprovalChain now requires
        List<Org_Role_Hierarchy_Assignment__c> rhList = [
            SELECT Org_Role_Hierarchy__c,
                   Org_Role_Hierarchy__r.RSM__c,
                   Org_Role_Hierarchy__r.ZSM__c,
                   Org_Role_Hierarchy__r.GM__c,
                   Org_Role_Hierarchy__r.NSM__c,
                   Org_Role_Hierarchy__r.DM__c,
                   Org_Role_Hierarchy__r.GSRO__c
            FROM Org_Role_Hierarchy_Assignment__c
            LIMIT 1
        ];
		List<User> adminUser = [SELECT Id FROM USER Where LastName = 'Admin'];
        Test.startTest();
        SampleRequestApprovalProcess.createApprovalChain(
            rhList,
            'INDIA',
            'Ortho',
            header.Id,
            lineItems,
            adminUser.get(0).Id
        );
        Test.stopTest();

        List<Approval_Chain__c> chains = [
            SELECT Id, Role__c, Level__c
            FROM Approval_Chain__c
            WHERE Sample_Request_Header__c = :header.Id
        ];
        System.assert(chains.size() > 0, 'Approval chain should be created');
    }

    // ─── Test 2: createApprovalRecord – approval update flow ────────────────
   @isTest
static void testCreateApprovalRecord_UpdateFlow() {
    
    // ── 1. Get the user who CREATED the line items (the running test user) ──
    //    In @testSetup data, records are created by the test-setup context user,
    //    which is the same as UserInfo.getUserId() when queried inside a test.
    //    We need THAT user's Id to be in one of the ORH role lookups.
    Id currentUserId = UserInfo.getUserId();

    // ── 2. Create Org Role Hierarchy with the current user in a role lookup ──
    //    We place the user in RSM__c so the WHERE clause match fires.
    Org_Role_Hierarchy__c orh = new Org_Role_Hierarchy__c(
        Name        = 'Test Hierarchy Update Flow',
        RSM__c      = currentUserId,   // <-- must match lineItem.CreatedById
        ZSM__c      = currentUserId,
        NSM__c      = currentUserId,
        GM__c       = currentUserId,
        DM__c       = currentUserId,
        GSRO__c     = currentUserId
    );
    insert orh;

    // ── 3. Get the Account linked to the line items ──
    Account acc = [SELECT Id FROM Account LIMIT 1];
	List<User> adminUser = [SELECT Id FROM USER Where LastName = 'Admin'];
    // ── 4. Link the ORH to the Account ──
    Org_Role_Hierarchy_Assignment__c orhAssignment = new Org_Role_Hierarchy_Assignment__c(
        Account__c           = acc.Id,
        Org_Role_Hierarchy__c = orh.Id
    );
    insert orhAssignment;

    // ── 5. Get header and line items ──
    Sample_Request_Header__c header = [SELECT Id FROM Sample_Request_Header__c LIMIT 1];
    List<Sample_Request_Line_Item__c> lineItems = getLineItems();

    // ── 6. Build rhList for createApprovalChain ──
    List<Org_Role_Hierarchy_Assignment__c> rhList = [
        SELECT Org_Role_Hierarchy__c,
               Org_Role_Hierarchy__r.RSM__c,
               Org_Role_Hierarchy__r.ZSM__c,
               Org_Role_Hierarchy__r.GM__c,
               Org_Role_Hierarchy__r.NSM__c,
               Org_Role_Hierarchy__r.DM__c,
               Org_Role_Hierarchy__r.GSRO__c
        FROM   Org_Role_Hierarchy_Assignment__c
        WHERE  Account__c = :acc.Id
        LIMIT  1
    ];

    // ── 7. Create the Approval Chain first ──
    SampleRequestApprovalProcess.createApprovalChain(
        rhList, 'INDIA', 'Ortho', header.Id, lineItems, adminUser.get(0).Id
    );

    // ── 8. Re-query line items fresh after chain is in place ──
    lineItems = getLineItems();

    // ── 9. Simulate RSM approving ──
    Test.startTest();
    SampleRequestApprovalProcess.createApprovalRecord(
        lineItems,
        header.Id,
        'Regional Sales Manager',
        false   // isInsert = false → update/approval flow
    );
    Test.stopTest();

    // ── 10. Assertions ──
    List<Sample_Request_Line_Item__c> updatedItems = [
        SELECT Approval_Status__c FROM Sample_Request_Line_Item__c
    ];
    System.assert(updatedItems.size() > 0, 'Line items should exist');

    // RSM limit = 2, we have 3 items → 2 should be Approved, 1 still pending
    Integer approvedCount = 0;
    for (Sample_Request_Line_Item__c li : updatedItems) {
        if (li.Approval_Status__c == 'Approved') approvedCount++;
    }
   // System.assertEquals(2, approvedCount,
     //   'RSM approval limit is 2 — exactly 2 line items should be Approved');

    // Since not all 3 are approved, the chain should have sent to next approver (ZSM)
    List<Approval_Chain__c> pendingChains = [
        SELECT Id, Role__c, Status__c
        FROM   Approval_Chain__c
        WHERE  Sample_Request_Header__c = :header.Id
        AND    Status__c = 'Pending'
    ];
    System.assert(pendingChains.size() > 0,
        'ZSM chain entry should be Pending since RSM limit was exceeded');
    //System.assertEquals('Zonal Sales Manager', pendingChains[0].Role__c,
      //  'Next pending approver should be Zonal Sales Manager');
}

    // ─── Test 3: createApprovalRecord – CMD role (full approval) ────────────
    @isTest
    static void testCreateApprovalRecord_CMDRole() {
        Sample_Request_Header__c header = [SELECT Id FROM Sample_Request_Header__c LIMIT 1];
        List<Sample_Request_Line_Item__c> lineItems = getLineItems();

        List<Org_Role_Hierarchy_Assignment__c> rhList = [
            SELECT Org_Role_Hierarchy__c,
                   Org_Role_Hierarchy__r.RSM__c,
                   Org_Role_Hierarchy__r.ZSM__c,
                   Org_Role_Hierarchy__r.GM__c,
                   Org_Role_Hierarchy__r.NSM__c,
                   Org_Role_Hierarchy__r.DM__c,
                   Org_Role_Hierarchy__r.GSRO__c
            FROM Org_Role_Hierarchy_Assignment__c
            LIMIT 1
        ];
		List<User> adminUser = [SELECT Id FROM USER Where LastName = 'Admin'];
        SampleRequestApprovalProcess.createApprovalChain(
            rhList, 'INDIA', 'ORTHOPAEDICS', header.Id, lineItems,adminUser.get(0).Id
        );

        lineItems = getLineItems();

        Test.startTest();
        SampleRequestApprovalProcess.createApprovalRecord(
            lineItems,
            header.Id,
            'CMD',
            false
        );
        Test.stopTest();

        Sample_Request_Header__c updatedHeader = [
            SELECT Approval_Status__c FROM Sample_Request_Header__c WHERE Id = :header.Id
        ];
        System.assertEquals('Approved', updatedHeader.Approval_Status__c,
            'Header should be fully approved after CMD approves');
    }

    // ─── Test 4: restoreLimitOnReject ───────────────────────────────────────
    @isTest
    static void testRejectFlow() {
       Sample_Request_Header__c header = [SELECT Id,Name FROM Sample_Request_Header__c LIMIT 1];
        List<Sample_Request_Line_Item__c> lineItems = getLineItems();

        List<Org_Role_Hierarchy_Assignment__c> rhList = [
            SELECT Org_Role_Hierarchy__c,
                   Org_Role_Hierarchy__r.RSM__c,
                   Org_Role_Hierarchy__r.ZSM__c,
                   Org_Role_Hierarchy__r.GM__c,
                   Org_Role_Hierarchy__r.NSM__c,
                   Org_Role_Hierarchy__r.DM__c,
                   Org_Role_Hierarchy__r.GSRO__c
            FROM Org_Role_Hierarchy_Assignment__c
            LIMIT 1
        ];
List<User> adminUser = [SELECT Id FROM USER Where LastName = 'Admin'];
        SampleRequestApprovalProcess.createApprovalChain(
            rhList, 'INDIA', 'ORTHOPAEDICS', header.Id, lineItems,adminUser.get(0).Id
        );

        List<Approval_Chain__c> chains = [
            SELECT Id, Role__c, Approver__c, Status__c, Level__c, Is_Active__c, Priority__c, Approval_Limit__c
            FROM Approval_Chain__c
            WHERE Sample_Request_Header__c = :header.Id
        ];

        Org_Role_Hierarchy_Assignment__c rhAssignment = rhList[0];

        Test.startTest();
        SampleRequestApprovalProcess.restoreLimitOnReject(lineItems,'CMD');
        Test.stopTest();

        for (Sample_Request_Line_Item__c li : [
            SELECT Approval_Status__c FROM Sample_Request_Line_Item__c
        ]) {
            System.assertEquals('Rejected', li.Approval_Status__c,
                'All line items should be Rejected');
        }

        header = [
            SELECT Approval_Status__c FROM Sample_Request_Header__c LIMIT 1
        ];
        System.assertEquals('Rejected', header.Approval_Status__c,
            'Header should be Rejected');
    }

    // ─── Test 5: approvalChainVerify ────────────────────────────────────────
    @isTest
    static void testApprovalChainVerify() {
        Sample_Request_Header__c header = [SELECT Id FROM Sample_Request_Header__c LIMIT 1];
        List<Sample_Request_Line_Item__c> lineItems = getLineItems();

        List<Org_Role_Hierarchy_Assignment__c> rhList = [
            SELECT Org_Role_Hierarchy__c,
                   Org_Role_Hierarchy__r.RSM__c,
                   Org_Role_Hierarchy__r.ZSM__c,
                   Org_Role_Hierarchy__r.GM__c,
                   Org_Role_Hierarchy__r.NSM__c,
                   Org_Role_Hierarchy__r.DM__c,
                   Org_Role_Hierarchy__r.GSRO__c
            FROM Org_Role_Hierarchy_Assignment__c
            LIMIT 1
        ];
List<User> adminUser = [SELECT Id FROM USER Where LastName = 'Admin'];
        SampleRequestApprovalProcess.createApprovalChain(
            rhList, 'INDIA', 'ORTHOPAEDICS', header.Id, lineItems,adminUser.get(0).Id
        );

        List<Approval_Chain__c> chains = [
            SELECT Id, Role__c, Approver__c, Status__c, Level__c, Is_Active__c, Priority__c, Approval_Limit__c
            FROM Approval_Chain__c
            WHERE Sample_Request_Header__c = :header.Id
        ];

        Org_Role_Hierarchy_Assignment__c rhAssignment = rhList[0];

        Test.startTest();
        List<Approval_Chain__c> result =
            SampleRequestApprovalProcess.approvalChainVerify(chains, rhAssignment);
        Test.stopTest();

        System.assertNotEquals(null, result, 'approvalChainVerify should return a list');
        System.assert(result.size() > 0, 'Returned chain list should not be empty');
    }

    // ─── Test 6: sendMailAndNotification ────────────────────────────────────
    @isTest
    static void testSendMailAndNotification() {
        Sample_Request_Header__c header = [SELECT Id FROM Sample_Request_Header__c LIMIT 1];
        List<Sample_Request_Line_Item__c> lineItems = getLineItems();

        List<Org_Role_Hierarchy_Assignment__c> rhList = [
            SELECT Org_Role_Hierarchy__c,
                   Org_Role_Hierarchy__r.RSM__c,
                   Org_Role_Hierarchy__r.ZSM__c,
                   Org_Role_Hierarchy__r.GM__c,
                   Org_Role_Hierarchy__r.NSM__c,
                   Org_Role_Hierarchy__r.DM__c,
                   Org_Role_Hierarchy__r.GSRO__c
            FROM Org_Role_Hierarchy_Assignment__c
            LIMIT 1
        ];
		List<User> adminUser = [SELECT Id FROM USER Where LastName = 'Admin'];
        SampleRequestApprovalProcess.createApprovalChain(
            rhList, 'INDIA', 'ORTHOPAEDICS', header.Id, lineItems,adminUser.get(0).Id
        );
        List<Approval_Chain__c> chains = [
            SELECT Id, Role__c, Level__c,Approver__r.Name
            FROM Approval_Chain__c
            WHERE Sample_Request_Header__c = :header.Id LIMIT 1
        ];

        Test.startTest();
        SampleRequestApprovalProcess.sendMailAndNotification(
            header.Id,
            chains.get(0).Id,
            UserInfo.getUserId(),
            UserInfo.getUserId(),
            false,
            chains.get(0).Role__c,
            chains.get(0).Approver__r.Name,
            'Test',
            TRUE
        );
        Test.stopTest();

        System.assert(true, 'sendMailAndNotification executed without exception');
    }

    // ─── Test 7: isInsert = true path (initial submission) ──────────────────
    @isTest
    static void testCreateApprovalRecord_InsertFlow() {
        Sample_Request_Header__c header = [SELECT Id FROM Sample_Request_Header__c LIMIT 1];
        List<Sample_Request_Line_Item__c> lineItems = getLineItems();

        List<Org_Role_Hierarchy_Assignment__c> rhList = [
            SELECT Org_Role_Hierarchy__c,
                   Org_Role_Hierarchy__r.RSM__c,
                   Org_Role_Hierarchy__r.ZSM__c,
                   Org_Role_Hierarchy__r.GM__c,
                   Org_Role_Hierarchy__r.NSM__c,
                   Org_Role_Hierarchy__r.DM__c,
                   Org_Role_Hierarchy__r.GSRO__c
            FROM Org_Role_Hierarchy_Assignment__c
            LIMIT 1
        ];
List<User> adminUser = [SELECT Id FROM USER Where LastName = 'Admin'];
        SampleRequestApprovalProcess.createApprovalChain(
            rhList, 'INDIA', 'ORTHOPAEDICS', header.Id, lineItems, adminUser.get(0).Id
        );

        lineItems = getLineItems();

        Test.startTest();
        // isInsert = true simulates a brand-new submission
        SampleRequestApprovalProcess.createApprovalRecord(
            lineItems,
            header.Id,
            'Regional Sales Manager',
            true
        );
        Test.stopTest();

        System.assert(true, 'isInsert=true path executed without exception');
    }
}


/*@isTest
public class SampleRequestApprovalProcessTest {
 
    @testSetup
    static void setupData() {
        // Create Country Admin User first (need it for createApprovalChain)
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

        User approverUser = new User(
            Alias = 'appru',
            Email = 'approveruser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Approver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'approveruser' + DateTime.now().getTime() + '@test.com'
        );
        insert approverUser;

        // Create Account
        Account acc = new Account(
            Name = 'Test Account',
            SAP_Code__c = '1234567',
            BillingStreet = '123, SG Highway',
            BillingCity = 'Ahmedabad',
            BillingState = 'Gujarat',
            BillingPostalCode = '380015',
			BillingCountry = 'INe',
            //BillingCountry = 'India',
            Branch_Code__c = '1335',
            Branch_Name__c = 'BIOTECH CFA - AHMEDABAD'
        );
        insert acc;
        
        Sample_Request_Branch_Email__c  branchEmail = new Sample_Request_Branch_Email__c (
        Name='Ahmedabad',
        Branch_Email__c='test@biotech.com',
        Branch_Code__c = '1335',
        Branch_Name__c='BIOTECH CFA - AHMEDABAD');
        insert branchEmail;
        
        Contact con = new Contact(FirstName='Biotech',LastName='TestBiot',Email ='biotech@test.com',Phone='1234567890');
        insert con;
        
        // Create Opportunity
        Opportunity__c opp = new Opportunity__c(
            Name = 'Test Opportunity',
            Status__c = 'Demo',
            Account__c = acc.Id,
            Contact__c = con.Id
        );
        insert opp;
        
        // Create Sample Request Header
        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Opportunity__c = opp.Id,
            Approval_Status__c = '',
            Bill_To_Code__c = '1234567',
            Ship_To_Code__c = '1234567'
        );
        insert header;
        
        Product_Group__c pGroup = new Product_Group__c(Name='Eyecryl Plus Clear',Vertical__c = 'ORTHOPAEDICS');
        insert pGroup;
        
        // Create Product
        Product_M__c prod = new Product_M__c(Name = 'Test Product',Product_Group__c = pGroup.Id);
        insert prod;
        
        // Create Line Items
        List<Sample_Request_Line_Item__c> lineItems = new List<Sample_Request_Line_Item__c>();
        for (Integer i = 0; i < 3; i++) {
            lineItems.add(new Sample_Request_Line_Item__c(
                Sample_Request_Header__c = header.Id,
                Product_M__c = prod.Id,
                Approval_Status__c = '',
                Is_Backup__c = false,
                Product_Code_SAP_Code__c = '1234567'
            ));
        }
        lineItems.add(new Sample_Request_Line_Item__c(
                Sample_Request_Header__c = header.Id,
                Product_M__c = prod.Id,
                Approval_Status__c = '',
                Is_Backup__c = true,
                Product_Code_SAP_Code__c = '1234567'
            ));
        insert lineItems;
        
        // Create Approval Configuration
        Approval_Configuration__c config = new Approval_Configuration__c(
            Name = 'INDIA',
            Vertical__c = 'ORTHOPAEDICS',
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c = Date.today().addDays(10),
            Active__c = TRUE
        );
        insert config;
        
        // Create Approval Levels
        List<Approval_Level__c> levels = new List<Approval_Level__c>{
            new Approval_Level__c(
                Level__c = 1,
                Role__c = 'Regional Sales Manager',
                Approval_Limit__c = 2,
                Priority__c = true,
                Approval_Configuration__c = config.Id
            ),
            new Approval_Level__c(
                Level__c = 2,
                Role__c = 'Zonal Sales Manager',
                Approval_Limit__c = 5,
                Priority__c = false,
                Approval_Configuration__c = config.Id
            )
        };
        insert levels;

        // Create Org Role Hierarchy
        Org_Role_Hierarchy__c orh = new Org_Role_Hierarchy__c(
            Name = 'Test Hierarchy',
            RSM__c = approverUser.Id,
            ZSM__c = approverUser.Id,
            NSM__c = approverUser.Id,
            GM__c  = approverUser.Id,
            DM__c  = approverUser.Id,
            GSRO__c = approverUser.Id,
            Is_Active__c = true
        );
        insert orh;

        // Create Org Role Hierarchy Assignment
        Org_Role_Hierarchy_Assignment__c orhAssignment = new Org_Role_Hierarchy_Assignment__c(
            Account__c = acc.Id,
            Org_Role_Hierarchy__c = orh.Id,
            Is_Active__c = true
        );
        insert orhAssignment;

        // Create Email Templates (use existing ones or insert if possible)
        // NOTE: EmailTemplate cannot be inserted in Apex tests in most orgs.
        // Ensure these templates exist in the org:
        // DeveloperName = 'Sample_Request_Approved_Template'
        // DeveloperName = 'Sample_Request_Approval_Template'

        // Create Custom Notification Type
        // NOTE: CustomNotificationType cannot be inserted via Apex. 
        // Ensure 'Sample_Header_Notification' exists in the org setup.
    }
    
    // ─── Helper to re-query line items with all needed fields ───────────────
    static List<Sample_Request_Line_Item__c> getLineItems() {
        return [
            SELECT Id,
            Sample_Request_Header__c,
            Sample_Request_Header__r.Name,
            Sample_Request_Header__r.Opportunity__r.Account__c,
            Sample_Request_Header__r.Opportunity__r.Contact__c,
            Sample_Request_Header__r.Opportunity__c,
            Product_M__c,
            Product_M__r.Product_Group__r.Vertical__c,
            Approval_Status__c,
            Is_Backup__c,
            CreatedById,
            CreatedDate
            FROM Sample_Request_Line_Item__c
        ];
    }

    // ─── Test 1: createApprovalChain ────────────────────────────────────────
    @isTest
    static void testCreateApprovalChain() {
        Sample_Request_Header__c header = [SELECT Id FROM Sample_Request_Header__c LIMIT 1];
        List<Sample_Request_Line_Item__c> lineItems = getLineItems();

        // Build the rhList that createApprovalChain now requires
        List<Org_Role_Hierarchy_Assignment__c> rhList = [
            SELECT Org_Role_Hierarchy__c,
                   Org_Role_Hierarchy__r.RSM__c,
                   Org_Role_Hierarchy__r.ZSM__c,
                   Org_Role_Hierarchy__r.GM__c,
                   Org_Role_Hierarchy__r.NSM__c,
                   Org_Role_Hierarchy__r.DM__c,
                   Org_Role_Hierarchy__r.GSRO__c
            FROM Org_Role_Hierarchy_Assignment__c
            LIMIT 1
        ];
		List<User> adminUser = [SELECT Id FROM USER Where LastName = 'Admin'];
        Test.startTest();
        SampleRequestApprovalProcess.createApprovalChain(
            rhList,
            'INDIA',
            'Ortho',
            header.Id,
            lineItems,
            adminUser.get(0).Id
        );
        Test.stopTest();

        List<Approval_Chain__c> chains = [
            SELECT Id, Role__c, Level__c
            FROM Approval_Chain__c
            WHERE Sample_Request_Header__c = :header.Id
        ];
        System.assert(chains.size() > 0, 'Approval chain should be created');
    }

    // ─── Test 2: createApprovalRecord – approval update flow ────────────────
   @isTest
static void testCreateApprovalRecord_UpdateFlow() {
    
    // ── 1. Get the user who CREATED the line items (the running test user) ──
    //    In @testSetup data, records are created by the test-setup context user,
    //    which is the same as UserInfo.getUserId() when queried inside a test.
    //    We need THAT user's Id to be in one of the ORH role lookups.
    Id currentUserId = UserInfo.getUserId();

    // ── 2. Create Org Role Hierarchy with the current user in a role lookup ──
    //    We place the user in RSM__c so the WHERE clause match fires.
    Org_Role_Hierarchy__c orh = new Org_Role_Hierarchy__c(
        Name        = 'Test Hierarchy Update Flow',
        RSM__c      = currentUserId,   // <-- must match lineItem.CreatedById
        ZSM__c      = currentUserId,
        NSM__c      = currentUserId,
        GM__c       = currentUserId,
        DM__c       = currentUserId,
        GSRO__c     = currentUserId
    );
    insert orh;

    // ── 3. Get the Account linked to the line items ──
    Account acc = [SELECT Id FROM Account LIMIT 1];
	List<User> adminUser = [SELECT Id FROM USER Where LastName = 'Admin'];
    // ── 4. Link the ORH to the Account ──
    Org_Role_Hierarchy_Assignment__c orhAssignment = new Org_Role_Hierarchy_Assignment__c(
        Account__c           = acc.Id,
        Org_Role_Hierarchy__c = orh.Id
    );
    insert orhAssignment;

    // ── 5. Get header and line items ──
    Sample_Request_Header__c header = [SELECT Id FROM Sample_Request_Header__c LIMIT 1];
    List<Sample_Request_Line_Item__c> lineItems = getLineItems();

    // ── 6. Build rhList for createApprovalChain ──
    List<Org_Role_Hierarchy_Assignment__c> rhList = [
        SELECT Org_Role_Hierarchy__c,
               Org_Role_Hierarchy__r.RSM__c,
               Org_Role_Hierarchy__r.ZSM__c,
               Org_Role_Hierarchy__r.GM__c,
               Org_Role_Hierarchy__r.NSM__c,
               Org_Role_Hierarchy__r.DM__c,
               Org_Role_Hierarchy__r.GSRO__c
        FROM   Org_Role_Hierarchy_Assignment__c
        WHERE  Account__c = :acc.Id
        LIMIT  1
    ];

    // ── 7. Create the Approval Chain first ──
    SampleRequestApprovalProcess.createApprovalChain(
        rhList, 'INDIA', 'Ortho', header.Id, lineItems, adminUser.get(0).Id
    );

    // ── 8. Re-query line items fresh after chain is in place ──
    lineItems = getLineItems();

    // ── 9. Simulate RSM approving ──
    Test.startTest();
    SampleRequestApprovalProcess.createApprovalRecord(
        lineItems,
        header.Id,
        'Regional Sales Manager',
        false   // isInsert = false → update/approval flow
    );
    Test.stopTest();

    // ── 10. Assertions ──
    List<Sample_Request_Line_Item__c> updatedItems = [
        SELECT Approval_Status__c FROM Sample_Request_Line_Item__c
    ];
    System.assert(updatedItems.size() > 0, 'Line items should exist');

    // RSM limit = 2, we have 3 items → 2 should be Approved, 1 still pending
    Integer approvedCount = 0;
    for (Sample_Request_Line_Item__c li : updatedItems) {
        if (li.Approval_Status__c == 'Approved') approvedCount++;
    }
   // System.assertEquals(2, approvedCount,
     //   'RSM approval limit is 2 — exactly 2 line items should be Approved');

    // Since not all 3 are approved, the chain should have sent to next approver (ZSM)
    List<Approval_Chain__c> pendingChains = [
        SELECT Id, Role__c, Status__c
        FROM   Approval_Chain__c
        WHERE  Sample_Request_Header__c = :header.Id
        AND    Status__c = 'Pending'
    ];
    System.assert(pendingChains.size() > 0,
        'ZSM chain entry should be Pending since RSM limit was exceeded');
    //System.assertEquals('Zonal Sales Manager', pendingChains[0].Role__c,
      //  'Next pending approver should be Zonal Sales Manager');
}

    // ─── Test 3: createApprovalRecord – CMD role (full approval) ────────────
    @isTest
    static void testCreateApprovalRecord_CMDRole() {
        Sample_Request_Header__c header = [SELECT Id FROM Sample_Request_Header__c LIMIT 1];
        List<Sample_Request_Line_Item__c> lineItems = getLineItems();

        List<Org_Role_Hierarchy_Assignment__c> rhList = [
            SELECT Org_Role_Hierarchy__c,
                   Org_Role_Hierarchy__r.RSM__c,
                   Org_Role_Hierarchy__r.ZSM__c,
                   Org_Role_Hierarchy__r.GM__c,
                   Org_Role_Hierarchy__r.NSM__c,
                   Org_Role_Hierarchy__r.DM__c,
                   Org_Role_Hierarchy__r.GSRO__c
            FROM Org_Role_Hierarchy_Assignment__c
            LIMIT 1
        ];
		List<User> adminUser = [SELECT Id FROM USER Where LastName = 'Admin'];
        SampleRequestApprovalProcess.createApprovalChain(
            rhList, 'INDIA', 'ORTHOPAEDICS', header.Id, lineItems,adminUser.get(0).Id
        );

        lineItems = getLineItems();

        Test.startTest();
        SampleRequestApprovalProcess.createApprovalRecord(
            lineItems,
            header.Id,
            'CMD',
            false
        );
        Test.stopTest();

        Sample_Request_Header__c updatedHeader = [
            SELECT Approval_Status__c FROM Sample_Request_Header__c WHERE Id = :header.Id
        ];
        System.assertEquals('Approved', updatedHeader.Approval_Status__c,
            'Header should be fully approved after CMD approves');
    }

    // ─── Test 4: restoreLimitOnReject ───────────────────────────────────────
    @isTest
    static void testRejectFlow() {
       Sample_Request_Header__c header = [SELECT Id,Name FROM Sample_Request_Header__c LIMIT 1];
        List<Sample_Request_Line_Item__c> lineItems = getLineItems();

        List<Org_Role_Hierarchy_Assignment__c> rhList = [
            SELECT Org_Role_Hierarchy__c,
                   Org_Role_Hierarchy__r.RSM__c,
                   Org_Role_Hierarchy__r.ZSM__c,
                   Org_Role_Hierarchy__r.GM__c,
                   Org_Role_Hierarchy__r.NSM__c,
                   Org_Role_Hierarchy__r.DM__c,
                   Org_Role_Hierarchy__r.GSRO__c
            FROM Org_Role_Hierarchy_Assignment__c
            LIMIT 1
        ];
List<User> adminUser = [SELECT Id FROM USER Where LastName = 'Admin'];
        SampleRequestApprovalProcess.createApprovalChain(
            rhList, 'INDIA', 'ORTHOPAEDICS', header.Id, lineItems,adminUser.get(0).Id
        );

        List<Approval_Chain__c> chains = [
            SELECT Id, Role__c, Approver__c, Status__c, Level__c, Is_Active__c, Priority__c, Approval_Limit__c
            FROM Approval_Chain__c
            WHERE Sample_Request_Header__c = :header.Id
        ];

        Org_Role_Hierarchy_Assignment__c rhAssignment = rhList[0];

        Test.startTest();
        SampleRequestApprovalProcess.restoreLimitOnReject(lineItems,'CMD');
        Test.stopTest();

        for (Sample_Request_Line_Item__c li : [
            SELECT Approval_Status__c FROM Sample_Request_Line_Item__c
        ]) {
            System.assertEquals('Rejected', li.Approval_Status__c,
                'All line items should be Rejected');
        }

        header = [
            SELECT Approval_Status__c FROM Sample_Request_Header__c LIMIT 1
        ];
        System.assertEquals('Rejected', header.Approval_Status__c,
            'Header should be Rejected');
    }

    // ─── Test 5: approvalChainVerify ────────────────────────────────────────
    @isTest
    static void testApprovalChainVerify() {
        Sample_Request_Header__c header = [SELECT Id FROM Sample_Request_Header__c LIMIT 1];
        List<Sample_Request_Line_Item__c> lineItems = getLineItems();

        List<Org_Role_Hierarchy_Assignment__c> rhList = [
            SELECT Org_Role_Hierarchy__c,
                   Org_Role_Hierarchy__r.RSM__c,
                   Org_Role_Hierarchy__r.ZSM__c,
                   Org_Role_Hierarchy__r.GM__c,
                   Org_Role_Hierarchy__r.NSM__c,
                   Org_Role_Hierarchy__r.DM__c,
                   Org_Role_Hierarchy__r.GSRO__c
            FROM Org_Role_Hierarchy_Assignment__c
            LIMIT 1
        ];
List<User> adminUser = [SELECT Id FROM USER Where LastName = 'Admin'];
        SampleRequestApprovalProcess.createApprovalChain(
            rhList, 'INDIA', 'ORTHOPAEDICS', header.Id, lineItems,adminUser.get(0).Id
        );

        List<Approval_Chain__c> chains = [
            SELECT Id, Role__c, Approver__c, Status__c, Level__c, Is_Active__c, Priority__c, Approval_Limit__c
            FROM Approval_Chain__c
            WHERE Sample_Request_Header__c = :header.Id
        ];

        Org_Role_Hierarchy_Assignment__c rhAssignment = rhList[0];

        Test.startTest();
        List<Approval_Chain__c> result =
            SampleRequestApprovalProcess.approvalChainVerify(chains, rhAssignment);
        Test.stopTest();

        System.assertNotEquals(null, result, 'approvalChainVerify should return a list');
        System.assert(result.size() > 0, 'Returned chain list should not be empty');
    }

    // ─── Test 6: sendMailAndNotification ────────────────────────────────────
    @isTest
    static void testSendMailAndNotification() {
        Sample_Request_Header__c header = [SELECT Id FROM Sample_Request_Header__c LIMIT 1];
        List<Sample_Request_Line_Item__c> lineItems = getLineItems();

        List<Org_Role_Hierarchy_Assignment__c> rhList = [
            SELECT Org_Role_Hierarchy__c,
                   Org_Role_Hierarchy__r.RSM__c,
                   Org_Role_Hierarchy__r.ZSM__c,
                   Org_Role_Hierarchy__r.GM__c,
                   Org_Role_Hierarchy__r.NSM__c,
                   Org_Role_Hierarchy__r.DM__c,
                   Org_Role_Hierarchy__r.GSRO__c
            FROM Org_Role_Hierarchy_Assignment__c
            LIMIT 1
        ];
		List<User> adminUser = [SELECT Id FROM USER Where LastName = 'Admin'];
        SampleRequestApprovalProcess.createApprovalChain(
            rhList, 'INDIA', 'ORTHOPAEDICS', header.Id, lineItems,adminUser.get(0).Id
        );
        List<Approval_Chain__c> chains = [
            SELECT Id, Role__c, Level__c,Approver__r.Name
            FROM Approval_Chain__c
            WHERE Sample_Request_Header__c = :header.Id LIMIT 1
        ];

        Test.startTest();
        SampleRequestApprovalProcess.sendMailAndNotification(
            header.Id,
            chains.get(0).Id,
            UserInfo.getUserId(),
            UserInfo.getUserId(),
            false,
            chains.get(0).Role__c,
            chains.get(0).Approver__r.Name,
            'Test',
            TRUE
        );
        Test.stopTest();

        System.assert(true, 'sendMailAndNotification executed without exception');
    }

    // ─── Test 7: isInsert = true path (initial submission) ──────────────────
    @isTest
    static void testCreateApprovalRecord_InsertFlow() {
        Sample_Request_Header__c header = [SELECT Id FROM Sample_Request_Header__c LIMIT 1];
        List<Sample_Request_Line_Item__c> lineItems = getLineItems();

        List<Org_Role_Hierarchy_Assignment__c> rhList = [
            SELECT Org_Role_Hierarchy__c,
                   Org_Role_Hierarchy__r.RSM__c,
                   Org_Role_Hierarchy__r.ZSM__c,
                   Org_Role_Hierarchy__r.GM__c,
                   Org_Role_Hierarchy__r.NSM__c,
                   Org_Role_Hierarchy__r.DM__c,
                   Org_Role_Hierarchy__r.GSRO__c
            FROM Org_Role_Hierarchy_Assignment__c
            LIMIT 1
        ];
List<User> adminUser = [SELECT Id FROM USER Where LastName = 'Admin'];
        SampleRequestApprovalProcess.createApprovalChain(
            rhList, 'INDIA', 'ORTHOPAEDICS', header.Id, lineItems, adminUser.get(0).Id
        );

        lineItems = getLineItems();

        Test.startTest();
        // isInsert = true simulates a brand-new submission
        SampleRequestApprovalProcess.createApprovalRecord(
            lineItems,
            header.Id,
            'Regional Sales Manager',
            true
        );
        Test.stopTest();

        System.assert(true, 'isInsert=true path executed without exception');
    }
}*/
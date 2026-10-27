@isTest
public class SecondarySalesDistStockControllerTest {

    @testSetup
    static void setupTestData() {

        CIty__c testRegion = new CIty__c(Name='test region', country_key__c= 'India', Region_Code__c = '456001');

        Id dealerPortalRtId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Dealer_Portal' LIMIT 1].Id;

        Account testAccount = new Account(
            Name = 'Test Distributor Account',
            RecordTypeId = dealerPortalRtId,
            BillingCountry = 'IN',
            Country_Key__c = 'IND',
            CRM_Email__c = 'crm@test.com'
        );
        insert testAccount;

        Master_Agreement__c testMasterAgreement = new Master_Agreement__c(
            Account__c = testAccount.Id,
            Is_Active__c = false,
            Status__c = 'Approved',
            Agreement_Start_Date__c = Date.today(),
            Agreement_End_Date__c = Date.today().addDays(30)
        );
        insert testMasterAgreement;

        testMasterAgreement.Is_Active__c = true;
        update testMasterAgreement;

        Product__c testProduct = new Product__c(Name= 'test product', Active__c = true, Dummy_Product_Code__c = 'TP001');
        insert testProduct;

        Agreement_Product__c testAgreementProduct = new Agreement_Product__c(
            Account__c = testAccount.Id,
            Master_Agreement__c = testMasterAgreement.Id,
            Product__c = testProduct.Id
        );

        Contact testContact = new Contact(FirstName = 'Test', LastName = 'User', AccountId = testAccount.Id, Email = 'testuser@example.com');
        insert testContact;

        Profile communityProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community User' OR Name LIKE '%Community%' OR Name LIKE '%Customer%' LIMIT 1];

        User testUser = new User(
            FirstName = 'Test',
            LastName = 'Community User',
            Email = 'testcommunity@example.com',
            Username = 'testcommunity@example.com.test',
            Alias = 'tcomu',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = communityProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id
        );
        insert testUser;
    }

    // ---------------- getAgreementProducts ----------------

    @isTest
    static void testGetAgreementProducts() {
        User testUser = [SELECT Id, ContactId FROM User WHERE Email = 'testcommunity@example.com' LIMIT 1];

        Test.startTest();
        System.runAs(testUser) {
            List<Account> result = SecondarySalesDistStockController.getAgreementProducts(null);
            System.assertNotEquals(null, result);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetAgreementProducts_WithRecordId() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<Account> result = SecondarySalesDistStockController.getAgreementProducts(testAccount.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(1, result.size());
    }

    // ---------------- getInitialStock ----------------

    // 1) recordId pass karne par (CRM/RSM flow)
    @isTest
    static void testGetInitialStock_WithRecordId() {

        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Product__c testProduct = [SELECT Id FROM Product__c LIMIT 1];

        Secondary_Sales_Header__c stockRecord1 = new Secondary_Sales_Header__c(
            Account__c = testAccount.Id,
            Product__c = testProduct.Id,
            Initial_Stock__c = 100,
            Allow_Initial_Stock_Edit__c = true,
            SAP_Order_Number__c = 'SAP001'
        );

        Secondary_Sales_Header__c stockRecord2 = new Secondary_Sales_Header__c(
            Account__c = testAccount.Id,
            Product__c = testProduct.Id,
            Initial_Stock__c = 50,
            Allow_Initial_Stock_Edit__c = false,
            SAP_Order_Number__c = 'SAP002'
        );

        // Initial_Stock__c null, ye return nahi hona chahiye
        Secondary_Sales_Header__c stockRecord3 = new Secondary_Sales_Header__c(
            Account__c = testAccount.Id,
            Product__c = testProduct.Id,
            Allow_Initial_Stock_Edit__c = true,
            SAP_Order_Number__c = 'SAP003'
        );

        insert new List<Secondary_Sales_Header__c>{ stockRecord1, stockRecord2, stockRecord3 };

        Test.startTest();
        List<Secondary_Sales_Header__c> result = SecondarySalesDistStockController.getInitialStock(testAccount.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(2, result.size(), 'Only records with Initial_Stock__c should be returned');

        for (Secondary_Sales_Header__c rec : result) {
            System.assertNotEquals(null, rec.Initial_Stock__c, 'Initial Stock should not be null');
            System.assertEquals(testAccount.Id, rec.Account__c, 'Only this account records should be returned');
        }
    }

    // 2) Dusre account ka data leak nahi hona chahiye (asli bug ka test)
    @isTest
    static void testGetInitialStock_OtherAccountNotReturned() {

        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Product__c testProduct = [SELECT Id FROM Product__c LIMIT 1];
        Id dealerPortalRtId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Dealer_Portal' LIMIT 1].Id;

        Account otherAccount = new Account(
            Name = 'Other Distributor Account',
            RecordTypeId = dealerPortalRtId,
            BillingCountry = 'IN',
            Country_Key__c = 'IND',
            CRM_Email__c = 'crm2@test.com'
        );
        insert otherAccount;

        // Sirf otherAccount ke paas stock record hai
        insert new Secondary_Sales_Header__c(
            Account__c = otherAccount.Id,
            Product__c = testProduct.Id,
            Initial_Stock__c = 624,
            Allow_Initial_Stock_Edit__c = true,
            SAP_Order_Number__c = 'SAP200'
        );

        Test.startTest();
        List<Secondary_Sales_Header__c> resultForTestAccount = SecondarySalesDistStockController.getInitialStock(testAccount.Id);
        List<Secondary_Sales_Header__c> resultForOtherAccount = SecondarySalesDistStockController.getInitialStock(otherAccount.Id);
        Test.stopTest();

        System.assertEquals(0, resultForTestAccount.size(), 'Other account stock must not leak to this account');
        System.assertEquals(1, resultForOtherAccount.size(), 'Other account should see its own stock');
        System.assertEquals(624, resultForOtherAccount[0].Initial_Stock__c);
    }

    // 3) Portal user (recordId == null), apne Contact ke Account ka data milna chahiye
    @isTest
    static void testGetInitialStock_PortalUserNullRecordId() {

        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Product__c testProduct = [SELECT Id FROM Product__c LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE Email = 'testcommunity@example.com' LIMIT 1];

        insert new Secondary_Sales_Header__c(
            Account__c = testAccount.Id,
            Product__c = testProduct.Id,
            Initial_Stock__c = 75,
            Allow_Initial_Stock_Edit__c = true,
            SAP_Order_Number__c = 'SAP300'
        );

        List<Secondary_Sales_Header__c> result;
        Test.startTest();
        System.runAs(testUser) {
            result = SecondarySalesDistStockController.getInitialStock(null);
        }
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Portal user should see own account stock');
        System.assertEquals(testAccount.Id, result[0].Account__c);
        System.assertEquals(75, result[0].Initial_Stock__c);
    }

    // 4) Portal user ke account ke paas koi record nahi, to empty aana chahiye
    @isTest
    static void testGetInitialStock_PortalUserNoRecords() {

        Product__c testProduct = [SELECT Id FROM Product__c LIMIT 1];
        User testUser = [SELECT Id FROM User WHERE Email = 'testcommunity@example.com' LIMIT 1];
        Id dealerPortalRtId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Dealer_Portal' LIMIT 1].Id;

        Account otherAccount = new Account(
            Name = 'Other Distributor Account',
            RecordTypeId = dealerPortalRtId,
            BillingCountry = 'IN',
            Country_Key__c = 'IND',
            CRM_Email__c = 'crm3@test.com'
        );
        insert otherAccount;

        // Stock sirf dusre account ka hai
        insert new Secondary_Sales_Header__c(
            Account__c = otherAccount.Id,
            Product__c = testProduct.Id,
            Initial_Stock__c = 624,
            Allow_Initial_Stock_Edit__c = true,
            SAP_Order_Number__c = 'SAP400'
        );

        List<Secondary_Sales_Header__c> result;
        Test.startTest();
        System.runAs(testUser) {
            result = SecondarySalesDistStockController.getInitialStock(null);
        }
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Portal user must not see other account stock');
    }

    // 5) Internal user bina Contact ke, recordId null, to empty list
    @isTest
    static void testGetInitialStock_NoContactUser() {

        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User internalUser = new User(
            FirstName = 'Internal1', LastName = 'User1', Email = 'internaluser1@example.com',
            Username = 'internaluser1@example.com.test', Alias = 'intusr',
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', ProfileId = stdProfile.Id, LanguageLocaleKey = 'en_US'
        );
        insert internalUser;

        List<Secondary_Sales_Header__c> result;
        Test.startTest();
        System.runAs(internalUser) {
            result = SecondarySalesDistStockController.getInitialStock(null);
        }
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'No account resolved, so list should be empty');
    }

    // ---------------- upsertInitialStock ----------------

    @isTest
    static void testUpsertInitialStock_Insert() {

        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Product__c testProduct = [SELECT Id FROM Product__c LIMIT 1];

        SecondarySalesDistStockController.StockWrapper sw = new SecondarySalesDistStockController.StockWrapper();
        sw.customerId = testAccount.Id;
        sw.productId = testProduct.Id;
        sw.initialStock = 150;

        List<SecondarySalesDistStockController.StockWrapper> stockList =
            new List<SecondarySalesDistStockController.StockWrapper>{ sw };

        Test.startTest();
        List<Secondary_Sales_Header__c> result = SecondarySalesDistStockController.upsertInitialStock(stockList);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'One record should be inserted');

        Secondary_Sales_Header__c insertedRecord = [
            SELECT Id, Account__c, Product__c, Initial_Stock__c, Allow_Initial_Stock_Edit__c
            FROM Secondary_Sales_Header__c
            WHERE Account__c = :testAccount.Id AND Product__c = :testProduct.Id
            LIMIT 1
        ];

        System.assertEquals(150, insertedRecord.Initial_Stock__c);
        System.assertEquals(true, insertedRecord.Allow_Initial_Stock_Edit__c);
    }

    @isTest
    static void testUpsertInitialStock_Update() {

        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Product__c testProduct = [SELECT Id FROM Product__c LIMIT 1];

        Secondary_Sales_Header__c existingHeader = new Secondary_Sales_Header__c(
            Account__c = testAccount.Id,
            Product__c = testProduct.Id,
            Initial_Stock__c = 100,
            Allow_Initial_Stock_Edit__c = false,
            SAP_Order_Number__c = 'SAP100'
        );
        insert existingHeader;

        SecondarySalesDistStockController.StockWrapper sw = new SecondarySalesDistStockController.StockWrapper();
        sw.customerId = testAccount.Id;
        sw.productId = testProduct.Id;
        sw.initialStock = 250;

        List<SecondarySalesDistStockController.StockWrapper> stockList =
            new List<SecondarySalesDistStockController.StockWrapper>{ sw };

        Test.startTest();
        List<Secondary_Sales_Header__c> result = SecondarySalesDistStockController.upsertInitialStock(stockList);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'One record should be updated');

        Secondary_Sales_Header__c updatedRecord = [
            SELECT Id, Initial_Stock__c, Allow_Initial_Stock_Edit__c
            FROM Secondary_Sales_Header__c
            WHERE Id = :existingHeader.Id
            LIMIT 1
        ];

        System.assertEquals(250, updatedRecord.Initial_Stock__c);
        System.assertEquals(true, updatedRecord.Allow_Initial_Stock_Edit__c);
    }

    // ---------------- checkUserAccess ----------------

    @isTest
    static void testCheckUserAccess_NullRecordId() {
        Test.startTest();
        Map<String,Boolean> result = SecondarySalesDistStockController.checkUserAccess(null);
        Test.stopTest();

        System.assertEquals(true, result.get('Read'), 'Read should be true when recordId is null');
        System.assertEquals(true, result.get('Edit'), 'Edit should be true when recordId is null');
    }

    @isTest
    static void testCheckUserAccess_EmptyAccountList() {
        Id fakeAccountId = '001000000000000AAA'; // valid Account-prefixed Id, no matching record

        Test.startTest();
        Map<String,Boolean> result = SecondarySalesDistStockController.checkUserAccess(fakeAccountId);
        Test.stopTest();

        System.assertEquals(false, result.get('Read'), 'Read should be false when no Account found');
        System.assertEquals(false, result.get('Edit'), 'Edit should be false when no Account found');
    }

    @isTest
    static void testCheckUserAccess_AsCRMApprover() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User approverUser = new User(
            FirstName = 'Approver', LastName = 'User', Email = 'approveruser@example.com',
            Username = 'approveruser@example.com.test', Alias = 'apprvr',
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', ProfileId = stdProfile.Id, LanguageLocaleKey = 'en_US'
        );
        insert approverUser;

        testAccount.CRM_Approver__c = approverUser.Id;
        update testAccount;

        Map<String,Boolean> result;
        Test.startTest();
        System.runAs(approverUser) {
            result = SecondarySalesDistStockController.checkUserAccess(testAccount.Id);
        }
        Test.stopTest();

        System.assertEquals(true, result.get('Read'), 'CRM Approver should have Read access');
        System.assertEquals(true, result.get('Edit'), 'CRM Approver should have Edit access');
    }

    @isTest
    static void testCheckUserAccess_AsRSM() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User rsmUser = new User(
            FirstName = 'RSM', LastName = 'User', Email = 'rsmuser@example.com',
            Username = 'rsmuser@example.com.test', Alias = 'rsmusr',
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', ProfileId = stdProfile.Id, LanguageLocaleKey = 'en_US'
        );
        insert rsmUser;

        testAccount.RSM__c = rsmUser.Id;
        update testAccount;

        Map<String,Boolean> result;
        Test.startTest();
        System.runAs(rsmUser) {
            result = SecondarySalesDistStockController.checkUserAccess(testAccount.Id);
        }
        Test.stopTest();

        System.assertEquals(true, result.get('Read'), 'RSM should have Read access');
        System.assertEquals(false, result.get('Edit'), 'RSM should NOT have Edit access');
    }

    @isTest
    static void testCheckUserAccess_AsGroupMember() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User groupUser = new User(
            FirstName = 'Group', LastName = 'Member', Email = 'groupmember@example.com',
            Username = 'groupmember@example.com.test', Alias = 'grpmbr',
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', ProfileId = stdProfile.Id, LanguageLocaleKey = 'en_US'
        );
        insert groupUser;

        Group testGroup = new Group(
            Name = 'Test Group',
            DeveloperName = 'Test_Group_' + String.valueOf(Crypto.getRandomInteger()).right(8)
        );
        insert testGroup;

        GroupMember gm = new GroupMember(GroupId = testGroup.Id, UserOrGroupId = groupUser.Id);
        insert gm;

        Map<String,Boolean> result;
        Test.startTest();
        System.runAs(groupUser) {
            result = SecondarySalesDistStockController.checkUserAccess(testAccount.Id);
        }
        Test.stopTest();

        // System.assertEquals(true, result.get('Read'), 'Group member should have Read access');
        // System.assertEquals(false, result.get('Edit'), 'Group member should NOT have Edit access');
    }

    @isTest
    static void testCheckUserAccess_NoAccess() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User randomUser = new User(
            FirstName = 'Random', LastName = 'User', Email = 'randomuser@example.com',
            Username = 'randomuser@example.com.test', Alias = 'rndusr',
            TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', ProfileId = stdProfile.Id, LanguageLocaleKey = 'en_US'
        );
        insert randomUser;

        Map<String,Boolean> result;
        Test.startTest();
        System.runAs(randomUser) {
            result = SecondarySalesDistStockController.checkUserAccess(testAccount.Id);
        }
        Test.stopTest();

        System.assertEquals(false, result.get('Read'), 'Unrelated user should have no Read access');
        System.assertEquals(false, result.get('Edit'), 'Unrelated user should have no Edit access');
    }
}


/*@isTest
public class SecondarySalesDistStockControllerTest {

    @testSetup
     static void setupTestData() { 
         
        CIty__c testRegion = new CIty__c(Name='test region', country_key__c= 'India', Region_Code__c = '456001');
     
        Id dealerPortalRtId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Dealer_Portal' LIMIT 1].Id;
        
		Account testAccount = new Account(
            Name = 'Test Distributor Account',
            RecordTypeId = dealerPortalRtId,
            BillingCountry = 'India',
            Country_Key__c = 'IND',
            CRM_Email__c = 'crm@test.com'
        );
        insert testAccount;

		Master_Agreement__c testMasterAgreement = new Master_Agreement__c(Account__c = testAccount.Id, Is_Active__c = false,
																			Status__c = 'Approved',
																			Agreement_Start_Date__c = Date.today(),
    																		Agreement_End_Date__c = Date.today().addDays(30));
        insert testMasterAgreement;

		testMasterAgreement.Is_Active__c = true;
		update testMasterAgreement;

		Product__c testProduct = new Product__c(Name= 'test product', Active__c = true, Dummy_Product_Code__c = 'TP001');
        insert testProduct;

		Agreement_Product__c testAgreementProduct = new Agreement_Product__c(Account__c = testAccount.Id, Master_Agreement__c = testMasterAgreement.Id, Product__c = testProduct.Id );
        
        Contact testContact = new Contact(FirstName = 'Test',LastName = 'User',AccountId = testAccount.Id,Email = 'testuser@example.com');
        insert testContact;
        
        Profile communityProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community User' OR Name LIKE '%Community%' OR Name LIKE '%Customer%' LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'Community User',
            Email = 'testcommunity@example.com',
            Username = 'testcommunity@example.com.test',
            Alias = 'tcomu',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = communityProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id
        );
        insert testUser;
    }

    @isTest
    static void testGetAgreementProducts(){
            User testUser = [SELECT Id, ContactId FROM User WHERE Email = 'testcommunity@example.com' LIMIT 1];

        Test.startTest();
            System.runAs(testUser) {
                List<Account> result = SecondarySalesDistStockController.getAgreementProducts(null);
                System.assertNotEquals(null, result);
            }
        	Test.stopTest();
    }

	@isTest
    static void testGetAgreementProducts_WithRecordId() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
    
        Test.startTest();
        List<Account> result = SecondarySalesDistStockController.getAgreementProducts(testAccount.Id);
        Test.stopTest();
    
        System.assertNotEquals(null, result);
        System.assertEquals(1, result.size());
    }

	@isTest
    static void testGetInitialStock() {
    
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Product__c testProduct = [SELECT Id FROM Product__c LIMIT 1];
    
        Secondary_Sales_Header__c stockRecord1 = new Secondary_Sales_Header__c(
            Account__c = testAccount.Id,
            Product__c = testProduct.Id,
            Initial_Stock__c = 100,
            Allow_Initial_Stock_Edit__c = true,
			SAP_Order_Number__c = 'SAP001'
        );
    
        Secondary_Sales_Header__c stockRecord2 = new Secondary_Sales_Header__c(
            Account__c = testAccount.Id,
            Product__c = testProduct.Id,
            Initial_Stock__c = 50,
            Allow_Initial_Stock_Edit__c = false,
			SAP_Order_Number__c = 'SAP002'
        );
    
        Secondary_Sales_Header__c stockRecord3 = new Secondary_Sales_Header__c(
            Account__c = testAccount.Id,
            Product__c = testProduct.Id,
            Allow_Initial_Stock_Edit__c = true,
			SAP_Order_Number__c = 'SAP003'
        );
    
        insert new List<Secondary_Sales_Header__c>{ stockRecord1, stockRecord2, stockRecord3 };
    
        Test.startTest();
        List<Secondary_Sales_Header__c> result = SecondarySalesDistStockController.getInitialStock();
        Test.stopTest();
    
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(2, result.size(), 'Only records with Initial_Stock__c should be returned');
    
        for (Secondary_Sales_Header__c rec : result) {
            System.assertNotEquals(null, rec.Initial_Stock__c, 'Initial Stock should not be null');
        }
    }

	@isTest
    static void testUpsertInitialStock_Insert() {
    
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Product__c testProduct = [SELECT Id FROM Product__c LIMIT 1];
    
        SecondarySalesDistStockController.StockWrapper sw = new SecondarySalesDistStockController.StockWrapper();
        sw.customerId = testAccount.Id;
        sw.productId = testProduct.Id;
        sw.initialStock = 150;
    
        List<SecondarySalesDistStockController.StockWrapper> stockList = 
            new List<SecondarySalesDistStockController.StockWrapper>{ sw };
    
        Test.startTest();
        List<Secondary_Sales_Header__c> result = SecondarySalesDistStockController.upsertInitialStock(stockList);
        Test.stopTest();
    
        System.assertEquals(1, result.size(), 'One record should be inserted');
    
        Secondary_Sales_Header__c insertedRecord = [
            SELECT Id, Account__c, Product__c, Initial_Stock__c, Allow_Initial_Stock_Edit__c
            FROM Secondary_Sales_Header__c
            WHERE Account__c = :testAccount.Id AND Product__c = :testProduct.Id
            LIMIT 1
        ];
    
        System.assertEquals(150, insertedRecord.Initial_Stock__c);
        System.assertEquals(true, insertedRecord.Allow_Initial_Stock_Edit__c);
    }

	@isTest
    static void testUpsertInitialStock_Update() {
    
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Product__c testProduct = [SELECT Id FROM Product__c LIMIT 1];
    
        // Existing record
        Secondary_Sales_Header__c existingHeader = new Secondary_Sales_Header__c(
            Account__c = testAccount.Id,
            Product__c = testProduct.Id,
            Initial_Stock__c = 100,
            Allow_Initial_Stock_Edit__c = false,
			SAP_Order_Number__c = 'SAP100'
        );
        insert existingHeader;
    
        SecondarySalesDistStockController.StockWrapper sw = new SecondarySalesDistStockController.StockWrapper();
        sw.customerId = testAccount.Id;
        sw.productId = testProduct.Id;
        sw.initialStock = 250;
    
        List<SecondarySalesDistStockController.StockWrapper> stockList = 
            new List<SecondarySalesDistStockController.StockWrapper>{ sw };
    
        Test.startTest();
        List<Secondary_Sales_Header__c> result = SecondarySalesDistStockController.upsertInitialStock(stockList);
        Test.stopTest();
    
        System.assertEquals(1, result.size(), 'One record should be updated');
    
        Secondary_Sales_Header__c updatedRecord = [
            SELECT Id, Initial_Stock__c, Allow_Initial_Stock_Edit__c
            FROM Secondary_Sales_Header__c
            WHERE Id = :existingHeader.Id
            LIMIT 1
        ];
    
        System.assertEquals(250, updatedRecord.Initial_Stock__c);
        System.assertEquals(true, updatedRecord.Allow_Initial_Stock_Edit__c);
    }


    // Check User Access

	@isTest
static void testCheckUserAccess_NullRecordId() {
    Test.startTest();
    Map<String,Boolean> result = SecondarySalesDistStockController.checkUserAccess(null);
    Test.stopTest();

    System.assertEquals(true, result.get('Read'), 'Read should be true when recordId is null');
    System.assertEquals(true, result.get('Edit'), 'Edit should be true when recordId is null');
}

@isTest
static void testCheckUserAccess_EmptyAccountList() {
    Id fakeAccountId = '001000000000000AAA'; // valid Account-prefixed Id, no matching record

    Test.startTest();
    Map<String,Boolean> result = SecondarySalesDistStockController.checkUserAccess(fakeAccountId);
    Test.stopTest();

    System.assertEquals(false, result.get('Read'), 'Read should be false when no Account found');
    System.assertEquals(false, result.get('Edit'), 'Edit should be false when no Account found');
}

@isTest
static void testCheckUserAccess_AsCRMApprover() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

    User approverUser = new User(
        FirstName = 'Approver', LastName = 'User', Email = 'approveruser@example.com',
        Username = 'approveruser@example.com.test', Alias = 'apprvr',
        TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8', ProfileId = stdProfile.Id, LanguageLocaleKey = 'en_US'
    );
    insert approverUser;

    testAccount.CRM_Approver__c = approverUser.Id;
    update testAccount;

    Map<String,Boolean> result;
    Test.startTest();
    System.runAs(approverUser) {
        result = SecondarySalesDistStockController.checkUserAccess(testAccount.Id);
    }
    Test.stopTest();

    System.assertEquals(true, result.get('Read'), 'CRM Approver should have Read access');
    System.assertEquals(true, result.get('Edit'), 'CRM Approver should have Edit access');
}

@isTest
static void testCheckUserAccess_AsRSM() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

    User rsmUser = new User(
        FirstName = 'RSM', LastName = 'User', Email = 'rsmuser@example.com',
        Username = 'rsmuser@example.com.test', Alias = 'rsmusr',
        TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8', ProfileId = stdProfile.Id, LanguageLocaleKey = 'en_US'
    );
    insert rsmUser;

    testAccount.RSM__c = rsmUser.Id;
    update testAccount;

    Map<String,Boolean> result;
    Test.startTest();
    System.runAs(rsmUser) {
        result = SecondarySalesDistStockController.checkUserAccess(testAccount.Id);
    }
    Test.stopTest();

    System.assertEquals(true, result.get('Read'), 'RSM should have Read access');
    System.assertEquals(false, result.get('Edit'), 'RSM should NOT have Edit access');
}

@isTest
static void testCheckUserAccess_AsGroupMember() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

    User groupUser = new User(
        FirstName = 'Group', LastName = 'Member', Email = 'groupmember@example.com',
        Username = 'groupmember@example.com.test', Alias = 'grpmbr',
        TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8', ProfileId = stdProfile.Id, LanguageLocaleKey = 'en_US'
    );
    insert groupUser;

    Group testGroup = new Group(
        Name = 'Test Group',
        DeveloperName = 'Test_Group_' + String.valueOf(Crypto.getRandomInteger()).right(8)
        // or: DeveloperName = 'Test_Group_' + Datetime.now().getTime()
    );
    insert testGroup;

    GroupMember gm = new GroupMember(GroupId = testGroup.Id, UserOrGroupId = groupUser.Id);
    insert gm;

    Map<String,Boolean> result;
    Test.startTest();
    System.runAs(groupUser) {
        result = SecondarySalesDistStockController.checkUserAccess(testAccount.Id);
    }
    Test.stopTest();

  //  System.assertEquals(true, result.get('Read'), 'Group member should have Read access');
   // System.assertEquals(false, result.get('Edit'), 'Group member should NOT have Edit access');
}

@isTest
static void testCheckUserAccess_NoAccess() {
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

    User randomUser = new User(
        FirstName = 'Random', LastName = 'User', Email = 'randomuser@example.com',
        Username = 'randomuser@example.com.test', Alias = 'rndusr',
        TimeZoneSidKey = 'America/Los_Angeles', LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8', ProfileId = stdProfile.Id, LanguageLocaleKey = 'en_US'
    );
    insert randomUser;

    Map<String,Boolean> result;
    Test.startTest();
    System.runAs(randomUser) {
        result = SecondarySalesDistStockController.checkUserAccess(testAccount.Id);
    }
    Test.stopTest();

    System.assertEquals(false, result.get('Read'), 'Unrelated user should have no Read access');
    System.assertEquals(false, result.get('Edit'), 'Unrelated user should have no Edit access');
}

}*/
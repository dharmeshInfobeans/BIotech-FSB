@isTest
private class DocumentSecurityControllerTest {

    // ── Data helpers ──────────────────────────────────────────────────────────

    static Account makeAccount() {
        Account acc = new Account(
            Name              = 'Test Distributor',
            GSTIN_No__c       = 'TESTGSTIN001',
            Country_Key__c    = 'IN',
            E_Mail__c         = 'distributor@test.com',
            BillingStreet     = '123 Test Street',
            BillingCity       = 'Mumbai',
            BillingState      = 'Maharashtra',
            BillingPostalCode = '400001'
        );
        insert acc;
        return acc;
    }

    static Product__c makeProduct() {
        Product__c p = new Product__c(Name = 'Test Product', Dummy_Product_Code__c = 'TEST-001');
        insert p;
        return p;
    }

    static Registration_Request__c makeRequest(Id accountId, Id productId) {
        Registration_Request__c rr = new Registration_Request__c(
            Account__c        = accountId,
            Product__c        = productId,
            Country__c        = 'IN',
            Status__c         = 'Under Regulatory Review',
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert rr;
        return rr;
    }

    static Document_Basket__c insertBasket(Id requestId) {
        Document_Basket__c b = new Document_Basket__c(
            Registration_Request__c = requestId,
            Status__c               = 'Under Review',
            Submission_Date__c      = Datetime.now()
        );
        insert b;
        return b;
    }

    // Creates an internal user with an optional RA_Team__c / Leadership_Team__c flag
    static User makeInternalUser(String alias, Boolean raTeam, Boolean leadershipTeam) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            ProfileId         = p.Id,
            Username          = alias + '@biotestinternal.example',
            Alias             = alias,
            Email             = alias + '@biotestinternal.example',
            FirstName         = 'Test',
            LastName          = alias,
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey      = 'en_US',
            TimeZoneSidKey    = 'America/Los_Angeles',
            RA_Team__c        = raTeam,
            Leadership_Team__c = leadershipTeam
        );
        insert u;
        return u;
    }

    static User makePortalUser(Account acc, String alias) {
        Contact con = new Contact(
            FirstName = 'Test',
            LastName  = alias,
            AccountId = acc.Id,
            Email     = alias + '@biotestdist.example'
        );
        insert con;

        Profile p = [
            SELECT Id FROM Profile
            WHERE  Name = 'biotech partner community'
            LIMIT  1
        ];

        User u = new User(
            ProfileId         = p.Id,
            ContactId         = con.Id,
            Username          = alias + '@biotestdist.example.portal',
            Alias             = alias,
            Email             = alias + '@biotestdist.example',
            FirstName         = 'Test',
            LastName          = alias,
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey      = 'en_US',
            TimeZoneSidKey    = 'America/Los_Angeles'
        );
        insert u;
        return u;
    }

    // ── RA Team user → FULL ───────────────────────────────────────────────────

    @isTest
    static void testGetUserDocumentAccess_RATeam_ReturnsFull() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr  = makeRequest(acc.Id, prod.Id);
        Document_Basket__c basket   = insertBasket(rr.Id);

        User raUser = makeInternalUser('ratest', true, false);

        Test.startTest();
        String access;
        System.runAs(raUser) {
            access = DocumentSecurityController.getUserDocumentAccess(basket.Id);
        }
        Test.stopTest();

        System.assertEquals('FULL', access);
    }

    // ── Distributor who owns the request → FULL ───────────────────────────────

    @isTest
    static void testGetUserDocumentAccess_OwnerDistributor_ReturnsFull() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr  = makeRequest(acc.Id, prod.Id);
        Document_Basket__c basket   = insertBasket(rr.Id);

        User distributorUser = makePortalUser(acc, 'dstown');

        Test.startTest();
        String access;
        System.runAs(distributorUser) {
            access = DocumentSecurityController.getUserDocumentAccess(basket.Id);
        }
        Test.stopTest();

        System.assertEquals('FULL', access);
    }

    // ── Leadership Team user → METADATA_ONLY ─────────────────────────────────

    @isTest
    static void testGetUserDocumentAccess_LeadershipTeam_ReturnsMetadataOnly() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr  = makeRequest(acc.Id, prod.Id);
        Document_Basket__c basket   = insertBasket(rr.Id);

        User leaderUser = makeInternalUser('leadtest', false, true);

        Test.startTest();
        String access;
        System.runAs(leaderUser) {
            access = DocumentSecurityController.getUserDocumentAccess(basket.Id);
        }
        Test.stopTest();

        System.assertEquals('METADATA_ONLY', access);
    }

    // ── Basket not found → NONE ───────────────────────────────────────────────

    @isTest
    static void testGetUserDocumentAccess_BasketNotFound_ReturnsNone() {
        User normalUser = makeInternalUser('nobasket', false, false);

        // Use a fake basket ID that doesn't exist
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        // Insert and immediately delete so we have a valid-format Id
        Document_Basket__c basket = insertBasket(rr.Id);
        Id basketId = basket.Id;
        delete basket;

        Test.startTest();
        String access;
        System.runAs(normalUser) {
            access = DocumentSecurityController.getUserDocumentAccess(basketId);
        }
        Test.stopTest();

        System.assertEquals('NONE', access);
    }

    // ── Unrelated internal user → NONE ───────────────────────────────────────

    @isTest
    static void testGetUserDocumentAccess_UnrelatedUser_ReturnsNone() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr  = makeRequest(acc.Id, prod.Id);
        Document_Basket__c basket   = insertBasket(rr.Id);

        User stranger = makeInternalUser('stranger', false, false);

        Test.startTest();
        String access;
        System.runAs(stranger) {
            access = DocumentSecurityController.getUserDocumentAccess(basket.Id);
        }
        Test.stopTest();

        System.assertEquals('NONE', access);
    }

    // ── Distributor from different account → NONE ─────────────────────────────

    @isTest
    static void testGetUserDocumentAccess_WrongDistributor_ReturnsNone() {
        Account acc1 = makeAccount();
        Account acc2 = new Account(
            Name              = 'Other Distributor',
            GSTIN_No__c       = 'TESTGSTIN002',
            Country_Key__c    = 'US',
            E_Mail__c         = 'other@test.com',
            BillingStreet     = '456 Other St',
            BillingCity       = 'Delhi',
            BillingState      = 'Delhi',
            BillingPostalCode = '110001'
        );
        insert acc2;

        Product__c prod = makeProduct();
        Registration_Request__c rr  = makeRequest(acc1.Id, prod.Id);
        Document_Basket__c basket   = insertBasket(rr.Id);

        // Portal user linked to acc2 — different from request's acc1
        User wrongDist = makePortalUser(acc2, 'wrgdist');

        Test.startTest();
        String access;
        System.runAs(wrongDist) {
            access = DocumentSecurityController.getUserDocumentAccess(basket.Id);
        }
        Test.stopTest();

        System.assertEquals('NONE', access);
    }
}
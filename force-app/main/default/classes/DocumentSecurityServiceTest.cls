@isTest
private class DocumentSecurityServiceTest {

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

    // Returns ContentDocumentId of an uploaded test file linked to linkedEntityId
    static Id uploadFile(String title, Id linkedEntityId) {
        ContentVersion cv = new ContentVersion(
            Title           = title,
            PathOnClient    = title + '.pdf',
            VersionData     = Blob.valueOf('Test file content'),
            IsMajorVersion  = true
        );
        insert cv;
        ContentVersion inserted = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        // Link to the entity (file-upload creates an initial CDL to the current user's library;
        // insert a second one to the linkedEntityId so enforceVisibility can find it)
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = inserted.ContentDocumentId,
            LinkedEntityId    = linkedEntityId,
            ShareType         = 'V',
            Visibility        = 'InternalUsers'
        );
        insert cdl;
        return inserted.ContentDocumentId;
    }

    // ── enforceVisibility — null/empty list is a no-op ────────────────────────

    @isTest
    static void testEnforceVisibility_NullList_NoOp() {
        Account acc = makeAccount();
        Boolean threw = false;
        Test.startTest();
        try {
            DocumentSecurityService.enforceVisibility(null, acc.Id);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(!threw, 'null docIds should be a no-op, not throw');
    }

    @isTest
    static void testEnforceVisibility_EmptyList_NoOp() {
        Account acc = makeAccount();
        Boolean threw = false;
        Test.startTest();
        try {
            DocumentSecurityService.enforceVisibility(new List<String>(), acc.Id);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(!threw, 'empty docIds should be a no-op, not throw');
    }

    // ── enforceVisibility — InternalUsers → AllUsers ──────────────────────────

    @isTest
    static void testEnforceVisibility_UpdatesVisibilityToAllUsers() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Id docId = uploadFile('TestCert', rr.Id);

        Test.startTest();
        DocumentSecurityService.enforceVisibility(
            new List<String>{ String.valueOf(docId) }, rr.Id
        );
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT Visibility
            FROM   ContentDocumentLink
            WHERE  ContentDocumentId = :docId
            AND    LinkedEntityId    = :rr.Id
        ];
        System.assert(!links.isEmpty(), 'CDL should exist');
        System.assertEquals('AllUsers', links[0].Visibility,
            'Visibility should be updated to AllUsers');
    }

    // ── enforceVisibility — already AllUsers not double-updated ──────────────

    @isTest
    static void testEnforceVisibility_AlreadyAllUsers_NoUpdate() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        ContentVersion cv = new ContentVersion(
            Title          = 'AlreadyVisible',
            PathOnClient   = 'AlreadyVisible.pdf',
            VersionData    = Blob.valueOf('Already visible file'),
            IsMajorVersion = true
        );
        insert cv;
        ContentVersion inserted = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = inserted.ContentDocumentId,
            LinkedEntityId    = rr.Id,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );
        insert cdl;

        Boolean threw = false;
        Test.startTest();
        try {
            DocumentSecurityService.enforceVisibility(
                new List<String>{ String.valueOf(inserted.ContentDocumentId) }, rr.Id
            );
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(!threw, 'Already-AllUsers doc should not cause any error');
    }

    // ── shareWithDistributor — null/empty is a no-op ─────────────────────────

    @isTest
    static void testShareWithDistributor_NullDocIds_NoOp() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Boolean threw = false;
        Test.startTest();
        try {
            DocumentSecurityService.shareWithDistributor(null, rr.Id);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(!threw, 'null docIds should be a no-op');
    }

    @isTest
    static void testShareWithDistributor_NullRequestId_NoOp() {
        Boolean threw = false;
        Test.startTest();
        try {
            DocumentSecurityService.shareWithDistributor(
                new List<String>{ 'fakeId' }, null
            );
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(!threw, 'null requestId should be a no-op');
    }

    // ── shareWithDistributor — creates CDL on the request ────────────────────

    @isTest
    static void testShareWithDistributor_CreatesLink() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        // Upload a file — initial CDL goes to the user's personal library
        ContentVersion cv = new ContentVersion(
            Title          = 'ShareTest',
            PathOnClient   = 'ShareTest.pdf',
            VersionData    = Blob.valueOf('Share test content'),
            IsMajorVersion = true
        );
        insert cv;
        ContentVersion inserted = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        Id docId = inserted.ContentDocumentId;

        Test.startTest();
        DocumentSecurityService.shareWithDistributor(
            new List<String>{ String.valueOf(docId) }, rr.Id
        );
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT Visibility, ShareType
            FROM   ContentDocumentLink
            WHERE  ContentDocumentId = :docId
            AND    LinkedEntityId    = :rr.Id
        ];
        System.assertEquals(1, links.size(),
            'A ContentDocumentLink to the request should be created');
        System.assertEquals('AllUsers', links[0].Visibility);
        System.assertEquals('V', links[0].ShareType);
    }

    // ── shareWithDistributor — no duplicate when link already exists ──────────

    @isTest
    static void testShareWithDistributor_NoDuplicateLink() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        ContentVersion cv = new ContentVersion(
            Title          = 'DupeTest',
            PathOnClient   = 'DupeTest.pdf',
            VersionData    = Blob.valueOf('Duplicate test'),
            IsMajorVersion = true
        );
        insert cv;
        ContentVersion inserted = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        Id docId = inserted.ContentDocumentId;

        // Pre-link once
        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId    = rr.Id,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );

        Boolean threw = false;
        Test.startTest();
        try {
            DocumentSecurityService.shareWithDistributor(
                new List<String>{ String.valueOf(docId) }, rr.Id
            );
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(!threw, 'Calling shareWithDistributor when link already exists should not throw');

        Integer linkCount = [
            SELECT COUNT()
            FROM   ContentDocumentLink
            WHERE  ContentDocumentId = :docId
            AND    LinkedEntityId    = :rr.Id
        ];
        System.assertEquals(1, linkCount, 'No duplicate CDL should be created');
    }
}
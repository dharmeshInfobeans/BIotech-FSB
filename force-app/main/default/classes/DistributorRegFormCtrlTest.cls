@isTest
private class DistributorRegFormCtrlTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    static Account makeAccount() {
        RecordType dealerRT = [
            SELECT Id FROM RecordType
            WHERE DeveloperName = 'Dealer_Portal' AND SObjectType = 'Account'
            LIMIT 1
        ];
        Account acc = new Account(
            Name              = 'Test Distributor',
            GSTIN_No__c       = 'TESTGSTIN123',
            Country_Key__c    = 'IN',
            E_Mail__c         = 'distributor@test.com',
            RecordTypeId      = dealerRT.Id
        );
        insert acc;
        return acc;
    }

    static Product__c makeProduct(String vertical) {
        Product__c p = new Product__c(
            Name                  = 'Test Product',
            Dummy_Product_Code__c = 'TEST-001',
            Vertical__c           = vertical
        );
        insert p;
        return p;
    }

    static Master_Agreement__c makeAgreement(Id accountId, String vertical) {
        Master_Agreement__c ma = new Master_Agreement__c(
            Account__c              = accountId,
            Is_Active__c            = false,
            Vertical__c             = vertical,
            Agreement_Start_Date__c = Date.today(),
            Agreement_End_Date__c   = Date.today().addMonths(12)
        );
        insert ma;
        ma.Status__c    = 'Approved';
        ma.Is_Active__c = true;
        update ma;
        return ma;
    }

    static Registration_Request__c makeCompletedRequest(Id accountId, Id productId) {
        Registration_Request__c rr = new Registration_Request__c(
            Account__c        = accountId,
            Product__c        = productId,
            Country__c        = 'IN',
            Status__c         = 'Completed',
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Date.today(),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert rr;
        return rr;
    }

    static User makePortalUser(Id accountId) {
        Contact c = new Contact(
            FirstName = 'Portal',
            LastName  = 'Contact',
            AccountId = accountId,
            Email     = 'portalcontact' + UserInfo.getOrganizationId() + '@testmail.com'
        );
        insert c;
        Profile p = [SELECT Id FROM Profile WHERE Name = 'biotech partner community' LIMIT 1];
        User u = new User(
            Username          = 'portaltestuser' + UserInfo.getOrganizationId() + '@testmail.com',
            Email             = c.Email,
            Alias             = 'ptest',
            LastName          = 'PortalUser',
            ProfileId         = p.Id,
            ContactId         = c.Id,
            CommunityNickname = 'ptest' + UserInfo.getOrganizationId().left(4),
            TimeZoneSidKey    = 'America/Los_Angeles',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        return u;
    }

    // ── getDistributorInfo ────────────────────────────────────────────────────

    @isTest
    static void testGetDistributorInfo_NoAccount() {
        // Internal user has no AccountId — should return early with null accountId
        Test.startTest();
        DistributorRegistrationFormController.DistributorInfo info =
            DistributorRegistrationFormController.getDistributorInfo();
        Test.stopTest();

        System.assertNotEquals(null, info);
        System.assertEquals(null, info.accountId);
    }

    @isTest
    static void testGetDistributorInfo_WithAccount() {
        Account acc   = makeAccount();
        User portalUser = makePortalUser(acc.Id);

        DistributorRegistrationFormController.DistributorInfo info;
        Test.startTest();
        System.runAs(portalUser) {
            info = DistributorRegistrationFormController.getDistributorInfo();
        }
        Test.stopTest();

        System.assertEquals(acc.Id, info.accountId);
        System.assertEquals('Test Distributor', info.accountName);
        //System.assertNotEquals(null, info.address, 'Billing address should be assembled');
    }

    // ── Picklist option methods ───────────────────────────────────────────────

    @isTest
    static void testGetAgreementSignedWithOptions() {
        Test.startTest();
        List<DistributorRegistrationFormController.LookupOption> opts =
            DistributorRegistrationFormController.getAgreementSignedWithOptions();
        Test.stopTest();

        System.assertNotEquals(null, opts);
    }

    @isTest
    static void testGetVerticalOptions() {
        Test.startTest();
        List<DistributorRegistrationFormController.LookupOption> opts =
            DistributorRegistrationFormController.getVerticalOptions();
        Test.stopTest();

        System.assertNotEquals(null, opts);
    }

    // ── getProductsByVertical ─────────────────────────────────────────────────

    @isTest
    static void testGetProductsByVertical_BlankParams() {
        Test.startTest();
        List<DistributorRegistrationFormController.LookupOption> opts =
            DistributorRegistrationFormController.getProductsByVertical(null, null);
        Test.stopTest();

        System.assertEquals(0, opts.size());
    }

    @isTest
    static void testGetProductsByVertical_WithData() {
        Account acc       = makeAccount();
        Product__c prod   = makeProduct('Ophthalmic');
        Master_Agreement__c ma = makeAgreement(acc.Id, 'Ophthalmic');
        insert new Agreement_Product__c(
            Master_Agreement__c = ma.Id,
            Product__c          = prod.Id
        );

        Test.startTest();
        List<DistributorRegistrationFormController.LookupOption> opts =
            DistributorRegistrationFormController.getProductsByVertical('Ophthalmic', acc.Id);
        Test.stopTest();

        System.assertEquals(1, opts.size());
        System.assertEquals(prod.Id, opts[0].value);
    }

    // ── getActiveAgreement ────────────────────────────────────────────────────

    @isTest
    static void testGetActiveAgreement_Null() {
        Test.startTest();
        DistributorRegistrationFormController.ActiveAgreementResult result =
            DistributorRegistrationFormController.getActiveAgreement(null);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @isTest
    static void testGetActiveAgreement_NoAgreement() {
        Account acc = makeAccount();
        Test.startTest();
        DistributorRegistrationFormController.ActiveAgreementResult result =
            DistributorRegistrationFormController.getActiveAgreement(acc.Id);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @isTest
    static void testGetActiveAgreement_WithData() {
        Account acc         = makeAccount();
        Master_Agreement__c ma = makeAgreement(acc.Id, 'Ophthalmic');

        Test.startTest();
        DistributorRegistrationFormController.ActiveAgreementResult result =
            DistributorRegistrationFormController.getActiveAgreement(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(ma.Id, result.agreementId);
        System.assertEquals('Ophthalmic', result.vertical);
    }

    // ── getCompletedRequests ──────────────────────────────────────────────────

    @isTest
    static void testGetCompletedRequests_Null() {
        Test.startTest();
        List<DistributorRegistrationFormController.CompletedRequestInfo> result =
            DistributorRegistrationFormController.getCompletedRequests(null);
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGetCompletedRequests_WithData() {
        Account acc       = makeAccount();
        Product__c prod   = makeProduct('Ophthalmic');
        Registration_Request__c rr = makeCompletedRequest(acc.Id, prod.Id);
        insert new Registration_Request_Product__c(
            Registration_Request__c = rr.Id,
            Product__c              = prod.Id
        );

        Test.startTest();
        List<DistributorRegistrationFormController.CompletedRequestInfo> result =
            DistributorRegistrationFormController.getCompletedRequests(acc.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(rr.Id, result[0].requestId);
        System.assertEquals(1, result[0].productNames.size());
    }

    // ── submitRequest ─────────────────────────────────────────────────────────

    @isTest
    static void testSubmitRequest_NoProducts() {
        Account acc = makeAccount();
        Boolean threw = false;
        Test.startTest();
        try {
            DistributorRegistrationFormController.submitRequest(
                acc.Id, 'New Request', 'IN', 'Ophthalmic', 'Company', 12,
                null, null, new List<Id>(), null, null, null
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw AuraHandledException for empty product list');
    }

    @isTest
    static void testSubmitRequest_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Ophthalmic');

        Test.startTest();
        DistributorRegistrationFormController.SubmitResult result =
            DistributorRegistrationFormController.submitRequest(
                acc.Id, 'New Request', 'IN', 'Ophthalmic', 'Company', 12,
                null, null, new List<Id>{ prod.Id }, 'GSTIN Certificate', 'Test remarks', null
            );
        Test.stopTest();

        System.assertNotEquals(null, result.recordId);
        System.assertNotEquals(null, result.recordName);

        Registration_Request__c created = [
            SELECT Status__c, Country__c, Request_Type__c
            FROM   Registration_Request__c
            WHERE  Id = :result.recordId
        ];
        System.assertEquals('Under Functional Head Review', created.Status__c);
        System.assertEquals('IN', created.Country__c);
        System.assertEquals('New Registration', created.Request_Type__c);
    }

    @isTest
    static void testSubmitRequest_WithDocMappings() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Ophthalmic');
        String docMappings = '[{"docType":"GSTIN Certificate","productIds":["' + prod.Id + '"]}]';

        Test.startTest();
        DistributorRegistrationFormController.SubmitResult result =
            DistributorRegistrationFormController.submitRequest(
                acc.Id, 'New Request', 'IN', 'Ophthalmic', 'Company', 12,
                null, null, new List<Id>{ prod.Id }, 'GSTIN Certificate', null, docMappings
            );
        Test.stopTest();

        System.assertNotEquals(null, result.recordId);
        List<Request_Document__c> docs = [
            SELECT Id FROM Request_Document__c
            WHERE  Registration_Request_Product__r.Registration_Request__c = :result.recordId
        ];
        System.assertEquals(1, docs.size(), 'Should create one Request_Document__c record');
    }

    // ── submitAdditionalCertRequest ───────────────────────────────────────────

    @isTest
    static void testSubmitAdditionalCertRequest_NullParent() {
        Boolean threw = false;
        Test.startTest();
        try {
            DistributorRegistrationFormController.submitAdditionalCertRequest(
                null, 'GSTIN Certificate', null, null
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw for null parentRequestId');
    }

    @isTest
    static void testSubmitAdditionalCertRequest_BlankDocTypes() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Ophthalmic');
        Registration_Request__c parent = makeCompletedRequest(acc.Id, prod.Id);

        Boolean threw = false;
        Test.startTest();
        try {
            DistributorRegistrationFormController.submitAdditionalCertRequest(
                parent.Id, '', null, null
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw for blank documentTypes');
    }

    @isTest
    static void testSubmitAdditionalCertRequest_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Ophthalmic');
        Registration_Request__c parent = makeCompletedRequest(acc.Id, prod.Id);
        String docMappings = '[{"docType":"GSTIN Certificate","productIds":["' + prod.Id + '"]}]';

        Test.startTest();
        DistributorRegistrationFormController.SubmitResult result =
            DistributorRegistrationFormController.submitAdditionalCertRequest(
                parent.Id, 'GSTIN Certificate', 'Additional remarks', docMappings
            );
        Test.stopTest();

        System.assertNotEquals(null, result.recordId);
        Registration_Request__c child = [
            SELECT Status__c, Parent_Request__c, Request_Type__c
            FROM   Registration_Request__c
            WHERE  Id = :result.recordId
        ];
        System.assertEquals('Submitted to Regulatory', child.Status__c);
        System.assertEquals(parent.Id, child.Parent_Request__c);
        System.assertEquals('Additional Document Request', child.Request_Type__c);
    }
}
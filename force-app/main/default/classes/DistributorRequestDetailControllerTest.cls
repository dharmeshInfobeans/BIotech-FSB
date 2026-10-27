@isTest
private class DistributorRequestDetailControllerTest {

    // ── Data helpers ──────────────────────────────────────────────────────────

    static Account makeAccount() {
        Account acc = new Account(
            Name           = 'Test Distributor',
            GSTIN_No__c    = 'TESTGSTIN001',
            Country_Key__c = 'IN',
            E_Mail__c      = 'distributor@test.com'
        );
        insert acc;
        return acc;
    }

    static Product__c makeProduct(String name) {
        Product__c p = new Product__c(Name = name, Dummy_Product_Code__c = name.left(10));
        insert p;
        return p;
    }

    static User makePortalUser(Account acc) {
        Contact con = new Contact(
            FirstName = 'Test',
            LastName  = 'Portal',
            AccountId = acc.Id,
            Email     = 'detailtest@biotestdistributor.example'
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
            Username          = 'detailtest@biotestdistributor.example.portal',
            Alias             = 'dtltest',
            Email             = 'detailtest@biotestdistributor.example',
            FirstName         = 'Test',
            LastName          = 'Portal',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey      = 'en_US',
            TimeZoneSidKey    = 'America/Los_Angeles'
        );
        insert u;
        return u;
    }

    static Registration_Request__c makeRequest(Id accountId, Id productId, String status) {
        Registration_Request__c rr = new Registration_Request__c(
            Account__c        = accountId,
            Product__c        = productId,
            Country__c        = 'IN',
            Status__c         = status,
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year()),
            Remarks__c        = 'Test remarks'
        );
        insert rr;
        return rr;
    }

    // ── getRequestDetail — null recordId throws ───────────────────────────────

    @isTest
    static void testGetRequestDetail_NullId_Throws() {
        Account acc  = makeAccount();
        User portalU = makePortalUser(acc);

        Boolean threw = false;
        Test.startTest();
        System.runAs(portalU) {
            try {
                DistributorRequestDetailController.getRequestDetail(null);
            } catch (AuraHandledException e) {
                threw = true;
            }
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when recordId is null');
    }

    // ── getRequestDetail — no account throws ─────────────────────────────────

    @isTest
    static void testGetRequestDetail_NoAccount_Throws() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Draft');

        // Running as internal user who has no AccountId
        Boolean threw = false;
        Test.startTest();
        try {
            DistributorRequestDetailController.getRequestDetail(rr.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when no account is linked to the user');
    }

    // ── getRequestDetail — wrong account throws ───────────────────────────────

    @isTest
    static void testGetRequestDetail_WrongAccount_Throws() {
        Account acc1 = makeAccount();
        Account acc2 = new Account(
            Name           = 'Other Distributor',
            GSTIN_No__c    = 'TESTGSTIN002',
            Country_Key__c = 'US',
            E_Mail__c      = 'other@test.com'
        );
        insert acc2;

        User portalU    = makePortalUser(acc1);
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc2.Id, prod.Id, 'Draft');

        Boolean threw = false;
        Test.startTest();
        System.runAs(portalU) {
            try {
                DistributorRequestDetailController.getRequestDetail(rr.Id);
            } catch (AuraHandledException e) {
                threw = true;
            }
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when request belongs to a different account');
    }

    // ── getRequestDetail — basic fields mapped ────────────────────────────────

    @isTest
    static void testGetRequestDetail_BasicFieldsMapped() {
        Account acc     = makeAccount();
        User portalU    = makePortalUser(acc);
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        Test.startTest();
        DistributorRequestDetailController.RequestDetail d;
        System.runAs(portalU) {
            d = DistributorRequestDetailController.getRequestDetail(rr.Id);
        }
        Test.stopTest();

        System.assertNotEquals(null, d);
        System.assertEquals(String.valueOf(rr.Id),   d.id);
        System.assertEquals('Under Leadership Review', d.status);
        System.assertEquals('IN',                    d.country);
        System.assertEquals('New Registration',      d.requestType);
        System.assertEquals('Test Product',          d.productName);
        System.assertEquals('Test remarks',          d.remarks);
        System.assertNotEquals(null, d.submittedDate);
        System.assertEquals(false, d.certificateUploaded);
        System.assertEquals(false, d.noRegistrationRequired);
        System.assertEquals(null, d.basket);
        System.assertEquals(0, d.documents.size());
        System.assertEquals(0, d.childRequests.size());
    }

    // ── getRequestDetail — allProductNames falls back to productName ──────────

    @isTest
    static void testGetRequestDetail_AllProductNames_FallbackToProductName() {
        Account acc     = makeAccount();
        User portalU    = makePortalUser(acc);
        Product__c prod = makeProduct('Primary Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Draft');

        Test.startTest();
        DistributorRequestDetailController.RequestDetail d;
        System.runAs(portalU) {
            d = DistributorRequestDetailController.getRequestDetail(rr.Id);
        }
        Test.stopTest();

        System.assertEquals('Primary Product', d.allProductNames);
    }

    // ── getRequestDetail — allProductNames from RRP records ──────────────────

    @isTest
    static void testGetRequestDetail_AllProductNames_FromRRP() {
        Account acc      = makeAccount();
        User portalU     = makePortalUser(acc);
        Product__c prod1 = makeProduct('Product A');
        Product__c prod2 = makeProduct('Product B');
        Registration_Request__c rr = makeRequest(acc.Id, prod1.Id, 'Draft');

        insert new List<Registration_Request_Product__c>{
            new Registration_Request_Product__c(Registration_Request__c = rr.Id, Product__c = prod1.Id),
            new Registration_Request_Product__c(Registration_Request__c = rr.Id, Product__c = prod2.Id)
        };

        Test.startTest();
        DistributorRequestDetailController.RequestDetail d;
        System.runAs(portalU) {
            d = DistributorRequestDetailController.getRequestDetail(rr.Id);
        }
        Test.stopTest();

        System.assert(d.allProductNames.contains('Product A'));
        System.assert(d.allProductNames.contains('Product B'));
    }

    // ── getRequestDetail — basket fields mapped ───────────────────────────────

    @isTest
    static void testGetRequestDetail_BasketMapped() {
        Account acc     = makeAccount();
        User portalU    = makePortalUser(acc);
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');

        Document_Basket__c basket = new Document_Basket__c(
            Registration_Request__c = rr.Id,
            Status__c               = 'Additional Documents Required',
            RA_Remarks__c           = 'Upload GST cert',
            Distributor_Remarks__c  = 'Will upload by Friday',
            Submission_Date__c      = Datetime.now(),
            Due_Date__c             = Date.today().addDays(7)
        );
        insert basket;

        Test.startTest();
        DistributorRequestDetailController.RequestDetail d;
        System.runAs(portalU) {
            d = DistributorRequestDetailController.getRequestDetail(rr.Id);
        }
        Test.stopTest();

        System.assertNotEquals(null, d.basket);
        System.assertEquals(String.valueOf(basket.Id), d.basket.id);
        System.assertEquals('Additional Documents Required', d.basket.status);
        System.assertEquals('Upload GST cert',         d.basket.raRemarks);
        System.assertEquals('Will upload by Friday',   d.basket.distributorRemarks);
        System.assertNotEquals(null, d.basket.submissionDate);
        System.assertNotEquals(null, d.basket.dueDate);
    }

    // ── getRequestDetail — child requests included ────────────────────────────

    @isTest
    static void testGetRequestDetail_ChildRequests() {
        Account acc     = makeAccount();
        User portalU    = makePortalUser(acc);
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c parent = makeRequest(acc.Id, prod.Id, 'Draft');

        Registration_Request__c child = new Registration_Request__c(
            Account__c        = acc.Id,
            Product__c        = prod.Id,
            Country__c        = 'IN',
            Status__c         = 'Draft',
            Request_Type__c   = 'Additional Document Request',
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year()),
            Parent_Request__c = parent.Id
        );
        insert child;

        Test.startTest();
        DistributorRequestDetailController.RequestDetail d;
        System.runAs(portalU) {
            d = DistributorRequestDetailController.getRequestDetail(parent.Id);
        }
        Test.stopTest();

        System.assertEquals(1, d.childRequests.size());
        System.assertEquals(String.valueOf(child.Id), d.childRequests[0].id);
        System.assertEquals('Draft',                  d.childRequests[0].status);
    }

    // ── getRequestDetail — documentsByProduct grouped ────────────────────────

    @isTest
    static void testGetRequestDetail_DocumentsByProduct() {
        Account acc     = makeAccount();
        User portalU    = makePortalUser(acc);
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory');

        Registration_Request_Product__c rrp = new Registration_Request_Product__c(
            Registration_Request__c = rr.Id,
            Product__c              = prod.Id
        );
        insert rrp;

        insert new List<Request_Document__c>{
            new Request_Document__c(
                Registration_Request_Product__c = rrp.Id,
                Document_Type__c                = 'GSTIN Certificate'
            ),
            new Request_Document__c(
                Registration_Request_Product__c = rrp.Id,
                Document_Type__c                = 'Import Export Certificate'
            )
        };

        Test.startTest();
        DistributorRequestDetailController.RequestDetail d;
        System.runAs(portalU) {
            d = DistributorRequestDetailController.getRequestDetail(rr.Id);
        }
        Test.stopTest();

        System.assertEquals(1, d.documentsByProduct.size());
        System.assertEquals('Test Product', d.documentsByProduct[0].productName);
        System.assertEquals(2,              d.documentsByProduct[0].docTypes.size());
    }

    // ── getResubmitData — no account throws ──────────────────────────────────

    @isTest
    static void testGetResubmitData_NoAccount_Throws() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Sent Back');

        Boolean threw = false;
        Test.startTest();
        try {
            DistributorRequestDetailController.getResubmitData(rr.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when no account linked to user');
    }

    // ── getResubmitData — returns data structure ──────────────────────────────

    @isTest
    static void testGetResubmitData_ReturnsStructure() {
        Account acc     = makeAccount();
        User portalU    = makePortalUser(acc);
        Product__c prod = makeProduct('Test Product');

        // getResubmitData runs with sharing — request must be owned by the portal user
        Registration_Request__c rr;
        System.runAs(portalU) {
            rr = makeRequest(acc.Id, prod.Id, 'Sent Back');
            Registration_Request_Product__c rrp = new Registration_Request_Product__c(
                Registration_Request__c = rr.Id,
                Product__c              = prod.Id
            );
            insert rrp;
            insert new Request_Document__c(
                Registration_Request_Product__c = rrp.Id,
                Document_Type__c                = 'GSTIN Certificate'
            );
        }

        Test.startTest();
        DistributorRequestDetailController.ResubmitFormData fd;
        System.runAs(portalU) {
            fd = DistributorRequestDetailController.getResubmitData(rr.Id);
        }
        Test.stopTest();

        System.assertNotEquals(null, fd);
        System.assertEquals(String.valueOf(acc.Id), fd.accountId);
        System.assertNotEquals(null, fd.existingProducts);
        System.assertEquals(1, fd.existingProducts.size());
        System.assertEquals(String.valueOf(prod.Id), fd.existingProducts[0].value);
        System.assertEquals('Test Product',          fd.existingProducts[0].label);
        System.assert(fd.existingDocTypes.contains('GSTIN Certificate'));
    }

    // ── resubmitWithUpdates — wrong status throws ─────────────────────────────

    @isTest
    static void testResubmitWithUpdates_WrongStatus_Throws() {
        Account acc     = makeAccount();
        User portalU    = makePortalUser(acc);
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        Boolean threw = false;
        Test.startTest();
        System.runAs(portalU) {
            try {
                DistributorRequestDetailController.resubmitWithUpdates(
                    rr.Id, null, null, '[]', '[]', null
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when status is not Sent Back');
    }

    // ── resubmitWithUpdates — happy path changes status ───────────────────────

    @isTest
    static void testResubmitWithUpdates_HappyPath() {
        Account acc     = makeAccount();
        User portalU    = makePortalUser(acc);
        Product__c prod = makeProduct('Test Product');

        Registration_Request__c rr;
        System.runAs(portalU) {
            rr = makeRequest(acc.Id, prod.Id, 'Sent Back');
            Registration_Request_Product__c rrp = new Registration_Request_Product__c(
                Registration_Request__c = rr.Id,
                Product__c              = prod.Id
            );
            insert rrp;
            insert new Request_Document__c(
                Registration_Request_Product__c = rrp.Id,
                Document_Type__c                = 'GSTIN Certificate'
            );
        }

        Test.startTest();
        System.runAs(portalU) {
            DistributorRequestDetailController.resubmitWithUpdates(
                rr.Id, '2026-01-01', '2027-01-01', '[]', '[]', 'Re-submitting with updates'
            );
        }
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c, Rejection_Comments__c, Remarks__c,
                   Certificate_Valid_From__c, Certificate_Valid_To__c
            FROM   Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Under Functional Head Review', updated.Status__c);
        System.assertEquals(null, updated.Rejection_Comments__c);
        System.assertEquals(Date.newInstance(2026, 1, 1), updated.Certificate_Valid_From__c);
        System.assertEquals(Date.newInstance(2027, 1, 1), updated.Certificate_Valid_To__c);
        System.assert(updated.Remarks__c.contains('Re-submitting with updates'));
    }

    // ── resubmitWithUpdates — adds new product and doc type ───────────────────

    @isTest
    static void testResubmitWithUpdates_NewProductAdded() {
        Account acc      = makeAccount();
        User portalU     = makePortalUser(acc);
        Product__c prod1 = makeProduct('Product Ex');
        Product__c prod2 = makeProduct('Product New');

        Registration_Request__c rr;
        System.runAs(portalU) {
            rr = makeRequest(acc.Id, prod1.Id, 'Sent Back');
            insert new Registration_Request_Product__c(
                Registration_Request__c = rr.Id,
                Product__c              = prod1.Id
            );
        }

        String newProdJson = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId' => String.valueOf(prod2.Id),
                'docTypes'  => new List<String>{ 'Import Export Certificate' }
            }
        });

        Test.startTest();
        System.runAs(portalU) {
            DistributorRequestDetailController.resubmitWithUpdates(
                rr.Id, null, null, '[]', newProdJson, null
            );
        }
        Test.stopTest();

        List<Registration_Request_Product__c> allRRPs = [
            SELECT Product__c FROM Registration_Request_Product__c
            WHERE  Registration_Request__c = :rr.Id
        ];
        System.assertEquals(2, allRRPs.size(), 'New product RRP should be added');

        List<Request_Document__c> newDocs = [
            SELECT Document_Type__c
            FROM   Request_Document__c
            WHERE  Registration_Request_Product__r.Product__c  = :prod2.Id
            AND    Registration_Request_Product__r.Registration_Request__c = :rr.Id
        ];
        System.assertEquals(1, newDocs.size());
        System.assertEquals('Import Export Certificate', newDocs[0].Document_Type__c);
    }

    // ── resubmitWithUpdates — existingProdAddedDocs branch ────────────────────

    @isTest
    static void testResubmitWithUpdates_ExistingProdAddedDocs() {
        Account acc     = makeAccount();
        User portalU    = makePortalUser(acc);
        Product__c prod = makeProduct('Test Prod');

        Registration_Request__c rr;
        Registration_Request_Product__c rrp;
        System.runAs(portalU) {
            rr = makeRequest(acc.Id, prod.Id, 'Sent Back');
            rrp = new Registration_Request_Product__c(
                Registration_Request__c = rr.Id,
                Product__c              = prod.Id
            );
            insert rrp;
        }

        String existingAddedJson = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId'   => String.valueOf(prod.Id),
                'addDocTypes' => new List<String>{ 'Import Export Certificate' }
            }
        });

        Test.startTest();
        System.runAs(portalU) {
            DistributorRequestDetailController.resubmitWithUpdates(
                rr.Id, null, null, existingAddedJson, '[]', null
            );
        }
        Test.stopTest();

        List<Request_Document__c> docs = [
            SELECT Document_Type__c FROM Request_Document__c
            WHERE  Registration_Request_Product__r.Registration_Request__c = :rr.Id
        ];
        System.assertEquals(1, docs.size(), 'Added doc type for existing product should be created');
        System.assertEquals('Import Export Certificate', docs[0].Document_Type__c);
    }

    // ── getRequestDetail — documents linked to basket cover formatSize ─────────

    @isTest
    static void testGetRequestDetail_Documents_CoverFormatSize() {
        Account acc     = makeAccount();
        User portalU    = makePortalUser(acc);
        Product__c prod = makeProduct('Test Prod');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');

        Document_Basket__c basket = new Document_Basket__c(
            Registration_Request__c = rr.Id,
            Status__c               = 'Under Review',
            Submission_Date__c      = Datetime.now()
        );
        insert basket;

        ContentVersion cv = new ContentVersion(
            Title          = 'GSTIN Certificate',
            PathOnClient   = 'GSTIN_Certificate.pdf',
            VersionData    = Blob.valueOf('test content'),
            IsMajorVersion = true
        );
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        insert new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId    = basket.Id,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );

        Test.startTest();
        DistributorRequestDetailController.RequestDetail d;
        System.runAs(portalU) {
            d = DistributorRequestDetailController.getRequestDetail(rr.Id);
        }
        Test.stopTest();

        System.assertNotEquals(null, d.documents);
        System.assert(d.documents.size() >= 1, 'Should include the linked document');
    }

    // ── resubmitToRegulatory ──────────────────────────────────────────────────

    @isTest
    static void testResubmitToRegulatory_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Sent Back');

        Test.startTest();
        DistributorRequestDetailController.resubmitToRegulatory(rr.Id);
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c, Rejection_Comments__c
            FROM   Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Submitted to Regulatory', updated.Status__c);
        System.assertEquals(null, updated.Rejection_Comments__c);
    }

    // ── resubmitToRegulatoryWithUpdates — no account throws ──────────────────

    @isTest
    static void testResubmitToRegulatoryWithUpdates_NoAccount_Throws() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Sent Back');

        Boolean threw = false;
        Test.startTest();
        try {
            DistributorRequestDetailController.resubmitToRegulatoryWithUpdates(
                rr.Id, '[]', '[]', null
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when no account is linked to the user');
    }

    // ── resubmitToRegulatoryWithUpdates — wrong status throws ────────────────

    @isTest
    static void testResubmitToRegulatoryWithUpdates_WrongStatus_Throws() {
        Account acc     = makeAccount();
        User portalU    = makePortalUser(acc);
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');

        Boolean threw = false;
        Test.startTest();
        System.runAs(portalU) {
            try {
                DistributorRequestDetailController.resubmitToRegulatoryWithUpdates(
                    rr.Id, '[]', '[]', null
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when status is not Sent Back');
    }

    // ── resubmitToRegulatoryWithUpdates — happy path ──────────────────────────

    @isTest
    static void testResubmitToRegulatoryWithUpdates_HappyPath() {
        Account acc     = makeAccount();
        User portalU    = makePortalUser(acc);
        Product__c prod = makeProduct('Test Product');

        Registration_Request__c rr;
        Registration_Request_Product__c rrp;
        System.runAs(portalU) {
            rr = makeRequest(acc.Id, prod.Id, 'Sent Back');
            rrp = new Registration_Request_Product__c(
                Registration_Request__c = rr.Id,
                Product__c              = prod.Id
            );
            insert rrp;
            insert new Request_Document__c(
                Registration_Request_Product__c = rrp.Id,
                Document_Type__c                = 'ISO Certificate'
            );
        }

        Test.startTest();
        System.runAs(portalU) {
            DistributorRequestDetailController.resubmitToRegulatoryWithUpdates(
                rr.Id, '[]', '[]', 'Re-uploading corrected documents'
            );
        }
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c, Rejection_Comments__c, Remarks__c
            FROM   Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Submitted to Regulatory', updated.Status__c);
        System.assertEquals(null, updated.Rejection_Comments__c);
        System.assert(updated.Remarks__c.contains('Re-uploading corrected documents'));
    }

    // ── resubmitToRegulatoryWithUpdates — adds new product and doc type ───────

    @isTest
    static void testResubmitToRegulatoryWithUpdates_NewProductAdded() {
        Account acc      = makeAccount();
        User portalU     = makePortalUser(acc);
        Product__c prod1 = makeProduct('Prod RA1');
        Product__c prod2 = makeProduct('Prod RA2');

        Registration_Request__c rr;
        System.runAs(portalU) {
            rr = makeRequest(acc.Id, prod1.Id, 'Sent Back');
            insert new Registration_Request_Product__c(
                Registration_Request__c = rr.Id,
                Product__c              = prod1.Id
            );
        }

        String newProdJson = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId' => String.valueOf(prod2.Id),
                'docTypes'  => new List<String>{ 'GMP' }
            }
        });

        Test.startTest();
        System.runAs(portalU) {
            DistributorRequestDetailController.resubmitToRegulatoryWithUpdates(
                rr.Id, '[]', newProdJson, null
            );
        }
        Test.stopTest();

        List<Registration_Request_Product__c> allRRPs = [
            SELECT Product__c FROM Registration_Request_Product__c
            WHERE  Registration_Request__c = :rr.Id
        ];
        System.assertEquals(2, allRRPs.size(), 'New product RRP should be added');

        List<Request_Document__c> newDocs = [
            SELECT Document_Type__c
            FROM   Request_Document__c
            WHERE  Registration_Request_Product__r.Product__c = :prod2.Id
            AND    Registration_Request_Product__r.Registration_Request__c = :rr.Id
        ];
        System.assertEquals(1, newDocs.size());
        System.assertEquals('GMP', newDocs[0].Document_Type__c);

        Registration_Request__c updated = [SELECT Status__c FROM Registration_Request__c WHERE Id = :rr.Id];
        System.assertEquals('Submitted to Regulatory', updated.Status__c);
    }

    // ── resubmitAdditionalRequest ─────────────────────────────────────────────

    @isTest
    static void testResubmitAdditionalRequest_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('ADR Product');
        Registration_Request__c parent = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');
        Registration_Request__c child = new Registration_Request__c(
            Account__c        = acc.Id,
            Product__c        = prod.Id,
            Country__c        = 'IN',
            Status__c         = 'Sent Back',
            Request_Type__c   = 'Additional Document Request',
            Parent_Request__c = parent.Id,
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert child;

        Test.startTest();
        DistributorRequestDetailController.resubmitAdditionalRequest(child.Id);
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c, Rejection_Comments__c
            FROM   Registration_Request__c WHERE Id = :child.Id
        ];
        System.assertEquals('Submitted to Regulatory', updated.Status__c);
        System.assertEquals(null, updated.Rejection_Comments__c);
    }

    // ── resubmitToRegulatoryWithUpdates — Additional Document Request ─────────

    @isTest
    static void testResubmitToRegulatoryWithUpdates_AdditionalRequest() {
        Account acc      = makeAccount();
        User portalU     = makePortalUser(acc);
        Product__c prod1 = makeProduct('ADR Prod1');
        Product__c prod2 = makeProduct('ADR Prod2');

        Registration_Request__c child;
        System.runAs(portalU) {
            Registration_Request__c parent = makeRequest(acc.Id, prod1.Id, 'Completed');
            child = new Registration_Request__c(
                Account__c        = acc.Id,
                Product__c        = prod1.Id,
                Country__c        = 'IN',
                Status__c         = 'Sent Back',
                Current_Stage__c  = 'Regulatory Processing',
                Request_Type__c   = 'Additional Document Request',
                Parent_Request__c = parent.Id,
                Submitted_Date__c = Datetime.now(),
                Year__c           = String.valueOf(Date.today().year())
            );
            insert child;
            Registration_Request_Product__c rrp = new Registration_Request_Product__c(
                Registration_Request__c = child.Id,
                Product__c              = prod1.Id
            );
            insert rrp;
            insert new Request_Document__c(
                Registration_Request_Product__c = rrp.Id,
                Document_Type__c                = 'ISO Certificate'
            );
        }

        String existingJson = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId'   => String.valueOf(prod1.Id),
                'addDocTypes' => new List<String>{ 'POA' }
            }
        });
        String newProdJson = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId' => String.valueOf(prod2.Id),
                'docTypes'  => new List<String>{ 'LOA', 'CE Certificate' }
            }
        });

        Test.startTest();
        System.runAs(portalU) {
            DistributorRequestDetailController.resubmitToRegulatoryWithUpdates(
                child.Id, existingJson, newProdJson, 'Added missing certificates'
            );
        }
        Test.stopTest();

        List<Registration_Request_Product__c> allRRPs = [
            SELECT Product__c FROM Registration_Request_Product__c
            WHERE  Registration_Request__c = :child.Id
        ];
        System.assertEquals(2, allRRPs.size(), 'New product should be added to the additional request');

        List<Request_Document__c> docs = [
            SELECT Document_Type__c
            FROM   Request_Document__c
            WHERE  Registration_Request_Product__r.Registration_Request__c = :child.Id
        ];
        System.assertEquals(4, docs.size(), 'ISO (existing) + POA (added) + LOA + CE Certificate (new product)');

        Registration_Request__c updated = [
            SELECT Status__c, Rejection_Comments__c, Remarks__c, Document_Types__c
            FROM   Registration_Request__c WHERE Id = :child.Id
        ];
        System.assertEquals('Submitted to Regulatory', updated.Status__c);
        System.assertEquals(null, updated.Rejection_Comments__c);
        System.assert(updated.Remarks__c.contains('Added missing certificates'));
        System.assert(updated.Document_Types__c.contains('POA'));
        System.assert(updated.Document_Types__c.contains('CE Certificate'));
    }
}
@isTest
private class RegulatoryRequestDetailControllerTest {

    // ── Data helpers ──────────────────────────────────────────────────────────

    static Account makeAccount() {
        Account acc = new Account(
            Name              = 'Test Distributor',
            GSTIN_No__c       = 'TESTGSTIN123',
            Country_Key__c    = 'IN',
            E_Mail__c         = 'distributor@test.com',
            BillingStreet     = '123 Test Street',
            BillingCity       = 'Mumbai',
            BillingPostalCode = '400001'
        );
        insert acc;
        return acc;
    }

    static Product__c makeProduct(String name) {
        Product__c p = new Product__c(Name = name, Dummy_Product_Code__c = name.left(10));
        insert p;
        return p;
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

    // ── getRequestDetail — basic field mapping ────────────────────────────────

    @isTest
    static void testGetRequestDetail_BasicFields() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory');

        Test.startTest();
        RegulatoryRequestDetailController.RequestDetail d =
            RegulatoryRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertNotEquals(null, d);
        System.assertEquals(String.valueOf(rr.Id),     d.id);
        System.assertEquals('Submitted to Regulatory', d.status);
        System.assertEquals('IN',                      d.country);
        System.assertEquals('New Registration',        d.requestType);
        System.assertEquals('Test Distributor',        d.distributorName);
        System.assertEquals('Test Product',            d.productName);
        System.assertEquals('Test remarks',            d.remarks);
        System.assertNotEquals(null, d.submittedDate);
        System.assertNotEquals(null, d.daysPending);
    }

    @isTest
    static void testGetRequestDetail_NullOptionalFields() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory');

        Test.startTest();
        RegulatoryRequestDetailController.RequestDetail d =
            RegulatoryRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertEquals(null, d.rejectionComments);
        System.assertEquals(null, d.parentRequestId);
        System.assertEquals(null, d.parentRequestName);
        System.assertEquals(null, d.forecastWeek);
        System.assertEquals(null, d.forecastYear);
        System.assertEquals(null, d.actualCompletionWeek);
        System.assertEquals(null, d.actualCompletionYear);
        System.assertEquals(null, d.crmName);
        System.assertEquals(null, d.rsmName);
    }

    // ── certificateUploaded default ───────────────────────────────────────────

    @isTest
    static void testGetRequestDetail_CertificateUploaded_DefaultFalse() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory');

        Test.startTest();
        RegulatoryRequestDetailController.RequestDetail d =
            RegulatoryRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertEquals(false, d.certificateUploaded);
    }

    // ── daysPending — computed from Submitted_Date__c ─────────────────────────

    @isTest
    static void testGetRequestDetail_DaysPending_ComputedFromSubmittedDate() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = new Registration_Request__c(
            Account__c        = acc.Id,
            Product__c        = prod.Id,
            Country__c        = 'IN',
            Status__c         = 'Submitted to Regulatory',
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Datetime.now().addDays(-5),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert rr;

        Test.startTest();
        RegulatoryRequestDetailController.RequestDetail d =
            RegulatoryRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertNotEquals(null, d.daysPending);
        System.assert(d.daysPending >= 5, 'daysPending should be at least 5');
    }

    // ── allProductNames — fallback and RRP-based ──────────────────────────────

    @isTest
    static void testGetRequestDetail_AllProductNames_FallsBackToProductName() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Primary Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory');

        Test.startTest();
        RegulatoryRequestDetailController.RequestDetail d =
            RegulatoryRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertEquals('Primary Product', d.allProductNames);
    }

    @isTest
    static void testGetRequestDetail_AllProductNames_FromRRPRecords() {
        Account acc      = makeAccount();
        Product__c prod1 = makeProduct('Product A');
        Product__c prod2 = makeProduct('Product B');
        Registration_Request__c rr = makeRequest(acc.Id, prod1.Id, 'Submitted to Regulatory');

        insert new List<Registration_Request_Product__c>{
            new Registration_Request_Product__c(Registration_Request__c = rr.Id, Product__c = prod1.Id),
            new Registration_Request_Product__c(Registration_Request__c = rr.Id, Product__c = prod2.Id)
        };

        Test.startTest();
        RegulatoryRequestDetailController.RequestDetail d =
            RegulatoryRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assert(d.allProductNames.contains('Product A'));
        System.assert(d.allProductNames.contains('Product B'));
    }

    // ── basket — no basket ────────────────────────────────────────────────────

    @isTest
    static void testGetRequestDetail_NoBasket_BasketNull() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory');

        Test.startTest();
        RegulatoryRequestDetailController.RequestDetail d =
            RegulatoryRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertEquals(null, d.basket);
        System.assertNotEquals(null, d.documents);
        System.assertEquals(0, d.documents.size());
    }

    // ── basket — with basket ──────────────────────────────────────────────────

    @isTest
    static void testGetRequestDetail_WithBasket_BasketFieldsMapped() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');

        Document_Basket__c basket = new Document_Basket__c(
            Registration_Request__c = rr.Id,
            Status__c               = 'Under Review',
            RA_Remarks__c           = 'Please upload GST cert',
            Submission_Date__c      = Datetime.now()
        );
        insert basket;

        Test.startTest();
        RegulatoryRequestDetailController.RequestDetail d =
            RegulatoryRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertNotEquals(null, d.basket);
        System.assertEquals(String.valueOf(basket.Id), d.basket.id);
        System.assertEquals('Under Review',            d.basket.status);
        System.assertEquals('Please upload GST cert',  d.basket.raRemarks);
        System.assertNotEquals(null, d.basket.submissionDate);
    }

    // ── childRequests — empty ─────────────────────────────────────────────────

    @isTest
    static void testGetRequestDetail_ChildRequests_Empty() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory');

        Test.startTest();
        RegulatoryRequestDetailController.RequestDetail d =
            RegulatoryRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertNotEquals(null, d.childRequests);
        System.assertEquals(0, d.childRequests.size());
    }

    // ── childRequests — populated ─────────────────────────────────────────────

    @isTest
    static void testGetRequestDetail_ChildRequests_Populated() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c parent = makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory');

        Registration_Request__c child = new Registration_Request__c(
            Account__c        = acc.Id,
            Product__c        = prod.Id,
            Country__c        = 'IN',
            Status__c         = 'Submitted to Regulatory',
            Request_Type__c   = 'Additional Document Request',
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year()),
            Parent_Request__c = parent.Id
        );
        insert child;

        Test.startTest();
        RegulatoryRequestDetailController.RequestDetail d =
            RegulatoryRequestDetailController.getRequestDetail(parent.Id);
        Test.stopTest();

        System.assertEquals(1, d.childRequests.size());
        System.assertEquals(String.valueOf(child.Id),        d.childRequests[0].id);
        System.assertEquals('Additional Document Request',   d.childRequests[0].requestType);
        System.assertEquals('Test Product',                  d.childRequests[0].productName);
        System.assertNotEquals(null, d.childRequests[0].submittedDate);
    }

    // ── parentRequestName ─────────────────────────────────────────────────────

    @isTest
    static void testGetRequestDetail_ParentRequest_Mapped() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c parent = makeRequest(acc.Id, prod.Id, 'Completed');

        Registration_Request__c child = new Registration_Request__c(
            Account__c        = acc.Id,
            Product__c        = prod.Id,
            Country__c        = 'IN',
            Status__c         = 'Submitted to Regulatory',
            Request_Type__c   = 'Additional Document Request',
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year()),
            Parent_Request__c = parent.Id
        );
        insert child;

        Test.startTest();
        RegulatoryRequestDetailController.RequestDetail d =
            RegulatoryRequestDetailController.getRequestDetail(child.Id);
        Test.stopTest();

        System.assertEquals(String.valueOf(parent.Id), d.parentRequestId);
        System.assertNotEquals(null, d.parentRequestName);
    }

    // ── documentsByProduct — empty ────────────────────────────────────────────

    @isTest
    static void testGetRequestDetail_DocumentsByProduct_Empty() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory');

        Test.startTest();
        RegulatoryRequestDetailController.RequestDetail d =
            RegulatoryRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertNotEquals(null, d.documentsByProduct);
        System.assertEquals(0, d.documentsByProduct.size());
    }

    // ── documentsByProduct — populated ────────────────────────────────────────

    @isTest
    static void testGetRequestDetail_DocumentsByProduct_Populated() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');

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
        RegulatoryRequestDetailController.RequestDetail d =
            RegulatoryRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertEquals(1, d.documentsByProduct.size());
        System.assertEquals('Test Product', d.documentsByProduct[0].productName);
        System.assertEquals(2,              d.documentsByProduct[0].docTypes.size());
    }

    // ── forecastWeek / forecastYear ───────────────────────────────────────────

    @isTest
    static void testGetRequestDetail_ForecastFields_Mapped() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');
        rr.Forecast_Week__c = 18;
        rr.Forecast_Year__c = 2026;
        update rr;

        Test.startTest();
        RegulatoryRequestDetailController.RequestDetail d =
            RegulatoryRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertEquals(18,   d.forecastWeek);
        System.assertEquals(2026, d.forecastYear);
    }

    // ── actualCompletionWeek / actualCompletionYear ───────────────────────────

    @isTest
    static void testGetRequestDetail_ActualCompletionFields_Mapped() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Completed');
        rr.Actual_Completion_Week__c = 25;
        rr.Actual_Completion_Year__c = 2026;
        update rr;

        Test.startTest();
        RegulatoryRequestDetailController.RequestDetail d =
            RegulatoryRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertEquals(25,   d.actualCompletionWeek);
        System.assertEquals(2026, d.actualCompletionYear);
    }

    // ── documents — ContentVersion linked to basket covers the doc-fetch loop ──

    @isTest
    static void testGetRequestDetail_Documents_Populated() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');

        // Controller reads documents from the basket's ContentDocumentLinks, not the request's
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
            ShareType         = 'V'
        );

        Test.startTest();
        RegulatoryRequestDetailController.RequestDetail d =
            RegulatoryRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertNotEquals(null, d.documents);
        System.assert(d.documents.size() >= 1, 'Should include the linked ContentVersion');
        Boolean foundCert = false;
        for (RegulatoryRequestDetailController.DocumentInfo di : d.documents) {
            if (di.title == 'GSTIN Certificate') { foundCert = true; break; }
        }
        System.assert(foundCert, 'Document titled "GSTIN Certificate" should be in the list');
    }
}
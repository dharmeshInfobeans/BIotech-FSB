@isTest
private class LeadershipRequestDetailControllerTest {

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

    static Id getPortalTaskRtId() {
        for (RecordType rt : [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Task' AND DeveloperName != 'MOM_Action_Items'
            LIMIT 1
        ]) { return rt.Id; }
        return null;
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
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        Test.startTest();
        LeadershipRequestDetailController.RequestDetail d =
            LeadershipRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertNotEquals(null, d);
        System.assertEquals(String.valueOf(rr.Id),  d.id);
        System.assertEquals('IN',                   d.country);
        System.assertEquals('Under Leadership Review', d.status);
        System.assertEquals('New Registration',     d.requestType);
        System.assertEquals('Test Distributor',     d.distributorName);
        System.assertEquals('Test Product',         d.productName);
        System.assertEquals('Test remarks',         d.remarks);
        System.assertNotEquals(null, d.submittedDate, 'submittedDate should be set');
    }

    @isTest
    static void testGetRequestDetail_NullOptionalFields() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Test.startTest();
        LeadershipRequestDetailController.RequestDetail d =
            LeadershipRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        // Fields not set — should be null without throwing
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

    // ── allProductNames — falls back to productName when no RRP records ───────

    @isTest
    static void testGetRequestDetail_AllProductNames_FallsBackToProductName() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Primary Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Test.startTest();
        LeadershipRequestDetailController.RequestDetail d =
            LeadershipRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertEquals('Primary Product', d.allProductNames,
            'Should fall back to productName when no RRP records exist');
    }

    @isTest
    static void testGetRequestDetail_AllProductNames_FromRRPRecords() {
        Account acc      = makeAccount();
        Product__c prod1 = makeProduct('Product A');
        Product__c prod2 = makeProduct('Product B');
        Registration_Request__c rr = makeRequest(acc.Id, prod1.Id, 'Submitted');

        insert new List<Registration_Request_Product__c>{
            new Registration_Request_Product__c(Registration_Request__c = rr.Id, Product__c = prod1.Id),
            new Registration_Request_Product__c(Registration_Request__c = rr.Id, Product__c = prod2.Id)
        };

        Test.startTest();
        LeadershipRequestDetailController.RequestDetail d =
            LeadershipRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assert(d.allProductNames.contains('Product A'), 'Should include Product A');
        System.assert(d.allProductNames.contains('Product B'), 'Should include Product B');
    }

    // ── childRequests ─────────────────────────────────────────────────────────

    @isTest
    static void testGetRequestDetail_ChildRequests_Empty() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory');

        Test.startTest();
        LeadershipRequestDetailController.RequestDetail d =
            LeadershipRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertNotEquals(null, d.childRequests);
        System.assertEquals(0, d.childRequests.size());
    }

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
        LeadershipRequestDetailController.RequestDetail d =
            LeadershipRequestDetailController.getRequestDetail(parent.Id);
        Test.stopTest();

        System.assertEquals(1, d.childRequests.size());
        System.assertEquals(String.valueOf(child.Id), d.childRequests[0].id);
        System.assertEquals('Additional Document Request', d.childRequests[0].requestType);
    }

    // ── parentRequestName ─────────────────────────────────────────────────────

    @isTest
    static void testGetRequestDetail_ParentRequestName_Populated() {
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
        LeadershipRequestDetailController.RequestDetail d =
            LeadershipRequestDetailController.getRequestDetail(child.Id);
        Test.stopTest();

        System.assertEquals(String.valueOf(parent.Id), d.parentRequestId);
        System.assertNotEquals(null, d.parentRequestName);
    }

    // ── auditHistory ──────────────────────────────────────────────────────────

    @isTest
    static void testGetRequestDetail_AuditHistory_Empty() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Test.startTest();
        LeadershipRequestDetailController.RequestDetail d =
            LeadershipRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertNotEquals(null, d.auditHistory);
        System.assertEquals(0, d.auditHistory.size());
    }



    // ── documentsByProduct ────────────────────────────────────────────────────

    @isTest
    static void testGetRequestDetail_DocumentsByProduct_Empty() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Test.startTest();
        LeadershipRequestDetailController.RequestDetail d =
            LeadershipRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertNotEquals(null, d.documentsByProduct);
        System.assertEquals(0, d.documentsByProduct.size());
    }

    @isTest
    static void testGetRequestDetail_DocumentsByProduct_Populated() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Registration_Request_Product__c rrp = new Registration_Request_Product__c(
            Registration_Request__c = rr.Id,
            Product__c              = prod.Id
        );
        insert rrp;

        insert new Request_Document__c(
            Registration_Request_Product__c = rrp.Id,
            Document_Type__c                = 'GSTIN Certificate'
        );

        Test.startTest();
        LeadershipRequestDetailController.RequestDetail d =
            LeadershipRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertEquals(1, d.documentsByProduct.size());
        System.assertEquals('Test Product',     d.documentsByProduct[0].productName);
        System.assertEquals(1,                  d.documentsByProduct[0].docTypes.size());
        System.assertEquals('GSTIN Certificate', d.documentsByProduct[0].docTypes[0]);
    }

    // ── forecastWeek / forecastYear mapping ───────────────────────────────────

    @isTest
    static void testGetRequestDetail_ForecastFields_Mapped() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');
        rr.Forecast_Week__c = 22;
        rr.Forecast_Year__c = 2026;
        update rr;

        Test.startTest();
        LeadershipRequestDetailController.RequestDetail d =
            LeadershipRequestDetailController.getRequestDetail(rr.Id);
        Test.stopTest();

        System.assertEquals(22,   d.forecastWeek);
        System.assertEquals(2026, d.forecastYear);
    }

    // ── getProductsWithDetails ────────────────────────────────────────────────

    @isTest
    static void testGetProductsWithDetails_Empty() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Test Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        Test.startTest();
        List<LeadershipRequestDetailController.ProductInfo> result =
            LeadershipRequestDetailController.getProductsWithDetails(rr.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGetProductsWithDetails_WithProducts() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product X');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        insert new Registration_Request_Product__c(
            Registration_Request__c = rr.Id,
            Product__c              = prod.Id
        );

        Test.startTest();
        List<LeadershipRequestDetailController.ProductInfo> result =
            LeadershipRequestDetailController.getProductsWithDetails(rr.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('Product X',              result[0].productName);
        System.assertEquals('Product X'.left(10),     result[0].dummyCode);
        System.assertEquals(null,                     result[0].fgCode);
    }

    // ── saveFGCodes ───────────────────────────────────────────────────────────

    @isTest
    static void testSaveFGCodes() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Y');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        Registration_Request_Product__c rrp = new Registration_Request_Product__c(
            Registration_Request__c = rr.Id,
            Product__c              = prod.Id
        );
        insert rrp;

        String payload = JSON.serialize(new List<Map<String,String>>{
            new Map<String,String>{ 'id' => rrp.Id, 'fgCode' => 'FG001' }
        });

        Test.startTest();
        LeadershipRequestDetailController.saveFGCodes(payload);
        Test.stopTest();

        Registration_Request_Product__c updated = [
            SELECT FG_Code__c FROM Registration_Request_Product__c WHERE Id = :rrp.Id
        ];
        System.assertEquals('FG001', updated.FG_Code__c);
    }

    // ── checkFGCodesComplete ──────────────────────────────────────────────────

    @isTest
    static void testCheckFGCodesComplete_NoProducts() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Z');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        Test.startTest();
        Boolean result = LeadershipRequestDetailController.checkFGCodesComplete(rr.Id);
        Test.stopTest();

        System.assertEquals(true, result, 'No RRP records means no missing FG codes');
    }

    @isTest
    static void testCheckFGCodesComplete_Incomplete() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Z');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        insert new Registration_Request_Product__c(
            Registration_Request__c = rr.Id,
            Product__c              = prod.Id
        );

        Test.startTest();
        Boolean result = LeadershipRequestDetailController.checkFGCodesComplete(rr.Id);
        Test.stopTest();

        System.assertEquals(false, result, 'RRP with no FG Code should return false');
    }

    @isTest
    static void testCheckFGCodesComplete_AllFilled() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Z');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        insert new Registration_Request_Product__c(
            Registration_Request__c = rr.Id,
            Product__c              = prod.Id,
            FG_Code__c              = 'FG999'
        );

        Test.startTest();
        Boolean result = LeadershipRequestDetailController.checkFGCodesComplete(rr.Id);
        Test.stopTest();

        System.assertEquals(true, result, 'All FG Codes filled should return true');
    }
}
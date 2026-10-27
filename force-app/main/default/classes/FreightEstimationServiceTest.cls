@IsTest
public with sharing class FreightEstimationServiceTest {

    /* =====================================================
     * Mock: Successful SAP Response
     * ===================================================== */
    private class FreightSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"SUCCESS","EstimationId":12345}');
            return res;
        }
    }

    /* =====================================================
     * Mock: Error SAP Response
     * ===================================================== */
    private class FreightErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setBody('SAP failure');
            return res;
        }
    }

    /* =====================================================
     * Test Setup
     * ===================================================== */
    @TestSetup
    static void setupData() {

        /* ---- SAP Credentials ---- */
        SAP_Creds__c creds = new SAP_Creds__c(
            Name = 'SAP_Fright_Estimation',
            Endpoint__c = 'https://test.sap.com/freight',
            Username__c = 'sapUser',
            Password__c = 'sapPassword'
        );
        insert creds;

        /* ---- Account ---- */
        Account acc = new Account(
            Name = 'Test Account',
            SAP_Code__c = 'CUST001'
        );
        insert acc;

        /* ---- Order ---- */
                      Order__c ord = new Order__c(Account__c = acc.Id,
                                                  Is_it_ok_to_cancel_old_Draft_Orders__c = true
);

        insert ord;

        /* ---- Order Product ---- */
        Order_Product__c op = new Order_Product__c(
            Order__c = ord.Id
        );
        insert op;
    }

    /* =====================================================
     * Positive Test
     * ===================================================== */
    @IsTest
    static void testGetNewEstimation_Success() {

        Order_Product__c op = [
            SELECT Id FROM Order_Product__c LIMIT 1
        ];

        FreightEstimationService.OrderProductWrapper w =
            new FreightEstimationService.OrderProductWrapper();
        w.id = op.Id;
        w.quantity = 10;

        List<FreightEstimationService.OrderProductWrapper> wrappers =
            new List<FreightEstimationService.OrderProductWrapper>{ w };

        Test.setMock(HttpCalloutMock.class, new FreightSuccessMock());

        Test.startTest();
        String response = FreightEstimationService.getNewEstimation(
            'SO-001',
            'PLANT01',
            wrappers
        );
        Test.stopTest();

        System.assertNotEquals(null, response);
        System.assert(response.contains('SUCCESS'));
    }

    /* =====================================================
     * Negative Test: Empty Products
     * ===================================================== */
    @IsTest
    static void testGetNewEstimation_NoProducts() {

        Test.startTest();
        try {
            FreightEstimationService.getNewEstimation(
                'SO-002',
                'PLANT01',
                new List<FreightEstimationService.OrderProductWrapper>()
            );
            System.assert(false, 'Exception expected');
        } catch (AuraHandledException e) {

        }
        Test.stopTest();
    }

    /* =====================================================
     * Negative Test: SAP Error Response
     * ===================================================== */
    @IsTest
    static void testGetNewEstimation_SAPError() {

        Order_Product__c op = [
            SELECT Id FROM Order_Product__c LIMIT 1
        ];

        FreightEstimationService.OrderProductWrapper w =
            new FreightEstimationService.OrderProductWrapper();
        w.id = op.Id;
        w.quantity = 5;

        List<FreightEstimationService.OrderProductWrapper> wrappers =
            new List<FreightEstimationService.OrderProductWrapper>{ w };

        Test.setMock(HttpCalloutMock.class, new FreightErrorMock());

        Test.startTest();
        try {
            FreightEstimationService.getNewEstimation(
                'SO-003',
                'PLANT01',
                wrappers
            );
            System.assert(false, 'Exception expected');
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }
}
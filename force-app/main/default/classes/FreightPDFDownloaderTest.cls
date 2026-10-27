@IsTest
public with sharing class FreightPDFDownloaderTest {

    /* -----------------------------
     * Mock HTTP Response
     * ----------------------------- */
    private class FreightPDFMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"SUCCESS","pdfBase64":"JVBERi0xLjQKJ..."}');
            return res;
        }
    }

    /* -----------------------------
     * Test Setup
     * ----------------------------- */
    @TestSetup
    static void setupData() {

        /* ---- Insert SAP Credentials ----
           Works for List / Hierarchy Custom Setting
        */
        SAP_Creds__c creds = new SAP_Creds__c(
            Name = 'SAP_GET_Freight_PDF',
            Endpoint__c = 'https://test.sap.com/api/freight/pdf',
            Username__c = 'testUser',
            Password__c = 'testPassword'
        );
        insert creds;

        /* ---- Insert Order Line Item ---- */
        OrderLineItem__c oli = new OrderLineItem__c(
            Name = 'Test Split Order',
            RFQNumber__c = 'RFQ-123',
            EstimationId__c = '1001',
            Transport_Mode__c = 'Road'
        );
        insert oli;
    }

    /* -----------------------------
     * Positive Test
     * ----------------------------- */
    @IsTest
    static void testDownloadFreightPDF_Success() {

        OrderLineItem__c oli = [
            SELECT Id FROM OrderLineItem__c LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new FreightPDFMock());

        Test.startTest();
        String response = FreightPDFDownloader.downloadFreightPDF(oli.Id);
        Test.stopTest();

        System.assertNotEquals(null, response, 'Response should not be null');
        System.assert(
            response.contains('SUCCESS'),
            'Response should contain SUCCESS'
        );
    }

    /* -----------------------------
     * Negative Test – Missing Fields
     * ----------------------------- */
    @IsTest
    static void testDownloadFreightPDF_MissingFields() {

        OrderLineItem__c oli = new OrderLineItem__c(
            Name = 'Invalid Split Order',
            RFQNumber__c = null,
            EstimationId__c = null,
            Transport_Mode__c = null
        );
        insert oli;

        Test.startTest();
        try {
            FreightPDFDownloader.downloadFreightPDF(oli.Id);
            System.assert(false, 'Exception should have been thrown');
        } catch (AuraHandledException e) {
            
        }
        Test.stopTest();
    }

    /* -----------------------------
     * Negative Test – Invalid Object
     * ----------------------------- */
    @IsTest
    static void testDownloadFreightPDF_InvalidObject() {

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Test.startTest();
        try {
            FreightPDFDownloader.downloadFreightPDF(acc.Id);
            System.assert(false, 'Exception should have been thrown');
        } catch (AuraHandledException e) {
            
        }
        Test.stopTest();
    }
}
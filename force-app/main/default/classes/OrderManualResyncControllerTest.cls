@IsTest
public class OrderManualResyncControllerTest {

    // ============================================================
    // TEST DATA SETUP
    // ============================================================
    @TestSetup
    static void setupData() {

        Sample_request_Module_Integration__c config =
            new Sample_request_Module_Integration__c(
                Name             = 'Order sync to SAP',
                End_Point_URL__c = 'http://test.sap.endpoint/salesordercreation',
                User_name__c     = 'testuser',
                Password__c      = 'testpass'
            );

        insert config;
    }


    // ============================================================
    // SUCCESSFUL HTTP MOCK
    // ============================================================
    private class MockSuccessResponse implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            List<Object> requestRecords = extractRequestRecords(req);
            List<Object> responseRecords = new List<Object>();

            for (Object obj : requestRecords) {

                Map<String, Object> record =
                    (Map<String, Object>) obj;

                responseRecords.add(
                    new Map<String, Object>{
                        'statuscode'               => 1,
                        'message'                  => 'Order Created Successfully',
                        'OrderNumber'              => '3260023520',
                        'Application_Order_Number' =>
                            record.get('Application_Order_Number')
                    }
                );
            }

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');

            response.setBody(
                JSON.serialize(
                    new Map<String, Object>{
                        'Record' => responseRecords
                    }
                )
            );

            return response;
        }
    }


    // ============================================================
    // CALLOUT EXCEPTION MOCK
    // ============================================================
    private class MockCalloutExceptionResponse implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            System.debug(
                'MOCK FIRED - throwing simulated CalloutException'
            );

            CalloutException ex =
                (CalloutException) CalloutException.class.newInstance();

            ex.setMessage('Simulated network failure');

            throw ex;
        }
    }


    // ============================================================
    // HELPER — EXTRACT REQUEST RECORDS
    // ============================================================
    private static List<Object> extractRequestRecords(
        HTTPRequest req
    ) {

        List<Object> result = new List<Object>();

        try {

            Map<String, Object> body =
                (Map<String, Object>)
                JSON.deserializeUntyped(req.getBody());

            List<Object> records =
                (List<Object>) body.get('Record');

            if (records != null) {
                result = records;
            }

        } catch (Exception ex) {

            System.debug(
                'Mock parse error: ' + ex.getMessage()
            );
        }

        return result;
    }


    // ============================================================
    // TEST DATA FACTORY
    // ============================================================
    private static Sample_Request_Header__c createHeader() {

        Account acc = new Account(
            Name = 'Manual Resync Account',
            BillingCountry = 'IN'
        );

        insert acc;


        Sample_Request_Header__c header =
            new Sample_Request_Header__c(
                Approval_Status__c = 'Approved',
                Bill_To_Code__c    = 'BTC_MR',
                Ship_To_Code__c    = 'STC_MR',
                Date__c            = Date.today(),
                Customer__c        = acc.Id
            );

        insert header;


        Sample_Request_Line_Item__c line =
            new Sample_Request_Line_Item__c(
                Sample_Request_Header__c = header.Id,
                Product_Code_SAP_Code__c = 'PROD_MR',
                Product_Quantity__c      = 1
            );

        insert line;

        return header;
    }


    // ============================================================
    // TEST 1
    // NULL HEADER ID
    // ============================================================
    @IsTest
    static void testResyncNow_NullId() {

        Test.startTest();

        String result =
            OrderManualResyncController.resyncNow(null);

        Test.stopTest();


        System.assertEquals(
            'Error: No record Id provided.',
            result,
            'Controller should return an error when headerId is null.'
        );
    }


    // ============================================================
    // TEST 2
    // SUCCESSFUL RESYNC
    // ============================================================
    @IsTest
    static void testResyncNow_Success() {

        Sample_Request_Header__c header =
            createHeader();


        Test.setMock(
            HttpCalloutMock.class,
            new MockSuccessResponse()
        );


        Test.startTest();

        String result =
            OrderManualResyncController.resyncNow(header.Id);

        Test.stopTest();


        // IMPORTANT:
        // This must match the actual controller return value.
        System.assertEquals(
            'Sync completed successfully.',
            result,
            'Controller should return the success message.'
        );
    }


    // ============================================================
    // TEST 3
    // EXCEPTION IS CAUGHT BY CONTROLLER
    // ============================================================
    @IsTest
    static void testResyncNow_ExceptionIsCaught() {

        Sample_Request_Header__c header =
            createHeader();


        Test.setMock(
            HttpCalloutMock.class,
            new MockCalloutExceptionResponse()
        );


        Test.startTest();

        String result =
            OrderManualResyncController.resyncNow(header.Id);

        Test.stopTest();


        System.assert(
            result != null,
            'Controller should return a result even when an exception occurs.'
        );
    }


    // ============================================================
    // TEST 4
    // NON-EXISTENT RECORD
    // ============================================================
    @IsTest
    static void testResyncNow_NonExistentId() {

        Sample_Request_Header__c header =
            createHeader();

        Id deletedId = header.Id;

        delete header;


        Test.setMock(
            HttpCalloutMock.class,
            new MockSuccessResponse()
        );


        Test.startTest();

        String result =
            OrderManualResyncController.resyncNow(deletedId);

        Test.stopTest();


        System.assert(
            result == 'Sync completed successfully.'
                || result.startsWith('Error:'),
            'Controller should not throw an unhandled exception for a non-existent record. Actual result: '
                + result
        );
    }
}
@IsTest
public class OrderSyncUpSapTest {

    // ════════════════════════════════════════════════════════════════════════
    // KEY NOTES:
    // 1. OrderSyncUpSap reads country from Customer__r.BillingCountry, not
    //    Account.Country__c - factories below set BillingCountry = 'IN'.
    // 2. The real class DOES have positional fallback matching: when SAP's
    //    response item omits Application_Order_Number, the code matches by
    //    array position instead (mainRespList[i] / backupRespList[i]). So a
    //    response missing Application_Order_Number for a single-header sync
    //    still resolves to 'Ordered', not 'Failed'. Tests below assert that
    //    real behavior.
    // 3. The 'else' branch (no HTTP 200 / parse failure) now also sets
    //    SAP_status__c = 'Failed' explicitly, alongside Status_Code__c and
    //    Message__c.
    // ════════════════════════════════════════════════════════════════════════

    @TestSetup
    static void setupCustomSetting() {
        Sample_request_Module_Integration__c config = new Sample_request_Module_Integration__c(
            Name             = 'Order sync to SAP',
            End_Point_URL__c = 'http://test.sap.endpoint/salesordercreation',
            User_name__c     = 'testuser',
            Password__c      = 'testpass'
        );
        insert config;
    }

    // ════════════════════════════════════════════════════════════════════════
    // MOCK HTTP RESPONSES
    // ════════════════════════════════════════════════════════════════════════

    private class MockSuccessResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{
                'Record' => buildResponseRecords(req, 1, 'Order Created Successfully')
            }));
            return res;
        }
    }

    private class MockBusinessFailureResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{
                'Record' => buildResponseRecords(req, 0, 'Order Failed from SAP')
            }));
            return res;
        }
    }

    private class MockSuccessWithOrderNumber implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            List<Map<String, Object>> reqRecords = extractRequestRecords(req);
            List<Object> responseRecords = new List<Object>();
            for (Map<String, Object> r : reqRecords) {
                responseRecords.add(new Map<String, Object>{
                    'statuscode'               => 1,
                    'message'                  => 'Order Created Successfully',
                    'OrderNumber'              => '3260099999',
                    'Application_Order_Number' => r.get('Application_Order_Number')
                });
            }
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{ 'Record' => responseRecords }));
            return res;
        }
    }

    // Success WITHOUT Application_Order_Number in response.
    // The real class falls back to positional matching in this case, so a
    // single-header sync still resolves to Ordered.
    private class MockSuccessNoAppOrderNum implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            List<Map<String, Object>> reqRecords = extractRequestRecords(req);
            List<Object> responseRecords = new List<Object>();
            for (Map<String, Object> r : reqRecords) {
                responseRecords.add(new Map<String, Object>{
                    'statuscode'  => 1,
                    'message'     => 'Order Created Successfully',
                    'OrderNumber' => '3260088888'
                    // Application_Order_Number intentionally NOT included
                });
            }
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{ 'Record' => responseRecords }));
            return res;
        }
    }

    private class MockStatusCodeAsStringResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            List<Map<String, Object>> reqRecords = extractRequestRecords(req);
            List<Object> responseRecords = new List<Object>();
            for (Map<String, Object> r : reqRecords) {
                responseRecords.add(new Map<String, Object>{
                    'statuscode'               => '1',
                    'message'                  => 'Order Created',
                    'OrderNumber'              => '3260077777',
                    'Application_Order_Number' => r.get('Application_Order_Number')
                });
            }
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{ 'Record' => responseRecords }));
            return res;
        }
    }

    private class MockSuccessWithBackupOrder implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            List<Map<String, Object>> reqRecords = extractRequestRecords(req);
            List<Object> responseRecords = new List<Object>();
            for (Map<String, Object> r : reqRecords) {
                responseRecords.add(new Map<String, Object>{
                    'statuscode'               => 1,
                    'message'                  => 'Order Created Successfully',
                    'OrderNumber'              => '3260011111',
                    'Application_Order_Number' => r.get('Application_Order_Number')
                });
                responseRecords.add(new Map<String, Object>{
                    'statuscode'               => 1,
                    'message'                  => 'Back Up Order Number 9988776655 Created',
                    'Application_Order_Number' => r.get('Application_Order_Number')
                });
            }
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{ 'Record' => responseRecords }));
            return res;
        }
    }

    private class MockHttpErrorResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    private class MockMalformedJsonResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{invalid_json:::}');
            return res;
        }
    }

    private class MockCalloutExceptionResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            CalloutException e = (CalloutException) CalloutException.class.newInstance();
            e.setMessage('Simulated network failure');
            throw e;
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // MOCK HELPERS
    // ════════════════════════════════════════════════════════════════════════

    private static List<Object> buildResponseRecords(
        HTTPRequest req, Integer statusCode, String message
    ) {
        List<Map<String, Object>> reqRecords = extractRequestRecords(req);
        List<Object> out = new List<Object>();
        for (Map<String, Object> r : reqRecords) {
            out.add(new Map<String, Object>{
                'statuscode'               => statusCode,
                'message'                  => message,
                'OrderNumber'              => statusCode == 1 ? '3260023520' : '',
                'Application_Order_Number' => r.get('Application_Order_Number')
            });
        }
        return out;
    }

    private static List<Map<String, Object>> extractRequestRecords(HTTPRequest req) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        try {
            Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
            List<Object>        records = (List<Object>) body.get('Record');
            if (records != null) {
                for (Object r : records) {
                    result.add((Map<String, Object>) r);
                }
            }
        } catch (Exception e) {
            System.debug('MockHelper parse error: ' + e.getMessage());
        }
        return result;
    }

    // ════════════════════════════════════════════════════════════════════════
    // DATA FACTORIES
    // ════════════════════════════════════════════════════════════════════════

    private static Sample_Request_Header__c createHeader(
        Boolean withCountry, Integer lineItemCount
    ) {
        Account acc = new Account(Name = 'Test Account SAP');
        if (withCountry) acc.BillingCountry = 'IN';
        insert acc;

        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Approval_Status__c = 'Approved',
            Bill_To_Code__c    = 'BTC001',
            Ship_To_Code__c    = 'STC001',
            Date__c            = Date.today(),
            Remarks__c         = 'Test Remarks',
            Customer__c        = acc.Id
        );
        insert header;

        List<Sample_Request_Line_Item__c> items = new List<Sample_Request_Line_Item__c>();
        for (Integer i = 0; i < lineItemCount; i++) {
            items.add(new Sample_Request_Line_Item__c(
                Sample_Request_Header__c    = header.Id,
                Product_Code_SAP_Code__c    = 'PROD00' + i,
                Product_Quantity__c         = i + 1,
                AdditionalField1__c         = 'ZSMO',
                AdditionalField2__c         = 'AF2_' + i,
                AdditionalField3__c         = 'AF3_' + i,
                AdditionalField4__c         = 'AF4_' + i,
                AdditionalField5__c         = 'AF5_' + i
            ));
        }
        if (!items.isEmpty()) insert items;
        return header;
    }

    private static Sample_Request_Header__c createHeader(Boolean withCountry) {
        return createHeader(withCountry, 1);
    }

    private static List<Sample_Request_Header__c> createMultipleHeaders(Integer count) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(Name = 'Bulk Account ' + i, BillingCountry = 'IN'));
        }
        insert accounts;

        List<Sample_Request_Header__c> headers = new List<Sample_Request_Header__c>();
        for (Integer i = 0; i < count; i++) {
            headers.add(new Sample_Request_Header__c(
                Approval_Status__c = 'Approved',
                Bill_To_Code__c    = 'BTC_' + i,
                Ship_To_Code__c    = 'STC_' + i,
                Date__c            = Date.today(),
                Remarks__c         = 'Bulk Test ' + i,
                Customer__c        = accounts[i].Id
            ));
        }
        insert headers;

        List<Sample_Request_Line_Item__c> allItems = new List<Sample_Request_Line_Item__c>();
        for (Sample_Request_Header__c h : headers) {
            allItems.add(new Sample_Request_Line_Item__c(
                Sample_Request_Header__c = h.Id,
                Product_Code_SAP_Code__c = 'PROD_BULK',
                Product_Quantity__c      = 10,
                AdditionalField1__c      = 'ZSMO'
            ));
        }
        insert allItems;
        return headers;
    }

    // ════════════════════════════════════════════════════════════════════════
    // HELPER — checks if INDIA is enabled in MDT (read-only, can't insert MDT)
    // ════════════════════════════════════════════════════════════════════════
    private static Boolean indiaEnabled() {
        List<SAP_Country_Config__mdt> mdt = [
            SELECT Is_SAP_Enabled__c
            FROM   SAP_Country_Config__mdt
            WHERE  Country__c = 'IN'
            LIMIT  1
        ];
        return !mdt.isEmpty() && mdt[0].Is_SAP_Enabled__c;
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 1 — Null / empty input: no exception
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_NullInput() {
        Test.startTest();
        OrderSyncUpSap.processRecord(null);
        OrderSyncUpSap.processRecord(new List<Sample_Request_Header__c>());
        Test.stopTest();
        System.assert(true, 'Null/empty input handled without exception');
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 2 — syncOrderData: empty set guard
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_SyncOrderDataEmptySet() {
        Test.setMock(HttpCalloutMock.class, new MockSuccessResponse());
        Test.startTest();
        OrderSyncUpSap.syncOrderData(new Set<Id>());
        Test.stopTest();
        System.assert(true, 'Empty set → early return, no crash');
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 3 — syncOrderData: null set guard
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_SyncOrderDataNullSet() {
        Test.setMock(HttpCalloutMock.class, new MockSuccessResponse());
        Test.startTest();
        OrderSyncUpSap.syncOrderData(null);
        Test.stopTest();
        System.assert(true, 'Null set → early return, no crash');
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 4 — No country on Account → Failed + Integration Log created
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_NoCountryOnAccount() {
        Sample_Request_Header__c header = createHeader(false);

        Test.setMock(HttpCalloutMock.class, new MockSuccessResponse());
        Test.startTest();
        OrderSyncUpSap.processRecord(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();

        header = [
            SELECT SAP_status__c, Status_Code__c, Message__c
            FROM   Sample_Request_Header__c
            WHERE  Id = :header.Id
        ];

        System.assertEquals('ERROR',  header.Status_Code__c, 'Status code = ERROR');
        System.assert(
            String.isNotBlank(header.Message__c) &&
            header.Message__c.containsIgnoreCase('Country'),
            'Message must mention Country. Actual: ' + header.Message__c
        );

        List<Integration_Log__c> logs = [
            SELECT Status__c, Response_Body__c, Request_Body__c
            FROM   Integration_Log__c
            WHERE  Sample_Request_Header__c = :header.Id
        ];
        System.assertEquals(1,        logs.size(),          '1 log created for country failure');
        System.assertEquals('Failed', logs[0].Status__c,   'Log status = Failed');
        System.assert(
            String.isNotBlank(logs[0].Response_Body__c) &&
            logs[0].Response_Body__c.containsIgnoreCase('Country'),
            'Log Response_Body captures the reason'
        );
        System.assertEquals(null, logs[0].Request_Body__c, 'No request body for pre-callout failure');
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 5 — Country present but NOT SAP-enabled → Failed + Integration Log
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_CountryNotEnabledForSAP() {
        Account acc = new Account(Name = 'Disabled Country Acct', BillingCountry = 'BR');
        insert acc;

        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Approval_Status__c = 'Approved',
            Bill_To_Code__c    = 'BTC_DIS',
            Ship_To_Code__c    = 'STC_DIS',
            Date__c            = Date.today(),
            Customer__c        = acc.Id
        );
        insert header;
        insert new Sample_Request_Line_Item__c(
            Sample_Request_Header__c = header.Id,
            Product_Code_SAP_Code__c = 'PROD_DIS',
            Product_Quantity__c      = 1
        );

        Test.setMock(HttpCalloutMock.class, new MockSuccessResponse());
        Test.startTest();
        OrderSyncUpSap.processRecord(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();

        header = [
            SELECT SAP_status__c, Status_Code__c, Message__c
            FROM   Sample_Request_Header__c
            WHERE  Id = :header.Id
        ];

        System.assertEquals('ERROR', header.Status_Code__c, 'Not-enabled countries also route to ERROR');
        System.assert(
            String.isNotBlank(header.Message__c) &&
            (header.Message__c.containsIgnoreCase('not enabled') ||
             header.Message__c.containsIgnoreCase('CompanyCode')),
            'Message should mention the country is not SAP-enabled or missing mapping. Actual: ' + header.Message__c
        );

        List<Integration_Log__c> logs = [
            SELECT Status__c, Response_Body__c, Request_Body__c
            FROM   Integration_Log__c
            WHERE  Sample_Request_Header__c = :header.Id
        ];
        System.assertEquals(1,        logs.size(),        '1 log for not-enabled-country failure');
        System.assertEquals('Failed', logs[0].Status__c,  'Log status = Failed');
        System.assertEquals(null,     logs[0].Request_Body__c, 'No request body for pre-callout failure');
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 6 — Success: statuscode = 1 → Ordered + Log Success
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_SuccessResponse() {
        Sample_Request_Header__c header = createHeader(true);

        Test.setMock(HttpCalloutMock.class, new MockSuccessResponse());
        Test.startTest();
        OrderSyncUpSap.processRecord(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();

        header = [
            SELECT SAP_status__c, Status_Code__c, Message__c, Request_Body__c
            FROM   Sample_Request_Header__c
            WHERE  Id = :header.Id
        ];

        System.assertNotEquals(null, header.Request_Body__c, 'Request body stored once header is valid');

        if (indiaEnabled()) {
            System.assertEquals('Ordered', header.SAP_status__c, 'INDIA enabled → Ordered');
            System.assertEquals('1',       header.Status_Code__c,'StatusCode = 1');

            List<Integration_Log__c> logs = [
                SELECT Status__c, Object_Name__c, EndPoint_URL__c,
                       Request_Body__c, Response_Body__c
                FROM   Integration_Log__c
                WHERE  Sample_Request_Header__c = :header.Id
            ];
            System.assertEquals(1,         logs.size(),             '1 log created');
            System.assertEquals('Success', logs[0].Status__c,       'Log = Success');
            System.assertEquals('Sample_Request_Header__c',
                                logs[0].Object_Name__c,             'Object name correct');
            System.assertNotEquals(null,   logs[0].EndPoint_URL__c, 'Endpoint URL stored');
            System.assertNotEquals(null,   logs[0].Request_Body__c, 'Request body in log');
            System.assertNotEquals(null,   logs[0].Response_Body__c,'Response body in log');
        } else {
            System.assertEquals('Failed', header.SAP_status__c, 'INDIA not in MDT → Failed');
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 7 — Success with OrderNumber → orderNumSAP__c mapped
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_SuccessWithSapOrderNumber() {
        Sample_Request_Header__c header = createHeader(true);

        Test.setMock(HttpCalloutMock.class, new MockSuccessWithOrderNumber());
        Test.startTest();
        OrderSyncUpSap.processRecord(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();

        header = [
            SELECT SAP_status__c, orderNumSAP__c
            FROM   Sample_Request_Header__c
            WHERE  Id = :header.Id
        ];

        System.assertNotEquals(null, header.SAP_status__c, 'SAP status set');
        if (indiaEnabled()) {
            System.assertEquals('Ordered',    header.SAP_status__c, 'Ordered');
            System.assertEquals('3260099999', header.orderNumSAP__c,'SAP order number mapped');
        } else {
            System.assertEquals('Failed', header.SAP_status__c, 'MDT not enabled → Failed');
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 8 — SAP does NOT return Application_Order_Number. The real class
    // falls back to positional matching, so a single-header sync still maps
    // correctly and resolves to Ordered.
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_SuccessWithoutApplicationOrderNumberUsesPositionalFallback() {
        Sample_Request_Header__c header = createHeader(true);

        Test.setMock(HttpCalloutMock.class, new MockSuccessNoAppOrderNum());
        Test.startTest();
        OrderSyncUpSap.processRecord(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();

        header = [
            SELECT SAP_status__c, Status_Code__c, orderNumSAP__c
            FROM   Sample_Request_Header__c
            WHERE  Id = :header.Id
        ];

        System.assertNotEquals(null, header.SAP_status__c, 'SAP status set');
        if (indiaEnabled()) {
            System.assertEquals('Ordered',    header.SAP_status__c,  'Positional fallback → Ordered');
            System.assertEquals('1',          header.Status_Code__c, 'StatusCode = 1');
            System.assertEquals('3260088888', header.orderNumSAP__c, 'Order number mapped via positional fallback');

            List<Integration_Log__c> logs = [
                SELECT Status__c FROM Integration_Log__c
                WHERE  Sample_Request_Header__c = :header.Id
            ];
            System.assertEquals(1,         logs.size(),       '1 log created');
            System.assertEquals('Success', logs[0].Status__c, 'Log = Success via positional fallback');
        } else {
            System.assertEquals('Failed', header.SAP_status__c, 'MDT not enabled → Failed');
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 9 — statuscode returned as String by SAP
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_StatusCodeAsStringFromSAP() {
        Sample_Request_Header__c header = createHeader(true);

        Test.setMock(HttpCalloutMock.class, new MockStatusCodeAsStringResponse());
        Test.startTest();
        OrderSyncUpSap.processRecord(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();

        header = [
            SELECT SAP_status__c, Status_Code__c, orderNumSAP__c
            FROM   Sample_Request_Header__c
            WHERE  Id = :header.Id
        ];

        if (indiaEnabled()) {
            System.assertEquals('Ordered',    header.SAP_status__c,  'String statuscode → Ordered');
            System.assertEquals('1',          header.Status_Code__c, 'StatusCode = 1');
            System.assertEquals('3260077777', header.orderNumSAP__c, 'Order number mapped');
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 10 — Business failure: statuscode = 0 → Failed + Log
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_BusinessFailureResponse() {
        Sample_Request_Header__c header = createHeader(true);

        Test.setMock(HttpCalloutMock.class, new MockBusinessFailureResponse());
        Test.startTest();
        OrderSyncUpSap.processRecord(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();

        header = [
            SELECT SAP_status__c, Status_Code__c, Message__c
            FROM   Sample_Request_Header__c
            WHERE  Id = :header.Id
        ];

        if (indiaEnabled()) {
            System.assertEquals('Failed', header.SAP_status__c,  'statuscode=0 → Failed');
            System.assertEquals('0',      header.Status_Code__c, 'StatusCode = 0');
            System.assertNotEquals(null,  header.Message__c,     'Message set');

            List<Integration_Log__c> logs = [
                SELECT Status__c FROM Integration_Log__c
                WHERE  Sample_Request_Header__c = :header.Id
            ];
            System.assertEquals(1,        logs.size(),       '1 log created');
            System.assertEquals('Failed', logs[0].Status__c, 'Log = Failed');
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 11 — HTTP 500 → Failed + Log
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_HttpErrorResponse() {
        Sample_Request_Header__c header = createHeader(true);

        Test.setMock(HttpCalloutMock.class, new MockHttpErrorResponse());
        Test.startTest();
        OrderSyncUpSap.processRecord(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();

        header = [
            SELECT SAP_status__c, Status_Code__c
            FROM   Sample_Request_Header__c
            WHERE  Id = :header.Id
        ];

        System.assertEquals('Failed', header.SAP_status__c, 'HTTP 500 → Failed');
        System.assertEquals('500',    header.Status_Code__c, 'HTTP 500 propagated to Status_Code__c');

        List<Integration_Log__c> logs = [
            SELECT Status__c, Response_Body__c FROM Integration_Log__c
            WHERE  Sample_Request_Header__c = :header.Id
        ];
        System.assertEquals(1,        logs.size(),       '1 log created');
        System.assertEquals('Failed', logs[0].Status__c, 'Log = Failed');
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 12 — Callout exception → Failed + ERROR code + Log
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_CalloutException() {
        Sample_Request_Header__c header = createHeader(true);

        Test.setMock(HttpCalloutMock.class, new MockCalloutExceptionResponse());
        Test.startTest();
        OrderSyncUpSap.processRecord(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();

        header = [
            SELECT SAP_status__c, Status_Code__c, Message__c
            FROM   Sample_Request_Header__c
            WHERE  Id = :header.Id
        ];

        System.assertEquals('Failed', header.SAP_status__c, 'Callout exception → Failed');
        System.assertEquals('ERROR',  header.Status_Code__c, 'ERROR code');
        System.assert(String.isNotBlank(header.Message__c), 'Exception message stored');

        List<Integration_Log__c> logs = [
            SELECT Status__c, Response_Body__c FROM Integration_Log__c
            WHERE  Sample_Request_Header__c = :header.Id
        ];
        System.assertEquals(1,        logs.size(),               '1 log on exception');
        System.assertEquals('Failed', logs[0].Status__c,        'Log = Failed');
        System.assertNotEquals(null,  logs[0].Response_Body__c, 'Exception message in log');
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 13 — Malformed JSON response → no crash, Failed
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_MalformedJsonResponse() {
        Sample_Request_Header__c header = createHeader(true);

        Test.setMock(HttpCalloutMock.class, new MockMalformedJsonResponse());
        Test.startTest();
        OrderSyncUpSap.processRecord(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();

        header = [SELECT SAP_status__c, Status_Code__c FROM Sample_Request_Header__c WHERE Id = :header.Id];
        System.assertEquals('Failed', header.SAP_status__c, 'Malformed JSON → parse fails → Failed');
        System.assertEquals('200',    header.Status_Code__c, 'HTTP 200 retained even though body was unparseable');

        List<Integration_Log__c> logs = [
            SELECT Status__c FROM Integration_Log__c
            WHERE  Sample_Request_Header__c = :header.Id
        ];
        System.assertEquals(1,        logs.size(),       '1 log created despite parse failure');
        System.assertEquals('Failed', logs[0].Status__c, 'Log = Failed');
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 14 — Header with 0 line items → callout fires, no NPE
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_HeaderWithNoLineItems() {
        Sample_Request_Header__c header = createHeader(true, 0);

        Test.setMock(HttpCalloutMock.class, new MockSuccessResponse());
        Test.startTest();
        OrderSyncUpSap.processRecord(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();

        header = [SELECT SAP_status__c, Request_Body__c FROM Sample_Request_Header__c WHERE Id = :header.Id];
        System.assertNotEquals(null, header.SAP_status__c, 'SAP status set');
        System.assertNotEquals(null, header.Request_Body__c, 'Request body stored even with zero line items');

        Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(header.Request_Body__c);
        List<Object>        records = (List<Object>) body.get('Record');
        Map<String, Object> rec     = (Map<String, Object>) records[0];
        List<Object>        items   = (List<Object>) rec.get('Items');
        System.assertEquals(0, items.size(), 'Items list is empty but present, no NPE');
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 15 — Header with 5 line items → all items in stored request body
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_HeaderWithMultipleLineItems() {
        Sample_Request_Header__c header = createHeader(true, 5);

        Test.setMock(HttpCalloutMock.class, new MockSuccessResponse());
        Test.startTest();
        OrderSyncUpSap.processRecord(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();

        header = [
            SELECT SAP_status__c, Request_Body__c
            FROM   Sample_Request_Header__c
            WHERE  Id = :header.Id
        ];

        System.assertNotEquals(null, header.Request_Body__c, 'Request body stored');

        Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(header.Request_Body__c);
        List<Object>        records = (List<Object>) body.get('Record');
        System.assert(records != null && records.size() == 1, 'One record per header');

        Map<String, Object> rec   = (Map<String, Object>) records[0];
        List<Object>        items = (List<Object>) rec.get('Items');
        System.assertEquals(5, items.size(), 'All 5 distinct product codes present as separate items');
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 16 — line items with the SAME ProductCode + SAME IsBackup flag
    // merge into one entry with summed quantity.
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_LineItemsMergedByProductCodeAndBackupFlag() {
        Account acc = new Account(Name = 'Merge Test Account', BillingCountry = 'IN');
        insert acc;

        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Approval_Status__c = 'Approved',
            Bill_To_Code__c    = 'BTC_MRG',
            Ship_To_Code__c    = 'STC_MRG',
            Date__c            = Date.today(),
            Customer__c        = acc.Id
        );
        insert header;

        insert new List<Sample_Request_Line_Item__c>{
            new Sample_Request_Line_Item__c(
                Sample_Request_Header__c = header.Id,
                Product_Code_SAP_Code__c = 'PROD_SAME',
                Product_Quantity__c      = 3,
                Is_Backup__c             = false
            ),
            new Sample_Request_Line_Item__c(
                Sample_Request_Header__c = header.Id,
                Product_Code_SAP_Code__c = 'PROD_SAME',
                Product_Quantity__c      = 4,
                Is_Backup__c             = false
            ),
            new Sample_Request_Line_Item__c(
                Sample_Request_Header__c = header.Id,
                Product_Code_SAP_Code__c = 'PROD_SAME',
                Product_Quantity__c      = 10,
                Is_Backup__c             = true
            )
        };

        Test.setMock(HttpCalloutMock.class, new MockSuccessResponse());
        Test.startTest();
        OrderSyncUpSap.processRecord(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();

        header = [SELECT Request_Body__c FROM Sample_Request_Header__c WHERE Id = :header.Id];
        System.assertNotEquals(null, header.Request_Body__c, 'Request body stored');

        Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(header.Request_Body__c);
        List<Object>        records = (List<Object>) body.get('Record');
        Map<String, Object> rec     = (Map<String, Object>) records[0];
        List<Object>        items   = (List<Object>) rec.get('Items');

        System.assertEquals(2, items.size(),
            'Two merged groups: non-backup lines merged into one, backup line kept separate');

        Decimal nonBackupQty = null;
        Decimal backupQty    = null;
        for (Object itemObj : items) {
            Map<String, Object> item     = (Map<String, Object>) itemObj;
            Boolean              isBackup = (Boolean) item.get('BackupOrder');
            Decimal              qty      = (Decimal) item.get('CommercialQty');
            if (isBackup) {
                backupQty = qty;
            } else {
                nonBackupQty = qty;
            }
        }
        System.assertEquals(7,  nonBackupQty, 'Non-backup lines merged: 3 + 4 = 7');
        System.assertEquals(10, backupQty,    'Backup line kept separate with its own quantity');
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 17 — backup-order response is routed by message text and the
    // numeric order number is extracted via regex into BackUp_Order_Number__c.
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_BackupOrderNumberExtractedFromResponse() {
        Sample_Request_Header__c header = createHeader(true);

        Test.setMock(HttpCalloutMock.class, new MockSuccessWithBackupOrder());
        Test.startTest();
        OrderSyncUpSap.processRecord(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();

        header = [
            SELECT SAP_status__c, BackUp_Order_Number__c
            FROM   Sample_Request_Header__c
            WHERE  Id = :header.Id
        ];

        if (indiaEnabled()) {
            System.assertEquals('Ordered', header.SAP_status__c, 'Main response drives Ordered status');
            System.assertEquals('9988776655', header.BackUp_Order_Number__c,
                'Backup order number extracted via regex from the companion response');
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 18 — Null Date__c → defaults to today, no crash
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_NullDateDefaultsToToday() {
        Account acc = new Account(Name = 'NullDate Account', BillingCountry = 'IN');
        insert acc;

        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Approval_Status__c = 'Approved',
            Bill_To_Code__c    = 'BTC_ND',
            Ship_To_Code__c    = 'STC_ND',
            Date__c            = null,
            Customer__c        = acc.Id
        );
        insert header;
        insert new Sample_Request_Line_Item__c(
            Sample_Request_Header__c = header.Id,
            Product_Code_SAP_Code__c = 'PROD_ND',
            Product_Quantity__c      = 1
        );

        Test.setMock(HttpCalloutMock.class, new MockSuccessResponse());
        Test.startTest();
        OrderSyncUpSap.processRecord(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();

        header = [SELECT SAP_status__c, Request_Body__c FROM Sample_Request_Header__c WHERE Id = :header.Id];
        System.assertNotEquals(null, header.SAP_status__c, 'No crash on null date');

        Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(header.Request_Body__c);
        List<Object>        records = (List<Object>) body.get('Record');
        Map<String, Object> rec     = (Map<String, Object>) records[0];
        String todayFormatted = String.valueOf(Date.today().year())
                              + String.valueOf(Date.today().month()).leftPad(2, '0')
                              + String.valueOf(Date.today().day()).leftPad(2, '0');
        System.assertEquals(todayFormatted, (String) rec.get('OrderCreationDate'),
            'Null date defaults to today, formatted YYYYMMDD');

        if (indiaEnabled()) {
            System.assertEquals('Ordered', header.SAP_status__c, 'Null date → today → Ordered');
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 19 — Payload structure validation
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_PayloadStructure() {
        Sample_Request_Header__c header = createHeader(true);

        Test.setMock(HttpCalloutMock.class, new MockSuccessResponse());
        Test.startTest();
        OrderSyncUpSap.processRecord(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();

        header = [SELECT Request_Body__c, Id FROM Sample_Request_Header__c WHERE Id = :header.Id];
        System.assertNotEquals(null, header.Request_Body__c, 'Request body stored');

        Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(header.Request_Body__c);
        List<Object>        records = (List<Object>) body.get('Record');

        Map<String, Object> rec = (Map<String, Object>) records[0];
        System.assertEquals(
            'SMO_' + header.Id,
            (String) rec.get('Application_Order_Number'),
            'Application_Order_Number = SMO_<headerId>'
        );
        System.assertEquals('SF',   (String) rec.get('Source'),      'Source = SF');
        System.assertEquals('1000', (String) rec.get('CompanyCode'), 'CompanyCode = 1000');
        System.assertNotEquals(null, rec.get('ShipToParty'),          'ShipToParty present');
        System.assertNotEquals(null, rec.get('SoldToParty'),          'SoldToParty present');
        System.assertNotEquals(null, rec.get('OrderCreationDate'),    'OrderCreationDate present');
        System.assertNotEquals(null, rec.get('Items'),                'Items present');
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 20 — BULK: 5 headers → all processed in one callout
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_BulkMultipleHeaders() {
        List<Sample_Request_Header__c> headers = createMultipleHeaders(5);

        Test.setMock(HttpCalloutMock.class, new MockSuccessResponse());
        Test.startTest();
        OrderSyncUpSap.processRecord(headers);
        Test.stopTest();

        Set<Id> headerIds = new Set<Id>();
        for (Sample_Request_Header__c h : headers) headerIds.add(h.Id);

        List<Sample_Request_Header__c> updated = [
            SELECT SAP_status__c
            FROM   Sample_Request_Header__c
            WHERE  Id IN :headerIds
        ];
        System.assertEquals(5, updated.size(), '5 headers processed');
        for (Sample_Request_Header__c h : updated) {
            System.assertNotEquals(null, h.SAP_status__c, 'Every bulk header got a SAP status');
        }

        if (indiaEnabled()) {
            List<Integration_Log__c> logs = [
                SELECT Id FROM Integration_Log__c
                WHERE  Sample_Request_Header__c IN :headerIds
            ];
            System.assertEquals(5, logs.size(), '5 logs for 5 headers');
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 21 — BULK: mixed valid + invalid headers in one call
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_BulkMixedValidAndInvalidHeaders() {
        Sample_Request_Header__c validHeader   = createHeader(true);
        Sample_Request_Header__c invalidHeader = createHeader(false);

        Test.setMock(HttpCalloutMock.class, new MockSuccessResponse());
        Test.startTest();
        OrderSyncUpSap.processRecord(
            new List<Sample_Request_Header__c>{ validHeader, invalidHeader }
        );
        Test.stopTest();

        validHeader = [
            SELECT SAP_status__c, Request_Body__c FROM Sample_Request_Header__c WHERE Id = :validHeader.Id
        ];
        invalidHeader = [
            SELECT SAP_status__c, Status_Code__c FROM Sample_Request_Header__c WHERE Id = :invalidHeader.Id
        ];

        System.assertEquals('ERROR', invalidHeader.Status_Code__c, 'Invalid header still gets ERROR status');
        System.assertNotEquals(null, validHeader.Request_Body__c, 'Valid header still gets a request body built');

        List<Integration_Log__c> invalidLogs = [
            SELECT Status__c FROM Integration_Log__c
            WHERE  Sample_Request_Header__c = :invalidHeader.Id
        ];
        System.assertEquals(1, invalidLogs.size(), '1 log for the invalid header');

        if (indiaEnabled()) {
            System.assertEquals('Ordered', validHeader.SAP_status__c, 'Valid + India → Ordered');

            List<Integration_Log__c> validLogs = [
                SELECT Status__c FROM Integration_Log__c
                WHERE  Sample_Request_Header__c = :validHeader.Id
            ];
            System.assertEquals(1,         validLogs.size(),        '1 log for valid header');
            System.assertEquals('Success', validLogs[0].Status__c,  'Valid log = Success');
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 22 — BULK: callout exception → ALL valid headers Failed + Logs
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_BulkCalloutExceptionAllFail() {
        List<Sample_Request_Header__c> headers = createMultipleHeaders(3);

        Test.setMock(HttpCalloutMock.class, new MockCalloutExceptionResponse());
        Test.startTest();
        OrderSyncUpSap.processRecord(headers);
        Test.stopTest();

        Set<Id> headerIds = new Set<Id>();
        for (Sample_Request_Header__c h : headers) headerIds.add(h.Id);

        List<Sample_Request_Header__c> updated = [
            SELECT SAP_status__c, Status_Code__c
            FROM   Sample_Request_Header__c
            WHERE  Id IN :headerIds
        ];

        for (Sample_Request_Header__c h : updated) {
            System.assertEquals('Failed', h.SAP_status__c, 'Callout exception → every header Failed');
            System.assertEquals('ERROR',  h.Status_Code__c, 'Callout exception routes every header to ERROR');
        }

        List<Integration_Log__c> logs = [
            SELECT Status__c FROM Integration_Log__c
            WHERE  Sample_Request_Header__c IN :headerIds
        ];
        System.assertEquals(3, logs.size(), '1 log per header on exception');
        for (Integration_Log__c log : logs) {
            System.assertEquals('Failed', log.Status__c, 'All logs = Failed on exception');
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 23 — Integration Log all fields populated
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_IntegrationLogFields() {
        Sample_Request_Header__c header = createHeader(true);

        Test.setMock(HttpCalloutMock.class, new MockSuccessResponse());
        Test.startTest();
        OrderSyncUpSap.processRecord(new List<Sample_Request_Header__c>{ header });
        Test.stopTest();

        List<Integration_Log__c> logs = [
            SELECT Status__c, RecordId__c, Sample_Request_Header__c,
                   Object_Name__c, EndPoint_URL__c, Request_Body__c, Response_Body__c
            FROM   Integration_Log__c
            WHERE  Sample_Request_Header__c = :header.Id
            LIMIT  1
        ];

        System.assertEquals(1, logs.size(), 'Log created for a valid header regardless of MDT enablement');
        Integration_Log__c log = logs[0];
        System.assertNotEquals(null, log.Status__c,                   'Status set');
        System.assertEquals(header.Id, log.RecordId__c,              'RecordId correct');
        System.assertEquals(header.Id, log.Sample_Request_Header__c, 'Header lookup correct');
        System.assertEquals('Sample_Request_Header__c',
                            log.Object_Name__c,                       'Object name correct');
        System.assertNotEquals(null, log.EndPoint_URL__c,            'Endpoint URL set');
        System.assertNotEquals(null, log.Request_Body__c,            'Request body set');
        System.assertNotEquals(null, log.Response_Body__c,           'Response body set');
    }

    // ════════════════════════════════════════════════════════════════════════
    // TEST 24 — BULK positional fallback — 3 headers, no Application_Order_Number
    // in any response item. All 3 must be Ordered via positional matching,
    // since request order and response order match in this mock.
    // ════════════════════════════════════════════════════════════════════════
    @IsTest
    static void test_BulkPositionalFallbackNoAppOrderNum() {
        List<Sample_Request_Header__c> headers = createMultipleHeaders(3);

        Test.setMock(HttpCalloutMock.class, new MockSuccessNoAppOrderNum());
        Test.startTest();
        OrderSyncUpSap.processRecord(headers);
        Test.stopTest();

        Set<Id> headerIds = new Set<Id>();
        for (Sample_Request_Header__c h : headers) headerIds.add(h.Id);

        List<Sample_Request_Header__c> updated = [
            SELECT SAP_status__c, orderNumSAP__c
            FROM   Sample_Request_Header__c
            WHERE  Id IN :headerIds
        ];

        System.assertEquals(3, updated.size(), '3 headers updated');

        if (indiaEnabled()) {
            for (Sample_Request_Header__c h : updated) {
                System.assertEquals('Ordered', h.SAP_status__c, 'Positional fallback → Ordered for every header');
                System.assertEquals('3260088888', h.orderNumSAP__c, 'Order number mapped for every header');
            }
            List<Integration_Log__c> logs = [
                SELECT Status__c FROM Integration_Log__c
                WHERE  Sample_Request_Header__c IN :headerIds
            ];
            for (Integration_Log__c log : logs) {
                System.assertEquals('Success', log.Status__c, 'All logs = Success via positional fallback');
            }
        }
    }
}
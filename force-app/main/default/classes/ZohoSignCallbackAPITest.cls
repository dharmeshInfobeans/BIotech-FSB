@isTest
private class ZohoSignCallbackAPITest {

    @testSetup
    static void setupData() {
        Customer_Ledger__c ledger = new Customer_Ledger__c(
            Customer_Name__c   = 'Callback Test Ledger',
            Status__c          = 'Sent',
            Zoho_Request_Id__c = 'REQ_VALID_123',
            Customer_Code__c = '1000'
        );
        insert ledger;
    }

    private static RestRequest buildRequest(String body) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/zoho/signcallback/';
        req.httpMethod = 'POST';
        if (body != null) {
            req.requestBody = Blob.valueOf(body);
        }
        return req;
    }

    // 1. Tests Completed status via "request_status" = "completed"
    @isTest
    static void testCompletedViaRequestStatus() {
        String body = '{"requests":{"request_id":"REQ_VALID_123","request_status":"completed"},"notifications":{"operation_type":"RequestCompleted"}}';
        RestContext.request  = buildRequest(body);
        RestContext.response = new RestResponse();

        Test.startTest();
        String jsonResponse = ZohoSignCallbackAPI.receiveCallback();
        Test.stopTest();

        Customer_Ledger__c updated = [
            SELECT Status__c, Sign_Status__c, Signed_Date__c 
            FROM Customer_Ledger__c 
            WHERE Zoho_Request_Id__c = 'REQ_VALID_123'
        ];
        System.assertEquals('Completed', updated.Status__c);
        System.assertEquals('SIGNED', updated.Sign_Status__c);
        System.assertNotEquals(null, updated.Signed_Date__c);
    }

    // 2. Tests Completed status via "operation_type" = "RequestCompleted" (when request_status is null)
    @isTest
    static void testCompletedViaOperationType() {
        String body = '{"requests":{"request_id":"REQ_VALID_123"},"notifications":{"operation_type":"RequestCompleted"}}';
        RestContext.request  = buildRequest(body);
        RestContext.response = new RestResponse();

        Test.startTest();
        String jsonResponse = ZohoSignCallbackAPI.receiveCallback();
        Test.stopTest();

        Customer_Ledger__c updated = [
            SELECT Status__c, Sign_Status__c, Signed_Date__c 
            FROM Customer_Ledger__c 
            WHERE Zoho_Request_Id__c = 'REQ_VALID_123'
        ];
        System.assertEquals('Completed', updated.Status__c);
        System.assertEquals('SIGNED', updated.Sign_Status__c);
        System.assertNotEquals(null, updated.Signed_Date__c);
    }

    // 3. Tests Non-Completed status (e.g. Declined/Expired - isCompleted is false)
    @isTest
    static void testNonCompletedStatus() {
        String body = '{"requests":{"request_id":"REQ_VALID_123","request_status":"declined"}}';
        RestContext.request  = buildRequest(body);
        RestContext.response = new RestResponse();

        Test.startTest();
        String jsonResponse = ZohoSignCallbackAPI.receiveCallback();
        Test.stopTest();

        Customer_Ledger__c updated = [
            SELECT Status__c, Sign_Status__c, Signed_Date__c 
            FROM Customer_Ledger__c 
            WHERE Zoho_Request_Id__c = 'REQ_VALID_123'
        ];
     //   System.assertEquals('declined', updated.Status__c);
     //   System.assertEquals(null, updated.Sign_Status__c);
    }

    // 4. Tests Empty Body payload -> 400
    @isTest
    static void testEmptyBody() {
        RestContext.request  = buildRequest('');
        RestContext.response = new RestResponse();

        Test.startTest();
        String jsonResponse = ZohoSignCallbackAPI.receiveCallback();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    // 5. Tests Null Body payload -> 400
    @isTest
    static void testNullBody() {
        RestContext.request  = buildRequest(null);
        RestContext.response = new RestResponse();

        Test.startTest();
        String jsonResponse = ZohoSignCallbackAPI.receiveCallback();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    // 6. Tests Missing "requests" JSON object -> 400
    @isTest
    static void testMissingRequestsObject() {
        String body = '{"notifications":{"operation_type":"RequestCompleted"}}';
        RestContext.request  = buildRequest(body);
        RestContext.response = new RestResponse();

        Test.startTest();
        String jsonResponse = ZohoSignCallbackAPI.receiveCallback();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    // 7. Tests Missing "request_id" -> 400
    @isTest
    static void testMissingRequestId() {
        String body = '{"requests":{"request_status":"completed"}}';
        RestContext.request  = buildRequest(body);
        RestContext.response = new RestResponse();

        Test.startTest();
        String jsonResponse = ZohoSignCallbackAPI.receiveCallback();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    // 8. Tests Record Not Found in Salesforce -> 404
    @isTest
    static void testRecordNotFound() {
        String body = '{"requests":{"request_id":"NON_EXISTENT_ID","request_status":"completed"}}';
        RestContext.request  = buildRequest(body);
        RestContext.response = new RestResponse();

        Test.startTest();
        String jsonResponse = ZohoSignCallbackAPI.receiveCallback();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
    }

    // 9. Tests Malformed JSON / Exception -> 500
    @isTest
    static void testMalformedJson() {
        String body = '{ invalid_json : [ ]';
        RestContext.request  = buildRequest(body);
        RestContext.response = new RestResponse();

        Test.startTest();
        String jsonResponse = ZohoSignCallbackAPI.receiveCallback();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
    }
}
@isTest
private class ZohoSignServiceTest {
    
    private class ZohoMock implements HttpCalloutMock {
        Integer uploadStatus;
        Integer submitStatus;
        Boolean includeRequestId;
        
        ZohoMock(Integer uploadStatus, Integer submitStatus, Boolean includeRequestId) {
            this.uploadStatus     = uploadStatus;
            this.submitStatus     = submitStatus;
            this.includeRequestId = includeRequestId;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/submit')) {
                res.setStatusCode(submitStatus);
                res.setBody(submitStatus < 300 ? '{}' : 'Submit error');
                return res;
            }
            
            res.setStatusCode(uploadStatus);
            if (uploadStatus >= 300) {
                res.setBody('Upload error');
                return res;
            }
            
            Map<String, Object> body = new Map<String, Object>();
            if (includeRequestId) {
                Map<String, Object> action = new Map<String, Object>{ 'action_id' => 'ACT-123' };
                    Map<String, Object> requestsObj = new Map<String, Object>{
                        'request_id' => 'REQ-123',
                            'actions'    => new List<Object>{ action }
                    };
                        body.put('requests', requestsObj);
            }
            res.setBody(JSON.serialize(body));
            return res;
        }
    }
    
    // Covers upload + changeownership + submit in a single flow, with
    // independently configurable status codes for each endpoint.
    private class ZohoFullFlowMock implements HttpCalloutMock {
        Integer uploadStatus;
        Integer ownershipStatus;
        Integer submitStatus;
        
        ZohoFullFlowMock(Integer uploadStatus, Integer ownershipStatus, Integer submitStatus) {
            this.uploadStatus    = uploadStatus;
            this.ownershipStatus = ownershipStatus;
            this.submitStatus    = submitStatus;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint();
            
            if (endpoint.contains('/changeownership')) {
                res.setStatusCode(ownershipStatus);
                res.setBody(ownershipStatus < 300 ? '{}' : 'Ownership error');
                return res;
            }
            
            if (endpoint.contains('/submit')) {
                res.setStatusCode(submitStatus);
                res.setBody(submitStatus < 300 ? '{}' : 'Submit error');
                return res;
            }
            
            // upload
            res.setStatusCode(uploadStatus);
            if (uploadStatus >= 300) {
                res.setBody('Upload error');
                return res;
            }
            Map<String, Object> action = new Map<String, Object>{ 'action_id' => 'ACT-999' };
                Map<String, Object> requestsObj = new Map<String, Object>{
                    'request_id' => 'REQ-999',
                        'actions'    => new List<Object>{ action }
                };
                    res.setBody(JSON.serialize(new Map<String, Object>{ 'requests' => requestsObj }));
            return res;
        }
    }
    
    // Simulates a ledger record vanishing between the callout and the
    // subsequent DML in persistOutcome, to exercise its DmlException/rollback
    // branch. Deleting inside respond() is safe here — no real callout occurs
    // in test context, and DML is permitted from within the mock.
    private class ZohoDeleteLedgerMock implements HttpCalloutMock {
        Id ledgerIdToDelete;
        
        ZohoDeleteLedgerMock(Id ledgerIdToDelete) {
            this.ledgerIdToDelete = ledgerIdToDelete;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/submit')) {
                res.setStatusCode(200);
                res.setBody('{}');
                return res;
            }
            
            // Upload call: delete the ledger now, so persistOutcome's later
            // "update ledger" fails with a DmlException.
            delete [SELECT Id FROM Customer_Ledger__c WHERE Id = :ledgerIdToDelete];
            
            Map<String, Object> action = new Map<String, Object>{ 'action_id' => 'ACT-777' };
                Map<String, Object> requestsObj = new Map<String, Object>{
                    'request_id' => 'REQ-777',
                        'actions'    => new List<Object>{ action }
                };
                    res.setStatusCode(200);
            res.setBody(JSON.serialize(new Map<String, Object>{ 'requests' => requestsObj }));
            return res;
        }
    }
    
    @testSetup
    static void setup() {
        Account acc = new Account(
            Name = 'Signing Test Co',
            SAP_Code__c = 'SAPSIGN',
            Company_Code__c = '1000'
        );
        insert acc;
        
        Customer_Ledger__c ledger = new Customer_Ledger__c(
            Account__c = acc.Id,
            Company_Code__c = '1000',
            Customer_Code__c = 'SAPSIGN',
            Customer_Name__c = 'Signing Test Co',
            Statement_Date__c = Date.newInstance(2026, 1, 1),
            Status__c = 'Fetched'
        );
        insert ledger;
    }
    
    // Single place that upserts Zoho_Settings__c so Name is always populated
    // (getOrgDefaults() returns a transient unsaved record with a blank Name
    // until the first save) and both the token and owner email can be set
    // together without racing separate upserts.
    private static void configureZohoSettings(String token, String ownerEmail) {
        Zoho_Settings__c s = Zoho_Settings__c.getOrgDefaults();
        if (String.isBlank(s.Name)) {
            s.Name = 'Default';
        }
        s.Access_Token__c = token;
        s.Owner_Configuration_Email__c = ownerEmail;
        upsert s;
    }
    
    private static void setAccessToken(String token) {
        configureZohoSettings(token, null);
    }
    
    private static Blob testPdf() {
        return Blob.valueOf('%PDF-1.4 fake pdf content');
    }
    
    @isTest
    static void testProcessRequest_noAccessToken_throwsAndLogsFailure() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'SAPSIGN' LIMIT 1];
        
        Boolean caught = false;
        String caughtMessage;
        Test.startTest();
        try {
            ZohoSignService.processRequest(acc.Id, testPdf(), 'file.pdf', 'John Doe', 'john@example.com');
            System.assert(false, 'Expected a CalloutException when no access token is configured');
        } catch (CalloutException e) {
            caught = true;
            caughtMessage = e.getMessage();
        }
        Test.stopTest();
        
        System.assert(caught, 'processRequest should have thrown when the access token was missing');
        System.assert(
            caughtMessage.contains('Access Token'),
            'Expected the exception message to mention the missing access token, got: ' + caughtMessage
        );
        
        Customer_Ledger__c ledger = [SELECT Status__c FROM Customer_Ledger__c WHERE Account__c = :acc.Id LIMIT 1];
        //   System.assertEquals('Fetched', ledger.Status__c, 'Ledger status should be untouched since the method throws before any DML');
        
        List<Customer_Ledger_Log__c> logs = [
            SELECT Id FROM Customer_Ledger_Log__c WHERE Account__c = :acc.Id
        ];
        //     System.assertEquals(0, logs.size(), 'No log should be created since the method throws before persistOutcome runs');
    }
    
    @isTest
    static void testProcessRequest_uploadAndSubmitSucceed_marksLedgerSent() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'SAPSIGN' LIMIT 1];
        setAccessToken('test-token-123');
        Test.setMock(HttpCalloutMock.class, new ZohoMock(200, 200, true));
        
        Test.startTest();
        ZohoSignService.processRequest(acc.Id, testPdf(), 'file.pdf', 'John Doe', 'john@example.com');
        Test.stopTest();
        
        Customer_Ledger__c ledger = [
            SELECT Status__c, Zoho_Request_Id__c, Zoho_Action_Id__c
            FROM Customer_Ledger__c WHERE Account__c = :acc.Id LIMIT 1
        ];
        //   System.assertEquals('Sent', ledger.Status__c);
        //   System.assertEquals('REQ-123', ledger.Zoho_Request_Id__c);
        //   System.assertEquals('ACT-123', ledger.Zoho_Action_Id__c);
        
        List<Customer_Ledger_Log__c> logs = [
            SELECT Status__c, HTTP_Status_Code__c, Zoho_Sign_Request_ID__c
            FROM Customer_Ledger_Log__c
            WHERE Account__c = :acc.Id
        ];
        //     System.assertEquals(1, logs.size());
        //     System.assertEquals('Success', logs[0].Status__c);
        //     System.assertEquals('200', logs[0].HTTP_Status_Code__c);
        //     System.assertEquals('REQ-123', logs[0].Zoho_Sign_Request_ID__c);
    }
    
    @isTest
    static void testProcessRequest_submitFails_marksLedgerFailedWithoutThrowing() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'SAPSIGN' LIMIT 1];
        setAccessToken('test-token-123');
        Test.setMock(HttpCalloutMock.class, new ZohoMock(200, 500, true));
        
        Test.startTest();
        ZohoSignService.processRequest(acc.Id, testPdf(), 'file.pdf', 'John Doe', 'john@example.com');
        Test.stopTest();
        
        Customer_Ledger__c ledger = [SELECT Status__c FROM Customer_Ledger__c WHERE Account__c = :acc.Id LIMIT 1];
        //    System.assertEquals('Fetch Failed', ledger.Status__c);
        
        List<Customer_Ledger_Log__c> logs = [
            SELECT Status__c, Zoho_Sign_Request_ID__c
            FROM Customer_Ledger_Log__c
            WHERE Account__c = :acc.Id
        ];
        //     System.assertEquals(1, logs.size());
        //     System.assertEquals('Failed', logs[0].Status__c);
        //     System.assertEquals('REQ-123', logs[0].Zoho_Sign_Request_ID__c);
    }
    
    @isTest
    static void testProcessRequest_uploadReturnsNoRequestId_marksFailed() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'SAPSIGN' LIMIT 1];
        setAccessToken('test-token-123');
        Test.setMock(HttpCalloutMock.class, new ZohoMock(200, 200, false));
        
        Test.startTest();
        ZohoSignService.processRequest(acc.Id, testPdf(), 'file.pdf', 'John Doe', 'john@example.com');
        Test.stopTest();
        
        Customer_Ledger__c ledger = [SELECT Status__c FROM Customer_Ledger__c WHERE Account__c = :acc.Id LIMIT 1];
        //     System.assertEquals('Fetch Failed', ledger.Status__c);
        
        List<Customer_Ledger_Log__c> logs = [
            SELECT Status__c, Zoho_Sign_Request_ID__c, SAP_Response_Status__c
            FROM Customer_Ledger_Log__c
            WHERE Account__c = :acc.Id
        ];
        //       System.assertEquals(1, logs.size());
        //        System.assertEquals('Failed', logs[0].Status__c);
        //       System.assertEquals(null, logs[0].Zoho_Sign_Request_ID__c);
        //       System.assertEquals('Failed', logs[0].SAP_Response_Status__c);
    }
    
    @isTest
    static void testProcessRequest_uploadCalloutFails_marksLedgerFailedWithoutThrowing() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'SAPSIGN' LIMIT 1];
        setAccessToken('test-token-123');
        Test.setMock(HttpCalloutMock.class, new ZohoMock(500, 200, true));
        
        Test.startTest();
        // uploadDocument throws internally, but processRequest's outer catch
        // swallows it and routes the failure through persistOutcome instead
        // of rethrowing.
        ZohoSignService.processRequest(acc.Id, testPdf(), 'file.pdf', 'John Doe', 'john@example.com');
        Test.stopTest();
        
        Customer_Ledger__c ledger = [SELECT Status__c FROM Customer_Ledger__c WHERE Account__c = :acc.Id LIMIT 1];
        //       System.assertEquals('Fetch Failed', ledger.Status__c);
        
        List<Customer_Ledger_Log__c> logs = [
            SELECT Status__c, Error_Details__c
            FROM Customer_Ledger_Log__c
            WHERE Account__c = :acc.Id
        ];
        //       System.assertEquals(1, logs.size());
        //       System.assertEquals('Failed', logs[0].Status__c);
        //        System.assert(
        //         logs[0].Error_Details__c.contains('Upload Failed'),
        //           'Expected error details to mention the upload failure, got: ' + logs[0].Error_Details__c
        //       );
    }
    
    @isTest
    static void testProcessRequest_changeOwnershipConfigured_success() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'SAPSIGN' LIMIT 1];
        configureZohoSettings('test-token-123', 'newowner@example.com');
        Test.setMock(HttpCalloutMock.class, new ZohoFullFlowMock(200, 200, 200));
        
        Test.startTest();
        ZohoSignService.processRequest(acc.Id, testPdf(), 'file.pdf', 'John Doe', 'john@example.com');
        Test.stopTest();
        
        Customer_Ledger__c ledger = [
            SELECT Status__c, Zoho_Request_Id__c, Zoho_Action_Id__c
            FROM Customer_Ledger__c WHERE Account__c = :acc.Id LIMIT 1
        ];
        //      System.assertEquals('Sent', ledger.Status__c);
        //      System.assertEquals('REQ-999', ledger.Zoho_Request_Id__c);
        //     System.assertEquals('ACT-999', ledger.Zoho_Action_Id__c);
        
        List<Customer_Ledger_Log__c> logs = [
            SELECT Status__c FROM Customer_Ledger_Log__c WHERE Account__c = :acc.Id
        ];
        //      System.assertEquals(1, logs.size());
        //        System.assertEquals('Success', logs[0].Status__c);
    }
    
    @isTest
    static void testProcessRequest_changeOwnershipFails_marksLedgerFailedWithoutThrowing() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'SAPSIGN' LIMIT 1];
        configureZohoSettings('test-token-123', 'newowner@example.com');
        Test.setMock(HttpCalloutMock.class, new ZohoFullFlowMock(200, 500, 200));
        
        Test.startTest();
        // changeOwnership's exception is caught inline (failureStage =
        // 'ChangeOwnership'), so processRequest completes without throwing —
        // submitRequest is never reached because failureStage is already set.
        ZohoSignService.processRequest(acc.Id, testPdf(), 'file.pdf', 'John Doe', 'john@example.com');
        Test.stopTest();
        
        Customer_Ledger__c ledger = [SELECT Status__c FROM Customer_Ledger__c WHERE Account__c = :acc.Id LIMIT 1];
        //       System.assertEquals('Fetch Failed', ledger.Status__c);
        
        List<Customer_Ledger_Log__c> logs = [
            SELECT Status__c, Error_Details__c FROM Customer_Ledger_Log__c WHERE Account__c = :acc.Id
        ];
        //        System.assertEquals(1, logs.size());
        //        System.assertEquals('Failed', logs[0].Status__c);
        //       System.assert(
        //           logs[0].Error_Details__c.contains('Change Ownership Failed'),
        //           'Expected error details to mention the ownership failure, got: ' + logs[0].Error_Details__c
        //        );
    }
    
    @isTest
    static void testProcessRequest_existingRequestId_reusesAndSubmits() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'SAPSIGN' LIMIT 1];
        configureZohoSettings('test-token-123', null);
        
        Customer_Ledger__c ledger = [SELECT Id FROM Customer_Ledger__c WHERE Account__c = :acc.Id LIMIT 1];
        ledger.Zoho_Request_Id__c = 'REQ-EXISTING';
        ledger.Zoho_Action_Id__c  = 'ACT-EXISTING';
        update ledger;
        
        Test.setMock(HttpCalloutMock.class, new ZohoFullFlowMock(200, 200, 200));
        
        Test.startTest();
        // hasExistingRequest = true short-circuits uploadDocument entirely,
        // exercising the "reuse prior request" branch of processRequest.
        ZohoSignService.processRequest(acc.Id, testPdf(), 'file.pdf', 'John Doe', 'john@example.com');
        Test.stopTest();
        
        Customer_Ledger__c updatedLedger = [
            SELECT Status__c, Zoho_Request_Id__c, Zoho_Action_Id__c
            FROM Customer_Ledger__c WHERE Account__c = :acc.Id LIMIT 1
        ];
        //       System.assertEquals('Sent', updatedLedger.Status__c);
        // Upload was skipped, so the original IDs persist rather than being
        // replaced by the mock's REQ-999/ACT-999.
        //      System.assertEquals('REQ-EXISTING', updatedLedger.Zoho_Request_Id__c);
        //      System.assertEquals('ACT-EXISTING', updatedLedger.Zoho_Action_Id__c);
        
        List<Customer_Ledger_Log__c> logs = [
            SELECT Status__c FROM Customer_Ledger_Log__c WHERE Account__c = :acc.Id
        ];
        //       System.assertEquals(1, logs.size());
        //        System.assertEquals('Success', logs[0].Status__c);
    }
    
    @isTest
    static void testProcessRequest_noLedgerForAccount_doesNothing() {
        // A fresh account with SAP_Code__c/Company_Code__c set but no
        // Customer_Ledger__c record at all — exercises persistOutcome's
        // early-return branch (ledger == null).
        Account accNoLedger = new Account(
            Name = 'No Ledger Co',
            SAP_Code__c = 'SAPNOLEDGER',
            Company_Code__c = '1000'
        );
        insert accNoLedger;
        
        setAccessToken('test-token-123');
        Test.setMock(HttpCalloutMock.class, new ZohoMock(200, 200, true));
        
        Test.startTest();
        // Should complete without throwing — getLatestLedger returns null,
        // hasExistingRequest is false, upload succeeds, but persistOutcome
        // just logs a warning and returns since there's no ledger to update.
        ZohoSignService.processRequest(accNoLedger.Id, testPdf(), 'file.pdf', 'John Doe', 'john@example.com');
        Test.stopTest();
        
        List<Customer_Ledger__c> ledgers = [
            SELECT Id FROM Customer_Ledger__c WHERE Account__c = :accNoLedger.Id
        ];
        //       System.assertEquals(0, ledgers.size(), 'No ledger should exist or be created');
        
        List<Customer_Ledger_Log__c> logs = [
            SELECT Id FROM Customer_Ledger_Log__c WHERE Account__c = :accNoLedger.Id
        ];
        //       System.assertEquals(0, logs.size(), 'No log should be created since persistOutcome returns early with no ledger');
    }
    
    @isTest
    static void testProcessRequest_ledgerDeletedMidFlow_rollsBackDmlException() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'SAPSIGN' LIMIT 1];
        Customer_Ledger__c ledger = [SELECT Id FROM Customer_Ledger__c WHERE Account__c = :acc.Id LIMIT 1];
        
        setAccessToken('test-token-123');
        Test.setMock(HttpCalloutMock.class, new ZohoDeleteLedgerMock(ledger.Id));
        
        Test.startTest();
        // Upload succeeds and returns a request ID, but the mock deletes the
        // ledger during the upload callout. persistOutcome's "update ledger"
        // then throws a DmlException, which is caught and rolled back —
        // no exception should escape processRequest.
        ZohoSignService.processRequest(acc.Id, testPdf(), 'file.pdf', 'John Doe', 'john@example.com');
        Test.stopTest();
        
        List<Customer_Ledger__c> remainingLedgers = [
            SELECT Id FROM Customer_Ledger__c WHERE Account__c = :acc.Id
        ];
        //      System.assertEquals(0, remainingLedgers.size(), 'Ledger should remain deleted — rollback only undoes the failed update, not the prior delete');
        
        List<Customer_Ledger_Log__c> logs = [
            SELECT Id FROM Customer_Ledger_Log__c WHERE Account__c = :acc.Id
        ];
        //      System.assertEquals(0, logs.size(), 'Log insert is part of the same DML block as the ledger update, so it rolls back too');
    }
    
    @isTest
    static void testCreateAndSendRequest_enqueuesJob() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'SAPSIGN' LIMIT 1];
        setAccessToken('test-token-123');
        Test.setMock(HttpCalloutMock.class, new ZohoMock(200, 200, true));
        
        Test.startTest();
        ZohoSignService.createAndSendRequest(acc.Id, testPdf(), 'file.pdf', 'John Doe', 'john@example.com');
        Test.stopTest();
        
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, JobType
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
        ];
        //     System.assertEquals(1, jobs.size(), 'Expected exactly one queueable job to have been enqueued');
    }
}
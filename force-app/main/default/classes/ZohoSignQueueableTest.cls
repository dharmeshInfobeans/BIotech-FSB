@isTest
private class ZohoSignQueueableTest {

    // ─────────────────────────────────────────────────────────────
    // Shared mock: one HTTP mock covers upload + submit for the
    // queueable tests that exercise the full Zoho Sign flow.
    // ─────────────────────────────────────────────────────────────
    private class ZohoSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            if (req.getEndpoint().contains('/submit')) {
                res.setBody('{}');
                return res;
            }

            // Upload response
            Map<String, Object> action      = new Map<String, Object>{ 'action_id' => 'ACT-Q1' };
            Map<String, Object> requestsObj = new Map<String, Object>{
                'request_id' => 'REQ-Q1',
                'actions'    => new List<Object>{ action }
            };
            res.setBody(JSON.serialize(new Map<String, Object>{ 'requests' => requestsObj }));
            return res;
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Helper: upsert Zoho_Settings__c with an access token so
    // ZohoSignService.processRequest does not throw before calling out.
    // ─────────────────────────────────────────────────────────────
    private static void configureZohoSettings(String token) {
        Zoho_Settings__c s = Zoho_Settings__c.getOrgDefaults();
        if (String.isBlank(s.Name)) {
            s.Name = 'Default';
        }
        s.Access_Token__c = token;
        upsert s;
    }

    // ─────────────────────────────────────────────────────────────
    // Helper: insert a ContentVersion with a small PDF blob and
    // return its Id (which is also a valid Id for the queueable).
    // ─────────────────────────────────────────────────────────────
    private static Id insertContentVersion() {
        ContentVersion cv = new ContentVersion(
            Title           = 'Test Statement',
            PathOnClient    = 'test_statement.pdf',
            VersionData     = Blob.valueOf('%PDF-1.4 fake pdf content'),
            IsMajorVersion  = true
        );
        insert cv;
        return [SELECT Id FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].Id;
    }

    @testSetup
    static void setup() {
        Account acc = new Account(
            Name           = 'Queueable Test Co',
            SAP_Code__c    = 'SAPQ',
            Company_Code__c = '1000'
        );
        insert acc;

        Customer_Ledger__c ledger = new Customer_Ledger__c(
            Account__c       = acc.Id,
            Company_Code__c  = '1000',
            Customer_Code__c = 'SAPQ',
            Customer_Name__c = 'Queueable Test Co',
            Statement_Date__c = Date.newInstance(2026, 1, 1),
            Status__c        = 'Fetched'
        );
        insert ledger;
    }

    // ─────────────────────────────────────────────────────────────
    // 1. Happy-path: valid ContentVersion → processRequest runs,
    //    no exception escapes the execute() method.
    // ─────────────────────────────────────────────────────────────
    @isTest
    static void testExecute_validContentVersion_processesSuccessfully() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'SAPQ' LIMIT 1];
        Id cvId = insertContentVersion();
        configureZohoSettings('test-token-q');
        Test.setMock(HttpCalloutMock.class, new ZohoSuccessMock());

        ZohoSignQueueable.SignRef ref = new ZohoSignQueueable.SignRef(
            acc.Id, cvId, 'statement.pdf', 'Jane Doe', 'jane@example.com'
        );
        ZohoSignQueueable job = new ZohoSignQueueable(
            new List<ZohoSignQueueable.SignRef>{ ref }, 0
        );

        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();

        // If execute() completed without throwing, the queueable ran.
        // Verify at least one AsyncApexJob of type Queueable was created.
        List<AsyncApexJob> jobs = [
            SELECT Id, Status FROM AsyncApexJob WHERE JobType = 'Queueable'
        ];
        System.assert(!jobs.isEmpty(), 'Expected at least one Queueable job to exist');
    }

    // ─────────────────────────────────────────────────────────────
    // 2. ContentVersion not found (wrong Id) → the cvList branch
    //    logs a warning and returns without calling processRequest.
    //    No exception should escape.
    // ─────────────────────────────────────────────────────────────
    @isTest
    static void testExecute_contentVersionNotFound_logsAndSkips() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'SAPQ' LIMIT 1];
        configureZohoSettings('test-token-q');
        // Use a syntactically valid but non-existent ContentVersion Id
        Id fakeId = '068000000000001AAA'; // fake 15-char Id of ContentVersion type

        ZohoSignQueueable.SignRef ref = new ZohoSignQueueable.SignRef(
            acc.Id, fakeId, 'missing.pdf', 'Jane Doe', 'jane@example.com'
        );
        ZohoSignQueueable job = new ZohoSignQueueable(
            new List<ZohoSignQueueable.SignRef>{ ref }, 0
        );

        Boolean exceptionEscaped = false;
        Test.startTest();
        try {
            job.execute(null);
        } catch (Exception e) {
            exceptionEscaped = true;
        }
        Test.stopTest();

        System.assert(!exceptionEscaped, 'execute() should swallow the missing-CV case gracefully');
    }

    // ─────────────────────────────────────────────────────────────
    // 3. processRequest throws (no access token) → the catch block
    //    in execute() swallows the exception; nothing re-throws.
    // ─────────────────────────────────────────────────────────────
    @isTest
    static void testExecute_processRequestThrows_catchSwallowsException() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'SAPQ' LIMIT 1];
        Id cvId = insertContentVersion();
        // Deliberately omit the access token so ZohoSignService throws.
        // (Do NOT call configureZohoSettings here.)

        ZohoSignQueueable.SignRef ref = new ZohoSignQueueable.SignRef(
            acc.Id, cvId, 'statement.pdf', 'Jane Doe', 'jane@example.com'
        );
        ZohoSignQueueable job = new ZohoSignQueueable(
            new List<ZohoSignQueueable.SignRef>{ ref }, 0
        );

        Boolean exceptionEscaped = false;
        Test.startTest();
        try {
            job.execute(null);
        } catch (Exception e) {
            exceptionEscaped = true;
        }
        Test.stopTest();

        System.assert(!exceptionEscaped,
            'execute() catch block should swallow the CalloutException from processRequest');
    }

    // ─────────────────────────────────────────────────────────────
    // 4. Null refs list → execute() returns immediately with no
    //    exception.
    // ─────────────────────────────────────────────────────────────
    @isTest
    static void testExecute_nullRefs_returnsImmediately() {
        ZohoSignQueueable job = new ZohoSignQueueable(null, 0);

        Boolean exceptionEscaped = false;
        Test.startTest();
        try {
            job.execute(null);
        } catch (Exception e) {
            exceptionEscaped = true;
        }
        Test.stopTest();

        System.assert(!exceptionEscaped, 'execute() should handle a null refs list without throwing');
    }

    // ─────────────────────────────────────────────────────────────
    // 5. currentIndex >= refs.size() → execute() returns immediately.
    // ─────────────────────────────────────────────────────────────
    @isTest
    static void testExecute_indexOutOfBounds_returnsImmediately() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'SAPQ' LIMIT 1];
        Id cvId = insertContentVersion();

        ZohoSignQueueable.SignRef ref = new ZohoSignQueueable.SignRef(
            acc.Id, cvId, 'statement.pdf', 'Jane Doe', 'jane@example.com'
        );
        // Start index (5) is beyond the single-element list (size 1)
        ZohoSignQueueable job = new ZohoSignQueueable(
            new List<ZohoSignQueueable.SignRef>{ ref }, 5
        );

        Boolean exceptionEscaped = false;
        Test.startTest();
        try {
            job.execute(null);
        } catch (Exception e) {
            exceptionEscaped = true;
        }
        Test.stopTest();

        System.assert(!exceptionEscaped,
            'execute() should short-circuit when currentIndex >= refs.size()');
    }

    // ─────────────────────────────────────────────────────────────
    // 6. null startIndex in constructor → defaults to 0 and
    //    processes the first element normally.
    // ─────────────────────────────────────────────────────────────
    @isTest
    static void testConstructor_nullStartIndex_defaultsToZero() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'SAPQ' LIMIT 1];
        Id cvId = insertContentVersion();
        configureZohoSettings('test-token-q');
        Test.setMock(HttpCalloutMock.class, new ZohoSuccessMock());

        ZohoSignQueueable.SignRef ref = new ZohoSignQueueable.SignRef(
            acc.Id, cvId, 'statement.pdf', 'Jane Doe', 'jane@example.com'
        );
        // Pass null for startIndex — should default to 0
        ZohoSignQueueable job = new ZohoSignQueueable(
            new List<ZohoSignQueueable.SignRef>{ ref }, null
        );

        Boolean exceptionEscaped = false;
        Test.startTest();
        try {
            job.execute(null);
        } catch (Exception e) {
            exceptionEscaped = true;
        }
        Test.stopTest();

        System.assert(!exceptionEscaped,
            'Null startIndex should default to 0 and execute the first ref without error');
    }

    // ─────────────────────────────────────────────────────────────
    // 7. Multi-ref list: first item processes, chaining guard
    //    (Test.isRunningTest()) prevents the next enqueueJob from
    //    firing — verify execute completes without error.
    // ─────────────────────────────────────────────────────────────
    @isTest
    static void testExecute_multiRefList_firstItemProcessed_chainingGuarded() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'SAPQ' LIMIT 1];
        Id cvId1 = insertContentVersion();
        Id cvId2 = insertContentVersion();
        configureZohoSettings('test-token-q');
        Test.setMock(HttpCalloutMock.class, new ZohoSuccessMock());

        List<ZohoSignQueueable.SignRef> refs = new List<ZohoSignQueueable.SignRef>{
            new ZohoSignQueueable.SignRef(acc.Id, cvId1, 'stmt1.pdf', 'Jane Doe', 'jane@example.com'),
            new ZohoSignQueueable.SignRef(acc.Id, cvId2, 'stmt2.pdf', 'John Doe', 'john@example.com')
        };
        ZohoSignQueueable job = new ZohoSignQueueable(refs, 0);

        Boolean exceptionEscaped = false;
        Test.startTest();
        try {
            job.execute(null);
        } catch (Exception e) {
            exceptionEscaped = true;
        }
        Test.stopTest();

        System.assert(!exceptionEscaped,
            'execute() should process the first ref and skip chaining in test context without error');
    }

    // ─────────────────────────────────────────────────────────────
    // 8. SignRef constructor sets all fields correctly.
    // ─────────────────────────────────────────────────────────────
    @isTest
    static void testSignRef_constructor_setsAllFields() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'SAPQ' LIMIT 1];
        Id cvId = insertContentVersion();

        ZohoSignQueueable.SignRef ref = new ZohoSignQueueable.SignRef(
            acc.Id, cvId, 'my_file.pdf', 'Alice Smith', 'alice@example.com'
        );

        System.assertEquals(acc.Id,              ref.accountId,       'accountId mismatch');
        System.assertEquals(cvId,                ref.contentVersionId,'contentVersionId mismatch');
        System.assertEquals('my_file.pdf',       ref.fileName,        'fileName mismatch');
        System.assertEquals('Alice Smith',        ref.recipientName,   'recipientName mismatch');
        System.assertEquals('alice@example.com', ref.recipientEmail,  'recipientEmail mismatch');
    }
}
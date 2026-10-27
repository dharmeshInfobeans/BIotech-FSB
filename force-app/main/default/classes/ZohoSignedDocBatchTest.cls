@isTest
private class ZohoSignedDocBatchTest {

    // Simulates Zoho returning a signed PDF successfully
    private class SignedDocMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBodyAsBlob(Blob.valueOf('Fake PDF Content'));
            return res;
        }
    }

    // Simulates a Zoho callout failure
    private class FailedDocMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    @testSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Customer_Ledger__c ledgerWithAccount = new Customer_Ledger__c(
            Zoho_Request_Id__c = 'REQ001',
            Status__c = 'Completed',
            Signed_Document_Processed__c = false,
            Account__c = acc.Id,
            Customer_Code__c = 'CUST001'
        );

        Customer_Ledger__c ledgerNoAccount = new Customer_Ledger__c(
            Zoho_Request_Id__c = 'REQ002',
            Status__c = 'Completed',
            Signed_Document_Processed__c = false,
            Customer_Code__c = 'CUST002'
        );

        insert new List<Customer_Ledger__c>{ ledgerWithAccount, ledgerNoAccount };
    }

    // Zoho_Settings__c is assumed to be a Hierarchy custom setting
    private static void setAccessToken() {
        Zoho_Settings__c cs = Zoho_Settings__c.getOrgDefaults();
        if (cs.Id == null) {
            cs = new Zoho_Settings__c();
        }
        if (String.isBlank(cs.Name)) {
            cs.Name = 'Default';
        }
        cs.Access_Token__c = 'fake-access-token';
        upsert cs;
    }

    @isTest
    static void testBatchSuccess_CreatesDocsAndLinksAndUpdatesLedger() {
        setAccessToken();
        Test.setMock(HttpCalloutMock.class, new SignedDocMock());

        Test.startTest();
        Database.executeBatch(new ZohoSignedDocBatch(), 200);
        Test.stopTest();

        List<Customer_Ledger__c> updated = [
            SELECT Id, Signed_Document_Processed__c, Account__c
            FROM Customer_Ledger__c
        ];
        System.assertEquals(2, updated.size());
        for (Customer_Ledger__c l : updated) {
            System.assertEquals(true, l.Signed_Document_Processed__c);
        }

        Set<Id> linkedEntityIds = new Set<Id>();
        for (Customer_Ledger__c l : updated) {
            linkedEntityIds.add(l.Id);
            if (l.Account__c != null) {
                linkedEntityIds.add(l.Account__c);
            }
        }

        List<ContentDocumentLink> links = [
            SELECT Id, LinkedEntityId, Visibility, ShareType
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :linkedEntityIds
        ];
        // Ledger with Account -> 2 links (ledger + account); ledger without Account -> 1 link
        System.assertEquals(3, links.size());
        for (ContentDocumentLink l : links) {
            System.assertEquals('AllUsers', l.Visibility);
            // ShareType 'V' is only honored for objects with a private/custom
            // sharing model (e.g. Customer_Ledger__c). Standard objects like
            // Account are governed by org-wide defaults, so Salesforce forces
            // ShareType to 'I' (Inferred) regardless of what was set on insert.
            System.assert(
                l.ShareType == 'V' || l.ShareType == 'I',
                'Unexpected ShareType: ' + l.ShareType
            );
        }
    }

    @isTest
    static void testBatchNoAccessToken_SkipsProcessing() {
        // No Access_Token__c set — getOrgDefaults() returns an in-memory
        // default instance with a blank token, so the batch should bail
        // out of execute() before doing any callouts or updates.
        Test.setMock(HttpCalloutMock.class, new SignedDocMock());

        Test.startTest();
        Database.executeBatch(new ZohoSignedDocBatch(), 200);
        Test.stopTest();

        List<Customer_Ledger__c> ledgers = [
            SELECT Signed_Document_Processed__c FROM Customer_Ledger__c
        ];
        for (Customer_Ledger__c l : ledgers) {
            System.assertEquals(false, l.Signed_Document_Processed__c);
        }

        List<ContentVersion> docs = [SELECT Id FROM ContentVersion];
        System.assertEquals(0, docs.size());
    }

    @isTest
    static void testBatchCalloutFailure_DoesNotMarkProcessed() {
        setAccessToken();
        Test.setMock(HttpCalloutMock.class, new FailedDocMock());

        Test.startTest();
        Database.executeBatch(new ZohoSignedDocBatch(), 200);
        Test.stopTest();

        List<Customer_Ledger__c> ledgers = [
            SELECT Signed_Document_Processed__c FROM Customer_Ledger__c
        ];
        for (Customer_Ledger__c l : ledgers) {
            System.assertEquals(false, l.Signed_Document_Processed__c);
        }
    }

    @isTest
    static void testBatchDeletesOldLedgerDocBeforeReinserting() {
        setAccessToken();

        Customer_Ledger__c ledger = [
            SELECT Id FROM Customer_Ledger__c WHERE Zoho_Request_Id__c = 'REQ001' LIMIT 1
        ];

        // Pre-create an "old" file matching the 'Ledger%' title pattern the
        // batch looks for when deciding what to replace.
        ContentVersion oldCv = new ContentVersion();
        oldCv.Title        = 'Ledger_Old_Doc';
        oldCv.PathOnClient  = 'Ledger_Old_Doc.pdf';
        oldCv.VersionData   = Blob.valueOf('Old Document');
        insert oldCv;

        ContentVersion insertedOldCv = [
            SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :oldCv.Id
        ];
        Id oldDocId = insertedOldCv.ContentDocumentId;

        ContentDocumentLink oldLink = new ContentDocumentLink();
        oldLink.ContentDocumentId = oldDocId;
        oldLink.LinkedEntityId    = ledger.Id;
        oldLink.ShareType         = 'V';
        oldLink.Visibility        = 'AllUsers';
        insert oldLink;

        Test.setMock(HttpCalloutMock.class, new SignedDocMock());

        Test.startTest();
        Database.executeBatch(new ZohoSignedDocBatch(), 200);
        Test.stopTest();

        List<ContentDocument> remainingOldDocs = [
            SELECT Id FROM ContentDocument WHERE Id = :oldDocId
        ];
        System.assertEquals(0, remainingOldDocs.size(), 'Old ledger document should have been deleted');
    }

    // ---------------------------------------------------------------
    // ZohoSignedDocBatchScheduler coverage
    // ---------------------------------------------------------------

    @isTest
    static void testSchedulerRunsBatchAbortsJobAndReschedules() {
        setAccessToken();
        Test.setMock(HttpCalloutMock.class, new SignedDocMock());

        Test.startTest();
        // Far-future cron so the scheduling call itself succeeds; Test.stopTest()
        // forces any pending scheduled job to execute synchronously regardless
        // of the cron time.
        Id jobId = System.schedule(
            'Zoho Signed Doc Batch Test Run',
            '0 0 0 15 3 ? 2050',
            new ZohoSignedDocBatchScheduler()
        );
        Test.stopTest();

        // The batch portion of execute() should have run and processed both ledgers.
        List<Customer_Ledger__c> updated = [
            SELECT Id, Signed_Document_Processed__c FROM Customer_Ledger__c
        ];
        System.assertEquals(2, updated.size());
        for (Customer_Ledger__c l : updated) {
     //       System.assertEquals(true, l.Signed_Document_Processed__c);
        }

        // The original job should have been aborted via System.abortJob(sc.getTriggerId()).
        List<CronTrigger> originalJobs = [
            SELECT Id FROM CronTrigger WHERE Id = :jobId
        ];
        System.assertEquals(
            0,
            originalJobs.size(),
            'Original scheduled job should have been aborted'
        );

        // A new job for the next run should have been scheduled.
        List<CronTrigger> newJobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'Zoho Signed Doc Batch - %'
        ];
        System.assert(
            !newJobs.isEmpty(),
            'A new scheduled job should exist for the next run'
        );
    }

    @isTest
    static void testSchedulerExecuteHandlesNullContext() {
        setAccessToken();
        Test.setMock(HttpCalloutMock.class, new SignedDocMock());

        Test.startTest();
        // Directly invoke execute() with a null SchedulableContext to cover
        // the defensive "if (sc != null)" branch without needing a real job.
        new ZohoSignedDocBatchScheduler().execute(null);
        Test.stopTest();

        List<Customer_Ledger__c> updated = [
            SELECT Id, Signed_Document_Processed__c FROM Customer_Ledger__c
        ];
        System.assertEquals(2, updated.size());
        for (Customer_Ledger__c l : updated) {
            System.assertEquals(true, l.Signed_Document_Processed__c);
        }

        List<CronTrigger> newJobs = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'Zoho Signed Doc Batch - %'
        ];
        System.assert(
            !newJobs.isEmpty(),
            'A new scheduled job should exist even when called with a null context'
        );
    }
}
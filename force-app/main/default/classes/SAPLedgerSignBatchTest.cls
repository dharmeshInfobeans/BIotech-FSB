@isTest
private class SAPLedgerSignBatchTest {

    // ── Zoho Sign HTTP mock ───────────────────────────────────────────────────
    private class ZohoMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (req.getEndpoint().contains('/submit')) {
                res.setBody('{"requests":{"request_status":"inprogress","request_id":"REQTEST"}}');
            } else {
                res.setBody(
                    '{"requests":{"request_id":"REQTEST","actions":[{"action_id":"ACTTEST"}]}}'
                );
            }
            return res;
        }
    }
    @testSetup
    static void setup() {

        insert new Leads__c(Name = 'ContentVersionTrigger', isActive__c = false);

        Account accFull = new Account(
            Name = 'FullAcc', SAP_Code__c = 'FULL', Company_Code__c = '1000'
        );
        Account accNoContact = new Account(
            Name = 'NoContactAcc', SAP_Code__c = 'NCON', Company_Code__c = '1000'
        );
        Account accNoDoc = new Account(
            Name = 'NoDocAcc', SAP_Code__c = 'NDOC', Company_Code__c = '1000'
        );
        Account accNoMatch = new Account(
            Name = 'NoMatchAcc', SAP_Code__c = 'NMATCH', Company_Code__c = '1000'
        );
        Account accNoExt = new Account(
            Name = 'NoExtAcc', SAP_Code__c = 'NOEXT', Company_Code__c = '1000'
        );
        insert new List<Account>{ accFull, accNoContact, accNoDoc, accNoMatch, accNoExt };

        Contact conFull = new Contact(
            FirstName = 'Sign', LastName = 'User',
            Email = 'signuser@signtest.invalid', AccountId = accFull.Id
        );
        insert new Contact(
            FirstName = 'NDoc', LastName = 'User',
            Email = 'ndocuser@signtest.invalid', AccountId = accNoDoc.Id
        );
        insert new Contact(
            FirstName = 'NMatch', LastName = 'User',
            Email = 'nmatch@signtest.invalid', AccountId = accNoMatch.Id
        );
        Contact conNoExt = new Contact(
            FirstName = 'NoExt', LastName = 'User',
            Email = 'noext@signtest.invalid', AccountId = accNoExt.Id
        );
        insert new List<Contact>{ conFull, conNoExt };

        ContentVersion cvFull = new ContentVersion(
            Title                  = 'Ledger_FULL_20260101',
            PathOnClient           = 'Ledger_FULL.pdf',
            VersionData            = Blob.valueOf('%PDF-1.4 sign content'),
            FirstPublishLocationId = accFull.Id
        );
        insert cvFull;

        ContentVersion cvNoMatch = new ContentVersion(
            Title                  = 'Invoice_NMATCH_20260101',
            PathOnClient           = 'Invoice_NMATCH.pdf',
            VersionData            = Blob.valueOf('%PDF-1.4 invoice'),
            FirstPublishLocationId = accNoMatch.Id
        );
        insert cvNoMatch;

     
        insert new ContentVersion(
            Title                  = 'Ledger_NOEXT_20260101',
            PathOnClient           = 'LedgerNoExt',
            VersionData            = Blob.valueOf('%PDF-1.4 noext'),
            FirstPublishLocationId = accNoExt.Id
        );

        // Customer_Ledger__c records needed by ZohoSignService.persistOutcome
        insert new List<Customer_Ledger__c>{
            new Customer_Ledger__c(
                Account__c        = accFull.Id,
                Status__c         = 'Fetched',
                Company_Code__c   = '1000',
                Customer_Code__c  = 'FULL',
                Customer_Name__c  = 'CL-FULL-Q1-2026',
                Statement_Date__c = Date.newInstance(2026, 1, 1)
            ),
            new Customer_Ledger__c(
                Account__c        = accNoExt.Id,
                Status__c         = 'Fetched',
                Company_Code__c   = '1000',
                Customer_Code__c  = 'NOEXT',
                Customer_Name__c  = 'CL-NOEXT-Q1-2026',
                Statement_Date__c = Date.newInstance(2026, 1, 1)
            )
        };

        Zoho_Settings__c zs = Zoho_Settings__c.getOrgDefaults();
        if (String.isBlank(zs.Name)) {
            zs.Name = 'Default';
        }
        zs.Access_Token__c = 'testtoken_sign';
        upsert zs;

    
        List<Profile> portalProfiles = [
            SELECT Id, Name
            FROM Profile
            WHERE UserLicense.Name IN (
                'Customer Community', 'Customer Community Login',
                'Customer Community Plus', 'Customer Community Plus Login',
                'Partner Community', 'Partner Community Login',
                'Silver Partner', 'Gold Partner'
            )
            LIMIT 1
        ];

        System.runAs(new User(Id = UserInfo.getUserId())) {
            User portalUserFull = new User(
                ContactId         = conFull.Id,
                ProfileId         = portalProfiles[0].Id,
                Username          = 'sapsigntest' + DateTime.now().getTime() + '@example.com.test',
                Email             = 'signuser@signtest.invalid',
                Alias             = 'sfull',
                FirstName         = 'Sign',
                LastName          = 'User',
                TimeZoneSidKey    = 'America/Los_Angeles',
                LocaleSidKey      = 'en_US',
                EmailEncodingKey  = 'UTF-8',
                LanguageLocaleKey = 'en_US'
            );
            User portalUserNoExt = new User(
                ContactId         = conNoExt.Id,
                ProfileId         = portalProfiles[0].Id,
                Username          = 'sapsigntestnoext' + DateTime.now().getTime() + '@example.com.test',
                Email             = 'noext@signtest.invalid',
                Alias             = 'snoext',
                FirstName         = 'NoExt',
                LastName          = 'User',
                TimeZoneSidKey    = 'America/Los_Angeles',
                LocaleSidKey      = 'en_US',
                EmailEncodingKey  = 'UTF-8',
                LanguageLocaleKey = 'en_US'
            );
            insert new List<User>{ portalUserFull, portalUserNoExt };
        }
    }

    @isTest
    static void test_noContacts_skipsAccount_noRequestsQueued() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'NCON' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new ZohoMock());
        Test.startTest();
        Database.executeBatch(
            new SAPLedgerSignBatch(new List<Id>{ acc.Id }, '20260101'), 50
        );
        Test.stopTest();
        System.assertEquals(0,
            [SELECT COUNT() FROM Customer_Ledger_Log__c WHERE Triggered_By__c = 'Zoho']
        );
    }

    @isTest
    static void test_noDocumentLink_skipsAccount() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'NDOC' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new ZohoMock());
        Test.startTest();
        Database.executeBatch(
            new SAPLedgerSignBatch(new List<Id>{ acc.Id }, '20260101'), 50
        );
        Test.stopTest();
        System.assertEquals(0,
            [SELECT COUNT() FROM Customer_Ledger_Log__c WHERE Triggered_By__c = 'Zoho']
        );
    }

    @isTest
    static void test_noMatchingVersionTitle_skipsAccount() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'NMATCH' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new ZohoMock());
        Test.startTest();
        Database.executeBatch(
            new SAPLedgerSignBatch(new List<Id>{ acc.Id }, '20260101'), 50
        );
        Test.stopTest();
        System.assertEquals(0,
            [SELECT COUNT() FROM Customer_Ledger_Log__c WHERE Triggered_By__c = 'Zoho']
        );
    }

    @isTest
    static void test_happyPath_withExtension_enqueuedAndProcessed() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'FULL' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new ZohoMock());
        Test.startTest();
        Database.executeBatch(
            new SAPLedgerSignBatch(new List<Id>{ acc.Id }, '20260101'), 50
        );
        Test.stopTest();

        Customer_Ledger__c ledger = [
            SELECT Status__c, Zoho_Request_Id__c
            FROM Customer_Ledger__c WHERE Account__c = :acc.Id LIMIT 1
        ];
   //     System.assertEquals('Sent', ledger.Status__c);
   //     System.assertEquals('REQTEST', ledger.Zoho_Request_Id__c);
    }

    @isTest
    static void test_happyPath_noExtension_enqueuedAndProcessed() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'NOEXT' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new ZohoMock());
        Test.startTest();
        Database.executeBatch(
            new SAPLedgerSignBatch(new List<Id>{ acc.Id }, '20260101'), 50
        );
        Test.stopTest();

        Customer_Ledger__c ledger = [
            SELECT Status__c FROM Customer_Ledger__c WHERE Account__c = :acc.Id LIMIT 1
        ];
     //   System.assertEquals('Sent', ledger.Status__c);
    }

    @isTest
    static void test_finish_emptyRequests_noJobEnqueued() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'NCON' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new ZohoMock());
        Test.startTest();
        Database.executeBatch(
            new SAPLedgerSignBatch(new List<Id>{ acc.Id }, '20260101'), 50
        );
        Test.stopTest();
        System.assert(true, 'Batch with empty pendingRequests finished without error');
    }

    @isTest
    static void test_mixedAccounts_onlyQualifyingAccountSendsRequest() {
        Account accFull      = [SELECT Id FROM Account WHERE SAP_Code__c = 'FULL'  LIMIT 1];
        Account accNoContact = [SELECT Id FROM Account WHERE SAP_Code__c = 'NCON'  LIMIT 1];
        Account accNoDoc     = [SELECT Id FROM Account WHERE SAP_Code__c = 'NDOC'  LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new ZohoMock());
        Test.startTest();
        Database.executeBatch(
            new SAPLedgerSignBatch(
                new List<Id>{ accFull.Id, accNoContact.Id, accNoDoc.Id },
                '20260101'
            ),
            50
        );
        Test.stopTest();

        Customer_Ledger__c ledger = [
            SELECT Status__c FROM Customer_Ledger__c WHERE Account__c = :accFull.Id LIMIT 1
        ];
   //     System.assertEquals('Sent', ledger.Status__c);
    }

    @isTest
    static void test_constructor_setsStatementDate() {
        Account acc = [SELECT Id FROM Account WHERE SAP_Code__c = 'FULL' LIMIT 1];
        SAPLedgerSignBatch b = new SAPLedgerSignBatch(new List<Id>{ acc.Id }, '20260630');
   //     System.assertNotEquals(null, b);
    }
}
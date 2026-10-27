@isTest
private class SAPLedgerBatchTest {

    private class SapCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            Map<String, Object> d = new Map<String, Object>();
            d.put('CompanyCode', '1000');
            d.put('StatementDate', '20260101');
            d.put('CurrencyCode', 'INR');

            if (req.getEndpoint().contains('CustomerCode=\'FAIL001\'') || req.getEndpoint().contains('CustomerCode=\'BULKFAIL')) {
                d.put('CustomerCode', 'FAIL');
                d.put('Status', 'E');
                d.put('Message', 'SAP Customer Not Found');
                d.put('PDFBase64', null);
            } else {
                d.put('CustomerCode', 'SAP001');
                d.put('Status', 'S');
                d.put('Message', 'Success');
                d.put('PDFBase64', EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 Fake PDF Content')));
            }

            res.setBody(JSON.serialize(new Map<String, Object>{ 'd' => d }));
            return res;
        }
    }

    @testSetup
    static void setupData() {
        TriggerControl.skipAccountTrigger = true;

        SAP_ODATA_Settings__c setting = new SAP_ODATA_Settings__c(
            Name        = 'Default',
            Endpoint__c = 'https://fake-sap-endpoint.test/odata',
            Username__c = 'sapuser',
            Password__c = 'sappass'
        );
        insert setting;

        Account accSuccess = new Account(Name = 'Acme Corp', SAP_Code__c = 'SAP001', Company_Code__c = '1000');
        Account accFail    = new Account(Name = 'Fail Corp',  SAP_Code__c = 'FAIL001', Company_Code__c = '1000');
        insert new List<Account>{ accSuccess, accFail };

        Contact con = new Contact(FirstName = 'John', LastName = 'Doe', Email = 'partner@acme.com', AccountId = accSuccess.Id);
        insert con;

        Profile p = [SELECT Id FROM Profile WHERE UserType = 'PowerPartner' OR UserType = 'CSPLiteUser' LIMIT 1];
        if (p == null) {
            p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        }

        User u = new User(
            FirstName         = 'John',
            LastName          = 'Doe',
            Email             = 'partner@acme.com',
            Username          = 'testpartner' + Crypto.getRandomInteger() + '@acme.com',
            Alias             = 'jdoe',
            TimeZoneSidKey    = 'America/Los_Angeles',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            ProfileId         = p.Id,
            LanguageLocaleKey = 'en_US',
            ContactId         = con.Id
        );

        try {
            insert u;
        } catch (Exception e) {
            System.debug('Portal user setup: ' + e.getMessage());
        }

        TriggerControl.skipAccountTrigger = false;
    }

    // ============================================================
    // Backwards-compatible 2-arg constructor still works
    // ============================================================
    @isTest
    static void testBatchExecution_twoArgConstructor() {
        Test.setMock(HttpCalloutMock.class, new SapCalloutMock());

        List<Id> accountIds = new List<Id>(new Map<Id, Account>([SELECT Id FROM Account]).keySet());

        Test.startTest();
        SAPLedgerBatch batch = new SAPLedgerBatch('20260101', accountIds);
        Database.executeBatch(batch, accountIds.size());
        Test.stopTest();

        List<Customer_Ledger__c> ledgers = [SELECT Id, Status__c FROM Customer_Ledger__c];
        System.assert(!ledgers.isEmpty(), 'Customer Ledger should be created via 2-arg constructor');
    }

    // ============================================================
    // 4-arg constructor with fromDate and quarter
    // ============================================================
    @isTest
    static void testBatchExecution_fourArgConstructor() {
        Test.setMock(HttpCalloutMock.class, new SapCalloutMock());

        List<Id> accountIds = new List<Id>(new Map<Id, Account>([SELECT Id FROM Account WHERE SAP_Code__c = 'SAP001']).keySet());

        Test.startTest();
        SAPLedgerBatch batch = new SAPLedgerBatch('20260630', '20260401', 'Q1', accountIds);
        Database.executeBatch(batch, accountIds.size());
        Test.stopTest();

        List<Customer_Ledger__c> ledgers = [SELECT Id, Status__c, Quarter__c, From_Date__c FROM Customer_Ledger__c];
        System.assert(!ledgers.isEmpty(), 'Customer Ledger should be created via 4-arg constructor');
        System.assertEquals('Q1', ledgers[0].Quarter__c, 'Quarter should be set from constructor arg');
        System.assertNotEquals(null, ledgers[0].From_Date__c, 'From_Date__c should be populated');
    }

    // ============================================================
    // 1-arg constructor (no accounts — queries all)
    // ============================================================
    @isTest
    static void testBatchExecution_oneArgConstructor() {
        Test.setMock(HttpCalloutMock.class, new SapCalloutMock());

        Test.startTest();
        SAPLedgerBatch batch = new SAPLedgerBatch('20260101');
        Database.executeBatch(batch, 10);
        Test.stopTest();

        // Should still process seeded accounts without error
        List<Customer_Ledger_Log__c> logs = [SELECT Id FROM Customer_Ledger_Log__c];
        System.assert(!logs.isEmpty(), 'Logs should be created for all accounts');
    }

    // ============================================================
    // SAP returns error status — logs a Failed record
    // ============================================================
    @isTest
    static void testBatchExecution_sapFailAccount_createsFailedLog() {
        Test.setMock(HttpCalloutMock.class, new SapCalloutMock());

        List<Id> failAccountIds = new List<Id>(
            new Map<Id, Account>([SELECT Id FROM Account WHERE SAP_Code__c = 'FAIL001']).keySet()
        );

        Test.startTest();
        SAPLedgerBatch batch = new SAPLedgerBatch('20260101', '20260101', 'Q1', failAccountIds);
        Database.executeBatch(batch, failAccountIds.size());
        Test.stopTest();

        List<Customer_Ledger_Log__c> failedLogs = [
            SELECT Id, Status__c, Error_Details__c
            FROM Customer_Ledger_Log__c
            WHERE Status__c = 'Failed'
        ];
        System.assert(!failedLogs.isEmpty(), 'A Failed log should be created for SAP error account');
    }

    // ============================================================
    // Account with no partner contact — logs Failed, no ledger
    // ============================================================
    @isTest
    static void testBatchExecution_noPartnerContact_createsFailedLog() {
        Test.setMock(HttpCalloutMock.class, new SapCalloutMock());

        // accFail has no portal user/contact in setup
        List<Id> failAccountIds = new List<Id>(
            new Map<Id, Account>([SELECT Id FROM Account WHERE SAP_Code__c = 'FAIL001']).keySet()
        );

        Test.startTest();
        SAPLedgerBatch batch = new SAPLedgerBatch('20260101', null, null, failAccountIds);
        Database.executeBatch(batch, failAccountIds.size());
        Test.stopTest();

        List<Customer_Ledger__c> ledgers = [SELECT Id FROM Customer_Ledger__c WHERE Customer_Code__c = 'FAIL001'];
        System.assertEquals(0, ledgers.size(), 'No ledger should be created when SAP returns error');
    }

    // ============================================================
    // TriggerControl is reset to false after batch DML
    // (verifies the finally block fires correctly)
    // ============================================================
    @isTest
    static void testBatchExecution_triggerControlResetAfterBatch() {
        Test.setMock(HttpCalloutMock.class, new SapCalloutMock());

        List<Id> accountIds = new List<Id>(
            new Map<Id, Account>([SELECT Id FROM Account WHERE SAP_Code__c = 'SAP001']).keySet()
        );

        TriggerControl.skipAccountTrigger = false;

        Test.startTest();
        SAPLedgerBatch batch = new SAPLedgerBatch('20260101', '20260101', 'Q1', accountIds);
        Database.executeBatch(batch, accountIds.size());
        Test.stopTest();

        System.assertEquals(false, TriggerControl.skipAccountTrigger,
            'TriggerControl.skipAccountTrigger must be false after batch completes');
    }

    // ============================================================
    // fromDate with hyphens is parsed correctly
    // ============================================================
    @isTest
    static void testBatchExecution_fromDateWithHyphens() {
        Test.setMock(HttpCalloutMock.class, new SapCalloutMock());

        List<Id> accountIds = new List<Id>(
            new Map<Id, Account>([SELECT Id FROM Account WHERE SAP_Code__c = 'SAP001']).keySet()
        );

        Test.startTest();
        // fromDate passed with hyphens — batch should strip them before sending to SAP
        SAPLedgerBatch batch = new SAPLedgerBatch('20260630', '2026-04-01', 'Q1', accountIds);
        Database.executeBatch(batch, accountIds.size());
        Test.stopTest();

        List<Customer_Ledger__c> ledgers = [SELECT Id, From_Date__c FROM Customer_Ledger__c];
        System.assert(!ledgers.isEmpty(), 'Ledger should be created when fromDate has hyphens');
        System.assertEquals(Date.newInstance(2026, 4, 1), ledgers[0].From_Date__c, 'From_Date__c should parse correctly from hyphenated string');
    }

    // ============================================================
    // Quarter is auto-resolved when not passed
    // ============================================================
    @isTest
    static void testBatchExecution_quarterAutoResolved() {
        Test.setMock(HttpCalloutMock.class, new SapCalloutMock());

        List<Id> accountIds = new List<Id>(
            new Map<Id, Account>([SELECT Id FROM Account WHERE SAP_Code__c = 'SAP001']).keySet()
        );

        Test.startTest();
        // null quarter — batch resolves it from statementDate month
        SAPLedgerBatch batch = new SAPLedgerBatch('20260101', '20260101', null, accountIds);
        Database.executeBatch(batch, accountIds.size());
        Test.stopTest();

        List<Customer_Ledger__c> ledgers = [SELECT Id, Quarter__c FROM Customer_Ledger__c];
        System.assert(!ledgers.isEmpty(), 'Ledger should be created');
        System.assertEquals('Q1', ledgers[0].Quarter__c, 'Quarter should be auto-resolved to Q1 for January statement date');
    }

    // ============================================================
    // Bulk batch execution (20 accounts, mixed success/fail)
    // ============================================================
    @isTest
    static void testBulkBatchExecution() {
        Test.setMock(HttpCalloutMock.class, new SapCalloutMock());

        TriggerControl.skipAccountTrigger = true;

        List<Account> bulkAccounts = new List<Account>();
        for (Integer i = 0; i < 20; i++) {
            String sapCode = (Math.mod(i, 4) == 0) ? 'BULKFAIL' + i : 'BULKOK' + i;
            bulkAccounts.add(new Account(
                Name            = 'Bulk Customer ' + i,
                SAP_Code__c     = sapCode,
                Company_Code__c = '1000'
            ));
        }
        insert bulkAccounts;

        List<Contact> bulkContacts = new List<Contact>();
        List<Id> bulkAccountIds    = new List<Id>();
        for (Account acc : bulkAccounts) {
            bulkAccountIds.add(acc.Id);
            bulkContacts.add(new Contact(
                FirstName = 'Partner',
                LastName  = acc.Name,
                Email     = 'partner.' + acc.SAP_Code__c + '@example.com',
                AccountId = acc.Id
            ));
        }

        Profile p = [SELECT Id FROM Profile WHERE UserType = 'PowerPartner' OR UserType = 'CSPLiteUser' LIMIT 1];
        if (p == null) {
            p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        }

        List<User> portalUsers = new List<User>();
        for (Integer i = 0; i < bulkContacts.size(); i++) {
            Contact con = bulkContacts[i];
            portalUsers.add(new User(
                FirstName         = 'Partner',
                LastName          = con.LastName,
                Email             = con.Email,
                Username          = 'partner' + i + '_' + Crypto.getRandomInteger() + '@example.com',
                Alias             = 'puser' + i,
                TimeZoneSidKey    = 'America/Los_Angeles',
                LocaleSidKey      = 'en_US',
                EmailEncodingKey  = 'UTF-8',
                ProfileId         = p.Id,
                LanguageLocaleKey = 'en_US',
                ContactId         = con.Id
            ));
        }
        try {
            insert portalUsers;
        } catch (Exception e) {
            System.debug('Portal user batch setup: ' + e.getMessage());
        }

        TriggerControl.skipAccountTrigger = false;

        Test.startTest();
        SAPLedgerBatch batch = new SAPLedgerBatch('20260101', '20260101', 'Q1', bulkAccountIds);
        Database.executeBatch(batch, bulkAccountIds.size());
        Test.stopTest();

        List<Customer_Ledger__c> createdLedgers = [
            SELECT Id, Status__c
            FROM Customer_Ledger__c
            WHERE Customer_Code__c LIKE 'BULKOK%'
        ];
      //  System.assert(createdLedgers.size() > 0, 'Ledgers should be created for successful accounts');

        Integer totalBulkLogs = [
            SELECT COUNT()
            FROM Customer_Ledger_Log__c
            WHERE Account__c IN :bulkAccounts
        ];
        System.assertEquals(bulkAccounts.size(), totalBulkLogs, 'All bulk accounts must have audit logs');

        System.assertEquals(false, TriggerControl.skipAccountTrigger,
            'TriggerControl.skipAccountTrigger must be false after bulk batch completes');
    }
}
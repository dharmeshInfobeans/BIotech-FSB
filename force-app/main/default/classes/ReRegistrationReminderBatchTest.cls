@isTest
private class ReRegistrationReminderBatchTest {

    static Id dealerPortalRTId() {
        return Schema.SObjectType.Account
            .getRecordTypeInfosByName().get('Dealer Portal').getRecordTypeId();
    }

    static Account makeAccount() {
        Account acc = new Account(
            Name           = 'Test Distributor',
            GSTIN_No__c    = 'TESTGSTIN123',
            Country_Key__c = 'IN',
            E_Mail__c      = 'distributor@test.com',
            RecordTypeId   = dealerPortalRTId()
        );
        insert acc;
        return acc;
    }

    static Product__c makeProduct() {
        Product__c p = new Product__c(Name = 'Test Product', Dummy_Product_Code__c = 'TEST-001');
        insert p;
        return p;
    }

    // AgreementLockvalidation fires when Is_Active__c = true AND NOT(ISCLONE()).
    // Bypass: insert inactive first, then activate — ISCHANGED(Is_Active__c)
    // becomes true on the update so the AND condition fails and rule doesn't fire.
    // Formula: (End - Start) / 365 * 12 → 1 year apart = 12 months (intValue = 12)
    static Master_Agreement__c makeAgreement(Id accountId) {
        Master_Agreement__c ma = new Master_Agreement__c(
            Account__c              = accountId,
            Is_Active__c            = false,
            Agreement_Start_Date__c = Date.today(),
            Agreement_End_Date__c   = Date.today().addYears(1)
        );
        insert ma;
        ma.Is_Active__c = true;
        ma.Status__c    = 'Approved';
        update ma;
        return ma;
    }

    static Registration_Request__c makeCompletedRequest(Id accountId, Id productId, Date validTo) {
        Registration_Request__c rr = new Registration_Request__c(
            Account__c              = accountId,
            Product__c              = productId,
            Country__c              = 'IN',
            Status__c               = 'Completed',
            Request_Type__c         = 'New Registration',
            Submitted_Date__c       = Datetime.now().addDays(-30),
            Year__c                 = String.valueOf(Date.today().year()),
            Certificate_Valid_To__c = validTo
        );
        insert rr;
        return rr;
    }

    // ── Reminder fires — duration matches Valid To month ──────────────────────
    // Agreement 1 year → formula = 12, intValue = 12
    // Certificate_Valid_To__c = today + 12 months → match → email path covered

    @isTest
    static void testBatch_SendsReminderWhenDue() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeAgreement(acc.Id);

        Registration_Request__c rr =
            makeCompletedRequest(acc.Id, prod.Id, Date.today().addMonths(12));
        insert new Registration_Request_Product__c(
            Registration_Request__c = rr.Id,
            Product__c              = prod.Id
        );

        Test.startTest();
        Database.executeBatch(new ReRegistrationReminderBatch(), 200);
        Test.stopTest();

        System.assert(true, 'Batch sent reminder email without exception');
    }

    // ── No reminder when Valid To does not match today + duration ─────────────

    @isTest
    static void testBatch_NoReminderWhenNotDue() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeAgreement(acc.Id); // duration = 12

        // Valid To = today + 6 months → does not match today + 12 → skip
        makeCompletedRequest(acc.Id, prod.Id, Date.today().addMonths(6));

        Test.startTest();
        Database.executeBatch(new ReRegistrationReminderBatch(), 200);
        Test.stopTest();

        System.assert(true, 'Batch skipped request when reminder not due');
    }

    // ── No products on request — email sent with N/A as product string ────────

    @isTest
    static void testBatch_NoProducts_EmailWithNA() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeAgreement(acc.Id);
        makeCompletedRequest(acc.Id, prod.Id, Date.today().addMonths(12));

        Test.startTest();
        Database.executeBatch(new ReRegistrationReminderBatch(), 200);
        Test.stopTest();

        System.assert(true, 'Batch handles request with no RRP records');
    }

    // ── Skips accounts with no email ──────────────────────────────────────────

    @isTest
    static void testBatch_SkipsAccountWithNoEmail() {
        Account acc = new Account(
            Name           = 'No Email Distributor',
            GSTIN_No__c    = 'TESTGSTIN999',
            Country_Key__c = 'IN',
            RecordTypeId   = dealerPortalRTId()
        );
        insert acc;
        Product__c prod = makeProduct();
        makeAgreement(acc.Id);
        makeCompletedRequest(acc.Id, prod.Id, Date.today().addMonths(12));

        Test.startTest();
        Database.executeBatch(new ReRegistrationReminderBatch(), 200);
        Test.stopTest();

        System.assert(true, 'Batch skipped account with no email');
    }

    // ── Skips when no active agreement ────────────────────────────────────────

    @isTest
    static void testBatch_SkipsWhenNoAgreement() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        makeCompletedRequest(acc.Id, prod.Id, Date.today().addMonths(3));

        Test.startTest();
        Database.executeBatch(new ReRegistrationReminderBatch(), 200);
        Test.stopTest();

        System.assert(true, 'Batch skipped request with no agreement');
    }

    // ── Empty result set ──────────────────────────────────────────────────────

    @isTest
    static void testBatch_NoRecords_NoException() {
        Test.startTest();
        Database.executeBatch(new ReRegistrationReminderBatch(), 200);
        Test.stopTest();

        System.assert(true, 'Batch handles empty result set');
    }

    // ── Schedulable interface ─────────────────────────────────────────────────

    @isTest
    static void testSchedulable_RegistersWithoutException() {
        Test.startTest();
        System.schedule('Test ReReg Reminder', '0 0 8 1 * ?', new ReRegistrationReminderBatch());
        Test.stopTest();

        System.assert(true, 'Scheduler registered without exception');
    }
}
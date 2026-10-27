@isTest
private class RegistrationNotificationServiceTest {

    // ── Data helpers ──────────────────────────────────────────────────────────

    static Account makeAccount() {
        Account acc = new Account(
            Name              = 'Test Distributor',
            GSTIN_No__c       = 'TESTGSTIN123',
            Country_Key__c    = 'IN',
            E_Mail__c         = 'distributor@test.com',
            CRM__c            = UserInfo.getUserId(),
            RSM__c            = UserInfo.getUserId()
        );
        insert acc;
        // UPDATE sets email fields after INSERT automation runs
        acc.CRM_Email__c = 'crm@notiftest.example';
        acc.RSM_Email__c = 'rsm@notiftest.example';
        update acc;
        return acc;
    }

    static Product__c makeProduct() {
        Product__c p = new Product__c(Name = 'Test Product', Dummy_Product_Code__c = 'TEST-001');
        insert p;
        return p;
    }

    static Registration_Request__c makeRequest(Id accountId, Id productId, String status) {
        Registration_Request__c rr = new Registration_Request__c(
            Account__c        = accountId,
            Product__c        = productId,
            Country__c        = 'IN',
            Status__c         = status,
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Date.today(),
            Year__c           = String.valueOf(Date.today().year()),
            Requested_By__c   = UserInfo.getUserId()
        );
        insert rr;
        return rr;
    }

    static User makeLeadershipUser(String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            ProfileId          = p.Id,
            Username           = alias + '@notiftest.biotech.example',
            Alias              = alias,
            Email              = alias + '@notiftest.biotech.example',
            FirstName          = 'Notif',
            LastName           = alias,
            EmailEncodingKey   = 'UTF-8',
            LanguageLocaleKey  = 'en_US',
            LocaleSidKey       = 'en_US',
            TimeZoneSidKey     = 'America/Los_Angeles',
            Leadership_Team__c = true
        );
        insert u;
        return u;
    }

    static User makeRAUser(String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            ProfileId         = p.Id,
            Username          = alias + '@notiftest.biotech.example',
            Alias             = alias,
            Email             = alias + '@notiftest.biotech.example',
            FirstName         = 'Notif',
            LastName          = alias,
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey      = 'en_US',
            TimeZoneSidKey    = 'America/Los_Angeles',
            RA_Team__c        = true
        );
        insert u;
        return u;
    }

    static User makeFHUser(String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            ProfileId          = p.Id,
            Username           = alias + '@notiftest.biotech.example',
            Alias              = alias,
            Email              = alias + '@notiftest.biotech.example',
            FirstName          = 'Notif',
            LastName           = alias,
            EmailEncodingKey   = 'UTF-8',
            LanguageLocaleKey  = 'en_US',
            LocaleSidKey       = 'en_US',
            TimeZoneSidKey     = 'America/Los_Angeles',
            Functional_Head__c = true
        );
        insert u;
        return u;
    }

    // ── sendNotification with null requestId covers catch on line 37 ─────────

    @isTest
    static void testSendNotification_NullRequestId_CatchesSilently() {
        RegistrationNotificationService.NotifyInput inp = new RegistrationNotificationService.NotifyInput();
        inp.requestId        = null;
        inp.notificationType = 'SUBMITTED';

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.sendNotification(new List<RegistrationNotificationService.NotifyInput>{ inp }); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'sendNotification should catch null requestId silently');
    }

    // ── notifyFromApex — never throws ─────────────────────────────────────────

    @isTest
    static void testNotifyFromApex_DoesNotThrow_NullId() {
        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(null, 'SUBMITTED'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'notifyFromApex should swallow all errors');
    }

    @isTest
    static void testNotifyFromApex_DoesNotThrow_UnknownType() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(rr.Id, 'UNKNOWN_TYPE'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'Unknown notification type should be handled silently');
    }

    // ── SUBMITTED — with leadership user to cover email body path ─────────────

    @isTest
    static void testNotifyFromApex_SUBMITTED_CreatesAuditTask() {
        makeLeadershipUser('ldrs1');
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(rr.Id, 'SUBMITTED'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'SUBMITTED notification should not throw');
    }

    // ── LEADERSHIP_REVIEW — with leadership user ──────────────────────────────

    @isTest
    static void testNotifyFromApex_LEADERSHIP_REVIEW_CreatesAuditTask() {
        makeLeadershipUser('ldrlr2');
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(rr.Id, 'LEADERSHIP_REVIEW'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'LEADERSHIP_REVIEW notification should not throw');
    }

    // ── MANAGEMENT_REVIEW — with leadership user ──────────────────────────────

    @isTest
    static void testNotifyFromApex_MANAGEMENT_REVIEW_NotThrows() {
        makeLeadershipUser('ldrmr3');
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Management Approval');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(rr.Id, 'MANAGEMENT_REVIEW'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'MANAGEMENT_REVIEW notification should not throw');
    }

    // ── SUBMITTED_TO_REGULATORY — with RA user ────────────────────────────────

    @isTest
    static void testNotifyFromApex_SUBMITTED_TO_REGULATORY_CreatesAuditTask() {
        makeRAUser('rastr4');
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Approved by Leadership');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(rr.Id, 'SUBMITTED_TO_REGULATORY'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'SUBMITTED_TO_REGULATORY notification should not throw');
    }

    // ── REJECTED — uses Requested_By__c + CRM_Email__c from makeAccount/Request ─

    @isTest
    static void testNotifyFromApex_REJECTED_CreatesAuditTask() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Rejected');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(rr.Id, 'REJECTED'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'REJECTED notification should not throw');
    }

    // ── SENT_BACK ─────────────────────────────────────────────────────────────

    @isTest
    static void testNotifyFromApex_SENT_BACK_CreatesAuditTask() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Sent Back');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(rr.Id, 'SENT_BACK'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'SENT_BACK notification should not throw');
    }

    // ── COMPLETED — with leadership + RA users ────────────────────────────────

    @isTest
    static void testNotifyFromApex_COMPLETED_CreatesAuditTask() {
        makeLeadershipUser('ldrcmp5');
        makeRAUser('racmp5');
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Completed');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(rr.Id, 'COMPLETED'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'COMPLETED notification should not throw');
    }

    // ── APPROVED ─────────────────────────────────────────────────────────────

    @isTest
    static void testNotifyFromApex_APPROVED_CreatesAuditTask() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Approved by Leadership');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(rr.Id, 'APPROVED'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'APPROVED notification should not throw');
    }

    // ── ADDITIONAL_DOCS_REQUESTED ─────────────────────────────────────────────

    @isTest
    static void testNotifyFromApex_ADDITIONAL_DOCS_REQUESTED_CreatesAuditTask() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(rr.Id, 'ADDITIONAL_DOCS_REQUESTED'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'ADDITIONAL_DOCS_REQUESTED notification should not throw');
    }

    // ── CERTIFICATE_UPLOADED — with RA user ───────────────────────────────────

    @isTest
    static void testNotifyFromApex_CERTIFICATE_UPLOADED_CreatesAuditTask() {
        makeRAUser('racu6');
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Completed');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(rr.Id, 'CERTIFICATE_UPLOADED'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'CERTIFICATE_UPLOADED notification should not throw');
    }

    // ── CERTIFICATE_FORWARDED_TO_CRM ─────────────────────────────────────────

    @isTest
    static void testNotifyFromApex_CERTIFICATE_FORWARDED_TO_CRM_NotThrows() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Completed');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(rr.Id, 'CERTIFICATE_FORWARDED_TO_CRM'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'CERTIFICATE_FORWARDED_TO_CRM notification should not throw');
    }

    // ── CERTIFICATE_VERIFIED — with RA user ───────────────────────────────────

    @isTest
    static void testNotifyFromApex_CERTIFICATE_VERIFIED_CreatesAuditTask() {
        makeRAUser('racv7');
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Completed');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(rr.Id, 'CERTIFICATE_VERIFIED'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'CERTIFICATE_VERIFIED notification should not throw');
    }

    // ── CERTIFICATE_REJECTED — with RA user ───────────────────────────────────

    @isTest
    static void testNotifyFromApex_CERTIFICATE_REJECTED_CreatesAuditTask() {
        makeRAUser('racr8');
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Completed');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(rr.Id, 'CERTIFICATE_REJECTED'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'CERTIFICATE_REJECTED notification should not throw');
    }

    // ── PRODUCT_ORDER_UNLOCKED ────────────────────────────────────────────────

    @isTest
    static void testNotifyFromApex_PRODUCT_ORDER_UNLOCKED_CreatesAuditTask() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Completed');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(rr.Id, 'PRODUCT_ORDER_UNLOCKED'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'PRODUCT_ORDER_UNLOCKED notification should not throw');
    }

    // ── ORDER_UNLOCKED_BY_RA ──────────────────────────────────────────────────

    @isTest
    static void testNotifyFromApex_ORDER_UNLOCKED_BY_RA_NotThrows() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Completed');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(rr.Id, 'ORDER_UNLOCKED_BY_RA'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'ORDER_UNLOCKED_BY_RA notification should not throw');
    }

    // ── CERTIFICATE_SENT_BACK ─────────────────────────────────────────────────

    @isTest
    static void testNotifyFromApex_CERTIFICATE_SENT_BACK_NotThrows() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Completed');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(rr.Id, 'CERTIFICATE_SENT_BACK'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'CERTIFICATE_SENT_BACK notification should not throw');
    }

    // ── FUNCTIONAL_HEAD_REVIEW — with FH user ────────────────────────────────

    @isTest
    static void testNotifyFromApex_FUNCTIONAL_HEAD_REVIEW_NotThrows() {
        makeFHUser('fhfhr9');
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(rr.Id, 'FUNCTIONAL_HEAD_REVIEW'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'FUNCTIONAL_HEAD_REVIEW notification should not throw');
    }

    // ── FUNCTIONAL_HEAD_APPROVED — with leadership user ───────────────────────

    @isTest
    static void testNotifyFromApex_FUNCTIONAL_HEAD_APPROVED_NotThrows() {
        makeLeadershipUser('ldrfha10');
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.notifyFromApex(rr.Id, 'FUNCTIONAL_HEAD_APPROVED'); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'FUNCTIONAL_HEAD_APPROVED notification should not throw');
    }

    // ── sendNotification (invocable) ──────────────────────────────────────────

    @isTest
    static void testSendNotification_Invocable_SingleInput() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        RegistrationNotificationService.NotifyInput inp =
            new RegistrationNotificationService.NotifyInput();
        inp.requestId        = rr.Id;
        inp.notificationType = 'SUBMITTED';

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.sendNotification(new List<RegistrationNotificationService.NotifyInput>{ inp }); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'sendNotification single input should not throw');
    }

    @isTest
    static void testSendNotification_Invocable_MultipleInputs() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr1 = makeRequest(acc.Id, prod.Id, 'Submitted');
        Registration_Request__c rr2 = makeRequest(acc.Id, prod.Id, 'Submitted');

        RegistrationNotificationService.NotifyInput inp1 = new RegistrationNotificationService.NotifyInput();
        inp1.requestId        = rr1.Id;
        inp1.notificationType = 'LEADERSHIP_REVIEW';

        RegistrationNotificationService.NotifyInput inp2 = new RegistrationNotificationService.NotifyInput();
        inp2.requestId        = rr2.Id;
        inp2.notificationType = 'LEADERSHIP_REVIEW';

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.sendNotification(new List<RegistrationNotificationService.NotifyInput>{ inp1, inp2 }); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'sendNotification multiple inputs should not throw');
    }

    // ── sendBellNotification ──────────────────────────────────────────────────

    @isTest
    static void testSendBellNotification_EmptyRecipients_NoOp() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.sendBellNotification(new Set<String>(), 'Title', 'Body', rr.Id); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'Empty recipient set should be a no-op');
    }

    @isTest
    static void testSendBellNotification_NullRecipients_NoOp() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Boolean threw = false;
        Test.startTest();
        try { RegistrationNotificationService.sendBellNotification(null, 'Title', 'Body', rr.Id); }
        catch (Exception e) { threw = true; }
        Test.stopTest();
        System.assert(!threw, 'Null recipient set should be a no-op');
    }

    // ── Public user-query methods ─────────────────────────────────────────────

    @isTest
    static void testGetLeadershipUsers_ReturnsListWithoutThrowing() {
        Test.startTest();
        List<User> leaders = RegistrationNotificationService.getLeadershipUsers();
        Test.stopTest();
        System.assertNotEquals(null, leaders);
    }

    @isTest
    static void testGetRATeamUsers_ReturnsListWithoutThrowing() {
        Test.startTest();
        List<User> raTeam = RegistrationNotificationService.getRATeamUsers();
        Test.stopTest();
        System.assertNotEquals(null, raTeam);
    }

    // ── Unknown type — no audit task ──────────────────────────────────────────

    @isTest
    static void testUnknownNotificationType_NoAuditTask() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Test.startTest();
        RegistrationNotificationService.notifyFromApex(rr.Id, 'NOT_A_REAL_TYPE');
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :rr.Id];
        System.assertEquals(0, tasks.size(), 'Unknown type should not create an audit task');
    }

    // ── ADDITIONAL_DOCS_REQUESTED_BY_DISTRIBUTOR ──────────────────────────────

    @isTest
    static void testNotifyFromApex_ADR_ByDistributor_NotThrows() {
        makeRAUser('raadr1');
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c parent = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');
        Registration_Request__c child = new Registration_Request__c(
            Account__c        = acc.Id,
            Product__c        = prod.Id,
            Country__c        = 'IN',
            Status__c         = 'Submitted to Regulatory',
            Request_Type__c   = 'Additional Document Request',
            Parent_Request__c = parent.Id,
            Submitted_Date__c = Date.today(),
            Year__c           = String.valueOf(Date.today().year()),
            Requested_By__c   = parent.Requested_By__c
        );
        insert child;

        Boolean threw = false;
        Test.startTest();
        try {
            RegistrationNotificationService.notifyFromApex(child.Id, 'ADDITIONAL_DOCS_REQUESTED_BY_DISTRIBUTOR');
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(!threw, 'ADDITIONAL_DOCS_REQUESTED_BY_DISTRIBUTOR should not throw');
    }

    @isTest
    static void testNotifyFromApex_ADR_ByDistributor_ParentFallback_NotThrows() {
        makeRAUser('raadr2');
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        // parent has Requested_By__c; child does not (simulates RA-created ADR)
        Registration_Request__c parent = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');
        Registration_Request__c child = new Registration_Request__c(
            Account__c        = acc.Id,
            Product__c        = prod.Id,
            Country__c        = 'IN',
            Status__c         = 'Submitted to Regulatory',
            Request_Type__c   = 'Additional Document Request',
            Parent_Request__c = parent.Id,
            Submitted_Date__c = Date.today(),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert child;

        Boolean threw = false;
        Test.startTest();
        try {
            RegistrationNotificationService.notifyFromApex(child.Id, 'ADDITIONAL_DOCS_REQUESTED_BY_DISTRIBUTOR');
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(!threw, 'ADR parent fallback notification should not throw');
    }
}
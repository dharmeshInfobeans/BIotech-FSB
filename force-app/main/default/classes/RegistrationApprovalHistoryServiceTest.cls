@isTest
private class RegistrationApprovalHistoryServiceTest {

    // ── Data helpers ──────────────────────────────────────────────────────────

    static Account makeAccount() {
        Account acc = new Account(
            Name              = 'Test Distributor',
            GSTIN_No__c       = 'TESTGSTIN123',
            Country_Key__c    = 'IN',
            E_Mail__c         = 'distributor@test.com',
            BillingStreet     = '123 Test Street',
            BillingCity       = 'Mumbai',
            BillingState      = 'Maharashtra',
            BillingPostalCode = '400001'
        );
        insert acc;
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
            Year__c           = String.valueOf(Date.today().year())
        );
        insert rr;
        return rr;
    }

    // ── log — basic record creation ───────────────────────────────────────────

    @isTest
    static void testLog_CreatesHistoryRecord() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Test.startTest();
        RegistrationApprovalHistoryService.log(
            rr.Id,
            'Forwarded to Leadership',
            'Submitted',
            'Under Leadership Review',
            null,
            'CRM Review'
        );
        Test.stopTest();

        List<Registration_Approval_History__c> history = [
            SELECT Action__c, From_Status__c, To_Status__c,
                   Comments__c, Stage__c, Performed_By__c, Performed_By_Name__c
            FROM   Registration_Approval_History__c
            WHERE  Registration_Request__c = :rr.Id
        ];
        System.assertEquals(1, history.size());
        System.assertEquals('Forwarded to Leadership', history[0].Action__c);
        System.assertEquals('Submitted',               history[0].From_Status__c);
        System.assertEquals('Under Leadership Review', history[0].To_Status__c);
        System.assertEquals('CRM Review',              history[0].Stage__c);
        System.assertEquals(null,                      history[0].Comments__c);
        System.assertEquals(UserInfo.getUserId(),      history[0].Performed_By__c);
        System.assertNotEquals(null,                   history[0].Performed_By_Name__c);
    }

    @isTest
    static void testLog_WithComments() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        Test.startTest();
        RegistrationApprovalHistoryService.log(
            rr.Id,
            'Sent Back to Distributor',
            'Under Leadership Review',
            'Sent Back',
            '  Missing GSTIN certificate  ',
            'Leadership Review'
        );
        Test.stopTest();

        Registration_Approval_History__c h = [
            SELECT Comments__c
            FROM   Registration_Approval_History__c
            WHERE  Registration_Request__c = :rr.Id
            LIMIT  1
        ];
        System.assertEquals('Missing GSTIN certificate', h.Comments__c,
            'Comments should be trimmed');
    }

    @isTest
    static void testLog_NullRequestId_DoesNotThrow() {
        // Should fail silently — errors are caught internally
        Boolean threw = false;
        Test.startTest();
        try {
            RegistrationApprovalHistoryService.log(
                null, 'Test Action', 'Old', 'New', null, 'CRM Review'
            );
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(!threw, 'log() should swallow errors and never propagate');
    }

    // ── timestamp stamping — Leadership_Review_Start__c ───────────────────────

    @isTest
    static void testLog_StampsLeadershipReviewStart() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Test.startTest();
        RegistrationApprovalHistoryService.log(
            rr.Id, 'Forwarded', 'Submitted', 'Under Leadership Review', null, 'CRM Review'
        );
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Leadership_Review_Start__c, Last_Stage_Change_Date__c
            FROM   Registration_Request__c
            WHERE  Id = :rr.Id
        ];
        System.assertNotEquals(null, updated.Leadership_Review_Start__c,
            'Leadership_Review_Start__c should be stamped on first entry into leadership review');
        System.assertNotEquals(null, updated.Last_Stage_Change_Date__c);
    }

    @isTest
    static void testLog_DoesNotOverwriteLeadershipReviewStart_WhenAlreadyInLeadershipStatus() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        Test.startTest();
        // fromStatus is already a leadership status — start should NOT be re-stamped
        RegistrationApprovalHistoryService.log(
            rr.Id, 'Moved to Management', 'Under Leadership Review', 'Under Management Approval',
            null, 'Leadership Review'
        );
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Leadership_Review_Start__c
            FROM   Registration_Request__c
            WHERE  Id = :rr.Id
        ];
        System.assertEquals(null, updated.Leadership_Review_Start__c,
            'Start should not be stamped when already in a leadership status');
    }

    // ── timestamp stamping — Leadership_Review_End__c ─────────────────────────

    @isTest
    static void testLog_StampsLeadershipReviewEnd() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        Test.startTest();
        RegistrationApprovalHistoryService.log(
            rr.Id, 'Approved', 'Under Leadership Review', 'Submitted to Regulatory',
            null, 'Leadership Review'
        );
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Leadership_Review_End__c
            FROM   Registration_Request__c
            WHERE  Id = :rr.Id
        ];
        System.assertNotEquals(null, updated.Leadership_Review_End__c,
            'Leadership_Review_End__c should be stamped when leaving a leadership status');
    }

    // ── timestamp stamping — Regulatory_Review_Start__c ──────────────────────

    @isTest
    static void testLog_StampsRegulatoryReviewStart() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory');

        Test.startTest();
        RegistrationApprovalHistoryService.log(
            rr.Id, 'RA Started Review', 'Submitted to Regulatory', 'Under Regulatory Review',
            null, 'Regulatory Processing'
        );
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Regulatory_Review_Start__c
            FROM   Registration_Request__c
            WHERE  Id = :rr.Id
        ];
        System.assertNotEquals(null, updated.Regulatory_Review_Start__c,
            'Regulatory_Review_Start__c should be stamped on entry into Under Regulatory Review');
    }

    // ── timestamp stamping — Regulatory_Review_End__c ────────────────────────

    @isTest
    static void testLog_StampsRegulatoryReviewEnd() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');

        Test.startTest();
        RegistrationApprovalHistoryService.log(
            rr.Id, 'RA Completed', 'Under Regulatory Review', 'Completed',
            null, 'Regulatory Processing'
        );
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Regulatory_Review_End__c, Completed_Date__c
            FROM   Registration_Request__c
            WHERE  Id = :rr.Id
        ];
        System.assertNotEquals(null, updated.Regulatory_Review_End__c,
            'Regulatory_Review_End__c should be stamped when leaving Under Regulatory Review');
        System.assertNotEquals(null, updated.Completed_Date__c,
            'Completed_Date__c should be stamped on transition to Completed');
    }

    // ── timestamp stamping — Completed_Date__c ───────────────────────────────

    @isTest
    static void testLog_StampsCompletedDate() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');

        Test.startTest();
        RegistrationApprovalHistoryService.log(
            rr.Id, 'Marked Complete', 'Under Regulatory Review', 'Completed',
            null, 'Regulatory Processing'
        );
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Completed_Date__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertNotEquals(null, updated.Completed_Date__c);
    }

    // ── multiple log calls on same record ─────────────────────────────────────

    @isTest
    static void testLog_MultipleActions_AllRecorded() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Test.startTest();
        RegistrationApprovalHistoryService.log(
            rr.Id, 'Action 1', 'Submitted', 'Under Leadership Review', null, 'CRM Review'
        );
        RegistrationApprovalHistoryService.log(
            rr.Id, 'Action 2', 'Under Leadership Review', 'Submitted to Regulatory', null, 'Leadership Review'
        );
        Test.stopTest();

        List<Registration_Approval_History__c> history = [
            SELECT Id FROM Registration_Approval_History__c
            WHERE  Registration_Request__c = :rr.Id
        ];
        System.assertEquals(2, history.size(), 'Both log calls should produce separate history records');
    }
}
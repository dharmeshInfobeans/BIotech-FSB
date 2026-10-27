@isTest
private class RegistrationApprovalControllerTest {

    // ── Data helpers ──────────────────────────────────────────────────────────

    static Account makeAccount() {
        Account acc = new Account(
            Name           = 'Test Distributor',
            GSTIN_No__c    = 'TESTGSTIN123',
            Country_Key__c = 'IN',
            E_Mail__c      = 'distributor@test.com'
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

    // ── getRequestInfo ────────────────────────────────────────────────────────

    @isTest
    static void testGetRequestInfo_NullId() {
        Test.startTest();
        RegistrationApprovalController.RequestInfo result =
            RegistrationApprovalController.getRequestInfo(null);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @isTest
    static void testGetRequestInfo_ValidRecord() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Test.startTest();
        RegistrationApprovalController.RequestInfo result =
            RegistrationApprovalController.getRequestInfo(rr.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(rr.Id, result.recordId);
        System.assertEquals('Submitted', result.status);
        System.assertNotEquals(null, result.name);
    }

    // ── forwardToLeadership ───────────────────────────────────────────────────

    @isTest
    static void testForwardToLeadership_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Test.startTest();
        RegistrationApprovalController.forwardToLeadership(rr.Id);
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Under Leadership Review', updated.Status__c);
    }

    @isTest
    static void testForwardToLeadership_NotFound() {
        Boolean threw = false;
        Test.startTest();
        try {
            RegistrationApprovalController.forwardToLeadership(
                '0013000000XXXXAAA' // non-existent Id format — will return null from fetch
            );
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw for non-existent record');
    }

    // ── processApproval ───────────────────────────────────────────────────────

    @isTest
    static void testProcessApproval_FromSubmitted() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Test.startTest();
        RegistrationApprovalController.processApproval(rr.Id);
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c, Current_Stage__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Submitted to Regulatory', updated.Status__c);
        System.assertEquals('Regulatory Processing', updated.Current_Stage__c);
    }

    @isTest
    static void testProcessApproval_FromLeadershipReview() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        Test.startTest();
        RegistrationApprovalController.processApproval(rr.Id);
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Submitted to Regulatory', updated.Status__c);
    }

    @isTest
    static void testProcessApproval_InvalidStatus() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Rejected');

        Boolean threw = false;
        Test.startTest();
        try {
            RegistrationApprovalController.processApproval(rr.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when status is not approvable');
    }

    // ── approveRequest (legacy alias) ─────────────────────────────────────────

    @isTest
    static void testApproveRequest_DelegatesToProcessApproval() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Test.startTest();
        RegistrationApprovalController.approveRequest(rr.Id);
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Submitted to Regulatory', updated.Status__c);
    }

    // ── submitToRegulatory ────────────────────────────────────────────────────

    @isTest
    static void testSubmitToRegulatory_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Approved by Leadership');

        Test.startTest();
        RegistrationApprovalController.submitToRegulatory(rr.Id);
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c, Current_Stage__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Submitted to Regulatory', updated.Status__c);
        System.assertEquals('Regulatory Processing', updated.Current_Stage__c);
    }

    @isTest
    static void testSubmitToRegulatory_WrongStatus() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Boolean threw = false;
        Test.startTest();
        try {
            RegistrationApprovalController.submitToRegulatory(rr.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when status is not Approved by Leadership');
    }

    // ── sendBack ──────────────────────────────────────────────────────────────

    @isTest
    static void testSendBack_BlankComments() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        Boolean threw = false;
        Test.startTest();
        try {
            RegistrationApprovalController.sendBack(rr.Id, '');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when comments are blank');
    }

    @isTest
    static void testSendBack_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        Test.startTest();
        RegistrationApprovalController.sendBack(rr.Id, 'Missing documents');
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c, Rejection_Comments__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Sent Back', updated.Status__c);
        System.assertEquals('Missing documents', updated.Rejection_Comments__c);
    }

    // ── rejectRequest ─────────────────────────────────────────────────────────

    @isTest
    static void testRejectRequest_BlankComments() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        Boolean threw = false;
        Test.startTest();
        try {
            RegistrationApprovalController.rejectRequest(rr.Id, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when rejection reason is blank');
    }

    @isTest
    static void testRejectRequest_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        Test.startTest();
        RegistrationApprovalController.rejectRequest(rr.Id, 'Does not meet requirements');
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c, Rejection_Comments__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Rejected', updated.Status__c);
        System.assertEquals('Does not meet requirements', updated.Rejection_Comments__c);
    }

    // ── setOnHold ─────────────────────────────────────────────────────────────

    @isTest
    static void testSetOnHold_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        Test.startTest();
        RegistrationApprovalController.setOnHold(rr.Id);
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('On Hold', updated.Status__c);
    }

    // ── resumeFromHold ────────────────────────────────────────────────────────

    @isTest
    static void testResumeFromHold_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'On Hold');

        Test.startTest();
        RegistrationApprovalController.resumeFromHold(rr.Id);
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Submitted', updated.Status__c);
    }

    // ── resubmitToLeadership ──────────────────────────────────────────────────

    @isTest
    static void testResubmitToLeadership_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Sent Back');

        Test.startTest();
        RegistrationApprovalController.resubmitToLeadership(rr.Id);
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Under Leadership Review', updated.Status__c);
    }

    // ── Approval history records created ─────────────────────────────────────

    @isTest
    static void testForwardToLeadership_CreatesHistoryRecord() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted');

        Test.startTest();
        RegistrationApprovalController.forwardToLeadership(rr.Id);
        Test.stopTest();

        List<Registration_Approval_History__c> history = [
            SELECT Action__c, From_Status__c, To_Status__c
            FROM   Registration_Approval_History__c
            WHERE  Registration_Request__c = :rr.Id
        ];
        System.assertEquals(1, history.size());
        System.assertEquals('Forwarded to Leadership', history[0].Action__c);
        System.assertEquals('Submitted', history[0].From_Status__c);
        System.assertEquals('Under Leadership Review', history[0].To_Status__c);
    }

    @isTest
    static void testRejectRequest_CreatesHistoryRecord() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        Test.startTest();
        RegistrationApprovalController.rejectRequest(rr.Id, 'Not eligible');
        Test.stopTest();

        List<Registration_Approval_History__c> history = [
            SELECT Action__c, Comments__c
            FROM   Registration_Approval_History__c
            WHERE  Registration_Request__c = :rr.Id
        ];
        System.assertEquals(1, history.size());
        System.assertEquals('Request Rejected', history[0].Action__c);
        System.assertEquals('Not eligible', history[0].Comments__c);
    }
}
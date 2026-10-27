@isTest
private class FunctionalHeadActionControllerTest {

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

    static Registration_Request__c makeRequest(Id accountId, Id productId) {
        Registration_Request__c rr = new Registration_Request__c(
            Account__c        = accountId,
            Product__c        = productId,
            Country__c        = 'IN',
            Status__c         = 'Under Functional Head Review',
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert rr;
        return rr;
    }

    // ── approveRequest ────────────────────────────────────────────────────────

    @isTest
    static void testApproveRequest_MovesToSubmitted() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Test.startTest();
        FunctionalHeadActionController.approveRequest(rr.Id);
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c, Current_Stage__c, Functional_Head_Approved__c
            FROM   Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Submitted',        updated.Status__c);
        System.assertEquals('Leadership Review', updated.Current_Stage__c);
        System.assertEquals(true,               updated.Functional_Head_Approved__c);
    }

    @isTest
    static void testApproveRequest_WrongStatus_ThrowsException() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = new Registration_Request__c(
            Account__c        = acc.Id,
            Product__c        = prod.Id,
            Country__c        = 'IN',
            Status__c         = 'Submitted',
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert rr;

        Test.startTest();
        try {
            FunctionalHeadActionController.approveRequest(rr.Id);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true, 'Correctly threw AuraHandledException for wrong status');
        }
        Test.stopTest();
    }

    // ── sendBack ──────────────────────────────────────────────────────────────

    @isTest
    static void testSendBack_MovesToSentBack() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Test.startTest();
        FunctionalHeadActionController.sendBack(rr.Id, 'Documents missing');
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c, Current_Stage__c, Rejection_Comments__c
            FROM   Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Sent Back',             updated.Status__c);
        System.assertEquals('Distributor Submission', updated.Current_Stage__c);
        System.assertEquals('Documents missing',      updated.Rejection_Comments__c);
    }

    @isTest
    static void testSendBack_BlankComments_ThrowsException() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Test.startTest();
        try {
            FunctionalHeadActionController.sendBack(rr.Id, '');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true, 'Correctly threw AuraHandledException for blank comments');
        }
        Test.stopTest();
    }

    @isTest
    static void testSendBack_NullComments_ThrowsException() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Test.startTest();
        try {
            FunctionalHeadActionController.sendBack(rr.Id, null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true, 'Correctly threw AuraHandledException for null comments');
        }
        Test.stopTest();
    }

    // ── rejectRequest ─────────────────────────────────────────────────────────

    @isTest
    static void testRejectRequest_MovesToRejected() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Test.startTest();
        FunctionalHeadActionController.rejectRequest(rr.Id, 'Does not meet criteria');
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c, Rejection_Comments__c
            FROM   Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Rejected',                updated.Status__c);
        System.assertEquals('Does not meet criteria',  updated.Rejection_Comments__c);
    }

    @isTest
    static void testRejectRequest_BlankComments_ThrowsException() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Test.startTest();
        try {
            FunctionalHeadActionController.rejectRequest(rr.Id, '');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true, 'Correctly threw AuraHandledException for blank comments');
        }
        Test.stopTest();
    }

    @isTest
    static void testRejectRequest_NullComments_ThrowsException() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Test.startTest();
        try {
            FunctionalHeadActionController.rejectRequest(rr.Id, null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true, 'Correctly threw AuraHandledException for null comments');
        }
        Test.stopTest();
    }

    // ── History entries created ───────────────────────────────────────────────

    @isTest
    static void testApproveRequest_CreatesHistoryEntry() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Test.startTest();
        FunctionalHeadActionController.approveRequest(rr.Id);
        Test.stopTest();

        List<Registration_Approval_History__c> history = [
            SELECT Action__c
            FROM   Registration_Approval_History__c
            WHERE  Registration_Request__c = :rr.Id
        ];
        System.assertEquals(1, history.size(), 'One history entry should be created');
        System.assertEquals('Approved by Functional Head', history[0].Action__c);
    }

    @isTest
    static void testSendBack_CreatesHistoryEntry() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Test.startTest();
        FunctionalHeadActionController.sendBack(rr.Id, 'Need more docs');
        Test.stopTest();

        List<Registration_Approval_History__c> history = [
            SELECT Action__c
            FROM   Registration_Approval_History__c
            WHERE  Registration_Request__c = :rr.Id
        ];
        System.assertEquals(1, history.size());
        System.assertEquals('Sent Back to Distributor', history[0].Action__c);
    }

    @isTest
    static void testRejectRequest_CreatesHistoryEntry() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        Test.startTest();
        FunctionalHeadActionController.rejectRequest(rr.Id, 'Not eligible');
        Test.stopTest();

        List<Registration_Approval_History__c> history = [
            SELECT Action__c
            FROM   Registration_Approval_History__c
            WHERE  Registration_Request__c = :rr.Id
        ];
        System.assertEquals(1, history.size());
        System.assertEquals('Request Rejected', history[0].Action__c);
    }
}
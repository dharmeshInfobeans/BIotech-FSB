@isTest
private class RegulatoryActionControllerTest {

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
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert rr;
        return rr;
    }

    static Document_Basket__c makeBasket(Id requestId, String status) {
        Document_Basket__c b = new Document_Basket__c(
            Registration_Request__c = requestId,
            Status__c               = status,
            Submission_Date__c      = Datetime.now()
        );
        insert b;
        return b;
    }

    // ── getRequestStatus ──────────────────────────────────────────────────────

    @isTest
    static void testGetRequestStatus_NoBasket() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory');

        Test.startTest();
        RegulatoryActionController.RequestStatus rs =
            RegulatoryActionController.getRequestStatus(rr.Id);
        Test.stopTest();

        System.assertNotEquals(null, rs);
        System.assertEquals(String.valueOf(rr.Id),    rs.requestId);
        System.assertEquals('Submitted to Regulatory', rs.status);
        System.assertEquals(false,                     rs.certificateUploaded);
        System.assertEquals(null,                      rs.basketId);
        System.assertEquals(null,                      rs.basketStatus);
    }

    @isTest
    static void testGetRequestStatus_WithBasket() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');
        Document_Basket__c basket  = makeBasket(rr.Id, 'Under Review');

        Test.startTest();
        RegulatoryActionController.RequestStatus rs =
            RegulatoryActionController.getRequestStatus(rr.Id);
        Test.stopTest();

        System.assertEquals(String.valueOf(basket.Id), rs.basketId);
        System.assertEquals('Under Review',            rs.basketStatus);
    }

    // ── startReview ───────────────────────────────────────────────────────────

    @isTest
    static void testStartReview_HappyPath_CreatesBasket() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory');

        Test.startTest();
        RegulatoryActionController.startReview(rr.Id);
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c, Current_Stage__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Under Regulatory Review', updated.Status__c);
        System.assertEquals('Regulatory Processing',   updated.Current_Stage__c);

        List<Document_Basket__c> baskets = [
            SELECT Status__c FROM Document_Basket__c WHERE Registration_Request__c = :rr.Id
        ];
        System.assertEquals(1,             baskets.size());
        System.assertEquals('Under Review', baskets[0].Status__c);
    }

    @isTest
    static void testStartReview_HappyPath_UpdatesExistingBasket() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory');
        Document_Basket__c existing = makeBasket(rr.Id, 'Documents Submitted');

        Test.startTest();
        RegulatoryActionController.startReview(rr.Id);
        Test.stopTest();

        Document_Basket__c updated = [
            SELECT Status__c FROM Document_Basket__c WHERE Id = :existing.Id
        ];
        System.assertEquals('Under Review', updated.Status__c,
            'Existing basket should be updated to Under Review');
    }

    @isTest
    static void testStartReview_WrongStatus_Throws() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Leadership Review');

        Boolean threw = false;
        Test.startTest();
        try {
            RegulatoryActionController.startReview(rr.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when status is not Submitted to Regulatory');
    }

    // ── resumeReview ──────────────────────────────────────────────────────────

    @isTest
    static void testResumeReview_FromAdditionalDocumentsRequested() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id,
            'Additional Documents Requested');
        makeBasket(rr.Id, 'Documents Submitted');

        Test.startTest();
        RegulatoryActionController.resumeReview(rr.Id);
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Under Regulatory Review', updated.Status__c);
    }

    @isTest
    static void testResumeReview_FromPendingCustomerResponse() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Pending Customer Response');
        makeBasket(rr.Id, 'Documents Submitted');

        Test.startTest();
        RegulatoryActionController.resumeReview(rr.Id);
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Under Regulatory Review', updated.Status__c);
    }

    @isTest
    static void testResumeReview_WrongStatus_Throws() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory');

        Boolean threw = false;
        Test.startTest();
        try {
            RegulatoryActionController.resumeReview(rr.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when status is not Additional Documents Requested');
    }

    // ── saveForecastWeek ──────────────────────────────────────────────────────

    @isTest
    static void testSaveForecastWeek_PersistsValues() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');

        Test.startTest();
        RegulatoryActionController.saveForecastWeek(rr.Id, 22, 2026);
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Forecast_Week__c, Forecast_Year__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals(22,   Integer.valueOf(updated.Forecast_Week__c));
        System.assertEquals(2026, Integer.valueOf(updated.Forecast_Year__c));
    }

    // ── markCompleted ─────────────────────────────────────────────────────────

    @isTest
    static void testMarkCompleted_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');
        makeBasket(rr.Id, 'Under Review');

        Registration_Request_Product__c rrp = new Registration_Request_Product__c(
            Registration_Request__c = rr.Id,
            Product__c              = prod.Id
        );
        insert rrp;

        Test.startTest();
        RegulatoryActionController.markCompleted(rr.Id, 'All documents verified');
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c, Current_Stage__c, Actual_Completion_Week__c, Actual_Completion_Year__c
            FROM   Registration_Request__c
            WHERE  Id = :rr.Id
        ];
        System.assertEquals('Completed',            updated.Status__c);
        System.assertEquals('Completed',            updated.Current_Stage__c);
        System.assertNotEquals(null, updated.Actual_Completion_Week__c);
        System.assertNotEquals(null, updated.Actual_Completion_Year__c);

        Document_Basket__c basket = [
            SELECT Status__c, Approved_Date__c FROM Document_Basket__c
            WHERE  Registration_Request__c = :rr.Id LIMIT 1
        ];
        System.assertEquals('Approved', basket.Status__c);
        System.assertNotEquals(null, basket.Approved_Date__c);
    }

    @isTest
    static void testMarkCompleted_WrongStatus_Throws() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Submitted to Regulatory');

        Boolean threw = false;
        Test.startTest();
        try {
            RegulatoryActionController.markCompleted(rr.Id, 'Remarks');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when status is not Under Regulatory Review');
    }

    @isTest
    static void testMarkCompleted_SetsProductCertStatusToPendingUpload() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');
        makeBasket(rr.Id, 'Under Review');

        Registration_Request_Product__c rrp = new Registration_Request_Product__c(
            Registration_Request__c = rr.Id,
            Product__c              = prod.Id
        );
        insert rrp;

        Test.startTest();
        RegulatoryActionController.markCompleted(rr.Id, null);
        Test.stopTest();

        Registration_Request_Product__c updatedProd = [
            SELECT Certificate_Status__c FROM Registration_Request_Product__c WHERE Id = :rrp.Id
        ];
        System.assertEquals('Pending Upload', updatedProd.Certificate_Status__c);
    }

    // ── markCertificateUploaded ───────────────────────────────────────────────

    @isTest
    static void testMarkCertificateUploaded_SetsFlag() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Completed');

        Test.startTest();
        RegulatoryActionController.markCertificateUploaded(rr.Id);
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Certificate_Uploaded__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals(true, updated.Certificate_Uploaded__c);
    }

    // ── resetCertificateUploaded ──────────────────────────────────────────────

    @isTest
    static void testResetCertificateUploaded_ClearsFlagNullDocId() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Completed');
        rr.Certificate_Uploaded__c = true;
        update rr;

        Test.startTest();
        RegulatoryActionController.resetCertificateUploaded(rr.Id, null);
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Certificate_Uploaded__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals(false, updated.Certificate_Uploaded__c);
    }

    // ── updateRARemarks ───────────────────────────────────────────────────────

    @isTest
    static void testUpdateRARemarks_PersistsRemarks() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');
        Document_Basket__c basket  = makeBasket(rr.Id, 'Under Review');

        Test.startTest();
        RegulatoryActionController.updateRARemarks(basket.Id, 'Please provide GST cert');
        Test.stopTest();

        Document_Basket__c updated = [
            SELECT RA_Remarks__c FROM Document_Basket__c WHERE Id = :basket.Id
        ];
        System.assertEquals('Please provide GST cert', updated.RA_Remarks__c);
    }

    // ── updateValidDates ──────────────────────────────────────────────────────

    @isTest
    static void testUpdateValidDates_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Completed');

        Test.startTest();
        RegulatoryActionController.updateValidDates(rr.Id, '2026-01-01', '2027-01-01');
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Certificate_Valid_From__c, Certificate_Valid_To__c
            FROM   Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals(Date.newInstance(2026, 1, 1), updated.Certificate_Valid_From__c);
        System.assertEquals(Date.newInstance(2027, 1, 1), updated.Certificate_Valid_To__c);
    }

    @isTest
    static void testUpdateValidDates_ToDateBeforeFromDate_Throws() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Completed');

        Boolean threw = false;
        Test.startTest();
        try {
            RegulatoryActionController.updateValidDates(rr.Id, '2027-01-01', '2026-01-01');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when Valid To is before Valid From');
    }

    @isTest
    static void testUpdateValidDates_SameDate_Throws() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Completed');

        Boolean threw = false;
        Test.startTest();
        try {
            RegulatoryActionController.updateValidDates(rr.Id, '2026-06-01', '2026-06-01');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when Valid To equals Valid From');
    }

    // ── linkDocumentToSlot — no-op when slot not found ────────────────────────

    @isTest
    static void testLinkDocumentToSlot_NoMatchingSlot_NoOp() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');

        Boolean threw = false;
        Test.startTest();
        try {
            RegulatoryActionController.linkDocumentToSlot(
                rr.Id, 'Nonexistent Product', 'GSTIN Certificate', 'fakeDocId'
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(!threw,
            'linkDocumentToSlot should be a no-op (not throw) when no matching slot exists');
    }

    @isTest
    static void testLinkDocumentToSlot_MatchingSlot_SetsUploadedDocId() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');

        Registration_Request_Product__c rrp = new Registration_Request_Product__c(
            Registration_Request__c = rr.Id,
            Product__c              = prod.Id
        );
        insert rrp;

        Request_Document__c rd = new Request_Document__c(
            Registration_Request_Product__c = rrp.Id,
            Document_Type__c                = 'GSTIN Certificate'
        );
        insert rd;

        Test.startTest();
        RegulatoryActionController.linkDocumentToSlot(
            rr.Id, 'Test Product', 'GSTIN Certificate', 'fakeContentDocId001'
        );
        Test.stopTest();

        Request_Document__c updated = [
            SELECT Uploaded_Document_Id__c FROM Request_Document__c WHERE Id = :rd.Id
        ];
        System.assertEquals('fakeContentDocId001', updated.Uploaded_Document_Id__c);
    }

    // ── rejectRegistrationRequest ─────────────────────────────────────────────

    @isTest
    static void testRejectRegistrationRequest_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        // No basket — updateBasketStatus returns early; avoids dependency on
        // 'Rejected' being deployed to Document_Basket__c.Status__c picklist yet.
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');

        Test.startTest();
        RegulatoryActionController.rejectRegistrationRequest(rr.Id, 'Does not meet requirements');
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c, Current_Stage__c, Rejection_Comments__c
            FROM   Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Rejected',                   updated.Status__c);
        System.assertEquals('Rejected',                   updated.Current_Stage__c);
        System.assertEquals('Does not meet requirements', updated.Rejection_Comments__c);
    }

    @isTest
    static void testRejectRegistrationRequest_BlankComment_Throws() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');

        Boolean threw = false;
        Test.startTest();
        try {
            RegulatoryActionController.rejectRegistrationRequest(rr.Id, '');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Should throw when comment is blank');
    }

    @isTest
    static void testRejectRegistrationRequest_AlreadyRejected_Throws() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Rejected');

        Boolean threw = false;
        Test.startTest();
        try {
            RegulatoryActionController.rejectRegistrationRequest(rr.Id, 'Duplicate reject');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Should throw when already Rejected');
    }

    // ── returnRegistrationRequest ─────────────────────────────────────────────

    @isTest
    static void testReturnRegistrationRequest_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');
        makeBasket(rr.Id, 'Under Review');

        Test.startTest();
        RegulatoryActionController.returnRegistrationRequest(rr.Id, 'Please attach updated GSTIN');
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c, Rejection_Comments__c
            FROM   Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Sent Back',                  updated.Status__c);
        System.assertEquals('Please attach updated GSTIN', updated.Rejection_Comments__c);

        Document_Basket__c basket = [
            SELECT Status__c FROM Document_Basket__c WHERE Registration_Request__c = :rr.Id LIMIT 1
        ];
        System.assertEquals('Documents Submitted', basket.Status__c);
    }

    @isTest
    static void testReturnRegistrationRequest_BlankComment_Throws() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');

        Boolean threw = false;
        Test.startTest();
        try {
            RegulatoryActionController.returnRegistrationRequest(rr.Id, '  ');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Should throw when comment is blank');
    }

    // ── returnAdditionalRequest ───────────────────────────────────────────────

    @isTest
    static void testReturnAdditionalRequest_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct();
        Registration_Request__c parent = makeRequest(acc.Id, prod.Id, 'Under Regulatory Review');
        Registration_Request__c child = new Registration_Request__c(
            Account__c          = acc.Id,
            Product__c          = prod.Id,
            Country__c          = 'IN',
            Status__c           = 'Under Regulatory Review',
            Request_Type__c     = 'Additional Document Request',
            Parent_Request__c   = parent.Id,
            Submitted_Date__c   = Datetime.now(),
            Year__c             = String.valueOf(Date.today().year())
        );
        insert child;

        Test.startTest();
        RegulatoryActionController.returnAdditionalRequest(child.Id, 'Certificate missing');
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Status__c, Rejection_Comments__c
            FROM   Registration_Request__c WHERE Id = :child.Id
        ];
        System.assertEquals('Sent Back',          updated.Status__c);
        System.assertEquals('Certificate missing', updated.Rejection_Comments__c);
    }
}
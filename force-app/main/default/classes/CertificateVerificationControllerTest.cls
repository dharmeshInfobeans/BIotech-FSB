@isTest
private class CertificateVerificationControllerTest {

    // ── Data helpers ──────────────────────────────────────────────────────────

    static Account makeAccount() {
        Account acc = new Account(
            Name              = 'Test Distributor',
            GSTIN_No__c       = 'TESTGSTIN001',
            Country_Key__c    = 'IN',
            E_Mail__c         = 'distributor@test.com',
            BillingStreet     = '123 Test Street',
            BillingCity       = 'Mumbai',
            BillingPostalCode = '400001'
        );
        insert acc;
        return acc;
    }

    static Product__c makeProduct(String name) {
        Product__c p = new Product__c(Name = name, Dummy_Product_Code__c = name.left(10));
        insert p;
        return p;
    }

    static Registration_Request__c makeRequest(Id accountId, Id productId) {
        Registration_Request__c rr = new Registration_Request__c(
            Account__c        = accountId,
            Product__c        = productId,
            Country__c        = 'IN',
            Status__c         = 'Completed',
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert rr;
        return rr;
    }

    static Registration_Request_Product__c makeRRP(Id requestId, Id productId, String certStatus) {
        Registration_Request_Product__c rrp = new Registration_Request_Product__c(
            Registration_Request__c = requestId,
            Product__c              = productId,
            Certificate_Status__c   = certStatus
        );
        insert rrp;
        return rrp;
    }

    // ── getProductsForCertUpload — returns list with product info ─────────────

    @isTest
    static void testGetProductsForCertUpload_ReturnsProducts() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Alpha');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        Registration_Request_Product__c rrp = makeRRP(rr.Id, prod.Id, 'Pending Upload');

        Test.startTest();
        List<CertificateVerificationController.ProductCertInfo> result =
            CertificateVerificationController.getProductsForCertUpload(rr.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(rrp.Id,           result[0].productId);
        System.assertEquals('Product Alpha',  result[0].productName);
        System.assertEquals('Pending Upload', result[0].certificateStatus);
        System.assertEquals(false,            result[0].orderUnlocked);
        System.assertNotEquals(null,          result[0].certificates);
        System.assertEquals(0,               result[0].certificates.size());
    }

    // ── getProductsForCertUpload — cert entries populated ────────────────────

    @isTest
    static void testGetProductsForCertUpload_CertEntriesIncluded() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Beta');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        Registration_Request_Product__c rrp = makeRRP(rr.Id, prod.Id, 'Uploaded');

        Product_Certificate__c cert = new Product_Certificate__c(
            Registration_Request_Product__c = rrp.Id,
            Certificate_Name__c             = 'Gov Cert 2026',
            Content_Document_Id__c          = 'fakeDocId001',
            Uploaded_By__c                  = UserInfo.getUserId(),
            Uploaded_Date__c                = Datetime.now()
        );
        insert cert;

        Test.startTest();
        List<CertificateVerificationController.ProductCertInfo> result =
            CertificateVerificationController.getProductsForCertUpload(rr.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(1, result[0].certificates.size());
        System.assertEquals(cert.Id,           result[0].certificates[0].certId);
        System.assertEquals('Gov Cert 2026',   result[0].certificates[0].certName);
        System.assertEquals('fakeDocId001',    result[0].certificates[0].contentDocumentId);
        System.assertNotEquals(null,           result[0].certificates[0].downloadUrl);
    }

    // ── getProductsForRAReview — delegates to getProductsForCertUpload ────────

    @isTest
    static void testGetProductsForRAReview_ReturnsSameAsDistributor() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Gamma');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        makeRRP(rr.Id, prod.Id, 'Uploaded');

        Test.startTest();
        List<CertificateVerificationController.ProductCertInfo> result =
            CertificateVerificationController.getProductsForRAReview(rr.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
    }

    // ── getProductsForCRMReview — returns products ────────────────────────────

    @isTest
    static void testGetProductsForCRMReview_ReturnsProducts() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Delta');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        makeRRP(rr.Id, prod.Id, 'Under CRM Review');

        Test.startTest();
        List<CertificateVerificationController.ProductCertInfo> result =
            CertificateVerificationController.getProductsForCRMReview(rr.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('Under CRM Review', result[0].certificateStatus);
    }

    // ── uploadCertificate — creates cert record, updates status ──────────────

    @isTest
    static void testUploadCertificate_CreatesCertAndSetsStatus() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Epsilon');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        Registration_Request_Product__c rrp = makeRRP(rr.Id, prod.Id, 'Pending Upload');

        ContentVersion cv = new ContentVersion(
            Title          = 'Reg Cert 2026',
            PathOnClient   = 'RegCert2026.pdf',
            VersionData    = Blob.valueOf('pdf content'),
            IsMajorVersion = true
        );
        insert cv;
        String realDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        Test.startTest();
        CertificateVerificationController.uploadCertificate(
            rrp.Id, 'Registration Certificate 2026', realDocId
        );
        try { Test.stopTest(); } catch (Exception e) { }

        List<Product_Certificate__c> certs = [
            SELECT Certificate_Name__c, Content_Document_Id__c
            FROM   Product_Certificate__c
            WHERE  Registration_Request_Product__c = :rrp.Id
        ];
        System.assertEquals(1, certs.size());
        System.assertEquals('Registration Certificate 2026', certs[0].Certificate_Name__c);

        Registration_Request_Product__c updated = [
            SELECT Certificate_Status__c FROM Registration_Request_Product__c WHERE Id = :rrp.Id
        ];
        System.assertEquals('Uploaded', updated.Certificate_Status__c);
    }

    // ── confirmProductValidity — saves date fields ────────────────────────────

    @isTest
    static void testConfirmProductValidity_SavesDates() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Zeta');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        Registration_Request_Product__c rrp = makeRRP(rr.Id, prod.Id, 'Uploaded');

        Test.startTest();
        CertificateVerificationController.confirmProductValidity(
            rrp.Id, '2026-01-01', '2027-01-01'
        );
        Test.stopTest();

        Registration_Request_Product__c updated = [
            SELECT Certificate_Valid_From__c, Certificate_Valid_To__c
            FROM   Registration_Request_Product__c WHERE Id = :rrp.Id
        ];
        System.assertEquals(Date.newInstance(2026, 1, 1), updated.Certificate_Valid_From__c);
        System.assertEquals(Date.newInstance(2027, 1, 1), updated.Certificate_Valid_To__c);
    }

    // ── submitGovernmentResponse — blank comment throws ───────────────────────

    @isTest
    static void testSubmitGovernmentResponse_BlankComment_Throws() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Eta');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        Registration_Request_Product__c rrp = makeRRP(rr.Id, prod.Id, 'Pending Upload');

        Boolean threw = false;
        Test.startTest();
        try {
            CertificateVerificationController.submitGovernmentResponse(
                rrp.Id, '', null, null, '2026-01-01', '2026-12-31'
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when comment is blank');
    }

    // ── submitGovernmentResponse — happy path (comment only) ─────────────────

    @isTest
    static void testSubmitGovernmentResponse_CommentOnly() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Theta');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        Registration_Request_Product__c rrp = makeRRP(rr.Id, prod.Id, 'Pending Upload');

        Test.startTest();
        CertificateVerificationController.submitGovernmentResponse(
            rrp.Id, 'Govt approved on 15-Jan-2026',
            null, null, '2026-01-01', '2026-12-31'
        );
        Test.stopTest();

        Registration_Request_Product__c updated = [
            SELECT Certificate_Status__c, Distributor_Comments__c,
                   Certificate_Valid_From__c, Certificate_Valid_To__c
            FROM   Registration_Request_Product__c WHERE Id = :rrp.Id
        ];
        System.assertEquals('Uploaded',                      updated.Certificate_Status__c);
        System.assertEquals('Govt approved on 15-Jan-2026',  updated.Distributor_Comments__c);
        System.assertEquals(Date.valueOf('2026-01-01'), updated.Certificate_Valid_From__c);
        System.assertEquals(Date.valueOf('2026-12-31'), updated.Certificate_Valid_To__c);
    }

    // ── removeCertificate — removes cert, resets status when last cert gone ───

    @isTest
    static void testRemoveCertificate_LastCert_ResetsStatus() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Iota');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        Registration_Request_Product__c rrp = makeRRP(rr.Id, prod.Id, 'Uploaded');

        Product_Certificate__c cert = new Product_Certificate__c(
            Registration_Request_Product__c = rrp.Id,
            Certificate_Name__c             = 'Test Cert',
            Uploaded_By__c                  = UserInfo.getUserId(),
            Uploaded_Date__c                = Datetime.now()
        );
        insert cert;

        Test.startTest();
        CertificateVerificationController.removeCertificate(cert.Id);
        Test.stopTest();

        List<Product_Certificate__c> remaining = [
            SELECT Id FROM Product_Certificate__c WHERE Registration_Request_Product__c = :rrp.Id
        ];
        System.assertEquals(0, remaining.size(), 'Cert record should be deleted');

        Registration_Request_Product__c updated = [
            SELECT Certificate_Status__c FROM Registration_Request_Product__c WHERE Id = :rrp.Id
        ];
        System.assertEquals('Pending Upload', updated.Certificate_Status__c,
            'Status should reset to Pending Upload when last cert is removed');
    }

    // ── forwardToCRM — no uploaded products throws ────────────────────────────

    @isTest
    static void testForwardToCRM_NoUploadedProducts_Throws() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Kappa');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        makeRRP(rr.Id, prod.Id, 'Pending Upload');

        Boolean threw = false;
        Test.startTest();
        try {
            CertificateVerificationController.forwardToCRM(rr.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when no products have Uploaded status');
    }

    // ── forwardToCRM — happy path sets Under CRM Review ──────────────────────

    @isTest
    static void testForwardToCRM_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Lambda');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        Registration_Request_Product__c rrp = makeRRP(rr.Id, prod.Id, 'Uploaded');

        Test.startTest();
        CertificateVerificationController.forwardToCRM(rr.Id);
        Test.stopTest();

        Registration_Request_Product__c updated = [
            SELECT Certificate_Status__c FROM Registration_Request_Product__c WHERE Id = :rrp.Id
        ];
        System.assertEquals('Under CRM Review', updated.Certificate_Status__c);
    }

    // ── forwardProductToCRM — wrong status throws ─────────────────────────────

    @isTest
    static void testForwardProductToCRM_WrongStatus_Throws() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Mu');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        Registration_Request_Product__c rrp = makeRRP(rr.Id, prod.Id, 'Pending Upload');

        Boolean threw = false;
        Test.startTest();
        try {
            CertificateVerificationController.forwardProductToCRM(rrp.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when status is not Uploaded');
    }

    // ── forwardProductToCRM — happy path ──────────────────────────────────────

    @isTest
    static void testForwardProductToCRM_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Nu');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        Registration_Request_Product__c rrp = makeRRP(rr.Id, prod.Id, 'Uploaded');

        Test.startTest();
        CertificateVerificationController.forwardProductToCRM(rrp.Id);
        Test.stopTest();

        Registration_Request_Product__c updated = [
            SELECT Certificate_Status__c FROM Registration_Request_Product__c WHERE Id = :rrp.Id
        ];
        System.assertEquals('Under CRM Review', updated.Certificate_Status__c);
    }

    // ── sendBackCertificate — blank comment throws ────────────────────────────

    @isTest
    static void testSendBackCertificate_BlankComment_Throws() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Xi');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        Registration_Request_Product__c rrp = makeRRP(rr.Id, prod.Id, 'Uploaded');

        Boolean threw = false;
        Test.startTest();
        try {
            CertificateVerificationController.sendBackCertificate(rrp.Id, '');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when comment is blank');
    }

    // ── sendBackCertificate — sets Pending and stores comments ───────────────

    @isTest
    static void testSendBackCertificate_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Omicron');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        Registration_Request_Product__c rrp = makeRRP(rr.Id, prod.Id, 'Uploaded');

        Test.startTest();
        CertificateVerificationController.sendBackCertificate(rrp.Id, 'Incorrect certificate format');
        Test.stopTest();

        Registration_Request_Product__c updated = [
            SELECT Certificate_Status__c, Certificate_Rejection_Comments__c
            FROM   Registration_Request_Product__c WHERE Id = :rrp.Id
        ];
        System.assertEquals('Pending Upload', updated.Certificate_Status__c);
        System.assertEquals('Incorrect certificate format', updated.Certificate_Rejection_Comments__c);
    }

    // ── verifyCertificate — wrong status throws ───────────────────────────────

    @isTest
    static void testVerifyCertificate_WrongStatus_Throws() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Pi');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        Registration_Request_Product__c rrp = makeRRP(rr.Id, prod.Id, 'Uploaded');

        Boolean threw = false;
        Test.startTest();
        try {
            CertificateVerificationController.verifyCertificate(rrp.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when status is not Under CRM Review');
    }

    // ── verifyCertificate — happy path sets Verified ──────────────────────────

    @isTest
    static void testVerifyCertificate_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Rho');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        Registration_Request_Product__c rrp = makeRRP(rr.Id, prod.Id, 'Under CRM Review');

        Test.startTest();
        CertificateVerificationController.verifyCertificate(rrp.Id);
        Test.stopTest();

        Registration_Request_Product__c updated = [
            SELECT Certificate_Status__c, Certificate_Verified_Date__c
            FROM   Registration_Request_Product__c WHERE Id = :rrp.Id
        ];
        System.assertEquals('Verified', updated.Certificate_Status__c);
        System.assertNotEquals(null, updated.Certificate_Verified_Date__c);
    }

    // ── rejectCertificate — blank comment throws ──────────────────────────────

    @isTest
    static void testRejectCertificate_BlankComment_Throws() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Sigma');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        Registration_Request_Product__c rrp = makeRRP(rr.Id, prod.Id, 'Under CRM Review');

        Boolean threw = false;
        Test.startTest();
        try {
            CertificateVerificationController.rejectCertificate(rrp.Id, '');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when rejection reason is blank');
    }

    // ── rejectCertificate — sets Rejected with comments ──────────────────────

    @isTest
    static void testRejectCertificate_HappyPath() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Tau');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        Registration_Request_Product__c rrp = makeRRP(rr.Id, prod.Id, 'Under CRM Review');

        Test.startTest();
        CertificateVerificationController.rejectCertificate(rrp.Id, 'Certificate expired');
        Test.stopTest();

        Registration_Request_Product__c updated = [
            SELECT Certificate_Status__c, Certificate_Rejection_Comments__c
            FROM   Registration_Request_Product__c WHERE Id = :rrp.Id
        ];
        System.assertEquals('Rejected', updated.Certificate_Status__c);
        System.assertEquals('Certificate expired', updated.Certificate_Rejection_Comments__c);
    }

    // ── unlockProductOrder — wrong status throws ──────────────────────────────

    @isTest
    static void testUnlockProductOrder_WrongStatus_Throws() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Upsilon');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        Registration_Request_Product__c rrp = makeRRP(rr.Id, prod.Id, 'Pending Upload');

        Boolean threw = false;
        Test.startTest();
        try {
            CertificateVerificationController.unlockProductOrder(rrp.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when status is not Verified or Uploaded');
    }

    // ── unlockProductOrder — from Verified sets Order_Unlocked__c ────────────

    @isTest
    static void testUnlockProductOrder_FromVerified() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Phi');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        Registration_Request_Product__c rrp = makeRRP(rr.Id, prod.Id, 'Verified');

        Test.startTest();
        CertificateVerificationController.unlockProductOrder(rrp.Id);
        Test.stopTest();

        Registration_Request_Product__c updated = [
            SELECT Order_Unlocked__c FROM Registration_Request_Product__c WHERE Id = :rrp.Id
        ];
        System.assertEquals(true, updated.Order_Unlocked__c);
    }

    // ── getCRMCertificateQueue — products Under CRM Review appear ────────────

    @isTest
    static void testGetCRMCertificateQueue_ReturnsItems() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Chi');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        makeRRP(rr.Id, prod.Id, 'Under CRM Review');

        Test.startTest();
        List<CertificateVerificationController.CRMQueueItem> items =
            CertificateVerificationController.getCRMCertificateQueue();
        Test.stopTest();

        System.assert(items.size() >= 1);
        Boolean found = false;
        for (CertificateVerificationController.CRMQueueItem item : items) {
            if (item.requestId == rr.Id) {
                found = true;
                System.assertEquals(1, item.pendingCount);
                System.assertNotEquals(null, item.distributorName);
            }
        }
        System.assert(found, 'Request should appear in CRM queue');
    }

    // ── getCRMCertificateQueue — unlocked products counted separately ─────────

    @isTest
    static void testGetCRMCertificateQueue_UnlockedCountSeparate() {
        Account acc     = makeAccount();
        Product__c prod1 = makeProduct('Product Psi');
        Product__c prod2 = makeProduct('Product Omega');
        Registration_Request__c rr = makeRequest(acc.Id, prod1.Id);

        Registration_Request_Product__c rrp1 = makeRRP(rr.Id, prod1.Id, 'Under CRM Review');
        Registration_Request_Product__c rrp2 = makeRRP(rr.Id, prod2.Id, 'Verified');
        rrp2.Order_Unlocked__c = true;
        update rrp2;

        Test.startTest();
        List<CertificateVerificationController.CRMQueueItem> items =
            CertificateVerificationController.getCRMCertificateQueue();
        Test.stopTest();

        Boolean found = false;
        for (CertificateVerificationController.CRMQueueItem item : items) {
            if (item.requestId == rr.Id) {
                found = true;
                System.assertEquals(1, item.pendingCount,  'pendingCount should be 1');
                System.assertEquals(1, item.unlockedCount, 'unlockedCount should be 1');
            }
        }
        System.assert(found, 'Request should appear in CRM queue');
    }

    // ── getCertFileData — not found throws ────────────────────────────────────

    @isTest
    static void testGetCertFileData_NotFound_Throws() {
        // Create a ContentDocument then delete it so we have a valid-format non-existent Id
        ContentVersion cv = new ContentVersion(
            Title          = 'TempCert',
            PathOnClient   = 'TempCert.pdf',
            VersionData    = Blob.valueOf('temp'),
            IsMajorVersion = true
        );
        insert cv;
        ContentVersion inserted = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        Id docId = inserted.ContentDocumentId;
        delete [SELECT Id FROM ContentDocument WHERE Id = :docId];

        Boolean threw = false;
        Test.startTest();
        try {
            CertificateVerificationController.getCertFileData(String.valueOf(docId));
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when content doc not found');
    }

    // ── getCertFileData — PDF returns correct mimeType and body ──────────────

    @isTest
    static void testGetCertFileData_PDF_ReturnsMimeAndBody() {
        ContentVersion cv = new ContentVersion(
            Title          = 'TestPDF',
            PathOnClient   = 'TestPDF.pdf',
            VersionData    = Blob.valueOf('PDF file content'),
            IsMajorVersion = true
        );
        insert cv;
        ContentVersion inserted = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        Test.startTest();
        Map<String, String> result = CertificateVerificationController.getCertFileData(
            String.valueOf(inserted.ContentDocumentId)
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('application/pdf', result.get('mimeType'));
        System.assertNotEquals(null, result.get('body'));
        System.assertNotEquals(null, result.get('filename'));
    }
}
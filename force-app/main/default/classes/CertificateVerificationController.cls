public with sharing class CertificateVerificationController {

    public class ProductCertInfo {
        @AuraEnabled public Id     productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String certificateStatus;
        @AuraEnabled public Boolean orderUnlocked;
        @AuraEnabled public String rejectionComments;
        @AuraEnabled public String distributorComments;
        @AuraEnabled public List<CertEntry> certificates;
        @AuraEnabled public Integer validFromWeek;
        @AuraEnabled public Integer validFromYear;
        @AuraEnabled public Integer validToWeek;
        @AuraEnabled public Integer validToYear;
        @AuraEnabled public String confirmedValidFrom;
        @AuraEnabled public String confirmedValidTo;
    }

    public class CertEntry {
        @AuraEnabled public Id     certId;
        @AuraEnabled public String certName;
        @AuraEnabled public String contentDocumentId;
        @AuraEnabled public String downloadUrl;
        @AuraEnabled public String uploadedByName;
        @AuraEnabled public Datetime uploadedDate;
    }

    // ── Distributor: get products with cert status + uploaded certs ────────────
    @AuraEnabled
    public static List<ProductCertInfo> getProductsForCertUpload(Id requestId) {
        ElevatedQuery eq = new ElevatedQuery();
        List<Registration_Request_Product__c> products = eq.getProducts(requestId);
        Map<Id, List<Product_Certificate__c>> certMap = eq.getCertsByProduct(requestId);

        List<ProductCertInfo> result = new List<ProductCertInfo>();
        for (Registration_Request_Product__c p : products) {
            ProductCertInfo info = new ProductCertInfo();
            info.productId           = p.Id;
            info.productName         = p.Product__r.Name;
            info.certificateStatus   = p.Certificate_Status__c;
            info.orderUnlocked       = p.Order_Unlocked__c;
            info.rejectionComments   = p.Certificate_Rejection_Comments__c;
            info.distributorComments = p.Distributor_Comments__c;
            info.certificates        = buildCertEntries(certMap.get(p.Id), true);
            info.validFromWeek       = p.Valid_From_Week__c != null ? Integer.valueOf(p.Valid_From_Week__c) : null;
            info.validFromYear       = p.Valid_From_Year__c != null ? Integer.valueOf(p.Valid_From_Year__c) : null;
            info.validToWeek         = p.Valid_To_Week__c   != null ? Integer.valueOf(p.Valid_To_Week__c)   : null;
            info.validToYear         = p.Valid_To_Year__c   != null ? Integer.valueOf(p.Valid_To_Year__c)   : null;
            info.confirmedValidFrom  = p.Certificate_Valid_From__c != null ? String.valueOf(p.Certificate_Valid_From__c) : null;
            info.confirmedValidTo    = p.Certificate_Valid_To__c   != null ? String.valueOf(p.Certificate_Valid_To__c)   : null;
            result.add(info);
        }
        return result;
    }

    // ── RA Team: get products with certs (contentDocumentId for blob download) ──
    @AuraEnabled
    public static List<ProductCertInfo> getProductsForRAReview(Id requestId) {
        return getProductsForCertUpload(requestId);
    }

    // ── CRM: get products with cert NAMES ONLY (no file IDs, no download) ────
    @AuraEnabled
    public static List<ProductCertInfo> getProductsForCRMReview(Id requestId) {
        ElevatedQuery eq = new ElevatedQuery();
        List<Registration_Request_Product__c> products = eq.getProducts(requestId);
        Map<Id, List<Product_Certificate__c>> certMap = eq.getCertsByProduct(requestId);

        List<ProductCertInfo> result = new List<ProductCertInfo>();
        for (Registration_Request_Product__c p : products) {
            ProductCertInfo info = new ProductCertInfo();
            info.productId           = p.Id;
            info.productName         = p.Product__r.Name;
            info.certificateStatus   = p.Certificate_Status__c;
            info.orderUnlocked       = p.Order_Unlocked__c;
            info.rejectionComments   = p.Certificate_Rejection_Comments__c;
            info.distributorComments = p.Distributor_Comments__c;
            info.certificates        = buildCertEntries(certMap.get(p.Id), true);
            result.add(info);
        }
        return result;
    }

    // ── Distributor: upload a certificate for a product ────────────────────────
    @AuraEnabled
    public static void uploadCertificate(Id productId, String certName, String contentDocumentId) {
        try {
            ElevatedQuery eq = new ElevatedQuery();
            eq.insertCert(new Product_Certificate__c(
                Registration_Request_Product__c = productId,
                Certificate_Name__c             = certName,
                Content_Document_Id__c          = contentDocumentId,
                Uploaded_By__c                  = UserInfo.getUserId(),
                Uploaded_Date__c                = Datetime.now()
            ));
            eq.updateProduct(new Registration_Request_Product__c(
                Id                    = productId,
                Certificate_Status__c = 'Uploaded'
            ));

            Id requestId = eq.getRequestIdFromProduct(productId);
            if (requestId != null) {
                List<String> docIds = new List<String>{ contentDocumentId };
                DocumentSecurityService.enforceVisibility(docIds, requestId);
            }

            RegistrationApprovalHistoryService.log(
                requestId, 'Certificate Uploaded: ' + certName,
                null, null, null, 'Certificate Verification'
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── RA Team: confirm per-product validity dates ───────────────────────────
    @AuraEnabled
    public static void confirmProductValidity(Id productId, String validFromDate, String validToDate) {
        try {
            Date fromDate = String.isNotBlank(validFromDate) ? Date.valueOf(validFromDate) : null;
            Date toDate   = String.isNotBlank(validToDate)   ? Date.valueOf(validToDate)   : null;
            new ElevatedQuery().updateProduct(new Registration_Request_Product__c(
                Id                        = productId,
                Certificate_Valid_From__c = fromDate,
                Certificate_Valid_To__c   = toDate
            ));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Distributor: submit government approval (comment required, certs optional) ─
    @AuraEnabled
    public static void submitGovernmentResponse(Id productId, String comments, List<String> contentDocumentIds, List<String> certNames, String validFromDate, String validToDate) {
        try {
            if (String.isBlank(comments)) {
                throw new AuraHandledException('A comment is required when submitting government approval.');
            }
            if (String.isBlank(validFromDate) || String.isBlank(validToDate)) {
                throw new AuraHandledException('Certificate validity dates (Valid From and Valid To) are required.');
            }
            ElevatedQuery eq = new ElevatedQuery();
            Id requestId = eq.getRequestIdFromProduct(productId);
            eq.updateProduct(new Registration_Request_Product__c(
                Id                        = productId,
                Distributor_Comments__c   = comments,
                Certificate_Status__c     = 'Uploaded',
                Certificate_Valid_From__c = Date.valueOf(validFromDate),
                Certificate_Valid_To__c   = Date.valueOf(validToDate)
            ));
            Boolean hasDocs = contentDocumentIds != null && !contentDocumentIds.isEmpty();
            if (hasDocs) {
                List<Product_Certificate__c> certs = new List<Product_Certificate__c>();
                for (Integer i = 0; i < contentDocumentIds.size(); i++) {
                    String docId = contentDocumentIds[i];
                    if (String.isBlank(docId)) continue;
                    String name = (certNames != null && certNames.size() > i && String.isNotBlank(certNames[i]))
                        ? certNames[i] : 'Registration Certificate';
                    certs.add(new Product_Certificate__c(
                        Registration_Request_Product__c = productId,
                        Certificate_Name__c             = name,
                        Content_Document_Id__c          = docId,
                        Uploaded_By__c                  = UserInfo.getUserId(),
                        Uploaded_Date__c                = Datetime.now()
                    ));
                }
                if (!certs.isEmpty()) {
                    eq.insertCerts(certs);
                }
                if (requestId != null) {
                    DocumentSecurityService.enforceVisibility(contentDocumentIds, requestId);
                }
            }
            if (requestId != null) {
                RegistrationNotificationService.notifyFromApex(requestId, 'CERTIFICATE_UPLOADED');
                RegistrationApprovalHistoryService.log(
                    requestId,
                    'Government Approval Submitted' + (hasDocs ? ' with ' + contentDocumentIds.size() + ' Certificate(s)' : ' (Comment Only)'),
                    'Pending', 'Uploaded', comments, 'Certificate Verification'
                );
            }
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Distributor: remove a certificate ─────────────────────────────────────
    @AuraEnabled
    public static void removeCertificate(Id certId) {
        try {
            ElevatedQuery eq = new ElevatedQuery();
            Product_Certificate__c cert = eq.getCert(certId);
            if (cert == null) throw new AuraHandledException('Certificate not found.');
            Id productId = cert.Registration_Request_Product__c;
            if (String.isNotBlank(cert.Content_Document_Id__c)) {
                try {
                    eq.deleteDoc(new ContentDocument(Id = cert.Content_Document_Id__c));
                } catch (Exception ex) {
                    System.debug(LoggingLevel.WARN, 'Content doc delete failed: ' + ex.getMessage());
                }
            }
            eq.deleteCert(cert);

            List<Product_Certificate__c> remaining = eq.getCertsForProduct(productId);
            if (remaining.isEmpty()) {
                eq.updateProduct(new Registration_Request_Product__c(
                    Id                      = productId,
                    Certificate_Status__c   = 'Pending Upload',
                    Distributor_Comments__c = null
                ));
            }
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── RA Team: forward all uploaded products to CRM for review ──────────────
    @AuraEnabled
    public static void forwardToCRM(Id requestId) {
        try {
            ElevatedQuery eq = new ElevatedQuery();
            List<Registration_Request_Product__c> products = eq.getProducts(requestId);
            List<Registration_Request_Product__c> toUpdate = new List<Registration_Request_Product__c>();
            for (Registration_Request_Product__c p : products) {
                if (p.Certificate_Status__c == 'Uploaded') {
                    toUpdate.add(new Registration_Request_Product__c(
                        Id                    = p.Id,
                        Certificate_Status__c = 'Under CRM Review'
                    ));
                }
            }
            if (toUpdate.isEmpty()) {
                throw new AuraHandledException('No products with uploaded certificates to forward.');
            }
            eq.updateProducts(toUpdate);
            RegistrationNotificationService.notifyFromApex(requestId, 'CERTIFICATE_FORWARDED_TO_CRM');
            RegistrationApprovalHistoryService.log(
                requestId, 'Certificates Forwarded to CRM',
                null, null, null, 'Certificate Verification'
            );
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── RA Team: forward a single product's certificate to CRM ───────────────
    @AuraEnabled
    public static void forwardProductToCRM(Id productId) {
        try {
            ElevatedQuery eq = new ElevatedQuery();
            Registration_Request_Product__c p = eq.getProduct(productId);
            if (p == null) throw new AuraHandledException('Product not found.');
            if (p.Certificate_Status__c != 'Uploaded') {
                throw new AuraHandledException('Certificate must be Uploaded to forward to CRM.');
            }
            eq.updateProduct(new Registration_Request_Product__c(
                Id                    = productId,
                Certificate_Status__c = 'Under CRM Review'
            ));
            Id requestId = eq.getRequestIdFromProduct(productId);
            RegistrationNotificationService.notifyFromApex(requestId, 'CERTIFICATE_FORWARDED_TO_CRM');
            RegistrationApprovalHistoryService.log(
                requestId, 'Certificate Forwarded to CRM: ' + p.Product__r.Name,
                'Uploaded', 'Under CRM Review', null, 'Certificate Verification'
            );
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── RA or CRM: send back certificate for re-upload ────────────────────────
    @AuraEnabled
    public static void sendBackCertificate(Id productId, String comments) {
        try {
            if (String.isBlank(comments)) {
                throw new AuraHandledException('Comments are required when sending back a certificate.');
            }
            ElevatedQuery eq = new ElevatedQuery();
            Registration_Request_Product__c p = eq.getProduct(productId);
            if (p == null) throw new AuraHandledException('Product not found.');
            if (p.Certificate_Status__c != 'Uploaded' && p.Certificate_Status__c != 'Under CRM Review') {
                throw new AuraHandledException('Certificate must be Uploaded or Under CRM Review to send back.');
            }
            String fromStatus = p.Certificate_Status__c;
            eq.updateProduct(new Registration_Request_Product__c(
                Id                                = productId,
                Certificate_Status__c             = 'Pending Upload',
                Certificate_Rejection_Comments__c = comments,
                Distributor_Comments__c           = null
            ));
            Id requestId = eq.getRequestIdFromProduct(productId);
            RegistrationNotificationService.notifyFromApex(requestId, 'CERTIFICATE_SENT_BACK');
            RegistrationApprovalHistoryService.log(
                requestId, 'Certificate Sent Back: ' + p.Product__r.Name,
                fromStatus, 'Pending Upload', comments, 'Certificate Verification'
            );
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── CRM: verify a product's certificate ───────────────────────────────────
    @AuraEnabled
    public static void verifyCertificate(Id productId) {
        try {
            ElevatedQuery eq = new ElevatedQuery();
            Registration_Request_Product__c p = eq.getProduct(productId);
            if (p == null) throw new AuraHandledException('Product not found.');
            if (p.Certificate_Status__c != 'Under CRM Review') {
                throw new AuraHandledException('Certificate must be Under CRM Review to verify.');
            }
            eq.updateProduct(new Registration_Request_Product__c(
                Id                          = productId,
                Certificate_Status__c       = 'Verified',
                Certificate_Verified_Date__c = Datetime.now()
            ));

            Id requestId = eq.getRequestIdFromProduct(productId);
            RegistrationNotificationService.notifyFromApex(requestId, 'CERTIFICATE_VERIFIED');
            RegistrationApprovalHistoryService.log(
                requestId, 'Certificate Verified by CRM: ' + p.Product__r.Name,
                'Under CRM Review', 'Verified', null, 'Certificate Verification'
            );
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── CRM: reject a product's certificate ───────────────────────────────────
    @AuraEnabled
    public static void rejectCertificate(Id productId, String comments) {
        try {
            if (String.isBlank(comments)) {
                throw new AuraHandledException('Rejection reason is required.');
            }
            ElevatedQuery eq = new ElevatedQuery();
            Registration_Request_Product__c p = eq.getProduct(productId);
            if (p == null) throw new AuraHandledException('Product not found.');
            if (p.Certificate_Status__c != 'Under CRM Review' && p.Certificate_Status__c != 'Uploaded') {
                throw new AuraHandledException('Certificate must be Uploaded or Under CRM Review to reject.');
            }
            eq.updateProduct(new Registration_Request_Product__c(
                Id                                = productId,
                Certificate_Status__c             = 'Rejected',
                Certificate_Rejection_Comments__c = comments
            ));

            Id requestId = eq.getRequestIdFromProduct(productId);
            RegistrationNotificationService.notifyFromApex(requestId, 'CERTIFICATE_REJECTED');
            RegistrationApprovalHistoryService.log(
                requestId, 'Certificate Rejected by CRM: ' + p.Product__r.Name,
                'Under CRM Review', 'Rejected', comments, 'Certificate Verification'
            );
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── RA Team: unlock order for a verified product ──────────────────────────
    @AuraEnabled
    public static void unlockProductOrder(Id productId) {
        try {
            ElevatedQuery eq = new ElevatedQuery();
            Registration_Request_Product__c p = eq.getProduct(productId);
            if (p == null) throw new AuraHandledException('Product not found.');
            if (p.Certificate_Status__c != 'Verified' && p.Certificate_Status__c != 'Uploaded') {
                throw new AuraHandledException('Certificate must be Verified or Uploaded before unlocking order.');
            }
            Boolean isDirectUnlock = p.Certificate_Status__c == 'Uploaded';
            eq.updateProduct(new Registration_Request_Product__c(
                Id                    = productId,
                Order_Unlocked__c     = true
            ));

            Id requestId = eq.getRequestIdFromProduct(productId);
            RegistrationNotificationService.notifyFromApex(requestId, 'PRODUCT_ORDER_UNLOCKED');
            if (isDirectUnlock) {
                RegistrationNotificationService.notifyFromApex(requestId, 'ORDER_UNLOCKED_BY_RA');
            }
            String auditAction = isDirectUnlock
                ? 'Order Unlocked Directly by RA (bypass CRM): ' + p.Product__r.Name
                : 'Order Unlocked: ' + p.Product__r.Name;
            String fromStatus  = isDirectUnlock ? 'Uploaded' : 'Verified';
            RegistrationApprovalHistoryService.log(
                requestId, auditAction,
                fromStatus, 'Order Unlocked', null, 'Certificate Verification'
            );
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── CRM Queue: get requests with products under CRM review ────────────────
    @AuraEnabled(cacheable=true)
    public static List<CRMQueueItem> getCRMCertificateQueue() {
        ElevatedQuery eq = new ElevatedQuery();
        return eq.getCRMQueue();
    }

    public class CRMQueueItem {
        @AuraEnabled public Id      requestId;
        @AuraEnabled public String  requestName;
        @AuraEnabled public String  distributorName;
        @AuraEnabled public String  country;
        @AuraEnabled public String  status;
        @AuraEnabled public Integer pendingCount;
        @AuraEnabled public Integer unlockedCount;
        @AuraEnabled public Datetime submittedDate;
    }

    // ── Helper: build cert entries with or without file access ─────────────────
    private static List<CertEntry> buildCertEntries(List<Product_Certificate__c> certs, Boolean includeFileAccess) {
        return buildCertEntries(certs, includeFileAccess, '', false);
    }

    private static List<CertEntry> buildCertEntries(List<Product_Certificate__c> certs, Boolean includeFileAccess, String urlBase, Boolean useLightningView) {
        List<CertEntry> entries = new List<CertEntry>();
        if (certs == null) return entries;
        for (Product_Certificate__c c : certs) {
            CertEntry e = new CertEntry();
            e.certId         = c.Id;
            e.certName       = c.Certificate_Name__c;
            e.uploadedDate   = c.Uploaded_Date__c;
            e.uploadedByName = c.Uploaded_By__r?.Name;
            if (includeFileAccess && String.isNotBlank(c.Content_Document_Id__c)) {
                e.contentDocumentId = c.Content_Document_Id__c;
                e.downloadUrl = useLightningView
                    ? urlBase + '/lightning/r/ContentDocument/' + c.Content_Document_Id__c + '/view'
                    : '/sfc/servlet.shepherd/document/download/' + c.Content_Document_Id__c;
            }
            entries.add(e);
        }
        return entries;
    }

    // ── Without-sharing inner class ───────────────────────────────────────────
    private without sharing class ElevatedQuery {

        public List<Registration_Request_Product__c> getProducts(Id requestId) {
            return [
                SELECT Id, Product__r.Name, Certificate_Status__c,
                       Order_Unlocked__c, Certificate_Rejection_Comments__c, Distributor_Comments__c,
                       Valid_From_Week__c, Valid_From_Year__c, Valid_To_Week__c, Valid_To_Year__c,
                       Certificate_Valid_From__c, Certificate_Valid_To__c
                FROM   Registration_Request_Product__c
                WHERE  Registration_Request__c = :requestId
                ORDER BY Product__r.Name
            ];
        }

        public Registration_Request_Product__c getProduct(Id productId) {
            List<Registration_Request_Product__c> rows = [
                SELECT Id, Product__r.Name, Certificate_Status__c,
                       Order_Unlocked__c, Registration_Request__c
                FROM   Registration_Request_Product__c
                WHERE  Id = :productId
                LIMIT  1
            ];
            return rows.isEmpty() ? null : rows[0];
        }

        public Id getRequestIdFromProduct(Id productId) {
            List<Registration_Request_Product__c> rows = [
                SELECT Registration_Request__c
                FROM   Registration_Request_Product__c
                WHERE  Id = :productId
                LIMIT  1
            ];
            return rows.isEmpty() ? null : rows[0].Registration_Request__c;
        }

        public Map<Id, List<Product_Certificate__c>> getCertsByProduct(Id requestId) {
            Map<Id, List<Product_Certificate__c>> result = new Map<Id, List<Product_Certificate__c>>();
            for (Product_Certificate__c c : [
                SELECT Id, Certificate_Name__c, Content_Document_Id__c,
                       Uploaded_By__r.Name, Uploaded_Date__c,
                       Registration_Request_Product__c
                FROM   Product_Certificate__c
                WHERE  Registration_Request_Product__r.Registration_Request__c = :requestId
                ORDER BY Uploaded_Date__c
            ]) {
                if (!result.containsKey(c.Registration_Request_Product__c)) {
                    result.put(c.Registration_Request_Product__c, new List<Product_Certificate__c>());
                }
                result.get(c.Registration_Request_Product__c).add(c);
            }
            return result;
        }

        public Product_Certificate__c getCert(Id certId) {
            List<Product_Certificate__c> rows = [
                SELECT Id, Certificate_Name__c, Content_Document_Id__c,
                       Registration_Request_Product__c
                FROM   Product_Certificate__c
                WHERE  Id = :certId
                LIMIT  1
            ];
            return rows.isEmpty() ? null : rows[0];
        }

        public List<Product_Certificate__c> getCertsForProduct(Id productId) {
            return [
                SELECT Id FROM Product_Certificate__c
                WHERE  Registration_Request_Product__c = :productId
            ];
        }

        public List<CRMQueueItem> getCRMQueue() {
            Map<Id, CRMQueueItem> queueMap = new Map<Id, CRMQueueItem>();
            for (Registration_Request_Product__c p : [
                SELECT Registration_Request__c,
                       Registration_Request__r.Name,
                       Registration_Request__r.Account__r.Name,
                       Registration_Request__r.Country__c,
                       Registration_Request__r.Status__c,
                       Registration_Request__r.Submitted_Date__c,
                       Certificate_Status__c,
                       Order_Unlocked__c
                FROM   Registration_Request_Product__c
                WHERE  Certificate_Status__c = 'Under CRM Review'
                OR     Order_Unlocked__c = true
                ORDER BY Registration_Request__r.LastModifiedDate DESC
            ]) {
                Id reqId = p.Registration_Request__c;
                if (!queueMap.containsKey(reqId)) {
                    CRMQueueItem item = new CRMQueueItem();
                    item.requestId       = reqId;
                    item.requestName     = p.Registration_Request__r.Name;
                    item.distributorName = p.Registration_Request__r.Account__r.Name;
                    item.country         = p.Registration_Request__r.Country__c;
                    item.status          = p.Registration_Request__r.Status__c;
                    item.submittedDate   = p.Registration_Request__r.Submitted_Date__c;
                    item.pendingCount    = 0;
                    item.unlockedCount   = 0;
                    queueMap.put(reqId, item);
                }
                CRMQueueItem item = queueMap.get(reqId);
                if (p.Certificate_Status__c == 'Under CRM Review') {
                    item.pendingCount++;
                } else if (p.Order_Unlocked__c) {
                    item.unlockedCount++;
                }
            }
            return queueMap.values();
        }

        public ContentVersion getContentVersion(String contentDocumentId) {
            List<ContentVersion> rows = [
                SELECT Title, PathOnClient, FileType, VersionData
                FROM   ContentVersion
                WHERE  ContentDocumentId = :contentDocumentId
                AND    IsLatest = true
                LIMIT  1
            ];
            return rows.isEmpty() ? null : rows[0];
        }

        public void insertCert(Product_Certificate__c cert)               { insert cert; }
        public void insertCerts(List<Product_Certificate__c> certs)       { insert certs; }
        public void deleteCert(Product_Certificate__c cert) { delete cert; }
        public void deleteDoc(ContentDocument doc)          { delete doc; }
        public void updateProduct(Registration_Request_Product__c p) { update p; }
        public void updateProducts(List<Registration_Request_Product__c> ps) { update ps; }
    }

    @AuraEnabled(cacheable=true)
    public static String getContentVersionId(String contentDocumentId) {
        List<ContentVersion> cvs = [
            SELECT Id FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
              AND IsLatest = true
            LIMIT 1
        ];
        if (cvs.isEmpty()) throw new AuraHandledException('File not found.');
        return cvs[0].Id;
    }

    @AuraEnabled
    public static Map<String, String> getCertFileData(String contentDocumentId) {
        try {
            ContentVersion cv = new ElevatedQuery().getContentVersion(contentDocumentId);
            if (cv == null) throw new AuraHandledException('Certificate file not found.');
            String mime = 'application/octet-stream';
            if      (cv.FileType == 'PDF')                   mime = 'application/pdf';
            else if (cv.FileType == 'PNG')                   mime = 'image/png';
            else if (cv.FileType == 'JPG' || cv.FileType == 'JPEG') mime = 'image/jpeg';
            String filename = String.isNotBlank(cv.PathOnClient) ? cv.PathOnClient : cv.Title;
            Map<String, String> result = new Map<String, String>();
            result.put('filename', filename);
            result.put('body',     EncodingUtil.base64Encode(cv.VersionData));
            result.put('mimeType', mime);
            return result;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
public with sharing class DistributorRequestDetailController {

    // ── Wrappers ──────────────────────────────────────────────────────────────

    public class RequestDetail {
        @AuraEnabled public String             id;
        @AuraEnabled public String             name;
        @AuraEnabled public String             status;
        @AuraEnabled public String             currentStage;
        @AuraEnabled public String             productName;
        @AuraEnabled public String             allProductNames;
        @AuraEnabled public String             country;
        @AuraEnabled public String             region;
        @AuraEnabled public String             documentTypes;
        @AuraEnabled public String             remarks;
        @AuraEnabled public String             rejectionComments;
        @AuraEnabled public String             requestType;
        @AuraEnabled public String             submittedDate;
        @AuraEnabled public String             validFrom;
        @AuraEnabled public String             validTo;
        @AuraEnabled public Boolean            certificateUploaded;
        @AuraEnabled public Boolean            noRegistrationRequired;
        @AuraEnabled public String             parentRequestId;
        @AuraEnabled public String             parentRequestName;
        @AuraEnabled public BasketInfo              basket;
        @AuraEnabled public List<DocumentInfo>      documents;
        @AuraEnabled public List<ChildRequest>      childRequests;
        @AuraEnabled public List<DocumentByProduct> documentsByProduct;
    }

    public class BasketInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String status;
        @AuraEnabled public String raRemarks;
        @AuraEnabled public String distributorRemarks;
        @AuraEnabled public String submissionDate;
        @AuraEnabled public String dueDate;
    }

    public class DocumentInfo {
        @AuraEnabled public String  contentDocumentId;
        @AuraEnabled public String  title;
        @AuraEnabled public String  fileType;
        @AuraEnabled public Long    contentSize;
        @AuraEnabled public String  createdDate;
        @AuraEnabled public String  createdByName;
        @AuraEnabled public Boolean isCertificate;
        @AuraEnabled public String  downloadUrl;
        @AuraEnabled public String  fileSizeLabel;
    }

    public class ChildRequest {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String documentTypes;
        @AuraEnabled public String submittedDate;
        @AuraEnabled public String rejectionComments;
    }

    public class DocTypeEntry {
        @AuraEnabled public String docType;
        @AuraEnabled public String uploadedDocumentId;
        @AuraEnabled public String uploadedDocumentName;
        @AuraEnabled public String downloadUrl;
    }

    public class DocumentByProduct {
        @AuraEnabled public String             productName;
        @AuraEnabled public List<DocTypeEntry> docTypes;
    }

    // ── Main method ───────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static RequestDetail getRequestDetail(Id recordId) {
        if (recordId == null) throw new AuraHandledException('Record ID is required.');

        Id userId    = UserInfo.getUserId();
        Id accountId = new ElevatedQuery().getAccountId(userId);
        if (accountId == null) throw new AuraHandledException('No account linked to your user profile.');

        Registration_Request__c rr = new ElevatedQuery().getRequest(recordId, accountId);
        if (rr == null) throw new AuraHandledException('Request not found or access denied.');

        RequestDetail d = new RequestDetail();
        d.id                  = rr.Id;
        d.name                = rr.Name;
        d.status              = rr.Status__c;
        d.currentStage        = rr.Current_Stage__c;
        d.productName         = rr.Product__r?.Name;
        d.country             = rr.Country__c;

        List<String> pNames = new List<String>();
        for (Registration_Request_Product__c rrp : new ElevatedQuery().fetchProducts(recordId)) {
            if (rrp.Product__r != null) pNames.add(rrp.Product__r.Name);
        }
        d.allProductNames = !pNames.isEmpty() ? String.join(pNames, ', ') : d.productName;
        d.region              = rr.Region__c;
        d.documentTypes       = rr.Document_Types__c;
        d.remarks             = rr.Remarks__c;
        d.rejectionComments   = rr.Rejection_Comments__c;
        d.requestType         = rr.Request_Type__c;
        d.certificateUploaded      = rr.Certificate_Uploaded__c;
        d.noRegistrationRequired   = rr.Account__r?.No_Registration_Required__c == true;
        d.submittedDate            = rr.Submitted_Date__c != null
                                ? String.valueOf(rr.Submitted_Date__c.date()) : null;
        d.validFrom           = rr.Certificate_Valid_From__c != null
                                ? String.valueOf(rr.Certificate_Valid_From__c) : null;
        d.validTo             = rr.Certificate_Valid_To__c != null
                                ? String.valueOf(rr.Certificate_Valid_To__c) : null;
        d.parentRequestId     = rr.Parent_Request__c;
        d.parentRequestName   = rr.Parent_Request__r?.Name;

        // Document basket
        d.documents = new List<DocumentInfo>();
        if (!rr.Document_Baskets__r.isEmpty()) {
            Document_Basket__c b = rr.Document_Baskets__r[0];
            d.basket                    = new BasketInfo();
            d.basket.id                 = b.Id;
            d.basket.status             = b.Status__c;
            d.basket.raRemarks          = b.RA_Remarks__c;
            d.basket.distributorRemarks = b.Distributor_Remarks__c;
            d.basket.submissionDate     = b.Submission_Date__c != null
                                          ? String.valueOf(b.Submission_Date__c.date()) : null;
            d.basket.dueDate            = b.Due_Date__c != null
                                          ? String.valueOf(b.Due_Date__c) : null;

            for (ContentDocumentLink cdl : new ElevatedQuery().getDocumentLinks(b.Id, recordId)) {
                ContentVersion cv = cdl.ContentDocument?.LatestPublishedVersion;
                if (cv == null) continue;
                DocumentInfo di        = new DocumentInfo();
                di.contentDocumentId   = cdl.ContentDocumentId;
                di.title               = cv.Title;
                di.fileType            = cv.FileType;
                di.contentSize         = cv.ContentSize;
                di.createdDate         = cv.CreatedDate != null
                                         ? String.valueOf(cv.CreatedDate.date()) : null;
                di.createdByName       = cv.CreatedBy?.Name;
                di.isCertificate       = cv.Title != null
                                         && (cv.Title.containsIgnoreCase('Certificate')
                                             || cv.Title.containsIgnoreCase('Cert'));
                di.downloadUrl         = '/sfc/servlet.shepherd/document/download/' + di.contentDocumentId;
                di.fileSizeLabel       = formatSize(cv.ContentSize);
                d.documents.add(di);
            }
        }

        // Child requests
        d.childRequests = new List<ChildRequest>();
        for (Registration_Request__c child : new ElevatedQuery().getChildRequests(recordId)) {
            ChildRequest cr  = new ChildRequest();
            cr.id               = child.Id;
            cr.name             = child.Name;
            cr.status           = child.Status__c;
            cr.documentTypes    = child.Document_Types__c;
            cr.rejectionComments = child.Rejection_Comments__c;
            cr.submittedDate    = child.Submitted_Date__c != null
                                  ? String.valueOf(child.Submitted_Date__c.date()) : null;
            d.childRequests.add(cr);
        }

        // Documents grouped by product — with upload status
        List<Request_Document__c> rdList = new ElevatedQuery().fetchDocuments(recordId);

        Set<Id> uploadedDocIds = new Set<Id>();
        for (Request_Document__c rd : rdList) {
            if (String.isNotBlank(rd.Uploaded_Document_Id__c)) {
                try { uploadedDocIds.add(Id.valueOf(rd.Uploaded_Document_Id__c)); } catch (Exception e) {}
            }
        }
        Map<Id, String> docTitleMap = new Map<Id, String>();
        if (!uploadedDocIds.isEmpty()) {
            for (ContentVersion cv : [
                SELECT ContentDocumentId, Title
                FROM   ContentVersion
                WHERE  ContentDocumentId IN :uploadedDocIds
                AND    IsLatest = true
            ]) {
                docTitleMap.put(cv.ContentDocumentId, cv.Title);
            }
        }

        Map<String, List<DocTypeEntry>> byProduct = new Map<String, List<DocTypeEntry>>();
        for (Request_Document__c rd : rdList) {
            String pName = rd.Registration_Request_Product__r?.Product__r?.Name != null
                           ? rd.Registration_Request_Product__r.Product__r.Name : '—';
            if (!byProduct.containsKey(pName)) byProduct.put(pName, new List<DocTypeEntry>());
            DocTypeEntry entry = new DocTypeEntry();
            entry.docType = rd.Document_Type__c;
            if (String.isNotBlank(rd.Uploaded_Document_Id__c)) {
                entry.uploadedDocumentId = rd.Uploaded_Document_Id__c;
                entry.downloadUrl = '/sfc/servlet.shepherd/document/download/' + rd.Uploaded_Document_Id__c;
                try {
                    Id cdId = Id.valueOf(rd.Uploaded_Document_Id__c);
                    entry.uploadedDocumentName = docTitleMap.containsKey(cdId) ? docTitleMap.get(cdId) : rd.Uploaded_Document_Id__c;
                } catch (Exception e) {
                    entry.uploadedDocumentName = rd.Uploaded_Document_Id__c;
                }
            }
            byProduct.get(pName).add(entry);
        }
        d.documentsByProduct = new List<DocumentByProduct>();
        for (String pName : byProduct.keySet()) {
            DocumentByProduct dbp = new DocumentByProduct();
            dbp.productName = pName;
            dbp.docTypes    = byProduct.get(pName);
            d.documentsByProduct.add(dbp);
        }

        return d;
    }

    // ── Re-submit: form data ──────────────────────────────────────────────────

    public class ProductInfo {
        @AuraEnabled public String       value;
        @AuraEnabled public String       label;
        @AuraEnabled public List<String> docTypes; // currently assigned doc types for this product
    }

    public class ResubmitFormData {
        @AuraEnabled public String             accountId;
        @AuraEnabled public String             agreementSignedWith;
        @AuraEnabled public Integer            durationMonths;
        @AuraEnabled public String             vertical;
        @AuraEnabled public List<ProductInfo>  existingProducts;
        @AuraEnabled public List<String>       existingDocTypes;
    }

    @AuraEnabled(cacheable=false)
    public static ResubmitFormData getResubmitData(Id recordId) {
        Id userId    = UserInfo.getUserId();
        Id accountId = new ElevatedQuery().getAccountId(userId);
        if (accountId == null) throw new AuraHandledException('No account linked to your user profile.');

        List<Registration_Request__c> rows = [
            SELECT Id, Status__c, Document_Types__c
            FROM   Registration_Request__c
            WHERE  Id = :recordId AND Account__c = :accountId
            LIMIT  1
        ];
        if (rows.isEmpty()) throw new AuraHandledException('Request not found or access denied.');

        Registration_Request__c rr = rows[0];

        ResubmitFormData fd = new ResubmitFormData();
        fd.accountId = accountId;

        Master_Agreement__c ma = new ElevatedQuery().getActiveAgreementForAccount(accountId);
        if (ma != null) {
            fd.agreementSignedWith = ma.Agreement_Signed_With_picklist__c;
            fd.durationMonths      = ma.Agreement_Duration_In_Months__c != null
                                     ? ma.Agreement_Duration_In_Months__c.intValue() : null;
            fd.vertical            = ma.Vertical__c;
        }

        // Per-product doc types from Request_Document__c
        Map<Id, List<String>> prodDocMap = new Map<Id, List<String>>();
        Set<String> allDocTypesSet = new Set<String>();
        for (Request_Document__c rd : [
            SELECT Registration_Request_Product__r.Product__c, Document_Type__c
            FROM   Request_Document__c
            WHERE  Registration_Request_Product__r.Registration_Request__c = :recordId
            AND    Document_Type__c != null
        ]) {
            Id pid = rd.Registration_Request_Product__r?.Product__c;
            if (pid == null) continue;
            if (!prodDocMap.containsKey(pid)) prodDocMap.put(pid, new List<String>());
            prodDocMap.get(pid).add(rd.Document_Type__c);
            allDocTypesSet.add(rd.Document_Type__c);
        }

        fd.existingProducts = new List<ProductInfo>();
        for (Registration_Request_Product__c rrp : new ElevatedQuery().fetchProductsWithId(recordId)) {
            if (rrp.Product__r != null) {
                ProductInfo pi = new ProductInfo();
                pi.value    = rrp.Product__c;
                pi.label    = rrp.Product__r.Name;
                pi.docTypes = prodDocMap.containsKey(rrp.Product__c)
                              ? prodDocMap.get(rrp.Product__c)
                              : new List<String>();
                fd.existingProducts.add(pi);
            }
        }

        fd.existingDocTypes = new List<String>(allDocTypesSet);

        return fd;
    }

    // ── Re-submit: write ──────────────────────────────────────────────────────

    // existingProdAddedDocsJson: [{ productId, addDocTypes: [] }]
    // newProdEntriesJson:        [{ productId, docTypes: [] }]
    @AuraEnabled
    public static void resubmitWithUpdates(
        Id     recordId,
        String validFromDate,
        String validToDate,
        String existingProdAddedDocsJson,
        String newProdEntriesJson,
        String resubmitNote
    ) {
        Id userId    = UserInfo.getUserId();
        Id accountId = new ElevatedQuery().getAccountId(userId);
        if (accountId == null) throw new AuraHandledException('No account linked to your user profile.');
        new ElevatedWriter().doResubmitWithUpdates(
            recordId, accountId, validFromDate, validToDate,
            existingProdAddedDocsJson, newProdEntriesJson, resubmitNote
        );
    }

    @AuraEnabled
    public static void resubmitAdditionalRequest(Id childRequestId) {
        try {
            new ElevatedWriter().doResubmitChild(childRequestId);
            RegistrationNotificationService.notifyFromApex(childRequestId, 'ADDITIONAL_DOCS_REQUESTED_BY_DISTRIBUTOR');
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Resubmit directly to Regulatory (RA sent-back flow, status change only) ─
    @AuraEnabled
    public static void resubmitToRegulatory(Id requestId) {
        try {
            new ElevatedWriter().doResubmitToRegulatory(requestId);
            RegistrationNotificationService.notifyFromApex(requestId, 'SUBMITTED_TO_REGULATORY');
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Resubmit to Regulatory with product/document updates (RA sent-back) ───
    @AuraEnabled
    public static void resubmitToRegulatoryWithUpdates(
        Id     requestId,
        String existingProdAddedDocsJson,
        String newProdEntriesJson,
        String resubmitNote
    ) {
        try {
            Id userId    = UserInfo.getUserId();
            Id accountId = new ElevatedQuery().getAccountId(userId);
            if (accountId == null) throw new AuraHandledException('No account linked to your user profile.');
            String requestType = new ElevatedWriter().doResubmitToRegulatoryWithUpdates(
                requestId, accountId,
                existingProdAddedDocsJson, newProdEntriesJson, resubmitNote
            );
            RegistrationNotificationService.notifyFromApex(
                requestId,
                requestType == 'Additional Document Request'
                    ? 'ADDITIONAL_DOCS_REQUESTED_BY_DISTRIBUTOR'
                    : 'SUBMITTED_TO_REGULATORY'
            );
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private without sharing class ElevatedWriter {
        public void doResubmitToRegulatory(Id requestId) {
            update new Registration_Request__c(
                Id                    = requestId,
                Status__c             = 'Submitted to Regulatory',
                Rejection_Comments__c = null
            );
        }

        // Returns Request_Type__c so the caller can pick the notification type
        public String doResubmitToRegulatoryWithUpdates(
            Id recordId, Id accountId,
            String existingProdAddedDocsJson, String newProdEntriesJson, String note
        ) {
            List<Registration_Request__c> rows = [
                SELECT Id, Status__c, Remarks__c, Document_Types__c, Request_Type__c
                FROM   Registration_Request__c
                WHERE  Id = :recordId AND Account__c = :accountId
                LIMIT  1
            ];
            if (rows.isEmpty()) throw new AuraHandledException('Request not found.');
            Registration_Request__c rr = rows[0];
            if (rr.Status__c != 'Sent Back') throw new AuraHandledException('Only Sent Back requests can be re-submitted.');

            Map<Id, List<String>> existingProdAddedMap = new Map<Id, List<String>>();
            if (String.isNotBlank(existingProdAddedDocsJson) && existingProdAddedDocsJson != '[]') {
                try {
                    for (Object item : (List<Object>)JSON.deserializeUntyped(existingProdAddedDocsJson)) {
                        Map<String, Object> m = (Map<String, Object>)item;
                        Id pid = Id.valueOf(String.valueOf(m.get('productId')));
                        List<Object> dts = (List<Object>)m.get('addDocTypes');
                        List<String> dtList = new List<String>();
                        if (dts != null) for (Object dt : dts) if (String.isNotBlank(String.valueOf(dt))) dtList.add(String.valueOf(dt).trim());
                        if (!dtList.isEmpty()) existingProdAddedMap.put(pid, dtList);
                    }
                } catch (Exception e) {}
            }

            List<Map<String, Object>> newProdEntries = new List<Map<String, Object>>();
            if (String.isNotBlank(newProdEntriesJson) && newProdEntriesJson != '[]') {
                try {
                    for (Object item : (List<Object>)JSON.deserializeUntyped(newProdEntriesJson)) {
                        newProdEntries.add((Map<String, Object>)item);
                    }
                } catch (Exception e) {}
            }

            Map<Id, Id> productToRRP = new Map<Id, Id>();
            for (Registration_Request_Product__c rrp : [
                SELECT Id, Product__c FROM Registration_Request_Product__c
                WHERE  Registration_Request__c = :recordId
            ]) {
                productToRRP.put(rrp.Product__c, rrp.Id);
            }

            Set<String> existingDocKeys = new Set<String>();
            Set<String> allDocTypes     = new Set<String>();
            for (Request_Document__c rd : [
                SELECT Registration_Request_Product__c, Document_Type__c
                FROM   Request_Document__c
                WHERE  Registration_Request_Product__r.Registration_Request__c = :recordId
                AND    Document_Type__c != null
            ]) {
                existingDocKeys.add(rd.Registration_Request_Product__c + '_' + rd.Document_Type__c);
                allDocTypes.add(rd.Document_Type__c);
            }

            List<Request_Document__c> newRDs = new List<Request_Document__c>();

            for (Id pid : existingProdAddedMap.keySet()) {
                Id rrpId = productToRRP.get(pid);
                if (rrpId == null) continue;
                for (String dt : existingProdAddedMap.get(pid)) {
                    String key = rrpId + '_' + dt;
                    if (!existingDocKeys.contains(key)) {
                        newRDs.add(new Request_Document__c(
                            Registration_Request_Product__c = rrpId,
                            Document_Type__c                = dt
                        ));
                        existingDocKeys.add(key);
                        allDocTypes.add(dt);
                    }
                }
            }

            if (!newProdEntries.isEmpty()) {
                List<Registration_Request_Product__c> newRRPs = new List<Registration_Request_Product__c>();
                for (Map<String, Object> entry : newProdEntries) {
                    Id pid = Id.valueOf(String.valueOf(entry.get('productId')));
                    if (!productToRRP.containsKey(pid)) {
                        newRRPs.add(new Registration_Request_Product__c(
                            Registration_Request__c = recordId,
                            Product__c              = pid
                        ));
                    }
                }
                if (!newRRPs.isEmpty()) insert newRRPs;

                for (Registration_Request_Product__c rrp : [
                    SELECT Id, Product__c FROM Registration_Request_Product__c
                    WHERE  Registration_Request__c = :recordId
                ]) {
                    productToRRP.put(rrp.Product__c, rrp.Id);
                }

                for (Map<String, Object> entry : newProdEntries) {
                    Id pid   = Id.valueOf(String.valueOf(entry.get('productId')));
                    Id rrpId = productToRRP.get(pid);
                    if (rrpId == null) continue;
                    List<Object> dts = (List<Object>)entry.get('docTypes');
                    if (dts == null) continue;
                    for (Object dtObj : dts) {
                        String dt  = String.valueOf(dtObj).trim();
                        String key = rrpId + '_' + dt;
                        if (String.isNotBlank(dt) && !existingDocKeys.contains(key)) {
                            newRDs.add(new Request_Document__c(
                                Registration_Request_Product__c = rrpId,
                                Document_Type__c                = dt
                            ));
                            existingDocKeys.add(key);
                            allDocTypes.add(dt);
                        }
                    }
                }
            }

            if (!newRDs.isEmpty()) insert newRDs;

            rr.Status__c             = 'Submitted to Regulatory';
            rr.Rejection_Comments__c = null;
            rr.Document_Types__c     = String.join(new List<String>(allDocTypes), ';');
            if (String.isNotBlank(note)) {
                rr.Remarks__c = (String.isNotBlank(rr.Remarks__c)
                    ? rr.Remarks__c + '\n\nRe-submission note: '
                    : 'Re-submission note: ') + note;
            }
            update rr;
            return rr.Request_Type__c;
        }

        public void doResubmitChild(Id childRequestId) {
            update new Registration_Request__c(
                Id                    = childRequestId,
                Status__c             = 'Submitted to Regulatory',
                Rejection_Comments__c = null
            );
        }

        public void doResubmitWithUpdates(
            Id recordId, Id accountId,
            String validFromStr, String validToStr,
            String existingProdAddedDocsJson, String newProdEntriesJson, String note
        ) {
            List<Registration_Request__c> rows = [
                SELECT Id, Status__c, Remarks__c
                FROM   Registration_Request__c
                WHERE  Id = :recordId AND Account__c = :accountId
                LIMIT  1
            ];
            if (rows.isEmpty()) throw new AuraHandledException('Request not found.');
            Registration_Request__c rr = rows[0];
            if (rr.Status__c != 'Sent Back') throw new AuraHandledException('Only Sent Back requests can be re-submitted.');

            // Parse: existing product additional doc types
            // [{ productId: string, addDocTypes: string[] }]
            Map<Id, List<String>> existingProdAddedMap = new Map<Id, List<String>>();
            if (String.isNotBlank(existingProdAddedDocsJson) && existingProdAddedDocsJson != '[]') {
                try {
                    for (Object item : (List<Object>)JSON.deserializeUntyped(existingProdAddedDocsJson)) {
                        Map<String, Object> m = (Map<String, Object>)item;
                        Id pid = Id.valueOf(String.valueOf(m.get('productId')));
                        List<Object> dts = (List<Object>)m.get('addDocTypes');
                        List<String> dtList = new List<String>();
                        if (dts != null) for (Object dt : dts) if (String.isNotBlank(String.valueOf(dt))) dtList.add(String.valueOf(dt).trim());
                        if (!dtList.isEmpty()) existingProdAddedMap.put(pid, dtList);
                    }
                } catch (Exception e) {}
            }

            // Parse: new product entries
            // [{ productId: string, docTypes: string[] }]
            List<Map<String, Object>> newProdEntries = new List<Map<String, Object>>();
            if (String.isNotBlank(newProdEntriesJson) && newProdEntriesJson != '[]') {
                try {
                    for (Object item : (List<Object>)JSON.deserializeUntyped(newProdEntriesJson)) {
                        newProdEntries.add((Map<String, Object>)item);
                    }
                } catch (Exception e) {}
            }

            // Get existing RRP map: productId → rrpId
            Map<Id, Id> productToRRP = new Map<Id, Id>();
            for (Registration_Request_Product__c rrp : [
                SELECT Id, Product__c FROM Registration_Request_Product__c
                WHERE  Registration_Request__c = :recordId
            ]) {
                productToRRP.put(rrp.Product__c, rrp.Id);
            }

            // Get existing Request_Document__c keys and current doc types
            Set<String> existingDocKeys = new Set<String>(); // "rrpId_docType"
            Set<String> allDocTypes     = new Set<String>();
            for (Request_Document__c rd : [
                SELECT Registration_Request_Product__c, Document_Type__c
                FROM   Request_Document__c
                WHERE  Registration_Request_Product__r.Registration_Request__c = :recordId
                AND    Document_Type__c != null
            ]) {
                existingDocKeys.add(rd.Registration_Request_Product__c + '_' + rd.Document_Type__c);
                allDocTypes.add(rd.Document_Type__c);
            }

            // New Request_Document__c records to insert
            List<Request_Document__c> newRDs = new List<Request_Document__c>();

            // A: existing products — add specified additional doc types
            for (Id pid : existingProdAddedMap.keySet()) {
                Id rrpId = productToRRP.get(pid);
                if (rrpId == null) continue;
                for (String dt : existingProdAddedMap.get(pid)) {
                    String key = rrpId + '_' + dt;
                    if (!existingDocKeys.contains(key)) {
                        newRDs.add(new Request_Document__c(
                            Registration_Request_Product__c = rrpId,
                            Document_Type__c                = dt
                        ));
                        existingDocKeys.add(key);
                        allDocTypes.add(dt);
                    }
                }
            }

            // B: new products — insert RRP then create their documents
            if (!newProdEntries.isEmpty()) {
                List<Registration_Request_Product__c> newRRPs = new List<Registration_Request_Product__c>();
                for (Map<String, Object> entry : newProdEntries) {
                    Id pid = Id.valueOf(String.valueOf(entry.get('productId')));
                    if (!productToRRP.containsKey(pid)) {
                        newRRPs.add(new Registration_Request_Product__c(
                            Registration_Request__c = recordId,
                            Product__c              = pid
                        ));
                    }
                }
                if (!newRRPs.isEmpty()) insert newRRPs;

                // Re-query to capture new RRP IDs
                for (Registration_Request_Product__c rrp : [
                    SELECT Id, Product__c FROM Registration_Request_Product__c
                    WHERE  Registration_Request__c = :recordId
                ]) {
                    productToRRP.put(rrp.Product__c, rrp.Id);
                }

                for (Map<String, Object> entry : newProdEntries) {
                    Id pid   = Id.valueOf(String.valueOf(entry.get('productId')));
                    Id rrpId = productToRRP.get(pid);
                    if (rrpId == null) continue;
                    List<Object> dts = (List<Object>)entry.get('docTypes');
                    if (dts == null) continue;
                    for (Object dtObj : dts) {
                        String dt  = String.valueOf(dtObj).trim();
                        String key = rrpId + '_' + dt;
                        if (String.isNotBlank(dt) && !existingDocKeys.contains(key)) {
                            newRDs.add(new Request_Document__c(
                                Registration_Request_Product__c = rrpId,
                                Document_Type__c                = dt
                            ));
                            existingDocKeys.add(key);
                            allDocTypes.add(dt);
                        }
                    }
                }
            }

            if (!newRDs.isEmpty()) insert newRDs;

            // Update main record
            rr.Status__c             = 'Under Functional Head Review';
            rr.Rejection_Comments__c = null;
            rr.Document_Types__c     = String.join(new List<String>(allDocTypes), ';');
            if (String.isNotBlank(validFromStr)) rr.Certificate_Valid_From__c = Date.valueOf(validFromStr);
            if (String.isNotBlank(validToStr))   rr.Certificate_Valid_To__c   = Date.valueOf(validToStr);
            if (String.isNotBlank(note)) {
                rr.Remarks__c = (String.isNotBlank(rr.Remarks__c)
                    ? rr.Remarks__c + '\n\nRe-submission note: '
                    : 'Re-submission note: ') + note;
            }
            update rr;
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static String formatSize(Long size) {
        if (size == null || size == 0) return '';
        if (size < 1024)               return size + ' B';
        if (size < 1048576)            return (size / 1024) + ' KB';
        return Decimal.valueOf(size).divide(1048576, 1) + ' MB';
    }

    // ── Without-sharing inner class for portal data access ────────────────────

    private without sharing class ElevatedQuery {

        public Id getAccountId(Id userId) {
            List<User> u = [SELECT AccountId FROM User WHERE Id = :userId LIMIT 1];
            return u.isEmpty() ? null : u[0].AccountId;
        }

        public Registration_Request__c getRequest(Id requestId, Id accountId) {
            List<Registration_Request__c> rows = [
                SELECT Id, Name, Status__c, Current_Stage__c,
                       Country__c, Region__c, Document_Types__c,
                       Remarks__c, Rejection_Comments__c, Request_Type__c,
                       Submitted_Date__c, Certificate_Uploaded__c,
                       Certificate_Valid_From__c, Certificate_Valid_To__c,
                       Product__c, Product__r.Name,
                       Parent_Request__c, Parent_Request__r.Name,
                       Account__c, Account__r.No_Registration_Required__c,
                       (SELECT Id, Status__c, RA_Remarks__c, Distributor_Remarks__c,
                               Submission_Date__c, Due_Date__c
                        FROM   Document_Baskets__r
                        ORDER BY CreatedDate DESC LIMIT 1)
                FROM   Registration_Request__c
                WHERE  Id         = :requestId
                AND    Account__c = :accountId
                LIMIT  1
            ];
            return rows.isEmpty() ? null : rows[0];
        }

        public List<Registration_Request_Product__c> fetchProducts(Id requestId) {
            return [
                SELECT Product__r.Name
                FROM   Registration_Request_Product__c
                WHERE  Registration_Request__c = :requestId
                ORDER BY CreatedDate ASC
            ];
        }

        public List<Registration_Request_Product__c> fetchProductsWithId(Id requestId) {
            return [
                SELECT Product__c, Product__r.Name
                FROM   Registration_Request_Product__c
                WHERE  Registration_Request__c = :requestId
                ORDER BY CreatedDate ASC
            ];
        }

        public Master_Agreement__c getActiveAgreementForAccount(Id accountId) {
            List<Master_Agreement__c> mas = [
                SELECT Id, Agreement_Signed_With_picklist__c,
                       Agreement_Duration_In_Months__c, Vertical__c
                FROM   Master_Agreement__c
                WHERE  Account__c   = :accountId
                AND    Is_Active__c = true
                ORDER BY CreatedDate DESC
                LIMIT  1
            ];
            return mas.isEmpty() ? null : mas[0];
        }

        public List<ContentDocumentLink> getDocumentLinks(Id basketId, Id requestId) {
            Set<Id> linkedIds = new Set<Id>();
            if (basketId  != null) linkedIds.add(basketId);
            if (requestId != null) linkedIds.add(requestId);
            // Dedup by ContentDocumentId — a file may be linked to both basket and request
            Map<Id, ContentDocumentLink> byDoc = new Map<Id, ContentDocumentLink>();
            for (ContentDocumentLink cdl : [
                SELECT ContentDocumentId,
                       ContentDocument.LatestPublishedVersion.Title,
                       ContentDocument.LatestPublishedVersion.FileType,
                       ContentDocument.LatestPublishedVersion.ContentSize,
                       ContentDocument.LatestPublishedVersion.CreatedDate,
                       ContentDocument.LatestPublishedVersion.CreatedBy.Name
                FROM   ContentDocumentLink
                WHERE  LinkedEntityId IN :linkedIds
                ORDER BY ContentDocument.CreatedDate DESC
            ]) {
                if (!byDoc.containsKey(cdl.ContentDocumentId)) {
                    byDoc.put(cdl.ContentDocumentId, cdl);
                }
            }
            return byDoc.values();
        }

        public List<Registration_Request__c> getChildRequests(Id parentId) {
            return [
                SELECT Id, Name, Status__c, Document_Types__c, Submitted_Date__c, Rejection_Comments__c
                FROM   Registration_Request__c
                WHERE  Parent_Request__c = :parentId
                ORDER BY CreatedDate DESC
            ];
        }

        public List<Request_Document__c> fetchDocuments(Id requestId) {
            return [
                SELECT Document_Type__c, Uploaded_Document_Id__c,
                       Registration_Request_Product__r.Product__r.Name
                FROM   Request_Document__c
                WHERE  Registration_Request_Product__r.Registration_Request__c = :requestId
                ORDER BY Registration_Request_Product__r.Product__r.Name, Document_Type__c
            ];
        }
    }
}
public with sharing class RegulatoryRequestDetailController {

    public class RequestDetail {
        @AuraEnabled public String            id;
        @AuraEnabled public String            name;
        @AuraEnabled public String            status;
        @AuraEnabled public String            currentStage;
        @AuraEnabled public String            distributorName;
        @AuraEnabled public String            crmName;
        @AuraEnabled public String            rsmName;
        @AuraEnabled public String            crmEmail;
        @AuraEnabled public String            rsmEmail;
        @AuraEnabled public String            productName;
        @AuraEnabled public String            allProductNames;
        @AuraEnabled public String            country;
        @AuraEnabled public String            region;
        @AuraEnabled public String            documentTypes;
        @AuraEnabled public String            remarks;
        @AuraEnabled public String            rejectionComments;
        @AuraEnabled public String            requestType;
        @AuraEnabled public String            submittedDate;
        @AuraEnabled public Integer           daysPending;
        @AuraEnabled public Boolean           certificateUploaded;
        @AuraEnabled public String            parentRequestId;
        @AuraEnabled public String            parentRequestName;
        @AuraEnabled public Integer           forecastWeek;
        @AuraEnabled public Integer           forecastYear;
        @AuraEnabled public Integer           actualCompletionWeek;
        @AuraEnabled public Integer           actualCompletionYear;
        @AuraEnabled public BasketInfo              basket;
        @AuraEnabled public List<DocumentInfo>      documents;
        @AuraEnabled public List<ChildRequest>      childRequests;
        @AuraEnabled public List<DocumentByProduct> documentsByProduct;
        @AuraEnabled public List<ProductInfo>       productDetails;
    }

    public class BasketInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String raRemarks;
        @AuraEnabled public String distributorRemarks;
        @AuraEnabled public String submissionDate;
        @AuraEnabled public String dueDate;
        @AuraEnabled public String approvedDate;
    }

    public class DocumentInfo {
        @AuraEnabled public String  contentDocumentId;
        @AuraEnabled public String  contentVersionId;
        @AuraEnabled public String  title;
        @AuraEnabled public String  fileType;
        @AuraEnabled public Long    contentSize;
        @AuraEnabled public String  createdDate;
        @AuraEnabled public String  createdByName;
        @AuraEnabled public Boolean isCertificate;
        @AuraEnabled public String  requestStatus;
        @AuraEnabled public String  requestStage;
    }

    public class ChildRequest {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String productName;
        @AuraEnabled public String requestType;
        @AuraEnabled public String documentTypes;
        @AuraEnabled public String submittedDate;
    }

    public class DocTypeEntry {
        @AuraEnabled public String docType;
        @AuraEnabled public String uploadedDocumentId;
        @AuraEnabled public String uploadedDocumentName;
    }

    public class DocumentByProduct {
        @AuraEnabled public String           productName;
        @AuraEnabled public List<DocTypeEntry> docTypes;
    }

    public class ProductInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String productName;
        @AuraEnabled public String dummyCode;
        @AuraEnabled public String dummyDescription;
        @AuraEnabled public String fgCode;
    }

    @AuraEnabled(cacheable=true)
    public static RequestDetail getRequestDetail(Id recordId) {
        ElevatedQuery eq = new ElevatedQuery();
        Registration_Request__c rr = eq.getRequest(recordId);

        RequestDetail d = new RequestDetail();
        d.id                  = rr.Id;
        d.name                = rr.Name;
        d.status              = rr.Status__c;
        d.currentStage        = rr.Current_Stage__c;
        d.distributorName     = rr.Account__r?.Name;
        d.crmName             = rr.Account__r?.CRM__r?.Name;
        d.crmEmail            = rr.Account__r?.CRM_Email__c;
        d.rsmName             = rr.Account__r?.RSM__r?.Name;
        d.rsmEmail            = rr.Account__r?.RSM_Email__c;
        d.productName         = rr.Product__r?.Name;
        d.country             = rr.Country__c;

        List<String> pNames = new List<String>();
        d.productDetails = new List<ProductInfo>();
        for (Registration_Request_Product__c rrp : eq.fetchProducts(recordId)) {
            if (rrp.Product__r != null) {
                pNames.add(rrp.Product__r.Name);
                ProductInfo pi      = new ProductInfo();
                pi.id               = rrp.Id;
                pi.productName      = rrp.Product__r.Name;
                pi.dummyCode        = rrp.Product__r.Dummy_Product_Code__c;
                pi.dummyDescription = rrp.Product__r.Dummy_Product_Description__c;
                pi.fgCode           = rrp.FG_Code__c;
                d.productDetails.add(pi);
            }
        }
        d.allProductNames = !pNames.isEmpty() ? String.join(pNames, ', ') : d.productName;
        d.region              = rr.Region__c;
        d.documentTypes       = rr.Document_Types__c;
        d.remarks             = rr.Remarks__c;
        d.rejectionComments   = rr.Rejection_Comments__c;
        d.requestType         = rr.Request_Type__c;
        d.certificateUploaded = rr.Certificate_Uploaded__c;
        d.submittedDate       = rr.Submitted_Date__c != null
                                ? String.valueOf(rr.Submitted_Date__c.date()) : null;
        d.daysPending         = rr.Submitted_Date__c != null
                                ? Integer.valueOf(rr.Submitted_Date__c.date().daysBetween(Date.today())) : null;
        d.parentRequestId     = rr.Parent_Request__c;
        d.parentRequestName   = rr.Parent_Request__r?.Name;
        d.forecastWeek        = rr.Forecast_Week__c != null ? Integer.valueOf(rr.Forecast_Week__c) : null;
        d.forecastYear        = rr.Forecast_Year__c != null ? Integer.valueOf(rr.Forecast_Year__c) : null;
        d.actualCompletionWeek = rr.Actual_Completion_Week__c != null ? Integer.valueOf(rr.Actual_Completion_Week__c) : null;
        d.actualCompletionYear = rr.Actual_Completion_Year__c != null ? Integer.valueOf(rr.Actual_Completion_Year__c) : null;

        // Document Basket
        d.documents = new List<DocumentInfo>();
        if (!rr.Document_Baskets__r.isEmpty()) {
            Document_Basket__c b = rr.Document_Baskets__r[0];
            d.basket = new BasketInfo();
            d.basket.id                 = b.Id;
            d.basket.name               = b.Name;
            d.basket.status             = b.Status__c;
            d.basket.raRemarks          = b.RA_Remarks__c;
            d.basket.distributorRemarks = b.Distributor_Remarks__c;
            d.basket.submissionDate     = b.Submission_Date__c != null
                                          ? String.valueOf(b.Submission_Date__c.date()) : null;
            d.basket.dueDate            = b.Due_Date__c != null
                                          ? String.valueOf(b.Due_Date__c) : null;
            d.basket.approvedDate       = b.Approved_Date__c != null
                                          ? String.valueOf(b.Approved_Date__c) : null;

            // Files uploaded to basket — exclude anything uploaded after approval
            Datetime approvalCutoff = b.Approved_Date__c;
            for (ContentDocumentLink cdl : eq.getDocumentLinks(b.Id)) {
                ContentVersion cv = cdl.ContentDocument?.LatestPublishedVersion;
                if (cv == null) continue;
                if (approvalCutoff != null && cv.CreatedDate != null && cv.CreatedDate > approvalCutoff) continue;
                DocumentInfo di = new DocumentInfo();
                di.contentDocumentId = cdl.ContentDocumentId;
                di.contentVersionId  = cv.Id;
                di.title             = cv.Title;
                di.fileType          = cv.FileType;
                di.contentSize       = cv.ContentSize;
                di.createdDate       = cv.CreatedDate != null
                                       ? String.valueOf(cv.CreatedDate.date()) : null;
                di.createdByName     = cv.CreatedBy?.Name;
                di.isCertificate     = cv.Title != null
                                       && (cv.Title.containsIgnoreCase('Certificate')
                                           || cv.Title.containsIgnoreCase('Cert'));
                di.requestStatus     = rr.Status__c;
                di.requestStage      = rr.Current_Stage__c;
                d.documents.add(di);
            }
        }

        // Child requests (queried separately to avoid relationship name dependency)
        d.childRequests = new List<ChildRequest>();
        for (Registration_Request__c child : eq.getChildRequests(recordId)) {
            ChildRequest cr  = new ChildRequest();
            cr.id            = child.Id;
            cr.name          = child.Name;
            cr.status        = child.Status__c;
            cr.productName   = child.Product__r?.Name;
            cr.requestType   = child.Request_Type__c;
            cr.documentTypes = child.Document_Types__c;
            cr.submittedDate = child.Submitted_Date__c != null
                               ? String.valueOf(child.Submitted_Date__c.date()) : null;
            d.childRequests.add(cr);
        }

        List<Request_Document__c> rdList = eq.fetchDocuments(recordId);

        // Collect uploaded content doc IDs so we can look up their titles
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

    // ── Without-sharing for portal-safe data access ────────────────────────────
    private without sharing class ElevatedQuery {

        public Registration_Request__c getRequest(Id requestId) {
            return [
                SELECT Id, Name, Status__c, Current_Stage__c,
                       Country__c, Region__c, Document_Types__c,
                       Remarks__c, Rejection_Comments__c, Request_Type__c,
                       Submitted_Date__c, Certificate_Uploaded__c,
                       Forecast_Week__c, Forecast_Year__c,
                       Actual_Completion_Week__c, Actual_Completion_Year__c,
                       Requested_By__c, Requested_By__r.Name,
                       Account__c, Account__r.Name,
                       Account__r.CRM__r.Name, Account__r.CRM_Email__c,
                       Account__r.RSM__r.Name, Account__r.RSM_Email__c,
                       Product__c, Product__r.Name,
                       Parent_Request__c, Parent_Request__r.Name,
                       (SELECT Id, Name, Status__c, RA_Remarks__c, Distributor_Remarks__c,
                               Submission_Date__c, Due_Date__c, Approved_Date__c
                        FROM   Document_Baskets__r
                        ORDER BY CreatedDate DESC LIMIT 1)
                FROM   Registration_Request__c
                WHERE  Id = :requestId
                LIMIT  1
            ];
        }

        public List<Registration_Request_Product__c> fetchProducts(Id requestId) {
            return [
                SELECT Id, FG_Code__c,
                       Product__r.Name,
                       Product__r.Dummy_Product_Code__c,
                       Product__r.Dummy_Product_Description__c
                FROM   Registration_Request_Product__c
                WHERE  Registration_Request__c = :requestId
                ORDER BY CreatedDate ASC
            ];
        }

        public List<ContentDocumentLink> getDocumentLinks(Id basketId) {
            return [
                SELECT ContentDocumentId,
                       ContentDocument.LatestPublishedVersion.Id,
                       ContentDocument.LatestPublishedVersion.Title,
                       ContentDocument.LatestPublishedVersion.FileType,
                       ContentDocument.LatestPublishedVersion.ContentSize,
                       ContentDocument.LatestPublishedVersion.CreatedDate,
                       ContentDocument.LatestPublishedVersion.CreatedBy.Name
                FROM   ContentDocumentLink
                WHERE  LinkedEntityId = :basketId
                ORDER BY ContentDocument.CreatedDate DESC
            ];
        }

        public List<Request_Document__c> fetchDocuments(Id requestId) {
            return [
                SELECT Id, Document_Type__c, Uploaded_Document_Id__c,
                       Registration_Request_Product__r.Product__r.Name
                FROM   Request_Document__c
                WHERE  Registration_Request_Product__r.Registration_Request__c = :requestId
                ORDER BY Registration_Request_Product__r.Product__r.Name, Document_Type__c
            ];
        }

        public List<Registration_Request__c> getChildRequests(Id parentId) {
            return [
                SELECT Id, Name, Status__c, Product__r.Name, Request_Type__c,
                       Document_Types__c, Submitted_Date__c
                FROM   Registration_Request__c
                WHERE  Parent_Request__c = :parentId
                ORDER BY CreatedDate DESC
            ];
        }
    }

}
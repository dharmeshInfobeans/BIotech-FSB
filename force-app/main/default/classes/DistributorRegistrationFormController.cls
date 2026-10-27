public with sharing class DistributorRegistrationFormController {

    // ── Data classes ──────────────────────────────────────────────────────────

    public class DistributorInfo {
        @AuraEnabled public Id     accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String gstin;
        @AuraEnabled public String country;
        @AuraEnabled public String address;
        @AuraEnabled public String email;
        @AuraEnabled public String region;
        @AuraEnabled public String rsmName;
        @AuraEnabled public String rsmEmail;
        @AuraEnabled public String crmName;
        @AuraEnabled public String crmEmail;
    }

    public class LookupOption {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
        public LookupOption(String v, String l) { value = v; label = l; }
    }

    public class ActiveAgreementResult {
        @AuraEnabled public Id      agreementId;
        @AuraEnabled public String  agreementName;
        @AuraEnabled public String  agreementSignedWith;
        @AuraEnabled public Integer durationMonths;
        @AuraEnabled public String  vertical;
    }

    public class SubmitResult {
        @AuraEnabled public Id     recordId;
        @AuraEnabled public String recordName;
    }

    public class ProductDocStatus {
        @AuraEnabled public Id           productId;
        @AuraEnabled public List<String> uploadedDocTypes;
    }

    public class CompletedRequestInfo {
        @AuraEnabled public Id                   requestId;
        @AuraEnabled public String               requestName;
        @AuraEnabled public String               documentTypes;
        @AuraEnabled public String               submittedDate;
        @AuraEnabled public String               validToDate;
        @AuraEnabled public List<String>         productNames;
        @AuraEnabled public List<Id>             productIds;
        @AuraEnabled public List<ProductDocStatus> alreadyProvidedByProduct;
    }

    // ── Inner class without sharing for Account / CIty__c / User reads ────────
    // Portal users cannot query these objects under with sharing rules.
    private without sharing class ElevatedReader {
        Account getAccount(Id accountId) {
            return [
                SELECT Id, Name, GSTIN_No__c, Country_Key__c,
                       BillingStreet, BillingCity, BillingState, BillingCountry, BillingPostalCode,
                       E_Mail__c, region__c,
                       RSM__c, RSM__r.Name, RSM_Email__c,
                       CRM__c, CRM__r.Name, CRM_Email__c
                FROM   Account
                WHERE  Id = :accountId
                LIMIT  1
            ];
        }
        String getCityName(Id cityId) {
            try { return [SELECT Name FROM CIty__c WHERE Id = :cityId LIMIT 1].Name; }
            catch (Exception e) { return null; }
        }
        Master_Agreement__c getActiveAgreement(Id accountId) {
            List<Master_Agreement__c> mas = [
                SELECT Id, Name,
                       Agreement_Signed_With_picklist__c,
                       Agreement_Duration_In_Months__c,
                       Vertical__c
                FROM   Master_Agreement__c
                WHERE  Account__c = :accountId
                AND    Is_Active__c = true
                ORDER BY CreatedDate DESC
                LIMIT  1
            ];
            return mas.isEmpty() ? null : mas[0];
        }
        List<Registration_Request__c> getCompletedRequestsForAccount(Id accountId) {
            return [
                SELECT Id, Name, Document_Types__c, Submitted_Date__c, Certificate_Valid_To__c, Parent_Request__c
                FROM   Registration_Request__c
                WHERE  Account__c = :accountId
                AND    Status__c  = 'Completed'
                ORDER BY Submitted_Date__c DESC
            ];
        }
        Map<Id, List<String>> getProductNamesForRequests(Set<Id> requestIds) {
            Map<Id, List<String>> result = new Map<Id, List<String>>();
            for (Registration_Request_Product__c rrp : [
                SELECT Registration_Request__c, Product__c, Product__r.Name
                FROM   Registration_Request_Product__c
                WHERE  Registration_Request__c IN :requestIds
                ORDER BY Product__r.Name
            ]) {
                if (!result.containsKey(rrp.Registration_Request__c)) {
                    result.put(rrp.Registration_Request__c, new List<String>());
                }
                if (rrp.Product__r != null && String.isNotBlank(rrp.Product__r.Name)) {
                    result.get(rrp.Registration_Request__c).add(rrp.Product__r.Name);
                }
            }
            return result;
        }

        Map<Id, Map<Id, List<String>>> getUploadedDocsByProduct(Set<Id> requestIds) {
            Map<Id, Map<Id, List<String>>> result = new Map<Id, Map<Id, List<String>>>();
            for (Request_Document__c rd : [
                SELECT Document_Type__c, Uploaded_Document_Id__c,
                       Registration_Request_Product__r.Registration_Request__c,
                       Registration_Request_Product__r.Product__c
                FROM   Request_Document__c
                WHERE  Registration_Request_Product__r.Registration_Request__c IN :requestIds
                AND    Uploaded_Document_Id__c != null
            ]) {
                Id reqId  = rd.Registration_Request_Product__r?.Registration_Request__c;
                Id prodId = rd.Registration_Request_Product__r?.Product__c;
                if (reqId == null || prodId == null) continue;
                if (!result.containsKey(reqId)) result.put(reqId, new Map<Id, List<String>>());
                if (!result.get(reqId).containsKey(prodId)) result.get(reqId).put(prodId, new List<String>());
                result.get(reqId).get(prodId).add(rd.Document_Type__c);
            }
            return result;
        }

        Map<Id, List<Id>> getProductIdsForRequests(Set<Id> requestIds) {
            Map<Id, List<Id>> result = new Map<Id, List<Id>>();
            for (Registration_Request_Product__c rrp : [
                SELECT Registration_Request__c, Product__c
                FROM   Registration_Request_Product__c
                WHERE  Registration_Request__c IN :requestIds
                ORDER BY Product__r.Name
            ]) {
                if (!result.containsKey(rrp.Registration_Request__c)) {
                    result.put(rrp.Registration_Request__c, new List<Id>());
                }
                if (rrp.Product__c != null) {
                    result.get(rrp.Registration_Request__c).add(rrp.Product__c);
                }
            }
            return result;
        }
        Registration_Request__c getParentRequest(Id requestId) {
            return [
                SELECT Id, Account__c, Product__c, Country__c
                FROM   Registration_Request__c
                WHERE  Id = :requestId LIMIT 1
            ];
        }
        void insertRequest(Registration_Request__c rec) { insert rec; }
        List<Product__c> getAgreementProducts(Id accountId, String vertical) {
            Set<Id> productIds = new Set<Id>();
            for (Agreement_Product__c ap : [
                SELECT Product__c
                FROM   Agreement_Product__c
                WHERE  Master_Agreement__r.Account__c   = :accountId
                AND    Master_Agreement__r.Is_Active__c = true
                AND    Product__r.Vertical__c           = :vertical
                AND    Is_Canceled__c                  != true
            ]) {
                productIds.add(ap.Product__c);
            }
            if (productIds.isEmpty()) return new List<Product__c>();
            return [SELECT Id, Name FROM Product__c WHERE Id IN :productIds ORDER BY Name];
        }
        void insertRequests(List<Registration_Request__c> records) {
            insert records;
        }
        void insertRequestProducts(Id requestId, List<Id> productIds) {
            List<Registration_Request_Product__c> rrps = new List<Registration_Request_Product__c>();
            for (Id pid : productIds) {
                rrps.add(new Registration_Request_Product__c(
                    Registration_Request__c = requestId,
                    Product__c              = pid
                ));
            }
            insert rrps;
        }
        Map<Id, Id> getRrpMap(Id requestId) {
            Map<Id, Id> productToRrp = new Map<Id, Id>();
            for (Registration_Request_Product__c rrp : [
                SELECT Id, Product__c
                FROM   Registration_Request_Product__c
                WHERE  Registration_Request__c = :requestId
            ]) {
                productToRrp.put(rrp.Product__c, rrp.Id);
            }
            return productToRrp;
        }
        void insertRequestDocuments(Map<Id, Id> productToRrp, List<DocMapping> mappings) {
            List<Request_Document__c> docs = new List<Request_Document__c>();
            for (DocMapping dm : mappings) {
                for (Id pid : dm.productIds) {
                    Id rrpId = productToRrp.get(pid);
                    if (rrpId == null) continue;
                    docs.add(new Request_Document__c(
                        Registration_Request_Product__c = rrpId,
                        Document_Type__c                = dm.docType
                    ));
                }
            }
            if (!docs.isEmpty()) insert docs;
        }
    }

    // ── Inner class for JSON deserialization ──────────────────────────────────
    public class DocMapping {
        public String   docType;
        public List<Id> productIds;
    }

    // ── @AuraEnabled methods ──────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static DistributorInfo getDistributorInfo() {
        User u = [SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        DistributorInfo info = new DistributorInfo();
        info.accountId = u.AccountId;
        if (u.AccountId == null) return info;

        ElevatedReader reader = new ElevatedReader();
        Account acc = reader.getAccount(u.AccountId);
        info.accountName = acc.Name;
        info.gstin       = acc.GSTIN_No__c;
        info.country     = acc.Country_Key__c;
        info.email       = acc.E_Mail__c;

        List<String> parts = new List<String>();
        if (String.isNotBlank(acc.BillingStreet))     parts.add(acc.BillingStreet);
        if (String.isNotBlank(acc.BillingCity))       parts.add(acc.BillingCity);
        if (String.isNotBlank(acc.BillingState))      parts.add(acc.BillingState);
        if (String.isNotBlank(acc.BillingPostalCode)) parts.add(acc.BillingPostalCode);
        if (String.isNotBlank(acc.BillingCountry))    parts.add(acc.BillingCountry);
        info.address = parts.isEmpty() ? null : String.join(parts, ', ');

        if (acc.region__c != null) info.region = reader.getCityName(acc.region__c);
        info.rsmName  = acc.RSM__r  != null ? acc.RSM__r.Name  : 'Pankhil';
        info.rsmEmail = acc.RSM_Email__c;
        info.crmName  = acc.CRM__r  != null ? acc.CRM__r.Name  : 'Pankhil';
        info.crmEmail = acc.CRM_Email__c;
        return info;
    }

    @AuraEnabled(cacheable=true)
    public static List<LookupOption> getAgreementSignedWithOptions() {
        List<LookupOption> opts = new List<LookupOption>();
        for (Schema.PicklistEntry e :
            Schema.Master_Agreement__c.Agreement_Signed_With_picklist__c
                .getDescribe().getPicklistValues()) {
            if (e.isActive()) opts.add(new LookupOption(e.getValue(), e.getLabel()));
        }
        return opts;
    }

    @AuraEnabled(cacheable=true)
    public static List<LookupOption> getVerticalOptions() {
        List<LookupOption> opts = new List<LookupOption>();
        for (Schema.PicklistEntry e :
            Schema.Product__c.Vertical__c
                .getDescribe().getPicklistValues()) {
            if (e.isActive()) opts.add(new LookupOption(e.getValue(), e.getLabel()));
        }
        return opts;
    }

    @AuraEnabled(cacheable=true)
    public static List<LookupOption> getProductsByVertical(String vertical, Id accountId) {
        if (String.isBlank(vertical) || accountId == null) return new List<LookupOption>();
        List<LookupOption> opts = new List<LookupOption>();
        for (Product__c p : new ElevatedReader().getAgreementProducts(accountId, vertical)) {
            opts.add(new LookupOption(p.Id, p.Name));
        }
        return opts;
    }

    @AuraEnabled
    public static ActiveAgreementResult getActiveAgreement(Id accountId) {
        if (accountId == null) return null;
        Master_Agreement__c ma = new ElevatedReader().getActiveAgreement(accountId);
        if (ma == null) return null;
        ActiveAgreementResult r  = new ActiveAgreementResult();
        r.agreementId            = ma.Id;
        r.agreementName          = ma.Name;
        r.agreementSignedWith    = ma.Agreement_Signed_With_picklist__c;
        r.durationMonths         = ma.Agreement_Duration_In_Months__c != null
                                    ? ma.Agreement_Duration_In_Months__c.intValue() : null;
        r.vertical               = ma.Vertical__c;
        return r;
    }

    @AuraEnabled(cacheable=true)
    public static List<CompletedRequestInfo> getCompletedRequests(Id accountId) {
        if (accountId == null) return new List<CompletedRequestInfo>();
        ElevatedReader reader = new ElevatedReader();
        List<Registration_Request__c> requests = reader.getCompletedRequestsForAccount(accountId);

        Set<Id> requestIds = new Set<Id>();
        for (Registration_Request__c rr : requests) requestIds.add(rr.Id);

        // Also include parent request IDs so we can merge their uploaded docs
        Set<Id> allDocQueryIds = new Set<Id>(requestIds);
        for (Registration_Request__c rr : requests) {
            if (rr.Parent_Request__c != null) allDocQueryIds.add(rr.Parent_Request__c);
        }

        Map<Id, List<String>>           productNameMap    = reader.getProductNamesForRequests(requestIds);
        Map<Id, List<Id>>               productIdMap      = reader.getProductIdsForRequests(requestIds);
        Map<Id, Map<Id, List<String>>>  uploadedDocsMap   = reader.getUploadedDocsByProduct(allDocQueryIds);

        List<CompletedRequestInfo> result = new List<CompletedRequestInfo>();
        for (Registration_Request__c rr : requests) {
            CompletedRequestInfo info = new CompletedRequestInfo();
            info.requestId     = rr.Id;
            info.requestName   = rr.Name;
            info.documentTypes = rr.Document_Types__c;
            info.submittedDate = rr.Submitted_Date__c != null
                ? String.valueOf(rr.Submitted_Date__c) : null;
            info.validToDate   = rr.Certificate_Valid_To__c != null
                ? String.valueOf(rr.Certificate_Valid_To__c) : null;
            info.productNames  = productNameMap.containsKey(rr.Id)
                ? productNameMap.get(rr.Id) : new List<String>();
            info.productIds    = productIdMap.containsKey(rr.Id)
                ? productIdMap.get(rr.Id) : new List<Id>();

            // Merge uploaded docs from this request + its parent (if any)
            Map<Id, Set<String>> mergedByProd = new Map<Id, Set<String>>();
            for (Id srcId : new List<Id>{ rr.Id, rr.Parent_Request__c }) {
                if (srcId == null || !uploadedDocsMap.containsKey(srcId)) continue;
                for (Id pid : uploadedDocsMap.get(srcId).keySet()) {
                    if (!mergedByProd.containsKey(pid)) mergedByProd.put(pid, new Set<String>());
                    mergedByProd.get(pid).addAll(uploadedDocsMap.get(srcId).get(pid));
                }
            }
            info.alreadyProvidedByProduct = new List<ProductDocStatus>();
            for (Id pid : mergedByProd.keySet()) {
                ProductDocStatus pds = new ProductDocStatus();
                pds.productId        = pid;
                pds.uploadedDocTypes = new List<String>(mergedByProd.get(pid));
                info.alreadyProvidedByProduct.add(pds);
            }
            result.add(info);
        }
        return result;
    }

    @AuraEnabled
    public static SubmitResult submitAdditionalCertRequest(
        Id     parentRequestId,
        String documentTypes,
        String remarks,
        String docProductMappings
    ) {
        try {
            if (parentRequestId == null) {
                throw new AuraHandledException('Please select a completed request.');
            }
            if (String.isBlank(documentTypes)) {
                throw new AuraHandledException('Please select at least one document type.');
            }

            // Deserialize per-product mappings
            List<DocMapping> mappings = String.isNotBlank(docProductMappings)
                ? (List<DocMapping>) JSON.deserialize(docProductMappings, List<DocMapping>.class)
                : new List<DocMapping>();

            // Collect unique product IDs from the mappings
            Set<Id> productIdSet = new Set<Id>();
            for (DocMapping dm : mappings) {
                if (dm.productIds != null) productIdSet.addAll(dm.productIds);
            }

            ElevatedReader reader = new ElevatedReader();
            Registration_Request__c parent = reader.getParentRequest(parentRequestId);
            Registration_Request__c rr = new Registration_Request__c(
                Account__c        = parent.Account__c,
                Product__c        = parent.Product__c,
                Country__c        = parent.Country__c,
                Status__c         = 'Submitted to Regulatory',
                Current_Stage__c  = 'Regulatory Processing',
                Request_Type__c   = 'Additional Document Request',
                Document_Types__c = documentTypes,
                Submitted_Date__c = Date.today(),
                Requested_By__c   = UserInfo.getUserId(),
                Parent_Request__c = parentRequestId,
                Year__c           = String.valueOf(Date.today().year()),
                Remarks__c        = String.isNotBlank(remarks) ? remarks : null
            );
            reader.insertRequest(rr);

            // Insert product links and doc-product records
            if (!productIdSet.isEmpty()) {
                reader.insertRequestProducts(rr.Id, new List<Id>(productIdSet));
                Map<Id, Id> productToRrp = reader.getRrpMap(rr.Id);
                reader.insertRequestDocuments(productToRrp, mappings);
            }

            RegistrationNotificationService.notifyFromApex(rr.Id, 'ADDITIONAL_DOCS_REQUESTED_BY_DISTRIBUTOR');
            Registration_Request__c created = [SELECT Id, Name FROM Registration_Request__c WHERE Id = :rr.Id LIMIT 1];
            SubmitResult res = new SubmitResult();
            res.recordId   = created.Id;
            res.recordName = created.Name;
            return res;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static SubmitResult submitRequest(
        Id       accountId,
        String   formType,
        String   country,
        String   vertical,
        String   agreementSignedWith,
        Integer  durationMonths,
        String   validFromDate,
        String   validToDate,
        List<Id> productIds,
        String   documentTypes,
        String   remarks,
        String   docProductMappings
    ) {
        try {
            if (productIds == null || productIds.isEmpty()) {
                throw new AuraHandledException('Please select at least one product.');
            }

            Registration_Request__c rr = new Registration_Request__c(
                Account__c                 = accountId,
                Product__c                 = productIds[0],
                Country__c                 = country,
                Request_Type__c            = 'New Registration',
                Remarks__c                 = String.isNotBlank(remarks) ? remarks : null,
                Document_Types__c          = String.isNotBlank(documentTypes) ? documentTypes : null,
                Year__c                    = String.valueOf(Date.today().year()),
                Status__c                  = 'Under Functional Head Review',
                Current_Stage__c           = 'Functional Head Review',
                Submitted_Date__c          = Date.today(),
                Requested_By__c            = UserInfo.getUserId(),
                Certificate_Valid_From__c  = String.isNotBlank(validFromDate) ? Date.valueOf(validFromDate) : null,
                Certificate_Valid_To__c    = String.isNotBlank(validToDate)   ? Date.valueOf(validToDate)   : null
            );

            ElevatedReader elev = new ElevatedReader();
            elev.insertRequests(new List<Registration_Request__c>{ rr });
            elev.insertRequestProducts(rr.Id, productIds);

            if (String.isNotBlank(docProductMappings)) {
                List<DocMapping> mappings = (List<DocMapping>)
                    JSON.deserialize(docProductMappings, List<DocMapping>.class);
                Map<Id, Id> productToRrp = elev.getRrpMap(rr.Id);
                elev.insertRequestDocuments(productToRrp, mappings);
            }

            RegistrationNotificationService.notifyFromApex(rr.Id, 'FUNCTIONAL_HEAD_REVIEW');

            Registration_Request__c created = [SELECT Id, Name FROM Registration_Request__c WHERE Id = :rr.Id LIMIT 1];
            SubmitResult res = new SubmitResult();
            res.recordId   = created.Id;
            res.recordName = created.Name;
            return res;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
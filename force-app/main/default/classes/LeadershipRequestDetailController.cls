public with sharing class LeadershipRequestDetailController {

    public class RequestDetail {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String currentStage;
        @AuraEnabled public String requestType;
        @AuraEnabled public String country;
        @AuraEnabled public String region;
        @AuraEnabled public String remarks;
        @AuraEnabled public String rejectionComments;
        @AuraEnabled public String documentTypes;
        @AuraEnabled public String submittedDate;
        @AuraEnabled public String distributorName;
        @AuraEnabled public String crmName;
        @AuraEnabled public String rsmName;
        @AuraEnabled public String crmEmail;
        @AuraEnabled public String rsmEmail;
        @AuraEnabled public String productName;
        @AuraEnabled public String allProductNames;
        @AuraEnabled public String parentRequestId;
        @AuraEnabled public String parentRequestName;
        @AuraEnabled public Integer forecastWeek;
        @AuraEnabled public Integer forecastYear;
        @AuraEnabled public Integer actualCompletionWeek;
        @AuraEnabled public Integer actualCompletionYear;
        @AuraEnabled public List<ChildRequestInfo>   childRequests;
        @AuraEnabled public List<AuditEntry>         auditHistory;
        @AuraEnabled public List<DocumentByProduct>  documentsByProduct;
    }

    public class ChildRequestInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String requestType;
        @AuraEnabled public String submittedDate;
        @AuraEnabled public String productName;
    }

    public class AuditEntry {
        @AuraEnabled public String subject;
        @AuraEnabled public String description;
        @AuraEnabled public String activityDate;
        @AuraEnabled public String createdByName;
    }

    public class DocumentByProduct {
        @AuraEnabled public String       productName;
        @AuraEnabled public List<String> docTypes;
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

        Registration_Request__c rr = eq.fetchRequest(recordId);

        RequestDetail d         = new RequestDetail();
        d.id                    = rr.Id;
        d.name                  = rr.Name;
        d.status                = rr.Status__c;
        d.currentStage          = rr.Current_Stage__c;
        d.requestType           = rr.Request_Type__c;
        d.country               = rr.Country__c;
        d.region                = rr.Region__c;
        d.remarks               = rr.Remarks__c;
        d.rejectionComments     = rr.Rejection_Comments__c;
        d.documentTypes         = rr.Document_Types__c;
        d.submittedDate         = rr.Submitted_Date__c != null
                                  ? String.valueOf(rr.Submitted_Date__c.date()) : null;
        d.distributorName       = rr.Account__r?.Name;
        d.crmName               = rr.Account__r?.CRM__r?.Name;
        d.crmEmail              = rr.Account__r?.CRM_Email__c;
        d.rsmName               = rr.Account__r?.RSM__r?.Name;
        d.rsmEmail              = rr.Account__r?.RSM_Email__c;
        d.productName           = rr.Product__r?.Name;
        d.parentRequestId       = rr.Parent_Request__c;
        d.forecastWeek          = rr.Forecast_Week__c != null ? Integer.valueOf(rr.Forecast_Week__c) : null;
        d.forecastYear          = rr.Forecast_Year__c != null ? Integer.valueOf(rr.Forecast_Year__c) : null;
        d.actualCompletionWeek  = rr.Actual_Completion_Week__c != null ? Integer.valueOf(rr.Actual_Completion_Week__c) : null;
        d.actualCompletionYear  = rr.Actual_Completion_Year__c != null ? Integer.valueOf(rr.Actual_Completion_Year__c) : null;

        List<String> pNames = new List<String>();
        for (Registration_Request_Product__c rrp : eq.fetchProducts(recordId)) {
            if (rrp.Product__r != null) pNames.add(rrp.Product__r.Name);
        }
        d.allProductNames = !pNames.isEmpty() ? String.join(pNames, ', ') : d.productName;
        d.parentRequestName     = rr.Parent_Request__r?.Name;

        d.childRequests = new List<ChildRequestInfo>();
        for (Registration_Request__c child : eq.fetchChildren(recordId)) {
            ChildRequestInfo cr = new ChildRequestInfo();
            cr.id            = child.Id;
            cr.name          = child.Name;
            cr.status        = child.Status__c;
            cr.requestType   = child.Request_Type__c;
            cr.submittedDate = child.Submitted_Date__c != null
                               ? String.valueOf(child.Submitted_Date__c.date()) : null;
            cr.productName   = child.Product__r?.Name;
            d.childRequests.add(cr);
        }

        d.auditHistory = new List<AuditEntry>();
        for (Task t : eq.fetchAuditTasks(recordId)) {
            AuditEntry ae    = new AuditEntry();
            ae.subject       = t.Subject;
            ae.description   = t.Description;
            ae.activityDate  = t.ActivityDate != null ? String.valueOf(t.ActivityDate) : null;
            ae.createdByName = t.CreatedBy?.Name;
            d.auditHistory.add(ae);
        }

        Map<String, List<String>> byProduct = new Map<String, List<String>>();
        for (Request_Document__c rd : eq.fetchDocuments(recordId)) {
            String pName = rd.Registration_Request_Product__r?.Product__r?.Name != null
                           ? rd.Registration_Request_Product__r.Product__r.Name : '—';
            if (!byProduct.containsKey(pName)) byProduct.put(pName, new List<String>());
            byProduct.get(pName).add(rd.Document_Type__c);
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

    @AuraEnabled
    public static List<ProductInfo> getProductsWithDetails(Id requestId) {
        ElevatedQuery eq = new ElevatedQuery();
        List<ProductInfo> result = new List<ProductInfo>();
        for (Registration_Request_Product__c rrp : eq.fetchProductsWithDetails(requestId)) {
            ProductInfo p      = new ProductInfo();
            p.id               = rrp.Id;
            p.productName      = rrp.Product__r?.Name;
            p.dummyCode        = rrp.Product__r?.Dummy_Product_Code__c;
            p.dummyDescription = rrp.Product__r?.Dummy_Product_Description__c;
            p.fgCode           = rrp.FG_Code__c;
            result.add(p);
        }
        return result;
    }

    @AuraEnabled
    public static void saveFGCodes(String rrpDataJson) {
        List<Object> items = (List<Object>) JSON.deserializeUntyped(rrpDataJson);
        List<Registration_Request_Product__c> toUpdate = new List<Registration_Request_Product__c>();
        for (Object item : items) {
            Map<String,Object> m = (Map<String,Object>) item;
            toUpdate.add(new Registration_Request_Product__c(
                Id         = (String) m.get('id'),
                FG_Code__c = (String) m.get('fgCode')
            ));
        }
        if (!toUpdate.isEmpty()) new ElevatedDML().doUpdate(toUpdate);
    }

    @AuraEnabled
    public static Boolean checkFGCodesComplete(Id requestId) {
        return new ElevatedQuery().isFGCodesComplete(requestId);
    }

    // Elevated query — Registration_Request__c OWD is Private
    private without sharing class ElevatedQuery {

        public Registration_Request__c fetchRequest(Id recordId) {
            return [
                SELECT Id, Name, Status__c, Current_Stage__c, Request_Type__c,
                       Country__c, Region__c, Remarks__c, Rejection_Comments__c,
                       Document_Types__c, Submitted_Date__c,
                       Forecast_Week__c, Forecast_Year__c,
                       Actual_Completion_Week__c, Actual_Completion_Year__c,
                       Account__c, Account__r.Name,
                       Account__r.CRM__r.Name, Account__r.CRM_Email__c,
                       Account__r.RSM__r.Name, Account__r.RSM_Email__c,
                       Product__c, Product__r.Name,
                       Parent_Request__c, Parent_Request__r.Name
                FROM   Registration_Request__c
                WHERE  Id = :recordId
                LIMIT  1
            ];
        }

        public List<Registration_Request__c> fetchChildren(Id parentId) {
            return [
                SELECT Id, Name, Status__c, Request_Type__c,
                       Submitted_Date__c, Product__r.Name
                FROM   Registration_Request__c
                WHERE  Parent_Request__c = :parentId
                ORDER BY Submitted_Date__c ASC NULLS LAST
                LIMIT  50
            ];
        }

        public List<Registration_Request_Product__c> fetchProducts(Id requestId) {
            return [
                SELECT Product__r.Name
                FROM   Registration_Request_Product__c
                WHERE  Registration_Request__c = :requestId
                ORDER BY CreatedDate ASC
            ];
        }

        public List<Request_Document__c> fetchDocuments(Id requestId) {
            return [
                SELECT Document_Type__c,
                       Registration_Request_Product__r.Product__r.Name
                FROM   Request_Document__c
                WHERE  Registration_Request_Product__r.Registration_Request__c = :requestId
                ORDER BY Registration_Request_Product__r.Product__r.Name, Document_Type__c
            ];
        }

        public List<Task> fetchAuditTasks(Id recordId) {
            return [
                SELECT Subject, Description, ActivityDate, CreatedBy.Name
                FROM   Task
                WHERE  WhatId = :recordId
                AND    Subject LIKE '[Reg%]'
                ORDER BY ActivityDate DESC, CreatedDate DESC
                LIMIT  30
            ];
        }

        public List<Registration_Request_Product__c> fetchProductsWithDetails(Id requestId) {
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

        public Boolean isFGCodesComplete(Id requestId) {
            Integer missing = [
                SELECT COUNT() FROM Registration_Request_Product__c
                WHERE  Registration_Request__c = :requestId
                AND    (FG_Code__c = null OR FG_Code__c = '')
            ];
            return missing == 0;
        }
    }

    private without sharing class ElevatedDML {
        public void doUpdate(List<SObject> records) {
            update records;
        }
    }
}
public with sharing class RegulatoryQueueController {

    public class RequestWrapper {
        @AuraEnabled public String  recId;
        @AuraEnabled public String  name;
        @AuraEnabled public String  distributorName;
        @AuraEnabled public String  country;
        @AuraEnabled public String  productName;
        @AuraEnabled public String  status;
        @AuraEnabled public String  currentStage;
        @AuraEnabled public String  documentTypes;
        @AuraEnabled public String  submittedDate;
        @AuraEnabled public Integer daysPending;
        @AuraEnabled public Boolean isOverdue;
        @AuraEnabled public String  priority;
        @AuraEnabled public String  basketStatus;
        @AuraEnabled public Boolean hasBasket;
        @AuraEnabled public Boolean certificateUploaded;
        @AuraEnabled public Integer cycleCount;
    }

    @AuraEnabled(cacheable=true)
    public static List<RequestWrapper> getQueue() {
        List<Registration_Request__c> records = new ElevatedQuery().fetchAll();
        Date today = Date.today();
        Set<String> activeStatuses = new Set<String>{
            'Submitted to Regulatory', 'Under Regulatory Review', 'Additional Documents Requested'
        };
        List<RequestWrapper> result = new List<RequestWrapper>();

        for (Registration_Request__c r : records) {
            RequestWrapper w      = new RequestWrapper();
            w.recId               = r.Id;
            w.name                = r.Name;
            w.distributorName     = r.Account__r != null ? r.Account__r.Name : '';
            w.country             = r.Country__c;
            w.productName         = r.Product__r != null ? r.Product__r.Name : '';
            w.status              = r.Status__c;
            w.currentStage        = r.Current_Stage__c;
            w.documentTypes       = r.Document_Types__c;
            w.certificateUploaded = r.Certificate_Uploaded__c;
            w.cycleCount          = r.Child_Requests__r != null
                                    ? r.Child_Requests__r.size() : 0;
            w.submittedDate       = r.Submitted_Date__c != null
                                    ? String.valueOf(r.Submitted_Date__c.date()) : null;

            if (r.Submitted_Date__c != null) {
                w.daysPending = r.Submitted_Date__c.date().daysBetween(today);
                w.isOverdue   = activeStatuses.contains(r.Status__c) && w.daysPending > 14;
                if (activeStatuses.contains(r.Status__c) && w.daysPending >= 21) {
                    w.priority = 'High';
                } else if (activeStatuses.contains(r.Status__c) && w.daysPending >= 14) {
                    w.priority = 'Medium';
                } else {
                    w.priority = 'Normal';
                }
            } else {
                w.daysPending = 0;
                w.isOverdue   = false;
                w.priority    = 'Normal';
            }

            if (!r.Document_Baskets__r.isEmpty()) {
                w.basketStatus = r.Document_Baskets__r[0].Status__c;
                w.hasBasket    = true;
            } else {
                w.hasBasket    = false;
            }

            result.add(w);
        }
        return result;
    }

    private without sharing class ElevatedQuery {
        public List<Registration_Request__c> fetchAll() {
            return [
                SELECT Id, Name,
                       Account__c, Account__r.Name,
                       Country__c, Product__c, Product__r.Name,
                       Status__c, Current_Stage__c,
                       Document_Types__c, Submitted_Date__c,
                       Certificate_Uploaded__c,
                       (SELECT Id, Status__c
                        FROM   Document_Baskets__r
                        ORDER BY CreatedDate DESC LIMIT 1),
                       (SELECT Id FROM Child_Requests__r)
                FROM   Registration_Request__c
                WHERE  Status__c IN ('Submitted to Regulatory', 'Under Regulatory Review',
                                     'Additional Documents Requested', 'Pending Customer Response',
                                     'Completed')
                ORDER BY Submitted_Date__c ASC NULLS LAST
                LIMIT  500
            ];
        }
    }
}
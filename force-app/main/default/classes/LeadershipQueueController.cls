public with sharing class LeadershipQueueController {

    public class RequestWrapper {
        @AuraEnabled public String  recId;
        @AuraEnabled public String  name;
        @AuraEnabled public String  distributorName;
        @AuraEnabled public String  country;
        @AuraEnabled public String  region;
        @AuraEnabled public String  productName;
        @AuraEnabled public String  status;
        @AuraEnabled public String  currentStage;
        @AuraEnabled public String  requestType;
        @AuraEnabled public String  submittedDate;
        @AuraEnabled public Integer daysPending;
        @AuraEnabled public Boolean isOverdue;
        @AuraEnabled public Boolean isPendingApproval;
        @AuraEnabled public String  priority;
    }

    @AuraEnabled(cacheable=true)
    public static List<RequestWrapper> getRequests() {
        List<Registration_Request__c> records = new ElevatedQuery().fetchAll();
        Date today = Date.today();
        Set<String> activeStatuses = new Set<String>{ 'Submitted', 'Under Leadership Review', 'Under Management Approval' };
        List<RequestWrapper> result = new List<RequestWrapper>();

        for (Registration_Request__c r : records) {
            RequestWrapper w   = new RequestWrapper();
            w.recId            = r.Id;
            w.name             = r.Name;
            w.distributorName  = r.Account__r != null ? r.Account__r.Name : '';
            w.country          = r.Country__c;
            w.region           = r.Region__c;
            w.productName      = r.Product__r != null ? r.Product__r.Name : '';
            w.status           = r.Status__c;
            w.currentStage     = r.Current_Stage__c;
            w.requestType      = r.Request_Type__c;
            w.submittedDate    = r.Submitted_Date__c != null
                                 ? String.valueOf(r.Submitted_Date__c.date()) : null;
            w.isPendingApproval = r.Status__c == 'Under Leadership Review'
                                 || r.Status__c == 'Under Management Approval';

            if (r.Submitted_Date__c != null) {
                w.daysPending = r.Submitted_Date__c.date().daysBetween(today);
                w.isOverdue   = activeStatuses.contains(r.Status__c) && w.daysPending > 7;
                if (activeStatuses.contains(r.Status__c) && w.daysPending >= 14) {
                    w.priority = 'High';
                } else if (activeStatuses.contains(r.Status__c) && w.daysPending >= 7) {
                    w.priority = 'Medium';
                } else {
                    w.priority = 'Normal';
                }
            } else {
                w.daysPending = 0;
                w.isOverdue   = false;
                w.priority    = 'Normal';
            }
            result.add(w);
        }
        return result;
    }

    // Elevated query needed because Registration_Request__c OWD is Private
    private without sharing class ElevatedQuery {
        public List<Registration_Request__c> fetchAll() {
            return [
                SELECT Id, Name,
                       Account__c, Account__r.Name,
                       Country__c, Region__c,
                       Product__c, Product__r.Name,
                       Status__c, Current_Stage__c,
                       Submitted_Date__c, Request_Type__c
                FROM   Registration_Request__c
                WHERE  Status__c NOT IN ('Draft', 'Under Functional Head Review')
                ORDER BY Submitted_Date__c ASC NULLS LAST
                LIMIT  1000
            ];
        }
    }
}
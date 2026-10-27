public without sharing class DistributorMyRequestsController {

    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Registration_Request__c> getMyRequests(String statusFilter) {
        try {
            Id userId = UserInfo.getUserId();

            List<User> users = [
                SELECT AccountId
                FROM User
                WHERE Id = :userId
                LIMIT 1
            ];

            if (users.isEmpty() || users[0].AccountId == null) {
                return new List<Registration_Request__c>();
            }

            Id accountId = users[0].AccountId;

            String query = 'SELECT Id, Name, Product__r.Name, Country__c, Region__c, Status__c, ' +
                           'Current_Stage__c, Submitted_Date__c, CreatedDate, Rejection_Comments__c, Request_Type__c, ' +
                           'Certificate_Valid_From__c, Certificate_Valid_To__c, Certificate_Uploaded__c ' +
                           'FROM Registration_Request__c ' +
                           'WHERE Account__c = :accountId ';

            if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
                query += 'AND Status__c = :statusFilter ';
            }

            query += 'ORDER BY CreatedDate DESC';

            return Database.query(query);
        } catch (Exception e) {
            throw new AuraHandledException('Error loading requests: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getStatusOptions() {
        List<PicklistOption> options = new List<PicklistOption>();
        options.add(new PicklistOption('All', 'All'));

        Schema.DescribeFieldResult fieldResult = Registration_Request__c.Status__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
            }
        }
        return options;
    }
}
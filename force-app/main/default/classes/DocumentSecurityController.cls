public with sharing class DocumentSecurityController {

    // Returns FULL, METADATA_ONLY, or NONE for the current user against a basket.
    // FULL          — RA Team OR distributor who owns the request
    // METADATA_ONLY — Leadership, CRM, RSM (see filename + size, no download/preview)
    // NONE          — fallback
    @AuraEnabled(cacheable=true)
    public static String getUserDocumentAccess(Id basketId) {
        try {
            Id userId = UserInfo.getUserId();
            ElevatedQuery eq = new ElevatedQuery();
            User u = eq.getUser(userId);

            if (u.RA_Team__c) return 'FULL';

            List<Document_Basket__c> baskets = eq.getBasket(basketId);
            if (baskets.isEmpty()) return 'NONE';

            Registration_Request__c rr = baskets[0].Registration_Request__r;

            // Distributor who owns the request
            if (u.AccountId != null && u.AccountId == rr.Account__c) return 'FULL';

            // Leadership, CRM, or RSM
            if (u.Leadership_Team__c
                || rr.Account__r?.CRM__c == userId
                || rr.Account__r?.RSM__c == userId) {
                return 'METADATA_ONLY';
            }

            return 'NONE';
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'DocumentSecurityController.getUserDocumentAccess error: ' + e.getMessage());
            return 'NONE';
        }
    }

    private without sharing class ElevatedQuery {
        public User getUser(Id userId) {
            return [
                SELECT Id, AccountId, RA_Team__c, Leadership_Team__c
                FROM   User
                WHERE  Id = :userId
                LIMIT  1
            ];
        }

        public List<Document_Basket__c> getBasket(Id basketId) {
            return [
                SELECT Id,
                       Registration_Request__r.Account__c,
                       Registration_Request__r.Account__r.CRM__c,
                       Registration_Request__r.Account__r.RSM__c
                FROM   Document_Basket__c
                WHERE  Id = :basketId
                LIMIT  1
            ];
        }
    }
}
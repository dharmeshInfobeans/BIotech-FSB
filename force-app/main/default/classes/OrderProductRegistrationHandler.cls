public without sharing class OrderProductRegistrationHandler {

    @TestVisible private static Boolean enforceForTest = false;

    public static void validateRegistration(List<Order_Product__c> newProducts) {
        // Only enforce for portal (community) users — internal users bypass
        if (!enforceForTest) {
            User currentUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
            if (currentUser.ContactId == null) {
                return;
            }
        }

        // Collect Order Ids
        Set<Id> orderIds = new Set<Id>();
        for (Order_Product__c op : newProducts) {
            if (op.Order__c != null) {
                orderIds.add(op.Order__c);
            }
        }
        if (orderIds.isEmpty()) {
            return;
        }

        // Map Order Id → Account Id
        Map<Id, Id> orderToAccount = new Map<Id, Id>();
        for (Order__c o : [SELECT Id, Account__c FROM Order__c WHERE Id IN :orderIds]) {
            if (o.Account__c != null) {
                orderToAccount.put(o.Id, o.Account__c);
            }
        }

        Set<Id> accountIds = new Set<Id>(orderToAccount.values());
        if (accountIds.isEmpty()) {
            return;
        }

        // Accounts with No_Registration__c = true get a full bypass
        Set<Id> bypassAccounts = new Set<Id>();
        for (Registration_Request__c rr : [
            SELECT Account__c
            FROM Registration_Request__c
            WHERE Account__c IN :accountIds
            AND No_Registration__c = true
            AND Status__c = 'Completed'
            AND Parent_Request__c = null
        ]) {
            bypassAccounts.add(rr.Account__c);
        }

        // Collect Product Ids being ordered
        Set<Id> productIds = new Set<Id>();
        for (Order_Product__c op : newProducts) {
            if (op.Product__c != null) {
                productIds.add(op.Product__c);
            }
        }

        // Build set of valid accountId_productId keys
        Date today = Date.today();
        Set<String> validKeys = new Set<String>();
        for (Registration_Request_Product__c rrp : [
            SELECT Product__c, Registration_Request__r.Account__c
            FROM Registration_Request_Product__c
            WHERE Registration_Request__r.Account__c IN :accountIds
            AND Product__c IN :productIds
            AND Order_Unlocked__c = true
            AND Registration_Request__r.Status__c = 'Completed'
            AND Registration_Request__r.Parent_Request__c = null
            AND (Certificate_Valid_From__c = null OR Certificate_Valid_From__c <= :today)
            AND (Certificate_Valid_To__c = null OR Certificate_Valid_To__c >= :today)
        ]) {
            validKeys.add(rrp.Registration_Request__r.Account__c + '_' + rrp.Product__c);
        }

        // Validate each Order_Product__c being inserted/updated
        for (Order_Product__c op : newProducts) {
            if (op.Product__c == null || op.Order__c == null) {
                continue;
            }

            Id accountId = orderToAccount.get(op.Order__c);
            if (accountId == null) {
                continue;
            }

            if (bypassAccounts.contains(accountId)) {
                continue;
            }

            String key = accountId + '_' + op.Product__c;
            if (!validKeys.contains(key)) {
                op.addError(
                    'You are not authorized to order this product. ' +
                    'The registration is either not approved or the validity period has expired.'
                );
            }
        }
    }
}
/**
 * Batch Class: MarketXrayBatch
 * Purpose: Send notification to users whose Market X-Ray Form has no updates in last 2 days
 * Schedule: Daily at 12:00 AM (midnight)
 * 
 * Logic:
 * 1. Find all forms where IsMarketXrayFormEditable__c = false (draft forms)
 * 2. Check if related Market_X_Ray__c or Customs_Clearance_Charges__c updated in last 2 days
 * 3. If NO updates in 2 days, send notification to form owner
 */
global class MarketXrayBatch implements Database.Batchable<SObject>, Database.Stateful {

    global Map<String, String> userToFormName = new Map<String, String>();

    global Database.QueryLocator start(Database.BatchableContext bc) {

        Date dateOf = Date.today().addDays(-2);

        return Database.getQueryLocator([
            SELECT Id,
                   (SELECT Id, Name, OwnerId
                    FROM Market_X_Ray_Forms__r
                    WHERE IsMarketXrayFormEditable__c = false
                      AND LastModifiedDate < :dateOf
                    ORDER BY CreatedDate DESC
                    LIMIT 1)
            FROM Account
            WHERE Id IN (
                SELECT Account__c
                FROM Market_X_Ray_Form__c
                WHERE IsMarketXrayFormEditable__c = false
                  AND LastModifiedDate < :dateOf
            )
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Account> accList) {

        for (Account acc : accList) {
            if (acc.Market_X_Ray_Forms__r != null &&
                !acc.Market_X_Ray_Forms__r.isEmpty()) {

                Market_X_Ray_Form__c formRec = acc.Market_X_Ray_Forms__r[0];

                if (formRec.OwnerId != null) {
                    userToFormName.put(
                        String.valueOf(formRec.OwnerId),
                        formRec.Name
                    );
                }
            }
        }
    }

    global void finish(Database.BatchableContext bc) {

        if (userToFormName.isEmpty()) return;

        CustomNotificationType cnType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Market_Xrays_Form_Notification' LIMIT 1];

        Map<String, Object> pageRef = new Map<String, Object>{'type' => 'comm__namedPage','attributes' => new Map<String, Object>{ 'name' => 'market-x-ray' }};

        for (String userId : userToFormName.keySet()) {

            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('Form Still in Draft');
            notification.setBody('Your Market X-Ray Form "' + userToFormName.get(userId) +'" has not been updated in the last 2 days. Please review and submit.');
            notification.setNotificationTypeId(cnType.Id);
            notification.setTargetPageRef(JSON.serialize(pageRef));

            notification.send(new Set<String>{ userId });
        }
    }
}






/*global class MarketXrayBatch implements Database.Batchable<SObject>, Database.Stateful {

    global Set<String> recipientIds = new Set<String>();

    global Database.QueryLocator start(Database.BatchableContext bc) {

        Date dateOf = Date.today().addDays(-2);

        return Database.getQueryLocator([
            SELECT Id,
                   (SELECT Id, Name, OwnerId
                    FROM Market_X_Ray_Forms__r
                    WHERE IsMarketXrayFormEditable__c = false
                      AND Test_Market_X_Ray_Batch__c < :dateOf
                    ORDER BY CreatedDate DESC
                    LIMIT 1)
            FROM Account
            WHERE Id IN (
                SELECT Account__c
                FROM Market_X_Ray_Form__c
                WHERE IsMarketXrayFormEditable__c = false
                  AND Test_Market_X_Ray_Batch__c < :dateOf
            )
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Account> accList) {

        for (Account acc : accList) {
            if (acc.Market_X_Ray_Forms__r != null &&
                !acc.Market_X_Ray_Forms__r.isEmpty()) {

                Market_X_Ray_Form__c formRec = acc.Market_X_Ray_Forms__r[0];

                if (formRec.OwnerId != null) {
                    recipientIds.add(String.valueOf(formRec.OwnerId));
                }
            }
        }
    }

    global void finish(Database.BatchableContext bc) {

        if (recipientIds.isEmpty()) return;

        CustomNotificationType cnType = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Market_Xrays_Form_Notification'
            LIMIT 1
        ];

        Map<String, Object> pageRef = new Map<String, Object>{
            'type' => 'comm__namedPage',
            'attributes' => new Map<String, Object>{ 'name' => 'market-x-ray' }
        };

        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setTitle('Form Still in Draft');
        notification.setBody('Your Market X-Ray form has not been updated in the last 2 days. Please review and submit.');
        notification.setNotificationTypeId(cnType.Id);
        notification.setTargetPageRef(JSON.serialize(pageRef));

        // ✅ SAME METHOD — NO ERROR
        notification.send(recipientIds);
    }
}*/







/*global class MarketXrayBatch implements Database.batchable<sObject>,Database.Stateful {
    global Set<String> recipientIds;
    global Database.QueryLocator start(Database.batchableContext bc){
        //return Database.getQueryLocator('SELECT Id,CreatedDate,Market_X_Ray_Form__r.Owner.Email FROM Market_X_ray__c WHERE CreatedDate = N_DAYS_AGO:6 AND CreatedDate AND CheckMarketXrayEditOrNot__c=false');
		 return Database.getQueryLocator('SELECT Id FROM Market_X_Ray_Form__c WHERE Id IN (SELECT Market_X_Ray_Form__c FROM Market_X_Ray__c WHERE LastModifiedDate = N_DAYS_AGO:6) AND Id IN ( SELECT Market_X_Ray_Form__c FROM Customs_Clearance_Charges__c WHERE LastModifiedDate = N_DAYS_AGO:6) AND IsMarketXrayFormEditable__c = false');   
    }

    global void execute(Database.batchableContext bc,List<Market_X_Ray_Form__c> formList){
        for(Market_X_Ray_Form__c  formRec : formList){
            if(String.isNotBlank(formRec.Owner.Email)){
                recipientIds.add(formRec.Owner.Email);
            }
        }
        
    }global void finish(Database.batchableContext bc){
        Map<String, Object> pageRef = new Map<String, Object>{'type' => 'comm__namedPage','attributes' => new Map<String, Object>{'name' => 'market-x-ray'}};
        CustomNotificationType cnType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Market_Xrays_Form_Notification']??null;
        Messaging.CustomNotification customNotificationObj = new Messaging.CustomNotification();
        customNotificationObj.setTitle('Form Still in Draft');
        customNotificationObj.setBody('Your form has been in draft for the past 7 days. Kindly review and submit it when you have a moment.');
        customNotificationObj.setNotificationTypeId(cnType.id);
        customNotificationObj.setTargetPageRef(JSON.serialize(pageRef));
        customNotificationObj.send(recipientIds);
    }
    
}*/
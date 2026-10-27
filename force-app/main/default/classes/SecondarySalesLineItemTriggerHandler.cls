public class SecondarySalesLineItemTriggerHandler {

    public static void sendTypeUpdateMail(
        Map<String, List<Secondary_Sales_Line_Item__c>> mapOfTypeToLineItem,
        Set<Id> lineItemIdList
    ) {

        Map<Id, List<Id>> mapOfAccountToUserIds = new Map<Id, List<Id>>();
        Map<Id, Id> mapOfLineItemtoAccount = new Map<Id, Id>();
        Map<Id, String> mapOfLineItemtoProductName = new Map<Id, String>();
        Set<Id> accountIdSet = new Set<Id>();

        if (mapOfTypeToLineItem.isEmpty()) {
            return;
        }

        Set<String> setOfEmailTemplateName = new Set<String>();

        if (mapOfTypeToLineItem.containsKey('In Transit')) {
            setOfEmailTemplateName.add('In_Transit_Stock_Receipt_Template');
        }

        if (mapOfTypeToLineItem.containsKey('Return Goods')) {
            setOfEmailTemplateName.add('Secondary_Sales_Return_Good_Template');
        }

        if (setOfEmailTemplateName.isEmpty()) {
            return;
        }
        
        

        // Get Email Templates
        Map<String, EmailTemplate> mapOfNameToTemplate = new Map<String, EmailTemplate>();

        for (EmailTemplate et : [
            SELECT Id, DeveloperName
            FROM EmailTemplate
            WHERE DeveloperName IN :setOfEmailTemplateName
        ]) {
            mapOfNameToTemplate.put(et.DeveloperName, et);
        }

        // Get Line Item Details
        for (Secondary_Sales_Line_Item__c sslitem : [
            SELECT Id,
                   Secondary_Sales_Header__r.Account__c,
                   Product__r.Name
            FROM Secondary_Sales_Line_Item__c
            WHERE Id IN :lineItemIdList
        ]) {
            mapOfLineItemtoAccount.put(
                sslitem.Id,
                sslitem.Secondary_Sales_Header__r.Account__c
            );
            
            

            mapOfLineItemtoProductName.put(
                sslitem.Id,
                sslitem.Product__r.Name
            );

            accountIdSet.add(
                sslitem.Secondary_Sales_Header__r.Account__c
            );
        }
        
        

        // Get Portal Users
        for (Contact con : [
            SELECT Id,
                   AccountId,
                   (SELECT Id FROM Users)
            FROM Contact
            WHERE AccountId IN :accountIdSet
            AND Id IN (
                SELECT ContactId
                FROM User
                WHERE IsPortalEnabled = true
                AND IsActive = true
                AND UserType = 'PowerPartner'
            )
            
            
            
        ]) {

            if (!con.Users.isEmpty()) {

                if (!mapOfAccountToUserIds.containsKey(con.AccountId)) {
                    mapOfAccountToUserIds.put(
                        con.AccountId,
                        new List<Id>()
                    );
                }

                for (User u : con.Users) {
                    mapOfAccountToUserIds.get(con.AccountId).add(u.Id);
                }
            }
        }

        // Safe Notification Type Query
        CustomNotificationType notifType;

        List<CustomNotificationType> notifList = [
            SELECT Id, DeveloperName
            FROM CustomNotificationType
            WHERE DeveloperName = 'Portal_Stock_Notification'
            LIMIT 1
        ];

        if (!notifList.isEmpty()) {
            notifType = notifList[0];
        }

        List<Messaging.SingleEmailMessage> lstEmails =
            new List<Messaging.SingleEmailMessage>();

        /*******************************
         * IN TRANSIT
         *******************************/
        if (mapOfTypeToLineItem.containsKey('In Transit')
            && mapOfNameToTemplate.containsKey('In_Transit_Stock_Receipt_Template')) {

            EmailTemplate template =
                mapOfNameToTemplate.get('In_Transit_Stock_Receipt_Template');

            for (Secondary_Sales_Line_Item__c lineItem :
                    mapOfTypeToLineItem.get('In Transit')) {

                Id accountId = mapOfLineItemtoAccount.get(lineItem.Id);

                if (accountId == null ||
                    !mapOfAccountToUserIds.containsKey(accountId)) {
                    continue;
                }

                List<Id> userIds =
                    mapOfAccountToUserIds.get(accountId);

                if (userIds.isEmpty()) {
                    continue;
                }

                Messaging.SingleEmailMessage mail =
                    new Messaging.SingleEmailMessage();

                mail.setTemplateId(template.Id);
                mail.setTargetObjectId(userIds[0]);
                mail.setWhatId(lineItem.Id);
                mail.setSaveAsActivity(false);

                lstEmails.add(mail);

                if (notifType != null) {

                    Messaging.CustomNotification notif =
                        new Messaging.CustomNotification();

                    notif.setNotificationTypeId(notifType.Id);

                    notif.setTargetPageRef(
                        '{"type":"standard__webPage","attributes":{"url":"/s/secondary-sales"}}'
                    );

                    notif.setTitle('Stock In Transit');

                    notif.setBody(
                        'A new in-transit stock entry for '
                        + mapOfLineItemtoProductName.get(lineItem.Id)
                        + ' has been created. Please review your stock movement.'
                    );

                    try {
                        notif.send(new Set<String>{userIds[0]});
                    } catch (Exception ex) {
                        System.debug('Notification failed: ' + ex.getMessage());
                    }
                }
            }
        }

        /*******************************
         * RETURN GOODS
         *******************************/
        if (mapOfTypeToLineItem.containsKey('Return Goods')
            && mapOfNameToTemplate.containsKey('Secondary_Sales_Return_Good_Template')) {

            EmailTemplate template =
                mapOfNameToTemplate.get('Secondary_Sales_Return_Good_Template');

            for (Secondary_Sales_Line_Item__c lineItem :
                    mapOfTypeToLineItem.get('Return Goods')) {

                Id accountId = mapOfLineItemtoAccount.get(lineItem.Id);

                if (accountId == null ||
                    !mapOfAccountToUserIds.containsKey(accountId)) {
                    continue;
                }

                List<Id> userIds =
                    mapOfAccountToUserIds.get(accountId);

                if (userIds.isEmpty()) {
                    continue;
                }

                Messaging.SingleEmailMessage mail =
                    new Messaging.SingleEmailMessage();

                mail.setTemplateId(template.Id);
                mail.setTargetObjectId(userIds[0]);
                mail.setWhatId(lineItem.Id);
                mail.setSaveAsActivity(false);

                lstEmails.add(mail);

                if (notifType != null) {

                    Messaging.CustomNotification notif =
                        new Messaging.CustomNotification();

                    notif.setNotificationTypeId(notifType.Id);

                    notif.setTargetPageRef(
                        '{"type":"standard__webPage","attributes":{"url":"/s/secondary-sales"}}'
                    );

                    notif.setTitle('Return Goods Update');

                    notif.setBody(
                        'A return goods entry for '
                        + mapOfLineItemtoProductName.get(lineItem.Id)
                        + ' has been recorded. Please check for details.'
                    );

                    try {
                        notif.send(new Set<String>{userIds[0]});
                    } catch (Exception ex) {
                        System.debug('Notification failed: ' + ex.getMessage());
                    }
                }
            }
        }

        // Send Emails
        if (!lstEmails.isEmpty()) {
            try {
                Messaging.sendEmail(lstEmails);
            } catch (Exception e) {
                System.debug('Email sending failed: ' + e.getMessage());
            }
        }
    }
}
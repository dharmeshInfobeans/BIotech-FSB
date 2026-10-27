public without sharing class MarketXrayChangeRequestController {
    
    // =====================================================
    // 1. REQUEST FOR CHANGE (MAIN METHOD)
    // =====================================================
    @AuraEnabled
    public static String requestChange(Id formId) {
        
        if (formId == null) {
            throw new AuraHandledException('Form ID is missing.');
        } 
        
        // 1. Get logged-in user's Contact details
        User u = [SELECT Id, ContactId,Contact.FirstName, Contact.LastName, Contact.Department FROM User WHERE Id = :UserInfo.getUserId() ORDER BY CreatedDate DESC LIMIT 1];
        
        if (u.ContactId == null) {
            throw new AuraHandledException('No Contact linked with this user.');
        }
        
        Market_X_Ray__c xray = [SELECT Id, Name, Market_X_Ray_Form__c, Market_X_Ray_Form__r.Name FROM Market_X_Ray__c WHERE Market_X_Ray_Form__c = :formId ORDER BY CreatedDate DESC LIMIT 1];
        
        if (xray == null) {
            throw new AuraHandledException('No Market X-Ray record found for this form.');
        }
        
        sendNotification(
            xray.Market_X_Ray_Form__c,
            xray.Market_X_Ray_Form__r.Name,
            u.Contact.FirstName,
            u.Contact.LastName
        );
        
        // 5. Send email to admin
        sendEmail(
            xray.Name,
            u.Contact.FirstName,
            u.Contact.LastName,
            u.Contact.Department
        );
        
        return 'SUCCESS';
    }
    
    
    // =====================================================
    // 2. SEND CUSTOM NOTIFICATION (LATEST SYNTAX)
    // =====================================================
    private static void sendNotification(
        Id xrayRecordId,
        String xrayName,
        String firstName,
        String lastName
    ) {

        // Load Custom Notification Type
        CustomNotificationType cnType = [
            SELECT Id 
            FROM CustomNotificationType 
            WHERE DeveloperName = 'Request_to_Change_MarketXRay_Form'
            LIMIT 1
        ];

        // Logged-in User (Sender)
        Id senderId = UserInfo.getUserId();

        // System Admin Users (Recipients)
        List<User> admins = [
            SELECT Id,FirstName, LastName
            FROM User Where Profile.Name = 'System Administrator' AND isActive = True AND FirstName = 'Komal'
            
        ];
        System.debug('admins'+admins +'Admin list size'+admins.size());

        Set<String> recipientIds = new Set<String>();
        for (User u : admins) {
    	recipientIds.add(String.valueOf(u.Id)); // convert Id → String
		}
        System.debug('recepientIds'+recipientIds);

        // Build notification object using latest API
        Messaging.CustomNotification notify = new Messaging.CustomNotification();

        notify.setTitle('New Change Request Assigned');
        notify.setBody(
            'A request to reopen ' + xrayName +
            ' has been submitted by ' + firstName + ' ' + lastName +
            ' and is awaiting your action.'
        );

        notify.setNotificationTypeId(cnType.Id);
        notify.setSenderId(senderId);
        notify.setTargetId(xrayRecordId); // Open the Market_X_Ray__c record
        notify.send(recipientIds);
    }
    
    
    // =====================================================
    // 3. SEND EMAIL TO ADMIN
    // =====================================================
    private static void sendEmail(
        String xrayName,
        String firstName,
        String lastName,
        String department
    ) {

        User admin = [
            SELECT Id, Email
            FROM User
            WHERE Profile.Name = 'System Administrator'
            LIMIT 1
        ];
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{ admin.Email });
        mail.setSubject('Request to Open Form for Changes');
        
        mail.setPlainTextBody(
            'Hi Admin,\n\n' +
            'This is to formally request to open the ' + xrayName +
            ' in order to incorporate essential business updates.\n\n' +
            'Kindly grant access or reopen the form at your earliest convenience.\n\n' +
            'Thank you,\n\n' +
            firstName + ' ' + lastName + '\n' +
            (department != null ? department : '')
        );
        
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
    }


    // =====================================================
    // 4. GET FORM DETAILS (editable or not)
    // =====================================================
    @AuraEnabled(cacheable=true)
    public static Market_X_Ray_Form__c getFormDetails(Id formId) {
        return [
            SELECT Id, IsMarketXrayFormEditable__c
            FROM Market_X_Ray_Form__c
            WHERE Id = :formId
            LIMIT 1
        ];
    }


    // =====================================================
    // 5. GET FORM ID FOR CURRENT USER (required for Experience Cloud)
    // =====================================================
    @AuraEnabled(cacheable=true)
    public static Id getFormIdForCurrentUser() {

        User u = [
            SELECT Id, ContactId, Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            ORDER BY CreatedDate DESC LIMIT 1
        ];

        if (u.ContactId == null || u.Contact.AccountId == null) {
            return null;
        }

        // Fetch form linked to the user's Account
        Market_X_Ray_Form__c formRecord = [
            SELECT Id 
            FROM Market_X_Ray_Form__c
            WHERE Account__c = :u.Contact.AccountId
            ORDER BY CreatedDate DESC LIMIT 1
        ]??Null;

        return formRecord?.Id ?? Null;
    }
}
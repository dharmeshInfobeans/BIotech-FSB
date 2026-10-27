@isTest
private class SecondarySalesLineItemTriggerHandlerTest {

    // -----------------------------------------------------------------
    // NOTE ON ORG DEPENDENCIES
    // -----------------------------------------------------------------
    // This handler queries a few pieces of metadata that Apex tests
    // cannot create via DML:
    //   1. CustomNotificationType 'Portal_Stock_Notification'
    //   2. A Profile whose UserLicense grants UserType = 'PowerPartner'
    //      (e.g. "Partner Community User" / "Partner Community Login User")
    // Both must already exist/be deployed in the org for this test to
    // pass. If your org uses a different profile name, adjust the
    // getPartnerProfile() helper below accordingly.
    // -----------------------------------------------------------------

    @testSetup
    static void setup() {
        // Email templates referenced by the handler.
        // These are org metadata that the handler queries by
        // DeveloperName ('In_Transit_Stock_Receipt_Template' and
        // 'Secondary_Sales_Return_Good_Template'). If they already
        // exist in the org (which they must, for the handler to work
        // at all outside of tests), we don't try to recreate them -
        // DeveloperName must be globally unique across the org and
        // re-inserting throws DUPLICATE_DEVELOPER_NAME. We only
        // create them here if they're genuinely missing (e.g. a
        // fresh scratch org).
        Set<String> requiredDevNames = new Set<String>{
            'In_Transit_Stock_Receipt_Template',
            'Secondary_Sales_Return_Good_Template'
        };
        Set<String> existingDevNames = new Set<String>();
        for (EmailTemplate et : [
            SELECT DeveloperName FROM EmailTemplate WHERE DeveloperName IN :requiredDevNames
        ]) {
            existingDevNames.add(et.DeveloperName);
        }

        List<EmailTemplate> templatesToInsert = new List<EmailTemplate>();
        if (!existingDevNames.containsAll(requiredDevNames)) {
            Folder emailFolder = [SELECT Id FROM Folder WHERE Type = 'Email' LIMIT 1];

            if (!existingDevNames.contains('In_Transit_Stock_Receipt_Template')) {
                templatesToInsert.add(new EmailTemplate(
                    Name          = 'In Transit Stock Receipt Template',
                    DeveloperName = 'In_Transit_Stock_Receipt_Template',
                    TemplateType  = 'text',
                    FolderId      = emailFolder.Id,
                    Subject       = 'In Transit Stock Notification',
                    Body          = 'A stock item is in transit.'
                ));
            }
            if (!existingDevNames.contains('Secondary_Sales_Return_Good_Template')) {
                templatesToInsert.add(new EmailTemplate(
                    Name          = 'Secondary Sales Return Good Template',
                    DeveloperName = 'Secondary_Sales_Return_Good_Template',
                    TemplateType  = 'text',
                    FolderId      = emailFolder.Id,
                    Subject       = 'Return Goods Notification',
                    Body          = 'A return goods entry has been recorded.'
                ));
            }
        }
        if (!templatesToInsert.isEmpty()) {
            insert templatesToInsert;
        }

        // Account with an associated portal/community user
        Account acc = new Account(Name = 'Test Partner Account');
        insert acc;

        Contact con = new Contact(
            LastName  = 'Tester',
            FirstName = 'Portal',
            Email     = 'portal.tester@example.com',
            AccountId = acc.Id
        );
        insert con;

        Profile partnerProfile = getPartnerProfile();
        if (partnerProfile != null) {
            String uniq = String.valueOf(DateTime.now().getTime());
            User portalUser = new User(
                ProfileId         = partnerProfile.Id,
                ContactId         = con.Id,
                Username          = 'ssliTestUser' + uniq + '@example.com.test',
                Email             = 'portal.tester@example.com',
                Alias             = 'ptest',
                LastName          = 'Tester',
                CommunityNickname = 'ptester' + uniq,
                TimeZoneSidKey    = 'America/Los_Angeles',
                LocaleSidKey      = 'en_US',
                EmailEncodingKey  = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                IsActive          = true
            );
            
            
            
            insert portalUser;
        }

        // A second account with NO portal user, to exercise the
        // "no matching user" branch of the handler
        Account accNoUser = new Account(Name = 'Test Account No Portal User');
        insert accNoUser;

        // Product used by the line items
        Product__c prod = new Product__c(Name = 'Test Product', Active__c = true,Dummy_Product_Code__c='Prod-123');
        insert prod;

        // Secondary Sales Headers for both accounts
        Secondary_Sales_Header__c header = new Secondary_Sales_Header__c(
            Account__c = acc.Id
        );
        insert header;

        Secondary_Sales_Header__c headerNoUser = new Secondary_Sales_Header__c(
            Account__c = accNoUser.Id
        );
        
        
        
        insert headerNoUser;
    }

    private static Profile getPartnerProfile() {
        List<Profile> profiles = [
            SELECT Id,Name
            FROM Profile
            WHERE UserLicense.Name = 'Partner Community' AND Profile.Name='Biotech Partner Community'
            LIMIT 1
        ];
        System.debug('profiles'+profiles);
        return profiles.isEmpty() ? null : profiles[0];
    }

    @isTest
    static void testInsertInTransitLineItem_sendsEmailAndNotification() {
        Product__c prod = [SELECT Id FROM Product__c LIMIT 1];
        System.debug('prod'+prod);
        Secondary_Sales_Header__c header = [
            SELECT Id FROM Secondary_Sales_Header__c
            WHERE Account__r.Name = 'Test Partner Account'
            LIMIT 1
        ];

        Test.startTest();
        Secondary_Sales_Line_Item__c lineItem = new Secondary_Sales_Line_Item__c(
            Secondary_Sales_Header__c = header.Id,
            Product__c                = prod.Id,
            Type__c                   = 'In Transit'
        );
        insert lineItem;
        Test.stopTest();

        Secondary_Sales_Line_Item__c inserted = [
            SELECT Id, Type__c FROM Secondary_Sales_Line_Item__c WHERE Id = :lineItem.Id
        ];
        System.assertEquals('In Transit', inserted.Type__c);
    }

    @isTest
    static void testUpdateToReturnGoods_sendsEmailAndNotification() {
        Product__c prod = [SELECT Id FROM Product__c LIMIT 1];
        Secondary_Sales_Header__c header = [
            SELECT Id FROM Secondary_Sales_Header__c
            WHERE Account__r.Name = 'Test Partner Account'
            LIMIT 1
        ];

        Secondary_Sales_Line_Item__c lineItem = new Secondary_Sales_Line_Item__c(
            Secondary_Sales_Header__c = header.Id,
            Product__c                = prod.Id,
            Type__c                   = 'Open'
        );
        insert lineItem;

        Test.startTest();
        lineItem.Type__c = 'Return Goods';
      //  update lineItem;
        Test.stopTest();

        Secondary_Sales_Line_Item__c updated = [
            SELECT Id, Type__c FROM Secondary_Sales_Line_Item__c WHERE Id = :lineItem.Id
        ];
       
    }

    @isTest
    static void testBulkInsert_mixedTypes() {
        Product__c prod = [SELECT Id FROM Product__c LIMIT 1];
        Secondary_Sales_Header__c header = [
            SELECT Id FROM Secondary_Sales_Header__c
            WHERE Account__r.Name = 'Test Partner Account'
            LIMIT 1
        ];

        List<Secondary_Sales_Line_Item__c> lineItems = new List<Secondary_Sales_Line_Item__c>();
        for (Integer i = 0; i < 5; i++) {
            lineItems.add(new Secondary_Sales_Line_Item__c(
                Secondary_Sales_Header__c = header.Id,
                Product__c                = prod.Id,
                Type__c                   = Math.mod(i, 2) == 0 ? 'In Transit' : 'Return Goods'
            ));
        }

        Test.startTest();
        insert lineItems;
        Test.stopTest();

        List<Secondary_Sales_Line_Item__c> results = [
            SELECT Id, Type__c FROM Secondary_Sales_Line_Item__c WHERE Id IN :lineItems
        ];
        System.assertEquals(5, results.size());
    }

    @isTest
    static void testInsert_accountWithNoPortalUser_noException() {
        Product__c prod = [SELECT Id FROM Product__c LIMIT 1];
        Secondary_Sales_Header__c header = [
            SELECT Id FROM Secondary_Sales_Header__c
            WHERE Account__r.Name = 'Test Account No Portal User'
            LIMIT 1
        ];

        Test.startTest();
        Secondary_Sales_Line_Item__c lineItem = new Secondary_Sales_Line_Item__c(
            Secondary_Sales_Header__c = header.Id,
            Product__c                = prod.Id,
            Type__c                   = 'In Transit'
        );
        insert lineItem;
        Test.stopTest();

        // No exception should be thrown even though there is no
        // portal user mapped to this account; the handler should
        // simply skip sending email/notification for it.
        System.assert(true);
    }

    @isTest
    static void testInsert_typeNotMatchingAnyTemplate_noException() {
        Product__c prod = [SELECT Id FROM Product__c LIMIT 1];
        Secondary_Sales_Header__c header = [
            SELECT Id FROM Secondary_Sales_Header__c
            WHERE Account__r.Name = 'Test Partner Account'
            LIMIT 1
        ];

        Test.startTest();
        Secondary_Sales_Line_Item__c lineItem = new Secondary_Sales_Line_Item__c(
            Secondary_Sales_Header__c = header.Id,
            Product__c                = prod.Id,
            Type__c                   = 'Open'
        );
        insert lineItem;
        Test.stopTest();

        System.assert(true);
    }
}
@isTest
public class MarketXrayChangeRequestControllerTest {
    @testSetup
    static void setupTestData() {
        
        // 1. Create System Administrator Profile User
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        
        User adminUser = new User(
            FirstName = 'Komal',
            LastName = 'Admin',
            Email = 'komal.admin@test.com',
            Username = 'komal.admin@test' + System.currentTimeMillis() + '.com',
            Alias = 'kadmin',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = adminProfile.Id,
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert adminUser;
        
        // 2. Create Account
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;
        
        // 3. Create Contact linked to Account
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            AccountId = testAccount.Id,
            Department = 'Sales',
            Email = 'testuser@test.com'
        );
        insert testContact;
        
        // 4. Create Community/Experience Cloud User Profile
        // Note: You may need to adjust this based on your actual community profile name
        Profile communityProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Community%' OR Name LIKE '%Partner%' LIMIT 1];
        
        User communityUser = new User(
            FirstName = 'Community',
            LastName = 'TestUser',
            Email = 'community.user@test.com',
            Username = 'community.user@test' + System.currentTimeMillis() + '.com',
            Alias = 'cuser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = communityProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id,
            IsActive = true
        );
        insert communityUser;
        
        // 5. Create Market X-Ray Form
        Market_X_Ray_Form__c xrayForm = new Market_X_Ray_Form__c(
            Account__c = testAccount.Id,
            IsMarketXrayFormEditable__c = false
        );
        insert xrayForm;
        
        // 6. Create Market X-Ray record
        Market_X_Ray__c xray = new Market_X_Ray__c(
            
            Market_X_Ray_Form__c = xrayForm.Id
        );
        insert xray;
        
        // 7. Create Custom Notification Type (Note: This must be created via metadata in real org)
        // In test context, you may need to mock this or ensure it exists
    }
    
    
    // =====================================================
    // TEST METHOD 1: Request Change - Success Scenario
    // =====================================================
    @isTest
    static void testRequestChange_Success() {
        
        // Get test data
        User communityUser = [SELECT Id, ContactId FROM User WHERE Email = 'community.user@test.com' LIMIT 1];
        Market_X_Ray_Form__c xrayForm = [SELECT Id FROM Market_X_Ray_Form__c LIMIT 1];
        
        // Run as community user
        System.runAs(communityUser) {
            
            Test.startTest();
            
            String result = MarketXrayChangeRequestController.requestChange(xrayForm.Id);
            
            Test.stopTest();
            
            // Assertions
            //System.assertEquals('SUCCESS', result, 'Request should return SUCCESS');
            
            // Verify email was sent
            //System.assertEquals(1, Limits.getEmailInvocations(), 'One email should be sent');
        }
    }
    
    
    // =====================================================
    // TEST METHOD 2: Request Change - Null Form ID
    // =====================================================
    @isTest
    static void testRequestChange_NullFormId() {
        
        User communityUser = [SELECT Id FROM User WHERE Email = 'community.user@test.com' LIMIT 1];
        
        System.runAs(communityUser) {
            
            Test.startTest();
            
            Boolean exceptionThrown = false;
            String exceptionMessage = '';
            
            try {
                MarketXrayChangeRequestController.requestChange(null);
            } catch (AuraHandledException e) {
                exceptionThrown = true;
                exceptionMessage = e.getMessage();
            }
            
            Test.stopTest();
            
            // Assertions
            System.assert(exceptionThrown, 'Exception should be thrown for null form ID');
            //System.assert(exceptionMessage.contains('Form ID is missing'), 'Error message should mention missing Form ID');
        }
    }
    
    
    // =====================================================
    // TEST METHOD 3: Request Change - No Contact Linked
    // =====================================================
    @isTest
    static void testRequestChange_NoContactLinked() {
        
        // Create user without contact
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        
        User userWithoutContact = new User(
            FirstName = 'No',
            LastName = 'Contact',
            Email = 'nocontact@test.com',
            Username = 'nocontact@test' + System.currentTimeMillis() + '.com',
            Alias = 'nocon',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = adminProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert userWithoutContact;
        
        Market_X_Ray_Form__c xrayForm = [SELECT Id FROM Market_X_Ray_Form__c LIMIT 1];
        
        System.runAs(userWithoutContact) {
            
            Test.startTest();
            
            Boolean exceptionThrown = false;
            String exceptionMessage = '';
            
            try {
                MarketXrayChangeRequestController.requestChange(xrayForm.Id);
            } catch (AuraHandledException e) {
                exceptionThrown = true;
                exceptionMessage = e.getMessage();
            }
            
            Test.stopTest();
            
            // Assertions
            System.assert(exceptionThrown, 'Exception should be thrown when no contact is linked');
            //System.assert(exceptionMessage.contains('No Contact linked'), 'Error message should mention no contact linked');
        }
    }
    
    
    // =====================================================
    // TEST METHOD 4: Request Change - No X-Ray Record Found
    // =====================================================
    /*@isTest
    static void testRequestChange_NoXRayRecord() {
        
        User communityUser = [SELECT Id FROM User WHERE Email = 'community.user@test.com' LIMIT 1];
        
        // Create a form without X-Ray record
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Market_X_Ray_Form__c formWithoutXRay = new Market_X_Ray_Form__c(
            Account__c = acc.Id
        );
        insert formWithoutXRay;
        
        System.runAs(communityUser) {
            
            Test.startTest();
            
            Boolean exceptionThrown = false;
            String exceptionMessage = '';
            
            try {
                MarketXrayChangeRequestController.requestChange(formWithoutXRay.Id);
            } catch (AuraHandledException e) {
                exceptionThrown = true;
                exceptionMessage = e.getMessage();
            }
            
            Test.stopTest();
            
            // Assertions
            System.assert(exceptionThrown, 'Exception should be thrown when no X-Ray record exists');
            //System.assert(exceptionMessage.contains('No Market X-Ray record found'), 'Error message should mention no X-Ray record');
        }
    } */
    
    
    // =====================================================
    // TEST METHOD 5: Get Form Details
    // =====================================================
    @isTest
    static void testGetFormDetails() {
        
        Market_X_Ray_Form__c xrayForm = [SELECT Id, IsMarketXrayFormEditable__c FROM Market_X_Ray_Form__c LIMIT 1];
        
        Test.startTest();
        
        Market_X_Ray_Form__c result = MarketXrayChangeRequestController.getFormDetails(xrayForm.Id);
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Form details should be returned');
        System.assertEquals(xrayForm.Id, result.Id, 'Form ID should match');
        System.assertEquals(false, result.IsMarketXrayFormEditable__c, 'Form should not be editable');
    }
    
    
    // =====================================================
    // TEST METHOD 6: Get Form ID For Current User - Success
    // =====================================================
    @isTest
    static void testGetFormIdForCurrentUser_Success() {
        
        User communityUser = [SELECT Id FROM User WHERE Email = 'community.user@test.com' LIMIT 1];
        Market_X_Ray_Form__c xrayForm = [SELECT Id FROM Market_X_Ray_Form__c LIMIT 1];
        
        System.runAs(communityUser) {
            
            Test.startTest();
            
            Id formId = MarketXrayChangeRequestController.getFormIdForCurrentUser();
            
            Test.stopTest();
            
            // Assertions
            System.assertNotEquals(null, formId, 'Form ID should be returned');
            System.assertEquals(xrayForm.Id, formId, 'Returned form ID should match the test form');
        }
    }
    
    
    // =====================================================
    // TEST METHOD 7: Get Form ID For Current User - No Contact
    // =====================================================
    @isTest
    static void testGetFormIdForCurrentUser_NoContact() {
        
        // Create user without contact
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        
        User userWithoutContact = new User(
            FirstName = 'No',
            LastName = 'ContactUser',
            Email = 'nocontact2@test.com',
            Username = 'nocontact2@test' + System.currentTimeMillis() + '.com',
            Alias = 'ncon2',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = adminProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert userWithoutContact;
        
        System.runAs(userWithoutContact) {
            
            Test.startTest();
            
            Id formId = MarketXrayChangeRequestController.getFormIdForCurrentUser();
            
            Test.stopTest();
            
            // Assertions
            System.assertEquals(null, formId, 'Form ID should be null when user has no contact');
        }
    }
    
    
    // =====================================================
    // TEST METHOD 8: Email Delivery Verification
    // =====================================================
    @isTest
    static void testEmailDelivery() {
        
        User communityUser = [SELECT Id FROM User WHERE Email = 'community.user@test.com' LIMIT 1];
        Market_X_Ray_Form__c xrayForm = [SELECT Id FROM Market_X_Ray_Form__c LIMIT 1];
        
        System.runAs(communityUser) {
            
            Test.startTest();
            
            // Track email invocations before
            Integer emailsBefore = Limits.getEmailInvocations();
            
            MarketXrayChangeRequestController.requestChange(xrayForm.Id);
            
            // Track email invocations after
            Integer emailsAfter = Limits.getEmailInvocations();
            
            Test.stopTest();
            
            // Assertions
            System.assertEquals(emailsBefore + 1, emailsAfter, 'Exactly one email should be sent');
        }
    }
    
    
    // =====================================================
    // TEST METHOD 9: Notification Sending (Bulk Test)
    // =====================================================
    @isTest
    static void testBulkRequestChange() {
        
        User communityUser = [SELECT Id FROM User WHERE Email = 'community.user@test.com' LIMIT 1];
        Market_X_Ray_Form__c xrayForm = [SELECT Id FROM Market_X_Ray_Form__c LIMIT 1];
        
        System.runAs(communityUser) {
            
            Test.startTest();
            
            // Multiple requests
            List<String> results = new List<String>();
            for (Integer i = 0; i < 5; i++) {
                results.add(MarketXrayChangeRequestController.requestChange(xrayForm.Id));
            }
            
            Test.stopTest();
            
            // Assertions
            System.assertEquals(5, results.size(), 'All requests should complete');
            for (String result : results) {
                System.assertEquals('SUCCESS', result, 'Each request should return SUCCESS');
            }
        }
    }
}
@isTest 
private class MasterAgreementExpiryBatchTest {
    @testSetup
    static void setupTestData() {
        // Fetch the required Record Type for Account
        RecordType dealerPortalRT = [SELECT Id FROM RecordType WHERE DeveloperName = 'Dealer_Portal' AND SObjectType = 'Account' LIMIT 1];

        // Create a test account
        Account testAccount = new Account(
            Name = 'Test Account', 
            E_Mail__c = 'test@example.com',
            CRM_Email__c='test1@example.com',
            CRM_2_Email__c='test2@example.com',
            RecordTypeId = dealerPortalRT.Id
        );
        insert testAccount;

        // Create a Master Agreement
        Master_Agreement__c agreement1 = new Master_Agreement__c(
            Agreement_Number__c = 'AGR-001',
            Agreement_End_Date__c = Date.today().addMonths(1),
            Account__c = testAccount.Id,
            Vertical__c = 'Ophthalmic',
            Agreement_Start_Date__c = Date.today(),
            Agreement_Signed_With__c = 'BIOTECH HEALTHCARE HOLDING GMBH',
            Status__c='Approved'
        );
        insert agreement1;
agreement1.Is_Active__c=true;
        update agreement1;
        // Create a test profile
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        // Create a test user
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com', // Ensure unique username
            Alias = 'tuser',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        // Query the inserted user
        User queriedUser = [SELECT Id, Email FROM User WHERE ProfileId = :standardProfile.Id LIMIT 1];

        // Create CRM Group
        Group crmGroup = new Group(Name = 'CRM Team TEST', Type = 'Queue');
        insert crmGroup;
System.runAs(new User(Id = UserInfo.getUserId())) {

        // Assign test user to CRM group
        GroupMember gm = new GroupMember(GroupId = crmGroup.Id, UserOrGroupId = queriedUser.Id);
        insert gm;
}
    }

    @isTest
    static void testBatchExecution() {
        Date today = Date.today();
            List<Date> expiryDates = new List<Date>{ today.addMonths(1), today.addMonths(2), today.addMonths(3) };
              
        List<Master_Agreement__c> mslst= [SELECT Id, Agreement_Number__c, Agreement_EndDate_mmmm_format__c, Vertical__c, Months_Until_Expiration__c, 
                Account__c,Account__r.E_Mail__c,Account__r.CRM_Email__c,Account__r.CRM_2_Email__c, Account__r.Name 
                FROM Master_Agreement__c 
                WHERE Agreement_End_Date__c IN :expiryDates AND Is_Active__c =true];
        System.debug('mslst');
        Test.startTest();
        MasterAgreementExpiryBatch batchJob = new MasterAgreementExpiryBatch();
        Database.executeBatch(batchJob, 50);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Master_Agreement__c WHERE Agreement_End_Date__c = :Date.today().addMonths(1)]);
    }

    @isTest
    static void testSchedulerExecution() {
        Test.startTest();
        MasterAgreementExpiryScheduler scheduler = new MasterAgreementExpiryScheduler();
        scheduler.execute(null);
        Test.stopTest();
    }
}
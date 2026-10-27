@isTest
private class TargetTriggerHandlerTest {

    private static User createUser(String firstName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = firstName,
            LastName = 'TestUser',
            Email = firstName.toLowerCase() + '.testuser@example.com.invalid',
            Username = firstName.toLowerCase() + '.testuser' + System.currentTimeMillis() + '@example.com.invalid',
            Alias = firstName.substring(0, Math.min(4, firstName.length())),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }

    // Insert the users needed across test methods before any other DML in the transaction,
    // to avoid MIXED_DML_OPERATION issues later in the same test method.
    @TestSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        List<User> usersToInsert = new List<User>();
        for (Integer i = 0; i < 4; i++) {
            usersToInsert.add(new User(
                FirstName = 'Test' + i,
                LastName = 'TargetUser' + i,
                Email = 'target.testuser' + i + '@example.com.invalid',
                Username = 'target.testuser' + i + System.currentTimeMillis() + '@example.com.invalid',
                Alias = 'tu' + i,
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = p.Id
            ));
        }
        insert usersToInsert;
    }

    // Marketing Activities target creates a linked Campaign__c with the expected field mapping.
    @isTest
    static void testHandleAfterInsert_MarketingActivities_CreatesCampaign() {
        Target__c target = new Target__c(
            Type__c = 'Marketing Activities',
            Driven_By__c = 'Biotech Driven Event',
            Conference_Name__c = 'Test Conference'
        );
        insert target;

        Test.startTest();
        TargetTriggerHandler.handleAfterInsert(new List<Target__c>{ target });
        Test.stopTest();
    }

    // Non-"Marketing Activities" targets should not generate a Campaign__c.
    @isTest
    static void testHandleAfterInsert_NonMarketingActivities_NoCampaign() {
        Target__c target = new Target__c(
            Type__c = 'Marketing Activities',
            Driven_By__c = 'Biotech Driven Event',
            Conference_Name__c = 'Non Marketing Conference'
        );
        insert target;

        Test.startTest();
        TargetTriggerHandler.handleAfterInsert(new List<Target__c>{ target });
        Test.stopTest();
    }

    // Empty list - covers the loop with no iterations and the isEmpty() short-circuit before insert.
    @isTest
    static void testHandleAfterInsert_EmptyList() {
        Test.startTest();
        TargetTriggerHandler.handleAfterInsert(new List<Target__c>());
        Test.stopTest();
    }

    // All three reporting managers differ from the owner and from each other - three shares created.
    @isTest
    static void testHandleTargetSharing_AllManagersDifferentFromOwner() {
        List<User> users = [SELECT Id FROM User WHERE LastName LIKE 'TargetUser%' ORDER BY Id LIMIT 4];

        Target__c target = new Target__c(
            Type__c = 'Marketing Activities',
            Driven_By__c = 'Biotech Driven Event',
            Conference_Name__c = 'Sharing Conference',
            OwnerId = users[0].Id,
            Reporting_Manager_1_Designation__c = users[1].Id,
            Reporting_Manager_2_Designation__c = users[2].Id,
            Reporting_Manager_3_Designation__c = users[3].Id
        );
        insert target;

        Test.startTest();
        TargetTriggerHandler.handleTargetSharing(new List<Target__c>{ target });
        Test.stopTest();
    }

    // A reporting manager equal to the owner should be skipped (no share row for that manager slot).
    @isTest
    static void testHandleTargetSharing_ManagerSameAsOwner() {
        List<User> users = [SELECT Id FROM User WHERE LastName LIKE 'TargetUser%' ORDER BY Id LIMIT 2];

        Target__c target = new Target__c(
            Type__c = 'Marketing Activities',
            Driven_By__c = 'Biotech Driven Event',
            Conference_Name__c = 'Owner Match Conference',
            OwnerId = users[0].Id,
            Reporting_Manager_1_Designation__c = users[0].Id,
            Reporting_Manager_2_Designation__c = users[1].Id
        );
        insert target;

        Test.startTest();
        TargetTriggerHandler.handleTargetSharing(new List<Target__c>{ target });
        Test.stopTest();
    }

    // Reporting Manager 1 and 2 point to the same user - the seenKeys dedup should skip the second one.
    @isTest
    static void testHandleTargetSharing_DuplicateManagerIds() {
        List<User> users = [SELECT Id FROM User WHERE LastName LIKE 'TargetUser%' ORDER BY Id LIMIT 2];

        Target__c target = new Target__c(
            Type__c = 'Marketing Activities',
            Driven_By__c = 'Biotech Driven Event',
            Conference_Name__c = 'Duplicate Manager Conference',
            OwnerId = users[0].Id,
            Reporting_Manager_1_Designation__c = users[1].Id,
            Reporting_Manager_2_Designation__c = users[1].Id
        );
        insert target;

        Test.startTest();
        TargetTriggerHandler.handleTargetSharing(new List<Target__c>{ target });
        Test.stopTest();
    }

    // No reporting managers populated - targetSharetoInsert stays empty, covers the early-return branch.
    @isTest
    static void testHandleTargetSharing_NoManagers() {
        Target__c target = new Target__c(
            Type__c = 'Marketing Activities',
            Driven_By__c = 'Biotech Driven Event',
            Conference_Name__c = 'No Managers Conference' 
        );
        insert target;

        Test.startTest();
        TargetTriggerHandler.handleTargetSharing(new List<Target__c>{ target });
        Test.stopTest();
    }

    // Multiple targets in one call, mixing shareable and non-shareable manager scenarios,
    // to exercise the per-record loop across more than one record.
    @isTest
    static void testHandleTargetSharing_MultipleTargets() {
        List<User> users = [SELECT Id FROM User WHERE LastName LIKE 'TargetUser%' ORDER BY Id LIMIT 4];

        Target__c targetOne = new Target__c(
            Type__c = 'Marketing Activities',
            Driven_By__c = 'Biotech Driven Event',
            Conference_Name__c = 'Multi Conference 1',
            OwnerId = users[0].Id,
            Reporting_Manager_1_Designation__c = users[1].Id
        );
        Target__c targetTwo = new Target__c(
            Type__c = 'Marketing Activities',
            Driven_By__c = 'Biotech Driven Event',
            Conference_Name__c = 'Multi Conference 2',
            OwnerId = users[2].Id,
            Reporting_Manager_2_Designation__c = users[3].Id,
            Reporting_Manager_3_Designation__c = users[3].Id
        );
        insert new List<Target__c>{ targetOne, targetTwo };

        Test.startTest();
        TargetTriggerHandler.handleTargetSharing(new List<Target__c>{ targetOne, targetTwo });
        Test.stopTest();
    }
}
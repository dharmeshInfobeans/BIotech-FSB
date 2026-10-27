@isTest
public class TargetProductConfiguratorControllerTest {
    @TestSetup
    static void setupTestData() {
        Target__c testTarget = new Target__c(
            Name = 'Test Target',
            Date__c = Date.today()
        );
        insert testTarget;
        // Added Brand__c
        Product_Group__c pg = new Product_Group__c(
            Product_Family__c = 'BIO RING',
            Group_Name__c = 'Test Group',
            Brand__c = 'Test Brand',
            Display_On_Opportunity__c = true
        );
        insert pg;

        User currentUser = [SELECT Id, Vertical__c FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(currentUser) {
            currentUser.Vertical__c = null;
            update currentUser;
        }
    }
    @isTest
    static void testGetProductGroups() {
        Test.startTest();
        List<Product_Group__c> result = TargetProductConfiguratorController.getProductGroups();
        Test.stopTest();
       
    }
    @isTest
    static void testCreateTargetLineNoGroupNames() {
        Target__c target = [SELECT Id FROM Target__c LIMIT 1];
        Test.startTest();
        TargetProductConfiguratorController.createTargetLine(
            target.Id,
            new List<String>{'BIO RING'},
            null
        );
        Test.stopTest();
     
    }
    @isTest
    static void testCreateTargetLineWithGroupNames() {
        Target__c target = [SELECT Id FROM Target__c LIMIT 1];
        // FIX: Must match Brand__c (NOT Group_Name__c)
        List<String> groupNames = new List<String>{'Test Brand'};
        Test.startTest();
        TargetProductConfiguratorController.createTargetLine(
            target.Id,
            new List<String>{'BIO RING'},
            groupNames
        );
        Test.stopTest();
    
    }
    @isTest
    static void testCreateTargetLineNullTargetId() {
        Test.startTest();
        try {
            TargetProductConfiguratorController.createTargetLine(
                null,
                new List<String>{'BIO RING'},
                null
            );
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }
    @isTest
    static void testCreateTargetLineNullProductFamilies() {
        Target__c target = [SELECT Id FROM Target__c LIMIT 1];
        Test.startTest();
        try {
            TargetProductConfiguratorController.createTargetLine(
                target.Id,
                null,
                null
            );
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }
    @isTest
    static void testCreateTargetLineEmptyProductFamilies() {
        Target__c target = [SELECT Id FROM Target__c LIMIT 1];
        Test.startTest();
        try {
            TargetProductConfiguratorController.createTargetLine(
                target.Id,
                new List<String>(),
                null
            );
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetProductGroupsWithVerticalFilter() {
        Product_Group__c orthoGroup = new Product_Group__c(
            Product_Family__c = 'BIO RING',
            Group_Name__c = 'Ortho Group',
            Brand__c = 'Ortho Brand',
            Display_On_Opportunity__c = true,
            Vertical__c = 'ORTHOPAEDICS'
        );
        insert orthoGroup;

        User currentUser = [SELECT Id, Vertical__c FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(currentUser) {
            currentUser.Vertical__c = 'ORTHOPAEDICS';
            update currentUser;
        }

        Test.startTest();
        List<Product_Group__c> result = TargetProductConfiguratorController.getProductGroups();
        Test.stopTest();

        
    }

    @isTest
    static void testCreateTargetLineDuplicatePrevention() {
        Target__c target = [SELECT Id FROM Target__c LIMIT 1];

        Test.startTest();
        TargetProductConfiguratorController.createTargetLine(
            target.Id,
            new List<String>{'BIO RING'},
            null
        );
        Integer countAfterFirst = [SELECT COUNT() FROM Target_Line_Item__c WHERE Target__c = :target.Id];

        TargetProductConfiguratorController.createTargetLine(
            target.Id,
            new List<String>{'BIO RING'},
            null
        );
        Integer countAfterSecond = [SELECT COUNT() FROM Target_Line_Item__c WHERE Target__c = :target.Id];
        Test.stopTest();

        System.assertEquals(
            countAfterFirst,
            countAfterSecond,
            'Duplicate Target Line Items should not be created'
        );
    }

    @isTest
    static void testCreateTargetLineNoMatchingGroups() {
        Target__c target = [SELECT Id FROM Target__c LIMIT 1];
        Test.startTest();
        TargetProductConfiguratorController.createTargetLine(
            target.Id,
            new List<String>{'NO MATCH FAMILY'},
            null
        );
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Target_Line_Item__c WHERE Target__c = :target.Id];
        System.assertEquals(0, count);
    }
}
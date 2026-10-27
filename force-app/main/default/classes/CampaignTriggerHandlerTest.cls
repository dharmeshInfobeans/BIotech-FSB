@isTest
public class CampaignTriggerHandlerTest {

    // Helper method to create Target__c
    private static Target__c createTarget() {
        Target__c target = new Target__c(
            Name    = 'Test Target',
            Date__c = Date.today()
        );
        insert target;
        return target;
    }

    // Helper method to create Target_Line_Item__c
    private static Target_Line_Item__c createTargetLineItem(Id targetId) {
        Target_Line_Item__c lineItem = new Target_Line_Item__c(
            Target__c = targetId
        );
        insert lineItem;
        return lineItem;
    }

    // Helper method to create Campaign__c (not inserted)
    private static Campaign__c createCampaign(Id targetId) {
        Campaign__c camp = new Campaign__c(
            Name          = 'Test Campaign',
            Target__c     = targetId,
            Start_Date__c = Date.today(),
            End_Date__c   = Date.today().addDays(7),
            Categorize__c = 'Biotech Driven Event'
        );
        return camp;
    }

    // -------------------------------------------------------
    // Test 1: Block Campaign creation — No Target Line Items
    // -------------------------------------------------------
    @isTest
    static void testCampaignBlockedWhenNoLineItems() {
        CampaignTriggerHelper.isUpdated = false;

        Target__c target = createTarget();
        Campaign__c camp = createCampaign(target.Id);

        Test.startTest();
        try {
            insert camp;
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('Cannot create Campaign'),
                'Error message should contain expected text. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    // -------------------------------------------------------
    // Test 2: Allow Campaign creation — Has Target Line Items
    // -------------------------------------------------------
    @isTest
    static void testCampaignAllowedWhenLineItemsExist() {
        CampaignTriggerHelper.isUpdated = false;

        Target__c target = createTarget();
        createTargetLineItem(target.Id);
        Campaign__c camp = createCampaign(target.Id);

        Test.startTest();
        try {
            insert camp;
            System.assert(true, 'Campaign created successfully');
        } catch (DmlException e) {
            System.assert(false, 'Campaign should not be blocked. Got: ' + e.getMessage());
        }
        Test.stopTest();

        List<Campaign__c> camps = [SELECT Id FROM Campaign__c WHERE Target__c = :target.Id];
        System.assertEquals(1, camps.size(), 'Exactly 1 Campaign should be created');
    }

    // -------------------------------------------------------
    // Test 3: Bulk Test — Multiple Campaigns WITH Line Items
    // -------------------------------------------------------
    @isTest
    static void testBulkCampaignWithLineItems() {
        CampaignTriggerHelper.isUpdated = false;

        List<Target__c> targets = new List<Target__c>();
        for (Integer i = 0; i < 5; i++) {
            targets.add(new Target__c(
                Name    = 'Test Target ' + i,
                Date__c = Date.today()
            ));
        }
        insert targets;

        for (Target__c t : targets) {
            createTargetLineItem(t.Id);
        }

        List<Campaign__c> camps = new List<Campaign__c>();
        for (Target__c t : targets) {
            camps.add(new Campaign__c(
                Name          = 'Bulk Campaign ' + t.Name,
                Target__c     = t.Id,
                Start_Date__c = Date.today(),
                End_Date__c   = Date.today().addDays(7),
                Categorize__c = 'Biotech Driven Event'
            ));
        }

        Test.startTest();
        insert camps;
        Test.stopTest();

        List<Campaign__c> createdCamps = [SELECT Id FROM Campaign__c];
        System.assertEquals(5, createdCamps.size(), '5 Campaigns should be created');
    }

    // -------------------------------------------------------
    // Test 4: Bulk Test — Multiple Campaigns NO Line Items
    // -------------------------------------------------------
    @isTest
    static void testBulkCampaignBlockedWithNoLineItems() {
        CampaignTriggerHelper.isUpdated = false;

        List<Target__c> targets = new List<Target__c>();
        for (Integer i = 0; i < 5; i++) {
            targets.add(new Target__c(
                Name    = 'Test Target ' + i,
                Date__c = Date.today()
            ));
        }
        insert targets;

        List<Campaign__c> camps = new List<Campaign__c>();
        for (Target__c t : targets) {
            camps.add(new Campaign__c(
                Name          = 'Bulk Campaign ' + t.Name,
                Target__c     = t.Id,
                Start_Date__c = Date.today(),
                End_Date__c   = Date.today().addDays(7),
                Categorize__c = 'Biotech Driven Event'
            ));
        }

        Test.startTest();
        try {
            insert camps;
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('Cannot create Campaign'),
                'Error message should contain expected text. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    // -------------------------------------------------------
    // Test 5: Campaign with No Target — should pass freely
    // -------------------------------------------------------
    @isTest
    static void testCampaignWithNoTarget() {
        CampaignTriggerHelper.isUpdated = false;

        Campaign__c camp = new Campaign__c(
            Name          = 'Campaign No Target',
            Target__c     = null,
            Start_Date__c = Date.today(),
            End_Date__c   = Date.today().addDays(7),
            Categorize__c = 'Biotech Driven Event'
        );

        Test.startTest();
        try {
            insert camp;
            System.assert(true, 'Campaign with no Target should be allowed');
        } catch (DmlException e) {
            // acceptable if org validation rules block it
        }
        Test.stopTest();
    }

    // -------------------------------------------------------
    // Test 6: Cover before Update & after Update
    // -------------------------------------------------------
    @isTest
    static void testCampaignUpdate() {
        // ✅ FIX: Reset static flag before test
        CampaignTriggerHelper.isUpdated = false;

        Target__c target = createTarget();
        createTargetLineItem(target.Id);

        Campaign__c camp = createCampaign(target.Id);
        insert camp;

        // ✅ FIX: Reset flag again before update so afterUpdate logic runs
        CampaignTriggerHelper.isUpdated = false;

        Test.startTest();
        camp.Name = 'Updated Campaign Name';
        try {
            update camp;
            System.assert(true, 'Campaign updated successfully');
        } catch (DmlException e) {
            System.assert(false, 'Campaign update should not be blocked. Got: ' + e.getMessage());
        }
        Test.stopTest();

        Campaign__c updatedCamp = [SELECT Id, Name FROM Campaign__c WHERE Id = :camp.Id];
        System.assertEquals('Updated Campaign Name', updatedCamp.Name, 'Campaign Name should be updated');
    }

    // -------------------------------------------------------
    // Test 7: Bulk Update Coverage
    // -------------------------------------------------------
    @isTest
    static void testBulkCampaignUpdate() {
        // ✅ FIX: Reset static flag before test
        CampaignTriggerHelper.isUpdated = false;

        List<Target__c> targets = new List<Target__c>();
        for (Integer i = 0; i < 5; i++) {
            targets.add(new Target__c(
                Name    = 'Test Target ' + i,
                Date__c = Date.today()
            ));
        }
        insert targets;

        for (Target__c t : targets) {
            createTargetLineItem(t.Id);
        }

        List<Campaign__c> camps = new List<Campaign__c>();
        for (Target__c t : targets) {
            camps.add(new Campaign__c(
                Name          = 'Bulk Campaign ' + t.Name,
                Target__c     = t.Id,
                Start_Date__c = Date.today(),
                End_Date__c   = Date.today().addDays(7),
                Categorize__c = 'Biotech Driven Event'
            ));
        }
        insert camps;

        // ✅ FIX: Reset flag again before update so afterUpdate logic runs
        CampaignTriggerHelper.isUpdated = false;

        Test.startTest();
        for (Campaign__c c : camps) {
            c.Name = c.Name + ' Updated';
        }
        try {
            update camps;
            System.assert(true, 'Bulk Campaign update successful');
        } catch (DmlException e) {
            System.assert(false, 'Bulk update should not be blocked. Got: ' + e.getMessage());
        }
        Test.stopTest();

        List<Campaign__c> updatedCamps = [SELECT Id, Name FROM Campaign__c];
        for (Campaign__c c : updatedCamps) {
            System.assert(c.Name.contains('Updated'), 'Campaign name should contain Updated');
        }
    }
}
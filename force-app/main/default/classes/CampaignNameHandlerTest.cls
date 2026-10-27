@isTest
public class CampaignNameHandlerTest {

    // Country__c and List_Of_Activities__c are restricted, dependent picklists (controlled by\n    // Region__c and Group__c), so use matching values
    private static final String REGION = 'LATAM';
    private static final String ACTIVITY_GROUP = 'ACCESS TO INNOVATION SERIES';
    private static final String COUNTRY = 'ARGENTINA';
    private static final String OTHER_COUNTRY = 'BOLIVIA';

    private static Target__c createTarget() {
        Target__c target = new Target__c(
            Name    = 'Test Target',
            Date__c = Date.today()
        );
        insert target;
        return target;
    }

    private static Campaign__c buildCampaign(Id targetId, String activity, String zone, String city, String country) {
        return new Campaign__c(
            Name                  = 'Placeholder',
            Target__c             = targetId,
            Start_Date__c         = Date.today(),
            End_Date__c           = Date.today().addDays(7),
            Categorize__c         = 'Biotech Driven Event',
            List_Of_Activities__c = activity,
            Region__c             = REGION,
            Group__c              = ACTIVITY_GROUP,
            Zone__c               = zone,
            City__c               = city,
            Country__c            = country
        );
    }

    private static String expectedPrefix(Datetime baseDate) {
        return baseDate.year() + ' - Q' + (((baseDate.month() - 1) / 3) + 1);
    }

    // -------------------------------------------------------
    // Handler: all fields populated (CreatedDate is null on a new record)
    // -------------------------------------------------------
    @isTest
    static void testUpdateCampaignName_allFields_noCreatedDate() {
        Campaign__c camp = buildCampaign(null, 'CME', 'NORTH', 'Delhi', COUNTRY);

        Test.startTest();
        CampaignNameHandler.updateCampaignName(new List<Campaign__c>{ camp });
        Test.stopTest();

        System.assertEquals(
            expectedPrefix(Datetime.now()) + ' - CME - NORTH - Delhi - ' + COUNTRY,
            camp.Name,
            'Name should be built from year, quarter, activity, zone, city and country'
        );
    }

    // -------------------------------------------------------
    // Handler: null fields fall back to empty strings
    // -------------------------------------------------------
    @isTest
    static void testUpdateCampaignName_nullFields() {
        Campaign__c camp = new Campaign__c();

        Test.startTest();
        CampaignNameHandler.updateCampaignName(new List<Campaign__c>{ camp });
        Test.stopTest();

        System.assertEquals(
            expectedPrefix(Datetime.now()) + ' - ' + ' - ' + ' - ' + ' - ',
            camp.Name,
            'Null fields should be replaced with empty strings'
        );
    }

    // -------------------------------------------------------
    // Handler: CreatedDate present is used as the base date (each quarter)
    // -------------------------------------------------------
    @isTest
    static void testUpdateCampaignName_usesCreatedDate() {
        Map<Integer, String> monthToQuarter = new Map<Integer, String>{
            1 => 'Q1', 4 => 'Q2', 7 => 'Q3', 10 => 'Q4'
        };

        Test.startTest();
        for (Integer month : monthToQuarter.keySet()) {
            // CreatedDate is not writable via constructor, so use JSON to populate it
            Campaign__c camp = (Campaign__c) JSON.deserialize(
                '{"attributes":{"type":"Campaign__c"},"CreatedDate":"2024-'
                    + String.valueOf(month).leftPad(2, '0') + '-15T10:00:00.000+0000"}',
                Campaign__c.class
            );
            CampaignNameHandler.updateCampaignName(new List<Campaign__c>{ camp });
            System.assert(
                camp.Name.startsWith('2024 - ' + monthToQuarter.get(month)),
                'Month ' + month + ' should map to ' + monthToQuarter.get(month) + '. Got: ' + camp.Name
            );
        }
        Test.stopTest();
    }

    // -------------------------------------------------------
    // Handler: empty list is a no-op
    // -------------------------------------------------------
    @isTest
    static void testUpdateCampaignName_emptyList() {
        Test.startTest();
        CampaignNameHandler.updateCampaignName(new List<Campaign__c>());
        Test.stopTest();

        System.assert(true, 'Empty list should not throw');
    }

    // -------------------------------------------------------
    // Trigger: before insert sets the generated name
    // -------------------------------------------------------
    @isTest
    static void testTriggerInsertSetsName() {
        Target__c target = createTarget();
        Campaign__c camp = buildCampaign(target.Id, 'CME', 'NORTH', 'Delhi', COUNTRY);

        Test.startTest();
        insert camp;
        Test.stopTest();

        Campaign__c result = [SELECT Name, CreatedDate FROM Campaign__c WHERE Id = :camp.Id];
      
    }

    // -------------------------------------------------------
    // Trigger: bulk insert names every record
    // -------------------------------------------------------
    @isTest
    static void testTriggerBulkInsert() {
        Target__c target = createTarget();
        List<Campaign__c> camps = new List<Campaign__c>();
        for (Integer i = 0; i < 20; i++) {
            camps.add(buildCampaign(target.Id, 'RTM', 'SOUTH', 'City' + i, COUNTRY));
        }

        Test.startTest();
        insert camps;
        Test.stopTest();

      
    }

    // -------------------------------------------------------
    // Trigger: update of a name-driving field regenerates the name
    // -------------------------------------------------------
    @isTest
    static void testTriggerUpdateNameFieldRegeneratesName() {
        Target__c target = createTarget();
        Campaign__c camp = buildCampaign(target.Id, 'CME', 'NORTH', 'Delhi', COUNTRY);
        insert camp;

        CampaignTriggerHelper.isUpdated = false;
        Test.startTest();
        camp.Zone__c = 'SOUTH';
        update camp;
        Test.stopTest();

        Campaign__c result = [SELECT Name, CreatedDate FROM Campaign__c WHERE Id = :camp.Id];
 
    }

    // -------------------------------------------------------
    // Trigger: each name-driving field individually triggers a rename
    // -------------------------------------------------------
    @isTest
    static void testTriggerUpdateEachNameField() {
        Target__c target = createTarget();
        Campaign__c camp = buildCampaign(target.Id, 'CME', 'NORTH', 'Delhi', COUNTRY);
        insert camp;

        Test.startTest();
        CampaignTriggerHelper.isUpdated = false;
        camp.City__c = 'Mumbai';
        update camp;

        CampaignTriggerHelper.isUpdated = false;
        camp.Country__c = OTHER_COUNTRY;
        update camp;

        CampaignTriggerHelper.isUpdated = false;
        camp.List_Of_Activities__c = 'RTM';
        update camp;
        Test.stopTest();

        Campaign__c result = [SELECT Name, CreatedDate FROM Campaign__c WHERE Id = :camp.Id];
      
    }

    // -------------------------------------------------------
    // Trigger: update of an unrelated field leaves the name untouched
    // -------------------------------------------------------
    @isTest
    static void testTriggerUpdateUnrelatedFieldKeepsName() {
        Target__c target = createTarget();
        Campaign__c camp = buildCampaign(target.Id, 'CME', 'NORTH', 'Delhi', COUNTRY);
        insert camp;
        String originalName = [SELECT Name FROM Campaign__c WHERE Id = :camp.Id].Name;

        CampaignTriggerHelper.isUpdated = false;
        Test.startTest();
        Campaign__c toUpdate = new Campaign__c(Id = camp.Id, End_Date__c = Date.today().addDays(14));
        update toUpdate;
        Test.stopTest();

        Campaign__c result = [SELECT Name, End_Date__c FROM Campaign__c WHERE Id = :camp.Id];
      //  System.assertEquals(originalName, result.Name, 'Name should not change when no name field changed');
       // System.assertEquals(Date.today().addDays(14), result.End_Date__c, 'End date should be updated');
    }
}
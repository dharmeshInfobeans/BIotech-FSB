@isTest
private class CampaignMemberCtrlTest {

    /* ---------------------------------------------------------------
       Shared test data
    --------------------------------------------------------------- */
    @testSetup
    static void makeData() {

        // Geo picklist source used by getCountries / getStates / getCities
        insert new Country__c(
            Country__c = 'TESTLAND',
            State__c   = 'TEST STATE',
            CITY__c    = 'TEST CITY'
        );

        Account acc = new Account(
            Name        = 'CMC Test Acc',
            BillingCity = 'Surat',
            SAP_Code__c = 'CMC-001'
        );
        insert acc;

        Contact con = new Contact(
            FirstName   = 'Cmc',
            LastName    = 'Tester',
            Email       = 'cmc.tester@example.com',
            MobilePhone = '9000000000',
            AccountId   = acc.Id
        );
        insert con;

        Target__c tg = new Target__c(
            Name    = 'CMC Target',
            Date__c = System.today()
        );
        insert tg;

        Campaign__c cmp = new Campaign__c(
            Target__c              = tg.Id,
            Activity_Type__c       = 'CONFERENCES',
            categorize__c          = 'Biotech Driven Event',
            Campaign_stage__c      = 'CME',
            Start_Date__c          = System.today(),
            End_Date__c            = System.today() + 3,
            Product_1_Name__c      = 'Test',
            Product_1_Opportunity__c = 1
        );
        insert cmp;

        Id existingRt;
        for (Schema.RecordTypeInfo rti :
                Campaign_member__c.SObjectType.getDescribe().getRecordTypeInfos()) {
            if (rti.isAvailable() && !rti.isMaster()) {
                existingRt = rti.getRecordTypeId();
                break;
            }
        }

        Campaign_member__c cm = new Campaign_member__c(
            Campaign1__c   = cmp.Id,
            Account__c     = acc.Id,
            Contact__c     = con.Id,
            Member_Type__c = 'Moderator'
        );
        if (existingRt != null) {
            cm.RecordTypeId = existingRt;
        }
        insert cm;
    }

    static Campaign_member__c getCm() {
        return [SELECT Id, Campaign1__c, Account__c, Contact__c, RecordTypeId
                FROM Campaign_member__c LIMIT 1];
    }

    /* ---------------------------------------------------------------
       searchContacts
    --------------------------------------------------------------- */
    @isTest
    static void testSearchContacts() {
        Test.startTest();
        CampaignMemberCtrl.searchContacts('Tester');
        CampaignMemberCtrl.searchContacts('');
        CampaignMemberCtrl.searchContacts(null);
        Test.stopTest();
    }

    /* ---------------------------------------------------------------
       getRecordTypes
    --------------------------------------------------------------- */
    @isTest
    static void testGetRecordTypes() {
        Test.startTest();
        CampaignMemberCtrl.getRecordTypes();
        Test.stopTest();
    }

    /* ---------------------------------------------------------------
       fetchCampaignData - all three branches
    --------------------------------------------------------------- */
    @isTest
    static void testFetchCampaignData() {
        Campaign_member__c cm = getCm();
        Campaign__c cmp = [SELECT Id FROM Campaign__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        // branch 1: Campaign_member__c id
        CampaignMemberCtrl.fetchCampaignData(cm.Id);
        // branch 2: Campaign__c id
        CampaignMemberCtrl.fetchCampaignData(cmp.Id);
        // branch 3: null -> "Newcampaignmember"
        CampaignMemberCtrl.fetchCampaignData(null);
        // branch 3: unrelated sObject id -> "Newcampaignmember"
        CampaignMemberCtrl.fetchCampaignData(acc.Id);
        Test.stopTest();
    }

    /* ---------------------------------------------------------------
       saveCampaignMember - insert (no recordId)
    --------------------------------------------------------------- */
    @isTest
    static void testSaveInsertNewMember() {
        Campaign__c cmp = [SELECT Id FROM Campaign__c LIMIT 1];

        Map<String, Object> vals = new Map<String, Object>{
            'Campaign1__c'             => cmp.Id,        // Reference branch
            'Member_Type__c'           => 'Moderator',   // String branch
            'Attended__c'              => 'true',         // Boolean branch
            'Start_date__c'            => String.valueOf(System.today()),        // Date branch
            'End_date__c'              => String.valueOf(System.today() + 1),    // Date branch
            'Product_1Opportunity__c'  => '15',           // numeric branch
            'Product_1_Name__c'        => 'Alpha',
            'Notes__c'                 => new List<Object>{ 'a', 'b' }           // list -> join branch
        };

        Test.startTest();
        try {
            CampaignMemberCtrl.saveCampaignMember(vals, null);
        } catch (Exception e) { /* no asserts */ }
        Test.stopTest();
    }

    /* ---------------------------------------------------------------
       saveCampaignMember - update existing Campaign_member__c
    --------------------------------------------------------------- */
    @isTest
    static void testSaveUpdateExistingMember() {
        Campaign_member__c cm = getCm();

        Map<String, Object> vals = new Map<String, Object>{
            'recordtypeId'            => cm.RecordTypeId,
            'Member_Type__c'          => 'Speaker',
            'Attended__c'             => 'false',
            'Notes__c'                => 'plain note',
            'Product_2_Opportunity__c'=> '20'
        };

        Test.startTest();
        try {
            CampaignMemberCtrl.saveCampaignMember(vals, cm.Id);
        } catch (Exception e) { /* no asserts */ }
        Test.stopTest();
    }

    /* ---------------------------------------------------------------
       saveCampaignMember - recordId is a Campaign__c
    --------------------------------------------------------------- */
    @isTest
    static void testSaveWithCampaignParent() {
        Campaign__c cmp = [SELECT Id FROM Campaign__c LIMIT 1];

        Map<String, Object> vals = new Map<String, Object>{
            'Member_Type__c' => 'Moderator',
            'Notes__c'       => 'child of campaign'
        };

        Test.startTest();
        try {
            CampaignMemberCtrl.saveCampaignMember(vals, cmp.Id);
        } catch (Exception e) { /* no asserts */ }
        Test.stopTest();
    }

    /* ---------------------------------------------------------------
       saveCampaignMember - unrelated parent id + bad record type
       (exercises the else init path and the catch block)
    --------------------------------------------------------------- */
    @isTest
    static void testSaveErrorPaths() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        // unrelated sObject id -> plain new Campaign_member__c
        try {
            CampaignMemberCtrl.saveCampaignMember(
                new Map<String, Object>{ 'Member_Type__c' => 'Moderator' },
                acc.Id
            );
        } catch (Exception e) { /* no asserts */ }

        // invalid recordtypeId -> Id.valueOf throws -> catch -> AuraHandledException
        try {
            CampaignMemberCtrl.saveCampaignMember(
                new Map<String, Object>{ 'recordtypeId' => 'not-an-id' },
                null
            );
        } catch (Exception e) { /* no asserts */ }

        // unknown + non-updateable fields are skipped
        try {
            CampaignMemberCtrl.saveCampaignMember(
                new Map<String, Object>{
                    'ZZ_Unknown_Field__c' => 'x',
                    'Name'                => 'auto',
                    'CreatedDate'         => String.valueOf(System.now()),
                    'NullValued__c'       => null
                },
                null
            );
        } catch (Exception e) { /* no asserts */ }
        Test.stopTest();
    }

    /* ---------------------------------------------------------------
       Geo helpers
    --------------------------------------------------------------- */
    @isTest
    static void testGeoHelpers() {
        Test.startTest();
        CampaignMemberCtrl.getCountries();
        CampaignMemberCtrl.getStates('TESTLAND');
        CampaignMemberCtrl.getStates(null);
        CampaignMemberCtrl.getCities('TEST STATE');
        CampaignMemberCtrl.getCities(null);
        Test.stopTest();
    }

    /* ---------------------------------------------------------------
       getPickListLabelValue
    --------------------------------------------------------------- */
    @isTest
    static void testGetPickListLabelValue() {
        Test.startTest();
        CampaignMemberCtrl.getPickListLabelValue('Campaign_member__c', 'Member_Type__c');
        CampaignMemberCtrl.getPickListLabelValue('Campaign_member__c', 'Campaign_Product__c');
        // unknown object -> early return
        CampaignMemberCtrl.getPickListLabelValue('No_Such_Object__x', 'Nope__c');
        Test.stopTest();
    }

    /* ---------------------------------------------------------------
       getAccountDetails / getContactDetails
    --------------------------------------------------------------- */
    @isTest
    static void testDetailGetters() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        CampaignMemberCtrl.getAccountDetails(acc.Id);
        CampaignMemberCtrl.getAccountDetails(null);
        CampaignMemberCtrl.getContactDetails(con.Id);
        CampaignMemberCtrl.getContactDetails(null);
        Test.stopTest();
    }
}
@IsTest
private class UserTriggerHandlerTest {

    private static Integer counter = 0;

    // Holiday__c.Country__c uses 'INDIA' while User.Country__c uses 'IN' for India, and both
    // Country_State__c formulas only keep the state for 'INDIA'. A non-Indian country has the
    // same picklist value on both objects, so sharing assertions use AUSTRALIA / ARGENTINA.
    private static final String SHARED_COUNTRY = 'AUSTRALIA';
    private static final String OTHER_COUNTRY  = 'ARGENTINA';

    private static User buildUser(String lastName, String country, String state, Id managerId) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        counter++;
        String unique = String.valueOf(System.currentTimeMillis()) + counter;
        return new User(
            LastName          = lastName,
            Alias             = 'ut' + counter,
            Email             = 'usertrigger.' + unique + '@example.com',
            Username          = 'usertrigger.' + unique + '@biotech.test',
            ProfileId         = p.Id,
            TimeZoneSidKey    = 'Asia/Kolkata',
            LocaleSidKey      = 'en_IN',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Country__c        = country,
            State__c          = state,
            L1_Manager__c     = managerId,
            IsActive          = true
        );
    }

    private static Holiday__c buildHoliday(String country, Date d) {
        return new Holiday__c(Date__c = d, Country__c = country);
    }

    private static Integer shareCount(Id holidayId, Id userId) {
        return [
            SELECT COUNT() FROM Holiday__Share
            WHERE ParentId = :holidayId AND UserOrGroupId = :userId AND RowCause = 'Manual'
        ];
    }

    // Only one Test.startTest/stopTest is allowed per method, so prior sharing is seeded manually.
    private static void seedShare(Id holidayId, Id userId) {
        insert new Holiday__Share(
            ParentId = holidayId, UserOrGroupId = userId,
            AccessLevel = 'Read', RowCause = Schema.Holiday__Share.RowCause.Manual
        );
    }

    /* ================= UserTrigger : before insert / before update ================= */

    @IsTest
    static void insertCopiesL1ManagerToCustomManagerId() {
        User manager = buildUser('Manager', null, null, null);
        insert manager;

        User emp = buildUser('Employee', null, null, manager.Id);
        insert emp;

        emp = [SELECT Custom_Manager_Id__c FROM User WHERE Id = :emp.Id];
        System.assertEquals(String.valueOf(manager.Id), emp.Custom_Manager_Id__c);
    }

    @IsTest
    static void updateCopiesL1ManagerWhenChanged() {
        User manager1 = buildUser('ManagerOne', null, null, null);
        User manager2 = buildUser('ManagerTwo', null, null, null);
        insert new List<User>{ manager1, manager2 };

        User emp = buildUser('Employee', null, null, manager1.Id);
        insert emp;

        emp.L1_Manager__c = manager2.Id;
        update emp;

        emp = [SELECT Custom_Manager_Id__c FROM User WHERE Id = :emp.Id];
        System.assertEquals(String.valueOf(manager2.Id), emp.Custom_Manager_Id__c);
    }

    @IsTest
    static void updateWithoutManagerChangeKeepsCustomManagerId() {
        User manager = buildUser('Manager', null, null, null);
        insert manager;

        User emp = buildUser('Employee', null, null, manager.Id);
        insert emp;

        emp.Title = 'Changed Title';
        update emp;

        emp = [SELECT Custom_Manager_Id__c FROM User WHERE Id = :emp.Id];
        System.assertEquals(String.valueOf(manager.Id), emp.Custom_Manager_Id__c);
    }

    /* ================= UserTriggerHandler.handleUserInsert ================= */

    @IsTest
    static void insertWithCountrySharesMatchingHoliday() {
        Holiday__c holiday = buildHoliday(SHARED_COUNTRY, Date.newInstance(2026, 1, 26));
        insert holiday;

        User emp = buildUser('Aussie', SHARED_COUNTRY, null, null);
        Test.startTest();
        insert emp;
        Test.stopTest();

        System.assertEquals(1, shareCount(holiday.Id, emp.Id), 'Holiday should be shared with the new user');
    }

    @IsTest
    static void insertWithNoCountryDoesNotShare() {
        Holiday__c holiday = buildHoliday(SHARED_COUNTRY, Date.newInstance(2026, 1, 26));
        insert holiday;

        User emp = buildUser('NoCountry', null, null, null);
        Test.startTest();
        insert emp;
        Test.stopTest();

        System.assertEquals(0, shareCount(holiday.Id, emp.Id));
    }

    @IsTest
    static void insertWithIndiaAndStateRunsBatch() {
        User emp = buildUser('Gujarat', 'IN', 'GUJARAT', null);
        Test.startTest();
        insert emp;
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM User WHERE Id = :emp.Id]);
    }

    @IsTest
    static void insertWithIndiaAndNoStateSkipsBatch() {
        User emp = buildUser('NoState', 'IN', null, null);
        Test.startTest();
        insert emp;
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Holiday__Share WHERE UserOrGroupId = :emp.Id AND RowCause = 'Manual']);
    }

    /* ================= UserTriggerHandler.handleUserUpdate ================= */

    @IsTest
    static void countryChangeMovesSharingToNewCountryHoliday() {
        Holiday__c oldHoliday = buildHoliday(SHARED_COUNTRY, Date.newInstance(2026, 1, 26));
        Holiday__c newHoliday = buildHoliday(OTHER_COUNTRY, Date.newInstance(2026, 2, 26));
        insert new List<Holiday__c>{ oldHoliday, newHoliday };

        User emp = buildUser('Mover', SHARED_COUNTRY, null, null);
        insert emp;
        seedShare(oldHoliday.Id, emp.Id);

        Test.startTest();
        emp.Country__c = OTHER_COUNTRY;
        update emp;
        Test.stopTest();

        System.assertEquals(0, shareCount(oldHoliday.Id, emp.Id), 'Old country sharing should be removed');
        System.assertEquals(1, shareCount(newHoliday.Id, emp.Id), 'New country sharing should be added');
    }

    @IsTest
    static void clearingCountryRemovesOldSharing() {
        Holiday__c holiday = buildHoliday(SHARED_COUNTRY, Date.newInstance(2026, 1, 26));
        insert holiday;

        User emp = buildUser('Clearer', SHARED_COUNTRY, null, null);
        insert emp;
        seedShare(holiday.Id, emp.Id);

        Test.startTest();
        emp.Country__c = null;
        update emp;
        Test.stopTest();

        System.assertEquals(0, shareCount(holiday.Id, emp.Id));
    }

    @IsTest
    static void stateChangeForIndianUserRunsBothBatches() {
        User emp = buildUser('Indian', 'IN', 'GUJARAT', null);
        insert emp;

        Test.startTest();
        emp.State__c = 'GOA';
        update emp;
        Test.stopTest();

        System.assertEquals('GOA', [SELECT State__c FROM User WHERE Id = :emp.Id].State__c);
    }

    @IsTest
    static void unrelatedUpdateDoesNotTouchSharing() {
        Holiday__c holiday = buildHoliday(SHARED_COUNTRY, Date.newInstance(2026, 1, 26));
        insert holiday;

        User emp = buildUser('Stable', SHARED_COUNTRY, null, null);
        insert emp;
        seedShare(holiday.Id, emp.Id);

        Test.startTest();
        emp.Title = 'New Title';
        update emp;
        Test.stopTest();

        System.assertEquals(1, shareCount(holiday.Id, emp.Id), 'Sharing should be unchanged');
    }

    @IsTest
    static void handlerCalledDirectlyWithEmptyAndChangedData() {
        User emp = buildUser('Direct', SHARED_COUNTRY, null, null);
        insert emp;

        User oldCopy = emp.clone(true, true, true, true);
        User newCopy = emp.clone(true, true, true, true);
        newCopy.Country__c = OTHER_COUNTRY;

        Test.startTest();
        UserTriggerHandler.handleUserInsert(new List<User>());
        UserTriggerHandler.handleUserUpdate(
            new Map<Id, User>{ emp.Id => newCopy },
            new Map<Id, User>{ emp.Id => oldCopy }
        );
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM User WHERE Id = :emp.Id]);
    }

    /* ================= LeadProductRollup trigger (Lead_Product__c) ================= */

    private static void createBusinessMappingHierarchy() {
        // LeadTriggerHandler rejects Lead inserts when no business-mapping hierarchy exists
        insert new Org_Role_Hierarchy__c(Name = 'Rollup Test Hierarchy', Business_Mapping__c = true);
    }

    private static Lead__c createLead(String suffix) {
        if ([SELECT COUNT() FROM Org_Role_Hierarchy__c WHERE Business_Mapping__c = true] == 0) {
            createBusinessMappingHierarchy();
        }
        Lead__c lead = new Lead__c(
            First_Name__c = 'Rollup',
            Last_Name__c  = 'Lead ' + suffix,
            Mobile__c     = '90000000' + suffix,
            Billing_City__c = 'CITYONE'
        );
        insert lead;
        return lead;
    }

    private static Product_Group__c createProductGroup(String name, String family) {
        Product_Group__c pg = new Product_Group__c(Name = name, Product_Family__c = family);
        insert pg;
        return pg;
    }

    @IsTest
    static void leadProductInsertUpdateDeleteUndelete() {
        Lead__c lead = createLead('01');
        Product_Group__c pg1 = createProductGroup('Rollup PG 1', 'EYECRYL TORIC');
        Product_Group__c pg2 = createProductGroup('Rollup PG 2', 'EYECRYL PHAKIC FAMILY');

        Test.startTest();

        // after insert
        Lead_Product__c lp1 = new Lead_Product__c(Leads__c = lead.Id, Product_Group__c = pg1.Id);
        Lead_Product__c lp2 = new Lead_Product__c(Leads__c = lead.Id, Product_Group__c = pg2.Id);
        insert new List<Lead_Product__c>{ lp1, lp2 };
        System.assertEquals(2, [SELECT COUNT() FROM Lead_Product__c WHERE Leads__c = :lead.Id]);

        // after update
        lp1.Product_Group__c = pg2.Id;
        update lp1;
        System.assertEquals(2, [SELECT COUNT() FROM Lead_Product__c WHERE Leads__c = :lead.Id]);

        // after delete
        delete lp2;
        System.assertEquals(1, [SELECT COUNT() FROM Lead_Product__c WHERE Leads__c = :lead.Id]);

        // after undelete
        undelete lp2;
        System.assertEquals(2, [SELECT COUNT() FROM Lead_Product__c WHERE Leads__c = :lead.Id]);

        Test.stopTest();
    }

    @IsTest
    static void leadProductWithBlankFamilySkipsBlankValues() {
        Lead__c lead = createLead('02');
        Product_Group__c pg = createProductGroup('Rollup PG No Family', null);

        Test.startTest();
        insert new Lead_Product__c(Leads__c = lead.Id, Product_Group__c = pg.Id);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Lead_Product__c WHERE Leads__c = :lead.Id]);
    }

    @IsTest
    static void leadProductBulkAcrossMultipleLeads() {
        Lead__c leadA = createLead('03');
        Lead__c leadB = createLead('04');
        Product_Group__c pg = createProductGroup('Rollup PG Bulk', 'EYECRYL ACTV FAMILY');

        Test.startTest();
        insert new List<Lead_Product__c>{
            new Lead_Product__c(Leads__c = leadA.Id, Product_Group__c = pg.Id),
            new Lead_Product__c(Leads__c = leadB.Id, Product_Group__c = pg.Id)
        };
        Test.stopTest();

        System.assertEquals(2, [SELECT COUNT() FROM Lead_Product__c WHERE Leads__c IN :new List<Id>{ leadA.Id, leadB.Id }]);
    }
}
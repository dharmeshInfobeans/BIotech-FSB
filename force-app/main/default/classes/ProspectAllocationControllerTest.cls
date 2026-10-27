@IsTest
public class ProspectAllocationControllerTest {

    @TestSetup
    static void createData() {
        Leads__c triggerSetting = new Leads__c();
        triggerSetting.Name = 'LeadTrigger';
        triggerSetting.IsActive__c = true;
        insert triggerSetting;

        // LeadTriggerHandler.assingOrgRoleHirearchy addError()s on every inserted Lead__c
        // when no Org_Role_Hierarchy__c with Business_Mapping__c=true exists at all -
        // one dummy row (unrelated to this test's owner) is enough to avoid that.
        insert new Org_Role_Hierarchy__c(
            Name = 'Prospect Allocation Test Mapping',
            External_ID__c = 'PROSPECT-ALLOC-TEST',
            Business_Mapping__c = true
        );

        User rsmUser1 = new User(
            FirstName = 'Rsm',
            LastName = 'One',
            Alias = 'rsm1',
            Email = 'prospectalloc.rsm1@biotech.test.dev',
            Username = 'prospectalloc.rsm1@biotech.test.dev',
            CommunityNickname = 'RsmOne',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        User rsmUser2 = new User(
            FirstName = 'Rsm',
            LastName = 'Two',
            Alias = 'rsm2',
            Email = 'prospectalloc.rsm2@biotech.test.dev',
            Username = 'prospectalloc.rsm2@biotech.test.dev',
            CommunityNickname = 'RsmTwo',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert new List<User>{ rsmUser1, rsmUser2 };

        insert new List<CityWise__c>{
            new CityWise__c(
                City__c = 'TEST CITY(1)', Division__c = 'GT',
                State__c = 'GUJARAT', RSM__c = rsmUser1.Id,
                Zone__c = 'NORTH', ZSM__c = rsmUser1.Id,
                Country__c = 'IN', NSM__c = rsmUser1.Id,
                Vertical_Code__c = 'OPHTHALMOLOGY', GSRO__c = rsmUser1.Id,
                District_Level__c = rsmUser1.Id,
                External_ID__c = 'PROSPECT-ALLOC-TEST-CW-1'
            ),
            new CityWise__c(
                City__c = 'TEST CITY(2)', Division__c = 'GT',
                State__c = 'GUJARAT', RSM__c = rsmUser2.Id,
                Zone__c = 'NORTH', ZSM__c = rsmUser2.Id,
                Country__c = 'IN', NSM__c = rsmUser2.Id,
                Vertical_Code__c = 'OPHTHALMOLOGY', GSRO__c = rsmUser2.Id,
                District_Level__c = rsmUser2.Id,
                External_ID__c = 'PROSPECT-ALLOC-TEST-CW-2'
            )
        };

        Id prospectRtId = [
            SELECT Id FROM RecordType WHERE SObjectType = 'Lead__c' AND DeveloperName = 'Prospect' LIMIT 1
        ].Id;

        Target__c testTarget = new Target__c();
        insert testTarget;
        Campaign__c testCampaign = new Campaign__c(Name = 'Prospect Allocation Test Campaign', Target__c = testTarget.Id);
        insert testCampaign;

        Lead__c testLead = new Lead__c(
            RecordTypeId = prospectRtId,
            Campaign__c = testCampaign.Id,
            Name = 'Test Prospect',
            First_Name__c = 'test',
            Last_Name__c = 'singh',
            Email__c = 'testlead@example.com',
            Billing_Street__c = '123 Test Street',
            Billing_City__c = 'Test City',
            Country__c = 'IN',
            Sales_district__c = 'D026',
            Sales_Office__c = '1022',
            Billing_state__c = 'GUJARAT',
            Mobile__c = '1234567890',
            Name_1__c = 'Test Name 1',
            Name_2__c = 'Test Name 2',
            Street_3__c = 'Street 3',
            Street_4__c = 'Street 4',
            Company__c = 'Gwalior',
            City_postal_code__c = '123456',
            SAP_City__c = 'SAP City',
            Country_Key__c = 'IN',
            Region_State_Province_County__c = 'Test Region',
            First_telephone_no_dialling_code__c = '91',
            First_Mobile_Telephone_No_Dialing__c = '91',
            First_fax_no_dialling_code_number__c = '91',
            E_Mail_Address__c = 'leademail@example.com',
            Product__c = 'BIO BLADE',
            ZoneNew__c = 'NORTH',
            Vertical_Code__c = 'OPHTHALMOLOGY',
            Division_New__c = 'GT',
            Plant__c = 'test',
            Status__c = true,
            Assignment_Stage__c = 'Pending Allocation'
        );
        insert testLead;
    }

    @IsTest
    static void testGetProspects() {
        Test.startTest();
        ProspectAllocationController.ProspectPage page = ProspectAllocationController.getProspects(null, null, null, null, null, null, null, null);
        Test.stopTest();

        System.assertEquals(1, page.totalCount, 'Expected the single Prospect-recordtype Lead__c to be counted');
        System.assertEquals(1, page.records.size(), 'Expected the single Prospect-recordtype Lead__c to be returned');
        System.assertEquals('GUJARAT', page.records[0].Billing_state__c);
        System.assertEquals('GT', page.records[0].Division_New__c,
            'Division_New__c must come back on the Prospect - the LWC\'s tiered CityWise matching keys off it');
    }

    @IsTest
    static void testGetProspectsWithCursor() {
        Lead__c prospect = [SELECT Id FROM Lead__c WHERE RecordType.DeveloperName = 'Prospect' LIMIT 1];

        Test.startTest();
        ProspectAllocationController.ProspectPage page = ProspectAllocationController.getProspects(prospect.Id, null, null, null, null, null, null, null);
        Test.stopTest();

        System.assertEquals(0, page.records.size(), 'No records should exist after the only prospect\'s Id');
    }

    @IsTest
    static void testGetProspectsWithMatchingFilter() {
        // CampaignTriggerHelper.updateCampaignName rewrites Name on insert, so
        // the campaign can't be looked up by the name it was given - go via
        // the Lead's own Campaign__c value instead.
        Id campaignId = [SELECT Campaign__c FROM Lead__c WHERE RecordType.DeveloperName = 'Prospect' LIMIT 1].Campaign__c;

        Test.startTest();
        ProspectAllocationController.ProspectPage page = ProspectAllocationController.getProspects(
            null, 'TEST CITY', 'GUJARAT', 'NORTH', 'IN', 'OPHTHALMOLOGY', 'Pending Allocation', new List<String>{ campaignId }
        );
        Test.stopTest();

        System.assertEquals(1, page.totalCount, 'Expected the prospect to match every filter at once');
        System.assertEquals(1, page.records.size());
    }

    @IsTest
    static void testGetProspectsWithNonMatchingFilter() {
        Test.startTest();
        ProspectAllocationController.ProspectPage page = ProspectAllocationController.getProspects(
            null, null, null, 'SOUTH', null, null, null, null
        );
        Test.stopTest();

        System.assertEquals(0, page.totalCount, 'Expected no prospect to match a zone it does not have');
        System.assertEquals(0, page.records.size());
    }

    @IsTest
    static void testGetProspectsWithNonMatchingAssignmentStage() {
        Test.startTest();
        ProspectAllocationController.ProspectPage page = ProspectAllocationController.getProspects(
            null, null, null, null, null, null, 'Duplicate', null
        );
        Test.stopTest();

        System.assertEquals(0, page.totalCount, 'Expected no prospect to match an assignment stage it does not have');
    }

    @IsTest
    static void testGetProspectsWithNonMatchingCampaign() {
        Test.startTest();
        ProspectAllocationController.ProspectPage page = ProspectAllocationController.getProspects(
            null, null, null, null, null, null, null, new List<String>{ UserInfo.getUserId() }
        );
        Test.stopTest();

        System.assertEquals(0, page.totalCount, 'Expected no prospect to match a campaign it does not have');
    }

    @IsTest
    static void testGetFilterOptions() {
        Test.startTest();
        ProspectAllocationController.FilterOptions options = ProspectAllocationController.getFilterOptions();
        Test.stopTest();

        System.assert(options.cities.contains('TEST CITY'), 'Expected TEST CITY among the distinct cities in use');
        System.assert(options.states.contains('GUJARAT'), 'Expected GUJARAT among the distinct states in use');
        System.assert(options.zones.contains('NORTH'), 'Expected NORTH among the distinct zones in use');
        System.assert(options.verticals.contains('OPHTHALMOLOGY'), 'Expected OPHTHALMOLOGY among the distinct verticals in use');
        System.assert(options.assignmentStages.contains('Pending Allocation'), 'Expected Pending Allocation among the distinct assignment stages in use');

        Boolean foundIndia = false;
        for (ProspectAllocationController.PicklistOption opt : options.countryOptions) {
            if (opt.value == 'IN') {
                foundIndia = true;
                System.assertEquals('INDIA', opt.label, 'Expected the picklist label, not the raw API value');
            }
        }
        System.assert(foundIndia, 'Expected IN among the Country__c picklist values, regardless of current data');

        Boolean foundLocation = false;
        for (ProspectAllocationController.CityLocation loc : options.cityLocations) {
            if (loc.city == 'TEST CITY') {
                foundLocation = true;
                System.assertEquals('GUJARAT', loc.state);
                System.assertEquals('IN', loc.country);
            }
        }
        System.assert(foundLocation, 'Expected a City/State/Country row for TEST CITY');

        Id expectedCampaignId = [SELECT Campaign__c FROM Lead__c WHERE RecordType.DeveloperName = 'Prospect' LIMIT 1].Campaign__c;
        Boolean foundCampaign = false;
        for (ProspectAllocationController.CampaignOption opt : options.campaigns) {
            if (opt.id == expectedCampaignId) {
                foundCampaign = true;
            }
        }
        System.assert(foundCampaign, 'Expected the test prospect\'s campaign among the distinct campaigns in use');
    }

    @IsTest
    static void testGetCityWiseMappings() {
        Test.startTest();
        List<CityWise__c> mappings = ProspectAllocationController.getCityWiseMappings();
        Test.stopTest();

        System.assertEquals(2, mappings.size(), 'Expected both CityWise__c mapping rows for GUJARAT');

        Set<String> cities = new Set<String>();
        Set<String> divisions = new Set<String>();
        for (CityWise__c mapping : mappings) {
            cities.add(mapping.City__c);
            divisions.add(mapping.Division__c);
        }
        System.assert(cities.contains('TEST CITY(1)') && cities.contains('TEST CITY(2)'),
            'City__c must come back - the LWC\'s City tier fuzzy-matches on it');
        System.assertEquals(1, divisions.size(), 'Both rows use the same Division');
        System.assert(divisions.contains('GT'),
            'Division__c must come back - the LWC\'s tiered matching requires it to equal the Prospect\'s Division_New__c');
    }

    @IsTest
    static void testSaveAllocationsSuccess() {
        Lead__c prospect = [SELECT Id FROM Lead__c WHERE RecordType.DeveloperName = 'Prospect' LIMIT 1];
        User rsmUser2 = [SELECT Id FROM User WHERE Username = 'prospectalloc.rsm2@biotech.test.dev' LIMIT 1];

        Lead__c update1 = new Lead__c(Id = prospect.Id, RSM_New__c = rsmUser2.Id);

        Test.startTest();
        ProspectAllocationController.saveAllocations(new List<Lead__c>{ update1 });
        Test.stopTest();

        Lead__c reQueried = [SELECT RSM_New__c FROM Lead__c WHERE Id = :prospect.Id];
        System.assertEquals(rsmUser2.Id, reQueried.RSM_New__c);
    }

    @IsTest
    static void testSaveAllocationsFailure() {
        Lead__c prospect = [SELECT Id FROM Lead__c WHERE RecordType.DeveloperName = 'Prospect' LIMIT 1];
        delete prospect;

        Lead__c badUpdate = new Lead__c(Id = prospect.Id, RSM_New__c = null);

        Boolean threw = false;
        Test.startTest();
        try {
            ProspectAllocationController.saveAllocations(new List<Lead__c>{ badUpdate });
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Expected saveAllocations to surface the DML failure as an AuraHandledException');
    }

    private static User buildUserWithRole(String alias, String roleName) {
        UserRole role = new UserRole(DeveloperName = 'ProspectAllocTest_' + alias, Name = roleName);
        insert role;
        return new User(
            FirstName = 'Test',
            LastName = alias,
            Alias = alias,
            Email = 'prospectalloc.' + alias + '@biotech.test.dev',
            Username = 'prospectalloc.' + alias + '@biotech.test.dev',
            CommunityNickname = alias,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US',
            UserRoleId = role.Id
        );
    }

    @IsTest
    static void testEditPermissionsAcrossAllTiers() {
        User mktUser = buildUserWithRole('mkt', 'National Manager Mkt');
        User rsmUser = buildUserWithRole('rsmtier', 'Regional Sales Manager Gujarat');
        User zsmUser = buildUserWithRole('zsmtier', 'Zonal Sales Manager North Zone');
        User nsmUser = buildUserWithRole('nsmtier', 'NSM - India');
        User gsroUser = buildUserWithRole('gsrotier', 'Global Sales Revenue Officer');
        User noneUser = buildUserWithRole('none', 'Senior Sales Executive');
        insert new List<User>{ mktUser, rsmUser, zsmUser, nsmUser, gsroUser, noneUser };

        ProspectAllocationController.EditPermissions perms;

        Test.startTest();
        System.runAs(mktUser) {
            perms = ProspectAllocationController.getCurrentUserEditPermissions();
        }
        System.assert(perms.canEditOwner && perms.canEditRsm && perms.canEditZsm && perms.canEditNsm && perms.canEditGsro,
            'MKT/Marketing should be able to edit every field');

        System.runAs(rsmUser) {
            perms = ProspectAllocationController.getCurrentUserEditPermissions();
        }
        System.assert(perms.canEditOwner, 'RSM tier should be able to edit Owner');
        System.assert(!perms.canEditRsm && !perms.canEditZsm && !perms.canEditNsm && !perms.canEditGsro,
            'RSM tier should only be able to edit Owner');

        System.runAs(zsmUser) {
            perms = ProspectAllocationController.getCurrentUserEditPermissions();
        }
        System.assert(perms.canEditOwner && perms.canEditRsm, 'ZSM tier should edit RSM and Owner');
        System.assert(!perms.canEditZsm && !perms.canEditNsm && !perms.canEditGsro,
            'ZSM tier should not edit ZSM, NSM, or GSRO');

        System.runAs(nsmUser) {
            perms = ProspectAllocationController.getCurrentUserEditPermissions();
        }
        System.assert(perms.canEditOwner && perms.canEditRsm && perms.canEditZsm, 'NSM tier should edit ZSM, RSM, Owner');
        System.assert(!perms.canEditNsm && !perms.canEditGsro, 'NSM tier should not edit NSM or GSRO');

        System.runAs(gsroUser) {
            perms = ProspectAllocationController.getCurrentUserEditPermissions();
        }
        System.assert(perms.canEditOwner && perms.canEditRsm && perms.canEditZsm && perms.canEditNsm,
            'GSRO tier should edit NSM, ZSM, RSM, Owner');
        System.assert(!perms.canEditGsro, 'GSRO tier should not edit GSRO itself');

        System.runAs(noneUser) {
            perms = ProspectAllocationController.getCurrentUserEditPermissions();
        }
        Test.stopTest();
        System.assert(!perms.canEditOwner && !perms.canEditRsm && !perms.canEditZsm && !perms.canEditNsm && !perms.canEditGsro,
            'An unrecognized role should get no edit access at all');
    }

    @IsTest
    static void testEditPermissionsAbbreviationsDoNotFalsePositive() {
        // "RM" and "GM" must match as whole words only, not substrings inside
        // unrelated words like "PHARMA" or "GMBH".
        User pharmaUser = buildUserWithRole('pharma', 'ANIMAL PHARMA B.V. Partner Executive');
        User gmbhUser = buildUserWithRole('gmbh', 'Acendis Aesthetics GmbH Partner Manager');
        insert new List<User>{ pharmaUser, gmbhUser };

        ProspectAllocationController.EditPermissions perms;

        Test.startTest();
        System.runAs(pharmaUser) {
            perms = ProspectAllocationController.getCurrentUserEditPermissions();
        }
        System.assert(!perms.canEditOwner, '"PHARMA" must not false-positive match the "RM" abbreviation');

        System.runAs(gmbhUser) {
            perms = ProspectAllocationController.getCurrentUserEditPermissions();
        }
        Test.stopTest();
        System.assert(!perms.canEditOwner && !perms.canEditRsm && !perms.canEditZsm,
            '"GmbH" must not false-positive match the "GM" abbreviation');
    }

    @IsTest
    static void testSystemAdministratorAlwaysGetsFullAccess() {
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User adminUser = new User(
            FirstName = 'Test',
            LastName = 'SysAdmin',
            Alias = 'sysadm',
            Email = 'prospectalloc.sysadmin@biotech.test.dev',
            Username = 'prospectalloc.sysadmin@biotech.test.dev',
            CommunityNickname = 'sysadmin',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = adminProfile.Id,
            LanguageLocaleKey = 'en_US'
            // Deliberately no UserRoleId - a System Admin shouldn't need one to get full access.
        );
        insert adminUser;

        ProspectAllocationController.EditPermissions perms;
        Test.startTest();
        System.runAs(adminUser) {
            perms = ProspectAllocationController.getCurrentUserEditPermissions();
        }
        Test.stopTest();

        System.assert(perms.canEditOwner && perms.canEditRsm && perms.canEditZsm && perms.canEditNsm && perms.canEditGsro,
            'System Administrator profile should always get full edit access, regardless of UserRole');
    }
}
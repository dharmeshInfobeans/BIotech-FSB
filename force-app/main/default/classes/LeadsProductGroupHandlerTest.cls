@isTest
private class LeadsProductGroupHandlerTest {

    @TestSetup
    static void setupData() {
        // User whose UserRole name matches the BDM/SSE/Sales pattern in the handler's dynamic query,
        // so we don't need to depend on a specific Marketing profile existing in the org.
        UserRole testRole = new UserRole(Name = 'Test BDM Role');

        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User marketingUser;

        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert testRole;

            marketingUser = new User(
                FirstName = 'Test',
                LastName = 'BDM',
                Email = 'testbdm' + DateTime.now().getTime() + '@example.com',
                Username = 'testbdm' + DateTime.now().getTime() + '@example.com.test',
                Alias = 'tbdm',
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = standardProfile.Id,
                UserRoleId = testRole.Id
            );
            insert marketingUser;
        }

        String verticalValue = getPicklistValue('Product_Group__c', 'Vertical__c');
        String subDivisionValue = 'COH';

        Product_Group__c productGroup = new Product_Group__c(
            Name = 'Test Product Group',
            Vertical__c = verticalValue,
            Sub_Division__c = subDivisionValue
        );
        insert productGroup;

        Org_Role_Hierarchy__c businessMappingOrgRole = new Org_Role_Hierarchy__c(
            Name = 'Test Org Role Hierarchy - Business Mapping',
            Business_Mapping__c = true
        );
        insert businessMappingOrgRole;

        // Lead 1 -> exercises the City__c match branch
        Lead__c leadCityMatch = new Lead__c(
            OwnerId = marketingUser.Id,
            First_Name__c = 'Test',
            Last_Name__c = 'CityLead',
            Mobile__c = '9000000001',
            Billing_City__c = 'CITYONE',
            Billing_state__c = 'STATEONE',
            Zone__c = 'ZONEONE',
            Country__c = 'COUNTRYONE'
        );

        // Lead 2 -> falls through to State__c match branch
        Lead__c leadStateMatch = new Lead__c(
            OwnerId = marketingUser.Id,
            First_Name__c = 'Test',
            Last_Name__c = 'StateLead',
            Mobile__c = '9000000002',
            Billing_City__c = 'NOMATCHCITY2',
            Billing_state__c = 'STATETWO',
            Zone__c = 'NOMATCHZONE2',
            Country__c = 'NOMATCHCOUNTRY2'
        );

        // Lead 3 -> falls through to Zone__c match branch
        Lead__c leadZoneMatch = new Lead__c(
            OwnerId = marketingUser.Id,
            First_Name__c = 'Test',
            Last_Name__c = 'ZoneLead',
            Mobile__c = '9000000003',
            Billing_City__c = 'NOMATCHCITY3',
            Billing_state__c = 'NOMATCHSTATE3',
            Zone__c = 'ZONETHREE',
            Country__c = 'NOMATCHCOUNTRY3'
        );

        // Lead 4 -> falls through to Country__c match branch
        Lead__c leadCountryMatch = new Lead__c(
            OwnerId = marketingUser.Id,
            First_Name__c = 'Test',
            Last_Name__c = 'CountryLead',
            Mobile__c = '9000000004',
            Billing_City__c = 'NOMATCHCITY4',
            Billing_state__c = 'NOMATCHSTATE4',
            Zone__c = 'NOMATCHZONE4',
            Country__c = 'COUNTRYFOUR'
        );

        // Lead 5 -> falls through to Vertical_Code__c match branch
        Lead__c leadVerticalMatch = new Lead__c(
            OwnerId = marketingUser.Id,
            First_Name__c = 'Test',
            Last_Name__c = 'VerticalLead',
            Mobile__c = '9000000005',
            Billing_City__c = 'NOMATCHCITY5',
            Billing_state__c = 'NOMATCHSTATE5',
            Zone__c = 'NOMATCHZONE5',
            Country__c = 'NOMATCHCOUNTRY5'
        );

        insert new List<Lead__c>{
            leadCityMatch, leadStateMatch, leadZoneMatch, leadCountryMatch, leadVerticalMatch
        };

        // ============================================================================
        // IMPORTANT FIX: The controller's map-building loop calls .toUpperCase() on
        // State__c, Zone__c, Country__c, Vertical_Code__c UNCONDITIONALLY, as soon as
        // the record matches on an earlier field (City__c, then State__c, etc.) —
        // it does NOT null-check those inner fields. Since we cannot modify the
        // controller, every "downstream" field for each record below is filled with
        // a unique, harmless filler value (never matching any test Lead's own fields)
        // purely to prevent a null.toUpperCase() crash. These fillers do not affect
        // which branch each Lead falls into.
        // ============================================================================

        CityWise__c cityWiseCity = new CityWise__c(
            External_Id__c = 'CW-CITY-001',
            City__c = 'CITYONE',
            State__c = 'ZZFILLERSTATE1',       // filler - only needed to avoid NPE
            Zone__c = 'ZZFILLERZONE1',         // filler
            Country__c = 'ZZFILLERCOUNTRY1',   // filler
            Vertical_Code__c = 'ZZFILLERVERT1',// filler
            Division__c = subDivisionValue,
            District_Level__c = marketingUser.Id,
            RSM__c = marketingUser.Id,
            ZSM__c = marketingUser.Id,
            NSM__c = marketingUser.Id,
            GSRO__c = marketingUser.Id,
            Divisional_Manager__c = marketingUser.Id
        );
        CityWise__c cityWiseState = new CityWise__c(
            External_Id__c = 'CW-STATE-001',
            State__c = 'STATETWO',
            Zone__c = 'ZZFILLERZONE2',         // filler
            Country__c = 'ZZFILLERCOUNTRY2',   // filler
            Vertical_Code__c = 'ZZFILLERVERT2',// filler
            Division__c = subDivisionValue,
            RSM__c = marketingUser.Id,
            ZSM__c = marketingUser.Id,
            NSM__c = marketingUser.Id,
            GSRO__c = marketingUser.Id,
            Divisional_Manager__c = marketingUser.Id
        );
        CityWise__c cityWiseZone = new CityWise__c(
            External_Id__c = 'CW-ZONE-001',
            Zone__c = 'ZONETHREE',
            Country__c = 'ZZFILLERCOUNTRY3',   // filler
            Vertical_Code__c = 'ZZFILLERVERT3',// filler
            Division__c = subDivisionValue,
            ZSM__c = marketingUser.Id,
            NSM__c = marketingUser.Id,
            GSRO__c = marketingUser.Id,
            Divisional_Manager__c = marketingUser.Id
        );
        CityWise__c cityWiseCountry = new CityWise__c(
            External_Id__c = 'CW-COUNTRY-001',
            Country__c = 'COUNTRYFOUR',
            Vertical_Code__c = 'ZZFILLERVERT4',// filler
            Division__c = subDivisionValue,
            NSM__c = marketingUser.Id,
            GSRO__c = marketingUser.Id,
            Divisional_Manager__c = marketingUser.Id
        );
        CityWise__c cityWiseVertical = new CityWise__c(
            External_Id__c = 'CW-VERTICAL-001',
            Vertical_Code__c = verticalValue,
            Division__c = subDivisionValue,
            GSRO__c = marketingUser.Id,
            Divisional_Manager__c = marketingUser.Id
        );
        insert new List<CityWise__c>{
            cityWiseCity, cityWiseState, cityWiseZone, cityWiseCountry, cityWiseVertical
        };

        insert new List<Lead_Product__c>{
            new Lead_Product__c(Leads__c = leadCityMatch.Id, Product_Group__c = productGroup.Id),
            new Lead_Product__c(Leads__c = leadStateMatch.Id, Product_Group__c = productGroup.Id),
            new Lead_Product__c(Leads__c = leadZoneMatch.Id, Product_Group__c = productGroup.Id),
            new Lead_Product__c(Leads__c = leadCountryMatch.Id, Product_Group__c = productGroup.Id),
            new Lead_Product__c(Leads__c = leadVerticalMatch.Id, Product_Group__c = productGroup.Id)
        };
    }

    @isTest
    static void testPopulateProspectFieldsFromCitywise1() {
        List<Lead_Product__c> leadProducts = [SELECT Id, Leads__c, Product_Group__c FROM Lead_Product__c];

        Test.startTest();
        LeadsProductGroupHandler.populateProspectFieldsFromCitywise1(leadProducts);
        Test.stopTest();
    }

    @isTest
    static void testPopulateProspectFieldsFromCitywise1EmptyList() {
        Test.startTest();
        LeadsProductGroupHandler.populateProspectFieldsFromCitywise1(new List<Lead_Product__c>());
        Test.stopTest();
    }

    @isTest
    static void testSendNotificaitonToUsers() {
        User marketingUser = [SELECT Id FROM User WHERE Alias = 'tbdm' LIMIT 1];

        Test.startTest();
        LeadsProductGroupHandler.sendNotificaitonToUsers(new Set<String>{ marketingUser.Id });
        LeadsProductGroupHandler.sendNotificaitonToUsers(new Set<String>());
        Test.stopTest();
    }

    @isTest
    static void testTriggerInsert() {
        Lead__c lead = [SELECT Id FROM Lead__c WHERE Billing_City__c = 'CITYONE' LIMIT 1];
        Product_Group__c pg = [SELECT Id FROM Product_Group__c LIMIT 1];

        Test.startTest();
        insert new Lead_Product__c(Leads__c = lead.Id, Product_Group__c = pg.Id);
        Test.stopTest();
    }

    private static String getPicklistValue(String objectName, String fieldName) {
        Schema.DescribeFieldResult fieldResult = Schema.getGlobalDescribe()
            .get(objectName)
            .getDescribe()
            .fields.getMap()
            .get(fieldName)
            .getDescribe();
        if (fieldResult.getType() == Schema.DisplayType.PICKLIST) {
            for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
                if (entry.isActive()) {
                    return entry.getValue();
                }
            }
        }
        return 'Test';
    }
}

/*@isTest
private class LeadsProductGroupHandlerTest {

    @TestSetup
    static void setupData() {
        // User whose UserRole name matches the BDM/SSE/Sales pattern in the handler's dynamic query,
        // so we don't need to depend on a specific Marketing profile existing in the org.
        UserRole testRole = new UserRole(Name = 'Test BDM Role');

        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User marketingUser;

        // UserRole/User are setup objects - isolate their DML via runAs to avoid MIXED_DML_OPERATION
        // when other (non-setup) sObjects are inserted later in this same test context.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert testRole;

            marketingUser = new User(
                FirstName = 'Test',
                LastName = 'BDM',
                Email = 'testbdm' + DateTime.now().getTime() + '@example.com',
                Username = 'testbdm' + DateTime.now().getTime() + '@example.com.test',
                Alias = 'tbdm',
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = standardProfile.Id,
                UserRoleId = testRole.Id
            );
            insert marketingUser;
        }

        String verticalValue = getPicklistValue('Product_Group__c', 'Vertical__c');
        // Sub_Division__c is hardcoded to 'COH' here (not dynamically resolved) because the handler
        // literally checks membership in {'COH','GT','ORTHO'} for the state-match branch - it needs
        // to be one of those exact values to exercise that path.
        String subDivisionValue = 'COH';

        Product_Group__c productGroup = new Product_Group__c(
            Name = 'Test Product Group',
            Vertical__c = verticalValue,
            Sub_Division__c = subDivisionValue
        );
        insert productGroup;

        Org_Role_Hierarchy__c businessMappingOrgRole = new Org_Role_Hierarchy__c(
            Name = 'Test Org Role Hierarchy - Business Mapping',
            Business_Mapping__c = true
        );
        insert businessMappingOrgRole;

        // IMPORTANT: the handler builds its lookup maps with city.Field__c.toUpperCase() as the key,
        // but then calls map.containsKey(lead.Field__c) using the RAW (non-uppercased) lead value.
        // So for a branch to actually be entered, the Lead's field value must already be uppercase -
        // that's why every value below is deliberately supplied in all caps.

        // Lead 1 -> exercises the City__c match branch
        Lead__c leadCityMatch = new Lead__c(
            OwnerId = marketingUser.Id,
            First_Name__c = 'Test',
            Last_Name__c = 'CityLead',
            Mobile__c = '9000000001',
            Billing_City__c = 'CITYONE',
            Billing_state__c = 'STATEONE',
            Zone__c = 'ZONEONE',
            Country__c = 'COUNTRYONE'
        );

        // Lead 2 -> city won't match, falls through to State__c match branch (Division_New__c = 'COH'
        // which is in the handler's hardcoded productGroupSet, satisfying that branch's extra condition)
        Lead__c leadStateMatch = new Lead__c(
            OwnerId = marketingUser.Id,
            First_Name__c = 'Test',
            Last_Name__c = 'StateLead',
            Mobile__c = '9000000002',
            Billing_City__c = 'NOMATCHCITY2',
            Billing_state__c = 'STATETWO',
            Zone__c = 'NOMATCHZONE2',
            Country__c = 'NOMATCHCOUNTRY2'
        );

        // Lead 3 -> city/state won't match, falls through to Zone__c match branch
        Lead__c leadZoneMatch = new Lead__c(
            OwnerId = marketingUser.Id,
            First_Name__c = 'Test',
            Last_Name__c = 'ZoneLead',
            Mobile__c = '9000000003',
            Billing_City__c = 'NOMATCHCITY3',
            Billing_state__c = 'NOMATCHSTATE3',
            Zone__c = 'ZONETHREE',
            Country__c = 'NOMATCHCOUNTRY3'
        );

        // Lead 4 -> city/state/zone won't match, falls through to Country__c match branch
        Lead__c leadCountryMatch = new Lead__c(
            OwnerId = marketingUser.Id,
            First_Name__c = 'Test',
            Last_Name__c = 'CountryLead',
            Mobile__c = '9000000004',
            Billing_City__c = 'NOMATCHCITY4',
            Billing_state__c = 'NOMATCHSTATE4',
            Zone__c = 'NOMATCHZONE4',
            Country__c = 'COUNTRYFOUR'
        );

        // Lead 5 -> city/state/zone/country won't match, falls through to Vertical_Code__c match branch.
        // Vertical_Code__c itself is overwritten by the handler from the Product_Group__c's Vertical__c
        // value, so we don't set it directly here - the CityWise vertical record below uses the same
        // verticalValue so they line up.
        Lead__c leadVerticalMatch = new Lead__c(
            OwnerId = marketingUser.Id,
            First_Name__c = 'Test',
            Last_Name__c = 'VerticalLead',
            Mobile__c = '9000000005',
            Billing_City__c = 'NOMATCHCITY5',
            Billing_state__c = 'NOMATCHSTATE5',
            Zone__c = 'NOMATCHZONE5',
            Country__c = 'NOMATCHCOUNTRY5'
        );

        insert new List<Lead__c>{
            leadCityMatch, leadStateMatch, leadZoneMatch, leadCountryMatch, leadVerticalMatch
        };

        CityWise__c cityWiseCity = new CityWise__c(
            External_Id__c = 'CW-CITY-001',
            City__c = 'CITYONE',
            Division__c = subDivisionValue,
            District_Level__c = marketingUser.Id,
            RSM__c = marketingUser.Id,
            ZSM__c = marketingUser.Id,
            NSM__c = marketingUser.Id,
            GSRO__c = marketingUser.Id,
            Divisional_Manager__c = marketingUser.Id
        );
        CityWise__c cityWiseState = new CityWise__c(
            External_Id__c = 'CW-STATE-001',
            State__c = 'STATETWO',
            Division__c = subDivisionValue,
            RSM__c = marketingUser.Id,
            ZSM__c = marketingUser.Id,
            NSM__c = marketingUser.Id,
            GSRO__c = marketingUser.Id,
            Divisional_Manager__c = marketingUser.Id
        );
        CityWise__c cityWiseZone = new CityWise__c(
            External_Id__c = 'CW-ZONE-001',
            Zone__c = 'ZONETHREE',
            Division__c = subDivisionValue,
            ZSM__c = marketingUser.Id,
            NSM__c = marketingUser.Id,
            GSRO__c = marketingUser.Id,
            Divisional_Manager__c = marketingUser.Id
        );
        CityWise__c cityWiseCountry = new CityWise__c(
            External_Id__c = 'CW-COUNTRY-001',
            Country__c = 'COUNTRYFOUR',
            Division__c = subDivisionValue,
            NSM__c = marketingUser.Id,
            GSRO__c = marketingUser.Id,
            Divisional_Manager__c = marketingUser.Id
        );
        CityWise__c cityWiseVertical = new CityWise__c(
            External_Id__c = 'CW-VERTICAL-001',
            Vertical_Code__c = verticalValue,
            Division__c = subDivisionValue,
            GSRO__c = marketingUser.Id,
            Divisional_Manager__c = marketingUser.Id
        );
        insert new List<CityWise__c>{
            cityWiseCity, cityWiseState, cityWiseZone, cityWiseCountry, cityWiseVertical
        };

        insert new List<Lead_Product__c>{
            new Lead_Product__c(Leads__c = leadCityMatch.Id, Product_Group__c = productGroup.Id),
            new Lead_Product__c(Leads__c = leadStateMatch.Id, Product_Group__c = productGroup.Id),
            new Lead_Product__c(Leads__c = leadZoneMatch.Id, Product_Group__c = productGroup.Id),
            new Lead_Product__c(Leads__c = leadCountryMatch.Id, Product_Group__c = productGroup.Id),
            new Lead_Product__c(Leads__c = leadVerticalMatch.Id, Product_Group__c = productGroup.Id)
        };
    }

    @isTest
    static void testPopulateProspectFieldsFromCitywise1() {
        List<Lead_Product__c> leadProducts = [SELECT Id, Leads__c, Product_Group__c FROM Lead_Product__c];

        Test.startTest();
        LeadsProductGroupHandler.populateProspectFieldsFromCitywise1(leadProducts);
        Test.stopTest();
    }

    @isTest
    static void testPopulateProspectFieldsFromCitywise1EmptyList() {
        Test.startTest();
        LeadsProductGroupHandler.populateProspectFieldsFromCitywise1(new List<Lead_Product__c>());
        Test.stopTest();
    }

    @isTest
    static void testSendNotificaitonToUsers() {
        User marketingUser = [SELECT Id FROM User WHERE Alias = 'tbdm' LIMIT 1];

        Test.startTest();
        LeadsProductGroupHandler.sendNotificaitonToUsers(new Set<String>{ marketingUser.Id });
        LeadsProductGroupHandler.sendNotificaitonToUsers(new Set<String>()); // early-return branch
        Test.stopTest();
    }

    @isTest
    static void testTriggerInsert() {
        Lead__c lead = [SELECT Id FROM Lead__c WHERE Billing_City__c = 'CITYONE' LIMIT 1];
        Product_Group__c pg = [SELECT Id FROM Product_Group__c LIMIT 1];

        Test.startTest();
        insert new Lead_Product__c(Leads__c = lead.Id, Product_Group__c = pg.Id);
        Test.stopTest();
    }

    // Dynamically resolves a valid picklist value instead of hardcoding one, so this test
    // doesn't break if picklist values are restricted/renamed in a given org.
    private static String getPicklistValue(String objectName, String fieldName) {
        Schema.DescribeFieldResult fieldResult = Schema.getGlobalDescribe()
            .get(objectName)
            .getDescribe()
            .fields.getMap()
            .get(fieldName)
            .getDescribe();
        if (fieldResult.getType() == Schema.DisplayType.PICKLIST) {
            for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
                if (entry.isActive()) {
                    return entry.getValue();
                }
            }
        }
        return 'Test';
    }
}*/
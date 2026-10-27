@IsTest
public class ProductConfiguratorControllerTest {

    @TestSetup
    static void setupTestData() {
        Target__c target = new Target__c(Name = 'Test Target', Date__c = Date.today());
        insert target;
		Target_Line_Item__c tli = new Target_Line_Item__c(
        Target__c = target.Id);
    	insert tli;
        Campaign__c campaign = new Campaign__c(
            Name = 'Test Campaign',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(10),
            Target__c = target.Id,
            Focus_Product__c = 'EYECRYL PLUS',
            Planned_Attendees__c = 10,
            Categorize__c = 'Biotech Driven Event',
            Zone__c = 'WEST',
            Operation__c = 'Direct',
            Region__c = 'APAC',
            //Country__c = 'INDIA'
			Country__c = 'IN'
        );
        insert campaign;

        Product_Group__c pg = new Product_Group__c(
            Product_Family__c = 'BIO RING',
            Group_Name__c = 'Test Group',
            Country__c = 'IN'
        );
        insert pg;

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            FirstName = 'John', LastName = 'Doe',
            Email = 'john@test.com', MobilePhone = '9999999999',
            MailingCity = 'Mumbai', MailingStreet = 'Street 1',
            MailingState = 'MH', MailingPostalCode = '400001',
            MailingCountry = 'India', AccountId = acc.Id
        );
        insert con;
    }

    @IsTest
    static void testGetRecordTypeNameWithId() {
        Test.startTest();
        ProductConfiguratorController.getRecordTypeNameWithId('Campaign__c');
        Test.stopTest();
    }

    @IsTest
    static void testGetFieldSets() {
        Test.startTest();
        ProductConfiguratorController.getFieldSets('Product_M__c', 'Add_Product_Field_Set');
        Test.stopTest();
    }

    @IsTest
    static void testGetLineItem() {
        Campaign__c cam = [SELECT Id FROM Campaign__c LIMIT 1];
        Product_Group__c pg = [SELECT Id FROM Product_Group__c LIMIT 1];
        insert new Campaign_Line_Item__c(Campaign__c = cam.Id, Product_Family__c = 'BIO RING', Product_Group__c = pg.Id);

        Test.startTest();
        ProductConfiguratorController.getLineItem(cam.Id);
        Test.stopTest();
    }

    @IsTest
    static void testCreateMemberAndProductRecordBlank() {
        Test.startTest();
        try {
            ProductConfiguratorController.createMemberAndProductRecord('', new List<Object>());
        } catch (AuraHandledException e) {}
        Test.stopTest();
    }

    @IsTest
    static void testCreateMemberAndProductRecordNull() {
        Test.startTest();
        try {
            ProductConfiguratorController.createMemberAndProductRecord(null, new List<Object>());
        } catch (AuraHandledException e) {}
        Test.stopTest();
    }

    @IsTest
    static void testCreateMemberAndProductRecordHappyPath() {
        Campaign__c cam = [SELECT Id FROM Campaign__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Product_Group__c pg = [SELECT Id FROM Product_Group__c LIMIT 1];

        Id rtId = Schema.SObjectType.Campaign_Member__c
            .getRecordTypeInfosByDeveloperName()
            .get('Existing_member')
            .getRecordTypeId();

        Campaign_Member__c cm = new Campaign_Member__c(
            RecordTypeId = rtId,
            Account__c = acc.Id,
            Campaign1__c = cam.Id,
            Campaign_Product__c = 'EYECRYL PLUS CLEAR',
            Contact__c = con.Id
        );

        Map<Object, Object> rowWithGroup = new Map<Object, Object>{'Product_Group__c' => pg.Id};
        Map<Object, Object> rowNoGroup = new Map<Object, Object>{'Product_Group__c' => null};

        List<Object> rows = new List<Object>{null, rowNoGroup, rowWithGroup};

        Test.startTest();
        ProductConfiguratorController.createMemberAndProductRecord(JSON.serialize(cm), rows);
        Test.stopTest();
    }

    @IsTest
    static void testGetContactNameByIdWithContact() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Test.startTest();
        ProductConfiguratorController.getContactNameById(con.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetContactNameByIdNull() {
        Test.startTest();
        ProductConfiguratorController.getContactNameById(null);
        Test.stopTest();
    }

    @IsTest
    static void testCreateCamLine() {
        Campaign__c cam = [SELECT Id FROM Campaign__c LIMIT 1];
        Test.startTest();
        ProductConfiguratorController.createCamLine(cam.Id, new List<String>{'BIO RING'});
        Test.stopTest();
    }

    @IsTest
    static void testCreateCamLineNullId() {
        Test.startTest();
        try {
            ProductConfiguratorController.createCamLine(null, new List<String>{'BIO RING'});
        } catch (AuraHandledException e) {}
        Test.stopTest();
    }

    @IsTest
    static void testCreateCamLineNullFamilies() {
        Campaign__c cam = [SELECT Id FROM Campaign__c LIMIT 1];
        Test.startTest();
        try {
            ProductConfiguratorController.createCamLine(cam.Id, null);
        } catch (AuraHandledException e) {}
        Test.stopTest();
    }

    @IsTest
    static void testCreateCamLineEmptyFamilies() {
        Campaign__c cam = [SELECT Id FROM Campaign__c LIMIT 1];
        Test.startTest();
        try {
            ProductConfiguratorController.createCamLine(cam.Id, new List<String>());
        } catch (AuraHandledException e) {}
        Test.stopTest();
    }

    @IsTest
    static void testCreateCampaignLineWithGroupNames() {
        Campaign__c cam = [SELECT Id FROM Campaign__c LIMIT 1];
        Test.startTest();
        ProductConfiguratorController.createCampaignLine(cam.Id, new List<String>{'BIO RING'}, new List<String>{'Test Group'});
        Test.stopTest();
    }

    // Covers createCampaignLine() — no groupNames (else branch)
    @IsTest
    static void testCreateCampaignLineNoGroupNames() {
        Campaign__c cam = [SELECT Id FROM Campaign__c LIMIT 1];
        Test.startTest();
        ProductConfiguratorController.createCampaignLine(cam.Id, new List<String>{'BIO RING'}, null);
        Test.stopTest();
    }

    @IsTest
    static void testCreateCampaignLineNullId() {
        Test.startTest();
        try {
            ProductConfiguratorController.createCampaignLine(null, new List<String>{'BIO RING'}, null);
        } catch (AuraHandledException e) {}
        Test.stopTest();
    }

    @IsTest
    static void testCreateCampaignLineEmptyFamilies() {
        Campaign__c cam = [SELECT Id FROM Campaign__c LIMIT 1];
        Test.startTest();
        try {
            ProductConfiguratorController.createCampaignLine(cam.Id, new List<String>(), null);
        } catch (AuraHandledException e) {}
        Test.stopTest();
    }

    // ===== New coverage: previously untested methods =====

    @IsTest
    static void testGetAccountCommercialName() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        ProductConfiguratorController.getAccountCommercialName(acc.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetAccountCommercialNameNull() {
        Test.startTest();
        ProductConfiguratorController.getAccountCommercialName(null);
        Test.stopTest();
    }

    @IsTest
    static void testGetRelatedContactIds() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        ProductConfiguratorController.getRelatedContactIds(acc.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetRelatedContactIdsNull() {
        Test.startTest();
        ProductConfiguratorController.getRelatedContactIds(null);
        Test.stopTest();
    }

    @IsTest
    static void testCheckDuplicateMemberFound() {
        Campaign__c cam = [SELECT Id FROM Campaign__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        Id rtId = Schema.SObjectType.Campaign_Member__c
            .getRecordTypeInfosByDeveloperName()
            .get('Existing_member')
            .getRecordTypeId();

        insert new Campaign_Member__c(
            RecordTypeId = rtId,
            Account__c = acc.Id,
            Campaign1__c = cam.Id,
            Campaign_Product__c = 'EYECRYL PLUS CLEAR',
            Contact__c = con.Id,
            Lead_First_Name__c = 'John',
            Lead_Last_Name__c = 'Doe'
        );

        Test.startTest();
        ProductConfiguratorController.checkDuplicateMember(cam.Id, 'John', 'Doe');
        Test.stopTest();
    }

    @IsTest
    static void testCheckDuplicateMemberNotFound() {
        Campaign__c cam = [SELECT Id FROM Campaign__c LIMIT 1];
        Test.startTest();
        ProductConfiguratorController.checkDuplicateMember(cam.Id, 'NoOne', 'Here');
        Test.stopTest();
    }

    @IsTest
    static void testGetCountries() {
        insert new Country__c(Country__c = 'India', State__c = 'MH', City__c = 'Mumbai');
        Test.startTest();
        ProductConfiguratorController.getCountries();
        Test.stopTest();
    }

    @IsTest
    static void testGetStates() {
        insert new Country__c(Country__c = 'India', State__c = 'MH', City__c = 'Mumbai');
        Test.startTest();
        ProductConfiguratorController.getStates('India');
        Test.stopTest();
    }

    @IsTest
    static void testGetCities() {
        insert new Country__c(Country__c = 'India', State__c = 'MH', City__c = 'Mumbai');
        Test.startTest();
        ProductConfiguratorController.getCities('India', 'MH');
        Test.stopTest();
    }
}



/*@IsTest
public class ProductConfiguratorControllerTest {

    @TestSetup
    static void setupTestData() {
        Target__c target = new Target__c(Name = 'Test Target', Date__c = Date.today());
        insert target;
		Target_Line_Item__c tli = new Target_Line_Item__c(
        Target__c = target.Id);
    	insert tli;
        Campaign__c campaign = new Campaign__c(
            Name = 'Test Campaign',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(10),
            Target__c = target.Id,
            Focus_Product__c = 'EYECRYL PLUS',
            Planned_Attendees__c = 10,
            Categorize__c = 'Biotech Driven Event',
            Zone__c = 'WEST',
            Operation__c = 'Direct',
            Region__c = 'APAC',
            //Country__c = 'INDIA'
			Country__c = 'IN'
        );
        insert campaign;

        Product_Group__c pg = new Product_Group__c(
            Product_Family__c = 'BIO RING',
            Group_Name__c = 'Test Group'
        );
        insert pg;

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            FirstName = 'John', LastName = 'Doe',
            Email = 'john@test.com', MobilePhone = '9999999999',
            MailingCity = 'Mumbai', MailingStreet = 'Street 1',
            MailingState = 'MH', MailingPostalCode = '400001',
            MailingCountry = 'India', AccountId = acc.Id
        );
        insert con;
    }

    @IsTest
    static void testGetRecordTypeNameWithId() {
        Test.startTest();
        ProductConfiguratorController.getRecordTypeNameWithId('Campaign__c');
        Test.stopTest();
    }

    @IsTest
    static void testGetFieldSets() {
        Test.startTest();
        ProductConfiguratorController.getFieldSets('Product_M__c', 'Add_Product_Field_Set');
        Test.stopTest();
    }

    @IsTest
    static void testGetLineItem() {
        Campaign__c cam = [SELECT Id FROM Campaign__c LIMIT 1];
        Product_Group__c pg = [SELECT Id FROM Product_Group__c LIMIT 1];
        insert new Campaign_Line_Item__c(Campaign__c = cam.Id, Product_Family__c = 'BIO RING', Product_Group__c = pg.Id);

        Test.startTest();
        ProductConfiguratorController.getLineItem(cam.Id);
        Test.stopTest();
    }

    @IsTest
    static void testCreateMemberAndProductRecordBlank() {
        Test.startTest();
        try {
            ProductConfiguratorController.createMemberAndProductRecord('', new List<Object>());
        } catch (AuraHandledException e) {}
        Test.stopTest();
    }

    @IsTest
    static void testCreateMemberAndProductRecordNull() {
        Test.startTest();
        try {
            ProductConfiguratorController.createMemberAndProductRecord(null, new List<Object>());
        } catch (AuraHandledException e) {}
        Test.stopTest();
    }

    @IsTest
    static void testCreateMemberAndProductRecordHappyPath() {
        Campaign__c cam = [SELECT Id FROM Campaign__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Product_Group__c pg = [SELECT Id FROM Product_Group__c LIMIT 1];

        Id rtId = Schema.SObjectType.Campaign_Member__c
            .getRecordTypeInfosByDeveloperName()
            .get('Existing_member')
            .getRecordTypeId();

        Campaign_Member__c cm = new Campaign_Member__c(
            RecordTypeId = rtId,
            Account__c = acc.Id,
            Campaign1__c = cam.Id,
            Campaign_Product__c = 'EYECRYL PLUS CLEAR',
            Contact__c = con.Id
        );

        Map<Object, Object> rowWithGroup = new Map<Object, Object>{'Product_Group__c' => pg.Id};
        Map<Object, Object> rowNoGroup = new Map<Object, Object>{'Product_Group__c' => null};

        List<Object> rows = new List<Object>{null, rowNoGroup, rowWithGroup};

        Test.startTest();
        ProductConfiguratorController.createMemberAndProductRecord(JSON.serialize(cm), rows);
        Test.stopTest();
    }

    @IsTest
    static void testGetContactNameByIdWithContact() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Test.startTest();
        ProductConfiguratorController.getContactNameById(con.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetContactNameByIdNull() {
        Test.startTest();
        ProductConfiguratorController.getContactNameById(null);
        Test.stopTest();
    }

    @IsTest
    static void testCreateCamLine() {
        Campaign__c cam = [SELECT Id FROM Campaign__c LIMIT 1];
        Test.startTest();
        ProductConfiguratorController.createCamLine(cam.Id, new List<String>{'BIO RING'});
        Test.stopTest();
    }

    @IsTest
    static void testCreateCamLineNullId() {
        Test.startTest();
        try {
            ProductConfiguratorController.createCamLine(null, new List<String>{'BIO RING'});
        } catch (AuraHandledException e) {}
        Test.stopTest();
    }

    @IsTest
    static void testCreateCamLineNullFamilies() {
        Campaign__c cam = [SELECT Id FROM Campaign__c LIMIT 1];
        Test.startTest();
        try {
            ProductConfiguratorController.createCamLine(cam.Id, null);
        } catch (AuraHandledException e) {}
        Test.stopTest();
    }

    @IsTest
    static void testCreateCamLineEmptyFamilies() {
        Campaign__c cam = [SELECT Id FROM Campaign__c LIMIT 1];
        Test.startTest();
        try {
            ProductConfiguratorController.createCamLine(cam.Id, new List<String>());
        } catch (AuraHandledException e) {}
        Test.stopTest();
    }

    @IsTest
    static void testCreateCampaignLineWithGroupNames() {
        Campaign__c cam = [SELECT Id FROM Campaign__c LIMIT 1];
        Test.startTest();
        ProductConfiguratorController.createCampaignLine(cam.Id, new List<String>{'BIO RING'}, new List<String>{'Test Group'});
        Test.stopTest();
    }

    // Covers createCampaignLine() — no groupNames (else branch)
    @IsTest
    static void testCreateCampaignLineNoGroupNames() {
        Campaign__c cam = [SELECT Id FROM Campaign__c LIMIT 1];
        Test.startTest();
        ProductConfiguratorController.createCampaignLine(cam.Id, new List<String>{'BIO RING'}, null);
        Test.stopTest();
    }

    @IsTest
    static void testCreateCampaignLineNullId() {
        Test.startTest();
        try {
            ProductConfiguratorController.createCampaignLine(null, new List<String>{'BIO RING'}, null);
        } catch (AuraHandledException e) {}
        Test.stopTest();
    }

    @IsTest
    static void testCreateCampaignLineEmptyFamilies() {
        Campaign__c cam = [SELECT Id FROM Campaign__c LIMIT 1];
        Test.startTest();
        try {
            ProductConfiguratorController.createCampaignLine(cam.Id, new List<String>(), null);
        } catch (AuraHandledException e) {}
        Test.stopTest();
    }
}*/
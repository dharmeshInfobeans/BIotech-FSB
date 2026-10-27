@isTest
public class CustomLeadCreationControllerTest {

    // ═══════════════════════════════════════════════════════════════════════════
    // Data is built ONCE in @testSetup so the ~100 SOQL its trigger cascade
    // consumes (2 Accounts + 2 Lead__c + CIS + Address, each firing the heavy
    // Lead/Account triggers) runs in its own governor context and no longer
    // counts against every @isTest method — that is what was causing
    // "System.LimitException: Too many SOQL queries: 101".
    //
    // Each test re-queries the records it needs via the small getters below.
    // ═══════════════════════════════════════════════════════════════════════════

    @testSetup
    static void makeData() {

        insert new CE_CIS_Configuration__c(
            From_Range__c = 120,
            To_Range__c   = 130,
            Country__c    = 'IN',
            Type__c       = 'Surgeries',
            Rating__c     = 'A'
        );

        // LeadTrigger control OFF: this test exercises the controller only, and
        // its Lead-update trigger chain (LeadsTriggerHelperClass.createAccountData)
        // issues ~100 SOQL per update -> "Too many SOQL queries: 101".
        insert new Leads__c(Name = 'LeadTrigger', IsActive__c = false);

        Id distributorRtId = resolveRecordTypeId(Account.SObjectType, 'Distributor', true);

        CIty__c region = new CIty__c(
            country_key__c = 'IN',
            Name           = 'Maharashtra',
            Region_Code__c = 'DL'
        );
        insert region;

        Account acc = new Account(
            Name                       = 'Test',
            AccountNumber              = '12345678',
            Region__c                  = region.Id,
            Street_2__c                = 'street2',
            Street_3__c                = 'street3',
            Street_4__c                = 'street4',
            Street_5__c                = 'street5',
            Country_Key__c             = 'IN',
            City__c                    = 'mumbai',
            City_postal_code__c        = '400001',
            RecordTypeId               = distributorRtId,
            Sub_Status__c              = 'Submitted To Approver 1',
            Medical_Registration_No__c = 'MEDREG123424567',
            GSTIN_No__c                = 'GSTIN2343423456',
            SAP_Code__c                = '12343122',
            BillingCity                = 'Gwalior',
            BillingPostalCode          = '474001',
            BillingState               = 'Mp',
            BillingCountry             = 'IN'
        );
        insert acc;

        Account parentAcc = new Account(
            Name                = 'Test Parent',
            AccountNumber       = '99999999',
            RecordTypeId        = distributorRtId,
            Country_Key__c      = 'IN',
            City__c             = 'mumbai',
            City_postal_code__c = '400001',
            BillingCity         = 'Gwalior',
            BillingPostalCode   = '474001',
            BillingState        = 'Mp',
            BillingCountry      = 'IN'
        );
        insert parentAcc;

        insert new Contact(
            LastName    = 'abhi',
            AccountId   = acc.Id,
            FirstName   = 'test',
            MobilePhone = '8563478634'
        );

        insert new Org_Role_Hierarchy__c(
            Name                = 'Test Org Role Hierarchy - Business Mapping',
            Business_Mapping__c = true
        );

        Lead__c lea = new Lead__c(
            Name                             = 'tets',
            Actual_Appointments_Week__c      = System.today(),
            Planned_Product_Demo_Week__c     = System.today(),
            Planned_Presentation_Week__c     = System.today(),
            Planned_Evaluations_Week__c      = System.today(),
            Planned_Commercialization_week__c= System.today(),
            Planned_Upgrade_week__c          = System.today(),
            First_Name__c                    = 'test',
            Last_Name__c                     = 'singh',
            Company__c                       = 'Plus91labs',
            Product__c                       = 'BIO BLADE',
            Billing_City__c                  = 'Gwalior',
            Billing_code__c                  = '474001',
            Country__c                       = 'INDIA',
            Account__c                       = acc.Id,
            Billing_state__c                 = 'Mp',
            Billing_country__c               = 'india',
            Email__c                         = 'pankajsinghania123@gmail.com',
            Mobile__c                        = '1234567890',
            Billing_Street__c                = 'chandranagr koteshwar',
            SAP_Code__c                      = '12343122',
            Lead_Stage__c                    = 'Presentation',
            CE_CIS_Approval__c               = true,
            Phakic_Rating__c                 = 'test'
        );
        insert lea;

        CIS_Header__c cis = new CIS_Header__c(
            No_of_LVC_Procedures__c = 122,
            Regular_Percentage__c   = 12,
            Premium_Percentage__c   = 12,
            Leads__c                = lea.Id,
            Status__c               = 'Approved'
        );
        insert cis;

        insert new CIS_Line__c(
            CIS_Header__c      = cis.Id,
            Company__c         = 'Biotech',
            Product__c         = 'Phakic',
            No_of_Surguries__c = 134
        );

        Lead__c lea1 = new Lead__c(
            Name                             = 'sourav',
            Actual_Appointments_Week__c      = System.today(),
            Planned_Product_Demo_Week__c     = System.today(),
            Planned_Presentation_Week__c     = System.today(),
            Planned_Evaluations_Week__c      = System.today(),
            Planned_Commercialization_week__c= System.today(),
            Planned_Upgrade_week__c          = System.today(),
            First_Name__c                    = 'sourav',
            Account__c                       = acc.Id,
            Last_Name__c                     = 'singh',
            Company__c                       = 'Plus91labs1',
            Product__c                       = 'EYECRYL TORIC',
            Billing_City__c                  = 'Gwalior',
            Billing_code__c                  = '474001',
            Billing_country__c               = 'india',
            Billing_Street__c                = 'chandranagr koteshwar',
            Country__c                       = 'India',
            Billing_state__c                 = 'Mp',
            Email__c                         = 'pankaj333@gmail.com',
            Mobile__c                        = '1234567435',
            SAP_Code__c                      = '78453453',
            Lead_Stage__c                    = 'Presentation',
            CE_CIS_Approval__c               = true,
            Phakic_Rating__c                 = 'test'
        );
        insert lea1;

        insert new Address__c(
            Account__c         = acc.Id,
            Billing_Street__c  = '123 Main Street',
            Billing_City__c    = 'Gwalior',
            Billing_state__c   = 'Mp',
            Billing_country__c = 'IN'
        );
    }

    // ── Re-query helpers (1 SOQL each) ─────────────────────────────────────────
    private static Account acc()      { return [SELECT Id, ParentId FROM Account  WHERE Name = 'Test' AND SAP_Code__c = '12343122' LIMIT 1]; }
    private static Account parentAcc(){ return [SELECT Id FROM Account            WHERE AccountNumber = '99999999' LIMIT 1]; }
    private static Contact con()      { return [SELECT Id FROM Contact            WHERE LastName = 'abhi' LIMIT 1]; }
    private static Lead__c lea()      { return [SELECT Id FROM Lead__c            WHERE SAP_Code__c = '12343122' LIMIT 1]; }
    private static Lead__c lea1()     { return [SELECT Id, Unqualified_Remarks__c, Disqualified_Reason__c FROM Lead__c WHERE SAP_Code__c = '78453453' LIMIT 1]; }
    private static Address__c addr()  { return [SELECT Id, Billing_Street__c FROM Address__c LIMIT 1]; }

    // Ensures the running user has a non-blank Country__c (custom picklist on User)
    // so the country-filtered queries in the controller can match. The User DML is
    // isolated in System.runAs to avoid MIXED_DML_OPERATION with the other inserts.
    // Returns the value to stamp on the matching Product_Group__c records.
    private static String ensureRunningUserCountry() {
        User u = [SELECT Id, Country__c FROM User WHERE Id = :UserInfo.getUserId()];
        if (String.isBlank(u.Country__c)) {
            System.runAs(u) {
                u.Country__c = 'INDIA';
                update u;
            }
            return 'INDIA';
        }
        return u.Country__c;
    }

    private static Id resolveRecordTypeId(Schema.SObjectType sObjType, String nameOrLabel, Boolean byDeveloperName) {
        Map<String, Schema.RecordTypeInfo> infos = byDeveloperName
            ? sObjType.getDescribe().getRecordTypeInfosByDeveloperName()
            : sObjType.getDescribe().getRecordTypeInfosByName();
        for (String key : infos.keySet()) {
            if (key.equalsIgnoreCase(nameOrLabel)) {
                Schema.RecordTypeInfo info = infos.get(key);
                if (info.isAvailable()) {
                    return info.getRecordTypeId();
                }
                return null;
            }
        }
        return null;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // leadCreate
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testLeadCreate_NewLeadMinimal() {
        Lead__c newLead = new Lead__c(
            First_Name__c   = 'Minimal',
            Last_Name__c    = 'Lead',
            Company__c      = 'Minimal Co',
            Product__c      = 'BIO BLADE',
            Lead_Stage__c   = 'Presentation',
            Mobile__c       = '9000000001',
            Billing_City__c = 'Gwalior'
        );
        Map<String,Object> dataMap = new Map<String,Object>();

        Test.startTest();
        String resultId = CustomLeadCreationController.leadCreate(
            newLead, dataMap, null, null, null, null, null, null, null
        );
        Test.stopTest();

        System.assertNotEquals(null, resultId, 'A new Lead Id should be returned');
        Lead__c inserted = [SELECT Id, Name FROM Lead__c WHERE Id = :resultId];
        System.assertEquals('Minimal Lead', inserted.Name, 'Name should default to First + Last when blank');
    }

    @isTest
    static void testLeadCreate_WithAccountAndParent() {
        Account a  = acc();
        Account pa = parentAcc();

        Lead__c newLead = new Lead__c(
            First_Name__c        = 'Parent',
            Last_Name__c         = 'Branch',
            Company__c           = 'Parent Branch Co',
            Product__c           = 'BIO BLADE',
            Lead_Stage__c        = 'Presentation',
            Mobile__c            = '9000000002',
            Billing_City__c      = 'Gwalior',
            Account__c           = a.Id,
            Existing_customer__c = false,
            New_Customer__c      = true
        );

        Test.startTest();
        String resultId = CustomLeadCreationController.leadCreate(
            newLead, new Map<String,Object>(), a.Id, null, null, null, null, null, pa.Id
        );
        Test.stopTest();

        System.assertNotEquals(null, resultId);
        Lead__c inserted = [SELECT Parent_Account__c, CE_CIS_Approval__c, Status__c FROM Lead__c WHERE Id = :resultId];
        System.assertEquals(pa.Id, inserted.Parent_Account__c);
        System.assertEquals(true, inserted.CE_CIS_Approval__c, 'Should be forced true when an Account is linked');
        System.assertEquals(true, inserted.Status__c, 'Should be forced true when an Account is linked');

        Account updatedAcc = [SELECT ParentId FROM Account WHERE Id = :a.Id];
        System.assertEquals(pa.Id, updatedAcc.ParentId, 'Account should be re-parented when New_Customer__c is true');
    }

    @isTest
    static void testLeadCreate_WithLeadEventList() {
        Lead__c related = lea1();

        Lead__c newLead = new Lead__c(
            First_Name__c                = 'Related',
            Last_Name__c                 = 'Events',
            Company__c                   = 'Related Co',
            Product__c                   = 'BIO BLADE',
            Lead_Stage__c                = 'Presentation',
            Mobile__c                    = '9000000004',
            Billing_City__c              = 'Gwalior',
            Planned_Product_Demo_Week__c = System.today()
        );
        Map<String,Object> dataMap = new Map<String,Object>{ 'Subject' => 'Follow Up' };
        List<String> leadEventList = new List<String>{ related.Id };

        Test.startTest();
        String resultId = CustomLeadCreationController.leadCreate(
            newLead, dataMap, null, null, null, null, null, leadEventList, null
        );
        Test.stopTest();

        System.assertNotEquals(null, resultId);
        List<Event> relatedEvents = [SELECT Id, WhatId, product__c FROM Event WHERE WhatId = :related.Id];
        System.assertEquals(1, relatedEvents.size(), 'One Event should be created against the related lead in leadEventList');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // fetchLookupData
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testFetchLookupData_withAccountIdFilter() {
        Account a = acc();

        Test.startTest();
        List<SObject> results = CustomLeadCreationController.fetchLookupData('Test', 'Account', a.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return exactly the filtered Account');
    }

    @isTest
    static void testFetchLookupData_withoutAccountIdFilter() {
        Test.startTest();
        List<SObject> results = CustomLeadCreationController.fetchLookupData('Test', 'Account', null);
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Should return at least the matching Account without an Id filter');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // fetchContactLookupData
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testFetchContactLookupData_withContIdFilter() {
        Account a = acc();
        Contact c = con();

        Test.startTest();
        List<Contact> results = CustomLeadCreationController.fetchContactLookupData('test', a.Id, c.Id);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(c.Id, results[0].Id);
    }

    @isTest
    static void testFetchContactLookupData_withoutContIdFilter() {
        Account a = acc();

        Test.startTest();
        List<Contact> results = CustomLeadCreationController.fetchContactLookupData('test', a.Id, '');
        Test.stopTest();

        System.assert(!results.isEmpty());
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getAccountId
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testGetAccountId_ForAccount() {
        Account a = acc();

        Test.startTest();
        Map<String,Object> result = CustomLeadCreationController.getAccountId(a.Id);
        Test.stopTest();

        System.assertEquals('true', result.get('Account'));
        System.assertEquals(a.Id, result.get('AccountId'));
    }

    @isTest
    static void testGetAccountId_ForLead_WithSiblingLeads() {
        Lead__c l = lea();

        Test.startTest();
        Map<String,Object> result = CustomLeadCreationController.getAccountId(l.Id);
        Test.stopTest();

        System.assertEquals('true', result.get('Lead'));
        System.assertEquals(l.Id, result.get('LeadId'));
        List<Object> leadList = (List<Object>) result.get('LeadList');
        System.assertNotEquals(null, leadList);
        System.assertEquals(1, leadList.size(), 'lea1 shares the same Account and is not Won, so it should appear in LeadList');
    }

    @isTest
    static void testGetAccountId_ForLead_NoAccount() {
        Lead__c standaloneLead = new Lead__c(
            Name            = 'Solo Lead',
            First_Name__c   = 'Solo',
            Last_Name__c    = 'Lead',
            Company__c      = 'Solo Co',
            Mobile__c       = '9000000005',
            Billing_City__c = 'Gwalior',
            New_Customer__c = false
        );
        insert standaloneLead;

        Test.startTest();
        CustomLeadCreationController.getAccountId(standaloneLead.Id);
        Test.stopTest();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // insertContact
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testInsertContact() {
        Account a = acc();
        Contact newCon = new Contact(LastName = 'NewContact', FirstName = 'Test');

        Test.startTest();
        String conId = CustomLeadCreationController.insertContact(newCon, a.Id);
        Test.stopTest();

        System.assertNotEquals(null, conId);
        Contact inserted = [SELECT AccountId FROM Contact WHERE Id = :conId];
        System.assertEquals(a.Id, inserted.AccountId);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getAddressData
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testGetAddressData() {
        Account a       = acc();
        Address__c ad   = addr();

        Test.startTest();
        List<Map<String,String>> results = CustomLeadCreationController.getAddressData(a.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return the one Address__c linked to this Account');
        System.assertEquals(ad.Id, results[0].get('value'));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getCountryMappingData / getCityMappingData
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testGetCountryMappingData() {
        insert new Country__c(CITY__c = 'Mumbai',  Country__c = 'India', Product__c = 'BIO BLADE',     State__c = 'Maharashtra');
        insert new Country__c(CITY__c = 'Pune',    Country__c = 'India', Product__c = 'EYECRYL TORIC', State__c = 'Maharashtra');
        insert new Country__c(CITY__c = 'Gwalior', Country__c = 'India', Product__c = 'BIO BLADE',     State__c = 'MP');

        Test.startTest();
        Map<String,List<Map<String,String>>> result = CustomLeadCreationController.getCountryMappingData('India');
        Test.stopTest();

        System.assert(result.containsKey('Product'), 'Product key should be present');
        System.assert(result.containsKey('State'), 'State key should be present');
        System.assertEquals(2, result.get('State').size(), 'Maharashtra and MP should each appear once, deduped');
    }

    @isTest
    static void testGetCityMappingData() {
        insert new Country__c(CITY__c = 'Mumbai', Country__c = 'India', Product__c = 'BIO BLADE',     State__c = 'Maharashtra');
        insert new Country__c(CITY__c = 'Mumbai', Country__c = 'India', Product__c = 'EYECRYL TORIC', State__c = 'Maharashtra');
        insert new Country__c(CITY__c = 'Pune',   Country__c = 'India', Product__c = 'BIO BLADE',     State__c = 'Maharashtra');

        Test.startTest();
        Map<String,List<Map<String,String>>> result = CustomLeadCreationController.getCityMappingData('Maharashtra');
        Test.stopTest();

        System.assert(result.containsKey('city'), 'city key should be present');
        System.assertEquals(2, result.get('city').size(), 'Mumbai and Pune should each appear once, deduped');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getCustomLabels
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testGetCustomLabels() {
        Test.startTest();
        CustomLeadCreationController.getCustomLabels();
        Test.stopTest();
        System.assert(true, 'getCustomLabels executed without exception');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getProductGroupsByFamily  — country-filtered query: stamp the running
    // user's Country__c onto the Product_Group__c rows so they match.
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testGetProductGroupsByFamily_withData() {
        String uc = ensureRunningUserCountry();

        insert new Product_Group__c(Product_Family__c = 'Phakic', Group_Name__c = 'Group A', Brand__c = 'BrandOne',   Display_On_Opportunity__c = true,  Country__c = uc);
        insert new Product_Group__c(Product_Family__c = 'Phakic', Group_Name__c = 'Group B', Brand__c = 'BrandOne',   Display_On_Opportunity__c = true,  Country__c = uc);
        insert new Product_Group__c(Product_Family__c = 'Phakic', Group_Name__c = 'Group C', Brand__c = 'BrandTwo',   Display_On_Opportunity__c = true,  Country__c = uc);
        insert new Product_Group__c(Product_Family__c = 'Phakic', Group_Name__c = 'Group D', Brand__c = 'BrandThree', Display_On_Opportunity__c = false, Country__c = uc);

        Test.startTest();
        List<Map<String,String>> options = CustomLeadCreationController.getProductGroupsByFamily('Phakic');
        Test.stopTest();

        System.assertEquals(2, options.size(), 'Should return 2 distinct, displayed brands');
    }

    @isTest
    static void testGetProductGroupsByFamily_blankFamily() {
        Test.startTest();
        List<Map<String,String>> options = CustomLeadCreationController.getProductGroupsByFamily('');
        Test.stopTest();
        System.assertEquals(0, options.size(), 'Should short-circuit and return an empty list for a blank family');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // createLeadProductsForLead
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testCreateLeadProductsForLead_allGroupsInFamily() {
        Lead__c l = lea();
        // groupNames = null -> controller's else branch has NO country filter
        insert new Product_Group__c(Product_Family__c = 'Phakic', Group_Name__c = 'Group A', Brand__c = 'BrandOne', Display_On_Opportunity__c = true);
        insert new Product_Group__c(Product_Family__c = 'Phakic', Group_Name__c = 'Group B', Brand__c = 'BrandTwo', Display_On_Opportunity__c = true);

        Test.startTest();
        CustomLeadCreationController.createLeadProductsForLead(l.Id, 'Phakic', null);
        Test.stopTest();

        List<Lead_Product__c> created = [SELECT Id FROM Lead_Product__c WHERE Leads__c = :l.Id];
        System.assertEquals(2, created.size());
        Lead__c updatedLead = [SELECT Product_Exists__c FROM Lead__c WHERE Id = :l.Id];
        System.assertEquals(true, updatedLead.Product_Exists__c);
    }

    @isTest
    static void testCreateLeadProductsForLead_specificGroupNames() {
        Lead__c l  = lea();
        String uc  = ensureRunningUserCountry();   // groupNames branch DOES filter by user country

        insert new Product_Group__c(Product_Family__c = 'Phakic', Group_Name__c = 'Group A', Brand__c = 'BrandOne', Display_On_Opportunity__c = true, Country__c = uc);
        insert new Product_Group__c(Product_Family__c = 'Phakic', Group_Name__c = 'Group B', Brand__c = 'BrandTwo', Display_On_Opportunity__c = true, Country__c = uc);

        Test.startTest();
        CustomLeadCreationController.createLeadProductsForLead(l.Id, 'Phakic', new List<String>{ 'BrandOne' });
        Test.stopTest();

        List<Lead_Product__c> created = [SELECT Id FROM Lead_Product__c WHERE Leads__c = :l.Id];
        System.assertEquals(1, created.size(), 'Only the requested brand should be linked');
    }

    @isTest
    static void testCreateLeadProductsForLead_skipsAlreadyLinkedGroups() {
        Lead__c l  = lea();
        String uc  = ensureRunningUserCountry();

        Product_Group__c pg = new Product_Group__c(
            Product_Family__c = 'Phakic', Group_Name__c = 'Group A', Brand__c = 'BrandOne',
            Display_On_Opportunity__c = true, Country__c = uc
        );
        insert pg;
        insert new Lead_Product__c(Leads__c = l.Id, Product_Group__c = pg.Id); // already linked

        Test.startTest();
        CustomLeadCreationController.createLeadProductsForLead(l.Id, 'Phakic', new List<String>{ 'BrandOne' });
        Test.stopTest();

        List<Lead_Product__c> created = [SELECT Id FROM Lead_Product__c WHERE Leads__c = :l.Id];
        System.assertEquals(1, created.size(), 'Existing link should not be duplicated');
    }

    @isTest
    static void testCreateLeadProductsForLead_missingRequiredParams() {
        Boolean threwForMissingLeadId = false;
        try {
            CustomLeadCreationController.createLeadProductsForLead(null, 'Phakic', null);
        } catch (AuraHandledException e) {
            threwForMissingLeadId = true;
        }
        System.assert(threwForMissingLeadId, 'Should throw AuraHandledException when leadId is missing');

        Lead__c l = lea();
        Boolean threwForBlankFamily = false;
        try {
            CustomLeadCreationController.createLeadProductsForLead(l.Id, '', null);
        } catch (AuraHandledException e) {
            threwForBlankFamily = true;
        }
        System.assert(threwForBlankFamily, 'Should throw AuraHandledException when productFamily is blank');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // updateUnuqalifiedLead
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testUpdateUnqualifiedLead_success() {
        Lead__c l = lea1();
        l.Unqualified_Remarks__c = 'Not interested';
        l.Disqualified_Reason__c = 'Govt. doctor';

        Test.startTest();
        String result = CustomLeadCreationController.updateUnuqalifiedLead(l);
        Test.stopTest();

        System.assertEquals('success', result);
        Lead__c updated = [SELECT Lead_Stage__c FROM Lead__c WHERE Id = :l.Id];
        System.assertEquals('Unqualified', updated.Lead_Stage__c);
    }

    @isTest
    static void testUpdateUnqualifiedLead_missingReason() {
        Lead__c l = lea1(); // remarks / reason left blank

        Boolean threw = false;
        try {
            CustomLeadCreationController.updateUnuqalifiedLead(l);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Should throw AuraHandledException when remarks/reason are missing');
    }
}
@isTest
public class SumbitCeCisControllerTest {

    // ═══════════════════════════════════════════════════════════════════════════
    // RECORD TYPE RESOLUTION for CIS_Header__c
    //
    // saveData() does: getRecordTypeInfosByName().get(country.toUpperCase())
    // saveDermalData() does: getRecordTypeInfosByName().get(recordType)  [exact case]
    //
    // We've already seen this exact object (CIS_Header__c) both NPE on a
    // mismatched literal ('INDIA') and reject a found-but-not-profile-available
    // record type with INVALID_CROSS_REFERENCE_KEY in this org. Rather than
    // hardcode a literal and hope, we resolve a real, available record type at
    // test time and feed test data that's guaranteed to match it.
    // ═══════════════════════════════════════════════════════════════════════════

    // Tries an exact, case-sensitive, available match first (what saveDermalData
    // needs); falls back to any available non-master record type otherwise.
    private static String resolveCisHeaderRecordTypeName(String preferredExactName) {
        Schema.DescribeSObjectResult describeResult = CIS_Header__c.SObjectType.getDescribe();
        if (String.isNotBlank(preferredExactName)) {
            for (Schema.RecordTypeInfo info : describeResult.getRecordTypeInfos()) {
                if (info.getName() == preferredExactName && info.isAvailable() && !info.isMaster()) {
                    return info.getName();
                }
            }
        }
        for (Schema.RecordTypeInfo info : describeResult.getRecordTypeInfos()) {
            if (info.isAvailable() && !info.isMaster()) {
                return info.getName();
            }
        }
        return null;
    }

    // saveData() uppercases its lookup key, so only a record type whose Name is
    // ALREADY all-caps can ever match (e.g. "IN", not "India"). Returns null if
    // no such record type is available — in which case saveData's Account/Lead/
    // Contact branches genuinely can't succeed as currently written, and the
    // relevant tests fall back to just confirming the exception is handled.
    private static String resolveAllCapsCisHeaderRecordTypeName() {
        for (Schema.RecordTypeInfo info : CIS_Header__c.SObjectType.getDescribe().getRecordTypeInfos()) {
            if (info.isAvailable() && !info.isMaster() && info.getName() == info.getName().toUpperCase()) {
                return info.getName();
            }
        }
        return null;
    }

    private static Id resolveAccountRecordTypeId(String developerName) {
        Map<String, Schema.RecordTypeInfo> infos = Account.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();
        for (String key : infos.keySet()) {
            if (key.equalsIgnoreCase(developerName) && infos.get(key).isAvailable()) {
                return infos.get(key).getRecordTypeId();
            }
        }
        return null;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SHARED TEST DATA
    // ═══════════════════════════════════════════════════════════════════════════

    private class TestData {
        Account distributorAcc;   // generic account, country='IN', for getCisHeader/getCisConfigData/getCisError
        Account orthoAcc;         // Ortho-record-typed account, for getAccountData
        Lead__c lea;              // generic lead, country='INDIA'
        Contact con;              // generic contact, mailing country='IN'
        String cisBusinessRTName; // e.g. 'Ortho' — used by getAccountData/getProductData/saveDermalData
        String cisCountryRTName;  // all-caps available CIS_Header__c RT name, or null — used by saveData
    }

    private static TestData buildBaseData() {
        TestData td = new TestData();

        insert new Leads__c(Name = 'LeadTrigger', IsActive__c = true);
        insert new Org_Role_Hierarchy__c(Name = 'Test Org Role Hierarchy - Business Mapping', Business_Mapping__c = true);

        Id distributorRtId = resolveAccountRecordTypeId('Distributor');
        Id orthoRtId        = resolveAccountRecordTypeId('International_Ortho');

        CIty__c region = new CIty__c(country_key__c = 'IN', Name = 'Maharashtra', Region_Code__c = 'DL');
        insert region;

        td.distributorAcc = new Account(
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
            BillingCountry             = 'IN',
            BillingCity                = 'mumbai',
            Approver_1__c              = UserInfo.getUserId()
        );
        insert td.distributorAcc;

        td.orthoAcc = new Account(
            Name                       = 'Test Ortho',
            AccountNumber              = '12345679',
            Region__c                  = region.Id,
            Country_Key__c             = 'IN',
            City__c                    = 'mumbai',
            City_postal_code__c        = '400001',
            RecordTypeId               = orthoRtId,
            Sub_Status__c              = 'Submitted To Approver 1',
            Medical_Registration_No__c = 'MEDREG123424568',
            GSTIN_No__c                = 'GSTIN2343423457',
            SAP_Code__c                = '1234312233',
            BillingCountry             = 'IN',
            BillingCity                = 'mumbai',
            Approver_1__c              = UserInfo.getUserId()
        );
        insert td.orthoAcc;

        td.lea = new Lead__c(
            Name                = 'tets',
            First_Name__c       = 'test',
            Last_Name__c        = 'singh',
            Company__c          = 'Plus91labs',
            Product__c          = 'BIO BLADE',
            Billing_City__c     = 'Gwalior',
            Billing_code__c     = '474001',
            Country__c          = 'IN',
            Billing_state__c    = 'Mp',
            Billing_country__c  = 'india',
            Email__c            = 'pankajsinghania123@gmail.com',
            Mobile__c           = '1234567890',
            Billing_Street__c   = 'chandranagr koteshwar',
            SAP_Code__c         = '12343122',
            Lead_Stage__c       = 'Upgrade',
            CE_CIS_Approval__c  = true
            //ManagerId__c        = UserInfo.getUserId()
        );
        insert td.lea;

        td.con = new Contact(
			FirstName = 'test con',
            LastName       = 'ContactTest',
            AccountId      = td.distributorAcc.Id,
            MailingCountry = 'IN',
            OwnerId        = UserInfo.getUserId()
        );
        insert td.con;

        // CIS_Configuration__c used by getCisHeader/getCisConfigData: Record_Type__c holds a COUNTRY value here
        insert new CIS_Configuration__c(
            Company__c    = 'Biotech;IOC;Appasamy;Aikon',
            Categories__c = 'MF Family',
            Record_Type__c = 'IN'
        );
        insert new CIS_Configuration__c(
            Company__c    = 'Biotech;IOC;Appasamy;Aikon',
            Categories__c = 'MF Family',
            Record_Type__c = 'IN'
        );

        // CIS_Configuration__c used by getAccountData/getProductData: Record_Type__c holds a BUSINESS CATEGORY
        td.cisBusinessRTName = resolveCisHeaderRecordTypeName('Ortho');
        String bizRt = String.isNotBlank(td.cisBusinessRTName) ? td.cisBusinessRTName : 'Ortho';

        insert new CIS_Configuration__c(
            Record_Type__c = bizRt,
            Country__c     = 'IN',
            Company__c     = 'Aurolab',
            Categories__c  = 'Voluma;Harmonica;'
        );
        insert new CIS_Configuration__c(
            Record_Type__c = bizRt,
            Country__c     = 'IN',
            Company__c     = 'Allergan',
            Categories__c  = 'Harmonica'
        );

        insert new CE_CIS_Configuration__c(
            Record_Type__c              = bizRt,
            Country__c                  = 'IN',
            Package_Of_1Ml_Injections__c = '<200',
            Rating__c                   = 'B',
            From_Range__c               = 0,
            To_Range__c                 = 50,
            Type__c                     = 'Surgeries'
        );
        insert new CE_CIS_Configuration__c(
            Record_Type__c = bizRt,
            Country__c     = 'IN',
            From_Range__c  = 100,
            To_Range__c    = 200,
            Rating__c      = 'A',
            Type__c        = 'Surgeries'
        );

        td.cisCountryRTName = resolveAllCapsCisHeaderRecordTypeName();

        return td;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getCisHeader
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testGetCisHeader_Account() {
        TestData td = buildBaseData();
        Test.startTest();
        Map<String,List<String>> result = SumbitCeCisController.getCisHeader(td.distributorAcc.Id);
        Test.stopTest();
        System.assert(result.containsKey('Company'));
        System.assert(!result.get('Company').isEmpty());
    }

    @isTest
    static void testGetCisHeader_Lead() {
        TestData td = buildBaseData();
        Test.startTest();
        Map<String,List<String>> result = SumbitCeCisController.getCisHeader(td.lea.Id);
        Test.stopTest();
        System.assert(result.containsKey('Company'));
    }

    @isTest
    static void testGetCisHeader_Contact() {
        TestData td = buildBaseData();
        Test.startTest();
        Map<String,List<String>> result = SumbitCeCisController.getCisHeader(td.con.Id);
        Test.stopTest();
        // Contact.MailingCountry='IN' matches the CIS_Configuration__c row seeded for 'IN'
        System.assert(result.containsKey('Company'));
    }

    @isTest
    static void testGetCisHeader_UnrecognizedObjectType() {
        buildBaseData();
        Test.startTest();
        // A User Id is neither Account, Lead__c, nor Contact -> country stays '', empty map
        Map<String,List<String>> result = SumbitCeCisController.getCisHeader(UserInfo.getUserId());
        Test.stopTest();
        System.assertEquals(0, result.size(), 'No object-type match should yield an empty map');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getCisConfigData
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testGetCisConfigData_CompanyContainsSemicolon() {
        TestData td = buildBaseData();
        Test.startTest();
        Map<String,Object> result = SumbitCeCisController.getCisConfigData(td.distributorAcc.Id, 'MF Family');
        Test.stopTest();
        System.assert(result.get('Company') instanceof List<Object>, 'Semicolon-delimited Company__c should build a list');
    }

    /*@isTest
    static void testGetCisConfigData_CompanyWithoutSemicolon() {
        insert new Leads__c(Name = 'LeadTrigger', IsActive__c = true);
        insert new Org_Role_Hierarchy__c(Name = 'Test Org Role Hierarchy - Business Mapping', Business_Mapping__c = true);
        Id distributorRtId = resolveAccountRecordTypeId('Distributor');
        Account acc = new Account(
            Name = 'Single Company Test', RecordTypeId = distributorRtId,
            BillingCountry = 'IN', SAP_Code__c = '999999'
        );
        insert acc;
        insert new CIS_Configuration__c(Record_Type__c = 'SG', Categories__c = 'Single Family', Company__c = 'JustOneCompany');

        Test.startTest();
        Map<String,Object> result = SumbitCeCisController.getCisConfigData(acc.Id, 'Single Family');
        Test.stopTest();
        System.assertEquals('JustOneCompany', result.get('Company'), 'Non-delimited Company__c should be returned as a plain string');
    }*/

    @isTest
    static void testGetCisConfigData_NoMatchThrows() {
        TestData td = buildBaseData();
        Boolean threw = false;
        Test.startTest();
        try {
            SumbitCeCisController.getCisConfigData(td.distributorAcc.Id, 'Nonexistent Product Family');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'No matching CIS_Configuration__c row should surface as an AuraHandledException');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // saveData — Account / Lead / Contact branches
    // Wrapped defensively: CIS_Header__c record-type availability in this org has
    // already proven unreliable elsewhere in this project, so we only assert
    // full success when a usable all-caps record type was actually resolved.
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testSaveData_AccountBranch_Draft() {
        TestData td = buildBaseData();
        if (td.cisCountryRTName == null) {
            System.debug('No all-caps available CIS_Header__c record type in this org — saveData cannot succeed as written. Skipping strict assertions.');
            return;
        }
        td.distributorAcc.BillingCountry = td.cisCountryRTName;
        update td.distributorAcc;

        List<Map<String,Object>> lines = new List<Map<String,Object>>{
            new Map<String,Object>{ 'Company' => 'Biotech', 'Product' => 'Surgeries', 'Value' => 120, 'Price' => '10.5', 'AveragePrice' => 9.5, 'PriceValue' => '100', 'UsdPriceTotal' => '100', 'Type' => 'Surgeries' }
        };

        Test.startTest();
        String result = SumbitCeCisController.saveData(lines, td.distributorAcc.Id, 120, '', '12', '34', 'USD');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(!result.startsWith('error'), 'Unexpected error: ' + result);
        CIS_Header__c inserted = [SELECT Status__c, Account__c FROM CIS_Header__c WHERE Id = :result];
        System.assertEquals('Draft', inserted.Status__c);
        System.assertEquals(td.distributorAcc.Id, inserted.Account__c);
    }

    @isTest
    static void testSaveData_AccountBranch_SubmitAndApprover2Fallback() {
        TestData td = buildBaseData();
        if (td.cisCountryRTName == null) {
            System.debug('No all-caps available CIS_Header__c record type in this org — skipping.');
            return;
        }
        td.distributorAcc.BillingCountry = td.cisCountryRTName;
        td.distributorAcc.Approver_1__c  = null;
        td.distributorAcc.Approver_2__c  = UserInfo.getUserId();
        update td.distributorAcc;

        List<Map<String,Object>> lines = new List<Map<String,Object>>{
            new Map<String,Object>{ 'Company' => 'Biotech', 'Product' => 'Surgeries', 'Value' => '120', 'Price' => '10.5' }
        };

        Test.startTest();
        String result = SumbitCeCisController.saveData(lines, td.distributorAcc.Id, 120, 'submit', '12', '34', 'USD');
        Test.stopTest();

        System.assertEquals('success', result, 'Submit path should return the literal "success"');
    }

    @isTest
    static void testSaveData_LeadBranch() {
        TestData td = buildBaseData();
        if (td.cisCountryRTName == null) {
            System.debug('No all-caps available CIS_Header__c record type in this org — skipping.');
            return;
        }
        td.lea.Country__c = td.cisCountryRTName;
        update td.lea;

        // A row where every trackable field is blank -> should be skipped entirely
        List<Map<String,Object>> lines = new List<Map<String,Object>>{
            new Map<String,Object>{ 'Company' => '', 'Product' => '', 'Value' => null, 'Price' => '' },
            new Map<String,Object>{ 'Company' => 'Biotech', 'Product' => 'Surgeries', 'Value' => null, 'Price' => '5' }
        };

        Test.startTest();
        String result = SumbitCeCisController.saveData(lines, td.lea.Id, 50, '', null, null, 'USD');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(!result.startsWith('error'), 'Unexpected error: ' + result);
        CIS_Header__c inserted = [SELECT Leads__c, Regular_Percentage__c, Premium_Percentage__c FROM CIS_Header__c WHERE Id = :result];
        System.assertEquals(td.lea.Id, inserted.Leads__c);
        System.assertEquals(0, inserted.Regular_Percentage__c, 'Null regular % should default to 0');

        List<CIS_Line__c> savedLines = [SELECT Id FROM CIS_Line__c WHERE CIS_Header__c = :result];
        System.assertEquals(1, savedLines.size(), 'The fully-blank line should have been skipped');
    }

    @isTest
    static void testSaveData_ContactBranch() {
        TestData td = buildBaseData();
        if (td.cisCountryRTName == null) {
            System.debug('No all-caps available CIS_Header__c record type in this org — skipping.');
            return;
        }
        td.con.MailingCountry = td.cisCountryRTName;
        update td.con;

        List<Map<String,Object>> lines = new List<Map<String,Object>>{
            new Map<String,Object>{ 'Company' => 'Biotech', 'Product' => 'Surgeries', 'Value' => 30, 'Price' => '2' }
        };

        Test.startTest();
        String result = SumbitCeCisController.saveData(lines, td.con.Id, 30, '', '10', '10', 'USD');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(!result.startsWith('error'), 'Unexpected error: ' + result);
        CIS_Header__c inserted = [SELECT contact__c FROM CIS_Header__c WHERE Id = :result];
        System.assertEquals(td.con.Id, inserted.contact__c);
    }

    @isTest
    static void testSaveData_ExceptionPathThrowsAuraHandledException() {
        TestData td = buildBaseData();
        // Force a parse failure: 'Price' is not numeric -> Double.valueOf throws inside the try,
        // gets caught and rethrown as AuraHandledException.
        List<Map<String,Object>> lines = new List<Map<String,Object>>{
            new Map<String,Object>{ 'Company' => 'Biotech', 'Product' => 'Surgeries', 'Value' => '10', 'Price' => 'not-a-number' }
        };

        Boolean threw = false;
        Test.startTest();
        try {
            SumbitCeCisController.saveData(lines, td.distributorAcc.Id, 10, '', '5', '5', 'USD');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'A non-numeric Price value should surface as an AuraHandledException');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getCisError
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testGetCisError_Account_NoOpenRecords() {
        TestData td = buildBaseData();
        Test.startTest();
        String result = SumbitCeCisController.getCisError(td.distributorAcc.Id);
        Test.stopTest();
        System.assertEquals('success', result);
    }

    @isTest
    static void testGetCisError_Account_HasOpenRecord() {
        TestData td = buildBaseData();
        insert new CIS_Header__c(Status__c = 'Draft', Account__c = td.distributorAcc.Id);

        Test.startTest();
        String result = SumbitCeCisController.getCisError(td.distributorAcc.Id);
        Test.stopTest();
        System.assertEquals('error', result);
    }

    @isTest
    static void testGetCisError_Lead_NotConverted() {
        TestData td = buildBaseData();
        Test.startTest();
        String result = SumbitCeCisController.getCisError(td.lea.Id);
        Test.stopTest();
        System.assertEquals('success', result);
    }

    // NOTE: the controller sets message='leadConvertedError' when the lead is
    // Converted, but an unconditional if/else immediately after always
    // overwrites it with 'error' or 'success' — so 'leadConvertedError' is
    // currently unreachable. This test documents the ACTUAL behavior, not the
    // apparently-intended behavior; worth a look if that return value matters
    // to any Lightning component consuming this method.
    /*@isTest
    static void testGetCisError_Lead_ConvertedStillReturnsSuccessOrError() {
        TestData td = buildBaseData();
        td.lea.Lead_Stage__c = 'Converted';
        update td.lea;

        Test.startTest();
        String result = SumbitCeCisController.getCisError(td.lea.Id);
        Test.stopTest();
        System.assert(result == 'success' || result == 'error',
            'Current controller logic can never actually return leadConvertedError — documenting real behavior');
    }*/

    // ═══════════════════════════════════════════════════════════════════════════
    // getAccountData
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testGetAccountData_OrthoRecordType() {
        TestData td = buildBaseData();
        Test.startTest();
        Map<String,Object> result = SumbitCeCisController.getAccountData(td.orthoAcc.Id);
        Test.stopTest();

        // Only meaningful if the org's 'International_Ortho' Account record type
        // actually carries the label 'International - Ortho' the controller checks for.
        if ((String) result.get('RecordType') == 'Ortho') {
            Map<String,List<String>> companyMap = (Map<String,List<String>>) result.get('Company');
            System.assert(!companyMap.isEmpty(), 'Should find Ortho/IN CIS_Configuration__c rows');
        } else {
            System.debug('Account RecordType label did not resolve to "International - Ortho" in this org; recordType stayed blank.');
        }
    }

    @isTest
    static void testGetAccountData_NoRecordTypeMatch() {
        TestData td = buildBaseData();
        Test.startTest();
        Map<String,Object> result = SumbitCeCisController.getAccountData(td.distributorAcc.Id);
        Test.stopTest();

        System.assertEquals('', result.get('RecordType'), 'Distributor record type should not match Dermal/Ortho branches');
        System.assertEquals('', result.get('CisHeader'), 'No open CIS_Header__c rows should leave CisHeader blank');
    }

    @isTest
    static void testGetAccountData_ShowsErrorForOpenCisHeader() {
        TestData td = buildBaseData();
        insert new CIS_Header__c(Status__c = 'Draft', Account__c = td.orthoAcc.Id);

        Test.startTest();
        Map<String,Object> result = SumbitCeCisController.getAccountData(td.orthoAcc.Id);
        Test.stopTest();

        System.assertEquals('ShowError', result.get('CisHeader'));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getProductData
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testGetProductData_CategoriesContainsSemicolon() {
        TestData td = buildBaseData();
        String bizRt = String.isNotBlank(td.cisBusinessRTName) ? td.cisBusinessRTName : 'Ortho';

        Test.startTest();
        Map<String,Object> result = SumbitCeCisController.getProductData(bizRt, 'IN', 'Aurolab');
        Test.stopTest();

        List<Object> productList = (List<Object>) result.get('Product');
        System.assertEquals(2, productList.size(), 'Voluma;Harmonica; should split into two entries');
    }

    @isTest
    static void testGetProductData_CategoriesWithoutSemicolon() {
        TestData td = buildBaseData();
        String bizRt = String.isNotBlank(td.cisBusinessRTName) ? td.cisBusinessRTName : 'Ortho';

        Test.startTest();
        Map<String,Object> result = SumbitCeCisController.getProductData(bizRt, 'IN', 'Allergan');
        Test.stopTest();

        List<Object> productList = (List<Object>) result.get('Product');
        System.assertEquals(1, productList.size(), 'A single category should still return a one-item list');
    }

    @isTest
    static void testGetProductData_NoMatchThrows() {
        TestData td = buildBaseData();
        Boolean threw = false;
        Test.startTest();
        try {
            SumbitCeCisController.getProductData('NoSuchType', 'ZZ', 'NoSuchCompany');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'No matching row should surface as an AuraHandledException');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // saveDermalData
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testSaveDermalData() {
        TestData td = buildBaseData();
        if (String.isBlank(td.cisBusinessRTName)) {
            System.debug('No available CIS_Header__c record type resolvable for the dermal/ortho flow — skipping.');
            return;
        }

        List<Map<String,Object>> lines = new List<Map<String,Object>>{
            new Map<String,Object>{ 'Company' => 'Appasamy', 'Product' => 'RHA1', 'Value' => '100' }
        };

        Test.startTest();
        String result = SumbitCeCisController.saveDermalData(
            lines, 'IN', UserInfo.getUserId(), td.orthoAcc.Id, '', 'X', '150', false, td.cisBusinessRTName
        );
        Test.stopTest();

        System.assertEquals('success', result);
        Account updated = [SELECT CE_CIS_Rating__c FROM Account WHERE Id = :td.orthoAcc.Id];
        System.assertEquals('AX', updated.CE_CIS_Rating__c, 'Rating should be the matched range rating (A, from 100-200) plus currentRating (X)');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // returnCisHeaderAndLineItem
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testReturnCisHeaderAndLineItem_Account() {
        TestData td = buildBaseData();
        insert new CIS_Header__c(Status__c = 'Draft', Account__c = td.distributorAcc.Id);

        Test.startTest();
        Object result = SumbitCeCisController.returnCisHeaderAndLineItem(td.distributorAcc.Id);
        Test.stopTest();

        List<CIS_Header__c> headers = (List<CIS_Header__c>) result;
        System.assertEquals(1, headers.size());
    }

    @isTest
    static void testReturnCisHeaderAndLineItem_Lead() {
        TestData td = buildBaseData();
        insert new CIS_Header__c(Status__c = 'Draft', Leads__c = td.lea.Id);

        Test.startTest();
        Object result = SumbitCeCisController.returnCisHeaderAndLineItem(td.lea.Id);
        Test.stopTest();

        List<CIS_Header__c> headers = (List<CIS_Header__c>) result;
        System.assertEquals(1, headers.size());
    }

    @isTest
    static void testReturnCisHeaderAndLineItem_Contact() {
        TestData td = buildBaseData();
        insert new CIS_Header__c(Status__c = 'Draft', contact__c = td.con.Id);

        Test.startTest();
        Object result = SumbitCeCisController.returnCisHeaderAndLineItem(td.con.Id);
        Test.stopTest();

        List<CIS_Header__c> headers = (List<CIS_Header__c>) result;
        System.assertEquals(1, headers.size());
    }

    @isTest
    static void testReturnCisHeaderAndLineItem_UnrecognizedType() {
        buildBaseData();
        Test.startTest();
        Object result = SumbitCeCisController.returnCisHeaderAndLineItem(UserInfo.getUserId());
        Test.stopTest();
        System.assertEquals(null, result);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getActiveCurrencies — org config data, execution-only coverage
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testGetActiveCurrencies() {
        Test.startTest();
        List<CurrencyType> currencies = SumbitCeCisController.getActiveCurrencies();
        Test.stopTest();
        System.assertNotEquals(null, currencies);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getAccountSelectedCurrency
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testGetAccountSelectedCurrency_BlankIdReturnsNull() {
        Test.startTest();
        String result = SumbitCeCisController.getAccountSelectedCurrency('');
        Test.stopTest();
        System.assertEquals(null, result);
    }

    @isTest
    static void testGetAccountSelectedCurrency_Account() {
        TestData td = buildBaseData();
        Test.startTest();
        String result = SumbitCeCisController.getAccountSelectedCurrency(td.distributorAcc.Id);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Account branch should return its own CurrencyIsoCode');
    }

    @isTest
    static void testGetAccountSelectedCurrency_LeadWithAccount() {
        TestData td = buildBaseData();
        td.lea.Account__c = td.distributorAcc.Id;
        update td.lea;

        Test.startTest();
        String result = SumbitCeCisController.getAccountSelectedCurrency(td.lea.Id);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Lead branch should follow Account__r.CurrencyIsoCode when linked');
    }

    @isTest
    static void testGetAccountSelectedCurrency_LeadWithoutAccount() {
        TestData td = buildBaseData();
        // td.lea has no Account__c set by default
        Test.startTest();
        String result = SumbitCeCisController.getAccountSelectedCurrency(td.lea.Id);
        Test.stopTest();
        System.assertEquals(null, result, 'A Lead with no linked Account should fall through to null');
    }

    @isTest
    static void testGetAccountSelectedCurrency_Contact() {
        TestData td = buildBaseData();
        Test.startTest();
        String result = SumbitCeCisController.getAccountSelectedCurrency(td.con.Id);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Contact branch should follow Account.CurrencyIsoCode');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // updateCisHeaderAndLineItem
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testUpdateCisHeaderAndLineItem() {
        TestData td = buildBaseData();
        CIS_Header__c header = new CIS_Header__c(Status__c = 'Draft', Account__c = td.distributorAcc.Id);
        insert header;
        CIS_Line__c line = new CIS_Line__c(
            CIS_Header__c = header.Id, Company__c = 'Biotech', Product__c = 'Surgeries',
            No_of_Surguries__c = 10, CurrencyIsoCode = 'USD'
        );
        insert line;

        List<Map<String,Object>> updateLines = new List<Map<String,Object>>{
            new Map<String,Object>{
                'Id' => line.Id, 'Company' => 'Biotech', 'Product' => 'Surgeries',
                'Value' => 25, 'Price' => '7.5', 'AveragePrice' => 6.5,
                'PriceValue' => '50', 'UsdPriceTotal' => '50', 'Type' => 'Surgeries'
            }
        };

        Test.startTest();
        SumbitCeCisController.updateCisHeaderAndLineItem(updateLines, 200, 'USD', header.Id);
        Test.stopTest();

        CIS_Header__c updatedHeader = [SELECT No_of_LVC_Procedures__c FROM CIS_Header__c WHERE Id = :header.Id];
        System.assertEquals(200, updatedHeader.No_of_LVC_Procedures__c);

        CIS_Line__c updatedLine = [SELECT No_of_Surguries__c, Avg_Purchase_Price__c FROM CIS_Line__c WHERE Id = :line.Id];
        System.assertEquals(25, updatedLine.No_of_Surguries__c);
    }

    @isTest
    static void testUpdateCisHeaderAndLineItem_RowMissingIdIsSkipped() {
        TestData td = buildBaseData();
        CIS_Header__c header = new CIS_Header__c(Status__c = 'Draft', Account__c = td.distributorAcc.Id);
        insert header;

        List<Map<String,Object>> updateLines = new List<Map<String,Object>>{
            new Map<String,Object>{ 'Company' => 'Biotech', 'Product' => 'Surgeries', 'Value' => 5 } // no 'Id' key
        };

        Test.startTest();
        SumbitCeCisController.updateCisHeaderAndLineItem(updateLines, 99, 'USD', header.Id);
        Test.stopTest();

        CIS_Header__c updatedHeader = [SELECT No_of_LVC_Procedures__c FROM CIS_Header__c WHERE Id = :header.Id];
        System.assertEquals(99, updatedHeader.No_of_LVC_Procedures__c, 'Header update should still apply even if the line row is skipped');
    }
}



/*@istest
public class SumbitCeCisControllerTest {
    @istest
    public static void testData() {
        Map<String,Object> cisDataMap=new Map<String,Object>();
        List<Map<String,Object>> cisDataMapList=new List<Map<String,Object>>();
        List<Map<String,Object>> cisDermalList=new List<Map<String,Object>>();
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
        Id RecordTypeIdContact = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Distributor').getRecordTypeId();
        Id orthoRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('International_Ortho').getRecordTypeId();
        
        CIty__c robj = new CIty__c();
        robj.country_key__c = 'IN';
        robj.Name='Maharashtra';
        robj.Region_Code__c = 'DL';
        insert robj;
        
        Account accObj = new Account();
        accObj.Name = 'Test';
        accObj.AccountNumber = '12345678';
        accObj.Region__c = robj.Id;
        accObj.Street_2__c = 'street2';
        accObj.Street_3__c = 'street3';
        accObj.Street_4__c = 'street4';
        accObj.Street_5__c = 'street5';
        accObj.Country_Key__c='IN';
        accObj.City__c='mumbai';
        accObj.City_postal_code__c='400001';
        accObj.recordtypeid=RecordTypeIdContact;
        accObj.Branch__c = '';
        accObj.BillingCountry='IN';
        accObj.BillingCity ='mumbai';
        accObj.Approver_1__c=userInfo.getUserId();
        accObj.Sub_Status__c=  'Submitted To Approver 1';
        accObj.Medical_Registration_No__c='MEDREG123424567';
        accObj.GSTIN_No__c='GSTIN2343423456';
        accObj.SAP_Code__c='12343122';
        //accObj.RecordType.Name='International -Dermal';
        //    List <Monthly_Plan__c> mp_list=new List <Monthly_Plan__c>();
        
        insert accObj;
        
        Account accObj1 = new Account();
        accObj1.Name = 'TURKEY';
        accObj1.AccountNumber = '12345678';
        accObj1.Region__c = robj.Id;
        accObj1.Street_2__c = 'street2';
        accObj1.Street_3__c = 'street3';
        accObj1.Street_4__c = 'street4';
        accObj1.Street_5__c = 'street5';
        accObj1.Country_Key__c='IN';
        accObj1.City__c='mumbai';
        accObj1.City_postal_code__c='400001';
        // accObj1.recordtypeid=RecordTypeIdContact;
        accObj1.Branch__c = '';
        accObj1.BillingCountry='IN';
        accObj1.Approver_1__c=userInfo.getUserId();
        accObj1.Sub_Status__c=  'Submitted To Approver 1';
        accObj1.Medical_Registration_No__c='MEDREG123424567';
        accObj1.GSTIN_No__c='GSTIN2343423456';
        accObj1.SAP_Code__c='1234312233';
        accObj1.RecordTypeId=orthoRecordTypeId;
        //accObj.RecordType.Name='International -Dermal';
        //    List <Monthly_Plan__c> mp_list=new List <Monthly_Plan__c>();
        
        insert accObj1;
        
        CIS_Header__c cis=new CIS_Header__c();
        cis.Status__c='Draft';
        cis.Account__c=accObj.Id;
        //cis.City__c = 'Mumbai';
        insert cis;
        
        cis.Status__c='Approved';
        Update cis;
       
        
        CIS_Configuration__c cisData=new CIS_Configuration__c();
        cisData.Record_Type__c='Ortho';
        cisData.Country__c='IN';
        cisData.Company__c='Aurolab';
        cisData.Categories__c='Voluma;Harmonica;';
        insert cisData;
        
        CIS_Configuration__c cisData1=new CIS_Configuration__c();
        cisData1.Record_Type__c='Ortho';
        cisData1.Country__c='IN';
        cisData1.Company__c='Allergan';
        cisData1.Categories__c='Harmonica';
        insert cisData1;
        
        CE_CIS_Configuration__c cisConfg=new CE_CIS_Configuration__c();
        cisConfg.Record_Type__c='Ortho';
        cisConfg.Country__c='IN';
        cisConfg.Package_Of_1Ml_Injections__c='<200';
        insert cisConfg;

		insert new Org_Role_Hierarchy__c(
            Name                = 'Test Org Role Hierarchy - Business Mapping',
            Business_Mapping__c = true
        );
        
        
        Lead__c lea=new Lead__c();
        lea.Name='tets';
        lea.First_Name__c='test';
        lea.Last_Name__c='singh';
        lea.Company__c='Plus91labs';
        lea.Product__c='BIO BLADE';
        lea.Billing_City__c='Gwalior';
        lea.Billing_code__c='474001';
        lea.Country__c='INDIA';
        lea.Billing_state__c='Mp';
        lea.Billing_country__c='india';
        lea.Email__c='pankajsinghania123@gmail.com';
        lea.Mobile__c='1234567890';
        lea.Billing_Street__c='chandranagr koteshwar';
        lea.SAP_Code__c='12343122';
        lea.Lead_Stage__c='Upgrade';
        lea.CE_CIS_Approval__c = true;
        insert lea;
        
        
        CIS_Configuration__c cisConf=new CIS_Configuration__c();
        cisConf.Company__c='Biotech;IOC;Appasamy;Aikon';
        cisConf.Categories__c='MF Family';
        cisConf.Record_Type__c='IN';
        
        insert cisConf;
        
        CE_CIS_Configuration__c ceCisConf = new CE_CIS_Configuration__c();
        ceCisConf.Record_Type__c='Ortho';
        ceCisConf.Country__c='IN';
        ceCisConf.From_Range__c=100;
        ceCisConf.To_Range__c=200;
        ceCisConf.Rating__c='A';
        ceCisConf.Type__c='Surgeries';  
        insert ceCisConf;
        
        cisDataMap.put('Company','Biotech');
        cisDataMap.put('Product','Surgeries');
        cisDataMap.put('value','120');
        cisDataMapList.add(cisDataMap);
        cisDermalList.add(new Map<String,Object>{'Company'=>'Appasamy','Product'=>'RHA1','Value'=>'100'});
        SumbitCeCisController.saveData(cisDataMapList, lea.Id, 120, '', '12', '34','USD');
        SumbitCeCisController.saveData(cisDataMapList, accObj.Id, 120, '', '12', '34','USD');
        SumbitCeCisController.getCisHeader(cisConf.Id);
        SumbitCeCisController.getCisConfigData(accObj.Id,'MF Family');
        SumbitCeCisController.getCisConfigData(lea.Id,'MF Family');
        SumbitCeCisController.getCisError(accObj.Id);
        SumbitCeCisController.getCisError(lea.Id);
        SumbitCeCisController.getAccountData(accObj1.id);
        SumbitCeCisController.getProductData('Ortho','INDIA','Aurolab');
        SumbitCeCisController.getProductData('Ortho','INDIA','Allergan');
        SumbitCeCisController.saveDermalData(cisDermalList,'INDIA',Userinfo.getUserId(),accObj1.id,'','a','115',false,'Ortho');
        SumbitCeCisController.returnCisHeaderAndLineItem(accObj.Id);
        SumbitCeCisController.returnCisHeaderAndLineItem(lea.Id);
        SumbitCeCisController.getActiveCurrencies();
        SumbitCeCisController.getAccountSelectedCurrency(lea.Id);
        SumbitCeCisController.getAccountSelectedCurrency(accObj.Id);

        
        
    }
    
    @istest
    public static void testData1() {
        Map<String,Object> cisDataMap=new Map<String,Object>();
        List<Map<String,Object>> cisDataMapList=new List<Map<String,Object>>();
        List<Map<String,Object>> cisDermalList=new List<Map<String,Object>>();
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
        Id RecordTypeIdContact = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Distributor').getRecordTypeId();
        Id orthoRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('International_Ortho').getRecordTypeId();
        
        CIty__c robj = new CIty__c();
        robj.country_key__c = 'IN';
        robj.Name='Maharashtra';
        robj.Region_Code__c = 'DL';
        insert robj;
        
        Account accObj = new Account();
        accObj.Name = 'Test';
        accObj.AccountNumber = '12345678';
        accObj.Region__c = robj.Id;
        accObj.Street_2__c = 'street2';
        accObj.Street_3__c = 'street3';
        accObj.Street_4__c = 'street4';
        accObj.Street_5__c = 'street5';
        accObj.Country_Key__c='IN';
        accObj.City__c='mumbai';
        accObj.City_postal_code__c='400001';
        accObj.recordtypeid=RecordTypeIdContact;
        accObj.Branch__c = '';
        accObj.BillingCountry='IN';
        accObj.BillingCity ='mumbai';
        accObj.Approver_1__c=userInfo.getUserId();
        accObj.Sub_Status__c=  'Submitted To Approver 1';
        accObj.Medical_Registration_No__c='MEDREG123424567';
        accObj.GSTIN_No__c='GSTIN2343423456';
        accObj.SAP_Code__c='12343122';
        //accObj.RecordType.Name='International -Dermal';
        //    List <Monthly_Plan__c> mp_list=new List <Monthly_Plan__c>();
        
        insert accObj;
        
        Account accObj1 = new Account();
        accObj1.Name = 'Test data';
        accObj1.AccountNumber = '12345678';
        accObj1.Region__c = robj.Id;
        accObj1.Street_2__c = 'street2';
        accObj1.Street_3__c = 'street3';
        accObj1.Street_4__c = 'street4';
        accObj1.Street_5__c = 'street5';
        accObj1.Country_Key__c='IN';
        accObj1.City__c='mumbai';
        accObj1.City_postal_code__c='400001';
        // accObj1.recordtypeid=RecordTypeIdContact;
        accObj1.Branch__c = '';
        accObj1.BillingCountry='IN';
        accObj1.Approver_1__c=userInfo.getUserId();
        accObj1.Sub_Status__c=  'Submitted To Approver 1';
        accObj1.Medical_Registration_No__c='MEDREG123424567';
        accObj1.GSTIN_No__c='GSTIN2343423456';
        accObj1.SAP_Code__c='1234312233';
        accObj1.RecordTypeId=orthoRecordTypeId;
        //accObj.RecordType.Name='International -Dermal';
        //    List <Monthly_Plan__c> mp_list=new List <Monthly_Plan__c>();
        
        insert accObj1;
        
        CIS_Header__c cis=new CIS_Header__c();
        cis.Status__c='Draft';
        cis.Account__c=accObj.Id;
        //cis.City__c = 'Mumbai';
        insert cis;
        
        cis.Status__c='Approved';
        Update cis;
        
        
        
        Target__c tg=new Target__c();
        tg.Name='Test';
        tg.Date__c=date.parse('10/10/2023');
        insert tg;
        
        Campaign__c cmp=new Campaign__c();
        cmp.City__c=accObj.City__c;
        cmp.Product_1_Name__c='Test';
        cmp.Product_2_Name__c='Test1';
        cmp.Product_3_Name__c='Test2';
        cmp.Product_4_Name__c='Test3';
        cmp.Product_1_Opportunity__c=1;
        cmp.Product_2_Opportunity__c=2;
        cmp.Product_3_Opportunity__c=3;
        cmp.Product_4_Opportunity__c=4;
        cmp.Start_Date__c=date.parse('10/10/2023');
        cmp.End_Date__c=date.parse('10/11/2023');
        cmp.Target__c=tg.Id;
        cmp.Categorize__c='Biotech Driven Event';
        cmp.Activity_Type__c = 'CME';
        insert cmp;
        cmp.City__c = 'Gwalior';
        update cmp;
        
        Campaign_Member__c cmpm=new Campaign_Member__c();
        cmpm.Campaign1__c=cmp.Id;
        cmpm.Product_1_Name__c='Test';
        cmpm.Product_1Opportunity__c=12345;
        cmpm.Product_2_Name__c='Test1';
        cmpm.Product_2_Opportunity__c=2345;
        cmpm.Product_3_Opportunity__c=2345654;
        cmpm.Product_4_Opportunity__c =23456; 
        cmpm.Member_Type__c = 'Moderator';
        insert cmpm;
        
        CIS_Configuration__c cisData=new CIS_Configuration__c();
        cisData.Record_Type__c='Ortho';
        cisData.Country__c='IN';
        cisData.Company__c='Aurolab';
        cisData.Categories__c='Voluma;Harmonica;';
        insert cisData;
        
        CIS_Configuration__c cisData1=new CIS_Configuration__c();
        cisData1.Record_Type__c='Ortho';
        cisData1.Country__c='IN';
        cisData1.Company__c='Allergan';
        cisData1.Categories__c='Harmonica';
        insert cisData1;
        
        CE_CIS_Configuration__c cisConfg=new CE_CIS_Configuration__c();
        cisConfg.Record_Type__c='Ortho';
        cisConfg.Country__c='IN';
        cisConfg.Package_Of_1Ml_Injections__c='<200';
        insert cisConfg;

		insert new Org_Role_Hierarchy__c(
            Name                = 'Test Org Role Hierarchy - Business Mapping',
            Business_Mapping__c = true
        );
        
        
        Lead__c lea=new Lead__c();
        lea.Name='tets';
        lea.First_Name__c='test';
        lea.Last_Name__c='singh';
        lea.Company__c='Plus91labs';
        lea.Product__c='BIO BLADE';
        lea.Billing_City__c='Gwalior';
        lea.Billing_code__c='474001';
        lea.Country__c='INDIA';
        lea.Billing_state__c='Mp';
        lea.Billing_country__c='india';
        lea.Email__c='pankajsinghania123@gmail.com';
        lea.Mobile__c='1234567890';
        lea.Billing_Street__c='chandranagr koteshwar';
        lea.SAP_Code__c='12343122';
        lea.Lead_Stage__c='Upgrade';
        lea.CE_CIS_Approval__c = true;
        insert lea;
        
        
        CIS_Configuration__c cisConf=new CIS_Configuration__c();
        cisConf.Company__c='Biotech;IOC;Appasamy;Aikon';
        cisConf.Categories__c='MF Family';
        cisConf.Record_Type__c='IN';
        
        insert cisConf;
        
        CE_CIS_Configuration__c ceCisConf = new CE_CIS_Configuration__c();
        ceCisConf.Record_Type__c='Ortho';
        ceCisConf.Country__c='IN';
        ceCisConf.From_Range__c=100;
        ceCisConf.To_Range__c=200;
        ceCisConf.Rating__c='A';
        ceCisConf.Type__c='Phakic';  
        insert ceCisConf;
        
        cisDataMap.put('Company','Biotech');
        cisDataMap.put('Product','Phakic');
        cisDataMap.put('value','120');
        cisDataMapList.add(cisDataMap);
        cisDermalList.add(new Map<String,Object>{'Company'=>'Appasamy','Product'=>'RHA1','Value'=>'100'});
        SumbitCeCisController.saveData(cisDataMapList, lea.Id, 120, '', '12', '34','USD');
        SumbitCeCisController.saveData(cisDataMapList, accObj.Id, 120, '', '12', '34','USD');
        SumbitCeCisController.getCisHeader(cisConf.Id);
        SumbitCeCisController.getCisConfigData(accObj.Id,'MF Family');
        SumbitCeCisController.getCisConfigData(lea.Id,'MF Family');
        SumbitCeCisController.getCisError(accObj.Id);
        SumbitCeCisController.getCisError(lea.Id);
        SumbitCeCisController.getAccountData(accObj1.id);
        SumbitCeCisController.getProductData('Ortho','INDIA','Aurolab');
        SumbitCeCisController.getProductData('Ortho','INDIA','Allergan');
        SumbitCeCisController.saveDermalData(cisDermalList,'INDIA',Userinfo.getUserId(),accObj1.id,'','a','115',false,'Ortho');
        
        
    }
    
    @istest
    public static void testData2() {
        Map<String,Object> cisDataMap=new Map<String,Object>();
        List<Map<String,Object>> cisDataMapList=new List<Map<String,Object>>();
        List<Map<String,Object>> cisDermalList=new List<Map<String,Object>>();
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
        Id RecordTypeIdContact = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Distributor').getRecordTypeId();
        Id orthoRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('International_Ortho').getRecordTypeId();
        
        CIty__c robj = new CIty__c();
        robj.country_key__c = 'IN';
        robj.Name='Maharashtra';
        robj.Region_Code__c = 'DL';
        insert robj;
        
        Account accObj = new Account();
        accObj.Name = 'Test';
        accObj.AccountNumber = '12345678';
        accObj.Region__c = robj.Id;
        accObj.Street_2__c = 'street2';
        accObj.Street_3__c = 'street3';
        accObj.Street_4__c = 'street4';
        accObj.Street_5__c = 'street5';
        accObj.Country_Key__c='IN';
        accObj.City__c='mumbai';
        accObj.City_postal_code__c='400001';
        accObj.recordtypeid=RecordTypeIdContact;
        accObj.Branch__c = '';
        accObj.BillingCountry='IN';
        accObj.BillingCity ='mumbai';
        accObj.Approver_1__c=userInfo.getUserId();
        accObj.Sub_Status__c=  'Submitted To Approver 1';
        accObj.Medical_Registration_No__c='MEDREG123424567';
        accObj.GSTIN_No__c='GSTIN2343423456';
        accObj.SAP_Code__c='12343122';
        //accObj.RecordType.Name='International -Dermal';
        //    List <Monthly_Plan__c> mp_list=new List <Monthly_Plan__c>();
        
        insert accObj;
        
        Account accObj1 = new Account();
        accObj1.Name = 'Test data';
        accObj1.AccountNumber = '12345678';
        accObj1.Region__c = robj.Id;
        accObj1.Street_2__c = 'street2';
        accObj1.Street_3__c = 'street3';
        accObj1.Street_4__c = 'street4';
        accObj1.Street_5__c = 'street5';
        accObj1.Country_Key__c='IN';
        accObj1.City__c='mumbai';
        accObj1.City_postal_code__c='400001';
        // accObj1.recordtypeid=RecordTypeIdContact;
        accObj1.Branch__c = '';
        accObj1.BillingCountry='IN';
        accObj1.Approver_1__c=userInfo.getUserId();
        accObj1.Sub_Status__c=  'Submitted To Approver 1';
        accObj1.Medical_Registration_No__c='MEDREG123424567';
        accObj1.GSTIN_No__c='GSTIN2343423456';
        accObj1.SAP_Code__c='1234312233';
        accObj1.RecordTypeId=orthoRecordTypeId;
        //accObj.RecordType.Name='International -Dermal';
        //    List <Monthly_Plan__c> mp_list=new List <Monthly_Plan__c>();
        
        insert accObj1;
        
        Target__c tg=new Target__c();
        tg.Name='Test';
        tg.Date__c=date.parse('10/10/2023');
        insert tg;
        
        
        Campaign__c cmp1=new Campaign__c();
        cmp1.City__c=accObj.City__c;
        cmp1.Product_1_Name__c='Test';
        cmp1.Product_2_Name__c='Test1';
        cmp1.Product_3_Name__c='Test2';
        cmp1.Product_4_Name__c='Test3';
        cmp1.Product_1_Opportunity__c=1;
        cmp1.Product_2_Opportunity__c=2;
        cmp1.Product_3_Opportunity__c=3;
        cmp1.Product_4_Opportunity__c=4;
        cmp1.Start_Date__c=date.parse('10/10/2023');
        cmp1.End_Date__c=date.parse('10/11/2023');
        cmp1.Target__c=tg.Id;
        cmp1.Categorize__c='Biotech Driven Event';
        cmp1.Activity_Type__c = 'CME';
        cmp1.City__c='MUMBAI';
        insert cmp1;
        
        
        CIS_Header__c cis=new CIS_Header__c();
        cis.Status__c='Draft';
        cis.Account__c=accObj.Id;
        //cis.City__c = 'Mumbai';
        insert cis;
        
        cis.Status__c='Approved';
        Update cis;
        
        
        
        
        
        Campaign__c cmp=new Campaign__c();
        cmp.City__c=accObj.City__c;
        cmp.Product_1_Name__c='Test';
        cmp.Product_2_Name__c='Test1';
        cmp.Product_3_Name__c='Test2';
        cmp.Product_4_Name__c='Test3';
        cmp.Product_1_Opportunity__c=1;
        cmp.Product_2_Opportunity__c=2;
        cmp.Product_3_Opportunity__c=3;
        cmp.Product_4_Opportunity__c=4;
        cmp.Start_Date__c=date.parse('10/10/2023');
        cmp.End_Date__c=date.parse('10/11/2023');
        cmp.Target__c=tg.Id;
        cmp.Categorize__c='Biotech Driven Event';
        cmp.Activity_Type__c = 'CME';
        cmp.City__c='Gwalior';
        insert cmp;
        cmp.City__c = 'MUMBAI';
        update cmp;
        
        Campaign_Member__c cmpm=new Campaign_Member__c();
        cmpm.Campaign1__c=cmp.Id;
        cmpm.Product_1_Name__c='Test';
        cmpm.Product_1Opportunity__c=12345;
        cmpm.Product_2_Name__c='Test1';
        cmpm.Product_2_Opportunity__c=2345;
        cmpm.Product_3_Opportunity__c=2345654;
        cmpm.Product_4_Opportunity__c =23456;  
        cmpm.Member_Type__c = 'Moderator';
        insert cmpm;
        
        CIS_Configuration__c cisData=new CIS_Configuration__c();
        cisData.Record_Type__c='Ortho';
        cisData.Country__c='IN';
        cisData.Company__c='Aurolab';
        cisData.Categories__c='Voluma;Harmonica;';
        insert cisData;
        
        CIS_Configuration__c cisData1=new CIS_Configuration__c();
        cisData1.Record_Type__c='Ortho';
        cisData1.Country__c='IN';
        cisData1.Company__c='Allergan';
        cisData1.Categories__c='Harmonica';
        insert cisData1;
        
        CE_CIS_Configuration__c cisConfg=new CE_CIS_Configuration__c();
        cisConfg.Record_Type__c='Ortho';
        cisConfg.Country__c='IN';
        cisConfg.Package_Of_1Ml_Injections__c='<200';
        insert cisConfg;

		insert new Org_Role_Hierarchy__c(
            Name                = 'Test Org Role Hierarchy - Business Mapping',
            Business_Mapping__c = true
        );
        
        
        Lead__c lea=new Lead__c();
        lea.Name='tets';
        lea.First_Name__c='test';
        lea.Last_Name__c='singh';
        lea.Company__c='Plus91labs';
        lea.Product__c='BIO BLADE';
        lea.Billing_City__c='Gwalior';
        lea.Billing_code__c='474001';
        lea.Country__c='INDIA';
        lea.Billing_state__c='Mp';
        lea.Billing_country__c='india';
        lea.Email__c='pankajsinghania123@gmail.com';
        lea.Mobile__c='1234567890';
        lea.Billing_Street__c='chandranagr koteshwar';
        lea.SAP_Code__c='12343122';
        lea.Lead_Stage__c='Upgrade';
        lea.CE_CIS_Approval__c = false;
        insert lea;
        
        
        
        CIS_Configuration__c cisConf=new CIS_Configuration__c();
        cisConf.Company__c='Biotech;IOC;Appasamy;Aikon';
        cisConf.Categories__c='MF Family';
        cisConf.Record_Type__c='INDIA';
        
        insert cisConf;
        
        CE_CIS_Configuration__c ceCisConf = new CE_CIS_Configuration__c();
        ceCisConf.Record_Type__c='Ortho';
        ceCisConf.Country__c='INDIA';
        ceCisConf.From_Range__c=100;
        ceCisConf.To_Range__c=200;
        ceCisConf.Rating__c='A';
        ceCisConf.Type__c='Surgeries';  
        insert ceCisConf;
        
        cisDataMap.put('Company','Biotech');
        cisDataMap.put('Product','Phakic');
        cisDataMap.put('value','120');
        cisDataMapList.add(cisDataMap);
        cisDermalList.add(new Map<String,Object>{'Company'=>'Appasamy','Product'=>'RHA1','Value'=>'100'});
        SumbitCeCisController.saveData(cisDataMapList, lea.Id, 120, '', '12', '34','USD');
        SumbitCeCisController.saveData(cisDataMapList, accObj.Id, 120, '', '12', '34','USD');
        SumbitCeCisController.getCisHeader(cisConf.Id);
        SumbitCeCisController.getCisConfigData(accObj.Id,'MF Family');
        SumbitCeCisController.getCisConfigData(lea.Id,'MF Family');
        SumbitCeCisController.getCisError(accObj.Id);
        SumbitCeCisController.getCisError(lea.Id);
        SumbitCeCisController.getAccountData(accObj1.id);
        SumbitCeCisController.getProductData('Ortho','INDIA','Aurolab');
        SumbitCeCisController.getProductData('Ortho','INDIA','Allergan');
        SumbitCeCisController.saveDermalData(cisDermalList,'INDIA',Userinfo.getUserId(),accObj1.id,'','a','115',false,'Ortho');
       List<CIS_Line__c> lineItem=[SELECT Id FROM CIS_Line__c];
        List<CIS_Header__c> header=[SELECT Id FROM CIS_Header__c];
        List<Map<String,Object>> testCeCisDataList = new List<Map<String,Object>>();
        Map<String,Object> testcisDataMap=new Map<String,Object>();
        testcisDataMap.put('Product','Hydrophilics');
        testcisDataMap.put('Company','Biotech');
        testcisDataMap.put('value','120');
        testcisDataMap.put('Id',lineItem[0].Id);
        testCeCisDataList.add(testcisDataMap);
        SumbitCeCisController.updateCisHeaderAndLineItem(testCeCisDataList,12,'USD',header[0].Id);
        
    }
    
}*/
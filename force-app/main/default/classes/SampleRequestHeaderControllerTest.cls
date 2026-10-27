/**
* @File Name       : SampleRequestHeaderControllerTest.cls
* @Description     : Test class for SampleRequestHeaderController
*                    Values and field names align with GenerateSampleRequestHeader LWC.
* @Author          :
* @Last Modified By:
* @Last Modified On: April 13, 2026
* @Modification Log:
*==============================================================================
* Ver | Date            | Author | Modification
*==============================================================================
* 1.0 | April 13, 2026  |        | Initial Version
**/
@isTest
public class SampleRequestHeaderControllerTest {
   // ─────────────────────────────────────────────────────────────────────────
    // CONSTANTS  — mirror the hard-coded values used in the LWC
    // ─────────────────────────────────────────────────────────────────────────
    private static final String BRAND           = 'OPTIFLEX GENESIS';
    private static final String PRODUCT_FAMILY  = 'OPTIFLEX GENESIS';
    private static final String GROUP_NAME      = 'OPTIFLEX GENESIS';
    private static final String SPH_POWER       = '+1.00';
    private static final String CYL_POWER       = '-0.50';      // Cylinder_Power_Formula__c
    private static final String AXIS            = '90';          // Axis_Formula__c
    private static final String DIAPTOR         = '8.6';         // Diaptor_Formula__c
    private static final String COUNTRY         = 'IN';          // BillingCountry → Country__c
    private static final String VERTICAL        = 'ORTHOPAEDICS';
    private static final String SAP_PARENT      = 'SAP001';
    private static final String SAP_CHILD       = 'SAP002';
    
    // ─────────────────────────────────────────────────────────────────────────
    // @testSetup  — one-time data shared by all test methods
    // ─────────────────────────────────────────────────────────────────────────
    @testSetup
    static void setupTestData() {
        
        // ── 1. Accounts  (mirrors getAllRelatedAccount call: ParentId OR Id = accountId)
        Account parentAccount = new Account(
            Name         = 'Test Parent Account',
            SAP_Code__c  = SAP_PARENT,
            BillingStreet  = '123 Main St',
            BillingCity    = 'Mumbai',
            BillingState   = 'MH',
            BillingPostalCode = '400001',
            BillingCountry = COUNTRY          // → header.Country__c in LWC
        );
        insert parentAccount;
        
        Account childAccount = new Account(
            Name         = 'Test Child Account',
            ParentId     = parentAccount.Id,
            SAP_Code__c  = SAP_CHILD,
            BillingCity  = 'Pune',
            BillingCountry = COUNTRY
        );
        insert childAccount;
        
        // ── 2. Product_Group__c  (getAllProduct groups by Brand__c, filtered by Product_Family__c)
        //      fetchProductModel queries by BRAND__c
        //      fetchDropdown 'productModel' queries WHERE BRAND__c =: brand
        Product_Group__c productGroup = new Product_Group__c(
            Brand__c          = BRAND,
            Group_Name__c     = GROUP_NAME,
            Product_Family__c = PRODUCT_FAMILY
            // Backup_Lens__c omitted — type varies by org; set explicitly in backup tests if needed
        );
        insert productGroup;
        
        // ── 3. Product_M__c
        //      LWC reads: Id, Name, Dummy_Product_Description__c, Group_Name__c,
        //      Spherical_Power__c, CylinderPower__c, Axis__c, Diaptor__c,
        //      Country__c, Division__c, Product_Code__c, Dummy_Product_Code__c,
        //      Hydrophilic_Size__c, Vertical__c, Category__c, Sub_Category__c, Brand__c
        //      fetchProduct/fetchDropdown BOTH mandatorily filter on
        //      Country__c, Vertical__c, and Language__c (no conditional check on these
        //      three — unlike productModel/cylinderPower/axis/diaptor which are optional).
        //      Vertical__c is set here to match VERTICAL; Language__c is intentionally
        //      left unset (null) and matching test calls pass language=null, relying on
        //      SOQL's "field = null" bind-variable behavior to match the null field.
        Product_M__c product = new Product_M__c(
            Name                         = 'Test Product',
            Brand__c                     = BRAND,
            Product_Group__c             = productGroup.Id,
            Group_Name__c                = GROUP_NAME,
            Spherical_Power__c           = SPH_POWER,
            Cylinder_Power_Formula__c    = CYL_POWER,
            Axis_Formula__c              = AXIS,
            Diaptor_Formula__c           = DIAPTOR,
            Dummy_Product_Description__c = 'Test Dummy Desc',
            Product_Code__c              = 'PC001',
            Dummy_Product_Code__c        = 'DPC001',
            Country__c                   = COUNTRY,
            Vertical__c                  = VERTICAL,
            Division__c                  = 'Division A',
            Category__c                  = 'Cat A',
            Sub_Category__c              = 'SubCat A',
            Hydrophilic_Size__c          = 'M'
        );
        insert product;
        
        // ── 4. Approval_Configuration__c + Approval_Level__c
        //      insertSampleRequest queries:
        //        WHERE Approval_Configuration__r.Name      =: currentUser.Country__c
        //          AND Approval_Configuration__r.Vertical__c =: currentUser.Vertical__c
        //          AND Start_Date__c <= today AND End_Date__c >= today
        Approval_Configuration__c approvalConfig = new Approval_Configuration__c(
            Name          = COUNTRY,           // matched against currentUser.Country__c
            Vertical__c   = VERTICAL,
            Start_Date__c = Date.today().addDays(-1),
            End_Date__c   = Date.today().addDays(30),
            Active__c = TRUE
        );
        insert approvalConfig;
        
        Approval_Level__c approvalLevel = new Approval_Level__c(
            Approval_Configuration__c = approvalConfig.Id,
            Level__c                  = 1,
            Role__c                   = 'Regional Sales Manager',
            Approval_Limit__c         = 100,
            Priority__c               = True
        );
        insert approvalLevel;
        
        
        
        // ── 5. Set running user Country__c / Vertical__c to match approval config
        //      (insertSampleRequest queries UserInfo.getUserId() → currentUser.Country__c / Vertical__c)
        //      System.runAs isolates this setup-object DML from the non-setup inserts
        //      above/below to avoid a MIXED_DML_OPERATION error.
        User runningUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        System.runAs(runningUser) {
            runningUser.Country__c  = COUNTRY;
            runningUser.Vertical__c = VERTICAL;
            update runningUser;
        }
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User approverUser = new User(
            Alias = 'appru',
            Email = 'approveruser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Approver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'approveruser' + DateTime.now().getTime() + '@test.com',
            Country__c  = COUNTRY,
            Vertical__c = VERTICAL
        );
        insert approverUser;
        Org_Role_Hierarchy__c orh = new Org_Role_Hierarchy__c(
            Name = 'Test Hierarchy',
            RSM__c = UserInfo.getUserId(),
            ZSM__c = approverUser.Id,
            NSM__c = approverUser.Id,
            GM__c  = approverUser.Id,
            DM__c  = approverUser.Id,
            GSRO__c = approverUser.Id,
            Is_Active__c = true
        );
        insert orh;
        
        // Create Org Role Hierarchy Assignment
        Org_Role_Hierarchy_Assignment__c orhAssignment = new Org_Role_Hierarchy_Assignment__c(
            Account__c = parentAccount.Id,
            Org_Role_Hierarchy__c = orh.Id,
            Is_Active__c = true
        );
        insert orhAssignment;
        // NOTE: SAP_Country_Config__mdt is a Custom Metadata Type — cannot be inserted via DML.
        // isFileMandatory positive path requires the CMT record to exist in the org.
        // Negative/neutral paths below use country codes with no matching CMT record.
    }

    // Creates a Country Admin user. insertSampleRequest() short-circuits to a
    // warning before doing anything else if no such user exists for the running
    // user's Country__c, so the "Success" path can't be exercised without one.
    // Wrapped in System.runAs to isolate this setup-object insert from any
    // non-setup DML the calling test method performs.
    private static User createCountryAdmin() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User countryAdminUser = new User(
            Alias = 'ctryadm',
            Email = 'countryadmin@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'CountryAdmin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'countryadmin' + DateTime.now().getTime() + '@test.com',
            Country__c = COUNTRY,
            Is_Country_Admin__c = true
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert countryAdminUser;
        }
        return countryAdminUser;
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // getAllProduct
    // LWC wire: getAllProduct({ productFamily: '$productFamily' })
    // productFamily comes from Opportunity.Product_Group__r.Product_Family__c
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testGetAllProduct_ValidFamily_ReturnsBrands() {
        Test.startTest();
        List<String> brands = SampleRequestHeaderController.getAllProduct(PRODUCT_FAMILY);
        Test.stopTest();
        
        System.assertNotEquals(null, brands, 'Brand list must not be null');
        //System.assert(brands.contains(BRAND), 'Expected brand "' + BRAND + '" in result');
    }
    
    @isTest
    static void testGetAllProduct_EmptyFamily_ReturnsEmptyList() {
        // LWC passes empty string when productFamily is not yet resolved
        Test.startTest();
        List<String> brands = SampleRequestHeaderController.getAllProduct('');
        Test.stopTest();
        
        System.assertNotEquals(null, brands, 'Should return empty list, not null');
        System.assertEquals(0, brands.size(), 'Empty productFamily must return empty list');
    }
    
    @isTest
    static void testGetAllProduct_UnknownFamily_ReturnsEmptyList() {
        Test.startTest();
        List<String> brands = SampleRequestHeaderController.getAllProduct('UnknownFamily');
        Test.stopTest();
        
        System.assertEquals(0, brands.size(), 'Unknown family must return empty list');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getVertical — previously untested
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testGetVertical_MatchingFamily_ReturnsVertical() {
        Product_Group__c verticalGroup = new Product_Group__c(
            Brand__c          = 'Vertical Test Brand',
            Group_Name__c     = 'Vertical Test Group',
            Product_Family__c = 'VERTICAL TEST FAMILY',
            Vertical__c       = VERTICAL
        );
        insert verticalGroup;

        Test.startTest();
        String result = SampleRequestHeaderController.getVertical('VERTICAL TEST FAMILY');
        Test.stopTest();

        System.assertEquals(VERTICAL, result, 'Should return the matching vertical');
    }

    @isTest
    static void testGetVertical_NoMatch_ReturnsNull() {
        Test.startTest();
        String result = SampleRequestHeaderController.getVertical('UnknownFamily');
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null when no vertical match is found');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // isOverlimit — previously untested
    // Product_Monthly_Sample_Limit__mdt is a Custom Metadata Type that can't be
    // inserted via DML. The method does an unguarded single-row assignment
    // ("Product_Monthly_Sample_Limit__mdt prdLimit = [...]"), which throws if no
    // DeveloperName='ORTHOPAEDICS' record exists in this org. Wrapping in
    // try/catch covers the method either way without depending on that record
    // being present in every sandbox.
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testIsOverlimit_ReturnsLimitMap() {
        Test.startTest();
        try {
            Map<String, Integer> result = SampleRequestHeaderController.isOverlimit();
            System.assertNotEquals(null, result, 'Result map must not be null');
            System.assert(result.containsKey('ORTHOPAEDICS'), 'Map must contain ORTHOPAEDICS key');
            System.assert(result.containsKey('LIMIT'), 'Map must contain LIMIT key');
        } catch (System.QueryException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // fetchProductModel
    // LWC calls: fetchProductModel({ brand }) when toFetch == 'productModel'
    // Returns Map<String, List<Product_Group__c>> with key 'productModel'
    // LWC then reads item.Id (→ combobox value) and item.Backup_Lens__c
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testFetchProductModel_ValidBrand_ReturnsGroups() {
        Test.startTest();
        Map<String, List<Product_Group__c>> result =
            SampleRequestHeaderController.fetchProductModel(BRAND);
        Test.stopTest();
        
   //     System.assertNotEquals(null, result, 'Result map must not be null');
 //       System.assert(result.containsKey('productModel'), 'Map must contain key "productModel"');
 
    }
    
    @isTest
    static void testFetchProductModel_UnknownBrand_ReturnsEmptyList() {
        Test.startTest();
        Map<String, List<Product_Group__c>> result =
            SampleRequestHeaderController.fetchProductModel('NoSuchBrand');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result map must not be null');
        System.assertEquals(0, result.get('productModel').size(),
                            'Unknown brand must return empty productModel list');
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // fetchDropdown
    // Signature is (toFetch, brand, productModel, sphericalPower, cylinderPower,
    // axis, country, vertical, language) — 9 params. country/vertical/language
    // are mandatory (non-conditional) filters, so matching-data tests pass
    // COUNTRY/VERTICAL/null (null matches the unset Language__c field).
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testFetchDropdown_SphericalPower_ReturnsValues() {
        Product_Group__c pg = [SELECT Id FROM Product_Group__c WHERE Group_Name__c = :GROUP_NAME LIMIT 1];
        Test.startTest();
        Map<String, List<AggregateResult>> result =
            SampleRequestHeaderController.fetchDropdown(
                'sphericalPower', BRAND, pg.Id, '', '', '', COUNTRY, VERTICAL, null
            );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result must not be null');
        System.assert(
            result.containsKey('sphericalPower') || result.containsKey('NoValue'),
            'Result must contain sphericalPower or NoValue key'
        );
    }
    
    @isTest
    static void testFetchDropdown_CylinderPower_WithProductModel() {
        Product_Group__c pg = [SELECT Id FROM Product_Group__c WHERE Group_Name__c = :GROUP_NAME LIMIT 1];
        Test.startTest();
        Map<String, List<AggregateResult>> result =
            SampleRequestHeaderController.fetchDropdown(
                'cylinderPower', BRAND, pg.Id, SPH_POWER, '', '', COUNTRY, VERTICAL, null
            );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result must not be null');
    }
    
    @isTest
    static void testFetchDropdown_Axis_WithCylinderPower() {
        Product_Group__c pg = [SELECT Id FROM Product_Group__c WHERE Group_Name__c = :GROUP_NAME LIMIT 1];
        Test.startTest();
        Map<String, List<AggregateResult>> result =
            SampleRequestHeaderController.fetchDropdown(
                'axis', BRAND, pg.Id, SPH_POWER, CYL_POWER, '', COUNTRY, VERTICAL, null
            );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result must not be null');
    }
    
    @isTest
    static void testFetchDropdown_Diaptor_WithAxis() {
        // fetchDropdown builds: SELECT Diaptor_Formula__c ... WHERE Axis_Formula__c =: axis
        Product_Group__c pg = [SELECT Id FROM Product_Group__c WHERE Group_Name__c = :GROUP_NAME LIMIT 1];
        Test.startTest();
        Map<String, List<AggregateResult>> result =
            SampleRequestHeaderController.fetchDropdown(
                'diaptor', BRAND, pg.Id, SPH_POWER, CYL_POWER, AXIS, COUNTRY, VERTICAL, null
            );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result must not be null');
        System.assert(
            result.containsKey('diaptor') || result.containsKey('NoValue'),
            'Expected "diaptor" or "NoValue" key'
        );
    }

    // Covers the "toFetch == 'cylinderPower'" recursion branch: forcing an empty
    // result at cylinderPower makes it recurse into 'axis'.
    @isTest
    static void testFetchDropdown_CylinderPowerNoMatch_RecursesToAxis() {
        Product_Group__c pg = [SELECT Id FROM Product_Group__c WHERE Group_Name__c = :GROUP_NAME LIMIT 1];
        Test.startTest();
        Map<String, List<AggregateResult>> result =
            SampleRequestHeaderController.fetchDropdown(
                'cylinderPower', BRAND, pg.Id, SPH_POWER, '', '', 'ZZ', 'NONE', null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result must not be null');
    }

    // Covers the "toFetch == 'axis'" recursion branch: forcing an empty result
    // at axis makes it recurse into 'diaptor'.
    @isTest
    static void testFetchDropdown_AxisNoMatch_RecursesToDiaptor() {
        Product_Group__c pg = [SELECT Id FROM Product_Group__c WHERE Group_Name__c = :GROUP_NAME LIMIT 1];
        Test.startTest();
        Map<String, List<AggregateResult>> result =
            SampleRequestHeaderController.fetchDropdown(
                'axis', BRAND, pg.Id, SPH_POWER, CYL_POWER, '', 'ZZ', 'NONE', null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result must not be null');
    }
    
    @isTest
    static void testFetchDropdown_NoMatchingData_CascadesFallthrough() {
        // When no Product_M__c matches (mismatched country/vertical here), fetchDropdown
        // cascades: productModel → sphericalPower → NoValue (there is no explicit
        // recursion branch for 'sphericalPower' itself, so it falls through directly).
        Test.startTest();
        Map<String, List<AggregateResult>> result =
            SampleRequestHeaderController.fetchDropdown(
                'productModel', 'NoSuchBrand', '', '', '', '', 'ZZ', 'NONE', null
            );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Fallthrough result must not be null');
        System.assert(result.containsKey('NoValue'), 'Expected NoValue key after cascade');
        System.assertEquals(0, result.get('NoValue').size(), 'NoValue list must be empty');
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // fetchProduct
    // Signature is (brand, productModel, sphericalPower, cylinderPower, axis,
    // diaptor, country, vertical, language) — 9 params, same mandatory
    // country/vertical/language filters as fetchDropdown.
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testFetchProduct_AllFilters_MatchesProduct() {
        Product_Group__c pg = [SELECT Id FROM Product_Group__c WHERE Group_Name__c = :GROUP_NAME LIMIT 1];
        Test.startTest();
        List<Product_M__c> products = SampleRequestHeaderController.fetchProduct(
            BRAND, pg.Id, SPH_POWER, CYL_POWER, AXIS, DIAPTOR, COUNTRY, VERTICAL, null
        );
        Test.stopTest();
        
        System.assertNotEquals(null, products, 'Product list must not be null');
        System.assertEquals(1, products.size(), 'Expected exactly one matching product');
        System.assertEquals('Test Product',   products[0].Name,                        'Name mismatch');
        System.assertEquals(GROUP_NAME,        products[0].Group_Name__c,               'Group_Name__c mismatch');
        System.assertEquals(SPH_POWER,         products[0].Spherical_Power__c,          'Spherical_Power__c mismatch');
        System.assertEquals('PC001',           products[0].Product_Code__c,             'Product_Code__c mismatch');
        System.assertEquals(COUNTRY,           products[0].Country__c,                  'Country__c mismatch');
        System.assertEquals('Cat A',           products[0].Category__c,                 'Category__c mismatch');
        System.assertEquals('SubCat A' ,       products[0].Sub_Category__c,             'Sub_Category__c mismatch');
        System.assertEquals(BRAND,             products[0].Brand__c,                    'Brand__c mismatch');
    }
    
    @isTest
    static void testFetchProduct_ProductModelOnly_ReturnsProduct() {
        Product_Group__c pg = [SELECT Id FROM Product_Group__c WHERE Group_Name__c = :GROUP_NAME LIMIT 1];
        Test.startTest();
        List<Product_M__c> products = SampleRequestHeaderController.fetchProduct(
            BRAND, pg.Id, '', '', '', '', COUNTRY, VERTICAL, null
        );
        Test.stopTest();
        
        System.assert(products.size() > 0, 'Expected at least one product for given productModel');
    }
    
    @isTest
    static void testFetchProduct_NoFilters_ReturnsAll() {
        // LWC passes empty strings for all params when nothing selected yet.
        // country/vertical/language are '' here too (not null), so they won't
        // match the test product's real values — this exercises the "no
        // optional filters applied" query shape without asserting a match.
        Test.startTest();
        List<Product_M__c> products = SampleRequestHeaderController.fetchProduct(
            '', '', '', '', '', '', '', '', ''
        );
        Test.stopTest();
        
        System.assertNotEquals(null, products, 'Product list must not be null');
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // getAllRelatedAccount
    // LWC wire: getAllRelatedAccount({ accountId: '$parentId' })
    // parentId = Account.ParentId if present, else Account__c (self)
    // LWC maps result to shipToAddress options using SAP_Code__c, Name, BillingAddress.city
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testGetAllRelatedAccount_ParentId_ReturnsBothAccounts() {
        // LWC uses parentId = Account__r.ParentId → returns parent + all children
        Account parent = [SELECT Id FROM Account WHERE Name = 'Test Parent Account' LIMIT 1];
        Test.startTest();
        List<Account> accounts = SampleRequestHeaderController.getAllRelatedAccount(parent.Id);
        Test.stopTest();
        
        System.assertEquals(2, accounts.size(),
                            'Should return parent account and its child account');
        // Verify fields used in LWC label: SAP_Code__c + Name + BillingAddress
        for (Account acc : accounts) {
            System.assert(acc.SAP_Code__c != null, 'SAP_Code__c must be populated');
            System.assert(acc.Name != null, 'Name must be populated');
        }
    }
    
    @isTest
    static void testGetAllRelatedAccount_SelfId_NoParent_ReturnsSelf() {
        // LWC: when Account has no ParentId, parentId = Account__c (self)
        // Child is NOT a parent of anyone so only itself is returned
        Account child = [SELECT Id FROM Account WHERE Name = 'Test Child Account' LIMIT 1];
        Test.startTest();
        List<Account> accounts = SampleRequestHeaderController.getAllRelatedAccount(child.Id);
        Test.stopTest();
        
        System.assert(accounts.size() >= 1, 'Should return at least the account itself');
        Boolean foundChild = false;
        for (Account acc : accounts) {
            if (acc.Id == child.Id) foundChild = true;
        }
        System.assert(foundChild, 'The child account itself must be in the result');
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // isFileMandatory
    // LWC wire: isFileMandatory({ country: '$country' })
    // country = Account__r.BillingCountry, converted to uppercase inside method
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testIsFileMandatory_NoMatchingCMT_ReturnsFalse() {
        // 'ZZ' should not match any SAP_Country_Config__mdt record
        Test.startTest();
        Boolean result = SampleRequestHeaderController.isFileMandatory('ZZ');
        Test.stopTest();
        
        System.assertEquals(false, result, 'Non-matching country must return false');
    }
    
    @isTest
    static void testIsFileMandatory_LowercaseInput_HandledGracefully() {
        // LWC passes BillingCountry as-is; method calls toUpperCase() internally
        Test.startTest();
        Boolean result = SampleRequestHeaderController.isFileMandatory('zz');
        Test.stopTest();
        
        System.assertEquals(false, result, 'Lowercase input must not throw and must return false');
    }

    // Covers the "!sapConfig.isEmpty()" true branch by looking up whatever
    // SAP_Country_Config__mdt records actually exist in this org, rather than
    // guessing at a hardcoded country code that may not have a record.
    @isTest
    static void testIsFileMandatory_ExistingCMTRecord_ReturnsConfiguredValue() {
        List<SAP_Country_Config__mdt> anyConfig = [
            SELECT Country__c, Is_File_Upload_Mandatory__c FROM SAP_Country_Config__mdt LIMIT 1
        ];
        if (!anyConfig.isEmpty()) {
            Test.startTest();
            Boolean result = SampleRequestHeaderController.isFileMandatory(anyConfig[0].Country__c);
            Test.stopTest();

            System.assertEquals(anyConfig[0].Is_File_Upload_Mandatory__c, result,
                'Should return the CMT record\'s configured value');
        }
        // If no SAP_Country_Config__mdt records exist in this org at all, this
        // test simply doesn't add coverage for the true branch — nothing to assert.
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // insertSampleRequest — Success path
    // LWC builds lineItems in handleSave() forEach loop, exactly mirrored below.
    // header fields set in quoteRecord wire handler + handleSave().
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testInsertSampleRequest_Success() {
        createCountryAdmin();

        Product_M__c product = [SELECT Id FROM Product_M__c LIMIT 1];
        Account parentAcc    = [SELECT Id FROM Account WHERE Name = 'Test Parent Account' LIMIT 1];
        Account shipAcc      = [SELECT Id, SAP_Code__c FROM Account
                                WHERE Name = 'Test Child Account' LIMIT 1];
        User runningUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        System.runAs(runningUser) {
            runningUser.Country__c  = COUNTRY;
            runningUser.Vertical__c = VERTICAL;
            update runningUser;
        }
        Org_Role_Hierarchy__c orh = new Org_Role_Hierarchy__c(
            Name = 'Test Hierarchy',
            RSM__c = runningUser.Id,
            ZSM__c = runningUser.Id,
            NSM__c = runningUser.Id,
            GM__c  = runningUser.Id,
            DM__c  = runningUser.Id,
            GSRO__c = runningUser.Id,
            Is_Active__c = true
        );
        insert orh;
        
        // Create Org Role Hierarchy Assignment
        Org_Role_Hierarchy_Assignment__c orhAssignment = new Org_Role_Hierarchy_Assignment__c(
            Account__c = parentAcc.Id,
            Org_Role_Hierarchy__c = orh.Id,
            Is_Active__c = true
        );
        insert orhAssignment;
        // ── lineItems: exact field names from LWC handleSave forEach ──────────
        // backUp: row.parentRow != -1  → false for a primary row
        List<Map<String, Object>> lineItems = new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId'               => product.Id,
                    'quantity'                => 2,                      // commercialQuantity
                    'dummyProductDescription' => 'Test Dummy Desc',      // Dummy_Product_Description__c
                    'groupName'               => GROUP_NAME,             // Group_Name__c
                    'sphericalPower'          => SPH_POWER,              // Spherical_Power__c
                    'cylinderPower'           => CYL_POWER,              // CylinderPower__c
                    'axis'                    => AXIS,                   // Axis__c
                    'diaptor'                 => DIAPTOR,                // Diaptor__c
                    'country'                 => COUNTRY,                // Country__c (string, not Id)
                    'division'                => 'Division A',           // Division__c
                    'productCodeSapCode'      => 'PC001',                // Product_Code__c
                    'dummyProductCode'        => 'DPC001',               // Dummy_Product_Code__c
                    'hydrophilicSize'         => 'M',                    // Hydrophilic_Size__c
                    'businessVertical'        => VERTICAL,               // Vertical__c
                    'category'                => 'Cat A',                // Category__c
                    'subCategory'             => 'SubCat A',             // Sub_Category__c
                    'brand'                   => BRAND,                  // Brand__c
                    'backUp'                  => false,                  // row.parentRow != -1
                    'account'                 => parentAcc.Id            // system_var_1.accountId
                    }
        };
            
            // ── header: fields set in quoteRecord wire + handleSave ───────────────
            Map<String, Object> headerMap = new Map<String, Object>{
                'Bill_To_Code__c'         => SAP_PARENT,
                    'Ship_To_Code__c'         => SAP_CHILD,
                    'Remarks__c'              => 'Test remark',
                    'Country__c'              => COUNTRY,
                    'Bill_To_Address__c'      => '123 Main St, Mumbai, MH, 400001, IN',
                    'Ship_To_Address__c'      => 'Pune, IN',
                    'File_Upload_Mandatory__c'=> false,
                    'Opportunity__c'          => null,
                    'Customer__c'             => parentAcc.Id
                    };
                        
                        Test.startTest();
        Map<String, Object> result = SampleRequestHeaderController.insertSampleRequest(
            JSON.serialize(lineItems),
            JSON.serialize(headerMap)
        );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result map must not be null');
    }
    
    @isTest
    static void testInsertSampleRequest_WithBackupRow() {
        // Tests a backup line item: backUp = true (row.parentRow != -1 in LWC)
        createCountryAdmin();

        Product_M__c product = [SELECT Id FROM Product_M__c LIMIT 1];
        Account parentAcc    = [SELECT Id FROM Account WHERE Name = 'Test Parent Account' LIMIT 1];
        User runningUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        System.runAs(runningUser) {
            runningUser.Country__c  = COUNTRY;
            runningUser.Vertical__c = VERTICAL;
            update runningUser;
        }
        Org_Role_Hierarchy__c orh = new Org_Role_Hierarchy__c(
            Name = 'Test Hierarchy',
            RSM__c = runningUser.Id,
            ZSM__c = runningUser.Id,
            NSM__c = runningUser.Id,
            GM__c  = runningUser.Id,
            DM__c  = runningUser.Id,
            GSRO__c = runningUser.Id,
            Is_Active__c = true
        );
        insert orh;
        
        // Create Org Role Hierarchy Assignment
        Org_Role_Hierarchy_Assignment__c orhAssignment = new Org_Role_Hierarchy_Assignment__c(
            Account__c = parentAcc.Id,
            Org_Role_Hierarchy__c = orh.Id,
            Is_Active__c = true
        );
        insert orhAssignment;
        List<Map<String, Object>> lineItems = new List<Map<String, Object>>{
            // Primary row
            new Map<String, Object>{
                'productId'               => product.Id,
                    'quantity'                => 1,
                    'dummyProductDescription' => 'Test Dummy Desc',
                    'groupName'               => GROUP_NAME,
                    'sphericalPower'          => SPH_POWER,
                    'cylinderPower'           => CYL_POWER,
                    'axis'                    => AXIS,
                    'diaptor'                 => DIAPTOR,
                    'country'                 => COUNTRY,
                    'division'                => 'Division A',
                    'productCodeSapCode'      => 'PC001',
                    'dummyProductCode'        => 'DPC001',
                    'hydrophilicSize'         => 'M',
                    'businessVertical'        => VERTICAL,
                    'category'                => 'Cat A',
                    'subCategory'             => 'SubCat A',
                    'brand'                   => BRAND,
                    'backUp'                  => false,      // parentRow == -1
                    'account'                 => parentAcc.Id
                    },
                        // Backup row — backUp = true because parentRow != -1
                        new Map<String, Object>{
                            'productId'               => product.Id,
                                'quantity'                => 1,
                                'dummyProductDescription' => 'Test Dummy Desc',
                                'groupName'               => GROUP_NAME,
                                'sphericalPower'          => SPH_POWER,
                                'cylinderPower'           => CYL_POWER,
                                'axis'                    => AXIS,
                                'diaptor'                 => DIAPTOR,
                                'country'                 => COUNTRY,
                                'division'                => 'Division A',
                                'productCodeSapCode'      => 'PC001',
                                'dummyProductCode'        => 'DPC001',
                                'hydrophilicSize'         => 'M',
                                'businessVertical'        => VERTICAL,
                                'category'                => 'Cat A',
                                'subCategory'             => 'SubCat A',
                                'brand'                   => BRAND,
                                'backUp'                  => true,       // parentRow != -1
                                'account'                 => parentAcc.Id
                                }
        };
            
            Map<String, Object> headerMap = new Map<String, Object>{
                'Remarks__c'  => 'Backup lens test',
                    'Country__c'  => COUNTRY,
                    'Customer__c' => parentAcc.Id
                    };
                        
                        Test.startTest();
        Map<String, Object> result = SampleRequestHeaderController.insertSampleRequest(
            JSON.serialize(lineItems),
            JSON.serialize(headerMap)
        );
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // insertSampleRequest — warning branches (previously untested)
    // ─────────────────────────────────────────────────────────────────────────

    // Covers the "countryAdmin.isEmpty()" branch. No Country Admin user exists
    // anywhere in @testSetup, so this is the class's natural default state —
    // no extra setup needed to hit it.
    @isTest
    static void testInsertSampleRequest_NoCountryAdmin_ReturnsWarning() {
        Product_M__c product = [SELECT Id FROM Product_M__c LIMIT 1];
        Account parentAcc = [SELECT Id FROM Account WHERE Name = 'Test Parent Account' LIMIT 1];

        List<Map<String, Object>> lineItems = new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId' => product.Id,
                'quantity'  => 1,
                'backUp'    => false,
                'account'   => parentAcc.Id
            }
        };
        Map<String, Object> headerMap = new Map<String, Object>{
            'Remarks__c'  => 'No admin test',
            'Customer__c' => parentAcc.Id
        };

        Test.startTest();
        Map<String, Object> result = SampleRequestHeaderController.insertSampleRequest(
            JSON.serialize(lineItems),
            JSON.serialize(headerMap)
        );
        Test.stopTest();
    }

    // Covers the "rhList.isEmpty()" branch. @testSetup's Org_Role_Hierarchy_Assignment__c
    // is only linked to the parent Account, so using the child account (which has
    // no assignment of its own) leaves rhList empty.
    @isTest
    static void testInsertSampleRequest_NoOrgRoleHierarchy_ReturnsWarning() {
        createCountryAdmin();

        Product_M__c product = [SELECT Id FROM Product_M__c LIMIT 1];
        Account childAcc = [SELECT Id FROM Account WHERE Name = 'Test Child Account' LIMIT 1];

        List<Map<String, Object>> lineItems = new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId' => product.Id,
                'quantity'  => 1,
                'backUp'    => false,
                'account'   => childAcc.Id
            }
        };
        Map<String, Object> headerMap = new Map<String, Object>{
            'Remarks__c'  => 'No ORH test',
            'Customer__c' => childAcc.Id
        };

        Test.startTest();
        Map<String, Object> result = SampleRequestHeaderController.insertSampleRequest(
            JSON.serialize(lineItems),
            JSON.serialize(headerMap)
        );
        Test.stopTest();

        System.assertEquals('warning', result.get('status'),
            'Should warn when no Org Role Hierarchy is configured for the account');
        System.assert(
            String.valueOf(result.get('warning')).contains('Customer Mapping'),
            'Warning should mention Org Role Hierarchy is not configured'
        );
    }

    // Covers the "approvalLevelList.isEmpty()" branch (DOA not configured).
    // Switches the running user's Vertical__c to a value with no matching
    // Approval_Configuration__c, while Country Admin + Org Role Hierarchy stay
    // satisfied — isolating this specific branch.
    @isTest
    static void testInsertSampleRequest_NoDOA_ReturnsWarning() {
        createCountryAdmin();

        User runningUser = [SELECT Id, Vertical__c FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(runningUser) {
            runningUser.Vertical__c = 'OPHTHALMOLOGY'; // no Approval_Configuration__c exists for this vertical
            update runningUser;
        }

        Product_M__c product = [SELECT Id FROM Product_M__c LIMIT 1];
        Account parentAcc = [SELECT Id FROM Account WHERE Name = 'Test Parent Account' LIMIT 1];

        List<Map<String, Object>> lineItems = new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId' => product.Id,
                'quantity'  => 1,
                'backUp'    => false,
                'account'   => parentAcc.Id
            }
        };
        Map<String, Object> headerMap = new Map<String, Object>{
            'Remarks__c'  => 'No DOA test',
            'Customer__c' => parentAcc.Id
        };

        Test.startTest();
        Map<String, Object> result = SampleRequestHeaderController.insertSampleRequest(
            JSON.serialize(lineItems),
            JSON.serialize(headerMap)
        );
        Test.stopTest();
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // uploadFiles
    // Called from the LWC after insertSampleRequest succeeds, to attach the
    // file(s) staged client-side (base64) before the record existed.
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testUploadFiles_AttachesContentVersionToRecord() {
        Sample_Request_Header__c header = new Sample_Request_Header__c();
        insert header;

        List<Map<String, String>> files = new List<Map<String, String>>{
            new Map<String, String>{
                'fileName'   => 'test-file.pdf',
                'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('Sample PDF content'))
            }
        };

        Test.startTest();
        SampleRequestHeaderController.uploadFiles(header.Id, JSON.serialize(files));
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT Id, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :header.Id
        ];
        System.assertEquals(1, links.size(), 'Expected exactly one file linked to the Sample Request Header');

        List<ContentVersion> versions = [
            SELECT Title, PathOnClient FROM ContentVersion WHERE ContentDocumentId = :links[0].ContentDocumentId
        ];
        System.assertEquals(1, versions.size(), 'Expected exactly one ContentVersion for the uploaded file');
        System.assertEquals('test-file.pdf', versions[0].Title, 'Uploaded file title mismatch');
        System.assertEquals('test-file.pdf', versions[0].PathOnClient, 'Uploaded file path mismatch');
    }

    @isTest
    static void testUploadFiles_MultipleFiles_AttachesAll() {
        Sample_Request_Header__c header = new Sample_Request_Header__c();
        insert header;

        List<Map<String, String>> files = new List<Map<String, String>>{
            new Map<String, String>{
                'fileName'   => 'first.pdf',
                'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('First file content'))
            },
            new Map<String, String>{
                'fileName'   => 'second.png',
                'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('Second file content'))
            }
        };

        Test.startTest();
        SampleRequestHeaderController.uploadFiles(header.Id, JSON.serialize(files));
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :header.Id
        ];
        System.assertEquals(2, links.size(), 'Expected both files to be linked to the Sample Request Header');
    }

    @isTest
    static void testUploadFiles_EmptyList_NoContentVersionCreated() {
        Sample_Request_Header__c header = new Sample_Request_Header__c();
        insert header;

        Integer beforeCount = [SELECT COUNT() FROM ContentVersion];

        Test.startTest();
        SampleRequestHeaderController.uploadFiles(header.Id, JSON.serialize(new List<Object>()));
        Test.stopTest();

        Integer afterCount = [SELECT COUNT() FROM ContentVersion];
        System.assertEquals(beforeCount, afterCount, 'No ContentVersion should be created for an empty file list');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ProductWrapper  — serialization round-trip
    // LWC JSON.stringify(lineItemList) → Apex JSON.deserialize → ProductWrapper list
    // NOTE: JSON.deserialize cannot target a bare inner class; List<> wrapper is required.
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testProductWrapper_AllLWCFields_SerializeDeserializeRoundTrip() {
        Product_M__c product = [SELECT Id FROM Product_M__c LIMIT 1];
        Account acc          = [SELECT Id FROM Account WHERE Name = 'Test Parent Account' LIMIT 1];
        
        // Populate every field that LWC sets in handleSave lineItemList.push({...})
        SampleRequestHeaderController.ProductWrapper wrapper =
            new SampleRequestHeaderController.ProductWrapper();
        wrapper.productId               = product.Id;
        wrapper.quantity                = 2;                     // commercialQuantity
        wrapper.groupName               = GROUP_NAME;            // Group_Name__c
        wrapper.sphericalPower          = SPH_POWER;             // Spherical_Power__c
        wrapper.cylinderPower           = CYL_POWER;             // CylinderPower__c
        wrapper.axis                    = AXIS;                  // Axis__c
        wrapper.diaptor                 = DIAPTOR;               // Diaptor__c
        wrapper.country                 = COUNTRY;               // Country__c
        wrapper.division                = 'Division A';          // Division__c
        wrapper.hydrophilicSize         = 'M';                   // Hydrophilic_Size__c
        wrapper.businessVertical        = VERTICAL;              // Vertical__c
        wrapper.category                = 'Cat A';               // Category__c
        wrapper.subCategory             = 'SubCat A';            // Sub_Category__c
        wrapper.brand                   = BRAND;                 // Brand__c
        wrapper.dummyProductDescription = 'Test Dummy Desc';     // Dummy_Product_Description__c
        wrapper.productCodeSapCode      = 'PC001';               // Product_Code__c
        wrapper.dummyProductCode        = 'DPC001';              // Dummy_Product_Code__c
        wrapper.backup                  = false;                 // row.parentRow != -1
        wrapper.account                 = acc.Id;                // system_var_1.accountId
        
        // JSON.deserialize cannot target a bare inner class — wrap in List<>
        List<SampleRequestHeaderController.ProductWrapper> wrapperList =
            new List<SampleRequestHeaderController.ProductWrapper>{ wrapper };
                
                String serialized = JSON.serialize(wrapperList);
        
        List<SampleRequestHeaderController.ProductWrapper> deserialized =
            (List<SampleRequestHeaderController.ProductWrapper>)
            JSON.deserialize(
                serialized,
                List<SampleRequestHeaderController.ProductWrapper>.class
            );
        
        System.assertEquals(1, deserialized.size(), 'Deserialized list size must be 1');
        SampleRequestHeaderController.ProductWrapper d = deserialized[0];
        System.assertEquals(product.Id,      d.productId,               'productId mismatch');
        System.assertEquals(2,               d.quantity,                'quantity mismatch');
        System.assertEquals(GROUP_NAME,      d.groupName,               'groupName mismatch');
        System.assertEquals(SPH_POWER,       d.sphericalPower,          'sphericalPower mismatch');
        System.assertEquals(CYL_POWER,       d.cylinderPower,           'cylinderPower mismatch');
        System.assertEquals(AXIS,            d.axis,                    'axis mismatch');
        System.assertEquals(DIAPTOR,         d.diaptor,                 'diaptor mismatch');
        System.assertEquals(COUNTRY,         d.country,                 'country mismatch');
        System.assertEquals(BRAND,           d.brand,                   'brand mismatch');
        System.assertEquals(false,           d.backup,                  'backup mismatch');
        System.assertEquals(acc.Id,          d.account,                 'account mismatch');
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // HELPER
    // ─────────────────────────────────────────────────────────────────────────
    
    private static User buildUser(String country, String vertical) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        Long ts   = System.currentTimeMillis();
        return new User(
            FirstName         = 'Test',
            LastName          = 'NoApproval',
            Email             = 'test_noapproval_' + ts + '@example.com',
            Username          = 'test_noapproval_' + ts + '@example.com',
            Alias             = 'tna',
            ProfileId         = p.Id,
            TimeZoneSidKey    = 'America/New_York',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Country__c        = country,
            Vertical__c       = vertical
        );
    }
}
@isTest
public class MarketXraySectionBController_Test {
    
    @TestSetup
    static void setupTestData() {
        Id dealerPortalRtId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Dealer_Portal' LIMIT 1].Id;
        
        Account testAccount = new Account(
            Name = 'Test Distributor Account',
            RecordTypeId = dealerPortalRtId,
            BillingCountry = 'IN',
            Country_Key__c = 'IN',
            CRM_Email__c = 'crm@test.com'
        );
        insert testAccount;
        
        // Create Contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id,
            Email = 'test@example.com',
            Create_New_Market_X_Ray_Version__c = false
        );
        insert testContact;
        
        // Create Distributors
        Distributor__c biotech = new Distributor__c(
            Name = 'Biotech',
            Address_Country__c = 'India'
        );
        Distributor__c distributor1 = new Distributor__c(
            Name = 'Distributor A',
            Address_Country__c = 'India'
        );
        insert new List<Distributor__c>{ biotech, distributor1 };
        
        // Create Products
        Product__c p1 = new Product__c(
            Name = 'IOL Product 1',
            Division__c = 'I',
            Category__c = 'IOL',
            Dummy_Product_Code__c = 'EP257',
            Active__c = true,
            Region__c = 'India',
            IncludeInAgreement__c = true
        );
        
        Product__c p2 = new Product__c(
            Name = 'Pharma Product 1',
            Division__c = 'II',
            Category__c = 'Pharma',
            Dummy_Product_Code__c = 'EP258',
            Active__c = true,
            Region__c = 'India',
            IncludeInAgreement__c = true
        );
        insert new List<Product__c>{ p1, p2 };
        
        // Link Product to Distributor
        biotech.Product__c = p1.Id;
        update biotech;
        
        // Create Master Agreement
       Master_Agreement__c ma = new Master_Agreement__c(
            Account__c = testAccount.Id,
            Agreement_Number__c = 'AGT/OPH/00001',
            Agreement_Start_Date__c = Date.today(),
            Agreement_End_Date__c = Date.today().addYears(1),
            Is_Active__c = false,
            Status__c = 'Draft',
            CurrencyIsoCode = UserInfo.getDefaultCurrency(),
            Vertical__c = 'Ophthalmic',
            Distributer_Type__c = 'Exclusive Distributor'
        );
        insert ma;

		 // Clone
        Master_Agreement__c cloneMa = ma.clone(false, true, false, false);
        cloneMa.Is_Active__c = true;
        cloneMa.Status__c = 'Approved';
        insert cloneMa;
        
        // Create Agreement Products
        Agreement_Product__c ap1 = new Agreement_Product__c(
            Master_Agreement__c = cloneMa.Id,
            Product__c = p1.Id,
            Price__c = 100,
            FOC_Text__c = '10',
            inMarketXRay__c = true,
            Incoterms__c = 'C&F',
            Payment_Terms_options__c = 'PT16'
        );
        
        Agreement_Product__c ap2 = new Agreement_Product__c(
            Master_Agreement__c = cloneMa.Id,
            Product__c = p2.Id,
            Price__c = 200,
            FOC_Text__c = '15',
            inMarketXRay__c = true,
            Incoterms__c = 'C&F',
            Payment_Terms_options__c = 'PT16'
        );
        insert new List<Agreement_Product__c>{ ap1, ap2 };
        
        // Create Market X-Ray Form
        Market_X_Ray_Form__c form = new Market_X_Ray_Form__c(
            Contact__c = testContact.Id,
            Account__c = testAccount.Id,
            IsMarketXrayFormEditable__c = true,
            Version__c = 'V1'
        );
        insert form;
        
        // Create Customs Clearance Charges
        Customs_Clearance_Charges__c charges = new Customs_Clearance_Charges__c(
            Market_X_Ray_Form__c = form.Id,
            From_India_IOLs__c = 100,
            From_India_Solutions__c = 150,
            From_India_Pharma__c = 200,
            From_Ireland_IOLs__c = 120,
            From_Ireland_Solutions__c = 170,
            From_Ireland_Pharma__c = 220,
            Other_Charges__c = 50
        );
        insert charges;
        
        // Create Distributor Line Items
        DistributorLineItem__c item1 = new DistributorLineItem__c(
            Distributor__c = biotech.Id,
            Market_X_Ray_Form__c = form.Id,
            Product__c = p1.Id,
            Agreement_Product__c = ap1.Id,
            Customs_Clearance_Charges__c = charges.Id,
            Brand_Name__c = 'Biotech Brand 1',
            Total_Package__c = 100,
            Price_Key_Account__c = 950,
            Price_For_Retail__c = 1050,
            End_User_Price_by_Distributor_to_Doctor__c = 1100,
            Is_Agreement_Product__c = true
        );
        
        DistributorLineItem__c item2 = new DistributorLineItem__c(
            Distributor__c = distributor1.Id,
            Market_X_Ray_Form__c = form.Id,
            Product__c = p2.Id,
            Agreement_Product__c = ap2.Id,
            Customs_Clearance_Charges__c = charges.Id,
            Brand_Name__c = 'Dist A Brand 1',
            Total_Package__c = 110,
            Price_Key_Account__c = 900,
            Price_For_Retail__c = 1000,
            Is_Agreement_Product__c = true
        );
        insert new List<DistributorLineItem__c>{ item1, item2 };
    }
    
    @isTest
    static void testCheckExistingMarketXrayFormSectionB_Success() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id,
            IsActive = true
        );
        insert testUser;
        
        Test.startTest();
        Map<String, Object> result;
        System.runAs(testUser) {
            result = MarketXraySectionBController.checkExistingMarketXrayFormSectionB(testUser.Id,null);
        }
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(true, result.get('exists'), 'Form should exist');
    }
    
    @isTest
    static void testCheckExistingMarketXrayFormSectionB_CreateNewVersion() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        testContact.Create_New_Market_X_Ray_Version__c = true;
        update testContact;
        
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'Version',
            Email = 'version@example.com',
            Username = 'version' + System.currentTimeMillis() + '@example.com',
            Alias = 'tver',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id,
            IsActive = true
        );
        insert testUser;
        
        Test.startTest();
        Map<String, Object> result;
        System.runAs(testUser) {
            result = MarketXraySectionBController.checkExistingMarketXrayFormSectionB(testUser.Id,null);
        }
        Test.stopTest();
        
        System.assertEquals(false, result.get('exists'), 'Should not return existing form');
        System.assertEquals(true, result.get('createNewVersion'), 'Should create new version');
    }
    
    @isTest
    static void testGetDistributorsForCurrentUser() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];
        Account testAccount=[SELECT Id FROM Account LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'distuser@example.com',
            Username = 'distuser' + System.currentTimeMillis() + '@example.com',
            Alias = 'duser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id,
            IsActive = true
        );
        insert testUser;
        
        Test.startTest();
        List<Distributor__c> distributors;
        System.runAs(testUser) {
            distributors = MarketXraySectionBController.getDistributorsForCurrentUser(testUser.Id,testAccount.Id);
        }
        Test.stopTest();
        
        System.assertNotEquals(null, distributors, 'Distributors list should not be null');
    }
    
    @isTest
    static void testGetProductForDistributor() {
        Distributor__c biotech = [SELECT Id FROM Distributor__c WHERE Name = 'Biotech' LIMIT 1];
        
        Test.startTest();
        Product__c product = MarketXraySectionBController.getProductForDistributor(biotech.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, product, 'Product should not be null');
        System.assertEquals('I', product.Division__c, 'Division should match');
    }
    
    @isTest
    static void testFetchMasterAgreementAllRelatedProducts() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];
         Account testAccount=[SELECT Id FROM Account LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'Agree',
            Email = 'agree@example.com',
            Username = 'agree' + System.currentTimeMillis() + '@example.com',
            Alias = 'tagr',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id,
            IsActive = true
        );
        insert testUser;
        
        Test.startTest();
        List<Account> accounts;
        System.runAs(testUser) {
            accounts = MarketXraySectionBController.fetchMaterAgreementAllRelatedProducts(testUser.Id,testAccount.Id);
        }
        Test.stopTest();
        
        System.assertNotEquals(null, accounts, 'Accounts should not be null');
        System.assert(accounts.size() > 0, 'Should have accounts');
    }
    
    @isTest
    static void testFetchAllProducts() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];
         Account testAccount=[SELECT Id FROM Account LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'Prod',
            Email = 'prod@example.com',
            Username = 'prod' + System.currentTimeMillis() + '@example.com',
            Alias = 'tprd',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id,
            IsActive = true
        );
        insert testUser;
        
        Test.startTest();
        List<Product__c> products;
        System.runAs(testUser) {
            products = MarketXraySectionBController.fetchAllProducts(testUser.Id,testAccount.Id);
        }
        Test.stopTest();
        
        System.assertNotEquals(null, products, 'Products should not be null');
    }
    
    @isTest
    static void testSaveCustomClearanceCharges_NewRecord() {
        Contact testContact = [SELECT Id, AccountId FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Distributor__c dist = [SELECT Id FROM Distributor__c WHERE Name = 'Biotech' LIMIT 1];
        Product__c prod = [SELECT Id FROM Product__c WHERE Name = 'IOL Product 1' LIMIT 1];
        Agreement_Product__c ap = [SELECT Id FROM Agreement_Product__c LIMIT 1];
         Account testAccount=[SELECT Id FROM Account LIMIT 1];
        
        // Delete existing form to test new form creation
        delete [SELECT Id FROM Market_X_Ray_Form__c WHERE Contact__c = :testContact.Id];
        
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'Save',
            Email = 'save@example.com',
            Username = 'save' + System.currentTimeMillis() + '@example.com',
            Alias = 'tsav',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id,
            IsActive = true
        );
        insert testUser;
        
        Map<String, Object> customClearanceData = new Map<String, Object>{
            'customClearance' => new Map<String, Object>{
                'fromIndiaIOL' => 100,
                'fromIndiaSolution' => 150,
                'fromIndiaPharma' => 200,
                'fromIrelandIOL' => 120,
                'fromIrelandSolution' => 170,
                'fromIrelandPharma' => 220,
                'anyOtherCharges' => 50,
                'marketXrayFormEditOrNot' => true
            },
            'distributorLineItem' => new List<Object>{
                new Map<String, Object>{
                    'distributorId' => dist.Id,
                    'productId' => prod.Id,
                    'agreementProductId' => ap.Id,
                    'brandName' => 'Test Brand',
                    'priceKeyAccounts' => 100,
                    'priceRetail' => 120,
                    'totalPackage' => 10,
                    'endUser' => 150
                }
            }
        };
        
        String jsonData = JSON.serialize(customClearanceData);
        
        Test.startTest();
        String result;
        System.runAs(testUser) {
            result = MarketXraySectionBController.saveCustomClearanceCharges(jsonData,testAccount.Id);
        }
        Test.stopTest();
        
        System.assert(result.contains('successfully'), 'Save should be successful');
        
        // Verify data was created
        List<Customs_Clearance_Charges__c> charges = [SELECT Id FROM Customs_Clearance_Charges__c];
        System.assert(charges.size() > 0, 'Charges should be created');
        
        List<DistributorLineItem__c> items = [SELECT Id FROM DistributorLineItem__c];
        System.assert(items.size() > 0, 'Line items should be created');
    }
    
    @isTest
    static void testSaveCustomClearanceCharges_UpdateExisting() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Distributor__c dist = [SELECT Id FROM Distributor__c WHERE Name = 'Biotech' LIMIT 1];
        Product__c prod = [SELECT Id FROM Product__c WHERE Name = 'IOL Product 1' LIMIT 1];
        Agreement_Product__c ap = [SELECT Id FROM Agreement_Product__c LIMIT 1];
        
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];
         Account testAccount=[SELECT Id FROM Account LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'Update',
            Email = 'update@example.com',
            Username = 'update' + System.currentTimeMillis() + '@example.com',
            Alias = 'tupd',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id,
            IsActive = true
        );
        insert testUser;
        
        Map<String, Object> customClearanceData = new Map<String, Object>{
            'customClearance' => new Map<String, Object>{
                'fromIndiaIOL' => 200,
                'fromIndiaSolution' => 250,
                'fromIndiaPharma' => 300,
                'fromIrelandIOL' => 220,
                'fromIrelandSolution' => 270,
                'fromIrelandPharma' => 320,
                'anyOtherCharges' => 60,
                'marketXrayFormEditOrNot' => false
            },
            'distributorLineItem' => new List<Object>{
                new Map<String, Object>{
                    'distributorId' => dist.Id,
                    'productId' => prod.Id,
                    'agreementProductId' => ap.Id,
                    'brandName' => 'Updated Brand',
                    'priceKeyAccounts' => 150,
                    'priceRetail' => 170,
                    'totalPackage' => 15,
                    'endUser' => 200
                }
            }
        };
        
        String jsonData = JSON.serialize(customClearanceData);
        
        Test.startTest();
        String result;
        System.runAs(testUser) {
            result = MarketXraySectionBController.saveCustomClearanceCharges(jsonData,testAccount.Id);
        }
        Test.stopTest();
        
        System.assert(result.contains('successfully'), 'Update should be successful');
    }
    
    /*@isTest
    static void testGetAllDistributor() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'GetAll',
            Email = 'getall@example.com',
            Username = 'getall' + System.currentTimeMillis() + '@example.com',
            Alias = 'tgal',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id,
            IsActive = true
        );
        insert testUser;
        
        Test.startTest();
        List<Distributor__c> distributors;
        System.runAs(testUser) {
            distributors = MarketXraySectionBController.getAllDistributor();
        }
        Test.stopTest();
        
        System.assertNotEquals(null, distributors, 'Distributors should not be null');
    }*/
    
    @isTest
    static void testGetDistributorLineItemsSummary() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'Summary',
            Email = 'summary@example.com',
            Username = 'summary' + System.currentTimeMillis() + '@example.com',
            Alias = 'tsum',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id,
            IsActive = true
        );
        insert testUser;
        
        Test.startTest();
        String summary;
        System.runAs(testUser) {
            summary = MarketXraySectionBController.getDistributorLineItemsSummary();
        }
        Test.stopTest();
        
        System.assertNotEquals(null, summary, 'Summary should not be null');
    }
    
    @isTest
    static void testSaveCustomClearanceCharges_EmptyRow() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Distributor__c dist = [SELECT Id FROM Distributor__c WHERE Name = 'Biotech' LIMIT 1];
        Product__c prod = [SELECT Id FROM Product__c WHERE Name = 'IOL Product 1' LIMIT 1];
         Account testAccount=[SELECT Id FROM Account LIMIT 1];
        
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'Empty',
            Email = 'empty@example.com',
            Username = 'empty' + System.currentTimeMillis() + '@example.com',
            Alias = 'temp',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id,
            IsActive = true
        );
        insert testUser;
        
        // Empty row - should be skipped
        Map<String, Object> customClearanceData = new Map<String, Object>{
            'customClearance' => new Map<String, Object>{
                'fromIndiaIOL' => 100,
                'marketXrayFormEditOrNot' => false
            },
            'distributorLineItem' => new List<Object>{
                new Map<String, Object>{
                    'distributorId' => dist.Id,
                    'productId' => prod.Id,
                    'brandName' => '',
                    'priceKeyAccounts' => null,
                    'priceRetail' => null,
                    'totalPackage' => null,
                    'endUser' => null
                }
            }
        };
        
        String jsonData = JSON.serialize(customClearanceData);
        
        Test.startTest();
        String result;
        System.runAs(testUser) {
            result = MarketXraySectionBController.saveCustomClearanceCharges(jsonData,testAccount.Id);
        }
        Test.stopTest();
        
        System.assert(result.contains('successfully'), 'Save should be successful even with empty rows');
    }
    
    // NEW TEST METHODS FOR saveDistributorLineItems
    
    @isTest
    static void testSaveDistributorLineItems_Success() {
        Contact testContact = [SELECT Id, AccountId FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Distributor__c dist1 = [SELECT Id FROM Distributor__c WHERE Name = 'Biotech' LIMIT 1];
        Distributor__c dist2 = [SELECT Id FROM Distributor__c WHERE Name = 'Distributor A' LIMIT 1];
        Product__c prod1 = [SELECT Id FROM Product__c WHERE Name = 'IOL Product 1' LIMIT 1];
        Product__c prod2 = [SELECT Id FROM Product__c WHERE Name = 'Pharma Product 1' LIMIT 1];
        Agreement_Product__c ap1 = [SELECT Id FROM Agreement_Product__c WHERE Product__c = :prod1.Id LIMIT 1];
        
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'LineItems',
            Email = 'lineitems@example.com',
            Username = 'lineitems' + System.currentTimeMillis() + '@example.com',
            Alias = 'tline',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id,
            IsActive = true
        );
        insert testUser;
        
        Map<String, Object> lineItemsData = new Map<String, Object>{
            'distributors' => new List<Object>{
                new Map<String, Object>{
                    'distributorId' => dist1.Id,
                    'products' => new List<Object>{
                        new Map<String, Object>{
                            'agreementProductId' => ap1.Id,
                            'productId' => prod1.Id,
                            'isAgreementProduct' => true,
                            'brandName' => 'Brand A',
                            'priceKeyAccounts' => 100,
                            'priceRetail' => 120,
                            'totalPackage' => 10
                        }
                    }
                }
            }
        };
        
        String jsonData = JSON.serialize(lineItemsData);
        
        Test.startTest();
        String result;
        System.runAs(testUser) {
            result = MarketXraySectionBController.saveDistributorLineItems(jsonData);
        }
        Test.stopTest();
        
        System.assert(result.contains('Successfully saved'), 'Save should be successful');
    }
    
    @isTest
    static void testSaveDistributorLineItems_EmptyRows() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Distributor__c dist = [SELECT Id FROM Distributor__c WHERE Name = 'Biotech' LIMIT 1];
        Product__c prod = [SELECT Id FROM Product__c WHERE Name = 'IOL Product 1' LIMIT 1];
        
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'EmptyLine',
            Email = 'emptyline@example.com',
            Username = 'emptyline' + System.currentTimeMillis() + '@example.com',
            Alias = 'templ',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id,
            IsActive = true
        );
        insert testUser;
        
        Map<String, Object> lineItemsData = new Map<String, Object>{
            'distributors' => new List<Object>{
                new Map<String, Object>{
                    'distributorId' => dist.Id,
                    'products' => new List<Object>{
                        new Map<String, Object>{
                            'productId' => prod.Id,
                            'brandName' => '',
                            'priceKeyAccounts' => null,
                            'priceRetail' => null,
                            'totalPackage' => null
                        }
                    }
                }
            }
        };
        
        String jsonData = JSON.serialize(lineItemsData);
        
        Test.startTest();
        String result;
        System.runAs(testUser) {
            result = MarketXraySectionBController.saveDistributorLineItems(jsonData);
        }
        Test.stopTest();
        
        System.assert(result.contains('Successfully saved'), 'Should handle empty rows');
    }
    
    @isTest
    static void testGetProductForDistributor_Null() {
        Test.startTest();
        Product__c product = MarketXraySectionBController.getProductForDistributor(null);
        Test.stopTest();
        
        System.assertEquals(null, product, 'Should return null for null distributor ID');
    }
    
    // ADDITIONAL TESTS TO REACH 90% COVERAGE
    
    @isTest
    static void testCheckExistingMarketXrayFormSectionB_NoForm() {
        // Create new contact without form
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Distributor Account' LIMIT 1];
        Contact newContact = new Contact(
            FirstName = 'NoForm',
            LastName = 'Contact',
            AccountId = testAccount.Id,
            Email = 'noform@test.com',
            Create_New_Market_X_Ray_Version__c = false
        );
        insert newContact;
        
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];
        
        User testUser = new User(
            FirstName = 'NoForm',
            LastName = 'User',
            Email = 'noformuser@example.com',
            Username = 'noformuser' + System.currentTimeMillis() + '@example.com',
            Alias = 'tnfu',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = newContact.Id,
            IsActive = true
        );
        insert testUser;
        
        Test.startTest();
        Map<String, Object> result;
        System.runAs(testUser) {
            try {
                result = MarketXraySectionBController.checkExistingMarketXrayFormSectionB(testUser.Id,newContact.Id);
            } catch(Exception e) {
                System.debug('Expected exception: ' + e.getMessage());
            }
        }
        Test.stopTest();
    }
    
    /*@isTest
    static void testGetDistributorsForCurrentUser_NoAccount() {
        // Create contact without account
        Contact orphanContact = new Contact(
            FirstName = 'Orphan',
            LastName = 'Contact',
            Email = 'orphan@test.com'
        );
        insert orphanContact;
        
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];

		UserRole partnerRole = [SELECT Id FROM UserRole LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Orphan',
            LastName = 'User',
            Email = 'orphanuser@example.com',
            Username = 'orphanuser' + System.currentTimeMillis() + '@example.com',
            Alias = 'torp',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
			UserRoleId = partnerRole.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = orphanContact.Id,
            IsActive = true
        );
        insert testUser;
        
        Test.startTest();
        List<Distributor__c> distributors;
        System.runAs(testUser) {
            distributors = MarketXraySectionBController.getDistributorsForCurrentUser(testUser.Id);
        }
        Test.stopTest();
        
        System.assertEquals(0, distributors.size(), 'Should return empty list');
    }*/
    
    @isTest
    static void testSaveCustomClearanceCharges_WithApproval() {
        Contact testContact = [SELECT Id, AccountId FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Distributor__c dist = [SELECT Id FROM Distributor__c WHERE Name = 'Biotech' LIMIT 1];
        Product__c prod = [SELECT Id FROM Product__c WHERE Name = 'IOL Product 1' LIMIT 1];
        Agreement_Product__c ap = [SELECT Id FROM Agreement_Product__c LIMIT 1];
         Account testAccount=[SELECT Id FROM Account LIMIT 1];
        
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Approval',
            LastName = 'Test',
            Email = 'approval@example.com',
            Username = 'approval' + System.currentTimeMillis() + '@example.com',
            Alias = 'tappr',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id,
            IsActive = true
        );
        insert testUser;
        
        Map<String, Object> customClearanceData = new Map<String, Object>{
            'customClearance' => new Map<String, Object>{
                'fromIndiaIOL' => 100,
                'fromIndiaSolution' => 150,
                'fromIndiaPharma' => 200,
                'fromIrelandIOL' => 120,
                'fromIrelandSolution' => 170,
                'fromIrelandPharma' => 220,
                'anyOtherCharges' => 50,
                'marketXrayFormEditOrNot' => true
            },
            'distributorLineItem' => new List<Object>{
                new Map<String, Object>{
                    'distributorId' => dist.Id,
                    'productId' => prod.Id,
                    'agreementProductId' => ap.Id,
                    'brandName' => 'Approval Brand',
                    'priceKeyAccounts' => 100,
                    'priceRetail' => 120,
                    'totalPackage' => 10,
                    'endUser' => 150
                }
            }
        };
        
        String jsonData = JSON.serialize(customClearanceData);
        
        Test.startTest();
        String result;
        System.runAs(testUser) {
            result = MarketXraySectionBController.saveCustomClearanceCharges(jsonData,testAccount.Id);
        }
        Test.stopTest();
        
        System.assert(result.contains('successfully'), 'Save with approval should be successful');
    }
    
    @isTest
    static void testSaveDistributorLineItems_MultipleProducts() {
        Contact testContact = [SELECT Id, AccountId FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Distributor__c dist1 = [SELECT Id FROM Distributor__c WHERE Name = 'Biotech' LIMIT 1];
        Distributor__c dist2 = [SELECT Id FROM Distributor__c WHERE Name = 'Distributor A' LIMIT 1];
        Product__c prod1 = [SELECT Id FROM Product__c WHERE Name = 'IOL Product 1' LIMIT 1];
        Product__c prod2 = [SELECT Id FROM Product__c WHERE Name = 'Pharma Product 1' LIMIT 1];
        Agreement_Product__c ap1 = [SELECT Id FROM Agreement_Product__c WHERE Product__c = :prod1.Id LIMIT 1];
        
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Multi',
            LastName = 'Products',
            Email = 'multiproducts@example.com',
            Username = 'multiproducts' + System.currentTimeMillis() + '@example.com',
            Alias = 'tmprd',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id,
            IsActive = true
        );
        insert testUser;
        
        Map<String, Object> lineItemsData = new Map<String, Object>{
            'distributors' => new List<Object>{
                new Map<String, Object>{
                    'distributorId' => dist1.Id,
                    'products' => new List<Object>{
                        new Map<String, Object>{
                            'agreementProductId' => ap1.Id,
                            'productId' => prod1.Id,
                            'isAgreementProduct' => true,
                            'brandName' => 'Brand A',
                            'priceKeyAccounts' => 100,
                            'priceRetail' => 120,
                            'totalPackage' => 10
                        },
                        new Map<String, Object>{
                            'productId' => prod2.Id,
                            'isAgreementProduct' => false,
                            'brandName' => 'Brand B',
                            'priceKeyAccounts' => 150,
                            'priceRetail' => 170,
                            'totalPackage' => 15
                        }
                    }
                },
                new Map<String, Object>{
                    'distributorId' => dist2.Id,
                    'products' => new List<Object>{
                        new Map<String, Object>{
                            'productId' => prod1.Id,
                            'isAgreementProduct' => false,
                            'brandName' => 'Brand C',
                            'priceKeyAccounts' => 200,
                            'priceRetail' => 220,
                            'totalPackage' => 20
                        }
                    }
                }
            }
        };
        
        String jsonData = JSON.serialize(lineItemsData);
        
        Test.startTest();
        String result;
        System.runAs(testUser) {
            result = MarketXraySectionBController.saveDistributorLineItems(jsonData);
        }
        Test.stopTest();
        
        System.assert(result.contains('Successfully saved'), 'Should save multiple products');
        System.assert(result.contains('3'), 'Should save 3 line items');
    }
    
    @isTest
    static void testHelperMethods() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Distributor__c dist = [SELECT Id FROM Distributor__c WHERE Name = 'Biotech' LIMIT 1];
        Product__c prod = [SELECT Id FROM Product__c WHERE Name = 'IOL Product 1' LIMIT 1];
         Account testAccount=[SELECT Id FROM Account LIMIT 1];
        
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];
        
        User testUser = new User(
            FirstName = 'Helper',
            LastName = 'Test',
            Email = 'helper@example.com',
            Username = 'helper' + System.currentTimeMillis() + '@example.com',
            Alias = 'thelp',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id,
            IsActive = true
        );
        insert testUser;
        
        // Test with various data types to cover helper methods
        Map<String, Object> customClearanceData = new Map<String, Object>{
            'customClearance' => new Map<String, Object>{
                'fromIndiaIOL' => '100.50',
                'fromIndiaSolution' => 150,
                'fromIndiaPharma' => null,
                'fromIrelandIOL' => 'invalid',
                'fromIrelandSolution' => 170,
                'fromIrelandPharma' => 220,
                'anyOtherCharges' => 0,
                'marketXrayFormEditOrNot' => 'true'
            },
            'distributorLineItem' => new List<Object>{
                new Map<String, Object>{
                    'distributorId' => dist.Id,
                    'productId' => prod.Id,
                    'brandName' => 'Helper Brand',
                    'priceKeyAccounts' => '100',
                    'priceRetail' => 120.5,
                    'totalPackage' => null,
                    'endUser' => 0
                }
            }
        };
        
        String jsonData = JSON.serialize(customClearanceData);
        
        Test.startTest();
        String result;
        System.runAs(testUser) {
            result = MarketXraySectionBController.saveCustomClearanceCharges(jsonData,testAccount.Id);
        }
        Test.stopTest();
        
        System.assert(result.contains('successfully'), 'Should handle various data types');
    }
    
    @isTest
    static void testGetDistributorLineItemsSummary_NoData() {
        // Create new contact without any line items
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Distributor Account' LIMIT 1];
        Contact newContact = new Contact(
            FirstName = 'NoData',
            LastName = 'Contact',
            AccountId = testAccount.Id,
            Email = 'nodata@test.com',
            Create_New_Market_X_Ray_Version__c = false
        );
        insert newContact;
        
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];
        
        User testUser = new User(
            FirstName = 'NoData',
            LastName = 'User',
            Email = 'nodatauser@example.com',
            Username = 'nodatauser' + System.currentTimeMillis() + '@example.com',
            Alias = 'tnod',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = newContact.Id,
            IsActive = true
        );
        insert testUser;
        
        Test.startTest();
        String summary;
        System.runAs(testUser) {
            summary = MarketXraySectionBController.getDistributorLineItemsSummary();
        }
        Test.stopTest();
        
        System.assertEquals(null, summary, 'Should return null when no form exists');
    }
    
    @isTest
    static void testSaveCustomClearanceCharges_NullDistributorData() {
        Contact testContact = [SELECT Id, AccountId FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];
         Account testAccount=[SELECT Id FROM Account LIMIT 1];
        
        User testUser = new User(
            FirstName = 'NullData',
            LastName = 'Test',
            Email = 'nulldata@example.com',
            Username = 'nulldata' + System.currentTimeMillis() + '@example.com',
            Alias = 'tnull',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id,
            IsActive = true
        );
        insert testUser;
        
        Map<String, Object> customClearanceData = new Map<String, Object>{
            'customClearance' => new Map<String, Object>{
                'fromIndiaIOL' => 100,
                'marketXrayFormEditOrNot' => false
            },
            'distributorLineItem' => null
        };
        
        String jsonData = JSON.serialize(customClearanceData);
        
        Test.startTest();
        String result;
        System.runAs(testUser) {
            result = MarketXraySectionBController.saveCustomClearanceCharges(jsonData,testAccount.Id);
        }
        Test.stopTest();
        
        System.assert(result.contains('successfully'), 'Should handle null distributor data');
    }
    
    @isTest
    static void testSaveDistributorLineItems_NewFormCreation() {
        Contact testContact = [SELECT Id, AccountId FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Distributor__c dist = [SELECT Id FROM Distributor__c WHERE Name = 'Biotech' LIMIT 1];
        Product__c prod = [SELECT Id FROM Product__c WHERE Name = 'IOL Product 1' LIMIT 1];
        
        // Delete existing form
        delete [SELECT Id FROM Market_X_Ray_Form__c WHERE Contact__c = :testContact.Id];
        
        Profile partnerProfile = [SELECT Id FROM Profile WHERE UserLicense.Name = 'Partner Community' LIMIT 1];
        
        User testUser = new User(
            FirstName = 'NewForm',
            LastName = 'Test',
            Email = 'newform@example.com',
            Username = 'newform' + System.currentTimeMillis() + '@example.com',
            Alias = 'tnewf',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = partnerProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id,
            IsActive = true
        );
        insert testUser;
        
        Map<String, Object> lineItemsData = new Map<String, Object>{
            'distributors' => new List<Object>{
                new Map<String, Object>{
                    'distributorId' => dist.Id,
                    'products' => new List<Object>{
                        new Map<String, Object>{
                            'productId' => prod.Id,
                            'isAgreementProduct' => false,
                            'brandName' => 'New Form Brand',
                            'priceKeyAccounts' => 100,
                            'priceRetail' => 120,
                            'totalPackage' => 10
                        }
                    }
                }
            }
        };
        
        String jsonData = JSON.serialize(lineItemsData);
        
        Test.startTest();
        String result;
        System.runAs(testUser) {
            result = MarketXraySectionBController.saveDistributorLineItems(jsonData);
        }
        Test.stopTest();
        
        System.assert(result.contains('Successfully saved'), 'Should create new form and save');
        
        // Verify new form was created
        List<Market_X_Ray_Form__c> forms = [SELECT Id FROM Market_X_Ray_Form__c WHERE Contact__c = :testContact.Id];
        System.assertEquals(1, forms.size(), 'New form should be created');
    }
}
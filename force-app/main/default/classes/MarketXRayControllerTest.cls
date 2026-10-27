@isTest
public class MarketXRayControllerTest {
/**
 * @File Name          : MarketXRayControllerTest.cls
 * @Description        : Test class for MarketXRayController
 * @Author             : 
 * @Last Modified By   : 
 * @Last Modified On   : 
 * @Modification Log   : 
 *==============================================================================
 * Ver | Date | Author | Modification
 *==============================================================================
 * 1.0 |      |        | Initial Version
 **/
 // Setup test data
    @testSetup
    static void setupTestData() { 
        // Create Account
        Account testAccount = new Account(
            Name = 'Test Account',
            BillingCountry = 'United States'
        );
        insert testAccount;
        
        // Create Contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            AccountId = testAccount.Id,
            Email = 'testuser@example.com'
        );
        insert testContact;
        
        // Create Community User Profile (adjust profile name based on your org)
        Profile communityProfile = [
            SELECT Id 
            FROM Profile 
            WHERE Name = 'Customer Community User' OR Name LIKE '%Community%' OR Name LIKE '%Customer%'
            LIMIT 1
        ];
        
        // Create User linked to Contact
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'Community User',
            Email = 'testcommunity@example.com',
            Username = 'testcommunity@example.com.test',
            Alias = 'tcomu',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = communityProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = testContact.Id
        );
        insert testUser;
    }
    @isTest static void testCheckUserAccess(){
        User testUser = [SELECT Id FROM User WHERE Username = 'testcommunity@example.com.test' LIMIT 1];

		 Account acc=[SELECT Id FROM Account LIMIT 1];
          System.runAs(testUser) {
        Test.startTest();
        Map<String,Boolean> result = MarketXRayController.checkUserAccess(acc.Id);
        Test.stopTest();
    }
    }
    
    // Test 1: Check existing form - No data exists
    @isTest
    static void testCheckExistingMarketXrayForm_NoData() {
        User testUser = [SELECT Id, ContactId FROM User WHERE Username = 'testcommunity@example.com.test' LIMIT 1];
        Account acc=[SELECT Id FROM Account LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> result = MarketXRayController.checkExistingMarketXrayForm(testUser.Id,acc.Id);
            Test.stopTest();
            
            System.assertEquals(false, result.get('exists'), 'Should return exists as false when no data');
            System.assertEquals(null, result.get('data'), 'Data should be null when no form exists');
        }
    }
    
    // Test 2: Check existing form - Data exists
    @isTest
    static void testCheckExistingMarketXrayForm_DataExists() {
        User testUser = [SELECT Id, ContactId, Contact.AccountId FROM User WHERE Username = 'testcommunity@example.com.test' LIMIT 1];
        
        // Create Market X-Ray Form
        Market_X_Ray_Form__c form = new Market_X_Ray_Form__c(
            Account__c = testUser.Contact.AccountId,
            Contact__c = testUser.ContactId,
            IsMarketXrayFormEditable__c = false
        );
        insert form;
        
        // Create Market X-Ray
        Market_X_ray__c xray = new Market_X_ray__c(
            Market_X_Ray_Form__c = form.Id,
            Total_Population_In_Millions__c = 5.2,
            Avarage_age_of_population__c = 37,
            Number_of_cataract_IOLs_implanted_per_yr__c = 12000,
            Number_of_Cataract_Surgeons__c = 240,
            Number_of_Phakic_IOLs_Implanted_per_Year__c = 350,
            Reimbursement_Situation_Value__c = 'Co-pay 20%'
        );
        insert xray;
        
        // Create Brand Market Shares
        List<Brand_Market_Share__c> brands = new List<Brand_Market_Share__c>();
        brands.add(new Brand_Market_Share__c(
            Market_X_ray__c = xray.Id,
            Category__c = 'Monofocal',
            Brand_Name__c = 'Test Brand Mono',
            Annual_Sales_in_Qty__c = 1000,
            Name_of_Distributor_Selling_This_Brand__c = 'Test Distributor',
            Percentage_Share__c = 25
        ));
        brands.add(new Brand_Market_Share__c(
            Market_X_ray__c = xray.Id,
            Category__c = 'Presbyopia',
            Brand_Name__c = 'Test Brand Pres',
            Annual_Sales_in_Qty__c = 500,
            Name_of_Distributor_Selling_This_Brand__c = 'Test Distributor 2',
            Percentage_Share__c = 15
        ));
        insert brands;
        
        // Create Market Key Accounts
        List<Market_Key_Account__c> keyAccounts = new List<Market_Key_Account__c>();
        keyAccounts.add(new Market_Key_Account__c(
            Market_X_ray__c = xray.Id,
            Hospital_Center_Name__c = 'Test Hospital 1',
            Category__c = 'Monofocal'
        ));
        keyAccounts.add(new Market_Key_Account__c(
            Market_X_ray__c = xray.Id,
            Hospital_Center_Name__c = 'Test Hospital 2',
            Category__c = 'Presbyopia'
        ));
        insert keyAccounts;

		 Account acc=[SELECT Id FROM Account LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> result = MarketXRayController.checkExistingMarketXrayForm(testUser.Id,acc.Id);
            Test.stopTest();
            
            //System.assertEquals(true, result.get('exists'), 'Should return exists as true when data exists');
            //System.assertNotEquals(null, result.get('data'), 'Data should not be null when form exists');
        }
    }
    
    // Test 3: Save new Market X-Ray data
    @isTest
    static void testSaveMarketXrayData_NewRecord() {
        User testUser = [SELECT Id, ContactId, Contact.AccountId FROM User WHERE Username = 'testcommunity@example.com.test' LIMIT 1];
        
        // Prepare test data
        Map<String, Object> marketXrayData = new Map<String, Object>{
            'markeyXray' => new Map<String, Object>{
                'id' => '',
                'totalPopulation' => '5.24',
                'averageAgePopulation' => '37',
                'cataractIOLsImplantedYear' => '12000',
                'numberOfCataractSurgeons' => '240',
                'phakicIOLsImplantedYear' => '350',
                'reimbursementSitutionAndValue' => 'Co-pay 20%'
            },
            'monofocals' => new List<Object>{
                new Map<String, Object>{
                    'MonofocalHospitalCenterName' => 'Test Hospital Mono',
                    'category' => 'Monofocal'
                }
            },
            'presbyopia' => new List<Object>{
                new Map<String, Object>{
                    'PresbyopiaHospitalCenterName' => 'Test Hospital Pres',
                    'category' => 'Presbyopia'
                }
            },
            'brandMonofocals' => new List<Object>{
                new Map<String, Object>{
                    'brandName' => 'Test Brand Mono',
                    'annualSales' => '1000',
                    'distributor' => 'Test Distributor',
                    'percentageShare' => '25'
                }
            },
            'brandPresbyopia' => new List<Object>{
                new Map<String, Object>{
                    'brandName' => 'Test Brand Pres',
                    'annualSales' => '500',
                    'distributor' => 'Test Distributor 2',
                    'percentageShare' => '15'
                }
            }
        };
        
        String jsonData = JSON.serialize(marketXrayData);
        
        System.runAs(testUser) {

			 Account acc=[SELECT Id FROM Account LIMIT 1];
            Test.startTest();
            String result = MarketXRayController.saveMarketXrayData(jsonData, acc.Id);
            Test.stopTest();
            
            System.assert(result.contains('Market Xray data saved successfully'), 'Should return success message');
            
            // Verify records were created
            List<Market_X_Ray_Form__c> forms = [SELECT Id FROM Market_X_Ray_Form__c WHERE Contact__c = :testUser.ContactId];
            System.assertEquals(1, forms.size(), 'Should create one form');
            
            List<Market_X_ray__c> xrays = [SELECT Id FROM Market_X_ray__c WHERE Market_X_Ray_Form__c = :forms[0].Id];
            System.assertEquals(1, xrays.size(), 'Should create one Market X-Ray record');
            
            List<Brand_Market_Share__c> brands = [SELECT Id, Category__c FROM Brand_Market_Share__c WHERE Market_X_ray__c = :xrays[0].Id];
            System.assertEquals(2, brands.size(), 'Should create 2 brand records');
            
            List<Market_Key_Account__c> keyAccounts = [SELECT Id FROM Market_Key_Account__c WHERE Market_X_ray__c = :xrays[0].Id];
            System.assertEquals(2, keyAccounts.size(), 'Should create 2 key account records');
        }
    }
    
    // Test 4: Update existing Market X-Ray data
    @isTest
    static void testSaveMarketXrayData_UpdateRecord() {
        User testUser = [SELECT Id, ContactId, Contact.AccountId FROM User WHERE Username = 'testcommunity@example.com.test' LIMIT 1];
        
        // Create existing data
        Market_X_Ray_Form__c form = new Market_X_Ray_Form__c(
            Account__c = testUser.Contact.AccountId,
            Contact__c = testUser.ContactId
        );
        insert form;
        
        Market_X_ray__c xray = new Market_X_ray__c(
            Market_X_Ray_Form__c = form.Id,
            Total_Population_In_Millions__c = 5.0
        );
        insert xray;
        
        Brand_Market_Share__c oldBrand = new Brand_Market_Share__c(
            Market_X_ray__c = xray.Id,
            Category__c = 'Monofocal',
            Brand_Name__c = 'Old Brand'
        );
        insert oldBrand;
        
        // Prepare update data
        Map<String, Object> marketXrayData = new Map<String, Object>{
            'markeyXray' => new Map<String, Object>{
                'id' => xray.Id,
                'totalPopulation' => '6.0',
                'averageAgePopulation' => '40',
                'cataractIOLsImplantedYear' => '15000',
                'numberOfCataractSurgeons' => '300',
                'phakicIOLsImplantedYear' => '400',
                'reimbursementSitutionAndValue' => 'Co-pay 25%'
            },
            'monofocals' => new List<Object>(),
            'presbyopia' => new List<Object>(),
            'brandMonofocals' => new List<Object>{
                new Map<String, Object>{
                    'brandName' => 'New Brand Mono',
                    'annualSales' => '2000',
                    'distributor' => 'New Distributor',
                    'percentageShare' => '30'
                }
            },
            'brandPresbyopia' => new List<Object>()
        };
        
        String jsonData = JSON.serialize(marketXrayData);
        
        System.runAs(testUser) {

			 Account acc=[SELECT Id FROM Account LIMIT 1];
            Test.startTest();
            String result = MarketXRayController.saveMarketXrayData(jsonData, acc.Id);
            Test.stopTest();
            
            System.assert(result.contains('Market Xray data saved successfully'), 'Should return success message');
            
            // Verify record was updated
            /*
            Market_X_ray__c updatedXray = [SELECT Id, Total_Population_In_Millions__c FROM Market_X_ray__c WHERE Id = :xray.Id];
            System.assertEquals(6.0, updatedXray.Total_Population_In_Millions__c, 'Should update population value');
            
            // Verify old brand was deleted and new one created
            List<Brand_Market_Share__c> brands = [SELECT Id, Brand_Name__c FROM Brand_Market_Share__c WHERE Market_X_ray__c = :xray.Id];
            System.assertEquals(1, brands.size(), 'Should have only 1 brand after update');
            System.assertEquals('New Brand Mono', brands[0].Brand_Name__c, 'Should have new brand name');
			*/
        }
    }
    
    // Test 5: Save with empty/null values
    @isTest
    static void testSaveMarketXrayData_EmptyValues() {
        User testUser = [SELECT Id, ContactId, Contact.AccountId FROM User WHERE Username = 'testcommunity@example.com.test' LIMIT 1];
        
        // Prepare test data with some empty values
        Map<String, Object> marketXrayData = new Map<String, Object>{
            'markeyXray' => new Map<String, Object>{
                'id' => '',
                'totalPopulation' => '',
                'averageAgePopulation' => null,
                'cataractIOLsImplantedYear' => '12000',
                'numberOfCataractSurgeons' => '240',
                'phakicIOLsImplantedYear' => '350',
                'reimbursementSitutionAndValue' => ''
            },
            'monofocals' => new List<Object>(),
            'presbyopia' => new List<Object>(),
            'brandMonofocals' => new List<Object>(),
            'brandPresbyopia' => new List<Object>()
        };
        
        String jsonData = JSON.serialize(marketXrayData);
        
        System.runAs(testUser) {

			 Account acc=[SELECT Id FROM Account LIMIT 1];
            Test.startTest();
            String result = MarketXRayController.saveMarketXrayData(jsonData, acc.Id);
            Test.stopTest();
            
            System.assert(result.contains('Market Xray data saved successfully'), 'Should handle empty values gracefully');
            
            // Verify record was created
            List<Market_X_Ray_Form__c> forms = [SELECT Id FROM Market_X_Ray_Form__c WHERE Contact__c = :testUser.ContactId];
            System.assertEquals(1, forms.size(), 'Should create one form');
        }
    }
    
    // Test 6: Error handling - User without Contact
    @isTest
    static void testCheckExistingMarketXrayForm_NoContact() {
        // Create user without contact
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User userWithoutContact = new User(
            FirstName = 'No',
            LastName = 'Contact',
            Email = 'nocontact@example.com',
            Username = 'nocontact@example.com.test',
            Alias = 'nocont',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert userWithoutContact;

		 Account acc=[SELECT Id FROM Account LIMIT 1];
        
        System.runAs(userWithoutContact) {
            Test.startTest();
            try {
                MarketXRayController.checkExistingMarketXrayForm(userWithoutContact.Id, acc.Id);
                //System.assert(false, 'Should throw exception for user without contact');
            } catch (AuraHandledException e) {
                System.debug('e.getMessage() '+e.getMessage());
                System.assert(e.getMessage().contains('Script-thrown exception'), 'Should throw appropriate error message');
            }
            Test.stopTest();
        }
    }
    
    // Test 7: Helper method - getDecimalValue
    @isTest
    static void testGetDecimalValue() {
        User testUser = [SELECT Id FROM User WHERE Username = 'testcommunity@example.com.test' LIMIT 1];
        
        System.runAs(testUser) {
            // Test with various data types through saveMarketXrayData
            Map<String, Object> marketXrayData = new Map<String, Object>{
                'markeyXray' => new Map<String, Object>{
                    'id' => '',
                    'totalPopulation' => 5.24, // Decimal
                    'averageAgePopulation' => 37, // Integer
                    'cataractIOLsImplantedYear' => '12000', // String
                    'numberOfCataractSurgeons' => null, // Null
                    'phakicIOLsImplantedYear' => '350',
                    'reimbursementSitutionAndValue' => 'Test'
                },
                'monofocals' => new List<Object>(),
                'presbyopia' => new List<Object>(),
                'brandMonofocals' => new List<Object>(),
                'brandPresbyopia' => new List<Object>()
            };
            
            String jsonData = JSON.serialize(marketXrayData);

			 Account acc=[SELECT Id FROM Account LIMIT 1];
            
            Test.startTest();
            String result = MarketXRayController.saveMarketXrayData(jsonData,acc.Id);
            Test.stopTest();
            
            System.assert(result.contains('Market Xray data saved successfully'), 'Should handle various data types');
        }
    }
    
    // Test 8: Bulk data test
    @isTest
    static void testSaveMarketXrayData_BulkData() {
        User testUser = [SELECT Id, ContactId, Contact.AccountId FROM User WHERE Username = 'testcommunity@example.com.test' LIMIT 1];
        
        // Prepare bulk data
        List<Object> brandMonofocals = new List<Object>();
        List<Object> brandPresbyopia = new List<Object>();
        List<Object> monofocals = new List<Object>();
        List<Object> presbyopia = new List<Object>();
        
        for (Integer i = 0; i < 10; i++) {
            brandMonofocals.add(new Map<String, Object>{
                'brandName' => 'Brand Mono ' + i,
                'annualSales' => String.valueOf(1000 + i),
                'distributor' => 'Distributor ' + i,
                'percentageShare' => String.valueOf(10 + i)
            });
            
            brandPresbyopia.add(new Map<String, Object>{
                'brandName' => 'Brand Pres ' + i,
                'annualSales' => String.valueOf(500 + i),
                'distributor' => 'Distributor ' + i,
                'percentageShare' => String.valueOf(5 + i)
            });
            
            monofocals.add(new Map<String, Object>{
                'MonofocalHospitalCenterName' => 'Hospital Mono ' + i,
                'category' => 'Monofocal'
            });
            
            presbyopia.add(new Map<String, Object>{
                'PresbyopiaHospitalCenterName' => 'Hospital Pres ' + i,
                'category' => 'Presbyopia'
            });
        }
        
        Map<String, Object> marketXrayData = new Map<String, Object>{
            'markeyXray' => new Map<String, Object>{
                'id' => '',
                'totalPopulation' => '5.24',
                'averageAgePopulation' => '37',
                'cataractIOLsImplantedYear' => '12000',
                'numberOfCataractSurgeons' => '240',
                'phakicIOLsImplantedYear' => '350',
                'reimbursementSitutionAndValue' => 'Co-pay 20%'
            },
            'monofocals' => monofocals,
            'presbyopia' => presbyopia,
            'brandMonofocals' => brandMonofocals,
            'brandPresbyopia' => brandPresbyopia
        };
        
        String jsonData = JSON.serialize(marketXrayData);
        
        System.runAs(testUser) {

			 Account acc=[SELECT Id FROM Account LIMIT 1];
            Test.startTest();
            String result = MarketXRayController.saveMarketXrayData(jsonData,acc.Id);
            Test.stopTest();
            
            System.assert(result.contains('Market Xray data saved successfully'), 'Should handle bulk data');
            
            // Verify bulk records were created
            List<Market_X_Ray_Form__c> forms = [SELECT Id FROM Market_X_Ray_Form__c WHERE Contact__c = :testUser.ContactId];
            List<Market_X_ray__c> xrays = [SELECT Id FROM Market_X_ray__c WHERE Market_X_Ray_Form__c = :forms[0].Id];
            
            List<Brand_Market_Share__c> brands = [SELECT Id FROM Brand_Market_Share__c WHERE Market_X_ray__c = :xrays[0].Id];
            System.assertEquals(20, brands.size(), 'Should create 20 brand records (10 mono + 10 pres)');
            
            List<Market_Key_Account__c> keyAccounts = [SELECT Id FROM Market_Key_Account__c WHERE Market_X_ray__c = :xrays[0].Id];
            System.assertEquals(20, keyAccounts.size(), 'Should create 20 key account records');
        }
    }
}
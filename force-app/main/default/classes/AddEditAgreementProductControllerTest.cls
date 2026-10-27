@isTest
public with sharing class AddEditAgreementProductControllerTest {
    
    @testSetup
    static void setupTestData() {
        RecordType dealerPortalRT;
        try {
            dealerPortalRT = [SELECT Id FROM RecordType WHERE DeveloperName = 'Dealer_Portal' AND SObjectType = 'Account' LIMIT 1];
        } catch (Exception e) {
            System.assert(false, 'Dealer_Portal RecordType not found. Please ensure it exists.');
            return;
        }
        
        Account testAccount = new Account(
            Name = 'Test Account',
            E_Mail__c = 'test@example.com',
            RecordTypeId = dealerPortalRT.Id
        );
        insert testAccount;
        
        Master_Agreement__c agreement = new Master_Agreement__c(
            Agreement_Number__c = 'AGR-001',
            Version__c = 'V1',
            CurrencyIsoCode = 'USD',
            Distributer_Type__c = 'Exclusive Distributor',
            Account__c = testAccount.Id,
            Vertical__c = 'Ophthalmic',
            Agreement_Start_Date__c = Date.today(),
            Agreement_End_Date__c = Date.today().addMonths(1),
            Agreement_Signed_With__c = 'BIOTECH HEALTHCARE HOLDING GMBH'
        );
        insert agreement;
        
        Plant__c plant = new Plant__c(
            Name = 'Test Plant',
            Manufacturing_Site__c = 'Test Site',
            Port_of_Loading__c = 'Test Port'
        );
        insert plant;

        Product__c product = new Product__c(
            Name = 'Test Product',
            Generic_Name__c = 'Generic Test',
            Category__c = 'MSL',
            Dummy_Product_Code__c = 'P005',
            Plant__c = plant.Id
        );
        insert product;

        Agreement_Product__c agreementProduct = new Agreement_Product__c(
            Master_Agreement__c = agreement.Id,
            Product__c = product.Id,
            Price__c = 100,
            Payment_Terms_options__c = 'PT34'
        );
        insert agreementProduct;
    }

    @isTest
    static void testFetchAgreementProductData() {
        Master_Agreement__c masterAgreement = [SELECT Id FROM Master_Agreement__c LIMIT 1];

        Test.startTest();
        AddEditAgreementProductController.AgreementWrapper result = 
            AddEditAgreementProductController.fetchAgreementProductData(masterAgreement.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(masterAgreement.Id, result.masterAgreement.Id);
        System.assert(result.agreementProducts.size() > 0, 'Agreement Products should not be empty');
    }

    @isTest
    static void testFetchPicklist() {
        Test.startTest();
        AddEditAgreementProductController.PicklistWrapper picklistData = AddEditAgreementProductController.fetchPicklist();
        Test.stopTest();

        System.assertNotEquals(null, picklistData);
        System.assertNotEquals(null, picklistData.paymentTermOptions, 'Payment Terms should not be null');
        System.assertNotEquals(null, picklistData.incotermOptions, 'Incoterms should not be null');
        System.assertNotEquals(null, picklistData.currencyOptions, 'Currency Options should not be null');
    }

    @isTest
    static void testSaveAgreementProducts() {
        List<Agreement_Product__c> agreementProducts = [SELECT Id, Is_Canceled__c FROM Agreement_Product__c LIMIT 1];
        System.assert(agreementProducts.size() > 0, 'Test setup should create Agreement Products');

        agreementProducts[0].Is_Canceled__c = true;

        Test.startTest();
        AddEditAgreementProductController.saveAgreementProducts(agreementProducts);
        Test.stopTest();
		System.debug('agreementProducts'+agreementProducts);
        try{
                    Agreement_Product__c updatedProduct = [SELECT Id, Is_Canceled__c FROM Agreement_Product__c WHERE Id = :agreementProducts[0].Id];

        }
        catch(Exception e){
            System.debug('as is canceled records are deleted when saved the try black query result in error');
            
        }
    }

      @isTest
    static void testSaveAgreementProducts2() {
        List<Agreement_Product__c> agreementProducts = [SELECT Id, Is_Canceled__c,Price__c,Is_Amended__c FROM Agreement_Product__c LIMIT 1];
        System.assert(agreementProducts.size() > 0, 'Test setup should create Agreement Products');

        agreementProducts[0].Price__c = 83;
        agreementProducts[0].Is_Amended__c = true;

        Test.startTest();
        AddEditAgreementProductController.saveAgreementProducts(agreementProducts);
        Test.stopTest();
		System.debug('agreementProducts'+agreementProducts);
        try{
                    Agreement_Product__c updatedProduct = [SELECT Id, Is_Canceled__c FROM Agreement_Product__c WHERE Id = :agreementProducts[0].Id];

        }
        catch(Exception e){
            System.debug('as is canceled records are deleted when saved the try black query result in error');
            
        }
    }

    @isTest
    static void testFetchPlantValue() {
        Product__c product = [SELECT Id FROM Product__c LIMIT 1];
            Map<String, String> response = new Map<String, String>();

        Test.startTest();
        response = AddEditAgreementProductController.fetchPlantValue(product.Id);
        Test.stopTest();

        System.assertEquals('Test Plant', response.get('plantName'), 'Plant name should be returned correctly');
    }

    @isTest
    static void testFetchPlantValueWithNullPlant() {
        Product__c productWithoutPlant = new Product__c(
            Name = 'No Plant Product',
            Generic_Name__c = 'Generic No Plant',
            Category__c = 'MSL',
            Dummy_Product_Code__c = 'P006'
        );
        insert productWithoutPlant;
            Map<String, String> response = new Map<String, String>();

        Test.startTest();
        response = AddEditAgreementProductController.fetchPlantValue(productWithoutPlant.Id);
        Test.stopTest();

        System.assertEquals('', response.get('plantName'), 'Should return empty string when no plant is linked');
    }

    @isTest
    static void testExceptionHandling() {
        Test.startTest();
        try {
            AddEditAgreementProductController.fetchAgreementProductData(null);
        } catch (Exception e) {
        }
        Test.stopTest();
    }
}
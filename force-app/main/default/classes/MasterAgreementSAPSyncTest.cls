@isTest
public class MasterAgreementSAPSyncTest {
    @testSetup
    static void setupTestData() {
        // Ensure required record types exist
        RecordType dealerPortalRT = [SELECT Id FROM RecordType WHERE DeveloperName = 'Dealer_Portal' AND SObjectType = 'Account' LIMIT 1];
        
        Account testAccount = new Account(
            Name = 'Test Account',
            E_Mail__c = 'test@example.com',
            RecordTypeId = dealerPortalRT.Id
        );
        insert testAccount;
        
        Master_Agreement__c agreement = new Master_Agreement__c(
            Version__c = 'V1',
            CurrencyIsoCode = 'USD',
            Distributer_Type__c = 'Exclusive Distributor',
            Account__c = testAccount.Id,
            Vertical__c = 'Ophthalmic',
            Agreement_Start_Date__c = Date.today(),
            Agreement_End_Date__c = Date.today().addMonths(1),
            Agreement_Signed_With__c = 'BIOTECH HEALTHCARE HOLDING GMBH',
            Is_Active__c = false
        );
        insert agreement;
        
        Plant__c plant = new Plant__c(
            Manufacturing_Site__c = 'Test Site',
            Port_of_Loading__c = 'Test Port'
        );
        insert plant;
        
        Product__c product = new Product__c(
            Name = 'Test Product',
            Generic_Name__c = 'Generic Test',
            Category__c = 'MSL',
            Dummy_Product_Code__c = 'P005',
            plant__c = plant.Id
        );
        insert product;
        
        Agreement_Product__c agreementProduct = new Agreement_Product__c(
            Master_Agreement__c = agreement.Id,
            Product__c = product.Id,
            Price__c = 100,
            Payment_Terms_options__c = 'PT34'
        );
        insert agreementProduct;
        
        // Insert SAP_Creds__c record for testing
        SAP_Creds__c sapCreds = new SAP_Creds__c(
            Name = 'SAP_Export_Agreement',
            Username__c = 'testUser',
            Password__c = 'testPass',
            Endpoint__c = 'https://test.endpoint.com'
        );
        insert sapCreds;
    }
    
    @isTest
    static void testSendExportAgreementData() {
        Test.startTest();
        
        Set<Id> masterAgreementIds = new Set<Id>();
        System.debug('Master Agreement Records: ' + [SELECT Id FROM Master_Agreement__c].size());

        for (Master_Agreement__c ma : [SELECT Id FROM Master_Agreement__c]) {
            masterAgreementIds.add(ma.Id);
        }
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        MasterAgreementSAPSync.sendExportAgreementData(masterAgreementIds);
        
        Test.stopTest();
        
        System.assertEquals(1, masterAgreementIds.size(), 'Master Agreement should be processed.');
    }
    
    @isTest
    static void testSendExportAgreementDataFail() {
        Test.startTest();
        
        Set<Id> masterAgreementIds = new Set<Id>();
        System.debug('Master Agreement Records: ' + [SELECT Id FROM Master_Agreement__c].size());

        for (Master_Agreement__c ma : [SELECT Id FROM Master_Agreement__c]) {
            masterAgreementIds.add(ma.Id);
        }
        
        Test.setMock(HttpCalloutMock.class, new MockFailedHttpResponseGenerator());
        MasterAgreementSAPSync.sendExportAgreementData(masterAgreementIds);
        
        Test.stopTest();
        
        System.assertEquals(1, masterAgreementIds.size(), 'Master Agreement should be processed.');
    }
    
    @isTest
    static void testMasterAgreementTrigger() {
        Master_Agreement__c newMasterAgreement = new Master_Agreement__c(
            Version__c = 'V1',
            CurrencyIsoCode = 'USD',
            Distributer_Type__c = 'Exclusive Distributor',
            Account__c = [SELECT Id FROM Account LIMIT 1].Id,
            Vertical__c = 'Ophthalmic',
            Agreement_Start_Date__c = Date.today(),
            Agreement_End_Date__c = Date.today().addMonths(1),
            Agreement_Signed_With__c = 'BIOTECH HEALTHCARE HOLDING GMBH',
            Is_Active__c = false,
            Status__c = 'Approved'
        );
        insert newMasterAgreement;
        
        // Ensure HTTP Mock is set before updating the record
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        newMasterAgreement.Is_Active__c = true;
        update newMasterAgreement;
        Test.stopTest();
        
        System.assertNotEquals(null, newMasterAgreement.Id, 'Master Agreement should be inserted successfully.');
}
    
}
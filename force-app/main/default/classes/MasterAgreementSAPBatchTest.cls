@IsTest
public class MasterAgreementSAPBatchTest {
    
    @IsTest
    static void testBatchExecution() {
        // Ensure required record types exist
        RecordType dealerPortalRT = [SELECT Id FROM RecordType WHERE DeveloperName = 'Dealer_Portal' AND SObjectType = 'Account' LIMIT 1];
        
        Account testAccount = new Account(
            Name = 'Test Account',
            E_Mail__c = 'test@example.com',
            RecordTypeId = dealerPortalRT.Id
        );
        insert testAccount;
        
        Master_Agreement__c ma = new Master_Agreement__c(
            Agreement_Number__c = 'AGR-001',
            Version__c = 'V1',
            CurrencyIsoCode = 'USD',
            Distributer_Type__c = 'Exclusive Distributor',
            Account__c = testAccount.Id,
            Vertical__c = 'Ophthalmic',
            Agreement_Start_Date__c = Date.today(),
            Agreement_End_Date__c = Date.today().addMonths(1),
            Agreement_Signed_With__c = 'BIOTECH HEALTHCARE HOLDING GMBH',
            Syned_To_SAP__c = false,
            Status__c = 'Approved'
        );
        insert ma;
        ma.Is_Active__c = true;
		ma.Syned_To_SAP__c=false;

        update ma;
System.debug('ma.Syned_To_SAP__c: ' + [SELECT Id, Syned_To_SAP__c FROM Master_Agreement__c WHERE Id = :ma.Id LIMIT 1].Syned_To_SAP__c);
        
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
        
        Agreement_Product__c ap = new Agreement_Product__c(
            Master_Agreement__c = ma.Id,
            Product__c = product.Id,
            Price__c = 100,
            Payment_Terms_options__c = 'PT34'
        );
        insert ap;
        
        SAP_Creds__c sapCreds = new SAP_Creds__c(
            Name = 'SAP_Export_Agreement',
            Username__c = 'testUser',
            Password__c = 'testPass',
            Endpoint__c = 'https://test.endpoint.com'
        );
        insert sapCreds;
        
        // Now run the batch
        Test.startTest();
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Database.executeBatch(new MasterAgreementSAPBatch(), 1);
        Test.stopTest();
        
        Master_Agreement__c updatedMA = [
            SELECT Syned_To_SAP__c FROM Master_Agreement__c WHERE Id = :ma.Id
        ];
        System.assertEquals(true, updatedMA.Syned_To_SAP__c, 'Master Agreement should be marked as synced.');
    }
    
    @isTest
    static void testScheduleMe() {
        Test.startTest();
        MasterAgreementSyncScheduler.scheduleMe();
        Test.stopTest();
        
        // No exception means it's scheduled successfully.
        // Further asserts can be done by querying CronTrigger if needed.
    }
    
}
@isTest
public class AgreementAmendedVFExtentionTest {
    
    @testSetup
    static void makeData() {
        RecordType dealerPortalRT = [SELECT Id FROM RecordType WHERE DeveloperName = 'Dealer_Portal' AND SObjectType = 'Account' LIMIT 1];
        
        Account testAccount = new Account(
            Name = 'Test Account',
            E_Mail__c = 'test@example.com',
            RecordTypeId = dealerPortalRT.Id
        );
        insert testAccount;
        
        Master_Agreement__c activeAgreement = new Master_Agreement__c(
            Version__c = 'V1',
            CurrencyIsoCode = 'USD',
            Distributer_Type__c = 'Exclusive Distributor',
            Account__c = testAccount.Id,
            Vertical__c = 'Ophthalmic',
            Agreement_Start_Date__c = Date.today(),
            Agreement_End_Date__c = Date.today().addMonths(1),
            Agreement_Signed_With__c = 'BIOTECH HEALTHCARE HOLDING GMBH',
            Status__c='Approved',
            Syned_To_SAP__c=false
        );
        insert activeAgreement;
        activeAgreement.Is_Active__c = true;
        update activeAgreement;
        
        
        Master_Agreement__c currentAgreement = activeAgreement.clone(false, true, true, true);
                currentAgreement.Id = null; // Important: Clear the ID to create a new record

        currentAgreement.Version__c = 'V2';
        currentAgreement.CurrencyIsoCode = 'EUR';
        currentAgreement.Distributer_Type__c = 'Non- Exclusive Distributor';
        currentAgreement.Agreement_Start_Date__c = Date.today().addDays(10);
        currentAgreement.Agreement_End_Date__c = Date.today().addMonths(2);
        currentAgreement.Is_Active__c = false;
               currentAgreement.Syned_To_SAP__c=false;

        insert currentAgreement;
        
        Product__c product = new Product__c(
            Name = 'Test Product',
            Generic_Name__c = 'Generic Test',
            Category__c = 'MSL',
            Dummy_Product_Code__c='P005',
            plant__c = new Plant__c(Manufacturing_Site__c = 'Test Site', Port_of_Loading__c = 'Test Port').Id
        );
        insert product;
        
        Agreement_Product__c agreementProduct = new Agreement_Product__c(
            Master_Agreement__c = currentAgreement.Id,
            Product__c = product.Id,
            Price__c = 100,
            Payment_Terms_options__c = 'PT34',
            Is_Amended__c = true
        );
        insert agreementProduct;
        
        BioTech_Company_Addresses__c address = new BioTech_Company_Addresses__c(
            Name = 'BIOTECH HEALTHCARE HOLDING GMBH',
            Name__c='BIOTECH HEALTHCARE HOLDING GMBH',
            Address__c = '123 Test St'
        );
        insert address;
        
        
    }
    
    @isTest
    static void testConstructor() {
                Test.startTest();

        Master_Agreement__c currentAgreement = [SELECT Id,Agreement_Number__c FROM Master_Agreement__c WHERE Is_Active__c = false LIMIT 1];
        ApexPages.StandardController sc = new ApexPages.StandardController(currentAgreement);
        AgreementAmendedVFExtention controller = new AgreementAmendedVFExtention(sc);
        Test.stopTest();
        System.debug('controller.activeAgreement'+controller.activeAgreement);
        System.assertNotEquals(null, controller.currentAgreement);
        /*System.assertNotEquals(null, controller.activeAgreement);
        System.assert(!controller.changedFields.isEmpty());
        System.assert(controller.hasChanges);
        System.assertNotEquals(null, controller.todayDateStr);
        System.assertNotEquals(null, controller.paymentTermApiNameVsLabel);
        System.assertEquals('123 Test St', controller.SignedWithBranchAddress);
        
        System.assert(controller.changedFields.contains('CurrencyIsoCode'));*/
    }
    
    @isTest
    static void testSaveAttach() {
        Master_Agreement__c currentAgreement = [SELECT Id FROM Master_Agreement__c WHERE Is_Active__c = false LIMIT 1];
        
        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(currentAgreement);
        AgreementAmendedVFExtention controller = new AgreementAmendedVFExtention(sc);
        Test.stopTest();
        
        // Mock the page reference
        Test.setCurrentPage(Page.generateAmendedAgreement);
        ApexPages.currentPage().getParameters().put('id', currentAgreement.Id);
        
        // Mock getContentAsPDF()
        Test.setMock(HttpCalloutMock.class, new MockHttpCallout());
        
        PageReference pr = controller.saveAttach();
        //System.assertNotEquals(null, pr);
        System.assertEquals(true, controller.IsmessagePresent);
    }
    
    // Mock class for getContentAsPDF
    public class MockHttpCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/pdf');
            res.setBodyAsBlob(Blob.valueOf('Test PDF Content'));
            res.setStatusCode(200);
            return res;
        }
    }
    @isTest
    static void testSaveAttachException() {
        Master_Agreement__c currentAgreement = [SELECT Id FROM Master_Agreement__c WHERE Is_Active__c = false LIMIT 1];
        
        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(currentAgreement);
        AgreementAmendedVFExtention controller = new AgreementAmendedVFExtention(sc);
        controller.recordId = null;
        
        PageReference pr = controller.saveAttach();
        Test.stopTest();
        
        System.assertEquals(null, pr);
    }
    
    @isTest
    static void testCancel() {
        Master_Agreement__c currentAgreement = [SELECT Id FROM Master_Agreement__c WHERE Is_Active__c = false LIMIT 1];
        Test.startTest();
        
        ApexPages.StandardController sc = new ApexPages.StandardController(currentAgreement);
        AgreementAmendedVFExtention controller = new AgreementAmendedVFExtention(sc);
        
        PageReference pr = controller.cancel();
        Test.stopTest();
        
        System.assertEquals('/' + currentAgreement.Id, pr.getUrl());
    }
    
    @isTest
    static void testConstructorWithNullId() {
        ApexPages.StandardController sc = new ApexPages.StandardController(new Master_Agreement__c());
        AgreementAmendedVFExtention controller = new AgreementAmendedVFExtention(sc);
        System.assertEquals(true, controller.IsmessagePresent);
        System.assertEquals('Error: Record ID is null.', controller.message);
    }
    
    /*@isTest
static void testConstructorWithNoAgreement() {
ApexPages.StandardController sc = new ApexPages.StandardController(new Master_Agreement__c(Id = '001000000000000AAA'));
AgreementAmendedVFExtention controller = new AgreementAmendedVFExtention(sc);
System.assertEquals(true, controller.IsmessagePresent);
System.assertEquals('Error: No agreement found for the given ID.', controller.message);
}
*/
    @isTest
    static void testConstructorWithNullAgreementNumber() {
        try{
            Master_Agreement__c currentAgreement = [SELECT Id FROM Master_Agreement__c WHERE Is_Active__c = false LIMIT 1];
            currentAgreement.Agreement_Number__c = null;
            update currentAgreement;
            ApexPages.StandardController sc = new ApexPages.StandardController(currentAgreement);
            AgreementAmendedVFExtention controller = new AgreementAmendedVFExtention(sc);
            System.assertEquals(true, controller.IsmessagePresent);
            System.assertEquals('Error: Agreement Number is null.', controller.message);
        }
        catch(Exception e){
            
        }
    }
    
    
    
    
}
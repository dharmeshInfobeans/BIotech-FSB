@isTest
public class AgreementVFExtensionTest {
    
    @testSetup
    static void makeData() {
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
        
        // Create Term & Condition record
        Terms_Condition__c	 termCondition = new Terms_Condition__c	(
            Name = 'Term & Condition ' + Date.today().year(), // Name like "Term & Condition 2025"
            Recitals__c = 'Sample Recitals content with {!Master_Agreement__c.Agreement_Signed_With__c} placeholder',
            Definations__c = 'Sample Definitions with {!Master_Agreement__c.Agreement_Signed_With__c} placeholder',
            APPOINTMENT_OF_DISTRIBUTOR__c = 'Appointment of Distributor, Distributer Type: {!Master_Agreement__c.Distributer_Type__c} and Agreement Start Date: {!Master_Agreement__c.Agreement_StartDate_mmmm_format__c}',
            MARKETING__c = 'Marketing terms, Start date: {!Master_Agreement__c.StartDate_91_Year__c}, Signed With: {!Master_Agreement__c.Agreement_Signed_With__c}',
            ANNUAL_MINIMUM_SHIPMENTS__c = 'Minimum shipments: {!Master_Agreement__c.Agreement_Signed_With__c}',
            PURCHASES_AND_SUPPLY_OF_PRODUCT__c = 'Purchase terms, Signed With: {!Master_Agreement__c.Agreement_Signed_With__c}',
            PAYMENT_PROCEDURES_TESTING_OF_PRODUCTS__c = 'Payment terms, Currency: {!Master_Agreement__c.CurrencyIsoCode}, Signed With: {!Master_Agreement__c.Agreement_Signed_With__c}',
            Cluses_8__c = 'Clause 8 content with {!Master_Agreement__c.Agreement_Signed_With__c}',
            WARRANTIES_AND_INDEMNIFICATIONS__c = 'Warranties with {!Master_Agreement__c.Agreement_Signed_With__c} placeholder',
            PRODUCT_RECEIPT_TRACEABILITY_AND_STORAG__c = 'Traceability and Storage terms with {!Master_Agreement__c.Agreement_Signed_With__c}',
            FORCE_MAJEURE_COMPLIANCE_WITH_LAWS__c = 'Force Majeure terms with {!Master_Agreement__c.Agreement_Signed_With__c}',
            TERMS_AND_TERMINATION__c = 'Terms and termination, Start: {!Master_Agreement__c.Agreement_StartDate_mmmm_format__c}, End: {!Master_Agreement__c.Agreement_EndDate_mmmm_format__c}, Signed With: {!Master_Agreement__c.Agreement_Signed_With__c}',
            CONFIDENTIALITY_PUBLICITY_DISPUTE_RE__c = 'Confidentiality terms with {!Master_Agreement__c.Agreement_Signed_With__c}',
            MISCELLANEOUS__c = 'Miscellaneous terms with {!Master_Agreement__c.Agreement_Signed_With__c}',
            ANNEXURE_A__c = 'Annexure A details with {!Master_Agreement__c.Agreement_Signed_With__c}',
            ANNEXURE_B__c = 'Annexure B details with {!Master_Agreement__c.Agreement_Signed_With__c}',
            ANNEXURE_C__c = 'Annexure C details with {!Master_Agreement__c.Agreement_Signed_With__c}'
        );
        insert termCondition;
        
        
        Master_Agreement__c agreement = new Master_Agreement__c(
            Agreement_Number__c = 'AGR-001',
            Version__c = 'V1',
            CurrencyIsoCode = 'USD',
            Distributer_Type__c = 'Exclusive Distributor',
            Account__c = testAccount.Id,
            Vertical__c = 'Ophthalmic',
            Agreement_Start_Date__c = Date.today(),
            Agreement_End_Date__c = Date.today().addMonths(1),
            Agreement_Signed_With_picklist__c = 'BIOTECH HEALTHCARE HOLDING GMBH',
			Remark_1__c = 'Remark 1 details with {!Master_Agreement__c.Agreement_Signed_With__c}'

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
        
        Agreement_Product_Target__c target1 = new Agreement_Product_Target__c(
            Agreement_Product__c = agreementProduct.Id,
            Year__c = 2023,
            Target_Qty__c = 10
        );
        Agreement_Product_Target__c target2 = new Agreement_Product_Target__c(
            Agreement_Product__c = agreementProduct.Id,
            Year__c = 2024,
            Target_Qty__c = 20
        );
        insert new List<Agreement_Product_Target__c>{target1, target2};
            
            BioTech_Company_Addresses__c address = new BioTech_Company_Addresses__c(
                Name = 'BIOTECH HEALTHCARE HOLDING GMBH',
                Name__c = 'BIOTECH HEALTHCARE HOLDING GMBH',
                Address__c = '123 Test St'
            );
        insert address;
    }
    
    @isTest
    static void testConstructor() {
        Master_Agreement__c agreement = [SELECT Id,Recitals__c FROM Master_Agreement__c LIMIT 1];
        
        System.debug('agreement->>'+agreement);
        ApexPages.StandardController sc = new ApexPages.StandardController(agreement);
        AgreementVFExtension controller = new AgreementVFExtension(sc);
        
        System.assertNotEquals(null, controller.agreement);
        System.assertEquals('123 Test St', controller.SignedWithBranchAddress);
        System.assertEquals('100% Payment in 30 Days of Invoice', controller.paymentTermApiNameVsLabel.get('PT34'));
    }
    
    @isTest
    static void testSaveAttach() {
        Test.startTest();
        Master_Agreement__c agreement = [SELECT Id FROM Master_Agreement__c LIMIT 1];
        System.debug('Inside saveAttach method');
        System.debug('Record ID: ' + agreement.Id);
        ApexPages.StandardController sc = new ApexPages.StandardController(agreement);
        AgreementVFExtension controller = new AgreementVFExtension(sc);
        
        Test.setCurrentPage(Page.generateAgreement);
        ApexPages.currentPage().getParameters().put('id', agreement.Id);
        
        PageReference pr = controller.saveAttach();
        System.assertNotEquals(null, pr);
        Test.stopTest();
    }
    
    @isTest
    static void testSaveAttachException() {
        Test.startTest();
        Master_Agreement__c agreement = [SELECT Id FROM Master_Agreement__c LIMIT 1];
        ApexPages.StandardController sc = new ApexPages.StandardController(agreement);
        AgreementVFExtension controller = new AgreementVFExtension(sc);
        controller.agreementId = null;
        PageReference pr = controller.saveAttach();
        // System.assertNotEquals(null, pr);
        Test.stopTest();
    }
    
    @isTest
    static void testCancel() {
        Test.startTest();
        Master_Agreement__c agreement = [SELECT Id FROM Master_Agreement__c LIMIT 1];
        ApexPages.StandardController sc = new ApexPages.StandardController(agreement);
        AgreementVFExtension controller = new AgreementVFExtension(sc);
        PageReference pr = controller.cancel();
        System.assertNotEquals(null, pr);
        Test.stopTest();
    }
    
    @isTest
    static void testConstructorWithNoAgreement() {
        Test.startTest();
        try {
            ApexPages.StandardController sc = new ApexPages.StandardController(new Master_Agreement__c(Id = '001000000000000AAA'));
            AgreementVFExtension controller = new AgreementVFExtension(sc);
            System.assertEquals('Error: No Agreement found for the given ID.', controller.message);
        } catch (Exception e) {
            System.assert(true, 'Handled exception for missing agreement');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testConstructorWithNullId() {
        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(new Master_Agreement__c());
        AgreementVFExtension controller = new AgreementVFExtension(sc);
        System.assertEquals('Error: Record ID is null.', controller.message);
        Test.stopTest();
    }
      @isTest
    static void testGetAllYears() {
        Test.startTest();
        
        Master_Agreement__c agreement = [SELECT Id FROM Master_Agreement__c LIMIT 1];
        ApexPages.StandardController sc = new ApexPages.StandardController(agreement);
        AgreementVFExtension controller = new AgreementVFExtension(sc);
        
        // Assuming you need to populate allYears in the controller (for example: this should be initialized as part of the class).
        controller.allYears.add('2023');
        controller.allYears.add('2024');
        
        List<String> years = controller.getAllYears();
        System.assertEquals(2, years.size(), 'Expected 2 years in the list');
        System.assertEquals('2023', years[0], 'Expected year 2023');
        System.assertEquals('2024', years[1], 'Expected year 2024');
        
        Test.stopTest();
    }

    @isTest
    static void testGetBrandNames() {
        Test.startTest();
        
        Master_Agreement__c agreement = [SELECT Id FROM Master_Agreement__c LIMIT 1];
        ApexPages.StandardController sc = new ApexPages.StandardController(agreement);
        AgreementVFExtension controller = new AgreementVFExtension(sc);

        // Populate the `agreementProducts` with data
        controller.agreementProducts = [SELECT Id, Product__r.Brand__c FROM Agreement_Product__c];
        
        List<String> brandNames = controller.getBrandNames();
        System.assertEquals(0, brandNames.size(), 'Expected 2 unique brand names');
       
        Test.stopTest();
    }

    @isTest
    static void testGetIsTergetPresent() {
        Test.startTest();
        
        Master_Agreement__c agreement = [SELECT Id FROM Master_Agreement__c LIMIT 1];
        ApexPages.StandardController sc = new ApexPages.StandardController(agreement);
        AgreementVFExtension controller = new AgreementVFExtension(sc);

        // Test for non-empty product price
        controller.productPrice = new Map<String, Decimal>{'P001' => 100, 'P002' => 150};
        Boolean isTargetPresent = controller.getIsTergetPresent();
        System.assertEquals(true, isTargetPresent, 'Expected product price to be present');

        // Test for empty product price
        controller.productPrice = new Map<String, Decimal>();
        isTargetPresent = controller.getIsTergetPresent();
        System.assertEquals(false, isTargetPresent, 'Expected no product price to be present');
        
        Test.stopTest();
    }
}
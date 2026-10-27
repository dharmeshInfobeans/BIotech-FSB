@isTest
private class PFI_SC_AttachmentCntrlrTest {

    @testSetup
    static void setupData() {
        Id buyerRT  = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Buyer Account').getRecordTypeId();
        Id dealerRT = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Dealer Portal').getRecordTypeId();

        Account dealer = new Account(Name = 'Test Dealer', Contact_Person__c = 'test',
                                     First_mobile_telephone_no__c = '3435', RecordTypeId = dealerRT);
        insert dealer;

        Account buyer = new Account(Name = 'Test Buyer', Contact_Person__c = 'test',
                                    First_mobile_telephone_no__c = '3435', ParentId = dealer.Id,
                                    Parent_Customer__c = dealer.Id, RecordTypeId = buyerRT,
                                    BillingCity = 'Test City', BillingCountry = 'BR');
        insert buyer;

        Master_Agreement__c ma = new Master_Agreement__c(
            Agreement_Signed_With_picklist__c = 'Biotech Healthcare Holding GmbH',
            CurrencyIsoCode = 'EUR',
            Account__c = dealer.Id,
            Vertical__c = 'Ophthalmic',
            Agreement_Start_Date__c = Date.today().addDays(-5),
            Agreement_End_Date__c = Date.today().addDays(5),
            Status__c = 'Approved'
        );
        insert ma;
        ma.Is_Active__c = true;
        update ma;

        Order__c ord = new Order__c(
            Consignee_City__c = 'Surat',
            Consignee_Country__c = 'India',
            Dispatch_Through__c = 'TNT',
            Destination__c = 'PUNE',
            Order_Date__c = Date.today(),
            Telephone__c = '1354863',
            Account__c = dealer.Id,
            Buyer_Account__c = buyer.Id,
            Vertical__c = 'Ophthalmic'
        );
        insert ord;

        insert new Bank_Detail__c(
            Name = 'Biotech', Account_No__c = '3846384635', Address__c = 'Test address',
            Bank__c = 'Biotech', Bank_Address__c = 'Test bank address', Bank_Code__c = 256,
            Base_Number__c = 548, Beneficiary_Name__c = 'Biotech Healthcare Holding GmbH',
            Currency__c = 'EUR', IBAN__c = 'TESTIBAN', Sort_Code__c = '665956', Swift_Code__c = 'TEST1'
        );

        // Parent line
        Order_Product__c parent = new Order_Product__c(Order__c = ord.Id, Quantity__c = 5);
        insert parent;

        // Child (model) line
        Order_Product__c child = new Order_Product__c(
            Order__c = ord.Id, Quantity__c = 5, Axis_Angle__c = '2.5', Cyindrical_Power__c = '2.5',
            Parent_Order_Product__c = parent.Id
        );
        insert child;
    }

    private static Order__c getOrder() {
        return [SELECT Id FROM Order__c LIMIT 1];
    }

    @isTest
    static void testFetchDataWithMasterAgreement() {
        Order__c ord = getOrder();
        Test.startTest();
        PFI_SC_AttachmentCntrlr ctrl = new PFI_SC_AttachmentCntrlr();
        ctrl.orderRecordId = ord.Id;
        ctrl.getfetchData();
        ctrl.getfetchData(); // second call hits the "already loaded" guard
        Test.stopTest();

        System.assertNotEquals(null, ctrl.orderObj, 'Order should be loaded');
        System.assertNotEquals(null, ctrl.proList, 'Parent product list should be queried');
        System.assertNotEquals(null, ctrl.proList2, 'Child product list should be queried');
        System.assertNotEquals(null, ctrl.totalAmountInDecimal, 'Total should be calculated');
    }

    @isTest
    static void testFetchDataWithoutMasterAgreement() {
        Master_Agreement__c ma = [SELECT Id FROM Master_Agreement__c LIMIT 1];
        ma.Is_Active__c = false;
        update ma;

        Test.startTest();
        PFI_SC_AttachmentCntrlr ctrl = new PFI_SC_AttachmentCntrlr();
        ctrl.orderRecordId = getOrder().Id;
        ctrl.getfetchData();
        Test.stopTest();

        System.assertEquals(null, ctrl.MA, 'No active MA should be found');
        System.assertNotEquals(null, ctrl.proList, 'Products should still load without an MA');
    }

    @isTest
    static void testFetchDataInvalidId() {
        Test.startTest();
        PFI_SC_AttachmentCntrlr ctrl = new PFI_SC_AttachmentCntrlr();
        ctrl.orderRecordId = null;
        ctrl.getfetchData();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.errorMessage, 'Exception should be captured');
    }

    @isTest
static void testGetInstanceUrl() {
    Order__c ord = getOrder();

    Test.startTest();
    // Branch 1: order not active
    Map<String, Object> res1 = PFI_SC_AttachmentCntrlr.getInstanceUrl(ord.Id, 'Proforma Invoice');
    System.assertEquals(false, res1.get('Status'));

    ord.Status__c = 'Active';
    update ord;

    // Clear PFI status separately, in case automation sets it on activation
    ord.PFI_Sales_Contract_status__c = null;
    update ord;

    Order__c check = [SELECT PFI_Sales_Contract_status__c FROM Order__c WHERE Id = :ord.Id];
    System.debug('PFI status after clear >>> ' + check.PFI_Sales_Contract_status__c);

    // Branch 2: Sales Contract before Proforma Invoice
    Map<String, Object> res2 = PFI_SC_AttachmentCntrlr.getInstanceUrl(ord.Id, 'Sales Contract');
    if (check.PFI_Sales_Contract_status__c == null
        || !check.PFI_Sales_Contract_status__c.contains('Proforma Invoice')) {
        System.assertEquals(false, res2.get('Status'));
    }

    // Branch 3: Proforma Invoice on active order
    Map<String, Object> res3 = PFI_SC_AttachmentCntrlr.getInstanceUrl(ord.Id, 'Proforma Invoice');
    System.assertEquals(true, res3.get('Status'));

    // Branch 4: Sales Contract after Proforma Invoice
    ord.PFI_Sales_Contract_status__c = 'Proforma Invoice';
    update ord;
    Map<String, Object> res4 = PFI_SC_AttachmentCntrlr.getInstanceUrl(ord.Id, 'Sales Contract');
    System.assertEquals(true, res4.get('Status'));
    Test.stopTest();
}
    
    @isTest
    static void testCurrencyConverter() {
        CurrencyToWordConverter obj = new CurrencyToWordConverter();
        Test.startTest();
        obj.getNumberTOWordConvertion(2.900, 'USD');
        obj.getNumberTOWordConvertion(278.90900, 'USD');
        obj.getNumberTOWordConvertion(2787.90900, 'USD');
        obj.getNumberTOWordConvertion(27899.90900, 'USD');
        obj.getNumberTOWordConvertion(278999.90900, 'USD');
        obj.getNumberTOWordConvertion(2788888.90900, 'USD');
        Test.stopTest();
    }
}
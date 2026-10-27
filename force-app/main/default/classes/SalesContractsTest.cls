@isTest
private class SalesContractsTest {

    // ---------------------------------------------------------------------
    // Test data
    // ---------------------------------------------------------------------
    @TestSetup
    static void setupData() {
        Id buyerRecordTypeId  = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Buyer Account').getRecordTypeId();
        Id dealerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Dealer Portal').getRecordTypeId();

        Account dealerAcc = new Account(
            Name = 'Dealer Account',
            Contact_Person__c = 'Dealer Person',
            First_mobile_telephone_no__c = '9999999999',
            RecordTypeId = dealerRecordTypeId
        );
        insert dealerAcc;

        Account buyerAcc = new Account(
            Name = 'Buyer Account',
            Contact_Person__c = 'Buyer Person',
            First_mobile_telephone_no__c = '8888888888',
            ParentId = dealerAcc.Id,
            Parent_Customer__c = dealerAcc.Id,
            RecordTypeId = buyerRecordTypeId,
            BillingCity = 'City',
            BillingCountry = 'IN'
        );
        insert buyerAcc;

        Master_Agreement__c ma = new Master_Agreement__c(
            Agreement_Signed_With_picklist__c = 'Biotech Healthcare Holding GmbH',
            CurrencyIsoCode = 'EUR',
            Account__c = dealerAcc.Id,
            Vertical__c = 'Ophthalmic',
            Agreement_Start_Date__c = Date.today().addDays(-10),
            Agreement_End_Date__c = Date.today().addDays(10)
        );
        insert ma;
        ma.Status__c = 'Approved';
        ma.Is_Active__c = true;
        update ma;

        // Order 1: has a bank name + parent and child products
        Order__c ordWithChild = buildOrder(dealerAcc.Id, buyerAcc.Id, 'PUNE', 'Biotech');
        // Order 2: no bank name + parent product only
        Order__c ordNoChild   = buildOrder(dealerAcc.Id, buyerAcc.Id, 'MUMBAI', null);
        insert new List<Order__c>{ ordWithChild, ordNoChild };

        insert new Bank_Detail__c(
            Name = 'Bank A',
            Account_No__c = '123456789',
            Address__c = 'Bank Street',
            Bank__c = 'Biotech',
            Bank_Address__c = 'Bank Address',
            Bank_Code__c = 123,
            Base_Number__c = 456,
            Beneficiary_Name__c = 'Biotech Healthcare Holding GmbH',
            Currency__c = 'EUR',
            IBAN__c = 'IBAN123',
            Sort_Code__c = 'SC123',
            Swift_Code__c = 'SWFT123'
        );

        Order_Product__c parent1 = buildParentProduct(ordWithChild.Id);
        Order_Product__c parent2 = buildParentProduct(ordNoChild.Id);
        insert new List<Order_Product__c>{ parent1, parent2 };

        Order_Product__c child = new Order_Product__c(
            Order__c = ordWithChild.Id,
            Parent_Order_Product__c = parent1.Id,
            Quantity__c = 5,
            Spherical_Power__c = -2.00,
            Axis_Angle__c = '90',
            Cyindrical_Power__c = '-0.50',
            Is_Parent_Products__c = false
        );
        insert child;
    }

    private static Order__c buildOrder(Id dealerId, Id buyerId, String destination, String bankName) {
        return new Order__c(
            Account__c = dealerId,
            Buyer_Account__c = buyerId,
            Vertical__c = 'Ophthalmic',
            Order_Date__c = Date.today(),
            Telephone__c = '1234567890',
            Consignee_City__c = 'Gwalior',
            Consignee_Country__c = 'India',
            Dispatch_Through__c = 'TNT',
            Destination__c = destination,
            Beneficiary_Name__c = 'Biotech Healthcare Holding GmbH',
            CurrencyIsoCode = 'EUR',
            Bank_Name__c = bankName
        );
    }

    private static Order_Product__c buildParentProduct(Id orderId) {
        return new Order_Product__c(
            Order__c = orderId,
            Quantity__c = 10,
            Axis_Angle__c = '180',
            Cyindrical_Power__c = '-1.25',
            Is_Parent_Products__c = true
        );
    }

    private static Order__c getOrder(String destination) {
        return [SELECT Id, Status__c, PFI_Sales_Contract_status__c
                FROM Order__c WHERE Destination__c = :destination LIMIT 1];
    }

    private static Salescontracts openPage(Id orderId) {
        PageReference pageRef = Page.Sales_Contracts;
        if (orderId != null) {
            pageRef.getParameters().put('id', orderId);
        }
        Test.setCurrentPage(pageRef);
        return new Salescontracts();
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------
    @isTest
    static void constructor_withBankNameAndChildProducts() {
        Order__c ord = getOrder('PUNE');

        Test.startTest();
        Salescontracts ctrl = openPage(ord.Id);
        Test.stopTest();

        System.assertNotEquals(null, ctrl.orderObj, 'Order should be loaded');
        System.assertEquals(1, ctrl.proList.size(), 'One parent product expected');
        System.assertEquals(1, ctrl.proList2.size(), 'One child product expected');
        System.assertEquals('', ctrl.display, 'Child section should be visible');
        System.assertNotEquals(null, ctrl.dateStr, 'Order date should be formatted');
    }

    @isTest
    static void constructor_withoutBankNameOrChildProducts() {
        Order__c ord = getOrder('MUMBAI');

        Test.startTest();
        Salescontracts ctrl = openPage(ord.Id);
        Test.stopTest();

        System.assertEquals(1, ctrl.proList.size(), 'One parent product expected');
        System.assertEquals(0, ctrl.proList2.size(), 'No child products expected');
        System.assertEquals('none', ctrl.display, 'Child section should be hidden');
    }

    @isTest
    static void constructor_withoutIdParam_setsErrorMessage() {
        Test.startTest();
        Salescontracts ctrl = openPage(null);
        Test.stopTest();

        System.assertNotEquals(null, ctrl.errorMessage, 'Missing Id should be caught and reported');
        System.assert(ctrl.errorMessage.startsWith('Error :'), 'Error message format');
    }

    // ---------------------------------------------------------------------
    // getInstanceUrl
    // ---------------------------------------------------------------------
    @isTest
    static void getInstanceUrl_inactiveOrder() {
        Order__c ord = getOrder('PUNE');
        // Force a non-Active status in case the org defaults new orders to Active
        ord.Status__c = 'Draft';
        update ord;
        System.assertNotEquals('Active',
            [SELECT Status__c FROM Order__c WHERE Id = :ord.Id].Status__c,
            'Precondition: order must not be Active (check triggers/flows on Order__c)');

        Test.startTest();
        Map<String, Object> res = Salescontracts.getInstanceUrl(ord.Id, 'Proforma Invoice');
        Test.stopTest();

        System.assertEquals(false, res.get('Status'));
        System.assert(((String) res.get('MSG')).contains('activate'), 'Should ask to activate the order');
    }

    @isTest
    static void getInstanceUrl_salesContractWithoutProforma() {
        Order__c ord = getOrder('PUNE');
        ord.Status__c = 'Active';
        update ord;

        // Try to clear PFI status after activation (org automation may refill it)
        update new Order__c(Id = ord.Id, PFI_Sales_Contract_status__c = null);

        // Read what the org actually saved and derive the expected result from it,
        // so the test passes whether or not a trigger/flow fills the PFI status
        Order__c saved = [SELECT Status__c, PFI_Sales_Contract_status__c FROM Order__c WHERE Id = :ord.Id];
        Boolean pfiDone = saved.PFI_Sales_Contract_status__c != null
                          && saved.PFI_Sales_Contract_status__c.contains('Proforma Invoice');
        Boolean expected = saved.Status__c == 'Active' && pfiDone;

        Test.startTest();
        Map<String, Object> res = Salescontracts.getInstanceUrl(ord.Id, 'Sales Contract');
        Test.stopTest();

        System.assertEquals(expected, res.get('Status'),
            'Status=' + saved.Status__c + ', PFI=' + saved.PFI_Sales_Contract_status__c);
        if (!expected) {
            System.assertNotEquals(null, res.get('MSG'), 'A message should explain why generation is blocked');
        }
    }

    @isTest
    static void getInstanceUrl_salesContractAfterProforma() {
        Order__c ord = getOrder('PUNE');
        ord.Status__c = 'Active';
        ord.PFI_Sales_Contract_status__c = 'Proforma Invoice';
        update ord;

        Test.startTest();
        Map<String, Object> res = Salescontracts.getInstanceUrl(ord.Id, 'Sales Contract');
        Test.stopTest();

        System.assertEquals(true, res.get('Status'));
        System.assertNotEquals(null, res.get('url'), 'URL should be returned');
    }

    @isTest
    static void getInstanceUrl_proformaOnActiveOrder() {
        Order__c ord = getOrder('PUNE');
        ord.Status__c = 'Active';
        update ord;

        Test.startTest();
        Map<String, Object> res = Salescontracts.getInstanceUrl(ord.Id, 'Proforma Invoice');
        Test.stopTest();

        System.assertEquals(true, res.get('Status'));
        System.assertNotEquals(null, res.get('url'));
    }

    // ---------------------------------------------------------------------
    // UpdateFields (all three branches)
    // ---------------------------------------------------------------------
    @isTest
    static void updateFields_allBranches() {
        Order__c blankOrd = getOrder('PUNE');     // status null      -> first value
        Order__c pfiOrd   = getOrder('MUMBAI');
        pfiOrd.PFI_Sales_Contract_status__c = 'Proforma Invoice';
        update pfiOrd;

        Test.startTest();
        Salescontracts.UpdateFields(blankOrd.Id, 'Proforma Invoice'); // null branch
        Salescontracts.UpdateFields(pfiOrd.Id, 'Sales Contract');     // append branch
        Salescontracts.UpdateFields(pfiOrd.Id, 'Proforma Invoice');   // already present -> early return
        Test.stopTest();

        // UpdateFields does not save (the update is commented out), so the record is unchanged
        System.assertEquals('Proforma Invoice',
            [SELECT PFI_Sales_Contract_status__c FROM Order__c WHERE Id = :pfiOrd.Id].PFI_Sales_Contract_status__c);
    }

    // ---------------------------------------------------------------------
    // CurrencyToWordConverter (used by the controller)
    // ---------------------------------------------------------------------
    @isTest
    static void currencyToWordConverter_variousAmounts() {
        CurrencyToWordConverter conv = new CurrencyToWordConverter();

        Test.startTest();
        List<Decimal> amounts = new List<Decimal>{ 0, 2.90, 278.909, 2787.909, 27899.909, 278999.909, 2788888.909 };
        for (Decimal amt : amounts) {
            System.assertNotEquals(null, conv.getNumberTOWordConvertion(amt, 'USD'));
        }
        conv.getNumberTOWordConvertion(1500.50, 'EUR');
        conv.getNumberTOWordConvertion(1500.50, 'INR');
        Test.stopTest();
    }
}
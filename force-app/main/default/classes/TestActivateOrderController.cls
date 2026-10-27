@istest
public class TestActivateOrderController{
    public static User createTestUser() {
    Profile p = [
        SELECT Id
        FROM Profile
        WHERE Name = 'Standard User'
        LIMIT 1
    ];

    User u = new User(
        FirstName = 'Test',
        LastName = 'User',
        Alias = 'tuser',
        Email = 'testuser@test.com',
        Username = 'testuser' + System.currentTimeMillis() + '@test.com',
        ProfileId = p.Id,
        TimeZoneSidKey = 'Asia/Kolkata',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US'
    );

    insert u;
    return u;
}

    @isTest
    public static void testFetchDetails(){
        Id systemAdminProfileId = [SELECT Id
                                   FROM Profile
                                   WHERE Name = 'System Administrator'].Id;
        Id internationalPortalProfileId = [SELECT Id
                                           FROM Profile
                                           WHERE Name = 'Biotech Partner Community'].Id;
        Id RBMRoleId = [SELECT Id
                        FROM UserRole
                        WHERE (Name like 'RSM Gujarat%')
                        LIMIT 1].Id;

        User systemAdmin = IB_TestDataFactory.createUser(systemAdminProfileId, 'International', RBMRoleId, 'EP-86573', 'I;II;III;IV;V', null);

        System.runAs(systemAdmin){

            CIty__c MiamiRegion = IB_TestDataFactory.createRegionData('Miami', '90', 'US');

            Id RecordTypeId = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('Consignee_Account').getRecordTypeId();
            
            Account internationalAcc = IB_TestDataFactory.createAccForInternational(MiamiRegion, '873890');
            Contact partnerContact = IB_TestDataFactory.createContact(internationalAcc.Id, 'Geller');

            Account shippingAcc = new Account();
            shippingAcc.RecordTypeId = RecordTypeId;
            shippingAcc.Name = 'Consignee account';
            shippingAcc.SAP_Code__c = '12345';
            shippingAcc.ShippingStreet = internationalAcc.Id;
            shippingAcc.ShippingCity = 'Vadodara';
            shippingAcc.Contact_Person__c = 'Darshan Patidar';
            shippingAcc.ShippingCountry = 'India';
            shippingAcc.E_Mail__c = 'xyz@gmail.com';

            //insert shippingAcc;
            

            Product__c internationalProd = IB_TestDataFactory.createProductData('I', 'International', 'U-987', 'International Product');

            User partnerUser = IB_TestDataFactory.createUser(internationalPortalProfileId, 'International', null, 'E94889', 'I;II', partnerContact.Id);
            List<Account> AddressLst = new List<Account>();
            system.runAs(partnerUser){
                   insert shippingAcc;
                Order__c ord = new Order__c(Account__c = internationalAcc.Id, Is_it_ok_to_cancel_old_Draft_Orders__c = true);
                insert ord;
                ord.Sales_Contract__c = true;
                update ord;

                Test.startTest();
                AddressLst = ActivateOrderController.fetchDetails(ord.Id);
                Test.stopTest();

            }
            

        }
    }
    
    @isTest
    public static void testcheckOrderStatus(){
        Id systemAdminProfileId = [SELECT Id
                                   FROM Profile
                                   WHERE Name = 'System Administrator'].Id;
        Id internationalPortalProfileId = [SELECT Id
                                           FROM Profile
                                           WHERE Name = 'Biotech Partner Community'].Id;
        Id RBMRoleId = [SELECT Id
                        FROM UserRole
                        WHERE (Name like 'RSM Gujarat%')
                        LIMIT 1].Id;

        User systemAdmin = IB_TestDataFactory.createUser(systemAdminProfileId, 'International', RBMRoleId, 'EP-86573', 'I;II;III;IV;V', null);

        System.runAs(systemAdmin){

            CIty__c MiamiRegion = IB_TestDataFactory.createRegionData('Miami', '90', 'US');

            Id RecordTypeId = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('Consignee_Account').getRecordTypeId();
            
            Account internationalAcc = IB_TestDataFactory.createAccForInternational(MiamiRegion, '873890');
            Contact partnerContact = IB_TestDataFactory.createContact(internationalAcc.Id, 'Geller');

            Account shippingAcc = new Account();
            shippingAcc.RecordTypeId = RecordTypeId;
            shippingAcc.Name = 'Consignee account';
            shippingAcc.SAP_Code__c = '12345';
            shippingAcc.ShippingStreet = internationalAcc.Id;
            shippingAcc.ShippingCity = 'Vadodara';
            shippingAcc.Contact_Person__c = 'Darshan Patidar';
            shippingAcc.ShippingCountry = 'India';
            shippingAcc.E_Mail__c = 'xyz@gmail.com';

            //insert shippingAcc;
            

            Product__c internationalProd = IB_TestDataFactory.createProductData('I', 'International', 'U-987', 'International Product');

            User partnerUser = IB_TestDataFactory.createUser(internationalPortalProfileId, 'International', null, 'E94889', 'I;II', partnerContact.Id);
            boolean isValidforActivation = false;
            boolean isValidforConsignee = false;

            boolean productsSelected = false;
            system.runAs(partnerUser){
                
                insert shippingAcc;
                Order__c ord = new Order__c(Account__c = internationalAcc.Id, Is_it_ok_to_cancel_old_Draft_Orders__c = true);
                insert ord;
                ord.Sales_Contract__c = true;
                update ord;

                Test.startTest();
                 isValidforActivation = ActivateOrderController.checkOrderStatusforActivation(ord.Id);
                isValidforConsignee = ActivateOrderController.checkOrderStatusforConsignee(ord.Id);

                 productsSelected  = ActivateOrderController.areOrderProductsSelected(ord.Id);
                Test.stopTest();

            }
            System.debug('isValidforActivation:->'+isValidforActivation+'isValidforConsignee:->'+isValidforConsignee);
            Assert.areEqual(isValidforActivation , false); // Succeeds
            Assert.areEqual(isValidforConsignee , true); // Succeeds

        }
    }
    
    @isTest
    public static void testCheckFreightRequest ()
    {
             Account testAccount = new Account(Name='Test Acc');
        insert testAccount;

        Order__c testOrder = new Order__c(Account__c = testAccount.Id);
        insert testOrder;
        
        Product__c prod = new Product__c(Name='ABC', Dummy_Product_Code__c='34566');
        insert prod;
        
        Plant__c plan = new Plant__c(Name='BCD');
        insert plan;

        // Create test Order Products
        List<Order_Product__c> newOrderProducts = new List<Order_Product__c>();
        newOrderProducts.add(new Order_Product__c(Order__c = testOrder.Id, Product__c = prod.Id));
        newOrderProducts.add(new Order_Product__c(Order__c = testOrder.Id, Product__c = prod.Id));
        insert newOrderProducts;

        // Create existing Freight Request records
        List<Split_Order__c  > existingSplitOrderList = new List<Split_Order__c  >();
        existingSplitOrderList.add(new Split_Order__c  (Order__c = testOrder.Id, Approx_Freight__c = 234.234,Transport_Mode__c='postal',EstimationId_Temp__c='dfsdf',RFQNumber_Temp__c='sdfdf'));
        existingSplitOrderList.add(new Split_Order__c  (Order__c = testOrder.Id, Approx_Freight__c = 234.24,Transport_Mode__c='postal',EstimationId_Temp__c='dfdf',RFQNumber_Temp__c='sddf'));
        insert existingSplitOrderList;
        
        Test.startTest();
        ActivateOrderController.checkFreightRequest(testOrder.Id);
        Test.stopTest();
        
    }
    
    @isTest
    public static void testCheckFreightRequestNoFreightRecCase ()
    {
             Account testAccount = new Account(Name='Test Acc');
        insert testAccount;

        Order__c testOrder = new Order__c(Account__c = testAccount.Id);
        insert testOrder;
        
        Product__c prod = new Product__c(Name='ABC', Dummy_Product_Code__c='34566');
        insert prod;
        
        Plant__c plan = new Plant__c(Name='BCD');
        insert plan;

        // Create test Order Products
        List<Order_Product__c> newOrderProducts = new List<Order_Product__c>();
        newOrderProducts.add(new Order_Product__c(Order__c = testOrder.Id, Product__c = prod.Id));
        newOrderProducts.add(new Order_Product__c(Order__c = testOrder.Id, Product__c = prod.Id));
        insert newOrderProducts;

    
        Test.startTest();
        ActivateOrderController.checkFreightRequest(testOrder.Id);
        Test.stopTest();
        
    }
    
    @isTest 
    public static void testActivateOrder(){
           Account testAccount = new Account(Name='Test Acc');
        insert testAccount;
            User u = createTestUser();


        Order__c testOrder = new Order__c(Account__c = testAccount.Id,CRM_Approver__c =u.Id);
        insert testOrder;

        Test.startTest();
        ActivateOrderController.activateOrder(testOrder.Id);
        Test.stopTest();        
    }
    @isTest
    public static void testCheckFreightRequestNegativeCase ()
    {
         Test.startTest();
        ActivateOrderController.checkFreightRequest(Null);
        Test.stopTest();
    }
    
    @isTest
    public static void testFillOrderConsignDetail(){
        Id systemAdminProfileId = [SELECT Id
                                   FROM Profile
                                   WHERE Name = 'System Administrator'].Id;
        Id internationalPortalProfileId = [SELECT Id
                                           FROM Profile
                                           WHERE Name = 'Biotech Partner Community'].Id;
        Id RBMRoleId = [SELECT Id
                        FROM UserRole
                        WHERE (Name like 'RSM Gujarat%')
                        LIMIT 1].Id;

        User systemAdmin = IB_TestDataFactory.createUser(systemAdminProfileId, 'International', RBMRoleId, 'EP-86573', 'I;II;III;IV;V', null);
        System.runAs(systemAdmin){
            CIty__c MiamiRegion = IB_TestDataFactory.createRegionData('Miami', '90', 'US');

            Account internationalAcc = IB_TestDataFactory.createAccForInternational(MiamiRegion, '873890');
            Contact partnerContact = IB_TestDataFactory.createContact(internationalAcc.Id, 'Geller');

            Product__c internationalProd = IB_TestDataFactory.createProductData('I', 'International', 'U-987', 'International Product');

            User partnerUser = IB_TestDataFactory.createUser(internationalPortalProfileId, 'International', null, 'E94889', 'I;II', partnerContact.Id);
            String result = '';

            Order__c ord = new Order__c(Account__c = internationalAcc.Id, Is_it_ok_to_cancel_old_Draft_Orders__c = true);
            insert ord;
            ord.Sales_Contract__c = true;
            update ord;
            // Create an instance of the OrderDetailWrapper class with test data
            OrderDetailWrapper orderDetailWrapper = new OrderDetailWrapper();
            orderDetailWrapper.Id = ord.Id; // Set the appropriate Order Id here
            orderDetailWrapper.selectedConName = 'Test Consignee';
            orderDetailWrapper.destination = 'Test Destination';
            orderDetailWrapper.city = 'Test City';
            orderDetailWrapper.street = 'Test Street';
            orderDetailWrapper.state = 'Test State';
            orderDetailWrapper.country = 'Test Country';
            orderDetailWrapper.zipCode = '12345';
            orderDetailWrapper.telephone = '555-555-5555';
            orderDetailWrapper.selectedDispatchMode = 'Air';

            // Serialize the OrderDetailWrapper as JSON
            String orderDetailJson = JSON.serialize(orderDetailWrapper);
            Test.startTest();
            result = ActivateOrderController.fillOrderConsignDetail(orderDetailJson);
            Test.stopTest();


            Assert.areEqual('Order updated successfully!', result, 'TestShippingAddressTrigger Passed'); // Succeeds
        }
    }

    public class OrderDetailWrapper{
        public String Id;
        public String selectedConName;
        public String destination;
        public String city;
        public String street;
        public String state;
        public String country;
        public String zipCode;
        public String telephone;
        public String selectedDispatchMode;

    }

    
          
    @isTest
    static void testGetPicklistValues_Positive() {
        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();

                Test.startTest();
        List<String> fieldApiNames = new List<String>{'Account_Assignment_Group__c','CurrencyIsoCode'};
        result = ActivateOrderController.getPicklistValues('Account', fieldApiNames);
        Test.stopTest();

        // Assertions
        System.debug(result.get('Account_Assignment_Group__c'));
        System.assertNotEquals(null, result.get('Account_Assignment_Group__c'), 'Expected picklist values to be retrieved');
        // Add more assertions based on the expected behavior of the getPicklistValues method
    }

    @isTest
    static void testGetPicklistValues_Negative() {
                      // Test Execution
                      Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
        Test.startTest();
        try { List<String> fieldApiNames = new List<String>{'abc','CurrencyIsoCode'};
        result = ActivateOrderController.getPicklistValues('Account', fieldApiNames);
            
        } catch (Exception e) {
            System.debug(e);

        }
       
        Test.stopTest();
        // Assertions
        System.assertEquals(null, result.get('abc'), 'Expected null result for non-existent field');
        // Add more assertions based on the expected behavior of the getPicklistValues method in negative scenarios
    }
}
@isTest
public class RequestForFreightControllerTest {
    
    @isTest
    static void testUpdateFreightStatus() {
        // Test when there is a Freight_Request__c record with the specified orderId
        Order__c newOrder = new Order__c(Customer_Po_No__c = '123456');
        insert newOrder;
        
         Product__c prod = new Product__c(Name='ABC', Dummy_Product_Code__c='34566');
        insert prod;
        
        Plant__c plan = new Plant__c(Name='BCD');
        insert plan;
        
        Freight_Request__c freightRequest = new Freight_Request__c(Order__c = newOrder.Id, Status__c = 'Created', Plant__c = plan.Id,Products__c ='ABC');
        insert freightRequest;
        
        Test.startTest();
        RequestForFreightController.updateFreightStatus(newOrder.Id);
        Test.stopTest();
        
        // Verify that the status is updated to 'Requested'
        freightRequest = [SELECT Id, Status__c FROM Freight_Request__c WHERE Id = :freightRequest.Id LIMIT 1];
        System.assertEquals('Requested', freightRequest.Status__c);
    }
    
    @isTest
    static void testUpdateFreightStatusNoRecord() {
        // Test when there is no Freight_Request__c record with the specified orderId
        Test.startTest();
        RequestForFreightController.updateFreightStatus('NonExistentOrder');
        Test.stopTest();
        // No need to assert anything, just ensuring there is no exception.
    } 
    @isTest
    static void testfetchFreightRequests() {
     // Create test Account and Order
        Account testAccount = new Account(Name='Test Acc');
        insert testAccount;

        Order__c testOrder = new Order__c(Account__c = testAccount.Id);
        insert testOrder;
        
        Product__c prod = new Product__c(Name='ABC', Dummy_Product_Code__c='34566');
        insert prod;
        Product__c prod2 = new Product__c(Name='def', Dummy_Product_Code__c='3456def');
        insert prod2;
        
        Plant__c plan = new Plant__c(Name='BCD');
        insert plan;

        // Create test Order Products
        List<Order_Product__c> newOrderProducts = new List<Order_Product__c>();
        newOrderProducts.add(new Order_Product__c(Order__c = testOrder.Id, Product__c = prod.Id,Is_Parent_Products__c= true));
        newOrderProducts.add(new Order_Product__c(Order__c = testOrder.Id, Product__c = prod2.Id,Is_Parent_Products__c= true));
        insert newOrderProducts;

        // Create existing Freight Request records
        List<Freight_Request__c> existingFRList = new List<Freight_Request__c>();
        existingFRList.add(new Freight_Request__c(Order__c = testOrder.Id, Plant__c = plan.Id,Products__c ='ABC,def'));
        insert existingFRList;

        // Test when there is no Freight_Request__c record with the specified orderId
        Test.startTest();
        RequestForFreightController.fetchFreightRequests(testOrder.Id);
        Test.stopTest();
        // No need to assert anything, just ensuring there is no exception.
    }
    
    @isTest
    static void testfetchStatus_Requests() {
     // Create test Account and Order
        Account testAccount = new Account(Name='Test Acc');
        insert testAccount;

        Order__c testOrder = new Order__c(Account__c = testAccount.Id);
        insert testOrder;
        
        Product__c prod = new Product__c(Name='ABC', Dummy_Product_Code__c='34566');
        insert prod;
        Product__c prod2 = new Product__c(Name='def', Dummy_Product_Code__c='3456def');
        insert prod2;
        
        Plant__c plan = new Plant__c(Name='BCD');
        insert plan;

        // Create test Order Products
        List<Order_Product__c> newOrderProducts = new List<Order_Product__c>();
        newOrderProducts.add(new Order_Product__c(Order__c = testOrder.Id, Product__c = prod.Id,Is_Parent_Products__c= true));
        newOrderProducts.add(new Order_Product__c(Order__c = testOrder.Id, Product__c = prod2.Id,Is_Parent_Products__c= true));
        insert newOrderProducts;

        // Create existing Freight Request records
        List<Freight_Request__c> existingFRList = new List<Freight_Request__c>();
        existingFRList.add(new Freight_Request__c(Order__c = testOrder.Id, Plant__c = plan.Id,Products__c ='ABC,def'));
        insert existingFRList;

        // Test when there is no Freight_Request__c record with the specified orderId
        Test.startTest();
        RequestForFreightController.fetchStatus_Requests(testOrder.Id);
        Test.stopTest();
        // No need to assert anything, just ensuring there is no exception.
    }
    
    @isTest
    static void testfetchOrderStatus() {
     // Create test Account and Order
        Account testAccount = new Account(Name='Test Acc');
        insert testAccount;

        Order__c testOrder = new Order__c(Account__c = testAccount.Id);
        insert testOrder;
        
        Product__c prod = new Product__c(Name='ABC', Dummy_Product_Code__c='34566');
        insert prod;
        Product__c prod2 = new Product__c(Name='def', Dummy_Product_Code__c='3456def');
        insert prod2;
        
        Plant__c plan = new Plant__c(Name='BCD');
        insert plan;

        // Create test Order Products
        List<Order_Product__c> newOrderProducts = new List<Order_Product__c>();
        newOrderProducts.add(new Order_Product__c(Order__c = testOrder.Id, Product__c = prod.Id,Is_Parent_Products__c= true));
        newOrderProducts.add(new Order_Product__c(Order__c = testOrder.Id, Product__c = prod2.Id,Is_Parent_Products__c= true));
        insert newOrderProducts;

        // Create existing Freight Request records
        List<Freight_Request__c> existingFRList = new List<Freight_Request__c>();
        existingFRList.add(new Freight_Request__c(Order__c = testOrder.Id, Plant__c = plan.Id,Products__c ='ABC,def'));
        insert existingFRList;

        // Test when there is no Freight_Request__c record with the specified orderId
        Test.startTest();
        RequestForFreightController.fetchOrderStatus(testOrder.Id);
        Test.stopTest();
        // No need to assert anything, just ensuring there is no exception.
    }
}
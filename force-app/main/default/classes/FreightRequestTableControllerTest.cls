@isTest
public class FreightRequestTableControllerTest {
    
    @isTest
    static void testgetfreightProductList() {
        
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

        Test.startTest();
        FreightRequestTableController cls = new FreightRequestTableController();
        cls.parentObjId = testOrder.Id;
        cls.getfreightProductList();
        Test.stopTest();
        
        // Verify that the status is updated to 'Requested'
        //freightRequest = [SELECT Id, Status__c FROM Freight_Request__c WHERE Id = :freightRequest.Id LIMIT 1];
        //System.assertEquals('Requested', freightRequest.Status__c);
    }
}
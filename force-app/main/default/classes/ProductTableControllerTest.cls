@isTest
public class ProductTableControllerTest {

    @isTest
    static void testProductTableController() {
       // Create test Account and Order
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
        newOrderProducts.add(new Order_Product__c(Order__c = testOrder.Id, Product__c = prod.Id,Is_Parent_Products__c = true));
        newOrderProducts.add(new Order_Product__c(Order__c = testOrder.Id, Product__c = prod.Id));
        insert newOrderProducts;


        // Create an instance of the ProductTableController class
        ProductTableController controller = new ProductTableController();
        controller.parentObjId = testOrder.Id;
controller.getProductOrderList();
        // Set the order property to the test Order__c record Id
        //controller.order = testOrder;

        // Verify that the order property is properly initialized
        //System.assertEquals(testOrder.Id, controller.orderId);
    }
}
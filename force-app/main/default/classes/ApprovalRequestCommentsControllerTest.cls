@isTest
public class ApprovalRequestCommentsControllerTest {
    
    @testSetup
    static void setup() {
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
    }
    
    @isTest
    static void testGetLastApprovalStepWithComments() {
        Order__c testOrder = [Select id from Order__c];
        testOrder.Is_Activate__c = true;
        update testOrder;
        
        List<ProcessInstance> piList = [Select p.TargetObjectId, p.Status From ProcessInstance p where TargetObjectId = :testOrder.Id];
        
        system.debug('piList:' +piList);
        ApprovalRequestCommentsController cls = new ApprovalRequestCommentsController();
        String str1 = cls.comments;
        // Create a ProcessInstance for the test record
        
    }
    
    
}
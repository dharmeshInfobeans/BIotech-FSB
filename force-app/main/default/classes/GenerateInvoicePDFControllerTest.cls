@isTest
public class GenerateInvoicePDFControllerTest {
    
    @isTest static void testingCalloutMethod() {
        insert new SAP_Creds__c(Name ='SAP_InvoicePDFData', Username__c = 'piuser', Password__c = 'Welcome@123', Endpoint__c = 'http://103.231.40.158:50000/RESTAdapter/salesforce/transactional/SF_InvoicePDFData');
        
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
        newOrderProducts.add(new Order_Product__c(Order__c = testOrder.Id, Product__c = prod.Id,Is_Parent_Products__c= true));
        insert newOrderProducts;
        
        OrderLineItem__c oli = new OrderLineItem__c(Order__c =testOrder.Id ,Order_Num_SAP__c ='3130006843' ,Status__c='Assigned',Products__c = 'ABC');
        insert oli;
        
        // Create a test record for Shipment_Detail__c
        Shipment_Detail__c testRecord = new Shipment_Detail__c(
            // Set the required fields here
            Order_Line_Item__c = oli.Id, 
            SAP_Order_Number__c = '3130006843',
            Invoice__c = '90028838'
        );
        insert testRecord;

        // setting mock callout
        Test.setMock(HttpCalloutMock.class, new GenerateInvoicePDFControllerMockResponse());
        
        Test.startTest();
        //calling the method
        GenerateInvoicePDFController.InvoiceData res = GenerateInvoicePDFController.getBase64String(testRecord.Id);
        Test.stopTest();
        
        //checking the response
        System.assertEquals(1, res.status_Code);

        String responseMessage = res.message;
        String expectedMessage = 'Invoice PDF found and added in response';
        System.assertEquals(expectedMessage, responseMessage);        

        String responseString = res.base64;
        String expectedString = 'hereIsBase64StringForPDF';
        System.assertEquals(expectedString, responseString);        

    }
}
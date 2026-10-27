@isTest
private class FetchUpdatedOrdersFromSAPTest {
    
    @testSetup
    static void setup() {
        // Create a test account
        Account testAccount = new Account(Name = 'Test Acc');
        insert testAccount;
        
        // Create a test order
        Order__c testOrder = new Order__c( Account__c = testAccount.Id);
        insert testOrder;
        testOrder.Integration_enabled_for_Created_By_User__c = true;
        update testOrder;
        
        
        // Create test products
        Product__c prod = new Product__c(Name = 'ABC', Dummy_Product_Code__c = '34566');
        insert prod;
        Product__c prod2 = new Product__c(Name = 'DEF', Dummy_Product_Code__c = '3456DEF');
        insert prod2;
        
        // Create test order products
        List<Order_Product__c> newOrderProducts = new List<Order_Product__c>{
            new Order_Product__c(Order__c = testOrder.Id, Product__c = prod.Id, Is_Parent_Products__c = true),
                new Order_Product__c(Order__c = testOrder.Id, Product__c = prod2.Id, Is_Parent_Products__c = true)
                };
                    insert newOrderProducts;
        
        // Create test order line items
        List<OrderLineItem__c> oliLst = new List<OrderLineItem__c>{
            new OrderLineItem__c(Order_Num_SAP__c = '0050009268', Order__c = testOrder.Id, Status__c = 'Assigned')
                };
                    insert oliLst;
        
        // Create test shipment details
        Shipment_Detail__c shipment = new Shipment_Detail__c(
            SAP_Order_Number__c = '0050009268', 
            Order_Line_Item__c = oliLst[0].Id, 
            Delivery__c = 'D123',
            Shipping_Partner__c = 'UPS',
            Partner_Name__c = 'Test Partner',
            Tracking__c = '1ZA316R904985',
            Invoice__c = 'INV123',
            External_Invoice__c = 'EINV123',
            Shipping_Status__c = 'Assigned',
            Assigned_Date__c = Date.today(),
            Assigned_Time__c = Time.newInstance(10, 30, 0, 0),
            Delivered_Date__c = Date.today().addDays(1),
            Deliverd_Time__c = Time.newInstance(15, 30, 0, 0)
        );
        insert shipment;
    }
    
    @isTest
    static void testdoPost() {
        // Create test data
        OrderAndOrderLineItemsWrapper.OrderWrapper sapRecord = new OrderAndOrderLineItemsWrapper.OrderWrapper();
        OrderAndOrderLineItemsWrapper.OrderLineItemsWrapper oliItem = new OrderAndOrderLineItemsWrapper.OrderLineItemsWrapper();
        oliItem.orderNumSAP = '0050009268';
        oliItem.status = 'Shipped';
        
        OrderAndOrderLineItemsWrapper.ShipmentWrapper shipItem = new OrderAndOrderLineItemsWrapper.ShipmentWrapper();
        shipItem.shippingPartner = 'UPS';
        shipItem.partnerName = 'Test Partner';
        shipItem.trackingNumber = '1ZA316R904985';
        shipItem.deliveryNumber = 'D123';
        shipItem.invoiceNumber = 'INV123';
        shipItem.externalInvoiceNumber = 'EINV123';
        shipItem.shipingStatus = 'Delivered';
        shipItem.assignedDate = '2023/06/16';
        shipItem.assignedTime = '10:30:00';
        shipItem.deliveredDate = '2023/06/17';
        shipItem.deliveredTime = '15:30:00';
        
        oliItem.shipments = new List<OrderAndOrderLineItemsWrapper.ShipmentWrapper>{ shipItem };
            // Query to get the Account Id based on the Account name 'Test Acc'
            Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Acc' LIMIT 1];
        
        	List<Order__c> orderLst =[
            SELECT Name,Integration_enabled_for_Created_By_User__c 
            FROM Order__c 
            
        ];
        System.debug('orderLst:-->'+orderLst);
        
        // Use the Account Id in the Order query
       sapRecord.orderId =orderLst[0].Name;
        
        sapRecord.orderLineItems = new List<OrderAndOrderLineItemsWrapper.OrderLineItemsWrapper>{ oliItem };
            
            String bodyStr = JSON.serialize(sapRecord);
        system.debug('bodyStr : ' + bodyStr);
        
        // Set up the request and response
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/Orders_Update';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(bodyStr);
        
        RestResponse response = new RestResponse();
        
        // Set the mock request and response
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        FetchUpdatedOrdersFromSAP.doPost();
        Test.stopTest();
        
        // Assertions
        response = RestContext.response;
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(response.responseBody.toString());
        
        System.assertEquals(200, response.statusCode);
        System.assertEquals('1', responseBody.get('statusCode'));
        System.assertEquals('Order updated successfully', responseBody.get('message'));
        
        // Verify that the order line item and shipment detail were updated correctly
        OrderLineItem__c updatedOli = [SELECT Id, Status__c FROM OrderLineItem__c WHERE Order_Num_SAP__c = '0050009268'];
        System.assertEquals('Assigned', updatedOli.Status__c);
        
        Shipment_Detail__c updatedShipment = [SELECT Shipping_Status__c FROM Shipment_Detail__c WHERE Tracking__c = '1ZA316R904985'];
        System.assertEquals('Delivered', updatedShipment.Shipping_Status__c);
    }
    
    @isTest
    static void testOrderNotFound() {
        // Create a request with an order ID that doesn't exist
        OrderAndOrderLineItemsWrapper.OrderWrapper sapRecord = new OrderAndOrderLineItemsWrapper.OrderWrapper();
        sapRecord.orderId = 'NonexistentOrder';
        sapRecord.orderLineItems = new List<OrderAndOrderLineItemsWrapper.OrderLineItemsWrapper>();
        
        String bodyStr = JSON.serialize(sapRecord);
        system.debug('bodyStr : ' + bodyStr);
        
        // Set up the request and response
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/Orders_Update';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(bodyStr);
        
        RestResponse response = new RestResponse();
        
        // Set the mock request and response
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        FetchUpdatedOrdersFromSAP.doPost();
        Test.stopTest();
        
        // Assertions
        response = RestContext.response;
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(response.responseBody.toString());
        
        System.assertEquals(400, response.statusCode);
        System.assertEquals('0', responseBody.get('statusCode'));
        System.assertEquals('SAP Order not found in the system!', responseBody.get('message'));
    }
}
@isTest
private class OrderSyncUpFromSAPTest {
    @testSetup
    static void setupTestData() {
        
        // Create Account record
        Id  RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Distributor').getRecordTypeId();
        

        Account accObj = new Account(
            Name = 'Test Account',
            AccountNumber = '12345678',
            rsm__c = UserInfo.getUserId(),
            ZSM__c = UserInfo.getUserId(),
            Street_2__c = 'Street2',
            Street_3__c = 'Street3',
            Street_4__c = 'Street4',
            Street_5__c = 'Street5',
            Country_Key__c = 'IN',
            City__c = 'Gwalior',
            City_postal_code__c = '474006',
            recordtypeid = RecordTypeId,
            Branch__c = '',
            Sub_Status__c = 'Submitted To Approver 1',
            Medical_Registration_No__c = 'MEDREG123424567',
            GSTIN_No__c = 'GSTIN2343423456',
            SAP_Code__c = '122322'
        );
        insert accObj;
        
       // Create Sample Request Header
        Sample_Request_Header__c sampleHeader = new Sample_Request_Header__c(
            Status_Code__c = 'Ordered',
            orderNumSAP__c = '3260015725',
            Tracking_Number__c = 'TN123456',
            External_Invoice_Number__c = 'INV-987654',
            Shipping_Partner__c = 'DHL',
            Delivery_Number__c = 'D12345',
            Shipping_No__c = 'SHP-7890',
            Partner_Name__c = 'Test Partner',
            Shiping_Status__c = 'In Transit',
            SAP_Order_Number__c = '1200584',
            invoiceNumber__c = 'INV-456789',
            Assigned_Date__c = string.valueof(Date.today()),
            Order_cancelled__c = false,
            Approval_Status__c = 'Approved',
            Bill_To_Code__c = 'BTC-001',
            Ship_To_Code__c = 'STC-002',
            Date__c = system.today(),
            Remarks__c = 'Test Order for Sync',
            Assigned_Time__c = string.valueof(System.now()),
            Isapproval__c = true,
            Customer__c = accObj.Id
        );
        insert sampleHeader;
    }

    @isTest
    static void testProcessData_Success() {
        
        Sample_Request_Header__c data= [select id from Sample_Request_Header__c limit 1];
        Test.startTest();
        
        // Create a mock request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf('{  "orderId": "SMO_' + data.Id + '" , "orderLineItems": [{ "orderNumSF": "SF12345", "orderNumSAP": "SAP67890", "status": "Shipped", "shipments": [{ "invoiceNumber": "INV001", "trackingNumber": "TRACK123" }] }] }');
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        OrderSyncUpFromSAP.processData();
        
        Test.stopTest();
       
    }

    @isTest
    static void testProcessData_Exception() {
        Test.startTest();
        
        // Create a mock request with an invalid ID
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody = Blob.valueOf('{ "orderId": "InvalidID" }');
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        OrderSyncUpFromSAP.processData();
        
        Test.stopTest();
       
    }
}
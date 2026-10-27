@isTest
public class AdminApprovalProcessforSampleAccountTest {
    @testSetup
    static void setupTestData() {
        // Create a test Customer Account
        Account testCustomer = new Account(Name = 'Test Customer', 
            SAP_code__c = 'SAP123', Branch_Code__c = 'B123', Branch_Name__c = 'Test Branch');
        insert testCustomer;

        // Create a Sample Request Header
        Sample_Request_Header__c testScheme = new Sample_Request_Header__c(
            Customer__c = testCustomer.Id,
            OrderId__c = 'ORD123',
            Order_Number__c = '12345',
            orderNumSAP__C = 'SAPORD123',
            ship_to_code__c = 'SHIP123',
            Country__c = 'INDIA',
            Remarks__c = 'Test Remarks'
        );
        insert testScheme;

        // Create Sample Request Line Items
        List<Sample_Request_Line_Item__c> lineItems = new List<Sample_Request_Line_Item__c>{
            new Sample_Request_Line_Item__c(
                Sample_Request_Header__c = testScheme.Id,
                Dummy_Product_Description__c = 'Product 1',
                Product_Code_SAP_Code__c = 'P1',
                Diaptor__c = 'D1',
                Product_Quantity__c = 10
            ),
            new Sample_Request_Line_Item__c(
                Sample_Request_Header__c = testScheme.Id,
                Dummy_Product_Description__c = 'Product 2',
                Product_Code_SAP_Code__c = 'P2',
                Diaptor__c = 'D2',
                Product_Quantity__c = 20
            )
        };
        insert lineItems;

        // Create an Org-Wide Email Address
        OrgWideEmailAddress owea =[select id,Displayname from OrgWideEmailAddress where address='crmhelpdesk@biotechhealthcare.com'];
          

        // Create a Sample Request Branch Email
        Sample_Request_Branch_Email__c branchEmail = new Sample_Request_Branch_Email__c(
            Name = 'INDIA',
            Branch_Name__c = 'Test Branch',
            Branch_Code__c = 'B123',
            Branch_Email__c = 'test@biotechhealthcare.com'
        );
        insert branchEmail;
    }

    @isTest
    static void testSendMOUEmail() {
        // Get a sample request header record
        Sample_Request_Header__c scheme = [SELECT Id FROM Sample_Request_Header__c LIMIT 1];

        Test.startTest();
        AdminApprovalProcessforSampleAccount.sendMOUEmail(scheme.Id);
        Test.stopTest();

       
    }
}
@Istest
public class AdminApprovalProcessforSampleLeadTest {
    
     @testSetup
    static void setupTestData() {
        
         Leads__c triggerSetting = new Leads__c();
        triggerSetting.Name = 'LeadTrigger';
        triggerSetting.IsActive__c = true;
        insert triggerSetting;
        
        // Create Lead record
        Lead__c lea = new Lead__c(
            Name = 'Test Lead',
            First_Name__c = 'Test',
            Last_Name__c = 'Singh',
            Company__c = 'Plus91labs',
            Product__c = 'BIO BLADE',
            Billing_City__c = 'Gwalior',
            Billing_code__c = '474001',
            Country__c = 'INDIA',
            rsm__c = UserInfo.getUserId(),
            ZSM__c = UserInfo.getUserId(),
            Billing_state__c = 'MP',
            Billing_country__c = 'India',
            Email__c = 'pankajsinghania123@gmail.com',
            Mobile__c = '1234567890',
            Billing_Street__c = 'Test Street',
            SAP_Code__c = '12343122',
            Approval_status__c = 'Approved',
            Aproved_By_Manager__c = true,
            Lead_Stage__c = 'presentation',
            CE_CIS_Approval__c = true,
            Status__c = true,
            Plant__c = 'test plant code',
            Plant_code__c = 'B123',
            New_Customer__c = true
        );
        insert lea;


        // Create a Sample Request Header
        Sample_Request_Header__c testScheme = new Sample_Request_Header__c(
            leads__c = lea.Id,
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
            Branch_Name__c = 'test plant code',
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
        AdminApprovalProcessforSampleLead.sendMOUEmail(scheme.Id);
        Test.stopTest();

       
    }

}
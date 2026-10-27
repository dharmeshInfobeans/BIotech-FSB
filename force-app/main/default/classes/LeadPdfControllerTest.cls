@isTest
public class LeadPdfControllerTest {
    @isTest
    static void testGetPdfData() {
        
        // Create a new custom setting record
        Leads__c setting = new Leads__c();
        setting.Name = 'LeadTrigger';
        setting.IsActive__c = true;
        insert setting;

        // Create test data
        Lead__c lead = new Lead__c(
            Name = 'Test Lead',
            Email__c = 'testlead@example.com',
            Billing_Street__c = '123 Test Street',
            Billing_City__c = 'Test City',
            Country__c = 'INDIA',
            Company__c = 'Gwalior',
            Mobile__c = '1234567890',
            Product__c = 'BIO BLADE',
            First_Name__c = 'Test',
            Last_Name__c = 'User',
            Billing_state__c = 'Test State'
        );
        insert lead;

        New_Customer_SAP_Code_PDF__c ncs = new New_Customer_SAP_Code_PDF__c(
            Name = 'INDIA',
            Country_Key__c = 'IN',
            Company_Code__c = 'COMP123',
            Sales_Organization__c = 'SALESORG1',
            Division__c = 'DIV1',
            Customer_classification__c = 'Class A',
            Industry_key__c = 'IND1',
            Terms_of_Payment_Key__c = 'TPK1',
            
            Customer_group__c = 'GROUP1',
            Currency__c = 'INR',
            Delivery_Priority__c = 'High'
        );
        insert ncs;

        // Mock the PageReference and set the test ID
        Test.setCurrentPageReference(new PageReference('/apex/LeadPdfPage'));
        ApexPages.currentPage().getParameters().put('id', lead.Id);

        // Call the method
        LeadPdfController controller = new LeadPdfController();
        List<LeadPdfController.DataWrapper> data = controller.getPdfData();

        // Assertions to verify the data
        System.assertNotEquals(null, data, 'Data list should not be null.');
        System.assert(!data.isEmpty(), 'Data list should not be empty.');

        // Verify specific fields
        Boolean foundLeadName = false;
        Boolean foundEmail = false;

        for (LeadPdfController.DataWrapper dw : data) {
            if (dw.field == 'Name' && dw.value == 'Test Lead') {
                foundLeadName = true;
            }
            if (dw.field == 'Email' && dw.value == 'testlead@example.com') {
                foundEmail = true;
            }
        }

       
    }
}
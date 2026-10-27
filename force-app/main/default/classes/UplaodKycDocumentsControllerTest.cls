@IsTest
public class UplaodKycDocumentsControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create test Lead__c record
        Leads__c triggerSetting = new Leads__c();
        triggerSetting.Name = 'LeadTrigger';
        triggerSetting.IsActive__c = true;
        insert triggerSetting;
      
        Lead__c testLead = new Lead__c(
            Name = 'Test Lead ',
            First_Name__c = 'test',
            Last_Name__c = 'singh',
            Company__c = 'Plus91labs',
            Product__c = 'BIO BLADE',
            Billing_City__c = 'Gwalior',
            Billing_code__c = '474001',
            Country__c = 'INDIA',
            Billing_state__c = 'Mp',
            Billing_country__c = 'INDIA',
            Email__c = 'pankajsinghania123@gmail.com',
            Mobile__c = '1234567890',
            Billing_Street__c = 'chandranagr koteshwar',
            SAP_Code__c = '12343122',
            Approval_status__c = 'Approved',
            Aproved_By_Manager__c = true,
            Lead_Stage__c = 'Upgrade',
            CE_CIS_Approval__c = true,
            Plant__c = 'test',
            Status__c = true
            
        );
        insert testLead;
        
        // Create a ContentVersion record (represents the file to be linked)
        ContentVersion contentVersion = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test content for file'),
            IsMajorVersion = true
        );
        insert contentVersion;
        
        // Fetch the ContentDocumentId from ContentVersion
        List<ContentDocument> contentDocuments = [SELECT Id FROM ContentDocument WHERE Id IN (SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id)];
        
        if (!contentDocuments.isEmpty()) {
            // Link ContentDocument to the Lead using ContentDocumentLink
            ContentDocumentLink contentDocumentLink = new ContentDocumentLink(
                LinkedEntityId = testLead.Id,
                ContentDocumentId = contentDocuments[0].Id,
                ShareType = 'V', // Viewer access
                Visibility = 'AllUsers'
            );
            insert contentDocumentLink;
        }


        
        
         Sales_Data_Kyc_Form__c salesdata1 = new Sales_Data_Kyc_Form__c();
       
        salesdata1.Name = 'TestSalesDataKyc';
        salesdata1.Country__c='INDIA';
        salesdata1.Email__c='abhayjadon123@gmail.com';
        salesdata1.State__c='Mp';
        salesdata1.Plant__c='test';
        salesdata1.Sales_District__c='Gwalior';
        salesdata1.Sales_Officer__c='1022';
        
        insert salesdata1;
        
      

        // Create test Account record
        Account testAccount = new Account(
            Name = 'Test Account',
            E_Mail__c = 'testlead@example.com',
            BillingPostalCode = '123456'
        );
        insert testAccount;


        // Create a custom metadata record for New_Customer_SAP_Code_PDF__c
        New_Customer_SAP_Code_PDF__c testSapPdf = new New_Customer_SAP_Code_PDF__c(
            Name = 'INDIA',
            Sales_Office__c = 'S001;S002',
            Sales_District__c = 'D001;D002'
        );
        insert testSapPdf;
    }

    @IsTest
    static void testGetRecords() {
        // Fetch the test lead
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];
       
        // Call the method to test
        Test.startTest();
        Map<String, Object> resultMap = UplaodKycDocumentsController.getRecords(lead.Id);
        Test.stopTest();

        // Verify that the result map contains the expected keys and data
        System.assert(resultMap.containsKey('KycData'), 'KycData should be present in the result.');
        System.assert(resultMap.containsKey('AccountExist'), 'AccountExist should be present in the result.');
       // System.assertEquals(true, resultMap.get('AccountExist'), 'AccountExist should be true since account exists.');
        System.assert(resultMap.containsKey('SalesDistrict'), 'SalesDistrict should be present in the result.');
        System.assert(resultMap.containsKey('SalesOfficer'), 'SalesOfficer should be present in the result.');
    }

    @IsTest
    static void testUploadFile() {
        // Fetch the test lead
        Lead__c lead = [SELECT Id FROM Lead__c LIMIT 1];
        
        String base64Data = 'VGhpcyBpcyBhIHRlc3QgZmlsZSBjb250ZW50';
        String fileName = 'TestFile.pdf';
         Map<String, String> fileMap = new Map<String, String>();
           fileMap.put('Aadhar_Card','12232235');


        Test.startTest();
        String contentDocLinkId = UplaodKycDocumentsController.uploadFile(base64Data, fileName, lead.Id,fileMap);
        Test.stopTest();

             
      
    }

    @IsTest
    static void testUpdateLeadData() {
        // Fetch the test lead
        Lead__c lead = [SELECT Id, Upload_Count__c FROM Lead__c LIMIT 1];
        Decimal initialUploadCount = lead.Upload_Count__c;

        Test.startTest();
        UplaodKycDocumentsController.updateLeadData(lead.Id);
        Test.stopTest();

        // Verify that the Upload_Count__c has been incremented
        Lead__c updatedLead = [SELECT Upload_Count__c FROM Lead__c WHERE Id = :lead.Id];
        System.assertEquals(initialUploadCount + 1, updatedLead.Upload_Count__c, 'Upload_Count__c should have been incremented.');
    }

    @IsTest
    static void testSaveLeadAndPdf() {
        // Create a lead record to update
        Lead__c leadToUpdate = [SELECT Id FROM Lead__c LIMIT 1];
        leadToUpdate.Name = 'Updated Test Lead';

        Test.startTest();
        UplaodKycDocumentsController.saveLeadAndPdf(leadToUpdate.Id, leadToUpdate);
        Test.stopTest();

        // Verify the lead record was updated
        Lead__c updatedLead = [SELECT Name FROM Lead__c WHERE Id = :leadToUpdate.Id];
        System.assertEquals('Updated Test Lead', updatedLead.Name, 'The lead name should have been updated.');
    }
}
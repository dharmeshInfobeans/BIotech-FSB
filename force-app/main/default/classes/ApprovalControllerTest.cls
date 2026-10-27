@IsTest
public class ApprovalControllerTest {
    @TestSetup
   public static void createData() {
    // Create a custom setting record
    Leads__c triggerSetting = new Leads__c();
    triggerSetting.Name = 'LeadTrigger';
    triggerSetting.IsActive__c = true;
    insert triggerSetting;

    // Create a test user
    User testUser = new User(
        FirstName = 'Test',
        LastName = 'User',
        Alias = 'tuser',
        Email = 'abhay@plus91labs.com',
        Username = 'amifghjjyhtvgrcfd@example.com.dev', // Username must be unique
        CommunityNickname = 'TestUser', // Required for Experience Cloud users
        TimeZoneSidKey = 'America/Los_Angeles', // Adjust for desired timezone
        LocaleSidKey = 'en_US', // Adjust for desired locale
        EmailEncodingKey = 'UTF-8',
        ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id, // Change to desired profile
        LanguageLocaleKey = 'en_US'
    );
    insert testUser;

    System.debug('Test User Created: ' + testUser);
       
       Sales_Data_Kyc_Form__c salesdata1 = new Sales_Data_Kyc_Form__c();
       
        salesdata1.Name = 'TestSalesDataKyc';
        salesdata1.Country__c='INDIA';
        salesdata1.Email__c='abhayjadon123@gmail.com';
        salesdata1.State__c='Madhyapradesh';
        salesdata1.Plant__c='test';
        salesdata1.Sales_District__c='Gwalior';
        salesdata1.Sales_Officer__c='1022';
        
        insert salesdata1;
       
       Sample_Request_Approver__c sra = new Sample_Request_Approver__c();
       sra.Country_Name__c='INDIA';
       sra.RSM__c = testUser.Id;
       sra.ZSM__c=  testuser.Id;
       sra.GM__c=   testuser.Id;
       sra.Admin__c=testuser.Id;
        
       insert sra;
       
       
      
       

    // Create a custom setting record
    customer_creation_url__c customSettingRecord = new customer_creation_url__c(
        Name = 'Customer Creation urls',
        RSM_Url__c = 'https://biotechcrm--biotechdev.sandbox.my.salesforce-sites.com/DocumentApprovalpage?id=',
        document_url__c = 'https://biotechcrm--biotechdev.sandbox.my.salesforce-sites.com/sfc/servlet.shepherd/document/download/',
        GM_NSM_url__c='https://biotechcrm--biotechdev.sandbox.my.salesforce-sites.com/GMNSMKYCapproval?id=',
        SAP_url__c='https://biotechcrm--biotechdev.sandbox.my.salesforce-sites.com/SAPKycteammembervf?id=',
        Admin_url__c='https://biotechcrm--biotechdev.sandbox.my.salesforce-sites.com/adminkycapproval?id=',
        Thank_you_url__c='https://biotechcrm--biotechdev.sandbox.my.salesforce-sites.com/thankyoupage',
        ZSM_url__c='https://biotechcrm--biotechdev.sandbox.my.salesforce-sites.com/ZSMapprovalvfpage?id='
    );
    insert customSettingRecord;

    // Create a record for SAP code PDF
    New_Customer_SAP_Code_PDF__c sapCodePDF = new New_Customer_SAP_Code_PDF__c(
        Name = 'INDIA',
        Company_Code__c = '1000',
        Sales_Organization__c = '2000',
        Distribution_Channel__c = '10',
        Division__c = '00',
        Customer_Account_Group__c = 'Z001',
        Customer_classification__c = '1',
        Industry_key__c = 'M1',
        Industry_Code_1__c = '11',
        Terms_of_Payment_Key__c = 'ZNET30',
        Customer_group__c = '01',
        Currency__c = 'INR',
        Delivery_Priority__c = '02',
        Delivering_Plant_Own_or_External__c = '1000',
        Account_assignment_group_for_this_custom__c = 'Z002'
    );
    insert sapCodePDF;
    System.debug('SAP Code PDF Record Created: ' + sapCodePDF);

    // Create a Lead and associate with the test user
    Lead__c testLead = new Lead__c(
        Name = 'Test Lead',
        First_Name__c = 'test',
        Last_Name__c = 'singh',
        Email__c = 'testlead@example.com',
        Billing_Street__c = '123 Test Street',
        Billing_City__c = 'Test City',
        Country__c = 'India',
        Sales_district__c = 'D026',
        Sales_Office__c = '1022',
        Billing_state__c = 'Test State',
        Mobile__c = '1234567890',
        Name_1__c = 'Test Name 1',
        Name_2__c = 'Test Name 2',
        Street_3__c = 'Street 3',
        Street_4__c = 'Street 4',
        Company__c = 'Gwalior',
        City_postal_code__c = '123456',
        SAP_City__c = 'SAP City',
        Country_Key__c = 'IN',
        Region_State_Province_County__c = 'Test Region',
        First_telephone_no_dialling_code__c = '91',
        First_Mobile_Telephone_No_Dialing__c = '91',
        First_fax_no_dialling_code_number__c = '91',
        E_Mail_Address__c = 'leademail@example.com',
        Product__c = 'BIO BLADE',
        RSM__c = testUser.Id, // Lookup to User
        RSM_Approve__c = false,
        RSM_Not_Approve__c = false,
        ZSM__c = testUser.Id, // Lookup to User
       // GM_NSM__c = testUser.Id,
        User__c=testuser.Id,// Lookup to User
        Admin_Approve__c=true,
        //SAP_Code__c =  '566787',
        Admin_Not_Approve__c=false,
        Plant__c='test'
    );
    insert testLead;

    // Debug the inserted Lead record
    testLead = [SELECT Id, RSM__c, ZSM__c, GM_NSM__c FROM Lead__c WHERE Id = :testLead.Id];
    System.debug('Test Lead Created: ' + testLead);
    System.debug('RSM: ' + testLead.RSM__c + ', ZSM: ' + testLead.ZSM__c + ', GM_NSM: ' + testLead.GM_NSM__c);



    
}

    
    @isTest
    public static void test(){
        
         // Create a custom setting record
    Leads__c triggerSetting = new Leads__c();
    triggerSetting.Name = 'LeadTrigger';
    triggerSetting.IsActive__c = true;
    insert triggerSetting;

   user testuser = [select id,email from user limit 1];

    System.debug('Test User Created: ' + testUser);
       
       Sales_Data_Kyc_Form__c salesdata1 = new Sales_Data_Kyc_Form__c();
       
        salesdata1.Name = 'TestSalesDataKyc';
        salesdata1.Country__c='INDIA';
        salesdata1.Email__c='abhayjadon123@gmail.com';
        salesdata1.State__c='Madhyapradesh';
        salesdata1.Plant__c='test';
        salesdata1.Sales_District__c='Gwalior';
        salesdata1.Sales_Officer__c='1022';
        
        insert salesdata1;
       
       Sample_Request_Approver__c sra = new Sample_Request_Approver__c();
       sra.Country_Name__c='INDIA';
       sra.RSM__c = testUser.Id;
       sra.ZSM__c=  testuser.Id;
       sra.GM__c=   testuser.Id;
       sra.Admin__c=testuser.Id;
        
       insert sra;
       
       
      
       

    // Create a custom setting record
    customer_creation_url__c customSettingRecord = new customer_creation_url__c(
        Name = 'Customer Creation urls',
        RSM_Url__c = 'https://biotechcrm--biotechdev.sandbox.my.salesforce-sites.com/DocumentApprovalpage?id=',
        document_url__c = 'https://biotechcrm--biotechdev.sandbox.my.salesforce-sites.com/sfc/servlet.shepherd/document/download/',
        GM_NSM_url__c='https://biotechcrm--biotechdev.sandbox.my.salesforce-sites.com/GMNSMKYCapproval?id=',
        SAP_url__c='https://biotechcrm--biotechdev.sandbox.my.salesforce-sites.com/SAPKycteammembervf?id=',
        Admin_url__c='https://biotechcrm--biotechdev.sandbox.my.salesforce-sites.com/adminkycapproval?id=',
        Thank_you_url__c='https://biotechcrm--biotechdev.sandbox.my.salesforce-sites.com/thankyoupage',
        ZSM_url__c='https://biotechcrm--biotechdev.sandbox.my.salesforce-sites.com/ZSMapprovalvfpage?id='
    );
    insert customSettingRecord;

    // Create a record for SAP code PDF
    New_Customer_SAP_Code_PDF__c sapCodePDF = new New_Customer_SAP_Code_PDF__c(
        Name = 'INDIA',
        Company_Code__c = '1000',
        Sales_Organization__c = '2000',
        Distribution_Channel__c = '10',
        Division__c = '00',
        Customer_Account_Group__c = 'Z001',
        Customer_classification__c = '1',
        Industry_key__c = 'M1',
        Industry_Code_1__c = '11',
        Terms_of_Payment_Key__c = 'ZNET30',
        Customer_group__c = '01',
        Currency__c = 'INR',
        Delivery_Priority__c = '02',
        Delivering_Plant_Own_or_External__c = '1000',
        Account_assignment_group_for_this_custom__c = 'Z002'
    );
    insert sapCodePDF;
    System.debug('SAP Code PDF Record Created: ' + sapCodePDF);

    // Create a Lead and associate with the test user
    Lead__c ld = new Lead__c(
        Name = 'Test Lead',
        First_Name__c = 'test',
        Last_Name__c = 'singh',
        Email__c = 'testlead@example.com',
        Billing_Street__c = '123 Test Street',
        Billing_City__c = 'Test City',
        Country__c = 'India',
        Company__c = 'Gwalior',
        Sales_district__c = 'D026',
        Sales_Office__c = '1022',
        Billing_state__c = 'Test State',
        Mobile__c = '12345673425',
        Name_1__c = 'Test Name 1',
        Name_2__c = 'Test Name 2',
        Street_3__c = 'Street 3',
        Street_4__c = 'Street 4',
        City_postal_code__c = '123456',
        SAP_City__c = 'SAP City',
        Country_Key__c = 'IN',
        Region_State_Province_County__c = 'Test Region',
        First_telephone_no_dialling_code__c = '91',
        First_Mobile_Telephone_No_Dialing__c = '91',
        First_fax_no_dialling_code_number__c = '91',
        E_Mail_Address__c = 'leademail@example.com',
        Product__c = 'BIO BLADE',
        RSM__c = testUser.Id, // Lookup to User
        RSM_Approve__c = true,
        RSM_Not_Approve__c = false,
        ZSM__c = testUser.Id, // Lookup to User
        GM_NSM__c = testUser.Id,
        User__c=testuser.Id,// Lookup to User
        Admin_Approve__c=true,
        //SAP_Code__c =  '566787',
        Admin_Not_Approve__c=false,
        Plant__c='test'
    );
    insert ld;
         ld = [SELECT Id,Name,Mobile__c,RSM_Email__c,RSM_approval_count__c,SAP_Code__c,RSM_Comments__c,GM_NSM__r.Email,User__c,User__r.Email,GM_NSM__c,country__c,Company__c,Product__c,Email__c,Billing_City__c,Billing_Street__c,Billing_country__c,Billing_state__c,Billing_code__c,Owner.Name,RSM_Approve__c,ZSM__c,ZSM__r.Email, RSM_Not_Approve__c,RSM__r.Email,Admin_Approve__c,Admin_Not_Approve__c FROM lead__c LIMIT 1];
       string leadid  = ld.id;
        
       
        
        PageReference pageRef = Page.RSMkycApproval; 
        pageRef.getParameters().put('id', ld.Id);
        Test.setCurrentPage(pageRef);
        
        // Step 2: Mock the VF Page Context
        Test.setCurrentPage(Page.LeadInformationPdf);
        ApexPages.currentPage().getParameters().put('id', ld.Id);

        // Step 3: Simulate PDF Blob
        Blob mockPDF = Blob.valueOf('Mock PDF Content');

        // Step 4: Simulate ContentVersion creation
        ContentVersion cv = new ContentVersion(
            Title = 'test' + ld.Id + '.pdf',
            PathOnClient = 'Lead_' + ld.Id + '.pdf',
            VersionData = mockPDF,
            IsMajorVersion = true
        );
        insert cv;

        // Query the ContentVersion to verify it was created
        ContentVersion insertedCV = [
            SELECT Id, ContentDocumentId, Title
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];
        System.assertNotEquals(null, insertedCV, 'ContentVersion should have been created.');

        // Step 5: Simulate ContentDocumentLink creation
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = insertedCV.ContentDocumentId,
            LinkedEntityId = ld.Id,
            ShareType = 'V'
        );
        insert cdl;

        // Query the ContentDocumentLink to verify it was created
        List<ContentDocumentLink> documentLinks = [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :ld.Id
        ];
        System.assertEquals(1, documentLinks.size(), 'ContentDocumentLink should have been created.');

        // Step 6: Verify logic for email attachments
        List<Messaging.EmailFileAttachment> emailAttachments = new List<Messaging.EmailFileAttachment>();
        Set<Id> docIdSet = new Set<Id>();
        Map<Id, Blob> contentMap = new Map<Id, Blob>();

        for (ContentDocumentLink docLink : documentLinks) {
            docIdSet.add(docLink.ContentDocumentId);
        }

        if (!docIdSet.isEmpty()) {
            List<ContentVersion> cvList = [
                SELECT VersionData, ContentDocumentId
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIdSet
            ];
            for (ContentVersion conVers : cvList) {
                contentMap.put(conVers.ContentDocumentId, conVers.VersionData);
            }
        }

        for (ContentDocumentLink docLink : documentLinks) {
            Messaging.EmailFileAttachment emailAttachment = new Messaging.EmailFileAttachment();
            emailAttachment.setFileName('Test_Document.pdf');

            if (contentMap.containsKey(docLink.ContentDocumentId)) {
                emailAttachment.setBody(contentMap.get(docLink.ContentDocumentId));
            }
            emailAttachments.add(emailAttachment);
        }

       
        
        ApprovalController controller = new ApprovalController(); 
        ApprovalController.RSMKYCapproval('Approve', 'comment',ld.Id, 'RSM');
        ApprovalController.RSMKYCapproval('Reject', 'comment',ld.id, 'RSM');
        ApprovalController.fetchCustomSetting('RSM');
        ApprovalController.fetchCustomSetting('Document');
        
        ApprovalController.ZSMkycapproval('Approve', 'comment', ld.Id, 'ZSM');
         ApprovalController.ZSMkycapproval('Reject', 'comment', leadid, 'ZSM');
        ApprovalController.fetchCustomSetting('ZSM');
        ApprovalController.fetchCustomSetting('Document');
        
        ApprovalController.GM_NSMkyccommenmethod('Approve', 'GM_NSMcomment',  ld.Id, 'GM_NSM');
        ApprovalController.GM_NSMkyccommenmethod('Reject', 'GM_NSMcomment',  leadid, 'GM_NSM');
        ApprovalController.fetchCustomSetting('GM NSM');
        ApprovalController.fetchCustomSetting('Document');
        
        ApprovalController.Adminkycmethod('Approve', 'Admincomment', ld.Id, 'Admin');
        ApprovalController.Adminkycmethod('Reject', 'Admincomment', leadid, 'Admin');
        ApprovalController.fetchCustomSetting('Admin');
        ApprovalController.fetchCustomSetting('Document');
        
        ApprovalController.JSMSAPcodemethod('data', 'SAPcode', ld.Id, 'JSM');
        ApprovalController.fetchCustomSetting('SAP');
        ApprovalController.fetchCustomSetting('Document');
         
        controller.getRecordId();
         ApprovalController.logPageVisit();
        ApprovalController.getRecordUrl(ld.Id);
        ApprovalController.generateBranchMail(ld);
        ApprovalController.generateBranchSAPMail(ld);
        
    }
    
    @isTest
    public static void test1(){
        Lead__c ld = [SELECT Id,Name,Mobile__c,RSM_approval_count__c,SAP_Code__c,RSM_Email__c,RSM_Comments__c,GM_NSM__r.Email,User__c,User__r.Email,GM_NSM__c,country__c,Company__c,Product__c,Email__c,Billing_City__c,Billing_Street__c,Billing_country__c,Billing_state__c,Billing_code__c,Owner.Name,RSM_Approve__c,ZSM__c,ZSM__r.Email, RSM_Not_Approve__c,RSM__r.Email,Admin_Approve__c,Admin_Not_Approve__c FROM lead__c LIMIT 1];
        string leadid  = ld.id;
        
        
        
        
        PageReference pageRef = Page.RSMkycApproval; 
        pageRef.getParameters().put('id', ld.Id);
        Test.setCurrentPage(pageRef);
        
         
        // Step 3: Invoke the method
        //Blob pdfBlob = PDFGenerator.generatePDF(testAccount.Id);
        
        ApprovalController controller = new ApprovalController(); 
        ApprovalController.RSMKYCapproval('Approve', 'comment',leadid, 'RSM');
        ApprovalController.RSMKYCapproval('Reject', 'comment',leadid, 'RSM');
        ApprovalController.fetchCustomSetting('RSM');
        ApprovalController.fetchCustomSetting('Document');
        
       // ApprovalController.ZSMkycapproval('Approve', 'comment', leadid, 'ZSM');
         ApprovalController.ZSMkycapproval('Reject', 'comment', leadid, 'ZSM');
        ApprovalController.fetchCustomSetting('ZSM');
        ApprovalController.fetchCustomSetting('Document');
        
        //ApprovalController.GM_NSMkyccommenmethod('Approve', 'GM_NSMcomment',  leadid, 'GM_NSM');
        ApprovalController.GM_NSMkyccommenmethod('Reject', 'GM_NSMcomment',  leadid, 'GM_NSM');
        ApprovalController.fetchCustomSetting('GM NSM');
        ApprovalController.fetchCustomSetting('Document');
        
        //ApprovalController.Adminkycmethod('Approve', 'Admincomment', leadid, 'Admin');
         ApprovalController.Adminkycmethod('Reject', 'Admincomment', leadid, 'Admin');
        ApprovalController.fetchCustomSetting('Admin');
        ApprovalController.fetchCustomSetting('Document');
        
        ApprovalController.JSMSAPcodemethod('', '576878', leadid, 'JSM');
        ApprovalController.fetchCustomSetting('SAP');
        ApprovalController.fetchCustomSetting('Document');
         
        controller.getRecordId();
        ApprovalController.logPageVisit();
        ApprovalController.getRecordUrl(leadid);
        ApprovalController.generateBranchMail(ld);
        ApprovalController.generateBranchSAPMail(ld);
        
    }
    
    
}
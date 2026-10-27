@isTest
public class SubmitForApprovalControllerTest {
    
    @isTest
    public static void testMethod1(){
        Test.startTest();
        CIty__c region = new CIty__c();
        region.country_key__c = 'IN';
        region.Name = 'MAHARASHTRA';
        region.Region_Code__c = 'IN-MH';
        insert region;
        Account acc = new Account();
        acc.RecordTypeId               = Constants.ACCOUNT_DOM_DOCTOR_RECORDTYPEID;
        acc.Name                       = 'Test Account';
        acc.Commercial_Account_Name__c = 'Commercial Test Acc';
        acc.Account_Type__c            = 'Commercial';
        acc.E_Mail__c	               = 'testacc@test.com';
        acc.Phone                      = '8787678678';
        acc.Medical_Registration_No__c = 'MED1234567898';
        acc.isAccHavingERL__c          = false;
        acc.region__c                  = region.Id;
        acc.City_postal_code__c        = '400001';
        acc.BillingPostalCode        = '400003';
        insert acc;
        Account acc3 = new Account();
        acc3.RecordTypeId               = Constants.ACCOUNT_DOM_DOCTOR_RECORDTYPEID;
        acc3.Name                       = 'Test Account3';
        acc3.Commercial_Account_Name__c = 'Commercial Test Acc3';
        acc3.Account_Type__c            = 'Commercial';
        acc3.E_Mail__c	               = 'testacc3@test.com';
        acc3.Phone                      = '8787678676';
        acc3.Medical_Registration_No__c = 'MED1234567898';
        acc3.GSTIN_No__c                = 'GSTIN12345671';
        acc3.Drug_License_No__c         = 'MEDIC12345612';
        acc3.isAccHavingERL__c          = false;
        acc3.region__c                  = region.Id;
        acc3.City_postal_code__c        = '400001';
        acc3.BillingPostalCode          = '400003';
        insert acc3;
        
        Attachment attach=new Attachment();   	
        attach.Name='ERL';
        Blob bodyBlob=Blob.valueOf('Unit Test Attachment Body');
        attach.body=bodyBlob;
        attach.parentId=acc.id;
        insert attach;
        
        
        ContentVersion contentVersion = new ContentVersion(
            Title = 'ERL',
            PathOnClient = 'Penguins.jpg',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert contentVersion;    
        List<ContentDocument> documents = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument];
        
        //create ContentDocumentLink  record 
        ContentDocumentLink cdl = New ContentDocumentLink();
        cdl.LinkedEntityId = acc.id;
        
        cdl.ContentDocumentId = documents[0].Id;
        cdl.shareType = 'V';
        insert cdl;
        
        Customer_Evaluation__c ce = new Customer_Evaluation__c();
        ce.Account__c = acc.id;
        ce.Year__c = '2019';
        //ce.Customer_Evaluation_Rating__c = 'B';
        ce.Status__c = 'Approved';
        ce.No_of_Counselors__c = 50;
        ce.No_of_Doctors__c    = 20;
        insert ce; 
        
        
        SubmitForApprovalController.checkAccHasERLAttachmentAndCESRecord(acc.Id);
        SubmitForApprovalController.checkAccHasERLAttachmentAndCESRecord(acc3.Id);
        SubmitForApprovalController.setIsAccHavingERLFieldOnAccount(acc.Id);
        Account acc2 = new Account();
        acc2.RecordTypeId               = Constants.ACCOUNT_DOM_DISTRIBUTOR_RECORDTYPEID;
        acc2.Name                       = 'Test Account2';
        acc2.Commercial_Account_Name__c = 'Commercial Test Acc2';
        acc2.Account_Type__c            = 'Commercial';
        acc2.E_Mail__c	               = 'testacc2@test.com';
        acc2.Phone                      = '8787678679';
        acc2.Medical_Registration_No__c = 'MED1234567898';
        acc2.GSTIN_No__c                = 'GSTIN12345671';
        acc2.Drug_License_No__c         = 'MEDIC12345612';
        acc2.isAccHavingERL__c          = false;
        acc2.region__c                  = region.Id;
        acc2.City_postal_code__c        = '400001';
        acc2.BillingPostalCode        = '400003';
        insert acc2;
        
        Attachment attach2=new Attachment();   	
        attach2.Name='ERL';
        Blob bodyBlob2=Blob.valueOf('Unit Test Attachment Body');
        attach2.body=bodyBlob2;
        attach2.parentId=acc2.id;
        insert attach2;
        Customer_Evaluation__c ce2 = new Customer_Evaluation__c();
        ce2.Account__c = acc2.id;
        ce2.Year__c = '2019';
        //ce.Customer_Evaluation_Rating__c = 'B';
        ce2.Status__c = 'Approved';
        ce2.No_of_Counselors__c = 70;
        ce2.No_of_Doctors__c    = 10;
        insert ce2; 
        
        SubmitForApprovalController.checkAccHasERLAttachmentAndCESRecord(acc2.Id);
        Account acc5 = new Account();
        acc5.RecordTypeId               = Constants.ACCOUNT_DOM_DISTRIBUTOR_RECORDTYPEID;
        acc5.Name                       = 'Test Account5';
        acc5.Commercial_Account_Name__c = 'Commercial Test Acc5';
        acc5.Account_Type__c            = 'Commercial';
        acc5.E_Mail__c	               = 'testacc5@test.com';
        acc5.Phone                      = '8787678667';
        acc5.Medical_Registration_No__c = 'MED1234567898';
        acc5.GSTIN_No__c                = 'GSTIN12345671';
        acc5.Drug_License_No__c         = 'MEDIC12345612';
        acc5.isAccHavingERL__c          = false;
        acc5.region__c                  = region.Id;
        acc5.City_postal_code__c        = '400001';
        acc5.BillingPostalCode        = '400003';
        insert acc5;
        SubmitForApprovalController.checkAccHasERLAttachmentAndCESRecord(acc5.Id);
        Test.stopTest();
    }
    
}
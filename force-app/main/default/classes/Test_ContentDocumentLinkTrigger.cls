@isTest
public class Test_ContentDocumentLinkTrigger {
    static testmethod void  validateContentDocumentLink()
    {
        //Create Document Parent Record        
        CIty__c objcity = new CIty__c();
        objcity.Name = 'Delhi';
        objcity.Region_Code__c = '009';
        objcity.country_key__c = 'IN';
        insert objcity;
        
        Id recTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Distributor').getRecordTypeId();
        Account objAccount = new Account();
        objAccount.RecordTypeId = recTypeId;
        objAccount.Name = 'Test Account';
        objAccount.region__c = objcity.Id;
        objAccount.Drug_License_No__c = 'Test';
        objAccount.First_mobile_telephone_no__c = 'Test';
        objAccount.Country_Key__c = objcity.country_key__c;
        objAccount.E_Mail__c = 'test@gmail.com';
        objAccount.Contact_Person__c = 'Test';
        objAccount.Commercial_Account_Name__c = 'Test';
        objAccount.Phone = 'Test';
        objAccount.SAP_Code__c = '909';
        objAccount.Account_Type__c = 'Sample';
        objAccount.Payment_Collection_Cycle__c = 90;
        objAccount.GSTIN_No__c = 'Test';
        objAccount.CurrencyIsoCode ='INR';
        objAccount.BillingCity = 'test';
        objAccount.BillingCountry = 'test';
        objAccount.BillingState = 'test';
        objAccount.BillingStreet = 'test';
        objAccount.BillingPostalCode = 'test';
        insert objAccount;  
        
        //Create Document
        ContentVersion cv = new ContentVersion();
        cv.Title = 'Test Document';
        cv.PathOnClient = 'TestDocument.pdf';
        cv.VersionData = Blob.valueOf('Test Content');
        cv.IsMajorVersion = true;
        Insert cv;
        
        //Get Content Documents
        Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:cv.Id].ContentDocumentId;
        
        //Create ContentDocumentLink 
        ContentDocumentLink cdl = New ContentDocumentLink();
        cdl.LinkedEntityId = objAccount.Id;
        cdl.ContentDocumentId = conDocId;
        cdl.shareType = 'V';
        Insert cdl;
        
    }
}
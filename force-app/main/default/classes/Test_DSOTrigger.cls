@isTest
public class Test_DSOTrigger {
    
    public static testMethod void testDSO(){
        
        //Create RSM User
        String rsmUserName = 'dom_rsmuser' + DateTime.now().getTime() + '@testorg.com';
        Profile rsmp  = [SELECT Id FROM Profile WHERE Name = 'Domestic Sales'];
        UserRole rsmd = [SELECT Id,name FROM UserRole WHERE Name like 'RSM%' LIMIT 1];
        User rsmUser = new User(Alias = 'rsm_u', Email='dom_rsmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = rsmp.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=rsmUserName, UserRoleId=rsmd.Id, Division__c='I',Employee_Code__c='DOMRSM1234');                                
        insert rsmUser;
        system.runAs(rsmUser){
            //Create Region
            CIty__c objcity = new CIty__c();
            objcity.Name = 'Maharashtra';
            objcity.Region_Code__c = 'MH01';
            objcity.country_key__c = 'IN';
            insert objcity;
            
            //Create Account
            Id RecordTypeIdContact = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Distributor').getRecordTypeId();
            Account objAccount = new Account();
            objAccount.RecordTypeId = RecordTypeIdContact;
            objAccount.Name = 'Test';
            objAccount.Country_Key__c = 'IN';
            objAccount.Drug_License_No__c = 'Test';
            objAccount.First_mobile_telephone_no__c = 'Test';
            objAccount.E_Mail__c = 'test@gmail.com';
            objAccount.Contact_Person__c = 'Test';
            objAccount.Commercial_Account_Name__c = 'Test';
            objAccount.Phone = 'Test';
            objAccount.SAP_Code__c = '45612';
            objAccount.BillingStreet = 'Main road';
            objAccount.BillingCity = 'Pune';
            objAccount.BillingState = 'Maharashtra';
            objAccount.BillingPostalCode = '411008';
            objAccount.BillingCountry = 'India';
            objAccount.Account_Type__c = 'Sample';
            objAccount.GSTIN_No__c = 'Test';
            objAccount.region__c = objcity.id;
            insert objAccount;
            
            //Create User Region Association
            User_Region_Association__c userRegionTest = new User_Region_Association__c(); 
            userRegionTest.User__c = rsmUser.id; 
            userRegionTest.Region__c = objcity.id;
            insert userRegionTest;
            
            //Create DSO
            DSO__c dso = new DSO__c();
            dso.Customer_Code__c = '45612';
            dso.Customer_Name__c = objAccount.id;
            dso.OwnerId = userRegionTest.User__c;
            insert dso;
        }
    }
}
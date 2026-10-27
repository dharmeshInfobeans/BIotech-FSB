@isTest
private class Test_DealerNotification_Trigger {
    static testMethod void runTestCasesForDealerNotification(){
        Id intAdminProfileId = [SELECT Id FROM Profile WHERE Name = 'Admin_Int'].Id;
        
        User internationalAdmin = new User(
            ProfileId = intAdminProfileId,
            LastName = 'sse user',
            Email = 'test1@gmail.com',
            Username = 'sseUser@gmail.com' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            Employee_Code__c = '99937',
            Division__c = 'I',
            User_Type__c = 'International',
            Date_of_Joining__c = System.today(),
            isActive = true
        );
        insert internationalAdmin;
        
        User partnerUser = new User(
            ProfileId = intAdminProfileId,
            LastName = 'sse user',
            Email = 'test@gmail.com',
            Username = 'sseUser@gmail.com' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            Employee_Code__c = '99937',
            Division__c = 'I',
            User_Type__c = 'Domestic',
            Date_of_Joining__c = System.today(),
            isActive = true
        );
        insert partnerUser;
        
        User partnerUser1 = new User(
            ProfileId = intAdminProfileId,
            LastName = 'sse user',
            Email = 'test11@gmail.com',
            Username = 'sseUser@gmail.com' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            Employee_Code__c = '99937',
            Division__c = 'I',
            User_Type__c = 'Domestic',
            Date_of_Joining__c = System.today(),
            isActive = true
        );
        insert partnerUser1;
        
        System.runAs(internationalAdmin){
            CIty__c objcity = new CIty__c();
            objcity.Name = 'Delhi';
            objcity.Region_Code__c = '757';
            objcity.country_key__c = 'IN';
            insert objcity;
            
            Id recTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Dealer Portal').getRecordTypeId();
            Account objAccount = new Account();
            objAccount.RecordTypeId = recTypeId;
            objAccount.Name = 'Adrialine D.O.O.';
            objAccount.region__c = objCity.Id;
            objAccount.Drug_License_No__c = 'Test';
            objAccount.First_mobile_telephone_no__c = 'Test';
            objAccount.Country_Key__c = objCity.country_key__c;
            objAccount.E_Mail__c = 'test@gmail.com';
            objAccount.Contact_Person__c = 'Test';
            objAccount.Commercial_Account_Name__c = 'Test';
            objAccount.Phone = 'Test';
            objAccount.SAP_Code__c = '1000369';
            objAccount.Account_Type__c = 'Sample';
            objAccount.Payment_Collection_Cycle__c = 90;
            objAccount.GSTIN_No__c = 'Test';
            objAccount.CurrencyIsoCode ='INR';
            insert objAccount;
            
            Dealer_Notification__c notificaton = new Dealer_Notification__c();
            notificaton.Notification_To__c = 'Specific Dealer';
            notificaton.Dealers__c = '1000369';
            notificaton.message__c = 'Test Message';
            insert notificaton;
            
            Dealer_Notification__c notificaton1 = new Dealer_Notification__c();
            notificaton1.Notification_To__c = 'All Dealers';
            notificaton1.message__c = 'Test Message';
            insert notificaton1;
            
            objAccount.E_Mail__c = 'test11@gmail.com';
            update objAccount;
        }
    }
}
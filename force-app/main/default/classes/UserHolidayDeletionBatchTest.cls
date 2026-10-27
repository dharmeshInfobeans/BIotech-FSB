@isTest
public class UserHolidayDeletionBatchTest {
    @isTest
    public static void test(){
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'testuser',
            Email = 'Mahek1@gmail.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            State__c = 'GUJARAT',
            Country__c = 'INDIA',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'Mahek1@examailple.com'
        );
        insert testUser;
         Holiday__c holi = new Holiday__c( 
            State__c = 'BIHAR',
            Country__c = 'RUSSIA'
        );
        insert holi;
        
        User_Holidays__c userHoli = new User_Holidays__c(
            User__c = testUser.Id,
            Holiday__c = holi.Id
        );
        insert userHoli;
        
        User testUser2 = new User(
            Alias = 'testuser',
            Email = 'Mahek2@gmail.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            State__c = 'GUJARAT',
            Country__c = 'INDIA',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'Mahek2@examailple.com'
        );
        insert testUser2;
         
        
        Holiday__c holi2 = new Holiday__c(
            State__c = 'BIHAR',
            Country__c = 'INDIA'
        );
        insert holi2;
        
        User_Holidays__c userHoli2 = new User_Holidays__c(
            User__c = testUser2.Id,
            Holiday__c = holi2.Id
        );
        insert userHoli2;
        
            User testUser3 = new User(
            Alias = 'testuser',
            Email = 'Mahek3@gmail.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            State__c = 'GUJARAT',
            Country__c = 'INDIA',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'Mahek3@examailple.com'
        );
        insert testUser3;
         
        
        Holiday__c holi3 = new Holiday__c(
            State__c = 'GUJARAT',
            Country__c = 'INDIA'
        );
        insert holi3;
        
        User_Holidays__c userHoli3 = new User_Holidays__c(
            User__c = testUser2.Id,
            Holiday__c = holi2.Id
        );
        insert userHoli3;
        UserHolidayDeletionScheduler b = new UserHolidayDeletionScheduler();
        String cronExp = '0 0 0 * * ?';

        
        Test.startTest();
        UserHolidayDeletionBatch batch1 = new UserHolidayDeletionBatch();
        
        String jobId = System.schedule('Test My Scheduled Job', cronExp, b);
        Database.executeBatch(batch1);
        Test.stopTest();
    }
    
}
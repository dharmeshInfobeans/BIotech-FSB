@isTest
public class CreateHolidayShareRecordsTest {
    
    @isTest
    public static void CreateHolidaySharingExecteMethod(){
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Admin_Dom' LIMIT 1];
        User userRecord = new User(
            LastName = 'TestUser',
            Alias = 'Testing',
            Email = 'test.user+' + System.currentTimeMillis() + '@example.com',
            Username = 'test.user+' + System.currentTimeMillis() + '@biotech.com',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Country__c = 'INDIA',
            State__c = 'GUJARAT',
            isActive=true
        );
        
        insert userRecord;
        
		 Holiday__c holidayRecord = new Holiday__c(
            Date__c = Date.newInstance(2025, 12, 31),
            Country__c = 'INDIA',
            State__c = 'GUJARAT'
        );
        insert holidayRecord;    
        
        Database.executeBatch(new CreateHolidayShareRecords());
    }

}
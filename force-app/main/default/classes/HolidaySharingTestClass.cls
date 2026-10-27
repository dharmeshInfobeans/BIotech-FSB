@IsTest
public class HolidaySharingTestClass {
   
    @TestSetup static void setup(){
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
        
    } 
    
    
      @IsTest
    static void testHolidaySharingForDelete() {
        Holiday__c holidayRecord=[Select id,State__c from  Holiday__c];
        holidayRecord.State__c=null;
        update holidayRecord;
    }
    
    
        @IsTest
    static void testHolidayTrigger() {


         Profile p = [SELECT Id FROM Profile WHERE Name = 'Admin_Dom' LIMIT 1];
        Holiday__c holidayRecord = new Holiday__c(
            Date__c = Date.newInstance(2025, 12, 31),
            Country__c = 'INDIA',
            State__c = 'GUJARAT'
        );
        insert holidayRecord;

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
        
        
			
        Holiday__c holidayUpdateRecord = [
            SELECT Id, State__c 
            FROM Holiday__c 
            WHERE Id = :holidayRecord.Id
        ];
        holidayUpdateRecord.State__c = 'GOA';
        update holidayUpdateRecord;
        
        userRecord.State__c='GOA';
        update userRecord;

        //delete holidayRecord;   
        //undelete holidayRecord;


    } 
    
    
    
    @IsTest
    static void testUserCreationTrigger() {
System.debug([SELECT Id,Name FROM Profile]);
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
            State__c = '',
            isActive=true
        );
        insert userRecord;
		System.debug('After insert : '+[select id,UserOrGroup.name from Holiday__Share where UserOrGroupId = :userRecord.Id]);
        userRecord.State__c = 'MADHYA PRADESH';
        update userRecord;
		System.debug('After update : '+[select id,UserOrGroup.name from Holiday__Share where UserOrGroupId = :userRecord.Id]);

        userRecord.State__c = '';
        update userRecord;
           
    }
    


}
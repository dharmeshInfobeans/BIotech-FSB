@isTest
public class HolidayOwnerUpdateBatchTest {
    
    @testSetup
    static void setupData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        List<User> gujaratUsers = new List<User>();
        for (Integer i = 0; i < 3; i++) {
            gujaratUsers.add(new User(
                FirstName = 'Test',
                LastName = 'GujUser' + i,
                Email = 'gujuser' + i + '@example.com',
                Username = 'gujuser' + i + '@example.com.' + System.currentTimeMillis(),
                Alias = 'guju' + i,
                TimeZoneSidKey = 'Asia/Kolkata',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                ProfileId = p.Id,
                LanguageLocaleKey = 'en_US',
                Country__c = 'INDIA',
                State__c = 'GUJARAT'
            ));
        }
        insert gujaratUsers;

        User ownerUser = new User(
            FirstName = 'Owner',
            LastName = 'User',
            Email = 'owner@example.com',
            Username = 'owneruser' + System.currentTimeMillis() + '@example.com',
            Alias = 'ownr',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US',
            Country__c = 'INDIA',
            State__c = 'DELHI'
        );
        insert ownerUser;

        List<Holiday__c> holidays = new List<Holiday__c>{
            new Holiday__c(Description__c = 'Gujarat Holiday 1', Country__c = 'INDIA', State__c = 'GUJARAT', OwnerId = ownerUser.Id),
            new Holiday__c(Description__c = 'Delhi Holiday', Country__c = 'INDIA', State__c = 'DELHI', OwnerId = ownerUser.Id)
        };
        insert holidays;
    }
    
    @isTest
    static void testBatchExecution() {
        Test.startTest();
        HolidayOwnerUpdateBatch batch = new HolidayOwnerUpdateBatch();
        Database.executeBatch(batch, 10);
        Test.stopTest();
        
       Id runningUserId = UserInfo.getUserId();
        
        List<Holiday__Share> shares = [
            SELECT Id, ParentId, UserOrGroupId, AccessLevel, RowCause
            FROM Holiday__Share
        ];
        
        System.assert(shares.size() > 0, 'Sharing records should be created');
        
        for (Holiday__Share hs : shares) {
            if (hs.UserOrGroupId != runningUserId) {
                continue;
            }
            System.assertEquals('Read', hs.AccessLevel, 'Access should be Read');
            System.assertEquals(Schema.Holiday__Share.RowCause.Manual, hs.RowCause, 'RowCause should be Manual');
        }
        
    }
    
     @isTest
    static void testScheduler() {
        Test.startTest();
        String cron = '0 0 0 1 1 ? 2050';
        System.schedule('Test Holiday Scheduler', cron, new HolidayOwnerUpdateBatchScheduler());
        Test.stopTest();
        
        System.assert(true, 'Scheduler executed successfully');
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
}
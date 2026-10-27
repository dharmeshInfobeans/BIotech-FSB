@IsTest
public class beatPlanCustomReport_Test {
    
@IsTest
private static void testBeatPlan1(){
    // Create test Account and Attachment
    Account acc = new Account(Name = 'Test Account');
    insert acc;
    Attachment attachment = new Attachment(
        ParentId = acc.Id,
        Name = 'biotech_logo-1.png',
        Body = Blob.valueOf('Test Data')
    );
    insert attachment;

    // Create test User
    Profile profile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
    User testUser = new User(
        FirstName = 'David',
        LastName = 'Liu',
        Email = 'dvdkliu+sfdc99@gmail.com2333',
        Username = 'sfdc-dreamer@gmail.com6666',
        Alias = 'fatty',
        ProfileId = profile.Id,
        TimeZoneSidKey = 'America/Denver',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        Employee_Code__c = '7653',
        region__c = 'Domestic',
        Country__c = 'INDIA',
        IsActive = true,
        corporate_function__c = false
    );
    insert testUser;

    // Create test Beat Plan
    Beat_Plan__c beatPlan = new Beat_Plan__c(
        Event_Type__c = 'H',
        ownerId = testUser.Id,
        Assigned_To__c = testUser.Id,
        Beat_Date__c = Date.today()
    );
    insert beatPlan;

    // Call methods and assertions
    Test.startTest();
    beatPlanCustomReport.getfetchBeatPlan(testUser.Username);
    beatPlanCustomReport.getSearchedBeatPlan('2019','Jan','Domestic', Date.today(), Date.today().addDays(7), false, '{"Country": "INDIA"}', testUser.Username);
    beatPlanCustomReport.fetchUser();
    beatPlanCustomReport.fetchUser();
        beatPlanCustomReport.getNumMonth();
        beatPlanCustomReport.getNumYr();
        beatPlanCustomReport.getNumOfRegion();
        beatPlanCustomReport.getNumerMonth();
        beatPlanCustomReport.getPicklistData();
        beatPlanCustomReport.getStateDatas('INDIA');
        
    Test.stopTest();

}

}
@istest
public class CampaignTeamMemberSharingTest {
    @istest
    private static void testData() {
        
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator']; 
        User u = new User(Alias = 'Bhanvi', Email='BhaveshUser@outlook.com', 
                          EmailEncodingKey='UTF-8', LastName='Bhavesh', LanguageLocaleKey='en_US', 
                          LocaleSidKey='en_US', ProfileId = p.Id, 
                          TimeZoneSidKey='America/Los_Angeles', UserName='BhaveshUser122@gmail.com');
        insert u;
        
        Target__c tar=new Target__c();
        tar.Date__c=system.today();
        insert tar;
        
        Campaign__c cam=new Campaign__c();
        cam.Target__c=tar.id;
        cam.Name='Test';
        insert cam;
        
        Campaign_Team_Member__c  cmpTmb=new Campaign_Team_Member__c();
        cmpTmb.Role__c='Sub Executer';
        cmpTmb.User__c=u.id;
        cmpTmb.Campaigns__c=cam.Id;
        insert cmpTmb;
        
    }
}
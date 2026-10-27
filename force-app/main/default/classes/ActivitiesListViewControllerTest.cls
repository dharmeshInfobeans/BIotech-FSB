@isTest
public class ActivitiesListViewControllerTest {
    
    @TestSetup
    static void makeData(){
        Account acc=new Account(name='Account', 
                                Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',Account_Locked__c=false,Status__c='Activated',GSTIN_No__c='GSTIN2343423456');
        insert acc;
        
        Lead lead1=new Lead(Lastname='Lead test', 
                            Status='New', Company='abcd');
        insert lead1;
        
        Profile profileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        User userToCreate = new User();
       
       // Do you recognize these fields?
       userToCreate.FirstName = 'David';
       userToCreate.LastName  = 'Liu';
       userToCreate.Email     = 'dvdkliu+sfdc99@gmail.com';
       userToCreate.Username  = 'sfdc-dreamer@gmail.com1';
       userToCreate.Alias     = 'fatty';
       userToCreate.ProfileId = profileId.id;

       // Don't worry about these
       userToCreate.TimeZoneSidKey    = 'America/Denver';
       userToCreate.LocaleSidKey      = 'en_US';
       userToCreate.EmailEncodingKey  = 'UTF-8';
       userToCreate.LanguageLocaleKey = 'en_US';
       userToCreate.User_Type__c = 'Domestic';
       userToCreate.IsActive = true;
       
       insert userToCreate; 
        Beat_Plan__c beatObj = new Beat_Plan__c();
        beatObj.Event_Type__c = 'H';
        beatObj.ownerId = userToCreate.id;
        beatObj.Beat_Date__c = system.today();
        insert beatObj;
        
        list<string> eventId = new list<string>();
        event obj1 = new event();
        obj1.subject = 'Leave';   
        obj1.startDateTime = system.now();
        obj1.endDateTime = System.now().addDays(1);
        obj1.Status__c = 'Approved';
        obj1.whoId=lead1.id;
        obj1.Beat_plan__c = beatObj.id;
        insert obj1;
        eventId.add(obj1.id);
        
        Account_Team__c scc_team=new Account_Team__c(Account__c=acc.Id,Team_Role__c = 'Div 1');
        insert scc_team;
        ActivitiesListViewController.getBeatPlan(eventId);
        List<Event> test_events= ActivitiesListViewController.getEvents();
        ActivitiesListViewController.updateEvents(test_events);
        
    }
    public static testmethod void methodName(){
        Account acc=new Account(name='Account', 
                                Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',Account_Locked__c=false,Status__c='Activated',GSTIN_No__c='GSTIN2343423456');
        insert acc;
        
        Lead lead1=new Lead(Lastname='Lead test', 
                            Status='New', Company='abcd');
        insert lead1;
        Profile profileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        User userToCreate = new User();
       
       // Do you recognize these fields?
       userToCreate.FirstName = 'David';
       userToCreate.LastName  = 'Liu';
       userToCreate.Email     = 'dvdkliu+sfdc99@gmail.com55';
       userToCreate.Username  = 'sfdc-dreamer@gmail.com1555';
       userToCreate.Alias     = 'fatty';
       userToCreate.ProfileId = profileId.id;

       // Don't worry about these
       userToCreate.TimeZoneSidKey    = 'America/Denver';
       userToCreate.LocaleSidKey      = 'en_US';
       userToCreate.EmailEncodingKey  = 'UTF-8';
       userToCreate.LanguageLocaleKey = 'en_US';
       userToCreate.User_Type__c = 'Domestic';
       userToCreate.IsActive = true;
       
       insert userToCreate; 
        Beat_Plan__c beatObj = new Beat_Plan__c();
        beatObj.Event_Type__c = 'P';
        beatObj.ownerId = userToCreate.id;
        beatObj.Beat_Date__c = system.today();
        insert beatObj;
        
        list<string> eventId = new list<string>();
        event obj1 = new event();
        obj1.subject = 'Test';   
        obj1.startDateTime = system.now();
        obj1.endDateTime = System.now().addDays(1);
        obj1.Status__c = 'Approved';
        obj1.whoId=lead1.id;
        obj1.Beat_plan__c = beatObj.id;
        insert obj1;
        eventId.add(obj1.id);
        
        Account_Team__c scc_team=new Account_Team__c(Account__c=acc.Id,Team_Role__c = 'Div 1');
        insert scc_team;
        ActivitiesListViewController.getBeatPlan(eventId);
        
        List<Event> test_events= ActivitiesListViewController.getEvents();
        ActivitiesListViewController.updateEvents(test_events);
    }
    public static testmethod void methodName2(){
        Account acc=new Account(name='Account', 
                                Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',Account_Locked__c=false,Status__c='Activated',GSTIN_No__c='GSTIN2343423456');
        insert acc;
        
        Lead lead1=new Lead(Lastname='Lead test', 
                            Status='New', Company='abcd');
        insert lead1;
        
        Profile profileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User userToCreate = new User();
       
       // Do you recognize these fields?
       userToCreate.FirstName = 'David';
       userToCreate.LastName  = 'Liu';
       userToCreate.Email     = 'dvdkliu+sfdc99@gmail.com11';
       userToCreate.Username  = 'sfdc-dreamer@gmail.com1555';
       userToCreate.Alias     = 'fatty';
       userToCreate.ProfileId = profileId.id;

       // Don't worry about these
       userToCreate.TimeZoneSidKey    = 'America/Denver';
       userToCreate.LocaleSidKey      = 'en_US';
       userToCreate.EmailEncodingKey  = 'UTF-8';
       userToCreate.LanguageLocaleKey = 'en_US';
       userToCreate.User_Type__c = 'Domestic';
       userToCreate.IsActive = true;
       
       insert userToCreate; 
        Beat_Plan__c beatObj = new Beat_Plan__c();
        beatObj.Event_Type__c = 'H';
        beatObj.ownerId = userToCreate.id;
        beatObj.Beat_Date__c = system.today();
        insert beatObj;
        
        list<string> eventId = new list<string>();
        event obj1 = new event();
        obj1.subject = 'Holiday';   
        obj1.startDateTime = system.now();
        obj1.endDateTime = System.now().addDays(1);
        obj1.Status__c = 'Approved';
        obj1.whoId=lead1.id;
        obj1.Beat_plan__c = beatObj.id;
        insert obj1;
        eventId.add(obj1.id);
        
        Account_Team__c scc_team=new Account_Team__c(Account__c=acc.Id,Team_Role__c = 'Div 1');
        insert scc_team;
        ActivitiesListViewController.getBeatPlan(eventId);
        
        List<Event> test_events= ActivitiesListViewController.getEvents();
        ActivitiesListViewController.updateEvents(test_events);
    }
}
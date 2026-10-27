@isTest
public class AccountTeamHandlerTest {
    @TestSetup
    static void makeData(){
        
        Test.startTest();
             
        String zsmUserName = 'dom_zsmuser' + DateTime.now().getTime() + '@testorg.com';
        Profile zsmp = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
        UserRole zsmd =[SELECT Id,name FROM UserRole WHERE (Name like'%ZSM%') AND PortalType!='Partner' LIMIT 1];
        User zsmUser = new User(Alias = 'zsm_u', Email='dom_zsmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = zsmp.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=zsmUserName,UserRoleId=zsmd.Id,Division__c='I;II',Employee_Code__c='DOMZSM1234');
         insert  zsmUser;                               
        
         String rsmUserName = 'dom_rsmuser' + DateTime.now().getTime() + '@testorg.com';
         Profile rsmp  = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
        // Profile rsmp  = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        UserRole rsmd = [SELECT Id,name,PortalRole,PortalType FROM UserRole WHERE (Name like'%RSM%' OR Name like '%SS_D%') AND PortalType!='Partner' LIMIT 1];
        User rsmUser = new User(Alias = 'rsm_u', Email='dom_rsmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = rsmp.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=rsmUserName,UserRoleId=rsmd.Id,Division__c='I;II',Employee_Code__c='DOMRSM1234', ManagerId=zsmUser.Id);                                
        insert rsmUser;
        
        String dmUserName = 'dom_dmuser' + DateTime.now().getTime() + '@testorg.com';
        Profile dmp  = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
	    //Profile dmp  = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        UserRole dmd = [SELECT Id,name FROM UserRole WHERE (Name like'%RSM%' OR Name like '%SS_D%')AND PortalType!='Partner' LIMIT 1];
        User dmUser = new User(Alias = 'dm_u', Email='dom_dmuser@testorg.com',
                               EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                               LocaleSidKey='en_US', ProfileId = dmp.Id,
                               TimeZoneSidKey='America/Los_Angeles',
                               User_Type__c='Domestic',UserName=dmUserName,UserRoleId=dmd.Id,Division__c='I;II',Employee_Code__c='DOMDM1234',ManagerId=rsmUser.Id);                                
        insert dmUser; 
        
        String uniqueUserName = 'dom_user' + DateTime.now().getTime() + '@testorg.com';
         Profile p = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
       //  Profile p  = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        UserRole ssd=[SELECT Id,name FROM UserRole WHERE (Name like'%SSE%' OR Name like '%SS_D%')AND PortalType!='Partner' LIMIT 1];
        
        User u = new User(Alias = 'dom_u', Email='dom_user@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = p.Id,
                          TimeZoneSidKey='America/Los_Angeles',Employee_Code__c='SSEDOM1234',
                          User_Type__c='Domestic',UserName=uniqueUserName,UserRoleId=ssd.Id,Division__c='I', ManagerId=dmUser.Id);
        
        insert u; 
        
        
          
        String uniqueUserName2 = 'sse2_user' + DateTime.now().getTime() + '@testorg.com';
        Profile sse2p = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
      //   Profile sse2p  = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        UserRole sse2d=[SELECT Id,name FROM UserRole WHERE (Name like'%SSE%' OR Name like '%SS_D%') AND PortalType!='Partner' LIMIT 1];
        
        User usr2 = new User(Alias = 'ssed_u', Email='sse2dom_user@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = sse2p.Id,
                          TimeZoneSidKey='America/Los_Angeles',Employee_Code__c='SSE2DOM1234',
                          User_Type__c='Domestic',UserName=uniqueUserName2,UserRoleId=sse2d.Id,Division__c='I', ManagerId=dmUser.Id);
        
        insert usr2;
        Test.stopTest();
        
    }
    
    public static testmethod void methodName(){
        Test.startTest();
        User sseDomUsr = [Select Id,Name From User Where Employee_Code__c='SSEDOM1234' LIMIT 1];
        User sseDomUsr2 = [Select Id,Name From User Where Employee_Code__c='SSE2DOM1234' LIMIT 1];
        User dmDomUsr = [Select Id,Name From User Where Employee_Code__c='DOMDM1234' LIMIT 1];
        
        
        System.runAs(dmDomUsr){
            CIty__c robj = new CIty__c();
            robj.country_key__c = 'IN';
            robj.Region_Code__c = 'IN-MAH';
            robj.Name='Maharashtra';
            insert robj;
            
            Account accObj = new Account();
            accObj.Name = 'Test';
            accObj.GSTIN_No__c='a12345678998765';
            accObj.AccountNumber = '12345678';
            accObj.Region__c = robj.Id;
            accObj.Street_2__c = 'street2';
            accObj.Street_3__c = 'street3';
            accObj.Street_4__c = 'street4';
            accObj.Street_5__c = 'street5';
            accObj.Country_Key__c='IN';
            accObj.City__c='mumbai';
            accObj.City_postal_code__c=String.valueOf('400001'); 
            accObj.BillingPostalCode = '400001';
            insert accObj;
            
            
            
            CIty__c robj1 = new CIty__c();
            robj1.country_key__c = 'IN';
            robj1.Name='Goa';
            robj1.Region_Code__c = 'IN-GOA';
            insert robj1;
            
            Account_Team__c act_team1=new Account_Team__c();
            
            act_team1.Account__c=accObj.Id;
            act_team1.Account_Access__c='Read';
            act_team1.Team_Member__c=sseDomUsr.Id;
            act_team1.Team_Role__c = 'Div 1';
            insert act_team1;
            
            Account_Team__c act_team2 = new Account_Team__c();
            act_team2.Account__c=accObj.Id;
            act_team2.Account_Access__c='Read/Write';
            act_team2.Team_Member__c= sseDomUsr.Id;
            act_team2.Team_Role__c = 'Div 2';
            insert act_team2;
            act_team2.Team_Member__c = sseDomUsr2.Id;
            act_team2.Account_Access__c='Read';
            update act_team2;
            
            Account_Team__c act_team3=new Account_Team__c();
            act_team3.Account__c=accObj.Id;
            act_team3.Account_Access__c='Read/Write';
            act_team3.Team_Member__c=sseDomUsr.Id;
            act_team3.Team_Role__c = 'Div 3';
            insert act_team3;
            
            delete act_team3;
            
            ExpenseTrackerController.getUserData();
            UrlConfigData__c config_data=new UrlConfigData__c(Token__c='',URL__c='http://procesys.archisys.biz/autoLogin?token=',name='ExpenseUrl');
            insert config_data;
            ExpenseTrackerController.getUrlConfigFromCS();    
        }
        
        Test.stopTest();  
    }
}
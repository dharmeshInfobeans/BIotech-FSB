@isTest
public class AccountProcessHandlerTest {
    
    @TestSetup
    static void makeData(){
        Test.startTest();
        String rsmUserName = 'dom_rsmuser' + DateTime.now().getTime() + '@testorg.com';
        Profile rsmp  = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
        UserRole rsmd = [SELECT Id,name FROM UserRole WHERE (Name='RSM_D' OR Name='Domestic RH')];
        User rsmUser = new User(Alias = 'rsm_u', Email='dom_rsmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = rsmp.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=rsmUserName,UserRoleId=rsmd.Id,Division__c='I;II',Employee_Code__c='DOMRSM1234');                                
        insert rsmUser;
        
        String uniqueUserName = 'dom_user' + DateTime.now().getTime() + '@testorg.com';
        Profile p = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
        UserRole ssd=[SELECT Id,name FROM UserRole WHERE (Name='SS_D'OR Name='Domestic RH')];
        
        User sseUser = new User(Alias = 'dom_u', Email='dom_user@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = p.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=uniqueUserName,UserRoleId=ssd.Id,Division__c='I;II',Employee_Code__c='DOM1234',ManagerId = rsmUser.Id);
        
        insert sseUser;
        
        String zsmUserName = 'dom_zsmuser' + DateTime.now().getTime() + '@testorg.com';
        Profile zsmp = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
        UserRole zsmd =[SELECT Id,name FROM UserRole WHERE (Name like'%ZSM%') LIMIT 1];
        User zsmUser = new User(Alias = 'zsm_u', Email='dom_zsmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = zsmp.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=zsmUserName,UserRoleId=zsmd.Id,Division__c='I;II',Employee_Code__c='DOMZSM1234');
         insert  zsmUser;                               
        
         String rsmUserName1 = 'dom_rsmuser' + DateTime.now().getTime() + '@testorg.com';
        //Profile rsmp  = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
        Profile rsmp1  = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        UserRole rsmd1 = [SELECT Id,name FROM UserRole WHERE (Name like'%RSM%' OR Name like '%SS_D%') LIMIT 1];
        User rsmUser1 = new User(Alias = 'rsm_u', Email='dom_rsmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = rsmp1.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=rsmUserName1,UserRoleId=rsmd1.Id,Division__c='I;II',Employee_Code__c='DOMRSM1234', ManagerId=zsmUser.Id);                                
        insert rsmUser1;
        
        String dmUserName = 'dom_dmuser' + DateTime.now().getTime() + '@testorg.com';
//        Profile dmp  = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
	    Profile dmp  = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        UserRole dmd = [SELECT Id,name FROM UserRole WHERE (Name like'%RSM%' OR Name like '%SS_D%') LIMIT 1];
        User dmUser = new User(Alias = 'dm_u', Email='dom_dmuser@testorg.com',
                               EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                               LocaleSidKey='en_US', ProfileId = dmp.Id,
                               TimeZoneSidKey='America/Los_Angeles',
                               User_Type__c='Domestic',UserName=dmUserName,UserRoleId=dmd.Id,Division__c='I;II',Employee_Code__c='DOMDM1234',ManagerId=rsmUser1.Id);                                
        insert dmUser;
        String uniqueUserName2 = 'sse2_user' + DateTime.now().getTime() + '@testorg.com';
 //       Profile p = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
         Profile sse2p  = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        UserRole sse2d=[SELECT Id,name FROM UserRole WHERE (Name like'%SSE%' OR Name like '%SS_D%') LIMIT 1];
        
        User usr2 = new User(Alias = 'ssed_u', Email='sse2dom_user@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = sse2p.Id,
                          TimeZoneSidKey='America/Los_Angeles',Employee_Code__c='SSE2DOM1234',
                          User_Type__c='Domestic',UserName=uniqueUserName2,UserRoleId=sse2d.Id,Division__c='I', ManagerId=dmUser.Id);
        
        insert usr2;
        Test.stopTest();
        
    }
    public static testmethod void methodName(){
        User sseUser = [Select Id,Name From User Where Employee_Code__c='DOM1234'LIMIT 1];
        System.runAs(sseUser){
            Id RecordTypeIdContact = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Distributor').getRecordTypeId();
            //UserRole r =[SELECT Id,name FROM UserRole WHERE Name='RSM_D'];
            
            
            CIty__c robj = new CIty__c();
            robj.country_key__c = 'IN';
            robj.Name='Maharashtra';
            robj.Region_Code__c = 'DL';
            insert robj;
            
            Account accObj = new Account();
            accObj.Name = 'Test';
            accObj.AccountNumber = '12345678';
            accObj.Region__c = robj.Id;
            accObj.Street_2__c = 'street2';
            accObj.Street_3__c = 'street3';
            accObj.Street_4__c = 'street4';
            accObj.Street_5__c = 'street5';
            accObj.Country_Key__c='IN';
            accObj.City__c='mumbai';
            accObj.City_postal_code__c='400001';
            accObj.recordtypeid=RecordTypeIdContact;
            accObj.Branch__c = '';
            accObj.Sub_Status__c=  'Submitted To Approver 1';
            accObj.Medical_Registration_No__c='MEDREG123424567';
            accObj.GSTIN_No__c='GSTIN2343423456';
            List <Monthly_Plan__c> mp_list=new List <Monthly_Plan__c>();
            
            insert accObj;
            
            
            // Account_Team__c acc_team=new Account_Team__c(Account__c=accObj1.Id);
            
            
            // Account_Team__c acc_team1=new Account_Team__c(Account__c=accObj2.Id);
            
            
            
            Attachment attach=new Attachment();     
            attach.Name='ERL';
            Blob bodyBlob=Blob.valueOf('Unit Test Attachment Body');
            attach.body=bodyBlob;
            attach.parentId=accObj.id;
            insert attach;
            
            string before = 'Testing base 64 encode';            
            Blob beforeblob = Blob.valueOf(before);
            //Insert contentdocument data
            ContentVersion cv = new ContentVersion();
            cv.title = 'test content trigger';      
            cv.PathOnClient ='test';           
            cv.VersionData =beforeblob;          
            insert cv;         
            
            ContentVersion testContent = [SELECT id, ContentDocumentId FROM ContentVersion where Id = :cv.Id];
            
            ContentDocumentLink newFileShare = new ContentDocumentLink();
            newFileShare.contentdocumentid = testcontent.contentdocumentid;
            newFileShare.LinkedEntityId = accObj.Id;
            newFileShare.ShareType= 'V';
            insert newFileShare;
            
            
            
            test.startTest();
            
            List<AccountProcessHandler.MonthlyPlanCreationRequest> mpcr_list=new List <AccountProcessHandler.MonthlyPlanCreationRequest>();
            
            
            AccountProcessHandler.MonthlyPlanCreationRequest mpcr=new  AccountProcessHandler.MonthlyPlanCreationRequest();
            mpcr.accountId=accObj.Id;
            mpcr.numberOfMonthlyPlanRecords=12; 
            mpcr_list.add(mpcr);
            AccountProcessHandler.createMonthlyPlanRecords(mpcr_list);
            
            
            AccountProcessHandler.MonthlyPlanCreationRequest mpcr2 = new  AccountProcessHandler.MonthlyPlanCreationRequest();
            mpcr2.accountId=accObj.Id;
            mpcr2.numberOfMonthlyPlanRecords=12;
            mpcr2.isFromBatch = true;
            List <Monthly_Plan__c> mplist = new List <Monthly_Plan__c>();
            mplist.add(new Monthly_Plan__c(Account__c = accObj.Id,Month__c= 'Apr',Financial_Year__c = '2018'));
            mpcr2.mPlanList = mplist;
            mpcr_list.add(mpcr2);
            AccountProcessHandler.createMonthlyPlanRecords(mpcr_list);
            
            //List<Monthly_Plan__c> mPlanList1=AccountProcessHandler.mpcr_list;       
            SubmitForApprovalController.checkAccHasERLAttachmentAndCESRecord(String.valueOf(accObj.Id));
            SubmitForApprovalController.setIsAccHavingERLFieldOnAccount(String.valueOf(accObj.Id));
            test.stopTest();            
        }
        
        
    }  
    public static testmethod void methodName1(){
        
        Account accObj1 = new Account();
        accObj1.Name = 'Test';
        accObj1.Medical_Registration_No__c='MEDREG123424567';
        accObj1.GSTIN_No__c='GSTIN2343423456';
        insert accObj1;
    }
    public static testmethod void methodName2(){
        
        Account accObj2 = new Account();
        accObj2.Name = 'Test';
        accObj2.Branch__c = 'Mumbai';
        //accObj2.Sub_Status__c=  'Submitted To Branch Team';
        accObj2.Medical_Registration_No__c='MEDREG123424567';
        accObj2.GSTIN_No__c='GSTIN2343423456';
        insert accObj2;
        
        User sseDomUsr = [Select Id,Name From User Where Employee_Code__c='DOM1234' LIMIT 1];
        User sseDomUsr2 = [Select Id,Name From User Where Employee_Code__c='SSE2DOM1234' LIMIT 1];
        User dmDomUsr = [Select Id,Name From User Where Employee_Code__c='DOMDM1234' LIMIT 1];
        
        
        System.runAs(dmDomUsr){
        Account_Team__c acc_team = new Account_Team__c();
        acc_team.Account__c=accObj2.Id;
        //acc_team.Team_Member__c = UserInfo.getUserId();
        acc_team.Team_Role__c = 'RH';
        acc_team.Team_Member__c=sseDomUsr.Id;
        insert acc_team;
        }
    }
    
}
@isTest
public class BiotechUtilityTest {
    @TestSetup
    static void initData(){
        Test.StartTest();
       
        
        String zsmUserName = 'dom_zsmuser' + DateTime.now().getTime() + '@testorg.com';
        Profile zsmp = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
        UserRole zsmd =[SELECT Id,name FROM UserRole WHERE (Name='ZSM' OR Name='Domestic RH')];
        User zsmUser = new User(Alias = 'zsm_u', Email='dom_zsmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = zsmp.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=zsmUserName,UserRoleId=zsmd.Id,Division__c='I;II',Employee_Code__c='DOMZSM1234');
         insert  zsmUser;                               
        
         String rsmUserName = 'dom_rsmuser' + DateTime.now().getTime() + '@testorg.com';
        Profile rsmp  = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
        UserRole rsmd = [SELECT Id,name FROM UserRole WHERE (Name='RSM_D' OR Name='Domestic RH')];
        User rsmUser = new User(Alias = 'rsm_u', Email='dom_rsmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = rsmp.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=rsmUserName,UserRoleId=rsmd.Id,Division__c='I;II',Employee_Code__c='DOMRSM1234', ManagerId=zsmUser.Id);                                
        insert rsmUser;
        
        String dmUserName = 'dom_dmuser' + DateTime.now().getTime() + '@testorg.com';
        Profile dmp  = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
        UserRole dmd = [SELECT Id,name FROM UserRole WHERE (Name='DM_D'OR Name='Domestic RH')];
        User dmUser = new User(Alias = 'dm_u', Email='dom_dmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = dmp.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=dmUserName,UserRoleId=dmd.Id,Division__c='I;II',Employee_Code__c='DOMDM1234', ManagerId=rsmUser.Id);                                
        insert dmUser;
        
        String uniqueUserName = 'dom_user' + DateTime.now().getTime() + '@testorg.com';
        Profile p = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
        UserRole ssd=[SELECT Id,name FROM UserRole WHERE (Name='SS_D'OR Name='Domestic RH')];
        
        User sseUser = new User(Alias = 'dom_u', Email='dom_user@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = p.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=uniqueUserName,UserRoleId=ssd.Id,Division__c='I;II',Employee_Code__c='DOM1234',ManagerId = dmUser.Id);
        
        insert sseUser;
        
        
        
        String rsmTUserName = 'rsmtur_user' + DateTime.now().getTime() + '@testorg.com';
        Profile rsmtprof  = [SELECT Id FROM Profile WHERE Name='Turkey Sales'];
        UserRole rsmtrole =[SELECT Id,name FROM UserRole WHERE (Name='RSM_T'OR Name='Domestic RH')];
        
        User rsmturkeyUser = new User(Alias = 'rsmt_u', Email='rsmt_user@testorg.com',
                                   EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                   LocaleSidKey='en_US', ProfileId = rsmtprof.Id,
                                   TimeZoneSidKey='America/Los_Angeles',
                                   User_Type__c='Turkey',UserName=rsmTUserName,UserRoleId=rsmtrole.Id,Division__c='I;II',Employee_Code__c='RSMTUR1234');
        insert rsmturkeyUser;
        
        String turUserName = 'tur_user' + DateTime.now().getTime() + '@testorg.com';
        Profile tprof  = [SELECT Id FROM Profile WHERE Name='Turkey Sales'];
        UserRole trole =[SELECT Id,name FROM UserRole WHERE (Name='SS_T'OR Name='Domestic RH')];
        
        User turkeyUser = new User(Alias = 'tur_u', Email='tur_user@testorg.com',
                                   EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                   LocaleSidKey='en_US', ProfileId = tprof.Id,
                                   TimeZoneSidKey='America/Los_Angeles',
                                   User_Type__c='Turkey',UserName=turUserName,UserRoleId=trole.Id,Division__c='I;II',Employee_Code__c='TUR1234',ManagerId = rsmturkeyUser.Id);
        
        insert turkeyUser;
        String chUserName = 'chint_user' + DateTime.now().getTime() + '@testorg.com';
        Profile chiprof  = [SELECT Id FROM Profile WHERE Name='International Sales'];
        UserRole chirole = [SELECT Id,name FROM UserRole WHERE (Name='CH_OP' OR Name='Domestic RH')];
        
        User chintUser = new User(Alias = 'chint_u', Email='chint_user@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = chiprof.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='International',UserName=chUserName,UserRoleId=chirole.Id,Division__c='I;II',Employee_Code__c='CHINT1234');
        
        insert chintUser;
                       
        String intUserName = 'int_user' + DateTime.now().getTime() + '@testorg.com';
        Profile iprof  = [SELECT Id FROM Profile WHERE Name='International Sales'];
        UserRole irole = [SELECT Id,name FROM UserRole WHERE (Name='RBM_OP' OR Name='Domestic RH')];
        
        User intUser = new User(Alias = 'int_u', Email='int_user@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = iprof.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='International',UserName=intUserName,UserRoleId=irole.Id,Division__c='I;II',Employee_Code__c='INT1234',ManagerId = chintUser.Id);
        
        insert intUser;
        
        String ceoUserName = 'ceo_user' + DateTime.now().getTime() + '@testorg.com';
        Profile prof  = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        UserRole ceorole = [SELECT Id,name FROM UserRole WHERE (Name='CEO_Dev_Admin' OR Name='Domestic RH')];
        
        User ceoUser = new User(Alias = 'ceo_u', Email='ceo_user@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = prof.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=ceoUserName,UserRoleId=ceorole.Id,Division__c='I;II',Employee_Code__c='CEO1234');
        
        insert ceoUser;
        
        String ceoTName = 'ceot_user' + DateTime.now().getTime() + '@testorg.com';
        Profile proft  = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        UserRole ceorolet = [SELECT Id,name FROM UserRole WHERE (Name='CEO_Dev_Admin' OR Name='Domestic RH')];
        
        User ceoTUser = new User(Alias = 'ceot_u', Email='ceot_user@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = proft.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Turkey',UserName=ceoTName,UserRoleId=ceorolet.Id,Division__c='I;II',Employee_Code__c='CEOTUR1234');
        
        insert ceoTUser;
        
        String ceoIntUserName = 'ceoint_user' + DateTime.now().getTime() + '@testorg.com';
        Profile profInt  = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        UserRole ceoroleInt = [SELECT Id,name FROM UserRole WHERE (Name='CEO_Dev_Admin' OR Name='Domestic RH')];
        
        User ceoIntUser = new User(Alias = 'ceoi_u', Email='ceoi_user@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = profInt.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='International',UserName=ceoIntUserName,UserRoleId=ceoroleInt.Id,Division__c='I;II',Employee_Code__c='CEOINT1234');
        
        insert ceoIntUser;
        
        
        String noUserTypeName = 'nousrtype_user' + DateTime.now().getTime() + '@testorg.com';
        Profile noUsrProfInt  = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        UserRole noUsrRole = [SELECT Id,name FROM UserRole WHERE (Name='CEO_Dev_Admin' OR Name='Domestic RH')];
        
        User noUserTypeUsr = new User(Alias = 'nousr_u', Email='nousr_user@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = noUsrProfInt.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                UserName=noUserTypeName,UserRoleId=noUsrRole.Id,Division__c='I;II',Employee_Code__c='NOUSR1234');
        
        insert noUserTypeUsr;
        Test.StopTest();
    }
    
    @isTest
    static void method1(){
        //BiotechUtility.encryptData(beforeblob);
        //BiotechUtility.decryptData(beforeblob);
        //BiotechUtility.getApprovers(UserInfo.getUserId());
        BiotechUtility.getPicklistValues('Account','Country_Key__c');
        BiotechUtility.getEmailByBranchLocation('MUMBAI');
        BiotechUtility.getEmailByBranchLocation('Sunami'); // random data
        BiotechUtility.getEmailByBranchLocation(null); // random data
        //BiotechUtility.getIntSalesHeadId();
        BiotechUtility.getIntAdminUserId();
        BiotechUtility.getTurkeyAdminUserId();
        BiotechUtility.getDomesticAdminUserId();
    }
    
    @isTest
    static void testApprover(){
        Test.startTest();
        User sseUsr = [Select Id,Name,UserRole.Name,ProfileId,Profile.Name,ManagerId,Manager.Name,Manager.UserRole.Name,Manager.Profile.Name,Manager.ManagerId,Manager.Manager.Name,Manager.Manager.UserRole.Name,Manager.Manager.ManagerId,Manager.Manager.Manager.Name,Manager.Manager.Manager.UserRole.Name
                       From User Where Employee_Code__c='DOM1234'LIMIT 1 ];
        User rsmUsr = [Select Id,Name,Division__c,Employee_Code__c From User Where Employee_Code__c='DOMRSM1234' LIMIT 1 ];
        //System.debug('USER-->'+sseUsr);
        //System.debug('USER-->Manager.UserRole.Name-->'+sseUsr.Manager.UserRole.Name);
        //
        System.runAs(sseUsr) {
           BiotechUtility.getApprovers(sseUsr.Id); 
           
        }
        System.runAs(rsmUsr) {
           BiotechUtility.getApprovers(rsmUsr.Id); 
           
        }
        
        
        User tUsr = [Select Id,Name,Division__c,Employee_Code__c From User Where Employee_Code__c='TUR1234' LIMIT 1 ];
        User rsmtUsr = [Select Id,Name,Division__c,Employee_Code__c From User Where Employee_Code__c='RSMTUR1234' LIMIT 1 ];
        
        System.runAs(tUsr) {
           BiotechUtility.getApprovers(tUsr.Id); 
           //BiotechUtility.getTurkeyAdminUserId();
        }
        System.runAs(rsmtUsr) {
           BiotechUtility.getApprovers(rsmtUsr.Id); //rsmtuser doesn't have manager
           //BiotechUtility.getTurkeyAdminUserId();
        }
        
        User iUsr = [Select Id,Name,Division__c,Employee_Code__c From User Where Employee_Code__c='INT1234' LIMIT 1 ];
        User chUsr = [Select Id,Name,Division__c,Employee_Code__c From User Where Employee_Code__c='CHINT1234' LIMIT 1 ];
        
        System.runAs(iUsr) {
           BiotechUtility.getApprovers(iUsr.Id); 
           //BiotechUtility.getTurkeyAdminUserId();
        }
        System.runAs(chUsr) {
           BiotechUtility.getApprovers(chUsr.Id); //rsmtuser doesn't have manager
           //BiotechUtility.getTurkeyAdminUserId();
        }
        System.runAs(chUsr) {
           BiotechUtility.getApprovers(null); //will throw exception
           //BiotechUtility.getTurkeyAdminUserId();
        }
        
        User ceoUsr = [Select Id,Name,Division__c,Employee_Code__c From User Where Employee_Code__c='CEO1234' LIMIT 1 ];
        System.runAs(ceoUsr) {
           BiotechUtility.getApprovers(ceoUsr.Id); 
        }
        
        User ceoUsrT = [Select Id,Name,Division__c,Employee_Code__c From User Where Employee_Code__c='CEOTUR1234' LIMIT 1 ];
        System.runAs(ceoUsrT) {
           BiotechUtility.getApprovers(ceoUsrT.Id); 
        }
        
        User noUsrTypeUsr = [Select Id,Name,Division__c,Employee_Code__c From User Where Employee_Code__c='NOUSR1234' LIMIT 1 ];
        System.runAs(noUsrTypeUsr) {
           BiotechUtility.getApprovers(noUsrTypeUsr.Id); 
        }
        
        Test.stopTest();
    }
}
@isTest
public class TargetAndPlanningControllerTest {
    public static Account acc;
    public static User user;
    
    @TestSetup
    static void makeData(){
        Test.startTest();
         String dmUserName = 'dom_dmuser' + DateTime.now().getTime() + '@testorg.com';
        Profile dmp  = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
        UserRole dmd = [SELECT Id,name FROM UserRole WHERE (Name like'%RSM%' OR Name like '%SS_D%') LIMIT 1];
        User dmUser = new User(Alias = 'dm_u', Email='dom_dmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = dmp.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=dmUserName,UserRoleId=dmd.Id,Division__c='I;II',Employee_Code__c='DOMDM1234');                                
        insert dmUser;
        
        String uniqueUserName = 'dom_user' + DateTime.now().getTime() + '@testorg.com';
        Profile p = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
        UserRole ssd=[SELECT Id,name FROM UserRole WHERE (Name like'%SSE%' OR Name like '%SS_D%') LIMIT 1];
        
        User u = new User(Alias = 'dom_u', Email='dom_user@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = p.Id,
                          TimeZoneSidKey='America/Los_Angeles',Employee_Code__c='SSEDOM1234',
                          User_Type__c='Domestic',UserName=uniqueUserName,UserRoleId=ssd.Id,Division__c='I', ManagerId=dmUser.Id);
        
        insert u;
        Test.stopTest();
    }
    
    static testmethod void test() { 
        User sseDomUsr = [Select Id,Name From User Where Employee_Code__c='SSEDOM1234' LIMIT 1];
        
        System.runAs(sseDomUsr) {
        Test.startTest();
        Account acc =new Account(
            name='Account',Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',
            Medical_Registration_No__c='MEDREG123424567',GSTIN_No__c='GSTIN2343423456',Account_Locked__c=true,
            Status__c='Activated');

        insert acc;
        
        Monthly_Plan__c mplan=new Monthly_Plan__c(name='mp1',Account__c=acc.id,Year__c='2019',
                                                  Month__c='Apr',Financial_Year__c='2019');
        insert mplan;
        
        Monthly_Plan__c mplan2 = new Monthly_Plan__c(name='mp2',Account__c=acc.id,Year__c='2019',
                                                  Month__c='Jun',Financial_Year__c='2019');
        insert mplan2;
        
        Product__c prod = new Product__c();
        prod.Name = '600';
        prod.Dummy_Product_Code__c = 'D0001';
        prod.Dummy_Product_Description__c = '600';
        prod.Division__c = 'I';
        prod.MSP__c = 300;
        insert prod;
        
        Monthly_AOP__c maop = new Monthly_AOP__c();
        maop.Account__c=acc.Id;
        maop.Year__c='2019';
        maop.Target_Quantity__c=10;
        maop.Month__c='Apr';
        maop.Product__c=prod.Id;
        maop.Financial_Year__c='2019';
        insert maop;
        
        Monthly_AOP__c maop2 = new Monthly_AOP__c();
        maop2.Account__c=acc.Id;
        maop2.Year__c='2019';
        maop2.Target_Quantity__c=20;
        maop2.Month__c='Jun';
        maop2.Product__c=prod.Id;
        maop.Financial_Year__c='2019';
        insert maop2;
        
        Monthly_Product_Plan__c mpp = new Monthly_Product_Plan__c();
        mpp.Planned_Quantity__c = 20;
        mpp.Monthly_Plan__c = mplan.Id;
        mpp.Monthly_Target__c = maop.Id;    
		mpp.Month__c = mplan.Month__c;
        mpp.Year__c = mplan.Year__c;
        mpp.User__c = sseDomUsr.Id;
        mpp.MPP_Mapping__c = 'MPPCODE1234';
        insert mpp;
        
        Monthly_Product_Plan__c mpp2 = new Monthly_Product_Plan__c();
        mpp2.Planned_Quantity__c = 30;
        mpp2.Monthly_Plan__c = mplan.Id;
        mpp2.Monthly_Target__c = maop.Id;    
		mpp2.Month__c = mplan2.Month__c;
        mpp2.Year__c = mplan2.Year__c;
        mpp2.User__c = sseDomUsr.Id;
        mpp2.MPP_Mapping__c = 'MPPCODE12345';
        insert mpp2;
        
        Monthly_Product_Plan__c mpp4 = new Monthly_Product_Plan__c();
        mpp4.Planned_Quantity__c = 30;
        mpp4.Monthly_Plan__c = mplan.Id;
        mpp4.Monthly_Target__c = maop.Id;    
		mpp4.Month__c = 'Jan';
        mpp4.Year__c = '2019';
        mpp4.User__c = sseDomUsr.Id;
        mpp4.MPP_Mapping__c = 'MPPCODE12345';
        insert mpp4;
		
        List<Monthly_Product_Plan__c> mp_plan = new List<Monthly_Product_Plan__c>();
        mp_plan.add(mpp);
        mp_plan.add(mpp2);
        Monthly_Product_Plan__c mpp3 = new Monthly_Product_Plan__c();
        mpp3.Planned_Quantity__c = 50;
        mpp3.Monthly_Plan__c = mplan.Id;
        mpp3.Monthly_Target__c = maop.Id;    
		mpp3.Month__c = mplan2.Month__c;
        mpp3.Year__c = mplan2.Year__c;
        mpp3.User__c = sseDomUsr.Id;
        mpp3.MPP_Mapping__c = 'MPPCODE12345';    
        mp_plan.add(mpp3);
        Monthly_AOP__c[] m_mop=[SELECT Id FROM Monthly_AOP__c];
        Set<Id> aopIds = new Set<Id>();
        for(Monthly_AOP__c tsk: m_mop) {
            aopIds.add(tsk.Id);
        }
        
        
            TargetAndPlanningController.getTargetAmountByUserDivision('Apr','2019','test');
            TargetAndPlanningController.getTargetAmountByUserDivision('Apr','2019','Domestic');
            TargetAndPlanningController.getTargetAmountByUserDivision('Apr','2019','Turkey');
            TargetAndPlanningController.getAccounts('Apr','2019','Domestic');
            TargetAndPlanningController.getAccounts('Apr','2019','Turkey');
            TargetAndPlanningController.getAccounts('Apr','2019','test');
            
            
        
        TargetAndPlanningController.saveMPPS(mp_plan,'Apr','2019','Domestic');
        TargetAndPlanningController.saveMPPS(mp_plan,'Apr','2019','Turkey');
        TargetAndPlanningController.saveMPPS(mp_plan,'Apr','2019','test');
        
        TargetAndPlanningController tp_ctrl=new TargetAndPlanningController();
        tp_ctrl.summarizePlannedQtyOnAOP(aopIds); 
        Test.stopTest();
        }
    }
    
    @isTest
    static void testAopRollupValues(){
        Test.startTest();
        Account acc =new Account(
            name='Account',Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',
            Medical_Registration_No__c='MEDREG123424567',GSTIN_No__c='GSTIN2343423456',Account_Locked__c=true,
            Status__c='Activated');
        insert acc;
        
        Monthly_Plan__c mplan=new Monthly_Plan__c(name='mp1',Account__c=acc.id,Year__c='2019',
                                                  Month__c='Apr',Financial_Year__c='2019');
        insert mplan;
        
        Monthly_Plan__c mplan2 = new Monthly_Plan__c(name='mp2',Account__c=acc.id,Year__c='2019',
                                                  Month__c='Jun',Financial_Year__c='2019');
        insert mplan2;
        
        Product__c prod = new Product__c();
        prod.Name = '600';
        prod.Dummy_Product_Code__c = 'D0001';
        prod.Dummy_Product_Description__c = '600';
        prod.Division__c = 'I';
        prod.MSP__c = 300;
        insert prod;
        
        Monthly_AOP__c maop = new Monthly_AOP__c();
        //maop.Account__c=acc.Id;
        maop.Year__c='2019';
        maop.Target_Quantity__c=900;
        maop.Month__c='Apr';
        maop.Product__c=prod.Id;
        maop.Planned_Quantity__c = 0;
        maop.Remaining_Qty__c = 0;            
        insert maop;
        
        
        Monthly_Product_Plan__c mpp = new Monthly_Product_Plan__c();
        mpp.Planned_Quantity__c = 20;
        mpp.Monthly_Plan__c = mplan.Id;
        mpp.Monthly_Target__c = maop.Id;    
		mpp.Month__c = mplan.Month__c;
        mpp.Year__c = mplan.Year__c;
        mpp.Product__c= prod.Id;
        mpp.MPP_Mapping__c = 'MPP1234567';
        mpp.User__c = UserInfo.getUserId();
        insert mpp;
        
        List<Id> maopIds = new List<Id>();
        maopIds.add(maop.Id);
        TargetAndPlanningController.updateAOPs(maopIds);
        Test.stopTest();
    }
    
    
    
}
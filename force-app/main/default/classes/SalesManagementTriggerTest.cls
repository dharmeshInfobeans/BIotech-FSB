@IsTest
public class SalesManagementTriggerTest {
    public static User u2;
    public static User u1;
    public static User u3;
    public static User u4;
    public static User u5;
    // public static Sample_Request__c sr_test;
    //      public static Account accObj;
    // public static Monthly_Plan__c mplan;
    // public static Monthly_AOP__c m_aop;
    // public static Monthly_Product_Plan__c mp_plan;
    public static UserRole r,r1,r2;
    public static Profile p;
    
    @TestSetup
    public static void makeData(){
        
        
        r =[SELECT Id,name FROM UserRole WHERE (Name='RH' OR Name='CEO_Dev_Admin' OR Name='Domestic RH') LIMIT 1];
        
        r1 = [SELECT Id,name FROM UserRole WHERE (Name='RH' OR Name='CEO_Dev_Admin' OR Name='Domestic RH') LIMIT 1];
        
        
        //  UserRole ssd=[SELECT Id,name FROM UserRole WHERE Name='SS_T'];
        p = [SELECT Id FROM Profile WHERE Name='International Sales'];
        
        
        r2 = [SELECT Id,name FROM UserRole WHERE (Name='RH' OR Name='CEO_Dev_Admin' OR Name='Domestic RH') LIMIT 1];
        u3 = new User(Alias = 'newUser1', Email='newuser1@testorg.com',
                      EmailEncodingKey='UTF-8', LastName='Test user 3', LanguageLocaleKey='en_US',
                      LocaleSidKey='en_US', ProfileId = p.Id,
                      TimeZoneSidKey='America/Los_Angeles', UserName='newuser1234@testorg123.com');
        
        
        u1 = new User(Alias = 'newU', Email='newuser123@testorg.com',
                      EmailEncodingKey='UTF-8', LastName='Test user 1', LanguageLocaleKey='en_US',
                      LocaleSidKey='en_US', ProfileId = p.Id,
                      TimeZoneSidKey='America/Los_Angeles', UserName='newuser123@testorg123.com',UserRoleId = r2.id);
        insert u1;
        
        u4 = new User(Alias = 'newU', Email='newuser4@testorg.com',
                      EmailEncodingKey='UTF-8', LastName='Test user 1', LanguageLocaleKey='en_US',
                      LocaleSidKey='en_US', ProfileId = p.Id,
                      TimeZoneSidKey='America/Los_Angeles', UserName='newuser4@testorg.com',UserRoleId = r1.id);
        insert u4;
        
        u5 = new User(Alias = 'newU', Email='newuser5@testorg.com',
                      EmailEncodingKey='UTF-8', LastName='Test user 1', LanguageLocaleKey='en_US',
                      LocaleSidKey='en_US', ProfileId = p.Id,
                      TimeZoneSidKey='America/Los_Angeles', UserName='newuser5@testorg.com',ManagerId = u4.id);
        insert u5; 
        
        u2 = new User(Alias = 'newUser1', Email='newuser1@testorg.com',
                      EmailEncodingKey='UTF-8', LastName='Test user 2', LanguageLocaleKey='en_US',
                      LocaleSidKey='en_US', ProfileId = p.Id,
                      TimeZoneSidKey='America/Los_Angeles', UserName='newuser1@testorg123.com',ManagerId= u1.Id);
        insert u2;
        List<SampleRequestProcessHandler.SampleRequestData> srd_list;
        Sample_Request__c  sr_test;
        System.runAs(u3){        
            Account  accObj = new Account();
            accObj.Name = 'Test';
            
            
            accObj.Street_2__c = 'street2';
            accObj.Street_3__c = 'street3';
            accObj.Street_4__c = 'street4';
            accObj.Street_5__c = 'street5';
            insert accObj;
            
            Product__c prd=new Product__c(name='test product',Dummy_Product_Code__c='123');
            insert prd;
            
            List <Monthly_Plan__c> mp_list=new List <Monthly_Plan__c>();
            
            
            Monthly_Plan__c mplan=new Monthly_Plan__c(name='mp1',Account__c=accObj.id);
            
            insert mplan;
            
            Monthly_AOP__c m_aop= new Monthly_AOP__c(Account__c=accObj.Id,Year__c='2019',Financial_Year__c='2019',Target_Quantity__c=10,Month__c='Jul',Product__c=prd.Id);
            insert m_aop;
            
            Monthly_Product_Plan__c mp_plan=new  Monthly_Product_Plan__c(Monthly_Plan__c=mplan.id);
            insert mp_plan;
            
            
            sr_test=new Sample_Request__c(Monthly_Plan__c=mplan.Id,Status__c='Approved');
            insert sr_test;
            
            AOPDetailCompIntController.getAllMppsForAop(String.valueOf(m_aop.Id) ,'2019',String.valueOf(prd.Id),String.valueOf(accObj.Id));
            srd_list=new List<SampleRequestProcessHandler.SampleRequestData>();
            SampleRequestProcessHandler.SampleRequestData srd=new SampleRequestProcessHandler.SampleRequestData();
            srd.ownerId=u3.Id;
            srd.sampleRequestId   =sr_test.Id;  
            srd_list.add(srd);
            
            
            SampleRequestProcessHandler.setApproverForSampleRequest(srd_list);
            
            List<SampleRequestProcessHandler.SampleRequestData> srd_list1=new List<SampleRequestProcessHandler.SampleRequestData>();
            SampleRequestProcessHandler.SampleRequestData srd1=new SampleRequestProcessHandler.SampleRequestData();
            srd1.ownerId=u1.Id;
            srd1.sampleRequestId   =sr_test.Id;  
            srd_list1.add(srd1);
            SampleRequestProcessHandler.setApproverForSampleRequest(srd_list1);
            
            List<SampleRequestProcessHandler.SampleRequestData> srd_list2=new List<SampleRequestProcessHandler.SampleRequestData>();
            SampleRequestProcessHandler.SampleRequestData srd2=new SampleRequestProcessHandler.SampleRequestData();
            srd2.ownerId=u2.Id;
            srd2.sampleRequestId   =sr_test.Id;  
            srd_list2.add(srd2);
            SampleRequestProcessHandler.setApproverForSampleRequest(srd_list2);
            
            List<SampleRequestProcessHandler.SampleRequestData> srd_list3=new List<SampleRequestProcessHandler.SampleRequestData>();
            SampleRequestProcessHandler.SampleRequestData srd3=new SampleRequestProcessHandler.SampleRequestData();
            srd3.ownerId=u5.Id;
            srd3.sampleRequestId   =sr_test.Id;  
            srd_list3.add(srd3);
            SampleRequestProcessHandler.setApproverForSampleRequest(srd_list3);
        }
        //BiotechUtility.getTurkeyAdminUserId();
        //BiotechUtility.getIntSalesHeadId();
        
        /*   
System.runAs(u2) {
Sample_Request__c sr_test2=[select id from Sample_Request__c where Status__c='Approved'];
List<SampleRequestProcessHandler.SampleRequestData> srd_list=new List<SampleRequestProcessHandler.SampleRequestData>();
SampleRequestProcessHandler.SampleRequestData srd=new SampleRequestProcessHandler.SampleRequestData();
srd.ownerId=u2.Id;
srd.sampleRequestId   =sr_test2.Id;  
srd_list.add(srd);
SampleRequestProcessHandler.setApproverForSampleRequest(srd_list);
}

System.runAs(u1) {
Sample_Request__c sr_test1=[select id from Sample_Request__c where Status__c='Approved'];
List<SampleRequestProcessHandler.SampleRequestData> srd_list=new List<SampleRequestProcessHandler.SampleRequestData>();
SampleRequestProcessHandler.SampleRequestData srd=new SampleRequestProcessHandler.SampleRequestData();
srd.ownerId=u1.Id;
srd.sampleRequestId   =sr_test1.Id;  
srd_list.add(srd);
SampleRequestProcessHandler.setApproverForSampleRequest(srd_list);
}
mp_plan.Year__c='2019';
mp_plan.Monthly_Target__c=m_aop.Id;
mp_plan.Planned_Quantity__c=1;
update mp_plan;*/
        //  System.debug('U# ID::::'+u3.UserRole.Name);
        
        
    }
    
    
    public static testmethod void makeData1(){
        
    }
    
    @IsTest
    public static void methodName(){
        
        test.startTest();
        
        //    System.debug('user3 ID111::::'+u3.Id);
        
        Sample_Request__c sr_test3=[select id from Sample_Request__c where Status__c='Approved'];
        
        
        
        // insert u3;
        //System.debug('user3 ID::::'+u3.Id);
        
        
        PickListController.getPickListValues('Account','Company_Code__c');
        
    }
    
    public static testmethod void methodName1(){
        Monthly_Plan__c mp1=[select id,name from Monthly_Plan__c where name='mp1'];
        Id mp1_id=mp1.Id;
        Monthly_Product_Plan__c mpp1=[select id from Monthly_Product_Plan__c where Monthly_Plan__r.id=:mp1_id];
        delete mpp1;
    }
    // delete mp_plan;
}
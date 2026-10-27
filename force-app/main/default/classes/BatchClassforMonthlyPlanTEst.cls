@isTest
public class BatchClassforMonthlyPlanTEst {
    
    @TestSetup
    static void makeData(){
        List<Account> accounts = new List<Account>();
        //List<String>  months=new List<String> {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
        
        List <Monthly_Plan__c> mp_list=new List <Monthly_Plan__c>();
        // SELECT Id, Name, DeveloperName FROM RecordType WHERE SObjectType = 'Opportunity'
        
        
        // insert 10 accounts
        
        accounts.add(new Account(name='Account', 
                                 Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',Account_Locked__c=false,Status__c='Activated',GSTIN_No__c='GSTIN2343423456'));
        List<Event> test_eve=new List<Event>();
        
         List<Event> test_eve1=new List<Event>();
        
        
        insert accounts;
        for(Account acc: accounts){
            for(Integer i=0;i<12;i++){
                mp_list.add(new Monthly_Plan__c(Financial_Year__c='2018',Account__c=acc.Id));
            }
            test_eve.add(new Event(subject='test subject',startDateTime=system.now(),endDateTime=System.now().addDays(1),visit_Date__c= date.today(),WhatId=acc.Id));
           test_eve1.add(new Event(subject='test subject',startDateTime=system.now(),endDateTime=System.now().addDays(1),visit_Date__c= date.today(),WhatId=acc.Id,Status__c='Approved',API_Status__c='Success'));

        }
        insert mp_list;
        insert test_eve;
        insert test_eve1;
    }
    
    
    
    static testmethod void test() {   
        Test.startTest();
        
        BatchClassforMonthlyPlan bmp=new BatchClassforMonthlyPlan();
        Id batchId1 = Database.executeBatch(bmp);
        BatchCreateBeatPlan bcp=new BatchCreateBeatPlan();
        Id batchId2 = Database.executeBatch(bcp);
        
        //BatchDCRCallOutClass bdcr=new BatchDCRCallOutClass();
        // Id batchId3 = Database.executeBatch(bdcr);
        Test.stopTest();
    }
}
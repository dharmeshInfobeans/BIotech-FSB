@IsTest(seeALLdata=true)
public class CaptureAccountAndLeadHelper_Test {
    @IsTest
    static void methodName(){
        list<event> eventList = new list<event>();
        Account a=new Account(name='Account', 
                                Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',Account_Locked__c=false,Status__c='Activated',GSTIN_No__c='GSTIN2343423456');
        insert a;
        
         Beat_Plan__c tt = new Beat_Plan__c();
         tt.Event_Type__c = 'P';
        insert tt;
        
        Event e = new Event();
        e.WhatId=a.id;
        e.StartDateTime=system.today();
        e.EndDateTime=system.today()+5;
        e.Visit_Date__c = system.today();
        e.Beat_plan__c = tt.id;
        e.Subject  = 'test';
        e.Type_of_leave__c = 'First Half Leave';
        e.status__c = 'Sent for Approval';
        insert e;
        eventList.add(e);
        //CaptureAccountAndLeadHelper.updatevent(eventList);
        CaptureAccountAndLeadHelper.updatbeatPlan(eventList);
    }
    @IsTest
    static void methodName2(){
        list<event> eventList = new list<event>();
        Account a=new Account(name='Account', 
                                Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',Account_Locked__c=false,Status__c='Activated',GSTIN_No__c='GSTIN2343423456');
        insert a;
        
         Beat_Plan__c tt = new Beat_Plan__c();
         tt.Event_Type__c = 'P';
        tt.Beat_Date__c = system.today();
        tt.Assigned_To__c = UserInfo.getUserId();
        insert tt;
        Event e = new Event();
        e.WhatId=a.id;
        e.Beat_Plan__c = tt.id;
        e.StartDateTime=system.today();
        e.EndDateTime=system.today()+5;
        e.Visit_Date__c = system.today()+2;
        e.Subject  = 'Holiday';
        e.status__c = 'Sent for Approval';
        insert e;
        eventList.add(e);
       
        Event e1 = new Event();
        e1.WhatId=a.id;
        e1.Beat_Plan__c = tt.id;
        e1.StartDateTime=system.today();
        e1.EndDateTime=system.today()+5;
        e1.Visit_Date__c = system.today()+2;
        e1.Subject  = 'Leave';
        e1.status__c = 'Sent for Approval';
        insert e1;
        eventList.add(e1);
        //CaptureAccountAndLeadHelper.updatevent(eventList);
        CaptureAccountAndLeadHelper.updatbeatPlan(eventList);
    }
    @IsTest
    static void methodName3(){
        list<event> eventList = new list<event>();
        Account a=new Account(name='Account', 
                                Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',Account_Locked__c=false,Status__c='Activated',GSTIN_No__c='GSTIN2343423456');
        insert a;
        Beat_Plan__c tt = new Beat_Plan__c();
         tt.Event_Type__c = 'P';
        insert tt;
        Event e = new Event();
        e.WhatId=a.id;
        e.StartDateTime=system.today();
        e.Type_of_leave__c= 'Full Day Leave';
        e.EndDateTime=system.today()+5;
        e.Visit_Date__c = system.today();
        e.Subject  = 'Leave';
        e.Beat_Plan__c = tt.id;
        e.status__c = 'Approved';
        insert e;
        eventList.add(e);
       // CaptureAccountAndLeadHelper.updatevent(eventList);
        CaptureAccountAndLeadHelper.updatbeatPlan(eventList);
    }
    @IsTest
    static void methodName4(){
        list<event> eventList = new list<event>();
        Account a=new Account(name='Account', 
                                Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',Account_Locked__c=false,Status__c='Activated',GSTIN_No__c='GSTIN2343423456');
        insert a;
        
        Event e = new Event();
        e.WhatId=a.id;
        e.OwnerId = UserInfo.getUserId();
        e.StartDateTime=system.today();
        e.EndDateTime=system.today()+5;
        e.Type_of_leave__c= 'First Half Leave';
        e.Visit_Date__c = system.today().adddays(2);
        e.Subject  = 'Holiday';
        e.status__c = 'Sent for Approval';
        insert e;
        
        Event e1 = new Event();
        e1.WhatId=a.id;
        //e1.OwnerId = UserInfo.getUserId();
        e1.StartDateTime=system.today();
        e1.EndDateTime=system.today()+5;
        e1.Type_of_leave__c= 'First Half Leave';
        e1.Visit_Date__c = system.today();
        e1.Subject  = 'Holiday';
        e1.status__c = 'Sent for Approval';
        insert e1;
        
        Event e2 = new Event();
        e2.WhatId=a.id;
        //e2.OwnerId = UserInfo.getUserId();
        e2.StartDateTime=system.today();
        e2.EndDateTime=system.today()+5;
        e2.Type_of_leave__c= 'First Half Leave';
        e2.Visit_Date__c = system.today().adddays(-14);
        e2.Subject  = 'Holiday';
        e2.status__c = 'Sent for Approval';
        insert e2;
        
        eventList.add(e);
        eventList.add(e1);
        eventList.add(e2);
        CaptureAccountAndLeadHelper.updatevent(eventList);
        //CaptureAccountAndLeadHelper.updatbeatPlan(eventList);
        CaptureAccountAndLeadHelper.fakMethod();
    }
}
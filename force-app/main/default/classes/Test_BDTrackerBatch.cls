@isTest
public class Test_BDTrackerBatch {
    static testMethod void Test_BDTrackerBatch() {
        // Account
        Id AccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Domestic-Doctor/Hospital').getRecordTypeId();
        Account acc = new Account();
        acc.Name = 'Test_Account';
        acc.Commercial_Account_Name__c ='Test_Commercials';
        acc.Phone	='9087653';
        acc.GSTIN_No__c = '123565890';
        acc.Account_Type__c=  'Commercial';
        acc.RecordTypeId = AccRecordTypeId;
        acc.BillingCity = 'Pune';
        acc.BillingState = 'Maharashtra';
        acc.BillingCountry = 'India';
        acc.BillingStreet = 'Test123';
        acc.BillingPostalCode = '411045';
        insert acc;
        
        //Contact 
        Contact con = new Contact();
        con.LastName ='Test_Last';
        con.AccountId =acc.Id;
        con.MobilePhone ='908754333';
        insert con;
        
        //Product
        Product__c prod = new Product__c();
        prod.Name ='Test_Product';
        prod.Dummy_Product_Description__c =' dummy Product description';
        prod.Region__c ='International';
        prod.Planning__c ='yes';
        prod.Dummy_Product_Code__c ='465';
        prod.Active__c = true;
        insert prod;
        
        //BD Tracker
        BD_Tracker__c BDTrack = new BD_Tracker__c();
        BDTrack.Account__c=acc.Id;
        BDTrack.Contact__c = con.Id;
        BDTrack.Product__c =prod.Id;
        BDTrack.Stage__c ='Product Discussion';
        BDTrack.Product_Discussion_Plan_Week__c ='Week2	';
        BDTrack.Product_Discussion_Plan_Year__c ='2019';
        BDTrack.Evaluation_Planned_Week__c ='Week18	';
        BDTrack.Evaluation_Plan_Year__c = '2019';
        insert BDTrack;
        
        //BD Tracker2
        BD_Tracker__c BDTrack1 = new BD_Tracker__c();
        BDTrack1.Account__c=acc.Id;
        BDTrack1.Contact__c = con.Id;
        BDTrack1.Product__c =prod.Id;
        BDTrack1.Stage__c ='Closed Lost';
        BDTrack1.Reason_For_Cancel__c ='No Action Performed.';
        BDTrack1.Product_Discussion_Plan_Week__c ='Week2	';
        BDTrack1.Product_Discussion_Plan_Year__c ='2019';
        BDTrack1.Evaluation_Planned_Week__c ='Week18	';
        BDTrack1.Evaluation_Plan_Year__c = '2019';
        insert BDTrack1;
        
        //BatchPlanning
        BD_Tracker_Planning__c BDTrackPlan = new BD_Tracker_Planning__c();
        BDTrackPlan.Account__c = acc.Id;
        BDTrackPlan.Product__c = prod.Id;
        BDTrackPlan.BD_Tracker__c = BDTrack.Id;
        BDTrackPlan.Stage__c = 	'Evaluation	';
        BDTrackPlan.Milestone_Stage__c ='Plan';
        BDTrackPlan.Planned_Week__c ='Week16';
        BDTrackPlan.Planned_Year__c = '2019';
        insert BDTrackPlan;
        
        List<event>lstevent = new List<Event>();
        Id recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('BD Tracker').getrecordTypeId();
        event eventobj = new event();
        eventobj.WhatId = BDTrack.Id;
        eventobj.BD_Tracker_Planning__c = BDTrackPlan.Id;
        eventobj.Milestone_Stage__c = 'Delay';
        eventobj.RecordTypeId =recId;
        eventobj.Delay_Reason__c = 'No Action Performed';
        eventobj.BD_Tracker_Phase__c ='Evaluation';
        eventobj.StartDateTime = system.today().addDays(-7);
        System.debug('StartDate' +eventobj.StartDateTime);
        eventobj.EndDateTime = System.today().addDays(-5);
        system.debug('EndDate' +eventobj.EndDateTime);
        eventobj.ActivityDateTime = eventobj.StartDateTime;
        System.debug('ActivityDateTime' +eventobj.ActivityDateTime);
        insert eventobj ;
        
        BDTrackPlan.Id =eventobj.BD_Tracker_Planning__c;
        update  BDTrackPlan;
        
        BD_Tracker_History__c BDtrchis = new BD_Tracker_History__c();
        BDtrchis.Account__c = BDTrackPlan.Account__c;
        BDtrchis.Product__c = BDTrackPlan.Product__c;
        BDtrchis.Activity_Stage__c = 'Delay';
        BDtrchis.Activity_Year__c = string.Valueof(System.today().Year());
        BDtrchis.BD_Tracker_Planning__c = BDTrackPlan.Id;
        insert BDtrchis;
        
        
        Id recId1 = Schema.SObjectType.Event.getRecordtypeInfosByName().get('BD Tracker').getrecordTypeId();
        event eventobj1 = new event();
        eventobj1.BD_Tracker_Planning__c = BDTrackPlan.Id;
        eventobj1.Milestone_Stage__c = 'Delay';
        eventobj1.RecordTypeId =recId1;
        eventobj1.Delay_Reason__c = 'No Action Performed';
        eventobj1.BD_Tracker_Phase__c ='Product Discussion';
        eventobj1.StartDateTime = system.today().addDays(-7);
        System.debug('StartDate' +eventobj1.StartDateTime);
        eventobj1.EndDateTime = System.today().addDays(-5);
        system.debug('EndDate' +eventobj1.EndDateTime);
        eventobj1.ActivityDateTime = eventobj1.StartDateTime;
        System.debug('ActivityDateTime' +eventobj1.ActivityDateTime);
        eventobj1.WhatId = BDTrack.Id;
        insert eventobj1 ;
        
        Id recId2 = Schema.SObjectType.Event.getRecordtypeInfosByName().get('BD Tracker').getrecordTypeId();
        event eventobj2 = new event();
        eventobj2.BD_Tracker_Planning__c = BDTrackPlan.Id;
        eventobj2.Milestone_Stage__c = 'Plan';
        eventobj2.RecordTypeId =recId1;
        eventobj2.Delay_Reason__c = 'No Action Performed';
        eventobj2.BD_Tracker_Phase__c ='Commercialization';
        eventobj2.StartDateTime = system.today().addDays(-7);
        System.debug('StartDate' +eventobj2.StartDateTime);
        eventobj2.EndDateTime = System.today().addDays(-5);
        system.debug('EndDate' +eventobj2.EndDateTime);
        eventobj2.ActivityDateTime = eventobj2.StartDateTime;
        System.debug('ActivityDateTime' +eventobj2.ActivityDateTime);
        eventobj2.WhatId = BDTrack.Id;
        insert eventobj2;
        
        Id recId3 = Schema.SObjectType.Event.getRecordtypeInfosByName().get('BD Tracker').getrecordTypeId();
        event eventobj3 = new event();
        eventobj3.BD_Tracker_Planning__c = BDTrackPlan.Id;
        eventobj3.Milestone_Stage__c = 'Plan';
        eventobj3.RecordTypeId =recId3;
        eventobj3.Delay_Reason__c = 'No Action Performed';
        eventobj3.BD_Tracker_Phase__c ='Product Discussion';
        eventobj3.ActivityDateTime =Datetime.newInstance(2015, 20 , 12, 00, 00, 00);
        eventobj3.EndDateTime = Datetime.newInstance(2015, 20 , 12, 01, 00, 00);
        eventobj3.ActivityDateTime =Datetime.newInstance(2015, 20 , 12, 00, 00, 00);
        eventobj3.WhatId = BDTrack.Id;
        insert eventobj3;
        
        Id recId4 = Schema.SObjectType.Event.getRecordtypeInfosByName().get('BD Tracker').getrecordTypeId();
        event eventobj4 = new event();
        eventobj4.BD_Tracker_Planning__c = BDTrackPlan.Id;
        eventobj4.Milestone_Stage__c = 'Plan';
        eventobj4.RecordTypeId =recId4;
        eventobj4.Delay_Reason__c = 'No Action Performed';
        eventobj4.BD_Tracker_Phase__c ='Evaluation';
        eventobj4.ActivityDateTime =Datetime.newInstance(2015, 20 , 12, 00, 00, 00);
        eventobj4.EndDateTime = Datetime.newInstance(2015, 20 , 12, 01, 00, 00);
        eventobj4.ActivityDateTime =Datetime.newInstance(2015, 20 , 12, 00, 00, 00);
        eventobj4.WhatId = BDTrack.Id;
        insert eventobj4;
        
        Id recId5 = Schema.SObjectType.Event.getRecordtypeInfosByName().get('BD Tracker').getrecordTypeId();
        event eventobj5 = new event();
        eventobj5.BD_Tracker_Planning__c = BDTrackPlan.Id;
        eventobj5.Milestone_Stage__c = 'Plan';
        eventobj5.RecordTypeId =recId5;
        eventobj5.Delay_Reason__c = 'No Action Performed';
        eventobj5.BD_Tracker_Phase__c ='Commercialization';
        eventobj5.ActivityDateTime =Datetime.newInstance(2015, 20 , 12, 00, 00, 00);
        eventobj5.EndDateTime = Datetime.newInstance(2015, 20 , 12, 01, 00, 00);
        eventobj5.ActivityDateTime =Datetime.newInstance(2015, 20 , 12, 00, 00, 00);
        eventobj5.WhatId = BDTrack.Id;
        insert eventobj5;
        
        
        test.startTest();
        BDTrackerBatch batch = new BDTrackerBatch();
        database.executebatch(batch);
        database.BatchableContext bc;
        
        test.stopTest();
        
        
        
    }
}
@isTest
public class EventHandler_Test {
   
    
    public static testMethod void checkPhases()
    {
        try{
            User objUser = [Select id,Name,Profile.Name,isActive from User limit 1];  
            System.runAs(objUser){
                test.startTest();
                 List<Event> lstEv = [Select id,Milestone_stage__c,WhatId,BD_Tracker_Phase__c,Reason_for_Evaluation_Skip__c from event];
                Event e =new Event(); 
                e.WhatId = e.id;
                e.Milestone_Stage__c = 'Plan';
                e.Milestone_Delay_Reason__c = 'Replacing bd tracker product.';
                lstEv.add(e);
                // List<Event>  ev = TestDataFactory.createEvent(2);
                database.update(lstEv);
                           Date StartDate = Date.newInstance(system.today().Year(),System.today().Month(),1); 
           Date EndDate = Date.newInstance(system.today().Year(),System.today().Month(),Date.daysInMonth(system.today().Year(),System.today().Month()));
           BDT_Submission_History__c BDTHist = new BDT_Submission_History__c();
            //BDTHist.Name = 'abc' ;
            BDTHist.isSubmitted__c = true;
            BDTHist.Submission_Date__c = system.today();
            BDTHist.Submit_Count__c = 2;
            BDTHist.WeekRange__c ='2';
           // BDTHist.CreatedDate = Date.newInstance(system.today().Year(),System.today().Month(),3);
            insert BDTHist;
               // EventHandler.checkPhases(lstEv);  
               //  EventHandler.ValidateDelay(lstEv,lstEv);
                test.stopTest();
            } 
        }catch(Exception e){}
    }
    public static testMethod void createHistory()
        
    {
       //ist<BD_Tracker_Planning__c>lstPlanning = TestDataFactory.createBDPlanning(1);
        LIst<event> lstEventold = new List<Event>();
        Id evtRecID = Schema.SObjectType.Event.getRecordtypeinfosbyName().get('BD Tracker').getRecordtypeId();
        
         User objUser = [select id,Name,Profile.Name,isActive  from User where Profile.Name = 'System Administrator' AND isActive=true limit 1];
       System.runAs(objUser){
        Id accRecId = Constants.ACCOUNT_DOM_DISTRIBUTOR_RECORDTYPEID;
            
      //    Account objAcc = [Select id,Name from Account limit 1];
           Account objAcc=new Account();
           objAcc.Name='Test';
           insert objAcc;
            Product__c objProduct = new Product__c();
            objProduct.Name = 'Test123';
            objProduct.Dummy_Product_Code__c = 'Test456';
            objProduct.Planning__c = 'Yes';
            objProduct.Active__c = true;
            objProduct.Division__c = 'II';
            objProduct.Region__c = 'Domestic';
            objProduct.MSP__c =10;
            insert objProduct;
            
            Contact objContact = new Contact();
            objContact.AccountId = objAcc.Id;
            objContact.Email ='Test@test.com';
            objContact.Phone = '123456789';
            objContact.MobilePhone = '1234567890';
            objContact.LastName = 'Test';
            objContact.FirstName = 'Test';
            objContact.Salutation = 'Mr.';
            insert(objContact);
         BD_Tracker__c objBdTracker = new BD_Tracker__c();
            objBdTracker.isSubmitted__c = true;
            
            objBdTracker.Account__c = objAcc.Id;
            objBdTracker.Product__c = objProduct.id;
            objBdTracker.Contact__c = objContact.id;
            objBdTracker.Product_Discussion_Plan_Week__c = 'Week12';
            objBdTracker.Product_Discussion_Plan_Year__c = '2019';
            objBdTracker.Evaluation_Plan_Year__c = '2019';
            objBdTracker.Evaluation_Planned_Week__c = 'Week12';
            objBdTracker.Commercialization_Plan_Year__c = '2019';
            objBdTracker.Commercialization_Planned_Week__c = 'Week12';
            DAtabase.insert(objBdTracker);
        System.debug('objBdTracker'+[Select id,Name from BD_Tracker__c limit 1]);
        
        BD_Tracker_Planning__c BD_Track = new BD_Tracker_Planning__c();
        BD_Track.Actual_Week__c = 'week1';
        BD_Track.Actual_Year__c = '2019';
        BD_Track.BD_Tracker__c = objBdTracker.Id;
        BD_Track.Stage__c = 'Product Discussion';
            BD_Track.Milestone_Stage__c = 'Plan';
           BD_Track.Account__c=objAcc.Id;
        insert BD_Track;
        
           event objEvent = new Event();
           objEvent.BD_Tracker_Planning__c = BD_Track.Id;
           objEvent.RecordTypeId= evtRecID;
           objEvent.BD_Tracker_Phase__c ='Product Discussion';
           objEvent.Milestone_Stage__c = 'Plan';
           objEvent.DurationInMinutes = 20 ;
           objEvent.Milestone_Actual_Week__c='week1';
           objEvent.Milestone_Actual_Year__c= '2019';
           objEvent.Reason_for_Evaluation_Skip__c = 'Other';
           objEvent.Milestone_Delay_Reason__c= 'none';
           //  objEvent.Delay_Reason__c = dr;
           objEvent.ActivityDateTime =Datetime.newInstance(2015, 20 , 12, 00, 00, 00);
           objevent.EndDateTime = Datetime.newInstance(2015, 20 , 12, 01, 00, 00);
           objevent.ActivityDateTime =Datetime.newInstance(2015, 20 , 12, 00, 00, 00);
           objEvent.DurationInMinutes = 60;
           objevent.isSubmitted__c = true;
           objevent.whatId = objBdTracker.Id;
           lstEventold.add(objEvent);
           insert objEvent;
           
           objEvent.Milestone_Stage__c = 'Actual';
           update objEvent;
           
          
           event objEvent1 = new Event();
           objEvent1.BD_Tracker_Planning__c = BD_Track.Id;
           objEvent1.RecordTypeId= evtRecID;
           objEvent1.BD_Tracker_Phase__c ='Evaluation';
           objEvent1.Milestone_Stage__c = 'Plan';
           objEvent1.DurationInMinutes = 20 ;
           objEvent1.Milestone_Actual_Week__c='week1';
           objEvent1.Milestone_Actual_Year__c= '2019';
           objEvent1.Reason_for_Evaluation_Skip__c = 'Other';
           objEvent1.Milestone_Delay_Reason__c= 'none';
           //  objEvent.Delay_Reason__c = dr;
           objEvent1.ActivityDateTime =Datetime.newInstance(2015, 20 , 12, 00, 00, 00);
           objEvent1.EndDateTime = Datetime.newInstance(2015, 20 , 12, 01, 00, 00);
           objEvent1.ActivityDateTime =Datetime.newInstance(2015, 20 , 12, 00, 00, 00);
           objEvent1.DurationInMinutes = 60;
           objEvent1.isSubmitted__c = true;
           objEvent1.whatId = objBdTracker.Id;
          
           insert objEvent1;
           
           objEvent1.Milestone_Stage__c = 'Actual';
           update objEvent1;
         
            
           event objEvent12 = new Event();
           objEvent12.BD_Tracker_Planning__c = BD_Track.Id;
           objEvent12.RecordTypeId= evtRecID;
           objEvent12.BD_Tracker_Phase__c ='Evaluation';
           objEvent12.Milestone_Stage__c = 'Plan';
           objEvent12.DurationInMinutes = 20 ;
           objEvent12.Milestone_Actual_Week__c='week1';
           objEvent12.Milestone_Actual_Year__c= '2019';
           objEvent12.Reason_for_Evaluation_Skip__c = 'Other';
           objEvent12.Milestone_Delay_Reason__c= 'none';
           //  objEvent.Delay_Reason__c = dr;
           objEvent12.ActivityDateTime =Datetime.newInstance(2015, 20 , 12, 00, 00, 00);
           objEvent12.EndDateTime = Datetime.newInstance(2015, 20 , 12, 01, 00, 00);
           objEvent12.ActivityDateTime =Datetime.newInstance(2015, 20 , 12, 00, 00, 00);
           objEvent12.DurationInMinutes = 60;
           objEvent12.isSubmitted__c = true;
           objEvent12.whatId = objBdTracker.Id;
          
           insert objEvent12;
           
           objEvent12.Milestone_Stage__c = 'Actual';
           update objEvent12;
         
            
        }
        
    }
    


}
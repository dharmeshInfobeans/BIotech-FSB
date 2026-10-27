/********************************************************************************
Author : Prashant Rana
Description : This is the test class for DCR and Mobile App
Date : 01-01-2019
********************************************************************************/
@isTest
public class DCRAllTest {
    
    @TestSetup
    static void makeData(){
        Id recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('DCR Planning').getrecordTypeId();
        Id recIdBD = Schema.SObjectType.Event.getRecordtypeInfosByName().get('BD Tracker').getrecordTypeId();
        List<User> testuser= [select id,Profile.Name,isActive from User where Profile.Name = 'System Administrator' AND isActive = True limit 1];
        
        //User testuser=TestDataFactory.createUserData('System Administrator'
        SYstem.runas(testuser[0]){
            Id evtRecID = Schema.SObjectType.Event.getRecordtypeinfosbyName().get('BD Tracker').getRecordtypeId();
            
            beat_Plan__c beatobj = new beat_Plan__c();
            beatobj.beat_date__c = date.today();
            beatobj.Assigned_To__c=UserInfo.getUserId();
            
            insert beatobj;
            
            CIty__c robj = new CIty__c();
            robj.country_key__c = 'IN';
            robj.Name = 'Maharashtra';
            robj.Region_Code__c = '24';
            insert robj;
            
            Account accObj = new Account();
            accObj.Name = 'Test';
            accObj.AccountNumber = '12345678';
            accObj.region__c = robj.Id;
            accObj.BillingCity = 'Pune';
            accObj.BillingCountry = 'India';
            accObj.BillingState = 'Maharashtra';
            accobj.BillingPostalCode = '411045';
            accobj.BillingStreet = 'Baner';
            accObj.Street_2__c = 'street2';
            accObj.Street_3__c = 'street3';
            accObj.Street_4__c = 'street4';
            accObj.Street_5__c = 'street5';
            accObj.Country_Key__c='IN';
            accObj.City__c='Mumbai';
            accObj.City_postal_code__c='400001';
            accObj.Medical_Registration_No__c = '123';
            accObj.GSTIN_No__c = 'AF122345678912F';
            
            insert accObj;
            
            
            event obj = new event();
            obj.subject = 'test';
            obj.startDateTime = system.now();
            obj.endDateTime = System.now().addDays(1);
            obj.Beat_Plan__c = beatobj.id;
            obj.Checkout__Latitude__s = 77.0000;
            obj.Checkout__Longitude__s = 24.0000;
            obj.whatId = accObj.id;
            obj.RecordTypeId = recId;
            insert obj;
            
            Product__c pobj = new Product__c();
            pobj.Region__c ='Domestic';
            pobj.Dummy_Product_Code__c = '123';
            insert pobj;
            
            Contact objContact = new Contact();
            objContact.AccountId = accObj.Id;
            objContact.Email ='Test@test.com';
            objContact.Phone = '123456789';
            objContact.MobilePhone = '1234567890';
            objContact.LastName = 'Test';
            objContact.FirstName = 'Test';
            objContact.Salutation = 'Mr.';
            insert(objContact);
            Product__c objProduct = new Product__c();
            objProduct.Name = 'Test123';
            objProduct.Dummy_Product_Code__c = 'Test456';
            objProduct.Planning__c = 'Yes';
            objProduct.Active__c = true;
            objProduct.Division__c = 'II';
            objProduct.Region__c = 'Domestic';
            objProduct.MSP__c =10;
            insert objProduct;
            
            BD_Tracker__c objBdTracker = new BD_Tracker__c();
            objBdTracker.isSubmitted__c = true;
            
            objBdTracker.Account__c = accObj.Id;
            objBdTracker.Product__c = objProduct.id;
            objBdTracker.Contact__c = objContact.id;
            objBdTracker.Product_Discussion_Plan_Week__c = 'Week12';
            objBdTracker.Product_Discussion_Plan_Year__c = '2019';
            objBdTracker.Evaluation_Plan_Year__c = '2019';
            objBdTracker.Evaluation_Planned_Week__c = 'Week12';
            objBdTracker.Commercialization_Plan_Year__c = '2019';
            objBdTracker.Commercialization_Planned_Week__c = 'Week12';
            objBdTracker.Manager_Email__c = 'snehal.suryawanshi@digicloudsolns.com';
            objBdTracker.RSM_Email__c = 'snehal.suryawanshi@digicloudsolns.com';
            DAtabase.insert(objBdTracker);
            System.debug('objBdTracker'+[Select id,Name from BD_Tracker__c limit 1]);
            
            BD_Tracker_Planning__c BD_Track = new BD_Tracker_Planning__c();
            BD_Track.Actual_Week__c = 'week1';
            BD_Track.Actual_Year__c = '2019';
            BD_Track.BD_Tracker__c = objBdTracker.Id;
            BD_Track.Stage__c = 'Product Discussion';
            BD_Track.Milestone_Stage__c = 'Plan';
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
            objEvent.isConnectedToDCR__c =true;
            objevent.whatId = objBdTracker.Id;
            objEvent.Account__c = accObj.Id;
            objEvent.WhoId =  objContact.Id;
            insert objEvent;
            
            event objEventEV = new Event();
            objEventEV.BD_Tracker_Planning__c = BD_Track.Id;
            objEventEV.RecordTypeId= evtRecID;
            objEventEV.BD_Tracker_Phase__c ='Evaluation';
            objEventEV.Milestone_Stage__c = 'Plan';
            objEventEV.DurationInMinutes = 20 ;
            objEventEV.Milestone_Actual_Week__c='week1';
            objEventEV.Milestone_Actual_Year__c= '2019';
            objEventEV.Reason_for_Evaluation_Skip__c = 'Other';
            objEventEV.Milestone_Delay_Reason__c= 'none';
            //  objEvent.Delay_Reason__c = dr;
            objEventEV.ActivityDateTime =Datetime.newInstance(2015, 20 , 12, 00, 00, 00);
            objEventEV.EndDateTime = Datetime.newInstance(2015, 20 , 12, 01, 00, 00);
            objEventEV.ActivityDateTime =Datetime.newInstance(2015, 20 , 12, 00, 00, 00);
            objEventEV.DurationInMinutes = 60;
            objEventEV.isSubmitted__c = true;
            objEventEV.isConnectedToDCR__c =true;
            objEventEV.whatId = objBdTracker.Id;
            objEventEV.Account__c = accObj.Id;
            objEventEV.WhoId =  objContact.Id;
            insert objEventEV;  
        }
    }
    /*
Class to Cover : DailyCallRecordController
Coverage : 90%
*/
    public static testmethod void dailyCallrecord(){
        
        test.startTest();
        
        Profile p = [select id, name from Profile where name = 'System Administrator'];
        User usr = new User(            
            ProfileId = p.id,
            LastName = 'Test usr',
            Email = 'testUser@gmail.com',
            Username = 'testUser@gmail.com' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            // UserRoleId = roleId,
            //Employee_Code__c = empCode,
            //Division__c = division,
            //User_Type__c =region,
            isActive = true,
            // ContactId = contactId,
            Date_of_Joining__c = system.today());
        //Portal_User_Role__c = 'RBM');
        insert usr;
        
        beat_Plan__c beatobj = new beat_Plan__c();
        beatobj.beat_date__c = date.today();
        beatobj.Assigned_To__c=UserInfo.getUserId();
        
        insert beatobj;
        
        //Account accObj = [select id , name, ownerId from Account];
        Account accObj = [select id , name, ownerId from Account where name = 'Test'];
        
        Contact objContact = new Contact();
        objContact.AccountId = accObj.Id;
        objContact.Email ='Test@test.com';
        objContact.Phone = '123456789';
        objContact.MobilePhone = '1234567890';
        objContact.LastName = 'Test';
        objContact.FirstName = 'Test';
        objContact.Salutation = 'Mr.';
        insert(objContact);
        
        //user objUser = [Select id,Profile.Name,isActive from User where Profile.Name='System Administrator' AND isActive=true limit 1];
        
        LIst<Event> obj = [select id,OwnerId from event];
        
        
        DailyCallRecordController.getUserData(accObj.OwnerId);
        DailyCallRecordController.returnHomePage();
        
        Id evtRecID = Schema.SObjectType.Event.getRecordtypeinfosbyName().get('BD Tracker').getRecordtypeId();
        Id accRecId = Constants.ACCOUNT_DOM_DISTRIBUTOR_RECORDTYPEID;
        
        List<CIty__c> lstRegion = TestDataFactory.createRegionData(1, 'Delhi', '30', 'IN');
        lstRegion[0].Zone_Code__c ='1';
        update lstRegion; 
        //  List<Account>lstAccount2 = TestDataFactory.createAccountData(4, accRecId, lstRegion[0]);
        List<User_Region_Association__c> lstAssociation = TestDataFactory.createUserRegionAssociationData(1, usr, lstRegion[0]);
        Product__c objProduct = new Product__c();
        objProduct.Name = 'Test123';
        objProduct.Dummy_Product_Code__c = 'Test456';
        objProduct.Planning__c = 'Yes';
        objProduct.Active__c = true;
        objProduct.Division__c = 'II';
        objProduct.Region__c = 'Domestic';
        objProduct.MSP__c =10;
        insert objProduct;
        
        BD_Tracker__c objBdTracker = new BD_Tracker__c();
        objBdTracker.isSubmitted__c = true;
        
        objBdTracker.Account__c = accObj.Id;
        objBdTracker.Product__c = objProduct.id;
        objBdTracker.Contact__c = objContact.id;
        objBdTracker.Product_Discussion_Plan_Week__c = 'Week12';
        objBdTracker.Product_Discussion_Plan_Year__c = '2019';
        objBdTracker.Evaluation_Plan_Year__c = '2019';
        objBdTracker.Evaluation_Planned_Week__c = 'Week12';
        objBdTracker.Commercialization_Plan_Year__c = '2019';
        objBdTracker.Commercialization_Planned_Week__c = 'Week12';
        objBdTracker.Manager_Email__c = 'snehal.suryawanshi@digicloudsolns.com';
        objBdTracker.RSM_Email__c = 'snehal.suryawanshi@digicloudsolns.com';
        DAtabase.insert(objBdTracker);
        System.debug('objBdTracker'+[Select id,Name from BD_Tracker__c limit 1]);
        
        BD_Tracker_Planning__c BD_Track = new BD_Tracker_Planning__c();
        BD_Track.Actual_Week__c = 'week1';
        BD_Track.Actual_Year__c = '2019';
        BD_Track.BD_Tracker__c = objBdTracker.Id;
        BD_Track.Stage__c = 'Product Discussion';
        BD_Track.Milestone_Stage__c = 'Plan';
        insert BD_Track;
        
        event objEvent = new Event();
        objEvent.BD_Tracker_Planning__c = BD_Track.Id;
        objEvent.RecordTypeId= evtRecID;
        objEvent.Beat_plan__c=beatobj.Id;
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
        objEvent.Account__c = accObj.Id;
        objEvent.WhoId =  objContact.Id;
        insert objEvent;
        
        event objEvent1 = new Event();
        objEvent1.BD_Tracker_Planning__c = BD_Track.Id;
        objEvent1.RecordTypeId= evtRecID;
        objEvent1.Beat_plan__c=beatobj.Id;
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
        objEvent1.Account__c = accObj.Id;
        objEvent1.WhoId =  objContact.Id;
        insert objEvent1;
        
        DailyCallRecordController DCRobj = new DailyCallRecordController();
        DCRobj.accountData = JSON.serialize(accObj);
        DCRobj.eventData = JSOn.serialize(obj);
        
        
        
        string request = '[{"subject":"subject","date":"2019-10-10","startTime":"10:00","endTime":"11:00","ownerId":"",'+
            +'"callType":"OT","relatedTo":"'+accObj.Id+'","isJoint":false,"remarkDoctor":"","marketInfo":"","remarkTender":"",'+
            +'"surgery":"","pmsCollected":"","contactId":"'+objContact.ID+'","doctorVisit":"","address":"", "name":"","nextVisitPlanning":"",'+
            +'"employeeName":"test data","toPlace":"test data","fromPlace":"test data","month":"9","week":"6","dayTravel":"89",'+
            +' "ToDate":"2019-01-02","country":"india","FromDate":"2019-02-01","description":"test","product":"600","ownerId":"'+obj[0].OwnerId+'",'+
            +'"evt":"'+objEvent.Id+'"}]';
        
        map<string,object> r1 = new map<string,object>();
        r1.put('eventId',obj[0].Id);
        r1.put('date','2019-10-10');
        r1.put('startTime','11:00');
        r1.put('endTime','11:05');
        r1.put('status', 'submitAndSave');
        r1.put('product', '600');
        r1.put('folloUpDate', '20-20-2020');
        r1.put('description','Testing');
        r1.put('contactId',objContact.ID);
        r1.put('eventId',objEvent.Id);
        r1.put('evtIdValue',objEvent.Id);
        
        DailyCallRecordController.createNewEvents(request);
        DailyCallRecordController.updateEvent(r1);
        DailyCallRecordController.deleteEvent(obj[0].Id);
        DCRobj.dateVal = String.valueOf(System.today());
        
        DailyCallRecordController objDCR1 = new DailyCallRecordController();
        objDCR1.accIdUpdate = accObj.Id;
        objDCR1.dateVal = String.valueOf(System.today());
        objDCR1.showPopup();
        
        DCRobj.accId = accObj.Id;
        DailyCallRecordController.weeknumber(Date.valueOf(System.today()));
        DCRobj.showPopup();
        DCRobj.closePopup();
        DCRobj.saveBdPlan();
        //DCRobj.openLinkBD();
        DCRobj.setDeafultWrapper();
        DailyCallRecordController.fakMethod();
        test.stopTest();
        
    }
    
    /*********************************************************************************
Class to Cover : BeatPlanMapPageController
Coverage : 85%
*********************************************************************************/
    @IsTest
    static void BeatPlanMapPageController(){
        
        Test.startTest();
        Id evtRecID = Schema.SObjectType.Event.getRecordtypeinfosbyName().get('BD Tracker').getRecordtypeId();
        
        
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
        beat_Plan__c beatobj = new beat_Plan__c();
        beatobj.beat_date__c = date.today();
        beatobj.Assigned_To__c=UserInfo.getUserId();
        
        insert beatobj;
        
        Lead__c lea=new Lead__c();
        lea.Name='tets';
        lea.First_Name__c='test';
        lea.Last_Name__c='singh';
        lea.Company__c='Plus91labs';
        lea.Product__c='BIO HYALUR CS';
        lea.Billing_City__c='Gwalior';
        lea.Billing_code__c='474001';
        lea.Country__c='INDIA';
        lea.Billing_state__c='Mp';
        lea.Billing_country__c='india';
        lea.Email__c='pankajsinghania123@gmail.com';
        lea.Mobile__c='1234567890';
        lea.Billing_Street__c='chandranagr koteshwar';
        lea.SAP_Code__c='12343122';
        lea.Lead_Stage__c='Presentation';
        lea.CE_CIS_Approval__c=true;
        lea.Status__c=true;
        insert lea;
        Account accObj = [select id , name, ownerId from Account];
        
        event objEvent1 = new Event();
        //    objEvent1.BD_Tracker_Planning__c = BD_Track.Id;
        objEvent1.RecordTypeId= evtRecID;
        objEvent1.Beat_plan__c=beatobj.Id;
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
        //   objEvent1.whatId = objBdTracker.Id;
        objEvent1.Account__c = accObj.Id;
        //  objEvent1.WhoId =  objContact.Id;
        insert objEvent1;
        
        
        
        LIst<Event> obj = [select id from Event];
        BeatPlanMapPageController beatPlanObj = new BeatPlanMapPageController();
        Map<String,Object> startDayMap = new Map<String,Object>{
            'UserLatitude' => 77.288,
                'UserLongitude'=> 24.000
                };
                    Map<String,Object> mapData = new Map<String,Object>{
                        'CheckInLat'=>77.23546,
                            'CheckInLong'=>77.8768,
                            'eventId'=>objEvent1.id,
                            'whatId'=>lea.Id,
                            'Stage'=>'Presentation'
                            };
                                Map<String,Object> updateMap = new Map<String,Object>{
                                    'startTime'=>system.now(),
                                        'endTime'=>system.now()+1,
                                        'reason'=>'testreason',
                                        'date'=>'2019-02-02',
                                        'eventId'=>obj[0].Id
                                        };
                                            //BeatPlanMapPageController.updateAccount('id', 77.288, 24.000);
                                            // BeatPlanMapPageController.startMyDay(startDayMap);
                                            //  BeatPlanMapPageController.endMyDay(startDayMap); 
                                            BeatPlanMapPageController.checkInMethod(mapData);
        BeatPlanMapPageController.checkOutMethod(mapData);
      //  BeatPlanMapPageController.updateCancelEvent('cancel', updateMap);
        BeatPlanMapPageController.GetBasicUrl();
        BeatPlanMapPageController.updateAccount(accobj.Id, 19.70, 18.80);
        
        BeatPlanMapPageController.checkOutMethodToGoIn(mapData);
        BeatPlanMapPageController.fakMethod();
        Test.stopTest();
        
    }
    
    /******************************************************************************************
Class to Cover : BeatPlanSecondAppPageController
Coverage : 90%
*******************************************************************************************/
    
    @IsTest
    static void BeatPlanSecondAppPageController(){
        Id evtRecID = Schema.SObjectType.Event.getRecordtypeinfosbyName().get('BD Tracker').getRecordtypeId();
        
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
        beat_Plan__c beatobj = new beat_Plan__c();
        beatobj.beat_date__c = date.today();
        beatobj.Assigned_To__c=UserInfo.getUserId();
        
        insert beatobj;
        
        Lead__c lea=new Lead__c();
        lea.Name='tets';
        lea.First_Name__c='test';
        lea.Last_Name__c='singh';
        lea.Company__c='Plus91labs';
        lea.Product__c='BIO HYALUR CS';
        lea.Billing_City__c='Gwalior';
        lea.Billing_code__c='474001';
        lea.Country__c='INDIA';
        lea.Billing_state__c='Mp';
        lea.Billing_country__c='india';
        lea.Email__c='pankajsinghania123@gmail.com';
        lea.Mobile__c='1234567890';
        lea.Billing_Street__c='chandranagr koteshwar';
        lea.SAP_Code__c='12343122';
        lea.Lead_Stage__c='Presentation';
        lea.CE_CIS_Approval__c=true;
        lea.Status__c=true;
        insert lea;
        Account accObj = [select id , name, ownerId from Account where name = 'Test'];
        
        
        event objEvent1 = new Event();
        //    objEvent1.BD_Tracker_Planning__c = BD_Track.Id;
        objEvent1.RecordTypeId= evtRecID;
        objEvent1.Beat_plan__c=beatobj.Id;
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
        //   objEvent1.whatId = objBdTracker.Id;
        objEvent1.Account__c = accObj.Id;
        //  objEvent1.WhoId =  objContact.Id;
        insert objEvent1;
        
        List<User> testuser= [select id,Profile.Name,isActive from User where Profile.Name = 'System Administrator' AND isActive = True limit 1];
        System.runAs(testuser[0]){
            Test.startTest();
            Id evtRecDCRID = Schema.SObjectType.Event.getRecordtypeinfosbyName().get('DCR Planning').getRecordtypeId();
            Id evtRecBDID = Schema.SObjectType.Event.getRecordtypeinfosbyName().get('BD Tracker').getRecordtypeId();
            event obj = [select id from Event where recordtypeId=:evtRecDCRID];
            List<event> lstobj = [select id from Event where recordtypeId=:evtRecBDID ];    
            test.setCurrentPage( new Pagereference('BeatPlanSecondAppPage'));
            System.currentPageReference().getParameters().put('id', obj.Id);
            BeatPlanSecondAppPageController beatSecond = new BeatPlanSecondAppPageController();
            Map<String,Object> dataMap = new Map<String,Object>{
                'remark'=>'test',
                    'followUpDate'=>'2019-02-02',
                    'eventId'=>objEvent1.id,
                    'product'=>'600',
                    'skipReason'=>lstobj[0].ID+':Test,'+lstobj[1].Id+':TEst',
                    'BDReason'=>lstobj[0].ID+':Test,'+lstobj[1].Id+':TEst',
                    'BDPlan'=>lstobj[0].ID+':Test,'+lstobj[1].Id+':TEst',
                    'whatId'=>lea.Id,
                    'Stage'=>'Presentation'
                    };
                        Map<String,Object> dataMap1 = new Map<String,Object>{
                            'remark'=>'test',
                                'followUpDate'=>'2019-02-02',
                                'eventId'=>objEvent1.id,
                                'product'=>'600',
                                'skipReason'=>lstobj[0].ID+':Test,'+lstobj[1].Id+':TEst',
                                'BDReason'=>lstobj[0].ID+':Test,'+lstobj[1].Id+':TEst',
                                'BDPlan'=>lstobj[0].ID+':Test,'+lstobj[1].Id+':TEst',
                                'whatId'=>lea.Id,
                                'Stage'=>'Appointments'
                                };
                                    Map<String,Object> dataMap2 = new Map<String,Object>{
                                        'remark'=>'test',
                                            'followUpDate'=>'2019-02-02',
                                            'eventId'=>objEvent1.id,
                                            'product'=>'600',
                                            'skipReason'=>lstobj[0].ID+':Test,'+lstobj[1].Id+':TEst',
                                            'BDReason'=>lstobj[0].ID+':Test,'+lstobj[1].Id+':TEst',
                                            'BDPlan'=>lstobj[0].ID+':Test,'+lstobj[1].Id+':TEst',
                                            'whatId'=>lea.Id,
                                            'Stage'=>'Presentation'
                                            };
                                                Map<String,Object> dataMap3 = new Map<String,Object>{
                                                    'remark'=>'test',
                                                        'followUpDate'=>'2019-02-02',
                                                        'eventId'=>objEvent1.id,
                                                        'product'=>'600',
                                                        'skipReason'=>lstobj[0].ID+':Test,'+lstobj[1].Id+':TEst',
                                                        'BDReason'=>lstobj[0].ID+':Test,'+lstobj[1].Id+':TEst',
                                                        'BDPlan'=>lstobj[0].ID+':Test,'+lstobj[1].Id+':TEst',
                                                        'whatId'=>lea.Id,
                                                        'Stage'=>'Product Demo'
                                                        };
                                                            Map<String,Object> dataMap4 = new Map<String,Object>{
                                                                'remark'=>'test',
                                                                    'followUpDate'=>'2019-02-02',
                                                                    'eventId'=>objEvent1.id,
                                                                    'product'=>'600',
                                                                    'skipReason'=>lstobj[0].ID+':Test,'+lstobj[1].Id+':TEst',
                                                                    'BDReason'=>lstobj[0].ID+':Test,'+lstobj[1].Id+':TEst',
                                                                    'BDPlan'=>lstobj[0].ID+':Test,'+lstobj[1].Id+':TEst',
                                                                    'whatId'=>lea.Id,
                                                                    'Stage'=>'Evaluations'
                                                                    };
                                                                        Map<String,Object> mapData = new Map<String,Object>{
                                                                            'CheckInLat'=>77.23546,
                                                                                'CheckInLong'=>77.8768,
                                                                                'eventId'=>objEvent1.id,
                                                                                'skipReason'=>lstobj[0].ID+':Test,'+lstobj[1].Id+':TEst',
                                                                                'BDReason'=>lstobj[0].ID+':Test,'+lstobj[1].Id+':TEst',
                                                                                'BDPlan'=>lstobj[0].ID+':Test,'+lstobj[1].Id+':TEst',
                                                                                'whatId'=>lea.Id,
                                                                                'Stage'=>'Presentation'
                                                                                
                                                                                };
                                                                                   
            Map<String,Object> dataUpdateMap=new Map<String,Object>{'Id'=>lea.Id,'Stage'=>'Presentation'};
            string data=JSON.serialize(dataMap);
             BeatPlanSecondAppPageController.saveDCR(dataMap1,data,mapData);
             BeatPlanSecondAppPageController.saveDCR(dataMap,data,mapData);
            BeatPlanSecondAppPageController.saveDCR(dataMap2,data,mapData);
            BeatPlanSecondAppPageController.saveDCR(dataMap3,data,mapData);
            BeatPlanSecondAppPageController.saveDCR(dataMap4,data,mapData);
            BeatPlanSecondAppPageController.submitDCR(dataMap);
            BeatPlanSecondAppPageController.checkOutMethod(mapData);
            BeatPlanSecondAppPageController.returnHomePage();
            BeatPlanSecondAppPageController.weeknumber(System.today());
            BeatPlanSecondAppPageController.fakMethod();
            
            
            
            Test.stopTest();
            
        }
    }
}
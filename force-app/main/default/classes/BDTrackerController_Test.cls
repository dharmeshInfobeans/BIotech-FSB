/********************************************
* @Class Name   : BDTrackerController_Test
* @Description  : It is test class for the class BDTrackerController
* @Created Date : 03-12-2019
* @Created By   : Rajesh N. 
* ****************************************/ 
@isTest
public class BDTrackerController_Test {
    
    @testSetup
    public static void createData(){
        User objUser = [select id,Profile.Name,isActive  from User where Profile.Name = 'System Administrator' AND isActive = True limit 1];//TestDataFactory.createUserData('System Administrator');
        System.runas(objUser){
            Test.startTest();
            Id evtRecID = Schema.SObjectType.Event.getRecordtypeinfosbyName().get('BD Tracker').getRecordtypeId();
            Id accRecId = Constants.ACCOUNT_DOM_DISTRIBUTOR_RECORDTYPEID;
            
            List<CIty__c> lstRegion = TestDataFactory.createRegionData(1, 'Delhi', '30', 'IN');
            List<Account>lstAccount = TestDataFactory.createAccountData(1, accRecId, lstRegion[0]);
            //List<Product__c> lstProduct = TestDataFactory.createProductData();
            List<User_Region_Association__c> lstAssociation = TestDataFactory.createUserRegionAssociationData(1, objUser, lstRegion[0]);
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
            objContact.AccountId = lstAccount[0].Id;
            objContact.Email ='Test@test.com';
            objContact.Phone = '123456789';
            objContact.MobilePhone = '1234567890';
            objContact.LastName = 'Test';
            objContact.FirstName = 'Test';
            objContact.Salutation = 'Mr.';
            insert(objContact);
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
            BD_Tracker__c objBdTracker = new BD_Tracker__c();
            objBdTracker.isSubmitted__c = true;
            
            objBdTracker.Account__c = lstAccount[0].Id;
            objBdTracker.Product__c = objProduct.id;
            objBdTracker.Contact__c = objContact.id;
            objBdTracker.Product_Discussion_Plan_Week__c = 'Week12';
            objBdTracker.Product_Discussion_Plan_Year__c = '2019';
            objBdTracker.Evaluation_Plan_Year__c = '2019';
            objBdTracker.Evaluation_Planned_Week__c = 'Week12';
            objBdTracker.Commercialization_Plan_Year__c = '2019';
            objBdTracker.Commercialization_Planned_Week__c = 'Week12';
            DAtabase.insert(objBdTracker);
            List<Event>lstEvent = TestDataFactory.createEvent(1);
            lstEvent[0].DurationInMinutes = 3;
            BDT_Submission_History__c objSubHistory = new BDT_Submission_History__c();
            objSubHistory.isSubmitted__c = True;
            objSubHistory.Submission_Date__c = Date.valueOf(System.today());
            objSubHistory.Submit_Count__c =1; 
            
            objSubHistory.WeekRange__c = '1-5';
           
            objSubHistory.Last_Submit_Date__c = Date.valueOf(System.today());
            insert objSubHistory;
            Test.stopTest();
        }
    }
    
    public static testMethod void testWrapper(){
        //try{
        User objUser = [select id,Profile.Name,isActive  from User where Profile.Name = 'System Administrator' AND isActive = True limit 1];
        System.runas(objUser){
            
        BDTrackerController.BDTrackerWrapper objwrap = new  BDTrackerController.BDTrackerWrapper();
        List<BDTrackerController.BDTrackerWrapper>lstWrap = new List<BDTrackerController.BDTrackerWrapper>();
        List<BDTrackerController.BDTrackerWrapper>lstWrapNew = new List<BDTrackerController.BDTrackerWrapper>();
        Account objAccount = [Select id,Name from Account limit 1];
        Contact objContact = [Select id,lastName from Contact limit 1];
        BD_Tracker__c objTracker = [Select id from BD_Tracker__c limit 1];
        Product__c objProduct = [Select id from Product__c limit 1];
        objwrap.BDrecId =null;
        objwrap.CommWeek = '12';
        objwrap.EvalWeek = '12';
        objwrap.ProdWeek = '12';
        objwrap.CommYear = '2020';
        objwrap.EvalYear = '2020';
        objwrap.ProdYear = '2020';
        objwrap.objProduct = objProduct;
        objwrap.Status = 'New';
        objwrap.objAccount = objAccount;
        objWrap.objcontact = objContact;
        
        List<BDTrackerController.StageWrapper>lstWeek = new List<BDTrackerController.StageWrapper>();
        BDTrackerController.StageWrapper objWeek1 = new BDTrackerController.StageWrapper();
        objWeek1.stageName = 'Product Discussion';
        BDTrackerController.StageWrapper objWeek2 = new BDTrackerController.StageWrapper();
        objWeek2.stageName = 'Evaluation';
        BDTrackerController.StageWrapper objWeek3 = new BDTrackerController.StageWrapper();
        objWeek3.stageName = 'Commercialization';
        
        lstWeek.add(objweek1);
        lstWeek.add(objweek2);
        lstWeek.add(objweek3);
        objWrap.lstStages = lstWeek;
        
        
        
        lstWrap.add(objWrap);
        String objbString = JSON.serialize(lstWrap);
        System.debug('objbString'+objbString);
        
        test.startTest();
        BDTrackerController.BDTrackerSave(objbString, true, '11',objUser.Id,2020);   
        test.stopTest();
        /*****************************************************/
        BDTrackerController.BDTrackerWrapper objwrap1 = new  BDTrackerController.BDTrackerWrapper();
        Account objAccount1 = [SELECT Id,Name,CIS_Rating__c,CE_Rating__c,SAP_Code__c from Account limit 1 ];
        Contact objContact1 = [Select id,lastName from Contact];
        
        
        BD_Tracker__c bdTrack = [Select id,Name,Stage__c from BD_Tracker__c limit 1];
        Product__c objProduc1t = [Select id from Product__c];
        BD_Tracker__c objTracker1 = [Select id from BD_Tracker__c limit 1];
        BD_Tracker_Planning__c objPL = [Select id,Stage__c from BD_Tracker_Planning__c where Stage__c ='Product Discussion' limit 1];
        BD_Tracker_Planning__c objev = [Select id,Stage__c from BD_Tracker_Planning__c where Stage__c ='Evaluation' limit 1];
        BD_Tracker_Planning__c objcm = [Select id,Stage__c from BD_Tracker_Planning__c where Stage__c ='Commercialization' limit 1];
        BD_Tracker_History__c objHp = [Select id,bd_Tracker_Planning__c from BD_Tracker_History__c where bd_Tracker_Planning__c=:objPL.Id limit 1];
        BD_Tracker_History__c objHe = [Select id,bd_Tracker_Planning__c from BD_Tracker_History__c where bd_Tracker_Planning__c=:objev.Id limit 1];
        BD_Tracker_History__c objHc = [Select id,bd_Tracker_Planning__c from BD_Tracker_History__c where bd_Tracker_Planning__c=:objcm.Id limit 1];
        Event pevt = [Select id,bd_Tracker_Planning__c from event where bd_Tracker_Planning__c=:objPL.Id];
        Event eevt = [Select id,bd_Tracker_Planning__c from event where bd_Tracker_Planning__c=:objev.Id];
        Event cevt = [Select id,bd_Tracker_Planning__c from event where bd_Tracker_Planning__c=:objcm.Id];
        
      /*  objTracker1.OwnerId = objUser.Id;
        objTracker1.Stage__c = 'Product Discussion';
        Update objTracker1; */
        objwrap1.prodEvtRecId = pevt.id;
        objwrap1.evalEvtRecId = eevt.id;
        objwrap1.commEvtRecId = cevt.id;
        objwrap1.BDrecId = bdTrack.id;
        objwrap1.prodRecId =objPL.id;
        objwrap1.evalRecId = objev.id;
        objwrap1.commRecId = objcm.Id;
        objwrap1.prodHRecId = objHp.Id;
        objwrap1.evalHRecId = objHe.Id;
        objwrap1.commHRecId = objHc.Id;
        
        //objwrap1.BDrecId =null;
        objwrap1.CommWeek = '46';
        objwrap1.EvalWeek = '45';
        objwrap1.ProdWeek = '44';
        objwrap1.CommYear = '2019';
        objwrap1.EvalYear = '2019';
        objwrap1.ProdYear = '2019';
        objwrap1.objProduct = objProduct;
        objwrap1.Status = 'New';
        objwrap1.objAccount = objAccount;
        objWrap1.objcontact = objContact;
        
        List<BDTrackerController.StageWrapper>lstWeek1 = new List<BDTrackerController.StageWrapper>();
        BDTrackerController.StageWrapper objWeek11 = new BDTrackerController.StageWrapper();
        objWeek11.stageName = 'Product Discussion';
        BDTrackerController.StageWrapper objWeek21 = new BDTrackerController.StageWrapper();
        objWeek21.stageName = 'Evaluation';
        BDTrackerController.StageWrapper objWeek31 = new BDTrackerController.StageWrapper();
        objWeek31.stageName = 'Commercialization';
        
        lstWeek1.add(objweek11);
        lstWeek1.add(objweek21);
        lstWeek1.add(objweek31);
        objWrap1.lstStages = lstWeek1;
        
        
        
        lstWrap.add(objWrap1);
        System.debug('lstWrap'+lstWrap.size());
        System.debug('lstWrap1'+lstWrap[1]);
        System.debug('obj'+objWrap1.BDrecId);
        String objbString1 = JSON.serialize(lstWrap);
        System.debug('objbString'+objbString1);
        BDTrackerController.BDTrackerSave(objbString1, false, '11',objUser.Id,2020); 
        
        Id evtRecID = Schema.SObjectType.Event.getRecordtypeinfosbyName().get('BD Tracker').getRecordtypeId();
        Id accRecId = Constants.ACCOUNT_DOM_DISTRIBUTOR_RECORDTYPEID;
        
        BD_Tracker__c objBdTracker = new BD_Tracker__c();
        objBdTracker.isSubmitted__c = true;
        objBdTracker.Product__c = objProduct.id;
        objBdTracker.Contact__c = objContact.id;
        objBdTracker.Product_Discussion_Plan_Week__c = 'Week12';
        objBdTracker.Product_Discussion_Plan_Year__c = '2019';
        objBdTracker.Evaluation_Plan_Year__c = '2019';
        objBdTracker.Evaluation_Planned_Week__c = 'Week12';
        objBdTracker.Commercialization_Plan_Year__c = '2019';
        objBdTracker.Commercialization_Planned_Week__c = 'Week12';
        DAtabase.insert(objBdTracker);
        BD_Tracker__c objTracker2 = [Select id from BD_Tracker__c limit 1];
        objwrap1.CommWeek = '46';
        objwrap1.EvalWeek = '45';
        objwrap1.ProdWeek = '44';
        objwrap1.CommYear = '2019';
        objwrap1.EvalYear = '2019';
        objwrap1.ProdYear = '2019';
        objwrap1.objProduct = objProduct;
        objwrap1.Status = 'New';
        objwrap1.objAccount = objAccount;
        objWrap1.objcontact = objContact;
        
        List<BDTrackerController.StageWrapper>lstWeek2 = new List<BDTrackerController.StageWrapper>();
        BDTrackerController.StageWrapper objWeek12 = new BDTrackerController.StageWrapper();
        objWeek12.stageName = 'Product Discussion';
        BDTrackerController.StageWrapper objWeek22 = new BDTrackerController.StageWrapper();
        objWeek22.stageName = 'Evaluation';
        BDTrackerController.StageWrapper objWeek32 = new BDTrackerController.StageWrapper();
        objWeek32.stageName = 'Commercialization';
        
        lstWeek1.add(objweek11);
        lstWeek1.add(objweek21);
        lstWeek1.add(objweek31);
        objWrap1.lstStages = lstWeek1;
        
        
        
        //lstWrap.add(objWrap1);
        System.debug('lstWrap'+lstWrap.size());
        System.debug('lstWrap1'+lstWrap[1]);
        System.debug('objBDrecId'+objWrap1.BDrecId);
        String objbString2 = JSON.serialize(lstWrap);
        System.debug('objbString'+objbString2);
        
        List<BDTrackerController.BDTrackerWrapper>lstWrap1 = new List<BDTrackerController.BDTrackerWrapper>();
        lstWrap1.add(objWrap1);
        String json1 = JSON.serialize(lstWrap1);
        
        BDTrackerController.getProductDetails('Test123','Product__c');
        BDTrackerController.getAccountDetails('Test1','Account');
        
        String json2 = JSON.serialize(lstWrap[0]);
            //Test.startTest();
        BDTrackerController.deleteBDTracker(json2, 'deleteReason', 2019,objUser.Id);
        BDTrackerController.validateAccount(objAccount1.id,objContact1.id, objProduc1t.id);
           // Test.stopTest();
      // 
       // BDTrackerController.validatePlans(json1,false,'1-5','2020');
        BDTrackerController.BDTrackerSave(objbString, FALSE, '11',objUser.Id,2020);
     // 
        /***************************************************/
        } 
        //}catch(Exception ex){
          //  ex.getMessage();
        //}
    }
    public static testmethod void getcontactdetailtest(){
        
        User objUser = [Select id,Name,Profile.Name,isActive from User limit 1];  
        System.runAs(objUser){
            Test.startTest();
            List<Contact> lstcontact = new List<Contact>();
            
            
            List<Account> lstaccount = new List<Account>();
            lstaccount = [select id, Name from Account];
            
            BDTrackerController.getContactDetails('Test1','Contact',lstaccount[0].Id);
            BDTrackerController.getWeeksOfYear(2020, 1, 2020);
            BDTrackerController.getWeekssOfyear(2020,objUser.Id);
            BDTrackerController.monthWiseWeeks('2020','1-5');
            BDTrackerController.getWeeks('2020','1');
            BDTrackerController.weeknumber(2020, '1-5');
            BDTrackerController.checkApprovalPending(objUser.Id,'6-9','2020');
            //BDTrackerController.callApproval('6-9','2020');
            BDTrackerController.updateforSubmitRequest('6-9','2020');
            Test.stopTest();
            
            
        }
    }
    
    public static testmethod void getcontactinfotest(){
        
        User objUser = [Select id,Name,Profile.Name,isActive from User limit 1];  
        System.runAs(objUser){
            Test.startTest();
            List<Contact> lstcontact = new List<Contact>();
            
            lstcontact = [select Id,AccountId from Contact];
            List<Account> lstaccount = new List<Account>();
            lstaccount = [select id, Name from Account];
            
            BDTrackerController.getContactInfo(lstcontact[0].Id, lstaccount[0].Id);
            
        BDTrackerController.getCurrentWeekDetails();
        //BDTrackerController.callApproval('6-9','2020');
        BDTrackerController.checkApprovalPending(objUser.Id,'6-9','2020');
        BDTrackerController.getLockSubmitValues('6-9','2020');
        BDTrackerController.getUserInfo();
        BDTrackerController.updateforSubmitRequest('6-9','2020');
            
            Test.stopTest();
            
            
        }
    }
    public static testmethod void getAccountinfotest(){
        
        User objUser = [Select id,Name,Profile.Name,isActive from User limit 1];  
        System.runAs(objUser){
            Test.startTest();
            
            List<Account> lstaccount = new List<Account>();
            lstaccount = [select id from Account];
            
            BDTrackerController.getAccountInfo(lstaccount[0].Id);
            BDTrackerController.fakMethod();
            Test.stopTest();
            
            
        }
    }
    public static testmethod void getProductinfotest(){
        
        User objUser = [Select id,Name,Profile.Name,isActive from User limit 1];  
        System.runAs(objUser){
            Test.startTest();
            List<Product__c> lstproduct = new List<Product__c>();
            lstproduct = [select Id from Product__c];
            
            List<Account> lstaccount = new List<Account>();
            lstaccount = [select id from Account];
            
            List<Contact> lstcontact = new List<Contact>();
            lstcontact = [select Id,AccountId from Contact];
            
            BDTrackerController.getProductInfo(lstproduct[0].Id,lstaccount[0].Id,lstcontact[0].Id);
            Test.stopTest();
            
            
        }
    }
    public static testmethod void getWeeksDetailtest(){
        
        User objUser = [Select id,Name,Profile.Name,isActive from User where profile.name='System Administrator' AND isActive=true limit 1];  
        System.runAs(objUser){
            // List<BDT_Submission_History__c> objSubHistoryToUpdate = [Select id,Name,isSubmitted__c,Submission_Date__c,Submit_Count__c,WeekRange__c,OwnerId,createdDate
            // from BDT_Submission_History__c where OwnerId=:userinfo.getUserId()
            // ];
            BDT_Submission_History__c objSubHistory = new BDT_Submission_History__c();
            objSubHistory.isSubmitted__c = True;
            objSubHistory.Submission_Date__c = Date.valueOf(System.today());
            objSubHistory.Submit_Count__c =1; 
            // objSubHistory.Id = 
            objSubHistory.WeekRange__c = '1-5';
            //objSubHistory.OwnerId = objUser.id; 
            objSubHistory.Last_Submit_Date__c = Date.valueOf(System.today());
            //  objSubHistoryToUpdate.add(objSubHistory);
            // Database.update(objSubHistoryToUpdate);
            insert objSubHistory;
            
            Test.startTest();
            List<string> lstweeks = new List<string>();
            BDTrackerController.getWeeksDetail('2019');
            BDTrackerController.getPickListValuesIntoList(objUser.id);
            BDTrackerController.getMonth(11);
           // BDTrackerController.getWeekssOfyear(2019);
            BDTrackerController.getBDTrackerByYearandMonth('2019','1',objUser.id);
            
            
            Id workItemId = objSubHistory.id;
           // BDTrackerController.approvePlan(objUser.id);
           // BDTrackerController.rejectPlan(objUser.id,'test');         
            Test.stopTest();
            
            
        }
    }
    /*
public static testmethod void getobjTrackerDetails(){
User objUser = [Select id,Name,Profile.Name,isActive from User limit 1];  
System.runAs(objUser){
test.startTest();
}
} 
*/  
}
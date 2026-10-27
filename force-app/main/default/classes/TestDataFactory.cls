/********************************************
* @Class Name   : TestDataFactory
* @Description  : It is used to create the dummay data for all objects
* @Created Date : 07-11-2019
* @Created By   : Rajesh N. 
* ****************************************/
public class TestDataFactory {
      
    /********************************************
* @Method Name  : createUserData
* @Params       : integer noOfRecords
* @Description  : It is used to create the dummay data Customer Conversion.
* @Created Date : 07-11-2019
* @Created By   : Rajesh N. 
* ****************************************/
   public static user createUserData(String ProfileName){
        
      /*  String zsmUserName = 'dom_zsmuser' + DateTime.now().getTime() + '@testorg.com';
        Profile zsmp = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
        UserRole zsmd =[SELECT Id,name FROM UserRole WHERE (Name like'%SE%') LIMIT 1];
        system.debug('zsmd'+zsmd);
        User zsmUser = new User(Alias = 'zsm_u', Email='dom_zsmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = zsmp.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=zsmUserName,UserRoleId=zsmd.Id,Division__c='I',Employee_Code__c='DOMZSM1234');
        insert  zsmUser; */
        
        
       String rsmUserName = 'dom_rsmuser' + DateTime.now().getTime() + '@testorg.com';
       
       Profile rsmp  = [SELECT Id FROM Profile WHERE Name=:ProfileName];
       UserRole rsmd = [SELECT Id,name FROM UserRole WHERE (Name like'%RSM%' OR Name like '%SS_D%') LIMIT 1];
       User rsmUser = new User(Alias = 'rsm_u', Email='dom_rsmuser@testorg.com',
                               EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                               LocaleSidKey='en_US', ProfileId = rsmp.Id,
                               TimeZoneSidKey='America/Los_Angeles',
                               User_Type__c='Domestic',UserName=rsmUserName,UserRoleId=rsmd.Id,Division__c='I;II',Employee_Code__c='DOMRSM1234');                                
       insert rsmUser;
       
       return rsmUser;
   }
    /********************************************
* @Method Name  : createTaskData
* @Params       : integer noOfRecords
* @Description  : It is used to create the dummay data for Task.
* @Created Date : 14-11-2019
* @Created By   : Rajesh N. 
* ****************************************/
    /*public static List<Task> createTaskData(Integer noOfRecords,Customer_Conversion_Plan__c objCCR){
List<Task> lstTask = new List<Task>();

for(Integer i=0;i<noOfRecords;i++){
Task objTask = new Task();
objTask.Subject = 'Product Discussion'+objCCR.Account__c;
objTask.OwnerId = userInfo.getUserId();
objTask.ActivityDate = Date.ValueOf(System.today());
objTask.WhatId = objCCR.Id;
objTask.Status = 'Open';
objTask.Priority = 'Normal';
lstTask.add(objTask);
}
Database.insert(lstTask);
return lstTask;
} */  
    /********************************************
* @Method Name  : createRegionData
* @Params       : integer noOfRecords
* @Description  : It is used to create the dummay data Region(City).
* @Created Date : 14-11-2019
* @Created By   : Abhi 
* ****************************************/
    public static List<CIty__c> createRegionData(integer noOfRecords,String cityName,String strRegionCode,String strContryKey){
        List<CIty__c>lstCity =new List<CIty__c>();
        
        for(integer i=0;i<noOfRecords;i++){
            CIty__c objcity = new CIty__c();
            objcity.Name = cityName;
            objcity.Region_Code__c = strRegionCode;
            objcity.country_key__c = strContryKey;
            lstCity.add(objcity);
        }
        insert lstCity;
        return lstCity;
    }
    /********************************************
* @Method Name   : createAccountData
* @Params       : integer noOfRecords
* @Description  : It is used to create the dummay data Customer Conversion.
* @Created Date : 07-11-2019
* @Created By   : Abhi 
* ****************************************/
    public static List<Account> createAccountData(Integer noOfAccount,id recTypeId,CIty__c objCity){
        
        Profile pf = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
    //    UserRole ur = [SELECT Id FROM UserRole WHERE Name='SSE'];//new UserRole(Name = 'SSE');
      //  insert ur;
        
   User tuser = [SELECT Id FROM User  Limit 1];        
        List<Account>lstAccount = new List<Account>();
        
        System.runAs(tuser){

        Id RecordTypeIdContact = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Distributor').getRecordTypeId();
        
        for(integer i=0;i<noOfAccount;i++){
            Account objAccount = new Account();
            objAccount.RecordTypeId = recTypeId;
            objAccount.Name = 'Test'+i;
            objAccount.region__c = objCity.Id;
            objAccount.Drug_License_No__c = 'Test'+i;
            objAccount.First_mobile_telephone_no__c = 'Test'+i;
            objAccount.Country_Key__c = objCity.country_key__c;
            objAccount.E_Mail__c = 'test@gmail.com';
            objAccount.Contact_Person__c = 'Test'+i;
            objAccount.Commercial_Account_Name__c = 'Test'+i;
            objAccount.Phone = 'Test'+i;
            objAccount.SAP_Code__c = '45612';
            objAccount.Account_Type__c = 'Commercial';
            objAccount.Payment_Collection_Cycle__c = 90;
            objAccount.GSTIN_No__c = 'Test'+i;
            lstAccount.add(objAccount);
        }
        Database.insert(lstAccount);
        }
        //lstAccount.add(accObj);
        return lstAccount;
    }  
    /********************************************
* @Method Name   : createProductData
* @Params       : integer noOfRecords
* @Description  : It is used to create the dummay data Customer Conversion.
* @Created Date : 07-11-2019
* @Created By   : Rajesh N. 
* ****************************************/   
    public static List<Product__c> createProductData(){
        List<Product__c> lstProduct  = new List<Product__c>();
        //Integer noOfProduct
        // for(integer i=0;i<noOfProduct; i++){
        Product__c objProduct = new Product__c();
        objProduct.Name = 'Test123';
        objProduct.Dummy_Product_Code__c = 'Test456';
        objProduct.Planning__c = 'Yes';
        objProduct.Active__c = true;
        objProduct.Division__c = 'II';
        objProduct.Region__c = 'Domestic';
        objProduct.MSP__c =10;
        objProduct.Dummy_Product_Description__c='test';
        lstProduct.add(objProduct);
        // }
        Insert lstProduct;
        return lstProduct;
        
    }
    
    /********************************************
* @Method Name   : createMonthlyAOP
* @Params       : integer noOfRecords,Product__c objProduct,String monthNm, String year
* @Description  : It is used to create the dummay data monthly AOP.
* @Created Date : 20-11-2019
* @Created By   : Pratiksha K. 
* ****************************************/
    public static List<Monthly_AOP__c> createMonthlyAOPData(integer noOfRecords,Product__c objProduct, String monthNm, String year){
        List<Monthly_AOP__c>lstMOP = new List<Monthly_AOP__c>();
        
        for(integer i=0;i<noOfRecords; i++){
            Monthly_AOP__c aopTest = new Monthly_AOP__c();
            aopTest.Target_Quantity__c =10; 
            aopTest.Month__c = monthNm;
            aopTest.Year__c = 	year;
            aopTest.Product__c = objProduct.Id;
           // aopTest.Sales_User__c = userId;
            system.debug('objProduct.Id'+objProduct.Id);
            lstMOP.add(aopTest);
        }
        database.insert(lstMOP);
        return lstMOP;
    }
    /********************************************
* @Method Name   : createBrancheData
* @Params       : integer noOfRecords,String branch, String regionCode, String deliveryPlant,String district
* @Description  : It is used to create the dummay data branch related custom setting record
* @Created Date : 20-11-2019
* @Created By   : Pratiksha K. 
* ****************************************/
    public static List<BranchFormDataVsLocation__c> createBranchData(integer noOfRecords, String branch, String regionCode, String deliveryPlant,
                                                                     String district){
                                                                         List<BranchFormDataVsLocation__c> lstbranch = new List<BranchFormDataVsLocation__c>();
                                                                         
                                                                         for(integer i=0;i<noOfRecords; i++){
                                                                             BranchFormDataVsLocation__c branchCustomsetting = new BranchFormDataVsLocation__c();
                                                                             branchCustomsetting.Name = 'Test Set';
                                                                             branchCustomsetting.Branch_Location__c = branch; //DELHI
                                                                             branchCustomsetting.Region_Code__c = regionCode;
                                                                             branchCustomsetting.Delivery_Plant__c = deliveryPlant;
                                                                             branchCustomsetting.Sales_District__c = district;
                                                                             lstbranch.add(branchCustomsetting);
                                                                         }
                                                                         database.insert(lstbranch);
                                                                         return lstbranch;
                                                                     }
    /********************************************
* @Method Name   : createUserRegionAssociationData
* @Params       : integer noOfRecords,User usr, CIty__c region
* @Description  : It is used to create the dummay user region association record data
* @Created Date : 20-11-2019
* @Created By   : Pratiksha K. 
* ****************************************/
    public static List<User_Region_Association__c> createUserRegionAssociationData(integer noOfRecords, User usr, CIty__c region){
        List<User_Region_Association__c> lstuserRegion = new List<User_Region_Association__c>();
        // CIty__c reg  = [Select id,name from CIty__c limit 1];
        for(integer i=0;i<noOfRecords; i++){
            User_Region_Association__c userRegionTest = new User_Region_Association__c(); 
           //userRegionTest.Name = 'RSM-'+region.Name;
            userRegionTest.User__c = usr.id; 
            userRegionTest.Region__c =region.Id;  
            lstuserRegion.add(userRegionTest);
            system.debug('userRegionTest'+userRegionTest);
        }
        database.insert(lstuserRegion);
        return lstuserRegion;
    }
    /********************************************
* @Method Name   : createWeeklyForecastSettingRecords
* @Params       : integer noOfRecords,String branch, String regionCode, String deliveryPlant,String district
* @Description  : It is used to create the dummay weekly forecast settings record data
* @Created Date : 20-11-2019
* @Created By   : Pratiksha K. 
* ****************************************/
    public static List<Weekly_Forecast_Settings__c> createWeeklyForecastSettingRecords(integer noOfRecords){
        List<Weekly_Forecast_Settings__c> lstweeklyForecastSettings = new List<Weekly_Forecast_Settings__c>();
        Date dt = system.today();
        
        for(integer i=0;i<noOfRecords; i++){
            Weekly_Forecast_Settings__c weeklysettingTest = new Weekly_Forecast_Settings__c();
            weeklysettingTest.Date__c = i;
            weeklysettingTest.Name = 'Test Forecast2';
            weeklysettingTest.Submission_Closing_Date__c =21;
            weeklysettingTest.Submission_Opening_Date__c=  23;
            lstweeklyForecastSettings.add(weeklysettingTest);
        }
        database.insert(lstweeklyForecastSettings);
        return lstweeklyForecastSettings;
    }
    /********************************************
* @Method Name   : createWeeklyForecastRecords
* @Params       : Integer noOfRecords, Product__c objProduct, Integer monthNumber,Integer actualQty, Integer forecastQty, String monthNm, Integer year,
Integer weekNumber, String branch, String branchCode, String objProduct
* @Description  : It is used to create the dummay weekly forecast record data
* @Created Date : 20-11-2019
* @Created By   : Pratiksha K. 
* ****************************************/
    public static List<Weekly_Forecast__c> createWeeklyForecastRecords(Integer noOfRecords, Product__c objProduct, Integer monthNumber,
                                                                       Integer actualQty, Integer forecastQty, String monthNm, Integer year,
                                                                       Integer weekNumber, String branch, String branchCode,Integer regionCode){
                                                                           List<Weekly_Forecast__c> lstweeklyForecast = new List<Weekly_Forecast__c>();
                                                                           
                                                                           for(integer i=0;i<noOfRecords; i++){
                                                                               Weekly_Forecast__c forecastTest = new Weekly_Forecast__c ();
                                                                               //forecastTest.Name  = 'Test Forecast'+i;
                                                                               forecastTest.Product__c = objProduct.id;
                                                                               forecastTest.Actual_Qty__c = actualQty;
                                                                               forecastTest.Forecast_Qty__c = forecastQty;
                                                                               forecastTest.Month__c = monthNumber;
                                                                               forecastTest.Month_Name__c = monthNm;
                                                                               forecastTest.Year__c =year;
                                                                               forecastTest.Week_Start_Date__c = Date.newInstance(2019,06,17);
                                                                               forecastTest.Week_End_Date__c  =  Date.newInstance(2019,06,23);
                                                                               forecastTest.Week_Number__c = weekNumber;
                                                                               forecastTest.Unique_Key_Weekly_Forecast__c = objProduct.id+'_'+regionCode+'_'+branch+'_'+year+'_'+monthNumber+'_'+weekNumber;
                                                                               forecastTest.Branch__c = branch;
                                                                               forecastTest.Branch_Code__c = branchCode;
                                                                               
                                                                               lstweeklyForecast.add(forecastTest);
                                                                           }
                                                                           system.debug('lstweeklyForecast'+lstweeklyForecast);
                                                                           database.insert(lstweeklyForecast);
                                                                           return lstweeklyForecast;
                                                                       }
    
    /********************************************
* @Method Name   : Submit Forecast records
* @Params       : Integer noOfRecords
* @Description  : It is used to create the dummay weekly forecast record data
* @Created Date : 20-11-2019
* @Created By   : siddhi 
* ****************************************/
    
    public static List<Forecast_Submission_History__c> submitForecastRecords(Integer noOfRecords,Id zsmUserId){
        List <Forecast_Submission_History__c > testfo = new List<Forecast_Submission_History__c >();
        Date nextMonthDate =  System.today().addMonths(1);
        Integer year = nextMonthDate.year();
        Integer nextMonthNumber = nextMonthDate.month();
        
        for(integer i=0;i<noOfRecords; i++){
            Forecast_Submission_History__c forecastHistoryTest = new Forecast_Submission_History__c();
            forecastHistoryTest.Status__c = 'Submitted';
            forecastHistoryTest.Submitted_For_Month__c = String.valueOf(nextMonthNumber);
            forecastHistoryTest.Submitted_For_Year__c = String.valueOf(year);
            forecastHistoryTest.Submitted_By__c  = zsmUserId;
            testfo.add(forecastHistoryTest);
        }
        // return testfo ;
        database.insert(testfo);
        return testfo;
        
    }
    /********************************************
* @Method Name   : checkCancelPhase
* @Params       : Integer noOfRecords ,string bdPhase, string mstage , Integer dm , string rs,string mr, string dr,string maw,string year,date time1
* @Description  : It is used to checkCancelPhase
* @Created Date : 5-12-2019
* @Created By   : siddhi 
* ****************************************/
    public static List<Event> createEvent(Integer noOfRecords ){
        Id evtRecID = Schema.SObjectType.Event.getRecordtypeinfosbyName().get('BD Tracker').getRecordtypeId();
        List<Event> eventTest = new List<Event>(); 
        Event objEvent = new Event();
        for(integer i=0;i<noOfRecords; i++){
            
            objEvent.RecordTypeId= evtRecID;
            objEvent.BD_Tracker_Phase__c ='Evaluation';
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
            eventTest.add(objEvent);
            
        }
        database.insert(eventTest);
        // return testfo;
        return eventTest;
        
    }
    /*    ********************************************
* @Method Name   : createBDPlanning
* @Params       : Integer noOfRecords ,string bdPhase, string mstage , Integer dm , string rs,string mr, string dr,string maw,string year,date time1
* @Description  : It is used to test createHistory
* @Created Date : 5-12-2019
* @Created By   : siddhi 
* *****************************************/
    public static List<BD_Tracker_Planning__c> createBDPlanning(Integer noOfRecords  ){
        
        List<BD_Tracker_Planning__c> BdTraList = new List<BD_Tracker_Planning__c>();
        BD_Tracker_Planning__c BD_Track = new BD_Tracker_Planning__c();
        for(Integer i=0; i<noOfRecords; i++)
        {
            // BD_Track.Account__c = a.id;
            // BD_Track.Product__c =p.id;
            BD_Track.Actual_Week__c = 'week1';
            BD_Track.Actual_Year__c = '2018';
            
        }
        database.insert(BD_Track);
        return BdTraList;
        
    }
    /*    ********************************************
* @Method Name   :createFiscalYears
* @Params       : Integer noOfRecords 
* @Description  : It is used to create data for Incentive Policy
* @Created Date : 23/12/2019
* @Created By   : siddhi 
* *****************************************/
   /*
    public static List<Incentive_Policy__c> createFiscalYears (Integer noOfRecords){
        
        List< Incentive_Policy__c> IPLst = new List< Incentive_Policy__c>();
        Incentive_Policy__c IP =new Incentive_Policy__c();
        for(Integer i = 0;i<noOfRecords;i++){
            
            IP.FY_Year__c = '2019-2020';
            IP.Start_Date__c = date.newInstance(2019, 04, 01);
            IP.End_Date__c = date.newInstance(2019, 3, 31);
            IP.Region__c = 'India';
            IPLst.add(IP);
        }
        database.insert(IPLst);
        return IPLst;  
    } 
*/
    /*    ********************************************
* @Method Name   : createIncentiveAllocations
* @Params       : Id fiscalYrId,Integer noOfRecords
* @Description  : It is used to create data for Consumable Incentive Allocation
* @Created Date : 23/12/2019
* @Created By   : siddhi 
* *****************************************/
    /*
    public static List<Consumable_Incentive_Allocation__c> createIncentiveAllocations(Id fiscalYrId,Integer noOfRecords, String division, string role){
        List<Consumable_Incentive_Allocation__c> CIAlst = new List<Consumable_Incentive_Allocation__c>();
        Consumable_Incentive_Allocation__c inctAllocation = new Consumable_Incentive_Allocation__c();
        for(Integer i = 0;i<noOfRecords;i++){
            inctAllocation.Division__c = division;
            inctAllocation.Incentive_Policy_Year__c = fiscalYrId;
            inctAllocation.Role__c = role;
            CIAlst.add(inctAllocation);
        } 
        database.insert(CIAlst);
        return CIAlst;
    }
    */
    
    /*    ********************************************
* @Method Name   :createProductWiseIncentiveRate
* @Params       :Id fiscalYrId,Integer noOfRecords, Product__c p
* @Description  : It is used to create data for Consumable_Product_Wise_Incentive_Rate__c
* @Created Date : 23/12/2019
* @Created By   : siddhi 
* *****************************************/
  /*  
    public static List<Consumable_Product_Wise_Incentive_Rate__c> createProductWiseIncentiveRate(Id fiscalYrId,Integer noOfRecords, Product__c p  ){
        List<Consumable_Product_Wise_Incentive_Rate__c> lstCPWI = new List<Consumable_Product_Wise_Incentive_Rate__c>();
        Consumable_Product_Wise_Incentive_Rate__c  CPWI = new  Consumable_Product_Wise_Incentive_Rate__c();
        for(Integer i = 0;i<noOfRecords;i++){
            CPWI.Product__c = p.Id;
            CPWI.Incentive_Per_Unit__c = 2;         
            CPWI.Incentive_Policy_Year__c = fiscalYrId;
            lstCPWI.add(CPWI);
        }
        database.insert(lstCPWI);
        return lstCPWI;
    }
    
    */
    /*    ********************************************
* @Method Name   :CreateAbcdConfig
* @Params       :id FiscalYrId,Integer noOfRecords
* @Description  : It is used to create data for ABCD_Configuration__c
* @Created Date : 23/12/2019
* @Created By   : siddhi 
* *****************************************/
    /*
    public static List<ABCD_Configuration__c> CreateAbcdConfig(id FiscalYrId,Integer noOfRecords){
        List<ABCD_Configuration__c> lstabc = new List<ABCD_Configuration__c>();
        ABCD_Configuration__c abc= new ABCD_Configuration__c();
        for(Integer i=0;i<noOfRecords;i++){
            abc.Percentage_Type__c = 'A';
            abc.Incentive_Per_Unit__c = 30;
            lstabc.add(abc);
        }
        
        database.insert(lstabc);
        return lstabc;
    }
    */
    /*    ********************************************
* @Method Name   :Create ZIncentive Records
* @Params       :id FiscalYrId,Integer noOfRecords
* @Description  : It is used to create data for ABCD_Configuration__c
* @Created Date : 23/12/2019
* @Created By   : siddhi 
* *****************************************/    
    
    
    public static List<Z_Incentive__c> CreateZIncentiveData(Integer noOfRecords,Product__c Product, Account objAccount){
        List<Z_Incentive__c> lstabc = new List<Z_Incentive__c>();
        Z_Incentive__c zincentive= new Z_Incentive__c();
        for(Integer i=0;i<noOfRecords;i++){
            zincentive.Account__c = objAccount.id;
        }
        return lstabc;
    }
    
  /*    ********************************************
* @Method Name   :create master agreement with agreement products
* @Params       :Account id, agreement start and end dates and number of master agreements to create.
* @Description  : It is used to create data for Master_Agreement__c
* @Created Date : 04/10/2020
* @Created By   : jagdish
* *****************************************/ 

    public static List<Master_Agreement__c> createMasterAgreements(Id accountId, date agrmntStartDate, date agrmntEndDate, integer numberOfAgreement){
     List<Master_Agreement__c> lstMasterAgreements = new List<Master_Agreement__c>();
        integer i=0;
        for(i=0; i < numberOfAgreement; i++){
            Master_Agreement__c masterAgreement = new Master_Agreement__c();
            	masterAgreement.Account__c = accountId;
                masterAgreement.Agreement_End_Date__c = agrmntEndDate;
                masterAgreement.Agreement_Start_Date__c = agrmntStartDate;
                lstMasterAgreements.add(masterAgreement);
        }
        insert lstMasterAgreements;
        return lstMasterAgreements;    
    }
    
    
    
    
    public static Agreement_Product__c createAgreementProduct(string productName, Id MasterAgreementId){
        Product__c product = new Product__c();
        product.Name = productName; 
        product.Active__c = true;
        product.Quantity__c = 10;
        product.Dummy_Product_Code__c = 'external';
        insert product;    
        Agreement_Product__c agreementProd = new Agreement_Product__c();
        agreementProd.Product__c = product.Id;
        agreementProd.Master_Agreement__c = MasterAgreementId;
        insert agreementProd;
    
        return agreementProd;        
    }
    public static Agreement_Product__c createAgreementProductForPoducts(id productId, Id MasterAgreementId){
        Agreement_Product__c ap = new Agreement_Product__c(); 
        ap.Product__c = productId;
        ap.Master_Agreement__c = MasterAgreementId;
        insert ap;
        integer i;
        List<Dealer_Actual_Sales__c> lstActualSales = new list<Dealer_Actual_Sales__c>();
        for(i=12; i>0;i--){
           Dealer_Actual_Sales__c actualSales = new Dealer_Actual_Sales__c();
           actualSales.Account__c = ap.Master_Agreement__r.Account__c;
           actualSales.Actual_Sales_Month__c = i;
           actualSales.Agreement_Product__c = ap.id;
           lstActualSales.add(actualSales);
        }
        
         insert lstActualSales;        
        return ap;
    }
    //----
    
        public static User createUser(Id profileId,String region, Id roleId, String empCode, String division, Id contactId){
        User usr = new User(            
            ProfileId = profileId,
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
            UserRoleId = roleId,
            Employee_Code__c = empCode,
            Division__c = division,
            User_Type__c =region,
            isActive = true,
            ContactId = contactId,
            Date_of_Joining__c = system.today(),
            Portal_User_Role__c = 'RBM');
        insert usr;
        return usr;
    }

        public static CIty__c createRegionData(String cityName,String strRegionCode,String strContryKey){       
        CIty__c objcity = new CIty__c();
        objcity.Name = cityName;
        objcity.Region_Code__c = strRegionCode;
        objcity.country_key__c = strContryKey;
        insert objcity;
        return objcity;
    }
    
    
        public static Account createAccForInternational(CIty__c objCity, String sapCode){
        Id recTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Ortho_Dermal').getRecordTypeId();
        Account objAccount = new Account();
        objAccount.RecordTypeId = recTypeId;
        objAccount.Name = 'Test Account';
        objAccount.region__c = objCity.Id;
        objAccount.First_mobile_telephone_no__c = '9868685855';
        objAccount.Country_Key__c = objCity.country_key__c;
        objAccount.E_Mail__c = 'test@gmail.com';
        objAccount.Contact_Person__c = 'Test';
        objAccount.City_postal_code__c = '87878';
        objAccount.SAP_Code__c = sapCode;
        objAccount.Payment_Collection_Cycle__c = 90;
        objAccount.CurrencyIsoCode ='USD';
        objAccount.Customer_Account_Group__c = 'ZESC';
        objAccount.Customer_Group__c = '01';
        objAccount.Sales_Office__c = '009';
        objAccount.Distributor_Channel__c = '10';
        objAccount.Company_Code__c = '1000';
        objAccount.Sales_District__c = 'E001';
        objAccount.Division__c = '00';
        objAccount.Customer_Class__c = 'A';
        objAccount.Reconciliation_Account_GL__c = '2050010';
        objAccount.Terms_Of_Payment_Key__c = 'A001';
        objAccount.Pricing_Procedure_Assigned__c = 'A';
        objAccount.Delivery_Priority__c = '01';
        objAccount.Account_Assignment_Group__c = '02';
        objAccount.Number_of_an_SD_business_partner_Z1__c ='11';
        objAccount.BillingCity = 'Test billing city';
        objAccount.BillingCountry = 'Test billing country';
        objAccount.BillingState = 'Test billing state';
        objAccount.BillingPostalCode = '1234';
        objAccount.BillingStreet = 'Test billing street';
        insert objAccount;
        return objAccount;
    }
    
    
        public static Contact createContact(Id accId, String lastName){
        Contact con = new Contact();
        con.AccountId  = accID;
        con.LastName= lastName;
        con.CurrencyIsoCode = 'USD';
        insert con;
        return con;
    }
    
        public static Product__c createProductData(String division, String region, String prodCode, String prodName){
        Product__c objProduct = new Product__c();
        objProduct.Name = 'Test123';
        objProduct.Dummy_Product_Code__c = prodCode;
        objProduct.Planning__c = 'Yes';
        objProduct.Active__c = true;
        objProduct.Division__c = division;
        objProduct.Region__c = region;
        objProduct.MSP__c =10;
        objProduct.Dummy_Product_Description__c= prodName;
        Insert objProduct;
        return objProduct;       
    }
    
}
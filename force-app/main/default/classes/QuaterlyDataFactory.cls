public class QuaterlyDataFactory {
    //Create RSM User
    public static user createUserData(String ProfileName){
        String rsmUserName = 'dom_rsmuser' + DateTime.now().getTime() + '@testorg.com';
        
        Profile rsmp  = [SELECT Id FROM Profile WHERE Name=:ProfileName];
        UserRole rsmd = [SELECT Id,name FROM UserRole WHERE Name like'RSM%' AND PortalType = 'None' LIMIT 1 ];
        User rsmUser = new User(Alias = 'rsm_u', Email='dom_rsmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = rsmp.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=rsmUserName, UserRoleId=rsmd.Id, Division__c='I',Employee_Code__c='DOMRSM1234');                                
        insert rsmUser;
        return rsmUser;
    }
    
    //Create DM User
    public static user createUserData1(String ProfileName){
        String dmUserName = 'dom_rsmuser' + DateTime.now().getTime() + '@testorg.com';
        
        Profile rsmp  = [SELECT Id FROM Profile WHERE Name=:ProfileName];
        UserRole DM1 = [SELECT Id,name FROM UserRole WHERE Name like'DM%' AND PortalType = 'None' LIMIT 1];
        User DMUser = new User(Alias = 'rsm_u', Email='dom_rsmuser@testorg.com',
                               EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                               LocaleSidKey='en_US', ProfileId = rsmp.Id,
                               TimeZoneSidKey='America/Los_Angeles',
                               User_Type__c='Domestic',UserName=dmUserName, UserRoleId=DM1.Id, Division__c='I',Employee_Code__c='DOMDMs1234');                                
        insert DMUser;
        return DMUser;
    }
    
    //CREATE SSE USER
    public static user createUserData2(String ProfileName){
        String rsmUserName = 'dom_rsmuser' + DateTime.now().getTime() + '@testorg.com';
        
        Profile rsmp  = [SELECT Id FROM Profile WHERE Name=:ProfileName];
        UserRole rsmd = [SELECT Id,name FROM UserRole WHERE Name like'SSE%' AND PortalType = 'None' LIMIT 1];
        User sseUser = new User(Alias = 'rsm_u', Email='dom_rsmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = rsmp.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=rsmUserName, UserRoleId=rsmd.Id, Division__c='I',Employee_Code__c='DOMSSE1234');                                
        insert sseUser;
        return sseUser;
    }
    
    //create zdm user
    public static user createUserData3(String ProfileName){
        String rsmUserName = 'dom_rsmuser' + DateTime.now().getTime() + '@testorg.com';
        
        Profile rsmp  = [SELECT Id FROM Profile WHERE Name=:ProfileName];
        UserRole rsmd = [SELECT Id,name FROM UserRole WHERE Name like'ZDM%' AND PortalType = 'None' LIMIT 1];
        User zdmUser = new User(Alias = 'rsm_u', Email='dom_rsmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = rsmp.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=rsmUserName, UserRoleId=rsmd.Id, Division__c='I',Employee_Code__c='DOMZDm1234');                                
        insert zdmUser;
        return zdmUser;
    }
    
    //    create asm user
    public static user createUserData4(String ProfileName){
        String rsmUserName = 'dom_rsmuser' + DateTime.now().getTime() + '@testorg.com';
        
        Profile rsmp  = [SELECT Id FROM Profile WHERE Name=:ProfileName];
        UserRole rsmd = [SELECT Id,name FROM UserRole WHERE Name like'ASM%' AND PortalType = 'None' LIMIT 1];
        User asmUser = new User(Alias = 'rsm_u', Email='dom_rsmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = rsmp.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=rsmUserName, UserRoleId=rsmd.Id, Division__c='I',Employee_Code__c='DOMasmUser 1234');                                
        insert asmUser ;
        return asmUser ;
    }
    
    //Create Region
    public static CIty__c CreateRegionData(string cityName,String strRegionCode,String strContryKey){
        CIty__c objcity = new CIty__c();
        objcity.Name = cityName;
        objcity.Region_Code__c = strRegionCode;
        objcity.country_key__c = strContryKey;
        insert objcity;
        return objcity;
    }
    
    //Create Account
    public static Account createAccountData(Id objcityid){
        Id RecordTypeIdContact = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Distributor').getRecordTypeId();
        Account objAccount = new Account();
        objAccount.RecordTypeId = RecordTypeIdContact;
        objAccount.Name = 'Test';
        objAccount.Country_Key__c = objcityid;
        objAccount.Drug_License_No__c = 'Test';
        objAccount.First_mobile_telephone_no__c = 'Test';
        objAccount.E_Mail__c = 'test@gmail.com';
        objAccount.Contact_Person__c = 'Test';
        objAccount.Commercial_Account_Name__c = 'Test';
        objAccount.Phone = 'Test';
        objAccount.SAP_Code__c = '45612';
        objAccount.Account_Type__c = 'Sample';
        objAccount.GSTIN_No__c = 'Test';
        insert objAccount ;
        return objAccount;
    }  
    
    //Create Product
    public static Product__c createProductData(){
        Product__c objProduct = new Product__c();
        objProduct.Name = 'Test123';
        objProduct.Dummy_Product_Code__c = 'Test456';
        objProduct.Planning__c = 'Yes';
        objProduct.Active__c = true;
        objProduct.Division__c = 'I';
        objProduct.Region__c = 'Domestic';
        objProduct.MSP__c =10;
        Insert objProduct;
        return objProduct;
    }
    
    //Create AOP rsm
    public static Monthly_AOP__c createMonthlyAOPData(Id objProductId, String monthNm, String year, Id rsmUserId){
        Monthly_AOP__c aopTest = new Monthly_AOP__c();
        aopTest.Target_Quantity__c =10; 
        aopTest.Month__c = monthNm;
        aopTest.OwnerId = rsmUserId;
        aopTest.Year__c = year;
        aopTest.Sales_User__c = rsmUserId;
        aopTest.Product__c = objProductId;
        system.debug('objProduct.Id'+objProductId);
        insert aopTest;
        return aopTest;
    }
    
    //Create AOP dm
    public static Monthly_AOP__c createMonthlyAOPData1(Id objProductId, String monthNm, String year, Id DMUserId){
        Monthly_AOP__c aopTest = new Monthly_AOP__c();
        aopTest.Target_Quantity__c =10; 
        aopTest.Month__c = monthNm;
        aopTest.OwnerId = DMUserId;
        aopTest.Year__c = year;
        aopTest.Sales_User__c = DMUserId;
        aopTest.Product__c = objProductId;
        system.debug('objProduct.Id'+objProductId);
        insert aopTest;
        return aopTest;
    }
    
    // create AOP sse
    public static Monthly_AOP__c createMonthlyAOPData2(Id objProductId, String monthNm, String year, Id sseUserId){
        Monthly_AOP__c aopTest = new Monthly_AOP__c();
        aopTest.Target_Quantity__c =10; 
        aopTest.Month__c = monthNm;
        aopTest.OwnerId = sseUserId;
        aopTest.Year__c = year;
        aopTest.Sales_User__c = sseUserId;
        aopTest.Product__c = objProductId;
        system.debug('objProduct.Id'+objProductId);
        insert aopTest;
        return aopTest;
    }
    
    //create aop ZDM
    public static Monthly_AOP__c createMonthlyAOPData3(Id objProductId, String monthNm, String year, Id zdmUserId){
        Monthly_AOP__c aopTest = new Monthly_AOP__c();
        aopTest.Target_Quantity__c =10; 
        aopTest.Month__c = monthNm;
        aopTest.OwnerId = zdmUserId;
        aopTest.Year__c = year;
        aopTest.Sales_User__c = zdmUserId;
        aopTest.Product__c = objProductId;
        system.debug('objProduct.Id'+objProductId);
        insert aopTest;
        return aopTest;
    }
    
    //create aop ASM
    public static Monthly_AOP__c createMonthlyAOPData4(Id objProductId, String monthNm, String year, Id asmUserId){
        Monthly_AOP__c aopTest = new Monthly_AOP__c();
        aopTest.Target_Quantity__c =10; 
        aopTest.Month__c = monthNm;
        aopTest.OwnerId = asmUserId;
        aopTest.Year__c = year;
        aopTest.Sales_User__c = asmUserId;
        aopTest.Product__c = objProductId;
        system.debug('objProduct.Id'+objProductId);
        insert aopTest;
        return aopTest;
    }
    
    //Create Incentive policy
    public static Incentive_Policy__c createFiscalYears (){
        Incentive_Policy__c IP =new Incentive_Policy__c();
        IP.FY_Year__c = '2019-2020';
        IP.Start_Date__c = date.newInstance(2019, 04, 01);
        IP.End_Date__c = date.newInstance(2019, 3, 31);
        insert IP;
        return IP;  
    } 
    
    //Create zIncentive rsm
    public static Z_Incentive__c CreateZIncentiveData(Id objProductId, Id objAccountid,Id rsmUserId){
        Z_Incentive__c zincentive= new Z_Incentive__c();
        zincentive.Account__c = objAccountid;
        zincentive.Product__c = objProductId;
        zincentive.RBM_RSM__c = rsmUserId;
        zincentive.Billing_Date__c = system.today();
        insert zincentive;
        return zincentive;
    }
    
    //Create zIncentive dm
    public static Z_Incentive__c CreateZIncentiveData1(Id objProductId, Id objAccountid,Id DMUserId){
        Z_Incentive__c zincentive= new Z_Incentive__c();
        zincentive.Account__c = objAccountid;
        zincentive.Product__c = objProductId;
        zincentive.RBM_RSM__c = DMUserId;
        zincentive.Billing_Date__c = system.today();
        insert zincentive;
        return zincentive;
    }
    
    //create zincentive sse
    public static Z_Incentive__c CreateZIncentiveData2(Id objProductId, Id objAccountid,Id sseUserId){
        Z_Incentive__c zincentive= new Z_Incentive__c();
        zincentive.Account__c = objAccountid;
        zincentive.Product__c = objProductId;
        zincentive.RBM_RSM__c = sseUserId;
        zincentive.Billing_Date__c = system.today();
        insert zincentive;
        return zincentive;
    }
    //create zincentive zdm
    public static Z_Incentive__c CreateZIncentiveData3(Id objProductId, Id objAccountid,Id zdmUserId){
        Z_Incentive__c zincentive= new Z_Incentive__c();
        zincentive.Account__c = objAccountid;
        zincentive.Product__c = objProductId;
        zincentive.RBM_RSM__c = zdmUserId;
        zincentive.Billing_Date__c = system.today();
        insert zincentive;
        return zincentive;
    }
    
    //create zincentive for asm
    public static Z_Incentive__c CreateZIncentiveData4(Id objProductId, Id objAccountid,Id asmUserId){
        Z_Incentive__c zincentive= new Z_Incentive__c();
        zincentive.Account__c = objAccountid;
        zincentive.Product__c = objProductId;
        zincentive.RBM_RSM__c = asmUserId;
        zincentive.Billing_Date__c = system.today();
        insert zincentive;
        return zincentive;
    }
    
    //Create KRA Configuration rsm 
    public static KRA_Configuration__c CreateKRAConfig(Id IPId, Id productid)
    {
        KRA_Configuration__c kra  = new KRA_Configuration__c();
        kra.Role__c = 'ZSM;RSM';
        kra.Applicable_For__c  = 'state';
        kra.Parameter__c = 'Product-Single';
        kra.Product_1__c = productid;
        kra.Measurement_Criteria__c = 'Target vs Actuals';
        kra.Unit_of_Measure__c ='Value';
        kra.Financial_Year__c = IPId;
        kra.Quadrant__c = 'Finance';
        
        kra.Division__c = 'I';
        insert kra;
        return kra;
    }
    
    //Create KRA Configuration   dm
    public static KRA_Configuration__c CreateKRAConfig1(Id IPId,Id prod1id , ID prod2id)
    {
        KRA_Configuration__c kra1  = new KRA_Configuration__c();
        kra1.Role__c = 'DM';
        kra1.Parameter__c = 'Product-Combination';
        kra1.Applicable_For__c  = 'state';
        kra1.Product_1__c = prod1id;
        kra1.Product_2__c = prod2id;
        kra1.Measurement_Criteria__c = 'Target vs Actuals';
        kra1.Unit_of_Measure__c ='Value';
        kra1.Financial_Year__c = IPId;
        kra1.Quadrant__c = 'Finance';
        kra1.Division__c = 'I';
        insert kra1;
        return kra1;
    }
    
    //Create KRA Configuration   sse
    public static KRA_Configuration__c CreateKRAConfig2(Id IPId)
    {
        KRA_Configuration__c kra1  = new KRA_Configuration__c();
        kra1.Role__c = 'SSE';
        kra1.Applicable_For__c  = 'state';
        kra1.Measurement_Criteria__c = 'Target vs Actuals';
        kra1.Unit_of_Measure__c ='Value';
        kra1.Financial_Year__c = IPId;
        kra1.Quadrant__c = 'Finance';
        kra1.Parameter__c = 'Target vs Sales';
        kra1.Division__c = 'I';
        insert kra1;
        return kra1;
    }
    
    //KRA CONFIGURATION ZDM
    public static KRA_Configuration__c CreateKRAConfig3(Id IPId)
    {
        KRA_Configuration__c kra1  = new KRA_Configuration__c();
        kra1.Role__c = 'ZDM';
        kra1.Applicable_For__c  = 'state';
        kra1.Measurement_Criteria__c = 'Target vs Actuals';
        kra1.Unit_of_Measure__c ='Value';
        kra1.Financial_Year__c = IPId;
        kra1.Quadrant__c = 'Finance';
        kra1.Parameter__c = 'Target vs Sales';
        kra1.Division__c = 'I;II';
        insert kra1;
        return kra1;
    }
    
    //CREATE KRA CONFIGURATION FOR ASM
    public static KRA_Configuration__c CreateKRAConfig4(Id IPId)
    {
        KRA_Configuration__c kra1  = new KRA_Configuration__c();
        kra1.Role__c = 'ASM';
        kra1.Applicable_For__c  = 'state';
        kra1.Measurement_Criteria__c = 'Target vs Actuals';
        kra1.Unit_of_Measure__c ='Value';
        kra1.Financial_Year__c = IPId;
        kra1.Quadrant__c = 'Finance';
        kra1.Parameter__c = 'Target vs Sales';
        kra1.Division__c = 'I';
        insert kra1;
        return kra1;
    }
    
    //Create KRA Parameter
    public static KRA_Parameter_Detail__c CreateKRAParm(Id kraID)
    {
        KRA_Parameter_Detail__c krapar  = new KRA_Parameter_Detail__c();
        krapar.KRA_Configuration__c = kraID;
        krapar.Achievement_from__c = 100;
        krapar.Achievement_to__c = 100;
        krapar.Points__c = 30;        
        insert krapar;
        return krapar;
    }
    
    //Create KRA Parameter
    public static KRA_Parameter_Detail__c CreateKRAParm1(Id kraID)
    {
        KRA_Parameter_Detail__c krapar  = new KRA_Parameter_Detail__c();
        krapar.KRA_Configuration__c = kraID;
        krapar.Achievement_from__c = 100;
        krapar.Achievement_to__c = 100;
        krapar.Points__c = 30;        
        insert krapar;
        return krapar;
    }
    
    //Create KRA Parameter dm
    public static KRA_Parameter_Detail__c CreateKRAParm2(Id kraID)
    {
        KRA_Parameter_Detail__c krapar  = new KRA_Parameter_Detail__c();
        krapar.KRA_Configuration__c = kraID;
        krapar.Achievement_from__c = 100;
        krapar.Achievement_to__c = 100;
        krapar.Points__c = 30;        
        insert krapar;
        return krapar;
    }
    
    //Create KRA Parameter zdm
    public static KRA_Parameter_Detail__c CreateKRAParm3(Id kraID)
    {
        KRA_Parameter_Detail__c krapar  = new KRA_Parameter_Detail__c();
        krapar.KRA_Configuration__c = kraID;
        krapar.Achievement_from__c = 100;
        krapar.Achievement_to__c = 100;
        krapar.Points__c = 30;        
        insert krapar;
        return krapar;
    }
    
    //create kra parameter asm
    public static KRA_Parameter_Detail__c CreateKRAParm4(Id kraID)
    {
        KRA_Parameter_Detail__c krapar  = new KRA_Parameter_Detail__c();
        krapar.KRA_Configuration__c = kraID;
        krapar.Achievement_from__c = 100;
        krapar.Achievement_to__c = 100;
        krapar.Points__c = 30;        
        insert krapar;
        return krapar;
    }
    
    //Create KRA Calculation rsm
    public static KRA_Calculation__c CreateKRAcal(Id kraId,Id rsmUserId)
    {
        KRA_Calculation__c kracal = new KRA_Calculation__c();
        kracal.Actual__c = 10;
        kracal.Start_Date__c = date.newInstance(2019, 04, 01);
        kracal.Target__c = 65000;
        kracal.End_Date__c = date.newInstance(2019, 3, 31);
        kracal.Points__c = 30;
        kracal.OwnerId = rsmUserId;
        kracal.KRA_Configuration__c = kraId;
        insert kracal;
        return kracal;
    }
    
    //Create KRA Calculation dm
    public static KRA_Calculation__c CreateKRAcal1(Id kraId,Id DMUserId)
    {
        KRA_Calculation__c kracal = new KRA_Calculation__c();
        kracal.Actual__c = 10;
        kracal.Start_Date__c = date.newInstance(2019, 04, 01);
        kracal.Target__c = 65000;
        kracal.End_Date__c = date.newInstance(2019, 3, 31);
        kracal.Points__c = 30;
        kracal.OwnerId = DMUserId;
        kracal.KRA_Configuration__c = kraId;
        insert kracal;
        return kracal;
    }
    
    //KRA CAL FOR SSE
    public static KRA_Calculation__c CreateKRAcal2(Id kraId,Id sseUserId)
    {
        KRA_Calculation__c kracal = new KRA_Calculation__c();
        kracal.Actual__c = 10;
        kracal.Start_Date__c = date.newInstance(2019, 04, 01);
        kracal.Target__c = 65000;
        kracal.End_Date__c = date.newInstance(2019, 3, 31);
        kracal.Points__c = 30;
        kracal.OwnerId = sseUserId;
        kracal.KRA_Configuration__c = kraId;
        insert kracal;
        return kracal;
    }
    
    //KRA CAL FOR ZDM
    public static KRA_Calculation__c CreateKRAcal3(Id kraId,Id zdmUserID)
    {
        KRA_Calculation__c kracal = new KRA_Calculation__c();
        kracal.Actual__c = 10;
        kracal.Start_Date__c = date.newInstance(2019, 04, 01);
        kracal.Target__c = 65000;
        kracal.End_Date__c = date.newInstance(2019, 3, 31);
        kracal.Points__c = 30;
        kracal.OwnerId = zdmUserID;
        kracal.KRA_Configuration__c = kraId;
        insert kracal;
        return kracal;
    }
    
    //KRA CAL FOR ASm
    public static KRA_Calculation__c CreateKRAcal4(Id kraId,Id asmUserId)
    {
        KRA_Calculation__c kracal = new KRA_Calculation__c();
        kracal.Actual__c = 10;
        kracal.Start_Date__c = date.newInstance(2019, 04, 01);
        kracal.Target__c = 65000;
        kracal.End_Date__c = date.newInstance(2019, 3, 31);
        kracal.Points__c = 30;
        kracal.OwnerId =  asmUserId;  
        kracal.KRA_Configuration__c = kraId;
        insert kracal;
        return kracal;
    }
}
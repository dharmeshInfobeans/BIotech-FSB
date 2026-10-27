public class RollingForecast_DataHandler {
    //account,contact,user-->contactid = contact.id,
    //account related---master agreement-->agreement product--->agreement product target
    //Z incentive, product
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
    public static Master_Agreement__c createMasterAgreements(Id accountId, Date stDate, Date endDate){
    	Master_Agreement__c masterAgreement = new Master_Agreement__c();
        masterAgreement.Account__c = accountId;
        masterAgreement.Agreement_Start_Date__c = stDate;
        masterAgreement.Agreement_End_Date__c = endDate;
        masterAgreement.Status__c='Approved';
        //masterAgreement.Agreement_Number__c= 'Test-5';
        insert masterAgreement;
        return masterAgreement;    
    }
    public static Agreement_Product__c createAgreementProduct(Id prodId, Id masterAgreementId){
        Agreement_Product__c agreementProd = new Agreement_Product__c();

        agreementProd.Product__c = prodId;
        agreementProd.Master_Agreement__c = masterAgreementId;
        agreementProd.Price__c = 12;
        insert agreementProd;
        return agreementProd;        
    }
    
    public static Agreement_Product_Target__c createAgreementProductTarget(Id agreementProdId, integer targetQty, Integer year, Date startDate, Date endDate){
        Agreement_Product_Target__c prodTarget_obj = new Agreement_Product_Target__c();
        prodTarget_obj.Agreement_Product__c = agreementProdId;
        prodTarget_obj.Target_Qty__c = targetQty;
        prodTarget_obj.Year__c = year;
        prodTarget_obj.Start_Date__c = startDate;
        prodTarget_obj.End_Date__c = endDate;
        insert prodTarget_obj;
        return prodTarget_obj;
    }
        
    public static  Z_Incentive__c  createZInctRecordsforInternational(String sapCode, String rbmEmpCode,String prodCode,Decimal Qty, Integer days, Date awbDate){
        Z_Incentive__c zIncentive= new Z_Incentive__c();
        zIncentive.Billing_Date__c = awbDate;
        zIncentive.Payment_Due_Date__c = system.today().addmonths(-1);
        zIncentive.Billing_Document_Status__c = 'Closed By Payment';
        zIncentive.Financial_Year__c = '2019-2020';
        zIncentive.Customer__c = sapCode;
        zIncentive.RBM_RSM__c = rbmEmpCode;                                         
        zIncentive.Dummy_Product_Code__c = prodCode;
        zIncentive.Quantity__c = Qty;
        zIncentive.No_Of_Days__c = days;
        zIncentive.Billing_type2__c = 'Sales';
        insert zIncentive;
        return zIncentive;        
    }
    
    Public static DealerPortalForecastController.WeeklyForecastWrapper getWeeklyForecastWrapperdata()
    {
        DealerPortalForecastController.WeeklyForecastWrapper weeklyWrapper=new DealerPortalForecastController.WeeklyForecastWrapper();
        weeklyWrapper.forecastQty=10;
        weeklyWrapper.globalWeekCount=42;
        weeklyWrapper.isDisabled=False;
        weeklyWrapper.month=4;
        weeklyWrapper.monthName='April';
        weeklyWrapper.startDate=system.today();
        weeklyWrapper.endDate=system.today().addmonths(-1);
        weeklyWrapper.uniqueKey='UK93854';
        weeklyWrapper.weekNumber=2;
        weeklyWrapper.year=2020;
        weeklyWrapper.yearWeekCnt=18;
        return weeklyWrapper;
    }
    Public static DealerPortalForecastController.MonthWiseWeeksWrapper getMonthForecastWrapperdata()
    {
        DealerPortalForecastController.MonthWiseWeeksWrapper monthWrapper=new DealerPortalForecastController.MonthWiseWeeksWrapper();
        list<DealerPortalForecastController.WeeklyForecastWrapper> weeklyForecastObj=new list<DealerPortalForecastController.WeeklyForecastWrapper>();
        weeklyForecastObj.add(getWeeklyForecastWrapperdata());
        monthWrapper.agreementProdId='agreementProdId';
        monthWrapper.endDate=system.today().addmonths(-1);
        monthWrapper.isDisabled=False;
        monthWrapper.month=4;
        monthWrapper.monthName='April';
        monthWrapper.monthShortName='Apr';
        monthWrapper.monthYear='4';
        monthWrapper.startDate=system.today();
        monthWrapper.thCls='monthTh5WeekCls';
        monthWrapper.totalForecast=4;
        monthWrapper.totalMonthlyActualQty=10;
        monthWrapper.totalWeeks=2;
        monthWrapper.weeklyForecastObj=weeklyForecastObj;
        monthWrapper.year=2020;
        
        return monthWrapper;
    }
    
    public static DealerPortalForecastController.WeeklyProductWrapper getWeeklyProductWrapperdata()
    {
        DealerPortalForecastController.WeeklyProductWrapper WeeklyProductWrapper = new DealerPortalForecastController.WeeklyProductWrapper();
        List<DealerPortalForecastController.MonthWiseWeeksWrapper> lstMonthWiseWeeks=new List<DealerPortalForecastController.MonthWiseWeeksWrapper>();
        lstMonthWiseWeeks.add(getMonthForecastWrapperdata());
        WeeklyProductWrapper.productId = 'productId';
        WeeklyProductWrapper.agreementProductId ='agreeProdId'; 
        WeeklyProductWrapper.productName= 'Test001';
        WeeklyProductWrapper.region= 'Miami';
        WeeklyProductWrapper.targetQty= 10;
        WeeklyProductWrapper.totalActualQty = 12;
        WeeklyProductWrapper.qtyGap= 2;
        WeeklyProductWrapper.agreementValue= 5;
        WeeklyProductWrapper.currencyISOCode= 'USD';
        WeeklyProductWrapper.customerCode= 'custCode';
        WeeklyProductWrapper.lstMonthWiseWeeks=lstMonthWiseWeeks;
        WeeklyProductWrapper.isDisabled= true;
       	return WeeklyProductWrapper;

    }
       
}
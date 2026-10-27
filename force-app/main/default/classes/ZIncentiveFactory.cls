public class ZIncentiveFactory {
    
    public static User createUser(Id profileId, String region, Id roleId, String empCode, String division){
        User sseUser = new User(
            ProfileId = profileId,
            LastName = 'sse user',
            Email = 'sseUser@gmail.com',
            Username = 'sseUser@gmail.com' + System.currentTimeMillis(),
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
            isActive = true
        );
        insert sseUser;
        return sseUser;
    } 
    public static CIty__c createRegionData(String cityName,String strRegionCode,String strContryKey){       
        CIty__c objcity = new CIty__c();
        objcity.Name = cityName;
        objcity.Region_Code__c = strRegionCode;
        objcity.country_key__c = strContryKey;
        insert objcity;
        return objcity;
    }
    public static Account createAccountData(CIty__c objCity, String sapCode){
        Id recTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Distributor').getRecordTypeId();
        Account objAccount = new Account();
        objAccount.RecordTypeId = recTypeId;
        objAccount.Name = 'Test Account';
        objAccount.region__c = objCity.Id;
        objAccount.Drug_License_No__c = 'Test';
        objAccount.First_mobile_telephone_no__c = 'Test';
        objAccount.Country_Key__c = objCity.country_key__c;
        objAccount.E_Mail__c = 'test@gmail.com';
        objAccount.Contact_Person__c = 'Test';
        objAccount.Commercial_Account_Name__c = 'Test';
        objAccount.Phone = 'Test';
        objAccount.SAP_Code__c = sapCode;
        objAccount.Account_Type__c = 'Commercial';
        objAccount.Payment_Collection_Cycle__c = 90;
        objAccount.GSTIN_No__c = 'Test';
        objAccount.CurrencyIsoCode ='INR';
        insert objAccount;
        return objAccount;
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
    public static Z_Incentive__c createZInctRecordsforDomestic(String accSAPCode, String  d1SalesEmpCode, String d1DmEmpCode, String rsmEmpCode, String zsmEmpCode,
                                                               String zdmEmpCode, String prodCode, String Qty, String days, String netValue, date billDate, 
                                                               String billingType, String d2SalesEmpCode, String d3SalesEmpCode, String d4SalesEmpCode, 
                                                               String d5SalesEmpCode, String d2DmEmpCode, String d3DmEmpCode, String d4DmEmpCode, String d5DmEmpCode,
                                                               String sellingRate, String asmEmpCode){
                                                                   Z_Incentive__c zincentive= new Z_Incentive__c();
                                                                   zincentive.Billing_Date__c = billDate;
                                                                   zincentive.Customer__c = accSAPCode;
                                                                   zincentive.D1_Div_1_Sales_Employee__c = d1SalesEmpCode;
                                                                   zincentive.D2_Div_2_Sales_Employee__c = d2SalesEmpCode;
                                                                   zincentive.D3_Div_3_Sales_Employee__c = d3SalesEmpCode;
                                                                   zincentive.D4_Div_4_Sales_Employee__c = d4SalesEmpCode;
                                                                   zincentive.D5_Div_5_Sales_Employee__c = d5SalesEmpCode;
                                                                   zincentive.M1_Div_1_Manager__c = d1DmEmpCode;
                                                                   zincentive.M2_Div_2_Manager__c = d2DmEmpCode;
                                                                   zincentive.M3_Div_3_Manager__c = d3DmEmpCode;
                                                                   zincentive.M4_Div_4_Manager__c = d4DmEmpCode;
                                                                   zincentive.M5_Div_5_Manager__c = d5DmEmpCode;
                                                                   zincentive.RBM_RSM__c = rsmEmpCode;
                                                                   zincentive.ASM__c = asmEmpCode;
                                                                   zincentive.ZBM__c = zdmEmpCode;
                                                                   zincentive.ZSM_Z1__c = zsmEmpCode;
                                                                   zincentive.Dummy_Product_Code__c = prodCode;
                                                                   zincentive.Quantity_Txt__c = Qty;
                                                                   zincentive.Days__c = days;
                                                                   zincentive.Billing_Document_Status__c = 'OPEN';                                            
                                                                   zincentive.Billing_type2__c = billingType;
                                                                   zincentive.Invoice_Created_Date__c = billDate;   
                                                                   zincentive.Net_Value_Txt__c = netValue;
                                                                   zincentive.Selling_Rate_Txt__c = sellingRate;
                                                                   insert zincentive;
                                                                   return zincentive;
                                                               }
    public static Z_Incentive__c createZInctRecordsforTurkey(String sapCode, String salesSpeEmpCode,String prodMngrEmpCode,String rsmEmpCode, 
                                                             String prodCode,Decimal Qty, Integer days, STring applicationSpeEmpCode){
                                                                 Z_Incentive__c zincentive= new Z_Incentive__c();
                                                                 zincentive.Billing_Date__c = System.today().addMonths(-4).toStartOfMonth();
                                                                 //zincentive.Billing_Date__c = system.today();
                                                                 zincentive.Billing_Document_Status__c = 'Closed By Payment';
                                                                 zincentive.Customer__c = sapCode;
                                                                 zincentive.RBM_RSM__c = rsmEmpCode;
                                                                 zincentive.D1_Div_1_Sales_Specialist__c = salesSpeEmpCode;
                                                                 zincentive.Product_Manager_Emp_Code__c = prodMngrEmpCode;  
                                                                 zincentive.Application_Specialist_Emp_Code__c = applicationSpeEmpCode;
                                                                 zincentive.Dummy_Product_Code__c = prodCode;
                                                                 zincentive.Quantity__c = Qty;
                                                                 zincentive.No_Of_Days__c = days;
                                                                 zincentive.Billing_type2__c = 'Sales';
                                                                 insert zincentive;
                                                                 return zincentive;
                                                             }
    public static  Z_Incentive__c  createZInctRecordsforInternational(String sapCode, String rbmEmpCode,String prodCode,Decimal Qty, Integer days,date awbDate){
        Z_Incentive__c zIncentive= new Z_Incentive__c();
        zIncentive.Billing_Date__c = awbDate;
        zIncentive.AWB_Date__c = awbDate;
        //zIncentive.Payment_Due_Date__c = system.today().addmonths(-1);
        zIncentive.Billing_Document_Status__c = 'OPEN';
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
    
    public static Partner_Rolling_Forecast__c createPartnerRollingForecast(Id accountId, Id productId, integer year, integer month, integer weekNumber,  date stDate, date endDate){
        Partner_Rolling_Forecast__c partnerRoll = new Partner_Rolling_Forecast__c();
        partnerRoll.Account__c =accountId;
        partnerRoll.Agreement_Product__c =productId; 
        partnerRoll.Year__c= year;
        partnerRoll.Month__c=month;
        partnerRoll.Week_Number__c=weekNumber;        
        partnerRoll.Week_Start_Date__c=stDate;
        partnerRoll.Week_End_Date__c=endDate;
        insert partnerRoll;
        return partnerRoll;
        
    }
    
    public static Master_Agreement__c createMasterAgreements(Id accountId, Date stDate, Date endDate, integer creditedPeriod){
        Master_Agreement__c masterAgreement = new Master_Agreement__c();
        masterAgreement.Account__c = accountId;
        masterAgreement.Agreement_Start_Date__c = stDate;
        masterAgreement.Agreement_End_Date__c = endDate;
        masterAgreement.Agreement_Number__c= '5';
        masterAgreement.Credited_Period__c = creditedPeriod;
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
}
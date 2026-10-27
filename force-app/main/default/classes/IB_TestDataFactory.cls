/********************************************
* @Class Name   : TestDataFactory
* @Description  : It is used to create the dummay data for all objects
* @Created Date : 07-11-2019
* @Created By   : Rajesh N.
* ****************************************/
public class IB_TestDataFactory{
    
    
    /********************************************
* @Method Name  : createRegionData
* @Params       : integer noOfRecords
* @Description  : It is used to create the dummay data Region(City).
* @Created Date : 14-11-2019
* @Created By   : Abhi
* ****************************************/
    public static List<CIty__c> createRegionData(integer noOfRecords, String cityName, String strRegionCode, String strContryKey){
        List<CIty__c> lstCity = new List<CIty__c>();
        
        for (integer i = 0; i < noOfRecords; i++){
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
* @Method Name   : createProductData
* @Params       : integer noOfRecords
* @Description  : It is used to create the dummay data Customer Conversion.
* @Created Date : 07-11-2019
* @Created By   : Rajesh N.
* ****************************************/
    public static List<Product__c> createProductData(){
        List<Product__c> lstProduct = new List<Product__c>();
        //Integer noOfProduct
        // for(integer i=0;i<noOfProduct; i++){
        Product__c objProduct = new Product__c();
        objProduct.Name = 'Test123';
        objProduct.Dummy_Product_Code__c = 'Test456';
        objProduct.Planning__c = 'Yes';
        objProduct.Active__c = true;
        objProduct.Division__c = 'II';
        objProduct.Region__c = 'Domestic';
        objProduct.MSP__c = 10;
        objProduct.Dummy_Product_Description__c = 'test';
        lstProduct.add(objProduct);
        // }
        Insert lstProduct;
        return lstProduct;
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
        integer i = 0;
        for (i = 0; i < numberOfAgreement; i++){
            Master_Agreement__c masterAgreement = new Master_Agreement__c();
            masterAgreement.Account__c = accountId;
            masterAgreement.Agreement_End_Date__c = agrmntEndDate;
            masterAgreement.Agreement_Start_Date__c = agrmntStartDate;
            lstMasterAgreements.add(masterAgreement);
        }
        insert lstMasterAgreements;
        return lstMasterAgreements;
    }
    
    public static Agreement_Product__c createAgreementProductForPoducts(id productId, Id MasterAgreementId){
        Agreement_Product__c ap = new Agreement_Product__c();
        ap.Product__c = productId;
        ap.Master_Agreement__c = MasterAgreementId;
        insert ap;
        integer i;
        List<Dealer_Actual_Sales__c> lstActualSales = new list<Dealer_Actual_Sales__c>();
        for (i = 12; i > 0; i--){
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
    public static User createUser(Id profileId, String region, Id roleId, String empCode, String division, Id contactId){
        User usr = new User(ProfileId = profileId, LastName = 'Test usr', Email = 'testUser@gmail.com', Username = 'testUser@gmail.com' + System.currentTimeMillis(), CompanyName = 'TEST', Title = 'title', Alias = 'alias', TimeZoneSidKey = 'America/Los_Angeles', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', UserRoleId = roleId, Employee_Code__c = empCode, Division__c = division, User_Type__c = region, isActive = true, ContactId = contactId, Date_of_Joining__c = system.today(), Portal_User_Role__c = 'RBM');
        insert usr;
        return usr;
    }
    
    public static CIty__c createRegionData(String cityName, String strRegionCode, String strContryKey){
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
        objAccount.CurrencyIsoCode = 'USD';
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
        objAccount.Number_of_an_SD_business_partner_Z1__c = '11';
        objAccount.BillingCity = 'Test billing city';
        objAccount.BillingCountry = 'BR';
        objAccount.BillingState = 'Test billing state';
        objAccount.BillingPostalCode = '1234';
        objAccount.BillingStreet = 'Test billing street';
        insert objAccount;
        return objAccount;
    }
    
    public static Contact createContact(Id accId, String lastName){
        Integer i=0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        Contact con = new Contact();
        con.AccountId = accID;        
        con.FirstName = 'First';
        con.LastName = lastName;
        con.CurrencyIsoCode = 'USD';
        con.MailingStreet='testStreet';
        con.MailingCity='testCity';
        con.MailingState='testState';
		con.MailingCountry='testCountry';
        con.MailingPostalCode='testPostalCode';

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
        objProduct.MSP__c = 10;
        objProduct.Dummy_Product_Description__c = prodName;
        Insert objProduct;
        return objProduct;
    }
    
    public static Plant__C createPlantdata(String Name, String Port_of_Loading, String origin){
        Plant__C pl1 = new Plant__c();
        pl1.Name = Name;
        Pl1.Port_of_Loading__c = Port_of_Loading;
        Pl1.Orgin__c = origin;
        insert pl1;
        return pl1;
    }
    
    public static Product_Model__c createProductModelData(Id productId, String modelName){
        Product_Model__c pm = new Product_Model__c();
        pm.Product__c = productId;
        pm.Text_Name__c = modelName;
        
        insert pm;
        return pm;
    }
    
    public static Product_Material_Stock__c createProductMaterialStockData(String name, string materialCode, Id plantId, Id productModelID){
        Product_Material_Stock__c productMS = new Product_Material_Stock__c();
        //productMS.Name = name;
        productMS.Material_Code__c = materialCode;
        productMS.Plant__c = plantId;
        productMS.Product_Models__c = productModelID;
        productMS.Quantity__c = 15;
        productMS.Stock_Id__c = plantId+'-'+materialCode;
        
        insert productMs;
        return productMS;
    }
    
    public static Order_Product__c createOrderProductData(Id orderId, Boolean is_Parent_Products, Id agreementProdId, Id ProductId, String Axis_Angle, String Cyindrical_Power, Decimal Quantity, String Model){
        Order_Product__c op = new Order_Product__c();
        op.Total_Price__c = 400;
        op.Model_Txt__c = model;
        op.Axis_Angle__c = Axis_Angle;
        op.Cyindrical_Power__c = Cyindrical_Power;
        op.Discount__c = 0;
        op.Parent_Unique_Key__c = '1695283552AJziYq9Dx3';
        op.Unique_Key__c = '1695283554ELNC1sklpm';
        op.Unit_Price__c = 192;
        op.FOC_Quantity__c = 2;
        op.Spherical_Power__c = 3;
        op.Quantity__c = Quantity;
        op.Sub_Total_Price__c = 768;
        op.Product__c = ProductId;
        op.Agreement_Product__c = agreementProdId;
        op.Is_Parent_Products__c = is_Parent_Products;
        op.Order__c = orderId;
        insert op;
        return op;
    }
    
    public static Freight_Request__c createFreightRequestData(Id orderId, Id plantId, String productName){
        Freight_Request__c fr = new Freight_Request__c();
        fr.Freight_Amount__c = 1836;
        //fr.Name = 'a1MBl000000APZp';
        fr.Order__c = orderId;
        fr.Plant__c = plantId;
        fr.Products__c = productName;
        
        insert fr;
        return fr;
    }
    
    /********************************************
* @Method Name   : createAccountData
* @Params       : integer noOfRecords
* @Description  : It is used to create the dummay data Customer Conversion.
* @Created Date : 07-11-2019
* @Created By   : Abhi
* ****************************************/
    public static List<Account> createAccountData(Integer noOfAccount, id recTypeId, CIty__c objCity){
        
        Profile pf = [SELECT Id
                      FROM Profile
                      WHERE Name = 'System Administrator'];
        //    UserRole ur = [SELECT Id FROM UserRole WHERE Name='SSE'];//new UserRole(Name = 'SSE');
        //  insert ur;
        
        //  User tuser = [SELECT Id
        //              FROM User
        ///            where isActive = true
        //         Limit 1];
        
        User tuser = new User(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'johndoe@example.com',
            Username = 'johndoe234@example.com',  // Must be unique across Salesforce
            Alias = 'jdoe',
            TimeZoneSidKey = 'America/New_York',  // Timezone
            LocaleSidKey = 'en_US',               // Locale
            EmailEncodingKey = 'UTF-8',           // Email Encoding
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,  // Assign Profile
            LanguageLocaleKey = 'en_US',          // Language
            CompanyName = 'Example Company',
            IsActive = true  // Activate the user
        );
        
        try {
            insert tuser;
            System.debug('New user created with ID: ' + tuser.Id);
        } catch (DmlException e) {
            System.debug('Error creating user: ' + e.getMessage());
        }
        
        
        
        List<Account> lstAccount = new List<Account>();
        
        System.runAs(tuser){
            
            Id RecordTypeIdContact = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Distributor').getRecordTypeId();
            
            for (integer i = 0; i < noOfAccount; i++){
                Account objAccount = new Account();
                objAccount.RecordTypeId = recTypeId;
                objAccount.Name = 'Test' + i;
                objAccount.region__c = objCity.Id;
                objAccount.Drug_License_No__c = 'Test' + i;
                objAccount.First_mobile_telephone_no__c = 'Test' + i;
                objAccount.Country_Key__c = objCity.country_key__c;
                objAccount.E_Mail__c = 'test@gmail.com';
                objAccount.Contact_Person__c = 'Test' + i;
                objAccount.Commercial_Account_Name__c = 'Test' + i;
                objAccount.Phone = 'Test' + i;
                objAccount.SAP_Code__c = '45612';
                objAccount.Account_Type__c = 'Commercial';
                objAccount.Payment_Collection_Cycle__c = 90;
                objAccount.GSTIN_No__c = 'Test' + i;
                lstAccount.add(objAccount);
            }
            Database.insert (lstAccount);
        }
        //lstAccount.add(accObj);
        return lstAccount;
    }
    
}
@isTest
public class LeadsTriggerHelperClassTest {
    public Static boolean isRunFirstTime =false;
    public static testmethod void test(){
   
        
        
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
       
        
       
        
        Id RecordTypeIdContact = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Distributor').getRecordTypeId();
        //UserRole r =[SELECT Id,name FROM UserRole WHERE Name='RSM_D'];
        
        list<lead__c> newlist = new list<lead__c>();
        CIty__c robj = new CIty__c();
        robj.country_key__c = 'IN';
        robj.Name='MADHYA PRADESH';
        robj.Region_Code__c = '12';
        insert robj;
        
        Account accObj = new Account();
        accObj.Name = 'Test';
        accObj.AccountNumber = '12345678';
        accObj.Region__c = robj.Id;
        accObj.Street_2__c = 'street2';
        accObj.Street_3__c = 'street3';
        accObj.Street_4__c = 'street4';
        accObj.Street_5__c = 'street5';
        accObj.Country_Key__c='IN';
        accObj.City__c='Gwalior';
        accObj.City_postal_code__c='400001';
        accObj.recordtypeid=RecordTypeIdContact;
        accObj.Branch__c = '';
        accObj.Sub_Status__c=  'Submitted To Approver 1';
        accObj.Medical_Registration_No__c='MEDREG123424567';
        accObj.GSTIN_No__c='GSTIN2343423456';
        accObj.SAP_Code__c='122322';
        accObj.BillingState = 'MADHYA PRADESH';
        //    List <Monthly_Plan__c> mp_list=new List <Monthly_Plan__c>();
        accObj.BillingCity       = 'Gwalior';
accObj.BillingStreet     = 'chandranagr koteshwar';
accObj.BillingState      = 'MADHYA PRADESH';
accObj.BillingPostalCode = '474001';
accObj.BillingCountry    = 'IN';
        insert accObj;
        
         Account accObj1 = new Account();
        accObj1.Name = 'Test';
        accObj1.AccountNumber = '12345678';
        accObj1.Region__c = robj.Id;
        accObj1.BillingState = 'MADHYA PRADESH';
        accObj1.Street_2__c = 'street2';
        accObj1.Street_3__c = 'street3';
        accObj1.Street_4__c = 'street4';
        accObj1.Street_5__c = 'street5';
        accObj1.Country_Key__c='IN';
        accObj1.City__c='mumbai';
        accObj1.City_postal_code__c='400001';
        accObj1.recordtypeid=RecordTypeIdContact;
        accObj1.Branch__c = '';
        accObj1.Sub_Status__c=  'Submitted To Approver 1';
        accObj1.Medical_Registration_No__c='MEDREG123424567';
        accObj1.GSTIN_No__c='GSTIN2343423456';
        accObj1.SAP_Code__c='12343';
        accObj1.BillingCity       = 'Mumbai';
accObj1.BillingStreet     = 'street2';
accObj1.BillingPostalCode = '400001';
accObj1.BillingCountry    = 'IN';
      //List <Monthly_Plan__c> mp_list=new List <Monthly_Plan__c>();
        
        insert accObj1;

		Org_Role_Hierarchy__c businessMappingOrgRole = new Org_Role_Hierarchy__c(
            Name = 'Test Org Role Hierarchy - Business Mapping',
            Business_Mapping__c = true
        );
        insert businessMappingOrgRole;
        
        
        test.startTest();
        Lead__c lea=new Lead__c();
        lea.Name='tets';
        lea.First_Name__c='test';
        lea.Last_Name__c='singh';
        lea.Company__c='Plus91labs';
        lea.Product__c='BIO BLADE';
        lea.Billing_City__c='Gwalior';
        lea.Billing_code__c='474001';
        lea.Country__c='INDIA';
        lea.Billing_state__c='MADHYA PRADESH';
        lea.Billing_country__c='INDIA';
        lea.Email__c='pankajsinghania123@gmail.com';
        lea.Mobile__c='1234567890';
        lea.Billing_Street__c='chandranagr koteshwar';
        lea.SAP_Code__c='12343122345';
        lea.Approval_status__c='Approved';
        lea.Aproved_By_Manager__c=true;
        lea.Lead_Stage__c='Evaluations';
        lea.CE_CIS_Approval__c=true;
        lea.Status__c=true;
        //lea.RSM__c  = UserInfo.getUserId();
        lea.ZSM__c  = UserInfo.getUserId();
        lea.Plant_code__c = '1223';
        lea.Plant__c = 'Biotech';
        lea.Billing_Street__c='test';
      //  lea.Account__c=accObj.Id;
        lea.New_Customer__c=true;
         lea.Region_Code__c = '213';
        //lea.SAP_Code__c='122322';

        
        insert lea;
        lea.Billing_City__c='Delhi';
        lea.Lead_Stage__c='Commercialization';
        update lea;
     


        
        
         Address__c ad = new Address__c();
        //ct.Name = 'MADHYA PRADESH';
        ad.Account__c = accObj.Id;
        ad.Billing_City__c = 'Gwalior';
       // ad.Billing_code__c = '472118';
        ad.Billing_country__c = 'IN';
        ad.Billing_state__c = 'MADHYA PRADESH';
        ad.Billing_Street__c = 'MORAR';
        insert ad;
        
      
        
        Target__c targetdata = new Target__c();
        targetdata.Activity_Type__c = 'PHAKIC TRAINING';
        targetdata.Name = 'test';
        targetdata.Date__c = system.today();
		targetdata.Activity_Type__c = 'CONFERENCES';
        insert targetdata;
        
        campaign__c campaigndata = new campaign__c();
        campaigndata.Name = 'test';
        campaigndata.Focus_Product__c= 'OPTIFLEX GENESIS';
        campaigndata.Activity_Type__c = 'PRODUCT TRAINING';
        campaigndata.Planned_Attendees__c = 20;
        campaigndata.Target__c = targetdata.Id;
        campaigndata.Categorize__c='Biotech Driven Event';
        insert campaigndata;
        
        Country__c country = new Country__c();
        
        // Manually assign field values
        country.Country__c = 'IN';
        country.State__c = 'MADHYA PRADESH';
        country.CITY__c = 'GWALIOR';
        country.Region__c = 'CENTRAL';
        country.Region_code__c = '01';
        country.Zone__c = 'Zone 1';
        
        // Insert or use the record
        insert country; // or add to a list for bulk insert
        
        Lead__c lea2=new Lead__c();
        lea2.Name='tets';
        lea2.First_Name__c='test';
        lea2.Last_Name__c='singh';
        lea2.Company__c='Plus91labs';
        lea2.Product__c='BIO BLADE';
        lea2.Billing_City__c='MUMBAI';
        lea2.Billing_code__c='474001';
        lea2.Country__c='IN';
        lea2.Billing_state__c='MADHYA PRADESH';
        lea2.Billing_country__c='IN';
        lea2.Email__c='pankajsinghania123@gmail.com';
        lea2.Mobile__c='1234523890';
        lea2.Billing_Street__c='chandranagrkoteshwaruireyriuefhjkvndkfhiuhfuiehiueiufheruheuirhweinhfjsdhfdijfieurf';
       // lea2.SAP_Code__c='12343122';
        lea2.Approval_status__c='Approved';
        lea2.Aproved_By_Manager__c=true;
        lea2.Lead_Stage__c='Evaluations';
        lea2.CE_CIS_Approval__c=true;
         lea2.Status__c=true;
       // lea2.Billing_Street__c='test';
      //  lea.Account__c=accObj.Id;
        lea2.Existing_customer__c=true;
        lea2.SAP_Code__c='122322';
         lea2.Account__c=accObj.id;
        lea2.GM_NSM__c  = UserInfo.getUserId();
        lea2.ZSM__c  = UserInfo.getUserId();
        lea2.Plant_code__c = '1223';
        lea2.Plant__c = 'Biotech';
        lea2.Region_Code__c = '213';
        lea2.Upload_Count__c = 1;
		
        
        insert lea2;
        
        // Create the parent CIS_Header__c record
        CIS_Header__c cisHeader = new CIS_Header__c();
        //cisHeader.Name = 'CIS-001';
        cisHeader.Ce_Cis_Rating__c = 'A';
        cisHeader.Status__c = 'Approved';
        cisHeader.User__c = lea2.OwnerId; // Use a real User Id
        cisHeader.No_of_LVC_Procedures__c = 5;
        //cisHeader.unique__c = UNQ123';
        cisHeader.Leads__c = lea2.Id; // Use a valid Lead Id       
       
        // Insert records (insert header first to get Id)
        insert cisHeader;
        
        lea2.Billing_City__c='Delhi';
        lea2.Lead_Stage__c='Upgrade';
        update lea2;
        
          Lead__c lea3=new Lead__c();
        lea3.Name='tets';
        lea3.First_Name__c='test';
        lea3.Last_Name__c='singh';
        lea3.Company__c='Plus91labs';
        lea3.Product__c='BIO BLADE';
        lea3.Billing_City__c='Gwalior';
        lea3.Billing_code__c='474001';
        lea3.Country__c='INDIA';
        lea3.Billing_state__c='MADHYA PRADESH';
        lea3.Billing_country__c='india';
        lea3.Email__c='pankajsinghania123@gmail.com';
        lea3.Mobile__c='1234598890';
        lea3.Billing_Street__c='chandranagr koteshwar testtuiyreuitreiutwiuertwitiwretuoiwreutoirewutiowrenfritireiotuireoytireutyiuerytiureyt testtuiyreuitreiutwiuertwitiwretuoiwreutoirewutiowrenfritireiotuireoytireutyiuerytiureyt';
       // lea2.SAP_Code__c='12343122';
        lea3.Approval_status__c='Approved';
        lea3.Aproved_By_Manager__c=true;
        lea3.Lead_Stage__c='Evaluations';
        lea3.CE_CIS_Approval__c=true;
         lea3.Status__c=true;
        lea3.Billing_Street__c='testtuiyreuitreiutwiuertwitiwretuoiwreutoirewutiowrenfritireiotuireoytireutyiuerytiureyt ertiuyrewuityruietyrweuityreuityrewuit reuytuireyt';
      //  lea.Account__c=accObj.Id;
        lea3.Existing_customer__c=true;
        lea3.SAP_Code__c='122322';
         lea3.Account__c=accObj.id;
        lea3.Campaign__c=campaigndata.id;
         lea3.Region_Code__c = '213';
        insert lea3;
        lea3.Billing_City__c='Delhi';
        lea3.Lead_Stage__c='Commercialization';
        update lea3;
    
        
        
        
        
        newlist.add(lea2);
        //newlist.add(lea3);
        
        
        Map<Id,Lead__c> oldMap = new Map<Id,Lead__c>();
        oldMap.put(lea2.Id,lea2);
        
        Map<String,String> accSapMap = new Map<String,String>();
        accSapMap.put(lea.id,lea.Name);
        
        Map<String,Account> accAdrsTagMap = new Map<String,Account>();
        accAdrsTagMap.put(lea.SAP_Code__c,accObj);
        
        //LeadsTriggerHelperClass.insAddressData(newlist);
        if(!isRunFirstTime){
            isRunFirstTime = true;
              LeadsTriggerHelperClass.testMethodIterate();
        }
      
       // LeadsTriggerHelperClass.createAccountData(newList, oldMap);
       // LeadsTriggerHelperClass.beforeLeadInsert(newList);
       // LeadsTriggerHelperClass.insertCisHeaderData(accSapMap, accAdrsTagMap);
        //LeadsTriggerHelperClass.submitForApproval(newList, oldMap);
        delete lea;
        undelete lea;
        System.debug('After delete');
         //LeadsTriggerHelperClass.updateCampaignData(newList, oldMap);
        test.stopTest();
        
        
    }
}
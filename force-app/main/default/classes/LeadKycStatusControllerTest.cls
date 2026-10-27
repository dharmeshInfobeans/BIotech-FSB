@isTest
public class LeadKycStatusControllerTest {
    public static testmethod void test(){
        CE_CIS_Configuration__c ceCisConf=new CE_CIS_Configuration__c();
        ceCisConf.From_Range__c=120;
        ceCisConf.To_Range__c=130;
        ceCisConf.Country__c='INDIA';
        ceCisConf.Type__c='Surgeries';
        ceCisConf.Rating__c='A';
        insert ceCisConf;
        
        
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
        Id RecordTypeIdContact = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Distributor').getRecordTypeId();
        //UserRole r =[SELECT Id,name FROM UserRole WHERE Name='RSM_D'];
        
        list<lead__c> newlist = new list<lead__c>();
        CIty__c robj = new CIty__c();
        robj.country_key__c = 'IN';
        robj.Name='Maharashtra';
        robj.Region_Code__c = 'DL';
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
        accObj.City__c='mumbai';
        accObj.City_postal_code__c='400001';
        accObj.recordtypeid=RecordTypeIdContact;
        accObj.Branch__c = '';
        accObj.Sub_Status__c=  'Submitted To Approver 1';
        accObj.Medical_Registration_No__c='MEDREG123424567';
        accObj.GSTIN_No__c='GSTIN2343423456';
        accObj.SAP_Code__c='122322';
        //    List <Monthly_Plan__c> mp_list=new List <Monthly_Plan__c>();
        
        insert accObj;
        
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
        lea.Billing_state__c='Mp';
        lea.Billing_country__c='india';
        lea.Email__c='pankajsinghania123@gmail.com';
        lea.Mobile__c='1234567890';
        lea.Billing_Street__c='chandranagr koteshwar';
        lea.SAP_Code__c='12343122';
        lea.Approval_status__c='Approved';
        lea.Aproved_By_Manager__c=true;
        lea.Lead_Stage__c='Upgrade';
        lea.CE_CIS_Approval__c=true;
        lea.Status__c=true;
        lea.Billing_Street__c='test';
        insert lea;
        
        
        lea.SAP_Code__c='122322';
        update lea;
        
        CIS_Header__c cis=new CIS_Header__c();
        cis.No_of_LVC_Procedures__c=122;
        cis.Regular_Percentage__c=12;
        cis.Premium_Percentage__c=12;
        cis.Leads__c=lea.Id;
        cis.RecordTypeId=Schema.SObjectType.CIS_Header__c.getRecordTypeInfosByName().get('INDIA'). getRecordTypeId();
        cis.Status__c='Approved';
        insert cis;
        
        Address__c adrs = new Address__c();
        adrs.Account__c = accObj.Id;
        adrs.Ship_to__c = 'delhi';
        adrs.Lead__c = lea.Id;
        adrs.Bill_to__c = 'gwalior';
        adrs.Billing_code__c = '563436';
        adrs.Is_Primary__c = 'test';
        
        // Fill in the required billing address fields
        adrs.Billing_City__c = 'Gwalior';
        adrs.Billing_Country__c = 'India';
        adrs.Billing_State__c = 'Madhya pradesh';
        adrs.Billing_Street__c='test';
        insert adrs;
        
        CIS_Line__c cisLine=new CIS_Line__c();
        cisLine.CIS_Header__c=cis.Id;
        cisLine.Company__c='Biotech';
        cisLine.Product__c='Phakic';
        cisLine.No_of_Surguries__c=134;
        insert cisLine;
        
        lea.Status__c=true;
        lea.CE_CIS_Approval__c=true;
        lea.Lead_Stage__c='Won';
        update lea;
        
        
        lead__c lea1=new lead__c();
        lea1.Name='sourav';
        lea1.First_Name__c='sourav';
        lea1.Last_Name__c='singh';
        lea1.Company__c='Plus91labs1';
        lea1.Product__c='EYECRYL TORIC';
        lea1.Billing_City__c='Gwalior';
        lea1.Billing_code__c='474001';
        lea1.Billing_country__c='india';
        lea1.Billing_Street__c='chandranagar';
        lea1.Country__c='India';
        lea1.Billing_state__c='Mp';
        lea1.Email__c='pankaj333@gmail.com';
        lea1.Mobile__c='1234567890';
        lea1.Billing_Street__c='chandranagr koteshwar';
        lea1.SAP_Code__c='122322';
        lea1.CE_CIS_Approval__c=true;
        lea1.Status__c=true;
        
        
        lea1.lead_Stage__c='upgrade';
        insert lea1;
        
        lea1.Status__c=true;
        lea1.CE_CIS_Approval__c=true;
        lea1.Approval_status__c = 'Approved';
        lea1.Aproved_By_Manager__c = true;
        lea1.lead_Stage__c='Won';
        update lea1;
        
        Lead__c testLead = [SELECT Id, KYC_Document_Uploaded__c FROM Lead__c LIMIT 1];
        
        Lead__c result = LeadKycStatusController.getLeadRecords(testLead.Id);
        
        Test.stopTest();        
    }
    
}
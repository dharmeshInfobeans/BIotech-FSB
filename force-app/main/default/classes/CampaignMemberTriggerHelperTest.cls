@istest
public class CampaignMemberTriggerHelperTest {
    @istest
    public static void testData() {
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
        Target__c tg=new Target__c();
        tg.Name='Test';
        tg.Date__c=System.today();
        insert tg;
        
        Campaign__c cmp=new Campaign__c();
        // cmp.City__c=accObj.City__c;
        cmp.Product_1_Name__c='Test';
        cmp.Product_2_Name__c='Test1';
        cmp.Product_3_Name__c='Test2';
        cmp.Product_4_Name__c='Test3';
        cmp.Product_1_Opportunity__c=1;
        cmp.Product_2_Opportunity__c=2;
        cmp.Product_3_Opportunity__c=3;
        cmp.Product_4_Opportunity__c=4;
        cmp.Start_Date__c=System.today();
        cmp.End_Date__c=System.today()+3;
        cmp.Target__c=tg.Id;
        cmp.Activity_Type__c = 'CONFERENCES';
        cmp.categorize__c = 'Biotech Driven Event';
        cmp.Campaign_stage__c='CME';
        insert cmp;
        
        
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
        lea.Lead_Stage__c='Presentation';
        lea.Campaign__c=cmp.id;
        insert lea;
        
        
        Campaign_Member__c cmpm=new Campaign_Member__c();
        cmpm.Campaign1__c=cmp.Id;
        cmpm.Product_1_Name__c='Test';
        cmpm.Product_1Opportunity__c=12345;
        cmpm.Product_2_Name__c='Test1';
        cmpm.Product_2_Opportunity__c=2345;
        cmpm.Product_3_Opportunity__c=2345654;
        cmpm.Product_4_Opportunity__c =23456; 
        cmpm.Lead1__c=lea.Id;
        cmpm.Member_Type__c = 'Moderator';
        insert cmpm;
        
        cmpm.Attended__c=true;
        update cmpm;
    }
    @istest
    public static void testData2() {
        
        
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
        Target__c tg=new Target__c();
        tg.Name='Test';
        tg.Date__c=System.today();
        insert tg;
        
        Campaign__c cmp=new Campaign__c();
        // cmp.City__c=accObj.City__c;
        cmp.Product_1_Name__c='Test';
        cmp.Product_2_Name__c='Test1';
        cmp.Product_3_Name__c='Test2';
        cmp.Product_4_Name__c='Test3';
        cmp.Product_1_Opportunity__c=1;
        cmp.Product_2_Opportunity__c=2;
        cmp.Product_3_Opportunity__c=3;
        cmp.Product_4_Opportunity__c=4;
        cmp.Start_Date__c=System.today();
        cmp.End_Date__c=System.today()+3;
        cmp.Target__c=tg.Id;
        cmp.Activity_Type__c = 'CONFERENCES';
        cmp.Campaign_stage__c='RTM';
        cmp.categorize__c = 'Biotech Driven Event';
        insert cmp;
        
        
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
        lea.Lead_Stage__c='Presentation';
        lea.Campaign__c=cmp.id;
        insert lea;
        
        
        Campaign_Member__c cmpm=new Campaign_Member__c();
        cmpm.Campaign1__c=cmp.Id;
        cmpm.Product_1_Name__c='Test';
        cmpm.Product_1Opportunity__c=12345;
        cmpm.Product_2_Name__c='Test1';
        cmpm.Product_2_Opportunity__c=2345;
        cmpm.Product_3_Opportunity__c=2345654;
        cmpm.Product_4_Opportunity__c =23456; 
        cmpm.Lead1__c=lea.Id;
        cmpm.Member_Type__c = 'Moderator';
        insert cmpm;
        cmpm.Attended__c=true;
        update cmpm;
    }
    @istest
    public static void testData3() {
        
        
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
        Target__c tg=new Target__c();
        tg.Name='Test';
        tg.Date__c=System.today();
        insert tg;
        
        Campaign__c cmp=new Campaign__c();
        // cmp.City__c=accObj.City__c;
        cmp.Product_1_Name__c='Test';
        cmp.Product_2_Name__c='Test1';
        cmp.Product_3_Name__c='Test2';
        cmp.Product_4_Name__c='Test3';
        cmp.Product_1_Opportunity__c=1;
        cmp.Product_2_Opportunity__c=2;
        cmp.Product_3_Opportunity__c=3;
        cmp.Product_4_Opportunity__c=4;
        cmp.Start_Date__c=System.today();
        cmp.End_Date__c=System.today()+3;
        cmp.Target__c=tg.Id;
        cmp.Activity_Type__c = 'CONFERENCES';
        cmp.categorize__c = 'Biotech Driven Event';
        cmp.Campaign_stage__c='User Meeting';
        insert cmp;
        
        
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
        lea.Lead_Stage__c='Presentation';
        lea.Campaign__c=cmp.id;
        insert lea;
        
        
        Campaign_Member__c cmpm=new Campaign_Member__c();
        cmpm.Campaign1__c=cmp.Id;
        cmpm.Product_1_Name__c='Test';
        cmpm.Product_1Opportunity__c=12345;
        cmpm.Product_2_Name__c='Test1';
        cmpm.Product_2_Opportunity__c=2345;
        cmpm.Product_3_Opportunity__c=2345654;
        cmpm.Product_4_Opportunity__c =23456; 
        cmpm.Lead1__c=lea.Id;
        cmpm.Member_Type__c = 'Moderator';
        insert cmpm;
        
        cmpm.Attended__c=true;
        update cmpm;
        
        
    }
    @istest
    public static void testData4() {
        
        
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
        Target__c tg=new Target__c();
        tg.Name='Test';
        tg.Date__c=System.today();
        insert tg;
        
        Campaign__c cmp=new Campaign__c();
        // cmp.City__c=accObj.City__c;
        cmp.Product_1_Name__c='Test';
        cmp.Product_2_Name__c='Test1';
        cmp.Product_3_Name__c='Test2';
        cmp.Product_4_Name__c='Test3';
        cmp.Product_1_Opportunity__c=1;
        cmp.Product_2_Opportunity__c=2;
        cmp.Product_3_Opportunity__c=3;
        cmp.Product_4_Opportunity__c=4;
        cmp.Start_Date__c=System.today();
        cmp.End_Date__c=System.today()+3;
        cmp.Target__c=tg.Id;
        cmp.Activity_Type__c = 'CONFERENCES';
        cmp.categorize__c = 'Biotech Driven Event';
        cmp.Campaign_stage__c='High Impact CME';
        insert cmp;
        
        
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
        lea.Lead_Stage__c='Presentation';
        lea.Campaign__c=cmp.id;
        insert lea;
        
        
        Campaign_Member__c cmpm=new Campaign_Member__c();
        cmpm.Campaign1__c=cmp.Id;
        cmpm.Product_1_Name__c='Test';
        cmpm.Product_1Opportunity__c=12345;
        cmpm.Product_2_Name__c='Test1';
        cmpm.Product_2_Opportunity__c=2345;
        cmpm.Product_3_Opportunity__c=2345654;
        cmpm.Product_4_Opportunity__c =23456; 
        cmpm.Lead1__c=lea.Id;
        cmpm.Member_Type__c = 'Moderator';
        insert cmpm;
        
        
    }
    @istest
    public static void testData5() {
        
        
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
        Target__c tg=new Target__c();
        tg.Name='Test';
        tg.Date__c=System.today();
        insert tg;
        
        Campaign__c cmp=new Campaign__c();
        // cmp.City__c=accObj.City__c;
        cmp.Product_1_Name__c='Test';
        cmp.Product_2_Name__c='Test1';
        cmp.Product_3_Name__c='Test2';
        cmp.Product_4_Name__c='Test3';
        cmp.Product_1_Opportunity__c=1;
        cmp.Product_2_Opportunity__c=2;
        cmp.Product_3_Opportunity__c=3;
        cmp.Product_4_Opportunity__c=4;
        cmp.Start_Date__c=System.today();
        cmp.End_Date__c=System.today()+3;
        cmp.Target__c=tg.Id;
        cmp.Activity_Type__c = 'CONFERENCES';
        cmp.categorize__c = 'Biotech Driven Event';
        cmp.Campaign_stage__c='KOL/FOL Development';
        insert cmp;
        
        
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
        lea.Lead_Stage__c='Presentation';
        lea.Campaign__c=cmp.id;
        insert lea;
        
        
        Campaign_Member__c cmpm=new Campaign_Member__c();
        cmpm.Campaign1__c=cmp.Id;
        cmpm.Product_1_Name__c='Test';
        cmpm.Product_1Opportunity__c=12345;
        cmpm.Product_2_Name__c='Test1';
        cmpm.Product_2_Opportunity__c=2345;
        cmpm.Product_3_Opportunity__c=2345654;
        cmpm.Product_4_Opportunity__c =23456; 
        cmpm.Lead1__c=lea.Id;
        cmpm.Member_Type__c = 'Moderator';
        insert cmpm;
        
        
        cmpm.Attended__c=true;
        update cmpm;
        
        
    }
    @istest
    public static void testData6() {
        
        
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
        Target__c tg=new Target__c();
        tg.Name='Test';
        tg.Date__c=System.today();
        insert tg;
        
        Campaign__c cmp=new Campaign__c();
        // cmp.City__c=accObj.City__c;
        cmp.Product_1_Name__c='Test';
        cmp.Product_2_Name__c='Test1';
        cmp.Product_3_Name__c='Test2';
        cmp.Product_4_Name__c='Test3';
        cmp.Product_1_Opportunity__c=1;
        cmp.Product_2_Opportunity__c=2;
        cmp.Product_3_Opportunity__c=3;
        cmp.Product_4_Opportunity__c=4;
        cmp.Start_Date__c=System.today();
        cmp.End_Date__c=System.today()+3;
        cmp.Target__c=tg.Id;
        cmp.Activity_Type__c = 'CONFERENCES';
         cmp.categorize__c = 'Biotech Driven Event';
        cmp.Campaign_stage__c='Virtual exp. Lab';
        insert cmp;
        
        
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
        lea.Lead_Stage__c='Presentation';
        lea.Campaign__c=cmp.id;
        insert lea;
        
        
        Campaign_Member__c cmpm=new Campaign_Member__c();
        cmpm.Campaign1__c=cmp.Id;
        cmpm.Product_1_Name__c='Test';
        cmpm.Product_1Opportunity__c=12345;
        cmpm.Product_2_Name__c='Test1';
        cmpm.Product_2_Opportunity__c=2345;
        cmpm.Product_3_Opportunity__c=2345654;
        cmpm.Product_4_Opportunity__c =23456; 
        cmpm.Lead1__c=lea.Id;
        cmpm.Member_Type__c = 'Moderator';
        insert cmpm;
        
        cmpm.Attended__c=true;
        update cmpm;
        
        
    }
    @istest
    public static void testData7() {
        
        
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
        Target__c tg=new Target__c();
        tg.Name='Test';
        tg.Date__c=System.today();
        insert tg;
        
        Campaign__c cmp=new Campaign__c();
        // cmp.City__c=accObj.City__c;
        cmp.Product_1_Name__c='Test';
        cmp.Product_2_Name__c='Test1';
        cmp.Product_3_Name__c='Test2';
        cmp.Product_4_Name__c='Test3';
        cmp.Product_1_Opportunity__c=1;
        cmp.Product_2_Opportunity__c=2;
        cmp.Product_3_Opportunity__c=3;
        cmp.Product_4_Opportunity__c=4;
        cmp.Start_Date__c=System.today();
        cmp.End_Date__c=System.today()+3;
        cmp.Target__c=tg.Id;
        cmp.Activity_Type__c = 'CONFERENCES';
         cmp.categorize__c = 'Biotech Driven Event';
        cmp.Campaign_stage__c='Wet Labs';
        insert cmp;
        
        
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
        lea.Lead_Stage__c='Presentation';
        lea.Campaign__c=cmp.id;
        insert lea;
        
        
        Campaign_Member__c cmpm=new Campaign_Member__c();
        cmpm.Campaign1__c=cmp.Id;
        cmpm.Product_1_Name__c='Test';
        cmpm.Product_1Opportunity__c=12345;
        cmpm.Product_2_Name__c='Test1';
        cmpm.Product_2_Opportunity__c=2345;
        cmpm.Product_3_Opportunity__c=2345654;
        cmpm.Product_4_Opportunity__c =23456; 
        cmpm.Lead1__c=lea.Id;
        cmpm.Member_Type__c = 'Moderator';
        insert cmpm;
        
        
        cmpm.Attended__c=true;
        update cmpm;
        
        
    }
    @istest
    public static void testData8() {
        
        
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
        Target__c tg=new Target__c();
        tg.Name='Test';
        tg.Date__c=System.today();
        insert tg;
        
        Campaign__c cmp=new Campaign__c();
        // cmp.City__c=accObj.City__c;
        cmp.Product_1_Name__c='Test';
        cmp.Product_2_Name__c='Test1';
        cmp.Product_3_Name__c='Test2';
        cmp.Product_4_Name__c='Test3';
        cmp.Product_1_Opportunity__c=1;
        cmp.Product_2_Opportunity__c=2;
        cmp.Product_3_Opportunity__c=3;
        cmp.Product_4_Opportunity__c=4;
        cmp.Start_Date__c=System.today();
        cmp.End_Date__c=System.today()+3;
        cmp.Target__c=tg.Id;
        cmp.Activity_Type__c = 'CONFERENCES';
         cmp.categorize__c = 'Biotech Driven Event';
        cmp.Campaign_stage__c='Testimonial';
        insert cmp;
        
        
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
        lea.Lead_Stage__c='Presentation';
        lea.Campaign__c=cmp.id;
        insert lea;
        
        
        Campaign_Member__c cmpm=new Campaign_Member__c();
        cmpm.Campaign1__c=cmp.Id;
        cmpm.Product_1_Name__c='Test';
        cmpm.Product_1Opportunity__c=12345;
        cmpm.Product_2_Name__c='Test1';
        cmpm.Product_2_Opportunity__c=2345;
        cmpm.Product_3_Opportunity__c=2345654;
        cmpm.Product_4_Opportunity__c =23456; 
        cmpm.Lead1__c=lea.Id;
        cmpm.Member_Type__c = 'Moderator';
        insert cmpm;
        
        
        cmpm.Attended__c=true;
        update cmpm;
        
    }
    @istest
    public static void testData9() {
        
        
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
        Target__c tg=new Target__c();
        tg.Name='Test';
        tg.Date__c=System.today();
        insert tg;
        
        Campaign__c cmp=new Campaign__c();
        // cmp.City__c=accObj.City__c;
        cmp.Product_1_Name__c='Test';
        cmp.Product_2_Name__c='Test1';
        cmp.Product_3_Name__c='Test2';
        cmp.Product_4_Name__c='Test3';
        cmp.Product_1_Opportunity__c=1;
        cmp.Product_2_Opportunity__c=2;
        cmp.Product_3_Opportunity__c=3;
        cmp.Product_4_Opportunity__c=4;
        cmp.Start_Date__c=System.today();
        cmp.End_Date__c=System.today()+3;
        cmp.Target__c=tg.Id;
        cmp.Activity_Type__c = 'CONFERENCES';
         cmp.categorize__c = 'Biotech Driven Event';
        cmp.Campaign_stage__c='CTP';
        insert cmp;
        
        
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
        lea.Lead_Stage__c='Presentation';
        lea.Campaign__c=cmp.id;
        insert lea;
        
        
        Campaign_Member__c cmpm=new Campaign_Member__c();
        cmpm.Campaign1__c=cmp.Id;
        cmpm.Product_1_Name__c='Test';
        cmpm.Product_1Opportunity__c=12345;
        cmpm.Product_2_Name__c='Test1';
        cmpm.Product_2_Opportunity__c=2345;
        cmpm.Product_3_Opportunity__c=2345654;
        cmpm.Product_4_Opportunity__c =23456; 
        cmpm.Lead1__c=lea.Id;
        cmpm.Member_Type__c = 'Moderator';
        insert cmpm;
        
        
        cmpm.Attended__c=true;
        update cmpm;
        
        
    }
    @istest
    public static void testData10() {
        
        
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
        Target__c tg=new Target__c();
        tg.Name='Test';
        tg.Date__c=System.today();
        insert tg;
        
        Campaign__c cmp=new Campaign__c();
        // cmp.City__c=accObj.City__c;
        cmp.Product_1_Name__c='Test';
        cmp.Product_2_Name__c='Test1';
        cmp.Product_3_Name__c='Test2';
        cmp.Product_4_Name__c='Test3';
        cmp.Product_1_Opportunity__c=1;
        cmp.Product_2_Opportunity__c=2;
        cmp.Product_3_Opportunity__c=3;
        cmp.Product_4_Opportunity__c=4;
        cmp.Start_Date__c=System.today();
        cmp.End_Date__c=System.today()+3;
        cmp.Target__c=tg.Id;
        cmp.Activity_Type__c = 'CONFERENCES';
         cmp.categorize__c = 'Biotech Driven Event';
        cmp.Campaign_stage__c='Focus';
        insert cmp;
        
        
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
        lea.Lead_Stage__c='Presentation';
        lea.Campaign__c=cmp.id;
        insert lea;
        
        
        Campaign_Member__c cmpm=new Campaign_Member__c();
        cmpm.Campaign1__c=cmp.Id;
        cmpm.Product_1_Name__c='Test';
        cmpm.Product_1Opportunity__c=12345;
        cmpm.Product_2_Name__c='Test1';
        cmpm.Product_2_Opportunity__c=2345;
        cmpm.Product_3_Opportunity__c=2345654;
        cmpm.Product_4_Opportunity__c =23456; 
        cmpm.Lead1__c=lea.Id;
        cmpm.Member_Type__c = 'Moderator';
        insert cmpm;
        
        
        cmpm.Attended__c=true;
        update cmpm;
        
        
    }
    @istest
    public static void testData11() {
        
        
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
        Target__c tg=new Target__c();
        tg.Name='Test';
        tg.Date__c=System.today();
        insert tg;
        
        Campaign__c cmp=new Campaign__c();
        // cmp.City__c=accObj.City__c;
        cmp.Product_1_Name__c='Test';
        cmp.Product_2_Name__c='Test1';
        cmp.Product_3_Name__c='Test2';
        cmp.Product_4_Name__c='Test3';
        cmp.Product_1_Opportunity__c=1;
        cmp.Product_2_Opportunity__c=2;
        cmp.Product_3_Opportunity__c=3;
        cmp.Product_4_Opportunity__c=4;
        cmp.Start_Date__c=System.today();
        cmp.End_Date__c=System.today()+3;
        cmp.Target__c=tg.Id;
        cmp.Activity_Type__c = 'CONFERENCES';
         cmp.categorize__c = 'Biotech Driven Event';
        cmp.Campaign_stage__c='Decode';
        insert cmp;
        
        
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
        lea.Lead_Stage__c='Presentation';
        lea.Campaign__c=cmp.id;
        insert lea;
        
        
        Campaign_Member__c cmpm=new Campaign_Member__c();
        cmpm.Campaign1__c=cmp.Id;
        cmpm.Product_1_Name__c='Test';
        cmpm.Product_1Opportunity__c=12345;
        cmpm.Product_2_Name__c='Test1';
        cmpm.Product_2_Opportunity__c=2345;
        cmpm.Product_3_Opportunity__c=2345654;
        cmpm.Product_4_Opportunity__c =23456; 
        cmpm.Lead1__c=lea.Id;
        cmpm.Member_Type__c = 'Moderator';
        insert cmpm;
        
        
        cmpm.Attended__c=true;
        update cmpm;
        
        
    }
    @istest
    public static void testData12() {
        Id RecordTypeIdContact = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Columbia_Distributor').getRecordTypeId();
        
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
        accObj.BillingCity='Amritsar';
        insert accObj;
        
        CIS_Header__c cisHe=new CIS_Header__c();
        cisHe.Account__c=accObj.id;
        cisHe.Status__c='Approved';
        cisHe.IsPrimary__c=true;
        insert cisHe;
        
        Target__c tg=new Target__c();
        tg.Name='Test';
        tg.Date__c=System.today();
        insert tg;
        
         // Create the Contact
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            MobilePhone = '9074468803',
            AccountId = accObj.Id
        );
        insert con;
        
        Campaign__c cmp=new Campaign__c();
        // cmp.City__c=accObj.City__c;
        cmp.Product_1_Name__c='Test';
        cmp.Product_2_Name__c='Test1';
        cmp.Product_3_Name__c='Test2';
        cmp.Product_4_Name__c='Test3';
        cmp.Product_1_Opportunity__c=1;
        cmp.Product_2_Opportunity__c=2;
        cmp.Product_3_Opportunity__c=3;
        cmp.Product_4_Opportunity__c=4;
        cmp.Start_Date__c=System.today();
        cmp.End_Date__c=System.today()+3;
        cmp.Target__c=tg.Id;
        cmp.Activity_Type__c = 'CONFERENCES';
        cmp.categorize__c = 'Biotech Driven Event';
        cmp.Campaign_stage__c='Decode';
        cmp.City__c='Amritsar';
        //cmp.Focus_Product__c='EYECRYL TORIC;OPTIFLEX COMFORT NY;EYECRYL ACTV TORIC;';
        insert cmp;
        
        Campaign_Member__c cmpm=new Campaign_Member__c();
        cmpm.Campaign1__c=cmp.Id;
        cmpm.Product_1_Name__c='Test';
        cmpm.Product_1Opportunity__c=12345;
        cmpm.Product_2_Name__c='Test1';
        cmpm.Product_2_Opportunity__c=2345;
        cmpm.Product_3_Opportunity__c=2345654;
        cmpm.Product_4_Opportunity__c =23456; 
        cmpm.Account__c=accObj.Id;
        cmpm.Contact__c = con.Id;
        cmpm.Member_Type__c = 'Moderator';
        insert cmpm;
        
        cmpm.Attended__c=true;
        update cmpm;
        
        
    }
}
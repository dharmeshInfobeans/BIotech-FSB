@istest
public class CampaingMemberTriggerHelperTest {
    @istest
    public static void testData() {
        
        
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
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
        insert lea;
        
        Target__c tar=new Target__c();
        tar.Date__c=system.today();
        insert tar;
        
        Campaign__c cam=new Campaign__c();
        cam.Target__c=tar.id;
        cam.Name='Test';
        cam.Start_Date__c=system.today();
        cam.End_Date__c=system.today()+1;
        cam.Campaign_stage__c='CME';
        cam.Categorize__c = 'Biotech Driven Event';
        insert cam;
        
        
        Campaign_Member__c camMem=new Campaign_Member__c();
        camMem.Campaign1__c=cam.Id;
        camMem.Lead1__c=lea.id;
        //   camMem.Product__c=lea.Product__c;
        insert camMem;   
        
        
        Campaign__c cam1=new Campaign__c();
        cam1.Target__c=tar.id;
        cam1.Name='Test1';
        cam1.Start_Date__c=system.today();
        cam1.End_Date__c=system.today()+1;
        cam1.Campaign_stage__c='RTM';
        cam1.Categorize__c = 'Biotech Driven Event';
        insert cam1;
        
        
        Campaign_Member__c camMem1=new Campaign_Member__c();
        camMem1.Campaign1__c=cam1.Id;
        camMem1.Lead1__c=lea.id;
        //   camMem.Product__c=lea.Product__c;
        insert camMem1;  
        
        
        Campaign__c cam2=new Campaign__c();
        cam2.Target__c=tar.id;
        cam2.Name='Test1';
        cam2.Start_Date__c=system.today();
        cam2.End_Date__c=system.today()+1;
        cam2.Campaign_stage__c='User Meeting';
        cam2.Categorize__c = 'Biotech Driven Event';
        insert cam2;
        
        
        Campaign_Member__c camMem2=new Campaign_Member__c();
        camMem2.Campaign1__c=cam2.Id;
        camMem2.Lead1__c=lea.id;
        //   camMem.Product__c=lea.Product__c;
        insert camMem2;   
        
        
        
        Campaign__c cam3=new Campaign__c();
        cam3.Target__c=tar.id;
        cam3.Name='Test1';
        cam3.Start_Date__c=system.today();
        cam3.End_Date__c=system.today()+1;
        cam3.Campaign_stage__c='High Impact CME';
        cam3.Categorize__c = 'Biotech Driven Event';
        insert cam3;
        
        
        Campaign_Member__c camMem3=new Campaign_Member__c();
        camMem3.Campaign1__c=cam3.Id;
        camMem3.Lead1__c=lea.id;
        //   camMem.Product__c=lea.Product__c;
        insert camMem3;   
        
        
        
        
        Campaign__c cam4=new Campaign__c();
        cam4.Target__c=tar.id;
        cam4.Name='Test1';
        cam4.Start_Date__c=system.today();
        cam4.End_Date__c=system.today()+1;
        cam4.Campaign_stage__c='KOL/FOL Development';
         cam4.Categorize__c = 'Biotech Driven Event';
        insert cam4;
        
        
        Campaign_Member__c camMem4=new Campaign_Member__c();
        camMem4.Campaign1__c=cam4.Id;
        camMem4.Lead1__c=lea.id;
        //   camMem.Product__c=lea.Product__c;
        insert camMem4;   
        
        
        
        Campaign__c cam5=new Campaign__c();
        cam5.Target__c=tar.id;
        cam5.Name='Test1';
        cam5.Start_Date__c=system.today();
        cam5.End_Date__c=system.today()+1;
        cam5.Campaign_stage__c='Virtual exp. Lab';
         cam5.Categorize__c = 'Biotech Driven Event';
        insert cam5;
        
        
        Campaign_Member__c camMem5=new Campaign_Member__c();
        camMem5.Campaign1__c=cam5.Id;
        camMem5.Lead1__c=lea.id;
        //   camMem.Product__c=lea.Product__c;
        insert camMem5; 
        
        Campaign__c cam6=new Campaign__c();
        cam6.Target__c=tar.id;
        cam6.Name='Test1';
        cam6.Start_Date__c=system.today();
        cam6.End_Date__c=system.today()+1;
        cam6.Campaign_stage__c='Wet Labs';
         cam6.Categorize__c = 'Biotech Driven Event';
        insert cam6;
        
        
        Campaign_Member__c camMem6=new Campaign_Member__c();
        camMem6.Campaign1__c=cam6.Id;
        camMem6.Lead1__c=lea.id;
        //   camMem.Product__c=lea.Product__c;
        insert camMem6; 
        
        
        Campaign__c cam7=new Campaign__c();
        cam7.Target__c=tar.id;
        cam7.Name='Test1';
        cam7.Start_Date__c=system.today();
        cam7.End_Date__c=system.today()+1;
        cam7.Campaign_stage__c='Testimonial';
         cam7.Categorize__c = 'Biotech Driven Event';
        insert cam7;
        
        
        Campaign_Member__c camMem7=new Campaign_Member__c();
        camMem7.Campaign1__c=cam7.Id;
        camMem7.Lead1__c=lea.id;
        //   camMem.Product__c=lea.Product__c;
        insert camMem7; 
        
    }
}
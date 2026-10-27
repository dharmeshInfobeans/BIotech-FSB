@istest
public class AttendenceControllerTest {
    
    private static testMethod void testData() {
        List<Campaign_Member__c> camMemList=new List<Campaign_Member__c>();
        User u = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
            LastName = 'last',
            Email = 'puser000@amamama.com',
            Username = 'puser000@amamama.com' + System.currentTimeMillis(),
            CompanyName = 'TEST',
            Title = 'title',
            Alias = 'alias',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Login_Logout_Module__c = 'INDIA',
            LocaleSidKey = 'en_US');
        insert u;
        
        Account accObj = new Account();
            accObj.Name = 'Test';
            accObj.AccountNumber = '12345678';
            //accObj.region__c = robj.Id;
            accObj.BillingCity = 'Gwalior';
            accObj.BillingCountry = 'INDIA';
            accObj.BillingState = 'Madhya Pradesh';
            accobj.BillingPostalCode = '474006';
            accobj.BillingStreet = 'Baner';
            accObj.Street_2__c = 'street2';
            accObj.Street_3__c = 'street3';
            accObj.Street_4__c = 'street4';
            accObj.Street_5__c = 'street5';
            accObj.Country_Key__c='IN';
            accObj.E_Mail__c = 'gyadeen@plus91labs.com';
            accObj.Phone = '9074468803';
            accObj.City__c='Mumbai';
            accObj.City_postal_code__c='400001';
            accObj.Medical_Registration_No__c = '123';
            accObj.GSTIN_No__c = 'AF122345678912F';
            
            insert accObj;
        
         Contact objContact = new Contact();
            objContact.AccountId = accObj.Id;
            objContact.Email ='Test@test.com';
            objContact.Phone = '123456789';
            objContact.MobilePhone = '1234567890';
            objContact.LastName = 'Test';
            objContact.FirstName = 'Test';
            objContact.Salutation = 'Mr.';
            insert objContact;
           
        
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
        lea.Country__c='IN';
        lea.Billing_state__c='Mp';
        lea.Billing_country__c='india';
        lea.Email__c='pankajsinghania123@gmail.com';
        lea.Mobile__c='1234567890';
        lea.Billing_Street__c='chandranagr koteshwar';
        lea.SAP_Code__c='12343122';
        lea.Lead_Stage__c='Presentation';
        insert lea;
        
        
        
        Target__c tar=new Target__c();
        //   tar.Activity_Type__c='Other';
        tar.Date__c=system.today();
        tar.Month__c='January';
        insert tar;
        Campaign__c cam=new Campaign__c();
        cam.Target__c=tar.id;
        cam.Name='Test';
        cam.Categorize__c ='Biotech Driven Event';
        cam.Start_Date__c=system.today();
        cam.End_Date__c=system.today()+1;
        cam.Campaign_stage__c='CME';
        cam.Focus_Product__c='EYECRYL PLUS 600;BIO HYALUR LVD';
        cam.Activity_Type__c='WETLAB';
        cam.Operation__c = 'Direct';
        cam.Region__c = 'APAC';
        cam.Country__c = 'IN';
        cam.State__c = 'Gujarat';
        cam.Zone__c = 'WEST';
        insert cam;
        
        Beat_Plan__c beatplan = new Beat_Plan__c();
        beatplan.Login_Time__c = system.now();
        beatplan.Beat_Date__c = system.today();
        beatplan.OwnerId = UserInfo.getUserId();
         insert beatplan;
        
        
        Campaign_Member__c camMem=new Campaign_Member__c();
        camMem.Campaign1__c=cam.Id;
        camMem.Lead1__c=lea.id;
        //   camMem.Product__c=lea.Product__c;
        camMem.Campaign_Product__c='EYECRYL PLUS 600;BIO HYALUR LVD';
        camMem.Member_Type__c='Moderator';
      
        insert camMem;   
        
        
        Campaign__c cam1=new Campaign__c();
        cam1.Target__c=tar.id;
        cam1.Name='Test1';
        cam1.Categorize__c ='Biotech Driven Event';
        cam1.Start_Date__c=system.today();
        cam1.End_Date__c=system.today()+1;
        cam1.Campaign_stage__c='RTM';
        cam1.Focus_Product__c='EYECRYL PLUS 600';
        cam1.Activity_Type__c='WETLAB';
        cam1.Operation__c = 'Direct';
        cam1.Region__c = 'APAC';
        cam1.Country__c = 'IN';
        cam1.State__c = 'Gujarat';
         cam1.Zone__c = 'WEST';
        
        
        insert cam1;
        
        
        Campaign_Member__c camMem1=new Campaign_Member__c();
        camMem1.Campaign1__c=cam1.Id;
        camMem1.Lead1__c=lea.id;
        //   camMem.Product__c=lea.Product__c;
        camMem1.Member_Type__c='Moderator';
        camMem1.Account__c = accObj.Id;
        camMem1.Contact__c =objContact.Id;
        insert camMem1;  
        
        
        Campaign__c cam2=new Campaign__c();
        cam2.Target__c=tar.id;
        cam2.Name='Test1';
        cam2.Start_Date__c=system.today();
        cam2.End_Date__c=system.today()+1;
        cam2.Campaign_stage__c='User Meeting';
        cam2.Activity_Type__c='WETLAB';
        cam2.Categorize__c ='Biotech Driven Event';
        cam2.Operation__c = 'Direct';
        cam2.Region__c = 'APAC';
        cam2.Country__c = 'IN';
        cam2.State__c = 'Gujarat';
         cam2.Zone__c = 'WEST';
        insert cam2;
        
        
     /*   Campaign_Member__c camMem2=new Campaign_Member__c();
        camMem2.Campaign1__c=cam2.Id;
        camMem2.Lead1__c=lea.id;
        //   camMem.Product__c=lea.Product__c;
        camMem2.Member_Type__c='Moderator';
        insert camMem2;   
        
        
        
        Campaign__c cam3=new Campaign__c();
        cam3.Target__c=tar.id;
        cam3.Name='Test1';
        cam3.Start_Date__c=system.today();
        cam3.End_Date__c=system.today()+1;
        cam3.Campaign_stage__c='High Impact CME';
        cam3.Activity_Type__c='WETLAB';
        insert cam3;
        
        
        Campaign_Member__c camMem3=new Campaign_Member__c();
        camMem3.Campaign1__c=cam3.Id;
        camMem3.Lead1__c=lea.id;
        //   camMem.Product__c=lea.Product__c;
        camMem3.Member_Type__c='Moderator';
        insert camMem3;   
        
        
        
        
        Campaign__c cam4=new Campaign__c();
        cam4.Target__c=tar.id;
        cam4.Name='Test1';
        cam4.Start_Date__c=system.today();
        cam4.End_Date__c=system.today()+1;
        cam4.Campaign_stage__c='KOL/FOL Development';
        cam4.Activity_Type__c='WETLAB';
        insert cam4;
        
        
        Campaign_Member__c camMem4=new Campaign_Member__c();
        camMem4.Campaign1__c=cam4.Id;
        camMem4.Lead1__c=lea.id;
        //   camMem.Product__c=lea.Product__c;
        camMem4.Member_Type__c='Moderator';
        insert camMem4;   
        
        
        
        Campaign__c cam5=new Campaign__c();
        cam5.Target__c=tar.id;
        cam5.Name='Test1';
        cam5.Start_Date__c=system.today();
        cam5.End_Date__c=system.today()+1;
        cam5.Campaign_stage__c='Virtual exp. Lab';
        cam5.Activity_Type__c='WETLAB';
        insert cam5;
        
        
        Campaign_Member__c camMem5=new Campaign_Member__c();
        camMem5.Campaign1__c=cam5.Id;
        camMem5.Lead1__c=lea.id;
        //   camMem.Product__c=lea.Product__c;
        camMem5.Member_Type__c='Moderator';
        insert camMem5; 
        
        Campaign__c cam6=new Campaign__c();
        cam6.Target__c=tar.id;
        cam6.Name='Test1';
        cam6.Start_Date__c=system.today();
        cam6.End_Date__c=system.today()+1;
        cam6.Campaign_stage__c='Wet Labs';
        cam6.Activity_Type__c='WETLAB';
        insert cam6;
        
        
        Campaign_Member__c camMem6=new Campaign_Member__c();
        camMem6.Campaign1__c=cam6.Id;
        camMem6.Lead1__c=lea.id;
        //   camMem.Product__c=lea.Product__c;
        camMem6.Member_Type__c='Moderator';
        insert camMem6; 
        
        

        
        
        
        camMemList.add(camMem);
        camMemList.add(camMem2);
        camMemList.add(camMem3);
        camMemList.add(camMem4);
        camMemList.add(camMem5);
        camMemList.add(camMem6);*/
        Campaign__c cam7=new Campaign__c();
        cam7.Target__c=tar.id;
        cam7.Name='Test1';
        cam7.Start_Date__c=system.today();
        cam7.End_Date__c=system.today()+1;
        cam7.Campaign_stage__c='Testimonial';
        cam7.Activity_Type__c='WETLAB';
        cam7.Categorize__c ='Biotech Driven Event';
        cam7.Operation__c = 'Direct';
        cam7.Region__c = 'APAC';
        cam7.Country__c = 'IN';
        cam7.State__c = 'Gujarat';
        cam7.Zone__c = 'WEST';
        insert cam7;
        Campaign_Member__c camMem7=new Campaign_Member__c();
        camMem7.Campaign1__c=cam7.Id;
        camMem7.Lead1__c=lea.id;
        //   camMem.Product__c=lea.Product__c;
        camMem7.Member_Type__c='Moderator';
        camMem7.Account__c = accObj.Id;
        camMem7.Contact__c = objContact.Id;
        insert camMem7; 
        
        List<Map<String,Object>> campDataList=new List<Map<String,Object>>();
        List<Object> proList=new List<Object>();
        Map<String,Object> camMap=new Map<String,Object>();
        proList.add('BIO BLADE');
        proList.add('EYECRYL PLUS 600');
        camMap.put('Product',proList);
        camMap.put('Id',camMem7.Id);
        camMap.put('Company','Plus9labs');
        camMap.put('FirstName','Pankaj');
        camMap.put('LastName','Sen');
        camMap.put('Email','pankaj@plus91labs.com');
        camMap.put('City','Delhi');
        camMap.put('country','India');
        camMap.put('CampaingStage','CME');
        camMap.put('State','CME');        
        camMap.put('Mobile','1234567890');
        camMap.put('Checked',true);
        camMap.put('Account',accObj.Id);
        campDataList.add(camMap);
        List<Map<String,Object>> campDataList1=new List<Map<String,Object>>();
        List<Object> proList1=new List<Object>();
        Map<String,Object> camMap1=new Map<String,Object>();
        proList1.add('BIO BLADE');
        proList1.add('EYECRYL PLUS 600');
        camMap1.put('Product',proList1);
        camMap1.put('Id',camMem7.Id);
        camMap1.put('Company','Plus9labs');
        camMap1.put('FirstName','Pankaj');
        camMap1.put('LastName','Sen');
        camMap1.put('Email','pankaj@plus91labs.com');
        camMap1.put('City','Delhi');
        camMap1.put('country','India');
        camMap1.put('CampaingStage','RTM');
        camMap1.put('State','CME');        
        camMap1.put('Mobile','1234567790');
        camMap1.put('Checked',true);
        camMap1.put('Account',accObj.Id);
        
        campDataList1.add(camMap1);
        List<Map<String,Object>> campDataList2=new List<Map<String,Object>>();
        List<Object> proList2=new List<Object>();
        Map<String,Object> camMap2=new Map<String,Object>();
        proList2.add('BIO BLADE');
        proList2.add('EYECRYL PLUS 600');
        camMap2.put('Product',proList2);
        camMap2.put('Id',camMem7.Id);
        camMap2.put('Company','Plus9labs');
        camMap2.put('FirstName','Pankaj');
        camMap2.put('LastName','Sen');
        camMap2.put('Email','pankaj@plus91labs.com');
        camMap2.put('City','Delhi');
        camMap1.put('country','India');
        camMap2.put('CampaingStage','User Meeting');
        camMap2.put('State','CME');        
        camMap2.put('Mobile','1234467790');
        camMap2.put('Checked',true);
        camMap2.put('Account',accObj.Id);
        
        campDataList2.add(camMap2);
        List<Map<String,Object>> campDataList3=new List<Map<String,Object>>();
        List<Object> proList3=new List<Object>();
        Map<String,Object> camMap3=new Map<String,Object>();
        proList3.add('BIO BLADE');
        proList3.add('EYECRYL PLUS 600');
        camMap3.put('Product',proList3);
        camMap3.put('Id',camMem7.Id);
        camMap3.put('Company','Plus9labs');
        camMap3.put('FirstName','Pankaj');
        camMap3.put('LastName','Sen');
        camMap3.put('Email','pankaj@plus91labs.com');
        camMap3.put('City','Delhi');
        camMap3.put('country','India');
        camMap3.put('CampaingStage','High Impact CME');
        camMap3.put('State','CME');        
        camMap3.put('Mobile','1230967790');
        camMap3.put('Checked',true);
        camMap3.put('Account',accObj.Id);
        
        campDataList3.add(camMap3);
        
        List<Map<String,Object>> campDataList4=new List<Map<String,Object>>();
        List<Object> proList4=new List<Object>();
        Map<String,Object> camMap4=new Map<String,Object>();
        proList4.add('BIO BLADE');
        proList4.add('EYECRYL PLUS 600');
        camMap4.put('Product',proList4);
        camMap4.put('Id',camMem7.Id);
        camMap4.put('Company','Plus9labs');
        camMap4.put('FirstName','Pankaj');
        camMap4.put('LastName','Sen');
        camMap4.put('Email','pankaj@plus91labs.com');
        camMap4.put('City','Delhi');
        camMap4.put('country','India');
        camMap4.put('CampaingStage','KOL/FOL Development');
        camMap4.put('State','CME');        
        camMap4.put('Mobile','1004467790');
        camMap4.put('Checked',true);
        camMap4.put('Account',accObj.Id);
        
        campDataList4.add(camMap4);
        List<Map<String,Object>> campDataList5=new List<Map<String,Object>>();
        List<Object> proList5=new List<Object>();
        Map<String,Object> camMap5=new Map<String,Object>();
        proList5.add('BIO BLADE');
        proList5.add('EYECRYL PLUS 600');
        camMap5.put('Product',proList5);
        camMap5.put('Id',camMem7.Id);
        camMap5.put('Company','Plus9labs');
        camMap5.put('FirstName','Pankaj');
        camMap5.put('LastName','Sen');
        camMap5.put('Email','pankaj@plus91labs.com');
        camMap5.put('City','Delhi');
        camMap5.put('country','India');
        camMap5.put('CampaingStage','Wet Labs');
        camMap5.put('State','CME');        
        camMap5.put('Mobile','0034467790');
        camMap5.put('Checked',true);
        camMap5.put('Account',accObj.Id);
        
        campDataList5.add(camMap5);
        List<Map<String,Object>> campDataList6=new List<Map<String,Object>>();
        List<Object> proList6=new List<Object>();
        Map<String,Object> camMap6=new Map<String,Object>();
        proList6.add('BIO BLADE');
        proList6.add('EYECRYL PLUS 600');
        camMap6.put('Product',proList6);
        camMap6.put('Id',camMem7.Id);
        camMap6.put('Company','Plus9labs');
        camMap6.put('FirstName','Pankaj');
        camMap6.put('LastName','Sen');
        camMap6.put('Email','pankaj@plus91labs.com');
        camMap6.put('City','Delhi');
        camMap6.put('country','India');
        camMap6.put('CampaingStage','Virtual exp. Lab');
        camMap6.put('State','CME');        
        camMap6.put('Mobile','1004467790');
        camMap6.put('Checked',true);
        camMap6.put('Account',accObj.Id);
        
        campDataList6.add(camMap6);
        List<Map<String,Object>> campDataList7=new List<Map<String,Object>>();
        List<Object> proList7=new List<Object>();
        Map<String,Object> camMap7=new Map<String,Object>();
        proList7.add('BIO BLADE');
        proList7.add('EYECRYL PLUS 600');
        camMap7.put('Product',proList7);
        camMap7.put('Id',camMem7.Id);
        camMap7.put('Company','Plus9labs');
        camMap7.put('FirstName','Pankaj');
        camMap7.put('LastName','Sen');
        camMap7.put('Email','pankaj@plus91labs.com');
        camMap7.put('City','Delhi');
        camMap7.put('country','India');
        camMap7.put('CampaingStage','Testimonial');
        camMap7.put('State','CME');        
        camMap7.put('Mobile','9834467790');
        camMap7.put('Checked',true);
        
        campDataList6.add(camMap7);
        List<Map<String,Object>> campDataList8=new List<Map<String,Object>>();
        List<Object> proList8=new List<Object>();
        Map<String,Object> camMap8=new Map<String,Object>();
        proList8.add('BIO BLADE');
        proList8.add('EYECRYL PLUS 600');
        camMap8.put('Product',proList8);
        camMap8.put('Id',camMem7.Id);
        camMap8.put('Company','Plus9labs');
        camMap8.put('FirstName','Pankaj');
        camMap8.put('LastName','Sen');
        camMap8.put('Email','pankaj@plus91labs.com');
        camMap8.put('City','Delhi');
        camMap8.put('country','India');
        camMap8.put('CampaingStage','CTP');
        camMap8.put('State','CME');        
        camMap8.put('Mobile','4534467790');
        camMap8.put('Checked',true);
        
        campDataList8.add(camMap8);
        List<Map<String,Object>> campDataList9=new List<Map<String,Object>>();
        List<Object> proList9=new List<Object>();
        Map<String,Object> camMap9=new Map<String,Object>();
        proList9.add('BIO BLADE');
        proList9.add('EYECRYL PLUS 600');
        camMap9.put('Product',proList9);
        camMap9.put('Id',camMem7.Id);
        camMap9.put('Company','Plus9labs');
        camMap9.put('FirstName','Pankaj');
        camMap9.put('LastName','Sen');
        camMap9.put('Email','pankaj@plus91labs.com');
        camMap9.put('City','Delhi');
        camMap9.put('country','India');
        camMap9.put('CampaingStage','Focus');
        camMap9.put('State','CME');        
        camMap9.put('Mobile','1290967790');
        camMap9.put('Checked',true);
        
        campDataList9.add(camMap9);
        List<Map<String,Object>> campDataList10=new List<Map<String,Object>>();
        List<Object> proList10=new List<Object>();
        Map<String,Object> camMap10=new Map<String,Object>();
        proList10.add('BIO BLADE');
        proList10.add('EYECRYL PLUS 600');
        camMap10.put('Product',proList6);
        camMap10.put('Id',camMem7.Id);
        camMap10.put('Company','Plus9labs');
        camMap10.put('FirstName','Pankaj');
        camMap10.put('LastName','Sen');
        camMap10.put('Email','pankaj@plus91labs.com');
        camMap10.put('City','Delhi');
        camMap10.put('country','India');
        camMap10.put('CampaingStage','Decode');
        camMap10.put('State','CME');        
        camMap10.put('Mobile','1290967790');
        camMap10.put('Checked',true);
        
        campDataList10.add(camMap10);
        
         
        
        List<Map<String,Object>> campDataList11=new List<Map<String,Object>>();
        List<Object> proList11=new List<Object>();
        Map<String,Object> camMap11=new Map<String,Object>();
        proList11.add('BIO BLADE');
        proList11.add('EYECRYL PLUS 600');
        camMap11.put('Product',proList11);
        camMap11.put('Id',camMem7.Id);
        camMap11.put('Company','Plus9labs');
        camMap11.put('FirstName','Pankaj');
        camMap11.put('LastName','Sen');
        camMap11.put('Email','pankaj@plus91labs.com');
        camMap11.put('City','Delhi');
        camMap11.put('country','India');
        camMap11.put('CampaingStage','Inclinic Branding');
        camMap11.put('State','CME');        
        camMap11.put('Mobile','2344467790');
        camMap11.put('Checked',true);
        camMap11.put('Account',accObj.Id);
        
        campDataList11.add(camMap11);
        AttendanceController.getAttendees(cam.id);
        AttendanceController.getAttendees(cam1.id);
        AttendanceController.markAttendance(campDataList,cam.Id);
        AttendanceController.markAttendance(campDataList1,cam.Id);
        AttendanceController.markAttendance(campDataList2,cam.Id);
        AttendanceController.markAttendance(campDataList3,cam.Id);
        AttendanceController.markAttendance(campDataList4,cam.Id);
        AttendanceController.markAttendance(campDataList5,cam.Id);
        AttendanceController.markAttendance(campDataList6,cam.Id);
        AttendanceController.markAttendance(campDataList7,cam.Id);
        AttendanceController.markAttendance(campDataList8,cam.Id);
        AttendanceController.markAttendance(campDataList9,cam.Id);
        AttendanceController.getCityData(cam.id);
        AttendanceController.updateCampaign(cam);
        //AttendanceController.markAttendance(campDataList10,cam.Id);
        //  AttendanceController.markAttendance(campDataList11,cam.Id);
        
        
    }
}
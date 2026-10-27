@isTest
public class LeadFormPageControllerTest {

    public static testmethod void test(){

      
        User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        Leads__c led = new Leads__c();
        led.IsActive__c = true;
        led.Name = 'LeadTrigger';
        insert led; 
        
        Lead__c lea = new Lead__c();
        lea.Name = 'test';
        lea.First_Name__c = 'test';
        lea.Last_Name__c = 'singh';
        lea.Company__c = 'Plus91labs';
        lea.Product__c = 'EYECRYL PLUS CLEAR';
        lea.Billing_City__c = 'Gwalior';
        lea.Billing_code__c = '474001';
        lea.Country__c = 'India'; // ✅ FIX (case sensitive match)
        lea.Billing_state__c = 'MP';
        lea.Billing_country__c = 'India';
        lea.Email__c = 'test@test.com';
        lea.Mobile__c = '1234567890';
        lea.Billing_Street__c = 'chandranagr';
        lea.SAP_Code__c = '12343122';
        lea.Lead_Stage__c = 'Appointments';
        lea.Lead_Closed__c = false;
        insert lea;
        
        Target__c tar = new Target__c();
        tar.Date__c = System.today();
        insert tar;
        
        Campaign__c cam = new Campaign__c();
        cam.Target__c = tar.Id;
        cam.Name = 'Test';
        cam.categorize__c = 'Biotech Driven Event';
        cam.Activity_Type__c = 'CONFERENCES';
        cam.Start_Date__c = System.today();
        cam.End_Date__c = System.today() + 1;
        cam.Focus_Product__c = 'EYECRYL PLUS CLEAR;OPTIFLEX GENESIS';
        cam.Executer__c = u.Id; 
        cam.Country__c = 'INDIA';
        cam.Operation__c = 'Direct';
        cam.Region__c = 'APAC';
        cam.State__c = 'Madhya Pradesh';
        cam.Zone__c = 'North';
        insert cam;

        Beat_Plan__c bp = new Beat_Plan__c(
            Beat_Date__c = System.today(),
            Login_Time__c = System.now(),
            OwnerId = u.Id
        );
        insert bp;

        insert new Country__c(
            Country__c = 'India',
            State__c = 'MP',
            CITY__c = 'Bhopal'
        );

        Test.startTest();

        String res1 = LeadFormPageController.insertLeadData(
            'member 1',
            '1234567890',
            'MP',
            'pankaj',
            'sen',
            'test@test.com',
            'plus91labs',
            'Bhopal',
            'India',
            'street',
            '474001',
            cam.Id,
            new List<String>{'EYECRYL TORIC'},
            lea.Id
        );

       String res2 = LeadFormPageController.insertLeadData(
            'member 1',
            '1234567899',
            'MP',
            'pankaj',
            'sen',
            'test2@test.com',
            'plus91labs',
            'Bhopal',
            'India',
            'street',
            '474001',
            cam.Id,
            new List<String>{'EYECRYL TORIC'},
            lea.Id
        );

        Test.stopTest();

        PageReference pgRef = Page.LeadFormPage;
        Test.setCurrentPage(pgRef);
        ApexPages.currentPage().getParameters().put('id', cam.Id);

        LeadFormPageController leadForm = new LeadFormPageController();
        System.assertNotEquals(null, leadForm);

        LeadFormPageController.leaddata('', cam.Id);
        LeadFormPageController.getCountries();
        LeadFormPageController.getStates('India');
        LeadFormPageController.getCities('MP');
        LeadFormPageController.getLeadDetails(lea.Id);
    }
}
@isTest
public class EventApprovalControllerTest {

    @testSetup
    static void setupData() {

        // ---------- Create Org Wide Email ----------
        OrgWideEmailAddress owe = [
            SELECT Id FROM OrgWideEmailAddress
            WHERE Address = 'crmhelpdesk@biotechhealthcare.com'
            LIMIT 1
        ];


        // ---------- Custom Settings ----------
        customer_creation_url__c cs1 = new customer_creation_url__c();
        cs1.Name = 'Customer Creation urls';
        cs1.Thank_you_url__c = 'https://thankyou.test';
        insert cs1;

        In_Clining_Branding_site_url__c cs2 = new In_Clining_Branding_site_url__c();
        cs2.Name = 'In Clining Branding';
        cs2.Page_Url__c = 'https://approve.test?id=';
        cs2.reporty_user_page__c = 'https://resubmit.test?id=';
        insert cs2;

        // ---------- Create Manager ----------
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];

        User manager = new User(
            FirstName = 'Manager',
            LastName = 'User',
            Email = 'manager@test.com',
            Username = 'manager' + System.currentTimeMillis() + '@test.com',
            Alias = 'mgr',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert manager;

        // ---------- Create Owner ----------
        User owner = new User(
            FirstName = 'Owner',
            LastName = 'User',
            Email = 'owner@test.com',
            Username = 'owner' + System.currentTimeMillis() + '@test.com',
            Alias = 'own',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            Reporting_manager_for_Inclining_branding__c = manager.Id
        );
        insert owner;

        // ---------- Create Account ----------
        Account acc = new Account(
            Name = 'Test Account',
            SAP_Code__c = 'SAP001',
            CE_CIS_Rating__c = 'A',
            Phakic_Rating__c = 'B',
            BillingCountry = 'India',
            BillingState = 'MP',
            BillingCity = 'Bhopal',
            BillingStreet = 'Street 1'
        );
        insert acc;

        // ---------- Create Event ----------
        Event ev = new Event(
            Subject = 'Test Event',
            OwnerId = owner.Id,
            ActivityDate = Date.today(),
            StartDateTime = System.now().addHours(1),
            EndDateTime   = System.now().addHours(2),
            
            DurationInMinutes = 60,
  
            Account__c = acc.Id,
            meeting_type__c = 'Onsite',
            Approval_Status__c = 'Installation WIP',
            Call_Type__c = 'IN clinic Branding',
            Sub_Call_Type__c = 'Standee'
        );
        insert ev;

    }

    // ---------------------------------------------
    // Constructor Test
    // ---------------------------------------------
    @isTest
    static void testConstructor() {

        Event ev = [SELECT Id FROM Event LIMIT 1];

        PageReference pageRef = new PageReference('/apex/EventApprovalVFpage');
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', ev.Id);

        Test.startTest();
        EventApprovalController ctrl = new EventApprovalController();
        Test.stopTest();

    }

    // ---------------------------------------------
    // Approve Test
    // ---------------------------------------------
    @isTest
    static void testApproveMethod() {

        Event ev = [SELECT Id FROM Event LIMIT 1];

        Test.startTest();
        Map<String,Object> res =
            EventApprovalController.ManagerApprovalMethod(
                'Approve','Approved OK',ev.Id,'Manager'
            );
        Test.stopTest();

       
    }

    // ---------------------------------------------
    // Reject Test
    // ---------------------------------------------
    @isTest
    static void testRejectMethod() {

        Event ev = [SELECT Id FROM Event LIMIT 1];

        Test.startTest();
        Map<String,Object> res =
            EventApprovalController.ManagerApprovalMethod(
                'Reject','Rejected reason',ev.Id,'Manager'
            );
        Test.stopTest();


    }

    // ---------------------------------------------
    // Already Approved scenario
    // ---------------------------------------------
    @isTest
    static void testAlreadyApproved() {

        Event ev = [SELECT Id FROM Event LIMIT 1];
        ev.Approval_Status__c = 'Approved';
        update ev;

        Test.startTest();
        Map<String,Object> res =
            EventApprovalController.ManagerApprovalMethod(
                'Approve','Again',ev.Id,'Manager'
            );
        Test.stopTest();

    }

    // ---------------------------------------------
    // sendApprovalEmail coverage
    // ---------------------------------------------
    @isTest
    static void testSendApprovalEmail() {

        Event ev = [SELECT Id, OwnerId FROM Event LIMIT 1];

        Test.startTest();
        EventApprovalController.sendApprovalEmail(ev);
        Test.stopTest();

    }

    // ---------------------------------------------
    // generateEmailBody coverage
    // ---------------------------------------------
    @isTest
    static void testGenerateEmailBody() {

        Event ev = [SELECT Id, Owner.FirstName, Owner.LastName FROM Event LIMIT 1];
        User u = [SELECT Id, Reporting_manager_for_Inclining_branding__r.FirstName,
                  Reporting_manager_for_Inclining_branding__r.LastName
                  FROM User WHERE Id=:ev.OwnerId LIMIT 1];

      
    }

}
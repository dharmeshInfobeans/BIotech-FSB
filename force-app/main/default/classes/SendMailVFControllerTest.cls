@isTest
public class SendMailVFControllerTest {

    @testSetup
    static void setupData() {

        // ---- custom setting ----
        customer_creation_url__c cs = new customer_creation_url__c();
        cs.Name = 'Customer Creation urls';
        cs.Thank_you_url__c = 'https://thankyou.test';
        insert cs;
        
        
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;

        // ---- Account ----
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

        // ---- Lead ----
        Lead__c lea = new Lead__c(
            Name='Test Lead',
            First_Name__c='test',
            Last_Name__c='singh',
            Company__c='Plus91labs',
            Product__c='BIO HYALUR CS',
            Billing_City__c='Gwalior',
            Billing_state__c='Mp',
            Billing_country__c='india',
            Email__c='test@test.com',
            Mobile__c='9999999999',
            Billing_Street__c='street',
            SAP_Code__c='SAPLEAD',
            Lead_Stage__c='Presentation',
            CE_CIS_Rating__c = 'Pp',
            Phakic_Rating__c = 'Aa',
            Account__c = acc.Id,
            Country__c = 'INDIA'
        );
        insert lea;

        // ---- User ----
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];

        User u = new User(
            FirstName='Test',
            LastName='User',
            Email='testuser@test.com',
            Username='testuser'+System.currentTimeMillis()+'@test.com',
            Alias='tusr',
            TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US',
            EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US',
            ProfileId=p.Id
        );
        insert u;

        // ---- Event with LEAD ----
        Event evLead = new Event(
            Subject='Lead Event',
            OwnerId=u.Id,
            Leads__c = lea.Id,
            Account__c = acc.Id,
            StartDateTime = System.now().addHours(1),
            EndDateTime   = System.now().addHours(2),
            DurationInMinutes = 60,
            Approval_Status__c = 'Rejected',
            Call_Type__c = 'IN clinic Branding',
            Sub_Call_Type__c = 'Standee'
        );
        insert evLead;

        // ---- Event with ACCOUNT only ----
        Event evAcc = new Event(
            Subject='Account Event',
            OwnerId=u.Id,
            Account__c = acc.Id,
            StartDateTime = System.now().addHours(3),
            EndDateTime   = System.now().addHours(4),
            DurationInMinutes = 60,
            Approval_Status__c = 'Rejected',
            Call_Type__c = 'IN clinic Branding',
            Sub_Call_Type__c = 'Standee'
        );
        insert evAcc;
    }

    // =====================================================
    // LEAD BASED EVENT TEST
    // =====================================================
    @isTest
    static void testLeadEventFlow() {

        Event ev = [SELECT Id FROM Event WHERE Subject='Lead Event' LIMIT 1];

        Test.setCurrentPage(new PageReference('/apex/test'));
        ApexPages.currentPage().getParameters().put('id', ev.Id);

        Test.startTest();
        SendMailVFController ctrl = new SendMailVFController();
        ctrl.assignDynamicLeadAccountFields();
        Test.stopTest();

        System.assertEquals(ev.Id, ctrl.recordId);
        System.assertNotEquals(null, ctrl.sapCode);
        System.assertNotEquals(null, ctrl.recordname);
    }

    // =====================================================
    // ACCOUNT BASED EVENT TEST
    // =====================================================
    @isTest
    static void testAccountEventFlow() {

        Event ev = [SELECT Id FROM Event WHERE Subject='Account Event' LIMIT 1];

        Test.setCurrentPage(new PageReference('/apex/test'));
        ApexPages.currentPage().getParameters().put('id', ev.Id);

        Test.startTest();
        SendMailVFController ctrl = new SendMailVFController();
        ctrl.assignDynamicLeadAccountFields();
        Test.stopTest();

        System.assertEquals(ev.Id, ctrl.recordId);
        System.assertNotEquals(null, ctrl.sapCode);
        System.assertNotEquals(null, ctrl.recordname);
    }

    // =====================================================
    // RESUBMIT SUCCESS
    // =====================================================
    @isTest
    static void testProcessResubmitSuccess() {

        Event ev = [SELECT Id FROM Event WHERE Subject='Lead Event' LIMIT 1];

        String base64Data = EncodingUtil.base64Encode(
            Blob.valueOf('Test File Body')
        );

        Test.startTest();
        Map<String,Object> res =
            SendMailVFController.processReSubmit(
                'Resubmitting again',
                ev.Id,
                'testfile.txt',
                base64Data
            );
        Test.stopTest();

        System.assertEquals('success', res.get('status'));
    }

    // =====================================================
    // COMMENT MANDATORY
    // =====================================================
    @isTest
    static void testCommentMandatory() {

        Event ev = [SELECT Id FROM Event LIMIT 1];

        Test.startTest();
        Map<String,Object> res =
            SendMailVFController.processReSubmit(
                '',
                ev.Id,
                'file.txt',
                'abc'
            );
        Test.stopTest();

        System.assertEquals('error', res.get('status'));
    }

    // =====================================================
    // ALREADY PENDING
    // =====================================================
    @isTest
    static void testAlreadyPending() {

        Event ev = [SELECT Id FROM Event LIMIT 1];
        ev.Approval_Status__c = 'Pending for Approval';
        update ev;

        Test.startTest();
        Map<String,Object> res =
            SendMailVFController.processReSubmit(
                'Again',
                ev.Id,
                'file.txt',
                EncodingUtil.base64Encode(Blob.valueOf('abc'))
            );
        Test.stopTest();

        System.assertEquals('error', res.get('status'));
    }
}
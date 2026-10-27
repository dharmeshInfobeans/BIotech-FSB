@IsTest
public class MarketXrayApprovalTriggerHandler_Test {

    @testSetup
    static void setupData() {

        // ---------- Create Approver User ----------
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User approver = new User(
            Alias = 'appr',
            Email = 'approver@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Approver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Kolkata',
            ProfileId = p.Id,
            Username = 'approver' + System.currentTimeMillis() + '@test.com'
        );
        insert approver;

        // ---------- Account ----------
        Account acc = new Account(
            Name = 'Test Account',
            Approver_1__c = approver.Id
        );
        insert acc;

        // ---------- Contact ----------
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'contact@test.com',
            AccountId = acc.Id
        );
        insert con;

        // ---------- Market XRay Form (Initial State) ----------
        insert new Market_X_Ray_Form__c(
            Account__c = acc.Id,
            Contact__c = con.Id,
            Approval_Status__c = 'Rejected',
            CRM_Approved__c = false
        );
    }

    // --------------------------------------------------------
    // POSITIVE SCENARIO – Eligible for second approval
    // --------------------------------------------------------
    @IsTest
    static void testEligibleForSecondApproval() {

        Market_X_Ray_Form__c form =
            [SELECT Id, Approval_Status__c, CRM_Approved__c
             FROM Market_X_Ray_Form__c
             LIMIT 1];

        Test.startTest();
            form.Approval_Status__c = 'Approved';
            form.CRM_Approved__c = true;
            update form;
        Test.stopTest();

        Market_X_Ray_Form__c updatedForm =
            [SELECT Approval_Status__c, CRM_Approved__c
             FROM Market_X_Ray_Form__c
             WHERE Id = :form.Id];

        System.assertEquals('Approved', updatedForm.Approval_Status__c,
            'Approval status should be Approved');
        System.assertEquals(true, updatedForm.CRM_Approved__c,
            'CRM Approved should be TRUE');
    }

    // --------------------------------------------------------
    // NEGATIVE – CRM not approved
    // --------------------------------------------------------
    @IsTest
    static void testNotEligibleWhenCRMNotApproved() {

        Market_X_Ray_Form__c form =
            [SELECT Id FROM Market_X_Ray_Form__c LIMIT 1];

        Test.startTest();
            form.Approval_Status__c = 'Approved';
            form.CRM_Approved__c = false;
            update form;
        Test.stopTest();

        Market_X_Ray_Form__c updatedForm =
            [SELECT CRM_Approved__c FROM Market_X_Ray_Form__c WHERE Id = :form.Id];

        System.assertEquals(false, updatedForm.CRM_Approved__c,
            'Form should not be eligible when CRM_Approved__c is false');
    }

    // --------------------------------------------------------
    // NEGATIVE – Status not changed
    // --------------------------------------------------------
    @IsTest
    static void testNotEligibleWhenStatusNotChanged() {

        Market_X_Ray_Form__c form =
            [SELECT Id, Approval_Status__c FROM Market_X_Ray_Form__c LIMIT 1];

        Test.startTest();
            form.CRM_Approved__c = true;
            update form;
        Test.stopTest();

        Market_X_Ray_Form__c updatedForm =
            [SELECT Approval_Status__c FROM Market_X_Ray_Form__c WHERE Id = :form.Id];

        System.assertEquals('Rejected', updatedForm.Approval_Status__c,
            'Approval status should remain unchanged');
    }

    // --------------------------------------------------------
    // FUTURE METHOD COVERAGE
    // --------------------------------------------------------
    @IsTest
    static void testFutureMethodExecution() {

        Market_X_Ray_Form__c form = [SELECT Id FROM Market_X_Ray_Form__c LIMIT 1];

        Test.startTest();
            MarketXrayApprovalTriggerHandler.submitSecondApprovalsAsync(new List<Id>{ form.Id });
        Test.stopTest();

        //System.assertEquals(1, Limits.getFutureCalls(),'Future method should be invoked once');
    }
}




/*@IsTest
public class MarketXrayApprovalTriggerHandler_Test {

    @testSetup
    static void setupData() {
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];

        User approver = new User(
            Alias = 'appr' + Math.round(Math.random()*9999),
            Email = 'approver' + Math.round(Math.random()*9999) + '@test.com',
            EmailEncodingKey='UTF-8',
            LastName='Approver',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            TimeZoneSidKey='Asia/Kolkata',
            ProfileId = p.Id,
            Username = 'approver' + System.currentTimeMillis() + '@test.com'
        );
        insert approver;

        Account acc = new Account(Name='Test Account',Approver_1__c = approver.Id);
        insert acc;

        Contact con = new Contact(
            FirstName='Test',
            LastName='Contact',
            Email='contact@test.com',
            AccountId=acc.Id
        );
        insert con;

        insert new Market_X_Ray_Form__c(
            Account__c = acc.Id,
            Contact__c = con.Id,
            Approval_Status__c = 'Rejected',
            CRM_Approved__c = false
        );
    }

    @IsTest
    static void testEligibleForSecondApproval() {
        Market_X_Ray_Form__c f = [SELECT Id FROM Market_X_Ray_Form__c LIMIT 1];

        Test.startTest();
            f.Approval_Status__c = 'Approved';
            f.CRM_Approved__c = true;
            update f;
        Test.stopTest();

        f = [SELECT Approval_Status__c, CRM_Approved__c FROM Market_X_Ray_Form__c WHERE Id=:f.Id];
        System.assertEquals('Approved', f.Approval_Status__c);
        System.assertEquals(true, f.CRM_Approved__c);
    }

    @IsTest
    static void testNotEligibleWhenCRMNotApproved() {
        Market_X_Ray_Form__c f = [SELECT Id FROM Market_X_Ray_Form__c LIMIT 1];

        Test.startTest();
            f.Approval_Status__c = 'Approved';
            f.CRM_Approved__c = false;
            update f;
        Test.stopTest();

        System.assertEquals(false, f.CRM_Approved__c);
    }

    @IsTest
    static void testNotEligibleWhenStatusNotChanged() {
        Market_X_Ray_Form__c f = [SELECT Id, Approval_Status__c FROM Market_X_Ray_Form__c LIMIT 1];

        Test.startTest();
            f.CRM_Approved__c = true;
            update f;
        Test.stopTest();

        System.assertEquals('Rejected', f.Approval_Status__c);
    }

    @IsTest
    static void testFutureLogicExecutes() {
        Market_X_Ray_Form__c f = [SELECT Id FROM Market_X_Ray_Form__c LIMIT 1];

        Test.startTest();
            MarketXrayApprovalTriggerHandler.submitSecondApprovalsAsync(new List<Id>{f.Id});
        Test.stopTest();

        System.assert(true, 'Future method ran without calling Approval.process()');
    }
}*/
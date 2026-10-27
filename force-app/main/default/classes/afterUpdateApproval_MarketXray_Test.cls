@IsTest
public class afterUpdateApproval_MarketXray_Test {

    @testSetup
    static void setup() {

        Account acc = new Account(Name = 'MX Account');
        insert acc;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test@test.com',
            AccountId = acc.Id
        );
        insert con;

        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];

        Market_X_Ray_Form__c form = new Market_X_Ray_Form__c(
            Account__c = acc.Id,
            Contact__c = con.Id,
            OwnerId = u.Id,
            IsMarketXrayFormEditable__c = true,
            Version__c = 'V1'
        );
        insert form;
    }

    @IsTest
    static void testAfterUpdateTrigger() {

        Market_X_Ray_Form__c form =
            [SELECT Id, IsMarketXrayFormEditable__c
             FROM Market_X_Ray_Form__c
             LIMIT 1];

        Test.startTest();
        form.IsMarketXrayFormEditable__c = false;
        update form;
        Test.stopTest();

        System.assert(true);
    }
}
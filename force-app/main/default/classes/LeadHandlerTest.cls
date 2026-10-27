/**
 * Tests for LeadHandler.populateFieldsFromAccount.
 *
 * The method mutates the Lead__c records in place (no DML of its own), so the tests
 * call it directly with in-memory Lead__c records. That keeps the assertions on
 * LeadHandler alone and avoids the full LeadsTrigger / DispatcherClass cascade that a
 * real Lead__c insert would run.
 */
@isTest
private class LeadHandlerTest {

    /** First active value of Account.Country__c (a restricted picklist), or null. */
    private static String anyAccountCountry() {
        for (Schema.PicklistEntry e : Account.Country__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                return e.getValue();
            }
        }
        return null;
    }

    private static Account makeAccount() {
        CIty__c region = new CIty__c(
            Name = 'Test Region',
            Region_Code__c = 'TEST-' + DateTime.now().getTime(),
            country_key__c = 'IN'
        );
        insert region;

        Account acc = new Account(
            Name = 'Test Account',
            Country__c = anyAccountCountry(),
            Region__c = region.Id,
            Zone_Name__c = 'North',
            BillingStreet = '221B Baker Street',
            BillingCity = 'Mumbai',
            BillingState = 'Maharashtra',
            BillingPostalCode = '400001'
        );
        insert acc;

        // Re-query so the test compares against whatever value is actually stored after
        // any account-side automation, not just the literals passed above.
        return [
            SELECT Id, Country__c, Region__c, Zone_Name__c,
                   BillingStreet, BillingState, BillingCity, BillingPostalCode
            FROM Account WHERE Id = :acc.Id
        ];
    }

    @isTest
    static void populatesFieldsFromAccount() {
        Account acc = makeAccount();
        Lead__c ld = new Lead__c(Account__c = acc.Id);

        Test.startTest();
        LeadHandler.populateFieldsFromAccount(new List<Lead__c>{ ld });
        Test.stopTest();

        System.assertEquals(acc.Country__c, ld.Country__c, 'Country__c should be copied from the Account');
        System.assertEquals(acc.Region__c, ld.Region__c, 'Region__c should be copied from the Account');
        System.assertEquals(acc.Zone_Name__c, ld.Zone__c, 'Zone__c should be copied from Account.Zone_Name__c');
        System.assertEquals(acc.BillingStreet, ld.Billing_Street__c, 'Billing_Street__c should be copied');
        System.assertEquals(acc.BillingCity, ld.Billing_City__c, 'Billing_City__c should be copied');
        System.assertEquals(acc.BillingState, ld.Billing_state__c, 'Billing_state__c should be copied');
        System.assertEquals(acc.BillingPostalCode, ld.Billing_code__c, 'Billing_code__c should be copied');
    }

    @isTest
    static void leadWithoutAccountIsLeftUntouched() {
        Account acc = makeAccount();

        Lead__c withAccount = new Lead__c(Account__c = acc.Id);
        Lead__c withoutAccount = new Lead__c(Country__c = 'IN', Zone__c = 'Existing Zone');

        Test.startTest();
        LeadHandler.populateFieldsFromAccount(new List<Lead__c>{ withAccount, withoutAccount });
        Test.stopTest();

        // Populated from the account
        System.assertEquals(acc.Zone_Name__c, withAccount.Zone__c, 'Lead with an account should be populated');

        // The account-less lead keeps its original values (hits the `continue` branch)
        System.assertEquals('IN', withoutAccount.Country__c, 'Lead without an account should be unchanged');
        System.assertEquals('Existing Zone', withoutAccount.Zone__c, 'Lead without an account should be unchanged');
    }

    @isTest
    static void noAccountsShortCircuits() {
        Lead__c ld = new Lead__c(Zone__c = 'Untouched');

        Test.startTest();
        // No Account__c on any record -> accountIds is empty -> method returns early.
        LeadHandler.populateFieldsFromAccount(new List<Lead__c>{ ld });
        LeadHandler.populateFieldsFromAccount(new List<Lead__c>());
        Test.stopTest();

        System.assertEquals('Untouched', ld.Zone__c, 'Nothing should change when no lead references an account');
    }

    @isTest
    static void missingAccountRecordIsIgnored() {
        // Non-existent (but well-formed) Account Id -> accountMap.get(...) returns null,
        // exercising the `acc == null` guard without throwing.
        Id fakeAccountId = '001000000000000AAA';
        Lead__c ld = new Lead__c(Account__c = fakeAccountId, Zone__c = 'Keep');

        Test.startTest();
        LeadHandler.populateFieldsFromAccount(new List<Lead__c>{ ld });
        Test.stopTest();

        System.assertEquals('Keep', ld.Zone__c, 'Lead should be untouched when its Account cannot be found');
    }
}
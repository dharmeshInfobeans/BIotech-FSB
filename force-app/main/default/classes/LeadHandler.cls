//Created by shakib khan
public class LeadHandler {

	public static void populateFieldsFromAccount(List<Lead__c> newLeads) {
        Set<Id> accountIds = new Set<Id>();
        for (Lead__c ld : newLeads) {
            if (ld.Account__c != null) {
                accountIds.add(ld.Account__c);
            }
        }
        if (accountIds.isEmpty()) {
            return;
        }

        Map<Id, Account> accountMap = new Map<Id, Account>([SELECT Id, Country__c, Region__c, Zone_Name__c,BillingStreet, BillingState, BillingCity, BillingPostalCode
             						 FROM Account WHERE Id IN :accountIds]);

        for (Lead__c ld : newLeads) {
            if (ld.Account__c == null) continue;
            Account acc = accountMap.get(ld.Account__c);
            if (acc == null) continue;

            ld.Country__c        = acc.Country__c;
            ld.Region__c         = acc.Region__c;
            ld.Zone__c           = acc.Zone_Name__c;
            ld.Billing_Street__c = acc.BillingStreet;
            ld.Billing_City__c   = acc.BillingCity;
			ld.Billing_state__c  = acc.BillingState;
            ld.Billing_code__c   = acc.BillingPostalCode;
        }
    }

}
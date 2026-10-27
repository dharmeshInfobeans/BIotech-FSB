@isTest(SeeAllData=true)
private class LeadConversionValidatorTest {

    @isTest
    static void testValidateLeadProducts() {
        Lead__c testLead = [SELECT Id FROM Lead__c LIMIT 1];

        Lead_Product__c product = new Lead_Product__c(
            Leads__c = testLead.Id
        );
        insert product;

        Lead__c emptyLead = [SELECT Id FROM Lead__c WHERE Id != :testLead.Id LIMIT 1];

        Test.startTest();
        List<String> results = LeadConversionValidator.validateLeadProducts(
            new List<Id>{ testLead.Id, emptyLead.Id }
        );
        Test.stopTest();
    }
}
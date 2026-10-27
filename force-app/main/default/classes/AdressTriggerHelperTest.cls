@istest
public class AdressTriggerHelperTest {
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
        lea.Lead_Stage__c='Prospects';
        insert lea;
        
        Address__c adrs=new Address__c();
        adrs.Billing_City__c='test';
        adrs.Billing_code__c='474001';
        adrs.Billing_country__c='india';
        adrs.Billing_state__c='mp';
        adrs.Billing_Street__c='jp';
        adrs.Lead__c=lea.Id;
        insert adrs;
        delete adrs;
    }
}
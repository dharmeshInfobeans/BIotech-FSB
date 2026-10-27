@isTest
public class PathControllerTest {
    @isTest
    public static void method1() {
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
        lea.Billing_country__c='india';
        lea.Billing_state__c='mp';
        lea.Billing_Street__c='chandranagr';
        lea.Country__c='INDIA';
        lea.Email__c='pankajsinghania123@gmail.com';
        lea.Mobile__c='1234567890';
        lea.Marketing_Stage__c ='CME';
        lea.Lead_Stage__c ='Prospects';
        lea.Status__c=false;
        insert lea; 
        
        lea.CE_CIS_Approval__c=true;
        lea.Status__c=true;
        
        update lea;
        
        PathController.getPicklistValues(lea.Id);
        PathController.isCurrentUserAdmin();
        PathController.updateLead(lea.Id, 'Marketing_Stage__c', 'Decode');
    }
    
}
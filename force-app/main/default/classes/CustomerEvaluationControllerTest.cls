@isTest
public class CustomerEvaluationControllerTest {
    public static Account acc;
    @TestSetup
    static void makeData(){
        
        
        
    }
    
    
    static testmethod void test() { 
        Profile p = [SELECT Id FROM Profile WHERE Name='International Sales'];
        
        //UserRole r =[SELECT Id,name FROM UserRole WHERE Name='SS_NSM'];
        
        User u1 = new User(Alias = 'newU', Email='newuser123@testorg.com',
                           EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                           LocaleSidKey='en_US', ProfileId = p.Id,
                           TimeZoneSidKey='America/Los_Angeles', UserName='newuser123@testorg123.com');
        insert u1;
        System.runAs(u1){
            acc =new Account();
            acc.name='Account';
            acc.Country_Key__c='IN'; 
            acc.City__c='mumbai';
            acc.City_postal_code__c='400001';
            acc.Account_Locked__c=true;
            acc.Status__c='Activated';
            acc.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('International -Dermal').getRecordTypeId();
            
             insert acc;
        }
       
        Customer_Evaluation__c cust_eval=new Customer_Evaluation__c();
        cust_eval.Account__c=acc.Id;
        cust_eval.RecordTypeId=Schema.SObjectType.Customer_Evaluation__c.getRecordTypeInfosByName().get('International -Dermal').getRecordTypeId();
        
        insert cust_eval;
        CE_Configuration__c ce_config=new CE_Configuration__c();
        ce_config.Section_Position__c=1;
        ce_config.API_Name__c='Account__c';
        ce_config.Record_Type__c='International_Dermal';
        ce_config.DropDownValues__c='2018';
        insert ce_config;
        CE_Configuration__c ce_configs=new CE_Configuration__c();
        ce_configs.Section_Position__c=1;
        ce_configs.API_Name__c='Year__c';
        ce_configs.Record_Type__c='International_Dermal';
        ce_configs.DropDownValues__c='2018';
        insert ce_configs;
        
        
        System.debug('ACC ID::::'+String.valueOf(acc.id));
        System.debug('USER ID name::::'+u1.UserRole.Name);
        String acc_id=String.valueOf(acc.id);
        // Integer acc_id= Integer.valueOf(acc.id);
        CustomerEvaluationController.getLastCE(String.valueOf(acc.id));
        
        //String cust_eval_json='[{"Account__c":"0010l00000amSiMAAU"}]';
        String str = JSON.serialize(cust_eval);
        CustomerEvaluationController.saveCustEvaluation(str);
        CustomerEvaluationController.getCEFormData(acc.id);
        
    }
    
    // This method should not be in this class. This is creating unnecessary dependency with BiotechUtility class.
    static testmethod void test1() { 
        
        string before = 'Testing base 64 encode';            
        Blob beforeblob = Blob.valueOf(before);
        
        
    }
    
    
}
@isTest
public class CreateSampleRequestControllerTest {

    @Testsetup
    static void InitData(){
        Test.startTest();
        Account actAcc = new Account( name='ActAccount',Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',
                                   Medical_Registration_No__c='MEDREG123424567',GSTIN_No__c='GSTIN2343423456',Account_Locked__c=true,
                                   Status__c='Activated');
        insert actAcc;
        
        Account draftAcc = new Account( name='DraftAccount',Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',
                                   Medical_Registration_No__c='MEDREG123424567',GSTIN_No__c='GSTIN2343423456',Account_Locked__c=true,
                                   Status__c='Draft');
        insert draftAcc;
        
        Monthly_Plan__c mplan = new Monthly_Plan__c(name='mp1',Account__c=actAcc.id,Year__c='2019',
                                                    Month__c='Apr',Financial_Year__c='2019');
        insert mplan;
        Test.stopTest();
    }
    
    @isTest
    static void testMethod1(){
        Test.startTest();
        Account acc = [Select Id,Name,Status__c From Account Where Name='ActAccount' LIMIT 1];
        Account acc2 = [Select Id,Name,Status__c From Account Where Name='DraftAccount' LIMIT 1];
        Monthly_Plan__c mp = [Select Id,Name From Monthly_Plan__c Where Name='mp1' LIMIT 1];
        
        CreateSampleRequestController.checkAccountActivated(acc.Id);
        CreateSampleRequestController.checkAccountActivated(acc2.Id);
        CreateSampleRequestController.checkAccountActivated(null);
        CreateSampleRequestController.checkAccountActivated('AAAAAAAA12333AAAAAAAAAA');
        Test.stopTest();
    }
    
    
    @isTest
    static void testMethod2(){
        Test.startTest();
        Account acc = [Select Id,Name,Status__c From Account Where Name='ActAccount' LIMIT 1];
        Monthly_Plan__c mp = [Select Id,Name From Monthly_Plan__c Where Name='mp1' LIMIT 1];
        
        CreateSampleRequestController.getMonthlyPlanId(acc.Id,'Apr','2019');
        CreateSampleRequestController.getMonthlyPlanId(acc.Id,'Jun','2019');
        
        
        Test.stopTest();
    }
}
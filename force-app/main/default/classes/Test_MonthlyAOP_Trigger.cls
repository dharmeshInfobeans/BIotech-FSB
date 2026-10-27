@isTest
public class Test_MonthlyAOP_Trigger {
    @testsetup
    static void testTrigger(){
        
    }
    
    @isTest
    static void testCase(){
        Account acc =new Account(
            name='Account',Country_Key__c='IN', City__c='mumbai',City_postal_code__c = '400001',BillingPostalCode = '400003',
            Medical_Registration_No__c='MEDREG123424567',GSTIN_No__c='GSTIN2343423456',Account_Locked__c=true,
            Status__c='Activated');
        //GSTIN_No__c
        //RecordTypeId
        //Medical_Registration_No__c
        insert acc;
        
        
        List<CIty__c> region = TestDataFactory.createRegionData(1, 'Pune','555', 'abc');
        List<CIty__c> region2 = TestDataFactory.createRegionData(1, 'Mumbai','444', 'abcd');        
        
        
        Product__c prod = new Product__c();
        prod.Name = '600';
        prod.Dummy_Product_Code__c = 'D0001';
        prod.Dummy_Product_Description__c = '600';
        prod.Division__c = 'I';
        prod.MSP__c = 300;
        insert prod;
        
        List<Monthly_AOP__c> monthlyAOPToInsert = new List<Monthly_AOP__c>();
        for(integer i=400; i>0;i--){
            Monthly_AOP__c maop1 = new Monthly_AOP__c();
            maop1.Account__c=acc.Id;
            maop1.Year__c='2019';
            maop1.Target_Quantity__c=10;
            maop1.Month__c='Apr';
            maop1.Product__c=prod.Id;
            maop1.Region_Code__c = '555';
            monthlyAOPToInsert.add(maop1);
        }
        test.startTest();
        insert monthlyAOPToInsert;
        List<Monthly_AOP__c>lstMopToUpdate = new List<Monthly_AOP__c>();
        for(Monthly_AOP__c mop: monthlyAOPToInsert){
            mop.Region_Code__c = '444';
            lstMopToUpdate.add(mop);
        }
        update lstMopToUpdate;
        test.stopTest();
        
        
    }
}
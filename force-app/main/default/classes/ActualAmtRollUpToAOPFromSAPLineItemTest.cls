@isTest
public class ActualAmtRollUpToAOPFromSAPLineItemTest {
    @isTest
    private static void testScenario(){
        Test.startTest();
        Account acc =new Account(
            name='Account',Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',
            Medical_Registration_No__c='MEDREG123424567',GSTIN_No__c='GSTIN2343423456',Account_Locked__c=true,
            Status__c='Activated');
        
        insert acc;
        
        Monthly_Plan__c mplan=new Monthly_Plan__c(name='mp1',Account__c=acc.id,Year__c='2019',
                                                  Month__c='Apr',Financial_Year__c='2019');
        insert mplan;
        
        Product__c prod = new Product__c();
        prod.Name = '600';
        prod.Dummy_Product_Code__c = 'D0001';
        prod.Dummy_Product_Description__c = '600';
        prod.Division__c = 'I';
        prod.MSP__c = 300;
        insert prod;
        
        
        Monthly_AOP__c maop = new Monthly_AOP__c();
        maop.Account__c=acc.Id;
        maop.Year__c='2019';
        maop.Target_Quantity__c=10;
        maop.Month__c='Apr';
        maop.Product__c=prod.Id;
        maop.Financial_Year__c='2019';
        insert maop;
        
        Monthly_Product_Plan__c mpp = new Monthly_Product_Plan__c();
        mpp.Planned_Quantity__c = 20;
        mpp.Monthly_Plan__c = mplan.Id;
        mpp.Monthly_Target__c = maop.Id;    
		mpp.Month__c = mplan.Month__c;
        mpp.Year__c = mplan.Year__c;
        mpp.User__c = UserInfo.getUserId();
        mpp.MPP_Mapping__c = 'MPPCODE1234';
        insert mpp;
        
        SAP_Header__c sapH = new SAP_Header__c();
        sapH.Monthly_Plan__c = mplan.Id;
        sapH.Status__c = 'Open';
        insert sapH;
        
        SAP_Line_Item__c sapL =  new SAP_Line_Item__c();
        sapL.Monthly_Product_Plan__c = mpp.Id;
        sapL.SAP_Header__c = sapH.Id;
        sapL.Amount__c = 1000;
        insert sapL;
        
        SAP_Line_Item__c sapL2 =  new SAP_Line_Item__c();
        sapL2.Monthly_Product_Plan__c = mpp.Id;
        sapL2.SAP_Header__c = sapH.Id;
        sapL2.Amount__c = 1500;
        insert sapL2;
        
        ActualAmountRollUpToAOPFromSAPLineItem.updateAOPs(new List<Id>{maop.Id});
        
        Test.stopTest();
    }
}
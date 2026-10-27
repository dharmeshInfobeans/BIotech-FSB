@isTest
public class SAPLineHandlerTest {
    @testsetup
    static void initData(){
        Test.startTest();
        Account acc =new Account(
            name='Account',Country_Key__c='IN', City__c='mumbai',City_postal_code__c = '400001',BillingPostalCode = '400003',
            Medical_Registration_No__c='MEDREG123424567',GSTIN_No__c='GSTIN2343423456',Account_Locked__c=true,
            Status__c='Activated');
        //GSTIN_No__c
        //RecordTypeId
        //Medical_Registration_No__c
        insert acc;
        
        Monthly_Plan__c mplan=new Monthly_Plan__c(name='mp1',Account__c=acc.id,Year__c='2019',
                                                  Month__c='Apr',Financial_Year__c='2019');
        insert mplan;
        
        Monthly_Plan__c mplan2 = new Monthly_Plan__c(name='mp2',Account__c=acc.id,Year__c='2019',
                                                  Month__c='Jun',Financial_Year__c='2019');
        insert mplan2;
        
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
        insert maop;
        
        Monthly_AOP__c maop2 = new Monthly_AOP__c();
        maop2.Account__c=acc.Id;
        maop2.Year__c='2019';
        maop2.Target_Quantity__c=20;
        maop2.Month__c='Jun';
        maop2.Product__c=prod.Id;
        insert maop2;
        
        Monthly_Product_Plan__c mpp = new Monthly_Product_Plan__c();
        mpp.Planned_Quantity__c = 20;
        mpp.Monthly_Plan__c = mplan.Id;
        mpp.Monthly_Target__c = maop.Id;    
		mpp.Month__c = mplan.Month__c;
        mpp.Year__c = mplan.Year__c;
        mpp.User__c = UserInfo.getUserId();
        insert mpp;
        
        Monthly_Product_Plan__c mpp2 = new Monthly_Product_Plan__c();
        mpp2.Planned_Quantity__c = 20;
        mpp2.Monthly_Plan__c = mplan.Id;
        mpp2.Monthly_Target__c = maop.Id;    
		mpp2.Month__c = mplan2.Month__c;
        mpp2.Year__c = mplan2.Year__c;
        mpp2.User__c = UserInfo.getUserId();
        insert mpp2;

		SAP_Header__c sapH  = new SAP_Header__c();
        sapH.Monthly_Plan__c = mplan.id;
        sapH.Month__c = 'Apr';
        insert sapH;
        SAP_Header__c sapH2  = new SAP_Header__c();
        sapH2.Monthly_Plan__c = mplan2.id;
        sapH2.Month__c = 'Jun';
        insert sapH2;
        //sapH
        
        SAP_Line_Item__c sapL =  new SAP_Line_Item__c();
        sapL.SAP_Header__c = sapH.Id;
        sapL.Month__c = 'Apr';
        sapL.Monthly_Product_Plan__c = mpp.Id;
        sapL.Product__c = prod.Id;
        sapL.Monthly_AOP__c = maop.Id;
        insert sapL;
        
        SAP_Line_Item__c sapL2 =  new SAP_Line_Item__c();
        sapL2.SAP_Header__c = sapH2.Id;
        sapL2.Month__c = 'Jun';
        sapL2.Monthly_Product_Plan__c = mpp2.Id;
        sapL2.Product__c = prod.Id;
        sapL2.Monthly_AOP__c = maop2.Id;
        insert sapL2;
        sapL2.Billing_Document_No__c = '111111111';
        update sapL2;
        SAP_Line_Item__c sapL3 =  new SAP_Line_Item__c();
        sapL3.SAP_Header__c = sapH2.Id;
        sapL3.Monthly_AOP__c = maop.Id;
		Test.stopTest();
    }
    @isTest
    static void testCase1(){
        List<SAP_Line_Item__c> sapLine1 = [Select Id,Name,Monthly_AOP__c From SAP_Line_Item__c];
        SAPLineHandler.MapSap(sapLine1); 
        SAPLineHandler.updateActualAmtOnAOP(sapLine1);
        
        delete sapLine1[0];
    }
    
     @isTest
    static void testCase2(){
        List<SAP_Header__c> sapHead = [Select Id,Name From SAP_Header__c Where Month__c='Jun' Limit 1];
        List<SAP_Line_Item__c> testList =new List<SAP_Line_Item__c>();
        testList.add(new SAP_Line_Item__c(SAP_Header__c = sapHead[0].Id));
        SAPLineHandler.MapSap(testList);//will cause exception cause no mpp is added.
    }
}
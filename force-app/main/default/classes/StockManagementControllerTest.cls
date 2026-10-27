@isTest
public class StockManagementControllerTest {
    @testSetup
    public static void setupMethod(){
		RecordType accRecordType = [SELECT id FROM RecordType Where DeveloperName='Ophthalmic_Vision'];
    	List<CIty__c> lstRegion = TestDataFactory.createRegionData(1, 'Delhi', '30', 'IN');
	    List<Account> lstAccount = TestDataFactory.createAccountData(1, accRecordType.Id, lstRegion[0]);    
        Integer day = Date.today().Day();
        Date startDate = Date.newInstance(Date.today().Year(), Date.today().Month(), day-1);
        Date endDate = Date.newInstance(Date.today().Year(), Date.today().Month(), day+1);
        List<Master_Agreement__c> masterAgreements = TestDataFactory.createMasterAgreements(lstAccount[0].Id, startDate, endDate, 2);    
        
        Agreement_Product__c agreementProd1 =  TestDataFactory.createAgreementProduct('test', masterAgreements[0].id);
        Agreement_Product__c agreementProd2 =  TestDataFactory.createAgreementProduct('test1', masterAgreements[1].id);
        
        
        Date startDate1 = Date.newInstance(Date.today().Year(), Date.today().Month(), day-1);
        Date endDate1 = Date.newInstance(Date.today().Year(), Date.today().Month(), day+1);
        
        List<Master_Agreement__c> masterAgreements2 = TestDataFactory.createMasterAgreements(lstAccount[0].Id, startDate1, endDate1, 2);        
        Agreement_Product__c agreementProd3 =  TestDataFactory.createAgreementProduct('test2', masterAgreements2[0].id);
        Agreement_Product__c agreementProd4 =  TestDataFactory.createAgreementProduct('test3', masterAgreements2[1].id);
        

        Date startDate2 = Date.newInstance(2011, 03, 01);
        Date endDate2 = Date.newInstance(2012, 03, 01);
        Product__c prod = [SELECT Id FROM Product__c WHERE id=:agreementProd3.Product__c];
        List<Master_Agreement__c> masterAgreements3 = TestDataFactory.createMasterAgreements(lstAccount[0].Id, startDate2, endDate2, 2);        
        Agreement_Product__c agreementProd5 =  TestDataFactory.createAgreementProductForPoducts(prod.Id, masterAgreements3[0].id);
        Agreement_Product__c agreementProd6 =  TestDataFactory.createAgreementProduct(prod.Id, masterAgreements3[1].id);
        

        List<StockManagementController.DASWrapper> lstDAS = new List<StockManagementController.DASWrapper>();
        /*
        StockManagementController.DASWrapper das = new StockManagementController.DASWrapper(); 
   		das.onlyInitialised = true;
        das.accountId = lstAccount[0].Id;
        das.recordId = lstAccount[0].Id;
        das.apId = 'test';
        das.month = 1;
        das.soldQuantity = 0.3;
        das.startDate = date.today();
        das.uniqueKey = 'test';
        das.prodcutId = lstAccount[0].Id;
	    das.isEditable = true;
        das.masterAgrId = lstAccount[0].Id;
        */
    }

        
     
    public static testmethod void getCurrentUserAccounts(){
		StockManagementController.getCurrentUserAccounts();
    }
    public static testmethod void testGetPageData(){
        Account acc = [SELECT ID FROM Account Limit 1];
        test.startTest();
        StockManagementController.getPageData(2010, acc.Id);
        StockManagementController.getPageData(2011, acc.Id);
        StockManagementController.getPageData(2012, acc.Id);

     List<StockManagementController.DAPWrapper> wrapper3 = StockManagementController.getPageData(2010, acc.Id);
     StockManagementController.upsertDSMandDASRecords(JSON.serialize(wrapper3));
     List<StockManagementController.DAPWrapper> wrapper2 = StockManagementController.getPageData(2011, acc.Id);
     StockManagementController.upsertDSMandDASRecords(JSON.serialize(wrapper2));
     List<StockManagementController.DAPWrapper> wrapper1 = StockManagementController.getPageData(2012, acc.Id);
     StockManagementController.upsertDSMandDASRecords(JSON.serialize(wrapper1));
        
     StockManagementController.getDraftOrderCount(acc.Id);
      test.stopTest();
    }
    public static testmethod void testgetDSMWrapper(){
        Agreement_Product__c ap = new Agreement_Product__c();
        ap = [SELECT Id, Account__c, Name, Agreement_Value__c, Product__r.Name, Average_Quantity_Till_Date__c, Difference__c,FOC__c,  FOC_Text__c, Ideal_Stock_Required__c, Master_Agreement__c, Open_Order_Quantity__c, Opening_Stock__c, Price__c, Product__c, Stock_In_Transit__c, Target_Qty__c, Total_Country_Stock__c FROM Agreement_Product__c Limit 1];
        Account acc = [SELECT Id FROM Account Limit 1];
        integer[] monthLst = new List<integer>();
        integer i;
        for(i=12; i>0;i--){
            monthLst.add(i);
        }
        test.startTest();
          StockManagementController.getDSMWrapper(ap, acc.Id, monthLst, 2011);
          StockManagementController.placeOrder(acc.Id, 'INR',false);
          StockManagementController.placeOrder(acc.Id, 'INR',true);
        test.stopTest();
    }

}
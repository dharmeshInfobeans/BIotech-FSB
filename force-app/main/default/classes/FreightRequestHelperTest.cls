@isTest
private class FreightRequestHelperTest {
   @isTest static void testProcessFreightRequests() {
        // Create test Account and Order
        Account testAccount = new Account(Name='Test Acc');
        insert testAccount;
        
        Master_Agreement__c  masterAgreement = new Master_Agreement__c(Account__c = testAccount.Id, Agreement_End_Date__c=date.today()+1, Agreement_Start_Date__c=date.today());
        insert masterAgreement;

        Order__c testOrder = new Order__c(Account__c = testAccount.Id);
        insert testOrder;       
        
        Plant__c plan = new Plant__c(Name='BCD');
        insert plan;
        
        Product__c prod = new Product__c(Name='ABC', Dummy_Product_Code__c='34566',Plant__c = plan.Id);
        insert prod;
        
        Agreement_Product__c agreementProduct = new Agreement_Product__c( Agreement_Value__c=100, Master_Agreement__c = masterAgreement.Id, Price__c=100,Product__c = prod.id, Incoterms__c = 'C&F' );
        insert agreementProduct;

        // Create test Order Products
        List<Order_Product__c> newOrderProducts = new List<Order_Product__c>();
        newOrderProducts.add(new Order_Product__c(Order__c = testOrder.Id, Product__c = prod.Id, Agreement_Product__c = agreementProduct.Id,Is_Parent_Products__c= true, Total_Price__c = 100));
        
        // Create existing Freight Request records
        /*List<Freight_Request__c> existingFRList = new List<Freight_Request__c>();
        existingFRList.add(new Freight_Request__c(Order__c = testOrder.Id, Plant__c = plan.Id));
        existingFRList.add(new Freight_Request__c(Order__c = testOrder.Id, Plant__c = plan.Id));
        insert existingFRList;*/

        // Create a map of old Order Products for delete testing
        /*Map<Id, Order_Product__c> oldOrderProductsMap = new Map<Id, Order_Product__c>();
        for (Order_Product__c op : newOrderProducts) {
            oldOrderProductsMap.put(op.Id, op);
        }*/

        Test.startTest();
        insert newOrderProducts;

        // Test the creation of new Freight Request records
        //FreightRequestHelper.processFreightRequests(newOrderProducts, new Map<Id, Order_Product__c>());
        List<Freight_Request__c> insertedFRs = [SELECT Id FROM Freight_Request__c];
        System.assertEquals(newOrderProducts.size(), insertedFRs.size(), 'New Freight Request records not inserted');

        // Test the updating of existing Freight Request records
       /* newOrderProducts.get(0).Product__c = prod.Id;
        update newOrderProducts.get(0);
        FreightRequestHelper.processFreightRequests(newOrderProducts, new Map<Id, Order_Product__c>());*/
        
        /*List<Freight_Request__c> updatedFRs = [SELECT Products__c FROM Freight_Request__c WHERE Order__c = :testOrder.Id AND Plant__c = :plan.Id];
        System.assertEquals(2, updatedFRs.size(), 'Wrong number of updated Freight Request records');
        System.assertEquals(null, updatedFRs[0].Products__c, 'Products__c not updated correctly');

        // Test the deletion of Freight Request records
        delete oldOrderProductsMap.values();
        FreightRequestHelper.processFreightRequests(new List<Order_Product__c>(), oldOrderProductsMap);*/
        

        Test.stopTest();
    }
    
    @isTest static void testProcessFreightRequestsdelete() {
        // Create test Account and Order
        Account testAccount = new Account(Name='Test Acc');
        insert testAccount;
        
        Master_Agreement__c  masterAgreement = new Master_Agreement__c(Account__c = testAccount.Id, Agreement_End_Date__c=date.today()+1, Agreement_Start_Date__c=date.today());
        insert masterAgreement;

        Order__c testOrder = new Order__c(Account__c = testAccount.Id);
        insert testOrder;
        Plant__c plan = new Plant__c(Name='BCD');
        insert plan;
        
        Product__c prod = new Product__c(Name='ABC', Dummy_Product_Code__c='34566', Plant__c = plan.Id);
        insert prod;      
        
        
        Agreement_Product__c agreementProduct = new Agreement_Product__c( Agreement_Value__c=100, Master_Agreement__c = masterAgreement.Id, Price__c=100,Product__c = prod.id, Incoterms__c = 'C&F' );
         insert agreementProduct;

        // Create test Order Products
        List<Order_Product__c> newOrderProducts = new List<Order_Product__c>();
        newOrderProducts.add(new Order_Product__c(Order__c = testOrder.Id, Product__c = prod.Id, Agreement_Product__c = agreementProduct.Id,Is_Parent_Products__c= true,Total_Price__c = 100));
        //newOrderProducts.add(new Order_Product__c(Order__c = testOrder.Id, Product__c = prod.Id, Agreement_Product__c = agreementProduct.Id,Is_Parent_Products__c= true));
        insert newOrderProducts;

        // Create existing Freight Request records
        /*List<Freight_Request__c> existingFRList = new List<Freight_Request__c>();
        existingFRList.add(new Freight_Request__c(Order__c = testOrder.Id, Plant__c = plan.Id));
        existingFRList.add(new Freight_Request__c(Order__c = testOrder.Id, Plant__c = plan.Id));
        insert existingFRList;*/

        // Create a map of old Order Products for delete testing
        Map<Id, Order_Product__c> oldOrderProductsMap = new Map<Id, Order_Product__c>();
        for (Order_Product__c op : newOrderProducts) {
            oldOrderProductsMap.put(op.Id, op);
        }

        Test.startTest();
        delete newOrderProducts[0];
        
        Test.stopTest();
    }
}
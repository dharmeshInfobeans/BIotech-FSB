@isTest
public class OrderProductSelectionControllerTest {
    
    static testmethod void testAllMethods(){
        
        
        
        CIty__c city = new CIty__c(Name='Test', Region_Code__c='Test', country_key__c='Test');
        insert city;
       RecordType dealerPortalRT;
        try {
            dealerPortalRT = [SELECT Id FROM RecordType WHERE DeveloperName = 'Dealer_Portal' AND SObjectType = 'Account' LIMIT 1];
        } catch (Exception e) {
            System.assert(false, 'Dealer_Portal RecordType not found. Please ensure it exists.');
            return;
        }
        
        Account testAccount = new Account(
            Name = 'Test Account',
            E_Mail__c = 'test@example.com',
            RecordTypeId = dealerPortalRT.Id
        );
        insert testAccount;
                                          // Integer page, Integer pageSize, string sortColumn, string sortOrder, string searchStr,string accountId       
         Master_Agreement__c masterAgreement = new Master_Agreement__c(
            Agreement_Number__c = 'AGR-001',
            Version__c = 'V1',
            CurrencyIsoCode = 'USD',
            Distributer_Type__c = 'Exclusive Distributor',
            Account__c = testAccount.Id,
            Vertical__c = 'Ophthalmic',
            Agreement_Start_Date__c = Date.today(),
            Agreement_End_Date__c = Date.today().addMonths(1),
            Agreement_Signed_With__c = 'BIOTECH HEALTHCARE HOLDING GMBH',
			Remark_1__c = 'Remark 1 details with {!Master_Agreement__c.Agreement_Signed_With__c}'

        );
        insert masterAgreement;
        
        System.debug('Master Agreement Records:: '+[SELECT Id FROM Master_Agreement__c WHERE Account__c=: testAccount.Id 
                                                        Order By Agreement_End_Date__c Desc LIMIT 1]);

        
        Product__c prod = new Product__c(Name='ABC', Dummy_Product_Code__c='34566');
        insert prod;
        Product__c prod2 = new Product__c(Name='def', Dummy_Product_Code__c='3456def');
        insert prod2;
         Order__c  order = new Order__c();
  //       order.Biotech_Po_No__c = 'test'; 
         order.Account__c = testAccount.Id;
         order.Customer_Po_No__c = 'test';
         order.Order_Date__c = date.today();
         insert order;
        
        OrderProductSelectionController.getPricebookEntries(1, 10,null,null,null,order.Id);
        OrderProductSelectionController.searchProducts('a');
        OrderProductSelectionController.getQuoteLineItems();
        
        
         Agreement_Product__c agreementProduct = new Agreement_Product__c( Agreement_Value__c=100, Master_Agreement__c = masterAgreement.Id, Price__c=100);
         insert agreementProduct;
        

        
        
        
        OrderProductSelectionController.getOrderLineItems(order.Id);
        
        Order_Product__c orderLineItemParent = new Order_Product__c(Unique_Key__c='test', Order__c =order.Id, Unit_Price__c=10, Total_Price__c=10, Quantity__c=10, Agreement_Product__c = agreementProduct.Id, Discount__c=10,Product__c = prod.Id);
        insert orderLineItemParent;

Order_Product__c orderLineItemParent2 = new Order_Product__c(Unique_Key__c='testParent2', Order__c =order.Id, Unit_Price__c=10, Total_Price__c=10, Quantity__c=10, Agreement_Product__c = agreementProduct.Id, Discount__c=10,Is_Parent_Products__c=true,Product__c = prod.Id);
        insert orderLineItemParent2;        
        Order_Product__c orderLineItemChild = new Order_Product__c(Unique_Key__c='test2', Unit_Price__c=10,Order__c =order.Id, Total_Price__c=10, Quantity__c=10, Code_txt__c = 'Code', Model_Txt__c='Model', Agreement_Product__c = agreementProduct.Id,Product__c = prod.Id);
        insert orderLineItemChild;
        System.debug('orderLineItemChild:: '+orderLineItemChild);
        Order_Product__c orderLineItem = new Order_Product__c();
        OrderProductSelectionController.OrderProductWrapper wrapper = new OrderProductSelectionController.OrderProductWrapper();
        wrapper.UniqueKey =  orderLineItemParent.Unique_Key__c;
        wrapper.SalesPrice = orderLineItemParent.Unit_Price__c;
        wrapper.TotalPrice = orderLineItemParent.Total_Price__c;
        wrapper.Quantity = integer.valueOf(orderLineItemParent.Quantity__c); 
        wrapper.AggrementProduct = orderLineItemParent.Agreement_Product__c;
        wrapper.Discount = orderLineItemParent.Discount__c;
        wrapper.Product = Prod.Id;
        wrapper.InCart = false;
        
        OrderProductSelectionController.OrderProductWrapper subOrderProdWrapper = new OrderProductSelectionController.OrderProductWrapper();
        subOrderProdWrapper.UniqueKey = 'test2';//orderLineItemChild.Unique_Key__c;
        subOrderProdWrapper.SalesPrice  = orderLineItemChild.Unit_Price__c;
        subOrderProdWrapper.TotalPrice  = orderLineItemChild.Total_Price__c;
        subOrderProdWrapper.Quantity  = integer.valueOf(orderLineItemChild.Quantity__c);
        subOrderProdWrapper.CodeTxt  = orderLineItemChild.Code_txt__c;
        subOrderProdWrapper.ModelTxt  = orderLineItemChild.Model_Txt__c;
     //   subOrderProdWrapper.UniqueKey  = orderLineItemChild.Parent_Unique_Key__c;
        subOrderProdWrapper.AggrementProduct  = orderLineItemChild.Agreement_Product__c;
        subOrderProdWrapper.Discount  = orderLineItemChild.Discount__c;
        
            List<OrderProductSelectionController.OrderProductWrapper> lstSubProd = new List<OrderProductSelectionController.OrderProductWrapper>();
        lstSubProd.add(subOrderProdWrapper);
        
        wrapper.subOrderProducts = lstSubProd;
                
        List<OrderProductSelectionController.OrderProductWrapper> lstWrapper = new List<OrderProductSelectionController.OrderProductWrapper>();
        lstWrapper.add(wrapper);
        
        String orderProductStr = JSON.serialize(lstWrapper);  
        System.debug('orderProductStr:::: '+orderProductStr);
        test.startTest();
        try{
           // OrderProductSelectionController.upsertOrderProducts(orderProductStr, order.Id,null);
                        OrderProductSelectionController.upsertOrderProducts(orderProductStr, order.Id,3.2);
    
            OrderProductSelectionController.getOrderDetails(order.id);
            //OrderProductSelectionController.upsertQuoteItems('test');
        }
        catch(Exception e){
            System.debug('e:->'+e);
        }
        Product__c  product = new Product__c(Active__c=true, Name = 'test', Quantity__c=10, UnitPrice__c=20, Dummy_Product_Code__c='test');
        insert product;
        Product_Model__c  model = new Product_Model__c(Description__c='Description', Product__c = product.Id);
        insert model;
           OrderProductSelectionController.getModels(String.valueOf(product.id));

  //      OrderProductSelectionController.getModelsWithCode(String.valueOf(product.id));
        //upsertOrderProducts

        // Add test product to be used in addSelectedProductsToQli
        Order_Product__c cartItem = new Order_Product__c(
            Unique_Key__c = 'uniqueKey123',
            Order__c = order.Id,
            InCart__c = false,
            Product__c = prod.Id
        );
        insert cartItem;

        // Try to add a new item that doesn't already exist in cart
        List<String> keysToAdd = new List<String>{'newKey456', 'uniqueKey123'}; // One new, one existing
        OrderProductSelectionController.addSelectedProductsToQli(order.Id, keysToAdd);

        // Confirm only one new product was inserted
        List<Order_Product__c> orderProducts = [
            SELECT Id, Unique_Key__c, Order__c 
            FROM Order_Product__c 
            WHERE Order__c = :order.Id AND Unique_Key__c = 'newKey456'
        ];
        System.assertEquals(1, orderProducts.size(), 'Should insert only one new order product for the new unique key');

        // Now delete the newly inserted product
        String recordIdToDelete = orderProducts[0].Id;
        OrderProductSelectionController.deleteSubProduct(recordIdToDelete);

        // Confirm it's deleted
        //Order_Product__c deletedItem = [SELECT Id FROM Order_Product__c WHERE Id = :recordIdToDelete LIMIT 1];
        //System.assertEquals(null, deletedItem, 'The order product should be deleted.');

        test.stopTest();
    }

}
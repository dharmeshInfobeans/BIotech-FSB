public with sharing class OrderProductSelectionController {
    public class OrderProductWrapper {
         @AuraEnabled
         public string UniqueKey;
 
            @AuraEnabled
         public string orderId;
 
         @AuraEnabled
         public string ProductCode;
 
         @AuraEnabled
         public Decimal ListPrice;
 
         @AuraEnabled
         public Decimal SalesPrice;
 
         @AuraEnabled
         public string ProductFamily;
 
         @AuraEnabled
         public integer Quantity;
 
         @AuraEnabled
         public Boolean InCart;          //Added for Cart management. When Order Item is autoSaved, its InCart value is true
 
         @AuraEnabled
         public String FOCText;
 
         @AuraEnabled
         public integer FocQuantity;
 
         @AuraEnabled
         public integer oldQuantity;
 
         @AuraEnabled
         public Decimal Discount;
 
         @AuraEnabled
         public Decimal Total;
 
         @AuraEnabled
         public string ProductName;
 
          @AuraEnabled
         public string AggrementProduct;
 
         @AuraEnabled
         public decimal SubTotalPrice;
 
         @AuraEnabled
         public decimal TotalPrice;
 
         @AuraEnabled
         public string CodeTxt;
 
        @AuraEnabled
         public decimal SelectedPower;
 
 
 
         @AuraEnabled
         public string ModelTxt;
 
         @AuraEnabled
         public string Product;
 
       @AuraEnabled
         public string currencyCode;
 
       @AuraEnabled
         public string SelectedCylendricalPower;
 
        @AuraEnabled
         public string selectedaxisAngle;
 
 
         @AuraEnabled
         public list<OrderProductWrapper> subOrderProducts;
 
        @AuraEnabled
        public integer totalQuantity;
     }
 
 
     @AuraEnabled
     public static List<Agreement_Product__c> getPricebookEntries(Integer page, Integer pageSize, string sortColumn, string sortOrder, string searchStr,string orderId){
         System.debug('searchStr:: '+searchStr);
 
         //Get order with accountId
         order__c orderRec = [select id, account__c, Plant__c,Vertical__c from order__c where Id=:orderId];
         String plantId = orderRec.plant__c;
         Integer skipRecords = 0;
 
         page = Integer.valueOf(page);
         pageSize = Integer.valueOf(pageSize);
         if(page > 1)
              skipRecords = (page - 1 ) * pageSize ;
 
         system.debug('skipRecords***'+skipRecords);
 
         //Get the active master aggrement
         List<Master_Agreement__c> lstMasterAgreement = [SELECT Id FROM Master_Agreement__c WHERE Account__c=: orderRec.Account__c  
         AND Vertical__c=:orderRec.Vertical__c AND Is_Active__c=true 
         AND Agreement_Start_Date__c <=: Date.today() AND Agreement_End_Date__c >=: date.today()
         Order By Agreement_End_Date__c Desc ];//LIMIT 1
         System.debug('lstMasterAgreement:: '+lstMasterAgreement);
 
         Set<Id> masterApIdSet = new Set<Id>();
         for(Master_Agreement__c maAP : lstMasterAgreement){
             masterApIdSet.add(maAP.Id);
         }
 
         String query = 'SELECT Id,currencyIsoCode,Name, FOC__c, FOC_Text__c, Agreement_Value__c,Is_Backup__c, Price__c,Product__c,Product__r.division__c,Product__r.Dummy_Product_Description__c, Product__r.Dummy_Product_code__c,Product__r.Category__c,' +
             'Product__r.Name, Target_Qty__c, Master_Agreement__r.Account__r.CurrencyIsoCode  , Master_Agreement__r.Agreement_Start_Date__c,Master_Agreement__r.Agreement_End_Date__c, Product__r.Model_Count__c,Ideal_Stock_Required__c,Opening_Stock__c,Average_Quantity_Till_Date__c,Difference__c FROM Agreement_Product__c WHERE Master_Agreement__c IN:masterApIdSet AND Product__r.Plant__c !=null'; // AND Product__r.Plant__c =: plantId';//(select id,Ideal_Stock_Required__c,Opening_Stock__c,Average_Quantity_Till_Date__c,Difference__c from Dealer_Stock_Managements__r)
         if(searchStr == null) {
            query +=' and Difference__c <=0';
         }                                                                                                                                                               //FROM Agreement_Product__c WHERE Difference__c <=0 and Master_Agreement__c =\''+lstMasterAgreement[0].Id+'\''
         if(searchStr!=null) {
             query += ' and (Product__r.Dummy_Product_Description__c LIKE \'%' +String.escapeSingleQuotes(searchStr) + '%\'';
             query += '  or Product__r.division__c LIKE \'%' +String.escapeSingleQuotes(searchStr) + '%\'';
             query += '  or Product__r.Name LIKE \'%' +String.escapeSingleQuotes(searchStr) + '%\' )';
 
         }
 
 
 
         query +=' order by Product__r.Name';
 
         if(sortOrder!= null && sortColumn!=null){
             query += ' Order by ' + sortColumn + ' ' + sortOrder;
         }
 
 
         query += ' LIMIT ' + pageSize ;
 
         query += ' OFFSET '+ skipRecords;
 
 
         List<Agreement_Product__c> lstAgreementProd = new List<Agreement_Product__c>();
         System.debug('query:: '+query);
         for(Agreement_Product__c ap : (List<Agreement_Product__c>) Database.query( query )){
             Date todaysDate = Date.today();
             if(todaysDate >= ap.Master_Agreement__r.Agreement_Start_Date__c && todaysDate <= ap.Master_Agreement__r.Agreement_End_Date__c){
                     lstAgreementProd.add(ap);
             }
         }
         System.debug('lstAgreementProd:: '+lstAgreementProd);
         SYstem.debug('lstAgreementProd size:'+lstAgreementProd.size());
         return lstAgreementProd;
     }
 
      @AuraEnabled
     public static List<Product__c> getQuoteLineItems(){//This method provides default selected products list
        List<Product__c> lstQli  =  [Select Id, Dummy_Product_Code__c, Category__c,Name,Active__c, Family__c, UnitPrice__c,Discount__c from Product__c Limit 0];
 
 
         system.debug('**lstQli***'+lstQli);
         return lstQli;
     }
 
     @AuraEnabled
     public static List<Product__c> searchProducts(string searchStr){
          string stringSearch='%' +searchStr + '%';
        List<Product__c> lstPbe =   [Select Id, Dummy_Product_Code__c, Name,Active__c, Family__c,
                                     UnitPrice__c from Product__c WHERE Name LIKE : stringSearch Limit 5];
 
         system.debug('**lstPbe***'+lstPbe);
         return lstPbe;
     }
 
 
 
 
      @AuraEnabled
     public static List<Product_Model__c> getModels(string productId){
         System.debug('productId:: '+productId);
         List<Product_Model__c> lstProductModel = [Select Id, Axis_Angle__c, Cylindrical_Power__c,Spherical_Power_Maximum1__c, Text_Name__c, Spherical_Power_Maximum__c, Spherical_Power_Minimum1__c, Spherical_Power_Minimum__c, Steps1__c, Steps__c,Steps2__c, Minimum_Power_2__c, Maximum_Power2__c  FROM Product_Model__c WHERE Product__c =: productId];
         System.debug('lstProductModel::'+lstProductModel);
         return lstProductModel;
 
     }
 
   //   @AuraEnabled
     //public static void upsertQuoteItems (string quoteLineItemsStr){
         //list<QuoteItemWrapper> lstQuoteItemWrapper = (list<QuoteItemWrapper>)System.JSON.deserialize(quoteLineItemsStr,list<QuoteItemWrapper>.class);
         //system.debug('***lstQuoteItemWrapper***'+lstQuoteItemWrapper);
    // }
 
     @AuraEnabled
     public static void upsertOrderProducts(string orderProductStr, string orderId, Decimal frieght){
         //Get existing oli
         list<Order_Product__c> existingOrderItems = getOrderLineItems(orderId);
         if(frieght != null){
             order__c order = [select id, name,Freight_Amount__c from order__c where Id=:orderId];
             order.Freight_Amount__c = frieght;
             update order;
         }
 
         map<string, Order_Product__c> mapNewOrderProd_ByKeys = new map<string, Order_Product__c>();
         map<string, Order_Product__c> mapExistingOrderProd_ByKeys = new map<string, Order_Product__c>();
         List<Order_Product__c> orderLineItemsToDelete = new List<Order_Product__c>();
         set<String> existingLineItemSet = new set<String>();
                 System.debug('existingOrderItems:->'+existingOrderItems);
 
         for(Order_Product__c orderLineItem : existingOrderItems){
             mapExistingOrderProd_ByKeys.put(orderLineItem.Unique_Key__c, orderLineItem);
         }
 
         system.debug('orderProductStr**'+orderProductStr);
         list<OrderProductWrapper> lstOrderProduct = (list<OrderProductWrapper>) JSON.deserialize(orderProductStr, list<OrderProductWrapper>.class);
         system.debug('***list<OrderProductWrapper>***'+lstOrderProduct);
 
         list<Order_Product__c> parentOrderLineItems =  new list<order_product__c>();
         list<Order_Product__c> subOrderLineItems =  new list<order_product__c>();
         map<string, list<Order_Product__c>> mapOrder_subOrderLineItems = new map<string, list<Order_Product__c>>();
         Set<String> orderProductUniqueKeySet = new Set<String>();
         Set<String> subProductUniqueKeySet = new Set<String>();
         Order_Product__c orderLineItem = new Order_Product__c();
         for(OrderProductWrapper orderProdWrapper : lstOrderProduct) {
             System.debug('orderProdWrapper:: '+orderProdWrapper);
             orderProductUniqueKeySet.add(orderProdWrapper.UniqueKey);
             orderLineItem = new Order_Product__c();
             orderLineItem.FOC_Quantity__c = orderProdWrapper.FocQuantity;
             orderLineItem.Unique_Key__c = orderProdWrapper.UniqueKey;
             orderLineItem.Unit_Price__c = orderProdWrapper.SalesPrice;
             orderLineItem.Total_Price__c = orderProdWrapper.TotalPrice;
             orderLineItem.Quantity__c = orderProdWrapper.Quantity;
             orderLineItem.Is_Parent_Products__c = true;
             orderLineItem.Agreement_Product__c = orderProdWrapper.AggrementProduct;
             orderLineItem.Discount__c = orderProdWrapper.Discount;
             orderLineItem.Sub_Total_Price__c = orderProdWrapper.SubTotalPrice;
             system.debug('Sub Total Price 207: '+orderLineItem.Sub_Total_Price__c);
             orderLineItem.Order__c = orderId;
             orderLineItem.InCart__c = Boolean.valueOf(orderProdWrapper.InCart);              //Added for Cart Management
             orderLineItem.Product__c = orderProdWrapper.Product;
             orderLineItem.Cyindrical_Power__c = orderProdWrapper.SelectedCylendricalPower;
             orderLineItem.Axis_Angle__c = orderProdWrapper.selectedaxisAngle;
         //    orderLineItem.Total_quantity__c=orderProdWrapper.totalQuantity;//Code added(Total quantity)
 
 
 
 
 
             parentOrderLineItems.add(orderLineItem);
             subOrderLineItems = new list<Order_Product__c>();
             if(orderProdWrapper != null && orderProdWrapper.subOrderProducts != null){
             for(OrderProductWrapper subOrderProdWrapper : orderProdWrapper.subOrderProducts) {
                 orderLineItem = new Order_Product__c();
                 if(subOrderProdWrapper != null && subOrderProdWrapper.UniqueKey != null){
                 orderLineItem.Unique_Key__c = subOrderProdWrapper.UniqueKey;
                 }
                 subProductUniqueKeySet.add(subOrderProdWrapper.UniqueKey);
                 orderLineItem.Unit_Price__c = subOrderProdWrapper.SalesPrice;
                 orderLineItem.Total_Price__c = subOrderProdWrapper.TotalPrice;
                 orderLineItem.Quantity__c = subOrderProdWrapper.Quantity;
                 orderLineItem.Code_txt__c = subOrderProdWrapper.CodeTxt;
                 orderLineItem.Model_Txt__c = subOrderProdWrapper.ModelTxt;
                 orderLineItem.Spherical_Power__c = subOrderProdWrapper.selectedPower;
                 orderLineItem.Is_Parent_Products__c = false;
                 orderLineItem.Parent_Unique_Key__c = orderProdWrapper.UniqueKey;
                 orderLineItem.Agreement_Product__c = subOrderProdWrapper.AggrementProduct;
                 orderLineItem.Discount__c = subOrderProdWrapper.Discount;
                 orderLineItem.Order__c = OrderId;
                 orderLineItem.InCart__c =subOrderProdWrapper.InCart != null? Boolean.valueOf(subOrderProdWrapper.InCart): false ;           //Added for Cart Management
                 orderLineItem.FOC_Quantity__c = subOrderProdWrapper.FocQuantity;
                 orderLineItem.Product__c = subOrderProdWrapper.Product;
                 orderLineItem.Spherical_Power__c = subOrderProdWrapper.SelectedPower;
                 orderLineItem.Sub_Total_Price__c = subOrderProdWrapper.SubTotalPrice;
                 orderLineItem.Unique_Key__c  =  subOrderProdWrapper.UniqueKey;//added while writing test class
                 orderLineItem.Cyindrical_Power__c = subOrderProdWrapper.SelectedCylendricalPower;
                 orderLineItem.Axis_Angle__c = subOrderProdWrapper.selectedaxisAngle;
               //  orderLineItem.Total_quantity__c=subOrderProdWrapper.totalQuantity;//Code added(Total quantity)
                 subOrderLineItems.add(orderLineItem);
             }
         }
              mapOrder_subOrderLineItems.put( orderLineItem.Parent_Unique_Key__c, subOrderLineItems);
         }
 
         system.debug('***parentOrderLineItems***'+parentOrderLineItems);
         system.debug('***mapOrder_subOrderLineItems***'+mapOrder_subOrderLineItems);
 
         //upsert parentOrderLineItems
         upsert parentOrderLineItems Unique_Key__c;
 
         list<Order_Product__c> lstSubOLI = new list<Order_Product__c>();
         for(Order_Product__c parentOLI : parentOrderLineItems){
             mapNewOrderProd_ByKeys.put(parentOLI.Unique_Key__c, parentOLI);
             if(mapOrder_subOrderLineItems.containsKey(parentOLI.Unique_Key__c)){
                 subOrderLineItems = mapOrder_subOrderLineItems.get(parentOLI.Unique_Key__c);
                 for(Order_Product__c subOLI : subOrderLineItems){
                     subOLI.Parent_Order_Product__c = parentOLI.Id;
                     lstSubOLI.add(subOLI);
                 }
             }
         }
         System.debug('lstSubOLI to upsert:: '+lstSubOLI);
         upsert lstSubOLI Unique_Key__c;
 
         //Logic for deleting sub products
         List<Order_Product__c> lstOrderProductToDelete = [SELECT Id FROM Order_Product__c WHERE id Not IN:lstSubOLI and Parent_Order_Product__c IN:parentOrderLineItems];
         System.debug('lstOrderProductToDelete:: '+lstOrderProductToDelete);
         if(lstOrderProductToDelete.size() >0 ){
             delete lstOrderProductToDelete;
         }
        //Log for deleting main products
         for(Order_Product__c orderRec : parentOrderLineItems) {
             if(!mapNewOrderProd_ByKeys.containsKey(orderRec.Unique_Key__c)) {
                 orderLineItemsToDelete.add(mapExistingOrderProd_ByKeys.get(orderRec.Unique_Key__c));
                 orderLineItemsToDelete.addAll(mapExistingOrderProd_ByKeys.get(orderRec.Unique_Key__c).Sub_Order_Products__r);
             }
         }
 
 
         for(Order_Product__c orderRec : existingOrderItems) {
             if(!mapNewOrderProd_ByKeys.containsKey(orderRec.Unique_Key__c)) {
                 orderLineItemsToDelete.add(orderRec);
                 orderLineItemsToDelete.addAll(orderRec.Sub_Order_Products__r);
             }
         }
 
 
         /*
         for(Order_Product__c record : mapNewOrderProd_ByKeys.Values()){
             if(mapExistingOrderProd_ByKeys.ContainsKey(record.Unique_Key__c)){
                 orderLineItemsToDelete.add(mapExistingOrderProd_ByKeys.get(record.Unique_Key__c));
             }
         }*/
         System.debug('orderLineItemsToDelete:: '+orderLineItemsToDelete);
         if(orderLineItemsToDelete.size() > 0){
             system.debug('detete successfully');
             delete orderLineItemsToDelete;
         }
 
        system.debug('***'+lstSubOLI);
 
 
     }
 
 
     @AuraEnabled
     public static List<Order_Product__c> getOrderLineItems(string orderId){//This method provides default selected products list
         List<Order_Product__c> lstOrderProduct  =  [Select Id, Agreement_Product__c,Agreement_Product__r.Is_Backup__c,Agreement_Product__r.Product__r.Name,CurrencyIsoCode, Unique_Key__c,Total_Quantities__c,
                                                     Agreement_Product__r.Product__r.Dummy_Product_Code__c,Agreement_Product__r.Product__c, InCart__c,Agreement_Product__r.FOC_Text__c,
                                                     Discount__c, Is_Parent_Products__c, Order__c, Parent_Order_Product__c,Foc_Quantity__c,
                                                     Parent_Unique_Key__c, Product__c, Product_Model__c, Quantity__c,Agreement_Product__r.FOC__c,Agreement_Product__r.Product__r.model_count__c,
                                                     Total_Price__c,Spherical_Power__c, Unit_Price__c, (select Id, Agreement_Product__c,Agreement_Product__r.Product__r.Name,CurrencyIsoCode	,
                                                                                     Discount__c,Agreement_Product__r.Product__r.Dummy_Product_Code__c,
                                                                                     Model_Txt__c, Code_Txt__c,Agreement_Product__r.Product__c,Foc_Quantity__c, InCart__c,
                                                                                     Is_Parent_Products__c, Order__c, Parent_Order_Product__c,Product_Model_Code__c,
                                                                                     Parent_Unique_Key__c, Product__c, Quantity__c,Spherical_Power__c,Axis_Angle__c,Cyindrical_Power__c,
                                                                                     Total_Price__c, Unit_Price__c,Total_Quantities__c, Unique_Key__c from Sub_Order_Products__r)
                                                     from Order_Product__c
                                                     where order__c =:orderId and Is_Parent_Products__c=true];
 
         system.debug('**lstOrderProduct***'+lstOrderProduct);
         return lstOrderProduct;
     }
 
     @AuraEnabled
     public static Map<string,Object> getOrderDetails(string orderId){
         Boolean incotermsRequired = false;
         Order__c ordRec = [ Select Id, Name,Account__c, Buyer_Account__c, Account__r.Name, Status__c,Freight_Amount__c,CurrencyIsoCode, Plant__c,Vertical__c from Order__c where Id=:orderId];
         Master_Agreement__c MA = [select id,Incoterms__c from Master_Agreement__c where Account__c =:ordRec.Account__c And Agreement_Start_Date__c <=: Date.today() And Agreement_End_Date__c >=: date.today() AND Vertical__c=:ordRec.Vertical__c AND Is_Active__c=true ];

        integer productCount = [SELECT count() FROM Agreement_Product__c WHERE Master_Agreement__c =: Ma.Id AND Product__r.Plant__c !=null AND Product__r.Plant__c =:ordRec.Plant__c];
        System.debug('productCount'+productCount);
         return new Map<string,Object>{
             'Id'=>ordRec.Id,'Name'=>ordRec.Name,'Account__c'=>ordRec.Account__c,'Account__r.Name'=>ordRec.Account__r.Name,'Status__c'=>ordRec.Status__c,'incotermsRequired'=>incotermsRequired,
                 'Freight_Amount__c'=>ordRec.Freight_Amount__c,'CurrencyIsoCode'=>ordRec.CurrencyIsoCode,'Incoterm'=>incotermsRequired,'Plant'=>ordRec.Plant__c,'productCount'=>incotermsRequired, 'Buyer_Account__c'=>ordRec.Buyer_Account__c
         };
     }
 
     //demo
  @AuraEnabled
     public static void addSelectedProductsToQli(String orderId, List<String> selectedProductUniqueKeys) {
         // Get the order
         Order__c orderRec = [SELECT Id FROM Order__c WHERE Id = :orderId];
 
         // Get the existing cart items for this order
         List<Order_Product__c> existingCartItems = [SELECT Id, Unique_Key__c, InCart__c FROM Order_Product__c WHERE Order__c = :orderRec.Id];
 
         // Create a set to store the unique keys of existing cart items
         Set<String> existingCartItemKeys = new Set<String>();
         for (Order_Product__c cartItem : existingCartItems) {
             existingCartItemKeys.add(cartItem.Unique_Key__c);
         }
 
         // Create a list to store new cart items to be inserted
         List<Order_Product__c> newCartItems = new List<Order_Product__c>();
 
         // Iterate through the selectedProductUniqueKeys
         for (String uniqueKey : selectedProductUniqueKeys) {
             // Check if the product with the unique key is already in the cart
             if (!existingCartItemKeys.contains(uniqueKey)) {
                 // Product is not in the cart, so create a new cart item
                 Order_Product__c cartItem = new Order_Product__c(
                     Order__c = orderRec.Id,
                     Unique_Key__c = uniqueKey,
                     InCart__c = true  // Set the InCart checkbox to true
                 );
                 newCartItems.add(cartItem);
             }
         }
 
         // Insert new cart items
         if (!newCartItems.isEmpty()) {
             insert newCartItems;
         }
     }
     //iiii
 
     @AuraEnabled
     public static void deleteSubProduct(String RecordId){
         System.debug('RecordId:: '+RecordId);
         Order_Product__c orderProd;
         if(RecordId !='' || RecordId !=null){
          orderProd = [Select Id FROM Order_Product__c WHERE id=:RecordId];
         }
         if(orderProd !=null){
         delete orderProd;

         }
     }
 
 }
public class FreightRequestHelper {
    public static Boolean insertUpdaterunOnce = true;
    public static Boolean deleterunOnce = true;
    public static void processFreightRequests(List<Order_Product__c> newOrderProducts, Map<Id, Order_Product__c> oldOPMap) {
        
        Map<Id, Map<Id, Freight_Request__c>> orderToPlantToFRMap = new Map<Id, Map<Id, Freight_Request__c>>();
        Set<Id> productIdSet = new Set<Id>();
        Set<Id> orderIdSet = new Set<Id>();
        
        for (Order_Product__c op : newOrderProducts) {
            if(oldOPMap != null && oldOPMap.containsKey(op.Id)) {
                if(oldOPMap.get(op.Id).Product__c != op.Product__c) {
                    orderIdSet.add(op.Order__c);
                    productIdSet.add(op.Product__c);
                }
            }
            else if(oldOPMap == null) {
                orderIdSet.add(op.Order__c);
                productIdSet.add(op.Product__c);
            }
        }
        Map<Id,String> orderVsEmail = new Map<Id,String>();
        for(Order__c order:[SELECT Id,CRM_2_Email__c FROM Order__c WHERE Id IN:orderIdSet]){
            orderVsEmail.put(order.Id, order.CRM_2_Email__c);
        }
        // Code block to process existing Freight requests
        List<Freight_Request__c> existingFRList = [SELECT Id, Order__c, Plant__c,status__c, Order_Value_Exc_Freight1__c, Total_Qty__c, Products__c FROM Freight_Request__c WHERE Order__c IN :orderIdSet];
        system.debug(existingFRList);
        
        for (Freight_Request__c frInstance : existingFRList) {
            if (!orderToPlantToFRMap.containsKey(frInstance.Order__c)) {
                orderToPlantToFRMap.put(frInstance.Order__c, new Map<Id, Freight_Request__c>());
            }
            orderToPlantToFRMap.get(frInstance.Order__c).put(frInstance.Plant__c, frInstance);
        }
        system.debug(orderToPlantToFRMap);
        
        // Code block to process new Freight requests
        Map<Id, Agreement_Product__c> agreementProductMap = new Map<Id, Agreement_Product__c>([
            SELECT Id, Product__c, Product__r.Name,Product__r.Plant__c, Name, Incoterms__c,Payment_Terms_options__c,Master_Agreement__r.Agreement_End_Date__c,Master_Agreement__r.Agreement_Start_Date__c
            FROM Agreement_Product__c
            WHERE Product__c IN :productIdSet
            AND (Master_Agreement__r.Agreement_Start_Date__c <= Today and Master_Agreement__r.Agreement_End_Date__c >= Today)
            AND (Incoterms__c = 'CIF' OR Incoterms__c = 'C&F')
        ]);
        
        Set<Freight_Request__c> frSet = new Set<Freight_Request__c>();
        
        for (Order_Product__c op : newOrderProducts) {
            
            Freight_Request__c frObj;
            
            System.debug('agreementProductMap'+agreementProductMap);
            if (agreementProductMap.containsKey(op.Agreement_Product__c) && agreementProductMap.get(op.Agreement_Product__c).Product__r.Plant__c != null) {
                System.debug('agreementProductMap.containsKey(op.Agreement_Product__c)'+agreementProductMap.containsKey(op.Agreement_Product__c));
                
                if (!orderToPlantToFRMap.containsKey(op.Order__c)) {
                    orderToPlantToFRMap.put(op.Order__c, new Map<Id, Freight_Request__c>());
                }
                system.debug(orderToPlantToFRMap);
                frObj = orderToPlantToFRMap.get(op.Order__c).get(agreementProductMap.get(op.Agreement_Product__c).Product__r.Plant__c);
                
                if (frObj == null) {
                    frObj = new Freight_Request__c();
                    frObj.Order__c = op.Order__c;
                    frObj.CRM_2_Email__c = orderVsEmail.get(op.Order__c);
                    frObj.Plant__c = agreementProductMap.get(op.Agreement_Product__c).Product__r.Plant__c;
                    frObj.Products__c = agreementProductMap.get(op.Agreement_Product__c).Product__r.Name;
                    frObj.Order_Value_Exc_Freight1__c = op.Total_Price__c;
                    frObj.Total_Qty__c = op.Total_Quantities__c;
                } else {
                    // Check if the product name is already in Products__c, and add it only if it's not there
                    List<String> productNames = frObj.Products__c.split(',');
                    Decimal totalPrice = frObj.Order_Value_Exc_Freight1__c;
                    Decimal total_Qty = frObj.Total_Qty__c;
                    if (!productNames.contains(agreementProductMap.get(op.Agreement_Product__c).Product__r.Name)) {
                        frObj.Products__c += ',' + agreementProductMap.get(op.Agreement_Product__c).Product__r.Name;
                    } else {
                        if(oldOPMap != null && oldOPMap.containsKey(op.Id)) {
                            frObj.Order_Value_Exc_Freight1__c = totalPrice - oldOPMap.get(op.Id).Total_Price__c;
                            frObj.Total_Qty__c = total_Qty - oldOPMap.get(op.Id).Total_Quantities__c;
                        }
                    }
                    totalPrice = frObj.Order_Value_Exc_Freight1__c;
                    total_Qty = frObj.Total_Qty__c;
                    frObj.Order_Value_Exc_Freight1__c = totalPrice + op.Total_Price__c;
                    frObj.Total_Qty__c = total_Qty + op.Total_Quantities__c;
                }
                orderToPlantToFRMap.get(op.Order__c).put(frObj.Plant__c, frObj);
                frSet.add(frObj);
            }
        }
        List<Freight_Request__c> frListToInsert = new List<Freight_Request__c>();
        for (id orderId: orderToPlantToFRMap.keySet()) {
            frListToInsert.addAll(orderToPlantToFRMap.get(orderId).Values());
        }
        
        // Insert new Freight request records
        if (!frListToInsert.isEmpty()) {
            upsert frListToInsert;
            insertUpdaterunOnce = false;
            system.debug(frListToInsert);
        }
    }
    
    // Handle delete functionality
    /*public static void processFreightRequestDelete( Map<Id, Order_Product__c> deletedOrderProductMap){
        
        List<Order_Product__c> orderProductNames = [SELECT Order__c, Product__r.Name FROM Order_Product__c WHERE Id IN :deletedOrderProductMap.keySet()];
        //getting OrderIds
        Set<String> orderId = new Set<String>();
        Map<Id, List<Order_Product__c>> orderIdVsOrderProducts = new Map<Id, List<Order_Product__c>>();
        for(Order_Product__c op2: orderProductNames)
        {
            orderId.add(op2.Order__c);
            orderIdVsOrderProducts.put(op2.Order__c, new List<Order_Product__c>());
        }
        System.debug('orderIdVsOrderProducts - ' + orderIdVsOrderProducts);
        //List of remaining Order_Product__c on orders
        List<Order_Product__c> remainingProductsName = [SELECT Order__c, Product__r.Name FROM Order_Product__c WHERE Order__c IN :orderId];
        for (Order_Product__c op : remainingProductsName) {
            orderIdVsOrderProducts.get(op.Order__c).add(op);
        }
        //creating map of Freight_Request__c for id and Products__c field
        List<Freight_Request__c> freightRequestUpdate = [SELECT Id, Order__c, Products__c FROM Freight_Request__c WHERE Order__c=:orderId];
        Map<Id, Freight_Request__c> orderIdVsFreightRequest = new Map<Id, Freight_Request__c>();
        for (Freight_Request__c fr : freightRequestUpdate) {
            orderIdVsFreightRequest.put(fr.Order__c, fr);
        }
        System.debug('orderIdVsFreightRequest - ' + orderIdVsFreightRequest);
        
        
        //List of Freight_Request__c because map cannot be used with DML
        List<Freight_Request__c> freightRequestUpdateList = new List<Freight_Request__c>();
        
        for (Id odId : orderIdVsFreightRequest.keySet()) {
            List<Order_Product__c> deletedOrderProducts = orderIdVsOrderProducts.get(odId);
            Freight_Request__c freightRequestToBeUpdated = orderIdVsFreightRequest.get(odId);
            System.debug('freightRequestToBeUpdated before - ' + freightRequestToBeUpdated);
            for (Order_Product__c orderProduct : deletedOrderProducts) {
                freightRequestToBeUpdated.Products__c = freightRequestToBeUpdated.Products__c.replace(orderProduct.Product__r.Name, '');
            }
            System.debug('freightRequestToBeUpdated after - ' + freightRequestToBeUpdated);
            
            freightRequestUpdateList.add(freightRequestToBeUpdated);
        }
        
        //updating accountList
        
        try{
            Database.update(freightRequestUpdateList);
        }catch(DMLException e){
            system.debug('Freight Request Product Name field failed to update. Error: '+e.getMessage());
        }
    }*/
    
    public static void updateFreightOnOrderProductDeletion(Map<Id, Order_Product__c> tobeDeletedOrderProductMap){
        Set<String> orderId = new Set<String>();
        Set<Id> productIdSet = new Set<Id>();
        List<Freight_Request__c> freightRequestUpdateList = new List<Freight_Request__c>();
        List<Freight_Request__c> freightRequestDeleteList = new List<Freight_Request__c>();
        Map<Id, Freight_Request__c> freightRequestUpdateMap = new Map<Id, Freight_Request__c>();
        Map<Id, Freight_Request__c> freightRequestDeleteMap = new Map<Id, Freight_Request__c>();
        Map<Id, Map<Id, Freight_Request__c>> orderToPlantToFRMap = new Map<Id, Map<Id, Freight_Request__c>>();
        for(Id orderProductId: tobeDeletedOrderProductMap.Keyset())
        {
            orderId.add(tobeDeletedOrderProductMap.get(orderProductId).Order__c);
            productIdSet.add(tobeDeletedOrderProductMap.get(orderProductId).Product__c);
        }
        Map<Id, Product__c> productMap = new Map<Id, Product__c>([ SELECT Id, Plant__c, Name
                                                                  FROM Product__c
                                                                  WHERE Id IN :productIdSet
                                                                  //AND incoterms__c = 'CIF'
                                                                 ]);
        
        // Code block to process new Freight requests
        Map<Id, Agreement_Product__c> agreementProductMap = new Map<Id, Agreement_Product__c>([
            SELECT Id, Product__c, Product__r.Name,Product__r.Plant__c, Name, Incoterms__c,Payment_Terms_options__c
            FROM Agreement_Product__c
            WHERE Product__c IN :productIdSet
            AND (Incoterms__c = 'CIF' OR Incoterms__c = 'C&F')
        ]);
        if(!agreementProductMap.isEmpty()){
            List<Freight_Request__c> existingFRList = [SELECT Id, Order__c, Products__c, Plant__c,Order_Value_Exc_Freight1__c FROM Freight_Request__c WHERE Order__c IN:orderId];
            for (Freight_Request__c frInstance : existingFRList) {
                if (!orderToPlantToFRMap.containsKey(frInstance.Order__c)) {
                    orderToPlantToFRMap.put(frInstance.Order__c, new Map<Id, Freight_Request__c>());
                }
                orderToPlantToFRMap.get(frInstance.Order__c).put(frInstance.Plant__c, frInstance);
            }
            Map<Id, Freight_Request__c> plantToFreightMap;
            String productsStr = '';
            Agreement_Product__c agreementProductInstance = new Agreement_Product__c();
            for(Id orderProductId: tobeDeletedOrderProductMap.Keyset()){
                system.debug('BG >>> orderProductId : '+orderProductId);
                Order_Product__c orderProductInstance = tobeDeletedOrderProductMap.get(orderProductId);
                system.debug('BG >>> orderProductInstance : '+orderProductInstance);
                if (orderToPlantToFRMap.containsKey(orderProductInstance.Order__c)) {
                    plantToFreightMap = orderToPlantToFRMap.get(orderProductInstance.Order__c);
                    if(agreementProductMap.containsKey(orderProductInstance.Agreement_Product__c)) {
                        agreementProductInstance = agreementProductMap.get(orderProductInstance.Agreement_Product__c);
                        Freight_Request__c frObj = new Freight_Request__c ();
                        if (plantToFreightMap.containsKey(agreementProductInstance.Product__r.Plant__c)) {
                            system.debug('BG >>> plantToFreightMap : '+plantToFreightMap);
                            frObj = plantToFreightMap.get(agreementProductInstance.Product__r.Plant__c);
                            frObj.Order_Value_Exc_Freight1__c = frObj.Order_Value_Exc_Freight1__c  - orderProductInstance.Total_Price__c;
                            productsStr = frObj.Products__c;
                            
                            // Remove the product from the comma-separated list without leaving extra commas
                            List<String> productsList = productsStr.split(',');
                            for(Integer i =0; i< productsList.size(); i++){
                                if(productsList[i] == agreementProductInstance.Product__r.Name){
                                    productsList.remove(i);
                                }
                            }
                            //productsList.remove(productInstance.Name);
                            productsStr = String.join(productsList, ',');
                            system.debug('productsStr'+productsStr);
                            frObj.Products__c = productsStr;
                            if(String.isEmpty(productsStr)){
                                freightRequestDeleteMap.put(frObj.Id, frObj);
                                //freightRequestDeleteSet.add(frObj);
                                system.debug('BG >>> if');
                            } else {
                                system.debug('BG >>> else');
                                freightRequestUpdateMap.put(frObj.Id, frObj);
                                //freightRequestUpdateSet.add(frObj);
                            }
                        }
                    }
                }
            }
            
            if(freightRequestUpdateMap.Keyset().size() > 0) {
                freightRequestUpdateList.clear();
                freightRequestUpdateList.addAll(freightRequestUpdateMap.values());
                update freightRequestUpdateList;
                deleterunOnce = false;
            }
            
            if(freightRequestDeleteMap.KeySet().size() > 0) {
                freightRequestDeleteList.clear();
                freightRequestDeleteList.addAll(freightRequestDeleteMap.values());
                delete freightRequestDeleteList;
                deleterunOnce = false;
            }
        }
    }
    
}
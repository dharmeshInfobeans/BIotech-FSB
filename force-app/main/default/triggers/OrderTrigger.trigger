trigger OrderTrigger on Order__c (before update, before insert, after insert, after update) {
    
    if(trigger.isBefore && trigger.IsInsert){
        User currentUser = [SELECT Id, ContactId FROM User WHERE id=: UserInfo.getUserId()];
        if(currentUser.ContactId != null){
            Contact contact = [SELECT Id, AccountId FROM Contact WHERE Id=: currentUser.ContactId];
            Account acc = [SELECT Id,Name,BillingPostalCode,BillingCountry,BillingStreet,BillingState,Contact_Person__c,First_mobile_telephone_no__c,BillingCity,CurrencyIsoCode,CRM_2_Email__c,CRM_Approver__c FROM Account WHERE Id=:contact.AccountId];
            for(Order__c  order: trigger.New){
                order.Account__c = contact.AccountId;
                order.CurrencyIsoCode = acc.CurrencyIsoCode;
                order.CRM_2_Email__c = acc.CRM_2_Email__c;
                                order.CRM_Approver__c = acc.CRM_Approver__c;

                order.order_date__c = date.today();
                //all below fields will be populated by the controller of Activate Order quick action
                //   order.Consignee_City__c=acc.BillingCity;
                // order.Consignee_Country__c=acc.BillingCountry;
                // order.Consignee_Name__c=acc.Name;
                // order.Consignee_Street__c=acc.BillingStreet;
                // order.Consignee_Zip_Postal_Code__c=acc.BillingPostalCode;
                // order.Consignee_State_Province__c=acc.BillingState;
                // order.Telephone__c=acc.First_mobile_telephone_no__c;
                //order.Contact_Person__c=acc.Contact_Person__c;
                system.debug('telephone'+ order.Telephone__c);
                system.debug('telephone'+ order.Contact_Person__c);
                system.debug('telephone'+ acc.Contact_Person__c);
                system.debug('telephone'+ acc.First_mobile_telephone_no__c);
                
            }
        }
    }
    
    
    if(trigger.IsAfter &&  trigger.IsInsert){
        
        
        User currentUser = [SELECT Id, ContactId FROM User WHERE id=: UserInfo.getUserId()];
        Contact contact = new Contact();
        if(currentUser.ContactId != null){
            contact = [SELECT Id, AccountId FROM Contact WHERE Id=: currentUser.ContactId];
        }
        List<Order__c> OldDraftOrders = [SELECT Id, Status__c, Account__c, Buyer_Account__c, Is_it_ok_to_cancel_old_Draft_Orders__c  FROM Order__c WHERE Account__c =: contact.AccountId and id NOT IN:trigger.New and Status__c='Draft'];
        //This list contains a old draft orders present in system other than the current inserted order as this code is executing in after insert.
        System.debug('OldDraftOrders:: '+OldDraftOrders);
        
        List<Order__c> lstOrdersToUpdate = new List<Order__c>();
        for(Order__c order : OldDraftOrders){
            if(order.Status__c == 'Draft' && trigger.New[0].Is_it_ok_to_cancel_old_Draft_Orders__c){
                order.Buyer_Account__c = String.isBlank(order.Buyer_Account__c)?order.Account__c:null;
                order.Status__c = 'Cancel';
            }else{
                trigger.New[0].Is_it_ok_to_cancel_old_Draft_Orders__c.AddError(Label.There_is_already_anopen_order_in_the_system);
            }
            lstOrdersToUpdate.add(order);
        }
        if(lstOrdersToUpdate.size()>0){
            update lstOrdersToUpdate;
        }
    }
    
    if(trigger.IsBefore && trigger.isUpdate){
        Order__c oldOrder = new Order__c();
        Set<Id> PFISet = new Set<Id>();
        Map<Id,Order_Product__c> orderIdVsOrderProductMap = new Map<Id,Order_Product__c>();
        for(Order_Product__c allRelatedProducts: [SELECT Id,Order__c FROM Order_Product__c WHERE Order__c IN :trigger.newMap.keyset() AND Incart__c = true ]){
            orderIdVsOrderProductMap.put(allRelatedProducts.Order__c, allRelatedProducts);
        }
        for(Order__c newOrder : trigger.New){

            if(newOrder.Status__c != trigger.OldMap.get(newOrder.id).Status__c  && newOrder.Status__c == 'Approved') {  // added by Bhakti
                    newOrder.Order_Approval_Date__c=Date.today(); 
           }
            if(newOrder.Customer_Po_No__c != trigger.OldMap.get(newOrder.id).Customer_Po_No__c && newOrder.Status__c == 'Active'){
                newOrder.AddError(Label.For_Active_Order_Customer_Po_No_can_not_be_changed);
            }
            
            if(newOrder.Buyer_Account__c != trigger.OldMap.get(newOrder.id).Buyer_Account__c && newOrder.Status__c == 'Active'){
                newOrder.AddError('Buyer Account Cannot be changed');
            }
            
            if(trigger.OldMap.get(newOrder.id).Status__c == 'Active' && newOrder.Status__c == 'Cancel') {  // added by Bhakti
                newOrder.AddError('Active Order cannot be cancelled');
            }
            if(Trigger.oldmap.get(newOrder.Id).Sales_Contract__c != newOrder.Sales_Contract__c && newOrder.Sales_Contract__c){
                System.debug('Sales contract'+newOrder.Sales_Contract__c);
                PFISet.add(newOrder.Id);
            }
            oldOrder = trigger.oldMap.get(newOrder.Id);
            if(newOrder.Is_Activate__c && newOrder.Status__c != 'Active'){   // added by Bhakti
                if(orderIdVsOrderProductMap.keySet().contains(newOrder.Id)){
                    newOrder.AddError('Some Order Products are in Cart. Please Save the Order Products before Activating Order');
                }else{
                    newOrder.Status__c = 'Sent for Approval';
                    newOrder.Is_Activate__c = false;
                    newOrder.Order_Activation_Date__c = system.today();
                }
            }
            if(newOrder.Status__c != oldOrder.Status__c && newOrder.Status__c == 'Active'){
                newOrder.PFI_Sales_Contract_status__c = 'Sales Contract;Proforma Invoice';
            }
            
        }
        
        /*if(PFISet.size() > 0){
            EmailAlterUtil.processEmail(PFISet, true);
        }*/
        
        
    }
    
    if(trigger.isBefore && trigger.IsUpdate){
        Order__c oldOrder = new Order__c();
        system.debug('BG >>> 1');  //debug
        for(Order__c newOrder : trigger.New) {
            system.debug('BG >>> 2');
            oldOrder = trigger.oldMap.get(newOrder.Id);
            system.debug('BG >>> 3');
            if(newOrder.Integration_enabled_for_Created_By_User__c && newOrder.Status__c == 'Active' && newOrder.Advance_Received__c != oldOrder.Advance_Received__c && newOrder.Advance_Received__c == true) {
                system.debug('BG >>> 3');
                //Order__c orderInstance = [Select id,Order_Creation_Time_Out__c from Order__c where id =:pOrderId ];
                newOrder.Order_Creation_Time_Out__c = false;
                //update orderInstance;
                OrderCreationSAP.sendOrderData(newOrder.Id);
                system.debug('BG >>> 5');
            }
        }
    }
    //   if(trigger.isAfter && trigger.isUpdate){
        //     Set<Id> orderIdsToBlock = new Set<Id>();
        //         for (Order__c order : trigger.New) {
            
            //             List<Order_Product__c> relatedOrderProducts = [SELECT Id FROM Order_Product__c WHERE Order__c = :order.Id AND Incart__c = true ];
            
            //             if (!relatedOrderProducts.isEmpty()) {
                //                 orderIdsToBlock.add(order.Id);
                //              order.AddError('Some Order Products are in Cart. Please Save the Order Products before Activating Order');
            //             }
        //         }
        
        //         if (!orderIdsToBlock.isEmpty()) {
            //             List<Order__c> ordersToBlock = [SELECT Id, Status__c, Is_Activate__c FROM Order__c WHERE Id IN :orderIdsToBlock];
            
            //             for (Order__c order : ordersToBlock) {
                //                 if (order.Status__c != 'Active' || order.Is_Activate__c) {
                    //                     order.Status__c = 'Sent for Approval';
                    //                     order.Is_Activate__c = false;
                    
                //                 }
            //             }
            
            //             if (!ordersToBlock.isEmpty()) {
                //                 //update ordersToBlock;
            //             }
        //      }
    //   }
    
    
}
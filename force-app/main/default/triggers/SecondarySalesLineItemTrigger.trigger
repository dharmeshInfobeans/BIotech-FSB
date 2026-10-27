trigger SecondarySalesLineItemTrigger on Secondary_Sales_Line_Item__c (after update,after insert) {
    Map<String, List<Secondary_Sales_Line_Item__c>> mapOfTypeUpdateLineItem = new Map<String, List<Secondary_Sales_Line_Item__c>>();
    Set<Id> lineItemIdList= new Set<Id>();
    if(Trigger.isAfter && (Trigger.isUpdate || Trigger.isInsert)){
        for(Secondary_Sales_Line_Item__c sslitem : Trigger.new){
            if(((Trigger.isUpdate && sslitem.Type__c != Trigger.oldMap.get(sslitem.id).Type__c) || Trigger.isInsert) && sslitem.Type__c == 'In Transit'){
                if(!mapOfTypeUpdateLineItem.containsKey('In Transit')) mapOfTypeUpdateLineItem.put('In Transit' , new List<Secondary_Sales_Line_Item__c>());
                mapOfTypeUpdateLineItem.get('In Transit').add(sslitem);
                lineItemIdList.add(sslitem.Id);
            }
             if(((Trigger.isUpdate && sslitem.Type__c != Trigger.oldMap.get(sslitem.id).Type__c) || Trigger.isInsert) && sslitem.Type__c == 'Return Goods'){
                if(!mapOfTypeUpdateLineItem.containsKey('Return Goods')) mapOfTypeUpdateLineItem.put('Return Goods' , new List<Secondary_Sales_Line_Item__c>());
                mapOfTypeUpdateLineItem.get('Return Goods').add(sslitem);
                 lineItemIdList.add(sslitem.Id);
            }
        }
    }
    if(!mapOfTypeUpdateLineItem.isEmpty()) SecondarySalesLineItemTriggerHandler.sendTypeUpdateMail(mapOfTypeUpdateLineItem,lineItemIdList);
}
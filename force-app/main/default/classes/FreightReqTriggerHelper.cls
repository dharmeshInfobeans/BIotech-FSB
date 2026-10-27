public class FreightReqTriggerHelper {
    public static void updateLookupOnOp(List<Freight_Request__c> newFreightRequestList) {
        Set<Id> orderIdSet = new Set<Id>();
        Map<Id, Map<Id, Id>> orderToPlantToFreight = new Map<Id, Map<Id, Id>>();
        for (Freight_Request__c frInstance : newFreightRequestList) {
            orderIdSet.add(frInstance.Order__c);
            //productNameSet.add(frInstance.Products__c.split(','));
            Map<Id, Id> plantToFreightMap = new Map<Id, Id>();
            if(orderToPlantToFreight.containsKey(frInstance.Order__c)){
                 plantToFreightMap = orderToPlantToFreight.get(frInstance.Order__c);                 
             }
             if(!plantToFreightMap.containsKey(frInstance.Plant__c)) {
                     plantToFreightMap.put(frInstance.Plant__c,frInstance.Id);
                 }
             orderToPlantToFreight.put(frInstance.Order__c, plantToFreightMap);
        }
        String jsonStr = json.serialize(orderToPlantToFreight);
        system.debug('BG >>> jsonStr :'+jsonStr );

        updateLookupOnOpinfuture(jsonStr);
    }
    //@future(callout=true)
    public static void updateLookupOnOpinfuture(String jsonStr) {
        Map<Id, Map<Id, Id>> orderToPlantToFreight1 = (Map<Id, Map<Id, Id>>)Json.deserialize(jsonStr,Map<Id, Map<Id, Id>>.class);
        List<Order_Product__c> orderProductList = new List<Order_Product__c>();
        List<Order_Product__c> opListtoupdate = new List<Order_Product__c>();
        orderProductList = [SELECT id, Freight_Request__c, Order__c, Product__c,Product__r.Plant__c, Agreement_Product__r.Plant__c FROM Order_Product__c
                            WHERE (Agreement_Product__r.Incoterms__c = 'CIF' OR Agreement_Product__r.Incoterms__c= 'C&F')
                            AND Order__c IN:orderToPlantToFreight1.keyset()
                            ];
                            
         for(Order_Product__c op : orderProductList){
             if(op.Freight_Request__c == null){
                 if(orderToPlantToFreight1 .containsKey(op.Order__c)){
                     if(orderToPlantToFreight1.get(op.Order__c).containsKey(op.Product__r.Plant__c)) {
                         op.Freight_Request__c = orderToPlantToFreight1.get(op.Order__c).get(op.Product__r.Plant__c);
                         opListtoupdate.add(op);
                     }
                 }
             }            
             
         }                         
              update opListtoupdate;              
                            
    }
}
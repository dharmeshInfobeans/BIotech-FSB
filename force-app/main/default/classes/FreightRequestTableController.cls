public class FreightRequestTableController {
    public ID parentObjId { get; set; }
    //public ID orderId = 'a0fBl000000F3X3';

    
    public List<Order_Product__c> getfreightProductList () {

        List<Order_Product__c> freightProductList = new List<Order_Product__c>();
        Map<String, List<Order_Product__c>> finalOrderProductMap = new Map<String, List<Order_Product__c>>();
        Map<String, Map<String, List<Order_Product__c>>> plantToOrderProductMap = new Map<String,Map<String, List<Order_Product__c>>>();
        List<Order_Product__c> finalFreightProductList = new List<Order_Product__c>();
        List<Order_Product__c> responseFreightProductList = new List<Order_Product__c>();
        List<Freight_Request__c> freightRequestList = new List<Freight_Request__c>();
         if (parentObjId != null) {
                freightRequestList = [select id, Products__c from Freight_Request__c  where Order__c =:parentObjId ];
                Set<String> productnameSet = new Set<String>();
                for(Freight_Request__c frObj : freightRequestList) {
                    List<String> productList = new List<String> ();
                    if(frObj.Products__c.contains(',')) {
                        productList = frObj.Products__c.split(',');
                    }
                    else {
                        productList.add(frObj.Products__c);
                    }
                    productnameSet.addAll(productList);               
                }
                
                freightProductList  = [select id, Order__r.Name,Commercial_Quantity__c,FOC_Quantity__c, Model_Txt__c,Product__r.Plant__r.Name, Product__r.Name, Quantity__c,Total_Quantities__c, Is_Parent_Products__c from Order_Product__c where Product__r.Name IN:productnameSet and Order__c = :parentObjId];
                  for(Order_Product__c op : freightProductList){
                  finalOrderProductMap = new Map<String, List<Order_Product__c>>();
                      if(plantToOrderProductMap.containsKey(op.Product__r.Plant__r.Name)) {
                      finalOrderProductMap = plantToOrderProductMap.get(op.Product__r.Plant__r.Name);
                          if(!op.Is_Parent_Products__c){                          
                              
                              if(finalOrderProductMap.containsKey(op.Product__r.Name)){
                                  finalFreightProductList = finalOrderProductMap.get(op.Product__r.Name);
                                  if(finalFreightProductList.size() == 1 && finalFreightProductList[0].Is_Parent_Products__c){
                                     finalFreightProductList.remove(0);
                                     finalOrderProductMap.remove(op.Product__r.Name);
                                  }
                              }
                          finalFreightProductList.add(op);
                          finalOrderProductMap.put(op.Product__r.Name, finalFreightProductList);                          
                          }
                          else {
                              if(!finalOrderProductMap.containsKey(op.Product__r.Name)){
                                  finalOrderProductMap.put(op.Product__r.Name, new List<Order_Product__c> {op});
                              }
                          }
                      }
                      else{
                          finalOrderProductMap.put(op.Product__r.Name, new List<Order_Product__c> {op});
                      }
                      plantToOrderProductMap.put(op.Product__r.Plant__r.Name,finalOrderProductMap);
                      
                  }
          }
          responseFreightProductList.clear();
          for(String str1 : plantToOrderProductMap.keySet()){
          finalOrderProductMap = new Map<String, List<Order_Product__c>>();
              finalOrderProductMap = plantToOrderProductMap.get(str1);
              for(String str2 : finalOrderProductMap.keySet()){
                  responseFreightProductList.addAll(finalOrderProductMap.get(str2));
              }
          }
        
          return responseFreightProductList;
     
    }
    
    

    // Additional logic can be added here if needed.
}
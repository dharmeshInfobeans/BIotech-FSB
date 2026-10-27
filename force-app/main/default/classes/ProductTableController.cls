public without sharing class ProductTableController {
    public Order__c order { get; set; }
    public ID parentObjId { get; set; }
    //public ID orderId = 'a0fBl000000F3X3';

    
    public List<Order_Product__c> getProductOrderList () {
        system.debug('BG >>> ');
        String procudtNameStr = '';
        List<Order_Product__c> orderProductList = new List<Order_Product__c>();
        Map<String, Order_Product__c> orderProductMap = new Map<String, Order_Product__c>();
         if (parentObjId != null) {            
                
                orderProductList = [select id, Order__r.Name,Commercial_Quantity__c,FOC_Quantity__c,Model_Txt__c,Product__r.Name, Quantity__c,Total_Quantities__c,Spherical_Power__c,Agreement_Product__c,Agreement_Product__r.Is_Backup__c from Order_Product__c where Order__c = :parentObjId AND Is_Parent_Products__c = true];
          }
          for(Order_Product__c op : orderProductList){
              
                  system.debug('BG>>> op.Model_Txt__c : '+op.Model_Txt__c);
                  procudtNameStr = op.Product__r.Name+'-'+op.Agreement_Product__r.Is_Backup__c;
                  // add to map
                 /* if(op.Model_Txt__c != null) {
                      procudtNameStr = op.Product__r.Name+'-'+op.Model_Txt__c+'-'+op.Spherical_Power__c+'-'+op.Agreement_Product__r.Is_Backup__c;
                      if(orderProductMap.containsKey(op.Product__r.Name)){
                          orderProductMap.remove(op.Product__r.Name);
                      }
                  }
                  else {
                      procudtNameStr  = op.Product__r.Name+'-'+op.Agreement_Product__r.Is_Backup__c;
                  }*/
                  if(!orderProductMap.containsKey(procudtNameStr)){
                  
                      orderProductMap.put(procudtNameStr,op);
                  }
                                     
          }
          system.debug('BGn >>> orderProductMap.values() : '+orderProductMap.values());
          
          return orderProductMap.values();
     
    }
    
    

    // Additional logic can be added here if needed.
}
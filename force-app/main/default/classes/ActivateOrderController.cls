public with sharing class ActivateOrderController{

    public static String draftStatus = 'Draft';
    public static String freightStatus = 'Freight Submitted';

    @AuraEnabled
    public static List<Account> fetchDetails(String orderId){
        System.debug('recordID' + orderId);
        //List<Shipping_Address__c> shippingAddressLst = new List<Shipping_Address__c>();
        List<Account> consigneeAccountLst = new List<Account>();
        try{
            Order__c orderObj = [SELECT Id, Account__c, Order_Message__c, Consignee_Name__c, Consignee_City__c, Consignee_Street__c, Customer_Po_No__c, Consignee_State_Province__c, Consignee_Country__c, Consignee_Zip_Postal_Code__c, Telephone__c, Contact_Person__c
                                 FROM Order__c
                                 WHERE Id = :orderId];

            Id accId = orderObj.Account__c;
            System.debug('orderObj'+orderObj);

            /*shippingAddressLst = [SELECT Id, Account__c, City__c, Contact_Person__c, Country__c, First_telephone_no__c, Ship_To_Code__c, State_Province__c, Street__c, Zip_Postal_Code__c, Consignee_Account__c, Consignee_Account__r.Name
                                                           FROM Shipping_Address__c
                                                           WHERE Account__c = :accId AND Ship_To_Code__c!= null];*/

            consigneeAccountLst = [SELECT id, Name, Contact_Person__c,Parent_Customer__c, ShippingAddress, ShippingCity, 
                                          ShippingCountry, ShippingGeocodeAccuracy, 
                                          ShippingLatitude, ShippingLongitude, 
                                          ShippingPostalCode, ShippingState, ShippingStreet, SAP_Code__c 
                                   FROM Account
                                   WHERE Parent_Customer__c =:accId AND SAP_Code__c != null AND RecordType.DeveloperName = 'Consignee_Account' ];

         
           // System.debug('shippingAddressLst'+shippingAddressLst);
            System.debug('consigneeAccountLst'+consigneeAccountLst);

            return consigneeAccountLst;
        } catch (Exception e){
            throw e;
        }

       
    }

    @AuraEnabled
    public static Boolean areOrderProductsSelected(String orderId){
        try {
            List<Order_Product__c> orderProducts = [SELECT Id FROM Order_Product__c WHERE Order__c=:orderId];
            return orderProducts.size()>0;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean checkOrderStatusforActivation(String orderId){
        Boolean validStatus = false;  
        try {
            Order__c orderObj = [SELECT Id, Status__c, Consignee_Name__c
                                 FROM Order__c
                                 WHERE Id = :orderId];
            if((orderObj.Status__c.equalsIgnoreCase(draftStatus) || orderObj.Status__c.equalsIgnoreCase(freightStatus)) && orderObj.Consignee_Name__c != null){
                validStatus = true;
            }  
            return validStatus;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Boolean checkOrderStatusforConsignee(String orderId){
        Boolean validStatus = false;  
        try {
            Order__c orderObj = [SELECT Id, Status__c, Consignee_Name__c
                                 FROM Order__c
                                 WHERE Id = :orderId];
            if(orderObj.Status__c.equalsIgnoreCase(draftStatus) && orderObj.Consignee_Name__c == null){
                validStatus = true;
            }  
            return validStatus;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
   @AuraEnabled
    public static Boolean checkFreightRequest(String orderId){
        Boolean validFreightRequest = false;  
        try {
          //  list <Freight_Request__c> requestToUpdate1 = [SELECT Id, Status__c FROM Freight_Request__c WHERE Order__c=:orderId
          //                                              AND Freight_Amount__c = null];
                               list <Split_Order__c> availbleFreight = [Select id,Approx_Freight__c,Status__c from Split_Order__c  WHERE Order__c=:orderId
                                                        AND Approx_Freight__c = null];
                                     
            if(availbleFreight == null || availbleFreight.size() == 0){
                validFreightRequest = true;
            }  
            return validFreightRequest;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }


    @AuraEnabled
    public static Boolean activateOrder(String orderId){
        Boolean orderActivateStatus = false;  
        try {
            Order__c orderObj = [SELECT Id, Status__c
                                 FROM Order__c
                                 WHERE Id = :orderId];
            if(orderObj.Status__c.equalsIgnoreCase(draftStatus) || orderObj.Status__c.equalsIgnoreCase(freightStatus) ){
                orderObj.Is_Activate__c=true;
                update orderObj;
                orderActivateStatus = true;
            }  
            return orderActivateStatus;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String fillOrderConsignDetail(String orderDetail) {
        try {
            // Deserialize the JSON string into an Apex object
            OrderDetailWrapper orderDetailWrapper = (OrderDetailWrapper) JSON.deserialize(orderDetail, OrderDetailWrapper.class);
            
            // Fetch the order record based on the ID
            Order__c orderRecord = new Order__c();

            // Update the order record with the values from the wrapper
            orderRecord.Id=orderDetailWrapper.Id;
            orderRecord.Consignee_Name__c = orderDetailWrapper.consigneeNameSelected;
            orderRecord.Contact_Person__c = orderDetailWrapper.selectedConName;
            orderRecord.Destination__c = orderDetailWrapper.destination;
            orderRecord.Consignee_City__c = orderDetailWrapper.city;
            orderRecord.Consignee_Street__c = orderDetailWrapper.street;
            orderRecord.Consignee_State_Province__c = orderDetailWrapper.state;
            orderRecord.Consignee_Country__c = orderDetailWrapper.country;
            orderRecord.Consignee_Zip_Postal_Code__c = orderDetailWrapper.zipCode;
            orderRecord.Telephone__c = orderDetailWrapper.telephone;
            orderRecord.Dispatch_Through__c = orderDetailWrapper.selectedDispatchMode;
            orderRecord.Consignee_Code__c = orderDetailWrapper.consigneeCode;
            // 
           
        System.debug('orderRecord'+orderRecord);
            // Update the order record
            update orderRecord;
            system.debug('orderRecord'+orderRecord);

            return 'Order updated successfully!';
        } catch (Exception e) {
            // Handle exceptions and return an error message
            throw e;
        }
    }

    @AuraEnabled
public static Map<String, List<Map<String, String>>> getPicklistValues(String objectApiName, List<String> fieldApiNames) {
    Map<String, List<Map<String, String>>> fieldValuesMap = new Map<String, List<Map<String, String>>>();
    
    // Get the SObjectType dynamically
    Schema.DescribeSObjectResult objectDescription = Schema.getGlobalDescribe().get(objectApiName).getDescribe();
    
    for (String fieldApiName : fieldApiNames) {
        // Get the DescribeFieldResult for the specific field
        Schema.DescribeFieldResult fieldDescription = objectDescription.fields.getMap().get(fieldApiName).getDescribe();
        
        // Check if the field is a picklist
        if (fieldDescription.getType() == Schema.DisplayType.PICKLIST) {
            List<Schema.PicklistEntry> picklistValues = fieldDescription.getPicklistValues();
            // Iterate through picklist values and create a map for each value
            List<Map<String, String>> values = new List<Map<String, String>>();
            for (Schema.PicklistEntry picklistEntry : picklistValues) {
                Map<String, String> valueMap = new Map<String, String>();
                valueMap.put('label', picklistEntry.getLabel());
                valueMap.put('value', picklistEntry.getValue());
                values.add(valueMap);
            }
            fieldValuesMap.put(fieldApiName, values);
        }
    }
    System.debug('fieldValuesMap ==> ' + fieldValuesMap);
    return fieldValuesMap;
}
    public class OrderDetailWrapper {
        public String Id;
        public String selectedConName;
        public String destination;
        public String city;
        public String street;
        public String state;
        public String country;
        public String zipCode;
        public String telephone;
        public String selectedDispatchMode;
        public String consigneeNameSelected;
        public String consigneeCode;
    }
       
}
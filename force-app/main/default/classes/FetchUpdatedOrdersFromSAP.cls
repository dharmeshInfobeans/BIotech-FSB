@RestResource(urlMapping='/Orders_Update')
global with sharing class FetchUpdatedOrdersFromSAP {
    public static string fileLog;
    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        //HttpResponse response = new HttpResponse();
        // Deserializing json objects into Order and Its Line Item Wrappers.
        system.debug('BG >>> req.requestBody.toString() : '+req.requestBody);
        List<Order__c> orderList = new List<Order__c>();
        OrderAndOrderLineItemsWrapper.OrderWrapper sapRecord = (OrderAndOrderLineItemsWrapper.OrderWrapper) JSON.deserialize(req.requestBody.toString(), OrderAndOrderLineItemsWrapper.OrderWrapper.class);
        Map<String, OrderLineItem__c> orderLineItemMap = new Map<String, OrderLineItem__c>();
        Map<String, String> responseMap = new Map<String, String>();
        responseMap.put('orderNumber',  sapRecord.orderId);
        System.debug('responseMap'+responseMap);
        
        
        Map<String, Shipment_Detail__c> shipmentMap = new Map<String, Shipment_Detail__c> ();
        
        try {
            System.debug('orderList:21-->'+[SELECT Id, Name, Integration_enabled_for_Created_By_User__c,(SELECT id, Plant__c, Status__c,
                                                                                                         Order_Num_SAP__c,Order__c, CurrencyIsoCode
                                                                                                         FROM Order_Line_Items__r) 
                                            FROM Order__c]);
            orderList  = [SELECT Id, Name, (SELECT id, Plant__c, Status__c,
                                            Order_Num_SAP__c,Order__c, CurrencyIsoCode
                                            FROM Order_Line_Items__r) 
                          FROM Order__c where Name =: sapRecord.orderId AND Integration_enabled_for_Created_By_User__c =true];
            system.debug('BG >>> updatedOrder : '+orderList);
            if(orderList.size() == 0 ){
                responseMap.put('statusCode', String.valueOf(0));
                responseMap.put('message', 'SAP Order not found in the system!');
                RestContext.response.addHeader('Content-Type', 'application/json');
                RestContext.response.responseBody = Blob.valueOf(JSON.serializePretty(responseMap));
                RestContext.response.statusCode = 400; 
            }
            else{
                Order__c updatedOrder = orderList[0];
                for(OrderLineItem__c item : updatedOrder.Order_Line_Items__r) {
                    orderLineItemMap.put(item.Order_Num_SAP__c,item);
                    //orderlineItemIdSet.add(item.Id);
                }
                
                List<Shipment_Detail__c> shipmentlist = [SELECT id, Assigned_Date__c, Assigned_Time__c,
                                                         Deliverd_Time__c, Delivery__c,
                                                         Invoice__c, External_Invoice__c, Order_Line_Item__c,
                                                         Partner_Name__c, SAP_Order_Number__c,
                                                         Shipping_Partner__c, Shipping_Status__c,
                                                         Tracking__c, Name 
                                                         FROM Shipment_Detail__c 
                                                         WHERE SAP_Order_Number__c IN :orderLineItemMap.keySet()];
                system.debug('BG >>> shipmentlist : '+shipmentlist);
                for(Shipment_Detail__c shipmentObj : shipmentlist) {
                    shipmentMap.put(shipmentObj.Delivery__c, shipmentObj);
                }
                
                
                List<OrderLineItem__c> orderLineItemsToBeUpserted = new List<OrderLineItem__c>();
                List<Shipment_Detail__c> shipmentsToBeUpserted = new List<Shipment_Detail__c>();
                
                //for(String key : uniqueIdVsOrderLineItemRecords.keySet()) {
                // List<OrderAndOrderLineItemsWrapper.OrderLineItemsWrapper> orderLineItems = uniqueIdVsOrderLineItemRecords.get(key);
                for (OrderAndOrderLineItemsWrapper.OrderLineItemsWrapper orderLineItemWrapper : sapRecord.orderLineItems) {
                    system.debug('BG >>> orderLineItemWrapper : '+orderLineItemWrapper);
                    OrderLineItem__c orderLineItemRecord = new OrderLineItem__c();
                    if(orderLineItemMap.containsKey(orderLineItemWrapper.orderNumSAP)) {
                        system.debug('BG >>> 1');
                        orderLineItemRecord = orderLineItemMap.get(orderLineItemWrapper.orderNumSAP);
                        //orderLineItemRecord.Plant__c = orderLineItemWrapper.plant;
                        orderLineItemRecord.Status__c = orderLineItemWrapper.status;
                        system.debug('BG >>> 2');
                        //orderLineItemRecord.Order_Num_SAP__c = orderLineItemWrapper.orderNumSAP;
                        //orderLineItemRecord.Order__c = updatedOrder.Id;
                        if(orderLineItemWrapper.shipments != null && orderLineItemWrapper.shipments.size() > 0) {
                            system.debug('BG >>> 3');
                            for(OrderAndOrderLineItemsWrapper.ShipmentWrapper shipment : orderLineItemWrapper.shipments) {
                                Shipment_Detail__c shipmentObj = new Shipment_Detail__c();
                                system.debug('BG >>> 4');
                                if(shipmentMap.containsKey(shipment.deliveryNumber)){
                                    shipmentObj = shipmentMap.get(shipment.deliveryNumber);
                                    system.debug('BG >>> 5');
                                }
                                else {
                                    shipmentObj.Order_Line_Item__c = orderLineItemRecord.Id;
                                    system.debug('BG >>> 6 : '+shipmentObj.Order_Line_Item__c);
                                }
                                system.debug('BG >>> 6 : '+shipmentObj.Order_Line_Item__c);                               
                                shipmentObj.Shipping_Partner__c = shipment.shippingPartner;
                                
                                shipmentObj.Partner_Name__c = shipment.partnerName;
                                shipmentObj.Tracking__c = shipment.trackingNumber;
                                shipmentObj.Delivery__c = shipment.deliveryNumber;
                                shipmentObj.CurrencyIsoCode = orderLineItemRecord.CurrencyIsoCode;
                                shipmentObj.Invoice__c = shipment.invoiceNumber;
                                shipmentObj.External_Invoice__c = shipment.externalInvoiceNumber;
                                shipmentObj.SAP_Order_Number__c = shipment.SAPorderNumber;
                                shipmentObj.Shipping_Status__c = shipment.shipingStatus; //
                                List<String> assignedTimeParts = (shipment.assignedTime != null && shipment.assignedTime.contains(':'))? shipment.assignedTime.split(':') : null;
                                List<String> deliveredTimeParts = (shipment.deliveredTime != null && shipment.deliveredTime.contains(':'))? shipment.deliveredTime.split(':') : null;
                                
                                List<String> assigneDateParts = (shipment.assignedDate != null && shipment.assignedDate.contains('/')) ? shipment.assignedDate.split('/') : null;
                                List<String> deliverdDateParts = (shipment.deliveredDate != null && shipment.deliveredDate.contains('/')) ? shipment.deliveredDate.split('/') : null;
                                shipmentObj.Assigned_Date__c = (shipment.assignedDate != null && shipment.assignedDate.contains('/')) ? Date.valueOf(Integer.valueOf(assigneDateParts[0])+'-'+Integer.valueOf(assigneDateParts[1])+'-'+Integer.valueOf(assigneDateParts[2])) : null;
                                system.debug('BG >>> 1');
                                shipmentObj.Assigned_Time__c = shipment.assignedTime != null ? Time.newInstance(Integer.valueOf(assignedTimeParts[0]), Integer.valueOf(assignedTimeParts[1]), Integer.valueOf(assignedTimeParts[2]), 0) : null;
                                system.debug('BG >>> 1');
                                shipmentObj.Delivered_Date__c = shipment.deliveredDate != null ? Date.valueOf(Integer.valueOf(deliverdDateParts[0])+'-'+Integer.valueOf(deliverdDateParts[1])+'-'+Integer.valueOf(deliverdDateParts[2])) : null;
                                system.debug('BG >>> 1');
                                shipmentObj.Deliverd_Time__c = shipment.deliveredTime != null ? Time.newInstance(Integer.valueOf(deliveredTimeParts[0]), Integer.valueOf(deliveredTimeParts[1]), Integer.valueOf(deliveredTimeParts[2]), 0) : null;
                                
                                system.debug('BG >>> 7');
                                system.debug('BG >>> 8 : '+shipmentObj.Order_Line_Item__c);
                                shipmentsToBeUpserted.add(shipmentObj);
                            }
                        }
                        orderLineItemsToBeUpserted.add(orderLineItemRecord);
                        system.debug('BG >>> shipmentsToBeUpserted : '+shipmentsToBeUpserted);
                        Database.SaveResult[] results = Database.update(orderLineItemsToBeUpserted, false);
                        if(!shipmentsToBeUpserted.isEmpty()) {
                            Database.UpsertResult[] shipmentResults = Database.upsert(shipmentsToBeUpserted, Shipment_Detail__c.Tracking__c, false);
                            system.debug('BG >>> shipmentResults : '+shipmentResults);
                        }
                        RestContext.response.statusCode = 200;
                        RestContext.response.addHeader('Content-Type', 'application/json');
                        responseMap.put('statusCode', String.valueOf(1));
                        responseMap.put('message', 'Order updated successfully');
                        RestContext.response.responseBody = Blob.valueOf(JSON.serializePretty(responseMap));
                        system.debug('BG >>> results : '+results); 
                    }
                    else {
                        responseMap.put('statusCode', String.valueOf(0));
                        responseMap.put('message', 'SAP Order not found in the system!');
                        RestContext.response.addHeader('Content-Type', 'application/json');
                        RestContext.response.responseBody = Blob.valueOf(JSON.serializePretty(responseMap));
                        RestContext.response.statusCode = 400; 
                    }
                }       
                
            } 
            
        }
        catch(Exception e){
            system.debug(e);
            RestContext.response.statusCode = 500;
            RestContext.response.addHeader('Content-Type', 'application/json');
            responseMap.put('statusCode', String.valueOf(0));            
            responseMap.put('message', e.getMessage());
            RestContext.response.responseBody = Blob.valueOf(JSON.serializePretty(responseMap));
        }
        
        //return RestContext.response;
    }
    
    
    @HttpPatch
   
    global static void processData() {
        RestResponse res = RestContext.response;
        RestRequest req = RestContext.request;
        SavePoint sp = Database.setSavepoint();
        try {
            RequestWrapper request = (RequestWrapper) JSON.deserialize(req.requestBody.toString(), RequestWrapper.class);
            system.debug('request--->' + request);
            
            Sample_Request_Header__c scheList;
            if (request.orderId != null) {
                String orderId = String.valueOf(request.orderId);
                if (orderId.startsWith('SMO_')) {
                    orderId = orderId.substring(4); // Removes first 4 characters (SMO_)
                }
                scheList = [SELECT Id, orderId__c, orderNumSAP__c,leads__c,customer__c, orderNumSF__c, SAP_status__c, invoiceNumber__c, 
                            External_Invoice_Number__c, Tracking_Number__c, Delivery_Number__c, Shipping_Partner__c, 
                            Shipping_No__c, SAP_Order_Number__c, Shiping_Status__c, Assigned_Date__c, 
                            Assigned_Time__c 
                            FROM Sample_Request_Header__c WHERE Id =: orderId];
            }
            
            OrderLineItem ord1;
            if (request.orderLineItems != null) {
                ord1 = request.orderLineItems[0];
                if (ord1.orderNumSF != null) {
                    scheList.orderNumSF__c = ord1.orderNumSF;
                }
                if (ord1.orderNumSAP != null) {
                    //scheList.orderNumSAP__c = ord1.orderNumSAP;
                }
                if (ord1.status != null) {
                    //scheList.SAP_status__c = ord1.status;
                    if(ord1.status =='Cancelled'){
                        scheList.Order_cancelled__c = true;
                    }
                }
            }
            
            if (ord1.shipments != null) {
                Shipment sipments = ord1.shipments[0];
                if (sipments.invoiceNumber != null) {
                    scheList.invoiceNumber__c = sipments.invoiceNumber;
                }
                if (sipments.externalInvoiceNumber != null) {
                    scheList.External_Invoice_Number__c = sipments.externalInvoiceNumber;
                }
                if (sipments.trackingNumber != null) {
                    scheList.Tracking_Number__c = sipments.trackingNumber;
                }
                if (sipments.deliveryNumber != null) {
                    scheList.Delivery_Number__c = sipments.deliveryNumber;
                }
                if (sipments.shippingPartner != null) {
                    scheList.Shipping_Partner__c = sipments.shippingPartner;
                }
                if (sipments.shippingNo != null) {
                    scheList.Shipping_No__c = sipments.shippingNo;
                }
                if (sipments.SAPorderNumber != null) {
                    scheList.SAP_Order_Number__c = sipments.SAPorderNumber;
                }
                if (sipments.shipingStatus != null) {
                    scheList.Shiping_Status__c = sipments.shipingStatus;
                }
                if (sipments.assignedDate != null) {
                    scheList.Assigned_Date__c = sipments.assignedDate;
                }
                if (sipments.assignedTime != null) {
                    scheList.Assigned_Time__c = sipments.assignedTime;
                }
            }
            
            update scheList;
            
            
            
            res = setResponse('Order updates successfully.', 200, 'success');
            
        } catch (Exception e) {
            Database.rollback(sp);
            String errorMessage = e.getMessage() + ' at line no: ' + e.getLineNumber();
            fileLog += '\n=======================================\n Error Details\n\n' + errorMessage;
            System.debug('Error in upserting: ' + errorMessage);
            res = setResponse(errorMessage, 500, 'error');
        }
    }
    
    private static RestResponse setResponse(String message, Integer statusCode, String status) {
        RestResponse res = RestContext.response;
        Map<String, Object> tempMap = new Map<String, Object>{
            'message' => message,
                'status'  => status
                };
                    res.statusCode = statusCode;
        res.addHeader('Content-Type', 'application/json');
        res.responseBody = BLOB.valueOf(JSON.serialize(tempMap));
        return res;
    }
    
    public class RequestWrapper {
        public String orderId;
        public List<OrderLineItem> orderLineItems;
    }
    
    public class OrderLineItem {
        public String orderNumSF;
        public String orderNumSAP;
        public String status;
        public List<Shipment> shipments;
    }
    
    public class Shipment {
        public String invoiceNumber;
        public String externalInvoiceNumber;
        public String trackingNumber;
        public String deliveryNumber;
        public String shippingPartner;
        public String partnerName;
        public String shippingNo;
        public String SAPorderNumber;
        public String shipingStatus;
        public String assignedDate;
        public String assignedTime;
    }
    
}
@RestResource(urlMapping='/Orders_Sync')
global class OrderSyncUpFromSAP {
    public static string fileLog;
    
    @HttpPost
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
                    scheList.orderNumSAP__c = ord1.orderNumSAP;
                }
                if (ord1.status != null) {
                    scheList.SAP_status__c = ord1.status;
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
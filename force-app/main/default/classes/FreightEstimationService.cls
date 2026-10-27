public with sharing class FreightEstimationService {

    // ======================
    // Main Method
    // ======================
    @AuraEnabled
    public static String getNewEstimation(
        String splitOrderNumber,
        String plantCode,
        List<OrderProductWrapper> orderProducts
    ) {
        System.debug('splitOrderNumber: ' + splitOrderNumber);
        System.debug('orderProducts: ' + JSON.serialize(orderProducts));

        if (orderProducts == null || orderProducts.isEmpty()) {
            throw new AuraHandledException('No Order Products provided.');
        }

        // Build request body using passed products and quantities
        RequestWrapper requestBody = buildRequestBody(splitOrderNumber, plantCode, orderProducts);

        // Prepare HTTP request
        SAP_Creds__c credential = SAP_Creds__c.getValues('SAP_Fright_Estimation');
        HttpRequest req = new HttpRequest();
        req.setEndpoint(credential.Endpoint__c);
        req.setMethod('POST');

        // Basic Authentication
        String username = credential.Username__c;
        String password = credential.Password__c;
        Blob headerValue = Blob.valueOf(username + ':' + password);
        String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);

        // Set headers
        req.setHeader('Authorization', authorizationHeader);
        req.setHeader('Source', 'SF');
        req.setHeader('Content-Type', 'application/json');

        // Serialize body
        String body = JSON.serialize(requestBody);
        System.debug('Request Body JSON: ' + body);
        req.setBody(body);
        req.setTimeout(120000);

        // Send HTTP request
        Http http = new Http();
        HttpResponse res;
        try {
            res = http.send(req);
            System.debug('res-->'+res);
                    System.debug('FreightEstimationService --> Response Body: ' + res.getBody());

        } catch (System.CalloutException e) {
            System.debug('FreightEstimationService --> Exception: ' + e);
            throw new AuraHandledException('Callout error: ' + e.getMessage());
        }

        if (res.getStatusCode() != 200) {
              String responseBody = res.getBody();
        String emailSubject = 'SAP Freight Estimation HTTP Failure | Split Order ' + splitOrderNumber;
        String emailBody = 'HTTP error occurred while calling SAP Freight Estimation API.\n\n' +
            'Split Order Number: ' + splitOrderNumber + '\n' +
            'Plant Code        : ' + plantCode + '\n\n' +
            'HTTP Status       : ' + res.getStatus() + '\n' +
            'Status Code       : ' + res.getStatusCode() + '\n' +
            'Response Body     : ' + responseBody + '\n\n' +
            'Request Payload:\n' + body + '\n\n' +
            'Timestamp:\n' + String.valueOf(System.now());

                // Send error email
                try {
            ReusableUtilityClass.sendSapErrorEmail(emailSubject, emailBody);
                } catch (Exception e) {
                    System.debug('Error while sending SAP error email: ' + e.getMessage());
                    
                }
                
            throw new AuraHandledException('Error from API: ' + res.getBody());
        }

        return res.getBody();
    }

    // ======================
    // Helper: Build Request Body
    // ======================
    private static RequestWrapper buildRequestBody(
        String splitOrderNumber,
        String plantCode,
        List<OrderProductWrapper> orderProducts
    ) {
        // Query only for static info needed (Customer SAP Code, Order ID)
        Set<Id> orderProductIds = new Set<Id>();
        for (OrderProductWrapper p : orderProducts) {
            orderProductIds.add(p.id);
        }

        List<Order_Product__c> queriedProducts = [
            SELECT Id, Order__r.Account__r.SAP_Code__c, Order__c
            FROM Order_Product__c
            WHERE Id IN :orderProductIds
            LIMIT 1
        ];

        if (queriedProducts.isEmpty()) {
            throw new AuraHandledException('No valid Order Products found.');
        }

        Id orderId = queriedProducts[0].Order__c;
        String customerCode = queriedProducts[0].Order__r.Account__r.SAP_Code__c;

        Map<Id, String> orderIdVsSAPMaterialCode =
            CalculateSAPMaterialCode.processOrderProductsByOrderId(orderId);

        // Build RequestWrapper
        RequestWrapper request = new RequestWrapper();
        request.CustomerCode = customerCode;
        request.TransactionMode = 'All';
        request.PlantCode = plantCode;
        request.AdditionalField1 = splitOrderNumber;

        request.Materials = new List<MaterialWrapper>();

        for (OrderProductWrapper op : orderProducts) {
            MaterialWrapper mw = new MaterialWrapper();
            mw.OrderProductId = op.id;
            mw.Code = orderIdVsSAPMaterialCode.get(op.id);
            mw.Quantity = Integer.valueOf(op.quantity);
            request.Materials.add(mw);
        }

        return request;
    }

    // ======================
    // Wrapper Classes 
    // ======================
    public class OrderProductWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public Integer quantity { get; set; }
    }

    public class MaterialWrapper {
        public String OrderProductId;
        public String Code;
        public Integer Quantity;
    }

    public class RequestWrapper {
        public String CustomerCode;
        public String TransactionMode;
        public String PlantCode;
        public List<MaterialWrapper> Materials;
        public String AdditionalField1;
        public String AdditionalField2;
        public String AdditionalField3;
        public String AdditionalField4;
        public String AdditionalField5;
    }
}
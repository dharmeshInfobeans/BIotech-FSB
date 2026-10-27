public with sharing class FreightPDFDownloader {

    // 🔹 Wrapper for API Request
    public class FreightRequest {
        public String RFQNumber;
        public Integer EstimationId;
        public String TransactionMode;
    }

    @AuraEnabled(cacheable=false)
    public static String downloadFreightPDF(Id SplitOrderId) {
        System.debug('SplitOrderId'+SplitOrderId);
       // try {
            // 🔹 Identify object
            String objectApiName = SplitOrderId.getSObjectType()
                .getDescribe()
                .getName();
            System.debug('Object API Name: ' + objectApiName);

            if (objectApiName != 'OrderLineItem__c') {
                throw new AuraHandledException('Invalid record type.');
            }

            // 🔹 Query Order Line Item
            OrderLineItem__c actualSplitOrder = [
                SELECT Id,
                       RFQNumber__c,
                       EstimationId__c,
                       Transport_Mode__c
                FROM OrderLineItem__c
                WHERE Id = :SplitOrderId
                LIMIT 1
            ];
        System.debug('actualSplitOrder'+actualSplitOrder);

            // 🔹 Validate mandatory fields
            if (String.isBlank(actualSplitOrder.RFQNumber__c) ||
                actualSplitOrder.EstimationId__c == null ||
                String.isBlank(actualSplitOrder.Transport_Mode__c)) {
                throw new AuraHandledException(
                    'Missing required fields (RFQ Number, Estimation ID, or Transport Mode).'
                );
            }

            // 🔹 Prepare request payload
            FreightRequest reqWrapper = new FreightRequest();
            reqWrapper.RFQNumber = actualSplitOrder.RFQNumber__c;
            reqWrapper.EstimationId = Integer.valueOf(actualSplitOrder.EstimationId__c);
            reqWrapper.TransactionMode = actualSplitOrder.Transport_Mode__c;

            String bodyStr = JSON.serialize(reqWrapper);
            System.debug('Request Body: ' + bodyStr);

            // 🔹 Get SAP credentials
            SAP_Creds__c credential =
                SAP_Creds__c.getValues('SAP_GET_Freight_PDF');

            HttpRequest req = new HttpRequest();
            req.setEndpoint(credential.Endpoint__c);
            req.setMethod('POST');

            // 🔹 Headers
            String auth = credential.Username__c + ':' + credential.Password__c;
            req.setHeader(
                'Authorization',
                'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(auth))
            );
            req.setHeader('Source', 'SF');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(bodyStr);

            // 🔹 Callout
            Http http = new Http();
            HttpResponse res = http.send(req);

            System.debug('Response Status: ' + res.getStatus());
            System.debug('Response Body: ' + res.getBody());

            return res.getBody();

       /* } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }*/
    }
}
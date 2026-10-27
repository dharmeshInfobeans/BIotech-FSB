public class GenerateInvoicePDFController {
    
    public class InvoiceData {
            @AuraEnabled public Integer status_Code { get; set; }
            @AuraEnabled public String message { get; set; }
            @AuraEnabled public String base64 { get; set; }
        }
    
    @AuraEnabled(cacheable=true)
    public static InvoiceData getBase64String(String recordId){
        
        //getting credentials from custom settings
        SAP_Creds__c sapCreds = SAP_Creds__c.getValues('SAP_InvoicePDFData');
        
        //generateInvoicePDF callout request creation ---------------
        
        HttpRequest req = new HttpRequest();
        HttpResponse res = new HttpResponse();
        Http http = new Http();
        
        // Set the endpoint URL
        String endpoint = sapCreds.Endpoint__c;
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        
        // Encode the Basic Authentication credentials
        String username = sapCreds.Username__c;    
        String password =  sapCreds.Password__c;
        Blob headerValue = Blob.valueOf(username + ':' + password);
        String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
        req.setHeader('Authorization', authorizationHeader);
        String salesforceOrderNumber;
        String sapOrderNumber;
        String invoiceNumber;    

        //querying the shipment details using the recordId
        try {
            Shipment_Detail__c record = [SELECT SAP_Order_Number__c, Invoice__c,SF_Number__c FROM Shipment_Detail__c WHERE Id=:recordId WITH SECURITY_ENFORCED];
            system.debug('BG >>> record : '+record);

            salesforceOrderNumber = record.SF_Number__c; // taken out from SOQL queery-> SF_Number__c,
            sapOrderNumber = record.SAP_Order_Number__c;
            invoiceNumber = record.Invoice__c;  

        } catch (Exception e) {
            throw e;
        }

        // Set the Content-Type header
        req.setHeader('Content-Type', 'application/json');
        
        // Define your JSON payload
        String bodyStr = '{\"Records\":[{\"SalesForce_Order_Number\":\"'+salesforceOrderNumber+'\",\"SAP_Order_Number\":\"'+sapOrderNumber+'\",\"Invoice_Number\":\"'+invoiceNumber+'\"}]}';
       // String bodyStr = '{"Records":[{"SalesForce_Order_Number":"'+salesforceOrderNumber+'","SAP_Order_Number":"'+sapOrderNumber+'","Invoice_Number":"'+invoiceNumber+'"}]}';
        //String bodyStr = '{\"Records\":[{\"SalesForce_Order_Number\":\"OSF00010003\",\"SAP_Order_Number\":\"3130006843\",\"Invoice_Number\":\"90028838\"}]}';
        
        // Set the request body
        if(!Test.isRunningTest()){
        req.setBody(bodyStr);
        }else{
                    String bodyStr1= '{\"Records\":[{\"SalesForce_Order_Number\":\"OSF00010003\",\"SAP_Order_Number\":\"3130006843\",\"Invoice_Number\":\"90028838\"}]}';

        }
        // Calculate and set the Content-Length header
        req.setHeader('Content-Length', String.valueOf(Blob.valueOf(bodyStr).size()));
        
        // Set a longer timeout (in milliseconds)
        req.setTimeout(60000); // 60 seconds
        
        // Debugging information (remove in production)
        system.debug('BG >>> req : ' + req.getHeader('Authorization'));
        system.debug('BG >>> req : ' + req.getHeader('Content-Type'));
        system.debug('BG >>> req : ' + req.getHeader('Content-Length'));
        system.debug('BG >>> req : ' + req.getEndpoint());
        system.debug('BG >>> req : ' + String.valueOf(req));
        system.debug('BG >>> req : ' + req.getBody());
        
        try {
            
            res = http.send(req);
            
            // Debugging the response (remove in production)
            system.debug('BG >>> res : ' + res.getBody());
            
            //generateInvoicePDF callout response ---------------
            
            String responseString = res.getBody();
            system.debug('BG >>> responseString : ' +responseString);
            
            //initializing the invoice Map with Invoice Wrapper class instance
            Map<String, InvoiceData> invoiceMap = (Map<String, InvoiceData>)JSON.deserialize(responseString, Map<String, InvoiceData>.class);
                       
            InvoiceData invoice = new InvoiceData();
            
            invoice.status_Code = invoiceMap.get('Records').status_Code;
            invoice.message = invoiceMap.get('Records').message;
            invoice.base64 = invoiceMap.get('Records').base64;
            System.debug('Status Code: ' + invoice.status_Code);
            System.debug('Message: ' + invoice.message);
            System.debug('Base64: ' + invoice.base64);
            
            //returning the Invoice wrapper class instance from invoice Map
            return invoice;
            
        } catch (Exception e) {
            throw e;
        }
    }
}
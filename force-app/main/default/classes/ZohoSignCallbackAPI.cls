@RestResource(urlMapping='/zoho/signcallback/*')
global with sharing class ZohoSignCallbackAPI {

    global class CallbackResponse {
        public Boolean success;
        public String message;
        public String requestId;
    }

    @HttpPost
    global static String receiveCallback() {
        CallbackResponse response = new CallbackResponse();
        try {
            String body = RestContext.request.requestBody != null ? RestContext.request.requestBody.toString() : '';
            if (String.isBlank(body)) {
                RestContext.response.statusCode = 400;
                response.success = false;
                response.message = 'Empty payload received';
                return JSON.serialize(response);
            }

            Map<String, Object> payload       = (Map<String, Object>) JSON.deserializeUntyped(body);
            Map<String, Object> notifications = (Map<String, Object>) payload.get('notifications');
            Map<String, Object> requestsObj   = (Map<String, Object>) payload.get('requests');

            if (requestsObj == null) {
                RestContext.response.statusCode = 400;
                response.success = false;
                response.message = 'Missing requests object in payload';
                return JSON.serialize(response);
            }

            String requestId     = (String) requestsObj.get('request_id');
            String requestStatus = (String) requestsObj.get('request_status');
            String operationType = notifications != null ? (String) notifications.get('operation_type') : null;

            if (String.isBlank(requestId)) {
                RestContext.response.statusCode = 400;
                response.success = false;
                response.message = 'Missing request_id in payload';
                return JSON.serialize(response);
            }

            List<Customer_Ledger__c> ledgers = [
                SELECT Id, Status__c, Sign_Status__c, Signed_Date__c
                FROM Customer_Ledger__c
                WHERE Zoho_Request_Id__c = :requestId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (ledgers.isEmpty()) {
                RestContext.response.statusCode = 404;
                response.success = false;
                response.message = 'No Customer Ledger found for Request Id: ' + requestId;
                response.requestId = requestId;
                return JSON.serialize(response);
            }

            Customer_Ledger__c ledger = ledgers[0];
            String effectiveStatus = String.isNotBlank(requestStatus) ? requestStatus : operationType;
            ledger.Status__c = effectiveStatus;

            Boolean isCompleted = (String.isNotBlank(requestStatus) && requestStatus.equalsIgnoreCase('completed'))
                               || (String.isNotBlank(operationType) && operationType.equalsIgnoreCase('RequestCompleted'));

            if (isCompleted) {
                ledger.Signed_Date__c = System.now();
                ledger.Sign_Status__c = 'SIGNED';
                ledger.Status__c      = 'Completed';
            }

            update ledger;

            response.success   = true;
            response.message   = 'Customer Ledger updated successfully.';
            response.requestId = requestId;
            return JSON.serialize(response);

        } catch (Exception e) {
            RestContext.response.statusCode = 500;
            response.success = false;
            response.message = e.getMessage();
            return JSON.serialize(response);
        }
    }
}
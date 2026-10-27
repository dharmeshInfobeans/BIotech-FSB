public with sharing class ZohoSignService {

    public class ZohoResponse {
        public String requestId;
        public String actionId;
        public Integer httpStatusCode;
    }

    public class SubmitException extends Exception {
        public Integer statusCode;
    }

    public static void createAndSendRequest(Id accountId, Blob pdfBlob, String fileName, String recipientName, String recipientEmail) {
        // Query latest content version for Queueable ref
        List<ContentDocumentLink> links = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :accountId ORDER BY SystemModstamp DESC LIMIT 1];
        if (links.isEmpty()) return;

        ContentVersion cv = [SELECT Id FROM ContentVersion WHERE ContentDocumentId = :links[0].ContentDocumentId AND IsLatest = true LIMIT 1];
        List<ZohoSignQueueable.SignRef> refs = new List<ZohoSignQueueable.SignRef>{
            new ZohoSignQueueable.SignRef(accountId, cv.Id, fileName, recipientName, recipientEmail)
        };
        System.enqueueJob(new ZohoSignQueueable(refs, 0));
    }

    public static void processRequest(Id accountId, Blob pdfBlob, String fileName, String recipientName, String recipientEmail) {
        Customer_Ledger__c ledger = getLatestLedger(accountId);

        // Uses your existing Custom Setting / Metadata setup
        Zoho_Settings__c cs = Zoho_Settings__c.getOrgDefaults();
        String accessToken  = cs != null ? cs.Access_Token__c : null;

        if (String.isBlank(accessToken)) {
            throw new CalloutException('Access Token not available in Zoho configuration.');
        }

        // File size guard (3.5MB limit to prevent Heap LimitException)
        if (pdfBlob != null && pdfBlob.size() > 3670016) {
            throw new CalloutException('File size exceeds maximum supported limit for Zoho Sign upload (3.5MB).');
        }

        Boolean hasExistingRequest = (ledger != null && String.isNotBlank(ledger.Zoho_Request_Id__c));
        ZohoResponse resp = new ZohoResponse();
        String failureStage;
        String failureMessage;

        try {
            if (hasExistingRequest) {
                resp.requestId      = ledger.Zoho_Request_Id__c;
                resp.actionId       = ledger.Zoho_Action_Id__c;
                resp.httpStatusCode = 200;
            } else {
                resp = uploadDocument(pdfBlob, fileName, recipientName, recipientEmail, accessToken);
                if (resp == null || String.isBlank(resp.requestId)) {
                    failureStage   = 'Upload';
                    failureMessage = 'Upload did not return a request ID.';
                }
            }

            if (failureStage == null && String.isNotBlank(resp.requestId)) {
                String newOwnerEmail = cs.Owner_Configuration_Email__c;
                if (String.isNotBlank(newOwnerEmail) && !hasExistingRequest) {
                    try {
                        changeOwnership(resp.requestId, accessToken, newOwnerEmail);
                    } catch (Exception e) {
                        failureStage   = 'ChangeOwnership';
                        failureMessage = e.getMessage();
                    }
                }

                if (failureStage == null) {
                    try {
                        resp.httpStatusCode = submitRequest(resp.requestId, accessToken);
                    } catch (SubmitException se) {
                        failureStage        = 'Submit';
                        failureMessage      = se.getMessage();
                        resp.httpStatusCode = se.statusCode;
                    } catch (Exception e) {
                        failureStage   = 'Submit';
                        failureMessage = e.getMessage();
                    }
                }
            }

        } catch (Exception e) {
            failureStage   = hasExistingRequest ? 'Submit' : 'Upload';
            failureMessage = e.getMessage();
        }

        persistOutcome(accountId, ledger, resp, failureStage, failureMessage);
    }

    private static ZohoResponse uploadDocument(Blob pdfBlob, String fileName, String recipientName, String recipientEmail, String accessToken) {
        Map<String, Object> action = new Map<String, Object>{
            'action_type'      => 'SIGN',
            'recipient_email'  => recipientEmail,
            'recipient_name'   => recipientName,
            'signing_order'    => 0,
            'verify_recipient' => false
        };

        String cleanFileName = fileName.replace('.pdf', '');
        String dataJson = JSON.serialize(new Map<String, Object>{
            'requests' => new Map<String, Object>{
                'request_name'  => cleanFileName,
                'description'   => 'Ledger document for signing',
                'is_sequential' => true,
                'actions'       => new List<Object>{ action }
            }
        });

        String boundary = '----ZohoBoundary' + String.valueOf(Crypto.getRandomInteger());
        String dataPart = '--' + boundary + '\r\nContent-Disposition: form-data; name="data"\r\nContent-Type: application/json\r\n\r\n' + dataJson + '\r\n';
        Blob filePartBlob = Blob.valueOf('--' + boundary + '\r\nContent-Disposition: form-data; name="file"; filename="' + fileName + '"\r\nContent-Type: application/pdf\r\n\r\n');
        String endPart = '\r\n--' + boundary + '--\r\n';

        String bodyHex = EncodingUtil.convertToHex(Blob.valueOf(dataPart)) 
                       + EncodingUtil.convertToHex(filePartBlob)
                       + EncodingUtil.convertToHex(pdfBlob) 
                       + EncodingUtil.convertToHex(Blob.valueOf(endPart));

        Blob bodyBlob = EncodingUtil.convertFromHex(bodyHex);

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Zoho_Sign/api/v1/requests');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Zoho-oauthtoken ' + accessToken);
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        req.setBodyAsBlob(bodyBlob);
        req.setTimeout(60000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() >= 300) {
            throw new CalloutException('Upload Failed: (' + res.getStatusCode() + ') ' + res.getBody());
        }

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        ZohoResponse zr = new ZohoResponse();
        zr.httpStatusCode = res.getStatusCode();

        if (result.containsKey('requests')) {
            Map<String, Object> requestObj = (Map<String, Object>) result.get('requests');
            zr.requestId = (String) requestObj.get('request_id');
            List<Object> actions = (List<Object>) requestObj.get('actions');
            if (actions != null && !actions.isEmpty()) {
                zr.actionId = (String)((Map<String, Object>) actions[0]).get('action_id');
            }
        }
        return zr;
    }

    private static void changeOwnership(String requestId, String accessToken, String newOwnerEmail) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Zoho_Sign/api/v1/requests/' + requestId + '/changeownership?email_id=' + EncodingUtil.urlEncode(newOwnerEmail, 'UTF-8'));
        req.setMethod('PUT');
        req.setHeader('Authorization', 'Zoho-oauthtoken ' + accessToken);
        req.setHeader('Accept', 'application/json');
        req.setTimeout(60000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() >= 300) {
            throw new CalloutException('Change Ownership Failed: ' + res.getBody());
        }
    }

    private static Integer submitRequest(String requestId, String accessToken) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Zoho_Sign/api/v1/requests/' + requestId + '/submit');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Zoho-oauthtoken ' + accessToken);
        req.setTimeout(60000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() >= 300) {
            SubmitException se = new SubmitException('Submit Failed: ' + res.getBody());
            se.statusCode = res.getStatusCode();
            throw se;
        }
        return res.getStatusCode();
    }

    private static Customer_Ledger__c getLatestLedger(Id accountId) {
        List<Customer_Ledger__c> ledgers = [
            SELECT Id, Zoho_Request_Id__c, Zoho_Action_Id__c,Status__c,Statement_Date__c,
            From_Date__c,
            Quarter__c
            FROM Customer_Ledger__c
            WHERE Account__c = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return ledgers.isEmpty() ? null : ledgers[0];
    }

    private static void persistOutcome(Id accountId, Customer_Ledger__c ledger, ZohoResponse resp, String failureStage, String failureMessage) {
        if (ledger == null) return;

        Boolean fullySucceeded = (failureStage == null && resp != null && resp.httpStatusCode == 200);

        if (resp != null && String.isNotBlank(resp.requestId)) {
            ledger.Zoho_Request_Id__c = resp.requestId;
            ledger.Zoho_Action_Id__c  = resp.actionId;
        }
        ledger.Status__c = fullySucceeded ? 'Sent' : 'Fetch Failed';

        Database.update(ledger, false);

        Customer_Ledger_Log__c log = new Customer_Ledger_Log__c(
            Customer_Ledger__c      = ledger.Id,
            Account__c              = accountId,
            Statement_Date__c       = ledger.Statement_Date__c,
            From_Date__c            = ledger.From_Date__c,
            Quarter__c              = ledger.Quarter__c,
            Status__c               = fullySucceeded ? 'Success' : 'Failed',
            Error_Details__c        = failureMessage,
            Zoho_Sign_Request_ID__c = resp != null ? resp.requestId : null,
            SAP_Response_Status__c  = failureStage == null ? 'Submitted' : 'Failed',
            HTTP_Status_Code__c     = (resp != null && resp.httpStatusCode != null) ? String.valueOf(resp.httpStatusCode) : null,
            Log_Timestamp__c        = System.now(),
            Performed_By__c         = UserInfo.getUserId(),
            Triggered_By__c         = 'Zoho'
        );
        Database.insert(log, false);
    }
}
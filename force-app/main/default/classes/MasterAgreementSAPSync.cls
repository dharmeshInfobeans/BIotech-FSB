public class MasterAgreementSAPSync {
    public static String maNumberStr { get; set; }
    public static Map<String, String> MANumberVSError { get; set; }
    
    // Main entry point - receives bulk but processes one-by-one asynchronously
    public static void sendExportAgreementData(Set<Id> masterAgreementIds) {
        for (Id maId : masterAgreementIds) {
            System.debug('Sending data for Master Agreement Id: ' + maId);
            MasterAgreementSAPSync.sendSingleAgreementToSAP(maId);
        }
    }
    
    // Future method to isolate callouts per agreement
    @future(callout=true)
    public static void sendSingleAgreementToSAP(Id masterAgreementId) {
        System.debug('Processing single Master Agreement Id: ' + masterAgreementId);
        processExportAgreementDataSingle(masterAgreementId);
    }
    
    //this is method is called from lwc to sync manually
    @AuraEnabled
    public static ResponseWrapper syncFromLWC(Id masterAgreementId) {
        return processExportAgreementDataSingle(masterAgreementId);
    }
    
    // Core logic: 1 Master Agreement -> 1 SAP Call
    public static ResponseWrapper processExportAgreementDataSingle(Id masterAgreementId){
        MANumberVSError = new Map<String, String>();
        
        // Fetching Master Agreement
        System.debug('Fetching Master Agreement with Id: ' + masterAgreementId);
        List<Master_Agreement__c> masterAgreements = [
            SELECT Id, Name, Account__r.Name, Agreement_Number__c, Account__r.SAP_Code__c,
            Agreement_Start_Date__c, Agreement_End_Date__c, Syned_To_SAP__c
            FROM Master_Agreement__c
            WHERE Id = :masterAgreementId
        ];
        
        if (masterAgreements.isEmpty()) {
            System.debug('No Master Agreement found for Id: ' + masterAgreementId);
            ResponseWrapper res = new ResponseWrapper();
            res.Status = 0;
            res.Message = 'Master Agreement not found';
            return res;
        }
        Master_Agreement__c ma = masterAgreements[0];
        System.debug('Master Agreement found: ' + ma);
        
        // Fetching Agreement Products
        System.debug('Fetching Agreement Products for Master Agreement Id: ' + masterAgreementId);
        List<Agreement_Product__c> agreementProducts = [
            SELECT Master_Agreement__c, Product__r.Dummy_Product_Code__c, Price__c, CurrencyIsoCode
            FROM Agreement_Product__c
            WHERE Master_Agreement__c = :masterAgreementId
        ];
        System.debug('Agreement Products retrieved: ' + agreementProducts.size());
        
        List<AgreementItem> items = new List<AgreementItem>();
        for (Agreement_Product__c ap : agreementProducts) {
            AgreementItem item = new AgreementItem();
            item.DummyCode = ap.Product__r.Dummy_Product_Code__c;
            item.Price = String.valueOf(ap.Price__c);
            item.PriceUnit = ap.CurrencyIsoCode;
            items.add(item);
        }
        
        Record record = new Record();
        record.MasterAgreementNumber = ma.Name;
        record.AgreementNumber = ma.Agreement_Number__c;
        record.CustomerNumber = ma.Account__r.SAP_Code__c;
        record.ValidFromDate = String.valueOf(ma.Agreement_Start_Date__c);
        record.ValidToDate = String.valueOf(ma.Agreement_End_Date__c);
        record.AgreementItems = items;
        
        RequestWrapper request = new RequestWrapper();
        request.Record = new List<Record> { record };
            
            // Fetching SAP credentials
            System.debug('Fetching SAP credentials.');
        SAP_Creds__c cred = [SELECT Username__c, Password__c, Endpoint__c FROM SAP_Creds__c WHERE Name = 'SAP_Export_Agreement' LIMIT 1];
        if (cred == null || String.isEmpty(cred.Username__c) || String.isEmpty(cred.Password__c)) {
            System.debug('Missing or invalid SAP credentials.');
            ResponseWrapper res = new ResponseWrapper();
            res.Status = 0;
            res.Message = 'Missing or invalid SAP credentials.';
            return res;        }
        
        // Sending HTTP request
        HttpRequest httpReq = new HttpRequest();
        httpReq.setEndpoint(cred.Endpoint__c);
        httpReq.setMethod('POST');
        httpReq.setHeader('Content-Type', 'application/json');
        httpReq.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(cred.Username__c + ':' + cred.Password__c)));
        httpReq.setBody(JSON.serialize(request));
        // Increase timeout (max 120000 ms = 120 sec)
httpReq.setTimeout(120000);
        System.debug('Sending request to SAP endpoint: ' + cred.Endpoint__c);
        Http http = new Http();
        HttpResponse response = http.send(httpReq);
        System.debug('SAP response received. Status code: ' + response.getStatus());
        System.debug('SAP response body: ' + response.getBody());
        
        // Parsing response
        ResponseWrapper res = (ResponseWrapper) JSON.deserialize(response.getBody(), ResponseWrapper.class);
        System.debug('Parsed SAP response: Status=' + res.Status + ', Message=' + res.Message);
        
        // Handling response
        if (res.Status == 1 && !ma.Syned_To_SAP__c) {
            System.debug('Marking Master Agreement as synced to SAP: ' + ma.Name);
            ma.Syned_To_SAP__c = true;
        } else {
            System.debug('SAP sync failed. Reason: ' + res.Message);
       // Safely get message
            String errorMsg = (res != null && res.Message != null)
                ? res.Message
                : 'Unknown SAP error';
            
            System.debug('SAP sync failed. Reason: ' + errorMsg);
            
            // Extract short reason (avoid regex)
            String shortReason = errorMsg.contains(' :- ')
                ? errorMsg.substringBefore(' :- ').trim()
                : errorMsg;
            
            
            // Truncate full message (Long Text Area)
            Integer shortLen = Schema.SObjectType.Master_Agreement__c
                .fields.Sap_Sync_Error_Message__c
                .getLength();
            
            ma.Sap_Sync_Error_Message__c =
                shortReason.substring(0, Math.min(shortReason.length(), shortLen));
            
            // Use proper DateTime field (make sure field type = DateTime)
                        ma.Sap_Sync_Error_TimeStemp__c = String.valueOf(System.now());
            
            
            MANumberVSError.put(ma.Name, res.Message);
        }
        System.debug('Updating Master Agreement record with sync results.');
        update ma;
        
        // Sending error email if failed
        if (res.Status != 1) {
            System.debug('Sending error email for failed sync.');
            sendErrorEmail(new List<Master_Agreement__c> { ma });
        }
        
        return res;
    }
    
    // Email Notification
    private static void sendErrorEmail(List<Master_Agreement__c> failedAgreements) {
        if (failedAgreements.isEmpty()) {
            System.debug('No failed agreements to send in the email.');
            return;
        }
        
        String htmlBody = '<h2>SAP Sync Failed</h2>';
        htmlBody += '<table border="1"><tr><th>Name</th><th>Account</th><th>Agreement Number</th><th>Error</th><th>Material Codes</th></tr>';
        
        for (Master_Agreement__c failed : failedAgreements) {
            String msg = MANumberVSError.get(failed.Name);
            List<String> materials = new List<String>();
            if (msg != null && msg.contains('$$')) {
                for (String part : msg.split('\\$\\$')) {
                    part = part.trim();
                    if (String.isNotEmpty(part) && !part.contains('No Material Group')) {
                        materials.add(part);
                    }
                }
            }
            
            String subTable = '';
            if (!materials.isEmpty()) {
                subTable = '<table border="1"><tr><th>Code</th></tr>';
                for (String code : materials) {
                    subTable += '<tr><td>' + code + '</td></tr>';
                }
                subTable += '</table>';
            }
            
            htmlBody += '<tr><td>' + failed.Name + '</td><td>' + failed.Account__r.Name + '</td><td>' +
                failed.Agreement_Number__c + '</td><td>' + failed.SAP_Sync_Fail_Reason__c + '</td><td>' +
                subTable + '</td></tr>';
        }
        htmlBody += '</table>';
        
        System.debug('Preparing to send error email.');
        
        BatchUpsertEmail__mdt mdt = BatchUpsertEmail__mdt.getInstance('StockUpdateJob');
        List<String> recipients = mdt.Emails__c.split(',');
        
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(recipients);
        email.setSubject('SAP Sync Failure');
        email.setHtmlBody(htmlBody);
        
        System.debug('Sending error email to recipients: ' + recipients);
        Messaging.SendEmailResult[] mailResults = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        System.debug('mailResults'+mailResults);
        
    }
    
    // Wrapper classes (unchanged)
    public class RequestWrapper { public List<Record> Record; }
    public class Record {
        public String MasterAgreementNumber;
        public String AgreementNumber;
        public String CustomerNumber;
        public String ValidFromDate;
        public String ValidToDate;
        public List<AgreementItem> AgreementItems;
    }
    public class AgreementItem {
        public String DummyCode;
        public String Price;
        public String PriceUnit;
    }
    public class ResponseWrapper {
        @AuraEnabled public String Message { get; set; }
        @AuraEnabled public Integer Status { get; set; }
    }
}
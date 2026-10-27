public class POCTESTDharmesh {
    private static final String SAP_ENDPOINT = 'https://sap.api.endpoint'; // Replace with actual host
    public static String maNumberStr {get;set;}
    public static Map<string,String> MANumberVSError {get;set;}
    public class RequestWrapper {
        public List<Record> Records;
    }
    
    public class Record {
        public String MasterAgreementNumber;
        public String AgreementNumber;
        public String CustomerNumber;
        public String ValidFromDate;
        public String ValidToDate;
        public String AdditionalField1;
        public String AdditionalField2;
        public String AdditionalField3;
        public String AdditionalField4;
        public String AdditionalField5;
        public List<AgreementItem> AgreementItems;
    }
    
    public class AgreementItem {
        public String DummyCode;
        public String DummyCodeDescription;
        public String Price;
        public String PriceUnit;
        public String AdditionalField1;
        public String AdditionalField2;
        public String AdditionalField3;
        public String AdditionalField4;
        public String AdditionalField5;
    }
    
    public class ResponseWrapper {
        public Integer Status;
        public String Message;
    }
    
    @future(callout=true)
    public static void sendExportAgreementData(Set<Id> masterAgreementIds){
                processExportAgreementData(masterAgreementIds); // Non-future version

    }  
    public static void processExportAgreementData(Set<Id> masterAgreementIds) {
                 MANumberVSError = new Map<string,String>();
        
        System.debug('Master Agreement IDs: ' + masterAgreementIds);
        
        if (masterAgreementIds.isEmpty()) {
            System.debug('No Master Agreements to sync.');
            return;
        }
        
        // Fetch Master Agreements
        List<Master_Agreement__c> masterAgreements = [
            SELECT Id, Name,Account__r.Name,Sap_Sync_Error_TimeStemp__c ,Agreement_Number__c, Account__r.SAP_Code__c, 
            Agreement_Start_Date__c, Agreement_End_Date__c, Syned_To_SAP__c
            FROM Master_Agreement__c 
            WHERE Id IN :masterAgreementIds
        ];
        
        if (masterAgreements.isEmpty()) {
            System.debug('No matching Master Agreements found.');
            return;
        }
        
        // Fetch Agreement Products
        List<Agreement_Product__c> agreementProducts = [
            SELECT Master_Agreement__c, Product__r.Dummy_Product_Code__c, Price__c, CurrencyIsoCode 
            FROM Agreement_Product__c 
            WHERE Master_Agreement__c IN :masterAgreementIds
        ];
        
        // Map Agreement Products to Agreements
        Map<Id, List<AgreementItem>> agreementItemsMap = new Map<Id, List<AgreementItem>>();
        for (Agreement_Product__c ap : agreementProducts) {
            if (!agreementItemsMap.containsKey(ap.Master_Agreement__c)) {
                agreementItemsMap.put(ap.Master_Agreement__c, new List<AgreementItem>());
            }
            AgreementItem item = new AgreementItem();
            item.DummyCode = ap.Product__r.Dummy_Product_Code__c;
            item.Price = String.valueOf(ap.Price__c);
            item.PriceUnit = ap.CurrencyIsoCode;
            agreementItemsMap.get(ap.Master_Agreement__c).add(item);
        }
        
        // Prepare request payload
        List<Record> records = new List<Record>();
        for (Master_Agreement__c ma : masterAgreements) {
            Record record = new Record();
            record.MasterAgreementNumber = ma.Name;
            record.AgreementNumber = ma.Agreement_Number__c;
            record.CustomerNumber = ma.Account__r.SAP_Code__c;
            record.ValidFromDate = String.valueOf(ma.Agreement_Start_Date__c);
            record.ValidToDate = String.valueOf(ma.Agreement_End_Date__c);
            record.AgreementItems = agreementItemsMap.get(ma.Id) != null ? agreementItemsMap.get(ma.Id) : new List<AgreementItem>();
            records.add(record);
        }
        
        // Fetch SAP credentials
        SAP_Creds__c credential = SAP_Creds__c.getValues('SAP_Export_Agreement');
        if (credential == null || String.isEmpty(credential.Username__c) || String.isEmpty(credential.Password__c)) {
            System.debug('Missing SAP Credentials');
            return;
        }
        
        String username = credential.Username__c;
        String password = credential.Password__c;
        
        RequestWrapper request = new RequestWrapper();
        request.Records = records;
        String jsonRequest = JSON.serialize(request);
        
        // Configure HTTP request
        Http http = new Http();
        HttpRequest httpRequest = new HttpRequest();
        httpRequest.setEndpoint(credential.Endpoint__c);
        httpRequest.setMethod('POST');
        httpRequest.setHeader('Content-Type', 'application/json');
        httpRequest.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(username + ':' + password)));
        httpRequest.setBody(jsonRequest);
        
        try {
            HttpResponse response = http.send(httpRequest);
            System.debug('SAP Response: ' + response.getBody());
            
            
            ResponseWrapper res = (ResponseWrapper) JSON.deserialize(response.getBody(), ResponseWrapper.class);
            
            
            // Update Master Agreements as Synced
            List<Master_Agreement__c> agreementsToUpdate = new List<Master_Agreement__c>();
            List<Master_Agreement__c> failedAgreements = new List<Master_Agreement__c>(); // Track failed ones
// The current logic is designed to handle only a single master agreement, as SAP is currently processing one master agreement at a time. 
// In the future, if SAP begins handling multiple master agreements simultaneously, 
// this logic will need to be updated to process multiple records using a loop or another appropriate method.
//manumber will work for now as sap is not processing bulk and we are also sending single records but if bulk record is synced this will fail 
            maNumberStr = masterAgreements[0].Name;
            for (Master_Agreement__c ma : masterAgreements) {
                if (res.Status == 1 && !ma.Syned_To_SAP__c) {
                    System.debug('SAP Sync Successful: ' + res.Message);
                    ma.Syned_To_SAP__c = true;
                    agreementsToUpdate.add(ma);
                    
                } else {
                   ma.SAP_Sync_Fail_Reason__c =  res.Message.split(' :-\\s*')[0].trim();
                   ma.Sap_Sync_Error_TimeStemp__c=String.valueOf(System.now());
                    MANumberVSError.put(ma.Name,res.Message);
                    //ma.SAP_Sync_Fail_Reason__c =  res.Message;

                    System.debug('SAP Response Error: ' + res.Message.split(' :-\\s*')[0].trim());

                    System.debug('SAP Response Error length: ' + res.Message.length());
                    failedAgreements.add(ma);
                    agreementsToUpdate.add(ma);
                    
                }
            }
            
            if (!agreementsToUpdate.isEmpty()) {
                update agreementsToUpdate;
                System.debug('Updated Master Agreements as Synced.');
            }
            
            // Send error email if failures exist
            if (!failedAgreements.isEmpty()) {
                String htmlBody = '<h2>SAP Sync Failed for the following Agreements</h2>';
                htmlBody += '<table border="1" cellpadding="5" cellspacing="0" style="border-collapse: collapse;">';
                htmlBody += '<tr><th>Name</th><th>AccountName</th><th>Agreement Number</th><th>Error Message</th><th>Failed Material Codes</th></tr>';
                
                for (Master_Agreement__c failed : failedAgreements) {
                    String errorMessage = MANumberVSError.get(failed.Name);
                    // String errorMessage = '';
                    
                    List<String> materials = new List<String>();
                    
                    // Extract material codes
                    if (errorMessage != null && errorMessage.contains('$$')) {
                        List<String> parts = errorMessage.split('\\$\\$');
                        for (String part : parts) {
                            part = part.trim();
                            if (String.isNotEmpty(part) && !part.contains('No Material Group')) {
                                materials.add(part);
                            }
                        }
                    }
                    
                    // Build the sub-table for material codes
                    String subTable = '';
                    if (!materials.isEmpty()) {
                        subTable = '<table border="1" cellpadding="3" cellspacing="0" style="border-collapse: collapse;">';
                        subTable += '<tr><th>Material Code</th></tr>';
                        for (String code : materials) {
                            subTable += '<tr><td>' + code + '</td></tr>';
                        }
                        subTable += '</table>';
                    }
                    
                    // Add to main table row
                    htmlBody += '<tr>';
                    htmlBody += '<td>' + failed.Name + '</td>';
					htmlBody += '<td>' + failed.Account__r.Name + '</td>';
                    htmlBody += '<td>' + failed.Agreement_Number__c + '</td>';
                    htmlBody += '<td>' + failed.SAP_Sync_Fail_Reason__c+ '</td>';
                    htmlBody += '<td>' + subTable + '</td>';
                    htmlBody += '</tr>';
                }
                
                htmlBody += '</table>';
                
                
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                BatchUpsertEmail__mdt mdt = BatchUpsertEmail__mdt.getInstance('StockUpdateJob');
                List<String> recipientEmails = New List<String>();
                recipientEmails = mdt.Emails__c.split(',');
                email.setToAddresses(recipientEmails); // Replace with real admin email
                System.debug('recipientEmails'+recipientEmails);
                email.setSubject('SAP Sync Failure Notification'+' '+maNumberStr);
                email.setHtmlBody(htmlBody);
                System.debug('htmlBody::->'+htmlBody);
                
                System.debug('email::->'+email);
                
                Messaging.SendEmailResult[] mailResults = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
                System.debug('mailResults'+mailResults);
            }
            
        } catch (Exception e) {
            System.debug('Exception in sending Agreement Data: ' + e.getMessage());
            
            // Optional: you could add a separate admin alert for unexpected exceptions here
        }
        
    
        
    }

}
public class PdfCustomerSchemeQueueable implements Queueable, Database.AllowsCallouts {
    private String customerschemeId;
    private String startdate;
    private String accountId;
    private Id schemeId;
    private List<Scheme_request__c> Schemelist; 
    
    public PdfCustomerSchemeQueueable(String customerschemeId, String startdate, String accountId, Id schemeId,List<scheme_request__c> Schemelist) {
        this.customerschemeId = customerschemeId;
        this.startdate = startdate;
        this.accountId = accountId;
        this.schemeId = schemeId;
        this.Schemelist = Schemelist;
    }
    
    public void execute(QueueableContext context) {
        string endpoint = '';
        MOU_Integration__c mouData = MOU_Integration__c.getInstance('pdfcustomerscheme');
        if (mouData != null) {
            endpoint = mouData.End_Point_URL__c;
        }
        
        if (String.isBlank(endpoint)) {
            createApiErrorLog(
                'MOU scheme',
                'PdfCustomerSchemeQueueable',
                null,
                'CONFIG_ERROR',
                'Endpoint not found in Custom Setting',
                null,
                null
            );
            return;
        }
        
        // Create request body
        Map<String, Object> requestBody = new Map<String, Object>();
        List<Map<String, String>> dataList = new List<Map<String, String>>();
        dataList.add(new Map<String,String>{'CustomerSchemeNo'=>customerschemeId,'StartDate'=>startdate});
        requestBody.put('Records', dataList);
        
        String requestBodyJson = JSON.serialize(requestBody);
        System.debug('Request JSON: ' + requestBodyJson);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setHeader('Content-Type', 'application/json;charset=UTF-8');
        //String username = 'piuser';
        //String password = 'Welcome@123';
        Blob headerValue = Blob.valueOf(mouData.Username__c + ':' + mouData.Password__c);
        String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
        req.setHeader('Authorization', authorizationHeader);
        req.setMethod('POST');
        req.setTimeout(120000);
        req.setBody(requestBodyJson);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        System.debug('Response Body: ' + res.getBody());
        System.debug('Response Status Code: ' + res.getStatusCode());
        
        // Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Map<String, Object> responseMap;
        Map<String, Object> objMap;
        String pdfData;
        
        responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        System.debug('responseMap:--> ' + responseMap);
        
        if (responseMap != null && responseMap.containsKey('Response')) {
            
            Object obj = responseMap.get('Response');
            
            if (obj != null && obj instanceof Map<String, Object>) {
                
                objMap = (Map<String, Object>) obj;
                
                if (objMap.containsKey('PDFData') && objMap.get('PDFData') != null) {
                    pdfData = String.valueOf(objMap.get('PDFData'));
                }
            }
        }
        //System.debug('objMap: ' + objMap);
        //System.debug('pdfData: ' + pdfData);
        // List<Map<String, Object>> responseList = (List<Map<String, Object>>) responseMap.get('Response');
        //List<Object> responseList=(List<Object>) responseMap.get('Response');
        //system.debug('responseList'+responseList);
        
        if (res.getStatusCode() == 200) {
            //Map<String, Object> responseItem = responseList[0];
            Scheme_Request__c schem =new  Scheme_Request__c();
            schem.Id = schemeId;
            schem.PDF_JSON__c =  string.valueof(requestBodyJson);
            if(objMap.containsKey('Message')){
                schem.PDF_Message__c = String.valueOf(objMap.get('Message'));
            }
            
            if(objMap.containsKey('PDFData')){
                schem.PDF_code_data__c = String.valueOf(objMap.get('PDFData'));         
            }
            Set<id> accids = new Set<id>();
            for(Scheme_Request__c sr : Schemelist){
                accids.add(sr.Account__c);
            }
            updateSchemeRequest(schem.Id,schem.PDF_code_data__c,accids);
            
            update schem;            
            
        }else if(res.getStatusCode() == 404){
            //system.debug('responseList'+responseList);
            //Map<String, Object> responseItem = responseList[0];
            Scheme_Request__c schem = new  Scheme_Request__c();
            schem.Id = schemeId;
            schem.PDF_JSON__c = string.valueof(requestBodyJson);
            if(objMap.containsKey('Message')){
                schem.PDF_Message__c = String.valueOf(objMap.get('Message'));
            }
            
            if(objMap.containsKey('PDFData')){
                schem.PDF_code_data__c = String.valueOf(objMap.get('PDFData'));         
            }
            
            update schem;
            
        }else {
            System.debug('API Error: ' + res.getStatusCode());
            System.debug('Response Body: ' + res.getBody());
            createApiErrorLog(
                'MOU scheme',
                'PdfCustomerSchemeQueueable',
                res.getStatusCode(),
                res.getStatus(),
                'Non-200 response from PDF API',
                requestBodyJson,
                res.getBody()
            );
        }
    }  
    
    @future(callout=true)
    public static void updateSchemeRequest(Id schemeId, String pdfData,set<Id> childschemes) {
        try {
            // Fetch Scheme_Request__c record
            Scheme_Request__c schem = [SELECT Id, Account__c FROM Scheme_Request__c WHERE Id = :schemeId LIMIT 1];
            
            // Convert base64 string to Blob
            Blob pdfBlob = EncodingUtil.base64Decode(pdfData);
            User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
            List<ContentVersion> versions = new List<ContentVersion>();
            
            versions.add(new ContentVersion(
                Title = 'Scheme_Request.pdf',
                PathOnClient = 'Scheme_Request.pdf',
                VersionData = pdfBlob,
                IsMajorVersion = true,
                ContentLocation = 'S',
                SharingOption = 'A',
                FirstPublishLocationId = schem.Account__c
            ));
            
            if(childschemes != null){
                for(Id accId : childschemes){
                    versions.add(new ContentVersion(
                        Title = 'Scheme_Request.pdf',
                        PathOnClient = 'Scheme_Request.pdf',
                        VersionData = pdfBlob,
                        IsMajorVersion = true,
                        ContentLocation = 'S',
                        SharingOption = 'A',
                        FirstPublishLocationId = accId
                    ));
                }
            }
            
            insert versions;
            
            // Fetch ContentDocument Id from ContentVersion
            Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :versions LIMIT 1].ContentDocumentId;
            
            // Associate ContentDocument with Scheme_Request__c
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.LinkedEntityId = schem.Account__c; // Link to Scheme_Request__c, not Account__c
            cdl.ContentDocumentId = contentDocumentId;
            cdl.ShareType = 'V'; 
            cdl.Visibility = 'AllUsers';
            
            List<ContentDocumentLink> existingLinks = [
                SELECT Id
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :schem.Account__c
                AND ContentDocumentId = :contentDocumentId
            ];
            
            if(existingLinks.isEmpty()){
                insert cdl;
            }
            // Fetch Scheme Request details
            Scheme_Request__c sr = [
                SELECT
                Id,
                Name,
                Scheme_number__c,
                Scheme_Description__c,
                Start_Date__c,
                End_Date__c,
                
                /* Owner (Greeting + Email) */
                Owner.Name,
                Owner.Email,
                
                /* Account Details (Table) */
                Account__r.Name,
                Account__r.SAP_Code__c,
                Account__r.BillingCity,
                Account__r.BillingState,
                
                /* RSM (To Address + Optional future use) */
                RSM__r.FirstName,
                RSM__r.LastName,
                RSM__r.Email,
                
                /* ZSM (To Address + Optional future use) */
                ZSM__r.FirstName,
                ZSM__r.LastName,
                ZSM__r.Email,
                
                NSM__r.FirstName,
                NSM__r.LastName,
                NSM__r.Email
                
                FROM Scheme_Request__c
                WHERE Id = :schemeId
            ];
            
            OrgWideEmailAddress owe = [
                SELECT Id FROM OrgWideEmailAddress
                WHERE Address = 'crmhelpdesk@biotechhealthcare.com'
                LIMIT 1
            ];
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            
            List<String> toEmails = new List<String>();
            
            MOU_Scheme_MIS_User_Configuration__c settingRec =
                MOU_Scheme_MIS_User_Configuration__c.getInstance('MIS');
            
            if(settingRec != null && String.isNotBlank(settingRec.Emails__c)){
                
                List<String> emailList = settingRec.Emails__c.split(',');
                
                for(String email : emailList){
                    if(String.isNotBlank(email)){
                        toEmails.add(email.trim());
                    }
                }
            }
            
            if(sr.RSM__r != null && String.isNotBlank(sr.RSM__r.Email))
                toEmails.add(sr.RSM__r.Email);
            
            if(sr.ZSM__r != null && String.isNotBlank(sr.ZSM__r.Email))
                toEmails.add(sr.ZSM__r.Email);
            
            if(sr.NSM__c != null && String.isNotBlank(sr.NSM__r.Email))
                toEmails.add(sr.NSM__r.Email);
            
            if(String.isNotBlank(sr.Owner.Email))
                toEmails.add(sr.Owner.Email);
            
            /*if(String.isNotBlank(Label.Admin_for_MOU_scheme))
toEmails.add(Label.Admin_for_MOU_scheme);*/
            
            if(!toEmails.isEmpty()){
                mail.setToAddresses(toEmails);
                
            } else {
                System.debug('❌ No valid email addresses found');
                return;
            }
            
            // Prepare Email
            // Subject
            mail.setOrgWideEmailAddressId(owe.Id);
            
            mail.setSubject('Customer Scheme Implementation - ' + safe(sr.Scheme_number__c));
            
            String logoUrl = URL.getOrgDomainUrl().toExternalForm()
                + '/resource/biotech_Logo';
            
            String body =
                '<div style="font-family:Arial, Helvetica, sans-serif; font-size:13px; color:#000;">'
                
                + '<div style="margin-bottom:12px;">'
                + '<img src="' + logoUrl + '" alt="Biotech Logo" '
                + 'style="height:60px; width:auto;" />'
                + '</div>'
                
                
                + '<!-- Title -->'
                + '<div style="font-size:16px; font-weight:bold; margin-bottom:15px;">'
                + 'Customer Scheme Implementation - ' + safe(sr.Scheme_number__c)
                + '</div>'
                
                + '<!-- Greeting -->'
                + '<p>Dear ' + safe(sr.Owner != null ? sr.Owner.Name : null) + ',</p>'
                
                + '<p>'
                + 'This is to notify you that a new <b>Customer Scheme Request</b> has been processed and applied within '
                + 'the system please find details below:'
                + '</p>'
                
                + '<!-- Main Table -->'
                + '<table border="1" cellpadding="8" cellspacing="0" width="100%" '
                + 'style="border-collapse:collapse; text-align:center;">'
                
                + '<tr>'
                + '<td width="25%"></td>'
                + '<th width="35%">Particulars</th>'
                + '<th width="40%">Details</th>'
                + '</tr>'
                
                /* ================= Scheme Details ================= */
                + '<tr>'
                + '<td rowspan="2"><b>Scheme Details</b></td>'
                + '<td><b>Scheme Reference Number</b></td>'
                + '<td>' + safe(sr.Scheme_number__c) + '</td>'
                + '</tr>'
                
                + '<tr>'
                + '<td><b>Scheme Name &amp; Description</b></td>'
                + '<td>' + safe(sr.Scheme_Description__c) + '</td>'
                + '</tr>'
                
                /* ================= Account Details ================= */
                + '<tr>'
                + '<td rowspan="3"><b>Account Details</b></td>'
                + '<td><b>SAP Code</b></td>'
                + '<td>' + safe(sr.Account__r != null ? sr.Account__r.SAP_Code__c : null) + '</td>'
                + '</tr>'
                
                + '<tr>'
                + '<td><b>Account Name</b></td>'
                + '<td>' + safe(sr.Account__r != null ? sr.Account__r.Name : null) + '</td>'
                + '</tr>'
                
                + '<tr>'
                + '<td><b>Location (City/State)</b></td>'
                + '<td>'
                +   + safe(sr.Account__r != null ? sr.Account__r.BillingCity : null)
                +   + (sr.Account__r != null && !String.isBlank(sr.Account__r.BillingCity) && !String.isBlank(sr.Account__r.BillingState) ? ', ' : '')
                +   + safe(sr.Account__r != null ? sr.Account__r.BillingState : null)
                + '</td>'
                + '</tr>'
                
                /* ================= Validity & Timeline ================= */
                + '<tr>'
                + '<td rowspan="2"><b>Validity &amp; Timeline</b></td>'
                + '<td><b>Scheme Commencement Date</b></td>'
                + '<td>' + formatDate(sr.Start_Date__c) + '</td>'
                + '</tr>'
                
                + '<tr>'
                + '<td><b>Scheme End Date</b></td>'
                + '<td>'  + formatDate(sr.End_Date__c) +  '</td>'
                + '</tr>'
                
                + '</table>'
                
                + '<br/>'
                + '<p>Regards,<br/>'
                + '<b>Biotech Healthcare Pvt. Ltd.</b></p>'
                
                + '<p style="font-size:11px; color:#555;">'
                + '<i>(This is an auto-generated notification from the Salesforce system. Please do not reply to this email.)</i>'
                + '</p>'
                
                + '</div>';
            
            mail.setHtmlBody(body);
            
            // ===== Attach PDF =====
            Messaging.EmailFileAttachment pdfAttachment = new Messaging.EmailFileAttachment();
            pdfAttachment.setFileName('Scheme_Request_' + sr.Name + '.pdf');
            pdfAttachment.setBody(pdfBlob); 
            pdfAttachment.setContentType('application/pdf');
            
            mail.setFileAttachments(new Messaging.EmailFileAttachment[] { pdfAttachment });
            
            // Send Email
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            // System.debug('ContentVersion and ContentDocumentLink successfully created: ' + cv.Id);
            
        } catch (Exception e) {
            System.debug('Error while updating Scheme_Request__c: ' + e.getMessage() + ' | Line: ' + e.getLineNumber());
            createApiErrorLog(
                'MOU scheme',
                'PdfCustomerSchemeQueueable',
                null,
                'FILE_ERROR',
                e.getMessage() + ' | Line: ' + e.getLineNumber(),
                null,
                null
            );
        }
    }
    
    public static String safe(String val) {
        return String.isBlank(val) ? '' : val;
    }
    
    public static String formatDate(Date d) {
        if (d == null) return '';
        Datetime dt = Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
        return dt.format('MMMM dd, yyyy');
    }
    
    public static void createApiErrorLog(
        String apiModuleType,
        String className,
        Integer statusCode,
        String status,
        String message,
        String requestBody,
        String responseBody
    ) {
        try {
            API_Log__c log = new API_Log__c();
            log.API_Module_Type__c = apiModuleType;
            log.Class_Name__c = className;
            log.Log_Date__c = System.now();
            log.Message__c = message;
            //log.Sample_Request_Header__c = requestBody;
            log.Response_Body__c = responseBody;
            insert log;
        } catch (Exception ex) {
            System.debug('API log insert failed: ' + ex.getMessage());
        }
    }  
}
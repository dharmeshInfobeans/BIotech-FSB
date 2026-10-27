// Approval Cotroller
public class ApprovalController {
    //public String approvalComment { get; set; }
    public Id recordId{get;set;} 
    public lead__c leaddata {get;set;}
    public List<FileInfo> fileInfos { get;set;}
    public string thanksurl { get; set;}
    
    public class FileInfo {
        public String name { get; set; }
        public String url { get; set; }
        
    }
    
    public static String fetchCustomSetting(String fieldsname) {
        // Retrieve the specific custom setting record by name
        customer_creation_url__c urls = customer_creation_url__c.getValues('Customer Creation urls');
        
        // Check if the custom setting record exists
        if (urls != null) {
            // Use a Map to relate the parameter to the field API names
            Map<String, String> fieldMap = new Map<String, String>{
                'ZSM' => 'ZSM_url__c',
                    'Admin' => 'Admin_url__c',
                    'Document' => 'document_url__c',
                    'GM NSM' => 'GM_NSM_url__c',
                    'RSM' => 'RSM_Url__c',
                    'SAP' => 'SAP_url__c',
                    'Thank You' => 'Thank_you_url__c'
                    };
                        
                        // Get the API name of the field from the map
                        String fieldApiName = fieldMap.get(fieldsname);
            
            if (fieldApiName != null) {
                // Dynamically access the field using the field's API name
                return (String)urls.get(fieldApiName);
            } else {
                return 'Invalid field name provided.';
            }
        } else {
            return 'Custom setting record not found.';
        }
    }
    
    
    
    
    public ApprovalController() {
        // Initialize recordId based on your requirement (e.g., passed from URL parameter)
        recordId  = ApexPages.currentPage().getParameters().get('id');
        customer_creation_url__c urls = customer_creation_url__c.getValues('Customer Creation urls');
        thanksurl = urls.Thank_you_url__c;
        fileInfos = new List<FileInfo>();
        leaddata = [SELECT Id,Name, Product__c,Email__c, Company__c, Billing_City__c,Billing_state__c,RSM__r.email,ZSM__r.email,GM_NSM__r.Email,User__r.email,GM_NSM__c,ZSM__c,user__c, 
                    Billing_code__c, country__c,RSM__c, RSM__r.Name,ZSM__r.Name,ZSM_Comments__c,
                    ZSM_Approve__c, ZSM_Not_Approve__c, RSM_Comments__c, RSM_Not_Approve__c, RSM_Approve__c,
                    Billing_Street__c, Phakic_Rating__c, CE_CIS_Rating__c,  Mobile__c, Last_Name__c, First_Name__c,
                    Address__c,Owner.Name,GM_NSM__r.Name,GM_NSM_Approve__c, GM_NSM_Comments__c, GM_NSM_Not_Approve__c,
                    Admin_Comments__c, Admin_Not_Approve__c, Admin_Approve__c, User__r.Name,Owner.UserRole.Name,Billing_country__c FROM Lead__c where Id =: recordId];
        
        
        fetchFileLinks();
        
        /* FileInfo file=new FileInfo();
file.Name='Aadhar card';
file.url='https://biotechcrm--biotechdev.sandbox.my.salesforce.com/sfc/p/C3000000fmgb/a/C3000000cdl7/kM.rbSJfS0LSrmV_ULDk92n56AWd_Dg3pRGigvTmhJY';
fileInfos.add(file);
FileInfo file1=new FileInfo();
file1.Name='Driving License';
file1.url='https://biotechcrm--biotechdev.sandbox.my.salesforce.com/sfc/p/C3000000fmgb/a/C3000000cdmj/1gvVs.Se6hBo5LYg3Q8FfE98huoSCQ5e44rJw41G8yA';
fileInfos.add(file1);


FileInfo file2=new FileInfo();
file2.Name='Pan card';
file2.url='https://biotechcrm--biotechdev.sandbox.my.salesforce.com/sfc/p/C3000000fmgb/a/C3000000cf3n/NcFV2SnRE..AkQRQj8fruuHJ.6w70gTohbKK4KSaVDA';
fileInfos.add(file2);
FileInfo file3=new FileInfo();
file3.Name='Voter card';
file3.url='https://biotechcrm--biotechdev.sandbox.my.salesforce.com/sfc/p/C3000000fmgb/a/C3000000cjov/nLXrBvxgORrMMUN4DGtXxYgAztMjHSyuIjH9tVY58Tk';
fileInfos.add(file3);  */      
    }
    
    public void fetchFileLinks() {
        string curUser=UserInfo.getUserId();
        User us=[SELECT Id,name from User where Id=:curUser];
        if (recordId != null) {
            List<ContentDocumentLink> docLinks = [
                SELECT ContentDocumentId 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :recordId
            ];
            
            if (!docLinks.isEmpty()) {
                Set<Id> contentDocumentIds = new Set<Id>();
                for (ContentDocumentLink docLink : docLinks) {
                    contentDocumentIds.add(docLink.ContentDocumentId);
                }
                
                // Fetch the content documents based on their IDs
                List<ContentDocument> documents = [
                    SELECT Id, Title 
                    FROM ContentDocument 
                    WHERE Id IN :contentDocumentIds
                ];
                
                
                
                // Create FileInfo objects for each document
                for (ContentDocument doc : documents) {
                    if(!us.name.contains('SAP') && !us.name.contains('Admin')) {
                        if(!doc.title.contains('AOF_')) {
                            FileInfo fileInfo = new FileInfo();
                            fileInfo.name = doc.Title;
                            fileInfo.url = ApprovalController.fetchCustomSetting('Document') + doc.Id;
                            fileInfos.add(fileInfo);
                        }
                    }
                    if(us.name.contains('SAP') || us.name.contains('Admin')) {
                        FileInfo fileInfo = new FileInfo();fileInfo.name = doc.Title;  fileInfo.url = ApprovalController.fetchCustomSetting('Document') + doc.Id; fileInfos.add(fileInfo);  
                    }
                    
                }
                
            } else {
                // Handle the case where no files are found
                FileInfo fileInfo = new FileInfo();
                fileInfo.name = 'No files found for the given record ID.';
                fileInfos.add(fileInfo);
            }
        } else {
            // Handle the case where recordId is null
            FileInfo fileInfo = new FileInfo();
            fileInfo.name = 'Record ID is not provided.';
            fileInfos.add(fileInfo);
        }
        
        // Final debug to show all fileInfos
        System.debug('Final fileInfos: ' + fileInfos);
    }
    
    
    @RemoteAction
    public static String logPageVisit() {
        
        return 'Success';
    }
    
    
    @RemoteAction
    public static Map<String, Object> RSMKYCapproval(String data, String comment, String recordId, String RSMKey) {
        String plainTextBody;
        Map<String, string> resultMap = new Map<String, string>();
        Set<Id> userIdSet=new Set<Id>();   
        List < ContentDocumentLink > documentLinks = new List < ContentDocumentLink > ();
        List < Messaging.EmailFileAttachment > emailAttachments = new List < Messaging.EmailFileAttachment > ();
        Map<String,Blob> contentMap=new Map<String,Blob>();
        Map<String,String> userEmailMap=new Map<String,String>();
        
        Set<Id> docIdSet=new Set<Id>();
        
        try {
            lead__c leadrecord = [SELECT Id,Name,Mobile__c,First_Name__c,Plant_Code__c,RSM_approval_count__c,RSM_Comments__c,GM_NSM__r.Email,User__c,User__r.Email,GM_NSM__c,country__c,Company__c,Product__c,Email__c,Billing_City__c,Billing_Street__c,Billing_country__c,Billing_state__c,Billing_code__c,Owner.Name,RSM_Approve__c,ZSM__c,ZSM__r.Email, RSM_Not_Approve__c,RSM__r.Email,Language__c FROM lead__c WHERE Id = :recordId LIMIT 1];
            OrgWideEmailAddress[] oweaList = [SELECT Id, Address FROM OrgWideEmailAddress WHERE Address = 'crmhelpdesk@biotechhealthcare.com' LIMIT 1];
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>(); 
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            //&& String.isEmpty(String.valueOf(leadRecord.Id) use this for 
            if (leadrecord.RSM_Approve__c && !leadrecord.RSM_Not_Approve__c && String.isEmpty(String.valueOf(leadRecord.Id))) {
                resultMap.put('status', 'error');
                resultMap.put('message', 'You have already taken the action: Approved.');
                return resultMap;
            } else if (leadrecord.RSM_Not_Approve__c && !leadrecord.RSM_Approve__c && String.isEmpty(String.valueOf(leadRecord.Id))) {
                resultMap.put('status', 'error');
                resultMap.put('message', 'You have already taken the action: Rejected.');
                return resultMap;
            } else {
                
                /*  email.setToAddresses(new String[] {leadrecord.RSM__r.Email}); // recipient email address
email.setSubject('Approve Mail'); // Email subject
email.setPlainTextBody(''+leadrecord.Name+' Kyc document has been succesfully approved by the respective rsm'); 
email.setOrgWideEmailAddressId(oweaList[0].Id); // Replace with Org-Wide Email Address Id
emails.add(email);

system.debug('emailsleadrecord.RSM__c>:'+leadrecord.RSM__c);

// Send the email(s)
Messaging.sendEmail(emails);*/
                
                
                lead__c leaddata = new lead__c();
                leaddata.Id = recordId;
                leaddata.RSM_Comments__c = comment;
                if (data == 'Approve' && RSMKey == 'RSM') {
                    if(leadrecord.RSM_approval_count__c==0) {
                        try {
                            // 1. Switch to Lead's language
                            if (!String.isBlank(leadrecord.Language__c)) {
                                //UserLanguageController.updateUserLanguage(leadrecord.Language__c);
                                generateAndAttachPdf(leadrecord,leadrecord.Language__c, Page.LeadInformationPdf);
                            }
                            // 2. Switch to English (or fallback language) for second PDF
                            UserLanguageController.updateUserLanguage('en_US');
                            generateAndAttachPdf(leadrecord, 'en_US',Page.LeadInformationPdf);
                        }finally {
                            // 3. Restore original language
                            // Capture the logged-in user’s original language
                            User userObj = [
                                SELECT Id, Language__c 
                                FROM User 
                                WHERE Id = :UserInfo.getUserId()
                                LIMIT 1
                            ];
                            String originalLang = userObj.Language__c;
                            
                            // Restore later
                            UserLanguageController.updateUserLanguage(originalLang);
                            
                        }
                        /*PageReference pdfPage = Page.LeadInformationPdf; // Replace with your VF page name
pdfPage.getParameters().put('id', recordId);
Blob pdfBlob;
try {

pdfBlob = pdfPage.getContentAsPDF();
System.debug('PDF blob'+pdfBlob);
} catch (VisualforceException e) {
throw new AuraHandledException('Failed to generate PDF: ' + e.getMessage());
}

// Save the PDF as a ContentVersion
ContentVersion cv = new ContentVersion();
cv.Title = 'AOF_' + leadrecord.First_Name__c +'-'+leadrecord.Plant_Code__c+'-'+leadrecord.Billing_state__c+'-'+leadrecord.Id+ '.pdf';
cv.PathOnClient = 'AOF_' + leadrecord.First_Name__c +'-'+leadrecord.Plant_Code__c+'-'+leadrecord.Billing_state__c+'-'+leadrecord.Id+ '.pdf';
cv.VersionData = pdfBlob;
cv.IsMajorVersion = true;
insert cv;


ContentVersion contentVersion = [
SELECT Id, ContentDocumentId 
FROM ContentVersion 
WHERE Id = :cv.Id
LIMIT 1
];


// Link the PDF to the Lead record
ContentDocumentLink cdl = new ContentDocumentLink();
cdl.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
cdl.LinkedEntityId = recordId;
cdl.ShareType = 'V';
insert cdl;
*/
                    }
                    leaddata.RSM_Approve__c = true;
                    Leaddata.RSM_approval_count__c = 1;
                    leaddata.RSM_Not_Approve__c = false;
                    leaddata.ZSM_Approve__c = false;
                    leaddata.ZSM_Not_Approve__c = false;
                    leaddata.GM_NSM_Approve__c = false;
                    leaddata.GM_NSM_Not_Approve__c = false;
                    leaddata.Admin_Approve__c = false;
                    leaddata.Admin_Not_Approve__c = false;
                    
                    
                    System.debug('RMS Lead Id'+recordId);
                    List < ContentDocumentLink > documents = [SELECT Id, ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension, ContentDocument.LatestPublishedVersionId from ContentDocumentLink where LinkedEntityId =: leadrecord.Id];
                    System.debug('Documents'+documents);                    
                    for(ContentDocumentLink con:documents) {
                        docIdSet.add(con.ContentDocumentId); 
                    }
                    if(docIdSet.size()>0) {
                        List<ContentVersion> cvList = [SELECT VersionData,ContentDocumentId FROM ContentVersion WHERE ContentDocumentId in: docIdSet];// WHERE ContentDocumentId in: docIdSet];
                        for(ContentVersion conVers:cvList) {
                            contentMap.put(conVers.ContentDocumentId,conVers.VersionData);
                        }
                    }
                    for (ContentDocumentLink docLink: documents) {
                        Messaging.EmailFileAttachment emailAttachment = new Messaging.EmailFileAttachment();
                        emailAttachment.setFileName(docLink.ContentDocument.Title);// + '.' + docLink.ContentDocument.FileExtension);
                        //   ContentVersion cv = [SELECT VersionData FROM ContentVersion WHERE ContentDocumentId =: docLink.ContentDocumentId LIMIT 1];
                        if(contentMap.containsKey(docLink.ContentDocumentId)) {
                            emailAttachment.setBody(contentMap.get(docLink.ContentDocumentId));
                            
                        }
                        emailAttachments.add(emailAttachment);
                    }
                    
                    String zsmvfPageUrl;
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    
                    if(leadrecord.ZSM__c != null){
                        zsmvfPageUrl = ApprovalController.fetchCustomSetting('ZSM') + leadrecord.id + '';
                        mail.setToAddresses(new List < String > {leadrecord.ZSM__r.Email});
                        plainTextBody = generateMail(zsmvfPageUrl,leadrecord);
                    }
                    if(leadrecord.ZSM__c == null && leadrecord.GM_NSM__c !=null){
                        String GM_NSMvfPageUrl= ApprovalController.fetchCustomSetting('GM NSM') + leadrecord.id + '';
                        mail.setToAddresses(new List < String > {leadrecord.GM_NSM__r.Email});
                        plainTextBody = generateMail(GM_NSMvfPageUrl,leadrecord);
                        
                    }
                    if( leadrecord.ZSM__c == null && leadrecord.GM_NSM__c == null && string.isNotBlank(system.label.Admin_Customer_Creation)){
                        String adminvfPageUrl = ApprovalController.fetchCustomSetting('Admin') + leadrecord.id + '';
                        mail.setToAddresses(label.Admin_Customer_Creation.contains(',') ? label.Admin_Customer_Creation.split(',') : new List<String>{label.Admin_Customer_Creation});
                        plainTextBody = generateMail(adminvfPageUrl,leadrecord);
                    }
                    if( leadrecord.ZSM__c == null && leadrecord.GM_NSM__c == null && string.isBlank(system.label.Admin_Customer_Creation)){
                        String sapVfPageUrl = ApprovalController.fetchCustomSetting('SAP') + leadrecord.id + '';
                        //   String adminvfPageUrl ='https://biotechcrm--biotechdev.sandbox.my.salesforce-sites.com/adminkycapproval?id=' + leadrecord.id + '';
                        mail.setToAddresses(label.SAP_Customer_Creation.contains(',') ? label.SAP_Customer_Creation.split(',') : new List<String>{label.SAP_Customer_Creation});
                        plainTextBody = generateMail(sapVfPageUrl,leadrecord);
                    }
                    
                    mail.setSubject('New Conversion'+' ' + leadrecord.Name +' '+ '-' + 'City:'+' '+ leadrecord.Billing_City__c);
                    
                    // Construct plain text body
                    /* String plainTextBody = 'Dear Leader,\n\n' +
'A new customer conversion has been initiated with the following details:\n\n'+
'Name : ' + leadrecord.Name + '\n' +
'Hospital : ' + leadrecord.Company__c + '\n' +
'Address : ' + leadrecord.Billing_Street__c+',' + leadrecord.Billing_City__c +'\n'+
'City : ' + leadrecord.Billing_City__c + '\n' +
'State : ' + leadrecord.Billing_state__c + '\n' +
'Pincode : ' + leadrecord.Billing_code__c + '\n' +
'Mobile No. : ' + leadrecord.Mobile__c + '\n' +
'Email : '+ leadrecord.Email__c + '\n\n' +
'Please check the Know Your Customer (KYC) details by clicking the link:\n\n' +
zsmvfPageUrl + '\n' +
'Kindly approve/ send back the conversion request'+'\n\n'+
'Regards,\n' +
'Salesforce Admin'+'\n'+
'Biotech Healthcare';*/
                    
                    mail.setPlainTextBody(plainTextBody);
                    system.debug('plainTextBody' + plainTextBody);
                    //mail.setFileAttachments(emailAttachments);
                    mail.setOrgWideEmailAddressId(oweaList[0].Id);
                    // Send email
                    //   Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                    Messaging.SendEmailResult[] emailResults = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail}, false);
                    for (Messaging.SendEmailResult emailResult : emailResults) {
                        if (emailResult.isSuccess()) {
                            System.debug('Email sent successfully to: ' + leadrecord.ZSM__r.Email);
                        } else {
                            System.debug('Failed to send email to: ' + leadrecord.ZSM__r.Email);
                            for (Messaging.SendEmailError error : emailResult.getErrors()) {
                                System.debug('Error: ' + error.getMessage());
                            }
                        }
                    }
                    System.debug('Mail sent--->ZSM:'+JSON.serialize(mail));
                    // Optionally, add documents to the document list for tracking purposes
                    documentLinks.addAll(documents);
                    
                    
                } else if (data == 'Reject' && RSMKey == 'RSM') {
                    leaddata.RSM_Approve__c = false;
                    leaddata.RSM_Not_Approve__c = true;
                    leaddata.ZSM_Approve__c = false;
                    leaddata.ZSM_Not_Approve__c = false;
                    leaddata.GM_NSM_Approve__c = false;
                    leaddata.GM_NSM_Not_Approve__c = false;
                    leaddata.Admin_Approve__c = false;
                    leaddata.Admin_Not_Approve__c = false;
                    
                    email.setToAddresses(new String[] {leadrecord.RSM__r.Email}); // recipient email address
                    string recordUrl =  ApprovalController.getRecordUrl(leadrecord.Id);
                    system.debug('recordUrl'+recordUrl);
                    email.setSubject('Rejection on New Conversion'+' ' + leadrecord.Name +' '+ '-' + 'City:'+' '+ leadrecord.Billing_City__c);
                    email.setPlainTextBody(rejectedMail(leadrecord));
                    email.setOrgWideEmailAddressId(oweaList[0].Id); // Replace with Org-Wide Email Address Id
                    emails.add(email);
                    
                    // Send the email(s)
                    Messaging.sendEmail(emails);
                }
                
                update leaddata;
                
                resultMap.put('status', 'success');
                //resultMap.put('message', data + ' Submit successfully.');
                return resultMap;
            }
        } catch (Exception e) {
            resultMap.put('status', 'error');
            resultMap.put('message', 'An error occurred: ' + e.getMessage());
            return resultMap;
        }
    }
    
    @RemoteAction
    public static Map<String, Object> ZSMkycapproval(String data, String comment, String recordId, String ZSMKey) {
        
        string plainTextBody;
        Map<String, string> resultMap = new Map<String, string>();
        Set<Id> userIdSet=new Set<Id>();   
        List < ContentDocumentLink > documentLinks = new List < ContentDocumentLink > ();
        List < Messaging.EmailFileAttachment > emailAttachments = new List < Messaging.EmailFileAttachment > ();
        Map<String,Blob> contentMap=new Map<String,Blob>();
        Map<String,String> userEmailMap=new Map<String,String>();
        Set<Id> docIdSet=new Set<Id>();
        
        try {
            lead__c leadrecord = [SELECT Id,Name,Mobile__c,ZSM_Comments__c,RSM__c,First_Name__c,Plant_Code__c,RSM_Email__c,Sales_Office__c,Plant__c,User__c,User__r.Email,Billing_code__c,Billing_Street__c,Email__c,Company__c, country__c,ZSM_Approve__c,ZSM_Not_Approve__c,Product__c,Billing_state__c,GM_NSM__c,GM_NSM__r.Email,Billing_City__c,Owner.Name,RSM_Approve__c,ZSM__c,ZSM__r.Email, RSM_Not_Approve__c,SAP_Code__c FROM lead__c WHERE Id = :recordId LIMIT 1];
            OrgWideEmailAddress[] oweaList = [SELECT Id, Address FROM OrgWideEmailAddress WHERE Address = 'crmhelpdesk@biotechhealthcare.com' LIMIT 1];
            
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>(); 
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            if (leadrecord.ZSM_Approve__c && !leadrecord.ZSM_Not_Approve__c) {
                resultMap.put('status', 'error');
                resultMap.put('message', 'You have already taken the action: Approved.');
                return resultMap;
            } else if (leadrecord.ZSM_Not_Approve__c && !leadrecord.ZSM_Approve__c) {    resultMap.put('status', 'error');   resultMap.put('message', 'You have already taken the action: Rejected.'); return resultMap;
                                                                                    } else {
                                                                                        /* email.setToAddresses(new String[] {leadrecord.ZSM__r.Email}); // recipient email address
email.setSubject('Approve Mail'); // Email subject
email.setPlainTextBody(''+leadrecord.Name+' Kyc document has been  approved by the respective ZSM'); 
email.setOrgWideEmailAddressId(oweaList[0].Id); // Replace with Org-Wide Email Address Id
emails.add(email);
Messaging.sendEmail(emails);*/
                                                                                        lead__c leaddata = new lead__c();
                                                                                        leaddata.Id = recordId;
                                                                                        leaddata.ZSM_Comments__c = comment;
                                                                                        
                                                                                        if (data == 'Approve' && ZSMKey == 'ZSM') {
                                                                                            List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
                                                                                            
                                                                                            List<Sales_Data_Kyc_Form__c> slsDataList=[SELECT Id,Email__c,Country__c,State__c,Plant__c,Sales_District__c,Sales_Officer__c from Sales_Data_Kyc_Form__c where Sales_Officer__c=:leadRecord.Sales_Office__c AND Plant__c=:leadRecord.Plant__c];
                                                                                            if(slsDataList.size()>0) {//need to add the attachement here
                                                                                                List<ContentDocumentLink> docLinks = [
                                                                                                    SELECT ContentDocumentId 
                                                                                                    FROM ContentDocumentLink 
                                                                                                    WHERE LinkedEntityId = :recordId
                                                                                                ];
                                                                                                
                                                                                                if (!docLinks.isEmpty()) {
                                                                                                    Set<Id> contentDocumentIds = new Set<Id>();
                                                                                                    for (ContentDocumentLink docLink : docLinks) {
                                                                                                        contentDocumentIds.add(docLink.ContentDocumentId);
                                                                                                    }
                                                                                                    
                                                                                                    // Retrieve the ContentDocuments and their related ContentVersions (for file data)
                                                                                                    List<ContentVersion> versions = [
                                                                                                        SELECT Id, Title, VersionData, ContentDocumentId 
                                                                                                        FROM ContentVersion 
                                                                                                        WHERE ContentDocumentId IN :contentDocumentIds
                                                                                                    ];
                                                                                                    
                                                                                                    
                                                                                                    // Add the PDF files as attachments
                                                                                                    for (ContentVersion version : versions) {
                                                                                                        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                                                                                                        attachment.setFileName(version.Title);
                                                                                                        attachment.setBody(version.VersionData);
                                                                                                        attachments.add(attachment);
                                                                                                    }
                                                                                                    
                                                                                                }
                                                                                                Messaging.SingleEmailMessage GMNSmail = new Messaging.SingleEmailMessage();
                                                                                                if(ZSMKey == 'ZSM' && leadrecord.GM_NSM__c !=null && data == 'Approve' && Leadrecord.RSM__c==null){ PageReference pdfPage = Page.LeadInformationPdf;   pdfPage.getParameters().put('id', recordId);     Blob pdfBlob;    try { pdfBlob = pdfPage.getContentAsPDF();
                                                                                                                                                                                                                                                                                                                             } catch (VisualforceException e) {
                                                                                                                                                                                                                                                                                                                                 throw new AuraHandledException('Failed to generate PDF: ' + e.getMessage());
                                                                                                                                                                                                                                                                                                                             }
                                                                                                                                                                                                   
                                                                                                                                                                                                   // Save the PDF as a ContentVersion
                                                                                                                                                                                                   ContentVersion cv = new ContentVersion();
                                                                                                                                                                                                   cv.Title = 'AOF_' + leadrecord.First_Name__c +'-'+leadrecord.Plant_Code__c+'-'+leadrecord.Billing_state__c+'-'+leadrecord.Id+ '.pdf';
                                                                                                                                                                                                   cv.PathOnClient = 'AOF_' + leadrecord.First_Name__c +'-'+leadrecord.Plant_Code__c+'-'+leadrecord.Billing_state__c+'-'+leadrecord.Id+ '.pdf';
                                                                                                                                                                                                   cv.VersionData = pdfBlob;
                                                                                                                                                                                                   cv.IsMajorVersion = true;
                                                                                                                                                                                                   insert cv;
                                                                                                                                                                                                   
                                                                                                                                                                                                   
                                                                                                                                                                                                   ContentVersion contentVersion = [
                                                                                                                                                                                                       SELECT Id, ContentDocumentId 
                                                                                                                                                                                                       FROM ContentVersion 
                                                                                                                                                                                                       WHERE Id = :cv.Id
                                                                                                                                                                                                       LIMIT 1
                                                                                                                                                                                                   ];
                                                                                                                                                                                                   
                                                                                                                                                                                                   System.debug('Content version'+contentVersion);                
                                                                                                                                                                                                   // Link the PDF to the Lead record
                                                                                                                                                                                                   ContentDocumentLink cdl = new ContentDocumentLink();
                                                                                                                                                                                                   cdl.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
                                                                                                                                                                                                   cdl.LinkedEntityId = recordId;
                                                                                                                                                                                                   cdl.ShareType = 'V';
                                                                                                                                                                                                   insert cdl;
                                                                                                                                                                                                   
                                                                                                                                                                                                   
                                                                                                                                                                                                   List<Messaging.EmailFileAttachment> gsmattachments = new List<Messaging.EmailFileAttachment>();
                                                                                                                                                                                                   
                                                                                                                                                                                                   
                                                                                                                                                                                                   List<ContentDocumentLink> gmsdocLinks = [
                                                                                                                                                                                                       SELECT ContentDocumentId 
                                                                                                                                                                                                       FROM ContentDocumentLink 
                                                                                                                                                                                                       WHERE LinkedEntityId = :recordId
                                                                                                                                                                                                   ];
                                                                                                                                                                                                   
                                                                                                                                                                                                   if (!gmsdocLinks.isEmpty()) {
                                                                                                                                                                                                       Set<Id> contentDocumentIds = new Set<Id>();
                                                                                                                                                                                                       for (ContentDocumentLink docLink : docLinks) {
                                                                                                                                                                                                           contentDocumentIds.add(docLink.ContentDocumentId);
                                                                                                                                                                                                       }
                                                                                                                                                                                                       // Construct the expected title
                                                                                                                                                                                                       String expectedTitle = 'AOF_' + leadrecord.First_Name__c + '-' + leadrecord.Plant_Code__c + '-' + leadrecord.Billing_state__c + '-' + leadrecord.Id + '.pdf';
                                                                                                                                                                                                       
                                                                                                                                                                                                       // Retrieve the ContentVersion records
                                                                                                                                                                                                       List<ContentVersion> versions = [
                                                                                                                                                                                                           SELECT Id, Title, VersionData, ContentDocumentId 
                                                                                                                                                                                                           FROM ContentVersion 
                                                                                                                                                                                                           WHERE ContentDocumentId IN :contentDocumentIds AND Title !=:expectedTitle
                                                                                                                                                                                                       ];
                                                                                                                                                                                                       
                                                                                                                                                                                                       
                                                                                                                                                                                                       // Add the PDF files as attachments
                                                                                                                                                                                                       for (ContentVersion version : versions) {
                                                                                                                                                                                                           Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                                                                                                                                                                                                           attachment.setFileName(version.Title);
                                                                                                                                                                                                           attachment.setBody(version.VersionData);
                                                                                                                                                                                                           gsmattachments.add(attachment);
                                                                                                                                                                                                       }
                                                                                                                                                                                                   }
                                                                                                                                                                                                   // Add the attachments to the email
                                                                                                                                                                                                   
                                                                                                                                                                                                   String GM_NSMvfPageUrl= ApprovalController.fetchCustomSetting('GM NSM') + leadrecord.id + '';
                                                                                                                                                                                                   
                                                                                                                                                                                                   GMNSmail.setToAddresses(new List < String > {leadrecord.GM_NSM__r.Email});
                                                                                                                                                                                                   plainTextBody = generateMail(GM_NSMvfPageUrl,leadrecord);
                                                                                                                                                                                                   GMNSmail.setSubject('New Conversion'+' ' + leadrecord.Name +' '+ '-' + 'City:'+' '+ leadrecord.Billing_City__c);
                                                                                                                                                                                                   GMNSmail.setPlainTextBody(plainTextBody);
                                                                                                                                                                                                   system.debug('plainTextBody' + plainTextBody);
                                                                                                                                                                                                   //GMNSmail.setFileAttachments(gsmattachments);
                                                                                                                                                                                                   GMNSmail.setOrgWideEmailAddressId(oweaList[0].Id);
                                                                                                                                                                                                   // Send email
                                                                                                                                                                                                   //   Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                                                                                                                                                                                                   Messaging.SendEmailResult[] emailResults = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{GMNSmail}, false);
                                                                                                                                                                                                   for (Messaging.SendEmailResult emailResult : emailResults) {
                                                                                                                                                                                                       if (emailResult.isSuccess()) {
                                                                                                                                                                                                           System.debug('Email sent successfully to: ' + leadrecord.GM_NSM__r.Email);
                                                                                                                                                                                                       } else {
                                                                                                                                                                                                           System.debug('Failed to send email to: ' + leadrecord.GM_NSM__r.Email);
                                                                                                                                                                                                           for (Messaging.SendEmailError error : emailResult.getErrors()) {
                                                                                                                                                                                                               System.debug('Error: ' + error.getMessage());
                                                                                                                                                                                                           }
                                                                                                                                                                                                       }
                                                                                                                                                                                                   }
                                                                                                                                                                                                   
                                                                                                                                                                                                  }
                                                                                                Messaging.SingleEmailMessage mail1 = new Messaging.SingleEmailMessage();
                                                                                                //  mail1.setToAddresses(new List < String > {slsDataList[0].Email__c.contains(',')});
                                                                                                mail1.setToAddresses(slsDataList[0].Email__c.contains(',') ? slsDataList[0].Email__c.split(',') : new List<String>{slsDataList[0].Email__c});
                                                                                                
                                                                                                mail1.setSubject('Branch Notification');
                                                                                                mail1.setHtmlBody(generateBranchMail(leadrecord));
                                                                                                //    mail.setFileAttachments(emailAttachments);
                                                                                                mail1.setOrgWideEmailAddressId(oweaList[0].Id);
                                                                                                mail1.setFileAttachments(attachments);
                                                                                                
                                                                                                Messaging.SendEmailResult[] emailResults1 = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail1}, false);
                                                                                                for (Messaging.SendEmailResult emailResult : emailResults1) {
                                                                                                    if (emailResult.isSuccess()) {
                                                                                                        System.debug('Email sent successfully to: ' + slsDataList[0].Email__c);
                                                                                                    } else {
                                                                                                        for (Messaging.SendEmailError error : emailResult.getErrors()) {
                                                                                                            System.debug('Error: ' + error.getMessage());
                                                                                                        }
                                                                                                    }
                                                                                                }
                                                                                                
                                                                                            }
                                                                                            
                                                                                            
                                                                                            leaddata.ZSM_Approve__c = true;
                                                                                            leaddata.ZSM_Not_Approve__c = false;
                                                                                            
                                                                                            leaddata.GM_NSM_Approve__c = false;
                                                                                            leaddata.GM_NSM_Not_Approve__c = false;
                                                                                            leaddata.Admin_Approve__c = false;
                                                                                            leaddata.Admin_Not_Approve__c = false;
                                                                                            
                                                                                            List < ContentDocumentLink > documents = [SELECT Id, ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension, ContentDocument.LatestPublishedVersionId from ContentDocumentLink where LinkedEntityId =: leadrecord.Id];
                                                                                            for(ContentDocumentLink con:documents) {
                                                                                                docIdSet.add(con.ContentDocumentId); 
                                                                                            }
                                                                                            if(docIdSet.size()>0) {
                                                                                                List<ContentVersion> cvList = [SELECT VersionData,ContentDocumentId FROM ContentVersion WHERE ContentDocumentId in: docIdSet];
                                                                                                for(ContentVersion conVers:cvList) {
                                                                                                    contentMap.put(conVers.ContentDocumentId,conVers.VersionData);
                                                                                                }
                                                                                            }
                                                                                            for (ContentDocumentLink docLink: documents) {
                                                                                                Messaging.EmailFileAttachment emailAttachment = new Messaging.EmailFileAttachment();
                                                                                                emailAttachment.setFileName(docLink.ContentDocument.Title);// + '.' + docLink.ContentDocument.FileExtension);
                                                                                                //   ContentVersion cv = [SELECT VersionData FROM ContentVersion WHERE ContentDocumentId =: docLink.ContentDocumentId LIMIT 1];
                                                                                                if(contentMap.containsKey(docLink.ContentDocumentId)) {
                                                                                                    emailAttachment.setBody(contentMap.get(docLink.ContentDocumentId));
                                                                                                    
                                                                                                }
                                                                                                emailAttachments.add(emailAttachment);
                                                                                            }
                                                                                            System.debug('Email attachement'+emailAttachments);
                                                                                            String GM_NSMvfPageUrl;
                                                                                            // String GM_NSMvfPageUrl= 'https://biotechcrm--biotechdev.sandbox.my.salesforce-sites.com/GMNSMKYCapproval?id=' + leadrecord.id + '';
                                                                                            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                                                                                            
                                                                                            String adminvfPageUrl =ApprovalController.fetchCustomSetting('Admin') + leadrecord.id + '';
                                                                                            mail.setToAddresses(label.Admin_Customer_Creation.contains(',') ? label.Admin_Customer_Creation.split(',') : new List<String>{label.Admin_Customer_Creation});
                                                                                            plainTextBody = generateMail(adminvfPageUrl,leadrecord);
                                                                                            
                                                                                            /*  if(leadrecord.GM_NSM__c == null && leadrecord.User__c ==null){
System.debug('Inside 4');
String sapVfPageUrl = ApprovalController.fetchCustomSetting('SAP') + leadrecord.id + '';
//   String adminvfPageUrl ='https://biotechcrm--biotechdev.sandbox.my.salesforce-sites.com/adminkycapproval?id=' + leadrecord.id + '';
mail.setToAddresses(label.SAP_Customer_Creation.contains(',') ? label.SAP_Customer_Creation.split(',') : new List<String>{label.SAP_Customer_Creation});                        plainTextBody = generateMail(sapVfPageUrl,leadrecord);
}*/
                                                                                            
                                                                                            
                                                                                            
                                                                                            
                                                                                            // Set subject
                                                                                            mail.setSubject('New Conversion'+' ' + leadrecord.Name +' '+ '-' + 'City:'+' '+ leadrecord.Billing_City__c);
                                                                                            
                                                                                            
                                                                                            
                                                                                            
                                                                                            
                                                                                            mail.setPlainTextBody(plainTextBody);
                                                                                            system.debug('plainTextBody' + plainTextBody);
                                                                                            mail.setFileAttachments(emailAttachments);
                                                                                            mail.setOrgWideEmailAddressId(oweaList[0].Id);
                                                                                            // Send email
                                                                                            //   Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                                                                                            
                                                                                            if(leadrecord.RSM__c !=null){
                                                                                                Messaging.SendEmailResult[] emailResults = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail}, false);
                                                                                                for (Messaging.SendEmailResult emailResult : emailResults) {
                                                                                                    if (emailResult.isSuccess()) {
                                                                                                        System.debug('Email sent successfully to: ' + leadrecord.ZSM__r.Email);
                                                                                                    } else {
                                                                                                        System.debug('Failed to send email to: ' + leadrecord.ZSM__r.Email);
                                                                                                        for (Messaging.SendEmailError error : emailResult.getErrors()) {
                                                                                                            System.debug('Error: ' + error.getMessage());
                                                                                                        }
                                                                                                    }
                                                                                                }
                                                                                                System.debug('ZSMkycapproval'+JSON.serialize(mail));
                                                                                            }
                                                                                            
                                                                                            
                                                                                            // Optionally, add documents to the document list for tracking purposes
                                                                                            documentLinks.addAll(documents); } else if (data == 'Reject' && ZSMKey == 'ZSM') { email.setToAddresses(new String[] {leadrecord.ZSM__r.Email});  string recordUrl =  ApprovalController.getRecordUrl(leadrecord.Id);  email.setSubject('Rejection on New Conversion'+' ' + leadrecord.Name +' '+ '-' + 'City:'+' '+ leadrecord.Billing_City__c); email.setPlainTextBody(rejectedMail(leadrecord));  email.setOrgWideEmailAddressId(oweaList[0].Id); // Replace with Org-Wide Email Address Id
                                                                                                                                                                              emails.add(email);
                                                                                                                                                                              Messaging.sendEmail(emails);
                                                                                                                                                                              leaddata.ZSM_Approve__c = false;
                                                                                                                                                                              leaddata.ZSM_Not_Approve__c = true;
                                                                                                                                                                              leaddata.RSM_Approve__c=true;
                                                                                                                                                                              leaddata.RSM_Not_Approve__c=false;
                                                                                                                                                                              leaddata.GM_NSM_Approve__c = false;
                                                                                                                                                                              leaddata.GM_NSM_Not_Approve__c = false;
                                                                                                                                                                              leaddata.Admin_Approve__c = false;
                                                                                                                                                                              leaddata.Admin_Not_Approve__c = false;
                                                                                                                                                                             }
                                                                                        
                                                                                        update leaddata;
                                                                                        
                                                                                        resultMap.put('status', 'success');
                                                                                        //resultMap.put('message', data + ' Submit successfully.');
                                                                                        return resultMap;
                                                                                    }
        } catch (Exception e) {
            resultMap.put('status', 'error');
            resultMap.put('message', 'An error occurred: ' + e.getMessage());
            return resultMap;
        }
    }
    
    @RemoteAction
    public static Map<String, Object> GM_NSMkyccommenmethod(String data, String GM_NSMcomment, String recordId, String GM_NSMkey) {
        string plainTextBody;
        Map<String, string> resultMap = new Map<String, string>();
        Set<Id> userIdSet=new Set<Id>();   
        List < ContentDocumentLink > documentLinks = new List < ContentDocumentLink > ();
        List < Messaging.EmailFileAttachment > emailAttachments = new List < Messaging.EmailFileAttachment > ();
        Map<String,Blob> contentMap=new Map<String,Blob>();
        Map<String,String> userEmailMap=new Map<String,String>();
        Set<Id> docIdSet=new Set<Id>();
        try {
            // Query to find the lead record by ID
            lead__c leadrecord = [SELECT Id,Name,Mobile__c,User__c,GM_NSM_Comments__c,Billing_code__c,Billing_Street__c,Email__c,Company__c, country__c,User__r.Email,Product__c,GM_NSM_Approve__c,GM_NSM_Not_Approve__c,Billing_state__c,GM_NSM__r.Email,Billing_City__c,Owner.Name,RSM_Approve__c,ZSM__c,ZSM__r.Email, RSM_Not_Approve__c FROM lead__c WHERE Id = :recordId LIMIT 1];
            OrgWideEmailAddress[] oweaList = [SELECT Id, Address FROM OrgWideEmailAddress WHERE Address = 'crmhelpdesk@biotechhealthcare.com' LIMIT 1];            
            
            
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>(); 
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            // Check if the SAP_Code__c is already filled and the JSMkey is 'JSM'
            if (leadrecord.GM_NSM_Approve__c && !leadrecord.GM_NSM_Not_Approve__c ) {
                resultMap.put('status', 'error');
                resultMap.put('message', 'You have already taken the action: Approved.');
                System.debug(resultMap);
                return resultMap;
            } else if (leadrecord.GM_NSM_Not_Approve__c && !leadrecord.GM_NSM_Approve__c) { resultMap.put('status', 'error'); resultMap.put('message', 'You have already taken the action: Rejected.'); return resultMap;
                                                                                          } else {
                                                                                              // Update the lead record with the new SAP code and change the lead stage
                                                                                              /*  email.setToAddresses(new String[] {leadrecord.GM_NSM__r.Email}); // recipient email address
email.setSubject('Approve Mail'); // Email subject
email.setPlainTextBody(''+leadrecord.Name+' Kyc document has been  approved by the respective GM'); 
email.setOrgWideEmailAddressId(oweaList[0].Id); // Replace with Org-Wide Email Address Id
emails.add(email);
Messaging.sendEmail(emails);*/
                                                                                              lead__c leaddata = new lead__c();
                                                                                              leaddata.Id = recordId;
                                                                                              leaddata.GM_NSM_Comments__c = GM_NSMcomment;
                                                                                              
                                                                                              if (data == 'Approve' && GM_NSMkey == 'GM_NSM') {
                                                                                                  leaddata.GM_NSM_Approve__c = true;
                                                                                                  leaddata.GM_NSM_Not_Approve__c = false;
                                                                                                  
                                                                                                  leaddata.Admin_Approve__c = false;
                                                                                                  leaddata.Admin_Not_Approve__c = false;
                                                                                                  Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                                                                                                  System.debug('Lead record'+leadrecord);
                                                                                                  System.debug('ZSM Email'+leadrecord.GM_NSM__r.Email);
                                                                                                  
                                                                                                  
                                                                                                  List<ContentDocumentLink> docLinks = [
                                                                                                      SELECT ContentDocumentId 
                                                                                                      FROM ContentDocumentLink 
                                                                                                      WHERE LinkedEntityId = :recordId
                                                                                                  ];
                                                                                                  system.debug('docLinks:--->>>'+docLinks);
                                                                                                  
                                                                                                  if (!docLinks.isEmpty()) {
                                                                                                      Set<Id> contentDocumentIds = new Set<Id>();
                                                                                                      for (ContentDocumentLink docLink : docLinks) {
                                                                                                          contentDocumentIds.add(docLink.ContentDocumentId);
                                                                                                      }
                                                                                                      system.debug('contentDocumentIds:--->>>'+contentDocumentIds);
                                                                                                      
                                                                                                      // Retrieve the ContentDocuments and their related ContentVersions (for file data)
                                                                                                      List<ContentVersion> versions = [
                                                                                                          SELECT Id, Title, VersionData, ContentDocumentId 
                                                                                                          FROM ContentVersion 
                                                                                                          WHERE ContentDocumentId IN :contentDocumentIds
                                                                                                      ];
                                                                                                      
                                                                                                      List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
                                                                                                      
                                                                                                      // Add the PDF files as attachments
                                                                                                      for (ContentVersion version : versions) {
                                                                                                          Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                                                                                                          attachment.setFileName(version.Title);
                                                                                                          attachment.setBody(version.VersionData);
                                                                                                          attachments.add(attachment);
                                                                                                      }
                                                                                                      System.debug('Attachement0-----'+attachments);
                                                                                                      // Add the attachments to the email
                                                                                                      mail.setFileAttachments(attachments);
                                                                                                      
                                                                                                  }
                                                                                                  
                                                                                                  if(string.isNotBlank(system.label.Admin_Customer_Creation)){//Change with user
                                                                                                      String adminvfPageUrl =ApprovalController.fetchCustomSetting('Admin') + leadrecord.id + '';
                                                                                                      mail.setToAddresses(label.Admin_Customer_Creation.contains(',') ? label.Admin_Customer_Creation.split(',') : new List<String>{label.Admin_Customer_Creation}); // recipient email address
                                                                                                      plainTextBody = generateMail(adminvfPageUrl,leadrecord);  } else if(string.isBlank(system.label.Admin_Customer_Creation)) { String sapVfPageUrl = ApprovalController.fetchCustomSetting('SAP') + leadrecord.id + '';
                                                                                                                                                                                                                                 mail.setToAddresses(label.SAP_Customer_Creation.contains(',') ? label.SAP_Customer_Creation.split(',') : new List<String>{label.SAP_Customer_Creation});                        plainTextBody = generateMail(sapVfPageUrl,leadrecord);
                                                                                                                                                                                                                                }
                                                                                                  
                                                                                                  
                                                                                                  // Set subject
                                                                                                  mail.setSubject('New Conversion'+' ' + leadrecord.Name +' '+ '-' + 'City:'+' '+ leadrecord.Billing_City__c);
                                                                                                  
                                                                                                  mail.setPlainTextBody(plainTextBody);
                                                                                                  
                                                                                                  mail.setOrgWideEmailAddressId(oweaList[0].Id);
                                                                                                  // Send email
                                                                                                  //   Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                                                                                                  Messaging.SendEmailResult[] emailResults = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail}, false);
                                                                                                  for (Messaging.SendEmailResult emailResult : emailResults) {
                                                                                                      if (emailResult.isSuccess()) {
                                                                                                          System.debug('Email sent successfully to: ' + leadrecord.User__r.Email);
                                                                                                      } else {
                                                                                                          System.debug('Failed to send email to: ' + leadrecord.User__r.Email);
                                                                                                          for (Messaging.SendEmailError error : emailResult.getErrors()) {
                                                                                                              System.debug('Error: ' + error.getMessage());
                                                                                                          }
                                                                                                      }
                                                                                                  }
                                                                                                  System.debug('GM_NSMkyccommenmethod'+JSON.serialize(mail));
                                                                                                  // Optionally, add documents to the document list for tracking purposes
                                                                                                  //   documentLinks.addAll(documents);
                                                                                                  
                                                                                                  
                                                                                                  
                                                                                                  
                                                                                              } else if (data == 'Reject' && GM_NSMkey == 'GM_NSM') {
                                                                                                  email.setToAddresses(new String[] {leadrecord.GM_NSM__r.Email}); // recipient email address
                                                                                                  string recordUrl =  ApprovalController.getRecordUrl(leadrecord.Id);
                                                                                                  system.debug('recordUrl'+recordUrl);
                                                                                                  email.setSubject('Rejection on New Conversion'+' ' + leadrecord.Name +' '+ '-' + 'City:'+' '+ leadrecord.Billing_City__c);
                                                                                                  
                                                                                                  email.setPlainTextBody(rejectedMail(leadrecord));
                                                                                                  email.setOrgWideEmailAddressId(oweaList[0].Id); // Replace with Org-Wide Email Address Id
                                                                                                  emails.add(email);
                                                                                                  Messaging.sendEmail(emails);
                                                                                                  leaddata.GM_NSM_Approve__c = false;
                                                                                                  leaddata.GM_NSM_Not_Approve__c = true;
                                                                                                  leaddata.RSM_Approve__c = true;
                                                                                                  leaddata.RSM_Not_Approve__c = false;
                                                                                                  leaddata.ZSM_Approve__c = true;
                                                                                                  leaddata.ZSM_Not_Approve__c= false;
                                                                                              }
                                                                                              
                                                                                              update leaddata;
                                                                                              
                                                                                              
                                                                                              
                                                                                              
                                                                                              resultMap.put('status', 'success');
                                                                                              resultMap.put('message', data + ' submitted successfully.');
                                                                                              System.debug(resultMap);
                                                                                              return resultMap;
                                                                                          }
        } catch (Exception e) {
            resultMap.put('status', 'error');
            resultMap.put('message', 'An error occurred: ' + e.getMessage());
            System.debug('Error: ' + e.getMessage());
            return resultMap;
        }
    }
    
    @RemoteAction
    public static Map<String, Object> Adminkycmethod(String data, String Admincomment, String recordId, String Adminkey) {
        
        
        Map<String, string> resultMap = new Map<String, string>();
        Set<Id> userIdSet=new Set<Id>();   
        List < ContentDocumentLink > documentLinks = new List < ContentDocumentLink > ();
        List < Messaging.EmailFileAttachment > emailAttachments = new List < Messaging.EmailFileAttachment > ();
        Map<String,Blob> contentMap=new Map<String,Blob>();
        Map<String,String> userEmailMap=new Map<String,String>();
        Set<Id> docIdSet=new Set<Id>();
        try {
            // Query to find the lead record by ID
            lead__c leadrecord = [SELECT Id,Name,Mobile__c,RSM_Email__c,Admin_Comments__c,User__c,Billing_code__c,Billing_Street__c,Email__c,Company__c, country__c,User__r.Email,Product__c,Admin_Approve__c,Admin_Not_Approve__c,Billing_state__c,GM_NSM__r.Email,Billing_City__c,Owner.Name,RSM_Approve__c,ZSM__c,ZSM__r.Email, RSM_Not_Approve__c,plant__c,Sales_Office__c FROM lead__c WHERE Id = :recordId LIMIT 1];
            OrgWideEmailAddress[] oweaList = [SELECT Id, Address FROM OrgWideEmailAddress WHERE Address = 'crmhelpdesk@biotechhealthcare.com' LIMIT 1];  
            
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>(); 
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            // Check if the SAP_Code__c is already filled and the JSMkey is 'JSM'
            if (leadrecord.Admin_Approve__c && !leadrecord.Admin_Not_Approve__c) {
                resultMap.put('status', 'error');
                resultMap.put('message', 'You have already taken the action: Approved.');
                
                System.debug(resultMap);
                return resultMap;
                
            } else if (leadrecord.Admin_Not_Approve__c && !leadrecord.Admin_Approve__c) {
                resultMap.put('status', 'error');
                resultMap.put('message', 'You have already taken the action: Rejected.');
                return resultMap;
            } else {
                // Update the lead record with the new SAP code and change the lead stage
                /*   email.setToAddresses(label.Admin_Customer_Creation.contains(',') ? label.Admin_Customer_Creation.split(',') : new List<String>{label.Admin_Customer_Creation}); // recipient email address
email.setSubject('Approve Mail'); // Email subject
email.setPlainTextBody(''+leadrecord.Name+' Kyc document has been  approved by the respective Admin'); 
email.setOrgWideEmailAddressId(oweaList[0].Id); // Replace with Org-Wide Email Address Id
emails.add(email);
Messaging.sendEmail(emails);*/
                lead__c leaddata = new lead__c();
                leaddata.Id = recordId;
                leaddata.Admin_Comments__c = Admincomment;
                
                if (data == 'Approve' && Adminkey == 'Admin') {
                    leaddata.Admin_Approve__c = true;
                    leaddata.Admin_Not_Approve__c = false;
                    leaddata.Approval_status__c='Approved';
                    leaddata.Aproved_By_Manager__c=true;
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    
                    /*  List < ContentDocumentLink > documents = [SELECT Id, ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension, ContentDocument.LatestPublishedVersionId from ContentDocumentLink where LinkedEntityId =: leadrecord.Id];
System.debug('Admin Kyc'+documents);
for(ContentDocumentLink con:documents) {
docIdSet.add(con.ContentDocumentId); 
}
if(docIdSet.size()>0) {
List<ContentVersion> cvList = [SELECT VersionData,ContentDocumentId FROM ContentVersion WHERE ContentDocumentId in: docIdSet];
for(ContentVersion conVers:cvList) {
contentMap.put(conVers.ContentDocumentId,conVers.VersionData);
}
}
for (ContentDocumentLink docLink: documents) {
Messaging.EmailFileAttachment emailAttachment = new Messaging.EmailFileAttachment();
emailAttachment.setFileName(docLink.ContentDocument.Title + '.' + docLink.ContentDocument.FileExtension);
//   ContentVersion cv = [SELECT VersionData FROM ContentVersion WHERE ContentDocumentId =: docLink.ContentDocumentId LIMIT 1];
if(contentMap.containsKey(docLink.ContentDocumentId)) {
emailAttachment.setBody(contentMap.get(docLink.ContentDocumentId));

}
emailAttachments.add(emailAttachment);
}*/
                    
                    List<ContentDocumentLink> docLinks = [
                        SELECT ContentDocumentId 
                        FROM ContentDocumentLink 
                        WHERE LinkedEntityId = :recordId
                    ];
                    system.debug('docLinks:--->>>'+docLinks);
                    
                    if (!docLinks.isEmpty()) {
                        Set<Id> contentDocumentIds = new Set<Id>();
                        for (ContentDocumentLink docLink : docLinks) {
                            contentDocumentIds.add(docLink.ContentDocumentId);
                        }
                        system.debug('contentDocumentIds:--->>>'+contentDocumentIds);
                        
                        // Retrieve the ContentDocuments and their related ContentVersions (for file data)
                        List<ContentVersion> versions = [
                            SELECT Id, Title, VersionData, ContentDocumentId 
                            FROM ContentVersion 
                            WHERE ContentDocumentId IN :contentDocumentIds
                        ];
                        
                        List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
                        
                        // Add the PDF files as attachments
                        for (ContentVersion version : versions) {
                            System.debug('Version title'+version.Title);
                            if(version.Title.contains('AOF')) {
                                
                                Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                                attachment.setFileName(version.Title);
                                attachment.setBody(version.VersionData);
                                attachments.add(attachment);
                            }
                            
                        }
                        System.debug('Attachement0-----'+attachments);
                        // Add the attachments to the email
                        mail.setFileAttachments(attachments);
                        
                    }
                    
                    
                    String JSMvfPageUrl = ApprovalController.fetchCustomSetting('SAP') + leadrecord.id + '';
                    System.debug('Lead record'+leadrecord);
                    List<Sales_Data_Kyc_Form__c> slsDataList=[SELECT Id,Email__c,Country__c,State__c,Plant__c,Sales_District__c,Sales_Officer__c from Sales_Data_Kyc_Form__c where Sales_Officer__c=:leadrecord.Sales_Office__c AND Plant__c=:leadrecord.Plant__c];
                    String branchemail;
                    if (!slsDataList.isEmpty()) {
                        branchemail = slsDataList[0].Email__c;
                    }
                    System.debug('ZSM Email'+leadrecord.GM_NSM__r.Email);
                    mail.setToAddresses(label.SAP_Customer_Creation.contains(',') ? label.SAP_Customer_Creation.split(',') : new List<String>{label.SAP_Customer_Creation});
                    // Set subject
                    mail.setSubject('New Conversion'+' ' + leadrecord.Name +' '+ '-' + 'City:'+' '+ leadrecord.Billing_City__c);
                    
                    // Construct plain text body
                    String plainTextBody = 'Dear Leader,\n\n' +
                        'A new customer conversion has been initiated with the following details:\n\n'+
                        'Name : ' + leadrecord.Name + '\n' +
                        'Hospital : ' + leadrecord.Company__c + '\n' +
                        'Address : ' + leadrecord.Billing_Street__c+',' + leadrecord.Billing_City__c +'\n'+
                        'City : ' + leadrecord.Billing_City__c + '\n' +
                        'State : ' + leadrecord.Billing_state__c + '\n' +
                        'Pincode : ' + leadrecord.Billing_code__c + '\n' +
                        'Mobile No. : ' + leadrecord.Mobile__c + '\n\n' +
                        'Customer Email Id : '+ leadrecord.Email__c + '\n' +
                        'Regional Sales Manager Email Id (Branch Email) : '+ branchemail +'\n\n'+
                        'Please check the Know Your Customer (KYC) details by clicking the link:\n\n' +
                        JSMvfPageUrl + '\n' +
                        'Kindly approve/ send back the conversion request'+'\n\n'+
                        'Regards,\n' +
                        'Salesforce Admin'+'\n'+
                        'Biotech Healthcare';
                    
                    mail.setPlainTextBody(plainTextBody);
                    //mail.setFileAttachments(emailAttachments);
                    mail.setOrgWideEmailAddressId(oweaList[0].Id);
                    // Send email
                    //   Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                    Messaging.SendEmailResult[] emailResults = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail}, false);
                    for (Messaging.SendEmailResult emailResult : emailResults) {
                        if (emailResult.isSuccess()) {
                            System.debug('Email sent successfully to: ' + leadrecord.User__r.Email);
                        } else {
                            System.debug('Failed to send email to: ' + leadrecord.User__r.Email);
                            for (Messaging.SendEmailError error : emailResult.getErrors()) {
                                System.debug('Error: ' + error.getMessage());
                            }
                        }
                    }
                    System.debug('Adminkycmethod'+JSON.serialize(mail));
                    // Optionally, add documents to the document list for tracking purposes
                    //    documentLinks.addAll(documents);
                    
                } else if (data == 'Reject' && Adminkey == 'Admin') {
                    /*    email.setToAddresses(new String[] {leadrecord.User__r.Email}); // recipient email address
string recordUrl =  ApprovalController.getRecordUrl(leadrecord.Id);
system.debug('recordUrl'+recordUrl);
email.setSubject('Rejection on New Conversion'+' ' + leadrecord.Name +' '+ '-' + 'City:'+' '+ leadrecord.Billing_City__c);


email.setPlainTextBody(rejectedMail(leadrecord));
email.setOrgWideEmailAddressId(oweaList[0].Id); // Replace with Org-Wide Email Address Id
emails.add(email);
Messaging.sendEmail(emails);*/
                    System.debug('Email data'+emails);
                    leaddata.Admin_Approve__c = false;
                    leaddata.Admin_Not_Approve__c = true;
                    leaddata.RSM_Approve__c=true;
                    leaddata.ZSM_Approve__c=true;
                    leaddata.GM_NSM_Approve__c=false;
                    leaddata.RSM_Not_Approve__c=false;
                    leaddata.ZSM_Not_Approve__c=false;
                    leaddata.GM_NSM_Not_Approve__c=false;
                    
                }
                
                update leaddata;
                resultMap.put('status', 'success');
                resultMap.put('message', data + ' submitted successfully.');
                System.debug(resultMap);
                return resultMap;
            }
        } catch (Exception e) {
            resultMap.put('status', 'error');
            resultMap.put('message', 'An error occurred: ' + e.getMessage());
            System.debug('Error: ' + e.getMessage());
            return resultMap;
        }
    }
    
    @RemoteAction
    public static Map<String, Object> JSMSAPcodemethod(String data, String SAPcode, String recordId, String JSMkey) {
        System.debug('Inside data');
        Map<String, Object> resultMap = new Map<String, Object>();
        try {
            OrgWideEmailAddress[] oweaList = [SELECT Id, Address FROM OrgWideEmailAddress WHERE Address = 'crmhelpdesk@biotechhealthcare.com' LIMIT 1];
            
            lead__c leadrecord = [SELECT Id, SAP_Code__c FROM lead__c WHERE Id = :recordId LIMIT 1];
            System.debug('Lead record'+leadrecord);
            // Check if the SAP_Code__c is already filled and the JSMkey is 'JSM'
            if (leadrecord.SAP_Code__c != null && JSMkey == 'JSM') {
                resultMap.put('status', 'error');
                resultMap.put('message', 'You have already filled the SAP code');
                System.debug(resultMap);
                return resultMap;
            } else {
                // Update the lead record with the new SAP code and change the lead stage
                lead__c leaddata = new lead__c();
                leaddata.Id = recordId;
                leaddata.SAP_Code__c = SAPcode;
                leaddata.Actual_Commercialization_week__c = system.today();
                //  leaddata.Lead_Stage__c = 'Won';
                
                update leaddata; 
                lead__c leadUpdateData = [SELECT Id,Name,Mobile__c,ZSM_Comments__c,Sales_Office__c,Plant__c,SAP_Code__c,User__c,User__r.Email,Billing_code__c,Billing_Street__c,Email__c,Company__c, country__c,ZSM_Approve__c,ZSM_Not_Approve__c,Product__c,Billing_state__c,GM_NSM__c,GM_NSM__r.Email,Billing_City__c,Owner.Name,RSM_Approve__c,ZSM__c,ZSM__r.Email, RSM_Not_Approve__c FROM lead__c WHERE Id = :leaddata.Id LIMIT 1];
                List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
                
                List<Sales_Data_Kyc_Form__c> slsDataList=[SELECT Id,Country__c,Email__c,State__c,Plant__c,Sales_District__c,Sales_Officer__c from Sales_Data_Kyc_Form__c where Sales_Officer__c=:leadUpdateData.Sales_Office__c AND Plant__c=:leadUpdateData.Plant__c];
                if(slsDataList.size()>0) {
                    
                    List<ContentDocumentLink> docLinks = [
                        SELECT ContentDocumentId 
                        FROM ContentDocumentLink 
                        WHERE LinkedEntityId = :recordId
                    ];
                    system.debug('docLinks:--->>>'+docLinks);
                    
                    if (!docLinks.isEmpty()) {
                        Set<Id> contentDocumentIds = new Set<Id>();
                        for (ContentDocumentLink docLink : docLinks) {
                            contentDocumentIds.add(docLink.ContentDocumentId);
                        }
                        system.debug('contentDocumentIds:--->>>'+contentDocumentIds);
                        
                        // Retrieve the ContentDocuments and their related ContentVersions (for file data)
                        List<ContentVersion> versions = [
                            SELECT Id, Title, VersionData, ContentDocumentId 
                            FROM ContentVersion 
                            WHERE ContentDocumentId IN :contentDocumentIds
                        ];
                        
                        
                        // Add the PDF files as attachments
                        for (ContentVersion version : versions) {
                            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                            attachment.setFileName(version.Title);
                            attachment.setBody(version.VersionData);
                            attachments.add(attachment);
                        }
                        System.debug('Attachement0-----'+attachments);
                        // Add the attachments to the email
                        
                    }
                    Messaging.SingleEmailMessage mail1 = new Messaging.SingleEmailMessage();
                    mail1.setToAddresses(slsDataList[0].Email__c.contains(',') ? slsDataList[0].Email__c.split(',') : new List<String>{slsDataList[0].Email__c});
                    mail1.setSubject('Branch Notification');
                    mail1.setHtmlBody(generateBranchSAPMail(leadUpdateData));
                    mail1.setFileAttachments(attachments);
                    
                    //  system.debug('plainTextBody' + plainTextBody);
                    //    mail.setFileAttachments(emailAttachments);
                    mail1.setOrgWideEmailAddressId(oweaList[0].Id);
                    Messaging.SendEmailResult[] emailResults1 = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail1}, false);
                    for (Messaging.SendEmailResult emailResult : emailResults1) {
                        if (emailResult.isSuccess()) {
                            System.debug('Email sent successfully to: ' + slsDataList[0].Email__c);
                        } else {
                            System.debug('Failed to send email to: ' + slsDataList[0].Email__c);
                            for (Messaging.SendEmailError error : emailResult.getErrors()) {
                                System.debug('Error: ' + error.getMessage());
                            }
                        }
                    }
                    
                }
                
                
                
                
                
                resultMap.put('status', 'success');
                resultMap.put('message', data + ' submitted successfully.');
                System.debug(resultMap);
                return resultMap;
            }
        } catch (Exception e) {
            resultMap.put('status', 'error');
            resultMap.put('message', 'An error occurred: ' + e.getMessage());
            System.debug('Error: ' + e.getMessage());
            return resultMap;
        }
    }
    
    public String getRecordId() {
        return ApexPages.currentPage().getParameters().get('recordId');
    }
    
    public static String getRecordUrl(Id recordId) {
        // Check if the provided Id is valid
        if (recordId == null) {
            throw new IllegalArgumentException('Record ID cannot be null.');
        }
        
        // Get the base URL of the current Salesforce instance
        String baseUrl = URL.getCurrentRequestUrl().getHost(); // Get the host of the current request
        String protocol = 'https://'; // Use HTTPS protocol
        String fullBaseUrl = protocol + baseUrl; // Construct the full base URL
        
        // Construct the full record URL for Lightning Experience
        String recordUrl = fullBaseUrl + '/lightning/r/' + recordId.getSObjectType().getDescribe().getName() + '/' + recordId + '/view';
        
        // Debug the constructed record URL
        System.debug('Record URL: ' + recordUrl);
        
        return recordUrl;
    }
    
    
    public static string generateMail(String urlData,Lead__c leadrecord) {
        String plainTextBody = 'Dear Leader,\n\n' +
            'A new customer has been initiated with the following details:\n\n'+
            'Name : ' + leadrecord.Name + '\n' +
            'Hospital : ' + leadrecord.Company__c + '\n' +
            'Address : ' + leadrecord.Billing_Street__c+',' + leadrecord.Billing_City__c +'\n'+
            'City : ' + leadrecord.Billing_City__c + '\n' +
            'State : ' + leadrecord.Billing_state__c + '\n' +
            'Pincode : ' + leadrecord.Billing_code__c + '\n' +
            'Mobile No. : ' + leadrecord.Mobile__c + '\n' +
            'Email : '+ leadrecord.Email__c + '\n\n' +
            'Please check the Know Your Customer (KYC) details by clicking the link:\n\n' +
            urlData + '\n' +
            'Kindly approve/ send back the conversion request'+'\n\n'+
            'Regards,\n' +
            'Salesforce Admin'+'\n'+
            'Biotech Healthcare';
        return plainTextBody;
    }
    public static string generateBranchMail(Lead__c leadrecord) {
        String htmlBody = 
            'Dear Branch Support team,<br><br>' +
            'A new customer conversion has been initiated with the following details:<br><br>' +
            //'SAP CODE : <b>' + leadrecord.SAP_Code__c + '</b><br>' +
            'Name : ' + leadrecord.Name + '<br>' +
            'Hospital : ' + leadrecord.Company__c + '<br>' +
            'Address : ' + leadrecord.Billing_Street__c + ', ' + leadrecord.Billing_City__c + '<br>' +
            'City : ' + leadrecord.Billing_City__c + '<br>' +
            'State : ' + leadrecord.Billing_state__c + '<br>' +
            'Pincode : ' + leadrecord.Billing_code__c + '<br>' +
            'Mobile No. : ' + leadrecord.Mobile__c + '<br>' +
            'Email : ' + leadrecord.Email__c + '<br>' +
            'RSM Email : ' + leadrecord.RSM_Email__c + '<br><br>' +
            'We will notify once customer code is created by SAP team.<br><br>' +
            'Thank you,<br>' +
            'Admin<br>' +
            'Biotech Vision Care Pvt. Ltd';
        return htmlBody;
    }
    public static string generateBranchSAPMail(Lead__c leadrecord) {
        String htmlBody = 'Dear team,<br><br>' +
            'New customer SAP code has been created, please find details below of the same:<br><br>' +
            'SAP Code : <b>' + leadrecord.SAP_Code__c + '</b><br>' +
            'Name : ' + leadrecord.Name + '<br>' +
            'Hospital : ' + leadrecord.Company__c + '<br>' +
            'Address : ' + leadrecord.Billing_Street__c + ', ' + leadrecord.Billing_City__c + '<br>' +
            'City : ' + leadrecord.Billing_City__c + '<br>' +
            'State : ' + leadrecord.Billing_state__c + '<br>' +
            'Pincode : ' + leadrecord.Billing_code__c + '<br>' +
            'Mobile No. : ' + leadrecord.Mobile__c + '<br>' +
            'Email : ' + leadrecord.Email__c + '<br><br>' +
            'You may start billing process for this customer.<br><br>' +
            'Thank you,<br>' +
            'Admin<br>' +
            'Biotech Vision Care Pvt. Ltd';
        return htmlBody;
    }
    
    
    public static string rejectedMail(Lead__c leadrecord) {
        String plainTextBody = 'Dear Leader,\n\n' +
            'A new customer has been rejected with the following details:\n\n'+
            'Name : ' + leadrecord.Name + '\n' +
            'Hospital : ' + leadrecord.Company__c + '\n' +
            'Address : ' + leadrecord.Billing_Street__c+',' + leadrecord.Billing_City__c +'\n'+
            'City : ' + leadrecord.Billing_City__c + '\n' +
            'State : ' + leadrecord.Billing_state__c + '\n' +
            'Pincode : ' + leadrecord.Billing_code__c + '\n' +
            'Mobile No. : ' + leadrecord.Mobile__c + '\n' +
            'Email : '+ leadrecord.Email__c + '\n\n' +
            'Regards,\n' +
            'Salesforce Admin'+'\n'+
            'Biotech Healthcare';
        return plainTextBody;
    }
    
    /**
* Generate a PDF from a VF page, save it as a ContentVersion,
* and link it to a record (e.g., Lead).
*
* @param leadRec Lead record (must contain Id, First_Name__c, Plant_Code__c, Billing_state__c, Language__c).
* @param pageRef The Visualforce page (e.g., Page.LeadInformationPdf).
* @return The ContentDocumentId of the created PDF.
*/
    public static void generateAndAttachPdf(Lead__c leadRec, String pdfTransLanguage, PageReference pageRef) {
        Blob pdfBlob;
        
        // Ensure page receives the Lead Id
        pageRef.getParameters().put('id', leadRec.Id);
        
        // Pass the override language (can be null or blank)
        if (!String.isBlank(pdfTransLanguage)) {
            pageRef.getParameters().put('lang', pdfTransLanguage);
        }
        
        try {
            pdfBlob = pageRef.getContentAsPDF();
        } catch (VisualforceException e) {
            throw new AuraHandledException('Failed to generate PDF: ' + e.getMessage());
        }
        
        // Build filename with language suffix (override > Lead.Language__c > default en_US)
        String langSuffix = 
            String.isNotBlank(pdfTransLanguage)
            ? '-' + pdfTransLanguage
            : (
                String.isNotBlank(leadRec.Language__c) 
                ? '-' + leadRec.Language__c 
                : '-en_US'
            );
                
                String fileName = 'AOF_' + leadRec.First_Name__c + '-' 
                + leadRec.Plant_Code__c + '-' 
                + leadRec.Billing_State__c + '-' 
                + leadRec.Id + langSuffix + '.pdf';
        
        // Save the PDF as ContentVersion
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName;
        cv.VersionData = pdfBlob;
        cv.IsMajorVersion = true;
        insert cv;
        
        // Fetch ContentDocumentId
        ContentVersion insertedCV = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];
        
        // Link the PDF to the Lead
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = insertedCV.ContentDocumentId;
        cdl.LinkedEntityId = leadRec.Id;
        cdl.ShareType = 'V';
        insert cdl;
    }
    
    
}
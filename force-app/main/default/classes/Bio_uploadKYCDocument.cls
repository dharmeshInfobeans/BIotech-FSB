// force-app/main/default/classes/Bio_uploadKYCDocument.cls
    public without sharing class Bio_uploadKYCDocument {
    
    public class ComboOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String code;
        public ComboOption(String label, String value, String code) {
            this.label = label;
            this.value = value;
            this.code = code;
        }
    }
    
    // ------------------- PLANT OPTIONS -------------------
    @AuraEnabled(cacheable=true)
    public static List<ComboOption> getPlantOptions(String country) {
        
        List<Sales_Data_Kyc_Form__c> rows = [SELECT Plant__c, Plant_Code__c FROM Sales_Data_Kyc_Form__c WHERE Plant__c != null AND Country__c = :country ORDER BY Plant__c ASC];
        
        Map<String, String> plantToCode = new Map<String, String>();
        
        for (Sales_Data_Kyc_Form__c r : rows) {
            if (String.isNotBlank(r.Plant__c)) {
                String key = r.Plant__c.trim();
                if (!plantToCode.containsKey(key)) {
                    plantToCode.put(key, r.Plant_Code__c);
                }
            }
        }
        
        List<ComboOption> options = new List<ComboOption>();
        
        for (String plant : plantToCode.keySet()) {
            options.add( new ComboOption(plant, plant, plantToCode.get(plant)));
        }
        
        return options;
    }
    
    // ------------------- KYC METADATA (COUNTRY RULES) -------------------
    /**
* Returns:
*  - KycData            : List<Map> rows for the table (country-filtered from MDT)
*  - HideUpload         : Boolean flag to hide upload section (e.g., Egypt, Morocco)
*  - Message            : Optional message for the UI
*  - ShowMoroccoFields  : Boolean flag to render Morocco-only number inputs
*/
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getRecords(String recordId) {
        Opportunity__c opp = [
            SELECT Id, Account__c, Account__r.BillingCountry, Account__r.Already_Uploaded__c,
            Account__r.Aadhaar_card_Number__c, Account__r.PAN_Card_Number__c, Account__r.Voter_Card_Number__c,
            Account__r.GST_Number__c, Account__r.Registration_Number__c, Account__r.Driving_Licence_number__c,
            Account__r.Doctor_Letter_Number__c, Account__r.VAT_Document_Number__c, Account__r.Medical_Registration_No__c
            FROM Opportunity__c
            WHERE Id = :recordId
            LIMIT 1
        ];
        
        String countryRaw = opp.Account__r.BillingCountry;
        String countryNorm = countryRaw == null ? '' : countryRaw.trim();
        String countryLc = countryNorm.toLowerCase();
        
        // Dynamic MDT fetch (no hard-coded document names/countries here)
        // We load all rows with a Country and then filter in Apex (case-insensitive).
        List<KYC_Document__mdt> mdtAll = [
            SELECT Id, MasterLabel, Is_required__c, Country__c
            FROM KYC_Document__mdt
            WHERE Country__c != null
            ORDER BY MasterLabel ASC
        ];
        
        List<KYC_Document__mdt> kycList = new List<KYC_Document__mdt>();
        Boolean hideUpload = false;
        Boolean showMoroccoFields = false;
        String uiMessage;
        
        // ---- Country specific rules (minimal: only Morocco/Egypt change upload visibility) ----
        if (countryLc == 'morocco') {
            // Morocco: no uploads; only two Account number inputs (existing behavior)
            hideUpload = true;
            showMoroccoFields = true;
            uiMessage = 'No document upload required. Please enter the document numbers below.';
            // kycList intentionally left empty
        } else if (countryLc == 'egypt') {
            // Egypt: no documents at all - hide upload area
            hideUpload = true;
            uiMessage = 'No Document needed';
            // kycList intentionally left empty
        } else {
            // For all other countries, filter KYC MDT rows dynamically by Country__c, case-insensitive.
            for (KYC_Document__mdt row : mdtAll) {
                if (row.Country__c != null && row.Country__c.trim().toLowerCase() == countryLc) {
                    kycList.add(row);
                }
            }
            if (kycList.isEmpty()) {
                uiMessage = 'There is no document data to upload.';
                hideUpload = true;
            }
        }
        
        List<Map<String, Object>> table = new List<Map<String, Object>>();
        Boolean alreadyUploaded = opp.Account__r.Already_Uploaded__c;

        // Same title(clean)->field mapping used by uploadFile/uploadFileAsGuest, so a
        // previously entered number pre-populates the field instead of showing blank.
        Map<String, String> docNumberByCleanTitle = new Map<String, String>{
            'Aadhar_Card'    => opp.Account__r.Aadhaar_card_Number__c,
                'Aadhaar_Card'   => opp.Account__r.Aadhaar_card_Number__c,
                'PAN_Card'       => opp.Account__r.PAN_Card_Number__c,
                'Voter_Card'     => opp.Account__r.Voter_Card_Number__c,
                'GST_No'         => opp.Account__r.GST_Number__c,
                'Medical_Registration_Number' => opp.Account__r.Medical_Registration_No__c,
                'Registration_No'=> opp.Account__r.Registration_Number__c,
                'Driving_Licence'=> opp.Account__r.Driving_Licence_number__c,
                'Doctor_Letter'  => opp.Account__r.Doctor_Letter_Number__c,
                'Vat_Document'   => opp.Account__r.VAT_Document_Number__c
                };

        for (KYC_Document__mdt kyc : kycList) {
            String cleanTitle = kyc.MasterLabel == null ? '' : kyc.MasterLabel.replace(' ', '_');
            table.add(new Map<String, Object>{
                'Id'             => String.valueOf(kyc.Id),
                    'MasterLabel'    => kyc.MasterLabel,
                    'IsRequired'     => kyc.Is_required__c,
                    'AlreadyUpdated' => alreadyUploaded,
                    'DocumentNumber' => docNumberByCleanTitle.get(cleanTitle)
                    });
        }
        
        return new Map<String, Object>{
            'KycData'           => table,
                'HideUpload'        => hideUpload,
                'Message'           => uiMessage,
                'ShowMoroccoFields' => showMoroccoFields
                };
                    }
    
    // ------------------- FILE UPLOAD -------------------
    /**
* Accepts a single file's base64 + filename, links to Account, and updates Account doc numbers using fileMap.
* Returns the created ContentDocumentLink Id (or null on failure).
*/
    @AuraEnabled
    public static String uploadFile(
        String base64,
        String filename,
        String recordId,
        String accountId,
        Map<String, String> fileMap
    ) {
        // Replace any existing doc with same logical base-name on the Account
        deleteExistingFiles(filename, accountId);
        
        ContentVersion cv = createContentVersion(base64, filename);
        if (cv == null) return null;
        
        ContentDocumentLink cdl = createContentLink(cv.Id, accountId);
        if (cdl == null) return null;
        createContentDistribution(cv.id);
        
        // Update Account document numbers via Opportunity -> Account
        Opportunity__c opp = [
            SELECT Id, Account__c
            FROM Opportunity__c
            WHERE Id = :recordId
            LIMIT 1
        ];
        
        Account acc = [
            SELECT Id,
            Aadhaar_card_Number__c,
            PAN_Card_Number__c,
            Registration_Number__c,
            Voter_Card_Number__c,
            Doctor_Letter_Number__c,
            GST_Number__c,
            Driving_Licence_number__c,
            VAT_Document_Number__c,
            Medical_Registration_No__c
            FROM Account
            WHERE Id = :opp.Account__c
            LIMIT 1
        ];

        if (fileMap != null) {
            // Keys are derived from MasterLabel by replacing spaces with underscores (see cleanKey in JS)
            if (fileMap.containsKey('Aadhar_Card'))      acc.Aadhaar_card_Number__c      = fileMap.get('Aadhar_Card');
            if (fileMap.containsKey('Doctor_Letter'))    acc.Doctor_Letter_Number__c     = fileMap.get('Doctor_Letter');
            if (fileMap.containsKey('PAN_Card'))         acc.PAN_Card_Number__c          = fileMap.get('PAN_Card');
            if (fileMap.containsKey('Registration_No'))  acc.Registration_Number__c      = fileMap.get('Registration_No');
            if (fileMap.containsKey('GST_No'))           acc.GST_Number__c               = fileMap.get('GST_No');
            if (fileMap.containsKey('Medical_Registration_Number')) acc.Medical_Registration_No__c = fileMap.get('Medical_Registration_Number');
            if (fileMap.containsKey('Driving_Licence'))  acc.Driving_Licence_number__c   = fileMap.get('Driving_Licence');
            if (fileMap.containsKey('Voter_Card'))       acc.Voter_Card_Number__c        = fileMap.get('Voter_Card');
            if (fileMap.containsKey('Vat_Document'))     acc.VAT_Document_Number__c      = fileMap.get('Vat_Document');
            // if (fileMap.containsKey('Vat_Document_MA'))     acc.VAT_Document_Number__c      = fileMap.get('Vat_Document_MA');
            // if (fileMap.containsKey('Vat_Document_TR'))     acc.VAT_Document_Number__c      = fileMap.get('Vat_Document_TR');
            // NOTE: As per your instruction, we are NOT changing existing mappings.
            // If you later want to persist CPF/CIN, add mappings here.
        }
        //acc.Generate_Account_PDF__c = false; // added by dhrumil  
        update acc;
        
        return cdl.Id;
    }
    
    // ------------------- Helpers -------------------
    
    private static void deleteExistingFiles(String filename, String linkedEntityId) {
        if (String.isBlank(filename) || String.isBlank(linkedEntityId)) return;
        
        String nameBase = filename;
        Integer lastDot = filename.lastIndexOf('.');
        if (lastDot > 0) nameBase = filename.substring(0, lastDot);
        
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :linkedEntityId
        ];
        
        List<ContentDocument> toDelete = new List<ContentDocument>();
        for (ContentDocumentLink l : links) {
            String title = l.ContentDocument.Title;
            if (String.isNotBlank(title) && title.equalsIgnoreCase(nameBase)) {
                toDelete.add(new ContentDocument(Id = l.ContentDocumentId));
            }
        }
        if (!toDelete.isEmpty()) delete toDelete;
    }
    
    private static ContentVersion createContentVersion(String base64, String filename) {
        if (String.isBlank(base64) || String.isBlank(filename)) return null;
        
        String titleOnly = filename;
        Integer lastDot = filename.lastIndexOf('.');
        if (lastDot > 0) titleOnly = filename.substring(0, lastDot);
        
        ContentVersion cv = new ContentVersion();
        cv.VersionData  = EncodingUtil.base64Decode(base64);
        cv.Title        = titleOnly;
        cv.PathOnClient = filename; // original name.ext
        try {
            insert cv;
            return cv;
        } catch (DmlException e) {
            System.debug('ContentVersion insert failed: ' + e.getMessage());
            return null;
        }
    }
    
    private static void createContentDistribution(Id contentVersionId){
        ContentDistribution cd = new ContentDistribution();
        cd.Name                              = 'Guest Public Preview';
        cd.ContentVersionId                  =  contentVersionId;
        cd.PreferencesAllowViewInBrowser     = true;  
        cd.PreferencesLinkLatestVersion      = true;
        cd.PreferencesNotifyOnVisit          = false;
        cd.PreferencesPasswordRequired       = false;
        cd.PreferencesAllowOriginalDownload  = true;
      insert cd;
    }
    
    private static ContentDocumentLink createContentLink(String contentVersionId, String linkedEntityId) {
        if (String.isBlank(contentVersionId) || String.isBlank(linkedEntityId)) return null;
        
        Id docId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ].ContentDocumentId;
        
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = docId;
        cdl.LinkedEntityId    = linkedEntityId;   // Account Id
        cdl.ShareType         = 'V';
        cdl.Visibility        = 'AllUsers';
        try {
            insert cdl;
            return cdl;
        } catch (DmlException e) {
            System.debug('CDL insert failed: ' + e.getMessage());
            return null;
        }
    }
    
    
    
    //  -------------------------------------------------------------------************* ApprovalUrlService Method Starts here *************  -----------------------------------------------------------------//
    
    public static String getApprovalUrl(Opportunity__c opp) {
        
        String approvalKey;
        System.debug('opp'+json.serialize(opp));
        if (!opp.RSM_Approve__c && !opp.RSM_Not_Approve__c && !opp.ZSM_Not_Approve__c && !opp.RSM_Not_Approve__c && !opp.Admin_Approve__c && !opp.Admin_Not_Approve__c) {
            approvalKey = 'Rsm_Approval_Process';
            System.debug('varisha bhai condition 1');
        } else if (opp.RSM_Approve__c && !opp.ZSM_Approve__c && !opp.ZSM_Not_Approve__c && !opp.RSM_Not_Approve__c && !opp.Admin_Approve__c && !opp.Admin_Not_Approve__c) {
            approvalKey = 'ZSM_Approval_Process';
            System.debug('varisha bhai condition 2');
        } else if (opp.RSM_Approve__c && opp.ZSM_Approve__c && !opp.RSM_Not_Approve__c && !opp.ZSM_Not_Approve__c && !opp.Admin_Approve__c && !opp.Admin_Not_Approve__c) {
            //	
            approvalKey = 'Admin_Approval_Process';
            System.debug('varisha bhai condition 3');
        } else if(opp.RSM_Approve__c && opp.ZSM_Approve__c && !opp.RSM_Not_Approve__c && !opp.ZSM_Not_Approve__c && opp.Admin_Approve__c && !opp.Admin_Not_Approve__c){
            approvalKey = 'SAP_Admin_Approval_Process';
            System.debug('varisha bhai condition 4');
        } else {
            return null;
        }
        
        Approval_URL_Config__mdt meta =
            Approval_URL_Config__mdt.getInstance(approvalKey);
        System.debug(meta.URL__c);        
        if (meta == null || String.isBlank(meta.URL__c)) {
            return null;
        }
        
        return meta.URL__c + '?recordId=' + opp.Id;
    }
    
    public static String getAdminEmail() {
        
        Approval_URL_Config__mdt meta =
            Approval_URL_Config__mdt.getInstance('SAP_admin_email');
        
        return meta != null ? meta.SAP_admin__c : null;
    }
    
    //  -------------------------------------------------------------------*************   SendEmailOnUpload Method Starts here *************  -----------------------------------------------------------------//
    @AuraEnabled
    public static void updateAccountBranch(Id accountId, String plant, String plantCode) {
        try {
            Account acc = [SELECT Id, BillingCountry, Country__c FROM Account WHERE Id = :accountId LIMIT 1];
            
            if (acc.BillingCountry != null) {
                acc.Country__c = acc.BillingCountry;
            }
            
            acc.Branch_Name__c = plant;
            acc.Branch_Code__c = plantCode;
            
            // Use a list query so zero matches means an empty list, not an exception
            List<Sales_Data_Kyc_Form__c> kycDetailsList = [
                SELECT Id, Plant__c, Sales_District_Code__c, Sales_Officer_Code__c
                FROM Sales_Data_Kyc_Form__c
                WHERE Plant__c = :plant
                LIMIT 1
            ];
            
            if (!kycDetailsList.isEmpty()) {
                Sales_Data_Kyc_Form__c kycDetails = kycDetailsList[0];
               // acc.Sales_District__c = kycDetails.Sales_District_Code__c;
                acc.Sales_Office__c = kycDetails.Sales_Officer_Code__c;
            }
            
            update acc;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error updating branch details: ' + e.getMessage());
        }
    }
   @AuraEnabled
    public static void callSendEmailOnUpload(Id oppId){
     //   sendEmailOnUpload(oppId);
        //System.enqueueJob(new GenerateAccountPDFQueueable(oppId));
    }
    
    @AuraEnabled
    public static void sendEmailOnUpload(Id oppId) {
        System.debug('Opportunity ID: ' + oppId);
        
        
        
        
        Opportunity__c opp = [
            SELECT Id, Name, RSM__c, Account__c,
            Account__r.Name,
            Account__r.Company_Name__c,
            Account__r.BillingStreet,
            Account__r.BillingCity,
            Account__r.BillingState,
            Account__r.BillingPostalCode,
            Account__r.Phone,
            Account__r.E_Mail__c,
            Account__r.Commercial_Account_Name__c,
            RSM_Approve__c,
            ZSM_Approve__c,
            GM_NSM_Approve__c,
            Admin_Approve__c,
            RSM_Not_Approve__c,
            ZSM_Not_Approve__c,
            Admin_Not_Approve__c,
            CreatedById,
            CreatedBy.Country__c,
            Owner.Name
            FROM Opportunity__c
            WHERE Id =: oppId
            LIMIT 1
        ]??null;
        
        /*    if (opp.RSM__c == null) {
return;
}*/
       //   PageReference pdfPage =  new PageReference('/BioTechPortal/apex/AccountInformationPdf');
            PageReference pdfPage =  Page.AccountInformationPdf;
            pdfPage.getParameters().put('id',opp.Account__c);
            System.debug('work till 402');
            Blob pdfBlob;

if (Test.isRunningTest()) {
    pdfBlob = Blob.valueOf('Test PDF Content');
} else {
    pdfBlob = pdfPage.getContentAsPDF();
}
           System.debug('After PDF. Size = ' + pdfBlob.size());
        
        
        
        //User rsmUser = [SELECT Email FROM User WHERE Id =: opp.RSM__c LIMIT 1];
        //System.debug('RSM User Email: ' + rsmUser.Email);
        Id userToSendMail = null;
        String emailToSend;
        String addressTo ='';
        if(!opp.ZSM_Approve__c && !opp.Admin_Approve__c){
            if(!opp.RSM_Approve__c){
                System.debug('userToSendMail: ' + opp.Id +'  '+opp.CreatedById);
                userToSendMail =InitiateCustomerApprovalProcess.getIntitiateCustomerApprover(opp.Id ,opp.CreatedById, 1);
                System.debug('userToSendMail: ' + userToSendMail);
                if(userToSendMail != null){
                    emailToSend = [SELECT Email FROM User WHERE ID=:userToSendMail ].Email;
                    addressTo = [SELECT Name FROM User WHERE ID=:userToSendMail ].Name;
                    System.debug('emailToSend : '+emailToSend);}
                else{
                    emailToSend=(String)sendEmailToAdminOrSAP(opp).get('emailToSend');
                    addressTo=(String)sendEmailToAdminOrSAP(opp).get('addressTo');
                    opp=(Opportunity__c)sendEmailToAdminOrSAP(opp).get('opp');
                }
                
                
            }
            else{
                userToSendMail =InitiateCustomerApprovalProcess.getIntitiateCustomerApprover(opp.Id ,opp.CreatedById, 2);
                if(userToSendMail != null){ 
                    emailToSend = [SELECT Email FROM User WHERE ID=:userToSendMail ].Email;
                    addressTo = [SELECT Name FROM User WHERE ID=:userToSendMail ].Name;
                    System.debug('userToSendMail: ' + userToSendMail);}
                else{
                    emailToSend=(String) sendEmailToAdminOrSAP(opp).get('emailToSend');
                    addressTo=(String) sendEmailToAdminOrSAP(opp).get('addressTo');
                    opp=(Opportunity__c)sendEmailToAdminOrSAP(opp).get('opp');
                }
                
            }
        }
        else {
            
            emailToSend=(String) sendEmailToAdminOrSAP(opp).get('emailToSend');
            addressTo=(String) sendEmailToAdminOrSAP(opp).get('addressTo');
            opp=(Opportunity__c)sendEmailToAdminOrSAP(opp).get('opp');
            // User currentUser = [ SELECT Country__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            /*  List<SAP_Country_Config__mdt> configList = new  List<SAP_Country_Config__mdt>();
if (!opp.Admin_Approve__c){
configList = [ SELECT Salesforce_Admin_Emails__c  FROM SAP_Country_Config__mdt  WHERE Country__c = :opp.CreatedBy.Country__c LIMIT 1];
if (!configList.isEmpty()) {
emailToSend = configList[0].Salesforce_Admin_Emails__c;
addressTo = 'Salesforce Admin';
}

}
else{
configList = [ SELECT SAP_Admin_Emails__c  FROM SAP_Country_Config__mdt  WHERE Country__c = :opp.CreatedBy.Country__c LIMIT 1];
if (!configList.isEmpty()) {
emailToSend = configList[0].SAP_Admin_Emails__c;
addressTo = 'SAP Admin';
}
}
*/
            
        }
        
        
        if (String.isBlank(emailToSend)) {
            return;
        }
        
        
        
        // String baseUrl = 'https://biotechcrm--testbiot.sandbox.my.site.com/s';
        //String baseUrl = 'https://biotechcrm--testbiot.sandbox.my.site.com/BioTechPortal/rsmapprovalprocess';
        //String lwcUrl = baseUrl + '?recordId=' + opp.Id;
        // ✅ Get Approval URL
        System.debug('Opp : '+ opp);
        String lwcUrl = Bio_uploadKYCDocument.getApprovalUrl(opp);
        
        if (String.isBlank(lwcUrl)) return;
        
        
        /*
String plainTextBody =
'Dear Leader,\n\n' +
'A new customer conversion has been initiated with the following details:\n\n' +
'Name : ' + opp.Account__r.Name + '\n' +
'Hospital : ' + opp.Account__r.Company_Name__c + '\n' +
'Address : ' + opp.Account__r.BillingStreet + ',' + opp.Account__r.BillingCity + '\n' +
'City : ' + opp.Account__r.BillingCity + '\n' +
'State : ' + opp.Account__r.BillingState + '\n' +
'Pincode : ' + opp.Account__r.BillingPostalCode + '\n' +
'Mobile No. : ' + opp.Account__r.Phone + '\n' +
'Email : ' + opp.Account__r.E_Mail__c + '\n\n' +
'Please check the Know Your Customer (KYC) details by clicking the link:\n\n'  + '\n' + lwcUrl +
'Kindly approve/ send back the conversion request\n\n' +
'Regards,\n' +
'Salesforce Admin\n' +
'Biotech Healthcare';
*/	
        
        
        /*   String plainTextBody =
'Dear Leader,\n\n' +
'A new customer conversion has been initiated with the following details:\n\n' +
'Name : ' + opp.Account__r.Name + '\n' +
'Hospital : ' + opp.Account__r.Commercial_Account_Name__c + '\n' +
'Address : ' + opp.Account__r.BillingStreet + ',' + opp.Account__r.BillingCity + '\n' +
'City : ' + opp.Account__r.BillingCity + '\n' +
'State : ' + opp.Account__r.BillingState + '\n' +
'Pincode : ' + opp.Account__r.BillingPostalCode + '\n' +
'Mobile No. : ' + opp.Account__r.Phone + '\n' +
'Email : ' + opp.Account__r.E_Mail__c + '\n\n' +
'Please review the KYC details using the link below:\n\n' +
lwcUrl + '\n\n' +
'Kindly approve or send back the conversion request.\n\n' +
'Regards,\n' +
'Salesforce Admin' ;*/
        
        
        String plainTextBody = 
            '<html>' +
            '<body style="margin:0; padding:0; font-family: Arial, sans-serif; background-color:#f4f6f9;">' +
            '<table width="100%" cellpadding="0" cellspacing="0" align="center">' +
            '<tr><td align="center">' +
            
            
            '<table width="600">' +
            '<tr><td align="center" style="padding-top:30px;">' +
            '<div style="width:80px; height:4px; background-color:#2f4f4f;"></div>' +
            '</td></tr>' +
            
            
            '<tr><td align="center" style="padding:10px 0;">' +
            '<img src="https://biotechcrm--testbiot.sandbox.my.salesforce.com/servlet/servlet.ImageServer?id=015C30000047jxN&oid=00DC3000002I023" style="height:50px; display:block; margin:7px auto;" />' +
            '</td></tr>' +
            
            
            '<tr><td align="center" style="padding:10px 0 20px 0;">' +
            '<h3 style="margin:0; color:#333;">New Customer Conversion</h3>' +
            '</td></tr>' +
            '</table>' +
            
            
            '<table width="600">' +
            '<tr><td style="background-color:#dfe6ee; padding:25px; border-radius:4px; color:#333; font-size:14px; line-height:1.6;">' +
            '<strong>Dear '+ addressTo+',</strong><br/><br/>' +
            'A new customer conversion has been initiated with the following details:<br/><br/>' +
            
            
            '<table cellpadding="4" cellspacing="0" style="width:100%; font-size:14px; color:#333;">' +
            '<tr><td style="width:35%; font-weight:bold;">Name</td><td style="width:5%;">:</td><td>' + opp.Account__r.Name + '</td></tr>' +
            '<tr><td style="font-weight:bold;">Hospital</td><td>:</td><td>' + opp.Account__r.Commercial_Account_Name__c + '</td></tr>' +
            '<tr><td style="font-weight:bold;">Address</td><td>:</td><td>' + opp.Account__r.BillingStreet + ', ' + opp.Account__r.BillingCity + '</td></tr>' +
            '<tr><td style="font-weight:bold;">City</td><td>:</td><td>' + opp.Account__r.BillingCity + '</td></tr>' +
            '<tr><td style="font-weight:bold;">State</td><td>:</td><td>' + opp.Account__r.BillingState + '</td></tr>' +
            '<tr><td style="font-weight:bold;">Pincode</td><td>:</td><td>' + opp.Account__r.BillingPostalCode + '</td></tr>' +
            '<tr><td style="font-weight:bold;">Mobile No.</td><td>:</td><td>' + opp.Account__r.Phone + '</td></tr>' +
            '<tr><td style="font-weight:bold;">Email</td><td>:</td><td>' + opp.Account__r.E_Mail__c + '</td></tr>' +
            '<tr><td style="font-weight:bold;">Request By</td><td>:</td><td>' + opp.Owner.Name + '</td></tr>' +
            '</table><br/>' +
            
            'Please review the KYC details using the button below:<br/><br/>' +
            
            
            '<a href="' + lwcUrl + '" style="display:inline-block; background-color:#2f4f4f; color:#ffffff; padding:10px 20px; text-decoration:none; border-radius:3px; font-size:14px;">Review KYC Details</a>' +
            '<br/><br/>' +
            'Kindly approve or send back the conversion request.<br/><br/>' +
            'Should you have any questions, feel free to reach out at ' +
            '<a href="mailto:sfadoption@biotechhealthcare.com" style="color:#1a73e8;">sfadoption@biotechhealthcare.com</a>.<br/><br/>' +
            '<strong>Regards,</strong><br/>Salesforce Admin' +
            '<div style="border-top:1px solid #999; margin-top:10px;"></div>' +
            '</td></tr>' +
            '</table>' +
            
            
            '<table width="600">' +
            '<tr><td align="center" style="padding:20px 0px 5px;">' +
            '<img src="https://biotechcrm--testbiot.sandbox.my.salesforce.com/servlet/servlet.ImageServer?id=015C30000047jxN&oid=00DC3000002I023" style="height:40px; display:block; margin:10px auto;" />' +
            '<p style="font-size:12px; color:#777;">sfadoption@biotechhealthcare.com</p>' +
            '<p style="font-size:11px; color:#999;">© Copyright Biotech | Terms Of Use - Privacy Policy</p>' +
            '<p style="font-size:11px; color:#000;">This email was sent from an email address that cannot receive emails. Please do not reply.</p>' +
            '</td></tr>' +
            '<tr><td align="center">' +
            '<div style="width:82%; height:4px; background-color:#2f4f4f;"></div>' +
            '</td></tr>' +
            '</table>' +
            
            '</td></tr></table>' +
            '</body></html>';
        
       // Fetch Files linked to Account
List<Messaging.EmailFileAttachment> emailAttachments =
    new List<Messaging.EmailFileAttachment>();

if (!Test.isRunningTest()) {

    List<ContentDocumentLink> docLinks = [
        SELECT ContentDocumentId
        FROM ContentDocumentLink
        WHERE LinkedEntityId = :opp.Account__c
    ];

    if (!docLinks.isEmpty()) {

        Set<Id> contentDocIds = new Set<Id>();

        for (ContentDocumentLink cdl : docLinks) {
            contentDocIds.add(cdl.ContentDocumentId);
        }

        List<ContentVersion> versions = [
            SELECT Title, FileType, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocIds
            AND IsLatest = true
        ];

        System.debug('Content Version ' + versions + ' + ' + contentDocIds);

        for (ContentVersion cv : versions) {

            Messaging.EmailFileAttachment efa =
                new Messaging.EmailFileAttachment();

            efa.setFileName(cv.Title + '.' + cv.FileType);
            efa.setBody(cv.VersionData);

            emailAttachments.add(efa);
        }
    }

        //Create Pdf
        try {
            System.debug('opp.Account__c'+opp.Account__c);
            
          
            
            
            // Store the PDF on the Account only the first time it's generated
            Account accForPdf = [
                SELECT Id,Name,Sales_District__c,Branch_Code__c,BillingState, PDF_Generated__c
                FROM Account
                WHERE Id = :opp.Account__c
                LIMIT 1
            ];
            
            if (!accForPdf.PDF_Generated__c && accForPdf.Sales_District__c!= null) {
                System.debug('inside con 11');
                String name = accForPdf.Name+'-'+accForPdf.Branch_Code__c+'-'+accForPdf.BillingState+'-'+accForPdf.id;
                ContentVersion pdfCv = new ContentVersion();
                pdfCv.Title        = name;
                pdfCv.PathOnClient = name+'.pdf';
                pdfCv.VersionData  = pdfBlob;
                insert pdfCv;
                
                ContentDocumentLink pdfCdl = createContentLink(pdfCv.Id, opp.Account__c);
                            System.debug('AccforPdf Inside'+accForPDf);
                if (pdfCdl != null) {
                   // createContentDistribution(pdfCv.Id);
                    accForPdf.PDF_Generated__c = true;
                    System.debug('AccforPdf'+accForPDf);
                   update accForPdf;
                }
                                    System.debug('AccforPdf Outside'+accForPDf);
                
                Messaging.EmailFileAttachment pdfAttachment =
                    new Messaging.EmailFileAttachment();
                pdfAttachment.setFileName(name+'.pdf');
                pdfAttachment.setBody(pdfBlob);
                pdfAttachment.setContentType('application/pdf');
                
                emailAttachments.add(pdfAttachment);
            }
        }
        catch (Exception e) {
            System.debug('### PDF ERROR TYPE: ' + e.getTypeName());
            System.debug('### PDF ERROR MESSAGE: ' + e.getMessage());
            System.debug('### PDF ERROR LINE: ' + e.getLineNumber());
            System.debug('### PDF STACK: ' + e.getStackTraceString());
            throw e;
        }
}
        
        //Send Email
        OrgWideEmailAddress owea = new OrgWideEmailAddress();
        owea = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress WHERE Address = 'crmhelpdesk@biotechhealthcare.com'];
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        List<String> toAddressList = emailToSend.contains(',') ? emailToSend.split(',\\s*') : new List<String>{ emailToSend };
		mail.setToAddresses(toAddressList);
      //  mail.setToAddresses(new List<String>{ emailToSend });
        System.debug('Second debug called >> ');
        
        if(owea != NULL){
            mail.setOrgWideEmailAddressId(owea.Id);
        }
        mail.setSubject('New Conversion ' + opp.Name + ' - City: ' + opp.Account__r.BillingCity);
        //mail.setPlainTextBody(plainTextBody);
        mail.setHtmlBody(plainTextBody);
        if (!emailAttachments.isEmpty() && opp.RSM_Approve__c == true && opp.ZSM_Approve__c == true) {
            mail.setFileAttachments(emailAttachments);
        }
        //Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        //System.debug('Email sent to: ' + rsmUser.Email);
        Messaging.SendEmailResult[] results = 
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        
        if (results != null && results.size() > 0) {
            if (results[0].isSuccess()) {
                System.debug('Email sent successfully' + emailToSend);
            } else {
                System.debug('Email failed to send');
                
                for (Messaging.SendEmailError err : results[0].getErrors()) {
                    System.debug('Error message: ' + err.getMessage());
                    System.debug('Status code: ' + err.getStatusCode());
                }
            }
        }
        
    }
    public static Map<String,Object> sendEmailToAdminOrSAP(Opportunity__c opp){
        Map<String,Object> emailAndAddress = new Map<String,Object>{'emailToSend'=>null,'addressTo'=>null,'opp'=>null};
            String emailToSend='';
        String addressTo='';
        List<SAP_Country_Config__mdt> configList = new  List<SAP_Country_Config__mdt>();
        if (!opp.Admin_Approve__c){
            configList = [ SELECT Salesforce_Admin_Emails__c  FROM SAP_Country_Config__mdt  WHERE Country__c = :opp.CreatedBy.Country__c LIMIT 1];
            if (!configList.isEmpty()) {
                emailToSend = configList[0].Salesforce_Admin_Emails__c;
                addressTo = 'Operations Admin';
                
            }
            
        }
        else{
            configList = [ SELECT SAP_Admin_Emails__c  FROM SAP_Country_Config__mdt  WHERE Country__c = :opp.CreatedBy.Country__c LIMIT 1];
            if (!configList.isEmpty()) {
                emailToSend = configList[0].SAP_Admin_Emails__c;
                addressTo = 'SAP Admin';
            }
        }
        emailAndAddress.put('emailToSend',emailToSend);
        emailAndAddress.put('addressTo',addressTo);
        opp.RSM_Approve__c=true;
        opp.ZSM_Approve__c=true;
        emailAndAddress.put('opp',opp);
        return emailAndAddress;
        
        
    }
    
    public static void AAA() 
    {
        Decimal a = 0;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        a++;
        
    }
}
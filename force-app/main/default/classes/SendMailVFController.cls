public without sharing class SendMailVFController {
    
    public Id recordId { get; set; }
    
    public Blob uploadedFile { get; set; }
    public String uploadedFileName { get; set; }
    
    public String Comment { get; set; }
    public Boolean showPopup { get; set; }
    public String popupMessage { get; set; }
    public Event eventData { get; set; }
    public string publicurl {get; set;}
    public string name {get; set;}
    public string recordname { get; set; }
    
    public string approverfirstname { get; set; }
    public string approverLastname { get; set; }
    
    // Dynamic fields
    public String sapCode { get; set; }
    public String ceCisRating { get; set; }
    public String phakicRating { get; set; }
    public String activitydate { get; set; }
    public String countryname { get; set; }
    public String statename { get; set; }
    public String cityname { get; set; }
    public String streetname { get; set; }
    public String url { get; set; }
    public String Description { get; set; }
    public String customercommnet { get; set; }
    public String subject { get; set; }
    public String calltype { get; set; }
    public String subcalltype { get; set; }
    
    public string thanksurl { get; set; }
    
    public Boolean mailSent { get; set; }
    
    public SendMailVFController() {
        mailSent = false;
        
        recordId = ApexPages.currentPage()
            .getParameters()
            .get('id');
        
        customer_creation_url__c urls = customer_creation_url__c.getValues('Customer Creation urls');
        thanksurl = urls.Thank_you_url__c;
        
        system.debug('recordId-->: '+recordId);
        
        if (String.isBlank(recordId)) {
            return;
        }
        
        try {
            Event ev = [
                SELECT Id, Subject, Description, Type,OwnerId, Call_Type__c,
                Visit_Date__c, Status__c, ActivityDate,Approver_comment__c,
                Country__c, State__c, BillingCity__c,Requester_Comment__c,
                Sub_Call_Type__c, BillingStreet__c,
                DCR_Description__c,
                
                Owner.FirstName, Owner.LastName,
                
                Leads__r.Name,
                Leads__r.SAP_Code__c,
                Leads__r.Country__c,
                Leads__r.Billing_State__c,
                Leads__r.CE_CIS_Rating__c,
                Leads__r.Billing_City__c,
                Leads__r.Billing_Street__c,
                Leads__r.Phakic_Rating__c,
                
                Account__r.Name,
                Account__r.SAP_Code__c,
                Account__r.CE_CIS_Rating__c,
                Account__r.Phakic_Rating__c,
                Account__r.BillingCountry,
                Account__r.BillingState,
                Account__r.BillingCity,
                Approval_Status__c,
                Account__r.BillingStreet,
                Public_File_Url__c,
                File_Name__c,
                CreatedBy.Email,
                CreatedBy.Name
                FROM Event
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            eventData = ev;
            publicurl = eventData.Public_File_Url__c;
            name = eventData.File_Name__c;
            Description = eventData.DCR_Description__c;
            subject =     eventData.Subject;
            Comment = eventData.Approver_comment__c;
            calltype = eventData.Call_Type__c;
            subcalltype = eventData.Sub_Call_Type__c;
            assignDynamicLeadAccountFields();
        } catch (Exception e) {
            System.debug('VF Guest Error: ' + e.getMessage());
        }
    }
    
    public void assignDynamicLeadAccountFields() {
        
        // SAP Code
        if (eventData.Leads__r != null && String.isNotBlank(eventData.Leads__r.SAP_Code__c)) {
            sapCode     = eventData.Leads__r.SAP_Code__c;
            
        } else if (eventData.Account__r != null && String.isNotBlank(eventData.Account__r.SAP_Code__c)) {
            sapCode     = eventData.Account__r.SAP_Code__c;
            
        } else {
            sapCode     = '';
            
        }
        
        if(eventData.Leads__r != null){
            recordname = eventData.Leads__r.Name;
            countryname = eventData.Leads__r.Country__c;
            statename   = eventData.Leads__r.Billing_State__c;
            Cityname    = eventData.Leads__r.Billing_City__c;
            streetname  = eventData.Leads__r.Billing_Street__c;
        }else if(eventData.Account__r != null){
            recordname = eventData.Account__r.Name;
            countryname = eventData.Account__r.BillingCountry;
            statename   = eventData.Account__r.BillingState;
            Cityname    = eventData.Account__r.BillingCity;
            streetname  = eventData.Account__r.BillingStreet;
        }else{
            countryname = '';
            statename   = '';
            Cityname    = '';
            streetname  = '';
        }
        
        
        
        
        // CE-CIS Rating
        if (eventData.Leads__r != null && eventData.Leads__r.CE_CIS_Rating__c != null) {
            ceCisRating = eventData.Leads__r.CE_CIS_Rating__c;
        } else if (eventData.Account__r != null && eventData.Account__r.CE_CIS_Rating__c != null) {
            ceCisRating = eventData.Account__r.CE_CIS_Rating__c;
        } else {
            ceCisRating = '';
        }
        
        // Phakic Rating
        if (eventData.Leads__r != null && eventData.Leads__r.Phakic_Rating__c != null) {
            phakicRating = eventData.Leads__r.Phakic_Rating__c;
        } else if (eventData.Account__r != null && eventData.Account__r.Phakic_Rating__c != null) {
            phakicRating = eventData.Account__r.Phakic_Rating__c;
        } else {
            phakicRating = '';
        }
    }
    
    
    @RemoteAction  
    public static Map<String, Object> processReSubmit(String managerComment, String recordId,String fileName,String base64Data) {
        
        Map<String, Object> resultMap = new Map<String, Object>();
        
        try {
            
            if (String.isBlank(managerComment)) {
                resultMap.put('status', 'error');
                resultMap.put('message', 'Comment is mandatory for re-submission.');
                return resultMap;
            }
            
            
            Event ev = [SELECT Id, Subject, Description, Type,OwnerId, Call_Type__c,
                        Visit_Date__c, Status__c, ActivityDate,Approver_comment__c,
                        Country__c, State__c, BillingCity__c,
                        Sub_Call_Type__c, BillingStreet__c,
                        DCR_Description__c,
                        
                        Owner.FirstName, Owner.LastName,
                        
                        Leads__r.Name,
                        Leads__r.SAP_Code__c,
                        Leads__r.Country__c,
                        Leads__r.Billing_State__c,
                        Leads__r.CE_CIS_Rating__c,
                        Leads__r.Billing_City__c,
                        Leads__r.Billing_Street__c,
                        Leads__r.Phakic_Rating__c,
                        
                        Account__r.Name,
                        Account__r.SAP_Code__c,
                        Account__r.CE_CIS_Rating__c,
                        Account__r.Phakic_Rating__c,
                        Account__r.BillingCountry,
                        Account__r.BillingState,
                        Account__r.BillingCity,
                        Approval_Status__c,
                        Requester_Comment__c,
                        Account__r.BillingStreet,
                        
                        Public_File_Url__c,
                        File_Name__c,
                        
                        CreatedBy.Email,
                        CreatedBy.Name
                        FROM Event
                        WHERE Id = :recordId
                        LIMIT 1
                       ];
            
            
            if (ev.Approval_Status__c == 'Pending for Approval') {
                resultMap.put('status', 'error');
                resultMap.put('message', 'Request already raised.');
                return resultMap;
            }
            
            if (ev.Approval_Status__c == 'Approved') {
                resultMap.put('status', 'error');
                resultMap.put('message', 'This Activity has already been approved.');
                return resultMap;
            }
            
            if (ev.Approval_Status__c == 'Rejected') {
                
                ev.Requester_Comment__c = managerComment;
                ev.Approval_Status__c = 'Pending for Approval';
                
                if(String.isNotBlank(base64Data) && String.isNotBlank(fileName)){
                
                
                Blob fileBody = EncodingUtil.base64Decode(base64Data);
                
                // ✅ Upload File
                ContentVersion cv = new ContentVersion();
                cv.Title = fileName;
                cv.PathOnClient = fileName;
                cv.VersionData = fileBody;
                insert cv;
                
                // ✅ Link File
                ContentVersion insertedCV = [SELECT ContentDocumentId FROM ContentVersion WHERE Id=:cv.Id];
                
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.LinkedEntityId = recordId;
                cdl.ContentDocumentId = insertedCV.ContentDocumentId;
                cdl.ShareType = 'V';
                cdl.Visibility = 'AllUsers';
                insert cdl;
                         ContentDistribution cd = new ContentDistribution();
                    cd.Name = fileName;
                    cd.ContentVersionId = cv.Id;
                    cd.PreferencesAllowViewInBrowser = true;
                    cd.PreferencesNotifyOnVisit = false;
                    cd.PreferencesAllowOriginalDownload = true;
                    cd.PreferencesAllowPDFDownload = true;
                    cd.PreferencesLinkLatestVersion = true;
                    insert cd;
                    
                   
                    List<ContentDistribution> dists = [
                        SELECT Id, Name, DistributionPublicUrl,ContentVersion.Title,ContentVersion.FileExtension, ContentDocumentId
                        FROM ContentDistribution
                        WHERE Id =:cd.Id
                    ];
                   
                        ev.Public_File_Url__c = dists[0].DistributionPublicUrl;
                        ev.File_Name__c = dists[0].ContentVersion.Title;
                }
                    update ev;
                
                EventApprovalController.sendApprovalEmail(ev);
                
                resultMap.put('status', 'success');
                resultMap.put('message', 'Re-submission done successfully.');
                return resultMap;
            }
            
            
            
            // 6️⃣ Fallback
            resultMap.put('status', 'error');
            resultMap.put('message', 'Action not allowed.');
            return resultMap;
            
        } catch (Exception e) {
            
            System.debug(LoggingLevel.ERROR,
                         'processReSubmit FAILED | Line: ' + e.getLineNumber() +
                         ' | Message: ' + e.getMessage() +
                         ' | Stack: ' + e.getStackTraceString()
                        );
            
            resultMap.put('status', 'error');
            resultMap.put(
                'message',
                'Error at line ' + e.getLineNumber() + ': ' + e.getMessage()
            );
            return resultMap;
        }
        
    }
       
    
    
}
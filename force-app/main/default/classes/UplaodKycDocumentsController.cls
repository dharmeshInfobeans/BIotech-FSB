public class UplaodKycDocumentsController {
    
    @AuraEnabled(cacheable=true)
    public static Map<String,Object> getRecords(String recordId) {
        try {
            List<Map<String, Object>> kycDataList = new List<Map<String, Object>>();
            Map<String,Object>  finalMap=new Map<String,Object>();
            List<Map<String,String>> slOfList=new  List<Map<String,String>>();
            List<Map<String,String>> slDisList=new  List<Map<String,String>>();
            List<Map<String,String>> plantCode=new  List<Map<String,String>>();
            
            if (String.isBlank(recordId)) {
                throw new AuraException('Record ID is required to fetch KYC documents.');
            }
            
            Lead__c leadRecord;
            try {
                leadRecord = [SELECT Email__c,Actual_Presentation_Week__c,Actual_Product_Demo_Week__c,Actual_Evaluations_Week__c,Actual_Appointments_Week__c, Billing_code__c,Billing_state__c,RSM_Not_Approve__c,ZSM_Not_Approve__c,GM_NSM_Not_Approve__c,Admin_Not_Approve__c,Country__c,Sales_district__c,Sales_Office__c, Already_Uploaded__c,Plant__c
                              FROM Lead__c
                              WHERE Id = :recordId
                              LIMIT 1];
                
                if (leadRecord == null) {
                    throw new AuraException('Lead record not found. Please check if the record exists.');
                }
            } catch (QueryException e) {
                throw new AuraException('Unable to fetch lead details. Please try again later.');
            }
            
            if (leadRecord.Actual_Appointments_Week__c == null &&
                leadRecord.Actual_Presentation_Week__c == null &&
                leadRecord.Actual_Product_Demo_Week__c == null &&
                leadRecord.Actual_Evaluations_Week__c == null){
                    finalMap.put('Initaiate',false);
                    
                }else{
                    finalMap.put('Initaiate',true);
                }
            
            List<Account> accList;
            try {
                accList=[SELECT Id,E_Mail__c,BillingPostalCode from Account where E_Mail__c=:leadRecord.Email__c AND BillingPostalCode=:leadRecord.Billing_code__c];
            } catch (Exception e) {
                throw new AuraException('Error checking existing accounts. Please contact administrator.');
            }
            
            List<KYC_Document__mdt> kycList;
            try {
                kycList = [SELECT Id, MasterLabel, Is_required__c FROM KYC_Document__mdt WHERE  Country__c =: leadRecord.Country__c];
            } catch (Exception e) {
                throw new AuraException('Error loading KYC document requirements. Please contact administrator.');
            }
            
            string LeadCountry = leadRecord.Country__c;
            Boolean AlreadyUpdated = leadRecord.Already_Uploaded__c;
            
            List<Sales_Data_Kyc_Form__c> slsDataList;
            try {
                slsDataList=[SELECT Id,Country__c,State__c,Plant__c,Sales_District__c,Sales_Officer__c,Sales_District_Code__c,Sales_Officer_Code__c,Plant_Code__c from Sales_Data_Kyc_Form__c where Country__c=:leadRecord.Country__c AND State__c=:leadRecord.Billing_state__c];
            } catch (Exception e) {
                throw new AuraException('Error loading sales data. Please contact administrator.');
            }
            
            if(slsDataList.size()>0) {
                for(Sales_Data_Kyc_Form__c sl:slsDataList) {
                    
                    slOfList.add(new Map<String,String>{'label'=>sl.Sales_Officer__c,'value'=>sl.Sales_Officer__c});
                    slDisList.add(new Map<String,String>{'label'=>sl.Sales_District__c,'value'=>sl.Sales_District__c}); 
                    plantCode.add(new Map<String,String>{'label'=>sl.Plant__c,'value'=>sl.Plant__c}); 
                }
                
            }
            
            List<ContentDocumentLink> uploadedDocuments;
            try {
                uploadedDocuments = [
                    SELECT ContentDocumentId, ContentDocument.Title
                    FROM ContentDocumentLink 
                    WHERE LinkedEntityId = :recordId
                ];
            } catch (Exception e) {
                throw new AuraException('Error checking uploaded documents. Please try again.');
            }
            
            // Marking KYC documents as unrequired if uploaded
            for (KYC_Document__mdt kyc : kycList) {
                Boolean isRequired;
                if(uploadedDocuments.size()>0) {
                    //isRequired=true;
                    kycDataList.add(new Map<String, Object>{
                        'MasterLabel' => kyc.MasterLabel,
                            'Id' => kyc.Id,
                            'IsRequired' => kyc.Is_required__c,
                            'AlreadyUpdated' => AlreadyUpdated
                            });
                }else {
                    kycDataList.add(new Map<String, Object>{
                        'MasterLabel' => kyc.MasterLabel,
                            'Id' => kyc.Id,
                            'IsRequired' => kyc.Is_required__c,
                            'AlreadyUpdated' => AlreadyUpdated
                            });   
                }           
            }       
            finalMap.put('KycData',kycDataList);
            finalMap.put('AccountExist',accList.size()>0 ? true : false);
            finalMap.put('SalesDistrict',leadRecord.Sales_district__c!=null ? leadRecord.Sales_district__c : '');
            finalMap.put('SalesOfficer',leadRecord.Sales_Office__c!=null ? leadRecord.Sales_Office__c : '');
            finalMap.put('plant',leadRecord.Plant__c!=null ? leadRecord.Plant__c : '');
            finalMap.put('SalesOfficerList',slOfList);
            finalMap.put('SalesDistrictList',slDisList);
            finalMap.put('PlantCodeList',plantCode);
            finalMap.put('ApprovalData',(leadRecord.RSM_Not_Approve__c || leadRecord.ZSM_Not_Approve__c || leadRecord.GM_NSM_Not_Approve__c || leadRecord.Admin_Not_Approve__c) ? true : false);
            
            system.debug('finalMap'+finalMap);
            
            return finalMap;
        } catch (Exception e) {
            throw new AuraException('Failed to load KYC documents: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String uploadFile(String base64, String filename, String recordId,Map<String, String> fileMap) {
        try {
            if (String.isBlank(base64) || String.isBlank(filename) || String.isBlank(recordId)) {
                throw new AuraException('Required parameters are missing. Please provide all file details.');
            }
            
            if (base64.length() > 6000000) { // ~6MB limit
                throw new AuraException('File size is too large. Please upload files smaller than 6MB.');
            }
            
            deleteExistingFiles(filename, recordId); // Delete existing files with the same name
            ContentVersion cv = createContentVersion(base64, filename);
            ContentDocumentLink cdl = createContentLink(cv.Id, recordId);
            system.debug('fileMap--------->'+fileMap);
            if (cv == null || cdl == null) { 
                throw new AuraException('Failed to upload file. Please try again.'); 
            } 
            
            // Update the relevant field in Lead__c
            Lead__c leadToUpdate;
            try {
                leadToUpdate = [
                    SELECT Id, 
                           Aadhaar_card_Number__c, 
                           PAN_Card_Number__c,Upload_Count__c, 
                           Registration_Number__c,Voter_Card_Number__c,
                           GST_Number__c, 
                           Driving_Licence_number__c 
                    FROM Lead__c 
                    WHERE Id = :recordId 
                    LIMIT 1
                ];
            } catch (QueryException e) {
                throw new AuraException('Lead record not found. Please refresh the page and try again.');
            }
            
            if (fileMap != null) {
                if (fileMap.containsKey('Aadhar_Card')) {
                    leadToUpdate.Aadhaar_card_Number__c = fileMap.get('Aadhar_Card');
                }
                if (fileMap.containsKey('PAN_Card')) {
                    leadToUpdate.PAN_Card_Number__c = fileMap.get('PAN_Card');
                }
                if (fileMap.containsKey('Registration_No')) {
                    leadToUpdate.Registration_Number__c = fileMap.get('Registration_No');
                }
                if (fileMap.containsKey('GST_No')) {
                    leadToUpdate.GST_Number__c = fileMap.get('GST_No'); 
                }
                if (fileMap.containsKey('Driving_Licence')) {
                    leadToUpdate.Driving_Licence_number__c = fileMap.get('Driving_Licence');
                }
                if (fileMap.containsKey('Voter_Card')) {
                    leadToUpdate.Voter_Card_Number__c = fileMap.get('Voter_Card');
                }
            }
            
            leadToUpdate.Upload_Count__c = (leadToUpdate.Upload_Count__c == null ? 0 : leadToUpdate.Upload_Count__c) + 1;
            
            try {
                update leadToUpdate;
            } catch (DMLException e) {
                throw new AuraException('Failed to update lead information: ' + e.getDmlMessage(0));
            }
            
            return cdl.Id;        
        } catch (Exception e) {
            throw new AuraException('File upload failed: ' + e.getMessage());
        }
    }
    
    private static void deleteExistingFiles(String filename, String recordId) {
        try {
            if (filename.length() < 4) {
                return; // Filename too short to remove extension
            }
            
            // Remove the last 4 characters from the filename for comparison
            String filenameWithoutExtension = filename.substring(0, filename.length() - 4);
            
            // Query ContentDocumentLink and the associated ContentDocument
            List<ContentDocumentLink> cdlList = [
                SELECT ContentDocumentId,
                ContentDocument.Title 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :recordId
            ];
            
            List<ContentDocument> cdsToDelete = new List<ContentDocument>();
            
            for (ContentDocumentLink cdl : cdlList) {
                ContentDocument cd = cdl.ContentDocument;
                // Check if the Title is not null and at least 4 characters long
                if (cd.Title != null && cd.Title.length() > 4) {
                    // Remove the last 4 characters from the Title for comparison
                    String titleWithoutExtension = cd.Title.substring(0, cd.Title.length() - 4);
                    // Compare the beginning of the Title with the filename
                    if (titleWithoutExtension.equalsIgnoreCase(filenameWithoutExtension)) {
                        cdsToDelete.add(new ContentDocument(Id = cdl.ContentDocumentId));
                    }
                }
            }
            
            // Delete the ContentDocument records
            if (!cdsToDelete.isEmpty()) {
                delete cdsToDelete;
            }
        } catch (Exception e) {
            throw new AuraException('Error removing existing files: ' + e.getMessage());
        }
    }
    
    private static ContentVersion createContentVersion(String base64, String filename) {
        try {
            ContentVersion cv = new ContentVersion();
            cv.VersionData = EncodingUtil.base64Decode(base64);
            cv.Title = filename;
            cv.PathOnClient = filename;
            insert cv;
            return cv;
        } catch(DMLException e) {
            System.debug(e);
            throw new AuraException('Failed to create file version: ' + e.getDmlMessage(0));
        }
    }
    
    private static ContentDocumentLink createContentLink(String contentVersionId, String recordId) {
        try {
            if (contentVersionId == null || recordId == null) { 
                throw new AuraException('Content version ID or record ID is missing.'); 
            }
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = [
                SELECT ContentDocumentId 
                FROM ContentVersion 
                WHERE Id =: contentVersionId
            ].ContentDocumentId;
            cdl.LinkedEntityId = recordId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;           
            return cdl;
        } catch(DMLException e) {
            System.debug(e);
            throw new AuraException('Failed to link document to record: ' + e.getDmlMessage(0));
        }
    }
    
    @AuraEnabled
    public static void updateLeadData(string recordId) {
        try {
            if (String.isBlank(recordId)) {
                throw new AuraException('Record ID is required to update lead data.');
            }
            
            System.debug('Inside data-->');
            Lead__c lead;
            try {
                lead = [SELECT Id,Upload_Count__c,Country__c,Billing_state__c FROM Lead__c WHERE Id =: recordId]; 
            } catch (QueryException e) {
                throw new AuraException('Lead record not found. Please check if the record exists.');
            }
            
            system.debug('lead-->201: '+lead);
            // lead.Upload_Count__c += 1;
            lead.Already_Uploaded__c = true;
            lead.RSM_Approve__c=false;
            lead.RSM_Not_Approve__c=false;
            lead.ZSM_Approve__c=false;
            lead.ZSM_Not_Approve__c=false;
            lead.GM_NSM_Approve__c=false;
            lead.GM_NSM_Not_Approve__c=false;
            lead.Admin_Approve__c=false;
            lead.Admin_Not_Approve__c=false;
            
            system.debug('lead.Upload_Count__c-->213: '+lead.Upload_Count__c);
            
            try {
                update lead;
            } catch (DMLException e) {
                throw new AuraException('Failed to update lead status: ' + e.getDmlMessage(0));
            }
            
            System.debug('Lead data-->'+lead);
        } catch (Exception e) {
            throw new AuraException('Failed to update lead data: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void saveLeadAndPdf(String recordId, Lead__c lea) {
        try {
            if (String.isBlank(recordId)) {
                throw new AuraException('Record ID is required to save lead data.');
            }
            
            system.debug('Test data');
            Map<String,String> sldDisMap=new Map<String,String>();
            Map<String,String> sldOffMap=new Map<String,String>();
            Map<String,Sales_Data_Kyc_Form__c> cutStgMap=new Map<String,Sales_Data_Kyc_Form__c>();
            Map<String,String> plantMap=new Map<String,String>();
            
            if(lea.Id != null) {
                try {
                    update lea;                    
                } catch (DMLException e) {
                    throw new AuraException('Failed to update lead information: ' + e.getDmlMessage(0));
                }
            }
            
            Lead__c lead;
            try {
                lead = [SELECT Id,Upload_Count__c,Country__c,Billing_state__c,Sales_Office__c,Sales_district__c,Sales_Officer_Code__c,Sales_District_Code__c,Plant__c,Plant_Code__c FROM Lead__c WHERE Id =: recordId];
            } catch (QueryException e) {
                throw new AuraException('Lead record not found. Please check if the record exists.');
            }
            
            System.debug('lead data'+lead);
            system.debug('lead.Upload_Count__c-->231: '+ lead.Upload_Count__c);
            
            List<Sales_Data_Kyc_Form__c> slsDataList;
            try {
                slsDataList=[SELECT Id,Country__c,State__c,Plant__c,Sales_District__c,Sales_Officer__c,Sales_District_Code__c,Sales_Officer_Code__c,Plant_Code__c from Sales_Data_Kyc_Form__c where  Country__c =:lead.Country__c AND State__c=:lead.Billing_state__c AND Plant__c=:lead.Plant__c];
            } catch (Exception e) {
                throw new AuraException('Error loading sales configuration data. Please contact administrator.');
            }
            
            System.debug('list size'+slsDataList);
            if(slsDataList.size()>0) {
                for(Sales_Data_Kyc_Form__c sld:slsDataList) {
                    cutStgMap.put(sld.Country__c+sld.State__c+sld.Plant__c,sld);
                }
                System.debug('cutStgMap'+cutStgMap);
                
                if(cutStgMap.containsKey(lead.Country__c+lead.Billing_state__c+lead.Plant__c)) {
                    lead.Sales_district__c=cutStgMap.get(lead.Country__c+lead.Billing_state__c+lead.Plant__c).Sales_District__c; 
                }
                if(cutStgMap.containsKey(lead.Country__c+lead.Billing_state__c+lead.Plant__c)) {
                    lead.Sales_District_Code__c=cutStgMap.get(lead.Country__c+lead.Billing_state__c+lead.Plant__c).Sales_District_Code__c;
                }
                if(cutStgMap.containsKey(lead.Country__c+lead.Billing_state__c+lead.Plant__c)) {
                    lead.Sales_Office__c=cutStgMap.get(lead.Country__c+lead.Billing_state__c+lead.Plant__c).Sales_Officer__c;
                }
                if(cutStgMap.containsKey(lead.Country__c+lead.Billing_state__c+lead.Plant__c)) {
                    lead.Sales_Officer_Code__c=cutStgMap.get(lead.Country__c+lead.Billing_state__c+lead.Plant__c).Sales_Officer_Code__c;
                }
                if(cutStgMap.containsKey(lead.Country__c+lead.Billing_state__c+lead.Plant__c)) {
                    lead.Plant_Code__c=cutStgMap.get(lead.Country__c+lead.Billing_state__c+lead.Plant__c).Plant_Code__c;
                }
                System.debug('update lead--256: '+lead);
                //lead.Upload_Count__c += 1;
                lead.Already_Uploaded__c = true;
                lead.RSM_Approve__c=false;
                lead.RSM_Not_Approve__c=false;
                lead.ZSM_Approve__c=false;
                lead.ZSM_Not_Approve__c=false;
                lead.GM_NSM_Approve__c=false;
                lead.GM_NSM_Not_Approve__c=false;
                lead.Admin_Approve__c=false;
                lead.Admin_Not_Approve__c=false;
                
                try {
                    update lead;
                } catch (DMLException e) {
                    throw new AuraException('Failed to save lead information: ' + e.getDmlMessage(0));
                }
                
                system.debug('update lead :lead--->:'+json.serialize(lead));
                system.debug('lead.Upload_Count__c-->271: '+ lead.Upload_Count__c);
                system.debug('lead.Upload_Count__c-->273: '+ lead.Upload_Count__c);
            } else {
                throw new AuraException('No sales configuration found for the selected country, state, and plant combination.');
            }
        } catch (Exception e) {
            throw new AuraException('Failed to save lead and PDF: ' + e.getMessage());
        }
    } 

        
        /* PageReference pdfPage = Page.LeadInformationPdf; // Replace with your VF page name
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
cv.Title = 'Lead_' + recordId + '.pdf';
cv.PathOnClient = 'Lead_' + recordId + '.pdf';
cv.VersionData = pdfBlob;
cv.IsMajorVersion = true;
insert cv;

// Link the PDF to the Lead record
ContentDocumentLink cdl = new ContentDocumentLink();
cdl.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
cdl.LinkedEntityId = recordId;
cdl.ShareType = 'V';
insert cdl; */
    }
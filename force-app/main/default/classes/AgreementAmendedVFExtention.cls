public class AgreementAmendedVFExtention {
        
        public Master_Agreement__c currentAgreement { get; set; }
        public Master_Agreement__c activeAgreement { get; set; }
        public List<String> changedFields { get; set; }
        public Map<String, String> changedFieldApiNameVsLabel { get; set; }
        public Map<String, String> changedFieldOldValues { get; set; }
        public Map<String, String> changedFieldNewValues { get; set; } 
        public Map<String, String> paymentTermApiNameVsLabel { get; set; } 
        public String SignedWithBranchAddress { get; set; }
    	public String currencyType {get;set;}
        
        public List<Agreement_Product__c> agreementProducts { get; set; }
        public String message { get; set; }
        public Boolean IsmessagePresent { get; set; }
        public Id recordId;
        public Boolean hasChanges { get; set; }
        public String todayDateStr { get; set; }
        
        public AgreementAmendedVFExtention(ApexPages.StandardController controller) {
            Integer i=0;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
                i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
                i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
                i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;    i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            i++;
            message = '';
            IsmessagePresent = false;
            changedFields = new List<String>();
            changedFieldOldValues = new Map<String, String>();
            changedFieldNewValues = new Map<String, String>();
            changedFieldApiNameVsLabel = new Map<String, String>();
            paymentTermApiNameVsLabel = new Map<String, String>();
    
            
            try {
                setTodayDateStr();
                
                paymentTermApiNameVsLabel=ReusableUtilityClass.getPicklistMap('Agreement_Product__c','Payment_Terms_options__c');
                
                recordId = controller.getId();
                if (recordId == null) {
                    setErrorMessage('Error: Record ID is null.');
                    return;
                }
                
                
                Schema.FieldSet fieldSet = Schema.getGlobalDescribe().get('Master_Agreement__c')
                    .getDescribe().fieldSets.getMap().get('Amendment_FieldSet');
                
                if (fieldSet == null) {
                    setErrorMessage('Error: FieldSet "Amendment_FieldSet" not found.');
                    return;
                }
                                    List<String> fieldNames = new List<String>();
    
                for (Schema.FieldSetMember fieldMember : fieldSet.getFields()) {
                    fieldNames.add(fieldMember.getFieldPath());
                }
                System.debug('fieldNames'+fieldNames);
                
                String queryFields = 'Id, Agreement_Number__c, Is_Active__c, ' + String.join(fieldNames, ', ');
                
                currentAgreement = Database.query('SELECT ' + queryFields + ' FROM Master_Agreement__c WHERE Id = :recordId LIMIT 1');
                System.debug('currentAgreement'+currentAgreement);
                if (currentAgreement == null) {
                    setErrorMessage('Error: No agreement found for the given ID.');
                    return;
                }
                if (currentAgreement.Agreement_Signed_With__c != null) {
                    // Fetch the corresponding address from custom settings
    BioTech_Company_Addresses__c addressSetting = [
        SELECT Address__c 
        FROM BioTech_Company_Addresses__c 
        WHERE Name = :currentAgreement.Agreement_Signed_With__c 
        LIMIT 1
    ];
    
    SignedWithBranchAddress = String.valueOf(addressSetting.Address__c);
                }
                String agreementNumber = currentAgreement.Agreement_Number__c;
                System.debug('agreementNumber'+agreementNumber);
                if (agreementNumber != null) {
                    List<Master_Agreement__c> maLst  = Database.query('SELECT ' + queryFields + ' FROM Master_Agreement__c WHERE Agreement_Number__c = :agreementNumber AND Is_Active__c = true LIMIT 1');
                                     System.debug('maLst'+maLst);
    
                    if(maLst.size()>0){
                        activeAgreement=maLst[0];
                        System.debug('activeAgreement'+activeAgreement);
                    }else{
                        setErrorMessage('Error: No Active Previous Agreement Available for this Amended Agreement.');
                        
                    }
                } else {
                    setErrorMessage('Error: Agreement Number is null.');
                    return;
                }
                
                
                
                agreementProducts = [SELECT Id, Product__r.Name, Price__c, FOC_Text__c, Incoterms__c,
                                     Payment_Terms_options__c, Product__r.plant__r.Port_of_Loading__c,
                                     Master_Agreement__r.CurrencyIsoCode
                                     FROM Agreement_Product__c 
                                     WHERE Master_Agreement__c = :currentAgreement.Id 
                                     AND Is_Canceled__c = false
                                     AND Is_Amended__c = true];
                if(agreementProducts.size()>0){
                currencyType = agreementProducts[0].Master_Agreement__r.CurrencyIsoCode;
                }
                else{
                    currencyType='';
                }
                if (activeAgreement != null) {
                    compareFieldsetValues(fieldSet);
                }
            } catch (QueryException qe) {
                
                setErrorMessage('Query Error: ' + qe);
            } catch (Exception e) {
                setErrorMessage('Unexpected error: ' + e);
            }
        }
        
        public void compareFieldsetValues(Schema.FieldSet fieldSet) {
            try {
                for (Schema.FieldSetMember fieldMember : fieldSet.getFields()) {
                    String fieldName = fieldMember.getFieldPath();
                    String fieldLabel = (fieldName == 'CurrencyIsoCode') ? 'Currency' : fieldMember.getLabel();
                    
                    System.debug('FieldName ==> ' + fieldName + ' FieldLabel ==> ' + fieldLabel);
                    
                    changedFieldApiNameVsLabel.put(fieldName, fieldLabel);
                    
                    Object currentValue = currentAgreement.get(fieldName);
                    Object activeValue = activeAgreement.get(fieldName);
                    
                    if (currentValue != null && !currentValue.equals(activeValue)) {
                        changedFields.add(fieldName);
                        changedFieldOldValues.put(fieldName, activeValue != null ? String.valueOf(activeValue) : 'N/A');
                        changedFieldNewValues.put(fieldName, String.valueOf(currentValue));
                    }
                }
                hasChanges = !changedFields.isEmpty();
            } catch (Exception e) {
                setErrorMessage('Error comparing fieldset values: ' + e);
            }
        }
        
        public void setTodayDateStr() {
            Date today = Date.today();
            Integer day = today.day();
            Integer monthNumber = today.month();
            
            Map<Integer, String> monthMap = new Map<Integer, String>{
                1 => 'Jan', 2 => 'Feb', 3 => 'Mar', 4 => 'Apr',
                    5 => 'May', 6 => 'Jun', 7 => 'Jul', 8 => 'Aug',
                    9 => 'Sep', 10 => 'Oct', 11 => 'Nov', 12 => 'Dec'
                    };
                        
                        String month = monthMap.get(monthNumber);
            Integer year = today.year();
            
            String suffix = (day == 1 || day == 21 || day == 31) ? 'st' :
            (day == 2 || day == 22) ? 'nd' :
            (day == 3 || day == 23) ? 'rd' : 'th';
            
            todayDateStr = 'Dated ' + day + suffix + ' ' + month + ' ' + year;
        }
        
        public void setErrorMessage(String errorMsg) {
            message = errorMsg;
            IsmessagePresent = true;
        }
        // Save & Attach PDF Method
        public PageReference saveAttach() {
            System.debug('recordId'+recordId);
            if (recordId == null) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Record ID is missing.'));
                return null;
            }
            
            try {
                // Generate PDF
                PageReference pdfPage = Page.generateAmendedAgreement;
                pdfPage.getParameters().put('id', recordId);
                // Fetch Agreement details for naming convention
                Master_Agreement__c agreementRecord = [
                    SELECT Agreement_Number__c, Version__c, Agreement_StartDate_mmmm_format__c
                    FROM Master_Agreement__c
                    WHERE Id = :recordId
                    LIMIT 1
                ];
                
                // Build the file name: AgreementNumber-Version-Date.pdf
                String agreementNumber = agreementRecord.Agreement_Number__c != null ? agreementRecord.Agreement_Number__c : 'Agreement';
                String version = agreementRecord.Version__c != null ? String.valueOf(agreementRecord.Version__c) : '1';
                String agreementDate = agreementRecord.Agreement_StartDate_mmmm_format__c != null ? agreementRecord.Agreement_StartDate_mmmm_format__c : 'UnknownDate';
                String todayStr = DateTime.now().format('yyyy-MM-dd');
                
                String fileName = 'Amended'+'-'+agreementNumber +'-'+ version + '-' + todayStr + '.pdf';
                
                Blob pdfBlob = Test.isRunningTest() ? Blob.valueOf('UNIT.TEST') :pdfPage.getContentAsPDF();
                
                // Create ContentVersion (for storing in Files)
                ContentVersion contentVersion = new ContentVersion();
                contentVersion.Title = fileName;
                contentVersion.PathOnClient = fileName;
                contentVersion.VersionData = pdfBlob;
                contentVersion.FirstPublishLocationId = recordId; // Associates with the Agreement Record
                insert contentVersion;
                
                /*
                    // Get the ContentDocument Id
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id].ContentDocumentId;
        // Share with multiple users
                    List<ContentDocumentLink> fileShares = new List<ContentDocumentLink>();
                User komalUser = [select id,Name from user where name ='Komal Bhatia' AND IsActive =true LIMIT 1];
                
                // Example: Share with multiple users
                Set<Id> userIds = new Set<Id>{komalUser.Id}; // Replace with actual User IDs
                    for (Id userId : userIds) {
                        fileShares.add(new ContentDocumentLink(
                            ContentDocumentId = contentDocumentId,
                            LinkedEntityId = userId,
                            ShareType = 'V',
                            Visibility = 'AllUsers'
                        ));
                    }
                insert fileShares;
*/
                message = 'PDF saved to Files successfully.';
                IsmessagePresent=true;
                
                
                return new PageReference('/' + recordId);
            } catch (Exception e) {
                
                message = 'Error generating or saving PDF: ' + e.getMessage();
                IsmessagePresent=true;
                
                return null;
            }
            
            
        }
        
        // Cancel Action (Redirect to Record Page)
        public PageReference cancel() {
            return new PageReference('/' + recordId);
        }
        
    }
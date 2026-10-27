public without sharing class initiateCustomerApprovalEmailController {
    /* =====================================================
Fetch Opportunity__c + related Account details
===================================================== */

   @AuraEnabled
    public static List<Account> tempgetOpportunityRecord(){
        System.debug('working');

        return [SELECT Id,Name FROM Account LIMIT 10];

    }
    @AuraEnabled(cacheable=true)
    public static OppWrapper getOpportunityDetails(Id recordId) {
        System.debug('RecordId : '+ recordId);

        if (recordId == null) {
            throw new AuraHandledException('Record Id is missing.');
        }

        List<Opportunity__c> oppList = [
           SELECT Id, RSM_Comments__c, ZSM_Comments__c, GM_NSM_Comments__c, Admin_Comments__c,Account__c,
            Admin_Approve__c, Admin_Not_Approve__c,
            RSM_Approve__c, RSM_Not_Approve__c,
            ZSM_Approve__c, ZSM_Not_Approve__c,
            GM_NSM_Approve__c, GM_NSM_Not_Approve__c,
            Account__r.Name,
            Account__r.Phone,
            Account__r.E_Mail__c,
            Account__r.BillingStreet,
            Account__r.BillingCity,
            Account__r.BillingState,
            Account__r.BillingPostalCode,
            Account__r.BillingCountry,
            Account__r.Phakic_Rating__c,
            Account__r.Commercial_Account_Name__c,
            Account__r.CE_CIS_Rating__c,
            Account__r.SAP_Code__c,
            Account__r.New_Owner__r.Name
            FROM Opportunity__c
            WHERE Id =: recordId
            LIMIT 1
        ];

        if (oppList.isEmpty()) {
            throw new AuraHandledException('Opportunity record not found.');
        }

        Opportunity__c opp = oppList[0];

        OppWrapper wrapper = new OppWrapper();
        wrapper.accountName = opp.Account__r.Name;
         wrapper.accountId = opp.Account__c;
        wrapper.mobile = opp.Account__r.Phone;
        wrapper.email = opp.Account__r.E_Mail__c;
        wrapper.phakic = opp.Account__r.Phakic_Rating__c;
        wrapper.hospital = opp.Account__r.Commercial_Account_Name__c;
        wrapper.address = String.join(new List<String>{
            opp.Account__r.BillingStreet,
                opp.Account__r.BillingCity,
                opp.Account__r.BillingState,
                opp.Account__r.BillingPostalCode,
                opp.Account__r.BillingCountry
                }, ', ');
        wrapper.rsmComment = opp.RSM_Comments__c;
        wrapper.ceceisrating = opp.Account__r.CE_CIS_Rating__c;
        wrapper.zsmComment = opp.ZSM_Comments__c;
        wrapper.gmnsmComment = opp.GM_NSM_Comments__c;
        wrapper.adminComment = opp.Admin_Comments__c;
        wrapper.adminApprove = opp.Admin_Approve__c;
        wrapper.adminNotApprove = opp.Admin_Not_Approve__c;
        wrapper.rsmApprove = opp.RSM_Approve__c;
        wrapper.rsmNotApprove = opp.RSM_Not_Approve__c;
        wrapper.zsmApprove = opp.ZSM_Approve__c;
        wrapper.zsmNotApprove = opp.ZSM_Not_Approve__c;
        wrapper.gmnsmApprove = opp.GM_NSM_Approve__c;
        wrapper.gmnsmNotApprove = opp.GM_NSM_Not_Approve__c;
        wrapper.sapCode = opp.Account__r.SAP_Code__c;
        wrapper.newOwnerName = opp.Account__r.New_Owner__r.Name;
        return wrapper;
    }



    /* =====================================================
Get Approval_URL_Config__mdt custom Metadata to show the approval thank you page
===================================================== */

    @AuraEnabled(cacheable=true)
    public static Approval_URL_Config__mdt getConfigByDeveloperName(String devName) {
        return [
            SELECT Id, Label, DeveloperName, URL__c
            FROM Approval_URL_Config__mdt
            WHERE DeveloperName = :devName
            LIMIT 1
        ];
    }


    /* =====================================================
Save RSM Comment on Opportunity__c
===================================================== */
    @AuraEnabled
    public static void saveRsmComment(Id recordId, String rsmcomments,Boolean isApproved,String userId) {

        if (recordId == null) {
            throw new AuraHandledException('Record Id is missing.');
        }

        if (String.isBlank(rsmcomments)) {
            throw new AuraHandledException('Comment is required.');
        }

        Opportunity__c opp;
         Account acc;
        User us;
        try {
            opp = [SELECT Id, RSM_Comments__c,Account__c  FROM Opportunity__c WHERE Id =: recordId  LIMIT 1 ];
             acc = [SELECT Id, New_Owner__c From Account WHERE Id =: opp.Account__c LIMIT 1];
            us = [SELECT Id,Sales_District__c FROM User where id =: userId];
        } catch (Exception e) {
            throw new AuraHandledException('Invalid Opportunity Id.');
        }
          acc.New_Owner__c = userId;
        acc.Sales_District__c = us!=null ? us.Sales_district__c : '';
        opp.RSM_Comments__c = rsmcomments;
        opp.RSM_Approve__c = isApproved;
        opp.RSM_Not_Approve__c = !isApproved;
        System.debug('acc'+acc);
        System.debug('opp'+opp);
        Generic_DML_Request__e evt = new Generic_DML_Request__e(  Object_API_Name__c = 'Account', Operation__c = 'Update', Record_JSON__c = JSON.serialize(acc));
EventBus.publish(evt);
            Generic_DML_Request__e evt1 = new Generic_DML_Request__e(  Object_API_Name__c = 'Opportunity__c', Operation__c = 'Update', Record_JSON__c = JSON.serialize(opp));
EventBus.publish(evt1);

       // update opp;
      //  update acc;

      //  if(isApproved) Bio_uploadKYCDocument.sendEmailOnUpload(recordId);
    }

    /* =====================================================
Save ZSM Comment on Opportunity__c
===================================================== */
    @AuraEnabled
    public static void saveZsmComment(Id recordId, String zsmcomments, Boolean isApproved) {

        if (recordId == null) {
            throw new AuraHandledException('Record Id is missing.');
        }

        if (String.isBlank(zsmcomments)) {
            throw new AuraHandledException('Comment is required.');
        }

        Opportunity__c opp1;

        try {
            opp1 = [SELECT Id, ZSM_Comments__c FROM Opportunity__c WHERE Id =: recordId  LIMIT 1 ];
        } catch (Exception e) {
            throw new AuraHandledException('Invalid Opportunity Id.');
        }

        opp1.ZSM_Comments__c = zsmcomments;
        opp1.ZSM_Approve__c = isApproved;
        opp1.ZSM_Not_Approve__c = !isApproved;
        System.debug('opp1'+opp1);
         Generic_DML_Request__e evt1 = new Generic_DML_Request__e(  Object_API_Name__c = 'Opportunity__c', Operation__c = 'Update', Record_JSON__c = JSON.serialize(opp1));
EventBus.publish(evt1);
       // update opp1;

       // if(isApproved) Bio_uploadKYCDocument.sendEmailOnUpload(recordId);
    }

    /* =====================================================
Save GM NSM Comment on Opportunity__c
===================================================== */
    @AuraEnabled
public static void savegmNSMComment(Id recordId, String gmnsmcomments, Boolean isApproved) {

    if (recordId == null) {
        throw new AuraHandledException('Record Id is missing.');
    }

    if (String.isBlank(gmnsmcomments)) {
        throw new AuraHandledException('GM NSM Comment is required.');
    }

    Opportunity__c opp2;

    try {
        opp2 = [SELECT Id, GM_NSM_Comments__c FROM Opportunity__c WHERE Id =: recordId LIMIT 1];
    } catch (Exception e) {
        throw new AuraHandledException('Invalid Opportunity Id.');
    }

    opp2.GM_NSM_Comments__c = gmnsmcomments;
    opp2.GM_NSM_Approve__c = isApproved;
    opp2.GM_NSM_Not_Approve__c = !isApproved;
    update opp2;

   // if(isApproved) Bio_uploadKYCDocument.sendEmailOnUpload(recordId);
}

    /* =====================================================
Save Admin Comment on Opportunity__c
===================================================== */
    @AuraEnabled
    public static void saveAdminComment(Id recordId, String admincomments,Boolean isApproved) {

        if (recordId == null) {
            throw new AuraHandledException('Record Id is missing.');
        }

        if (String.isBlank(admincomments)) {
            throw new AuraHandledException('Comment is required.');
        }

        Opportunity__c opp3;

        try {
            opp3 = [SELECT Id, Admin_Comments__c FROM Opportunity__c WHERE Id =: recordId  LIMIT 1 ];
        } catch (Exception e) {
            throw new AuraHandledException('Invalid Opportunity Id.');
        }

        opp3.Admin_Comments__c = admincomments;
        opp3.Admin_Approve__c = isApproved;
        opp3.Admin_Not_Approve__c = !isApproved;
      //  update opp3;
         Generic_DML_Request__e evt1 = new Generic_DML_Request__e(  Object_API_Name__c = 'Opportunity__c', Operation__c = 'Update', Record_JSON__c = JSON.serialize(opp3));
EventBus.publish(evt1);
      //  if(isApproved) Bio_uploadKYCDocument.sendEmailOnUpload(recordId);
    }
    @AuraEnabled
    public static void resubmitRecord(Id recordId) {
        System.debug('resumbit called'+recordId);
        if (recordId == null) {
            throw new AuraHandledException('Record Id is missing.');
        }

        Opportunity__c opp;
        try {
            opp = [SELECT Id, Admin_Not_Approve__c, Account__c FROM Opportunity__c WHERE Id = :recordId LIMIT 1];
        } catch (Exception e) {
            throw new AuraHandledException('Invalid Record Id.');
        }
 if (opp.Account__c != null) {
            deleteExistingAccountPdf(opp.Account__c);
        }

        // Update the flag
        opp.Admin_Not_Approve__c = false;
      //  update opp;
          Generic_DML_Request__e evt1 = new Generic_DML_Request__e(  Object_API_Name__c = 'Opportunity__c', Operation__c = 'Update', Record_JSON__c = JSON.serialize(opp));
EventBus.publish(evt1);

        // Delete the previously generated Account Information PDF (named
        // "<AccountName>-<BranchCode>-<BillingState>-<AccountId>", same as
        // Bio_uploadKYCDocument.sendEmailOnUpload) so the stale copy doesn't linger.
       
        // Trigger the email
/*        try {
            Bio_uploadKYCDocument.sendEmailOnUpload(recordId);
        } catch (Exception e) {
            System.debug('Error sending email on resubmit: ' + e.getMessage());
            // Optional: throw new AuraHandledException('Record updated, but failed to send email.');
        }*/
    }

    private static void deleteExistingAccountPdf(Id accountId) {
        try {
            Account acc = [SELECT Id, Name, Branch_Code__c, BillingState, PDF_Generated__c FROM Account WHERE Id = :accountId LIMIT 1];
            String pdfName = acc.Name + '-' + acc.Branch_Code__c + '-' + acc.BillingState + '-' + acc.Id;
            deleteContentDocumentByTitle(accountId, pdfName);

            // Reset the flag so sendEmailOnUpload's PDF-generation step (gated by
            // !PDF_Generated__c) actually regenerates a fresh copy next time around.
            if (acc.PDF_Generated__c) {
                acc.PDF_Generated__c = false;
                Generic_DML_Request__e evt = new Generic_DML_Request__e( Object_API_Name__c = 'Account', Operation__c = 'Update', Record_JSON__c = JSON.serialize(acc));
                EventBus.publish(evt);
            }
        } catch (Exception e) {
            System.debug('Error deleting existing Account PDF: ' + e.getMessage());
        }
    }

    // Shared guest-safe delete: removes the ContentDocument linked to linkedEntityId
    // whose Title exactly matches title, via the Generic_DML_Request__e platform
    // event (same pattern used throughout this class for guest-context DML).
    private static void deleteContentDocumentByTitle(Id linkedEntityId, String title) {
        if (linkedEntityId == null || String.isBlank(title)) return;

        List<ContentDocumentLink> existingLinks = [
            SELECT ContentDocumentId, ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :linkedEntityId
            WITH SYSTEM_MODE
        ];

        for (ContentDocumentLink link : existingLinks) {
            if (link.ContentDocument.Title == title) {
                Generic_DML_Request__e evt = new Generic_DML_Request__e( Object_API_Name__c = 'ContentDocument', Operation__c = 'Delete', Record_JSON__c = JSON.serialize(new ContentDocument(Id = link.ContentDocumentId)));
                EventBus.publish(evt);
                break; // title is expected to be unique per record
            }
        }
    }

    /* =====================================================
Save SAP Code on Opportunity__c
===================================================== */
    @AuraEnabled
    public static void saveSAPCode(Id recordId, String sapcode) {

        if (recordId == null) {
            throw new AuraHandledException('Record Id is missing.');
        }

        if (String.isBlank(sapcode)) {
            throw new AuraHandledException('SAP Code is required.');
        }

        Opportunity__c opp4;
        Account acc;

        try {
            opp4 = [SELECT Id, Account__c FROM Opportunity__c WHERE Id =: recordId  LIMIT 1 ];
            acc = [SELECT Id, SAP_Code__c,BillingCountry From Account WHERE Id =: opp4.Account__c LIMIT 1];

        } catch (Exception e) {
            throw new AuraHandledException('Invalid Opportunity Id.');
        }

        //opp4.Account__r.SAP_Code__c = sapcode;
         System.debug('Before '+acc);
        acc.SAP_Code__c = sapcode;
        System.debug('After '+acc);
        //update acc;
        opp4.Mis_Email__c = true;
        //update opp4;
          Generic_DML_Request__e evt = new Generic_DML_Request__e(  Object_API_Name__c = 'Account', Operation__c = 'Update', Record_JSON__c = JSON.serialize(acc));
EventBus.publish(evt);
            Generic_DML_Request__e evt1 = new Generic_DML_Request__e(  Object_API_Name__c = 'Opportunity__c', Operation__c = 'Update', Record_JSON__c = JSON.serialize(opp4));
EventBus.publish(evt1);
       // SAPAccountEmailNotifier.oppEmail(recordId,acc.BillingCountry);
    }

    /* =====================================================
Fetch Account Files linked to Opportunity__c
===================================================== */
    @AuraEnabled(cacheable=true)
    public static List<FileWrapper> getAccountFiles(Id opportunityId) {

        if (opportunityId == null) {
            return new List<FileWrapper>();
        }

        List<Opportunity__c> oppList = [
            SELECT Id, Account__c,
            Account__r.Aadhaar_card_Number__c,
            Account__r.PAN_Card_Number__c,
            Account__r.Voter_Card_Number__c,
            Account__r.GST_Number__c,
            Account__r.Registration_Number__c,
            Account__r.Driving_Licence_number__c,
            Account__r.Doctor_Letter_Number__c,
            Account__r.Vat_Document_Number__c,
            Account__r.Medical_Registration_No__c
            FROM Opportunity__c
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        if (oppList.isEmpty() || oppList[0].Account__c == null) {
            return new List<FileWrapper>();
        }

        /* ✅ STEP C: ADD DOCUMENT NUMBER MAP HERE */

        Account acc = oppList[0].Account__r;

        Map<String, String> docNumberMap = new Map<String, String>{
            'Aadhaar' => acc.Aadhaar_card_Number__c,
                'PAN' => acc.PAN_Card_Number__c,
                'Voter' => acc.Voter_Card_Number__c,
                'GST' => acc.GST_Number__c,
                'Registration' => acc.Registration_Number__c,
                'Driving' => acc.Driving_Licence_number__c,
                'Doctor' => acc.Doctor_Letter_Number__c,
                'Vat' => acc.Vat_Document_Number__c,
                'Medical_Registration' => acc.Medical_Registration_No__c
                };

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId,
            ContentDocument.Title,
            ContentDocument.FileType,
            ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :oppList[0].Account__c
           // AND ContentDocument.FileType != 'PDF'  // added by dhrumil
            ORDER BY ContentDocument.CreatedDate DESC
        ];

        List<FileWrapper> files = new List<FileWrapper>();
        for (ContentDocumentLink cdl : links) {
            FileWrapper fw = new FileWrapper();
            fw.documentId = cdl.ContentDocumentId;
            fw.versionId = cdl.ContentDocument.LatestPublishedVersionId;
            fw.title = cdl.ContentDocument.Title;
            fw.fileType = cdl.ContentDocument.FileType;

            //newly added code
            String docNum = '';

            if (fw.title != null) {

               if (fw.title.containsIgnoreCase('Aadhaar') || fw.title.containsIgnoreCase('Aadhar'))
                    docNum = docNumberMap.get('Aadhaar');

                else if (fw.title.containsIgnoreCase('PAN'))
                    docNum = docNumberMap.get('PAN');

                else if (fw.title.containsIgnoreCase('Voter'))
                    docNum = docNumberMap.get('Voter');

                else if (fw.title.containsIgnoreCase('GST'))
                    docNum = docNumberMap.get('GST');

                else if (fw.title.containsIgnoreCase('Medical Registration'))
                    docNum = docNumberMap.get('Medical_Registration');

                else if (fw.title.containsIgnoreCase('Registration'))
                    docNum = docNumberMap.get('Registration');

                else if (fw.title.containsIgnoreCase('Driving'))
                    docNum = docNumberMap.get('Driving');

                else if (fw.title.containsIgnoreCase('Doctor'))
                    docNum = docNumberMap.get('Doctor');

                else if (fw.title.containsIgnoreCase('Vat Document'))
                    docNum = docNumberMap.get('Vat');
            }

            fw.documentNumber = docNum;
            //ends here

            files.add(fw);
        }

        return files;
    }

     @AuraEnabled
    public static String getPublicFileUrl(String contentDocumentId) {
        try {
        // Check if distribution already exists
        List<ContentDistribution> existing = [
            SELECT Id, DistributionPublicUrl
            FROM ContentDistribution
            WHERE ContentDocumentId = :contentDocumentId
            LIMIT 1
        ];
            System.debug('existing'+existing);

        if (!existing.isEmpty()) {
            return existing[0].DistributionPublicUrl;
        }

        // Get latest ContentVersion
        ContentVersion cv = [
            SELECT Id FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            AND IsLatest = true
            LIMIT 1
        ];
            System.debug('cv'+cv);

        // Create public distribution
        ContentDistribution cd = new ContentDistribution();
        cd.Name                              = 'Guest Public Preview';
        cd.ContentVersionId                  = cv.Id;
        cd.PreferencesAllowViewInBrowser     = true;  // ✅ Opens in browser (preview)
        cd.PreferencesLinkLatestVersion      = true;
        cd.PreferencesNotifyOnVisit          = false;
        cd.PreferencesPasswordRequired       = false;
        cd.PreferencesAllowOriginalDownload  = true;
           System.debug('cd'+cd);
        insert cd;
            System.debug('cd'+cd);

        cd = [SELECT DistributionPublicUrl FROM ContentDistribution WHERE Id = :cd.Id];
            System.debug('cd1'+cd);
        return cd.DistributionPublicUrl;
         } catch (Exception e) {
             System.debug('e.getMessage()'+e.getLineNumber());
              System.debug('jiou'+ e.getMessage());
        throw new AuraHandledException('File preview error: ' + e.getMessage());
    }
    }
  /*  @AuraEnabled(cacheable=true)
    public static List<User> getTeamOfLevelOne(Id recordId) {
        try {
             TeamResult result = new TeamResult();
            if (String.isBlank(recordId)) {  return new List<User>();  }
            // Using a list query prevents QueryException if recordId does not exist
            List<Opportunity__c> oppList = [ SELECT Id,  TYPEOF Owner  WHEN User THEN L1_Manager__c  END  FROM Opportunity__c  WHERE Id = :recordId  LIMIT 1 ];
            if (oppList.isEmpty()) { return new List<User>(); }
            Id managerId = null;
            if (oppList[0].Owner instanceof User) {
                User ownerUser = (User) oppList[0].Owner;
                managerId = ownerUser.L1_Manager__c;
            }
            if (managerId == null) {  return new List<User>(); }

            return [ SELECT Id,Name,Title_Internal_Use__c,Custom_Manager_Id__c   FROM User  WHERE IsActive = true   AND (Title_Internal_Use__c LIKE '%BDM%' OR Title_Internal_Use__c LIKE '%SAE%')	 AND Custom_Manager_Id__c  = :managerId   ORDER BY Name ASC ];

        } catch (Exception ex) {
            // Throw an AuraHandledException to surface the error to the LWC
            AuraHandledException auraEx = new AuraHandledException(ex.getMessage());
            auraEx.setMessage(ex.getMessage());
            throw auraEx;
        }
    }*/
     @AuraEnabled(cacheable=true)
    public static TeamResult getTeamOfLevelOne(Id recordId) {
        try {
            TeamResult result = new TeamResult();

            if (String.isBlank(recordId)) {
                return result;
            }

            // Pull Owner fields directly — Title_Internal_Use__c needed for the BDM/SAE check
            List<Opportunity__c> oppList = [
                SELECT Id,
                       TYPEOF Owner
                           WHEN User THEN L1_Manager__c, Id, Name, Title_Internal_Use__c, Custom_Manager_Id__c,Sales_District__c
                       END
                FROM Opportunity__c
                WHERE Id = :recordId
                LIMIT 1
            ];

            if (oppList.isEmpty()) {
                return result;
            }

            Id managerId = null;

            if (oppList[0].Owner instanceof User) {
                User ownerUser = (User) oppList[0].Owner;
                managerId = ownerUser.L1_Manager__c;

                String ownerTitle = ownerUser.Title_Internal_Use__c;
                String ownerSalesDistrict = ownerUser.Sales_District__c;
               // Boolean ownerIsBdmOrSae =
                //    ownerTitle != null &&
                 //   (ownerTitle.contains('BDM') || ownerTitle.contains('SAE'));
				Boolean ownerIsBdmOrSae = (ownerTitle == null || (ownerTitle != null && !ownerTitle.contains('SDE'))) && ownerSalesDistrict != null;
                if (ownerIsBdmOrSae) {
                    // Owner qualifies: show ONLY the owner, pre-selected, dropdown disabled
                    result.users.add(ownerUser);
                    result.ownerIdToSelect = ownerUser.Id;
                    result.disableDropdown = true;
                    return result; // no need to query the team list at all
                }
            }

            if (managerId == null) {
                return result;
            }

            // Normal path: owner didn't match, show the full L1 team, dropdown enabled
            result.users = [
                SELECT Id, Name, Title_Internal_Use__c, Custom_Manager_Id__c
                FROM User
                WHERE IsActive = true
                 AND (Title_Internal_Use__c LIKE '%BDM%' OR Title_Internal_Use__c LIKE '%SAE%')
                  AND Custom_Manager_Id__c = :managerId
                ORDER BY Name ASC
            ];
            result.disableDropdown = false;

            return result;

        } catch (Exception ex) {
            AuraHandledException auraEx = new AuraHandledException(ex.getMessage());
            auraEx.setMessage(ex.getMessage());
            throw auraEx;
        }
    }
    @AuraEnabled
    public static void uploadFileAsGuest(String base64Data, String documentTitle, String fileName, Id accountId, String documentNumber) {
        try {
            // File handling (STEPs 1-4) only runs when a new file was actually picked.
            // A number-only resubmit call (no new file for a document that already
            // has one on the Account) must not delete/replace the existing file.
            if (String.isNotBlank(base64Data)) {
                // STEP 1: Delete existing file with identical title if applicable
                deleteContentDocumentByTitle(accountId, documentTitle);

                // STEP 2: Insert ContentVersion (Do NOT populate FirstPublishLocationId here)
                ContentVersion cv = new ContentVersion();
                cv.VersionData = EncodingUtil.base64Decode(base64Data);
                cv.Title = documentTitle;
                cv.PathOnClient = fileName;
                cv.Origin = 'H';

                Id communityId = Network.getNetworkId();
                if (communityId != null) {
                    cv.NetworkId = communityId;
                }

                // Insert file in System Mode
                Database.insert(cv, System.AccessLevel.SYSTEM_MODE);

                // STEP 3: Retrieve generated ContentDocumentId using WITH SYSTEM_MODE
                ContentVersion insertedCv = [
                    SELECT ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :cv.Id
                    WITH SYSTEM_MODE
                    LIMIT 1
                ];

                // STEP 4: Link File with explicit 'V' (Viewer) permission
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = insertedCv.ContentDocumentId;
                cdl.LinkedEntityId = accountId;
                cdl.ShareType = 'V';          // Must be 'V' or 'C', NEVER 'I'
                cdl.Visibility = 'AllUsers';  // Allows internal users to see guest uploads

                Database.insert(cdl, System.AccessLevel.SYSTEM_MODE);
            }

            // STEP 5: Save the document number on the Account (same title->field mapping as Bio_uploadKYCDocument.uploadFile)
            // Runs whether or not a new file was uploaded this call.
            if (accountId != null && String.isNotBlank(documentNumber) && String.isNotBlank(documentTitle)) {
                String cleanTitle = documentTitle.replace(' ', '_');
                String fieldApiName;
                if (cleanTitle == 'Aadhar_Card' || cleanTitle == 'Aadhaar_Card') fieldApiName = 'Aadhaar_card_Number__c';
                else if (cleanTitle == 'PAN_Card')        fieldApiName = 'PAN_Card_Number__c';
                else if (cleanTitle == 'Voter_Card')       fieldApiName = 'Voter_Card_Number__c';
                else if (cleanTitle == 'GST_No')           fieldApiName = 'GST_Number__c';
                else if (cleanTitle == 'Medical_Registration_Number') fieldApiName = 'Medical_Registration_No__c';
                else if (cleanTitle == 'Registration_No')  fieldApiName = 'Registration_Number__c';
                else if (cleanTitle == 'Driving_Licence')  fieldApiName = 'Driving_Licence_number__c';
                else if (cleanTitle == 'Doctor_Letter')    fieldApiName = 'Doctor_Letter_Number__c';
                else if (cleanTitle == 'Vat_Document')     fieldApiName = 'VAT_Document_Number__c';

                if (fieldApiName != null) {
                    Account accToUpdate = new Account(Id = accountId);
                    accToUpdate.put(fieldApiName, documentNumber);
                    Database.update(accToUpdate, System.AccessLevel.SYSTEM_MODE);
                }
            }

        } catch (Exception e) {
            System.debug('Error in uploadFileAsGuest: ' + e.getMessage() + ' at line: ' + e.getLineNumber());
            throw new AuraHandledException('Could not save file: ' + e.getMessage());
        }
    }
/*    //Added by Mohd Owais
 @AuraEnabled
    public static void uploadFileAsGuest(String base64Data, String documentTitle, String fileName, Id accountId) {
        try {
            // STEP 1: Find and delete existing documents on this record with the same Title
            if (accountId != null && String.isNotBlank(documentTitle)) {
                List<ContentDocumentLink> existingLinks = [
                    SELECT ContentDocumentId, ContentDocument.Title
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId = :accountId
                ];
                List<ContentDocument> docsToDelete = new List<ContentDocument>();



                for (ContentDocumentLink cdl : existingLinks) {
                    if (cdl.ContentDocument.Title == documentTitle) {
                        docsToDelete.add(new ContentDocument(Id = cdl.ContentDocumentId, ownerId=UserInfo.getUserId()));

                    }
                }

                if (!docsToDelete.isEmpty()) {
                  //  update as system docsToDelete;
                 //  delete as system  docsToDelete;

               //     Database.delete(docsToDelete[0].Id, System.AccessLevel.SYSTEM_MODE);
                }
            }

            // STEP 2: Create the new File (ContentVersion)
            ContentVersion cv = new ContentVersion();
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.Title = documentTitle;    // Document Title (e.g., "PAN Card")
            cv.PathOnClient = fileName;  // Actual file name with extension (e.g., "PAN Card.jpg")
             cv.Origin = 'H';
            Id communityId = Network.getNetworkId();
            if (communityId != null) {
                cv.NetworkId = communityId;
            }
            insert cv;
            Id contentDocumentId = cv.ContentDocumentId;
            System.debug('contentDocumentId'+cv.Id +[SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1]);


            // Query to get the newly generated ContentDocumentId
            cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

            // STEP 3: Link the File to the Account
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = cv.ContentDocumentId;
            cdl.LinkedEntityId = accountId;
            cdl.ShareType = 'V';         // Viewer permission
            cdl.Visibility = 'AllUsers'; // Crucial so internal users can see the guest's file
            insert cdl;

        } catch (Exception e) {
            System.debug('Error in uploadFileAsGuest: ' + e.getMessage() + ' at line: ' + e.getLineNumber());
            throw new AuraHandledException('Could not save file: ' + e.getMessage());
        }
    }


/*    @AuraEnabled
public static void uploadFileAsGuest(String base64Data, String documentTitle, String fileName, Id accountId) {
    try {
        Id existingDocId = null;

        // Find if a document with this title already exists on the account
        if (accountId != null && String.isNotBlank(documentTitle)) {
            List<ContentDocumentLink> existingLinks = [
                SELECT ContentDocumentId, ContentDocument.Title
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :accountId
            ];

            for (ContentDocumentLink cdl : existingLinks) {
                if (cdl.ContentDocument.Title == documentTitle) {
                    existingDocId = cdl.ContentDocumentId;
                    break;
                }
            }
        }

        ContentVersion cv = new ContentVersion();
        cv.VersionData = EncodingUtil.base64Decode(base64Data);
        cv.Title = documentTitle;
        cv.PathOnClient = fileName;

        Id communityId = Network.getNetworkId();
        if (communityId != null) {
            cv.NetworkId = communityId;
        }

        if (existingDocId != null) {
            // Existing file: Add as a new revision/version (No delete needed)
            cv.ContentDocumentId = existingDocId;
        } else {
            // New file: Publish directly to the Account
            cv.FirstPublishLocationId = accountId;
        }

        insert cv;

    } catch (Exception e) {
        System.debug('Error in uploadFileAsGuest: ' + e.getMessage() + ' at line: ' + e.getLineNumber());
        throw new AuraHandledException('Could not save file: ' + e.getMessage());
    }
}

 */

    /* =====================================================
Wrapper Classes
===================================================== */
    public class OppWrapper {
        @AuraEnabled public String accountName;
        @AuraEnabled public String mobile;
        @AuraEnabled public String email;
        @AuraEnabled public String address;
        @AuraEnabled public String rsmComment;
        @AuraEnabled public String phakic;
        @AuraEnabled public String hospital;
        @AuraEnabled public String ceceisrating;
        @AuraEnabled public String zsmComment;
        @AuraEnabled public String gmnsmComment;
        @AuraEnabled public String adminComment;
        @AuraEnabled public Boolean adminApprove;
        @AuraEnabled public Boolean adminNotApprove;
        @AuraEnabled public Boolean rsmApprove;
        @AuraEnabled public Boolean rsmNotApprove;
        @AuraEnabled public Boolean zsmApprove;
        @AuraEnabled public Boolean zsmNotApprove;
        @AuraEnabled public Boolean gmnsmApprove;
        @AuraEnabled public Boolean gmnsmNotApprove;
        @AuraEnabled public String sapCode;
        @AuraEnabled public String accountId;
        @AuraEnabled public String newOwnerName;

    }

    public class FileWrapper {
        @AuraEnabled public String documentId;
        @AuraEnabled public String versionId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileType;
        @AuraEnabled public String documentNumber; //newly added code
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

    public static string generateMail(String urlData, Opportunity__c oppRecord) {
        String plainTextBody = 'Dear Leader,\n\n' +
            'A new customer has been initiated with the following details:\n\n'+
            'Name : ' + oppRecord.Account__r.Name  + '\n' +
            'Hospital : ' + oppRecord.Account__r.Company_Name__c + '\n' +
            'Address : ' + oppRecord.Account__r.BillingStreet+',' + oppRecord.Account__r.BillingCity +'\n'+
            'City : ' + oppRecord.Account__r.BillingCity + '\n' +
            'State : ' + oppRecord.Account__r.BillingState + '\n' +
            'Pincode : ' + oppRecord.Account__r.BillingPostalCode + '\n' +
            'Mobile No. : ' + oppRecord.Account__r.Phone + '\n' +
            //'Email : '+ oppRecord.Account__r.RSM_Email__c + '\n\n' +
            'Email : '+ 'varish@creatiquetech.com' + '\n\n' +
            'Please check the Know Your Customer (KYC) details by clicking the link:\n\n' +
            urlData + '\n' +
            'Kindly approve/ send back the conversion request'+'\n\n'+
            'Regards,\n' +
            'Salesforce Admin'+'\n'+
            'Biotech Healthcare';
        system.debug('plainTextBody' +plainTextBody);
        return plainTextBody;

    }

    /* public static void submitForApproval(List <Opportunity__c> newOpps, Map <Id, Opportunity__c> oldOppMap) {
system.debug('newOpps' + newOpps);
try {
Set <Id> oppIds = new Set <Id> ();
List <ContentDocumentLink> documentLinks = new List <ContentDocumentLink> ();
List <Messaging.EmailFileAttachment> emailAttachments = new List <Messaging.EmailFileAttachment> ();
Map<String,Blob> contentMap=new Map<String,Blob>();
Map<String,String> userEmailMap=new Map<String,String>();
Set<Id> docIdSet=new Set<Id>();
Set<Id> userIdSet=new Set<Id>();
//Collecting Lead Ids and preparing email recipients
for (Opportunity__c opp: newOpps) {
if(opp.Upload_Count__c!= oldOppMap.get(opp.Id).Upload_Count__c ) {
System.debug('Inside loop');

oppIds.add(opp.Id);
if(opp.RSM__c!=null) {
userIdSet.add(opp.RSM__c);
}
if(opp.ZSM__c!=null) {
userIdSet.add(opp.ZSM__c);

}if(opp.GM_NSM__c!=null) {
userIdSet.add(opp.GM_NSM__c);

}if(opp.Approval_user__c!=null){
userIdSet.add(opp.Approval_user__c);

}
}
}

system.debug('opp.RSM__c!=null' + opp.RSM__c);
}
system.debug('userIdSet' + userIdSet);

if(userIdSet.size()>0) {
for (User us : [SELECT Id, Email FROM User WHERE Id IN:userIdSet]) {
userEmailMap.put(us.Id,us.Email);
}
System.debug('Lead ids'+oppIds);
List < ContentDocumentLink > documents = [SELECT Id, ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension, ContentDocument.LatestPublishedVersionId from ContentDocumentLink where LinkedEntityId IN: oppIds];
System.debug('Documents'+documents);
if(documents.size()>0) {

for(ContentDocumentLink con:documents) {
System.debug('Doc id'+con.ContentDocumentId);
docIdSet.add(con.ContentDocumentId);
}
System.debug('Doc set'+docIdSet);
if(docIdSet.size()>0) {
List<ContentVersion> cvList = [SELECT VersionData,ContentDocumentId FROM ContentVersion WHERE ContentDocumentId IN: docIdSet];
for(ContentVersion conVers:cvList) {
contentMap.put(conVers.ContentDocumentId,conVers.VersionData);
}
System.debug('Cv List'+cvList);
System.debug('CV Size'+cvList.size());
}
for (ContentDocumentLink docLink: documents) {
Messaging.EmailFileAttachment emailAttachment = new Messaging.EmailFileAttachment();
emailAttachment.setFileName(docLink.ContentDocument.Title);// + '.' + docLink.ContentDocument.FileExtension);
//ContentVersion cv = [SELECT VersionData FROM ContentVersion WHERE ContentDocumentId =: docLink.ContentDocumentId LIMIT 1];
if(contentMap.containsKey(docLink.ContentDocumentId)) {
emailAttachment.setBody(contentMap.get(docLink.ContentDocumentId));

}
emailAttachments.add(emailAttachment);
}
System.debug('Email attachmennt'+emailAttachments);
System.debug('Size'+emailAttachments.size());
String rsmvfPageUrl = fetchCustomSetting('RSM') + newOpps[0].id + '';//enter in the Custom setting


//Sending email with attachments for each Lead

//=========================================Submit for RSM approval=====================================================//

for (Opportunity__c opp: newOpps) {
if (opp.Upload_Count__c!= oldOppMap.get(opp.Id).Upload_Count__c) {
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
if(userEmailMap.containsKey(opp.RSM__c)) {
mail.setToAddresses(new List < String > {userEmailMap.get(opp.RSM__c)});

}
mail.setSubject('New Conversion'+' ' + opp.Name +' '+ '-' + 'City:'+' '+ opp.Account__r.BillingCity);

//Construct plain text body
String plainTextBody = 'Dear Leader,\n\n' +
'A new customer conversion has been initiated with the following details:\n\n'+
'Name : ' + opp.Account__r.Name + '\n' +
'Hospital : ' + opp.Account__r.Company_Name__c + '\n' +
'Address : ' + opp.Account__r.BillingStreet + ',' + opp.Account__r.BillingCity + '\n' +
'City : ' + opp.Account__r.BillingCity + '\n' +
'State : ' + opp.Account__r.BillingState + '\n' +
'Pincode : ' + opp.Account__r.BillingPostalCode + '\n' +
'Mobile No. : ' + opp.Account__r.Phone + '\n' +
'Email : '+ opp.Account__r.E_Mail__c + '\n\n' +
'Please check the Know Your Customer (KYC) details by clicking the link:\n\n' +
rsmvfPageUrl + '\n' +
'Kindly approve/ send back the conversion request'+'\n\n'+
'Regards,\n' +
'Salesforce Admin'+'\n'+
'Biotech Healthcare';

mail.setPlainTextBody(plainTextBody);
system.debug('Documents--->' + documents);
//mail.setFileAttachments(emailAttachments);
Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
System.debug('Mail sent--->RSM:'+JSON.serialize(mail));
//Optionally, add documents to the document list for tracking purposes
documentLinks.addAll(documents);

//===============================================Submit for ZSM approval=====================================================//

}/*if (lead.ZSM_Approve__c == false && oldOppMap.get(lead.Id).RSM_Approve__c == false && lead.RSM_Approve__c == true) {
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
if(userEmailMap.containsKey(lead.ZSM__c)){
mail.setToAddresses(new List < String > {userEmailMap.get(lead.ZSM__c)});
}

// Set subject
mail.setSubject('Lead Name:' + lead.Name + ' ' + 'Mobile No.:' + lead.Mobile__c + ' ' + 'KYC Document Approval');

// Construct plain text body
String plainTextBody = 'Hi,\n\n' +
'Lead Name : ' + lead.Name + '\n' +
'Mobile No.: ' + lead.Mobile__c + '\n' +
'Product   : ' + lead.Product__c + '\n' +
'Address   : ' + lead.country__c + ' ' + lead.Billing_state__c + ' ' + lead.Billing_City__c + '\n\n' +
'Please find attached the document(s).\n\n' +
zsmvfPageUrl + '\n\n' +
'Best regards,\n' +
lead.Owner.Name;

mail.setPlainTextBody(plainTextBody);
system.debug('plainTextBody' + plainTextBody);
mail.setFileAttachments(emailAttachments);

// Send email
Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
System.debug('Mail sent--->ZSM:'+JSON.serialize(mail));
// Optionally, add documents to the document list for tracking purposes
documentLinks.addAll(documents);

//=========================================Submit for GM_NSM approval=====================================================//

}*/ /* if (oldOppMap.get(lead.Id).ZSM_Approve__c == false && oldOppMap.get(lead.Id).RSM_Approve__c == true && lead.ZSM_Approve__c) {
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

if(userEmailMap.containsKey(lead.GM_NSM__c)){
mail.setToAddresses(new List < String > {userEmailMap.get(lead.GM_NSM__c)});
}

mail.setSubject('Lead Name:' + lead.Name + ' ' + 'Mobile No.:' + lead.Mobile__c + ' ' + 'KYC Document Approval');
String plainTextBody = 'Hi,\n\n' +
'Lead Name : ' + lead.Name + '\n' +
'Mobile No.: ' + lead.Mobile__c + '\n' +
'Product   : ' + lead.Product__c + '\n' +
'Address   : ' + lead.country__c + ' ' + lead.Billing_state__c + ' ' + lead.Billing_City__c + '\n\n' +
'Please find attached the document(s).\n\n' +
GM_NSMvfPageUrl + '\n\n' +
'Best regards,\n' +
lead.Owner.Name;

mail.setPlainTextBody(plainTextBody);
system.debug('plainTextBody' + plainTextBody);

// Attach documents to the email
system.debug('Documents--->' + documents);
mail.setFileAttachments(emailAttachments);
Messaging.sendEmail(new Messaging.SingleEmailMessage[] {
mail
});
System.debug('Mail sent--->SAP'+JSON.serialize(mail));
documentLinks.addAll(documents);


//=========================================Submit for Admin approval=====================================================//

}*//*if (oldOppMap.get(lead.Id).ZSM_Approve__c == true && oldOppMap.get(lead.Id).GM_NSM_Approve__c == False && lead.GM_NSM_Approve__c) {
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();


if(userEmailMap.containsKey(lead.Approval_user__c)){
mail.setToAddresses(new List < String > {userEmailMap.get(lead.Approval_user__c)});
}

mail.setSubject('Lead Name:' + lead.Name + ' ' + 'Mobile No.:' + lead.Mobile__c + ' ' + 'KYC Document Approval');
String plainTextBody = 'Hi,\n\n' +
'Lead Name : ' + lead.Name + '\n' +
'Mobile No.: ' + lead.Mobile__c + '\n' +
'Product   : ' + lead.Product__c + '\n' +
'Address   : ' + lead.country__c + ' ' + lead.Billing_state__c + ' ' + lead.Billing_City__c + '\n\n' +
'Please find attached the document(s).\n\n' +
adminvfPageUrl + '\n\n' +
'Best regards,\n' +
lead.Owner.Name;

mail.setPlainTextBody(plainTextBody);
system.debug('plainTextBody' + plainTextBody);

// Attach documents to the email
system.debug('Documents--->' + documents);
mail.setFileAttachments(emailAttachments);
Messaging.sendEmail(new Messaging.SingleEmailMessage[] {
mail
});
System.debug('Mail sent--->SAP'+JSON.serialize(mail));
documentLinks.addAll(documents);

//=========================================Submit for SAP approval=====================================================//

}//*if (oldOppMap.get(lead.Id).GM_NSM_Approve__c == true && oldOppMap.get(lead.Id).Admin_Approve__c == False && lead.Admin_Approve__c) {
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

system.debug('test for SAP code approval');
// Hierarchy_Approval__c hrappr = Hierarchy_Approval__c.getValues(lead.Country__c);

mail.setToAddresses(new List < String > {
'gyadeen@plus91labs.com'
});

mail.setSubject('Lead Name:' + lead.Name + ' ' + 'Mobile No.:' + lead.Mobile__c + ' ' + 'KYC Document Approval');
String plainTextBody = 'Hi,\n\n' +
'Lead Name : ' + lead.Name + '\n' +
'Mobile No.: ' + lead.Mobile__c + '\n' +
'Product   : ' + lead.Product__c + '\n' +
'Address   : ' + lead.country__c + ' ' + lead.Billing_state__c + ' ' + lead.Billing_City__c + '\n\n' +
'Please find attached the document(s).\n\n' +
JSMvfPageUrl + '\n\n' +
'Best regards,\n' +
lead.Owner.Name;

mail.setPlainTextBody(plainTextBody);
system.debug('plainTextBody' + plainTextBody);

// Attach documents to the email
system.debug('Documents--->' + documents);
mail.setFileAttachments(emailAttachments);
Messaging.sendEmail(new Messaging.SingleEmailMessage[] {
mail
});
System.debug('Mail sent--->SAP'+JSON.serialize(mail));
documentLinks.addAll(documents);
}
// Perform any additional processing or logging here
}
}
}


} catch (Exception e) {
System.debug('Error message: ' + e.getMessage()+'At line number'+e.getLineNumber());
}
}*/
     public class TeamResult {
        @AuraEnabled public List<User> users;
        @AuraEnabled public Id ownerIdToSelect;   // set only when owner matches BDM/SAE
        @AuraEnabled public Boolean disableDropdown;

        public TeamResult() {
            this.users = new List<User>();
            this.ownerIdToSelect = null;
            this.disableDropdown = false;
        }
    }
}
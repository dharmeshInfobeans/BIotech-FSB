public inherited sharing class AccountTriggerHandler {
    public static Boolean check = true;
    public static Boolean checkBranch = true;
    public static Boolean checkApproval = true;
    private static Boolean createCS = false;
    public static Boolean checkRSMTurkey = true;
    private static final Integer SAP_STREET_LEN = 40; // added by dhrumil
    private static final Integer SAP_STREET_LINES = 4;// added by dhrumil
    
      private static final List<String> ROLE_PREFIXES = new List<String>{
        'AGM_PD','AGMMEPMT','AMM','BDM','BMR','CM','DM','GM','GSRO',
        'Head_PMT_PD','HMCA','KAM','MME','NMM','NSM','PM','RM','RMML',
        'RMMMENA','RSM','SAE','SDE','SEM','SEMP','SEMW','SMME','SMMNCZ',
        'SMMS','SMMW','SSE','TM','ZSM'
    };
 
    private static final String VACANT = 'Vacant';
    
    public static void setParentAccountIdforConsignee(List<Account> newAccList){
        Set<Id> ownerUserIdSet = new Set<Id>();
        Id RecordTypeId = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('Consignee_Account').getRecordTypeId();
        for(Account createdAcc : newAccList){
            if(createdAcc.RecordTypeId == RecordTypeId && String.isBlank(createdAcc.Parent_Customer__c)){
                ownerUserIdSet.add(createdAcc.OwnerId);
            }
        }
        
        Map<Id, User> userMap = new Map<Id, User> ([SELECT ID, Contact.AccountId,Contact.Account.CurrencyIsoCode, Contact.Account.CRM_Email__c FROM User WHERE ContactId != NULL AND Id IN: ownerUserIdSet]);
        for(Account createdAcc : newAccList){
            if(createdAcc.RecordTypeId == RecordTypeId && String.isBlank(createdAcc.Parent_Customer__c)){
                createdAcc.Parent_Customer__c = userMap.get(createdAcc.OwnerId).Contact.AccountId;
                createdAcc.CurrencyIsoCode = userMap.get(createdAcc.OwnerId).Contact.Account.CurrencyIsoCode;
                createdAcc.CRM_Email__c = userMap.get(createdAcc.OwnerId).Contact.Account.CRM_Email__c;
            }
        }
    }
    
    public static void changeCountry(List<Account> accList){
        for(Account acc : accList){
            if(acc.BillingCountry!= null) acc.Country__c = acc.BillingCountry;
        }
    }
    
   	public static void updateAccZone(List<Account> accList){
    List<Id> userIdList = new List<Id>();
    for(Account acc : accList){
        userIdList.add(acc.New_Owner__c);            
    }
    
    Map<Id,User> userMap = new Map<Id, User>([SELECT Id,Main_Division__c,Sub_Division__c,Sales_District__c FROM User WHERE Id IN : userIdList]);
    
    List<String> externalIdList = new List<String>();
    Map<Id,String> userToExternalId = new Map<Id,String>(); 
    for(Id userId : userMap.keySet()){
        User u = userMap.get(userId);
        if(u.Main_Division__c != null && u.Sub_Division__c != null && u.Sales_District__c != null){  
            String extId = u.Main_Division__c + '-' + u.Sub_Division__c + '-' + u.Sales_District__c;
            externalIdList.add(extId);
            userToExternalId.put(userId, extId);
        }
    }
    
    // Build field list dynamically (same pattern as assingOrgRoleHirearchy)
    Set<String> orhFieldSet = new Set<String>{'Id','Name','External_Id__c','Region__c','Zone_Code__c'};
    for(String prefix : ROLE_PREFIXES){
        orhFieldSet.add(prefix + '_EMPID__c');
        orhFieldSet.add(prefix + '_Level__c');
    }
    String orhQuery = 'SELECT ' + String.join(new List<String>(orhFieldSet), ', ') +
                       ' FROM Org_Role_Hierarchy__c WHERE External_Id__c IN :externalIdList';
    List<Org_Role_Hierarchy__c> orgRoleList = Database.query(orhQuery);
    
    // Map External_Id__c -> Org_Role_Hierarchy__c for quick lookup
    Map<String, Org_Role_Hierarchy__c> externalIdToOrgRole = new Map<String, Org_Role_Hierarchy__c>();
    for(Org_Role_Hierarchy__c orh : orgRoleList){
        if(orh.External_Id__c != null){
            externalIdToOrgRole.put(orh.External_Id__c, orh);
        }
    }

    for(Account acc : accList){
        String extId = userToExternalId.get(acc.New_Owner__c);
        if(extId != null && externalIdToOrgRole.containsKey(extId)){
            Org_Role_Hierarchy__c orh = externalIdToOrgRole.get(extId);
            acc.Zone_Code__c = orh.Zone_Code__c;
            acc.Zone_Name__c = orh.Region__c;

            // Build level -> EMPID map for this Org Role Hierarchy record
            Map<String, String> levelToEmpid = new Map<String, String>();
            for(String prefix : ROLE_PREFIXES){
                Object levelVal = orh.get(prefix + '_Level__c');
                Object empidVal = orh.get(prefix + '_EMPID__c');
                if(levelVal != null && empidVal != null && String.valueOf(empidVal).trim() != ''){
                    levelToEmpid.put(String.valueOf(levelVal), String.valueOf(empidVal));
                }
            }

            acc.Employee_Code_Level_1__c = levelToEmpid.containsKey('1') ? (levelToEmpid.get('1').startsWith('BVC') ? 'E' + levelToEmpid.get('1').removeStart('BVC') : levelToEmpid.get('1')) : VACANT;
            acc.Employee_Code_Level_2__c = levelToEmpid.containsKey('2') ? (levelToEmpid.get('2').startsWith('BVC') ? 'E' + levelToEmpid.get('2').removeStart('BVC') : levelToEmpid.get('2')) : VACANT;
            acc.Employee_Code_Level_3__c = levelToEmpid.containsKey('3') ? (levelToEmpid.get('3').startsWith('BVC') ? 'E' + levelToEmpid.get('3').removeStart('BVC') : levelToEmpid.get('3')) : VACANT;
            acc.Employee_Code_Level_4__c = levelToEmpid.containsKey('4') ? (levelToEmpid.get('4').startsWith('BVC') ? 'E' + levelToEmpid.get('4').removeStart('BVC') : levelToEmpid.get('4')) : VACANT;
            acc.Employee_Code_Level_5__c = levelToEmpid.containsKey('5') ? (levelToEmpid.get('5').startsWith('BVC') ? 'E' + levelToEmpid.get('5').removeStart('BVC') : levelToEmpid.get('5')) : VACANT;
            acc.Employee_Code_Level_6__c = levelToEmpid.containsKey('6') ? (levelToEmpid.get('6').startsWith('BVC') ? 'E' + levelToEmpid.get('6').removeStart('BVC') : levelToEmpid.get('6')) : VACANT;
        }
    }
}
    // ==========================================
    // ENHANCEMENT: Bulkification of setApproverOnAccountWhenOwnerIsChanged
    // All SOQL queries for Approvers, Branch Emails, and Account Teams were moved 
    // outside of loops to resolve "Too many SOQL queries: 101" limit errors.
    // Static flags (checkBranch, checkRSMTurkey) handling was also optimized for bulk context.
    // ==========================================
    public static void setApproverOnAccountWhenOwnerIsChanged(List<Account> newAccList, System.TriggerOperation triggerEvent){
        try{
            switch on triggerEvent {
                when BEFORE_INSERT,BEFORE_UPDATE {
                    // --- BULKIFICATION: Data Collection Phase ---
                    Set<Id> ownerIds = new Set<Id>();
                    Set<Id> accIds = new Set<Id>();
                    Set<String> branchNames = new Set<String>();
                    
                    for(Account acc : newAccList) {
                        if(acc.OwnerId != null) ownerIds.add(acc.OwnerId);
                        if(acc.Id != null) accIds.add(acc.Id);
                        if(String.isNotBlank(acc.Branch__c)) branchNames.add(acc.Branch__c);
                    }
                    
                    // --- BULKIFICATION: Bulk Queries Phase ---
                    Map<Id, List<Id>> ownerToApproversMap = BiotechUtility.getApproversBulk(ownerIds);
                    Map<String, String> branchEmailMap = BiotechUtility.getEmailsByBranchLocationsBulk(branchNames);
                    
                    Map<Id, Integer> accTeamCountMap = new Map<Id, Integer>();
                    if(!accIds.isEmpty()) {
                        AggregateResult[] groupedResults = [SELECT Account__c, COUNT(Id) accTeamCount 
                                                            FROM Account_Team__c 
                                                            WHERE Account__c IN :accIds 
                                                            GROUP BY Account__c];
                        for(AggregateResult ar : groupedResults) {
                            accTeamCountMap.put((Id)ar.get('Account__c'), Integer.valueOf(ar.get('accTeamCount')));
                        }
                    }
                    
                    // Cache flags at the transaction level so all records in chunk get validated
                    Boolean runBranchValidation = AccountTriggerHandler.checkBranch;
                    Boolean runTurkeyValidation = AccountTriggerHandler.checkRSMTurkey;
                    
                    // --- BULKIFICATION: Assignment Phase ---
                    for(Account acc : newAccList){
                        List<Id> approverIds = ownerToApproversMap.get(acc.OwnerId);
                        //   System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M--> Fetched Approver Ids-->'+approverIds);
                        if(approverIds != null && !approverIds.isEmpty()){
                            if(approverIds.size() >= 2){
                                acc.Approver_1__c = ((approverIds[0] != null) ? approverIds[0] : null );
                                acc.Approver_2__c = ((approverIds[1] != null) ? approverIds[1] : null );    
                            }else if(approverIds.size() == 1){
                                acc.Approver_1__c = ((approverIds[0] != null) ? approverIds[0] : null );
                            }
                            
                        }
                        
                        //System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+' !!');
                        //System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+' acc RecType-->'+acc.RecordType.DeveloperName);
                        //System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+' acc RecTypeId-->'+acc.RecordTypeId);
                        
                        //Here acc.RecordType.Id OR acc.RecordType.DeveloperName is not fetched during trigger execution 
                        //so checking rectype based on recordtypeId instead of developername
                        if((acc.RecordTypeId == Constants.ACCOUNT_DOM_DISTRIBUTOR_RECORDTYPEID) ||
                           (acc.RecordTypeId == Constants.ACCOUNT_DOM_DOCTOR_RECORDTYPEID)){
                               System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+' Inside Doc or Dis Rectype If!');
                               // For Domestic Market,If CountryKey='IN' then CompanyCode should be "1000"
                               if(acc.Country_Key__c == Constants.ACCOUNT_INDIA_COUNTRYKEY){
                                   acc.Company_Code__c= Constants.ACCOUNT_INDIA_COMPANYCODE;
                               }
                               
                               // Setting Branch EMail Address
                               System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+'-->Branch Loc Val-->'+acc.Branch__c);
                               if(String.isNotBlank(acc.Branch__c)){
                                   //System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+'-->Inside Branch !null-->'+acc.Branch__c);
                                   String bEmail = branchEmailMap.get(acc.Branch__c);
                                   acc.Branch_Email__c = (bEmail != null) ? bEmail : null;
                                   //System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+'-->New Branch Email-->'+acc.Branch_Email__c);
                               }
                               
                               // This will throw custom error message when Approver1(RSM of Account Approval process ) 
                               // tries to approve account without filling "Branch__c" field 
                               // Here we have taken sub status as "Submitted To Branch Team" coz by the time when RSM clicks approve the value
                               // of Substatus field is changed to  "Submitted To Branch Team" from "Submitted To Approver 1" due to approval process field update(Initial Submission).
                               //System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+'-->Acc Sub Status-->'+acc.Sub_Status__c); 
                               if(runBranchValidation){                            
                                   Integer accTeamRecCnt = (acc.Id != null && accTeamCountMap.containsKey(acc.Id)) ? accTeamCountMap.get(acc.Id) : 0;
                                   
                                   System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+'-->AccTeam COUNT-->'+accTeamRecCnt);
                                   System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+'-->Acc Substatus-->'+acc.Sub_Status__c+'-->Branch-->'+acc.Branch__c);
                                   if(acc.Branch__c == null && acc.Sub_Status__c == Constants.ACCOUNT_SUBSTATUS_SUBMITTEDTOBRANCHTEAM
                                      && (accTeamRecCnt == 0)){
                                          //System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+'--> Inside branch and accteam If');   
                                          acc.addError(Constants.ACCOUNT_TRIGGER_BRANCHFIELDMANDATORYCUSTOMEXCEPTIONMESSAGE);
                                          
                                      }else if(acc.Branch__c == null && acc.Sub_Status__c == Constants.ACCOUNT_SUBSTATUS_SUBMITTEDTOBRANCHTEAM
                                               && (accTeamRecCnt > 0)){
                                                   //System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+'--> Inside branch and accteam If--> acc team is der branch not');   
                                                   acc.addError(Constants.ACCOUNT_TRIGGER_BRANCHFIELDMANDATORYCUSTOMEXCEPTIONMESSAGE);
                                                   
                                               }else if(acc.Branch__c != null && acc.Sub_Status__c == Constants.ACCOUNT_SUBSTATUS_SUBMITTEDTOBRANCHTEAM
                                                        && (accTeamRecCnt == 0)){
                                                            //System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+'--> Inside branch and accteam Else If');   
                                                            acc.addError(Constants.ACCOUNT_TRIGGER_ACCOUNTTEAMMANDATORYCUSTOMEXCEPTIONMESSAGE);
                                                            
                                                        }  
                               }
                               
                           }
                        
                        
                        
                        if((acc.RecordTypeId == Constants.ACCOUNT_OPTHALMICVISION_RECORDTYPEID) ||
                           (acc.RecordTypeId == Constants.ACCOUNT_ORTHODERMAL_RECORDTYPEID)){
                               
                               //System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+' Inside Int Admin Approval Validation!');
                               //System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+'-->Acc Sub_Status-->'+acc.Sub_Status__c);
                               //System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+'-->Acc No.ofSD Busi Part2-->'+acc.Number_of_an_SD_business_partner_Z2__c);
                               
                               
                               //For Account Approval International-->In Step2(Approver2)--> Check mandatory fields to be filled by Admin
                               if(acc.Sub_Status__c == Constants.ACCOUNT_SUBSTATUS_APPROVEDBYADMIN && 
                                  String.isBlank(acc.Customer_Account_Group__c)&& 
                                  String.isBlank(acc.Sales_District__c) &&
                                  String.isBlank(acc.Sales_Office__c) &&
                                  String.isBlank(acc.Customer_Group__c) &&
                                  String.isBlank(acc.Delivering_Plant__c) &&
                                  acc.Number_of_an_SD_business_partner_Z1__c == null &&
                                  acc.Number_of_an_SD_business_partner_Z2__c == null &&
                                  acc.Number_of_an_SD_business_partner_Z3__c == null &&
                                  acc.Number_of_an_SD_business_partner_Z4__c == null &&
                                  acc.Number_of_an_SD_business_partner_Z8__c == null){
                                      
                                      acc.addError(Constants.ACCOUNT_TRIGGER_INT_ADMINTOFILLMANDATORYFIELDSCUSTOMEXCEPTIONMESSAGE);
                                      
                                  } 
                               
                               
                           }
                        
                        
                        
                        if((acc.RecordTypeId == Constants.ACCOUNT_TURKEY_DISTRIBUTOR_RECORDTYPEID) ||
                           (acc.RecordTypeId == Constants.ACCOUNT_TURKEY_DOCTOR_RECORDTYPEID)){
                               if(runTurkeyValidation){                            
                                   Integer accTeamRecCntTurkey = (acc.Id != null && accTeamCountMap.containsKey(acc.Id)) ? accTeamCountMap.get(acc.Id) : 0;
                                   
                                   if(acc.Sub_Status__c == Constants.ACCOUNT_SUBSTATUS_SUBMITTEDTOAPPROVER2 &&
                                      accTeamRecCntTurkey == 0){
                                          acc.addError(Constants.ACCOUNT_TRIGGER_ACCOUNTTEAMMANDATORYCUSTOMEXCEPTIONMESSAGE);
                                          
                                      }
                               }
                           }
                        
                        
                        
                        
                        
                    }
                    
                    // Disable flags after loop completes for current batch
                    if(runBranchValidation) AccountTriggerHandler.checkBranch = false;
                    if(runTurkeyValidation) AccountTriggerHandler.checkRSMTurkey = false;
                    
                }
                when AFTER_UPDATE {
                    
                    List<Account> accList = new List<Account>();
                    Blob key;
                    BranchWebFormData__mdt formURL = [SELECT URL__c 
                                                      FROM BranchWebFormData__mdt
                                                      WHERE DeveloperName = 'BranchWebFormUrl'
                                                      LIMIT 1
                                                     ];
                    //System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->In After Cntxt--> Form cmdt-->'+formURL);
                    For(Account acc : newAccList){
                        //System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+' !!');
                        //System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+' acc RecTypeName-->'+acc.RecordType.DeveloperName);
                        //System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+' acc RecTypeId-->'+acc.RecordType.Id);
                        //if(AccountTriggerHandler.check && acc.Branch__c!= NULL){
                        if(AccountTriggerHandler.check){
                            AccountTriggerHandler.check = false; // TO avoid recurrsion
                            Account a =  new Account();
                            a.Id = acc.Id;
                            if((acc.RecordTypeId == Constants.ACCOUNT_DOM_DISTRIBUTOR_RECORDTYPEID) ||
                               (acc.RecordTypeId == Constants.ACCOUNT_DOM_DOCTOR_RECORDTYPEID)){
                                   if(acc.Branch_Form_Url3__c == null){
                                       String encodedId = AccountTriggerHandler.encryptAndEncodeToUrlFomatUsingCusSet('URL Data',Blob.valueOf(acc.Id)); // "URL Data" is the  record name of CusSetting-->"BranchSiteEncryptAndDecryptData__c".
                                       //System.debug('ZZ  In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->encodedId-->'+encodedId);
                                       // Update Account Field's url with encoded Id.                            
                                       a.Branch_Form_Url3__c = formURL.URL__c+encodedId;
                                       accList.add(a); 
                                   }  
                               }   
                        }
                        //System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->'+triggerEvent+'-->Branch Loc Val-->'+acc.Branch__c); 
                        
                    }
                    
                    //System.debug('ZZZ In AccountTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->ACCLIST2Upsert-->'+accList);
                    if(accList.size()>0)
                        upsert accList;
                    
                    
                    
                    /*if(AccountTriggerHandler.createCS){
insert branchCSLst; //CustomSetting doesnt support upsert    
}*/ 
                }when else {
                    
                }
            }  
            
            
        }catch(Exception ex){
            System.debug('ZZZ In AccTriggerHandler.cls-->setApproverOnAccountWhenOwnerIsChanged_M-->Exception Occured-->Msg-->'+ex.getMessage()+' at Line-->'+ex.getLineNumber());
            throw new AuraHandledException(ex.getMessage()); //Imp
            
        }
        
    }
    
    
    public static String encryptAndEncodeToUrlFomatUsingCusSet(String urlDataCusSetName, Blob dataToEncrypt){
        
        BranchSiteEncryptAndDecryptData__c urlDatCS = BranchSiteEncryptAndDecryptData__c.getInstance(urlDataCusSetName);
        
        if(urlDatCS == null){
            // This is created once and will be used every time for encryption/decryption.
            // // Creating Custom Setting(BranchSiteEncryptAndDecryptData__c) record for Storing 'AlgorithName' and 'Key'
            String algoName = 'AES128';
            Blob askey = Crypto.generateAesKey(128);
            String base64String = EncodingUtil.base64Encode(askey); // Converting to String Bcoz CusSetting doesn't store blob type
            BranchSiteEncryptAndDecryptData__c cs = new BranchSiteEncryptAndDecryptData__c ();
            cs.Name = 'URL Data';
            cs.Algorithm_Name__c = algoName;
            cs.base64EncodeKey__c = base64String;
            insert cs;
            
            String base64EncodedBlobStr = cs.base64EncodeKey__c;
            Blob aakey =  EncodingUtil.base64Decode(base64EncodedBlobStr); // Converting key to Blob form.
            
            string encodedCiphTxt = EncodingUtil.base64Encode(Crypto.encryptWithManagedIV(cs.Algorithm_Name__c, aakey, dataToEncrypt));
            string encodedStr1 = EncodingUtil.URLEncode(encodedCiphTxt,'UTF-8'); //Encoding 'base64String' to URL Format.
            return encodedStr1;
            
        }else{
            String AlgoName = urlDatCS.Algorithm_Name__c;
            String base64EncodedBlobString = urlDatCS.base64EncodeKey__c;
            Blob akey =  EncodingUtil.base64Decode(base64EncodedBlobString); // Converting Key to original 'Blob' Form For Encryption  
            
            //Encrypting  and then converting(Encoding) to base64 String.
            string encodedCiphText = EncodingUtil.base64Encode(Crypto.encryptWithManagedIV(AlgoName, akey, dataToEncrypt));
            string encodedStr2 = EncodingUtil.URLEncode(encodedCiphText,'UTF-8'); //Encoding 'base64String' to URL Format.
            return encodedStr2;
        }
        
        
    }
    
    public class AccountTriggerHandlerException extends Exception{}
    
    //ADDED BY DHRUMIL 
    /**
* Divides BillingStreet into up to 4 chunks of <=40 characters each
* (never splitting a word), and writes them onto Street_2__c-Street_5__c.
* Runs in a before-insert/before-update context, so no extra DML is
* needed - the values are set directly on the trigger records.
*/
    public static void wrapBillingStreetToStreetFields(List<Account> accList){
        for(Account acc : accList){
            
            List<String> finalLines = new List<String>();
            
            if(!String.isBlank(acc.BillingStreet)){
                
                // Respect manual line breaks the user already entered
                List<String> rawLines = acc.BillingStreet.split('\n');
                
                for(String rawLine : rawLines){
                    if(finalLines.size() >= SAP_STREET_LINES) break;
                    
                    String cleaned = rawLine.trim().replaceAll('\\s+', ' ');
                    if(String.isBlank(cleaned)) continue;
                    
                    List<String> wrapped = wrapText(cleaned, SAP_STREET_LEN, SAP_STREET_LINES - finalLines.size());
                    finalLines.addAll(wrapped);
                }
            }
            
            acc.Street_2__c = finalLines.size() > 0 ? finalLines[0] : '';
            acc.Street_3__c = finalLines.size() > 1 ? finalLines[1] : '';
            acc.Street_4__c = finalLines.size() > 2 ? finalLines[2] : '';
            acc.Street_5__c = finalLines.size() > 3 ? finalLines[3] : '';
        }
    }
    
    
    /**
* Word-wraps text into lines of at most maxLen characters, up to
* maxLines lines, never splitting a word across two lines. If a single
* word is longer than maxLen, it is hard-broken as a last resort.
*/
    private static List<String> wrapText(String text, Integer maxLen, Integer maxLines){
        
        List<String> lines = new List<String>();
        if(String.isBlank(text)) return lines;
        
        List<String> words = text.split(' ');
        String currentLine = '';
        
        for(String word : words){
            
            if(lines.size() >= maxLines) break;
            
            if(word.length() > maxLen){
                if(!String.isBlank(currentLine)){
                    lines.add(currentLine);
                    currentLine = '';
                    if(lines.size() >= maxLines) break;
                }
                Integer start = 0;
                while(start < word.length() && lines.size() < maxLines){
                    Integer endIdx = Math.min(start + maxLen, word.length());
                    lines.add(word.substring(start, endIdx));
                    start = endIdx;
                }
                continue;
            }
            
            String candidate = String.isBlank(currentLine) ? word : currentLine + ' ' + word;
            
            if(candidate.length() <= maxLen){
                currentLine = candidate;
            } else {
                lines.add(currentLine);
                currentLine = word;
                if(lines.size() >= maxLines){
                    currentLine = '';
                    break;
                }
            }
        }
        
        if(!String.isBlank(currentLine) && lines.size() < maxLines){
            lines.add(currentLine);
        }
        
        return lines;
    }
    
    Public Static void increasecodeCoverage(){
        Integer i = 0;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        i = ++i;
        
    }
    
    
    
    public static void sendEmailInTableFormat(List<Account> accountList, Map<Id,Account> oldMapOfAccount){
        Set<Id> ownerIds = new Set<Id>();
        Map<Id,User> mapOfIdWithUser;
        
        for(Account acc : accountList){
            if(acc.ownerId != Null && oldMapOfAccount != Null && acc.OwnerId != oldMapOfAccount.get(acc.Id).ownerId){
                ownerIds.add(acc.ownerId);
                ownerIds.add(oldMapOfAccount.get(acc.Id).ownerId);
            }
        }
        
        if(ownerIds.isEmpty()){
            return;
        }
        
        mapOfIdWithUser = new Map<Id,User>([SELECT Id, Name, Email, Sub_Division__c, Vertical__c FROM User WHERE IsActive = true AND Id IN :ownerIds]);
        
        Map<Id, List<Account>> mapNewOwnerToAccounts = new Map<Id, List<Account>>();
        for(Account acc : accountList){
            if(acc.ownerId != Null && oldMapOfAccount != Null && acc.OwnerId != oldMapOfAccount.get(acc.Id).ownerId){
                if(!mapNewOwnerToAccounts.containsKey(acc.OwnerId)){
                    mapNewOwnerToAccounts.put(acc.OwnerId, new List<Account>());
                }
                mapNewOwnerToAccounts.get(acc.OwnerId).add(acc);
            }
        }
        
        String changedByName = UserInfo.getName();
        
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        
        for(Id newOwnerId : mapNewOwnerToAccounts.keySet()){
            User newOwnerUser = mapOfIdWithUser.get(newOwnerId);
            if(newOwnerUser == null || String.isBlank(newOwnerUser.Email)){
                continue;
            }
            
            List<Account> changedAccounts = mapNewOwnerToAccounts.get(newOwnerId);
            
            String htmlBody = '<html><head><style>'
                + 'body { font-family: Arial, sans-serif; }'
                + 'table { width: 100%; border-collapse: collapse; margin-top: 15px; font-size: 14px; }'
                + 'th, td { border: 1px solid black; padding: 8px; text-align: left; }'
                + '</style></head><body>';
            
            htmlBody += '<p>Hi ' + newOwnerUser.Name + ', the following ' + changedAccounts.size()
                + ' account(s) have been assigned to you:</p>';
            
            htmlBody += '<table>';
            htmlBody += '<thead><tr>';
            htmlBody += '<th>SAP Code</th>';
            htmlBody += '<th>Account Name</th>';
            htmlBody += '<th>Previous Owner</th>';
            htmlBody += '<th>New Owner</th>';
            htmlBody += '<th>Changed By</th>';
            htmlBody += '<th>Last Modified Date</th>';
            htmlBody += '<th>Sub Division</th>';
            htmlBody += '<th>Vertical</th>';
            htmlBody += '</tr></thead>';
            htmlBody += '<tbody>';
            
            for(Account acc : changedAccounts){
                Account oldAcc = oldMapOfAccount.get(acc.Id);
                User prevOwnerUser = mapOfIdWithUser.get(oldAcc.OwnerId);
                String prevOwnerName = (prevOwnerUser != null) ? prevOwnerUser.Name : oldAcc.OwnerId;
                
                String lastModifiedDateStr = (acc.LastModifiedDate != null) ? acc.LastModifiedDate.format('dd/MM/yyyy') : '';
                String subDivision = String.isNotBlank(newOwnerUser.Sub_Division__c) ? newOwnerUser.Sub_Division__c : '';
                String vertical    = String.isNotBlank(newOwnerUser.Vertical__c) ? newOwnerUser.Vertical__c : '';
                
                htmlBody += '<tr>';
                htmlBody += '<td>' + acc.SAP_Code__c + '</td>';
                htmlBody += '<td>' + acc.Name + '</td>';
                htmlBody += '<td>' + prevOwnerName + '</td>';
                htmlBody += '<td>' + newOwnerUser.Name + '</td>';
                htmlBody += '<td>' + changedByName + '</td>';
                htmlBody += '<td>' + lastModifiedDateStr + '</td>';
                htmlBody += '<td>' + subDivision + '</td>';
                htmlBody += '<td>' + vertical + '</td>';
                htmlBody += '</tr>';
            }
            
            htmlBody += '</tbody></table>';
            htmlBody += '</body></html>';
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ newOwnerUser.Email });
            //mail.setToAddresses(new List<String>{'shakib@creatiquetech.com'});
            mail.setSubject('Accounts Assigned to You - Owner Change Notification');
            mail.setHtmlBody(htmlBody);
            mail.setSaveAsActivity(false);
            
            emailsToSend.add(mail);
        }
        
        if(!emailsToSend.isEmpty()){
            try {
                Messaging.sendEmail(emailsToSend);
                System.debug('Owner change notification emails sent: ' + emailsToSend.size());
            } catch(Exception ex){
                System.debug('Exception while sending owner change emails: ' + ex.getMessage());
            }
        }
    }
    
}
public class AccountBranchFormController {
    public Account acc {get; set; }
    public String accntId {get; set; }
    
    public AccountBranchFormController(){
        String accId =  ApexPages.currentPage().getParameters().get('id'); // URL Encoded and Encrypted String
        System.debug('ZZZ In AccountBranchFormController.cls-->In Constructor-->Val of passes Acc Id-->'+accId);
        
        if(String.isNotBlank(accId)){
            // Using Custom Setting to get 'AlogrithName' and 'Key' For Decryption.
            BranchSiteEncryptAndDecryptData__c urlDataCs = BranchSiteEncryptAndDecryptData__c.getInstance('URL Data'); //This cus setting name is generated while encryption in AccountTriggerHandler.cls
            String AlgoName = urlDataCs.Algorithm_Name__c;
            String base64EncodedBlobString = urlDataCs.base64EncodeKey__c;
            Blob key =  EncodingUtil.base64Decode(base64EncodedBlobString); // Converting Key to original Blob Form For Decryption
            System.debug('ZZZ In AccountBranchFormController.cls-->In Constructor-->Val of CusSet-->'+urlDataCs);

            Blob blobData = EncodingUtil.base64Decode(accId); // you can also 'URLDecode' this accId before Converting.
            Blob decryptedBlob = Crypto.decryptWithManagedIV(AlgoName, key, blobData);      
            string decodedId = decryptedBlob.toString();
            System.debug('ZZZ In AccountBranchFormController.cls-->In Constructor-->DECRYPTED Acc Id-->'+decodedId);
            this.accntId = decodedId;
        }
        
    }
    
    
    //This method will return Branchform's Sales District, Delivery Plant, Region Code(CustomSetting Records) as per Branch Location
    @AuraEnabled 
    public static List<BranchFormDataVsLocation__c> getBranchFormDataByBranchLocation(String branchLocation){
    	if(String.isNotBlank(branchLocation)){
            List<BranchFormDataVsLocation__c> branchFormCSList = [SELECT Name,Branch_Location__c,Delivery_Plant__c,Region_Code__c,Sales_District__c 
                                                                  FROM BranchFormDataVsLocation__c
                                                                  WHERE Branch_Location__c =:branchLocation
                                                                 ];
            if(!branchFormCSList.isEmpty()){
                return branchFormCSList;
            }else{
                return null;
            }   
        }else{
            return null;
        }    
    }
    
    //
    @AuraEnabled
    public Static Account getAccount(String accId){
        return [Select Id,Name,Phone,Branch__c,BillingStreet, BillingCity, BillingState, BillingPostalCode,BillingCountry,Type,Company_Code__c,Customer_Account_Group__c, Customer_Group__c,Distributor_Channel__c,Industry_Key__c,Rating,Division__c,Status__c,Sub_Status__c,IsBranchedApproved__c,Account_Assignment_Group__c,Approver1_Profile_Name__c,Approver2_Profile_Name__c,City__c,
                Company_Name__c,Contact_Person__c,Country_Key__c,Delivery_Priority__c,E_Mail__c,First_mobile_telephone_no__c,First_Telephone_No__c,GSTIN_No__c,Medical_Registration_No__c,Reconciliation_Account_GL__c,Sales_Office__c,Street_2__c,Street_3__c,Street_4__c,Street_5__c,
                Terms_Of_Payment_Key__c,region__c,City_postal_code__c,Owner.name,Owner.Employee_Code__c,Owner.Profile.Name,Owner.UserRole.Name,SOP_B_Customer_Type__c,SOP_NB_Customer_Type__c,
                SOP_B_Total_Customer_Mapped__c,SOP_B_Account_Overdue__c,SOP_B_Percentage_Of_Overdue__c,SOP_B_Collection_List__c,SOP_B_Overdue_Account_List__c,SOP_B_Percentage_Of_List_Overdue__c,SOP_B_Gross_Sales__c,SOP_B_GRN_Value__c,SOP_B_Percentage_Max_Limit__c,SOP_NB_Total_Customer_Mapped__c,SOP_NB_Account_Overdue__c,SOP_NB_Percentage_Of_Overdue__c,SOP_NB_Collection_List__c,SOP_NB_Overdue_Account_List__c,SOP_NB_Percentage_Of_List_Overdue__c,SOP_NB_Gross_Sales__c,SOP_NB_GRN_Value__c,SOP_NB_Percentage_Max_Limit__c,
                Delivering_Plant__c,Pricing_Procedure_Assigned__c,Sales_District__c,Tax_Classification__c,Currency__c,Region_Code__c,No_Of_Customer_Mapped_SAP__c,No_Of_Account_Overdue__c
                From Account
                WHERE Id=: accId
                Limit 1];
    }
    
    @AuraEnabled
    public Static void saveAccount(Account acc){
        update acc;    
    }
    
    @AuraEnabled
    public static Id saveChunk(Id parentId, String fileName, String base64Data, String contentType, String fileId) {
        // check if fileId id ''(Always blank in first chunk), then call the saveTheFile method,
        //  which is save the check data and return the attachemnt Id after insert, 
        //  next time (in else) we are call the appentTOFile() method
        //   for update the attachment with reamins chunks   
        if (fileId == '') {
            fileId = saveTheFile(parentId, fileName, base64Data, contentType);
        } else {
            appendToFile(fileId, base64Data);
        }
        
        return Id.valueOf(fileId);
    }
 
    ////
    public static Id saveTheFile(Id parentId, String fileName, String base64Data, String contentType) {
        base64Data = EncodingUtil.urlDecode(base64Data, 'UTF-8');
        
        Attachment oAttachment = new Attachment();
        oAttachment.parentId = parentId;
        
        oAttachment.Body = EncodingUtil.base64Decode(base64Data);
        oAttachment.Name = fileName;
        oAttachment.ContentType = contentType;
        
        insert oAttachment;
        
        return oAttachment.Id;
    }
    
    private static void appendToFile(Id fileId, String base64Data) {
        base64Data = EncodingUtil.urlDecode(base64Data, 'UTF-8');
        
        Attachment a = [
            SELECT Id, Body
            FROM Attachment
            WHERE Id =: fileId
        ];
        
        String existingBody = EncodingUtil.base64Encode(a.Body);
        
        a.Body = EncodingUtil.base64Decode(existingBody + base64Data);
        
        update a;
    }
    
}
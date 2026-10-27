/**
* ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
* Class Name      : CustomApprovalProcessController
* Author          : <YourName>
* Created Date    : Mar 2, 2026
* Last Modified By: <YourName>
* Last Modified On: Mar 2, 2026
* Description     : This class implements for......
*  
* Change History  :
*  Date          │   Author     │   Change
* ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
*  Mar 2, 2026  │ <YourName>   │ Initial version
* ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
*/

public class CustomApprovalProcessController {
    
    public class CountWrapper {
        @AuraEnabled public Integer approvedFeedbackCount;
        @AuraEnabled public Integer pendingLineItemCount;
        
        public CountWrapper() {
            approvedFeedbackCount = 0;
            pendingLineItemCount = 0;
        }
    }
    
    public class FileWrapper {
        @AuraEnabled public List<ContentDocumentLink> files;
        @AuraEnabled public Boolean isFileUploadMandatory;
        
        public FileWrapper() {
            files = new List<ContentDocumentLink>();
            isFileUploadMandatory = false;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Integer getApprovedQuantityForProduct(Id lineItemId) {
        Sample_Request_Line_Item__c lineItem = [SELECT Product_Group__c, Sample_Request_Header__r.Customer__c,Sample_Request_Header__r.Contact__c FROM Sample_Request_Line_Item__c WHERE Id = :lineItemId LIMIT 1];
        
        List<AggregateResult> agg = [SELECT COUNT(Id) resultCount FROM Sample_Request_Line_Item__c WHERE Product_Group__c = :lineItem.Product_Group__c AND Sample_Request_Header__r.Customer__c =:lineItem.Sample_Request_Header__r.Customer__c AND Sample_Request_Header__r.Contact__c = :lineItem.Sample_Request_Header__r.Contact__c AND Approval_Status__c = 'Approved'];
        return Integer.valueOf(agg[0].get('resultCount'));
    }
    @AuraEnabled(cacheable=true)
    public static List<Approver_Comment__c> getExistingComments(Id lineItemId) {
        
        Sample_Request_Line_Item__c lineItem = [SELECT Product_Group__c, Sample_Request_Header__c, Sample_Request_Header__r.Opportunity__r.Account__c,Sample_Request_Header__r.Opportunity__r.Contact__c FROM Sample_Request_Line_Item__c WHERE Id = :lineItemId LIMIT 1];
        
        Id productId = lineItem.Product_Group__c;
        Id accountId = lineItem.Sample_Request_Header__r.Opportunity__r.Account__c;
        Id contactId = lineItem.Sample_Request_Header__r.Opportunity__r.Contact__c;
       
        List<Sample_Request_Line_Item__c> allRelatedItems = [SELECT Id, Sample_Request_Header__c FROM Sample_Request_Line_Item__c WHERE Product_Group__c = :productId AND Sample_Request_Header__r.Customer__c =:accountId AND  Sample_Request_Header__r.Contact__c = :contactId];
        
        Map<Id, Id> headerToLineItemMap = new Map<Id, Id>();
        for(Sample_Request_Line_Item__c item : allRelatedItems) {
            if(!headerToLineItemMap.containsKey(item.Sample_Request_Header__c)) {
                headerToLineItemMap.put(item.Sample_Request_Header__c, item.Id);
            }
        }
        Set<Id> oneLineItemPerHeader = new Set<Id>(headerToLineItemMap.values());
        
        return [SELECT Id, GSM_Comments__c, RSM_Comments__c, NSM_Comments__c, CreatedDate, Approval_Status__c, Role__c, Approver_Name__c, Approver_Name__r.Name, Sample_Request_Line_Item__r.Product_Quantity__c, 
                Approval_Date__c FROM Approver_Comment__c WHERE Sample_Request_Line_Item__c IN :oneLineItemPerHeader ORDER BY CreatedDate DESC];
    }
    
    @AuraEnabled
    public static void updateApproverComment(Id lineItemId, String comment, String status) {
        
        Id currentUserId = UserInfo.getUserId();
        List<sObject> recordToUpdate = new List<sObject>();
        List<Approver_Comment__c> existingComments = [SELECT Id, GSM_Comments__c, Approval_Status__c, Approver_Name__c,Role__c FROM Approver_Comment__c WHERE Sample_Request_Line_Item__r.Sample_Request_Header__c = :lineItemId
                                                      AND Approver_Name__c = :currentUserId AND Approval_Status__c = 'Pending'];
        System.debug('existingComments : ' + existingComments);
        if (!existingComments.isEmpty()) {
            for(Approver_Comment__c existingComment : existingComments){
                recordToUpdate.add(new Approver_Comment__c(Id = existingComment.Id, GSM_Comments__c = comment, Approval_Status__c = status, Approval_Date__c = System.today()));
            }
            
            update recordToUpdate;
             if (status == 'Rejected') {
            SampleRequestApprovalProcess.restoreLimitOnReject([SELECT Id, Approval_Status__c, Product_M__c, Is_Backup__c, Sample_Request_Header__c,Sample_Request_Header__r.Name, Sample_Request_Header__r.Opportunity__r.Account__c,CreatedById FROM Sample_Request_Line_Item__c WHERE Sample_Request_Header__c =: lineItemId],existingComments.get(0).Role__c);
        }
        } else {
            throw new AuraHandledException('No matching approver record found for current user.');
        }
       
    }

    /**
    * Updates all pending approver comments of the current user for the header in a single call,
    * using the comment entered for each line item (rows without an entry, e.g. backup items,
    * get the first comment). Replaces the per line item parallel calls that raced each other.
    */
    @AuraEnabled
    public static void updateApproverComments(Id headerId, Map<String, String> commentsByLineItem, String status) {

        Id currentUserId = UserInfo.getUserId();
        List<Approver_Comment__c> existingComments = [SELECT Id, Sample_Request_Line_Item__c, Role__c FROM Approver_Comment__c WHERE Sample_Request_Line_Item__r.Sample_Request_Header__c = :headerId
                                                      AND Approver_Name__c = :currentUserId AND Approval_Status__c = 'Pending'];
        if (existingComments.isEmpty()) {
            throw new AuraHandledException('No matching approver record found for current user.');
        }

        Map<Id, String> commentByLineItem = new Map<Id, String>();
        String fallbackComment;
        if (commentsByLineItem != null) {
            for (String lineItemKey : commentsByLineItem.keySet()) {
                commentByLineItem.put(Id.valueOf(lineItemKey), commentsByLineItem.get(lineItemKey));
                if (fallbackComment == null) {
                    fallbackComment = commentsByLineItem.get(lineItemKey);
                }
            }
        }

        List<Approver_Comment__c> recordToUpdate = new List<Approver_Comment__c>();
        for (Approver_Comment__c existingComment : existingComments) {
            String lineComment = commentByLineItem.containsKey(existingComment.Sample_Request_Line_Item__c) ? commentByLineItem.get(existingComment.Sample_Request_Line_Item__c) : fallbackComment;
            recordToUpdate.add(new Approver_Comment__c(Id = existingComment.Id, GSM_Comments__c = lineComment, Approval_Status__c = status, Approval_Date__c = System.today()));
        }
        update recordToUpdate;

        if (status == 'Rejected') {
            SampleRequestApprovalProcess.restoreLimitOnReject([SELECT Id, Approval_Status__c, Product_M__c, Is_Backup__c, Sample_Request_Header__c,Sample_Request_Header__r.Name, Sample_Request_Header__r.Opportunity__r.Account__c,CreatedById FROM Sample_Request_Line_Item__c WHERE Sample_Request_Header__c =: headerId], existingComments.get(0).Role__c);
        }
    }

   /* @AuraEnabled(cacheable=true)
    public static List<ContentDocumentLink> getFiles(Id recordId) {
        return [ SELECT ContentDocumentId, ContentDocument.Title FROM ContentDocumentLink WHERE LinkedEntityId = :recordId];
    }*/
    
    @AuraEnabled(cacheable=true)
    public static FileWrapper getFiles(Id recordId) {
        FileWrapper wrapper = new FileWrapper();
        
        wrapper.files = [SELECT ContentDocumentId, ContentDocument.Title FROM ContentDocumentLink WHERE LinkedEntityId = :recordId];
        
        Sample_Request_Header__c header = [SELECT File_Upload_Mandatory__c FROM Sample_Request_Header__c WHERE Id = :recordId LIMIT 1];
        wrapper.isFileUploadMandatory = header.File_Upload_Mandatory__c;
        
        return wrapper;
    }
    
    @AuraEnabled(cacheable=true)
    public static String isUserApprover(Id lineItemId) {
        Id currentUserId = UserInfo.getUserId();
        
        List<Approver_Comment__c> records = [SELECT Id,Role__c FROM Approver_Comment__c WHERE Sample_Request_Line_Item__c = :lineItemId AND Approver_Name__c = :currentUserId AND Approval_Status__c = 'Pending' LIMIT 1];
        
        return records.isEmpty() ? null : records[0].Role__c;
    }
    
   /* @AuraEnabled(cacheable=true)
    public static Integer getApprovedFeedbackCount() {
        
        List<AggregateResult> agg = [select COUNT(Id) resultCount from Sample_Request_Line_Item__c where id not in (select Sample_Request_Line_Item__c from Sample_Request_Feedback__c where Approval_Status__c = 'Approved' ) and CreatedById = :UserInfo.getUserId() and Executed_On__c < LAST_N_DAYS:35];
        Integer value = Integer.valueOf(agg[0].get('resultCount'));
        return value;
    }
    
    @AuraEnabled(cacheable=true)
    public static Integer getPendingLineItemCountByAccount(Id accountId) {
        List<AggregateResult> agg = [SELECT COUNT(Id) resultCount FROM Sample_Request_Line_Item__c WHERE Id NOT IN (SELECT Sample_Request_Line_Item__c FROM Sample_Request_Feedback__c WHERE Approval_Status__c = 'Approved') AND CreatedById = :UserInfo.getUserId()
                                     AND Sample_Request_Header__r.Opportunity__r.Account__c = :accountId AND SAP_Status__c != 'Returned' AND Executed_On__c < LAST_N_DAYS:35];
        Integer value = Integer.valueOf(agg[0].get('resultCount'));
        return value;
    }*/
    
    
    @AuraEnabled(cacheable=true)
    public static CountWrapper getCounts(Id contactId,Id createdById) {
        CountWrapper result = new CountWrapper();
        try {
            //Id currentUserId = UserInfo.getUserId();
            List<AggregateResult> approvedAgg = [SELECT COUNT(Id) total FROM Sample_Request_Line_Item__c WHERE Feedback_Upload_Status__c != 'Approved' AND CreatedById = :createdById AND SAP_Status__c IN ('Executed', 'Delivered') AND Executed_On__c < LAST_N_DAYS:35];
            
            if (!approvedAgg.isEmpty()) {
                result.approvedFeedbackCount = (Integer) approvedAgg[0].get('total');
            }
            if (contactId != null) {
                List<AggregateResult> pendingAgg = [SELECT COUNT(Id) total FROM Sample_Request_Line_Item__c WHERE Feedback_Upload_Status__c != 'Approved' AND  Sample_Request_Header__r.Contact__c = :contactId AND SAP_Status__c IN ('Executed', 'Delivered') AND Executed_On__c < LAST_N_DAYS:35];
                if (!pendingAgg.isEmpty()) {
                    result.pendingLineItemCount = (Integer) pendingAgg[0].get('total');
                }
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching counts: ' + e.getMessage());
        }
        return result;
    }
    
    // ── Custom labels ──────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static SampleTranslation2__c getCustomLabels() {
        String language = UserInfo.getLanguage();
        return SampleTranslation2__c.getValues(language);
    }

    
    @AuraEnabled
    public static void callApprovalProcess(List<Id> lineItemIds, Id recordId){
        
        List<Sample_Request_Line_Item__c> lineItems = [SELECT Id,CreatedById,Sample_Request_Header__r.Customer__c,Sample_Request_Header__r.Contact__c, Approval_Status__c, Product_M__c,Product_Group__c,Product_M__r.Product_Group__r.Vertical__c,CreatedDate, Is_Backup__c, Sample_Request_Header__c, Sample_Request_Header__r.Opportunity__r.Account__c,Sample_Request_Header__r.Opportunity__r.Contact__c FROM Sample_Request_Line_Item__c WHERE Sample_Request_Header__c =: recordId];
        
        if(lineItems.isEmpty()) return;
        Id headerId = lineItems[0].Sample_Request_Header__c;
        
        Id currentUserId = UserInfo.getUserId();
        List<Approver_Comment__c> comments = [ SELECT Role__c FROM Approver_Comment__c WHERE Sample_Request_Line_Item__c IN :lineItemIds AND Approver_Name__c = :currentUserId ORDER BY CreatedDate DESC];
        
        if(comments.isEmpty()){
            throw new AuraHandledException('No role found for current user');
        }
        String role = comments[0].Role__c;        
        SampleRequestApprovalProcess.createApprovalRecord(lineItems, headerId, role, false);
    }
    
    
    @AuraEnabled
    public static Boolean isCountryAdmin(Id headerId) {
        Id currentUserId = UserInfo.getUserId();
        List<ContentDocumentLink> contentDocumentLinkRecord = new List<ContentDocumentLink>();
        Boolean isFileNotAttached = false;
        
        List<Approver_Comment__c> records = new List<Approver_Comment__c>([SELECT Id,Role__c FROM Approver_Comment__c WHERE Sample_Request_Line_Item__r.Sample_Request_Header__c = :headerId AND Approver_Name__c = :currentUserId AND Approval_Status__c = 'Pending' AND Role__c = 'CMD' LIMIT 1]);  
        
        List<Approval_Chain__c> approvalChainRecords = [SELECT Id FROM Approval_Chain__c WHERE Sample_Request_Header__c = :headerId AND Role__c = 'CMD' LIMIT 1];
        
        if(!approvalChainRecords.isEmpty()){
            contentDocumentLinkRecord = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :approvalChainRecords[0].Id LIMIT 1];     
            System.debug('contentDocumentLinkRecord '+contentDocumentLinkRecord);
        }
        
        
        isFileNotAttached = !approvalChainRecords.isEmpty() && contentDocumentLinkRecord.IsEmpty();
        
        System.debug('isFileAttached >> '+isFileNotAttached);
        System.debug('records.isEmpty() >> '+records);
        
        return !records.isEmpty() && isFileNotAttached;
    }
    
   /* @AuraEnabled
    public static void handleFileUploadForAdmin(Id headerId, String base64, String filename) {
        
        List<Approval_Chain__c> approvalChainRecords = [SELECT Id FROM Approval_Chain__c WHERE Sample_Request_Header__c = :headerId AND Role__c = 'CMD' LIMIT 1];
        
        if (approvalChainRecords.isEmpty()) {
            throw new AuraHandledException('No CMD approval chain record found.');
        }
        
        ContentVersion cv = new ContentVersion();
        cv.Title = filename;
        cv.PathOnClient = '/' + filename;
        cv.VersionData = EncodingUtil.base64Decode(base64);
        cv.FirstPublishLocationId = headerId;
        cv.IsMajorVersion = true;
        insert cv;
        
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = cv.ContentDocumentId;
        cdl.LinkedEntityId = approvalChainRecords[0].Id;
        cdl.ShareType = 'V'; // Viewer access
        cdl.Visibility = 'AllUsers';
        
        insert cdl;
    }*/
    
    @AuraEnabled
    public static String uploadChunkForAdmin(Id headerId,String base64Chunk,String fileName,String fileId) {
        List<Approval_Chain__c> approvalChainRecords = [SELECT Id FROM Approval_Chain__c WHERE Sample_Request_Header__c = :headerId AND Role__c = 'CMD' LIMIT 1];
        
        if (approvalChainRecords.isEmpty()) {
            throw new AuraHandledException('No CMD approval chain record found.');
        }
        
        Id approvalChainId = approvalChainRecords[0].Id;
        
        if (String.isBlank(fileId)) {
            
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = '/' + fileName;
            while(Math.mod(base64Chunk.length(), 4) != 0) {
    base64Chunk += '=';
}
            cv.VersionData = EncodingUtil.base64Decode(base64Chunk);
            cv.FirstPublishLocationId = headerId;
            insert cv;
            
            cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
            
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = cv.ContentDocumentId;
            cdl.LinkedEntityId = approvalChainId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;
            
            return cv.Id;
        } 
        else {
            ContentVersion existing = [SELECT Id, VersionData FROM ContentVersion WHERE Id = :fileId LIMIT 1];
            
            String existingBase64 = EncodingUtil.base64Encode(existing.VersionData);
            
            existingBase64 += base64Chunk;
            
            existing.VersionData = EncodingUtil.base64Decode(existingBase64);
            
            // update existing;
            
            return existing.Id;
        }
    }
    
    
  /*  @AuraEnabled(cacheable=true)
    public static List<ContentDocumentLink> handleCmdFile(Id headerId) {
        
        List<ContentDocumentLink> contentDocumentListRecord = new List<ContentDocumentLink>();
        
        List<Approval_Chain__c> approvalChainRecords = [
            SELECT Id 
            FROM Approval_Chain__c 
            WHERE Sample_Request_Header__c = :headerId 
            AND Role__c = 'CMD'
            LIMIT 1
        ];        
        
        if (approvalChainRecords.isEmpty()) {
            return contentDocumentListRecord;
        }
        
        contentDocumentListRecord = [
            SELECT ContentDocumentId, ContentDocument.Title 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :approvalChainRecords[0].Id ORDER By SystemModstamp DESC
            LIMIT 1
        ];
        
        return contentDocumentListRecord;
    }
    
    @AuraEnabled
    public static List<ContentDocumentLink> handleCmdFileForAdmin(Id headerId) {
        
        List<ContentDocumentLink> contentDocumentListRecord = new List<ContentDocumentLink>();
        
        List<Approval_Chain__c> approvalChainRecords = [
            SELECT Id 
            FROM Approval_Chain__c 
            WHERE Sample_Request_Header__c = :headerId 
            AND Role__c = 'CMD'
            LIMIT 1
        ];        
        
        if (approvalChainRecords.isEmpty()) {
            return contentDocumentListRecord;
        }
        
        contentDocumentListRecord = [
            SELECT ContentDocumentId, ContentDocument.Title 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :approvalChainRecords[0].Id ORDER By SystemModstamp DESC
            LIMIT 1
        ];
        
        return contentDocumentListRecord;
    } */
    
    @AuraEnabled(cacheable=true)
    public static List<ContentDocumentLink> getCmdFile(Id headerId) {
        
        List<Approval_Chain__c> approvalChainRecords = [SELECT Id FROM Approval_Chain__c WHERE Sample_Request_Header__c = :headerId AND Role__c = 'CMD' LIMIT 1];        
        
        if (approvalChainRecords.isEmpty()) {
            return new List<ContentDocumentLink>();
        }
        
        return [SELECT ContentDocumentId, ContentDocument.Title FROM ContentDocumentLink WHERE LinkedEntityId = :approvalChainRecords[0].Id ORDER BY SystemModstamp DESC LIMIT 1];
    }
    
    @AuraEnabled
    public static void deleteCmdFile(Id contentDocumentId) {
        ContentDocument doc = [SELECT Id FROM ContentDocument WHERE Id = :contentDocumentId LIMIT 1];
        delete doc;
    }

    
}
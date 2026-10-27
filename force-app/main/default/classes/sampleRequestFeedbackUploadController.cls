/**
* ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
* Class Name      : sampleRequestFeedbackUploadController
* Author          : <YourName>
* Created Date    : Mar 16, 2026
* Last Modified By: <YourName>
* Last Modified On: Mar 16, 2026
* Description     : This class implements for......
*  
* Change History  :
*  Date          │   Author     │   Change
* ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
*  Mar 16, 2026  │ <YourName>   │ Initial version
* ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
*/

public without sharing class sampleRequestFeedbackUploadController {

    @AuraEnabled(cacheable=true)
    public static List<Sample_Request_Line_Item__c> getLineItem(Id recordId){
        return [SELECT Id,Name,Brand__c,Group_Name__c,Diaptor__c,Batch_Number__c,Serial_Number__c  FROM Sample_Request_Line_Item__c WHERE Sample_Request_Header__c =: recordId AND (SAP_Status__c = 'Executed' OR SAP_Status__c = 'Delivered')];
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isSampleRequestOwner(Id recordId){
        Sample_Request_Header__c header = [SELECT Id, OwnerId FROM Sample_Request_Header__c WHERE Id =: recordId];
        return header.OwnerId == UserInfo.getUserId();
    }
    
    @AuraEnabled
    public static void uploadFile(String uplodedFile,Id recordId) {
        
        
        List<FileUploadWrapper> fileToUpload = (List<FileUploadWrapper>) JSON.deserialize(uplodedFile , List<FileUploadWrapper>.class);
        System.debug('recordId : '+recordId);
        Sample_Request_Feedback__c feedBack = new Sample_Request_Feedback__c(
            Sample_Request_Line_Item__c = recordId,
            Approval_Status__c = 'Pending'
        );
        insert feedBack;
        List<ContentDocumentLink> cvList = new List<ContentDocumentLink>();
        for(FileUploadWrapper fileObj : fileToUpload){
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = fileObj.documentId; 
            cdl.LinkedEntityId = feedBack.Id;    
            cdl.ShareType = 'V'; 
            cvList.add(cdl);
        }
        insert cvList;
        Sample_Request_Line_Item__c lineItem = new Sample_Request_Line_Item__c(
        Id = recordId,
        Feedback_Upload_Status__c = 'Approval Pending'
        );
        update lineItem;
        submitForApproval(feedBack.Id,recordId);
    }
    
    @AuraEnabled
    public static void deleteContentDocument(Id documentId) {
        List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE Id = :documentId];
        if (!docs.isEmpty()) {
            delete docs;
        }
    }

    @AuraEnabled
    public static void submitForApproval(Id recordId,Id sampleRequestLineItemId) {
        Approval_Chain__c approvalChainRecord = [SELECT Id,Approver__c FROM Approval_Chain__c WHERE Sample_Request_Header__c IN (SELECT Sample_Request_Header__c FROM Sample_Request_Line_Item__c WHERE Id =: sampleRequestLineItemId) AND Status__c = 'APPROVED' ORDER BY Level__c ASC LIMIT 1];
        Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
        req.setObjectId(recordId);
        req.setProcessDefinitionNameOrId('Feedback_Approval');
        req.setComments('Submitted for approval via LWC');
        //req.setNextApproverIds(new List<Id>{ '0056F00000BgrcNQAR' });
         req.setNextApproverIds(new List<Id>{ approvalChainRecord.Approver__c });        
        Approval.ProcessResult result = Approval.process(req);
        
        if (!result.isSuccess()) {
            throw new AuraHandledException('Approval submission failed: ' + result.getErrors());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Sample_Request_Feedback__c> getDataTable(String recordId){
        return [SELECT Id,Name,Approval_Status__c,Comments__c FROM Sample_Request_Feedback__c WHERE Sample_Request_Line_Item__c =: recordId];
    }

    @AuraEnabled(cacheable=true)
    public static SampleTranslation2__c getCustomLabels() {
        String language = UserInfo.getLanguage();
        return SampleTranslation2__c.getValues(language);
    }

    @AuraEnabled(cacheable=true)
public static Map<String, String> getLatestFeedbackStatus(Id recordId) {
    Map<String, String> statusMap = new Map<String, String>();
    
    // query the latest feedback record per line item
    for (Sample_Request_Feedback__c feedback : [
        SELECT Id, Sample_Request_Line_Item__c, Approval_Status__c
        FROM Sample_Request_Feedback__c
        WHERE Sample_Request_Line_Item__r.Sample_Request_Header__c = :recordId
        ORDER BY CreatedDate DESC
    ]) {
        // only store the first (latest) one per line item
        if (!statusMap.containsKey(feedback.Sample_Request_Line_Item__c)) {
            statusMap.put(feedback.Sample_Request_Line_Item__c, feedback.Approval_Status__c);
        }
    }
    
    return statusMap;
}
    
    public class FileUploadWrapper{
        public String documentName;
        public String contentVersionId;
        public String documentId;
        
    }
}
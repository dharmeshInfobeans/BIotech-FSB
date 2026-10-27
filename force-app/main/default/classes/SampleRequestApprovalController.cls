public with sharing class SampleRequestApprovalController {
    
    @AuraEnabled(cacheable=true)
    public static List<ApprovalWrapper> getPendingApprovals(Id headerId) {
        
        List<ApprovalWrapper> result = new List<ApprovalWrapper>();
        Map<Id, Sample_Request_Line_Item__c> lineItemMap = new Map<Id, Sample_Request_Line_Item__c>([SELECT Id, Name, Brand__c, Diaptor__c, Group_Name__c FROM Sample_Request_Line_Item__c WHERE Sample_Request_Header__c =: headerId]);
        
        if (lineItemMap.isEmpty()) {
            return result;
        }
        
        Map<Id, Sample_Request_Feedback__c> feedbackMap = new Map<Id, Sample_Request_Feedback__c>([SELECT Id, Sample_Request_Line_Item__c, Comments__c FROM Sample_Request_Feedback__c WHERE Sample_Request_Line_Item__c IN :lineItemMap.keySet()]);
        
        if (feedbackMap.isEmpty()) {
            return result;
        }
        Map<Id, Id> feedbackToFileMap = new Map<Id, Id>();
        
        for (ContentDocumentLink cdl : [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :feedbackMap.keySet()]) {
            if (!feedbackToFileMap.containsKey(cdl.LinkedEntityId)) {
                feedbackToFileMap.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
            }
        }
        
        Map<Id, ProcessInstanceWorkitem> workItemMap = new Map<Id, ProcessInstanceWorkitem>();
        for (ProcessInstanceWorkitem wi : [SELECT Id, ActorId, ProcessInstance.TargetObjectId FROM ProcessInstanceWorkitem WHERE ProcessInstance.Status = 'Pending' AND ProcessInstance.TargetObjectId IN :feedbackMap.keySet() AND ActorId =: UserInfo.getUserId()]) {
            workItemMap.put(wi.ProcessInstance.TargetObjectId, wi);
        }
        Integer count = 1;
        
        for (Sample_Request_Feedback__c feedback : feedbackMap.values()) {
            ProcessInstanceWorkitem wi = workItemMap.get(feedback.Id);
            if (wi != null) {
                Sample_Request_Line_Item__c lineItem = lineItemMap.get(feedback.Sample_Request_Line_Item__c);
                if (lineItem != null) {
                    ApprovalWrapper wrap = new ApprovalWrapper();
                    wrap.serialNo = count++;
                    wrap.workItemId = wi.Id;
                    wrap.lineItemName = lineItem.Name;
                    wrap.brand = lineItem.Brand__c;
                    wrap.diaptor = lineItem.Diaptor__c;
                    wrap.model = lineItem.Group_Name__c;
                    wrap.lineItemId = lineItem.Id;
                    wrap.feedbackId = feedback.Id;
                    wrap.fileId = feedbackToFileMap.get(feedback.Id);
                    
                    result.add(wrap);
                }
            }
        }
        
        return result;
    }
    
    @AuraEnabled
    public static void processApproval(Id workItemId, String action, String comments) {
        
        Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
        req.setWorkitemId(workItemId);
        req.setAction(action);
        req.setComments(comments);
        Approval.process(req);
    }
    @AuraEnabled
    public static void updateFeedbackComment(Id feedbackId, String comment) {
        if (feedbackId == null) return;
        Sample_Request_Feedback__c feedback = new Sample_Request_Feedback__c(Id = feedbackId, Comments__c = comment);
        update feedback;
    }

    @AuraEnabled(cacheable=true)
    public static SampleTranslation2__c getCustomLabels() {
        String language = UserInfo.getLanguage();
        return SampleTranslation2__c.getValues(language);
    }

    public class ApprovalWrapper {
        @AuraEnabled public Integer serialNo;
        @AuraEnabled public Id workItemId;
        @AuraEnabled public String lineItemName;
        @AuraEnabled public String brand;
        @AuraEnabled public String diaptor;
        @AuraEnabled public String model;
        @AuraEnabled public Id feedbackId;
        @AuraEnabled public Id lineItemId;
        @AuraEnabled public Id fileId;
    }
}
public class SampleRequestLineItemTriggerHandler {
    
    public static void updateSampleHeaderStatus(List<Sample_Request_Line_Item__c> sampleLineItemList){
        Set<Id> headerIds = new Set<Id>();
        for(Sample_Request_Line_Item__c item : sampleLineItemList){
            if(item.Sample_Request_Header__c != null){
                headerIds.add(item.Sample_Request_Header__c);
            }
        }
        List<Sample_Request_Line_Item__c> sampleRequestLineItem = [SELECT Id,SAP_status__c,Sample_Request_Header__c,Sample_Request_Header__r.SAP_Status__c FROM  Sample_Request_Line_Item__c WHERE Sample_Request_Header__c IN: headerIds AND Is_BackUp__c != True];
        
        Map<Id,Set<String>> mapOfHeaderStatus = new Map<Id,Set<String>>();
        Map<Id,String> mapOfHeaderCurrentStatus = new Map<Id,String>();
        for(Sample_Request_Line_Item__c item : sampleRequestLineItem){
            if(!mapOfHeaderStatus.containsKey(item.Sample_Request_Header__c)) mapOfHeaderStatus.put(item.Sample_Request_Header__c,new Set<String>());
            mapOfHeaderStatus.get(item.Sample_Request_Header__c).add(item.SAP_status__c);
            mapOfHeaderCurrentStatus.put(item.Sample_Request_Header__c, item.Sample_Request_Header__r.SAP_Status__c);
        }
        List<Sample_Request_Header__c> recordToUpdate = new List<Sample_Request_Header__c>();
        for(Id headerId : mapOfHeaderStatus.keySet()){
            if(mapOfHeaderStatus.get(headerId).size() > 1){
                List<String> status = new List<String>(mapOfHeaderStatus.get(headerId));
                if(status.contains('Ordered')){
                    if(mapOfHeaderCurrentStatus.get(headerId) != 'Partially Executed'){
                        recordToUpdate.add(new Sample_Request_Header__c(
                            Id = headerId,
                            SAP_Status__c = 'Partially Executed'));
                    }
                }
                else if(status.contains('Executed')){
                    if(mapOfHeaderCurrentStatus.get(headerId) != 'Executed'){
                        recordToUpdate.add(new Sample_Request_Header__c(
                            Id = headerId,
                            SAP_Status__c = 'Executed'));
                    }
                }
                else if(status.contains('Delivered')){
                    if(mapOfHeaderCurrentStatus.get(headerId) != 'Delivered'){
                        recordToUpdate.add(new Sample_Request_Header__c(
                            Id = headerId,
                            SAP_Status__c = 'Delivered'));
                    }
                }
            }
            else{
                String singleStatus = new List<String>(mapOfHeaderStatus.get(headerId))[0];
                if(singleStatus != 'Returned'){
                    if(mapOfHeaderCurrentStatus.get(headerId) != singleStatus){
                        recordToUpdate.add(new Sample_Request_Header__c(
                            Id = headerId,
                            SAP_Status__c = singleStatus));
                    }
                }
            }
        }
        if(!recordToUpdate.isEmpty()){ 
            update recordToUpdate;

            // FIX: re-query full header fields (CreatedById, Name, etc.) needed for
            // email/notification. The 'recordToUpdate' sObjects above only have
            // Id + SAP_Status__c populated, so passing them directly caused
            // CreatedById to be null -> REQUIRED_FIELD_MISSING on sendEmail.
            Set<Id> updatedHeaderIds = new Set<Id>();
            for (Sample_Request_Header__c h : recordToUpdate) {
                updatedHeaderIds.add(h.Id);
            }

            List<Sample_Request_Header__c> fullHeaders = [
                SELECT Id, Name, CreatedById, SAP_Status__c
                FROM Sample_Request_Header__c
                WHERE Id IN :updatedHeaderIds
            ];

            SampleRequestLineItemTriggerHandler.sendMailAndNotificationOnStageChange(fullHeaders);
        }
    }
    
    
    public static void sendMailAndNotificationOnStageChange(List<Sample_Request_Header__c> headerList){
        EmailTemplate template = [SELECT Id, HtmlValue, Subject FROM EmailTemplate WHERE DeveloperName = 'Sample_Request_Stage_Change_Email' LIMIT 1];
        CustomNotificationType notificationType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Sample_Header_Notification' LIMIT 1];
        OrgWideEmailAddress[] owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'crmhelpdesk@biotechhealthcare.com' LIMIT 1];
        
        List<Messaging.SingleEmailMessage> mailToSend = new List<Messaging.SingleEmailMessage>();
        List<Messaging.CustomNotification> notificationsToSend = new List<Messaging.CustomNotification>();
        
        for(Sample_Request_Header__c header : headerList){

            // FIX: guard against missing CreatedById so one bad record doesn't
            // throw REQUIRED_FIELD_MISSING and roll back the entire trigger/DML.
            if (header.CreatedById == null) {
                System.debug('Skipping email/notification — CreatedById is null for header: ' + header.Id);
                continue;
            }

            Messaging.SingleEmailMessage renderedMail = Messaging.renderStoredEmailTemplate(template.Id, header.CreatedById, header.Id);
            //Messaging.SingleEmailMessage renderedMail = Messaging.renderStoredEmailTemplate(template.Id, '0056F00000BgrE5QAJ', header.Id);
            String htmlBody = renderedMail.getHtmlBody();
            
            String feedbackReminder = '';
            if(header.SAP_Status__c == 'Partially Executed' || header.SAP_Status__c == 'Executed') {
                feedbackReminder = '<div style="background-color:#fff8e1; border-left:4px solid #f0a500; padding:12px 15px; border-radius:3px; margin-bottom:10px;">'
                    + '<strong style="color:#f0a500;">&#9888; Feedback Reminder</strong><br/>'
                    + 'Please ensure that you submit your feedback for this sample request before the due date. '
                    + 'Timely feedback helps us serve you better and is required for further processing. '
                    + 'Please log in and submit your feedback at the earliest.'
                    + '</div><br/>';
            }
            
            htmlBody = htmlBody.replace('##FEEDBACK_REMINDER##', feedbackReminder);
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(header.CreatedById);
            //mail.setTargetObjectId('0056F00000BgrE5QAJ');
            if (!owea.isEmpty()) mail.setOrgWideEmailAddressId(owea[0].Id);
            mail.setSubject(renderedMail.getSubject());
            mail.setHtmlBody(htmlBody);
            mail.setSaveAsActivity(false);
            //mail.setToAddresses(new String[] { 'dhruv@creatiquetech.com' });
            mailToSend.add(mail);
            
            // Notification
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setNotificationTypeId(notificationType.Id);
            notification.setTargetId(header.Id);
            notification.setTitle('Sample Request ' + header.Name + ' - Status Update');
            notification.setBody('Your Sample Request status has been updated to: ' + header.SAP_Status__c);
            notification.send(new Set<String>{header.CreatedById});
        }
        if(!mailToSend.isEmpty()) Messaging.sendEmail( mailToSend );
    }
    /*
public static void createApprovalProcess(List<Sample_Request_Line_Item__c> newList) {
List<Approval.ProcessSubmitRequest> approvalRequestList = new List<Approval.ProcessSubmitRequest>();

for (Sample_Request_Line_Item__c samReq : newList) {
if (samReq.Product_Quantity__c > 0) {
System.debug('Check Quantity');

Id approverId = null;

if (samReq.RSM__c != null) {
approverId = samReq.RSM__c;
System.debug('RSM Approver found: ' + approverId);
} else if (samReq.NSM__c != null) {
approverId = samReq.NSM__c;
System.debug('NSM Approver found: ' + approverId);
} else {
System.debug('No approver found');
}

if (approverId != null) {
Approval.ProcessSubmitRequest approvalRequest = new Approval.ProcessSubmitRequest();
approvalRequest.setObjectId(samReq.Id);  
approvalRequest.setNextApproverIds(new List<Id>{approverId});  
approvalRequest.setComments('Submitting for approval'); 

approvalRequestList.add(approvalRequest);
System.debug('Creating approval request for ' + samReq.Id);
}
} else {
System.debug('Product quantity is 0 or less for ' + samReq.Id);
}
}

if (!approvalRequestList.isEmpty()) {
Approval.process(approvalRequestList);  
} else {
System.debug('No approval requests to submit.');
}
}

public static void createApprovalProcess2(List<Sample_Request_Line_Item__c> newList) {
Map<String,Approval_Config__mdt> approvalConfigMap = new Map<String,Approval_Config__mdt>();
Map<String,List<Approval_Rule__mdt>> countryWiseApprovalMap = new Map<String,List<Approval_Rule__mdt>>();
Map<String,String> approvalRolesApiMap = new Map<String,String>();

for(Approval_Config__mdt approvalConfRec : [SELECT Id,Country_Code__c,Is_Active__c FROM Approval_Config__mdt]){
approvalConfigMap.put(approvalConfRec.Country_Code__c,approvalConfRec);
}

for(Approval_Rule__mdt cntApprvRec : [SELECT Id,Approval_Chain__c,Approval_Config__c,Quantity_Min__c,Quantity_Max__c FROM Approval_Rule__mdt]){
if(!countryWiseApprovalMap.containsKey(cntApprvRec.Approval_Config__c)){
countryWiseApprovalMap.put(cntApprvRec.Approval_Config__c,new List<Approval_Rule__mdt>());
}

countryWiseApprovalMap.get(cntApprvRec.Approval_Config__c).add(cntApprvRec);
}


for(Approval_Label__mdt approvalLabel : [SELECT Id,Role_Code__c,Field_API_Name__c FROM Approval_Label__mdt]){
approvalRolesApiMap.put(approvalLabel.Role_Code__c,approvalLabel.Field_API_Name__c);
}

List<Approval.ProcessSubmitRequest> approvalRequestList = new List<Approval.ProcessSubmitRequest>();

for (Sample_Request_Line_Item__c samReq : newList) {
if (samReq.Product_Quantity__c > 0) {
System.debug('Check Quantity');

Id approverId = null;

if (samReq.RSM__c != null) {
approverId = samReq.RSM__c;
System.debug('RSM Approver found: ' + approverId);
} else if (samReq.NSM__c != null) {
approverId = samReq.NSM__c;
System.debug('NSM Approver found: ' + approverId);
} else {
System.debug('No approver found');
}

if (approverId != null) {
Approval.ProcessSubmitRequest approvalRequest = new Approval.ProcessSubmitRequest();
approvalRequest.setObjectId(samReq.Id);  
approvalRequest.setNextApproverIds(new List<Id>{approverId});  
approvalRequest.setComments('Submitting for approval'); 

approvalRequestList.add(approvalRequest);
System.debug('Creating approval request for ' + samReq.Id);
}
} else {
System.debug('Product quantity is 0 or less for ' + samReq.Id);
}
}

if (!approvalRequestList.isEmpty()) {
Approval.process(approvalRequestList);  
} else {
System.debug('No approval requests to submit.');
}
}*/
}
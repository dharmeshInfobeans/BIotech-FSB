trigger SampleRequestHeaderTrigger on Sample_Request_Header__c (after update,after insert) {
    
    if(Trigger.isAfter && Trigger.isInsert) {
       SampleRequestHeaderTriggerHandler.updateOppCheckbox(Trigger.new);
       SampleRequestHeaderTriggerHandler.handleVisibility(Trigger.new);
    }

    if(Trigger.isAfter && Trigger.isUpdate) {

        List<Sample_Request_Header__c> approvedRecords = new List<Sample_Request_Header__c>();
		List<Id> cancelledHeaderList = new List<Id>();
        List<Sample_Request_Header__c> headerStatusUpdateList = new List<Sample_Request_Header__c>();
        List<Id> sampleHeaderOrderNoMailIds = new List<Id>();
		
        for(Sample_Request_Header__c newRec : Trigger.new) {

            Sample_Request_Header__c oldRec = Trigger.oldMap.get(newRec.Id);

            if(newRec.Approval_Status__c == 'Approved' &&
               (oldRec == null || oldRec.Approval_Status__c != 'Approved')) {

                approvedRecords.add(newRec);
            }
            if(newRec.SAP_Status__c == 'Cancelled' ) {
                cancelledHeaderList.add(newRec.Id);
            }
            if(Trigger.oldMap.get(newRec.Id).SAP_Status__c != newRec.SAP_status__c){
                headerStatusUpdateList.add(newRec);
            }
            if(newRec.orderNumSAP__c != null && oldRec.orderNumSAP__c ==null){
                sampleHeaderOrderNoMailIds.add(newRec.Id);
            }
        }

        if(!approvedRecords.isEmpty()) {
            OrderSyncUpSap.processRecord(approvedRecords);
        }
        if(!cancelledHeaderList.isEmpty()) {
            SampleRequestHeaderTriggerHandler.handleCancel(cancelledHeaderList);
        }
         if(!headerStatusUpdateList.isEmpty()){
            SampleRequestLineItemTriggerHandler.sendMailAndNotificationOnStageChange(headerStatusUpdateList);
        }
        if(!sampleHeaderOrderNoMailIds.isEmpty()){
            SampleRequestHeaderTriggerHandler.sendBranchMail(sampleHeaderOrderNoMailIds);
        }
    }
}
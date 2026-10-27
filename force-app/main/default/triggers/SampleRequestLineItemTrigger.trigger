trigger SampleRequestLineItemTrigger on Sample_Request_Line_Item__c (after insert,before update,after update) {
   /* if(Trigger.isAfter && Trigger.isInsert){
        SampleRequestLineItemTriggerHandler.createApprovalProcess(Trigger.new);
        
    }*/
    if(Trigger.isAfter && Trigger.isUpdate){
        SampleRequestLineItemTriggerHandler.updateSampleHeaderStatus(Trigger.new);
        
    }
    if(Trigger.isBefore){
        if(Trigger.isUpdate)
        {
            for(Sample_Request_Line_Item__c lineItem : Trigger.new){
                if(lineItem.SAP_Status__c == 'Executed' && lineItem.Executed_On__c == NULL){
                    lineItem.Executed_On__c = Date.today();
                    lineItem.Feedback_Upload_Status__c = 'Pending';
                }
            }
        }
    }

}
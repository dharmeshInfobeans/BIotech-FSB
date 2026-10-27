trigger GenericDMLRequestTrigger on Generic_DML_Request__e (after insert) {

    if(trigger.isAfter && trigger.isInsert){
        GenericDMLRequestTriggerHandler.genericDML(trigger.new);
    }	

     /*List<sObject> toUpdate = new List<sObject>();
       List<Id> oppIdsToNotify = new List<Id>();
    for(Generic_DML_Request__e evt:trigger.new){
        if (String.isBlank(evt.Object_API_Name__c)) {
            System.debug('GenericDmlRequestTrigger: skipped event with no Object_API_Name__c');
            continue;
        }
         Schema.SObjectType targetType = Schema.getGlobalDescribe().get(evt.Object_API_Name__c);
         if (targetType == null) {
            System.debug('GenericDmlRequestTrigger: unknown object ' + evt.Object_API_Name__c);
            continue;
        }
        if (evt.Operation__c == 'Update') {
             if (String.isBlank(evt.Record_JSON__c)) {
                System.debug('GenericDmlRequestTrigger: Update requested with no Record_JSON__c');
                continue;
            }
            sObject record = (sObject) JSON.deserialize( evt.Record_JSON__c,Type.forName(evt.Object_API_Name__c));
            toUpdate.add(record);
           //sObject record = (sObject)JSON.deserialize( evt.Record_JSON__c, targetType.getDescribe().getSObjectType() );
             //toUpdate.add(record);
           if (evt.Object_API_Name__c == 'Opportunity__c') {
                Opportunity__c oppRecord = (Opportunity__c) record;
                if (oppRecord.RSM_Approve__c == true) {
                    oppIdsToNotify.add(oppRecord.Id);
                }
               else if (oppRecord.ZSM_Approve__c == true){
                      oppIdsToNotify.add(oppRecord.Id);
               }
              else if (oppRecord.Admin_Approve__c == true){
                      oppIdsToNotify.add(oppRecord.Id);
               }
            }
        }
    }
    if(!toUpdate.isEmpty()){
        update toUpdate;
    }
	 for (Id oppId : oppIdsToNotify) {
        Bio_uploadKYCDocument.sendEmailOnUpload(oppId);
    }*/
}
public class GenericDMLRequestTriggerHandler {

    public static void genericDML(List<Generic_DML_Request__e> listOfGenericDmlList){
        List<sObject> toUpdate = new List<sObject>();
        List<sObject> toDelete = new List<sObject>();
       	List<Id> oppIdsToNotify = new List<Id>();
        System.debug('listOfGenericDmlList'+listOfGenericDmlList);
        for(Generic_DML_Request__e evt:listOfGenericDmlList){
            if (String.isBlank(evt.Object_API_Name__c)) {
                System.debug('GenericDmlRequestTrigger: skipped event with no Object_API_Name__c');
                continue;
            }
             Schema.SObjectType targetType = Schema.getGlobalDescribe().get(evt.Object_API_Name__c);
             if (targetType == null) {
                System.debug('GenericDmlRequestTrigger: unknown object ' + evt.Object_API_Name__c);
                continue;
            }
            if(evt.Operation__c == 'Delete'){
                 if (String.isBlank(evt.Record_JSON__c)) {
                    System.debug('GenericDmlRequestTrigger: Update requested with no Record_JSON__c');
                    continue;
                }
                 sObject record = (sObject) JSON.deserialize( evt.Record_JSON__c,Type.forName(evt.Object_API_Name__c));
                toDelete.add(record);
            }
            if (evt.Operation__c == 'Update') {
                if (String.isBlank(evt.Record_JSON__c)) {
                    System.debug('GenericDmlRequestTrigger: Update requested with no Record_JSON__c');
                    continue;
                }
                sObject record = (sObject) JSON.deserialize( evt.Record_JSON__c,Type.forName(evt.Object_API_Name__c));
                toUpdate.add(record);
                /*  sObject record = (sObject)JSON.deserialize( evt.Record_JSON__c, targetType.getDescribe().getSObjectType() );
toUpdate.add(record); */
                if (evt.Object_API_Name__c == 'Opportunity__c') {
                    Opportunity__c oppRecord = (Opportunity__c) record;
                    if(oppRecord.Mis_Email__c != true){
                        System.debug('inside 1');
                        if (oppRecord.RSM_Approve__c == true) {
                              System.debug('inside 2');
                            oppIdsToNotify.add(oppRecord.Id);
                        }
                        else if (oppRecord.ZSM_Approve__c == true){
                              System.debug('inside 3');
                            oppIdsToNotify.add(oppRecord.Id);
                        }
                        else if (oppRecord.Admin_Approve__c == true){
                              System.debug('inside 4');
                            oppIdsToNotify.add(oppRecord.Id);
                        }
                        else if (oppRecord.Admin_Not_Approve__c == false){
                              System.debug('inside 5');
                            oppIdsToNotify.add(oppRecord.Id);
                        }
                    }
                }
            }
        }
        if(!toUpdate.isEmpty()){
            update toUpdate;
        }
        if(!toDelete.isEmpty()){
            delete toDelete;
        }
     //   if(!oppIdsToNotify.isEmpty()){  Bio_uploadKYCDocument.sendEmailOnUpload(oppIdsToNotify[0]); }
        
         for (Id oppId : oppIdsToNotify) {
             System.debug('inside for loop');
             System.debug(oppId);
             System.enqueueJob(new GenerateAccountPDFQueueable(oppId));
            //Bio_uploadKYCDocument.callSendEmailOnUpload(oppId);
           
        }
    }

}
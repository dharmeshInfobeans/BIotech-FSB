trigger LeadsTrigger on Lead__c (After Insert,before insert,before update,After update,After delete,before delete,After undelete) {
    DispatcherClass.run(new LeadTriggerHandler(), 'LeadTrigger');  
    List<Lead__c> leadList = new List<Lead__c>();
    if(Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)){
        for(Lead__c leadRec : Trigger.new){
           if(Trigger.isInsert || leadRec.OwnerId != Trigger.oldMap.get(leadRec.Id).OwnerId) leadList.add(leadRec);
            if(Trigger.isUpdate && leadRec.RSM_New__c != Trigger.oldMap.get(leadRec.Id).RSM_New__c && leadRec.RSM_New__c!=null) leadRec.Assignment_Stage__c = 'Allocated – Pending RSM Acceptance'; 
            if(Trigger.isInsert && leadRec.RSM_New__c!=null) leadRec.Assignment_Stage__c = 'Allocated – Pending RSM Acceptance'; 
        }
        if(!leadList.isEmpty()) LeadTriggerHandler.checkOrthoOwner(leadList);
    }
    
    //Added by Shakib Khan
    if (Trigger.isBefore && Trigger.isInsert) {
        LeadHandler.populateFieldsFromAccount(Trigger.new);
        System.debug('shakib bhai trigger called');
       // LeadTriggerHandler.populateCityWiseUserOnLeadCreation(Trigger.new);
    }

    if(Trigger.isAfter && Trigger.isInsert){
        LeadTriggerHandler.assingOrgRoleHirearchy(Trigger.new,false);
    }

    if(Trigger.isAfter && Trigger.isUpdate){
        List<Lead__c> leadsToUpdate = new List<Lead__c>();
        for(Lead__c ld : Trigger.new){
            boolean oldValue = Trigger.oldMap.get(ld.Id).RLS_Checked__c;
            Id oldOwnerId = Trigger.oldMap.get(ld.Id).OwnerId;
            if(ld.RLS_Checked__c != oldValue || ld.OwnerId != oldOwnerId){
                leadsToUpdate.add(ld);
            }
        }
        if(!leadsToUpdate.isEmpty()){
             LeadTriggerHandler.assingOrgRoleHirearchy(leadsToUpdate,true);
        }
    }
}
trigger OpportunityTrigger on Opportunity__c (before update,after insert,after update) {
    if(Trigger.isBefore && Trigger.isUpdate){
        OpportunityTriggerHandler.validateEvaluationStage(Trigger.new, Trigger.oldMap);
    }
   /* 
    if(Trigger.isInsert && Trigger.isAfter){
        List<Opportunity__c> newAccountOpp = new List<Opportunity__c>();
        for(Opportunity__c opp : Trigger.new){
            if(String.isBlank(opp.SAP_Code__c)){
                newAccountOpp.add(opp);
            }	
        }
      // if(!newAccountOpp.isEmpty()) OpportunityTriggerHandler.assingOrgRoleHirearchy(newAccountOpp);
    }*/
    if(trigger.isAfter && trigger.isUpdate){
        OpportunityTriggerHandler.sendEmailToOpportunityOwnerOnAdminRejection(trigger.new,trigger.oldMap);
    }
    
    if(trigger.isAfter && trigger.isUpdate){
        List<Opportunity__c> oppList = new List<Opportunity__c>();
        for(Opportunity__c opp : Trigger.new){
            System.debug('BillingCOuntry : '+opp.Country__c);
            if(opp.Mis_Email__c == true && Trigger.oldMap.get(opp.Id).Mis_Email__c == false){
                oppList.add(opp);
            }
        }
        if(!oppList.isEmpty()) SAPAccountEmailNotifier.oppEmail(oppList);
    }

}
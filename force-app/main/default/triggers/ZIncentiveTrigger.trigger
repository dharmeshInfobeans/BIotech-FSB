trigger ZIncentiveTrigger on Z_Incentive__c (before insert,before update, after insert,After update ) {
    ZIncentiveTriggerHandler zInctTriggerHandler = new ZIncentiveTriggerHandler();
    if(trigger.isBefore){
        if(trigger.isInsert){
            zInctTriggerHandler.beforeInsertHandler(trigger.New);
        }
        if(trigger.isUpdate){
            zInctTriggerHandler.beforeUpdateHandler(trigger.New, trigger.OldMap);
        }
    }
    
   if(trigger.IsAfter){
        if(trigger.IsUpdate){
            for (Z_Incentive__c updatedZinct : Trigger.new){
				zInctTriggerHandler.afterUpdateHandler(trigger.New, trigger.OldMap);
            } 
        }
        if(trigger.isInsert){
            zInctTriggerHandler.updateRegion(trigger.New);
            zInctTriggerHandler.updateRollingForecastLookups(trigger.New);
        }
    }  
}
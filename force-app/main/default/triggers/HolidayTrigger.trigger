trigger HolidayTrigger on Holiday__c (after insert , after update , after undelete) {
    if(Trigger.isAfter && ( Trigger.isInsert || Trigger.isUndelete)){
        HolidayTriggerHandler.handleHolidayInsertOrUndelete(Trigger.new);
    }
    if(Trigger.isAfter && Trigger.isUpdate){
        HolidayTriggerHandler.handleHolidayUpdate(Trigger.newMap, Trigger.oldMap);
    }
}
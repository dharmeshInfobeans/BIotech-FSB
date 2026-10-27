trigger FreightReqTrigger on Freight_Request__c (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            FreightReqTriggerHelper.updateLookupOnOp(Trigger.new);
        }
    }
}
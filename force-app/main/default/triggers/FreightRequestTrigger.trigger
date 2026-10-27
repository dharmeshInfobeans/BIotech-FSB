trigger FreightRequestTrigger on Order_Product__c (after insert, after update, after delete) {
    
    if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            if(FreightRequestHelper.insertUpdaterunOnce)
                FreightRequestHelper.processFreightRequests(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            if(FreightRequestHelper.deleterunOnce)
                FreightRequestHelper.updateFreightOnOrderProductDeletion(Trigger.oldMap);
        }
    }
}
trigger OrderProductTrigger on Order_Product__c (before insert, before update) {
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
    }
}
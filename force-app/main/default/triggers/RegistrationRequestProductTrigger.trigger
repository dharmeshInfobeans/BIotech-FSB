trigger RegistrationRequestProductTrigger on Registration_Request_Product__c
    (after insert, after update, after delete, after undelete) {

    Set<Id> requestIds = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (Registration_Request_Product__c rrp : Trigger.new) {
            if (rrp.Registration_Request__c != null) {
                requestIds.add(rrp.Registration_Request__c);
            }
        }
    }
    if (Trigger.isUpdate || Trigger.isDelete) {
        for (Registration_Request_Product__c rrp : Trigger.old) {
            if (rrp.Registration_Request__c != null) {
                requestIds.add(rrp.Registration_Request__c);
            }
        }
    }

    if (!requestIds.isEmpty()) {
        RegistrationProductRollupService.rollupProductList(requestIds);
    }
}
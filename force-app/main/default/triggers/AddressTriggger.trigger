trigger AddressTriggger on Address__c (after  insert,after delete) {
    if(Trigger.isAfter) {
        if(Trigger.isInsert) {
             AdressTriggerHelper.updateAdressOnLead(Trigger.new);
        }
        if(Trigger.isDelete) {
            AdressTriggerHelper.deleteAddresse(Trigger.old);
        }
        
    }
   
    
}
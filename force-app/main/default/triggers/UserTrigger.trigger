trigger UserTrigger on User (after insert , after update,before insert , before update) {
    List<User> userList = new List<User>();
    if(Trigger.isAfter && Trigger.isInsert){
        UserTriggerHandler.handleUserInsert(Trigger.new);
    }
    if(Trigger.isBefore && (Trigger.isUpdate || Trigger.isInsert)){
        for(User usr : Trigger.new){
            if(Trigger.isInsert || (usr.L1_Manager__c != Trigger.oldMap.get(usr.Id).L1_Manager__c)){
                usr.Custom_Manager_Id__c = usr.L1_Manager__c;
            }
        }
    }
    if(Trigger.isAfter && Trigger.isUpdate){
        
        UserTriggerHandler.handleUserUpdate(Trigger.newMap, Trigger.oldMap);
    }
}
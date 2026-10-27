trigger ShareAccountWithAccTeam on Account_Team__c (before insert,before update,after insert, after update,before delete,after delete) {
    AccountTeamHandler.shareAccountWithAccTeam(Trigger.new, Trigger.old,Trigger.newMap,Trigger.oldMap,Trigger.operationType);
}
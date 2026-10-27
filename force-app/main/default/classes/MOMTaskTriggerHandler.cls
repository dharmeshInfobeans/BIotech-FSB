public without sharing class MOMTaskTriggerHandler {

    public static void handle(List<Task> newTasks, Map<Id, Task> oldMap) {
        Set<Id> meetingIds = new Set<Id>();

        for (Task t : newTasks) {
            Task old = oldMap.get(t.Id);
            if (t.Meeting__c != null
                    && t.Status == 'Completed'
                    && old.Status != 'Completed') {
                meetingIds.add(t.Meeting__c);
            }
        }

        if (meetingIds.isEmpty()) return;

        // For each meeting, check if any incomplete MOM Action Items remain
        Map<Id, Integer> pendingCountMap = new Map<Id, Integer>();
        for (Id mId : meetingIds) {
            pendingCountMap.put(mId, 0);
        }

        for (AggregateResult ar : [
            SELECT Meeting__c mId, COUNT(Id) cnt
            FROM   Task
            WHERE  Meeting__c IN :meetingIds
            AND    RecordType.DeveloperName = 'MOM_Action_Item'
            AND    Status != 'Completed'
            GROUP BY Meeting__c
        ]) {
            pendingCountMap.put((Id) ar.get('mId'), (Integer) ar.get('cnt'));
        }

        List<MOM_Meeting__c> toFinalize = new List<MOM_Meeting__c>();
        for (Id mId : pendingCountMap.keySet()) {
            if (pendingCountMap.get(mId) == 0) {
                toFinalize.add(new MOM_Meeting__c(Id = mId, Status__c = 'Finalized'));
            }
        }

        if (!toFinalize.isEmpty()) {
            update toFinalize;
        }
    }
}
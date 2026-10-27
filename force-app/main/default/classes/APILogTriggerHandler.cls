public class APILogTriggerHandler implements TriggerInterface{
    
    public static Boolean TriggerDisabled = false;
    
    public Boolean isDisabled(){
        return TriggerDisabled;
    }
    
    public void beforeInsert(List<sObject> newList) {}
    
    public void afterInsert(List<sObject> newList , Map<Id, sObject> newMap) {
        List<API_Log__c> mouSchemeLogs = new List<API_Log__c>();
        for (SObject sobj : newList) {
            API_Log__c logRec = (API_Log__c) sobj;
            if (logRec.API_Module_Type__c == 'MOU Scheme') {
                mouSchemeLogs.add(logRec);
            }
        }
        if (!mouSchemeLogs.isEmpty()) {
            APILogTriggerHelper.sendMouSchemeEmail(mouSchemeLogs);
        }
    }    
    public void beforeUpdate(List<sObject> newList, Map<Id, sObject> newMap, List<sObject> oldList, Map<Id, sObject> oldMap) {} public void afterUpdate(List<sObject> newList, Map<Id, sObject> newMap,  List<sObject> oldList, Map<Id, sObject> oldMap) {} public void beforeDelete(List<sObject> oldList , Map<Id, sObject> oldMap) {} public void afterDelete(List<sObject> oldList , Map<Id, sObject> oldMap) {} public void afterUnDelete(List<sObject> newList, Map<Id, sObject> newMap) {}
}
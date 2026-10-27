public class ContentVersionHandler implements TriggerInterface 
{ 
    public static Boolean TriggerDisabled = false; public Boolean isDisabled() 
    { 
        return TriggerDisabled;
    }
    
    public void BeforeInsert(List<sObject> newList) 
    {
        System.debug('newList: ' + newList);
    }
    
    public void AfterInsert(List<sObject> newList, Map<Id, sObject> newMap)
    {
        ContentVersionHelper.genratepublicurl(newlist); System.debug('After Insert: ' + newList);
    }
    
    public void BeforeUpdate(List<sObject> newList, Map<Id, sObject> newMap, List<sObject> oldList, Map<Id, sObject> oldMap)
    {
        System.debug('Before update : ' + newList);
    } 
    
    public void AfterUpdate(List<sObject> newList, Map<Id, sObject> newMap, List<sObject> oldList, Map<Id, sObject> oldMap) 
    {
        System.debug('After Update '); 
    }
    
    public void BeforeDelete(List<sObject> oldList , Map<Id, sObject> oldMap)
    { 
        System.debug('Before Delete ');
    } 
    
    public void AfterDelete(List<sObject> oldList , Map<Id, sObject> oldMap)
    { 
        System.debug('After Delete ');
    }
    public void AfterUnDelete(List<sObject> newList, Map<Id, sObject> newMap)
    {
        System.debug('After Undelete ');
    }
}
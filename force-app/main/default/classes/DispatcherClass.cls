public class DispatcherClass {
    
    public static void run(TriggerInterface handler, string triggerName){
        
        if (handler.IsDisabled()){
            return;
        }
        
        Leads__c setting = Leads__c.getValues(triggerName);
        Boolean isActive = setting != null && setting.isActive__c;
        System.debug('Is active'+isActive);
        if(isActive){
            
            switch on Trigger.operationType {
                
                when BEFORE_INSERT {
                    System.debug('Dispather class');
                    handler.beforeInsert(trigger.new);
                }
                when AFTER_INSERT {
                    System.debug('After Insert');
                    handler.afterInsert(trigger.new, trigger.newMap);
                }
                when BEFORE_UPDATE {
                    handler.beforeUpdate(trigger.new, trigger.newMap, trigger.old, trigger.oldMap);
                }
                when AFTER_UPDATE {
                    system.debug('After update');
                    handler.afterUpdate(trigger.new, trigger.newMap, trigger.old, trigger.oldMap);
                }
                when BEFORE_DELETE {
                    handler.beforeDelete(trigger.old, trigger.oldMap);
                }
                when AFTER_DELETE {
                    handler.afterDelete(trigger.old, trigger.oldMap);
                }
                when AFTER_UNDELETE {
                    handler.afterUnDelete(trigger.new, trigger.newMap);
                }
            }
        }
    }
}
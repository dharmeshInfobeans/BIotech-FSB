trigger MOMTaskTrigger on Task (after update) {
    MOMTaskTriggerHandler.handle(Trigger.new, Trigger.oldMap);
}
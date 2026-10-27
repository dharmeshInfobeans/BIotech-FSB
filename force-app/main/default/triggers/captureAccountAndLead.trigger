trigger captureAccountAndLead on Event (before insert, before update, after update) {

    Id recId   = Schema.SObjectType.Event.getRecordTypeInfosByName().get('DCR Planning').getRecordTypeId();
    Id BDrecId = Schema.SObjectType.Event.getRecordTypeInfosByName().get('BD Tracker').getRecordTypeId();

    // ------------------- BEFORE UPDATE -------------------
    if (Trigger.isUpdate && Trigger.isBefore) {
        // Validate and create history
        EventHandler.validateDateChanged(Trigger.new, Trigger.old);
        EventHandler.createHistoryData(Trigger.new, Trigger.oldMap);
    }

    // ------------------- AFTER UPDATE -------------------
    if (Trigger.isUpdate && Trigger.isAfter) {
        List<Event> lstEvent = new List<Event>();

        for (Event objNew : Trigger.new) {
            if (objNew.RecordTypeId == BDrecId && objNew.Milestone_Stage__c == 'Actual') {
                lstEvent.add(objNew);
            }
        }

        if (!lstEvent.isEmpty()) {
            EventHandler.updateTracker(lstEvent);
        }
    }

    // ------------------- BEFORE INSERT/UPDATE -------------------
    List<Event> eventList = new List<Event>();

    for (Event obj : Trigger.new) {
        if (obj.RecordTypeId == recId) {
            if (Trigger.isInsert || (Trigger.isUpdate && Trigger.isBefore &&
                obj.StartDateTime != Trigger.oldMap.get(obj.Id).StartDateTime)) {
                eventList.add(obj);
            }
        }
    }

    if (!eventList.isEmpty()) {
        CaptureAccountAndLeadHelper.updatevent(eventList);
    }

    // ------------------- AFTER UPDATE -------------------
    if (Trigger.isUpdate && Trigger.isAfter) {
        List<Event> recEventList = new List<Event>();
        for (Event obj : Trigger.new) {
            if (obj.RecordTypeId == recId) {
                recEventList.add(obj);
            }
        }
        if (!recEventList.isEmpty()) {
            CaptureAccountAndLeadHelper.updatbeatPlan(recEventList);
        }
    }

    /* ------------------- OPTIONAL LOGIC (Keep Commented) -------------------
    if (Trigger.isBefore) { 
        for (Event e : Trigger.new) {
            if (Trigger.isInsert && e.Call_Type__c != 'Leave' && e.Call_Type__c != 'Holiday' && e.Call_Type__c != 'Review meeting') {
                e.Planned_Visits__c = 1;    
            }
            if (Trigger.isUpdate && e.Actual_Visits__c != 1 &&
                (e.Status__c == 'Sent for Approval' || e.Status__c == 'Draft')) {
                e.Actual_Visits__c = 1;
            }
        }
    }
    */
}
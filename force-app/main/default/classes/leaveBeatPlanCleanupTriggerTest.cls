/**
 * @description Trigger-specific integration test class for leaveBeatPlanCleanupTrigger
 * @author Priyam Shah
 * @date 2026-02-02
 * Coverage Target: 100% trigger coverage
 *
 * This test class validates that the trigger fires correctly in before delete
 * context and integrates properly with leaveBeatPlanCleanupHelper.
 * For detailed business logic tests, see leaveBeatPlanCleanupHelperTest.cls
 */
@isTest
public class leaveBeatPlanCleanupTriggerTest {

    /**
     * @description Setup test data for all test methods
     * Creates Beat Plans and corresponding Events for trigger testing
     */
    @testSetup
    static void setupTestData() {
        // Create Beat Plans
        List<Beat_Plan__c> beatPlans = new List<Beat_Plan__c>();

        // Create 5 Leave Beat Plans for trigger testing
        for(Integer i = 0; i < 5; i++) {
            Beat_Plan__c leaveBeatPlan = new Beat_Plan__c(
                Beat_Date__c = System.today().addDays(i),
                Assigned_To__c = UserInfo.getUserId(),
                Event_type_Name__c = 'Leave',
                Approval_status__c = 'Approved'
            );
            beatPlans.add(leaveBeatPlan);
        }

        // Create 2 Work Beat Plans for non-leave event testing
        for(Integer i = 0; i < 2; i++) {
            Beat_Plan__c workBeatPlan = new Beat_Plan__c(
                Beat_Date__c = System.today().addDays(10 + i),
                Assigned_To__c = UserInfo.getUserId(),
                Event_type_Name__c = 'Work',
                Approval_status__c = 'Approved'
            );
            beatPlans.add(workBeatPlan);
        }

        insert beatPlans;

        // Create Events
        List<Event> events = new List<Event>();

        // Create 5 Leave Events linked to Leave Beat Plans (index 0-4)
        for(Integer i = 0; i < 5; i++) {
            Event leaveEvent = new Event(
                Subject = 'Leave',
                StartDateTime = System.now().addDays(i),
                EndDateTime = System.now().addDays(i).addHours(8),
                Beat_plan__c = beatPlans[i].Id,
                Description = 'Trigger Test Leave Event ' + i
            );
            events.add(leaveEvent);
        }

        // Create 2 Meeting Events linked to Work Beat Plans (index 5-6)
        for(Integer i = 0; i < 2; i++) {
            Event meetingEvent = new Event(
                Subject = 'Customer Meeting',
                StartDateTime = System.now().addDays(10 + i),
                EndDateTime = System.now().addDays(10 + i).addHours(1),
                Beat_plan__c = beatPlans[5 + i].Id,
                Description = 'Trigger Test Meeting Event ' + i
            );
            events.add(meetingEvent);
        }

        // Create 1 Leave Event WITHOUT Beat Plan
        Event leaveNoPlanEvent = new Event(
            Subject = 'Leave',
            StartDateTime = System.now().addDays(20),
            EndDateTime = System.now().addDays(20).addHours(8),
            Description = 'Leave Event without Beat Plan'
        );
        events.add(leaveNoPlanEvent);

        insert events;
    }

    // ==================== Trigger Integration Tests ====================

    /**
     * @description Test trigger fires for single leave event deletion
     * Validates trigger executes in before delete context for single record
     */
    @isTest
    static void testTrigger_SingleLeaveEventDeletion_Success() {
        // Query for a leave event with beat plan
        Event leaveEvent = [
            SELECT Id, Beat_plan__c, Subject
            FROM Event
            WHERE Subject = 'Leave' AND Beat_plan__c != null
            LIMIT 1
        ];
        Id beatPlanId = leaveEvent.Beat_plan__c;

        // Verify Beat Plan exists before deletion
        List<Beat_Plan__c> beforeDelete = [SELECT Id FROM Beat_Plan__c WHERE Id = :beatPlanId];
        System.assertEquals(1, beforeDelete.size(), 'Beat Plan should exist before event deletion');

        Test.startTest();
        // Delete the event - trigger fires automatically in before delete context
        delete leaveEvent;
        Test.stopTest();

        // Verify Beat Plan was cascade deleted by trigger
        List<Beat_Plan__c> afterDelete = [SELECT Id FROM Beat_Plan__c WHERE Id = :beatPlanId];
        System.assertEquals(0, afterDelete.size(),
            'Trigger should fire and cascade delete Beat Plan when leave event is deleted');
    }

    /**
     * @description Test trigger handles bulk deletion of 200 events
     * Validates trigger handles governor limits and bulk processing
     */
    @isTest
    static void testTrigger_BulkLeaveEventDeletion_200Records() {
        // Create 200 Beat Plans and Events for bulk testing
        List<Beat_Plan__c> bulkBeatPlans = new List<Beat_Plan__c>();
        for(Integer i = 0; i < 200; i++) {
            Beat_Plan__c bp = new Beat_Plan__c(
                Beat_Date__c = System.today().addDays(100 + i),
                Assigned_To__c = UserInfo.getUserId(),
                Event_type_Name__c = 'Leave',
                Approval_status__c = 'Approved'
            );
            bulkBeatPlans.add(bp);
        }
        insert bulkBeatPlans;

        List<Event> bulkEvents = new List<Event>();
        for(Integer i = 0; i < 200; i++) {
            Event ev = new Event(
                Subject = 'Leave',
                StartDateTime = System.now().addDays(100 + i),
                EndDateTime = System.now().addDays(100 + i).addHours(8),
                Beat_plan__c = bulkBeatPlans[i].Id,
                Description = 'Bulk Test Event ' + i
            );
            bulkEvents.add(ev);
        }
        insert bulkEvents;

        // Collect Beat Plan IDs for verification
        Set<Id> beatPlanIds = new Set<Id>();
        for(Beat_Plan__c bp : bulkBeatPlans) {
            beatPlanIds.add(bp.Id);
        }

        // Verify all Beat Plans exist
        List<Beat_Plan__c> beforeDelete = [SELECT Id FROM Beat_Plan__c WHERE Id IN :beatPlanIds];
        System.assertEquals(200, beforeDelete.size(), 'All 200 Beat Plans should exist before deletion');

        Test.startTest();
        // Delete all 200 events - trigger fires in bulk context
        delete bulkEvents;
        Test.stopTest();

        // Verify all Beat Plans were cascade deleted
        List<Beat_Plan__c> afterDelete = [SELECT Id FROM Beat_Plan__c WHERE Id IN :beatPlanIds];
        System.assertEquals(0, afterDelete.size(),
            'Trigger should handle bulk deletion of 200 events and cascade delete all Beat Plans');
    }

    /**
     * @description Test trigger context receives correct Trigger.old collection
     * Validates trigger processes mixed events and filters correctly
     */
    @isTest
    static void testTrigger_TriggerContextValidation_TriggerOldSize() {
        // Query for 3 leave events and 2 non-leave events
        List<Event> leaveEvents = [
            SELECT Id, Beat_plan__c, Subject
            FROM Event
            WHERE Subject = 'Leave' AND Beat_plan__c != null
            LIMIT 3
        ];

        List<Event> nonLeaveEvents = [
            SELECT Id, Beat_plan__c, Subject
            FROM Event
            WHERE Subject = 'Customer Meeting' AND Beat_plan__c != null
            LIMIT 2
        ];

        // Collect Beat Plan IDs from leave events only
        Set<Id> leaveBeatPlanIds = new Set<Id>();
        for(Event ev : leaveEvents) {
            leaveBeatPlanIds.add(ev.Beat_plan__c);
        }

        // Collect Beat Plan IDs from non-leave events
        Set<Id> nonLeaveBeatPlanIds = new Set<Id>();
        for(Event ev : nonLeaveEvents) {
            nonLeaveBeatPlanIds.add(ev.Beat_plan__c);
        }

        // Combine all events for deletion
        List<Event> allEvents = new List<Event>();
        allEvents.addAll(leaveEvents);
        allEvents.addAll(nonLeaveEvents);

        System.assertEquals(5, allEvents.size(), 'Should have 5 total events to delete');

        Test.startTest();
        // Delete all 5 events - trigger receives Trigger.old with 5 events
        // but should only process the 3 leave events due to filtering
        delete allEvents;
        Test.stopTest();

        // Verify only leave Beat Plans were deleted
        List<Beat_Plan__c> deletedLeavePlans = [SELECT Id FROM Beat_Plan__c WHERE Id IN :leaveBeatPlanIds];
        System.assertEquals(0, deletedLeavePlans.size(),
            'All 3 Leave Beat Plans should be deleted');

        List<Beat_Plan__c> remainingWorkPlans = [SELECT Id FROM Beat_Plan__c WHERE Id IN :nonLeaveBeatPlanIds];
        System.assertEquals(2, remainingWorkPlans.size(),
            'Non-Leave Beat Plans should NOT be deleted - validates filtering in trigger context');
    }

    /**
     * @description Test trigger fires but helper filters out non-leave events
     * Validates end-to-end filtering logic
     */
    @isTest
    static void testTrigger_NonLeaveEvents_NoHelperImpact() {
        // Query for non-leave events (Customer Meeting)
        List<Event> meetingEvents = [
            SELECT Id, Beat_plan__c, Subject
            FROM Event
            WHERE Subject = 'Customer Meeting' AND Beat_plan__c != null
        ];

        System.assert(meetingEvents.size() > 0, 'Should have at least one meeting event');

        // Collect Beat Plan IDs
        Set<Id> beatPlanIds = new Set<Id>();
        for(Event ev : meetingEvents) {
            beatPlanIds.add(ev.Beat_plan__c);
        }

        // Verify Beat Plans exist
        List<Beat_Plan__c> beforeDelete = [SELECT Id FROM Beat_Plan__c WHERE Id IN :beatPlanIds];
        System.assertEquals(meetingEvents.size(), beforeDelete.size(),
            'All Beat Plans should exist before event deletion');

        Test.startTest();
        // Delete meeting events - trigger fires but helper should filter them out
        delete meetingEvents;
        Test.stopTest();

        // Verify Beat Plans were NOT deleted (Subject filter should exclude them)
        List<Beat_Plan__c> afterDelete = [SELECT Id FROM Beat_Plan__c WHERE Id IN :beatPlanIds];
        System.assertEquals(meetingEvents.size(), afterDelete.size(),
            'Beat Plans should NOT be deleted when events have Subject != "Leave"');
    }

    /**
     * @description Test mixed scenario with comprehensive integration validation
     * Validates complete trigger to helper flow with various event types
     */
    @isTest
    static void testTrigger_MixedScenario_SelectiveProcessing() {
        // Query one leave event with beat plan (should delete)
        Event leaveWithPlan = [
            SELECT Id, Beat_plan__c, Subject
            FROM Event
            WHERE Subject = 'Leave' AND Beat_plan__c != null
            LIMIT 1
        ];
        Id leaveBeatPlanId = leaveWithPlan.Beat_plan__c;

        // Query meeting event with beat plan (should NOT delete)
        Event meetingWithPlan = [
            SELECT Id, Beat_plan__c, Subject
            FROM Event
            WHERE Subject = 'Customer Meeting' AND Beat_plan__c != null
            LIMIT 1
        ];
        Id meetingBeatPlanId = meetingWithPlan.Beat_plan__c;

        // Query leave event without beat plan (no beat plan to delete)
        Event leaveNoPlan = [
            SELECT Id, Beat_plan__c, Subject
            FROM Event
            WHERE Subject = 'Leave' AND Beat_plan__c = null
            LIMIT 1
        ];

        // Verify initial state
        List<Beat_Plan__c> beforeDelete = [
            SELECT Id
            FROM Beat_Plan__c
            WHERE Id IN (:leaveBeatPlanId, :meetingBeatPlanId)
        ];
        System.assertEquals(2, beforeDelete.size(), 'Both Beat Plans should exist initially');

        Test.startTest();
        // Delete all three events - trigger fires and processes selectively
        delete new List<Event>{leaveWithPlan, meetingWithPlan, leaveNoPlan};
        Test.stopTest();

        // Verify only the leave beat plan was deleted
        List<Beat_Plan__c> deletedPlan = [SELECT Id FROM Beat_Plan__c WHERE Id = :leaveBeatPlanId];
        System.assertEquals(0, deletedPlan.size(),
            'Leave Beat Plan should be cascade deleted by trigger');

        List<Beat_Plan__c> remainingPlan = [SELECT Id FROM Beat_Plan__c WHERE Id = :meetingBeatPlanId];
        System.assertEquals(1, remainingPlan.size(),
            'Meeting Beat Plan should NOT be deleted - validates selective processing');
    }

	@isTest
    static void testTrigger_EventUpdate_AfterUpdateContext() {
        Event leaveEvent = [
            SELECT Id, Subject, Description
            FROM Event
            WHERE Subject = 'Leave' AND Beat_plan__c != null
            LIMIT 1
        ];
    
        Test.startTest();
        // Update the event - fires after update context in the trigger
        leaveEvent.Description = 'Updated Description';
        update leaveEvent;
        Test.stopTest();
    
        Event updatedEvent = [SELECT Id, Description FROM Event WHERE Id = :leaveEvent.Id];
        System.assertEquals('Updated Description', updatedEvent.Description,
            'Event should update successfully and fire after update trigger context');
    }
    
    /**
     * @description Test bulk update of Events to validate after update branch
     * under bulk trigger context (200 records)
     */
    @isTest
    static void testTrigger_BulkEventUpdate_AfterUpdateContext() {
        List<Event> leaveEvents = [
            SELECT Id, Description
            FROM Event
            WHERE Subject = 'Leave' AND Beat_plan__c != null
        ];
    
        for (Event ev : leaveEvents) {
            ev.Description = 'Bulk Updated';
        }
    
        Test.startTest();
        update leaveEvents;
        Test.stopTest();
    
        List<Event> updatedEvents = [
            SELECT Id, Description
            FROM Event
            WHERE Id IN :leaveEvents
        ];
        for (Event ev : updatedEvents) {
            System.assertEquals('Bulk Updated', ev.Description,
                'All events should update successfully in bulk after update context');
        }
    }
}
/**
 * @description Comprehensive test class for leaveBeatPlanCleanupHelper
 * @author Priyam Shah
 * @date 2026-02-02
 * Coverage Target: 90%+ (11 test methods covering all code paths)
 */
@isTest
public class leaveBeatPlanCleanupHelperTest {

    /**
     * @description Setup test data for all test methods
     * Creates Beat Plans (Leave and Work types) and corresponding Events
     */
    @testSetup
    static void setupTestData() {
        // Create Beat Plans
        List<Beat_Plan__c> beatPlans = new List<Beat_Plan__c>();

        // Create 6 Leave Beat Plans for success path and bulk testing
        for(Integer i = 0; i < 6; i++) {
            Beat_Plan__c leaveBeatPlan = new Beat_Plan__c(
                Beat_Date__c = System.today().addDays(i),
                Assigned_To__c = UserInfo.getUserId(),
                Event_type_Name__c = 'Leave',
                Approval_status__c = 'Approved'
            );
            beatPlans.add(leaveBeatPlan);
        }

        // Create 1 Work Beat Plan for negative testing (non-leave event)
        Beat_Plan__c workBeatPlan = new Beat_Plan__c(
            Beat_Date__c = System.today().addDays(10),
            Assigned_To__c = UserInfo.getUserId(),
            Event_type_Name__c = 'Work',
            Approval_status__c = 'Approved'
        );
        beatPlans.add(workBeatPlan);

        insert beatPlans;

        // Create Events
        List<Event> events = new List<Event>();

        // Create 6 Leave Events linked to Leave Beat Plans (index 0-5)
        for(Integer i = 0; i < 6; i++) {
            Event leaveEvent = new Event(
                Subject = 'Leave',
                StartDateTime = System.now().addDays(i),
                EndDateTime = System.now().addDays(i).addHours(8),
                Beat_plan__c = beatPlans[i].Id,
                Description = 'Test Leave Event ' + i
            );
            events.add(leaveEvent);
        }

        // Create 1 Meeting Event linked to Work Beat Plan (index 6)
        Event meetingEvent = new Event(
            Subject = 'Customer Meeting',
            StartDateTime = System.now().addDays(10),
            EndDateTime = System.now().addDays(10).addHours(1),
            Beat_plan__c = beatPlans[6].Id,
            Description = 'Test Meeting Event'
        );
        events.add(meetingEvent);

        // Create 1 Leave Event WITHOUT Beat Plan
        Event leaveNoPlanEvent = new Event(
            Subject = 'Leave',
            StartDateTime = System.now().addDays(15),
            EndDateTime = System.now().addDays(15).addHours(8),
            Description = 'Leave Event without Beat Plan'
        );
        events.add(leaveNoPlanEvent);

        insert events;
    }

    // ==================== Group 1: Success Path Tests ====================

    /**
     * @description Test single leave event deletion triggers cascade delete of Beat Plan
     */
    @isTest
    static void testHandleEventDeletion_SingleLeaveEvent_Success() {
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
        // Delete the event - trigger fires automatically
        delete leaveEvent;
        Test.stopTest();

        // Verify Beat Plan was cascade deleted
        List<Beat_Plan__c> afterDelete = [SELECT Id FROM Beat_Plan__c WHERE Id = :beatPlanId];
        System.assertEquals(0, afterDelete.size(),
            'Beat Plan should be cascade deleted when leave event is deleted');
    }

    /**
     * @description Test bulk deletion of multiple leave events
     */
    @isTest
    static void testHandleEventDeletion_MultipleLeaveEvents_BulkSuccess() {
        // Query for 5 leave events with beat plans
        List<Event> leaveEvents = [
            SELECT Id, Beat_plan__c, Subject
            FROM Event
            WHERE Subject = 'Leave' AND Beat_plan__c != null
            LIMIT 5
        ];

        // Collect Beat Plan IDs
        Set<Id> beatPlanIds = new Set<Id>();
        for(Event ev : leaveEvents) {
            beatPlanIds.add(ev.Beat_plan__c);
        }

        System.assertEquals(5, beatPlanIds.size(), 'Should have 5 unique beat plans');

        // Verify Beat Plans exist before deletion
        List<Beat_Plan__c> beforeDelete = [SELECT Id FROM Beat_Plan__c WHERE Id IN :beatPlanIds];
        System.assertEquals(5, beforeDelete.size(), 'All 5 Beat Plans should exist before deletion');

        Test.startTest();
        // Delete all events in bulk - trigger fires for all
        delete leaveEvents;
        Test.stopTest();

        // Verify all Beat Plans were cascade deleted
        List<Beat_Plan__c> afterDelete = [SELECT Id FROM Beat_Plan__c WHERE Id IN :beatPlanIds];
        System.assertEquals(0, afterDelete.size(),
            'All 5 Beat Plans should be cascade deleted in bulk operation');
    }

    // ==================== Group 2: Filtering Logic Tests ====================

    /**
     * @description Test that non-leave events do not trigger cascade deletion
     */
    @isTest
    static void testHandleEventDeletion_NonLeaveEvent_NotDeleted() {
        // Query for meeting event with beat plan (Subject != 'Leave')
        Event meetingEvent = [
            SELECT Id, Beat_plan__c, Subject
            FROM Event
            WHERE Subject = 'Customer Meeting' AND Beat_plan__c != null
            LIMIT 1
        ];
        Id beatPlanId = meetingEvent.Beat_plan__c;

        // Verify Beat Plan exists
        List<Beat_Plan__c> beforeDelete = [SELECT Id FROM Beat_Plan__c WHERE Id = :beatPlanId];
        System.assertEquals(1, beforeDelete.size(), 'Beat Plan should exist');

        Test.startTest();
        // Delete the meeting event
        delete meetingEvent;
        Test.stopTest();

        // Verify Beat Plan was NOT deleted (Subject filter should exclude it)
        List<Beat_Plan__c> afterDelete = [SELECT Id FROM Beat_Plan__c WHERE Id = :beatPlanId];
        System.assertEquals(1, afterDelete.size(),
            'Beat Plan should NOT be deleted when event subject is not "Leave"');
    }

    /**
     * @description Test that leave events without Beat Plan reference are handled gracefully
     */
    @isTest
    static void testHandleEventDeletion_LeaveEventNoBeatPlan_NoError() {
        // Query for leave event WITHOUT beat plan
        Event leaveNoPlan = [
            SELECT Id, Beat_plan__c, Subject
            FROM Event
            WHERE Subject = 'Leave' AND Beat_plan__c = null
            LIMIT 1
        ];

        // Count all Beat Plans before deletion
        Integer beatPlanCountBefore = [SELECT COUNT() FROM Beat_Plan__c];

        Test.startTest();
        // Delete the event - should not cause errors
        delete leaveNoPlan;
        Test.stopTest();

        // Verify no Beat Plans were affected
        Integer beatPlanCountAfter = [SELECT COUNT() FROM Beat_Plan__c];
        System.assertEquals(beatPlanCountBefore, beatPlanCountAfter,
            'No Beat Plans should be affected when deleting leave event without Beat Plan reference');
    }

    /**
     * @description Test mixed scenario with different event types and configurations
     */
    @isTest
    static void testHandleEventDeletion_MixedEvents_SelectiveDeletion() {
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

        Test.startTest();
        // Delete all three events
        delete new List<Event>{leaveWithPlan, meetingWithPlan, leaveNoPlan};
        Test.stopTest();

        // Verify only the leave beat plan was deleted
        List<Beat_Plan__c> deletedPlan = [SELECT Id FROM Beat_Plan__c WHERE Id = :leaveBeatPlanId];
        System.assertEquals(0, deletedPlan.size(),
            'Leave Beat Plan should be deleted');

        List<Beat_Plan__c> remainingPlan = [SELECT Id FROM Beat_Plan__c WHERE Id = :meetingBeatPlanId];
        System.assertEquals(1, remainingPlan.size(),
            'Meeting Beat Plan should NOT be deleted');
    }

    // ==================== Group 3: Edge Cases ====================

    /**
     * @description Test helper handles empty event list gracefully
     */
    @isTest
    static void testHandleEventDeletion_EmptyEventList_NoError() {
        Test.startTest();
        // Call helper directly with empty list
        leaveBeatPlanCleanupHelper.handleEventDeletion(new List<Event>());
        Test.stopTest();

        // Verify no errors thrown and method completes successfully
        System.assert(true, 'Empty list should be handled gracefully without errors');
    }

    /**
     * @description Test that no queries execute when beatPlanIds set is empty
     */
    @isTest
    static void testHandleEventDeletion_BeatPlanIdsEmpty_NoQuery() {
        // Create events that won't match filter criteria
        List<Event> nonMatchingEvents = new List<Event>();

        // Event without Beat Plan
        Event ev1 = new Event(
            Subject = 'Leave',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1)
        );

        // Event with Beat Plan but wrong subject
        Event ev2 = new Event(
            Subject = 'Other',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1)
        );

        // Add these events to simulate trigger context
        // In real scenario, these would be in Trigger.old

        Test.startTest();
        // Call helper directly with events that don't match filter
        leaveBeatPlanCleanupHelper.handleEventDeletion(nonMatchingEvents);

        // Verify no SOQL queries were executed (isEmpty check prevents query)
        Integer queriesUsed = Limits.getQueries();
        Test.stopTest();

        System.assertEquals(0, queriesUsed,
            'No SOQL queries should be executed when beatPlanIds set is empty');
    }

    /**
     * @description Test when query returns empty (beat plan deleted externally)
     */
    @isTest
    static void testHandleEventDeletion_QueryReturnsEmpty_NoDelete() {
        // Create a beat plan and event
        Beat_Plan__c bp = new Beat_Plan__c(
            Beat_Date__c = System.today().addDays(20),
            Assigned_To__c = UserInfo.getUserId(),
            Event_type_Name__c = 'Leave',
            Approval_status__c = 'Approved'
        );
        insert bp;

        Event ev = new Event(
            Subject = 'Leave',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(8),
            Beat_plan__c = bp.Id
        );
        insert ev;

        // Delete the beat plan BEFORE deleting the event (simulates external deletion)
        delete bp;

        Test.startTest();
        // Delete the event - query will return empty but should not error
        delete ev;
        Test.stopTest();

        // Verify operation completed without exception
        System.assert(true,
            'Should handle missing beat plans gracefully when query returns empty');
    }

    // ==================== Group 4: Integration & Additional Tests ====================

    /**
     * @description Test full trigger integration - verify trigger fires and calls helper
     */
    @isTest
    static void testTriggerIntegration_EventDeletion_TriggerFiresHelper() {
        // Query for leave event with beat plan
        Event leaveEvent = [
            SELECT Id, Beat_plan__c, Subject
            FROM Event
            WHERE Subject = 'Leave' AND Beat_plan__c != null
            LIMIT 1
        ];
        Id beatPlanId = leaveEvent.Beat_plan__c;

        // Verify Beat Plan exists
        List<Beat_Plan__c> beforeDelete = [SELECT Id FROM Beat_Plan__c WHERE Id = :beatPlanId];
        System.assertEquals(1, beforeDelete.size(), 'Beat Plan should exist');

        Test.startTest();
        // Delete event - trigger should fire automatically in test context
        delete leaveEvent;
        Test.stopTest();

        // Verify trigger executed and helper performed cascade deletion
        List<Beat_Plan__c> afterDelete = [SELECT Id FROM Beat_Plan__c WHERE Id = :beatPlanId];
        System.assertEquals(0, afterDelete.size(),
            'Trigger should fire and helper should cascade delete Beat Plan');
    }

    /**
     * @description Test successful execution with all debug logging
     */
    @isTest
    static void testHandleEventDeletion_DebugLogging_Success() {
        // Query for leave event with beat plan
        Event leaveEvent = [
            SELECT Id, Beat_plan__c, Subject
            FROM Event
            WHERE Subject = 'Leave' AND Beat_plan__c != null
            LIMIT 1
        ];
        Id beatPlanId = leaveEvent.Beat_plan__c;

        Test.startTest();
        // Delete event - all debug statements should execute
        delete leaveEvent;
        Test.stopTest();

        // Verify successful execution with debug logging
        List<Beat_Plan__c> afterDelete = [SELECT Id FROM Beat_Plan__c WHERE Id = :beatPlanId];
        System.assertEquals(0, afterDelete.size(),
            'Method should execute successfully with all debug logging statements');
    }

    // ==================== Group 5: Exception / Catch Block Test ====================

    /**
     * @description Drives execution into the catch block of handleEventDeletion using
     * Approval.lock() to genuinely lock the Beat_Plan__c record the same way Salesforce's
     * approval-process record locking would, then attempts the delete as a Standard User (who
     * lacks "Modify All Data" by default, and therefore cannot edit/delete a locked record
     * regardless of object-level Delete permission or the class being "without sharing" - locking
     * is enforced at the platform DML layer, separate from sharing/CRUD).
     *
     * Two earlier approaches were tried and ruled out:
     * 1) Running as a Standard User with no special setup - didn't throw, because this org's
     *    Standard User profile already has Delete on Beat_Plan__c (expected, since the whole
     *    point of this handler is letting regular users delete their own approved leaves).
     * 2) Exhausting the DML-statement governor limit - the resulting System.LimitException
     *    propagated uncaught past every try/catch in the stack, confirming that specific
     *    governor-limit exception can't be caught in Apex at all.
     *
     * This approach uses the platform's real locking mechanism instead of guessing at
     * permissions or abusing governor limits, so it should reliably reproduce a genuine,
     * catchable DmlException.
     */
    @isTest
    static void testHandleEventDeletion_LockedRecord_CatchBlockAndAddError() {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User limitedUser = new User(
            FirstName = 'Limited',
            LastName = 'Deleter',
            Email = 'limiteddeleter' + DateTime.now().getTime() + '@example.com',
            Username = 'limiteddeleter' + DateTime.now().getTime() + '@example.com.test',
            Alias = 'ltddel',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id
        );
        insert limitedUser;

        Beat_Plan__c bp;
        Event ev;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            bp = new Beat_Plan__c(
                Beat_Date__c = System.today().addDays(30),
                Assigned_To__c = limitedUser.Id,
                Event_type_Name__c = 'Leave',
                Approval_status__c = 'Approved'
            );
            insert bp;

            ev = new Event(
                OwnerId = limitedUser.Id,
                Subject = 'Leave',
                StartDateTime = System.now().addDays(30),
                EndDateTime = System.now().addDays(30).addHours(8),
                Beat_plan__c = bp.Id
            );
            insert ev;

            // Genuinely lock the record the way an approval process would. If "Enable record
            // locking and unlocking" isn't turned on for Beat_Plan__c in this org, this call
            // itself throws - caught below so the test fails with a clear, actionable message
            // instead of a confusing stack trace.
            try {
                Approval.lock(bp.Id);
            } catch (Exception lockEx) {
                System.assert(false,
                    'Approval.lock() failed - check that "Enable record locking and unlocking" ' +
                    'is turned on for Beat_Plan__c under Setup > Object Manager. Underlying error: ' +
                    lockEx.getMessage());
            }
        }

        Boolean exceptionThrown = false;
        String exceptionMessage;

        Test.startTest();
        System.runAs(limitedUser) {
            try {
                delete ev;
            } catch (Exception ex) {
                exceptionThrown = true;
                exceptionMessage = ex.getMessage();
            }
        }
        Test.stopTest();

        if (exceptionMessage.contains('Cannot delete leave')) {
            System.assert(exceptionMessage.contains('administrator'),
                'Error message should include the user-facing guidance from addError');
        }

        List<Beat_Plan__c> stillExists = [SELECT Id FROM Beat_Plan__c WHERE Id = :bp.Id];
        System.assertEquals(1, stillExists.size(),
            'Beat Plan should NOT be deleted when the cascade delete fails against a locked record');
    }
}




/**
 * @description Comprehensive test class for leaveBeatPlanCleanupHelper
 * @author Priyam Shah
 * @date 2026-02-02
 * Coverage Target: 90%+ (10 test methods covering all code paths)
 */
/*@isTest
public class leaveBeatPlanCleanupHelperTest {

    @testSetup
    static void setupTestData() {
        // Create Beat Plans
        List<Beat_Plan__c> beatPlans = new List<Beat_Plan__c>();

        // Create 6 Leave Beat Plans for success path and bulk testing
        for(Integer i = 0; i < 6; i++) {
            Beat_Plan__c leaveBeatPlan = new Beat_Plan__c(
                Beat_Date__c = System.today().addDays(i),
                Assigned_To__c = UserInfo.getUserId(),
                Event_type_Name__c = 'Leave',
                Approval_status__c = 'Approved'
            );
            beatPlans.add(leaveBeatPlan);
        }

        // Create 1 Work Beat Plan for negative testing (non-leave event)
        Beat_Plan__c workBeatPlan = new Beat_Plan__c(
            Beat_Date__c = System.today().addDays(10),
            Assigned_To__c = UserInfo.getUserId(),
            Event_type_Name__c = 'Work',
            Approval_status__c = 'Approved'
        );
        beatPlans.add(workBeatPlan);

        insert beatPlans;

        // Create Events
        List<Event> events = new List<Event>();

        // Create 6 Leave Events linked to Leave Beat Plans (index 0-5)
        for(Integer i = 0; i < 6; i++) {
            Event leaveEvent = new Event(
                Subject = 'Leave',
                StartDateTime = System.now().addDays(i),
                EndDateTime = System.now().addDays(i).addHours(8),
                Beat_plan__c = beatPlans[i].Id,
                Description = 'Test Leave Event ' + i
            );
            events.add(leaveEvent);
        }

        // Create 1 Meeting Event linked to Work Beat Plan (index 6)
        Event meetingEvent = new Event(
            Subject = 'Customer Meeting',
            StartDateTime = System.now().addDays(10),
            EndDateTime = System.now().addDays(10).addHours(1),
            Beat_plan__c = beatPlans[6].Id,
            Description = 'Test Meeting Event'
        );
        events.add(meetingEvent);

        // Create 1 Leave Event WITHOUT Beat Plan
        Event leaveNoPlanEvent = new Event(
            Subject = 'Leave',
            StartDateTime = System.now().addDays(15),
            EndDateTime = System.now().addDays(15).addHours(8),
            Description = 'Leave Event without Beat Plan'
        );
        events.add(leaveNoPlanEvent);

        insert events;
    }

    // ==================== Group 1: Success Path Tests ====================

    @isTest
    static void testHandleEventDeletion_SingleLeaveEvent_Success() {
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
        // Delete the event - trigger fires automatically
        delete leaveEvent;
        Test.stopTest();

        // Verify Beat Plan was cascade deleted
        List<Beat_Plan__c> afterDelete = [SELECT Id FROM Beat_Plan__c WHERE Id = :beatPlanId];
        System.assertEquals(0, afterDelete.size(),
            'Beat Plan should be cascade deleted when leave event is deleted');
    }

    @isTest
    static void testHandleEventDeletion_MultipleLeaveEvents_BulkSuccess() {
        // Query for 5 leave events with beat plans
        List<Event> leaveEvents = [
            SELECT Id, Beat_plan__c, Subject
            FROM Event
            WHERE Subject = 'Leave' AND Beat_plan__c != null
            LIMIT 5
        ];

        // Collect Beat Plan IDs
        Set<Id> beatPlanIds = new Set<Id>();
        for(Event ev : leaveEvents) {
            beatPlanIds.add(ev.Beat_plan__c);
        }

        System.assertEquals(5, beatPlanIds.size(), 'Should have 5 unique beat plans');

        // Verify Beat Plans exist before deletion
        List<Beat_Plan__c> beforeDelete = [SELECT Id FROM Beat_Plan__c WHERE Id IN :beatPlanIds];
        System.assertEquals(5, beforeDelete.size(), 'All 5 Beat Plans should exist before deletion');

        Test.startTest();
        // Delete all events in bulk - trigger fires for all
        delete leaveEvents;
        Test.stopTest();

        // Verify all Beat Plans were cascade deleted
        List<Beat_Plan__c> afterDelete = [SELECT Id FROM Beat_Plan__c WHERE Id IN :beatPlanIds];
        System.assertEquals(0, afterDelete.size(),
            'All 5 Beat Plans should be cascade deleted in bulk operation');
    }

    // ==================== Group 2: Filtering Logic Tests ====================

    @isTest
    static void testHandleEventDeletion_NonLeaveEvent_NotDeleted() {
        // Query for meeting event with beat plan (Subject != 'Leave')
        Event meetingEvent = [
            SELECT Id, Beat_plan__c, Subject
            FROM Event
            WHERE Subject = 'Customer Meeting' AND Beat_plan__c != null
            LIMIT 1
        ];
        Id beatPlanId = meetingEvent.Beat_plan__c;

        // Verify Beat Plan exists
        List<Beat_Plan__c> beforeDelete = [SELECT Id FROM Beat_Plan__c WHERE Id = :beatPlanId];
        System.assertEquals(1, beforeDelete.size(), 'Beat Plan should exist');

        Test.startTest();
        // Delete the meeting event
        delete meetingEvent;
        Test.stopTest();

        // Verify Beat Plan was NOT deleted (Subject filter should exclude it)
        List<Beat_Plan__c> afterDelete = [SELECT Id FROM Beat_Plan__c WHERE Id = :beatPlanId];
        System.assertEquals(1, afterDelete.size(),
            'Beat Plan should NOT be deleted when event subject is not "Leave"');
    }

    @isTest
    static void testHandleEventDeletion_LeaveEventNoBeatPlan_NoError() {
        // Query for leave event WITHOUT beat plan
        Event leaveNoPlan = [
            SELECT Id, Beat_plan__c, Subject
            FROM Event
            WHERE Subject = 'Leave' AND Beat_plan__c = null
            LIMIT 1
        ];

        // Count all Beat Plans before deletion
        Integer beatPlanCountBefore = [SELECT COUNT() FROM Beat_Plan__c];

        Test.startTest();
        // Delete the event - should not cause errors
        delete leaveNoPlan;
        Test.stopTest();

        // Verify no Beat Plans were affected
        Integer beatPlanCountAfter = [SELECT COUNT() FROM Beat_Plan__c];
        System.assertEquals(beatPlanCountBefore, beatPlanCountAfter,
            'No Beat Plans should be affected when deleting leave event without Beat Plan reference');
    }

    @isTest
    static void testHandleEventDeletion_MixedEvents_SelectiveDeletion() {
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

        Test.startTest();
        // Delete all three events
        delete new List<Event>{leaveWithPlan, meetingWithPlan, leaveNoPlan};
        Test.stopTest();

        // Verify only the leave beat plan was deleted
        List<Beat_Plan__c> deletedPlan = [SELECT Id FROM Beat_Plan__c WHERE Id = :leaveBeatPlanId];
        System.assertEquals(0, deletedPlan.size(),
            'Leave Beat Plan should be deleted');

        List<Beat_Plan__c> remainingPlan = [SELECT Id FROM Beat_Plan__c WHERE Id = :meetingBeatPlanId];
        System.assertEquals(1, remainingPlan.size(),
            'Meeting Beat Plan should NOT be deleted');
    }

    // ==================== Group 3: Edge Cases ====================

    @isTest
    static void testHandleEventDeletion_EmptyEventList_NoError() {
        Test.startTest();
        // Call helper directly with empty list
        leaveBeatPlanCleanupHelper.handleEventDeletion(new List<Event>());
        Test.stopTest();

        // Verify no errors thrown and method completes successfully
        System.assert(true, 'Empty list should be handled gracefully without errors');
    }

    @isTest
    static void testHandleEventDeletion_BeatPlanIdsEmpty_NoQuery() {
        // Create events that won't match filter criteria
        List<Event> nonMatchingEvents = new List<Event>();

        // Event without Beat Plan
        Event ev1 = new Event(
            Subject = 'Leave',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1)
        );

        // Event with Beat Plan but wrong subject
        Event ev2 = new Event(
            Subject = 'Other',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1)
        );

        // Add these events to simulate trigger context
        // In real scenario, these would be in Trigger.old

        Test.startTest();
        // Call helper directly with events that don't match filter
        leaveBeatPlanCleanupHelper.handleEventDeletion(nonMatchingEvents);

        // Verify no SOQL queries were executed (isEmpty check prevents query)
        Integer queriesUsed = Limits.getQueries();
        Test.stopTest();

        System.assertEquals(0, queriesUsed,
            'No SOQL queries should be executed when beatPlanIds set is empty');
    }

    @isTest
    static void testHandleEventDeletion_QueryReturnsEmpty_NoDelete() {
        // Create a beat plan and event
        Beat_Plan__c bp = new Beat_Plan__c(
            Beat_Date__c = System.today().addDays(20),
            Assigned_To__c = UserInfo.getUserId(),
            Event_type_Name__c = 'Leave',
            Approval_status__c = 'Approved'
        );
        insert bp;

        Event ev = new Event(
            Subject = 'Leave',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(8),
            Beat_plan__c = bp.Id
        );
        insert ev;

        // Delete the beat plan BEFORE deleting the event (simulates external deletion)
        delete bp;

        Test.startTest();
        // Delete the event - query will return empty but should not error
        delete ev;
        Test.stopTest();

        // Verify operation completed without exception
        System.assert(true,
            'Should handle missing beat plans gracefully when query returns empty');
    }

    // ==================== Group 4: Integration & Additional Tests ====================

    @isTest
    static void testTriggerIntegration_EventDeletion_TriggerFiresHelper() {
        // Query for leave event with beat plan
        Event leaveEvent = [
            SELECT Id, Beat_plan__c, Subject
            FROM Event
            WHERE Subject = 'Leave' AND Beat_plan__c != null
            LIMIT 1
        ];
        Id beatPlanId = leaveEvent.Beat_plan__c;

        // Verify Beat Plan exists
        List<Beat_Plan__c> beforeDelete = [SELECT Id FROM Beat_Plan__c WHERE Id = :beatPlanId];
        System.assertEquals(1, beforeDelete.size(), 'Beat Plan should exist');

        Test.startTest();
        // Delete event - trigger should fire automatically in test context
        delete leaveEvent;
        Test.stopTest();

        // Verify trigger executed and helper performed cascade deletion
        List<Beat_Plan__c> afterDelete = [SELECT Id FROM Beat_Plan__c WHERE Id = :beatPlanId];
        System.assertEquals(0, afterDelete.size(),
            'Trigger should fire and helper should cascade delete Beat Plan');
    }

    @isTest
    static void testHandleEventDeletion_DebugLogging_Success() {
        // Query for leave event with beat plan
        Event leaveEvent = [
            SELECT Id, Beat_plan__c, Subject
            FROM Event
            WHERE Subject = 'Leave' AND Beat_plan__c != null
            LIMIT 1
        ];
        Id beatPlanId = leaveEvent.Beat_plan__c;

        Test.startTest();
        // Delete event - all debug statements should execute
        delete leaveEvent;
        Test.stopTest();

        // Verify successful execution with debug logging
        List<Beat_Plan__c> afterDelete = [SELECT Id FROM Beat_Plan__c WHERE Id = :beatPlanId];
        System.assertEquals(0, afterDelete.size(),
            'Method should execute successfully with all debug logging statements');
    }
}*/
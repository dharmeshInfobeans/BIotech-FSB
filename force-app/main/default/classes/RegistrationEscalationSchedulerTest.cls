@isTest
private class RegistrationEscalationSchedulerTest {

    // ── Schedulable execute fires the batch without error ─────────────────────

    @isTest
    static void testExecute_FiresBatchWithoutError() {
        Boolean threw = false;
        Test.startTest();
        try {
            RegistrationEscalationScheduler scheduler = new RegistrationEscalationScheduler();
            scheduler.execute(null);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(!threw, 'Scheduler execute() should run without throwing');
    }

    // ── System.schedule wires up the job correctly ────────────────────────────

    @isTest
    static void testSchedule_JobRegistered() {
        Test.startTest();
        RegistrationEscalationScheduler.schedule();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name, State
            FROM   CronTrigger
            WHERE  CronJobDetail.Name = 'Registration Escalation Daily'
        ];
        System.assertEquals(1, jobs.size(),
            'One scheduled job should be registered with the expected name');
        System.assertEquals('WAITING', jobs[0].State,
            'Newly scheduled job should be in WAITING state');
    }

    // ── Calling schedule() twice replaces the old job (no duplicates) ─────────

    @isTest
    static void testSchedule_CalledTwice_NoDuplicates() {
        Test.startTest();
        RegistrationEscalationScheduler.schedule();
        RegistrationEscalationScheduler.schedule();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id FROM CronTrigger
            WHERE  CronJobDetail.Name = 'Registration Escalation Daily'
        ];
        System.assertEquals(1, jobs.size(),
            'Calling schedule() twice should leave exactly one job (old job aborted)');
    }
}
@IsTest
private class MOMOverdueEscalationScheduler_Test {

    private static final String CRON_EXP = '0 0 8 * * ?';
    private static final String JOB_NAME = 'MOM Overdue Escalation Test';

    // Abort any live scheduled jobs using this class before the test runs.
    // Without this, Salesforce throws "jobs pending or in progress" during deployment.
    private static void abortExistingJobs() {
        for (CronTrigger ct : [
            SELECT Id FROM CronTrigger
            WHERE CronJobDetail.JobType = '7'
            AND   State NOT IN ('DELETED', 'COMPLETE')
            AND   CronJobDetail.Name LIKE 'MOM Overdue Escalation%'
        ]) {
            System.abortJob(ct.Id);
        }
    }

    @IsTest
    static void execute_WhenScheduled_ShouldSubmitBatchWithoutError() {
        abortExistingJobs();

        Test.startTest();
        String jobId = System.schedule(JOB_NAME, CRON_EXP, new MOMOverdueEscalationScheduler());
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, CronExpression, State
            FROM   CronTrigger
            WHERE  Id = :jobId
        ];
        System.assertEquals(1,        jobs.size(),              'Scheduler job should be created');
        System.assertEquals(CRON_EXP, jobs[0].CronExpression,  'Cron expression should match');
    }
}
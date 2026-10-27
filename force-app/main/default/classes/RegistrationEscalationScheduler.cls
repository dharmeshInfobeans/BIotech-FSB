public class RegistrationEscalationScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new RegistrationEscalationBatch(), 50);
    }

    // Run daily at 8:00 AM — execute this once in Anonymous Apex after deployment:
    // RegistrationEscalationScheduler.schedule();
    public static void schedule() {
        String jobName = 'Registration Escalation Daily';
        // Abort any existing schedule with the same name
        for (CronTrigger ct : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = :jobName]) {
            System.abortJob(ct.Id);
        }
        // 0 0 8 * * ? = every day at 8:00 AM
        System.schedule(jobName, '0 0 8 * * ?', new RegistrationEscalationScheduler());
    }
}
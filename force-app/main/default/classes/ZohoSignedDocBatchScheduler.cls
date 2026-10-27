public class ZohoSignedDocBatchScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        // 1. Run the batch
        Database.executeBatch(new ZohoSignedDocBatch(), 50);

        // 2. Clean up the current scheduled job entry
        if (sc != null) {
            System.abortJob(sc.getTriggerId());
        }

        // 3. Schedule the NEXT run, 5 minutes from now
        DateTime nextRun = System.now().addMinutes(5);
        String cronExp = nextRun.format('s m H d M \'?\' yyyy');

        System.schedule(
            'Zoho Signed Doc Batch - ' + nextRun.getTime(),
            cronExp,
            new ZohoSignedDocBatchScheduler()
        );
    }
}
public class MasterAgreementSyncScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new MasterAgreementSAPBatch(), 1); // small batch size for callouts
    }

    public static void scheduleMe() {
        // Every 4 hours
        String cronExp = '0 0 0/4 * * ?';
        System.schedule('SAP Sync Batch Every 4 Hours', cronExp, new MasterAgreementSyncScheduler());
    }
}
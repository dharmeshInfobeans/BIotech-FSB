global class MasterAgreementExpiryScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        try {
            System.debug('Triggering MasterAgreementExpiryBatch...');
            MasterAgreementExpiryBatch batchJob = new MasterAgreementExpiryBatch();
            Database.executeBatch(batchJob, 150);  // Batch size of 50
        } catch (Exception e) {
            System.debug('Error executing MasterAgreementExpiryScheduler: ' + e.getMessage());
        }
    }
}
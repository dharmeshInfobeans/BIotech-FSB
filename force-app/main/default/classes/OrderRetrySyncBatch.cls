public class OrderRetrySyncBatch
    implements Database.Batchable<SObject>,
               Database.AllowsCallouts,
               Schedulable {

    public static final Integer RETRY_WINDOW_HOURS = 48;
    public static final Integer RETRY_BATCH_SCOPE = 1;

    public Database.QueryLocator start(Database.BatchableContext bc) {

        return Database.getQueryLocator([
            SELECT Id
            FROM Sample_Request_Header__c
            WHERE SAP_status__c = 'Failed'
            AND Status_Code__c != '1'
            AND First_Failure_Time__c != null
            AND First_Failure_Time__c >= :DateTime.now().addHours(-RETRY_WINDOW_HOURS)
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {

        Set<Id> idsToRetry = new Set<Id>();

        for (SObject s : scope) {
            idsToRetry.add((Id) s.get('Id'));
        }

        if (idsToRetry.isEmpty()) {
            return;
        }

        /*
         * Automatic retry. Retry_Count__c is incremented
         * inside syncOrderDataSync for every attempt,
         * manual or automatic.
         */
        OrderSyncUpSap.syncOrderDataSync(idsToRetry);
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('OrderRetrySyncBatch run complete.');
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new OrderRetrySyncBatch(), RETRY_BATCH_SCOPE);
    }

    public static void scheduleEvery20Min() {

        for (CronTrigger ct : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'OrderRetrySync_Every20Min%'
        ]) {
            System.abortJob(ct.Id);
        }

        System.schedule('OrderRetrySync_Every20Min_00', '0 0 * * * ?', new OrderRetrySyncBatch());
        System.schedule('OrderRetrySync_Every20Min_20', '0 20 * * * ?', new OrderRetrySyncBatch());
        System.schedule('OrderRetrySync_Every20Min_40', '0 40 * * * ?', new OrderRetrySyncBatch());
    }
}
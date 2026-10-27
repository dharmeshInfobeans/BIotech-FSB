public class ZohoRefreshQueueable implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext qc) {

        ZohoRefreshService.refreshAccessToken();

    }
}
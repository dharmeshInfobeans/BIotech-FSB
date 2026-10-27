global class ZohoTokenScheduler implements Schedulable {

    global void execute(SchedulableContext sc) {

        System.enqueueJob(new ZohoRefreshQueueable());

    }
}
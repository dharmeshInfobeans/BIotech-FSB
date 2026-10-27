global class MarketXrayScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        MarketXrayBatch batch = new MarketXrayBatch();
        Database.executeBatch(batch, 50);
    }
}
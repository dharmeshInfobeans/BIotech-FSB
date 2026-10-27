public class ScheduleDeletionInactiveProductStock implements Schedulable {
	public void execute(SchedulableContext sc) {
        BatchDeletionInactiveProductStock batch = new BatchDeletionInactiveProductStock();
        Database.executeBatch(batch);
    }
}
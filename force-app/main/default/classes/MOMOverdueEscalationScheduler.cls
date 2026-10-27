public class MOMOverdueEscalationScheduler implements Schedulable {

    // Schedule with: System.schedule('MOM Overdue Escalation Daily', '0 0 8 * * ?', new MOMOverdueEscalationScheduler());
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new MOMOverdueEscalationBatch(), 200);
    }
}
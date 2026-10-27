global class ScheduleBatchAccountCISLocked implements Schedulable {
   global void execute(SchedulableContext SC) {
      BatchAccountCISLocked  b = new BatchAccountCISLocked(); 
      Database.executeBatch(b,50);
   }
}
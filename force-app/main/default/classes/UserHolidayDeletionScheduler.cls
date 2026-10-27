global class UserHolidayDeletionScheduler implements Schedulable {
   global void execute(SchedulableContext sc) {
      UserHolidayDeletionBatch b = new UserHolidayDeletionBatch(); 
      Database.executeBatch(b);
   }
}
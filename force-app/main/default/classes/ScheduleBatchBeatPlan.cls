global class ScheduleBatchBeatPlan implements Schedulable {
   global void execute(SchedulableContext sx){
       BatchCreateBeatPlan obj = new BatchCreateBeatPlan();
       database.executeBatch(obj);
   }
}
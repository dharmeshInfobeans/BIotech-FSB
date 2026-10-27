global class BatchDCRCallOutSchedule implements Schedulable{
    global void execute(SchedulableContext sx){
       BatchDCRCallOutClass obj = new BatchDCRCallOutClass();
       database.executeBatch(obj,1);
   }
}
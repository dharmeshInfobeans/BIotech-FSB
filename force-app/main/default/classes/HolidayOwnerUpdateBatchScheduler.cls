global class HolidayOwnerUpdateBatchScheduler implements Schedulable {
    
    global void execute(SchedulableContext sc) {
            HolidayOwnerUpdateBatch batch = new HolidayOwnerUpdateBatch();
            Database.executeBatch(batch, 200);
        }

}
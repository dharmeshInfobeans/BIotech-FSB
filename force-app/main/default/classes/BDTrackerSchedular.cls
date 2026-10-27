global class BDTrackerSchedular implements Schedulable {

    global void execute(SchedulableContext ctx) {
        BDTrackerBatch objBatch =new BDTrackerBatch();
        Database.executeBatch(objBatch,200);
    }
    
   /* public static void schedulaJob(){
        BDTrackerSchedular obj = new BDTrackerSchedular();
        string sch = '0 0 22 * * ? *';
        System.schedule('Execute Events', sch, obj);
    }*/
}
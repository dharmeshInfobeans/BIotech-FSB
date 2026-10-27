global class MARecResyncToSapSchedule implements Schedulable {
    global void execute(SchedulableContext SC) {
        MAFailRecResyncToSapBatch batch = new MAFailRecResyncToSapBatch();
        //size 1 so that we dont get error fo too many calllout
        Database.executeBatch(batch, 1);
        
    }
    /*
            String jobName = 'SAP_Retry_Every_4_Hours';
            
            String cronExp = '0 0 0,4,8,12,16,20 * * ?'; 
            Runs at 12AM, 4AM, 8AM, 12PM, 4PM, 8PM daily
            
            System.schedule(jobName, cronExp, new ScheduleSAPRetryBatch());
	*/
    

}
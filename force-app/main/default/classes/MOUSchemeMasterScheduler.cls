global without sharing class MOUSchemeMasterScheduler
    implements Schedulable {

    global void execute(SchedulableContext sc) {

        Integer yearVal = Date.today().year();

        // Create Date values
        Date fromDate = Date.newInstance(yearVal, 1, 1);
        Date toDate   = Date.newInstance(yearVal, 12, 31);

        // Convert to dd-MM-yyyy
        String startDate =
            String.valueOf(fromDate.day()).leftPad(2, '0') + '-' +
            String.valueOf(fromDate.month()).leftPad(2, '0') + '-' +
            fromDate.year();

        String endDate =
            String.valueOf(toDate.day()).leftPad(2, '0') + '-' +
            String.valueOf(toDate.month()).leftPad(2, '0') + '-' +
            toDate.year();

        System.debug('Start Date => ' + startDate); // 01-01-2025
        System.debug('End Date   => ' + endDate);   // 31-12-2025

        Database.executeBatch(
            new MOUSchemeMasterBatch(startDate, endDate),
            1
        );
    }
}
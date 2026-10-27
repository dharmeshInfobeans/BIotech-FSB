/********************************************
* @Class Name   : Batch_MonthlyIncentiveCalculation
* @Description  : This class is used to calculate monthly incentive
* @Created Date : 22-01-2020
* @Created By   : Pratiksha K. 
* ****************************************/
	
global class Batch_MonthlyIncentiveCalculation implements Database.Batchable<sObject>{
    global Date startDate, endDate, startDateForPaceSetter, endDateForPaceSetter;
    
    //Constructor with no arguments
    global Batch_MonthlyIncentiveCalculation() {
        startDate = System.today().addMonths(-4).toStartOfMonth();
        endDate = startDate.addMonths(1).toStartofMonth().addDays(-1);
        startDateForPaceSetter = System.today().addMonths(-1).toStartOfMonth();
        endDateForPaceSetter = startDateForPaceSetter.addMonths(1).toStartofMonth().addDays(-1);
    }
    
    // Constructor with one argument 
    global Batch_MonthlyIncentiveCalculation(Date fromDate, Date toDate) {
        startDate = fromDate;  
        endDate = toDate;
        startDateForPaceSetter = fromDate;
        endDateForPaceSetter = toDate;
    }
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator([Select Id,Execution_Order__c,Frequency__c,Region__c,Type__c,Last_Execution_Date__c,Next_Execution_Date__c From 
                                         Batch_Execution_Orders__c where Frequency__c = 'Monthly' /*And Type__c  = 'Consumable Incentive'*/
                                         order by Execution_Order__c ASC]);
    }
    
    global void execute(Database.BatchableContext BC, List<Batch_Execution_Orders__c> scope){
        String log;
        List<Batch_Execution_Orders__c> executionOrderLst = new List<Batch_Execution_Orders__c>();
        for(Batch_Execution_Orders__c batchDetails : scope){
            if(batchDetails.Type__c  == 'Consumable Incentive'){
                if(batchDetails.Region__c == 'Domestic'){
                    log = CalculateMonthlyIncentive.fetchConfigurationDetails(batchDetails.Region__c,startDate, endDate); 
                }
                /*else if(batchDetails.Region__c == 'International'){
                    log = CalculateMonthlyIncentive_International.fetchConfigurationDetailsForInternational(batchDetails.Region__c,startDate, endDate); 
                }*////commented on 20/5
                //else if for turkey
            }
            /*else if(batchDetails.Type__c  == 'Pace Setter'){
                log = CalculateMonthlyPaceSetterIncentive.fetchConfigurationDetails(batchDetails.Region__c,startDateForPaceSetter, endDateForPaceSetter); 
            }*///commented by pk on 5/6/20 for prod deployment
            if(log == 'error') {
                break;
            }
            /*else{
                continue;
            }*///commented on 20_4
            batchDetails.Last_Execution_Date__c = System.today();
            batchDetails.Next_Execution_Date__c = System.today().addMonths(1);
            executionOrderLst.add(batchDetails);
        }
        if(!executionOrderLst.isEmpty()){
            Update executionOrderLst;
        }
    }
    
    global void finish(Database.BatchableContext BC){
    }
}
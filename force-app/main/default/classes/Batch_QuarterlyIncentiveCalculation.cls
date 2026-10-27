/********************************************
* @Class Name   : Batch_QuarterlyIncentiveCalculation
* @Description  : This class is used to calculate quarterly incentive
* @Created Date : 23-01-2020
* @Created By   : Pratiksha K. 
* ****************************************/
global class Batch_QuarterlyIncentiveCalculation implements Database.Batchable<sObject>{
    global Date startDate, endDate, startDateForPaceSetter, endDateForPaceSetter;
	global Period period_obj, period_objForPaceSetter;
	    
    //Constructor with no arguments
    global Batch_QuarterlyIncentiveCalculation(){  
        period_obj = [Select Id,StartDate,EndDate from period where type = 'QUARTER' AND StartDate = LAST_N_FISCAL_QUARTERS:2 AND 
                      StartDate != LAST_QUARTER];
        period_objForPaceSetter = [Select Id,StartDate,EndDate from period where type = 'QUARTER' AND StartDate = LAST_N_FISCAL_QUARTERS:1];
        startDate  = period_obj.StartDate;
        endDate = period_obj.EndDate;
        startDateForPaceSetter = period_objForPaceSetter.StartDate;
        endDateForPaceSetter = period_objForPaceSetter.EndDate;
    }
    
    // Constructor with one argument 
    global Batch_QuarterlyIncentiveCalculation(Date fromDate, Date toDate) {
        startDate = fromDate;  
        endDate = toDate;
        startDateForPaceSetter = fromDate;
        endDateForPaceSetter = toDate;
    }
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator([Select Id,Execution_Order__c,Frequency__c,Region__c,Type__c,Last_Execution_Date__c,Next_Execution_Date__c From 
                                         Batch_Execution_Orders__c where Frequency__c = 'Quarterly' /*And Type__c  = 'Consumable Incentive'*/
                                         order by Execution_Order__c ASC]);
    }
    
    global void execute(Database.BatchableContext BC, List<Batch_Execution_Orders__c> scope){
        String log;
        List<Batch_Execution_Orders__c> executionOrderLst = new List<Batch_Execution_Orders__c>();
        for(Batch_Execution_Orders__c batchDetails : scope){
            if(batchDetails.Type__c  == 'Consumable Incentive'){
                if(batchDetails.Region__c == 'Domestic'){
                    log = CalculateQuarterlyIncentive.fetchConfigurationDetails(batchDetails.Region__c,startDate, endDate); 
                }
            }
            /*else if(batchDetails.Type__c  == 'Pace Setter'){
                log = CalculateQuarterlyPaceSetterIncentive.fetchConfigurationDetails(batchDetails.Region__c,startDateForPaceSetter, endDateForPaceSetter);  
            }*///commented by pk on 6/5/20 for prod deployment
            if(log == 'error') {
                break;
            }
            /*else{
                continue;
            }*///commented on 20/4/2020
            batchDetails.Last_Execution_Date__c = System.today();
            batchDetails.Next_Execution_Date__c = System.today().addMonths(3);
            executionOrderLst.add(batchDetails);
        }
        if(!executionOrderLst.isEmpty()){
            Update executionOrderLst;
        }
    }
    
    global void finish(Database.BatchableContext BC){
    }
}
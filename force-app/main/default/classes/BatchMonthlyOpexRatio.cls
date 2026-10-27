global class BatchMonthlyOpexRatio implements Database.Batchable<sObject>{
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator([Select Id,Quadrant__c,Role__c, Parameter__c,Financial_Year__c,Financial_Year__r.Start_Date__c,
                                         Financial_Year__r.End_Date__c,Product_1__c,Product_2__c,Division__c, 
                                         (select id,Points__c,KRA_Configuration__c,Achievement_to__c,Achievement_from__c 
                                          from KRA_Details__r) from KRA_Configuration__c where Parameter__c = 'Opex to Sales Ratio']);
    }
    //Operation Discpline(OT)
    global void execute(Database.BatchableContext BC, List<KRA_Configuration__c> scope){
        MonthlyOpexRatioCalculation monthlyopex = new MonthlyOpexRatioCalculation();
        monthlyopex.MonthlyOpexCalculation();
        
        //QuarterlyOTCalculation quatOT = new QuarterlyOTCalculation();
        // quatOT.QuarterlyOTCalculation();
    }
    
    global void finish(Database.BatchableContext BC){
        System.debug('In Opex to Sales Ratio batch finish method : ');
    }
    
}
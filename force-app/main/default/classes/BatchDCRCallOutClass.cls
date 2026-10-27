/************************************************************************************
Author : Prashant Rana
Description : This batch will call DCRCallOutClass to send data to external system
Date : 2019-04-10
************************************************************************************/
global class BatchDCRCallOutClass implements Database.Batchable<sobject>, Database.AllowsCallouts, Database.Stateful {
    
    global database.QueryLocator start(Database.BatchableContext bx){
        string status = 'Approved';
        string apiStatus = 'Success';
        string query = 'select subject,EndDateTime,Call_Type__c,UniqueId__c,Account__r.SAP_Code__c,Account__r.BillingCity, Status__c, StartDateTime,API_Status__c from event where Status__c = :status AND API_Status__c != : apiStatus';
        return database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext bx, list<Event> scope){
        try {
            System.debug('in DCR batch execute : '+scope);
            for(event obj : scope){
                DCRCallOutClass.doCallOut(obj);
            }
        } catch (Exception e) {
            System.debug('error in dcr batch : '+e.getMessage()+', At line no : '+e.getLineNumber());
        }
    }

    global void finish(Database.BatchableContext bx){
        System.debug('in DCR batch finish method : ');
    }
}
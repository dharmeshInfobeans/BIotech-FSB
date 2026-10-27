trigger APILogTrigger on API_Log__c (after insert) {
    DispatcherClass.run(new APILogTriggerHandler(), 'APILogTrigger'); 

}
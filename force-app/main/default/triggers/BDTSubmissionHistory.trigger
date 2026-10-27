trigger BDTSubmissionHistory on BDT_Submission_History__c (before insert, before update) {
    set<Id> ownerIds = new set<Id>();
    
    list<BDT_Submission_History__c> bdtHistory = new list<BDT_Submission_History__c>();
    map<Id, BDT_Submission_History__c> oldMap_BDTrackerSubmission = new map<Id, BDT_Submission_History__c>();
    for(BDT_Submission_History__c BDTHistoryNew :trigger.new){
       
       
        if(BDTHistoryNew.isSubmitted__c
           ||  BDTHistoryNew.Request_for_Reopen__c ){
               ownerIds.add(BDTHistoryNew.OwnerId);           
           }
     
    }
    
    system.debug('**ownerIds***'+ownerIds);
	if(ownerIds.size() > 0)
    	BDTrackerController.updateBDApproverOnUser(ownerIds);
}
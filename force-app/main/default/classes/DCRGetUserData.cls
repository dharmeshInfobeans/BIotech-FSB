global without sharing class DCRGetUserData {
	global static list<event> getUserData(string data){
        system.debug('parameter in user method : '+data);
        //  Id recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('DCR Planning').getrecordTypeId();
        list<event> eventList = new list<event>();
        try{
            eventList = [select id,follow_Up_Date__c,ActivityDate,startdateTime,DCR_Description__c,endDateTime,subject,toLabel(Product__c),Account__r.Name,Account__r.RecordType.DeveloperName,Event_Locked__c,
                         CE_Rating__c,CIS_Rating__C, toLabel(Status__c),toLabel(Stage__c),toLabel(Meeting_Type__c),Other_Type__c,Account__c,WhoId from event where OwnerId =:data 
                         /*AND recordtypeid=:recId*/];
        }catch(exception e){
            system.debug('error in getting user details : '+e.getMessage()+',at line no '+e.getLineNumber());
        }
        return eventList;
    }
}
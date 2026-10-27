public class HolidayTriggerHandler {
    
    
    public static void handleHolidayInsertOrUndelete(List<Holiday__c> holidayList){
        Set<String> setOfState = new Set<String>();
        Map<String,Set<Id>> mapOfObjectId=new Map<String,Set<Id>>{'Holiday'=> new Set<Id>()};
            for(Holiday__c holidayRecord : holidayList){
                if(holidayRecord.Country_State__c != NULL){
                    setOfState.add(holidayRecord.Country_State__c);
                    mapOfObjectId.get('Holiday').add(holidayRecord.Id);
                }
            }
        
        if(!mapOfObjectId.get('Holiday').isEmpty()){   Database.executeBatch(new HolidaySharingBatch(setOfState, mapOfObjectId, false)); }
    }
    
    public static void handleHolidayUpdate(Map<Id,Holiday__c> newholidayMap,Map<Id,Holiday__c> oldholidayMap){
        Set<String> setOfState = new Set<String>();
        Map<String,Set<Id>> mapOfObjectId=new Map<String,Set<Id>>{'Holiday'=> new Set<Id>()};
        Set<String> setOfStateToDelete = new Set<String>();
        Map<String,Set<Id>> mapOfObjectIdToDelete = new Map<String,Set<Id>>{'Holiday'=> new Set<Id>()};
            for(Id holidayId : newholidayMap.keySet()){
              /*
                if((newholidayMap.get(holidayId).Country__c != oldholidayMap.get(holidayId).Country__c) || (newholidayMap.get(holidayId).State__c != oldholidayMap.get(holidayId).State__c) ){
                    if(newholidayMap.get(holidayId).Country_State__c != NULL ){
                        setOfState.add(newholidayMap.get(holidayId).Country_State__c );
                        mapOfObjectId.get('Holiday').add(holidayId);
                    }
                    if(oldholidayMap.get(holidayId).State__c != NULL ){
                        setOfStateToDelete.add(oldholidayMap.get(holidayId).Country_State__c );
                        mapOfObjectIdToDelete.get('Holiday').add(holidayId);
                    }
                } 
					*/
                
                if( (newholidayMap.get(holidayId).Country__c!=null && newholidayMap.get(holidayId).Country__c!=oldholidayMap.get(holidayId).Country__c) ||  ( newholidayMap.get(holidayId).State__c!=null &&  newholidayMap.get(holidayId).State__c != oldholidayMap.get(holidayId).State__c)  ){
                      setOfState.add(newholidayMap.get(holidayId).Country_State__c );
                      mapOfObjectId.get('Holiday').add(holidayId);
                }
                
                if( (oldholidayMap.get(holidayId).Country__c!=null && newholidayMap.get(holidayId).Country__c!=oldholidayMap.get(holidayId).Country__c) ||  ( oldholidayMap.get(holidayId).State__c!=null &&  newholidayMap.get(holidayId).State__c != oldholidayMap.get(holidayId).State__c)  ){
                    setOfStateToDelete.add(oldholidayMap.get(holidayId).Country_State__c );
                    mapOfObjectIdToDelete.get('Holiday').add(holidayId);
                }
                
            }
        if(!mapOfObjectId.get('Holiday').isEmpty()){ Database.executeBatch(new HolidaySharingBatch(setOfState, mapOfObjectId, false)); }
        if(!mapOfObjectIdToDelete.get('Holiday').isEmpty()){ Database.executeBatch(new HolidaySharingBatch(setOfStateToDelete, mapOfObjectIdToDelete, true)); }
    }
}
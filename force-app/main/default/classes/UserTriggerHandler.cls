public class UserTriggerHandler {
    
    public static void handleUserInsert(List<User> userList){
        Set<String> setOfState = new Set<String>();
        Map<String,Set<Id>> mapOfObjectId=new Map<String,Set<Id>>{'User'=> new Set<Id>()};
            for(User userRecord : userList){
                if(userRecord.Country__c != null && (userRecord.Country__c != 'IN' || userRecord.State__c != null)){
                    setOfState.add(userRecord.Country_State__c);
                    mapOfObjectId.get('User').add(userRecord.Id);
                }
            }
        
        if(!mapOfObjectId.get('User').isEmpty()){ Database.executeBatch(new HolidaySharingBatch(setOfState, mapOfObjectId, false)); }
    }
    
    public static void handleUserUpdate(Map<Id,User> newUserMap , Map<Id,User> oldUserMap){
        Set<String> setOfState = new Set<String>();
        Map<String,Set<Id>> mapOfObjectId=new Map<String,Set<Id>>{'User'=> new Set<Id>()};
            Set<String> setOfStateToDelete = new Set<String>();
        Map<String,Set<Id>> mapOfObjectIdToDelete = new Map<String,Set<Id>>{'User'=> new Set<Id>()};
            for(Id userId : newUserMap.keySet()){
                /*     if((newUserMap.get(userId).Country__c != oldUserMap.get(userId).Country__c) || (newUserMap.get(userId).State__c != oldUserMap.get(userId).State__c)){
if(newUserMap.get(userId).State__c != NULL ){
setOfState.add(newUserMap.get(userId).State__c );
mapOfObjectId.get('User').add(userId);
}
if(oldUserMap.get(userId).State__c != NULL ){
setOfStateToDelete.add(oldUserMap.get(userId).State__c );
mapOfObjectIdToDelete.get('User').add(userId);
}
}
*/
                if( (newUserMap.get(userId).Country__c !=null && newUserMap.get(userId).Country__c != oldUserMap.get(userId).Country__c) || (newUserMap.get(userId).State__c !=null && newUserMap.get(userId).State__c != oldUserMap.get(userId).State__c)  ){
                    setOfState.add(newUserMap.get(userId).Country_State__c );
                    mapOfObjectId.get('User').add(userId);
                }
                if( (oldUserMap.get(userId).Country__c !=null && newUserMap.get(userId).Country__c != oldUserMap.get(userId).Country__c) || (oldUserMap.get(userId).State__c !=null && newUserMap.get(userId).State__c != oldUserMap.get(userId).State__c)  ){
                    setOfStateToDelete.add(oldUserMap.get(userId).Country_State__c );
                    mapOfObjectIdToDelete.get('User').add(userId);
                }
                
            }
        
        
        if(!mapOfObjectId.get('User').isEmpty()){ Database.executeBatch(new HolidaySharingBatch(setOfState, mapOfObjectId, false)); }
        if(!mapOfObjectIdToDelete.get('User').isEmpty()){ Database.executeBatch(new HolidaySharingBatch(setOfStateToDelete, mapOfObjectIdToDelete, true)); }
    }
    
}
public class HolidaySharingBatch implements Database.Batchable<Sobject> {
    
    Set<String> listOfState=new Set<String>();
    Map<String,Set<Id>> mapOfObjectId=new Map<String,Set<Id>>(); 
    Boolean isSharingDeleted;
    
    public HolidaySharingBatch(Set<String> listOfState,Map<String,Set<Id>> mapOfObjectId,Boolean isSharingDeleted ){
        this.listOfState=listOfState;
        this.mapOfObjectId=mapOfObjectId;
        this.isSharingDeleted=isSharingDeleted;
    }
    
    public Database.Querylocator start(Database.BatchableContext bc){
        
        System.debug('query: '+getDynamicQuery(listOfState,mapOfObjectId,isSharingDeleted));
        Set<Id> setOfIds=mapOfObjectId.containsKey('Holiday')? mapOfObjectId.get('Holiday'): mapOfObjectId.get('User');
        return Database.getQueryLocator(getDynamicQuery(listOfState,mapOfObjectId,isSharingDeleted));    
                                                                    }
    
    
    public void execute(Database.BatchableContext BC, List<sObject> scope){
        System.debug('scope '+scope);
        List<Holiday__Share> listOfHolidayShare = new List<Holiday__Share>();
        if(isSharingDeleted){
            System.debug('Deleting : ' + scope);
            delete scope;   }
        else{
            Map<String,Set<Id>> mapOfStateIds=new Map<String,Set<Id>>();
            if(mapOfObjectId.containsKey('Holiday')){
                mapOfStateIds=combineStateAndIds([Select id,State__c,Country_State__c from user where Country_State__c IN :listOfState AND IsActive =true AND Profile.UserType='Standard' ]);
                System.debug('mapOfStateIds '+mapOfStateIds);
                for(sObject sobj: scope)  {
                    System.debug('sobj.get(Id) '+sobj.get('Id'));
                    System.debug('String.valueOf '+String.valueOf(sobj.get('Country_State__c')));
                    if(mapOfStateIds.containsKey(String.valueOf(sobj.get('Country_State__c')))){ listOfHolidayShare.addAll(makeHolidaySharingRecord(String.valueOf(sobj.get('Id')),mapOfStateIds.get(String.valueOf(sobj.get('Country_State__c'))))); }
                }
            }
            else {
                mapOfStateIds=combineStateAndIds(scope);
                for(Holiday__c holiday:[Select id, State__c,Country_State__c,OwnerId  from Holiday__c where  Country_State__c IN : listOfState]){
                    System.debug('holiday.Id: '+holiday.Id+'--------------'+mapOfStateIds.get(holiday.Country_State__c));
                    if(mapOfStateIds.get(holiday.Country_State__c)!=null) {  listOfHolidayShare.addAll(makeHolidaySharingRecord(holiday.Id,mapOfStateIds.get(holiday.Country_State__c))) ;} 
                }
            }
        }
        System.debug('listOfHolidayShare: '+listOfHolidayShare);
        System.debug('size: '+listOfHolidayShare.size());
        try {
            if(!listOfHolidayShare.isEmpty()){
                List<Database.SaveResult> saveResults = Database.insert(listOfHolidayShare, false);
                for (Database.SaveResult sr : saveResults) {
                    if (sr.isSuccess()) {
                        System.debug('Successfully inserted account. Account ID: ' + sr.getId());
                    } else {
                        for (Database.Error err : sr.getErrors()) {   System.debug('Error: ' + err.getStatusCode() + ': ' + err.getMessage());  }
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
        }
        
        
    }
    
    public void finish(Database.BatchableContext BC){
        
        
    }
    
    public static List<Holiday__Share> makeHolidaySharingRecord(String scopeId, Set<id> setOfIds){
        System.debug('scopeId '+scopeId+'    setOfIds'+setOfIds );
        List<Holiday__Share> listOfHolidayShare=new List<Holiday__Share>();
        for(Id ids:setOfIds){  listOfHolidayShare.add(new Holiday__Share(AccessLevel = 'Read', RowCause =Schema.Holiday__Share.RowCause.Manual, ParentId=scopeId,UserOrGroupId=ids) );  }
        return listOfHolidayShare;
    }
    
    public static Map<String,Set<Id>> combineStateAndIds(List<User> listOfUsers){
        Map<String,Set<Id>> mapOfStateIds=new Map<String,Set<Id>>();
        for(User userObj: listOfUsers){
            if(!mapOfStateIds.containsKey(userObj.Country_State__c)){ mapOfStateIds.put(userObj.Country_State__c,new Set<Id>{userObj.Id}); }
            mapOfStateIds.get(userObj.Country_State__c).add(userObj.Id);
        }
        return mapOfStateIds; 
    } 
    
    
    public static String getDynamicQuery(Set<String> listOfState,Map<String,Set<Id>> mapOfObjectId,Boolean isSharingDeleted ){
        String query='';
        
        Set<Id> setOfIds=mapOfObjectId.containsKey('Holiday')? mapOfObjectId.get('Holiday'): mapOfObjectId.get('User');
        System.debug('setOfIds '+setOfIds+ ' : ' +listOfState);
        if(isSharingDeleted){
            if(mapOfObjectId.containsKey('Holiday')){  query='SELECT Id FROM Holiday__Share where RowCause =\'Manual\' AND UserOrGroupId IN (Select id from user where Country_State__c IN : listOfState ) AND ParentId IN:setOfIds '; }
            if(mapOfObjectId.containsKey('User')){  query='SELECT Id FROM Holiday__Share where RowCause =\'Manual\' AND ParentId IN (Select id from Holiday__c where Country_State__c IN : listOfState ) AND UserOrGroupId IN:setOfIds'; }
        }
        else{
            if(mapOfObjectId.containsKey('Holiday')){ query='Select id,State__c,Country_State__c,OwnerId  from Holiday__c where Id IN:setOfIds '; }
            if(mapOfObjectId.containsKey('User')){ query='Select id,State__c,Country_State__c from User where Id IN :setOfIds AND IsActive =true AND Profile.UserType=\'Standard\''; }
        }
        return query;
    }
    
    
}
global class HolidayOwnerUpdateBatch implements Database.Batchable<Sobject> {
    
    global Database.Querylocator start(Database.BatchableContext bc){
        return Database.getQueryLocator('SELECT Id, Name,ownerId, Country_State__c FROM Holiday__c WHERE Country_State__c != null');    
    }
    
    global void execute(Database.BatchableContext BC, List<Holiday__c> holidays){
        
        Set<String> stateKeys = new Set<String>();
        for (Holiday__c h : holidays) {
            if (h.Country_State__c != null) {
                stateKeys.add(h.Country_State__c);
            }
        }
        
        if (stateKeys.isEmpty()) return;
        
        Map<String, List<Id>> stateToUserMap = new Map<String, List<Id>>();
        for (User u : [SELECT Id, Country_State__c FROM User WHERE IsActive = true AND Country_State__c IN :stateKeys AND UserType NOT IN ('Guest', 'Partner')]) {
            if (u.Country_State__c != null) {
                if (!stateToUserMap.containsKey(u.Country_State__c)) {
                    stateToUserMap.put(u.Country_State__c, new List<Id>());
                }
                stateToUserMap.get(u.Country_State__c).add(u.Id);
            }
        }
        
        System.debug('stateToUserMap --> '+stateToUserMap);
        
        List<Holiday__Share> sharesToInsert = new List<Holiday__Share>();
        
        for (Holiday__c h : holidays) {
            if (stateToUserMap.containsKey(h.Country_State__c)) {
                
                for (Id userId : stateToUserMap.get(h.Country_State__c)) {
                    if(h.ownerId!=userId){
                        Holiday__Share hs = new Holiday__Share();
                        hs.ParentId = h.Id;
                        hs.UserOrGroupId = userId;
                        hs.AccessLevel = 'Read';
                        hs.RowCause =Schema.Holiday__Share.RowCause.Manual;
                        sharesToInsert.add(hs);
                    }
                }
            }
        }
        
        System.debug('sharesToInsert --> '+sharesToInsert);
        
        if (!sharesToInsert.isEmpty()) {
            try {
                insert sharesToInsert;
            } catch (Exception e) {
                System.debug('Error inserting sharing records: ' + e.getMessage());
            }
        }
    }
    
    global void finish(Database.BatchableContext BC){
        
        System.debug('Holiday Owner Update Batch Completed');
        
    }
    
   
    
    
    
}
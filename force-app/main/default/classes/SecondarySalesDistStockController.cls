public without sharing  class SecondarySalesDistStockController {

	@AuraEnabled
    public static List<Account> getAgreementProducts(Id recordId) {
		List<Account> listOfExistingProducts = new List<Account>();
        try{
            System.debug('recordId --> '+recordId);
            if(recordId == null){
            Id currentUserId = UserInfo.getUserId();
            System.debug('currentUserId------>>'+ currentUserId);
            List<User> users = [ SELECT Id, ContactId, Contact.AccountId FROM User WHERE Id = :currentUserId LIMIT 1 ];
            User currentUser = !users.isEmpty() ? users[0] : null;
			System.debug('currentUser------->>>>'+ currentUser);
            if (currentUser == null || currentUser.ContactId == null || currentUser.Contact.AccountId == null) {
                    throw new AuraHandledException('This user is not associated with a Contact.');
            }
			listOfExistingProducts = [SELECT Id, Name,(SELECT Id, Name,(SELECT Id, Name, Product__c, Product__r.Name FROM Agreement_Products__r)
                                       FROM Master_Agreements__r WHERE Is_Active__c = true)
                                       FROM Account WHERE Id = : currentUser.Contact.AccountId LIMIT 1];
			/*listOfExistingProducts = [SELECT Id, Name,(SELECT Id, Name,(SELECT Id, Name, Product__c, Product__r.Name FROM Agreement_Products__r)
                                       FROM Master_Agreements__r WHERE Is_Active__c = true)
                                       FROM Account];*/
            System.debug('listOfExistingProducts--->>>'+ listOfExistingProducts);
            }
            else{
                listOfExistingProducts = [SELECT Id, Name,(SELECT Id, Name,(SELECT Id, Name, Product__c, Product__r.Name FROM Agreement_Products__r)
                                       FROM Master_Agreements__r WHERE Is_Active__c = true)
                                       FROM Account WHERE Id = : recordId LIMIT 1];
            }
        }catch(Exception e){
            System.debug('Error in check secondary sales: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
        
        return listOfExistingProducts;
    }

	@AuraEnabled
    public static Map<String,Boolean> checkUserAccess(Id recordId){
        System.debug('recordId===>>'+ recordId);
        Id userId = UserInfo.getUserId();
        Map<String,Boolean> mapOfUserAccess = new Map<String,Boolean>{'Read'=>false,'Edit'=>false};
        
        if(recordId == null){
            mapOfUserAccess.put('Read', true);
            mapOfUserAccess.put('Edit', true);
            return mapOfUserAccess;
        }
        
        List<Account> accList = [SELECT CRM_Approver__c, RSM__c FROM Account WHERE Id =: recordId LIMIT 1];
        
        if(accList.isEmpty()){
            return mapOfUserAccess;
        }
        
        Account accRecord = accList[0];
        
        Map<Id,User> userMap = new Map<Id,User>([SELECT Id FROM User WHERE Id IN (SELECT UserOrGroupId FROM GroupMember 
                          						 WHERE Group.DeveloperName = 'Secondary_Sales_Access') AND IsActive = true]);
        
        if(userId == accRecord.CRM_Approver__c || userId == accRecord.RSM__c){ 
            mapOfUserAccess.put('Read', true);
            if(userId != accRecord.RSM__c){
                mapOfUserAccess.put('Edit', true);
            }  
        } else if(userMap.containsKey(userId)){
            mapOfUserAccess.put('Read', true);
        }
        
        System.debug('mapOfUserAccess===>>'+ mapOfUserAccess);
        return mapOfUserAccess;
    }

    /*@AuraEnabled
    public static Map<String,Boolean> checkUserAccess(Id recordId){
        System.debug('recordId===>>'+ recordId);
        Id userId = UserInfo.getUserId();
        Account accRecord = [SELECT CRM_Approver__c,RSM__c FROM Account WHERE Id =: recordId];
        Map<Id,User> userMap = new Map<Id,User>([SELECT Id, Name, Email, IsActive FROM User WHERE Id IN (SELECT UserOrGroupId FROM GroupMember WHERE Group.DeveloperName= 'Secondary_Sales_Access') AND IsActive = true]);
        Map<String,Boolean> mapOfUserAccess = new Map<String,Boolean>{'Read'=>false,'Edit'=>false};
        if(userId == accRecord.CRM_Approver__c || userId == accRecord.RSM__c){ 
            mapOfUserAccess.put('Read',true);
            mapOfUserAccess.put('Edit',true);
        }
        else{
            if(userMap.containsKey(userId)){
                mapOfUserAccess.put('Read',true);
            }
        }
		System.debug('mapOfUserAccess===>>'+ mapOfUserAccess);
        return mapOfUserAccess;
    }*/

	private static Id resolveAccountId(Id recordId) {
        if (recordId != null) return recordId;
        List<User> users = [SELECT Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        return (!users.isEmpty() && users[0].Contact != null) ? users[0].Contact.AccountId : null;
    }

	/*@AuraEnabled
    public static List<Secondary_Sales_Header__c> getInitialStock(){
        return [SELECT Id, Product__c, Initial_Stock__c, Allow_Initial_Stock_Edit__c FROM Secondary_Sales_Header__c WHERE Initial_Stock__c != NULL];
    }*/

	@AuraEnabled
    public static List<Secondary_Sales_Header__c> getInitialStock(Id recordId){
        Id accountId = resolveAccountId(recordId);
        if (accountId == null) return new List<Secondary_Sales_Header__c>();
        return [SELECT Id, Account__c, Product__c, Initial_Stock__c, Allow_Initial_Stock_Edit__c
                FROM Secondary_Sales_Header__c
                WHERE Initial_Stock__c != NULL AND Account__c = :accountId];
    }

	public class StockWrapper {
        @AuraEnabled public Id customerId {get; set;}
        @AuraEnabled public Id productId {get; set;}
        @AuraEnabled public Decimal initialStock {get; set;}
    }

	@AuraEnabled
    public static List<Secondary_Sales_Header__c> upsertInitialStock(List<StockWrapper> stockList) {
    
        System.debug('Incoming stockList => ' + stockList);
    
        List<Secondary_Sales_Header__c> processedRecords = new List<Secondary_Sales_Header__c>();
    
        if (stockList == null || stockList.isEmpty()) {
            return processedRecords;
        }
    
        Set<Id> customerIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
    
        for (StockWrapper sw : stockList) {
            if (sw.customerId != null && sw.productId != null) {
                customerIds.add(sw.customerId);
                productIds.add(sw.productId);
            }
        }
    
        Map<String, Secondary_Sales_Header__c> existingMap = new Map<String, Secondary_Sales_Header__c>();
    
        for (Secondary_Sales_Header__c header : [SELECT Id, Account__c, Product__c, Initial_Stock__c, Allow_Initial_Stock_Edit__c FROM Secondary_Sales_Header__c WHERE Account__c IN :customerIds AND Product__c IN :productIds]) {
            String key = header.Account__c + '-' + header.Product__c;
            existingMap.put(key, header);
        }
    
        List<Secondary_Sales_Header__c> toInsert = new List<Secondary_Sales_Header__c>();
        Map<Id, Secondary_Sales_Header__c> toUpdateMap = new Map<Id, Secondary_Sales_Header__c>();
    
        for (StockWrapper sw : stockList) {
    
            if (sw.customerId == null || sw.productId == null) continue;
    
            String key = sw.customerId + '-' + sw.productId;
    
            if (existingMap.containsKey(key)) {
    
                Secondary_Sales_Header__c existingRecord = existingMap.get(key);
                existingRecord.Initial_Stock__c = sw.initialStock;
                existingRecord.Allow_Initial_Stock_Edit__c = true;
    
                toUpdateMap.put(existingRecord.Id, existingRecord);
    
            } else {
    
                Secondary_Sales_Header__c newRecord = new Secondary_Sales_Header__c();
                newRecord.Account__c = sw.customerId;
                newRecord.Product__c = sw.productId;
                newRecord.Initial_Stock__c = sw.initialStock;
                newRecord.Allow_Initial_Stock_Edit__c = true;
    
                toInsert.add(newRecord);
            }
        }
    
        if (!toInsert.isEmpty()) {
            insert toInsert;
            processedRecords.addAll(toInsert);
        }
    
        if (!toUpdateMap.isEmpty()) {
            update toUpdateMap.values();
            processedRecords.addAll(toUpdateMap.values());
        }
    
        return processedRecords;
    }
}
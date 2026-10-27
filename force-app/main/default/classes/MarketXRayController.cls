/**
* @File Name : MarketXRayController.cls
* @Description :
* @Author : Shakib Khan
* @Last Modified By :
* @Last Modified On : November 3, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 3, 2025 |   | Initial Version
**/

public without sharing class MarketXRayController {

	@AuraEnabled
    public static Map<String,Boolean> checkUserAccess(Id recordId){
        Id userId = UserInfo.getUserId();
        Map<String,Boolean> mapOfUserAccess = new Map<String,Boolean>{'Read'=>false,'Edit'=>false};
    
        System.debug('LOGIN USER ID ===>> ' + userId);
        System.debug('recordId received ===>> ' + recordId);
    
        if(recordId == null){
            mapOfUserAccess.put('Read', true);
            mapOfUserAccess.put('Edit', true);
            return mapOfUserAccess;
        }
    
        List<Account> accList = [SELECT Id, CRM_Approver__c, RSM__c FROM Account WHERE Id =: recordId LIMIT 1];
        System.debug('accList size ===>> ' + accList.size());
    
        if(accList.isEmpty()){
            System.debug('NO ACCOUNT FOUND for recordId ===>> ' + recordId);
            return mapOfUserAccess;
        }
    
        Account accRecord = accList[0];
        System.debug('accRecord.CRM_Approver__c ===>> ' + accRecord.CRM_Approver__c);
        System.debug('accRecord.RSM__c ===>> ' + accRecord.RSM__c);
    
        Map<Id,User> userMap = new Map<Id,User>([SELECT Id FROM User WHERE Id IN (SELECT UserOrGroupId FROM GroupMember 
                                                  WHERE Group.DeveloperName = 'Market_Xray_Access') AND IsActive = true]);
        System.debug('Public Group user ids ===>> ' + userMap.keySet());
    
        if(userId == accRecord.CRM_Approver__c || userId == accRecord.RSM__c){ 
            mapOfUserAccess.put('Read', true);
            mapOfUserAccess.put('Edit', true);
        } else if(userMap.containsKey(userId)){
            mapOfUserAccess.put('Read', true);
        }
    
        System.debug('FINAL mapOfUserAccess ===>> ' + mapOfUserAccess);
        return mapOfUserAccess;
    }

	/*@AuraEnabled
    public static Map<String,Boolean> checkUserAccess(Id recordId){
        System.debug('recordId===>>'+ recordId);
        Id userId = UserInfo.getUserId();
        Map<String,Boolean> mapOfUserAccess = new Map<String,Boolean>{'Read'=>false,'Edit'=>false};
    
        if(recordId == null){
            mapOfUserAccess.put('Read', true);
            mapOfUserAccess.put('Edit', true);
            return mapOfUserAccess;
        }
    
        List<Account> accList = [SELECT Id, CRM_Approver__c, RSM__c FROM Account WHERE Id =: recordId LIMIT 1];
    
        if(accList.isEmpty()){
            return mapOfUserAccess;
        }
    
        Account accRecord = accList[0];
    
        Map<Id,User> userMap = new Map<Id,User>([SELECT Id FROM User WHERE Id IN (SELECT UserOrGroupId FROM GroupMember 
                                                  WHERE Group.DeveloperName = 'Market_Xray_Access') AND IsActive = true]);
    
        if(userId == accRecord.CRM_Approver__c || userId == accRecord.RSM__c){ 
            mapOfUserAccess.put('Read', true);
            mapOfUserAccess.put('Edit', true);
        } else if(userMap.containsKey(userId)){
            mapOfUserAccess.put('Read', true);
        }
    
        System.debug('mapOfUserAccess===>>'+ mapOfUserAccess);
        return mapOfUserAccess;
    }*/
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> checkExistingMarketXrayForm(String userId,Id recordId) {
        Map<String, Object> response = new Map<String, Object>();
        
        try {

            Id currentUserId = userId;//UserInfo.getUserId(); //'0056F00000EOhwBQAT';
            User recordPageUser = null;
            if(recordId != null){
                 recordPageUser = [select id from user where contactid in (select id from contact where AccountId  =: recordId)];
                currentUserId = recordPageUser.Id;
            }
            
            List<User> users = [SELECT Id, ContactId, Contact.AccountId, Contact.Create_New_Market_X_Ray_Version__c FROM User WHERE Id = :currentUserId LIMIT 1];
            
            User currentUser = !users.isEmpty() ? users[0] : null;
            
            if (currentUser == null || currentUser.ContactId == null) {
                throw new AuraHandledException('This user is not associated with a Contact.');
            }
            
            List<AggregateResult> aggregateList = [SELECT count(Id) totalCount FROM Market_X_Ray_Form__c WHERE Account__c=:currentUser.Contact.AccountId GROUP BY Account__c];
            if(!aggregateList.isEmpty()){
                AggregateResult agr = aggregateList[0];
                
                String versionName = 'V'+Integer.valueOf(agr.get('totalCount'));
                
                // Check if form already exists
                List<Market_X_Ray_Form__c> existingForms = [
                    SELECT Id, IsMarketXrayFormEditable__c,
                    (SELECT Id, Total_Population_In_Millions__c, 
                     Avarage_age_of_population__c,
                     Number_of_cataract_IOLs_implanted_per_yr__c, 
                     Number_of_Cataract_Surgeons__c, 
                     Number_of_Phakic_IOLs_Implanted_per_Year__c,
                     CheckMarketXrayEditOrNot__c,
                     Reimbursement_Situation_Value__c,
                     (SELECT Id, Brand_Name__c, Annual_Sales_in_Qty__c, 
                      Name_of_Distributor_Selling_This_Brand__c, 
                      Percentage_Share__c, Category__c 
                      FROM Brand_Market_Shares__r),
                     (SELECT Id, Hospital_Center_Name__c, Category__c 
                      FROM Market_Key_Accounts__r) 
                     FROM Market_X_Rays__r
                     ORDER BY CreatedDate DESC
                     LIMIT 1) 
                    FROM Market_X_Ray_Form__c
                    WHERE Contact__c = :currentUser.ContactId AND Version__c =:versionName
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                
                System.debug('existingForms record in get method: ' + existingForms);
                
                Boolean shouldCreateNewVersion = currentUser.Contact.Create_New_Market_X_Ray_Version__c;
                
                if(shouldCreateNewVersion && existingForms[0].IsMarketXrayFormEditable__c == true){
                    response.put('exists', false);
                    response.put('createNewVersion', true);
                    response.put('message', 'Admin has enabled new version creation. Form will be blank.');
                    System.debug('New version requested by Admin for Contact: ' + currentUser.ContactId);
                    return response;
                }
                
                if (!existingForms.isEmpty() && !existingForms[0].Market_X_Rays__r.isEmpty()) {
                    response.put('exists', true);
                    response.put('data', existingForms[0]);
                    //response.put('data', existingForms[0].Market_X_Rays__r[0]);
                } else {
                    response.put('exists', false);
                }
            }else {
                response.put('exists', false);
            }
        } catch (Exception e) {
            System.debug('Error in checkExistingMarketXrayForm: 2 ' + e.getStackTraceString());
            System.debug('Error in checkExistingMarketXrayForm: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
        
        return response;
    }
    
    @AuraEnabled
    public static String saveMarketXrayData(String marketXrayData,Id recordId) {
        
        try {
            System.debug('marketXrayData=====>>>' + marketXrayData);
            
            Id currentUserId = UserInfo.getUserId();
            User recordPageUser = null;
            if(recordId != null){
                 recordPageUser = [select id from user where contactid in (select id from contact where AccountId  =: recordId)];
                currentUserId = recordPageUser.Id;
            }
            
            
            List<User> users = [SELECT Id, ContactId, Contact.AccountId, Contact.Create_New_Market_X_Ray_Version__c FROM User WHERE Id = :currentUserId LIMIT 1];
            
            User currentUser = !users.isEmpty() ? users[0] : null;
            System.debug('currentUser=====>>>' + currentUser);
            
            // Check if user is a community user
            if(currentUser == null || currentUser.ContactId == null) {
                System.debug('User not associated with Contact');
                throw new AuraHandledException('This user is not associated with a Contact. Please use an Experience Cloud user.');
            }
            
            // Deserialize data
            Map<String,Object> marketXraySerializeData = (Map<String, Object>) JSON.deserializeUntyped(marketXrayData);
            
            Map<String, Object> marketXray = (Map<String, Object>) marketXraySerializeData.get('markeyXray');
            System.debug('marketXray after serialize data======>>>>' + marketXray);
            List<Object> monofocals = (List<Object>) marketXraySerializeData.get('monofocals');
            List<Object> presbyopia = (List<Object>) marketXraySerializeData.get('presbyopia');
            List<Object> brandMonofocals = (List<Object>) marketXraySerializeData.get('brandMonofocals');
            List<Object> brandPresbyopia = (List<Object>) marketXraySerializeData.get('brandPresbyopia');
            
            // Get or Create Market X-Ray Form
            Market_X_Ray_Form__c marketXrayFormRecord;
            List<Market_X_Ray_Form__c> existingForms = [SELECT Id, Account__c, Contact__c FROM Market_X_Ray_Form__c WHERE Contact__c = :currentUser.ContactId ORDER BY CreatedDate DESC LIMIT 1];
            System.debug('existingForms >>> ' + existingForms);
            
            if (!existingForms.isEmpty() && !currentUser.Contact.Create_New_Market_X_Ray_Version__c) {
                marketXrayFormRecord = existingForms[0];
                System.debug('Updating existing Form >>> ' + marketXrayFormRecord.Id);
            } else {
                marketXrayFormRecord = new Market_X_Ray_Form__c();
                marketXrayFormRecord.Account__c = currentUser.Contact.AccountId;
                marketXrayFormRecord.Contact__c = currentUser.ContactId;
                System.debug('Creating NEW Form');
            }
            
            /*marketXrayFormRecord = new Market_X_Ray_Form__c();
marketXrayFormRecord.Account__c = currentUser.Contact.AccountId;
marketXrayFormRecord.Contact__c = currentUser.ContactId;
System.debug('Creating NEW Form');*/
            
            UPSERT marketXrayFormRecord;
            System.debug('after upsert marketXrayFormRecord ======>>>>' + marketXrayFormRecord.Id);
            
            if(currentUser.ContactId != null){
                Contact conRec = new Contact();
                conRec.Id = currentUser.ContactId;
                conRec.Create_New_Market_X_Ray_Version__c = false;
                UPDATE conRec;
            }
            
            // Get or Create Market X-ray record
            Market_X_ray__c mx;
            String marketXrayId = getStringValue(marketXray.get('id'));
            
            if(String.isNotBlank(marketXrayId)) {
                List<Market_X_ray__c> existingMx = [SELECT Id FROM Market_X_ray__c WHERE Id = :marketXrayId LIMIT 1];
                if(!existingMx.isEmpty()) {
                    mx = existingMx[0];
                    System.debug('Updating existing Market X-ray >>> ' + mx.Id);
                } else {
                    mx = new Market_X_ray__c();
                    System.debug('Creating NEW Market X-ray');
                }
            } else {
                mx = new Market_X_ray__c();
                System.debug('Creating NEW Market X-ray');
            }
            
            // Use helper methods for safe type conversion
            mx.Total_Population_In_Millions__c = getDecimalValue(marketXray.get('totalPopulation'));
            mx.Avarage_age_of_population__c = getDecimalValue(marketXray.get('averageAgePopulation'));
            mx.Number_of_cataract_IOLs_implanted_per_yr__c = getDecimalValue(marketXray.get('cataractIOLsImplantedYear'));
            mx.Number_of_Cataract_Surgeons__c = getDecimalValue(marketXray.get('numberOfCataractSurgeons'));
            mx.Number_of_Phakic_IOLs_Implanted_per_Year__c = getDecimalValue(marketXray.get('phakicIOLsImplantedYear'));
            mx.Reimbursement_Situation_Value__c = getStringValue(marketXray.get('reimbursementSitutionAndValue'));
            //mx.CheckMarketXrayEditOrNot__c = getBooleanValue(marketXray.get('checkMarketXrayEditOrNot'));
            //mx.Market_X_Ray_Form__c = marketXrayFormRecord.Id;
            if(mx.Id == null) {
                mx.Market_X_Ray_Form__c = marketXrayFormRecord.Id;
            }
            
            System.debug('mx=============>>>' + mx);
            UPSERT mx;
            System.debug('after mx upsert =============>>>' + mx);
            System.debug('mx Id =============>>>' + mx.Id);
            
            // Delete old Brand Market Shares if updating
            if(String.isNotBlank(marketXrayId)) {
                List<Brand_Market_Share__c> oldBrands = [SELECT Id FROM Brand_Market_Share__c WHERE Market_X_ray__c = :mx.Id];
                if(!oldBrands.isEmpty()) {
                    DELETE oldBrands;
                    System.debug('Deleted old brand records: ' + oldBrands.size());
                }
            }
            
            // Insert Brand Tables (Monofocals & Presbyopia)
            List<Brand_Market_Share__c> brandList = new List<Brand_Market_Share__c>();
            
            for (Object obj : brandMonofocals) {
                Map<String, Object> rec = (Map<String, Object>) obj;
                if(rec.get('brandName') != null || rec.get('annualSales') != null || 
                   rec.get('distributor') != null || rec.get('percentageShare') != null) {
                       Brand_Market_Share__c b = new Brand_Market_Share__c();
                       b.Market_X_ray__c = mx.Id;
                       b.Category__c = 'Monofocal';
                       b.Annual_Sales_in_Qty__c = getDecimalValue(rec.get('annualSales'));
                       b.Name_of_Distributor_Selling_This_Brand__c = getStringValue(rec.get('distributor'));
                       b.Percentage_Share__c = getDecimalValue(rec.get('percentageShare'));
                       b.Brand_Name__c = getStringValue(rec.get('brandName'));
                       brandList.add(b);
                   }
            }
            
            for (Object obj : brandPresbyopia) {
                Map<String, Object> rec = (Map<String, Object>) obj;
                if(rec.get('brandName') != null || rec.get('annualSales') != null || 
                   rec.get('distributor') != null || rec.get('percentageShare') != null) {
                       Brand_Market_Share__c b = new Brand_Market_Share__c();
                       b.Market_X_ray__c = mx.Id;
                       b.Category__c = 'Presbyopia';
                       b.Annual_Sales_in_Qty__c = getDecimalValue(rec.get('annualSales'));
                       b.Name_of_Distributor_Selling_This_Brand__c = getStringValue(rec.get('distributor'));
                       b.Percentage_Share__c = getDecimalValue(rec.get('percentageShare'));
                       b.Brand_Name__c = getStringValue(rec.get('brandName'));
                       brandList.add(b);
                   }
            }
            
            System.debug('Final brandlist =======>>>>' + brandList);
            if(!brandList.isEmpty()) {
                INSERT brandList;
                System.debug('after insert brandList====>' + brandList);
            }
            
            // Delete old Key Accounts if updating
            if(String.isNotBlank(marketXrayId)) {
                List<Market_Key_Account__c> oldAccounts = [
                    SELECT Id 
                    FROM Market_Key_Account__c 
                    WHERE Market_X_ray__c = :mx.Id
                ];
                if(!oldAccounts.isEmpty()) {
                    DELETE oldAccounts;
                    System.debug('Deleted old key account records: ' + oldAccounts.size());
                }
            }
            
            // Insert Key Accounts
            List<Market_Key_Account__c> keyAccountsToInsert = new List<Market_Key_Account__c>();
            
            for (Object obj : monofocals) {
                Map<String, Object> rec = (Map<String, Object>) obj;
                String hospitalName = getStringValue(rec.get('MonofocalHospitalCenterName'));
                if(String.isNotBlank(hospitalName)) {
                    Market_Key_Account__c keyAccount = new Market_Key_Account__c();
                    keyAccount.Market_X_ray__c = mx.Id;
                    keyAccount.Hospital_Center_Name__c = hospitalName;
                    keyAccount.Category__c = getStringValue(rec.get('category'));
                    keyAccountsToInsert.add(keyAccount);
                }
            }
            
            for (Object obj : presbyopia) {
                Map<String, Object> rec = (Map<String, Object>) obj;
                String hospitalName = getStringValue(rec.get('PresbyopiaHospitalCenterName'));
                if(String.isNotBlank(hospitalName)) {
                    Market_Key_Account__c keyAccount = new Market_Key_Account__c();
                    keyAccount.Market_X_ray__c = mx.Id;
                    keyAccount.Hospital_Center_Name__c = hospitalName;
                    keyAccount.Category__c = getStringValue(rec.get('category'));
                    keyAccountsToInsert.add(keyAccount);
                }
            }
            
            if(!keyAccountsToInsert.isEmpty()) {
                INSERT keyAccountsToInsert;
                System.debug('Inserted key accounts: ' + keyAccountsToInsert.size());
            }
            
            return 'Market Xray data saved successfully with ID: ' + marketXrayFormRecord.Id;
            
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error while saving data: ' + e.getMessage());
        }
    }
    
    // Helper method to safely convert Object to Decimal
    private static Decimal getDecimalValue(Object value) {
        if(value == null) {
            return null;
        }
        
        if(value instanceof Decimal) {
            return (Decimal) value;
        } else if(value instanceof Integer) {
            return Decimal.valueOf((Integer) value);
        } else if(value instanceof String) {
            String strValue = (String) value;
            return String.isNotBlank(strValue) ? Decimal.valueOf(strValue) : null;
        }
        
        return null;
    }
    
    // Helper method to safely convert Object to Boolean
    private static Boolean getBooleanValue(Object value) {
        if(value == null) {
            return false; // or null, depending on your requirement
        }
        
        if(value instanceof Boolean) {
            return (Boolean) value;
        } else if(value instanceof String) {
            String strValue = ((String) value).toLowerCase();
            return strValue == 'true' || strValue == '1';
        } else if(value instanceof Integer) {
            return (Integer) value == 1;
        }
        
        return false;
    }
    
    // Helper method to safely convert Object to String
    private static String getStringValue(Object value) {
        if(value == null) {
            return null;
        }
        
        if(value instanceof String) {
            String strValue = (String) value;
            return String.isNotBlank(strValue) ? strValue : null;
        } else {
            return String.valueOf(value);
        }
    }
    
    @AuraEnabled
    public static String retUserId(String userId){
        
        if(Auth.CommunitiesUtil.isGuestUser()){
            userId = userId != NULL ? userId : '';
        }else{
            userId = UserInfo.getUserId();
        }
        
        return userId;
    }
}
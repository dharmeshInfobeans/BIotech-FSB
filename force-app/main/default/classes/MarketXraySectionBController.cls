public without sharing class MarketXraySectionBController {

	    @AuraEnabled(cacheable=true)
        public static Map<String, Object> checkExistingMarketXrayFormSectionB(String userId,Id recordId){
            
            Map<String, Object> response = new Map<String, Object>();
        
           try { 
                Id currentUserId =  userId;//UserInfo.getUserId();  //'0056F00000EOhwBQAT';
                User recordPageUser = null;
            if(recordId != null){
                System.debug('before recordPageUser');
                 recordPageUser = [select id from user where contactid in (select id from contact where AccountId  =: recordId)];
                  System.debug('After recordPageUser');
                currentUserId = recordPageUser.Id;
            }
                User currentUser = [SELECT Id, ContactId, Contact.AccountId, Contact.Create_New_Market_X_Ray_Version__c FROM User WHERE Id = :currentUserId LIMIT 1 ]??null;
        		System.debug('currentUser'+currentUser+'currentUser.con'+currentUser?.ContactId);
                if (currentUser?.ContactId == null) {
                    throw new AuraHandledException('This user is not associated with a Contact.');
                }
               
                List<AggregateResult> aggregateList = [SELECT count(Id) totalCount FROM Market_X_Ray_Form__c WHERE Account__c=:currentUser.Contact.AccountId GROUP BY Account__c];
				System.debug('aggregate without if >>');
               if(!aggregateList.isEmpty()){
                   
                   System.debug('versioning name >> before');
                   
                   AggregateResult agr = aggregateList[0];
                   String versionName = 'V'+Integer.valueOf(agr.get('totalCount'));
                   
                   System.debug('versioning name >> '+versionName);
                   
                   List<Market_X_Ray_Form__c> existingForms = [SELECT Id, Market_X_Ray_Form_URL__c, IsMarketXrayFormEditable__c,
                                                               (
                                                                   SELECT Id,
                                                                   From_India_IOLs__c,
                                                                   From_India_Pharma__c,
                                                                   From_India_Solutions__c,
                                                                   From_Ireland_IOLs__c,
                                                                   From_Ireland_Pharma__c,
                                                                   From_Ireland_Solutions__c,
                                                                   Other_Charges__c,
                                                                   (
                                                                       SELECT Id,
                                                                       Brand_Name__c,
                                                                       Division__c,
                                                                       Category__c,
                                                                       Price_For_Retail__c,
                                                                       Price_Key_Account__c,
                                                                       Total_Package__c,
                                                                       End_User_Price_by_Distributor_to_Doctor__c,
                                                                       Product__c,
                                                                       Agreement_Product__c,
                                                                       Distributor__c,
                                                                       Distributor__r.Name
                                                                       FROM DistributorLineItems__r
                                                                   )
                                                                   FROM Customs_Clearance_Charges__r
                                                               )
                                                               
                                                               FROM Market_X_Ray_Form__c 
                                                               WHERE Contact__c = :currentUser.ContactId AND Version__c =:versionName
                                                               ORDER BY CreatedDate DESC
                                                               LIMIT 1
                                                              ]??Null;
                   
                   System.debug('existingForms: ' + existingForms);
                   //List<String> listOfst=new List<String>{existingForms[0].Id};
                   //MarketXrayFormEmailNotificationApprover.getPendingWorkitems(listOfst);
                   //System.debug('MarketXrayFormEmailNotificationApprover.getPendingWorkitems(listOfst);' + MarketXrayFormEmailNotificationApprover.getPendingWorkitems(listOfst));
                   
                   
                   
                   Boolean shouldCreateNewVersion = currentUser.Contact.Create_New_Market_X_Ray_Version__c;
                   
                   if(shouldCreateNewVersion && existingForms[0].IsMarketXrayFormEditable__c == true){
                       response.put('exists', false);
                       response.put('createNewVersion', true);
                       response.put('message', 'Admin has enabled new version creation. Form will be blank.');
                       
                       System.debug('New version requested by Admin for Contact: ' + currentUser.ContactId);
                       return response;
                   }
                   
                   if (!existingForms.isEmpty() && !existingForms[0].Customs_Clearance_Charges__r.isEmpty()) {
                       response.put('exists', true);
                       response.put('data', existingForms[0]);
                   } else {
                       response.put('exists', false);
                   }
                   
               }
        
             } catch (Exception e) {
                System.debug('Error in checkExistingMarketXrayFormSectionB: ' + e.getMessage());
                 throw new AuraHandledException(e.getMessage());
            }
        
            return response;
        }

	@AuraEnabled(cacheable=true)
    public static List<Distributor__c> getDistributorsForCurrentUser(String userId, Id recordId) {
    
        Account acc;
    
        // 1. Community user case — Contact se Account nikaalo
        User u = [SELECT Id, ContactId FROM User WHERE Id = :userId];
    
        if (u.ContactId != null) {
            Contact c = [SELECT Id, AccountId FROM Contact WHERE Id = :u.ContactId];
            if (c.AccountId == null) {
                return new List<Distributor__c>();
            }
            acc = [SELECT Id, Country_Key__c, BillingCountry FROM Account WHERE Id = :c.AccountId];
    
        } else if (recordId != null) {
            // 2. Internal user, Account record page — recordId khud Account Id hai
            acc = [SELECT Id, Country_Key__c, BillingCountry FROM Account WHERE Id = :recordId];
    
        } else {
            return new List<Distributor__c>();
        }
    
        if (acc == null || String.isBlank(acc.Country_Key__c)) {
            return new List<Distributor__c>();
        }
    
        // 3. Return distributors in that country
        List<Distributor__c> listOfDistributer = [SELECT Id, Name, Address_Country__c FROM Distributor__c WHERE Address_Country__c = :acc.BillingCountry 
            ORDER BY Name];
    
        system.debug(listOfDistributer);
        return listOfDistributer;
    }
    
    /*@AuraEnabled(cacheable=true)
    public static List<Distributor__c> getDistributorsForCurrentUser(String userId) {

        // 1. Get current user and its Contact
        User u = [SELECT Id, ContactId FROM User WHERE Id = :userId];
        
        if (u.ContactId == null) {
            return new List<Distributor__c>();
        }
        
        // 2. Get Contact's Account
        Contact c = [SELECT Id, AccountId FROM Contact WHERE Id = :u.ContactId];
        
        if (c.AccountId == null) {
            return new List<Distributor__c>();
        }
        
        // 3. Get Account's country
        Account acc = [SELECT Id, Country_Key__c, BillingCountry FROM Account WHERE Id = :c.AccountId];
        
        if (String.isBlank(acc.Country_Key__c)) {
            return new List<Distributor__c>();
        }
        
        // 4. Return distributors in that country
        list<Distributor__c> listOfDistributer = [ SELECT Id, Name, Address_Country__c FROM Distributor__c WHERE Address_Country__c  = :acc.BillingCountry ORDER BY Name];
        
        system.debug(listOfDistributer);
        return listOfDistributer;
    }*/

    @AuraEnabled(cacheable=true)
    public static Product__c getProductForDistributor(Id distributorId) {
        if (distributorId == null) return null;
        
        Distributor__c dist = [
            SELECT Id, Name, Product__c,
            Product__r.Division__c,
            Product__r.Category__c,
            Product__r.Name
            FROM Distributor__c
            WHERE Id = :distributorId
            LIMIT 1
        ];
        
        return dist.Product__r;
    }

	@AuraEnabled(cacheable=true)
    public static List<Account> fetchMaterAgreementAllRelatedProducts(String userId, Id recordId) {
        List<Account> listOfExistingProducts = new List<Account>();
        try {
            Id accountId;
    
            List<User> users = [ SELECT Id, ContactId, Contact.AccountId FROM User WHERE Id = :userId LIMIT 1 ];
            User currentUser = !users.isEmpty() ? users[0] : null;
    
            if (currentUser != null && currentUser.ContactId != null && currentUser.Contact.AccountId != null) {
                // Community user
                accountId = currentUser.Contact.AccountId;
            } else if (recordId != null) {
                // Internal user, Account record page — recordId khud Account Id hai
                accountId = recordId;
            } else {
                throw new AuraHandledException('Unable to determine Account context.');
            }
    
            listOfExistingProducts = [
                SELECT Id, (
                    SELECT Id, Is_Active__c, (
                        SELECT Id, inMarketXRay__c, Price__c, FOC_Text__c, Product__c, 
                               Product__r.Division__c, Product__r.Category__c, Product__r.Name 
                        FROM Agreement_Products__r 
                        WHERE inMarketXRay__c = TRUE
                    ) 
                    FROM Master_Agreements__r 
                    WHERE Is_Active__c = true AND RecordType.DeveloperName = 'Ophthalmic'
                ) 
                FROM Account 
                WHERE Id = :accountId
            ];
            System.debug('listOfExistingProducts=====>>>' + listOfExistingProducts);
    
        } catch (Exception e) {
            System.debug('Error in fetchMaterAgreementAllRelatedProducts: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    
        return listOfExistingProducts;
    }    
    /*@AuraEnabled(cacheable=true)
    public static List<Account> fetchMaterAgreementAllRelatedProducts(String userId){
        List<Account> listOfExistingProducts = new List<Account>();
        try{
            Id currentUserId = userId;
            List<User> users = [ SELECT Id, ContactId, Contact.AccountId FROM User WHERE Id = :currentUserId LIMIT 1 ];
            
            User currentUser = !users.isEmpty() ? users[0] : null;
            
            if (currentUser == null || currentUser.ContactId == null || currentUser.Contact.AccountId == null) {
                throw new AuraHandledException('This user is not associated with a Contact.');
            }
            
            listOfExistingProducts = [SELECT Id, (SELECT Id, Is_Active__c, (SELECT Id, inMarketXRay__c,Price__c, FOC_Text__c, Product__c, Product__r.Division__c, Product__r.Category__c, Product__r.Name FROM Agreement_Products__r WHERE inMarketXRay__c = TRUE) FROM Master_Agreements__r where Is_Active__c = true ) FROM Account where id =: currentUser.Contact.AccountId];
            System.debug('listOfExistingProducts=====>>>'+ listOfExistingProducts);
            
        }catch(Exception e){
            System.debug('Error in checkExistingMarketXrayForm: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
        
        return listOfExistingProducts;
    }*/
    
    
    /*@AuraEnabled(cacheable=true)
    public static List<Product__c> fetchAllProducts() {
        //List<Product__c> products = [ SELECT Id, Name, Division__c, Category__c FROM Product__c WHERE Active__c = TRUE];
        //List<Product__c> products = [SELECT Id , Name, Division__c , Category__c ,Active__c FROM Product__c LIMIT 10];
        Id currentUserId = UserInfo.getUserId();
        List<User> users = [ SELECT Id, ContactId, Contact.AccountId FROM User WHERE Id = :currentUserId LIMIT 1 ];
            
        User currentUser = !users.isEmpty() ? users[0] : null;
            
        if (currentUser == null || currentUser.ContactId == null || currentUser.Contact.AccountId == null) {
            throw new AuraHandledException('This user is not associated with a Contact.');
        }

        Account accRec = [SELECT Id, BillingCountry FROM Account WHERE Id =: currentUser.Contact.AccountId];

		List<Product__c> products = [SELECT Id , Name, Region__c, Division__c , Category__c ,Active__c FROM Product__c WHERE Region__c = : accRec.BillingCountry AND IncludeInAgreement__c = : true];
        return products;
    }*/

	@AuraEnabled(cacheable=true)
    public static List<Product__c> fetchAllProducts(String userId, Id recordId) {
        System.debug('userId--->>'+ userId);
		System.debug('recordId------>>>>'+ recordId);
        Id accountId;
    
        List<User> users = [ SELECT Id, ContactId, Contact.AccountId FROM User WHERE Id = :userId LIMIT 1 ];
        User currentUser = !users.isEmpty() ? users[0] : null;
    
        if (currentUser != null && currentUser.ContactId != null && currentUser.Contact.AccountId != null) {
            // Community user
            accountId = currentUser.Contact.AccountId;
        } else if (recordId != null) {
            // Internal user, Account record page
            accountId = recordId;
        } else {
            throw new AuraHandledException('Unable to determine Account context.');
        }
    
        Account accRec = [SELECT Id, BillingCountry FROM Account WHERE Id = :accountId];
    
        List<Product__c> products = [
            SELECT Id, Name, Region__c, Division__c, Category__c, Active__c 
            FROM Product__c 
            WHERE Region__c = :accRec.BillingCountry AND IncludeInAgreement__c = true
        ];
		System.debug('products------>>>>'+ products);
        return products;
    }
    
    
    @AuraEnabled
    public static String saveCustomClearanceCharges(String customClearance,Id recordId) {
        try {
            System.debug('customClearance>>> ' + customClearance);
            
            User currentUser = null;
            if(recordId != null){
                 currentUser = [select id, ContactId, Contact.AccountId, Contact.Create_New_Market_X_Ray_Version__c from user where contactid in (select id from contact where AccountId  =: recordId) LIMIT 1];
                
            }
            else{
               currentUser= [SELECT Id, ContactId, Contact.AccountId, Contact.Create_New_Market_X_Ray_Version__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            }
            if (currentUser.ContactId == null) {
                throw new AuraHandledException('This user is not associated with a Contact.');
            }

			Map<String, Object> customClearanceData = (Map<String, Object>) JSON.deserializeUntyped(customClearance);
            Map<String, Object> clearanceFields = (Map<String, Object>) customClearanceData.get('customClearance');
            List<Object> distributorData = (List<Object>) customClearanceData.get('distributorLineItem');
            
            Market_X_Ray_Form__c form;
            List<Market_X_Ray_Form__c> existingForms = [SELECT Id, Account__c, Contact__c FROM Market_X_Ray_Form__c WHERE Contact__c = :currentUser.ContactId ORDER BY CreatedDate DESC LIMIT 1];
            System.debug('existingForms ----> ' + existingForms);
            
            if (!existingForms.isEmpty() && !currentUser.Contact.Create_New_Market_X_Ray_Version__c) {
                form = existingForms[0];
                form.IsMarketXrayFormEditable__c = getBooleanValue(clearanceFields.get('marketXrayFormEditOrNot'));
				form.Market_X_Ray_Form_URL__c = String.valueOf(clearanceFields.get('currentFormUrl'));
				UPSERT form;
				System.debug('Found existing Form >>> ' + form);
                System.debug('Found existing Form >>> ' + form.Id);
            } else {
                form = new Market_X_Ray_Form__c();
                form.Account__c = currentUser.Contact.AccountId;
                form.Contact__c = currentUser.ContactId;
				form.IsMarketXrayFormEditable__c = getBooleanValue(clearanceFields.get('marketXrayFormEditOrNot'));
                UPSERT form;
                System.debug('Created NEW Form >>> ' + form.Id);
            }

			if(currentUser.ContactId != null){
                Contact conRec = new Contact();
				conRec.Id = currentUser.ContactId;
				conRec.Create_New_Market_X_Ray_Version__c = false;
                UPDATE conRec;
            }
            
            /*Map<String, Object> customClearanceData = (Map<String, Object>) JSON.deserializeUntyped(customClearance);
            Map<String, Object> clearanceFields = (Map<String, Object>) customClearanceData.get('customClearance');
            List<Object> distributorData = (List<Object>) customClearanceData.get('distributorLineItem');*/
            System.debug('clearanceFields >>> ' + clearanceFields);
            
            // 4. Get or Create Customs_Clearance_Charges__c record
            Customs_Clearance_Charges__c  clearanceRecord;
            List<Customs_Clearance_Charges__c> existingCharges = [
                SELECT Id, Market_X_Ray_Form__c,
                From_India_IOLs__c, From_India_Solutions__c, From_India_Pharma__c,
                From_Ireland_IOLs__c, From_Ireland_Solutions__c, From_Ireland_Pharma__c,
                Other_Charges__c
                FROM Customs_Clearance_Charges__c 
                WHERE Market_X_Ray_Form__c = :form.Id 
                LIMIT 1
            ];
            System.debug('existingCharges ----> ' + existingCharges);
            
            if (!existingCharges.isEmpty()) {
                clearanceRecord = existingCharges[0];
                System.debug('Updating existing Custom Clearance Charges >>> ' + clearanceRecord.Id);
            } else {
                clearanceRecord = new Customs_Clearance_Charges__c();
                clearanceRecord.Market_X_Ray_Form__c = form.Id;
                System.debug('Creating NEW Custom Clearance Charges');
            }
            
            // 5. Map the custom clearance fields
            clearanceRecord.From_India_IOLs__c = getDecimalValue(clearanceFields.get('fromIndiaIOL'));
            clearanceRecord.From_India_Solutions__c = getDecimalValue(clearanceFields.get('fromIndiaSolution'));
            clearanceRecord.From_India_Pharma__c = getDecimalValue(clearanceFields.get('fromIndiaPharma'));
            clearanceRecord.From_Ireland_IOLs__c = getDecimalValue(clearanceFields.get('fromIrelandIOL'));
            clearanceRecord.From_Ireland_Solutions__c = getDecimalValue(clearanceFields.get('fromIrelandSolution'));
            clearanceRecord.From_Ireland_Pharma__c = getDecimalValue(clearanceFields.get('fromIrelandPharma'));
            clearanceRecord.Other_Charges__c = getDecimalValue(clearanceFields.get('anyOtherCharges'));
            
            System.debug('clearanceRecord before upsert >>> ' + clearanceRecord);
            UPSERT clearanceRecord;
            System.debug('after upsert clearanceRecord ======>>>>' + clearanceRecord.Id);

			if(form.IsMarketXrayFormEditable__c == true) {
                System.debug('call approval process' + form.Id);
                submitMarketXrayForApproval(form.Id);
            }
            
            if (distributorData != null && !distributorData.isEmpty()) {
                
                Set<String> productIds = new Set<String>();
                Set<String> distributorIds = new Set<String>();
                Map<String, String> existingMap = new Map<String, String>();
                List<DistributorLineItem__c> upsertList = new List<DistributorLineItem__c>();
                
                // STEP 1: Collect IDs
                for (Object obj : distributorData) {
                    Map<String, Object> row = (Map<String, Object>) obj;
                    String distributorId = (String) row.get('distributorId');
                    String productId = (String) row.get('productId');
                    
                    if (String.isNotBlank(distributorId)) {
                        distributorIds.add(distributorId);
                    }
                    if (String.isNotBlank(productId)) {
                        productIds.add(productId);
                    }
                }
                
                // STEP 2: Query existing records 
                if (!productIds.isEmpty() && !distributorIds.isEmpty()) {
                    for (DistributorLineItem__c dsItem : [
                        SELECT Id, Distributor__c, Product__c
                        FROM DistributorLineItem__c
                        WHERE Distributor__c IN :distributorIds
                        AND Product__c IN :productIds
                    ]) {
                        String key = dsItem.Distributor__c + '-' + dsItem.Product__c;
                        existingMap.put(key, dsItem.Id);
                    }
                }
                
                
				// STEP 3: Build upsert list
                for (Object obj : distributorData) {
                    Map<String, Object> row = (Map<String, Object>) obj;
                    
                    String distributorId = (String) row.get('distributorId');
                    String productId = (String) row.get('productId');
                    
                    if (String.isBlank(distributorId) || String.isBlank(productId)) {
                        continue;
                    }
                    
                    if (isRowEmpty(row)) {
                        System.debug('Skipping empty row for Product: ' + productId);
                        continue;
                    }
                    
                    String agreementProductId = (String) row.get('agreementProductId');
                    String key = distributorId + '-' + productId;
                    
                    DistributorLineItem__c item = new DistributorLineItem__c();
                    
                    if (existingMap.containsKey(key)) {
                        item.Id = existingMap.get(key);
                    }
                    
                    item.Product__c = productId;
                    item.Distributor__c = distributorId;
                    item.Agreement_Product__c = agreementProductId;
					item.Is_Agreement_Product__c = (agreementProductId != null) ? true : false;
                    item.Brand_Name__c = (String) row.get('brandName');
                    item.Price_For_Retail__c = getDecimalValue(row.get('priceRetail'));
                    item.Price_Key_Account__c = getDecimalValue(row.get('priceKeyAccounts'));
                    item.Total_Package__c = getDecimalValue(row.get('totalPackage'));
                    item.End_User_Price_by_Distributor_to_Doctor__c = getDecimalValue(row.get('endUser'));
                    item.Customs_Clearance_Charges__c = clearanceRecord.Id;
                    item.Market_X_Ray_Form__c = form.Id;
                    
                    upsertList.add(item);
                }
                
                // STEP 4: Save
                if (!upsertList.isEmpty()) {
                    upsert upsertList;
                }
            }
            
            //List<String> listOfst=new List<String>{form.Id};
             //MarketXrayFormEmailNotificationApprover.getPendingWorkitems(listOfst);
             //System.debug('MarketXrayFormEmailNotificationApprover.getPendingWorkitems(listOfst);' + MarketXrayFormEmailNotificationApprover.getPendingWorkitems(listOfst));
                
            return 'Custom Clearance Charges saved successfully with ID: ' + clearanceRecord.Id;
            
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error while saving data: ' + e.getMessage());
        }
    }


	// ✅ Helper method - Check if row is completely empty
        private static Boolean isRowEmpty(Map<String, Object> row) {
            String brandName = (String) row.get('brandName');
            
            // Check brandName
            if (String.isNotBlank(brandName)) {
                return false;
            }
            
            // Check numeric fields
            if (hasNumericValue(row.get('priceKeyAccounts'))) {
                return false;
            }
            if (hasNumericValue(row.get('priceRetail'))) {
                return false;
            }
            if (hasNumericValue(row.get('totalPackage'))) {
                return false;
            }
            if (hasNumericValue(row.get('endUser'))) {
                return false;
            }
            
            return true; // All fields are empty
        }
        
        // ✅ Helper method - Check if value is non-zero number
        private static Boolean hasNumericValue(Object value) {
            if (value == null) {
                return false;
            }
            
            String strValue = String.valueOf(value).trim();
            
            if (String.isBlank(strValue)) {
                return false;
            }
            
            try {
                Decimal decValue = Decimal.valueOf(strValue);
                return decValue != 0;
            } catch (Exception e) {
                return false;
            }
        }
    
    // Helper method for Decimal conversion
    private static Decimal getDecimalValue(Object value) {
        if (value == null) {
            return null;
        }
        try {
            return Decimal.valueOf(String.valueOf(value));
        } catch (Exception e) {
            System.debug('Error converting to Decimal: ' + value);
            return null;
        }
    }

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
    
    // Helper method for String conversion
    private static String getStringValue(Object value) {
        if (value == null) {
            return null;
        }
        return String.valueOf(value);
    }
    
    /*@AuraEnabled
    public static List<Distributor__c> getAllDistributor(){
        User u = [SELECT Id, Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId()];
        Account acc= [SELECT Id,BillingCountry FROM Account WHERE Id =:u.Contact.AccountId LIMIT 1]??null;
        return [SELECT Id,Address__CountryCode__s from Distributor__c WHERE  Address__CountryCode__s=:acc.BillingCountry];  
    }*/
    
    @AuraEnabled
    public static String saveDistributorLineItems(String lineItemsJson) {
        try {
            System.debug('lineItemsJson>>> ' + lineItemsJson);
            
            User currentUser = [SELECT Id, ContactId, Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1 ];
            
            if (currentUser.ContactId == null) {
                throw new AuraHandledException('This user is not associated with a Contact.');
            }
            
            Market_X_Ray_Form__c form;
            List<Market_X_Ray_Form__c> existingForms = [SELECT Id, Account__c, Contact__c FROM Market_X_Ray_Form__c WHERE Contact__c = :currentUser.ContactId ORDER BY CreatedDate DESC LIMIT 1];
            
            if (!existingForms.isEmpty()) {
                form = existingForms[0];
                System.debug('Found existing Form >>> ' + form.Id);
            } else {
                form = new Market_X_Ray_Form__c();
                form.Account__c = currentUser.Contact.AccountId;
                form.Contact__c = currentUser.ContactId;
                UPSERT form;
                System.debug('Created NEW Form >>> ' + form.Id);
            }
            
            Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(lineItemsJson);
            List<Object> distributorsData = (List<Object>) dataMap.get('distributors');
            
            System.debug('Distributors Data >>> ' + distributorsData);
            
            List<DistributorLineItem__c> existingLineItems = [SELECT Id FROM DistributorLineItem__c WHERE Market_X_Ray_Form__c = :form.Id];
            
            if (!existingLineItems.isEmpty()) {
                DELETE existingLineItems;
                System.debug('Deleted existing line items: ' + existingLineItems.size());
            }
            
            List<DistributorLineItem__c> lineItemsToInsert = new List<DistributorLineItem__c>();
            
            for (Object distObj : distributorsData) {
                Map<String, Object> distData = (Map<String, Object>) distObj;
                String distributorId = (String) distData.get('distributorId');
                List<Object> products = (List<Object>) distData.get('products');
                
                System.debug('Processing Distributor: ' + distributorId);
                
                for (Object prodObj : products) {
                    Map<String, Object> prodData = (Map<String, Object>) prodObj;
                    
                    String brandName = (String) prodData.get('brandName');
                    Object priceKeyAccounts = prodData.get('priceKeyAccounts');
                    Object priceRetail = prodData.get('priceRetail');
                    Object totalPackage = prodData.get('totalPackage');
                    
                    if (String.isBlank(brandName) && priceKeyAccounts == null && priceRetail == null && totalPackage == null) {
                            continue;
                    }
                    
                    DistributorLineItem__c lineItem = new DistributorLineItem__c();
                    lineItem.Market_X_Ray_Form__c = form.Id;
                    lineItem.Account__c = currentUser.Contact.AccountId;
                    lineItem.Distributor__c = distributorId;
                    
                    String agreementProductId = (String) prodData.get('agreementProductId');
                    String productId = (String) prodData.get('productId');
                    Boolean isAgreementProduct = (Boolean) prodData.get('isAgreementProduct');
                    
                    if (isAgreementProduct != null && isAgreementProduct && String.isNotBlank(agreementProductId)) {
                        lineItem.Agreement_Product__c = agreementProductId;
                        lineItem.Is_Agreement_Product__c = true;
                    } else if (String.isNotBlank(productId)) {
                        lineItem.Product__c = productId;
                        lineItem.Is_Agreement_Product__c = false;
                    }
                
                    lineItem.Brand_Name__c = brandName;
                    lineItem.Price_Key_Account__c = getDecimalValue(priceKeyAccounts);
                    lineItem.Price_For_Retail__c = getDecimalValue(priceRetail);
                    lineItem.Total_Package__c = getDecimalValue(totalPackage);
                    
                    lineItemsToInsert.add(lineItem);
                }
            }
            
            if (!lineItemsToInsert.isEmpty()) { 
                INSERT lineItemsToInsert;
                System.debug('Inserted ' + lineItemsToInsert.size() + ' line items');
            }
            
            return 'Successfully saved ' + lineItemsToInsert.size() + ' line items';
            
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error while saving: ' + e.getMessage());
        }
        
    }
    @AuraEnabled
public static String getDistributorLineItemsSummary() {
    try {
        System.debug('Fetching distributor line items summary...');
        
        // 1. Get current user
        User currentUser = [
            SELECT Id, ContactId, Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        
        if (currentUser.ContactId == null) {
            return null;
        }
        
        // 2. Get Market X-Ray Form
        List<Market_X_Ray_Form__c> forms = [
            SELECT Id 
            FROM Market_X_Ray_Form__c
            WHERE Contact__c = :currentUser.ContactId
            LIMIT 1
        ];
        
        if (forms.isEmpty()) {
            System.debug('No Market X-Ray Form found');
            return null;
        }
        
        Id formId = forms[0].Id;
        
        // 3. Get Custom Clearance Charges
        List<Customs_Clearance_Charges__c> charges = [
            SELECT Id, 
                   From_India_IOLs__c, 
                   From_India_Solutions__c, 
                   From_India_Pharma__c,
                   From_Ireland_IOLs__c, 
                   From_Ireland_Solutions__c, 
                   From_Ireland_Pharma__c,
                   Other_Charges__c
            FROM Customs_Clearance_Charges__c
            WHERE Market_X_Ray_Form__c = :formId
            LIMIT 1
        ];
        
        Map<String, Decimal> customClearanceMap = new Map<String, Decimal>();
        if (!charges.isEmpty()) {
            Customs_Clearance_Charges__c charge = charges[0];
            customClearanceMap.put('fromIndiaIOL', charge.From_India_IOLs__c);
            customClearanceMap.put('fromIndiaSolution', charge.From_India_Solutions__c);
            customClearanceMap.put('fromIndiaPharma', charge.From_India_Pharma__c);
            customClearanceMap.put('fromIrelandIOL', charge.From_Ireland_IOLs__c);
            customClearanceMap.put('fromIrelandSolution', charge.From_Ireland_Solutions__c);
            customClearanceMap.put('fromIrelandPharma', charge.From_Ireland_Pharma__c);
        }
        
        // 4. Get all Distributor Line Items with related data
        List<DistributorLineItem__c> lineItems = [
            SELECT Id, 
                   Distributor__c,
                   Distributor__r.Name,
                   Product__c,
                   Product__r.Name,
                   Product__r.Division__c,
                   Product__r.Category__c,
                   Agreement_Product__c,
                   Agreement_Product__r.Product__c,
                   Agreement_Product__r.Product__r.Name,
                   Agreement_Product__r.Product__r.Division__c,
                   Agreement_Product__r.Product__r.Category__c,
                   Agreement_Product__r.Price__c,
                   Agreement_Product__r.FOC_Text__c,
                   Brand_Name__c,
                   Price_Key_Account__c,
                   Price_For_Retail__c,
                   Total_Package__c,
                   Is_Agreement_Product__c
            FROM DistributorLineItem__c
            WHERE Market_X_Ray_Form__c = :formId
            ORDER BY Product__r.Division__c, Product__r.Category__c, Product__r.Name
        ];
        
        System.debug('Found ' + lineItems.size() + ' line items');
        
        // 5. Group by Product
        Map<String, Map<String, Object>> productMap = new Map<String, Map<String, Object>>();
        
        for (DistributorLineItem__c item : lineItems) {
            String productId;
            String productName;
            String division;
            String category;
            Decimal agreementPrice = null;
            Decimal foc = null;
            
            if (item.Is_Agreement_Product__c && item.Agreement_Product__c != null) {
                productId = item.Agreement_Product__r.Product__c;
                productName = item.Agreement_Product__r.Product__r.Name;
                division = item.Agreement_Product__r.Product__r.Division__c;
                category = item.Agreement_Product__r.Product__r.Category__c;
                agreementPrice = item.Agreement_Product__r.Price__c;
                
                // Parse FOC (handle both percentage and text)
                String focText = item.Agreement_Product__r.FOC_Text__c;
                if (String.isNotBlank(focText)) {
                    try {
                        foc = Decimal.valueOf(focText.replace('%', '').trim());
                    } catch (Exception e) {
                        foc = 0;
                    }
                }
            } else if (item.Product__c != null) {
                productId = item.Product__c;
                productName = item.Product__r.Name;
                division = item.Product__r.Division__c;
                category = item.Product__r.Category__c;
            }
            
            if (String.isBlank(productId)) continue;
            
            if (!productMap.containsKey(productId)) {
                productMap.put(productId, new Map<String, Object>{
                    'productId' => productId,
                    'productName' => productName,
                    'division' => division,
                    'category' => category,
                    'agreementPrice' => agreementPrice,
                    'foc' => foc,
                    'distributors' => new Map<String, Object>()
                });
            }
            
            Map<String, Object> productData = productMap.get(productId);
            Map<String, Object> distributorData = (Map<String, Object>) productData.get('distributors');
            
            distributorData.put(item.Distributor__c, new Map<String, Object>{
                'distributorId' => item.Distributor__c,
                'distributorName' => item.Distributor__r.Name,
                'brandName' => item.Brand_Name__c,
                'priceKeyAccount' => item.Price_Key_Account__c,
                'priceRetail' => item.Price_For_Retail__c,
                'totalPackage' => item.Total_Package__c
            });
        }
        
        // 6. Build final response
        Map<String, Object> response = new Map<String, Object>{
            'products' => productMap.values(),
            'customClearance' => customClearanceMap
        };
        
        return JSON.serialize(response);
        
    } catch (Exception e) {
        System.debug('Error: ' + e.getMessage());
        System.debug('Stack Trace: ' + e.getStackTraceString());
        throw new AuraHandledException('Error loading summary: ' + e.getMessage());
    }

}


		public static void submitMarketXrayForApproval(Id formId) {
            try {
        
                Market_X_Ray_Form__c formRecord = [SELECT Id, Account__c, Account__r.CRM_Email__c, Account__r.Approver_1__c FROM Market_X_Ray_Form__c WHERE Id = :formId];
                System.debug('formRecord=======>>>>' + formRecord);
        
                List<Id> nextApprovers = new List<Id>();
                //String userId = '';
        
                if (formRecord.Account__c != null && formRecord.Account__r.CRM_Email__c != null) {
                    List<User> approverUsers = [SELECT Id, Email FROM User WHERE Email = :formRecord.Account__r.CRM_Email__c AND IsActive = TRUE];
					System.debug('approverUsers=====>>>>'+ approverUsers);
        
                    for (User u : approverUsers) {
                        //userId = u.Id;
                        nextApprovers.add(u.Id);
                    }
                    
                    System.debug('nextApprovers======>>>> list before '+ nextApprovers);

                    if(String.isNotBlank(formId)){
                       	Market_X_Ray_Form__c marketXrayFormUpdate = new Market_X_Ray_Form__c();
                        marketXrayFormUpdate.Id = formId;
                        marketXrayFormUpdate.StoreUserId__c = UserInfo.getUserId();
						update marketXrayFormUpdate;
                    }
                }

				System.debug('nextApprovers======>>>> list '+ nextApprovers);
        
                if (nextApprovers.isEmpty()) {
                    System.debug('No first-stage approvers found, skipping first approval.');
                } else {
                    Approval.ProcessSubmitRequest firstReq = new Approval.ProcessSubmitRequest();
                    firstReq.setComments('Submitting Market X-Ray for first approval');
                    firstReq.setObjectId(formId);
                    firstReq.setSkipEntryCriteria(true);
                    firstReq.setNextApproverIds(nextApprovers);
                    firstReq.setProcessDefinitionNameOrId('Step_1_Approval_Process_Form');
                    Approval.ProcessResult firstResult = Approval.process(firstReq);
        
                    System.debug('First Approval Submission Result: ' + firstResult.isSuccess());

					/*if (firstResult.isSuccess()) {
                        sendEmailToCrmEmail(formRecord);
                    }*/
                }
            } catch (Exception ex) {
                System.debug('Error while submitting for approval: ' + ex.getMessage());
            }
        }


		/*private static void sendEmailToCrmEmail(Market_X_Ray_Form__c formRecord) {
            if (String.isBlank(formRecord.Account__r.CRM_Email__c)) return;

			OrgWideEmailAddress owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'crm@company.com' LIMIT 1];
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        	mail.setToAddresses(new String[] { formRecord.Account__r.CRM_Email__c });
			mail.setOrgWideEmailAddressId(owea.Id);
            mail.setSubject('Action Required – Review & Approve Market X-Ray Form');
            mail.setPlainTextBody('Dear Approver,\n\n' + 'A new Market X-Ray Form has been submitted under ' +
                				   formRecord.Account__r.Name + '.\n\n' + 'Form Number: ' + formRecord.Name + '\n\n' +
                				   'Please login to Salesforce to review and approve.\n\n' + 'Regards,\nMarket X-Ray Automation');
        
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }*/


}
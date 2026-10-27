public class ProductConfiguratorController {
     @AuraEnabled(cacheable=true)
public static String getAccountCommercialName(Id accountId) {
    if (accountId == null) return null;
    Account acc = [
        SELECT Commercial_Account_Name__c
        FROM Account
        WHERE Id = :accountId
        LIMIT 1
    ];
    return acc.Commercial_Account_Name__c;
}
    @AuraEnabled
    public static void createMemberAndProductRecord(
        String campaignMember,
        List<Object> selectedRows
    ) {
        try {
            System.debug('CM : ' + campaignMember);
            System.debug('selectedRows : ' + Json.serialize(selectedRows));
            
            if (String.isBlank(campaignMember)) {
                throw new AuraHandledException('Campaign Member data is required.');
            }
            
            Campaign_Member__c campaignMemberRec =
                (Campaign_Member__c) JSON.deserialize(campaignMember, Campaign_Member__c.class);
            
            insert campaignMemberRec;
            
            List<Campaign_Member_Product__c> campaignProductList = new List<Campaign_Member_Product__c>();
            
            if (selectedRows != null && !selectedRows.isEmpty()) {
                for (Object obj : selectedRows) {
                    if (obj == null) continue;
                    
                    Map<Object, Object> row = (Map<Object, Object>) obj;
                    Object productGroupId = row.get('Product_Group__c');
                    System.debug('productGroupId: ' + productGroupId);
                    
                    if (productGroupId != null) {
                        campaignProductList.add(
                            new Campaign_Member_Product__c(
                                Campaign_Members__c = campaignMemberRec.Id,
                                Product_Group__c    = (Id) productGroupId
                            )
                        );
                    }
                }
            }
            
            System.debug('campaignProductList: ' + campaignProductList);
            
            if (!campaignProductList.isEmpty()) {
                insert campaignProductList;
            }
            
        } catch (Exception e) {
            System.debug('ERROR: ' + e.getMessage());
            throw new AuraHandledException(
                'Failed to create Campaign Member and Products: ' + e.getMessage()
            );
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String,Object>> getRecordTypeNameWithId(String ObjectApiName) {
        List<Map<String,Object>> returnMap = new List<Map<String,Object>>();
        for (RecordType redType : [
            SELECT Id, Name, DeveloperName
            FROM RecordType
            WHERE SObjectType = :ObjectApiName
            ORDER BY Name
        ]) {
            returnMap.add(new Map<String,Object>{ 'label' => redType.Name, 'value' => redType.Id });
        }
        return returnMap;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<FieldSetFieldWrapper> getFieldSets(String objectName, String fieldSetName) {
        List<FieldSetFieldWrapper> listOfFieldSet = new List<FieldSetFieldWrapper>();
        Schema.DescribeSObjectResult describeResult = Schema.getGlobalDescribe().get(objectName).getDescribe();
        for (Schema.FieldSetMember fsm : describeResult.fieldSets.getMap().get(fieldSetName).getFields()) {
            FieldSetFieldWrapper wrapper = new FieldSetFieldWrapper();
            wrapper.fieldName  = fsm.getFieldPath();
            wrapper.isRequired = fsm.getRequired();
            listOfFieldSet.add(wrapper);
        }
        return listOfFieldSet;
    }
      @AuraEnabled(cacheable=true)
    public static List<Contact> getRelatedContactIds(Id accountId) {
        if (accountId == null) {
            return new List<Contact>();
        }
        return [
            SELECT Id, Name
            FROM   Contact
            WHERE  AccountId = :accountId
            ORDER BY Name
        ];
    }
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getContactNameById(Id contactId) {
        Map<String, String> contactNames = new Map<String, String>();
        if (contactId != null) {
            Contact contact = [
                SELECT FirstName, LastName, Email, MailingCity, MailingStreet,
                MailingState, MailingPostalCode, MailingCountry, MobilePhone
                FROM Contact
                WHERE Id = :contactId
                LIMIT 1
            ];
            contactNames.put('FirstName',         contact.FirstName);
            contactNames.put('LastName',          contact.LastName);
            contactNames.put('Email',             contact.Email);
            contactNames.put('MailingCity',       contact.MailingCity);
            contactNames.put('MailingStreet',     contact.MailingStreet);
            contactNames.put('MailingState',      contact.MailingState);
            contactNames.put('MailingPostalCode', contact.MailingPostalCode);
            contactNames.put('MailingCountry',    contact.MailingCountry);
            contactNames.put('MobilePhone',       contact.MobilePhone);
        }
        return contactNames;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Campaign_Line_Item__c> getLineItem(String recordId) {
        return [
            SELECT Id,
            Name,
            Product_Family__c,
            Product_Group__c,
            Product_Group__r.Name,
            Product_Group__r.Brand__c,
            Product_Group__r.Product_Family__c
            FROM Campaign_Line_Item__c
            WHERE Campaign__c = :recordId
        ];
    }
    
    @AuraEnabled
    public static void createCamLine(Id camId, List<String> productFamilies) {
        if (camId == null || productFamilies == null || productFamilies.isEmpty()) {
            throw new AuraHandledException('Campaign Id and Product Families are required.');
        }
        System.debug('camId: ' + camId);
        System.debug('productFamilies: ' + productFamilies);
        
        // Prevent duplicates
        Set<String> existingFamilies = new Set<String>();
        for (Campaign_Line_Item__c cli : [
            SELECT Product_Family__c
            FROM Campaign_Line_Item__c
            WHERE Campaign__c = :camId
        ]) {
            existingFamilies.add(cli.Product_Family__c);
        }
        
        Campaign__c target = [SELECT Id, Name FROM Campaign__c WHERE Id = :camId LIMIT 1];
        
        List<Campaign_Line_Item__c> linesToInsert = new List<Campaign_Line_Item__c>();
        for (String proFam : productFamilies) {
            if (!existingFamilies.contains(proFam)) {
                linesToInsert.add(new Campaign_Line_Item__c(
                    Campaign__c       = target.Id,
                    Product_Family__c = proFam
                ));
            }
        }
        
        if (!linesToInsert.isEmpty()) {
            try {
                insert linesToInsert;
            } catch (Exception e) {
                throw new AuraHandledException('Database Error: ' + e.getMessage());
            }
        }
    }
    
    @AuraEnabled
    public static void createCampaignLine(Id campaignId, List<String> productFamilies, List<String> groupNames) {
        if (campaignId == null || productFamilies == null || productFamilies.isEmpty()) {
            throw new AuraHandledException('Campaign Id and Product Families are required.');
        }
        User usr=[SELECT Id,country__c FROM User WHERE Id=:userInfo.getUserId()]??Null;
        List<Product_Group__c> productGroups;
        
        if (groupNames != null && !groupNames.isEmpty()) {
            productGroups = [
                SELECT Id, Product_Family__c, Group_Name__c, Brand__c
                FROM Product_Group__c
                WHERE Product_Family__c IN :productFamilies
                AND Brand__c IN :groupNames
                AND Display_On_Opportunity__c = true
                AND country__c =:usr.country__c
            ];
        } else {
            productGroups = [
                SELECT Id, Product_Family__c, Group_Name__c, Brand__c
                FROM Product_Group__c
                WHERE Product_Family__c IN :productFamilies
                AND Display_On_Opportunity__c = true  AND country__c =:usr.country__c
            ];
        }
        
        System.debug('Product Groups Found: ' + productGroups.size());
        
        // Prevent duplicates: get existing Campaign Line Items
        Set<Id> existingPgIds = new Set<Id>();
        for (Campaign_Line_Item__c cli : [
            SELECT Product_Group__c
            FROM Campaign_Line_Item__c
            WHERE Campaign__c = :campaignId
            AND Product_Group__c != null
        ]) {
            existingPgIds.add(cli.Product_Group__c);
        }
        
        List<Campaign_Line_Item__c> linesToInsert = new List<Campaign_Line_Item__c>();
        for (Product_Group__c pg : productGroups) {
            if (!existingPgIds.contains(pg.Id)) {
                linesToInsert.add(new Campaign_Line_Item__c(
                    Campaign__c       = campaignId,
                    Product_Family__c = pg.Product_Family__c,
                    Product_Group__c  = pg.Id
                ));
            }
        }
        
        if (!linesToInsert.isEmpty()) {
            try {
                insert linesToInsert;
            } catch (Exception e) {
                throw new AuraHandledException('Database Error: ' + e.getMessage());
            }
        }
    }
    
    @AuraEnabled
    public static Boolean checkDuplicateMember(String campaignId, String firstName, String lastName) {
        List<Campaign_Member__c> existing = [
            SELECT Id
            FROM Campaign_Member__c
            WHERE Campaign1__c = :campaignId
            AND Lead_First_Name__c = :firstName
            AND Lead_Last_Name__c  = :lastName
            LIMIT 1
        ];
        return !existing.isEmpty();
    }
    
    public class FieldSetFieldWrapper {
        @AuraEnabled public String  fieldName;
        @AuraEnabled public Boolean isRequired;
    }

    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCountries() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Set<String> seen = new Set<String>();
        for (AggregateResult  c : [SELECT Country__c FROM Country__c 
                               WHERE Country__c != null GROUP BY Country__c Order by Country__c ASC]) {
            String countryName = (String) c.get('Country__c');
        options.add(new Map<String, String>{
            'label' => countryName,
            'value' => countryName
        });
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getStates(String country) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Set<String> seen = new Set<String>();
        for (Country__c c : [SELECT Id, State__c FROM Country__c 
                               WHERE Country__c = :country AND State__c != null 
                               ORDER BY State__c ASC]) {
            if (!seen.contains(c.State__c)) {
                seen.add(c.State__c);
                options.add(new Map<String, String>{
                    'label' => c.State__c,
                    'value' => c.State__c
                });
            }
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCities(String country, String state) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (Country__c c : [SELECT Id, City__c FROM Country__c 
                               WHERE Country__c = :country AND State__c = :state 
                               AND City__c != null 
                               ORDER BY City__c ASC]) {
            options.add(new Map<String, String>{
                'label' => c.City__c,
                'value' => c.City__c
            });
        }
        return options;
    }
}
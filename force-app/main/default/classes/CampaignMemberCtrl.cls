public with sharing class CampaignMemberCtrl {
    
    @AuraEnabled(cacheable=true)
    public static List<Contact> searchContacts(String searchKey) {
        return [
            SELECT Id, Name
            FROM Contact
            WHERE Name LIKE :('%' + searchKey + '%')
            ORDER BY Name
            LIMIT 10
        ];
    }
    
    
    @AuraEnabled(cacheable=true)
    public static List<RecordTypeWrapper> getRecordTypes() {
        
        List<RecordTypeWrapper> result = new List<RecordTypeWrapper>();
        
        for (RecordType rt : [
            SELECT Id, Name
            FROM RecordType
            WHERE SObjectType = 'Campaign_Member__c'
            AND IsActive = true
            ORDER BY Name
        ]) {
            result.add(new RecordTypeWrapper(rt.Id, rt.Name));
        }
        
        return result;
    }
    
    public class RecordTypeWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        
        public RecordTypeWrapper(String id, String name) {
            this.id = id;
            this.name = name;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> fetchCampaignData(Id recordId) {
        
        Map<String, Object> result = new Map<String, Object>();
        
        List<PicklistOption> memberTypeOptions =
            getPickListLabelValue(
                'Campaign_member__c',
                'Member_Type__c'
            );
        
        List<PicklistOption> CampaignProductoption =
            getPickListLabelValue(
                'Campaign_member__c',
                'Campaign_Product__c'
            );
        
        result.put('memberTypePicklist', memberTypeOptions);
        result.put('cmpaignProductList', CampaignProductoption);
        Map<String, Object> fieldMap = new Map<String, Object>();
        
        if (recordId !=null && recordId.getSObjectType() == Campaign_member__c.SObjectType) {
            
            Campaign_member__c cm = [
                SELECT Account__c,Contact__r.Name, Account_Billing_City__c,Account__r.Name,Account__r.Id, Account_Billing_Country__c, Account_Billing_State__c,
                Account_CE_CIS_Rating__c, Account_Phakic_Rating__c, Account_SAP_Code__c, Activity_type__c, Approver__c, 
                Attended__c, Attended_Product_1_Opportunity__c,recordtype.Name, Attended_Product_2_Opportunity__c,
                Attended_Product_3_Opportunity__c, Attended_Product_4_Opportunity__c, Campaign_City__c,
                Campaign_Id__c, Campaign_Name__c, Campaign_Product__c, Campaign1__c, CampaignPhone__c,
                Contact__c,Campaign1__r.Id,Campaign1__r.Name, Customer__c, Customer_Name__c,
                End_date__c, Id,Lead_City__c, Lead_Country__c, Lead_Email__c,
                Lead_First_Name__c, Lead_Hospital_Clinic_Name__c, Lead_Last_Name__c, Lead_Mobile_Number__c,
                Lead_State_Province__c, Lead_Street__c, Lead_Zip_Postal_Code__c, Lead1__c, Member_Type__c,
                Name, Notes__c, Product__c, Product_1_Name__c, Product_1Opportunity__c, Product_2_Name__c,
                Product_2_Opportunity__c, Product_3_Opportunity__c, Product_4_Opportunity__c, RecordTypeId,
                Start_date__c, SystemModstamp from Campaign_Member__c WHERE Id = :recordId
                LIMIT 1
            ];
            
            
            
            fieldMap.put('Account__c', cm.Account__c);
            fieldMap.put('Account_Billing_City__c', cm.Account_Billing_City__c);
            fieldMap.put('Account_Billing_Country__c', cm.Account_Billing_Country__c);
            fieldMap.put('Account_Billing_State__c', cm.Account_Billing_State__c);
            fieldMap.put('Account_CE_CIS_Rating__c', cm.Account_CE_CIS_Rating__c);
            fieldMap.put('Account_Phakic_Rating__c', cm.Account_Phakic_Rating__c);
            fieldMap.put('Account_SAP_Code__c', cm.Account_SAP_Code__c);
            
            fieldMap.put('Activity_type__c', cm.Activity_type__c);
            fieldMap.put('Approver__c', cm.Approver__c);
            fieldMap.put('Attended__c', cm.Attended__c);
            
            fieldMap.put('Attended_Product_1_Opportunity__c', cm.Attended_Product_1_Opportunity__c);
            fieldMap.put('Attended_Product_2_Opportunity__c', cm.Attended_Product_2_Opportunity__c);
            fieldMap.put('Attended_Product_3_Opportunity__c', cm.Attended_Product_3_Opportunity__c);
            fieldMap.put('Attended_Product_4_Opportunity__c', cm.Attended_Product_4_Opportunity__c);
            
            fieldMap.put('Campaign_City__c', cm.Campaign_City__c);
            fieldMap.put('Campaign_Id__c', cm.Campaign_Id__c);
            if (cm.Campaign1__c != null) {
                Map<String, Object> campaignLookup = new Map<String, Object>();
                campaignLookup.put('Id', cm.Campaign1__r.Id);
                campaignLookup.put('Name', cm.Campaign1__r.Name);
                
                fieldMap.put('Campaign1__c', campaignLookup);
            }
            if (cm.Contact__c != null) {
                Map<String, Object> contactMap = new Map<String, Object>();
                contactMap.put('Id', cm.Contact__c);
                contactMap.put('Name', cm.Contact__r.Name);
                fieldMap.put('Contact__c', contactMap);
            }
            
            if (cm.Account__c != null) {
                Map<String, Object> accountLookup = new Map<String, Object>();
                accountLookup.put('Id', cm.Account__c);
                accountLookup.put('Name', cm.Account__r.Name);
                fieldMap.put('Account__c', accountLookup);
            }
            
            if (cm.recordtypeId != null) {
                Map<String, Object> recordtypeIdMap = new Map<String, Object>();
                recordtypeIdMap.put('Id', cm.recordtypeId);
                recordtypeIdMap.put('Name', cm.recordtype.Name);
                
                fieldMap.put('RecordtypeName', recordtypeIdMap);
            }
            fieldMap.put('recordtypeId', cm.recordtypeId);
            fieldMap.put('Campaign_Name__c', cm.Campaign_Name__c);
            fieldMap.put('Campaign_Product__c', cm.Campaign_Product__c);
            fieldMap.put('CampaignPhone__c', cm.CampaignPhone__c);
            
            
            
            fieldMap.put('Customer__c', cm.Customer__c);
            fieldMap.put('Customer_Name__c', cm.Customer_Name__c);
            
            fieldMap.put('Start_date__c', cm.Start_date__c);
            fieldMap.put('End_date__c', cm.End_date__c);
            
            fieldMap.put('Lead_City__c', cm.Lead_City__c);
            fieldMap.put('Lead_Country__c', cm.Lead_Country__c);
            fieldMap.put('Lead_Email__c', cm.Lead_Email__c);
            fieldMap.put('Lead_First_Name__c', cm.Lead_First_Name__c);
            fieldMap.put('Lead_Hospital_Clinic_Name__c', cm.Lead_Hospital_Clinic_Name__c);
            fieldMap.put('Lead_Last_Name__c', cm.Lead_Last_Name__c);
            fieldMap.put('Lead_Mobile_Number__c', cm.Lead_Mobile_Number__c);
            fieldMap.put('Lead_State_Province__c', cm.Lead_State_Province__c);
            fieldMap.put('Lead_Street__c', cm.Lead_Street__c);
            fieldMap.put('Lead_Zip_Postal_Code__c', cm.Lead_Zip_Postal_Code__c);
            fieldMap.put('Lead1__c', cm.Lead1__c);
            
            fieldMap.put('Member_Type__c', cm.Member_Type__c);
            fieldMap.put('Notes__c', cm.Notes__c);
            
            fieldMap.put('Product__c', cm.Product__c);
            fieldMap.put('Product_1_Name__c', cm.Product_1_Name__c);
            fieldMap.put('Product_1Opportunity__c', cm.Product_1Opportunity__c);
            fieldMap.put('Product_2_Name__c', cm.Product_2_Name__c);
            fieldMap.put('Product_2_Opportunity__c', cm.Product_2_Opportunity__c);
            fieldMap.put('Product_3_Opportunity__c', cm.Product_3_Opportunity__c);
            fieldMap.put('Product_4_Opportunity__c', cm.Product_4_Opportunity__c);       
            
            result.put('type', 'CampaignMember');
            result.put('data', fieldMap);
        }
        else if( recordId!=null && recordId.getSObjectType() == Campaign__c.SObjectType){
            
            Campaign__c campaign = [ select Id,Name from Campaign__c where Id =:recordId];
            fieldMap.put('Id', campaign.Id);
            fieldMap.put('Name', campaign.Name);   
            
            result.put('type', 'Campaign');
            result.put('data', fieldMap);
        }else{
            fieldMap.put('recordtypeId', '');
            result.put('type', 'Newcampaignmember');
            result.put('data', fieldMap);
            
        }
        
        return result;
    }
  @AuraEnabled
public static Id saveCampaignMember(
    Map<String, Object> fieldValues,
    Id recordId
) {
    Campaign_member__c cm;

    System.debug('Incoming recordId => ' + recordId);
    System.debug('fieldValues => ' + JSON.serialize(fieldValues));

    /* -------------------------
       1️⃣ Initialize record
    -------------------------- */
    if (recordId != null) {
        Schema.SObjectType sObjType = recordId.getSObjectType();

        if (sObjType == Campaign_member__c.SObjectType) {
            cm = new Campaign_member__c(Id = recordId);
        }
        else if (sObjType == Campaign__c.SObjectType) {
            cm = new Campaign_member__c();
            cm.Campaign1__c = recordId;
        }
        else {
            cm = new Campaign_member__c();
        }
    } else {
        cm = new Campaign_member__c();
    }

    /* -------------------------
       2️⃣ Handle RecordTypeId explicitly
    -------------------------- */
    if (fieldValues.containsKey('recordtypeId')) {
        cm.RecordTypeId = Id.valueOf(
            String.valueOf(fieldValues.get('recordtypeId'))
        );
    }

     if (fieldValues.containsKey('Campaign1__c') && recordId == null) {
        cm.Campaign1__c = Id.valueOf(String.valueOf(fieldValues.get('Campaign1__c')));
    }

    /* -------------------------
       3️⃣ Generic field handler
    -------------------------- */
    Map<String, Schema.SObjectField> fieldsMap =
        Campaign_member__c.SObjectType.getDescribe().fields.getMap();

    for (String fieldName : fieldValues.keySet()) {

        if (fieldName.equalsIgnoreCase('recordtypeId')) continue;

        // skip unknown fields
        if (!fieldsMap.containsKey(fieldName)) continue;

        Schema.DescribeFieldResult dfr =
            fieldsMap.get(fieldName).getDescribe();

        // skip formula / read-only
        if (dfr.isCalculated() || !dfr.isUpdateable()) continue;

        Object raw = fieldValues.get(fieldName);
        if (raw == null) continue;

        Object finalValue;

        try {
            switch on dfr.getType() {

                when Integer {
                    finalValue = Integer.valueOf(String.valueOf(raw));
                }

                when Double, Currency, Percent {
                    finalValue = Decimal.valueOf(String.valueOf(raw));
                }

                when Boolean {
                    finalValue =
                        String.valueOf(raw).equalsIgnoreCase('true');
                }

                when Date {
                    finalValue = Date.valueOf(String.valueOf(raw));
                }

                when DateTime {
                    finalValue = DateTime.valueOf(String.valueOf(raw));
                }

                // ✅ Lookup / Master-Detail
                when Reference {
                    finalValue = Id.valueOf(String.valueOf(raw));
                    system.debug('finalValue-->'+ finalValue);
                }

                // ✅ Multi-select picklist / array support
                when String {
                    if (raw instanceof List<Object>) {
                        List<String> values = new List<String>();
                        for (Object o : (List<Object>) raw) {
                            values.add(String.valueOf(o));
                        }
                        finalValue = String.join(values, ';');
                    } else {
                        finalValue = String.valueOf(raw);
                    }
                }

                when else {
                    finalValue = raw;
                }
            }

            cm.put(fieldName, finalValue);
            System.debug('Field set => ' + fieldName + ' = ' + finalValue);

        } catch (Exception e) {
            System.debug(
                'Skipping field ' + fieldName +
                ' due to error: ' + e.getMessage()
            );
        }
    }

    /* -------------------------
       4️⃣ Save record
    -------------------------- */
   try {
    Database.UpsertResult sr = Database.upsert(cm, false);

    if (!sr.isSuccess()) {
        for (Database.Error err : sr.getErrors()) {

            System.debug('❌ DML Error StatusCode => ' + err.getStatusCode());
            System.debug('❌ DML Error Message => ' + err.getMessage());

            // 🔥 EXACT FIELDS causing error
            if (err.getFields() != null && !err.getFields().isEmpty()) {
                System.debug('❌ Error Fields => ' + err.getFields());
            }

            // Optional: throw readable error to UI
            throw new AuraHandledException(
                'Save failed: ' + err.getMessage() +
                ' | Fields: ' + err.getFields()
            );
        }
        
    }
       return cm.Id;

} catch (Exception e) {
    System.debug('❌ Unexpected exception => ' + e.getMessage());
    throw new AuraHandledException(e.getMessage());
}

    
}

    
    
    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        
        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getCountries() {
        Set<String> countries = new Set<String>();
        
        for (Country__c c : [
            SELECT Country__c
            FROM Country__c
            WHERE Country__c != null
        ]) {
            countries.add(c.Country__c);
        }
        
        List<String> countryList = new List<String>(countries);
        countryList.sort();
        return countryList;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getStates(String country) {
        Set<String> states = new Set<String>();
        
        for (Country__c c : [
            SELECT State__c
            FROM Country__c
            WHERE Country__c = :country
            AND State__c != null
        ]) {
            states.add(c.State__c);
        }
        
        List<String> stateList = new List<String>(states);
        stateList.sort();
        return stateList;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getCities(String state) {
        Set<String> cities = new Set<String>();
        
        for (Country__c c : [
            SELECT CITY__c
            FROM Country__c
            WHERE State__c = :state
            AND CITY__c != null
        ]) {
            cities.add(c.CITY__c);
        }
        
        List<String> cityList = new List<String>(cities);
        cityList.sort();
        return cityList;
    }
    
    
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getPickListLabelValue(
        String objectType,
        String fieldName
    ) {
        List<PicklistOption> options = new List<PicklistOption>();
        
        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectType);
        if (sObjType == null) return options;
        
        Schema.DescribeSObjectResult objDescribe = sObjType.getDescribe();
        Schema.DescribeFieldResult fieldDescribe =
            objDescribe.fields.getMap().get(fieldName).getDescribe();
        
        for (Schema.PicklistEntry ple : fieldDescribe.getPicklistValues()) {
            options.add(
                new PicklistOption(
                    ple.getLabel(), // what user sees
                    ple.getValue()  // what is stored
                )
            );
        }
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static Account getAccountDetails(Id accountId) {
        if (accountId == null) return null;
        
        return [
            SELECT Id, Name, Phone, BillingStreet, BillingCity,
            BillingState, BillingPostalCode, BillingCountry
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static Contact getContactDetails(Id contactId) {
        if (contactId == null) return null;
        
        return [
            SELECT Id, FirstName, LastName, Email, MobilePhone
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
    }
    
    
    
    
}
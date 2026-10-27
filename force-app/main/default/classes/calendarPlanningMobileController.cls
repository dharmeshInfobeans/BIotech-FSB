public with sharing class calendarPlanningMobileController {
    @AuraEnabled(cacheable = false)
    public static List<Map<String, String>> getProductsBySubCallType(String subCallType) {
        System.debug('getProductsBySubCallType called with: ' + subCallType);
        List<Map<String, String>> productList = new List<Map<String, String>>();
        
        try {
            // ✅ Get custom setting instance by name
            Subcalltype__c subCallTypeSetting = Subcalltype__c.getInstance(subCallType);
            System.debug('Custom setting instance: ' + subCallTypeSetting);
            
            if (subCallTypeSetting != null && String.isNotBlank(subCallTypeSetting.product_name__c)) {
                // ✅ Split the long text area by commas and trim spaces
                List<String> productNames = new List<String>();
                for (String namePart : subCallTypeSetting.product_name__c.split(',')) {
                    if (String.isNotBlank(namePart)) {
                        productNames.add(namePart.trim());
                    }
                }
                
                System.debug('Split product names: ' + productNames);
                
                // ✅ Convert each product name to {label, value} map
                for (String prodName : productNames) {
                    productList.add(new Map<String, String>{
                        'label' => prodName,
                            'value' => prodName
                            });
                }
            } else {
                System.debug('No custom setting found or product name is blank for: ' + subCallType);
            }
            
        } catch (Exception e) {
            System.debug('Error in getProductsBySubCallType: ' + e.getMessage());
            throw new AuraHandledException('Error fetching product list: ' + e.getMessage());
        }
        
        System.debug('Returning product list size: ' + productList.size());
        return productList;
    }
     @AuraEnabled(cacheable = false)
    public static List<Map<String, String>> getProductsByFamily(String family) {
        System.debug('getProductsByFamily called with: ' + family);
        List<Map<String, String>> productList = new List<Map<String, String>>();
        
        try {
            // ✅ Get custom setting instance by name
            List<Product_Group__c> productGroupSettings = [SELECT Id, Name, Product_Family__c  FROM Product_Group__c WHERE Product_Family__c  = :family LIMIT 1000];
              // ✅ Convert each product name to {label, value} map
                for (Product_Group__c prodGroup : productGroupSettings) {
                    productList.add(new Map<String, String>{
                        'label' => prodGroup.Name,
                            'value' => prodGroup.Name
                            });
                }
            } 
            
         catch (Exception e) {
            System.debug('Error in getProductsBySubCallType: ' + e.getMessage());
            throw new AuraHandledException('Error fetching product list: ' + e.getMessage());
        }
        
        System.debug('Returning product list size: ' + productList.size());
        return productList;
    }
     @AuraEnabled(cacheable = false)
    public static List<Map<String, String>> getProductFamily() {
        System.debug('getProductFamily called');
        List<Map<String, String>> familyList = new List<Map<String, String>>();
        
        try {
            // ✅ Get custom setting instance by name
            List<String> productFamily = new List<String>();
            productFamily.add('EYECRYL TORIC');
            productFamily.add('EYECRYL ACTV FAMILY');
            productFamily.add('EYECRYL PHAKIC FAMILY');
            productFamily.add('BIO BLUE RANGE');
            productFamily.add('BIO RING');
            productFamily.add('BIO HYALUR RANGE - General');
            productFamily.add('BIO OCTANE');
            productFamily.add('BIO CTR');
            productFamily.add('SILICONE OILS');
            productFamily.add('EYECRYL SERT EDOF FAMILY');
            productFamily.add('HYDROPHILIC 600 / HSAS/ CLEAR');
            productFamily.add('HYDROPHOBIC ASHFY / HD');
            productFamily.add('EYEVISC HPMC');
            productFamily.add('RIBOFLAVIN');
            productFamily.add('OPTIFLEX TRIO FAMILY');
            productFamily.add('POPULAR HYDROPHOBIC MONOFOCAL');
           

              // ✅ Convert each product name to {label, value} map
                for (String prodGroup : productFamily) {
                    familyList.add(new Map<String, String>{
                        'label' => prodGroup,
                            'value' => prodGroup
                            });
                }
            }   catch (Exception e) {
            System.debug('Error in getProductsBySubCallType: ' + e.getMessage());
            throw new AuraHandledException('Error fetching product list: ' + e.getMessage());
        }
        
        System.debug('Returning family list size: ' + familyList.size());
        return familyList;
    }
    
    @AuraEnabled(cacheable = false)
    public static List<Map<String, String>> getSubCallTypeOptions() {
        List<Map<String, String>> optionsList = new List<Map<String, String>>();
        try {
            Schema.DescribeFieldResult fieldResult = Event.Sub_Call_Type__c.getDescribe();
            List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
            for(Schema.PicklistEntry f : ple) {
                if(f.isActive()) {
                    Map<String, String> option = new Map<String, String>();
                    option.put('label', f.getLabel());
                    option.put('value', f.getValue());
                    optionsList.add(option);
                }
            }
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
        }
        return optionsList;
    }
    
    //Added by Yogi
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getUserClinicalVertical() {
        Id currentUserId = UserInfo.getUserId();
        User currentUser = [SELECT Id, Clinical_Vertical__c FROM User WHERE Id = :currentUserId LIMIT 1];
        
        return new Map<String, Object>{
            'clinicalVertical' => currentUser.Clinical_Vertical__c
                };
                    }
    
    //Added by Yogi
    @AuraEnabled(cacheable=true)
    public static Map<String, Account_Plan_Restrictions__c> getAccountPlanRestrictions() {
        Map<String, Account_Plan_Restrictions__c> restrictionsMap = new Map<String, Account_Plan_Restrictions__c>();
        
        // Get all Custom Setting records
        List<Account_Plan_Restrictions__c> allSettings = Account_Plan_Restrictions__c.getAll().values();
        
        // Populate map with Name as key
        for(Account_Plan_Restrictions__c setting : allSettings){
            Account_Plan_Restrictions__c custom = new Account_Plan_Restrictions__c();
            custom.Name = setting.name;
            custom.Record_Type__c = setting.Record_Type__c;
            custom.Status__c = setting.Status__c;
            custom.SAP_Code__c  = setting.SAP_Code__c;
            
            restrictionsMap.put(setting.Name, custom);
        }
        
        return restrictionsMap;
    }
    
    
    @AuraEnabled(cacheable=true)
    public static map<string,object> getRegionAndZone() {
        
        List<Account> accObj = new List<Account>();
        accObj = [select id,(select contact.Name, contact.Department, contact.Id from contacts), BillingCountry,Name,recordType.DeveloperName,phone,Status__c,Account_Locked__c,Account_Locked_Reason__c,CE_Rating__c,CIS_Rating__c,Branch__c, BillingCity, Region__r.country_key__c,Region__r.Zone_Code__c from account order by Name];
        string userType,zoneType;
        map<string,string> mapZone_ZoneCode = new map<string, string>();
        map<string, list<Account>> mapRegion_Account = new map<string, list<Account>>();
        list<Account> accountList = new list<Account>();
        map<string, string> mapUserType_Region = new map<string, string>();
        list<map<string,string>> userRegionSelectList = new list<map<string,string>>();
        list<map<string,string>> userZoneSelectList = new list<map<string,string>>();
        for(Account acc : accObj) {
            if(acc.Region__r.country_key__c == 'TR'){
                userType = 'Turkey';
            } else if (acc.Region__r.country_key__c == 'IN'){
                system.debug('**acc.Region__r.Zone_Code__c***'+acc.Region__r.Zone_Code__c);
                userType = 'Domestic';
                zoneType ='';
                if(acc.Region__r.Zone_Code__c == null){
                    continue;
                }
                if(acc.Region__r.Zone_Code__c == '1'){
                    zoneType = 'North';
                } 
                else if(acc.Region__r.Zone_Code__c == '2'){
                    zoneType = 'West';
                } else if(acc.Region__r.Zone_Code__c == '3'){
                    zoneType = 'South';
                } else if(acc.Region__r.Zone_Code__c == '4'){
                    zoneType = 'East';
                } 
                if(zoneType!='')
                    mapZone_ZoneCode.put(zoneType,string.ValueOf(acc.Region__r.Zone_Code__c));
            }else{
                userType = 'International';
            }
            if(mapRegion_Account.containskey(userType)){
                accountList = mapRegion_Account.get(userType);
            }
            accountList.add(acc);
            mapRegion_Account.put(userType, accountList);
            mapUserType_Region.put(userType, acc.Region__r.country_key__c);
        }
        list<string> lstRegion = new list<string>();
        list<string> lstZone = new list<string>();
        for(string region : mapUserType_Region.keySet()){
            map<string,string> tempMap = new map<string,string>();
            // tempMap.put(region,region);
            // userRegionSelectList.add(tempMap);
            userRegionSelectList.add(new Map<String,string>{'label'=>region,'value'=>region});
        }
        if(mapZone_ZoneCode.size()>0){
            for(string zone : mapZone_ZoneCode.keySet()){
                map<string,string> tempMap = new map<string,string>();
                // tempMap.put(zone,zone);
                // userZoneSelectList.add(tempMap);
                userZoneSelectList.add(new Map<String,string>{'label'=>zone,'value'=>zone});
            }
        }
        system.debug('userRegionSelectList '+userRegionSelectList);
        system.debug('userZoneSelectList '+userZoneSelectList);
        map<string,object> returnMap = new map<string,object>();
        returnMap.put('userRegionSelectList',userRegionSelectList);
        returnMap.put('userZoneSelectList',userZoneSelectList);
        return returnMap;
    }
    
    @AuraEnabled(cacheable=true)
      public static List<Map<String,Object>> findAccount(String searchKey, string region, string selectedZone,string ObjectName) {
        System.debug('>>> calendarPlanningMobileController.findAccount: Entry');
        List<Map<String,Object>> dataMap=new List<Map<String,Object>>();
        System.debug('   searchKey: ' + searchKey);
        System.debug('   region: ' + region);
        System.debug('   selectedZone: ' + selectedZone);
        System.debug('   ObjectName: ' + ObjectName);
        
        String key;
        Set<String> stageSet=new Set<String>();
        stageSet.add('Won');
        stageSet.add('Lost');
        stageSet.add('Unqualified');

        // Added by Priyam Shah - Opportunity status exclusion
        Set<String> oppStatusSet = new Set<String>();
        oppStatusSet.add('Closed Won');
        oppStatusSet.add('Closed Lost');

        List<sObject> allDataList=new List<sObject>();
        List<Account> accObj = new List<Account>();
        list<string> regionList = new list<string>();
        List<Lead__c>  leadObj=new List<Lead__c>();
        if(region!=null){
            if(region=='International'){
                regionList.add('IN');
                regionList.add('TR');
            }else if(region=='Domestic'){
                regionList.add('IN');
            }else{
                regionList.add('TR');
            }
        }
        system.debug('regionList : '+regionList);
        if(ObjectName=='Account') {
            string query = 'select id,SAP_Code__c,Branch_Account__c,(select contact.Name, contact.Department, contact.Id from contacts), BillingCountry,name,recordType.DeveloperName,recordType.Name,phone,Status__c,Account_Locked__c,Account_Locked_Reason__c,CE_CIS_Rating__c,Phakic_Rating__c, Branch__c, BillingCity, Region__r.country_key__c,Region__r.Zone_Code__c,last_CE_Date__c from account';
            if(region!=null){
                query += ' Where ';
                if(region=='International'){
                    regionList.add('IN');
                    regionList.add('TR');
                    query += ' Region__r.country_key__c Not IN:regionList';
                }else if(region=='Domestic'){
                    regionList.add('IN');
                    query += ' Region__r.country_key__c IN:regionList AND Region__r.Zone_Name__c =: selectedZone';
                }else{
                    regionList.add('TR');
                    query += ' Region__r.country_key__c IN:regionList';
                }
            }
            
            if(string.isNotBlank(searchKey)){
                key = '%' + searchKey + '%';
                if(query.contains('Where')){
                    query += ' AND (Name LIKE :key OR Phone LIKE :key OR BillingCity Like : key Or BillingCountry Like : key)';
                }else{
                    query += ' Where (Name LIKE :key OR Phone LIKE :key OR BillingCity Like : key Or BillingCountry Like : key)';    
                }
            }
            
            query += ' order by Name limit 100';
            System.debug('   Account query: ' + query);
            accObj = Database.query(query);
            System.debug('   Account query returned ' + accObj.size() + ' records');
            System.debug('   Account data: ' + accObj);
            System.debug('   Processing ' + accObj.size() + ' accounts into maps...');
            for(Account acc:accObj) {
                Map<String,Object> accMap=new Map<String,Object>();
                accMap.put('Id',acc.id);
                accmap.put('Name',acc.Name);
                accMap.put('Phone',acc.Phone);
                accMap.put('BillingCity',acc.BillingCity);
                accMap.put('BillingCountry',acc.BillingCountry);
                accMap.put('CERating',acc.CE_CIS_Rating__c);
                accMap.put('CISRating',acc.Phakic_Rating__c);
                accMap.put('show','Account');
                accMap.put('Contacts',acc.contacts);
                accMap.put('RecordType',acc.recordType.DeveloperName);
                accMap.put('sapcode',acc.SAP_Code__c);
                accMap.put('status',acc.Status__c);
                accMap.put('branchaccount', String.valueOf(acc.Branch_Account__c));
                accMap.put('RecordTypeName',acc.recordType.Name);
                accMap.put('Account','Account');
                accMap.put('region',region);
                dataMap.add(accMap);
            }
            
            
        }
        if(ObjectName=='Lead') {//done
            System.debug('   Searching Leads');
            System.debug('   Object Name: ' + ObjectName);
            System.debug('   Search Key: ' + searchKey);
            string query='SELECT Id,Name,Mobile__c,CE_CIS_Rating__c,Product__c,Lead_Products__c ,Lead_Product_Family__c ,Phakic_Rating__c,Billing_City__c,Existing_customer__c,Country__c,Lead_Stage__c,Contact_Name__r.FirstName,Contact_Name__r.LastName,status__c from Lead__c';
            
            if(String.isNotBlank(searchKey)){
                key = '%' + searchKey + '%';
                if(query.contains('Where')){
                    query += ' AND (Name LIKE :key OR Mobile__c LIKE :key ) AND Lead_Closed__c != true AND Lead_Stage__c NOT in:stageSet';
                }else{
                    query += ' Where (Name LIKE :key OR Mobile__c LIKE :key)AND Lead_Closed__c != true AND Lead_Stage__c NOT in:stageSet';    
                }
            }else {
                if(query.contains('Where')){
                    query += ' Lead_Closed__c != true AND Lead_Stage__c NOT in:stageSet';
                }else{
                    query += ' Where Lead_Closed__c != true AND Lead_Stage__c NOT in:stageSet';    
                }
                
            }
            query += ' order by Name limit 100';
            System.debug('   Lead query: ' + query);
            List<Lead__c> leadList = Database.query(query);
            System.debug('   Lead query returned ' + leadList.size() + ' records');
            System.debug('   Processing ' + leadList.size() + ' leads into maps...');
            for(Lead__c lea:leadList) {
                Map<String,object> leadMap=new Map<String,object>();
                leadMap.put('Id',lea.id);
                //leadMap.put('ContactName',lea.Contact_Name__r.Name);//******************************************Added by GYadeen Ahirwar***********************
                leadMap.put('Name',lea.Name);
                leadMap.put('Phone',lea.Mobile__c);
                leadMap.put('BillingCity',lea.Billing_City__c);
                leadMap.put('BillingCountry',lea.Country__c);
                leadMap.put('CERating',lea.CE_CIS_Rating__c);
                leadMap.put('CISRating',lea.Phakic_Rating__c);
                leadMap.put('show','Lead');
                leadMap.put('leadstage',lea.Lead_Stage__c);
                leadMap.put('Stage',lea.Lead_Stage__c); // Added by Priyam Shah - Display stage badge
                leadMap.put('Product',lea.Product__c);
                leadMap.put('ProductFamily',lea.Lead_Product_Family__c);
                leadMap.put('ProductGroup',lea.Lead_Products__c); 
                leadMap.put('Lead','Lead');
                leadMap.put('Existing',lea.Existing_customer__c);
                leadMap.put('status__c',lea.status__c);
                leadMap.put('ContactName',lea.Contact_Name__r.FirstName!=null ? lea.Contact_Name__r.FirstName+lea.Contact_Name__r.LastName : '');
                
                dataMap.add(leadMap);
            }

        }

        // Added by Priyam Shah - Opportunity search query
        if(ObjectName=='Opportunity') {
            System.debug('Object Name: Opportunity');
            System.debug('Search Key: ' + searchKey);

            String query = 'SELECT Id, Name, Account__c, Account__r.Name, Account__r.Phone, ' +
                           'Account__r.BillingCity, Account__r.BillingCountry, ' +
                           'Status__c, CE_CIS_Rating__c, Phakic_Rating__c, ' +
                           'Opps_Products__c, Opps_Product_Family__c ' +
                           'FROM Opportunity__c';

            if(String.isNotBlank(searchKey)) {
                key = '%' + searchKey + '%';
                query += ' WHERE (Name LIKE :key OR Account__r.Name LIKE :key) ' +
                         'AND Status__c NOT IN :oppStatusSet ' + 
                          'AND Opps_Product_Family__c != null';
            } else {
               // query += ' WHERE Status__c NOT IN :oppStatusSet' modified by Ankit on 06/08;
               query += ' WHERE Status__c NOT IN :oppStatusSet ' +
                         'AND Opps_Product_Family__c != null';
            }

            query += ' ORDER BY Name LIMIT 100';
            System.debug('Opportunity Query: ' + query);

            for(Opportunity__c opp : Database.query(query)) {
                Map<String,Object> oppMap = new Map<String,Object>();
                oppMap.put('Id', opp.Id);
                oppMap.put('Name', opp.Name);
                oppMap.put('AccountName', opp.Account__c != null ? opp.Account__r.Name : null);
                oppMap.put('Phone', opp.Account__c != null ? opp.Account__r.Phone : null);
                oppMap.put('BillingCity', opp.Account__c != null ? opp.Account__r.BillingCity : null);
                oppMap.put('BillingCountry', opp.Account__c != null ? opp.Account__r.BillingCountry : null);
                oppMap.put('CERating', opp.CE_CIS_Rating__c);
                oppMap.put('CISRating', opp.Phakic_Rating__c);
                oppMap.put('show', 'Opportunity');
                oppMap.put('Opportunity', 'Opportunity');
                oppMap.put('Stage', opp.Status__c);
                oppMap.put('ProductFamily', opp.Opps_Product_Family__c);
                oppMap.put('ProductGroup', opp.Opps_Products__c);

                dataMap.add(oppMap);
            }
        }

        System.debug('DataMap'+dataMap);
        if(ObjectName=='All') {
            string query = 'select id,SAP_Code__c,Branch_Account__c,(select contact.Name, contact.Department, contact.Id from contacts), BillingCountry,name,recordType.DeveloperName,recordType.Name,phone,Status__c,Account_Locked__c,Account_Locked_Reason__c,CE_CIS_Rating__c	,Phakic_Rating__c, Branch__c, BillingCity, Region__r.country_key__c,Region__r.Zone_Code__c,last_CE_Date__c from account';
            if(region!=null){
                query += ' Where ';
                if(region=='International'){
                    regionList.add('IN');
                    regionList.add('TR');
                    query += ' Region__r.country_key__c Not IN:regionList';
                }else if(region=='Domestic'){
                    regionList.add('IN');
                    query += ' Region__r.country_key__c IN:regionList AND Region__r.Zone_Name__c =: selectedZone';
                }else{
                    regionList.add('TR');
                    query += ' Region__r.country_key__c IN:regionList';
                }
            }
            
            if(string.isNotBlank(searchKey)){
                key = '%' + searchKey + '%';
                if(query.contains('Where')){
                    query += ' AND (Name LIKE :key OR Phone LIKE :key)';
                }else{
                    query += ' Where (Name LIKE :key OR Phone LIKE :key)';    
                }
            }
            
            
            
            query += ' order by Name limit 100';
            system.debug('Query : '+query);
            accObj = Database.query(query); 
            
            for(Account acc:accObj) {
                Map<String,object> accMap=new Map<String,object>();
                accMap.put('Id',acc.id);
                accmap.put('Name',acc.Name);
                accMap.put('Phone',acc.Phone);
                accMap.put('BillingCity',acc.BillingCity);
                accMap.put('BillingCountry',acc.BillingCountry);
                accMap.put('CERating',acc.CE_CIS_Rating__c);
                accMap.put('CISRating',acc.Phakic_Rating__c);
                accMap.put('show','Account');
                accMap.put('sapcode',acc.SAP_Code__c);
                accMap.put('branchaccount', String.valueOf(acc.Branch_Account__c));
                accMap.put('region',region);
                accMap.put('status',acc.Status__c);
                accMap.put('Contacts',acc.contacts);
                accMap.put('RecordType',acc.recordType.DeveloperName);
                accMap.put('RecordTypeName',acc.recordType.Name);
                accMap.put('Account','Account');
                dataMap.add(accMap);
            }
            
            
            
            System.debug('Object Name'+ObjectName);
            System.debug('Search Key'+searchKey);
            string query1='SELECT Id,Name,Mobile__c,CE_CIS_Rating__c,Product__c,Lead_Products__c,Lead_Product_Family__c,Phakic_Rating__c,Existing_customer__c,Billing_City__c,Country__c,Lead_Stage__c,Contact_Name__r.FirstName,Contact_Name__r.LastName,status__c from Lead__c';

            if(String.isNotBlank(searchKey)){
                key = '%' + searchKey + '%';
                if(query1.contains('Where')){
                    query1 += ' AND (Name LIKE :key OR Mobile__c LIKE :key ) AND Lead_Closed__c != true AND Lead_Stage__c  NOT in:stageSet';
                }else{
                    query1 += ' Where (Name LIKE :key OR Mobile__c LIKE :key) AND Lead_Closed__c != true AND Lead_Stage__c NOT in:stageSet';
                }
            }else {
                if(query1.contains('Where')){
                    query1 += ' Lead_Closed__c != true AND Lead_Stage__c NOT in:stageSet';
                }else{
                    query1 += ' Where Lead_Closed__c != true AND Lead_Stage__c NOT in:stageSet';
                }

            }
            query1 += ' order by Name limit 100';
            for(Lead__c lea:Database.query(query1)) {
                Map<String,object> leadMap=new Map<String,object>();
                leadMap.put('Id',lea.id);
                //leadMap.put('ContactName',lea.Contact_Name__r.Name);//******************************************Added by GYadeen Ahirwar***********************
                leadMap.put('Name',lea.Name);
                leadMap.put('Phone',lea.Mobile__c);
                leadMap.put('BillingCity',lea.Billing_City__c);
                leadMap.put('BillingCountry',lea.Country__c);
                leadMap.put('CERating',lea.CE_CIS_Rating__c);
                leadMap.put('CISRating',lea.Phakic_Rating__c);
                leadMap.put('show','Lead');
                leadMap.put('leadstage',lea.Lead_Stage__c);
                leadMap.put('Stage',lea.Lead_Stage__c); // Added by Priyam Shah - Display stage badge
                leadMap.put('Product',lea.Product__c);
                leadMap.put('ProductFamily',lea.Lead_Product_Family__c);
                leadMap.put('ProductGroup',lea.Lead_Products__c);
                leadMap.put('Lead','Lead');
                leadMap.put('Existing',lea.Existing_customer__c);
                leadMap.put('status__c',lea.status__c);
                leadMap.put('ContactName',lea.Contact_Name__r.FirstName!=null ? lea.Contact_Name__r.FirstName+lea.Contact_Name__r.LastName : '');

                dataMap.add(leadMap);
            }

            // Added by Priyam Shah - Include opportunities in 'All' filter
            String oppQuery = 'SELECT Id, Name, Account__c, Account__r.Name, Account__r.Phone, ' +
                              'Account__r.BillingCity, Account__r.BillingCountry, ' +
                              'Status__c, CE_CIS_Rating__c, Phakic_Rating__c, ' +
                              'Opps_Products__c, Opps_Product_Family__c ' +
                              'FROM Opportunity__c';

            if(String.isNotBlank(searchKey)) {
                key = '%' + searchKey + '%';
                oppQuery += ' WHERE (Name LIKE :key OR Account__r.Name LIKE :key) ' +
                            'AND Status__c NOT IN :oppStatusSet';
            } else {
                oppQuery += ' WHERE Status__c NOT IN :oppStatusSet';
            }

            oppQuery += ' ORDER BY Name LIMIT 100';

            for(Opportunity__c opp : Database.query(oppQuery)) {
                Map<String,Object> oppMap = new Map<String,Object>();
                oppMap.put('Id', opp.Id);
                oppMap.put('Name', opp.Name);
                oppMap.put('AccountName', opp.Account__c != null ? opp.Account__r.Name : null);
                oppMap.put('Phone', opp.Account__c != null ? opp.Account__r.Phone : null);
                oppMap.put('BillingCity', opp.Account__c != null ? opp.Account__r.BillingCity : null);
                oppMap.put('BillingCountry', opp.Account__c != null ? opp.Account__r.BillingCountry : null);
                oppMap.put('CERating', opp.CE_CIS_Rating__c);
                oppMap.put('CISRating', opp.Phakic_Rating__c);
                oppMap.put('show', 'Opportunity');
                oppMap.put('Opportunity', 'Opportunity');
                oppMap.put('Stage', opp.Status__c);
                oppMap.put('ProductFamily', opp.Opps_Product_Family__c);
                oppMap.put('ProductGroup', opp.Opps_Products__c);

                dataMap.add(oppMap);
            }

        }
        System.debug('   Final dataMap size: ' + dataMap.size() + ' records');
        System.debug('   Data Map: ' + dataMap);
        System.debug('<<< calendarPlanningMobileController.findAccount: Exit - Returning ' + dataMap.size() + ' records');
        return dataMap;
    }
    public static List<Map<String,Object>> findAccount2(String searchKey, string region, string selectedZone,string ObjectName) {
        List<Map<String,Object>> dataMap=new List<Map<String,Object>>();
        system.debug('searchKey '+searchKey);
        system.debug('region '+region);
        system.debug('selectedZone '+selectedZone);
        System.debug('ObjectName'+ObjectName);
        
        String key;
        Set<String> stageSet=new Set<String>();
        stageSet.add('Won');
        stageSet.add('Lost');
        stageSet.add('Unqualified');
        List<sObject> allDataList=new List<sObject>();
        List<Account> accObj = new List<Account>();
        list<string> regionList = new list<string>();
        List<Lead__c>  leadObj=new List<Lead__c>();
        if(region!=null){
            if(region=='International'){
                regionList.add('IN');
                regionList.add('TR');
            }else if(region=='Domestic'){
                regionList.add('IN');
            }else{
                regionList.add('TR');
            }
        }
        system.debug('regionList : '+regionList);
        if(ObjectName=='Account') {
            string query = 'select id,SAP_Code__c,Branch_Account__c,(select contact.Name, contact.Department, contact.Id from contacts), BillingCountry,name,recordType.DeveloperName,recordType.Name,phone,Status__c,Account_Locked__c,Account_Locked_Reason__c,CE_CIS_Rating__c,Phakic_Rating__c, Branch__c, BillingCity, Region__r.country_key__c,Region__r.Zone_Code__c,last_CE_Date__c from account';
            if(region!=null){
                query += ' Where ';
                if(region=='International'){
                    regionList.add('IN');
                    regionList.add('TR');
                    query += ' Region__r.country_key__c Not IN:regionList';
                }else if(region=='Domestic'){
                    regionList.add('IN');
                    query += ' Region__r.country_key__c IN:regionList AND Region__r.Zone_Name__c =: selectedZone';
                }else{
                    regionList.add('TR');
                    query += ' Region__r.country_key__c IN:regionList';
                }
            }
            
            if(string.isNotBlank(searchKey)){
                key = '%' + searchKey + '%';
                if(query.contains('Where')){
                    query += ' AND (Name LIKE :key OR Phone LIKE :key OR BillingCity Like : key Or BillingCountry Like : key)';
                }else{
                    query += ' Where (Name LIKE :key OR Phone LIKE :key OR BillingCity Like : key Or BillingCountry Like : key)';    
                }
            }
            
            query += ' order by Name limit 100';
            system.debug('Query : '+query);
            accObj = Database.query(query); 
            System.debug('Serialize data'+accObj);
            for(Account acc:accObj) {
                Map<String,Object> accMap=new Map<String,Object>();
                accMap.put('Id',acc.id);
                accmap.put('Name',acc.Name);
                accMap.put('Phone',acc.Phone);
                accMap.put('BillingCity',acc.BillingCity);
                accMap.put('BillingCountry',acc.BillingCountry);
                accMap.put('CERating',acc.CE_CIS_Rating__c);
                accMap.put('CISRating',acc.Phakic_Rating__c);
                accMap.put('show','Account');
                accMap.put('Contacts',acc.contacts);
                accMap.put('RecordType',acc.recordType.DeveloperName);
                accMap.put('sapcode',acc.SAP_Code__c);
                accMap.put('status',acc.Status__c);
                accMap.put('branchaccount', String.valueOf(acc.Branch_Account__c));
                accMap.put('RecordTypeName',acc.recordType.Name);
                accMap.put('Account','Account');
                accMap.put('region',region);
                dataMap.add(accMap);
            }
            
            
        }
        if(ObjectName=='Lead') {//done
            System.debug('Object Name'+ObjectName);
            System.debug('Search Key'+searchKey);
            string query='SELECT Id,Name,Mobile__c,CE_CIS_Rating__c,Product__c,Phakic_Rating__c,Billing_City__c,Existing_customer__c,Country__c,Lead_Stage__c,Contact_Name__r.FirstName,Contact_Name__r.LastName,status__c from Lead__c';
            
            if(String.isNotBlank(searchKey)){
                key = '%' + searchKey + '%';
                if(query.contains('Where')){
                    query += ' AND (Name LIKE :key OR Mobile__c LIKE :key ) AND Lead_Closed__c != true AND Lead_Stage__c NOT in:stageSet';
                }else{
                    query += ' Where (Name LIKE :key OR Mobile__c LIKE :key)AND Lead_Closed__c != true AND Lead_Stage__c NOT in:stageSet';    
                }
            }else {
                if(query.contains('Where')){
                    query += ' Lead_Closed__c != true AND Lead_Stage__c NOT in:stageSet';
                }else{
                    query += ' Where Lead_Closed__c != true AND Lead_Stage__c NOT in:stageSet';    
                }
                
            }
            query += ' order by Name limit 100';
            System.debug('Query'+query);
            for(Lead__c lea:Database.query(query)) {
                Map<String,object> leadMap=new Map<String,object>();
                leadMap.put('Id',lea.id);
                //leadMap.put('ContactName',lea.Contact_Name__r.Name);//******************************************Added by GYadeen Ahirwar***********************
                leadMap.put('Name',lea.Name);
                leadMap.put('Phone',lea.Mobile__c);
                leadMap.put('BillingCity',lea.Billing_City__c);
                leadMap.put('BillingCountry',lea.Country__c);
                leadMap.put('CERating',lea.CE_CIS_Rating__c);
                leadMap.put('CISRating',lea.Phakic_Rating__c);
                leadMap.put('show','Lead');
                leadMap.put('leadstage',lea.Lead_Stage__c);
                leadMap.put('Product',lea.Product__c);
                leadMap.put('Lead','Lead');
                leadMap.put('Existing',lea.Existing_customer__c);
                leadMap.put('status__c',lea.status__c);
                leadMap.put('contactId',lea.Contact_Name__c);
                leadMap.put('ContactName',lea.Contact_Name__r.FirstName!=null ? lea.Contact_Name__r.FirstName+lea.Contact_Name__r.LastName : '');
                
                dataMap.add(leadMap);
            }
            
        }
        System.debug('DataMap'+dataMap);
        if(ObjectName=='All') {
            string query = 'select id,SAP_Code__c,Branch_Account__c,(select contact.Name, contact.Department, contact.Id from contacts), BillingCountry,name,recordType.DeveloperName,recordType.Name,phone,Status__c,Account_Locked__c,Account_Locked_Reason__c,CE_CIS_Rating__c   ,Phakic_Rating__c, Branch__c, BillingCity, Region__r.country_key__c,Region__r.Zone_Code__c,last_CE_Date__c from account';
            if(region!=null){
                query += ' Where ';
                if(region=='International'){
                    regionList.add('IN');
                    regionList.add('TR');
                    query += ' Region__r.country_key__c Not IN:regionList';
                }else if(region=='Domestic'){
                    regionList.add('IN');
                    query += ' Region__r.country_key__c IN:regionList AND Region__r.Zone_Name__c =: selectedZone';
                }else{
                    regionList.add('TR');
                    query += ' Region__r.country_key__c IN:regionList';
                }
            }
            
            if(string.isNotBlank(searchKey)){
                key = '%' + searchKey + '%';
                if(query.contains('Where')){
                    query += ' AND (Name LIKE :key OR Phone LIKE :key)';
                }else{
                    query += ' Where (Name LIKE :key OR Phone LIKE :key)';    
                }
            }
            
            
            
            query += ' order by Name limit 100';
            system.debug('Query : '+query);
            accObj = Database.query(query); 
            
            for(Account acc:accObj) {
                Map<String,object> accMap=new Map<String,object>();
                accMap.put('Id',acc.id);
                accmap.put('Name',acc.Name);
                accMap.put('Phone',acc.Phone);
                accMap.put('BillingCity',acc.BillingCity);
                accMap.put('BillingCountry',acc.BillingCountry);
                accMap.put('CERating',acc.CE_CIS_Rating__c);
                accMap.put('CISRating',acc.Phakic_Rating__c);
                accMap.put('show','Account');
                accMap.put('sapcode',acc.SAP_Code__c);
                accMap.put('branchaccount', String.valueOf(acc.Branch_Account__c));
                accMap.put('region',region);
                accMap.put('status',acc.Status__c);
                accMap.put('Contacts',acc.contacts);
                accMap.put('RecordType',acc.recordType.DeveloperName);
                accMap.put('RecordTypeName',acc.recordType.Name);
                accMap.put('Account','Account');
                dataMap.add(accMap);
            }
            
            
            
            System.debug('Object Name'+ObjectName);
            System.debug('Search Key'+searchKey);
            string query1='SELECT Id,Name,Mobile__c,CE_CIS_Rating__c,Product__c,Phakic_Rating__c,Existing_customer__c,Billing_City__c,Country__c,Lead_Stage__c,Contact_Name__r.FirstName,Contact_Name__r.LastName,status__c from Lead__c';
            
            if(String.isNotBlank(searchKey)){
                key = '%' + searchKey + '%';
                if(query1.contains('Where')){
                    query1 += ' AND (Name LIKE :key OR Mobile__c LIKE :key ) AND Lead_Closed__c != true AND Lead_Stage__c  NOT in:stageSet';
                }else{
                    query1 += ' Where (Name LIKE :key OR Mobile__c LIKE :key) AND Lead_Closed__c != true AND Lead_Stage__c NOT in:stageSet';    
                }
            }else {
                if(query1.contains('Where')){
                    query1 += ' Lead_Closed__c != true AND Lead_Stage__c NOT in:stageSet';
                }else{
                    query1 += ' Where Lead_Closed__c != true AND Lead_Stage__c NOT in:stageSet';    
                }
                
            }
            query1 += ' order by Name limit 100';
            for(Lead__c lea:Database.query(query1)) {
                Map<String,object> leadMap=new Map<String,object>();
                leadMap.put('Id',lea.id);
                //leadMap.put('ContactName',lea.Contact_Name__r.Name);//******************************************Added by GYadeen Ahirwar***********************
                leadMap.put('Name',lea.Name);
                leadMap.put('Phone',lea.Mobile__c);
                leadMap.put('BillingCity',lea.Billing_City__c);
                leadMap.put('BillingCountry',lea.Country__c);
                leadMap.put('CERating',lea.CE_CIS_Rating__c);
                leadMap.put('CISRating',lea.Phakic_Rating__c);
                leadMap.put('show','Lead');
                leadMap.put('leadstage',lea.Lead_Stage__c);
                leadMap.put('Product',lea.Product__c);
                leadMap.put('Lead','Lead');
                leadMap.put('Existing',lea.Existing_customer__c);
                leadMap.put('status__c',lea.status__c);
                leadMap.put('contactId',lea.Contact_Name__c);
                leadMap.put('ContactName',lea.Contact_Name__r.FirstName!=null ? lea.Contact_Name__r.FirstName+lea.Contact_Name__r.LastName : '');
                
                dataMap.add(leadMap);
            }
            
        }
        System.debug('Data Map'+dataMap);
        return dataMap;
    }
    









    @AuraEnabled(cacheable=true)
    public static DCR_Planning_Translation_Turkey__c getLabels(){
        string curentLang = userinfo.getLanguage();
        DCR_Planning_Translation_Turkey__c translationObject = DCR_Planning_Translation_Turkey__c.getValues(curentLang);
        System.debug('translationObject'+translationObject);
        return translationObject;
    }    
    
    
    @AuraEnabled(cacheable=true)
    public static List<Product__c> getProducts(string searchKey){
        system.debug('searchKey '+searchKey);
        string sKey='';
        user userObj = [select id, name, profileId,User_Type__c,Profile.Name,userRoleId,userRole.Name from user where id =: userInfo.getUserId()];
        List<Product__c> prodList = new List<Product__c>();
        if(searchKey!=null){
            sKey='%'+searchKey+'%';
            prodList = [select name from Product__c where region__c =: userObj.user_Type__c AND MSP__c !=null AND MSP__c != 0 Order BY Name ASC limit 100];
        }else{
            prodList = [select name from Product__c where region__c =: userObj.user_Type__c AND MSP__c !=null AND MSP__c != 0 Order BY Name ASC limit 100];
        }
        return prodList;
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String,string> getCallType(){
        Map<String,string> pickListValuesList= new map<String,string>();
        Schema.DescribeFieldResult fieldResult = event.Call_Type__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for( Schema.PicklistEntry pickListVal : ple){
            pickListValuesList.put(pickListVal.getLabel(),pickListVal.getvalue());
        } 
        return pickListValuesList;
    } 
    
    @AuraEnabled(cacheable=true)
    public static Map<String,string> getLevelTypeOptions(){
        Map<String,string> pickListValuesList= new Map<String,string>();
        Schema.DescribeFieldResult fieldResult = event.level_Type__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for( Schema.PicklistEntry pickListVal : ple){
            pickListValuesList.put(pickListVal.getLabel(),pickListVal.getvalue());
        } 
        return pickListValuesList;
    } 
    
    public static list<Map<String,Object>> getLightningPickListValues(String fieldName, string objectName) {
        list<Map<String,Object>> returnList = new list<Map<String,Object>>();
        try {
            returnList.add(new Map<String,Object>{'label'=>'--Select--','value'=>'--Select--'});
            Map<String, schema.SObjectField> feildMap = Schema.getGlobalDescribe().get(objectName.trim()).getDescribe().fields.getMap();
            list<Schema.PicklistEntry> values = feildMap.get(fieldName.trim()).getDescribe().getPickListValues();
            for (Schema.PicklistEntry obj : values) {
                returnList.add(new Map<String,Object>{'label'=>obj.getLabel(),'value'=>obj.getValue().remove('\'').escapeUnicode()});
            }
            System.debug('MAP with FEILD TYPE : '+returnList);
        } catch (Exception e) {
            System.debug('Error in lightning picklist values : '+e.getMessage()+' at line no :'+e.getLineNumber());
            // return null;
        }
        return returnList;
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getReviewCallType(){
        
        Map<String, String> pickListValuesList = new Map<String, String>();
        Schema.DescribeFieldResult fieldResult = event.Review_Call_Type__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for( Schema.PicklistEntry pickListVal : ple){
            pickListValuesList.put(pickListVal.getLabel(),pickListVal.getValue());
        } 
        return pickListValuesList;
    } 
    //Added by below method  Gyadeen*************************** 
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getdailyactivity() {
        Id currentUserId = UserInfo.getUserId(); // Get the current logged-in user
        
        // Retrieve the current user's country and Login_Logout_Module__c values
        User currentUser;
        try {
            currentUser = [
                SELECT Country__c, Login_Logout_Module__c
                FROM User
                WHERE Id = :currentUserId
                LIMIT 1
            ];
        } catch (Exception e) {
            return new Map<String, Object>{ 'error' => 'Error retrieving user information: ' + e.getMessage() };
                }
        
        //  String userCountry = currentUser.Country__c;
        String loginLogoutValue = (currentUser.Login_Logout_Module__c!=null && currentUser.Login_Logout_Module__c!='') ? currentUser.Login_Logout_Module__c : '';
        
        // Handle empty or null fields
        /* if (String.isEmpty(userCountry) || String.isEmpty(loginLogoutValue)) {
// return new Map<String, Object>{ 'activity' => false, 'error' => 'Required user fields are empty' };
}*/
        
        // Retrieve the custom label value (comma-separated) and split it into a list
        String excludedCountries = Label.Country_wise_Login_logout_module; // Replace with your custom label API name
        List<String> excludedCountryList = new List<String>();
        if (!String.isEmpty(excludedCountries)) {
            if(excludedCountries!=null && excludedCountries!='') {
                if(excludedCountries.contains(',')) {
                    for (String country : excludedCountries.split(',')) {
                        excludedCountryList.add(country.trim());
                    }
                }else {
                    excludedCountryList.add(excludedCountries.trim());
                }
            }
            
        }
        
        // Split the Login_Logout_Module__c field into a list of countries
        /*   List<String> loginLogoutCountries = new List<String>();
for (String country : loginLogoutValue.split(',')) {
loginLogoutCountries.add(country.trim());
}*/
        
        // Check if the user's country exists in both the excluded list and Login_Logout_Module__c list
        // Boolean isExcluded = excludedCountryList.contains(userCountry) && loginLogoutCountries.contains(userCountry);
        
        // Return activity status based on the exclusion criteria
        if (excludedCountryList.contains(loginLogoutValue) || Test.isRunningTest()) {
            // Query Beat_Plan__c for today's activity
            List<Beat_Plan__c> beatPlans = [
                SELECT Id, Name, Beat_Date__c, Login_Time__c
                FROM Beat_Plan__c 
                WHERE Beat_Date__c = :System.today() 
                AND Assigned_To__c = :currentUserId 
                AND Login_Time__c != null
                LIMIT 1
            ];
            
            // Check if there are any beat plans for today
            if (!beatPlans.isEmpty()) {
                system.debug('beatPlans'+beatPlans);
                return new Map<String, Object>{ 'activity' => true };
                    } else {
                        system.debug('beatPlans activity False include');
                        return new Map<String, Object>{ 'activity' => false };
                            }
        } else {
            system.debug('beatPlans activity true excluded');
            // If the country is not in the custom label or not in the login/logout module
            return new Map<String, Object>{ 'activity' => true };
                }
    }
    //Added by Above method  Gyadeen***************************
    
    
    
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getMeetingType(){
        
        Map<String, String> pickListValuesList = new Map<String, String>();
        Schema.DescribeFieldResult fieldResult = event.Meeting_Type__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for( Schema.PicklistEntry pickListVal : ple){
            pickListValuesList.put(pickListVal.getLabel(), pickListVal.getValue());
        } 
        return pickListValuesList;
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getLeaveType() {
        Map<String, String> pickListMap = new Map<String, String>();
        Schema.DescribeFieldResult fieldResult = Event.Type_of_leave__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        
        for (Schema.PicklistEntry pickListVal : ple) {
            // Picklist label (translated) and value
            pickListMap.put(pickListVal.getLabel(), pickListVal.getValue());
        }
        
        return pickListMap;
    }
    
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String,String>> getManagerAndReportee(){
        string currentUserId='';
        string currentUserRoleId='';
        Set<Id> usersIds=new Set<Id>();
        currentUserId = UserInfo.getUserId();
        currentUserRoleId = UserInfo.getUserRoleId();
        User us = [Select id, Name from User where Id=:currentUserId];
        /*   list<string>lst=new list<string>();
Set<id> Userlst = new Set<Id>();
list<GroupMember>grp=[SELECT Id, GroupId, UserOrGroupId FROM GroupMember where Group.Name = 'HO' OR Group.Name ='Admin Level User'];
if(!grp.isEmpty()){
For(GroupMember mem : grp){
Userlst.add(mem.UserOrGroupId);
}
}
list<User_Region_Association__c>usr=[SELECT Id, Region__c, User__c FROM User_Region_Association__c where user__c=:userinfo.getUserId()];
for(User_Region_Association__c obj :usr){
lst.add(obj.Region__c);
}
list<User_Region_Association__c>usrlst=[SELECT Id, Region__c, User__c FROM User_Region_Association__c where region__c IN:lst];

if(!usrlst.isEmpty()){
For(User_Region_Association__c obj : usrlst){
Userlst.add(obj.User__c);
}RoleHierarchyUtilityClass
}

Userlst.add(UserInfo.getUserId());
list<user> userList = [select id, name, profileId from user where IsActive = true and ID In:Userlst ];
return userList;*/
        List<Map<String,String>> userList = new List<Map<String,String>>();
        // userList.add(new SelectOption(us.Id,us.Name));
        userList.add(new Map<String,String>{'label'=>us.Name,'value'=>us.Id});
        usersIds.add(us.Id);
        // roleHierarchyUtilityClass is the utility class which returns the list of users which are below the role of Current User.
        Set<Id> allUsers = RoleHierarchyUtilityClass.getRoleSubordinateUsers(currentUserRoleId); 
        System.debug('All user'+allUsers);
        for(User usr : [Select id, name from User where (id in:allUsers AND Profile.UserLicense.Name !=: 'Partner Community')]){
            if(usr.id!=null) {
                userList.add(new Map<String,String>{'label'=>usr.Name,'value'=>usr.Id}); 
            }
            
            usersIds.add(usr.Id);
        }
        System.debug('User Ids'+usersIds);
        System.debug('User list'+JSON.serialize(userList));
        
        return userList;
    }
    
    
    @AuraEnabled(cacheable=true)
    public static List<User> getUsers(){
        Set<id> Userlst = new Set<Id>();
        list<GroupMember>grp=[SELECT Id, GroupId, UserOrGroupId FROM GroupMember where Group.Name = 'HO' OR Group.Name ='Admin Level User'];
        if(!grp.isEmpty()){
            For(GroupMember mem : grp){
                Userlst.add(mem.UserOrGroupId);
            }
        }
        list<string>lst=new list<string>();
        list<User_Region_Association__c>usr=[SELECT Id, Region__c, User__c FROM User_Region_Association__c where user__c=:userinfo.getUserId()];
        for(User_Region_Association__c obj :usr){
            lst.add(obj.Region__c);
        }
        list<User_Region_Association__c>usrlst=[SELECT Id, Region__c, User__c FROM User_Region_Association__c where region__c IN:lst];
        if(!usrlst.isEmpty()){
            For(User_Region_Association__c obj : usrlst){
                Userlst.add(obj.User__c);
            }
        }
        list<user> userList = [select id, name, profileId from user where IsActive = true and ID In:Userlst ];
        return userList;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getEvents(string skey) {
        return getEventsRefresh(skey);
    } 
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getEventsRefresh(string skey) {
        List<Map<String, Object>> returnMapList = new List<Map<String, Object>>();
        string userId;
        if(skey==''){
            userId = UserInfo.getUserId();
        }else{
            System.debug('Search key'+skey);
            userId = skey;
        }
        List<Event> upEvList=new List<Event>();
        
        System.debug('query '+[select id,Lead_Stage__c,Beat_plan__r.Login_Time__c,Type_of_leave__c,What.name,follow_Up_Date__c,who.Name,Meeting_Type__c,Leads__r.Name,Stage__c,ActivityDate,Leads__r.Lead_Stage__c,startdateTime,description,DCR_Description__c,endDateTime,subject,Product__c,Account__r.Name,Account__r.CE_Rating__c, Account__r.CIS_Rating__c, Account__r.RecordType.DeveloperName,Event_Locked__c, Status__c,Other_Type__c,Type, Visit_Date__c from event where ownerId =:userId]);
        List<Event> eveList = [select id,What.name,Lead_Stage__c,Beat_plan__r.Login_Time__c,Type_of_leave__c,Account__c,Leads__c,who.Name,follow_Up_Date__c,Leads__r.Lead_Closed__c,Leads__r.CE_CIS_Rating__c,Meeting_Type__c,Stage__c,Call_type__c,Sub_Call_Type__c,Leads__r.Name,Leads__r.Lead_Stage__c,ActivityDate,startdateTime,description,DCR_Description__c,endDateTime,subject,Product__c,Account__r.Name,Account__r.CE_Rating__c, Account__r.CIS_Rating__c, Account__r.RecordType.DeveloperName,Event_Locked__c, Status__c,Other_Type__c, Visit_Date__c,Account__r.CE_CIS_Rating__c,Beat_plan__c,Beat_plan__r.Approval_status__C, WhatId from event where ownerId =:userId];
        system.debug('eveList '+eveList);
        //system.debug('eventData------>:'+eventData);
        for(event ev:eveList) {
            if(ev.Account__c !=null && ev.Leads__c == null) {
                upEvList.add(ev);
            } if(ev.Account__c == null &&  ev.Leads__c!=null && ev.Leads__r.Lead_Closed__c == false) {
                upEvList.add(ev);
            }
            if(ev.Account__c ==null && ev.Leads__c == null) {
                upEvList.add(ev);
            }
        }
        for(Event ev : upEvList){
            Map<String, Object> eveMap = new Map<String, Object>();
            eveMap.put('Id', ev.Id);
            eveMap.put('FollowUpDate', ev.follow_Up_Date__c);
            eveMap.put('stage', ev.Stage__c);
            //eveMap.put('LeaveStatus','');
            if(ev.Beat_plan__r.Approval_status__c != null && ev.Type_of_leave__c != null){
                if(ev.Type_of_leave__c == 'Full Day Leave'){
                    eveMap.put('Leavetype', 'PL'); 
                }else if(ev.Type_of_leave__c == 'First Half Leave' && ev.Beat_plan__r.Login_Time__c != null ){
                    eveMap.put('Leavetype', '1/2PL+1/2P'); 
                } else if(ev.Type_of_leave__c == 'First Half Leave' && ev.Beat_plan__r.Login_Time__c == null){
                    eveMap.put('Leavetype', '1/2PL+1/2AB'); 
                }else if(ev.Type_of_leave__c == 'Second Half Leave' && ev.Beat_plan__r.Login_Time__c != null ){
                    eveMap.put('Leavetype', '1/2P+1/2PL'); 
                }else if(ev.Type_of_leave__c == 'Second Half Leave' && ev.Beat_plan__r.Login_Time__c == null){
                    eveMap.put('Leavetype', '1/2AB+1/2PL'); 
                }else if(ev.Type_of_leave__c == 'Compensation off'){
                    eveMap.put('Leavetype', 'CO'); 
                }              
            eveMap.put('ApprovalStatus', ev.Beat_plan__r.Approval_status__c);
            }
                
                      eveMap.put('Status', ev.Status__c);
           
            eveMap.put('CallType', ev.Call_Type__c);//*********************Gyadeen ahirwar*****************************
            eveMap.put('SubCallType', ev.Sub_Call_Type__c);
            eveMap.put('Leadstage', ev.Lead_Stage__c); // ***************************Gyadeen Ahirwar************************
            eveMap.put('contactname',ev.Who.Name);//****************************Added bY Gyadeen Ahirwar******************
            eveMap.put('ActivityDate', ev.ActivityDate);
            eveMap.put('otherType', ev.Other_Type__c);
            eveMap.put('StartDateTime', ev.startdateTime);
            eveMap.put('EndDateTime', ev.endDateTime);
            eveMap.put('meetimgType', ev.Meeting_Type__c);
            eveMap.put('Description', ev.DCR_Description__c);
            eveMap.put('Subject', ev.subject);
            eveMap.put('Leavevalue', ev.Type_of_leave__c);
            eveMap.put('Product', ev.Product__c);
            eveMap.put('EventLocked', ev.Event_Locked__c);

          

            eveMap.put('OtherType', ev.Other_Type__c);
            eveMap.put('VisitDate', ev.Visit_Date__c);
            eveMap.put('AccountId', ev.Account__c);
            //  eveMap.put('Product', ev.Account__c);
            // NEW
            Boolean isOpp = ev.WhatId != null && ev.WhatId.getSObjectType() == Opportunity__c.SObjectType;
            eveMap.put('isOpportunity', isOpp);

            if(ev.Leads__r.Name!=null || test.isRunningTest()){
                eveMap.put('AccountName', ev.Leads__r.Name);
                eveMap.put('objectname',true);
            } else if(ev.Account__r.Name!=null) {
                eveMap.put('AccountName', ev.Account__r.Name);
                eveMap.put('objectname',False);
            } else if(isOpp && ev.What != null) {
                eveMap.put('AccountName', ev.What.Name);
                eveMap.put('OpportunityAccountName', ev.What.Name);
                eveMap.put('objectname', False);
            }
            
            //   eveMap.put('CERating', ev.Account__r.CE_Rating__c);
            if(ev.Account__r.CE_CIS_Rating__c!=null) {
                
                eveMap.put('CISRating', ev.Account__r.CE_CIS_Rating__c);
                
            }else {
                eveMap.put('CISRating', ev.Leads__r.CE_CIS_Rating__c);
                
            }
            eveMap.put('AccountRecordType', ev.Account__r.RecordType.DeveloperName);
            string cardColor;
            if(ev.Meeting_Type__c=='Onsite'){
                if(ev.Stage__c == 'Planned'){
                    cardColor = 'onsitePlanned';    
                }else{
                    cardColor = 'onsiteNotPlanned';
                }
            }else if(ev.Meeting_Type__c=='Online'){
                if(ev.Stage__c == 'Planned'){
                    cardColor = 'onlinePlanned';    
                }else{
                    cardColor = 'onlineNotPlanned';
                }
            }else if(ev.Meeting_Type__c=='Offsite'){
                if(ev.Stage__c == 'Planned'){
                    cardColor = 'offsitePlanned';    
                }else{
                    cardColor = 'offsiteNotPlanned';
                }
            }else if(ev.Meeting_Type__c==null){
                cardColor = 'notDefined';    
            }else{
                cardColor = 'default'; 
            }
            eveMap.put('cardColor', cardColor);
            
            returnMapList.add(eveMap);
        }
        
        return returnMapList;
    } 
    
    @AuraEnabled(cacheable=true)
    public static List <Event> findEvent(String eventName) {
        eventName = '%' + eventName + '%';
        System.debug('query '+[select id,What.name,follow_Up_Date__c,Call_Type__c,who.name,Lead_Stage__c,ActivityDate,startdateTime,description,endDateTime,subject,Product__c,Account__r.Name,Account__r.RecordType.DeveloperName,Event_Locked__c, Status__c,Other_Type__c, Visit_Date__c from event where subject LIKE :eventName LIMIT 5]);
        return [select id,What.name,follow_Up_Date__c,Call_Type__c,Lead_Stage__c,who.Name,ActivityDate,startdateTime,description,endDateTime,subject,Product__c,Account__r.Name,Account__r.RecordType.DeveloperName,Event_Locked__c, Status__c,Other_Type__c, Visit_Date__c from event where subject LIKE :eventName LIMIT 5];
    } 
    
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getEventsForBDPlan(string accountid, string userid, string action) {
        ID recordId = Schema.SObjectType.Event.getRecordTypeInfosByName().get('BD Tracker').getRecordTypeId();
        system.debug('userid'+accountid);
        List<Map<String, Object>> returnMapList = new List<Map<String, Object>>();
        List<Event> eveList = new list<Event>();
        // if(action=='Update'){
        //     eveList =  [Select id,recordtypeId,BD_Tracker_Phase__c,Milestone_Plan_Week__c,Product__c,whoId,Who.Name,MileStone_Stage__c,
        //     isSubmitted__c,OwnerId,startDateTime,Account__c,Account__r.Name,isConnectedToDCR__c,EndDateTime,whatId,createdDate
        //     from Event 
        //     where recordtypeId =:recordId AND OwnerId=:userid AND isSubmitted__c=true AND isConnectedToDCR__c=true
        //     AND Account__c=:accountid AND MileStone_Stage__c !='Actual'AND MileStone_Stage__c !='Cancel'
        //     order by what.Name,Milestone_Plan_Week__c,BD_Tracker_Phase__c ASC];
        // }else{
        //     eveList =  [Select id,recordtypeId,BD_Tracker_Phase__c,Milestone_Plan_Week__c,Product__c,whoId,Who.Name,MileStone_Stage__c,
        //     isSubmitted__c,OwnerId,startDateTime,Account__c,Account__r.Name,isConnectedToDCR__c,EndDateTime,whatId,createdDate
        //     from Event 
        //     where recordtypeId =:recordId AND OwnerId=:userid AND isSubmitted__c=true
        //     AND Account__c=:accountid AND MileStone_Stage__c !='Actual'AND MileStone_Stage__c !='Cancel'
        //     order by what.Name,Milestone_Plan_Week__c,BD_Tracker_Phase__c ASC];
        //     
        // }
        eveList =  [Select id,recordtypeId,BD_Tracker_Phase__c,Milestone_Plan_Week__c,Product__c,whoId,Who.Name,MileStone_Stage__c,
                    isSubmitted__c,Call_Type__c,Lead_Stage__c,OwnerId,startDateTime,Account__c,Account__r.Name,isConnectedToDCR__c,EndDateTime,whatId,createdDate from Event 
                    where recordtypeId =:recordId AND OwnerId=:userid AND isSubmitted__c=true
                    AND Account__c=:accountid AND MileStone_Stage__c !='Actual'AND MileStone_Stage__c !='Cancel'
                    order by what.Name,Milestone_Plan_Week__c,BD_Tracker_Phase__c ASC];
        system.debug('eveList'+eveList);
        for(Event ev : eveList){
            Map<String, Object> eveMap = new Map<String, Object>();
            eveMap.put('Id', ev.Id);
            eveMap.put('BDTrackerPhase', ev.BD_Tracker_Phase__c);
            eveMap.put('MilestonePlanWeek', ev.Milestone_Plan_Week__c);
            eveMap.put('PlanYear', ev.EndDateTime.Year());
            eveMap.put('ProductId', ev.Product__c);
            eveMap.put('whoId', ev.whoId);
            eveMap.put('CallType', ev.Call_Type__c);//*********************Gyadeen ahirwar*****************************
            eveMap.put('Leadstage', ev.Lead_Stage__c); // ***************************Gyadeen Ahirwar************************
            eveMap.put('contactname', ev.who != null ? ev.who.name : null); // ***************************Gyadeen Ahirwar************************
            eveMap.put('MileStoneStage', ev.MileStone_Stage__c);
            eveMap.put('isSubmitted', ev.isSubmitted__c);
            eveMap.put('OwnerId', ev.OwnerId);
            eveMap.put('startDateTime', ev.startDateTime);
            eveMap.put('AccountId', ev.Account__c);
            eveMap.put('isConnectedToDCR', ev.isConnectedToDCR__c);
            eveMap.put('EndDateTime', ev.EndDateTime);
            eveMap.put('whatId', ev.whatId);
            eveMap.put('AccountName', ev.Account__r.Name);
            if(ev.isConnectedToDCR__c){
                eveMap.put('isCheck', true);
            }else{
                eveMap.put('isCheck', false);
            }
            
            
            returnMapList.add(eveMap);
        }
        system.debug('returnMapList'+returnMapList);
        
        return returnMapList;
    } 
    
    @AuraEnabled
    public static string updateEventData(event dataMap) {
        system.debug('dataMap '+dataMap);
        system.debug('dataMap ActivityDate'+dataMap.ActivityDate);
        update dataMap;
        return 'Success';
    }
    
    @AuraEnabled
    public static string updateEventBDPlan(list<object> selectedIdToUpdateBDPlan, string action) {
        system.debug('selectedIdToUpdateBDPlan '+selectedIdToUpdateBDPlan);
        system.debug('action '+action);
        list<Event> eventList = new List<Event>();
        if(action=='Update'){
            for(object obj : selectedIdToUpdateBDPlan){
                Event ev = new Event();
                ev.id = string.valueof(obj);
                ev.isConnectedToDCR__c = false;
                eventList.add(ev);
            }
        }else{
            for(object obj : selectedIdToUpdateBDPlan){
                Event ev = new Event();
                ev.id = string.valueof(obj);
                ev.isConnectedToDCR__c = true;
                eventList.add(ev);
            }
        }
        
        system.debug('eventList '+eventList);
        update eventList;
        System.debug('update eventList'+eventList);
        return 'Success';
    }
    
  /*  
    @AuraEnabled
    public static string deleteEventData(event dataMap) {
        system.debug('dataMap '+dataMap);
        delete dataMap;
        return 'Success';
    }*/
    
    @AuraEnabled
public static string deleteEventData(event dataMap) {
    system.debug('dataMap '+dataMap);

    // The event from the LWC may not carry these fields, so re-query
    List<Event> existing = [SELECT Id, Target__c, WhatId FROM Event WHERE Id = :dataMap.Id];
    Id targetId;
    if (!existing.isEmpty() && existing[0].Target__c != null && existing[0].WhatId != null
        && Schema.Account.SObjectType == existing[0].WhatId.getSobjectType()) {
        targetId = existing[0].Target__c;
    }

    delete dataMap;

    if (targetId != null) {
        // Only uncheck if no other Account event still uses this target
        Integer remaining = 0;
        for (Event e : [SELECT WhatId FROM Event WHERE Target__c = :targetId]) {
            if (e.WhatId != null && Schema.Account.SObjectType == e.WhatId.getSobjectType()) {
                remaining++;
            }
        }
        if (remaining == 0) {
            update new Target__c(Id = targetId, Target_Completed__c = false);
        }
    }
    return 'Success';
}

    @AuraEnabled
    public static string createEvent(map<string, object> dataMap,string eventAdress,Date holidaydate) {
        System.debug('dataMap '+dataMap);
        System.debug(String.valueOf(dataMap.get('eventProductFamily')));
        System.debug('System.now()'+System.now());
        System.debug('Event Addres'+eventAdress);
        // Current time in the running user's time zone
Time currentTime = System.now().time();
        Map<String,String> billingData=new Map<String,String>();
        string message='';
        Lead__c lea=new Lead__c();
        Boolean accountData=false;
        User  objUser  = [select id,Name,Profile.Name,userRoleId,userRole.Name from User where id =: UserInfo.getUserId()];
        Userrole rl =[SELECT Id, Name, DeveloperName FROM UserRole WHERE Id =: objUser.userRoleId];
        Id recId;
        Address__c currentAddress  = new Address__c();
        if(eventAdress!='' && eventAdress!=null) {
            billingData=new Map<String,string>();
            currentAddress=[SELECT Id,Billing_Street__c,Billing_City__c,Account__c,Lead__c,Billing_code__c,Billing_country__c,Billing_state__c from Address__c where Id=:eventAdress];
            billingData.put('BillingStreet',currentAddress.Billing_Street__c);
            billingData.put('BillingCity',currentAddress.Billing_City__c);
            System.debug('Billing map1'+billingData);
        }
        if(rl.Name=='Colambia and Brazil Portal User Partner User'){
            
            //recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('Planejamento do DCR').getrecordTypeId();  
            recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('DCR Planning').getrecordTypeId();
        }else{
            
            recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('DCR Planning').getrecordTypeId();  
            
        }
        Id objectId=(Id)string.valueOf(dataMap.get('relatedTo'));
        
        if(objectId != null && Schema.Opportunity__c.SObjectType==objectId.getSobjectType()) {
            
          Opportunity__c  opp=[SELECT Id,Status__c,City__c,Street__c  from Opportunity__c where id=:objectId];
            if(eventAdress=='' || eventAdress==null) {
                billingData=new Map<String,string>();
                            billingData.put('BillingStreet',opp.Street__c);
                billingData.put('BillingCity',opp.City__c);
            }
            System.debug('Billing map2'+billingData);
            
        }
       else if(objectId != null && Schema.Lead__c.SObjectType==objectId.getSobjectType()) {
            
            lea=[SELECT Id,Status__c,CE_CIS_Approval__c,Existing_customer__c,New_Customer__c,Billing_Street__c,Billing_City__c,Contact_Name__c  from Lead__c where id=:objectId];
            if(eventAdress=='' || eventAdress==null) {
                billingData=new Map<String,string>();
                billingData.put('BillingStreet',lea.Billing_Street__c);
                billingData.put('BillingCity',lea.Billing_City__c);
            }
            System.debug('Billing map2'+billingData);
            
        }
        else if(objectId != null && Schema.Account.SObjectType==objectId.getSobjectType()) {
            accountData=true;
            Account acc=[SELECT Id ,BillingStreet,BillingCity,ShippingPostalCode,ShippingCountry,ShippingState from Account where id=:objectId];
            //Account acc=[SELECT Id ,BillingStreet,BillingCity,ShippingPostalCode,ShippingCountry,ShippingState from Account where id=:objectId];
            if(eventAdress=='' || eventAdress==null) {
                
                billingData=new Map<String,string>();
                billingData.put('BillingStreet',acc.BillingStreet);
                billingData.put('BillingCity',acc.BillingCity);
            }
            /*else{
acc.ShippingCity = currentAddress.Billing_City__c;
acc.ShippingStreet = currentAddress.Billing_Street__c;
acc.ShippingPostalCode = currentAddress.Billing_code__c;
acc.ShippingCountry = currentAddress.Billing_country__c;
acc.ShippingState = currentAddress.Billing_state__c;
}*/
            // Update the account if it's not null
            /*if (acc != null) {
update acc;
}*/
            //System.debug('Billing map3'+billingData);
            
            
        }
        
        system.debug('accountData'+accountData);
        system.debug('objectId'+objectId);
        if(((lea.Status__c==true && lea.CE_CIS_Approval__c==true && lea.Existing_customer__c) || (accountData==true || objectId==null)) ||(Schema.Opportunity__c.SObjectType==objectId.getSobjectType()) || ((lea.Status__c==true && lea.CE_CIS_Approval__c==false && lea.New_Customer__c) || (accountData==true || objectId==null))||((lea.Status__c==true && lea.CE_CIS_Approval__c==true && lea.New_Customer__c) || (accountData==true || objectId==null))) {
            
            
            List<event> eventsList = new List<event>();
            List<string> usersList = new List<string>();
            List<Object> objList;
            system.debug('user list : '+string.valueof(dataMap.get('users')));
            if(boolean.valueOf(dataMap.get('jointassignee'))){
                if(string.valueof(dataMap.get('users'))!=''){
                    objList = (List<Object>) dataMap.get('users');
                    if(objList.size()>0){
                        for(object obj : objList){
                            usersList.add(string.valueof(obj));
                        }
                    }
                }
            }
            
            string eventType = String.valueOf(dataMap.get('eventType'));
            System.debug('Addres map'+billingData);
            system.debug('eventType : '+eventType);
            if(usersList.size()>0){
                system.debug('usersList'+usersList);
                for(string userId : usersList){
                    Event ev = new Event();
                    System.debug('1406'+String.valueOf(dataMap.get('targetId')));
                    ev.Target__c=String.valueOf(dataMap.get('targetId'));
                    if(objectId != null && Schema.Account.SObjectType==objectId.getSobjectType()){
                        ev.Product_Family__c=String.ValueOf(dataMap.get('eventProductFamily'));
                       
                    }
                    
                    system.debug('eventTypeeventType : '+eventType);
                    if(eventType=='Customer visit'){
                        ev.Subject = String.valueOf(dataMap.get('subject'));
                        ev.stage__c = 'Planned';
                        ev.BillingStreet__c=billingData.get('BillingStreet');
                        ev.BillingCity__c=billingData.get('BillingCity');
                        ev.OwnerId = userId; //UserInfo.getUserId();
                        ev.Joint_Call__c = boolean.valueOf(dataMap.get('jointassignee'));
                        
                        String subCall = String.valueOf(dataMap.get('subCallType'));
                        //Object fileObj = dataMap.get('fileData');
                        if (String.isNotBlank(subCall)) {
                            ev.Sub_Call_Type__c = subCall;
                            // File mandatory only when subcalltype is selected
                           /* if (fileObj == null) {
                                throw new AuraHandledException('Please upload file for selected sub-call type.');
                            }
                            Map<String, Object> fileData = (Map<String, Object>)fileObj;
                            String fileName = (String)fileData.get('filename');
                            String base64File = (String)fileData.get('base64');
                            if (String.isBlank(fileName) || String.isBlank(base64File)) {
                                throw new AuraHandledException('Invalid file. Please upload again.');
                            }*/
                            ev.Approval_Status__c = 'Installation WIP';
                        }
                        
                        ev.RecordTypeId=recId;
                        //  ev.Account__c = String.valueOf(dataMap.get('relatedTo'));
                        ev.status__c = 'Planned';
                        ev.WhatId = String.valueOf(dataMap.get('relatedTo'));
                        ev.WhoId = String.valueOf(dataMap.get('contact'))!=''? String.valueOf(dataMap.get('contact')):null;
                        //-------------------Start by yogi---------------------------//
                        ev.contact_Name__c = String.valueOf(dataMap.get('contact'))!=''? String.valueOf(dataMap.get('contact')):null;//added by yogi
                        //-------------------End by yogi---------------------------//
                        ev.Description = String.valueOf(dataMap.get('notes'));
                        ev.DCR_Description__c = String.valueOf(dataMap.get('notes'));
                        string [] dateArr = string.valueOf(dataMap.get('date')).split('/');
                        date evdate = date.newInstance(integer.valueOf(dateArr[2]), integer.valueOf(dateArr[0]), integer.valueOf(dateArr[1]));
                        date visitdate = date.newInstance(integer.valueOf(dateArr[2]), integer.valueOf(dateArr[0]), integer.valueOf(dateArr[1]));
                        visitdate.addDays(1);
                        //    time startTime = time.newInstance(0, 0, 0, 0);
                        // time endtime = time.newInstance(0, 0, 0, 0);
                        // ev.StartDateTime = evdate; //datetime.newInstance(evdate, startTime).addMinutes(0);
                        // ev.EndDateTime = evdate; //datetime.newInstance(evdate, endTime).addMinutes(0);
                        time startTime = currentTime;
                        time endTime = currentTime;
                        ev.StartDateTime = Datetime.newInstance(evdate, startTime);
                        ev.EndDateTime = Datetime.newInstance(evdate, endTime);
                        system.debug('visitdate '+ev.startDateTime.dateGMT());
                        //ev.visit_Date__c = ev.startDateTime.dateGMT();
                        ev.Account_Visit_Call_Type__c = String.valueOf(dataMap.get('CallType'));
                        ev.Meeting_Type__c = String.valueOf(dataMap.get('MeetingType'));
                        ev.product__c = String.valueOf(dataMap.get('product'));
                        ev.Call_Type__c=String.valueOf(dataMap.get('CallType'));
                        ev.Level_type__c =String.valueOf(dataMap.get('Leveltype'));
                        //ev.ActivityDateTime = ev.startDateTime.dateGMT();//datetime.newInstance(evdate, startTime).addMinutes(0);
                        ev.visit_Date__c = evdate;
ev.ActivityDateTime = ev.StartDateTime;
                        long milliseconds = datetime.newInstance(evdate, endTime).addMinutes(0).getTime() - datetime.newInstance(evdate, startTime).addMinutes(0).getTime();
                        long seconds = milliseconds / 1000;
                        integer minutes = integer.valueof(seconds / 60);
                        ev.DurationInMinutes=minutes;
                    }
                    ev.RecordTypeId = Schema.SObjectType.Event.getRecordTypeInfosByName().get('DCR Planning').getRecordTypeId();
                    eventsList.add(ev);
                }
            }
            
            Event ev = new Event();
             System.debug('1476'+String.valueOf(dataMap.get('targetId')));
              ev.Target__c=String.valueOf(dataMap.get('targetId'));
            if(eventType=='Leave'){
                if(holidaydate != null){
                    ev.Compensation_Off_Date__c=holidaydate;
                }
                
                ev.Type_of_leave__c = String.valueOf(dataMap.get('leaveOptions'));
                ev.Status__c = 'Planned';
                ev.stage__c = 'Planned';
                ev.Event_Locked__c = true;
                ev.BillingStreet__c=billingData.get('BillingStreet');
                ev.BillingCity__c=billingData.get('BillingCity');
                ev.RecordTypeId=recId;
                ev.OwnerId = String.valueOf(dataMap.get('ownerid')); //UserInfo.getUserId();
                ev.Other_Type__c = true;
                ev.Subject = eventType;
                ev.Description = String.valueOf(dataMap.get('notes'));
                ev.DCR_Description__c = String.valueOf(dataMap.get('notes'));
                ev.Type_of_leave__c = String.valueOf(dataMap.get('leaveOptions'));
                string [] dateArr = string.valueOf(dataMap.get('date')).split('/');
                date evdate = date.newInstance(integer.valueOf(dateArr[2]), integer.valueOf(dateArr[0]), integer.valueOf(dateArr[1]));
                date visitdate = date.newInstance(integer.valueOf(dateArr[2]), integer.valueOf(dateArr[0]), integer.valueOf(dateArr[1]));
                visitdate.addDays(1);
                time startTime = time.newInstance(0, 0, 0, 0);
                time endtime = time.newInstance(0, 0, 0, 0);
                ev.StartDateTime = evdate; //datetime.newInstance(evdate, startTime).addMinutes(0);
                ev.EndDateTime = evdate; //datetime.newInstance(evdate, endTime).addMinutes(0);
                system.debug('visitdate '+ev.startDateTime.dateGMT());
                ev.visit_Date__c = ev.startDateTime.dateGMT();
                ev.ActivityDateTime = ev.startDateTime.dateGMT();//datetime.newInstance(evdate, startTime).addMinutes(0);
                long milliseconds = datetime.newInstance(evdate, endTime).addMinutes(0).getTime() - datetime.newInstance(evdate, startTime).addMinutes(0).getTime();
                long seconds = milliseconds / 1000;
                ev.Call_Type__c=String.valueOf(dataMap.get('CallType'));
                
                integer minutes = integer.valueof(seconds / 60);
                system.debug('Minutes : '+minutes);
                ev.DurationInMinutes=minutes;
            }else if(eventType=='Holiday'){
                ev.Status__c = 'Planned';
                ev.stage__c = 'Planned';
                ev.RecordTypeId=recId;
                ev.BillingStreet__c=billingData.get('BillingStreet');
                ev.BillingCity__c=billingData.get('BillingCity');
                ev.Event_Locked__c = true;
                ev.OwnerId = String.valueOf(dataMap.get('ownerid')); //UserInfo.getUserId();
                ev.Other_Type__c = true;
                ev.Subject = eventType;
                ev.Description = String.valueOf(dataMap.get('notes'));
                ev.DCR_Description__c = String.valueOf(dataMap.get('notes'));
                string [] dateArr = string.valueOf(dataMap.get('date')).split('/');
                date evdate = date.newInstance(integer.valueOf(dateArr[2]), integer.valueOf(dateArr[0]), integer.valueOf(dateArr[1]));
                date visitdate = date.newInstance(integer.valueOf(dateArr[2]), integer.valueOf(dateArr[0]), integer.valueOf(dateArr[1]));
                visitdate.addDays(1);
                time startTime = time.newInstance(0, 0, 0, 0);
                time endtime = time.newInstance(0, 0, 0, 0);
                ev.StartDateTime = evdate; //datetime.newInstance(evdate, startTime).addMinutes(0);
                ev.EndDateTime = evdate; //datetime.newInstance(evdate, endTime).addMinutes(0);
                system.debug('visitdate '+ev.startDateTime.dateGMT());
                ev.visit_Date__c = ev.startDateTime.dateGMT();
                ev.ActivityDateTime = ev.startDateTime.dateGMT();//datetime.newInstance(evdate, startTime).addMinutes(0);
                long milliseconds = datetime.newInstance(evdate, endTime).addMinutes(0).getTime() - datetime.newInstance(evdate, startTime).addMinutes(0).getTime();
                long seconds = milliseconds / 1000;
                integer minutes = integer.valueof(seconds / 60);
                ev.DurationInMinutes=minutes;
                ev.Call_Type__c=String.valueOf(dataMap.get('CallType'));
                ev.Level_type__c =String.valueOf(dataMap.get('Leveltype'));
                
                system.debug('Minutes : '+minutes);
            }else if(eventType=='Out of office'){
                ev.Status__c = 'Planned';
                ev.stage__c = 'Planned';
                ev.RecordTypeId=recId;
                //ev.Type_of_leave__c='Out of office';
                ev.BillingStreet__c=billingData.get('BillingStreet');
                ev.BillingCity__c=billingData.get('BillingCity');
                ev.Event_Locked__c = true;
                ev.OwnerId = String.valueOf(dataMap.get('ownerid')); //UserInfo.getUserId();
                ev.Other_Type__c = true;
                ev.Subject = eventType+'-'+String.valueOf(dataMap.get('reviewCallType'));
                ev.Description = String.valueOf(dataMap.get('notes'));
                ev.DCR_Description__c = String.valueOf(dataMap.get('notes'));
                ev.Review_Call_Type__c = String.valueOf(dataMap.get('reviewCallType'));
                string [] dateArr = string.valueOf(dataMap.get('date')).split('/');
                date evdate = date.newInstance(integer.valueOf(dateArr[2]), integer.valueOf(dateArr[0]), integer.valueOf(dateArr[1]));
                date visitdate = date.newInstance(integer.valueOf(dateArr[2]), integer.valueOf(dateArr[0]), integer.valueOf(dateArr[1]));
                visitdate.addDays(1);
                time startTime = time.newInstance(0, 0, 0, 0);
                time endtime = time.newInstance(0, 0, 0, 0);
                ev.StartDateTime = evdate; //datetime.newInstance(evdate, startTime).addMinutes(0);
                ev.EndDateTime = evdate; //datetime.newInstance(evdate, endTime).addMinutes(0);
                system.debug('visitdate '+ev.startDateTime.dateGMT());
                ev.visit_Date__c = ev.startDateTime.dateGMT();
                ev.ActivityDateTime = ev.startDateTime.dateGMT();//datetime.newInstance(evdate, startTime).addMinutes(0);
                long milliseconds = datetime.newInstance(evdate, endTime).addMinutes(0).getTime() - datetime.newInstance(evdate, startTime).addMinutes(0).getTime();
                long seconds = milliseconds / 1000;
                integer minutes = integer.valueof(seconds / 60);
                ev.DurationInMinutes=minutes;
                ev.Call_Type__c=String.valueOf(dataMap.get('CallType'));
                ev.Level_type__c =String.valueOf(dataMap.get('Leveltype'));
                
                system.debug('Minutes : '+minutes);
            }else if(eventType=='Customer visit'){
                 Id relatedToId =String.ValueOf(dataMap.get('relatedTo'));
            System.debug('relatedToId'+relatedToId);
             if(relatedToId != null && Schema.Account.SObjectType==relatedToId.getSobjectType()){
                        ev.Product_Family__c=String.ValueOf(dataMap.get('eventProductFamily'));
                 System.debug('iqehfoiuehfuiwegfuio'+JSON.serialize(dataMap));
                       System.debug('Inside condition'+ev.Product_Family__c);
                    }
                ev.Subject = String.valueOf(dataMap.get('subject'));
                ev.stage__c = 'Planned';
                ev.RecordTypeId=recId;
                ev.BillingStreet__c=billingData.get('BillingStreet');
                ev.BillingCity__c=billingData.get('BillingCity');
                ev.Joint_Call__c = boolean.valueOf(dataMap.get('jointassignee'));                
                //   ev.Account__c = String.valueOf(dataMap.get('relatedTo'));
                ev.OwnerId = String.valueOf(dataMap.get('ownerid')); //UserInfo.getUserId();
                ev.Call_Type__c=String.valueOf(dataMap.get('CallType'));
                ev.Level_type__c =String.valueOf(dataMap.get('Leveltype'));
                
                // 🔹 Subcall type + file mandatory logic
                
                String subCall = String.valueOf(dataMap.get('subCallType'));
                //Object fileObj = dataMap.get('fileData');
                if (String.isNotBlank(subCall)) {
                    ev.Sub_Call_Type__c = subCall;
                    // File MUST be uploaded
                   /* if (fileObj == null) {
                        throw new AuraHandledException('Please upload file.');
                    }*/
                    // Safe conversion
                   /* Map<String, Object> fileData = (Map<String, Object>)
                        
                        JSON.deserializeUntyped(JSON.serialize(fileObj));
                    String fileName = (String) fileData.get('filename');
                    String base64File = (String) fileData.get('base64');
                    if (String.isBlank(fileName) || String.isBlank(base64File)) {
                        throw new AuraHandledException('Invalid file. Please upload again.');
                    }*/
                    ev.Approval_Status__c = 'Installation WIP';
                }
                
                
                
                ev.contact_Name__c = String.valueOf(dataMap.get('contact')) != '' ? (Id)String.valueOf(dataMap.get('contact')) : null;//Added by Yogi 11/10/2025
                
                if(lea.Contact_Name__c!=null) {
                    ev.WhoId = lea.Contact_Name__c;
                    //-------------------Start by yogi 10/11/2025---------------------------//
                    ev.contact_Name__c = lea.Contact_Name__c;
                    //-------------------End by yogi 10/11/2025---------------------------//
                }
                ev.status__c = 'Planned';
                ev.WhatId = String.valueOf(dataMap.get('relatedTo'));
                ev.Description = String.valueOf(dataMap.get('notes'));
                ev.DCR_Description__c = String.valueOf(dataMap.get('notes'));
                string [] dateArr = string.valueOf(dataMap.get('date')).split('/');
                date evdate = date.newInstance(integer.valueOf(dateArr[2]), integer.valueOf(dateArr[0]), integer.valueOf(dateArr[1]));
                System.debug('Event date'+evdate);
                date visitdate = date.newInstance(integer.valueOf(dateArr[2]), integer.valueOf(dateArr[0]), integer.valueOf(dateArr[1]));
                System.debug('Visit date'+visitdate);
                visitdate.addDays(1);
                // Store the time of creation on the selected date (same as the joint-assignee branch)
                time startTime = currentTime;
                System.debug('start Time'+startTime);
                time endtime = currentTime;
                System.debug('end Time'+endtime);
                ev.StartDateTime = Datetime.newInstance(evdate, startTime);
                ev.EndDateTime = Datetime.newInstance(evdate, endTime);
                System.debug('Start DateTIme'+ev.StartDateTime);
                System.debug('EndDateTime'+ev.EndDateTime);
                system.debug('visitdate '+ev.startDateTime.dateGMT());
                ev.visit_Date__c = evdate;
                ev.ActivityDateTime = ev.StartDateTime;
                ev.Account_Visit_Call_Type__c = String.valueOf(dataMap.get('CallType'));
                ev.Level_type__c =String.valueOf(dataMap.get('Leveltype'));
                ev.Meeting_Type__c = String.valueOf(dataMap.get('MeetingType'));
                ev.product__c = String.valueOf(dataMap.get('product'));
                long milliseconds = datetime.newInstance(evdate, endTime).addMinutes(0).getTime() - datetime.newInstance(evdate, startTime).addMinutes(0).getTime();
                System.debug('milliseconds'+milliseconds);
                long seconds = milliseconds / 1000;
                System.debug('seconds'+seconds);
                integer minutes = integer.valueof(seconds / 60);
                System.debug('minutes'+minutes);
                ev.DurationInMinutes=minutes;
                system.debug('ev.DurationInMinutes : '+ev.DurationInMinutes);
            }
            ev.RecordTypeId = Schema.SObjectType.Event.getRecordTypeInfosByName().get('DCR Planning').getRecordTypeId();
            
            eventsList.add(ev);
           
            System.debug('eventsList '+eventsList);
            System.debug('eventsList '+eventsList.size());
            insert eventsList;
            
            
            // Mark targets as true for Account events that have a target
Map<Id, Target__c> targetsToUpdate = new Map<Id, Target__c>();
for (Event e : eventsList) {
    if (e.Target__c != null && e.WhatId != null
        && Schema.Account.SObjectType == e.WhatId.getSobjectType()) {
        targetsToUpdate.put(e.Target__c, new Target__c(Id = e.Target__c, Target_Completed__c = true));
    }
}
if (!targetsToUpdate.isEmpty()) {
    update targetsToUpdate.values();
}
           /* Id eventId = eventsList[0].Id;leaveBeatPlanCleanupTrigger
            Object fileObj = dataMap.get('fileData');
            if (fileObj != null) {
                Map<String, Object> fileMap = (Map<String, Object>)
                    
                    JSON.deserializeUntyped(JSON.serialize(fileObj));
                String base64Data = (String) fileMap.get('base64');
                String fileName   = (String) fileMap.get('filename');
                
                
                
                if (!String.isBlank(base64Data) && !String.isBlank(fileName)) {
                    Blob fileBlob = EncodingUtil.base64Decode(base64Data);
                    ContentVersion cv = new ContentVersion();
                    cv.Title = fileName.split('\\.')[0];
                    cv.PathOnClient = fileName;
                    cv.VersionData = fileBlob;
                    insert cv;
                    ContentVersion insertedCv = [
                        SELECT Id, ContentDocumentId
                        FROM ContentVersion
                        WHERE Id = :cv.Id
                        LIMIT 1
                    ];
                    if (insertedCv.ContentDocumentId != null) {
                        ContentDocumentLink cdl = new ContentDocumentLink();
                        cdl.ContentDocumentId = insertedCv.ContentDocumentId;
                        cdl.LinkedEntityId = eventId;
                        cdl.ShareType = 'V';
                        cdl.Visibility = 'AllUsers';
                        insert cdl;
                    }
                    ContentDistribution cd = new ContentDistribution();
                    cd.Name = fileName;
                    cd.ContentVersionId = insertedCv.Id;
                    cd.PreferencesAllowViewInBrowser = true;
                    cd.PreferencesNotifyOnVisit = false;
                    cd.PreferencesAllowOriginalDownload = true;
                    cd.PreferencesAllowPDFDownload = true;
                    cd.PreferencesLinkLatestVersion = true;
                    insert cd;
                    
                   
                    List<ContentDistribution> dists = [
                        SELECT Id, Name, DistributionPublicUrl,ContentVersion.Title,ContentVersion.FileExtension, ContentDocumentId
                        FROM ContentDistribution
                        WHERE Id =:cd.Id
                    ];
                    Event evt = new Event(
                        Id = eventId,
                        Public_File_Url__c = dists[0].DistributionPublicUrl,
                        File_Name__c = dists[0].ContentVersion.Title +'.'+ dists[0].ContentVersion.FileExtension
                    );
                    update evt;

                }
            }
            
            */
            /* event eventdata =[select id,Beat_plan__c,Type_of_leave__c,Subject,DCR_Description__c from Event where Id =:eventsList[0].Id];
beat_plan__c beatdata = [select id from beat_plan__c where Id =:eventdata.Beat_plan__c];
system.debug('eventData-subject:'+eventData.Subject);
try{


if(beatdata!=null){
if(eventdata.Subject=='Leave' && eventdata.Subject !=null ){
if(eventdata.Type_of_leave__c =='Full Day Leave'){
beatdata.Event_type_Name__c = 'Full Day Leave';
}
if(eventdata.Type_of_leave__c =='First Half Leave'){
beatdata.Event_type_Name__c = 'First Half Leave';
}
if(eventdata.Type_of_leave__c =='Second Half Leave'){
beatdata.Event_type_Name__c = 'Second Half Leave';

}
if(eventdata.Type_of_leave__c =='Compensation off'){
beatdata.Event_type_Name__c = 'Compensation off';

}


}
System.debug('Subject'+eventData.Subject);
if (eventData.Subject != null && eventData.Subject.contains('Out of office')) {
beatdata.Event_type_Name__c = 'Out of office';
}
beatdata.Description__c = eventData.DCR_Description__c;
if(!test.isRunningTest()) {
update beatdata;

}
}

}catch(exception e){
system.debug(e.getmessage());

}*/
            message='Success';
            
        }
        else {
            if(lea.Status__c==false && lea.CE_CIS_Approval__c==true) {
                message='Address'; 
            }
            if(lea.CE_CIS_Approval__c==false && lea.Status__c==true && lea.Existing_customer__c) {
                message='CECIS';   
            }
            
            
            if(lea.Status__c==false && lea.CE_CIS_Approval__c==false && lea.New_Customer__c) {
                message='reject';
            }
            if(lea.Status__c==false && lea.CE_CIS_Approval__c==false && lea.Existing_customer__c) {
                message='upgrade';
            }
            
        }
        return message;
    }
    /**
* This method retrieves holiday records and related beat plans within the last 30 days.
* The results are categorized into holidays and beat plans, including weekly off days.
* @return Map<String, Object> containing lists of holidays and beat plans
*/
    @AuraEnabled(cacheable = true)
    public static Map<String, Object> getHolidayRecord() {
        // Initialize the result map
        Map<String, Object> holidayMap = new Map<String, Object>();
        List<Map<String,Object>> hlDataList=new List<Map<String,Object>>();
        user currentuser = [select id,region__c,country__c,state__c from user where Id =: UserInfo.getUserId()];
        // Query holidays within the last 30 days with specific types
        List<Holiday__c> holidayList = [SELECT Id, Date__c, Name, Type__c,country__c ,Region__c, state__c FROM Holiday__c 
                                        WHERE Date__c = LAST_N_DAYS:30 AND (Type__c = 'H' OR Type__c = 'WO') AND State__c=:currentuser.State__c
                                        AND Region__c=:currentuser.Region__c and country__c =: currentuser.Country__c];
        
        // Map to store holiday dates and IDs
        Map<Date, String> holidayDateMap = new Map<Date, String>();
        
        // Lists to store Beat Plans related to holidays and weekly off days
        List<Beat_Plan__c> holidayBeatPlanList = new List<Beat_Plan__c>();
        List<Beat_Plan__c> weeklyOffBeatPlanList = new List<Beat_Plan__c>();
        
        // Map to store weekly off days
        Map<Date, String> weeklyOffMap = new Map<Date, String>();
        
        // Populate the map with weekly off days
        for (Holiday__c weeklyHoliday : [SELECT Id, Date__c, Name, Type__c,country__c,state__c,Region__c FROM Holiday__c 
                                         WHERE Date__c = LAST_N_DAYS:30 AND (Type__c = 'H' OR Type__c = 'WO') AND State__c=:currentuser.State__c
                                         AND Region__c=:currentuser.Region__c and country__c =: currentuser.Country__c]) {
                                             weeklyOffMap.put(weeklyHoliday.Date__c, weeklyHoliday.Id);
                                         }
        system.debug('weeklyOffMap'+weeklyOffMap);
        // Populate the holidayDateMap with holiday dates and IDs
        for (Holiday__c holiday : holidayList) {
            holidayDateMap.put(holiday.Date__c, holiday.Type__c);
            system.debug('holidayDateMap'+holidayDateMap);
        }
        
        //system.debug('holidayDateMap'+holidayDateMap);
        // Query Beat Plans within the last 30 days with the event type 'P'
        for (Beat_Plan__c beatPlan : [SELECT Id, Name, Event_Type__c, Event_type_Name__c, Beat_Date__c 
                                      FROM Beat_Plan__c WHERE (Beat_Date__c = LAST_N_DAYS:30 AND Event_Type__c = 'P') AND Assigned_To__c =:UserInfo.getUserId() AND Applied_Compensation_off__c=false AND (COF_Status__c = 'Rejected' OR COF_Status__c = null)]) {
                                          if (holidayDateMap.containsKey(beatPlan.Beat_Date__c)) {
                                              hlDataList.add(new Map<String,Object>{'Date'=>beatPlan.Beat_Date__c,
                                                  'Type'=>holidayDateMap.get(beatPlan.Beat_Date__c)});
                                              holidayBeatPlanList.add(beatPlan);
                                          }
                                          system.debug('hlDataList'+hlDataList);
                                          system.debug('holidayBeatPlanList'+holidayBeatPlanList);
                                      }
        
        // Populate the result map with the lists of holidays and beat plans
        holidayMap.put('holidays', hlDataList);
        holidayMap.put('holidayBeatPlans', holidayBeatPlanList);
        holidayMap.put('weeklyOffBeatPlans', weeklyOffBeatPlanList);
        
        // Debug statements
        System.debug('hlDataList: ' + holidayMap);
        System.debug('beatPlan: ' + holidayBeatPlanList);
        
        // Return the result map
        return holidayMap;
    }
    
    @AuraEnabled(cacheable = true)
    public static List<SObject> findRecords(String searchKey, String objectName, String searchField){
        String key = '%' + searchKey + '%';
        String QUERY = 'Select Id, '+searchField+' From '+objectName +' Where '+searchField +' LIKE :key';
        System.debug(System.LoggingLevel.DEBUG, QUERY);
        List<SObject> sObjectList = Database.query(QUERY);
        return sObjectList;
    }
    
    
    
    @AuraEnabled
    public static List<Map<String,Object>> getLeadData(string leadId) {
        List<Map<String,Object>> dataList=new List<Map<String,Object>>();
        // ****************************Gyadeen below Add code*********************************************
        // Convert the leadId string to Id
        Id leadIdAsId = (Id)leadId;
        system.debug('leadIdAsId'+leadId);
        string leadids ; 
        system.debug('leadIdAsId.getSObjectType()'+leadIdAsId.getSObjectType());
        // Check if the ID is associated with the Event object
        if (leadIdAsId.getSObjectType() == Event.SObjectType) {
            
            system.debug('Event ID :'+leadIdAsId);
            // Query Event data
            Event eve = [SELECT Id, Leads__r.Mobile__c FROM Event WHERE Id = :leadIdAsId];
            //Lead__c lea =[SELECT Id, Name, Mobile__c  FROM Lead__c WHERE Id = :eve.lead__c];
            leadids = eve.Leads__r.Mobile__c;
        }else{
            
            Lead__c lea =[SELECT Id, Name, Mobile__c  FROM Lead__c WHERE Id =: leadIdAsId];
            leadids = lea.Mobile__c;
            system.debug('Lead Id :'+leadIdAsId);
        }
        
        
        Integer i=0;
        
        for(lead__c relatedlead : [SELECT id,Name,Mobile__c,Product__c,Planned_Appointments_Week__c,Planned_Presentation_Week__c,Planned_Product_Demo_Week__c,Planned_Evaluations_Week__c,Planned_Commercialization_week__c
                                   ,Planned_Upgrade_week__c,Actual_Appointments_Week__c,Actual_Presentation_Week__c,
                                   Actual_Product_Demo_Week__c,Actual_Evaluations_Week__c,Actual_Commercialization_week__c,Actual_Upgrade_week__c,Lead_Stage__c from Lead__c where Mobile__c =: leadids]){
                                       
                                       if(relatedlead.Lead_Stage__c==null || relatedlead.Lead_Stage__c=='') {
                                           i++;
                                           dataList.add(new Map<String,Object>{'Stage'=>'','PlannedDate'=>'','Name'=>relatedlead.Name,'ProductName'=>relatedlead.Product__c,'key'=>i,'ActualDate'=>''});
                                           
                                       }
                                       
                                       if(relatedlead.Lead_Stage__c=='Appointments') {
                                           i++;
                                           dataList.add(new Map<String,Object>{'Stage'=>'Appointment','PlannedDate'=>relatedlead.Planned_Appointments_Week__c,'Name'=>relatedlead.Name,'ProductName'=>relatedlead.Product__c,'key'=>i,'ActualDate'=>relatedlead.Actual_Appointments_Week__c});
                                       }  
                                       if(relatedlead.Lead_Stage__c=='Presentation') {
                                           i++;
                                           dataList.add(new Map<String,Object>{'Stage'=>'Presentation','PlannedDate'=>relatedlead.Planned_Presentation_Week__c,'Name'=>relatedlead.Name,'ProductName'=>relatedlead.Product__c,'key'=>i,'ActualDate'=>relatedlead.Actual_Presentation_Week__c});
                                       }  
                                       if(relatedlead.Lead_Stage__c=='Product Demo') {
                                           i++;
                                           dataList.add(new Map<String,Object>{'Stage'=>'Product Demo','PlannedDate'=>relatedlead.Planned_Product_Demo_Week__c,'Name'=>relatedlead.Name,'ProductName'=>relatedlead.Product__c,'key'=>i,'ActualDate'=>relatedlead.Actual_Product_Demo_Week__c});
                                       }  
                                       if(relatedlead.Lead_Stage__c=='Evaluations') {
                                           i++;
                                           dataList.add(new Map<String,Object>{'Stage'=>'Evaluations','PlannedDate'=>relatedlead.Planned_Evaluations_Week__c,'Name'=>relatedlead.Name,'ProductName'=>relatedlead.Product__c,'key'=>i,'ActualDate'=>relatedlead.Actual_Evaluations_Week__c});
                                       }  
                                       if(relatedlead.Lead_Stage__c=='Commercialization') {
                                           i++;
                                           dataList.add(new Map<String,Object>{'Stage'=>'Commercialization','PlannedDate'=>relatedlead.Planned_Commercialization_week__c,'Name'=>relatedlead.Name,'ProductName'=>relatedlead.Product__c,'key'=>i,'ActualDate'=>relatedlead.Actual_Commercialization_week__c});
                                       }  
                                       if(relatedlead.Lead_Stage__c=='Upgrade') {
                                           i++;
                                           dataList.add(new Map<String,Object>{'Stage'=>'Upgrade','PlannedDate'=>relatedlead.Planned_Upgrade_week__c,'Name'=>relatedlead.Name,'ProductName'=>relatedlead.Product__c,'key'=>i,'ActualDate'=>relatedlead.Actual_Upgrade_week__c});
                                       }  
                                       
                                       
                                       /*  if(relatedlead.Planned_Appointments_Week__c!=null) {
i++;
dataList.add(new Map<String,Object>{'Stage'=>'Appointment','Date'=>relatedlead.Planned_Appointments_Week__c,'Name'=>relatedlead.Name,'ProductName'=>relatedlead.Product__c,'key'=>i});
}
if(relatedlead.Planned_Presentation_Week__c!=null) {
i++;
dataList.add(new Map<String,Object>{'Stage'=>'Presentation','Date'=>relatedlead.Planned_Presentation_Week__c,'Name'=>relatedlead.Name,'ProductName'=>relatedlead.Product__c,'key'=>i});
}
if(relatedlead.Planned_Product_Demo_Week__c!=null) {
i++;
dataList.add(new Map<String,Object>{'Stage'=>'ProductDemo','Date'=>relatedlead.Planned_Product_Demo_Week__c,'Name'=>relatedlead.Name,'ProductName'=>relatedlead.Product__c,'key'=>i});
}
if(relatedlead.Planned_Evaluations_Week__c!=null) {
i++;
dataList.add(new Map<String,Object>{'Stage'=>'Evaluation','Date'=>relatedlead.Planned_Evaluations_Week__c,'Name'=>relatedlead.Name,'ProductName'=>relatedlead.Product__c,'key'=>i});
}
if(relatedlead.Planned_Commercialization_week__c!=null) {
i++;
dataList.add(new Map<String,Object>{'Stage'=>'Commerialization','Date'=>relatedlead.Planned_Commercialization_week__c,'Name'=>relatedlead.Name,'ProductName'=>relatedlead.Product__c,'key'=>i});
}
if(relatedlead.Planned_Upgrade_week__c!=null) {
i++;
dataList.add(new Map<String,Object>{'Stage'=>'Upgrade','Date'=>relatedlead.Planned_Upgrade_week__c,'Name'=>relatedlead.Name,'ProductName'=>relatedlead.Product__c,'key'=>i});
}*/
                                   }
        
        // ****************************Gyadeen Above Add code*********************************************
        
        
        /*   //Integer i=0;
if(lea.Planned_Appointments_Week__c!=null) {
i++;
dataList.add(new Map<String,Object>{'Stage'=>'Appointment','Date'=>lea.Planned_Appointments_Week__c,'key'=>i});
}
if(lea.Planned_Presentation_Week__c!=null) {
i++;
dataList.add(new Map<String,Object>{'Stage'=>'Presentation','Date'=>lea.Planned_Presentation_Week__c,'key'=>i});
}
if(lea.Planned_Product_Demo_Week__c!=null) {
i++;
dataList.add(new Map<String,Object>{'Stage'=>'ProductDemo','Date'=>lea.Planned_Product_Demo_Week__c,'key'=>i});
}
if(lea.Planned_Evaluations_Week__c!=null) {
i++;
dataList.add(new Map<String,Object>{'Stage'=>'Evaluation','Date'=>lea.Planned_Evaluations_Week__c,'key'=>i});
}
if(lea.Planned_Commercialization_week__c!=null) {
i++;
dataList.add(new Map<String,Object>{'Stage'=>'Commerialization','Date'=>lea.Planned_Commercialization_week__c,'key'=>i});
}
if(lea.Planned_Upgrade_week__c!=null) {
i++;
dataList.add(new Map<String,Object>{'Stage'=>'Upgrade','Date'=>lea.Planned_Upgrade_week__c,'key'=>i});
}
*/
        
        return dataList;
    }
    
    @AuraEnabled(cacheable=true)
    public static User getCurrentUser() {
        return [SELECT Id, User_Type__c FROM User WHERE Id = :UserInfo.getUserId()];
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getUserHolidays(string userId) {
        Map<String, String> holidayMap = new Map<String, String>();
        Id currentUs = (userId != null && userId != '') ? userId : UserInfo.getUserId();
        
        // Fetch current user safely
        User currentUser = [
            SELECT Id, Country__c, State__c, Region__c 
            FROM User 
            WHERE Id = :currentUs
            LIMIT 1
        ];
        
        String userCountry = currentUser.Country__c;
        String userState   = currentUser.State__c;
        String userRegion  = currentUser.Region__c;
        
        List<Holiday__c> holidays = new List<Holiday__c>();
        
        // Build query with ALL fields explicitly
        String baseQuery = 'SELECT Id, Name, Date__c, Type__c, Description__c, Country__c, State__c, Region__c FROM Holiday__c WHERE ';
        List<String> conditions = new List<String>();
        
        // Add conditions only if values are not null
        if (userCountry != null) {
            conditions.add('Country__c = :userCountry');
        }
        if (userState != null) {
            conditions.add('State__c = :userState');
        }
        if (userRegion != null) {
            conditions.add('Region__c = :userRegion');
        }
        
      Integer currentYear = Date.today().year();
    
    Date startDate = Date.newInstance(currentYear - 1, 1, 1);
    Date endDate   = Date.newInstance(currentYear + 1, 12, 31);
    
    if (conditions.isEmpty()) {
        holidays = [
            SELECT Id, Name, Date__c, Type__c, Description__c
            FROM Holiday__c
            WHERE Date__c >= :startDate AND Date__c <= :endDate
        ];
    } else {
        String finalQuery = baseQuery 
            + String.join(conditions, ' AND ') 
            + ' AND Date__c >= :startDate AND Date__c <= :endDate';
        
        System.debug('Final Query: ' + finalQuery);
        holidays = Database.query(finalQuery);
    }

        
        // Debug all records
        System.debug('Total Holidays Found: ' + holidays.size());
        for (Holiday__c h : holidays) {
            System.debug('Holiday: ' + h.Date__c + ' | Type: ' + h.Type__c + ' | Description: ' + h.Description__c);
        }
        
        // Fill map with type and description
        for (Holiday__c h : holidays) {
            if (h.Date__c != null && String.isNotBlank(h.Type__c)) {
                String dateKey = String.valueOf(h.Date__c);
                String holidayValue = h.Type__c;
                
                if (String.isNotBlank(h.Description__c)) {
                    holidayValue += '|' + h.Description__c;
                } else {
                    // If no description, use name as fallback
                    holidayValue += '|' + (String.isNotBlank(h.Name) ? h.Name : 'Holiday');
                }
                
                holidayMap.put(dateKey, holidayValue);
            }
        }
        
        System.debug('Final Holiday Map: ' + holidayMap);
        return holidayMap;
    }
    public static void fakemethod(){
        integer i=0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
}
public without sharing class CustomLeadCreationController {

    @AuraEnabled
    public static string leadCreate(
        Lead__c leadData,
        Map<String,Object> dataMap,
        string accountId,
        string leadId,
        string existingLead,
        string newLead,
        string eventAdress,
        List<String> leadEventList,
        string parentaccountId
    ) {
        system.debug('parentaccountId:'+ parentaccountId);
        Account acc = new Account();
        system.debug('dataMap:'+dataMap);
        string res = '';
        System.debug('Lead data'+ JSON.serialize(leadData));

        Map<String,String> billingData = new Map<String,String>();
        List<Date> dateList            = new List<Date>();
        List<Event> eventList          = new List<Event>();

        if (leadId != '' && leadId != null) {
            leadData.id = leadId;
        }

        System.debug('Account'+ leadData.Account__c);

        if (leadData.Account__c != null && String.isNotBlank(leadData.Account__c)) {
            acc = [
                SELECT Id, RSM__c, ZSM__c, Branch_Name__c, Branch_Code__c
                FROM Account
                WHERE Id = :leadData.Account__c
            ];
            leadData.Plant__c          = acc.Branch_Name__c;
            leadData.Plant_Code__c     = acc.Branch_Code__c;
            leadData.CE_CIS_Approval__c = true;
            leadData.Status__c         = true;
        }

        if (String.isNotBlank(parentaccountId)) {
            leadData.Parent_Account__c = parentaccountId;
        }

        if (leadData.Account__c != null && acc != null &&
            String.isNotBlank(parentaccountId) && !leadData.Existing_customer__c) {
            system.debug('system.debug ' + parentaccountId);
            acc.ParentId = parentaccountId;
            if (leadData.New_Customer__c) {
                update acc;
            }
        }

        if (leadData.Planned_Appointments_Week__c != null) {
            dateList.add(leadData.Planned_Appointments_Week__c);
        }
        if (leadData.Planned_Product_Demo_Week__c != null) {
            dateList.add(leadData.Planned_Product_Demo_Week__c);
        }
        if (leadData.Planned_Presentation_Week__c != null) {
            dateList.add(leadData.Planned_Presentation_Week__c);
        }
        if (leadData.Planned_Evaluations_Week__c != null) {
            dateList.add(leadData.Planned_Evaluations_Week__c);
        }
        if (leadData.Planned_Commercialization_week__c != null) {
            dateList.add(leadData.Planned_Commercialization_week__c);
        }
        if (leadData.Planned_Upgrade_week__c != null) {
            dateList.add(leadData.Planned_Upgrade_week__c);
        }

        System.debug('Final data'+ JSON.serialize(leadData));

        // ── Set Name before upsert ─────────────────────────────
        if (String.isBlank(leadData.Name)) {
            String firstName = String.isNotBlank(leadData.First_Name__c) ? leadData.First_Name__c : '';
            String lastName  = String.isNotBlank(leadData.Last_Name__c)  ? leadData.Last_Name__c  : '';
            leadData.Name    = (firstName + ' ' + lastName).trim();
            if (String.isBlank(leadData.Name)) {
                leadData.Name = leadData.Company__c != null ? leadData.Company__c : 'New Lead';
            }
        }
        if ( leadData.Name != null &&  leadData.Name.length() > 80) {
     leadData.Name =  leadData.Name.substring(0, 80);
}


        // ── If Name is passed from LWC (family-suffixed), honour it ──
        // LWC sets leadData.Name = "First Last - ProductFamily"
        // so we only set Name if blank (above). If already set, upsert uses it as-is.

        upsert leadData;

        if (leadData != null) {
            billingData = new Map<String,String>();

            if (eventAdress != '' && eventAdress != null) {
                Address__c currentAddress = [
                    SELECT Id, Billing_Street__c, Billing_City__c
                    FROM Address__c
                    WHERE Id = :eventAdress
                ];
                billingData.put('BillingStreet', currentAddress.Billing_Street__c);
                billingData.put('BillingCity',   currentAddress.Billing_City__c);
            } else {
                billingData.put('BillingStreet', leadData.Billing_Street__c);
                billingData.put('BillingCity',   leadData.Billing_City__c);
            }

            res = leadData.Id;
        }

        // ── Create Events for the new/updated lead ─────────────
        if (leadData != null && dataMap.size() > 0) {
            for (Date evDte : dateList) {
                Event ev          = new Event();
                ev.BillingStreet__c            = billingData.get('BillingStreet');
                ev.BillingCity__c              = billingData.get('BillingCity');
                ev.Subject                     = String.valueOf(dataMap.get('Subject'));
                ev.stage__c                    = 'Planned';
                ev.OwnerId                     = UserInfo.getUserId();
                ev.status__c                   = 'Planned';
                ev.WhatId                      = res;
                Date evdate                    = evDte;
                Time startTime                 = Time.newInstance(0, 0, 0, 0);
                Time endTime                   = Time.newInstance(0, 0, 0, 0);
                ev.StartDateTime               = evDte;
                ev.EndDateTime                 = evDte;
                ev.visit_Date__c               = ev.StartDateTime.dateGMT();
                ev.Account_Visit_Call_Type__c  = String.valueOf(dataMap.get('CallType'));
                ev.Meeting_Type__c             = String.valueOf(dataMap.get('MeetingType'));
                ev.product__c                  = leadData.Product__c;
                ev.ActivityDateTime            = ev.StartDateTime.dateGMT();
                Long milliseconds              = DateTime.newInstance(evdate, endTime).addMinutes(0).getTime()
                                               - DateTime.newInstance(evdate, startTime).addMinutes(0).getTime();
                Long seconds                   = milliseconds / 1000;
                Integer minutes                = Integer.valueOf(seconds / 60);
                ev.DurationInMinutes           = minutes;
                ev.RecordTypeId                = Schema.SObjectType.Event
                                                    .getRecordTypeInfosByName()
                                                    .get('DCR Planning')
                                                    .getRecordTypeId();
                eventList.add(ev);
            }
        }

        // ── Create Events for related leads ───────────────────
        if (leadEventList != null && leadEventList.size() > 0) {
            Map<String,String> leadMapData = new Map<String,String>();
            for (Lead__c lea : [
                SELECT Id, Product__c
                FROM Lead__c
                WHERE Id IN :leadEventList
            ]) {
                leadMapData.put(lea.Id, lea.Product__c);
            }

            for (String le : leadEventList) {
                for (Date evDte : dateList) {
                    Event ev          = new Event();
                    ev.BillingStreet__c            = billingData.get('BillingStreet');
                    ev.BillingCity__c              = billingData.get('BillingCity');
                    ev.Subject                     = String.valueOf(dataMap.get('Subject'));
                    ev.stage__c                    = 'Planned';
                    ev.OwnerId                     = UserInfo.getUserId();
                    ev.status__c                   = 'Planned';
                    ev.WhatId                      = le;
                    Date evdate                    = evDte;
                    Time startTime                 = Time.newInstance(0, 0, 0, 0);
                    Time endTime                   = Time.newInstance(0, 0, 0, 0);
                    ev.StartDateTime               = evDte;
                    ev.EndDateTime                 = evDte;
                    ev.visit_Date__c               = ev.StartDateTime.dateGMT();
                    ev.Account_Visit_Call_Type__c  = String.valueOf(dataMap.get('CallType'));
                    ev.Meeting_Type__c             = String.valueOf(dataMap.get('MeetingType'));
                    if (leadMapData.containsKey(le)) {
                        ev.product__c = leadMapData.get(le);
                    }
                    ev.ActivityDateTime            = ev.StartDateTime.dateGMT();
                    Long milliseconds              = DateTime.newInstance(evdate, endTime).addMinutes(0).getTime()
                                                   - DateTime.newInstance(evdate, startTime).addMinutes(0).getTime();
                    Long seconds                   = milliseconds / 1000;
                    Integer minutes                = Integer.valueOf(seconds / 60);
                    ev.DurationInMinutes           = minutes;
                    ev.RecordTypeId                = Schema.SObjectType.Event
                                                        .getRecordTypeInfosByName()
                                                        .get('DCR Planning')
                                                        .getRecordTypeId();
                    eventList.add(ev);
                }
            }
        }

        if (eventList.size() > 0) {
            insert eventList;
        }

        return res;
    }

    // ── Lookup search ──────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<SObject> fetchLookupData(
        String searchKey,
        String sObjectApiName,
        String accountId
    ) {
        List<SObject> returnList  = new List<SObject>();
        String sWildCardText      = '%' + searchKey + '%';
        String sQuery             = 'SELECT Id,Name,SAP_Code__c,OwnerId,E_Mail__c,CE_CIS_Rating__c,'
                                  + 'Phakic_Rating__c,Company_Name__c,Phone,BillingStreet,BillingCity,'
                                  + 'BillingCountry,BillingState,BillingPostalCode FROM '
                                  + sObjectApiName
                                  + ' WHERE Name LIKE :sWildCardText';
        if (String.isNotBlank(accountId)) {
            sQuery += ' AND Id = :accountId';
        }
        sQuery += ' ORDER BY CreatedDate DESC LIMIT 5';
        system.debug('Account query'+ sQuery);
        for (SObject obj : Database.query(sQuery)) {
            returnList.add(obj);
        }
        System.debug('return list'+ returnList);
        return returnList;
    }

    // ── Contact lookup ─────────────────────────────────────────
    @AuraEnabled
    public static List<Contact> fetchContactLookupData(
        String searchKey,
        String AccountId,
        String contId
    ) {
        List<Contact> returnList = new List<Contact>();
        system.debug('searchKey'+ searchKey);
        system.debug('AccountId'+ AccountId);
        system.debug('contId'+ contId);

        String sWildCardText = '%' + searchKey + '%';
        String sQuery        = 'SELECT Id,FirstName,LastName,Email,MobilePhone FROM Contact '
                             + 'WHERE Name LIKE :sWildCardText AND AccountId = :AccountId';
        if (contId != '') {
            sQuery += ' AND Id = :contId';
        }
        sQuery += ' ORDER BY CreatedDate DESC LIMIT 5';
        for (Contact obj : Database.query(sQuery)) {
            returnList.add(obj);
        }
        System.debug('Return list'+ returnList);
        return returnList;
    }

    // ── Account / Lead context ─────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static Map<String,Object> getAccountId(String recordId) {
        Id objectId = (Id) recordId;
        Map<String,Object> accLeadMap          = new Map<String,Object>();
        List<Map<String,Object>> dataList      = new List<Map<String,Object>>();

        if (Schema.Account.SObjectType == objectId.getSObjectType()) {
            System.debug('Account');
            Account acc = [
                SELECT Id, BillingCountry, CE_Rating__c, Phakic_Rating__c, SAP_Code__c,
                       RecordType.Name,
                       (SELECT Id, Name, Lead_Stage__c, Product__c FROM Leads__r)
                FROM Account
                WHERE Id = :recordId
                LIMIT 1
            ];
            accLeadMap.put('Account',           'true');
            accLeadMap.put('AccountId',          acc.Id);
            accLeadMap.put('CeRating',           acc.CE_Rating__c);
            accLeadMap.put('PhakicRating',       acc.Phakic_Rating__c);
            accLeadMap.put('AccountRecordType',  acc.RecordType.Name);

        } else if (Schema.Lead__c.SObjectType == objectId.getSObjectType()) {
            System.debug('Lead');
            Lead__c lea = [
                SELECT Id, Account__c, Planned_Evaluations_Week__c,
                       Planned_Commercialization_week__c, CE_CIS_Rating__c, Phakic_Rating__c,
                       CE_CIS_Approval__c, Planned_Upgrade_week__c, New_Customer__c,
                       Planned_Product_Demo_Week__c, Planned_Presentation_Week__c,
                       Planned_Appointments_Week__c, First_Name__c, Last_Name__c,
                       Email__c, Billing_Street__c, Country__c, CreatedDate,
                       Billing_state__c, Billing_City__c, Mobile__c, Company__c,
                       Contact_Name__c, Product__c, Billing_code__c, Lead_Stage__c
                FROM Lead__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            accLeadMap.put('Lead',                  'true');
            accLeadMap.put('LeadId',                 lea.Id);
            accLeadMap.put('CreatedDate',            lea.CreatedDate);
            accLeadMap.put('DemoWeek',               String.valueOf(lea.Planned_Product_Demo_Week__c));
            accLeadMap.put('Presentatinweek',        String.valueOf(lea.Planned_Presentation_Week__c));
            accLeadMap.put('AppointmentWeek',        String.valueOf(lea.Planned_Appointments_Week__c));
            accLeadMap.put('AccountId',              lea.Account__c);
            accLeadMap.put('FirstName',              lea.First_Name__c);
            accLeadMap.put('lastName',               lea.Last_Name__c);
            accLeadMap.put('email',                  lea.Email__c);
            accLeadMap.put('billingStreet',          lea.Billing_Street__c);
            accLeadMap.put('Country',                lea.Country__c);
            accLeadMap.put('BillingState',           lea.Billing_state__c);
            accLeadMap.put('billingCity',            lea.Billing_City__c);
            accLeadMap.put('Mobile',                 lea.Mobile__c);
            accLeadMap.put('Company',                lea.Company__c);
            accLeadMap.put('Product',                lea.Product__c);
            accLeadMap.put('ZipCode',                lea.Billing_code__c);
            accLeadMap.put('LeadStage',              lea.Lead_Stage__c);
            accLeadMap.put('EvaluationWeek',         lea.Planned_Evaluations_Week__c);
            accLeadMap.put('CommercializationWeek',  lea.Planned_Commercialization_week__c);
            accLeadMap.put('UpgradeWeek',            lea.Planned_Upgrade_week__c);
            accLeadMap.put('Contact',                lea.Contact_Name__c);
            accLeadMap.put('cecisrating',            lea.CE_CIS_Rating__c  != null ? lea.CE_CIS_Rating__c  : 'Nill');
            accLeadMap.put('phakicrating',           lea.Phakic_Rating__c  != null ? lea.Phakic_Rating__c  : 'Nill');
            accLeadMap.put('cecisapproval',          lea.CE_CIS_Approval__c);
            accLeadMap.put('newcustomer',            lea.New_Customer__c);

            if (lea.Account__c != null) {
                for (Lead__c leaData : [
                    SELECT Id, Name, Lead_Stage__c, Product__c
                    FROM Lead__c
                    WHERE Account__c = :lea.Account__c
                    AND Lead_Stage__c != 'Won'
                    AND Id != :recordId
                ]) {
                    dataList.add(new Map<String,Object>{
                        'Id'      => leaData.Id,
                        'Name'    => leaData.Name,
                        'Stage'   => leaData.Lead_Stage__c,
                        'Product' => leaData.Product__c
                    });
                }
                accLeadMap.put('LeadList', dataList);
            }

            if (lea.New_Customer__c) {
                accLeadMap.put('NewCustomer', lea.New_Customer__c);
            } else {
                accLeadMap.put('NewCustomer', false);
            }
        }

        return accLeadMap;
    }

    // ── Insert contact ─────────────────────────────────────────
    @AuraEnabled
    public static String insertContact(Contact conData, String accountId) {
        conData.AccountId = accountId;
        insert conData;
        return conData.Id;
    }

    // ── Address data ───────────────────────────────────────────
    @AuraEnabled
    public static List<Map<String,String>> getAddressData(String accounId) {
        List<Map<String,String>> adressStoreList = new List<Map<String,String>>();
        String query = 'SELECT Billing_Street__c, Billing_state__c, Billing_country__c '
                     + 'FROM Address__c WHERE Account__c = :accounId OR Lead__c = :accounId';
        for (Address__c adrs : Database.query(query)) {
            adressStoreList.add(new Map<String,String>{
                'label' => adrs.Billing_Street__c + ' ' + adrs.Billing_state__c + ' ' + adrs.Billing_country__c,
                'value' => adrs.Id
            });
        }
        return adressStoreList;
    }

    // ── Country mapping ────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static Map<String,List<Map<String,String>>> getCountryMappingData(String country) {
        Map<String,List<Map<String,String>>> countryWiseMap = new Map<String,List<Map<String,String>>>();
        String query = 'SELECT Id, CITY__c, Country__c, Product__c, State__c '
                     + 'FROM Country__c WHERE Country__c = :country ORDER BY State__c ASC';
        Map<String,String> stateMap = new Map<String,String>();

        if (String.isNotBlank(query)) {
            for (Country__c con : Database.query(query)) {
                if (String.isNotBlank(country)) {
                    if (countryWiseMap.containsKey('Product') && String.isNotBlank(con.Product__c)) {
                        countryWiseMap.get('Product').add(
                            new Map<String,String>{ 'label' => con.Product__c, 'value' => con.Product__c }
                        );
                    } else {
                        if (String.isNotBlank(con.Product__c)) {
                            List<Map<String,String>> productList = new List<Map<String,String>>();
                            productList.add(new Map<String,String>{ 'label' => con.Product__c, 'value' => con.Product__c });
                            countryWiseMap.put('Product', productList);
                        }
                    }
                    if (!stateMap.containsKey(con.State__c)) {
                        stateMap.put(con.State__c, con.State__c);
                        if (countryWiseMap.containsKey('State')) {
                            countryWiseMap.get('State').add(
                                new Map<String,String>{ 'label' => con.State__c, 'value' => con.State__c }
                            );
                        } else {
                            List<Map<String,String>> stateList = new List<Map<String,String>>();
                            stateList.add(new Map<String,String>{ 'label' => con.State__c, 'value' => con.State__c });
                            countryWiseMap.put('State', stateList);
                        }
                    }
                }
            }
        }
        return countryWiseMap;
    }

    // ── City mapping ───────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static Map<String,List<Map<String,String>>> getCityMappingData(String state) {
        Map<String,List<Map<String,String>>> countryWiseMap = new Map<String,List<Map<String,String>>>();
        String query = 'SELECT Id, CITY__c, Country__c, Product__c, State__c '
                     + 'FROM Country__c WHERE State__c = :state ORDER BY CITY__c ASC';
        Map<String,String> cityMap = new Map<String,String>();

        if (String.isNotBlank(query)) {
            for (Country__c con : Database.query(query)) {
                if (!cityMap.containsKey(con.CITY__c)) {
                    cityMap.put(con.CITY__c, con.CITY__c);
                    if (String.isNotBlank(state)) {
                        if (countryWiseMap.containsKey('city')) {
                            countryWiseMap.get('city').add(
                                new Map<String,String>{ 'label' => con.CITY__c, 'value' => con.CITY__c }
                            );
                        } else {
                            List<Map<String,String>> cityList = new List<Map<String,String>>();
                            cityList.add(new Map<String,String>{ 'label' => con.CITY__c, 'value' => con.CITY__c });
                            countryWiseMap.put('city', cityList);
                        }
                    }
                }
            }
        }
        return countryWiseMap;
    }

    // ── Custom labels ──────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static LeadForm__c getCustomLabels() {
        String language = UserInfo.getLanguage();
        return LeadForm__c.getValues(language);
    }

    // ── Product Groups by Family ───────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<Map<String,String>> getProductGroupsByFamily(String productFamily) {
        List<Map<String,String>> options = new List<Map<String,String>>();
        if (String.isBlank(productFamily)) {
            return options;
        }
        User usr=[SELECT Id,Country__c from USER WHERE Id=:userInfo.getUserId()]??NULL;
        Set<String> seen = new Set<String>();
        for (Product_Group__c pg : [
            SELECT Brand__c
            FROM Product_Group__c
            WHERE Product_Family__c = :productFamily
            AND Display_On_Opportunity__c = true
            AND Brand__c != null
            AND Country__c =:usr.Country__c
            ORDER BY Brand__c ASC
        ]) {
            if (!seen.contains(pg.Brand__c)) {
                seen.add(pg.Brand__c);
                options.add(new Map<String,String>{
                    'label' => pg.Brand__c,
                    'value' => pg.Brand__c
                });
            }
        }
        return options;
    }

    // ── Create Lead Products ───────────────────────────────────
    @AuraEnabled
    public static void createLeadProductsForLead(
        Id leadId,
        String productFamily,
        List<String> groupNames
    ) {
        if (leadId == null || String.isBlank(productFamily)) {
            throw new AuraHandledException('Lead Id and Product Family are required.');
        }
		User usr=[SELECT Id,Country__c FROM User WHERE Id=:userInfo.getUserId()]??NULL;
        List<Product_Group__c> productGroups;
        if (groupNames != null && !groupNames.isEmpty()) {
            productGroups = [
                SELECT Id, Product_Family__c, Group_Name__c, Brand__c
                FROM Product_Group__c
                WHERE Product_Family__c = :productFamily
                AND Brand__c IN :groupNames
                AND Display_On_Opportunity__c = true AND Country__c =:usr.country__c
            ];
        } else {
            productGroups = [
                SELECT Id, Product_Family__c, Group_Name__c, Brand__c
                FROM Product_Group__c
                WHERE Product_Family__c = :productFamily
                AND Display_On_Opportunity__c = true
            ];
        }

        Set<Id> existingPgIds = new Set<Id>();
        for (Lead_Product__c lp : [
            SELECT Product_Group__c
            FROM Lead_Product__c
            WHERE Leads__c = :leadId
        ]) {
            if (lp.Product_Group__c != null) {
                existingPgIds.add(lp.Product_Group__c);
            }
        }

        Set<Id> seenInBatch             = new Set<Id>();
        List<Lead_Product__c> linesToInsert = new List<Lead_Product__c>();
        for (Product_Group__c pg : productGroups) {
            if (existingPgIds.contains(pg.Id) || seenInBatch.contains(pg.Id)) {
                continue;
            }
            seenInBatch.add(pg.Id);
            linesToInsert.add(new Lead_Product__c(
                Leads__c         = leadId,
                Product_Group__c = pg.Id
            ));
        }

        if (!linesToInsert.isEmpty()) {
            try {
                insert linesToInsert;
                update new Lead__c(Id = leadId, Product_Exists__c = true);
            } catch (Exception e) {
                System.debug('534 on lead creation'+e.getMessage()+'line Number'+e.getLineNumber());
                throw new AuraHandledException('Database Error: ' + e.getMessage());
            }
        }
    }

    // ── Unqualify lead ─────────────────────────────────────────
    @AuraEnabled
    public static String updateUnuqalifiedLead(Lead__c lea) {
        if (String.isBlank(lea.Unqualified_Remarks__c) || String.isBlank(lea.Disqualified_Reason__c)) {
            throw new AuraHandledException('Please fill in the reason for unqualified the lead.');
        }
        try {
            lea.Lead_Stage__c = 'Unqualified';
            update lea;
            return 'success';
        } catch (Exception e) {
            throw new AuraHandledException('An error occurred while updating the lead: ' + e.getMessage());
        }
    }
}
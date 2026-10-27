public with sharing class OppTypeSelectorController {
    private static final String TYPE_BUNDLE    = 'Bundle Equipment Deal';
    private static final String TYPE_SOLO      = 'Solo Equipment Sale';
    private static final String DEFAULT_COMPANY = 'Others';
    
    // ─── Inner classes ────────────────────────────────────────────────────────
    
    public class FieldInfo {
        @AuraEnabled public String  apiName   { get; set; }
        @AuraEnabled public String  label     { get; set; }
        @AuraEnabled public String  fieldType { get; set; }
        @AuraEnabled public Boolean required  { get; set; }
    }

        public class ProductOption {
        @AuraEnabled public String  Id         { get; set; }
        @AuraEnabled public String  Name       { get; set; }
        @AuraEnabled public Decimal productMSP { get; set; }
        @AuraEnabled public String  brandName   { get; set; }  // ← ADD THIS
        @AuraEnabled public Decimal pfAsp       { get; set; }  // renamed — Apex identifiers can't have "__"


        }
        
    public class EquipmentLineWrapper {
        @AuraEnabled public Id      equipmentProductId    { get; set; }
        @AuraEnabled public String  equipmentCompany      { get; set; }
        @AuraEnabled public String  equipmentName         { get; set; }
        @AuraEnabled public Integer quantity              { get; set; }
        @AuraEnabled public Decimal equipmentValue        { get; set; }
        @AuraEnabled public Decimal equipmentTotalValue   { get; set; }
    }

    public class OpportunityProductInput {
        @AuraEnabled public String  sfRecordId         { get; set; }
        @AuraEnabled public String  opportunityId      { get; set; }
        @AuraEnabled public String  equipmentProductId { get; set; }
        @AuraEnabled public String  equipmentName      { get; set; }
        @AuraEnabled public String  productId          { get; set; }
        @AuraEnabled public String  productFamilyLabel { get; set; }
        @AuraEnabled public Decimal msp                { get; set; }
        @AuraEnabled public Decimal monthlyQty         { get; set; }
        @AuraEnabled public String  totalDealPeriod    { get; set; }
        @AuraEnabled public Decimal totalDealQty       { get; set; }
        @AuraEnabled public Decimal monthlyDealValue   { get; set; }
        @AuraEnabled public Decimal totalDealValue     { get; set; }
    }
    
    // ─── Metadata / schema helpers ────────────────────────────────────────────
    
    @AuraEnabled(cacheable=true)
    public static Id getRecordTypeIdByName(String objectApiName, String recordTypeName) {
        try {
            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectApiName);
            if (sot == null) return null;
            Map<String, Schema.RecordTypeInfo> rtMap =
                sot.getDescribe().getRecordTypeInfosByDeveloperName();
            return rtMap.containsKey(recordTypeName)
                ? rtMap.get(recordTypeName).getRecordTypeId()
                : null;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching record type: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<FieldInfo> getFieldSetFields(String fieldSetName) {
        try {
            if (String.isBlank(fieldSetName)) {
                throw new AuraHandledException('Field set name must not be blank.');
            }
            Schema.DescribeSObjectResult objDesc = Opportunity__c.SObjectType.getDescribe();
            Map<String, Schema.FieldSet> fieldSets = objDesc.fieldSets.getMap();
            if (!fieldSets.containsKey(fieldSetName)) {
                throw new AuraHandledException('Field set "' + fieldSetName + '" not found on Opportunity__c.');
            }
            Map<String, Schema.SObjectField> fieldMap = objDesc.fields.getMap();
            List<FieldInfo> result = new List<FieldInfo>();
            for (Schema.FieldSetMember member : fieldSets.get(fieldSetName).getFields()) {
                FieldInfo info = new FieldInfo();
                info.apiName   = member.getFieldPath();
                info.label     = member.getLabel();
                info.required  = member.getRequired() || member.getDbRequired();
                info.fieldType = fieldMap.containsKey(info.apiName)
                    ? String.valueOf(fieldMap.get(info.apiName).getDescribe().getType()).toLowerCase()
                    : 'string';
                result.add(info);
            }
            return result;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading fields: ' + e.getMessage());
        }
    }
    
    // ─── Deal period picklist ─────────────────────────────────────────────────
    
    @AuraEnabled(cacheable=true)
    public static List<String> getDealPeriodOptions() {
        List<String> options = new List<String>();
        for (Schema.PicklistEntry entry : Opportunity__c.Total_Deal_Period__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) options.add(entry.getValue());
        }
        return options;
    }
    
    @AuraEnabled
    public static Integer getOpportunityDealPeriod(Id opportunityId) {
        if (opportunityId == null) return 36;
        List<Opportunity__c> opps = [
            SELECT Total_Deal_Period__c
            FROM   Opportunity__c
            WHERE  Id = :opportunityId
            LIMIT  1
        ];
        if (opps.isEmpty() || String.isBlank(opps[0].Total_Deal_Period__c)) return 36;
        try {
            return Integer.valueOf(opps[0].Total_Deal_Period__c);
        } catch (Exception e) {
            return 36;
        }
    }
    
    // ─── Equipment products ───────────────────────────────────────────────────
    
    @AuraEnabled(cacheable=true)
    public static List<Equipment_Product__c> getEquipmentProducts(String opportunityType) {
        Map<String, Schema.SObjectField> fields =
            Equipment_Product__c.SObjectType.getDescribe().fields.getMap();
        
        Boolean hasSoloCheckbox   = fields.containsKey('Solo_Equipment__c');
        Boolean hasBundleCheckbox = fields.containsKey('Bundle_Equipment__c');
        
        if (hasSoloCheckbox && hasBundleCheckbox) {
            String soql =
                'SELECT Id, Name, Is_Available__c, ' +
                'Solo_Equipment__c, Bundle_Equipment__c ';
            
            String brandField = firstExistingField(fields, new List<String>{
                'Brand__c', 'Equipment_Brand__c', 'Product_Brand__c'
            });
            if (brandField != null) soql += ', ' + brandField + ' ';
            
            // ── Exclude the "Others" record — it is handled by the JS sentinel ──
            soql += 'FROM Equipment_Product__c WHERE Is_Available__c = TRUE AND Name != \'Others\' ';
            
            if (TYPE_SOLO.equalsIgnoreCase(opportunityType)) {
                soql += 'AND Solo_Equipment__c = TRUE ';
            } else if (TYPE_BUNDLE.equalsIgnoreCase(opportunityType)) {
                soql += 'AND Bundle_Equipment__c = TRUE ';
            }
            
            soql += 'ORDER BY Name ASC';
            return (List<Equipment_Product__c>) Database.query(soql);
        }
        
        String typeField  = firstExistingField(fields, new List<String>{
            'Equipment_Type__c', 'Type__c', 'Product_Type__c', 'Equipment_Product_Type__c'
        });
        String brandField = firstExistingField(fields, new List<String>{
            'Brand__c', 'Equipment_Brand__c', 'Product_Brand__c'
        });
        
        String soql = 'SELECT Id, Name, Is_Available__c';
        if (typeField  != null) soql += ', ' + typeField;
        if (brandField != null) soql += ', ' + brandField;
        // ── Exclude the "Others" record here too ──────────────────────────────
        soql += ' FROM Equipment_Product__c WHERE Is_Available__c = TRUE AND Name != \'Others\' ORDER BY Name ASC';
        
        List<Equipment_Product__c> allProducts = Database.query(soql);
        
        if (typeField == null || String.isBlank(opportunityType)) {
            return allProducts;
        }
        
        String wanted = (opportunityType == TYPE_SOLO) ? 'solo' : 'bundle';
        
        List<Equipment_Product__c> filtered = new List<Equipment_Product__c>();
        for (Equipment_Product__c product : allProducts) {
            String rawType = String.valueOf(product.get(typeField));
            if (String.isBlank(rawType)) {
                filtered.add(product);
                continue;
            }
            String normalized = rawType.toLowerCase();
            Boolean matchesWanted = normalized.contains(wanted);
            Boolean matchesBoth   = normalized.contains('both')
                || normalized.contains('all')
                || normalized.contains('solo;bundle')
                || normalized.contains('bundle;solo');
            if (matchesWanted || matchesBoth) {
                filtered.add(product);
            }
        }
        return filtered;
    }
    
    // ─── Equipment company mapping ────────────────────────────────────────────
    
    @AuraEnabled(cacheable=true)
    public static List<String> getEquipmentCompanies(Id equipmentProductId) {
        if (equipmentProductId == null) {
            return new List<String>{ DEFAULT_COMPANY };
        }
        List<Equipment_Product__c> products = [
            SELECT Id, Name
            FROM   Equipment_Product__c
            WHERE  Id = :equipmentProductId
            LIMIT  1
        ];
        if (products.isEmpty()) return new List<String>{ DEFAULT_COMPANY };
        
        List<String> companies = new List<String>();
        for (Equipment_Company_Mapping__mdt rec : [
            SELECT Company_Name__c, Sort_Order__c
            FROM   Equipment_Company_Mapping__mdt
            WHERE  Equipment_Product_Name__c = :products[0].Name
            ORDER BY Sort_Order__c ASC NULLS LAST, Company_Name__c ASC
        ]) {
            if (String.isBlank(rec.Company_Name__c)) continue;
            if (rec.Company_Name__c.equalsIgnoreCase(DEFAULT_COMPANY)) continue;
            companies.add(rec.Company_Name__c);
        }
        companies.add(DEFAULT_COMPANY);
        return companies;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Contact> getRelatedContactIds(Id accountId) {
        if (accountId == null) {
            return new List<Contact>();
        }
      /*  return [
            SELECT Id, Name
            FROM   Contact
            WHERE  AccountId = :accountId
            ORDER BY Name
        ];*/
        return [SELECT Id, Name 
FROM Contact 
WHERE Id IN (
    SELECT ContactId 
    FROM AccountContactRelation 
    WHERE AccountId = :accountId
)
];
    }

    // ─── Save equipment survey (Bundle) ──────────────────────────────────────
    
    @AuraEnabled
    public static Id saveBundleEquipment(
        Id                         opportunityId,
        Decimal                    totalFundingValue,
        Decimal                    downPayment,
        String                     totalDealPeriod,
        Date                       startDate,
        Date                       endDate,
        List<EquipmentLineWrapper> equipmentLines
    ) {
        Savepoint sp = Database.setSavepoint();
        try {
            validateOpportunity(opportunityId);
            Opportunity__c opp = new Opportunity__c(
                Id                            = opportunityId,
                Equipment_Value2__c           = totalFundingValue,
                Down_Payment__c               = downPayment,
                Total_Deal_Period__c          = totalDealPeriod,
                Equipment_Opportunity_Type__c = TYPE_BUNDLE
            );
            putIfFieldExists(opp, 'Start_Date__c', startDate);
            putIfFieldExists(opp, 'End_Date__c',   endDate);
            update opp;
            upsertEquipmentLines(opportunityId, equipmentLines);
            return opportunityId;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Bundle Equipment save failed: ' + e.getMessage());
        }
    }
    
    // ─── Save equipment survey (Solo) ─────────────────────────────────────────
    
    @AuraEnabled
    public static Id saveSoloEquipment(
        Id                         opportunityId,
        Decimal                    totalSoloValue,
        String                     totalDealPeriod,
        Date                       startDate,
        Date                       endDate,
        List<EquipmentLineWrapper> equipmentLines
    ) {
        Savepoint sp = Database.setSavepoint();
        try {
            validateOpportunity(opportunityId);
            Opportunity__c opp = new Opportunity__c(
                Id                            = opportunityId,
                Total_Solo_Equipment_Value__c = totalSoloValue,
                Total_Deal_Period__c          = totalDealPeriod,
                Equipment_Opportunity_Type__c = TYPE_SOLO
            );
            putIfFieldExists(opp, 'Start_Date__c', startDate);
            putIfFieldExists(opp, 'End_Date__c',   endDate);
            update opp;
            upsertEquipmentLines(opportunityId, equipmentLines);
            return opportunityId;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Solo Equipment save failed: ' + e.getMessage());
        }
    }
    
    // ─── Product family / product group ──────────────────────────────────────

    // private static String getCurrentUserVertical() {
    //     User currentUser = [
    //         SELECT Vertical__c, CurrencyIsoCode
    //         FROM   User
    //         WHERE  Id = :UserInfo.getUserId()
    //         LIMIT  1
    //     ];
    //     return currentUser.Vertical__c;
    // }

    @AuraEnabled(cacheable=true)
   public static User getCurrentUserVertical() {
    return [
        SELECT Vertical__c, CurrencyIsoCode,DefaultCurrencyIsoCode,Country__c
        FROM   User
        WHERE  Id = :UserInfo.getUserId()
        LIMIT  1
    ];
}

    // Solo/Bundle (Equipment) opportunity types are gated per country via
    // SAP_Country_Config__mdt.Equipment_Enabled__c, matched on the running
    // user's Country__c. Countries with no config record, or any error,
    // default to enabled so existing behavior is unaffected.
    @AuraEnabled(cacheable=true)
    public static Boolean isEquipmentEnabledForCurrentUser() {
        User currentUser = [SELECT Country__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (String.isBlank(currentUser.Country__c)) {
            return true;
        }
        List<SAP_Country_Config__mdt> configs = [
            SELECT Equipment_Enabled__c
            FROM SAP_Country_Config__mdt
            WHERE Country__c = :currentUser.Country__c.toUpperCase()
            LIMIT 1
        ];
        if (configs.isEmpty()) {
            return true;
        }
        return configs[0].Equipment_Enabled__c;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getProductFamily(Id opportunityId) {
        try {
            String userVertical = getCurrentUserVertical().Vertical__c;
            if (String.isBlank(userVertical)) {
                return new List<String>(); // no vertical assigned -> show nothing
            }

            Set<String> familySet = new Set<String>();
            for (AggregateResult pg : [
                SELECT   Product_Family__c
                FROM     Product_Group__c
                WHERE    Display_on_Opportunity__c = true
                AND      Vertical__c = :userVertical
                GROUP BY Product_Family__c
            ]) {
                String family = (String) pg.get('Product_Family__c');
                if (String.isNotBlank(family)) {
                    familySet.add(family);
                }
            }

            List<String> families = new List<String>(familySet);
            families.sort();
            return families;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading product families: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ProductOption> getProductsByFamily(String productFamily) {
        try {
            String userVertical = getCurrentUserVertical().Vertical__c;
            String userCountry = getCurrentUserVertical().Country__c;
            if (String.isBlank(userVertical)) {
                return new List<ProductOption>();
            }
			
          
            List<ProductOption> options = new List<ProductOption>();
            System.debug('product option'+[ SELECT Id, Group_Name__c, Brand__c, Product_MSP__c,PF_ASP__c, Name
                FROM   Product_Group__c
                WHERE  Product_Family__c = :productFamily
                AND    Vertical__c = :userVertical
                AND    Display_on_Opportunity__c = TRUE AND country__c=:userCountry
                WITH USER_MODE
                ORDER BY Group_Name__c]);
            System.debug('productFamily'+productFamily +' userVertical'+userVertical +' usr.Country__c'+userCountry);
            for (Product_Group__c groupRecord : [
                SELECT Id, Group_Name__c, Brand__c, Product_MSP__c,PF_ASP__c, Name
                FROM   Product_Group__c
                WHERE  Product_Family__c = :productFamily
                AND    Vertical__c = :userVertical
                AND    Display_on_Opportunity__c = TRUE AND country__c=:userCountry
                WITH USER_MODE
                ORDER BY Group_Name__c
            ]) {
                ProductOption option = new ProductOption();
                option.Id         = groupRecord.Id;
                option.Name       = groupRecord.Name;
                option.brandName  = groupRecord.Brand__c;
                option.productMSP = groupRecord.Product_MSP__c == null ? 0 : groupRecord.Product_MSP__c;
                option.pfAsp      = groupRecord.PF_ASP__c == null ? 0 : groupRecord.PF_ASP__c;
                options.add(option);
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading products: ' + e.getMessage());
        }
    }

    // ─── Save opportunity products ────────────────────────────────────────────
    
    @AuraEnabled
    public static List<String> saveOpportunityProducts(List<OpportunityProductInput> inputs) {
        if (inputs == null || inputs.isEmpty()) return new List<String>();
        
        List<Opportunity_Product__c> toUpsert = new List<Opportunity_Product__c>();
        
        for (OpportunityProductInput input : inputs) {
            Opportunity_Product__c rec = String.isNotBlank(input.sfRecordId)
                ? new Opportunity_Product__c(Id = input.sfRecordId)
                : new Opportunity_Product__c();
            
            if (String.isBlank(input.sfRecordId)) {
                rec.Opportunity__c = input.opportunityId;
            }
            
            rec.Product_Family__c   = input.productFamilyLabel;
            rec.Product_Group__c    = input.productId;
            rec.MSP__c              = input.msp;
            rec.Monthly_Quantity__c = input.monthlyQty;
            rec.Quantity__c         = input.monthlyQty;
            
            putIfFieldExists(rec, 'Equipment_Product__c', input.equipmentProductId);
            putIfFieldExists(rec, 'Equipment__c',         input.equipmentProductId);
            putIfFieldExists(rec, 'Equipment_Name__c',    input.equipmentName);
            
            if (String.isNotBlank(input.totalDealPeriod)) {
                try {
                    String numericPart = input.totalDealPeriod.replaceAll('[^0-9.]', '');
                    rec.Total_Deal_Period__c = String.isNotBlank(numericPart)
                        ? Decimal.valueOf(numericPart)
                        : null;
                } catch (Exception e) {
                    rec.Total_Deal_Period__c = null;
                }
            } else {
                rec.Total_Deal_Period__c = null;
            }
            
            toUpsert.add(rec);
        }
        
        try {
            upsert toUpsert;
        } catch (DmlException e) {
            throw new AuraHandledException('Save error: ' + e.getDmlMessage(0));
        }
        
        List<String> savedIds = new List<String>();
        for (Opportunity_Product__c rec : toUpsert) {
            savedIds.add(rec.Id);
        }
        return savedIds;
    }
    
    // ─── Opportunity creation ─────────────────────────────────────────────────
    
    @AuraEnabled
    public static Id createOpportunity(Map<String, Object> fieldValues) {
        try {
            if (fieldValues == null) {
                throw new AuraHandledException('fieldValues map must not be null.');
            }
            Opportunity__c opp = new Opportunity__c();
            putExtraFields(opp, fieldValues);
            insert opp;
            return opp.Id;
        } catch (DmlException e) {
            system.debug('e=>> ' + e);
            throw new AuraHandledException(e.getDmlMessage(0));
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // ─── Private helpers ──────────────────────────────────────────────────────
    
    private static void validateOpportunity(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity Id is required.');
        }
    }
    
    private static void putIfFieldExists(SObject recordValue, String fieldApi, Object value) {
        if (value == null) return;
        Map<String, Schema.SObjectField> fields =
            recordValue.getSObjectType().getDescribe().fields.getMap();
        if (!fields.containsKey(fieldApi)) return;
        Schema.DisplayType fieldType = fields.get(fieldApi).getDescribe().getType();
        if (fieldType == Schema.DisplayType.REFERENCE && value instanceof String) {
            recordValue.put(fieldApi, (Id) String.valueOf(value));
        } else {
            recordValue.put(fieldApi, value);
        }
    }
    
    private static void putExtraFields(Opportunity__c opp, Map<String, Object> fieldValues) {
        if (fieldValues == null || fieldValues.isEmpty()) return;
        Map<String, Schema.SObjectField> fields = Opportunity__c.SObjectType.getDescribe().fields.getMap();
        for (String apiName : fieldValues.keySet()) {
            if (String.isBlank(apiName) || !fields.containsKey(apiName)) continue;
            Object rawValue = fieldValues.get(apiName);
            if (rawValue == null || String.valueOf(rawValue) == '') continue;
            Schema.DescribeFieldResult dfr = fields.get(apiName).getDescribe();
            if (!dfr.isCreateable()) continue;
            String value = String.valueOf(rawValue);
            try {
                switch on dfr.getType() {
                    when REFERENCE  { opp.put(apiName, (Id)     value); }
                    when DATE       { opp.put(apiName, Date.valueOf(value.left(10))); }
                    when DATETIME   { opp.put(apiName, DateTime.valueOf(value)); }
                    when BOOLEAN    { opp.put(apiName, Boolean.valueOf(value)); }
                    when CURRENCY, DOUBLE, PERCENT { opp.put(apiName, Decimal.valueOf(value)); }
                    when INTEGER    { opp.put(apiName, Integer.valueOf(value)); }
                    when else       { opp.put(apiName, value); }
                }
            } catch (Exception e) {
                throw new AuraHandledException('Invalid value for ' + apiName + ': ' + e.getMessage());
            }
        }
    }

    // ─── Upsert equipment lines ───────────────────────────────────────────────

    private static void upsertEquipmentLines(Id opportunityId, List<EquipmentLineWrapper> equipmentLines) {
    if (equipmentLines == null || equipmentLines.isEmpty()) return;

    Map<String, Object> brandById = getEquipmentBrandById(equipmentLines);

    Id othersProductId = null;
    List<Equipment_Product__c> othersProducts = [
        SELECT Id FROM Equipment_Product__c WHERE Name = 'Others' LIMIT 1
    ];
    if (!othersProducts.isEmpty()) othersProductId = othersProducts[0].Id;

    // Delete all existing "Other" lines before re-inserting to prevent duplicates
    if (othersProductId != null) {
        List<Equipment_Product_Group__c> existingOtherLines = [
            SELECT Id FROM Equipment_Product_Group__c
            WHERE  Opportunity__c = :opportunityId
            AND    Equipment_Product__c = :othersProductId
        ];
        if (!existingOtherLines.isEmpty()) delete existingOtherLines;
    }

    // Build existing-records map for non-Other rows only
    Map<String, Equipment_Product_Group__c> existingMap = new Map<String, Equipment_Product_Group__c>();
    for (Equipment_Product_Group__c existing : [
        SELECT Id, Equipment_Product__c, Company__c, Equipemnt_Name_Other__c
        FROM   Equipment_Product_Group__c
        WHERE  Opportunity__c = :opportunityId
    ]) {
        if (existing.Equipment_Product__c == null) continue;
        String key = String.valueOf(existing.Equipment_Product__c) + '-' + existing.Company__c;
        existingMap.put(key, existing);
    }

    List<Equipment_Product_Group__c> toUpsert = new List<Equipment_Product_Group__c>();
    Set<String> processed = new Set<String>();
    Integer otherSeq = 0;

    for (EquipmentLineWrapper line : equipmentLines) {
        if (line == null) continue;

        String rawId = line.equipmentProductId != null
            ? String.valueOf(line.equipmentProductId).trim()
            : '';

        Boolean isOtherLine = String.isBlank(rawId)
            || rawId.equalsIgnoreCase('Others')
            || rawId.equalsIgnoreCase('Other');

        Integer qty        = (line.quantity == null || line.quantity <= 0) ? 1 : line.quantity;
        Decimal unitValue  = (line.equipmentValue != null && line.equipmentValue > 0)
            ? line.equipmentValue : 0;
        Decimal totalValue = unitValue * qty;

        String companyName = String.isBlank(line.equipmentCompany)
            ? DEFAULT_COMPANY : line.equipmentCompany.trim();
        String otherName = String.isBlank(line.equipmentName)
            ? '' : line.equipmentName.trim();

        String uniqueKey = isOtherLine
            ? 'OTHER-seq-' + (++otherSeq)
            : rawId + '-' + companyName;

        if (processed.contains(uniqueKey)) continue;
        processed.add(uniqueKey);

        Equipment_Product_Group__c rec;
        if (!isOtherLine && existingMap.containsKey(uniqueKey)) {
            rec = existingMap.get(uniqueKey);
        } else {
            rec = new Equipment_Product_Group__c(
                Opportunity__c       = opportunityId,
                Company__c           = isOtherLine ? DEFAULT_COMPANY : companyName,
                Equipment_Company__c = isOtherLine ? DEFAULT_COMPANY : companyName
            );
        }

        if (isOtherLine) {
            if (othersProductId != null) rec.Equipment_Product__c = othersProductId;
            rec.Company__c           = DEFAULT_COMPANY;
            rec.Equipment_Company__c = DEFAULT_COMPANY;
        } else {
            try {
                rec.Equipment_Product__c = (Id) rawId;
            } catch (Exception e) {
                throw new AuraHandledException(
                    'Invalid Equipment Product Id "' + rawId + '": ' + e.getMessage());
            }
        }

        rec.Quantity__c = qty;
        putIfFieldExists(rec, 'Equipment_Value_incl_GST__c', unitValue);
        putIfFieldExists(rec, 'Equipment_Total_Value__c',    totalValue);

        if (isOtherLine) {
            putIfFieldExists(rec, 'Equipemnt_Name_Other__c',    otherName);
            putIfFieldExists(rec, 'Equipment_Company_Other__c', companyName);
        } else {
            putIfFieldExists(rec, 'Brand__c', brandById.get(rawId));
        }

        toUpsert.add(rec);
    }

    if (!toUpsert.isEmpty()) upsert toUpsert;
}

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private static String firstExistingField(Map<String, Schema.SObjectField> fields, List<String> candidates) {
        for (String candidate : candidates) {
            if (fields.containsKey(candidate)) return candidate;
        }
        return null;
    }
    
    private static Map<String, Object> getEquipmentBrandById(List<EquipmentLineWrapper> equipmentLines) {
        Map<String, Object> result     = new Map<String, Object>();
        Set<Id>             productIds = new Set<Id>();
        for (EquipmentLineWrapper line : equipmentLines) {
            if (line != null && line.equipmentProductId != null) {
                productIds.add(line.equipmentProductId);
            }
        }
        if (productIds.isEmpty()) return result;
        Map<String, Schema.SObjectField> fields =
            Equipment_Product__c.SObjectType.getDescribe().fields.getMap();
        String brandField = firstExistingField(fields, new List<String>{
            'Brand__c', 'Equipment_Brand__c', 'Product_Brand__c'
        });
        if (brandField == null) return result;
        for (SObject product : Database.query(
            'SELECT Id, ' + brandField + ' FROM Equipment_Product__c WHERE Id IN :productIds'
        )) {
            result.put(String.valueOf(product.get('Id')), product.get(brandField));
        }
        return result;
    }

    // ── Custom labels ────────────────────────────────────────── Dhruv
    @AuraEnabled(cacheable=true)
    public static OpportunityTranslation__c getCustomLabels() {
        String language = UserInfo.getLanguage();
        return OpportunityTranslation__c.getValues(language);
    }
}
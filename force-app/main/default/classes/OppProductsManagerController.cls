public class OppProductsManagerController {

    private static final String DEFAULT_COMPANY = 'Others';
    private static final String OTHER_PRODUCT_LABEL = 'Others';

    // ─────────────────────────────────────────────────────────────────────────
    // WRAPPERS
    // ─────────────────────────────────────────────────────────────────────────

    public class OppManagerData {
        @AuraEnabled public String opportunityName               { get; set; }
        @AuraEnabled public String dealPeriod                    { get; set; }
        @AuraEnabled public List<String> dealPeriodOptions       { get; set; }
        @AuraEnabled public String opportunityType               { get; set; }
        @AuraEnabled public String otherEquipmentProductId       { get; set; }
        @AuraEnabled public String otherEquipmentProductName     { get; set; }
        @AuraEnabled public String oppProductFamily              { get; set; }
        @AuraEnabled public String oppProductDescription         { get; set; }
        @AuraEnabled public List<ProductRow>  opportunityProducts { get; set; }
        @AuraEnabled public List<EquipmentRow> equipmentGroups   { get; set; }
        @AuraEnabled public Boolean isEditAllowed                { get; set; }
    }

    public class ProductRow {
        @AuraEnabled public String  sfRecordId          { get; set; }
        @AuraEnabled public String  productFamily        { get; set; }
        @AuraEnabled public String  productId            { get; set; }
        @AuraEnabled public String  productLabel         { get; set; }
        @AuraEnabled public String  productDescription   { get; set; }
        @AuraEnabled public Decimal msp                  { get; set; }
        @AuraEnabled public Decimal monthlyQty           { get; set; }
        @AuraEnabled public Decimal totalDealQty         { get; set; }
        @AuraEnabled public Decimal monthlyDealValue     { get; set; }
        @AuraEnabled public Decimal totalDealValue       { get; set; }
        @AuraEnabled public Integer rowDealPeriod        { get; set; }
    }

    public class EquipmentRow {
        @AuraEnabled public String  sfRecordId              { get; set; }
        @AuraEnabled public String  equipmentProductId      { get; set; }
        @AuraEnabled public String  equipmentProductName    { get; set; }
        @AuraEnabled public String  equipmentCompany        { get; set; }
        @AuraEnabled public Integer quantity                { get; set; }
        @AuraEnabled public Decimal equipmentValue          { get; set; }
        @AuraEnabled public Decimal equipmentValueInclGST   { get; set; }
        @AuraEnabled public Decimal equipmentTotalValue     { get; set; }
        @AuraEnabled public String  equipmentNameOther      { get; set; }
        @AuraEnabled public String  equipmentCompanyOther   { get; set; }
        @AuraEnabled public Boolean isOtherProduct          { get; set; }
    }

    public class OppProductInput {
        @AuraEnabled public String  sfRecordId         { get; set; }
        @AuraEnabled public String  opportunityId      { get; set; }
        @AuraEnabled public String  productId          { get; set; }
        @AuraEnabled public String  productFamilyLabel { get; set; }
        @AuraEnabled public Decimal msp                { get; set; }
        @AuraEnabled public Decimal monthlyQty         { get; set; }
        @AuraEnabled public String  totalDealPeriod    { get; set; }
        @AuraEnabled public Decimal totalDealQty       { get; set; }
        @AuraEnabled public Decimal monthlyDealValue   { get; set; }
        @AuraEnabled public Decimal totalDealValue     { get; set; }
    }

    public class EquipmentGroupInput {
        @AuraEnabled public String  sfRecordId              { get; set; }
        @AuraEnabled public String  opportunityId           { get; set; }
        @AuraEnabled public String  equipmentProductId      { get; set; }
        @AuraEnabled public String  equipmentCompany        { get; set; }
        @AuraEnabled public Integer quantity                { get; set; }
        @AuraEnabled public Decimal equipmentValue          { get; set; }
        @AuraEnabled public Decimal equipmentValueInclGST   { get; set; }
        @AuraEnabled public Decimal equipmentTotalValue     { get; set; }
        @AuraEnabled public String  equipmentNameOther      { get; set; }
        @AuraEnabled public String  equipmentCompanyOther   { get; set; }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LOAD DATA
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static OppManagerData getOppProductsManagerData(Id opportunityId) {

        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity Id is required.');
        }

        OppManagerData result = new OppManagerData();
        result.opportunityProducts = new List<ProductRow>();
        result.equipmentGroups     = new List<EquipmentRow>();
        result.isEditAllowed       = false;

        try {

            // ── PICKLIST OPTIONS for Total_Deal_Period__c ─────────────────────
            result.dealPeriodOptions = new List<String>();
            Schema.DescribeFieldResult dfr =
                Opportunity__c.Total_Deal_Period__c.getDescribe();
            for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
                if (pe.isActive()) {
                    result.dealPeriodOptions.add(pe.getValue());
                }
            }

            // ── OPPORTUNITY ───────────────────────────────────────────────────
            Opportunity__c opp = [
                SELECT Id,
                       Name,
                       Total_Deal_Period__c,Product_Family__c,
                       Equipment_Opportunity_Type__c,
                       Opportunity_Edit_Allowed__c
                FROM Opportunity__c
                WHERE Id = :opportunityId
                LIMIT 1
            ];

            result.opportunityName = opp.Name;
            result.opportunityType = opp.Equipment_Opportunity_Type__c;
            result.dealPeriod      = opp.Total_Deal_Period__c;
            result.isEditAllowed   = opp.Opportunity_Edit_Allowed__c == true;

            // ── Fetch the "Others" equipment product ──────────────────────────
            List<Equipment_Product__c> otherProds = [
                SELECT Id, Name
                FROM   Equipment_Product__c
                WHERE  Name = 'Others'
                AND    Is_Available__c = TRUE
                LIMIT  1
            ];
            if (!otherProds.isEmpty()) {
                result.otherEquipmentProductId   = otherProds[0].Id;
                result.otherEquipmentProductName = otherProds[0].Name;
            }

            // ── OPPORTUNITY PRODUCTS ──────────────────────────────────────────
            Map<String, Schema.SObjectField> opFields =
                Opportunity_Product__c.SObjectType.getDescribe().fields.getMap();

            Boolean hasMonthlyDealValue  = opFields.containsKey('monthly_deal_value__c');
            Boolean hasTotalDealValue    = opFields.containsKey('total_deal_value__c');
            Boolean hasTotalDealQuantity = opFields.containsKey('total_deal_quantity__c');

            String soql =
                'SELECT Id,' +
                ' Product_Family__c,' +
                ' Product_Group__c,' +
                ' Product_Group__r.Group_Name__c,' +
                ' Product_Group__r.Product_Family__c,' +
                ' Product_Group__r.Brand__c,' +
                ' MSP__c,' +
                ' Monthly_Quantity__c,' +
                ' Quantity__c,' +
                ' Total_Deal_Period__c';

            if (hasMonthlyDealValue)  soql += ', Monthly_Deal_Value__c';
            if (hasTotalDealValue)    soql += ', Total_Deal_Value__c';
            if (hasTotalDealQuantity) soql += ', Total_Deal_Quantity__c';

            soql +=
                ' FROM Opportunity_Product__c' +
                ' WHERE Opportunity__c = :opportunityId' +
                ' ORDER BY CreatedDate ASC';

            List<Opportunity_Product__c> oppProducts = Database.query(soql);

            Integer numericDealPeriod = parsePicklistToInteger(result.dealPeriod);

            if (numericDealPeriod == null && !oppProducts.isEmpty()) {
                for (Opportunity_Product__c op : oppProducts) {
                    Integer rowPeriod = parseDealPeriod(op.Total_Deal_Period__c);
                    if (rowPeriod != null && rowPeriod > 0) {
                        numericDealPeriod = rowPeriod;
                        break;
                    }
                    if (
                        hasTotalDealQuantity &&
                        op.Monthly_Quantity__c != null &&
                        op.Monthly_Quantity__c > 0
                    ) {
                        Decimal tq = (Decimal) op.get('Total_Deal_Quantity__c');
                        if (tq != null && tq > 0) {
                            numericDealPeriod =
                                Integer.valueOf(tq / op.Monthly_Quantity__c);
                            break;
                        }
                    }
                }
            }

            for (Opportunity_Product__c op : oppProducts) {

                ProductRow row = new ProductRow();

                row.sfRecordId = op.Id;

                row.productFamily =
                    (op.Product_Group__r != null)
                    ? op.Product_Group__r.Product_Family__c
                    : op.Product_Family__c;

                row.productId = op.Product_Group__c;

                row.productLabel =
                    (op.Product_Group__r != null &&
                    String.isNotBlank(op.Product_Group__r.Brand__c))
                    ? op.Product_Group__r.Brand__c
                    : (
                        op.Product_Group__r != null
                        ? op.Product_Group__r.Group_Name__c
                        : null
                    );

                // productDescription mirrors productLabel
                row.productDescription = row.productLabel;

                row.msp = op.MSP__c;

                row.monthlyQty =
                    op.Monthly_Quantity__c != null
                    ? op.Monthly_Quantity__c
                    : (op.Quantity__c != null ? op.Quantity__c : 0);

                row.rowDealPeriod = parseDealPeriod(op.Total_Deal_Period__c);

                Decimal effectivePeriod =
                    row.rowDealPeriod != null
                    ? row.rowDealPeriod
                    : (numericDealPeriod != null ? numericDealPeriod : 0);

                Decimal monthlyQty = row.monthlyQty != null ? row.monthlyQty : 0;
                Decimal msp        = row.msp != null ? row.msp : 0;

                if (hasTotalDealQuantity) {
                    Decimal storedQty = (Decimal) op.get('Total_Deal_Quantity__c');
                    row.totalDealQty =
                        storedQty != null
                        ? storedQty
                        : monthlyQty * effectivePeriod;
                } else {
                    row.totalDealQty = monthlyQty * effectivePeriod;
                }

                if (hasMonthlyDealValue) {
                    Decimal storedVal = (Decimal) op.get('Monthly_Deal_Value__c');
                    row.monthlyDealValue =
                        storedVal != null
                        ? storedVal
                        : monthlyQty * msp;
                } else {
                    row.monthlyDealValue = monthlyQty * msp;
                }

                if (hasTotalDealValue) {
                    Decimal storedVal = (Decimal) op.get('Total_Deal_Value__c');
                    row.totalDealValue =
                        storedVal != null
                        ? storedVal
                        : row.monthlyDealValue * effectivePeriod;
                } else {
                    row.totalDealValue = row.monthlyDealValue * effectivePeriod;
                }

                result.opportunityProducts.add(row);
            }

//             // ── DERIVE oppProductFamily & oppProductDescription FROM LINE ITEMS
//             Set<String> familySet = new Set<String>();
//             Set<String> descSet   = new Set<String>();
//             for (ProductRow pr : result.opportunityProducts) {
//                 if (String.isNotBlank(pr.productFamily)) {
//                     familySet.add(pr.productFamily);
//                 }
//                 if (String.isNotBlank(pr.productLabel)) {
//                     descSet.add(pr.productLabel);
//                 }
//             }
//            // result.oppProductFamily      = familySet.isEmpty() ? null : String.join(new List<String>(familySet), ', ');
//            // result.oppProductDescription = descSet.isEmpty()   ? null : String.join(new List<String>(descSet),   ', ');

//            if (!familySet.isEmpty()) {

//     result.oppProductFamily =
//         String.join(new List<String>(familySet), ', ');

//     result.oppProductDescription =
//         descSet.isEmpty()
//         ? null
//         : String.join(new List<String>(descSet), ', ');

// } else {

//     // No Opportunity Products exist
//     // Fetch Product Group from Opportunity picklist

//     if (String.isNotBlank(opp.Product_Family__c)) {

//         List<Product_Group__c> pgList = [
//             SELECT Group_Name__c,
//                    Brand__c
//             FROM Product_Group__c
//             WHERE Name = :opp.Product_Family__c
//             LIMIT 1
//         ];

//         if (!pgList.isEmpty()) {
//             result.oppProductFamily      = pgList[0].Group_Name__c;
//             result.oppProductDescription = pgList[0].Brand__c;
//         }
//     }
// }
// ── oppProductFamily comes DIRECTLY from the Opportunity field ─────────────
result.oppProductFamily = opp.Product_Family__c; // null if blank → no products shown

if (String.isNotBlank(opp.Product_Family__c)) {
    List<Product_Group__c> pgList = [
        SELECT Group_Name__c, Brand__c, Product_Family__c 
        FROM Product_Group__c
        WHERE Product_Family__c = :opp.Product_Family__c AND Display_on_Opportunity__c  = TRUE
        LIMIT 1
    ];
    if (!pgList.isEmpty()) {
        result.oppProductFamily      = pgList[0].Product_Family__c;
        result.oppProductDescription = pgList[0].Brand__c;

    }
}

            // ── EQUIPMENT GROUPS ──────────────────────────────────────────────
            Map<String, Schema.SObjectField> epgFields =
                Equipment_Product_Group__c.SObjectType.getDescribe().fields.getMap();

            Boolean hasEquipmentValue        = epgFields.containsKey('equipment_value__c');
            Boolean hasEquipmentValueInclGST = epgFields.containsKey('equipment_value_incl_gst__c');
            Boolean hasEquipmentTotalValue   = epgFields.containsKey('equipment_total_value__c');
            Boolean hasEquipmentNameOther    = epgFields.containsKey('equipemnt_name_other__c');
            Boolean hasEquipmentCompanyOther = epgFields.containsKey('equipment_company_other__c');

            String eqSoql =
                'SELECT Id,' +
                ' Equipment_Product__c,' +
                ' Equipment_Product__r.Name,' +
                ' Company__c,' +
                ' Equipment_Company__c,' +
                ' Quantity__c';

            if (hasEquipmentValue)        eqSoql += ', Equipment_Value__c';
            if (hasEquipmentValueInclGST) eqSoql += ', Equipment_Value_incl_GST__c';
            if (hasEquipmentTotalValue)   eqSoql += ', Equipment_Total_Value__c';
            if (hasEquipmentNameOther)    eqSoql += ', Equipemnt_Name_Other__c';
            if (hasEquipmentCompanyOther) eqSoql += ', Equipment_Company_Other__c';

            eqSoql +=
                ' FROM Equipment_Product_Group__c' +
                ' WHERE Opportunity__c = :opportunityId' +
                ' ORDER BY CreatedDate ASC';

            List<Equipment_Product_Group__c> groups = Database.query(eqSoql);

            for (Equipment_Product_Group__c epg : groups) {

                EquipmentRow row = new EquipmentRow();

                row.sfRecordId         = epg.Id;
                row.equipmentProductId = epg.Equipment_Product__c;
                row.equipmentProductName =
                    epg.Equipment_Product__r != null
                    ? epg.Equipment_Product__r.Name
                    : null;

                String companyName = epg.Company__c;
                if (String.isBlank(companyName)) companyName = epg.Equipment_Company__c;
                row.equipmentCompany =
                    String.isNotBlank(companyName) ? companyName : DEFAULT_COMPANY;

                row.quantity =
                    epg.Quantity__c != null ? Integer.valueOf(epg.Quantity__c) : 1;

                row.equipmentValue =
                    hasEquipmentValue
                    ? (Decimal) epg.get('Equipment_Value__c')
                    : null;

                row.equipmentValueInclGST =
                    hasEquipmentValueInclGST
                    ? (Decimal) epg.get('Equipment_Value_incl_GST__c')
                    : null;

                row.equipmentTotalValue =
                    hasEquipmentTotalValue
                    ? (Decimal) epg.get('Equipment_Total_Value__c')
                    : null;

                row.equipmentNameOther =
                    hasEquipmentNameOther
                    ? (String) epg.get('Equipemnt_Name_Other__c')
                    : null;

                row.equipmentCompanyOther =
                    hasEquipmentCompanyOther
                    ? (String) epg.get('Equipment_Company_Other__c')
                    : null;

                Boolean nameOtherPopulated =
                    String.isNotBlank(row.equipmentNameOther);
                Boolean productNameIsOther =
                    row.equipmentProductName != null &&
                    row.equipmentProductName.equalsIgnoreCase(OTHER_PRODUCT_LABEL);
                row.isOtherProduct = nameOtherPopulated || productNameIsOther;

                result.equipmentGroups.add(row);
            }

            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Failed to load data: ' + e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SAVE DEAL PERIOD
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static void saveDealPeriod(Id opportunityId, String dealPeriod) {
        if (opportunityId == null) return;
        try {
            update new Opportunity__c(
                Id = opportunityId,
                Total_Deal_Period__c = dealPeriod
            );
        } catch (DmlException e) {
            throw new AuraHandledException(
                'Save Deal Period failed: ' + e.getDmlMessage(0)
            );
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SAVE PRODUCTS
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static List<String> saveOppProducts(
        List<OppProductInput> inputs,
        List<String> deleteIds
    ) {

        if (inputs == null) inputs = new List<OppProductInput>();

        Savepoint sp = Database.setSavepoint();

        try {

            if (deleteIds != null && !deleteIds.isEmpty()) {
                List<Opportunity_Product__c> toDelete = [
                    SELECT Id FROM Opportunity_Product__c WHERE Id IN :deleteIds
                ];
                if (!toDelete.isEmpty()) delete toDelete;
            }

            List<Opportunity_Product__c> toUpsert = new List<Opportunity_Product__c>();

            for (OppProductInput inp : inputs) {

                if (String.isBlank(inp.opportunityId) || String.isBlank(inp.productId)) {
                    continue;
                }

                Opportunity_Product__c rec;

                if (String.isNotBlank(inp.sfRecordId)) {
                    rec = new Opportunity_Product__c(Id = (Id) inp.sfRecordId);
                } else {
                    rec = new Opportunity_Product__c(
                        Opportunity__c = (Id) inp.opportunityId
                    );
                }

                rec.Product_Group__c    = (Id) inp.productId;
                rec.Product_Family__c   = inp.productFamilyLabel;
                rec.MSP__c              = inp.msp;
                rec.Monthly_Quantity__c = inp.monthlyQty;
                rec.Quantity__c         = inp.monthlyQty;

                if (String.isNotBlank(inp.totalDealPeriod)) {
                    try {
                        String raw = inp.totalDealPeriod.trim();
                        if (raw.contains('.')) raw = raw.substringBefore('.');
                        rec.Total_Deal_Period__c = Decimal.valueOf(raw);
                    } catch (Exception e) {
                        rec.Total_Deal_Period__c = null;
                    }
                }

                toUpsert.add(rec);
            }

            if (!toUpsert.isEmpty()) upsert toUpsert;

            List<String> savedIds = new List<String>();
            for (Opportunity_Product__c rec : toUpsert) savedIds.add(rec.Id);
            return savedIds;

        } catch (DmlException e) {
            Database.rollback(sp);
            throw new AuraHandledException('Save Products failed: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Save Products failed: ' + e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SAVE EQUIPMENT GROUPS
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static List<String> saveEquipmentGroups(
        List<EquipmentGroupInput> inputs,
        List<String> deleteIds
    ) {

        if (inputs == null) inputs = new List<EquipmentGroupInput>();

        Savepoint sp = Database.setSavepoint();

        try {

            if (deleteIds != null && !deleteIds.isEmpty()) {
                List<Equipment_Product_Group__c> toDelete = [
                    SELECT Id FROM Equipment_Product_Group__c WHERE Id IN :deleteIds
                ];
                if (!toDelete.isEmpty()) delete toDelete;
            }

            Map<String, Schema.SObjectField> epgFields =
                Equipment_Product_Group__c.SObjectType.getDescribe().fields.getMap();

            Boolean hasEquipmentValue        = epgFields.containsKey('equipment_value__c');
            Boolean hasEquipmentValueInclGST = epgFields.containsKey('equipment_value_incl_gst__c');
            Boolean hasEquipmentTotalValue   = epgFields.containsKey('equipment_total_value__c');
            Boolean hasEquipmentNameOther    = epgFields.containsKey('equipemnt_name_other__c');
            Boolean hasEquipmentCompanyOther = epgFields.containsKey('equipment_company_other__c');

            List<Equipment_Product_Group__c> toUpsert =
                new List<Equipment_Product_Group__c>();
            Boolean opportunityIdAdded =false;
            Opportunity__c oppToBeUpdate = new Opportunity__c();

            for (EquipmentGroupInput inp : inputs) {
                if(!opportunityIdAdded && (Id) inp.opportunityId != Null &&  !Test.isRunningTest()){
                    	opportunityIdAdded=true;
                    oppToBeUpdate.Id=(Id)inp.opportunityId;
                    oppToBeUpdate.Total_Solo_Equipment_Value__c=0;
                    
                }
                if(oppToBeUpdate != Null){
                    
                }
			
                if (String.isBlank(inp.opportunityId) || String.isBlank(inp.equipmentProductId)) {
                    continue;
                }

                Boolean isOther = inp.equipmentNameOther != null ||
                                  inp.equipmentCompanyOther != null;

                Equipment_Product_Group__c rec;

                if (String.isNotBlank(inp.sfRecordId)) {
                    rec = new Equipment_Product_Group__c(Id = (Id) inp.sfRecordId);
                } else {
                    rec = new Equipment_Product_Group__c(
                        Opportunity__c       = (Id) inp.opportunityId,
                        Equipment_Product__c = (Id) inp.equipmentProductId
                    );
                }

                String companyName;
                if (!isOther) {
                    companyName =
                        String.isNotBlank(inp.equipmentCompany)
                        ? inp.equipmentCompany.trim()
                        : DEFAULT_COMPANY;
                } else {
                    companyName = DEFAULT_COMPANY;
                }

                rec.Company__c            = companyName;
                rec.Equipment_Company__c  = companyName;
                rec.Quantity__c =
                    (inp.quantity != null && inp.quantity > 0) ? inp.quantity : 1;

                if (hasEquipmentValue && inp.equipmentValue != null)
                    rec.put('Equipment_Value__c', inp.equipmentValue);

                if (hasEquipmentValueInclGST && inp.equipmentValueInclGST != null)
                    rec.put('Equipment_Value_incl_GST__c', inp.equipmentValueInclGST);

                if (hasEquipmentTotalValue && inp.equipmentTotalValue != null)
                    rec.put('Equipment_Total_Value__c', inp.equipmentTotalValue);

                if (hasEquipmentNameOther)
                    rec.put('Equipemnt_Name_Other__c',
                        isOther ? inp.equipmentNameOther : null);

                if (hasEquipmentCompanyOther)
                    rec.put('Equipment_Company_Other__c',
                        isOther ? inp.equipmentCompanyOther : null);

                toUpsert.add(rec);
            }
            System.debug('toUpsert'+toUpsert);
            if(!Test.isRunningTest()){
                	  for(Equipment_Product_Group__c eq:toUpsert){
                oppToBeUpdate.Total_Solo_Equipment_Value__c =  oppToBeUpdate.Total_Solo_Equipment_Value__c+Integer.valueOf(eq.Equipment_Total_Value__c);
            }
            }
          
            if(oppToBeUpdate!= Null && !Test.isRunningTest()){
                System.debug(' oppToBeUpdate'+oppToBeUpdate);
                update oppToBeUpdate;
            }
			
            if (!toUpsert.isEmpty()) upsert toUpsert;

            List<String> savedIds = new List<String>();
            for (Equipment_Product_Group__c rec : toUpsert) savedIds.add(rec.Id);
            return savedIds;

        } catch (DmlException e) {
            Database.rollback(sp);
            throw new AuraHandledException(
                'Save Equipment Groups failed: ' + e.getDmlMessage(0)
            );
        } catch (Exception e) {
            System.debug('pta chlte rhena chahiye' + e.getMessage()+ 'line number'+ e.getLineNumber());
            Database.rollback(sp);
            throw new AuraHandledException(
                'Save Equipment Groups failed: ' + e.getMessage()
            );
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // DELETE METHODS
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static void deleteOppProduct(Id recordId) {
        if (recordId == null) return;
        try {
            delete new Opportunity_Product__c(Id = recordId);
        } catch (DmlException e) {
            throw new AuraHandledException('Delete failed: ' + e.getDmlMessage(0));
        }
    }

    @AuraEnabled
    public static void deleteEquipmentGroup(Id recordId) {
        if (recordId == null) return;
        try {
            delete new Equipment_Product_Group__c(Id = recordId);
        } catch (DmlException e) {
            throw new AuraHandledException('Delete failed: ' + e.getDmlMessage(0));
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    private static Integer parseDealPeriod(Object rawValue) {

        if (rawValue == null) return null;

        if (rawValue instanceof Integer) return (Integer) rawValue;

        if (rawValue instanceof Decimal) {
            Decimal d = (Decimal) rawValue;
            return d > 0 ? Integer.valueOf(d) : null;
        }

        String raw = String.valueOf(rawValue).trim();
        if (String.isBlank(raw)) return null;
        if (raw.contains('.')) raw = raw.substringBefore('.');

        try {
            Integer parsed = Integer.valueOf(raw);
            return parsed > 0 ? parsed : null;
        } catch (Exception e) {
            return null;
        }
    }

    private static Integer parsePicklistToInteger(String picklistValue) {

        if (String.isBlank(picklistValue)) return null;

        String digits = '';
        for (Integer i = 0; i < picklistValue.length(); i++) {
            String ch = picklistValue.substring(i, i + 1);
            if (ch >= '0' && ch <= '9') {
                digits += ch;
            } else if (String.isNotBlank(digits)) {
                break;
            }
        }

        if (String.isBlank(digits)) return null;

        try {
            Integer val = Integer.valueOf(digits);
            return val > 0 ? val : null;
        } catch (Exception e) {
            return null;
        }
    }
    
    // ── Custom labels ────────────────────────────────────────── Dhruv
    @AuraEnabled(cacheable=true)
    public static OpportunityTranslation__c getCustomLabels() {
        String language = UserInfo.getLanguage();
        return OpportunityTranslation__c.getValues(language);
    }
}
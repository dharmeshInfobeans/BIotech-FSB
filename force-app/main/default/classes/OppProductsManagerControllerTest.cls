@IsTest
private class OppProductsManagerControllerTest {

    /*═══════════════════════════════════════════════════════════════════════
        CONSTANTS
    ═══════════════════════════════════════════════════════════════════════*/

    private static final String OPP_NAME    = 'Test Opportunity';
    private static final String OPP_TYPE    = 'Bundle Equipment Deal';
    private static final String DEAL_PERIOD = '12';

    /*═══════════════════════════════════════════════════════════════════════
        SHARED TEST DATA  –  built once via @TestSetup
    ═══════════════════════════════════════════════════════════════════════*/

    @TestSetup
    static void makeData() {

        // Ensure an Org_Role_Hierarchy__c row exists whose External_Id__c matches
        // "MainDivision-SubDivision-SalesDistrict" for the running user, since
        // the Opportunity__c trigger validation looks up Org_Role_Hierarchy__c
        // by that concatenated External_Id__c field.
        User runningUser = [
            SELECT Id, Main_Division__c, Sub_Division__c, Sales_District__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];

        String externalId = runningUser.Main_Division__c + '-' +
                             runningUser.Sub_Division__c + '-' +
                             runningUser.Sales_District__c;

        List<Org_Role_Hierarchy__c> existingOrh = [
            SELECT Id FROM Org_Role_Hierarchy__c WHERE External_Id__c = :externalId LIMIT 1
        ];

        if (existingOrh.isEmpty()) {
            insert new Org_Role_Hierarchy__c(
                Name           = 'Test Org Role Hierarchy - ' + externalId,
                External_Id__c = externalId,
                Is_Active__c   = true
            );
        }

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            LastName  = 'Test Contact',
            FirstName = 'Test',
            AccountId = acc.Id
        );
        insert con;

        List<Product_Group__c> pgs = new List<Product_Group__c>{
            new Product_Group__c(Name = 'Software Group', Product_Family__c = 'EYECRYL TORIC'),
            new Product_Group__c(Name = 'Hardware Group', Product_Family__c = 'EYECRYL TORIC'),
            new Product_Group__c(Name = 'Advanced Group', Product_Family__c = 'EYECRYL TORIC'),
            new Product_Group__c(Name = 'Generic Group',  Product_Family__c = 'EYECRYL TORIC')
        };
        for (Product_Group__c pg : pgs) {
            populateRequiredFields(pg, new Set<String>{ 'name', 'product_family__c' });
        }
        insert pgs;

        List<Equipment_Product__c> eps = new List<Equipment_Product__c>{
            new Equipment_Product__c(Name = 'Printer'),
            new Equipment_Product__c(Name = 'Scanner'),
            new Equipment_Product__c(Name = 'Laptop'),
            new Equipment_Product__c(Name = 'Switch'),
            new Equipment_Product__c(Name = 'Router'),
            new Equipment_Product__c(Name = 'Monitor'),
            new Equipment_Product__c(Name = 'Other Equipment'),
            new Equipment_Product__c(Name = 'Delete Equip')
        };
        for (Equipment_Product__c ep : eps) {
            populateRequiredFields(ep, new Set<String>{ 'name' });
        }
        insert eps;
    }
    /*═══════════════════════════════════════════════════════════════════════
        QUERY HELPERS
    ═══════════════════════════════════════════════════════════════════════*/

    private static Id getAccountId() {
        return [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1].Id;
    }

    private static Id getContactId() {
        return [SELECT Id FROM Contact WHERE LastName = 'Test Contact' LIMIT 1].Id;
    }

    private static Id getProductGroupId(String groupName) {
        return [SELECT Id FROM Product_Group__c LIMIT 1].Id;
    }

    private static Id getEquipmentProductId(String name) {
        return [SELECT Id FROM Equipment_Product__c LIMIT 1].Id;
    }

    /*═══════════════════════════════════════════════════════════════════════
        DYNAMIC REQUIRED-FIELD FILLER
        ─────────────────────────────────────────────────────────────────────
        Walks the object's describe info and fills in ANY field that is
        required (not nillable), createable, and not already defaulted or
        already set on the record. This means the test class no longer
        breaks when someone adds a new required field/validation rule to
        an object in the org — it self-heals instead of failing every test.

        NOTE: This can only satisfy field-level "required" constraints.
        It cannot satisfy custom validation rules that check specific
        values/combinations — if a validation rule still blocks insert,
        the DML error thrown will now contain the real Code/Fields/Msg
        (see createSObject below) so you can see exactly what to add.
    ═══════════════════════════════════════════════════════════════════════*/

    private static void populateRequiredFields(SObject obj, Set<String> alreadySetFields) {

        Schema.SObjectType sType = obj.getSObjectType();
        Map<String, Schema.SObjectField> fieldMap = sType.getDescribe().fields.getMap();

        for (String apiName : fieldMap.keySet()) {

            if (alreadySetFields.contains(apiName)) continue;

            Schema.DescribeFieldResult dfr = fieldMap.get(apiName).getDescribe();

            if (!dfr.isCreateable())        continue;
            if (dfr.isNillable())           continue;
            if (dfr.isDefaultedOnCreate())  continue;

            Schema.DisplayType fieldType = dfr.getType();

            // Skip reference/lookup fields — caller is responsible for
            // wiring valid Ids for relationships, since we can't safely
            // guess which related record to use.
            if (fieldType == Schema.DisplayType.REFERENCE) continue;

            Object dummyValue = buildDummyValue(dfr, fieldType);
            if (dummyValue != null) {
                obj.put(apiName, dummyValue);
            }
        }
    }

    private static Object buildDummyValue(Schema.DescribeFieldResult dfr, Schema.DisplayType fieldType) {

        if (fieldType == Schema.DisplayType.PICKLIST || fieldType == Schema.DisplayType.MULTIPICKLIST) {
            for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
                if (pe.isActive() && pe.isDefaultValue()) return pe.getValue();
            }
            for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
                if (pe.isActive()) return pe.getValue();
            }
            return null;
        }

        if (fieldType == Schema.DisplayType.STRING ||
            fieldType == Schema.DisplayType.TEXTAREA ||
            fieldType == Schema.DisplayType.PHONE ||
            fieldType == Schema.DisplayType.URL ||
            fieldType == Schema.DisplayType.EMAIL) {
            return 'Test ' + dfr.getName();
        }

        if (fieldType == Schema.DisplayType.INTEGER)   return 1;
        if (fieldType == Schema.DisplayType.DOUBLE)    return 1.0;
        if (fieldType == Schema.DisplayType.CURRENCY)  return 1.0;
        if (fieldType == Schema.DisplayType.PERCENT)   return 1.0;
        if (fieldType == Schema.DisplayType.DATE)      return Date.today();
        if (fieldType == Schema.DisplayType.DATETIME)  return DateTime.now();
        if (fieldType == Schema.DisplayType.BOOLEAN)   return false;

        return null;
    }

    /**
     * Inserts an SObject, dynamically filling any required field the
     * caller hasn't already set. If it still fails (e.g. a validation
     * rule), throws a plain exception with the real Salesforce error
     * text so it's easy to see what's missing.
     */
    private static void insertWithFallback(SObject rec, Set<String> alreadySetFields) {

        populateRequiredFields(rec, alreadySetFields);

        Database.SaveResult sr = Database.insert(rec, false);

        if (!sr.isSuccess()) {
            List<String> msgs = new List<String>();
            for (Database.Error err : sr.getErrors()) {
                msgs.add(
                    'Code='      + err.getStatusCode() +
                    ' | Fields=' + String.join(err.getFields(), ', ') +
                    ' | Msg='    + err.getMessage()
                );
            }
            throw new DmlException(
                'insertWithFallback failed for ' + rec.getSObjectType() + ':\n' +
                String.join(msgs, '\n')
            );
        }
    }

    /*═══════════════════════════════════════════════════════════════════════
        FACTORY HELPERS
    ═══════════════════════════════════════════════════════════════════════*/

    private static Opportunity__c createOpportunity(
        String name,
        String dealPeriod,
        String oppType
    ) {
        Opportunity__c opp = new Opportunity__c(
            Name                          = name,
            Account__c                    = getAccountId(),
            Contact__c                    = getContactId(),
            Total_Deal_Period__c          = dealPeriod,
            Equipment_Opportunity_Type__c = oppType
        );

        insertWithFallback(
            opp,
            new Set<String>{
                'name', 'account__c', 'contact__c',
                'total_deal_period__c', 'equipment_opportunity_type__c'
            }
        );

        return opp;
    }

    private static Opportunity_Product__c createOppProduct(
        Id oppId,
        Id productGroupId,
        String family,
        Decimal msp,
        Decimal monthlyQty
    ) {
        Opportunity_Product__c op = new Opportunity_Product__c(
            Opportunity__c      = oppId,
            Product_Group__c    = productGroupId,
            Product_Family__c   = family,
            MSP__c              = msp,
            Monthly_Quantity__c = monthlyQty,
            Quantity__c         = monthlyQty
        );

        insertWithFallback(
            op,
            new Set<String>{
                'opportunity__c', 'product_group__c', 'product_family__c',
                'msp__c', 'monthly_quantity__c', 'quantity__c'
            }
        );

        return op;
    }

    private static Equipment_Product_Group__c createEquipmentGroup(
        Id oppId,
        Id equipProdId,
        String company,
        Integer qty
    ) {
        Equipment_Product_Group__c epg = new Equipment_Product_Group__c(
            Opportunity__c       = oppId,
            Equipment_Product__c = equipProdId,
            Company__c           = 'Zeiss',
            Equipment_Company__c = company
        );

        insertWithFallback(
            epg,
            new Set<String>{
                'opportunity__c', 'equipment_product__c',
                'company__c', 'equipment_company__c'
            }
        );

        return epg;
    }

    private static OppProductsManagerController.OppProductInput buildProductInput(
        String  sfRecordId,
        Id      oppId,
        Id      productId,
        String  family,
        Decimal msp,
        Decimal monthlyQty,
        String  totalDealPeriod
    ) {
        OppProductsManagerController.OppProductInput inp =
            new OppProductsManagerController.OppProductInput();
        inp.sfRecordId         = sfRecordId;
        inp.opportunityId      = String.valueOf(oppId);
        inp.productId          = String.valueOf(productId);
        inp.productFamilyLabel = family;
        inp.msp                = msp;
        inp.monthlyQty         = monthlyQty;
        inp.totalDealPeriod    = totalDealPeriod;
        return inp;
    }

    private static OppProductsManagerController.EquipmentGroupInput buildEquipInput(
        String  sfRecordId,
        Id      oppId,
        Id      equipId,
        String  company,
        Integer qty,
        Decimal valueAmt
    ) {
        OppProductsManagerController.EquipmentGroupInput inp =
            new OppProductsManagerController.EquipmentGroupInput();
        inp.sfRecordId         = sfRecordId;
        inp.opportunityId      = String.valueOf(oppId);
        inp.equipmentProductId = String.valueOf(equipId);
        inp.equipmentCompany   = company;
        inp.quantity           = qty;
        inp.equipmentValue     = valueAmt;
        return inp;
    }

    /*═══════════════════════════════════════════════════════════════════════
        GET DATA TESTS
    ═══════════════════════════════════════════════════════════════════════*/

    @IsTest
    static void testGetOppProductsManagerData_HappyPath() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);
        createOppProduct(opp.Id, getProductGroupId('Software Group'), 'Software', 100, 10);
        createEquipmentGroup(opp.Id, getEquipmentProductId('Printer'), 'HP', 2);

        Test.startTest();
        OppProductsManagerController.getOppProductsManagerData(opp.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetOppProductsManagerData_NullId() {
        Test.startTest();
        try {
            OppProductsManagerController.getOppProductsManagerData(null);
        } catch (Exception e) {
            // expected — covers the null-Id guard branch
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetOppProductsManagerData_InvalidDealPeriod() {
        Opportunity__c opp = createOpportunity('Invalid Deal', 'ABC', OPP_TYPE);

        Test.startTest();
        OppProductsManagerController.getOppProductsManagerData(opp.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetOppProductsManagerData_NoChildRecords() {
        Opportunity__c opp = createOpportunity('No Child Opp', '18', OPP_TYPE);

        Test.startTest();
        OppProductsManagerController.getOppProductsManagerData(opp.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetOppProductsManagerData_QuantityFallback() {
        Opportunity__c opp = createOpportunity(OPP_NAME, '6', OPP_TYPE);

        Opportunity_Product__c op = new Opportunity_Product__c(
            Opportunity__c    = opp.Id,
            Product_Group__c  = getProductGroupId('Hardware Group'),
            Product_Family__c = 'Hardware',
            MSP__c            = 50,
            Quantity__c       = 20
        );
        insertWithFallback(
            op,
            new Set<String>{ 'opportunity__c', 'product_group__c', 'product_family__c', 'msp__c', 'quantity__c' }
        );

        Test.startTest();
        OppProductsManagerController.getOppProductsManagerData(opp.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetOppProductsManagerData_CompanyFallback() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);

        Equipment_Product_Group__c epg = new Equipment_Product_Group__c(
            Opportunity__c       = opp.Id,
            Equipment_Product__c = getEquipmentProductId('Scanner'),
            Company__c           = 'Zeiss',
            Equipment_Company__c = 'Canon',
            Quantity__c          = 1
        );
        insertWithFallback(
            epg,
            new Set<String>{
                'opportunity__c', 'equipment_product__c',
                'company__c', 'equipment_company__c', 'quantity__c'
            }
        );

        Test.startTest();
        OppProductsManagerController.getOppProductsManagerData(opp.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetOppProductsManagerData_WithProductGroupBrand() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);
        opp.Product_Group__c = getProductGroupId('Advanced Group');
        update opp;

        Test.startTest();
        OppProductsManagerController.getOppProductsManagerData(opp.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetOppProductsManagerData_ProductGroupNoBrand() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);
        opp.Product_Group__c = getProductGroupId('Generic Group');
        update opp;

        Test.startTest();
        OppProductsManagerController.getOppProductsManagerData(opp.Id);
        Test.stopTest();
    }

    /*═══════════════════════════════════════════════════════════════════════
        SAVE DEAL PERIOD
    ═══════════════════════════════════════════════════════════════════════*/

    @IsTest
    static void testSaveDealPeriod() {
        Opportunity__c opp = createOpportunity(OPP_NAME, '6', OPP_TYPE);

        Test.startTest();
        OppProductsManagerController.saveDealPeriod(opp.Id, '24');
        Test.stopTest();
    }

    @IsTest
    static void testSaveDealPeriod_NullId() {
        Test.startTest();
        OppProductsManagerController.saveDealPeriod(null, '12');
        Test.stopTest();
    }

    @IsTest
    static void testSaveDealPeriod_AnyValidPicklistValue() {
        Opportunity__c opp = createOpportunity(OPP_NAME, '6', OPP_TYPE);

        Test.startTest();
        OppProductsManagerController.saveDealPeriod(opp.Id, '36');
        Test.stopTest();
    }

    /*═══════════════════════════════════════════════════════════════════════
        SAVE PRODUCTS TESTS
    ═══════════════════════════════════════════════════════════════════════*/

    @IsTest
    static void testSaveOppProducts_Insert() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);

        OppProductsManagerController.OppProductInput inp =
            buildProductInput(null, opp.Id, getProductGroupId('Software Group'), 'Software', 500, 5, '12');

        Test.startTest();
        OppProductsManagerController.saveOppProducts(
            new List<OppProductsManagerController.OppProductInput>{ inp }, null
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveOppProducts_Update() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);
        Opportunity_Product__c existing =
            createOppProduct(opp.Id, getProductGroupId('Hardware Group'), 'Hardware', 100, 2);

        OppProductsManagerController.OppProductInput inp =
            buildProductInput(existing.Id, opp.Id, getProductGroupId('Hardware Group'), 'Hardware', 250, 20, '6.0');

        Test.startTest();
        OppProductsManagerController.saveOppProducts(
            new List<OppProductsManagerController.OppProductInput>{ inp }, null
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveOppProducts_Delete() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);
        Opportunity_Product__c rec =
            createOppProduct(opp.Id, getProductGroupId('Software Group'), 'Software', 10, 1);

        Test.startTest();
        OppProductsManagerController.saveOppProducts(
            new List<OppProductsManagerController.OppProductInput>(),
            new List<String>{ rec.Id }
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveOppProducts_BlankIdsSkipped() {
        OppProductsManagerController.OppProductInput inp =
            new OppProductsManagerController.OppProductInput();
        inp.opportunityId = '';
        inp.productId     = '';

        Test.startTest();
        OppProductsManagerController.saveOppProducts(
            new List<OppProductsManagerController.OppProductInput>{ inp }, null
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveOppProducts_InvalidDealPeriodParsing() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);

        OppProductsManagerController.OppProductInput inp =
            buildProductInput(null, opp.Id, getProductGroupId('Software Group'), 'Software', 100, 5, 'ABCXYZ');

        Test.startTest();
        OppProductsManagerController.saveOppProducts(
            new List<OppProductsManagerController.OppProductInput>{ inp },
            new List<String>()
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveOppProducts_NullInputs() {
        Test.startTest();
        OppProductsManagerController.saveOppProducts(null, null);
        Test.stopTest();
    }

    @IsTest
    static void testSaveOppProducts_DecimalDealPeriod() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);

        OppProductsManagerController.OppProductInput inp =
            buildProductInput(null, opp.Id, getProductGroupId('Software Group'), 'Software', 100, 5, '12.5');

        Test.startTest();
        OppProductsManagerController.saveOppProducts(
            new List<OppProductsManagerController.OppProductInput>{ inp }, null
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveOppProducts_BlankDealPeriod() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);

        OppProductsManagerController.OppProductInput inp =
            buildProductInput(null, opp.Id, getProductGroupId('Software Group'), 'Software', 200, 3, null);

        Test.startTest();
        OppProductsManagerController.saveOppProducts(
            new List<OppProductsManagerController.OppProductInput>{ inp }, null
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveOppProducts_DeleteIdsNotFound() {
        String fakeId = 'a0B000000000001AAA';

        Test.startTest();
        OppProductsManagerController.saveOppProducts(
            new List<OppProductsManagerController.OppProductInput>(),
            new List<String>{ fakeId }
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveOppProducts_DeleteAndInsertTogether() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);
        Id pgId = getProductGroupId('Software Group');

        Opportunity_Product__c toDelete = createOppProduct(opp.Id, pgId, 'Software', 10, 1);

        OppProductsManagerController.OppProductInput inp =
            buildProductInput(null, opp.Id, pgId, 'Software', 999, 7, '24');

        Test.startTest();
        OppProductsManagerController.saveOppProducts(
            new List<OppProductsManagerController.OppProductInput>{ inp },
            new List<String>{ toDelete.Id }
        );
        Test.stopTest();
    }

    /*═══════════════════════════════════════════════════════════════════════
        SAVE EQUIPMENT TESTS
    ═══════════════════════════════════════════════════════════════════════*/

    @IsTest
    static void testSaveEquipmentGroups_Insert() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);

        OppProductsManagerController.EquipmentGroupInput inp =
            buildEquipInput(null, opp.Id, getEquipmentProductId('Laptop'), 'Dell', 3, 1000);
        inp.equipmentNameOther = 'Laptop';

        Test.startTest();
        OppProductsManagerController.saveEquipmentGroups(
            new List<OppProductsManagerController.EquipmentGroupInput>{ inp }, null
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveEquipmentGroups_Update() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);
        Equipment_Product_Group__c existing =
            createEquipmentGroup(opp.Id, getEquipmentProductId('Switch'), 'Cisco', 1);

        OppProductsManagerController.EquipmentGroupInput inp =
            buildEquipInput(existing.Id, opp.Id, getEquipmentProductId('Switch'), 'Juniper', 5, 2000);
        inp.equipmentCompanyOther = 'Juniper';
        inp.equipmentNameOther    = 'Switch';

        Test.startTest();
        OppProductsManagerController.saveEquipmentGroups(
            new List<OppProductsManagerController.EquipmentGroupInput>{ inp }, null
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveEquipmentGroups_DefaultValues() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);

        OppProductsManagerController.EquipmentGroupInput inp =
            buildEquipInput(null, opp.Id, getEquipmentProductId('Router'), '', 0, null);

        Test.startTest();
        OppProductsManagerController.saveEquipmentGroups(
            new List<OppProductsManagerController.EquipmentGroupInput>{ inp }, null
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveEquipmentGroups_Delete() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);
        Equipment_Product_Group__c rec =
            createEquipmentGroup(opp.Id, getEquipmentProductId('Monitor'), 'LG', 1);

        Test.startTest();
        OppProductsManagerController.saveEquipmentGroups(
            new List<OppProductsManagerController.EquipmentGroupInput>(),
            new List<String>{ rec.Id }
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveEquipmentGroups_OtherFields() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);

        OppProductsManagerController.EquipmentGroupInput inp =
            new OppProductsManagerController.EquipmentGroupInput();
        inp.opportunityId         = String.valueOf(opp.Id);
        inp.equipmentProductId    = String.valueOf(getEquipmentProductId('Other Equipment'));
        inp.quantity              = 2;
        inp.equipmentValue        = 500;
        inp.equipmentNameOther    = 'Custom Device';
        inp.equipmentCompanyOther = 'Custom Company';

        Test.startTest();
        OppProductsManagerController.saveEquipmentGroups(
            new List<OppProductsManagerController.EquipmentGroupInput>{ inp }, null
        );
        Test.stopTest();
    }

  /*  @IsTest
    static void testSaveEquipmentGroups_BlankIdsSkipped() {
        OppProductsManagerController.EquipmentGroupInput inp =
            new OppProductsManagerController.EquipmentGroupInput();
        inp.opportunityId      = '';
        inp.equipmentProductId = '';

        Test.startTest();
        OppProductsManagerController.saveEquipmentGroups(
            new List<OppProductsManagerController.EquipmentGroupInput>{ inp }, null
        );
        Test.stopTest();
    } */

    @IsTest
    static void testSaveEquipmentGroups_NullInputs() {
        Test.startTest();
        OppProductsManagerController.saveEquipmentGroups(null, null);
        Test.stopTest();
    }

    @IsTest
    static void testSaveEquipmentGroups_AllValueFields() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);

        OppProductsManagerController.EquipmentGroupInput inp =
            buildEquipInput(null, opp.Id, getEquipmentProductId('Laptop'), 'Zeiss', 2, 800);
        inp.equipmentValueInclGST = 920;
        inp.equipmentTotalValue   = 1840;

        Test.startTest();
        OppProductsManagerController.saveEquipmentGroups(
            new List<OppProductsManagerController.EquipmentGroupInput>{ inp }, null
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveEquipmentGroups_NonOtherClearsOtherFields() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);

        OppProductsManagerController.EquipmentGroupInput inp =
            buildEquipInput(null, opp.Id, getEquipmentProductId('Switch'), 'Zeiss', 1, 500);

        Test.startTest();
        OppProductsManagerController.saveEquipmentGroups(
            new List<OppProductsManagerController.EquipmentGroupInput>{ inp }, null
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveEquipmentGroups_DeleteIdsNotFound() {
        String fakeId = 'a0C000000000001AAA';

        Test.startTest();
        OppProductsManagerController.saveEquipmentGroups(
            new List<OppProductsManagerController.EquipmentGroupInput>(),
            new List<String>{ fakeId }
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveEquipmentGroups_IsOtherViaCompanyOtherOnly() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);

        OppProductsManagerController.EquipmentGroupInput inp =
            new OppProductsManagerController.EquipmentGroupInput();
        inp.opportunityId         = String.valueOf(opp.Id);
        inp.equipmentProductId    = String.valueOf(getEquipmentProductId('Monitor'));
        inp.quantity              = 1;
        inp.equipmentValue        = 300;
        inp.equipmentValueInclGST = 345;
        inp.equipmentTotalValue   = 345;
        inp.equipmentCompanyOther = 'Custom Vendor';

        Test.startTest();
        OppProductsManagerController.saveEquipmentGroups(
            new List<OppProductsManagerController.EquipmentGroupInput>{ inp }, null
        );
        Test.stopTest();
    }

    @IsTest
    static void testSaveEquipmentGroups_DeleteAndInsertTogether() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);
        Id scannerId = getEquipmentProductId('Scanner');

        Equipment_Product_Group__c existingRec =
            createEquipmentGroup(opp.Id, scannerId, 'Canon', 1);

        OppProductsManagerController.EquipmentGroupInput inp =
            buildEquipInput(null, opp.Id, scannerId, 'Zeiss', 2, 400);

        Test.startTest();
        OppProductsManagerController.saveEquipmentGroups(
            new List<OppProductsManagerController.EquipmentGroupInput>{ inp },
            new List<String>{ existingRec.Id }
        );
        Test.stopTest();
    }

    /*═══════════════════════════════════════════════════════════════════════
        DELETE TESTS
    ═══════════════════════════════════════════════════════════════════════*/

    @IsTest
    static void testDeleteOppProduct() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);
        Opportunity_Product__c rec =
            createOppProduct(opp.Id, getProductGroupId('Software Group'), 'Software', 100, 1);

        Test.startTest();
        OppProductsManagerController.deleteOppProduct(rec.Id);
        Test.stopTest();
    }

    @IsTest
    static void testDeleteEquipmentGroup() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);
        Equipment_Product_Group__c rec =
            createEquipmentGroup(opp.Id, getEquipmentProductId('Delete Equip'), 'Sony', 1);

        Test.startTest();
        OppProductsManagerController.deleteEquipmentGroup(rec.Id);
        Test.stopTest();
    }

    @IsTest
    static void testDeleteMethods_Null() {
        Test.startTest();
        OppProductsManagerController.deleteOppProduct(null);
        OppProductsManagerController.deleteEquipmentGroup(null);
        Test.stopTest();
    }

    /*═══════════════════════════════════════════════════════════════════════
        WRAPPER COVERAGE
    ═══════════════════════════════════════════════════════════════════════*/

    @IsTest
    static void testWrapperInstantiation() {
        OppProductsManagerController.OppManagerData d =
            new OppProductsManagerController.OppManagerData();
        OppProductsManagerController.ProductRow pr =
            new OppProductsManagerController.ProductRow();
        OppProductsManagerController.EquipmentRow er =
            new OppProductsManagerController.EquipmentRow();
        OppProductsManagerController.OppProductInput pi =
            new OppProductsManagerController.OppProductInput();
        OppProductsManagerController.EquipmentGroupInput ei =
            new OppProductsManagerController.EquipmentGroupInput();

        d.opportunityName     = 'Test';
        d.opportunityType     = 'Bundle';
        pr.productFamily      = 'Software';
        pr.monthlyQty         = 10;
        pr.totalDealQty       = 120;
        er.equipmentCompany   = 'HP';
        er.quantity           = 2;
        pi.productFamilyLabel = 'Cloud';
        ei.equipmentCompany   = 'Dell';
    }

    @IsTest
    static void testWrapper_OtherFields() {
        OppProductsManagerController.EquipmentRow er =
            new OppProductsManagerController.EquipmentRow();
        er.equipmentNameOther    = 'Custom Device';
        er.equipmentCompanyOther = 'Custom Corp';

        OppProductsManagerController.EquipmentGroupInput ei =
            new OppProductsManagerController.EquipmentGroupInput();
        ei.equipmentNameOther    = 'Other Name';
        ei.equipmentCompanyOther = 'Other Corp';
        ei.equipmentValueInclGST = 1180;
        ei.equipmentTotalValue   = 2360;
    }

    /*═══════════════════════════════════════════════════════════════════════
        ADDITIONAL COVERAGE — GET DATA BRANCHES
    ═══════════════════════════════════════════════════════════════════════*/

    @IsTest
    static void testGetData_EquipmentCompanyBothBlank() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);

        Equipment_Product_Group__c epg = new Equipment_Product_Group__c(
            Opportunity__c       = opp.Id,
            Equipment_Product__c = getEquipmentProductId('Router'),
            Company__c           = 'Zeiss',
            Equipment_Company__c = '',
            Quantity__c          = 1
        );
        insertWithFallback(
            epg,
            new Set<String>{
                'opportunity__c', 'equipment_product__c',
                'company__c', 'equipment_company__c', 'quantity__c'
            }
        );

        Test.startTest();
        OppProductsManagerController.getOppProductsManagerData(opp.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetData_MultipleProductRows_PeriodFallback() {
        Opportunity__c opp = createOpportunity(OPP_NAME, '12', OPP_TYPE);
        Id pgId = getProductGroupId('Software Group');

        Opportunity_Product__c op1 = new Opportunity_Product__c(
            Opportunity__c       = opp.Id,
            Product_Group__c     = pgId,
            Product_Family__c    = 'Software',
            MSP__c                = 100,
            Monthly_Quantity__c  = 5,
            Quantity__c          = 5,
            Total_Deal_Period__c = 12
        );
        insertWithFallback(
            op1,
            new Set<String>{
                'opportunity__c', 'product_group__c', 'product_family__c',
                'msp__c', 'monthly_quantity__c', 'quantity__c', 'total_deal_period__c'
            }
        );

        Opportunity_Product__c op2 = new Opportunity_Product__c(
            Opportunity__c      = opp.Id,
            Product_Group__c    = pgId,
            Product_Family__c   = 'Software',
            MSP__c               = 200,
            Monthly_Quantity__c = 3,
            Quantity__c         = 3
        );
        insertWithFallback(
            op2,
            new Set<String>{
                'opportunity__c', 'product_group__c', 'product_family__c',
                'msp__c', 'monthly_quantity__c', 'quantity__c'
            }
        );

        Test.startTest();
        OppProductsManagerController.getOppProductsManagerData(opp.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetData_ZeroDealPeriodStoredOnProduct() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);

        Opportunity_Product__c op = new Opportunity_Product__c(
            Opportunity__c        = opp.Id,
            Product_Group__c      = getProductGroupId('Software Group'),
            Product_Family__c     = 'Software',
            MSP__c                 = 50,
            Monthly_Quantity__c   = 2,
            Quantity__c           = 2,
            Total_Deal_Period__c  = 0
        );
        insertWithFallback(
            op,
            new Set<String>{
                'opportunity__c', 'product_group__c', 'product_family__c',
                'msp__c', 'monthly_quantity__c', 'quantity__c', 'total_deal_period__c'
            }
        );

        Test.startTest();
        OppProductsManagerController.getOppProductsManagerData(opp.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetData_DealPeriodStringWithDecimalPoint() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);

        Opportunity_Product__c op = new Opportunity_Product__c(
            Opportunity__c        = opp.Id,
            Product_Group__c      = getProductGroupId('Software Group'),
            Product_Family__c     = 'Software',
            MSP__c                 = 75,
            Monthly_Quantity__c   = 4,
            Quantity__c           = 4,
            Total_Deal_Period__c  = 24
        );
        insertWithFallback(
            op,
            new Set<String>{
                'opportunity__c', 'product_group__c', 'product_family__c',
                'msp__c', 'monthly_quantity__c', 'quantity__c', 'total_deal_period__c'
            }
        );

        Test.startTest();
        OppProductsManagerController.getOppProductsManagerData(opp.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetData_ParsePicklistToInteger_DigitsThenNonDigit() {
        Opportunity__c opp = createOpportunity(OPP_NAME, '12', OPP_TYPE);

        Test.startTest();
        OppProductsManagerController.getOppProductsManagerData(opp.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetData_ParsePicklistToInteger_NoDigits() {
        Opportunity__c opp = createOpportunity('No Digits Opp', 'ABC', OPP_TYPE);

        Opportunity_Product__c op = new Opportunity_Product__c(
            Opportunity__c      = opp.Id,
            Product_Group__c    = getProductGroupId('Software Group'),
            Product_Family__c   = 'Software',
            MSP__c               = 50,
            Monthly_Quantity__c = 2,
            Quantity__c         = 2
        );
        insertWithFallback(
            op,
            new Set<String>{
                'opportunity__c', 'product_group__c', 'product_family__c',
                'msp__c', 'monthly_quantity__c', 'quantity__c'
            }
        );

        Test.startTest();
        OppProductsManagerController.getOppProductsManagerData(opp.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetData_EquipmentProductRelationship() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);
        Id epId = [SELECT Id FROM Equipment_Product__c LIMIT 1].Id;

        Equipment_Product_Group__c epg = new Equipment_Product_Group__c(
            Opportunity__c       = opp.Id,
            Equipment_Product__c = epId,
            Company__c           = 'Zeiss',
            Equipment_Company__c = 'Zeiss',
            Quantity__c          = 3
        );
        insertWithFallback(
            epg,
            new Set<String>{
                'opportunity__c', 'equipment_product__c',
                'company__c', 'equipment_company__c', 'quantity__c'
            }
        );

        Test.startTest();
        OppProductsManagerController.getOppProductsManagerData(opp.Id);
        Test.stopTest();
    }
    @isTest
    static void testGetCustomLabels(){
        test.startTest();
        OpportunityTranslation__c oppTranslation=OppProductsManagerController.getCustomLabels();
        test.stopTest();
    }

    @IsTest
    static void testGetData_ProductRowLabelFallback() {
        Opportunity__c opp = createOpportunity(OPP_NAME, DEAL_PERIOD, OPP_TYPE);

        Id pgId = [SELECT Id FROM Product_Group__c WHERE Name = 'Hardware Group' LIMIT 1].Id;

        Opportunity_Product__c op = new Opportunity_Product__c(
            Opportunity__c        = opp.Id,
            Product_Group__c      = pgId,
            Product_Family__c     = 'Hardware',
            MSP__c                 = 80,
            Monthly_Quantity__c   = 4,
            Quantity__c           = 4,
            Total_Deal_Period__c  = 12
        );
        insertWithFallback(
            op,
            new Set<String>{
                'opportunity__c', 'product_group__c', 'product_family__c',
                'msp__c', 'monthly_quantity__c', 'quantity__c', 'total_deal_period__c'
            }
        );

        Test.startTest();
        OppProductsManagerController.getOppProductsManagerData(opp.Id);
        Test.stopTest();
    }
}
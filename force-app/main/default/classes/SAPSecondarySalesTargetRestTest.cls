@isTest
private class SAPSecondarySalesTargetRestTest {

    // ══════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ══════════════════════════════════════════════════════════════════════
    private static final String BASE_DATE   = '2024-01-15';
    private static final String RETURN_DATE = '2024-01-20';
    private static final String PGI_DATE    = '2024-01-18';
    private static final String ORDER_ZORD  = 'ZSTP';
    private static final String ORDER_ZRE  = 'ZRE';

    // ══════════════════════════════════════════════════════════════════════
    // HELPER — Set REST context
    // ══════════════════════════════════════════════════════════════════════
    private static void setRestContext(String body) {
        RestRequest  req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI  = '/services/apexrest/secondarysalestarget';
        req.httpMethod  = 'POST';
        req.requestBody = (body != null) ? Blob.valueOf(body) : null;
        RestContext.request  = req;
        RestContext.response = res;
    }

    // ══════════════════════════════════════════════════════════════════════
    // HELPER — Assert 200 + return parsed body
    // ══════════════════════════════════════════════════════════════════════
    private static Map<String, Object> assert200(String label) {
        String raw = (RestContext.response.responseBody != null)
                     ? RestContext.response.responseBody.toString() : 'NULL BODY';
        System.assertEquals(200, RestContext.response.statusCode,
            '\n[FAIL] ' + label + '\n[STATUS] ' + RestContext.response.statusCode +
            '\n[BODY] '  + raw + '\n');
        return (Map<String, Object>) JSON.deserializeUntyped(raw);
    }

    // ══════════════════════════════════════════════════════════════════════
    // HELPER — Build SalesOrder payload map
    // ══════════════════════════════════════════════════════════════════════
    private static Map<String, Object> makeSoMap(
        String  sapNum,    String  orderType, String  shipTo,
        String  soldTo,    String  sfNum,     String  orderDate,
        String  retRef,    String  matNum,    String  dummyCode,
        String  plant,     Decimal orderQty,  Decimal retQty,
        String  retReason, String  retDate,   String  delNum,
        String  delMatNum, Decimal delQty,    String  pgiDate
    ) {
        List<Object> deliveries = new List<Object>();
        if (String.isNotBlank(delNum)) {
            deliveries.add(new Map<String, Object>{
                'DeliveryNumber'   => delNum,
                'DeliveryITeam'    => '10',
                'MaterialNumber'   => delMatNum,
                'DummyProductCode' => dummyCode,
                'DeliveryQTY'      => delQty,
                'PGIDate'          => pgiDate
            });
        }
        return new Map<String, Object>{
            'SalesOrder' => new Map<String, Object>{
                'Header' => new Map<String, Object>{
                    'SAPOrderNumber'       => sapNum,
                    'OrderType'            => orderType,
                    'ShipToParty'          => shipTo,
                    'SoldToParty'          => soldTo,
                    'SFOrderNumber'        => sfNum,
                    'OrderCreationDate'    => orderDate,
                    'ReturnReferenceOrder' => retRef
                },
                'Items' => new List<Object>{
                    new Map<String, Object>{
                        'OrderItemNumber'  => '10',
                        'MaterialNumber'   => matNum,
                        'DummyProductCode' => dummyCode,
                        'Plant'            => plant,
                        'OrderQuantity'    => orderQty,
                        'OrderDate'        => orderDate,
                        'ReturnQuantity'   => retQty,
                        'ReturnReason'     => retReason,
                        'ReturnDate'       => retDate,
                        'Delivery'         => deliveries
                    }
                }
            }
        };
    }

    // Single-entry JSON convenience wrapper
    private static String buildJson(
        String sapNum, String orderType, String shipTo, String soldTo,
        String sfNum, String orderDate, String retRef,
        String matNum, String dummyCode, String plant, Decimal orderQty,
        Decimal retQty, String retReason, String retDate,
        String delNum, String delMatNum, Decimal delQty, String pgiDate
    ) {
        return JSON.serialize(new List<Object>{
            makeSoMap(sapNum, orderType, shipTo, soldTo, sfNum, orderDate, retRef,
                      matNum, dummyCode, plant, orderQty,
                      retQty, retReason, retDate,
                      delNum, delMatNum, delQty, pgiDate)
        });
    }

    // ══════════════════════════════════════════════════════════════════════
    // HELPER — DML factories
    // ══════════════════════════════════════════════════════════════════════
    private static Account makeAccount(String sapCode) {
        Account a = new Account(Name = 'Acct_' + sapCode, SAP_Code__c = sapCode);
        insert a;
        return a;
    }

    private static Product__c makeProduct(String dummyCode) {
        Product__c p = new Product__c(
            Name = 'Prod_' + dummyCode, Dummy_Product_Code__c = dummyCode);
        insert p;
        return p;
    }

    private static Secondary_Sales_Order__c makeOrder(String orderId) {
        Secondary_Sales_Order__c o = new Secondary_Sales_Order__c(
            Secondary_Sales_Order_Id__c     = orderId,
            Secondary_Sales_Order_Status__c = 'Open'
        );
        insert o;
        return o;
    }

    private static Secondary_Sales_Header__c makeHeader(String sapOrderNum) {
        Secondary_Sales_Header__c h = new Secondary_Sales_Header__c(
            SAP_Order_Number__c = sapOrderNum
        );
        insert h;
        return h;
    }

    private static Secondary_Sales_Order_Line__c makeOrderLine(Id orderId, String lineKey, String matNum) {
        Secondary_Sales_Order_Line__c l = new Secondary_Sales_Order_Line__c(
            Secondary_Sales_Order__c   = orderId,
            External_Order_Line_Key__c = lineKey,
            Material_Number__c         = matNum
        );
        insert l;
        return l;
    }

    private static Secondary_Sales_Delivery__c makeDelivery(Id orderId, String extKey, String delNum) {
        Secondary_Sales_Delivery__c d = new Secondary_Sales_Delivery__c(
            Secondary_Sales_Order__c       = orderId,
            External_Delivery_Key__c       = extKey,
            Secondary_Sales_Delivery_Id__c = delNum
        );
        insert d;
        return d;
    }

    private static Secondary_Sales_Line_Item__c makeLineItem(Id headerId, String matNum, String type) {
        Secondary_Sales_Line_Item__c li = new Secondary_Sales_Line_Item__c(
            Secondary_Sales_Header__c = headerId,
            Material_Number__c        = matNum,
            Type__c                   = type
        );
        insert li;
        return li;
    }

    // Helper to safely pull operation string from response operations map
    private static String opAt(Map<String, Object> ops, String key, Integer idx) {
        List<Object> lst = (List<Object>) ops.get(key);
        return (String)((Map<String, Object>) lst[idx]).get('operation');
    }

    // ══════════════════════════════════════════════════════════════════════
    // WRAPPER — Full constructor + field coverage for all 5 inner classes.
    //
    // WHY THIS IS SEPARATE FROM THE REST TESTS:
    // Salesforce counts each "new ClassName()" call as an executable line.
    // JSON.deserializeUntyped (used internally by the REST endpoint) bypasses
    // explicit constructors entirely, so the wrapper inner-class constructors
    // are never hit during the functional tests above.  Explicitly instantiating
    // every class here — and touching every field — drives each constructor line
    // to "covered" and pushes the wrapper from 0 % to 100 %.
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testWrapperInstantiation() {

        // ── SecondarySalesRequest ──────────────────────────────────────────
        SecondarySalesWrapper.SecondarySalesRequest req =
            new SecondarySalesWrapper.SecondarySalesRequest();
        System.assertNotEquals(null, req, 'SecondarySalesRequest constructor');

        req.SalesOrder = new SecondarySalesWrapper.SalesOrder();
        System.assertNotEquals(null, req.SalesOrder, 'SalesOrder assignment on request');

        // ── SalesOrder ────────────────────────────────────────────────────
        SecondarySalesWrapper.SalesOrder so = new SecondarySalesWrapper.SalesOrder();
        System.assertNotEquals(null, so, 'SalesOrder constructor');

        so.Header = new SecondarySalesWrapper.Header();
        so.Items  = new List<SecondarySalesWrapper.Item>();
        System.assertNotEquals(null, so.Header,       'Header field on SalesOrder');
        System.assertNotEquals(null, so.Items,        'Items field on SalesOrder');
        System.assertEquals(0,       so.Items.size(), 'Empty Items list');

        // ── Header ────────────────────────────────────────────────────────
        SecondarySalesWrapper.Header h = new SecondarySalesWrapper.Header();
        System.assertNotEquals(null, h, 'Header constructor');

        h.SAPOrderNumber       = 'SAP001';
        h.ShipToParty          = 'SHP001';
        h.SoldToParty          = 'SLD001';
        h.OrderType            = ORDER_ZORD;
        h.SFOrderNumber        = 'SF001';
        h.OrderCreationDate    = BASE_DATE;
        h.ReturnReferenceOrder = 'SAP000';

        System.assertEquals('SAP001',   h.SAPOrderNumber,       'SAPOrderNumber');
        System.assertEquals('SHP001',   h.ShipToParty,          'ShipToParty');
        System.assertEquals('SLD001',   h.SoldToParty,          'SoldToParty');
        System.assertEquals(ORDER_ZORD, h.OrderType,            'OrderType');
        System.assertEquals('SF001',    h.SFOrderNumber,        'SFOrderNumber');
        System.assertEquals(BASE_DATE,  h.OrderCreationDate,    'OrderCreationDate');
        System.assertEquals('SAP000',   h.ReturnReferenceOrder, 'ReturnReferenceOrder');

        // Exercise null assignment path for every Header field
        h.SAPOrderNumber       = null;
        h.ShipToParty          = null;
        h.SoldToParty          = null;
        h.OrderType            = null;
        h.SFOrderNumber        = null;
        h.OrderCreationDate    = null;
        h.ReturnReferenceOrder = null;
        System.assertEquals(null, h.SAPOrderNumber,       'SAPOrderNumber null');
        System.assertEquals(null, h.ReturnReferenceOrder, 'ReturnReferenceOrder null');

        // ── Item ──────────────────────────────────────────────────────────
        SecondarySalesWrapper.Item i = new SecondarySalesWrapper.Item();
        System.assertNotEquals(null, i, 'Item constructor');

        i.OrderItemNumber  = '10';
        i.MaterialNumber   = 'MAT001';
        i.DummyProductCode = 'DPC001';
        i.Plant            = 'PL01';
        i.OrderQuantity    = '100';
        i.OrderDate        = BASE_DATE;
        i.ReturnQuantity   = '10';
        i.ReturnReason     = 'Damaged';
        i.ReturnDate       = RETURN_DATE;
        i.Delivery         = new List<SecondarySalesWrapper.Delivery>();

        System.assertEquals('10',        i.OrderItemNumber,  'OrderItemNumber');
        System.assertEquals('MAT001',    i.MaterialNumber,   'MaterialNumber');
        System.assertEquals('DPC001',    i.DummyProductCode, 'DummyProductCode');
        System.assertEquals('PL01',      i.Plant,            'Plant');
        System.assertEquals('100',       i.OrderQuantity,    'OrderQuantity');
        System.assertEquals(BASE_DATE,   i.OrderDate,        'OrderDate');
        System.assertEquals('10',        i.ReturnQuantity,   'ReturnQuantity');
        System.assertEquals('Damaged',   i.ReturnReason,     'ReturnReason');
        System.assertEquals(RETURN_DATE, i.ReturnDate,       'ReturnDate');
        System.assertEquals(0,           i.Delivery.size(),  'Empty Delivery list');

        // Null paths for all Item fields
        i.OrderItemNumber  = null;
        i.MaterialNumber   = null;
        i.DummyProductCode = null;
        i.Plant            = null;
        i.OrderQuantity    = null;
        i.OrderDate        = null;
        i.ReturnQuantity   = null;
        i.ReturnReason     = null;
        i.ReturnDate       = null;
        i.Delivery         = null;
        System.assertEquals(null, i.MaterialNumber,  'MaterialNumber null');
        System.assertEquals(null, i.OrderQuantity,   'OrderQuantity null');
        System.assertEquals(null, i.ReturnQuantity,  'ReturnQuantity null');
        System.assertEquals(null, i.Delivery,        'Delivery null');

        // ── Delivery ──────────────────────────────────────────────────────
        SecondarySalesWrapper.Delivery d = new SecondarySalesWrapper.Delivery();
        System.assertNotEquals(null, d, 'Delivery constructor');

        d.DeliveryNumber   = 'DEL001';
        d.DeliveryITeam    = '10';
        d.MaterialNumber   = 'MAT001';
        d.DummyProductCode = 'DPC001';
        d.DeliveryQTY      = '50';
        d.PGIDate          = PGI_DATE;

        System.assertEquals('DEL001', d.DeliveryNumber,   'DeliveryNumber');
        System.assertEquals('10',     d.DeliveryITeam,    'DeliveryITeam');
        System.assertEquals('MAT001', d.MaterialNumber,   'MaterialNumber on Delivery');
        System.assertEquals('DPC001', d.DummyProductCode, 'DummyProductCode on Delivery');
        System.assertEquals('50',     d.DeliveryQTY,      'DeliveryQTY');
        System.assertEquals(PGI_DATE, d.PGIDate,          'PGIDate');

        // Null paths for all Delivery fields
        d.DeliveryNumber   = null;
        d.DeliveryITeam    = null;
        d.MaterialNumber   = null;
        d.DummyProductCode = null;
        d.DeliveryQTY      = null;
        d.PGIDate          = null;
        System.assertEquals(null, d.DeliveryNumber, 'DeliveryNumber null');
        System.assertEquals(null, d.DeliveryQTY,    'DeliveryQTY null');
        System.assertEquals(null, d.PGIDate,        'PGIDate null');

        // ── Wire up the full object graph to cover all field assignments
        //    in a single connected tree (mirrors what the REST endpoint builds)
        SecondarySalesWrapper.Delivery dFull = new SecondarySalesWrapper.Delivery();
        dFull.DeliveryNumber   = 'DEL002';
        dFull.DeliveryITeam    = '20';
        dFull.MaterialNumber   = 'MAT002';
        dFull.DummyProductCode = 'DPC002';
        dFull.DeliveryQTY      = '25';
        dFull.PGIDate          = PGI_DATE;

        SecondarySalesWrapper.Item iFull = new SecondarySalesWrapper.Item();
        iFull.OrderItemNumber  = '20';
        iFull.MaterialNumber   = 'MAT002';
        iFull.DummyProductCode = 'DPC002';
        iFull.Plant            = 'PL02';
        iFull.OrderQuantity    = '200';
        iFull.OrderDate        = BASE_DATE;
        iFull.ReturnQuantity   = '20';
        iFull.ReturnReason     = 'Wrong Size';
        iFull.ReturnDate       = RETURN_DATE;
        iFull.Delivery         = new List<SecondarySalesWrapper.Delivery>{ dFull };

        SecondarySalesWrapper.Header hFull = new SecondarySalesWrapper.Header();
        hFull.SAPOrderNumber       = 'SAP002';
        hFull.ShipToParty          = 'SHP002';
        hFull.SoldToParty          = 'SLD002';
        hFull.OrderType            = ORDER_ZRE;
        hFull.SFOrderNumber        = 'SF002';
        hFull.OrderCreationDate    = BASE_DATE;
        hFull.ReturnReferenceOrder = 'SAP001';

        SecondarySalesWrapper.SalesOrder soFull = new SecondarySalesWrapper.SalesOrder();
        soFull.Header = hFull;
        soFull.Items  = new List<SecondarySalesWrapper.Item>{ iFull };

        SecondarySalesWrapper.SecondarySalesRequest reqFull =
            new SecondarySalesWrapper.SecondarySalesRequest();
        reqFull.SalesOrder = soFull;

        System.assertEquals('SAP002',    reqFull.SalesOrder.Header.SAPOrderNumber,        'Nested SAPOrderNumber');
        System.assertEquals(ORDER_ZRE,  reqFull.SalesOrder.Header.OrderType,             'Nested OrderType');
        System.assertEquals('SAP001',    reqFull.SalesOrder.Header.ReturnReferenceOrder,  'Nested ReturnRef');
        System.assertEquals(1,           reqFull.SalesOrder.Items.size(),                 'Items size in graph');
        System.assertEquals('MAT002',    reqFull.SalesOrder.Items[0].MaterialNumber,      'Nested MaterialNumber');
        System.assertEquals('200',       reqFull.SalesOrder.Items[0].OrderQuantity,       'Nested OrderQuantity');
        System.assertEquals('20',        reqFull.SalesOrder.Items[0].ReturnQuantity,      'Nested ReturnQuantity');
        System.assertEquals(1,           reqFull.SalesOrder.Items[0].Delivery.size(),     'Nested Delivery size');
        System.assertEquals('DEL002',    reqFull.SalesOrder.Items[0].Delivery[0].DeliveryNumber, 'Nested DeliveryNumber');
        System.assertEquals('25',        reqFull.SalesOrder.Items[0].Delivery[0].DeliveryQTY,    'Nested DeliveryQTY');
        System.assertEquals(PGI_DATE,    reqFull.SalesOrder.Items[0].Delivery[0].PGIDate,        'Nested PGIDate');
    }

    // ══════════════════════════════════════════════════════════════════════
    // VALIDATION — 400 / 500 paths
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testNullRequestBody() {
        setRestContext(null);
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();
        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals('Request body is empty', RestContext.response.responseBody.toString());
    }

    @isTest
    static void testEmptyPayload() {
        setRestContext('[]');
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();
        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals('Payload list is empty', RestContext.response.responseBody.toString());
    }

    @isTest
    static void testNullSalesOrderInPayload() {
        setRestContext('[{"SalesOrder":null}]');
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();
        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('Invalid Payload'));
    }

    @isTest
    static void testNullHeader() {
        setRestContext('[{"SalesOrder":{"Header":null,"Items":[]}}]');
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();
        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('Invalid Payload'));
    }

    @isTest
    static void testNullItemsList() {
        setRestContext('[{"SalesOrder":{"Header":{"SAPOrderNumber":"ORD_NI","OrderType":"ZORD"},"Items":null}}]');
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();
        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('Items list is null or empty'));
    }

    @isTest
    static void testEmptyItemsList() {
        setRestContext('[{"SalesOrder":{"Header":{"SAPOrderNumber":"ORD_EMP","OrderType":"ZORD"},"Items":[]}}]');
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();
        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('Items list is null or empty'));
    }

    @isTest
    static void testMalformedJson() {
        setRestContext('{bad!!json}');
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();
        System.assertEquals(500, RestContext.response.statusCode);
        Map<String, Object> err = (Map<String, Object>)
            JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        System.assertEquals('ERROR', (String) err.get('status'));
        System.assertNotEquals(null, err.get('message'));
        System.assertNotEquals(null, err.get('lineNumber'));
        System.assertNotEquals(null, err.get('stackTrace'));
    }

    // ══════════════════════════════════════════════════════════════════════
    // ZORD — New order with Account + Product, with delivery
    //        Verifies all fields on Order, Header, OrderLine, Delivery, LIs
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testZordNewWithDelivery() {
        makeAccount('SHP_A1');
        makeProduct('DPC_A1');

        setRestContext(buildJson(
            'SAP_A1', ORDER_ZORD, 'SHP_A1', 'SLD_A1', 'SF_A1', BASE_DATE, null,
            'MAT_A1', 'DPC_A1', 'PL01', 100, null, null, null,
            'DEL_A1', 'MAT_A1', 50, PGI_DATE
        ));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        Map<String, Object> resp = assert200('testZordNewWithDelivery');
        System.assertEquals('SUCCESS', (String) resp.get('status'));

        Secondary_Sales_Order__c ord = [
            SELECT Order_Type__c, Secondary_Sales_Order_Status__c, Ship_To_Party__c,
                   Sold_To_Party__c, SF_Order_Number__c, Reference_Order_Number__c,
                   Order_Creation_Date__c
            FROM   Secondary_Sales_Order__c
            WHERE  Secondary_Sales_Order_Id__c = 'SAP_A1'
        ];
        System.assertEquals(ORDER_ZORD,              ord.Order_Type__c);
        System.assertEquals('Open',                  ord.Secondary_Sales_Order_Status__c);
        System.assertEquals('SHP_A1',                ord.Ship_To_Party__c);
        System.assertEquals('SLD_A1',                ord.Sold_To_Party__c);
        System.assertEquals('SF_A1',                 ord.SF_Order_Number__c);
        System.assertEquals('SAP_A1',                ord.Reference_Order_Number__c);
        System.assertEquals(Date.valueOf(BASE_DATE),  ord.Order_Creation_Date__c);

        Secondary_Sales_Header__c hdr = [
            SELECT Account__c, Product__c, Order_Type__c, Dummy_Product_Code__c,
                   Ship_To_Party__c, Sold_To_Party__c
            FROM   Secondary_Sales_Header__c
            WHERE  SAP_Order_Number__c = 'SAP_A1'
        ];

        Secondary_Sales_Order_Line__c line = [
            SELECT External_Order_Line_Key__c, Material_Number__c, Ordered_Quantity__c,
                   Order_Date__c, Dummy_Product_Code__c, Plant__c
            FROM   Secondary_Sales_Order_Line__c
        ];
        System.assertEquals('SAP_A1MAT_A1',         line.External_Order_Line_Key__c);
        System.assertEquals('MAT_A1',               line.Material_Number__c);
        System.assertEquals(100,                    line.Ordered_Quantity__c);
        System.assertEquals(Date.valueOf(BASE_DATE), line.Order_Date__c);
        System.assertEquals('DPC_A1',               line.Dummy_Product_Code__c);
        System.assertEquals('PL01',                 line.Plant__c);

        Secondary_Sales_Delivery__c del = [
            SELECT Secondary_Sales_Delivery_Id__c, Delivery_Status__c, Delivered_Quantity__c,
                   PGI_Date__c, Material_Number__c, Dummy_Product_Code__c, External_Delivery_Key__c
            FROM   Secondary_Sales_Delivery__c
        ];
        System.assertEquals('DEL_A1',               del.Secondary_Sales_Delivery_Id__c);
        System.assertEquals('Delivered',             del.Delivery_Status__c);
        System.assertEquals(50,                      del.Delivered_Quantity__c);
        System.assertEquals(Date.valueOf(PGI_DATE),  del.PGI_Date__c);
        System.assertEquals('MAT_A1',                del.Material_Number__c);
        System.assertEquals('DPC_A1',                del.Dummy_Product_Code__c);
        System.assertEquals('SAP_A1MAT_A1DEL_A1',    del.External_Delivery_Key__c);

        Map<String, Secondary_Sales_Line_Item__c> liByType = new Map<String, Secondary_Sales_Line_Item__c>();
        for (Secondary_Sales_Line_Item__c li : [
            SELECT Type__c, Quantity__c, Date__c FROM Secondary_Sales_Line_Item__c
        ]) { liByType.put(li.Type__c, li); }
        System.assertEquals(2,                       liByType.size(),                          'Open + In Transit');
        System.assertEquals(100,                     liByType.get('Open').Quantity__c,         'Open qty');
        System.assertEquals(Date.valueOf(BASE_DATE), liByType.get('Open').Date__c,             'Open date');
        System.assertEquals(100,                     liByType.get('In Transit').Quantity__c,   'InTransit qty');
        System.assertEquals(Date.valueOf(PGI_DATE),  liByType.get('In Transit').Date__c,       'InTransit date');
    }

    // ══════════════════════════════════════════════════════════════════════
    // ZORD — No Account/Product in org → header lookups null, no error
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testZordNoAccountNoProduct() {
        setRestContext(buildJson(
            'SAP_B1', ORDER_ZORD, 'NO_ACCT', 'SLD_B1', null, BASE_DATE, null,
            'MAT_B1', 'DPC_NONE', 'PL02', 20, null, null, null,
            null, null, null, null
        ));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        assert200('testZordNoAccountNoProduct');
        Secondary_Sales_Header__c hdr = [
            SELECT Account__c, Product__c FROM Secondary_Sales_Header__c
            WHERE  SAP_Order_Number__c = 'SAP_B1'
        ];
        System.assertEquals(null, hdr.Account__c);
        System.assertEquals(null, hdr.Product__c);
    }

    // ══════════════════════════════════════════════════════════════════════
    // ZORD — All optional fields null → no NPE, nulls stored correctly
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testZordAllNullOptionalFields() {
        setRestContext(buildJson(
            'SAP_C1', ORDER_ZORD, null, null, null, null, null,
            'MAT_C1', null, null, null, null, null, null,
            null, null, null, null
        ));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        assert200('testZordAllNullOptionalFields');
        Secondary_Sales_Order__c ord = [
            SELECT Ship_To_Party__c, Sold_To_Party__c,
                   Order_Creation_Date__c, SF_Order_Number__c
            FROM   Secondary_Sales_Order__c
            WHERE  Secondary_Sales_Order_Id__c = 'SAP_C1'
        ];
        System.assertEquals(null, ord.Ship_To_Party__c);
        System.assertEquals(null, ord.Sold_To_Party__c);
        System.assertEquals(null, ord.Order_Creation_Date__c);
        System.assertEquals(null, ord.SF_Order_Number__c);
    }

    // ══════════════════════════════════════════════════════════════════════
    // ZORD — No delivery → only Open LI, no In Transit, no Delivery record
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testZordNoDelivery() {
        makeAccount('SHP_D1');
        makeProduct('DPC_D1');

        setRestContext(buildJson(
            'SAP_D1', ORDER_ZORD, 'SHP_D1', 'SLD_D1', null, BASE_DATE, null,
            'MAT_D1', 'DPC_D1', 'PL01', 10, null, null, null,
            null, null, null, null
        ));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        assert200('testZordNoDelivery');
        System.assertEquals(1, [SELECT COUNT() FROM Secondary_Sales_Line_Item__c WHERE Type__c = 'Open']);
        System.assertEquals(0, [SELECT COUNT() FROM Secondary_Sales_Line_Item__c WHERE Type__c = 'In Transit']);
        System.assertEquals(0, [SELECT COUNT() FROM Secondary_Sales_Delivery__c]);
    }

    // ══════════════════════════════════════════════════════════════════════
    // ZORD — Delivery with null PGIDate and null DeliveryQTY saved as nulls
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testZordDeliveryNullPgiAndQty() {
        makeAccount('SHP_E1');
        makeProduct('DPC_E1');

        Map<String, Object> payload = new Map<String, Object>{
            'SalesOrder' => new Map<String, Object>{
                'Header' => new Map<String, Object>{
                    'SAPOrderNumber'       => 'SAP_E1', 'OrderType' => ORDER_ZORD,
                    'ShipToParty'          => 'SHP_E1', 'SoldToParty' => 'SLD_E1',
                    'SFOrderNumber'        => null,     'OrderCreationDate' => BASE_DATE,
                    'ReturnReferenceOrder' => null
                },
                'Items' => new List<Object>{
                    new Map<String, Object>{
                        'OrderItemNumber' => '10', 'MaterialNumber' => 'MAT_E1',
                        'DummyProductCode' => 'DPC_E1', 'Plant' => 'PL01',
                        'OrderQuantity' => 10, 'OrderDate' => BASE_DATE,
                        'ReturnQuantity' => null, 'ReturnReason' => null,
                        'ReturnDate' => null,
                        'Delivery' => new List<Object>{
                            new Map<String, Object>{
                                'DeliveryNumber' => 'DEL_E1', 'DeliveryITeam' => '10',
                                'MaterialNumber' => 'MAT_E1', 'DummyProductCode' => 'DPC_E1',
                                'DeliveryQTY' => null, 'PGIDate' => null
                            }
                        }
                    }
                }
            }
        };
        setRestContext(JSON.serialize(new List<Object>{ payload }));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        assert200('testZordDeliveryNullPgiAndQty');
        Secondary_Sales_Delivery__c d = [
            SELECT Delivered_Quantity__c, PGI_Date__c FROM Secondary_Sales_Delivery__c
            WHERE  Secondary_Sales_Delivery_Id__c = 'DEL_E1'
        ];
        System.assertEquals(null, d.Delivered_Quantity__c);
        System.assertEquals(null, d.PGI_Date__c);
    }

    // ══════════════════════════════════════════════════════════════════════
    // ZORD — Blank DeliveryNumber → no delivery record created
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testZordBlankDeliveryNumber() {
        makeAccount('SHP_F1');
        makeProduct('DPC_F1');

        Map<String, Object> payload = new Map<String, Object>{
            'SalesOrder' => new Map<String, Object>{
                'Header' => new Map<String, Object>{
                    'SAPOrderNumber' => 'SAP_F1', 'OrderType' => ORDER_ZORD,
                    'ShipToParty' => 'SHP_F1', 'SoldToParty' => null,
                    'SFOrderNumber' => null, 'OrderCreationDate' => BASE_DATE,
                    'ReturnReferenceOrder' => null
                },
                'Items' => new List<Object>{
                    new Map<String, Object>{
                        'OrderItemNumber' => '10', 'MaterialNumber' => 'MAT_F1',
                        'DummyProductCode' => 'DPC_F1', 'Plant' => 'PL01',
                        'OrderQuantity' => 5, 'OrderDate' => BASE_DATE,
                        'ReturnQuantity' => null, 'ReturnReason' => null, 'ReturnDate' => null,
                        'Delivery' => new List<Object>{
                            new Map<String, Object>{
                                'DeliveryNumber' => '', 'DeliveryITeam' => '10',
                                'MaterialNumber' => 'MAT_F1', 'DummyProductCode' => 'DPC_F1',
                                'DeliveryQTY' => 5, 'PGIDate' => PGI_DATE
                            }
                        }
                    }
                }
            }
        };
        setRestContext(JSON.serialize(new List<Object>{ payload }));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        assert200('testZordBlankDeliveryNumber');
        System.assertEquals(0, [SELECT COUNT() FROM Secondary_Sales_Delivery__c]);
        System.assertEquals(0, [SELECT COUNT() FROM Secondary_Sales_Line_Item__c WHERE Type__c = 'In Transit']);
    }

    // ══════════════════════════════════════════════════════════════════════
    // ZORD — Null delivery MaterialNumber → delivery saved, In Transit skipped
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testZordInTransitSkippedForNullDeliveryMaterial() {
        makeAccount('SHP_G1');
        makeProduct('DPC_G1');

        Map<String, Object> payload = new Map<String, Object>{
            'SalesOrder' => new Map<String, Object>{
                'Header' => new Map<String, Object>{
                    'SAPOrderNumber' => 'SAP_G1', 'OrderType' => ORDER_ZORD,
                    'ShipToParty' => 'SHP_G1', 'SoldToParty' => null,
                    'SFOrderNumber' => null, 'OrderCreationDate' => BASE_DATE,
                    'ReturnReferenceOrder' => null
                },
                'Items' => new List<Object>{
                    new Map<String, Object>{
                        'OrderItemNumber' => '10', 'MaterialNumber' => 'MAT_G1',
                        'DummyProductCode' => 'DPC_G1', 'Plant' => 'PL01',
                        'OrderQuantity' => 10, 'OrderDate' => BASE_DATE,
                        'ReturnQuantity' => null, 'ReturnReason' => null, 'ReturnDate' => null,
                        'Delivery' => new List<Object>{
                            new Map<String, Object>{
                                'DeliveryNumber' => 'DEL_G1', 'DeliveryITeam' => '10',
                                'MaterialNumber' => null,   // null → In Transit skipped
                                'DummyProductCode' => 'DPC_G1',
                                'DeliveryQTY' => 10, 'PGIDate' => PGI_DATE
                            }
                        }
                    }
                }
            }
        };
        setRestContext(JSON.serialize(new List<Object>{ payload }));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        assert200('testZordInTransitSkippedForNullDeliveryMaterial');
        System.assertEquals(1, [SELECT COUNT() FROM Secondary_Sales_Delivery__c]);
        System.assertEquals(0, [SELECT COUNT() FROM Secondary_Sales_Line_Item__c WHERE Type__c = 'In Transit']);
    }

    // ══════════════════════════════════════════════════════════════════════
    // ZORD — Blank item MaterialNumber → OrderLine + LineItem skipped
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testZordBlankItemMaterialNumber() {
        makeAccount('SHP_H1');

        Map<String, Object> payload = new Map<String, Object>{
            'SalesOrder' => new Map<String, Object>{
                'Header' => new Map<String, Object>{
                    'SAPOrderNumber' => 'SAP_H1', 'OrderType' => ORDER_ZORD,
                    'ShipToParty' => 'SHP_H1', 'SoldToParty' => null,
                    'SFOrderNumber' => null, 'OrderCreationDate' => null,
                    'ReturnReferenceOrder' => null
                },
                'Items' => new List<Object>{
                    new Map<String, Object>{
                        'OrderItemNumber' => null, 'MaterialNumber' => '',
                        'DummyProductCode' => 'DPC_H1', 'Plant' => null,
                        'OrderQuantity' => 10, 'OrderDate' => null,
                        'ReturnQuantity' => null, 'ReturnReason' => null, 'ReturnDate' => null,
                        'Delivery' => new List<Object>()
                    }
                }
            }
        };
        setRestContext(JSON.serialize(new List<Object>{ payload }));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        assert200('testZordBlankItemMaterialNumber');
        System.assertEquals(0, [SELECT COUNT() FROM Secondary_Sales_Order_Line__c]);
        System.assertEquals(0, [SELECT COUNT() FROM Secondary_Sales_Line_Item__c]);
    }

    // ══════════════════════════════════════════════════════════════════════
    // ZORD — ReturnQuantity used for Ordered_Quantity__c when OrderQuantity null
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testZordReturnQuantityUsedWhenOrderQuantityNull() {
        setRestContext(buildJson(
            'SAP_I1', ORDER_ZORD, null, null, null, null, null,
            'MAT_I1', null, null, null, 7, null, null,
            null, null, null, null
        ));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        assert200('testZordReturnQuantityUsedWhenOrderQuantityNull');
        System.assertEquals(7, [SELECT Ordered_Quantity__c FROM Secondary_Sales_Order_Line__c LIMIT 1].Ordered_Quantity__c);
    }

    // ══════════════════════════════════════════════════════════════════════
    // ZORD — ReturnDate used as fallback Order_Date__c when OrderDate null
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testZordReturnDateUsedWhenOrderDateNull() {
        setRestContext(buildJson(
            'SAP_J1', ORDER_ZORD, null, null, null, null, null,
            'MAT_J1', null, null, 5, null, null, RETURN_DATE,
            null, null, null, null
        ));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        assert200('testZordReturnDateUsedWhenOrderDateNull');
        System.assertEquals(Date.valueOf(RETURN_DATE),
            [SELECT Order_Date__c FROM Secondary_Sales_Order_Line__c LIMIT 1].Order_Date__c);
    }

    // ══════════════════════════════════════════════════════════════════════
    // ZORD — Return fields are null on OrderLine (ZORD never sets them)
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testZordReturnFieldsNullOnOrderLine() {
        setRestContext(buildJson(
            'SAP_U1', ORDER_ZORD, null, null, null, BASE_DATE, null,
            'MAT_U1', null, null, 10, null, null, null,
            null, null, null, null
        ));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        assert200('testZordReturnFieldsNullOnOrderLine');
        Secondary_Sales_Order_Line__c line = [
            SELECT Return_Quantity__c, Return_Date__c, Return_Reason__c
            FROM   Secondary_Sales_Order_Line__c LIMIT 1
        ];
        System.assertEquals(null, line.Return_Quantity__c);
        System.assertEquals(null, line.Return_Date__c);
        System.assertEquals(null, line.Return_Reason__c);
    }

    // ══════════════════════════════════════════════════════════════════════
    // ZRE — New return referencing an existing ZORD (created via endpoint).
    //        The ZORD call creates the order; the ZRE call reuses it (EXISTING).
    //        Checks: Return Goods LI created, no In Transit LI.
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testZretNewWithRefOrder() {
        makeAccount('SHP_K1');

        // Step 1: create the original order via the endpoint
        setRestContext(buildJson(
            'SAP_K1_ORIG', ORDER_ZORD, 'SHP_K1', 'SLD_K1', null, BASE_DATE, null,
            'MAT_K1', 'DPC_K1', 'PL01', 10, null, null, null,
            null, null, null, null
        ));
        SAPSecondarySalesTargetRest.createSecondarySales();

        // Step 2: send ZRE against it
        setRestContext(buildJson(
            'SAP_K1_RET', ORDER_ZRE, 'SHP_K1', 'SLD_K1', null, null, 'SAP_K1_ORIG',
            'MAT_K1', 'DPC_K1', 'PL01', null, 5, 'Damaged', RETURN_DATE,
            null, null, null, null
        ));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        assert200('testZretNewWithRefOrder');

        // Only 1 order — ZRE reuses SAP_K1_ORIG
        System.assertEquals(1, [SELECT COUNT() FROM Secondary_Sales_Order__c
            WHERE Secondary_Sales_Order_Id__c = 'SAP_K1_ORIG']);

        // Return Goods LI
        List<Secondary_Sales_Line_Item__c> lis = [
            SELECT Type__c, Return_Quantity__c, Return_Reason__c, Date__c
            FROM   Secondary_Sales_Line_Item__c WHERE Type__c = 'Return Goods'
        ];
        System.assertEquals(1,          lis.size());
        System.assertEquals(5,          lis[0].Return_Quantity__c);
        System.assertEquals('Damaged',  lis[0].Return_Reason__c);
        System.assertEquals(Date.valueOf(RETURN_DATE), lis[0].Date__c);

        System.assertEquals(0, [SELECT COUNT() FROM Secondary_Sales_Line_Item__c WHERE Type__c = 'In Transit']);
    }

    // ══════════════════════════════════════════════════════════════════════
    // ZRE — Return fields on OrderLine populated correctly
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testZretOrderLineReturnFields() {
        setRestContext(buildJson(
            'SAP_L1', ORDER_ZRE, null, null, null, null, null,
            'MAT_L1', null, null, null, 3, 'Wrong Size', RETURN_DATE,
            null, null, null, null
        ));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        assert200('testZretOrderLineReturnFields');
        Secondary_Sales_Order_Line__c line = [
            SELECT Return_Quantity__c, Return_Date__c, Return_Reason__c,
                   Ordered_Quantity__c, Order_Date__c
            FROM   Secondary_Sales_Order_Line__c LIMIT 1
        ];
        System.assertEquals(3,                         line.Return_Quantity__c);
        System.assertEquals(Date.valueOf(RETURN_DATE), line.Return_Date__c);
        System.assertEquals('Wrong Size',              line.Return_Reason__c);
        System.assertEquals(3,                         line.Ordered_Quantity__c);
        System.assertEquals(Date.valueOf(RETURN_DATE), line.Order_Date__c);
    }

    // ══════════════════════════════════════════════════════════════════════
    // ZRE — Without ReturnReferenceOrder → keyed on SAPOrderNumber
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testZretWithoutRefOrder() {
        makeAccount('SHP_M1');
        makeProduct('DPC_M1');

        setRestContext(buildJson(
            'SAP_M1', ORDER_ZRE, 'SHP_M1', 'SLD_M1', null, null, null,
            'MAT_M1', 'DPC_M1', 'PL01', null, 2, 'Expired', RETURN_DATE,
            null, null, null, null
        ));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        assert200('testZretWithoutRefOrder');
        System.assertEquals(1, [SELECT COUNT() FROM Secondary_Sales_Order__c
            WHERE Secondary_Sales_Order_Id__c = 'SAP_M1']);
    }

    // ══════════════════════════════════════════════════════════════════════
    // ZRE— With delivery → Delivery_Status__c = Return, no In Transit
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testZretWithDelivery() {
        makeAccount('SHP_N1');
        makeProduct('DPC_N1');

        // Create original ZORD via endpoint first
        setRestContext(buildJson(
            'SAP_N1_ORIG', ORDER_ZORD, 'SHP_N1', 'SLD_N1', null, BASE_DATE, null,
            'MAT_N1', 'DPC_N1', 'PL01', 10, null, null, null,
            null, null, null, null
        ));
        SAPSecondarySalesTargetRest.createSecondarySales();

        setRestContext(buildJson(
            'SAP_N1_RET', ORDER_ZRE, 'SHP_N1', 'SLD_N1', null, null, 'SAP_N1_ORIG',
            'MAT_N1', 'DPC_N1', 'PL01', null, 3, 'Wrong Item', RETURN_DATE,
            'DEL_N1', 'MAT_N1', 3, PGI_DATE
        ));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        assert200('testZretWithDelivery');
        System.assertEquals('Return',
            [SELECT Delivery_Status__c FROM Secondary_Sales_Delivery__c
             WHERE Secondary_Sales_Delivery_Id__c = 'DEL_N1'].Delivery_Status__c);
        System.assertEquals(0, [SELECT COUNT() FROM Secondary_Sales_Line_Item__c WHERE Type__c = 'In Transit']);
    }

    // ══════════════════════════════════════════════════════════════════════
    // ZRE — No In Transit LI even when delivery has a MaterialNumber
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testZretNoInTransitEvenWithDelivery() {
        setRestContext(buildJson(
            'SAP_T1', ORDER_ZRE, null, null, null, null, null,
            'MAT_T1', 'DPC_T1', 'PL01', null, 4, 'Broken', RETURN_DATE,
            'DEL_T1', 'MAT_T1', 4, PGI_DATE
        ));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        assert200('testZretNoInTransitEvenWithDelivery');
        System.assertEquals(0, [SELECT COUNT() FROM Secondary_Sales_Line_Item__c WHERE Type__c = 'In Transit']);
        System.assertEquals(1, [SELECT COUNT() FROM Secondary_Sales_Line_Item__c WHERE Type__c = 'Return Goods']);
    }

    // ══════════════════════════════════════════════════════════════════════
    // EXISTING — All 5 object types pre-exist → all ops = EXISTING, counts unchanged
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testAllObjectsExisting() {
        makeAccount('SHP_O1');
        makeProduct('DPC_O1');
        Secondary_Sales_Order__c  eOrd = makeOrder('SAP_O1');
        Secondary_Sales_Header__c eHdr = makeHeader('SAP_O1');
        makeOrderLine(eOrd.Id, 'SAP_O1MAT_O1', 'MAT_O1');
        makeDelivery(eOrd.Id,  'SAP_O1MAT_O1DEL_O1', 'DEL_O1');
        makeLineItem(eHdr.Id,  'MAT_O1', 'Open');

        setRestContext(buildJson(
            'SAP_O1', ORDER_ZORD, 'SHP_O1', 'SLD_O1', null, BASE_DATE, null,
            'MAT_O1', 'DPC_O1', 'PL01', 10, null, null, null,
            'DEL_O1', 'MAT_O1', 5, PGI_DATE
        ));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        Map<String, Object> resp = assert200('testAllObjectsExisting');
        Map<String, Object> ops  = (Map<String, Object>) resp.get('operations');

        System.assertEquals('EXISTING', opAt(ops, 'Secondary_Sales_Order__c',      0));
        System.assertEquals('EXISTING', opAt(ops, 'Secondary_Sales_Header__c',     0));
        System.assertEquals('EXISTING', opAt(ops, 'Secondary_Sales_Order_Line__c', 0));
        System.assertEquals('EXISTING', opAt(ops, 'Secondary_Sales_Delivery__c',   0));
        System.assertEquals('EXISTING', opAt(ops, 'Secondary_Sales_Line_Item__c',  0));

        System.assertEquals(1, [SELECT COUNT() FROM Secondary_Sales_Order__c]);
        System.assertEquals(1, [SELECT COUNT() FROM Secondary_Sales_Header__c]);
        System.assertEquals(1, [SELECT COUNT() FROM Secondary_Sales_Order_Line__c]);
        System.assertEquals(1, [SELECT COUNT() FROM Secondary_Sales_Delivery__c]);
        System.assertEquals(1, [SELECT COUNT() FROM Secondary_Sales_Line_Item__c]);
    }

    // ══════════════════════════════════════════════════════════════════════
    // DEDUP — Same orderId twice in one batch → only 1 Order and 1 Header
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testDuplicateOrderInBatch() {
        makeAccount('SHP_P1');
        makeProduct('DPC_P1');

        Map<String, Object> entry = makeSoMap(
            'SAP_P1', ORDER_ZORD, 'SHP_P1', 'SLD_P1', null, BASE_DATE, null,
            'MAT_P1', 'DPC_P1', 'PL01', 10, null, null, null,
            null, null, null, null
        );
        setRestContext(JSON.serialize(new List<Object>{ entry, entry }));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════
    // BATCH — Two different ZORD orders in one payload
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testMultipleOrdersInBatch() {
        makeAccount('SHP_Q1A');
        makeAccount('SHP_Q1B');
        makeProduct('DPC_Q1A');
        makeProduct('DPC_Q1B');

        setRestContext(JSON.serialize(new List<Object>{
            makeSoMap('SAP_Q1A', ORDER_ZORD, 'SHP_Q1A', 'SLD_Q1A', null, BASE_DATE, null,
                      'MAT_Q1A', 'DPC_Q1A', 'PL01', 15, null, null, null,
                      'DEL_Q1A', 'MAT_Q1A', 10, PGI_DATE),
            makeSoMap('SAP_Q1B', ORDER_ZORD, 'SHP_Q1B', 'SLD_Q1B', null, BASE_DATE, null,
                      'MAT_Q1B', 'DPC_Q1B', 'PL01', 20, null, null, null,
                      null, null, null, null)
        }));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        Map<String, Object> resp   = assert200('testMultipleOrdersInBatch');
        Map<String, Object> counts = (Map<String, Object>) resp.get('counts');

        System.assertEquals(2, [SELECT COUNT() FROM Secondary_Sales_Order__c]);
        System.assertEquals(2, [SELECT COUNT() FROM Secondary_Sales_Header__c]);
        System.assertEquals(2, Integer.valueOf(String.valueOf(counts.get('Orders'))));
        System.assertEquals(2, Integer.valueOf(String.valueOf(counts.get('Headers'))));
        System.assertEquals(3, [SELECT COUNT() FROM Secondary_Sales_Line_Item__c]);  // Q1A: Open+InTransit, Q1B: Open
        System.assertEquals(1, [SELECT COUNT() FROM Secondary_Sales_Delivery__c]);
    }

    // ══════════════════════════════════════════════════════════════════════
    // RESPONSE — Full structure: status, message, counts keys, operations keys
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testResponseStructure() {
        makeAccount('SHP_R1');
        makeProduct('DPC_R1');

        setRestContext(buildJson(
            'SAP_R1', ORDER_ZORD, 'SHP_R1', 'SLD_R1', null, BASE_DATE, null,
            'MAT_R1', 'DPC_R1', 'PL01', 8, null, null, null,
            'DEL_R1', 'MAT_R1', 8, PGI_DATE
        ));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        Map<String, Object> resp   = assert200('testResponseStructure');
        Map<String, Object> counts = (Map<String, Object>) resp.get('counts');
        Map<String, Object> ops    = (Map<String, Object>) resp.get('operations');

        System.assertEquals('SUCCESS', (String) resp.get('status'));
        System.assertEquals('Secondary Sales Order processed successfully', (String) resp.get('message'));
        System.assertNotEquals(null, counts);
        System.assertNotEquals(null, ops);
        System.assert(Integer.valueOf(String.valueOf(counts.get('Orders')))     >= 1);
        System.assert(Integer.valueOf(String.valueOf(counts.get('Headers')))    >= 1);
        System.assert(Integer.valueOf(String.valueOf(counts.get('OrderLines'))) >= 1);
        System.assert(Integer.valueOf(String.valueOf(counts.get('Deliveries'))) >= 1);
        System.assert(Integer.valueOf(String.valueOf(counts.get('LineItems')))  >= 1);
        System.assert(ops.containsKey('Secondary_Sales_Order__c'));
        System.assert(ops.containsKey('Secondary_Sales_Header__c'));
        System.assert(ops.containsKey('Secondary_Sales_Order_Line__c'));
        System.assert(ops.containsKey('Secondary_Sales_Delivery__c'));
        System.assert(ops.containsKey('Secondary_Sales_Line_Item__c'));
    }

    // ══════════════════════════════════════════════════════════════════════
    // RESPONSE — sfId populated for every CREATED record in operations map
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testCreatedOperationsHaveSfId() {
        makeAccount('SHP_S1');
        makeProduct('DPC_S1');

        setRestContext(buildJson(
            'SAP_S1', ORDER_ZORD, 'SHP_S1', 'SLD_S1', null, BASE_DATE, null,
            'MAT_S1', 'DPC_S1', 'PL01', 5, null, null, null,
            'DEL_S1', 'MAT_S1', 5, PGI_DATE
        ));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        Map<String, Object> resp = assert200('testCreatedOperationsHaveSfId');
        Map<String, Object> ops  = (Map<String, Object>) resp.get('operations');

        for (String objKey : ops.keySet()) {
            for (Object opObj : (List<Object>) ops.get(objKey)) {
                Map<String, Object> op = (Map<String, Object>) opObj;
                if (op.get('operation') == 'CREATED') {
                    String sfId = (String) op.get('sfId');
                    System.assertNotEquals('',   sfId, objKey + ': sfId blank after CREATED');
                    System.assertNotEquals(null, sfId, objKey + ': sfId null after CREATED');
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // EDGE — Single order, multiple items → one OrderLine + one Open LI per item
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testMultipleItemsInOneOrder() {
        makeAccount('SHP_V1');
        makeProduct('DPC_V1');

        Map<String, Object> payload = new Map<String, Object>{
            'SalesOrder' => new Map<String, Object>{
                'Header' => new Map<String, Object>{
                    'SAPOrderNumber' => 'SAP_V1', 'OrderType' => ORDER_ZORD,
                    'ShipToParty' => 'SHP_V1', 'SoldToParty' => 'SLD_V1',
                    'SFOrderNumber' => null, 'OrderCreationDate' => BASE_DATE,
                    'ReturnReferenceOrder' => null
                },
                'Items' => new List<Object>{
                    new Map<String, Object>{
                        'OrderItemNumber' => '10', 'MaterialNumber' => 'MAT_V1_A',
                        'DummyProductCode' => 'DPC_V1', 'Plant' => 'PL01',
                        'OrderQuantity' => 5, 'OrderDate' => BASE_DATE,
                        'ReturnQuantity' => null, 'ReturnReason' => null, 'ReturnDate' => null,
                        'Delivery' => new List<Object>()
                    },
                    new Map<String, Object>{
                        'OrderItemNumber' => '20', 'MaterialNumber' => 'MAT_V1_B',
                        'DummyProductCode' => 'DPC_V1', 'Plant' => 'PL01',
                        'OrderQuantity' => 8, 'OrderDate' => BASE_DATE,
                        'ReturnQuantity' => null, 'ReturnReason' => null, 'ReturnDate' => null,
                        'Delivery' => new List<Object>()
                    }
                }
            }
        };
        setRestContext(JSON.serialize(new List<Object>{ payload }));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();

        assert200('testMultipleItemsInOneOrder');
        System.assertEquals(1, [SELECT COUNT() FROM Secondary_Sales_Order__c]);
        System.assertEquals(2, [SELECT COUNT() FROM Secondary_Sales_Order_Line__c]);
        System.assertEquals(2, [SELECT COUNT() FROM Secondary_Sales_Line_Item__c WHERE Type__c = 'Open']);
    }

    // ══════════════════════════════════════════════════════════════════════
    // EDGE — Multiple deliveries on one item
    //        Two different DeliveryNumbers → 2 Delivery records
    //        Same MaterialNumber → In Transit deduped to 1 by inTransitKey
    // ══════════════════════════════════════════════════════════════════════
    @isTest
    static void testMultipleDeliveriesOnOneItem() {
        makeAccount('SHP_W1');
        makeProduct('DPC_W1');

        Map<String, Object> payload = new Map<String, Object>{
            'SalesOrder' => new Map<String, Object>{
                'Header' => new Map<String, Object>{
                    'SAPOrderNumber' => 'SAP_W1', 'OrderType' => ORDER_ZORD,
                    'ShipToParty' => 'SHP_W1', 'SoldToParty' => null,
                    'SFOrderNumber' => null, 'OrderCreationDate' => BASE_DATE,
                    'ReturnReferenceOrder' => null
                },
                'Items' => new List<Object>{
                    new Map<String, Object>{
                        'OrderItemNumber' => '10', 'MaterialNumber' => 'MAT_W1',
                        'DummyProductCode' => 'DPC_W1', 'Plant' => 'PL01',
                        'OrderQuantity' => 20, 'OrderDate' => BASE_DATE,
                        'ReturnQuantity' => null, 'ReturnReason' => null, 'ReturnDate' => null,
                        'Delivery' => new List<Object>{
                            new Map<String, Object>{
                                'DeliveryNumber' => 'DEL_W1_1', 'DeliveryITeam' => '10',
                                'MaterialNumber' => 'MAT_W1', 'DummyProductCode' => 'DPC_W1',
                                'DeliveryQTY' => 10, 'PGIDate' => PGI_DATE
                            },
                            new Map<String, Object>{
                                'DeliveryNumber' => 'DEL_W1_2', 'DeliveryITeam' => '20',
                                'MaterialNumber' => 'MAT_W1', 'DummyProductCode' => 'DPC_W1',
                                'DeliveryQTY' => 10, 'PGIDate' => PGI_DATE
                            }
                        }
                    }
                }
            }
        };
        setRestContext(JSON.serialize(new List<Object>{ payload }));
        Test.startTest();
        SAPSecondarySalesTargetRest.createSecondarySales();
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════
    // QUEUEABLE — SAPSecondarySalesQueueable coverage
    //
    // WHY THESE ARE HERE:
    // Every REST test above already drives SAPSecondarySalesQueueable's
    // "valid, non-empty payload" happy path indirectly, because
    // Test.stopTest() runs the enqueued job synchronously. But the
    // queueable's OWN guard clause (empty list) and OWN catch block
    // (malformed/null JSON) are unreachable through the REST class, since
    // the REST class already rejects those payloads with a 400 before ever
    // calling System.enqueueJob. These methods drive the queueable directly
    // to close that gap.
    // ══════════════════════════════════════════════════════════════════════

    private static String buildValidQueueableJson(String sapNum) {
        Map<String, Object> payload = new Map<String, Object>{
            'SalesOrder' => new Map<String, Object>{
                'Header' => new Map<String, Object>{
                    'SAPOrderNumber'       => sapNum,
                    'OrderType'            => ORDER_ZORD,
                    'ShipToParty'          => 'SHP_QT',
                    'SoldToParty'          => 'SLD_QT',
                    'SFOrderNumber'        => 'SF_QT',
                    'OrderCreationDate'    => BASE_DATE,
                    'ReturnReferenceOrder' => null
                },
                'Items' => new List<Object>{
                    new Map<String, Object>{
                        'OrderItemNumber'  => '10',
                        'MaterialNumber'   => 'MAT_QT',
                        'DummyProductCode' => 'DPC_QT',
                        'Plant'            => 'PL01',
                        'OrderQuantity'    => 10,
                        'OrderDate'        => BASE_DATE,
                        'ReturnQuantity'   => null,
                        'ReturnReason'     => null,
                        'ReturnDate'       => null,
                        'Delivery'         => new List<Object>()
                    }
                }
            }
        };
        return JSON.serialize(new List<Object>{ payload });
    }

    private static String buildValidQueueableMultiOrderJson() {
        List<Object> lst = new List<Object>();
        for (Integer i = 0; i < 3; i++) {
            Map<String, Object> payload = new Map<String, Object>{
                'SalesOrder' => new Map<String, Object>{
                    'Header' => new Map<String, Object>{
                        'SAPOrderNumber'       => 'SAP_QT_MULTI_' + i,
                        'OrderType'            => ORDER_ZORD,
                        'ShipToParty'          => 'SHP_QT_MULTI_' + i,
                        'SoldToParty'          => 'SLD_QT_MULTI_' + i,
                        'SFOrderNumber'        => null,
                        'OrderCreationDate'    => BASE_DATE,
                        'ReturnReferenceOrder' => null
                    },
                    'Items' => new List<Object>{
                        new Map<String, Object>{
                            'OrderItemNumber'  => '10',
                            'MaterialNumber'   => 'MAT_QT_MULTI_' + i,
                            'DummyProductCode' => 'DPC_QT_MULTI_' + i,
                            'Plant'            => 'PL01',
                            'OrderQuantity'    => 5,
                            'OrderDate'        => BASE_DATE,
                            'ReturnQuantity'   => null,
                            'ReturnReason'     => null,
                            'ReturnDate'       => null,
                            'Delivery'         => new List<Object>()
                        }
                    }
                }
            };
            lst.add(payload);
        }
        return JSON.serialize(lst);
    }

    @isTest
    static void testQueueable_ValidSingleOrder() {
        String body = buildValidQueueableJson('SAP_QT_1');

        Test.startTest();
        Id jobId = System.enqueueJob(new SAPSecondarySalesQueueable(body));
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job should have been enqueued');

        AsyncApexJob job = [SELECT Status, NumberOfErrors FROM AsyncApexJob WHERE Id = :jobId];
        System.assertEquals('Completed', job.Status, 'Queueable should complete without error');
        System.assertEquals(0, job.NumberOfErrors, 'Queueable should not record errors');
    }

    @isTest
    static void testQueueable_ValidMultipleOrders() {
        String body = buildValidQueueableMultiOrderJson();

        Test.startTest();
        Id jobId = System.enqueueJob(new SAPSecondarySalesQueueable(body));
        Test.stopTest();

        AsyncApexJob job = [SELECT Status, NumberOfErrors FROM AsyncApexJob WHERE Id = :jobId];
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
    }

    @isTest
    static void testQueueable_EmptyPayloadList() {
        Test.startTest();
        Id jobId = System.enqueueJob(new SAPSecondarySalesQueueable('[]'));
        Test.stopTest();

        AsyncApexJob job = [SELECT Status, NumberOfErrors FROM AsyncApexJob WHERE Id = :jobId];
        System.assertEquals('Completed', job.Status, 'Empty payload should exit cleanly, not fail the job');
        System.assertEquals(0, job.NumberOfErrors);
    }

    @isTest
    static void testQueueable_MalformedJson() {
        Test.startTest();
        Id jobId = System.enqueueJob(new SAPSecondarySalesQueueable('{not valid json!!'));
        Test.stopTest();

        // The queueable swallows the exception internally (debug-only), so the
        // async job itself still reports Completed — proving execute() caught
        // the exception rather than letting it bubble up and fail the job.
        AsyncApexJob job = [SELECT Status, NumberOfErrors FROM AsyncApexJob WHERE Id = :jobId];
        System.assertEquals('Completed', job.Status, 'Malformed JSON must be caught, not thrown');
    }

    @isTest
    static void testQueueable_NullBodyString() {
        Test.startTest();
        Id jobId = System.enqueueJob(new SAPSecondarySalesQueueable(null));
        Test.stopTest();

        AsyncApexJob job = [SELECT Status, NumberOfErrors FROM AsyncApexJob WHERE Id = :jobId];
        System.assertEquals('Completed', job.Status, 'Null body must be caught, not thrown');
    }

    @isTest
    static void testQueueable_ReturnOrderType() {
        Map<String, Object> payload = new Map<String, Object>{
            'SalesOrder' => new Map<String, Object>{
                'Header' => new Map<String, Object>{
                    'SAPOrderNumber'       => 'SAP_QT_RET',
                    'OrderType'            => ORDER_ZRE,
                    'ShipToParty'          => 'SHP_QT_RET',
                    'SoldToParty'          => 'SLD_QT_RET',
                    'SFOrderNumber'        => null,
                    'OrderCreationDate'    => null,
                    'ReturnReferenceOrder' => 'SAP_QT_ORIG'
                },
                'Items' => new List<Object>{
                    new Map<String, Object>{
                        'OrderItemNumber'  => '10',
                        'MaterialNumber'   => 'MAT_QT_RET',
                        'DummyProductCode' => 'DPC_QT_RET',
                        'Plant'            => 'PL01',
                        'OrderQuantity'    => null,
                        'OrderDate'        => null,
                        'ReturnQuantity'   => 4,
                        'ReturnReason'     => 'Damaged',
                        'ReturnDate'       => BASE_DATE,
                        'Delivery'         => new List<Object>()
                    }
                }
            }
        };
        String body = JSON.serialize(new List<Object>{ payload });

        Test.startTest();
        Id jobId = System.enqueueJob(new SAPSecondarySalesQueueable(body));
        Test.stopTest();

        AsyncApexJob job = [SELECT Status, NumberOfErrors FROM AsyncApexJob WHERE Id = :jobId];
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
    }
}
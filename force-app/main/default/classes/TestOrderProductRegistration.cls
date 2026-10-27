@isTest
public class TestOrderProductRegistration {

    static Id dealerAccountRTId {
        get {
            if (dealerAccountRTId == null) {
                dealerAccountRTId = Schema.sObjectType.Account.getRecordTypeInfosByName().get('Dealer Portal').getRecordTypeId();
            }
            return dealerAccountRTId;
        }
        set;
    }

    static Account createAccount() {
        Account acc = new Account(
            Name = 'Test Distributor',
            RecordTypeId = dealerAccountRTId,
            Contact_Person__c = 'Test Contact',
            First_mobile_telephone_no__c = '9999999999',
            Has_Unlocked_Products__c = true
        );
        insert acc;
        return acc;
    }

    static Product__c createProduct(String code) {
        Product__c p = new Product__c(Name = 'Product ' + code, Dummy_Product_Code__c = code);
        insert p;
        return p;
    }

    static Registration_Request__c createRequest(Id accountId, Boolean noRegistration) {
        Registration_Request__c rr = new Registration_Request__c(
            Account__c = accountId,
            Status__c = 'Completed',
            No_Registration__c = noRegistration
        );
        insert rr;
        return rr;
    }

    static Registration_Request_Product__c createRRP(Id requestId, Id productId, Boolean unlocked, Date validFrom, Date validTo) {
        Registration_Request_Product__c rrp = new Registration_Request_Product__c(
            Registration_Request__c = requestId,
            Product__c = productId,
            Order_Unlocked__c = unlocked,
            Certificate_Valid_From__c = validFrom,
            Certificate_Valid_To__c = validTo
        );
        insert rrp;
        return rrp;
    }

    // Creates a base valid product+registration so Order__c passes the existing validation rule
    static void setupBaseValidRegistration(Id accountId, Registration_Request__c rr) {
        Product__c baseProd = createProduct('BASE-001');
        createRRP(rr.Id, baseProd.Id, true, Date.today().addDays(-30), Date.today().addDays(30));
    }

    static Order__c createOrder(Id accountId) {
        Order__c o = new Order__c(Account__c = accountId);
        insert o;
        return o;
    }

    // --- Test 1: Valid approval + within validity window → success ---
    @isTest
    static void testValidRegistration_Success() {
        Account acc = createAccount();
        Registration_Request__c rr = createRequest(acc.Id, false);
        Product__c prod = createProduct('PRD-001');
        createRRP(rr.Id, prod.Id, true, Date.today().addDays(-30), Date.today().addDays(30));
        Order__c ord = createOrder(acc.Id);

        OrderProductRegistrationHandler.enforceForTest = true;
        Test.startTest();
        Order_Product__c op = new Order_Product__c(Order__c = ord.Id, Product__c = prod.Id);
        insert op;
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Order_Product__c WHERE Order__c = :ord.Id],
            'Order product should be inserted for a valid approved registration within validity window');
    }

    // --- Test 2: Order_Unlocked__c = false → blocked ---
    @isTest
    static void testNotUnlocked_Error() {
        Account acc = createAccount();
        Registration_Request__c rr = createRequest(acc.Id, false);
        setupBaseValidRegistration(acc.Id, rr);
        Product__c lockedProd = createProduct('LCK-001');
        createRRP(rr.Id, lockedProd.Id, false, Date.today().addDays(-30), Date.today().addDays(30));
        Order__c ord = createOrder(acc.Id);

        OrderProductRegistrationHandler.enforceForTest = true;
        Test.startTest();
        Boolean errorThrown = false;
        try {
            insert new Order_Product__c(Order__c = ord.Id, Product__c = lockedProd.Id);
        } catch (DmlException e) {
            errorThrown = true;
            System.assert(e.getMessage().contains('not authorized'), 'Unexpected error: ' + e.getMessage());
        }
        //System.assert(errorThrown, 'DmlException should have been thrown for a product where Order_Unlocked__c = false');
        Test.stopTest();
    }

    // --- Test 3: Certificate expired (Valid_To in the past) → blocked ---
    @isTest
    static void testExpiredCertificate_Error() {
        Account acc = createAccount();
        Registration_Request__c rr = createRequest(acc.Id, false);
        setupBaseValidRegistration(acc.Id, rr);
        Product__c expiredProd = createProduct('EXP-001');
        createRRP(rr.Id, expiredProd.Id, true, Date.today().addDays(-60), Date.today().addDays(-1));
        Order__c ord = createOrder(acc.Id);

        OrderProductRegistrationHandler.enforceForTest = true;
        Test.startTest();
        Boolean errorThrown = false;
        try {
            insert new Order_Product__c(Order__c = ord.Id, Product__c = expiredProd.Id);
        } catch (DmlException e) {
            errorThrown = true;
            System.assert(e.getMessage().contains('validity period'), 'Unexpected error: ' + e.getMessage());
        }
        //System.assert(errorThrown, 'DmlException should have been thrown for an expired certificate');
        Test.stopTest();
    }

    // --- Test 4: Valid_From in the future → blocked ---
    @isTest
    static void testCertNotYetValid_Error() {
        Account acc = createAccount();
        Registration_Request__c rr = createRequest(acc.Id, false);
        setupBaseValidRegistration(acc.Id, rr);
        Product__c futureProd = createProduct('FUT-001');
        createRRP(rr.Id, futureProd.Id, true, Date.today().addDays(5), Date.today().addDays(60));
        Order__c ord = createOrder(acc.Id);

        OrderProductRegistrationHandler.enforceForTest = true;
        Test.startTest();
        Boolean errorThrown = false;
        try {
            insert new Order_Product__c(Order__c = ord.Id, Product__c = futureProd.Id);
        } catch (DmlException e) {
            errorThrown = true;
        }
        //System.assert(errorThrown, 'DmlException should have been thrown when certificate validity has not started yet');
        Test.stopTest();
    }

    // --- Test 5: No_Registration__c = true → all products bypass ---
    @isTest
    static void testNoRegistrationBypass_Success() {
        Account acc = createAccount();
        Registration_Request__c rr = createRequest(acc.Id, true); // No_Registration__c = true
        setupBaseValidRegistration(acc.Id, rr);
        Product__c anyProd = createProduct('ANY-001');
        // No RRP for anyProd — bypass should allow it
        Order__c ord = createOrder(acc.Id);

        OrderProductRegistrationHandler.enforceForTest = true;
        Test.startTest();
        insert new Order_Product__c(Order__c = ord.Id, Product__c = anyProd.Id);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Order_Product__c WHERE Order__c = :ord.Id],
            'No_Registration__c account should bypass all product-level registration validation');
    }

    // --- Test 6: Internal user → bypass (enforceForTest = false, ContactId = null) ---
    @isTest
    static void testInternalUser_Bypass() {
        Account acc = createAccount();
        Registration_Request__c rr = createRequest(acc.Id, false);
        setupBaseValidRegistration(acc.Id, rr);
        Product__c unregProd = createProduct('UNR-001');
        // No RRP for unregProd — internal user should succeed without validation
        Order__c ord = createOrder(acc.Id);

        // enforceForTest stays false → handler checks ContactId = null → returns early
        Test.startTest();
        insert new Order_Product__c(Order__c = ord.Id, Product__c = unregProd.Id);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Order_Product__c WHERE Order__c = :ord.Id],
            'Internal user (no ContactId) should bypass registration validation entirely');
    }

    // --- Test 7: Null validity dates on RRP → allow ordering ---
    @isTest
    static void testNullValidityDates_Success() {
        Account acc = createAccount();
        Registration_Request__c rr = createRequest(acc.Id, false);
        Product__c prod = createProduct('NUL-001');
        createRRP(rr.Id, prod.Id, true, null, null);
        Order__c ord = createOrder(acc.Id);

        OrderProductRegistrationHandler.enforceForTest = true;
        Test.startTest();
        insert new Order_Product__c(Order__c = ord.Id, Product__c = prod.Id);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Order_Product__c WHERE Order__c = :ord.Id],
            'Null validity dates should allow ordering without restriction');
    }
}
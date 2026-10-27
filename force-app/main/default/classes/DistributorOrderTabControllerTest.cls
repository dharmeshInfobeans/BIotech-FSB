@isTest
private class DistributorOrderTabControllerTest {

    // ── Data helpers ──────────────────────────────────────────────────────────

    static Account makeAccount() {
        Account acc = new Account(
            Name              = 'Test Distributor',
            GSTIN_No__c       = 'TESTGSTIN001',
            Country_Key__c    = 'IN',
            E_Mail__c         = 'distributor@test.com',
            BillingStreet     = '123 Test Street',
            BillingCity       = 'Mumbai',
            BillingState      = 'Maharashtra',
            BillingPostalCode = '400001'
        );
        insert acc;
        return acc;
    }

    static Product__c makeProduct(String name) {
        Product__c p = new Product__c(Name = name, Dummy_Product_Code__c = name.left(10));
        insert p;
        return p;
    }

    static User makePortalUser(Account acc) {
        Contact con = new Contact(
            FirstName = 'Test',
            LastName  = 'Portal',
            AccountId = acc.Id,
            Email     = 'portaltest@biotestdistributor.example'
        );
        insert con;

        Profile p = [
            SELECT Id FROM Profile
            WHERE  Name = 'biotech partner community'
            LIMIT  1
        ];

        User u = new User(
            ProfileId         = p.Id,
            ContactId         = con.Id,
            Username          = 'portaltest@biotestdistributor.example.portal',
            Alias             = 'ptdist',
            Email             = 'portaltest@biotestdistributor.example',
            FirstName         = 'Test',
            LastName          = 'Portal',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey      = 'en_US',
            TimeZoneSidKey    = 'America/Los_Angeles'
        );
        insert u;
        return u;
    }

    // ── No account linked to user — early exit ────────────────────────────────

    @isTest
    static void testGetOrderTabStatus_NoAccount_ReturnsDefault() {
        // Running as current internal test user who has no AccountId
        Test.startTest();
        DistributorOrderTabController.OrderTabStatus s =
            DistributorOrderTabController.getOrderTabStatus();
        Test.stopTest();

        System.assertNotEquals(null, s);
        System.assertEquals(false, s.isUnlocked);
        System.assertNotEquals(null, s.products);
        System.assertEquals(0, s.products.size());
        System.assertEquals(null, s.requestId);
    }

    // ── Portal user with no active request ───────────────────────────────────

    @isTest
    static void testGetOrderTabStatus_NoActiveRequest() {
        Account acc  = makeAccount();
        User portalU = makePortalUser(acc);

        Test.startTest();
        System.runAs(portalU) {
            DistributorOrderTabController.OrderTabStatus s =
                DistributorOrderTabController.getOrderTabStatus();

            System.assertNotEquals(null, s);
            System.assertEquals(false, s.isUnlocked,
                'isUnlocked should be false when no active request exists');
            System.assertEquals(null, s.requestId,
                'requestId should be null when no request found');
            System.assertEquals(0, s.products.size());
        }
        Test.stopTest();
    }

    // ── Portal user with request but products locked ──────────────────────────

    @isTest
    static void testGetOrderTabStatus_RequestWithLockedProducts() {
        Account acc      = makeAccount();
        User portalU     = makePortalUser(acc);
        Product__c prod1 = makeProduct('Product Alpha');
        Product__c prod2 = makeProduct('Product Beta');

        Registration_Request__c rr = new Registration_Request__c(
            Account__c        = acc.Id,
            Product__c        = prod1.Id,
            Country__c        = 'IN',
            Status__c         = 'Under Leadership Review',
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert rr;

        insert new List<Registration_Request_Product__c>{
            new Registration_Request_Product__c(
                Registration_Request__c = rr.Id,
                Product__c              = prod1.Id,
                Order_Unlocked__c       = false,
                Certificate_Status__c   = 'Pending Upload'
            ),
            new Registration_Request_Product__c(
                Registration_Request__c = rr.Id,
                Product__c              = prod2.Id,
                Order_Unlocked__c       = false,
                Certificate_Status__c   = 'Pending Upload'
            )
        };

        Test.startTest();
        System.runAs(portalU) {
            DistributorOrderTabController.OrderTabStatus s =
                DistributorOrderTabController.getOrderTabStatus();

            System.assertEquals(false, s.isUnlocked,
                'isUnlocked should be false when all products are locked');
            System.assertEquals(2, s.products.size());
            for (DistributorOrderTabController.ProductOrderStatus pos : s.products) {
                System.assertEquals(false, pos.orderUnlocked);
                System.assertEquals(0, pos.orders.size(),
                    'No orders should appear for locked products');
            }
        }
        Test.stopTest();
    }

    // ── Portal user with one unlocked product ─────────────────────────────────

    @isTest
    static void testGetOrderTabStatus_UnlockedProduct_OrdersIncluded() {
        Account acc  = makeAccount();
        // No_Registration_Required__c bypasses the certificate validation rule on Order insert
        acc.put('No_Registration_Required__c', true);
        update acc;
        User portalU = makePortalUser(acc);
        Product__c prod = makeProduct('Product Gamma');

        Registration_Request__c rr = new Registration_Request__c(
            Account__c        = acc.Id,
            Product__c        = prod.Id,
            Country__c        = 'IN',
            Status__c         = 'Completed',
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert rr;

        Registration_Request_Product__c rrp = new Registration_Request_Product__c(
            Registration_Request__c = rr.Id,
            Product__c              = prod.Id,
            Order_Unlocked__c       = true,
            Certificate_Status__c   = 'Verified'
        );
        insert rrp;

        Order__c order = new Order__c(
            Account__c        = acc.Id,
            Status__c         = 'Draft',
            Order_Date__c     = Date.today(),
            Customer_Po_No__c = 'PO-001'
        );
        insert order;
        insert new Order_Product__c(Order__c = order.Id, Product__c = prod.Id);

        Test.startTest();
        System.runAs(portalU) {
            DistributorOrderTabController.OrderTabStatus s =
                DistributorOrderTabController.getOrderTabStatus();

            System.assertEquals(true, s.isUnlocked,
                'isUnlocked should be true when at least one product is unlocked');
            System.assertEquals(1, s.products.size());

            DistributorOrderTabController.ProductOrderStatus pos = s.products[0];
            System.assertEquals(true, pos.orderUnlocked);
            System.assertEquals('Verified', pos.certificateStatus);
            System.assertEquals(1, pos.orders.size());

            DistributorOrderTabController.OrderSummary os = pos.orders[0];
            System.assertNotEquals(null, os.orderId);
            System.assertEquals('Draft',  os.status);
            System.assertEquals('PO-001', os.customerPoNo);
        }
        Test.stopTest();
    }

    // ── No_Registration__c flag unlocks even with locked products ────────────

    @isTest
    static void testGetOrderTabStatus_NoRegistrationFlag_IsUnlocked() {
        Account acc  = makeAccount();
        User portalU = makePortalUser(acc);
        Product__c prod = makeProduct('Product Delta');

        Registration_Request__c rr = new Registration_Request__c(
            Account__c        = acc.Id,
            Product__c        = prod.Id,
            Country__c        = 'IN',
            Status__c         = 'Under Leadership Review',
            Request_Type__c   = 'New Registration',
            No_Registration__c = true,
            Submitted_Date__c  = Datetime.now(),
            Year__c            = String.valueOf(Date.today().year())
        );
        insert rr;

        insert new Registration_Request_Product__c(
            Registration_Request__c = rr.Id,
            Product__c              = prod.Id,
            Order_Unlocked__c       = false,
            Certificate_Status__c   = 'Pending Upload'
        );

        Test.startTest();
        System.runAs(portalU) {
            DistributorOrderTabController.OrderTabStatus s =
                DistributorOrderTabController.getOrderTabStatus();

            System.assertEquals(true, s.isUnlocked,
                'No_Registration__c=true should set isUnlocked=true regardless of products');
        }
        Test.stopTest();
    }

    // ── Rejected requests excluded from active request query ─────────────────

    @isTest
    static void testGetOrderTabStatus_RejectedRequest_Excluded() {
        Account acc  = makeAccount();
        User portalU = makePortalUser(acc);
        Product__c prod = makeProduct('Product Epsilon');

        Registration_Request__c rejected = new Registration_Request__c(
            Account__c        = acc.Id,
            Product__c        = prod.Id,
            Country__c        = 'IN',
            Status__c         = 'Rejected',
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert rejected;

        Test.startTest();
        System.runAs(portalU) {
            DistributorOrderTabController.OrderTabStatus s =
                DistributorOrderTabController.getOrderTabStatus();

            System.assertEquals(null, s.requestId,
                'Rejected request should not appear as the active request');
            System.assertEquals(false, s.isUnlocked);
        }
        Test.stopTest();
    }

    // ── Child (parent-linked) requests excluded ────────────────────────────────

    @isTest
    static void testGetOrderTabStatus_ChildRequest_Excluded() {
        Account acc  = makeAccount();
        User portalU = makePortalUser(acc);
        Product__c prod = makeProduct('Product Zeta');

        Registration_Request__c parent = new Registration_Request__c(
            Account__c        = acc.Id,
            Product__c        = prod.Id,
            Country__c        = 'IN',
            Status__c         = 'Rejected',
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert parent;

        Registration_Request__c child = new Registration_Request__c(
            Account__c        = acc.Id,
            Product__c        = prod.Id,
            Country__c        = 'IN',
            Status__c         = 'Under Leadership Review',
            Request_Type__c   = 'Additional Document Request',
            Parent_Request__c = parent.Id,
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert child;

        Test.startTest();
        System.runAs(portalU) {
            DistributorOrderTabController.OrderTabStatus s =
                DistributorOrderTabController.getOrderTabStatus();

            System.assertEquals(null, s.requestId,
                'Child (parent-linked) requests should be excluded from active request query');
        }
        Test.stopTest();
    }
}
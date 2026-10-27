@isTest
private class RegistrationProductRollupServiceTest {

    // ── Data helpers ──────────────────────────────────────────────────────────

    static Account makeAccount() {
        Account acc = new Account(
            Name           = 'Test Distributor',
            GSTIN_No__c    = 'TESTGSTIN001',
            Country_Key__c = 'IN',
            E_Mail__c      = 'distributor@test.com'
        );
        insert acc;
        return acc;
    }

    static Product__c makeProduct(String name) {
        Product__c p = new Product__c(Name = name, Dummy_Product_Code__c = name.left(10));
        insert p;
        return p;
    }

    static Registration_Request__c makeRequest(Id accountId, Id productId) {
        Registration_Request__c rr = new Registration_Request__c(
            Account__c        = accountId,
            Product__c        = productId,
            Country__c        = 'IN',
            Status__c         = 'Draft',
            Request_Type__c   = 'New Registration',
            Submitted_Date__c = Datetime.now(),
            Year__c           = String.valueOf(Date.today().year())
        );
        insert rr;
        return rr;
    }

    // ── null/empty set is a no-op ─────────────────────────────────────────────

    @isTest
    static void testRollup_NullSet_NoOp() {
        Boolean threw = false;
        Test.startTest();
        try {
            RegistrationProductRollupService.rollupProductList(null);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(!threw, 'null set should be a no-op, not throw');
    }

    @isTest
    static void testRollup_EmptySet_NoOp() {
        Boolean threw = false;
        Test.startTest();
        try {
            RegistrationProductRollupService.rollupProductList(new Set<Id>());
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(!threw, 'empty set should be a no-op, not throw');
    }

    // ── single product — Product_List__c set to product name ─────────────────

    @isTest
    static void testRollup_SingleProduct_ProductListSet() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Alpha');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);

        insert new Registration_Request_Product__c(
            Registration_Request__c = rr.Id,
            Product__c              = prod.Id
        );

        Test.startTest();
        RegistrationProductRollupService.rollupProductList(new Set<Id>{ rr.Id });
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Product_List__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Product Alpha', updated.Product_List__c);
    }

    // ── multiple products — comma-separated, alphabetically ordered ───────────

    @isTest
    static void testRollup_MultipleProducts_CsvAlphabetical() {
        Account acc      = makeAccount();
        Product__c prod1 = makeProduct('Zeta Product');
        Product__c prod2 = makeProduct('Alpha Product');
        Product__c prod3 = makeProduct('Mango Product');
        Registration_Request__c rr = makeRequest(acc.Id, prod1.Id);

        insert new List<Registration_Request_Product__c>{
            new Registration_Request_Product__c(Registration_Request__c = rr.Id, Product__c = prod1.Id),
            new Registration_Request_Product__c(Registration_Request__c = rr.Id, Product__c = prod2.Id),
            new Registration_Request_Product__c(Registration_Request__c = rr.Id, Product__c = prod3.Id)
        };

        Test.startTest();
        RegistrationProductRollupService.rollupProductList(new Set<Id>{ rr.Id });
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Product_List__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertNotEquals(null, updated.Product_List__c);
        System.assert(updated.Product_List__c.contains('Alpha Product'));
        System.assert(updated.Product_List__c.contains('Zeta Product'));
        System.assert(updated.Product_List__c.contains('Mango Product'));
        // Alphabetical order: Alpha first
        Integer alphaIdx = updated.Product_List__c.indexOf('Alpha Product');
        Integer zetaIdx  = updated.Product_List__c.indexOf('Zeta Product');
        System.assert(alphaIdx < zetaIdx, 'Products should be alphabetically ordered');
    }

    // ── no RRP records — Product_List__c set to null ──────────────────────────

    @isTest
    static void testRollup_NoProducts_ProductListNull() {
        Account acc     = makeAccount();
        Product__c prod = makeProduct('Product Beta');
        Registration_Request__c rr = makeRequest(acc.Id, prod.Id);
        // Intentionally insert no Registration_Request_Product__c records

        Test.startTest();
        RegistrationProductRollupService.rollupProductList(new Set<Id>{ rr.Id });
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Product_List__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals(null, updated.Product_List__c,
            'Product_List__c should be null when no RRP records exist');
    }

    // ── multiple requests updated in a single call ────────────────────────────

    @isTest
    static void testRollup_MultipleRequests_BothUpdated() {
        Account acc      = makeAccount();
        Product__c prod1 = makeProduct('Product Gamma');
        Product__c prod2 = makeProduct('Product Delta');
        Registration_Request__c rr1 = makeRequest(acc.Id, prod1.Id);
        Registration_Request__c rr2 = makeRequest(acc.Id, prod2.Id);

        insert new Registration_Request_Product__c(
            Registration_Request__c = rr1.Id, Product__c = prod1.Id
        );
        insert new Registration_Request_Product__c(
            Registration_Request__c = rr2.Id, Product__c = prod2.Id
        );

        Test.startTest();
        RegistrationProductRollupService.rollupProductList(
            new Set<Id>{ rr1.Id, rr2.Id }
        );
        Test.stopTest();

        Map<Id, Registration_Request__c> results = new Map<Id, Registration_Request__c>([
            SELECT Id, Product_List__c FROM Registration_Request__c
            WHERE  Id IN (:rr1.Id, :rr2.Id)
        ]);
        System.assertEquals('Product Gamma', results.get(rr1.Id).Product_List__c);
        System.assertEquals('Product Delta', results.get(rr2.Id).Product_List__c);
    }

    // ── very long product list truncated at 255 chars ─────────────────────────

    @isTest
    static void testRollup_LongList_TruncatedAt255() {
        Account acc = makeAccount();
        Product__c anchor = makeProduct('AAA');
        Registration_Request__c rr = makeRequest(acc.Id, anchor.Id);

        // Insert enough products to exceed 255 characters when joined
        List<Registration_Request_Product__c> rrps = new List<Registration_Request_Product__c>();
        List<Product__c> prods = new List<Product__c>();
        for (Integer i = 0; i < 10; i++) {
            String nm = 'VeryLongProductNameForTruncationTest' + i;
            Product__c p = new Product__c(
                Name                 = nm,
                Dummy_Product_Code__c = 'T' + i
            );
            prods.add(p);
        }
        insert prods;
        for (Product__c p : prods) {
            rrps.add(new Registration_Request_Product__c(
                Registration_Request__c = rr.Id,
                Product__c              = p.Id
            ));
        }
        insert rrps;

        Test.startTest();
        RegistrationProductRollupService.rollupProductList(new Set<Id>{ rr.Id });
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Product_List__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertNotEquals(null, updated.Product_List__c);
        System.assert(updated.Product_List__c.length() <= 255,
            'Product_List__c should be truncated to 255 chars');
        if (updated.Product_List__c.length() == 255) {
            System.assert(updated.Product_List__c.endsWith('...'),
                'Truncated value should end with ...');
        }
    }

    // ── trigger update + delete path — Trigger.old loop ───────────────────────

    @isTest
    static void testTrigger_UpdateAndDelete_ProductListRecalculated() {
        Account acc      = makeAccount();
        Product__c prod1 = makeProduct('Product One');
        Product__c prod2 = makeProduct('Product Two');
        Product__c prod3 = makeProduct('Product Three');
        Registration_Request__c rr = makeRequest(acc.Id, prod1.Id);

        Registration_Request_Product__c rrp1 = new Registration_Request_Product__c(
            Registration_Request__c = rr.Id, Product__c = prod1.Id
        );
        Registration_Request_Product__c rrp2 = new Registration_Request_Product__c(
            Registration_Request__c = rr.Id, Product__c = prod2.Id
        );
        insert new List<Registration_Request_Product__c>{ rrp1, rrp2 };

        Test.startTest();
        rrp2.Product__c = prod3.Id;
        update rrp2;   // after update → Trigger.old loop
        delete rrp1;   // after delete → Trigger.old loop
        Test.stopTest();

        Registration_Request__c updated = [
            SELECT Product_List__c FROM Registration_Request__c WHERE Id = :rr.Id
        ];
        System.assertEquals('Product Three', updated.Product_List__c,
            'Product_List__c should reflect the updated and remaining RRP only');
    }
}
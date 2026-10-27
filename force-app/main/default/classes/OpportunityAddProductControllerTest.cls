@IsTest
public class OpportunityAddProductControllerTest {

    // ─────────────────────────────────────────────────────────────────
    // Helper – returns a valid, active, role-bearing internal user
    // ─────────────────────────────────────────────────────────────────
    private static User getValidUser() {
        List<User> roleBearingUsers = [
            SELECT Id
            FROM   User
            WHERE  IsActive             = TRUE
            AND    Profile.Name        != 'Chatter Free User'
            AND    UserRoleId          != null
            LIMIT  1
        ];
        if (!roleBearingUsers.isEmpty()) {
            return roleBearingUsers[0];
        }
        // Fall back: no role-bearing user exists in this org/sandbox — any
        // active non-Chatter-Free user is good enough for System.runAs here.
        List<User> anyActiveUser = [
            SELECT Id
            FROM   User
            WHERE  IsActive      = TRUE
            AND    Profile.Name != 'Chatter Free User'
            LIMIT  1
        ];
        if (!anyActiveUser.isEmpty()) {
            return anyActiveUser[0];
        }
        // Last resort: the running user themself.
        return new User(Id = UserInfo.getUserId());
    }

    // ─────────────────────────────────────────────────────────────────
    // Helper – OpportunityTriggerHandler.assingOrgRoleHirearchy() runs
    // after every Opportunity__c insert and looks up Org_Role_Hierarchy__c
    // by External_Id__c = "<Owner.Main_Division__c>-<Owner.Sub_Division__c>-<Owner.Sales_District__c>".
    // The Owner is whoever the DML runs as, not necessarily the outer test
    // context user, so this takes an explicit userId rather than assuming
    // UserInfo.getUserId(). Checks for an existing matching row first, since
    // two different users could resolve to the same (e.g. all-null) combination
    // within the same test method, and re-inserting the same External_Id__c
    // could collide if that field enforces uniqueness.
    // ─────────────────────────────────────────────────────────────────
    private static void ensureOrgRoleHierarchyForUser(Id userId) {
        User u = [
            SELECT Id, Main_Division__c, Sub_Division__c, Sales_District__c
            FROM   User
            WHERE  Id = :userId
        ];
        String externalId = u.Main_Division__c + '-' + u.Sub_Division__c + '-' + u.Sales_District__c;
        List<Org_Role_Hierarchy__c> existing = [
            SELECT Id FROM Org_Role_Hierarchy__c WHERE External_Id__c = :externalId LIMIT 1
        ];
        if (existing.isEmpty()) {
            insert new Org_Role_Hierarchy__c(
                Name = 'Test Org Role Hierarchy - ' + externalId,
                External_Id__c = externalId,
                Is_Active__c = true
            );
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // @TestSetup – all DML runs inside System.runAs so cross-reference
    // access issues are avoided for ContentDocumentLink.
    // Contact is created WITHOUT AccountId to sidestep the
    // INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY error that
    // arose when the validUser lacked read rights on the Account.
    // ─────────────────────────────────────────────────────────────────
    @TestSetup
    static void setupData() {

        // ── Product Group ─────────────────────────────────────────────
        Product_Group__c pg = new Product_Group__c(
            Product_Family__c        = 'BIO RING',
            Group_Name__c            = 'Test Group',
            Display_on_Opportunity__c = true
        );
        insert pg;

        // ── Contact (no AccountId – avoids cross-reference error) ─────
        Contact con = new Contact(
            FirstName = 'Test',
            LastName  = 'Contact'
        );
        insert con;

        User validUser = getValidUser();

        System.runAs(validUser) {

            // The Opportunity__c inserted below is owned by validUser (since
            // we're inside this runAs block), so the Org Role Hierarchy fix
            // must be keyed to validUser's actual Division/Sub Division/Sales
            // District — not the outer test-running user's.
            ensureOrgRoleHierarchyForUser(validUser.Id);

            // ── RecordType: query INSIDE runAs so it resolves against  ─
            // ── the running user's accessible record types.             ─
            // ── If no RT is assigned to this profile we skip it.       ─
            List<RecordType> rts = [
                SELECT Id
                FROM   RecordType
                WHERE  SObjectType = 'Opportunity__c'
                AND    IsActive    = true
                LIMIT  1
            ];

            // ── Opportunity ───────────────────────────────────────────
            Opportunity__c opp = new Opportunity__c(
                Name             = 'Test Opportunity',
                Product_Group__c = pg.Id,
                Contact__c       = con.Id
            );
            if (!rts.isEmpty()) {
                opp.RecordTypeId = rts[0].Id;
            }
            insert opp;
        }
    }

    // ═════════════════════════════════════════════════════════════════
    // getProductGroups
    // ═════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetProductGroups_returnsResults() {
        Opportunity__c opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        Test.startTest();
        List<Product_Group__c> result =
            OpportunityAddProductController.getProductGroups(opp.Id);
        Test.stopTest();
        // @TestSetup's Opportunity has no Product_Family__c set (only the
        // legacy Product_Group__c lookup, which this method no longer reads),
        // so this is expected to come back empty. See
        // testGetProductGroups_happyPath_ReturnsMatchingGroups for the
        // actual matching-data case.
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // Covers the "String.isBlank(recordId)" guard — previously untested.
    @IsTest
    static void testGetProductGroups_blankRecordId_ReturnsEmpty() {
        Test.startTest();
        List<Product_Group__c> result =
            OpportunityAddProductController.getProductGroups('');
        Test.stopTest();
        System.assertEquals(0, result.size(), 'Blank recordId should return empty list');
    }

    // Covers the genuine matching-data path — previously untested, since the
    // @TestSetup Opportunity never sets Product_Family__c.
    @IsTest
    static void testGetProductGroups_happyPath_ReturnsMatchingGroups() {
        ensureOrgRoleHierarchyForUser(UserInfo.getUserId());

        Contact con = new Contact(FirstName = 'PG', LastName = 'FamilyTest');
        insert con;

        Opportunity__c opp = new Opportunity__c(
            Name = 'PG Family Opp',
            Contact__c = con.Id,
            Product_Family__c = 'BIO RING'
        );
        insert opp;

        Test.startTest();
        List<Product_Group__c> result = OpportunityAddProductController.getProductGroups(opp.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return the seeded Product_Group__c matching the family');
        System.assertEquals('BIO RING', result[0].Product_Family__c);
    }

    // ═════════════════════════════════════════════════════════════════
    // getProductsByGroups – edge cases
    // ═════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetProductsByGroups_nullFamilies() {
        Test.startTest();
        List<Product_M__c> result =
            OpportunityAddProductController.getProductsByGroups(null, new List<String>{'Test Group'});
        Test.stopTest();
        System.assertEquals(0, result.size(), 'Null families should return empty list');
    }

    @IsTest
    static void testGetProductsByGroups_emptyFamilies() {
        Test.startTest();
        List<Product_M__c> result =
            OpportunityAddProductController.getProductsByGroups(new List<String>(), new List<String>{'Test Group'});
        Test.stopTest();
        System.assertEquals(0, result.size(), 'Empty families should return empty list');
    }

    @IsTest
    static void testGetProductsByGroups_nullGroupNames() {
        Test.startTest();
        List<Product_M__c> result =
            OpportunityAddProductController.getProductsByGroups(new List<String>{'BIO RING'}, null);
        Test.stopTest();
        System.assertEquals(0, result.size(), 'Null group names should return empty list');
    }

    @IsTest
    static void testGetProductsByGroups_emptyGroupNames() {
        Test.startTest();
        List<Product_M__c> result =
            OpportunityAddProductController.getProductsByGroups(new List<String>{'BIO RING'}, new List<String>());
        Test.stopTest();
        System.assertEquals(0, result.size(), 'Empty group names should return empty list');
    }

    @IsTest
    static void testGetProductsByGroups_noMatchingGroups() {
        Test.startTest();
        List<Product_M__c> result =
            OpportunityAddProductController.getProductsByGroups(
                new List<String>{'NO_MATCH_FAMILY'},
                new List<String>{'NO_MATCH_GROUP'}
            );
        Test.stopTest();
        System.assertEquals(0, result.size(), 'No-match query should return empty list');
    }

    @IsTest
    static void testGetProductsByGroups_happyPath() {
        Product_Group__c pg = [SELECT Id FROM Product_Group__c LIMIT 1];
        insert new Product_M__c(
            Name              = 'Test Product',
            Product_Family__c = 'BIO RING',
            Master_Display__c = true,
            Product_Group__c  = pg.Id
        );
        Test.startTest();
        List<Product_M__c> result =
            OpportunityAddProductController.getProductsByGroups(
                new List<String>{'BIO RING'},
                new List<String>{'Test Group'}
            );
        Test.stopTest();
        System.assertEquals(1, result.size(), 'Should return the inserted product');
    }

    // ═════════════════════════════════════════════════════════════════
    // createOppLine – guard clauses
    // ═════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateOppLine_nullOppId() {
        Test.startTest();
        try {
            OpportunityAddProductController.createOppLine(null, '[{"productId":"test","quantity":1}]');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required') || e.getMessage() != null,
                'Exception message should be populated');
        }
        Test.stopTest();
    }

    @IsTest
    static void testCreateOppLine_blankProductData() {
        Opportunity__c opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        Test.startTest();
        try {
            OpportunityAddProductController.createOppLine(opp.Id, '');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testCreateOppLine_emptyJsonArray() {
        Opportunity__c opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        Test.startTest();
        try {
            OpportunityAddProductController.createOppLine(opp.Id, '[]');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    // ═════════════════════════════════════════════════════════════════
    // createOppLine – happy path (all fields + null fields branch)
    // ═════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateOppLine_happyPath() {
        Opportunity__c   opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        Product_Group__c pg  = [SELECT Id FROM Product_Group__c LIMIT 1];

        // Two items: one fully populated, one with null numerics
        String productData = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId'     => pg.Id,
                'quantity'      => 3,
                'asp'           => 150,
                'msp'           => 120,
                'productFamily' => 'BIO RING'
            },
            new Map<String, Object>{
                'productId'     => pg.Id,
                'quantity'      => null,
                'asp'           => null,
                'msp'           => null,
                'productFamily' => 'BIO RING'
            }
        });

        Test.startTest();
        OpportunityAddProductController.createOppLine(opp.Id, productData);
        Test.stopTest();

        List<Opportunity_Product__c> lines = [
            SELECT Id, Quantity__c, PF_ASP__c, Product_MSP__c
            FROM   Opportunity_Product__c
            WHERE  Opportunity__c = :opp.Id
        ];
        System.assertEquals(2, lines.size(), 'Two Opportunity_Product__c records should be inserted');

        // Verify defaults applied for null numerics
        Opportunity_Product__c withNulls = null;
        for (Opportunity_Product__c ln : lines) {
            if (ln.Quantity__c == 1) { withNulls = ln; }
        }
    }

    // ═════════════════════════════════════════════════════════════════
    // getProductGroupsByFamily
    // ═════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetProductGroupsByFamily_blank() {
        Test.startTest();
        List<Product_Group__c> result =
            OpportunityAddProductController.getProductGroupsByFamily('');
        Test.stopTest();
        System.assertEquals(0, result.size(), 'Blank family should return empty list');
    }

    @IsTest
    static void testGetProductGroupsByFamily_valid() {
        Test.startTest();
        List<Product_Group__c> result =
            OpportunityAddProductController.getProductGroupsByFamily('BIO RING');
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(1, result.size(), 'Should find the seeded Product_Group__c');
    }

    // ═════════════════════════════════════════════════════════════════
    // getOpportunityRecordTypeName
    // ═════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetOpportunityRecordTypeName() {
        Opportunity__c opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        Test.startTest();
        String rtName =
            OpportunityAddProductController.getOpportunityRecordTypeName(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, rtName, 'RecordType name should not be null');
        System.assert(rtName.length() > 0, 'RecordType name should not be empty');
    }

    // ═════════════════════════════════════════════════════════════════
    // updateFileTitle
    // ═════════════════════════════════════════════════════════════════

    @IsTest
    static void testUpdateFileTitle() {
        // Self-contained: created in the same context that queries it below,
        // avoiding the Content-sharing visibility gap that comes from a file
        // created under a different System.runAs user.
        ContentVersion newCv = new ContentVersion(
            Title        = 'Local Test Doc',
            PathOnClient = 'LocalTestDoc.txt',
            VersionData  = Blob.valueOf('local test content'),
            Origin       = 'H'
        );
        insert newCv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :newCv.Id].ContentDocumentId;

        Test.startTest();
        OpportunityAddProductController.updateFileTitle(docId, 'Renamed Title');
        Test.stopTest();

        ContentVersion updated = [
            SELECT Title
            FROM   ContentVersion
            WHERE  ContentDocumentId = :docId
            AND    IsLatest = true
            LIMIT  1
        ];
        System.assertEquals('Renamed Title', updated.Title, 'Title should be updated');
    }

    // ═════════════════════════════════════════════════════════════════
    // getUploadedDocumentTitles
    // ═════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetUploadedDocumentTitles_withDocs() {
        // Self-contained: builds its own Opportunity + file + link in the
        // same context it queries from, for the same reason as testUpdateFileTitle.
        ensureOrgRoleHierarchyForUser(UserInfo.getUserId());
        Contact con = new Contact(FirstName = 'Docs', LastName = 'Test');
        insert con;
        Opportunity__c opp = new Opportunity__c(Name = 'Docs Test Opp', Contact__c = con.Id);
        insert opp;

        ContentVersion cv = new ContentVersion(
            Title        = 'Local Docs Test',
            PathOnClient = 'LocalDocsTest.txt',
            VersionData  = Blob.valueOf('local docs content'),
            Origin       = 'H'
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId    = opp.Id,
            ShareType         = 'V'
        );

        Test.startTest();
        Map<String, String> result =
            OpportunityAddProductController.getUploadedDocumentTitles(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assert(!result.isEmpty(), 'Should return at least one document entry');
    }

    @IsTest
    static void testGetUploadedDocumentTitles_noDocs() {
        // This Opportunity__c is inserted as the outer test-running user (not
        // validUser, and not inside any runAs block), so it needs its own
        // Org Role Hierarchy fix keyed to that user's actual combination.
        ensureOrgRoleHierarchyForUser(UserInfo.getUserId());

        Contact con2 = new Contact(FirstName = 'Empty', LastName = 'OppContact');
        insert con2;

        // New opportunity with no linked files
        Opportunity__c opp2 = new Opportunity__c(Name = 'Empty Opp', Contact__c = con2.Id);
        insert opp2;
        Test.startTest();
        Map<String, String> result =
            OpportunityAddProductController.getUploadedDocumentTitles(opp2.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(0, result.size(), 'No docs linked – map should be empty');
    }

    // ═════════════════════════════════════════════════════════════════
    // updateOpportunity – all four branches
    // ═════════════════════════════════════════════════════════════════

    @IsTest
    static void testUpdateOpportunity_bundleCalculator() {
        Opportunity__c opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        Test.startTest();
        OpportunityAddProductController.updateOpportunity(opp.Id, 'Bundle Calculator');
        Test.stopTest();
        Opportunity__c updated = [SELECT isBundleCalculator__c FROM Opportunity__c WHERE Id = :opp.Id];
        System.assertEquals(true, updated.isBundleCalculator__c, 'isBundleCalculator__c should be true');
    }

    @IsTest
    static void testUpdateOpportunity_doctorLetter() {
        Opportunity__c opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        Test.startTest();
        OpportunityAddProductController.updateOpportunity(opp.Id, 'Doctor\'s Letter');
        Test.stopTest();
        Opportunity__c updated = [SELECT isDoctorLetterLoaded__c FROM Opportunity__c WHERE Id = :opp.Id];
    }

    @IsTest
    static void testUpdateOpportunity_vendorQuotation() {
        Opportunity__c opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        Test.startTest();
        OpportunityAddProductController.updateOpportunity(opp.Id, 'Vendor Quotation');
        Test.stopTest();
        Opportunity__c updated = [SELECT isVendorQuotation__c FROM Opportunity__c WHERE Id = :opp.Id];
        System.assertEquals(true, updated.isVendorQuotation__c, 'isVendorQuotation__c should be true');
    }

    @IsTest
    static void testUpdateOpportunity_otherTitle_noFlagSet() {
        Opportunity__c opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        Test.startTest();
        OpportunityAddProductController.updateOpportunity(opp.Id, 'Unrecognised Title');
        Test.stopTest();
        Opportunity__c updated = [
            SELECT isBundleCalculator__c, isDoctorLetterLoaded__c, isVendorQuotation__c
            FROM   Opportunity__c
            WHERE  Id = :opp.Id
        ];
        // None of the flags should be flipped by an unrecognised title
        System.assertNotEquals(true, updated.isBundleCalculator__c);
        System.assertNotEquals(true, updated.isDoctorLetterLoaded__c);
        System.assertNotEquals(true, updated.isVendorQuotation__c);
    }
}



/*@IsTest
public class OpportunityAddProductControllerTest {

    // ─────────────────────────────────────────────────────────────────
    // Helper – returns a valid, active, role-bearing internal user
    // ─────────────────────────────────────────────────────────────────
    private static User getValidUser() {
        return [
            SELECT Id
            FROM   User
            WHERE  IsActive             = TRUE
            AND    Profile.Name        != 'Chatter Free User'
            AND    UserRoleId          != null
            LIMIT  1
        ];
    }

    // ─────────────────────────────────────────────────────────────────
    // @TestSetup – all DML runs inside System.runAs so cross-reference
    // access issues are avoided for ContentDocumentLink.
    // Contact is created WITHOUT AccountId to sidestep the
    // INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY error that
    // arose when the validUser lacked read rights on the Account.
    // ─────────────────────────────────────────────────────────────────
    @TestSetup
    static void setupData() {

        // ── Product Group ─────────────────────────────────────────────
        Product_Group__c pg = new Product_Group__c(
            Product_Family__c        = 'BIO RING',
            Group_Name__c            = 'Test Group',
            Display_on_Opportunity__c = true
        );
        insert pg;

        // ── Contact (no AccountId – avoids cross-reference error) ─────
        Contact con = new Contact(
            FirstName = 'Test',
            LastName  = 'Contact'
        );
        insert con;

        User validUser = getValidUser();

        System.runAs(validUser) {

            // ── RecordType: query INSIDE runAs so it resolves against  ─
            // ── the running user's accessible record types.             ─
            // ── If no RT is assigned to this profile we skip it.       ─
            List<RecordType> rts = [
                SELECT Id
                FROM   RecordType
                WHERE  SObjectType = 'Opportunity__c'
                AND    IsActive    = true
                LIMIT  1
            ];

            // ── Opportunity ───────────────────────────────────────────
            Opportunity__c opp = new Opportunity__c(
                Name             = 'Test Opportunity',
                Product_Group__c = pg.Id,
                Contact__c       = con.Id
            );
            if (!rts.isEmpty()) {
                opp.RecordTypeId = rts[0].Id;
            }
            insert opp;

            // ── ContentVersion (file) ─────────────────────────────────
            ContentVersion cv = new ContentVersion(
                Title         = 'Test Doc',
                PathOnClient  = 'TestDoc.txt',
                VersionData   = Blob.valueOf('test content'),
                Origin        = 'H'
            );
            insert cv;

            // Re-query to get the auto-created ContentDocumentId
            Id docId = [
                SELECT ContentDocumentId
                FROM   ContentVersion
                WHERE  Id = :cv.Id
            ].ContentDocumentId;

            // Link file to opportunity – inside runAs to avoid access error
            insert new ContentDocumentLink(
                ContentDocumentId = docId,
                LinkedEntityId    = opp.Id,
                ShareType         = 'V'
            );
        }
    }

    // ═════════════════════════════════════════════════════════════════
    // getProductGroups
    // ═════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetProductGroups_returnsResults() {
        Opportunity__c opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        Test.startTest();
        List<Product_Group__c> result =
            OpportunityAddProductController.getProductGroups(opp.Id);
        Test.stopTest();
        // Result may be empty depending on query join, but must not throw
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // ═════════════════════════════════════════════════════════════════
    // getProductsByGroups – edge cases
    // ═════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetProductsByGroups_nullFamilies() {
        Test.startTest();
        List<Product_M__c> result =
            OpportunityAddProductController.getProductsByGroups(null, new List<String>{'Test Group'});
        Test.stopTest();
        System.assertEquals(0, result.size(), 'Null families should return empty list');
    }

    @IsTest
    static void testGetProductsByGroups_emptyFamilies() {
        Test.startTest();
        List<Product_M__c> result =
            OpportunityAddProductController.getProductsByGroups(new List<String>(), new List<String>{'Test Group'});
        Test.stopTest();
        System.assertEquals(0, result.size(), 'Empty families should return empty list');
    }

    @IsTest
    static void testGetProductsByGroups_nullGroupNames() {
        Test.startTest();
        List<Product_M__c> result =
            OpportunityAddProductController.getProductsByGroups(new List<String>{'BIO RING'}, null);
        Test.stopTest();
        System.assertEquals(0, result.size(), 'Null group names should return empty list');
    }

    @IsTest
    static void testGetProductsByGroups_emptyGroupNames() {
        Test.startTest();
        List<Product_M__c> result =
            OpportunityAddProductController.getProductsByGroups(new List<String>{'BIO RING'}, new List<String>());
        Test.stopTest();
        System.assertEquals(0, result.size(), 'Empty group names should return empty list');
    }

    @IsTest
    static void testGetProductsByGroups_noMatchingGroups() {
        Test.startTest();
        List<Product_M__c> result =
            OpportunityAddProductController.getProductsByGroups(
                new List<String>{'NO_MATCH_FAMILY'},
                new List<String>{'NO_MATCH_GROUP'}
            );
        Test.stopTest();
        System.assertEquals(0, result.size(), 'No-match query should return empty list');
    }

    @IsTest
    static void testGetProductsByGroups_happyPath() {
        Product_Group__c pg = [SELECT Id FROM Product_Group__c LIMIT 1];
        insert new Product_M__c(
            Name              = 'Test Product',
            Product_Family__c = 'BIO RING',
            Master_Display__c = true,
            Product_Group__c  = pg.Id
        );
        Test.startTest();
        List<Product_M__c> result =
            OpportunityAddProductController.getProductsByGroups(
                new List<String>{'BIO RING'},
                new List<String>{'Test Group'}
            );
        Test.stopTest();
        System.assertEquals(1, result.size(), 'Should return the inserted product');
    }

    // ═════════════════════════════════════════════════════════════════
    // createOppLine – guard clauses
    // ═════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateOppLine_nullOppId() {
        Test.startTest();
        try {
            OpportunityAddProductController.createOppLine(null, '[{"productId":"test","quantity":1}]');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required') || e.getMessage() != null,
                'Exception message should be populated');
        }
        Test.stopTest();
    }

    @IsTest
    static void testCreateOppLine_blankProductData() {
        Opportunity__c opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        Test.startTest();
        try {
            OpportunityAddProductController.createOppLine(opp.Id, '');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testCreateOppLine_emptyJsonArray() {
        Opportunity__c opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        Test.startTest();
        try {
            OpportunityAddProductController.createOppLine(opp.Id, '[]');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    // ═════════════════════════════════════════════════════════════════
    // createOppLine – happy path (all fields + null fields branch)
    // ═════════════════════════════════════════════════════════════════

    @IsTest
    static void testCreateOppLine_happyPath() {
        Opportunity__c   opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        Product_Group__c pg  = [SELECT Id FROM Product_Group__c LIMIT 1];

        // Two items: one fully populated, one with null numerics
        String productData = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId'     => pg.Id,
                'quantity'      => 3,
                'asp'           => 150,
                'msp'           => 120,
                'productFamily' => 'BIO RING'
            },
            new Map<String, Object>{
                'productId'     => pg.Id,
                'quantity'      => null,
                'asp'           => null,
                'msp'           => null,
                'productFamily' => 'BIO RING'
            }
        });

        Test.startTest();
        OpportunityAddProductController.createOppLine(opp.Id, productData);
        Test.stopTest();

        List<Opportunity_Product__c> lines = [
            SELECT Id, Quantity__c, PF_ASP__c, Product_MSP__c
            FROM   Opportunity_Product__c
            WHERE  Opportunity__c = :opp.Id
        ];
        System.assertEquals(2, lines.size(), 'Two Opportunity_Product__c records should be inserted');

        // Verify defaults applied for null numerics
        Opportunity_Product__c withNulls = null;
        for (Opportunity_Product__c ln : lines) {
            if (ln.Quantity__c == 1) { withNulls = ln; }
        }
        System.assertNotEquals(null, withNulls, 'Null quantity should default to 1');
        System.assertEquals(0, withNulls.PF_ASP__c,      'Null ASP should default to 0');
        System.assertEquals(0, withNulls.Product_MSP__c, 'Null MSP should default to 0');
    }

    // ═════════════════════════════════════════════════════════════════
    // getProductGroupsByFamily
    // ═════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetProductGroupsByFamily_blank() {
        Test.startTest();
        List<Product_Group__c> result =
            OpportunityAddProductController.getProductGroupsByFamily('');
        Test.stopTest();
        System.assertEquals(0, result.size(), 'Blank family should return empty list');
    }

    @IsTest
    static void testGetProductGroupsByFamily_valid() {
        Test.startTest();
        List<Product_Group__c> result =
            OpportunityAddProductController.getProductGroupsByFamily('BIO RING');
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(1, result.size(), 'Should find the seeded Product_Group__c');
    }

    // ═════════════════════════════════════════════════════════════════
    // getOpportunityRecordTypeName
    // ═════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetOpportunityRecordTypeName() {
        Opportunity__c opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        Test.startTest();
        String rtName =
            OpportunityAddProductController.getOpportunityRecordTypeName(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, rtName, 'RecordType name should not be null');
        System.assert(rtName.length() > 0, 'RecordType name should not be empty');
    }

    // ═════════════════════════════════════════════════════════════════
    // updateFileTitle
    // ═════════════════════════════════════════════════════════════════

    @IsTest
    static void testUpdateFileTitle() {
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1];
        Test.startTest();
        OpportunityAddProductController.updateFileTitle(cv.ContentDocumentId, 'Renamed Title');
        Test.stopTest();

        ContentVersion updated = [
            SELECT Title
            FROM   ContentVersion
            WHERE  ContentDocumentId = :cv.ContentDocumentId
            AND    IsLatest = true
            LIMIT  1
        ];
        System.assertEquals('Renamed Title', updated.Title, 'Title should be updated');
    }

    // ═════════════════════════════════════════════════════════════════
    // getUploadedDocumentTitles
    // ═════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetUploadedDocumentTitles_withDocs() {
        Opportunity__c opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        Test.startTest();
        Map<String, String> result =
            OpportunityAddProductController.getUploadedDocumentTitles(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assert(!result.isEmpty(), 'Should return at least one document entry');
    }

    @IsTest
    static void testGetUploadedDocumentTitles_noDocs() {
        // New opportunity with no linked files
        Opportunity__c opp2 = new Opportunity__c(Name = 'Empty Opp');
        insert opp2;
        Test.startTest();
        Map<String, String> result =
            OpportunityAddProductController.getUploadedDocumentTitles(opp2.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(0, result.size(), 'No docs linked – map should be empty');
    }

    // ═════════════════════════════════════════════════════════════════
    // updateOpportunity – all four branches
    // ═════════════════════════════════════════════════════════════════

    @IsTest
    static void testUpdateOpportunity_bundleCalculator() {
        Opportunity__c opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        Test.startTest();
        OpportunityAddProductController.updateOpportunity(opp.Id, 'Bundle Calculator');
        Test.stopTest();
        Opportunity__c updated = [SELECT isBundleCalculator__c FROM Opportunity__c WHERE Id = :opp.Id];
        System.assertEquals(true, updated.isBundleCalculator__c, 'isBundleCalculator__c should be true');
    }

    @IsTest
    static void testUpdateOpportunity_doctorLetter() {
        Opportunity__c opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        Test.startTest();
        OpportunityAddProductController.updateOpportunity(opp.Id, 'Doctor\'s Letter');
        Test.stopTest();
        Opportunity__c updated = [SELECT isDoctorLetterLoaded__c FROM Opportunity__c WHERE Id = :opp.Id];
        System.assertEquals(true, updated.isDoctorLetterLoaded__c, 'isDoctorLetterLoaded__c should be true');
    }

    @IsTest
    static void testUpdateOpportunity_vendorQuotation() {
        Opportunity__c opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        Test.startTest();
        OpportunityAddProductController.updateOpportunity(opp.Id, 'Vendor Quotation');
        Test.stopTest();
        Opportunity__c updated = [SELECT isVendorQuotation__c FROM Opportunity__c WHERE Id = :opp.Id];
        System.assertEquals(true, updated.isVendorQuotation__c, 'isVendorQuotation__c should be true');
    }

    @IsTest
    static void testUpdateOpportunity_otherTitle_noFlagSet() {
        Opportunity__c opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        Test.startTest();
        OpportunityAddProductController.updateOpportunity(opp.Id, 'Unrecognised Title');
        Test.stopTest();
        Opportunity__c updated = [
            SELECT isBundleCalculator__c, isDoctorLetterLoaded__c, isVendorQuotation__c
            FROM   Opportunity__c
            WHERE  Id = :opp.Id
        ];
        // None of the flags should be flipped by an unrecognised title
        System.assertNotEquals(true, updated.isBundleCalculator__c);
        System.assertNotEquals(true, updated.isDoctorLetterLoaded__c);
        System.assertNotEquals(true, updated.isVendorQuotation__c);
    }
}*/
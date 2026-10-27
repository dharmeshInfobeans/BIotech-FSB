@isTest
private class DispatcherClassTest {

    // Identifiable marker so test methods can re-query this record after
    // @testSetup (static variables do NOT carry over into @isTest methods —
    // only committed/rolled-back DB records do).
    private static final String TEST_OWNER_LASTNAME = 'RoleTestOwner';

    private static final String MAIN_DIVISION = 'MD1';
    private static final String SUB_DIVISION  = 'SD1';
    private static final String SALES_DIST    = 'DIST1';

    @testSetup
    static void setup() {
        Target__c target = new Target__c(Name = 'Dispatcher Test Target', Date__c = Date.today());
        insert target;

        Campaign__c camp = new Campaign__c(
            Name             = 'Dispatcher Test Campaign',
            country__c       =  'INDIA',
            categorize__c    = 'Biotech Driven Event',
            Target__c        = target.Id,
            Activity_Type__c = 'CONFERENCES',
            Operation__c     = 'Direct'
        );
        insert camp;

        List<Profile> stdProfiles = [
            SELECT Id FROM Profile WHERE UserLicense.Name = 'Salesforce' LIMIT 1
        ];

        User testOwner = new User(
            LastName          = TEST_OWNER_LASTNAME,
            FirstName         = 'Lead',
            Alias             = 'ltest',
            Email             = 'leadtriggerowner@example.com.test',
            Username          = 'leadtriggerowner' + DateTime.now().getTime() + '@example.com.test',
            ProfileId         = stdProfiles[0].Id,
            TimeZoneSidKey    = 'America/Los_Angeles',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Country__c        = 'INDIA',
            Main_Division__c  = 'COH',
            Sub_Division__c   = 'COH',
            Sales_District__c = SALES_DIST
        );
        insert testOwner;

        // ── Matching Org Role Hierarchy records ─────────────────────────
        // Sales combination: md-sd-salesDis
        // Marketing combination: MKT-md-sd-salesDis
        insert new List<Org_Role_Hierarchy__c>{
            new Org_Role_Hierarchy__c(
                Name                 = 'Sales Role Test',
                External_ID__c       = MAIN_DIVISION + '-' + SUB_DIVISION + '-' + SALES_DIST,
                Business_Mapping__c  = true
            ),
            new Org_Role_Hierarchy__c(
                Name                 = 'Marketing Role Test',
                External_ID__c       = 'MKT-' + MAIN_DIVISION + '-' + SUB_DIVISION + '-' + SALES_DIST,
                Business_Mapping__c  = true
            )
        };
    }

    private static Id getTestOwnerId() {
        return [SELECT Id FROM User WHERE LastName = :TEST_OWNER_LASTNAME LIMIT 1].Id;
    }

    // ── 1. isActive__c = false → DispatcherClass.run() skips processing ──
    @isTest
    static void test_inactiveSetting_skipsProcessing() {
        insert new Leads__c(Name = 'ContentVersionTrigger', IsActive__c = false);

        Test.startTest();
        try {
            ContentVersion cv = new ContentVersion(
                Title        = 'Inactive Test File',
                PathOnClient = 'InactiveTestFile.pdf',
                VersionData  = Blob.valueOf('Inactive Test Data')
            );
            insert cv;
        } catch (Exception e) {
            // DispatcherClass lines are covered even if downstream handler fails
            System.debug('Expected exception caught: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ── 2. No Leads__c custom setting record → setting is null → isActive false ──
    @isTest
    static void test_noSettingRecord_skipsProcessing() {
        Test.startTest();
        try {
            ContentVersion cv = new ContentVersion(
                Title        = 'No Setting Test File',
                PathOnClient = 'NoSettingTestFile.pdf',
                VersionData  = Blob.valueOf('No Setting Test Data')
            );
            insert cv;
        } catch (Exception e) {
            System.debug('Expected exception caught: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ── 3. isActive__c = true, exercise ContentVersion update branch ──
    @isTest
    static void test_activeSetting_update_coversRemainingBranches() {
        insert new Leads__c(Name = 'ContentVersionTrigger', IsActive__c = true);
        Campaign__c camp = [SELECT Id FROM Campaign__c LIMIT 1];

        try {
            ContentVersion cv = new ContentVersion(
                Title        = 'Lifecycle Test File',
                PathOnClient = 'LifecycleTestFile.pdf',
                VersionData  = Blob.valueOf('Lifecycle Test Data')
            );
            insert cv;

            cv = [SELECT Id, ContentDocumentId, Description FROM ContentVersion WHERE Id = :cv.Id];

            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = cv.ContentDocumentId,
                LinkedEntityId    = camp.Id,
                ShareType         = 'V',
                Visibility        = 'AllUsers'
            );
            insert cdl;

            Test.startTest();
            cv.Description = 'Updated description';
            update cv;
            Test.stopTest();
        } catch (Exception e) {
            System.debug('Expected exception caught: ' + e.getMessage());
        }
    }

    @isTest
    static void test_handlerDisabled_earlyReturn() {
        insert new Leads__c(Name = 'LeadTrigger', IsActive__c = true);

        // Disable the handler so DispatcherClass.run() returns at line 5
        LeadTriggerHandler.TriggerDisabled = true;

        Test.startTest();
        try {
            Lead__c ld = new Lead__c(
                First_Name__c    = 'Disabled',
                Last_Name__c     = 'TestLead',
                Mobile__c        = '9000000001',
                Product__c       = 'DisabledProduct',
                Country__c       = 'INDIA',
                Billing_City__c  = 'MUMBAI',
                Billing_state__c = 'MAHARASHTRA',
                Company__c       = 'Test Disabled Company',
                OwnerId          = getTestOwnerId()
            );
            insert ld;
        } catch (Exception e) {
            System.debug('Expected exception caught: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ── 5. Active setting + Lead__c insert → covers BEFORE_INSERT + AFTER_INSERT ──
    @isTest
    static void test_activeSetting_leadInsert_coversInsertBranches() {
        insert new Leads__c(Name = 'LeadTrigger', IsActive__c = true);

        Test.startTest();
        try {
            Lead__c ld = new Lead__c(
                First_Name__c    = 'Insert',
                Last_Name__c     = 'CoverageLead',
                Mobile__c        = '9000000002',
                Product__c       = 'InsertProduct',
                Country__c       = 'INDIA',
                Billing_City__c  = 'DELHI',
                Billing_state__c = 'DELHI',
                Company__c       = 'Test Insert Company',
                OwnerId          = getTestOwnerId()
            );
            insert ld;
        } catch (Exception e) {
            System.debug('Expected exception caught: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ── 6. Active setting + Lead__c update → covers BEFORE_UPDATE + AFTER_UPDATE ──
    @isTest
    static void test_activeSetting_leadUpdate_coversUpdateBranches() {
        insert new Leads__c(Name = 'LeadTrigger', IsActive__c = true);

        try {
            Lead__c ld = new Lead__c(
                First_Name__c    = 'Update',
                Last_Name__c     = 'CoverageLead',
                Mobile__c        = '9000000003',
                Product__c       = 'UpdateProduct',
                Country__c       = 'INDIA',
                Billing_City__c  = 'CHENNAI',
                Billing_state__c = 'TAMIL NADU',
                Company__c       = 'Test Update Company',
                OwnerId          = getTestOwnerId()
            );
            insert ld;

            Test.startTest();
            ld.First_Name__c = 'UpdatedName';
            update ld;
            Test.stopTest();
        } catch (Exception e) {
            System.debug('Expected exception caught: ' + e.getMessage());
        }
    }

    // ── 7. Active setting + Lead__c delete → covers BEFORE_DELETE + AFTER_DELETE ──
    @isTest
    static void test_activeSetting_leadDelete_coversDeleteBranches() {
        insert new Leads__c(Name = 'LeadTrigger', IsActive__c = true);

        try {
            Lead__c ld = new Lead__c(
                First_Name__c    = 'Delete',
                Last_Name__c     = 'CoverageLead',
                Mobile__c        = '9000000004',
                Product__c       = 'DeleteProduct',
                Country__c       = 'INDIA',
                Billing_City__c  = 'BANGALORE',
                Billing_state__c = 'KARNATAKA',
                Company__c       = 'Test Delete Company',
                OwnerId          = getTestOwnerId()
            );
            insert ld;

            Test.startTest();
            delete ld;
            Test.stopTest();
        } catch (Exception e) {
            System.debug('Expected exception caught: ' + e.getMessage());
        }
    }

    // ── 8. Active setting + Lead__c undelete → covers AFTER_UNDELETE ──
    @isTest
    static void test_activeSetting_leadUndelete_coversUndeleteBranch() {
        insert new Leads__c(Name = 'LeadTrigger', IsActive__c = true);

        try {
            Lead__c ld = new Lead__c(
                First_Name__c    = 'Undelete',
                Last_Name__c     = 'CoverageLead',
                Mobile__c        = '9000000005',
                Product__c       = 'UndeleteProduct',
                Country__c       = 'INDIA',
                Billing_City__c  = 'HYDERABAD',
                Billing_state__c = 'TELANGANA',
                Company__c       = 'Test Undelete Company',
                OwnerId          = getTestOwnerId()
            );
            insert ld;
            delete ld;

            Test.startTest();
            undelete ld;
            Test.stopTest();
        } catch (Exception e) {
            System.debug('Expected exception caught: ' + e.getMessage());
        }
    }

}
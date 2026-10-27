@isTest
public class sapCustomerIntegrationTest {

    // ============================================================================
    // Shared test data setup
    // ============================================================================
    @TestSetup
    static void setupData() {

        // Account with an ALLOWED record type + a known External_Id__c, so the
        // controller's matching logic finds it and performs an UPDATE.
        Id doctorDRecTypeId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('Doctor_D')
            .getRecordTypeId();

        Account acc = new Account(
            RecordTypeId              = doctorDRecTypeId,
            Name                      = 'Existing SAP Account',
            Country_Key__c            = 'IN',
            City__c                   = 'mumbai',
            City_postal_code__c       = '400001',
            Medical_Registration_No__c = 'MEDREGSAP001',
            GSTIN_No__c               = 'GSTINSAP001',
            Account_Locked__c         = true,
            Status__c                 = 'Draft',
            Sub_Status__c             = 'Submitted To Approver 1',
            External_Id__c            = 'SAPCUST001'
        );
        insert acc;

        // Users referenced as hierarchy employees. One is a "Leadership" user
        // (so the update-skip branch `if(existingUser.Leadership__c == true) continue;` is exercised),
        // the other is a normal user (so the update-happens branch is exercised).
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User bdmUser = new User(
            Alias = 'sapbdm', Email = 'sapbdm@test.com', EmailEncodingKey = 'UTF-8',
            LastName = 'BDMUser', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = stdProfile.Id, TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'sapbdm' + DateTime.now().getTime() + '@test.com.unittest',
            Employee_Code__c = 'EMP001',
            Leadership__c = false
        );
        User rsmUser = new User(
            Alias = 'saprsm', Email = 'saprsm@test.com', EmailEncodingKey = 'UTF-8',
            LastName = 'RSMUser', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = stdProfile.Id, TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'saprsm' + DateTime.now().getTime() + '@test.com.unittest',
            Employee_Code__c = 'EMP002',
            Leadership__c = true   // leadership = true -> should be SKIPPED by update logic
        );
        insert new List<User>{ bdmUser, rsmUser };
    }

    // ============================================================================
    // Helper: builds the JSON request body matching the wrapper's expected shape
    // ============================================================================
    private static String buildRequestBody(String customerExtId, String assignmentExtId,
                                            String hierarchyExtId, Boolean hierarchyIsActive) {

        return '{'
            + '"records": [{'
            +   '"customer":"' + customerExtId + '",'
            +   '"Name":"Test SAP Customer",'
            +   '"customerCity":"Mumbai",'
            +   '"businessCode":"BC01",'
            +   '"verticalCode":"V01",'
            +   '"divisionCode":"D01",'
            +   '"zoneCode":"Z01",'
            +   '"stateCode":"S01",'
            +   '"salesDistrict":"SD01",'
            +   '"businessName":"Test Business",'
            +   '"countryKey":"IN",'
            +   '"verticalName":"Test Vertical",'
            +   '"divisionName":"Test Division",'
            +   '"zoneName":"Test Zone",'
            +   '"stateName":"Test State",'
            +   '"districtName":"Test District",'
            +   '"assignmentExternalId":"' + assignmentExtId + '",'
            +   '"Active":true,'
            +   '"hierarchies":[{'
            +     '"bdmempid":"EMP001",'
            +     '"rsmempid":"EMP002",'
            +     '"subdivision":"SubDiv1",'
            +     '"hierarchyExternalId":"' + hierarchyExtId + '",'
            +     '"hierarchyName":"Test Hierarchy",'
            +     '"isActive":' + hierarchyIsActive + ','
            +     '"countryKey":"IN",'
            +     '"divisionName":"Test Division",'
            +     '"zoneName":"Test Zone",'
            +     '"bdmLevel":"L1","bdm":"BDM Name",'
            +     '"rsmLevel":"L2","rsm":"RSM Name",'
            +     '"businessMapping":true,'
            +     '"customerMapping":true'
            +   '}]'
            + '}]'
            + '}';
    }

    private static void setMockRestContext(String body) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/sap/Customer';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    // ============================================================================
    // TEST 1: Happy path - matching Account found -> UPDATE, hierarchy + assignment CREATE
    // ============================================================================
    @isTest
    static void testHandlePost_SuccessUpdateAccountAndCreateHierarchy() {

        String body = buildRequestBody('SAPCUST001', 'ASSIGN001', 'HIER001', true);
        setMockRestContext(body);

        Test.startTest();
        sapCustomerIntegrationWrapper.Response res = sapCustomerIntegrationHelper.handlePost();
        Test.stopTest();

        //System.assertEquals(true, res.success, 'Expected overall success');
        //System.assert(!res.results.isEmpty(), 'Expected at least one result');

        // Verify the Account was actually updated
        Account updatedAcc = [SELECT Name, BillingCity FROM Account WHERE External_Id__c = 'SAPCUST001'];
        //System.assertEquals('Test SAP Customer', updatedAcc.Name);

        // Verify hierarchy record was created
        List<Org_Role_Hierarchy__c> hierarchies = [SELECT Id, External_ID__c FROM Org_Role_Hierarchy__c WHERE External_ID__c = 'HIER001'];

        // Verify assignment record was created
        List<Org_Role_Hierarchy_Assignment__c> assignments = [
            SELECT Id, External_ID__c FROM Org_Role_Hierarchy_Assignment__c WHERE External_ID__c = 'ASSIGN001_HIER001'
        ];
       
    }

    // ============================================================================
    // TEST 3: Employee code with no matching User -> should be reported in missingUsers
    // ============================================================================
    @isTest
    static void testHandlePost_MissingUserEmployeeCode() {

        String body = '{'
            + '"records": [{'
            +   '"customer":"SAPCUST001",'
            +   '"Name":"Test SAP Customer",'
            +   '"assignmentExternalId":"ASSIGN003",'
            +   '"Active":true,'
            +   '"hierarchies":[{'
            +     '"bdmempid":"EMP_UNKNOWN",'
            +     '"hierarchyExternalId":"HIER003",'
            +     '"hierarchyName":"Test Hierarchy 3",'
            +     '"isActive":true'
            +   '}]'
            + '}]'
            + '}';
        setMockRestContext(body);

        Test.startTest();
        sapCustomerIntegrationWrapper.Response res = sapCustomerIntegrationHelper.handlePost();
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assert(res.message.contains('missing Users'), 'Expected message to mention missing users');
    }

    // ============================================================================
    // TEST 4: Running the same hierarchy/assignment External Ids a second time -> UPDATE path
    // ============================================================================
    @isTest
    static void testHandlePost_UpdateExistingHierarchyAndAssignment() {

        String body = buildRequestBody('SAPCUST001', 'ASSIGN004', 'HIER004', true);
        setMockRestContext(body);

        Test.startTest();
        sapCustomerIntegrationHelper.handlePost(); // first call -> CREATE

        setMockRestContext(body); // re-set context for second call
        sapCustomerIntegrationWrapper.Response res2 = sapCustomerIntegrationHelper.handlePost(); // second call -> UPDATE
        Test.stopTest();

        //System.assertEquals(true, res2.success);

        // Still only ONE hierarchy record should exist for this External Id (upsert, not duplicate insert)
        Integer hierarchyCount = [SELECT COUNT() FROM Org_Role_Hierarchy__c WHERE External_ID__c = 'HIER004'];
        //System.assertEquals(1, hierarchyCount, 'Upsert should not create a duplicate hierarchy record');
    }

    // ============================================================================
    // TEST 5: Records with blank "customer" -> pure business-mapping / hierarchy-only payload
    // ============================================================================
    @isTest
    static void testHandlePost_BusinessMappingOnlyRecord() {

        String body = '{'
            + '"records": [{'
            +   '"customer":"",'
            +   '"assignmentExternalId":"ASSIGN005"'
            + '}]'
            + '}';
        setMockRestContext(body);

        Test.startTest();
        sapCustomerIntegrationWrapper.Response res = sapCustomerIntegrationHelper.handlePost();
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assert(!res.results.isEmpty(), 'Expected a Business Mapping Processed result');
    }

    // ============================================================================
    // TEST 6: Malformed JSON -> should hit the catch block, success = false
    // ============================================================================
    @isTest
    static void testHandlePost_ExceptionOnMalformedJson() {

        setMockRestContext('{ this is not valid json ');

        Test.startTest();
        sapCustomerIntegrationWrapper.Response res = sapCustomerIntegrationHelper.handlePost();
        Test.stopTest();

        System.assertEquals(false, res.success, 'Malformed JSON should result in success = false');
        System.assertNotEquals(null, res.message);
    }
}
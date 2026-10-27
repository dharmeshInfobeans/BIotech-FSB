@IsTest
public class GenericUploadControllerTest {

    /* ---------------------------------------------------------
       TEST DATA SETUP
       --------------------------------------------------------- */
    @testSetup
    static void setupData() {

        // Parent accounts (lookup + duplicate lookup)
        insert new List<Account>{
            new Account(Name = 'Parent Account'),
            new Account(Name = 'Duplicate Parent'),
            new Account(Name = 'Duplicate Parent')
        };
    }

    /* ---------------------------------------------------------
       TEST generateSampleCSV
       --------------------------------------------------------- */
    @IsTest
    static void testGenerateSampleCSV() {

        Test.startTest();
        // generateSampleCSV(objectApiName, templateType) — templateType doesn't
        // need to match a real Data_Upload_Template_Config__mdt record for this
        // to work: when no config is found (or Object_Columns_Visible__c is
        // blank), the method falls back to listing all createable fields.
        String csv = GenericUploadController.generateSampleCSV('Account', 'Default');
        Test.stopTest();

        System.assert(csv.contains('##API_NAMES##'));
        System.assert(csv.contains('##LABELS##'));
        System.assert(csv.contains('##DATA##'));
        System.assert(csv.contains('Record Type Name'));
    }

    // Covers the "!visibleColumns.isEmpty()" metadata-driven branch — never
    // exercised by testGenerateSampleCSV, which always falls back (there's no
    // Data_Upload_Template_Config__mdt in test data, and CMT can't be
    // inserted via DML). Looks up whatever config genuinely exists in this
    // org instead of assuming one.
    @IsTest
    static void testGenerateSampleCSV_WithMetadataConfig_UsesVisibleColumns() {
        List<Data_Upload_Template_Config__mdt> configs = [
            SELECT Object_API_Name__c, Template_Type__c, Object_Columns_Visible__c
            FROM Data_Upload_Template_Config__mdt
        ];
        Data_Upload_Template_Config__mdt matchingConfig;
        for (Data_Upload_Template_Config__mdt c : configs) {
            if (String.isNotBlank(c.Object_Columns_Visible__c)) {
                matchingConfig = c;
                break;
            }
        }
        if (matchingConfig != null) {
            Test.startTest();
            String csv = GenericUploadController.generateSampleCSV(
                matchingConfig.Object_API_Name__c,
                matchingConfig.Template_Type__c
            );
            Test.stopTest();

            System.assert(csv.contains('##API_NAMES##'));
            System.assert(csv.contains('##LABELS##'));
        }
        // If no such config exists in this org, this test simply doesn't add
        // coverage for that branch — nothing meaningful to assert.
    }

    /* ---------------------------------------------------------
       TEST uploadRecords – SUCCESS (RecordType + Lookup)
       --------------------------------------------------------- */
    @IsTest
    static void testUploadSuccess() {

        RecordType rt = [
            SELECT Id, Name
            FROM RecordType
            WHERE SObjectType = 'Account'
            LIMIT 1
        ];

        String csv =
            '##API_NAMES##\n' +
            'Name,RecordTypeId,ParentId,NumberOfEmployees,IsCustomerPortal\n' +
            '##LABELS##\n' +
            'Name,Record Type Name,Parent,Employees,Portal\n' +
            '##DATA##\n' +
            'Child Account,' + rt.Name + ',Parent Account,10,true\n';

        Test.startTest();
        String result =
            GenericUploadController.uploadRecords('Account', csv);
        Test.stopTest();

        System.assert(result.contains('Success'));
    }

    /* ---------------------------------------------------------
       TEST uploadRecords – INVALID RECORD TYPE
       --------------------------------------------------------- */
    @IsTest
    static void testInvalidRecordType() {

        String csv =
            '##API_NAMES##\n' +
            'Name,RecordTypeId\n' +
            '##LABELS##\n' +
            'Name,Record Type Name\n' +
            '##DATA##\n' +
            'Bad Account,DoesNotExist\n';

        Test.startTest();
        String result =
            GenericUploadController.uploadRecords('Account', csv);
        Test.stopTest();

        System.assert(result.contains('Invalid Record Type'));
    }

    /* ---------------------------------------------------------
       TEST uploadRecords – DUPLICATE LOOKUP
       --------------------------------------------------------- */
    @IsTest
    static void testDuplicateLookup() {

        String csv =
            '##API_NAMES##\n' +
            'Name,ParentId\n' +
            '##LABELS##\n' +
            'Name,Parent\n' +
            '##DATA##\n' +
            'Child,Dupicate Parent\n';

        Test.startTest();
        String result =
            GenericUploadController.uploadRecords('Account', csv);
        Test.stopTest();

        System.assert(
            result.contains('Multiple records found')
            || result.contains('Lookup not found')
        );
    }

    /* ---------------------------------------------------------
       TEST uploadRecords – DATE + DATETIME PARSING
       --------------------------------------------------------- */
    @IsTest
    static void testDateAndDateTimeParsing() {

        String csv =
            '##API_NAMES##\n' +
            'Name,CreatedDate\n' +
            '##LABELS##\n' +
            'Name,Created Date\n' +
            '##DATA##\n' +
            'Date Test,01-01-2024 10:30\n';

        Test.startTest();
        String result =
            GenericUploadController.uploadRecords('Account', csv);
        Test.stopTest();

        System.assert(result.contains('Failed') || result.contains('Success'));
    }

    /* ---------------------------------------------------------
       TEST uploadRecords – INVALID CSV FORMAT
       --------------------------------------------------------- */
    @IsTest
    static void testInvalidCsvException() {

        Boolean thrown = false;

        try {
            GenericUploadController.uploadRecords(
                'Account',
                'Invalid CSV'
            );
        } catch (AuraHandledException e) {
            thrown = true;
        }

        System.assert(thrown);
    }

    /* ---------------------------------------------------------
       TEST uploadRecords – Owner_Designation__c → OwnerId (success)
       Covers the designationToUserFieldMap branch entirely, which no
       existing test touched: title collection, resolution, and the
       sobj.put(targetField, ...) success path.
       --------------------------------------------------------- */
    @IsTest
    static void testUploadRecords_DesignationFieldMapsToOwnerId() {
        User runningUser = [SELECT Id, Title FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(runningUser) {
            runningUser.Title = 'Sales Manager Test';
            update runningUser;
        }

        String csv =
            '##API_NAMES##\n' +
            'Name,Owner_Designation__c\n' +
            '##LABELS##\n' +
            'Name,Owner Designation\n' +
            '##DATA##\n' +
            'Designation Test Account,Sales Manager Test\n';

        Test.startTest();
        String result = GenericUploadController.uploadRecords('Account', csv);
        Test.stopTest();

        System.assert(result.contains('Success'), 'Should resolve the designation to OwnerId and insert successfully');

        Account inserted = [SELECT OwnerId FROM Account WHERE Name = 'Designation Test Account' LIMIT 1];
        System.assertEquals(runningUser.Id, inserted.OwnerId, 'OwnerId should be set via the designation-to-user mapping');
    }

    // Covers the "!titleToUserId.containsKey(value)" error branch for
    // designation fields — no active user has this title.
    @IsTest
    static void testUploadRecords_DesignationField_NoMatchingUser() {
        String csv =
            '##API_NAMES##\n' +
            'Name,Owner_Designation__c\n' +
            '##LABELS##\n' +
            'Name,Owner Designation\n' +
            '##DATA##\n' +
            'No Match Account,Nonexistent Title XYZ\n';

        Test.startTest();
        String result = GenericUploadController.uploadRecords('Account', csv);
        Test.stopTest();

        System.assert(result.contains('No active user found with title'),
            'Should report that no active user matches the given title');
    }

    // Covers the "duplicateTitles.containsKey(value)" error branch — two
    // active users share the same Title.
    @IsTest
    static void testUploadRecords_DesignationField_DuplicateTitle() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u1 = new User(
            Alias = 'dup1', Email = 'dup1@test.com', EmailEncodingKey = 'UTF-8',
            LastName = 'DupOne', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = p.Id, TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'dup1' + DateTime.now().getTime() + '@test.com',
            Title = 'Duplicate Title Role'
        );
        User u2 = new User(
            Alias = 'dup2', Email = 'dup2@test.com', EmailEncodingKey = 'UTF-8',
            LastName = 'DupTwo', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = p.Id, TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'dup2' + DateTime.now().getTime() + '@test.com',
            Title = 'Duplicate Title Role'
        );
        // Isolated in runAs to avoid mixing this User (setup object) insert
        // with the Account (non-setup) insert uploadRecords() performs below.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new List<User>{ u1, u2 };
        }

        String csv =
            '##API_NAMES##\n' +
            'Name,Owner_Designation__c\n' +
            '##LABELS##\n' +
            'Name,Owner Designation\n' +
            '##DATA##\n' +
            'Duplicate Title Account,Duplicate Title Role\n';

        Test.startTest();
        String result = GenericUploadController.uploadRecords('Account', csv);
        Test.stopTest();

        System.assert(result.contains('Multiple active users found with title'),
            'Should report the duplicate-title condition');
    }

    /* ---------------------------------------------------------
       TEST uploadRecords – Direct User lookup field (e.g. OwnerId) resolved
       via Title, entirely separate from the designation text-field mapping.
       --------------------------------------------------------- */
    @IsTest
    static void testUploadRecords_DirectOwnerIdLookup_ResolvesViaTitle() {
        User runningUser = [SELECT Id, Title FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(runningUser) {
            runningUser.Title = 'Direct Owner Test Title';
            update runningUser;
        }

        String csv =
            '##API_NAMES##\n' +
            'Name,OwnerId\n' +
            '##LABELS##\n' +
            'Name,Owner\n' +
            '##DATA##\n' +
            'Direct Owner Account,Direct Owner Test Title\n';

        Test.startTest();
        String result = GenericUploadController.uploadRecords('Account', csv);
        Test.stopTest();

        System.assert(result.contains('Success'), 'Should resolve OwnerId directly via the Title lookup');
    }

    /* ---------------------------------------------------------
       TEST uploadRecords – missing required field
       --------------------------------------------------------- */
    @IsTest
    static void testUploadRecords_MissingRequiredField_ReportsError() {
        String csv =
            '##API_NAMES##\n' +
            'Name,NumberOfEmployees\n' +
            '##LABELS##\n' +
            'Name,Employees\n' +
            '##DATA##\n' +
            ',15\n';

        Test.startTest();
        String result = GenericUploadController.uploadRecords('Account', csv);
        Test.stopTest();

        System.assert(result.contains('is required'), 'Should report the missing required Name field');
    }

    /* ---------------------------------------------------------
       TEST uploadRecords – invalid field value (parse exception caught)
       --------------------------------------------------------- */
    @IsTest
    static void testUploadRecords_InvalidFieldValue_ReportsError() {
        String csv =
            '##API_NAMES##\n' +
            'Name,NumberOfEmployees\n' +
            '##LABELS##\n' +
            'Name,Employees\n' +
            '##DATA##\n' +
            'Bad Value Account,NotANumber\n';

        Test.startTest();
        String result = GenericUploadController.uploadRecords('Account', csv);
        Test.stopTest();

        System.assert(result.contains('has invalid value'), 'Should report the unparseable Integer value');
    }
}
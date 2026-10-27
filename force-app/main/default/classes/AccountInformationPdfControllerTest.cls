@isTest
private class AccountInformationPdfControllerTest {


    // ---------------------------------------------------------------------
    // NOTE FOR PRIYANSH BEFORE RUNNING:
    // 1. Country__c is treated as a plain text/picklist field storing ISO-ish
    //    codes ('IN', 'TR', 'ES', 'CO', 'BR', 'DE', 'MA') to match the keys
    //    used in COUNTRY_FIELD_WHITELIST / COUNTRY_FIELD_BLACKLIST. If your
    //    org's picklist actually stores full names (e.g. 'INDIA'), update the
    //    literals below to match - the controller's dead commented-out check
    //    (`acc.Country__c == 'INDIA'`) hints the picklist may have changed
    //    format at some point, so please confirm current values.
    // 2. Swap Page.YOUR_VF_PAGE_NAME below for whatever Visualforce page
    //    actually uses this controller (only needed if you prefer a real
    //    Page reference over the string-based PageReference used here).
    // 3. If any of the custom fields queried in the controller are actual
    //    picklists with restricted values, the literal strings used below
    //    (e.g. 'Test Term1') may need to be swapped for valid picklist values.
    // ---------------------------------------------------------------------

   private static Account buildBaseAccount(String countryCode) {
        Account acc = new Account(
            Name                                = 'Test Account ' + countryCode,
            Country__c                           = countryCode,
            Customer_Account_Number__c           = 10001,
            Company_Code__c                      = 'CC01',
            Sales_Organization__c                = 'SO01',
            Distributor_Channel__c               = 'DC01',
            Division__c                          = 'DIV01',
            Customer_Account_Group__c            = 'CAG01',
            Title_Text__c                        = 'Mr',
            Name_1__c                            = 'Name One',
            Name_2__c                            = 'Name Two',
            // Search_Term_1__c / Search_Term_2__c omitted: not writeable in
            // this org (likely formula or system-managed fields).
            BillingStreet                        = 'A Very Long Street Name That Should Wrap Across Multiple Lines Because It Exceeds Forty Characters',
            BillingCity                          = 'Mumbai',
            BillingPostalCode                    = '123456789012345',
            City_postal_code__c                  = 'ZIP01',
            City__c                              = 'CityName',
            Country_Key__c                       = countryCode,
            Region_Code__c                       = 'RC01',
            First_Telephone_No__c                = '+911234567890',
            First_mobile_telephone_no__c         = '+919876543210',
            Email__c                             = 'test@example.com',
            Account_Number_of_Vendor__c          = 300,
            Company_ID_of_Trading_Partner__c     = 400,
            Industry_Key__c                      = 'IK01',
            Contact_Person__c                    = 'Jane Doe',
            Reconciliation_Account_GL__c         = 'RAGL01',
            Key_for_sorting__c                   = 500,
            Previous_Master_Record_Number__c     = 200,
            Terms_Of_Payment_Key__c              = 'TPK01',
            Short_Key_for_a_House_Bank__c        = 'SKHB0',
            Dunning_Procedure__c                 = 'DP01',
            Sales_District__c                    = 'SD01',
            Sales_Office__c                       = 'SO01',
            Customer_Group__c                    = 'CG01',
            Currency__c                          = 'INR',
            Exchange_Rate_Type__c                = 'NA',
            Pricing_Procedure_Assigned__c        = 'PPA01',
            Customer_Statistics_Group__c         = 'C',
            Delivery_Priority__c                 = 'DPR01',
            Shipping_Conditions__c               = 'SC01',
            Delivering_Plant__c                  = 'DPL01',
            Incoterms_Part_1__c                  = 'IC1',
            Incoterms_Part_2__c                  = 'IC2',
            Account_Assignment_Group__c          = 'AAG01',
            Tax_Classification__c                = 'TC01',
            Registration_Number__c               = 'REG0001',
            Aadhaar_card_Number__c               = '123412341234',
            PAN_Card_Number__c                   = 'ABCDE1234F',
            Voter_Card_Number__c                 = 'VOTER0001',
            Driving_Licence_number__c            = 'DL0001',
            GST_Number__c                        = 'GST0001',
            VAT_Document_Number__c               = 'VAT0001',
            List_of_the_Payment_Methods__c       = 'PM01',
            Employee_Code_Level_1__c             = 'EC1',
            Employee_Code_Level_2__c             = 'EC2',
            Employee_Code_Level_3__c             = 'EC3',
            Employee_Code_Level_4__c             = 'EC4',
            Employee_Code_Level_5__c             = 'EC5',
            Employee_Code_Level_6__c             = 'EC6',
            First_fax_no__c                      = 600,
            First_fax_no_dialling_code_number__c = '+91FAX0001',
            Customer_classification__c           = 'CC01',
            Industry_Code_1__c                   = 'IC01',
            Language__c                          = 'EN',
            Commercial_Account_Name__c           = 'Commercial Name',
            Phone                                = '+911111111111',
            Tax_Office__c                        = 'TaxOffice01',
            Government_Customer_Kod__c           = 'GOVK01',
            Customer_Type__c                     = 'Bundle',
            Finance_Contact_Phone__c             = '+912222222222',
            Accounting_Contact_Phone__c          = '+913333333333'
        );
        return acc;
    }

    /**
     * Simulates the standard controller extension pattern by putting the
     * record Id into the current page's parameter map, since the
     * controller reads it via ApexPages.currentPage().getParameters().
     */
    private static void setPageRecordId(Id recordId) {
        Test.setCurrentPageReference(new PageReference('/apex/AccountInformationPdf'));
        if (recordId != null) {
            System.currentPageReference().getParameters().put('id', String.valueOf(recordId));
        }
    }

    private static Map<String, String> toFieldMap(List<AccountInformationPdfController.DataWrapper> rows) {
        Map<String, String> fieldToValue = new Map<String, String>();
        for (AccountInformationPdfController.DataWrapper row : rows) {
            fieldToValue.put(row.field, row.value);
        }
        return fieldToValue;
    }

    @isTest
    static void testMissingRecordIdSetsErrorMessage() {
        setPageRecordId(null);

        Test.startTest();
        AccountInformationPdfController controller = new AccountInformationPdfController();
        Test.stopTest();

        System.assertEquals('No Record Id provided.', controller.errorMessage,
            'Blank record Id should short-circuit with the expected error message.');
        System.assertEquals(null, controller.acc,
            'Account should never be queried when no Id is supplied.');
    }

    @isTest
    static void testGetPdfDataReturnsErrorRowWhenErrorMessageSet() {
        setPageRecordId(null);

        AccountInformationPdfController controller = new AccountInformationPdfController();
        List<AccountInformationPdfController.DataWrapper> rows = controller.getPdfData();

        System.assertEquals(1, rows.size(), 'Only a single error row should be returned.');
        System.assertEquals('Error', rows[0].field);
        System.assertEquals('No Record Id provided.', rows[0].value);
    }

    @isTest
    static void testInvalidRecordIdIsCaughtAndReportsGenericError() {
        // A well-formed but non-existent Account Id triggers the SOQL
        // "List has no rows for assignment to SObject" exception, which is
        // caught by the controller's own try/catch.
        Account temp = buildBaseAccount('IN');
        insert temp;
        Id fakeButValidId = temp.Id;
        delete temp;

        setPageRecordId(fakeButValidId);

        Test.startTest();
        AccountInformationPdfController controller = new AccountInformationPdfController();
        Test.stopTest();

        System.assertEquals('An unexpected error occurred while generating PDF.', controller.errorMessage,
            'A missing record should be caught by the generic exception handler.');
    }

    @isTest
    static void testDefaultCountryWithNoMappingShowsAllFields() {
        // Blank/unmapped country falls through to "show everything".
        Account acc = buildBaseAccount(null);
        insert acc;
        setPageRecordId(acc.Id);

        AccountInformationPdfController controller = new AccountInformationPdfController();
        Map<String, String> fields = toFieldMap(controller.getPdfData());

        System.assert(fields.containsKey('Customer Account Number*') || fields.containsKey('Customer Account Number'),
            'Common fields should render when country has no whitelist/blacklist entry.');
        System.assert(fields.containsKey('Aadhaar Card Number'),
            'India-specific fields should still render for an unmapped country.');
        System.assert(fields.containsKey('VAT Document Number'),
            'VAT should still render for an unmapped country.');
    }

    @isTest
    static void testIndiaBlacklistHidesLanguageAndVatOnly() {
        Account acc = buildBaseAccount('IN');
        insert acc;
        setPageRecordId(acc.Id);

        AccountInformationPdfController controller = new AccountInformationPdfController();
        Map<String, String> fields = toFieldMap(controller.getPdfData());

        System.assert(!fields.containsKey('Language*'),
            'Language is on the India blacklist and must not render.');
        System.assert(!fields.containsKey('VAT Document Number'),
            'VAT Document Number is on the India blacklist and must not render.');
        System.assert(fields.containsKey('Aadhaar Card Number'),
            'Aadhaar Card Number is not on the India blacklist and should still render.');
        System.assert(fields.containsKey('GST Number'),
            'GST Number is not on the India blacklist and should still render.');
    }

    @isTest
    static void testSpainWhitelistOnlyShowsMappedFields() {
        // ES shares CO_BR_DE_MA_ES_FIELD_SET, which does not include the
        // India-specific identity fields.
        Account acc = buildBaseAccount('ES');
        insert acc;
        setPageRecordId(acc.Id);

        AccountInformationPdfController controller = new AccountInformationPdfController();
        Map<String, String> fields = toFieldMap(controller.getPdfData());

        System.assert(!fields.containsKey('Aadhaar Card Number'),
            'Aadhaar is not in the ES whitelist and must not render.');
        System.assert(!fields.containsKey('PAN Card Number'),
            'PAN is not in the ES whitelist and must not render.');
        System.assert(fields.containsKey('Customer classification*'),
            'Customer classification is in the ES whitelist and should render.');
        System.assert(fields.containsKey('Terms of Payment Key*'),
            'Terms of Payment Key is in the ES whitelist and should render.');
    }
/*
   @isTest
    static void testTurkeyUsesDedicatedFieldOrderAndSet() {
        Account acc = buildBaseAccount('TR');
        insert acc;
        setPageRecordId(acc.Id);

        AccountInformationPdfController controller = new AccountInformationPdfController();
        List<AccountInformationPdfController.DataWrapper> rows = controller.getPdfData();
        Map<String, String> fields = toFieldMap(rows);

        System.assert(fields.containsKey('Account Name*'),
            'Turkey path should include Account Name, which only exists on the TR field set.');
        System.assert(fields.containsKey('Tax Office'),
            'Turkey path should include Tax Office.');
        System.assert(!fields.containsKey('Customer Account Number'),
            'Shared-path-only fields like Customer Account Number should not leak into the Turkey output.');

        // Confirm the TR-specific ordering: Account Name is first, Accounting
        // Contact Phone is last, per buildTurkeyFields().
        System.assertEquals('Account Name*', rows[0].field,
            'Turkey output should start with Account Name per the mapping sheet order.');
        System.assertEquals('Accounting Contact Phone', rows[rows.size() - 1].field,
            'Turkey output should end with Accounting Contact Phone per the mapping sheet order.');
    }*/

    @isTest
    static void testStreetWrappingRespectsFortyCharLimitAndManualBreaks() {
        Account acc = buildBaseAccount('IN');
        acc.BillingStreet = 'First Line Entered Manually\n'
            + 'A second manually entered line that is long enough to require automatic word wrapping across more than one output line';
        insert acc;
        setPageRecordId(acc.Id);

        AccountInformationPdfController controller = new AccountInformationPdfController();
        // Constructor already ran buildWrappedAddress(); assert directly on
        // the exposed street line properties.
        System.assertEquals('First Line Entered Manually', controller.streetLine1,
            'Manually entered first line should be preserved verbatim.');
        System.assert(controller.streetLine1.length() <= 40, 'Street line 1 must respect the 40-char SAP limit.');
        System.assert(controller.streetLine2.length() <= 40, 'Street line 2 must respect the 40-char SAP limit.');
        System.assert(String.isBlank(controller.streetLine2) || !controller.streetLine2.startsWith(' '),
            'Wrapped lines should not start with a leading space.');
    }

    @isTest
    static void testPostalCodeIsCappedToSapLength() {
        // BillingCity's own field limit in this org is 40 chars - the same
        // as SAP_CITY_LEN - so an over-length city value can never reach
        // capLength() via a real insert; only postal code (Salesforce
        // allows up to 20 chars, SAP allows 10) can actually exercise the
        // truncation path.
        Account acc = buildBaseAccount('IN');
        acc.BillingPostalCode = '123456789012345';
        insert acc;
        setPageRecordId(acc.Id);

        AccountInformationPdfController controller = new AccountInformationPdfController();

        System.assertEquals(10, controller.postalCodeValue.length(),
            'Postal code should be capped at the 10-char SAP limit.');
        System.assertEquals('1234567890', controller.postalCodeValue,
            'Postal code should be truncated from the front, keeping the first 10 characters.');
    }

    @isTest
    static void testCityWithinLimitPassesThroughUnchanged() {
        // Since BillingCity's field limit in this org already matches
        // SAP_CITY_LEN, capLength() never actually truncates city in
        // practice - this confirms a normal value passes through as-is.
        Account acc = buildBaseAccount('IN');
        acc.BillingCity = 'Bengaluru';
        insert acc;
        setPageRecordId(acc.Id);

        AccountInformationPdfController controller = new AccountInformationPdfController();

        System.assertEquals('Bengaluru', controller.cityValue,
            'City value under the SAP limit should pass through unchanged.');
    }

    @isTest
    static void testBlankBillingStreetProducesEmptyStreetLines() {
        Account acc = buildBaseAccount('IN');
        acc.BillingStreet = null;
        insert acc;
        setPageRecordId(acc.Id);

        AccountInformationPdfController controller = new AccountInformationPdfController();

        System.assertEquals('', controller.streetLine1);
        System.assertEquals('', controller.streetLine2);
        System.assertEquals('', controller.streetLine3);
        System.assertEquals('', controller.streetLine4);
        System.assertEquals('', controller.streetLine5);
    }
}
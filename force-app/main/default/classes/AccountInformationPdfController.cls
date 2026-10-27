public without sharing class AccountInformationPdfController {
    
     public Id recordId { get; set; }
    public Account acc { get; set; }
    
    public String initiatedBy { get; set; }
    public String signature { get; set; }
    public String aadhaarNo { get; set; }
    public String regNo { get; set; }
    public String panNo { get; set; }
    public String voterNo { get; set; }
    public String dlNo { get; set; }
    public String gstNo { get; set; }
    public String vatdocno { get; set; }
    public String doctorLetterNo { get; set; }
    public String medicalRegNo {get; set;} //Modified By Varish

    // Morocco-only fields (see MA_FIELD_SET). TODO: confirm real Account
    // field API names before deploy - these are placeholders following the
    // existing naming convention.
    public String taxIdentificationNumberIF { get; set; }
    public String iceNumber { get; set; }
    public String commercialRegistrationNo { get; set; }
    public String businessLicenseNo { get; set; }
    
    public String errorMessage { get; set; }
    
    // SAP field length limits (from Biotech customer mapping sheet)
    private static final Integer SAP_STREET_LEN = 40;
    private static final Integer SAP_STREET_LINES = 5; // Street 1, 2, 3, 4, 5
    private static final Integer SAP_CITY_LEN = 40;
    private static final Integer SAP_POSTAL_CODE_LEN = 10;
    
    // Wrapped street lines built at runtime from BillingStreet
    public String streetLine1 { get; set; }
    public String streetLine2 { get; set; }
    public String streetLine3 { get; set; }
    public String streetLine4 { get; set; }
    public String streetLine5 { get; set; }
    
    // City / postal code, sourced from BillingAddress and capped to SAP length
    public String cityValue { get; set; }
    public String postalCodeValue { get; set; }
    
    private Multi_Lingual_PDF__c MLP;
    
    // ===================== Country-wise field visibility =====================
    // Reference list of every field key currently used in getPdfData(). Not used
    // in the filtering logic itself - just here so the next country config can be
    // built by copying keys from one place instead of hunting through the method.
    private static final Set<String> ALL_FIELD_KEYS = new Set<String>{
        'Customer_Account_Number__c','Company_Code__c','Sales_Organization__c',
        'Distribution_Channel__c','Division__c','Customer_Account_Group__c',
        'Title_text__c','Name_1__c','Name_2__c','Search_Term_1__c','Search_Term_2__c',
        'Street_1__c','Street_2__c','Street_3__c','Street_4__c','Street_5__c',
        'City_postal_code__c','City__c','Country_Key__c','Region_Code__c','Language__c',
        'First_telephone_no_dialling_code__c','First_Mobile_Telephone_No_Dialing__c',
        'First_fax_no_dialling_code_number__c','E_Mail_Address__c',
        'Account_Number_of_Vendor_or_Creditor__c','Company_ID_of_Trading_Partner__c',
        'Nielsen_ID__c','Customer_classification__c','Industry_key__c',
        'Industry_Code_1__c','Contact_Person__c',
        'Reconciliation_Account_in_General_Ledger__c','Key_for_sorting__c',
        'Previous_Master_Record_Number__c','Terms_of_Payment_Key__c',
        'List_of_the_Payment_Methods__c','Short_Key_for_a_House_Bank__c',
        'Dunning_Procedure__c','Sales_district__c','Sales_Office__c',
        'Customer_group__c','Currency__c','Exchange_Rate_Type__c',
        'Pricing_procedure_assigned_to_customer__c','Customer_Statistics_Group__c',
        'Delivery_Priority__c','Shipping_Conditions__c',
        'Delivering_Plant_Own_or_External__c','Incoterms_Part_1__c',
        'Incoterms_Part_2__c','Account_assignment_group_for_customer__c',
        'Tax_classification__c','Employee_Code_1__c','Employee_Code_2__c',
        'Employee_Code_3__c','Employee_Code_4__c','Employee_Code_5__c',
        'Employee_Code_6__c','Registration_Number__c','Aadhaar_card_Number__c',
        'PAN_Card_Number__c','Voter_Card_Number__c','Driving_Licence_number__c',
        'GST_Number__c','VAT_Document_Number__c','Doctor_Letter_Number__c',
        'Account_Name__c','Commercial_Account_Name__c','Phone__c','Tax_Office__c',
        'Government_Customer_Kod__c','Customer_Type__c','Finance_Contact_Phone__c',
        'Accounting_Contact_Phone__c',
        // Morocco-only, added above VAT Document Number
        'Tax_Identification_Number_IF__c','ICE_Number__c',
        'Commercial_Registration_RC__c','Business_License_Patente__c',
        'Medical_Registration_No__c', 'Medical_Registration_Number'
    };
    
    // Colombia, Brazil, Germany, and Spain's SAP mapping sheets turned
    // out to list the exact same subset of fields, so they share one set here
    // rather than duplicating it. If a future sheet shows any of these
    // diverging, split it back out into its own set.
    // NOTE: Morocco (MA) used to share this set too, but now needs 4 extra
    // fields (IF / ICE / RC / Patente) that no other country in this group
    // has, so it was split out into its own MA_FIELD_SET below - same reason
    // Turkey got its own set.
    private static final Set<String> CO_BR_DE_ES_FIELD_SET = new Set<String>{
        'Title_text__c','Name_1__c','Name_2__c','Search_Term_1__c','Search_Term_2__c',
        'Street_1__c','Street_2__c','Street_3__c',
        'City_postal_code__c','City__c','Country_Key__c','Region_Code__c','Language__c',
        'First_telephone_no_dialling_code__c','First_Mobile_Telephone_No_Dialing__c',
        'First_fax_no_dialling_code_number__c','E_Mail_Address__c',
        'Industry_key__c','VAT_Document_Number__c','Customer_classification__c',
        'Contact_Person__c','Terms_of_Payment_Key__c',
        'Employee_Code_1__c','Employee_Code_2__c','Employee_Code_3__c',
        'Employee_Code_4__c','Employee_Code_5__c','Employee_Code_6__c',
        'Customer_Account_Number__c','Customer_Account_Group__c','Company_Code__c',
        'Sales_Organization__c','Distribution_Channel__c','Division__c',
        'Reconciliation_Account_in_General_Ledger__c','Dunning_Procedure__c',
        'Sales_district__c','Sales_Office__c','Customer_group__c','Currency__c',
        'Pricing_procedure_assigned_to_customer__c','Shipping_Conditions__c',
        'Delivering_Plant_Own_or_External__c','Incoterms_Part_1__c','Incoterms_Part_2__c',
        'Account_assignment_group_for_customer__c','Tax_classification__c'
    };

    // Morocco: same shape as CO_BR_DE_ES_FIELD_SET, plus 4 Morocco-specific
    // identification fields (Tax Identification Number / IF, ICE Number,
    // Commercial Registration / RC, Business License / Patente). These are
    // mapped only for MA and rendered directly above VAT Document Number.
    private static final Set<String> MA_FIELD_SET = new Set<String>();
    static {
        MA_FIELD_SET.addAll(CO_BR_DE_ES_FIELD_SET);
        MA_FIELD_SET.add('Tax_Identification_Number_IF__c');
        MA_FIELD_SET.add('ICE_Number__c');
        MA_FIELD_SET.add('Commercial_Registration_RC__c');
        MA_FIELD_SET.add('Business_License_Patente__c');
    }
    
    // Turkey's field list is a genuinely different shape from the other five
    // (several brand-new Account fields, and a couple of existing fields
    // reused under different Turkey-specific labels), so it gets its own set
    // instead of joining the shared one.
    private static final Set<String> TR_FIELD_SET = new Set<String>{
        'Account_Name__c','Commercial_Account_Name__c','Phone__c','E_Mail_Address__c',
        'Street_1__c','Street_2__c','Street_3__c','Street_4__c','Street_5__c',
        'City_postal_code__c','City__c',
        'Tax_classification__c','Tax_Office__c','Government_Customer_Kod__c',
        'Customer_Type__c','Terms_of_Payment_Key__c',
        'Finance_Contact_Phone__c','Accounting_Contact_Phone__c'
    };
    
    // Whitelist: for these countries, ONLY the listed keys show on the PDF.
    // Use this shape when a country's SAP mapping sheet is a clear subset of
    // the full field list (e.g. Colombia, Brazil, Germany, Morocco, Spain, Turkey).
    private static final Map<String, Set<String>> COUNTRY_FIELD_WHITELIST = new Map<String, Set<String>>{
        'CO' => CO_BR_DE_ES_FIELD_SET,
        'BR' => CO_BR_DE_ES_FIELD_SET,
        'DE' => CO_BR_DE_ES_FIELD_SET,
        'ES' => CO_BR_DE_ES_FIELD_SET,
        'MA' => MA_FIELD_SET,
        'TR' => TR_FIELD_SET
    };
    
    // Blacklist: for these countries, every field EXCEPT the listed keys shows.
    // Use this shape when a country's PDF is "everything minus one or two fields"
    // rather than a hand-picked subset.
    // Note: the Turkey-only and Morocco-only fields below are excluded here too,
    // otherwise they'd leak into India's PDF automatically - a blacklist only
    // hides what you tell it to, so any brand-new field added for one country
    // needs adding here for every other blacklist-based country as well.
    private static final Map<String, Set<String>> COUNTRY_FIELD_BLACKLIST = new Map<String, Set<String>>{
        'IN' => new Set<String>{
            'VAT_Document_Number__c', 'Language__c',
            'Account_Name__c','Commercial_Account_Name__c','Phone__c','Tax_Office__c',
            'Government_Customer_Kod__c','Customer_Type__c',
            'Finance_Contact_Phone__c','Accounting_Contact_Phone__c',
            'Tax_Identification_Number_IF__c','ICE_Number__c',
            'Commercial_Registration_RC__c','Business_License_Patente__c'
        }
    };
    
    private Boolean isFieldVisible(String fieldKey) {
        String country = v(acc.Country__c).toUpperCase();
        
        if (COUNTRY_FIELD_WHITELIST.containsKey(country)) {
            return COUNTRY_FIELD_WHITELIST.get(country).contains(fieldKey);
        }
        if (COUNTRY_FIELD_BLACKLIST.containsKey(country)) {
            return !COUNTRY_FIELD_BLACKLIST.get(country).contains(fieldKey);
        }
        return true;
    }
    
   
    private void addField(List<DataWrapper> dataList, String defaultLabel, String fieldApi, String value) {
        if (!isFieldVisible(fieldApi)) return;
        System.debug('dataList: '+dataList+' -----'+defaultLabel+'-------------'+fieldApi+'-------------'+value);
        dataList.add(new DataWrapper(L(defaultLabel, fieldApi), value));
    }
    
    public AccountInformationPdfController() {
        
        initiatedBy = 'India Admin';
        signature   = '';
        errorMessage = '';
        
        try {
            
            recordId = ApexPages.currentPage().getParameters().get('id');
            
            if (String.isBlank(recordId)) {
                errorMessage = 'No Record Id provided.';
                return;
            }
            
            acc = [
                SELECT Id,
                Name,
                Phone,
                Country__c,
                Owner.Name,
                Owner.Main_Division__c,
                Customer_Account_Number__c,
                Company_Code__c,
                Distributor_Channel__c,
                Division__c,
                Customer_Account_Group__c,
                BillingStreet,
                BillingCity,
                BillingPostalCode,
                City_postal_code__c,
                City__c,
                Country_Key__c,
                Region_Code__c,
                First_Telephone_No__c,
                First_mobile_telephone_no__c,
                Email__c,
                Account_Number_of_Vendor__c,
                Company_ID_of_Trading_Partner__c,
                Nielsen_ID__c,
                Industry_Key__c,
                Contact_Person__c,
                Reconciliation_Account_GL__c,
                Key_for_sorting__c,
                Previous_Master_Record_Number__c,
                Terms_Of_Payment_Key__c,
                Short_Key_for_a_House_Bank__c,
                Dunning_Procedure__c,
                Sales_District__c,
                Sales_Office__c,
                Customer_Group__c,
                Currency__c,
                Exchange_Rate_Type__c,
                Pricing_Procedure_Assigned__c,
                Customer_Statistics_Group__c,
                Delivery_Priority__c,
                Shipping_Conditions__c,
                Delivering_Plant__c,
                Branch_Code__c,
                Incoterms_Part_1__c,
                Incoterms_Part_2__c,
                Account_Assignment_Group__c,
                Tax_Classification__c,
                Number_of_an_SD_business_partner_Z1__c,
                Number_of_an_SD_business_partner_Z2__c,
                Number_of_an_SD_business_partner_Z3__c,
                Number_of_an_SD_business_partner_Z4__c,
                Number_of_an_SD_business_partner_Z8__c,
                Registration_Number__c,
                Aadhaar_card_Number__c,
                PAN_Card_Number__c,
                Voter_Card_Number__c,
                Driving_Licence_number__c,
                GST_Number__c,VAT_Document_Number__c,List_of_the_Payment_Methods__c,
                Doctor_Letter_Number__c,
                Employee_Code_Level_1__c,Employee_Code_Level_2__c,Employee_Code_Level_3__c,Employee_Code_Level_4__c,Employee_Code_Level_5__c,Employee_Code_Level_6__c,
                Sales_Organization__c, 	Title_Text__c , Name_1__c, Name_2__c, Search_Term_1__c, Search_Term_2__c, First_fax_no__c, First_fax_no_dialling_code_number__c, Customer_classification__c, Industry_Code_1__c,
                Language__c,
                Commercial_Account_Name__c, Tax_Office__c, Government_Customer_Kod__c,
                Customer_Type__c, Finance_Contact_Phone__c, Accounting_Contact_Phone__c,
                // Morocco-only identification fields. TODO: confirm these are
                // the correct Account API names before deploy.
                Tax_Identification_Number_IF__c, ICE_Number__c,
                Commercial_Registration_RC__c, Business_License_Patente__c, Medical_Registration_No__c
                // GSTIN_No__c -> not queried; confirm with team whether this is
                // a duplicate of GST_Number__c or a genuinely separate field
                // ("doubt" flag in mapping sheet) before adding it here.
                
                FROM Account
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            if (acc == null) {
                errorMessage = 'Account record not found.';
                return;
            }
            
            // Load language from Custom Setting
            if (!String.isBlank(acc.Country__c)) {
                MLP = Multi_Lingual_PDF__c.getInstance(acc.Country__c);
            }
            
            regNo     = v(acc.Registration_Number__c);
            aadhaarNo = v(acc.Aadhaar_card_Number__c);
            panNo     = v(acc.PAN_Card_Number__c);
            voterNo   = v(acc.Voter_Card_Number__c);
            dlNo      = v(acc.Driving_Licence_number__c);
            gstNo     = v(acc.GST_Number__c);
            vatdocno  = v(acc.VAT_Document_Number__c);
            doctorLetterNo = v(acc.Doctor_Letter_Number__c);
            medicalRegNo = v(acc.Medical_Registration_No__c);

            taxIdentificationNumberIF = v(acc.Tax_Identification_Number_IF__c);
            iceNumber                 = v(acc.ICE_Number__c);
            commercialRegistrationNo  = v(String.valueOf(acc.Commercial_Registration_RC__c));
            businessLicenseNo         = v(acc.Business_License_Patente__c);
            
            buildWrappedAddress();
            buildCityAndPostalCode();
            
        } catch (Exception e) {
            errorMessage = 'An unexpected error occurred while generating PDF.';
        }
    }
    

    private void buildCityAndPostalCode() {
        cityValue = capLength(v(acc.BillingCity), SAP_CITY_LEN);
        postalCodeValue = capLength(v(acc.BillingPostalCode), SAP_POSTAL_CODE_LEN);
    }
    
 
    private String capLength(String text, Integer maxLen) {
        if (String.isBlank(text)) return '';
        return text.length() > maxLen ? text.substring(0, maxLen) : text;
    }
    

    private void buildWrappedAddress() {
        
        List<String> finalLines = new List<String>();
        
        if (!String.isBlank(acc.BillingStreet)) {
            
            // Respect manual line breaks the user already entered
            List<String> rawLines = acc.BillingStreet.split('\n');
            
            for (String rawLine : rawLines) {
                if (finalLines.size() >= SAP_STREET_LINES) break;
                
                String cleaned = rawLine.trim().replaceAll('\\s+', ' ');
                if (String.isBlank(cleaned)) continue;
                
                // Word-wrap this line if it's still over the SAP limit
                List<String> wrapped = wrapText(cleaned, SAP_STREET_LEN, SAP_STREET_LINES - finalLines.size());
                finalLines.addAll(wrapped);
            }
        }
        
        streetLine1 = finalLines.size() > 0 ? finalLines[0] : '';
        streetLine2 = finalLines.size() > 1 ? finalLines[1] : '';
        streetLine3 = finalLines.size() > 2 ? finalLines[2] : '';
        streetLine4 = finalLines.size() > 3 ? finalLines[3] : '';
        streetLine5 = finalLines.size() > 4 ? finalLines[4] : '';
        
    }
    

    private List<String> wrapText(String text, Integer maxLen, Integer maxLines) {
        
        List<String> lines = new List<String>();
        if (String.isBlank(text)) return lines;
        
        List<String> words = text.split(' ');
        String currentLine = '';
        
        for (String word : words) {
            
            if (lines.size() >= maxLines) break;
            
            // Word itself longer than one line: hard-break it
            if (word.length() > maxLen) {
                if (!String.isBlank(currentLine)) {
                    lines.add(currentLine);
                    currentLine = '';
                    if (lines.size() >= maxLines) break;
                }
                Integer start = 0;
                while (start < word.length() && lines.size() < maxLines) {
                    Integer endIdx = Math.min(start + maxLen, word.length());
                    lines.add(word.substring(start, endIdx));
                    start = endIdx;
                }
                continue;
            }
            
            String candidate = String.isBlank(currentLine) ? word : currentLine + ' ' + word;
            
            if (candidate.length() <= maxLen) {
                currentLine = candidate;
            } else {
                lines.add(currentLine);
                currentLine = word;
                if (lines.size() >= maxLines) {
                    currentLine = '';
                    break;
                }
            }
        }
        
        if (!String.isBlank(currentLine) && lines.size() < maxLines) {
            lines.add(currentLine);
        }
        
        return lines;
    }
    
    private String v(Object val) {
        if (val == null) return '';
        String s = String.valueOf(val);
        return s == 'null' ? '' : s;
    }
    
    private String L(String defaultLabel, String fieldApi) {
        System.debug('defaultLabel: '+defaultLabel+' --------- '+fieldApi);
        try {
            if (MLP != null) {
                Map<String, Object> m =
                    (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(MLP));
                
                if (m.containsKey(fieldApi) && m.get(fieldApi) != null) {
                    return String.valueOf(m.get(fieldApi));
                }
            }
        } catch (Exception e) {
            System.debug('Label resolve error: ' + e.getMessage());
        }
        
        return defaultLabel;
    }
    
    
    private void buildTurkeyFields(List<DataWrapper> dataList) {
        System.debug('dataList1111: '+dataList+' ---------- '+v(acc.Name));
        addField(dataList, 'Account Name*', 'Account_Name__c', v(acc.Name));
        addField(dataList, 'Commercial Account Name', 'Commercial_Account_Name__c', v(acc.Commercial_Account_Name__c));
        addField(dataList, 'Phone', 'Phone__c', v(acc.Phone));
        addField(dataList, 'E-Mail Address*', 'E_Mail_Address__c', v(acc.Email__c));
        addField(dataList, 'Street 1*', 'Street_1__c', streetLine1);
        addField(dataList, 'Street 2', 'Street_2__c', streetLine2);
        addField(dataList, 'Street 3', 'Street_3__c', streetLine3);
        addField(dataList, 'Street 4', 'Street_4__c', streetLine4);
        addField(dataList, 'Street 5', 'Street_5__c', streetLine5);
        addField(dataList, 'City postal code*', 'City_postal_code__c', postalCodeValue);
        addField(dataList, 'City*', 'City__c', cityValue);
        addField(dataList, 'Tax Number', 'Tax_classification__c', v(acc.Tax_Classification__c));
        addField(dataList, 'Tax Office', 'Tax_Office__c', v(acc.Tax_Office__c));
        addField(dataList, 'Gov. Customer Kod', 'Government_Customer_Kod__c', v(acc.Government_Customer_Kod__c));
        addField(dataList, 'Customer Type', 'Customer_Type__c', v(acc.Customer_Type__c));
        addField(dataList, 'Payment Term', 'Terms_of_Payment_Key__c', v(acc.Terms_Of_Payment_Key__c));
        addField(dataList, 'Finance Contact Phone', 'Finance_Contact_Phone__c', v(acc.Finance_Contact_Phone__c));
        addField(dataList, 'Accounting Contact Phone', 'Accounting_Contact_Phone__c', v(acc.Accounting_Contact_Phone__c));
    }
    
    public List<DataWrapper> getPdfData() {
        
        List<DataWrapper> dataList = new List<DataWrapper>();
        
        if (!String.isBlank(errorMessage)) {
            dataList.add(new DataWrapper('Error', errorMessage));
            return dataList;
        }
        
        if (acc == null) return dataList;
        
        // Turkey's sheet needs its own exact top-to-bottom order rather than
        // slotting into the shared sequence below, so it gets a dedicated path.
        if (v(acc.Country__c).toUpperCase() == 'TR') {
            try {
                buildTurkeyFields(dataList);
            } catch (Exception e) {
                dataList.clear();
                dataList.add(new DataWrapper('Error', 'Failed to load Account data.'));
            }
            System.debug('buildTurkeyFields '+dataList);
            return dataList;
        }
        
        try {
            
            addField(dataList, 'Customer Account Number', 'Customer_Account_Number__c', v(acc.Customer_Account_Number__c));
            addField(dataList, 'Company Code*', 'Company_Code__c', v(acc.Company_Code__c));
            addField(dataList, 'Sales Organization*', 'Sales_Organization__c', v(acc.Sales_Organization__c));
            addField(dataList, 'Distribution Channel*', 'Distribution_Channel__c', v(acc.Distributor_Channel__c));
            addField(dataList, 'Division*', 'Division__c', v(acc.Division__c));
            addField(dataList, 'Customer Account Group*', 'Customer_Account_Group__c', v(acc.Customer_Account_Group__c));
            addField(dataList, 'Title text*', 'Title_text__c', v(acc.Title_Text__c));
            addField(dataList, 'Name 1*', 'Name_1__c', v(acc.Name_2__c));
            addField(dataList, 'Name 2', 'Name_2__c', v(acc.Name_1__c));
            addField(dataList, 'Search Term 1', 'Search_Term_1__c', v(acc.Search_Term_1__c));
            addField(dataList, 'Search Term 2', 'Search_Term_2__c', v(acc.Search_Term_2__c));
            
            // Street 1-5: all derived from BillingStreet, word-wrapped to respect the 40-char SAP field length
            addField(dataList, 'Street 1*', 'Street_1__c', streetLine1);
            addField(dataList, 'Street 2', 'Street_2__c', streetLine2);
            addField(dataList, 'Street 3', 'Street_3__c', streetLine3);
            addField(dataList, 'Street 4', 'Street_4__c', streetLine4);
            addField(dataList, 'Street 5', 'Street_5__c', streetLine5);
            
            // City / Postal Code: sourced from BillingAddress, capped to SAP field length
            addField(dataList, 'City postal code*', 'City_postal_code__c', postalCodeValue);
            addField(dataList, 'City*', 'City__c', cityValue);
            addField(dataList, 'Country Key*', 'Country_Key__c', v(acc.Country_Key__c));
            addField(dataList, 'Region Code', 'Region_Code__c', v(acc.Region_Code__c));
            addField(dataList, 'Language*', 'Language__c', v(acc.Language__c));
            addField(dataList, 'First telephone no.: dialling code+', 'First_telephone_no_dialling_code__c', v(acc.First_Telephone_No__c));
            addField(dataList, 'First Mobile Telephone No.: Dialing*', 'First_Mobile_Telephone_No_Dialing__c', v(acc.First_mobile_telephone_no__c));
            addField(dataList, 'First fax no.: dialling code+number', 'First_fax_no_dialling_code_number__c', v(acc.First_fax_no_dialling_code_number__c));
            addField(dataList, 'E-Mail Address*', 'E_Mail_Address__c', v(acc.Email__c));
            
            addField(dataList, 'Account Number of Vendor or Creditor', 'Account_Number_of_Vendor_or_Creditor__c', v(acc.Account_Number_of_Vendor__c));
            addField(dataList, 'Company ID of Trading Partner', 'Company_ID_of_Trading_Partner__c', v(acc.Company_ID_of_Trading_Partner__c));
            addField(dataList, 'Nielsen ID', 'Nielsen_ID__c', v(acc.Nielsen_ID__c));
            addField(dataList, 'Customer classification*', 'Customer_classification__c', v(acc.Customer_classification__c));
            addField(dataList, 'Industry key*', 'Industry_key__c', v(acc.Industry_Key__c));
            addField(dataList, 'Industry Code 1*', 'Industry_Code_1__c', v(acc.Industry_Code_1__c));
            addField(dataList, 'Contact Person*', 'Contact_Person__c', v(acc.Contact_Person__c));
            
            addField(dataList, 'Reconciliation Account in General Ledger*', 'Reconciliation_Account_in_General_Ledger__c', v(acc.Reconciliation_Account_GL__c));
            addField(dataList, 'Key for sorting according to assignment numbers', 'Key_for_sorting__c', v(acc.Key_for_sorting__c));
            addField(dataList, 'Previous Master Record Number', 'Previous_Master_Record_Number__c', v(acc.Previous_Master_Record_Number__c));
            addField(dataList, 'Terms of Payment Key*', 'Terms_of_Payment_Key__c', v(acc.Terms_Of_Payment_Key__c));
            addField(dataList, 'List of the Payment Methods to be Considered', 'List_of_the_Payment_Methods__c', v(acc.List_of_the_Payment_Methods__c));
            addField(dataList, 'Short Key for a House Bank', 'Short_Key_for_a_House_Bank__c', v(acc.Short_Key_for_a_House_Bank__c));
            addField(dataList, 'Dunning Procedure', 'Dunning_Procedure__c', v(acc.Dunning_Procedure__c));
            
            addField(dataList, 'Sales district*', 'Sales_district__c', v(acc.Sales_District__c));
            addField(dataList, 'Sales Office*', 'Sales_Office__c', v(acc.Sales_Office__c));
            addField(dataList, 'Customer group*', 'Customer_group__c', v(acc.Customer_Group__c));
            addField(dataList, 'Currency*', 'Currency__c', v(acc.Currency__c));
            addField(dataList, 'Exchange Rate Type', 'Exchange_Rate_Type__c', v(acc.Exchange_Rate_Type__c));
            addField(dataList, 'Customer Pricing Procedure', 'Pricing_procedure_assigned_to_customer__c', v(acc.Pricing_Procedure_Assigned__c));
            addField(dataList, 'Customer Statistics Group', 'Customer_Statistics_Group__c', v(acc.Customer_Statistics_Group__c));
            addField(dataList, 'Delivery Priority*', 'Delivery_Priority__c', v(acc.Delivery_Priority__c));
            addField(dataList, 'Shipping Conditions', 'Shipping_Conditions__c', v(acc.Shipping_Conditions__c));
            addField(dataList, 'Delivering Plant (Own or External)*', 'Delivering_Plant_Own_or_External__c', v(acc.Branch_Code__c));
            addField(dataList, 'Incoterms (Part 1)', 'Incoterms_Part_1__c', v(acc.Incoterms_Part_1__c));
            addField(dataList, 'Incoterms (Part 2)', 'Incoterms_Part_2__c', v(acc.Incoterms_Part_2__c));
            addField(dataList, 'Account assignment group for this customer*', 'Account_assignment_group_for_customer__c', v(acc.Account_Assignment_Group__c));
            addField(dataList, 'Tax classification*', 'Tax_classification__c', v(acc.Tax_Classification__c));
            
            addField(dataList, 'Employee Code Level 1', 'Employee_Code_1__c', v(acc.Employee_Code_Level_1__c));
            addField(dataList, 'Employee Code Level 2', 'Employee_Code_2__c', v(acc.Employee_Code_Level_2__c));
            addField(dataList, 'Employee Code Level 3', 'Employee_Code_3__c', v(acc.Employee_Code_Level_3__c));
            addField(dataList, 'Employee Code Level 4', 'Employee_Code_4__c', v(acc.Employee_Code_Level_4__c));
            addField(dataList, 'Employee Code Level 5', 'Employee_Code_5__c', v(acc.Employee_Code_Level_5__c));
            addField(dataList, 'Employee Code Level 6', 'Employee_Code_6__c', v(acc.Employee_Code_Level_6__c));
           // if(acc.Country__c == 'INDIA'){
                // --- Previously queried but missing from PDF output - now added ---
                addField(dataList, 'Registration Number', 'Registration_Number__c', regNo);
                addField(dataList, 'Aadhaar Card Number', 'Aadhaar_card_Number__c', aadhaarNo);
                addField(dataList, 'PAN Card Number', 'PAN_Card_Number__c', panNo);
                addField(dataList, 'Voter Card Number', 'Voter_Card_Number__c', voterNo);
                addField(dataList, 'Driving Licence Number', 'Driving_Licence_number__c', dlNo);
                addField(dataList, 'GST Number', 'GST_Number__c', gstNo);
                addField(dataList, 'Doctor Letter Number', 'Doctor_Letter_Number__c', doctorLetterNo);
            	addField(dataList, 'GSTN / Pan Card /Medical Registration No', 'Medical_Registration_No__c', medicalRegNo);
            //}

            // Morocco-only fields (isFieldVisible() keeps these hidden for every
            // other country via MA_FIELD_SET). Deliberately placed directly
            // above VAT Document Number per the MA mapping sheet.
            addField(dataList, 'Tax Identification Number (IF)', 'Tax_Identification_Number_IF__c', taxIdentificationNumberIF);
            addField(dataList, 'ICE Number', 'ICE_Number__c', iceNumber);
            addField(dataList, 'Commercial Registration (RC)', 'Commercial_Registration_RC__c', commercialRegistrationNo);
            addField(dataList, 'Business License (Patente)', 'Business_License_Patente__c', businessLicenseNo);
            
            // Moved in from outside the try/catch (see note below) so it goes through
            // the same country filter and the same error handling as everything else.
            addField(dataList, 'VAT Document Number', 'VAT_Document_Number__c', vatdocno);
            
        } catch (Exception e) {
            dataList.clear();
            dataList.add(new DataWrapper('Error', 'Failed to load Account data.'));
        }
        
        return dataList;
    }
    
    public class DataWrapper {
        public String field { get; set; }
        public String value { get; set; }
        
        public DataWrapper(String field, String value) {
            this.field = field;
            this.value = value;
        }
    } 
}
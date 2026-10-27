//LEAD PDF CONTROLLER 

public class LeadPdfController {   
    public Id RecordId {get;set;}
	public String pageLanguage { get; set; }
    public String initiatedBy { get; set; }
    public String signature { get; set; }
    public String aadhaarNo { get; set; }
    public String regNo { get; set; }
    public String panNo { get; set; }
    public String gstNo { get; set; }
    public String voterNo { get; set; }
    public String dlNo { get; set; }
    public LeadPdfController(){
        string  RecordId  = ApexPages.currentPage().getParameters().get('id'); 
        Lead__c LeadMap = [select Id,Name,Email__c, Billing_Street__c,Voter_Card_Number__c,Registration_Number__c,
                           PAN_Card_Number__c,GST_Number__c,Driving_Licence_number__c, Region__c, Sales_District__c,
                           Aadhaar_card_Number__c, Sales_Office__c, Search_Term_1__c, Search_Term_2__c, City_Postal_Code__c, 
                           Billing_city__c,Country__c,Sales_District_Code__c,Sales_Officer_Code__c,Plant_Code__c,Region_Code__c,
                           RSM_Email__c,Employee_Code__c,Billing_state__c,Mobile__c, Name_1__c, Name_2__c, Street_1__c, Street_2__c, 
                           Street_3__c, Street_4__c, SAP_City__c, Country_Key__c, Region_State_Province_County__c, 
                           First_telephone_no_dialling_code__c, First_Mobile_Telephone_No_Dialing__c, 
                           First_fax_no_dialling_code_number__c, E_Mail_Address__c,Number_of_an_SD_business_partner_Z2_RB__c,
                           Number_of_an_SD_business_partner_Z1_ZS__c,Language__c from Lead__c where Id =:RecordId];       
        initiatedBy = 'India Admin';
        signature = ''; // Static blank for now
     
        // First priority: explicit override from page param
        String langParam = ApexPages.currentPage().getParameters().get('lang');
        if (!String.isBlank(langParam)) {
            pageLanguage = langParam;
            
        }
        else{
            // Second priority: Lead.Language__c
            if (RecordId != null) {
                pageLanguage = String.isNotBlank(LeadMap.Language__c) ? LeadMap.Language__c : 'en_US';
            } else {
                // Fallback
                pageLanguage = 'en_US';
            }
        }
        if (String.isNotBlank(leadmap.Aadhaar_card_Number__c)) {
            aadhaarNo = leadmap.Aadhaar_card_Number__c;
        }
        
        if (String.isNotBlank(leadmap.Registration_Number__c)) {
            regNo = leadmap.Registration_Number__c;
        }
        
        if (String.isNotBlank(leadmap.PAN_Card_Number__c)) {
            panNo = leadmap.PAN_Card_Number__c;
        }
        
        if (String.isNotBlank(leadmap.GST_Number__c)) {
            gstNo = leadmap.GST_Number__c;
        }
        
        if (String.isNotBlank(leadmap.Voter_Card_Number__c)) {
            voterNo = leadmap.Voter_Card_Number__c;
        }
        
        if (String.isNotBlank(leadmap.Driving_Licence_number__c)) {
            dlNo = leadmap.Driving_Licence_number__c;
        }
    }
    
    public List<DataWrapper> getPdfData() {
        try {
            RecordId  = ApexPages.currentPage().getParameters().get('id'); 
            List<DataWrapper> dataList = new List<DataWrapper>();
            Lead__c LeadMap = [select Id,Name,Email__c,First_Name__c,Last_Name__c, Billing_Street__c,Lead_1_Hierarchy__c,
                               Lead_2_Hirarchy__c,Lead_3_Hierarchy__c,Voter_Card_Number__c,Registration_Number__c,
                               PAN_Card_Number__c,GST_Number__c,Driving_Licence_number__c, Region__c, Sales_District__c,
                               Aadhaar_card_Number__c, Sales_Office__c, Search_Term_1__c, Search_Term_2__c, City_Postal_Code__c, 
                               Billing_city__c,Country__c,Sales_District_Code__c,Sales_Officer_Code__c,Plant_Code__c,Region_Code__c,
                               RSM_Email__c,Employee_Code__c,Billing_state__c,Mobile__c, Name_1__c, Name_2__c, Street_1__c, 
                               Street_2__c, Street_3__c, Street_4__c, SAP_City__c, Country_Key__c, Region_State_Province_County__c, 
                               First_telephone_no_dialling_code__c, First_Mobile_Telephone_No_Dialing__c, First_fax_no_dialling_code_number__c, 
                               E_Mail_Address__c,Number_of_an_SD_business_partner_Z2_RB__c,
                               Number_of_an_SD_business_partner_Z1_ZS__c from Lead__c where Id =:RecordId];       
            //Lead__c LeadMap = Database.query('Select Id,' +queryfields+ ' from Lead__c where Id =:RecordId'); 
            System.debug('Lead Map'+JSON.serialize(LeadMap));
            string LeadCountry = LeadMap.Country__c;
            
            New_Customer_SAP_Code_PDF__c NCSCP = New_Customer_SAP_Code_PDF__c.getInstance(LeadCountry);
            
            /*            for(String str : queryfields.split(',')){
String fieldLabel = str.remove('__c').replace('_', ' ');
Object fieldValue = LeadMap.get(str.trim());
dataList.add(new DataWrapper(fieldLabel, fieldValue != null ? fieldValue.toString() : ''));
}*/
            // all Extra fields =======
            dataList.add(new DataWrapper('Customer Account Number', NCSCP.Customer_Account_Group__c));
            dataList.add(new DataWrapper('Company Code*', NCSCP.Company_Code__c));
            dataList.add(new DataWrapper('Sales Organization*', NCSCP.Sales_Organization__c));
            dataList.add(new DataWrapper('Distribution Channel*', NCSCP.Distribution_Channel__c));
            dataList.add(new DataWrapper('Division*', NCSCP.Division__c));
            dataList.add(new DataWrapper('Customer Account Group*', NCSCP.Customer_Account_Group__c));
            dataList.add(new DataWrapper('Title text*', ''));
            dataList.add(new DataWrapper('Name 1*', LeadMap.Name_1__c));
            dataList.add(new DataWrapper('Name 2', LeadMap.Name_2__c));
            dataList.add(new DataWrapper('Search Term 1', LeadMap.Search_Term_1__c));
            dataList.add(new DataWrapper('Search Term 2', LeadMap.Search_Term_2__c));
            dataList.add(new DataWrapper('Street 1*', LeadMap.Street_1__c));
            dataList.add(new DataWrapper('Street 2', LeadMap.Street_2__c));
            dataList.add(new DataWrapper('Street 3', LeadMap.Street_3__c));
            dataList.add(new DataWrapper('Street 4', LeadMap.Street_4__c));
            dataList.add(new DataWrapper('City postal code*', LeadMap.City_Postal_Code__c));
            dataList.add(new DataWrapper('City*', LeadMap.Billing_city__c));
            dataList.add(new DataWrapper('Country Key*', NCSCP.Country_Key__c));
            //dataList.add(new DataWrapper('RSM Email', leadmap.RSM_Email__c));
            dataList.add(new DataWrapper('Region Code', leadmap.Region_Code__c));
            //dataList.add(new DataWrapper('Employee Code', leadmap.Employee_Code__c));
            // dataList.add(new DataWrapper('Region (State, Province, County)*', LeadMap.Region__c));
            dataList.add(new DataWrapper('First telephone no.: dialling code+', LeadMap.First_telephone_no_dialling_code__c));
            dataList.add(new DataWrapper('First Mobile Telephone No.: Dialing*', LeadMap.Mobile__c));
            dataList.add(new DataWrapper('First fax no.: dialling code+number', LeadMap.First_fax_no_dialling_code_number__c));
            dataList.add(new DataWrapper('E-Mail Address*', LeadMap.E_Mail_Address__c));
            dataList.add(new DataWrapper('Account Number of Vendor or Creditor', ''));
            dataList.add(new DataWrapper('Company ID of Trading Partner', ''));
            dataList.add(new DataWrapper('Nielsen ID', NCSCP.Nielsen_ID__c));
            dataList.add(new DataWrapper('Customer classification*', NCSCP.Customer_Classification__c));
            dataList.add(new DataWrapper('Industry key*', NCSCP.Industry_Key__c));
            dataList.add(new DataWrapper('Industry Code 1*', NCSCP.Industry_Code_1__c));
            dataList.add(new DataWrapper('Contact Person*', LeadMap.First_Name__c +' '+LeadMap.Last_Name__c));
            dataList.add(new DataWrapper('Reconciliation Account in General Ledger*', '2050020'));
            dataList.add(new DataWrapper('Key for sorting according to assignment numbers', '031'));
            dataList.add(new DataWrapper('Previous Master Record Number', ''));
            dataList.add(new DataWrapper('Terms of Payment Key*', NCSCP.Terms_of_Payment_Key__c));
            dataList.add(new DataWrapper('List of the Payment Methods to be Considered', ''));
            dataList.add(new DataWrapper('Short Key for a House Bank', ''));
            dataList.add(new DataWrapper('Dunning Procedure', ''));
            dataList.add(new DataWrapper('Sales district*', LeadMap.Sales_District_Code__c));
            dataList.add(new DataWrapper('Sales Office*', LeadMap.Sales_Officer_Code__c));
            dataList.add(new DataWrapper('Customer group*', NCSCP.Customer_group__c));
            dataList.add(new DataWrapper('Currency*', NCSCP.Currency__c));
            dataList.add(new DataWrapper('Exchange Rate Type', ''));
            dataList.add(new DataWrapper('Pricing procedure assigned to this customer*', NCSCP.Pricing_procedure_assigned_to_this_custo__c));
            dataList.add(new DataWrapper('Customer Statistics Group', ''));
            dataList.add(new DataWrapper('Delivery Priority*', NCSCP.Delivery_Priority__c));
            dataList.add(new DataWrapper('Shipping Conditions',''));
            dataList.add(new DataWrapper('Delivering Plant (Own or External)*', LeadMap.Plant_Code__c));
            dataList.add(new DataWrapper('Incoterms (Part 1)',''));
            dataList.add(new DataWrapper('Incoterms (Part 2)',''));
            dataList.add(new DataWrapper('Terms of Payment Key*', NCSCP.Terms_of_Payment_Key__c));
            dataList.add(new DataWrapper('Account assignment group for this customer*', NCSCP.Account_assignment_group_for_this_custom__c));
            dataList.add(new DataWrapper('Tax classification*', '1'));
            //dataList.add(new DataWrapper('Number of an SD business partner (Z1) ZSM*', ''));
            //dataList.add(new DataWrapper('Number of an SD business partner (Z2) RBM/RSM*', ''));
            dataList.add(new DataWrapper('Number of an SD business partner (M1) Div 1 to 2 Mgr.*', LeadMap.Lead_2_Hirarchy__c));
            dataList.add(new DataWrapper('Number of an SD business partner (M2) Div 3 to 4 Mgr.*', LeadMap.Lead_2_Hirarchy__c));
            dataList.add(new DataWrapper('Number of an SD business partner (M5) Div 5 Mgr.*', LeadMap.Lead_2_Hirarchy__c));
            dataList.add(new DataWrapper('Number of an SD business partner (D1) Div 1 Emp.*', LeadMap.Lead_1_Hierarchy__c));
            dataList.add(new DataWrapper('Number of an SD business partner (D2) Div 2 Emp.*', LeadMap.Lead_1_Hierarchy__c));
            dataList.add(new DataWrapper('Number of an SD business partner (D3) Div 3 Emp.*', LeadMap.Lead_1_Hierarchy__c));
            dataList.add(new DataWrapper('Number of an SD business partner (D4) Div 4 Emp.*', LeadMap.Lead_1_Hierarchy__c));
            dataList.add(new DataWrapper('Number of an SD business partner (D5) Div 5 Emp.*',LeadMap.Lead_1_Hierarchy__c));
            dataList.add(new DataWrapper('Number of an SD business partner (Z3) ASM*', '0'));
            dataList.add(new DataWrapper('Number of an SD business partner (Z3) Refrective Manager*', LeadMap.Lead_3_Hierarchy__c));
            dataList.add(new DataWrapper('Number of an SD business partner (Z4) Executive*', '0'));
            dataList.add(new DataWrapper('Number of an SD business partner (Z8) Export Sales Support*','0'));
            dataList.add(new DataWrapper('Reconciliation Account in General Ledger*', NCSCP.Reconciliation_Account_in_General_Ledger__c));
            dataList.add(new DataWrapper('Key for sorting according to assignment numbers', NCSCP.Key_for_sorting_according_to_assignment__c));
            dataList.add(new DataWrapper('Pricing procedure assigned to this customer*', NCSCP.Pricing_procedure_assigned_to_this_custo__c));
          
           
            return dataList;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating Sample Request: ' + e.getLineNumber() +'Message:'+ e.getMessage());
        }
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
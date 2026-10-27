public class Constants {
    
    public static final String ACCOUNT_B2B2C_RECORDTYPEDEVELOPERNAME = 'Secondary_User';  //Name is Secondary User for B2B2C Account Recordtype
    public static final String ACCOUNT_DOM_DISTRIBUTOR_RECORDTYPEDEVELOPERNAME = 'Distributor';
    public static final String ACCOUNT_DOM_DOCTOR_RECORDTYPEDEVELOPERNAME = 'Doctor_D';
    public static final String ACCOUNT_DOM_DISTRIBUTOR_RECORDTYPEID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(ACCOUNT_DOM_DISTRIBUTOR_RECORDTYPEDEVELOPERNAME).getRecordTypeId();
    public static final String ACCOUNT_DOM_DOCTOR_RECORDTYPEID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(ACCOUNT_DOM_DOCTOR_RECORDTYPEDEVELOPERNAME).getRecordTypeId();
    public static final String ACCOUNT_TURKEY_DISTRIBUTOR_RECORDTYPEDEVELOPERNAME = 'Distributor_T';
    public static final String ACCOUNT_TURKEY_DOCTOR_RECORDTYPEDEVELOPERNAME = 'Doctor_T';
    public static final String ACCOUNT_TURKEY_DISTRIBUTOR_RECORDTYPEID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(ACCOUNT_TURKEY_DISTRIBUTOR_RECORDTYPEDEVELOPERNAME).getRecordTypeId();
    public static final String ACCOUNT_TURKEY_DOCTOR_RECORDTYPEID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(ACCOUNT_TURKEY_DOCTOR_RECORDTYPEDEVELOPERNAME).getRecordTypeId();
    public static final String ACCOUNT_OPTHALMICVISION_RECORDTYPE_DEVELOPERNAME = 'Ophthalmic_Vision';
    public static final String ACCOUNT_ORTHODERMAL_RECORDTYPE_DEVELOPERNAME = 'Ortho_Dermal';
    public static final String ACCOUNT_OPTHALMICVISION_RECORDTYPEID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(ACCOUNT_OPTHALMICVISION_RECORDTYPE_DEVELOPERNAME).getRecordTypeId();
    public static final String ACCOUNT_ORTHODERMAL_RECORDTYPEID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(ACCOUNT_ORTHODERMAL_RECORDTYPE_DEVELOPERNAME).getRecordTypeId();
    public static final String ACCOUNT_INDIA_COMPANYCODE = '1000';
    public static final String ACCOUNT_INDIA_COUNTRYKEY = 'IN';
    public static final String ACCOUNT_STATUS_ACTIVATED = 'Activated';
    public static final String ACCOUNT_SUBSTATUS_SUBMITTEDTOAPPROVER1 = 'Submitted To Approver 1';
    public static final String ACCOUNT_SUBSTATUS_SUBMITTEDTOAPPROVER2 = 'Submitted To Approver 2';
    public static final String ACCOUNT_SUBSTATUS_SUBMITTEDTOBRANCHTEAM = 'Submitted To Branch Team';
    public static final String ACCOUNT_SUBSTATUS_APPROVEDBYADMIN ='Approved by Admin';
    public static final String ACCOUNT_SUBSTATUS_PENDINGFORADMIN ='Pending For Admin';
    public static final String ACCOUNT_TRIGGER_BRANCHFIELDMANDATORYCUSTOMEXCEPTIONMESSAGE = 'Branch Field is mandatory to fill before record is approved';
    public static final String ACCOUNT_TRIGGER_ACCOUNTTEAMMANDATORYCUSTOMEXCEPTIONMESSAGE = 'Account Team record is mandatory to create before record is approved';
    public static final String ACCOUNT_TRIGGER_TURKEY_ACCOUNTTEAMMANDATORYCUSTOMEXCEPTIONMESSAGE = 'Hesap onaylanmadan önce Hesap Ekibi kaydı gereklidir';
    public static final String ACCOUNT_TRIGGER_INT_ADMINTOFILLMANDATORYFIELDSCUSTOMEXCEPTIONMESSAGE = 'Please fill in the mandate fields under CRM Details Section';
    public static final String ACCOUNT_INT_ADMINROLENAME = 'International_Admin';
    public static final String ACCOUNT_TURKEY_ADMINROLENAME = 'Turkey_Admin';
    public static final String ACCOUNT_DOM_ADMINROLENAME = 'Domestic_Admin';
    public static final String USER_USERTYPE_DOMESTIC = 'Domestic';   //Usertype picklist value on User object
    public static final String USER_USERTYPE_TURKEY = 'Turkey';
    public static final String USER_USERTYPE_INTERNATIONAL = 'International';
    
    
    public static final Map<Integer,String> MONTH_VALUE_MAP = new Map<Integer,String>{9 => 'Jan',
        10 => 'Feb',
        11 => 'Mar',
        0 => 'Apr',
        1 => 'May',
        2 => 'Jun',
        3 => 'Jul',
        4 => 'Aug',
        5 => 'Sep',
        6 => 'Oct',
        7 => 'Nov',
        8 => 'Dec'};
    
    public static final String FISCALYEAR_STARTMONTH = 'Apr';                                                                                       
    
    public static final String FISCALYEAR_ENDMONTH = 'Mar'; 
    
    
    public static final String CURRENT_FISCALYEAR = [SELECT FiscalYearSettings.Name FROM Period WHERE Type = 'Year' AND StartDate <= TODAY AND EndDate >= TODAY].FiscalYearSettings.Name;
    
    public static final List<Schema.PicklistEntry> EVENT_STATUS = Event.Status__c.getDescribe().getPicklistValues();
    
    public static final List<String> EVENT_STATUS_VALUES;
    
    public static final String EVENT_STATUS_APPROVED = 'Approved';
    
    public static final String EVENT_STATUS_SENTFORAPPROVAL = 'Sent for Approval';
    
    public static final String MONTHLYAOP_INTERNATIONAL_RECORDTYPE_DEVELOPERNAME = 'International';
    public static final String MONTHLYAOP_DOMESTIC_RECORDTYPE_DEVELOPERNAME = 'Domestic';
    public static final String MONTHLYAOP_TURKEY_RECORDTYPE_DEVELOPERNAME = 'Turkey';
    public static final String DEMOGRAPHIC_DOMESTIC = 'Domestic';
    public static final String DEMOGRAPHIC_INTERNATIONAL = 'International';
    public static final String DEMOGRAPHIC_TURKEY = 'Turkey';
    public static final String CE_STATUS_APPROVED = 'Approved';
    

    static {
        List<String> tempList =  new List<String>();
        for(Schema.PicklistEntry ple : EVENT_STATUS){
            if(ple.isActive()){
                tempList.add(ple.getValue());
            }    
        }
        EVENT_STATUS_VALUES = tempList; // now it contains 'Active' Event's Status__c picklist values.
    }   
    
    
    
    
    //public static final String SELECT_ONE = Label.Select_One;
}
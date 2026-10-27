/**=====================================================================
* 
* Name: LeadFormPageController 
* Description: This controller will take care of  when the lead form page load than it will catch all the lead information and insert the lead data into the system
* Created Date: 28-08-2022
* Created By: (Plus91labs)-Pankaj Sen
* 
* Date Modified     Description of the update
*        
* Last modified By : Gyadeen Ahirwar 
* Date Modified : 08-04-2024
=====================================================================*/

public  class LeadFormPageController {
    public string recordId {get;set;}
    public List<SelectOption> leadOptions { get; set; }
    public String selectedLeadId { get; set; }
    public string cmpName{get;set;}
    public string cmpDate{get;set;}
    public string publicFileUrl{get;set;}
    public  List<String> productList{get;set;}
    public list<String> productDataList{get;set;} // Added by gyadeen
    public List<SelectOption> memberTypeOptions { get; set; } // Added by gyadeen 
    public String selectedMemberType { get; set; } // Define the selectedMemberType property
    public Boolean hideLeadProduct {get;set;}
    
    public LeadFormPageController() {
        recordId  = ApexPages.currentPage().getParameters().get('id');//Add
        leadOptions = new List<SelectOption>();
        List<Lead__c> leads = leaddata('', recordId);//Add
        
        for (Lead__c lead : leads) {
            leadOptions.add(new SelectOption(lead.Id, lead.Name));
        }
        
        
        // Initialize memberTypeOptions and populate it dynamically from picklist values
        memberTypeOptions = new List<SelectOption>(); // Added by gyadeen
        
        // Query the picklist values for the Member Type field on the Campaign Member object
        Schema.DescribeFieldResult fieldResult = Campaign_Member__c.Member_Type__c.getDescribe(); // Added by gyadeen
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues(); // Added by gyadeen
        
        // Add picklist values to the memberTypeOptions list
        //memberTypeOptions.add(new SelectOption('', '--Select--')); // Add a default option // Added by gyadeen
        for(Schema.PicklistEntry entry : picklistValues) {
            memberTypeOptions.add(new SelectOption(entry.getValue(), entry.getLabel())); // Added by gyadeen
        }
        Integer i=1;
        productList=new List<String>();
        recordId  = ApexPages.currentPage().getParameters().get('id');
        System.debug('Record Id'+recordId);
        productDataList=new List<String>();
        Campaign__c cmp=[SELECT Id,Name,Status__c,Start_Date__c,Public_File_Url__c,Target__r.Name,Focus_Product__c, LeadWithProduct_Hide__c from Campaign__c where Id=:recordId];
        hideLeadProduct = cmp.LeadWithProduct_Hide__c;
        if(cmp.Public_File_Url__c != null){
            publicFileUrl = cmp.Public_File_Url__c;
        }
        if(cmp.Focus_Product__c.contains(';')) {
            productList=cmp.Focus_Product__c.split(';');
            for(string prod:productList) {
                productDataList.add(prod);
            }
        }else {
            productDataList.add(cmp.Focus_Product__c);
            //  productdata=cmp.Focus_Product__c;
        }
        System.debug('Product List'+productDataList);
        cmpName=cmp.Name;
        cmpDate=string.valueOf(cmp.Start_Date__c);
        
    }
    
    /*This method will take of when the lead insert into the system*/
    @RemoteAction
    public static string insertLeadData( string membertype ,string phoneData,string billingState,string firstName, string lastName, string email, string Company,string billingCity,string billingcountry,string billingStreet,string billingCode,string recordId,List<String> productData,string selLeadId) {
        string message;
        string product='';
        system.debug('membertype'+membertype);
        try{
            if(productData.size()>0) {
                product='';
                for(string pro:productData) {
                    product=product+pro+';';
                }
            }
            System.debug('Product data'+product);  
            List<Campaign_Member__c> camMemList=new List<Campaign_Member__c>();
            Campaign__c cmp=[SELECT Id,LeadWithProduct_Hide__c,Current_Login_User__c,CreatedById,Name,Status__c,Executer__c,Start_Date__c,Campaign_stage__c,Target__r.Name,Focus_Product__c from Campaign__c where Id=:recordId];
            if(string.isNotBlank(membertype) && string.isNotBlank(phoneData) && string.isNotBlank(billingState) && string.isNotBlank(firstName) && string.isNotBlank(lastName)   && string.isNotBlank(billingCity) && string.isNotBlank(billingcountry) && string.isNotBlank(recordId)){
                Campaign_Member__c camMem=new Campaign_Member__c();
                camMem.Campaign1__c=recordId;
                camMem.RecordTypeId= Schema.SObjectType.Campaign_Member__c.getRecordTypeInfosByName().get('New member').getRecordTypeId();
                camMem.Campaign_Product__c=product.removeEnd(';');
                camMem.Lead_First_Name__c=firstName;
                camMem.Lead_Last_Name__c=lastName;
                camMem.Lead_Email__c=email;
                camMem.Lead_Hospital_Clinic_Name__c=Company;
                camMem.Lead_Street__c=billingStreet;
                camMem.Lead_City__c=billingCity;
                camMem.Lead_Zip_Postal_Code__c=billingCode;
                camMem.Lead_State_Province__c=billingState;
                camMem.Lead_Country__c=billingcountry;
                camMem.Lead_Mobile_Number__c=phoneData;
                camMem.Member_Type__c = membertype;
                if(selLeadId!='' && selLeadId!=null && selLeadId!='undefined') {
                    camMem.Lead1__c= selLeadId;
                }
                camMemList.add(camMem); 
            }
            System.debug('Campaign List'+camMemList);
            
            // Query Beat_Plan__c records where OwnerId is the logged-in user
            system.debug('currentuser'+cmp.Current_Login_User__c);
            List<Beat_Plan__c> beatPlans = [
                SELECT Id, Name, Beat_Date__c, Login_Time__c
                FROM Beat_Plan__c
                WHERE Beat_Date__c = :System.today() 
                AND OwnerId = :cmp.Executer__c
                AND Login_Time__c != null
                LIMIT 1
            ];
            
            system.debug('beatPlans: ' + beatPlans);
            
            // Check if there are any beat plans for today
            if (beatPlans.size() > 0 ) {
                // If beat plans are available, return activity as true
                
            }else if(cmp.LeadWithProduct_Hide__c == true){
               
            }else{
                message='No data';
                return message;
            }
            if(!camMemList.isEmpty()) {
                insert camMemList;
                message='success';
            }
            
        }catch(Exception e) {
            message='Invalid';
            System.debug('Error message'+e.getMessage());
        }
        return message;
    }
    
    @RemoteAction
    public static List<Lead__c> leaddata(String leadname, string recordId) {//add the paramteters
        //List<Lead__c> leaddatalist=    LeadPageController.leaddata(leadname);
        
        Campaign__c Campaign1 = [SELECT Id, User_s_Country__c, name FROM Campaign__c WHERE Id = :recordId];//add changes
        
        List<Lead__c> leaddatalist = [
            SELECT Id, Lead_Stage__c, Name 
            FROM Lead__c 
            WHERE Name LIKE :('%' + leadname + '%')
            AND Lead_Stage__c != 'Won' 
            AND Lead_Stage__c != 'Lost' 
            AND Lead_Stage__c != 'Unqualified'
            AND Lead_Closed__c !=true
            AND Country__c = :Campaign1.User_s_Country__c
        ];
        System.debug('leaddatalist: ' + leaddatalist);
        return leaddatalist;
    }
    public void selectLead() {
        // Logic to handle the selected lead
        System.debug('Selected Lead Id: ' + selectedLeadId);
    }
    
    @RemoteAction
    public static List<String> getCountries() {
        Set<String> countries = new Set<String>();
        for(Country__c c : [
            SELECT Country__c FROM Country__c WHERE Country__c != null
        ]) {
            countries.add(c.Country__c);
        }
        
        // Convert to list and sort A-Z
        List<String> countryList = new List<String>(countries);
        countryList.sort();
        return countryList;
    }
    
    @RemoteAction
    public static List<String> getStates(String country) {
        Set<String> states = new Set<String>();
        for(Country__c c : [
            SELECT State__c FROM Country__c 
            WHERE Country__c = :country AND State__c != null
        ]) {
            states.add(c.State__c);
        }
        
        List<String> stateList = new List<String>(states);
        stateList.sort();
        return stateList;
    }
    
    @RemoteAction
    public static List<String> getCities(String state) {
        Set<String> cities = new Set<String>();
        for(Country__c c : [
            SELECT CITY__c FROM Country__c 
            WHERE State__c = :state AND CITY__c != null
        ]) {
            cities.add(c.CITY__c);
        }
        
        List<String> cityList = new List<String>(cities);
        cityList.sort();
        return cityList;
    }
    
    
    @RemoteAction
    public static Lead__c getLeadDetails(String leadId) {
        //return LeadPageController.getLeadDetails(leadId);
        
        return [SELECT Id, First_Name__c, Last_Name__c, Email__c, Mobile__c, Company__c, Billing_Street__c,Billing_City__c,Product__c, Billing_state__c,Billing_code__c, Country__c
                FROM Lead__c
                WHERE  Id = :leadId AND Lead_Closed__c !=true AND Lead_Stage__c != 'Won' 
                AND Lead_Stage__c != 'Lost' 
                AND Lead_Stage__c != 'Unqualified' order by CreatedDate DESC
                LIMIT 1 ];
    }
}
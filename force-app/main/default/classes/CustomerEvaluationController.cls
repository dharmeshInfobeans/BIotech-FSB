public class CustomerEvaluationController {
    
    @AuraEnabled
    public static Result getLastCE(String accId) {
        Result resultObj = new Result();
        resultObj.yearPicklistValues = getYear();
        resultObj.statusPicklistValues = getStatus();
        resultObj.languagePicklist = getLanguagePicklist();
        Profile p = [select id,name from Profile where id=:UserInfo.getProfileId()];
        resultObj.isAdmin = p.name == 'System Administrator';
        resultObj.lastCE = new Customer_Evaluation__c();
        
        Account acc = [SELECT name,Owner.Name,recordType.DeveloperName,recordType.Name,BillingStreet,BillingCountry,BillingState,Street_2__c FROM Account WHERE id = :accId];
        resultObj.acc = acc;
        resultObj.accountName = acc.name;
        if(acc.RecordType.DeveloperName == 'Doctor_D' || acc.RecordType.DeveloperName == 'Doctor_T' || acc.RecordType.DeveloperName == 'Columbia_Doctor' || acc.RecordType.DeveloperName == 'Brazil_Doctor' ){
            resultObj.recordType = 'Doctor_D_and_T';
        }else if(acc.RecordType.DeveloperName == 'Distributor' || acc.RecordType.DeveloperName == 'Distributor_T'){
            resultObj.recordType = 'Distributor_D';
        }else{
            resultObj.recordType = 'International';
        }
        String currentyear = System.today().year()+'';
        List<Customer_Evaluation__c> customerEvaluationList = [SELECT Id, IsDeleted, Name, RecordTypeId, 
                                                               No_of_Procedures_Cataract__c, No_of_Procedures_Glaucoma__c, 
                                                               No_of_Procedures_Pediatric__c, No_of_Procedures_Refractive__c, No_of_Procedures_Retina__c, 
                                                               Year__c, Last_Customer_Evaluation__c, Status__c, No_of_Working_Days__c, No_of_Doctors__c, 
                                                               No_of_Counselors__c, Account__c, Customer_Evaluation_Rating__c, Number_of_Time_Submitted__c, 
                                                               Annual_Turn_over_in_INR__c, No_of_Employees__c, No_of_Distribution_centers_Branch__c, Areas_covered__c, 
                                                               Number_of_Sales_Staff__c, Current_Distribution_Name_of_Companies__c, Number_of_Products_Handled_with_company__c, 
                                                               By_Tender_Business__c, By_Hospital_Supplies__c, Others__c, Annual_Turn_over_in_USD__c, 
                                                               How_much_would_be_the_annual_projection__c, Your_Retail_Shops__c, Name_the_competitors_in_your_Market__c, 
                                                               Year_of_Establishment__c, Population__c, Language_and_Currency__c, Age_ratio__c, GDP_in_USD__c, GDP_Per_capita_in_USD__c, 
                                                               Per_Capita_Health_Expenditure__c, No_of_Eye_surgeons__c, No_of_Eye_hospitals__c, No_of_Cataract_surgery_annum__c, 
                                                               Govt_Health_Policy_Tender_Facility__c, Common_Diseases__c, No_of_wholesalers__c, No_of_Pharmacies__c, 
                                                               Products_to_import__c, Value_of_imports_by_your_company__c, Do_you_have_any_Expert_Specific_Division__c, 
                                                               Are_you_handling_any_Ophthalmic_products__c, Ophthalmic_products_imported__c, Company_s_product_has_a_easy_recall__c, 
                                                               The_reasons_why_you_chose_our_Company__c, How_you_can_garner_extra_volumes__c, Do_You_Sell_products_inside_Palestine__c, 
                                                               Registration_Protocols__c, Maximum_number_of_distributors_MOH__c, Any_brands_of_your_company_registered__c 
                                                               FROM Customer_Evaluation__c
                                                               WHERE Account__c=:accId AND Year__c=:currentyear
                                                              ];
        system.debug('Last CE : '+customerEvaluationList);
        if(customerEvaluationList.size()>0){
            resultObj.lastCE = customerEvaluationList[0];
        }else{
            resultObj.lastCE.recordTypeId = Schema.SObjectType.Customer_Evaluation__c.getRecordTypeInfosByDeveloperName().get(resultObj.recordType).getRecordTypeId();
        }
        /*
resultObj.lastCEname = '';
for(Customer_Evaluation__c obj : [SELECT Name, No_of_Procedures_Cataract__c, No_of_Procedures_Glaucoma__c, No_of_Procedures_Pediatric__c,
No_of_Procedures_Refractive__c, No_of_Procedures_Retina__c, Year__c, Status__c, 
No_of_Working_Days__c, No_of_Doctors__c, No_of_Counselors__c,Customer_Evaluation_Rating__c 
FROM Customer_Evaluation__c WHERE Account__c=:accId ORDER BY CreatedDate DESC LIMIT 1]
){
system.debug('###=' + obj);
resultObj.lastCE = obj.clone(false);
resultObj.lastCEname = obj.Name;
}
*/
        system.debug('resultObj.lastCE : :'+resultObj.lastCE );
        if(resultObj.lastCE.Status__c == 'Pending Approval' ){
            resultObj.disableForm = true;
        }else{
            resultObj.disableForm = false;
        }
        resultObj.lastCE.Year__c = ''+System.today().year();
        system.debug('Last CE Status : '+resultObj.lastCE.Status__c);
        return resultObj;                                 
    }
    
    @AuraEnabled
    public static Map<string, object> getCEFormData(string accountId){
        Map<string, object> returnData = new Map<string, object>();
        Map<object, List<map<string, object>>> formDataMap = new Map<object, List<map<string, object>>>();
        Map<decimal,string> postionMap = new Map<Decimal, string>();
        Account acc = [SELECT name,Owner.Name,recordType.DeveloperName,recordType.Name,BillingStreet,BillingCountry,BillingState,Street_2__c FROM Account WHERE id = :accountId];
        system.debug('AccountId : '+acc);
        list<CE_Configuration__c> configList = [select id , name,API_Name__c,Section_Position__c,Record_Type__c,Data_type__c,Disabled__c,Required__c,DropDownValues__c,Field_label__c,Section__c from CE_Configuration__c where Record_Type__c =: acc.recordType.DeveloperName order by Position__c ASC];
        for(CE_Configuration__c ce : configList){
            map<string, object> formMap = new Map<string, object>();
            postionMap.put(ce.Section_Position__c,ce.Section__c);
            if(ce.API_Name__c == 'Account__c'){
                formMap.put('value',acc.Name);
            }else if(ce.API_Name__c == 'Year__c'){
                formMap.put('value',''+system.today().year());
            }else{
                formMap.put('value','');
            }
            formMap.put('disabled',ce.Disabled__c);
            formMap.put('required',ce.Required__c);
            formMap.put('name',ce.API_Name__c);
            formMap.put('type',ce.Data_type__c);
            formMap.put('label',ce.Field_label__c);
            if(ce.Data_type__c == 'Picklist' && ce.DropDownValues__c != null){
                List<Map<string, object>> pickList = new List<Map<string, object>>();
                for(string str : ce.DropDownValues__c.split(';')){
                    pickList.add(new Map<string, object>{'label'=>str,'value'=>str});
                }
                formMap.put('column',pickList);
            }
            if(formDataMap.containsKey(ce.Section_Position__c)){
                formDataMap.get(ce.Section_Position__c).add(formMap);
            }else{
                formDataMap.put(ce.Section_Position__c, new List<map<string, object>>{formMap});
            }
        }
        returnData.put('accountName',acc.name);
        returnData.put('form',formDataMap);
        returnData.put('sectionPosition',postionMap);
        returnData.put('currentYear',system.now().year());
        String currentyear = System.today().year()+'';
        String query = 'select '+getAllFields('Customer_Evaluation__c')+',Account__r.Name from Customer_Evaluation__c where Account__c=:accountId AND Year__c=:currentyear';
        List<Customer_Evaluation__c> customerEvaluationList = Database.query(query);
        Map<String, Object> fieldsToValue = new Map<String, Object>();
        for(Customer_Evaluation__c ceData : customerEvaluationList){
            fieldsToValue = ceData.getPopulatedFieldsAsMap();
        }
        
        if(fieldsToValue.size() == 0){
            returnData.put('disableForm',false);
            string recordType = '';
             
           if(acc.RecordType.DeveloperName == 'Doctor_D' || acc.RecordType.DeveloperName == 'Doctor_T' || acc.RecordType.DeveloperName == 'Columbia_Doctor' || acc.RecordType.DeveloperName == 'Brazil_Doctor'){
                recordType = 'Doctor_D_and_T';
            }else if(acc.RecordType.DeveloperName == 'Distributor' || acc.RecordType.DeveloperName == 'Distributor_T'){
                recordType = 'Distributor_D';
            }else if(acc.RecordType.DeveloperName=='International_Ortho'||acc.RecordType.DeveloperName=='Domestic_Ortho'){
                recordType = 'International_Ortho';
            } else if(acc.RecordType.DeveloperName=='International_Dermal'){
                recordType = 'International_Dermal';
                System.debug('record type name==>>'+acc.RecordType.DeveloperName);
            }else if(acc.RecordType.DeveloperName=='International_Ophthalmic_Vision'){
                recordType = 'International_Ophthalmic_Vision';
            }
            returnData.put('recordType', Schema.SObjectType.Customer_Evaluation__c.getRecordTypeInfosByDeveloperName().get(recordType).getRecordTypeId());
        }else{
            returnData.put('data', fieldsToValue);
            returnData.put('oldEecordId',customerEvaluationList[0].Id);
            if(fieldsToValue.get('Status__c') == 'Pending Approval' ){
                returnData.put('disableForm',true);
            }else{
                returnData.put('disableForm',false);
            }
        }
        
        return returnData;
    }
    
    
    @AuraEnabled
    public static Customer_Evaluation__c saveCustEvaluation( String custEvaluationJSON) {
        try{
            Customer_Evaluation__c custEvaluation = (Customer_Evaluation__c) JSON.deserialize(custEvaluationJSON, Customer_Evaluation__c.class);
            List<Account> accList = [SELECT Id,Approver_1__c,Approver_2__c FROM Account where id=:custEvaluation.Account__c];
            
            if(accList.size()>0){
                System.debug('accList[0].Approver_1__c::'+accList[0].Approver_1__c);
                System.debug('accList[0].Approver_2__c::'+accList[0].Approver_2__c);
                //    custEvaluation.Approver_1__c = accList[0].Approver_1__c;
                //    custEvaluation.Approver_2__c = accList[0].Approver_2__c; 
                
            }
            List<Customer_Evaluation__c> lastCE = [SELECT Id, Account__r.OwnerId
                                                   FROM Customer_Evaluation__c 
                                                   WHERE Account__c=:custEvaluation.Account__c AND Id !=: custEvaluation.Id
                                                   ORDER BY CreatedDate DESC LIMIT 1];
            System.debug('lastCE:: '+lastCE);
            if(lastCE.size()>0){
                custEvaluation.Last_Customer_Evaluation__c = lastCE[0].Id;
            }
            custEvaluation.Status__c = 'Draft';
            if(custEvaluation.Id ==null){
                Account a = new Account();
                a.last_CE_date__c = System.today();
                a.Id = custEvaluation.Account__c;
                System.debug('Account Owner:: '+custEvaluation.Account__r.OwnerId);
                update a;
            }
            System.debug('custEvaluation:: '+custEvaluation);
            
            custEvaluation =  CEUtilWS.insertCERecord(accList[0], custEvaluation);
            upsert custEvaluation;
            return custEvaluation; 
        }catch(DMLException e){
            throw new AuraHandledException(e.getDMLMessage(0));
        }catch(Exception e){
            System.debug('getMessage:::'+e.getMessage()+':::at Line No:::'+e.getLineNumber());
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public static List<String> getStatus() {
        List<String> options = new List<String>();
        Schema.DescribeFieldResult fieldResult = Customer_Evaluation__c.Status__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry f: ple) {
            // options.add(f.getLabel());
            options.add(f.getValue());
        }
        return options;
    }
    
    public static List<String> getYear() {
        List<String> options = new List<String>();
        Schema.DescribeFieldResult fieldResult = Customer_Evaluation__c.Year__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry f: ple) {
            //options.add(f.getLabel());
            options.add(f.getValue());
        }
        return options;
    }
    
    private static List<String> getLanguagePicklist(){
        List<String> options = new List<String>();
        Schema.DescribeFieldResult fieldResult = Customer_Evaluation__c.Language_and_Currency__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry f: ple) {
            options.add(f.getLabel());
        }
        return options;
    }
    
    public class Result{
        @AuraEnabled
        public boolean isAdmin;
        @AuraEnabled
        public boolean disableForm;
        @AuraEnabled
        public List<String> yearPicklistValues;
        @AuraEnabled
        public List<String> statusPicklistValues;
        @AuraEnabled
        public List<String> languagePicklist;
        @AuraEnabled
        public String accountName;
        @AuraEnabled
        public String lastCEname;
        @AuraEnabled
        public Customer_Evaluation__c lastCE;
        @AuraEnabled
        public Account acc;
        @AuraEnabled
        public String recordType;
        
    }
    
    public static string getAllFields(String objectAPIName){
        string returnString;
        try {
            System.debug('REQUEST : '+objectAPIName);
            list<string> apiNames = new List<string>();
            Map<String, Schema.SObjectField> objectFields = Schema.getGlobalDescribe().get(objectAPIName.trim()).getDescribe().fields.getMap();
            for(string obj : objectFields.keySet()){
                apiNames.add(obj);
            }
            returnString = string.join(apiNames,',');
        } catch (Exception e) {
            System.debug('error in get all field class : '+e.getMessage()+' at line no : '+e.getLineNumber());
            returnString = '';
        }
        
        return returnString;
    }
}
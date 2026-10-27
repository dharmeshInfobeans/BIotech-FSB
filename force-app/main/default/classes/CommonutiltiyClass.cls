public class CommonutiltiyClass {

    @AuraEnabled(cacheable=true)
    public static Map<String,String> getUserInformation() {
        Map<String,String> userInfMap=new Map<String,String>();
        User use=[SELECT Id,profile.name from user where Id=:userinfo.getUserId()];
        userInfMap.put('FirstName',UserInfo.getFirstName());
        userInfMap.put('LastName',UserInfo.getLastName());
        userInfMap.put('Email',UserInfo.getUserEmail());
        userInfMap.put('Profile',use.profile.name);
        return userInfMap;
    }

    /*  public static string getAllFields(String objectAPIName){ string returnString; try { System.debug('REQUEST : '+objectAPIName); list<string> apiNames = new List<string>(); Map<String, Schema.SObjectField> objectFields = Schema.getGlobalDescribe().get(objectAPIName.trim()).getDescribe().fields.getMap(); for(string obj : objectFields.keySet()){ apiNames.add(obj); } returnString = string.join(apiNames,','); } catch (Exception e) { System.debug('error in get all field class : '+e.getMessage()+' at line no : '+e.getLineNumber()); returnString = ''; }  return returnString; }*/

    public static list<String> getPickListValues(String fieldName, string objectName){
        list<String> returnList = new list<String>();
        System.debug('Object : '+objectName+' : Field name : '+fieldName);
        try {
            Map<String, schema.SObjectField> feildMap = Schema.getGlobalDescribe().get(objectName.trim()).getDescribe().fields.getMap();
            list<Schema.PicklistEntry> values = feildMap.get(fieldName.trim()).getDescribe().getPickListValues();
            system.debug('values111'+values);
            for (Schema.PicklistEntry obj : values) {
                returnList.add(obj.getValue().remove('\'').escapeUnicode());
            }
            returnList.sort();
            System.debug('MAP with FEILD TYPE : '+returnList);
        } catch (Exception e) {
            System.debug('error in datafetching method : '+e.getMessage()+' at line no : '+e.getLineNumber());
        }
        if (returnList.isEmpty()) {
            return null;
        }else {
            return returnList;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getdailyactivity() {
        Id currentUserId = UserInfo.getUserId(); // Get the current logged-in user

        // Retrieve the current user's country and Login_Logout_Module__c values
        User currentUser;
        try {
            currentUser = [
                SELECT Country__c, Login_Logout_Module__c
                FROM User
                WHERE Id = :currentUserId
                LIMIT 1
            ];
        } catch (Exception e) {
            return new Map<String, Object>{ 'error' => 'Error retrieving user information: ' + e.getMessage() };
        }

        //  String userCountry = currentUser.Country__c;
        String loginLogoutValue = (currentUser.Login_Logout_Module__c!=null && currentUser.Login_Logout_Module__c!='') ? currentUser.Login_Logout_Module__c : '';

        // Handle empty or null fields
        /* if (String.isEmpty(userCountry) || String.isEmpty(loginLogoutValue)) { // return new Map<String, Object>{ 'activity' => false, 'error' => 'Required user fields are empty' }; }*/

        // Retrieve the custom label value (comma-separated) and split it into a list
        String excludedCountries = Label.Country_wise_Login_logout_module; // Replace with your custom label API name
        List<String> excludedCountryList = new List<String>();
        if (!String.isEmpty(excludedCountries)) {
            if(excludedCountries!=null && excludedCountries!='') {
                if(excludedCountries.contains(',')) {
                    for (String country : excludedCountries.split(',')) {
                        excludedCountryList.add(country.trim());
                    }
                }else {
                    excludedCountryList.add(excludedCountries.trim());
                }
            }
        }

        // Split the Login_Logout_Module__c field into a list of countries
        /*   List<String> loginLogoutCountries = new List<String>();
        for (String country : loginLogoutValue.split(',')) {
            loginLogoutCountries.add(country.trim());
        }*/

        // Check if the user's country exists in both the excluded list and Login_Logout_Module__c list
        // Boolean isExcluded = excludedCountryList.contains(userCountry) && loginLogoutCountries.contains(userCountry);

        // Return activity status based on the exclusion criteria
        if (excludedCountryList.contains(loginLogoutValue)) {
            // Query Beat_Plan__c for today's activity
            List<Beat_Plan__c> beatPlans = [
                SELECT Id, Name, Beat_Date__c, Login_Time__c
                FROM Beat_Plan__c
                WHERE Beat_Date__c = :System.today()
                AND Assigned_To__c = :currentUserId
                AND Login_Time__c != null
                LIMIT 1
            ];

            // Check if there are any beat plans for today
            if (!beatPlans.isEmpty()) {
                return new Map<String, Object>{ 'activity' => true };
            } else {
                return new Map<String, Object>{ 'activity' => false };
            }
        } else {
            // If the country is not in the custom label or not in the login/logout module
            return new Map<String, Object>{ 'activity' => true };
        }
    }

    /*   public static list<SObject> getSobjectData(string type){ string fields = getAllFields(type); if (String.isNotBlank(fields)) { list<SObject> returnObject = Database.query('select '+fields+' from '+type); return returnObject; }else { return null; } }*/

    /* public static String getNamespacePrefix(String className, String objective) { String namespace = ''; if (objective == 'Class') { try { ApexClass ac = [SELECT NameSpacePrefix FROM ApexClass WHERE Name =: className]; if(null != ac.NameSpacePrefix) { namespace = ac.NameSpacePrefix + '__'; } } catch (QueryException ex) { System.debug('error in Apex class name : '+ex.getMessage()); } }else { try { Integer indexOfToken = -1; for ( Schema.SObjectType type : Schema.getGlobalDescribe().values() ) { String sobjName = String.valueOf(type);  if (null != sobjName) { indexOfToken = sobjName.indexOf(className); }  if (indexOfToken != -1) { namespace = sobjName.substring(0, indexOfToken); break; } } } catch (Exception e) { System.debug('SOBJECT error : '+e.getMessage()); }  }  return namespace; } */

    public static String getFieldType(string fieldName,String objectName){
        Map<String, schema.SObjectField> feildMap = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap();
        Schema.SObjectField field = feildMap.get(fieldName);
        Schema.DisplayType dataType = field.getDescribe().getType();
        System.debug('Field Request : '+fieldName+' type : '+dataType);
        return String.valueOf(dataType);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String,List<Map<String,String>>> getLightningPickListValues() {
        //list<Map<String,String>> returnList = new list<Map<String,String>>();
        Map<String,List<Map<String,String>>> dynamicPicklistMap=new Map<String,List<Map<String,String>>>();
        try {
            //  returnList.add(new Map<String,String>{'label'=>'--Select--','value'=>'--Select--'});
            for(String objectName:getDynamicObjectName().keyset()) {
                for(string fieldName:getDynamicObjectName().get(objectName).split(';')) {
                    Map<String, schema.SObjectField> feildMap = Schema.getGlobalDescribe().get(objectName.trim()).getDescribe().fields.getMap();
                    list<Schema.PicklistEntry> values = feildMap.get(fieldName.trim()).getDescribe().getPickListValues();
                    system.debug('values=========>'+values); //gyadeen

                    for (Schema.PicklistEntry obj : values) {
                        if(dynamicPicklistMap.containsKey(fieldName))  {
                            dynamicPicklistMap.get(fieldName).add(new Map<String,String>{'label'=>obj.getLabel(),'value'=>obj.getValue().remove('\'').escapeUnicode()});
                        }else {
                            List<Map<String,String>> returnList=new List<Map<String,String>>();
                            returnList.add(new Map<String,String>{'label'=>obj.getLabel(),'value'=>obj.getValue().remove('\'').escapeUnicode()});
                            dynamicPicklistMap.put(fieldName,returnList);
                        }
                    }
                }
            }

        } catch (Exception e) {
            System.debug('Error in lightning picklist values : '+e.getMessage()+' at line no :'+e.getLineNumber());
            // return null;
        }
        return dynamicPicklistMap;
    }

    private static Map<String,String> getDynamicObjectName() {
        return new Map<String,String>{
            'Lead__c'=>'Lead_Stage__c;Country__c;Product__c;Disqualified_Reason__c;Product_Family__c',
            'Event'=>'Subject;Call_Type__c;Meeting_Type__c',
            'Contact'=>'Specialities__c'
        };
    }

    public static Map<String,String> getLeadAssignment(){
        Map<String,String> cityWiseMappingMap=new Map<String,String>();
        for(CityWise__c cityMapping:[SELECT City__c,Country__c,State__c,UserId__c from CityWise__c]) {
            cityWiseMappingMap.put(cityMapping.Country__c+cityMapping.State__c+cityMapping.City__c,cityMapping.UserId__c);
        }
        return cityWiseMappingMap;
    }

    @AuraEnabled(cacheable=true)
    public static Loginlogoutlabels__c getCustomLabels() {
        String language=UserInfo.getLanguage();
        Loginlogoutlabels__c leadTranslationLabel=Loginlogoutlabels__c.getValues(language);
        return leadTranslationLabel;
    }

    @AuraEnabled(cacheable=true)
    public static Customercreationlabels__c getCustomLabelscustomercreation() {
        String language=UserInfo.getLanguage();
        Customercreationlabels__c leadTranslationLabel = Customercreationlabels__c.getValues(language);
        return leadTranslationLabel;
    }

}
public class PathController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPicklistValues(String recordId){
        Map<String, Object> returnMap = new Map<String, Object>();
        List<Map<String, Object>> picklistList = new List<Map<String, Object>>();
        Lead__c ld = [select id,Marketing_Stage__c,Lead_Stage__c,Existing_customer__c,New_Customer__c from Lead__c where Id =: recordId];
        returnMap.put('profile',UserInfo.getProfileId());
        if(label.marketing_Profiles.split(',').contains(UserInfo.getProfileId())){
            returnMap.put('existValue',ld.Marketing_Stage__c); //
            returnMap.put('field','Marketing_Stage__c');
            returnMap.put('existingcustomer',ld.Existing_customer__c);// Gyadeen Ahirwar
            returnMap.put('newcustomer',ld.New_Customer__c);// Gyadeen Ahirwar
            returnMap.put('picklist',getLightningPickListValues('Marketing_Stage__c','Lead__c'));
        }else{
            returnMap.put('existingcustomer',ld.Existing_customer__c); // Gyadeen Ahirwar
            returnMap.put('newcustomer',ld.New_Customer__c);// Gyadeen Ahirwar
            returnMap.put('existValue',ld.lead_Stage__c);
            returnMap.put('field','lead_Stage__c');
            returnMap.put('picklist',getLightningPickListValues('Lead_Stage__c','Lead__c'));
        }

        return returnMap;
    }
    //*********************************Added by gyadeen**************************************************************
    @AuraEnabled(cacheable=true)
    public static Boolean isCurrentUserAdmin() {
        Boolean isadmin;
       User currentUser = [SELECT Profile.Name, UserRole.Name,Lead_Stage_Access__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
// Extracting Profile Name and User Role Name
String profileName = currentUser.Profile.Name;
        
        system.debug('profileName'+ profileName);
       

        // Check if the user is an admin
        if (profileName == 'System Administrator' || currentUser.Lead_Stage_Access__c==true) {
            return true; 
        } else {
            return false;
        
        }
    }
     //*********************************Added by gyadeen**************************************************************


    public static list<Map<String,Object>> getLightningPickListValues(String fieldName, string objectName) {
        list<Map<String,Object>> returnList = new list<Map<String,Object>>();
        try {
           // returnList.add(new Map<String,Object>{'label'=>'--Select--','value'=>'--Select--'});
            Map<String, schema.SObjectField> feildMap = Schema.getGlobalDescribe().get(objectName.trim()).getDescribe().fields.getMap();
            list<Schema.PicklistEntry> values = feildMap.get(fieldName.trim()).getDescribe().getPickListValues();
            for (Schema.PicklistEntry obj : values) {
                returnList.add(new Map<String,Object>{'label'=>obj.getLabel(),'value'=>obj.getValue().remove('\'').escapeUnicode()});
            }
            System.debug('MAP with FEILD TYPE : '+returnList);
        } catch (Exception e) {
            System.debug('Error in lightning picklist values : '+e.getMessage()+' at line no :'+e.getLineNumber());
           // return null;
        }
        return returnList;
    }

    @AuraEnabled
    public static lead__c updateLead(String recordId, String field, String value){
        Lead__c ld = new Lead__c();
        ld.Id = recordId;
        ld.put(field,value);
        update ld;
        return ld;
    }
}
/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 02-13-2024
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class ReusableUtilityClass {

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getPicklistValues(String objectApiName, List<String> fieldApiNames) {
        Map<String, List<Map<String, String>>> fieldValuesMap = new Map<String, List<Map<String, String>>>();
        
        // Get the SObjectType dynamically
        Schema.DescribeSObjectResult objectDescription = Schema.getGlobalDescribe().get(objectApiName).getDescribe();
        
        for (String fieldApiName : fieldApiNames) {
            // Get the DescribeFieldResult for the specific field
            Schema.DescribeFieldResult fieldDescription = objectDescription.fields.getMap().get(fieldApiName).getDescribe();
            
            // Check if the field is a picklist
            if (fieldDescription.getType() == Schema.DisplayType.PICKLIST) {
                List<Schema.PicklistEntry> picklistValues = fieldDescription.getPicklistValues();
                // Iterate through picklist values and create a map for each value
                List<Map<String, String>> values = new List<Map<String, String>>();
                for (Schema.PicklistEntry picklistEntry : picklistValues) {
                    Map<String, String> valueMap = new Map<String, String>();
                    valueMap.put('label', picklistEntry.getLabel());
                    valueMap.put('value', picklistEntry.getValue());
                    values.add(valueMap);
                }
                fieldValuesMap.put(fieldApiName, values);
            }
        }
        System.debug('fieldValuesMap ==> ' + fieldValuesMap);
        return fieldValuesMap;
    } 
    
    public static Map<String, String> getPicklistMap(String objectName, String fieldName) {
        Map<String, String> picklistMap = new Map<String, String>();
        
        // Get field describe information
        Schema.DescribeFieldResult fieldDescribe = Schema.getGlobalDescribe().get(objectName)
            .getDescribe().fields.getMap().get(fieldName).getDescribe();

        // Get picklist values
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            picklistMap.put(entry.getValue(), entry.getLabel()); // API Name -> Label
        }
        
        return picklistMap;
    }
    

    public static void sendSapErrorEmail(String errorMessage,String subject) {
        List<String> toEmails = new List<String>();

        // 1. Add fixed admin email
        toEmails.add('dharmeshkumar.vaishnav@infobeans.com');

        // 2. Add all AdminINT profile users (commented out safely)
       List<User> users = [
                    SELECT Email, Username
                    FROM User
                    WHERE Name = 'Komal Bhatia'];
        
                
                for (User u : users) {
                    if (!String.isBlank(u.Email)) {
                        toEmails.add(u.Email);
                    }
                }
  List<OrgWideEmailAddress> owaList = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = 'CRM HelpDesk'];

        // Send email only if we have recipients
        if (!toEmails.isEmpty()) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(toEmails);
            mail.setSubject(subject);
            mail.setPlainTextBody('An SAP API call failed.\n\n' + errorMessage);
             mail.setOrgWideEmailAddressId(owaList[0].Id);
            
                List<Messaging.SendEmailResult> results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
    for (Messaging.SendEmailResult res : results) {
        if (res.isSuccess()) {
            System.debug('Email sent successfully to ' + res);
        } else {
            System.debug('Email failed to send to ' + res);
        }
    }
        }
    }
    
    
}
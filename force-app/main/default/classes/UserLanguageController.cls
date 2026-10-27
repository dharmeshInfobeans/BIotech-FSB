public without sharing class UserLanguageController {
    public static User userObj = new User();
    @AuraEnabled
    public static String updateUserLanguage(String language) {
        String userId = UserInfo.getUserId();
        system.debug('BG >>> language : '+language);
        // Query the user record
        userObj = [SELECT Id, LanguageLocaleKey FROM User WHERE Id = :userId LIMIT 1];
        userObj.LanguageLocaleKey = language;

        try {
            // Update the user's language preference
            update userObj;
            return 'Language updated successfully.';
        } catch (Exception e) {
            return 'Error updating language: ' + e.getMessage();
        }
    }

    /*@AuraEnabled
    public static List<String> getActiveLanguages() {
        List<String> activeLanguages = new List<String>();

        // Query and retrieve active languages from custom metadata or custom settings
        List<SiteLanguage__mdt> siteLanguages = [SELECT LanguageCode__c FROM SiteLanguage__mdt WHERE IsActive__c = true];
        for (SiteLanguage__mdt lang : siteLanguages) {
            activeLanguages.add(lang.LanguageCode__c);
        }

        return activeLanguages;
    }*/

    @AuraEnabled(cacheable=true)
    public static List<SiteLanguage__mdt> getAvailableLanguages() {
        return [SELECT MasterLabel, LanguageCode__c,IsActive__c FROM SiteLanguage__mdt WHERE IsActive__c = true]; 
    }

   // public with sharing class UserLanguageController {
        @AuraEnabled(cacheable=true)
        public static String getUserLanguage() {
            String userId = UserInfo.getUserId();
            userObj = [SELECT LanguageLocaleKey FROM User WHERE Id = :userId LIMIT 1];
            return userObj.LanguageLocaleKey;
        }
    //}
}
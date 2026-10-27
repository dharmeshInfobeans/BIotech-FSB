/**
 * ContactTriggerHandler Class
 *
 * Description:
 * This class handles duplicate validation logic for Contact records based on user-defined settings.
 * Duplicate checks include:
 *   - Email-based duplicate detection
 *   - Mobile phone-based duplicate detection
 *   - First Name + Last Name combination duplicate detection
 *   - Contact Name duplicate within the same Account (if enabled)
 *
 * The behavior is controlled by the 'Contact_duplicate_rule__c' Custom Setting.
 *
 * Notes:
 * - Designed to support bulk operations and avoid SOQL limits.
 * - Error messages are shown to the end user during insert/update if duplicates are found.
 * - Supports different rules based on the logged-in user's Country.
 *
 * Usage:
 * Call 'checkForDuplicate(List<Contact>)' method from Trigger before insert or before update.
 * 
 * Created by: Gyadeen Ahirwar
 * Created date: 04/07/2025
 * Last modified Date: 07/07/2025
 */

public class ContactTriggerHandler {

    public void checkForDuplicate(List<Contact> newList) {
        if (newList == null || newList.isEmpty()) return;

        //Get custom settings
        String userCountry = [SELECT Country__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1].Country__c;
        Contact_duplicate_rule__c setting = Contact_duplicate_rule__c.getValues(userCountry);
        if (setting == null) return;

        //Collect values
        Set<String> emails = new Set<String>();
        Set<String> mobiles = new Set<String>();
        Set<String> nameCombos = new Set<String>();
        Set<Id> accountIdSet = new Set<Id>();

        for (Contact con : newList) {

            if (setting.Email__c && String.isNotBlank(con.Email)) {
                emails.add(con.Email.trim());
            }

            if (setting.Mobile__c && String.isNotBlank(con.MobilePhone)) {
                mobiles.add(con.MobilePhone.trim());
            }

            if (setting.First_Name_Last_Name_Name__c && String.isNotBlank(con.FirstName) && String.isNotBlank(con.LastName)) {
                String combo = con.FirstName.trim() + '-' + con.LastName.trim();
                nameCombos.add(combo);
            }

            if (setting.Account_Name__c && con.AccountId != null) {
                accountIdSet.add(con.AccountId);
            }
        }

        //Build SOQL
        String dynamicQuery = 'SELECT Id, Email, FirstName, MobilePhone, LastName, Account.Name, AccountId FROM Contact WHERE ';
        List<String> conditions = new List<String>();

        if (!emails.isEmpty()){
            conditions.add('Email IN :emails');
        } 
        if (!mobiles.isEmpty()){
            conditions.add('MobilePhone IN :mobiles');
        } 
        if (!nameCombos.isEmpty()) {
            conditions.add('FirstName != null');
            conditions.add('LastName != null');
        }
        if (!accountIdSet.isEmpty()){
            conditions.add('AccountId IN :accountIdSet');
        } 

        if (!conditions.isEmpty()) {
            dynamicQuery += String.join(conditions, ' OR ');
        } else {
            dynamicQuery = 'SELECT Id, Email, FirstName, MobilePhone, LastName, Account.Name, AccountId FROM Contact LIMIT 0';
        }

        System.debug('Final Dynamic Query: ' + dynamicQuery);

        //Run query
        List<Contact> contactList = Database.query(dynamicQuery);

        Map<String, Contact> emailMap = new Map<String, Contact>();
        Map<String, Contact> mobileMap = new Map<String, Contact>();
        Set<String> existingCombos = new Set<String>();
        Map<Id, Set<String>> accountToNameSet = new Map<Id, Set<String>>();

        for (Contact existingCon : contactList) {

            if (setting.Email__c && String.isNotBlank(existingCon.Email)) {
                emailMap.put(existingCon.Email.trim(), existingCon);
            }

            if (setting.Mobile__c && String.isNotBlank(existingCon.MobilePhone)) {
                mobileMap.put(existingCon.MobilePhone.trim(), existingCon);
            }

            if (setting.First_Name_Last_Name_Name__c && String.isNotBlank(existingCon.FirstName) && String.isNotBlank(existingCon.LastName)) {
                String combo = existingCon.FirstName.trim() + '-' + existingCon.LastName.trim();
                existingCombos.add(combo);
            }

            if (setting.Account_Name__c && existingCon.AccountId != null && 
                String.isNotBlank(existingCon.FirstName) && String.isNotBlank(existingCon.LastName)) {

                String combo = existingCon.FirstName.trim() + '-' + existingCon.LastName.trim();
                if (!accountToNameSet.containsKey(existingCon.AccountId)) {
                    accountToNameSet.put(existingCon.AccountId, new Set<String>());
                }
                accountToNameSet.get(existingCon.AccountId).add(combo);
            }
        }

        // Get Account Names 
        Map<Id, String> accountNameMap = new Map<Id, String>();
        if (!accountIdSet.isEmpty()) {
            for (Account acc : [SELECT Id, Name FROM Account WHERE Id IN :accountIdSet]) {
                accountNameMap.put(acc.Id, acc.Name);
            }
        }

        //Final Duplicate Validation
        for (Contact con : newList) {

            if (setting.Email__c && String.isNotBlank(con.Email)) {
                String emailTrimmed = con.Email.trim();
                if (emailMap.containsKey(emailTrimmed)) {
                    con.addError('⚠ DUPLICATE FOUND: A Contact already exists with the same Email: ' + con.Email);
                }
            }

            if (setting.Mobile__c && String.isNotBlank(con.MobilePhone)) {
                String mobileTrimmed = con.MobilePhone.trim();
                if (mobileMap.containsKey(mobileTrimmed)) {
                    con.addError('⚠ DUPLICATE FOUND: A Contact already exists with the same Mobile: ' + con.MobilePhone);
                }
            }

            String combo = (String.isNotBlank(con.FirstName) && String.isNotBlank(con.LastName)) 
                            ? con.FirstName.trim() + '-' + con.LastName.trim() : null;

            if (setting.First_Name_Last_Name_Name__c && combo != null && existingCombos.contains(combo)) {
                con.addError('⚠ DUPLICATE FOUND: A Contact already exists with the same First Name and Last Name.');
            }

            if (setting.Account_Name__c && con.AccountId != null && combo != null) {
                if (accountToNameSet.containsKey(con.AccountId) && accountToNameSet.get(con.AccountId).contains(combo)) {
                    String accName = accountNameMap.containsKey(con.AccountId) ? accountNameMap.get(con.AccountId) : 'this Account';
                    con.addError('⚠ DUPLICATE FOUND: A Contact with the SAME NAME already exists under Account: ' + accName);
                }
            }
        }
    }
}
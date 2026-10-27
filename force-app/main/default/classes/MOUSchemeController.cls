public class MOUSchemeController {
    @AuraEnabled(cacheable=true)
    public static list<Account> getChildAccounts() {
        List<Account> ChildAccounts = [Select Id , Name, ParentId, E_Mail__c, phone, SAP_Code__c from Account where ParentId =: '001C300000EM2khIAD' OR Id='001C300000EM2khIAD'];
        
        return ChildAccounts;
    }

}
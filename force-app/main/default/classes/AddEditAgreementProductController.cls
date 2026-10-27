public with sharing class AddEditAgreementProductController {
    
    
    @AuraEnabled
    public static AgreementWrapper fetchAgreementProductData(String MasterAgreementId) {
        AgreementWrapper response = new AgreementWrapper();
        
        try {
            // Fetch Master Agreement details separately
            List<Master_Agreement__c> masterAgreements = [
                SELECT Id, Version__c, Is_Active__c, Renewed_From__c,Vertical__c 
                FROM Master_Agreement__c 
                WHERE Id = :MasterAgreementId
                LIMIT 1
            ];
            
            if (!masterAgreements.isEmpty()) {
                response.masterAgreement = masterAgreements[0];
            }
            
            // Fetch Agreement Products related to the Master Agreement
            response.agreementProducts = [
                SELECT Id, Master_Agreement__c, Name, Product__c,Is_Backup__c, Price__c,Product__r.Has_Backup__c , 
                FOC_Text__c, Plant__c, CurrencyIsoCode, Payment_Terms_options__c, 
                Incoterms__c, Is_Amended__c, Is_Canceled__c
                FROM Agreement_Product__c
                WHERE Master_Agreement__c = :MasterAgreementId
            ];
            
            return response;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching agreement data: ' + e.getMessage());
        }
    }
    
    
    @AuraEnabled
    public static PicklistWrapper fetchPicklist() {
        try {
            PicklistWrapper result = new PicklistWrapper();
            
            // Fetch picklist values using reusable utility class
            Map<String, List<Map<String, String>>> picklistValues = ReusableUtilityClass.getPicklistValues(
                'Agreement_Product__c',
                new List<String>{'Payment_Terms_options__c', 'Incoterms__c', 'CurrencyIsoCode'}
            );
            
            result.paymentTermOptions = picklistValues.get('Payment_Terms_options__c');
            result.incotermOptions = picklistValues.get('Incoterms__c');
            result.currencyOptions = picklistValues.get('CurrencyIsoCode');
            
            return result;
        } catch (Exception e) {
            throw e;
        }
    }
    
    @AuraEnabled
    public static void saveAgreementProducts(List<Agreement_Product__c> updatedAgreementProducts) {
        try {
            if (updatedAgreementProducts == null || updatedAgreementProducts.isEmpty()) {
                throw new AuraHandledException('No changes detected to save.');
            }
            
            List<Agreement_Product__c> recordsToUpdate = new List<Agreement_Product__c>();
            List<Agreement_Product__c> recordsToDelete = new List<Agreement_Product__c>();
            
            for (Agreement_Product__c product : updatedAgreementProducts) {
                // Ensure product is marked as Is_Canceled__c for deleted records
                if (product.Is_Canceled__c == true) {
                    recordsToDelete.add(product);  
                }else{
                recordsToUpdate.add(product);
                }
            }
            System.debug('recordsToUpdate'+recordsToUpdate);
            if (!recordsToUpdate.isEmpty()) {
                upsert recordsToUpdate;
            }
            System.debug('recordsToDelete'+recordsToDelete);
            if (!recordsToDelete.isEmpty()) {
                delete recordsToDelete;
            }
        } catch (Exception e) {
            throw  e;
        }
    }
    
    @AuraEnabled
    public static Map<String, String> fetchPlantValue(Id productID) {
        try {
            Product__c product = [
                SELECT Plant__r.Name, Has_Backup__c 
                FROM Product__c 
                WHERE Id = :productID 
                LIMIT 1
            ];
            
            // Prepare response with only two required values
            Map<String, String> response = new Map<String, String>();
            response.put('plantName', product.Plant__r != null ? product.Plant__r.Name : ''); // Handle null safely
            response.put('hasBackup', String.valueOf(product.Has_Backup__c)); // Convert Boolean to String
            
            return response;
        } catch (Exception e) {
            throw  e;
        }
    }
    
    
    // Wrapper class for picklist values
    public class PicklistWrapper {
        @AuraEnabled
        public List<Map<String, String>> paymentTermOptions { get; set; }
        @AuraEnabled
        public List<Map<String, String>> incotermOptions { get; set; }
        @AuraEnabled
        public List<Map<String, String>> currencyOptions { get; set; }
    }
    
    public class AgreementWrapper {
        @AuraEnabled public Master_Agreement__c masterAgreement;
        @AuraEnabled public List<Agreement_Product__c> agreementProducts;
    }
    
}
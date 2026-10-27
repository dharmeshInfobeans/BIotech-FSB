/**
* @File Name : OpportunityAddProductController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : June 10, 2026
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | December 25, 2025 |   | Initial Version
* 2.0 | February 26, 2026 |   | Fixed createOppLine
* 3.0 | February 27, 2026 |   | Removed cacheable from getProductsByGroups,
*                               added Product_Family__c to product SELECT,
*                               products only load when groupNames provided,
*                               improved null safety throughout
* 4.0 | June 10, 2026      |   | getProductGroups no longer reads the removed
*                               Opportunity__c.Product_Group__c lookup. It now
*                               reads the Opportunity's Product_Family__c
*                               picklist and returns all Product Groups in that
*                               family (Display_on_Opportunity__c = true).
**/
public class OpportunityAddProductController {

    @AuraEnabled(cacheable=true)
    public static List<Product_Group__c> getProductGroups(String recordId) {
        try {
            if (String.isBlank(recordId)) {
                return new List<Product_Group__c>();
            }

            // CHANGED (v4.0): the Opportunity Product_Group__c lookup has been
            // removed. Read the Product_Family__c picklist off the Opportunity
            // and return every Product Group in that family instead.
            List<Opportunity__c> opps = [
                SELECT Id, Product_Family__c
                FROM   Opportunity__c
                WHERE  Id = :recordId
                LIMIT  1
            ];

            if (opps.isEmpty() || String.isBlank(opps[0].Product_Family__c)) {
                return new List<Product_Group__c>();
            }

            String oppFamily = opps[0].Product_Family__c;

            return [
                SELECT Id, Product_Family__c, Group_Name__c, Brand__c
                FROM   Product_Group__c
                WHERE  Product_Family__c = :oppFamily
                AND    Display_on_Opportunity__c = TRUE
                ORDER BY Product_Family__c ASC, Group_Name__c ASC
            ];

        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to load product groups: ' + e.getMessage()
            );
        }
    }
    @AuraEnabled
    public static List<Product_M__c> getProductsByGroups(List<String> productFamilies, List<String> groupNames) {
        try {
            if (productFamilies == null || productFamilies.isEmpty()) {
                return new List<Product_M__c>();
            }
            if (groupNames == null || groupNames.isEmpty()) {
                return new List<Product_M__c>();
            }
            
            List<Product_Group__c> groups = [SELECT Id FROM Product_Group__c WHERE Product_Family__c IN :productFamilies AND Group_Name__c IN :groupNames];
            
            Set<Id> groupIds = new Set<Id>();
            for (Product_Group__c pg : groups) {
                groupIds.add(pg.Id);
            }
            
            if (groupIds.isEmpty()) {
                return new List<Product_M__c>();
            }
            
            return [SELECT Id, Name, Product_Group__c, Product_Family__c, Brand__c, Category__c, Sub_Category__c FROM Product_M__c WHERE Product_Group__c IN :groupIds
                    ORDER BY Name ASC];
            
        } catch (Exception e) {
            throw new AuraHandledException(
                'Failed to load products: ' + e.getMessage()
            );
        }
    }
    
    @AuraEnabled
    public static void createOppLine(Id oppId, String productData) {
        
        if (oppId == null) {
            throw new AuraHandledException('Opportunity Id is required.');
        }
        
        if (String.isBlank(productData)) {
            throw new AuraHandledException('No Product Groups selected.');
        }
        
        List<Object> parsedList = (List<Object>) JSON.deserializeUntyped(productData);
        
        if (parsedList.isEmpty()) {
            throw new AuraHandledException('No Product Groups selected.');
        }
        
        List<Opportunity_Product__c> oppProducts = new List<Opportunity_Product__c>();
        
        for (Object obj : parsedList) {
            system.debug('83----' + parsedList);
            Map<String, Object> item = (Map<String, Object>) obj;
            
            Id groupId = (Id) item.get('productId');
            
            Decimal qty = item.get('quantity') != null
                ? Decimal.valueOf(String.valueOf(item.get('quantity')))
                : 1;
            
            Decimal asp = item.get('asp') != null
                ? Decimal.valueOf(String.valueOf(item.get('asp')))
                : 0;
            
            Decimal msp = item.get('msp') != null
                ? Decimal.valueOf(String.valueOf(item.get('msp')))
                : 0;
            
            String family = (String) item.get('productFamily');
            
            oppProducts.add(new Opportunity_Product__c(
                Opportunity__c = oppId,
                Product_Group__c = groupId,
                Product_Family__c = family,
                Quantity__c = qty,
                PF_ASP__c = asp,
                Product_MSP__c = msp
            ));
        }
        
        if (!oppProducts.isEmpty()) {
            insert oppProducts;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Product_Group__c> getProductGroupsByFamily(String productFamily) {
        
        if(String.isBlank(productFamily)){
            return new List<Product_Group__c>();
        }
        
        return [SELECT Id, Name, Product_Family__c, Brand__c, PF_ASP__c, Product_MSP__c FROM Product_Group__c
                WHERE Product_Family__c = :productFamily AND Display_on_Opportunity__c = true ORDER BY Group_Name__c];
    }
    @AuraEnabled(cacheable=true)
    public static String getOpportunityRecordTypeName(Id oppId) {
        Opportunity__c opp = [SELECT RecordType.Name FROM Opportunity__c WHERE Id = :oppId LIMIT 1];
        return opp.RecordType.Name;
    }
    
    
    //**********************below code is refer to Equipment Opportunity Document Uploader******************************
    @AuraEnabled
    public static void updateFileTitle(Id contentDocumentId, String newTitle) {
        
        // query the contententversion received Id from lwc.
        ContentVersion latestVersion = [
            SELECT Id, Title
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId 
            ORDER BY CreatedDate DESC 
            LIMIT 1 
        ];
        
        // Add title name comes from lwc
        latestVersion.Title = newTitle;
        
        update latestVersion;
        // Database.SaveResult sr = Database.insert( latestVersion, false, AccessLevel.USER_MODE);
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String,String> getUploadedDocumentTitles(String recordId) {
        Map<String,String> MapOfIdWithTitle = new Map<String,String>();
        List<ContentDocumentLink> links = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :recordId];
        if (!links.isEmpty()) {Set<Id> docIds = new Set<Id>();
                               for (ContentDocumentLink link : links) {docIds.add(link.ContentDocumentId);} 
                               for (ContentVersion ver : [SELECT Id,Title,ContentDocumentId FROM ContentVersion WHERE ContentDocumentId IN :docIds AND IsLatest = true]) {MapOfIdWithTitle.put(ver.Title,ver.ContentDocumentId);}}
        return MapOfIdWithTitle;
    }
    
      @AuraEnabled
    public static void updateOpportunity(String recordId,String titleName){
        Opportunity__c opp =[SELECT Id,isBundleCalculator__c, isDoctorLetterLoaded__c, isVendorQuotation__c FROM Opportunity__c WHERE Id=:recordId LIMIT 1];
        opp.isBundleCalculator__c = (titlename == 'Bundle Calculator') ? true : opp.isBundleCalculator__c;
		opp.isDoctorLetterLoaded__c = (titlename == 'Doctor’s Letter') ? true : opp.isDoctorLetterLoaded__c;
        opp.isVendorQuotation__c = (titlename == 'Vendor Quotation') ? true : opp.isVendorQuotation__c;
       

        if(opp!= Null){update opp;}}
    
     //******************************************************Ends Here**************************************************************
}
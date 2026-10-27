public without sharing class SecondarySalesLineItemController {

	@AuraEnabled
    public static List<Secondary_Sales_Line_Item__c> getMonthlySalesEntry(){
        return [SELECT Id, Product__c, Quantity__c,Date__c, Allow_Monthly_Sales_Edit__c FROM Secondary_Sales_Line_Item__c where Quantity__c != null AND Allow_Monthly_Sales_Edit__c = true];
    }

	@AuraEnabled
    public static List<Secondary_Sales_Line_Item__c> saveMonthlySales(List<MonthlySalesWrapper> salesList){
            
        System.debug('salesList=======>>>>'+ salesList);
		List<Secondary_Sales_Line_Item__c> processedRecords = new List<Secondary_Sales_Line_Item__c>();
    
        if(salesList == null || salesList.isEmpty()){  
            return processedRecords;
        }
    
        Set<Id> productIds = new Set<Id>();
        Set<Id> headerIds = new Set<Id>();
        Set<Date> salesDates = new Set<Date>();
    
        for(MonthlySalesWrapper w : salesList){
            if(w.productId != null){
                productIds.add(w.productId);
            }
            if(w.secondarySalesHeaderId != null){
                headerIds.add(w.secondarySalesHeaderId);
            }
            if(w.salesMonthDate != null){
                salesDates.add(Date.valueOf(w.salesMonthDate));
            }
        }
    
        // Fetch existing records
        Map<String, Secondary_Sales_Line_Item__c> existingMap = new Map<String, Secondary_Sales_Line_Item__c>();
    
        for(Secondary_Sales_Line_Item__c rec : [SELECT Id, Product__c, Secondary_Sales_Header__c, Date__c FROM Secondary_Sales_Line_Item__c WHERE Product__c IN :productIds
            									AND Secondary_Sales_Header__c IN :headerIds AND Date__c IN :salesDates]){
            String key = rec.Product__c + '-' + rec.Secondary_Sales_Header__c + '-' + rec.Date__c;
            existingMap.put(key, rec);
        }
    
        List<Secondary_Sales_Line_Item__c> recordsToInsert = new List<Secondary_Sales_Line_Item__c>();
        List<Secondary_Sales_Line_Item__c> recordsToUpdate = new List<Secondary_Sales_Line_Item__c>();
    
        for(MonthlySalesWrapper w : salesList){
    
            Date salesDate = Date.valueOf(w.salesMonthDate);
            String key = w.productId + '-' + w.secondarySalesHeaderId + '-' + salesDate;
    
            if(existingMap.containsKey(key)){
                // UPDATE scenario
                Secondary_Sales_Line_Item__c existingRec = existingMap.get(key);
                existingRec.Quantity__c = w.montlySales;
                existingRec.Allow_Monthly_Sales_Edit__c = true;
    
                recordsToUpdate.add(existingRec);
            }
            else{
                // INSERT scenario
                Secondary_Sales_Line_Item__c lineItem = new Secondary_Sales_Line_Item__c();
    
                lineItem.Quantity__c = w.montlySales;
                lineItem.Date__c = salesDate;
                lineItem.Product__c = w.productId;
                lineItem.Secondary_Sales_Header__c = w.secondarySalesHeaderId;
                lineItem.Allow_Monthly_Sales_Edit__c = true;
				lineItem.Type__c = 'Sold';
    
                recordsToInsert.add(lineItem);
            }
        }
    
        System.debug('recordsToInsert=======>>>>'+ recordsToInsert);
        System.debug('recordsToUpdate=======>>>>'+ recordsToUpdate);
    
        if(!recordsToInsert.isEmpty()){
            insert recordsToInsert;
			processedRecords.addAll(recordsToInsert);
        }
    
        if(!recordsToUpdate.isEmpty()){
            update recordsToUpdate;
			processedRecords.addAll(recordsToUpdate);
        }

		return processedRecords;
    }

    public class MonthlySalesWrapper{
        @AuraEnabled public String customerId {get; set;}
        @AuraEnabled public String secondarySalesHeaderId {get; set;}
        @AuraEnabled public String productId {get; set;}
        @AuraEnabled public Decimal montlySales {get; set;}
        @AuraEnabled public String salesMonthDate {get; set;}
    }

}
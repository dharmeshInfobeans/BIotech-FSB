public without sharing class SecondarySaleslineController {
	 @AuraEnabled(cacheable=True)
    public static List<Secondary_Sales_Line_Item__c> getSecondarySales() {
          return [SELECT Id,Product__r.Name, Quantity__c, Type__c, Date__c, Order_Number__c, 
          Approved_Record_Created__c,Secondary_Sales_Header__c
            FROM Secondary_Sales_Line_Item__c Where Type__c = 'In Transit' AND Approved_Record_Created__c = FALSE];
    }
  @AuraEnabled
public static void approveSales(List<Id> recordIds){

    List<Secondary_Sales_Line_Item__c> sourceRecords = [
        SELECT Id, Product__c, Quantity__c, Date__c, Order_Number__c, Approved_Record_Created__c,Secondary_Sales_Header__c
        FROM Secondary_Sales_Line_Item__c
        WHERE Id IN :recordIds];

    List<Secondary_Sales_Line_Item__c> newRecords = new List<Secondary_Sales_Line_Item__c>();
    List<Secondary_Sales_Line_Item__c> updateRecords = new List<Secondary_Sales_Line_Item__c>();

    for(Secondary_Sales_Line_Item__c rec : sourceRecords){

        if(!rec.Approved_Record_Created__c){

            Secondary_Sales_Line_Item__c approvedRec = new Secondary_Sales_Line_Item__c();

            approvedRec.Product__c = rec.Product__c;
            approvedRec.Quantity__c = rec.Quantity__c;
            approvedRec.Date__c = rec.Date__c;
            approvedRec.Order_Number__c = rec.Order_Number__c;
            approvedRec.Secondary_Sales_Header__c = rec.Secondary_Sales_Header__c;
            approvedRec.Type__c = 'Approved';

            newRecords.add(approvedRec);

            rec.Approved_Record_Created__c = true;
            updateRecords.add(rec);
        }
    }

    if(!newRecords.isEmpty()){
        insert newRecords;
    }

    if(!updateRecords.isEmpty()){
        update updateRecords;
    }
}
}
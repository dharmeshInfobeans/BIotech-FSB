public class BatchDeletionInactiveProductStock implements Database.Batchable<sObject> {
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Query to fetch inactive product material stocks
        System.debug('Starting batch job to fetch inactive product material stocks');
        Database.QueryLocator queryLocator = Database.getQueryLocator('SELECT Id, Name, IsActive__c FROM Product_Material_Stock__c WHERE IsActive__c = FALSE LIMIT 1000');
        System.debug('QueryLocator created: ' + queryLocator.getQuery());
        return queryLocator;
    }
    
    public void execute(Database.BatchableContext bc, List<Product_Material_Stock__c> records) {
        // Log the size of records to be deleted
        System.debug('In execute method, number of records to process: ' + records.size());
        
        // Delete the inactive product material stocks
        try {
            if (!records.isEmpty()) {
                delete records;
                System.debug('Deleted Inactive Product Material Stocks -- ' + records.size());
            } else {
                System.debug('No records to delete.');
            }
        } catch (DmlException e) {
            System.debug('Error in deleting Inactive Product Material Stocks: ' + e.getMessage());
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        // Execute any post-processing operations if needed
        System.debug('Batch Process for Deleting Inactive Product Material Stocks Completed');
    }
}
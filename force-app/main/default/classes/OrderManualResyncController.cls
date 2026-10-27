public with sharing class OrderManualResyncController {
    
    @AuraEnabled
    public static String resyncNow(Id headerId) {
        
        try {
            if (headerId == null) {
                return 'Error: No record Id provided.';
            }
            
            OrderSyncUpSap.syncOrderDataSync(
                new Set<Id>{ headerId },
                true
            );
            
            return 'Sync completed successfully.';
            
        } catch (Exception ex) {
            
            System.debug(
                'Manual SAP resync error: ' +
                ex.getMessage()
            );
            
            return 'Error: ' + ex.getMessage();
        }
    }
}
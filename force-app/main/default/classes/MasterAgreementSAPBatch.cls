public class MasterAgreementSAPBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Fetch Master Agreements that need syncing
        List<Master_Agreement__c> nslast = [SELECT Id from Master_Agreement__c WHERE Is_Active__c = TRUE AND Syned_To_SAP__c =FALSE];
        System.debug('nslast'+nslast);
        return Database.getQueryLocator([
           SELECT Id from Master_Agreement__c WHERE Is_Active__c = TRUE AND Syned_To_SAP__c =FALSE
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Master_Agreement__c> scope) {
        // Loop through each record and call the SAP sync method
        for (Master_Agreement__c ma : scope) {
            try {
                MasterAgreementSAPSync.processExportAgreementDataSingle(ma.Id);
            } catch (Exception e) {
                System.debug('Error syncing agreement ' + ma.Id + ': ' + e.getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Master Agreement SAP Sync Batch finished');
    }
}
global class MAFailRecResyncToSapBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    global Database.QueryLocator start(Database.BatchableContext BC) {
        String query = 'SELECT Id FROM Master_Agreement__c ' +
                       'WHERE Is_Active__c = TRUE AND Syned_To_SAP__c = FALSE';
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Master_Agreement__c> scope) {
        Set<Id> masterAgreementIds = new Set<Id>();

        // You can make callouts here without needing Database.allowCallouts(true)
        for (Master_Agreement__c ma : scope) {
            masterAgreementIds.add(ma.Id);
            if (!String.isBlank(ma.Id)) {
                Set<Id> maIdSet = new Set<Id>();
                maIdSet.add(ma.Id);
                MasterAgreementSAPSync.processExportAgreementData(maIdSet);  // This makes the SAP callout
            }
        }
    }

    global void finish(Database.BatchableContext BC) {
        System.debug('Finished reprocessing SAP sync errors.');
    }
}
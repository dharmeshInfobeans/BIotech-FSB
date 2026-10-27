// One-time, manually-invoked backfill for the three Actual_*_Week_Dashboard__c fields, for
// records that existed before the Lead_Sync_Actual_Week_Numbers flow started keeping them in
// sync automatically. This class does NOTHING on its own - deploying it makes no change to any
// record. It only runs when explicitly invoked (see the Database.executeBatch call documented in
// this class's own test method and in the rollout notes shared with the admin running it).
//
// Only ever writes to the three Actual_*_Week_Dashboard__c fields - never any other field on
// Lead__c. Processes 200 records per batch chunk (each chunk is its own transaction, so one bad
// record can't block the rest), and uses Database.update(records, false) so a single record
// failing validation doesn't stop its whole chunk - failures are logged, not thrown.
//
// Note for whoever runs this: because it updates real Lead__c records, any other
// automation on this object that reacts to "any update" (not just these 3 fields) will very
// likely still fire, the same as if each record had been edited by hand. This class does not
// suppress or bypass that - it only guarantees IT doesn't touch anything beyond the 3 fields
// listed above.
public class BackfillActualWeekNumbersBatch implements Database.Batchable<SObject>, Database.Stateful {
    public Integer recordsUpdated = 0;
    public Integer recordsFailed = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id,
                   Actual_Commercialization_Week_Number__c, Actual_Commercialization_Week_Dashboard__c,
                   Actual_Upgrade_Week_Number__c, Actual_Upgrade_Week_Dashboard__c,
                   Actual_Evaluation_Wee_Number__c, Actual_Evaluation_Week_Dashboard__c
            FROM Lead__c
            WHERE (Actual_Commercialization_Week_Number__c != null AND Actual_Commercialization_Week_Dashboard__c = null)
               OR (Actual_Upgrade_Week_Number__c != null AND Actual_Upgrade_Week_Dashboard__c = null)
               OR (Actual_Evaluation_Wee_Number__c != null AND Actual_Evaluation_Week_Dashboard__c = null)
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Lead__c> scope) {
        List<Lead__c> toUpdate = new List<Lead__c>();
        for (Lead__c rec : scope) {
            Lead__c upd = new Lead__c(Id = rec.Id);
            Boolean needsUpdate = false;
            if (rec.Actual_Commercialization_Week_Number__c != null && rec.Actual_Commercialization_Week_Dashboard__c == null) {
                upd.Actual_Commercialization_Week_Dashboard__c = rec.Actual_Commercialization_Week_Number__c;
                needsUpdate = true;
            }
            if (rec.Actual_Upgrade_Week_Number__c != null && rec.Actual_Upgrade_Week_Dashboard__c == null) {
                upd.Actual_Upgrade_Week_Dashboard__c = rec.Actual_Upgrade_Week_Number__c;
                needsUpdate = true;
            }
            if (rec.Actual_Evaluation_Wee_Number__c != null && rec.Actual_Evaluation_Week_Dashboard__c == null) {
                upd.Actual_Evaluation_Week_Dashboard__c = rec.Actual_Evaluation_Wee_Number__c;
                needsUpdate = true;
            }
            if (needsUpdate) {
                toUpdate.add(upd);
            }
        }

        if (!toUpdate.isEmpty()) {
            List<Database.SaveResult> results = Database.update(toUpdate, false);
            for (Database.SaveResult result : results) {
                if (result.isSuccess()) {
                    recordsUpdated++;
                } else {
                    recordsFailed++;
                    for (Database.Error err : result.getErrors()) {
                        System.debug(LoggingLevel.ERROR, 'BackfillActualWeekNumbersBatch failed for ' + result.getId() + ': ' + err.getMessage());
                    }
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('BackfillActualWeekNumbersBatch finished. Updated: ' + recordsUpdated + ', Failed: ' + recordsFailed);
    }
}
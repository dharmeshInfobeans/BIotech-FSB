@isTest(SeeAllData=true)
private class BackfillActualWeekNumbersBatchTest {
    // Deliberately does NOT invoke execute() or Database.executeBatch() here, even though Apex
    // test transactions roll back database changes - a rolled-back test can still leave behind
    // non-database side effects (an email actually sent, a callout actually made) from any of the
    // other automation attached to Lead__c if it fired mid-test. Given the explicit decision to
    // never risk that, even transiently, this test only exercises the read-only query logic in
    // start() - iterating a QueryLocator only reads records, it performs no DML.
    @isTest
    static void testStartQueryLocatorMatchesRecordsNeedingBackfill() {
        Set<Id> expectedIds = new Set<Id>();
        for (Lead__c rec : [
            SELECT Id FROM Lead__c
            WHERE (Actual_Commercialization_Week_Number__c != null AND Actual_Commercialization_Week_Dashboard__c = null)
               OR (Actual_Upgrade_Week_Number__c != null AND Actual_Upgrade_Week_Dashboard__c = null)
               OR (Actual_Evaluation_Wee_Number__c != null AND Actual_Evaluation_Week_Dashboard__c = null)
        ]) {
            expectedIds.add(rec.Id);
        }

        Test.startTest();
        Database.QueryLocator locator = new BackfillActualWeekNumbersBatch().start(null);
        Database.QueryLocatorIterator it = locator.iterator();
        Set<Id> actualIds = new Set<Id>();
        while (it.hasNext()) {
            actualIds.add(((Lead__c) it.next()).Id);
        }
        Test.stopTest();

        System.assertEquals(expectedIds, actualIds, 'start() should return exactly the records still needing backfill, matching a direct SOQL query');
    }
}
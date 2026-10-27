/** Provides current-user sample distribution records for the compliance view. */
public with sharing class SampleDistributionComplianceController {
    /** A serializable, UI-oriented representation of a sample line item. */
    public class ComplianceRow {
        @AuraEnabled public Id id;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String zone;
        @AuraEnabled public String division;
        @AuraEnabled public String product;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public String feedbackStatus;
        @AuraEnabled public Date executedOn;
        @AuraEnabled public String sapOrder;
        @AuraEnabled public String remarks;
        @AuraEnabled public String batchNumber;
        @AuraEnabled public String serialNumber;
    }

    /**
     * Returns every sample line owned through the current user's request headers.
     * @return owner-scoped rows, ordered for the detail tables.
     */
    @AuraEnabled(cacheable=true)
    public static List<ComplianceRow> getComplianceRows() {
        List<ComplianceRow> result = new List<ComplianceRow>();
        try {
            for (Sample_Request_Line_Item__c line : [
                SELECT Id, Account__c, Account__r.Name, Account__r.Zone_Name__c,
                    Divison__c, Dummy_Product_Description__c, Product_Quantity__c,
                    Feedback_Upload_Status__c, Executed_On__c, Batch_Number__c, Serial_Number__c,
                    Sample_Request_Header__r.orderNumSAP__c, Sample_Request_Header__r.Remarks__c
                FROM Sample_Request_Line_Item__c
                WITH USER_MODE
                ORDER BY Executed_On__c DESC, Id
            ]) {
                result.add(toComplianceRow(line));
            }
            return result;
        } catch (Exception caughtException) {
            System.debug(LoggingLevel.ERROR, 'Unable to load sample compliance rows: ' + caughtException.getMessage());
            throw new AuraHandledException('Sample compliance data is unavailable. Please refresh and try again.');
        }
    }

    /** Maps a queried line item into the view's response contract. */
    @TestVisible
    private static ComplianceRow toComplianceRow(Sample_Request_Line_Item__c line) {
        ComplianceRow row = new ComplianceRow();
        row.id = line.Id; row.accountId = line.Account__c;
        row.accountName = line.Account__r == null ? null : line.Account__r.Name;
        row.zone = line.Account__r == null ? null : line.Account__r.Zone_Name__c;
        row.division = line.Divison__c; row.product = line.Dummy_Product_Description__c;
        row.quantity = line.Product_Quantity__c; row.feedbackStatus = line.Feedback_Upload_Status__c;
        row.executedOn = line.Executed_On__c;
        row.sapOrder = line.Sample_Request_Header__r == null ? null : line.Sample_Request_Header__r.orderNumSAP__c;
        row.remarks = line.Sample_Request_Header__r == null ? null : line.Sample_Request_Header__r.Remarks__c;
        row.batchNumber = line.Batch_Number__c; row.serialNumber = line.Serial_Number__c;
        return row;
    }
}
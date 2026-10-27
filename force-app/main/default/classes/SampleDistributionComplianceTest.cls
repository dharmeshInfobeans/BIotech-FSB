/** @description Tests the owner-scoped sample compliance controller response contract. */
@IsTest
private class SampleDistributionComplianceTest {
    @IsTest
    static void returnsSafeCollectionWhenNoVisibleRows() {
        User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        System.runAs(currentUser) {
            Test.startTest();
            List<SampleDistributionComplianceController.ComplianceRow> rows = SampleDistributionComplianceController.getComplianceRows();
            Test.stopTest();
            System.assertNotEquals(null, rows, 'The controller must always return a collection.');
        }
    }

    @IsTest
    static void mapsPopulatedRowWithoutDml() {
        User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        System.runAs(currentUser) {
            Account account = new Account(Name = 'North Clinic', Zone_Name__c = 'North');
            Sample_Request_Header__c header = new Sample_Request_Header__c(orderNumSAP__c = 'SAP-42', Remarks__c = 'Complete');
            Sample_Request_Line_Item__c line = new Sample_Request_Line_Item__c(
                Divison__c = 'D1', Dummy_Product_Description__c = 'Lens', Product_Quantity__c = 4,
                Feedback_Upload_Status__c = 'Approved', Executed_On__c = Date.today(), Batch_Number__c = 'B-1', Serial_Number__c = 'S-1'
            );
            line.putSObject('Account__r', account);
            line.putSObject('Sample_Request_Header__r', header);
            Test.startTest();
            SampleDistributionComplianceController.ComplianceRow row = SampleDistributionComplianceController.toComplianceRow(line);
            Test.stopTest();
            System.assertEquals('North Clinic', row.accountName, 'The account name should map from the relationship.');
            System.assertEquals('SAP-42', row.sapOrder, 'The SAP order should map from the request header.');
            System.assertEquals(4, row.quantity, 'The quantity should map from the line item.');
        }
    }
}
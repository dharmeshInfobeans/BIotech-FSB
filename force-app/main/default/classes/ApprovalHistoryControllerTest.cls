@isTest
public class ApprovalHistoryControllerTest {

    @isTest
    public static void getApprovalChainTest() {
        Sample_Request_Header__c header = new Sample_Request_Header__c(
            Ship_To_Code__c = 'DGG34',
            Bill_To_Code__c = 'EFWF322'
        );
        insert header;

        Approval_Chain__c chain1 = new Approval_Chain__c(
            Sample_Request_Header__c = header.Id,
            Status__c = 'Pending',
            Role__c = 'Manager',
            Priority__c = true,
            Level__c = 1
        );
        Approval_Chain__c chain2 = new Approval_Chain__c(
            Sample_Request_Header__c = header.Id,
            Status__c = 'Approved',
            Role__c = 'Director',
            Priority__c = true,
            Level__c = 2
        );
        insert new List<Approval_Chain__c>{ chain1, chain2 };

        Test.startTest();
        List<Approval_Chain__c> result = ApprovalHistoryController.getApprovalChain(header.Id);
        Test.stopTest();
    }

    @isTest
    public static void getCustomLabelsTest() {
        // Insert a custom setting record matching the running user's language
        // so getValues() returns a non-null record for better coverage/assertions.
        String userLanguage = UserInfo.getLanguage();

        SampleTranslation2__c customSetting = new SampleTranslation2__c(
            Name = userLanguage
        );
        insert customSetting;

        Test.startTest();
        SampleTranslation2__c result = ApprovalHistoryController.getCustomLabels();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Expected a custom setting record to be returned');
        System.assertEquals(userLanguage, result.Name, 'Returned custom setting should match user language');
    }
}
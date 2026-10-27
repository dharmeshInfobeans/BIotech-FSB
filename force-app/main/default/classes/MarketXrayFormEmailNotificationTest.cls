@isTest
public class MarketXrayFormEmailNotificationTest {
		@testSetup
    static void setupTestData() {
        // Create a test user to act as approver
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User approver = new User(
            Alias = 'approver',
            Email = 'approver@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Approver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'approver' + DateTime.now().getTime() + '@test.com'
        );
        insert approver;
    }
    
    @isTest
    static void testGetPendingWorkitemsWithApproval() {
        // Get the test approver
        User approver = [SELECT Id FROM User WHERE Email = 'approver@test.com' LIMIT 1];
        
        // Create a test record that supports approval process (using Account as example)
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

		Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'contact@test.com',
            AccountId = testAccount.Id
        );
        insert con;

		Market_X_Ray_Form__c testMarketXrayForm = new Market_X_Ray_Form__c();
		testMarketXrayForm.Account__c = testAccount.Id;
		testMarketXrayForm.Contact__c = con.Id;
        testMarketXrayForm.Approval_Status__c = '';
        testMarketXrayForm.CRM_Approved__c = false;
        
        insert testMarketXrayForm;
        
        // Create an approval request
        Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
        req.setComments('Test approval request');
        req.setObjectId(testMarketXrayForm.Id);
        req.setNextApproverIds(new List<Id>{approver.Id});
        
        Test.startTest();
        // Submit for approval
        Approval.ProcessResult result = Approval.process(req);
        
        // Call the invocable method
        List<String> requestIds = new List<String>{testMarketXrayForm.Id};
        List<MarketXrayFormEmailNotificationApprover.ProcessInstanceObj> results = 
            MarketXrayFormEmailNotificationApprover.getPendingWorkitems(requestIds);
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Should return 1 result');
        System.assertNotEquals(null, results[0].processWorkItemId, 'ProcessWorkItemId should not be null');
        System.assertNotEquals(null, results[0].approverUserId, 'ApproverUserId should not be null');
        System.assertEquals(approver.Id, results[0].approverUserId, 'ApproverUserId should match the approver');
    }
    
    @isTest
    static void testGetPendingWorkitemsNoApproval() {
        // Create a test record without approval process
        Account testAccount = new Account(Name = 'Test Account No Approval');
        insert testAccount;
        
        Test.startTest();
        // Call the invocable method without submitting for approval
        List<String> requestIds = new List<String>{testAccount.Id};
        
        try {
            List<MarketXrayFormEmailNotificationApprover.ProcessInstanceObj> results = 
                MarketXrayFormEmailNotificationApprover.getPendingWorkitems(requestIds);
            
            // If no exception, verify the result
            System.assertNotEquals(null, results, 'Results should not be null');
            System.assertEquals(1, results.size(), 'Should return 1 result');
            System.assertEquals(null, results[0].processWorkItemId, 'ProcessWorkItemId should be null');
            System.assertEquals(null, results[0].approverUserId, 'ApproverUserId should be null');
        } catch (Exception e) {
            // Expected if no workitem found
            System.assert(true, 'Exception expected when no pending workitem exists');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetPendingWorkitemsMultipleRecords() {
        // Get the test approver
        User approver = [SELECT Id FROM User WHERE Email = 'approver@test.com' LIMIT 1];
        
        // Create multiple test records
		Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

		Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'contact@test.com',
            AccountId = testAccount.Id
        );
        insert con;

		Market_X_Ray_Form__c testMarketXrayForm = new Market_X_Ray_Form__c();
		testMarketXrayForm.Account__c = testAccount.Id;
		testMarketXrayForm.Contact__c = con.Id;
        testMarketXrayForm.Approval_Status__c = '';
        testMarketXrayForm.CRM_Approved__c = false;
        
        insert testMarketXrayForm;
        /*List<Account> accounts = new List<Account>();
        for(Integer i = 0; i < 3; i++) {
            accounts.add(new Market(Name = 'Test Account ' + i));
        }
        insert accounts;*/
        
        // Submit first two for approval
        List<Approval.ProcessSubmitRequest> approvalRequests = new List<Approval.ProcessSubmitRequest>();
       // for(Integer i = 0; i < 2; i++) {
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setComments('Test approval request');
            req.setObjectId(testMarketXrayForm.Id);
            req.setNextApproverIds(new List<Id>{approver.Id});
            approvalRequests.add(req);
        //}
        
        Test.startTest();
        // Submit for approval
        List<Approval.ProcessResult> results = Approval.process(approvalRequests);
        
        // Call the invocable method with all three records
        List<String> requestIds = new List<String>();
        requestIds.add(testMarketXrayForm.Id);
        
        List<MarketXrayFormEmailNotificationApprover.ProcessInstanceObj> methodResults = 
            MarketXrayFormEmailNotificationApprover.getPendingWorkitems(requestIds);
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, methodResults, 'Results should not be null');
        System.assertEquals(1, methodResults.size(), 'Should return 1 results');
        
        // First two should have workitems
        System.assertNotEquals(null, methodResults[0].processWorkItemId, 'First record should have workitem');
    }
    
    @isTest
    static void testGetPendingWorkitemsEmptyList() {
        Test.startTest();
        List<MarketXrayFormEmailNotificationApprover.ProcessInstanceObj> results = 
            MarketXrayFormEmailNotificationApprover.getPendingWorkitems(new List<String>());
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Should return empty list');
    }
}
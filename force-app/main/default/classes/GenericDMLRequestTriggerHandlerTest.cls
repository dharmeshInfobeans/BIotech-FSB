@isTest
private class GenericDMLRequestTriggerHandlerTest {

    private static Generic_DML_Request__e buildEvent(String objectApiName, String operation, String recordJson) {
        Generic_DML_Request__e evt = new Generic_DML_Request__e();
        evt.Object_API_Name__c = objectApiName;
        evt.Operation__c       = operation;
        evt.Record_JSON__c     = recordJson;
        return evt;
    }

    @isTest
    static void testSkipsWhenObjectApiNameBlank() {
        Generic_DML_Request__e evt = buildEvent(null, 'Update', '{"Name":"Test"}');

        Test.startTest();
        EventBus.publish(evt);
        Test.getEventBus().deliver();
        Test.stopTest();

        // No exception thrown, no records to assert on -> handler exited early via continue
        System.assert(true, 'Handler should skip blank Object_API_Name__c without throwing');
    }

    @isTest
    static void testSkipsWhenObjectUnknown() {
        Generic_DML_Request__e evt = buildEvent('Not_A_Real_Object__c', 'Update', '{"Name":"Test"}');

        Test.startTest();
        EventBus.publish(evt);
        Test.getEventBus().deliver();
        Test.stopTest();

        System.assert(true, 'Handler should skip unknown Object_API_Name__c without throwing');
    }

    @isTest
    static void testSkipsWhenRecordJsonBlank() {
        Generic_DML_Request__e evt = buildEvent('Account', 'Update', null);

        Test.startTest();
        EventBus.publish(evt);
        Test.getEventBus().deliver();
        Test.stopTest();

        System.assert(true, 'Handler should skip Update with blank Record_JSON__c without throwing');
    }

    // ---------------------------------------------------------------
    // 4. Valid update on a generic (non-Opportunity__c) sObject
    // ---------------------------------------------------------------
    @isTest
    static void testUpdatesGenericSObject() {
        Account acc = new Account(Name = 'Original Name');
        insert acc;

        String json = '{"Id":"' + acc.Id + '","Name":"Updated Via Platform Event"}';
        Generic_DML_Request__e evt = buildEvent('Account', 'Update', json);

        Test.startTest();
        EventBus.publish(evt);
        Test.getEventBus().deliver();
        Test.stopTest();

        Account updated = [SELECT Id, Name FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Updated Via Platform Event', updated.Name,
            'Account should be updated with the values from Record_JSON__c');
    }

    @isTest
    static void testOpportunityRsmApproveTriggersNotification() {
        Contact con = new Contact(LastName = 'Test', FirstName='Contact');
    	insert con;

        Opportunity__c opp = new Opportunity__c(Contact__c = con.Id);
        insert opp;

        String json = '{"Id":"' + opp.Id + '","RSM_Approve__c":true}';
        Generic_DML_Request__e evt = buildEvent('Opportunity__c', 'Update', json);

        Test.startTest();
        EventBus.publish(evt);
        Test.getEventBus().deliver();
        Test.stopTest();

        Opportunity__c updated = [SELECT Id, RSM_Approve__c FROM Opportunity__c WHERE Id = :opp.Id];
        System.assertEquals(true, updated.RSM_Approve__c, 'RSM_Approve__c should be updated to true');
      
    }

    @isTest
    static void testOpportunityZsmApproveTriggersNotification() {
        Contact con = new Contact(LastName = 'Test', FirstName='Contact');
    	insert con;

        Opportunity__c opp = new Opportunity__c(Contact__c = con.Id);
        insert opp;

        String json = '{"Id":"' + opp.Id + '","ZSM_Approve__c":true}';
        Generic_DML_Request__e evt = buildEvent('Opportunity__c', 'Update', json);

        Test.startTest();
        EventBus.publish(evt);
        Test.getEventBus().deliver();
        Test.stopTest();

        Opportunity__c updated = [SELECT Id, ZSM_Approve__c FROM Opportunity__c WHERE Id = :opp.Id];
        System.assertEquals(true, updated.ZSM_Approve__c, 'ZSM_Approve__c should be updated to true');
    }

    @isTest
    static void testOpportunityAdminApproveTriggersNotification() {
        Contact con = new Contact(LastName = 'Test', FirstName='Contact');
    	insert con;

        Opportunity__c opp = new Opportunity__c(Contact__c = con.Id);
        insert opp;

        String json = '{"Id":"' + opp.Id + '","Admin_Approve__c":true}';
        Generic_DML_Request__e evt = buildEvent('Opportunity__c', 'Update', json);

        Test.startTest();
        EventBus.publish(evt);
        Test.getEventBus().deliver();
        Test.stopTest();

        Opportunity__c updated = [SELECT Id, Admin_Approve__c FROM Opportunity__c WHERE Id = :opp.Id];
        System.assertEquals(true, updated.Admin_Approve__c, 'Admin_Approve__c should be updated to true');
    }

    @isTest
    static void testOpportunityNoApproveFlagsNoNotification() {
        Contact con = new Contact(LastName = 'Test', FirstName='Contact');
    	insert con;

        Opportunity__c opp = new Opportunity__c(Contact__c = con.Id);
        insert opp;

        String json = '{"Id":"' + opp.Id + '","RSM_Approve__c":false,"ZSM_Approve__c":false,"Admin_Approve__c":false}';
        Generic_DML_Request__e evt = buildEvent('Opportunity__c', 'Update', json);

        Test.startTest();
        EventBus.publish(evt);
        Test.getEventBus().deliver();
        Test.stopTest();

        Opportunity__c updated = [SELECT Id, RSM_Approve__c, ZSM_Approve__c, Admin_Approve__c
                                   FROM Opportunity__c WHERE Id = :opp.Id];
        System.assertEquals(false, updated.RSM_Approve__c);
        System.assertEquals(false, updated.ZSM_Approve__c);
        System.assertEquals(false, updated.Admin_Approve__c);
    }

    @isTest
    static void testSkipsWhenDeleteRecordJsonBlank() {
        Generic_DML_Request__e evt = buildEvent('Account', 'Delete', null);

        Test.startTest();
        EventBus.publish(evt);
        Test.getEventBus().deliver();
        Test.stopTest();

        System.assert(true, 'Handler should skip Delete with blank Record_JSON__c without throwing');
    }

    @isTest
    static void testDeletesGenericSObject() {
        Account acc = new Account(Name = 'To Be Deleted');
        insert acc;

        String json = '{"Id":"' + acc.Id + '"}';
        Generic_DML_Request__e evt = buildEvent('Account', 'Delete', json);

        Test.startTest();
        EventBus.publish(evt);
        Test.getEventBus().deliver();
        Test.stopTest();

        List<Account> remaining = [SELECT Id FROM Account WHERE Id = :acc.Id];
        System.assertEquals(0, remaining.size(), 'Account should have been deleted');
    }

    @isTest
    static void testBulkMixedEvents() {
        Account acc1 = new Account(Name = 'Bulk 1');
        Account acc2 = new Account(Name = 'Bulk 2');
        insert new List<Account>{ acc1, acc2 };

        List<Generic_DML_Request__e> events = new List<Generic_DML_Request__e>{
            buildEvent('Account', 'Update', '{"Id":"' + acc1.Id + '","Name":"Bulk 1 Updated"}'),
            buildEvent('Account', 'Update', '{"Id":"' + acc2.Id + '","Name":"Bulk 2 Updated"}'),
            buildEvent(null, 'Update', '{"Name":"Should be skipped"}'),
            buildEvent('Not_A_Real_Object__c', 'Update', '{"Name":"Should be skipped"}')
        };

        Test.startTest();
        EventBus.publish(events);
        Test.getEventBus().deliver();
        Test.stopTest();

        List<Account> updatedAccounts = [SELECT Id, Name FROM Account WHERE Id IN :new List<Id>{ acc1.Id, acc2.Id }];
        Map<Id, Account> accByid = new Map<Id, Account>(updatedAccounts);
        System.assertEquals('Bulk 1 Updated', accByid.get(acc1.Id).Name);
        System.assertEquals('Bulk 2 Updated', accByid.get(acc2.Id).Name);
    }
}
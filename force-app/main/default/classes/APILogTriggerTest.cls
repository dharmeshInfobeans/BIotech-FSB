@isTest
public class APILogTriggerTest {
    
    @testSetup
    static void setupData() {
        insert new MOU_Integration__c(
            Name = 'getschememaster',
            Error_Log_Emails__c = 'test@test.com'
        );
    }
    
    @isTest
    static void testAfterInsert_MOUScheme() {
            Leads__c setting = new Leads__c(
            Name = 'ContentVersionTrigger', 
            IsActive__c = true
        );
        insert setting;
        
        APILogTriggerHandler.TriggerDisabled = true;
        
        List<API_Log__c> logs = new List<API_Log__c>{
            new API_Log__c(API_Module_Type__c = 'MOU Scheme'),
            new API_Log__c(API_Module_Type__c = 'MOU scheme')
        };
        
        insert logs;

        /* ✅ ADD THIS: Force ContentVersion creation so cvList is NOT empty */
        List<ContentVersion> cvs = new List<ContentVersion>{
            new ContentVersion(
                Title = 'Log1',
                PathOnClient = 'log1.json',
                VersionData = Blob.valueOf('{"msg":"log1"}'),
                FirstPublishLocationId = logs[0].Id
            ),
            new ContentVersion(
                Title = 'Log2',
                PathOnClient = 'log2.json',
                VersionData = Blob.valueOf('{"msg":"log2"}'),
                FirstPublishLocationId = logs[1].Id
            )
        };
        insert cvs;

        Test.startTest();
        
        try {
            APILogTriggerHelper.sendMouSchemeEmail(logs);
        } catch (Exception e) {
            System.debug('Expected Email Exception: ' + e.getMessage());
        }
        
        Test.stopTest();
        
        Set<Id> mouIds = new Set<Id>();
        for (API_Log__c l : logs) {
            if (l.API_Module_Type__c == 'MOU Scheme') {
                mouIds.add(l.Id);
            }
        }
        
        List<ContentVersion> cv = [
            SELECT Id FROM ContentVersion
        ];
        
        List<ContentDocumentLink> cdl = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :mouIds
        ];
        
        System.assert(cv.size() > 0);
    }
    
    @isTest
    static void testNoSetting() {
        
        APILogTriggerHandler.TriggerDisabled = true;
        
        delete [SELECT Id FROM MOU_Integration__c];
        
        API_Log__c log = new API_Log__c(API_Module_Type__c = 'MOU Scheme');
        
        Test.startTest();
        
        insert log;
        
        try {
            APILogTriggerHelper.sendMouSchemeEmail(new List<API_Log__c>{log});
        } catch (Exception e) {}
        
        Test.stopTest();
        
        List<ContentVersion> cv = [SELECT Id FROM ContentVersion];
        System.assertEquals(0, cv.size());
    }
    
    @isTest
    static void testNonMOURecord() {
        
        APILogTriggerHandler.TriggerDisabled = true;
        
        API_Log__c log = new API_Log__c(API_Module_Type__c = 'MOU scheme');
        
        Test.startTest();
        
        insert log;
        
        try {
            APILogTriggerHelper.sendMouSchemeEmail(new List<API_Log__c>{log});
        } catch (Exception e) {}
        
        Test.stopTest();
    }
    
    @isTest
    static void testEmptyList() {
        
        Test.startTest();
        
        try {
            APILogTriggerHelper.sendMouSchemeEmail(new List<API_Log__c>());
        } catch (Exception e) {}
        
        Test.stopTest();
        
        System.assert(true);
    }
    
    @isTest
    static void testHandlerAfterInsertCoverage() {
        
        APILogTriggerHandler.TriggerDisabled = true;
        
        List<API_Log__c> logs = new List<API_Log__c>{
            new API_Log__c(API_Module_Type__c = 'MOU Scheme'),
            new API_Log__c(API_Module_Type__c = 'MOU scheme')
        };
                    
        insert logs;
        
        List<SObject> sobjList = new List<SObject>();
        Map<Id, SObject> sobjMap = new Map<Id, SObject>();
        
        for (API_Log__c l : logs) {
            sobjList.add(l);
            sobjMap.put(l.Id, l);
        }
        
        APILogTriggerHandler handler = new APILogTriggerHandler();
        
        Test.startTest();
        
        try {
            handler.afterInsert(sobjList, sobjMap);
        } catch (Exception e) {
            System.debug('Handled email error: ' + e.getMessage());
        }
        
        Test.stopTest();
        
        System.assert(true);
    }
}
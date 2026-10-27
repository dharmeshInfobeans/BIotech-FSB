@isTest
public class ParentToChildFullTest {
    
    @isTest
    static void testEndpointBlank() {
        
        List<MOU_Integration__c> csList = [
            SELECT Id FROM MOU_Integration__c 
            WHERE Name = 'pdfcustomerscheme'
        ]; 
        
        if(!csList.isEmpty()){
            delete csList;
        }
        
        Account acc = new Account(Name = 'Test Acc', SAP_Code__c  = '1206228');
        insert acc;
        
        Account childAcc = new Account(Name = 'Child Test', SAP_Code__c = '1204859', ParentId = acc.Id);
        insert childAcc;
        
        Scheme_Request__c sr = new Scheme_Request__c(
            Account__c = acc.Id
        );
        insert sr;
        
        Test.startTest();
        
        System.enqueueJob(new PdfCustomerSchemeQueueable(
            'SCH001',
            '2024-01-01',
            acc.Id,
            sr.Id,
            new List<Scheme_Request__c>{sr}
        ));
        
        Test.stopTest();
        
        List<API_Log__c> logs = [SELECT Id, Message__c FROM API_Log__c];
        
    }
    
    class MockHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            String jsonBody = '{ "d": { "results": [ ' +
                '{ "ParentCustomerNumber": "P001", "BundleCustomer": "Y", ' +
                '"to_Children": { "results": [ ' +
                '{ "ChildCustomer": "C001", "BundleCustomer": "N" } ' +
                '] } } ] } }';
            
            if(req.getMethod() == 'POST'){
                jsonBody = '{ "Response": { "PDFData": "' + EncodingUtil.base64Encode(Blob.valueOf('Test PDF')) + '", "Message":"Success" } }';
            }
            
            res.setBody(jsonBody);
            return res;
        }
    }
    
    @testSetup
    static void setupData() {
        
        MOU_Integration__c cs1 = new MOU_Integration__c(
            Name = 'parenttochildsyncingwithoutparam',
            End_Point_URL__c = 'https://test.com',
            Username__c = 'user',
            Password__c = 'pass'
        );
        insert cs1;
        
        MOU_Integration__c cs2 = new MOU_Integration__c(
            Name = 'pdfcustomerscheme',
            End_Point_URL__c = 'https://test.com',
            Username__c = 'user',
            Password__c = 'pass'
        );
        insert cs2;
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Scheme_Request__c sr = new Scheme_Request__c(
            Account__c = acc.Id
        );
        insert sr;
    }
    
    @isTest
    static void testBatchInvoker() {
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        ParentToChildBatchInvoker.FlowInput inp = new ParentToChildBatchInvoker.FlowInput();
        inp.customerNumber = '123';
        
        Test.startTest();
        ParentToChildBatchInvoker.runBatch(new List<ParentToChildBatchInvoker.FlowInput>{inp});
        Test.stopTest();
    }
    
    @isTest
    static void testScheduler() {
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        Test.startTest();
        String cronExp = '0 0 0 1 1 ? 2050';
        System.schedule('Test Job', cronExp, new ParentToChildSyncAPIScheduler());
        Test.stopTest();
    }
    
    @isTest
    static void testQueueable() {
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Scheme_Request__c sr = [SELECT Id, Account__c FROM Scheme_Request__c LIMIT 1];
        
        List<Scheme_Request__c> srList = new List<Scheme_Request__c>{sr};
            
            Test.startTest();
        
        System.enqueueJob(
            new PdfCustomerSchemeQueueable(
                'SCH001',
                '2024-01-01',
                acc.Id,
                sr.Id,
                srList
            )
        );
        
        Test.stopTest();
    }
    
    @isTest
    static void testParentToChildSyncAPIbatch() {
        
        Account parentAcc = new Account(
            Name = 'Parent',
            SAP_Code__c = 'P001'
        );
        insert parentAcc;
        
        Account childAcc = new Account(
            Name = 'Child',
            SAP_Code__c = 'C001'
        );
        insert childAcc;
        
        Map<String, List<String>> parentToChildMap = new Map<String, List<String>>();
        parentToChildMap.put('P001', new List<String>{'C001'});
        
        Map<String, String> bundleFlagMap = new Map<String, String>();
        bundleFlagMap.put('P001', 'X');
        bundleFlagMap.put('C001', '');
        
        List<String> chunkParents = new List<String>{'P001'};
            
            Test.startTest();
        
        Database.executeBatch(
            new ParentToChildSyncAPIbatch(
                parentToChildMap,
                bundleFlagMap,
                chunkParents
            ),
            1
        );
        
        Test.stopTest();
        
        Account updatedChild = [
            SELECT ParentId, Customer_Type__c
            FROM Account
            WHERE Id = :childAcc.Id
        ];
        
        Account updatedParent = [
            SELECT Customer_Type__c
            FROM Account
            WHERE Id = :parentAcc.Id
        ];
        
        System.assertEquals(parentAcc.Id, updatedChild.ParentId);
        System.assertEquals('Bundle', updatedParent.Customer_Type__c);
    }
    
    @isTest
    static void testCreateApiErrorLog() {
        
        Test.startTest();
        
        ParentToChildSyncAPIbatch.createApiErrorLog(
            'MOU scheme',
            'ParentToChildSyncAPIbatch',
            500,
            'ERROR',
            'Test Message',
            '{"request":"test"}',
            '{"response":"test"}'
        );
        
        Test.stopTest();
        
        List<API_Log__c> logs = [
            SELECT Id,
            API_Module_Type__c,
            Class_Name__c,
            Message__c
            FROM API_Log__c
            WHERE Class_Name__c = 'ParentToChildSyncAPIbatch'
        ];
        
    }
}
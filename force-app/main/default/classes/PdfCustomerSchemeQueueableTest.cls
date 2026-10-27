@isTest
public class PdfCustomerSchemeQueueableTest {
    
    class MockHttp200 implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            String dummyPdf = EncodingUtil.base64Encode(Blob.valueOf('PDF DATA'));
            
            res.setBody(
                '{"Response": {' +
                '"Status":"1",' +
                '"Message":"Success",' +
                '"PDFData":"' + dummyPdf + '"' +
                '}}'
            );
            return res;
        }
    }
    
    class MockHttp404 implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setHeader('Content-Type', 'application/json');
            
            res.setBody(
                '{"Response": {' +
                '"Message":"Not Found",' +
                '"PDFData":"dGVzdA=="' +
                '}}'
            );
            return res;
        }
    }
    
    class MockHttp500 implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setHeader('Content-Type', 'application/json');
            
            res.setBody(
                '{"Response": {' +
                '"Message":"Server Error",' +
                '"PDFData":null' +
                '}}'
            );
            return res;
        }
    }
    
    private static Scheme_Request__c createTestData() {
        
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Profile p = [SELECT Id FROM Profile LIMIT 1];
        
        User rsm = new User(
            FirstName = 'RSM',
            LastName = 'User',
            Email = 'rsm@test.com',
            Username = 'rsm' + System.currentTimeMillis() + '@test.com',
            Alias = 'rsm',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        
        User zsm = new User(
            FirstName = 'ZSM',
            LastName = 'User',
            Email = 'zsm@test.com',
            Username = 'zsm' + System.currentTimeMillis() + '@test.com',
            Alias = 'zsm',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        
        User nsm = new User(
            FirstName = 'NSM',
            LastName = 'User',
            Email = 'nsm@test.com',
            Username = 'nsm' + System.currentTimeMillis() + '@test.com',
            Alias = 'nsm',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        
        insert new List<User>{rsm, zsm, nsm};
            
            Scheme_Request__c scheme = new Scheme_Request__c(
                Account__c = acc.Id,
                Scheme_number__c = 'SCH-001',
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addDays(10),
                RSM__c = rsm.Id,
                ZSM__c = zsm.Id,
                NSM__c = nsm.Id
            );
        insert scheme;
        
        MOU_Integration__c setting = new MOU_Integration__c(
            Name = 'pdfcustomerscheme',
            End_Point_URL__c = 'https://dummyurl.com',
            Username__c = 'test',
            Password__c = 'test'
        );
        insert setting;
        
        return scheme;
    }
    
    @isTest
    static void testSuccess200() {
         Leads__c setting = new Leads__c(
            Name = 'ContentVersionTrigger', 
            IsActive__c = true
        );
        insert setting;
        Scheme_Request__c scheme = createTestData();
        
        Test.setMock(HttpCalloutMock.class, new MockHttp200());
        
        Test.startTest();
        System.enqueueJob(new PdfCustomerSchemeQueueable(
            'CS001',
            '2024-01-01',
            scheme.Account__c,
            scheme.Id,
            new List<Scheme_Request__c>{scheme}
        ));
        Test.stopTest();
        
        Scheme_Request__c updated = [
            SELECT PDF_Message__c, PDF_code_data__c
            FROM Scheme_Request__c
            WHERE Id = :scheme.Id
        ];
        
        System.assertEquals('Success', updated.PDF_Message__c);
        System.assertNotEquals(null, updated.PDF_code_data__c);
    }
    
    // =========================
    // TEST: 404
    // =========================
    @isTest
    static void test404Response() {
        
        Scheme_Request__c scheme = createTestData();
        
        Test.setMock(HttpCalloutMock.class, new MockHttp404());
        
        Test.startTest();
        System.enqueueJob(new PdfCustomerSchemeQueueable(
            'CS404',
            '2024-01-01',
            scheme.Account__c,
            scheme.Id,
            new List<Scheme_Request__c>{scheme}
        ));
        Test.stopTest();
        
        Scheme_Request__c updated = [
            SELECT PDF_Message__c
            FROM Scheme_Request__c
            WHERE Id = :scheme.Id
        ];
        
        System.assertEquals('Not Found', updated.PDF_Message__c);
    }
    
    @isTest
    static void testErrorResponse() {
        
        Scheme_Request__c scheme = createTestData();
        
        Test.setMock(HttpCalloutMock.class, new MockHttp500());
        
        Test.startTest();
        System.enqueueJob(new PdfCustomerSchemeQueueable(
            'CS500',
            '2024-01-01',
            scheme.Account__c,
            scheme.Id,
            new List<Scheme_Request__c>{scheme}
        ));
        Test.stopTest();
        
        List<API_Log__c> logs = [
            SELECT Id, Message__c
            FROM API_Log__c
            WHERE Class_Name__c = 'PdfCustomerSchemeQueueable'
        ];
        
    }
    @isTest
    static void testMissingEndpoint() {
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Scheme_Request__c scheme = new Scheme_Request__c(
            Account__c = acc.Id
        );
        insert scheme;
        
        Test.startTest();
        System.enqueueJob(new PdfCustomerSchemeQueueable(
            'CS_NO_ENDPOINT',
            '2024-01-01',
            acc.Id,
            scheme.Id,
            new List<Scheme_Request__c>{scheme}
        ));
        Test.stopTest();
        
        List<API_Log__c> logs = [
            SELECT Id, Message__c, API_Module_Type__c
            FROM API_Log__c
            WHERE Class_Name__c = 'PdfCustomerSchemeQueueable'
        ];   
    }
    
}
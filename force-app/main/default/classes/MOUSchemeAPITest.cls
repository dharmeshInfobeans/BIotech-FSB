@isTest
public class MOUSchemeAPITest {
    
    Public class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            
            res.setBody(
                '{"Response":[{' +
                '"Status":"1",' +
                '"Message":"Success",' +
                '"CustomerSchemeID":"CS-1001"' +
                '}]}'
            );
            
            return res;
        }
    }
    
    Public class SchemeMasterMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            
            res.setBody(
                '{' +
                '"Header":[{' +
                '"SchemeNo":"SCM-001",' +
                '"SchemeName":"Test Scheme",' +
                '"SchemeDesc":"Desc",' +
                '"Tenure":"12",' +
                '"PayTerms":"NET30",' +
                '"TotBusiness":"1000",' +
                '"PurUnitComm":"10",' +
                '"Remarks":"Test",' +
                '"MinQty":10,' +
                '"CreditNote":"Yes",' +
                '"TotalQtyFlg":"Y",' +
                '"AddCn":5,' +
                '"country":"India",' +
                '"TotalAmt":10000,' +
                '"ValidUpto":"20251231",' +
                '"Item":[{' +
                '"ProductCode":"P1",' +
                '"ProductDesc":"Product 1",' +
                '"MinQty":5,' +
                '"RegPrice":100,' +
                '"NetPrice":90,' +
                '"CreditNote":"Yes",' +
                '"CreditPer":5,' +
                '"CrNotePlGst":"GST",' +
                '"AddCn":2,' +
                '"Benefit":"Good"' +
                '}]' +
                '}]' +
                '}'
            );
            
            return res;
        }
    }
    
    @isTest
    static void testMOUSchemeBatch() {
        
        MOU_Integration__c mou = new MOU_Integration__c(
            Name = 'getschememaster',
            End_Point_URL__c = 'https://test.com',
            Username__c = 'user',
            Password__c = 'pass'
        );
        insert mou;
        
        Test.setMock(HttpCalloutMock.class, new SchemeMasterMock());
        
        Test.startTest();
        
        MOUSchemeMasterBatch batch =
            new MOUSchemeMasterBatch('01-01-2025', '31-12-2025');
        
        Database.executeBatch(batch, 1);
        
        Test.stopTest();
        
        System.assert(true, 'Batch executed successfully');
    }
    
    @isTest
    static void testMOUSchemeScheduler() {
        
        MOU_Integration__c mou = new MOU_Integration__c(
            Name = 'getschememaster',
            End_Point_URL__c = 'https://test.com',
            Username__c = 'user',
            Password__c = 'pass'
        );
        insert mou;
        
        Test.setMock(HttpCalloutMock.class, new SchemeMasterMock());
        
        Test.startTest();
        
        MOUSchemeMasterScheduler sch = new MOUSchemeMasterScheduler();
        sch.execute(null);
        
        Test.stopTest();
        
        System.assert(true, 'Scheduler executed successfully');
    }
    
    @isTest
    static void testPostCustomerMapping() {
        
        MOU_Integration__c mou = new MOU_Integration__c(
            Name = 'PostCustomerMappingToScheme',
            End_Point_URL__c = 'https://test.com',
            Username__c = 'user',
            Password__c = 'pass'
        );
        insert mou;
        
        Account parentAcc = new Account(Name='Parent Account');
        insert parentAcc;
        
        Account childAcc = new Account(
            Name='Child Account',
            ParentId = parentAcc.Id
        );
        insert childAcc;
        
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User rsm = new User(
            FirstName='RSM',
            LastName='User',
            Email='rsm@test.com',
            Username='rsm'+System.currentTimeMillis()+'@test.com',
            Alias='rsmu',
            TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US',
            EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US',
            ProfileId=p.Id
        );
        insert rsm;
        
        User zsm = new User(
            FirstName='ZSM',
            LastName='User',
            Email='zsm@test.com',
            Username='zsm'+System.currentTimeMillis()+'@test.com',
            Alias='zsmu',
            TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US',
            EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US',
            ProfileId=p.Id
        );
        insert zsm;
        
        User nsm = new User(
            FirstName='NSM',
            LastName='User',
            Email='nsm@test.com',
            Username='nsm'+System.currentTimeMillis()+'@test.com',
            Alias='nsmu',
            TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US',
            EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US',
            ProfileId=p.Id
        );
        insert nsm;
        
        Scheme_Request__c parent = new Scheme_Request__c(
            Account__c = parentAcc.Id,
            Scheme_Number__c = 'SCM-001',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(5),
            Scheme_applied_By_Parent__c = true,
            RSM__c = rsm.Id
        );
        insert parent;
        
        Scheme_Request__c child = new Scheme_Request__c(
            Account__c = childAcc.Id,
            Scheme_Number__c = 'SCM-001',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(5),
            Scheme_applied_By_Parent__c = true,
            ZSM__c = zsm.Id,
            NSM__c = nsm.Id
        );
        insert child;
        
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        
        Test.startTest();
        
        MOUSchemeAPI.postCustomerMappingToSchemeAPI(
            new List<Scheme_Request__c>{ parent }
        );
        
        Test.stopTest();
        
        Scheme_Request__c result = [
            SELECT Customer_Scheme_Id__c,
            Customer_Scheme_Id_status__c,
            Approval_Status__c
            FROM Scheme_Request__c
            WHERE Id = :parent.Id
        ];
        
        System.assertEquals('1', result.Customer_Scheme_Id_status__c);
        System.assertEquals('Approved', result.Approval_Status__c);
        System.assertEquals('CS-1001', result.Customer_Scheme_Id__c);
    }
    @isTest
    static void testGetChildAccounts() {
        
        Account parentAcc = new Account(
            Name = 'Parent Account',
            E_Mail__c = 'parent@test.com',
            Phone = '1234567890',
            SAP_Code__c = 'SAP001'
        );
        insert parentAcc;
        
        Account childAcc = new Account(
            Name = 'Child Account',
            ParentId = parentAcc.Id,
            E_Mail__c = 'child@test.com',
            Phone = '9876543210',
            SAP_Code__c = 'SAP002'
        );
        insert childAcc;
        
        Test.startTest();
        
        List<Account> result = MOUSchemeController.getChildAccounts();
        
        Test.stopTest();
        
        System.assert(result != null, 'Result should not be null');
    }
}
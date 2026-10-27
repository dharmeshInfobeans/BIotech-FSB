@isTest
public class sapCustomerIntegrationHelperTest {
    
    @TestSetup
    static void setup() {
        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@test.com',
            Username = 'testuser_sap_' + System.currentTimeMillis() + '@test.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US',
            Employee_Code__c = 'EMP001'
        );
        insert u;
    }
    
    static String buildRequestBody() {
        return '{"records":[{"customer":"CUST001","Name":"Test Customer","customerCity":"Ahmedabad","businessCode":"BC01","verticalCode":"VC01","divisionCode":"DC01","zoneCode":"ZC01","stateCode":"SC01","salesDistrict":"SD01","businessName":"Test Biz","countryKey":"IN","verticalName":"Vertical A","divisionName":"Division A","zoneName":"Zone A","stateName":"Gujarat","districtName":"District A","assignmentExternalId":"ASSIGN001","Active":true,"hierarchies":[{"hierarchyExternalId":"HIER001","hierarchyName":"Hierarchy One","isActive":true,"countryKey":"IN","divisionName":"Division A","zoneName":"Zone A","BDM_EMPID":"EMP001","CM_EMPID":null,"DM_EMPID":null,"GM_EMPID":null,"GSRO_EMPID":null,"KAM_EMPID":null,"NSM_EMPID":null,"RM_EMPID":null,"RSM_EMPID":null,"SAE_EMPID":null,"SDE_EMPID":null,"SSE_EMPID":null,"TM_EMPID":null,"ZSM_EMPID":null}]}]}';
    }
    
    @isTest
    static void testHandlePostCreate() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/sap/Customer';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(buildRequestBody());
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        sapCustomerIntegrationWrapper.Response res = sapCustomerIntegrationHelper.handlePost();
        Test.stopTest();
    }
    
    @isTest
    static void testHandlePostUpdate() {
        Account existing = new Account(Name = 'Old Name', External_Id__c = 'CUST001');
        insert existing;
        
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/sap/Customer';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(buildRequestBody());
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        sapCustomerIntegrationWrapper.Response res = sapCustomerIntegrationHelper.handlePost();
        Test.stopTest();
    }
    
    @isTest
    static void testHandlePostInvalidJson() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/sap/Customer';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('invalid json');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        sapCustomerIntegrationWrapper.Response res = sapCustomerIntegrationHelper.handlePost();
        Test.stopTest();
    }
    
    @isTest
    static void testHandlePostNoHierarchies() {
        String body = '{"records":[{"customer":"CUST002","Name":"No Hierarchy Customer","customerCity":"Surat","businessCode":"BC02","verticalCode":"VC02","divisionCode":"DC02","zoneCode":"ZC02","stateCode":"SC02","salesDistrict":"SD02","businessName":"Biz Two","countryKey":"IN","verticalName":"Vertical B","divisionName":"Division B","zoneName":"Zone B","stateName":"Gujarat","districtName":"District B","assignmentExternalId":"ASSIGN002","Active":true,"hierarchies":null}]}';
        
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/sap/Customer';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        sapCustomerIntegrationWrapper.Response res = sapCustomerIntegrationHelper.handlePost();
        Test.stopTest();
    }

}
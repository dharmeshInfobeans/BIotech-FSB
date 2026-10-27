@isTest
private class sapProductIntegrationTest {
  @isTest
    static void testReceiveData() {
        
        String requestBody = '{"records":[{"headerExternalId":"HDR001","groupName":"Test Group","vertical":"V1","productFamily":"PF1","brand":"B1","category":"C1","subCategory":"SC1","activeheader":true,"addition1":"A1","addition2":"A2","addition3":"A3","addition4":"A4","addition5":"A5","lines":[{"lineExternalId":"LINE001","productCode":"PC001","country":"US","language":"EN","activeline":true,"productFamilyLine":"PFL1","currency1":"USD","verticalLine":"VL1","groupNameLine":"GNL1","brandLine":"BL1","categoryLine":"CL1","subCategoryLine":"SCL1","division":"D1","axis":1.5,"cylinderPower":2.0,"diaptor":3.0,"hydrophilicSize":"HS1","sphericalPower":"SP1","dummyProductCode":"DPC1","groupDescription":"GD1","dummyProductDescription":"DPD1","originalProductDescription":"OPD1"}]}]}';
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/sap/productRationalization';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        sapProductIntegrationHelper.receiveData();
        Test.stopTest();
    }
    
    @isTest
    static void testReceiveDataEmpty() {
        
        String requestBody = '{"records":[]}';
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/sap/productRationalization';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        sapProductIntegrationHelper.receiveData();
        Test.stopTest();
    }
    
    @isTest
    static void testReceiveDataInvalidJson() {
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/sap/productRationalization';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('INVALID JSON');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        sapProductIntegrationHelper.receiveData();
        Test.stopTest();
    }
    
    @isTest
static void testHeaderFailure() {
    // Insert a Product_Group__c with a duplicate or required field missing to force header upsert failure
    // Easiest: send two records with same external ID but conflicting required fields
    // OR: send a record that violates a validation rule
    
    String requestBody = '{"records":[' +
        '{"headerExternalId":"HDR_FAIL","groupName":null,"vertical":null,"productFamily":null,"brand":null,"category":null,"subCategory":null,"activeheader":false,"addition1":null,"addition2":null,"addition3":null,"addition4":null,"addition5":null,"lines":[]},' +
        '{"headerExternalId":"HDR_FAIL","groupName":null,"vertical":null,"productFamily":null,"brand":null,"category":null,"subCategory":null,"activeheader":false,"addition1":null,"addition2":null,"addition3":null,"addition4":null,"addition5":null,"lines":[]}' +
        ']}';
    
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestURI = '/services/apexrest/sap/productRationalization';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(requestBody);
    RestContext.request = req;
    RestContext.response = res;
    
    Test.startTest();
    sapProductIntegrationHelper.receiveData();
    Test.stopTest();
}

@isTest
static void testSuccessfulLines() {
    
    String requestBody = '{"records":[{"headerExternalId":"HDR_LINE_TEST","groupName":"Line Test Group","vertical":"V1","productFamily":"PF1","brand":"B1","category":"C1","subCategory":"SC1","activeheader":true,"addition1":null,"addition2":null,"addition3":null,"addition4":null,"addition5":null,' +
        '"lines":[' +
            '{"lineExternalId":"LINE_A01","productCode":"PC_A01","country":"US","language":"EN","activeline":true,"productFamilyLine":"PFL1","currency1":"USD","verticalLine":"VL1","groupNameLine":"GNL1","brandLine":"BL1","categoryLine":"CL1","subCategoryLine":"SCL1","division":"D1","axis":1.5,"cylinderPower":2.0,"diaptor":3.0,"hydrophilicSize":"HS1","sphericalPower":"SP1","dummyProductCode":"DPC1","groupDescription":"GD1","dummyProductDescription":"DPD1","originalProductDescription":"OPD1"},' +
            '{"lineExternalId":"LINE_A02","productCode":"PC_A02","country":"UK","language":"EN","activeline":false,"productFamilyLine":"PFL2","currency1":"GBP","verticalLine":"VL2","groupNameLine":"GNL2","brandLine":"BL2","categoryLine":"CL2","subCategoryLine":"SCL2","division":"D2","axis":null,"cylinderPower":null,"diaptor":null,"hydrophilicSize":null,"sphericalPower":null,"dummyProductCode":null,"groupDescription":null,"dummyProductDescription":null,"originalProductDescription":null}' +
        ']}]}';
    
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestURI = '/services/apexrest/sap/productRationalization';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(requestBody);
    RestContext.request = req;
    RestContext.response = res;
    
    Test.startTest();
    sapProductIntegrationHelper.receiveData();
    Test.stopTest();
}

}
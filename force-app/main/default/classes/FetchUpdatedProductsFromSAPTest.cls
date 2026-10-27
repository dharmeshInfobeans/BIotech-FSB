@isTest
private class FetchUpdatedProductsFromSAPTest {
    @isTest
    static void testFetchUpdatedProductsFromSAPTest() {
        // Test Data for BatchUpsertProductsFromSAP Class
        Plant__c plantA = new Plant__c(Name = 'Test A');
        Plant__c plantB = new Plant__c(Name = 'Test B');
        insert new List<Plant__c> { plantA, plantB };
        
        List<Product_Material_Stock__c> testRecords = new List<Product_Material_Stock__c>();
        testRecords.add(new Product_Material_Stock__c(Material_Code__c = 'Test1', Plant__c = plantA.Id));
        testRecords.add(new Product_Material_Stock__c(Material_Code__c = 'Test2', Plant__c = plantB.Id));
        insert testRecords;
        
        // Test Data for this class
        List<ProductMaterialStockWrapper> testData = new List<ProductMaterialStockWrapper>();
        ProductMaterialStockWrapper prodWrapper = new ProductMaterialStockWrapper();
        prodWrapper.stockType = 'Test';
        prodWrapper.quantity = 1;
        testData.add(prodWrapper);
        
        // Serialize the test data to JSON
        String requestBody = JSON.serialize(testData);
        
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/Product_Material_Stock_Update';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(requestBody);
        
        RestResponse response = new RestResponse();
        
        Test.startTest();
        
        // Test with a valid request
        RestContext.request = request;
        RestContext.response = response;
        FetchUpdatedProductsFromSAP.doPost();
        
        // Verify the response for a valid request
        System.assertEquals(200, response.statusCode, 'Expected a successful response status code');
        
        // Reset the response for the next test
        response = new RestResponse();
        
        // Test with a blank request
        request.requestBody = Blob.valueOf('');
        RestContext.request = request;
        RestContext.response = response;
        FetchUpdatedProductsFromSAP.doPost();
        
        // Verify the response for a blank request
        System.assertEquals(500, response.statusCode, 'Expected an error response status code');
        String responseBody = response.responseBody.toString();
        System.assertNotEquals(-1, responseBody.indexOf('Error'), 'Expected an error message in the response');
        
        Test.stopTest();
    }
}
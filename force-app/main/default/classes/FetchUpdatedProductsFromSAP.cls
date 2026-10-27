@RestResource(urlMapping='/Product_Material_Stock_Update')
global with sharing class FetchUpdatedProductsFromSAP {
    // Test class - FetchUpdatedProductsFromSAPTest

  @HttpPost
    global static void doPost() {
        Map<String, String> responseMap = new Map<String, String>();
        try {
            RestRequest req = RestContext.request;
            String requestBody = req.requestBody.toString();
            BatchUpsertProductsFromSAP updateBatch = new BatchUpsertProductsFromSAP(requestBody);
            Database.executeBatch(updateBatch);
            RestContext.response.statusCode = 200; 
            RestContext.response.addHeader('Content-Type', 'application/json');
            responseMap.put('Mesage', 'Stock update will take some time!');            
            RestContext.response.responseBody = Blob.valueOf(JSON.serializePretty(responseMap));
        }
        catch(Exception e){
            // Handle any errors that occur and set the response as failure
            RestContext.response.statusCode = 500; // HTTP 500 Internal Server Error
            responseMap.clear();
            RestContext.response.addHeader('Content-Type', 'application/json');
            responseMap.put('Error', e.getMessage());
            RestContext.response.responseBody = Blob.valueOf(JSON.serializePretty(responseMap));
        }

    }
}
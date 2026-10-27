@isTest
public class BatchUpsertProductsFromSAPTest {
    @isTest
     static void testBatchUpsertProductsFromSAP() {
       Plant__c plantA = new Plant__c(Name = 'Test A');
        Plant__c plantB = new Plant__c(Name = 'Test B');
        insert new List<Plant__c>{plantA, plantB};

        
        List<Product_Material_Stock__c> testData = new List<Product_Material_Stock__c>();
        testData.add(new Product_Material_Stock__c(Material_Code__c = 'Test1', Plant__c = plantA.Id,Stock_Id__c=plantA.Id+'-'+'Test1'));
        testData.add(new Product_Material_Stock__c(Material_Code__c = 'Test2', Plant__c = plantB.Id,Stock_Id__c=plantB.Id+'-'+'Test2'));
        insert testData;
       
        String testJsonData = JSON.serialize(testData);

        
        Test.startTest();
        BatchUpsertProductsFromSAP batch = new BatchUpsertProductsFromSAP(testJsonData);
        Database.executeBatch(batch);
        Test.stopTest();

  
        //System.assertEquals(0, batch.errorMessages.size(), 'There should be no error messages');
       
    }
}
@isTest
public class BatchDeletionInactiveProductStockTest {
    
    @isTest
    static void testMethod1() {
        // Create test Plant__c and Product_Models__c records for Product_Material_Stock__c lookups
        Plant__c testPlant = new Plant__c(Name = 'Test Plant');
        insert testPlant;
        
        Product__c testPlants = new Product__c(Name = 'Test',Dummy_Product_Code__c='123');
        insert testPlants;
        
        
        Product_Model__c testProductModel = new Product_Model__c(Text_Name__c = 'Test Model', Product__c=testPlants.Id);
        insert testProductModel;
        
        // Create test Product_Material_Stock__c records
        List<Product_Material_Stock__c> testRecords = new List<Product_Material_Stock__c>();
        for (Integer i = 1; i <= 5; i++) {
            Product_Material_Stock__c record = new Product_Material_Stock__c(
                Plant__c = testPlant.Id,
                Product_Models__c = testProductModel.Id,
                Quantity__c = i,
                Material_Code__c = 'MCode' + i,
                isActive__c = false,
                Stock_Id__c = testPlant.Id +'-'+ 'MCode' + i
            );
            testRecords.add(record);
        }
        insert testRecords;
        
        Test.startTest();
        String schedule = '0 0 15 ? * SUN *'; // CRON expression for every Sunday at 3 PM
        ScheduleDeletionInactiveProductStock schedulable = new ScheduleDeletionInactiveProductStock();
        System.schedule('Test Weekly BatchDeletionInactiveProductStock', schedule, schedulable);
        Test.stopTest();
    }
}
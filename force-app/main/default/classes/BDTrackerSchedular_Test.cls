@isTest
public class BDTrackerSchedular_Test {
  
    public static testMethod void testSchedular(){
        Test.startTest();
        BDTrackerSchedular objBatch =new BDTrackerSchedular();
        String sch = '0 0 23 * * ?';
        system.schedule('Test Territory Check', sch, objBatch);
        Test.stopTest();
    }
}
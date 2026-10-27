@isTest
public class CountFOCPercentageTest {
    
    @isTest
    static void testMethod1() {
        // Test case 1: Simple percentage
        CountFOCPercentage.Request req1 = new CountFOCPercentage.Request();
        req1.focText = '10%';
        req1.quantity = 5;
        
        List<CountFOCPercentage.Request> requests = new List<CountFOCPercentage.Request> {
            req1
                };
                    
        Test.startTest();
        List<CountFOCPercentage.Percent> results = CountFOCPercentage.calculateFOCPercentage(requests);
        Test.stopTest();
        
        System.assertEquals(10, results[0].percentage, 'The percentage should be 10%');
    }
    
    @isTest
    static void testMethod2() {
        CountFOCPercentage.Request req1 = new CountFOCPercentage.Request();
        req1.focText = 'FOC (01-99 Pcs) - 5%, FOC (100-299 Pcs) - 10%, FOC (300-999 Pcs) - 15%, FOC (1000 & Above Pcs) - 20%';
        req1.quantity = 89;
        
        List<CountFOCPercentage.Request> requests = new List<CountFOCPercentage.Request> {
            req1
                };
                    
        Test.startTest();
        List<CountFOCPercentage.Percent> results = CountFOCPercentage.calculateFOCPercentage(requests);
        Test.stopTest();
        
    }
    
    @isTest
    static void testMethod3() {
        
        CountFOCPercentage.Request req1 = new CountFOCPercentage.Request();
        req1.focText = 'FOC 5-10 Pcs) - 15%, 11-20 Pcs) - 20%';
        req1.quantity = 7;
        
        CountFOCPercentage.Request req2 = new CountFOCPercentage.Request();
        req2.focText = 'FOC 21 & Above Pcs) - 25%';
        req2.quantity = 25;
        
        CountFOCPercentage.Request req3 = new CountFOCPercentage.Request();
        req3.focText = 'FOC 5-10 Pcs) - 15%';
        req3.quantity = 3;
        
        CountFOCPercentage.Request req4 = new CountFOCPercentage.Request();
        req4.focText = 'Invalid Format';
        req4.quantity = 10;
        
        List<CountFOCPercentage.Request> requests = new List<CountFOCPercentage.Request> {
            req1, req2, req3, req4
                };
                    
        Test.startTest();
        List<CountFOCPercentage.Percent> results = CountFOCPercentage.calculateFOCPercentage(requests);
        Test.stopTest();
    }
}
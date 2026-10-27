@isTest
public class AddProductControllerTest {
   @TestSetup
    static void makeData(){
  
        
    }
    
 public static testmethod void methodName(){
     Opportunity__c test_opp=new Opportunity__c(Name='Test Opportunity');
        insert test_opp;
     List<Opportunity_Product__c> opp_prod=new  List<Opportunity_Product__c>();
         opp_prod.add(new Opportunity_Product__c(Opportunity__c=test_opp.Id));
        insert opp_prod;
     AddProductController.getAllProductByRegion();        
     AddProductController.getProductBySearchTerm('test search'); 
     AddProductController.getOpportunityProducts(String.valueOf(test_opp.Id));
     AddProductController.saveOpportunityProducts(opp_prod);
     for(Opportunity_Product__c prod:opp_prod)
     AddProductController.deleteOpportunityProducts(String.valueOf(prod.id), String.valueOf(test_opp.Id));
	}
}
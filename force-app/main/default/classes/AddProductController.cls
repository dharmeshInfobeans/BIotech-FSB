public class AddProductController {

    @AuraEnabled (cacheable=true)
    public static List<Product__c> getAllProductByRegion(){
        User usr = [Select Id,User_Type__c From User Where Id =: UserInfo.getUserId() LIMIT 1];
        
        return [Select Id,Name,Dummy_Product_Description__c,Dummy_Product_Code__c,Region__c,MSP__c
                FROM Product__c
                WHERE Region__c =: usr.User_Type__c
                AND MSP__c != NULL
                ];
    }
    
    @AuraEnabled
    public static List<Product__c> getProductBySearchTerm(String searchKey){
        String searchTerm = '%'+searchKey+'%';
        User usr = [Select Id,User_Type__c From User Where Id =: UserInfo.getUserId() LIMIT 1];
        
        return [Select Id,Name,Dummy_Product_Description__c,Dummy_Product_Code__c,Region__c,MSP__c
                FROM Product__c
                Where Name like :searchTerm
                AND Region__c =: usr.User_Type__c
                AND MSP__c != NULL 
               ];
    }
    
    @AuraEnabled
    public static List<Opportunity_Product__c> getOpportunityProducts(String oppId){

        return [Select Id,Name,Opportunity__c,Quantity__c,Sales_Price__c,Description__c,List_Price__c,Product__c,Product__r.Name,Product__r.MSP__c
                FROM Opportunity_Product__c
                Where Opportunity__c =:oppId
               ];
    }
    
   @AuraEnabled
    public static void saveOpportunityProducts(List<Opportunity_Product__c>  oppProds){
		upsert oppProds;
    }
    
    @AuraEnabled
    public static String deleteOpportunityProducts(String oppProductId,String oppId ){
		List<Opportunity_Product__c> oppProdLst = [Select Id,Name,Opportunity__c,Product__c
                                                   From Opportunity_Product__c
                                                   Where Opportunity__c =:oppId
                                                   AND Id=:oppProductId ];
        //throw new AddProductControllerException('Test Exception');
        if(!oppProdLst.isEmpty()){
            Database.DeleteResult[] DR_Dels = Database.delete(oppProdLst);
            System.debug('ZZZ In AddProdCont.cls-->Delete Result-->'+DR_Dels);
            return 'deleted';
        }else{
            return null;
        }
    }
    
    public class AddProductControllerException extends Exception{}
}
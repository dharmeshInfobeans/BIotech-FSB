public class MonthlyAOP_TriggerHandler {
   /*
    public void updateNoOfproducts(List<Monthly_AOP__c> mopLst){
        List<String> productCodeLst = new List<String>();
        Id internationalRecTyp = Schema.SObjectType.Monthly_AOP__c.getRecordTypeInfosByName().get('International').getRecordTypeId();
        
        for(Monthly_AOP__c mop: mopLst){
            if(mop.RecordTypeId == internationalRecTyp){
                productCodeLst = new List<String>();
                productCodeLst = mop.Product_Codes_Text__c.split('/');
                mop.No_of_Products__c = productCodeLst.size();
            }
        }
    }
    */
    public void updateRegion(List<Monthly_AOP__c> mopLst, map<String,CIty__c>mapRegionbyCode ){
        for(Monthly_AOP__c monthlyAop : mopLst ){
            if( monthlyAop.Region_Code__c!= null &&  mapRegionbyCode.containsKey(monthlyAop.Region_Code__c)){
            monthlyAop.Region__c = mapRegionbyCode.get(monthlyAop.Region_Code__c).Id;
                }
        }
        
    }
}
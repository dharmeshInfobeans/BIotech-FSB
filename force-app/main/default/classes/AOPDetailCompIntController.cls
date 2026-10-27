public class AOPDetailCompIntController {

    @AuraEnabled
    public static List<Monthly_Product_Plan__c> getAllMppsForAop(String aopId,String fyear,String prodId,String accId){
        List<Monthly_Product_Plan__c> mppLst = new List<Monthly_Product_Plan__c>();
       /* List<Monthly_AOP__c> mopLst = [Select Id,Name,Remaining_Qty__c,
                                       (Select Id,Name,Month__c,Monthly_Plan__c,Year__c,Planned_Amount__c,Planned_Quantity__c,User__c,Product__c,Product__r.Name,Monthly_Target__c,Monthly_Target__r.Account__r.Name
                                        From Monthly_Product_Plans__r)
                                       From Monthly_AOP__c
                                       Where Id=:aopId
                                       AND Financial_Year__c=:fyear
                                       AND Product__c =:prodId
                                       AND Account__c =:accId];*/
        for (Monthly_AOP__c mAOp : [Select Id,Name,Remaining_Qty__c,
             						(Select Id,Name,Month__c,Monthly_Plan__c,Year__c,Planned_Amount__c,Planned_Quantity__c,User__c,Product__c,Product__r.Name,Monthly_Target__c,Monthly_Target__r.Remaining_Qty__c,Monthly_Target__r.Name,Monthly_Target__r.Target_Quantity__c,Monthly_Target__r.Account__r.Name
              						From Monthly_Product_Plans__r)
             						From Monthly_AOP__c
             					    Where Id=:aopId
            					    AND Financial_Year__c=:fyear
            					    AND Product__c =:prodId
             						AND Account__c =:accId]) {
                 for (Monthly_Product_Plan__c mpp : mAOp.Monthly_Product_Plans__r) {
                     mppLst.add(mpp);
                 }
         }
         return mppLst;
    }
}
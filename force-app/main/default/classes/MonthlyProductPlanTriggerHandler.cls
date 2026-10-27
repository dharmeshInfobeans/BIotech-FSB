public inherited sharing class MonthlyProductPlanTriggerHandler {
    
    public static void updateMonthlyAOPWhenMppIsDeleted(List<Monthly_Product_Plan__c> newMPPList,List<Monthly_Product_Plan__c> oldMPPList,System.TriggerOperation triggerEvent){
       
        Switch on triggerEvent {
            when AFTER_DELETE{
               // System.debug('ZZZ In MonthlyProductPlanTriggerHandler.cls-->updateMonthlyAOPWhenMppIsDeleted_M-->In After Delete !');
                Set<Id> mAopIdsToUpdate = new Set<Id>();
                for(Monthly_Product_Plan__c mpp : oldMPPList){
                    if(mpp.Monthly_Target__c != null){
                        mAopIdsToUpdate.add(mpp.Monthly_Target__c);
                    }
                }
                //System.debug('ZZZ In MonthlyProductPlanTriggerHandler.cls-->updateMonthlyAOPWhenMppIsDeleted_M-->AOP SET ToUpdate-->'+mAopIdsToUpdate);
                
                //Update RollupField(Sum Of Planned Qty) on Related AOP Record When mpp is deleted.
                TargetAndPlanningController.rollUpSumOfPlannedQtyToAOP(mAopIdsToUpdate);
                
            }
            when else{}
        }
    }
    
    //@future
    //public static void updateRollupFieldQtyOnAOP()

}
public class ActualAmountRollUpToAOPFromSAPLineItem {

    @InvocableMethod(label='Rollup Actual Amount on AOP' description='This method will rollup the sum of all amount in a SAP Lineitem in AOP')
    public static void updateAOPs(List<ID> mopIds) {
        Set<ID> monthlyAopIds = new Set<ID>(mopIds);
        ActualAmountRollUpToAOPFromSAPLineItem.rollUpSumOfAmountToAOP(monthlyAopIds);  
    }	
    
    @future
    public static void rollUpSumOfAmountToAOP (Set<ID> aopIdsToRoll){
        new ActualAmountRollUpToAOPFromSAPLineItem().summarizeAmountOnAOP(aopIdsToRoll);   
    }
    
    public void summarizeAmountOnAOP(Set<Id> maopIds){
        List<Monthly_AOP__c> mAopToUpdate = new List<Monthly_AOP__c>();
        
        List<Monthly_AOP__c> aops = queryAOPsById(maopIds);
        System.debug('ZZZ In ActualAmountRollUpToAOPFromSAPLineItem.cls-->summarizeAmountOnAOP_M-->Agg QueryResult-->'+aops);
        Map<Id,Decimal> summedQtyByAopId = getRolledUpAmountByAopId(maopIds);
        
        for(Monthly_AOP__c aop : aops){
            Decimal totalSummedQty = 0;
            
            if (summedQtyByAopId.containsKey(aop.Id)) {
                totalSummedQty = summedQtyByAopId.get(aop.Id);
            }
            System.debug('ZZZ In ActualAmountRollUpToAOPFromSAPLineItem.cls-->summarizeAmountOnAOP_M-->totalSummedAmt-->'+totalSummedQty);
            //Determine if Total Qty has Changed
            if (aop.Actual_Amount__c != totalSummedQty ) {
                aop.Actual_Amount__c = totalSummedQty; //Update Actual_Amount__c on  AOP 
                
                //System.debug('AOP FIELDS-->'+aop);
                mAopToUpdate.add(aop); //Add aop to collection to be updated
            }
        }
        
        if(mAopToUpdate.isEmpty() == false){
            Database.SaveResult[] saveResults = Database.update(mAopToUpdate, false);
            System.debug(saveResults);
        }
        
        
    }
    
    
    
    private Map<Id,Decimal> getRolledUpAmountByAopId(Set<Id> mAopIds){
        Map<Id,Decimal> resultsByAopId = new Map<Id,Decimal>();
        
        
        //Summarize Won Opportunity Amounts by Account Id
        AggregateResult[] results = getAggregatePlannedQty(mAopIds);
        
        for (AggregateResult result : results) {
            Id nAOPId = (Id) result.get('AOPId');
            Decimal total = (Decimal) result.get('TotalAmt');
            resultsByAopId.put(nAOPId, total);
        }
        return resultsByAopId;
    }
    
    private AggregateResult[] getAggregatePlannedQty(Set<Id> aopIds){
        return   [SELECT Monthly_AOP__c AOPId  ,SUM(Amount__c) TotalAmt 
                  FROM SAP_Line_Item__c
                  Where Monthly_AOP__c IN : aopIds
                  // on 15042019   AND Monthly_Target__r.RecordType.DeveloperName =:Constants.MONTHLYAOP_INTERNATIONAL_RECORDTYPE_DEVELOPERNAME
                  GROUP BY Monthly_AOP__c];
        
    }
    private List<Monthly_AOP__c> queryAOPsById(Set<Id> aopIds){
        return [Select Id,Actual_Amount__c,Target_Quantity__c,Remaining_Qty__c,Planned_Quantity__c	
                From Monthly_AOP__c Where Id IN : aopIds
               ];
    }
}
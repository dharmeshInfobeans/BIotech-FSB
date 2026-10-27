trigger UserwiseIncentiveDistribution_Trigger on User_Wise_Incentive_Distribution__c (before insert) {
    if(trigger.isBefore){
        if(trigger.isInsert){
            Set<Id> usrInctDistributionIdSt = new Set<Id>();
            List<User_Region_Association__c> usrRegAssociationLst = new List<User_Region_Association__c>();
            Map<Id,List<User_Region_Association__c>> usrIdIsrInctDistributionLstMap = new Map<Id,List<User_Region_Association__c>>();
            
            Id monthlyInctDistributionRecordTypId = Schema.SObjectType.User_Wise_Incentive_Distribution__c.getRecordTypeInfosByName().get('Monthly Incentive Distribution').getRecordTypeId();            
            List<User_Region_Association__c> usrRegionAssociationLst  = [Select Id,Region__r.Name,User__c From User_Region_Association__c];
            if(!usrRegionAssociationLst.isEmpty()){
                for(User_Region_Association__c usrRegAssociation : usrRegionAssociationLst){
                    if(usrIdIsrInctDistributionLstMap.containsKey(usrRegAssociation.User__c)){
                        usrRegAssociationLst = usrIdIsrInctDistributionLstMap.get(usrRegAssociation.User__c);
                        usrRegAssociationLst.add(usrRegAssociation);
                    }
                    else{
                        usrRegAssociationLst = new List<User_Region_Association__c>();
                        usrRegAssociationLst.add(usrRegAssociation);
                        usrIdIsrInctDistributionLstMap.put(usrRegAssociation.User__c,usrRegAssociationLst);
                    }
                }
            }           
            
            for(User_Wise_Incentive_Distribution__c usrInctDistributionToInsrt : trigger.new){
                //if(usrInctDistributionToInsrt.RecordTypeId == monthlyInctDistributionRecordTypId){
                    if(usrIdIsrInctDistributionLstMap.containsKey(usrInctDistributionToInsrt.User__c)){
                        for(User_Region_Association__c usrRegAssociation : usrIdIsrInctDistributionLstMap.get(usrInctDistributionToInsrt.OwnerId)){
                            if(usrInctDistributionToInsrt.Region__c == null){
                                usrInctDistributionToInsrt.Region__c = ''; 
                            }
                            usrInctDistributionToInsrt.Region__c += usrRegAssociation.Region__r.Name +'-'; 
                        }
                        usrInctDistributionToInsrt.Region__c = usrInctDistributionToInsrt.Region__c.SubString(0,usrInctDistributionToInsrt.Region__c.length()-1);
                    } 
                //}//
            }
        }
    }
}
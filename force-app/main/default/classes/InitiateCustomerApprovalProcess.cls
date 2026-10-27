public class InitiateCustomerApprovalProcess {
    
   /* public static Id getIntitiateCustomerApprover(Id OpportunityId ,Id userId, Integer approvalLevel){
        User currentUser = [SELECT Main_Division__c ,Sub_Division__c FROM User WHERE Id =: userId];
        Map<String, String> roleLevelToRoleMap = new Map<String ,String>{ 'BDM_Level__c' => 'BDM__c', 'CM_Level__c' => 'CM__c', 'DM_Level__c' => 'DM__c', 'GM_Level__c' => 'GM__c', 'GSRO_Level__c' => 'GSRO__c', 'KAM_Level__c' => 'KAM__c', 'NSM_Level__c' => 'NSM__c', 'RM_Level__c' => 'RM__c', 'RSM_Level__c' => 'RSM__c', 'SAE_Level__c' => 'SAE__c', 'SDE_Level__c' => 'SDE__c', 'SSE_Level__c' => 'SSE__c', 'TM_Level__c' => 'TM__c', 'ZSM_Level__c' => 'ZSM__c' };
            List<Org_Role_Hierarchy_Assignment__c> rhList = [select Org_Role_Hierarchy__c,Org_Role_Hierarchy__r.BDM__c, Org_Role_Hierarchy__r.BDM_Level__c, Org_Role_Hierarchy__r.CM__c, Org_Role_Hierarchy__r.CM_Level__c, Org_Role_Hierarchy__r.DM__c, Org_Role_Hierarchy__r.DM_Level__c, Org_Role_Hierarchy__r.GM__c, Org_Role_Hierarchy__r.GM_Level__c, Org_Role_Hierarchy__r.GSRO__c, Org_Role_Hierarchy__r.GSRO_Level__c, Org_Role_Hierarchy__r.KAM__c, Org_Role_Hierarchy__r.KAM_Level__c, Org_Role_Hierarchy__r.NSM__c, Org_Role_Hierarchy__r.NSM_Level__c, Org_Role_Hierarchy__r.RM__c, Org_Role_Hierarchy__r.RM_Level__c, Org_Role_Hierarchy__r.RSM__c, Org_Role_Hierarchy__r.RSM_Level__c, Org_Role_Hierarchy__r.SAE__c, Org_Role_Hierarchy__r.SAE_Level__c, Org_Role_Hierarchy__r.SDE__c, Org_Role_Hierarchy__r.SDE_Level__c, Org_Role_Hierarchy__r.SSE__c, Org_Role_Hierarchy__r.SSE_Level__c, Org_Role_Hierarchy__r.TM__c, Org_Role_Hierarchy__r.TM_Level__c, Org_Role_Hierarchy__r.ZSM__c, Org_Role_Hierarchy__r.ZSM_Level__c  from Org_Role_Hierarchy_Assignment__c where Opportunity__c =: opportunityId AND Org_Role_Hierarchy__r.Division__c =: currentUser.Main_Division__c AND Org_Role_Hierarchy__r.Sub_Division__c  =: currentUser.Sub_Division__c AND Is_Active__c = TRUE LIMIT 1];
        //List<Org_Role_Hierarchy_Assignment__c> rhList = [select Org_Role_Hierarchy__c,Org_Role_Hierarchy__r.BDM__c, Org_Role_Hierarchy__r.BDM_Level__c, Org_Role_Hierarchy__r.CM__c, Org_Role_Hierarchy__r.CM_Level__c, Org_Role_Hierarchy__r.DM__c, Org_Role_Hierarchy__r.DM_Level__c, Org_Role_Hierarchy__r.GM__c, Org_Role_Hierarchy__r.GM_Level__c, Org_Role_Hierarchy__r.GSRO__c, Org_Role_Hierarchy__r.GSRO_Level__c, Org_Role_Hierarchy__r.KAM__c, Org_Role_Hierarchy__r.KAM_Level__c, Org_Role_Hierarchy__r.NSM__c, Org_Role_Hierarchy__r.NSM_Level__c, Org_Role_Hierarchy__r.RM__c, Org_Role_Hierarchy__r.RM_Level__c, Org_Role_Hierarchy__r.RSM__c, Org_Role_Hierarchy__r.RSM_Level__c, Org_Role_Hierarchy__r.SAE__c, Org_Role_Hierarchy__r.SAE_Level__c, Org_Role_Hierarchy__r.SDE__c, Org_Role_Hierarchy__r.SDE_Level__c, Org_Role_Hierarchy__r.SSE__c, Org_Role_Hierarchy__r.SSE_Level__c, Org_Role_Hierarchy__r.TM__c, Org_Role_Hierarchy__r.TM_Level__c, Org_Role_Hierarchy__r.ZSM__c, Org_Role_Hierarchy__r.ZSM_Level__c  from Org_Role_Hierarchy_Assignment__c where Opportunity__c =: opportunityId AND Org_Role_Hierarchy__r.Division__c =: 'GT' AND Org_Role_Hierarchy__r.Sub_Division__c  =:'GT'  LIMIT 1];
        Map<String,Id> mapOfRoleLevel = new Map<String,Id>();
        if(!rhList.isEmpty()){
            Org_Role_Hierarchy__c rlsRecord = rhList.get(0).Org_Role_Hierarchy__r;
            for(String levelField : roleLevelToRoleMap.keySet()){
                if((String)rlsRecord.get(levelField) != null && (String)rlsRecord.get(levelField) != '' && (Id)rlsRecord.get(roleLevelToRoleMap.get(levelField)) != null){
                    mapOfRoleLevel.put((String) rlsRecord.get(levelField),(Id) rlsRecord.get(roleLevelToRoleMap.get(levelField)));
                }
            }
            List<String> keys = new List<String>(mapOfRoleLevel.keySet());
            keys.sort();
            
            Integer userIndex = -1;
            for(Integer i = 0; i < keys.size(); i++){
                if(mapOfRoleLevel.get(keys.get(i)) == userId){
                    userIndex = i;
                    break;
                }
            }

            if(userIndex != -1){
                // User found in the hierarchy -> go "approvalLevel" levels above their own position
                Integer targetIndex = userIndex + approvalLevel;
                if(targetIndex < keys.size()){
                    Id approverAbove = mapOfRoleLevel.get(keys.get(targetIndex));
                    System.debug('User found at index ' + userIndex + ', returning approver at index ' + targetIndex + ' : ' + approverAbove);
                    Opportunity__c oppToUpdate = new Opportunity__c(Id = OpportunityId);
                    Boolean shouldUpdate = false;
                    if(approvalLevel == 1){
                        oppToUpdate.RSM__c = approverAbove;
                        shouldUpdate = true;
                    } else if(approvalLevel == 2){
                        oppToUpdate.ZSM__c = approverAbove;
                        shouldUpdate = true;
                    }
                    if(shouldUpdate){
                        update oppToUpdate;
                    }
                    return approverAbove;
                }
                // No one further above in the chain
                return null;
            }
            
            
            if(keys.size() >= approvalLevel){
                System.debug('UserId : '+mapOfRoleLevel.get((String)keys.get(approvalLevel-1)));
                if(mapOfRoleLevel.get((String)keys.get(approvalLevel-1)) != null) return mapOfRoleLevel.get((String)keys.get(approvalLevel-1));
            }
        } 
        return null;
    }*/	
    
    public static Id getIntitiateCustomerApprover(Id OpportunityId, Id userId, Integer approvalLevel){
    Opportunity__c opp = [SELECT Id, CreatedById FROM Opportunity__c WHERE Id = :OpportunityId LIMIT 1];

    User createdByUser = [SELECT Id, L1_Manager__c, L2Manager__c 
                           FROM User 
                           WHERE Id = :opp.CreatedById LIMIT 1];

    Id approverId = null;
    Opportunity__c oppToUpdate = new Opportunity__c(Id = OpportunityId);
    Boolean shouldUpdate = false;

    if(approvalLevel == 1){
        approverId = (Id) createdByUser.get('L1_Manager__c');
        if(approverId != null){
            oppToUpdate.RSM__c = approverId;
            shouldUpdate = true;
        }
    } else if(approvalLevel == 2){
        approverId = (Id) createdByUser.get('L2Manager__c');
        if(approverId != null){
            oppToUpdate.ZSM__c = approverId;
            shouldUpdate = true;
        }
    }

    if(shouldUpdate){
        update oppToUpdate;
    }

    System.debug('Approver for level ' + approvalLevel + ': ' + approverId);
    return approverId;
}
}
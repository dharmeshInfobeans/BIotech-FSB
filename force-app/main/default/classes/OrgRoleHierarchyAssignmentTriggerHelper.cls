public class OrgRoleHierarchyAssignmentTriggerHelper {
    
     private static final List<String> ROLE_FIELDS = new List<String>{
        'ZSM__c','TM__c','SSE__c','SDE__c','SAE__c','RSM__c','GM__c','DM__c','BDM__c',
        'GSRO__c','CM__c','RM__c','NSM__c','KAM__c',
        'NMM__c','BMR__c','MME__c','SMME__c','SMMS__c','SMMW__c','SMMNCZ__c','PM__c',
        'SEMP__c','AMM__c','SEMW__c','SEM__c','RMMMENA__c','RMML__c','AGMMEPMT__c','HMCA__c'
    };

    
    public static void ShareLeadWithUsers(List<Org_Role_Hierarchy_Assignment__c> orgRoleHirerachyList,Map<Id,Org_Role_Hierarchy_Assignment__c> oldMapOfOrgRoleHirerachy){
        List<Lead__Share> shareRecordList = new List<Lead__Share>();
        Set<Id> leadIds = new Set<Id>();
        Set<Id> orgRoleHirerachyIds = new Set<Id>();
        Map<Id,Org_Role_Hierarchy__c> ordRoleHirarchyMap = new Map<Id,Org_Role_Hierarchy__c>();
        Map<Id,Lead__c> mapLead = new Map<Id,Lead__c>();
        /*for(Org_Role_Hierarchy_Assignment__c orgRoleHirerachyAssignment:orgRoleHirerachyList){ 
if(orgRoleHirerachyAssignment.Lead__c != Null && (oldMapOfOrgRoleHirerachy== Null ||  orgRoleHirerachyAssignment.Lead__c != oldMapOfOrgRoleHirerachy.get(orgRoleHirerachyAssignment.Id).Lead__c)){  leadIds.add(orgRoleHirerachyAssignment.Lead__c); }
if(orgRoleHirerachyAssignment?.Org_Role_Hierarchy__c != Null){  orgRoleHirerachyIds.add(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c);  }
}
if(!orgRoleHirerachyIds.isEmpty()){ ordRoleHirarchyMap = new Map<Id,Org_Role_Hierarchy__c>([SELECT Id,ZSM__c,TM__c,SSE__c,SDE__c,SAE__c,RSM__c,GM__c,DM__c,BDM__c,GSRO__c,CM__c,RM__c,NSM__c,KAM__c FROM Org_Role_Hierarchy__c WHERE Id IN:orgRoleHirerachyIds]);}
if(!leadIds.isEmpty()){ mapLead=new Map<Id,Lead__c>([SELECT Id,Campaign__r.Target__c FROM Lead__c WHERE Id IN:leadIds]);}
if(mapLead!= Null && !mapLead.isEmpty() && ordRoleHirarchyMap != Null && !ordRoleHirarchyMap.isEmpty()){
for(Org_Role_Hierarchy_Assignment__c orgRoleHirerachyAssignment:orgRoleHirerachyList){
if(mapLead.containsKey(orgRoleHirerachyAssignment.Lead__c) && ordRoleHirarchyMap.containsKey(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c) && orgRoleHirerachyAssignment.Lead__c != Null){
// ZSM__c 
if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).ZSM__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).ZSM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
//TM__c
if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).TM__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).TM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
//SSE__c
if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SSE__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SSE__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
//SDE__c
if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SDE__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SDE__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
//SAE__c
if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SAE__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SAE__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
//RSM__c
if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).RSM__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).RSM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
//GM__c
if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).GM__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).GM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
//DM__c
if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).DM__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).DM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
// BDM__c
if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).BDM__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).BDM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
// GSRO__c
if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).GSRO__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).GSRO__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
// CM__c
if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).CM__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).CM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
// RM__c
if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).RM__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).RM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
// NSM__c
if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).NSM__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).NSM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
//KAM__c
if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).KAM__c != Null){  shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).KAM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }

}
}
}*/
        
        for(Org_Role_Hierarchy_Assignment__c orgRoleHirerachyAssignment:orgRoleHirerachyList){ 
            //  if(orgRoleHirerachyAssignment.Lead__c != Null && (oldMapOfOrgRoleHirerachy== Null ||  orgRoleHirerachyAssignment.Lead__c != oldMapOfOrgRoleHirerachy.get(orgRoleHirerachyAssignment.Id).Lead__c)){  leadIds.add(orgRoleHirerachyAssignment.Lead__c); }
            if(orgRoleHirerachyAssignment?.Org_Role_Hierarchy__c != Null){  orgRoleHirerachyIds.add(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c);  }
        }
        if(!orgRoleHirerachyIds.isEmpty()){ ordRoleHirarchyMap = new Map<Id,Org_Role_Hierarchy__c>([SELECT Id,ZSM__c,TM__c,SSE__c,SDE__c,SAE__c,RSM__c,GM__c,DM__c,BDM__c,GSRO__c,CM__c,RM__c,NSM__c,KAM__c,
                                                                                                    NMM__c,BMR__c,MME__c,SMME__c,SMMS__c,SMMW__c,
                                                                                                    SMMNCZ__c,
                                                                                                    PM__c,
                                                                                                    SEMP__c,
                                                                                                    AMM__c,
                                                                                                    SEMW__c,
                                                                                                    SEM__c,
                                                                                                    RMMMENA__c,
                                                                                                    RMML__c,
                                                                                                    AGMMEPMT__c,
                                                                                                    HMCA__c FROM Org_Role_Hierarchy__c WHERE Id IN:orgRoleHirerachyIds]);}
        // if(!leadIds.isEmpty()){ mapLead=new Map<Id,Lead__c>([SELECT Id,Campaign__r.Target__c FROM Lead__c WHERE Id IN:leadIds]);}
        if(ordRoleHirarchyMap != Null && !ordRoleHirarchyMap.isEmpty()){
            for(Org_Role_Hierarchy_Assignment__c orgRoleHirerachyAssignment:orgRoleHirerachyList){
                if( ordRoleHirarchyMap.containsKey(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c) && orgRoleHirerachyAssignment.Lead__c != Null){
                    // ZSM__c 
                    if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).ZSM__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).ZSM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
                    //TM__c
                    if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).TM__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).TM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
                    //SSE__c
                    if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SSE__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SSE__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
                    //SDE__c
                    if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SDE__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SDE__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
                    //SAE__c
                    if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SAE__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SAE__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
                    //RSM__c
                    if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).RSM__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).RSM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
                    //GM__c
                    if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).GM__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).GM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
                    //DM__c
                    if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).DM__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).DM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
                    // BDM__c
                    if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).BDM__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).BDM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
                    // GSRO__c
                    if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).GSRO__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).GSRO__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
                    // CM__c
                    if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).CM__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).CM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
                    // RM__c
                    if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).RM__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).RM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
                    // NSM__c
                    if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).NSM__c != Null){ shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).NSM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
                    //KAM__c
                    if(ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).KAM__c != Null){  shareRecordList.add( new Lead__Share(ParentId=orgRoleHirerachyAssignment.Lead__c,UserOrGroupId=ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).KAM__c,AccessLevel='Read',RowCause=Schema.Lead__Share.RowCause.Manual)); }
                    
                    
                    
                    //Marketing fields
                    if (ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).NMM__c != null) {
                        shareRecordList.add(new Lead__Share(ParentId = orgRoleHirerachyAssignment.Lead__c, UserOrGroupId = ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).NMM__c, AccessLevel = 'Read', RowCause = Schema.Lead__Share.RowCause.Manual));
                    }
                    
                    if (ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).BMR__c != null) {
                        shareRecordList.add(new Lead__Share(ParentId = orgRoleHirerachyAssignment.Lead__c, UserOrGroupId = ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).BMR__c, AccessLevel = 'Read', RowCause = Schema.Lead__Share.RowCause.Manual));
                    }
                    
                    if (ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).MME__c != null) {
                        shareRecordList.add(new Lead__Share(ParentId = orgRoleHirerachyAssignment.Lead__c, UserOrGroupId = ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).MME__c, AccessLevel = 'Read', RowCause = Schema.Lead__Share.RowCause.Manual));
                    }
                    
                    if (ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SMME__c != null) {
                        shareRecordList.add(new Lead__Share(ParentId = orgRoleHirerachyAssignment.Lead__c, UserOrGroupId = ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SMME__c, AccessLevel = 'Read', RowCause = Schema.Lead__Share.RowCause.Manual));
                    }
                    
                    if (ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SMMS__c != null) {
                        shareRecordList.add(new Lead__Share(ParentId = orgRoleHirerachyAssignment.Lead__c, UserOrGroupId = ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SMMS__c, AccessLevel = 'Read', RowCause = Schema.Lead__Share.RowCause.Manual));
                    }
                    
                    if (ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SMMW__c != null) {
                        shareRecordList.add(new Lead__Share(ParentId = orgRoleHirerachyAssignment.Lead__c, UserOrGroupId = ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SMMW__c, AccessLevel = 'Read', RowCause = Schema.Lead__Share.RowCause.Manual));
                    }
                    
                    if (ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SMMNCZ__c != null) {
                        shareRecordList.add(new Lead__Share(ParentId = orgRoleHirerachyAssignment.Lead__c, UserOrGroupId = ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SMMNCZ__c, AccessLevel = 'Read', RowCause = Schema.Lead__Share.RowCause.Manual));
                    }
                    
                    if (ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).PM__c != null) {
                        shareRecordList.add(new Lead__Share(ParentId = orgRoleHirerachyAssignment.Lead__c, UserOrGroupId = ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).PM__c, AccessLevel = 'Read', RowCause = Schema.Lead__Share.RowCause.Manual));
                    }
                    
                    if (ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SEMP__c != null) {
                        shareRecordList.add(new Lead__Share(ParentId = orgRoleHirerachyAssignment.Lead__c, UserOrGroupId = ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SEMP__c, AccessLevel = 'Read', RowCause = Schema.Lead__Share.RowCause.Manual));
                    }
                    
                    if (ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).AMM__c != null) {
                        shareRecordList.add(new Lead__Share(ParentId = orgRoleHirerachyAssignment.Lead__c, UserOrGroupId = ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).AMM__c, AccessLevel = 'Read', RowCause = Schema.Lead__Share.RowCause.Manual));
                    }
                    
                    if (ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SEMW__c != null) {
                        shareRecordList.add(new Lead__Share(ParentId = orgRoleHirerachyAssignment.Lead__c, UserOrGroupId = ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SEMW__c, AccessLevel = 'Read', RowCause = Schema.Lead__Share.RowCause.Manual));
                    }
                    
                    if (ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SEM__c != null) {
                        shareRecordList.add(new Lead__Share(ParentId = orgRoleHirerachyAssignment.Lead__c, UserOrGroupId = ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).SEM__c, AccessLevel = 'Read', RowCause = Schema.Lead__Share.RowCause.Manual));
                    }
                    
                    if (ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).RMMMENA__c != null) {
                        shareRecordList.add(new Lead__Share(ParentId = orgRoleHirerachyAssignment.Lead__c, UserOrGroupId = ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).RMMMENA__c, AccessLevel = 'Read', RowCause = Schema.Lead__Share.RowCause.Manual));
                    }
                    
                    if (ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).RMML__c != null) {
                        shareRecordList.add(new Lead__Share(ParentId = orgRoleHirerachyAssignment.Lead__c, UserOrGroupId = ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).RMML__c, AccessLevel = 'Read', RowCause = Schema.Lead__Share.RowCause.Manual));
                    }
                    
                    if (ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).AGMMEPMT__c != null) {
                        shareRecordList.add(new Lead__Share(ParentId = orgRoleHirerachyAssignment.Lead__c, UserOrGroupId = ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).AGMMEPMT__c, AccessLevel = 'Read', RowCause = Schema.Lead__Share.RowCause.Manual));
                    }
                    
                    if (ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).HMCA__c != null) {
                        shareRecordList.add(new Lead__Share(ParentId = orgRoleHirerachyAssignment.Lead__c, UserOrGroupId = ordRoleHirarchyMap.get(orgRoleHirerachyAssignment.Org_Role_Hierarchy__c).HMCA__c, AccessLevel = 'Read', RowCause = Schema.Lead__Share.RowCause.Manual));
                    }
                    
                }
            }
        }
        
        if(!shareRecordList.isEmpty()){
            System.debug('shareRecordList'+shareRecordList);
            Database.SaveResult[] results = Database.insert(shareRecordList, false);
            System.debug('results'+results);
        }
        
    }
    
    
     public static void ShareAccountWithUsers(List<Org_Role_Hierarchy_Assignment__c> orgRoleHirerachyList){

        Set<Id> hierarchyIds = new Set<Id>();
        for(Org_Role_Hierarchy_Assignment__c a : orgRoleHirerachyList){
            if(a.Org_Role_Hierarchy__c != null){
                hierarchyIds.add(a.Org_Role_Hierarchy__c);
            }
        }
        if(hierarchyIds.isEmpty()) return;

        Map<Id, Org_Role_Hierarchy__c> hierarchyMap = new Map<Id, Org_Role_Hierarchy__c>(
            (List<Org_Role_Hierarchy__c>) Database.query(
                'SELECT Id, ' + String.join(ROLE_FIELDS, ',') + ' FROM Org_Role_Hierarchy__c WHERE Id IN :hierarchyIds'
            )
        );

        List<AccountShare> sharesToInsert = new List<AccountShare>();

        for(Org_Role_Hierarchy_Assignment__c a : orgRoleHirerachyList){
            if(a.Account__c == null) continue;
            if(!hierarchyMap.containsKey(a.Org_Role_Hierarchy__c)) continue;

            Org_Role_Hierarchy__c h = hierarchyMap.get(a.Org_Role_Hierarchy__c);
            for(String f : ROLE_FIELDS){
                Object userId = h.get(f);
                if(userId != null){
                    sharesToInsert.add(new AccountShare(
                        AccountId      = a.Account__c,
                        UserOrGroupId = (Id)userId,
                         AccountAccessLevel     = 'Edit',
                        OpportunityAccessLevel = 'Edit',  // required field on AccountShare
                        CaseAccessLevel        = 'Edit',
                        RowCause      = Schema.AccountShare.RowCause.Manual
                    ));
                }
            }
        }

        if(!sharesToInsert.isEmpty()){
            System.debug('Account sharesToInsert: ' + sharesToInsert);
            Database.SaveResult[] results = Database.insert(sharesToInsert, false);
            System.debug('Account share results: ' + results);
        }
    }
    
}
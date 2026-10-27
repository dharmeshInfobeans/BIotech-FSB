trigger OpexTrigger on OPEX__c (before insert, before update) {
    
    if(trigger.IsBefore && (trigger.IsUpdate || trigger.IsInsert)){
        
        Map<String, String>mapUserEmpCode = new Map<String, String>();
        Map<String, String>mapRegionStateCode = new Map<String, String>();
        Set<String> employeeCodeSet = New Set<String>();
        Set<String> stateCodeSet = New Set<String>();
        for(OPEX__c opex: trigger.New){
            if(trigger.IsUpdate){
                OPEX__c oldOpex = trigger.OldMap.get(opex.Id);
                if(oldOpex.Employee_Code__c != opex.Employee_Code__c){
                    employeeCodeSet.add(opex.Employee_Code__c);
                }  
                if(oldOpex.StateCode__c != opex.StateCode__c){
                    stateCodeSet.add(opex.StateCode__c);
                }
            }else{
                employeeCodeSet.add(opex.Employee_Code__c);
                stateCodeSet.add(opex.StateCode__c);
            }

        }
        
            For(User usr : [SELECT Id,Employee_Code__c FROM User WHERE Employee_Code__c IN:employeeCodeSet]){
                mapUserEmpCode.put(usr.Employee_Code__c, usr.id);
            }
            
            For(CIty__c region:[SELECT Id, Region_Code__c FROM CIty__c WHERE Region_Code__c IN:stateCodeSet]){
                mapRegionStateCode.put(region.Region_Code__c, region.Id);
            }        
        
        
        for(OPEX__c opex: Trigger.New){
            if(opex.Employee_Code__c != null && mapUserEmpCode.ContainsKey(opex.Employee_Code__c)){
                opex.Sales_Employee__c = mapUserEmpCode.get(opex.Employee_Code__c);
            }
            if(opex.StateCode__c != null && mapRegionStateCode.ContainsKey(opex.StateCode__c)){
                opex.Region__c = mapRegionStateCode.get(opex.StateCode__c);
            }
        }
        
        
    }
    
    
    
}
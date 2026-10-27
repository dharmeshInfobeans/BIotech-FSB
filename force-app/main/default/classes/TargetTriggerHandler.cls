public class TargetTriggerHandler {
    
    public static void handleAfterInsert(List<Target__c> newTargets) {
        
        List<Campaign__c> campaignsToInsert = new List<Campaign__c>();
        
        for (Target__c target : newTargets) {
            
            // Create Campaign only for Marketing Activities
            if (target.Type__c == 'Marketing Activities') {
                
                Campaign__c camp = new Campaign__c();
                
                // Link Campaign to Target
                camp.Target__c = target.Id;
                
                // Populate Campaign fields
                camp.Categorize__c = target.Driven_By__c;
                camp.Name = target.Conference_Name__c;
                camp.Executer__c = target.OwnerId;
                
                campaignsToInsert.add(camp);
            }
        }
        
        if (!campaignsToInsert.isEmpty()) {
            insert campaignsToInsert;
        }
    }
    
    public static void handleTargetSharing(List<Target__c> targetList){
        List<Target__Share> targetSharetoInsert = new List<Target__Share>();
        Set<String> seenKeys = new Set<String>();
        for(Target__c target : targetList){
            if(target.Reporting_Manager_1_Designation__c!=null && target.Reporting_Manager_1_Designation__c!=target.OwnerId && !seenKeys.contains((String)target.Id+(String)target.Reporting_Manager_1_Designation__c)) {
                Target__Share ts = new Target__Share();
                ts.ParentId = target.Id;
                ts.UserOrGroupId = target.Reporting_Manager_1_Designation__c;
                ts.AccessLevel = 'Edit'; 
                targetSharetoInsert.add(ts);
                seenKeys.add((String)target.Id+(String)target.Reporting_Manager_1_Designation__c);
            }
            if(target.Reporting_Manager_2_Designation__c!=null && target.Reporting_Manager_2_Designation__c!=target.OwnerId  && !seenKeys.contains((String)target.Id+(String)target.Reporting_Manager_2_Designation__c)) {
                Target__Share ts = new Target__Share();
                ts.ParentId = target.Id;
                ts.UserOrGroupId = target.Reporting_Manager_2_Designation__c;
                ts.AccessLevel = 'Edit'; 
                targetSharetoInsert.add(ts);
                seenKeys.add((String)target.Id+(String)target.Reporting_Manager_2_Designation__c);
            }
            if(target.Reporting_Manager_3_Designation__c!=null && target.Reporting_Manager_3_Designation__c!=target.OwnerId  && !seenKeys.contains((String)target.Id+(String)target.Reporting_Manager_3_Designation__c)) {
                Target__Share ts = new Target__Share();
                ts.ParentId = target.Id;
                ts.UserOrGroupId = target.Reporting_Manager_3_Designation__c;
                ts.AccessLevel = 'Edit'; 
                targetSharetoInsert.add(ts);
                seenKeys.add((String)target.Id+(String)target.Reporting_Manager_3_Designation__c);
            }
        }
        
        if(!targetSharetoInsert.isEmpty()){
            Database.SaveResult[] results = Database.insert(targetSharetoInsert, false);
            for(Integer i = 0; i < results.size(); i++){
                if(!results[i].isSuccess()){
                    for(Database.Error err : results[i].getErrors()){
                        System.debug(LoggingLevel.ERROR,
                                     'FAILED for Target Id: ' + targetSharetoInsert[i].ParentId +
                                     ' | UserOrGroupId: ' + targetSharetoInsert[i].UserOrGroupId +
                                     ' | Status: ' + err.getStatusCode() +
                                     ' | Message: ' + err.getMessage());
                    }
                } else {
                    System.debug(LoggingLevel.INFO,
                                 'SUCCESS for Target Id: ' + targetSharetoInsert[i].ParentId +
                                 ' | UserOrGroupId: ' + targetSharetoInsert[i].UserOrGroupId +
                                 ' | Share Id: ' + results[i].getId());
                }
            }
        }
    }
}
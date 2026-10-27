public class LeadTriggerHandler implements TriggerInterface{
    
    //Use this variable to disable this trigger from transaction
    public static Boolean TriggerDisabled = false;
    public static Boolean skipConversionLogic = false;
    //check if the trigger is disabled from transaction
    public Boolean isDisabled(){
        return TriggerDisabled;
    }
    
    public void beforeInsert(List<sObject> newList) {
        List<Lead__c> leadList=(List<Lead__c>)newList;
        LeadsTriggerHelperClass.beforeLeadInsert(leadList);
    }
    
    public void afterInsert(List<sObject> newList , Map<Id, sObject> newMap) {
        List<Lead__c> leadList=(List<Lead__c>)newList;
        LeadsTriggerHelperClass.insAddressData(leadList);
        
    }
    
    public void beforeUpdate(List<sObject> newList, Map<Id, sObject> newMap, List<sObject> oldList, Map<Id, sObject> oldMap) {
        List<lead__c> leadList=(List<lead__c>)newList;
        Map<Id,Lead__c> leadOldmap=(Map<Id,Lead__c>)oldMap;
        if (skipConversionLogic) return;
        LeadsTriggerHelperClass.createAccountData(leadList,leadOldmap);
        //LeadsTriggerHelperClass.getLeadOwnerData(leadList,leadOldmap);
    }
    
    public void afterUpdate(List<sObject> newList, Map<Id, sObject> newMap,  List<sObject> oldList, Map<Id, sObject> oldMap) {
        Map<Id,Lead__c> leadOldmap=(Map<Id,Lead__c>)oldMap;
        List<lead__c> leadList=(List<lead__c>)newList;
        System.debug('After update');
        LeadsTriggerHelperClass.submitForApproval(leadList,leadOldmap);
        LeadsTriggerHelperClass.updateCampaignData(leadList,leadOldmap);
        
    }
    
    public void beforeDelete(List<sObject> oldList , Map<Id, sObject> oldMap) {
        
    }
    
    public void afterDelete(List<sObject> oldList , Map<Id, sObject> oldMap) {
        
    }
    
    public void afterUnDelete(List<sObject> newList, Map<Id, sObject> newMap) {
        
    }
    
    //Dhruv Start - Ortho Checkbox 
    public static void checkOrthoOwner(List<Lead__c> leadList){
        Set<Id> ownerIds = new Set<Id>();
        
        for(Lead__c leadRec : leadList){
            if(leadRec.OwnerId != null){
                ownerIds.add(leadRec.OwnerId);
            }
        }
        
        if(ownerIds.isEmpty()) return;
        
        Map<Id, User> mapOfUser = new Map<Id, User>(
            [SELECT Id, Vertical__c 
             FROM User 
             WHERE Id IN :ownerIds]
        );
         for(Lead__c leadRec : leadList){
         leadRec.Is_Ortho__c = mapOfUser.get(leadRec.OwnerId).Vertical__c == 'ORTHOPAEDICS' ? TRUE : FALSE;   
        }
        
    }

//Dhruv End

/// Dhruv start - For the org role hierarchy assignment to new created lead
public static void assingOrgRoleHirearchy(List<Lead__c> leadList,Boolean isUpdate){
    if(skipConversionLogic) return;
    Set<Id> ownerIds = new Set<Id>();
    List<Lead__c> indianLeads = new List<Lead__c>();
    if(!leadList.isEmpty()){
        for(Lead__c ld : leadList){
            ownerIds.add(ld.OwnerId);
            indianLeads.add(ld);
        }
        System.debug('LeadList -->'+indianLeads);

        // If this is an update, delete existing assignments for these leads first
        if(isUpdate){
            Set<Id> leadIds = new Set<Id>();
            for(Lead__c ld : indianLeads){
                leadIds.add(ld.Id);
            }
            List<Org_Role_Hierarchy_Assignment__c> existingAssignments = [
                SELECT Id 
                FROM Org_Role_Hierarchy_Assignment__c 
                WHERE Lead__c IN :leadIds
            ];
            if(!existingAssignments.isEmpty()){
                Database.DeleteResult[] delResults = Database.delete(existingAssignments, false);
                for(Database.DeleteResult dr : delResults){
                    if(!dr.isSuccess()){
                        for(Database.Error err : dr.getErrors()){
                            System.debug('Error deleting existing Org Role Hierarchy Assignment: ' + err.getStatusCode() + ': ' + err.getMessage());
                        }
                    }
                }
            }
        }

        Map<Id,User> salesOwnerMap = new Map<Id,User>([SELECT id,Country__c,Sales_District__c,Sub_Division__c,Main_Division__c FROM User WHERE Id in :ownerIds ]);
        
        List<Org_Role_Hierarchy_Assignment__c> orgRoleHierarchyAssignmentRecordToInsert = new List<Org_Role_Hierarchy_Assignment__c>();
        
        Map<String, Org_Role_Hierarchy__c> orgRoleMap = new Map<String, Org_Role_Hierarchy__c>();
        for (Org_Role_Hierarchy__c rec : [
            SELECT Id, External_ID__c,Name 
            FROM Org_Role_Hierarchy__c WHERE Business_Mapping__c = true
        ]) {
            orgRoleMap.put(rec.External_ID__c, rec);
        }
        SYstem.debug('orgRoleMap---'+orgRoleMap.keySet());
        SYstem.debug('getting key--'+orgRoleMap.get('MKT-GT-GT-INC051'));
        if(orgRoleMap.isEmpty()){
            for (Lead__c leadRecord : indianLeads) {
                leadRecord.addError(
                    'No Org Role Hierarchy found for the combination: . Please ensure the Owner\'s Division, Sub Division, and Sales District are correctly configured.'
                );
            }
            
        }
        else{
            for(Lead__c leadRecord : indianLeads){
                System.debug('LeadList indianLeads -->'+leadRecord);
                if(salesOwnerMap.containsKey(leadRecord.OwnerId)){
                    
                    String md = salesOwnerMap.get(leadRecord.OwnerId).Main_Division__c;
                    String sd = salesOwnerMap.get(leadRecord.OwnerId).Sub_Division__c;
                    String salesDis = salesOwnerMap.get(leadRecord.OwnerId).Sales_District__c;
                    String country = salesOwnerMap.get(leadRecord.OwnerId).Country__c;
                    
                    System.debug('LeadList indianLeads -->'+md+sd+salesDis+country);
                    if(md ==null || sd == null || salesDis == null || country == null ) continue;
                    System.debug('LeadList indianLeads -->'+md+sd+salesDis+country);
                    String orgRoleCombinationSales = md +'-'+ sd +'-'+  salesDis;
                    Id orgRoleHierarchyIdSales = orgRoleMap.containsKey(orgRoleCombinationSales)? orgRoleMap.get(orgRoleCombinationSales).Id : null;
                    String orgRoleHierarchyNameSales = orgRoleMap.containsKey(orgRoleCombinationSales)? orgRoleMap.get(orgRoleCombinationSales).Name : null;
                    if(orgRoleHierarchyIdSales == null) continue;
                    String externalIdSales = 'Sales-'+md+'-'+sd+'-'+salesDis+'-'+country+'-'+leadRecord.id;
                    orgRoleHierarchyAssignmentRecordToInsert.add(new Org_Role_Hierarchy_Assignment__c(
                        Name= orgRoleHierarchyNameSales+'-Sales-Assignment',
                        Lead__c = leadRecord.Id,
                        Org_Role_Hierarchy__c = orgRoleHierarchyIdSales,
                        External_ID__c = externalIdSales,
                        Is_Active__c = true));
                    
                    if(md ==null || sd == null || salesDis == null || country == null ) continue;
                    String orgRoleCombination ='';
                    if(country == 'TR'){
                        orgRoleCombination = 'MKT-TURKEY';
                    }
                    else if(country == 'EG'){
                        orgRoleCombination = 'MKT-EGYPT';
                    }
                    else if(country == 'MA'){
                        orgRoleCombination = 'MKT-MOROCCO';
                    }
                    else if(country == 'ES'){
                        orgRoleCombination = 'MKT-SPAIN';
                    }
                    else if(country == 'DE'){
                        orgRoleCombination = 'MKT-GERMANY';
                    }
                    else if(country == 'BR'){
                        orgRoleCombination = 'MKT-BRAZIL';
                    }
	                    else if(country == 'CO'){
                        orgRoleCombination = 'MKT-COLOMBIA';
                    }
                    else{
                        orgRoleCombination = 'MKT-'+md +'-'+ sd +'-'+  salesDis;
                    }
                    Id orgRoleHierarchyId = orgRoleMap.containsKey(orgRoleCombination)? orgRoleMap.get(orgRoleCombination).Id : null;
                    String orgRoleHierarchyName = orgRoleMap.containsKey(orgRoleCombination)? orgRoleMap.get(orgRoleCombination).Name : null;
                    if(orgRoleHierarchyId == null) continue;
                    String externalId = '';
                    if(country == 'TR'){
                        externalId = 'MKT-TURKEY'+'-'+leadRecord.id;
                    }
                    else if(country == 'EG'){
                        externalId = 'MKT-EGYPT'+'-'+leadRecord.id;
                    }
                    else if(country == 'MA'){
                        externalId = 'MKT-MOROCCO'+'-'+leadRecord.id;
                    }
                    else if(country == 'ES'){
                        externalId = 'MKT-SPAIN'+'-'+leadRecord.id;
                    }
                    else if(country == 'DE'){
                        externalId = 'MKT-GERMANY'+'-'+leadRecord.id;
                    }
                    else if(country == 'BR'){
                        externalId = 'MKT-BRAZIL'+'-'+leadRecord.id;
                    }
	                    else if(country == 'CO'){
                        externalId = 'MKT-COLOMBIA'+'-'+leadRecord.id;
                    }
                    else{
                        externalId = 'MKT-'+md+'-'+sd+'-'+salesDis+'-'+country+'-'+leadRecord.id;
                    }
                    orgRoleHierarchyAssignmentRecordToInsert.add(new Org_Role_Hierarchy_Assignment__c(
                        Name= orgRoleHierarchyName+'-Assignment',
                        Lead__c = leadRecord.Id,
                        Org_Role_Hierarchy__c = orgRoleHierarchyId,
                        External_ID__c = externalId,
                        Is_Active__c = true));
                    
                }
            }
        }
        if(!orgRoleHierarchyAssignmentRecordToInsert.isEmpty()){
            Database.SaveResult[] results = Database.insert(orgRoleHierarchyAssignmentRecordToInsert, false);
            
            for (Database.SaveResult sr : results) {
                if (sr.isSuccess()) {
                    System.debug('Successfully inserted account. Org Role Hirearchy Assignment ID: ' + sr.getId());
                } else {
                    for(Database.Error err : sr.getErrors()) {
                        System.debug('The following error has occurred.');                    
                        System.debug(err.getStatusCode() + ': ' + err.getMessage());
                        System.debug('Org Role Hirearchy Assignment fields that affected this error: ' + err.getFields());
                    }
                }
            }
        }
    }
}
//Dhruv End

// Added By Mohd Owais
  /*  public static void populateCityWiseUserOnLeadCreation(List<Lead__c> leadList){
        System.debug('populateCityWiseUserOnLeadCreation start');
        Map<Id,User> userIdWithUser = new Map<Id,User>([SELECT Id, Name, Username, Email, UserRoleId, UserRole.Name FROM User WHERE isActive=true AND ( UserRole.Name LIKE '%SSE%'  OR UserRole.Name LIKE '%BDM%'  OR UserRole.Name LIKE '%Sales%')]);
        System.debug('userIdWithUser'+userIdWithUser);
        Set<Id> rsmOwnerIds = new Set<Id>();
        Map<Id,Map<String,CityWise__c>> mapOfUserWithDistStateZone = new Map<Id,Map<String,CityWise__c>>();
        Set<String> typeSet = new Set<String>{'State','Zone','District'};
        for(Lead__c lead:leadList){ if(userIdWithUser.containsKey(lead.OwnerId)){  rsmOwnerIds.add(lead.OwnerId); } }
        if(rsmOwnerIds.isEmpty()) return;
        
        for(CityWise__c cityWise:[SELECT Id,State__c,Zone__c,GSRO__c, NSM__c, ZSM__c,RSM__c,Type__c  FROM CityWise__c WHERE Type__c IN:typeSet AND RSM__c IN:rsmOwnerIds]){
            if(!mapOfUserWithDistStateZone.containsKey(cityWise.RSM__c)){
                System.debug('inside citywise'+cityWise);
                Map<String,CityWise__c> mapOfZoneAndState = new Map<String,CityWise__c>();
                mapOfZoneAndState.put(cityWise.State__c,cityWise);
                 mapOfZoneAndState.put(cityWise.Zone__c,cityWise);
                mapOfUserWithDistStateZone.put(cityWise.RSM__c,mapOfZoneAndState);
            }else{
                Map<String,CityWise__c> mapOfZoneAndState = mapOfUserWithDistStateZone.get(cityWise.RSM__c);
                  mapOfZoneAndState.put(cityWise.State__c,cityWise);
                 mapOfZoneAndState.put(cityWise.Zone__c,cityWise);
                  mapOfUserWithDistStateZone.put(cityWise.RSM__c,mapOfZoneAndState);
                
            }  
        }
        
        System.debug('mapOfUserWithDistStateZone'+mapOfUserWithDistStateZone);
        for(Lead__c lead:leadList){
            if(mapOfUserWithDistStateZone.containskey(lead.ownerId)){
               
                 Map<String,CityWise__c> mapOfZoneAndState = mapOfUserWithDistStateZone.get(lead.ownerId);
                 System.debug('inside last condition'+mapOfZoneAndState);
                lead.RSM__c=mapOfZoneAndState.containsKey(lead.Billing_state__c) ? mapOfZoneAndState.get(lead.Billing_state__c).RSM__c : mapOfZoneAndState.containsKey(lead.ZoneNew__c) ? mapOfZoneAndState.get(lead.ZoneNew__c).RSM__c : Null;
                lead.ZSM__c=mapOfZoneAndState.containsKey(lead.Billing_state__c) ? mapOfZoneAndState.get(lead.Billing_state__c).ZSM__c : mapOfZoneAndState.containsKey(lead.ZoneNew__c) ? mapOfZoneAndState.get(lead.ZoneNew__c).ZSM__c : Null;
                lead.NSM_New__c=mapOfZoneAndState.containsKey(lead.Billing_state__c) ? mapOfZoneAndState.get(lead.Billing_state__c).NSM__c : mapOfZoneAndState.containsKey(lead.ZoneNew__c) ? mapOfZoneAndState.get(lead.ZoneNew__c).NSM__c : Null;
                lead.GSRO_New__c=mapOfZoneAndState.containsKey(lead.Billing_state__c) ? mapOfZoneAndState.get(lead.Billing_state__c).GSRO__c : mapOfZoneAndState.containsKey(lead.ZoneNew__c) ? mapOfZoneAndState.get(lead.ZoneNew__c).GSRO__c : Null;
            }
        }
        System.debug('leadList'+leadList);
    }
    // Added By Owais End Here
// Dhruv start - For the org role hierarchy assignment to new created lead
/* public static void assingOrgRoleHirearchy(List<Lead__c> leadList){
if(!leadList.isEmpty()){
List<Org_Role_Hierarchy_Assignment__c> orgRoleHierarchyAssignmentRecordToInsert = new List<Org_Role_Hierarchy_Assignment__c>();
User ownerOfList = [SELECT Main_Division__c, Sub_Division__c, Sales_District__c, Country__c FROM User WHERE Id =: leadList.get(0).OwnerId];
String baseCombination = ownerOfList.Main_Division__c + '-' + ownerOfList.Sub_Division__c + '-' + ownerOfList.Sales_District__c;

Set<Id> accountIds = new Set<Id>();
for(Lead__c leadRecord : leadList){
if(leadRecord.Account__c != null){
accountIds.add(leadRecord.Account__c);
}
}

Map<Id, Account> accountMap = new Map<Id, Account>([SELECT Id, SAP_Code__c FROM Account WHERE Id IN :accountIds]);

List<Lead__c> leadsWithSapCode = new List<Lead__c>();
List<Lead__c> leadsWithoutSapCode = new List<Lead__c>();

for(Lead__c leadRecord : leadList){
if(leadRecord.Account__c != null && accountMap.containsKey(leadRecord.Account__c) && String.isNotBlank(accountMap.get(leadRecord.Account__c).SAP_Code__c)){
leadsWithSapCode.add(leadRecord);
} else {
leadsWithoutSapCode.add(leadRecord);
}
}

Set<String> orgRoleCombinations = new Set<String>();

if(!leadsWithoutSapCode.isEmpty()){
orgRoleCombinations.add(baseCombination);
orgRoleCombinations.add('MKT-' + baseCombination);
}

for(Lead__c leadRecord : leadsWithSapCode){
orgRoleCombinations.add(accountMap.get(leadRecord.Account__c).SAP_Code__c + '-' + baseCombination);
}

List<Org_Role_Hierarchy__c> orhRecords = [SELECT Id, Name, External_Id__c FROM Org_Role_Hierarchy__c WHERE External_Id__c IN :orgRoleCombinations];

Map<String, Org_Role_Hierarchy__c> orhByExternalId = new Map<String, Org_Role_hierarchy__c>();
for(Org_Role_Hierarchy__c orh : orhRecords){
orhByExternalId.put(orh.External_Id__c, orh);
}

if(!leadsWithoutSapCode.isEmpty()){
List<Org_Role_Hierarchy__c> standardOrhRecords = new List<Org_Role_Hierarchy__c>();
for(String combo : new List<String>{baseCombination, 'MKT-' + baseCombination}){
if(orhByExternalId.containsKey(combo)){
standardOrhRecords.add(orhByExternalId.get(combo));
}
}

if(standardOrhRecords.isEmpty()){
for(Lead__c leadRecord : leadsWithoutSapCode){
leadRecord.addError('No Org Role Hierarchy found for the combinations: ' + baseCombination + ', MKT-' + baseCombination + '. Please ensure the Owner\'s Division, Sub Division, and Sales District are correctly configured.');
}
} else {
for(Lead__c leadRecord : leadsWithoutSapCode){
for(Org_Role_Hierarchy__c orh : standardOrhRecords){
orgRoleHierarchyAssignmentRecordToInsert.add(new Org_Role_Hierarchy_Assignment__c(Name = leadRecord.Name + '-' + orh.Name, Lead__c = leadRecord.Id, Org_Role_Hierarchy__c = orh.Id, Is_Active__c = true));
}
}
}
}

for(Lead__c leadRecord : leadsWithSapCode){
String sapCombo = accountMap.get(leadRecord.Account__c).SAP_Code__c + '-' + baseCombination;
if(orhByExternalId.containsKey(sapCombo)){
Org_Role_Hierarchy__c orh = orhByExternalId.get(sapCombo);
orgRoleHierarchyAssignmentRecordToInsert.add(new Org_Role_Hierarchy_Assignment__c(Name = leadRecord.Name + '-' + orh.Name, Lead__c = leadRecord.Id, Org_Role_Hierarchy__c = orh.Id, Is_Active__c = true));
} else {
leadRecord.addError('No Org Role Hierarchy found for the SAP Code combination: ' + sapCombo + '. Please ensure the SAP Code and the Owner\'s Division, Sub Division, and Sales District are correctly configured.');
}
}

if(!orgRoleHierarchyAssignmentRecordToInsert.isEmpty()){
Database.SaveResult[] results = Database.insert(orgRoleHierarchyAssignmentRecordToInsert, false);
for (Database.SaveResult sr : results) {
if (sr.isSuccess()) {
System.debug('Successfully inserted Org Role Hierarchy Assignment. ID: ' + sr.getId());
} else {
for(Database.Error err : sr.getErrors()) {
System.debug('The following error has occurred.');
System.debug(err.getStatusCode() + ': ' + err.getMessage());
System.debug('Org Role Hierarchy Assignment fields that affected this error: ' + err.getFields());
}
}
}
}
}
}*/
//Dhruv End
}
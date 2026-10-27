public class OpportunityTriggerHandler {
    
    public static void validateEvaluationStage(List<Opportunity__c> newList, Map<Id, Opportunity__c> oldMap){
        Set<Id> oppId = new Set<Id>();
        for(Opportunity__c opp : newList){
            if(opp.Status__c == 'Presentation' && oldMap.get(opp.Id).Status__c != 'Presentation'){
                oppId.add(opp.Id);
            }
        }
        Map<Id, Integer> mapOfInteger = new Map<Id, Integer>();
        List<AggregateResult> aggResult = [SELECT Opportunity__c oppId, COUNT(Id) cnt FROM Opportunity_Product__c WHERE Opportunity__c IN :oppId GROUP BY Opportunity__c];
        for(AggregateResult agg : aggResult){
            mapOfInteger.put((Id) agg.get('oppId'), (Integer) agg.get('cnt'));
        }
        for(Opportunity__c opp : newList){
            if(oppId.contains(opp.Id)){
                if(mapOfInteger.get(opp.Id)== null || mapOfInteger.get(opp.Id)==0){
                    opp.Status__c.addError('You cannot move to Presentation without adding Opportunity Products.');
                }
            }
        }
        
    }
    
  private static final List<String> ROLE_PREFIXES = new List<String>{
        'AGM_PD','AGMMEPMT','AMM','BDM','BMR','CM','DM','GM','GSRO',
        'Head_PMT_PD','HMCA','KAM','MME','NMM','NSM','PM','RM','RMML',
        'RMMMENA','RSM','SAE','SDE','SEM','SEMP','SEMW','SMME','SMMNCZ',
        'SMMS','SMMW','SSE','TM','ZSM'
    };
 
    private static final String VACANT = 'Vacant';
 
   /* public static void assingOrgRoleHirearchy(List<Opportunity__c> oppList){
        if(oppList.isEmpty()){
            return;
        }
 
        String orgRoleCombination = '';
        Set<Id> oppIdSet = new Set<Id>();
        List<Org_Role_Hierarchy_Assignment__c> orgRoleHierarchyAssignmentRecordToInsert = new List<Org_Role_Hierarchy_Assignment__c>();
 
        User ownerOfList = [SELECT Main_Division__c, Sub_Division__c, Sales_District__c FROM User WHERE Id =: oppList.get(0).OwnerId];
        orgRoleCombination = ownerOfList.Main_Division__c + '-' + ownerOfList.Sub_Division__c + '-' + ownerOfList.Sales_District__c;
 
        // Build the full field list dynamically so we don't have to hand-type
        // ~65 field names, and so it stays correct if ROLE_PREFIXES changes.
        Set<String> orhFieldSet = new Set<String>{'Id','Name','Sales_District__c','Region__c','Zone_Code__c'};
        for(String prefix : ROLE_PREFIXES){
            orhFieldSet.add(prefix + '_EMPID__c');
            orhFieldSet.add(prefix + '_Level__c');
        }
        String orhQuery = 'SELECT ' + String.join(new List<String>(orhFieldSet), ', ') +
                           ' FROM Org_Role_Hierarchy__c WHERE External_Id__c = :orgRoleCombination';
        List<Org_Role_Hierarchy__c> orhRecord = Database.query(orhQuery);
 
        if(orhRecord.isEmpty()){
            for (Opportunity__c oppRecord : oppList) {
                oppRecord.addError(
                    'No Org Role Hierarchy found for the combination: ' + orgRoleCombination +
                    '. Please ensure the Owner\'s Division, Sub Division, and Sales District are correctly configured.'
                );
            }
            return;
        }
 
        Org_Role_Hierarchy__c orh = orhRecord.get(0);
 
        // Level ("1".."6") -> EMPID, built once for this Org_Role_Hierarchy__c record.
        // NOTE: if two role fields share the same Level value, the later one in
        // ROLE_PREFIXES wins — there's currently no defined tie-break rule beyond that.
        Map<String, String> levelToEmpid = new Map<String, String>();
        for(String prefix : ROLE_PREFIXES){
            Object levelVal = orh.get(prefix + '_Level__c');
            Object empidVal = orh.get(prefix + '_EMPID__c');
            if(levelVal != null && empidVal != null && String.valueOf(empidVal).trim() != ''){
                levelToEmpid.put(String.valueOf(levelVal), String.valueOf(empidVal));
            }
        }
 
        for(Opportunity__c oppRecord : oppList){
            oppIdSet.add(oppRecord.Id);
        }
 
        Map<Id,Opportunity__c> oppMap = new Map<Id, Opportunity__c>([
            SELECT Id, Account__c, Account__r.Name, Contact__r.Name, Account__r.SAP_Code__c
            FROM Opportunity__c
            WHERE Id IN :oppIdSet
        ]);
 
        Set<Id> accountIdsToUpdate = new Set<Id>();
 		List<Account> accountToUpdate = new List<Account>();
        for(Opportunity__c oppRecord : oppList){
            Opportunity__c fullOpp = oppMap.get(oppRecord.Id);
            if(fullOpp != null && fullOpp.Account__r.SAP_Code__c == null){
                orgRoleHierarchyAssignmentRecordToInsert.add(new Org_Role_Hierarchy_Assignment__c(
                    Name = fullOpp.Account__r.Name + '-' + fullOpp.Contact__r.Name + '-' + orh.Name,
                    Opportunity__c = oppRecord.Id,
                    Org_Role_Hierarchy__c = orh.Id,
                    Is_Active__c = true
                ));
                if(fullOpp.Account__c != null){
                    accountIdsToUpdate.add(fullOpp.Account__c);
                }
                accountToUpdate.add(new Account(
    Id = fullOpp.Account__c,
    Sales_District__c = orh?.Sales_District__c,
    Zone_Name__c = orh?.Region__c,
    Zone_Code__c = orh?.Zone_Code__c
));
            }
        }
 
        if(!orgRoleHierarchyAssignmentRecordToInsert.isEmpty()){
            Database.SaveResult[] results = Database.insert(orgRoleHierarchyAssignmentRecordToInsert, false);
            for (Database.SaveResult sr : results) {
                if (sr.isSuccess()) {
                    System.debug('Successfully inserted Org Role Hierarchy Assignment. Id: ' + sr.getId());
                } else {
                    for(Database.Error err : sr.getErrors()) {
                        System.debug('The following error has occurred.');
                        System.debug(err.getStatusCode() + ': ' + err.getMessage());
                        System.debug('Org Role Hierarchy Assignment fields that affected this error: ' + err.getFields());
                    }
                }
            }
        }
        if(!accountToUpdate.isEmpty()){
            Database.SaveResult[] results = Database.update(accountToUpdate, false);
            for (Database.SaveResult sr : results) {
                if (sr.isSuccess()) {
                    System.debug('Successfully updated Account Sales District , Zone Name and ZOne Code ' + sr.getId());
                } else {
                    for(Database.Error err : sr.getErrors()) {
                        System.debug('The following error has occurred.');
                        System.debug(err.getStatusCode() + ': ' + err.getMessage());
                        System.debug('Account fields that affected this error: ' + err.getFields());
                    }
                }
            }
        }
 
        if(!accountIdsToUpdate.isEmpty()){
            updateAccountEmployeeCodes(accountIdsToUpdate, levelToEmpid);
        }
    }
 
    private static void updateAccountEmployeeCodes(Set<Id> accountIds, Map<String, String> levelToEmpid){
        List<Account> accountsToUpdate = new List<Account>();
        for(Id accId : accountIds){
            accountsToUpdate.add(new Account(
                Id = accId,
                Employee_Code_Level_1__c = levelToEmpid.containsKey('1') ? (levelToEmpid.get('1').startsWith('BVC')  ? 'E' + levelToEmpid.get('1').removeStart('BVC') : levelToEmpid.get('1'))  : VACANT,
                Employee_Code_Level_2__c = levelToEmpid.containsKey('2') ? (levelToEmpid.get('2').startsWith('BVC') ? 'E' + levelToEmpid.get('2').removeStart('BVC') : levelToEmpid.get('2')) : VACANT,
                Employee_Code_Level_3__c = levelToEmpid.containsKey('3') ? (levelToEmpid.get('3').startsWith('BVC') ? 'E' + levelToEmpid.get('3').removeStart('BVC') : levelToEmpid.get('3')) : VACANT,
                Employee_Code_Level_4__c = levelToEmpid.containsKey('4') ? (levelToEmpid.get('4').startsWith('BVC') ? 'E' + levelToEmpid.get('4').removeStart('BVC') : levelToEmpid.get('4')) : VACANT,
                Employee_Code_Level_5__c = levelToEmpid.containsKey('5') ? (levelToEmpid.get('5').startsWith('BVC') ? 'E' + levelToEmpid.get('5').removeStart('BVC') : levelToEmpid.get('5')) : VACANT,
                Employee_Code_Level_6__c = levelToEmpid.containsKey('6') ? (levelToEmpid.get('6').startsWith('BVC') ? 'E' + levelToEmpid.get('6').removeStart('BVC') : levelToEmpid.get('6')) : VACANT
            ));
        }
 
        Database.SaveResult[] results = Database.update(accountsToUpdate, false);
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                System.debug('Successfully updated Account employee codes. Id: ' + sr.getId());
            } else {
                for(Database.Error err : sr.getErrors()) {
                    System.debug('The following error has occurred.');
                    System.debug(err.getStatusCode() + ': ' + err.getMessage());
                    System.debug('Account fields that affected this error: ' + err.getFields());
                }
            }
        }
    }*/
    // Added by Mohd Owais
    public static void sendEmailToOpportunityOwnerOnAdminRejection(List<Opportunity__c> oppList,Map<Id,Opportunity__c> oldMapOfOpportunity){
        System.debug('inside trigger');
        List<Opportunity__c> filteredOppList = new List<Opportunity__c>();
        Set<Id> ownerIds = new Set<Id>();
        for(Opportunity__c opp:oppList){
            if(opp.Admin_Not_Approve__c && opp.Admin_Not_Approve__c != oldMapOfOpportunity.get(opp.Id).Admin_Not_Approve__c){
                filteredOppList.add(opp);  
                ownerIds.add(opp.OwnerId);
            }
        }
        if(filteredOppList.isEmpty()) {return;}
        List<OrgWideEmailAddress> oweaList = [SELECT Id, Address FROM OrgWideEmailAddress LIMIT 1];
        System.debug('ownerIds'+ownerIds);
        System.debug('filteredOppList'+filteredOppList);
         String orgDomainUrl = URL.getOrgDomainUrl().toExternalForm();
         String siteDomainUrl = orgDomainUrl.replace('.my.salesforce.com', '.my.site.com');
           List<Site> sites = [  SELECT UrlPathPrefix  FROM Site  WHERE Status = 'Active' AND UrlPathPrefix = 'BioTechPortal'  LIMIT 1 ];
          String orgBaseUrl = !sites.isEmpty()
        ? siteDomainUrl + '/' + sites[0].UrlPathPrefix
        : siteDomainUrl;
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        Map<Id,User> userIdWithEmail = new Map<Id,User>([SELECT Id,Email FROM User WHERE Id IN:ownerIds]);
        for(Opportunity__c opp:filteredOppList){
              String formLink = orgBaseUrl + '/adminapprovalprocess?recordId=' + opp.Id+'&sendForCustomer=true';
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            if (!oweaList.isEmpty()) {  mail.setOrgWideEmailAddressId(oweaList[0].Id);}
         //   mail.setToAddresses(new String[] { userIdWithEmail.get(opp.OwnerId).Email });
             mail.setToAddresses(new String[] { 'dhruv@creatiquetech.com' });
            mail.setSubject('KYC Document Rejected: ' + opp.Name);
            String htmlBody = 'Hello,<br><br>'
                    + 'Your colleague has rejected the activity: <b>' + opp.Name + '</b>.<br><br>'
                    + 'If you want to re-submit this activity for approval, please click the link below:<br><br>'
                    + '<a href="' + formLink + '">Re-submit Approval</a><br><br>'
                    + 'Thanks,<br>'
                    + 'Operations Admin';
            mail.setHtmlBody(htmlBody);
            emailsToSend.add(mail);
            
        }
        if (!emailsToSend.isEmpty()) {  Messaging.sendEmail(emailsToSend); }
        
    }
    

}
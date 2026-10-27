public inherited sharing class AccountTeamHandler {
    public static void shareAccountWithAccTeam(List<Account_Team__c> newAccTeamList, List<Account_Team__c> oldAccTeamList,Map<Id,Account_Team__c> newAccTeamMap, Map<Id,Account_Team__c> oldAccTeamMap, System.TriggerOperation triggerEvent){
        //try{
        switch on triggerEvent {
            when BEFORE_UPDATE {
                //System.debug('In ZZZ BEF_UPD!!!!!');
                List<AccountShare> accShareUpdLst = new List<AccountShare>();
                List<AccountShare> accShareToDelete = new List<AccountShare>();
                List<AccountShare> accShareToInsert = new List<AccountShare>();
                
                Set<Id> oldAccTeamRecAccIdSet1 = new Set<Id>();
                Set<Id> oldAccTeamRecUsrIdSet1 = new Set<Id>();
                Set<Id> oldAccTeamRecAccIdSet2 = new Set<Id>();
                Set<Id> oldAccTeamRecUsrIdSet2 = new Set<Id>();
                
                Map<String,String> newAccTeamRecAccessLevelMap1    = new Map<String,String>(); // This store's accId+UserId as key and "Accesslevel" as value
                Set<String> newAccTeamRecIdSet2 = new Set<String>(); // Used
                
                Set<Account_Team__c> oldAccTeamRecValSet1 = new Set<Account_Team__c>();
                Set<Account_Team__c> oldAccTeamRecValSet2 = new Set<Account_Team__c>();
                
                for(Account_Team__c newAccTeam : newAccTeamList){
                    
                    Account_Team__c oldAccTeam = oldAccTeamMap.get(newAccTeam.Id);
                    if((oldAccTeam.Team_Member__c != newAccTeam.Team_Member__c) && (oldAccTeam.Account__c == newAccTeam.Account__c)){
                        // System.debug('In ZZZAccTeamHandler.cls-->shareAccountWithAccTeam_M-->IN B4UPDATE-->ELSE IF !!!!!');
                        if(newAccTeam.Member_Same_As_Account_Owner__c==false && newAccTeam.Allow_Creation__c){
                            oldAccTeamRecAccIdSet2.add(oldAccTeam.Account__c);
                            oldAccTeamRecUsrIdSet2.add(oldAccTeam.Team_Member__c);
                            newAccTeamRecIdSet2.add(newAccTeam.Id);   
                        }else{
                        	newAccTeam.addError(System.Label.apex_AccTeamTrigErrMsg);
                        }  
                        
                    }
                }
                
                
                
                
                If(! oldAccTeamRecUsrIdSet2.isEmpty()  && ! oldAccTeamRecAccIdSet2.isEmpty() ){
                    //Deleting the old accountshare record because team member is changed
                    for(AccountShare oldAccShareObj : [Select Id,AccountId,UserOrGroupId,AccountAccessLevel 
                                                       From AccountShare 
                                                       Where (AccountId IN : oldAccTeamRecAccIdSet2
                                                              AND UserOrGroupId IN : oldAccTeamRecUsrIdSet2)
                                                       AND RowCause = 'Manual'
                                                      ]){
                                                          accShareToDelete.add(oldAccShareObj);
                                                      }
                    if(!accShareToDelete.isEmpty()){
                        system.debug('accShareToDelete:'+accShareToDelete);
                        delete accShareToDelete;
                    }
                    
                    //Creating New AccountShare Record
                    for(Id newAccTeamId : newAccTeamRecIdSet2){
                        //Creating New AccountShare Record
                        AccountShare newAccShare =  new AccountShare();
                        newAccShare.AccountAccessLevel = (((newAccTeamMap.get(newAccTeamId).Account_Access__c) == 'Read/Write') ? 'Edit' : 'Read');
                        newAccShare.UserOrGroupId      = newAccTeamMap.get(newAccTeamId).Team_Member__c;
                        newAccShare.AccountId          = newAccTeamMap.get(newAccTeamId).Account__c;
                        newAccShare.OpportunityAccessLevel = 'Read';  // This is required field  
                        accShareToInsert.add(newAccShare);    
                    }
                    
                    map<id,AccountShare> accSharemap = new map<id,AccountShare>();
                    //put all the values from the list to map. 
                    accSharemap.putall(accShareToInsert);
                    if(accSharemap.size()>0){
                        insert accSharemap.values();
                    }
                    
                }
                
            }
            when AFTER_INSERT {
                for(Account_Team__c accTeam : newAccTeamList){
                    //System.debug('####-->accTeam.Allow_Creation__c-->'+accTeam.Allow_Creation__c);
                    if(!accTeam.Member_Same_As_Account_Owner__c /*&& accTeam.Allow_Creation__c*/){
                    	AccountTeamHandler.createAccountShareForUser(accTeam);  
                    }else{
                        accTeam.addError(System.Label.apex_AccTeamTrigErrMsg);
                    }  	 
                }
                
                
            }
            when AFTER_DELETE{
                //System.debug('In ZZZ IN DELETE!!!!!');
                System.debug('AccteamHandlr--> Queries-->'+triggerEvent+' -->'+Limits.getQueries());
                
                List<AccountShare> accShareLstToDelete = new List<AccountShare>();
                Set<Id> accountIdSet =  new Set<Id>();
                Set<Id> userIdSet =  new Set<Id>();
                for(Account_Team__c oldAccTeam : oldAccTeamList){
                    accountIdSet.add(oldAccTeam.Account__c);
                    userIdSet.add(oldAccTeam.Team_Member__c);    
                }
                for(AccountShare accShareO : [Select Id,AccountId,UserOrGroupId,AccountAccessLevel 
                                              From AccountShare 
                                              Where (AccountId IN : accountIdSet
                                                     AND UserOrGroupId IN : userIdSet)
                                              AND RowCause = 'Manual'
                                             ]){
                                                 accShareLstToDelete.add(accShareO);
                                             }    
                //System.debug('In ZZZAccTeamHandler.cls-->shareAccountWithAccTeam_M--> loop DELETE LST-->'+accShareLstToDelete);
                if(! accShareLstToDelete.isEmpty()){
                    System.debug('In ZZZAccTeamHandler.cls-->shareAccountWithAccTeam_M--> 2 DELETE LST-->'+accShareLstToDelete);
                    delete accShareLstToDelete;
                }
                /*
                 * Will deploy in next release after thorough testing effect.
                if(!accountIdSet.isEmpty()){
                    AccountTeamHandler.updateAccountTeamCountOnAccount(accountIdSet);
                }*/
                
                System.debug('AccteamHandlr-->Queries-->'+triggerEvent+' -->'+Limits.getQueries());
                
            }
            when else{}
        }
        // }catch(Exception ex){
        //     System.debug('In ZZZAccTeamHandler.cls-->shareAccountWithAccTeam_M-->Exception-->'+ex.getMessage()+' at Line-->'+ex.getLineNumber());
        // }
        
    }
    
    public static void createAccountShareForUser(Account_Team__c accTeam){
        List<AccountShare> accShareLst = new List<AccountShare>();
        AccountShare acShare =  new AccountShare();
        if(accTeam.Team_Member__c != null && accTeam.Account__c != null){
            acShare.AccountAccessLevel = ((accTeam.Account_Access__c == 'Read/Write') ? 'Edit' : 'Read');
            acShare.UserOrGroupId      = accTeam.Team_Member__c;
            acShare.AccountId          = accTeam.Account__c;
            acShare.OpportunityAccessLevel = 'Read';  // This is required field
            //acShare.CaseAccessLevel        = 'Read';
            //acShare.ContactAccessLevel     = 'Read';
            accShareLst.add(acShare);    
        }
        if(! accShareLst.isEmpty()){
            System.debug('33333 AfterInsert-->AccShare2Insert Size-->'+accShareLst.size());
            insert accShareLst;
        }
    }
    
    public static void updateAccountTeamCountOnAccount(Set<Id> accountIds){
        List<Account> accountListToUpdate = new  List<Account>();
        For(Account acc : [Select Id,Name,No_Of_Account_Team__c From Account Where Id IN :accountIds]){
            if(acc.No_Of_Account_Team__c > 0){
                acc.No_Of_Account_Team__c = acc.No_Of_Account_Team__c - 1; 
                accountListToUpdate.add(acc);
            }       	
        }
        
        if(!accountListToUpdate.isEmpty())  {
            update accountListToUpdate;
        }
        
        
        
    }
    
}
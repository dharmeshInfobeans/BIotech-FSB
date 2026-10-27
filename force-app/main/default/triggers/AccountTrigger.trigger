trigger AccountTrigger on Account (before insert, before update, after insert, after update) {
    
    if(TriggerControl.skipAccountTrigger){
        return;
    }
  AccountTriggerHandler.setApproverOnAccountWhenOwnerIsChanged(Trigger.new, Trigger.operationType);
    
    if(Trigger.isBefore && Trigger.isUpdate){
        List<Account> accToUpdateZone = new List<Account>();
        for(Account acc : Trigger.new){
            if(acc.New_Owner__c != Trigger.oldMap.get(acc.Id).New_Owner__c){
                accToUpdateZone.add(acc);
            }
        }
        if(!accToUpdateZone.isEmpty()) AccountTriggerHandler.updateAccZone(accToUpdateZone);
    }
  
  if(trigger.isBefore){
        if(trigger.isInsert){
            AccountTriggerHandler.changeCountry(Trigger.new);
            AccountTriggerHandler.setParentAccountIdforConsignee(Trigger.new);
            AccountTriggerHandler.wrapBillingStreetToStreetFields(Trigger.new);// added by dhrumil
        }
      If(trigger.IsUpdate){
          PreserveAccountTeamHelper.backupTeamMembers(Trigger.new, Trigger.oldMap);//Changes by yogi
          AccountTriggerHandler.wrapBillingStreetToStreetFields(Trigger.new); //added by dhrumil
      }
     
    }
    
    if(trigger.isAfter){
        if(trigger.isUpdate){
            PreserveAccountTeamHelper.reinsertTeamMembers();//Changes by yogi
			//AccountTriggerHandler.sendEmailInTableFormat(Trigger.new, Trigger.oldMap);
            Map<String, String> mapAccCodeWithNewEmail = new Map<String, String>();
            Map<String, String> mapAccCodeWithOldEmail = new Map<String, String>();
            List<User> lstOldUsers = new List<User>();
            List<User> lstNewUsers = new List<User>();
            List<Dealer_Notification__Share> lstOldDealerShares = new List<Dealer_Notification__Share>();
            List<Dealer_Notification__Share> lstDealerNotiShareToInsert = new List<Dealer_Notification__Share>();
            Map<String, Id> mapNewUserEmail = new Map<String, Id>();
            Map<Id, String> mapOldUserEmail = new Map<Id, String>();
            Map<Id, List<Dealer_Notification__Share>> mapUserIdDealerShare = new Map<Id, List<Dealer_Notification__Share>>();
             Map<String, List<Dealer_Notification__Share>> mapUserEmailDealerShare = new Map<String, List<Dealer_Notification__Share>>();
            List<Dealer_Notification__Share> lstDealerShares = new List<Dealer_Notification__Share>();
            Dealer_Notification__Share dealerNotiShare_obj;
            List<Dealer_Notification__Share> lstDealerSharesToDelete = new List<Dealer_Notification__Share>();
            
            Id dealerRecordTypId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Dealer Portal').getRecordTypeId();
            for(Account updatedAcc : trigger.new){
                Account oldAcc = trigger.oldMap.get(updatedAcc.Id);
                if(updatedAcc.E_Mail__c != oldAcc.E_Mail__c && String.isNotBlank(updatedAcc.E_Mail__c) 
                   && String.isNotBlank(oldAcc.E_Mail__c) && updatedAcc.recordtypeId == dealerRecordTypId){
                    mapAccCodeWithNewEmail.put(updatedAcc.SAP_Code__c, updatedAcc.E_Mail__c);
                    mapAccCodeWithOldEmail.put(updatedAcc.SAP_Code__c, oldAcc.E_Mail__c);
                }
            }
            if(!mapAccCodeWithNewEmail.isEmpty()){
                lstNewUsers = [Select Id, Name, Email From User Where Email IN : mapAccCodeWithNewEmail.values()];
                if(!lstNewUsers.isEmpty()){
                    for(User usr : lstNewUsers){
                        mapNewUserEmail.put(usr.Email,usr.Id);
                    } 
                }
            }
            if(!mapAccCodeWithOldEmail.isEmpty()){
             lstOldUsers = [Select Id, Name, Email From User Where Email IN : mapAccCodeWithOldEmail.values()];
                if(!lstOldUsers.isEmpty()){
                    for(User usr : lstOldUsers){
                        mapOldUserEmail.put(usr.Id,usr.Email);
                    } 
                }
                if(!lstOldUsers.isEmpty()){
                    lstOldDealerShares = [Select Id,UserOrGroupId,ParentId From Dealer_Notification__Share Where UserOrGroupId IN: lstOldUsers and rowCause = 'Manual'];
                }
                system.debug('lstOldDealerShares**'+lstOldDealerShares);
                if(!lstOldDealerShares.isEmpty()){
                    for(Dealer_Notification__Share dealerShare : lstOldDealerShares){
                        if(mapUserIdDealerShare.containsKey(dealerShare.UserOrGroupId)){
                            lstDealerShares = mapUserIdDealerShare.get(dealerShare.UserOrGroupId);
                            lstDealerShares.add(dealerShare);
                            mapUserIdDealerShare.put(dealerShare.UserOrGroupId, lstDealerShares);
                        }
                        else{
                            lstDealerShares = new List<Dealer_Notification__Share>(); 
                            lstDealerShares.add(dealerShare);
                            mapUserIdDealerShare.put(dealerShare.UserOrGroupId, lstDealerShares);
                        }
                    }
                     system.debug('mapUserIdDealerShare**'+mapUserIdDealerShare);
                    if(!mapUserIdDealerShare.isEmpty()){
                        for(Id usrId : mapUserIdDealerShare.keySet()){
                            if(mapOldUserEmail.containsKey(usrId)){
                                mapUserEmailDealerShare.put(mapOldUserEmail.get(usrId), mapUserIdDealerShare.get(usrId));
                            }
                        } 
                    }
                }
            }
            system.debug('mapUserEmailDealerShare**'+mapUserEmailDealerShare);
            for(Account updatedAcc : trigger.new){
                Account oldAcc = trigger.oldMap.get(updatedAcc.Id);
                if(updatedAcc.E_Mail__c != oldAcc.E_Mail__c && String.isNotBlank(updatedAcc.E_Mail__c) && 
                   String.isNotBlank(oldAcc.E_Mail__c) && updatedAcc.recordtypeId == dealerRecordTypId){
                    if(mapNewUserEmail.containsKey(updatedAcc.E_Mail__c) && mapUserEmailDealerShare.containsKey(oldAcc.E_Mail__c)){
                        for(Dealer_Notification__Share dealerNotiShare : mapUserEmailDealerShare.get(oldAcc.E_Mail__c)){
                            dealerNotiShare_obj = new Dealer_Notification__Share();
                            dealerNotiShare_obj.ParentId = dealerNotiShare.ParentId;
                            dealerNotiShare_obj.UserOrGroupId = mapNewUserEmail.get(updatedAcc.E_Mail__c);
                            dealerNotiShare_obj.AccessLevel = 'Read';
                            dealerNotiShare_obj.RowCause = Schema.Dealer_Notification__Share.RowCause.Manual;
                            lstDealerNotiShareToInsert.add(dealerNotiShare_obj);
                        }
                    }
                }
            }
            system.debug('mapUserEmailDealerShare**'+mapUserEmailDealerShare);
            if(!mapUserEmailDealerShare.isEmpty()){
                for(String usrEmail : mapUserEmailDealerShare.keySet()){
                    for(Dealer_Notification__Share shateToDelete : mapUserEmailDealerShare.get(usrEmail)){
                        lstDealerSharesToDelete.add(shateToDelete);
                    }                    
                }
            }
            if(!lstDealerSharesToDelete.isEmpty()){	
                delete lstDealerSharesToDelete;
            }
            if(!lstDealerNotiShareToInsert.isEmpty()){
                Database.SaveResult[] lsr = Database.insert(lstDealerNotiShareToInsert,false);
            }
            
            
            
        }
    }
}
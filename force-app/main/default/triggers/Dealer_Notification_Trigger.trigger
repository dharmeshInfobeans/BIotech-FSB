trigger Dealer_Notification_Trigger on Dealer_Notification__c (after insert) {
    Set<String> setAccSAPCode = new Set<String>();
    Set<String> setAccountSAPCodes = new Set<String>();
    Set<String> setDealerSAPCode = new Set<String>();
    List<Account> lstAccounts = new List<Account>();
    Map<Id, Set<String>> mapNotiToAccCode = new Map<Id, Set<String>>();
    Map<String, Id> accCodeUser_Map = new Map<String, Id>();
    Set<String> setDealerEmail = new Set<String>();
    List<User> lstUsers = new List<User>();
    Map<String, Id> mapUserEmail = new Map<String, Id>();
    Dealer_Notification__Share dealerNotiShare_obj;
    List<Dealer_Notification__Share> lstDealerNotiShareToInsert = new List<Dealer_Notification__Share>();
    
    Id dealerRecordTypId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Dealer Portal').getRecordTypeId();
    
    for(Dealer_Notification__c notificationTosent : trigger.new){
        if(notificationTosent.Notification_To__c == 'Specific Dealer'){
            //setAccSAPCode.clear();
            setAccSAPCode = new Set<String>();
            for(String accCode : notificationTosent.Dealers__c.split(';')){
                setAccSAPCode.add(accCode);
                setDealerSAPCode.add(accCode);
            }
            mapNotiToAccCode.put(notificationTosent.Id, setAccSAPCode);
        }
    }
    system.debug('mapNotiToAccCode**'+mapNotiToAccCode);
    
    //if(!setAccSAPCode.isEmpty()){
        lstAccounts = [Select Id, Name, E_Mail__c,SAP_Code__c,RecordTypeId From Account Where SAP_Code__c IN : setDealerSAPCode or RecordTypeId  =: dealerRecordTypId];
        system.debug('lstAccounts**'+lstAccounts);
        system.debug('lstAccounts size**'+lstAccounts.size());

        if(!lstAccounts.isEmpty()){
            for(Account acc : lstAccounts){
                setDealerEmail.add(acc.E_Mail__c);
            }
            for(Dealer_Notification__c notificationTosent : trigger.new){
                if(notificationTosent.Notification_To__c == 'All Dealers'){
                    setAccountSAPCodes = new Set<String>();
                    for(Account acc : lstAccounts){
                        if(acc.RecordTypeId == dealerRecordTypId){
                            setAccountSAPCodes.add(acc.SAP_Code__c);
                        }
                    }
                    mapNotiToAccCode.put(notificationTosent.Id, setAccountSAPCodes);                    
                }
            }
        }
    //}//
    system.debug('setDealerEmail**'+setDealerEmail);
     system.debug('mapNotiToAccCode**'+mapNotiToAccCode);
    
    if(!setDealerEmail.isEmpty()){
        lstUsers = [Select Id,Name,Email From User Where Email IN : setDealerEmail];
        if(!lstUsers.isEmpty()){
            for(User usr : lstUsers){
                mapUserEmail.put(usr.Email, usr.Id);
            }
        }
        if(!lstAccounts.isEmpty() && !lstUsers.isEmpty()){
            for(Account acc : lstAccounts){
                if(mapUserEmail.containsKey(acc.E_Mail__c)){
                    accCodeUser_Map.put(acc.SAP_Code__c,mapUserEmail.get(acc.E_Mail__c));
                }
            } 
        }
    }
	system.debug('accCodeUser_Map**'+accCodeUser_Map);   
    
    for(Dealer_Notification__c notificationTosent : trigger.new){
        if(mapNotiToAccCode.containsKey(notificationTosent.Id)){
            for(String accCde : mapNotiToAccCode.get(notificationTosent.Id)){
                if(accCodeUser_Map.containsKey(accCde)){
                    dealerNotiShare_obj = new Dealer_Notification__Share();
                    dealerNotiShare_obj.ParentId = notificationTosent.Id;
                    dealerNotiShare_obj.UserOrGroupId = accCodeUser_Map.get(accCde);
                    dealerNotiShare_obj.AccessLevel = 'Read';
                    dealerNotiShare_obj.RowCause = Schema.Dealer_Notification__Share.RowCause.Manual;
                    lstDealerNotiShareToInsert.add(dealerNotiShare_obj);
                }
            }
        }
    }
    system.debug('lstDealerNotiShareToInsert** '+lstDealerNotiShareToInsert); 
    system.debug('lstDealerNotiShareToInsert** '+lstDealerNotiShareToInsert.size()); 
    
    if(!lstDealerNotiShareToInsert.isEmpty()){
        Database.SaveResult[] lsr = Database.insert(lstDealerNotiShareToInsert,false);
        // Process the save results.
        for(Database.SaveResult sr : lsr){
            if(sr.isSuccess()){
                system.debug('ii');
            }
            if(!sr.isSuccess()){
                // Get the first save result error
                Database.Error err = sr.getErrors()[0];
                system.debug('err'+err);
            }
        }
    }
}
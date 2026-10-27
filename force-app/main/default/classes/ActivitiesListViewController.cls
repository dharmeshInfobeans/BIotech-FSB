public class ActivitiesListViewController {
    
    @AuraEnabled
    public static List<Event> getEvents(){
        return [Select Id,Subject,Beat_plan__c,Status__c,StartDateTime,EndDateTime,Event_Locked__c,What.Name,WhoId,Owner.Name 
                From Event 
                Where Status__c =: Constants.EVENT_STATUS_SENTFORAPPROVAL 
                ];
        
         
    }
    @AuraEnabled
    public static void getBeatPlan(list<string> eventId){
        system.debug(eventId);
        set<id> beatplanId  = new set<id>();
        for(event ev : [Select Id,Subject,Beat_plan__c,Status__c,StartDateTime,EndDateTime,Event_Locked__c,What.Name,WhoId,Owner.Name From Event Where Id IN: eventId]){
            system.debug('ev.id==>'+ev.id);
            system.debug('ev.Status__c==>'+ev.Status__c);
            if(ev.Beat_plan__c != null){       
                beatplanId.add(ev.Beat_plan__c);
                system.debug('beatplanId==>'+beatplanId);//a0H0l000006VS7FEAW
            }
        }
        
        list<Beat_plan__c> beatPlanToBeupdated = new list<Beat_plan__c>();
        //list<string> eveSub = new list<string>();
        map<id,list<string>> mapOfBeatIdVsListOfAccountId = new map<id,list<string>>();
        map<id,list<string>> mapOfBeatIdVsListOfEvent = new map<id,list<string>>();
        for(event eve : [Select Id,Subject,Beat_plan__c,whatid,Status__c,StartDateTime,EndDateTime,Event_Locked__c,
                        What.Name,WhoId,Owner.Name 
                        From Event 
                        Where Beat_plan__c IN: beatplanId 
                        ]){      //AND Status__c = 'Approved'                      
                        if(mapOfBeatIdVsListOfEvent.containsKey(eve.Beat_plan__c)){ 
                                list<String> eveSub = mapOfBeatIdVsListOfEvent.get(eve.Beat_plan__c);
                                if(eve.Subject == 'Leave' && eve.status__c== 'Approved'){
                                    eveSub.add(eve.Subject);
                                }
                                else{
                                system.debug(eve.status__c);
                                    if(eve.Subject != 'Leave' ){
                                        eveSub.add(eve.Subject);
                                    }
                                }
                                mapOfBeatIdVsListOfEvent.put(eve.Beat_plan__c,eveSub);
                        }
                        else{
                                list<string>  eveSub = new list<string>();
                                if(eve.Subject == 'Leave' && eve.status__c== 'Approved'){
                                    eveSub.add(eve.Subject);
                                    mapOfBeatIdVsListOfEvent.put(eve.Beat_plan__c,eveSub);
                                } 
                                else{
                                system.debug(eve.status__c);
                                    if(eve.Subject != 'Leave'){
                                        eveSub.add(eve.Subject);
                                        mapOfBeatIdVsListOfEvent.put(eve.Beat_plan__c,eveSub);
                                    }
                                } 
                             
                        }
                            //// storing accountName
                            if(mapOfBeatIdVsListOfAccountId.containsKey(eve.Beat_plan__c)){ 
                                list<String> accname = mapOfBeatIdVsListOfAccountId.get(eve.Beat_plan__c);
                                accname.add(eve.Whatid);
                                mapOfBeatIdVsListOfAccountId.put(eve.Beat_plan__c,accname);
                            }
                            else{
                                //if(eve.Beat_plan__c !=null){
                                    list<string>  accname = new list<string>();
                                    accname.add(eve.Whatid);
                                    mapOfBeatIdVsListOfAccountId.put(eve.Beat_plan__c,accname);  
                                 
                            }
            
        }
        set<id> accountnidset = new set<id>();
        for(account acc : [select id, name from account ]){
            accountnidset.add(acc.id);
        }
        
        system.debug(accountnidset);
        map<id,Beat_plan__c> mapOfBeatPlanIdVsBeatPlan = new map<id,Beat_plan__c>();
        for(Event newlyApprovedevents : [Select Id,Subject,Beat_plan__c,Status__c,StartDateTime,EndDateTime,Event_Locked__c,What.Name,WhoId,Owner.Name From Event Where Id IN: eventId AND Beat_plan__c != null]){
            system.debug('newlyApprovedevents.Subject----'+newlyApprovedevents.Subject);
            system.debug('mapOfBeatIdVsListOfEvent.get(newlyApprovedevents.Beat_plan__c)----'+mapOfBeatIdVsListOfEvent.get(newlyApprovedevents.Beat_plan__c));

            if(newlyApprovedevents != null && newlyApprovedevents.Subject != null && newlyApprovedevents.Beat_plan__c != null && newlyApprovedevents.Subject != 'Holiday' && mapOfBeatIdVsListOfEvent != null && mapOfBeatIdVsListOfEvent.get(newlyApprovedevents.Beat_plan__c) != null && !mapOfBeatIdVsListOfEvent.get(newlyApprovedevents.Beat_plan__c).contains('Holiday')){
                system.debug('you ar here!!!');
                if( mapOfBeatIdVsListOfEvent.get(newlyApprovedevents.Beat_plan__c).contains('Leave') && !mapOfBeatIdVsListOfEvent.get(newlyApprovedevents.Beat_plan__c).contains('Review Meeting') && !accountnidset.contains(newlyApprovedevents.whatid)){
                    Beat_plan__c bb = new Beat_plan__c();
                    bb.id = newlyApprovedevents.Beat_plan__c;
                    bb.Event_Type__c = 'PL';
                    system.debug('bb.Event_Type__c1==>'+bb.Event_Type__c);
                    beatPlanToBeupdated.add(bb);
                }       
                else if(  mapOfBeatIdVsListOfEvent.get(newlyApprovedevents.Beat_plan__c).contains('Leave') && (mapOfBeatIdVsListOfEvent.get(newlyApprovedevents.Beat_plan__c).contains('Review Meeting') || accountnidset.contains(newlyApprovedevents.whatid))){
                    system.debug('you ar here!!!222');
                    Beat_plan__c bb = new Beat_plan__c();
                    bb.id = newlyApprovedevents.Beat_plan__c;
                    bb.Event_Type__c = 'Half day';
                    system.debug('bb.Event_Type__c2==>'+bb.Event_Type__c);
                    beatPlanToBeupdated.add(bb);
                } 
                
               /* else if(newlyApprovedevents.Subject != 'Leave' &&  mapOfBeatIdVsListOfEvent.get(newlyApprovedevents.Beat_plan__c).contains('Leave') && (mapOfBeatIdVsListOfEvent.get(newlyApprovedevents.Beat_plan__c).contains('Review Meeting') || accountnidset.contains(newlyApprovedevents.whatid))){
                    Beat_plan__c bb = new Beat_plan__c();
                    bb.id = newlyApprovedevents.Beat_plan__c;
                    bb.Event_Type__c = 'Half day';
                    beatPlanToBeupdated.add(bb);
                } 
                else if( newlyApprovedevents.Subject != 'Leave' &&  mapOfBeatIdVsListOfEvent.get(newlyApprovedevents.Beat_plan__c).contains('Leave') == false){
                    Beat_plan__c bb = new Beat_plan__c();
                    bb.id = newlyApprovedevents.Beat_plan__c;
                    bb.Event_Type__c = 'P';
                    system.debug('bb.Event_Type__c3==>'+bb.Event_Type__c);
                    beatPlanToBeupdated.add(bb);
                }*/
                
            }
            /*else{
               
                Beat_plan__c bb = new Beat_plan__c();
                bb.id = newlyApprovedevents.Beat_plan__c;
                bb.Event_Type__c = 'PH';
                system.debug('bb.Event_Type__c6==>'+bb.Event_Type__c);
                beatPlanToBeupdated.add(bb);
                  
            }*/
        }
        mapOfBeatPlanIdVsBeatPlan.putAll(beatPlanToBeupdated); 
        system.debug('mapOfBeatPlanIdVsBeatPlan==='+mapOfBeatPlanIdVsBeatPlan);
        system.debug('mapOfBeatPlanIdVsBeatPlan==='+mapOfBeatPlanIdVsBeatPlan.values());
        system.debug('beatPlanToBeupdated==='+beatPlanToBeupdated);
        if(mapOfBeatPlanIdVsBeatPlan.size() > 0){
            update mapOfBeatPlanIdVsBeatPlan.values();
        }
        
    }
    
    
    @AuraEnabled
    public static boolean updateEvents(List<Event> editedAccountList)
     
    {            
        //System.debug('Evts Recvd-->'+editedAccountList);
        try{
            update editedAccountList;
            return true;
            //list<event> evlist = new list<event>();
            
            
        } catch(Exception e){
            System.debug('IN ActivitiesLstVwCon.cls-->Exception-->'+e.getMessage()+' at Line-->'+e.getLineNumber());
            return false;
        }
        
        
    }
    
}
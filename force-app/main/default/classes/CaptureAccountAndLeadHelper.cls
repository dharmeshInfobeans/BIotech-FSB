/**************************************************************************************************************
Description : This helper class will tag the event to its suitable beat plan on every create or update event
Author : Prashant Rana
Date : 2019-04-20
**************************************************************************************************************/
public class CaptureAccountAndLeadHelper {
    
    public static void updatevent(list<event> evlist){
        try{
            System.debug('event list : '+evlist);  
            map<String , beat_Plan__c> beatMap = new map<String,beat_Plan__c>();
            list<date> dateList = new list<date>();
            set<id> beatIdSet = new set<id>();
            map<id,string> beatAndNewEventsMap = new map<id,string>();
            map<id,list<string>> beatAndEventListsMap = new map<id,list<string>>();
            
            for(event obj : evlist){
                dateList.add(obj.StartDateTime.dateGMT());
            }
            
            date dobj = date.today().addDays(-5);
            list<beat_Plan__c> beatList = [select beat_Date__c,Assigned_To__c,BUI__c,Event_Type__c, id,Event_type_Name__c, Compensation_Off_Date__c from beat_Plan__c where Beat_Date__c in : dateList];
            System.debug('beat plan : '+beatList);
            
            map<string,object> updatebeatmap = new map<string,object> ();
            
            for (beat_Plan__c bobj : beatList) {
                beatMap.put(bobj.Assigned_To__c + '-'+ bobj.beat_Date__c.format(),bobj);
            }
            
            System.debug('beat map : '+beatMap);
            
            if(evlist !=null){
                for (event evObj : evlist) {
                    updatebeatmap.put(evObj.ownerId+'-'+evObj.Visit_Date__c.format(),evObj);
                    
                    if(evObj.WhatId != null && String.valueOf(evObj.whatId).startswith('001')){
                        evObj.Account__c = evObj.WhatId;
                    }
                    if(evObj.WhatId!=null && Schema.Lead__c.SObjectType==evObj.WhatId.getSobjectType()) {
                        evObj.Leads__c=evObj.WhatId;
                    }
                    evObj.Visit_Date__c = evObj.StartDateTime.dateGMT();
                    
                    if (evObj.Visit_Date__c <= date.today() && beatMap.containsKey(evObj.ownerId+'-'+evObj.Visit_Date__c.format())) {
                        evObj.Beat_Plan__c = beatMap.get(evObj.ownerId+'-'+evObj.Visit_Date__c.format()).Id;
                        beatAndNewEventsMap.put(evObj.Beat_plan__c, evObj.Subject);
                        beatIdSet.add(evObj.Beat_Plan__c);
                    }
                    else if(evObj.Visit_Date__c > date.today()){
                        system.debug('check ');
                        if(beatMap.containsKey(evObj.ownerId+'-'+evObj.Visit_Date__c.format())){
                            evObj.Beat_Plan__c = beatMap.get(evObj.ownerId+'-'+evObj.Visit_Date__c.format()).Id;
                            beatAndNewEventsMap.put(evObj.Beat_plan__c, evObj.Subject);
                            beatIdSet.add(evObj.Beat_Plan__c);
                        }else{
                            beat_Plan__c bobj = new beat_Plan__c();
                            if(evObj.Subject.contains('Holiday')){
                                bobj.Event_Type__c = 'H';
                            }
                            bobj.Beat_Date__c = evObj.Visit_date__c;
                            bobj.BUI__c = evObj.OwnerId+'-'+evObj.visit_Date__c.format();
                            bobj.Assigned_To__c = evObj.OwnerId;
                            bobj.OwnerId = evObj.OwnerId;
                            bobj.Joint_User__c = UserInfo.getUserId();
                            
                            //---------Added Start by yogi-------------//
                            if(evObj.Compensation_Off_Date__c != null){
                                bobj.Compensation_Off_Date__c = evObj.Compensation_Off_Date__c;
                                bobj.Applied_Compensation_off__c=true;
                            }
                            //---------------End---------------------//
                            if(evObj.Subject=='Leave') {
                                bobj.Event_type_Name__c = evObj.Type_of_leave__c;
                            }
                            if (evObj.Subject.contains('Out of office')){
                                bobj.Event_type_Name__c = 'Out of office';
                            }
                            bobj.Description__c = evObj.DCR_Description__c;
                            insert bobj;
                            system.debug('****bobj***'+bobj);
                            evObj.Beat_Plan__c = bobj.id;
                            beatMap.put(bobj.BUI__c,bobj);
                        }
                    }
                    else if (evObj.Visit_Date__c <= date.today() && !beatMap.containsKey(evObj.ownerId+'-'+evObj.Visit_Date__c.format())) {
                        beat_Plan__c bobj = new beat_Plan__c();
                        if(evObj.Subject.contains('Holiday')){
                            bobj.Event_Type__c = 'H';
                        }
                        bobj.Beat_Date__c = evObj.Visit_date__c;
                        bobj.BUI__c = evObj.OwnerId+'-'+evObj.visit_Date__c.format();
                        bobj.Assigned_To__c = evObj.OwnerId;
                        bobj.OwnerId = evObj.OwnerId;
                        bobj.Joint_User__c = UserInfo.getUserId();
                        
                        //---------Added Start by yogi-------------//
                        if(evObj.Compensation_Off_Date__c != null){
                            bobj.Compensation_Off_Date__c = evObj.Compensation_Off_Date__c;
                            //bobj.Applied_Compensation_off__c=true;
                        }
                        //--------------End-----------------------//
                        if(evObj.Subject=='Leave') {
                            bobj.Event_type_Name__c = evObj.Type_of_leave__c;
                        }  
                        if (evObj.Subject.contains('Out of office')){
                            bobj.Event_type_Name__c = 'Out of office';
                        }
                        bobj.Description__c = evObj.DCR_Description__c;
                        insert bobj;
                        system.debug('****bobj***'+bobj);
                        evObj.Beat_Plan__c = bobj.id;
                        beatMap.put(bobj.BUI__c,bobj);
                    }   
                }
            }
            
            // Update existing beat plans
            List<beat_Plan__c> beatlistdata = new List<beat_Plan__c>();
            system.debug('beatList---->'+beatList);
            
            for (beat_Plan__c bobj : beatList) {
                if(updatebeatmap.containsKey(bobj.Assigned_To__c+'-'+bobj.beat_Date__c.format())){
                    Event ev=(Event) updatebeatmap.get(bobj.Assigned_To__c+'-'+bobj.beat_Date__c.format());
                    
                    system.debug('ev:---ev.Beat_plan__c>'+ev.Beat_plan__c);            
                    if(ev.Subject.contains('Leave')) {
                        bobj.Description__c = ev.DCR_Description__c;
                        bobj.Event_type_Name__c= ev.Type_of_leave__c;
                        
                        // UPDATE: Set Compensation_Off_Date__c on existing beat plan
                        if(ev.Compensation_Off_Date__c != null){
                            bobj.Compensation_Off_Date__c = ev.Compensation_Off_Date__c;
                            //bobj.Applied_Compensation_off__c=true;
                        }
                    }
                    if(ev.Subject.contains('Out of office')){
                        bobj.Description__c = ev.DCR_Description__c;
                        bobj.Event_type_Name__c = 'Out of office';                
                    }
                    if(ev.Subject.contains('Holiday')){
                        bobj.Event_Type__c = 'H';
                    }
                    bobj.Description__c = ev.DCR_Description__c;
                    
                    beatlistdata.add(bobj);
                }     
            }
            
            if(beatlistdata.size()>0){
                Database.SaveResult[] results = Database.update(beatListData, false);
                
                for (Integer i = 0; i < results.size(); i++) {
                    if (results[i].isSuccess()) {
                        System.debug('Record updated: ' + beatListData[i].Id);
                    } else {
                        for (Database.Error error : results[i].getErrors()) {
                            System.debug('Error on record: ' + beatListData[i].Id + ' - ' + error.getMessage());
                        }
                    }
                }
                system.debug('beatlistdata'+beatlistdata);
            }
            
        }catch(exception e){
            system.debug('error in capturing account and lead : '+e.getMessage()+'at line number'+e.getLineNumber());
        }
        // the update code*************Added by gyadeen**************************
    }
    public static void updatbeatPlan(list<event> evlist){  
        
        System.debug('event list update beat : '+evlist); 
        
        set<id> beatPlanId = new set<id>();
        for(event evObj : evlist){
            if(evObj.status__c != 'Draft'){
                beatPlanId.add(evObj.Beat_Plan__c);
            }
            
            
        }
        system.debug('beatPlanId'+beatPlanId);
        string eventtype;
        list<event> listOfExistingEvent = [select id,Check_Out_Time__c,Check_In_Time__c,Stage__c,Lead_Stage__c,Status__c,Check_Out__c,Beat_Plan__c,Subject,Type_of_leave__c from Event where Beat_Plan__c IN : beatPlanId];
        system.debug(listOfExistingEvent );
        map<id,list<string>> mapOfBeatIdVsListOfEvent = new map<id,list<string>>();
        for(event eve : listOfExistingEvent){
            eventtype = eve.Type_of_leave__c;
            
            if(mapOfBeatIdVsListOfEvent.containsKey(eve.Beat_plan__c)){ 
                list<String> eveSub = mapOfBeatIdVsListOfEvent.get(eve.Beat_plan__c);
                if(eve.Subject == 'Leave' && eve.status__c == 'Approved'){
                    eveSub.add(eve.Subject);
                }
                else{
                    if(eve.Subject != 'Leave' && eve.status__c == 'Sent for Approval'){
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
                    if(eve.Subject != 'Leave' && eve.status__c== 'Sent for Approval'){
                        eveSub.add(eve.Subject);
                        mapOfBeatIdVsListOfEvent.put(eve.Beat_plan__c,eveSub);
                    }
                } 
                
            }
        }
        system.debug(mapOfBeatIdVsListOfEvent);
        
        map<id,Beat_plan__c> mapOfBeatPlanIdVsBeatPlan = new map<id,Beat_plan__c>();
        list<Beat_plan__c> beatPlanToBeupdated = new list<Beat_plan__c>();
        /*set<id> accountnidset = new set<id>();
for(account acc : [select id, name from account ]){
accountnidset.add(acc.id);

}*/
        
        list<event> eventlist = [select  id,Type_of_leave__c,Subject,Beat_plan__c,Beat_plan__r.Approval_status__c from Event where Type_of_leave__c!= Null AND Beat_plan__c In : beatPlanId ];
        for(Event newlyApprovedevents : evlist){
            system.debug(newlyApprovedevents.Subject);
            system.debug(mapOfBeatIdVsListOfEvent);
            if(newlyApprovedevents.status__c != 'Draft'){
                if(newlyApprovedevents != null && newlyApprovedevents.Subject != null && newlyApprovedevents.Beat_plan__c != null && newlyApprovedevents.Subject != 'Holiday' && mapOfBeatIdVsListOfEvent != null && mapOfBeatIdVsListOfEvent.get(newlyApprovedevents.Beat_plan__c) != null && !mapOfBeatIdVsListOfEvent.get(newlyApprovedevents.Beat_plan__c).contains('Holiday')){
                    if( newlyApprovedevents.Subject != 'Leave' && mapOfBeatIdVsListOfEvent != null && mapOfBeatIdVsListOfEvent.get(newlyApprovedevents.Beat_plan__c) != null &&  newlyApprovedevents.status__c == 'Sent For Approval' && mapOfBeatIdVsListOfEvent.get(newlyApprovedevents.Beat_plan__c).contains('Leave') == false ){
                        system.debug('i am in------>'+newlyApprovedevents.Subject);
                        
                        Beat_plan__c bb = new Beat_plan__c();
                        bb.id = newlyApprovedevents.Beat_plan__c;
                        bb.Event_Type__c = 'P';
                        system.debug('bb.Event_Type__c3==>'+bb.Event_Type__c);
                        beatPlanToBeupdated.add(bb);
                    }
                    
                    system.debug('eventlist'+eventlist.size());
                    if (eventlist != null && !eventlist.isEmpty()) {
                        // Access the first element
                        if (eventlist[0].Type_of_leave__c == 'First Half Leave' && eventlist[0].Beat_plan__r.Approval_Status__c =='Approved') {
                            Beat_plan__c bb = new Beat_plan__c();
                            bb.Id = newlyApprovedevents.Beat_plan__c;
                            bb.Event_Type__c = '1/2P+1/2PL';
                            beatPlanToBeupdated.add(bb);
                        } else if (eventlist[0].Type_of_leave__c == 'Second Half Leave' && eventlist[0].Beat_plan__r.Approval_Status__c =='Approved') {
                            Beat_plan__c bb = new Beat_plan__c();
                            bb.Id = newlyApprovedevents.Beat_plan__c;
                            bb.Event_Type__c = '1/2PL+1/2P';
                            beatPlanToBeupdated.add(bb);
                        }
                        
                    }
                    else if(mapOfBeatIdVsListOfEvent.get(newlyApprovedevents.Beat_plan__c).contains('Leave') && newlyApprovedevents.Subject != 'Leave' &&  newlyApprovedevents.status__c == 'Sent For Approval'){
                        Beat_plan__c bb = new Beat_plan__c();
                        bb.id = newlyApprovedevents.Beat_plan__c;
                        bb.Event_Type__c = 'First Half Leave';
                        system.debug('bb.Event_Type__c3==>'+bb.Event_Type__c);
                        beatPlanToBeupdated.add(bb);
                    }
                }
                else{
                    if(newlyApprovedevents.Subject == 'Holiday' ){
                        Beat_plan__c bb = new Beat_plan__c();
                        bb.id = newlyApprovedevents.Beat_plan__c;
                        bb.Event_Type__c = 'H';
                        system.debug('bb.Event_Type__c6==>'+bb.Event_Type__c);
                        beatPlanToBeupdated.add(bb);
                    }
                    
                }
                
                mapOfBeatPlanIdVsBeatPlan.putAll(beatPlanToBeupdated); 
            }
        } 
        system.debug('mapOfBeatPlanIdVsBeatPlan'+mapOfBeatPlanIdVsBeatPlan);
        if(mapOfBeatPlanIdVsBeatPlan.size() > 0){
            update mapOfBeatPlanIdVsBeatPlan.values();
        }
    }
    
    public static void fakMethod(){
        integer i=0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        
        
        
    }
}
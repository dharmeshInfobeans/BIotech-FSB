global class BDTrackerBatch implements Database.Batchable<sObject>{
    
    global Database.QueryLocator start(Database.BatchableContext BC){
       String strQuery = 'select id,StartDateTime,endDateTime,Milestone_Stage__c,recordtypeId,recordtype.Name,BD_Tracker_Planning__c,BD_Tracker_Phase__c,WhatId'+
           +',Account__c,Product__c,checkMilestoneDelayed__c from event where recordtype.Name =\'BD Tracker\' AND BD_Tracker_Planning__c != Null and Milestone_Stage__c IN (\'Plan\')';
        System.debug('strQuery'+strQuery);
        return Database.getQueryLocator(strQuery);
    }
    
    global void execute(Database.BatchableContext BC, List<event> scope){
        List<event>lstevent = new List<Event>();
        List<event>lstOldevent = new List<Event>();
        List<BD_Tracker_History__c>lstHistory = new List<BD_Tracker_History__c>();
        List<BD_Tracker_History__c>lstOldHistory = new List<BD_Tracker_History__c>();
        List<BD_Tracker__c>lstBDTracker = new List<BD_Tracker__c>();
        List<BD_Tracker__c>lstBDTrackerToUpdate = new List<BD_Tracker__c>();
        List<id>lstId = new List<Id>();
        List<id>lstBDTrackerId = new List<Id>();
        BD_Tracker_Planning__c objPlan;
        Id recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('BD Tracker').getrecordTypeId();
        Integer weekNum =EventHandler.weeknumber(Date.valueOf(System.today()));
        System.debug('scope'+scope);
        List<BD_Tracker__c>lstBDTrackerDailyUpdate = new List<BD_Tracker__c>();
        List<BD_Tracker__c>lstBDTrackerCancel = new List<BD_Tracker__c>();
        
        
        for(event objevent : scope ){
            objPlan = new BD_Tracker_Planning__c();
             if(objEvent.BD_Tracker_Planning__c != null){
                    objPlan.Id = objEvent.BD_Tracker_Planning__c;
			
                }
            if(objevent.Milestone_Stage__c =='Plan' && objEvent.RecordTypeId == recId ){
                System.debug('==>'+objEvent);
               // if(objevent.EndDateTime < System.today() && objevent.Milestone_Stage__c =='Plan'){
                if(objevent.checkMilestoneDelayed__c && objevent.Milestone_Stage__c =='Plan'){
                    System.debug('objEvent=>'+objEvent);
                    objEvent.Milestone_Stage__c = 'Delay';
                    objPlan.Milestone_Stage__c = 'Delay';
                    
                    lstevent.add(objevent);
                    lstBDTrackerId.add(objevent.whatId);
                    
                    if(objEvent.BD_Tracker_Phase__c == 'Product Discussion' || objEvent.BD_Tracker_Phase__c =='Ürün Tartışması'
                       || objEvent.BD_Tracker_Phase__c =='Discussão sobre produtos' || objEvent.BD_Tracker_Phase__c =='Discusión de producto'){
                        
                        BD_Tracker_History__c objHistory = new BD_Tracker_History__c();
                        objHistory.Account__c = objEvent.Account__c;
                        objHistory.Activity_Stage__c = 'Delay';
                        objHistory.Activity_Weeks__c = 'Week'+(weekNum-1);
                        objHistory.Activity_Year__c = string.Valueof(System.today().Year());
                        objHistory.BD_Tracker_Planning__c = objEvent.BD_Tracker_Planning__c;
                        lstHistory.add(objHistory);
                        
                        BD_Tracker__c objTracker = new BD_Tracker__c();
                        objTracker.id = objEvent.whatId;
                        objTracker.PD_Status__c = 'Delay'; 
                        lstBDTrackerDailyUpdate.add(objTracker);
                    }
                    if(objEvent.BD_Tracker_Phase__c == 'Evaluation' || objEvent.BD_Tracker_Phase__c =='Değerlendirme'
                       || objEvent.BD_Tracker_Phase__c =='Avaliação' || objEvent.BD_Tracker_Phase__c =='Evaluación'){
                        
                        BD_Tracker_History__c objHistory = new BD_Tracker_History__c();
                        objHistory.Account__c = objEvent.Account__c;
                        objHistory.Activity_Stage__c = 'Delay';
                        objHistory.Activity_Weeks__c = 'Week'+(weekNum-1);
                        objHistory.Activity_Year__c = string.Valueof(System.today().Year());
                        objHistory.BD_Tracker_Planning__c = objEvent.BD_Tracker_Planning__c;
                        lstHistory.add(objHistory);
                        
                        BD_Tracker__c objTracker = new BD_Tracker__c();
                        objTracker.id = objEvent.whatId;
                        objTracker.EV_Status__c = 'Delay';
                        lstBDTrackerDailyUpdate.add(objTracker);
                        
                    }
                    if(objEvent.BD_Tracker_Phase__c == 'Commercialization'||objEvent.BD_Tracker_Phase__c == 'Ticarileştirme'
                       ||objEvent.BD_Tracker_Phase__c == 'Comercialização' || objEvent.BD_Tracker_Phase__c =='Comercialización'){
                        
                        BD_Tracker_History__c objHistory = new BD_Tracker_History__c();
                        objHistory.Account__c = objEvent.Account__c;
                        objHistory.Activity_Stage__c = 'Delay';
                        objHistory.Activity_Weeks__c =  'Week'+(weekNum-1);
                        objHistory.Activity_Year__c = string.Valueof(System.today().Year());
                        objHistory.BD_Tracker_Planning__c = objEvent.BD_Tracker_Planning__c;
                        lstHistory.add(objHistory);
                       
                        BD_Tracker__c objTracker = new BD_Tracker__c();
                        objTracker.id = objEvent.whatId;
                        objTracker.CM_Status__c = 'Delay';
                        lstBDTrackerDailyUpdate.add(objTracker);
                    }
                    
                } 
                
                //Cancel all the phases which are 3 months older and no any operation has been taken.
                
                if(objevent.EndDateTime < System.today().addMonths(-3) && objevent.BD_Tracker_Phase__c =='Product Discussion' 
                   || objevent.BD_Tracker_Phase__c =='Ürün Tartışması' ||objevent.BD_Tracker_Phase__c =='Discussão sobre produtos' || objevent.BD_Tracker_Phase__c =='Discusión de producto'){
                    lstId.add(objevent.WhatId);
                    objPlan.Milestone_Stage__c = 'Delay';
                    List<Event>lstofAllEvent  = [SELECT id,Milestone_Stage__c,WhatID from Event where WhatID =:objEvent.WhatId];
                    for(Event obj : lstofAllEvent){
                        
                        obj.Milestone_Stage__c = 'Cancel';
                        obj.Delay_Reason__c  = 'No Action Performed';
                        obj.Milestone_Actual_Week__c = 'Week'+weekNum;
                        obj.Milestone_Actual_Year__c = string.Valueof(System.today().Year());
                        
                        lstOldevent.add(obj);
                    }
                    
                    
                    if(objEvent.BD_Tracker_Phase__c == 'Product Discussion' || objevent.BD_Tracker_Phase__c =='Ürün Tartışması'
                       ||objevent.BD_Tracker_Phase__c =='Discussão sobre produtos' || objevent.BD_Tracker_Phase__c =='Discusión de producto'){
                        
                        BD_Tracker_History__c objHistory = new BD_Tracker_History__c();
                        objHistory.Account__c = objEvent.Account__c;
                       // objHistory.Product__c = objEvent.Product__c;
                        objHistory.Activity_Stage__c = 'Cancel';
                        objHistory.Activity_Weeks__c =  'Week'+weekNum;
                        objHistory.Activity_Year__c = string.Valueof(System.today().Year());
                        objHistory.BD_Tracker_Planning__c = objEvent.BD_Tracker_Planning__c;
                        lstOldHistory.add(objHistory);
                        
                        BD_Tracker__c objTracker = new BD_Tracker__c();
                        objTracker.id = objEvent.whatId;
                        objTracker.PD_Status__c = 'Cancel';
                        lstBDTrackerCancel.add(objTracker);
                        
                        
                    }
                    if(objEvent.BD_Tracker_Phase__c == 'Evaluation'|| objevent.BD_Tracker_Phase__c =='Değerlendirme' 
                       ||objevent.BD_Tracker_Phase__c =='Avaliação' || objevent.BD_Tracker_Phase__c =='Evaluación'){
                        
                        BD_Tracker_History__c objHistory = new BD_Tracker_History__c();
                        objHistory.Account__c = objEvent.Account__c;
                       // objHistory.Product__c = objEvent.Product__c;
                        objHistory.Activity_Stage__c = 'Cancel';
                        objHistory.Activity_Weeks__c =  'Week'+weekNum;
                        objHistory.Activity_Year__c = string.Valueof(System.today().Year());
                        objHistory.BD_Tracker_Planning__c = objEvent.BD_Tracker_Planning__c;
                        lstOldHistory.add(objHistory);
                        
                        BD_Tracker__c objTracker = new BD_Tracker__c();
                        objTracker.id = objEvent.whatId;
                        objTracker.EV_Status__c = 'Cancel';
                        lstBDTrackerCancel.add(objTracker);
                        
                    }
                    if(objEvent.BD_Tracker_Phase__c == 'Commercialization' || objEvent.BD_Tracker_Phase__c =='Ticarileştirme' 
                       || objEvent.BD_Tracker_Phase__c =='Comercialização' || objEvent.BD_Tracker_Phase__c == 'Comercialización'){
                        
                        BD_Tracker_History__c objHistory = new BD_Tracker_History__c();
                        objHistory.Account__c = objEvent.Account__c;
                       // objHistory.Product__c = objEvent.Product__c;
                        objHistory.Activity_Stage__c = 'Cancel';
                        objHistory.Activity_Weeks__c =  'Week'+weekNum;
                        objHistory.Activity_Year__c = string.Valueof(System.today().Year());
                        objHistory.BD_Tracker_Planning__c = objEvent.BD_Tracker_Planning__c;
                        lstOldHistory.add(objHistory);
                        
                        //BD_Tracker__c bd = [Select id from BD_Tracker__c where Id =:objEvent.whatId];
                        //system.debug('*******'+[Select id from BD_Tracker__c where Id =:objEvent.whatId]);
                        //system.debug('*******'+bd);
                        //system.debug('****objEvent.whatId***'+objEvent.whatId);
                        BD_Tracker__c objTracker = new BD_Tracker__c();
                        objTracker.id = objEvent.whatId;
                        objTracker.CM_Status__c = 'Cancel';
                        lstBDTrackerCancel.add(objTracker);
                        
                    }
                    
                } 
            }
            
        }
       SYstem.debug('lstEvent'+lstEvent); 
        if(lstId.size() > 0 || lstId !=null){
            lstBDTracker = [Select id,Name,Stage__c from BD_Tracker__c where Id IN :lstId];
            for(BD_Tracker__c objBD : lstBDTracker){
                objBD.Stage__c = 'Closed Lost';
                objBD.Reason_For_Cancel__c = 'No Action Performed.';
                objBD.Status__c = 'Re-Plan';
                lstBDTrackerToUpdate.add(objBD);
            }
        }
      
        
          if(lstBDTrackerDailyUpdate.size() > 0 || lstBDTrackerDailyUpdate != null){
              
            update lstBDTrackerToUpdate;
          
          }
        
        if(lstBDTrackerToUpdate.size() > 0 || lstBDTrackerToUpdate != null){
            update lstBDTrackerToUpdate;
        }
        
        if((lstOldevent.size() > 0|| lstOldevent!= null) ){
            
            Database.update(lstOldevent);
            Database.update(objPlan); 
        }
        if(lstHistory.size() > 0 && lstHistory != Null){
            Database.update(lstEvent);
            Database.insert(lstHistory);
            Database.update(objPlan);
        }
        If((lstOldHistory.size() > 0 || lstOldHistory != Null)){
            
            Database.insert(lstOldHistory);
            update lstBDTrackerCancel;  
            Database.update(objPlan);
        }
        
    }
    global void finish(Database.BatchableContext bc){
        
    }
}
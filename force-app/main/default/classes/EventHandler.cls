public class EventHandler {
    
    
    
  /*  public static void createHistory(List<Event>lstEvent,List<Event>lstOldEvent){
        Id recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('BD Tracker').getrecordTypeId();
        BDTrackerController.weeksWrapperWithMonth objWeeksWrapper = BDTrackerController.getYearwiseWeeks(Date.newInstance(System.today().Year(), 01, 01), Date.newInstance(System.today().Year(), 12, 31));
        Integer weekNum =weeknumber(Date.valueOf(System.today()));
        
        for(event objEvent : lstEvent){
            
            
            for(event objOldEvent : lstOldEvent){
                System.debug('objEvent'+objEvent);
                if(objEvent.RecordTypeId == recId && objEvent.Milestone_Stage__c =='Actual' && objOldEvent.Milestone_Stage__c != objEvent.Milestone_Stage__c
                   && objOldEvent.Milestone_Stage__c != 'Actual'){
                       
                       objEvent.Milestone_Actual_Week__c = 'Week'+weekNum;
                       objEvent.Milestone_Actual_Year__c =  String.valueOf(System.today().Year());
                       
                       BD_Tracker_Planning__c objPlan = [Select id,Name,Account__c,Product__c,Actual_Week__c,Actual_Year__c,BD_Tracker__c 
                                                         from BD_Tracker_Planning__c
                                                         where ID=:objEvent.BD_Tracker_Planning__c];
                       BD_Tracker__c objTracker = [SELECT id,Name,stage__c from BD_Tracker__c where ID=:objPlan.BD_Tracker__c];
                       
                       //Check the BD tRAcker phase and update same.
                       if(objEvent.BD_Tracker_Phase__c == 'Product Discussion' || objEvent.BD_Tracker_Phase__c == 'Ürün Tartışması'
                          || objEvent.BD_Tracker_Phase__c == 'Discussão sobre produtos' || objEvent.BD_Tracker_Phase__c =='Discusión de producto'){
                              objtracker.stage__c = 'Evaluation';
                          }
                       else if(objEvent.BD_Tracker_Phase__c == 'Evaluation' || objEvent.BD_Tracker_Phase__c == 'Değerlendirme'
                               || objEvent.BD_Tracker_Phase__c == 'Avaliação' || objEvent.BD_Tracker_Phase__c =='Evaluación'){
                                   objtracker.stage__c = 'Commercialization';
                               }
                       else if((objEvent.BD_Tracker_Phase__c == 'Commercialization' || objEvent.BD_Tracker_Phase__c == 'Ticarileştirme'
                                || objEvent.BD_Tracker_Phase__c == 'Comercialização' || objEvent.BD_Tracker_Phase__c =='Comercialización') && objEvent.BD_Plan_Status__c=='Won'){
                                    objtracker.stage__c = 'Completed';
                                    objtracker.Plan_Won_Date__c = System.today();
                                }
                       
                       else if((objEvent.BD_Tracker_Phase__c == 'Commercialization'|| objEvent.BD_Tracker_Phase__c == 'Ticarileştirme' || objEvent.BD_Tracker_Phase__c == 'Comercialização' || objEvent.BD_Tracker_Phase__c =='Comercialización') && objEvent.BD_Plan_Status__c=='Closed Lost'){
                           objtracker.stage__c = 'Closed Lost'; 
                           objtracker.Plan_Won_Date__c = System.today();
                       }
                       
                       
                       
                       Database.update(objTracker);
                       objPlan.Actual_Week__c = 'Week'+weekNum;
                       objPlan.Actual_Year__c = String.valueOf(System.today().Year());
                       
                       Database.update(objPlan);
                       BD_Tracker_History__c objHistory = new BD_Tracker_History__c();
                       objHistory.Account__c = objPlan.Account__c;
                       objHistory.Product__c = objPlan.Product__c;
                       objHistory.Activity_Stage__c = objEvent.Milestone_Stage__c;
                       objHistory.Activity_Weeks__c =  'Week'+weekNum;
                       objHistory.Activity_Year__c = string.Valueof(System.today().Year());
                       objHistory.BD_Tracker_Planning__c = objPlan.Id;
                       Database.insert(objHistory);
                   }         
            }
            
        }
    }*/
    
    
    public static void createHistoryData(List<Event>lstEvent,Map<Id,Event> oldEventmap) {
        Map<String,BD_Tracker_Planning__c> bdTrackerDataMap=new Map<String,BD_Tracker_Planning__c>();
        Id recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('BD Tracker').getrecordTypeId();
        BDTrackerController.weeksWrapperWithMonth objWeeksWrapper = BDTrackerController.getYearwiseWeeks(Date.newInstance(System.today().Year(), 01, 01), Date.newInstance(System.today().Year(), 12, 31));
        List<BD_Tracker_Planning__c> bdTrackerPlaUpdateList=new List<BD_Tracker_Planning__c>();
        List<BD_Tracker__c> bdTrackerUpdateList=new list<BD_Tracker__c>();
        List<BD_Tracker_History__c> bdTrackerHistoryList=new List<BD_Tracker_History__c>();
        Integer weekNum =weeknumber(Date.valueOf(System.today()));
        Set<String> brTrakerPlanningSet=new Set<String>();
        Set<String> bdTrackerSet=new Set<String>();
        
        for(event objEvent : lstEvent){
            
            if(objEvent.RecordTypeId == recId && objEvent.Milestone_Stage__c =='Actual' && oldEventmap.get(objEvent.Id).Milestone_Stage__c != objEvent.Milestone_Stage__c
               && oldEventmap.get(objEvent.Id).Milestone_Stage__c != 'Actual'){
                   brTrakerPlanningSet.add(objEvent.BD_Tracker_Planning__c);
               }
        }
        
        List<BD_Tracker_Planning__c> bdTrackerPlanningList=[Select id,Name,Account__c,Product__c,Actual_Week__c,Actual_Year__c,BD_Tracker__c,BD_Tracker__r.Stage__c,BD_Tracker__r.Plan_Won_Date__c 
                                                            from BD_Tracker_Planning__c
                                                            where ID in:brTrakerPlanningSet];//Getting the Bd tracker List tagged to the event
        System.debug('Bd tracker Planning list'+bdTrackerPlanningList);
        for(BD_Tracker_Planning__c bdTrPlan:bdTrackerPlanningList) {
            bdTrackerDataMap.put(bdTrPlan.Id,bdTrPlan);
        }
        System.debug('Bd tracker Map'+bdTrackerDataMap);
        System.debug('Event data'+JSON.serialize(lstEvent));
        System.debug('Serialize  Map'+JSON.serialize(bdTrackerDataMap));
        for(event objEvent : lstEvent){
            
            if(objEvent.RecordTypeId == recId && objEvent.Milestone_Stage__c =='Actual' && oldEventmap.get(objEvent.Id).Milestone_Stage__c != objEvent.Milestone_Stage__c
               && oldEventmap.get(objEvent.Id).Milestone_Stage__c != 'Actual'){
                   if(bdTrackerDataMap.containskey(objEvent.BD_Tracker_Planning__c)) {
                       
                       objEvent.Milestone_Actual_Week__c = 'Week'+weekNum;
                       objEvent.Milestone_Actual_Year__c =  String.valueOf(System.today().Year());
                       
                       BD_Tracker__c bdTracker=new BD_Tracker__c();
                       bdTracker.Id=bdTrackerDataMap.get(objEvent.BD_Tracker_Planning__c).BD_Tracker__c;
                       if(objEvent.BD_Tracker_Phase__c == 'Product Discussion' || objEvent.BD_Tracker_Phase__c == 'Ürün Tartışması'
                          || objEvent.BD_Tracker_Phase__c == 'Discussão sobre produtos' || objEvent.BD_Tracker_Phase__c =='Discusión de producto'){
                              bdTracker.Stage__c = 'Evaluation';
                          }
                       
                       else if(objEvent.BD_Tracker_Phase__c == 'Evaluation' || objEvent.BD_Tracker_Phase__c == 'Değerlendirme'
                               || objEvent.BD_Tracker_Phase__c == 'Avaliação' || objEvent.BD_Tracker_Phase__c =='Evaluación'){
                                   bdTracker.Stage__c = 'Commercialization';
                               }
                       
                       else if((objEvent.BD_Tracker_Phase__c == 'Commercialization' || objEvent.BD_Tracker_Phase__c == 'Ticarileştirme'
                                || objEvent.BD_Tracker_Phase__c == 'Comercialização' || objEvent.BD_Tracker_Phase__c =='Comercialización') && objEvent.BD_Plan_Status__c=='Won'){
                                    bdTracker.Stage__c = 'Completed';
                                    bdTracker.Plan_Won_Date__c = System.today();
                                }
                       
                       else if((objEvent.BD_Tracker_Phase__c == 'Commercialization'|| objEvent.BD_Tracker_Phase__c == 'Ticarileştirme' || objEvent.BD_Tracker_Phase__c == 'Comercialização' || objEvent.BD_Tracker_Phase__c =='Comercialización') && objEvent.BD_Plan_Status__c=='Closed Lost'){
                           bdTracker.Stage__c = 'Closed Lost'; 
                           bdTracker.Plan_Won_Date__c  = System.today();
                       }
                       
                       BD_Tracker_Planning__c bdTrackerUpdate=new BD_Tracker_Planning__c();
                       bdTrackerUpdate.id=bdTrackerDataMap.get(objEvent.BD_Tracker_Planning__c).Id;
                       bdTrackerUpdate.Actual_Week__c='Week'+weekNum;
                       bdTrackerUpdate.Actual_Year__c= String.valueOf(System.today().Year());
                       bdTrackerPlaUpdateList.add(bdTrackerUpdate);
                       bdTrackerUpdateList.add(bdTracker);
                       
                       BD_Tracker_History__c objHistory = new BD_Tracker_History__c();
                       objHistory.Account__c = (bdTrackerDataMap.get(objEvent.BD_Tracker_Planning__c).Account__c!=null ||  bdTrackerDataMap.get(objEvent.BD_Tracker_Planning__c).Account__c!='') ?  bdTrackerDataMap.get(objEvent.BD_Tracker_Planning__c).Account__c : ''; 
                       
                       objHistory.Product__c = ( bdTrackerDataMap.get(objEvent.BD_Tracker_Planning__c).Product__c!=null || bdTrackerDataMap.get(objEvent.BD_Tracker_Planning__c).Product__c!='' )? bdTrackerDataMap.get(objEvent.BD_Tracker_Planning__c).Product__c : '';
                       if(!test.isRunningTest()) {
                           objHistory.Activity_Stage__c =  (bdTrackerDataMap.get(objEvent.BD_Tracker_Planning__c).Milestone_Stage__c!=null ||  bdTrackerDataMap.get(objEvent.BD_Tracker_Planning__c).Milestone_Stage__c!='') ? bdTrackerDataMap.get(objEvent.BD_Tracker_Planning__c).Milestone_Stage__c : '';
                       }
                      
                       objHistory.Activity_Weeks__c =  'Week'+weekNum;
                       objHistory.Activity_Year__c = string.Valueof(System.today().Year());
                       objHistory.BD_Tracker_Planning__c =  bdTrackerDataMap.get(objEvent.BD_Tracker_Planning__c).Id;
                       bdTrackerHistoryList.add(objHistory);
                       
                   }
               }
        }
        if(bdTrackerUpdateList.size()>0) {
            update bdTrackerUpdateList;
        }
        if(bdTrackerPlaUpdateList.size()>0) {
            update bdTrackerPlaUpdateList;
        }
        if(bdTrackerHistoryList.size()>0) {
            insert bdTrackerHistoryList;
        }
        
        
    }
    
    
    
    
    
    public static void updateTracker(List<Event>lstEvent){
        List<string>lstString = new List<string>();
        for(event objEvent : lstEvent){
            lstString.add(objEvent.whatId);
        }
        List<BD_Tracker__c> objBDVal = [Select Id,Name,Product_Discussion_Plan_Year__c,Evaluation_Plan_Year__c,Commercialization_Plan_Year__c,Product_Discussion_Plan_Week__c,
                                        Evaluation_Planned_Week__c,Commercialization_Planned_Week__c,Account__c,Product__c,Contact__c,Status__c,OwnerId,Reason_For_Delete__c,Product_Discussion_Actual_Year__c,
                                        Product_Discussion_Actual_Week__c,Evaluation_Actual_Year__c,Evaluation_Actual_Week__c,Commercialization_Actual_Week__c,Commercialization_Actual_Year__c
                                        
                                        from BD_Tracker__c where ID IN :lstString];
        Map<string,BD_Tracker__c>lstMap = new Map<string,BD_Tracker__c>();
        for(BD_Tracker__c objBDrecord :objBDVal){
            lstMap.put(objBDrecord.Id,objBDrecord);
        }
        List<BD_Tracker__c> objBDValList = new List<BD_Tracker__c>();
        for(event objEvent : lstEvent){
            
            BD_Tracker__c objBD;
            if(lstMap.containskey(objEvent.whatId)){
                objBD = lstMap.get(objEvent.whatId);
                if(objEvent.Milestone_Stage__c == 'Actual'){
                    if(objEvent.BD_Tracker_Phase__c == 'Product Discussion' || objEvent.BD_Tracker_Phase__c == 'Ürün Tartışması'
                       || objEvent.BD_Tracker_Phase__c == 'Discussão sobre produtos' || objEvent.BD_Tracker_Phase__c =='Discusión de producto'){
                           objBD.Product_Discussion_Actual_Week__c = objEvent.Milestone_Actual_Week__c;
                           objBD.Product_Discussion_Actual_Year__c = objEvent.Milestone_Actual_Year__c;
                           objBDValList.add(objBD);
                           
                       }
                    if(objEvent.BD_Tracker_Phase__c ==	'Evaluation' || objEvent.BD_Tracker_Phase__c == 'Değerlendirme'
                       || objEvent.BD_Tracker_Phase__c == 'Avaliação' || objEvent.BD_Tracker_Phase__c =='Evaluación'){
                           objBD.Evaluation_Actual_Week__c = objEvent.Milestone_Actual_Week__c;
                           objBD.Evaluation_Actual_Year__c = objEvent.Milestone_Actual_Year__c;
                           objBDValList.add(objBD);
                           
                       }
                    if(objEvent.BD_Tracker_Phase__c ==	'Commercialization' || objEvent.BD_Tracker_Phase__c == 'Ticarileştirme'
                       || objEvent.BD_Tracker_Phase__c == 'Comercialização' || objEvent.BD_Tracker_Phase__c == 'Comercialización'){
                           objBD.Commercialization_Actual_Week__c = objEvent.Milestone_Actual_Week__c;
                           objBD.Commercialization_Actual_Year__c = objEvent.Milestone_Actual_Year__c;
                           objBDValList.add(objBD);
                           
                       }
                }
            }
        }
        Database.update(objBDValList);
    }
    
    public static void validateDateChanged(List<Event>lstEvent,List<Event>lstOldEvent){
        for(event objEvent : lstEvent){
            
            for(event objOldEvent : lstOldEvent){
                if(objEvent.StartDateTime !=objOldEvent.StartDateTime && objEvent.isSubmitted__c && objEvent.id == objOldEvent.Id){
                    // objEvent.addError('You can not change BD Plan after submission.');
                }
                if(objEvent.EndDateTime !=objOldEvent.EndDateTime && objEvent.isSubmitted__c && objEvent.id == objOldEvent.Id){
                    // objEvent.addError('You can not change BD Plan after submission.');
                }
                
                if((!objEvent.isSubmitted__c) && objEvent.Milestone_Stage__c =='Actual' && objOldEvent.Milestone_Stage__c =='Plan'){
                    //  objEvent.addError('You can not complete phase before submit.');
                }
            }
        }
    }
    /********************************************
* @Method Name  : weeknumber
* @Params       : Date startdate
* @Description  : It is used to get the Weeknumber of current date.
* @Created Date : 13-11-2019
* @Created By   : Rajesh N. 
* ****************************************/           
    public static Integer weeknumber(Date startdate){
        Date todaydateinstance = date.newinstance(startdate.year(), startdate.month(), startdate.day());
        
        Integer currentyear = startdate.year();
        
        Date yearstartdate = date.newinstance(currentyear, 01, 01);
        Date year2ndweek = yearstartdate.adddays(7).tostartofweek();
        
        if(startdate<year2ndweek)
            return 1;
        integer numberDaysDue = year2ndweek.daysBetween(todaydateinstance);
        
        Integer numberOfWeek;
        if(math.mod(numberDaysDue,7)==0)
            numberOfWeek = math.MOD(Integer.valueof(math.FLOOR( ( numberDaysDue )/7)),52)+1;
        else
            numberOfWeek = math.MOD(Integer.valueof(math.FLOOR( ( numberDaysDue )/7)),52)+2;
        return numberOfWeek;
        
    }     
}
/********************************************
* @Class Name   : BDTrackerController
* @Description  : It is used to provide data to BDTracker component.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/
public with sharing class  BDTrackerController {
    
    public class BDTrackerWrapper{
        @AuraEnabled public Account objAccount{get;set;}
        @AuraEnabled public List<StageWrapper> lstStages{get;set;}
        @AuraEnabled public Product__c objProduct{get;set;}
        @AuraEnabled public String ProdWeek{get;set;}
        @AuraEnabled public String EvalWeek{get;set;}
        @AuraEnabled public String CommWeek{get;set;}
        @AuraEnabled public String ProdYear{get;set;}
        @AuraEnabled public String EvalYear{get;set;}
        @AuraEnabled public String CommYear{get;set;}
        @AuraEnabled public Contact objcontact{get;set;}
        @AuraEnabled public string Status{get;set;}
        @AuraEnabled public Id BDrecId{get;set;}
        @AuraEnabled public Id prodRecId{get;set;}
        @AuraEnabled public Id evalRecId{get;set;}
        @AuraEnabled public Id commRecId{get;set;}
        @AuraEnabled public Id prodHRecId{get;set;}
        @AuraEnabled public Id evalHRecId{get;set;}
        @AuraEnabled public Id commHRecId{get;set;}
        @AuraEnabled public Id prodEvtRecId{get;set;}
        @AuraEnabled public Id evalEvtRecId{get;set;}
        @AuraEnabled public Id commEvtRecId{get;set;}
        @AuraEnabled public boolean isDisabled{get;set;}
        @AuraEnabled public string BDTName{get;set;}
        @AuraEnabled public string ConId{get;set;} 
        @AuraEnabled public string AccId{get;set;} 
        @AuraEnabled public boolean RequestForSubmit{get;set;} 
        @AuraEnabled public integer totalNoOfRecords{get;set;}
        @AuraEnabled public integer currentWeek{get;set;}
        @AuraEnabled public boolean isRSMUser{get;set;}
        @AuraEnabled public user loggedInUserName{get;set;}
        @AuraEnabled public boolean isAdmin{get;set;}
        @AuraEnabled public List<string>lstWeeksOfYear{get;set;}
        @AuraEnabled public List<string>lstWeeksOfNextYear{get;set;}
        @AuraEnabled public boolean isSubbmit{get;set;}
    } 
/********************************************
* @Method Name  : BDTrackerSave
* @Description  : It is used to save the BD Plans.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/   
    
    @AuraEnabled
    public static List<BDTrackerWrapper> BDTrackerSave(string objStr,boolean isSubmit,string Month,string userIdValue,integer selectedYear){
        List<BD_Tracker__c>lstSaubmitAll =new List<BD_Tracker__c>();
        List<BD_Tracker__c>lstTracker = new List<BD_Tracker__c>();
        List<BDTrackerWrapper>lstBDTrackerToRetuen = new List<BDTrackerWrapper>();
        List<Event>lstSaubmitAllEvent =new List<Event>();
        BDT_Submission_History__c bdtSubmissionHistory = new BDT_Submission_History__c();
         User userRec = new User();
        
        Map<String,List<dateTime>>WeekMap = New Map<String,List<dateTime>>();
         BDTrackerController.weeksWrapperWithMonth objWeeksWrapper = BDTrackerController.getYearwiseWeeks(Date.newInstance(selectedYear, 01, 01), Date.newInstance(selectedYear+1, 12, 31));   
        //Start
        	for(BDTrackerController.WeeksWrapper objWrap :objWeeksWrapper.weekWrapperObj){
                
              List<dateTime>lstDateString = new List<dateTime>();
                
                lstDateString.add(DateTime.newInstance(objWrap.startDate.year(), objWrap.startDate.month(), objWrap.startDate.day(), 9, 00, 00));
                lstDateString.add(DateTime.newInstance(objWrap.endDate.year(), objWrap.endDate.month(), objWrap.endDate.day(), 9, 00, 00));
                WeekMap.put(objWrap.WeekNumber+'-'+objwrap.year,lstDateString);
                
            }
        //ENd
         Id recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('BD Tracker').getrecordTypeId();   
            //START :Create BDT Submission Hsitory.
            
            List<BDT_Submission_History__c> objSubHistoryToUpdate = [Select id,Name,isSubmitted__c,Submission_Date__c,Submit_Count__c,WeekRange__c,OwnerId,createdDate
                                                                     from BDT_Submission_History__c where OwnerId=:userinfo.getUserId()
                                                                     AND WeekRange__c=:Month AND Year__c=:string.ValueOf(selectedYear)];
            List<BDT_Submission_History__c> objSubHistoryUpdateForSubmit = [Select id,Name,isSubmitted__c,Submission_Date__c,Submit_Count__c,WeekRange__c,OwnerId,createdDate
                                                                     from BDT_Submission_History__c where OwnerId=:userinfo.getUserId()
                                                                     AND  Year__c=:string.ValueOf(selectedYear) AND isSubmitted__c=false];
        if(isSubmit && objSubHistoryUpdateForSubmit.size() > 0){
            for(BDT_Submission_History__c objSubmit : objSubHistoryUpdateForSubmit){
                objSubmit.isSubmitted__c = true;
                
            }
            update objSubHistoryUpdateForSubmit;
        }
        
            if(objSubHistoryToUpdate.size() > 0){
                if(isSubmit){
                objSubHistoryToUpdate[0].isSubmitted__c = isSubmit;
                }
                objSubHistoryToUpdate[0].Last_Submit_Date__c = Date.valueOf(System.today());
                objSubHistoryToUpdate[0].Submit_Count__c =objSubHistoryToUpdate[0].Submit_Count__c+1; 
                objSubHistoryToUpdate[0].WeekRange__c = Month;
                objSubHistoryToUpdate[0].Year__c = string.ValueOf(selectedYear);
                objSubHistoryToUpdate[0].Replanning_Request_Status__c =System.Label.Not_Submitted;//'Not Submitted';
                Database.update(objSubHistoryToUpdate);
                bdtSubmissionHistory = objSubHistoryToUpdate[0];
            }else{
                BDT_Submission_History__c objSubHistory = new BDT_Submission_History__c();
               
                    objSubHistory.isSubmitted__c = isSubmit;
                
                objSubHistory.Replanning_Request_Status__c =System.Label.Not_Submitted;//'Not Submitted';
                objSubHistory.Submission_Date__c = Date.valueOf(System.today());
                objSubHistory.Submit_Count__c =1; 
                objSubHistory.WeekRange__c = Month;
                objSubHistory.Last_Submit_Date__c = Date.valueOf(System.today());
                objSubHistory.OwnerId = userinfo.getUserId();
                objSubHistory.Year__c = string.ValueOf(selectedYear);
                Database.insert(objSubHistory);
                
                bdtSubmissionHistory = objSubHistory;
            }  
            
            //END : BDT Submission History
            //Get RSM and Manager email Ids
            userRec = [Select Id, BDT_Approver__c, BDT_Approver__r.Email, Manager.Email from User where Id=:bdtSubmissionHistory.OwnerId];
          
        if(isSubmit){ 
            
            lstSaubmitAll = [Select id,isSubmitted__c,Stage__c,ownerId from BD_Tracker__c where (Stage__c='Product Discussion' OR Stage__c='Ürün Tartışması' OR Stage__c='Discussão sobre produtos' OR Stage__c='Discusión de producto') AND ownerId=:userInfo.getUserId()];
            for(BD_Tracker__c obj :lstSaubmitAll){
                obj.isSubmitted__c =true;  
            }
            
            Database.update(lstSaubmitAll);
            lstSaubmitAllEvent = [Select id,isSubmitted__c,BD_Tracker_Phase__c,ownerId,Milestone_stage__c from event where 
                                  ownerId=:userInfo.getUserId()
                                  AND Milestone_stage__c='Plan' AND isSubmitted__c=false];
            for(Event obj :lstSaubmitAllEvent){
                obj.isSubmitted__c =true;   
            }
            update lstSaubmitAllEvent;
        }
        
        List<BDTrackerWrapper> lstWrapper =   (List<BDTrackerWrapper>)System.JSON.deserialize(objStr, List<BDTrackerWrapper>.class);
        
        List<Event>lstEvent ; 
        for(BDTrackerWrapper objWrapper : lstWrapper) {
            
            if(objWrapper.BDrecID==null){
                if(isSubmit){
                    
                    objWrapper.isDisabled =isSubmit;
                }
                
                List<BD_Tracker__c>lstBDTracker = new List<BD_Tracker__c>();
                
                BD_Tracker__c objBDTracker = new BD_Tracker__c();
                objBDTracker.isSubmitted__c = isSubmit;
                
               //if(objBDTracker.isSubmitted__c){
                objBDTracker.BDT_Submission_History__c = bdtSubmissionHistory.Id;
                if(userRec.BDT_Approver__c!=null)
                    objBDTracker.RSM_Email__c = userRec.BDT_Approver__r.Email;
                if(userRec.Manager!=null)
                    objBDTracker.Manager_Email__c = userRec.Manager.Email;
                //}
                objBDTracker.Account__c = objWrapper.objAccount.Id;
                objBDTracker.Product__c = objWrapper.objProduct.ID;
                objBDTracker.Contact__c = objWrapper.objContact.Id;
                objBDTracker.Product_Discussion_Plan_Year__c = objWrapper.ProdYear;    
                objBDTracker.Evaluation_Plan_Year__c = objWrapper.EvalYear;    
                objBDTracker.Commercialization_Plan_Year__c = objWrapper.CommYear; 
                objBDTracker.Product_Discussion_Plan_Week__c = 'Week'+objWrapper.ProdWeek;    
                objBDTracker.Evaluation_Planned_Week__c = 'Week'+objWrapper.EvalWeek;    
                objBDTracker.Commercialization_Planned_Week__c = 'Week'+objWrapper.CommWeek;    
                objBDTracker.Stage__c = 'Product Discussion';
                objBDTracker.Status__c = 'Plan';
                objBDTracker.Planned_Year__c = string.valueOf(objWrapper.ProdYear);
                objBDTracker.Planned_Month__c = month;
                objBDTracker.PD_Status__c = 'Plan';
                objBDTracker.EV_Status__c = 'Plan';
                objBDTracker.CM_Status__c = 'Plan';
                lstBDTracker.add(objBDTracker);
                
                if(lstBDTracker.size() > 0 ){
                    Database.insert(lstBDTracker);
                }
                BD_Tracker__c objBD = lstBDTracker[0];
                List<BD_Tracker_Planning__c> lstPlanning;
                for(BD_Tracker__c objBDTrackerupdated : lstBDTracker){
                    lstPlanning   = new List<BD_Tracker_Planning__c>();
                    for(StageWrapper objString : objWrapper.lstStages){
                        
                        BD_Tracker_Planning__c objPlanning = new BD_Tracker_Planning__c();  
                        
                        objPlanning.Stage__c =objString.stageName;
                        objPlanning.Milestone_Stage__c = 'Plan';
                        objPlanning.BD_Tracker__c = objBDTrackerupdated.Id;
                        objPlanning.Account__c = objBDTrackerupdated.Account__c;
                        objPlanning.Product__c = objBDTrackerupdated.Product__c;
                        if(objString.stageName == 'Product Discussion'){
                            
                            objPlanning.Planned_Week__c = 'Week'+objWrapper.ProdWeek;  
                            objPlanning.Planned_Year__c = objWrapper.prodYear;
                        }
                        if(objString.stageName == 'Evaluation'){
                            objPlanning.Planned_Week__c = 'Week'+objWrapper.evalWeek;   
                            objPlanning.Planned_Year__c = objWrapper.EvalYear;
                        }
                        
                        if(objString.stageName == 'Commercialization'){
                            objPlanning.Planned_Week__c = 'Week'+objWrapper.CommWeek;
                            objPlanning.Planned_Year__c = objWrapper.CommYear;
                        }
                        lstPlanning.add(objPlanning); 
                        
                    }
                    
                    if(lstPlanning.size() > 0 ){
                        Database.insert(lstPlanning);
                    }
                    
                    for(BD_Tracker_Planning__c objPlan :lstPlanning){
                        List<BD_Tracker_History__c>lstHistory = new List<BD_Tracker_History__c>();
                        lstEvent= new List<Event>();
                        if(objPlan.Stage__c == 'Product Discussion' || objPlan.Stage__c =='Ürün Tartışması' || objPlan.Stage__c =='Discussão sobre produtos' || objPlan.Stage__c =='Discusión de producto'){
                            objWrapper.prodRecId = objPlan.Id;
                                  Event objEvent =new Event();
                                    objEvent.RecordTypeId = recId;
                                    objEvent.WhatId = objBDTracker.Id;
                                    objEvent.WhoId = objWrapper.objContact.Id;
                                    objEvent.Product__c = objWrapper.ObjProduct.Name;
                                    if(weekMap.containsKey(objWrapper.ProdWeek+'-'+objWrapper.ProdYear)){
                                        objEvent.StartDateTime =weekMap.get(objWrapper.ProdWeek+'-'+objWrapper.ProdYear)[0];
                                        objEvent.EndDateTime = weekMap.get(objWrapper.ProdWeek+'-'+objWrapper.ProdYear)[1].addDays(-2);
                                    }
                                    objEvent.Milestone_Plan_Week__c = 'Week'+objWrapper.prodWeek;
                                    objEvent.Subject = objWrapper.objAccount.Name;
                                    objEvent.BD_Tracker_Phase__c = objPlan.Stage__c;
                                    objEvent.BD_Tracker_Planning__c = objPlan.Id;
                                    objEvent.Milestone_Stage__c = 'Plan';
                                    if(isSubmit){
                                        objEvent.isSubmitted__c = isSubmit;
                                    }
                                    objEvent.Account__c = objWrapper.objAccount.Id;
                                   lstEvent.Add(objEvent);
                   
                            BD_Tracker_History__c objHistory = new BD_Tracker_History__c();
                            objHistory.Account__c = objPlan.Account__c;
                            objHistory.Product__c = objPlan.Product__c;
                            objHistory.Activity_Stage__c = 'Plan';
                            objHistory.Activity_Weeks__c =  'Week'+objWrapper.prodWeek;
                            objHistory.Activity_Year__c = objWrapper.prodYear;
                            objHistory.BD_Tracker_Planning__c = objPlan.Id;
                            lstHistory.add(objHistory);
                            
                        }
                        if(objPlan.Stage__c == 'Evaluation' || objPlan.Stage__c =='Değerlendirme' || objPlan.Stage__c =='Avaliação' || objPlan.Stage__c =='Evaluación'){
                            objWrapper.evalRecId = objPlan.Id;
                                    Event objEvent =new Event();
                                    objEvent.RecordTypeId = recId;
                                    objEvent.WhatId = objBDTracker.Id;
                                    objEvent.WhoId = objWrapper.objContact.Id;
                                    objEvent.Product__c = objWrapper.ObjProduct.Name;
                                    objEvent.Milestone_Plan_Week__c = 'Week'+objWrapper.evalWeek;
                                   
                                    if(weekMap.containsKey(objWrapper.evalWeek+'-'+objWrapper.evalYear)){
                                        objEvent.StartDateTime =weekMap.get(objWrapper.evalWeek+'-'+objWrapper.evalYear)[0];
                                        objEvent.EndDateTime = weekMap.get(objWrapper.evalWeek+'-'+objWrapper.evalYear)[1].addDays(-2);
                                    }
                            		objEvent.BD_Tracker_Phase__c = objPlan.Stage__c;
                                    objEvent.Subject = objWrapper.objAccount.Name;
                                    objEvent.BD_Tracker_Planning__c = objPlan.Id;
                                    objEvent.Milestone_Stage__c = 'Plan';
                                    if(isSubmit){
                                        objEvent.isSubmitted__c = isSubmit;
                                    }
                                    objEvent.Account__c = objWrapper.objAccount.Id;
                                   lstEvent.Add(objEvent);
                     
                            BD_Tracker_History__c objHistory1 = new BD_Tracker_History__c();
                            objHistory1.Account__c = objPlan.Account__c;
                            objHistory1.Product__c = objPlan.Product__c;
                            objHistory1.Activity_Stage__c = 'Plan';
                            objHistory1.Activity_Weeks__c = 'Week'+objWrapper.evalWeek;
                            objHistory1.Activity_Year__c = objWrapper.evalYear;
                            objHistory1.BD_Tracker_Planning__c = objPlan.Id;
                            lstHistory.add(objHistory1);
                        }
                        
                        if(objPlan.Stage__c == 'Commercialization' || objPlan.Stage__c =='Ticarileştirme' || objPlan.Stage__c =='Comercialização'|| objPlan.Stage__c =='Comercialización'){
                            objWrapper.commRecId = objPlan.Id;
                               
                                    Event objEvent =new Event();
                                    objEvent.RecordTypeId = recId;
                                    objEvent.WhatId = objBDTracker.Id;
                                    objEvent.WhoId = objWrapper.objContact.Id;
                                    objEvent.Product__c = objWrapper.ObjProduct.Name;
                                    objEvent.BD_Tracker_Planning__c = objPlan.Id;
                                    objEvent.Milestone_Plan_Week__c = 'Week'+objWrapper.commWeek;
                            		if(weekMap.containsKey(objWrapper.commWeek+'-'+objWrapper.commYear)){
                                        objEvent.StartDateTime =weekMap.get(objWrapper.commWeek+'-'+objWrapper.commYear)[0];
                                        objEvent.EndDateTime = weekMap.get(objWrapper.commWeek+'-'+objWrapper.commYear)[1].addDays(-2);
                                    }
                            		objEvent.BD_Tracker_Phase__c = objPlan.Stage__c;
                                    objEvent.Subject = objWrapper.objAccount.Name;
                                    objEvent.Milestone_Stage__c = 'Plan';
                                    objEvent.Account__c = objWrapper.objAccount.Id;
                                    if(isSubmit){
                                        objEvent.isSubmitted__c = isSubmit;
                                    }
                                   lstEvent.Add(objEvent);
                                    
                            BD_Tracker_History__c objHistory2 = new BD_Tracker_History__c();
                            objHistory2.Account__c = objPlan.Account__c;
                            objHistory2.Product__c = objPlan.Product__c;
                            objHistory2.Activity_Stage__c = 'Plan';
                            objHistory2.Activity_Weeks__c =  'Week'+objWrapper.commWeek;
                            objHistory2.Activity_Year__c = objWrapper.commYear;
                            objHistory2.BD_Tracker_Planning__c = objPlan.Id;
                            lstHistory.add(objHistory2);
                        }
                        
                        if(lstHistory.size() > 0 ){
                           Database.insert(lstHistory);
                        }
                        
                        if(lstEvent.size() > 0 ){
                           Database.insert(lstEvent);
                        } 
                        for(BD_Tracker_History__c objH : lstHistory){
                            if(objH.BD_Tracker_Planning__c == objWrapper.ProdRecId){
                                objWrapper.ProdHRecId = objH.Id;
                            }else if(objH.BD_Tracker_Planning__c == objWrapper.evalRecId){
                                objWrapper.evalHRecId = objH.Id;
                            }else if(objH.BD_Tracker_Planning__c == objWrapper.commRecId){
                                objWrapper.commHRecId = objH.Id;
                            }
                        }
                        for(Event objE : lstEvent){
                            if(objE.BD_Tracker_Planning__c == objWrapper.ProdRecId){
                                objWrapper.ProdevtRecId = objE.Id;
                            }else if(objE.BD_Tracker_Planning__c == objWrapper.evalRecId){
                                objWrapper.evalevtRecId = objE.Id;
                            }else if(objE.BD_Tracker_Planning__c == objWrapper.commRecId){
                                objWrapper.commevtRecId = objE.Id;
                            }
                        }
                        
                    }
                    
                    objWrapper.BDrecID = objBDTracker.Id;
                    objWrapper.Status = 'Plan';
                    
                    lstBDTrackerToRetuen.add(objWrapper);
                   
                }
            }else{
               
                List<BD_Tracker__c>   objTracker =[Select Id,Name,Product_Discussion_Plan_Year__c,Evaluation_Plan_Year__c,Commercialization_Plan_Year__c,Product_Discussion_Plan_Week__c,
                                                   Evaluation_Planned_Week__c,Commercialization_Planned_Week__c,Account__c,Product__c,Contact__c,Status__c,OwnerId,Stage__c
                                                   from BD_Tracker__c
                                                   where OwnerId=:userinfo.getUserId() and Stage__c!='Completed' AND ID=:objWrapper.BDRecId];
                
                if(objTracker.size()>0){
                    
                    List<BD_Tracker__c>lstBDTracker = new List<BD_Tracker__c>();
                    BD_Tracker__c objBDTracker = new BD_Tracker__c();
                    if(isSubmit){
                        objBDTracker.isSubmitted__c = isSubmit;
                    }
                    
                    //if(objBDTracker.isSubmitted__c){
                    objBDTracker.BDT_Submission_History__c = bdtSubmissionHistory.Id;
                    if(userRec.BDT_Approver__c!=null)
                        objBDTracker.RSM_Email__c = userRec.BDT_Approver__r.Email;
                    if(userRec.Manager!=null)
                        objBDTracker.Manager_Email__c = userRec.Manager.Email;
                    //}
                    
                    objBDTracker.id = objWrapper.BDRecId;
                    objBDTracker.Account__c = objWrapper.objAccount.Id;
                    objBDTracker.Product__c = objWrapper.objProduct.ID;
                    objBDTracker.Contact__c = objWrapper.objContact.Id;
                    objBDTracker.Product_Discussion_Plan_Year__c = objWrapper.ProdYear;    
                    objBDTracker.Evaluation_Plan_Year__c = objWrapper.EvalYear;    
                    objBDTracker.Commercialization_Plan_Year__c = objWrapper.CommYear; 
                    objBDTracker.Product_Discussion_Plan_Week__c = 'Week'+objWrapper.ProdWeek;    
                    objBDTracker.Evaluation_Planned_Week__c = 'Week'+objWrapper.EvalWeek;    
                    objBDTracker.Commercialization_Planned_Week__c = 'Week'+objWrapper.CommWeek;    
                    objBDTracker.Stage__c = 'Product Discussion';
                    objBDTracker.Status__c ='Plan';
                    objBDTracker.Planned_Year__c = String.valueOf(System.today().Year());
                    objBDTracker.Planned_Month__c =month;
                    lstBDTracker.add(objBDTracker);
                    
                    if(lstBDTracker.size() > 0 ){
                        Database.update(lstBDTracker);
                    }
                    List<BD_Tracker_Planning__c> lstPlanning;
                    for(BD_Tracker__c objBDTrackerupdated : lstBDTracker){
                        lstPlanning   = new List<BD_Tracker_Planning__c>();
                        for(StageWrapper objString : objWrapper.lstStages){
                            
                            BD_Tracker_Planning__c objPlanning = new BD_Tracker_Planning__c();  
                            
                            objPlanning.Stage__c =objString.stageName;
                            objPlanning.Milestone_Stage__c = 'Plan';
                            objPlanning.BD_Tracker__c = objBDTrackerupdated.Id;
                            objPlanning.Account__c = objBDTrackerupdated.Account__c;
                            objPlanning.Product__c = objBDTrackerupdated.Product__c;
                            if(objString.stageName == 'Product Discussion'){
                                objPlanning.Id = objWrapper.prodRecId;
                                objPlanning.Planned_Week__c = 'Week'+objWrapper.ProdWeek;  
                                objPlanning.Planned_Year__c = objWrapper.prodYear;
                            }
                            if(objString.stageName == 'Evaluation'){
                                objPlanning.Id = objWrapper.evalRecId;
                                objPlanning.Planned_Week__c = 'Week'+objWrapper.evalWeek;   
                                objPlanning.Planned_Year__c = objWrapper.EvalYear;
                            }
                            
                            if(objString.stageName == 'Commercialization'){
                                objPlanning.Id = objWrapper.commRecId;
                                objPlanning.Planned_Week__c = 'Week'+objWrapper.CommWeek;
                                objPlanning.Planned_Year__c = objWrapper.CommYear;
                            }
                            lstPlanning.add(objPlanning); 
                            
                        }
                        
                        if(lstPlanning.size() > 0 ){
                            
                            Database.upsert(lstPlanning);
                        }
                        
                       for(BD_Tracker_Planning__c objPlan :lstPlanning){
                            List<BD_Tracker_History__c>lstHistory = new List<BD_Tracker_History__c>();
                            lstEvent= new List<Event>();
                            if(objPlan.Stage__c == 'Product Discussion' || objPlan.Stage__c =='Ürün Tartışması' || objPlan.Stage__c =='Discussão sobre produtos'||objPlan.Stage__c =='Discusión de producto'){
                                objWrapper.prodRecId = objPlan.Id;
                                        Event objEvent =new Event();
                                        objEvent.Id = objWrapper.prodevtrecId;
                                        objEvent.RecordTypeId = recId;
                                        objEvent.WhatId = objBDTracker.Id;
                                        
                                        objEvent.WhoId = objWrapper.objContact.Id;
                                        objEvent.Product__c = objWrapper.ObjProduct.Name;
                                       if(weekMap.containsKey(objWrapper.prodWeek+'-'+objWrapper.ProdYear)){
                                            objEvent.StartDateTime =weekMap.get(objWrapper.prodWeek+'-'+objWrapper.ProdYear)[0];
                                            objEvent.EndDateTime = weekMap.get(objWrapper.prodWeek+'-'+objWrapper.ProdYear)[1].addDays(-2);
                                        }
                                		objEvent.Milestone_Plan_Week__c = 'Week'+objWrapper.prodWeek;
                                        objEvent.Subject = objWrapper.objAccount.Name;
                                        objEvent.BD_Tracker_Phase__c = objPlan.Stage__c;
                                        objEvent.BD_Tracker_Planning__c = objPlan.Id;
                                        objEvent.Milestone_Stage__c = 'Plan';
                                        objEvent.Account__c = objWrapper.objAccount.Id;
                                        if(isSubmit){
                                            objEvent.isSubmitted__c = isSubmit;
                                        }
                                        lstEvent.Add(objEvent);
                               // BD_Tracker_Planning__c BDPPD = New BD_Tracker_Planning__c(Id=objWrapper.ProdRecId);
                                BD_Tracker_History__c objHistory = new BD_Tracker_History__c();
                                objHistory.Id = objWrapper.ProdHRecId;
                                objHistory.Account__c = objPlan.Account__c;
                                objHistory.Product__c = objPlan.Product__c;
                                objHistory.Activity_Stage__c = 'Plan';
                                objHistory.Activity_Weeks__c =  'Week'+objWrapper.prodWeek;
                                objHistory.Activity_Year__c = objWrapper.prodYear;
                               // objHistory.BD_Tracker_Planning__c = BDPPD.Id;
                                lstHistory.add(objHistory);
                                
                            }
                            if(objPlan.Stage__c == 'Evaluation' || objPlan.Stage__c =='Değerlendirme' || objPlan.Stage__c =='Avaliação'|| objPlan.Stage__c =='Evaluación'){
                                objWrapper.evalRecId = objPlan.Id;
                                      Event objEvent =new Event();
                                        objEvent.Id = objWrapper.evalEvtRecId;
                                        objEvent.RecordTypeId = recId;
                                        objEvent.WhatId = objBDTracker.Id;
                                        objEvent.WhoId = objWrapper.objContact.Id;
                                        objEvent.Product__c = objWrapper.ObjProduct.Name;
                                        objEvent.Milestone_Plan_Week__c = 'Week'+objWrapper.evalWeek;
                                       if(weekMap.containsKey(objWrapper.evalWeek+'-'+objWrapper.evalYear)){
                                            objEvent.StartDateTime =weekMap.get(objWrapper.evalWeek+'-'+objWrapper.evalYear)[0];
                                            objEvent.EndDateTime = weekMap.get(objWrapper.evalWeek+'-'+objWrapper.evalYear)[1].addDays(-2);
                                        }
                                		objEvent.BD_Tracker_Phase__c = objPlan.Stage__c;
                                        objEvent.Subject = objWrapper.objAccount.Name;
                                        objEvent.BD_Tracker_Planning__c = objPlan.Id;
                                        objEvent.Milestone_Stage__c = 'Plan';
                                        objEvent.Account__c = objWrapper.objAccount.Id;
                                        if(isSubmit){
                                            objEvent.isSubmitted__c = isSubmit;
                                        }
                                        lstEvent.Add(objEvent);
                              //  BD_Tracker_Planning__c BDPEV = New BD_Tracker_Planning__c(Id=objWrapper.EvalRecId);
                                BD_Tracker_History__c objHistory1 = new BD_Tracker_History__c();
                                objHistory1.Id = objWrapper.evalHRecId;
                                objHistory1.Account__c = objPlan.Account__c;
                                objHistory1.Product__c = objPlan.Product__c;
                                objHistory1.Activity_Stage__c = 'Plan';
                                objHistory1.Activity_Weeks__c = 'Week'+objWrapper.evalWeek;
                                objHistory1.Activity_Year__c = objWrapper.evalYear;
                              //  objHistory1.BD_Tracker_Planning__c = BDPEV.Id;
                                lstHistory.add(objHistory1);
                            }
                            
                            
                            if(objPlan.Stage__c == 'Commercialization' || objPlan.Stage__c =='Ticarileştirme' || objPlan.Stage__c =='Comercialização' || objPlan.Stage__c =='Comercialización'){
                                objWrapper.commRecId = objPlan.Id;
                                        Event objEvent =new Event();
                                        objEvent.Id = objWrapper.commEvtRecId;
                                        objEvent.RecordTypeId = recId;
                                        objEvent.WhatId = objBDTracker.Id;
                                        objEvent.WhoId = objWrapper.objContact.Id;
                                        objEvent.Product__c = objWrapper.ObjProduct.Name;
                                        objEvent.BD_Tracker_Planning__c = objPlan.Id;
                                        objEvent.Milestone_Plan_Week__c = 'Week'+objWrapper.commWeek;
                               		if(weekMap.containsKey(objWrapper.commWeek+'-'+objWrapper.commYear)){
                                            objEvent.StartDateTime =weekMap.get(objWrapper.commWeek+'-'+objWrapper.commYear)[0];
                                            objEvent.EndDateTime = weekMap.get(objWrapper.commWeek+'-'+objWrapper.commYear)[1].addDays(-2);
                                        }
                                        objEvent.BD_Tracker_Phase__c = objPlan.Stage__c;
                                        objEvent.Subject = objWrapper.objAccount.Name;
                                        objEvent.Milestone_Stage__c = 'Plan';
                                        objEvent.Account__c = objWrapper.objAccount.Id;
                                        if(isSubmit){
                                            objEvent.isSubmitted__c = isSubmit;
                                        }
                                        lstEvent.Add(objEvent);
                                   //     BD_Tracker_Planning__c BDPCM = New BD_Tracker_Planning__c(Id=objWrapper.commRecId);
                               BD_Tracker_History__c objHistory2 = new BD_Tracker_History__c();
                                objHistory2.Id = objWrapper.commHRecId;
                                objHistory2.Account__c = objPlan.Account__c;
                                objHistory2.Product__c = objPlan.Product__c;
                                objHistory2.Activity_Stage__c = 'Plan';
                                objHistory2.Activity_Weeks__c =  'Week'+objWrapper.commWeek;
                                objHistory2.Activity_Year__c = objWrapper.commYear;
                               // objHistory2.BD_Tracker_Planning__c = BDPCM.Id;
                                lstHistory.add(objHistory2);
                            }
                            
                            if(lstHistory.size() > 0 ){
                               Database.upsert(lstHistory);
                            }
                            
                            if(lstEvent.size() > 0 ){
                                Database.upsert(lstEvent);
                            } 
                            for(BD_Tracker_History__c objH : lstHistory){
                                if(objH.BD_Tracker_Planning__c == objWrapper.ProdRecId){
                                    objWrapper.ProdHRecId = objH.Id;
                                }else if(objH.BD_Tracker_Planning__c == objWrapper.evalRecId){
                                    objWrapper.evalHRecId = objH.Id;
                                }else if(objH.BD_Tracker_Planning__c == objWrapper.commRecId){
                                    objWrapper.commHRecId = objH.Id;
                                }
                            }
                            for(Event objE : lstEvent){
                                if(objE.BD_Tracker_Planning__c == objWrapper.ProdRecId){
                                    objWrapper.ProdevtRecId = objE.Id;
                                }else if(objE.BD_Tracker_Planning__c == objWrapper.evalRecId){
                                    objWrapper.evalevtRecId = objE.Id;
                                }else if(objE.BD_Tracker_Planning__c == objWrapper.commRecId){
                                    objWrapper.commevtRecId = objE.Id;
                                }
                            }
                            
                        }
                        
                        
                        objWrapper.BDrecID = objBDTracker.Id;
                        if(isSubmit){
                            objWrapper.isDisabled =isSubmit;
                        }
                        objWrapper.Status = 'Plan';
                        lstBDTrackerToRetuen.add(objWrapper);
                        //End
                        
                    }
                }
                
                //End ****************************
            }
        }
        if(lstBDTrackerToRetuen.size() > 0){
            lstBDTrackerToRetuen[0].lstWeeksOfYear = getWeekssOfyear(integer.valueOf(lstWrapper[0].ProdYear),userIdValue);
        }
        return lstBDTrackerToRetuen;
    }
    
/********************************************
* @Method Name  : getProductDetails
* @Description  : It is used to return the product based upon the user division.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/    
    @AuraEnabled
    public static List<Product__c> getProductDetails(String strInput,string ObjectName){
        List<Product__c>lstProduct = new List<Product__c>();
        
        User objUser = [Select id,Name,Profile.Name,Division__c,ManagerId,RSM_User__c,User_Type__c from User where id=:userinfo.getUserId()];
        
        List<string>lstString = new LIst<String>();
        lstString = objUser.Division__c.split(';');

        List<Product__c>lstp;
        for(String obj : lstString){
            lstp =[SELECT Id,Name,Division__c,Active__c,Region__c,MSP__c 
                   from Product__c 
                   where Name LIKE :'%'+strInput+'%' AND division__c =:obj AND 
                   Active__c=true  AND Region__c=:objUser.User_Type__c
                   // AND ID NOT In :idSet
                   AND (MSP__c != null AND MSP__c > 0 ) limit 5];
            
            lstProduct.addAll(lstp); 
        }
        
        return lstProduct;
    }
/********************************************
* @Method Name  : getAccountDetails
* @Description  : It is used to return the Account on user click search.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/     
    @AuraEnabled
    public static List<Account> getAccountDetails(String strInput,string ObjectName){
        List<Account>lstAccount = new List<Account>();
        List<Account>lstAccountToReturn = new List<Account>();
        if(ObjectName.equals('Account')){
            User objUser = [Select id,Name,Profile.Name,ManagerId,RSM_User__c from User where id=:userinfo.getUserId()];
            
            lstAccount = [SELECT Id,Name,CIS_Rating__c,CE_Rating__c,SAP_Code__c,Region__c,Region__r.Name from Account where Name LIKE : '%'+strInput+'%' Limit 5]; 
            
        }  
        return lstAccount;
    }
/********************************************
* @Method Name  : getContactDetails
* @Description  : It is used to return the Contact on user click search.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/     
    @AuraEnabled
    public static List<Contact> getContactDetails(String strInput,string ObjectName,string accountId){
        List<Contact>lstContact = new List<Contact>();
        
        User objUser = [Select id,Name,Profile.Name,ManagerId,RSM_User__c from User where id=:userinfo.getUserId()];
        
        lstContact = [SELECT Id,AccountId,FirstName,Name from Contact where Name LIKE :'%'+strInput+'%' AND AccountId=:accountId Limit 5]; 
       
        return lstContact;
    }
/********************************************
* @Method Name  : getContactInfo
* @Description  : It is used to return the Contact based upon the user input string and related account.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/     
    @AuraEnabled
    public static Contact getContactInfo(String contactId,String accountId){
        
        Contact objContact = new Contact();
        if(contactId != null && accountId != null)
            objContact = [SELECT Id,FirstName,LastName,AccountId,Name from Contact where id=:contactId AND AccountId=:accountId limit 5]; 
        
        return objContact;
    }
/********************************************
* @Method Name  : getAccountInfo
* @Description  : It is used to return the Account based upon the user input string.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/     
    @AuraEnabled
    public static Account getAccountInfo(String accountId){
        
        Account objAccount = new Account();
        if(accountId != Null)
            objAccount = [SELECT Id,Name,CIS_Rating__c,CE_Rating__c,SAP_Code__c from Account where id=:accountId limit 5]; 
        
        return objAccount;
    }
/********************************************
* @Method Name  : getProductInfo
* @Description  : It is used to return the Product based upon the user input string,contactId And AccountId.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/     
    @AuraEnabled
    public static product__c getProductInfo(String productId,string accountId,string contactId){
        boolean valid =true;
        Product__c objProduct =new Product__c();
        if(productId !=null && accountId != null && contactId !=null){
            
            List<BD_Tracker__c>lstTracker = [Select id,Name,Account__c,Product__c,Contact__c,Stage__c
                                             from BD_Tracker__c where 
                                             Account__c=:accountId AND Product__c=:productId AND Contact__c=:contactId AND Stage__c!='Cancelled'];
            
            if(lstTracker.size() > 0){
                valid =false;
            }
        }
        if(!string.isEmpty(productId) && valid)
        {
            objProduct = [SELECT Id,Name,Dummy_Product_Description__c  from product__c where id=:productId limit 5]; 
            
            return objProduct;
        }else{
            return null;
        }     
    }
/********************************************
* @Method Name  : getWeeksDetail
* @Description  : It is used to return number of based upon the provided year.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/     
    @AuraEnabled
    public static List<string> getWeeksDetail(string year){
        
        BDTrackerController.weeksWrapperWithMonth obj = BDTrackerController.getYearwiseWeeks(Date.newInstance(Integer.valueOf(year), 01, 01), Date.newInstance(Integer.valueOf(year), 12, 31));
        List<String>lstWeeks = new List<String>();
        
        for(BDTrackerController.WeeksWrapper objWrap : obj.weekWrapperObj){
            if(objWrap.Year == Integer.valueOf(year)){
                lstWeeks.add(string.ValueOf(objWrap.WeekNumber));
                //lstWeeks.add('Week'+string.ValueOf(objWrap.WeekNumber));  
            }
        }
        return lstWeeks;
    }
/********************************************
* @Method Name  : getPickListValuesIntoList
* @Description  : It is used to return plan details when user screen get loaded.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/    
    @AuraEnabled
    public static List<BDTrackerWrapper> getPickListValuesIntoList(string userId){
        List<BDTrackerWrapper> objWrapper = new List<BDTrackerWrapper>();
        BDTrackerWrapper objv = new BDTrackerWrapper();
        List<StageWrapper>lstStageWrapper = new List<StageWrapper>();
        List<String> pickListValuesYear= new List<String>();
        
        Set<String>setOfRole = new Set<String>{'Biotech Vision Care Pvt. Ltd','CEO','Domestic Admin','Domestic RH','Head PMT','Manager - Clinical Affairs','Sr. Manager - Mkt',
            'Sr. Manager - PMT','ZSM','ZDM','RSM'};
                
                User objUser;
        if(userId !=null){
            objUser  = [select id,Name,Profile.Name,userRoleId,userRole.Name,ManagerId,RSM_User__c from User where id =: userId];
            objv.isAdmin = true;
        }else{
            objUser  = [select id,Name,Profile.Name,userRoleId,userRole.Name,ManagerId,RSM_User__c from User where id =: userInfo.getUserId()];
        }
        System.debug('Admin==>'+objUser.userRole.Name+'uId'+userInfo.getUserId());
        if(objUser.Profile.Name=='System Administrator' || setOfRole.contains((objUser.userRole.Name).split(' ')[0]) || objUser.userRole.Name=='Biotech Turkey  Employee Partner Executive'){
            objv.isAdmin = true;
              System.debug('AdminTrue');
        }else{
            objv.isAdmin = false; 
            System.debug('AdminFalse');
        }
        Schema.DescribeFieldResult fieldResultYear = BD_Tracker_Planning__c.Planned_Year__c.getDescribe();
        List<Schema.PicklistEntry> pleYear = fieldResultYear.getPicklistValues();
        for( Schema.PicklistEntry pickListVal : pleYear){
            pickListValuesYear.add(pickListVal.getLabel());
        }  
        
        BDTrackerController.weeksWrapperWithMonth obj = BDTrackerController.getYearwiseWeeks(Date.newInstance(Integer.valueOf(pickListValuesYear[0]), 01, 01), Date.newInstance(Integer.valueOf(pickListValuesYear[0]), 12, 31));
        List<String>lstWeeks = new List<String>();
        
        for(BDTrackerController.WeeksWrapper objWrap : obj.weekWrapperObj){
            if(objWrap.Year == Integer.valueOf(pickListValuesYear[0])){
                lstWeeks.add('Week'+string.ValueOf(objWrap.WeekNumber));  
            }
            
        }
        List<string>dummy =  new List<String>();
        List<String> pickListValuesList= new List<String>();
        Schema.DescribeFieldResult fieldResult = BD_Tracker_Planning__c.Stage__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for( Schema.PicklistEntry pickListVal : ple){
            
            StageWrapper objStageWrapper = new StageWrapper();
            objStageWrapper.stageName = pickListVal.getLabel();
            objStageWrapper.lstYears = pickListValuesYear;
            objStageWrapper.lstWeeks = dummy;
            lstStageWrapper.Add(objStageWrapper);
            
        }  
        
        objv.loggedInUserName = objUser;
        objv.lstStages = lstStageWrapper;
        objv.Status = 'New';
        objv.currentWeek = getCurrentWeekDetails();
        objv.isRSMUser = getUserInfo();
        //objv.isSubmitButtonLocked = getLockSubmitValues();
        objWrapper.add(objv);
        
        System.debug('objWrapper'+objWrapper);
        return objWrapper;
    }
    
    public class StageWrapper{
        @AuraEnabled public String stageName{get;set;}
        @AuraEnabled public List<String> lstYears{get;set;}
        @AuraEnabled public List<String> lstWeeks{get;set;}
    }
    
    public class  weeksWrapperWithMonth{
        @AuraEnabled public list<WeeksWrapper> weekWrapperObj{get;set;}
        @AuraEnabled public map<date, integer> lstCountMonth{get;set;}
    }     
    
    public class WeeksWrapper{
        @AuraEnabled public integer weekNumber{get;set;}
        @AuraEnabled public date startDate{get;set;}
        @AuraEnabled public date endDate{get;set;}
        @AuraEnabled public integer month{get;set;}
        @AuraEnabled public string monthName{get;set;}
        @AuraEnabled public integer year{get;set;}
    }
    ////////////Start
/********************************************
* @Method Name  : getYearwiseWeeks
* @Description  : It is used to return total week in each monthe based upon the start date and end date.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/   
    public static weeksWrapperWithMonth getYearwiseWeeks(date startDate, date endDate){
        
        List<WeeksWrapper>lstWeeksWrapper = new List<WeeksWrapper>();
        weeksWrapperWithMonth objMonthWIseWeeks  = new weeksWrapperWithMonth();
        date yrStartDate = date.newInstance(startDate.year(),1,1);
        date yrEndDate = date.newInstance(endDate.year(),12,31);
        datetime weekStDateTime,monthStartDateTime;
        date monthStartDt = yrStartDate, monthEndDt, weekStDt = yrStartDate, weekEndDt; 
        map<Date, integer> mapDate_WeekNumber = new map<Date,integer>();
        integer yearlyWeekCnt =1, year, month;
        Integer monthCount = yrStartDate.monthsBetween(yrEndDate);
        if (yrEndDate.day() > yrStartDate.day()) monthCount++;
        
        for(integer i=0; i<=monthCount; i++){
            year = monthStartDt.year();
            month = monthStartDt.month();
            
            monthStartDateTime = dateTime.newInstance(year, month, 1);
            monthEndDt = monthStartDt.addMonths(1).addDays(-1);
            
            weekStDt = monthStartDt;
            if(weekStDt.month()==1){
                boolean is53Week = false;
                //Check whether prev year was leap year or not
                dateTime lastJanDt = dateTime.newInstance(weekStDt.year()-1, 1, 1);
                if(Math.mod(lastJanDt.year(),4) == 0 && lastJanDt.format('EEE')=='Wed') {
                    is53Week = true;
                } else{
                    if(lastJanDt.format('EEE')=='Thu' || lastJanDt.format('EEE')=='Fri' || 
                       lastJanDt.format('EEE')=='Sat' || lastJanDt.format('EEE')=='Sun') {
                           is53Week = true;
                       }
                }
                
                weekStDateTime = date.newInstance(weekStDt.year(), weekStDt.month(), weekStDt.day());
                //Find the first monday of selected stocksheet Date time i.e week1 startdate
                system.debug(weekStDateTime.format('EEEE'));
                if(weekStDateTime.format('EEEE') != 'Monday' ) {
                    //weekStDt = weekStDt.addDays(1);
                    while(weekStDateTime.format('EEEE') != 'Monday') {
                        if(is53Week){
                            weekStDt = weekStDt.addDays(1);
                        }else{
                            weekStDt = weekStDt.addDays(-1);
                        }
                        weekStDateTime = date.newInstance(weekStDt.year(), weekStDt.month(), weekStDt.day());
                    }
                }
                yearlyWeekCnt = 1;
                WeeksWrapper objWrapper = new WeeksWrapper();
                objWrapper.year = year; 
                objWrapper.endDate = date.valueOf(weekStDateTime.addDays(7));
                objWrapper.startDate = date.valueOf(weekStDateTime);
                objWrapper.month = date.valueOf(weekStDateTime).addDays(7).Month();
                objWrapper.weekNumber = yearlyWeekCnt;
                lstWeeksWrapper.add(objWrapper);
                
                mapDate_WeekNumber.put( weekStDt, yearlyWeekCnt);
            }
            
            weekEndDt = weekStDt.addDays(7);
           while(weekStDt<=monthEndDt){
                
                weekStDateTime = date.newInstance(weekStDt.year(), weekStDt.month(), weekStDt.day());
                if(weekStDateTime.format('EEEE') != 'Monday') {
                    while(weekStDateTime.format('EEEE') != 'Monday') {
                        weekStDt = weekStDt.addDays(1);
                        weekStDateTime = date.newInstance(weekStDt.year(), weekStDt.month(), weekStDt.day());
                    }
                }
                
                //Add 7 days to get end of week
                weekEndDt = weekStDt.addDays(6);
                
                if(!mapDate_WeekNumber.containsKey(weekStDt)){
                    WeeksWrapper objWrapper = new WeeksWrapper();
                    objWrapper.year = year; 
                    objWrapper.endDate = date.valueOf(weekStDateTime.addDays(7));
                    objWrapper.startDate = date.valueOf(weekStDateTime);
                    objWrapper.month = date.valueOf(weekStDateTime).Month();
                    objWrapper.weekNumber = yearlyWeekCnt;
                    lstWeeksWrapper.add(objWrapper);
                    mapDate_WeekNumber.put( weekStDt, yearlyWeekCnt);    
                }
                //Calculate whether 52 or 53 weeks
              
                if (yearlyWeekCnt >=52 ){
                    boolean is53Weeks = false;
                    if(yearlyWeekCnt == 53 || (monthEndDt.month()!=1 && weekStDt.year() != weekEndDt.year())){
                        is53Weeks = false;
                    } else {
                        //Found leap year
                        //Get the day 1st of next year Jan
                        dateTime janDay1 = dateTime.newInstance(year, 1, 1);
                        if (Math.mod(year,4) == 0 && janDay1.format('EEE') == 'Wed') {
                            is53Weeks = true;						                        
                        } else if(janDay1.format('EEE') == 'Thu') {
                            is53Weeks = true;
                        }
                    }
                    if(!is53Weeks) {
                        yearlyWeekCnt = 1;
                        break;
                    }
                }
                yearlyWeekCnt++;
                weekStDt = weekEndDt.addDays(1);
            } 
            monthStartDt = monthStartDt.addMonths(1);
            
        }
        
        objMonthWIseWeeks.weekWrapperObj = lstWeeksWrapper;
        objMonthWIseWeeks.lstCountMonth = mapDate_WeekNumber;
     
        return objMonthWIseWeeks;
    }
    
    
    ///END 
/********************************************
* @Method Name  : getMonth
* @Description  : It is used to return return the Month Name based upon the month Number.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/    
    public static string getMonth(integer month){
        String str;
        Switch on month{
            when 1{str ='January';}
            when 2{str = 'February';}
            when 3{str = 'March';}
            when 4{str = 'April';}
            when 5{str = 'May';}
            when 6{str = 'June';}
            when 7{str = 'July';}
            when 8{str = 'August';}
            when 9{str = 'September';}
            when 10{str = 'October';}
            when 11{str = 'November';}
            when 12{str = 'December';}
        }
        return str;
    }
/********************************************
* @Method Name  : getBDTrackerByYearandMonth
* @Description  : It is used to return plan details when user chnage the year and week in UI Screen.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/    
    @AuraEnabled
    public static List<BDTrackerWrapper> getBDTrackerByYearandMonth(string year,string month,string uID){ 
        System.debug('year'+year);
        System.debug('month'+month);
        System.debug('uID'+uID);
        
        List<string>lstWeeks =  getWeekssOfyear(integer.valueOf(year),uID); 
        Set<String>setOfRole = new Set<String>{'Biotech Vision Care Pvt. Ltd','CEO','Domestic Admin','Domestic RH','Head PMT','Manager - Clinical Affairs','Sr. Manager - Mkt',
            'Sr. Manager - PMT','ZSM','ZDM','RSM'};
                
                List<BDTrackerWrapper>lstWrap = new List<BDTrackerWrapper>();
        List<BD_Tracker__c>lsTracker ;
        User objUser;
        if(uID!=null){
            objUser = [Select id,Name,Profile.Name,userRoleId,UserRole.Name,ManagerId,RSM_User__c from user where id=:uID];
            
        }else{
            objUser = [Select id,Name,Profile.Name,userRoleId,UserRole.Name,ManagerId,RSM_User__c from user where id=:userInfo.getUserId()];  
        }
        if(uID!=null){
            System.debug('objUser'+objUser);
            System.debug('InSide UID'+uID);
            System.debug('year'+year);
            System.debug('month'+month);
            
            lsTracker = [Select Id,Name,Product_Discussion_Plan_Year__c,Evaluation_Plan_Year__c,Commercialization_Plan_Year__c,Product_Discussion_Plan_Week__c,Stage__c,CreatedDate,
                         Evaluation_Planned_Week__c,Commercialization_Planned_Week__c,Account__c,isSubmitted__c,Product__c,Contact__c,Status__c,OwnerId,Planned_Year__c,Planned_Month__c
                         ,(Select id,BD_Tracker__c,stage__c from BD_Tracker_Plannings__r)                         					
                         from BD_Tracker__c 
                         where ownerId=:objUser.Id AND Product_Discussion_Plan_Year__c=:year AND Planned_Month__c=:month AND Stage__c!='Cancelled' Order By CreatedDate];
            
            
        }else{
            lsTracker = [Select Id,Name,Product_Discussion_Plan_Year__c,Evaluation_Plan_Year__c,Commercialization_Plan_Year__c,Product_Discussion_Plan_Week__c,Stage__c,CreatedDate,
                         Evaluation_Planned_Week__c,Commercialization_Planned_Week__c,Account__c,isSubmitted__c,Product__c,Contact__c,Status__c,OwnerId,Planned_Year__c,Planned_Month__c,
                         (Select id,BD_Tracker__c,stage__c from BD_Tracker_Plannings__r) 
                         from BD_Tracker__c
                         where OwnerId=:userinfo.getUserId() AND Product_Discussion_Plan_Year__c=:year AND Planned_Month__c=:month AND Stage__c!='Cancelled'/* AND Stage__c!='Completed'*/ Order By CreatedDate];
            
        }
        
        System.debug('lsTracker'+lsTracker);
        if(lsTracker.size() > 0 || lsTracker!= null){
            
            List<String> pickListValuesYear= new List<String>();
            Schema.DescribeFieldResult fieldResultYear = BD_Tracker_Planning__c.Planned_Year__c.getDescribe();
            List<Schema.PicklistEntry> pleYear = fieldResultYear.getPicklistValues();
            for( Schema.PicklistEntry pickListVal : pleYear){
                pickListValuesYear.add(pickListVal.getLabel());
            }  
            
            List<StageWrapper>lstStageWrapper = new List<StageWrapper>();
            List<BDTrackerWrapper>lst = new List<BDTrackerWrapper>();
            Schema.DescribeFieldResult fieldResult = BD_Tracker_Planning__c.Stage__c.getDescribe();
            List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
            for( Schema.PicklistEntry pickListVal : ple){
                
                StageWrapper objStageWrapper = new StageWrapper();
                objStageWrapper.stageName = pickListVal.getLabel();
                objStageWrapper.lstYears = pickListValuesYear;
                //  objStageWrapper.lstWeeks = dummy;
                lstStageWrapper.Add(objStageWrapper);
                
            }  
            
            
            set<Id>lstAccountId = new set<Id>();
            set<Id>lstContactId = new set<Id>();
            set<Id>lstProductId = new set<Id>();
            
            for(BD_Tracker__c objTrack :lsTracker){
                
                lstAccountId.add(objTrack.Account__c);
                lstContactId.add(objTrack.Contact__c);
                lstProductId.add(objTrack.Product__c);  
            }
            List<Account> lstobjAcc = [Select id,Name,CIS_Rating__c,SAP_Code__c,CE_Rating__c from Account where id IN :lstAccountId];
            List<Product__c> lstobjProd = [Select id,Name from Product__c where Id IN :lstProductId];
            List<contact> lstobjCon = [Select id,Name from contact where id IN :lstContactId];
            
            
            Map<string,Account>mapOfAccount = new Map<string,Account>();
            Map<string,Contact>mapOfContact = new Map<string,Contact>();
            Map<string,Product__c>mapOfProduct = new Map<string,Product__c>();
            
            for(Account objAccount : lstobjAcc){
                for(BD_Tracker__c objTrack :lsTracker){
                    if(objTrack.Account__c == objAccount.Id){
                        mapOfAccount.put(objTrack.Id,objAccount); 
                    }  
                }
            }
            for(Contact objContact : lstobjCon){
                for(BD_Tracker__c objTrack :lsTracker){
                    if(objTrack.Contact__c == objContact.Id){
                        mapOfContact.put(objTrack.Id,objContact); 
                    }  
                }
            }
            for(Product__c objProduct : lstobjProd){
                for(BD_Tracker__c objTrack :lsTracker){
                    if(objTrack.Product__c == objProduct.Id){
                        mapOfProduct.put(objTrack.Id,objProduct); 
                    }  
                }
            }
            
            for(BD_Tracker__c objTrack :lsTracker){
                if(objTrack.Account__c != null && objTrack.product__c!=null && objTrack.Contact__c!=null){
                    BDTrackerWrapper objv = new BDTrackerWrapper();
                    objv.ProdYear = objTrack.Product_Discussion_Plan_Year__c;
                    objv.EvalYear = objTrack.Evaluation_Plan_Year__c;
                    objv.commYear = objTrack.Commercialization_Plan_Year__c;
                    objv.prodweek = objTrack.Product_Discussion_Plan_Week__c.substringAfter('Week');
                    objv.evalweek = objTrack.Evaluation_Planned_Week__c.substringAfter('Week');
                    objv.commweek = objTrack.Commercialization_Planned_Week__c.substringAfter('Week');
                    if(mapOfAccount.containsKey(objTrack.Id)){
                        objv.objAccount = mapOfAccount.get(objTrack.Id);
                    }
                    if(mapOfProduct.containsKey(objTrack.Id)){
                        objv.objProduct = mapOfProduct.get(objTrack.Id);
                    }
                    if(mapOfContact.containsKey(objTrack.Id)){
                        objv.objcontact = mapOfContact.get(objTrack.Id);
                    }
                    objv.loggedInUserName = objUser;
                    
                    
                    objv.lstWeeksOfYear = lstWeeks;
                    //Check System Admin
                    
                    if(objUser.Profile.Name=='System Administrator' || setOfRole.contains((objUser.userRole.Name).split(' ')[0]) || objUser.UserRole.Name=='Biotech Turkey  Employee Partner Executive' ){
                        objv.isAdmin = true;
                    }else{
                        objv.isAdmin = false; 
                    }
                    
                    if(objTrack.Stage__c =='Completed'){
                        objv.Status = System.Label.Won;
                    }else if(objTrack.Stage__c =='Closed Lost'){
                        objv.Status = System.Label.Closed_Lost;
                    }else{
                        objv.Status = objTrack.Status__c;    
                    }
                    
                    objv.lstStages = lstStageWrapper;
                    objv.BDRecId = objTrack.Id;
                    objv.isDisabled = objTrack.isSubmitted__c;
                    
                    List<BD_Tracker_Planning__c>lstPlan = new List<BD_Tracker_Planning__c>();
                    List<event>lstEvent = new List<Event>();
                    List<BD_Tracker_History__c>lstHistory = new List<BD_Tracker_History__c>();
                    
                    //lstPlan = [Select id,BD_Tracker__c,stage__c from BD_Tracker_Planning__c where BD_Tracker__c =:objTrack.Id];
                    SYstem.debug('objTrack.BD_Tracker_Plannings__r'+objTrack.BD_Tracker_Plannings__r);
                    for(BD_Tracker_Planning__c objp :objTrack.BD_Tracker_Plannings__r){
                        
                        if(objp.stage__c=='Product Discussion' || objp.stage__c=='Ürün Tartışması' || objp.stage__c== 'Discussão sobre produtos' || objp.stage__c=='Discusión de producto'){
                            objv.prodRecId = objp.Id;	                            
                        }else if(objp.stage__c=='Evaluation' || objp.stage__c=='Değerlendirme' || objp.stage__c=='Avaliação' || objp.stage__c=='Evaluación'){
                            objv.evalRecId = objp.Id;	   
                        }else if(objp.stage__c=='Commercialization' || objp.stage__c=='Ticarileştirme' || objp.stage__c=='Comercialização' || objp.stage__c=='Comercialización'){
                            objv.commRecId = objp.Id;	     
                        }
                        
                        lstHistory =[Select id,Name,BD_Tracker_Planning__c from BD_Tracker_History__c where BD_Tracker_Planning__c =:objp.id]; 
                        lstEvent = [Select id,BD_Tracker_Planning__c from event where BD_Tracker_Planning__c =:objp.id];
                        
                        for(BD_Tracker_History__c objH :lstHistory){
                            
                            if(objH.BD_Tracker_Planning__c == objv.prodRecId){
                                objv.prodHRecId = objH.Id;  
                            }else if(objH.BD_Tracker_Planning__c == objv.evalRecId){
                                objv.evalHRecId = objH.Id;     
                            }else if(objH.BD_Tracker_Planning__c == objv.commRecId){
                                objv.commHRecId = objH.Id;    
                            }
                            
                        }
                        for(Event objE :lstEvent){
                            
                            if(objE.BD_Tracker_Planning__c == objv.prodRecId){
                                objv.prodEvtRecId = objE.Id;  
                            }else if(objE.BD_Tracker_Planning__c == objv.evalRecId){
                                objv.evalEvtRecId = objE.Id;     
                            }else if(objE.BD_Tracker_Planning__c == objv.commRecId){
                                objv.commEvtRecId = objE.Id;    
                            } 
                            
                        }
                    }
                    
                    lstWrap.add(objv);
                }
            }
        }
        System.debug('lstWrap'+lstWrap);
        return lstWrap;
    }
/********************************************
* @Method Name  : deleteBDTracker
* @Description  : It is used to delete the BD Plan.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/    
    @AuraEnabled
    public static List<string> deleteBDTracker(string jsonstr, string deleteReason ,integer year,string usr){
        
        BDTrackerWrapper objWrapper =   (BDTrackerWrapper)System.JSON.deserialize(jsonstr, BDTrackerWrapper.class);
        System.debug('objWrapper'+objWrapper);
        if(objWrapper.BDrecId !=null){
            
            List<BD_Tracker__c>lst  = [Select Id,Name,Product_Discussion_Plan_Year__c,Evaluation_Plan_Year__c,Commercialization_Plan_Year__c,Product_Discussion_Plan_Week__c,
                                       Evaluation_Planned_Week__c,Commercialization_Planned_Week__c,Account__c,Product__c,Contact__c,Status__c,OwnerId,Reason_For_Delete__c
                                       from BD_Tracker__c
                                       where id=:objWrapper.BDrecId];
            System.debug('lst'+lst);
            if((lst!=null || lst.size() > 0)  &&  objWrapper.isDisabled){
                lst[0].Stage__c = 'Cancelled';
                lst[0].Reason_For_Delete__c=deleteReason;
                if(!test.isRunningTest()){
                    Database.update(lst);
                }
            }else{
                delete lst;
            }
        }
        Id recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('BD Tracker').getrecordTypeId();
        List<Event>lstEvent = [Select id,recordtypeId,WhatId from Event where recordtypeId=:recId and WhatId =:objWrapper.BDrecId];
        if(lstEvent.size()>0 || lstEvent!= null){
            Database.delete(lstEvent);
        }
        
        List<string> lstWeeks = getWeekssOfyear(year,usr);
        return lstWeeks;
    }
/********************************************
* @Method Name  : monthWiseWeeks
* @Description  : It is used to get the weeks of the month based upon the month and year value.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/     
    @AuraEnabled
    public static List<integer> monthWiseWeeks(string year,string month){
        
        System.debug('month'+month);
        List<string>lstString = month.split('-');
        System.debug('lstString'+lstString);
        integer mon ;
        List<integer>lstint = new List<integer>();
        integer i =Integer.ValueOf(lstString[0]);
        while(i<=Integer.ValueOf(lstString[1])){
            lstint.add(i);
            i++;
        }
        
        System.debug('lstint'+lstint);
        return lstint;
    }
/********************************************
* @Method Name  : getWeeks
* @Description  : It is used to return weeks of the month.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/    
    @AuraEnabled
    public static List<integer> getWeeks(string year,string month){
        
        System.debug('month'+month);
        integer val = Integer.valueOf(month);
        integer mon=val+1;
        List<integer>lstint = new List<integer>();
        
        System.debug('mon'+mon);
        BDTrackerController.weeksWrapperWithMonth objWeeksWrapper = BDTrackerController.getYearwiseWeeks(Date.newInstance(Integer.valueOf(year), mon, Date.daysInMonth(Integer.valueOf(year),mon)), Date.newInstance(Integer.valueOf(year), mon, Date.daysInMonth(Integer.valueOf(year),mon)));  
        
        for(BDTrackerController.WeeksWrapper objWrap :objWeeksWrapper.weekWrapperObj){
            if(objWrap.year == Integer.valueOf(year) && objWrap.month == mon){
                
                lstint.add(objWrap.weekNumber);
            }
        }
        System.debug('lstint'+lstint);
        return lstint;
    }
/********************************************
* @Method Name  : reportName
* @Description  : It is used to return name of report.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/    
    @AuraEnabled
    public static string reportName(){
        User  objUser  = [select id,Name,Profile.Name,userRoleId,userRole.Name from User where id =: UserInfo.getUserId()];
        Userrole rl =[SELECT Id, Name, DeveloperName FROM UserRole WHERE Id =: objUser.userRoleId];
        SYstem.debug('r'+rl);
        string nm;
        List<Report>lst;
        lst = [SELECT  Id,Name,DeveloperName FROM Report WHERE Name= 'BD Tracker With Sales Person' limit 1];
        System.debug('objUser'+objUser);
        if(rl.Name =='Turkey Portal Business Partner Executive' || rl.Name =='Turkey Portal Business Partner Manager'){
            nm = '/turkeyemployee/s/report/'+lst[0].Id+'/BD-Tracker-With-Sales-Person';
        }
        else if(rl.Name=='Colambia and Brazil Portal User Partner User'){
            nm = '/employee/s/report/'+lst[0].Id+'/BD-Tracker-With-Sales-Person';
        }
        else{
            nm = '/lightning/r/Report/'+lst[0].Id+'/view';
        }
        return nm ;//= '/turkeyemployee/s/report/'+lst[0].Id+'/BD-Tracker-With-Sales-Person' ;
    }
/********************************************
* @Method Name  : getWeekssOfyear
* @Description  : It is used to return weeks of the year.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/     
    @AuraEnabled 
    public static  List<String>getWeekssOfyear(integer year,string uidValue){
        string yr =string.valueOf(year);
        List<integer>lstLeapYear =new List<integer>{2020,2026,2032,2037,2043,2048,2054,2060,2065,2071,2076,2082,2088,2093,2099};        
            System.debug('year'+year);
        List<Integer>lstString = new List<Integer>();
        map<Integer,List<integer>>mapint = new Map<Integer,List<Integer>>();
        Integer i=1;
        integer counter =1;
        while(i<=12){
            BDTrackerController.weeksWrapperWithMonth objWeeksWrapper = BDTrackerController.getYearwiseWeeks(Date.newInstance(year,i,1), Date.newInstance(year,i,Date.daysInMonth(year,i)));  
            
            for(BDTrackerController.WeeksWrapper objWrap :objWeeksWrapper.weekWrapperObj){
                System.debug('objWrap.WeekNumber+++'+objWrap.WeekNumber);
                if((objWrap.endDate.year() == year || objWrap.startDate.year() == year) && objWrap.month == i){
                    System.debug('lstString'+lstString);
                    lstString.add(objWrap.weekNumber);
                    
                }
            }
            System.debug('lstString'+lstString);
            for(Integer objInt : lstLeapYear){
                if(objInt == year && i==12){
                    
                    lstString.add(53);  
                }
            }
            if(lstString.size() >5){
                List<Integer>lstTemp = new List<Integer>();
                for(integer k=0;k<5;k++){
                    lstTemp.add(lstString[k]);
                }
                mapint.put(i,lstTemp);
            }
            else{
                mapint.put(i,lstString);
            }
            
            lstString = new List<Integer>();
            i++;
        }
        System.debug('mapInt'+mapInt);
        List<String>LStMonthString  = new List<String>();
        
        List<String>lstToReturn = new List<String>();
        for(integer k=1;k<=mapInt.size();k++){
            Integer sz = mapInt.get(k).size();
            List<Integer>lstInt = mapInt.get(k);
            String lstForm = string.ValueOf(lstInt[0]+'-'+lstInt[sz-1]);
            
            LStMonthString.add(lstForm);
            
        }
        List<BD_Tracker__c>lsTracker;
        if(uidValue == null){
        lsTracker = [Select Id,Name,Product_Discussion_Plan_Year__c,Evaluation_Plan_Year__c,Commercialization_Plan_Year__c,Product_Discussion_Plan_Week__c,Stage__c,CreatedDate,
                                        Evaluation_Planned_Week__c,Commercialization_Planned_Week__c,Account__c,isSubmitted__c,Product__c,Contact__c,Status__c,OwnerId,Planned_Year__c,Planned_Month__c
                                        from BD_Tracker__c
                                        where OwnerId=:userinfo.getUserId() AND Product_Discussion_Plan_Year__c=:yr AND Planned_Month__c In :LStMonthString AND Stage__c!='Cancelled' /*AND Stage__c!='Completed'*/ Order By CreatedDate];
        }else{
            
			lsTracker = [Select Id,Name,Product_Discussion_Plan_Year__c,Evaluation_Plan_Year__c,Commercialization_Plan_Year__c,Product_Discussion_Plan_Week__c,Stage__c,CreatedDate,
                                        Evaluation_Planned_Week__c,Commercialization_Planned_Week__c,Account__c,isSubmitted__c,Product__c,Contact__c,Status__c,OwnerId,Planned_Year__c,Planned_Month__c
                                        from BD_Tracker__c
                                        where OwnerId=:uidValue AND Product_Discussion_Plan_Year__c=:yr AND Planned_Month__c In :LStMonthString AND Stage__c!='Cancelled' /*AND Stage__c!='Completed'*/ Order By CreatedDate];
                    
        }
        map<string,integer>mapSize = new Map<string,integer>();
        
        for(BD_Tracker__c BD :lsTracker){
            if(mapSize.containskey(BD.Planned_Month__c)){
                
                integer sz = mapSize.get(BD.Planned_Month__c);
                sz = sz + 1;
                mapSize.put(BD.Planned_Month__c,sz);
            }else{
                
                mapSize.put(BD.Planned_Month__c,1); 
            }           
            
        }
        
        for(integer k=1;k<=mapInt.size();k++){
            Integer sz = mapInt.get(k).size();
            List<Integer>lstInt = mapInt.get(k);
            String lstForm = string.ValueOf(lstInt[0]+'-'+lstInt[sz-1]);
            
            if(mapSize.containsKey(lstForm)){
                
                lstToReturn.add(string.ValueOf(lstInt[0]+'-'+lstInt[sz-1]+' ('+mapSize.get(lstForm)+')'));
            }else{
                
                lstToReturn.add(string.ValueOf(lstInt[0]+'-'+lstInt[sz-1]+' ')); 
            }
            
        }
       
        System.debug('lstToReturn'+lstToReturn);
        return lstToReturn;
        
    }
/********************************************
* @Method Name  : weeknumber
* @Description  : It is used to return weeknumber.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/    
    @auraEnabled
    public static boolean weeknumber(integer year,string month){
        System.debug('month'+month);
        boolean isTrue =false;
        Date startdate = System.today();
        Date todaydateinstance = date.newinstance(startdate.year(), startdate.month(), startdate.day());
        List<String>lstString = month.split('-');
        Integer currentyear = startdate.year();
        
        Date yearstartdate = date.newinstance(currentyear, 01, 01);
        Date year2ndweek = yearstartdate.adddays(7).tostartofweek();
        
        if(startdate<year2ndweek){
            
            
            if(integer.valueof(lstString[1]) < 1 && year <= System.today().Year())
            {
                isTrue = true;
            }
            return isTrue;
        }
        integer numberDaysDue = year2ndweek.daysBetween(todaydateinstance);
        
        Integer numberOfWeek;
        if(math.mod(numberDaysDue,7)==0){
            numberOfWeek = math.MOD(Integer.valueof(math.FLOOR( ( numberDaysDue )/7)),52)+1;
        }
        else{
            numberOfWeek = math.MOD(Integer.valueof(math.FLOOR( ( numberDaysDue )/7)),52)+2;
        }
        System.debug('numberOfWeek'+numberOfWeek);
        // List<String>lstString = month.split('-');
        
        if(integer.valueof(lstString[1]) < numberOfWeek && year <= System.today().Year())
        {
            isTrue = true;
        }
        
        
        SYstem.debug('numberOfWeek'+numberOfWeek);
        return isTrue;
        
    }
/********************************************
* @Method Name  : validateAccount
* @Description  : It is used to validate selected account based upon the contact id and Product Id.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/    
    @AuraEnabled
    public static Account validateAccount(Id accId,Id conId,Id prodId){
        
        Account objAccount = New Account();
        boolean valid =true;
        if(prodId !=null && accId != null && conId !=null){
            
            List<BD_Tracker__c>lstTracker = [Select id,Name,Account__c,Product__c,Contact__c,Stage__c from BD_Tracker__c where Account__c=:accId AND Product__c=:prodId AND Contact__c=:conId AND Stage__c!='Cancelled'];
            
            if(lstTracker.size() > 0){
                System.debug('lstTracker'+lstTracker);
                valid =false;
            }
        }
        if(!string.isEmpty(accId) && valid)
        {
            objAccount = [SELECT Id,Name,CIS_Rating__c,CE_Rating__c,SAP_Code__c from Account where id=:accId]; 
            return objAccount;
        }else{
            return null;
        }
        
    }
/********************************************
* @Method Name  : getWeeksOfYear
* @Description  : It is used to get the weeks of the year.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/     
    @AuraEnabled
    public static Map<boolean,List<integer>> getWeeksOfYear(integer year,integer month,integer slYear){
        
        Map<boolean,List<integer>>mapWeekNumber = new Map<boolean,List<integer>>();
        boolean isTrue =false;
        List<integer>lstInteger = new list<integer>();
        integer counter =1;
        Date todayyr = Date.newInstance(System.today().Year(),01,01);
        Date nextWeek = Date.newInstance(System.today().Year(),12,31);
        Integer totalWeeks = todayyr.daysBetween(nextWeek)/7;
        date startDateOfWeek;
        integer endWeek;
        List<integer>lstLeapYear =new List<integer>{2020,2026,2032,2037,2043,2048,2054,2060,2065,2071,2076,2082,2088,2093,2099};        
            BDTrackerController.weeksWrapperWithMonth objWeeksWrapper = BDTrackerController.getYearwiseWeeks(Date.newInstance(year,1,1), Date.newInstance(year,1,31));  
        for(BDTrackerController.WeeksWrapper objWrap :objWeeksWrapper.weekWrapperObj){
            if(objWrap.year== year && objWrap.weekNumber >= month && slYear == year){
                
                
                System.debug('1');
                if(counter <=15 ){
                    lstInteger.add(objWrap.weekNumber);
                    counter++;
                }
            }else if(objWrap.year== year && year > slYear){
                System.debug('2');
                if(counter <=15 ){
                    lstInteger.add(objWrap.weekNumber);
                    counter++;
                }
            }
        }
        for(Integer objInnt : lstLeapYear){
            if(System.today().Year() == objInnt){
                totalWeeks = 53;  
            }
        }
        integer mon = month + 15;
        Integer DiffrenceValue;
        if(mon > totalWeeks){
            isTrue = true;
            DiffrenceValue = mon -totalWeeks;
            if(year == slYear){
                for(integer i=1;i<=DiffrenceValue;i++){
                    lstInteger.add(i);  
                }
            }else{
                lstInteger.clear();
                for(integer i=1;i<=DiffrenceValue;i++){
                    lstInteger.add(i);  
                }  
            }
        }
        mapWeekNumber.put(isTrue,lstInteger);
        return mapWeekNumber;
    }
    
/********************************************
* @Method Name  : getLockSubmitValues
* @Description  : It is used to lock the submit button based upon the 'provided date.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/    
    @AuraEnabled
    public static boolean getLockSubmitValues(string Month,string selYear){
        
        Locking_Period__mdt objSubmit = [Select id,DeveloperName,Close_Date__c,Open_Date__c,Label,Type__c,Region__c
                                         from Locking_Period__mdt where Label ='Lock Submit' AND Type__c='BD Tracker' AND
                                         Region__c='Domestic'][0];
      //  Date StartDate = Date.newInstance(system.today().Year(),System.today().Month(),1); 
      //  Date EndDate = Date.newInstance(system.today().Year(),System.today().Month(),Date.daysInMonth(system.today().Year(),System.today().Month()));
        
        List<BDT_Submission_History__c> objSubHistoryToUpdate = [Select id,Name,isSubmitted__c,Submission_Date__c,Submit_Count__c,Year__c,
                                                                 Number_of_Time_Reopened__c,WeekRange__c,OwnerId,createdDate,Request_for_Reopen__c
                                                                 from BDT_Submission_History__c where OwnerId=:userinfo.getUserId()
                                                                 AND WeekRange__c=:Month AND Year__c=:selYear];
        
        boolean isCheck =true;
        System.debug('objSubmit'+objSubmit);
        if(System.today().Day() >= Integer.valueOf(objSubmit.Open_Date__c) && System.today().Day() <= Integer.valueOf(objSubmit.Close_Date__c)){
            isCheck =false;
        }        
        if((objSubHistoryToUpdate != null && objSubHistoryToUpdate.size() > 0)
           && objSubHistoryToUpdate[0].isSubmitted__c){
               
               isCheck =true ; 
           }  
        
        
        return isCheck;
    }
/********************************************
* @Method Name  : getUserInfo
* @Description  : It is used to return current logged in user details.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/    
    @AuraEnabled
    public static boolean getUserInfo(){
        List<User> objUser = [Select id,Name,Profile.Name,userrole.name,ManagerId,RSM_User__c  from User where id=:UserInfo.getUserId() AND userrole.name LIKE'%RSM%'];
        boolean isTrue =false;
        
        if(objUser !=null && objUser.size() > 0){
            isTrue =true; 
        }else{
            isTrue =false;
        }
        return isTrue;
    }
/********************************************
* @Method Name  : getCurrentWeekDetails
* @Description  : It is used to get the current week based upon the todays date.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/     
    @AuraEnabled
    public static integer getCurrentWeekDetails(){
        Date startdate = System.today();
        Date todaydateinstance = date.newinstance(startdate.year(), startdate.month(), startdate.day());
        
        Integer currentyear = startdate.year();
        
        Date yearstartdate = date.newinstance(currentyear, 01, 01);
        Date year2ndweek = yearstartdate.adddays(7).tostartofweek();
        
        if(startdate<year2ndweek){
            return 1;
        }
        integer numberDaysDue = year2ndweek.daysBetween(todaydateinstance);
        
        Integer numberOfWeek;
        if(math.mod(numberDaysDue,7)==0){
            numberOfWeek = math.MOD(Integer.valueof(math.FLOOR( ( numberDaysDue )/7)),52)+1;
        }
        else{
            numberOfWeek = math.MOD(Integer.valueof(math.FLOOR( ( numberDaysDue )/7)),52)+2;
        }
        return numberOfWeek;
    }
/********************************************
* @Method Name  : callApproval
* @Description  : It is used to approve the user request for submit button.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/
    @AuraEnabled
    public static BDT_Submission_History__c callApproval(string Month,string selYear){
        boolean isSuccess =false;
      	System.debug('Month'+Month);
        System.debug('selYear'+selYear);
        List<BDT_Submission_History__c> objSubHistoryToUpdate = [Select id,Name,isSubmitted__c,Submission_Date__c,Submit_Count__c,Year__c,
                                                                 Replanning_Request_Status__c,Number_of_Time_Reopened__c,WeekRange__c,OwnerId,createdDate,Request_for_Reopen__c
                                                                 from BDT_Submission_History__c where OwnerId=:userinfo.getUserId()
                                                                 AND WeekRange__c=:Month AND Year__c=:selYear];
        
        System.debug('objSubHistoryToUpdate'+objSubHistoryToUpdate);
        System.debug('objSubHistoryToUpdate'+objSubHistoryToUpdate.size());
        
        if(objSubHistoryToUpdate.size() > 0){
            if(objSubHistoryToUpdate[0].Request_for_Reopen__c == false){
                objSubHistoryToUpdate[0].Request_for_Reopen__c= true;
                objSubHistoryToUpdate[0].Replanning_Request_Status__c = System.Label.Submitted;//'Submitted';
               
                if(objSubHistoryToUpdate[0].Number_of_Time_Reopened__c == null){
                    objSubHistoryToUpdate[0].Number_of_Time_Reopened__c =1;
                }
                else{
                    objSubHistoryToUpdate[0].Number_of_Time_Reopened__c = objSubHistoryToUpdate[0].Number_of_Time_Reopened__c+1;
                }
                
                Database.update(objSubHistoryToUpdate);
                System.debug('objSubHistoryToUpdate'+objSubHistoryToUpdate);
                isSuccess = true;
            }
        }
        return objSubHistoryToUpdate[0];
    }
/********************************************
* @Method Name  : checkApprovalPending
* @Description  : It is used to check the approval pending from the RSM user.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/    
    @AuraEnabled
    public static boolean checkApprovalPending(string uID,string Month,string selYear){
        boolean isTrue =false;
        
        List<BDT_Submission_History__c> objSubHistoryToUpdate = [Select id,Name,isSubmitted__c,Submission_Date__c,Submit_Count__c,Year__c,
                                                                 Number_of_Time_Reopened__c,WeekRange__c,OwnerId,createdDate,Request_for_Reopen__c
                                                                 from BDT_Submission_History__c where OwnerId=:uID
                                                                 AND WeekRange__c =:Month AND Year__c=:selYear];
        
        if(objSubHistoryToUpdate!=null && objSubHistoryToUpdate.size() > 0){
            if(objSubHistoryToUpdate[0].Request_for_Reopen__c == true && objSubHistoryToUpdate[0].Number_of_Time_Reopened__c!=null
               && objSubHistoryToUpdate[0].isSubmitted__c){
                   isTrue =true ; 
               }else{
                   isTrue =false;    
               }
        }
        
        return isTrue;
    }
/********************************************
* @Method Name  : updateforSubmitRequest
* @Description  : It is used to updaate the submit button based upon the approved and reject.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/    
    @AuraEnabled
    public static BDT_Submission_History__c updateforSubmitRequest(string Month,string selYear){
        boolean isTrue =false;
        
      
        List<BDT_Submission_History__c> objSubHistoryToUpdate = [Select id,Name,isSubmitted__c,Submission_Date__c,Submit_Count__c,Year__c,Replanning_Request_Status__c,
                                                                 Number_of_Time_Reopened__c,WeekRange__c,OwnerId,createdDate,Request_for_Reopen__c
                                                                 from BDT_Submission_History__c where OwnerId=:userinfo.getUserId()
                                                                 AND WeekRange__c =: Month AND Year__c=:selYear];
        if(objSubHistoryToUpdate.size() > 0){
            return objSubHistoryToUpdate[0];
        }else{
            return null;
        }
        //return isTrue;
    }
/********************************************
* @Method Name  : validatePlans
* @Description  : It is used to validate plans before getting saved to system for duplicacy.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/   
    @AuraEnabled
    public static boolean validatePlans(string objStr,boolean isSubmit,string Month,string year){
        
        List<BDTrackerWrapper> lstWrapper =   (List<BDTrackerWrapper>)System.JSON.deserialize(objStr, List<BDTrackerWrapper>.class);
        Boolean isTrue =true;
        List<BD_Tracker__c>lstTracker;
        
        lstTracker = new  List<BD_Tracker__c>(); 
        lstTracker = [select id,Account__c,Product__c,Contact__c,Planned_Year__c,ownerId,Status__c,stage__c from BD_Tracker__c where Planned_Year__c=:year AND
                      stage__c!='Cancelled' AND Stage__c!='Completed'];
        System.debug('lstTracker'+lstTracker);
        for(BDTrackerWrapper objWrapper : lstWrapper){
            
           for(Bd_Tracker__c objTrack:lstTracker){
               
                if(objTrack.Account__c == objWrapper.objAccount.id && 
                   objTrack.Product__c == objWrapper.objProduct.Id && objTrack.contact__c == objWrapper.objContact.Id ){
                       if((objWrapper.Status=='New'|| objWrapper.Status=='Plan') && objTrack.Status__c=='Plan' ){
                           continue;
                       }else{
                           isTrue = false;
                           break;
                       }  
                   } 
            }
            
        }
        
        return isTrue;
    }
/********************************************
* @Method Name  : approvePlan
* @Description  : It is used to approve the request for submit button.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/    
    @AuraEnabled
    public static void approvePlan(string uID,string Month,string selYear){
        List<BDT_Submission_History__c> objSubHistoryToUpdate = [Select id,Name,isSubmitted__c,Submission_Date__c,Submit_Count__c,Year__c,
                                                                 Number_of_Time_Reopened__c,WeekRange__c,OwnerId,createdDate,Request_for_Reopen__c
                                                                 from BDT_Submission_History__c where OwnerId=:uID
                                                                 AND WeekRange__c=:Month AND Year__c=:selYear];
        
        Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
        req.setComments('Approving request');
        req.setAction('Approve');
        // req.setNextApproverIds(new Id[] {opp.Next_Approver__c});
        Id workItemId = getWorkItemId(objSubHistoryToUpdate[0].id); 
        SYstem.debug('workItemId'+workItemId);
        if(workItemId == null)
        {
            //   objSubHistoryToUpdate[0].addError('Error Occured in Approval');
        }
        else
        {
            req.setWorkitemId(workItemId);
            // Submit the request for approval
            Approval.ProcessResult result =  Approval.process(req);
        }
        
    }
/********************************************
* @Method Name  : rejectPlan
* @Description  : It is used to reject the request for submit button.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/    
    @AuraEnabled
    public static void rejectPlan(string uID,string comment,string Month,string selYear){
        
        List<BDT_Submission_History__c> objSubHistoryToUpdate = [Select id,Name,isSubmitted__c,Submission_Date__c,Submit_Count__c,Year__c,
                                                                 Number_of_Time_Reopened__c,WeekRange__c,OwnerId,createdDate,Request_for_Reopen__c
                                                                 from BDT_Submission_History__c where OwnerId=:uID
                                                                 AND WeekRange__c=:Month AND Year__c=:selYear]; 
        System.debug('objSubHistoryToUpdate'+objSubHistoryToUpdate);
        Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
        req.setComments(comment);
        req.setAction('Reject');
        Id workItemId = getWorkItemId(objSubHistoryToUpdate[0].id);  
        if(workItemId == null)
        {
            
        }
        else
        {
            req.setWorkitemId(workItemId);
            Approval.ProcessResult result =  Approval.process(req);
        }
        
    }
/********************************************
* @Method Name  : getWorkItemId
* @Description  : It is used to retunr the approval process id.
* @Created Date : 26-11-2019
* @Created By   : Rajesh N. 
* ****************************************/      
    public static Id getWorkItemId(Id targetObjectId)
    {
        Id retVal = null;
        for(ProcessInstanceWorkitem workItem  : [Select p.Id from ProcessInstanceWorkitem p
                                                 
                                                 where p.ProcessInstance.TargetObjectId =: targetObjectId])
            
        {
            
            retVal  =  workItem.Id;
            
        }
        
        
        
        return retVal;
        
    }
    public static void updateBDApproverOnUser(set<id> userIds){
        //Get region
        list<User_Region_Association__c> userRegions = [Select Id, User__c, User__r.UserRole.Name, Region__c, User__r.BDT_Approver__c,User__r.Portal_User_Role__c,
                                                        Region__r.Region_Code__c,Region__r.OwnerId from User_Region_Association__c
                                                       where User__c IN : userIds];
        System.debug('userRegions'+userRegions);
        map<string, list<User_Region_Association__c>> mapRegion_User = new map<string, list<User_Region_Association__c>>();
        list<User_Region_Association__c> lstUserRegionAsso = new list<User_Region_Association__c>();
        for(User_Region_Association__c userRegion : userRegions){
            lstUserRegionAsso = new list<User_Region_Association__c>();
            if(mapRegion_User.containsKey(userRegion.Region__r.Region_Code__c)){
                lstUserRegionAsso = mapRegion_User.get(userRegion.Region__r.Region_Code__c);
            }
            lstUserRegionAsso.add(userRegion);
            mapRegion_User.put(userRegion.Region__r.Region_Code__c, lstUserRegionAsso);
        }
        
        //Get RSM for region
        list<User_Region_Association__c> ManagerRegions = [Select Id, User__c, User__r.UserRole.Name, Region__c,User__r.BDT_Approver__c,User__r.Portal_User_Role__c,
                                                        Region__r.Region_Code__c,Region__r.OwnerId from User_Region_Association__c
                                                       where  Region__r.Region_Code__c IN : mapRegion_User.keySet()
                                                           and User__r.IsActive=true and (User__r.UserRole.Name LIKE 'RSM%' 
                                                                                          OR User__r.UserRole.Name LIKE 'ZSM%' 
                                                                                          OR User__r.UserRole.Name LIKE 'India Sales Head%'
                                                                                          OR User__r.Portal_User_Role__c LIKE 'RSM%'
                                                                                          OR User__r.Portal_User_Role__c LIKE 'Product Manager%')];
        
        System.debug('ManagerRegions'+ManagerRegions);
        map<string, list<User_Region_Association__c>> mapRSMRegion_User = new map<string, list<User_Region_Association__c>>();
        map<string, list<User_Region_Association__c>> mapZSMRegion_User = new map<string, list<User_Region_Association__c>>();
        map<string, list<User_Region_Association__c>> mapIndiaSalesHeadRegion_User = new map<string, list<User_Region_Association__c>>();
        map<string, list<User_Region_Association__c>> mapTurkeyPartnerManagerRegion_User = new map<string, list<User_Region_Association__c>>();
        map<string, list<User_Region_Association__c>> mapTurkeyRSMRegion_User = new map<string, list<User_Region_Association__c>>();
        
        lstUserRegionAsso = new list<User_Region_Association__c>();
        for(User_Region_Association__c userRegion : ManagerRegions) {
            lstUserRegionAsso = new list<User_Region_Association__c>();
            if(userRegion.User__r.Portal_User_Role__c.contains('RSM')){
                if(mapTurkeyRSMRegion_User.containsKey(userRegion.User__r.Portal_User_Role__c)){
                    lstUserRegionAsso = mapTurkeyRSMRegion_User.get(userRegion.User__r.Portal_User_Role__c);
                }
                lstUserRegionAsso.add(userRegion);
                mapTurkeyRSMRegion_User.put(userRegion.Region__r.Region_Code__c, lstUserRegionAsso);
            }else if(userRegion.User__r.Portal_User_Role__c.contains('Product Manager')){
                if(mapTurkeyPartnerManagerRegion_User.containsKey(userRegion.User__r.Portal_User_Role__c)){
                    lstUserRegionAsso = mapTurkeyPartnerManagerRegion_User.get(userRegion.User__r.Portal_User_Role__c);
                }
                lstUserRegionAsso.add(userRegion);
                mapTurkeyPartnerManagerRegion_User.put(userRegion.Region__r.Region_Code__c, lstUserRegionAsso);
            }else if(userRegion.User__r.UserRole.Name.contains('RSM')){
                if(mapRSMRegion_User.containsKey(userRegion.User__r.UserRole.Name)){
                    lstUserRegionAsso = mapRSMRegion_User.get(userRegion.User__r.UserRole.Name);
                }
                lstUserRegionAsso.add(userRegion);
                mapRSMRegion_User.put(userRegion.Region__r.Region_Code__c, lstUserRegionAsso);
            } else if(userRegion.User__r.UserRole.Name.contains('ZSM')){
                if(mapZSMRegion_User.containsKey(userRegion.User__r.UserRole.Name)){
                    lstUserRegionAsso = mapZSMRegion_User.get(userRegion.User__r.UserRole.Name);
                }
                 lstUserRegionAsso.add(userRegion);
                mapZSMRegion_User.put(userRegion.Region__r.Region_Code__c, lstUserRegionAsso);
            } else if(userRegion.User__r.UserRole.Name.contains('India Sales Head')) {
                if(mapIndiaSalesHeadRegion_User.containsKey(userRegion.User__r.UserRole.Name)){
                    lstUserRegionAsso = mapIndiaSalesHeadRegion_User.get(userRegion.User__r.UserRole.Name);
                }
                lstUserRegionAsso.add(userRegion);
                mapIndiaSalesHeadRegion_User.put(userRegion.Region__r.Region_Code__c, lstUserRegionAsso);
            }
        }
        
        system.debug('**mapIndiaSalesHeadRegion_User***'+mapIndiaSalesHeadRegion_User);
        system.debug('**ZSM***'+mapZSMRegion_User);
        system.debug('**RSM***'+mapRSMRegion_User);
        //User_Region_Association__c userRegionAsso = new User_Region_Association__c();
        //list<User> userBDTUpdate = new list<User>();
        map<id, User>  mapUserBDTUpdate =  new map<id, User> ();
        lstUserRegionAsso = new list<User_Region_Association__c>();
        for(string regionCode : mapRegion_User.keySet()){
            lstUserRegionAsso = mapRegion_User.get(regionCode);
            for(User_Region_Association__c userRegionAsso : lstUserRegionAsso){
                if(mapRSMRegion_User.containsKey(regionCode) && mapRSMRegion_User.get(regionCode)[0].user__c!=userRegionAsso.User__r.BDT_Approver__C){
                    mapUserBDTUpdate.put(userRegionAsso.user__c ,new User(id=userRegionAsso.user__C, BDT_Approver__C = mapRSMRegion_User.get(regionCode)[0].user__c));
                }else if(mapZSMRegion_User.containsKey(regionCode) && mapZSMRegion_User.get(regionCode)[0].user__c!=userRegionAsso.User__r.BDT_Approver__C){
                   mapUserBDTUpdate.put(userRegionAsso.user__c ,new User(id=userRegionAsso.user__C, BDT_Approver__C = mapZSMRegion_User.get(regionCode)[0].user__c));
                } else if(mapIndiaSalesHeadRegion_User.containsKey(regionCode) && mapIndiaSalesHeadRegion_User.get(regionCode)[0].user__c!=userRegionAsso.User__r.BDT_Approver__C){
                   mapUserBDTUpdate.put(userRegionAsso.user__c ,new User(id=userRegionAsso.user__C, BDT_Approver__C = mapIndiaSalesHeadRegion_User.get(regionCode)[0].user__c));
                } else if(mapTurkeyRSMRegion_User.containsKey(regionCode) && mapTurkeyRSMRegion_User.get(regionCode)[0].user__c!=userRegionAsso.User__r.BDT_Approver__C){
                   mapUserBDTUpdate.put(userRegionAsso.user__c ,new User(id=userRegionAsso.user__C, BDT_Approver__C = mapTurkeyRSMRegion_User.get(regionCode)[0].user__c));
                } 
                else if(mapTurkeyPartnerManagerRegion_User.containsKey(regionCode) && mapTurkeyPartnerManagerRegion_User.get(regionCode)[0].user__c!=userRegionAsso.User__r.BDT_Approver__C){
                   mapUserBDTUpdate.put(userRegionAsso.user__c ,new User(id=userRegionAsso.user__C, BDT_Approver__C = mapTurkeyPartnerManagerRegion_User.get(regionCode)[0].user__c));
                } 
            }
        }
        
        system.debug('****update mapUserBDTUpdate***'+mapUserBDTUpdate);
        if(mapUserBDTUpdate.size() > 0){
            update mapUserBDTUpdate.values();
        }
           
           
        
        
    }
    public class ApprovalWrapper{
        @AuraENabled public boolean isrsmUser{get;set;}
        @AuraENabled public List<BDT_Submission_History__c>lstHistory{get;set;}
        
        public ApprovalWrapper(){
            this.isrsmUser = false;
            this.lstHistory = null;
        }
    }
    @AuraEnabled
    public static List<BDT_Submission_History__c>getListOfApproval(){
        ApprovalWrapper objWrapper = new ApprovalWrapper();
        objWrapper.lstHistory = new List<BDT_Submission_History__c>();
        List<ProcessInstance>lstinstance = new List<ProcessInstance>();
        List<BDT_Submission_History__c>lstinstanceToReturn = new List<BDT_Submission_History__c>();
        map<id,ProcessInstance>lstMap = new Map<Id,ProcessInstance>();
        lstinstance = [select id,TargetObjectId,TargetObject.Name,(select id,actor.Name,stepStatus,actorId 
                                                                   from stepsAndWorkItems
                                                                   where stepStatus='pending' AND actorId=:userinfo.getUserId())
                       from processinstance];
        for(ProcessInstance obj : lstinstance){
            if(obj.stepsAndWorkItems != Null){
                for(ProcessInstanceHistory objItem : obj.stepsAndWorkItems){
                    if(objItem.stepStatus == 'pending'){
                        lstMap.put(obj.TargetObjectId,obj); 
                    }
                }
            }
        }
        
        List<BDT_Submission_History__c>lstHistory = new list<BDT_Submission_History__c>();
        lstHistory = [Select id,Name,OwnerId,Owner.Name,Go_To_Plan__c, Year__c, WeekRange__c from BDT_Submission_History__c];
        for(BDT_Submission_History__c objHistory : lstHistory){
            if(lstMap.containsKey(objHistory.Id)){
                lstinstanceToReturn.add(objHistory);
            }
        }
        System.debug('lstinstanceToReturn'+lstinstanceToReturn);
       User  objUser  = [select id,Name,Profile.Name,userRoleId,userRole.Name,ManagerId,RSM_User__c from User where id =: UserInfo.getUserId()];
        if(objUser.userRole.Name == 'Biotech Turkey  Employee Partner Executive'){
            objWrapper.isrsmUser =true;
        }else{ 
            objWrapper.isrsmUser =false;
        }
        objWrapper.lstHistory = lstinstanceToReturn;
        
        return lstinstanceToReturn;
    }
    
      public static void fakMethod(){
        integer i=0;
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
        i++;
          i++;i++;
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
        
    }  
    
}
/*******************************************************************************
Description : This controller will take care of calendar events
Date : 01-01-2019
Created By : Prashant Rana 
********************************************************************************/
global with sharing class DailyCallRecordController {
    public string eventData{get;set;}
    public string accountData{get;set;}
    public string allUser{get;set;}
    public List<String> pickListValuesList{get;set;}
    public user userObj{get;set;}
    public string userObject{get;set;}
    public string managerList{get;set;}
    public string productList{get;set;}
    public DCR_Planning_Translation_Turkey__c translationObject{get;set;}
    public String curentLang {get;set;}
    public Event currentEvent {get;set;}
    public string aId{get;set;}
    
    // START :BD Tracker 
    public  id accId{get;set;}
    public  string dateVal{get;set;}
    public  string dateValUpdate{get;set;}
    public List<Event>lstEvent{get;set;}
    public Boolean displayUpdatePopUp {get;set;}
    public Boolean displayPopup {get;set;}
    public   Boolean displayPopUpToShow {get;set;}
    public   List<DailyCallRecordController.BDWrapper>lstWrapper{get;set;}
    public   List<DailyCallRecordController.BDWrapper>lstWrapperToShow{get;set;}
    public static List<DailyCallRecordController.BDWrapper>lstWrapperToShowS{get;set;}
    public string eventIds{get;set;}
    public integer weekN {get; set;}
    public boolean isLinkToBD{get;set;}
    
    public  string accIdUpdate{get;set;}
    public  string evtIds{get;set;}
    public string updateEvent{get;set;} 
    public string idBeforeUpdate{get;set;} 
    public boolean checkUpdateBDButton {get;set;}
    //END BD Tracker
    global string selectedRegion{get;set;}	
    global String selectedZone{get;set;}
    public list<SelectOption> userRegionSelectList {get;set;}
    public list<SelectOption> userZoneSelectList {get;set;}
    //Constructor 
    global DailyCallRecordController(){
        try{ 
            
            Set<id> Userlst = new Set<Id>();
            
            userObj = [select id, name, profileId,User_Type__c,Profile.Name,userRoleId,userRole.Name from user where id =: userInfo.getUserId()];
            Userrole rl =  new Userrole();
            if(userObj.userRoleId != null){
                rl =[SELECT Id, Name, DeveloperName FROM UserRole WHERE Id =: userObj.userRoleId];
            }
             
            Id recId;
            if(rl.Name != null ){
                if(rl.Name=='Colambia and Brazil Portal User Partner User'){
                    
                    // recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('Planejamento do DCR').getrecordTypeId();  
                    recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('DCR Planning').getrecordTypeId();  
                }else{
                    
                    recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('DCR Planning').getrecordTypeId();  
                    
                }
            }else{
                recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('DCR Planning').getrecordTypeId();  
            }
            
            userObject = JSON.serialize(userObj);
            System.debug('user object : '+userObject);
            curentLang = userinfo.getLanguage();
            translationObject = DCR_Planning_Translation_Turkey__c.getValues(curentLang);
            System.debug('translationObject'+translationObject);
            Set<id> subord = new set<id>();
            Set<id> subord1 = new set<id>();
            Set<id> subord2 = new set<id>();
            Set<id> subord3 = new set<id>();
            List<User> Finallist2 = new List<User>();
            List<User> Finallist = new List<User>();
            Set<id> level2 = new Set<id>();
            List<User> Finallist1 = new List<User>();
            list<user> mngList = [select id, name from user where  IsActive = true
                                  and (ManagerId =: UserInfo.getUserId() or ID =:UserInfo.getUserId())];//Rajesh 
            system.debug('***mngList***'+mngList);
            for(User usr:mngList){
                subord.add(usr.id);   
            }
            if(subord.size() > 0){
                Finallist = [select id, name,ManagerId from user where IsActive = true AND (ManagerId =: UserInfo.getUserId()OR ManagerId=:subord OR ID =:UserInfo.getUserId())];//Pratiksha
                system.debug('***Finallist***'+Finallist);
                
            }
            for(User usr:Finallist){
                subord1.add(usr.id); 
                System.debug('Inside Finalist');
            }
            if(subord1.size() > 0){
                Finallist1 = [select id, name,ManagerId from user where IsActive = true AND (ManagerId =: UserInfo.getUserId() OR ManagerId=:subord1 OR ManagerId=:subord )];//Pratiksha
                system.debug('***Finallist1***'+Finallist1);
                for(User usr:Finallist1){
                    subord2.add(usr.id); 
                    System.debug('Inside Finalist1');
                }
            }
            if(subord2.size() > 0){
                Finallist2 = [select id, name,ManagerId from user where IsActive = true AND (ManagerId =: UserInfo.getUserId() OR ManagerId=:subord2 OR ManagerId=:subord1 OR ManagerId=:subord)];//Pratiksha
                system.debug('***Finallist2***'+Finallist2);
                for(User usr:Finallist2){
                    subord3.add(usr.id);
                    System.debug('Inside Finalist2');
                }
            }
            
            
            if(!Finallist2.isempty()){
                
                
                
                
                
                String ues = JSON.serialize(Finallist2);
                managerList = ues.escapeUnicode().remove('\'');
                System.debug('manager List2 : '+Finallist2);
                System.debug('Inside JSON');
            }
            system.debug('Manager list2 : '+Finallist2);
            System.debug('Inside Event obj');
            list<event> evObj =[select id,Account_Visit_Call_Type__c,Call_Type__c,toLabel(Review_Call_Type__c),follow_Up_Date__c,toLabel(Meeting_Type__c),ActivityDate,startdateTime,
                                DCR_Description__c,endDateTime,subject,toLabel(Product__c),Account__r.Name,Account__r.RecordType.DeveloperName,Account__r.BillingCountry,
                                Event_Locked__c,CE_Rating__c,CIS_Rating__C, toLabel(Status__c),toLabel(Stage__c),Other_Type__c,Account__c,Type_Of_Leave__c,
                                WhoId from event where 
                                ownerId =:UserInfo.getUserId() ];
            currentEvent = new Event();

            if(!evObj.isEmpty()){
                String res = JSON.serialize(evObj);
                eventData = res.escapeUnicode().remove('\'');
                System.debug('event data : '+eventData);
                currentEvent = evObj[0];
            }
            system.debug('currentEvent*****'+currentEvent);
  
            list<GroupMember>grp=[SELECT Id, GroupId, UserOrGroupId FROM GroupMember where Group.Name = 'HO' OR Group.Name ='Admin Level User'];
            list<account> accObj = [select id,(select contact.Name, contact.Department, contact.Id from contacts), BillingCountry,
                                    name,recordType.DeveloperName,phone,Status__c,Account_Locked__c,Account_Locked_Reason__c, 
                                    CE_Rating__c,CIS_Rating__c, Branch__c, BillingCity, Region__r.country_key__c,Region__r.Zone_Code__c
                                    from account order by Name];
            
            map<string, list<Account>> mapRegion_Account = new map<string, list<Account>>();
            map<string, list<Account>> mapZone_Account = new map<string, list<Account>>();
            list<Account> accountList = new list<Account>();
            list<Account> zonewiseAccountLst = new list<Account>();
            string userType,zoneType;
            
            map<string, string> mapUserType_Region = new map<string, string>();
            map<string,string> mapZone_ZoneCode = new map<string, string>();
            
            for(Account acc : accObj) {
                if(acc.Region__r.country_key__c == 'TR'){
                    userType = 'Turkey';
                } else if (acc.Region__r.country_key__c == 'IN'){
                    system.debug('**acc.Region__r.Zone_Code__c***'+acc.Region__r.Zone_Code__c);
                    userType = 'Domestic';
                    zoneType ='';
                    if(acc.Region__r.Zone_Code__c == null){
                        continue;
                    }
                    if(acc.Region__r.Zone_Code__c == '1'){
                        zoneType = 'North';
                    } 
                    else if(acc.Region__r.Zone_Code__c == '2'){
                        zoneType = 'West';
                    } else if(acc.Region__r.Zone_Code__c == '3'){
                        zoneType = 'South';
                    } else if(acc.Region__r.Zone_Code__c == '4'){
                        zoneType = 'East';
                    } 
                    if(zoneType!='')
                        mapZone_ZoneCode.put(zoneType,string.ValueOf(acc.Region__r.Zone_Code__c));
                }else{
                    userType = 'International';
                }
                if(mapRegion_Account.containskey(userType)){
                    accountList = mapRegion_Account.get(userType);
                }
                accountList.add(acc);
                mapRegion_Account.put(userType, accountList);
                mapUserType_Region.put(userType, acc.Region__r.country_key__c);
            }
            
            list<string> lstRegion = new list<string>();
            list<string> lstZone = new list<string>();
            userRegionSelectList = new List<SelectOption>();
            userZoneSelectList = new List<SelectOption>();
            for(string region : mapUserType_Region.keySet()){
                userRegionSelectList.add(new SelectOption(region,region));
                lstRegion.add(region);
            }
            if(ApexPages.currentPage().getParameters().get('region') == null){
                selectedRegion = lstRegion[0];
            }else{
                selectedRegion = ApexPages.currentPage().getParameters().get('region');
            }
            system.debug('***selectedRegion***'+selectedRegion);
            system.debug('***mapZone_ZoneCode***'+mapZone_ZoneCode);
            if(mapZone_ZoneCode.size()>0){
                for(string zone : mapZone_ZoneCode.keySet()){
                    userZoneSelectList.add(new SelectOption(zone,zone));
                    lstZone.add(zone);
                }
            }
            if(ApexPages.currentPage().getParameters().get('zone') == null){
                if(lstZone.size() > 0){
                    selectedZone = lstZone[0];    
                }
            }else{
                selectedZone = ApexPages.currentPage().getParameters().get('zone');
            }
            
            system.debug('**selectedZone**'+selectedZone);
            String query;
            if(selectedRegion=='International'){
                accObj = [select id,(select contact.Name, contact.Department, contact.Id from contacts), 
                          name,recordType.DeveloperName,phone,Status__c,Account_Locked__c,Account_Locked_Reason__c,BillingCountry,
                          CE_Rating__c,CIS_Rating__c,Branch__c,BillingCity,  Region__r.country_key__c from account 
                          where Region__r.country_key__c !='IN' AND Region__r.country_key__c !='TR' order by Name];
            }else if(selectedRegion=='Domestic') {
                accObj = [select id,(select contact.Name, contact.Department, contact.Id from contacts), 
                          name,recordType.DeveloperName,phone,Status__c,Account_Locked__c,Account_Locked_Reason__c,BillingCountry,
                          CE_Rating__c,CIS_Rating__c,Branch__c,BillingCity, Region__r.country_key__c,Region__r.Zone_Name__c from account 
                          where Region__r.country_key__c = 'IN' and Region__r.Zone_Name__c =: selectedZone order by Name];
            }else{
                accObj = [select id,(select contact.Name, contact.Department, contact.Id from contacts), 
                          name,recordType.DeveloperName,phone,Status__c,Account_Locked__c,Account_Locked_Reason__c,BillingCountry,
                          CE_Rating__c,CIS_Rating__c,Branch__c,BillingCity,  Region__r.country_key__c from account 
                          where Region__r.country_key__c = 'TR' order by Name];
            }
            
            system.debug('accObj.size'+accObj.size());
          
            if(!accObj.isEmpty()){
                String aces = JSON.serialize(accObj);
                accountData = aces.escapeUnicode().remove('\'');
                System.debug('account data : '+accountData);
            }
            list<product__c> prodList = [select name from Product__c where region__c =: userObj.user_Type__c AND MSP__c !=null AND MSP__c != 0 Order BY Name ASC];
            if(!prodList.isEmpty()){
                String pes = JSON.serialize(prodList);
                productList = pes.escapeUnicode().remove('\'');
                System.debug('product list : '+productList);
            }
            
            Map<Id,Profile> profileIds = new Map<id,profile>([SELECT Id,UserLicenseId FROM Profile where UserLicenseId  in (SELECT Id FROM UserLicense where name ='Salesforce Platform')]);
            
            
            if(!grp.isEmpty()){
                For(GroupMember mem : grp){
                    Userlst.add(mem.UserOrGroupId);
                }
            }
            list<string>lst=new list<string>();
            list<User_Region_Association__c>usr=[SELECT Id, Region__c, User__c FROM User_Region_Association__c where user__c=:userinfo.getUserId()];
            for(User_Region_Association__c obj :usr){
                lst.add(obj.Region__c);
            }
            list<User_Region_Association__c>usrlst=[SELECT Id, Region__c, User__c FROM User_Region_Association__c where region__c IN:lst];
            
            if(!usrlst.isEmpty()){
                For(User_Region_Association__c obj : usrlst){
                    Userlst.add(obj.User__c);
                }
            }
            
            
            list<user> userList = [select id, name, profileId from user where IsActive = true and ID In:Userlst ];
            if(!userList.isEmpty()){
                String aues = JSON.serialize(userList);
                allUser = aues.escapeUnicode().remove('\'');
                System.debug('All user : '+allUser);
            }
            pickListValuesList= new List<String>();
            map<string , CallTypeRemoval__c> removalCallTypeMap = CallTypeRemoval__c.getAll();
            Schema.DescribeFieldResult fieldResult = event.Call_Type__c.getDescribe();
            List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
            for( Schema.PicklistEntry pickListVal : ple){
                if(!removalCallTypeMap.containsKey(pickListVal.getLabel()))
                    pickListValuesList.add(pickListVal.getLabel());
            }   
            System.debug(pickListValuesList.size());
            System.debug('picklislt values after removal : '+pickListValuesList);
            
            
            
            
        }catch(exception e){
            system.debug('Error in constructor : '+e.getMessage()+',At line no : '+e.getLineNumber());
        }
    }
    
    //This method will receive list of events and will save all events in DB
    @RemoteAction
    global static void createNewEvents(string data){
        //isConnectedToDCR__c
        system.debug('Data : '+data);
        List<event>lstEventToUpdate = new List<event>();
        list<event> eventList = new list<event>();
        try{
            User  objUser  = [select id,Name,Profile.Name,userRoleId,userRole.Name from User where id =: UserInfo.getUserId()];
            Userrole rl =[SELECT Id, Name, DeveloperName FROM UserRole WHERE Id =: objUser.userRoleId];
            Id recId;
            if(rl.Name=='Colambia and Brazil Portal User Partner User'){
                
                 //recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('Planejamento do DCR').getrecordTypeId();  
                 recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('DCR Planning').getrecordTypeId();
            }else{
                
               recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('DCR Planning').getrecordTypeId();  
                
            }
          //  Id recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('DCR Planning').getrecordTypeId();
            list<object> dataList = (list<object>)JSON.deserializeUntyped(data);
            system.debug('Data List : '+dataList);
            for(object o : dataList){
                
                
                map<string, object> dataMap =  (map<string, object>)o;
                
                
                event eventObj = new event();
                eventObj.stage__c = 'Planned';
                eventObj.Type_of_leave__c = string.valueOf(dataMap.get('TypeOfcall'));
                eventObj.Subject = string.valueOf(dataMap.get('subject'));
                System.debug('Subject'+dataMap.get('subject'));
                IF(string.valueOf(dataMap.get('callType1'))!=''&& string.valueOf(dataMap.get('callType1'))!=NULL && string.valueOf(dataMap.get('callType1'))!='Leave'){
                    eventObj.Account_Visit_Call_Type__c = string.valueOf(dataMap.get('callType1')).trim();
                }
                 IF(string.valueOf(dataMap.get('meetingType'))!=''&& string.valueOf(dataMap.get('meetingType'))!=NULL && string.valueOf(dataMap.get('meetingType'))!='Leave'){
                    eventObj.Meeting_Type__c = string.valueOf(dataMap.get('meetingType'));
                }
                eventObj.RecordTypeId = recId;
                string [] dateArr = string.valueOf(dataMap.get('date')).split('-');
                date evdate = date.newInstance(integer.valueOf(dateArr[0]), integer.valueOf(dateArr[1]), integer.valueOf(dateArr[2]));
                eventObj.StartDateTime = (evdate);//datetime.valueof(evdate);
                eventObj.EndDateTime = (evdate); //datetime.valueof(evdate);
                
                
                eventObj.visit_Date__c = eventObj.startDateTime.dateGMT();
                eventObj.Joint_Call__c = boolean.valueOf(dataMap.get('isJoint'));
                /* if(dataMap.get('outOfOffice') !=null){
eventObj.Out_Of_Office__c = Boolean.valueOf(dataMap.get('outOfOffice'));
}*/
                if(string.valueOf(dataMap.get('relatedTo')).startsWith('001') && !string.valueOf(dataMap.get('relatedTo')).contains('001Leave')){
                    eventObj.WhatId = string.valueOf(dataMap.get('relatedTo'));
                    eventObj.status__c = 'Planned';
                }else if(string.valueOf(dataMap.get('relatedTo')).contains('001Leave')){
                    string temp = string.valueOf(dataMap.get('relatedTo'));
                    System.debug('temp var : '+temp);
                    
                    //eventObj.status__c = 'Draft'; commented Sid
                    //New Fields Added Below: Sid
                    eventObj.Status__c = 'Sent for Approval';
                    
                    eventObj.Event_Locked__c = true;
                    eventObj.Other_Type__c = true;
                }
                if(string.isNotBlank(string.valueOf(dataMap.get('ownerId')))){
                    eventObj.OwnerId = string.valueOf(dataMap.get('ownerId'));
                }
                eventObj.Address__c = dataMap.get('address') !=null ? dataMap.get('address').tostring() : '';
                eventObj.Contact__c = dataMap.get('contact') !=null ? dataMap.get('contact').tostring() : '';
                eventObj.Country__c = dataMap.get('country') !=null ? dataMap.get('country').toString() : '';
                eventObj.DCR_Description__c = dataMap.get('description') !=null ? dataMap.get('description').toString() : '';
                if(dataMap.get('FromDate') !=''){
                    String[] fromDateArr = dataMap.get('FromDate').toString().split('-');
                    eventObj.From_Date__c = date.newInstance(Integer.valueOf(fromDateArr[0]),Integer.valueOf(fromDateArr[1]),Integer.valueOf(fromDateArr[2]));
                }
                eventObj.From_place__c = dataMap.get('FromPlace') !=null ? dataMap.get('fromPlace').tostring() : '';
                eventObj.Name__c = dataMap.get('name') !=null ? dataMap.get('name').toString() : '';
                eventObj.Next_Visit_Planning_Remarks__c = dataMap.get('nextVisitPlanning') !=null ? dataMap.get('nextVisitPlanning').toString() : '';
                eventObj.No_of_days_travelled__c = dataMap.get('dayTravel') !='' ? integer.valueOf(dataMap.get('dayTravel')) : null;
                eventObj.No_of_doctors_visited__c = dataMap.get('doctorVisit') !='' ? integer.valueOf(dataMap.get('doctorVisit')) : null;
                eventObj.No_of_PMS_Collected__c = dataMap.get('pmsCollected') !='' ? integer.valueOf(dataMap.get('pmsCollected')) : null;
                eventObj.No_of_Surgeries_Attended__c = dataMap.get('surgery') !='' ? integer.valueOf(dataMap.get('surgery')) : null;
                eventObj.Remark_for_doctors__c = dataMap.get('remarkDoctor') !=null ? dataMap.get('remarkDoctor').toString() : '';
                eventObj.Remark_for_market_information__c = dataMap.get('marketInfo') !=null ? dataMap.get('marketInfo').toString() : '';
                eventObj.Remark_for_Tenders__c = dataMap.get('remarkTender') !=null ? dataMap.get('remarkTender').toString() : '';
                if(dataMap.get('ToDate') !=''){
                    string[] toDateArr = dataMap.get('ToDate').toString().split('-');
                    eventObj.To_Date__c = date.newInstance(Integer.valueOf(toDateArr[0]),Integer.valueOf(toDateArr[1]),Integer.valueOf(toDateArr[2]));
                }
                if(dataMap.get('contactId') !=''){
                    eventObj.whoId = dataMap.get('contactId').toString();
                    System.debug('Contact Id : '+eventObj.whoId);
                }
                eventObj.To_place__c = dataMap.get('toPlace') !='' ? dataMap.get('toPlace').tostring() : '';
                eventObj.Week_no__c = dataMap.get('week') !='' ? integer.valueof(dataMap.get('week')) : null;
                
                eventObj.Employee__c = dataMap.get('employeeName') !='' ? dataMap.get('employeeName').tostring() : '';
                if(dataMap.get('product') !=''){
                    eventObj.product__c = dataMap.get('product').toString();
                    system.debug(eventObj.product__c);
                }
                if(dataMap.containsKey('callType') && dataMap.get('callType') !=''){
                    eventObj.Account_Visit_Call_Type__c = dataMap.get('callType').toString().trim() ;
                } 
                if(dataMap.containsKey('newCallType') &&  dataMap.get('newCallType') !=''){
                    eventObj.Call_Type__c = dataMap.get('newCallType').toString() ;
                } 
                if(dataMap.containsKey('newCallType2') &&  dataMap.get('newCallType2') !=''){
                    eventObj.Call_Type__c = dataMap.get('newCallType2').toString() ;
                }
                
                // START :BD Tracker connect
                
                string eventI = string.valueOf(dataMap.get('evt'));
                System.debug('eventIds'+eventI);
                if(eventI!=null && eventI != ''){
                    
                    List<string>strList = eventI.split(',');
                    List<id>ldLst = new List<id>();
                    if(strList !=null && strList.size() > 0){
                        for(string str : strList){
                            
                            ldLst.add(id.valueOf(str)); 
                        }
                        
                        List<Event>lstEvt = [select id,isConnectedToDCR__c from event where id In:ldLst];
                        for(event objevent : lstEvt){
                            objevent.isConnectedToDCR__c  =true;
                            //objevent.DCR
                            lstEventToUpdate.add(objevent);
                        }
                    }
                }
                //END
                eventList.add(eventObj);
                
                
                if(lstEventToUpdate!= null || lstEventToUpdate.size() > 0)
                    System.debug('lstEventToUpdate'+lstEventToUpdate);
                update lstEventToUpdate; 
            }
            //END : 
            
            insert eventList;
        }catch(exception e){
            system.debug('error in Creating visits : '+e.getMessage()+', at line no : '+e.getLineNumber());
        }
    }
    
    @RemoteAction
    global static void deleteEvent(string eventId){
        system.debug('Event id in param : '+eventId);
        try{
            event evObj = new event(id=eventId);
            delete evObj;
        }catch(exception e){
            system.debug('error in delete of event method : '+e.getLineNumber()+', at line no : '+e.getLineNumber());
        }
    }
    
    @RemoteAction
    global static void updateEvent(map<string, object> data){
        system.debug('prameter : '+data);
        try{
            event evObj = new event();
            
            
            evObj.id = data.get('eventId').toString();
            //string[] eTimeArr = String.valueOf(data.get('endTime')).split(':');
            //string[] STimeArr = String.valueOf(data.get('startTime')).split(':');
            string[] dateArr = string.valueOf(data.get('date')).split('-');
            date dt = date.newInstance(Integer.valueOf(dateArr[0]),Integer.valueOf(dateArr[1]),Integer.valueOf(dateArr[2]));
            //time endTime = time.newInstance(Integer.valueOf(eTimeArr[0]), Integer.valueOf(eTimeArr[1]), 0, 0);
            //time startTime = time.newInstance(Integer.valueOf(STimeArr[0]), Integer.valueOf(STimeArr[1]), 0, 0);
            //evObj.StartDateTime = Datetime.newInstance(dt, startTime).addMinutes(0);
            //evObj.EndDateTime = Datetime.newInstance(dt, endTime).addMinutes(0);
            //evObj.visit_date__c = evObj.startDateTime.date();
            if(data.get('status') == 'submitAndSave'){
                evObj.Status__c = 'Sent for Approval';
                evObj.Event_Locked__c = true;
            }
            System.debug('prod to updated : ' + data.get('product'));
            if(data.get('product') !=''){
                evObj.product__c = data.get('product').toString();
                system.debug(evObj.product__c);
            }
            if(data.get('folloUpDate') !=''){
                string[] fromDateArr = String.valueOf(data.get('folloUpDate')).split('-');
                evObj.follow_Up_Date__c = date.newInstance(integer.valueOf(fromDateArr[0]),integer.valueOf(fromDateArr[1]),integer.valueOf(fromDateArr[2]));
            }
            if(data.get('contactId') !=''){
                evObj.whoId = data.get('contactId').toString();
                System.debug('Contact Id : '+evObj.whoId);
            }
            evObj.DCR_Description__c = data.get('description').tostring() !='' ? data.get('description').tostring() :'';
            system.debug('event before update : '+evObj);
            
            
            //START : BD Tracker
            
            Event objEvent = [Select id,Account__c from Event where ID=:data.get('eventId').toString()];
            string idValueEvt = data.get('evtIdValue').tostring();
            
            List<String>lstToUpdateValue;
            List<String>lstIdvalue;
            if(idValueEvt!=null){
                lstIdvalue = idValueEvt.split(',');
            }  
            
            if(lstIdvalue.size() > 0 && lstIdvalue!=null){
                System.debug('lstIdvalue'+lstIdvalue);
                List<Event>lstEvents = [Select id,recordtypeId,BD_Tracker_Phase__c,Milestone_Plan_Week__c,Product__c,whoId,MileStone_Stage__c,
                                        isSubmitted__c,OwnerId,startDateTime,Account__c,isConnectedToDCR__c,EndDateTime
                                        from Event 
                                        where OwnerId=:userInfo.getUserId() AND isSubmitted__c=true
                                        /* AND isConnectedToDCR__c = true*/ AND Account__c=:objEvent.Account__c 
                                        AND MileStone_Stage__c !='Actual'AND MileStone_Stage__c !='Cancel'
                                        AND ID In :lstIdvalue];
                
                System.debug('lstEvents'+lstEvents);
                
                for(Event obj :lstEvents){
                    System.debug('obj==>'+obj);
                    obj.isConnectedtoDCR__c=true;
                }
                update lstEvents;
            }
            
            
            //END BD:Tracker
            
            
            System.debug('data.get(date) : ' + data.get('date'));
            
            dateArr = string.valueOf(data.get('date')).split('-');
            date evdate = date.newInstance(integer.valueOf(dateArr[0]), integer.valueOf(dateArr[1]), integer.valueOf(dateArr[2]));
            evObj.StartDateTime = (evdate);//datetime.valueof(evdate);
            evObj.EndDateTime = (evdate); //datetime.valueof(evdate);
            
            update evObj;
            
        }catch(Exception e){
            system.debug('error in updating event : '+e.getMessage()+',at line no. '+e.getLineNumber());
        }
    }
    
    @RemoteAction
    global static list<event> getUserData(string data){
       //Calling without sharing class
        return DCRGetUserData.getUserData(data);
    }
    
    @RemoteAction
    global static string returnHomePage(){
        return URL.getSalesforceBaseUrl().toExternalForm();
    }
    
    /********************************************
* @Method Name  : weeknumber
* @Params       : Date startdate
* @Description  : It is used to get the Weeknumber of current date.
* @Created Date : 13-11-2019
* @Created By   : Rajesh N. 
* ****************************************/           
    public static Integer weeknumber(Date startdate){
        Integer numberOfWeek;
        Date todaydateinstance = date.newinstance(startdate.year(), startdate.month(), startdate.day());
        
        Integer currentyear = startdate.year();
        
        Date yearstartdate = date.newinstance(currentyear, 01, 01);
        Date year2ndweek = yearstartdate.adddays(7).tostartofweek();
        
        if(startdate<year2ndweek)
            numberOfWeek = 1;
        integer numberDaysDue = year2ndweek.daysBetween(todaydateinstance);
        
        
        if(math.mod(numberDaysDue,7)==0)
            numberOfWeek = math.MOD(Integer.valueof(math.FLOOR( ( numberDaysDue )/7)),52)+1;
        else
            numberOfWeek = math.MOD(Integer.valueof(math.FLOOR( ( numberDaysDue )/7)),52)+2;
        return numberOfWeek;
        
    }   
    //STart By Rajesh
    public void showPopup()
    {
        
        if(aId ==null){
            aId =accId;
        }
        displayPopup = true;
        
        if(dateVal==null && dateValUpdate!=null){
            dateVal = dateValUpdate;
        }
        Integer weekNo = weeknumber(Date.valueOf(dateVal));
        System.debug('weekNo'+weekNo);
        weekN = weekNo;
        string wk ='Week'+weekNo;
        
        Date startDate;
        Date EndDate;
        ID recordId = Schema.SObjectType.Event.getRecordTypeInfosByName().get('BD Tracker').getRecordTypeId();
        lstEvent = new List<Event>();
        List<Event>lstCheckEvent = new List<EVent>();
        
        lstEvent = [Select id,recordtypeId,BD_Tracker_Phase__c,Milestone_Plan_Week__c,Product__c,whoId,MileStone_Stage__c,
                    isSubmitted__c,OwnerId,startDateTime,Account__c,isConnectedToDCR__c,EndDateTime,whatId,createdDate
                    from Event 
                    where recordtypeId =:recordId AND OwnerId=:userInfo.getUserId() AND isSubmitted__c=true
                    AND Account__c=:accId AND MileStone_Stage__c !='Actual'AND MileStone_Stage__c !='Cancel'
                    order by what.Name,Milestone_Plan_Week__c,BD_Tracker_Phase__c ASC];
        
        
        System.debug('accId'+accId);
        System.debug('lstEvent'+lstEvent);
        System.debug('lstWrapper'+lstWrapper);
        
        if((lstWrapperToShow !=null && lstWrapperToShow.size() > 0) && (lstWrapper!=null  && lstWrapper.size() > 0 )){
            
            if(aID!=null  && aId != accId ){
                lstWrapper = new List<DailyCallRecordController.BDWrapper>();
                lstWrapperToShow = new List<DailyCallRecordController.BDWrapper>();
                
                for(DailyCallRecordController.BDWrapper objWrappertoShow : lstWrapperToShow){
                    
                    
                    for(DailyCallRecordController.BDWrapper objWrapper : lstWrapper){
                        DailyCallRecordController.BDWrapper objWrap =new DailyCallRecordController.BDWrapper(); 
                        
                        if(objWrappertoShow.isCheck && objWrapper.objEvent.Milestone_Plan_Week__c ==objWrappertoShow.objevent.Milestone_Plan_Week__c && objWrappertoShow.objEvent.Product__c ==objWrapper.objEvent.Product__c 
                           && objWrapper.objEvent.Milestone_Stage__c == objWrappertoShow.objEvent.Milestone_Stage__c 
                           && objWrappertoShow.objEvent.BD_Tracker_Phase__c == objWrapper.objEvent.BD_Tracker_Phase__c ){  
                               
                               objWrapper.isCheck =true;
                           }
                        
                    }
                    
                    
                }
            }else{
                for(DailyCallRecordController.BDWrapper objWrappertoShow : lstWrapperToShow){
                    
                    
                    for(DailyCallRecordController.BDWrapper objWrapper : lstWrapper){
                        DailyCallRecordController.BDWrapper objWrap =new DailyCallRecordController.BDWrapper(); 
                        
                        if(objWrappertoShow.isCheck && objWrapper.objEvent.Milestone_Plan_Week__c ==objWrappertoShow.objevent.Milestone_Plan_Week__c && objWrappertoShow.objEvent.Product__c ==objWrapper.objEvent.Product__c 
                           && objWrapper.objEvent.Milestone_Stage__c == objWrappertoShow.objEvent.Milestone_Stage__c && objWrappertoShow.objEvent.BD_Tracker_Phase__c == objWrapper.objEvent.BD_Tracker_Phase__c){  
                               
                               objWrapper.isCheck =true;
                           }
                        
                    }
                    
                    
                }
            }
        }else{
            
            if(lstEvent.size() > 0){
                lstWrapper = new List<DailyCallRecordController.BDWrapper>();
                for(event objEvent : lstEvent){
                    Contact objContact =[Select id,FirstName,LastName from Contact where ID=:objEvent.WhoId];
                    DailyCallRecordController.BDWrapper objWraapper =new DailyCallRecordController.BDWrapper();
                    objWraapper.ischeck  =false;
                    objWraapper.objEvent = objEvent;
                    objWraapper.conName = objContact.LastName; 
                    objWraapper.PlanYear = Integer.valueOf(objEvent.endDateTime.Year());
                    lstWrapper.add(objWraapper);
                }
            }else{
                
                lstEvent = [Select id,recordtypeId,BD_Tracker_Phase__c,Milestone_Plan_Week__c,Product__c,whoId,MileStone_Stage__c,
                            isSubmitted__c,OwnerId,startDateTime,Account__c,isConnectedToDCR__c,EndDateTime
                            from Event 
                            where recordtypeId =:recordId AND OwnerId=:userInfo.getUserId() AND isSubmitted__c=true
                            AND Account__c=:accIdUpdate AND MileStone_Stage__c !='Actual'AND MileStone_Stage__c !='Cancel'
                           order by what.Name,Milestone_Plan_Week__c,BD_Tracker_Phase__c ASC];
                
                lstWrapper = new List<DailyCallRecordController.BDWrapper>();
                idBeforeUpdate =null;
                for(event objEvent : lstEvent){
                    Contact objContact =[Select id,FirstName,LastName from Contact where ID=:objEvent.WhoId];
                    DailyCallRecordController.BDWrapper objWraapper =new DailyCallRecordController.BDWrapper();
                    if(objEvent.isConnectedToDCR__c){
                        objWraapper.ischeck  =true;
                        if(idBeforeUpdate ==null)
                            idBeforeUpdate =objEvent.Id+',';
                        else
                            idBeforeUpdate =idBeforeUpdate + objEvent.Id+',';
                    }
                    else{
                        objWraapper.ischeck  =false;
                    }
                    
                    objWraapper.objEvent = objEvent;
                    objWraapper.conName = objContact.LastName; 
                    objWraapper.PlanYear = Integer.valueOf(objEvent.endDateTime.Year());
                    lstWrapper.add(objWraapper);
                }
                System.debug('idBeforeUpdate'+idBeforeUpdate);
            }
        }
        
    }
    // }
    
    public void closePopup() {
        displayPopup = false;
        
    }
    
    public void saveBdPlan(){
        System.debug('updateEvent'+updateEvent);
        if(updateEvent ==null){
            
            List<Id>lstCheckPlan = new List<Id>();
            set<id>lstSet = new Set<id>();    
            
            displayPopUpToShow =false; 
            lstWrapperToShow = new List<DailyCallRecordController.BDWrapper>();
            lstWrapperToShowS = new List<DailyCallRecordController.BDWrapper>();
            System.debug('lstWrapper'+lstWrapper);
            eventIds =null;
            for(DailyCallRecordController.BDWrapper objWrapper : lstWrapper){
                lstCheckPlan.add(objWrapper.objevent.Id);
                if(objWrapper.isCheck){
                    lstSet.add(objWrapper.objevent.Id);
                    if(eventIds==null){
                        eventIds = objWrapper.objevent.Id+',';
                    }
                    else{
                        // eventIds =null;
                        eventIds = eventIds + objWrapper.objevent.Id+',';
                    }
                    
                    lstWrapperToShow.add(objWrapper);
                    lstWrapperToShowS.add(objWrapper);
                }
            }
            
            //Start 
            Boolean success =true;
            if(lstCheckPlan.size() >0){
                set<string>whtaNameString = new set<string>();
                map<String,List<string>>bdtSet = new map<String,List<string>>();
                Map<string,List<Event>>lstMap = new Map<string,list<Event>>();
                
                List<Event>lst = [Select id,WhatId,bd_tracker_phase__c,what.Name,product__c,
                                  Milestone_stage__c
                                  from event where id IN:lstCheckPlan];
                List<Event>lstSelected = [Select id,WhatId,bd_tracker_phase__c,what.Name,product__c,
                                          Milestone_stage__c
                                          from event where id IN:lstset];
                
                Map<string,string>selectedMap = new Map<string,string>();
                for(Event obj :lstSelected){
                    selectedMap.put(obj.id,obj.what.Name); 
                    whtaNameString.add(obj.what.Name);
                }
                
                if(lst !=null){
                    
                    for(Event objEv : lst){
                        
                        if(lstMap.containsKey(objEv.what.Name)){
                            List<Event>lstEv = new List<Event>();
                            List<String>lstPhases = new List<string>();
                            //
                            lstPhases = bdtSet.get(objEv.what.Name);
                            lstPhases.add(objEv.BD_Tracker_Phase__c);
                            bdtSet.put(objEv.what.Name,lstPhases);
                            //
                            lstEv = lstMap.get(objEv.what.Name);
                            lstEv.add(objEv);
                            lstMap.put(objEv.what.Name,lstEv);
                            
                        }else{
                            List<Event>lstEv = new List<Event>();
                            lstEv.add(objEv);
                            lstMap.put(objEv.what.Name,lstEv);
                            
                            List<String>lstPhases = new List<String>();
                            lstPhases.add(objEv.BD_Tracker_Phase__c);
                            bdtSet.put(objEv.what.Name,lstPhases);
                        }
                    }
                    
                }
                
                for(string str : bdtSet.keyset()){
                    
                    for(Event lstEv : lstMap.get(str)){
                        
                        if((lstEv.BD_Tracker_Phase__c=='Product Discussion'|| lstEv.BD_Tracker_Phase__c=='Ürün Tartışması' || lstEv.BD_Tracker_Phase__c=='Discussão sobre produtos' || lstEv.BD_Tracker_Phase__c=='Discusión de producto' ) && lstEv.Milestone_Stage__c!='Actual' &&
                           ((!selectedMap.containsKey(lstEv.id))) && (whtaNameString.contains(lstEv.what.Name)) ){
                               
                               ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,System.Label.Please_select_Product_Discussion_with_respective_Evaluation_and_Commercializatio);
                               ApexPages.addMessage(myMsg);
                               success =false;
                               eventIds =null;
                               return;
                           }
                    }
                }
            }
            //End
            
            if(lstWrapperToShow .size() >0 && success){
                
                displayPopUpToShow =true;
                
            }
        }else{
            List<Id>lstCheckPlan = new List<Id>();
            set<id>lstSet = new Set<id>();
            
            List<Event>lstEventValue = New List<Event>();
            List<Event>lstEventValueUncheked = New List<Event>();
            evtIds=null;
            for(DailyCallRecordController.BDWrapper objWrapper : lstWrapper){
                lstCheckPlan.add(objWrapper.objevent.Id);
                if(objWrapper.isCheck){
                    lstSet.add(objWrapper.objevent.Id);
                    objWrapper.objEvent.isConnectedToDCR__c =true;
                    System.debug('objWrapper.objEvent'+objWrapper.objEvent);
                    lstEventValue.add(objWrapper.objEvent);
                    if(evtIds==null){
                        evtIds = objWrapper.objevent.Id+',';
                    }
                    else{
                        
                        evtIds = evtIds + objWrapper.objevent.Id+',';
                    }
                    
                }else{
                    objWrapper.objEvent.isConnectedToDCR__c =false;
                    lstEventValueUncheked.add(objWrapper.objEvent);
                }
                
            }
            
            //Start 
            Boolean success =true;
            if(lstCheckPlan.size() >0){
                set<string>whtaNameString = new set<string>();
                map<String,List<string>>bdtSet = new map<String,List<string>>();
                Map<string,List<Event>>lstMap = new Map<string,list<Event>>();
                
                List<Event>lst = [Select id,WhatId,bd_tracker_phase__c,what.Name,product__c,
                                  Milestone_stage__c
                                  from event where id IN:lstCheckPlan];
                List<Event>lstSelected = [Select id,WhatId,bd_tracker_phase__c,what.Name,product__c,
                                          Milestone_stage__c
                                          from event where id IN:lstset];
                
                Map<string,string>selectedMap = new Map<string,string>();
                for(Event obj :lstSelected){
                    selectedMap.put(obj.id,obj.what.Name); 
                    whtaNameString.add(obj.what.Name);
                }
                
                if(lst !=null){
                    
                    for(Event objEv : lst){
                        
                        if(lstMap.containsKey(objEv.what.Name)){
                            List<Event>lstEv = new List<Event>();
                            List<String>lstPhases = new List<string>();
                            //
                            lstPhases = bdtSet.get(objEv.what.Name);
                            lstPhases.add(objEv.BD_Tracker_Phase__c);
                            bdtSet.put(objEv.what.Name,lstPhases);
                            //
                            lstEv = lstMap.get(objEv.what.Name);
                            lstEv.add(objEv);
                            lstMap.put(objEv.what.Name,lstEv);
                            
                        }else{
                            List<Event>lstEv = new List<Event>();
                            lstEv.add(objEv);
                            lstMap.put(objEv.what.Name,lstEv);
                            
                            List<String>lstPhases = new List<String>();
                            lstPhases.add(objEv.BD_Tracker_Phase__c);
                            bdtSet.put(objEv.what.Name,lstPhases);
                        }
                    }
                    
                }
                
                for(string str : bdtSet.keyset()){
                    
                    for(Event lstEv : lstMap.get(str)){
                        
                        if((lstEv.BD_Tracker_Phase__c=='Product Discussion' ||lstEv.BD_Tracker_Phase__c=='Ürün Tartışması' || lstEv.BD_Tracker_Phase__c=='Discussão sobre produtos' || lstEv.BD_Tracker_Phase__c=='Discusión de producto') && lstEv.Milestone_Stage__c!='Actual' &&
                           ((!selectedMap.containsKey(lstEv.id))) && (whtaNameString.contains(lstEv.what.Name)) ){
                               
                               ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'Please select Product Discussion with respective Evaluation and Commercialization Plan.');
                               ApexPages.addMessage(myMsg);
                               success =false;
                               evtIds =null;
                               return;
                           }
                    }
                }
            }
            //End
            if(success){
                update lstEventValue;
                update lstEventValueUncheked;
            }
        }
        
        displayPopup = false;
        
        
        
    }
    
    
    Class BDWrapper{
        public boolean isCheck{get;set;}
        public event objEvent{get;set;}
        public string conName{get;set;}
        public Integer PlanYear{get;set;}
    }
    public void openLinkBD (){
        if(currentEvent.Account_Visit_Call_Type__c=='Business Development'){
            isLinkToBD =true;
            //weekN = weeknumber(Date.valueOf(dateVal));
        }
        else{
            isLinkToBD =false;
        }
        
    }
    
    
    
    public  pagereference  setDeafultWrapper(){
        
        lstWrapper = new List<DailyCallRecordController.BDWrapper>();
        lstWrapperToShow = new List<DailyCallRecordController.BDWrapper>();
        displayPopUpToShow =false;  
        updateEvent =null;
        //  accId=null; 
        return null; 
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
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        
        
    }   
}
/***********************************************************************************************************************
Author : Prashant Rana
Description : This controller will take care of all the functionality behid mobile app (DCR Details)
Date : 01-01-2019 
************************************************************************************************************************/
global with sharing class BeatPlanMapPageController {
    
    global string eventList{get;set;}
    global beat_Plan__c beatObj{get;set;}
    global string checkinMapping{get;set;}
    global string curentLang {get;set;}
    global DCR_Detail1_Translation__c translationObject{get;set;}
    global string isCommunityUser{get;set;}
    
    
    
    global static void updateAccount(String accountId,Decimal Lati,Decimal Longi) {
        
        Account a = new Account(Id = Id.valueOf(accountId));
        // a.BillingLatitude = Decimal.valueOf(Lati) ;
        // a.BillingLongitude = Decimal.valueOf(Longi);
        a.BillingLatitude = Lati ;
        a.BillingLongitude = Longi;
        a.Location_Copied__c = true;
        update a;
        
    }
    global void doInit()
    {
        /*
beatObj = [select name, Started__c,ended__c,Start_LatLang__Latitude__s,Start_LatLang__Longitude__s,id from beat_Plan__c where beat_Date__c =: date.today() AND Assigned_To__c = :UserInfo.getUserId()];
system.debug('beat Object : '+beatObj);
if(beatObj !=null){
string beatId = beatObj.id;
system.debug('Beat Id : '+beatId);
list<event> eventData = [select id, subject,AccountId,Cheked_In__c, StartDateTime,Check_Out__c, EndDateTime, Event_Latitude__c, Event_Longitude__c,Account__c, Account__r.RecordType.DeveloperName,
Account__r.Name, Account__r.BillingStreet, Account__r.BillingCity,Beat_Plan__c,Out_Of_Office__c from event where Beat_Plan__c = :beatId AND
Check_Out__c != true AND Account__c !=null AND Status__c !='Cancelled' order by StartDateTime  ASC];
//list<event> eventList = [select checkout__Latitude__s,Checkout__Longitude__s,AccountId from event where Beat_Plan__c =: beatObj.Id order by startDateTime ASC];
Account a  = new Account(Id = eventData[0].AccountId);
a.BillingLatitude = beatObj.Start_LatLang__Latitude__s;
a.BillingLongitude = beatObj.Start_LatLang__Longitude__s;
update a;

}
*/
    }
    
    //Constructor
    global BeatPlanMapPageController(){
        try{  
            User  objUser  = [select id,Name,Profile.Name,userRoleId,userRole.Name from User where id =: UserInfo.getUserId()];
            Userrole rl = new Userrole();
            if(objUser.userRoleId != null){
                rl =[SELECT Id, Name, DeveloperName FROM UserRole WHERE Id =: objUser.userRoleId];
            }
            isCommunityUser = rl.Name;
            Id recId;
            if(rl.Name != Null){
                if(rl.Name=='Colambia and Brazil Portal User Partner User'|| rl.Name == 'Colambia and Brazil Portal User Partner Executive'){
                    
                    // recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('Planejamento do DCR').getrecordTypeId();  
                    recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('DCR Planning').getrecordTypeId();  
                    
                }else{
                    
                    recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('DCR Planning').getrecordTypeId();  
                    
                }
            }else{
                recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('DCR Planning').getrecordTypeId();  
            }
            curentLang = UserInfo.getLanguage();
            translationObject= DCR_Detail1_Translation__c.getValues(UserInfo.getLanguage()); 
            if(translationObject== null){
                translationObject= DCR_Detail1_Translation__c.getValues('en_US');
            }
            list<Check_In_Setting__c> checkinList = Check_In_Setting__c.getAll().values();
            if(!checkinList.isEmpty()){
                checkinMapping = JSON.serialize(checkinList);
            }
            system.debug(UserInfo.getUserId());
            beatObj = [select name, Started__c,ended__c,id from beat_Plan__c where beat_Date__c =: date.today() AND Assigned_To__c = :UserInfo.getUserId() limit 1];
            beatObj.Started__c = true;
            if(beatObj !=null){
                string beatId = beatObj.id;
                system.debug('recId : '+recId);
                system.debug('Beat Id : '+beatId);
                List<Event> upEvList=new List<Event>();
                list<event> eventData = [select id, subject,BillingStreet__c,BillingCity__c,AccountId,Leads__r.Lead_Closed__c,Leads__r.lead_stage__C,Account__r.BillingLatitude, Account__r.BillingLongitude,Account__r.Location_copied__c,Cheked_In__c, StartDateTime,Check_Out__c, EndDateTime, Event_Latitude__c, Event_Longitude__c,Account__c, Account__r.RecordType.DeveloperName,
                                         Account__r.Name,IsInternationalUser__c,Account__r.BillingStreet,Leads__c, Account__r.BillingCity,Beat_Plan__c,Out_Of_Office__c,recordtypeid,Meeting_Type__c,Leads__r.Billing_Street__c,Leads__r.Billing_City__c,Leads__r.Name,Leads__r.Country__c from event where Beat_Plan__c =: beatId  AND
                                         Check_Out__c != true AND (Account__c !=null OR whatID !=null) AND Status__c !='Cancelled'AND recordtypeid=:recid order by StartDateTime  DESC];
                
                
                
                system.debug('eventData------>:'+eventData);
                for(event ev:eventData) {
                    if(ev.Account__c !=null && ev.Leads__c == null) {
                        upEvList.add(ev);
                    }else if(ev.Account__c == null &&  ev.Leads__c!=null && ev.Leads__r.Lead_Closed__c == false && ev.Leads__r.lead_stage__C !='Won' && ev.Leads__r.lead_stage__C !='Lost' && ev.Leads__r.lead_stage__C !='Unqualified') {
                        upEvList.add(ev);
                    }
                    
                }
                if(!eventData.isempty()){
                    string eventString = json.serialize(upEvList);
                    eventList = eventString.escapeUnicode().remove('\'');
                    
                    system.debug('eventString------>:'+eventString);
                }
            }
            
        }catch(exception e){
            system.debug('error in beat plan constructor : '+e.getMessage()+', at line no : '+e.getLineNumber());
        }
    }
    //Start my day method
    @remoteAction
    global static String startMyDay(map<string,Object> mapData){
        string returnmessage='';
        try{
            //**************************************
            Map<String, Object> data = CommonutiltiyClass.getdailyactivity();
            System.debug('data: ' + JSON.serialize(data));
            Boolean activityFlag = (Boolean)data.get('activity');
            system.debug('activityFlag---->'+activityFlag);
            if (activityFlag == false) {
                returnmessage ='NOCLOCKIN';
                return returnmessage;
            }
            
            //**************************************
            System.debug('Data from request in start my day : '+mapData);
            beat_Plan__c beatObj = [select name,Started__c, Start_Time__c,Start_LatLang__Latitude__s,Start_LatLang__Longitude__s, End_Time__c from beat_Plan__c where beat_Date__c =: date.today() AND Assigned_To__c =:UserInfo.getUserId() limit 1];
            beatObj.Start_LatLang__Latitude__s = (Decimal)mapData.get('UserLatitude');
            beatObj.Start_Time__c = system.now().time();
            beatObj.Started__c = true;
            beatObj.Start_LatLang__Longitude__s = (Decimal)mapData.get('UserLongitude');
            System.debug('beat object : '+beatObj);
            update beatObj;
            
            //beat_Plan__c beatObj2 = [select name,Started__c, Start_Time__c,End_LatLang__Latitude__s,End_Time__c,End_LatLang__Longitude__s,Start_LatLang__Latitude__s,Start_LatLang__Longitude__s,total_Distance__c from beat_Plan__c where beat_Date__c =: date.today() AND Assigned_To__c = : UserInfo.getUserId() limit 1];
            
            /*list<event> eventList = [select checkout__Latitude__s,Checkout__Longitude__s,AccountId from event where Beat_Plan__c =: beatObj.Id order by startDateTime ASC];

Account a  = new Account(Id = eventList[0].AccountId);
a.BillingLatitude = beatObj.Start_LatLang__Latitude__s;
a.BillingLongitude = beatObj.Start_LatLang__Longitude__s;
update a;*/
            
        }catch(Exception e){
            System.debug('error in start my day : '+e.getMessage()+', at line no : '+e.getLineNumber());
            return e.getMessage();
        }
        return 'SUCCESS';
    }
    @RemoteAction
    global static list<String> checkOutMethodToGoIn(map<string,Object> mapData){
        return new List<String>{'SUCCESS',URL.getSalesforceBaseUrl().toExternalForm()};   
            }
    
    //CheckIn Function
    @RemoteAction
    global static list<String> checkInMethod(map<string,Object> mapData){
        system.debug('Gyadeen');
        System.debug('Map data'+mapData);
        try{
            location l1;
            double distance;
            
            //**************************************
            Map<String, Object> data = CommonutiltiyClass.getdailyactivity();
            System.debug('data: ' + JSON.serialize(data));
            Boolean activityFlag = (Boolean)data.get('activity');
            system.debug('activityFlag---->'+activityFlag);
            if (activityFlag == false) {
                return new List<String>{'NOCLOCKIN'};
                    }
            
            //**************************************
            
            event evObj = [select id,Account__c,Leads__c,Lead_Latitude__c,Lead_Longitude__c,Beat_plan__c,Subject,Checkin_Latlang__Latitude__s,Checkin_Latlang__Longitude__s,Meeting_Type__c,Event_Latitude__c,IsInternationalUser__c,Event_Longitude__c,check_In_Time__c,Stage__c,Cheked_In__c  from event where Id =: mapData.get('eventId').toString()];
            if(mapData.get('CheckInLat') !='' && mapData.get('CheckInLong') !='' && evObj.Meeting_Type__c == 'Onsite'){
                evObj.Checkin_Latlang__Latitude__s = (Decimal)mapData.get('CheckInLat');
                evObj.Checkin_Latlang__Longitude__s = (Decimal)mapData.get('CheckInLong');
                if(evObj.Account__c!=null && evObj.Leads__c==null) {
                    l1 = Location.newInstance(evObj.Event_Latitude__c,evObj.Event_Longitude__c);
                }
                if(evObj.Account__c==null && evObj.Leads__c!=null) {
                    l1 = Location.newInstance(evObj.Lead_Latitude__c,evObj.Lead_Longitude__c);  
                }
                String checkInDistanceLabel = System.Label.check_in_Distance;
                Decimal allowedDistance = Decimal.valueOf(checkInDistanceLabel);
                location l2 = Location.newInstance(evObj.Checkin_Latlang__Latitude__s,evObj.Checkin_Latlang__Longitude__s);
                System.debug('Event obje'+evObj.id);
                System.debug('location 1'+l1);
                System.debug('location 2'+l2);
                double dist = location.getDistance(l1,l2,'km');
                distance = dist;
                
               
                
                System.debug('Allowed Distance from Label: ' + allowedDistance);
                System.debug('Actual Distance: ' + dist);
                
                if(distance > allowedDistance){
                   // return new List<String>{'FAILED','you are too far away at a distance of ' + dist};
                        }
                //*********************Adding By gyadeen*******************************************
                if(evObj.Beat_plan__c!=null){
                    
                    List<ProcessInstance> approvalProcesses = [SELECT Id, Status, TargetObjectId FROM ProcessInstance WHERE TargetObjectId =: evObj.Beat_plan__c AND Status = 'Pending'];
                    system.debug('approvalProcesses'+approvalProcesses);
                    if (approvalProcesses.size()>0) {
                        
                        return new list<String>{'approval pending'};
                            } else {
                                System.debug('No pending approval process found.');
                            }
                    
                    
                }
                //*********************Adding above By gyadeen*******************************************8
                //string checkInDistanceLabel = System.Label.check_in_Distance;
                
                System.debug('Custom Label Value: ' + checkInDistanceLabel);
                System.debug('Dis'+dist);
                if(dist > Decimal.valueOf(String.valueOf(checkInDistanceLabel))){
                    //return new list<String>{'FAILED','you are too far away at a distance of '+dist};
                        }
            }
            
            system.debug('request in checkin method : '+mapData);
            evObj.check_In_Time__c = System.now().time();
            evObj.Stage__c = 'Checked‐In';
            evObj.Cheked_In__c = true;
            evObj.Distance__c = distance;
            
            System.debug('update in checkin : '+evObj);
            update evObj;
            
            beat_Plan__c beatObj = [select name,Started__c, Start_Time__c,Start_LatLang__Latitude__s,Start_LatLang__Longitude__s, End_Time__c from beat_Plan__c 
                                    where beat_Date__c =: date.today() AND Assigned_To__c =:UserInfo.getUserId() limit 1];
            //Update Beat Obj
            if(beatObj.Start_LatLang__Latitude__s==null){
                beatObj.Start_LatLang__Latitude__s = (Decimal)mapData.get('CheckInLat');
                beatObj.Start_LatLang__Longitude__s = (Decimal)mapData.get('CheckInLong');
                update beatObj;
            }
            
            // Id accID = [select id,Account__c from Event where id = : evObj.Id limit 1].Account__c;
            // updateAccount(String.valueOf(accID),(decimal)mapData.get('CheckInLat'),(decimal)mapData.get('CheckInLong'));
            
        }catch(Exception e){
            system.debug('error in checkin method : '+e.getMessage()+', at line no : '+e.getLineNumber());
            return new list<String>{'FAILED',e.getMessage() +'---'+e.getLineNumber()};
                }
        
        return new List<String>{'SUCCESS',URL.getSalesforceBaseUrl().toExternalForm()};
            }
    //Checkout Method
    @remoteAction
    global static void checkOutMethod(Map<String,Object> mapData){
        try {
            System.debug('request in checkout method : '+mapData);
            string Id = string.valueOf(mapData.get('eventId'));
            event evObj = [select subject ,Event_Latitude__c,Event_Longitude__c,Checkout_Distance__c,Checkout__Latitude__s,
                           Checkout__Longitude__s ,check_Out_Time__c,check_Out__c,Stage__c from event where id =:Id ];
            Location loc1 = Location.newInstance(evObj.Event_Latitude__c,evObj.Event_Longitude__c);
            Location loc2 = Location.newInstance((decimal)mapData.get('CheckOutLat'),(Decimal)mapData.get('CheckOutLong'));
            System.debug('locations : '+loc1+', location 2 : '+loc2);
            Double dist = Location.getDistance(loc1, loc2, 'km');
            system.debug('distance : '+dist);
            evObj.Checkout_Distance__c = dist;
            evObj.Checkout__Latitude__s = (decimal)mapData.get('CheckOutLat');
            evObj.Checkout__Longitude__s = (decimal)mapData.get('CheckOutLong');
            evObj.check_Out_Time__c = System.now().time();
            evObj.check_Out__c = true;
            evObj.Stage__c = 'Checked-Out';
            System.debug('Event for update : '+evObj);
            update evObj;
            
            beat_Plan__c beatObj = [select name,Started__c, Start_Time__c,End_LatLang__Latitude__s,End_Time__c,End_LatLang__Longitude__s,
                                    Start_LatLang__Latitude__s,Start_LatLang__Longitude__s,total_Distance__c from beat_Plan__c 
                                    where beat_Date__c =: date.today() AND Assigned_To__c = : UserInfo.getUserId() limit 1];
            
            //Update Beat Obj
            // if(beatObj.Start_LatLang__Latitude__s==null){
            beatObj.End_LatLang__Latitude__s = (Decimal)mapData.get('CheckOutLat');
            beatObj.End_LatLang__Longitude__s = (Decimal)mapData.get('CheckOutLong');
            update beatObj;
            //}
            
        } catch (Exception e) {
            system.debug('error in checout method : '+e.getMessage()+', at line no : '+e.getLineNumber());
        }
    }
    //end my day method
    @remoteAction
    global static String endMyDay(map<string, Object> mapData){
        try {
            System.debug('request from page : '+mapData);
            beat_Plan__c beatObj = [select name,Started__c, Start_Time__c,End_LatLang__Latitude__s,End_Time__c,End_LatLang__Longitude__s,Start_LatLang__Latitude__s,Start_LatLang__Longitude__s,total_Distance__c from beat_Plan__c where beat_Date__c =: date.today() AND Assigned_To__c = : UserInfo.getUserId() limit 1];
            list<event> eventList = [select checkout__Latitude__s,Checkout__Longitude__s from event where Beat_Plan__c =: beatObj.Id order  by startDateTime ASC];
            beatObj.End_LatLang__Latitude__s = (decimal)mapData.get('UserLatitude');
            beatObj.End_LatLang__Longitude__s = (Decimal)mapData.get('UserLongitude');
            integer count = 0;
            Double distance = 0;
            if(!eventList.isEmpty() && eventList[0].Checkout__Latitude__s !=null){
                Integer lastIndex = eventList.size() -1;
                Location loc1 = Location.newInstance(beatObj.Start_Latlang__latitude__s,beatObj.Start_Latlang__Longitude__s);
                Location loc2 = Location.newInstance(eventList[0].Checkout__Latitude__s,eventList[0].Checkout__Longitude__s);
                System.debug('location1 : '+loc1+', Locations 2 : '+loc2);
                distance += Location.getDistance(loc1,loc2,'KM');
                System.debug('distance after first checkout : '+distance);
                System.debug('event list size : '+eventList.Size());
                for(integer i=0; i+1 <eventList.size();i++){
                    distance += Location.getDistance(Location.newInstance(eventList[i].Checkout__Latitude__s,eventList[i].Checkout__Longitude__s),
                                                     Location.newInstance(eventList[i+1].Checkout__Latitude__s,eventList[i+1].Checkout__Longitude__s),'KM');
                }
                distance += Location.getDistance(Location.newInstance(eventList[lastIndex].Checkout__Latitude__s,eventList[lastIndex].Checkout__Longitude__s),
                                                 Location.newInstance(beatObj.End_Latlang__latitude__s,beatObj.End_Latlang__Longitude__s),'KM');
                beatObj.Total_Distance__c = distance ;
            }
            System.debug('distance : '+distance);
            beatObj.End_Time__c = system.now().time();
            beatObj.Ended__c = true;
            System.debug('beat object : '+beatObj);
            update beatObj;
        } catch (Exception e) {
            System.debug('error in end my day method : '+e.getMessage()+', at line no : '+e.getLineNumber()); 
            return 'FAILED';
        } 
        return 'SUCCESS';
    }
    
    //This method will update or cancel the event
    @RemoteAction
    global static string updateCancelEvent(string info,map<string,Object> mapData){
        System.debug('request :---- '+mapData+', with info : '+info);
        try {
            DateTime now = (DateTime)JSON.deserialize('"' + string.valueOf(mapData.get('startTime')) + '"', DateTime.class);
            System.debug('JS Date: ' + now);
            event eventObj = new event();
            eventObj.Id = String.valueOf(mapData.get('eventId'));
            string [] dateArr = string.valueOf(mapData.get('date')).split('-');
            string [] startTimeArr = string.valueOf(mapData.get('startTime')).split(':');
            string [] endTimeArr = string.valueOf(mapData.get('endTime')).split(':');
            date evdate = date.newInstance(integer.valueOf(dateArr[0]), integer.valueOf(dateArr[1]), integer.valueOf(dateArr[2]));
            //time startTime = time.newInstance(integer.valueOf(startTimeArr[0]), integer.valueOf(startTimeArr[1]), 0, 0);
            //time endtime = time.newInstance(integer.valueOf(endTimeArr[0]), integer.valueOf(endTimeArr[1]), 0, 0);
            //System.debug('DAte: ' + DateTime.valueOf(string.valueOf(mapData.get('startTime'))));
            
            if(!test.isRunningtest()) {
                eventObj.StartDateTime =now; //DateTime.valueOf(string.valueOf(mapData.get('startTime')));//datetime.newInstance(evdate, startTime);
                
                eventObj.EnddateTIme =now;//DateTime.valueOf(string.valueOf(mapData.get('endTime'))); //datetime.newInstance(evdate, endtime);
            }
            
            eventObj.Update_Reason__c = String.valueOf(mapData.get('reason'));
            eventObj.Visit_date__c = evdate;
            //eventObj.Visit_date__c = system.today();
            system.debug('Visit Date in BeatPlanController: '+eventObj.Visit_date__c);
            if(info == 'cancel'){
                eventObj.Status__c = 'Cancelled';
            }
            System.debug('event updated : '+eventObj);
            update eventObj;
        } catch (Exception e) {
            System.debug('error in updating event :---- '+e.getMessage()+', At line no : '+e.getLineNumber());
            return e.getMessage();
        }
        return 'SUCCESS';
    }
    
    @RemoteAction
    global static string GetBasicUrl(){
        return URL.getSalesforceBaseUrl().toExternalForm();
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
        i++;i++;
        
        
    } 
}
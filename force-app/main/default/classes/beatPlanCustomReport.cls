public class beatPlanCustomReport {
    @AuraEnabled
    public set<date> beatdateList{get;set;}
    @AuraEnabled
    public map<string, string> numMonthList{get;set;}
    @AuraEnabled
    public List<String> getEntity{get;set;}
    @AuraEnabled
    public map<string, string> yrList{get;set;}
    @AuraEnabled
    public map<string,string> numRegionList{get;set;}
    @AuraEnabled
    public map<string , map<date,string>> mapOfMap{get;set;}
    @AuraEnabled
    public string attachmentId{get;set;}
    @AuraEnabled
    public map<string , map<date,string>> mapOfMapNew{get;set;}
    @AuraEnabled
    public set<date> beatdateListNew{get;set;}
    @AuraEnabled
    public string currentMonth{get;set;}
    @AuraEnabled
    public string currentMonthName{get;set;}
    @AuraEnabled
    public string currentYear{get;set;}
    @AuraEnabled
    Public string currentRegion {get;set;}
    
    @AuraEnabled
    Public Boolean IscurrentdateTab {get;set;}
    
    @AuraEnabled
    public  map<string,string> userrolemap {get;set;}
    
    @AuraEnabled
    public  map<string,string> Employeecodemap {get;set;}
    
    @AuraEnabled
    public   map<string,string> countrynamemap {get;set;}
    
    
    @AuraEnabled
    public static Map<String,List<Map<String,String>>> pickListMap {get;set;}
    
    @AuraEnabled
    public static Map<String,List<Map<String,String>>> pickListMaps {get;set;}
    
    @AuraEnabled
    public static  beatPlanCustomReport getfetchBeatPlan(string userName) {
        
        map<string , map<date,string>> mapdateVsUserEvents = new  map<string , map<date,string>>();
        //Attachment attachObj = [SELECT Id, Name FROM Attachment where name = 'biotech_logo-1.png' limit 1];
        //string attchId = attachObj.id;
        beatPlanCustomReport beatplanObj = new beatPlanCustomReport();                
        Integer monthSelection = Date.Today().Month(); //month > declared here so it can be overwritten in afuture enhancement
        Integer yearSelection = Date.Today().Year(); //year > declared here so it can be overwritten in afuture enhancement
        string  CurrentMonth = string.valueOf(monthSelection);
        string  CurrentYear = string.valueOf(yearSelection);
        string regionSelection='Domestic';
        List<Date> returnList = new List<Date>(); //return list of Dates
        Integer daysInMonth = Date.daysInMonth(yearSelection, monthSelection ); //number of days in month
        string query='select id, name, Region__c,Employee_Code__c,UserRole.Name,Country__c, CreatedDate from user WHERE IsActive = true AND corporate_function__c != TRUE AND region__c = \'' + regionSelection + '\'';
        System.debug('user name'+userName);
        map<Date,string> mapVsEventCommon = new map<Date, string>();
        map<Date,string> mapVsEventCommon1 = new map<Date, string>();
        set<date> setOfDays = new set<date>();
        for (Integer day = 1; day <= daysInMonth; day++) { //for first to last day in month
            setOfDays.add(Date.newInstance(yearSelection, monthSelection, day));
            mapVsEventCommon.put(Date.newInstance(yearSelection, monthSelection, day) , 'AB');
            mapVsEventCommon1.put(Date.newInstance(yearSelection, monthSelection, day) , 'AB');
        }
        
        /*  for(Holiday__c holi : [SELECT Id, Name, Country__c, Date__c, State__c, Type__c FROM Holiday__c where Date__c = THIS_MONTH ]){
if(mapVsEventCommon.containskey(holi.Date__c)){
mapVsEventCommon.put(holi.Date__c,holi.Type__c);
}
if(mapVsEventCommon1.containskey(holi.Date__c)){
mapVsEventCommon1.put(holi.Date__c,holi.Type__c);
} 
}*/
        system.debug('mapVsEventCommon : '+mapVsEventCommon);
        map<string, string> monListOfString = getNumMonth();
        map<string, string> listOfYr = getNumYr();
        map<string, string> listOfregion = getNumOfRegion();
        
        /*//Qyery  beatPlan*/
        list<string> userSet = new list<string>();
        map<string,string> userrolemap = new map<string,string>();
        map<string,string> Employeecodemap = new map<string,string>();
        map<string,string> countrynamemap = new map<string,string>();
        
        //List<Beat_Plan__c> beatList = [SELECT Id, End_Time__c, Event_Type__c, Beat_Date__c, BeatYr__c, BeatMonth__c,BUI__c, Assigned_To__c,owner.name from Beat_Plan__c where Beat_Date__c = THIS_MONTH and Event_Type__c != null];
        string qString = '';
        qString ='SELECT Id, End_Time__c, Event_Type__c, Beat_Date__c, BeatYr__c,Assigned_To__r.name, BeatMonth__c,BUI__c, Assigned_To__c,owner.name from Beat_Plan__c where Event_Type__c != null AND BeatMonth__c = \'' +CurrentMonth+ '\' and BeatYr__c = \'' + CurrentYear + '\' and Assigned_To__r.region__c = \'' + regionSelection + '\' and Assigned_To__r.corporate_function__c  !=TRUE  order by Assigned_To__r.name asc';
        List<Beat_Plan__c> beatList = database.query(qString);
        if(String.isNotBlank(userName) && userName !='') {
            query+=' AND (FirstName LIKE \'%' + userName + '%\' OR Employee_Code__c LIKE \'%' + userName + '%\' OR UserRole.Name LIKE \'%' + userName + '%\')';
        }
        query+=' Order by Name asc';
        System.debug('Query----->'+query);
        //system.debug('Database.query(query)'+Database.query(query));
        for(user usrObj :Database.query(query)){
            userSet.add(usrObj.name);
            
            if(usrObj.UserRole.Name==Null){
                userrolemap.put(usrObj.Name,'NIL');
            }else{
                userrolemap.put(usrObj.Name,usrObj.UserRole.Name);
            }
            if(usrObj.Employee_Code__c==Null){
                Employeecodemap.put(usrObj.Name,'NIL');
            }else{
                Employeecodemap.put(usrObj.Name,usrObj.Employee_Code__c);
            }
            if(usrObj.Country__c !=Null){
                countrynamemap.put(usrObj.Name,usrObj.Country__c);
            }else{
                countrynamemap.put(usrObj.Name,'NIL');
            }
        }
        system.debug(userSet);
        userSet.sort();
        system.debug('beatList :'+beatList.size());
        for(Beat_Plan__c btObj : beatList){
            map<date,string> newTempMap = new map<date,string>();
            if(mapdateVsUserEvents.containskey(btObj.Assigned_To__r.name) && userSet.contains(btObj.Assigned_To__r.name)){
                newTempMap = mapdateVsUserEvents.get(btObj.Assigned_To__r.name);
                system.debug(btObj.Event_Type__c);
                if(btObj.Event_Type__c != null){
                    //system.debug('i am in');
                    //system.debug(btObj.Event_Type__c);
                    //system.debug('110');
                    newTempMap.put(btObj.Beat_Date__c,btObj.Event_Type__c);
                }
                //system.debug('newTempMapnewTempMap :'+newTempMap);
                mapdateVsUserEvents.put(btObj.Assigned_To__r.name , newTempMap);
            }
            else{
                newTempMap = mapVsEventCommon.clone();
                if(newTempMap != null && newTempMap.containskey(btObj.Beat_Date__c)  && !string.isBlank(newTempMap.get(btObj.Beat_Date__c)) && newTempMap.get(btObj.Beat_Date__c) != null){
                    newTempMap.put(btObj.Beat_Date__c,btObj.Event_Type__c);
                } 
                if(userSet.contains(btObj.Assigned_To__r.name)){
                    mapdateVsUserEvents.put(btObj.Assigned_To__r.name , newTempMap);
                }
            }
            //system.debug(newTempMap);
            if(userSet.contains(btObj.Assigned_To__r.name)){
                mapdateVsUserEvents.put(btObj.Assigned_To__r.name,newTempMap);
            }
            
        }
        Map<String,Date> userDateMap=new Map<String,Date>();
        for(user usrObj : Database.query(query)){
            userDateMap.put(usrObj.name,usrObj.CreatedDate.date());
            if(!mapdateVsUserEvents.containskey(usrObj.name)){
                mapdateVsUserEvents.put(usrObj.name,mapVsEventCommon1);
            }
            
        }
        
        
        System.debug('user created date'+JSON.serialize(userDateMap));
        
        /* if(mapdateVsUserEvents.size()>0) {
for(String usrName:mapdateVsUserEvents.keySet()) {

Map<Date,String> curMap=mapdateVsUserEvents.get(usrName);
mapdateVsUserEvents.put(usrName,curMap);
System.debug('Serailize map'+JSON.serialize(curMap));
for(Date dt:curMap.keySet()) {
System.debug('User Name'+usrName);
System.debug('Created date'+userDateMap.get(usrName));
System.debug('Main date'+dt);
if(userDateMap.get(usrName)>=dt) {
System.debug('In user'+usrName);
curMap.put(dt,''); 
}
}

mapdateVsUserEvents.put(usrName,curMap);
}
}
System.debug('Data map'+JSON.serialize(mapdateVsUserEvents));*/
        
        
        
        
        system.debug(string.valueOf(yearSelection));
        
        beatplanObj.currentMonth = string.valueOf(monthSelection ); //+ 1
        beatplanObj.currentyear = string.valueOf(yearSelection);
        beatplanObj.mapOfMap = mapdateVsUserEvents;
        beatplanObj.beatdateList = setOfDays;
        beatplanObj.numMonthList = monListOfString;
        beatplanObj.yrList = listOfYr;
        beatplanObj.userrolemap = userrolemap;
        beatplanObj.countrynamemap = countrynamemap;
        beatplanObj.Employeecodemap = Employeecodemap;
        beatplanObj.numRegionList = listOfregion;
        //beatplanObj.attachmentId = attchId;
        beatplanObj.currentMonthName = monListOfString.get(string.valueOf(monthSelection ));
        beatplanObj.currentRegion=listOfregion.get(regionSelection);
        system.debug('beatplanObj'+beatplanObj);
        return beatplanObj; 
        //system.debug('beatplanObj'+beatplanObj);
    }
    @AuraEnabled
    public static beatPlanCustomReport getSearchedBeatPlan(string selectedYr, string selectedMonths, string selectedreg, date startDate, date endDate, Boolean selectedMonthTab,string receivedData,string userName){   
       
        
        string query='select id, name,Country__c, Region__c,Employee_Code__c,UserRole.Name from user Where IsActive = true AND corporate_function__c != TRUE';
        System.debug('user name'+userName);
        String jsonString = receivedData ;
        Object parsedJson;
        if (jsonString != null) {
            // Deserialize the JSON string to a generic Object
            parsedJson = JSON.deserializeUntyped(jsonString);
            
            // Rest of your JSON parsing logic goes here
        } else {
            receivedData = '{"Country":"INDIA"}';
            System.debug('Error: receivedData is null.');
        }
        
        
        // Object parsedJson = JSON.deserializeUntyped(jsonString);
        // 
        //this map store username and respective user rolename.
        map<string,string> userrolemap = new map<string,string>();
        //this map store username and respective user user employee code.
        map<string,string> Employeecodemap = new map<string,string>();
        //this map store username and respective user country name.
        map<string,string> countrynamemap = new map<string,string>();
        // Create a Map to store key-value pairs
        Map<String, String> resultMap = new Map<String, String>();
        // Create a Map to store the holiday data
        Map<Date,Map<String,String>> hldyMap=new Map<Date,Map<String,String>>();
        
        // Process the parsed JSON to extract key-value pairs
        // Assuming parsedJson is a Map<String, Object>
        if (parsedJson instanceof Map<String, Object>) {
            Map<String, Object> jsonMap = (Map<String, Object>)parsedJson;
            
            for (String key : jsonMap.keySet()) {
                Object value = jsonMap.get(key);
                if (value != null) {
                    resultMap.put(key, String.valueOf(value));
                }
            }
        }
        
        string Statename = '';
        string countryname ='';
        countryname = resultMap.get('Country');
        Statename = resultMap.get('state');
     
        // Output the resulting Map
        
        Integer numberDaysDue = 0;
        integer selectedMon = 0;
        string yearSelected = '';
        // create a new instance of the class
        beatPlanCustomReport beatplanObj = new beatPlanCustomReport();  
        beatplanObj.IscurrentdateTab = false;
        //create map of month and number of days in month
        Map<string, string> mapOfMOnthandNumber =  getNumerMonth();
        if(startDate != null && endDate != null && selectedMonthTab == false){
            numberDaysDue = startDate.daysBetween(endDate)+ 1;
            //numberDaysDue = startDate.day();
            beatplanObj.IscurrentdateTab = true;
            selectedMon = startDate.month();
            yearSelected = string.valueOf(startDate.year());
           
        }
        
        else if( selectedMonths != null &&  selectedMonths !='' && selectedMonthTab == true){
            selectedMon = integer.valueOf(selectedMonths);
        }
        else if(startDate==Null){ 
            yearSelected  =  string.valueOf(Date.Today().year());
            
        }
        
        if(selectedYr != null && yearSelected == '' && selectedMonthTab == true){
            yearSelected = string.valueOf(selectedYr);
        }
       
        
        Integer Endmonth;
        if(endDate !=Null){
            Endmonth = endDate.month();
        }
       
        
        //String monthName = myDate.format().substringBefore('-');
        string selectedMonth = string.valueOf(selectedMon);
        String qString = '';
        string qUserString = ''; 
       
        
        if (yearSelected != null && selectedMon == null) {
    qString = 'SELECT Id, End_Time__c, Event_Type__c, Beat_Date__c, BeatYr__c, BeatMonth__c, BUI__c, Assigned_To__r.Name, Assigned_To__r.Region__c, Assigned_To__r.Country__c, Assigned_To__r.State__c, Assigned_To__c, Owner.Name ' +
              'FROM Beat_Plan__c WHERE Event_Type__c != null AND BeatYr__c = \'' + yearSelected + '\'';
} 
else if (yearSelected == null && selectedMon != null) {
    qString = 'SELECT Id, End_Time__c, Event_Type__c, Beat_Date__c, BeatYr__c, BeatMonth__c, BUI__c, Assigned_To__r.Name, Assigned_To__r.Region__c, Assigned_To__r.Country__c, Assigned_To__r.State__c, Assigned_To__c, Owner.Name ' +
              'FROM Beat_Plan__c WHERE Event_Type__c != null AND BeatMonth__c = \'' + selectedMon + '\'';
} 
else if (yearSelected != null && selectedMon != null && (startdate == null || Enddate == null)) {
    qString = 'SELECT Id, End_Time__c, Event_Type__c, Beat_Date__c, BeatYr__c, BeatMonth__c, BUI__c, Assigned_To__r.Name, Assigned_To__r.Region__c, Assigned_To__r.Country__c, Assigned_To__r.State__c, Assigned_To__c, Owner.Name ' +
              'FROM Beat_Plan__c WHERE Event_Type__c != null AND BeatMonth__c = \'' + selectedMon + '\' AND BeatYr__c = \'' + yearSelected + '\'';
} 
else if (startdate < Enddate && startdate != null && Enddate != null && selectedMonthTab == false) {
    qString = 'SELECT Id, End_Time__c, Event_Type__c, Beat_Date__c, BeatYr__c, BeatMonth__c, BUI__c, Assigned_To__r.Name, Assigned_To__r.Region__c, Assigned_To__r.Country__c, Assigned_To__r.State__c, Assigned_To__c, Owner.Name ' +
              'FROM Beat_Plan__c WHERE Event_Type__c != null AND Beat_Date__c >= :startDate AND Beat_Date__c <= :endDate';
} 
else {
    qString = 'SELECT Id, End_Time__c, Event_Type__c, Beat_Date__c, BeatYr__c, BeatMonth__c, BUI__c, Assigned_To__r.Name, Assigned_To__c, Owner.Name ' +
              'FROM Beat_Plan__c WHERE Event_Type__c != null AND BeatMonth__c = \'' + selectedMon + '\'';
}

// Now adding additional filters
if (String.isNotBlank(selectedreg) && String.isBlank(countryname) && String.isBlank(statename)) {
    qString += ' AND Assigned_To__r.Region__c = \'' + selectedreg + '\'';
}

if (String.isNotBlank(selectedreg) && String.isNotBlank(countryname) && String.isBlank(statename)) {
    qString += ' AND Assigned_To__r.Region__c = \'' + selectedreg + '\'';
    qString += ' AND Assigned_To__r.Country__c = \'' + countryname + '\'';
}

if (String.isNotBlank(selectedreg) && String.isNotBlank(countryname) && String.isNotBlank(statename)) {
    qString += ' AND Assigned_To__r.Region__c = \'' + selectedreg + '\'';
    qString += ' AND Assigned_To__r.Country__c = \'' + countryname + '\'';
    qString += ' AND Assigned_To__r.State__c = \'' + statename + '\'';
}

if (String.isBlank(selectedreg) && String.isNotBlank(countryname) && String.isNotBlank(statename)) {
    qString += ' AND Assigned_To__r.Country__c = \'' + countryname + '\'';
    qString += ' AND Assigned_To__r.State__c = \'' + statename + '\'';
}

// Final single ORDER BY
qString += ' AND Assigned_To__r.corporate_function__c != TRUE  ORDER BY Assigned_To__r.Name ASC';

          
        
        List<Beat_Plan__c> beatList = database.query(qString);
       
        
       
        // Create a map to store the Username and their respective user dates or event types, if applicable.
        map<string , map<date,string>> mapdateVsUserEvents = new  map<string , map<date,string>>();
        
        
        Integer monthSelection = integer.valueOf(selectedMon);
        
        
        Integer yearSelection = integer.valueOf(yearSelected);
        
        List<Date> returnList = new List<Date>(); //return list of Dates
        Integer daysInMonth = Date.daysInMonth(yearSelection, monthSelection ); //number of days in month
        
        
        // Create a map to store the common event types for each date
        map<Date,string> mapVsEventCommon = new map<Date, string>();
        set<date> setOfDays = new set<date>();
        if(numberDaysDue == 0){
            for (Integer day = 1; day <= daysInMonth; day++) { //for first to last day in month
                setOfDays.add(Date.newInstance(yearSelection, monthSelection, day));
                mapVsEventCommon.put(Date.newInstance(yearSelection, monthSelection, day) , 'AB');
                
            }
         
            
        }
        
        
        else{
     
            for (Date d = startDate; d <= endDate; d = d.addDays(1)) {
                setOfDays.add(d); // Use 'd' directly as it already has the correct year
                mapVsEventCommon.put(d, 'AB'); // Use 'd' directly
                //   mapVsEventCommon1.put(d, 'AB'); // Use 'd' directly
                
            }
            
            
        }
    
        
        String qholidayString;
        List<String> filters = new List<String>();
        if(startDate == null && endDate == null) {
            if (yearSelected != null && selectedMon == null) {
                filters.add('Year__c = :selectedYr');
            } 
            else if (yearSelected == null && selectedMon != null) {
                filters.add('Month__c = :selectedMonths');
            } 
            else if (yearSelected != null && selectedMon != null) {
                filters.add('Year__c = :selectedYr');
                filters.add('Month__c = :selectedMonths');
            } 
        }
        
        
        
        else if (Countryname != null && resultMap.containsKey('state') && String.isNotBlank(resultMap.get('state'))) {
            filters.add('Country__c = :Countryname');
            filters.add('State__c = :statename');
        } 
        else if (Countryname != null && !resultMap.containsKey('state')) {
            filters.add('Country__c = :Countryname');
        } 
        else if (Countryname != null && resultMap.containsKey('state') && String.isBlank(resultMap.get('state'))) {
            filters.add('Country__c = :Countryname');
        }
        
        // **Updated Date Filter: Check if Start and End Date are Provided**
        if (startDate != null && endDate != null) {
            filters.add('Date__c >= :startDate AND Date__c <= :endDate');
        } 
        
        // Always ensure Type__c is filtered
        filters.add('Type__c != null');
        
        qholidayString = 'SELECT Id, Name, Country__c, Date__c, State__c, Type__c, Region__c FROM Holiday__c';
        
        // Add WHERE clause if there are any filters
        if (!filters.isEmpty()) {
            qholidayString += ' WHERE ' + String.join(filters, ' AND ');
        }
        
        // Append Region filter if applicable
        if (selectedreg != null && selectedreg != '') {
            qholidayString += ' AND Region__c = :selectedreg';
        }
        
        qholidayString += ' ORDER BY Owner.Name ASC';

        list<Holiday__c> holidaylist = Database.Query(qholidayString);
     
        
        
        
        
        
        Map<String,String> duplCheckMap=new Map<String,String>();
        
        for(Holiday__c holi : holidaylist){
   
            if(mapVsEventCommon.containskey(holi.Date__c)){
                mapVsEventCommon.put(holi.Date__c,holi.Type__c);
            }
            
            if(hldyMap.containsKey(holi.Date__c)) {
                Map<String,String> temMap=hldyMap.get(holi.Date__c);
                if(temMap.containsKey(holi.Region__c+holi.Country__c+holi.State__c)) {
                    string temVar=temMap.get(holi.Region__c+holi.Country__c+holi.State__c);
                    temVar=holi.Type__c;
                    temMap.put(holi.Region__c+holi.Country__c+holi.State__c,temVar);
                }else {
                    temMap.put(holi.Region__c+holi.Country__c+holi.State__c,holi.Type__c);
                }
                hldyMap.put(holi.Date__c,temMap);
            }else{
                Map<String,String> temDataMap=new Map<String,String>();
                temDataMap.put(holi.Region__c+holi.Country__c+holi.State__c,holi.Type__c);
                hldyMap.put(holi.Date__c,temDataMap);
            }
        }

        
        qUserString = 'SELECT Id, Name,Region__c,Country__c,Employee_Code__c,UserRole.Name,State__c FROM User WHERE IsActive = true AND corporate_function__c != TRUE';
        if(String.isNotBlank(userName) && userName!='') {
            query+=' AND (FirstName LIKE \'%' + userName + '%\' OR Employee_Code__c LIKE \'%' + userName + '%\' OR UserRole.Name LIKE \'%' + userName + '%\') AND corporate_function__c =:true';
            
        }
        
        query+=' order by name asc';
        
        if(Countryname != '' && Countryname != Null && resultMap.containskey('state') && resultMap.containskey('state') <> NULL && resultMap.get('state') <> ''){
            qUserString += ' AND Country__c = \'' + Countryname + '\' AND State__c = \'' + statename + '\'';
        } else if(Countryname !='' && Countryname != Null  && !resultMap.containskey('state')){
            qUserString += ' AND Country__c = \'' + Countryname + '\'';
            
        }else if(Countryname =='' && Countryname == Null && resultMap.containskey('state') && resultMap.get('state') == '' && resultMap.get('state') == Null) {
            system.debug('qUserString-------country is blank  and state also blank  '+ qUserString);
            
        }
        //******************************************* Added Below  by Gyadeen*********************************
        
        if ((selectedreg=='Domestic' && (Countryname ==''|| Countryname ==Null))||(selectedreg=='International'&&(Countryname =='' || Countryname ==Null)) || (selectedreg=='Turkey'&& Countryname ==''|| Countryname ==Null)||(selectedreg=='Domestic Ortho' && Countryname ==''|| Countryname ==Null)){
            qUserString +=' AND Region__c = \'' + selectedreg + '\' and IsActive = true';            
        }
        else if((selectedreg=='Domestic' && (Countryname !=''&& Countryname !=Null))||(selectedreg=='International'&& (Countryname !=''&& Countryname !=Null)) || (selectedreg=='Turkey'&& (Countryname !=''&& Countryname !=Null))||(selectedreg=='Domestic Ortho'&& (Countryname !=''&& Countryname !=Null))){

        }
        else if (selectedreg=='All' && (Countryname ==''|| Countryname ==Null)) {
            qUserString +=' AND IsActive = true ';
        }
        else
        {
        }
        
        //******************************************* Added Above  by Gyadeen*********************************
        
        
        
        qUserString+=' Order by Name asc';
        List<user> userList = new list<user>();
        set<string> userSet = new set<string>();
        userList = database.query(qUserString);
        for(user usrObj : userList){
            userSet.add(usrObj.name);
            
            if(usrObj.UserRole.Name==Null){
                userrolemap.put(usrObj.Name,'NIL');
                
            }else{
                userrolemap.put(usrObj.Name,usrObj.UserRole.Name);
                countrynamemap.put(usrObj.Name,usrObj.Country__c);
            }
            if(usrObj.Employee_Code__c==Null){
                Employeecodemap.put(usrObj.Name,'NIL');
            }else{
                Employeecodemap.put(usrObj.Name,usrObj.Employee_Code__c);
            }
            if(usrObj.Country__c !=Null){
                countrynamemap.put(usrObj.Name,usrObj.Country__c);
            }else{
                countrynamemap.put(usrObj.Name,'NIL');
            }
        }
    
        for(Beat_Plan__c btObj : beatList){
            duplCheckMap.put(btObj.Assigned_To__r.name+string.valueof(btObj.Beat_Date__c),'');
        
            if(mapdateVsUserEvents.containskey(btObj.Assigned_To__r.name)){
                Map<Date,String> newTempMapData = mapdateVsUserEvents.get(btObj.Assigned_To__r.name);
                if(newTempMapData.containsKey(btObj.Beat_Date__c)) {
                    string btData=newTempMapData.get(btObj.Beat_Date__c);
                    btData=btObj.Event_Type__c;
                    newTempMapData.put(btObj.Beat_Date__c,btData);
                }else {
                    newTempMapData.put(btObj.Beat_Date__c,btObj.Event_Type__c);
                }
                
         
                mapdateVsUserEvents.put(btObj.Assigned_To__r.name , newTempMapData);
            }
            else{
                
                Map<Date,String> tempMapData=new Map<Date,String> ();
                tempMapData.put(btObj.Beat_Date__c,btObj.Event_Type__c);
                mapdateVsUserEvents.put(btObj.Assigned_To__r.name , tempMapData);
                
            }
            

            
        }
        
        
        for(user usrObj : userList){
            Map<Date, String> mapVsEventCommon1 = new Map<Date, String>();
            if(startDate!=null && endDate!=null) 
                for (Date d = startDate; d <= endDate; d = d.addDays(1)) {
                    mapVsEventCommon1.put(d, 'AB'); // Use 'd' directly
                    
                }
            if(startDate==null && endDate==null) {
                for (Integer day = 1; day <= daysInMonth; day++) { //for first to last day in month
                    mapVsEventCommon1.put(Date.newInstance(yearSelection, monthSelection, day) , 'AB');
                    
                }
            }
           
            
            if(mapdateVsUserEvents.containskey(usrObj.name)){
                Map<Date,String> btUserMap=mapdateVsUserEvents.get(usrObj.name);
                for(Date dt:mapVsEventCommon1.keySet()) {
                    if(!btUserMap.containsKey(dt)) {
                        if(hldyMap.containsKey(dt) && hldyMap.get(dt).containsKey(usrObj.Region__c+usrObj.Country__c+usrObj.State__c)) {
                                btUserMap.put(dt,hldyMap.get(dt).get(usrObj.Region__c+usrObj.Country__c+usrObj.State__c)); 
                            
                        }
                        else {
                            btUserMap.put(dt,'AB');
                        }
                    }
                  
                }
                
                 mapdateVsUserEvents.put(usrObj.name,btUserMap);
                
            }
            else {
                for(Date dt:mapVsEventCommon1.keySet()) {
                    if(hldyMap.containsKey(dt)) { 
                            Map<String,String> temMap=hldyMap.get(dt);
                            if(temMap.containsKey(usrObj.Region__c+usrObj.Country__c+usrObj.State__c)) {
                                mapVsEventCommon1.put(dt,temMap.get(usrObj.Region__c+usrObj.Country__c+usrObj.State__c)); 
                            }
                     
                    }
                    
                }
               mapdateVsUserEvents.put(usrObj.name,mapVsEventCommon1); 
                
            }// else close
            
            
            
            
      
        }
        
        
        
        for (String employeeName : mapdateVsUserEvents.keySet()) {
    
    Map<Date, String> dateStatusMap = mapdateVsUserEvents.get(employeeName);

    List<Date> dateList = new List<Date>(dateStatusMap.keySet());

    dateList.sort(); 
            Map<Date,String> temMap=new Map<Date,String>();
            for(date dt:dateList) {
                temMap.put(dt,dateStatusMap.get(dt));
            }
        mapdateVsUserEvents.put(employeeName,temMap);    
            

}
        
        beatplanObj.mapOfMapNew = mapdateVsUserEvents;
        beatplanObj.beatdateListNew = setOfDays;
        beatplanObj.userrolemap = userrolemap;
        beatplanObj.Employeecodemap = Employeecodemap;
        beatplanObj.countrynamemap = countrynamemap;
   
        return beatplanObj; 
        
    }
    
    @AuraEnabled 
    public static user fetchUser(){
        User u = [select id,Name, Region__c from User where id =: userInfo.getUserId() order by name asc];
        return u;
    }
    
    public static Map<string, string> getNumMonth(){
        Map<string, string> monthList = new Map<string, string>();
        //monthList.put('0','---NONE---');
        monthList.put('1','Jan');
        monthList.put('2','Feb');
        monthList.put('3','Mar');
        monthList.put('4','Apr');
        monthList.put('5','May');
        monthList.put('6','Jun');
        monthList.put('7','Jul');
        monthList.put('8','Aug');
        monthList.put('9','Sep');
        monthList.put('10','Oct');
        monthList.put('11','Nov');
        monthList.put('12','Dec');
        
        return monthList;
    }
    public static Map<string, string> getNumYr(){
        Map<string, string> yrMap = new Map<string, string>();
        // yrMap.put('1','---NONE---');
        yrMap.put('2019','2019');
        yrMap.put('2020','2020');
        yrMap.put('2021','2021');
        yrMap.put('2022','2022');
        yrMap.put('2023','2023');
        yrMap.put('2024','2024');
        yrMap.put('2025','2025');
        yrMap.put('2026','2026');
        yrMap.put('2027','2027');
        yrMap.put('2028','2028');
        yrMap.put('2029','2029');
        yrMap.put('2030','2030');
        
        
        return yrMap;
    }
    public static map<string,string> getNumOfRegion(){
        Map<string, string> regionMap = new Map<string, string>();
        // regionMap.put('1','---NONE---');
        regionMap.put('Domestic','Domestic');
        regionMap.put('International','International');
        regionMap.put('Turkey','Turkey');
        //regionMap.put('Domestic Ortho','Domestic Ortho');
        
        return regionMap;
    }
    public static Map<string, string> getNumerMonth(){
        Map<string, string> monthList = new Map<string, string>();
        //monthList.put('1','---NONE---');
        monthList.put('Jan','1');
        monthList.put('Feb','2');
        monthList.put('Mar','3');
        monthList.put('Apr','4');
        monthList.put('May','5');
        monthList.put('Jun','6');
        monthList.put('Jul','7');
        monthList.put('Aug','8');
        monthList.put('Sep','9');
        monthList.put('Oct','10');
        monthList.put('Nov','11');
        monthList.put('Dec','12');
        
        return monthList;
    }
    @AuraEnabled
    public static Map<String,List<Map<String,String>>> getPicklistData() {
        pickListMap=new Map<String,List<Map<String,String>>>();
        pickListMap=CommonutiltiyClass.getLightningPickListValues();
        return pickListMap;
        
    } 
    @AuraEnabled
    public static Map<String,List<Map<String,String>>> getStateDatas(string country) {
        pickListMaps=new Map<String,List<Map<String,String>>>();
        pickListMaps=CustomLeadCreationController.getCountryMappingData(country);
        return pickListMaps;
        
    } 
}
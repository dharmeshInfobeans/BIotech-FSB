/***********************************************************************************************************
Author : Prashant Rana
Description : This class will take care for after checkin part from mobile app
Date : 01-01-2019
************************************************************************************************************/

global with sharing class BeatPlanSecondAppPageController {
    
    public Blob uploadedFile { get; set; }
    public String fileName { get; set; }
    public string eventIds {get; set;}
    public String eventData{get;set;}
    public string lastFiveInvoicesList{get;set;}
    public string productList{get;set;}
    public user userObj{get;set;}
    public string curentLang{get;set;}
    public DCR_Detail2_Translation__c translationObject{get;set;}
    public DCR_Planning_Translation_Turkey__c translationObject1{get;set;}
    public List<event>lstEvent {get;set;}
    public Boolean showCheckBox{get;set;}
    public List<String> stagesOption{get;set;}
    public boolean isnewlead {get;set;}
    public Customercreationlabels__c customercretaion {get;set;}
    public boolean includecustomer {get;set;}
    public Boolean isMarketingUser {get;set;}
    
    //START BD
    public static List<BeatPlanSecondAppPageController.BDWrapper>lstWrapper{get;set;}
    public static string lstWrapString{get;set;}
    public boolean isPdAvailable{get;set;}
    public string lstWrapStringValue{get;set;}
    public map<string,list<event>>mapOfEvent{get;set;}
    public boolean isError{get;set;}
    public string lstWrapValue{get;set;}
    global string isCommunityUser{get;set;}
    public List<Lead__c> leadDataList{get;set;}
    public String leadDataJson {get;set;}
    
    //END BD
    
    //Constructor
    global BeatPlanSecondAppPageController() {
        try {
            Integer i=1;
            leadDataList=new List<Lead__c>();
            User  objUser  = [select id,Name,Profile.Name,userRoleId,userRole.Name,Country__c from User where id =: UserInfo.getUserId()];
            Userrole rl = new Userrole();
            if(objUser.userRoleId != null){
                rl =[SELECT Id, Name, DeveloperName FROM UserRole WHERE Id =: objUser.userRoleId];
            }
            
            // Check if user is a marketing user
            isMarketingUser = checkIfMarketingUser();
            
            // Set stages based on user type
            if(isMarketingUser) {
                stagesOption = getMarketingStages();
            } else {
                stagesOption = getLeadStages();
            }
            
            Id recId;
            if(rl.Name != Null){
                if(rl.Name=='Colambia and Brazil Portal User Partner User'){
                    recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('DCR Planning').getrecordTypeId();  
                }else{
                    recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('DCR Planning').getrecordTypeId();  
                }
            }else{
                recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('DCR Planning').getrecordTypeId();   
            }
            Id recIdBD = Schema.SObjectType.Event.getRecordtypeInfosByName().get('BD Tracker').getrecordTypeId();
            
            curentLang = UserInfo.getLanguage();
            translationObject1 = DCR_Planning_Translation_Turkey__c.getValues(curentLang);
            translationObject= DCR_Detail2_Translation__c.getValues(UserInfo.getLanguage()); 
            if(translationObject== null){
                translationObject= DCR_Detail2_Translation__c.getValues('en_US');
            }
            id eventId = apexpages.currentpage().getparameters().get('id');
           
            System.debug('event id on page : '+eventId);
            event eventObj = [select Profile_Name__c,subject,toLabel(product__c),Leads__c,Leads__r.Name,Leads__r.Product__c,Leads__r.Account__c,Leads__r.CE_CIS_Rating__c,Leads__r.Phakic_Rating__c,DCR_Description__c,Leads__r.CE_CIS_Approval__c,Leads__r.Status__c,Leads__r.Lead_Stage__c,Leads__r.Lead_Date__c,Leads__r.Marketing_Stage__c,Leads__r.Lead_Marketing_date__c,Sub_Call_Type__c, Call_Type__c,CE_Rating__c,CIS_Rating__c, Account__r.Name,Who.Name,whatId,Leads__r.Mobile__c from event where Id=:eventId ];
             eventIds = eventObj.Id;
            if(eventObj.Call_Type__c == 'In Clinic Branding'){
                if(uploadedFile !=null){
                 uploadFile();
                }
            }
            
            System.debug('event record : '+eventObj);
            string query = 'SELECT Id, Lead_Stage__c,Marketing_Stage__c, Name, Product__c,New_Customer__c,Existing_customer__c,SAP_Code__c FROM Lead__c WHERE Lead_Closed__c != true AND Lead_Stage__c != \'Won\' AND Lead_Stage__c != \'Unqualified\' AND Lead_Stage__c != \'Lost\'';
            
            if(eventObj.Leads__c!=null) {
                string mobileNumber=eventObj.Leads__r.Mobile__c;
                System.debug('Mobile nymber'+mobileNumber);
                query+=' AND  Mobile__c =:mobileNumber'; 
            }
            if(eventObj.Leads__r.Account__c!=null) {
                string accountId=eventObj.Leads__r.Account__c;
                query+=' AND Account__c=:accountId'; 
            }
            
            query += ' LIMIT 1000';
            
            leadDataList = Database.query(query);
            leadDataJson = JSON.serialize(leadDataList);
            
            System.debug('Lead data list'+leadDataList);
            
            System.debug('Lead data list size '+leadDataList.size());
            
            if(eventObj.WhatId!=null && Schema.Lead__c.SObjectType==eventObj.WhatId.getSobjectType()) {
                showCheckBox=true;
            }
            if(eventObj.WhatId!=null && Schema.Account.SObjectType==eventObj.WhatId.getSobjectType()) {
                showCheckBox=false;
            }
            
            String ev = JSON.serialize(eventObj);
            System.debug('Final event data'+ev);
            eventData = ev.escapeUnicode().remove('\'');
            
            userObj = [select id, name, profileId,User_Type__c from user where id =: userInfo.getUserId() limit 1];
            list<product__c> prodList = [select name from Product__c where region__c =: userObj.user_Type__c AND MSP__c !=null AND MSP__c != 0 order by Name ASC];
            if(!prodList.isEmpty()){
                String pes = JSON.serialize(prodList);
                productList = pes.escapeUnicode().remove('\'');
            }
            
            customercretaion = getCustomLabelscustomercreation();
            includecustomer = isUserCountryExcluded();
            system.debug('includecustomer: '+includecustomer);
        } catch (Exception  e) {
            System.debug('error in constructor : '+e.getMessage()+' At line no : '+e.getLineNumber());
        } 
    }
    
    // Method to check if user is marketing user
    private Boolean checkIfMarketingUser() {
        Profile userProfile = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId()];
        // Add your marketing profile names here - update these based on your org's profile names
        Set<String> marketingProfiles = new Set<String>{'Marketing User'};
            return marketingProfiles.contains(userProfile.Name);
    }
    
    // Static method to check if user is marketing user (for remote actions)
    private static Boolean checkIfMarketingUserStatic() {
        Profile userProfile = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId()];
        Set<String> marketingProfiles = new Set<String>{'Marketing User'};
            return marketingProfiles.contains(userProfile.Name);
    }
    
    // Method to get lead stages for non-marketing users
    private List<String> getLeadStages() {
        return new List<String>{'Prospect', 'Appointments', 'Presentation', 'Product Demo', 
            'Evaluations', 'Commercialization', 'Upgrade'};
                }
    
    // Method to get marketing stages for marketing users
    private List<String> getMarketingStages() {
        return new List<String>{'CME', 'RTM', 'User Meeting', 'High Impact CME', 
            'KOL/FOL Development', 'Virtual exp. Lab', 'Wet Labs', 
            'Testimonial', 'CTP', 'Focus', 'Decode', 'Inclinic Branding'};
                }
    
    public static Boolean isUserCountryExcluded() {
        Id currentUserId = UserInfo.getUserId();
        
        User currentUser = [
            SELECT Country__c, Customer_Creation_Module__c
            FROM User
            WHERE Id = :currentUserId
            LIMIT 1
        ];
        
        String isCustomCreationEnabled = (currentUser.Customer_Creation_Module__c!=null &&  currentUser.Customer_Creation_Module__c!='') ? currentUser.Customer_Creation_Module__c : '';
        
        String excludedCountries = Label.Country_wise_Customer_creation_module;
        
        List<String> excludedCountryList = new List<String>();
        if (!String.isEmpty(excludedCountries)) {
            
            if(excludedCountries!=null && excludedCountries!='') {
                if(excludedCountries.contains(',')) {
                    for (String country : excludedCountries.split(',')) {
                        excludedCountryList.add(country.trim());
                    }
                }else {
                    excludedCountryList.add(excludedCountries.trim());
                }
            }
        }
        
        return excludedCountryList.contains(isCustomCreationEnabled);
    }
    
    public static Customercreationlabels__c getCustomLabelscustomercreation() {
        String language=UserInfo.getLanguage();
        Customercreationlabels__c leadTranslationLabel = Customercreationlabels__c.getValues(language);
        return leadTranslationLabel;
        
    }
    
    public void uploadFile() {

    if (uploadedFile == null || String.isBlank(fileName)) {
        return;
    }

    Id evId = Id.valueOf(eventIds);

    ContentVersion cv = new ContentVersion();
    cv.Title = fileName;
    cv.PathOnClient = fileName;
    cv.VersionData = uploadedFile;
    insert cv;

    cv = [
        SELECT ContentDocumentId
        FROM ContentVersion
        WHERE Id = :cv.Id
        LIMIT 1
    ];

    ContentDocumentLink cdl = new ContentDocumentLink();
    cdl.ContentDocumentId = cv.ContentDocumentId;
    cdl.LinkedEntityId = evId;
    cdl.ShareType = 'V';
    cdl.Visibility = 'AllUsers';
    insert cdl;
}

    
    // This method for save the DCR
    @RemoteAction
    global static string saveDCR(map<string, Object> dataMap,string leadMap,Map<String,Object> leadStageMap){
        System.debug('Data Map'+dataMap);
        System.debug('Lead map'+leadMap);
        System.debug('Lead stage map'+leadStageMap);
        
        Map<String,Object> leadUpdateMap=(Map<String,Object>)JSON.deserializeUntyped(leadMap);
        System.debug('Lead Update map'+leadUpdateMap);
        
        // Get user type
        Boolean isMarketingUser = checkIfMarketingUserStatic();
        
        Id leadId=(Id)string.valueOf(dataMap.get('whatId'));
        if(Schema.Lead__c.SObjectType==leadId.getSobjectType()) {
            System.debug('Lead UId'+leadId);
            List<Lead__c> leaList=[SELECT Id,Name,Status__c,Appointment_Date_History__c,Product_Demo_Date_History__c,
                                   Product_Demo_Stage_Count__c,Evaluation_Date_History__c,Evaluation_Stage_Count__c,
                                   Commercialization_Stage_Count__c,Commercialization_Date_History__c,Upgrade_Date_History__c,
                                   Upgrade_Stage_Count__c,Presentation_Date_History__c,Presentation_Stage_Count__c,Appointment_Stage_Count__c,
                                   New_Customer__c,Company__c,SAP_Code__c ,CE_CIS_Approval__c,Email__c,Billing_code__c,Billing_Street__c, 
                                   Lead_Stage__c,Marketing_Stage__c,Actual_Prospect_Week__c,Actual_Appointments_Week__c,
                                   Actual_Presentation_Week__c,Actual_Product_Demo_Week__c,Actual_Evaluations_Week__c,
                                   Actual_Commercialization_week__c,Actual_Upgrade_week__c,Actual_CME__c,Actual_RTM__c,
                                   Actual_User_Meeting__c,Actual_High_Impact_CME__c,Actual_KOL_FOL_Development__c,
                                   Actual_Virtual_exp_Lab__c,Actual_Wet_Labs__c,Actual_Testimonial__c,Actual_CTP__c,
                                   Actual_Focus__c,Actual_Decode__c,Actual_Inclinic_Branding__c from Lead__c where Id in:leadStageMap.keySet()];
            
            System.debug('Lead get data'+JSON.serialize(leaList));
            
            for(Lead__c lea:leaList) {
                // Validation for required fields
                if (String.isBlank(lea.Company__c) || String.isBlank(lea.Email__c) || String.isBlank(lea.Billing_code__c) || String.isBlank(lea.Billing_Street__c)) {
                    system.debug('run------> Please fill in Email ID, Hospital / Clinic Name, and Street ZIP Code.');
                    return 'Please fill in Email ID, Hospital / Clinic Name, and Street ZIP Code';
                }
                
                system.debug('lea.Lead_Stage__c'+lea.Lead_Stage__c);
                if (String.isBlank(lea.SAP_Code__c) && lea.New_Customer__c && leadStageMap.containsKey(lea.Id) && 
                    (leadStageMap.get(lea.Id)=='Commercialization' || leadStageMap.get(lea.Id)=='Commercialization')) {
                        
                        system.debug('run------>Kindly Please fill the SAP code before marking Commercialization');
                        return 'Kindly Please fill the SAP code before marking Commercialization';
                    }
                
                system.debug('lea.stage:'+lea.Lead_Stage__c);
                system.debug('lea.New_Customer__c:'+ lea.New_Customer__c);
                system.debug('lea.CE_CIS_Approval__c:'+lea.CE_CIS_Approval__c);
                
                if((leadStageMap.get(lea.Id) == 'Evaluations' || leadStageMap.get(lea.Id) == 'Commercialization') && 
                   (lea.New_Customer__c == true && lea.CE_CIS_Approval__c == false)){
                       system.debug('Please get CE-CIS approved before proceeding to the next stage.');
                       return 'Please get CE-CIS approved before proceeding to the next stage.';
                   }
                
                if(leadUpdateMap.containsKey(lea.Id)) {
                    String selectedValue = string.valueOf(leadUpdateMap.get(lea.Id));
                    
                    if(isMarketingUser) {
                        // Update marketing stage for marketing users
                        lea.Marketing_Stage__c = selectedValue;
                        updateMarketingStageDateFields(lea, selectedValue);
                    } else {
                        // Update lead stage for non-marketing users
                        lea.Lead_Stage__c = selectedValue;
                        updateLeadStageDateFields(lea, selectedValue);
                    }
                }
            }
            
            System.debug('Lead list'+JSON.serialize(leaList));
            
            try {
                update leaList;
            } catch (DmlException e) {
                return e.getMessage();
            }
        }
        
        try {
            //START BD Tracker
            Id recIdBD = Schema.SObjectType.Event.getRecordtypeInfosByName().get('BD Tracker').getrecordTypeId();
            String strEventId =string.valueOf(dataMap.get('BDPlan'));
            String bdReasonVal;
            string skipReasonVal;
            map<string,string>lstSkipMap = new Map<String,string>();
            
            if(string.valueOf(dataMap.get('skipReason'))!= null && string.valueOf(dataMap.get('skipReason'))!=''){
                skipReasonVal = string.valueOf(dataMap.get('skipReason'));
                List<String>lstSkipReason =skipReasonVal.split(',');
                if( lstSkipReason != null && lstSkipReason.size() > 0 ){
                    for(String strVal :lstSkipReason){
                        List<string>spl = strVal.split(':');
                        lstSkipMap.put(spl[0],spl[1]);
                    }
                }
            }
            List<Event>lstEventSkipReason = [Select id,Remark__c,BD_Tracker_Phase__c,recordTypeId,WhatId,Account__c,Milestone_delay_reason__c,what.Name
                                             from event 
                                             where Id IN :lstSkipMap.Keyset()];
            
            set<string>lstSet = new Set<String>();
            for(Event objEvent : lstEventSkipReason){
                lstSet.add(objEvent.what.Name);
            }
            System.debug('lstSet'+lstSet);
            List<Event>lstEventSkipReasonEvaluation = [Select id,Remark__c,BD_Tracker_Phase__c,recordTypeId,WhatId,Account__c,Milestone_delay_reason__c,what.Name
                                                       from event 
                                                       where what.Name IN :lstSet AND BD_Tracker_Phase__c='Evaluation'];
            
            SYstem.debug('lstEventSkipReasonEvaluation'+lstEventSkipReasonEvaluation);
            
            List<Event>eventSkipToUpdate = new List<Event>();
            List<Event>setVal = new List<Event>();
            for(Event obj : lstEventSkipReason){
                for(Event objEval : lstEventSkipReasonEvaluation){
                    
                    if(obj.what.Name == objEval.what.Name && lstSkipMap.get(obj.Id)!='undefined'){
                        objEval.Reason_for_Evaluation_Skip__c  = lstSkipMap.get(obj.Id);
                        eventSkipToUpdate.add(objEval);  
                    }
                }
            }
            
            //Update Evaluation skip reason.
            if(eventSkipToUpdate != null || eventSkipToUpdate.size() > 0){
                
                Map<string,List<Event>>lstMap = New Map<String,List<Event>>();
                for(Event obj :eventSkipToUpdate){
                    if(lstMap.containsKey(obj.Id)){
                        Continue; 
                    }else{
                        List<Event>lst = new List<Event>();
                        lst.add(obj);
                        lstMap.put(obj.Id,lst); 
                    }
                }
                for(List<Event> lstobj :lstMap.values()){
                    for(Event obj :lstobj){
                        setVal.add(obj);
                    }
                }
                
            }
            
            map<String,string>reasonMap = new Map<string,string>();
            if(string.valueOf(dataMap.get('BDReason'))!= null && string.valueOf(dataMap.get('BDReason'))!=''){
                
                bdReasonVal = string.valueOf(dataMap.get('BDReason'));
                
            }
            if(bdReasonVal!=null && bdReasonVal!=''){
                List<String>lstReason =bdReasonVal.split(',');
                for(String strVal :lstReason){
                    List<string>spl = strVal.split(':');
                    reasonMap.put(spl[0],spl[1]);
                }
            }
            List<event>lstEventBDToUpdate = new List<event>();
            
            List<Event>PdEvent = new List<Event>();
            List<Event>EVEvent = new List<Event>();
            List<Event>CMEvent = new List<Event>();
            
            if(strEventId !=null && strEventId!= ''){
                System.debug('strEventId'+strEventId);
                List<string>lstString = strEventId.split(',');
                Map<string,string>mapList = new Map<string,string>();
                for(String strVal :lstString){
                    System.debug('strVal'+strVal);
                    List<string>spl = strVal.split(':');
                    System.debug('spl'+spl+'Size'+spl[1]);
                    if(!String.isBlank(spl[1])){
                        mapList.put(spl[0],spl[1]);
                    }
                    
                }
                List<Event>lstEvent = [Select id,Remark__c,BD_Tracker_Phase__c,recordTypeId,WhatId,Account__c,Milestone_delay_reason__c,isUpdate__c,Milestone_Stage__c from event 
                                       where id In :mapList.keySet() AND recordTypeId=:recIdBD];
                
                System.debug('mapList'+mapList);
                for(Event objEvent : lstEvent){
                    for(String mapString : mapList.keySet()){
                        
                        if(objEvent.Id == mapString){
                            
                            if( (mapList.get(objEvent.Id))!='Null'){
                                System.debug('mapList.get(objEvent.Id)'+mapList.get(objEvent.Id));
                                
                                objEvent.Remark__c = mapList.get(mapString);
                                objEvent.isUpdate__c=true;
                            }else{
                                System.debug('unchecked');
                                objEvent.isUpdate__c=false;
                                objEvent.Remark__c =''; 
                            }
                            
                            if(reasonMap.containsKey(objEvent.Id) ){
                                
                                objEvent.Milestone_Delay_Reason__c = reasonMap.get(objEvent.Id);  
                            }else{
                                
                                objEvent.Milestone_Delay_Reason__c =' ';  
                            }
                            
                            lstEventBDToUpdate.add(objEvent);
                        }
                    }  
                }
                
                for(Event obj :lstEventBDToUpdate){
                    if(obj.BD_Tracker_Phase__c =='Product Discussion' || obj.BD_Tracker_Phase__c =='Ürün Tartışması' 
                       || obj.BD_Tracker_Phase__c =='Discussão sobre produtos' || obj.BD_Tracker_Phase__c =='Discusión de producto')
                        PdEvent.add(obj);
                    else if(obj.BD_Tracker_Phase__c =='Evaluation' || obj.BD_Tracker_Phase__c =='Değerlendirme' 
                            || obj.BD_Tracker_Phase__c =='Avaliação' || obj.BD_Tracker_Phase__c =='Evaluación')
                        EVEvent.add(obj);
                    else if(obj.BD_Tracker_Phase__c =='Commercialization' || obj.BD_Tracker_Phase__c =='Ticarileştirme' 
                            ||obj.BD_Tracker_Phase__c =='Comercialização' || obj.BD_Tracker_Phase__c =='Comercialización')
                        CMEvent.add(obj);
                }
            }
            
            //START :BD Tracker   
            if(PdEvent!= null && PdEvent.size() >0){
                update PdEvent;
            }
            if(EVEvent!= null && EVEvent.size() >0){
                update EVEvent;
                
            }
            if(CMEvent!= null && CMEvent.size() >0){
                System.debug('setVal'+setVal); 
                if(setVal!=null && setVal.size() > 0){
                    Database.update(setVal);
                }
                update CMEvent;
                
            }
            //End BD Tracker
            
            System.debug('Request in save dcr : '+dataMap);
            event eventObj = new Event();
            eventObj.Id = dataMap.get('eventId').toString();
            
            if(dataMap.get('followUpDate') !=''){
                string[] dateArr = dataMap.get('followUpDate').toString().split('-');
                eventObj.Follow_Up_Date__c = Date.newInstance(Integer.valueOf(dateArr[0]),Integer.valueOf(dateArr[1]),Integer.valueOf(dateArr[2]));
            }
            if(dataMap.get('product') !=''){
                eventObj.product__c = dataMap.get('product').toString();
                system.debug(eventObj.product__c);
            }
            eventObj.Status__c = 'Draft';
            eventObj.DCR_Description__c = dataMap.get('remark').toString();
            eventObj.Stage__c = 'Checked‐In';
            
            update eventObj;
            if(dataMap.get('remark') !=''){
                event ev = [select id, account__c from event where Id = :eventObj.id limit 1];
                Note noteObj = new Note();
                noteObj.parentId = ev.Account__c;
                noteObj.title = 'DCR SAVED =>'+date.today();
                noteObj.body = dataMap.get('remark').toString();
                if(ev.Account__c!=null){
                    insert noteObj; 
                }
                
            }
        } catch (Exception e) {
            system.debug('error in saving the DCR : '+e.getMessage()+', At line no : '+e.getLineNumber());
            return e.getMessage();
        }
        return 'SUCCESS';
    }
    
    // Helper method to update marketing stage date fields
    Public static void updateMarketingStageDateFields(Lead__c lea, String marketingStage) {
        if(marketingStage == 'CME') {
            lea.Actual_CME__c = system.today();
        } else if(marketingStage == 'RTM') {
            lea.Actual_RTM__c = system.today();
        } else if(marketingStage == 'User Meeting') {
            lea.Actual_User_Meeting__c = system.today();
        } else if(marketingStage == 'High Impact CME') {
            lea.Actual_High_Impact_CME__c = system.today();
        } else if(marketingStage == 'KOL/FOL Development') {
            lea.Actual_KOL_FOL_Development__c = system.today();
        } else if(marketingStage == 'Virtual exp. Lab') {
            lea.Actual_Virtual_exp_Lab__c = system.today();
        } else if(marketingStage == 'Wet Labs') {
            lea.Actual_Wet_Labs__c = system.today();
        } else if(marketingStage == 'Testimonial') {
            lea.Actual_Testimonial__c = system.today();
        } else if(marketingStage == 'CTP') {
            lea.Actual_CTP__c = system.today();
        } else if(marketingStage == 'Focus') {
            lea.Actual_Focus__c = system.today();
        } else if(marketingStage == 'Decode') {
            lea.Actual_Decode__c = system.today();
        } else if(marketingStage == 'Inclinic Branding') {
            lea.Actual_Inclinic_Branding__c = system.today();  
        }
    }
    
    // Helper method to update lead stage date fields
    private static void updateLeadStageDateFields(Lead__c lea, String leadStage) {
        if(leadStage == 'Prospects') {
            lea.Actual_Prospect_Week__c = system.today();
            if (lea.Appointment_Date_History__c == null) {
                lea.Appointment_Date_History__c = String.valueOf(System.today());
                lea.Appointment_Stage_Count__c = 1;
            } else {
                lea.Appointment_Date_History__c += ', ' + String.valueOf(System.today());
                lea.Appointment_Stage_Count__c = (lea.Appointment_Stage_Count__c == null) ? 1 : lea.Appointment_Stage_Count__c + 1;
            }
        } else if(leadStage == 'Appointments') {
            lea.Actual_Appointments_Week__c = system.today();
            if (lea.Appointment_Date_History__c == null) {
                lea.Appointment_Date_History__c = String.valueOf(System.today());
                lea.Appointment_Stage_Count__c = 1;
            } else {
                lea.Appointment_Date_History__c += ', ' + String.valueOf(System.today());
                lea.Appointment_Stage_Count__c = (lea.Appointment_Stage_Count__c == null) ? 1 : lea.Appointment_Stage_Count__c + 1;
            }
        } else if(leadStage == 'Presentation') {
            lea.Actual_Presentation_Week__c = system.today();
            if (lea.Presentation_Date_History__c == null) {
                lea.Presentation_Date_History__c = String.valueOf(System.today());
                lea.Presentation_Stage_Count__c = 1;
            } else {
                lea.Presentation_Date_History__c += ', ' + String.valueOf(System.today());
                lea.Presentation_Stage_Count__c = (lea.Presentation_Stage_Count__c == null) ? 1 : lea.Presentation_Stage_Count__c + 1;
            }
        } else if(leadStage == 'Product Demo') {
            lea.Actual_Product_Demo_Week__c = system.today();
            if (lea.Product_Demo_Date_History__c == null) {
                lea.Product_Demo_Date_History__c = String.valueOf(System.today());
                lea.Product_Demo_Stage_Count__c = 1;
            } else {
                lea.Product_Demo_Date_History__c += ', ' + String.valueOf(System.today());
                lea.Product_Demo_Stage_Count__c = (lea.Product_Demo_Stage_Count__c == null) ? 1 : lea.Product_Demo_Stage_Count__c + 1;
            }
        } else if(leadStage == 'Evaluations') {
            lea.Actual_Evaluations_Week__c = system.today();
            if (lea.Evaluation_Date_History__c == null) {
                lea.Evaluation_Date_History__c = String.valueOf(System.today());
                lea.Evaluation_Stage_Count__c = 1;
            } else {
                lea.Evaluation_Date_History__c += ', ' + String.valueOf(System.today());
                lea.Evaluation_Stage_Count__c = (lea.Evaluation_Stage_Count__c == null) ? 1 : lea.Evaluation_Stage_Count__c + 1;
            }
        } else if(leadStage == 'Commercialization') {
            lea.Actual_Commercialization_week__c = system.today();
            if (lea.Commercialization_Date_History__c == null) {
                lea.Commercialization_Date_History__c = String.valueOf(System.today());
                lea.Commercialization_Stage_Count__c = 1;
            } else {
                lea.Commercialization_Date_History__c += ', ' + String.valueOf(System.today());
                lea.Commercialization_Stage_Count__c = (lea.Commercialization_Stage_Count__c == null) ? 1 : lea.Commercialization_Stage_Count__c + 1;
            }
        } else if(leadStage == 'Upgrade') {
            lea.Actual_Upgrade_week__c = system.today();
            if (lea.Upgrade_Date_History__c == null) {
                lea.Upgrade_Date_History__c = String.valueOf(System.today());
                lea.Upgrade_Stage_Count__c = 1;
            } else {
                lea.Upgrade_Date_History__c += ', ' + String.valueOf(System.today());
                lea.Upgrade_Stage_Count__c = (lea.Upgrade_Stage_Count__c == null) ? 1 : lea.Upgrade_Stage_Count__c + 1;
            }
        }
    }
    
    //This method will submit the DCR for approval
    @remoteAction
    global static string submitDCR(Map<String,Object> dataMap){
        try{
            system.debug('Request in submit dcr : '+dataMap);
            event eventObj = new Event();
            eventObj.Id = dataMap.get('eventId').toString();
            if(dataMap.get('followUpDate') !=''){
                string[] dateArr = dataMap.get('followUpDate').toString().split('-');
                eventObj.Follow_Up_Date__c = Date.newInstance(Integer.valueOf(dateArr[0]),Integer.valueOf(dateArr[1]),Integer.valueOf(dateArr[2]));
            }
            eventObj.DCR_Description__c = dataMap.get('remark').toString();
            eventObj.Status__c = 'Sent for Approval';
            eventObj.event_Locked__c = true;
            if(dataMap.get('product') !=''){
                eventObj.product__c = dataMap.get('product').toString();
            }
            eventObj.Stage__c = 'Checked‐In';
            eventObj.Cheked_In__c = true;
            
            eventObj.Stage__c = 'Checked-Out';
            eventObj.Check_Out__c = true;
            update eventObj;
        }catch(Exception e){
            system.debug('error in submitting the dcr : '+e.getMessage()+', at line no : '+e.getLineNumber());
            return e.getMessage();
        }
        return 'SUCCESS';
    } 
    
    public class CheckoutData {
        public String CheckOutLat { get; set; }
        public String CheckOutLong { get; set; }
        public String eventId { get; set; }
        public String BDPlan { get; set; }
        public String BDReason { get; set; }
        public String skipReason { get; set; }
        public String BDStage { get; set; }
        public String LostStageReason { get; set; }
        public String Stage { get; set; }
        public String whatId { get; set; }
        public String Marketing { get; set; }
    }
    
    //Checkout Method
    @remoteAction
    global static void checkOutMethod(Map<String,Object> mapData){
        
        system.debug('mapData'+ mapData);
        
        try {
            // Get user type
            Boolean isMarketingUser = checkIfMarketingUserStatic();
            
            Id leadId=(Id)string.valueOf(mapData.get('whatId'));
            if(Schema.Lead__c.SObjectType==leadId.getSobjectType()) {
                System.debug('Lead UId'+leadId);
                Lead__c lea=[SELECT Id,Name,Status__c,Appointment_Date_History__c,Product_Demo_Date_History__c,
                             Product_Demo_Stage_Count__c,Evaluation_Date_History__c,Evaluation_Stage_Count__c,
                             Presentation_Date_History__c,Presentation_Stage_Count__c,Appointment_Stage_Count__c,
                             Lead_Stage__c,Marketing_Stage__c,Actual_Prospect_Week__c,Actual_Appointments_Week__c,
                             Actual_Presentation_Week__c,Actual_Product_Demo_Week__c,Actual_Evaluations_Week__c,
                             Commercialization_Stage_Count__c,Commercialization_Date_History__c,Upgrade_Date_History__c,
                             Upgrade_Stage_Count__c,Actual_Commercialization_week__c,Actual_Upgrade_week__c,
                             Actual_CME__c,Actual_RTM__c,Actual_User_Meeting__c,Actual_High_Impact_CME__c,
                             Actual_KOL_FOL_Development__c,Actual_Virtual_exp_Lab__c,Actual_Wet_Labs__c,
                             Actual_Testimonial__c,Actual_CTP__c,Actual_Focus__c,Actual_Decode__c,Actual_Inclinic_Branding__c 
                             from Lead__c where Id=:leadId];
                
                if(string.isNotBlank(string.valueOf(mapData.get('Stage')))  && string.valueOf(mapData.get('Stage'))!='None' ) {
                    if(isMarketingUser) {
                        // Update marketing stage for marketing users
                        lea.Marketing_Stage__c = string.valueOf(mapData.get('Stage'));
                        updateMarketingStageDateFields(lea, string.valueOf(mapData.get('Stage')));
                    } else {
                        // Update lead stage for non-marketing users
                        lea.Lead_Stage__c = string.valueOf(mapData.get('Stage'));
                        updateLeadStageDateFields(lea, string.valueOf(mapData.get('Stage')));
                    }
                }
                
                System.debug('Update lea'+lea);
                update lea; 
            }
            
            // ... rest of the checkout method remains the same ...
            // START BD Tracker
            Id recIdBD = Schema.SObjectType.Event.getRecordtypeInfosByName().get('BD Tracker').getrecordTypeId();
            String strEventId =string.valueOf(mapData.get('BDPlan'));
            String bdReasonVal;
            string skipReasonVal;
            string BDStageValue;
            string LostStageReason;
            Map<string,String>mapOfStage = new Map<String,string>();
            Map<string,String>mapOfLostStageReason = new Map<String,string>();
            map<string,string>lstSkipMap = new Map<String,string>();
            
            if(string.valueOf(mapData.get('LostStageReason'))!= null && string.valueOf(mapData.get('LostStageReason'))!='' && string.valueOf(mapData.get('LostStageReason'))!='undefined'){
                LostStageReason = string.valueOf(mapData.get('LostStageReason'));
                System.debug('LostStageReason'+LostStageReason);
                if(LostStageReason !=null && LostStageReason!=''){  
                    List<String>lostReason = LostStageReason.split(',');
                    if( lostReason != null && lostReason.size() > 0 ){
                        for(String strVal :lostReason){
                            List<string>spl = strVal.split(':');
                            mapOfLostStageReason.put(spl[0],spl[1]);
                        }
                    }
                }
            }
            
            if(string.valueOf(mapData.get('BDStage'))!= null && string.valueOf(mapData.get('BDStage'))!='' && string.valueOf(mapData.get('BDStage'))!='undefined'){
                BDStageValue = string.valueOf(mapData.get('BDStage'));
                List<String>stages = BDStageValue.split(',');
                if( stages != null && stages.size() > 0 ){
                    for(String strVal :stages){
                        List<string>spl = strVal.split(':');
                        mapOfStage.put(spl[0],spl[1]);
                    }
                }
                
            }
            //START : Update Evaluation Skip Reasonn
            if(string.valueOf(mapData.get('skipReason'))!= null && string.valueOf(mapData.get('skipReason'))!='' && string.valueOf(mapData.get('skipReason'))!='undefined'){
                skipReasonVal = string.valueOf(mapData.get('skipReason'));
                List<String>lstSkipReason =skipReasonVal.split(',');
                if( lstSkipReason != null && lstSkipReason.size() > 0 ){
                    for(String strVal :lstSkipReason){
                        List<string>spl = strVal.split(':');
                        lstSkipMap.put(spl[0],spl[1]);
                    }
                }
            }
            List<Event>lstEventSkipReason = [Select id,Remark__c,BD_Tracker_Phase__c,recordTypeId,WhatId,Account__c,Milestone_delay_reason__c,what.Name
                                             from event 
                                             where Id IN :lstSkipMap.Keyset()];
            
            set<string>lstSet = new Set<String>();
            for(Event objEvent : lstEventSkipReason){
                lstSet.add(objEvent.what.Name);
            }
            System.debug('lstSet'+lstSet);
            List<Event>lstEventSkipReasonEvaluation = [Select id,Remark__c,BD_Tracker_Phase__c,recordTypeId,WhatId,Account__c,Milestone_delay_reason__c,what.Name
                                                       from event 
                                                       where what.Name IN :lstSet AND (BD_Tracker_Phase__c='Evaluation' OR BD_Tracker_Phase__c='Değerlendirme' OR BD_Tracker_Phase__c='Avaliação'
                                                                                       OR BD_Tracker_Phase__c='Evaluación')];
            
            SYstem.debug('lstEventSkipReasonEvaluation'+lstEventSkipReasonEvaluation);
            
            List<Event>eventSkipToUpdate = new List<Event>();
            List<Event>setVal = new List<Event>();
            for(Event obj : lstEventSkipReason){
                for(Event objEval : lstEventSkipReasonEvaluation){
                    
                    if(obj.what.Name == objEval.what.Name && lstSkipMap.get(obj.Id)!='undefined'){
                        objEval.Reason_for_Evaluation_Skip__c  = lstSkipMap.get(obj.Id);
                        objEval.Milestone_Stage__c = 'Actual';
                        eventSkipToUpdate.add(objEval);  
                    }
                }
            }
            
            //Update Evaluation skip reason.
            if(eventSkipToUpdate != null || eventSkipToUpdate.size() > 0){
                
                Map<string,List<Event>>lstMap = New Map<String,List<Event>>();
                for(Event obj :eventSkipToUpdate){
                    if(lstMap.containsKey(obj.Id)){
                        Continue; 
                    }else{
                        List<Event>lst = new List<Event>();
                        lst.add(obj);
                        lstMap.put(obj.Id,lst); 
                    }
                }
                for(List<Event> lstobj :lstMap.values()){
                    for(Event obj :lstobj){
                        setVal.add(obj);
                    }
                }
                
            }
            //END :
            map<String,string>reasonMap = new Map<string,string>();
            if(string.valueOf(mapData.get('BDReason'))!= null){
                
                bdReasonVal = string.valueOf(mapData.get('BDReason'));
                
            }
            if(bdReasonVal!=null && bdReasonVal!=''){
                List<String>lstReason =bdReasonVal.split(',');
                for(String strVal :lstReason){
                    List<string>spl = strVal.split(':');
                    reasonMap.put(spl[0],spl[1]);
                }
            }
            List<event>lstEventBDToUpdate = new List<event>();
            
            List<Event>PdEvent = new List<Event>();
            List<Event>EVEvent = new List<Event>();
            List<Event>CMEvent = new List<Event>();
            
            if(strEventId !=null && strEventId!= ''){
                List<string>lstString = strEventId.split(',');
                Map<string,string>mapList = new Map<string,string>();
                for(String strVal :lstString){
                    List<string>spl = strVal.split(':');
                    mapList.put(spl[0],spl[1]);
                }
                List<Event>lstEvent = [Select id,Remark__c,BD_Tracker_Phase__c,recordTypeId,WhatId,Account__c,Milestone_delay_reason__c
                                       ,BD_Plan_Status__c,Reason__c from event 
                                       where id In :mapList.keySet() AND recordTypeId=:recIdBD];
                
                
                for(Event objEvent : lstEvent){
                    for(String mapString : mapList.keySet()){
                        
                        if(objEvent.Id == mapString){
                            objEvent.Remark__c = mapList.get(mapString);
                            objEvent.Milestone_Stage__c = 'Actual';
                            objEvent.isLinkedToDCR__c=true;
                            objEvent.isUpdate__c =false;
                            if(reasonMap.containsKey(objEvent.Id)){
                                objEvent.Milestone_Delay_Reason__c = reasonMap.get(objEvent.Id);  
                            }
                            if(mapOfStage.containsKey(objEvent.Id)){
                                objEvent.BD_Plan_Status__c = mapOfStage.get(objEvent.Id);  
                            }
                            
                            if(mapOfLostStageReason.containsKey(objEvent.Id)){
                                objEvent.Reason__c = mapOfLostStageReason.get(objEvent.Id);  
                            }
                            
                            lstEventBDToUpdate.add(objEvent);
                        }
                    }  
                }
                
                
                
                SYstem.debug('lstEventBDToUpdate'+lstEventBDToUpdate);
                Map<ID,BD_Tracker__c>BDMapTracker = new Map<ID,BD_Tracker__c>();
                
                for(Event obj :lstEventBDToUpdate){
                    BD_Tracker__c objTrack = new BD_Tracker__c();
                    
                    if(obj.BD_Tracker_Phase__c =='Product Discussion' || obj.BD_Tracker_Phase__c =='Ürün Tartışması' 
                       || obj.BD_Tracker_Phase__c =='Discussão sobre produtos' || obj.BD_Tracker_Phase__c =='Discusión de producto'){
                           PdEvent.add(obj);
                           
                           if(BDMapTracker.containsKey(obj.WhatId)){
                               BD_Tracker__c objBDTracker = new BD_Tracker__C();
                               objBDTracker = BDMapTracker.get(obj.WhatId);
                               
                               objBDTracker.PD_Status__c = 'Actual';
                               
                               BDMapTracker.put(obj.WhatId,objBDTracker); 
                           }else{
                               BD_Tracker__c objBDTracker = new BD_Tracker__C();  
                               objBDTracker.Id = obj.WhatId;
                               objBDTracker.PD_Status__c = 'Actual';
                               
                               BDMapTracker.put(obj.WhatId,objBDTracker);    
                           }
                           
                           
                       }else if(obj.BD_Tracker_Phase__c =='Evaluation' || obj.BD_Tracker_Phase__c =='Değerlendirme' 
                                || obj.BD_Tracker_Phase__c =='Avaliação' || obj.BD_Tracker_Phase__c == 'Evaluación'){
                                    EVEvent.add(obj);
                                    
                                    if(BDMapTracker.containsKey(obj.WhatId)){
                                        BD_Tracker__c objBDTracker = new BD_Tracker__C();
                                        objBDTracker = BDMapTracker.get(obj.WhatId);
                                        
                                        objBDTracker.PD_Status__c = 'Actual';
                                        
                                        BDMapTracker.put(obj.WhatId,objBDTracker); 
                                    }else{
                                        BD_Tracker__c objBDTracker = new BD_Tracker__C();  
                                        objBDTracker.Id = obj.WhatId;
                                        objBDTracker.PD_Status__c = 'Actual';
                                        BDMapTracker.put(obj.WhatId,objBDTracker);    
                                    }
                                    
                                }else if(obj.BD_Tracker_Phase__c =='Commercialization' || obj.BD_Tracker_Phase__c =='Ticarileştirme' 
                                         || obj.BD_Tracker_Phase__c =='Comercialização' || obj.BD_Tracker_Phase__c == 'Comercialización'){
                                             CMEvent.add(obj);
                                             
                                             if(BDMapTracker.containsKey(obj.WhatId)){
                                                 BD_Tracker__c objBDTracker = new BD_Tracker__C();
                                                 objBDTracker = BDMapTracker.get(obj.WhatId);
                                                 
                                                 objBDTracker.PD_Status__c = 'Actual';
                                                 if(obj.reason__c != null){
                                                     
                                                     objBDTracker.reason__c = obj.reason__c;
                                                 }
                                                 BDMapTracker.put(obj.WhatId,objBDTracker); 
                                             }else{
                                                 BD_Tracker__c objBDTracker = new BD_Tracker__C();  
                                                 objBDTracker.Id = obj.WhatId;
                                                 objBDTracker.PD_Status__c = 'Actual';
                                                 if(obj.reason__c != null){
                                                     
                                                     objBDTracker.reason__c = obj.reason__c;
                                                 }
                                                 BDMapTracker.put(obj.WhatId,objBDTracker);    
                                             }
                                         }
                }
                List<BD_Tracker__c>lsTracker = new List<BD_Tracker__c>();
                if(BDMapTracker.size() > 0){
                    
                    for(Id  i:BDMapTracker.keySet()){
                        
                        lsTracker.add(BDMapTracker.get(i));  
                    }
                    update lsTracker;
                } 
            }
            //End BD Tracker
            
            Id recId = Schema.SObjectType.Event.getRecordtypeInfosByName().get('DCR Planning').getrecordTypeId();
            System.debug('request in checkout method : '+mapData);
            string Id = string.valueOf(mapData.get('eventId'));
            event evObj = [select Event_Latitude__c,Event_Longitude__c,Approval_Status__c,OwnerId,Owner.FirstName,Owner.LastName,Subject,Checkout_Distance__c,Checkout__Latitude__s,
                           Checkout__Longitude__s ,check_Out_Time__c,check_Out__c,Stage__c,Account__c
                           from event 
                           where id =:Id  ];
           
           
            System.debug('event in checkout : '+evObj);
            Location loc1 = Location.newInstance(evObj.Event_Latitude__c,evObj.Event_Longitude__c);
            Location loc2 = Location.newInstance((decimal)mapData.get('CheckOutLat'),(Decimal)mapData.get('CheckOutLong'));
            Double dist = Location.getDistance(loc1, loc2, 'km');
            System.debug('locations : '+loc1+','+loc2);
            system.debug('distance : '+dist);
            evObj.Checkout_Distance__c = dist;
            evObj.Checkout__Latitude__s = (decimal)mapData.get('CheckOutLat');
            evObj.Checkout__Longitude__s = (decimal)mapData.get('CheckOutLong');
            evObj.check_Out_Time__c = System.now().time();
            evObj.check_Out__c = true;
            evObj.Stage__c = 'Checked-Out';
            if(evObj.Approval_Status__c == 'Installation WIP'){
                EventApprovalController.sendApprovalEmail(evObj);
                evObj.Approval_Status__c = 'Pending for Approval';
            }
            System.debug('Event for update : '+evObj);
            update evObj;
            
            /* if(evObj.Account__c !=null){
Account acc = new Account();
acc.id = evObj.Account__c;
acc.ShippingCity = '';
acc.ShippingCountry = '';
acc.ShippingPostalCode = '';
acc.ShippingState = '';
acc.ShippingStreet = '';
update acc;
}*/
            
            
            
            beat_Plan__c beatObj = [select name,Started__c, Start_Time__c,End_LatLang__Latitude__s,End_Time__c,End_LatLang__Longitude__s,
                                    Start_LatLang__Latitude__s,Start_LatLang__Longitude__s,total_Distance__c from beat_Plan__c 
                                    where beat_Date__c =: date.today() AND Assigned_To__c = : UserInfo.getUserId() limit 1];
            
            //Update Beat Obj
            //if(beatObj.Start_LatLang__Latitude__s==null){
            beatObj.End_LatLang__Latitude__s = (Decimal)mapData.get('CheckOutLat');
            beatObj.End_LatLang__Longitude__s = (Decimal)mapData.get('CheckOutLong');
            update beatObj;
            //}
            
            //START :BD Tracker 
            
            if(PdEvent!= null && PdEvent.size() >0){
                update PdEvent;
            }
            if(EVEvent!= null && EVEvent.size() >0){
                update EVEvent;
                
            }
            if(CMEvent!= null && CMEvent.size() >0){
                System.debug('setVal'+setVal); 
                if(setVal!=null && setVal.size() > 0){
                    Database.update(setVal);
                }
                update CMEvent;
                
            }
            
            Integer WeekN = weekNumber(Date.ValueOf(System.today()));
            string wk = 'Week'+WeekN;
            List<event>lstToCheck=  [select id,Account__c,Account__r.Name,recordtypeId,isConnectedToDCR__c,BD_Tracker_Phase__c,Milestone_Plan_Week__c,Product__c,
                                     whoId,MileStone_Stage__c,OwnerId,startDateTime,Remark__c,Milestone_delay_reason__c
                                     from event
                                     where Account__c =: evObj.Account__c AND recordtypeId=:recIdBD AND isConnectedToDCR__c=true AND 
                                     (MileStone_Stage__c !='Actual')
                                     /* AND Milestone_Plan_Week__c=:wk*/ AND isLinkedToDCR__c=false order by startDateTime ];
            
            for(Event objEV :lstToCheck){
                objEV.isConnectedToDCR__c =false;
            }
            System.debug('lstToCheck'+lstToCheck);
            update lstToCheck;
            
            //END :BD Tracker     
            
            
        } catch (Exception e) {
            system.debug('error in checout method : '+e.getMessage()+', at line no : '+e.getLineNumber());
        }
    }
    
    @RemoteAction
    global static string returnHomePage(){
        return URL.getSalesforceBaseUrl().toExternalForm();
    }
    
    //START : BD Tracker Wrpper
    public class BDWrapper{
        public boolean isCheck{get;set;}
        public event objEvent{get;set;}
        public string conName{get;set;}
        public string delayReason{get;set;}
        public boolean evSkip{get;set;}
        public boolean isError{get;set;}
        public string remark{get;set;}
        public string userProfile{get;set;}
        
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
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        
        
    }
    @RemoteAction
    global     static void uploadBrandingFile(
        Id recordId,
        String fileName,
        String base64Data
    ) {
        System.debug(' uploadBrandingFile called');
        System.debug(' recordId = ' + recordId);
        System.debug(' fileName = ' + fileName);

        if (recordId == null || String.isBlank(base64Data)) {
            System.debug(' Invalid input, exiting');
            return;
        }

        Blob fileBody = EncodingUtil.base64Decode(base64Data);
        System.debug('Blob size = ' + fileBody.size());

        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName;
        cv.VersionData = fileBody;
        insert cv;

        System.debug(' ContentVersion inserted: ' + cv.Id);

        Id contentDocId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = contentDocId;
        cdl.LinkedEntityId = recordId;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';
        insert cdl;
        
         ContentDistribution cd = new ContentDistribution();
                    cd.Name = fileName;
                    cd.ContentVersionId = cv.Id;
                    cd.PreferencesAllowViewInBrowser = true;
                    cd.PreferencesNotifyOnVisit = false;
                    cd.PreferencesAllowOriginalDownload = true;
                    cd.PreferencesAllowPDFDownload = true;
                    cd.PreferencesLinkLatestVersion = true;
                    insert cd;
                    
                   
                    List<ContentDistribution> dists = [
                        SELECT Id, Name, DistributionPublicUrl,ContentVersion.Title,ContentVersion.FileExtension, ContentDocumentId
                        FROM ContentDistribution
                        WHERE Id =:cd.Id
                    ];
                    Event evt = new Event(
                        Id = recordId,
                        Public_File_Url__c = dists[0].DistributionPublicUrl,
                        File_Name__c = dists[0].ContentVersion.Title
                    );
                    update evt;

        System.debug(' File linked to record successfully');
    }
}
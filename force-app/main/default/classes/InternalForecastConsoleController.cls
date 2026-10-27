/********************************************
* @Class Name   : InternalForecastConsoleController
* @Description  : It is used to implement the weekly forecast logic for internal forecast console.
* @Created Date : 15-06-2026
* @Created By   : Antigravity AI
* ****************************************/
public without sharing class InternalForecastConsoleController {
    public class RollingForecastWrapper{
        @AuraEnabled public Integer totalProducts {get; set;}
        @AuraEnabled public integer selMonth{get;set;}
        @AuraEnabled public string selMonthName{get;set;}
        @AuraEnabled public integer selYear{get;set;}
        @AuraEnabled public date startDate{get;set;}
        @AuraEnabled public date endDate{get;set;}
        @AuraEnabled public date fromDate{get;set;}
        @AuraEnabled public date toDate{get;set;}
        @AuraEnabled public date selDate{get;set;}
        @AuraEnabled public integer nextMonth{get;set;}
        @AuraEnabled public list<WeeklyProductWrapper> weeklyProductObj {get;set;}
    }
    
    public class WeeklyProductWrapper {
        @AuraEnabled public string productId{get;set;}
        @AuraEnabled public string agreementProductId{get;set;}
        @AuraEnabled public string productName{get;set;}
        @AuraEnabled public string region{get;set;}
        @AuraEnabled public Integer targetQty{get;set;}
        @AuraEnabled public Integer totalActualQty{get;set;}
        @AuraEnabled public Integer qtyGap{get;set;}
        @AuraEnabled public Decimal agreementValue{get;set;}
        @AuraEnabled public String currencyISOCode{get;set;}
        @AuraEnabled public String customerCode{get;set;}
        @AuraEnabled public list<MonthWiseWeeksWrapper> lstMonthWiseWeeks {get;set;}
        @AuraEnabled public boolean isDisabled{get;set;}
    }
    
    public class MonthWiseWeeksWrapper{
        @AuraEnabled public string monthYear{get;set;}
        @AuraEnabled public string agreementProdId{get;set;}
        @AuraEnabled public integer month{get;set;}
        @AuraEnabled public string monthName{get;set;}
        @AuraEnabled public string monthShortName{get;set;}
        @AuraEnabled public integer year{get;set;}
        @AuraEnabled public date startDate{get;set;}
        @AuraEnabled public date endDate{get;set;}
        @AuraEnabled public list<WeeklyForecastWrapper> weeklyForecastObj{get;set;}
        @AuraEnabled public string thCls{get;set;}
        @AuraEnabled public boolean isDisabled{get;set;}
        @AuraEnabled public integer totalForecast{get;set;}
        @AuraEnabled public integer totalMonthlyActualQty{get;set;}
        @AuraEnabled public integer totalWeeks{get;set;}
    }
    public class WeeklyForecastWrapper{
        @AuraEnabled public integer forecastQty {get;set;}
        @AuraEnabled public date startDate{get;set;}
        @AuraEnabled public date endDate{get;set;}
        @AuraEnabled public integer month{get;set;}
        @AuraEnabled public string monthName{get;set;}
        @AuraEnabled public integer year{get;set;}
        @AuraEnabled public string uniqueKey{get;set;}
        @AuraEnabled public integer weekNumber{get;set;}
        @AuraEnabled public boolean isDisabled{get;set;}
        @AuraEnabled public integer globalWeekCount{get;set;}
        @AuraEnabled public integer yearWeekCnt{get;set;}
    }    
    
    //Fetch user details
    @AuraEnabled
    public static User fetchUserDetails(){
        User usr;
        Id currentUserId = userinfo.getUserId();
        usr = [Select Id,Name, Profile.Id, Profile.Name,ContactId,IsPortalEnabled From User Where id =: currentUserId];
        return usr;
    }
    
    @AuraEnabled
    public static Map<String,String> fetchAccountDetails(Id contactId){
        Map<String,String> sapCodeAccNmMap = new Map<String,String>();
        Contact con = [Select Id,Name,Account.Name,Account.SAP_Code__c, Account.region__r.name From Contact Where Id =: contactId];
        
        List<Master_Agreement__c> agreementList = new List<Master_Agreement__c>();
        if(Test.isRunningTest()){
            agreementList = [select id,End_Year__c, Start_Year__c from Master_Agreement__c Where Account__r.SAP_Code__c=:con.Account.SAP_Code__c  AND Is_Active__c = true
                             ORDER BY Agreement_End_Date__c DESC 
                             LIMIT 1];
        }else{
            agreementList = [select id,End_Year__c, Start_Year__c from Master_Agreement__c where Agreement_Start_Date__c <= today and Agreement_End_Date__c >= today and Account__r.SAP_Code__c=:con.Account.SAP_Code__c  AND Is_Active__c = true
                             ORDER BY Agreement_End_Date__c DESC 
                             LIMIT 1];
        }
        
        Master_Agreement__c agreementObj = null;
        if (!agreementList.isEmpty()) {
            agreementObj = agreementList[0];
        } else {
            // Fallback: get the latest active master agreement even if expired or future
            List<Master_Agreement__c> fallbackList = [select id,End_Year__c, Start_Year__c from Master_Agreement__c where Account__r.SAP_Code__c=:con.Account.SAP_Code__c  AND Is_Active__c = true
                                                      ORDER BY Agreement_End_Date__c DESC 
                                                      LIMIT 1];
            if (!fallbackList.isEmpty()) {
                agreementObj = fallbackList[0];
            }
        }
        
        sapCodeAccNmMap.put(con.Account.SAP_Code__c, con.Account.Name);
        if (agreementObj != null) {
            sapCodeAccNmMap.put('agreementStartYear', String.valueOf(agreementObj.Start_Year__c));
            sapCodeAccNmMap.put('agreementEndYear', String.valueOf(agreementObj.End_Year__c));
        } else {
            Integer currentYear = Date.today().year();
            sapCodeAccNmMap.put('agreementStartYear', String.valueOf(currentYear - 2));
            sapCodeAccNmMap.put('agreementEndYear', String.valueOf(currentYear + 2));
        }
        return sapCodeAccNmMap;
    }
    
    public static String GetMonthName(Integer month){
        String monthName = '';
        Switch on month{
            When 1{
                return System.Label.January;
            }
            When 2{
                return System.Label.February;
            }
            When 3{
                return System.Label.March;
            }
            When 4{
                return System.Label.April;
            }
            When 5{
                return System.Label.May;
            }
            When 6{
                return System.Label.June;
            }
            When 7{
                return System.Label.July;
            }
            When 8{
                return System.Label.August;
            }
            When 9{
                return System.Label.September;
            }
            When 10{
                return System.Label.October;
            }
            When 11{
                return System.Label.November;
            }
            When 12{
                return System.Label.December;
            }
        }
        return monthName;
    }
    
    //Create parent forecast warpper object
    @AuraEnabled
    public static RollingForecastWrapper getWeeklyForecastDetails(Integer fromselectedYear,String selectedCustomerCode,
                                                                  Integer fromselectedMonth,Integer page, Integer pageSize,Integer toselectedYear,Integer toselectedMonth){                                                             
                                                                      String selectedMonthName;
                                                                      String fromselectedMonthName;
                                                                      String toselectedMonthName;
                                                                      Integer nextMonth;
                                                                      date selectedDate,startDt,endDt,fromselectedDate,toselectedDate;       
                                                                      
                                                                      system.debug('BG 1 >>> fromselectedMonth'+ fromselectedMonth);
                                                                      system.debug('BG 1 >>> fromselectedYear'+ fromselectedYear);
                                                                      system.debug('BG 1 >>> toselectedYear'+ toselectedYear);
                                                                      system.debug('BG 1 >>> toselectedMonth'+ toselectedMonth);
                                                                      selectedMonthName = InternalForecastConsoleController.GetMonthName(fromselectedMonth);                                                                
                                                                      selectedDate = date.newInstance(fromselectedYear, fromselectedMonth, 1);        
                                                                      fromselectedMonthName = InternalForecastConsoleController.GetMonthName(fromselectedMonth);                                                                
                                                                      fromselectedDate = date.newInstance(fromselectedYear, fromselectedMonth, 1);
                                                                      toselectedMonthName = InternalForecastConsoleController.GetMonthName(toselectedMonth);                                                                
                                                                      toselectedDate = date.newInstance(toselectedYear, toselectedMonth, 1);
                                                                      nextMonth = 12;    
                                                                      
                                                                      startDt = selectedDate;
                                                                      system.debug('BG 1 >>> startDt'+ startDt);
                                                                      
                                                                      endDt = selectedDate.addMonths(nextMonth);
                                                                      system.debug('BG 1 >>> endDt' + endDt);
                                                                      
                                                                      RollingForecastWrapper rollingForecastObj = new RollingForecastWrapper();
                                                                      rollingForecastObj.selMonth = fromselectedMonth;
                                                                      rollingForecastObj.selYear = fromselectedYear;
                                                                      rollingForecastObj.startDate = startDt;
                                                                      rollingForecastObj.endDate = endDt;
                                                                      rollingForecastObj.fromDate = fromselectedDate;
                                                                      rollingForecastObj.toDate = toselectedDate;
                                                                      rollingForecastObj.selMonthName = selectedMonthName;
                                                                      rollingForecastObj.nextMonth = nextMonth;
                                                                      rollingForecastObj.selDate = selectedDate;
                                                                      rollingForecastObj = updateRollingForecastWrapper(rollingForecastObj,selectedCustomerCode,page,pageSize);
                                                                      
                                                                      return rollingForecastObj;
                                                                  }
    
    //Update parent forecast warpper object with all child wrapper classes
    @AuraEnabled
    public static RollingForecastWrapper updateRollingForecastWrapper(RollingForecastWrapper rollingForecastObj, String selectedCustomerCode, Integer page, Integer pageSize){
        WeeklyProductWrapper productWrapperObj = new WeeklyProductWrapper();
        list<WeeklyProductWrapper> lstProductWrapperObj = new list<WeeklyProductWrapper>();
        WeeklyForecastWrapper weeklyForecastObj = new WeeklyForecastWrapper();
        Set<Id> prodId = new set<Id>();
        Set<Id> agrrementProdIsSet = new set<Id>();
        Set<Id> prodIdSt = new set<Id>();
        Set<Date> dateSt = new Set<Date>();
        map<String,String> userForecastHistoryMap = new map<String,String>();      
        Date selectedDate = rollingForecastObj.selDate;
        Date DateAftrFourMonths = selectedDate.addMonths(3);
        Date nextMonth = selectedDate.addMonths(1);
        Integer selectedYear = selectedDate.year(); 
        
        Id currentUserId = UserInfo.getUserId();
        date yrStartDate = date.newInstance(rollingForecastObj.fromDate.year(),1,1);
        date yrEndDate = date.newInstance(rollingForecastObj.toDate.year(),12,31);                                                    
        map<date, integer> mapDate_WeekNumber = getYearwiseWeeks(yrStartDate, yrEndDate);
        Date fromDate = rollingForecastObj.fromDate;
        Date toDate = rollingForecastObj.toDate;
        System.debug('DV >>> rollingForecastObj:'+rollingForecastObj);
        
        Integer skipRecords = 0;                                                   
        page = Integer.valueOf(page);
        pageSize = Integer.valueOf(pageSize);
        if(page > 1){
            skipRecords = (page - 1 ) * pageSize ;
        } 
        
        // fetch all th ap
        Map<String, Decimal> ProductToPriceMap = new Map<String, Decimal>();
        
        List<Agreement_Product__c> apList1 = [Select Id,Agreement_Value__c,Product__r.Name, Price__c from Agreement_Product__c 
                                              Where Master_Agreement__r.Account__r.SAP_Code__c  =:selectedCustomerCode 
                                              AND Master_Agreement__r.Is_Active__c = true
                                              And ((Master_Agreement__r.Agreement_Start_Date__c <=:fromDate 
                                                    And Master_Agreement__r.Agreement_End_Date__c >=: toDate ) 
                                                   OR (Master_Agreement__r.Agreement_End_Date__c >=: fromDate 
                                                       AND Master_Agreement__r.Agreement_Start_Date__c <=:toDate))
                                              Order By Product__r.Dummy_Product_Description__c];
        Set<Id> apIdSet = new Set<Id>();
        Map<String, Id> apNametoIdMap = new Map<String, Id>();
        for(Agreement_Product__c agreementProd : apList1){
            if(ProductToPriceMap.containsKey(agreementProd.Product__r.Name) && ProductToPriceMap.get(agreementProd.Product__r.Name) < agreementProd.Price__c) {
                ProductToPriceMap.put(agreementProd.Product__r.Name, agreementProd.Price__c);
                apNametoIdMap.put(agreementProd.Product__r.Name, agreementProd.Id);                
            } else if(!ProductToPriceMap.containsKey(agreementProd.Product__r.Name)) {
                ProductToPriceMap.put(agreementProd.Product__r.Name, agreementProd.Price__c);
                apNametoIdMap.put(agreementProd.Product__r.Name, agreementProd.Id);                
            }                   
        }
        apIdSet.addAll(apNametoIdMap.values());
        
        // fetch related ap targets limit and offset
        List<Agreement_Product_Target__c> aggProdtargetLst = [select id ,Target_Qty__c,Start_Date__c,End_Date__c,Agreement_Product__c,Agreement_Product__r.Product__c,Agreement_Product__r.Product__r.Dummy_Product_Description__c,
                                                              Agreement_Product__r.Master_Agreement__r.Agreement_Start_Date__c,Agreement_Product__r.Master_Agreement__r.Agreement_End_Date__c
                                                              from Agreement_Product_Target__c
                                                              Where Start_Date__c <= :rollingForecastObj.fromDate And End_Date__c >=: rollingForecastObj.toDate and Agreement_Product__c IN : apIdSet
                                                              order by Agreement_Product__r.Product__r.Dummy_Product_Description__c ASC
                                                              LIMIT :pageSize
                                                              OFFSET :skipRecords
                                                             ];
        System.debug('DV >> aggProdtargetLst'+aggProdtargetLst);
        Set<ID> paginationAPIDSet = new Set<Id>();
        Map<Id,date> prodStDate = new Map<Id,date>();
        Map<Id,date> prodEndDate = new Map<Id,date>();
        Map<Id, Agreement_Product_Target__c> prodQty_Map = new Map<Id, Agreement_Product_Target__c>();
        for(Agreement_Product_Target__c target : aggProdtargetLst){
            prodQty_Map.put(target.Agreement_Product__r.Product__c, target);
            prodStDate.put(target.Agreement_Product__r.Product__c,target.Agreement_Product__r.Master_Agreement__r.Agreement_Start_Date__c);
            prodEndDate.put(target.Agreement_Product__r.Product__c,target.Agreement_Product__r.Master_Agreement__r.Agreement_End_Date__c);
        }
        
        String query = 'Select Id,Agreement_Value__c,Price__c,Product__c,Product__r.Dummy_Product_Code__c,Product__r.Dummy_Product_Description__c,Target_Qty__c,'
            + ' currencyISOCode,Master_Agreement__r.Account__r.SAP_Code__c,Master_Agreement__r.Agreement_End_Date__c,Master_Agreement__r.Agreement_Start_Date__c'
            + ' From Agreement_Product__c Where Id IN :apIdSet AND '
            + 'Master_Agreement__r.Is_Active__c = true AND'
            + ' Master_Agreement__r.Account__r.SAP_Code__c  =: selectedCustomerCode And ((Master_Agreement__r.Agreement_Start_Date__c <=:fromDate'
            + ' And Master_Agreement__r.Agreement_End_Date__c >=: toDate ) OR '
            + '(Master_Agreement__r.Agreement_End_Date__c >=: fromDate AND Master_Agreement__r.Agreement_Start_Date__c <=:toDate))'
            + ' Order By Product__r.Dummy_Product_Description__c';          
        query += ' LIMIT '+ pageSize;            
        query += ' OFFSET '+ skipRecords;    
        system.debug('BG >>> query : '+query);                                                  
        List<Agreement_Product__c> agreementProdLst = (List<Agreement_Product__c>) Database.query(query);
        system.debug('agreementProdLst**'+agreementProdLst); 
        if(agreementProdLst == null){
            system.debug('list is null. Records not found in db');
            return null;
        }
        system.debug('prod lst'+agreementProdLst.size());
        if(!agreementProdLst.isEmpty()){
            for(Agreement_Product__c agreementProd : agreementProdLst){
                prodId.add(agreementProd.Id);
                prodIdSt.add(agreementProd.Product__c);
            }
        }
        system.debug('prodId'+prodId);
        
        Map<Id, Decimal> productActualQty_Map = new Map<Id,Decimal>();
        Map<Id,Map<Integer,Decimal>> monthWiseProductActualQty_Map = new Map<Id,Map<Integer,Decimal>>();
        
        List<MonthWiseWeeksWrapper> monthWiseWeeksWrapper_Lst = new List<MonthWiseWeeksWrapper>();
        Map<String, List<MonthWiseWeeksWrapper>> prodCodeMonthWiseWrapper_Map = new Map<String, List<MonthWiseWeeksWrapper>>();
        
        for(Agreement_Product__c agreementProductObj : agreementProdLst){
            system.debug('BG >>> for');
            if(prodCodeMonthWiseWrapper_Map.containsKey(agreementProductObj.Product__r.Dummy_Product_Code__c)){
                system.debug('BG >>> if');
                monthWiseWeeksWrapper_Lst = prodCodeMonthWiseWrapper_Map.get(agreementProductObj.Product__r.Dummy_Product_Code__c);
                InternalForecastConsoleController.updateMonhwiseWeekWrapper(monthWiseWeeksWrapper_Lst, agreementProductObj);
            }
            else{
                system.debug('BG >>> else');
                productWrapperObj = new WeeklyProductWrapper();
                productWrapperObj.productName = agreementProductObj.Product__r.Dummy_Product_Description__c;
                productWrapperObj.agreementProductId = agreementProductObj.Id;
                if(prodQty_Map.containsKey(agreementProductObj.Product__c)){
                    productWrapperObj.targetQty = Integer.valueOf(prodQty_Map.get(agreementProductObj.Product__c).Target_Qty__c);
                }
                else {
                    productWrapperObj.targetQty = 0;
                }
                productWrapperObj.agreementValue = agreementProductObj.Agreement_Value__c;
                productWrapperObj.currencyISOCode  = agreementProductObj.currencyISOCode;
                productWrapperObj.customerCode = agreementProductObj.Master_Agreement__r.Account__r.SAP_Code__c;
                productWrapperObj.lstMonthWiseWeeks = InternalForecastConsoleController.getWeekWiseDetails(rollingForecastObj.fromDate,agreementProductObj,
                                                                                                           rollingForecastObj.toDate,mapDate_WeekNumber, 
                                                                                                           rollingForecastObj.selDate, selectedCustomerCode,
                                                                                                           monthWiseProductActualQty_Map);
                prodCodeMonthWiseWrapper_Map.put(agreementProductObj.Product__r.Dummy_Product_Code__c,productWrapperObj.lstMonthWiseWeeks);
                lstProductWrapperObj.add(productWrapperObj);
            }
        }
        system.debug('lstProductWrapperObj------'+lstProductWrapperObj);
        rollingForecastObj.weeklyProductObj = lstProductWrapperObj;
        
        List<Partner_Rolling_Forecast__c> partnerWeeklyForecastRecords = [Select Id,Name,Forecast_Qty__c,Month__c,Month_Name__c,Agreement_Product__c,Region__c,Account__c,
                                                                          Year__c,Week_End_Date__c,Week_Start_Date__c,Week_Number__c,Account__r.SAP_Code__c, 
                                                                          Unique_Key__c,Region__r.Region_Code__c From Partner_Rolling_Forecast__c
                                                                          Where Agreement_Product__c IN : prodId And Account__r.SAP_Code__c =: selectedCustomerCode];
        system.debug('partnerWeeklyForecastRecords**'+partnerWeeklyForecastRecords);
        if(partnerWeeklyForecastRecords.size() == 0){
            system.debug('list is null records not found in db');
            return rollingForecastObj;
        }
        
        if(!partnerWeeklyForecastRecords.isEmpty()){
            for(Partner_Rolling_Forecast__c weeklyForecastRec : partnerWeeklyForecastRecords){
                for(WeeklyProductWrapper forcastObj : rollingForecastObj.weeklyProductObj){
                    for(MonthWiseWeeksWrapper monthWiseWeek : forcastObj.lstMonthWiseWeeks){                                                
                        for(WeeklyForecastWrapper weeklyForecast :  monthWiseWeek.weeklyForecastObj){
                            if(weeklyForecast.year == weeklyForecastRec.Year__c && weeklyForecast.month ==  weeklyForecastRec.Month__c && 
                               weeklyForecast.yearWeekCnt == weeklyForecastRec.Week_Number__c && monthWiseWeek.agreementProdId == weeklyForecastRec.Agreement_Product__c &&
                               forcastObj.customerCode == weeklyForecastRec.Account__r.SAP_Code__c){                                 
                                   weeklyForecast.forecastQty = integer.valueOf(weeklyForecastRec.Forecast_Qty__c);  
                                   monthWiseWeek.totalForecast += integer.valueOf(weeklyForecastRec.Forecast_Qty__c);  
                               }
                        }
                    }
                }
            }
        }
        system.debug('full wrapper'+json.serialize(rollingForecastObj));
        return rollingForecastObj;                                                          
    }
    
    //Get weekwise details
    public static List<MonthWiseWeeksWrapper> getWeekWiseDetails(Date startDate, Agreement_Product__c agreementProd, Date endDate, Map<Date,Integer> mapDate_WeekNumber,Date selectedDate, String selectedCustomerCode, Map<Id,Map<Integer,Decimal>> monthWiseProductActualQty_Map){
        List<MonthWiseWeeksWrapper> lstMonthWiseWeekObj = new List<MonthWiseWeeksWrapper>();
        MonthWiseWeeksWrapper monthWiseWeekObj = new MonthWiseWeeksWrapper();
        List<WeeklyForecastWrapper> lstWeeklyForecastObj = new list<WeeklyForecastWrapper>();
        WeeklyForecastWrapper weeklyForecastObj = new WeeklyForecastWrapper();
        Date monthStartDt , monthEndDt, weekStDt, weekEndDt, monthStartDate;
        Datetime weekStDateTime,monthStartDateTime;
        Integer weekCnt =1, yearlyWeekCnt = 1;
        Date today =system.today();
        Integer currentMonth = today.month();
        Integer currentYear = today.year();
        Integer selectedYear = selectedDate.year();
        Integer selectedMonth = selectedDate.month();
        monthStartDt = date.newinstance(selectedYear, selectedMonth, 1);                                                        
        Integer globalWeekCount = 0,totalForecast = 0;
        Boolean hasOverridePermission = FeatureManagement.checkPermission('Edit_Forecast_Override');
        system.debug('BG >>> endDate : '+endDate);
        system.debug('BG >>> startDate : '+startDate);
        Integer monthCount = startDate.monthsBetween(endDate);
        system.debug('BG >>> monthCount : '+monthCount);
        monthCount = String.valueOf(monthCount).startsWith('-') ? Integer.ValueOf(String.valueOf(monthCount).remove('-')) : monthCount;
        if (endDate.day() > startDate.day()) {
            monthCount++;
        }           
        
        for(integer i=0; i<=monthCount; i++){
            totalForecast = 0;
            selectedYear = monthStartDt.year();
            selectedMonth = monthStartDt.month();
            monthStartDateTime = dateTime.newInstance(monthStartDt.year(), monthStartDt.month(), 1);
            monthStartDate = date.newinstance(monthStartDateTime.year(), monthStartDateTime.month(), monthStartDateTime.day());
            monthEndDt = monthStartDt.addMonths(1).addDays(-1);            
            weekStDt = monthStartDt;
            weekCnt = 1;
            weekEndDt = weekStDt.addDays(7);
            
            monthWiseWeekObj = new MonthWiseWeeksWrapper();            
            monthWiseWeekObj.month = selectedMonth;
            monthWiseWeekObj.monthName = InternalForecastConsoleController.GetMonthName(selectedMonth);
            monthWiseWeekObj.monthShortName = monthWiseWeekObj.monthName.substring(0,3);
            monthWiseWeekObj.year = selectedYear;
            monthWiseWeekObj.monthYear = string.valueOf(selectedMonth) + string.valueOf(selectedYear);
            monthWiseWeekObj.startDate = monthStartDateTime.date();
            monthWiseWeekObj.endDate = monthStartDateTime.date().addMonths(1).addDays(-1);
            monthWiseWeekObj.agreementProdId = agreementProd.Id;
            if(monthWiseProductActualQty_Map.containsKey(agreementProd.Product__c)){
                monthWiseWeekObj.totalMonthlyActualQty = Integer.valueOf(monthWiseProductActualQty_Map.get(agreementProd.Product__c).get(selectedMonth));          
            }
            
            if(monthStartDate < today && !hasOverridePermission){
                monthWiseWeekObj.isDisabled = true; 
            }
            else if(agreementProd.Master_Agreement__r.Agreement_End_Date__c >= monthWiseWeekObj.endDate && 
                    agreementProd.Master_Agreement__r.Agreement_Start_Date__c <= monthWiseWeekObj.startDate){
                        system.debug('in iff');
                        monthWiseWeekObj.isDisabled = false; 
                    }
            else{
                system.debug('in eee');
                monthWiseWeekObj.isDisabled = true; 
            }
            if(weekStDt.month()==1){                
                boolean is53Week = false;
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
                
                if(weekStDateTime.format('EEEE') != 'Monday' ) {
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
            }
            
            lstWeeklyForecastObj = new list<WeeklyForecastWrapper>();
            while(weekStDt<=monthEndDt){
                weeklyForecastObj = new WeeklyForecastWrapper();
                weekStDateTime = date.newInstance(weekStDt.year(), weekStDt.month(), weekStDt.day());
                if(weekStDateTime.format('EEEE') != 'Monday') {
                    while(weekStDateTime.format('EEEE') != 'Monday') {
                        weekStDt = weekStDt.addDays(1);
                        weekStDateTime = date.newInstance(weekStDt.year(), weekStDt.month(), weekStDt.day());
                    }
                }
                weekEndDt = weekStDt.addDays(6);
                weeklyForecastObj.startDate = weekStDt;
                weeklyForecastObj.endDate = weekEndDt;
                weeklyForecastObj.weekNumber = weekCnt;
                weeklyForecastObj.month = monthWiseWeekObj.month;
                weeklyForecastObj.monthName = monthWiseWeekObj.monthName;
                weeklyForecastObj.year = monthWiseWeekObj.year;
                
                if(mapDate_WeekNumber.containsKey(weeklyForecastObj.startDate)){
                    weeklyForecastObj.yearWeekCnt = mapDate_WeekNumber.get(weeklyForecastObj.startDate);
                }
                
                weeklyForecastObj.globalWeekCount = globalWeekCount;                               
                weeklyForecastObj.uniqueKey = agreementProd.Id+'_'+selectedCustomerCode+'_'+monthWiseWeekObj.year+'_'+monthWiseWeekObj.month+'_'+weeklyForecastObj.yearWeekCnt;
                lstWeeklyForecastObj.add(weeklyForecastObj);               
                
                if(weeklyForecastObj.forecastQty == null){
                    weeklyForecastObj.forecastQty = 0;
                }
                totalForecast += weeklyForecastObj.forecastQty;
                
                if(mapDate_WeekNumber.containsKey(weekStDt)){
                    yearlyWeekCnt = mapDate_WeekNumber.get(weekStDt);
                }
                
                if (yearlyWeekCnt == 52) {
                    boolean is53Weeks = false;
                    if(yearlyWeekCnt == 53 || (monthEndDt.month()!=1 && weekStDt.year() != weekEndDt.year())) {
                        is53Weeks = false;
                    } else {
                        dateTime janDay1 = dateTime.newInstance(weekStDt.year(), 1, 1);
                        if (Math.mod(janDay1.year(),4) == 0 && janDay1.format('EEE') == 'Wed') {
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
                weekStDt = weekEndDt.addDays(1);
                weekCnt++;
                globalWeekCount++;
                
                yearlyWeekCnt++;
            }
            monthStartDt = monthStartDt.addMonths(1);
            monthWiseWeekObj.weeklyForecastObj = lstWeeklyForecastObj;
            if(lstWeeklyForecastObj.size() > 4){
                monthWiseWeekObj.thCls = 'monthTh5WeekCls';
            }else{
                monthWiseWeekObj.thCls = 'monthTh4WeekCls';
            }            
            monthWiseWeekObj.totalForecast = totalForecast;
            monthWiseWeekObj.totalWeeks = weekCnt;
            lstMonthWiseWeekObj.add(monthWiseWeekObj);
        }
        return lstMonthWiseWeekObj;
    }
    //calculate year wise weeks
    public static map<date, integer> getYearwiseWeeks(date startDate, date endDate){
        date yrStartDate = startDate;
        date yrEndDate = endDate;
        
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
                if(weekStDateTime.format('EEEE') != 'Monday' ) {
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
                
                weekEndDt = weekStDt.addDays(6);
                
                if(!mapDate_WeekNumber.containsKey(weekStDt)){
                    mapDate_WeekNumber.put( weekStDt, yearlyWeekCnt);    
                }               
                
                if (yearlyWeekCnt >=52 ){
                    boolean is53Weeks = false;
                    if(yearlyWeekCnt == 53 || (monthEndDt.month()!=1 && weekStDt.year() != weekEndDt.year())){
                        is53Weeks = false;
                    } else {
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
        return mapDate_WeekNumber;
    }
    @AuraEnabled
    public static void savePortalForecastRecords(String forecastWeeklyWrapper){
        Partner_Rolling_Forecast__c weeklyForecastRec = new Partner_Rolling_Forecast__c();
        map<string, Partner_Rolling_Forecast__c> mapUniqueKey_ForecastRec = new map<string, Partner_Rolling_Forecast__c>();
        Map<String,Id> regionMap = new Map<String,Id>();
        map<String,Id> accMap = new Map<String,Id>();
        
        system.debug('***forecastWeeklyWrapper-----------'+json.serialize(forecastWeeklyWrapper));
        RollingForecastWrapper lstForecastRecords =   (RollingForecastWrapper)System.JSON.deserialize(forecastWeeklyWrapper, RollingForecastWrapper.class);
        system.debug('***deserlize-----------'+(lstForecastRecords));
        
        Set<String> sapCodes = new Set<String>();
        for(WeeklyProductWrapper prodObj : lstForecastRecords.weeklyProductObj){
            if (String.isNotBlank(prodObj.customerCode)) {
                sapCodes.add(prodObj.customerCode);
            }
        }
        for(Account acc : [Select Id, SAP_Code__c From Account Where SAP_Code__c IN :sapCodes]) {
            accMap.put(acc.SAP_Code__c, acc.Id);
        } 
        
        for(WeeklyProductWrapper prodObj : lstForecastRecords.weeklyProductObj){
            for(MonthWiseWeeksWrapper monthWiseWeeks : prodObj.lstMonthWiseWeeks){
                for(WeeklyForecastWrapper forecastWeeklyObj : monthWiseWeeks.weeklyForecastObj){
                    if(mapUniqueKey_ForecastRec.containsKey(forecastWeeklyObj.uniqueKey)){
                        weeklyForecastRec = mapUniqueKey_ForecastRec.get(forecastWeeklyObj.uniqueKey);
                    }
                    else{
                        weeklyForecastRec = new Partner_Rolling_Forecast__c();
                        weeklyForecastRec.Unique_Key__c = forecastWeeklyObj.uniqueKey;
                        weeklyForecastRec.Agreement_Product__c = monthWiseWeeks.agreementProdId;
                        weeklyForecastRec.Year__c = forecastWeeklyObj.year;
                        weeklyForecastRec.Month__c = forecastWeeklyObj.month;
                        weeklyForecastRec.Month_Name__c = forecastWeeklyObj.monthName;
                        weeklyForecastRec.Week_Number__c = forecastWeeklyObj.yearWeekCnt;
                        weeklyForecastRec.Week_Start_Date__c = forecastWeeklyObj.startDate;
                        weeklyForecastRec.Week_End_Date__c = forecastWeeklyObj.endDate;
                        weeklyForecastRec.Forecast_Qty__c = forecastWeeklyObj.forecastQty;
                        weeklyForecastRec.ownerId = userinfo.getUserId();
                        weeklyForecastRec.Actual_Qty__c = monthWiseWeeks.totalMonthlyActualQty;
                        if(accMap.containsKey(prodObj.customerCode)){
                            weeklyForecastRec.Account__c = accMap.get(prodObj.customerCode);
                        }
                    }
                    mapUniqueKey_ForecastRec.put(weeklyForecastRec.Unique_Key__c, weeklyForecastRec);
                }
            }
        }
        try{
            upsert mapUniqueKey_ForecastRec.values() Unique_Key__c; 
        }
        Catch(Exception e){
            System.debug('The following exception has occurred: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public static List<MonthWiseWeeksWrapper> updateMonhwiseWeekWrapper(List<MonthWiseWeeksWrapper> lstMonthWiseWeeks, Agreement_Product__c agreementProductObj){
        String oldAgreementProdId, remainingKey, updatedUniqueKey;
        system.debug('month wise week wrapper'+json.serialize(lstMonthWiseWeeks));
        system.debug('new prod id'+agreementProductObj);
        
        Boolean hasOverridePermission = FeatureManagement.checkPermission('Edit_Forecast_Override');
        
        for(MonthWiseWeeksWrapper monthwiseWeek_obj : lstMonthWiseWeeks){
            if(monthwiseWeek_obj.startDate <= agreementProductObj.Master_Agreement__r.Agreement_Start_Date__c &&
               monthwiseWeek_obj.endDate >= agreementProductObj.Master_Agreement__r.Agreement_End_Date__c){
                   monthwiseWeek_obj.agreementProdId = agreementProductObj.id;
                   for(WeeklyForecastWrapper weeklyForecast_obj : monthwiseWeek_obj.weeklyForecastObj){
                       if(monthwiseWeek_obj.startDate < System.today() && !hasOverridePermission){
                           monthwiseWeek_obj.isDisabled = true; 
                       }
                       else if(agreementProductObj.Master_Agreement__r.Agreement_End_Date__c >= monthwiseWeek_obj.endDate && 
                               agreementProductObj.Master_Agreement__r.Agreement_Start_Date__c <= monthwiseWeek_obj.startDate){
                                   monthwiseWeek_obj.isDisabled = false; 
                               }
                       else{
                           monthwiseWeek_obj.isDisabled = true; 
                       }
                       remainingKey = weeklyForecast_obj.uniqueKey.substringAfter('_');
                       updatedUniqueKey = agreementProductObj.Id+'_'+remainingKey;
                       weeklyForecast_obj.uniqueKey = updatedUniqueKey;
                   }
               }
            if(monthwiseWeek_obj.startDate >= agreementProductObj.Master_Agreement__r.Agreement_Start_Date__c &&
               monthwiseWeek_obj.endDate <= agreementProductObj.Master_Agreement__r.Agreement_End_Date__c){
                   monthwiseWeek_obj.agreementProdId = agreementProductObj.id;
                   for(WeeklyForecastWrapper weeklyForecast_obj : monthwiseWeek_obj.weeklyForecastObj){
                       if(monthwiseWeek_obj.startDate < System.today() && !hasOverridePermission){
                           monthwiseWeek_obj.isDisabled = true; 
                       }
                       else if(agreementProductObj.Master_Agreement__r.Agreement_End_Date__c >= monthwiseWeek_obj.endDate && 
                               agreementProductObj.Master_Agreement__r.Agreement_Start_Date__c <= monthwiseWeek_obj.startDate){
                                   monthwiseWeek_obj.isDisabled = false; 
                               }
                       else{
                           system.debug('in eee');
                           monthwiseWeek_obj.isDisabled = true; 
                       }
                       remainingKey = weeklyForecast_obj.uniqueKey.substringAfter('_');
                       updatedUniqueKey = agreementProductObj.Id+'_'+remainingKey;
                       weeklyForecast_obj.uniqueKey = updatedUniqueKey;
                   }
               }
        }        
        return lstMonthWiseWeeks;        
    }
}
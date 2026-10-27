/********************************************
* @Class Name   : WeeklyForecastController
* @Description  : It is used to implement the weekly forecast logic.
* @Created Date : 06-11-2019
* @Created By   : Pratiksha K. 
* ****************************************/

Public class WeeklyForecastController{
	    
    public class WeeklyForecastWrapper{
        @AuraEnabled public integer selMonth{get;set;}
        @AuraEnabled public string selMonthName{get;set;}
        @AuraEnabled public integer selYear{get;set;}
        @AuraEnabled public date startDate{get;set;}
        @AuraEnabled public date endDate{get;set;}
        @AuraEnabled public date selDate{get;set;}
        @AuraEnabled public integer nextMonth{get;set;}
        @AuraEnabled public list<WeeklyProductWrapper> weeklyProductObj {get;set;}
    }
    
    public class WeeklyProductWrapper {
        @AuraEnabled public string productId{get;set;}
        @AuraEnabled public string productName{get;set;}
        @AuraEnabled public string branch{get;set;}
        @AuraEnabled public string division{get;set;}
        @AuraEnabled public String branchCode{get;set;}
        @AuraEnabled public string region{get;set;}
        @AuraEnabled public list<MonthWiseWeeksWrapper> lstMonthWiseWeeks {get;set;}
        @AuraEnabled public boolean isDisabled{get;set;}
        @AuraEnabled public integer intDiv{get;set;}
    }
    
    public class ForecastWeeklyWrapper{
        @AuraEnabled public integer forecastQty {get;set;}
        @AuraEnabled public integer actualQty {get;set;}
        @AuraEnabled public string comment {get;set;}
        @AuraEnabled public date startDate{get;set;}
        @AuraEnabled public date endDate{get;set;}
        @AuraEnabled public integer month{get;set;}
        @AuraEnabled public string monthName{get;set;}
        @AuraEnabled public integer year{get;set;}
        @AuraEnabled public string recordId{get;set;}
        @AuraEnabled public string uniqueKey{get;set;}
        @AuraEnabled public integer weekNumber{get;set;}
        @AuraEnabled public boolean isDisabled{get;set;}
        @AuraEnabled public integer globalWeekCount{get;set;}
        @AuraEnabled public integer yearWeekCnt{get;set;}
        @AuraEnabled public string forecastWeekNumber{get;set;}
        @AuraEnabled public string actualWeekNumber{get;set;}
        @AuraEnabled public string mopId{get;set;}
        @AuraEnabled public integer weekwiseMOPQty{get;set;}
    }
    
    public class MonthWiseWeeksWrapper{
        @AuraEnabled public string monthYear{get;set;}
        @AuraEnabled public integer month{get;set;}
        @AuraEnabled public string monthName{get;set;}
        @AuraEnabled public string monthShortName{get;set;}
        @AuraEnabled public integer year{get;set;}
        @AuraEnabled public date startDate{get;set;}
        @AuraEnabled public list<WeeksWrapper> weekWrapperObj{get;set;}
        @AuraEnabled public list<ForecastWeeklyWrapper> weeklyForecastObj{get;set;}
        @AuraEnabled public string thCls{get;set;}
        @AuraEnabled public boolean isDisabled{get;set;}
        @AuraEnabled public integer totalForecast{get;set;}
        @AuraEnabled public integer totalActual{get;set;}
        @AuraEnabled public integer forecastActualVariance{get;set;}
        @AuraEnabled public decimal budCons{get;set;}
        @AuraEnabled public integer mopValue{get;set;}
        @AuraEnabled public string mopId{get;set;}
        @AuraEnabled public integer totalWeeks{get;set;}
    }
    
    public class WeeksWrapper{
        @AuraEnabled public integer weekNumber{get;set;}
        @AuraEnabled public date startDate{get;set;}
        @AuraEnabled public date endDate{get;set;}
        @AuraEnabled public integer month{get;set;}
        @AuraEnabled public string monthName{get;set;}
        @AuraEnabled public integer year{get;set;}
    }
    
    public class FieldWiseWrapper{
        @AuraEnabled public string fieldLbl{get;set;}
        @AuraEnabled public list<MonthWiseWeeksWrapper> lstMonthWiseWeeks {get;set;}
        @AuraEnabled public boolean isDisabled{get;set;}
    }
    //fetch user's related regions
    @AuraEnabled
    public static Map<String,String> fetchRegionLst(Id userId){
        Set<String> regionValues = new Set<String>();
        Map<String,String> regionCodeUserMap = new Map<String,String>();
        List<CIty__c> regionValuesLst = new List<CIty__c>();
        List<User_Region_Association__c> userRegionLst= [Select id,name,Region__r.Name,Region__r.Region_Code__c,User__c,User__r.name from User_Region_Association__c where User__c =: userId];
       
        if(!userRegionLst.isEmpty()){
            for(User_Region_Association__c userRegion : userRegionLst){
                regionCodeUserMap.put(userRegion.Region__r.Region_Code__c,userRegion.Region__r.Name);
            }
        }
        return regionCodeUserMap;
    }
    
    //fetch branches related to regions
    @AuraEnabled
    public static Map<String,String> fetchRelatedBranchLst(String selectedRegionCode){
        List<String> branchLst = new List<String>();
        Set<String> branchst = new Set<String>();
        List<BranchFormDataVsLocation__c> customSettingLstForBranch = new List<BranchFormDataVsLocation__c>();
        List<BranchFormDataVsLocation__c> customSettingLstToReturnForBranch = new List<BranchFormDataVsLocation__c>();
        Set<BranchFormDataVsLocation__c> customSettingStForBranch = new Set<BranchFormDataVsLocation__c>();
        Map<String,String> deliverPlantBranchMap = new Map<String,String>();
        
        CIty__c region = [Select Id,Name,Region_Code__c From CIty__c Where Region_Code__c =: selectedRegionCode];
        
        if(region != null){
            customSettingLstForBranch = [Select Id,Branch_Location__c,Region_Code__c,Delivery_Plant__c From BranchFormDataVsLocation__c 
                                         Where Region_Code__c =: region.Region_Code__c];
        }
        if(!customSettingLstForBranch.isEmpty()){
            for(BranchFormDataVsLocation__c branch : customSettingLstForBranch){
                branchst.add(branch.Delivery_Plant__c);
            }
        }
        //deliverPlantBranchMap.put('All','All');
        for(BranchFormDataVsLocation__c br : customSettingLstForBranch){
            deliverPlantBranchMap.put(br.Branch_Location__c,br.Delivery_Plant__c);
            //deliverPlantBranchMap.put(br.Delivery_Plant__c,br.Branch_Location__c);
        }
        return deliverPlantBranchMap;
    }
    //Get monthname from selected month number
    public static String GetCurrentMonthName(String monthNumber){
        String monthName = '';
        Switch on monthNumber{
        	When '1'{
                return 'January';
            }
            When '2'{
                return 'February';
            }
            When '3'{
                return 'March';
            }
            When '4'{
                return 'April';
            }
            When '5'{
                return 'May';
            }
            When '6'{
                return 'June';
            }
            When '7'{
                return 'July';
            }
            When '8'{
                return 'August';
            }
            When '9'{
                return 'September';
            }
            When '10'{
                return 'October';
            }
            When '11'{
                return 'November';
            }
            When '12'{
                return 'December';
            }
        }
        return monthNumber;
    }
    //fill weekly forecast warpper object
    @AuraEnabled
    public static WeeklyForecastWrapper getWeeklyForecastDetails(Id currentUserId, String selectedYear,
                                                                 String selectedRegionCode, String selectedBranchName,String selectedBranchCode,
                                                                 String selectedMonth,Integer page, Integer pageSize){                                                             
                                                                     
        Date currentMonthDate =system.today();
        Integer currentMonth = currentMonthDate.month();
        Integer currentYear = currentMonthDate.year();  
        Integer nextMonth;
                                                                     
        String selectedMonthName = WeeklyForecastController.GetCurrentMonthName(selectedMonth);    

        date selDate = date.newInstance(Integer.valueOf(selectedYear), Integer.valueOf(selectedMonth), 1);
        nextMonth = 2;                                               

        date startDt = selDate;
        date endDt = selDate.addMonths(nextMonth);
       
        WeeklyForecastWrapper weeklyForecastObj = new WeeklyForecastWrapper();
        weeklyForecastObj.selMonth = Integer.valueOf(selectedMonth);
        weeklyForecastObj.selYear = Integer.valueOf(selectedYear);
        weeklyForecastObj.startDate = startDt;
        weeklyForecastObj.endDate = endDt;
        weeklyForecastObj.selMonthName = selectedMonthName;
        weeklyForecastObj.nextMonth = nextMonth;
        weeklyForecastObj.selDate = selDate;
        
        weeklyForecastObj = getForecastWrapper(weeklyForecastObj, weeklyForecastObj.startDate, weeklyForecastObj.endDate, currentUserId,
                                              selectedRegionCode,selectedBranchName,selectedBranchCode,page,pageSize);

        return weeklyForecastObj;
    }
    //create final wrapper
    @AuraEnabled //startDate = selected months start date // end date = start date of last month to show
    public static WeeklyForecastWrapper getForecastWrapper(WeeklyForecastWrapper weeklyForecastObj, date startDate, date endDate, 
                                                           Id currentUserId,String selectedRegionCode, String selectedBranchName,
                                                           String selectedBranchCode,Integer page, Integer pageSize){
        //list<string> productNameLst = getProducts();
        WeeklyProductWrapper productWrapperObj = new WeeklyProductWrapper();
        list<WeeklyProductWrapper> lstProductWrapperObj = new list<WeeklyProductWrapper>();
        ForecastWeeklyWrapper forecastWeeklyObj = new ForecastWeeklyWrapper();
        Set<Id> prodId = new set<Id>();                                                    
       List<BranchFormDataVsLocation__c> customSettingLstForBranch = new List<BranchFormDataVsLocation__c>();
       Set<String> branchst = new Set<String>();
       Set<Date> dateSt = new Set<Date>();
        Map<String,String> branchNameCodeMap  = new Map<String,String>();   
        Map<String,Decimal> mopQty  = new Map<String,Decimal>();
       	Map<String,Monthly_AOP__c> productMopMap = new Map<String,Monthly_AOP__c>();
       List<Monthly_AOP__c> mopLst = new List<Monthly_AOP__c>();                                                        
        map<String,String> userForecastHistoryMap = new map<String,String>(); 
        List<Forecast_Submission_History__c> forecasthistoryLst = new List<Forecast_Submission_History__c>();                                                     
                                                                             
         Integer skipRecords = 0;
            system.debug('page'+Integer.valueOf(page));
            system.debug('page size'+Integer.valueOf(pageSize));                                                   
            page = Integer.valueOf(page);
            pageSize = Integer.valueOf(pageSize);
            if(page > 1)
                skipRecords = (page - 1 ) * pageSize ;
            
            system.debug('skipRecords***'+skipRecords);  
                                                               
        //Get product data
        List<Product__c> productLst = new List<Product__c>();
        if(selectedBranchCode == 'All'){
           forecasthistoryLst = [Select id,Submitted_By__c,Status__c,Submitted_For_Month__c,Submitted_For_Year__c,
                                                                       Submission_Date__c,Branch__c,Region__c,Delivery_Plant_Code__c
                                                                       from Forecast_Submission_History__c Where Submitted_By__c =: currentUserId and 
																		Region__r.Region_Code__c =: selectedRegionCode];
        }  
       else{                                                        
      	forecasthistoryLst = [Select id,Submitted_By__c,Status__c,Submitted_For_Month__c,Submitted_For_Year__c,
                                                        		Submission_Date__c,Branch__c,Region__c,Delivery_Plant_Code__c
                                                                 from Forecast_Submission_History__c Where Submitted_By__c =: currentUserId and 
                                                                Branch__c =: selectedBranchName and 
                                                                 Delivery_Plant_Code__c =: Integer.valueOf(selectedBranchCode)
                                                                and Region__r.Region_Code__c =: selectedRegionCode];
       }
      system.debug('forecasthistoryLst'+forecasthistoryLst);                                                         
       if(!forecasthistoryLst.isEmpty()){
           for(Forecast_Submission_History__c forecastHistory : forecasthistoryLst){
               userForecastHistoryMap.put(forecastHistory.Submitted_For_Month__c+'-'+forecastHistory.Submitted_For_Year__c,forecastHistory.Submitted_By__c);
           }
       }                                                        
                                                               
       /*productLst = [Select Id,Name,Division__c,Active__c,Planning__c,Dummy_Product_Code__c,Region__c,Dummy_Product_Description__c,MSP__c 
                     From Product__c Where Planning__c = 'Yes' AND Active__c = TRUE and Region__c ='Domestic' and MSP__c > 0 and Division__c = 'I'
                     Order By Division__c,Dummy_Product_Description__c]; */
                                                               
         String query =  'Select Id,Name,Division__c,Active__c,Planning__c,Dummy_Product_Code__c,Region__c,'
         +' Dummy_Product_Description__c,MSP__c From Product__c Where Planning__c = \'Yes\''
         +' AND Active__c = TRUE and Region__c =\'Domestic\' and MSP__c > 0'
         +' Order By Division__c ,Dummy_Product_Description__c';
            
            system.debug('query : ' +query);

            query += ' LIMIT ' + pageSize ;            
            query += ' OFFSET '+ skipRecords;            
            
            system.debug('**Product2.Name***'+query);                                                        
        productLst = (List<Product__c>) Database.query( query );                                                       

        if(!productLst.isEmpty()){
            for(Product__c pr : productLst){
                prodId.add(pr.id);
            }
        }                                                      
        if(startDate.month() == system.today().month() && startDate.year() == system.today().year()){
            dateSt.add(startDate.addMonths(1));
            dateSt.add(startDate.addMonths(2));
            dateSt.add(startDate.addMonths(3));
        }
        else{                                                       
            dateSt.add(startDate); 
            dateSt.add(startDate.addMonths(1));
            dateSt.add(startDate.addMonths(2)); 
        }
       if(!prodId.isEmpty() && !dateSt.isEmpty()){
            mopLst = [select id,Target_Quantity__c,Month__c,Product__c,Month_Number__c,Start_Date__c,
                                       OwnerId from Monthly_AOP__c where Product__c IN: prodId and Start_Date__c IN : dateSt and 
                                       OwnerId =: currentUserId];
        }                                                    
        
      system.debug('mopLst'+json.serialize(mopLst));
         if(!mopLst.isEmpty()){
             for(Monthly_AOP__c mop : mopLst){
                 productMopMap.put(mop.Start_Date__c+'-'+mop.Product__c,mop);
             }                                                      
         }                                                      
                                                               
        if(productLst == null){
            system.debug('list is null records not found in db');
            return null;
        }
        if(selectedBranchName == 'All'){
            customSettingLstForBranch = [Select Id,Branch_Location__c,Region_Code__c,Delivery_Plant__c From BranchFormDataVsLocation__c 
                                         Where Region_Code__c =: selectedRegionCode];
            system.debug('customSettingLstForBranch in all'+customSettingLstForBranch);
        
            if(!customSettingLstForBranch.isEmpty()){
                for(BranchFormDataVsLocation__c branch : customSettingLstForBranch){
                    //branchst.add(branch.Delivery_Plant__c);
                    branchNameCodeMap.put(branch.Delivery_Plant__c,branch.Branch_Location__c);
                }
            }
        }
        else if(selectedBranchName != 'All'){
             branchNameCodeMap.put(selectedBranchCode,selectedBranchName);
            system.debug('branchst'+branchNameCodeMap);
        } 
        date yrStartDate = date.newInstance(startDate.year(),1,1);
        date yrEndDate = date.newInstance(endDate.year(),12,31);                                                    
         map<date, integer> mapDate_WeekNumber = getYearwiseWeeks(yrStartDate, yrEndDate);                                                      
         Weekly_Forecast_Settings__c forecastSettings = [Select Id,Date__c,Submission_Closing_Date__c,Submission_Opening_Date__c From Weekly_Forecast_Settings__c];                                                     
                                                               
		String branchNm='';
         for(String branch : branchNameCodeMap.keyset()){
             branchNm = branchNameCodeMap.get(branch);
            	for(Product__c productObj : productLst){
                        productWrapperObj = new WeeklyProductWrapper();
                        //productWrapperObj.productName = productObj.name;
                        productWrapperObj.productName = productObj.Dummy_Product_Description__c;
                        productWrapperObj.productId = productObj.Id; 
                        productWrapperObj.branch = branchNm; 
                        productWrapperObj.branchCode = branch;
                        productWrapperObj.region = selectedRegionCode; 
                    	productWrapperObj.division = productObj.Division__c;
                    if(productObj.Division__c == 'I'){
                        productWrapperObj.intDiv= 1;
                    }
                    if(productObj.Division__c == 'II'){
                        productWrapperObj.intDiv= 2;
                    }
                    if(productObj.Division__c == 'III'){
                        productWrapperObj.intDiv= 3;
                    }
                    if(productObj.Division__c == 'IV'){
                        productWrapperObj.intDiv= 4;
                    }
                    if(productObj.Division__c == 'V'){
                        productWrapperObj.intDiv= 5;
                    }
                    	productWrapperObj.lstMonthWiseWeeks = WeeklyForecastController.getWeekWiseDetails(startDate,productObj.Id,branch,endDate, 
                                                                                                  		  weeklyForecastObj.selDate,selectedRegionCode,
                                                                                                          forecastSettings,productMopMap,userForecastHistoryMap,
                                                                                                          mapDate_WeekNumber);
                    	//selDate && startDate = selected months start date // end date = start date of last month to show
                        //system.debug('productWrapperObj-----'+productWrapperObj);
                        lstProductWrapperObj.add(productWrapperObj);
         }
       }
        system.debug('lstProductWrapperObj------'+lstProductWrapperObj);
        weeklyForecastObj.weeklyProductObj = lstProductWrapperObj;
        
        List<Weekly_Forecast__c> weeklyForecastRecords = [select id,name,Actual_Qty__c,Forecast_Qty__c,Month__c,Month_Name__c,Product__c,Region__c,
                                                          Product__r.Name,Year__c,Week_End_Date__c,Week_Start_Date__c,Week_Number__c,Branch_Code__c, 
                                                          Month_Start_Date__c,Unique_Key_Weekly_Forecast__c,Branch__c from Weekly_Forecast__c
                                                          where Product__c IN : prodId and Branch_Code__c IN: branchNameCodeMap.keyset() and
                                                         Region__r.Region_Code__c =: selectedRegionCode];                                                                                                                   
        //system.debug('list of weekly forecasst records from database------'+json.serialize(weeklyForecastRecords));
        
        if(weeklyForecastRecords == null){
            system.debug('list is null records not found in db');
            //system.debug('wrapeer when no records found'+weeklyForecastObj);
            return weeklyForecastObj;
        }
        
        productWrapperObj = new WeeklyProductWrapper();
        lstProductWrapperObj = new list<WeeklyProductWrapper>();
        
        decimal weekVal = 0;
       
        if(!weeklyForecastRecords.isEmpty()){
            for(Weekly_Forecast__c weeklyForecastRec : weeklyForecastRecords){
                for(WeeklyProductWrapper forcastObj : weeklyForecastObj.weeklyProductObj){
                    for(MonthWiseWeeksWrapper monthWiseWeek : forcastObj.lstMonthWiseWeeks){                                                
                        for(ForecastWeeklyWrapper weeklyForecast :  monthWiseWeek.weeklyForecastObj){
                            if(weeklyForecast.year == weeklyForecastRec.Year__c && weeklyForecast.month ==  weeklyForecastRec.Month__c && 
                               weeklyForecast.yearWeekCnt == weeklyForecastRec.Week_Number__c && forcastObj.productId == weeklyForecastRec.Product__c &&
                               forcastObj.branchCode == weeklyForecastRec.Branch_Code__c){                                 
                                   weeklyForecast.forecastQty = integer.valueOf(weeklyForecastRec.Forecast_Qty__c); 
                                   //weeklyForecast.actualQty = integer.valueOf(weeklyForecastRec.Actual_Qty__c); 
                                   monthWiseWeek.totalForecast += integer.valueOf(weeklyForecastRec.Forecast_Qty__c); 
                                   //monthWiseWeek.totalActual += integer.valueOf(weeklyForecastRec.Actual_Qty__c); 
                               }
                        }
                        //monthWiseWeek.forecastActualVariance  = monthWiseWeek.totalActual - monthWiseWeek.totalForecast;
                        if(monthWiseWeek.mopValue != null){
                         monthWiseWeek.forecastActualVariance  = monthWiseWeek.totalForecast - monthWiseWeek.mopValue;
                        }
                        else{
                            monthWiseWeek.forecastActualVariance  = monthWiseWeek.totalForecast;
                        }
                        /*if(monthWiseWeek.totalForecast > 0){
                            monthWiseWeek.budCons = ((decimal.valueOf(monthWiseWeek.totalActual)/monthWiseWeek.totalForecast)*100).setScale(2); 
                        }                            
                        else{
                            monthWiseWeek.budCons = 0;
                        }*/
                    }
                }
            }
        }
          system.debug('**weeklyForecastObj***'+JSOn.serialize(weeklyForecastObj));                                                
        return weeklyForecastObj;
    }
    //fill monthwise weeks wrapper(calculate month wise weeks)
     @AuraEnabled
    public static list<MonthWiseWeeksWrapper> getWeekWiseDetails(date startDate, Id prodId,String branch,date endDate, date selDate,String selectedRegionCode,
                                                                 Weekly_Forecast_Settings__c forecastSettings,
                                                                 Map<String,Monthly_AOP__c> productMopMap,
                                                                 Map<String,String> userForecastHistoryMap,map<date, integer> mapDate_WeekNumber){
        //selDate && startDate = selected months start date // end date = start date of last month to show
        Date currentMonthDate =system.today();
        Integer currentMonthNumber = currentMonthDate.month();
        Integer currentMonthYear = currentMonthDate.year(); 
        Date selectedSubmissionClosingDate = date.newInstance(currentMonthYear,currentMonthNumber,integer.valueOf(forecastSettings.Submission_Closing_Date__c));                                                         
        
		integer selectedYear = selDate.year();
        integer selectedMonth = selDate.month();
        
        //map<date, integer> mapDate_WeekNumber = getYearwiseWeeks(startDate, endDate);//1/11/2020 - 1/1/2021 //commented by pk 0n 5 12
        
        date monthStartDt = startDate, monthEndDt, weekStDt, weekEndDt; 
        //date monthStartDt, monthEndDt, weekStDt, weekEndDt; 
        datetime weekStDateTime;
        
        monthStartDt = date.newinstance(selectedYear, selectedMonth, 1);
                                                            
        if(currentMonthDate < selectedSubmissionClosingDate && selDate.month() == currentMonthNumber && selDate.year() == currentMonthYear){
             monthStartDt = monthStartDt.addMonths(1);
        }
         else if(currentMonthDate > selectedSubmissionClosingDate && selDate.month() == currentMonthNumber && selDate.year() == currentMonthYear){
             monthStartDt = monthStartDt.addMonths(2);
         }
          else{
             monthStartDt = monthStartDt.addMonths(1); 
          }                                                           
    
        list<MonthWiseWeeksWrapper> lstMonthWiseWeekObj = new list<MonthWiseWeeksWrapper>();
        MonthWiseWeeksWrapper monthWiseWeekObj = new MonthWiseWeeksWrapper();
        
        integer weekCnt =1, yearlyWeekCnt = 1;
        
        //Weekwise Wrapper
        list<ForecastWeeklyWrapper> lstWeeksObj = new list<ForecastWeeklyWrapper>();
        ForecastWeeklyWrapper weekObj = new ForecastWeeklyWrapper();
        datetime monthStartDateTime;
        date monthStartDate;                                                           
        integer globalWeekCount = 0;
        Integer totalForecast = 0;
        Integer totalActual = 0;
        Integer forecastActualVarience = 0;
        Integer budCons = 0;
        
        Integer monthCount = startDate.monthsBetween(endDate);
        if (endDate.day() > startDate.day()) monthCount++;        
       
        //i=3//per month for loop
        for(integer i=0; i<=monthCount; i++) {
            totalForecast = 0;
            totalActual=0;
            forecastActualVarience = 0;
            budCons = 0;
            lstWeeksObj = new list<ForecastWeeklyWrapper>(); 
            selectedYear = monthStartDt.year();
            selectedMonth = monthStartDt.month();
            
            monthStartDateTime = dateTime.newInstance(selectedYear, selectedMonth, 1);
            monthStartDate = date.newinstance(monthStartDateTime.year(), monthStartDateTime.month(), monthStartDateTime.day());
            monthWiseWeekObj = new MonthWiseWeeksWrapper();

            if(monthStartDate > currentMonthDate){
                if(currentMonthDate > selectedSubmissionClosingDate){
                    if(!userForecastHistoryMap.isEmpty()){
                        if(userForecastHistoryMap.containsKey(monthStartDate.month()+'-'+monthStartDate.year())){
                            monthWiseWeekObj.isDisabled = true;
                        }
                        else{
                            monthWiseWeekObj.isDisabled = false; 
                        }
                    }
                    else{ 
                        if(monthStartDate.month() == system.today().addMonths(1).month()){
                           monthWiseWeekObj.isDisabled = true;  
                        }
                        else{
                            monthWiseWeekObj.isDisabled = false; 
                        }
                    }
                }
                else{
                    if(!userForecastHistoryMap.isEmpty()){
                        if(userForecastHistoryMap.containsKey(monthStartDate.month()+'-'+monthStartDate.year())){
                            monthWiseWeekObj.isDisabled = true;
                        }
                        else{
                            monthWiseWeekObj.isDisabled = false; 
                        }
                    }
                    else{
                        monthWiseWeekObj.isDisabled = false; 
                    }
                }
            }
            else{
                monthWiseWeekObj.isDisabled = true;
            } 

            monthWiseWeekObj.month = selectedMonth;
            monthWiseWeekObj.monthName = monthStartDateTime.format('MMMMM');
            monthWiseWeekObj.monthShortName = monthWiseWeekObj.monthName.substring(0,3);  
            monthWiseWeekObj.year = selectedYear;
            monthWiseWeekObj.monthYear = string.valueOf(selectedMonth) + string.valueOf(selectedYear);
            monthWiseWeekObj.startDate = monthStartDateTime.date();

            if(productMopMap.containsKey(monthStartDate+'-'+prodId)){
                monthWiseWeekObj.mopValue = Integer.valueOf(productMopMap.get(monthStartDate+'-'+prodId).Target_Quantity__c);
                monthWiseWeekObj.mopId = productMopMap.get(monthStartDate+'-'+prodId).Id;
            }
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
                system.debug(is53Week +'*****'+ weekStDt);
                //Find the first monday of selected stocksheet Date time i.e week1 startdate
                system.debug(weekStDateTime.format('EEEE'));
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
            
            weekCnt = 1;
            weekEndDt = weekStDt.addDays(7);
            
        	//week wise while loop
            while(weekStDt<=monthEndDt){
                weekObj = new ForecastWeeklyWrapper();
                weekStDateTime = date.newInstance(weekStDt.year(), weekStDt.month(), weekStDt.day());
                //Find the first monday of selected stocksheet Date time i.e week1 startdate
                if(weekStDateTime.format('EEEE') != 'Monday') {
                    while(weekStDateTime.format('EEEE') != 'Monday') {
                        weekStDt = weekStDt.addDays(1);
                        weekStDateTime = date.newInstance(weekStDt.year(), weekStDt.month(), weekStDt.day());
                    }
                }
                //Add 7 days to get end of week
                weekEndDt = weekStDt.addDays(6);
                weekObj.startDate = weekStDt;
                weekObj.endDate = weekEndDt;
                weekObj.weekNumber = weekCnt;
                weekObj.month = monthWiseWeekObj.month;
                weekObj.monthName = monthWiseWeekObj.monthName;
                weekObj.year = monthWiseWeekObj.year;
                weekObj.mopId = monthWiseWeekObj.mopId;

                if(mapDate_WeekNumber.containsKey(weekObj.startDate)){
                    weekObj.yearWeekCnt = mapDate_WeekNumber.get(weekObj.startDate);
                }
                
        		weekObj.globalWeekCount = globalWeekCount;                               
                weekObj.uniqueKey = prodId+'_'+selectedRegionCode+'_'+branch+'_'+monthWiseWeekObj.year+'_'+monthWiseWeekObj.month+'_'+weekObj.yearWeekCnt;
                lstWeeksObj.add(weekObj);               
                
                if(weekObj.forecastQty == null){
                    weekObj.forecastQty = 0;
                }
                /*if(weekObj.actualQty == null){
                    weekObj.actualQty = 0;
                }*/
                totalForecast += weekObj.forecastQty;
                //totalActual += weekObj.actualQty;

                if(mapDate_WeekNumber.containsKey(weekStDt)){
                     yearlyWeekCnt = mapDate_WeekNumber.get(weekStDt);
                }
 
                system.debug('***weekObj.yearWeekCnt****' + yearlyWeekCnt);
                if (yearlyWeekCnt == 52) {
                    boolean is53Weeks = false;
                    if(yearlyWeekCnt == 53 || (monthEndDt.month()!=1 && weekStDt.year() != weekEndDt.year())) {
                        is53Weeks = false;
                    } else {
                        // Found leap year
                        // Get the day 1st of next year Jan
                        dateTime janDay1 = dateTime.newInstance(weekStDt.year(), 1, 1);
                        system.debug('*Jan Day*'+janDay1.format('EEE'));
                        if (Math.mod(janDay1.year(),4) == 0 && janDay1.format('EEE') == 'Wed') {
                            is53Weeks = true;						                        
                        } else if(janDay1.format('EEE') == 'Thu') {
                            is53Weeks = true;
                        }
                        system.debug('*isWeek53*'+is53Weeks);
                    }
                    
                    system.debug('is53Weeks*****'+is53Weeks);
                    if(!is53Weeks) {
                        //weekCnt = 1;
                        //weekObj.yearWeekCnt = 1;
                        yearlyWeekCnt = 1;
                        break;
                    }
                }
                //Add one day to week end date to get start date
                weekStDt = weekEndDt.addDays(1);
                weekCnt++;
                globalWeekCount++;
                
                yearlyWeekCnt++;
            } 
            system.debug('***lstWeeksObj***'+lstWeeksObj)	;
            monthStartDt = monthStartDt.addMonths(1);
            monthWiseWeekObj.weeklyForecastObj = lstWeeksObj;
            if(lstWeeksObj.size() > 4){
                monthWiseWeekObj.thCls = 'monthTh5WeekCls';
            }else{
                monthWiseWeekObj.thCls = 'monthTh4WeekCls';
            }
            
            monthWiseWeekObj.totalForecast = totalForecast;
            //monthWiseWeekObj.totalActual = totalActual;            
            //monthWiseWeekObj.forecastActualVariance = monthWiseWeekObj.totalActual - monthWiseWeekObj.totalForecast;
            system.debug('total forcast'+monthWiseWeekObj.totalForecast);
            system.debug('total mop'+monthWiseWeekObj.mopValue);
            if(monthWiseWeekObj.mopValue != null){
               monthWiseWeekObj.forecastActualVariance = monthWiseWeekObj.totalForecast - monthWiseWeekObj.mopValue;
            }
            else{
               monthWiseWeekObj.forecastActualVariance = monthWiseWeekObj.totalForecast; 
            }
            monthWiseWeekObj.totalWeeks = weekCnt;
            
            /*if(monthWiseWeekObj.totalForecast >  0){
                monthWiseWeekObj.budCons = ((decimal.valueOf(monthWiseWeekObj.totalActual)/monthWiseWeekObj.totalForecast)*100).setScale(0); 
            }
            if(monthWiseWeekObj.totalForecast ==  0){
                monthWiseWeekObj.budCons = 0;
            }*/
            
            lstMonthWiseWeekObj.add(monthWiseWeekObj);
        
        } 
        //system.debug('**lstMonthWiseWeekObj***'+lstMonthWiseWeekObj);
        return lstMonthWiseWeekObj;
    }
    //calculate year wise weeks
    public static map<date, integer> getYearwiseWeeks(date startDate, date endDate){
        system.debug('**startDate***'+startDate);//1/11/2020
        system.debug('**endDate***'+endDate); //1/1/2021
        /*date yrStartDate = date.newInstance(startDate.year(),1,1);
        date yrEndDate = date.newInstance(endDate.year(),12,31);*///commented by pk on 5 12
		date yrStartDate = startDate;
        date yrEndDate = endDate;
        
        datetime weekStDateTime,monthStartDateTime;
        date monthStartDt = yrStartDate, monthEndDt, weekStDt = yrStartDate, weekEndDt; 
        map<Date, integer> mapDate_WeekNumber = new map<Date,integer>();
        
        integer yearlyWeekCnt =1, year, month;
        
        
        Integer monthCount = yrStartDate.monthsBetween(yrEndDate);
        if (yrEndDate.day() > yrStartDate.day()) monthCount++;
        
        system.debug('**monthCount*'+monthCount);
        
        
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
                system.debug('***lastJanDt***'+lastJanDt);

                if(Math.mod(lastJanDt.year(),4) == 0 && lastJanDt.format('EEE')=='Wed') {
                    is53Week = true;
                } else{
                    if(lastJanDt.format('EEE')=='Thu' || lastJanDt.format('EEE')=='Fri' || 
                       lastJanDt.format('EEE')=='Sat' || lastJanDt.format('EEE')=='Sun') {
                        is53Week = true;
                    }
                }
                
                weekStDateTime = date.newInstance(weekStDt.year(), weekStDt.month(), weekStDt.day());
                system.debug(is53Week +'*****'+ weekStDt);
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
                        system.debug('**Jan Monday weekStDateTime**'+weekStDateTime);
                        system.debug('**Jan Monday weekStDt**'+weekStDt);
                        weekStDateTime = date.newInstance(weekStDt.year(), weekStDt.month(), weekStDt.day());
                    }
                }
                system.debug('**Jan Monday**'+weekStDt);
                yearlyWeekCnt = 1;
                mapDate_WeekNumber.put( weekStDt, yearlyWeekCnt);
            }
      
            weekEndDt = weekStDt.addDays(7);
            
            while(weekStDt<=monthEndDt){
				                
                weekStDateTime = date.newInstance(weekStDt.year(), weekStDt.month(), weekStDt.day());
                if(weekStDateTime.format('EEEE') != 'Monday') {
                    //weekStDt = weekStDt.addDays(1);
                    while(weekStDateTime.format('EEEE') != 'Monday') {
                        weekStDt = weekStDt.addDays(1);
                        weekStDateTime = date.newInstance(weekStDt.year(), weekStDt.month(), weekStDt.day());
                    }
                }
                
                //Add 7 days to get end of week
                weekEndDt = weekStDt.addDays(6);
                
                if(!mapDate_WeekNumber.containsKey(weekStDt)){
                    mapDate_WeekNumber.put( weekStDt, yearlyWeekCnt);    
                }
                
                system.debug('**mapDate_WeekNumber**'+mapDate_WeekNumber);
                
                //Calculate whether 52 or 53 weeks
                system.debug('**year**'+year);
                if (yearlyWeekCnt >=52 ){
                    system.debug('***yearlyWeekCnt***'+yearlyWeekCnt);
                    boolean is53Weeks = false;
                    if(yearlyWeekCnt == 53 || (monthEndDt.month()!=1 && weekStDt.year() != weekEndDt.year())){
                        is53Weeks = false;
                    } else {
                        //Found leap year
                        //Get the day 1st of next year Jan
                        dateTime janDay1 = dateTime.newInstance(year, 1, 1);
                        system.debug('**'+janDay1.format('EEE'));
                        if (Math.mod(year,4) == 0 && janDay1.format('EEE') == 'Wed') {
                            is53Weeks = true;						                        
                        } else if(janDay1.format('EEE') == 'Thu') {
                            is53Weeks = true;
                        }
                        system.debug('**'+is53Weeks);
                    }
                    if(!is53Weeks) {
                        yearlyWeekCnt = 1;
                        break;
                    }
                }
                //mapDate_WeekNumber.put( weekStDt,  yearlyWeekCnt);    
				yearlyWeekCnt++;

                //Add one day to week end date to get start date
                weekStDt = weekEndDt.addDays(1);
            } 
            monthStartDt = monthStartDt.addMonths(1);

        }
        
        //system.debug('****mapDate_WeekNumber***'+JSON.serialize(mapDate_WeekNumber));
        return mapDate_WeekNumber;
    }
    
    //upsert forecast records
    @AuraEnabled
    public static void saveForecastRecords(String forecastWeeklyWrapper){
        system.debug('***forecastWeeklyWrapper-----------'+forecastWeeklyWrapper);
        WeeklyForecastWrapper lstForecastRecords =   (WeeklyForecastWrapper)System.JSON.deserialize(forecastWeeklyWrapper, WeeklyForecastWrapper.class);
        system.debug('***deserlize-----------'+(lstForecastRecords));
        
        Weekly_Forecast__c weeklyForecastRec = new Weekly_Forecast__c();
        map<string, Weekly_Forecast__c> mapUniqueKey_ForecastRec = new map<string, Weekly_Forecast__c>();
        Map<String,String> regionMap = new Map<String,String>();
        List<CIty__c> regionLst = [Select Id,Name,Region_Code__c From CIty__c];
        if(!regionLst.isEmpty()){
            for(CIty__c region : regionLst){
               regionMap.put(region.Region_Code__c,region.id); 
            }
        }
        
            for(WeeklyProductWrapper prodObj : lstForecastRecords.weeklyProductObj){
                for(MonthWiseWeeksWrapper monthWiseWeeks : prodObj.lstMonthWiseWeeks){
                    for(ForecastWeeklyWrapper forecastWeeklyObj : monthWiseWeeks.weeklyForecastObj){
                        if(mapUniqueKey_ForecastRec.containsKey(forecastWeeklyObj.uniqueKey)){
                          weeklyForecastRec = mapUniqueKey_ForecastRec.get(forecastWeeklyObj.uniqueKey);
                        }
                        else{
                        weeklyForecastRec = new Weekly_Forecast__c();
                        weeklyForecastRec.Unique_Key_Weekly_Forecast__c = forecastWeeklyObj.uniqueKey;
                        weeklyForecastRec.Product__c = prodObj.productId;
                        weeklyForecastRec.Year__c = forecastWeeklyObj.year;
                        weeklyForecastRec.Month__c = forecastWeeklyObj.month;
                        weeklyForecastRec.Month_Name__c = forecastWeeklyObj.monthName;
                        weeklyForecastRec.Week_Number__c = forecastWeeklyObj.yearWeekCnt;
                        weeklyForecastRec.Week_Start_Date__c = forecastWeeklyObj.startDate;
                        weeklyForecastRec.Week_End_Date__c = forecastWeeklyObj.endDate;
                        weeklyForecastRec.Forecast_Qty__c = forecastWeeklyObj.forecastQty;
                        weeklyForecastRec.Week_Start_Date__c = forecastWeeklyObj.startDate;
                        weeklyForecastRec.Week_End_Date__c = forecastWeeklyObj.endDate;
                        weeklyForecastRec.Actual_Qty__c = forecastWeeklyObj.actualQty;
                        weeklyForecastRec.Branch__c = prodObj.branch;   
                        weeklyForecastRec.Branch_Code__c = prodObj.branchCode;   
                        weeklyForecastRec.Monthly_AOP__c = forecastWeeklyObj.mopId;
                        //weeklyForecastRec.Region__c = prodObj.region;
                            if(regionMap.containsKey(prodObj.region)){
                                weeklyForecastRec.Region__c = regionMap.get(prodObj.region);
                            }
                        }
                        mapUniqueKey_ForecastRec.put(weeklyForecastRec.Unique_Key_Weekly_Forecast__c, weeklyForecastRec);
                    }
                }
            }
        try{
           upsert mapUniqueKey_ForecastRec.values() Unique_Key_Weekly_Forecast__c; 
        }
        Catch(Exception e){
            System.debug('The following exception has occurred: ' + e.getMessage());
        }
    }
    
     @AuraEnabled
    public static Map<Boolean,String> submitForecastRecords(String selectedBranchName, Integer selectedBranchCode, String selectedRegionCode){
        Map<Boolean,String> booleanMessageMap = new Map<Boolean,String>();
		Date nextMonthDate =  System.today().addMonths(1);
        Integer year = nextMonthDate.year();
        Integer nextMonthNumber = nextMonthDate.month();
        system.debug('selectedRegionCode'+selectedRegionCode);
        List<CIty__c> regionLst = [Select Id,Name,Region_Code__c From CIty__c Where Region_Code__c =: selectedRegionCode Limit 1];
        system.debug('regionLst'+regionLst);
        Forecast_Submission_History__c forecastHistory = new Forecast_Submission_History__c();
        forecastHistory.Submitted_By__c = UserInfo.getUserId();
        forecastHistory.Status__c = 'Submitted';
        forecastHistory.Submitted_For_Month__c = String.valueOf(nextMonthNumber);
        forecastHistory.Submitted_For_Year__c = String.valueOf(year);
        forecastHistory.Submission_Date__c = system.today();
        forecastHistory.Branch__c = selectedBranchName;
        forecastHistory.Delivery_Plant_Code__c = selectedBranchCode;
        if(regionLst.size() > 0){
           forecastHistory.Region__c = regionLst[0].Id;
        }
        insert forecastHistory;
        system.debug('forecastHistory'+forecastHistory);
        booleanMessageMap.put(true,'Report is submitted');
        return booleanMessageMap;
    }
    
    @AuraEnabled
    public static Map<Boolean,String> checkSubmitButton(String selectedmonthNumber, String selectedmonthYear, String selectedRegionCode,
                                                        String selectedBranchName, String selectedBranchCode){
        Map<Boolean,String> booleanMessageMap = new Map<Boolean,String>();
        String nextMonthNumber = String.valueOf(system.today().addMonths(1).month());
        Set<integer> dateSt = new Set<integer>();
        Integer nextMonth;  
        Integer nextYear;                                                      
        List<CIty__c> regionLst = [Select Id,Name,Region_Code__c From CIty__c Where Region_Code__c =: String.valueOf(selectedRegionCode) Limit 1];
        Weekly_Forecast_Settings__c forecastSettings = [Select Id,Submission_Closing_Date__c,Submission_Opening_Date__c From 
                                                        Weekly_Forecast_Settings__c];
        
        date submissionOpeningDate = date.newInstance(system.today().year(),system.today().month(),Integer.valueOf(forecastSettings.Submission_Opening_Date__c));
        date submissionClosingDate = date.newInstance(system.today().year(),system.today().month(),Integer.valueOf(forecastSettings.Submission_Closing_Date__c));
         String strSubmissionOpeningDate = String.valueOf(submissionOpeningDate).removeEnd(' 00:00:00');
         String strSubmissionClosingDate  = String.valueOf(submissionClosingDate).removeEnd(' 00:00:00');
                                             
    	
        date selDate  = date.newInstance(integer.valueOf(selectedmonthYear),integer.valueOf(selectedmonthNumber),1);
       if(selDate.month() == 12){
           nextMonth = selDate.addMonths(1).month();
           nextYear = selDate.addYears(1).year();
       }                                                     
       else{
           nextMonth = selDate.addMonths(1).month();
           nextYear = selDate.year();
       }
        system.debug('selDate.month()'+selDate.month());                                                   
		system.debug('nextMonth'+nextMonth); 
       system.debug('nextYear'+nextYear); 
        List<Forecast_Submission_History__c> forecastHistory = [Select Id,Status__c,Submitted_By__c,Submitted_For_Month__c,Submitted_For_Year__c
                                                                From Forecast_Submission_History__c 
                                                                Where Submitted_For_Month__c =: string.valueOf(nextMonth)
                                                                and Submitted_For_Year__c =: string.valueOf(nextYear) 
                                                                and Submitted_By__c = : UserInfo.getUserId() and Branch__c =: selectedBranchName
                                                               and Delivery_Plant_Code__c =: Integer.valueOf(selectedBranchCode) and 
                                                                Region__r.Region_Code__c =: String.valueOf(selectedRegionCode)];	        

        //system.debug('forecastHistory'+forecastHistory);
		
        
            if(forecastHistory.size() == 0){
                system.debug('forecastHistory');
                if(system.today().month()== selDate.month() && system.today().year()== selDate.year()){
                    system.debug('inside current month if');
                    if(system.today() < submissionOpeningDate)
                        booleanMessageMap.put(true,'Button will be enabled between' + strSubmissionOpeningDate +' '+ '-' + ' ' + strSubmissionClosingDate);
                    else if(system.today() > submissionOpeningDate && system.today() <= submissionClosingDate){
                        booleanMessageMap.put(false,'Button will be available till '+strSubmissionClosingDate);	    
                    }
                    else if(system.today() > submissionClosingDate){ //1oct2019
                        system.debug('booleanMessageMap'+booleanMessageMap);
                        booleanMessageMap.put(true,'Pending for submission.Please contact administrator to submit the report.');
                    }
                }else if(selDate > system.today()){
                    booleanMessageMap.put(true,'Button will be enabled when selected month is current month.');
                }
                /*else if((system.today() > submissionClosingDate) || (system.today() > selDate)){ //1oct2019
                    system.debug('booleanMessageMap'+booleanMessageMap);
                    booleanMessageMap.put(true,'Pending for submission.Please contact administrator to submit the report.');
                }*/
                else if(system.today() > selDate){ //1oct2019
                    system.debug('booleanMessageMap'+booleanMessageMap);
                    booleanMessageMap.put(true,'Pending for submission.Please contact administrator to submit the report.');
                }
                
            } else {
                 booleanMessageMap.put(true,'Report for selected month is already submitted.');
            }
        
        
                system.debug('booleanMessageMap'+booleanMessageMap);
        
        return booleanMessageMap;
    }
}
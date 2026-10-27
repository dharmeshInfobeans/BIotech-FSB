@isTest
public class Test_WeeklyForecastController {
    static testMethod void runTestCases(){
        User rsmUser = [Select id,Name,Profile.Name,isActive from User where Profile.Name='System Administrator' AND isActive=true limit 1];//TestDataFactory.createUserData( 'System Administrator');
        System.runAs(rsmUser){
            List<City__c> regionLst = TestDataFactory.createRegionData(1, 'Delhi', '30', 'IN');
            system.debug('regionLst'+regionLst[0]);
            List<Product__c> testProductLst = TestDataFactory.createProductData();
            List<Monthly_AOP__c> mAOPLst =  TestDataFactory.createMonthlyAOPData(1, testProductLst[0], 'Nov', '2019');
            List<BranchFormDataVsLocation__c> branch = TestDataFactory.createBranchData(1, 'Delhi', '30', '1315', 'Delhi');
            List<User_Region_Association__c> userRegion = TestDataFactory.createUserRegionAssociationData(1, rsmUser, regionLst[0]);
            List<Weekly_Forecast_Settings__c>  weeklyForecastSetting = TestDataFactory.createWeeklyForecastSettingRecords(1);
             List<Forecast_Submission_History__c> forecastHistory = TestDataFactory.submitForecastRecords(1,rsmUser.id);
            List<Weekly_Forecast__c> weeklyForecast = TestDataFactory.createWeeklyForecastRecords(1, testProductLst[0], 11, 10, 20, 'November',
                                                                                                  2019, 45, 'Delhi', '1315',30);
            
            Map<string,string> AOPMAP = new Map<string,string>();
            
            for(Monthly_AOP__c mop : mAOPLst){
                 AOPMAP.put(mop.Start_Date__c+'-'+mop.Product__c,mop.id);
             }
            
            map<String,String> userForecastHistoryMap = new map<String,String>();
            
              for(Forecast_Submission_History__c forecastHistory1 : forecastHistory){
               userForecastHistoryMap.put(forecastHistory1.Submitted_For_Month__c+'-'+forecastHistory1.Submitted_For_Year__c,forecastHistory1.Submitted_By__c);
           }
            
            
            map<Date, integer> mapDate_WeekNum = new map<Date,integer>();
            mapDate_WeekNum.put( system.today(), 49);
  			
            
     
            
            string prodId = testProductLst[0].id;
            String prodName = testProductLst[0].name;
            system.debug('prodId'+prodId);
            system.debug('prodId'+testProductLst[0].id);
            system.debug('prodName'+prodName);
            String forecastJSOn = '{"endDate":"2020-01-01","nextMonth":2,"selDate":"2019-11-01","selMonth":11,"selMonthName":"November","selYear":2019,"startDate":"2019-11-01","weeklyProductObj":[{"branch":"Delhi","branchCode":"1305","lstMonthWiseWeeks":[{"isDisabled":true,"month":11,"monthName":"November","monthShortName":"Nov","monthYear":"112019","startDate":"2019-11-01","thCls":"monthTh4WeekCls","totalActual":0,"totalForecast":0,"weeklyForecastObj":[{"actualQty":0,"endDate":"2019-11-10","forecastQty":0,"globalWeekCount":0,"month":11,"monthName":"November","startDate":"2019-11-04","uniqueKey":"prodId.id_1390_2019_11_45","weekNumber":1,"year":2019,"yearWeekCnt":45},{"actualQty":0,"endDate":"2019-11-17","forecastQty":0,"globalWeekCount":1,"month":11,"monthName":"November","startDate":"2019-11-11","uniqueKey":"prodId.id_1390_2019_11_46","weekNumber":2,"year":2019,"yearWeekCnt":46},{"actualQty":0,"endDate":"2019-11-24","forecastQty":0,"globalWeekCount":2,"month":11,"monthName":"November","startDate":"2019-11-18","uniqueKey":"prodId.id_1390_2019_11_47","weekNumber":3,"year":2019,"yearWeekCnt":47},{"actualQty":0,"endDate":"2019-12-01","forecastQty":0,"globalWeekCount":3,"month":11,"monthName":"November","startDate":"2019-11-25","uniqueKey":"prodId.id_1390_2019_11_48","weekNumber":4,"year":2019,"yearWeekCnt":48}],"year":2019},{"isDisabled":false,"month":12,"monthName":"December","monthShortName":"Dec","monthYear":"122019","startDate":"2019-12-01","thCls":"monthTh4WeekCls","totalActual":0,"totalForecast":0,"weeklyForecastObj":[{"actualQty":0,"endDate":"2019-12-08","forecastQty":0,"globalWeekCount":4,"month":12,"monthName":"December","startDate":"2019-12-02","uniqueKey":"prodId.Id_1390_2019_12_49","weekNumber":1,"year":2019,"yearWeekCnt":49},{"actualQty":0,"endDate":"2019-12-15","forecastQty":0,"globalWeekCount":5,"month":12,"monthName":"December","startDate":"2019-12-09","uniqueKey":"prodId.id_1390_2019_12_50","weekNumber":2,"year":2019,"yearWeekCnt":50},{"actualQty":0,"endDate":"2019-12-22","forecastQty":0,"globalWeekCount":6,"month":12,"monthName":"December","startDate":"2019-12-16","uniqueKey":"prodId.id_1390_2019_12_51","weekNumber":3,"year":2019,"yearWeekCnt":51},{"actualQty":0,"endDate":"2019-12-29","forecastQty":0,"globalWeekCount":7,"month":12,"monthName":"December","startDate":"2019-12-23","uniqueKey":"prodId.id_1390_2019_12_52","weekNumber":4,"year":2019,"yearWeekCnt":52}],"year":2019},{"isDisabled":false,"month":1,"monthName":"January","monthShortName":"Jan","monthYear":"12020","startDate":"2020-01-01","thCls":"monthTh5WeekCls","totalActual":0,"totalForecast":0,"weeklyForecastObj":[{"actualQty":0,"endDate":"2020-01-05","forecastQty":0,"globalWeekCount":7,"month":1,"monthName":"January","startDate":"2019-12-30","uniqueKey":"prodId.id_1390_2020_1_1","weekNumber":1,"year":2020,"yearWeekCnt":1},{"actualQty":0,"endDate":"2020-01-12","forecastQty":0,"globalWeekCount":8,"month":1,"monthName":"January","startDate":"2020-01-06","uniqueKey":"prodId.id_1390_2020_1_2","weekNumber":2,"year":2020,"yearWeekCnt":2},{"actualQty":0,"endDate":"2020-01-19","forecastQty":0,"globalWeekCount":9,"month":1,"monthName":"January","startDate":"2020-01-13","uniqueKey":"prodId.id_1390_2020_1_3","weekNumber":3,"year":2020,"yearWeekCnt":3},{"actualQty":0,"endDate":"2020-01-26","forecastQty":0,"globalWeekCount":10,"month":1,"monthName":"January","startDate":"2020-01-20","uniqueKey":"prodId.id_1390_2020_1_4","weekNumber":4,"year":2020,"yearWeekCnt":4},{"actualQty":0,"endDate":"2020-02-02","forecastQty":0,"globalWeekCount":11,"month":1,"monthName":"January","startDate":"2020-01-27","uniqueKey":"prodId.id_1390_2020_1_5","weekNumber":5,"year":2020,"yearWeekCnt":5}],"year":2020}],"productId":"prodId.id","productName":"prodName","region":"19"}]}';
           //String forecastJSOn = '{"endDate":"2020-01-01","nextMonth":2,"selDate":"2019-11-01","selMonth":11,"selMonthName":"November","selYear":2019,"startDate":"2019-11-01","weeklyProductObj":[{"branch":"Delhi","branchCode":"1305","lstMonthWiseWeeks":[{"isDisabled":true,"month":11,"monthName":"November","monthShortName":"Nov","monthYear":"112019","startDate":"2019-11-01","thCls":"monthTh4WeekCls","totalActual":0,"totalForecast":0,"weeklyForecastObj":[{"actualQty":0,"endDate":"2019-11-10","forecastQty":0,"globalWeekCount":0,"month":11,"monthName":"November","startDate":"2019-11-04","weekNumber":1,"year":2019,"yearWeekCnt":45},{"actualQty":0,"endDate":"2019-11-17","forecastQty":0,"globalWeekCount":1,"month":11,"monthName":"November","startDate":"2019-11-11","weekNumber":2,"year":2019,"yearWeekCnt":46},{"actualQty":0,"endDate":"2019-11-24","forecastQty":0,"globalWeekCount":2,"month":11,"monthName":"November","startDate":"2019-11-18","weekNumber":3,"year":2019,"yearWeekCnt":47},{"actualQty":0,"endDate":"2019-12-01","forecastQty":0,"globalWeekCount":3,"month":11,"monthName":"November","startDate":"2019-11-25","weekNumber":4,"year":2019,"yearWeekCnt":48}],"year":2019},{"isDisabled":false,"month":12,"monthName":"December","monthShortName":"Dec","monthYear":"122019","startDate":"2019-12-01","thCls":"monthTh4WeekCls","totalActual":0,"totalForecast":0,"weeklyForecastObj":[{"actualQty":0,"endDate":"2019-12-08","forecastQty":0,"globalWeekCount":4,"month":12,"monthName":"December","startDate":"2019-12-02","weekNumber":1,"year":2019,"yearWeekCnt":49},{"actualQty":0,"endDate":"2019-12-15","forecastQty":0,"globalWeekCount":5,"month":12,"monthName":"December","startDate":"2019-12-09","weekNumber":2,"year":2019,"yearWeekCnt":50},{"actualQty":0,"endDate":"2019-12-22","forecastQty":0,"globalWeekCount":6,"month":12,"monthName":"December","startDate":"2019-12-16","weekNumber":3,"year":2019,"yearWeekCnt":51},{"actualQty":0,"endDate":"2019-12-29","forecastQty":0,"globalWeekCount":7,"month":12,"monthName":"December","startDate":"2019-12-23","weekNumber":4,"year":2019,"yearWeekCnt":52}],"year":2019},{"isDisabled":false,"month":1,"monthName":"January","monthShortName":"Jan","monthYear":"12020","startDate":"2020-01-01","thCls":"monthTh5WeekCls","totalActual":0,"totalForecast":0,"weeklyForecastObj":[{"actualQty":0,"endDate":"2020-01-05","forecastQty":0,"globalWeekCount":7,"month":1,"monthName":"January","startDate":"2019-12-30","weekNumber":1,"year":2020,"yearWeekCnt":1},{"actualQty":0,"endDate":"2020-01-12","forecastQty":0,"globalWeekCount":8,"month":1,"monthName":"January","startDate":"2020-01-06","weekNumber":2,"year":2020,"yearWeekCnt":2},{"actualQty":0,"endDate":"2020-01-19","forecastQty":0,"globalWeekCount":9,"month":1,"monthName":"January","startDate":"2020-01-13","weekNumber":3,"year":2020,"yearWeekCnt":3},{"actualQty":0,"endDate":"2020-01-26","forecastQty":0,"globalWeekCount":10,"month":1,"monthName":"January","startDate":"2020-01-20","weekNumber":4,"year":2020,"yearWeekCnt":4},{"actualQty":0,"endDate":"2020-02-02","forecastQty":0,"globalWeekCount":11,"month":1,"monthName":"January","startDate":"2020-01-27","weekNumber":5,"year":2020,"yearWeekCnt":5}],"year":2020}],"productId":prodId.id,"productName":"prodName","region":"19"}]}';
           
               
            Test.startTest();
            WeeklyForecastController.fetchRegionLst(rsmUser.Id); 
            WeeklyForecastController.fetchRelatedBranchLst('30');
            WeeklyForecastController.GetCurrentMonthName('1');
            WeeklyForecastController.GetCurrentMonthName('2');
            WeeklyForecastController.GetCurrentMonthName('3');
            WeeklyForecastController.GetCurrentMonthName('4');
            WeeklyForecastController.GetCurrentMonthName('5');
            WeeklyForecastController.GetCurrentMonthName('6');  
            WeeklyForecastController.GetCurrentMonthName('7');
            WeeklyForecastController.GetCurrentMonthName('8');
            WeeklyForecastController.GetCurrentMonthName('9');
            WeeklyForecastController.GetCurrentMonthName('10');
            WeeklyForecastController.GetCurrentMonthName('11');
            WeeklyForecastController.GetCurrentMonthName('12');
            WeeklyForecastController.getWeeklyForecastDetails(rsmUser.Id, '2019', '30', 'Delhi', '1315', '11',1,1);
            WeeklyForecastController.submitForecastRecords('Delhi',1315,'30');
            date stdate = system.today();
            date endate = system.today().addDays(7);
            WeeklyForecastController.getYearwiseWeeks(stdate, endate);
         //WeeklyForecastController.getWeekWiseDetails(stdate, testProductLst[0].id, 'Delhi', endate, stdate, '1315', weeklyForecastSetting[0], AOPMAP, userForecastHistoryMap, mapDate_WeekNum);
          // WeeklyForecastController.checkIfSubmitButtonEnabled();
          // 
          WeeklyForecastController.checkSubmitButton('12','2019', '1315', 'Delhi', '30');
         // Demo.saveForecastRecords('forecastJSOn');
            
            
            
            Test.stopTest();
        }
    }
}
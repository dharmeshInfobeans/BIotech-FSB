@isTest
public class TestDealerPortalForecastController{
    static testMethod void runTestCases(){
        Id systemAdminProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id;
        Id internationalPortalProfileId = [SELECT Id FROM Profile WHERE Name = 'Biotech Partner Community'].Id; 
        Id RBMRoleId = [SELECT Id FROM UserRole WHERE (Name like'RBM%') LIMIT 1].Id;        

        User systemAdmin = RollingForecast_DataHandler.createUser(systemAdminProfileId, 'International', RBMRoleId,'EP-93854', 'I;II;III;IV;V', null); 
        
        System.runAs(systemAdmin){   
         
            CIty__c MiamiRegion = RollingForecast_DataHandler.createRegionData('Miami', '90', 'US');
            
            Account internationalAcc =RollingForecast_DataHandler.createAccForInternational(MiamiRegion, '873890');
            internationalAcc.recordTypeId=[Select id,DeveloperName from RecordType where SobjectType ='Account' AND DeveloperName='Dealer_Portal'][0].Id;
            update internationalAcc;
            Contact partnerContact = IB_TestDataFactory.createContact(internationalAcc.Id, 'Geller');
            
            Product__c internationalProd = RollingForecast_DataHandler.createProductData('I', 'International', 'U-987', 'International Product');
            
            User partnerUser = RollingForecast_DataHandler.createUser(internationalPortalProfileId, 'International', null, 'E94889', 'I;II', partnerContact.Id);
            Z_Incentive__c testZIncentive = RollingForecast_DataHandler.createZInctRecordsforInternational(internationalAcc.SAP_Code__c, partnerUser.Employee_Code__c, internationalProd.Dummy_Product_Code__c, 1, 2, date.newInstance(2019, 12, 01));
                        
            Master_Agreement__c testMasterAgreement = RollingForecast_DataHandler.createMasterAgreements(internationalAcc.Id,date.newInstance(2019, 04, 01),date.newInstance(2020, 03, 31));
			Agreement_Product__c agreementProduct = RollingForecast_DataHandler.createAgreementProduct(internationalProd.Id, testMasterAgreement.Id);
            Agreement_Product_Target__c agreementProductTarget = RollingForecast_DataHandler.createAgreementProductTarget(agreementProduct.Id, 10, 2019,date.newInstance(2019, 04, 01),date.newInstance(2020, 03, 31));
            Master_Agreement__c updatetestMasterAgreement =[Select id,Is_Active__c from Master_Agreement__c where Id =:testMasterAgreement.Id];
			System.debug('updatetestMasterAgreement'+updatetestMasterAgreement);           
            updatetestMasterAgreement.Is_Active__c=true;
            update updatetestMasterAgreement;

            DealerPortalForecastController.WeeklyForecastWrapper weeklyWrapper= RollingForecast_DataHandler.getWeeklyForecastWrapperdata();
                      	
            DealerPortalForecastController.MonthWiseWeeksWrapper monthWrapper = RollingForecast_DataHandler.getMonthForecastWrapperdata();
            List<DealerPortalForecastController.MonthWiseWeeksWrapper> lstmonthWrapper=new List<DealerPortalForecastController.MonthWiseWeeksWrapper>();
            lstmonthWrapper.add(monthWrapper);

            DealerPortalForecastController.WeeklyProductWrapper WeeklyProductWrapper = RollingForecast_DataHandler.getWeeklyProductWrapperdata();
            List<DealerPortalForecastController.WeeklyForecastWrapper> lstweeklyWrapper = new List<DealerPortalForecastController.WeeklyForecastWrapper>();
            lstweeklyWrapper.add(weeklyWrapper);
            
                
            
            systemAdmin.contactId=partnerContact.Id;
            test.startTest();
            DealerPortalForecastController.fetchUserDetails();
            DealerPortalForecastController.fetchAccountDetails(partnerContact.Id);
            DealerPortalForecastController.GetMonthName(1);
            DealerPortalForecastController.GetMonthName(2);
            DealerPortalForecastController.GetMonthName(3);
            DealerPortalForecastController.GetMonthName(4);
            DealerPortalForecastController.GetMonthName(5);
            DealerPortalForecastController.GetMonthName(6);
            DealerPortalForecastController.GetMonthName(7);
            DealerPortalForecastController.GetMonthName(8);
            DealerPortalForecastController.GetMonthName(9);
            DealerPortalForecastController.GetMonthName(10);
            DealerPortalForecastController.GetMonthName(11);
            DealerPortalForecastController.GetMonthName(12);
            DealerPortalForecastController.RollingForecastWrapper rollingForecastWrapper = DealerPortalForecastController.getWeeklyForecastDetails(2019,internationalAcc.SAP_Code__c,11,1,10,2019,2);
           	test.stopTest();
            }   
    
    }
   
    static testMethod void testSavePortalForecastRecords() {
        Id systemAdminProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id;
        Id internationalPortalProfileId = [SELECT Id FROM Profile WHERE Name = 'Biotech Partner Community'].Id; 
        Id RBMRoleId = [SELECT Id FROM UserRole WHERE (Name like'RBM%') LIMIT 1].Id;        

        User systemAdmin = RollingForecast_DataHandler.createUser(systemAdminProfileId, 'International', RBMRoleId, 'EP-93854', 'I;II;III;IV;V', null); 
        
        System.runAs(systemAdmin) {   
            CIty__c MiamiRegion = RollingForecast_DataHandler.createRegionData('Miami', '90', 'US');
            Account internationalAcc = RollingForecast_DataHandler.createAccForInternational(MiamiRegion, '873890');
            internationalAcc.RecordTypeId = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Dealer_Portal' LIMIT 1].Id;
            update internationalAcc;
            Contact partnerContact = IB_TestDataFactory.createContact(internationalAcc.Id, 'Geller');

            Product__c internationalProd = RollingForecast_DataHandler.createProductData('I', 'International', 'U-987', 'International Product');
            User partnerUser = RollingForecast_DataHandler.createUser(internationalPortalProfileId, 'International', null, 'E94889', 'I;II', partnerContact.Id);

            Z_Incentive__c testZIncentive = RollingForecast_DataHandler.createZInctRecordsforInternational(
                internationalAcc.SAP_Code__c, partnerUser.Employee_Code__c, internationalProd.Dummy_Product_Code__c, 1, 2, date.newInstance(2019, 12, 1));

            Master_Agreement__c testMasterAgreement = RollingForecast_DataHandler.createMasterAgreements(
                internationalAcc.Id, date.newInstance(2019, 4, 1), date.newInstance(2020, 3, 31));

            Agreement_Product__c agreementProduct = RollingForecast_DataHandler.createAgreementProduct(internationalProd.Id, testMasterAgreement.Id);
            Agreement_Product_Target__c agreementProductTarget = RollingForecast_DataHandler.createAgreementProductTarget(
                agreementProduct.Id, 10, 2019, date.newInstance(2019, 4, 1), date.newInstance(2020, 3, 31));

            testMasterAgreement.Is_Active__c = true;
            update testMasterAgreement;

            // Prepare forecast wrapper
            DealerPortalForecastController.WeeklyForecastWrapper weeklyForecast = new DealerPortalForecastController.WeeklyForecastWrapper();
            weeklyForecast.uniqueKey = agreementProduct.Id + '_2019_11_1';
            weeklyForecast.year = 2019;
            weeklyForecast.month = 11;
            weeklyForecast.monthName = 'November';
            weeklyForecast.yearWeekCnt = 1;
            weeklyForecast.startDate = Date.newInstance(2019, 11, 1);
            weeklyForecast.endDate = Date.newInstance(2019, 11, 7);
            weeklyForecast.forecastQty = 100;

            DealerPortalForecastController.MonthWiseWeeksWrapper monthWrapper = new DealerPortalForecastController.MonthWiseWeeksWrapper();
            monthWrapper.agreementProdId = agreementProduct.Id;
            monthWrapper.totalMonthlyActualQty = 50;
            monthWrapper.weeklyForecastObj = new List<DealerPortalForecastController.WeeklyForecastWrapper>{ weeklyForecast };
            monthWrapper.startDate = Date.newInstance(2019, 11, 1);
            monthWrapper.endDate = Date.newInstance(2019, 11, 30);

            DealerPortalForecastController.WeeklyProductWrapper productWrapper = new DealerPortalForecastController.WeeklyProductWrapper();
            productWrapper.customerCode = internationalAcc.SAP_Code__c;
            productWrapper.lstMonthWiseWeeks = new List<DealerPortalForecastController.MonthWiseWeeksWrapper>{ monthWrapper };
            productWrapper.totalActualQty = 50;

            DealerPortalForecastController.RollingForecastWrapper wrapper = new DealerPortalForecastController.RollingForecastWrapper();
            wrapper.weeklyProductObj = new List<DealerPortalForecastController.WeeklyProductWrapper>{ productWrapper };

            String jsonInput = JSON.serialize(wrapper);

            System.runAs(partnerUser) {
                Test.startTest();
                DealerPortalForecastController.savePortalForecastRecords(jsonInput);
                Test.stopTest();
            }

            // Validate forecast record was created
            List<Partner_Rolling_Forecast__c> forecasts = [
                SELECT Id, Unique_Key__c, Forecast_Qty__c, Account__c
                FROM Partner_Rolling_Forecast__c
                WHERE Unique_Key__c = :weeklyForecast.uniqueKey
            ];
            System.assertEquals(1, forecasts.size());
            System.assertEquals(100, forecasts[0].Forecast_Qty__c);
        }
    }

    @isTest
    static void testUpdateMonthwiseWeekWrapper() {
        // Create Region and Account
        CIty__c city = RollingForecast_DataHandler.createRegionData('TestRegion', '99', 'US');
        Account acc = RollingForecast_DataHandler.createAccForInternational(city, 'TEST123');
        acc.RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Dealer_Portal' LIMIT 1].Id;
        update acc;

        // Create Product
        Product__c product = RollingForecast_DataHandler.createProductData('I', 'International', 'U-111', 'Test Product');

        // Create Master Agreement with specific date range
        Date startDate = Date.today().addMonths(-1);
        Date endDate = Date.today().addMonths(1);
        Master_Agreement__c ma = RollingForecast_DataHandler.createMasterAgreements(acc.Id, startDate, endDate);

        // Create Agreement Product and attach master agreement to it manually
        Agreement_Product__c ap = RollingForecast_DataHandler.createAgreementProduct(product.Id, ma.Id);
        ap.Master_Agreement__r = ma; // manually populate for testing logic

        // Prepare wrapper data
        DealerPortalForecastController.WeeklyForecastWrapper forecast = new DealerPortalForecastController.WeeklyForecastWrapper();
        forecast.uniqueKey = 'oldKey_001';
        forecast.year = Date.today().year();
        forecast.month = Date.today().month();
        forecast.monthName = 'June';
        forecast.yearWeekCnt = 23;
        forecast.startDate = Date.today();
        forecast.endDate = Date.today().addDays(6);
        forecast.forecastQty = 100;

        DealerPortalForecastController.MonthWiseWeeksWrapper monthWrapper = new DealerPortalForecastController.MonthWiseWeeksWrapper();
        monthWrapper.startDate = Date.today();
        monthWrapper.endDate = Date.today().addDays(6);
        monthWrapper.weeklyForecastObj = new List<DealerPortalForecastController.WeeklyForecastWrapper>{ forecast };

        List<DealerPortalForecastController.MonthWiseWeeksWrapper> monthList = new List<DealerPortalForecastController.MonthWiseWeeksWrapper>{ monthWrapper };

        Test.startTest();
        List<DealerPortalForecastController.MonthWiseWeeksWrapper> updatedList = DealerPortalForecastController.updateMonhwiseWeekWrapper(monthList, ap);
        Test.stopTest();

        // Assertions
        System.assertEquals(ap.Id, updatedList[0].agreementProdId, 'Agreement Product ID should be updated');
        System.assertEquals(false, updatedList[0].isDisabled, 'isDisabled flag should be false');
        System.assert(updatedList[0].weeklyForecastObj[0].uniqueKey.startsWith(ap.Id), 'Unique key should start with agreement product ID');
    }


}
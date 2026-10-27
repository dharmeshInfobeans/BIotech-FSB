@isTest
public class TestInternalForecastConsoleController {
    @isTest
    static void testForecastConsoleFlows() {
        Id systemAdminProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id;
        Id internationalPortalProfileId = [SELECT Id FROM Profile WHERE Name = 'Biotech Partner Community'].Id; 
        Id RBMRoleId = [SELECT Id FROM UserRole WHERE (Name like 'RBM%') LIMIT 1].Id;        
        
        User systemAdmin = RollingForecast_DataHandler.createUser(systemAdminProfileId, 'International', RBMRoleId, 'EP-93854', 'I;II;III;IV;V', null); 
        
        System.runAs(systemAdmin) {   
            CIty__c MiamiRegion = RollingForecast_DataHandler.createRegionData('Miami', '90', 'US');
            Account internationalAcc = RollingForecast_DataHandler.createAccForInternational(MiamiRegion, '873890');
            internationalAcc.RecordTypeId = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Dealer_Portal' LIMIT 1].Id;
            update internationalAcc;
            Contact partnerContact = IB_TestDataFactory.createContact(internationalAcc.Id, 'Geller');
            
            Product__c internationalProd = RollingForecast_DataHandler.createProductData('I', 'International', 'U-987', 'International Product');
            User partnerUser = RollingForecast_DataHandler.createUser(internationalPortalProfileId, 'International', null, 'E94889', 'I;II', partnerContact.Id);
            
            Z_Incentive__c testZIncentive = RollingForecast_DataHandler.createZInctRecordsforInternational(internationalAcc.SAP_Code__c, partnerUser.Employee_Code__c, internationalProd.Dummy_Product_Code__c, 1, 2, Date.newInstance(2019, 12, 1));
            
            Master_Agreement__c testMasterAgreement = RollingForecast_DataHandler.createMasterAgreements(internationalAcc.Id, Date.newInstance(2019, 4, 1), Date.newInstance(2020, 3, 31));
            
            Agreement_Product__c agreementProduct = RollingForecast_DataHandler.createAgreementProduct(internationalProd.Id, testMasterAgreement.Id);
            Agreement_Product_Target__c agreementProductTarget = RollingForecast_DataHandler.createAgreementProductTarget(agreementProduct.Id, 10, 2019, Date.newInstance(2019, 4, 1), Date.newInstance(2020, 3, 31));
            
            testMasterAgreement.Is_Active__c = true;
            update testMasterAgreement;
            
            Test.startTest();
            InternalForecastConsoleController.fetchUserDetails();
            InternalForecastConsoleController.fetchAccountDetails(partnerContact.Id);
            InternalForecastConsoleController.GetMonthName(1);
            
            // Query forecast details
            InternalForecastConsoleController.RollingForecastWrapper wrapper = InternalForecastConsoleController.getWeeklyForecastDetails(2019, internationalAcc.SAP_Code__c, 11, 1, 10, 2019, 12);
            
            System.assertNotEquals(null, wrapper, 'Wrapper should be returned');
            
            // Prepare saving data
            InternalForecastConsoleController.WeeklyForecastWrapper weeklyForecast = new InternalForecastConsoleController.WeeklyForecastWrapper();
            weeklyForecast.uniqueKey = agreementProduct.Id + '_2019_11_1';
            weeklyForecast.year = 2019;
            weeklyForecast.month = 11;
            weeklyForecast.monthName = 'November';
            weeklyForecast.yearWeekCnt = 1;
            weeklyForecast.startDate = Date.newInstance(2019, 11, 1);
            weeklyForecast.endDate = Date.newInstance(2019, 11, 7);
            weeklyForecast.forecastQty = 100;
            
            InternalForecastConsoleController.MonthWiseWeeksWrapper monthWrapper = new InternalForecastConsoleController.MonthWiseWeeksWrapper();
            monthWrapper.agreementProdId = agreementProduct.Id;
            monthWrapper.totalMonthlyActualQty = 50;
            monthWrapper.weeklyForecastObj = new List<InternalForecastConsoleController.WeeklyForecastWrapper>{ weeklyForecast };
                monthWrapper.startDate = Date.newInstance(2019, 11, 1);
            monthWrapper.endDate = Date.newInstance(2019, 11, 30);
            
            InternalForecastConsoleController.WeeklyProductWrapper productWrapper = new InternalForecastConsoleController.WeeklyProductWrapper();
            productWrapper.customerCode = internationalAcc.SAP_Code__c;
            productWrapper.lstMonthWiseWeeks = new List<InternalForecastConsoleController.MonthWiseWeeksWrapper>{ monthWrapper };
                productWrapper.totalActualQty = 50;
            
            InternalForecastConsoleController.RollingForecastWrapper saveWrapper = new InternalForecastConsoleController.RollingForecastWrapper();
            saveWrapper.weeklyProductObj = new List<InternalForecastConsoleController.WeeklyProductWrapper>{ productWrapper };
                
                String jsonInput = JSON.serialize(saveWrapper);
            
            // Test save method (internal user context)
            InternalForecastConsoleController.savePortalForecastRecords(jsonInput);
            Test.stopTest();
            
            // Validate save
            List<Partner_Rolling_Forecast__c> forecasts = [
                SELECT Id, Unique_Key__c, Forecast_Qty__c, Account__c
                FROM Partner_Rolling_Forecast__c
                WHERE Unique_Key__c = :weeklyForecast.uniqueKey
            ];
            System.assertEquals(1, forecasts.size());
            System.assertEquals(100, forecasts[0].Forecast_Qty__c);
        }
    }
}
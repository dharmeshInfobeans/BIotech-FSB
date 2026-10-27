/********************************************
* @Class Name   : Test_CalculatConsumableIncentive
* @Description  : This class is used to cover following classes : Batch_MonthlyIncentiveCalculation,CalculateMonthlyIncentive, Batch_QuarterlyIncentiveCalculation, 
				  CalculateQuarterlyIncentive, createUserwiseGrouping
* @Created Date : 23-01-2020
* @Created By   : Pratiksha K. 
* ****************************************/

@isTest
public class Test_CalculatConsumableIncentive {
    static testMethod void runTestCasesForDomestic(){
        Id systemAdminProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id;
        Id domesticSalesProfileId = [SELECT Id FROM Profile WHERE Name = 'Domestic Sales'].Id;      

        Id salesEmpRoleId = [SELECT Id,name FROM UserRole WHERE (Name like'SSE%') LIMIT 1].Id;
        Id DMRoleId = [SELECT Id,name FROM UserRole WHERE (Name like'DM%') LIMIT 1].Id;
        Id RSMRoleId = [SELECT Id,name,PortalType FROM UserRole WHERE PortalType != 'Partner' And (Name like'RSM%') LIMIT 1].Id;
        Id ZDMRoleId = [SELECT Id,name FROM UserRole WHERE (Name like'ZDM%') LIMIT 1].Id;
        Id ZSMRoleId = [SELECT Id,name FROM UserRole WHERE (Name like'ZSM%') LIMIT 1].Id;
        
        User systemAdmin = Incentive_Data_Handler.createUser(systemAdminProfileId, 'Domestic', salesEmpRoleId,'EP-93854','I;II;III;IV;V'); 
        system.debug('systemAdmin'+systemAdmin);
        system.debug('RSMRoleId'+RSMRoleId);
        
        System.runAs(systemAdmin){
            User salesEmpUser = Incentive_Data_Handler.createUser(domesticSalesProfileId, 'Domestic', salesEmpRoleId, 'EP-87906', 'I;II;III;IV;V');
            system.debug('salesEmpUser'+salesEmpUser);
            User dmUser = Incentive_Data_Handler.createUser(domesticSalesProfileId, 'Domestic', DMRoleId, 'EP-58285', 'I;II;III;IV;V'); 
            system.debug('dmUser'+dmUser);
            User rsmUser = Incentive_Data_Handler.createUser(domesticSalesProfileId, 'Domestic', RSMRoleId, 'EP-44464', 'I;II;III;IV;V'); 
            User zsmUser = Incentive_Data_Handler.createUser(domesticSalesProfileId, 'Domestic', ZSMRoleId,'EP-47535', 'I;II;III;IV;V'); 
            User zdmUser = Incentive_Data_Handler.createUser(domesticSalesProfileId, 'Domestic', ZDMRoleId,'EP-54399', 'I;II;III;IV;V');   
            
            Batch_Execution_Orders__c domesticMontlysetting = Incentive_Data_Handler.createBatchExecutionOrderSetting('Domestic Monthly Incentive Details', 1, 'Monthly', 'Domestic', 'Consumable Incentive');
			Batch_Execution_Orders__c domesticQuarterlySetting = Incentive_Data_Handler.createBatchExecutionOrderSetting('Domestic Quarterly Incentive Details', 4, 'Quarterly', 'Domestic', 'Consumable Incentive');
            
            CIty__c DelhiRegion = Incentive_Data_Handler.createRegionData('Delhi', '20', 'IN');
            
            User_Region_Association__c salesEmpUserAllocation = Incentive_Data_Handler.createUserRegionAssociationData(salesEmpUser.Id, DelhiRegion.Id);
            User_Region_Association__c dmUserAllocation = Incentive_Data_Handler.createUserRegionAssociationData(dmUser.Id, DelhiRegion.Id);
            User_Region_Association__c rsmUserAllocation = Incentive_Data_Handler.createUserRegionAssociationData(rsmUser.Id, DelhiRegion.Id);
            User_Region_Association__c zsmUserAllocation = Incentive_Data_Handler.createUserRegionAssociationData(zsmUser.Id, DelhiRegion.Id);
            User_Region_Association__c zdmUserAlocation = Incentive_Data_Handler.createUserRegionAssociationData(zdmUser.Id, DelhiRegion.Id);

            Account domesticAcc = Incentive_Data_Handler.createAccountData(DelhiRegion,'4545');
            
            Product__c domesticProd = Incentive_Data_Handler.createProductData('I', 'Domestic', 'D-022', 'domestic product');
            
            Incentive_Policy__c domesticPolicyYr = Incentive_Data_Handler.createFiscalYears('Domestic', '2019-2020', date.newInstance(2019, 04, 01), date.newInstance(2020, 03, 31));

            Consumable_Incentive_Allocation__c salesEmpAllocation = Incentive_Data_Handler.createAllocationData('I', domesticPolicyYr.Id , 'SSE;SE;BDM;SSE/BDM', 50,false);
            Consumable_Incentive_Allocation__c dmAllocation = Incentive_Data_Handler.createAllocationData('I', domesticPolicyYr.Id , 'DM', 45,false);
            Consumable_Incentive_Allocation__c rsmAllocation = Incentive_Data_Handler.createAllocationData('I', domesticPolicyYr.Id , 'RSM', 5,true);
            Consumable_Incentive_Allocation__c zsmAllocation = Incentive_Data_Handler.createAllocationData('I', domesticPolicyYr.Id , 'ZSM',0,false);
            Consumable_Incentive_Allocation__c zdmAllocation = Incentive_Data_Handler.createAllocationData('I', domesticPolicyYr.Id , 'ZDM', 0,false);

            Consumable_Product_Wise_Incentive_Rate__c inctRate = Incentive_Data_Handler.createIncentiveRate(domesticProd.Id, domesticPolicyYr.Id, 30);

            ABCD_Configuration__c domesticAconfg = Incentive_Data_Handler.createConfgRecords('A', domesticPolicyYr.Id, 30, 0);
            ABCD_Configuration__c domesticBconfg = Incentive_Data_Handler.createConfgRecords('B', domesticPolicyYr.Id, 20, 80);
            ABCD_Configuration__c domesticCconfg = Incentive_Data_Handler.createConfgRecords('C', domesticPolicyYr.Id, 20, 90);
            ABCD_Configuration__c domesticDconfg = Incentive_Data_Handler.createConfgRecords('D', domesticPolicyYr.Id, 30, 100);
          
            Id domesticRecTypeId = Schema.SObjectType.Monthly_AOP__c.getRecordTypeInfosByDeveloperName().get('Domestic').getRecordTypeId();
        
            Monthly_AOP__c salesEmpMOP = Incentive_Data_Handler.createMOPTestRecords(10, 'Oct', '2019', domesticProd.Id, salesEmpUser.Id, DelhiRegion.Id,domesticRecTypeId,'Oct');
            Monthly_AOP__c dmMOP = Incentive_Data_Handler.createMOPTestRecords(20, 'Oct', '2019', domesticProd.Id, dmUser.Id, DelhiRegion.Id,domesticRecTypeId,'Oct');
            Monthly_AOP__c rsmMOP = Incentive_Data_Handler.createMOPTestRecords(30, 'Oct', '2019', domesticProd.Id, rsmUser.Id, DelhiRegion.Id,domesticRecTypeId,'Oct');
            Monthly_AOP__c zsmMOP = Incentive_Data_Handler.createMOPTestRecords(40, 'Oct', '2019', domesticProd.Id, zsmUser.Id ,DelhiRegion.Id,domesticRecTypeId,'Oct');
            Monthly_AOP__c zdmMOP = Incentive_Data_Handler.createMOPTestRecords(50, 'Oct', '2019', domesticProd.Id, zdmUser.Id, DelhiRegion.Id,domesticRecTypeId,'Oct');
			
            Date fourMonthOldDate = System.today().addMonths(-4);
            Z_Incentive__c zInct = Incentive_Data_Handler.createZInctRecordsforDomestic(domesticAcc.SAP_Code__c,salesEmpUser.Employee_Code__c,
                                                                                        dmUser.Employee_Code__c,rsmUser.Employee_Code__c,zsmUser.Employee_Code__c,
                                                                                        zdmUser.Employee_Code__c, domesticProd.Dummy_Product_Code__c, 7, 9,
                                                                                       1000, fourMonthOldDate, 'Sales', '','','','','','','','',null);

            Period last2FiscQaurterStartEndDt = [Select Id,StartDate,EndDate from period where type = 'QUARTER' AND StartDate = LAST_N_FISCAL_QUARTERS:2 AND 
                                      			StartDate != LAST_QUARTER];
            
            User_Wise_Incentive_Distribution__c salesEmpInctDistribution = Incentive_Data_Handler.createUserwiseInctDistribution(last2FiscQaurterStartEndDt.StartDate.year(),
                                                                           last2FiscQaurterStartEndDt.StartDate,last2FiscQaurterStartEndDt.EndDate,salesEmpUser.Id,
                                                                            'I','SE',salesEmpMOP.Id, domesticProd.Id,inctRate.Id,salesEmpAllocation.Id, 10);
            
            User_Wise_Incentive_Distribution__c dmInctDistribution = Incentive_Data_Handler.createUserwiseInctDistribution(last2FiscQaurterStartEndDt.StartDate.year(),
                                                                           last2FiscQaurterStartEndDt.StartDate,last2FiscQaurterStartEndDt.EndDate,dmUser.Id,
                                                                            'I','DM',dmMOP.Id, domesticProd.Id,inctRate.Id,dmAllocation.Id, 20); 
            
            User_Wise_Incentive_Distribution__c rsmInctDistribution = Incentive_Data_Handler.createUserwiseInctDistribution(last2FiscQaurterStartEndDt.StartDate.year(),
                                                                           last2FiscQaurterStartEndDt.StartDate,last2FiscQaurterStartEndDt.EndDate,rsmUser.Id,
                                                                            'I','RSM',rsmMOP.Id, domesticProd.Id,inctRate.Id,rsmAllocation.Id, 30); 
            
             User_Wise_Incentive_Distribution__c zdmInctDistribution = Incentive_Data_Handler.createUserwiseInctDistribution(last2FiscQaurterStartEndDt.StartDate.year(),
                                                                           last2FiscQaurterStartEndDt.StartDate,last2FiscQaurterStartEndDt.EndDate,zdmUser.Id,
                                                                            'I','ZDM',zdmMOP.Id, domesticProd.Id,inctRate.Id,zdmAllocation.Id, 40);
            
            User_Wise_Incentive_Distribution__c zsmInctDistribution = Incentive_Data_Handler.createUserwiseInctDistribution(last2FiscQaurterStartEndDt.StartDate.year(),
                                                                           last2FiscQaurterStartEndDt.StartDate,last2FiscQaurterStartEndDt.EndDate,zsmUser.Id,
                                                                            'I','ZSM',zsmMOP.Id, domesticProd.Id,inctRate.Id,zsmAllocation.Id, 50);

			Log_Entry__c log = Create_Log_Entries.createLogEntries('Batch', 'Failed', 'Test', 'Domestic', 'Test', 'Consumable Incentive' ,'Monthly');
			
            Date startDate = System.today().addMonths(-4).toStartOfMonth();
            Date endDate = startDate.addMonths(1).toStartofMonth().addDays(-1);
            
            Test.startTest();
            Batch_MonthlyIncentiveCalculation monthlyBatch = New Batch_MonthlyIncentiveCalculation();
            Database.executeBatch(monthlyBatch);
            Batch_MonthlyIncentiveCalculation monthlyBatch1 = New Batch_MonthlyIncentiveCalculation(startDate,endDate);
            Database.executeBatch(monthlyBatch1);
            Batch_QuarterlyIncentiveCalculation quarterlyBatch = new Batch_QuarterlyIncentiveCalculation();
            Database.executeBatch(quarterlyBatch);
            Test.stopTest();
        }
    }
}
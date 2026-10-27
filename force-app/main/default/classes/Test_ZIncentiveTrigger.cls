@isTest
public class Test_ZIncentiveTrigger {
    static testMethod void runTestCasesForDomestic(){
        Id systemAdminProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id;
        Id domesticSalesProfileId = [SELECT Id FROM Profile WHERE Name = 'Domestic Sales'].Id;
        Id turkeySalesProfileId = [SELECT Id FROM Profile WHERE Name = 'Turkey Sales'].Id;
        Id internationalSalesProfileId = [SELECT Id FROM Profile WHERE Name = 'International Sales'].Id;
        
        Id salesEmpRoleId = [SELECT Id,name FROM UserRole WHERE (Name like'SSE%') LIMIT 1].Id;
        Id DMRoleId = [SELECT Id,name FROM UserRole WHERE (Name like'DM%') LIMIT 1].Id;
        Id ASMRoleId = [SELECT Id,name FROM UserRole WHERE (Name like'ASM%') LIMIT 1].Id;
        Id RSMRoleId = [SELECT Id,name FROM UserRole WHERE (Name like'RSM Gujarat%') LIMIT 1].Id;
        Id ZDMRoleId = [SELECT Id,name FROM UserRole WHERE (Name like'ZDM%') LIMIT 1].Id;
        Id ZSMRoleId = [SELECT Id,name FROM UserRole WHERE (Name like'ZSM%') LIMIT 1].Id;
        Id SalesSpecialistRoleId = [SELECT Id,name FROM UserRole WHERE (Name like'Sales Specialist%') LIMIT 1].Id;
        Id ProductManagerRoleId = [SELECT Id,name FROM UserRole WHERE (Name like'Product Manager%') LIMIT 1].Id; 
        Id RBMRoleId = [SELECT Id,name FROM UserRole WHERE (Name like'RBM%') LIMIT 1].Id;
        
        User systemAdmin = ZIncentiveFactory.createUser(systemAdminProfileId, 'Domestic', null,'EP-93854','I;II;III;IV;V'); 
        system.debug('systemAdmin'+systemAdmin);
        
        System.runAs(systemAdmin){
            User salesEmpUser = ZIncentiveFactory.createUser(domesticSalesProfileId, 'Domestic', salesEmpRoleId, 'EP-87906','I;II;III;IV;V');
            User salesEmpUser1 = ZIncentiveFactory.createUser(domesticSalesProfileId, 'Domestic', salesEmpRoleId, 'EP-02646','I;II;III;IV;V');
            User salesEmpUser2 = ZIncentiveFactory.createUser(domesticSalesProfileId, 'Domestic', salesEmpRoleId, 'EP-02649','I;II;III;IV;V');
            User salesEmpUser3 = ZIncentiveFactory.createUser(domesticSalesProfileId, 'Domestic', salesEmpRoleId, 'EP-02652','I;II;III;IV;V');
            User salesEmpUser4 = ZIncentiveFactory.createUser(domesticSalesProfileId, 'Domestic', salesEmpRoleId, 'EP-02556','I;II;III;IV;V');
            
            User dmUser = ZIncentiveFactory.createUser(domesticSalesProfileId, 'Domestic', DMRoleId, 'EP-58285','I;II;III;IV;V');
            User dmUser1 = ZIncentiveFactory.createUser(domesticSalesProfileId, 'Domestic', DMRoleId, 'EP-58205','I;II;III;IV;V');
            User dmUser2 = ZIncentiveFactory.createUser(domesticSalesProfileId, 'Domestic', DMRoleId, 'EP-58275','I;II;III;IV;V');
            User dmUser3 = ZIncentiveFactory.createUser(domesticSalesProfileId, 'Domestic', DMRoleId, 'EP-58265','I;II;III;IV;V');
            User dmUser4 = ZIncentiveFactory.createUser(domesticSalesProfileId, 'Domestic', DMRoleId, 'EP-58255','I;II;III;IV;V');
            
            User asmUser = ZIncentiveFactory.createUser(domesticSalesProfileId, 'Domestic', ASMRoleId, 'EP-73592','I;II;III;IV;V');
            User asmUser1 = ZIncentiveFactory.createUser(domesticSalesProfileId, 'Domestic', ASMRoleId, 'EP-73592','I;II;III;IV;V');
            
            User rsmUser = ZIncentiveFactory.createUser(domesticSalesProfileId, 'Domestic', RSMRoleId, 'EP-9200','I;II;III;IV;V');
            User rsmUser1 = ZIncentiveFactory.createUser(domesticSalesProfileId, 'Domestic', RSMRoleId, 'EP-9201','I;II;III;IV;V');
            
            User zsmUser = ZIncentiveFactory.createUser(domesticSalesProfileId, 'Domestic', ZSMRoleId,'EP-47535','I;II;III;IV;V'); 
            User zsmUser1 = ZIncentiveFactory.createUser(domesticSalesProfileId, 'Domestic', ZSMRoleId,'EP-47505','I;II;III;IV;V'); 
            
            User zdmUser = ZIncentiveFactory.createUser(domesticSalesProfileId, 'Domestic', ZDMRoleId,'EP-54321','I;II;III;IV;V'); 
            User zdmUser1 = ZIncentiveFactory.createUser(domesticSalesProfileId, 'Domestic', ZDMRoleId,'EP-54301','I;II;III;IV;V'); 
            
            User salesSpeUser = ZIncentiveFactory.createUser(turkeySalesProfileId, 'Turkey', SalesSpecialistRoleId,'ET0059', 'I;II;III;IV;V'); 
            User salesSpeUser1 = ZIncentiveFactory.createUser(turkeySalesProfileId, 'Turkey', SalesSpecialistRoleId,'ET0009', 'I;II;III;IV;V'); 
            
            User turkeyRsmUser = ZIncentiveFactory.createUser(turkeySalesProfileId, 'Turkey', RSMRoleId,'ET0004', 'I;II;III;IV;V'); 
            User turkeyRsmUser1 = ZIncentiveFactory.createUser(turkeySalesProfileId, 'Turkey', RSMRoleId,'ET0014', 'I;II;III;IV;V'); 
            
            User prodMngrUser = ZIncentiveFactory.createUser(turkeySalesProfileId, 'Turkey', ProductManagerRoleId,'ET0038', 'I;II;III;IV;V');
            User prodMngrUser1 = ZIncentiveFactory.createUser(turkeySalesProfileId, 'Turkey', ProductManagerRoleId,'ET206', 'I;II;III;IV;V');
            
            User applicationSpecialistUser = ZIncentiveFactory.createUser(turkeySalesProfileId, 'Turkey', ProductManagerRoleId,'ET295', 'I;II;III;IV;V');
            User applicationSpecialistUser1 = ZIncentiveFactory.createUser(turkeySalesProfileId, 'Turkey', ProductManagerRoleId,'ET205', 'I;II;III;IV;V');
            
            User rbmuser = ZIncentiveFactory.createUser(internationalSalesProfileId, 'International', RBMRoleId, 'EP-93854', 'I;II;III;IV;V');
            
            
            CIty__c DelhiRegion = ZIncentiveFactory.createRegionData('Delhi', '20', 'IN');
            CIty__c AksarayRegion = ZIncentiveFactory.createRegionData('Aksaray', '78', 'TR');
            CIty__c MiamiRegion = ZIncentiveFactory.createRegionData('Miami', '90', 'US');
            
            
            Account domesticAcc = ZIncentiveFactory.createAccountData(DelhiRegion,'4545');
            Account turkeyAcc = ZIncentiveFactory.createAccountData(AksarayRegion, '8989');
            Account internationalAcc = ZIncentiveFactory.createAccountData(MiamiRegion, '873890');
            
            Product__c domesticProd = ZIncentiveFactory.createProductData('I', 'Domestic', 'D-022', 'domestic product 1');
            Product__c domesticProd2 = ZIncentiveFactory.createProductData('II', 'Domestic', 'D-023', 'domestic product 2');
            Product__c domesticProd3 = ZIncentiveFactory.createProductData('III', 'Domestic', 'D-024', 'domestic product 3');
            Product__c domesticProd4 = ZIncentiveFactory.createProductData('IV', 'Domestic', 'D-025', 'domestic product 4');
            Product__c domesticProd5 = ZIncentiveFactory.createProductData('v', 'Domestic', 'D-026', 'domestic product 5');
            
            Product__c turkeyProd = ZIncentiveFactory.createProductData('I', 'Turkey', 'T-090', 'Turkey Product 1');
            Product__c turkeyProd2 = ZIncentiveFactory.createProductData('II', 'Turkey', 'T-091', 'Turkey Product 2');
            Product__c turkeyProd3 = ZIncentiveFactory.createProductData('III', 'Turkey', 'T-092', 'Turkey Product 3');
            Product__c turkeyProd4 = ZIncentiveFactory.createProductData('IV', 'Turkey', 'T-093', 'Turkey Product 4');
            Product__c turkeyProd5 = ZIncentiveFactory.createProductData('V', 'Turkey', 'T-094', 'Turkey Product 5');
            
            
            Date billingDate = date.newInstance(2020, 01, 01);
            Z_Incentive__c zInct = ZIncentiveFactory.createZInctRecordsforDomestic(domesticAcc.SAP_Code__c,salesEmpUser.Employee_Code__c,dmUser.Employee_Code__c,
                                                                                   rsmUser.Employee_Code__c,zsmUser.Employee_Code__c, zdmUser.Employee_Code__c, 
                                                                                   domesticProd.Dummy_Product_Code__c, '7-', '-9','10-',billingDate,'Sales',
                                                                                   salesEmpUser1.Employee_Code__c,salesEmpUser2.Employee_Code__c,
                                                                                   salesEmpUser3.Employee_Code__c,salesEmpUser4.Employee_Code__c,
                                                                                   dmUser1.Employee_Code__c,dmUser2.Employee_Code__c,
                                                                                   dmUser3.Employee_Code__c,dmUser4.Employee_Code__c,'87-', 
                                                                                   asmUser.Employee_Code__c);
            
            Z_Incentive__c zInctForD2 = ZIncentiveFactory.createZInctRecordsforDomestic(domesticAcc.SAP_Code__c,salesEmpUser.Employee_Code__c,dmUser.Employee_Code__c,
                                                                                        rsmUser.Employee_Code__c,zsmUser.Employee_Code__c, zdmUser.Employee_Code__c, 
                                                                                        domesticProd2.Dummy_Product_Code__c, '7-', '9','10-',billingDate,'Sales',
                                                                                        salesEmpUser1.Employee_Code__c,salesEmpUser2.Employee_Code__c,
                                                                                        salesEmpUser3.Employee_Code__c,salesEmpUser4.Employee_Code__c,
                                                                                        dmUser1.Employee_Code__c,dmUser2.Employee_Code__c,
                                                                                        dmUser3.Employee_Code__c,dmUser4.Employee_Code__c,'87-', 
                                                                                        asmUser.Employee_Code__c);
            
            Z_Incentive__c zInctForD3 = ZIncentiveFactory.createZInctRecordsforDomestic(domesticAcc.SAP_Code__c,salesEmpUser.Employee_Code__c,dmUser.Employee_Code__c,
                                                                                        rsmUser.Employee_Code__c,zsmUser.Employee_Code__c, zdmUser.Employee_Code__c, 
                                                                                        domesticProd3.Dummy_Product_Code__c, '7-', '9','10-',billingDate,'Sales',
                                                                                        salesEmpUser1.Employee_Code__c,salesEmpUser2.Employee_Code__c,
                                                                                        salesEmpUser3.Employee_Code__c,salesEmpUser4.Employee_Code__c,
                                                                                        dmUser1.Employee_Code__c,dmUser2.Employee_Code__c,
                                                                                        dmUser3.Employee_Code__c,dmUser4.Employee_Code__c,'87-', 
                                                                                        asmUser.Employee_Code__c);
            
            Z_Incentive__c zInctForD4 = ZIncentiveFactory.createZInctRecordsforDomestic(domesticAcc.SAP_Code__c,salesEmpUser.Employee_Code__c,dmUser.Employee_Code__c,
                                                                                        rsmUser.Employee_Code__c,zsmUser.Employee_Code__c, zdmUser.Employee_Code__c, 
                                                                                        domesticProd4.Dummy_Product_Code__c, '7-', '9','10-',billingDate,'Sales',
                                                                                        salesEmpUser1.Employee_Code__c,salesEmpUser2.Employee_Code__c,
                                                                                        salesEmpUser3.Employee_Code__c,salesEmpUser4.Employee_Code__c,
                                                                                        dmUser1.Employee_Code__c,dmUser2.Employee_Code__c,
                                                                                        dmUser3.Employee_Code__c,dmUser4.Employee_Code__c,'87-', 
                                                                                        asmUser.Employee_Code__c);
            
            
            Z_Incentive__c zInctForD5 = ZIncentiveFactory.createZInctRecordsforDomestic(domesticAcc.SAP_Code__c,salesEmpUser.Employee_Code__c,dmUser.Employee_Code__c,
                                                                                        rsmUser.Employee_Code__c,zsmUser.Employee_Code__c, zdmUser.Employee_Code__c, 
                                                                                        domesticProd5.Dummy_Product_Code__c, '7-', '9','10-',billingDate,'Sales',
                                                                                        salesEmpUser1.Employee_Code__c,salesEmpUser2.Employee_Code__c,
                                                                                        salesEmpUser3.Employee_Code__c,salesEmpUser4.Employee_Code__c,
                                                                                        dmUser1.Employee_Code__c,dmUser2.Employee_Code__c,
                                                                                        dmUser3.Employee_Code__c,dmUser4.Employee_Code__c,'87-', 
                                                                                        asmUser.Employee_Code__c);
            
            Z_Incentive__c turkeyZInct = ZIncentiveFactory.createZInctRecordsforTurkey(turkeyAcc.SAP_Code__c,salesSpeUser.Employee_Code__c,
                                                                                       prodMngrUser.Employee_Code__c,rsmUser.Employee_Code__c,
                                                                                       turkeyProd.Dummy_Product_Code__c, 7, 9,
                                                                                       applicationSpecialistUser.Employee_Code__c);
            
            Z_Incentive__c turkeyZInctForD5 = ZIncentiveFactory.createZInctRecordsforTurkey(turkeyAcc.SAP_Code__c,salesSpeUser.Employee_Code__c,
                                                                                            prodMngrUser.Employee_Code__c,rsmUser.Employee_Code__c,
                                                                                            turkeyProd.Dummy_Product_Code__c, 7, 9,
                                                                                            applicationSpecialistUser.Employee_Code__c);          
            
            zInct.Days__c = 'OPEN';
            zInct.D1_Div_1_Sales_Employee__c = salesEmpUser4.Employee_Code__c;
            zInct.M1_Div_1_Manager__c = dmUser4.Employee_Code__c;      
            zInct.Quantity_Txt__c = '100-';
            zInct.Selling_Rate_Txt__c = '200-';
            zInct.Net_Value_Txt__c = '7';
            Update zInct;                        
            
            zInctForD2.D2_Div_2_Sales_Employee__c = salesEmpUser3.Employee_Code__c;
            zInctForD2.M2_Div_2_Manager__c = dmUser3.Employee_Code__c;
            Update zInctForD2;
            
            zInctForD3.D3_Div_3_Sales_Employee__c = salesEmpUser2.Employee_Code__c;
            zInctForD3.M3_Div_3_Manager__c = dmUser2.Employee_Code__c;
            Update zInctForD3;
            
            zInctForD4.D4_Div_4_Sales_Employee__c= salesEmpUser3.Employee_Code__c;
            zInctForD4.M4_Div_4_Manager__c= dmUser1.Employee_Code__c;
            Update zInctForD4;
            
            zInctForD5.D5_Div_5_Sales_Employee__c=salesEmpUser4.Employee_Code__c;
            zInctForD5.M5_Div_5_Manager__c=dmUser4.Employee_Code__c;
            zInctForD5.Days__c = '-90';
            Update zInctForD5;
            
            
            turkeyZInct.Application_Specialist_Emp_Code__c=applicationSpecialistUser1.Employee_Code__c;
            turkeyZInct.Product_Manager_Emp_Code__c = prodMngrUser1.Employee_Code__c;
            turkeyZInct.RSM__c= turkeyRsmUser1.Id;
            turkeyZInct.Quantity_Txt__c = '15';
            turkeyZInct.Days__c= '20-';
            turkeyZInct.No_Of_Days__c =10;
            turkeyZInct.D1_Div_1_Sales_Specialist__c = salesSpeUser1.Employee_Code__c;
            Update turkeyZInct;
            
            turkeyZInctForD5.Application_Specialist_Emp_Code__c= applicationSpecialistUser.Employee_Code__c;
            turkeyZInctForD5.Product_Manager_Emp_Code__c=prodMngrUser.Employee_Code__c;
            Update turkeyZInctForD5;
            
            Product__c internationalProd = ZIncentiveFactory.createProductData('I', 'International', 'U-987', 'International Product 1');                    
            
            Master_Agreement__c masterAgreementInternational = ZIncentiveFactory.createMasterAgreements(internationalAcc.Id, date.newInstance(2019, 04, 01), 
                                                                                                        date.newInstance(2020, 03, 31), 94);
            
            Agreement_Product__c agreementProd = ZIncentiveFactory.createAgreementProduct(internationalProd.Id, masterAgreementInternational.Id);
            
            Agreement_Product_Target__c agreementProductTarget = ZIncentiveFactory.createAgreementProductTarget(agreementProd.Id, 3, 2019,
                                                                                                                date.newInstance(2019, 04, 01),date.newInstance(2020, 03, 31));
            
            
            Partner_Rolling_Forecast__c partnerRollingForecastDom = ZIncentiveFactory.createPartnerRollingForecast(internationalAcc.Id, agreementProd.Id,
                                                                                                                   2019, 12, 49,
                                                                                                                   date.newInstance(2019, 12, 02),
                                                                                                                   date.newInstance(2019,12, 08));         
            
            system.debug('rollingforecast : '+partnerRollingForecastDom);
            Z_Incentive__c zInctForInterntional = ZIncentiveFactory.createZInctRecordsforInternational(internationalAcc.SAP_Code__c, rbmuser.Employee_Code__c, 
                                                                                                       internationalProd.Dummy_Product_Code__c, 100, 0,
                                                                                                       date.newInstance(2019, 12, 03));
            system.debug('zInctForInterntional***'+zInctForInterntional);
            zInctForInterntional.Payment_Received_Within_Cycle__c = TRUE;
            zInctForInterntional.Billing_Document_Status__c = 'Closed By Payment';
            Update zInctForInterntional;
        }
        
    }
}
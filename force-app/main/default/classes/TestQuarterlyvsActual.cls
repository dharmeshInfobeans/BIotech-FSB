@isTest
public class TestQuarterlyvsActual {
    static testMethod void runTestCases(){
        
        User usr = QuaterlyDataFactory.createUserData('System Administrator');
        User usr1 = QuaterlyDataFactory.createUserData1('System Administrator'); 
        User usr2 = QuaterlyDataFactory.createUserData2('System Administrator');
        User usr3 = QuaterlyDataFactory.createUserData3('System Administrator');
        User usr4 = QuaterlyDataFactory.createUserData4('System Administrator');
        
        system.runAs(usr){
            City__c reg = QuaterlyDataFactory.CreateRegionData('Delhi', '30', 'IN');
            Account acc = QuaterlyDataFactory.createAccountData(reg.id);
            Product__c prod = QuaterlyDataFactory.createProductData();
            Monthly_AOP__c MAOP = QuaterlyDataFactory.createMonthlyAOPData(prod.id, 'Jan', '2019', usr.Id);
            Z_Incentive__c zinc = QuaterlyDataFactory.CreateZIncentiveData(prod.id, acc.id, usr.Id);
            Incentive_Policy__c Incp = QuaterlyDataFactory.createFiscalYears();
            KRA_Configuration__c krac = QuaterlyDataFactory.CreateKRAConfig(Incp.Id,prod.id);
            KRA_Parameter_Detail__c kraparam = QuaterlyDataFactory.CreateKRAParm(krac.id);
            KRA_Calculation__c kracal = QuaterlyDataFactory.CreateKRAcal(krac.id, usr.Id);
            QuarterlyTargetActualCalculation qtac = new QuarterlyTargetActualCalculation();
            qtac.QuarterlyTargetCalculation(krac,'RSM');
            qtac.QuarterlyActualCalculation(krac,'RSM');
            qtac.calculateKRA(krac,'RSM'); 
        }
        system.runAs(usr1){
            City__c reg1 = QuaterlyDataFactory.CreateRegionData('Punjab', '31', 'IN');  
            Account acc1 = QuaterlyDataFactory.createAccountData(reg1.id);
            Product__c prod1 = QuaterlyDataFactory.createProductData();
            Monthly_AOP__c MAOP1 = QuaterlyDataFactory.createMonthlyAOPData1(prod1.id, 'Jan', '2019', usr1.Id);
            Z_Incentive__c zinc1 = QuaterlyDataFactory.CreateZIncentiveData1(prod1.id, acc1.id, usr1.Id);
            Incentive_Policy__c Incp1 = QuaterlyDataFactory.createFiscalYears();
            KRA_Configuration__c krac1 = QuaterlyDataFactory.CreateKRAConfig1(Incp1.Id,prod1.id,prod1.id);
            KRA_Parameter_Detail__c kraparam1 = QuaterlyDataFactory.CreateKRAParm1(krac1.id);
            KRA_Calculation__c kracal1 = QuaterlyDataFactory.CreateKRAcal1(krac1.id, usr1.Id);
            QuarterlyTargetActualCalculation qtac = new QuarterlyTargetActualCalculation();
            qtac.QuarterlyTargetCalculation(krac1,'DM');
            qtac.QuarterlyActualCalculation(krac1,'DM');
            qtac.calculateKRA(krac1,'DM'); 
            
        }
        system.runAs(usr2){
            City__c reg2 = QuaterlyDataFactory.CreateRegionData('Kerala', '32', 'IN');  
            Account acc2 = QuaterlyDataFactory.createAccountData(reg2.id);
            Product__c prod2 = QuaterlyDataFactory.createProductData();
            Monthly_AOP__c MAOP2 = QuaterlyDataFactory.createMonthlyAOPData2(prod2.id, 'Jan', '2019', usr2.Id);
            Z_Incentive__c zinc2 = QuaterlyDataFactory.CreateZIncentiveData2(prod2.id, acc2.id, usr2.Id);
            Incentive_Policy__c Incp2 = QuaterlyDataFactory.createFiscalYears();
            KRA_Configuration__c krac2 = QuaterlyDataFactory.CreateKRAConfig2(Incp2.Id);
            KRA_Parameter_Detail__c kraparam2 = QuaterlyDataFactory.CreateKRAParm2(krac2.id);
            KRA_Calculation__c kracal2 = QuaterlyDataFactory.CreateKRAcal2(krac2.id, usr2.Id);
            QuarterlyTargetActualCalculation qtac = new QuarterlyTargetActualCalculation();
            qtac.QuarterlyTargetCalculation(krac2,'SSE');
            qtac.QuarterlyActualCalculation(krac2,'SSE');
            qtac.calculateKRA(krac2,'SSE'); 
            
        }
        system.runAs(usr3){
            City__c reg3 = QuaterlyDataFactory.CreateRegionData('Maharashtra', '33', 'IN');  
            Account acc3 = QuaterlyDataFactory.createAccountData(reg3.id);
            Product__c prod3 = QuaterlyDataFactory.createProductData();
            Monthly_AOP__c MAOP3 = QuaterlyDataFactory.createMonthlyAOPData3(prod3.id, 'Jan', '2019', usr3.Id);
            Z_Incentive__c zinc3 = QuaterlyDataFactory.CreateZIncentiveData3(prod3.id, acc3.id, usr3.Id);
            Incentive_Policy__c Incp3 = QuaterlyDataFactory.createFiscalYears();
            KRA_Configuration__c krac3 = QuaterlyDataFactory.CreateKRAConfig3(Incp3.Id);
            KRA_Parameter_Detail__c kraparam3 = QuaterlyDataFactory.CreateKRAParm3(krac3.id);
            KRA_Calculation__c kracal3 = QuaterlyDataFactory.CreateKRAcal3(krac3.id, usr3.Id);
            QuarterlyTargetActualCalculation qtac = new QuarterlyTargetActualCalculation();
            qtac.QuarterlyTargetCalculation(krac3,'ZDM');
            qtac.QuarterlyActualCalculation(krac3,'ZDM');
            qtac.calculateKRA(krac3,'ZDM'); 
            
        }
        system.runAs(usr4){
            City__c reg4 = QuaterlyDataFactory.CreateRegionData('Rajasthan', '34', 'IN');  
            Account acc4 = QuaterlyDataFactory.createAccountData(reg4.id);
            Product__c prod4 = QuaterlyDataFactory.createProductData();
            Monthly_AOP__c MAOP4 = QuaterlyDataFactory.createMonthlyAOPData4(prod4.id, 'Jan', '2019', usr4.Id);
            Z_Incentive__c zinc4 = QuaterlyDataFactory.CreateZIncentiveData4(prod4.id, acc4.id, usr4.Id);
            Incentive_Policy__c Incp4 = QuaterlyDataFactory.createFiscalYears();
            KRA_Configuration__c krac4 = QuaterlyDataFactory.CreateKRAConfig4(Incp4.Id);
            KRA_Parameter_Detail__c kraparam4 = QuaterlyDataFactory.CreateKRAParm4(krac4.id);
            KRA_Calculation__c kracal4 = QuaterlyDataFactory.CreateKRAcal4(krac4.id, usr4.Id);
            QuarterlyTargetActualCalculation qtac = new QuarterlyTargetActualCalculation();
            qtac.QuarterlyTargetCalculation(krac4,'ASM');
            qtac.QuarterlyActualCalculation(krac4,'ASM');
            qtac.calculateKRA(krac4,'ASM'); 
            
        }
        
        
    }
    
    static testMethod void runTestCases1(){
        
        Product__c pdt = new Product__c();
        pdt.Active__c = TRUE;
        pdt.Division__c = 'I';
        pdt.Region__c = 'Domestic';
        pdt.Dummy_Product_Code__c = '1110';
        pdt.Dummy_Product_Description__c = 'ABC';
        insert pdt;
        
        List<KRA_Configuration__c> lstkras= new List<KRA_Configuration__c>();
        KRA_Configuration__c kra1 = new KRA_Configuration__c();
        kra1.Role__c = 'ASM;DM';
        kra1.Applicable_For__c  = 'state';
        //kra1.Measurement_Criteria__c = 'Product-Single';
        kra1.Unit_of_Measure__c ='Value';
        kra1.Quadrant__c = 'Finance';
        kra1.Parameter__c = 'Product-Single';
        kra1.Division__c = 'I';
        kra1.Product_1__c = pdt.Id;
        lstkras.add(kra1);
        
        KRA_Configuration__c kra2 = new KRA_Configuration__c();
        kra2.Role__c = 'RSM';
        kra2.Product_1__c = pdt.Id;
        kra2.Applicable_For__c  = 'state';
        //kra2.Measurement_Criteria__c = 'Product-Combination';
        kra2.Unit_of_Measure__c ='Value';
        kra2.Quadrant__c = 'Finance';
        kra2.Parameter__c = 'Product-Single';
        kra2.Division__c = 'I';
        lstkras.add(kra2);
        
        
        insert lstkras;
        
        Test.startTest();
        BatchQuarterlyTargetActualCalculation batch = new BatchQuarterlyTargetActualCalculation();
        database.executebatch(batch);
        Test.stopTest();
    }
}
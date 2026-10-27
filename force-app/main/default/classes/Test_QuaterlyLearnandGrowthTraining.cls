@isTest
public class Test_QuaterlyLearnandGrowthTraining {
    
    public static testMethod void runTestCases(){
        
        String rsmUserName = 'dom_rsmuser' + DateTime.now().getTime() + '@testorg.com';
         String dmUserName = 'dom_dmuser' + DateTime.now().getTime() + '@testorg.com';
        Profile rsmp = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
        UserRole rsmd =[SELECT Id,name FROM UserRole WHERE Name like'RSM%' AND PortalType = 'None' LIMIT 1];
        UserRole dmd =[SELECT Id,name FROM UserRole WHERE Name like'DM%' AND PortalType = 'None' LIMIT 1];
        system.debug('rsmd'+rsmd);
        User rsmUser = new User(Alias = 'rsm_u', Email='dom_rsmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = rsmp.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=rsmUserName,UserRoleId=rsmd.Id,Division__c='I;II;III;IV;V',Employee_Code__c='DOMRSM1234');
        insert  rsmUser;
        
        User dmUser = new User(Alias = 'dm_u', Email='dom_dmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = rsmp.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=dmUserName,UserRoleId=dmd.Id,Division__c='I;II;III;IV;V',Employee_Code__c='DOMRSM12345');
        insert  dmUser;
        system.runAs(rsmUser){
            period last2FiscQaurterStartEndDt = [Select Id,StartDate,EndDate,FiscalYearSettings.StartDate,FiscalYearSettings.Enddate from period where type = 'QUARTER' AND StartDate = THIS_QUARTER];
            system.debug('***last2FiscQaurterStartEndDt***'+last2FiscQaurterStartEndDt);
            
            CIty__c objcity = new CIty__c();
            objcity.Name = 'Punjab';
            objcity.Region_Code__c = '007';
            objcity.country_key__c = 'IN';
            insert objcity; 
            
            Incentive_Policy__c IP =new Incentive_Policy__c();
            IP.FY_Year__c = '2019-2020';
            IP.Start_Date__c = last2FiscQaurterStartEndDt.StartDate;
            IP.End_Date__c = last2FiscQaurterStartEndDt.EndDate;
            IP.Region__c = 'Domestic';
            insert IP;
            
            Id devRecordTypeId = Schema.SObjectType.Visit_Report__c.getRecordTypeInfosByName().get('Learn & Growth Training').getRecordTypeId();
            List<Visit_Report__c> lstvisit =  new List<Visit_Report__c>();
            Visit_Report__c visit = new Visit_Report__c();
            visit.RecordTypeId = devRecordTypeId;
            visit.Meeting_Type__c = 'Learn & Growth Training';
            visit.Achieve_Percentage__c = 100;
            visit.Start_Date__c = Date.newInstance(2020, 2, 10);
            visit.End_Date__c =Date.newInstance(2020, 2, 10);
            visit.State__c = objcity.Id;
            visit.Sales_Employee__c = rsmUser.Id;
            lstvisit.add(visit);
            insert lstvisit;
            
            KRA_Configuration__c kra  = new KRA_Configuration__c();
            kra.Role__c = 'RSM';
            kra.Applicable_For__c  = 'state';
            kra.Parameter__c = 'Learn & Growth Training';
            kra.Quadrant__c = 'People';
            kra.Division__c = 'I;II;III;IV;V';
            kra.Financial_Year__c = IP.Id;
            insert kra;
            
            KRA_Parameter_Detail__c krapar  = new KRA_Parameter_Detail__c();
            krapar.KRA_Configuration__c = kra.Id;
            krapar.Achievement_from__c = 100;
            krapar.Achievement_to__c = 100;
            krapar.Points__c = 5;        
            insert krapar;
            
            KRA_Calculation__c kracal = new KRA_Calculation__c();
            kracal.Start_Date__c =last2FiscQaurterStartEndDt.StartDate;
            kracal.End_Date__c = last2FiscQaurterStartEndDt.EndDate;
            kracal.Points__c = 5;
            kracal.Percentage__c = 100;
            kracal.OwnerId = rsmUser.Id;
            kracal.KRA_Configuration__c = kra.Id;
            insert kracal;
            
            KRA_Configuration__c kraConfig = [Select Id,Quadrant__c,Role__c, Parameter__c,Financial_Year__c,Financial_Year__r.Start_Date__c,
                                              Financial_Year__r.End_Date__c,Division__c,DivisionT__c,(select id,Points__c,KRA_Configuration__c,Achievement_to__c,Achievement_from__c 
                                                                                                      from KRA_Details__r)
                                              from KRA_Configuration__c where Parameter__c ='Learn & Growth Training' and id =: kra.Id];
            
            if(kraConfig.Parameter__c =='Learn & Growth Training'){
                List<String> tmpString = new list<string>();
                if(kraConfig.DivisionT__c != null){
                    if(kraConfig.DivisionT__c.contains(',')){
                        tmpString = kraConfig.DivisionT__c.split(','); 
                    }else {
                        tmpString.add(kraConfig.DivisionT__c);
                    }
                }
                
                QuarterlyLearnandGrowthTraining QLGT = new QuarterlyLearnandGrowthTraining();
                QLGT.QuarterlyLearnandGrowth(kraConfig,kraConfig.Role__c,tmpString);
                QLGT.calculateLearnandGrowthTraining(kraConfig,kraConfig.Role__c,tmpString);
            }
        }
        
        system.runAs(dmUser){
            period last2FiscQaurterStartEndDt = [Select Id,StartDate,EndDate,FiscalYearSettings.StartDate,FiscalYearSettings.Enddate from period where type = 'QUARTER' AND StartDate = THIS_QUARTER];
            system.debug('***last2FiscQaurterStartEndDt***'+last2FiscQaurterStartEndDt);
            
            CIty__c objcity = new CIty__c();
            objcity.Name = 'Maharashtra';
            objcity.Region_Code__c = '004';
            objcity.country_key__c = 'IN';
            insert objcity; 
            
            Incentive_Policy__c IP =new Incentive_Policy__c();
            IP.FY_Year__c = '2019-2020';
            IP.Start_Date__c = last2FiscQaurterStartEndDt.StartDate;
            IP.End_Date__c = last2FiscQaurterStartEndDt.EndDate;
            IP.Region__c = 'Domestic';
            insert IP;
            
            Id devRecordTypeId = Schema.SObjectType.Visit_Report__c.getRecordTypeInfosByName().get('Learn & Growth Training').getRecordTypeId();
            List<Visit_Report__c> lstvisit =  new List<Visit_Report__c>();
            Visit_Report__c visit = new Visit_Report__c();
            visit.RecordTypeId = devRecordTypeId;
            visit.Meeting_Type__c = 'Learn & Growth Training';
            visit.Achieve_Percentage__c = 100;
            visit.Start_Date__c = last2FiscQaurterStartEndDt.StartDate;
            visit.End_Date__c =last2FiscQaurterStartEndDt.EndDate;
            visit.State__c = objcity.Id;
            visit.Sales_Employee__c = dmUser.Id;
            lstvisit.add(visit);
            insert lstvisit;
            
            KRA_Configuration__c kra  = new KRA_Configuration__c();
            kra.Role__c = 'DM';
            kra.Applicable_For__c  = 'state';
            kra.Parameter__c = 'Learn & Growth Training';
            kra.Quadrant__c = 'People';
            kra.Division__c = 'I;II;III;IV;V';
            kra.Financial_Year__c = IP.Id;
            insert kra;
            
            KRA_Parameter_Detail__c krapar  = new KRA_Parameter_Detail__c();
            krapar.KRA_Configuration__c = kra.Id;
            krapar.Achievement_from__c = 100;
            krapar.Achievement_to__c = 100;
            krapar.Points__c = 5;        
            insert krapar;
            
            KRA_Calculation__c kracal = new KRA_Calculation__c();
            kracal.Start_Date__c =last2FiscQaurterStartEndDt.StartDate;
            kracal.End_Date__c = last2FiscQaurterStartEndDt.EndDate;
            kracal.Points__c = 5;
            kracal.Percentage__c = 100;
            kracal.OwnerId = dmUser.Id;
            kracal.KRA_Configuration__c = kra.Id;
            insert kracal;
            
            KRA_Configuration__c kraConfig = [Select Id,Quadrant__c,Role__c, Parameter__c,Financial_Year__c,Financial_Year__r.Start_Date__c,
                                              Financial_Year__r.End_Date__c,Division__c,DivisionT__c,(select id,Points__c,KRA_Configuration__c,Achievement_to__c,Achievement_from__c 
                                                                                                      from KRA_Details__r)
                                              from KRA_Configuration__c where Parameter__c ='Learn & Growth Training' and id =: kra.Id];
            
            if(kraConfig.Parameter__c =='Learn & Growth Training'){
                List<String> tmpString = new list<string>();
                if(kraConfig.DivisionT__c != null){
                    if(kraConfig.DivisionT__c.contains(',')){
                        tmpString = kraConfig.DivisionT__c.split(','); 
                    }else {
                        tmpString.add(kraConfig.DivisionT__c);
                    }
                }
                
                QuarterlyLearnandGrowthTraining QLGT = new QuarterlyLearnandGrowthTraining();
                QLGT.QuarterlyLearnandGrowth(kraConfig,kraConfig.Role__c,tmpString);
                QLGT.calculateLearnandGrowthTraining(kraConfig,kraConfig.Role__c,tmpString);
            }
        }
        Test.startTest();
        BatchQuarterlyTargetActualCalculation batch = new BatchQuarterlyTargetActualCalculation();
        database.executebatch(batch);
        Test.stopTest();
    }
    
    static testMethod void runTestCases1(){
        
        List<KRA_Configuration__c> lstkras= new List<KRA_Configuration__c>();
        KRA_Configuration__c kra1 = new KRA_Configuration__c();
        kra1.Role__c = 'ASM;DM';
        kra1.Applicable_For__c  = 'state';
      //  kra1.Measurement_Criteria__c = 'State';
        kra1.Unit_of_Measure__c ='Value';
        kra1.Quadrant__c = 'People';
        kra1.Parameter__c = 'Learn & Growth Training';
        kra1.Division__c = 'I';
        lstkras.add(kra1);
        
        KRA_Configuration__c kra2 = new KRA_Configuration__c();
        kra2.Role__c = 'RSM';
        kra2.Applicable_For__c  = 'state';
      //  kra2.Measurement_Criteria__c = 'State';
        kra2.Unit_of_Measure__c ='Value';
        kra2.Quadrant__c = 'People';
        kra2.Parameter__c = 'Learn & Growth Training';
        kra2.Division__c = 'I';
         lstkras.add(kra2);

        
        insert lstkras;
        
        Test.startTest();
        BatchQuarterlyTargetActualCalculation batch = new BatchQuarterlyTargetActualCalculation();
        database.executebatch(batch);
        Test.stopTest();
    }
}
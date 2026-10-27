@isTest
public class Test_QuarterlyCMERTMCalculation {
    
    public static testMethod void CMERTMCalculation(){
        
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
            
            period last2FiscQaurterStartEndDt = [Select Id,StartDate,EndDate,FiscalYearSettings.StartDate,FiscalYearSettings.Enddate from period where type = 'QUARTER' AND StartDate = LAST_QUARTER];
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
            
            KRA_Target__c ktgt=new KRA_Target__c();
            ktgt.Target_Type__c='CME-RTM';
            ktgt.Start_Date__c= Date.newInstance(2020, 2, 9);
            ktgt.End_Date__c= Date.newInstance(2020, 2, 25);
            ktgt.Sales_Employee__c= rsmUser.Id;
            ktgt.State__c = objcity.Id;
            ktgt.Target__c = 1;
            insert ktgt;
            
            Id devRecordTypeId = Schema.SObjectType.Visit_Report__c.getRecordTypeInfosByName().get('CME-RTM').getRecordTypeId();
            List<Visit_Report__c> lstvisit =  new List<Visit_Report__c>();
            Visit_Report__c visit = new Visit_Report__c();
            visit.RecordTypeId = devRecordTypeId;
            visit.Meeting_Type__c = 'CME-RTM';
            visit.Team_Performance__c = '5';
            visit.Date__c = Date.newInstance(2020, 2, 10);
            visit.Date__c = Date.newInstance(2020, 2, 10);
            visit.State__c = objcity.Id;
            visit.Sales_Employee__c = rsmUser.Id;
            lstvisit.add(visit);
            insert lstvisit;
            
            KRA_Configuration__c kra  = new KRA_Configuration__c();
            kra.Role__c = 'RSM';
            kra.Applicable_For__c  = 'state';
            kra.Parameter__c = 'CME - RTM';
            kra.Measurement_Criteria__c = 'Target vs Actuals';
            kra.Quadrant__c = 'Customer';
            kra.Division__c = 'I;II;III;IV;V';
            kra.Financial_Year__c = IP.Id;
            insert kra;
            
            List<KRA_Parameter_Detail__c> KRAParam = new List<KRA_Parameter_Detail__c>();
            KRA_Parameter_Detail__c krapar  = new KRA_Parameter_Detail__c();
            krapar.KRA_Configuration__c = kra.ID;
            krapar.Achievement_from__c = 100;
            krapar.Achievement_to__c = 100;
            krapar.Points__c = 5;        
            KRAParam.add(krapar);
            insert KRAParam;
            
            KRA_Calculation__c kracal = new KRA_Calculation__c();
            kracal.Start_Date__c = last2FiscQaurterStartEndDt.StartDate;
            kracal.End_Date__c = last2FiscQaurterStartEndDt.EndDate;
            kracal.Points__c = 5;
            kracal.OwnerId = rsmUser.Id;
            kracal.KRA_Configuration__c = kra.Id;
            kracal.Region__c = objcity.Id;
            kracal.Percentage__c = 100;
            insert kracal;
            
            KRA_Configuration__c kraConfig = [Select Id,Quadrant__c,Role__c, Parameter__c,Financial_Year__c,Financial_Year__r.Start_Date__c,
                                              Financial_Year__r.End_Date__c,Division__c,DivisionT__c
                                              from KRA_Configuration__c where Parameter__c ='CME - RTM' and id =: kra.Id];
            if(kraConfig.Parameter__c =='CME - RTM'){
                List<String> tmpString = new list<string>();
                if(kraConfig.DivisionT__c != null){
                    if(kraConfig.DivisionT__c.contains(',')){
                        tmpString = kraConfig.DivisionT__c.split(','); 
                    }else {
                        tmpString.add(kraConfig.DivisionT__c);
                    }
                }
                QuarterlyCMERTMCalculation QCMERTM = new QuarterlyCMERTMCalculation();
                QCMERTM.QuarterlyCMERTMTarget(kraConfig, kraConfig.Role__c, tmpString);
                QCMERTM.QuarterlyCMERTMVisitReport(kraConfig, kraConfig.Role__c, tmpString);
                QCMERTM.calculateCMERTM(kraConfig, kraConfig.Role__c, tmpString);
            }
        }
        Test.startTest();
        BatchQuarterlyTargetActualCalculation batch = new BatchQuarterlyTargetActualCalculation();
        database.executebatch(batch);
        Test.stopTest();
    }
}
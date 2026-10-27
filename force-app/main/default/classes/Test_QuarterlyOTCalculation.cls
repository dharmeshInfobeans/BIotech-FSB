@istest
public class Test_QuarterlyOTCalculation {
    static testMethod void Quarterlycalculation(){
        
        String rsmUserName = 'dom_rsmuser' + DateTime.now().getTime() + '@testorg.com';
        Profile rsmp = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
        UserRole rsmd =[SELECT Id,name FROM UserRole WHERE Name like'RSM%' AND PortalType = 'None' LIMIT 1];
        system.debug('rsmd'+rsmd);
        User rsmUser = new User(Alias = 'rsm_u', Email='dom_rsmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = rsmp.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=rsmUserName,UserRoleId=rsmd.Id,Division__c='I;II;III;IV;V',Employee_Code__c='DOMRSM1234');
        insert  rsmUser;
        
        system.runAs(rsmUser){
            
            period last2FiscQaurterStartEndDt = [Select Id,StartDate,EndDate,FiscalYearSettings.StartDate,FiscalYearSettings.Enddate from period where type = 'QUARTER' AND StartDate = Last_QUARTER];
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
            ktgt.Target_Type__c='OT';
            ktgt.Start_Date__c= last2FiscQaurterStartEndDt.StartDate;
            ktgt.End_Date__c= last2FiscQaurterStartEndDt.EndDate;
            ktgt.Sales_Employee__c= rsmUser.Id;
            ktgt.State__c = objcity.Id;
            ktgt.Target__c = 9;
            insert ktgt;
            
            event eventobj1 = new event();
            eventobj1.Milestone_Stage__c = 'Delay';
            eventobj1.Delay_Reason__c = 'No Action Performed';
            eventobj1.BD_Tracker_Phase__c ='Product Discussion';
            eventobj1.Visit_Date__c = last2FiscQaurterStartEndDt.StartDate;
            eventobj1.Sales_Employee__c = rsmUser.Id;
            eventobj1.Call_Type__c = 'OT';
            eventobj1.Status__c = 'Approved';
            eventobj1.DurationInMinutes = 2;
            eventobj1.ActivityDateTime = system.now();
            insert eventobj1 ;
            
            List<KRA_Configuration__c> lstkras= new List<KRA_Configuration__c>();
            KRA_Configuration__c kra2 = new KRA_Configuration__c();
            kra2.Role__c = 'RSM';
            kra2.Quadrant__c = 'Process';
            kra2.Division__c = 'I;II;III;IV;V';
            kra2.Parameter__c = 'Operation Discpline(OT)';
            kra2.Financial_Year__c = IP.Id;
            insert kra2;
            
            string parameter = 'Operation Discpline(OT)';
            KRA_Calculation__c kcal=new KRA_Calculation__c();
            kcal.Start_Date__c=last2FiscQaurterStartEndDt.StartDate;
            kcal.End_Date__c=last2FiscQaurterStartEndDt.EndDate;
            kcal.Percentage__c=23;
          //  kcal.UniqueKey__c=rsmUser.Id+'_'+last2FiscQaurterStartEndDt.StartDate+'_'+parameter;
            KCAL.Points__c=4.5;
            kcal.KRA_Configuration__c = kra2.Id; 
            insert kcal;        
            
            KRA_Parameter_Detail__c kp=new KRA_Parameter_Detail__c();
            kp.KRA_Configuration__c=kra2.id;
            insert kp;
        
        Test.startTest();
        QuarterlyOTCalculation.KRACalculateOT();
        //QuarterlyOTCalculation.calculateOT(usrLst, 'RSM', lstkras);
        Test.stopTest();
        }
        BatchQuarterlyOTCalculation batch = new BatchQuarterlyOTCalculation();
        database.executebatch(batch);
    }
}
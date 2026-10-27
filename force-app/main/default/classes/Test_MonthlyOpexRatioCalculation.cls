@isTest
public class Test_MonthlyOpexRatioCalculation {
    
    public static testMethod void runTestCases(){
        
        String rsmUserName = 'dom_rsmuser' + DateTime.now().getTime() + '@testorg.com';
        Profile rsmp = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
        UserRole rsmd =[SELECT Id,name FROM UserRole WHERE Name like'RSM%' AND PortalType = 'None' LIMIT 1];
        UserRole rsmd1 =[SELECT Id,name FROM UserRole WHERE Name like'ASM%' AND PortalType = 'None' LIMIT 1];
        system.debug('rsmd'+rsmd);
        List<User> lstUser = new List<User>();
        User rsmUser = new User(Alias = 'rsm_u', Email='dom_rsmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = rsmp.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=rsmUserName,UserRoleId=rsmd1.Id,Division__c='I;II;III;IV;V',Employee_Code__c='DOMRSM1234');
        lstUser.add(rsmUser);
        
        String rsmUserName1 = 'dom_rsmuser1' + DateTime.now().getTime() + '@testorg.com';
        User rsmUser1 = new User(Alias = 'rsm_u1', Email='dom_rsmuser1@testorg.com',
                                 EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                 LocaleSidKey='en_US', ProfileId = rsmp.Id,
                                 TimeZoneSidKey='America/Los_Angeles',
                                 User_Type__c='Domestic',UserName=rsmUserName1,UserRoleId=rsmd.Id,Division__c='I;II;III;IV;V',Employee_Code__c='DOMRSM12345');
        lstUser.add(rsmUser1);
        insert lstUser; 
        rsmUser1.ManagerId = rsmUser.Id;
        update rsmUser1;
        system.runAs(rsmUser1){
            
            period last2FiscQaurterStartEndDt = [Select Id,StartDate,EndDate,FiscalYearSettings.StartDate,FiscalYearSettings.Enddate from period where type = 'MONTH' AND StartDate = LAST_MONTH];
            system.debug('***last2FiscQaurterStartEndDt***'+last2FiscQaurterStartEndDt);
            
            CIty__c objcity = new CIty__c();
            objcity.Name = 'Punjab';
            objcity.Region_Code__c = '007';
            objcity.country_key__c = 'IN';
            insert objcity; 
            
            OPEX__c op = new OPEX__c();
            op.Designation__c = 'RSM';
            op.Salary__c = 10000;
            op.Expense_Amount__c = 5000;
            op.Expense_From_Date__c= Date.newInstance(2020, 03, 1);
            op.Expense_To_Date__c= Date.newInstance(2020, 03, 31);
            op.Net_Sales_Value__c = 15000;
            op.Region__c = objcity.Id;
            op.Sales_Employee__c = rsmUser1.id;
            insert op;
            
            OPEX__c op1 = new OPEX__c();
            op1.Designation__c = 'RSM';
            op1.Salary__c = 10000;
            op1.Expense_Amount__c = 5000;
            op1.Expense_From_Date__c= Date.newInstance(2020, 03, 1);
            op1.Expense_To_Date__c= Date.newInstance(2020, 03, 31);
            op1.Net_Sales_Value__c = 15000;
            op1.Region__c = objcity.Id;
            op1.Sales_Employee__c = rsmUser1.id;
            insert op1;
            
            MonthlyOpexRatioCalculation monthlyOpex = new MonthlyOpexRatioCalculation();
            monthlyOpex.MonthlyOpexCalculation();            
            monthlyOpex.calculateOpexExpensesAndSalary(lstUser, 'RSM');
            
            Incentive_Policy__c IP =new Incentive_Policy__c();
            IP.FY_Year__c = '2020-2021';
            IP.Start_Date__c = date.newInstance(2020, 4, 1);
            IP.End_Date__c = date.newInstance(2021, 3, 31);
            IP.Region__c = 'Domestic';
            insert IP;
            
            KRA_Configuration__c kra  = new KRA_Configuration__c();
            kra.Role__c = 'RSM';
            kra.Applicable_For__c  = 'State';
            kra.Parameter__c = 'Opex to Sales Ratio';
           // kra.Measurement_Criteria__c = 'State';
            kra.Quadrant__c = 'Finance';
            kra.Division__c = 'I;II;III;IV;V';
            kra.Financial_Year__c = IP.Id;
            insert kra;
            
            KRA_Parameter_Detail__c krapar  = new KRA_Parameter_Detail__c();
            krapar.KRA_Configuration__c = kra.Id;
            krapar.Achievement_from__c = 8.01;
            krapar.Achievement_to__c = 12;
            krapar.Points__c = 3;        
            insert krapar;
            
            KRA_Configuration__c kraConfig = [Select Id,Quadrant__c,Role__c, Parameter__c,Financial_Year__c,Financial_Year__r.Start_Date__c,
                                              Financial_Year__r.End_Date__c,Division__c,DivisionT__c
                                              from KRA_Configuration__c where Parameter__c ='Opex to Sales Ratio' and id =: kra.Id];
            
            Test.startTest();
            BatchMonthlyOpexRatio batch = new BatchMonthlyOpexRatio();
            database.executebatch(batch);
            
            BatchQuarterlyOpexRatioCalculation batch1 = new BatchQuarterlyOpexRatioCalculation();
            database.executebatch(batch1);
            Test.stopTest();
        }
    }
}
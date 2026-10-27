@istest
public class Test_OpexTrigger {
    
    static testmethod void testTrigger(){
        
        String rsmUserName = 'dom_rsmuser' + DateTime.now().getTime() + '@testorg.com';
        Profile rsmp = [SELECT Id FROM Profile WHERE Name='Domestic Sales'];
        UserRole rsmd =[SELECT Id,name FROM UserRole WHERE Name like'RSM%' AND PortalType = 'None' LIMIT 1];
        //UserRole rsmd1 =[SELECT Id,name FROM UserRole WHERE Name like'ASM%' AND PortalType = 'None' LIMIT 1];
        system.debug('rsmd'+rsmd);
        //List<User> lstUser = new List<User>();
        User rsmUser = new User(Alias = 'rsm_u', Email='dom_rsmuser@testorg.com',
                                EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                                LocaleSidKey='en_US', ProfileId = rsmp.Id,
                                TimeZoneSidKey='America/Los_Angeles',
                                User_Type__c='Domestic',UserName=rsmUserName,UserRoleId=rsmd.Id,Division__c='I;II;III;IV;V',Employee_Code__c='DOMRSM1234');
        insert rsmUser;
        
        system.runAs(rsmUser){
            
            CIty__c objcity = new CIty__c();
            objcity.Name = 'Punjab';
            objcity.Region_Code__c = '007';
            objcity.country_key__c = 'IN';
            insert objcity; 
            
            OPEX__c op = new OPEX__c();
            op.Designation__c = 'RSM';
            op.Salary__c = 10000;
            op.Employee_Code__c = 'DOMRSM1234';
            op.StateCode__c = '007';
            op.Expense_Amount__c = 5000;
            // op.Expense_From_Date__c= Date.newInstance(2020, 04, 1);
            //  op.Expense_To_Date__c= Date.newInstance(2020, 04, 30);
            op.Net_Sales_Value__c = 15000;
            op.Region__c = objcity.Id;
            op.Sales_Employee__c = rsmUser.id;
            insert op;
            
            op.Employee_Code__c = 'DOMRSM12345';
            op.StateCode__c = '008';
            update op;
        }
    }
    
}
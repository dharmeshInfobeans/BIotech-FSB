@isTest
public class TestBatchAccountActivation 
{
    static testmethod void testSchedular(){
        test.startTest();
        ScheduleBatchAccountActivation sh1 = new ScheduleBatchAccountActivation();
        String sch = '0 0 23 * * ?'; 
        system.schedule('Test Territory Check', sch, sh1);
        Test.stopTest();    
    }
    
    static testmethod void Test_BatchAccount ()
    {
        User usr = [Select id,Name,Profile.Name,isActive from User where Profile.Name='System Administrator' AND isActive=true limit 1];
        system.runas(usr){
            Period last2FiscQaurterStartEndDt = [Select Id,StartDate,EndDate from period where type = 'QUARTER' AND StartDate = LAST_N_FISCAL_QUARTERS:2 AND 
                                                 StartDate != LAST_QUARTER];
            date startDate = last2FiscQaurterStartEndDt.StartDate;
            date endDate = last2FiscQaurterStartEndDt.EndDate;
            Id AccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Domestic-Doctor/Hospital').getRecordTypeId();
            //List <Account> accL = new List<Account>();
            Account acc = new Account ();
            acc.Name = 'Test123';
            acc.Phone	='9087653';
            acc.GSTIN_No__c = '123565890';
            acc.Account_Type__c=  'Commercial';
            acc.RecordTypeId = AccRecordTypeId;
            acc.BillingCity = 'Pune';
            acc.BillingState = 'Maharashtra';
            acc.BillingCountry = 'India';
            acc.BillingStreet = 'Test123';
            acc.BillingPostalCode = '411045';
            acc.SAP_Code__c  = '1250';
            //cL.add(acc);
            //sert accL;
            insert acc;
            
            List<z_Incentive__c> zInc= new List<z_Incentive__c>();
            z_Incentive__c zobj = new z_Incentive__c();
            zobj.Account__c = acc.Id;
            zobj.Billing_Date__c =  system.today();
            zInc.add(zobj);
            insert zInc;
            
            
            /*
List<Account_Activation_History__c> accList = new List<Account_Activation_History__c>();

Account_Activation_History__c accHistory  = new Account_Activation_History__c();
accHistory.Account__c = acc.id;
// accHistory.Activation_Type__c = 'Active';
accHistory.Sales_Employee__c = acc.OwnerId;
accHistory.Start_Date__c = StartDate;
accHistory.Batch_Execution_Date__c = system.today();
accHistory.End_Date__c = EndDate;
acclist.add(accHistory);
insert acclist;
*/
            
            Test.startTest();
            BatchAccountActivationQuaterly bacca = new BatchAccountActivationQuaterly('KRA');
            database.executebatch(bacca);
            database.BatchableContext bc;
            BatchAccountActivationQuaterly bacc = new BatchAccountActivationQuaterly('MIS');
            database.executebatch(bacc);
            database.BatchableContext bc1;
            KRACalculationsActiveCustomers.calculateActiveCustomerKRA();
            
            
            Test.stopTest();
            
        }
    }
}
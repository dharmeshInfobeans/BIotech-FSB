@isTest
public class BatchAccountCISLockedTest {
    public static String CRON_EXP = '0 0 0 15 3 ? *';
   @TestSetup
    static void makeData(){
    List<Account> accounts = new List<Account>();
       
        // insert 10 accounts
        for (Integer i=0;i<10;i++) {
            accounts.add(new Account(name='Account '+i, Medical_Registration_No__c='123456'+i,
                Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',Account_Locked__c=false,GSTIN_No__c='GSTIN2343423456'));
        }
        insert accounts;
        
        CIS_Setting__c cis=new  CIS_Setting__c ()   ; 
        cis.CIS_Allowed_Till__c=1;
        insert cis;
        
    }
    static testmethod void test() {   
         Test.startTest();
        BatchAccountCISLocked uca = new BatchAccountCISLocked();
        Id batchId = Database.executeBatch(uca);
        
        // This should not be in this class, this is creating unnecessary dependency between difference modules
        /*
        BatchClassforMonthlyPlan bmp=new BatchClassforMonthlyPlan();
        Id batchId1 = Database.executeBatch(bmp);
        */
        
        String jobId = System.schedule('ScheduleApexClassTest',  CRON_EXP, new ScheduleBatchAccountCISLocked());
        Test.stopTest();
    }
    
    
}
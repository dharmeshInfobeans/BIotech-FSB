@isTest
public class SubmitCISControllerTest {
    // public static Account acc;
    //public static CIS_Header__c cis_head;
    @TestSetup
    static void makeData(){
        
    }
    
    static testmethod void test() {   
        
        Account acc =new Account(name='Account',  Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',Account_Locked__c=false,Status__c='Activated');
        acc.Medical_Registration_No__c = '123456789';
        acc.GSTIN_No__c='GSTIN2343423456';
        acc.BillingPostalCode = '400001';
        insert acc;
        
        Customer_Evaluation__c cust_eval=new Customer_Evaluation__c(Account__c=acc.Id,Year__c='2019',Status__c='Approved');
        insert cust_eval;
        
        CIS_Header__c cis_head=new CIS_Header__c(Account__c=acc.Id,Year__c='2019',Month__c='Apr');
        insert cis_head;
        CIS_Header__c cis_head2=new CIS_Header__c(Account__c=acc.Id,Year__c='2019',Month__c='Mar');
        insert cis_head2;
        
        SubmitCISController.getBudgetOptions(String.valueOf(acc.Id),String.valueOf(cis_head.Id),'Apr','2019');
        
        
        
        
        List<CIS_Line__c> cis_line=new List<CIS_Line__c>();
        cis_line.add(new CIS_Line__c(CIS_Header__c=cis_head.Id,Company__c='Biotech'));
        insert cis_line;
        CIS_Line__c cis_line1=cis_line.get(0);
        SubmitCISController.CISLineItem cs_line_item=new SubmitCISController.CISLineItem(cis_line1,true);
        SubmitCISController.CISWrapper wrap=new SubmitCISController.CISWrapper('1000');
        SubmitCISController.CISWrapper wrapper=new SubmitCISController.CISWrapper('1000',cis_line,true);
        
        List<SubmitCISController.CISWrapper> wrapper_list=new List<SubmitCISController.CISWrapper>();
        wrapper_list.add(wrapper);
        //JSON.serialize(cis_head);
        SubmitCISController.saveCISRecord(JSON.serialize(wrapper_list),String.valueOf(acc.Id),'',String.valueOf(cis_head.Id),'Apr','2019','USD');
        SubmitCISController.saveCISRecord(JSON.serialize(wrapper_list),String.valueOf(acc.Id),String.valueOf(cis_head.Id),String.valueOf(cis_head2.Id),'Apr','2019','USD');
        SubmitCISController.approveCISRecord(String.valueOf(cis_head.Id),'test status','test comment');
        
        
        delete cis_head;
        //  SubmitCISController.getBudgetOptions(String.valueOf(acc.Id),null);
    }
    static testmethod void test1() {   
        Account acc =new Account(name='Account',  Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',Account_Locked__c=false,Status__c='Activated');
        acc.Medical_Registration_No__c = '123456789';
        acc.GSTIN_No__c='GSTIN2343423456';
        acc.BillingPostalCode = '400001';
        insert acc;
        Account acc2 =new Account(name='Account2',  Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',Account_Locked__c=false,Status__c='Activated');
        acc2.Medical_Registration_No__c = '123456788';
        acc2.GSTIN_No__c='GSTIN2343423456';
        acc2.BillingPostalCode = '400002';
        acc2.Account_Locked__c = true;
        insert acc2;
        Account acc3 =new Account(name='Account3',  Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',Account_Locked__c=false,Status__c='Activated');
        acc3.Medical_Registration_No__c = '123456787';
        acc3.GSTIN_No__c='GSTIN2343423456';
        acc3.BillingPostalCode = '400003';
        insert acc3;
        Customer_Evaluation__c cust_eval=new Customer_Evaluation__c(Account__c=acc3.Id,Year__c=''+System.today().Year(),Status__c='Approved');
        insert cust_eval;
        
        CIS_Header__c cis_head2=new CIS_Header__c(Account__c=acc3.Id,Year__c='2019',Month__c='Mar');
        insert cis_head2;
        
        CIS_Header__c cis_head=new CIS_Header__c(Account__c=acc.Id,Year__c='2019',Month__c='Apr');
        insert cis_head;

        SubmitCISController.getBudgetOptions(String.valueOf(acc.Id),null,'Apr','2019');
        SubmitCISController.getBudgetOptions(String.valueOf(acc2.Id),null,'Apr','2019');
        SubmitCISController.getBudgetOptions(String.valueOf(acc3.Id),null,'Apr','2019');
    }
    static testmethod void test2() {   
        Account acc =new Account(name='Account',  Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',Account_Locked__c=false,Status__c='Activated');
        acc.Medical_Registration_No__c = '123456789';
        acc.GSTIN_No__c='GSTIN2343423456';
        acc.BillingPostalCode = '400001';
        insert acc;
        // CIS_Header__c cis_head=new CIS_Header__c(Account__c=acc.Id,Year__c='2019',Month__c='Apr');
        //insert cis_head;
        SubmitCISController.getBudgetOptions(String.valueOf(acc.Id),null,null,null);
    }
}
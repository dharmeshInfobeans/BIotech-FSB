@isTest
public class TestCommunityAccountInfo {
    static testmethod void Test_AccountDetail ()
    { 
        //User usr = [Select id,Name,Profile.Name,isActive from User Where Name ='Biotech Partner Community'];
        //system.runas(usr){
            Account acc = new Account ();
            acc.Name = 'Test123';
            List<Account> acLst = new List<Account>();
            if(acLst.size()<0){ 
                acLst.add(acc);
            }
            insert acLst;
            
            test.startTest();
            CommunityAccountInfo.getAccountDetail();
            test.stopTest();
            
            
       // }
    }
}
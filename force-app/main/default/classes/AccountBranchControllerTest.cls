@isTest
public class AccountBranchControllerTest {
    public static Id test_id;
      public static Account acc;
    @TestSetup
    static void makeData(){
        BranchSiteEncryptAndDecryptData__c cs1=new BranchSiteEncryptAndDecryptData__c();
       //  Blob beforeblob = Blob.valueOf(before);
        cs1.Algorithm_Name__c='';
        cs1.base64EncodeKey__c='';
        cs1.Name='URL Data';
        //  cs1.GeneratedAesKey__c='';
        insert cs1;
        BranchFormDataVsLocation__c cs2 = new BranchFormDataVsLocation__c();
        cs2.Name               = 'MAH-03-MUM-Mumbai';
        cs2.Branch_Location__c = 'MUMBAI';
        cs2.Region_Code__c	   = '03';
		cs2.Delivery_Plant__c  = '1345';
		cs2.Sales_District__c  = 'D045-MUMBAI';
        insert cs2;

    }
    public static testmethod void testmethod1(){
        test.startTest();
        
        Profile p = [SELECT Id FROM Profile WHERE Name='International Sales'];

        UserRole r =[SELECT Id,name FROM UserRole WHERE (Name='Domestic Admin' OR  Name='Admin_D')];
         
         System.debug('UserRole ID::::'+String.valueOf(r.id));
          User u1 = new User(Alias = 'newU', Email='newuser123@testorg.com',
                      EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                      LocaleSidKey='en_US', ProfileId = p.Id,
                      TimeZoneSidKey='America/Los_Angeles', UserName='newuser123@testorg123.com',UserRole = r);
         insert u1;
         System.runAs(u1){       
         acc=new Account(name='Account', 
                                Country_Key__c='IN', City__c='mumbai',City_postal_code__c='400001',Account_Locked__c=false,Status__c='Activated');
        insert acc;
         
        test_id=acc.id;
            Blob  dataToEncrypt =   Blob.valueOf(acc.Id);
        String algoName = 'AES128';
            Blob askey = Crypto.generateAesKey(128);
            String base64String = EncodingUtil.base64Encode(askey);
             
               BranchSiteEncryptAndDecryptData__c cs = new BranchSiteEncryptAndDecryptData__c ();
            cs.Name = 'URL Data';
            cs.Algorithm_Name__c = 'AES128';
            cs.base64EncodeKey__c = base64String;
            insert cs;
       String base64EncodedBlobStr = cs.base64EncodeKey__c;
            Blob aakey =  EncodingUtil.base64Decode(base64EncodedBlobStr);
     
             
             
        string encodedCiphTxt = EncodingUtil.base64Encode(Crypto.encryptWithManagedIV(cs.Algorithm_Name__c, aakey, dataToEncrypt));

        PageReference myVfPage = Page.AccBranchForm;
        Test.setCurrentPage(myVfPage);
      
        // Put Id into the current page Parameters
        ApexPages.currentPage().getParameters().put('id',encodedCiphTxt); 
        
        String test_id1= String.valueOf(acc.id) ;
        System.debug('test_id1:::'+acc.OwnerId);
        AccountBranchFormController.getAccount(test_id1);
             AccountBranchFormController abc=new AccountBranchFormController();
             
                Attachment attach=new Attachment();     
        attach.Name='ERL';
        Blob bodyBlob=Blob.valueOf('Unit Test Attachment Body');
        attach.body=bodyBlob;
        attach.parentId=acc.id;
        insert attach;
               Blob askey1 = Crypto.generateAesKey(128);
            String base64String1 = EncodingUtil.base64Encode(askey);
                     
             string encodedCiphTxt1 = EncodingUtil.base64Encode(Crypto.encryptWithManagedIV('AES128', askey1, attach.body));

           AccountBranchFormController.saveChunk(String.valueOf( attach.parentId),'test123',encodedCiphTxt1,'application/html',attach.Id);
          AccountBranchFormController.saveChunk(String.valueOf( attach.parentId),'test123',encodedCiphTxt1,'application/html','');
             AccountBranchFormController.getBranchFormDataByBranchLocation('MUMBAI');
             AccountBranchFormController.getBranchFormDataByBranchLocation('');
             AccountBranchFormController.getBranchFormDataByBranchLocation('LONDON');
			
             acc.City__c = 'Ahmedabad';
             AccountBranchFormController.saveAccount(acc);
             AccountBranchFormController abfc = new AccountBranchFormController();
             Account acct = abfc.acc;
            // AccountBranchFormController.appendToFile(attach.Id, encodedCiphTxt1);
         }
        test.stopTest();
    }
    
    
    
}
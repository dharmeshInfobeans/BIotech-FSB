@IsTest
public class ShowBiotechCategoryProductRange_Test {
  
    @isTest
    public static void getDistributorDataTest(){
         List<RecordType> rtList = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Dealer_Portal' LIMIT 1];
        
        Id dealerPortalRtId = rtList.isEmpty() ? null : rtList[0].Id;

         Account acc = new Account(Name = 'Test Account',RecordTypeId = dealerPortalRtId);
         insert acc;

         Contact con = new Contact(FirstName='Test first', LastName = 'TestCon', AccountId = acc.Id, Email = 'testcon@example.com', Create_New_Market_X_Ray_Version__c=true);
         insert con;

         Profile communityProfile = [SELECT Id FROM Profile WHERE Name = 'Partner Community User' LIMIT 1];
         System.debug('communityProfile'+communityProfile);

         User communityUser = new User(
            Username = 'testuser' + System.currentTimeMillis() + '@test.com',
            Email = 'testuser@example.com',
            LastName = 'User',
            FirstName = 'Test',
            Alias = 'tuser',
            CommunityNickname = 'testnick' + Math.round(Math.random() * 1000),
            ProfileId = communityProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ContactId = con.Id
        );
        insert communityUser;

         User partnerUser =[ SELECT Id, ContactId, Contact.Email FROM User WHERE Id = :communityUser.Id LIMIT 1];
         Master_Agreement__c ma = new Master_Agreement__c(
            Account__c = acc.Id,
            Agreement_Number__c = 'AGT/OPH/00001',
            Agreement_Start_Date__c = Date.today(),
            Agreement_End_Date__c = Date.today().addYears(1),
            Is_Active__c = false,
            Status__c = 'Draft',
            CurrencyIsoCode = UserInfo.getDefaultCurrency(),
            Vertical__c = 'Ophthalmic',
            Distributer_Type__c = 'Exclusive Distributor'
        );
        insert ma;

        Distributor__c biotech = new Distributor__c(Name = 'Biotech');
        Distributor__c distA = new Distributor__c(Name = 'DistributorA');
        Distributor__c distB = new Distributor__c(Name = 'DistributorB');
        Distributor__c distC = new Distributor__c(Name = 'DistributorC');
        insert new List<Distributor__c>{biotech, distA, distB, distC};

        Plant__c plant1 = new Plant__c(Name = 'Plant India', Orgin__c = 'India');
        Plant__c plant2 = new Plant__c(Name = 'Plant USA', Orgin__c = 'USA');
        Plant__c plant3 = new Plant__c(Name = 'Plant Germany', Orgin__c = 'Germany');
        insert new List<Plant__c>{plant1, plant2, plant3};
            
		Product__c prod1 = new Product__c(Name = 'Range1', Division__c = 'I',Category__c = 'Solution',Dummy_Product_Code__c = 'P1', plant__c = plant1.Id);
        insert prod1;

        Agreement_Product__c agr1 = new Agreement_Product__c(Price__c = 500, Master_Agreement__c = ma.Id, FOC_Text__c = 'FOC YES', Product__c = prod1.Id);
		insert agr1;

		
         System.runAs(partnerUser){
               System.debug('communityUser-----iddd'+ communityUser.ContactId);
			   communityUser = [SELECT Id, ContactId FROM User WHERE Id = :communityUser.Id];
               System.assertNotEquals(null, communityUser.ContactId, 'Partner user must have ContactId before using it');
               Market_X_Ray_Form__c form = new Market_X_Ray_Form__c(Contact__c = communityUser.ContactId,Account__c = con.AccountId,IsMarketXrayFormEditable__c = false);
               insert form;
         }
       
		List<Market_X_Ray_Form__c> formss=[SELECT Id FROM Market_X_Ray_Form__c LIMIT 1];
		List<DistributorLineItem__c> lineItems = new List<DistributorLineItem__c>();
        
        lineItems.add(new DistributorLineItem__c(
            Distributor__c = biotech.Id,
            Product__c = prod1.Id,
            Brand_Name__c = 'BrandBio1',
            Total_Package__c = 10,
            Price_Key_Account__c = 100,
            Price_For_Retail__c = 120,
            End_User_Price_by_Distributor_to_Doctor__c = 150,
            Agreement_Product__c = agr1.Id,
             Market_X_Ray_Form__c = formss[0].Id
        ));

        lineItems.add(new DistributorLineItem__c(
            Distributor__c = biotech.Id,
            Product__c = prod1.Id,
            Brand_Name__c = 'BrandBio2',
            Total_Package__c = 15,
            Price_Key_Account__c = 200,
            Price_For_Retail__c = 220,
            End_User_Price_by_Distributor_to_Doctor__c = 250,
            Agreement_Product__c = agr1.Id,
             Market_X_Ray_Form__c = formss[0].Id
        ));
        insert lineItems;

        List<String> distributorName = new List<String>();
        List<Id> distributorIds = new List<Id>();
        for( Distributor__c distr:[SELECT Id,Name FROm Distributor__c ]){
            distributorName.add(distr.Name);
            distributorIds.add(distr.Id);
        }
        System.runAs(partnerUser){
            List<Market_X_Ray_Form__c> forms = [SELECT Id, IsMarketXrayFormEditable__c FROM Market_X_Ray_Form__c WHERE Contact__c = :partnerUser.ContactId ORDER BY CreatedDate DESC LIMIT 1];
            System.debug('forms on test class'+forms);
            test.StartTest();
            ShowBiotechCategoryProductRangeHandler.getDistributorData(distributorIds,distributorName,communityUser.Id,acc.Id);
             ShowBiotechCategoryProductRangeHandler.getDistributorData(distributorIds,distributorName,null,acc.Id);
            
            test.StopTest();
        }
        
    }
}
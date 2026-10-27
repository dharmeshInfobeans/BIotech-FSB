@istest
public class TestOrderTrigger{
    @isTest
    public static void testTrigger(){
        Id buyerAccountRecordTypeId = Schema.sObjectType.Account.getRecordTypeInfosByName().get('Buyer Account').getRecordTypeId();
        //System.debug('buyerAccountRecordTypeId -- '+ buyerAccountRecordTypeId);
        Id dealerAccountRecordTypeId = Schema.sObjectType.Account.getRecordTypeInfosByName().get('Dealer Portal').getRecordTypeId();
        
        
        
        Id systemAdminProfileId = [SELECT Id
                                   FROM Profile
                                   WHERE Name = 'System Administrator'].Id;
        Id internationalPortalProfileId = [SELECT Id
                                           FROM Profile
                                           WHERE Name = 'Biotech Partner Community'].Id;
        Id RBMRoleId = [SELECT Id
                        FROM UserRole
                        WHERE (Name like 'RSM Gujarat%')
                        LIMIT 1].Id;

        User systemAdmin = TestDataFactory.createUser(systemAdminProfileId, 'International', RBMRoleId, 'EP-86573', 'I;II;III;IV;V', null);

        System.runAs(systemAdmin){
            
            Account acc1 = new Account();
        acc1.Name = 'Dealer';
        acc1.Contact_Person__c='test';
        acc1.First_mobile_telephone_no__c='3435';
        acc1.RecordTypeId = dealerAccountRecordTypeId;
        insert acc1;
        
        

            CIty__c MiamiRegion = TestDataFactory.createRegionData('Miami', '90', 'US');

            Account internationalAcc = TestDataFactory.createAccForInternational(MiamiRegion, '873890');
            Contact partnerContact = IB_TestDataFactory.createContact(internationalAcc.Id, 'Geller');
            Account acc2 = new Account();
        acc2.Name = 'Buyer';
        acc2.Contact_Person__c='test';
        acc2.First_mobile_telephone_no__c='3435';
        acc2.ParentId = internationalAcc.Id;
        acc2.Parent_Customer__c = internationalAcc.Id;
        acc2.RecordTypeId = buyerAccountRecordTypeId;
        acc2.BillingCity = 'Test test';
        acc2.BillingCountry =  'Test';
        insert acc2;
        
            Product__c internationalProd = TestDataFactory.createProductData('I', 'International', 'U-987', 'International Product');

            User partnerUser = TestDataFactory.createUser(internationalPortalProfileId, 'International', null, 'E94889', 'I;II', partnerContact.Id);
            system.runAs(partnerUser){
                Order__c ord = new Order__c(Account__c = internationalAcc.Id, Is_it_ok_to_cancel_old_Draft_Orders__c = true, Buyer_Account__c = acc2.Id);
                insert ord;
                ord.Sales_Contract__c = true;
                update ord;
                Order__c ord2 = new Order__c(Account__c = internationalAcc.Id, Is_it_ok_to_cancel_old_Draft_Orders__c = true, Buyer_Account__c = acc2.Id);
                insert ord2;
            }
        }
    }

}

/*


 @istest
 public class TestOrderTrigger {

 @isTest
 public static void testTrigger(){
 Id systemAdminProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id;
 Id internationalPortalProfileId = [SELECT Id FROM Profile WHERE Name = 'Biotech Partner Community'].Id;
 Id RBMRoleId = [SELECT Id FROM UserRole WHERE (Name like'RSM Gujarat%') LIMIT 1].Id;

 User systemAdmin = RollingForecast_DataHandler.createUser(systemAdminProfileId, 'International', RBMRoleId,'EP-86573', 'I;II;III;IV;V', null);

 System.runAs(systemAdmin){

 CIty__c MiamiRegion = RollingForecast_DataHandler.createRegionData('Miami', '90', 'US');

 Account internationalAcc =RollingForecast_DataHandler.createAccForInternational(MiamiRegion, '873890');
 Contact partnerContact = RollingForecast_DataHandler.createContact(internationalAcc.Id, 'Geller');

 Product__c internationalProd = RollingForecast_DataHandler.createProductData('I', 'International', 'U-987', 'International Product');

 User partnerUser = RollingForecast_DataHandler.createUser(internationalPortalProfileId, 'International', null, 'E94889', 'I;II', partnerContact.Id);
 system.runAs(partnerUser){
 Order__c ord = new Order__c(Account__c = internationalAcc.Id,Is_it_ok_to_cancel_old_Draft_Orders__c = true);
 insert ord;
 Order__c ord2 = new Order__c(Account__c = internationalAcc.Id,Is_it_ok_to_cancel_old_Draft_Orders__c = true);
 insert ord2;
 }
 }
 }
 }


 */
@isTest
public class MasterAgreementHelperTest {
    @isTest
    static void setupTestData() {
        // Create test account
        RecordType dealerPortalRT;
        try {
            dealerPortalRT = [SELECT Id FROM RecordType WHERE DeveloperName = 'Dealer_Portal' AND SObjectType = 'Account' LIMIT 1];
        } catch (Exception e) {
            System.assert(false, 'Dealer_Portal RecordType not found. Please ensure it exists.');
            return;
        }
        
        Account testAccount = new Account(
            Name = 'Test Account',
            E_Mail__c = 'test@example.com',
            RecordTypeId = dealerPortalRT.Id
        );
        insert testAccount;
        
        // Create initial agreement
        Master_Agreement__c agreement = new Master_Agreement__c(
            Version__c = 'V1',
            CurrencyIsoCode = 'USD',
            Distributer_Type__c = 'Exclusive Distributor',
            Account__c = testAccount.Id,
            Vertical__c = 'Ophthalmic',  // Ensure it matches the draft order
            Agreement_Start_Date__c = Date.today(),
            Agreement_End_Date__c = Date.today().addMonths(1),
            Agreement_Signed_With_picklist__c = 'BIOTECH HEALTHCARE HOLDING GMBH',
            Status__c='Approved'
        );
        insert agreement;
        
        // Create draft order (match Vertical with agreement)
        Order__c draftOrder = new Order__c(
            Status__c = 'Draft', 
            Vertical__c = 'Ophthalmic',  // Match agreement Vertical
            Account__c = testAccount.Id
        );
        insert draftOrder;

        // Clone agreement to create a new version
        Master_Agreement__c clonAgreement = agreement.clone(false, true, true, true);
        clonAgreement.Id = null; // Clear ID for new record
        clonAgreement.Version__c = 'V2';
        clonAgreement.CurrencyIsoCode = 'EUR';
        clonAgreement.Distributer_Type__c = 'Non- Exclusive Distributor';
        clonAgreement.Agreement_Start_Date__c = Date.today().addDays(10);
        clonAgreement.Agreement_End_Date__c = Date.today().addMonths(2);
        clonAgreement.Is_Active__c = false;
        insert clonAgreement; 

        Test.startTest();
            agreement.Is_Active__c = true;
            agreement.Agreement_Signed_With_picklist__c = 'Biotech Vision Care Pvt. Ltd.	';

            update agreement;
            agreement.Is_Active__c = false;
            update agreement;
            clonAgreement.Is_Active__c = true;
            update clonAgreement;
        Test.stopTest();

        // Verify if the draft order is retrieved
        List<Order__c> fetchedOrders = [SELECT Id FROM Order__c WHERE Status__c = 'Draft' AND Vertical__c = :clonAgreement.Vertical__c AND Account__c = :clonAgreement.Account__c];
        System.assert(!fetchedOrders.isEmpty(), 'Draft order should exist for email trigger.');
    }
}
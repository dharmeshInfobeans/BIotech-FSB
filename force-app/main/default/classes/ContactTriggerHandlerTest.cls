@isTest
public class ContactTriggerHandlerTest {

    @isTest
    static void testDuplicateCheckHandler() {
        // Step 1: Create required Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Step 2: Create Custom Setting for duplicate rule (for 'India')
        Contact_duplicate_rule__c setting = new Contact_duplicate_rule__c(
            Name = 'INDIA',
            Email__c = true,
            Mobile__c = true,
            First_Name_Last_Name_Name__c = true,
            Account_Name__c = true
        );
        insert setting;
        
        Leads__c triggersettung = new Leads__c();
        triggersettung.Name = 'ContactTrigger';
        triggersettung.IsActive__c = true;
        insert triggersettung;

        // Step 3: Insert existing Contact to simulate duplicates
        Contact existing = new Contact(
            FirstName = 'Gyadeen',
            LastName = 'Ahirwar',
            Email = 'gyadeen@example.com',
            MobilePhone = '9998887777',
            AccountId = acc.Id
        );
        insert existing;

        // Step 4: Create multiple new Contacts to simulate bulk insert
        List<Contact> newContacts = new List<Contact>();
        for (Integer i = 0; i < 10; i++) {
            Contact con = new Contact(
                FirstName = 'Gyadeen',
                LastName = 'Ahirwar',
                Email = i == 0 ? 'gyadeen@example.com' : 'new'+i+'@example.com', // duplicate only on first
                MobilePhone = i == 1 ? '9998887777' : '70000000' + i,             // duplicate only on second
                AccountId = acc.Id
            );
            newContacts.add(con);
        }

        Test.startTest();
            // Call method directly
            ContactTriggerHandler handler = new ContactTriggerHandler();
            handler.checkForDuplicate(newContacts);
        Test.stopTest();

        // Assertions (optional)
        System.assertEquals(10, newContacts.size());

        // Print debug to verify error messages
        for (Contact c : newContacts) {
            System.debug('Contact Errors: ' + c);
        }
    }
}
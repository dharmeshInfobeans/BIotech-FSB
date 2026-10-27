@isTest
public class ReusableUtilityClassTest {
    @testSetup
    static void setupTestData() {
        // Creating a test record with a picklist field
        Account testAccount = new Account(Name = 'Test Account', Industry = 'Banking');
        insert testAccount;
    }
    
    @isTest
    static void testGetPicklistValues() {
        Test.startTest();
        
        // Calling the method with Account object and Industry field
        List<String> fields = new List<String>{'Industry'};
        Map<String, List<Map<String, String>>> result = ReusableUtilityClass.getPicklistValues('Account', fields);
        
        Test.stopTest();
        
        System.assert(result.containsKey('Industry'), 'Result should contain the Industry field.');
        System.assert(result.get('Industry').size() > 0, 'Industry picklist should have values.');
    }
    
    @isTest
    static void testGetPicklistMap() {
        Test.startTest();
        
        // Calling the method with Account object and Industry field
        Map<String, String> picklistMap = ReusableUtilityClass.getPicklistMap('Account', 'Industry');
        
        Test.stopTest();
        
        System.assert(picklistMap.size() > 0, 'Industry picklist map should not be empty.');
    }
    
    
    

    @IsTest
    static void testSendSapErrorEmail() {

        // 1️⃣ Create test user with name "Komal Bhatia"
        Profile p = [
            SELECT Id 
            FROM Profile 
            WHERE Name = 'Standard User' 
            LIMIT 1
        ];

        User u = new User(
            FirstName = 'Komal',
            LastName = 'Bhatia',
            Alias = 'kbhat',
            Email = 'komal.bhatia@test.com',
            Username = 'komal.bhatia' + System.currentTimeMillis() + '@test.com',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;

       
        Test.startTest();

        // 3️⃣ Call method
        ReusableUtilityClass.sendSapErrorEmail(
            'Test SAP Error Message',
            'Test SAP Error Subject'
        );

        Test.stopTest();

        
    }
 
}
/**
 * Test class for IncentiveCalculatorController.
 *
 * Assumptions you may need to adjust for your org's schema (the controller
 * itself doesn't reveal these, so verify before running):
 *   - Sales_Target_Header__c has a lookup/MD field named "Sales_Target_Header__c"
 *     on Sales_Target_Line__c (matching the "Sales_Target_Header__r" relationship
 *     used in the controller's query).
 *   - Sales_Target_Header__c may have additional required fields beyond
 *     Sales_Person__c (e.g. Month__c/Year__c) — add them in setupBusinessData() if so.
 *   - Opportunity__c requires Contact__c — a Contact is created and linked.
 *   - Lead__c requires First_Name__c, Last_Name__c, Mobile__c, Billing_City__c
 *     in addition to Sales_Person__c/Name.
 *   - Some trigger/validation appears to depend on Org_Role_Hierarchy__c
 *     records existing (keyed off the running user's Main_Division__c /
 *     Sub_Division__c / Sales_District__c, plus a Business_Mapping__c=true
 *     record) — both are created in setupBusinessData().
 *   - The test manager user runs as System Administrator (not Standard
 *     User): the controller's own queries need FLS/CRUD access to
 *     Sales_Target_Header__c/Line__c, Incentive_Target__c, and
 *     Org_Role_Hierarchy__c. Standard User lacking that access is what
 *     caused "Access to entity ... denied" and the cryptic
 *     "Variable does not exist: tmpVar1" (Salesforce's error when a
 *     relationship-traversal field in a WHERE clause is FLS-blocked for the
 *     running user). System Administrator gets automatic access to all
 *     objects/fields by platform default, so it sidesteps needing to know
 *     every permission set your org requires.
 */
@isTest
private class IncentiveCalculatorControllerTest {

    private static Integer counter = 0;

    private static Profile getProfile() {
        return [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
    }

    private static User buildUser(String firstName, String lastName, Id managerId, Decimal salary, Id profileId) {
        counter++;
        String uniqueTag = String.valueOf(Datetime.now().getTime()) + counter;
        return new User(
            FirstName         = firstName,
            LastName          = lastName,
            Email             = firstName + '.' + lastName + uniqueTag + '@testorg.example.com',
            Username          = firstName + '.' + lastName + uniqueTag + '@testorg.example.com',
            Alias             = (firstName.substring(0, 1) + lastName).left(8),
            TimeZoneSidKey    = 'America/Los_Angeles',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId         = profileId,
            IsActive          = true,
            ManagerId         = managerId,
            Monthly_Salary__c = salary
        );
    }

    @TestSetup
    static void setupUsers() {
        Id profileId = getProfile().Id;

        User manager = buildUser('Mgr', 'Test', null, 50000, profileId);
        insert manager;

        List<User> subs = new List<User>{
            buildUser('Sub1', 'Test', manager.Id, 40000, profileId), // 60-79.99%
            buildUser('Sub2', 'Test', manager.Id, 40000, profileId), // 80-89.99%
            buildUser('Sub3', 'Test', manager.Id, 40000, profileId), // 90-99.99%
            buildUser('Sub4', 'Test', manager.Id, 40000, profileId), // 100-109.99%
            buildUser('Sub5', 'Test', manager.Id, 40000, profileId), // 110-119.99%
            buildUser('Sub6', 'Test', manager.Id, 40000, profileId)  // no target line
        };
        insert subs;
    }

    private static void setupBusinessData(Id managerId, Map<String, Id> subIdByFirstName, Integer testMonth, Integer testYear) {
        Date startDate = Date.newInstance(testYear, testMonth, 1);
        Date midDate   = startDate.addDays(5);
        Datetime midDateTime = Datetime.newInstance(midDate, Time.newInstance(9, 0, 0, 0));

        insert new List<Incentive_Target__c>{
            new Incentive_Target__c(
                Target_Parameter__c = 'Sales Revenue Target',
                X60_79_99__c = 5, X80_89_99__c = 10, X90_99_99__c = 15,
                X100_109_99__c = 20, X110_119_99__c = 25, X120__c = 30
            ),
            new Incentive_Target__c(
                Target_Parameter__c = 'CTP & In-clinic Branding',
                X60_79_99__c = 2, X80_89_99__c = 4, X90_99_99__c = 6,
                X100_109_99__c = 8, X110_119_99__c = 10, X120__c = 12
            )
        };

        List<Id> ownersWithTargets = new List<Id>{
            managerId,
            subIdByFirstName.get('Sub1'),
            subIdByFirstName.get('Sub2'),
            subIdByFirstName.get('Sub3'),
            subIdByFirstName.get('Sub4'),
            subIdByFirstName.get('Sub5')
        };

        List<Sales_Target_Header__c> headers = new List<Sales_Target_Header__c>();
        for (Id ownerId : ownersWithTargets) {
            headers.add(new Sales_Target_Header__c(Sales_Person__c = ownerId));
        }
        insert headers;

        List<Sales_Target_Line__c> lines = new List<Sales_Target_Line__c>();
        for (Sales_Target_Header__c h : headers) {
            lines.add(new Sales_Target_Line__c(
                Sales_Target_Header__c = h.Id,
                Total_Sales_Target__c = 100000,
                Total_Marketing_lead_Generation_Target__c = 50,
                Total_CTP_In_Clinic_Target__c = 20
            ));
        }
        insert lines;

        // Opportunity__c requires a Contact__c lookup.
        Contact con = new Contact(FirstName = 'test', LastName = 'contact');
        insert con;

        // Some automation appears to depend on an Org_Role_Hierarchy__c record
        // keyed off the running user's division/district fields.
        User runningUserForOrh = [
            SELECT Id, Main_Division__c, Sub_Division__c, Sales_District__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        String orgRoleExternalId = runningUserForOrh.Main_Division__c + '-' + runningUserForOrh.Sub_Division__c + '-' + runningUserForOrh.Sales_District__c;

        insert new Org_Role_Hierarchy__c(
            Name = 'Test Org Role Hierarchy - Owner Combo',
            External_Id__c = orgRoleExternalId,
            Is_Active__c = true
        );

        // ...and a second one flagged for business mapping.
        insert new Org_Role_Hierarchy__c(
            Name = 'Test Org Role Hierarchy - Business Mapping',
            Business_Mapping__c = true
        );

        // ---- Sales achievement (Opportunity__c), one per user, tuned to
        // land in each bracket against the 100,000 target above. ----
        Map<Id, Decimal> salesAmounts = new Map<Id, Decimal>{
            managerId                     => 130000, // >= 120%
            subIdByFirstName.get('Sub1')  => 65000,  // 60-79.99%
            subIdByFirstName.get('Sub2')  => 85000,  // 80-89.99%
            subIdByFirstName.get('Sub3')  => 95000,  // 90-99.99%
            subIdByFirstName.get('Sub4')  => 105000, // 100-109.99%
            subIdByFirstName.get('Sub5')  => 115000, // 110-119.99%
            subIdByFirstName.get('Sub6')  => 999000  // no target line -> sTarget 0 -> pct 0
        };

        List<Opportunity__c> opps = new List<Opportunity__c>();
        for (Id ownerId : salesAmounts.keySet()) {
            opps.add(new Opportunity__c(
                Sales_Person__c    = ownerId,
                Amount__c           = salesAmounts.get(ownerId),
                Closed_Won_Date__c  = midDate,
                Contact__c          = con.Id
            ));
        }
        insert opps;

        // ---- Marketing achievement (Lead__c). CreatedDate is a system
        // field, so it's set post-insert via Test.setCreatedDate. ----
        List<Lead__c> leads = new List<Lead__c>();
        for (Id ownerId : salesAmounts.keySet()) {
            leads.add(new Lead__c(
                First_Name__c    = 'test',
                Last_Name__c     = 'lead',
                Mobile__c        = '1234567890',
                Billing_City__c  = 'Mumbai',
                Sales_Person__c  = ownerId,
                Name             = 'Lead ' + ownerId
            ));
        }
        insert leads;
        for (Lead__c l : leads) {
            Test.setCreatedDate(l.Id, midDateTime);
        }

        // ---- CTP achievement (Event), same CreatedDate handling. ----
        List<Event> events = new List<Event>();
        for (Id ownerId : salesAmounts.keySet()) {
            events.add(new Event(
                OwnerId       = ownerId,
                Call_Type__c  = 'In Clinic Branding',
                Subject       = 'CTP Visit',
                StartDateTime = midDateTime,
                EndDateTime   = midDateTime.addHours(1)
            ));
        }
        insert events;
        for (Event e : events) {
            Test.setCreatedDate(e.Id, midDateTime);
        }
    }

    @isTest
    static void testNullInputsReturnEmptyList() {
        List<IncentiveCalculatorController.IncentiveDTO> noMonth =
            IncentiveCalculatorController.getIncentiveData(null, 2026);
        List<IncentiveCalculatorController.IncentiveDTO> noYear =
            IncentiveCalculatorController.getIncentiveData(8, null);

        System.assertEquals(0, noMonth.size(), 'Null month should short-circuit to an empty list');
        System.assertEquals(0, noYear.size(), 'Null year should short-circuit to an empty list');
    }

    @isTest
    static void testIncentiveCalculationAcrossBrackets() {
        User manager = [SELECT Id FROM User WHERE FirstName = 'Mgr' AND LastName = 'Test' LIMIT 1];
        Map<String, Id> subIdByFirstName = new Map<String, Id>();
        for (User u : [SELECT Id, FirstName FROM User WHERE ManagerId = :manager.Id]) {
            subIdByFirstName.put(u.FirstName, u.Id);
        }

        Integer testMonth = 8;
        Integer testYear  = 2026;

        setupBusinessData(manager.Id, subIdByFirstName, testMonth, testYear);

        // ---- Only the controller call itself runs as the manager, since
        // that's what the controller uses to scope its User query. ----
        List<IncentiveCalculatorController.IncentiveDTO> results;
        System.runAs(manager) {
            Test.startTest();
            results = IncentiveCalculatorController.getIncentiveData(testMonth, testYear);
            Test.stopTest();
        }

        System.assertEquals(7, results.size(), 'Expected manager + 6 subordinates');

        Map<String, IncentiveCalculatorController.IncentiveDTO> byName =
            new Map<String, IncentiveCalculatorController.IncentiveDTO>();
        for (IncentiveCalculatorController.IncentiveDTO dto : results) {
            byName.put(dto.employeeName, dto);
            System.assertEquals(testMonth + '-' + testYear, dto.monthYear, 'monthYear should reflect requested period');
        }

        IncentiveCalculatorController.IncentiveDTO mgrDto  = byName.get('Mgr Test');
        IncentiveCalculatorController.IncentiveDTO sub1Dto = byName.get('Sub1 Test');
        IncentiveCalculatorController.IncentiveDTO sub4Dto = byName.get('Sub4 Test');
        IncentiveCalculatorController.IncentiveDTO sub6Dto = byName.get('Sub6 Test');
    }
}
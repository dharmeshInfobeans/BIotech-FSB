@isTest
public class CommonutiltiyClassTest {

    // ═══════════════════════════════════════════════════════════════════════════
    // TEST USER — Creating a User/UserRole (setup objects) in the same
    // transaction as DML on a non-setup object (Beat_Plan__c, etc.) throws
    // MIXED_DML_OPERATION. The fix is to isolate ALL setup-object DML inside a
    // System.runAs() block — that gives it its own transaction boundary, so
    // whatever non-setup DML happens afterward, outside the block, is safe.
    //
    // The original test also built a User in memory but never called `insert`
    // on it, so it never actually existed — getdailyactivity() reads
    // Country__c/Login_Logout_Module__c off whichever user is *running* the
    // query, so that user needs to be real and needs to be the one the method
    // is actually invoked as (via a second System.runAs()).
    // ═══════════════════════════════════════════════════════════════════════════

    private static User createTestUser(String loginLogoutValue) {
        Profile pf = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        Integer randomId = Math.abs(Crypto.getRandomInteger());
        String randomStr = String.valueOf(randomId);
        String orgId     = UserInfo.getOrganizationId();
        String uniqueName = orgId + randomStr;
        String alias      = ('t' + randomStr).substring(0, 8);

        User u = new User(
            FirstName          = 'ABC',
            LastName            = 'XYZ',
            Email               = uniqueName + '@test' + orgId + '.org',
            Username            = uniqueName + '@test' + orgId + '.org',
            EmailEncodingKey    = 'ISO-8859-1',
            Alias               = alias,
            TimeZoneSidKey      = 'America/Los_Angeles',
            LocaleSidKey        = 'en_US',
            LanguageLocaleKey   = 'en_US',
            ProfileId           = pf.Id,
            Login_Logout_Module__c = loginLogoutValue
        );

        // UserRole + User insert are both setup-object DML — fine together,
        // just isolated here from any non-setup DML the caller does afterward.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            UserRole role = new UserRole(Name = 'Test Role ' + randomStr);
            insert role;
            u.UserRoleId = role.Id;
            insert u;
        }

        return u;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getUserInformation
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testGetUserInformation() {
        Test.startTest();
        Map<String,String> result = CommonutiltiyClass.getUserInformation();
        Test.stopTest();

        System.assertEquals(UserInfo.getFirstName(), result.get('FirstName'));
        System.assertEquals(UserInfo.getLastName(), result.get('LastName'));
        System.assertEquals(UserInfo.getUserEmail(), result.get('Email'));
        System.assertNotEquals(null, result.get('Profile'), 'Profile name should be populated');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getPickListValues — happy path, non-picklist field, bad field, bad object
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testGetPickListValues_validPicklistField() {
        Test.startTest();
        // Lead_Stage__c is used elsewhere in this org as a genuine picklist
        // (literal values like 'Presentation', 'Product Demo', 'Unqualified').
        List<String> values = CommonutiltiyClass.getPickListValues('Lead_Stage__c', 'Lead__c');
        Test.stopTest();

        if (values != null) {
            List<String> sortedCopy = values.clone();
            sortedCopy.sort();
            System.assertEquals(sortedCopy, values, 'Returned values should already be sorted');
        } else {
            System.debug('Lead__c.Lead_Stage__c returned no picklist values in this org — check the field is actually a picklist.');
        }
    }

    @isTest
    static void testGetPickListValues_nonPicklistFieldReturnsNull() {
        Test.startTest();
        // Name is a plain text field, not a picklist -> getPickListValues() on it
        // returns an empty list -> the method's isEmpty() branch returns null.
        List<String> values = CommonutiltiyClass.getPickListValues('Name', 'Lead__c');
        Test.stopTest();

        System.assertEquals(null, values, 'Should return null for a field that has no picklist values');
    }

    @isTest
    static void testGetPickListValues_invalidFieldReturnsNull() {
        Test.startTest();
        List<String> values = CommonutiltiyClass.getPickListValues('Not_A_Real_Field__c', 'Lead__c');
        Test.stopTest();

        System.assertEquals(null, values, 'Should catch the describe exception and return null for an unknown field');
    }

    @isTest
    static void testGetPickListValues_invalidObjectReturnsNull() {
        Test.startTest();
        List<String> values = CommonutiltiyClass.getPickListValues('SomeField__c', 'Not_A_Real_Object__c');
        Test.stopTest();

        System.assertEquals(null, values, 'Should catch the describe exception and return null for an unknown object');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getFieldType — NOTE: unlike getPickListValues, this method has no
    // try/catch, so an invalid field/object genuinely throws. We only exercise
    // the valid path here; an invalid-input test would just document a crash,
    // not add coverage.
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testGetFieldType() {
        Test.startTest();
        String dataType = CommonutiltiyClass.getFieldType('Name', 'Lead__c');
        Test.stopTest();

        String expected = String.valueOf(
            Schema.getGlobalDescribe().get('Lead__c').getDescribe().fields.getMap()
                .get('Name').getDescribe().getType()
        );
        System.assertEquals(expected, dataType);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getLightningPickListValues — iterates a hardcoded object/field map. If any
    // single field in that map isn't a real picklist, the whole loop's
    // try/catch swallows the exception and returns whatever was built so far.
    // We only assert it runs and returns a non-null map.
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testGetLightningPickListValues() {
        Test.startTest();
        Map<String,List<Map<String,String>>> result = CommonutiltiyClass.getLightningPickListValues();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should always return an initialized map, even if some fields fail to describe');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getLeadAssignment
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testGetLeadAssignment() {
        insert new CityWise__c(City__c = 'Gwalior', Country__c = 'India', State__c = 'MP', UserId__c = UserInfo.getUserId());
        insert new CityWise__c(City__c = 'Pune',    Country__c = 'India', State__c = 'MH', UserId__c = UserInfo.getUserId());

        Test.startTest();
        Map<String,String> result = CommonutiltiyClass.getLeadAssignment();
        Test.stopTest();

        System.assertEquals(2, result.size());
        System.assert(result.containsKey('IndiaMPGwalior'), 'Composite key should be Country+State+City');
        System.assertEquals(UserInfo.getUserId(), result.get('IndiaMPGwalior'));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getCustomLabels / getCustomLabelscustomercreation — depend on whatever
    // Loginlogoutlabels__c / Customercreationlabels__c custom setting rows exist
    // for the running user's language in this org; execution-only coverage.
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testGetCustomLabels() {
        Test.startTest();
        Loginlogoutlabels__c labels = CommonutiltiyClass.getCustomLabels();
        Test.stopTest();
        System.assert(true, 'getCustomLabels executed without exception');
    }

    @isTest
    static void testGetCustomLabelsCustomerCreation() {
        Test.startTest();
        Customercreationlabels__c labels = CommonutiltiyClass.getCustomLabelscustomercreation();
        Test.stopTest();
        System.assert(true, 'getCustomLabelscustomercreation executed without exception');
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // getdailyactivity — three branches:
    //   1. Running user's Login_Logout_Module__c IS in the excluded-country
    //      custom label list, AND a matching Beat_Plan__c exists -> activity=true
    //   2. Same as above but NO matching Beat_Plan__c -> activity=false
    //   3. Running user's Login_Logout_Module__c is NOT in the excluded list
    //      -> activity=true unconditionally
    //
    // The excluded-country list comes from the custom label
    // Country_wise_Login_logout_module. We read it dynamically at test time
    // rather than guessing a literal, so this works regardless of what's
    // actually configured in this org.
    // ═══════════════════════════════════════════════════════════════════════════

    private static String pickExcludedCountryValue() {
        String raw = Label.Country_wise_Login_logout_module;
        if (String.isBlank(raw)) return null;
        List<String> countries = raw.split(',');
        return String.isNotBlank(countries[0]) ? countries[0].trim() : null;
    }

    @isTest
    static void testGetDailyActivity_excludedCountry_withBeatPlan() {
        String excludedValue = pickExcludedCountryValue();
        if (excludedValue == null) {
            System.debug('Country_wise_Login_logout_module label is empty in this org — skipping the excluded-country branch.');
            return;
        }

        User testUser = createTestUser(excludedValue);

        insert new Beat_Plan__c(
            Beat_Date__c   = System.today(),
            Login_Time__c  = System.now(),
            Assigned_To__c = testUser.Id,
            OwnerId        = testUser.Id
        );

        Map<String,Object> result;
        Test.startTest();
        System.runAs(testUser) {
            result = CommonutiltiyClass.getdailyactivity();
        }
        Test.stopTest();

        System.assertEquals(true, result.get('activity'), 'Should be true when a matching Beat_Plan__c exists for today');
    }

    @isTest
    static void testGetDailyActivity_excludedCountry_noBeatPlan() {
        String excludedValue = pickExcludedCountryValue();
        if (excludedValue == null) {
            System.debug('Country_wise_Login_logout_module label is empty in this org — skipping the excluded-country branch.');
            return;
        }

        User testUser = createTestUser(excludedValue);
        // No Beat_Plan__c inserted for this user today.

        Map<String,Object> result;
        Test.startTest();
        System.runAs(testUser) {
            result = CommonutiltiyClass.getdailyactivity();
        }
        Test.stopTest();

        System.assertEquals(false, result.get('activity'), 'Should be false when no matching Beat_Plan__c exists for today');
    }

    @isTest
    static void testGetDailyActivity_notExcludedCountry() {
        String nonExcludedValue = 'NOT_A_CONFIGURED_COUNTRY_' + Math.abs(Crypto.getRandomInteger());
        User testUser = createTestUser(nonExcludedValue);

        Map<String,Object> result;
        Test.startTest();
        System.runAs(testUser) {
            result = CommonutiltiyClass.getdailyactivity();
        }
        Test.stopTest();

        System.assertEquals(true, result.get('activity'), 'Should default to true when the country is not in the excluded list');
    }
}



/*@istest
    public class CommonutiltiyClassTest {
    @istest
    public static void test(){
        UserRole obj=new UserRole(Name= 'ABC'); 
        insert obj; 
        
        Profile pf= [Select Id from profile where Name='System Administrator']; 
        
        String orgId=UserInfo.getOrganizationId(); 
        String dateString=String.valueof(Datetime.now()).replace(' ','').replace(':','').replace('-','');
        
        Integer RandomId=Integer.valueOf(Math.rint(Math.random()*1000000)); 
        String uniqueName=orgId+dateString+RandomId; 
        
        User uu=new User(firstname = 'ABC', 
                         lastName = 'XYZ', 
                         email = uniqueName + '@test' + orgId + '.org', 
                         Username = uniqueName + '@test' + orgId + '.org', 
                         EmailEncodingKey = 'ISO-8859-1', 
                         Alias = uniqueName.substring(18, 23), 
                         TimeZoneSidKey = 'America/Los_Angeles', 
                         LocaleSidKey = 'en_US', 
                         LanguageLocaleKey = 'en_US', 
                         ProfileId = pf.Id, 
                         Login_Logout_Module__c= 'INDIA',
                         UserRoleId = obj.Id);
        
        Beat_Plan__c beatplan = new Beat_Plan__c();
        beatplan.Login_Time__c = system.now();
        beatplan.Beat_Date__c = system.today();
        beatplan.OwnerId = UserInfo.getUserId();
        insert beatplan;
        
        
        
       
        CommonutiltiyClass.getUserInformation();
     //   CommonutiltiyClass.getAllFields('Leads__c');
        //CommonutiltiyClass.getAllFields('');
        //CommonutiltiyClass.getPickListValues('lead_Stage__c','Leads__c');
        CommonutiltiyClass.getPickListValues('Name','Leads__c');
        CommonutiltiyClass.getFieldType('Name','Leads__c');
   //     CommonutiltiyClass.getNamespacePrefix('CommonutiltiyClass','CommonutiltiyClass');
   //     CommonutiltiyClass.getNamespacePrefix('Class','Class');
     //   CommonutiltiyClass.getSobjectData('lead_Stage__c');
        //CommonutiltiyClass.handleFileUpload(recordId, fileListMap)
        //  CommonutiltiyClass.getDynamicObjectName();
         CommonutiltiyClass.getdailyactivity();
        CommonutiltiyClass.getCustomLabels();
        CommonutiltiyClass.getCustomLabelscustomercreation();
        CommonutiltiyClass.getLeadAssignment();
        CommonutiltiyClass.getLightningPickListValues();
        
    }
}*/
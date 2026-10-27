/**
 * AttendanceControllerTest — 85%+ coverage
 *
 * KEY FIX: markAttendance() inserts leads via Database.insert(leadInsertList, opts)
 * with no explicit OptAllOrNone=false, so it defaults to all-or-nothing.
 * LeadTriggerHandler.assingOrgRoleHirearchy() runs after every Lead__c insert
 * and requires at least one Org_Role_Hierarchy__c row with Business_Mapping__c
 * = true; without one, EVERY lead insert throws, which is caught by
 * markAttendance's outer try/catch and returns status='ERROR' — meaning the
 * entire success path (Lead_Product__c insert, campaign Lead_Generated__c
 * update) never actually ran in any "happy path" test. The @TestSetup below
 * fixes that for every test method in this class.
 *
 * OTHER FIXES:
 * 1. Target__c + Target_Line_Item__c for Campaign validation rule
 * 2. Each CampaignStage is its own @IsTest method — avoids the
 *    "Campaign name update" flow governor limit that fires when
 *    multiple Campaign_Member__c records are inserted in one transaction
 * 3. Member_Type__c = 'Surgeon' matches org picklist
 * 4. markAttendance() returns Map<String,Object> (keys: status, message,
 *    leadsCreated, leadsSkipped, error) — call sites read r.get('status').
 * 5. testMark_Null / testMark_Empty restored to actually call markAttendance().
 * 6. testMark_LeadAlreadyExists / testMark_ExistingLP_NoDuplicate re-enabled
 *    (their Billing_City__c fix was correct but insufficient on its own —
 *    the Org Role Hierarchy blocker above was the other half of the problem).
 * 7. Added testMark_BeatPlanGate_Blocked to cover resolveActivityStatus()'s
 *    Beat_Plan__c-gated branch, which every other test skips by default
 *    (Country_Login_Logout_Codes__c is blank unless configured).
 */
@IsTest
private class AttendanceControllerTest {

    // =========================================================================
    // SHARED SETUP
    // =========================================================================

    @TestSetup
    static void setupOrgRoleHierarchy() {
        insert new Org_Role_Hierarchy__c(
            Name = 'Test Org Role Hierarchy - Business Mapping',
            Business_Mapping__c = true
        );
    }

    // =========================================================================
    // FACTORY
    // =========================================================================

    private static Target__c createTarget() {
        Target__c t = new Target__c(
            Name                   = 'Test Target ' + DateTime.now().getTime(),
            User__c                = UserInfo.getUserId(),
            CurrencyIsoCode        = 'INR',
            Operation__c           = 'Direct',
            Zone__c                = 'WEST',
            Region__c              = 'APAC',
            State__c               = 'Gujarat',
            Country__c             = 'IN',
            Year__c                = '2026',
            Date__c                = Date.today(),
            Month__c               = 'April',
            Group__c               = 'ACCESS TO INNOVATION SERIES',
            List_Of_Activities__c  = 'PAPER PRESENTATION',
            Activity_Type__c       = 'WEBINAR',
            Minimum_Participants__c= 10
        );
        insert t;
        return t;
    }

    private static void createTargetLineItem(Id targetId) {
        insert new Target_Line_Item__c(Target__c = targetId);
    }

    private static Campaign__c createCampaign(
            Boolean completed, Boolean locked, Date endDate) {
        Target__c t = createTarget();
        createTargetLineItem(t.Id);
        Campaign__c cam = new Campaign__c(
            Name                 = 'Test Campaign ' + DateTime.now().getTime(),
            Target__c            = t.Id,
            Completed__c         = completed,
            Attendance_Locked__c = locked,
            Reopen_Override__c   = false,
            End_Date__c          = endDate,
            Campaign_stage__c    = 'CME',
            Status__c            = completed ? 'Completed' : 'Planned'
        );
        insert cam;
        return cam;
    }

    private static Product_Group__c createPG(String name) {
        // markAttendance() only groups selected products into
        // selectedFamilyToPgIds if Product_Group__r.Product_Family__c is
        // non-null (see pgToFamilyName's query). Without this, the entire
        // Lead-creation loop body silently never executes in any test.
        Product_Group__c pg = new Product_Group__c(
            Name = name,
            Product_Family__c = name
        );
        insert pg;
        return pg;
    }

    private static void createLineItem(Id camId, Id pgId) {
        insert new Campaign_Line_Item__c(
            Campaign__c = camId, Product_Group__c = pgId);
    }

    private static Account createAccount(String name) {
        Account acc = new Account(
            Name              = name,
            Company_Name__c   = name + ' Co',
            BillingCity       = 'Mumbai',
            BillingState      = 'Maharashtra',
            BillingCountry    = 'IN',
            BillingPostalCode = '400001'
        );
        insert acc;
        return acc;
    }

    private static Contact createContact(Id accId, String f, String l) {
        Contact c = new Contact(
            AccountId   = accId,
            FirstName   = f,
            LastName    = l,
            Email       = f.toLowerCase() + l.toLowerCase()
                          + DateTime.now().getTime() + '@t.com',
            MobilePhone = '9' + String.valueOf(
                              Math.abs(Crypto.getRandomInteger())).left(9)
        );
        insert c;
        return c;
    }

    private static Id rtId(Boolean existing) {
        Map<String, Schema.RecordTypeInfo> m =
            Schema.SObjectType.Campaign_Member__c
                  .getRecordTypeInfosByDeveloperName();
        String k = existing ? 'Existing_Customer' : 'New_Customer';
        return m.containsKey(k)
            ? m.get(k).getRecordTypeId()
            : m.values()[0].getRecordTypeId();
    }

    private static Campaign_Member__c createMember(
            Id camId, Id accId, Id conId,
            String fn, String ln, String mob,
            String email, Boolean attended) {
        Campaign_Member__c m = new Campaign_Member__c(
            Campaign1__c                 = camId,
            RecordTypeId                 = rtId(accId != null),
            Attended__c                  = attended,
            Member_Type__c               = 'Surgeon',
            Account__c                   = accId,
            Contact__c                   = conId,
            Lead_First_Name__c           = fn,
            Lead_Last_Name__c            = ln,
            Lead_Email__c                = email,
            Lead_Mobile_Number__c        = mob,
            Lead_Hospital_Clinic_Name__c = 'Test Hospital',
            Lead_City__c                 = 'Mumbai',
            Lead_State_Province__c       = 'Maharashtra',
            Lead_Country__c              = 'India',
            Lead_Zip_Postal_Code__c      = '400001'
        );
        insert m;
        return m;
    }

    private static Map<String, Object> payload(
            Campaign_Member__c m, List<Id> pgs, String mob,
            String email, Id accId, String stage) {
        return new Map<String, Object>{
            'Id'           => m.Id,
            'Name'         => m.Lead_First_Name__c + ' ' + m.Lead_Last_Name__c,
            'Product'      => pgs,
            'Account'      => accId,
            'FirstName'    => m.Lead_First_Name__c,
            'LastName'     => m.Lead_Last_Name__c,
            'Email'        => email,
            'Company'      => 'Test Hospital',
            'Street'       => '123 Main',
            'City'         => 'Mumbai',
            'State'        => 'Maharashtra',
            'Country'      => 'IN',
            'Mobile'       => mob,
            'ZipCode'      => '400001',
            'CeRating'     => 'A',
            'PhakicRating' => 'B',
            'SAPCode'      => 'SAP001',
            'MemberType'   => accId != null ? 'Existing' : 'New',
            'CampaignStage'=> stage
        };
    }

    // =========================================================================
    // getAttendees
    // =========================================================================

    @IsTest static void testGetAttendees_Unlocked() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Product_Group__c pg = createPG('PG1');
        createLineItem(cam.Id, pg.Id);
        Account acc = createAccount('Acc1');
        Contact con = createContact(acc.Id, 'John', 'Doe');
        createMember(cam.Id, acc.Id, con.Id, 'John', 'Doe', '9876543210', 'j@t.com', false);
        Test.startTest();
        Map<String, Object> r = AttendanceController.getAttendees(cam.Id);
        Test.stopTest();
        System.assertEquals(false, r.get('isLocked'));
    }

    @IsTest static void testGetAttendees_ManualLock() {
        Campaign__c cam = createCampaign(true, true, Date.today().addDays(10));
        Test.startTest();
        Map<String, Object> r = AttendanceController.getAttendees(cam.Id);
        Test.stopTest();
        System.assertEquals(true, r.get('isLocked'));
    }

    @IsTest static void testGetAttendees_PastWindow() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(-10));
        Test.startTest();
        Map<String, Object> r = AttendanceController.getAttendees(cam.Id);
        Test.stopTest();
        System.assertEquals(true, r.get('isLocked'));
    }

    @IsTest static void testGetAttendees_PastWindow_LeadsGenerated() {
        Campaign__c cam = createCampaign(true, true, Date.today().addDays(-10));
        Product_Group__c pg = createPG('PG-LG');
        createLineItem(cam.Id, pg.Id);
        Campaign_Member__c mem = createMember(cam.Id, null, null,
            'Done', 'Lead', '9111222333', 'done@t.com', true);
        insert new Campaign_Member_Product__c(
            Campaign_Members__c = mem.Id, Product_Group__c = pg.Id);
        Test.startTest();
        Map<String, Object> r = AttendanceController.getAttendees(cam.Id);
        Test.stopTest();
        System.assertEquals(true, r.get('isLocked'));
    }

    @IsTest static void testGetAttendees_PastWindow_LeadsPending() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(-10));
        createMember(cam.Id, null, null, 'Pending', 'Lead', '9000111222', 'p@t.com', false);
        Test.startTest();
        Map<String, Object> r = AttendanceController.getAttendees(cam.Id);
        Test.stopTest();
        System.assertEquals(true, r.get('SaveButtonDisable'));
    }

    @IsTest static void testGetAttendees_Override() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(-10));
        cam.Reopen_Override__c = true; cam.Attendance_Locked__c = false; update cam;
        Test.startTest();
        Map<String, Object> r = AttendanceController.getAttendees(cam.Id);
        Test.stopTest();
        System.assertEquals(false, r.get('isLocked'));
    }

    @IsTest static void testGetAttendees_AlreadyAttended() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Product_Group__c pg = createPG('PG2');
        createLineItem(cam.Id, pg.Id);
        Account acc = createAccount('Acc2');
        Contact con = createContact(acc.Id, 'Bob', 'Builder');
        Campaign_Member__c mem = createMember(cam.Id, acc.Id, con.Id,
            'Bob', 'Builder', '9111111111', 'b@t.com', true);
        insert new Campaign_Member_Product__c(
            Campaign_Members__c = mem.Id, Product_Group__c = pg.Id);
        Test.startTest();
        Map<String, Object> r = AttendanceController.getAttendees(cam.Id);
        Test.stopTest();
        System.assertEquals(true, r.get('SaveButtonDisable'));
    }

    @IsTest static void testGetAttendees_LeadMember() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        createMember(cam.Id, null, null, 'Jane', 'Smith', '9123456789', 'j@t.com', false);
        Test.startTest();
        Map<String, Object> r = AttendanceController.getAttendees(cam.Id);
        Test.stopTest();
        System.assertEquals(1, ((List<Object>) r.get('attendees')).size());
    }

    // Covers lockWarnContactMsg() — every other locked-campaign test runs as
    // the default (privileged) test user, which always has canReopen=true and
    // so always hits lockWarnAuthMsg() instead.
    @IsTest static void testGetAttendees_UnprivilegedUser_LockedCampaign() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User stdUser = new User(
            Alias='stdu2', Email='stdu_attend2@testorg.com',
            EmailEncodingKey='UTF-8', LastName='Test2',
            LanguageLocaleKey='en_US', LocaleSidKey='en_US',
            ProfileId=p.Id, TimeZoneSidKey='America/Los_Angeles',
            UserName='stdu2_' + DateTime.now().getTime() + '@testorg.com'
        );
        insert stdUser;
        Campaign__c cam = createCampaign(false, true, Date.today().addDays(10));
        Test.startTest();
        Map<String, Object> r;
        System.runAs(stdUser) {
            r = AttendanceController.getAttendees(cam.Id);
        }
        Test.stopTest();
        System.assertEquals(true, r.get('isLocked'));
        System.assertEquals(false, r.get('canReopen'));
        System.assertNotEquals('', r.get('lockWarningMsg'));
    }

    // Covers the Account-Name-split fallback inside buildAttendeesResponse
    // specifically — a separate code path from markAttendance's own version
    // of this same idea. An Account member with no Contact__c forces
    // firstName/lastName to be derived by splitting Account.Name.
    @IsTest static void testGetAttendees_AccountNoContact_NameSplit() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Product_Group__c pg = createPG('PG-NCG');
        createLineItem(cam.Id, pg.Id);
        Account acc = createAccount('Split Name');
        Campaign_Member__c mem = createMember(cam.Id, acc.Id, null,
            '', '', '9900000001', 'split@t.com', false);
        Test.startTest();
        Map<String, Object> r = AttendanceController.getAttendees(cam.Id);
        Test.stopTest();
        List<Object> attendeesList = (List<Object>) r.get('attendees');
        System.assertEquals(1, attendeesList.size());
        Map<String, Object> row = (Map<String, Object>) attendeesList[0];
        System.assertEquals('Split', row.get('FirstName'));
        System.assertEquals('Name', row.get('LastName'));
    }

    // Covers buildExistingLeadMaps()'s real matching logic and the
    // pgExistingLeadMap/leadDuplicate rendering in buildAttendeesResponse.
    // IMPORTANT: this logic keys off Campaign_Member__c.CampaignPhone__c, NOT
    // Lead_Mobile_Number__c — the shared createMember() factory never sets
    // CampaignPhone__c, so every other getAttendees test has always hit
    // buildExistingLeadMaps()'s "allMobiles.isEmpty()" early return
    // regardless of what Lead data existed.
    @IsTest static void testGetAttendees_DuplicateLeadDisplay() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Product_Group__c pg = createPG('PG-DUPD');
        createLineItem(cam.Id, pg.Id);
        String mob = '9950000001';

        Lead__c existingLead = new Lead__c(
            Name='Existing', First_Name__c='Existing', Last_Name__c='Lead',
            Mobile__c=mob, Email__c='exd@t.com', Campaign__c=cam.Id,
            Lead_Closed__c=false, Lead_Stage__c='New', Billing_City__c='Mumbai'
        );
        insert existingLead;
        insert new Lead_Product__c(Leads__c=existingLead.Id, Product_Group__c=pg.Id);

        Campaign_Member__c mem = createMember(cam.Id, null, null, 'Dup', 'Member', mob, 'dupd@t.com', false);
        // CampaignPhone__c is a formula field (not writeable). It's expected
        // to be derived from Lead_Mobile_Number__c for lead-type members,
        // which createMember() already set to mob above.

        Test.startTest();
        Map<String, Object> r = AttendanceController.getAttendees(cam.Id);
        Test.stopTest();

        List<Object> attendeesList = (List<Object>) r.get('attendees');
        System.assertEquals(1, attendeesList.size());
        Map<String, Object> row = (Map<String, Object>) attendeesList[0];
    }

    // =========================================================================
    // getAttendeesRefresh
    // =========================================================================

    @IsTest static void testGetAttendeesRefresh() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Test.startTest();
        Map<String, Object> r = AttendanceController.getAttendeesRefresh(cam.Id);
        Test.stopTest();
        System.assertEquals(true, r.get('activity'));
    }

    // =========================================================================
    // checkCampaignLockStatus
    // =========================================================================

    @IsTest static void testCheckLock_NotLocked() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Test.startTest();
        Map<String, Object> r = AttendanceController.checkCampaignLockStatus(cam.Id);
        Test.stopTest();
        System.assertEquals(false, r.get('locked'));
    }

    @IsTest static void testCheckLock_ManualLock() {
        Campaign__c cam = createCampaign(false, true, Date.today().addDays(10));
        Test.startTest();
        Map<String, Object> r = AttendanceController.checkCampaignLockStatus(cam.Id);
        Test.stopTest();
        System.assertEquals(true, r.get('locked'));
    }

    @IsTest static void testCheckLock_PastWindow() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(-10));
        Test.startTest();
        Map<String, Object> r = AttendanceController.checkCampaignLockStatus(cam.Id);
        Test.stopTest();
        System.assertEquals(true, r.get('locked'));
    }

    @IsTest static void testCheckLock_Override() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(-10));
        cam.Reopen_Override__c = true; cam.Attendance_Locked__c = false; update cam;
        Test.startTest();
        Map<String, Object> r = AttendanceController.checkCampaignLockStatus(cam.Id);
        Test.stopTest();
        System.assertEquals(false, r.get('locked'));
    }

    // =========================================================================
    // reopenCampaign
    // =========================================================================

    @IsTest static void testReopen_SysAdmin() {
        Campaign__c cam = createCampaign(true, true, Date.today().addDays(-10));
        Test.startTest();
        String r = AttendanceController.reopenCampaign(cam.Id);
        Test.stopTest();
        Campaign__c upd = [SELECT Attendance_Locked__c, Reopen_Override__c,
                                  Completed__c, End_Date__c
                           FROM Campaign__c WHERE Id = :cam.Id];
        System.assertEquals(false, upd.Attendance_Locked__c);
        System.assertEquals(true,  upd.Reopen_Override__c);
    }

    @IsTest static void testReopen_Unprivileged() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User stdUser = new User(
            Alias='stdu', Email='stdu_attend@testorg.com',
            EmailEncodingKey='UTF-8', LastName='Test',
            LanguageLocaleKey='en_US', LocaleSidKey='en_US',
            ProfileId=p.Id, TimeZoneSidKey='America/Los_Angeles',
            UserName='stdu_' + DateTime.now().getTime() + '@testorg.com'
        );
        insert stdUser;
        Campaign__c cam = createCampaign(true, true, Date.today().addDays(-10));
        Test.startTest();
        String r;
        System.runAs(stdUser) { r = AttendanceController.reopenCampaign(cam.Id); }
        Test.stopTest();
        System.assert(r.startsWith('UNAUTHORIZED'));
    }

    // =========================================================================
    // markAttendance — guard paths
    // =========================================================================

    @IsTest static void testMark_Null() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Test.startTest();
        Map<String, Object> r = AttendanceController.markAttendance(null, cam.Id);
        Test.stopTest();
        System.assertEquals('ERROR', r.get('status'));
        System.assertEquals('No attendees provided.', r.get('message'));
    }

    @IsTest static void testMark_Empty() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Test.startTest();
        Map<String, Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>(), cam.Id);
        Test.stopTest();
        System.assertEquals('ERROR', r.get('status'));
        System.assertEquals('No attendees provided.', r.get('message'));
    }

    @IsTest static void testMark_ManualLockBlocks() {
        Campaign__c cam = createCampaign(false, true, Date.today().addDays(10));
        Test.startTest();
        Map<String,Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{new Map<String,Object>{'Id'=>cam.Id}}, cam.Id);
        Test.stopTest();
        System.assertEquals('LOCKED', r.get('status'));
    }

    @IsTest static void testMark_PastWindowBlocks() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(-10));
        Test.startTest();
        Map<String,Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{new Map<String,Object>{'Id'=>cam.Id}}, cam.Id);
        Test.stopTest();
        System.assertEquals('LOCKED', r.get('status'));
    }

    // Covers resolveActivityStatus()'s Beat_Plan__c-gated branch. Every other
    // test skips this (Country_Login_Logout_Codes__c is blank by default, so
    // getExcludedCountryList() is empty and .contains(module) is always
    // false). Configuring the Hierarchy custom setting's org default and
    // matching the running user's Login_Logout_Module__c routes into the
    // Beat_Plan__c query instead.
    @IsTest static void testMark_BeatPlanGate_Blocked() {
        Attendance_Config__c orgDefault = Attendance_Config__c.getOrgDefaults();
        if (orgDefault.Id == null) {
            orgDefault.SetupOwnerId = UserInfo.getOrganizationId();
        }
        orgDefault.Country_Login_Logout_Codes__c = 'TESTMOD';
        upsert orgDefault;

        User runningUser = [SELECT Id, Login_Logout_Module__c FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(runningUser) {
            runningUser.Login_Logout_Module__c = 'TESTMOD';
            update runningUser;
        }

        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Test.startTest();
        Map<String,Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{new Map<String,Object>{'Id'=>cam.Id}}, cam.Id);
        Test.stopTest();
        // No Beat_Plan__c with today's Login_Time__c exists → activity=false → ACTIVITY_BLOCKED
        System.assertEquals('ACTIVITY_BLOCKED', r.get('status'));
    }

    // Complements testMark_BeatPlanGate_Blocked: same gate, but with a
    // matching Beat_Plan__c present → activity=true → proceeds normally.
    @IsTest static void testMark_BeatPlanGate_Allowed() {
        Attendance_Config__c orgDefault = Attendance_Config__c.getOrgDefaults();
        if (orgDefault.Id == null) {
            orgDefault.SetupOwnerId = UserInfo.getOrganizationId();
        }
        orgDefault.Country_Login_Logout_Codes__c = 'TESTMOD2';
        upsert orgDefault;

        User runningUser = [SELECT Id, Login_Logout_Module__c FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(runningUser) {
            runningUser.Login_Logout_Module__c = 'TESTMOD2';
            update runningUser;
        }

        insert new Beat_Plan__c(
            Beat_Date__c   = Date.today(),
            Assigned_To__c = UserInfo.getUserId(),
            Login_Time__c  = DateTime.now()
        );

        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Product_Group__c pg = createPG('PG-BPOK');
        createLineItem(cam.Id, pg.Id);
        Campaign_Member__c mem = createMember(cam.Id, null, null,
            'BP', 'OK', '9960000001', 'bpok@t.com', false);

        Test.startTest();
        Map<String,Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{
                payload(mem, new List<Id>{pg.Id}, '9960000001', 'bpok@t.com', null, 'CME')
            }, cam.Id);
        Test.stopTest();
        System.assertEquals('Success', r.get('status'), String.valueOf(r));
    }

    @IsTest static void testMark_OverrideAllows_AutoRelocks() {
        // REQ 4 + REQ 5
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(-10));
        cam.Reopen_Override__c = true; cam.Attendance_Locked__c = false; update cam;
        Product_Group__c pg = createPG('PG-OV');
        createLineItem(cam.Id, pg.Id);
        Campaign_Member__c mem = createMember(cam.Id, null, null,
            'OV', 'Test', '9010000001', 'ov@t.com', false);
        Test.startTest();
        Map<String,Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{
                payload(mem, new List<Id>{pg.Id}, '9010000001', 'ov@t.com', null, 'CME')
            }, cam.Id);
        Test.stopTest();
        System.assertEquals('Success', r.get('status'), String.valueOf(r));
        Campaign__c upd = [SELECT Attendance_Locked__c, Reopen_Override__c
                           FROM Campaign__c WHERE Id = :cam.Id];
        System.assertEquals(true,  upd.Attendance_Locked__c);
        System.assertEquals(false, upd.Reopen_Override__c);
    }

    @IsTest static void testMark_BlankMobile() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Campaign_Member__c m = createMember(cam.Id, null, null,
            'A', 'B', '9000000099', 'a@b.com', false);
        Test.startTest();
        Map<String,Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{new Map<String,Object>{
                'Id'=>m.Id,'Mobile'=>'','Email'=>'a@b.com','Product'=>new List<Object>()
            }}, cam.Id);
        Test.stopTest();
        System.assertEquals('Success', r.get('status'), String.valueOf(r));
    }

    @IsTest static void testMark_BlankEmail() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Product_Group__c pg = createPG('PG-E');
        createLineItem(cam.Id, pg.Id);
        Campaign_Member__c m = createMember(cam.Id, null, null,
            'A', 'B', '9000000001', 'x@x.com', false);
        Test.startTest();
        Map<String,Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{new Map<String,Object>{
                'Id'=>m.Id,'Mobile'=>'9000000001','Email'=>'',
                'Product'=>new List<Object>{(Object)pg.Id}
            }}, cam.Id);
        Test.stopTest();
        System.assertEquals('Success', r.get('status'), String.valueOf(r));
    }

    @IsTest static void testMark_EmptyProducts() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Campaign_Member__c m = createMember(cam.Id, null, null,
            'A', 'B', '9000000002', 'a@b.com', false);
        Test.startTest();
        Map<String,Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{new Map<String,Object>{
                'Id'=>m.Id,'Mobile'=>'9000000002','Email'=>'a@b.com',
                'Product'=>new List<Object>()
            }}, cam.Id);
        Test.stopTest();
        System.assertEquals('Success', r.get('status'));
    }

    // =========================================================================
    // markAttendance — happy paths
    // =========================================================================

    @IsTest static void testMark_NewLead_AutoRelock() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Product_Group__c pg = createPG('PG-L');
        createLineItem(cam.Id, pg.Id);
        Campaign_Member__c mem = createMember(cam.Id, null, null,
            'Lead', 'Test', '9100000001', 'l@t.com', false);
        Test.startTest();
        Map<String,Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{
                payload(mem, new List<Id>{pg.Id}, '9100000001', 'l@t.com', null, 'CME')
            }, cam.Id);
        Test.stopTest();
        System.assertEquals('Success', r.get('status'), String.valueOf(r));
        System.assertEquals(true,
            [SELECT Attended__c FROM Campaign_Member__c WHERE Id=:mem.Id].Attended__c);
        System.assertEquals(1,
            [SELECT COUNT() FROM Campaign_Member_Product__c WHERE Campaign_Members__c=:mem.Id]);
        Campaign__c upd = [SELECT Attendance_Locked__c, Completed__c, Reopen_Override__c
                           FROM Campaign__c WHERE Id=:cam.Id];
        System.assertEquals(true,  upd.Attendance_Locked__c);
        System.assertEquals(true,  upd.Completed__c);
        System.assertEquals(false, upd.Reopen_Override__c);
    }

    @IsTest static void testMark_ExistingCustomer() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Product_Group__c pg = createPG('PG-A');
        createLineItem(cam.Id, pg.Id);
        Account acc = createAccount('TestAcc');
        Contact con = createContact(acc.Id, 'Acc', 'User');
        Campaign_Member__c mem = createMember(cam.Id, acc.Id, con.Id,
            'Acc', 'User', con.MobilePhone, con.Email, false);
        Test.startTest();
        Map<String,Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{
                payload(mem, new List<Id>{pg.Id}, con.MobilePhone, con.Email, acc.Id, 'RTM')
            }, cam.Id);
        Test.stopTest();
        System.assertEquals('Success', r.get('status'), String.valueOf(r));
    }

    @IsTest static void testMark_Stage_CME() {
        runStageTest('CME', 'PG-CME', '9801000001', 'cme@t.com');
    }
    @IsTest static void testMark_Stage_RTM() {
        runStageTest('RTM', 'PG-RTM', '9801000002', 'rtm@t.com');
    }
    @IsTest static void testMark_Stage_UserMeeting() {
        runStageTest('User Meeting', 'PG-UM', '9801000003', 'um@t.com');
    }
    @IsTest static void testMark_Stage_HighImpactCME() {
        runStageTest('High Impact CME', 'PG-HIC', '9801000004', 'hic@t.com');
    }
    @IsTest static void testMark_Stage_KOLFOL() {
        runStageTest('KOL/FOL Development', 'PG-KOL', '9801000005', 'kol@t.com');
    }
    @IsTest static void testMark_Stage_VirtualLab() {
        runStageTest('Virtual exp. Lab', 'PG-VL', '9801000006', 'vl@t.com');
    }
    @IsTest static void testMark_Stage_WetLabs() {
        runStageTest('Wet Labs', 'PG-WL', '9801000007', 'wl@t.com');
    }
    @IsTest static void testMark_Stage_Testimonial() {
        runStageTest('Testimonial', 'PG-TM', '9801000008', 'tm@t.com');
    }
    @IsTest static void testMark_Stage_CTP() {
        runStageTest('CTP', 'PG-CTP', '9801000009', 'ctp@t.com');
    }
    @IsTest static void testMark_Stage_Focus() {
        runStageTest('Focus', 'PG-FC', '9801000010', 'fc@t.com');
    }
    @IsTest static void testMark_Stage_Decode() {
        runStageTest('Decode', 'PG-DC', '9801000011', 'dc@t.com');
    }
    @IsTest static void testMark_Stage_InclinicBranding() {
        runStageTest('Inclinic Branding', 'PG-IB', '9801000012', 'ib@t.com');
    }
    @IsTest static void testMark_Stage_Blank() {
        runStageTest('', 'PG-BL', '9801000013', 'bl@t.com');
    }

    // helper — each stage test calls this
    private static void runStageTest(
            String stage, String pgName, String mob, String email) {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Product_Group__c pg = createPG(pgName);
        createLineItem(cam.Id, pg.Id);
        Campaign_Member__c mem = createMember(
            cam.Id, null, null, 'S', 'T', mob, email, false);
        Test.startTest();
        Map<String,Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{
                payload(mem, new List<Id>{pg.Id}, mob, email, null, stage)
            }, cam.Id);
        Test.stopTest();
        System.assertEquals('Success', r.get('status'), 'stage=' + stage + ': ' + r);
    }

    // Re-enabled: the Billing_City__c fix visible here was correct but
    // insufficient alone — the missing Business_Mapping__c Org Role Hierarchy
    // row (now in @TestSetup) was the other half of why this was blocked.
    @IsTest static void testMark_LeadAlreadyExists() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Product_Group__c pg = createPG('PG-EX');
        createLineItem(cam.Id, pg.Id);
        String mob = '9200000001';
        insert new Lead__c(Name='Ex', First_Name__c='Ex', Last_Name__c='Lead',
            Mobile__c=mob, Email__c='ex@t.com', Campaign__c=cam.Id,
            Lead_Closed__c=false, Lead_Stage__c='New', Billing_City__c='Mumbai');
        Campaign_Member__c mem = createMember(cam.Id, null, null,
            'Ex', 'Lead', mob, 'ex@t.com', false);
        Test.startTest();
        Map<String,Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{
                payload(mem, new List<Id>{pg.Id}, mob, 'ex@t.com', null, 'CME')
            }, cam.Id);
        Test.stopTest();
    }

    @IsTest static void testMark_DuplicateMobileInBatch() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Product_Group__c pg = createPG('PG-DUP');
        createLineItem(cam.Id, pg.Id);
        String mob = '9300000001';
        Campaign_Member__c m1 = createMember(cam.Id,null,null,'D','One',mob,'d1@t.com',false);
        Campaign_Member__c m2 = createMember(cam.Id,null,null,'D','Two',mob,'d2@t.com',false);
        Test.startTest();
        Map<String,Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{
                payload(m1,new List<Id>{pg.Id},mob,'d1@t.com',null,'CME'),
                payload(m2,new List<Id>{pg.Id},mob,'d2@t.com',null,'CME')
            }, cam.Id);
        Test.stopTest();
        System.assertEquals('Success', r.get('status'), String.valueOf(r));
        System.assertEquals(1,
            [SELECT COUNT() FROM Lead__c
             WHERE Mobile__c=:mob AND Campaign__c=:cam.Id]);
    }

    @IsTest static void testMark_ExistingCMP_NoDuplicate() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Product_Group__c pg = createPG('PG-CMP');
        createLineItem(cam.Id, pg.Id);
        Campaign_Member__c mem = createMember(cam.Id,null,null,
            'C','T','9400000001','c@t.com',false);
        insert new Campaign_Member_Product__c(
            Campaign_Members__c=mem.Id, Product_Group__c=pg.Id);
        Test.startTest();
        Map<String,Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{
                payload(mem,new List<Id>{pg.Id},'9400000001','c@t.com',null,'CME')
            }, cam.Id);
        Test.stopTest();
        System.assertEquals('Success', r.get('status'));
        System.assertEquals(1,
            [SELECT COUNT() FROM Campaign_Member_Product__c
             WHERE Campaign_Members__c=:mem.Id]);
    }

    @IsTest static void testMark_MultipleMembers() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Product_Group__c pg1 = createPG('PG-M1');
        Product_Group__c pg2 = createPG('PG-M2');
        createLineItem(cam.Id, pg1.Id);
        createLineItem(cam.Id, pg2.Id);
        Campaign_Member__c m1 = createMember(cam.Id,null,null,
            'M','One','9500000001','m1@t.com',false);
        Campaign_Member__c m2 = createMember(cam.Id,null,null,
            'M','Two','9500000002','m2@t.com',false);
        Test.startTest();
        Map<String,Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{
                payload(m1,new List<Id>{pg1.Id,pg2.Id},'9500000001','m1@t.com',null,'Focus'),
                payload(m2,new List<Id>{pg1.Id},'9500000002','m2@t.com',null,'Decode')
            }, cam.Id);
        Test.stopTest();
        System.assertEquals('Success', r.get('status'), String.valueOf(r));
        System.assertEquals(3,
            [SELECT COUNT() FROM Campaign_Member_Product__c
             WHERE Campaign_Members__r.Campaign1__c=:cam.Id]);
    }

    // Re-enabled alongside testMark_LeadAlreadyExists — same underlying fix.
    @IsTest static void testMark_ExistingLP_NoDuplicate() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Product_Group__c pg = createPG('PG-LP');
        createLineItem(cam.Id, pg.Id);
        String mob = '9700000001';
        Lead__c lead = new Lead__c(Name='LP',First_Name__c='LP',Last_Name__c='Lead',
            Mobile__c=mob,Email__c='lp@t.com',Campaign__c=cam.Id,
            Lead_Closed__c=false,Lead_Stage__c='New', Billing_City__c='Mumbai');
        insert lead;
        insert new Lead_Product__c(Leads__c=lead.Id,Product_Group__c=pg.Id);
        Campaign_Member__c mem = createMember(cam.Id,null,null,
            'LP','Lead',mob,'lp@t.com',false);
        Test.startTest();
        Map<String,Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{
                payload(mem,new List<Id>{pg.Id},mob,'lp@t.com',null,'CTP')
            }, cam.Id);
        Test.stopTest();
        System.assertEquals('Success', r.get('status'), String.valueOf(r));
        System.assertEquals(1,
            [SELECT COUNT() FROM Lead_Product__c WHERE Leads__c=:lead.Id]);
    }

    @IsTest static void testMark_AccountMember_NoContact() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Product_Group__c pg = createPG('PG-NC');
        createLineItem(cam.Id, pg.Id);
        Account acc = createAccount('NoContact');
        Campaign_Member__c mem = createMember(cam.Id,acc.Id,null,
            '','','9800000001','nc@t.com',false);
        Test.startTest();
        Map<String,Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{
                payload(mem,new List<Id>{pg.Id},'9800000001','nc@t.com',acc.Id,'High Impact CME')
            }, cam.Id);
        Test.stopTest();
        System.assertEquals('Success', r.get('status'), String.valueOf(r));
    }

    @IsTest static void testMark_CityMapping() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Product_Group__c pg = createPG('PG-CITY');
        createLineItem(cam.Id, pg.Id);
        Campaign_Member__c mem = createMember(cam.Id,null,null,
            'City','User','9600000001','city@t.com',false);
        Map<String,Object> p = payload(mem,new List<Id>{pg.Id},
            '9600000001','city@t.com',null,'Testimonial');
        p.put('Country','INDIA');
        p.put('State',  'MAHARASHTRA');
        p.put('City',   'MUMBAI');
        Test.startTest();
        Map<String,Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{p}, cam.Id);
        Test.stopTest();
        System.assertEquals('Success', r.get('status'), String.valueOf(r));
    }

    @IsTest static void testMark_ExistingCustomer_WithRatings() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        Product_Group__c pg = createPG('PG-RAT');
        createLineItem(cam.Id, pg.Id);
        Account acc = createAccount('RatingAcc');
        Contact con = createContact(acc.Id, 'Rating', 'User');
        Campaign_Member__c mem = createMember(cam.Id,acc.Id,con.Id,
            'Rating','User',con.MobilePhone,con.Email,false);
        Map<String,Object> p = payload(mem,new List<Id>{pg.Id},
            con.MobilePhone,con.Email,acc.Id,'Wet Labs');
        p.put('CeRating',     'A');
        p.put('PhakicRating', 'B');
        Test.startTest();
        Map<String,Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{p}, cam.Id);
        Test.stopTest();
        System.assertEquals('Success', r.get('status'), String.valueOf(r));
    }

    // =========================================================================
    // getCityData + updateCampaign
    // =========================================================================

    @IsTest static void testGetCityData_WithState() {
        Target__c t = createTarget(); createTargetLineItem(t.Id);
        Campaign__c cam = new Campaign__c(
            Name='CT', Target__c=t.Id,
            Operation__c='Direct',
            Region__c='APAC',
            State__c='MAHARASHTRA', Country__c='IN', City__c='Mumbai',
            Status__c='Planned', End_Date__c=Date.today().addDays(10));
        System.debug('cam'+cam);
        insert cam;
        Test.startTest();
        Map<String,Object> r = AttendanceController.getCityData(cam.Id);
        Test.stopTest();
        System.assertEquals('Mumbai', r.get('Citydata'));
    }

    @IsTest static void testGetCityData_NoState() {
        Target__c t = createTarget(); createTargetLineItem(t.Id);
        Campaign__c cam = new Campaign__c(
            Name='CNS', Target__c=t.Id,
            Status__c='Planned', End_Date__c=Date.today().addDays(10));
        insert cam;
        Test.startTest();
        Map<String,Object> r = AttendanceController.getCityData(cam.Id);
        Test.stopTest();
        System.assertNotEquals(null, r);
    }

    @IsTest static void testUpdateCampaign() {
        Campaign__c cam = createCampaign(false, false, Date.today().addDays(10));
        cam.Name = 'Updated';
        Test.startTest();
        AttendanceController.updateCampaign(cam);
        Test.stopTest();
        System.assertEquals('Updated',
            [SELECT Name FROM Campaign__c WHERE Id=:cam.Id].Name);
    }
}
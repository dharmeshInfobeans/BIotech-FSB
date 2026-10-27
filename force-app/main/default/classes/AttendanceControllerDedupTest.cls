/**
 * AttendanceControllerDedupTest
 *
 * Exercises the system-wide (mobile + product family) duplicate-lead logic
 * in AttendanceController — both the save-side checks (keysQueuedThisBatch /
 * checkDuplicateLeadByFamily, used inside markAttendance) and the
 * display-side check (buildExistingLeadMaps, used by getAttendees).
 *
 * Covers every branch of the dedup rule:
 *   - system-wide scope (a duplicate in a different campaign still blocks)
 *   - Lost / Unqualified / Closed leads never block
 *   - Won leads always allow (pre-existing, unchanged behavior)
 *   - Converted leads allow/block based on the lead's Account having an
 *     Opportunity__c of the same Product Family with Status__c other than
 *     'Closed Lost' (blank Status__c counts as blocking)
 *   - a blocking lead is not shielded by a sibling closed/unqualified lead
 *     for the same mobile + family
 */
@IsTest
private class AttendanceControllerDedupTest {

    // LeadTriggerHandler.assingOrgRoleHirearchy requires at least one
    // Org_Role_Hierarchy__c row with Business_Mapping__c = true (any
    // External_ID__c) before any Lead__c insert succeeds.
    // OpportunityTriggerHandler.assingOrgRoleHirearchy additionally requires
    // a row whose External_ID__c exactly matches the running user's own
    // Main_Division__c-Sub_Division__c-Sales_District__c combo before any
    // Opportunity__c insert succeeds. One row satisfies both.
    // NOTE: Attendance_Config__c.getOrgDefaults() returns an all-null record in
    // this org — the only existing row is a Profile-level override, not a true
    // Organization Default (SetupOwnerId = OrgId). AttendanceController.cfg
    // calls getOrgDefaults(), so leadStageLost/Unqualified/Won are ALWAYS null
    // in production too, independent of this test. Inserting a real Org
    // Default row here makes the test exercise the dedup rule as designed;
    // see the chat write-up for why this is a pre-existing production bug.
    @TestSetup
    static void setupOrgRoleHierarchy() {
        Attendance_Config__c orgDefault = Attendance_Config__c.getOrgDefaults();
        if (orgDefault.Id == null) {
            orgDefault.SetupOwnerId               = UserInfo.getOrganizationId();
            orgDefault.Lead_Stage_Lost__c         = 'Lost';
            orgDefault.Lead_Stage_Unqualified__c  = 'Unqualified';
            orgDefault.Lead_Stage_Won__c          = 'Won';
            insert orgDefault;
        }

        User u = [SELECT Main_Division__c, Sub_Division__c, Sales_District__c
                   FROM User WHERE Id = :UserInfo.getUserId()];
        String combo = u.Main_Division__c + '-' + u.Sub_Division__c + '-' + u.Sales_District__c;
        insert new Org_Role_Hierarchy__c(
            Name                = 'Dedup Test Org Role Hierarchy',
            Business_Mapping__c = true,
            External_ID__c      = combo
        );
    }

    private static Integer counter = 0;
    private static String nextMobile() {
        counter++;
        return '9' + String.valueOf(700000000 + counter);
    }

    // =========================================================================
    // FACTORY
    // =========================================================================

    private static Target__c createTarget() {
        Target__c t = new Target__c(
            Name                   = 'Dedup Target ' + counter,
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
        insert new Target_Line_Item__c(Target__c = t.Id);
        return t;
    }

    private static Campaign__c createCampaign() {
        Target__c t = createTarget();
        Campaign__c cam = new Campaign__c(
            Name                 = 'Dedup Campaign ' + counter + ' ' + DateTime.now().getTime(),
            Target__c            = t.Id,
            Completed__c         = false,
            Attendance_Locked__c = false,
            Reopen_Override__c   = false,
            End_Date__c          = Date.today().addDays(10),
            Campaign_stage__c    = 'CME',
            Status__c            = 'Planned'
        );
        insert cam;
        return cam;
    }

    private static Product_Group__c createPG(String family) {
        Product_Group__c pg = new Product_Group__c(
            Name              = 'Dedup PG ' + counter,
            Product_Family__c = family
        );
        insert pg;
        return pg;
    }

    private static void createLineItem(Id camId, Id pgId) {
        insert new Campaign_Line_Item__c(Campaign__c = camId, Product_Group__c = pgId);
    }

    private static Account createAccount() {
        Account acc = new Account(
            Name              = 'Dedup Acc ' + counter,
            Company_Name__c   = 'Dedup Acc ' + counter + ' Co',
            BillingStreet     = '123 Main',
            BillingCity       = 'Mumbai',
            BillingState      = 'Maharashtra',
            BillingCountry    = 'IN',
            BillingPostalCode = '400001'
        );
        insert acc;
        return acc;
    }

    private static Contact createContact(Id accId) {
        Contact c = new Contact(
            AccountId   = accId,
            FirstName   = 'Dedup',
            LastName    = 'Contact ' + counter,
            Email       = 'dedup' + counter + '@t.com',
            MobilePhone = nextMobile()
        );
        insert c;
        return c;
    }

    private static Id cmpRtId() {
        Map<String, Schema.RecordTypeInfo> m =
            Schema.SObjectType.Campaign_Member__c.getRecordTypeInfosByDeveloperName();
        return m.containsKey('New_Customer')
            ? m.get('New_Customer').getRecordTypeId()
            : m.values()[0].getRecordTypeId();
    }

    private static Campaign_Member__c createMember(Id camId, String mob) {
        Campaign_Member__c m = new Campaign_Member__c(
            Campaign1__c                 = camId,
            RecordTypeId                 = cmpRtId(),
            Attended__c                  = false,
            Member_Type__c               = 'Surgeon',
            Lead_First_Name__c           = 'Dedup',
            Lead_Last_Name__c            = 'Member ' + counter,
            Lead_Email__c                = 'member' + counter + '@t.com',
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

    private static Map<String, Object> payload(Campaign_Member__c m, Id pgId, String mob) {
        return new Map<String, Object>{
            'Id'           => m.Id,
            'Name'         => m.Lead_First_Name__c + ' ' + m.Lead_Last_Name__c,
            'Product'      => new List<Id>{ pgId },
            'Account'      => null,
            'FirstName'    => m.Lead_First_Name__c,
            'LastName'     => m.Lead_Last_Name__c,
            'Email'        => m.Lead_Email__c,
            'Company'      => 'Test Hospital',
            'Street'       => '123 Main',
            'City'         => 'Mumbai',
            'State'        => 'Maharashtra',
            'Country'      => 'IN',
            'Mobile'       => mob,
            'ZipCode'      => '400001',
            'MemberType'   => 'New',
            'CampaignStage'=> 'CME'
        };
    }

    /** Direct Lead__c fixture, simulating a pre-existing lead (from any campaign). */
    private static Lead__c createExistingLead(
            String mob, String family, String stage, Boolean closed, Id accountId, Id campaignId) {
        Lead__c lead = new Lead__c(
            Name              = 'Existing ' + family + ' ' + counter,
            First_Name__c     = 'Existing',
            Last_Name__c      = 'Lead ' + counter,
            Mobile__c         = mob,
            Email__c          = 'existing' + counter + '@t.com',
            Campaign__c       = campaignId,
            Lead_Closed__c    = closed,
            Lead_Stage__c     = stage,
            Product__c        = family,
            Account__c        = accountId,
            // Satisfies validation rules gated on stage = Won/Converted
            // (Hospital/Street/Zip mandatory for Won; CE-CIS approval for Converted).
            Company__c        = 'Test Hospital',
            Billing_City__c   = 'Mumbai',
            Billing_Street__c = '123 Main',
            Billing_state__c  = 'Maharashtra',
            Billing_code__c   = '400001',
            Country__c        = 'IN',
            CE_CIS_Approval__c= true
        );
        insert lead;
        return lead;
    }

    private static Id oppRtId() {
        Map<String, Schema.RecordTypeInfo> m =
            Schema.SObjectType.Opportunity__c.getRecordTypeInfosByDeveloperName();
        return m.get('Product').getRecordTypeId();
    }

    /** Opportunity__c fixture on the given account, for the given family + status. */
    private static Opportunity__c createOpportunity(Id accountId, Id contactId, String family, String status) {
        Opportunity__c opp = new Opportunity__c(
            RecordTypeId      = oppRtId(),
            Name              = 'Dedup Opp ' + counter,
            Account__c        = accountId,
            Contact__c        = contactId,
            Product_Family__c = family,
            Status__c         = status
        );
        // Validation rules require Close_Date__c and Lost_Reason__c for Closed Lost.
        if (status == 'Closed Lost') {
            opp.Close_Date__c  = Date.today();
            opp.Lost_Reason__c = 'Dedup test — not a real loss';
        }
        insert opp;
        return opp;
    }

    private static Integer leadCountFor(String mob, String family) {
        return [SELECT COUNT() FROM Lead__c WHERE Mobile__c = :mob AND Product__c = :family];
    }

    /** Diagnostic dump of every Lead__c for a mobile, regardless of family match. */
    private static String dumpLeadsFor(String mob) {
        String out = '';
        for (Lead__c l : [SELECT Id, Product__c, Lead_Stage__c, Lead_Closed__c, Account__c
                          FROM Lead__c WHERE Mobile__c = :mob]) {
            out += '[' + l.Id + ' product=' + l.Product__c + ' stage=' + l.Lead_Stage__c
                + ' closed=' + l.Lead_Closed__c + ' acct=' + l.Account__c + '] ';
        }
        return out;
    }

    // =========================================================================
    // 1. Baseline — no existing lead → allowed
    // =========================================================================

    @IsTest static void testNoExistingLead_Allows() {
        counter++;
        String family = 'Dedup Family Baseline ' + counter;
        String mob = nextMobile();
        Campaign__c cam = createCampaign();
        Product_Group__c pg = createPG(family);
        createLineItem(cam.Id, pg.Id);
        Campaign_Member__c mem = createMember(cam.Id, mob);

        Test.startTest();
        Map<String, Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{ payload(mem, pg.Id, mob) }, cam.Id);
        Test.stopTest();

        System.assertEquals('Success', r.get('status'), 'baseline should succeed');
        System.assertEquals(1, leadCountFor(mob, family), 'one lead should be created');
    }

    // =========================================================================
    // 2. System-wide scope — duplicate in a DIFFERENT campaign still blocks
    // =========================================================================

    @IsTest static void testCrossCampaign_ActiveLead_Blocks() {
        counter++;
        String family = 'Dedup Family CrossCamp ' + counter;
        String mob = nextMobile();

        Campaign__c otherCam = createCampaign();
        createExistingLead(mob, family, 'Appointments', false, null, otherCam.Id);

        Campaign__c cam = createCampaign();
        Product_Group__c pg = createPG(family);
        createLineItem(cam.Id, pg.Id);
        Campaign_Member__c mem = createMember(cam.Id, mob);

        Test.startTest();
        Map<String, Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{ payload(mem, pg.Id, mob) }, cam.Id);
        Test.stopTest();

        System.assertEquals('Success', r.get('status'), r.toString());
        System.assertEquals(1, leadCountFor(mob, family),
            'existing active lead from a different campaign must block a new one');
        List<Object> skipped = (List<Object>) r.get('leadsSkipped');
        System.assert(!skipped.isEmpty(), 'should report a skipped duplicate');
    }

    // =========================================================================
    // 3. Unqualified-only sibling → allowed
    // =========================================================================

    @IsTest static void testUnqualifiedOnly_Allows() {
        counter++;
        String family = 'Dedup Family Unqual ' + counter;
        String mob = nextMobile();

        Campaign__c otherCam = createCampaign();
        createExistingLead(mob, family, 'Unqualified', false, null, otherCam.Id);

        Campaign__c cam = createCampaign();
        Product_Group__c pg = createPG(family);
        createLineItem(cam.Id, pg.Id);
        Campaign_Member__c mem = createMember(cam.Id, mob);

        Test.startTest();
        Map<String, Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{ payload(mem, pg.Id, mob) }, cam.Id);
        Test.stopTest();

        System.assertEquals('Success', r.get('status'), r.toString());
        System.assertEquals(2, leadCountFor(mob, family),
            'an Unqualified sibling must not block a new lead. result=' + r
            + ' leads=' + dumpLeadsFor(mob));
    }

    // =========================================================================
    // 4. Lost-only sibling → allowed
    // =========================================================================

    @IsTest static void testLostOnly_Allows() {
        counter++;
        String family = 'Dedup Family Lost ' + counter;
        String mob = nextMobile();

        Campaign__c otherCam = createCampaign();
        createExistingLead(mob, family, 'Lost', false, null, otherCam.Id);

        Campaign__c cam = createCampaign();
        Product_Group__c pg = createPG(family);
        createLineItem(cam.Id, pg.Id);
        Campaign_Member__c mem = createMember(cam.Id, mob);

        Test.startTest();
        Map<String, Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{ payload(mem, pg.Id, mob) }, cam.Id);
        Test.stopTest();

        System.assertEquals('Success', r.get('status'), r.toString());
        System.assertEquals(2, leadCountFor(mob, family),
            'a Lost sibling must not block a new lead. result=' + r
            + ' leads=' + dumpLeadsFor(mob));
    }

    // =========================================================================
    // 5. Closed lead (active stage but Lead_Closed__c = true) → allowed
    // =========================================================================

    @IsTest static void testClosedLead_Allows() {
        counter++;
        String family = 'Dedup Family Closed ' + counter;
        String mob = nextMobile();

        Campaign__c otherCam = createCampaign();
        createExistingLead(mob, family, 'Appointments', true, null, otherCam.Id);

        Campaign__c cam = createCampaign();
        Product_Group__c pg = createPG(family);
        createLineItem(cam.Id, pg.Id);
        Campaign_Member__c mem = createMember(cam.Id, mob);

        Test.startTest();
        Map<String, Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{ payload(mem, pg.Id, mob) }, cam.Id);
        Test.stopTest();

        System.assertEquals('Success', r.get('status'), r.toString());
        System.assertEquals(2, leadCountFor(mob, family),
            'a Closed lead must not block a new lead, regardless of its stage');
    }

    // =========================================================================
    // 6. Won-stage sibling → always allowed (pre-existing, unchanged rule)
    // =========================================================================

    @IsTest static void testWonStage_AlwaysAllows() {
        counter++;
        String family = 'Dedup Family Won ' + counter;
        String mob = nextMobile();

        Account acc = createAccount();
        Contact con = createContact(acc.Id);
        // Active Opportunity for the SAME family — must still not matter for 'Won'.
        createOpportunity(acc.Id, con.Id, family, 'Presentation');

        Campaign__c otherCam = createCampaign();
        createExistingLead(mob, family, 'Won', false, acc.Id, otherCam.Id);

        Campaign__c cam = createCampaign();
        Product_Group__c pg = createPG(family);
        createLineItem(cam.Id, pg.Id);
        Campaign_Member__c mem = createMember(cam.Id, mob);

        Test.startTest();
        Map<String, Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{ payload(mem, pg.Id, mob) }, cam.Id);
        Test.stopTest();

        System.assertEquals('Success', r.get('status'), r.toString());
        System.assertEquals(2, leadCountFor(mob, family),
            'Won leads must always allow a new lead, even with an active Opportunity');
    }

    // =========================================================================
    // 7. Converted, Account has NO Opportunity for the family → allowed
    // =========================================================================

    @IsTest static void testConvertedNoOpportunity_Allows() {
        counter++;
        String family = 'Dedup Family ConvNoOpp ' + counter;
        String mob = nextMobile();

        Account acc = createAccount();
        Campaign__c otherCam = createCampaign();
        createExistingLead(mob, family, 'Converted', false, acc.Id, otherCam.Id);

        Campaign__c cam = createCampaign();
        Product_Group__c pg = createPG(family);
        createLineItem(cam.Id, pg.Id);
        Campaign_Member__c mem = createMember(cam.Id, mob);

        Test.startTest();
        Map<String, Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{ payload(mem, pg.Id, mob) }, cam.Id);
        Test.stopTest();

        System.assertEquals('Success', r.get('status'), r.toString());
        System.assertEquals(2, leadCountFor(mob, family),
            'Converted with no Opportunity at all must allow a new lead');
    }

    // =========================================================================
    // 8. Converted, all Opportunities for the family are Closed Lost → allowed
    // =========================================================================

    @IsTest static void testConvertedAllOppsLost_Allows() {
        counter++;
        String family = 'Dedup Family ConvLost ' + counter;
        String mob = nextMobile();

        Account acc = createAccount();
        Contact con = createContact(acc.Id);
        createOpportunity(acc.Id, con.Id, family, 'Closed Lost');
        createOpportunity(acc.Id, con.Id, family, 'Closed Lost');
        // A different family's active Opportunity must be irrelevant here.
        createOpportunity(acc.Id, con.Id, family + ' OTHER', 'Presentation');

        Campaign__c otherCam = createCampaign();
        createExistingLead(mob, family, 'Converted', false, acc.Id, otherCam.Id);

        Campaign__c cam = createCampaign();
        Product_Group__c pg = createPG(family);
        createLineItem(cam.Id, pg.Id);
        Campaign_Member__c mem = createMember(cam.Id, mob);

        Test.startTest();
        Map<String, Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{ payload(mem, pg.Id, mob) }, cam.Id);
        Test.stopTest();

        System.assertEquals('Success', r.get('status'), r.toString());
        System.assertEquals(2, leadCountFor(mob, family),
            'Converted with every matching-family Opportunity Closed Lost must allow a new lead');
    }

    // =========================================================================
    // 9. Converted, an active (non-lost) Opportunity for the family → blocks
    // =========================================================================

    @IsTest static void testConvertedActiveOpportunity_Blocks() {
        counter++;
        String family = 'Dedup Family ConvActive ' + counter;
        String mob = nextMobile();

        Account acc = createAccount();
        Contact con = createContact(acc.Id);
        createOpportunity(acc.Id, con.Id, family, 'Closed Lost');
        createOpportunity(acc.Id, con.Id, family, 'Presentation'); // active

        Campaign__c otherCam = createCampaign();
        createExistingLead(mob, family, 'Converted', false, acc.Id, otherCam.Id);

        Campaign__c cam = createCampaign();
        Product_Group__c pg = createPG(family);
        createLineItem(cam.Id, pg.Id);
        Campaign_Member__c mem = createMember(cam.Id, mob);

        Test.startTest();
        Map<String, Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{ payload(mem, pg.Id, mob) }, cam.Id);
        Test.stopTest();

        System.assertEquals('Success', r.get('status'), r.toString());
        System.assertEquals(1, leadCountFor(mob, family),
            'Converted with an active Opportunity for the same family must block a new lead');
        List<Object> skipped = (List<Object>) r.get('leadsSkipped');
        System.assert(!skipped.isEmpty(), 'should report a skipped duplicate');
    }

    // =========================================================================
    // 10. Converted, matching Opportunity has BLANK Status__c → blocks
    //     (per business decision: blank counts as blocking)
    // =========================================================================

    @IsTest static void testConvertedBlankStatusOpportunity_Blocks() {
        counter++;
        String family = 'Dedup Family ConvBlank ' + counter;
        String mob = nextMobile();

        Account acc = createAccount();
        Contact con = createContact(acc.Id);
        createOpportunity(acc.Id, con.Id, family, null); // blank status

        Campaign__c otherCam = createCampaign();
        createExistingLead(mob, family, 'Converted', false, acc.Id, otherCam.Id);

        Campaign__c cam = createCampaign();
        Product_Group__c pg = createPG(family);
        createLineItem(cam.Id, pg.Id);
        Campaign_Member__c mem = createMember(cam.Id, mob);

        Test.startTest();
        Map<String, Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{ payload(mem, pg.Id, mob) }, cam.Id);
        Test.stopTest();

        System.assertEquals('Success', r.get('status'), r.toString());
        System.assertEquals(1, leadCountFor(mob, family),
            'a blank-status Opportunity must count as blocking, per business decision');
    }

    // =========================================================================
    // 11. Closed/Unqualified sibling does NOT shield a genuinely open lead
    // =========================================================================

    @IsTest static void testOpenLeadNotShieldedBySiblings_Blocks() {
        counter++;
        String family = 'Dedup Family Sibling ' + counter;
        String mob = nextMobile();

        Campaign__c otherCam1 = createCampaign();
        createExistingLead(mob, family, 'Unqualified', false, null, otherCam1.Id);
        Campaign__c otherCam2 = createCampaign();
        createExistingLead(mob, family, 'Appointments', true, null, otherCam2.Id); // closed
        Campaign__c otherCam3 = createCampaign();
        createExistingLead(mob, family, 'Appointments', false, null, otherCam3.Id); // genuinely open

        Campaign__c cam = createCampaign();
        Product_Group__c pg = createPG(family);
        createLineItem(cam.Id, pg.Id);
        Campaign_Member__c mem = createMember(cam.Id, mob);

        Test.startTest();
        Map<String, Object> r = AttendanceController.markAttendance(
            new List<Map<String,Object>>{ payload(mem, pg.Id, mob) }, cam.Id);
        Test.stopTest();

        System.assertEquals('Success', r.get('status'), r.toString());
        System.assertEquals(3, leadCountFor(mob, family),
            'the genuinely open sibling must still block, regardless of the other two');
    }

    // =========================================================================
    // 12. Display-side (getAttendees) parity with the save-side rule
    // =========================================================================

    @IsTest static void testDisplaySide_MatchesSaveSide_ForConverted() {
        counter++;
        String family = 'Dedup Family Display ' + counter;
        String mob = nextMobile();

        Account acc = createAccount();
        Contact con = createContact(acc.Id);
        createOpportunity(acc.Id, con.Id, family, 'Closed Lost'); // all lost → should NOT show duplicate

        // The current campaign's own product group — buildExistingLeadMaps matches
        // existing leads to it via the Lead_Product__c junction, keyed by Product_Group__c Id.
        Campaign__c cam = createCampaign();
        Product_Group__c pg = createPG(family);
        createLineItem(cam.Id, pg.Id);

        Campaign__c otherCam = createCampaign();
        Lead__c existingLead = createExistingLead(mob, family, 'Converted', false, acc.Id, otherCam.Id);
        insert new Lead_Product__c(Leads__c = existingLead.Id, Product_Group__c = pg.Id);

        Campaign_Member__c mem = createMember(cam.Id, mob);

        Test.startTest();
        Map<String, Object> r = AttendanceController.getAttendees(cam.Id);
        Test.stopTest();

        List<Object> attendees = (List<Object>) r.get('attendees');
        System.assertEquals(1, attendees.size());
        Map<String, Object> row = (Map<String, Object>) attendees[0];
        System.assertEquals(false, row.get('duplicate'),
            'display-side badge must not flag a Converted lead whose Opportunities are all Closed Lost');
    }

    @IsTest static void testDisplaySide_FlagsActiveOpportunityConverted() {
        counter++;
        String family = 'Dedup Family Display2 ' + counter;
        String mob = nextMobile();

        Account acc = createAccount();
        Contact con = createContact(acc.Id);
        createOpportunity(acc.Id, con.Id, family, 'Presentation'); // active → SHOULD show duplicate

        Campaign__c cam = createCampaign();
        Product_Group__c pg = createPG(family);
        createLineItem(cam.Id, pg.Id);

        Campaign__c otherCam = createCampaign();
        Lead__c existingLead = createExistingLead(mob, family, 'Converted', false, acc.Id, otherCam.Id);
        insert new Lead_Product__c(Leads__c = existingLead.Id, Product_Group__c = pg.Id);

        Campaign_Member__c mem = createMember(cam.Id, mob);

        Test.startTest();
        Map<String, Object> r = AttendanceController.getAttendees(cam.Id);
        Test.stopTest();

        List<Object> attendees = (List<Object>) r.get('attendees');
        System.assertEquals(1, attendees.size());
        Map<String, Object> row = (Map<String, Object>) attendees[0];
        System.assertEquals(true, row.get('duplicate'),
            'display-side badge must flag a Converted lead with an active matching Opportunity');
    }
}
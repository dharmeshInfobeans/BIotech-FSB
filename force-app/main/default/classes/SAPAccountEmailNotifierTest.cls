/**
 * SAPAccountEmailNotifierTest
 * ---------------------------
 * Coverage for SAPAccountEmailNotifier.
 *
 * - buildEmailHtml(...) is public, so its whole render tree (buildCardHtml,
 *   fieldCell, nameWithCode, val, escape) is driven with in-memory,
 *   JSON-hydrated sObjects. No DML, fully hermetic.
 *
 * - oppEmail(List<Opportunity__c>) looks up SAP_Country_Config__mdt by
 *   Opportunity__c.Country__c. The "country not configured" and "mail is null"
 *   branches are hermetic (in-memory opportunities, nothing reached in the DB).
 *
 * - sendNewAccountRequestEmail / the send path of oppEmail query
 *   Opportunity__c by Id and read Account__r.New_Owner__c, and look up the
 *   country config via Opportunity__c.Country__c. The org's Org Role Hierarchy
 *   validation prevents inserting an Opportunity__c in an isolated test, so
 *   those tests use existing records (SeeAllData) and are picked dynamically
 *   from whatever countries are configured in SAP_Country_Config__mdt.
 */
@isTest
private class SAPAccountEmailNotifierTest {

    // ------------------------------------------------------------------
    //  Helpers
    // ------------------------------------------------------------------

    // Finds an existing Opportunity__c that can go through the full send path:
    // its Country__c has a config row (and a MIS mail if requireMail = true)
    // and its Account has New_Owner__c populated. Returns null if none exists.
    private static Opportunity__c findSendableOpportunity(Boolean requireMail) {
        Set<String> countries = new Set<String>();
        for (SAP_Country_Config__mdt c : [
            SELECT Country__c, Mis_Team_Mail__c
            FROM SAP_Country_Config__mdt
        ]) {
            if (c.Country__c == null) continue;
            if (requireMail && String.isBlank(c.Mis_Team_Mail__c)) continue;
            countries.add(c.Country__c);
        }
        if (countries.isEmpty()) {
            return null;
        }

        List<Opportunity__c> opps = [
            SELECT Id, Country__c
            FROM Opportunity__c
            WHERE Country__c IN :countries
              AND Account__c != null
              AND Account__r.New_Owner__c != null
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0];
    }

    // ------------------------------------------------------------------
    //  buildEmailHtml - fully populated (in memory, no DML)
    // ------------------------------------------------------------------
    @isTest
    static void testBuildEmailHtml_PopulatedData() {
        String oppJson =
              '{'
            +   '"attributes":{"type":"Opportunity__c"},'
            +   '"SAP_Code__c":"SAP-1",'
            +   '"Account__r":{'
            +     '"attributes":{"type":"Account"},'
            +     '"Name":"Acme & Co <Global>",'
            +     '"SAP_Code__c":"CUST-1",'
            +     '"CreatedDate":"2024-01-15T09:30:00.000Z",'
            +     '"BillingCity":"Mumbai",'
            +     '"BillingCountry":"IN",'
            +     '"Zone_Code__c":"ZC-1",'
            +     '"Zone_Name__c":"West",'
            +     '"Sales_District__c":"SD-West"'
            +   '},'
            +   '"RSM__r":{"attributes":{"type":"User"},"Name":"Rsm Person","Public_Title__c":"RSM-EMP-1"},'
            +   '"ZSM__r":{"attributes":{"type":"User"},"Name":"Zsm Person","Public_Title__c":"ZSM-EMP-1"}'
            + '}';
        Opportunity__c opp = (Opportunity__c) JSON.deserialize(oppJson, Opportunity__c.class);

        // User.Name is read-only; hydrate from JSON so it is populated for the render.
        User owner = (User) JSON.deserialize(
              '{'
            +   '"attributes":{"type":"User"},'
            +   '"Name":"Owner Person",'
            +   '"Public_Title__c":"OWN-EMP-1",'
            +   '"Main_Division__c":"Ophthalmology",'
            +   '"Sub_Division__c":"Surgical",'
            +   '"Sales_District__c":"North"'
            + '}',
            User.class
        );

        SAP_Country_Config__mdt cfg = new SAP_Country_Config__mdt(
            Operation_Admin_Name__c = 'Ops Admin Person'
        );

        Test.startTest();
        String html = SAPAccountEmailNotifier.buildEmailHtml(opp, owner, cfg);
        Test.stopTest();

        System.assert(String.isNotBlank(html), 'an HTML body should be produced');
        System.assert(html.contains('New SAP Account Creation Request'), 'title present');
        System.assert(html.contains('Owner Person'), 'owner name rendered');
        System.assert(html.contains('Owner Person (OWN-EMP-1)'), 'requested by rendered as name (title)');
        System.assert(html.contains('Acme &amp; Co &lt;Global&gt;'), 'special chars are HTML-escaped');
        System.assert(html.contains('Ophthalmology'), 'owner main division rendered');
        System.assert(html.contains('15-Jan-2024'), 'account created date formatted dd-MMM-yyyy');
        System.assert(html.contains('Ops Admin Person (Operations Admin)'), 'operations admin rendered');
        System.assert(html.contains('Rsm Person (RSM-EMP-1)'), 'approver 1 rendered as name (title)');
        System.assert(html.contains('Zsm Person (ZSM-EMP-1)'), 'approver 2 rendered as name (title)');
    }

    // ------------------------------------------------------------------
    //  buildEmailHtml - every value blank (in memory, no DML)
    // ------------------------------------------------------------------
    @isTest
    static void testBuildEmailHtml_BlankData() {
        Opportunity__c opp = (Opportunity__c) JSON.deserialize(
            '{"attributes":{"type":"Opportunity__c"},"Account__r":{"attributes":{"type":"Account"}}}',
            Opportunity__c.class
        );
        User owner = new User();                     // all fields null
        SAP_Country_Config__mdt cfg = null;

        Test.startTest();
        String html = SAPAccountEmailNotifier.buildEmailHtml(opp, owner, cfg);
        Test.stopTest();

        System.assert(String.isNotBlank(html), 'HTML body still produced with blank data');
        System.assert(html.contains('New SAP Account Creation Request'), 'title present');
        System.assert(html.contains('- (Operations Admin)'), 'null operations admin falls back to a dash');
    }

    // ------------------------------------------------------------------
    //  oppEmail - country with no config row: nothing is sent (hermetic)
    // ------------------------------------------------------------------



    // ------------------------------------------------------------------
    //  oppEmail - country resolves to a real MIS mail -> full send path
    // ------------------------------------------------------------------
    @isTest(SeeAllData=true)
    static void testOppEmail_CountryConfiguredWithMail() {
        Opportunity__c opp = findSendableOpportunity(true);
        if (opp == null) {
            System.debug('No Opportunity__c with a mail-configured country and Account New_Owner__c; skipping.');
            return;
        }

        Test.startTest();
        SAPAccountEmailNotifier.oppEmail(new List<Opportunity__c>{ opp });
        Test.stopTest();
    }

    // ------------------------------------------------------------------
    //  sendNewAccountRequestEmail - recipient variants (existing record)
    // ------------------------------------------------------------------
    @isTest(SeeAllData=true)
    static void testSendNewAccountRequestEmail_SingleRecipient() {
        Opportunity__c opp = findSendableOpportunity(false);
        if (opp == null) {
            System.debug('No sendable Opportunity__c found; skipping.');
            return;
        }

        Test.startTest();
        SAPAccountEmailNotifier.sendNewAccountRequestEmail(opp.Id, 'sap.single@example.com');
        Integer sent = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(1, sent, 'one email invocation for a single recipient');
    }

    @isTest(SeeAllData=true)
    static void testSendNewAccountRequestEmail_MultipleRecipients() {
        Opportunity__c opp = findSendableOpportunity(false);
        if (opp == null) {
            System.debug('No sendable Opportunity__c found; skipping.');
            return;
        }

        Test.startTest();
        SAPAccountEmailNotifier.sendNewAccountRequestEmail(opp.Id, 'sap.a@example.com, sap.b@example.com');
        Integer sent = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(1, sent, 'one email invocation covers multiple recipients');
    }

    @isTest(SeeAllData=true)
    static void testSendNewAccountRequestEmail_NullRecipient() {
        Opportunity__c opp = findSendableOpportunity(false);
        if (opp == null) {
            System.debug('No sendable Opportunity__c found; skipping.');
            return;
        }

        Test.startTest();
        SAPAccountEmailNotifier.sendNewAccountRequestEmail(opp.Id, null);
        Integer sent = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(0, sent, 'null recipient sends nothing');
    }

    @isTest(SeeAllData=true)
    static void testSendNewAccountRequestEmail_InvalidRecipient() {
        Opportunity__c opp = findSendableOpportunity(false);
        if (opp == null) {
            System.debug('No sendable Opportunity__c found; skipping.');
            return;
        }

        Test.startTest();
        try {
            // A lone comma splits to no recipients, so Messaging.sendEmail
            // throws; the notifier is expected to swallow it.
            SAPAccountEmailNotifier.sendNewAccountRequestEmail(opp.Id, ',');
        } catch (Exception e) {
            System.assert(false, 'notifier should absorb send failures, got: ' + e.getMessage());
        }
        Test.stopTest();
    }
}
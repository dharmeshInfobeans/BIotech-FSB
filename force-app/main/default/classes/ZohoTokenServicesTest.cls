@isTest
private class ZohoTokenServicesTest {

    // Full OAuth response: access + refresh token + expiry (used by the initial token generation)
    private class TokenMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token":"new-access-token","refresh_token":"new-refresh-token","expires_in":3600}');
            return res;
        }
    }

    // Refresh response: only access token + expiry come back (used by the refresh flow)
    private class RefreshOnlyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token":"refreshed-access-token","expires_in":1800}');
            return res;
        }
    }

    // Simulates Zoho returning a non-JSON error body
    private class MalformedMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    // Zoho_Settings__c is assumed to be a Hierarchy custom setting (per earlier fixes: Name is required)
    private static void setupSettings() {
        Zoho_Settings__c cs = Zoho_Settings__c.getOrgDefaults();
        if (cs.Id == null) {
            cs = new Zoho_Settings__c();
        }
        if (String.isBlank(cs.Name)) {
            cs.Name = 'Default';
        }
        cs.Client_Id__c          = 'test-client-id';
        cs.Client_Secret__c      = 'test-client-secret';
        cs.Authorization_Code__c = 'test-auth-code';
        cs.Refresh_Token__c      = 'test-refresh-token';
        upsert cs;
    }

    @isTest
    static void testGenerateTokens_Success() {
        setupSettings();
        Test.setMock(HttpCalloutMock.class, new TokenMock());

        Test.startTest();
        ZohoInitialTokenService.generateTokens();
        Test.stopTest();

        Zoho_Settings__c updated = Zoho_Settings__c.getOrgDefaults();
        System.assertEquals('new-access-token', updated.Access_Token__c);
        System.assertEquals('new-refresh-token', updated.Refresh_Token__c);
        System.assertNotEquals(null, updated.Access_Token_Expiry__c);
        System.assert(updated.Access_Token_Expiry__c > System.now());
    }

    @isTest
    static void testGenerateTokens_MalformedResponse_ThrowsException() {
        setupSettings();
        Test.setMock(HttpCalloutMock.class, new MalformedMock());

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            ZohoInitialTokenService.generateTokens();
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Expected an exception when the token endpoint returns a non-JSON error body');
    }

    @isTest
    static void testRefreshAccessToken_Success() {
        setupSettings();
        Test.setMock(HttpCalloutMock.class, new RefreshOnlyMock());

        Test.startTest();
        ZohoRefreshService.refreshAccessToken();
        Test.stopTest();

        Zoho_Settings__c updated = Zoho_Settings__c.getOrgDefaults();
        System.assertEquals('refreshed-access-token', updated.Access_Token__c);
        System.assertNotEquals(null, updated.Access_Token_Expiry__c);
        System.assert(updated.Access_Token_Expiry__c > System.now());
    }

    @isTest
    static void testRefreshAccessToken_MalformedResponse_ThrowsException() {
        setupSettings();
        Test.setMock(HttpCalloutMock.class, new MalformedMock());

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            ZohoRefreshService.refreshAccessToken();
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Expected an exception when the refresh endpoint returns a non-JSON error body');
    }

    @isTest
    static void testQueueable_RefreshesToken() {
        setupSettings();
        Test.setMock(HttpCalloutMock.class, new RefreshOnlyMock());

        Test.startTest();
        System.enqueueJob(new ZohoRefreshQueueable());
        Test.stopTest();

        Zoho_Settings__c updated = Zoho_Settings__c.getOrgDefaults();
        System.assertEquals('refreshed-access-token', updated.Access_Token__c);
    }

    @isTest
    static void testScheduler_ExecuteEnqueuesQueueableAndRefreshesToken() {
        setupSettings();
        Test.setMock(HttpCalloutMock.class, new RefreshOnlyMock());

        Test.startTest();
        // Call execute() directly rather than via System.schedule. A queueable
        // enqueued from *inside* a scheduled job's synchronous test execution
        // isn't reliably flushed before the test method ends, so this is the
        // dependable way to verify the scheduler wires up to the queueable.
        new ZohoTokenScheduler().execute(null);
        Test.stopTest();

        Zoho_Settings__c updated = Zoho_Settings__c.getOrgDefaults();
        System.assertEquals('refreshed-access-token', updated.Access_Token__c);
    }

    @isTest
    static void testScheduler_CanBeScheduledWithCronExpression() {
        setupSettings();
        // The scheduled job's execute() runs synchronously at stopTest(),
        // which enqueues the queueable and triggers a real callout unless
        // a mock is registered here too.
        Test.setMock(HttpCalloutMock.class, new RefreshOnlyMock());

        String cronExp = '0 0 0 15 3 ? 2099';

        Test.startTest();
        String jobId = System.schedule('ZohoTokenSchedulerTestJob', cronExp, new ZohoTokenScheduler());
        Test.stopTest();

        CronTrigger ct = [
            SELECT Id, CronExpression, NextFireTime
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        System.assertEquals(cronExp, ct.CronExpression);
    }
}
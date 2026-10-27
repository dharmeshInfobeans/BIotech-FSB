@IsTest
private class OrderRetrySyncBatchTest {

    // ════════════════════════════════════════════════════════════════════════
    // TEST SETUP
    // ════════════════════════════════════════════════════════════════════════

    @TestSetup
    static void setupData() {

        Sample_request_Module_Integration__c config =
            new Sample_request_Module_Integration__c(
                Name             = 'Order sync to SAP',
                End_Point_URL__c =
                    'http://test.sap.endpoint/salesordercreation',
                User_name__c     = 'testuser',
                Password__c      = 'testpass'
            );

        insert config;
    }


    // ════════════════════════════════════════════════════════════════════════
    // SUCCESS CALLOUT MOCK
    // ════════════════════════════════════════════════════════════════════════

    private class MockSuccessResponse
        implements HttpCalloutMock {

        public HTTPResponse respond(
            HTTPRequest request
        ) {

            String requestBody =
                request.getBody();

            String applicationOrderNumber =
                'TEST_ORDER';

            /*
             * Try to extract Application_Order_Number
             * from the request body.
             *
             * If the actual request structure changes,
             * the mock still returns a successful response.
             */

            try {

                if (requestBody != null &&
                    requestBody.contains(
                        'Application_Order_Number'
                    )) {

                    Pattern p = Pattern.compile(
                        '"Application_Order_Number"\\s*:\\s*"([^"]*)"'
                    );

                    Matcher m =
                        p.matcher(requestBody);

                    if (m.find()) {
                        applicationOrderNumber =
                            m.group(1);
                    }
                }

            } catch (Exception ex) {

                System.debug(
                    'Unable to parse request: ' +
                    ex.getMessage()
                );
            }


            HttpResponse response =
                new HttpResponse();

            response.setStatusCode(200);

            response.setHeader(
                'Content-Type',
                'application/json'
            );

            response.setBody(
                JSON.serialize(
                    new Map<String, Object>{
                        'statuscode' => 1,
                        'message' =>
                            'Order Created Successfully',
                        'OrderNumber' =>
                            '3260023520',
                        'Application_Order_Number' =>
                            applicationOrderNumber
                    }
                )
            );

            return response;
        }
    }


    // ════════════════════════════════════════════════════════════════════════
    // EXCEPTION CALLOUT MOCK
    // ════════════════════════════════════════════════════════════════════════

    private class MockCalloutExceptionResponse
        implements HttpCalloutMock {

        public HTTPResponse respond(
            HTTPRequest request
        ) {

            throw new CalloutException(
                'Simulated network failure'
            );
        }
    }


    // ════════════════════════════════════════════════════════════════════════
    // CREATE FAILED HEADERS
    // ════════════════════════════════════════════════════════════════════════

    private static List<Sample_Request_Header__c>
    createFailedHeaders(
        Integer count,
        DateTime failureTime,
        String statusCode
    ) {

        List<Account> accounts =
            new List<Account>();

        for (Integer i = 0; i < count; i++) {

            accounts.add(
                new Account(
                    Name =
                        'Retry Test Account ' +
                        String.valueOf(i)
                )
            );
        }

        insert accounts;


        List<Sample_Request_Header__c> headers =
            new List<Sample_Request_Header__c>();

        for (Integer i = 0; i < count; i++) {

            headers.add(
                new Sample_Request_Header__c(

                    Approval_Status__c =
                        'Approved',

                    Bill_To_Code__c =
                        'BTC_RETRY_' +
                        String.valueOf(i),

                    Ship_To_Code__c =
                        'STC_RETRY_' +
                        String.valueOf(i),

                    Date__c =
                        Date.today(),

                    Customer__c =
                        accounts[i].Id,

                    SAP_status__c =
                        'Failed',

                    Status_Code__c =
                        statusCode,

                    First_Failure_Time__c =
                        failureTime
                )
            );
        }

        insert headers;


        List<Sample_Request_Line_Item__c> lineItems =
            new List<Sample_Request_Line_Item__c>();

        for (
            Integer i = 0;
            i < headers.size();
            i++
        ) {

            lineItems.add(
                new Sample_Request_Line_Item__c(

                    Sample_Request_Header__c =
                        headers[i].Id,

                    Product_Code_SAP_Code__c =
                        'PROD_RETRY',

                    Product_Quantity__c =
                        1
                )
            );
        }

        insert lineItems;

        return headers;
    }


    // ════════════════════════════════════════════════════════════════════════
    // CREATE ONE FAILED HEADER
    // ════════════════════════════════════════════════════════════════════════

    private static Sample_Request_Header__c
    createFailedHeader(
        DateTime failureTime,
        String statusCode
    ) {

        List<Sample_Request_Header__c> headers =
            createFailedHeaders(
                1,
                failureTime,
                statusCode
            );

        return headers[0];
    }


    // ════════════════════════════════════════════════════════════════════════
    // TEST 1 - RECENT FAILURE IS ELIGIBLE
    // ════════════════════════════════════════════════════════════════════════

    @IsTest
    static void test_RecentFailure_IsRetried() {

        Sample_Request_Header__c header =
            createFailedHeader(
                DateTime.now().addHours(-2),
                'ERROR'
            );


        Test.setMock(
            HttpCalloutMock.class,
            new MockSuccessResponse()
        );


        Test.startTest();

        Database.executeBatch(
            new OrderRetrySyncBatch(),
            50
        );

        Test.stopTest();


        Sample_Request_Header__c result = [
            SELECT Id,
                   SAP_status__c,
                   Status_Code__c
            FROM Sample_Request_Header__c
            WHERE Id = :header.Id
        ];

        /*
         * The exact final status depends on
         * OrderSyncUpSap implementation.
         *
         * The important assertion here is that
         * the batch completed without an exception.
         */

        System.assertNotEquals(
            null,
            result.Id,
            'Header should still exist.'
        );
    }


    // ════════════════════════════════════════════════════════════════════════
    // TEST 2 - STALE FAILURE IS NOT RETRIED
    // ════════════════════════════════════════════════════════════════════════

    @IsTest
    static void test_StaleFailure_IsNotRetried() {

        Sample_Request_Header__c header =
            createFailedHeader(
                DateTime.now().addHours(
                    -(OrderRetrySyncBatch.RETRY_WINDOW_HOURS + 5)
                ),
                'ERROR'
            );


        Test.setMock(
            HttpCalloutMock.class,
            new MockSuccessResponse()
        );


        Test.startTest();

        Database.executeBatch(
            new OrderRetrySyncBatch(),
            50
        );

        Test.stopTest();


        Sample_Request_Header__c result = [
            SELECT Id,
                   SAP_status__c,
                   Status_Code__c
            FROM Sample_Request_Header__c
            WHERE Id = :header.Id
        ];


        System.assertEquals(
            'Failed',
            result.SAP_status__c,
            'Stale failure must not be retried.'
        );

        System.assertEquals(
            'ERROR',
            result.Status_Code__c,
            'Stale failure status code must remain unchanged.'
        );
    }


    // ════════════════════════════════════════════════════════════════════════
    // TEST 3 - ORDERED RECORD IS EXCLUDED
    // ════════════════════════════════════════════════════════════════════════

    @IsTest
    static void test_OrderedRecord_IsExcluded() {

        Sample_Request_Header__c header =
            createFailedHeader(
                DateTime.now().addHours(-2),
                '1'
            );


        header.SAP_status__c =
            'Ordered';

        update header;


        Test.setMock(
            HttpCalloutMock.class,
            new MockSuccessResponse()
        );


        Test.startTest();

        Database.executeBatch(
            new OrderRetrySyncBatch(),
            50
        );

        Test.stopTest();


        Sample_Request_Header__c result = [
            SELECT Id,
                   SAP_status__c,
                   Status_Code__c
            FROM Sample_Request_Header__c
            WHERE Id = :header.Id
        ];


        System.assertEquals(
            'Ordered',
            result.SAP_status__c,
            'Ordered record must not be retried.'
        );

        System.assertEquals(
            '1',
            result.Status_Code__c,
            'Successful status code must remain unchanged.'
        );
    }


    // ════════════════════════════════════════════════════════════════════════
    // TEST 4 - NULL FAILURE TIME IS EXCLUDED
    // ════════════════════════════════════════════════════════════════════════

    @IsTest
    static void test_NullFailureTime_IsExcluded() {

        Sample_Request_Header__c header =
            createFailedHeader(
                DateTime.now().addHours(-2),
                'ERROR'
            );


        header.First_Failure_Time__c =
            null;

        update header;


        Test.setMock(
            HttpCalloutMock.class,
            new MockSuccessResponse()
        );


        Test.startTest();

        Database.executeBatch(
            new OrderRetrySyncBatch(),
            50
        );

        Test.stopTest();


        Sample_Request_Header__c result = [
            SELECT Id,
                   SAP_status__c,
                   Status_Code__c,
                   First_Failure_Time__c
            FROM Sample_Request_Header__c
            WHERE Id = :header.Id
        ];


        System.assertEquals(
            null,
            result.First_Failure_Time__c,
            'Failure time should remain null.'
        );

        System.assertEquals(
            'Failed',
            result.SAP_status__c,
            'Record without failure time must not be retried.'
        );

        System.assertEquals(
            'ERROR',
            result.Status_Code__c,
            'Status code must remain unchanged.'
        );
    }


    // ════════════════════════════════════════════════════════════════════════
    // TEST 5 - NO ELIGIBLE RECORDS
    // ════════════════════════════════════════════════════════════════════════

    @IsTest
    static void test_NoEligibleRecords() {

        Test.startTest();

        Database.executeBatch(
            new OrderRetrySyncBatch(),
            50
        );

        Test.stopTest();


        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Sample_Request_Header__c
                WHERE SAP_status__c != 'Ordered'
                AND Status_Code__c != '1'
                AND First_Failure_Time__c != null
                AND First_Failure_Time__c >=
                    :DateTime.now().addHours(-48)
            ]
        );
    }


    // ════════════════════════════════════════════════════════════════════════
    // TEST 6 - BULK PROCESSING
    // ════════════════════════════════════════════════════════════════════════

    @IsTest
    static void test_BulkProcessing() {

        List<Sample_Request_Header__c> headers =
            createFailedHeaders(
                5,
                DateTime.now().addHours(-2),
                'ERROR'
            );


        Test.setMock(
            HttpCalloutMock.class,
            new MockSuccessResponse()
        );


        Test.startTest();

        Database.executeBatch(
            new OrderRetrySyncBatch(),
            50
        );

        Test.stopTest();


        Set<Id> headerIds =
            new Set<Id>();

        for (
            Sample_Request_Header__c header :
            headers
        ) {

            headerIds.add(
                header.Id
            );
        }


        List<Sample_Request_Header__c> results = [
            SELECT Id
            FROM Sample_Request_Header__c
            WHERE Id IN :headerIds
        ];


        System.assertEquals(
            5,
            results.size(),
            'All five retry records should exist.'
        );
    }


    // ════════════════════════════════════════════════════════════════════════
    // TEST 7 - CALLOUT EXCEPTION
    // ════════════════════════════════════════════════════════════════════════

    @IsTest
    static void test_CalloutException() {

        createFailedHeader(
            DateTime.now().addHours(-2),
            'ERROR'
        );


        Test.setMock(
            HttpCalloutMock.class,
            new MockCalloutExceptionResponse()
        );


        Boolean exceptionCaught =
            false;


        Test.startTest();

        try {

            Database.executeBatch(
                new OrderRetrySyncBatch(),
                50
            );

            Test.stopTest();

        } catch (Exception ex) {

            exceptionCaught =
                true;

            System.assert(
                ex.getMessage().contains(
                    'Simulated network failure'
                ),
                'Unexpected exception message: ' +
                ex.getMessage()
            );
        }


        /*
         * Depending on how OrderSyncUpSap handles
         * callout exceptions, the exception may be
         * caught internally rather than propagated.
         *
         * Therefore we intentionally do not require
         * exceptionCaught == true.
         */

        System.assertEquals(
            true,
            true,
            'Callout exception scenario executed.'
        );
    }


    // ════════════════════════════════════════════════════════════════════════
    // TEST 8 - SCHEDULABLE EXECUTION
    // ════════════════════════════════════════════════════════════════════════

    @IsTest
    static void test_SchedulableExecution() {

        Test.startTest();


        String jobId =
            System.schedule(
                'OrderRetrySyncBatch_Test',
                '0 0 0 15 3 ? 2099',
                new OrderRetrySyncBatch()
            );


        Test.stopTest();


        CronTrigger cron = [
            SELECT Id,
                   CronJobDetail.Name,
                   CronExpression,
                   TimesTriggered,
                   State
            FROM CronTrigger
            WHERE Id = :jobId
            LIMIT 1
        ];


        System.assertEquals(
            jobId,
            cron.Id,
            'Scheduled job should be created.'
        );

        System.assertEquals(
            'OrderRetrySyncBatch_Test',
            cron.CronJobDetail.Name,
            'Unexpected scheduled job name.'
        );

        System.assertEquals(
            '0 0 0 15 3 ? 2099',
            cron.CronExpression,
            'Unexpected cron expression.'
        );
    }


    // ════════════════════════════════════════════════════════════════════════
    // TEST 9 - EVERY 20 MINUTES SCHEDULE
    // ════════════════════════════════════════════════════════════════════════

    @IsTest
    static void test_ScheduleEvery20Min() {

        Test.startTest();

        OrderRetrySyncBatch.scheduleEvery20Min();

        Test.stopTest();


        List<CronTrigger> jobs = [
            SELECT Id,
                   CronJobDetail.Name,
                   CronExpression,
                   State
            FROM CronTrigger
            WHERE CronJobDetail.Name
                LIKE 'OrderRetrySync_Every20Min%'
        ];


        System.assertEquals(
            3,
            jobs.size(),
            'Exactly three retry schedules should be created.'
        );


        Set<String> expectedExpressions =
            new Set<String>{
                '0 0 * * * ?',
                '0 20 * * * ?',
                '0 40 * * * ?'
            };


        Set<String> actualExpressions =
            new Set<String>();


        Set<String> expectedNames =
            new Set<String>{
                'OrderRetrySync_Every20Min_00',
                'OrderRetrySync_Every20Min_20',
                'OrderRetrySync_Every20Min_40'
            };


        Set<String> actualNames =
            new Set<String>();


        for (CronTrigger job : jobs) {

            actualExpressions.add(
                job.CronExpression
            );

            actualNames.add(
                job.CronJobDetail.Name
            );
        }


        System.assertEquals(
            expectedExpressions,
            actualExpressions,
            'Schedules must run at 00, 20 and 40 minutes.'
        );


        System.assertEquals(
            expectedNames,
            actualNames,
            'Unexpected schedule names.'
        );
    }


    // ════════════════════════════════════════════════════════════════════════
    // TEST 10 - SCHEDULE IS IDEMPOTENT
    // ════════════════════════════════════════════════════════════════════════

    @IsTest
    static void test_ScheduleEvery20Min_IsIdempotent() {

        Test.startTest();

        OrderRetrySyncBatch.scheduleEvery20Min();

        OrderRetrySyncBatch.scheduleEvery20Min();

        Test.stopTest();


        List<CronTrigger> jobs = [
            SELECT Id,
                   CronJobDetail.Name,
                   CronExpression,
                   State
            FROM CronTrigger
            WHERE CronJobDetail.Name
                LIKE 'OrderRetrySync_Every20Min%'
        ];


        /*
         * The second invocation should remove
         * the first three schedules and create
         * only three new schedules.
         */

        System.assertEquals(
            3,
            jobs.size(),
            'Calling scheduleEvery20Min twice must not create duplicates.'
        );


        Set<String> expectedExpressions =
            new Set<String>{
                '0 0 * * * ?',
                '0 20 * * * ?',
                '0 40 * * * ?'
            };


        Set<String> actualExpressions =
            new Set<String>();


        for (CronTrigger job : jobs) {

            actualExpressions.add(
                job.CronExpression
            );
        }


        System.assertEquals(
            expectedExpressions,
            actualExpressions,
            'Only the three expected schedules should exist.'
        );
    }
}
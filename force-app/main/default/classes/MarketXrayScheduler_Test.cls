@IsTest
public class MarketXrayScheduler_Test {

    @IsTest
    static void testSchedulerExecution() {

        Test.startTest();
        String jobId = System.schedule(
            'MarketXray Scheduler Test',
            '0 0 2 * * ?',
            new MarketXrayScheduler()
        );
        Test.stopTest();

        CronTrigger ct = [
            SELECT Id, CronExpression, TimesTriggered
            FROM CronTrigger
            WHERE Id = :jobId
        ];

        System.assertEquals('0 0 2 * * ?', ct.CronExpression);
        System.assertEquals(0, ct.TimesTriggered);
    }
}
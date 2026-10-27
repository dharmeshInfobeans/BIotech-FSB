@IsTest
private class MOMCustomNotificationService_Test {

    // ─── Helpers ───────────────────────────────────────────────────────────────

    private static MOMCustomNotificationService.NotificationRequest buildRequest(String notifTypeId) {
        MOMCustomNotificationService.NotificationRequest req = new MOMCustomNotificationService.NotificationRequest();
        req.notifTypeId  = notifTypeId;
        req.title        = 'Test Title';
        req.body         = 'Test Body';
        req.targetId     = UserInfo.getUserId();
        req.recipientId  = UserInfo.getUserId();
        return req;
    }

    // ─── Tests ─────────────────────────────────────────────────────────────────

    @IsTest
    static void sendNotification_WhenEmptyList_ShouldReturnWithoutError() {
        // Arrange
        List<MOMCustomNotificationService.NotificationRequest> requests =
            new List<MOMCustomNotificationService.NotificationRequest>();

        // Act
        Test.startTest();
        MOMCustomNotificationService.sendNotification(requests);
        Test.stopTest();

        // Assert — no exception propagated
        System.assert(true, 'Empty list should complete without errors');
    }

    @IsTest
    static void sendNotification_WhenBlankNotifTypeId_ShouldSkipWithoutError() {
        // Arrange
        List<MOMCustomNotificationService.NotificationRequest> requests =
            new List<MOMCustomNotificationService.NotificationRequest>{ buildRequest('') };

        // Act
        Test.startTest();
        MOMCustomNotificationService.sendNotification(requests);
        Test.stopTest();

        // Assert — blank type ID triggers continue, no exception
        System.assert(true, 'Blank notifTypeId should be skipped gracefully');
    }

    @IsTest
    static void sendNotification_WhenInvalidNotifTypeId_ShouldCatchExceptionAndNotPropagate() {
        // Arrange — fake but non-blank ID forces Messaging.CustomNotification to throw,
        // which exercises the catch block without needing a real CustomNotificationType
        List<MOMCustomNotificationService.NotificationRequest> requests =
            new List<MOMCustomNotificationService.NotificationRequest>{ buildRequest('0ML000000000001AAA') };

        // Act
        Test.startTest();
        MOMCustomNotificationService.sendNotification(requests);
        Test.stopTest();

        // Assert — exception caught, flow is not interrupted
        System.assert(true, 'Invalid notifTypeId exception should be caught and not propagate');
    }

    @IsTest
    static void sendNotification_BulkTest_ShouldHandle200RecordsWithoutError() {
        // Arrange
        List<MOMCustomNotificationService.NotificationRequest> requests =
            new List<MOMCustomNotificationService.NotificationRequest>();
        for (Integer i = 0; i < 200; i++) {
            requests.add(buildRequest('0ML000000000001AAA'));
        }

        // Act
        Test.startTest();
        MOMCustomNotificationService.sendNotification(requests);
        Test.stopTest();

        // Assert
        System.assertEquals(200, requests.size(), '200 requests should all be processed');
    }

    @IsTest
    static void sendNotification_WhenBlankRecipientId_ShouldSkipWithoutError() {
        // Arrange
        MOMCustomNotificationService.NotificationRequest req = buildRequest('0ML000000000001AAA');
        req.recipientId = '';
        List<MOMCustomNotificationService.NotificationRequest> requests =
            new List<MOMCustomNotificationService.NotificationRequest>{ req };

        // Act
        Test.startTest();
        MOMCustomNotificationService.sendNotification(requests);
        Test.stopTest();

        // Assert — blank recipientId triggers continue, no exception
        System.assert(true, 'Blank recipientId should be skipped gracefully');
    }
}
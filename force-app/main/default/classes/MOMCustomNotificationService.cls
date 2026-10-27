public with sharing class MOMCustomNotificationService {

    @InvocableMethod(
        label='Send MOM Custom Notification'
        description='Sends an in-app custom notification for MOM Action Items'
    )
    public static void sendNotification(List<NotificationRequest> requests) {
        for (NotificationRequest req : requests) {
            if (String.isBlank(req.notifTypeId) || String.isBlank(req.recipientId)) {
                continue;
            }
            try {
                Messaging.CustomNotification notif = new Messaging.CustomNotification();
                notif.setTitle(req.title);
                notif.setBody(req.body);
                notif.setNotificationTypeId(req.notifTypeId);
                notif.setTargetId(req.targetId);
                notif.send(new Set<String>{ req.recipientId });
            } catch (Exception e) {
                // Silently fail — notification failure must not block flow or email delivery
            }
        }
    }

    public class NotificationRequest {
        @InvocableVariable(required=true label='Custom Notification Type Id')
        public String notifTypeId;

        @InvocableVariable(required=true label='Title')
        public String title;

        @InvocableVariable(required=true label='Body')
        public String body;

        @InvocableVariable(required=true label='Target Record Id')
        public String targetId;

        @InvocableVariable(required=true label='Recipient User Id')
        public String recipientId;
    }
}
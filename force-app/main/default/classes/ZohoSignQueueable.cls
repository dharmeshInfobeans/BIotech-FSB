public class ZohoSignQueueable implements Queueable, Database.AllowsCallouts {

    public class SignRef {
        public Id accountId;
        public Id contentVersionId;
        public String fileName;
        public String recipientName;
        public String recipientEmail;

        public SignRef(Id accountId, Id contentVersionId, String fileName, String recipientName, String recipientEmail) {
            this.accountId        = accountId;
            this.contentVersionId = contentVersionId;
            this.fileName         = fileName;
            this.recipientName    = recipientName;
            this.recipientEmail   = recipientEmail;
        }
    }

    private List<SignRef> refs;
    private Integer currentIndex;

    public ZohoSignQueueable(List<SignRef> refs, Integer startIndex) {
        this.refs         = refs;
        this.currentIndex = startIndex != null ? startIndex : 0;
    }

    public void execute(QueueableContext qc) {
        if (refs == null || currentIndex >= refs.size()) return;

        SignRef ref = refs[currentIndex];

        try {
            List<ContentVersion> cvList = [
                SELECT Id, VersionData 
                FROM ContentVersion 
                WHERE Id = :ref.contentVersionId 
                LIMIT 1
            ];

            if (!cvList.isEmpty() && cvList[0].VersionData != null) {
                ZohoSignService.processRequest(
                    ref.accountId,
                    cvList[0].VersionData,
                    ref.fileName,
                    ref.recipientName,
                    ref.recipientEmail
                );
                System.debug('Zoho Sign successfully processed for Account: ' + ref.accountId);
            } else {
                System.debug('ContentVersion not found or empty for Account: ' + ref.accountId);
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Zoho Sign failed for Account ' + ref.accountId + ': ' + e.getMessage());
        } finally {
            // ALWAYS chain to the next index in the list
            Integer nextIndex = currentIndex + 1;
            if (nextIndex < refs.size() && !Test.isRunningTest()) {
                System.enqueueJob(new ZohoSignQueueable(refs, nextIndex));
            }
        }
    }
}
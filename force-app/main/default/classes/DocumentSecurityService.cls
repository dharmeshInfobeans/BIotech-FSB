public with sharing class DocumentSecurityService {

    // Called from LWC after upload to ensure portal users can access the file.
    // lightning-file-upload may create ContentDocumentLink with InternalUsers visibility
    // when run by an internal user — this corrects it to AllUsers for portal access.
    @AuraEnabled
    public static void enforceVisibility(List<String> contentDocumentIds, Id linkedEntityId) {
        if (contentDocumentIds == null || contentDocumentIds.isEmpty()) return;
        try {
            List<ContentDocumentLink> links = new ElevatedQuery().getLinks(contentDocumentIds, linkedEntityId);
            List<ContentDocumentLink> toUpdate = new List<ContentDocumentLink>();
            for (ContentDocumentLink cdl : links) {
                if (cdl.Visibility != 'AllUsers') {
                    cdl.Visibility = 'AllUsers';
                    toUpdate.add(cdl);
                }
            }
            if (!toUpdate.isEmpty()) update toUpdate;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'DocumentSecurityService.enforceVisibility error: ' + e.getMessage());
        }
    }

    // Creates a ContentDocumentLink from each uploaded file to the Registration_Request__c
    // so that the Distributor (who owns the request) can access the files via the portal.
    @AuraEnabled
    public static void shareWithDistributor(List<String> contentDocumentIds, Id requestId) {
        if (contentDocumentIds == null || contentDocumentIds.isEmpty() || requestId == null) return;
        try {
            new ElevatedQuery().linkToRequest(contentDocumentIds, requestId);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'DocumentSecurityService.shareWithDistributor error: ' + e.getMessage());
        }
    }

    private without sharing class ElevatedQuery {
        public List<ContentDocumentLink> getLinks(List<String> docIds, Id linkedEntityId) {
            return [
                SELECT Id, Visibility
                FROM   ContentDocumentLink
                WHERE  ContentDocumentId IN :docIds
                AND    LinkedEntityId    =  :linkedEntityId
            ];
        }

        public void linkToRequest(List<String> docIds, Id requestId) {
            Set<Id> existing = new Set<Id>();
            for (ContentDocumentLink cdl : [
                SELECT ContentDocumentId
                FROM   ContentDocumentLink
                WHERE  LinkedEntityId     = :requestId
                AND    ContentDocumentId IN :docIds
            ]) {
                existing.add(cdl.ContentDocumentId);
            }
            List<ContentDocumentLink> toInsert = new List<ContentDocumentLink>();
            for (String docIdStr : docIds) {
                Id docId = (Id) docIdStr;
                if (docId != null && !existing.contains(docId)) {
                    toInsert.add(new ContentDocumentLink(
                        ContentDocumentId = docId,
                        LinkedEntityId    = requestId,
                        ShareType         = 'V',
                        Visibility        = 'AllUsers'
                    ));
                }
            }
            if (!toInsert.isEmpty()) insert toInsert;
        }
    }
}
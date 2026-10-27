global without sharing class SAPLedgerSignBatch implements Database.Batchable<SObject>, Database.Stateful {

    private Set<Id> accountIds;
    private String statementDate;
    private List<ZohoSignQueueable.SignRef> pendingRefs = new List<ZohoSignQueueable.SignRef>();

    public SAPLedgerSignBatch(List<Id> accountIds, String statementDate) {
        this.accountIds    = new Set<Id>(accountIds);
        this.statementDate = statementDate;
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name
            FROM Account
            WHERE Id IN :accountIds
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Account> scope) {
        Set<Id> accIds = new Map<Id, Account>(scope).keySet();
        Map<Id, Contact> primaryContactMap = SAPLedgerService.getPrimaryContactsByAccount(accIds);

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :accIds
        ];

        Map<Id, Id> accountToDocMap = new Map<Id, Id>();
        Set<Id> docIds = new Set<Id>();

        for (ContentDocumentLink cdl : links) {
            accountToDocMap.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
            docIds.add(cdl.ContentDocumentId);
        }

        if (docIds.isEmpty()) return;

        String titlePattern = 'L_%' + statementDate + '%';

        Map<Id, ContentVersion> docMap = new Map<Id, ContentVersion>();
        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId, Title, FileExtension, CreatedDate
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND Title LIKE :titlePattern
            ORDER BY CreatedDate DESC
        ]) {
            if (!docMap.containsKey(cv.ContentDocumentId)) {
                docMap.put(cv.ContentDocumentId, cv);
            }
        }

        for (Account acc : scope) {
            Contact con = primaryContactMap.get(acc.Id);
            if (con == null) continue;

            Id docId = accountToDocMap.get(acc.Id);
            if (docId == null) continue;

            ContentVersion pdf = docMap.get(docId);
            if (pdf == null) continue;

            String fileName = pdf.Title;
            if (String.isNotBlank(pdf.FileExtension)) {
                fileName += '.' + pdf.FileExtension;
            }

            pendingRefs.add(new ZohoSignQueueable.SignRef(
                acc.Id, pdf.Id, fileName, con.Name, con.Email
            ));
        }
    }

    global void finish(Database.BatchableContext bc) {
        if (!pendingRefs.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new ZohoSignQueueable(pendingRefs, 0));
        }
        System.debug('SAPLedgerSignBatch completed. Queued ' + pendingRefs.size() + ' requests.');
    }
}
public class ZohoSignedDocBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Zoho_Request_Id__c, Status__c, Signed_Document_Processed__c, Account__c, Customer_Name__c, Signed_Date__c 
            FROM Customer_Ledger__c
            WHERE Status__c = 'Completed'
              AND Zoho_Request_Id__c != null
              AND Signed_Document_Processed__c = false
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Customer_Ledger__c> scope) {
        Set<Id> ledgerIds = new Map<Id, Customer_Ledger__c>(scope).keySet();

        // 1. Bulk Query all existing document links outside loop
        Map<Id, List<Id>> ledgerToOldDocIdsMap = new Map<Id, List<Id>>();
        for (ContentDocumentLink link : [
            SELECT LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :ledgerIds
            AND ContentDocument.Title LIKE 'L%'
        ]) {
            if (!ledgerToOldDocIdsMap.containsKey(link.LinkedEntityId)) {
                ledgerToOldDocIdsMap.put(link.LinkedEntityId, new List<Id>());
            }
            ledgerToOldDocIdsMap.get(link.LinkedEntityId).add(link.ContentDocumentId);
        }

        Zoho_Settings__c cs = Zoho_Settings__c.getOrgDefaults();
        String accessToken = cs != null ? cs.Access_Token__c : null;
        if (String.isBlank(accessToken)) return;

        List<ContentVersion> docsToInsert       = new List<ContentVersion>();
        List<Customer_Ledger__c> ledgersToUpdate = new List<Customer_Ledger__c>();
        Set<Id> oldDocIdsToDelete               = new Set<Id>();
        List<Map<String, Object>> linkPlan      = new List<Map<String, Object>>();

        for (Customer_Ledger__c ledger : scope) {
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:Zoho_Sign/api/v1/requests/' + ledger.Zoho_Request_Id__c + '/pdf');
                req.setMethod('GET');
                req.setHeader('Authorization', 'Zoho-oauthtoken ' + accessToken);
                req.setTimeout(60000);

                HttpResponse res = new Http().send(req);

                if (res.getStatusCode() == 200) {
                    Blob pdfBlob = res.getBodyAsBlob();
                    String ledgerNamePart = String.isNotBlank(ledger.Customer_Name__c) ? ledger.Customer_Name__c : ledger.Id;
                    String signedDatePart = ledger.Signed_Date__c != null ? ledger.Signed_Date__c.format('yyyy-MM-dd') : String.valueOf(Date.today());

                    String docTitle = 'Signed_' + ledgerNamePart + '_' + signedDatePart;
                    String docPath  = 'Signed_' + ledger.Zoho_Request_Id__c + '.pdf';

                    // Prepare ContentVersion for Ledger
                    ContentVersion cvLedger = new ContentVersion(
                        Title = docTitle, PathOnClient = docPath, VersionData = pdfBlob
                    );
                    docsToInsert.add(cvLedger);

                    linkPlan.add(new Map<String, Object>{
                        'cvIndex' => docsToInsert.size() - 1,
                        'linkedEntityId' => ledger.Id
                    });

                    // Prepare ContentVersion for Account
                    if (ledger.Account__c != null) {
                        ContentVersion cvAcc = new ContentVersion(
                            Title = docTitle, PathOnClient = docPath, VersionData = pdfBlob
                        );
                        docsToInsert.add(cvAcc);

                        linkPlan.add(new Map<String, Object>{
                            'cvIndex' => docsToInsert.size() - 1,
                            'linkedEntityId' => ledger.Account__c
                        });
                    }

                    // Collect old doc IDs for safe deletion later
                    if (ledgerToOldDocIdsMap.containsKey(ledger.Id)) {
                        oldDocIdsToDelete.addAll(ledgerToOldDocIdsMap.get(ledger.Id));
                    }

                    ledger.Signed_Document_Processed__c = true;
                    ledgersToUpdate.add(ledger);
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error downloading signed PDF for ledger ' + ledger.Id + ': ' + e.getMessage());
            }
        }

        // 2. Insert ContentVersions in Bulk
        if (!docsToInsert.isEmpty()) {
            insert docsToInsert;

            Set<Id> cvIds = new Map<Id, ContentVersion>(docsToInsert).keySet();
            Map<Id, Id> cvIdToDocId = new Map<Id, Id>();
            for (ContentVersion cv : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :cvIds]) {
                cvIdToDocId.put(cv.Id, cv.ContentDocumentId);
            }

            List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
            for (Map<String, Object> plan : linkPlan) {
                Integer idx = (Integer) plan.get('cvIndex');
                Id entityId = (Id) plan.get('linkedEntityId');
                Id docId    = cvIdToDocId.get(docsToInsert[idx].Id);

                if (docId != null) {
                    linksToInsert.add(new ContentDocumentLink(
                        ContentDocumentId = docId,
                        LinkedEntityId    = entityId,
                        ShareType         = 'V',
                        Visibility        = 'AllUsers'
                    ));
                }
            }
            if (!linksToInsert.isEmpty()) {
                Database.insert(linksToInsert, false);
            }
        }

        // 3. Update Ledgers in Bulk
        if (!ledgersToUpdate.isEmpty()) {
            Database.update(ledgersToUpdate, false);
        }

        // 4. Safely Delete Old Draft Documents
        if (!oldDocIdsToDelete.isEmpty()) {
            List<ContentDocument> docsToDelete = [SELECT Id FROM ContentDocument WHERE Id IN :oldDocIdsToDelete];
            Database.delete(docsToDelete, false);
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('ZohoSignedDocBatch completed successfully.');
    }
}
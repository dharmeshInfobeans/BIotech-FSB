global without sharing class SAPLedgerBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    private String statementDate;
    private String fromDateStr;
    private String quarter;
    private List<Id> accountIds;
    private Map<Id, String> accountCompanyCodes;
    private String batchRunId;

    private class SuccessfulItem {
        Account acc;
        Contact contact;
        Date stmtDate;
        Date fromDate;
        String quarter;
        String docTitle;
        String ledgerName;
        Long startTime;
        ContentVersion cv;
        SAPLedgerService.SAPLedgerResponse response;
        String companyCode;
    }

    // Main Constructor with From Date, Quarter, Account IDs, and custom Company Codes
    public SAPLedgerBatch(String statementDate, String fromDateStr, String quarter, List<Id> accountIds, Map<Id, String> accountCompanyCodes) {
        this.statementDate        = statementDate;
        this.fromDateStr          = fromDateStr;
        this.quarter              = quarter;
        this.accountIds           = accountIds;
        this.accountCompanyCodes  = accountCompanyCodes;
    }

    // Constructor with From Date and Quarter (Backwards Compatibility)
    public SAPLedgerBatch(String statementDate, String fromDateStr, String quarter, List<Id> accountIds) {
        this(statementDate, fromDateStr, quarter, accountIds, null);
    }

    // Overloaded Constructor (Backwards Compatibility)
    public SAPLedgerBatch(String statementDate, List<Id> accountIds) {
        this(statementDate, null, null, accountIds, null);
    }

    // Overloaded 1-param Constructor
    public SAPLedgerBatch(String statementDate) {
        this(statementDate, null, null, null, null);
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        this.batchRunId = bc.getJobId();

        if (this.accountIds != null && !this.accountIds.isEmpty()) {
            return Database.getQueryLocator([
                SELECT Id, Name, Status__c, E_mail__c, SAP_Code__c, Company_Code__c
                FROM Account
                WHERE Id IN :accountIds
                AND SAP_Code__c != null
            ]);
        }

        return Database.getQueryLocator([
            SELECT Id, Name, Status__c, E_mail__c, SAP_Code__c, Company_Code__c
            FROM Account 
            WHERE SAP_Code__c != null
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Account> scope) {
        String currentJobId = (bc != null && bc.getJobId() != null) ? String.valueOf(bc.getJobId()) : this.batchRunId;
        this.batchRunId = currentJobId;

        Set<Id> scopeAccountIds = new Map<Id, Account>(scope).keySet();
        
        Map<Id, Contact> primaryContactMap = SAPLedgerService.getPrimaryContactsByAccount(scopeAccountIds);

        List<SuccessfulItem> successItems         = new List<SuccessfulItem>();
        List<ContentVersion> cvsToInsert          = new List<ContentVersion>();
        List<Customer_Ledger_Log__c> logsToInsert = new List<Customer_Ledger_Log__c>();
        Set<Id> successfulAccountIds              = new Set<Id>();
        
        Date parsedStmtDate;
        if (String.isNotBlank(statementDate)) {
            String cleanStmt = statementDate.replaceAll('[^0-9]', '');
            if (cleanStmt.length() == 8) {
                parsedStmtDate = Date.newInstance(
                    Integer.valueOf(cleanStmt.substring(0, 4)),
                    Integer.valueOf(cleanStmt.substring(4, 6)),
                    Integer.valueOf(cleanStmt.substring(6, 8))
                );
            }
        }
        if (parsedStmtDate == null) {
            parsedStmtDate = Date.today();
        }
        
        Integer monthNo   = parsedStmtDate.month();
        Integer yearNo    = parsedStmtDate.year();
        Integer quarterNo = ((monthNo - 1) / 3) + 1;
        String quarterLabel = String.isNotBlank(this.quarter) ? this.quarter : ('Q' + quarterNo);
            
            Date parsedFromDate;
        if (String.isNotBlank(fromDateStr)) {
            String cleanFrom = fromDateStr.replaceAll('[^0-9]', '');
            if (cleanFrom.length() == 8) {
                parsedFromDate = Date.newInstance(
                    Integer.valueOf(cleanFrom.substring(0, 4)),
                    Integer.valueOf(cleanFrom.substring(4, 6)),
                    Integer.valueOf(cleanFrom.substring(6, 8))
                );
            }
        }
        
        // Fallback: If fromDate was not provided or failed to parse, retrieve from Ledger_Quarter_Date__c or quarter start
        if (parsedFromDate == null) {
            List<Ledger_Quarter_Date__c> qDates = [
                SELECT From_Date__c 
                FROM Ledger_Quarter_Date__c 
                WHERE Quarter__c = :quarterLabel 
                AND Year__c = :yearNo 
                LIMIT 1
            ];
            if (!qDates.isEmpty() && qDates[0].From_Date__c != null) {
                parsedFromDate = qDates[0].From_Date__c;
            } else {
                Integer startMonth = ((quarterNo - 1) * 3) + 1;
                parsedFromDate = Date.newInstance(yearNo, startMonth, 1);
            }
        }
        for (Account acc : scope) {
            Long startTime = System.currentTimeMillis();

            String effectiveCompanyCode = (this.accountCompanyCodes != null && this.accountCompanyCodes.containsKey(acc.Id) && String.isNotBlank(this.accountCompanyCodes.get(acc.Id)))
                ? this.accountCompanyCodes.get(acc.Id)
                : acc.Company_Code__c;

            try {
                SAPLedgerService.SAPLedgerResponse response = SAPLedgerService.fetchLedgerForAccount(
                    effectiveCompanyCode, 
                    acc.SAP_Code__c, 
                    this.fromDateStr, 
                    this.statementDate
                );

                Contact primaryContact = primaryContactMap.get(acc.Id);

                if (response != null && response.Status == 'S' && String.isNotBlank(response.PDFBase64) && primaryContact != null) {
                    String base64Pdf = response.PDFBase64.contains(',') ? response.PDFBase64.substringAfter(',') : response.PDFBase64;
                    Blob pdfBlob = EncodingUtil.base64Decode(base64Pdf);

                    String docTitle   = 'L_' + acc.Name + '_' + acc.SAP_Code__c + '_' + quarterLabel + '_' + yearNo;
                    String ledgerName = 'L-' + acc.Name + '_' + acc.SAP_Code__c + '_' + quarterLabel + '_' + yearNo;

                    ContentVersion cv = new ContentVersion(
                        Title                  = docTitle,
                        PathOnClient           = docTitle + '.pdf',
                        VersionData            = pdfBlob,
                        FirstPublishLocationId = acc.Id
                    );
                    cvsToInsert.add(cv);

                    SuccessfulItem item = new SuccessfulItem();
                    item.acc         = acc;
                    item.contact     = primaryContact;
                    item.stmtDate    = parsedStmtDate;
                    item.fromDate    = parsedFromDate;
                    item.quarter     = quarterLabel;
                    item.docTitle    = docTitle;
                    item.ledgerName  = ledgerName;
                    item.startTime   = startTime;
                    item.cv          = cv;
                    item.response    = response;
                    item.companyCode = effectiveCompanyCode;
                    successItems.add(item);

                    successfulAccountIds.add(acc.Id);
                } else {
                    String reason = (primaryContact == null) 
                        ? 'No active partner user contact found for this Account' 
                        : (response != null ? response.Message : 'Empty response from SAP');

                    logsToInsert.add(new Customer_Ledger_Log__c(
                        Account__c             = acc.Id,
                        Company_Code__c        = effectiveCompanyCode,
                        Customer_Code__c       = acc.SAP_Code__c,
                        Statement_Date__c      = parsedStmtDate,
                        From_Date__c           = parsedFromDate,
                        Quarter__c             = quarterLabel,
                        Status__c              = 'Failed',
                        Batch_Run_ID__c        = batchRunId,
                        SAP_Response_Status__c = response?.Status,
                        Error_Details__c       = reason,
                        HTTP_Status_Code__c    = response?.HttpStatusCode != null ? String.valueOf(response.HttpStatusCode) : null,
                        Log_Timestamp__c       = System.now(),
                        Triggered_By__c        = 'SAP'
                    ));
                }
            } catch (Exception e) {
                logsToInsert.add(new Customer_Ledger_Log__c(
                    Account__c        = acc.Id,
                    Company_Code__c   = effectiveCompanyCode,
                    Customer_Code__c  = acc.SAP_Code__c,
                    Statement_Date__c = parsedStmtDate,
                    From_Date__c      = parsedFromDate,
                    Quarter__c        = quarterLabel,
                    Status__c         = 'Failed',
                    Batch_Run_ID__c   = batchRunId,
                    Error_Details__c  = e.getMessage() + ' | ' + e.getStackTraceString(),
                    Log_Timestamp__c  = System.now(),
                    Triggered_By__c   = 'SAP'
                ));
            }
        }

        // Bulk DML: ContentVersions
        if (!cvsToInsert.isEmpty()) {
            insert cvsToInsert;

            Map<Id, Id> cvIdToDocIdMap = new Map<Id, Id>();
            for (ContentVersion cv : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :cvsToInsert]) {
                cvIdToDocIdMap.put(cv.Id, cv.ContentDocumentId);
            }

            // Bulk DML: Ledgers
            List<Customer_Ledger__c> ledgersToInsert = new List<Customer_Ledger__c>();
            for (SuccessfulItem item : successItems) {
                Customer_Ledger__c ledger = new Customer_Ledger__c(
                    Account__c        = item.acc.Id,
                    Company_Code__c   = item.companyCode,
                    Customer_Code__c  = item.acc.SAP_Code__c,
                    Customer_Email__c = item.acc.E_Mail__c,
                    Customer_Name__c  = item.ledgerName,
                    Statement_Date__c = item.stmtDate,
                    From_Date__c      = item.fromDate,
                    Quarter__c        = item.quarter,
                    Contact_Name__c   = item.contact.Name,
                    Status__c         = 'Fetched'
                );
                ledgersToInsert.add(ledger);
            }
            insert ledgersToInsert;

            // Bulk DML: Links and Success Logs
            List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
            for (Integer i = 0; i < successItems.size(); i++) {
                SuccessfulItem item = successItems[i];
                Customer_Ledger__c ledger = ledgersToInsert[i];
                Id docId = cvIdToDocIdMap.get(item.cv.Id);

                if (docId != null) {
                    linksToInsert.add(new ContentDocumentLink(
                        ContentDocumentId = docId,
                        LinkedEntityId    = ledger.Id,
                        ShareType         = 'V',
                        Visibility        = 'AllUsers'
                    ));
                }

                Long duration = System.currentTimeMillis() - item.startTime;
                logsToInsert.add(new Customer_Ledger_Log__c(
                    Customer_Ledger__c     = ledger.Id,
                    Account__c             = item.acc.Id,
                    Company_Code__c        = item.companyCode,
                    Customer_Code__c       = item.acc.SAP_Code__c,
                    Statement_Date__c      = item.stmtDate,
                    From_Date__c           = item.fromDate,
                    Quarter__c             = item.quarter,
                    Status__c              = 'Success',
                    Batch_Run_ID__c        = batchRunId,
                    SAP_Response_Status__c = 'S',
                    Remarks__c             = 'Ledger PDF generated and attached successfully.',
                    Content_Document_ID__c = docId,
                    Duration_ms__c         = duration,
                    HTTP_Status_Code__c    = '200',
                    Log_Timestamp__c       = System.now(),
                    Triggered_By__c        = 'SAP'
                ));
            }

            if (!linksToInsert.isEmpty()) {
                Database.insert(linksToInsert, false);
            }
        }

        if (!successfulAccountIds.isEmpty()) {
            List<Customer_Ledger_Log__c> oldFailedLogs = [
                SELECT Id, Status__c FROM Customer_Ledger_Log__c
                WHERE Account__c IN :successfulAccountIds
                AND Status__c = 'Failed'
                AND Triggered_By__c = 'SAP'
            ];
            for (Customer_Ledger_Log__c oldLog : oldFailedLogs) {
                oldLog.Status__c = 'Retried';
            }
            if (!oldFailedLogs.isEmpty()) {
                Database.update(oldFailedLogs, false);
            }
        }

        if (!logsToInsert.isEmpty()) {
            Database.insert(logsToInsert, false);
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('SAPLedgerBatch finished successfully.');
    }
}
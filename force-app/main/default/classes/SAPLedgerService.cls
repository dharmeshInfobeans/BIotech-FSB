public without sharing class SAPLedgerService {
    
    public static Map<Id, Contact> getPrimaryContactsByAccount(Set<Id> accountIds) {
        Map<Id, Contact> result = new Map<Id, Contact>();
        if (accountIds == null || accountIds.isEmpty()) {
            return result;
        }
        
        for (User u : [
            SELECT AccountId, Contact.Name, Contact.Email
            FROM User
            WHERE AccountId IN :accountIds
            AND ContactId != null
            AND IsPortalEnabled = true
            AND IsActive = true
            AND Contact.Email != null
            ORDER BY AccountId, LastLoginDate DESC NULLS LAST
        ]) {
            if (!result.containsKey(u.AccountId)) {
                result.put(u.AccountId, u.Contact);
            }
        }
        return result;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> searchAccounts(String accountName, String sapCode) {
        
        String query =
            'SELECT Id, Name, SAP_Code__c, Company_Code__c, region__c, region__r.Name ' +
            'FROM Account ' +
            'WHERE SAP_Code__c != NULL';
        
        if (String.isNotBlank(accountName)) {
            query += ' AND Name LIKE \'%' +
                String.escapeSingleQuotes(accountName) +
                '%\'';
        }
        
        if (String.isNotBlank(sapCode)) {
            query += ' AND SAP_Code__c LIKE \'%' +
                String.escapeSingleQuotes(sapCode) +
                '%\'';
        }
        
        query += ' ORDER BY Name';
        
        List<Account> accounts = Database.query(query);
        
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        if (accounts.isEmpty()) {
            return results;
        }
        
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : accounts) {
            accountIds.add(acc.Id);
        }
        
        Map<Id, Contact> primaryContactMap = getPrimaryContactsByAccount(accountIds);
        
        for (Account acc : accounts) {
            Contact c = primaryContactMap.get(acc.Id);
            
            Map<String, Object> row = new Map<String, Object>();
            row.put('accountId',    acc.Id);
            row.put('accountName',  acc.Name);
            row.put('sapCode',      acc.SAP_Code__c);
            row.put('companyCode',  '');
            row.put('region',       acc.region__r != null ? acc.region__r.Name : '');
            row.put('contactName',  c != null ? c.Name  : '—');
            row.put('contactEmail', c != null ? c.Email : '—');
            results.add(row);
        }
        
        return results;
    }
    
    // startLedgerBatch() with fromDate, quarter, accountIds, and accountCompanyCodes
    @AuraEnabled
    public static Id startLedgerBatch(String statementDate, String fromDate, String quarter, List<Id> accountIds, Map<Id, String> accountCompanyCodes) {
        if (accountIds == null || accountIds.isEmpty()) {
            throw new AuraHandledException('Please select at least one Account.');
        }
        return Database.executeBatch(new SAPLedgerBatch(statementDate, fromDate, quarter, accountIds, accountCompanyCodes), 10); 
    }

    // startLedgerBatch() with fromDate and quarter (Backwards Compatibility for Apex callers)
    public static Id startLedgerBatch(String statementDate, String fromDate, String quarter, List<Id> accountIds) {
        return startLedgerBatch(statementDate, fromDate, quarter, accountIds, null);
    }
    
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getBatchJobStatus(Id jobId) {
        
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, ExtendedStatus
            FROM AsyncApexJob
            WHERE Id = :jobId
            LIMIT 1
        ];
        
        Map<String, Object> result = new Map<String, Object>();
        result.put('status', job.Status);              
        result.put('processed', job.JobItemsProcessed);
        result.put('total', job.TotalJobItems);
        result.put('errors', job.NumberOfErrors);
        return result;
    }
    
    // fetchLedgerForAccount() - Constructs endpoint with FromDate and ToDate
    public static SAPLedgerResponse fetchLedgerForAccount(String companyCode, String customerCode, String fromDateStr, String statementDate) {
        
        try {
            SAP_ODATA_Settings__c settings = SAP_ODATA_Settings__c.getInstance('Default');
            
            if (settings == null) {
                throw new CalloutException('SAP ODATA Settings "Default" record not found. Please configure Custom Setting.');
            }
            
            String username     = settings.Username__c;
            String password     = settings.Password__c;
            String baseEndpoint = settings.Endpoint__c;
            
            if (String.isBlank(username) || String.isBlank(password) || String.isBlank(baseEndpoint)) {
                throw new CalloutException('SAP ODATA Settings "Default" record is missing Username, Password, or Endpoint.');
            }
            
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            
            // Constructs: {baseEndpoint}/Es_CustLedgerSet(CompanyCode='1000',CustomerCode='1375',FromDate='20230601',ToDate='20230630')?$format=json
            String endpoint = baseEndpoint.removeEnd('/') +
                '/Es_CustLedgerSet(' +
                'CompanyCode=\''  + companyCode   + '\',' +
                'CustomerCode=\'' + customerCode  + '\',' +
                'FromDate=\''     + fromDateStr   + '\',' +
                'ToDate=\''       + statementDate + '\'' +
                ')?$format=json';
            
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setTimeout(120000);
            
            String authValue = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(username + ':' + password));
            req.setHeader('Authorization', authValue);
            req.setHeader('X-Requested-With', 'XMLHttpRequest');
            req.setHeader('Accept', 'application/json');
            req.setHeader('Content-Type', 'application/json');
            
            System.debug('Endpoint = ' + endpoint);
            System.debug('===== REQUEST VALUES =====');
            System.debug('companyCode = '   + companyCode);
            System.debug('customerCode = '  + customerCode);
            System.debug('fromDateStr = '   + fromDateStr);
            System.debug('statementDate = ' + statementDate);
            
            HttpResponse res = http.send(req);
            System.debug('Status Code = ' + res.getStatusCode());
            System.debug('Response = ' + res.getBody());
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Map<String, Object> d = (Map<String, Object>) root.get('d');
                
                SAPLedgerResponse resp = new SAPLedgerResponse();
                resp.CompanyCode   = (String) d.get('CompanyCode');
                resp.CustomerCode  = (String) d.get('CustomerCode');
                resp.StatementDate = (String) d.get('StatementDate');
                resp.Status        = (String) d.get('Status');
                resp.Message       = (String) d.get('Message');
                resp.CurrencyCode  = (String) d.get('CurrencyCode');
                resp.PDFBase64     = (String) d.get('PDFBase64');
                resp.HttpStatusCode = res.getStatusCode();  
                return resp;
                
            } else {
                SAPLedgerResponse errResp = new SAPLedgerResponse();
                errResp.HttpStatusCode = res.getStatusCode();
                errResp.Status  = 'E';
                errResp.Message = 'SAP Error ' + res.getStatusCode() + ': ' + res.getBody();
                return errResp;
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'SAPLedgerService Error: ' + e.getMessage());
            throw e;
        }
    }
    
    public class SAPLedgerResponse {
        @AuraEnabled public String CompanyCode;
        @AuraEnabled public String CustomerCode;
        @AuraEnabled public String StatementDate;
        @AuraEnabled public Decimal LedgerAmount;
        @AuraEnabled public String CurrencyCode;
        @AuraEnabled public String PDFBase64;
        @AuraEnabled public String Status;
        @AuraEnabled public String Message;
        @AuraEnabled public String contentDocumentId;
        @AuraEnabled public Integer HttpStatusCode;
    }
    
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getProcessedAccounts(String statementDate, List<Id> accountIds, String jobId) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        
        Date stmtDate;
        if (String.isNotBlank(statementDate)) {
            String cleanStmt = statementDate.replaceAll('[^0-9]', '');
            if (cleanStmt.length() == 8) {
                stmtDate = Date.newInstance(
                    Integer.valueOf(cleanStmt.substring(0, 4)),
                    Integer.valueOf(cleanStmt.substring(4, 6)),
                    Integer.valueOf(cleanStmt.substring(6, 8))
                );
            }
        }
        if (stmtDate == null) return results;
        if (accountIds == null || accountIds.isEmpty()) return results;
        
        // If a jobId is provided, only return ledgers successfully generated in THIS batch run
        Set<Id> successfulLedgerIds = new Set<Id>();
        if (String.isNotBlank(jobId)) {
            String cleanJobId = jobId.trim();
            String shortJobId = cleanJobId.length() >= 15 ? cleanJobId.substring(0, 15) : cleanJobId;
            for (Customer_Ledger_Log__c log : [
                SELECT Customer_Ledger__c 
                FROM Customer_Ledger_Log__c 
                WHERE (Batch_Run_ID__c = :cleanJobId OR Batch_Run_ID__c = :shortJobId)
                AND Status__c = 'Success' 
                AND Customer_Ledger__c != null
            ]) {
                successfulLedgerIds.add(log.Customer_Ledger__c);
            }
            
            if (successfulLedgerIds.isEmpty()) {
                return results; // The current run failed or generated 0 new ledgers
            }
        }
        
        List<Customer_Ledger__c> ledgers;
        if (!successfulLedgerIds.isEmpty()) {
            ledgers = [
                SELECT Id, Account__c, Account__r.Name, Account__r.Status__c, Account__r.SAP_Code__c,
                Contact_Name__c, Customer_Code__c, Customer_Name__c, Company_Code__c, CreatedDate
                FROM Customer_Ledger__c
                WHERE Status__c = 'Fetched'
                AND Statement_Date__c  = :stmtDate
                AND Account__c IN :accountIds
                AND Id IN :successfulLedgerIds
                ORDER BY CreatedDate DESC
            ];
        } else {
            ledgers = [
                SELECT Id, Account__c, Account__r.Name, Account__r.Status__c, Account__r.SAP_Code__c,
                Contact_Name__c, Customer_Code__c, Customer_Name__c, Company_Code__c, CreatedDate
                FROM Customer_Ledger__c
                WHERE Status__c = 'Fetched'
                AND Statement_Date__c  = :stmtDate
                AND Account__c IN :accountIds
                ORDER BY CreatedDate DESC
            ];
        }
        
        if (ledgers.isEmpty()) return results;
        
        Set<Id> ledgerIds  = new Set<Id>();
        for (Customer_Ledger__c l : ledgers) {
            ledgerIds.add(l.Id);
            if (l.Account__c != null) accountIds.add(l.Account__c);
        }
        
        Map<Id, Id> ledgerToVersionId = new Map<Id, Id>();
        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :ledgerIds
        ]) {
            if (!ledgerToVersionId.containsKey(cdl.LinkedEntityId)) {
                ledgerToVersionId.put(cdl.LinkedEntityId, cdl.ContentDocument.LatestPublishedVersionId);
            }
        }
        
        Map<Id, Contact> primaryContactMap = getPrimaryContactsByAccount(new Set<Id>(accountIds));
        Set<Id> processedAccounts = new Set<Id>();
        
        for (Customer_Ledger__c l : ledgers) {
            if (processedAccounts.contains(l.Account__c)) continue;
            processedAccounts.add(l.Account__c);
            
            Contact c = primaryContactMap.get(l.Account__c);
            Map<String, Object> row = new Map<String, Object>();
            row.put('ledgerId',     l.Id);
            row.put('accountId',    l.Account__c);
            row.put('accountName',  l.Account__r.Name);
            row.put('sapCode',      l.Account__r.SAP_Code__c); 
            row.put('status',       l.Account__r.Status__c);
            row.put('title',        l.Customer_Name__c);
            row.put('versionId',    ledgerToVersionId.get(l.Id));
            row.put('createdDate',  String.valueOf(Date.today()));
            row.put('contactName',  c != null ? c.Name  : '—');
            row.put('contactEmail', c != null ? c.Email : '—');
            results.add(row);
        }        
        return results;
    }

    // Overload for Apex callers (Backwards Compatibility)
    public static List<Map<String, Object>> getProcessedAccounts(String statementDate, List<Id> accountIds) {
        return getProcessedAccounts(statementDate, accountIds, null);
    }

    @AuraEnabled
    public static String sendForSign(String accountId, String statementDate) {
        try {
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :accountId
            ];
            
            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink cdl : links) {
                docIds.add(cdl.ContentDocumentId);
            }
            
            if (docIds.isEmpty()) {
                return 'No documents found for account';
            }
            
            ContentVersion cv = [
                SELECT Id, VersionData, Title, FileExtension
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds
                AND Title LIKE 'L_%'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            String fullFileName = cv.Title;
            if (String.isNotBlank(cv.FileExtension)) {
                fullFileName += '.' + cv.FileExtension;
            }
            
            Account acc = [SELECT Id, Name FROM Account WHERE Id = :accountId LIMIT 1];
            Contact primaryContact = getPrimaryPartnerContact(accountId);
            
            if (primaryContact == null) {
                if (!hasAnyContact(accountId)) {
                    return 'No partner user contact present for this account.';
                }
                return 'Please try with partner user.';
            }
            
            String recipientName  = primaryContact.Name;
            String recipientEmail = primaryContact.Email;
      
            ZohoSignService.createAndSendRequest(accountId, cv.VersionData, fullFileName, recipientName, recipientEmail);
            
            List<Customer_Ledger_Log__c> logsToUpdate = [
                SELECT Id, Status__c
                FROM Customer_Ledger_Log__c
                WHERE Customer_Ledger__r.Account__c = :accountId
                AND Status__c = 'Failed'
            ];
            
            for (Customer_Ledger_Log__c log : logsToUpdate) {
                log.Status__c = 'Retried';
            }
            
            if (!logsToUpdate.isEmpty()) {
                update logsToUpdate;
            }
            
            return 'Sent to Zoho Sign successfully';
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String sendSelectedForSign(List<Id> accountIds, String statementDate){
        
        List<Customer_Ledger_Log__c> logsToUpdate = [
            SELECT Id, Status__c
            FROM Customer_Ledger_Log__c
            WHERE Customer_Ledger__r.Account__c IN :accountIds
            AND Status__c = 'Failed'
        ];
        
        for (Customer_Ledger_Log__c log : logsToUpdate) {
            log.Status__c = 'Retried';
        }
        
        if (!logsToUpdate.isEmpty()) {
            update logsToUpdate;
        }
        
        Database.executeBatch(new SAPLedgerSignBatch(accountIds, statementDate), 50);
        
        return 'Bulk Sign Process Started';
    }
    
    public static Contact getPrimaryPartnerContact(Id accountId) {
        List<User> partnerUsers = [
            SELECT Id, ContactId, Contact.Name, Contact.Email,
            AccountId, IsPortalEnabled, IsActive
            FROM User
            WHERE AccountId = :accountId
            AND ContactId != null
            AND IsPortalEnabled = true
            AND IsActive = true
            ORDER BY LastLoginDate DESC NULLS LAST
            LIMIT 1
        ];
        
        if (partnerUsers.isEmpty() || String.isBlank(partnerUsers[0].Contact.Email)) {
            return null;
        }
        return partnerUsers[0].Contact;
    }
    
    public static Boolean hasAnyContact(Id accountId) {
        return [SELECT COUNT() FROM Contact WHERE AccountId = :accountId] > 0;
    }    
    
    @AuraEnabled(cacheable=true)
    public static List<Customer_Ledger__c> getLedgers(String status) {
        User currentUser = [SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId()];
        Id accountId = currentUser.AccountId;
        
        String query = 'SELECT Id, Customer_Name__c, Company_Code__c, Customer_Code__c, ' +
            'Status__c, Account__c, Account__r.Name, Contact_Name__c, Statement_Date__c ' +
            'FROM Customer_Ledger__c';
        
        List<String> conditions = new List<String>();
        if (accountId != null) {
            conditions.add('Account__c = :accountId');
        }
        if (String.isNotBlank(status) && status != 'Draft') {
            conditions.add('Status__c = :status');
        }
        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }
        query += ' ORDER BY CreatedDate DESC';
        return Database.query(query);
    }
    
    @AuraEnabled
    public static Id getContentVersionId(Id ledgerId) {
        List<ContentDocumentLink> cdls = [
            SELECT Id, ContentDocumentId, Visibility, ShareType
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :ledgerId
        ];
        
        if (cdls.isEmpty()) return null;
        
        List<ContentDocumentLink> toFix = new List<ContentDocumentLink>();
        for (ContentDocumentLink l : cdls) {
            if (l.Visibility == 'InternalUsers' && l.ShareType == 'V') {
                l.Visibility = 'AllUsers';
                toFix.add(l);
            }
        }
        if (!toFix.isEmpty()) {
            try {
                update toFix;
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Could not update Visibility: ' + e.getMessage());
            }
        }
        
        ContentVersion cv = [
            SELECT Id
            FROM ContentVersion
            WHERE ContentDocumentId = :cdls[0].ContentDocumentId
            AND IsLatest = true
            LIMIT 1
        ];
        return cv.Id;
    }
    
    @AuraEnabled
    public static String getDownloadUrl(Id ledgerId) {
        List<ContentDocumentLink> cdls = [
            SELECT Id, ContentDocumentId, Visibility, ShareType
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :ledgerId
            AND (ContentDocument.Title LIKE 'L_%'
                 OR ContentDocument.Title LIKE 'Signed_%')
            ORDER BY ContentDocument.CreatedDate DESC
            LIMIT 1
        ];
        
        if (cdls.isEmpty()) {
            throw new AuraHandledException('No document found for this ledger.');
        }
        
        if (cdls[0].Visibility == 'InternalUsers' && cdls[0].ShareType == 'V') {
            try {
                cdls[0].Visibility = 'AllUsers';
                update cdls[0];
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Could not update Visibility: ' + e.getMessage());
            }
        }
        return '/sfc/servlet.shepherd/document/download/' + cdls[0].ContentDocumentId;
    }
    
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getPendingLedgers() {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        List<Customer_Ledger__c> ledgers = [
            SELECT Id, Name, Customer_Name__c, Company_Code__c, Customer_Code__c, Status__c,
            Sign_Status__c, Account__c, Account__r.Name, Account__r.SAP_Code__c,
            CreatedDate, LastModifiedDate
            FROM Customer_Ledger__c
            WHERE ( Status__c = 'Fetched'
                   OR ( Status__c = 'Sent' AND Zoho_Request_Id__c != null AND Zoho_Action_Id__c != null ) )
            ORDER BY LastModifiedDate DESC
        ];
        if (ledgers.isEmpty()) return results;
        
        Set<Id> ledgerIds  = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        for (Customer_Ledger__c l : ledgers) {
            ledgerIds.add(l.Id);
            if (l.Account__c != null) accountIds.add(l.Account__c);
        }
        
        Map<Id, Id> ledgerToVersionId = new Map<Id, Id>();
        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :ledgerIds
        ]) {
            if (!ledgerToVersionId.containsKey(cdl.LinkedEntityId)) {
                ledgerToVersionId.put(cdl.LinkedEntityId, cdl.ContentDocument.LatestPublishedVersionId);
            }
        }
        
        Map<Id, Contact> primaryContactMap = getPrimaryContactsByAccount(accountIds);
        for (Customer_Ledger__c l : ledgers) {
            Contact c = primaryContactMap.get(l.Account__c);
            Map<String, Object> row = new Map<String, Object>();
            row.put('ledgerId',     l.Id);
            row.put('ledgerName',   l.Customer_Name__c);
            row.put('ledgerStatus', l.Status__c);
            row.put('signStatus',   l.Sign_Status__c);
            row.put('accountId',    l.Account__c);
            row.put('accountName',  l.Account__r.Name);
            row.put('sapCode',      l.Account__r.SAP_Code__c);
            row.put('versionId',    ledgerToVersionId.get(l.Id));
            row.put('contactName',  c != null ? c.Name  : '—');
            row.put('contactEmail', c != null ? c.Email : '—');
            row.put('createdDate', l.CreatedDate);
            results.add(row);
        }
        return results;
    }
    
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getSignedLedgers() {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        List<Customer_Ledger__c> ledgers = [
            SELECT Id, Name, Customer_Name__c, Company_Code__c, Customer_Code__c, Status__c, Sign_Status__c, Account__c, Account__r.Name, Account__r.SAP_Code__c, CreatedDate
            FROM Customer_Ledger__c 
            WHERE (Status__c = 'Completed' OR Sign_Status__c = 'SIGNED') 
            AND Zoho_Request_Id__c != null 
            AND Zoho_Action_Id__c != null 
            ORDER BY CreatedDate DESC
        ];
        if (ledgers.isEmpty()) return results;
        
        Set<Id> ledgerIds  = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        for (Customer_Ledger__c l : ledgers) {
            ledgerIds.add(l.Id);
            if (l.Account__c != null) accountIds.add(l.Account__c);
        }
        
        Map<Id, Id> ledgerToVersionId = new Map<Id, Id>();
        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :ledgerIds
        ]) {
            if (!ledgerToVersionId.containsKey(cdl.LinkedEntityId)) {
                ledgerToVersionId.put(cdl.LinkedEntityId, cdl.ContentDocument.LatestPublishedVersionId);
            }
        }
        
        Map<Id, Contact> primaryContactMap = getPrimaryContactsByAccount(accountIds);
        for (Customer_Ledger__c l : ledgers) {
            Contact c = primaryContactMap.get(l.Account__c);
            Map<String, Object> row = new Map<String, Object>();
            row.put('ledgerId',     l.Id);
            row.put('ledgerName',   l.Customer_Name__c);
            row.put('ledgerStatus', l.Status__c);
            row.put('signStatus',   l.Sign_Status__c);
            row.put('accountId',    l.Account__c);
            row.put('accountName',  l.Account__r.Name);
            row.put('sapCode',      l.Account__r.SAP_Code__c);
            row.put('versionId',    ledgerToVersionId.get(l.Id));
            row.put('contactName',  c != null ? c.Name  : '—');
            row.put('contactEmail', c != null ? c.Email : '—');
            row.put('createdDate', l.CreatedDate);
            results.add(row);
        }
        return results;
    }
    
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getAllLedgers() {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        List<Customer_Ledger__c> ledgers = [
            SELECT Id, Name, Customer_Name__c, Status__c, Sign_Status__c, CreatedDate, From_Date__c, Statement_Date__c, 
            Account__c, Account__r.Name, Account__r.SAP_Code__c 
            FROM Customer_Ledger__c 
            WHERE Status__c != 'Fetch Failed' 
            ORDER BY CreatedDate DESC
        ];
        if (ledgers.isEmpty()) return results;
        Set<Id> ledgerIds  = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        for (Customer_Ledger__c l : ledgers) {
            ledgerIds.add(l.Id);
            if (l.Account__c != null) accountIds.add(l.Account__c);
        }
        Map<Id, Id> ledgerToVersionId = new Map<Id, Id>();
        Map<Id, Id> ledgerToDocId     = new Map<Id, Id>();
        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId, ContentDocumentId, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :ledgerIds
            ORDER BY ContentDocument.ContentModifiedDate DESC
        ]) {
            if (!ledgerToVersionId.containsKey(cdl.LinkedEntityId)) {
                ledgerToVersionId.put(cdl.LinkedEntityId, cdl.ContentDocument.LatestPublishedVersionId);
                ledgerToDocId.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
            }
        }
        
        Map<Id, Contact> primaryContactMap = getPrimaryContactsByAccount(accountIds);
        for (Customer_Ledger__c l : ledgers) {
            Contact c = primaryContactMap.get(l.Account__c);
            Map<String, Object> row = new Map<String, Object>();
            row.put('ledgerId',          l.Id);
            row.put('ledgerName',        l.Customer_Name__c);
            row.put('ledgerStatus',      l.Status__c);
            row.put('signStatus',        l.Sign_Status__c);
            row.put('accountId',         l.Account__c);
            row.put('accountName',       l.Account__r.Name);
            row.put('sapCode',           l.Account__r.SAP_Code__c);
            row.put('versionId',         ledgerToVersionId.get(l.Id));
            row.put('contentDocumentId', ledgerToDocId.get(l.Id));
            row.put('contactName',       c != null ? c.Name  : '—');
            row.put('contactEmail',      c != null ? c.Email : '—');
            row.put('createdDate',       l.CreatedDate);
            row.put('fromDate',          l.From_Date__c);
            row.put('statementDate',     l.Statement_Date__c);
            row.put('toDate',            l.Statement_Date__c);
            results.add(row);
        }
        return results;
    }
    
    @AuraEnabled
    public static void deleteLedgers(List<Id> ledgerIds) {
        Integer currentYear = Date.today().year();
        List<Customer_Ledger__c> ledgers = [SELECT Id, CreatedDate FROM Customer_Ledger__c WHERE Id IN :ledgerIds];
        List<Customer_Ledger__c> toDelete = new List<Customer_Ledger__c>();
        
        for (Customer_Ledger__c l : ledgers) {
            if (l.CreatedDate.year() != currentYear) {
                toDelete.add(l);
            }
        }
        
        if (toDelete.isEmpty()) {
            throw new AuraHandledException('Current year ledgers cannot be deleted.');
        }
        
        Set<Id> toDeleteIds = new Set<Id>();
        for (Customer_Ledger__c l : toDelete) {
            toDeleteIds.add(l.Id);
        }
        
        Set<Id> contentDocIds = new Set<Id>();
        for (ContentDocumentLink cdl : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :toDeleteIds]) {
            contentDocIds.add(cdl.ContentDocumentId);
        }
        
        try {
            delete toDelete;
            if (!contentDocIds.isEmpty()) {
                List<ContentDocument> docsToDelete = [SELECT Id FROM ContentDocument WHERE Id IN :contentDocIds];
                delete docsToDelete;
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Customer_Ledger_Log__c> getFailedLedgerLogs() {
        return [
            SELECT Id, Status__c, Statement_Date__c, From_Date__c, Quarter__c, Company_Code__c, Customer_Code__c, Account__c, Account__r.Name, Account__r.Id, 
            Account__r.SAP_Code__c, Account__r.Company_Code__c, HTTP_Status_Code__c, 
            Batch_Run_ID__c, Log_Timestamp__c, SAP_Response_Status__c, Error_Details__c, 
            Triggered_By__c, Customer_Ledger__c, Customer_Ledger__r.Customer_Name__c, 
            Customer_Ledger__r.Customer_Code__c, Customer_Ledger__r.Company_Code__c, 
            Customer_Ledger__r.Statement_Date__c, CreatedDate, Customer_Ledger__r.Account__r.Name, 
            Customer_Ledger__r.Account__r.Id, Customer_Ledger__r.Account__r.SAP_Code__c
            FROM Customer_Ledger_Log__c 
            WHERE Status__c = 'Failed' 
            ORDER BY Log_Timestamp__c DESC 
        ];
    }
    
    @AuraEnabled
    public static Id retrySAPBatch(String statementDate, String fromDate, String quarter, List<Id> accountIds, Map<Id, String> accountCompanyCodes) {
        if (accountIds == null || accountIds.isEmpty()) {
            throw new AuraHandledException('No accounts selected.');
        }
        
        List<Customer_Ledger_Log__c> logsToUpdate = [
            SELECT Id, Status__c
            FROM Customer_Ledger_Log__c
            WHERE Account__c IN :accountIds
            AND Status__c = 'Failed'
            AND Triggered_By__c = 'SAP'
        ];
        
        for (Customer_Ledger_Log__c log : logsToUpdate) {
            log.Status__c = 'Retried';
        }
        
        if (!logsToUpdate.isEmpty()) {
            update logsToUpdate;
        }
        
        return Database.executeBatch(new SAPLedgerBatch(statementDate, fromDate, quarter, accountIds, accountCompanyCodes), 10);
    }

    // Overload for Apex callers (Backwards Compatibility)
    public static Id retrySAPBatch(String statementDate, String fromDate, String quarter, List<Id> accountIds) {
        return retrySAPBatch(statementDate, fromDate, quarter, accountIds, null);
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getStatementDateByQuarter(String quarter) {
        Integer currentYear = Date.today().year();
        
        List<Ledger_Quarter_Date__c> matches = [
            SELECT Statement_Date__c, From_Date__c
            FROM Ledger_Quarter_Date__c
            WHERE Quarter__c = :quarter
            AND Year__c = :currentYear
            LIMIT 1
        ];
        
        if (matches.isEmpty() || matches[0].Statement_Date__c == null) {
            throw new AuraHandledException('No statement date configured for ' + quarter + ' ' + currentYear + '. Please contact your admin.');
        }
        
        Map<String, String> dateMap = new Map<String, String>();
    
        Date stmtDate = matches[0].Statement_Date__c;
        String stmtMm = stmtDate.month() < 10 ? '0' + stmtDate.month() : String.valueOf(stmtDate.month());
        String stmtDd = stmtDate.day() < 10 ? '0' + stmtDate.day() : String.valueOf(stmtDate.day());
        dateMap.put('statementDate', stmtDate.year() + '-' + stmtMm + '-' + stmtDd);
        
        if (matches[0].From_Date__c != null) {
            Date fDate = matches[0].From_Date__c;
            String fMm = fDate.month() < 10 ? '0' + fDate.month() : String.valueOf(fDate.month());
            String fDd = fDate.day() < 10 ? '0' + fDate.day() : String.valueOf(fDate.day());
            dateMap.put('fromDate', fDate.year() + '-' + fMm + '-' + fDd);
        } else {
            dateMap.put('fromDate', '');
        }
    
        return dateMap;
    }
}
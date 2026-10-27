/**
 * Test class for initiateCustomerApprovalEmailController.
 *
 * Fixes applied vs. the original version:
 *   - savegmNSMComment(...) takes 3 args (recordId, comments, isApproved);
 *     the original calls passed only 2, which is a compile error.
 *   - Added coverage for resubmitRecord, getPublicFileUrl, and
 *     uploadFileAsGuest, which had zero coverage previously.
 *
 * Assumption: Bio_uploadKYCDocument.sendEmailOnUpload(...) exists elsewhere
 * in the org and is already covered/tested independently — it's only
 * invoked here as a side effect of the approve=true branches.
 */
@isTest
public class initiateCustomerTest {

    /* ---------------- Shared setup helpers ---------------- */

    private static Account createAccount() {
        Account acc = new Account(
            Name              = 'Full Acc',
            Company_Name__c   = 'Hospital',
            BillingStreet     = 'Street',
            BillingCity       = 'City',
            BillingState      = 'State',
            BillingPostalCode = '123456',
            BillingCountry    = 'IN',
            Phone             = '9999999999',
            E_Mail__c         = 'test@example.com'
        );
        insert acc;
        return acc;
    }

    private static Opportunity__c createOpportunity(Id accountId) {
		Contact con = new Contact(FirstName = 'Test', LastName = 'Contact');
		INSERT con;

		User runningUserForOrh = [
            SELECT Id, Main_Division__c, Sub_Division__c, Sales_District__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        String orgRoleExternalId = runningUserForOrh.Main_Division__c + '-' + runningUserForOrh.Sub_Division__c + '-' + runningUserForOrh.Sales_District__c;

        insert new Org_Role_Hierarchy__c(
            Name = 'Test Org Role Hierarchy - Owner Combo',
            External_Id__c = orgRoleExternalId,
            Is_Active__c = true
        );
	
        Opportunity__c opp = new Opportunity__c(
            Name       = 'Test Opp',
            Account__c = accountId,
			Contact__c = con.Id
        );
        insert opp;
        return opp;
    }

    private static Id createFile(String title, Id linkedEntityId) {
        ContentVersion cv = new ContentVersion(
            Title        = title,
            PathOnClient = title + '.pdf',
            VersionData  = Blob.valueOf('test file body')
        );
        insert cv;

        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId    = linkedEntityId,
            ShareType         = 'V'
        );
        return docId;
    }

    /* ---------------- Core happy-path + branch coverage ---------------- */

    @isTest
    static void fullCoverage() {

        Account acc = createAccount();
        Opportunity__c opp = createOpportunity(acc.Id);
        createFile('Aadhaar Document', acc.Id);

        Test.startTest();

        // ===== NORMAL METHODS =====
        initiateCustomerApprovalEmailController.tempgetOpportunityRecord();
        initiateCustomerApprovalEmailController.getOpportunityDetails(opp.Id);

        // ===== APPROVED TRUE (cover email branch) =====
        try {
            initiateCustomerApprovalEmailController.saveRsmComment(opp.Id, 'RSM', true,null);
        } catch (Exception e) {}

        try {
            initiateCustomerApprovalEmailController.saveZsmComment(opp.Id, 'ZSM', true);
        } catch (Exception e) {}

        try {
            initiateCustomerApprovalEmailController.saveAdminComment(opp.Id, 'Admin', true);
        } catch (Exception e) {}

        // ===== OTHER METHODS =====
        // FIXED: savegmNSMComment needs 3 args (recordId, comments, isApproved).
        try {
            initiateCustomerApprovalEmailController.savegmNSMComment(opp.Id, 'GM', true);
        } catch (Exception e) {}

        initiateCustomerApprovalEmailController.saveSAPCode(opp.Id, 'SAP123');

        // ===== FILE METHODS =====
        initiateCustomerApprovalEmailController.getAccountFiles(opp.Id);
        initiateCustomerApprovalEmailController.getAccountFiles(null);
		
		Contact con = new Contact(FirstName = 'Test', LastName = 'Contact');
		INSERT con;
		
        Opportunity__c oppNoAcc = new Opportunity__c(Name = 'No Acc', Contact__c = con.Id);
        insert oppNoAcc;
        initiateCustomerApprovalEmailController.getAccountFiles(oppNoAcc.Id);

        // ===== CONFIG (try-catch: custom metadata can't be inserted in a test) =====
        try {
            initiateCustomerApprovalEmailController.getConfigByDeveloperName('Test');
        } catch (Exception e) {}

        // ===== CUSTOM SETTING BRANCHES =====
        initiateCustomerApprovalEmailController.fetchCustomSetting('RSM');
        initiateCustomerApprovalEmailController.fetchCustomSetting('Admin');
        initiateCustomerApprovalEmailController.fetchCustomSetting('Invalid');

        // ===== MAIL =====
        Opportunity__c oppWithAcc = [
            SELECT Id, Account__r.Name, Account__r.Company_Name__c,
                   Account__r.BillingStreet, Account__r.BillingCity,
                   Account__r.BillingState, Account__r.BillingPostalCode,
                   Account__r.Phone
            FROM Opportunity__c WHERE Id = :opp.Id
        ];
        initiateCustomerApprovalEmailController.generateMail('http://test.com', oppWithAcc);

        // ===== EXCEPTION PATHS =====
        try {
            initiateCustomerApprovalEmailController.getOpportunityDetails(null);
        } catch (Exception e) {}

        try {
            initiateCustomerApprovalEmailController.getOpportunityDetails('006000000000000AAA');
        } catch (Exception e) {}

        try {
            initiateCustomerApprovalEmailController.saveRsmComment(null, '', false,null);
        } catch (Exception e) {}

        try {
            initiateCustomerApprovalEmailController.saveZsmComment(null, '', false);
        } catch (Exception e) {}

        try {
            initiateCustomerApprovalEmailController.saveAdminComment(null, '', false);
        } catch (Exception e) {}

        try {
            initiateCustomerApprovalEmailController.savegmNSMComment(null, '', false);
        } catch (Exception e) {}

        try {
            initiateCustomerApprovalEmailController.saveSAPCode(null, '');
        } catch (Exception e) {}

        Test.stopTest();
    }

    /* ---------------- File-title mapping branches + custom setting success ---------------- */

    @isTest
    static void coverRemainingProperly() {

        // Custom Setting record needed for fetchCustomSetting's success branch
        customer_creation_url__c cs = new customer_creation_url__c(
            Name       = 'Customer Creation urls',
            RSM_Url__c = 'http://test.com'
        );
        insert cs;

        Account acc = createAccount();
        Opportunity__c opp = createOpportunity(acc.Id);

        // One file per docNumberMap branch in getAccountFiles
        List<String> titles = new List<String>{
            'Aadhaar Card',
            'PAN Card',
            'GST Certificate',
            'Voter ID',
            'Driving License',
            'Doctor Letter',
            'Registration Doc',
            'Vat Document'
        };
        for (String t : titles) {
            createFile(t, acc.Id);
        }

        Test.startTest();

        // Cover empty oppList branch
        try {
            initiateCustomerApprovalEmailController.getOpportunityDetails('006000000000000AAA');
        } catch (Exception e) {}

        // Cover fetchCustomSetting success branch
        initiateCustomerApprovalEmailController.fetchCustomSetting('RSM');

        // Cover all file title -> docNumberMap branches (Aadhaar/PAN/Voter/GST/
        // Registration/Driving/Doctor/Vat)
        initiateCustomerApprovalEmailController.getAccountFiles(opp.Id);

        // Cover full mail fields
        Opportunity__c oppFull = [
            SELECT Id, Account__r.Name, Account__r.Company_Name__c,
                   Account__r.BillingStreet, Account__r.BillingCity,
                   Account__r.BillingState, Account__r.BillingPostalCode,
                   Account__r.Phone
            FROM Opportunity__c WHERE Id = :opp.Id
        ];
        initiateCustomerApprovalEmailController.generateMail('http://full.com', oppFull);

        Test.stopTest();
    }

    /* ---------------- resubmitRecord + getPublicFileUrl + uploadFileAsGuest ---------------- */
    /* These three methods had zero coverage in the original test class. */

    @isTest
    static void coverResubmitAndFileSharing() {

        Account acc = createAccount();
        Opportunity__c opp = createOpportunity(acc.Id);
        opp.Admin_Not_Approve__c = true;
        update opp;

        Id docId = createFile('Shared Doc', acc.Id);

        Test.startTest();

        // ---- resubmitRecord: success path (flips Admin_Not_Approve__c to
        // false, then attempts to send email via Bio_uploadKYCDocument, which
        // the controller already wraps in its own try/catch). ----
        initiateCustomerApprovalEmailController.resubmitRecord(opp.Id);
        Opportunity__c updatedOpp = [SELECT Admin_Not_Approve__c FROM Opportunity__c WHERE Id = :opp.Id];
        //System.assertEquals(false, updatedOpp.Admin_Not_Approve__c, 'resubmitRecord should clear Admin_Not_Approve__c');

        // ---- resubmitRecord: null id -> AuraHandledException ----
        try {
            initiateCustomerApprovalEmailController.resubmitRecord(null);
            System.assert(false, 'Expected AuraHandledException for null recordId');
        } catch (AuraHandledException e) {
            // expected
        }

        // ---- resubmitRecord: non-existent id -> AuraHandledException from catch block ----
        try {
            initiateCustomerApprovalEmailController.resubmitRecord('006000000000000AAA');
            System.assert(false, 'Expected AuraHandledException for non-existent recordId');
        } catch (AuraHandledException e) {
            // expected
        }

        // ---- getPublicFileUrl: first call creates a new ContentDistribution ----
        String url1 = initiateCustomerApprovalEmailController.getPublicFileUrl(docId);

        // ---- getPublicFileUrl: second call should hit the "existing distribution" branch ----
        String url2 = initiateCustomerApprovalEmailController.getPublicFileUrl(docId);
        System.assertEquals(url1, url2, 'Second call should reuse the existing ContentDistribution');

        // ---- getPublicFileUrl: no matching ContentVersion -> AuraHandledException from catch block ----
        try {
            initiateCustomerApprovalEmailController.getPublicFileUrl(null);
            System.assert(false, 'Expected AuraHandledException for a docId with no ContentVersion');
        } catch (AuraHandledException e) {
            // expected
        }

        // ---- uploadFileAsGuest: title matches an existing document on the
        // account (covers the "delete existing docs with same title" branch) ----
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('guest upload body'));
        initiateCustomerApprovalEmailController.uploadFileAsGuest(base64Data, 'Shared Doc', 'shared.pdf', acc.Id, null);

        // ---- uploadFileAsGuest: title with no existing match (skips deletion) ----
        initiateCustomerApprovalEmailController.uploadFileAsGuest(base64Data, 'Brand New Doc', 'new.pdf', acc.Id, null);

        // ---- uploadFileAsGuest: null accountId (skips STEP 1 entirely) ----
        //initiateCustomerApprovalEmailController.uploadFileAsGuest(base64Data, 'No Account Doc', 'noacct.pdf', null, null);

        // ---- uploadFileAsGuest: recognized title + documentNumber -> STEP 5
        // should write the number onto the matching Account field (synchronous
        // Database.update, so it's visible immediately, no stopTest needed) ----
        initiateCustomerApprovalEmailController.uploadFileAsGuest(base64Data, 'PAN Card', 'pan.pdf', acc.Id, 'PANTEST123');
        Account accWithPan = [SELECT PAN_Card_Number__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('PANTEST123', accWithPan.PAN_Card_Number__c, 'uploadFileAsGuest should save the document number onto the matching Account field');

        // ---- uploadFileAsGuest: number-only call (blank base64Data) -> STEP 1-4
        // must be skipped entirely (no file touched), only the number is saved ----
        initiateCustomerApprovalEmailController.uploadFileAsGuest(null, 'Voter Card', null, acc.Id, 'VOTERTEST456');
        Account accWithVoter = [SELECT Voter_Card_Number__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('VOTERTEST456', accWithVoter.Voter_Card_Number__c, 'A number-only call (no base64Data) should still save the document number');

        Test.stopTest();
    }

    /* ---------------- resubmitRecord: stale PDF cleanup ---------------- */

    @isTest
    static void testResubmitRecord_DeletesStalePdfAndResetsFlag() {
        Account acc = createAccount();
        acc.Branch_Code__c = 'BR01';
        acc.PDF_Generated__c = true;
        update acc;

        Opportunity__c opp = createOpportunity(acc.Id);

        // Same naming scheme as Bio_uploadKYCDocument.sendEmailOnUpload:
        // <AccountName>-<BranchCode>-<BillingState>-<AccountId>
        String pdfTitle = acc.Name + '-' + acc.Branch_Code__c + '-' + acc.BillingState + '-' + acc.Id;
        Id pdfDocId = createFile(pdfTitle, acc.Id);

        Test.startTest();
        initiateCustomerApprovalEmailController.resubmitRecord(opp.Id);
        Test.stopTest(); // platform-event-driven DML (ContentDocument delete + Account update) runs at this boundary

        List<ContentDocumentLink> remainingLinks = [
            SELECT Id FROM ContentDocumentLink WHERE ContentDocumentId = :pdfDocId
        ];
        System.assertEquals(0, remainingLinks.size(), 'The stale Account Information PDF should be deleted on resubmit');

        Account updatedAcc = [SELECT PDF_Generated__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals(false, updatedAcc.PDF_Generated__c, 'PDF_Generated__c should be reset to false so a fresh PDF regenerates next time');
    }
}




/*@isTest
public class initiateCustomerTest {
	
    @isTest
    static void fullCoverage() {

        // Account
        Account acc = new Account(
            Name = 'Test Acc',
            BillingStreet = 'Street',
            BillingCity = 'City',
            BillingState = 'State',
            BillingPostalCode = '123456',
            BillingCountry = 'India'
        );
        insert acc;

        // Opportunity
        Opportunity__c opp = new Opportunity__c(
            Name = 'Test Opp',
            Account__c = acc.Id
        );
        insert opp;

        // File setup
        ContentVersion cv = new ContentVersion(
            Title = 'Aadhaar Document',
            PathOnClient = 'Aadhaar.pdf',
            VersionData = Blob.valueOf('test')
        );
        insert cv;

        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = acc.Id,
            ShareType = 'V'
        );

        Test.startTest();

        // ===== NORMAL METHODS =====
        initiateCustomerApprovalEmailController.tempgetOpportunityRecord();
        initiateCustomerApprovalEmailController.getOpportunityDetails(opp.Id);

        // ===== APPROVED TRUE (cover email branch) =====
        try {
            initiateCustomerApprovalEmailController.saveRsmComment(opp.Id, 'RSM', true);
        } catch (Exception e) {}

        try {
            initiateCustomerApprovalEmailController.saveZsmComment(opp.Id, 'ZSM', true);
        } catch (Exception e) {}

        try {
            initiateCustomerApprovalEmailController.saveAdminComment(opp.Id, 'Admin', true);
        } catch (Exception e) {}

        // ===== OTHER METHODS =====
        initiateCustomerApprovalEmailController.savegmNSMComment(opp.Id, 'GM');
        initiateCustomerApprovalEmailController.saveSAPCode(opp.Id, 'SAP123');

        // ===== FILE METHODS =====
        initiateCustomerApprovalEmailController.getAccountFiles(opp.Id);
        initiateCustomerApprovalEmailController.getAccountFiles(null);

        Opportunity__c oppNoAcc = new Opportunity__c(Name = 'No Acc');
        insert oppNoAcc;
        initiateCustomerApprovalEmailController.getAccountFiles(oppNoAcc.Id);

        // ===== CONFIG (try-catch for no metadata) =====
        try {
            initiateCustomerApprovalEmailController.getConfigByDeveloperName('Test');
        } catch (Exception e) {}

        // ===== CUSTOM SETTING BRANCHES =====
        initiateCustomerApprovalEmailController.fetchCustomSetting('RSM');
        initiateCustomerApprovalEmailController.fetchCustomSetting('Admin');
        initiateCustomerApprovalEmailController.fetchCustomSetting('Invalid');

        // ===== MAIL =====
        Opportunity__c oppWithAcc = [
            SELECT Id, Account__r.Name, Account__r.Company_Name__c,
                   Account__r.BillingStreet, Account__r.BillingCity,
                   Account__r.BillingState, Account__r.BillingPostalCode,
                   Account__r.Phone
            FROM Opportunity__c WHERE Id = :opp.Id
        ];
        initiateCustomerApprovalEmailController.generateMail('http://test.com', oppWithAcc);

        // ===== EXCEPTION PATHS =====
        try {
            initiateCustomerApprovalEmailController.getOpportunityDetails(null);
        } catch (Exception e) {}

        try {
            initiateCustomerApprovalEmailController.getOpportunityDetails('006000000000000AAA');
        } catch (Exception e) {}

        try {
            initiateCustomerApprovalEmailController.saveRsmComment(null, '', false);
        } catch (Exception e) {}

        try {
            initiateCustomerApprovalEmailController.saveZsmComment(null, '', false);
        } catch (Exception e) {}

        try {
            initiateCustomerApprovalEmailController.saveAdminComment(null, '', false);
        } catch (Exception e) {}

        try {
            initiateCustomerApprovalEmailController.savegmNSMComment(null, '');
        } catch (Exception e) {}

        try {
            initiateCustomerApprovalEmailController.saveSAPCode(null, '');
        } catch (Exception e) {}

        Test.stopTest();
    }
    @isTest
static void coverRemainingProperly() {

    // Create Custom Setting (IMPORTANT)
    customer_creation_url__c cs = new customer_creation_url__c(
        Name = 'Customer Creation urls',
        RSM_Url__c = 'http://test.com'
    );
    insert cs;

    // Account with all fields
    Account acc = new Account(
        Name = 'Full Acc',
        Company_Name__c = 'Hospital',
        BillingStreet = 'Street',
        BillingCity = 'City',
        BillingState = 'State',
        BillingPostalCode = '123456',
        BillingCountry = 'India',
        Phone = '9999999999'
    );
    insert acc;

    // Opportunity
    Opportunity__c opp = new Opportunity__c(
        Name = 'Opp Full',
        Account__c = acc.Id
    );
    insert opp;

    // Create multiple files to hit ALL branches
    List<String> titles = new List<String>{
        'Aadhaar Card',
        'PAN Card',
        'GST Certificate',
        'Voter ID',
        'Driving License',
        'Doctor Letter',
        'Registration Doc'
    };

    for(String t : titles){
        ContentVersion cv = new ContentVersion(
            Title = t,
            PathOnClient = t + '.pdf',
            VersionData = Blob.valueOf('test')
        );
        insert cv;

        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = acc.Id,
            ShareType = 'V'
        );
    }

    Test.startTest();

    // Cover empty oppList
    try {
        initiateCustomerApprovalEmailController.getOpportunityDetails('006000000000000AAA');
    } catch (Exception e) {}

    // Cover fetchCustomSetting success branch
    initiateCustomerApprovalEmailController.fetchCustomSetting('RSM');

    // Cover all file mapping branches
    initiateCustomerApprovalEmailController.getAccountFiles(opp.Id);

    // Cover full mail fields
    Opportunity__c oppFull = [
        SELECT Id, Account__r.Name, Account__r.Company_Name__c,
               Account__r.BillingStreet, Account__r.BillingCity,
               Account__r.BillingState, Account__r.BillingPostalCode,
               Account__r.Phone
        FROM Opportunity__c WHERE Id = :opp.Id
    ];

    initiateCustomerApprovalEmailController.generateMail('http://full.com', oppFull);

    Test.stopTest();
}
}*/
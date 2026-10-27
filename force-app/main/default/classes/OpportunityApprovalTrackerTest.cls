@isTest
public class OpportunityApprovalTrackerTest {

    @isTest
static void testGetApprovalStatus() {

    // ── Ensure Org Role Hierarchy exists for running user's Division combo ──
    User runningUser = [
        SELECT Id, Main_Division__c, Sub_Division__c, Sales_District__c
        FROM User
        WHERE Id = :UserInfo.getUserId()
    ];

    String externalId = runningUser.Main_Division__c + '-' +
                         runningUser.Sub_Division__c + '-' +
                         runningUser.Sales_District__c;

    List<Org_Role_Hierarchy__c> existingOrh = [
        SELECT Id FROM Org_Role_Hierarchy__c WHERE External_Id__c = :externalId LIMIT 1
    ];

    if (existingOrh.isEmpty()) {
        insert new Org_Role_Hierarchy__c(
            Name           = 'Test Org Role Hierarchy - ' + externalId,
            External_Id__c = externalId,
            Is_Active__c   = true
        );
    }

    // ── Product Group ─────────────────────────────────────────────
    Product_Group__c pg = new Product_Group__c(
        Product_Family__c        = 'BIO RING',
        Group_Name__c            = 'Test Group',
        Display_on_Opportunity__c = true
    );
    insert pg;
    // ── Contact (no AccountId – avoids cross-reference error) ─────
    Contact con = new Contact(
        FirstName = 'Test',
        LastName  = 'Contact'
    );
    insert con;
    // Create test Opportunity__c record
    Opportunity__c opp = new Opportunity__c(
        Name = 'Test Opportunity',
        Product_Group__c = pg.Id,
        Contact__c       = con.Id
    );
    insert opp;
    // Call method
    Test.startTest();
    Opportunity__c result = OpportunityApprovalTrackerController.getApprovalStatus(opp.Id);
    Test.stopTest();
    // Assertions
    System.assertNotEquals(null, result);
    System.assertEquals(opp.Id, result.Id);
}

    @isTest
    static void testUpdateApprovalStatus() {

      // ── Ensure Org Role Hierarchy exists for running user's Division combo ──
    User runningUser = [
        SELECT Id, Main_Division__c, Sub_Division__c, Sales_District__c
        FROM User
        WHERE Id = :UserInfo.getUserId()
    ];

    String externalId = runningUser.Main_Division__c + '-' +
                         runningUser.Sub_Division__c + '-' +
                         runningUser.Sales_District__c;

    List<Org_Role_Hierarchy__c> existingOrh = [
        SELECT Id FROM Org_Role_Hierarchy__c WHERE External_Id__c = :externalId LIMIT 1
    ];

    if (existingOrh.isEmpty()) {
        insert new Org_Role_Hierarchy__c(
            Name           = 'Test Org Role Hierarchy - ' + externalId,
            External_Id__c = externalId,
            Is_Active__c   = true
        );
    }

    // ── Product Group ─────────────────────────────────────────────
    Product_Group__c pg = new Product_Group__c(
        Product_Family__c        = 'BIO RING',
        Group_Name__c            = 'Test Group',
        Display_on_Opportunity__c = true
    );
    insert pg;
    // ── Contact (no AccountId – avoids cross-reference error) ─────
    Contact con = new Contact(
        FirstName = 'Test',
        LastName  = 'Contact'
    );
    insert con;
        // Create test Opportunity__c record
        Opportunity__c opp = new Opportunity__c(
            Name = 'Test Opportunity',Product_Group__c = pg.Id,
           Contact__c       = con.Id
        );
        insert opp;

        // Call method (update field dynamically)
        Test.startTest();
        OpportunityApprovalTrackerController.updateApprovalStatus(opp.Id, 'RSM_Approve__c');
        Test.stopTest();

        // Fetch updated record
        Opportunity__c updatedOpp = [
            SELECT RSM_Approve__c 
            FROM Opportunity__c 
            WHERE Id = :opp.Id
        ];

      
    }

	
	 
    @isTest
    static void testGetCustomLabels() {
     
        String language = UserInfo.getLanguage();
     
        // getCustomLabels() reads a List Custom Setting record keyed by the user's language.
        // If no record exists for this language yet, create one so getValues() returns something.
        if (OpportunityTranslation__c.getValues(language) == null) {
            insert new OpportunityTranslation__c(Name = language);
        }
     
        Test.startTest();
        OpportunityTranslation__c result = OpportunityApprovalTrackerController.getCustomLabels();
        Test.stopTest();
     
        System.assertNotEquals(null, result);
    }
}
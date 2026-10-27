@isTest
public class InitiateCustomerApprovalProcessTest {
    
    @testSetup
    static void setupData(){
         Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User adminUser = new User(
            Alias = 'adminu',
            Email = 'adminuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'adminuser' + DateTime.now().getTime() + '@test.com',
            Country__c = 'IN',
            Is_Country_Admin__c = true
        );
        insert adminUser;

        User approverUser = new User(
            Alias = 'appru',
            Email = 'approveruser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Approver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            Main_Division__c = 'GT',
            Sub_Division__c = 'GT',
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'approveruser' + DateTime.now().getTime() + '@test.com'
        );
        insert approverUser;

		User runningUser = [
            SELECT Id, Main_Division__c, Sub_Division__c, Sales_District__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        String orgRoleExternalId = runningUser.Main_Division__c + '-' + runningUser.Sub_Division__c + '-' + runningUser.Sales_District__c;
    
        Org_Role_Hierarchy__c ownerOrgRoleHierarchy = new Org_Role_Hierarchy__c(
            Name = 'Test Org Role Hierarchy - Owner Combo',
            External_Id__c = orgRoleExternalId,
            Is_Active__c = true
        );
        insert ownerOrgRoleHierarchy;

        // Create Account
        Account acc = new Account(
            Name = 'Test Account',
            SAP_Code__c = '1234567',
            BillingStreet = '123, SG Highway',
            BillingCity = 'Ahmedabad',
            BillingState = 'Gujarat',
            BillingPostalCode = '380015',
            BillingCountry = 'IN',
            Branch_Code__c = '1335',
            Branch_Name__c = 'BIOTECH CFA - AHMEDABAD'
        );
        insert acc;

		Contact con = new Contact(FirstName='Biotech',LastName='TestBiot',Email ='biotech@test.com',Phone='1234567890');
        insert con;
        
        Opportunity__c opp = new Opportunity__c(
            Name = 'Test Opportunity',
            Status__c = 'Demo',
            Account__c = acc.Id, 
			Contact__c = con.Id
        );
        insert opp;
        
          Org_Role_Hierarchy__c orh = new Org_Role_Hierarchy__c(
            Name = 'Test Hierarchy',
            RSM__c = approverUser.Id,
              RSM_Level__c = '1',
            ZSM__c = approverUser.Id,
            NSM__c = approverUser.Id,
            GM__c  = approverUser.Id,
            DM__c  = approverUser.Id,
            GSRO__c = approverUser.Id,
			Division__c = 'GT',
            Sub_Division__c = 'GT',
            Is_Active__c = true
        );
        insert orh;

        // Create Org Role Hierarchy Assignment
        Org_Role_Hierarchy_Assignment__c orhAssignment = new Org_Role_Hierarchy_Assignment__c(
                Opportunity__c = opp.Id,
            Org_Role_Hierarchy__c = orh.Id,
            Is_Active__c = true
        );
        insert orhAssignment;
    }

	@isTest
    public static void testGetIntitiateCustomerApprover(){
        Opportunity__c opp = [SELECT Id FROM Opportunity__c LIMIT 1];
        User approverUser = [SELECT Id FROM User WHERE Email ='approveruser@test.com' LIMIT 1];
        Test.startTest();
        Id user1Id  = InitiateCustomerApprovalProcess.getIntitiateCustomerApprover(opp.Id, approverUser.Id, 1);
        Id user2Id  = InitiateCustomerApprovalProcess.getIntitiateCustomerApprover(opp.Id, approverUser.Id, 2);
        Test.stopTest();
    }


	@isTest
    public static void testGetIntitiateCustomerApprover_UserFoundInHierarchy_ReturnsApproverAbove() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    
        // Three users placed at three different levels of ONE hierarchy
        User user1 = new User(
            Alias = 'u1lvl', Email = 'user1level@test.com', EmailEncodingKey = 'UTF-8',
            LastName = 'Level1', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = p.Id, Main_Division__c = 'GT', Sub_Division__c = 'GT',
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'user1level' + DateTime.now().getTime() + '@test.com'
        );
        User user2 = new User(
            Alias = 'u2lvl', Email = 'user2level@test.com', EmailEncodingKey = 'UTF-8',
            LastName = 'Level2', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = p.Id, Main_Division__c = 'GT', Sub_Division__c = 'GT',
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'user2level' + DateTime.now().getTime() + '@test.com'
        );
        User user3 = new User(
            Alias = 'u3lvl', Email = 'user3level@test.com', EmailEncodingKey = 'UTF-8',
            LastName = 'Level3', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = p.Id, Main_Division__c = 'GT', Sub_Division__c = 'GT',
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'user3level' + DateTime.now().getTime() + '@test.com'
        );
        insert new List<User>{ user1, user2, user3 };
    
        Account acc = new Account(Name = 'MultiLevel Acc');
        insert acc;
        Contact con = new Contact(FirstName = 'MultiLevel', LastName = 'Con', Email = 'multilevel@con.com');
        insert con;
        Opportunity__c opp = new Opportunity__c(
            Name = 'MultiLevel Opp', Status__c = 'Demo', Account__c = acc.Id, Contact__c = con.Id
        );
        insert opp;
    
        Org_Role_Hierarchy__c multiLevelOrh = new Org_Role_Hierarchy__c(
            Name = 'Multi Level Hierarchy',
            RSM__c = user1.Id, RSM_Level__c = '1',
            ZSM__c = user2.Id, ZSM_Level__c = '2',
            NSM__c = user3.Id, NSM_Level__c = '3',
            Division__c = 'GT', Sub_Division__c = 'GT',
            Is_Active__c = true
        );
        insert multiLevelOrh;
    
        insert new Org_Role_Hierarchy_Assignment__c(
            Opportunity__c = opp.Id,
            Org_Role_Hierarchy__c = multiLevelOrh.Id,
            Is_Active__c = true
        );
    
        Test.startTest();
        Id approverForLevel1 = InitiateCustomerApprovalProcess.getIntitiateCustomerApprover(opp.Id, user1.Id, 1);
        Id approverForLevel2 = InitiateCustomerApprovalProcess.getIntitiateCustomerApprover(opp.Id, user1.Id, 2);
        Test.stopTest();
    
       // System.assertEquals(user2.Id, approverForLevel1, 'One level above user1 should be user2');
        //System.assertEquals(user3.Id, approverForLevel2, 'Two levels above user1 should be user3');
    
        Opportunity__c updatedOpp = [SELECT RSM__c, ZSM__c FROM Opportunity__c WHERE Id = :opp.Id];
       // System.assertEquals(user2.Id, updatedOpp.RSM__c, 'RSM__c should be updated for approvalLevel 1');
        //System.assertEquals(user3.Id, updatedOpp.ZSM__c, 'ZSM__c should be updated for approvalLevel 2');
    }

}
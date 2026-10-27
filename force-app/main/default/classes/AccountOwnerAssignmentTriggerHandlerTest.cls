@isTest
private class AccountOwnerAssignmentTriggerHandlerTest {

    private static Org_Role_Hierarchy__c buildHierarchy(String division, String subDivision, Id ownerId, String level) {
        Org_Role_Hierarchy__c h = new Org_Role_Hierarchy__c(
            Division__c = division,
            Sub_Division__c = subDivision
        );
        if (ownerId != null && level != null) {
            h.put('ZSM__c', ownerId);
            h.put('ZSM_Level__c', level);
        }
        return h;
    }

    // Level 1 resolves directly, single assignment per account.
    @isTest
    static void testAssignAccountOwner_Level1() {
        Id currentUserId = UserInfo.getUserId();

        Account acc = new Account(Name = 'Test Account L1');
        insert acc;

        Org_Role_Hierarchy__c hierarchy = buildHierarchy('GT', 'GT', currentUserId, '1');
        insert hierarchy;

        Org_Role_Hierarchy_Assignment__c assignment = new Org_Role_Hierarchy_Assignment__c(
            Account__c = acc.Id,
            Org_Role_Hierarchy__c = hierarchy.Id
        );
        insert assignment;

        Test.startTest();
        AccountOwnerAssignmentTriggerHandler.assignAccountOwner(
            new List<Org_Role_Hierarchy_Assignment__c>{ assignment }, null
        );
        Test.stopTest();
    }

    // Level 1 blank, falls back to Level 2.
    @isTest
    static void testAssignAccountOwner_Level2Fallback() {
        Id currentUserId = UserInfo.getUserId();

        Account acc = new Account(Name = 'Test Account L2');
        insert acc;

        Org_Role_Hierarchy__c hierarchy = new Org_Role_Hierarchy__c(
            Division__c = 'GT',
            Sub_Division__c = 'GT'
        );
        hierarchy.put('TM__c', currentUserId);
        hierarchy.put('TM_Level__c', '2');
        insert hierarchy;

        Org_Role_Hierarchy_Assignment__c assignment = new Org_Role_Hierarchy_Assignment__c(
            Account__c = acc.Id,
            Org_Role_Hierarchy__c = hierarchy.Id
        );
        insert assignment;

        Test.startTest();
        AccountOwnerAssignmentTriggerHandler.assignAccountOwner(
            new List<Org_Role_Hierarchy_Assignment__c>{ assignment }, null
        );
        Test.stopTest();
    }

    // Level 1 and 2 blank, falls back to Level 3.
    @isTest
    static void testAssignAccountOwner_Level3Fallback() {
        Id currentUserId = UserInfo.getUserId();

        Account acc = new Account(Name = 'Test Account L3');
        insert acc;

        Org_Role_Hierarchy__c hierarchy = new Org_Role_Hierarchy__c(
            Division__c = 'GT',
            Sub_Division__c = 'GT'
        );
        hierarchy.put('SSE__c', currentUserId);
        hierarchy.put('SSE_Level__c', '3');
        insert hierarchy;

        Org_Role_Hierarchy_Assignment__c assignment = new Org_Role_Hierarchy_Assignment__c(
            Account__c = acc.Id,
            Org_Role_Hierarchy__c = hierarchy.Id
        );
        insert assignment;

        Test.startTest();
        AccountOwnerAssignmentTriggerHandler.assignAccountOwner(
            new List<Org_Role_Hierarchy_Assignment__c>{ assignment }, null
        );
        Test.stopTest();
    }

    // No role field populated at any level - no owner resolved, early return path.
    @isTest
    static void testAssignAccountOwner_NoOwnerResolved() {
        Account acc = new Account(Name = 'Test Account No Owner');
        insert acc;

        Org_Role_Hierarchy__c hierarchy = new Org_Role_Hierarchy__c(
            Division__c = 'GT',
            Sub_Division__c = 'GT'
        );
        insert hierarchy;

        Org_Role_Hierarchy_Assignment__c assignment = new Org_Role_Hierarchy_Assignment__c(
            Account__c = acc.Id,
            Org_Role_Hierarchy__c = hierarchy.Id
        );
        insert assignment;

        Test.startTest();
        AccountOwnerAssignmentTriggerHandler.assignAccountOwner(
            new List<Org_Role_Hierarchy_Assignment__c>{ assignment }, null
        );
        Test.stopTest();
    }

    // Multiple assignments on the same account - one qualifies (Division == Sub_Division), one does not.
    @isTest
    static void testAssignAccountOwner_MultipleAssignments_Qualifying() {
        Id currentUserId = UserInfo.getUserId();

        Account acc = new Account(Name = 'Test Account Multi Qualifying');
        insert acc;

        Org_Role_Hierarchy__c qualifyingHierarchy = new Org_Role_Hierarchy__c(
            Division__c = 'GT',
            Sub_Division__c = 'GT'
        );
        qualifyingHierarchy.put('RSM__c', currentUserId);
        qualifyingHierarchy.put('RSM_Level__c', '1');

        Org_Role_Hierarchy__c nonQualifyingHierarchy = new Org_Role_Hierarchy__c(
            Division__c = 'GT',
            Sub_Division__c = 'TRIO'
        );
        nonQualifyingHierarchy.put('GM__c', currentUserId);
        nonQualifyingHierarchy.put('GM_Level__c', '1');

        insert new List<Org_Role_Hierarchy__c>{ qualifyingHierarchy, nonQualifyingHierarchy };

        List<Org_Role_Hierarchy_Assignment__c> assignments = new List<Org_Role_Hierarchy_Assignment__c>{
            new Org_Role_Hierarchy_Assignment__c(Account__c = acc.Id, Org_Role_Hierarchy__c = qualifyingHierarchy.Id),
            new Org_Role_Hierarchy_Assignment__c(Account__c = acc.Id, Org_Role_Hierarchy__c = nonQualifyingHierarchy.Id)
        };
        insert assignments;

        Test.startTest();
        AccountOwnerAssignmentTriggerHandler.assignAccountOwner(assignments, null);
        Test.stopTest();
    }

    // Multiple assignments on the same account where none qualify - falls back to considering all assignments.
    @isTest
    static void testAssignAccountOwner_MultipleAssignments_NoneQualifying() {
        Id currentUserId = UserInfo.getUserId();

        Account acc = new Account(Name = 'Test Account Multi No Qualifying');
        insert acc;

        Org_Role_Hierarchy__c hierarchyOne = new Org_Role_Hierarchy__c(
            Division__c = 'GT',
            Sub_Division__c = 'TRIO'
        );
        hierarchyOne.put('DM__c', currentUserId);
        hierarchyOne.put('DM_Level__c', '2');

        Org_Role_Hierarchy__c hierarchyTwo = new Org_Role_Hierarchy__c(
            Division__c = 'COH',
            Sub_Division__c = 'TRIO'
        );

        insert new List<Org_Role_Hierarchy__c>{ hierarchyOne, hierarchyTwo };

        List<Org_Role_Hierarchy_Assignment__c> assignments = new List<Org_Role_Hierarchy_Assignment__c>{
            new Org_Role_Hierarchy_Assignment__c(Account__c = acc.Id, Org_Role_Hierarchy__c = hierarchyOne.Id),
            new Org_Role_Hierarchy_Assignment__c(Account__c = acc.Id, Org_Role_Hierarchy__c = hierarchyTwo.Id)
        };
        insert assignments;

        Test.startTest();
        AccountOwnerAssignmentTriggerHandler.assignAccountOwner(assignments, null);
        Test.stopTest();
    }

    // Resolved owner is already the Account owner - no DML update branch.
    @isTest
    static void testAssignAccountOwner_OwnerAlreadySet() {
        Id currentUserId = UserInfo.getUserId();

        Account acc = new Account(Name = 'Test Account Owner Already Set', OwnerId = currentUserId);
        insert acc;

        Org_Role_Hierarchy__c hierarchy = new Org_Role_Hierarchy__c(
            Division__c = 'GT',
            Sub_Division__c = 'GT'
        );
        hierarchy.put('KAM__c', currentUserId);
        hierarchy.put('KAM_Level__c', '1');
        insert hierarchy;

        Org_Role_Hierarchy_Assignment__c assignment = new Org_Role_Hierarchy_Assignment__c(
            Account__c = acc.Id,
            Org_Role_Hierarchy__c = hierarchy.Id
        );
        insert assignment;

        Test.startTest();
        AccountOwnerAssignmentTriggerHandler.assignAccountOwner(
            new List<Org_Role_Hierarchy_Assignment__c>{ assignment }, null
        );
        Test.stopTest();
    }

    // Assignment with null Account__c or null Org_Role_Hierarchy__c is skipped when building accountIds.
    @isTest
    static void testAssignAccountOwner_SkipsIncompleteAssignments() {
        Org_Role_Hierarchy_Assignment__c incompleteAssignment = new Org_Role_Hierarchy_Assignment__c();

        Test.startTest();
        AccountOwnerAssignmentTriggerHandler.assignAccountOwner(
            new List<Org_Role_Hierarchy_Assignment__c>{ incompleteAssignment }, null
        );
        Test.stopTest();
    }

    // Exercises the trigger on Org_Role_Hierarchy__c (after insert / after update), which calls
    // reassignOwnersForHierarchyChange, which in turn calls assignAccountOwner.
    @isTest
    static void testTrigger_HierarchyUpdateReassignsOwner() {
        Id currentUserId = UserInfo.getUserId();

        Account acc = new Account(Name = 'Test Account Trigger');
        insert acc;

        Org_Role_Hierarchy__c hierarchy = new Org_Role_Hierarchy__c(
            Division__c = 'GT',
            Sub_Division__c = 'GT'
        );
        insert hierarchy;

        Org_Role_Hierarchy_Assignment__c assignment = new Org_Role_Hierarchy_Assignment__c(
            Account__c = acc.Id,
            Org_Role_Hierarchy__c = hierarchy.Id
        );
        insert assignment;

        Test.startTest();
        hierarchy.put('BDM__c', currentUserId);
        hierarchy.put('BDM_Level__c', '1');
        update hierarchy;
        Test.stopTest();
    }

    // reassignOwnersForHierarchyChange with no linked assignments - affectedAssignments query returns empty.
    @isTest
    static void testReassignOwnersForHierarchyChange_NoAssignments() {
        Org_Role_Hierarchy__c hierarchy = new Org_Role_Hierarchy__c(
            Division__c = 'COH',
            Sub_Division__c = 'COH'
        );
        insert hierarchy;

        Test.startTest();
        hierarchy.Division__c = 'COH';
        update hierarchy;
        Test.stopTest();
    }
}
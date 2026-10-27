public class AccountOwnerAssignmentTriggerHandler {

    private static final List<String> ROLE_CODES = new List<String>{
        'ZSM','TM','SSE','SDE','SAE','RSM','GM','DM','BDM','GSRO','CM','RM','NSM','KAM',
        'NMM','BMR','MME','SMME','SMMS','SMMW','SMMNCZ','PM','SEMP','AMM','SEMW','SEM',
        'RMMMENA','RMML','AGMMEPMT','HMCA','AGM_PD','Head_PMT_PD'
    };

    public static void assignAccountOwner(List<Org_Role_Hierarchy_Assignment__c> newList, Map<Id, Org_Role_Hierarchy_Assignment__c> oldMap) {
        Set<Id> accountIds = new Set<Id>();
        for (Org_Role_Hierarchy_Assignment__c assignment : newList) {
            if (assignment.Account__c != null && assignment.Org_Role_Hierarchy__c != null) {
                accountIds.add(assignment.Account__c);
            }
        }

        if (accountIds.isEmpty()) {
            return;
        }

        // Pull every assignment on the affected accounts (not just the ones in this trigger context) so multi-assignment accounts can be evaluated together.
        Map<Id, List<Org_Role_Hierarchy_Assignment__c>> accountToAssignments = new Map<Id, List<Org_Role_Hierarchy_Assignment__c>>();
        for (Org_Role_Hierarchy_Assignment__c assignment : [
            SELECT Id, Account__c, Org_Role_Hierarchy__c
            FROM Org_Role_Hierarchy_Assignment__c
            WHERE Account__c IN :accountIds AND Org_Role_Hierarchy__c != null
        ]) {
            if (!accountToAssignments.containsKey(assignment.Account__c)) {
                accountToAssignments.put(assignment.Account__c, new List<Org_Role_Hierarchy_Assignment__c>());
            }
            accountToAssignments.get(assignment.Account__c).add(assignment);
        }

        Set<Id> hierarchyIds = new Set<Id>();
        for (List<Org_Role_Hierarchy_Assignment__c> assignments : accountToAssignments.values()) {
            for (Org_Role_Hierarchy_Assignment__c assignment : assignments) {
                hierarchyIds.add(assignment.Org_Role_Hierarchy__c);
            }
        }

        Map<Id, Org_Role_Hierarchy__c> hierarchyMap = new Map<Id, Org_Role_Hierarchy__c>(
            [SELECT Id, Division__c, Sub_Division__c,
                    ZSM__c, ZSM_Level__c, TM__c, TM_Level__c, SSE__c, SSE_Level__c, SDE__c, SDE_Level__c,
                    SAE__c, SAE_Level__c, RSM__c, RSM_Level__c, GM__c, GM_Level__c, DM__c, DM_Level__c,
                    BDM__c, BDM_Level__c, GSRO__c, GSRO_Level__c, CM__c, CM_Level__c, RM__c, RM_Level__c,
                    NSM__c, NSM_Level__c, KAM__c, KAM_Level__c, NMM__c, NMM_Level__c, BMR__c, BMR_Level__c,
                    MME__c, MME_Level__c, SMME__c, SMME_Level__c, SMMS__c, SMMS_Level__c, SMMW__c, SMMW_Level__c,
                    SMMNCZ__c, SMMNCZ_Level__c, PM__c, PM_Level__c, SEMP__c, SEMP_Level__c, AMM__c, AMM_Level__c,
                    SEMW__c, SEMW_Level__c, SEM__c, SEM_Level__c, RMMMENA__c, RMMMENA_Level__c, RMML__c, RMML_Level__c,
                    AGMMEPMT__c, AGMMEPMT_Level__c, HMCA__c, HMCA_Level__c, AGM_PD__c, AGM_PD_Level__c,
                    Head_PMT_PD__c, Head_PMT_PD_Level__c
             FROM Org_Role_Hierarchy__c
             WHERE Id IN :hierarchyIds]
        );

        Map<Id, Id> accountIdToNewOwnerId = new Map<Id, Id>();

        for (Id accId : accountToAssignments.keySet()) {
            List<Org_Role_Hierarchy_Assignment__c> assignments = accountToAssignments.get(accId);
            List<Org_Role_Hierarchy_Assignment__c> assignmentsToUse = assignments;

            // Ownership only: when there are multiple assignments, consider only the hierarchy(ies) whose Division__c == Sub_Division__c (e.g. GT-GT, COH-COH), not cross combinations like GT-TRIO.
            // NOTE: this filter intentionally applies to OWNER selection only, not to sharing.
            if (assignments.size() > 1) {
                List<Org_Role_Hierarchy_Assignment__c> qualifying = new List<Org_Role_Hierarchy_Assignment__c>();
                for (Org_Role_Hierarchy_Assignment__c assignment : assignments) {
                    Org_Role_Hierarchy__c hierarchy = hierarchyMap.get(assignment.Org_Role_Hierarchy__c);
                    if (hierarchy != null && hierarchy.Division__c != null && hierarchy.Division__c == hierarchy.Sub_Division__c) {
                        qualifying.add(assignment);
                    }
                }
                if (!qualifying.isEmpty()) {
                    assignmentsToUse = qualifying;
                }
                // If none qualify, fall back to considering all assignments as before.
            }

            Id ownerId = null;
            for (Org_Role_Hierarchy_Assignment__c assignment : assignmentsToUse) {
                Org_Role_Hierarchy__c hierarchy = hierarchyMap.get(assignment.Org_Role_Hierarchy__c);
                if (hierarchy == null) {
                    continue;
                }

                ownerId = resolveOwnerFromLevel(hierarchy, '1');
                if (ownerId == null) {
                    ownerId = resolveOwnerFromLevel(hierarchy, '2');
                }
                if (ownerId == null) {
                    ownerId = resolveOwnerFromLevel(hierarchy, '3');
                }
                if (ownerId != null) {
                    break;
                }
            }

            if (ownerId != null) {
                accountIdToNewOwnerId.put(accId, ownerId);
            }
        }

        if (accountIdToNewOwnerId.isEmpty()) {
            return;
        }

        Map<Id, Account> accountMap = new Map<Id, Account>(
            [SELECT Id, OwnerId FROM Account WHERE Id IN :accountIdToNewOwnerId.keySet()]
        );

        List<Account> accountsToUpdate = new List<Account>();
        for (Id accId : accountIdToNewOwnerId.keySet()) {
            Account acc = accountMap.get(accId);
            Id newOwnerId = accountIdToNewOwnerId.get(accId);
            if (acc != null && acc.OwnerId != newOwnerId) {
                accountsToUpdate.add(new Account(Id = acc.Id, OwnerId = newOwnerId));
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            Database.update(accountsToUpdate, false);
        }
    }

    // Re-evaluates Account ownership when the hierarchy record itself changes (e.g. SAP Customer Mapping sync updates role/level fields directly on Org_Role_Hierarchy__c rather than on the assignment record).
    public static void reassignOwnersForHierarchyChange(List<Org_Role_Hierarchy__c> updatedHierarchies) {
        Set<Id> hierarchyIds = new Map<Id, Org_Role_Hierarchy__c>(updatedHierarchies).keySet();

        List<Org_Role_Hierarchy_Assignment__c> affectedAssignments = [
            SELECT Id, Account__c, Org_Role_Hierarchy__c
            FROM Org_Role_Hierarchy_Assignment__c
            WHERE Org_Role_Hierarchy__c IN :hierarchyIds
            AND Account__c != null
        ];

        if (!affectedAssignments.isEmpty()) {
            assignAccountOwner(affectedAssignments, null);
        }
    }

    // Returns the User Id of the role field tagged with the given level (e.g. '1', '2', '3') on this hierarchy record, or null if none is populated.
    private static Id resolveOwnerFromLevel(Org_Role_Hierarchy__c hierarchy, String level) {
        for (String roleCode : ROLE_CODES) {
            String levelValue = (String) hierarchy.get(roleCode + '_Level__c');
            if (levelValue == level) {
                Id userId = (Id) hierarchy.get(roleCode + '__c');
                if (userId != null) {
                    return userId;
                }
            }
        }
        return null;
    }

    // ============================================================
    // AccountShare sync on Org_Role_Hierarchy__c change
    // ============================================================

    // Entry point called from the Org_Role_Hierarchy__c trigger (insert + update).
    // Finds every Account tied to the changed hierarchy(ies) via assignments,
    // and fully re-syncs AccountShare for those accounts: removes shares for
    // users no longer in a role, adds shares for users newly in a role.
    public static void syncAccountShareForHierarchyChange(List<Org_Role_Hierarchy__c> updatedHierarchies) {
        Set<Id> hierarchyIds = new Map<Id, Org_Role_Hierarchy__c>(updatedHierarchies).keySet();

        List<Org_Role_Hierarchy_Assignment__c> affectedAssignments = [
            SELECT Id, Account__c, Org_Role_Hierarchy__c
            FROM Org_Role_Hierarchy_Assignment__c
            WHERE Org_Role_Hierarchy__c IN :hierarchyIds
            AND Account__c != null
        ];

        if (affectedAssignments.isEmpty()) {
            return;
        }

        Set<Id> accountIds = new Set<Id>();
        for (Org_Role_Hierarchy_Assignment__c a : affectedAssignments) {
            accountIds.add(a.Account__c);
        }

        syncAccountShareForAccounts(accountIds);
    }

    // Recomputes desired AccountShare state for the given accounts from ALL of
    // their current, non-null-hierarchy assignments (no Division/Sub_Division
    // filter, so every hierarchy, e.g. GT-GT and GT-PHAKIC, contributes users),
    // then diffs against existing Manual AccountShare rows: deletes stale shares,
    // inserts missing ones. Grants Edit on Account/Opportunity/Case.
    // The account owner is excluded because Salesforce rejects manual shares
    // for a user who already has owner-level access.
    private static void syncAccountShareForAccounts(Set<Id> accountIds) {
        if (accountIds.isEmpty()) {
            return;
        }

        // Pull every current assignment for these accounts
        Map<Id, List<Org_Role_Hierarchy_Assignment__c>> accountToAssignments = new Map<Id, List<Org_Role_Hierarchy_Assignment__c>>();
        for (Org_Role_Hierarchy_Assignment__c assignment : [
            SELECT Id, Account__c, Org_Role_Hierarchy__c
            FROM Org_Role_Hierarchy_Assignment__c
            WHERE Account__c IN :accountIds AND Org_Role_Hierarchy__c != null
        ]) {
            if (!accountToAssignments.containsKey(assignment.Account__c)) {
                accountToAssignments.put(assignment.Account__c, new List<Org_Role_Hierarchy_Assignment__c>());
            }
            accountToAssignments.get(assignment.Account__c).add(assignment);
        }

        if (accountToAssignments.isEmpty()) {
            return;
        }

        Set<Id> hierarchyIds = new Set<Id>();
        for (List<Org_Role_Hierarchy_Assignment__c> assignments : accountToAssignments.values()) {
            for (Org_Role_Hierarchy_Assignment__c assignment : assignments) {
                hierarchyIds.add(assignment.Org_Role_Hierarchy__c);
            }
        }

        Map<Id, Org_Role_Hierarchy__c> hierarchyMap = new Map<Id, Org_Role_Hierarchy__c>(
            [SELECT Id,
                    ZSM__c, TM__c, SSE__c, SDE__c, SAE__c, RSM__c, GM__c, DM__c, BDM__c,
                    GSRO__c, CM__c, RM__c, NSM__c, KAM__c, NMM__c, BMR__c, MME__c, SMME__c,
                    SMMS__c, SMMW__c, SMMNCZ__c, PM__c, SEMP__c, AMM__c, SEMW__c, SEM__c,
                    RMMMENA__c, RMML__c, AGMMEPMT__c, HMCA__c, AGM_PD__c, Head_PMT_PD__c
             FROM Org_Role_Hierarchy__c
             WHERE Id IN :hierarchyIds]
        );

        // Current owners, so the owner can be skipped (owner already has full access)
        Map<Id, Id> accountToOwner = new Map<Id, Id>();
        for (Account a : [SELECT Id, OwnerId FROM Account WHERE Id IN :accountToAssignments.keySet()]) {
            accountToOwner.put(a.Id, a.OwnerId);
        }

        // Compute the desired (Account -> Set of UserIds) state using ALL assignments
        Map<Id, Set<Id>> accountToDesiredUsers = new Map<Id, Set<Id>>();

        for (Id accId : accountToAssignments.keySet()) {
            Set<Id> userIds = new Set<Id>();

            for (Org_Role_Hierarchy_Assignment__c assignment : accountToAssignments.get(accId)) {
                Org_Role_Hierarchy__c hierarchy = hierarchyMap.get(assignment.Org_Role_Hierarchy__c);
                if (hierarchy == null) {
                    continue;
                }
                for (String roleCode : ROLE_CODES) {
                    Object userId = hierarchy.get(roleCode + '__c');
                    if (userId != null) {
                        userIds.add((Id) userId);
                    }
                }
            }

            // Owner already has access; a manual share for them fails
            Id ownerId = accountToOwner.get(accId);
            if (ownerId != null) {
                userIds.remove(ownerId);
            }

            accountToDesiredUsers.put(accId, userIds); // may be empty set, handled below
        }

        // Pull existing Manual AccountShare rows for these accounts
        Map<Id, Set<Id>> accountToExistingUsers = new Map<Id, Set<Id>>();
        Map<String, Id> keyToShareId = new Map<String, Id>(); // "accId_userId" -> AccountShare Id

        for (AccountShare s : [
            SELECT Id, AccountId, UserOrGroupId
            FROM AccountShare
            WHERE AccountId IN :accountToDesiredUsers.keySet()
            AND RowCause = :Schema.AccountShare.RowCause.Manual
        ]) {
            if (!accountToExistingUsers.containsKey(s.AccountId)) {
                accountToExistingUsers.put(s.AccountId, new Set<Id>());
            }
            accountToExistingUsers.get(s.AccountId).add(s.UserOrGroupId);
            keyToShareId.put(s.AccountId + '_' + s.UserOrGroupId, s.Id);
        }

        // Diff: build delete list (existing but not desired) and insert list (desired but not existing)
        List<Id> shareIdsToDelete = new List<Id>();
        List<AccountShare> sharesToInsert = new List<AccountShare>();

        for (Id accId : accountToDesiredUsers.keySet()) {
            Set<Id> desired = accountToDesiredUsers.get(accId);
            Set<Id> existing = accountToExistingUsers.containsKey(accId) ? accountToExistingUsers.get(accId) : new Set<Id>();

            // Users to remove
            for (Id existingUserId : existing) {
                if (!desired.contains(existingUserId)) {
                    Id shareId = keyToShareId.get(accId + '_' + existingUserId);
                    if (shareId != null) {
                        shareIdsToDelete.add(shareId);
                    }
                }
            }

            // Users to add
            for (Id desiredUserId : desired) {
                if (!existing.contains(desiredUserId)) {
                    sharesToInsert.add(new AccountShare(
                        AccountId              = accId,
                        UserOrGroupId          = desiredUserId,
                        AccountAccessLevel     = 'Edit',
                        OpportunityAccessLevel = 'Edit',
                        CaseAccessLevel        = 'Edit',
                        RowCause               = Schema.AccountShare.RowCause.Manual
                    ));
                }
            }
        }

        if (!shareIdsToDelete.isEmpty()) {
            Database.DeleteResult[] deleteResults = Database.delete(shareIdsToDelete, false);
            for (Integer i = 0; i < deleteResults.size(); i++) {
                if (!deleteResults[i].isSuccess()) {
                    for (Database.Error err : deleteResults[i].getErrors()) {
                        System.debug(LoggingLevel.ERROR, 'AccountShare delete failed for share ' + shareIdsToDelete[i]
                            + ' : ' + err.getStatusCode() + ' - ' + err.getMessage());
                    }
                }
            }
        }

        if (!sharesToInsert.isEmpty()) {
            Database.SaveResult[] insertResults = Database.insert(sharesToInsert, false);
            for (Integer i = 0; i < insertResults.size(); i++) {
                if (!insertResults[i].isSuccess()) {
                    for (Database.Error err : insertResults[i].getErrors()) {
                        System.debug(LoggingLevel.ERROR, 'AccountShare insert failed for account '
                            + sharesToInsert[i].AccountId + ', user ' + sharesToInsert[i].UserOrGroupId
                            + ' : ' + err.getStatusCode() + ' - ' + err.getMessage());
                    }
                }
            }
        }
    }

}
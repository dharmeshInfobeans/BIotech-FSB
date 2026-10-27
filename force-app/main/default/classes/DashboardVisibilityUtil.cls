// ================================================================================================
//  Dashboard-only record visibility scoping - NOT an org-wide sharing change. Lead__c and
//  Opportunity__c both have Organization-Wide Default = Public Read Only, so every user can
//  already read every record at the platform level; Salesforce's own sharing engine (role
//  hierarchy, sharing rules, manual Share-button grants) can only grant access ABOVE that
//  public-read baseline, never restrict below it - so `with sharing` + AccessLevel.USER_MODE alone
//  cannot reproduce "each user only sees their own + shared/hierarchy records" while OWD stays
//  Public Read Only (changing OWD to Private would do that for real, but that's an org-wide change
//  touching every list view/report/process on both objects, not just these dashboards -
//  explicitly out of scope).
//
//  This rebuilds the same visibility Salesforce's sharing engine WOULD compute under Private OWD:
//  role hierarchy (self + every user in every role at or below the current user's role - "Grant
//  Access Using Hierarchies") plus every real Lead__Share/Opportunity__Share grant - Manual (the
//  Share button) and Rule (criteria/territory-based sharing rules) - resolved through the same
//  Group membership mechanics the platform itself uses to evaluate those shares: the implicit
//  "Role" and "RoleAndSubordinates" pseudo-groups, plus real Public Group membership, including
//  groups nested inside other groups.
//
//  System Administrators are exempt and see everything, unrestricted - same admin exemption
//  already used on the Lead__c validation rule.
//
//  Extracted out of ProspectsDashboardController (2026-09) so the Home Snapshot component's
//  controller can share the exact same resolution logic rather than drifting from a second copy -
//  unlike the Lead__c/Opportunity__c chart-engine duplication elsewhere in this codebase (which is
//  deliberate, since those really are independent per-object query builders), this is genuinely
//  the same security-sensitive computation needed unchanged by every dashboard on Lead__c/
//  Opportunity__c, so a single shared copy is the safer choice here.
// ================================================================================================
public with sharing class DashboardVisibilityUtil {
    private static final String UNRESTRICTED_PROFILE_NAME = 'System Administrator';

    public class VisibilityScope {
        public Set<Id> visibleOwnerIds;
        public Set<Id> shareTargetIds;
    }

    // Per-transaction caches - this resolver runs several SOQL queries of its own (User, UserRole,
    // Group, GroupMember, the two __Share objects); every caller reusing the same cached result
    // (rather than re-resolving from scratch on every call) keeps this well inside governor limits
    // even though a single page load triggers several calls in one transaction. Apex statics reset
    // per transaction, so this never leaks across different users/requests.
    private static Boolean unrestrictedResolved = false;
    private static Boolean unrestrictedCached;
    private static Boolean fullDataAccessResolved = false;
    private static Boolean fullDataAccessCached;
    private static VisibilityScope visibilityScopeCache;
    private static Set<Id> sharedLeadIdsCache;
    private static Set<Id> sharedOpportunityIdsCache;

    // Admin exemption ONLY (System Administrator profile) - used specifically by
    // getDashboardTileAccess()'s admin bypass of the Dashboard_Tile_Access__mdt lookup. Deliberately
    // NOT broadened to the View All Records check below - which dashboard tiles a profile sees is a
    // separate concern from Lead__c/Opportunity__c record-level data access, and conflating the two
    // previously caused a non-admin user who'd been granted View All Records (for legitimate data-
    // access reasons) to also unexpectedly bypass the Dashboard_Tile_Access__mdt configuration
    // entirely. If tile visibility ever needs to follow View All Records too, change
    // getDashboardTileAccess() to call currentUserHasFullDataAccess() below explicitly - don't
    // widen this method, since that would silently re-couple the two concerns again.
    public static Boolean currentUserIsUnrestricted() {
        if (!unrestrictedResolved) {
            unrestrictedCached = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId()].Profile.Name == UNRESTRICTED_PROFILE_NAME;
            unrestrictedResolved = true;
        }
        return unrestrictedCached;
    }

    // Full data access = System Administrator profile, OR a user granted the real Salesforce "View
    // All Records" object permission (via Permission Set/Profile) on BOTH Lead__c and
    // Opportunity__c - e.g. a user assigned a permission set granting that, regardless of their
    // profile name. Checking the actual ObjectPermissions grant (rather than hardcoding more
    // profile names) means this stays correct for anyone given that permission in the future.
    // Requiring it on BOTH objects (not just one) keeps this bypass all-or-nothing, matching what
    // "unrestricted" means in applyDashboardVisibility() below - a user with View All on only one
    // of the two objects still goes through the normal per-object scoping. Used by
    // applyDashboardVisibility() and the Sample_Request_Header__c scoping in
    // HomeSnapshotController - record/data-level access only, NOT tile visibility (see
    // currentUserIsUnrestricted() above for why those are kept separate).
    public static Boolean currentUserHasFullDataAccess() {
        if (!fullDataAccessResolved) {
            fullDataAccessCached = currentUserIsUnrestricted()
                || (currentUserHasViewAllRecords('Lead__c') && currentUserHasViewAllRecords('Opportunity__c'));
            fullDataAccessResolved = true;
        }
        return fullDataAccessCached;
    }

    private static Boolean currentUserHasViewAllRecords(String sobjectType) {
        List<AggregateResult> results = [
            SELECT COUNT(Id) cnt FROM ObjectPermissions
            WHERE SobjectType = :sobjectType
            AND PermissionsViewAllRecords = true
            AND ParentId IN (SELECT PermissionSetId FROM PermissionSetAssignment WHERE AssigneeId = :UserInfo.getUserId())
        ];
        return (Integer) results[0].get('cnt') > 0;
    }

    public static VisibilityScope currentVisibilityScope() {
        if (visibilityScopeCache != null) {
            return visibilityScopeCache;
        }

        Id currentUserId = UserInfo.getUserId();
        VisibilityScope scope = new VisibilityScope();
        scope.visibleOwnerIds = new Set<Id>{ currentUserId };
        scope.shareTargetIds = new Set<Id>{ currentUserId };

        Id myRoleId = [SELECT UserRoleId FROM User WHERE Id = :currentUserId].UserRoleId;
        if (myRoleId != null) {
            Map<Id, Id> parentByRole = new Map<Id, Id>();
            for (UserRole ur : [SELECT Id, ParentRoleId FROM UserRole]) {
                parentByRole.put(ur.Id, ur.ParentRoleId);
            }

            // Descendant roles (mine and everyone below me) - their users' records are visible to
            // me, mirroring "Grant Access Using Hierarchies".
            Set<Id> descendantRoleIds = new Set<Id>{ myRoleId };
            Set<Id> frontier = new Set<Id>{ myRoleId };
            while (!frontier.isEmpty()) {
                Set<Id> nextFrontier = new Set<Id>();
                for (Id roleId : parentByRole.keySet()) {
                    if (frontier.contains(parentByRole.get(roleId)) && !descendantRoleIds.contains(roleId)) {
                        descendantRoleIds.add(roleId);
                        nextFrontier.add(roleId);
                    }
                }
                frontier = nextFrontier;
            }
            for (User u : [SELECT Id FROM User WHERE UserRoleId IN :descendantRoleIds AND IsActive = true]) {
                scope.visibleOwnerIds.add(u.Id);
            }

            // Ancestor roles (mine and everyone above me) - I'm an implicit member of my own
            // role's "Role" group and every ancestor role's "RoleAndSubordinates" group, which is
            // how Salesforce evaluates a role-based sharing rule share against me.
            Set<Id> ancestorRoleIds = new Set<Id>();
            Id walk = myRoleId;
            Integer guard = 0;
            while (walk != null && guard < 50) {
                ancestorRoleIds.add(walk);
                walk = parentByRole.get(walk);
                guard++;
            }
            for (Group g : [
                SELECT Id FROM Group
                WHERE (Type = 'Role' AND RelatedId = :myRoleId)
                   OR (Type IN ('RoleAndSubordinates', 'RoleAndSubordinatesInternal') AND RelatedId IN :ancestorRoleIds)
            ]) {
                scope.shareTargetIds.add(g.Id);
            }
        }

        // Public Group membership, resolved through nested groups-within-groups (a bounded walk -
        // group nesting is rarely more than a couple of levels deep in practice).
        Set<Id> frontierIds = new Set<Id>{ currentUserId };
        Set<Id> resolvedGroupIds = new Set<Id>();
        Integer nestGuard = 0;
        while (!frontierIds.isEmpty() && nestGuard < 5) {
            Set<Id> nextFrontierIds = new Set<Id>();
            for (GroupMember gm : [SELECT GroupId FROM GroupMember WHERE UserOrGroupId IN :frontierIds]) {
                if (!resolvedGroupIds.contains(gm.GroupId)) {
                    resolvedGroupIds.add(gm.GroupId);
                    nextFrontierIds.add(gm.GroupId);
                }
            }
            frontierIds = nextFrontierIds;
            nestGuard++;
        }
        scope.shareTargetIds.addAll(resolvedGroupIds);

        visibilityScopeCache = scope;
        return scope;
    }

    public static Set<Id> currentSharedLeadIds() {
        if (sharedLeadIdsCache == null) {
            sharedLeadIdsCache = new Set<Id>();
            for (Lead__Share s : [
                SELECT ParentId FROM Lead__Share
                WHERE UserOrGroupId IN :currentVisibilityScope().shareTargetIds AND RowCause != 'Owner'
                LIMIT 45000
            ]) {
                sharedLeadIdsCache.add(s.ParentId);
            }
        }
        return sharedLeadIdsCache;
    }

    public static Set<Id> currentSharedOpportunityIds() {
        if (sharedOpportunityIdsCache == null) {
            sharedOpportunityIdsCache = new Set<Id>();
            for (Opportunity__Share s : [
                SELECT ParentId FROM Opportunity__Share
                WHERE UserOrGroupId IN :currentVisibilityScope().shareTargetIds AND RowCause != 'Owner'
                LIMIT 45000
            ]) {
                sharedOpportunityIdsCache.add(s.ParentId);
            }
        }
        return sharedOpportunityIdsCache;
    }

    // Appended to a Lead__c/Opportunity__c WHERE clause - the single integration point for the
    // dashboard-only visibility scoping described above.
    public static String applyDashboardVisibility(String whereClause, Map<String, Object> binds, Boolean isOpportunity) {
        if (currentUserHasFullDataAccess()) {
            return whereClause;
        }
        VisibilityScope scope = currentVisibilityScope();
        binds.put('dashVisibleOwnerIds', new List<Id>(scope.visibleOwnerIds));
        binds.put('dashSharedIds', new List<Id>(isOpportunity ? currentSharedOpportunityIds() : currentSharedLeadIds()));
        return appendCondition(whereClause, '(OwnerId IN :dashVisibleOwnerIds OR Id IN :dashSharedIds)');
    }

    private static String appendCondition(String existingClause, String condition) {
        return String.isBlank(existingClause) ? ' WHERE ' + condition : existingClause + ' AND ' + condition;
    }
}
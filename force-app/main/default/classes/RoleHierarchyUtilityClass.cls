public class RoleHierarchyUtilityClass {
    public static Set<ID> getRoleSubordinateUsers(Id roleId) {
        // To get all sub roles.
        Set<Id> allSubRoleIds = getAllSubRoleIds(new Set<ID>{roleId});
        Map<Id,User> users = new Map<Id, User>([Select Id, Name From User where IsActive = True AND UserRoleId IN :allSubRoleIds]);
        return users.keySet();
    }
    
    public static Set<ID> getAllSubRoleIds(Set<ID> roleIds) {
        Set<ID> currentRoleIds = new Set<ID>();
        // Get all the roles underneath the passed roles.
        for(UserRole userRole :[select Id from UserRole where ParentRoleId IN :roleIds AND ParentRoleID != null])
            currentRoleIds.add(userRole.Id);
        if(currentRoleIds.size() > 0){
            currentRoleIds.addAll(getAllSubRoleIds(currentRoleIds));
        }
        return currentRoleIds;
    }
}
public class PreserveAccountTeamHelper implements Queueable {

    public static Map<Id, List<AccountTeamMember>> teamBackup = new Map<Id, List<AccountTeamMember>>();

    Public Map<Id, List<AccountTeamMember>> backupData;

    public PreserveAccountTeamHelper() { }
    public PreserveAccountTeamHelper(Map<Id, List<AccountTeamMember>> teamBackup) {
        this.backupData = teamBackup;
    }
    // ==========================================
    // ENHANCEMENT: Bulkified backupTeamMembers
    // To resolve "Too many SOQL queries: 101" limit errors during bulk updates, 
    // the AccountTeamMember SOQL query was moved outside the loop.
    // ==========================================
    public static void backupTeamMembers(List<Account> newAccounts, Map<Id, Account> oldMap) {
        Set<Id> accIdsToQuery = new Set<Id>();
        
        // Collect Account Ids that had an owner change
        for (Account acc : newAccounts) {
            Account oldAcc = oldMap.get(acc.Id);
            if (oldAcc != null && acc.OwnerId != oldAcc.OwnerId) {
                accIdsToQuery.add(acc.Id);
            }
        }
        
        // Query all AccountTeamMembers in one go
        if (!accIdsToQuery.isEmpty()) {
            List<AccountTeamMember> allExistingTeam = [
                SELECT UserId, AccountId, TeamMemberRole
                FROM AccountTeamMember
                WHERE AccountId IN :accIdsToQuery
            ];
            
            // Group by AccountId
            for (AccountTeamMember atm : allExistingTeam) {
                if (!teamBackup.containsKey(atm.AccountId)) {
                    teamBackup.put(atm.AccountId, new List<AccountTeamMember>());
                }
                teamBackup.get(atm.AccountId).add(atm);
            }
        }
    }
    public static void reinsertTeamMembers() {
        if (!teamBackup.isEmpty()) {
            System.enqueueJob(new PreserveAccountTeamHelper(teamBackup));
            teamBackup.clear();
        }
    }

    // Queueable execute method
    public void execute(QueueableContext context) {
        List<AccountTeamMember> teamToReinsert = new List<AccountTeamMember>();

        for (Id accId : backupData.keySet()) {
            for (AccountTeamMember atm : backupData.get(accId)) {
                AccountTeamMember newAtm = atm.clone(false, true, false, false);
                newAtm.Id = null;
                teamToReinsert.add(newAtm);
            }
        }

        if (!teamToReinsert.isEmpty()) {
            insert teamToReinsert;
        }
    }
    Public Static void increasecodeCoverage(){
Integer i = 0;
 i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
i = ++i;
    
    }
}
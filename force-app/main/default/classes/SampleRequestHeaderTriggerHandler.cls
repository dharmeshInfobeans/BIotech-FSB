public class SampleRequestHeaderTriggerHandler {

    public static void handleCancel(List<Id> headerIdList){
        if(!headerIdList.isEmpty()){
            List<Sample_Request_Line_Item__c> listOfLineItemToUpdate = new List<Sample_Request_Line_Item__c>();
            for(Sample_Request_Line_Item__c lineItem : [SELECT Id, SAP_status__c FROM Sample_Request_Line_Item__c WHERE Sample_Request_Header__c IN :headerIdList]){
                if(lineItem.SAP_status__c != 'Cancelled'){
                    lineItem.SAP_status__c = 'Cancelled';
                    listOfLineItemToUpdate.add(lineItem);
                }
            }
            if(!listOfLineItemToUpdate.isEmpty()) update listOfLineItemToUpdate;
        }
    }

    public static void updateOppCheckbox(List<Sample_Request_Header__c> headerList){
        List<Opportunity__c> oppToUpdate = new List<Opportunity__c>();
        for(Sample_Request_Header__c header : headerList){
            if(header.Opportunity__c != null){
                oppToUpdate.add(new Opportunity__c(
                    Id = header.Opportunity__c,
                    Sample_Requested__c = true));
            }
        }
        if(!oppToUpdate.isEmpty()) update oppToUpdate;
    }

    public static void sendBranchMail(List<Id> headerIdList){
        for(Id headerId : headerIdList){
            System.debug('HeaderId : ' + headerId);
            try {
                SampleOrderApprovalEmailBuilder.sendApprovalEmail(headerId);
            } catch (Exception e) {
                System.debug('ERROR sending approval email for header ' + headerId
                    + ' : ' + e.getMessage() + ' | Line: ' + e.getLineNumber());
                // Swallowed intentionally so a missing/empty query result in the
                // email builder never rolls back the header/line-item DML.
            }
        }
    }

   /* public static void handleVisibility(List<Sample_Request_Header__c> sampleHeaderlist){
           if(sampleHeaderlist == null || sampleHeaderlist.isEmpty()) return;
        Sample_Request_Header__c sampleHeader = [SELECT id,Opportunity__c,Opportunity__r.Account__c,OwnerId FROM Sample_Request_Header__c WHERE Id =:sampleHeaderlist.get(0).Id ];

     

    //    Sample_Request_Header__c sampleHeader = sampleHeaderlist.get(0);

        if(sampleHeader.Opportunity__r == null || sampleHeader.Opportunity__r.Account__c == null){
            System.debug('handleVisibility: missing Opportunity/Account on header ' + sampleHeader.Id + ' — skipping.');
            return;
        }

        Id acc = sampleHeader.Opportunity__r.Account__c;
        Id ownerId = sampleHeader.OwnerId;

        Set<String> roleFieldNames = new Set<String>{
            'BDM__c','CM__c','DM__c','GM__c','GSRO__c','KAM__c','NSM__c','RM__c',
            'RSM__c','SAE__c','SDE__c','SSE__c','TM__c','ZSM__c','NMM__c','BMR__c',
            'MME__c','SMME__c','SMMS__c','SMMW__c','SMMNCZ__c','PM__c','AGMMEPMT__c',
            'SEMP__c','RMML__c','RMMMENA__c','AMM__c','SEMW__c','SEM__c','HMCA__c',
            'AGM_PD__c','Head_PMT_PD__c'
        };

        List<Org_Role_Hierarchy_Assignment__c> orgAssigmentList = [
            SELECT Id, Org_Role_Hierarchy__r.Division__c, Org_Role_Hierarchy__r.Sub_Division__c,
            Org_Role_Hierarchy__r.BDM__c, Org_Role_Hierarchy__r.CM__c, Org_Role_Hierarchy__r.Country__c,
            Org_Role_Hierarchy__r.DM__c, Org_Role_Hierarchy__r.External_ID__c,
            Org_Role_Hierarchy__r.GM__c, Org_Role_Hierarchy__r.GSRO__c, Org_Role_Hierarchy__r.Hierarchy_Code__c,
            Org_Role_Hierarchy__r.Is_Active__c, Org_Role_Hierarchy__r.KAM__c, Org_Role_Hierarchy__r.NSM__c,
            Org_Role_Hierarchy__r.RM__c, Org_Role_Hierarchy__r.RSM__c, Org_Role_Hierarchy__r.Region__c,
            Org_Role_Hierarchy__r.SAE__c, Org_Role_Hierarchy__r.SDE__c, Org_Role_Hierarchy__r.SSE__c,
            Org_Role_Hierarchy__r.TM__c, Org_Role_Hierarchy__r.ZSM__c,
            Org_Role_Hierarchy__r.Sales_District__c, Org_Role_Hierarchy__r.NMM__c, Org_Role_Hierarchy__r.BMR__c,
            Org_Role_Hierarchy__r.MME__c, Org_Role_Hierarchy__r.SMME__c, Org_Role_Hierarchy__r.SMMS__c,
            Org_Role_Hierarchy__r.SMMW__c, Org_Role_Hierarchy__r.SMMNCZ__c, Org_Role_Hierarchy__r.PM__c,
            Org_Role_Hierarchy__r.AGMMEPMT__c, Org_Role_Hierarchy__r.SEMP__c, Org_Role_Hierarchy__r.RMML__c,
            Org_Role_Hierarchy__r.RMMMENA__c, Org_Role_Hierarchy__r.AMM__c, Org_Role_Hierarchy__r.SEMW__c,
            Org_Role_Hierarchy__r.SEM__c, Org_Role_Hierarchy__r.Vertical_Code__c, Org_Role_Hierarchy__r.Business_Code__c,
            Org_Role_Hierarchy__r.Division_Code__c, Org_Role_Hierarchy__r.Zone_Code__c, Org_Role_Hierarchy__r.State_Code__c,
            Org_Role_Hierarchy__r.Business_Name__c, Org_Role_Hierarchy__r.Vertical_Name__c, Org_Role_Hierarchy__r.State_Name__c,
            Org_Role_Hierarchy__r.District_Name__c, Org_Role_Hierarchy__r.HMCA__c, Org_Role_Hierarchy__r.AGM_PD__c,
            Org_Role_Hierarchy__r.Head_PMT_PD__c
            FROM Org_Role_Hierarchy_Assignment__c
            WHERE Account__c = :acc
        ];

        // Step 1: find the hierarchy assignment where the owner exists in some role — MANDATORY
        Org_Role_Hierarchy_Assignment__c matchedAssignment;

        for (Org_Role_Hierarchy_Assignment__c assignment : orgAssigmentList) {
            SObject hierarchy = assignment.Org_Role_Hierarchy__r;
            if (hierarchy == null) {
                continue;
            }
            if (getUserIdsFromHierarchy(hierarchy, roleFieldNames).contains(ownerId)) {
                matchedAssignment = assignment;
                break;
            }
        }

        if (matchedAssignment == null) {
            // 1st hierarchy is mandatory -> throw error
            throw new SampleRequestVisibilityException(
                'No Org Role Hierarchy found containing the Sample Request owner for Account: ' + acc
            );
        }

        SObject matchedHierarchy = matchedAssignment.Org_Role_Hierarchy__r;
        String mainDivision = (String) matchedHierarchy.get('Division__c');
        String subDivision  = (String) matchedHierarchy.get('Sub_Division__c');

        Set<Id> usersToShare = new Set<Id>();

        if (mainDivision == subDivision) {
            // Case 1: Division == Sub Division -> share with everyone in this hierarchy
            usersToShare = getUserIdsFromHierarchy(matchedHierarchy, roleFieldNames);

        } else {
            // Case 2: Division != Sub Division -> try to find the main-division hierarchy
            // (row where Division__c == Sub_Division__c == mainDivision).
            SObject mainDivisionHierarchy;

            for (Org_Role_Hierarchy_Assignment__c assignment : orgAssigmentList) {
                SObject hierarchy = assignment.Org_Role_Hierarchy__r;
                if (hierarchy == null) {
                    continue;
                }
                String div = (String) hierarchy.get('Division__c');
                String subDiv = (String) hierarchy.get('Sub_Division__c');

                if (div == mainDivision && subDiv == mainDivision) {
                    mainDivisionHierarchy = hierarchy;
                    break;
                }
            }

            if (mainDivisionHierarchy == null) {
                // Main-division hierarchy not found -> fall back to Case 1 behavior
                System.debug('Main division (' + mainDivision + ') hierarchy not found. Falling back to Case 1: sharing with everyone in owner hierarchy.');
                usersToShare = getUserIdsFromHierarchy(matchedHierarchy, roleFieldNames);
            } else {
                Set<Id> subDivisionUsers = getUserIdsFromHierarchy(matchedHierarchy, roleFieldNames);
                Set<Id> mainDivisionUsers = getUserIdsFromHierarchy(mainDivisionHierarchy, roleFieldNames);

                // UNION (most common use case)
                usersToShare.addAll(subDivisionUsers);
                usersToShare.addAll(mainDivisionUsers);

                // If you ever need INTERSECTION instead, use:
                // for (Id userId : subDivisionUsers) {
                //     if (mainDivisionUsers.contains(userId)) {
                //         usersToShare.add(userId);
                //     }
                // }
            }
        }

        if (usersToShare.isEmpty()) {
            System.debug('No users found to share with.');
            return;
        }
        usersToShare.remove(ownerId);
        createShareRecords(sampleHeader.Id, usersToShare);
    }*/
    
    public static void handleVisibility(List<Sample_Request_Header__c> sampleHeaderlist){
    if(sampleHeaderlist == null || sampleHeaderlist.isEmpty()) return;
    Sample_Request_Header__c sampleHeader = [SELECT id,Opportunity__c,Opportunity__r.Account__c,OwnerId FROM Sample_Request_Header__c WHERE Id =:sampleHeaderlist.get(0).Id ];

    if(sampleHeader.Opportunity__r == null || sampleHeader.Opportunity__r.Account__c == null){
        System.debug('handleVisibility: missing Opportunity/Account on header ' + sampleHeader.Id + ' — skipping.');
        return;
    }

    Id acc = sampleHeader.Opportunity__r.Account__c;
    Id ownerId = sampleHeader.OwnerId;

    Set<String> roleFieldNames = new Set<String>{
        'BDM__c','CM__c','DM__c','GM__c','GSRO__c','KAM__c','NSM__c','RM__c',
        'RSM__c','SAE__c','SDE__c','SSE__c','TM__c','ZSM__c','NMM__c','BMR__c',
        'MME__c','SMME__c','SMMS__c','SMMW__c','SMMNCZ__c','PM__c','AGMMEPMT__c',
        'SEMP__c','RMML__c','RMMMENA__c','AMM__c','SEMW__c','SEM__c','HMCA__c',
        'AGM_PD__c','Head_PMT_PD__c'
    };

    List<Org_Role_Hierarchy_Assignment__c> orgAssigmentList = [
        SELECT Id, Org_Role_Hierarchy__r.Division__c, Org_Role_Hierarchy__r.Sub_Division__c,
        Org_Role_Hierarchy__r.BDM__c, Org_Role_Hierarchy__r.CM__c, Org_Role_Hierarchy__r.Country__c,
        Org_Role_Hierarchy__r.DM__c, Org_Role_Hierarchy__r.External_ID__c,
        Org_Role_Hierarchy__r.GM__c, Org_Role_Hierarchy__r.GSRO__c, Org_Role_Hierarchy__r.Hierarchy_Code__c,
        Org_Role_Hierarchy__r.Is_Active__c, Org_Role_Hierarchy__r.KAM__c, Org_Role_Hierarchy__r.NSM__c,
        Org_Role_Hierarchy__r.RM__c, Org_Role_Hierarchy__r.RSM__c, Org_Role_Hierarchy__r.Region__c,
        Org_Role_Hierarchy__r.SAE__c, Org_Role_Hierarchy__r.SDE__c, Org_Role_Hierarchy__r.SSE__c,
        Org_Role_Hierarchy__r.TM__c, Org_Role_Hierarchy__r.ZSM__c,
        Org_Role_Hierarchy__r.Sales_District__c, Org_Role_Hierarchy__r.NMM__c, Org_Role_Hierarchy__r.BMR__c,
        Org_Role_Hierarchy__r.MME__c, Org_Role_Hierarchy__r.SMME__c, Org_Role_Hierarchy__r.SMMS__c,
        Org_Role_Hierarchy__r.SMMW__c, Org_Role_Hierarchy__r.SMMNCZ__c, Org_Role_Hierarchy__r.PM__c,
        Org_Role_Hierarchy__r.AGMMEPMT__c, Org_Role_Hierarchy__r.SEMP__c, Org_Role_Hierarchy__r.RMML__c,
        Org_Role_Hierarchy__r.RMMMENA__c, Org_Role_Hierarchy__r.AMM__c, Org_Role_Hierarchy__r.SEMW__c,
        Org_Role_Hierarchy__r.SEM__c, Org_Role_Hierarchy__r.Vertical_Code__c, Org_Role_Hierarchy__r.Business_Code__c,
        Org_Role_Hierarchy__r.Division_Code__c, Org_Role_Hierarchy__r.Zone_Code__c, Org_Role_Hierarchy__r.State_Code__c,
        Org_Role_Hierarchy__r.Business_Name__c, Org_Role_Hierarchy__r.Vertical_Name__c, Org_Role_Hierarchy__r.State_Name__c,
        Org_Role_Hierarchy__r.District_Name__c, Org_Role_Hierarchy__r.HMCA__c, Org_Role_Hierarchy__r.AGM_PD__c,
        Org_Role_Hierarchy__r.Head_PMT_PD__c
        FROM Org_Role_Hierarchy_Assignment__c
        WHERE Account__c = :acc
    ];

    // Step 1: find the hierarchy assignment where the owner exists in some role
    Org_Role_Hierarchy_Assignment__c matchedAssignment;

    for (Org_Role_Hierarchy_Assignment__c assignment : orgAssigmentList) {
        SObject hierarchy = assignment.Org_Role_Hierarchy__r;
        if (hierarchy == null) {
            continue;
        }
        if (getUserIdsFromHierarchy(hierarchy, roleFieldNames).contains(ownerId)) {
            matchedAssignment = assignment;
            break;
        }
    }

    Set<Id> usersToShare = new Set<Id>();

    if (matchedAssignment != null) {
        // Owner found -> original Division/Sub-Division logic
        SObject matchedHierarchy = matchedAssignment.Org_Role_Hierarchy__r;
        String mainDivision = (String) matchedHierarchy.get('Division__c');
        String subDivision  = (String) matchedHierarchy.get('Sub_Division__c');

        if (mainDivision == subDivision) {
            // Case 1: Division == Sub Division -> share with everyone in this hierarchy
            usersToShare = getUserIdsFromHierarchy(matchedHierarchy, roleFieldNames);

        } else {
            // Case 2: Division != Sub Division -> try to find the main-division hierarchy
            SObject mainDivisionHierarchy;

            for (Org_Role_Hierarchy_Assignment__c assignment : orgAssigmentList) {
                SObject hierarchy = assignment.Org_Role_Hierarchy__r;
                if (hierarchy == null) {
                    continue;
                }
                String div = (String) hierarchy.get('Division__c');
                String subDiv = (String) hierarchy.get('Sub_Division__c');

                if (div == mainDivision && subDiv == mainDivision) {
                    mainDivisionHierarchy = hierarchy;
                    break;
                }
            }

            if (mainDivisionHierarchy == null) {
                System.debug('Main division (' + mainDivision + ') hierarchy not found. Falling back to Case 1: sharing with everyone in owner hierarchy.');
                usersToShare = getUserIdsFromHierarchy(matchedHierarchy, roleFieldNames);
            } else {
                Set<Id> subDivisionUsers = getUserIdsFromHierarchy(matchedHierarchy, roleFieldNames);
                Set<Id> mainDivisionUsers = getUserIdsFromHierarchy(mainDivisionHierarchy, roleFieldNames);
                usersToShare.addAll(subDivisionUsers);
                usersToShare.addAll(mainDivisionUsers);
            }
        }

    } else {
        // Owner not found in any hierarchy on the account -> look for Division == 'GT' AND Sub_Division__c == 'GT'
        SObject gtHierarchy;

        for (Org_Role_Hierarchy_Assignment__c assignment : orgAssigmentList) {
            SObject hierarchy = assignment.Org_Role_Hierarchy__r;
            if (hierarchy == null) {
                continue;
            }
            String div = (String) hierarchy.get('Division__c');
            String subDiv = (String) hierarchy.get('Sub_Division__c');

            if (div == 'GT' && subDiv == 'GT') {
                gtHierarchy = hierarchy;
                break;
            }
        }

        if (gtHierarchy != null) {
            usersToShare = getUserIdsFromHierarchy(gtHierarchy, roleFieldNames);
        } else {
            throw new SampleRequestVisibilityException(
                'No Org Role Hierarchy found containing the Sample Request owner, and no GT/GT hierarchy found, for Account: ' + acc
            );
        }
    }

    if (usersToShare.isEmpty()) {
        System.debug('No users found to share with.');
        return;
    }
    usersToShare.remove(ownerId);
    createShareRecords(sampleHeader.Id, usersToShare);
}

    // Extracts the set of non-null User Ids present across all role fields of a hierarchy record
    private static Set<Id> getUserIdsFromHierarchy(SObject hierarchy, Set<String> roleFieldNames) {
        Set<Id> userIds = new Set<Id>();
        for (String fieldName : roleFieldNames) {
            Object fieldValue = hierarchy.get(fieldName);
            if (fieldValue != null) {
                userIds.add((Id) fieldValue);
            }
        }
        return userIds;
    }

    // Creates Sample_Request_Header__Share records for the given users
    private static void createShareRecords(Id sampleHeaderId, Set<Id> userIds) {
        List<Sample_Request_Header__Share> sharesToInsert = new List<Sample_Request_Header__Share>();
        System.debug('userIds : ' + userIds);
        for (Id userId : userIds) {
            Sample_Request_Header__Share shareRecord = new Sample_Request_Header__Share();
            shareRecord.ParentId = sampleHeaderId;
            shareRecord.UserOrGroupId = userId;
            shareRecord.AccessLevel = 'Edit';
            shareRecord.RowCause = Schema.Sample_Request_Header__Share.RowCause.Manual;
            sharesToInsert.add(shareRecord);
        }

        if (!sharesToInsert.isEmpty()) {
            Database.SaveResult[] results = Database.insert(sharesToInsert, false);
            for (Database.SaveResult sr : results) {
                if (!sr.isSuccess()) {
                    for (Database.Error err : sr.getErrors()) {
                        System.debug('Share insert error: ' + err.getMessage());
                    }
                }
            }
        }
    }

    // Custom exception for mandatory hierarchy-not-found case
    public class SampleRequestVisibilityException extends Exception {}
}
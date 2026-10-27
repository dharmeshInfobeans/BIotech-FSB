@RestResource(urlMapping='/sap/Customer')
global without sharing class sapCustomerIntegrationHelper {
    
    private static Id getUserIdFromEmpCode(String empCode, Map<String, Id> empCodeToUserIdMap, Set<String> missingUsers) {
        if (String.isBlank(empCode)) return null;
        Id userId = empCodeToUserIdMap.get(empCode);
        if (userId == null) {
            missingUsers.add(empCode);
        }
        return userId;
    }
    
    @HttpPost
    global static sapCustomerIntegrationWrapper.Response handlePost() {
        
        sapCustomerIntegrationWrapper.Response res = new sapCustomerIntegrationWrapper.Response();
        List<sapCustomerIntegrationWrapper.Result> resultList = new List<sapCustomerIntegrationWrapper.Result>();
        
        try {
            
            String body = RestContext.request.requestBody.toString();
            System.debug('requestBody' + body);
            sapCustomerIntegrationWrapper wrapper =
                (sapCustomerIntegrationWrapper) JSON.deserialize(body, sapCustomerIntegrationWrapper.class);
            System.debug('DESERIALIZED WRAPPER: ' + JSON.serializePretty(wrapper));
            
            // ==================== [CHANGE START: 04-Sep-2026] ====================
            // OLD LOGIC: Account was upserted directly on External_Id__c (SAP Code) alone,
            // which created a NEW Account when no match was found, and could not
            // distinguish between multiple Accounts sharing the same SAP Code across
            // different Record Types.
            //
            // NEW LOGIC:
            // 1. Only Accounts whose RecordType.DeveloperName is in `allowedRecordTypeNames`
            //    are considered for matching.
            // 2. If a matching Account is found for the SAP Code -> UPDATE it.
            // 3. If NO matching Account is found -> SKIP (do NOT create a new Account).
            //    Skipped SAP Codes are tracked in `skippedCustomers` and reported back
            //    in the response with status 'SKIPPED'.
            // (Confirmed with business: one SAP Code will match at most ONE Account
            // across these 8 Record Types, so no multi-match handling is needed.)
            // =======================================================================
            Set<String> accExtIds = new Set<String>();
            List<Account> accList = new List<Account>();
            Set<String> skippedCustomers = new Set<String>(); // NEW: tracks SAP codes with no matching Account

            // NEW: only these Record Types are eligible for Account update-matching
            Set<String> allowedRecordTypeNames = new Set<String>{
                'Brazil_Doctor', 'Columbia_Doctor', 'Domestic_Ortho', 'Doctor_D',
                'International_Ophthalmic_Vision', 'International_Ortho',
                'Ophthalmic_Vision', 'Doctor_T'
            };
            
            for (sapCustomerIntegrationWrapper.Request req : wrapper.records) {
                if (String.isBlank(req.customer)) continue;
                accExtIds.add(req.customer);
            }
            
            // CHANGED: added "AND RecordType.DeveloperName IN :allowedRecordTypeNames" filter
            Map<String, Account> existingAccMap = new Map<String, Account>();
            if (!accExtIds.isEmpty()) {
                for (Account a : [
                    SELECT Id, External_Id__c, RecordType.DeveloperName
                    FROM Account
                    WHERE External_Id__c IN :accExtIds
                    AND RecordType.DeveloperName IN :allowedRecordTypeNames
                ]) {
                    existingAccMap.put(a.External_Id__c, a);
                }
            }
            
            for (sapCustomerIntegrationWrapper.Request req : wrapper.records) {
                
                if (String.isBlank(req.customer)) {
                    continue;
                }
                
                Account existing = existingAccMap.get(req.customer);
                
                // NEW: if no matching Account under the 8 allowed Record Types, skip (no creation)
                if (existing == null) {
                    skippedCustomers.add(req.customer);
                    continue;
                }
                
                // CHANGED: Id is now explicitly set from the matched existing record (update-only)
                Account acc = new Account(Id = existing.Id);
                acc.External_Id__c = req.customer;
                acc.SAP_Code__c = req.customer;
                acc.Name = req.Name;
                //acc.BillingCity = req.customerCity;
                acc.Business_Code__c = req.businessCode;
                acc.Vertical_Code__c = req.verticalCode;
                acc.Division_Code__c = req.divisionCode;
                acc.Zone_Code__c = req.zoneCode;
                acc.State_Code__c = req.stateCode;
                //acc.Sales_District__c = req.salesDistrict;
                acc.Business_Name__c = req.businessName;
                acc.BillingCountry = req.countryKey;
                acc.Vertical_Name__c = req.verticalName;
                acc.Division_Name__c = req.divisionName;
                //acc.Zone_Name__c = req.zoneName;
               //acc.BillingState = req.stateName;
                acc.District_Code__c = req.districtName;
                
                accList.add(acc);
            }
            
            // CHANGED: Database.update() instead of Database.upsert() -> update-only, never inserts
            Database.SaveResult[] accResults = new List<Database.SaveResult>();
            
            if (!accList.isEmpty()) {
                accResults = Database.update(accList, false);
            }
            
            Map<String, sapCustomerIntegrationWrapper.Result> resultMap = new Map<String, sapCustomerIntegrationWrapper.Result>();
            Map<String, Account> accMap = new Map<String, Account>();
            
            for (Integer i = 0; i < accResults.size(); i++) {
                
                Account a = accList[i];
                Database.SaveResult sr = accResults[i]; // CHANGED: was Database.UpsertResult
                
                sapCustomerIntegrationWrapper.Result r = new sapCustomerIntegrationWrapper.Result();
                
                r.sapCustomerexternalId = a.External_Id__c;
                r.accountId = sr.isSuccess() ? sr.getId() : null;
                r.operation = 'UPDATE'; // CHANGED: always UPDATE now, since creation is not allowed
                
                r.assignments = new List<sapCustomerIntegrationWrapper.AssignmentResult>();
                r.hierarchies = new List<sapCustomerIntegrationWrapper.HierarchyResult>();
                
                r.status = sr.isSuccess() ? 'SUCCESS' : 'ERROR';
                r.message = sr.isSuccess()
                    ? 'Account updated successfully'
                    : sr.getErrors()[0].getMessage();
                
                resultList.add(r);
                resultMap.put(a.External_Id__c, r);
                accMap.put(a.External_Id__c, a);
            }
            
            // NEW BLOCK: report SAP Codes skipped due to no matching Account under allowed Record Types
            for (String sapCode : skippedCustomers) {
                
                sapCustomerIntegrationWrapper.Result r = new sapCustomerIntegrationWrapper.Result();
                r.sapCustomerexternalId = sapCode;
                r.accountId = null;
                r.operation = 'SKIPPED';
                r.status = 'SKIPPED';
                r.message = 'No existing Account found for this SAP Code under the allowed Record Types. Creation not permitted.';
                
                r.assignments = new List<sapCustomerIntegrationWrapper.AssignmentResult>();
                r.hierarchies = new List<sapCustomerIntegrationWrapper.HierarchyResult>();
                
                resultList.add(r);
                resultMap.put(sapCode, r);
            }
            // ==================== [CHANGE END] ====================
            
            // for Business Mapping Response Structure -- UNCHANGED, DO NOT TOUCH
            if (accList.isEmpty()) {
                
                for (sapCustomerIntegrationWrapper.Request req : wrapper.records) {
                    
                    sapCustomerIntegrationWrapper.Result r =
                        new sapCustomerIntegrationWrapper.Result();
                    
                    r.sapCustomerexternalId = req.customer;
                    r.accountId = null;
                    r.operation = 'UPDATE';
                    r.status = 'SUCCESS';
                    r.message = 'Business Mapping Processed';
                    
                    r.assignments = new List<sapCustomerIntegrationWrapper.AssignmentResult>();
                    r.hierarchies = new List<sapCustomerIntegrationWrapper.HierarchyResult>();
                    
                    resultList.add(r);
                    resultMap.put(req.assignmentExternalId, r);
                }
            }
            
            // ---------------- EMPLOYEE CODES (UNCHANGED) ----------------
            Set<String> empCodeSet = new Set<String>();
            for (sapCustomerIntegrationWrapper.Request req : wrapper.records) {
                if (req.hierarchies != null) {
                    for (sapCustomerIntegrationWrapper.Hierarchy h : req.hierarchies) {
                        if (String.isNotBlank(h.bdmempid)) empCodeSet.add(h.bdmempid);
                        if (String.isNotBlank(h.cmempid)) empCodeSet.add(h.cmempid);
                        if (String.isNotBlank(h.dmempid)) empCodeSet.add(h.dmempid);
                        if (String.isNotBlank(h.gmempid)) empCodeSet.add(h.gmempid);
                        if (String.isNotBlank(h.gsroempid)) empCodeSet.add(h.gsroempid);
                        if (String.isNotBlank(h.kamempid)) empCodeSet.add(h.kamempid);
                        if (String.isNotBlank(h.nsmempid)) empCodeSet.add(h.nsmempid);
                        if (String.isNotBlank(h.rmempid)) empCodeSet.add(h.rmempid);
                        if (String.isNotBlank(h.rsmempid)) empCodeSet.add(h.rsmempid);
                        if (String.isNotBlank(h.Saeempid)) empCodeSet.add(h.Saeempid);
                        if (String.isNotBlank(h.sdeempid)) empCodeSet.add(h.sdeempid);
                        if (String.isNotBlank(h.sseempid)) empCodeSet.add(h.sseempid);
                        if (String.isNotBlank(h.tmempid)) empCodeSet.add(h.tmempid);
                        if (String.isNotBlank(h.zsmempid)) empCodeSet.add(h.zsmempid);
                    }
                }
            }
            
            Map<String, Id> empCodeToUserIdMap = new Map<String, Id>();
            if (!empCodeSet.isEmpty()) {
                for (User u : [
                    SELECT Id, Employee_Code__c
                    FROM User
                    WHERE Employee_Code__c IN :empCodeSet
                ]) {
                    empCodeToUserIdMap.put(u.Employee_Code__c, u.Id);
                }
            }
            
            Set<String> missingUsers = new Set<String>();
            
            // ================= USER UPDATE LOGIC (UNCHANGED) =================
            Set<Id> userIdsToProcess = new Set<Id>(empCodeToUserIdMap.values());
            
            Map<Id, User> userMap = new Map<Id, User>();
            if (!userIdsToProcess.isEmpty()) {
                userMap = new Map<Id, User>([
                    SELECT Id, Leadership__c, Main_Division__c, Sub_Division__c, Sales_District__c
                    FROM User
                    WHERE Id IN :userIdsToProcess
                ]);
            }
            
            Map<Id, User> usersToUpdateMap = new Map<Id, User>();
            
            for (sapCustomerIntegrationWrapper.Request req : wrapper.records) {
                
                String mainDivision = req.divisionName;
                String salesDistrict = req.salesDistrict;
                
                if (req.hierarchies != null) {
                    for (sapCustomerIntegrationWrapper.Hierarchy h : req.hierarchies) {
                        
                        String subDivision = h.subdivision;
                        
                        List<String> empIds = new List<String>{
                            h.bdmempid, h.cmempid, h.dmempid, h.gmempid,
                            h.gsroempid, h.kamempid, h.nsmempid, h.rmempid,
                            h.rsmempid, h.Saeempid, h.sdeempid, h.sseempid,
                            h.tmempid, h.zsmempid
                        };
                        
                        for (String empId : empIds) {
                            
                            if (String.isBlank(empId)) continue;
                            
                            Id userId = empCodeToUserIdMap.get(empId);
                            if (userId == null) continue;
                            
                            User existingUser = userMap.get(userId);
                            if (existingUser == null) continue;
                            
                            if (existingUser.Leadership__c == true) continue;
                            
                            if (!usersToUpdateMap.containsKey(userId)) {
                                User u = new User(Id = userId);
                                u.Main_Division__c = mainDivision;
                                u.Sub_Division__c = subDivision;
                                usersToUpdateMap.put(userId, u);
                            }
                        }
                    }
                }
            }
            
            if (!usersToUpdateMap.isEmpty()) {
                update usersToUpdateMap.values();
            }
            // ================= END USER UPDATE =================
            
            // ---------------- HIERARCHY (UNCHANGED) ----------------
            List<Org_Role_Hierarchy__c> hierarchyList = new List<Org_Role_Hierarchy__c>();
            Set<String> hierarchyExtIds = new Set<String>();
            
            for (sapCustomerIntegrationWrapper.Request req : wrapper.records) {
                if (req.hierarchies != null) {
                    for (sapCustomerIntegrationWrapper.Hierarchy h : req.hierarchies) {
                        if (h.hierarchyExternalId != null) {
                            hierarchyExtIds.add(h.hierarchyExternalId);
                        }
                    }
                }
            }
            
            Map<String, Org_Role_Hierarchy__c> existingHierarchyMap = new Map<String, Org_Role_Hierarchy__c>();
            for (Org_Role_Hierarchy__c h : [
                SELECT Id, External_ID__c
                FROM Org_Role_Hierarchy__c
                WHERE External_ID__c IN :hierarchyExtIds
            ]) {
                existingHierarchyMap.put(h.External_ID__c, h);
            }
            
            for (sapCustomerIntegrationWrapper.Request req : wrapper.records) {
                if (req.hierarchies != null) {
                    for (sapCustomerIntegrationWrapper.Hierarchy h : req.hierarchies) {
                        
                        if (h.hierarchyExternalId == null) continue;
                        
                        Org_Role_Hierarchy__c hr = new Org_Role_Hierarchy__c();
                        hr.External_ID__c = h.hierarchyExternalId;
                        hr.Name = h.hierarchyName;
                        hr.Is_Active__c = h.isActive;
                        hr.Country__c = h.countryKey;
                        hr.Division__c = h.divisionName;
                        hr.Sub_Division__c = h.subdivision;
                        hr.Region__c = h.zoneName;
                        
                        //below fields are carried from another object using object variable
                        hr.Business_Code__c = req.businessCode;
                        hr.Vertical_Code__c = req.verticalCode;
                        hr.Division_Code__c = req.divisionCode;
                        hr.Zone_Code__c = req.zoneCode;
                        hr.State_Code__c = req.stateCode;
                        hr.Sales_District__c = req.salesDistrict;
                        hr.Business_Name__c = req.businessName;
                        hr.Vertical_Name__c = req.verticalName;
                        hr.State_Name__c = req.stateName;
                        hr.District_Name__c = req.districtName;
                        //ends here
                        
                        hr.BDM__c = getUserIdFromEmpCode(h.bdmempid, empCodeToUserIdMap, missingUsers);
                        hr.BDM_EMPID__c = h.bdmempid;
                        hr.BDM_Level__c = h.bdmLevel;
                        hr.BDM_Name__c = h.bdm;
                        
                        hr.CM__c  = getUserIdFromEmpCode(h.cmempid, empCodeToUserIdMap, missingUsers);
                        hr.CM_EMPID__c = h.cmempid;
                        hr.CM_Level__c = h.cmLevel;
                        hr.CM_Name__c = h.cm;
                        
                        hr.DM__c  = getUserIdFromEmpCode(h.dmempid, empCodeToUserIdMap, missingUsers);
                        hr.DM_EMPID__c = h.dmempid;
                        hr.DM_Level__c = h.dmLevel;
                        hr.DM_Name__c = h.dm;
                        
                        hr.GM__c  = getUserIdFromEmpCode(h.gmempid, empCodeToUserIdMap, missingUsers);
                        hr.GM_EMPID__c = h.gmempid;
                        hr.GM_Level__c = h.gmLevel;
                        hr.GM_Name__c = h.gm;
                        
                        hr.GSRO__c = getUserIdFromEmpCode(h.gsroempid, empCodeToUserIdMap, missingUsers);
                        hr.GSRO_EMPID__c = h.gsroempid;
                        hr.GSRO_Level__c = h.gsroLevel;
                        hr.GSRO_Name__c = h.gsro;
                        
                        hr.KAM__c = getUserIdFromEmpCode(h.kamempid, empCodeToUserIdMap, missingUsers);
                        hr.KAM_EMPID__c = h.kamempid;
                        hr.KAM_Level__c = h.kamLevel;
                        hr.KAM_Name__c = h.kam;
                        
                        hr.NSM__c = getUserIdFromEmpCode(h.nsmempid, empCodeToUserIdMap, missingUsers);
                        hr.NSM_EMPID__c = h.nsmempid;
                        hr.NSM_Level__c = h.nsmLevel;
                        hr.NSM_Name__c = h.nsm;
                        
                        hr.RM__c  = getUserIdFromEmpCode(h.rmempid, empCodeToUserIdMap, missingUsers);
                        hr.RM_EMPID__c = h.rmempid;
                        hr.RM_Level__c = h.rmLevel;
                        hr.RM_Name__c = h.rm;
                        
                        hr.RSM__c = getUserIdFromEmpCode(h.rsmempid, empCodeToUserIdMap, missingUsers);
                        hr.RSM_EMPID__c = h.rsmempid;
                        hr.RSM_Level__c = h.rsmLevel;
                        hr.RSM_Name__c = h.rsm;
                        
                        hr.SAE__c = getUserIdFromEmpCode(h.Saeempid, empCodeToUserIdMap, missingUsers);
                        hr.SAE_EMPID__c = h.Saeempid;
                        hr.SAE_Level__c = h.saeLevel;
                        hr.SAE_Name__c = h.sae;
                        
                        hr.SDE__c = getUserIdFromEmpCode(h.sdeempid, empCodeToUserIdMap, missingUsers);
                        hr.SDE_EMPID__c = h.sdeempid;
                        hr.SDE_Level__c = h.sdeLevel;
                        hr.SDE_Name__c = h.sde;
                        
                        hr.SSE__c = getUserIdFromEmpCode(h.sseempid, empCodeToUserIdMap, missingUsers);
                        hr.SSE_EMPID__c = h.sseempid;
                        hr.SSE_Level__c = h.sseLevel;
                        hr.SSE_Name__c = h.sse;
                        
                        hr.TM__c  = getUserIdFromEmpCode(h.tmempid, empCodeToUserIdMap, missingUsers);
                        hr.TM_EMPID__c = h.tmempid;
                        hr.TM_Level__c = h.tmLevel;
                        hr.TM_Name__c = h.tm;
                        
                        hr.ZSM__c = getUserIdFromEmpCode(h.zsmempid, empCodeToUserIdMap, missingUsers);
                        hr.ZSM_EMPID__c = h.zsmempid;
                        hr.ZSM_Level__c = h.zsmLevel;
                        hr.ZSM_Name__c = h.zsm;
                        
                        hr.Business_Mapping__c = h.businessMapping;
                        hr.Customer_Mapping__c = h.customerMapping;
                        hr.Sales_District__c = req.salesDistrict;
                        
                        hierarchyList.add(hr);
                    }
                }
            }
            
            if (!hierarchyList.isEmpty()) {
                Database.UpsertResult[] hierarchyResults =
                    Database.upsert(hierarchyList, Org_Role_Hierarchy__c.External_ID__c, false);
                
                for (Integer i = 0; i < hierarchyResults.size(); i++) {
                    
                    Org_Role_Hierarchy__c h = hierarchyList[i];
                    Database.UpsertResult sr = hierarchyResults[i];
                    
                    String operation = existingHierarchyMap.containsKey(h.External_ID__c) ? 'UPDATE' : 'CREATE';
                    
                    for (sapCustomerIntegrationWrapper.Request req : wrapper.records) {
                        
                        String resultKey =
                            String.isNotBlank(req.customer)
                            ? req.customer
                            : req.assignmentExternalId;
                        
                        if (resultMap.containsKey(resultKey)) {
                            
                            sapCustomerIntegrationWrapper.HierarchyResult hr =
                                new sapCustomerIntegrationWrapper.HierarchyResult();
                            
                            hr.hierarchyexternalId = h.External_ID__c;
                            hr.recordId = sr.isSuccess() ? sr.getId() : null;
                            hr.hierarchyoperation = operation;
                            hr.status = sr.isSuccess() ? 'SUCCESS' : 'ERROR';
                            hr.message = sr.isSuccess()
                                ? (operation == 'CREATE' ? 'Hierarchy created successfully' : 'Hierarchy updated successfully')
                                : sr.getErrors()[0].getMessage();
                            
                            resultMap.get(resultKey).hierarchies.add(hr);
                        }
                    }
                }
            }
            
            // ---------------- ASSIGNMENTS (UNCHANGED) ----------------
            Set<String> assignmentExtIds = new Set<String>();
            for (sapCustomerIntegrationWrapper.Request req : wrapper.records) {
                if (req.hierarchies != null) {
                    for (sapCustomerIntegrationWrapper.Hierarchy h : req.hierarchies) {
                        if (h.hierarchyExternalId != null) {
                            assignmentExtIds.add(req.assignmentExternalId + '_' + h.hierarchyExternalId);
                        }
                    }
                }
            }
            
            Map<String, Org_Role_Hierarchy_Assignment__c> existingAssignMap = new Map<String, Org_Role_Hierarchy_Assignment__c>();
            for (Org_Role_Hierarchy_Assignment__c a : [
                SELECT Id, External_ID__c
                FROM Org_Role_Hierarchy_Assignment__c
                WHERE External_ID__c IN :assignmentExtIds
            ]) {
                existingAssignMap.put(a.External_ID__c, a);
            }
            
            List<Org_Role_Hierarchy_Assignment__c> assignList = new List<Org_Role_Hierarchy_Assignment__c>();
            Set<String> uniqueAssignIds = new Set<String>();
            
            for (sapCustomerIntegrationWrapper.Request req : wrapper.records) {
                if (req.hierarchies != null) {
                    for (sapCustomerIntegrationWrapper.Hierarchy h : req.hierarchies) {
                        if (h.isActive && h.hierarchyExternalId != null) {
                            
                            String extId = req.assignmentExternalId + '_' + h.hierarchyExternalId;
                            
                            if (!uniqueAssignIds.contains(extId)) {
                                uniqueAssignIds.add(extId);
                                
                                Org_Role_Hierarchy_Assignment__c a = new Org_Role_Hierarchy_Assignment__c();
                                a.External_ID__c = extId;
                                
                                if (String.isNotBlank(req.customer) && accMap.containsKey(req.customer)) {
                                    a.Account__c = accMap.get(req.customer).Id;
                                }
                                
                                a.Is_Active__c = req.Active;
                                a.Name = h.hierarchyName;
                                // External ID reference works now because hierarchy is already upserted above
                                a.Org_Role_Hierarchy__r = new Org_Role_Hierarchy__c(
                                    External_ID__c = h.hierarchyExternalId
                                );
                                
                                assignList.add(a);
                            }
                        }
                    }
                }
            }
            
            if (!assignList.isEmpty()) {
                Database.UpsertResult[] assignResults =
                    Database.upsert(assignList, Org_Role_Hierarchy_Assignment__c.External_ID__c, false);
                
                for (Integer i = 0; i < assignResults.size(); i++) {
                    
                    Org_Role_Hierarchy_Assignment__c a = assignList[i];
                    Database.UpsertResult sr = assignResults[i];
                    
                    String operation = existingAssignMap.containsKey(a.External_ID__c) ? 'UPDATE' : 'CREATE';
                    
                    for (String key : accMap.keySet()) {
                        if (accMap.get(key).Id == a.Account__c) {
                            
                            sapCustomerIntegrationWrapper.AssignmentResult ar =
                                new sapCustomerIntegrationWrapper.AssignmentResult();
                            
                            ar.assignmentexternalId = a.External_ID__c;
                            ar.recordId = sr.isSuccess() ? sr.getId() : null;
                            ar.assignmentoperation = operation;
                            ar.status = sr.isSuccess() ? 'SUCCESS' : 'ERROR';
                            ar.message = sr.isSuccess()
                                ? (operation == 'CREATE' ? 'Assignment created successfully' : 'Assignment updated successfully')
                                : sr.getErrors()[0].getMessage();
                            
                            if (resultMap.containsKey(key)) {
                                resultMap.get(key).assignments.add(ar);
                            }
                            break;
                        }
                    }
                }
            }
            
            res.success = true;
            res.message = missingUsers.isEmpty()
                ? 'Records Processed Successfully'
                : 'Processed with missing Users: ' + missingUsers;
            res.results = resultList;
            
        } catch (Exception e) {
            res.success = false;
            res.message = e.getMessage();
        }
        
        return res;
    }
}
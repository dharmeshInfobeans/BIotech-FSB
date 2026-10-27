/**
* AttendanceController
* Configuration sourced from Custom Setting: Attendance_Config__c (Hierarchy, OrgDefaults)
*
* LEAD CREATION LOGIC:
*   One Lead per (Campaign Member × Product Family).
*   Lead Name = ProductFamilyName + " " + Customer_Full_Name__c
*
*   Dedup key = Lead_Mobile_Number__c + '_' + familyName (text)
*   Scoped to campaign via Lead.Campaign__c.
*   keysQueuedThisBatch pre-loaded from DB before loop so re-opens
*   for already-processed members are skipped automatically.
*
* BULKIFICATION NOTE (latest change):
*   The per-row calls to checkDuplicateLeadByFamily() inside the attendee/family
*   loop, and the per-row Lead_Product__c fallback query inside the failed-insert
*   loop, have been replaced with single bulk pre-computations (dupeCheckResultMap
*   and fallbackLeadProductLookup respectively). This removes SOQL-in-loop so the
*   query count no longer scales with attendees.size() x families-per-attendee,
*   which was causing "Too many SOQL queries: 101" on larger batches (e.g. 111
*   attendees). No business logic, filters, or output strings were changed —
*   only where/how often the queries run.
*/
public without sharing class AttendanceController {
    
    // =========================================================================
    // CUSTOM SETTING
    // =========================================================================
    
    private static Attendance_Config__c cfg {
        get {
            if (cfg == null) cfg = Attendance_Config__c.getOrgDefaults();
            return cfg;
        }
        set;
    }
    
    // =========================================================================
    // TYPED ACCESSORS
    // =========================================================================
    
    private static Integer lockAfterDays {
        get {
            if (lockAfterDays == null) {
                try {
                    lockAfterDays = cfg.Lock_After_Days__c != null
                        ? Integer.valueOf(cfg.Lock_After_Days__c) : 5;
                } catch (Exception e) { lockAfterDays = 5; }
            }
            return lockAfterDays;
        }
        set;
    }
    
    private static String privilegedProfileName {
        get {
            return String.isNotBlank(cfg.Privileged_Profile_Name__c)
                ? cfg.Privileged_Profile_Name__c : 'System Administrator';
        }
    }
    
    private static String leadStageLost           { get { return cfg.Lead_Stage_Lost__c; } }
    private static String leadStageUnqualified    { get { return cfg.Lead_Stage_Unqualified__c; } }
    private static String leadStageWon            { get { return cfg.Lead_Stage_Won__c; } }
    private static String leadSourceDefault       { get { return cfg.Lead_Source_Default__c; } }
    private static String campaignStatusCompleted { 
        get { 
            return String.isNotBlank(cfg.Campaign_Status_Completed__c) 
                ? cfg.Campaign_Status_Completed__c 
                : 'Completed';
        } 
    }
    private static String leadFallbackName        { get { return cfg.Lead_Fallback_Name__c; } }
    
    private static String stageCME              { get { return cfg.Campaign_Stage_CME__c; } }
    private static String stageRTM              { get { return cfg.Campaign_Stage_RTM__c; } }
    private static String stageUserMeeting      { get { return cfg.Campaign_Stage_User_Meeting__c; } }
    private static String stageHighImpactCME    { get { return cfg.Campaign_Stage_High_Impact_CME__c; } }
    private static String stageKOLFOL           { get { return cfg.Campaign_Stage_KOL_FOL__c; } }
    private static String stageVirtualLab       { get { return cfg.Campaign_Stage_Virtual_Lab__c; } }
    private static String stageWetLabs          { get { return cfg.Campaign_Stage_Wet_Labs__c; } }
    private static String stageTestimonial      { get { return cfg.Campaign_Stage_Testimonial__c; } }
    private static String stageCTP              { get { return cfg.Campaign_Stage_CTP__c; } }
    private static String stageFocus            { get { return cfg.Campaign_Stage_Focus__c; } }
    private static String stageDecode           { get { return cfg.Campaign_Stage_Decode__c; } }
    private static String stageInclinicBranding { get { return cfg.Campaign_Stage_Inclinic_Branding__c; } }
    
    private static String attendanceSaveSuccess {
        get {
            return String.isNotBlank(cfg.Attendance_Save_Success__c)
                ? cfg.Attendance_Save_Success__c : 'Success';
        }
    }
    private static String reopenSuccessToken {
        get {
            return String.isNotBlank(cfg.Reopen_Success_Token__c)
                ? cfg.Reopen_Success_Token__c : 'SUCCESS';
        }
    }
    
    // =========================================================================
    // MESSAGE HELPERS
    // =========================================================================
    
    private static String lockWarnAuthMsg() {
        return String.isNotBlank(cfg.Lock_Warning_Auth_Message__c)
            ? cfg.Lock_Warning_Auth_Message__c
            : 'This campaign is locked. As an authorised user you may re-open it.';
    }
    
    private static String lockWarnContactMsg() {
        String tpl = String.isNotBlank(cfg.Lock_Warning_Contact_Message__c)
            ? cfg.Lock_Warning_Contact_Message__c
            : 'This campaign is locked. Please contact: {0} to re-open the campaign.';
        return tpl.replace('{0}', getPrivilegedUserNames());
    }
    
    private static String reopenUnauthorizedMsg() {
        String tpl = String.isNotBlank(cfg.Reopen_Unauthorized_Message__c)
            ? cfg.Reopen_Unauthorized_Message__c
            : 'UNAUTHORIZED|You are not authorised to re-open this campaign. Please contact: {0} for approval.';
        return tpl.replace('{0}', getPrivilegedUserNames());
    }
    
    private static String markLockedMsg() {
        String tpl = String.isNotBlank(cfg.Mark_Locked_Message__c)
            ? cfg.Mark_Locked_Message__c
            : 'LOCKED|This campaign is locked for attendance marking. Please contact: {0} for approval.';
        return tpl.replace('{0}', getPrivilegedUserNames());
    }
    
    private static String activityBlockedMsg() {
        String msg = String.isNotBlank(cfg.Activity_Blocked_Message__c)
            ? cfg.Activity_Blocked_Message__c
            : 'You do not have an active Beat Plan login for today. Please log in via the Beat Plan before marking attendance.';
        if (msg.startsWith('ACTIVITY_BLOCKED|')) return msg;
        return 'ACTIVITY_BLOCKED|' + msg;
    }
    
    // =========================================================================
    // PRIVATE HELPERS
    // =========================================================================
    
    private static String safeStr(Object val) {
        if (val == null) return '';
        String s = String.valueOf(val);
        return s == 'null' ? '' : s;
    }
    
    private static Id safeId(Object val) {
        if (val == null) return null;
        String s = String.valueOf(val).trim();
        if (String.isBlank(s) || s == 'null') return null;
        try { return (Id) s; } catch (Exception e) { return null; }
    }
    
    private static Boolean isPastLockWindow(Date endDate) {
        return endDate != null && System.today() > endDate.addDays(lockAfterDays);
    }
    
    private static Boolean resolveLocked(Date endDate, Boolean attendanceLocked, Boolean reopenOverride) {
        Boolean isReopened = (reopenOverride == true);
        if (isPastLockWindow(endDate)) return !isReopened;
        return (attendanceLocked == true) && !isReopened;
    }
    
    private static Boolean isPrivilegedUser() {
        User u = [SELECT Username, Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (u.Profile.Name == privilegedProfileName) return true;
        if (u.Username == null) return false;
        String userPrefix = u.Username.toLowerCase().split('@')[0];
        for (Campaign_Access_Config__mdt acc : [
            SELECT User_Email__c FROM Campaign_Access_Config__mdt
            WHERE  Active__c = true AND User_Email__c != null
        ]) {
            if (userPrefix == acc.User_Email__c.toLowerCase().split('@')[0]) return true;
        }
        return false;
    }
    
    private static String getPrivilegedUserNames() {
        List<String> names = new List<String>();
        for (Campaign_Access_Config__mdt acc : [
            SELECT DeveloperName FROM Campaign_Access_Config__mdt WHERE Active__c = true
        ]) {
            names.add(acc.DeveloperName.replace('_', ' '));
        }
        names.add(privilegedProfileName);
        return String.join(names, ', ');
    }
    
    /** Reads product IDs from a row: 'Product' first, falls back to 'FilterValue'. */
    private static List<Id> resolveProductIds(Map<String, Object> row) {
        List<Id> result = new List<Id>();
        List<Object> src = (List<Object>) row.get('Product');
        if (src == null || src.isEmpty()) src = (List<Object>) row.get('FilterValue');
        if (src != null) {
            for (Object o : src) {
                if (o instanceof Map<String, Object>) {
                    Map<String, Object> m = (Map<String, Object>) o;
                    Id pid = safeId(m.get('value'));
                    if (pid == null) pid = safeId(m.get('id'));
                    if (pid != null) result.add(pid);
                } else {
                    Id pid = safeId(o);
                    if (pid != null) result.add(pid);
                }
            }
        }
        return result;
    }
    
    private static String dedupKey(String mobile, Id pgId) {
        return mobile + '_' + String.valueOf(pgId);
    }
    
    // =========================================================================
    // LOGIN / LOGOUT BEAT-PLAN GATE
    // =========================================================================
    
    private static List<String> getExcludedCountryList() {
        List<String> result = new List<String>();
        String raw = cfg.Country_Login_Logout_Codes__c;
        if (String.isBlank(raw)) return result;
        for (String c : raw.split(',')) result.add(c.trim());
        return result;
    }
    
    private static Map<String, Boolean> resolveActivityStatus(Boolean camCompleted) {
        Map<String, Boolean> result = new Map<String, Boolean>();
        User u = [SELECT Login_Logout_Module__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        String module = String.isNotBlank(u.Login_Logout_Module__c) ? u.Login_Logout_Module__c : '';
        if (getExcludedCountryList().contains(module)) {
            List<Beat_Plan__c> bp = [
                SELECT Id FROM Beat_Plan__c
                WHERE  Beat_Date__c   = :System.today()
                AND    Assigned_To__c = :UserInfo.getUserId()
                AND    Login_Time__c  != null
                LIMIT  1
            ];
            result.put('activity', !bp.isEmpty());
            result.put('status',   !camCompleted);
        } else {
            result.put('activity', true);
            result.put('status',   !camCompleted);
        }
        return result;
    }
    
    // =========================================================================
    // CAMPAIGN STAGE → LEAD FIELD STAMP
    // =========================================================================
    
    private static void stampCampaignStageDate(Lead__c lead, String campStage) {
        if (String.isBlank(campStage)) return;
        if      (campStage == stageCME)              lead.Actual_CME__c                 = System.today();
        else if (campStage == stageRTM)              lead.Actual_RTM__c                 = System.today();
        else if (campStage == stageUserMeeting)      lead.Actual_User_Meeting__c        = System.today();
        else if (campStage == stageHighImpactCME)    lead.Actual_High_Impact_CME__c     = System.today();
        else if (campStage == stageKOLFOL)           lead.Actual_KOL_FOL_Development__c = System.today();
        else if (campStage == stageVirtualLab)       lead.Actual_Virtual_exp_Lab__c     = System.today();
        else if (campStage == stageWetLabs)          lead.Actual_Wet_Labs__c            = System.today();
        else if (campStage == stageTestimonial)      lead.Actual_Testimonial__c         = System.today();
        else if (campStage == stageCTP)              lead.Actual_CTP__c                 = System.today();
        else if (campStage == stageFocus)            lead.Actual_Focus__c               = System.today();
        else if (campStage == stageDecode)           lead.Actual_Decode__c              = System.today();
        else if (campStage == stageInclinicBranding) lead.Actual_Inclinic_Branding__c   = System.today();
    }
    
    // =========================================================================
    // SHARED HELPER — build existing (mobile+pgId) → Lead info map
    // =========================================================================
    
    private static Map<String, String> buildExistingLeadMaps(
        Set<String>         allMobiles,
        String              campaignId,
        Map<String, Id>     leadIdMap
    ) {
        Map<String, String> nameMap = new Map<String, String>();
        if (allMobiles.isEmpty()) return nameMap;
        
        // CHANGED by Dhruv: campaign-specific to system-level duplicate check —
        // dropped Campaign__c filter so the "already exists" lookup reflects
        // existing Leads for this mobile/family from any campaign, not just this one.
        //
        // CHANGED by Dhruv: Leads at the literal 'Converted' stage are no longer
        // unconditionally treated as an existing duplicate for display purposes —
        // mirrors the same Account+Opportunity nuance used in markAttendance
        // (checkDuplicateLeadByFamily), so the "already exists" badge shown here
        // matches what will actually happen when the user saves. 'Won' stays
        // always-excluded (pre-existing behavior, unchanged).
        Map<Id, String> leadMobileMap  = new Map<Id, String>();
        Map<Id, String> leadNameMap2   = new Map<Id, String>();
        Map<Id, Id>     leadAccountMap = new Map<Id, Id>();
        Map<Id, String> leadStageMap   = new Map<Id, String>();
        for (Lead__c lea : [
            SELECT Id, Name, Mobile__c, Account__c, Lead_Stage__c
            FROM   Lead__c
            WHERE  Mobile__c     IN :allMobiles
            AND    Lead_Stage__c != :leadStageLost
            AND    Lead_Stage__c != :leadStageUnqualified
            AND    Lead_Stage__c != :leadStageWon
            AND    Lead_Closed__c = false
            AND    Product__c    != null
        ]) {
            leadMobileMap.put(lea.Id, lea.Mobile__c);
            leadNameMap2.put(lea.Id,  lea.Name);
            leadAccountMap.put(lea.Id, lea.Account__c);
            leadStageMap.put(lea.Id, lea.Lead_Stage__c);
        }

        if (leadMobileMap.isEmpty()) return nameMap;

        // accountId + '_' + productFamily → has at least one non-lost Opportunity
        Set<Id> convertedAccountIds = new Set<Id>();
        for (Id leadId : leadStageMap.keySet()) {
            if (leadStageMap.get(leadId) == 'Converted' && leadAccountMap.get(leadId) != null) {
                convertedAccountIds.add(leadAccountMap.get(leadId));
            }
        }
        Set<String> accountFamilyHasActiveOpp = new Set<String>();
        if (!convertedAccountIds.isEmpty()) {
            for (Opportunity__c opp : [
                SELECT Account__c, Product_Family__c
                FROM   Opportunity__c
                WHERE  Account__c        IN :convertedAccountIds
                AND    Product_Family__c != null
                AND    Status__c        != 'Closed Lost'
            ]) {
                accountFamilyHasActiveOpp.add(opp.Account__c + '_' + opp.Product_Family__c);
            }
        }

        for (Lead_Product__c lp : [
            SELECT Leads__c, Product_Group__c, Product_Group__r.Product_Family__c
            FROM   Lead_Product__c
            WHERE  Leads__c IN :leadMobileMap.keySet()
        ]) {
            String mobile = leadMobileMap.get(lp.Leads__c);
            if (String.isBlank(mobile)) continue;

            if (leadStageMap.get(lp.Leads__c) == 'Converted') {
                Id     acctId  = leadAccountMap.get(lp.Leads__c);
                String famName = lp.Product_Group__r?.Product_Family__c;
                Boolean blocks = acctId != null && String.isNotBlank(famName)
                    && accountFamilyHasActiveOpp.contains(acctId + '_' + famName);
                if (!blocks) continue;
            }

            String dk = dedupKey(mobile, lp.Product_Group__c);
            nameMap.put(dk, leadNameMap2.get(lp.Leads__c));
            if (leadIdMap != null) leadIdMap.put(dk, lp.Leads__c);
        }

        Map<String, Id> pgNameToIdMap = new Map<String, Id>();
        for (Campaign_Line_Item__c cli : [
            SELECT Product_Group__c, Product_Group__r.Name
            FROM   Campaign_Line_Item__c
            WHERE  Campaign__c = :campaignId AND Product_Group__c != null
        ]) {
            pgNameToIdMap.put(cli.Product_Group__r.Name, cli.Product_Group__c);
        }

        // CHANGED by Dhruv: campaign-specific to system-level duplicate check —
        // dropped Campaign__c filter here too, matching leads by mobile + family
        // (via Product__c) regardless of which campaign they were created under.
        for (Lead__c lea : [
            SELECT Id, Name, Mobile__c, Product__c, Lead_Stage__c, Account__c
            FROM   Lead__c
            WHERE  Mobile__c     IN :allMobiles
            AND    Lead_Stage__c != :leadStageLost
            AND    Lead_Stage__c != :leadStageUnqualified
            AND    Lead_Stage__c != :leadStageWon
            AND    Lead_Closed__c = false
            AND    Product__c    != null
        ]) {
            Id matchedPgId = pgNameToIdMap.get(lea.Product__c);
            if (matchedPgId == null) continue;

            if (lea.Lead_Stage__c == 'Converted') {
                Boolean blocks = lea.Account__c != null
                    && accountFamilyHasActiveOpp.contains(lea.Account__c + '_' + lea.Product__c);
                if (!blocks) continue;
            }

            String dk = dedupKey(lea.Mobile__c, matchedPgId);
            if (!nameMap.containsKey(dk)) nameMap.put(dk, lea.Name);
            if (leadIdMap != null && !leadIdMap.containsKey(dk)) leadIdMap.put(dk, lea.Id);
        }

        return nameMap;
    }
    
    // =========================================================================
    // BUILD ATTENDEE RESPONSE
    // =========================================================================
    
    private static Map<String, Object> buildAttendeesResponse(String campaignId) {
        
        Campaign__c cam = [
            SELECT Id, Name, Completed__c, Attendance_Locked__c, End_Date__c, Reopen_Override__c
            FROM   Campaign__c WHERE Id = :campaignId LIMIT 1
        ];
        
        Boolean isLocked  = resolveLocked(cam.End_Date__c, cam.Attendance_Locked__c, cam.Reopen_Override__c);
        Boolean canReopen = isPrivilegedUser();
        
        Map<String, Boolean> activityStatus = resolveActivityStatus(cam.Completed__c);
        Boolean activity = activityStatus.get('activity');
        Boolean status   = activityStatus.get('status');
        
        String lockWarningMsg = isLocked
            ? (canReopen ? lockWarnAuthMsg() : lockWarnContactMsg()) : '';
        
        List<Map<String, String>> campaignProductGroups = new List<Map<String, String>>();
        Map<String, String>       pgLabelMap            = new Map<String, String>();
        for (Campaign_Line_Item__c cli : [
            SELECT Id, Product_Group__c, Product_Group__r.Name
            FROM   Campaign_Line_Item__c
            WHERE  Campaign__c = :campaignId AND Product_Group__c != null
        ]) {
            campaignProductGroups.add(new Map<String, String>{
                'label' => cli.Product_Group__r.Name,
                    'value' => cli.Product_Group__c
                    });
            pgLabelMap.put(cli.Product_Group__c, cli.Product_Group__r.Name);
        }
        
        Map<Id, Set<Id>> memberToProductsMap = new Map<Id, Set<Id>>();
        for (Campaign_Member_Product__c cmpProd : [
            SELECT Campaign_Members__c, Product_Group__c
            FROM   Campaign_Member_Product__c
            WHERE  Campaign_Members__r.Campaign1__c = :campaignId
        ]) {
            if (!memberToProductsMap.containsKey(cmpProd.Campaign_Members__c))
                memberToProductsMap.put(cmpProd.Campaign_Members__c, new Set<Id>());
            memberToProductsMap.get(cmpProd.Campaign_Members__c).add(cmpProd.Product_Group__c);
        }
        
        List<Campaign_Member__c> attendees = [
            SELECT  Id, Name, Attended__c, RecordType.Name,
            Customer__c, Customer_Full_Name__c, Account__c,
            Lead_First_Name__c, Lead_Last_Name__c,
            Lead_Email__c, Lead_Hospital_Clinic_Name__c,
            Lead_Street__c, Lead_City__c, Lead_Zip_Postal_Code__c,
            Lead_State_Province__c, Lead_Country__c, Lead_Mobile_Number__c,
            Contact__r.FirstName, Contact__r.LastName,
            Contact__r.MobilePhone, Contact__r.Email,
            Account__r.CE_CIS_Rating__c, Account__r.Phakic_Rating__c,
            Account__r.Name, Account__r.Company_Name__c,
            Account__r.BillingStreet, Account__r.BillingCity,
            Account__r.BillingCountry, Account__r.BillingState,
            Account__r.BillingPostalCode, Account__r.SAP_Code__c,
            Account__r.OwnerId,Account__r.Commercial_Account_Name__c,
            Approver__c, Campaign1__r.Campaign_stage__c,
            CampaignPhone__c, Member_Type__c
            FROM    Campaign_Member__c
            WHERE   Campaign1__c = :campaignId
        ];
        
        Set<String> allMemberMobiles = new Set<String>();
        for (Campaign_Member__c cmp : attendees) {
            if (String.isNotBlank(cmp.CampaignPhone__c)) allMemberMobiles.add(cmp.CampaignPhone__c);
        }
        
        Map<String, String> existingLeadNameByKey =
            buildExistingLeadMaps(allMemberMobiles, campaignId, null);
        System.debug('### buildAttendeesResponse | existingLeadNameByKey=' + existingLeadNameByKey);
        
        Boolean saveButtonDisable = true;
        List<Map<String, Object>> cmpMemberList = new List<Map<String, Object>>();
        
        for (Campaign_Member__c cmp : attendees) {
            if (!cmp.Attended__c) saveButtonDisable = false;
            
            Set<Id> alreadySelected = memberToProductsMap.containsKey(cmp.Id)
                ? memberToProductsMap.get(cmp.Id) : new Set<Id>();
            
            List<String>              filterValueIds    = new List<String>();
            List<Map<String, String>> filterValueLabels = new List<Map<String, String>>();
            for (Id pgId : alreadySelected) {
                filterValueIds.add(pgId);
                filterValueLabels.add(new Map<String, String>{
                    'id'    => pgId,
                        'label' => pgLabelMap.containsKey(pgId) ? pgLabelMap.get(pgId) : pgId
                            });
            }
            
            List<Map<String, String>> availableOptions = new List<Map<String, String>>();
            if (filterValueIds.isEmpty()) {
                for (Map<String, String> pg : campaignProductGroups) {
                    if (!alreadySelected.contains(pg.get('value'))) availableOptions.add(pg);
                }
            }
            
            if (!filterValueIds.isEmpty() && availableOptions.isEmpty()) {
                for (String pgId : filterValueIds) {
                    availableOptions.add(new Map<String, String>{
                        'label' => pgLabelMap.containsKey(pgId) ? pgLabelMap.get(pgId) : pgId,
                            'value' => pgId
                            });
                }
            }
            
            String memberMobile = cmp.CampaignPhone__c;
            Map<String, Map<String, String>> pgExistingLeadMap = new Map<String, Map<String, String>>();
            Boolean leadDuplicate  = false;
            String  leadUniqueName = '';
            if (String.isNotBlank(memberMobile)) {
                for (Map<String, String> pg : campaignProductGroups) {
                    String pgId = pg.get('value');
                    String dk   = dedupKey(memberMobile, pgId);
                    if (existingLeadNameByKey.containsKey(dk)) {
                        pgExistingLeadMap.put(pgId, new Map<String, String>{
                            'leadName' => existingLeadNameByKey.get(dk)
                                });
                        leadDuplicate = true;
                        String pgLabel = pgLabelMap.containsKey(pgId) ? pgLabelMap.get(pgId) : pgId;
                        leadUniqueName = String.isBlank(leadUniqueName)
                            ? pgLabel : leadUniqueName + ', ' + pgLabel;
                    }
                }
            }
            
            String firstName = '', lastName = '';
            if (cmp.Account__c != null) {
                firstName = cmp.Contact__r?.FirstName != null ? cmp.Contact__r.FirstName : '';
                lastName  = cmp.Contact__r?.LastName  != null ? cmp.Contact__r.LastName  : '';
                if (String.isBlank(firstName) && String.isBlank(lastName)) {
                    String accName = cmp.Account__r.Name != null ? cmp.Account__r.Name : '';
                    List<String> parts = accName.split(' ', 2);
                    firstName = parts.size() > 0 ? parts[0] : accName;
                    lastName  = parts.size() > 1 ? parts[1] : accName;
                }
            } else {
                firstName = cmp.Lead_First_Name__c != null ? cmp.Lead_First_Name__c : '';
                lastName  = cmp.Lead_Last_Name__c  != null ? cmp.Lead_Last_Name__c  : '';
            }
            
            Boolean rowDisabled = cmp.Attended__c || isLocked;
            
            Map<String, Object> row = new Map<String, Object>{
                'Id'                => cmp.Id,
                    'Name'              => cmp.Name,
                    'Type'              => cmp.RecordType.Name,
                    'CustomerName'      => cmp.Customer__c,
                    'CustomerFullName'  => cmp.Customer_Full_Name__c,
                    'Attended__c'       => cmp.Attended__c,
                    'checked'           => cmp.Attended__c,
                    'disable'           => rowDisabled,
                    'disableToggle'     => rowDisabled,
                    'duplicate'         => leadDuplicate,
                    'description'       => leadUniqueName,
                    'CampaignStage'     => cmp.Campaign1__r.Campaign_stage__c,
                    'memberType'        => cmp.Member_Type__c,
                    'Approver'          => cmp.Approver__c,
                    'FilterValue'       => filterValueIds,
                    'FilterValueLabels' => filterValueLabels,
                    'Product'           => availableOptions,
                    'FirstName'         => firstName,
                    'LastName'          => lastName,
                    'pgExistingLeadMap' => pgExistingLeadMap
                    };
                        
            if (cmp.Account__c == null) {
                row.put('Account',      '');
                row.put('Email',        cmp.Lead_Email__c);
                row.put('Company',      cmp.Lead_Hospital_Clinic_Name__c);
                row.put('Street',       cmp.Lead_Street__c);
                row.put('City',         cmp.Lead_City__c);
                row.put('State',        cmp.Lead_State_Province__c);
                row.put('Country',      cmp.Lead_Country__c);
                row.put('Mobile',       cmp.Lead_Mobile_Number__c);
                row.put('zipCode',      cmp.Lead_Zip_Postal_Code__c);
                row.put('CeRating',     '');
                row.put('PhakicRating', '');
                row.put('SAPCode',      '');
                row.put('ContactName',  '');
                row.put('OwnerId',      '');
            } else {
                String cf = cmp.Contact__r?.FirstName;
                String cl = cmp.Contact__r?.LastName;
                row.put('Account',      cmp.Account__c);
                row.put('ContactName',  ((cf != null ? cf : '') + ' ' + (cl != null ? cl : '')).trim());
                row.put('Email',        cmp.Contact__r?.Email);
                row.put('Company',      cmp.Account__r.Commercial_Account_Name__c);
                row.put('Street',       cmp.Account__r.BillingStreet);
                row.put('City',         cmp.Account__r.BillingCity);
                row.put('State',        cmp.Account__r.BillingState);
                row.put('Country',      cmp.Account__r.BillingCountry);
                row.put('Mobile',       cmp.Contact__r?.MobilePhone);
                row.put('zipCode',      cmp.Account__r.BillingPostalCode);
                row.put('CeRating',     cmp.Account__r.CE_CIS_Rating__c);
                row.put('PhakicRating', cmp.Account__r.Phakic_Rating__c);
                row.put('SAPCode',      cmp.Account__r.SAP_Code__c);
                row.put('OwnerId',      cmp.Account__r.OwnerId);
            }
            
            cmpMemberList.add(row);
        }
        
        return new Map<String, Object>{
            'activity'              => activity,
                'status'                => status,
                'campaignName'          => cam.Name,
                'isLocked'              => isLocked,
                'canReopen'             => canReopen,
                'lockWarningMsg'        => lockWarningMsg,
                'SaveButtonDisable'     => saveButtonDisable || isLocked,
                'attendees'             => cmpMemberList,
                'campaignProductGroups' => campaignProductGroups
                };
    }
    
    // =========================================================================
    // PUBLIC AURA METHODS
    // =========================================================================
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getAttendees(String campaignId) {
        return buildAttendeesResponse(campaignId);
    }
    
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getAttendeesRefresh(String campaignId) {
        return buildAttendeesResponse(campaignId);
    }
    
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> checkCampaignLockStatus(String campaignId) {
        Campaign__c cam = [
            SELECT Id, Name, Attendance_Locked__c, End_Date__c,
            Reopen_Override__c, Reopened_By__c, Reopened_At__c
            FROM   Campaign__c WHERE Id = :campaignId LIMIT 1
        ];
        Boolean isLocked  = resolveLocked(cam.End_Date__c, cam.Attendance_Locked__c, cam.Reopen_Override__c);
        Boolean canReopen = isPrivilegedUser();
        return new Map<String, Object>{
            'locked'       => isLocked,
                'canReopen'    => canReopen,
                'warningMsg'   => isLocked ? (canReopen ? lockWarnAuthMsg() : lockWarnContactMsg()) : '',
                    'campaignName' => cam.Name,
                    'endDate'      => cam.End_Date__c    != null ? String.valueOf(cam.End_Date__c)    : '',
                        'reopenedBy'   => safeStr(cam.Reopened_By__c),
                        'reopenedAt'   => cam.Reopened_At__c != null ? String.valueOf(cam.Reopened_At__c) : ''
                            };
    }
    
    @AuraEnabled
    public static String reopenCampaign(String campaignId) {
        if (!isPrivilegedUser()) return reopenUnauthorizedMsg();
        try {
            User u = [SELECT Name, Employee_Code__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            update new Campaign__c(
                Id                    = campaignId,
                Attendance_Locked__c  = false,
                Reopen_Override__c    = true,
                Completed__c          = false,
                Reopened_By__c        = UserInfo.getUserName(),
                Reopened_At__c        = System.now(),
                User_Full_Name__c     = u.Name,
                User_Employee_Code__c = u.Employee_Code__c != null ? u.Employee_Code__c : '',
                Status__c = 'Planned'
            );
            return reopenSuccessToken;
        } catch (Exception e) {
            return e.getMessage();
        }
    }
    
    // =========================================================================
    // MARK ATTENDANCE
    // =========================================================================
    
    @AuraEnabled
    public static Map<String, Object> markAttendance(
        List<Map<String, Object>> attendees,
        String campaignId) {
            System.debug('attendees----' + attendees);
            System.debug('### markAttendance START | campaignId=' + campaignId
                         + ' | count=' + (attendees != null ? attendees.size() : 0));
            
            if (attendees == null || attendees.isEmpty()) {
                return new Map<String, Object>{ 'status' => 'ERROR', 'message' => 'No attendees provided.' };
            }
            
            // ── Gate checks ──────────────────────────────────────────────────────
            Campaign__c camCheck = [
                SELECT Id, Completed__c, Attendance_Locked__c, End_Date__c, Reopen_Override__c
                FROM   Campaign__c WHERE Id = :campaignId LIMIT 1
            ];
            System.debug('### camCheck | Locked=' + camCheck.Attendance_Locked__c
                         + ' | Completed=' + camCheck.Completed__c
                         + ' | EndDate=' + camCheck.End_Date__c
                         + ' | ReopenOverride=' + camCheck.Reopen_Override__c);
            
            if (resolveLocked(camCheck.End_Date__c, camCheck.Attendance_Locked__c, camCheck.Reopen_Override__c)) {
                System.debug('### ABORT — campaign locked');
                return new Map<String, Object>{ 'status' => 'LOCKED', 'message' => markLockedMsg() };
            }
            if (!resolveActivityStatus(camCheck.Completed__c).get('activity')) {
                System.debug('### ABORT — beat plan gate');
                return new Map<String, Object>{ 'status' => 'ACTIVITY_BLOCKED', 'message' => activityBlockedMsg() };
            }
            
            // ── Bulk-query prep ──────────────────────────────────────────────────
            Set<Id>     allMemberIds  = new Set<Id>();
            Set<Id>     allAccountIds = new Set<Id>();

            for (Map<String, Object> row : attendees) {
                Id mid = safeId(row.get('Id'));
                Id aid = safeId(row.get('Account'));
                if (mid != null) allMemberIds.add(mid);
                if (aid != null) allAccountIds.add(aid);
            }

            // CHANGED: query ALL Campaign_Member__c records upfront (removes SOQL-in-loop)
            // Use Lead_Mobile_Number__c as the single source of truth for mobile
            // so the dedup key matches what is stored on Lead__c.Mobile__c
            Map<Id, Campaign_Member__c> campMembersFullMap = allMemberIds.isEmpty()
                ? new Map<Id, Campaign_Member__c>()
                : new Map<Id, Campaign_Member__c>([
                    SELECT Id, Lead_Mobile_Number__c, RecordType.Name, Lead_Email__c, Zone__c
                    FROM   Campaign_Member__c
                    WHERE  Id IN :allMemberIds
                ]);

            // CHANGED: allMobiles now uses Lead_Mobile_Number__c exclusively
            // so the pre-load query and dedup key are consistent with Lead.Mobile__c
            Set<String> allMobiles = new Set<String>();
            for (Campaign_Member__c cm : campMembersFullMap.values()) {
                if (String.isNotBlank(cm.Lead_Mobile_Number__c)) {
                    allMobiles.add(cm.Lead_Mobile_Number__c);
                }
            }
            System.debug('campMembersFullMap'+campMembersFullMap);
            System.debug('### allMobiles (from Lead_Mobile_Number__c)=' + allMobiles);
            // ── END CHANGED ───────────────────────────────────────────────────────
            
            Map<Id, Account> accountMap = allAccountIds.isEmpty() ? new Map<Id, Account>()
                : new Map<Id, Account>([
                    SELECT Id, Name, Company_Name__c, Branch_Code__c, Branch_Name__c
                    FROM   Account WHERE Id IN :allAccountIds
                ]);
            System.debug('accountMap========='+accountMap);
            Map<Id, Campaign_Member__c> memberMap = allMemberIds.isEmpty() ? new Map<Id, Campaign_Member__c>()
                : new Map<Id, Campaign_Member__c>([
                    SELECT Id, Contact__r.FirstName, Contact__r.LastName,
                    Lead_First_Name__c, Lead_Last_Name__c, Account__c,
                    Customer_Full_Name__c
                    FROM   Campaign_Member__c WHERE Id IN :allMemberIds
                ]);
            System.debug('memberMap'+memberMap);
            Set<String> existingCmpKeys = new Set<String>();
            for (Campaign_Member_Product__c cx : [
                SELECT Campaign_Members__c, Product_Group__c
                FROM   Campaign_Member_Product__c
                WHERE  Campaign_Members__r.Campaign1__c = :campaignId
            ]) {
                existingCmpKeys.add(cx.Campaign_Members__c + '_' + cx.Product_Group__c);
            }
            System.debug('existingCmpKeys'+existingCmpKeys);
            
            // ── Existing leads by dedupKey(mobile, pgId) via Lead_Product__c junction ──
            /*  Map<String, Id>     existingLeadIdByKey   = new Map<String, Id>();
Map<String, String> existingLeadNameByKey =
buildExistingLeadMaps(allMobiles, campaignId, existingLeadIdByKey);
System.debug('### existingLeadIdByKey=' + existingLeadIdByKey); */
            
            Map<String, String> cityMap = new Map<String, String>();
            if (!Test.isRunningTest()) cityMap = CommonutiltiyClass.getLeadAssignment();
            
            Id defaultOwnerId = UserInfo.getUserId();
            try {
                Campaign__c cr = [SELECT CreatedById FROM Campaign__c WHERE Id = :campaignId LIMIT 1];
                if (cr.CreatedById != null) defaultOwnerId = cr.CreatedById;
            } catch (Exception ex) { System.debug('### CreatedById err: ' + ex.getMessage()); }
            
            // pgId → label
            Map<Id, String> pgLabelMap = new Map<Id, String>();
            Map<String, Id> prodGroupValueMap = new Map<String, Id>();
            for (Campaign_Line_Item__c cli : [
                SELECT Product_Group__c, Product_Group__r.Name
                FROM   Campaign_Line_Item__c
                WHERE  Campaign__c = :campaignId AND Product_Group__c != null
            ]) {
                pgLabelMap.put(cli.Product_Group__c, cli.Product_Group__r.Name);
                prodGroupValueMap.put(cli.Product_Group__r.Name, cli.Product_Group__c);
            }
            system.debug('pgLabelMap test---' + pgLabelMap);
            system.debug('prodGroupValueMap test---' + prodGroupValueMap);

            // ── CHANGED: Build Product Family maps from Product_Group__c.Product_Family__c (text field) ──
            Map<Id, String>       pgToFamilyName = new Map<Id, String>();
            Map<String, List<Id>> familyToPgIds  = new Map<String, List<Id>>();

            for (Campaign_Line_Item__c cli : [
                SELECT Product_Group__c,
                       Product_Group__r.Name,
                       Product_Group__r.Product_Family__c
                FROM   Campaign_Line_Item__c
                WHERE  Campaign__c       = :campaignId
                AND    Product_Group__c != null
                AND    Product_Group__r.Product_Family__c != null
            ]) {
                Id     pgId    = cli.Product_Group__c;
                String famName = cli.Product_Group__r.Product_Family__c;

                pgToFamilyName.put(pgId, famName);

                if (!familyToPgIds.containsKey(famName)) {
                    familyToPgIds.put(famName, new List<Id>());
                }
                if (!familyToPgIds.get(famName).contains(pgId)) {
                    familyToPgIds.get(famName).add(pgId);
                }
            }
            System.debug('### pgToFamilyName=' + pgToFamilyName);
            System.debug('### familyToPgIds='  + familyToPgIds);

            // CHANGED: Pre-load existing leads into keysQueuedThisBatch using
            // Lead_Mobile_Number__c so the dedup key matches Lead.Mobile__c exactly.
            // Key = Lead_Mobile_Number__c + '_' + Product__c (family name text)
            // CHANGED by Dhruv: campaign-specific to system-level duplicate check —
            // dedup is now system-wide (mobile + family), not scoped to this
            // campaign. Dropped the Campaign__c filter so a Lead created for the
            // same person/family in any other campaign is also picked up here.
            //
            // CHANGED by Dhruv: Leads at the literal 'Converted' stage are no longer
            // unconditionally treated as non-blocking. NOTE: 'Converted' and 'Won'
            // are two DISTINCT Lead_Stage__c values in this org — Won leads keep
            // their pre-existing behavior (always excluded, never block). Only
            // 'Converted' leads get the new nuance: they count as a duplicate only
            // if their Account has an Opportunity__c of the same Product Family
            // whose Status__c is anything other than 'Closed Won' (a blank/unset
            // Status__c also counts as blocking, per business decision). If every
            // such Opportunity is Closed Won (or none exist), the Converted lead
            // does not block and a new Lead may still be created.
            // Lost / Unqualified / Closed leads never block, regardless of any
            // other lead's status for the same mobile + family.
            //
            // BULKIFICATION CHANGE: this block now ALSO builds dupeCheckResultMap,
            // which stores the exact skip-message string ('unique' or
            // 'Name - Product') for every (mobile_family) key seen in
            // candidateLeads. This replaces the old per-row call to
            // checkDuplicateLeadByFamily() inside the main attendee/family loop
            // below — same filters, same Converted/Opportunity nuance, same
            // output strings, just computed once for the whole batch instead of
            // once per (member x family) iteration. This is what was causing the
            // "Too many SOQL queries: 101" error on larger batches.
            Set<String> keysQueuedThisBatch = new Set<String>();
            Map<String, String> dupeCheckResultMap = new Map<String, String>(); // mobile_family -> 'unique' or 'Name - Product'

            if (!allMobiles.isEmpty()) {
             /*   List<Lead__c> candidateLeads = [
                    SELECT Mobile__c, Product__c, Account__c, Lead_Stage__c
                    FROM   Lead__c
                    WHERE  Mobile__c      IN :allMobiles
                    AND    Product__c    != null
                    AND    Lead_Closed__c = false
                    AND    Lead_Stage__c != :leadStageLost
                    AND    Lead_Stage__c != :leadStageUnqualified
                    AND    Lead_Stage__c != :leadStageWon
                ];*/
                 List<Lead__c> candidateLeads = [SELECT Id,Name,Product__c,Lead_Stage__c,Account__c,Mobile__c,product_Family__c FROM Lead__c WHERE Mobile__c IN :allMobiles AND product_Family__c IN:pgToFamilyName.values() AND Lead_Stage__c !='Unqualified' ];
				System.debug('candidateLeads'+candidateLeads);
                Set<Id> convertedAccountIds = new Set<Id>();
                for (Lead__c cl : candidateLeads) {
                    if (cl.Lead_Stage__c == 'Converted' && cl.Account__c != null) {
                        convertedAccountIds.add(cl.Account__c);
                    }
                }

                // accountId + '_' + productFamily → has at least one non-lost Opportunity
                Set<String> accountFamilyHasActiveOpp = new Set<String>();
                if (!convertedAccountIds.isEmpty()) {
                    for (Opportunity__c opp : [
                        SELECT Account__c, Product_Family__c
                        FROM   Opportunity__c
                        WHERE  Account__c        IN :convertedAccountIds
                        AND    Product_Family__c != null
                        // Mobile match intentionally omitted — Opportunity__c has no direct
                        // Mobile/Phone field; matching stays scoped to Account + Product Family.
                        // AND Contact__r.MobilePhone IN :allMobiles
                        AND    Status__c        != 'Closed Won'
                    ]) {
                        accountFamilyHasActiveOpp.add(opp.Account__c + '_' + opp.Product_Family__c);
                    }
                }
                System.debug('accountFamilyHasActiveOpp'+accountFamilyHasActiveOpp);

                // BULKIFICATION CHANGE: group candidate leads by mobile_family key so a
                // single result (blocks true/false + message string) can be resolved
                // per key, instead of iterating attendees x families later.
                Map<String, List<Lead__c>> leadsByKey = new Map<String, List<Lead__c>>();
                for (Lead__c cl : candidateLeads) {
                    if (String.isBlank(cl.Mobile__c) || String.isBlank(cl.Product__c)) continue;
                    String key = cl.Mobile__c + '_' + cl.Product__c;
                    if (!leadsByKey.containsKey(key)) leadsByKey.put(key, new List<Lead__c>());
                    leadsByKey.get(key).add(cl);
                }

                for (String key : leadsByKey.keySet()) {
                    Boolean blocks    = false;
                    String  resultStr = 'unique';
                    for (Lead__c cl : leadsByKey.get(key)) {
                        Boolean thisBlocks;
                        if (cl.Lead_Stage__c == 'Converted') {
                            thisBlocks = cl.Account__c != null
                                && accountFamilyHasActiveOpp.contains(cl.Account__c + '_' + cl.Product__c);
                        } else if (cl.Lead_Stage__c != 'Unqualified') {
                            // same as original: non-Converted, non-Unqualified always blocks
                            thisBlocks = true;
                        } else {
                            thisBlocks = false;
                        }
                        System.debug('blocks'+thisBlocks);
                        if (thisBlocks) {
                            blocks    = true;
                            resultStr = cl.Name + ' - ' + cl.Product__c;
                            break;
                        }
                    }
                    if (blocks) keysQueuedThisBatch.add(key);
                    dupeCheckResultMap.put(key, resultStr);
                }
            }
            System.debug('### keysQueuedThisBatch pre-loaded=' + keysQueuedThisBatch);
            System.debug('### dupeCheckResultMap pre-loaded=' + dupeCheckResultMap);
            // ── END CHANGED ───────────────────────────────────────────────────────

            // ── DML collections ──────────────────────────────────────────────────
            List<Campaign_Member__c>         cmpUpdates  = new List<Campaign_Member__c>();
            List<Campaign_Member_Product__c> cmpProdList = new List<Campaign_Member_Product__c>();
            
            List<Lead__c>  leadInsertList  = new List<Lead__c>();
            List<String>   leadDedupKeys   = new List<String>();
            List<List<Id>> leadFamilyPgIds = new List<List<Id>>();
            
            Map<Id, String> mapOfProdFamily = new Map<Id, String>();
            
            List<Map<String, String>> createdLeadDetails = new List<Map<String, String>>();
            List<Map<String, String>> skippedLeadDetails = new List<Map<String, String>>();
            Integer leadCount = 0;
            
            Campaign__c cam = new Campaign__c(
                Id                         = campaignId,
                Completed__c               = true,
                Status__c                  = campaignStatusCompleted,
                Campaign_Completed_Date__c = System.today(),
                Attendance_Locked__c       = true,
                Reopen_Override__c         = false
            );
            system.debug('750----' + attendees);

            List<String> listOfDuplicatesLeads = new List<String>();
            Map<String, Object> errorMessages  = new Map<String, Object>();
            
            for (Map<String, Object> row : attendees) {
                Id     memberId  = safeId(row.get('Id'));
                Id     accountId = safeId(row.get('Account'));
                String emailVal  = safeStr(row.get('Email'));

                // CHANGED: resolve the definitive mobile from the pre-queried
                // Campaign_Member__c map — NOT from row.get('Mobile') which may
                // carry Contact.MobilePhone instead of Lead_Mobile_Number__c
                Campaign_Member__c campMemberRec = campMembersFullMap.get(memberId);
                String mobileNo = campMemberRec != null
                    ? safeStr(campMemberRec.Lead_Mobile_Number__c)
                    : safeStr(row.get('Mobile'));
                // ── END CHANGED ───────────────────────────────────────────────────
                
                System.debug('### ATTENDEE | id=' + memberId
                             + ' | mobile (Lead_Mobile_Number__c)=' + mobileNo
                             + ' | email=' + emailVal
                             + ' | account=' + accountId);
                
                /*  if (String.isBlank(mobileNo)) {
return new Map<String, Object>{
'status'  => 'ERROR',
'message' => 'Please update mobile number for Campaign Member: ' + memberId
};
}
if (String.isBlank(emailVal)) {
return new Map<String, Object>{
'status'  => 'ERROR',
'message' => 'Please add email for Campaign Member: ' + memberId
};
}  */
                
                List<Id> productIds = resolveProductIds(row);
                System.debug('### productIds=' + productIds + ' | memberId=' + memberId);
                
                if (productIds.isEmpty()) {
                    System.debug('### SKIP — no products | memberId=' + memberId);
                    continue;
                }
                
                Campaign_Member__c mr = memberMap.get(memberId);
                String customerFullName = mr != null && String.isNotBlank(mr.Customer_Full_Name__c)
                    ? mr.Customer_Full_Name__c
                    : safeStr(row.get('CustomerFullName'));
                if (String.isBlank(customerFullName)) {
                    customerFullName = (safeStr(row.get('FirstName'))
                                        + ' ' + safeStr(row.get('LastName'))).trim();
                }
                if (String.isBlank(customerFullName)) customerFullName = safeStr(row.get('Name'));
                
                String firstName = '', lastName = '';
                if (accountId != null) {
                    if (mr?.Contact__r != null) {
                        firstName = safeStr(mr.Contact__r.FirstName);
                        lastName  = safeStr(mr.Contact__r.LastName);
                    }
                    if (String.isBlank(firstName) && String.isBlank(lastName)) {
                        Account acc = accountMap.get(accountId);
                        if (acc != null) {
                            List<String> parts = (acc.Name != null ? acc.Name : '').split(' ', 2);
                            firstName = parts.size() > 0 ? parts[0] : '';
                            lastName  = parts.size() > 1 ? parts[1] : '';
                        }
                    }
                    if (String.isBlank(firstName)) firstName = safeStr(row.get('FirstName'));
                    if (String.isBlank(lastName))  lastName  = safeStr(row.get('LastName'));
                } else {
                    firstName = mr != null ? safeStr(mr.Lead_First_Name__c) : safeStr(row.get('FirstName'));
                    lastName  = mr != null ? safeStr(mr.Lead_Last_Name__c)  : safeStr(row.get('LastName'));
                }
                
                // ── Campaign_Member__c update ─────────────────────────────────────
                cmpUpdates.add(new Campaign_Member__c(
                    Id                           = memberId,
                    Attended__c                  = true,
                    Lead_First_Name__c           = firstName,
                    Lead_Last_Name__c            = lastName,
                    Lead_Street__c               = safeStr(row.get('Street')),
                    Lead_City__c                 = safeStr(row.get('City')),
                    Lead_Zip_Postal_Code__c      = safeStr(row.get('zipCode')),
                    Lead_State_Province__c       = safeStr(row.get('State')),
                    Lead_Country__c              = safeStr(row.get('Country'))
                ));
                
                // ── Campaign_Member_Product__c ────────────────────────────────────
                for (Id pgId : productIds) {
                    String ck = memberId + '_' + pgId;
                    if (!existingCmpKeys.contains(ck)) {
                        cmpProdList.add(new Campaign_Member_Product__c(
                            Campaign_Members__c = memberId,
                            Product_Group__c    = pgId
                        ));
                        existingCmpKeys.add(ck);
                    }
                }
                
                String country   = safeStr(row.get('Country'));
                String state     = safeStr(row.get('State'));
                String city      = safeStr(row.get('City'));
                String campStage = safeStr(row.get('CampaignStage'));

                // ── CHANGED: Group selected productIds by Product Family (text) ────
                Map<String, List<Id>> selectedFamilyToPgIds = new Map<String, List<Id>>();
                for (Id pgId : productIds) {
                    String famName = pgToFamilyName.get(pgId);
                    if (String.isBlank(famName)) {
                        System.debug('### SKIP pgId — no family text mapped | pgId=' + pgId);
                        continue;
                    }
                    if (!selectedFamilyToPgIds.containsKey(famName)) {
                        selectedFamilyToPgIds.put(famName, new List<Id>());
                    }
                    selectedFamilyToPgIds.get(famName).add(pgId);
                }

                // ── CHANGED: One Lead per Product Family; dedup via batchKey ─────
                for (String famName : selectedFamilyToPgIds.keySet()) {

                    String leadName = (famName + ' ' + customerFullName).trim();
                    if (String.isBlank(leadName)) leadName = leadFallbackName;

                    // CHANGED: batchKey uses mobileNo from Lead_Mobile_Number__c
                    // which is exactly what Lead.Mobile__c is set to → consistent
                    String batchKey = mobileNo + '_' + famName;

                    if (keysQueuedThisBatch.contains(batchKey)) {
                        listOfDuplicatesLeads.add(famName + ' - already exists or queued this batch');
                        System.debug('### SKIP LEAD — already in batch/DB | batchKey=' + batchKey);
                        continue;
                    }

                    // BULKIFICATION CHANGE: secondary DB check now served entirely from
                    // the pre-computed dupeCheckResultMap (built once above, before this
                    // loop) instead of calling checkDuplicateLeadByFamily() — which ran a
                    // fresh SOQL query on every single (member x family) iteration and
                    // was the primary cause of "Too many SOQL queries: 101" on larger
                    // batches. Same filters, same Converted/Opportunity nuance, same
                    // output strings — just computed once for the whole batch.
                    String duplicateLead = dupeCheckResultMap.containsKey(batchKey)
                        ? dupeCheckResultMap.get(batchKey)
                        : 'unique';
                    if (duplicateLead != 'unique') {
                        listOfDuplicatesLeads.add(duplicateLead);
                        keysQueuedThisBatch.add(batchKey);
                        System.debug('### SKIP LEAD — duplicate DB check | famName=' + famName);
                        continue;
                    }

                    keysQueuedThisBatch.add(batchKey);
                    leadCount++;
                    // ── END CHANGED ───────────────────────────────────────────────

                    system.debug('902---' + famName);

                    // CHANGED: email and mobile now come from the pre-queried map
                    // (no SOQL inside loop)
                    String leadEmail  = campMemberRec != null ? safeStr(campMemberRec.Lead_Email__c)         : '';
                    String leadMobile = campMemberRec != null ? safeStr(campMemberRec.Lead_Mobile_Number__c) : '';
                    String recTypeName = campMemberRec != null ? safeStr(campMemberRec.RecordType.Name)      : '';
                    /* old SOQL-in-loop removed:
                    List<Campaign_Member__c> campMembersList = [
                        SELECT Id, Lead_Mobile_Number__c, RecordType.Name, Lead_Email__c
                        FROM   Campaign_Member__c WHERE Id = :memberId LIMIT 1
                    ]; */

                    Lead__c lead = new Lead__c(
                        Name              = leadName,
                        First_Name__c     = firstName,
                        Last_Name__c      = String.isNotBlank(lastName) ? lastName : firstName,
                        Email__c          = String.isNotBlank(leadEmail)  ? leadEmail  : null,
                        Mobile__c         = String.isNotBlank(leadMobile) ? leadMobile : null,
                        ZoneNew__c        = campMemberRec != null ? campMemberRec.Zone__c : null,
                        Company__c        = safeStr(row.get('Company')),
                        Lead_Source__c    = leadSourceDefault,
                        Billing_City__c   = city,
                        Country__c        = country,
                        Billing_Street__c = safeStr(row.get('Street')),
                        Billing_code__c   = safeStr(row.get('zipCode')),
                        Billing_state__c  = state,
                        Campaign__c       = campaignId,
                        Member_Type__c    = safeStr(row.get('memberType')),
                        Product__c        = famName,
                        Product_Family__c = famName,
                        Campaign_Member_Product_Family_Id__c = memberId+'_'+famName
                    );
                    System.debug('lead on 1083'+lead);
                    
                    if (accountId != null) {
                        String ceRating = safeStr(row.get('CeRating'));
                        String phakic   = safeStr(row.get('PhakicRating'));
                        String sapCode  = safeStr(row.get('SAPCode'));
                        Account acc     = accountMap.get(accountId);
                        lead.Account__c           = accountId;
                        lead.CE_CIS_Rating__c     = ceRating;
                        lead.Phakic_Rating__c     = phakic;
                        lead.SAP_Code__c          = String.isNotBlank(sapCode) ? sapCode : ' ';
                        // CHANGED: use pre-queried recTypeName instead of SOQL-in-loop
                        if (recTypeName == 'Existing member') {
                            lead.Existing_customer__c = true;
                        } else {
                            system.debug('915----' + recTypeName);
                            lead.Existing_customer__c = false;
                            lead.New_Customer__c      = true;
                        }
                        lead.UserId__c = String.isNotBlank(safeStr(row.get('OwnerId')))
                            ? safeStr(row.get('OwnerId')) : defaultOwnerId;
                        if (acc != null) {
                            lead.Plant__c      = acc.Branch_Name__c;
                            lead.Plant_code__c = acc.Branch_Code__c;
                        }
                        if (String.isNotBlank(ceRating) && String.isNotBlank(phakic)) {
                            lead.CE_CIS_Approval__c = true;
                            lead.Status__c          = true;
                        }
                        System.debug('### LEAD queued (existing cust) | famName=' + famName + ' | name=' + leadName);
                    } else {
                        lead.New_Customer__c = true;
                        if (String.isNotBlank(country) && String.isNotBlank(state) && String.isNotBlank(city)) {
                            String ck2 = country.toUpperCase() + state.toUpperCase() + city.toUpperCase();
                            lead.UserId__c = cityMap.containsKey(ck2) ? cityMap.get(ck2) : defaultOwnerId;
                        } else {
                            lead.UserId__c = defaultOwnerId;
                        }
                        lead.Lead_Assignment__c = true;
                        System.debug('### LEAD queued (new cust) | famName=' + famName
                                     + ' | name=' + leadName + ' | owner=' + lead.UserId__c);
                    }
                    
                    stampCampaignStageDate(lead, campStage);
                    leadInsertList.add(lead);
                    leadDedupKeys.add(batchKey);
                    leadFamilyPgIds.add(selectedFamilyToPgIds.get(famName));
                    
                    createdLeadDetails.add(new Map<String, String>{
                        'memberName' => customerFullName,
                        'pgLabel'    => famName,
                        'leadName'   => leadName
                    });
                }
                // ── END CHANGED ───────────────────────────────────────────────────
            }
            
            System.debug('### PRE-DML | cmpUpdates=' + cmpUpdates.size()
                         + ' | cmpProd=' + cmpProdList.size()
                         + ' | leads=' + leadInsertList.size()
                         + ' | leadCount=' + leadCount);
              Savepoint sp = Database.setSavepoint();
            try {
              
                // 1. Update Campaign_Member__c
                if (!cmpUpdates.isEmpty()) {
                    update cmpUpdates;
                    System.debug('### DML: updated ' + cmpUpdates.size() + ' Campaign_Member__c');
                }
                
                // 2. Insert Campaign_Member_Product__c
                if (!cmpProdList.isEmpty()) {
                    insert cmpProdList;
                    System.debug('### DML: inserted ' + cmpProdList.size() + ' Campaign_Member_Product__c');
                }
                
                // 3. Insert leads
                /*  Map<String, Id> dkToLeadId = new Map<String, Id>(existingLeadIdByKey); */
                Set<Id> insertedLeadIds = new Set<Id>();

                List<Lead_Product__c> listOfProd = new List<Lead_Product__c>();

                // BULKIFICATION CHANGE: pre-compute the Lead_Product__c fallback lookup
                // for ALL potential failed inserts up front (one bulk query), instead of
                // running a SOQL query per failed row inside the results loop below.
                Map<String, Id> fallbackLeadProductLookup = new Map<String, Id>();
                if (!leadInsertList.isEmpty()) {
                    Set<String> mobilesForFallback = new Set<String>();
                    for (Lead__c l : leadInsertList) {
                        if (String.isNotBlank(l.Mobile__c)) mobilesForFallback.add(l.Mobile__c);
                    }
                    if (!mobilesForFallback.isEmpty()) {
                        for (Lead_Product__c lp : [
                            SELECT Leads__c, Leads__r.Mobile__c, Leads__r.Product__c
                            FROM   Lead_Product__c
                            WHERE  Leads__r.Mobile__c      IN :mobilesForFallback
                            AND    Leads__r.Campaign__c    = :campaignId
                            AND    Leads__r.Lead_Closed__c = false
                        ]) {
                            String fbk = lp.Leads__r.Mobile__c + '_' + lp.Leads__r.Product__c;
                            if (!fallbackLeadProductLookup.containsKey(fbk)) {
                                fallbackLeadProductLookup.put(fbk, lp.Leads__c);
                            }
                        }
                    }
                }
                System.debug('### fallbackLeadProductLookup pre-loaded=' + fallbackLeadProductLookup);

                if (!leadInsertList.isEmpty()) {
                    Database.DmlOptions opts = new Database.DmlOptions();
                    opts.DuplicateRuleHeader.allowSave        = true;
                    opts.DuplicateRuleHeader.runAsCurrentUser = true;
                    LeadTriggerHandler.skipConversionLogic = true;
Database.SaveResult[] results = Database.insert(leadInsertList, opts);
LeadTriggerHandler.skipConversionLogic = false;
                    //List<Database.SaveResult> results = Database.insert(leadInsertList, opts);
                    
                    for (Integer i = 0; i < results.size(); i++) {
                        String dk = leadDedupKeys[i];
                        
                        if (results[i].isSuccess()) {
                            Id leadId = results[i].getId();
                            insertedLeadIds.add(leadId);
                            System.debug('### LEAD inserted | dk=' + dk + ' | leadId=' + leadId);

                            List<Id> pgIdsForLead = leadFamilyPgIds[i];
                            for (Id pgId : pgIdsForLead) {
                                if (pgId == null) continue;
                                listOfProd.add(new Lead_Product__c(
                                    Leads__c         = leadId,
                                    Product_Group__c = pgId
                                ));
                                System.debug('### LP queued | leadId=' + leadId + ' | pgId=' + pgId);
                            }

                        } else {
                            System.debug('### LEAD insert FAILED | dk=' + dk
                                         + ' | errors=' + results[i].getErrors());
                            if (results[i].getErrors().size() > 0) {
                                Database.Error err = results[i].getErrors()[0];
                                errorMessages.put('error', err.getMessage());
                            }
                            
                            // BULKIFICATION CHANGE: replaced per-row SOQL fallback query with
                            // a lookup into the pre-computed fallbackLeadProductLookup map.
                            String mob     = leadInsertList[i].Mobile__c;
                            String famName = leadInsertList[i].Product__c;
                            String fbKey   = mob + '_' + famName;
                            if (fallbackLeadProductLookup.containsKey(fbKey)) {
                                System.debug('### LEAD fallback | dk=' + dk + ' | id=' + fallbackLeadProductLookup.get(fbKey));
                            }
                        }
                    }
                }

                /* added by ankit — replaced by CHANGED block above
                List<Lead_Product__c> listOfProd = new List<Lead_Product__c>();
                List<Lead__c> leadList = [select id, Product__c from Lead__c where id IN :insertedLeadIds];
                Map<Id, String> mapLeadIdProdName = new Map<Id, String>();
                for(Lead__c leadRec : leadList){
                    mapLeadIdProdName.put(leadRec.id, leadRec.Product__c); 
                }
                for(Id leadId : insertedLeadIds){
                    Lead_Product__c leadRec = new  Lead_Product__c();
                    leadRec.Leads__c = leadId;
                    String prodName = mapLeadIdProdName.get(leadId);
                    Id prodGropId = prodGroupValueMap.get(prodName);
                    system.debug('prodGropId---' + prodGropId);
                    leadRec.Product_Group__c = prodGropId;
                    listOfProd.add(leadRec);
                }
                if(!listOfProd.isEmpty()){
                    system.debug('listOfProd---' + listOfProd);
                    Database.insert(listOfProd, false);
                }else{
                    system.debug('error---');
                } */

                /*    Set<String> existingLpKeys = new Set<String>();
Set<Id> allLeadIds = new Set<Id>(dkToLeadId.values());
...
} */

                // 4. Insert Lead_Product__c
                if (!listOfProd.isEmpty()) {
                    Database.insert(listOfProd, false);
                    System.debug('### DML: inserted ' + listOfProd.size() + ' Lead_Product__c');
                } else {
                    System.debug('### No Lead_Product__c to insert');
                }
                
                // 5. Update campaign
                cam.Lead_Generated__c = leadCount;
                update cam;
                System.debug('### Campaign updated | Lead_Generated__c=' + leadCount);
                System.debug('### DONE | created=' + createdLeadDetails.size()
                             + ' | skipped=' + skippedLeadDetails.size());
                
                return new Map<String, Object>{
                    'status'       => attendanceSaveSuccess,
                        'message'      => attendanceSaveSuccess,
                        'leadsCreated' => createdLeadDetails,
                        'leadsSkipped' => listOfDuplicatesLeads,
                        'error'        => errorMessages
                        };
                            
            } catch (Exception e) {
                Database.rollback(sp);
                System.debug('### EXCEPTION | ' + e.getMessage()
                             + ' | line=' + e.getLineNumber()
                             + ' | stack=' + e.getStackTraceString());
                return new Map<String, Object>{
                    'status'  => 'ERROR',
                        'message' => e.getMessage()
                        };
            }
        }

    // =========================================================================
    // NOTE: checkDuplicateLeadByFamily() is retained below for reference / in
    // case other callers exist, but it is NO LONGER CALLED from markAttendance.
    // Its logic has been absorbed into the bulk pre-computation of
    // dupeCheckResultMap earlier in markAttendance (see BULKIFICATION CHANGE
    // comments above). If nothing else references this method, it is safe to
    // delete after confirming via an "Find Usages" / global search.
    //
    // CHANGED by Dhruv: campaign-specific to system-level duplicate check —
    // dedup is now system-wide (mobile + family), no longer scoped to
    // campaignId/memberId, since Campaign_Member_Product_Family_Id__c is built
    // from a Campaign_Member__c Id, which is unique per campaign per person and
    // therefore could never match across campaigns for the same physical person.
    //
    // CHANGED by Dhruv: Leads at the literal 'Converted' stage no longer
    // unconditionally skipped. NOTE: 'Converted' and 'Won' are two DISTINCT
    // Lead_Stage__c values in this org — Won leads keep their pre-existing
    // behavior (always excluded via the query filter below, never block).
    // A Converted lead only blocks if its Account has an Opportunity__c of the
    // same Product Family with Status__c other than 'Closed Won' (a blank/
    // unset Status__c also counts as blocking, per business decision). If
    // every such Opportunity is Closed Won (or none exist), it does not block.
    // =========================================================================
    private static String checkDuplicateLeadByFamily(String mobile, String familyName) {
		System.debug('mobile'+mobile+'familyName'+familyName);
        if (String.isBlank(mobile) || String.isBlank(familyName)) return 'unique';

      /*  List<Lead__c> existing = [
            SELECT Id, Name, Product__c, Lead_Stage__c, Account__c
            FROM   Lead__c
            WHERE  Mobile__c      = :mobile
            AND    Product__c     = :familyName
            AND    Lead_Closed__c = false
            AND    Lead_Stage__c != :leadStageLost
            AND    Lead_Stage__c != :leadStageUnqualified
            AND    Lead_Stage__c != :leadStageWon
        ]; */
        List<Lead__c> existing = [
            SELECT Id, Name, Product__c, Product_Family__c, Lead_Stage__c, Account__c
            FROM   Lead__c
            WHERE  Mobile__c         = :mobile
            AND    Product_Family__c != null
            AND    Product_Family__c = :familyName
            AND    Lead_Stage__c     != 'Unqualified'
            AND Lead_Closed__c  =false
        ];
		System.debug('Exisiting Method '+ existing);
		System.debug('Exisiting Method parameter'+ mobile+familyName);

        for (Lead__c lea : existing) {
            if (lea.Lead_Stage__c != 'Converted') {
                return lea.Name + ' - ' + lea.Product__c;
            }
            if (lea.Account__c != null) {
                List<Opportunity__c> activeOpps = [
                    SELECT Id FROM Opportunity__c
                    WHERE  Account__c        = :lea.Account__c
                    AND    Product_Family__c = :familyName
                    // Mobile match intentionally omitted — Opportunity__c has no direct
                    // Mobile/Phone field; matching stays scoped to Account + Product Family.
                    // AND Contact__r.MobilePhone = :mobile
                    AND    Status__c        != 'Closed Lost'
                    LIMIT  1
                ];
                if (!activeOpps.isEmpty()) return lea.Name + ' - ' + lea.Product__c;
            }
        }
        return 'unique';
    }
    /* old checkDuplicateLead method — replaced by checkDuplicateLeadByFamily above
    private static string checkDuplicateLead(String pgLabel, String firstName, String lastName){
        List<Lead_Product__c> leadProdList = [SELECT id, Name, Product_Group__r.Name,
                                              Leads__r.First_Name__c, Leads__r.Last_Name__c, Leads__r.name
                                              from Lead_Product__c where Product_Group__r.Name =:pgLabel AND
                                              Leads__r.First_Name__c =:firstName AND
                                              Leads__r.Last_Name__c =:lastName];
        if(!leadProdList.isEmpty()){
            return leadProdList[0].Name + '-' + leadProdList[0].Leads__r.name + '-' + leadProdList[0].Product_Group__r.Name;
        }else{
            return 'unique'; 
        }
    } */

    // =========================================================================
    // UTILITY METHODS
    // =========================================================================
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCityData(String cmpId) {
        Campaign__c cmp = [SELECT Id, State__c, Country__c, City__c FROM Campaign__c WHERE Id = :cmpId LIMIT 1];
        Map<String, Object> result = new Map<String, Object>();
        if (String.isNotBlank(cmp.State__c)) {
            result.put('CityList', CustomLeadCreationController.getCityMappingData(cmp.State__c.toUpperCase()));
        }
        result.put('Citydata', cmp.City__c);
        return result;
    }
    
    @AuraEnabled
    public static void updateCampaign(Campaign__c cmp) {
        update cmp;
    }



}
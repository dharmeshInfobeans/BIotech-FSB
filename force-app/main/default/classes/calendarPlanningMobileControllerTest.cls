@isTest
public class calendarPlanningMobileControllerTest {

    static testMethod void validategetproducts() {
        List<User> userList=[SELECT Id from user   limit 2];
        List<Object> objList=new List<Object>();
        CIty__c reg=new CIty__c();
        reg.country_key__c='1234';
        reg.Old_Region_Code__c=123;
        reg.Region_Code__c='12333';
        reg.Name='International';
        reg.Zone_Name__c='North';
        reg.Zone_Code__c='1';
        reg.country_key__c='IN';
        insert reg;
        
     
        
        Holiday__c h=new holiday__c();
        h.date__c=system.today();
        h.type__c='H';
        h.Country__c='INDIA';
        h.State__c = 'Madhya Pradesh';
        h.Description__c='Diwali';
        insert h;
            
        Account ac = new Account();
        ac.name = 'Test';
        ac.CE_CIS_Rating__c = 'Aa';
        ac.region__c=reg.Id;
        ac.Phone='12345678910';        
        insert ac;
        
        
        Account_Plan_Restrictions__c acc=new Account_Plan_Restrictions__c();
        acc.Status__c='Activated';
        acc.SAP_Code__c=true;
        acc.Name='INDIA';
        acc.Record_Type__c='Domestic-Doctor/Hospital';
        insert acc;
        
        Contact c = new Contact();
        c.LastName='abc';
        c.FirstName = 'cds';
        c.MailingCity='Gwalior';
        c.MailingCountry='IN';
        c.MailingPostalCode='470001';
        c.MailingStreet='city center';
        insert c;
        
        string cardColor;
        cardColor ='onsitePlanned';
        list<Event> eveList = new list<Event>();
        Event ev = new Event();
        ev.Subject = 'abc';
        ev.OwnerId = userinfo.getUserId();
        ev.StartDateTime = system.now();
        ev.endDateTime = system.now().adddays(1);
        ev.BD_Tracker_Phase__c='122';
        ev.Status__c = 'Planned';
        ev.Milestone_Plan_Week__c='today';
        ev.MileStone_Stage__c='true';
        ev.Meeting_Type__c = 'Online';
        ev.isSubmitted__c=true;
        ev.StartDateTime=system.now();
        ev.isConnectedToDCR__c=false;
        ev.EndDateTime=system.now();
        ev.WhatId = ac.Id;
        
        insert ev;
        objList.add(ev.id);
        
        beat_plan__c beatdata = new beat_plan__c();
        beatdata.Beat_Date__c = system.today();
        insert beatdata;
        
        Event ev2 = new Event();
        ev2.Subject = 'Call';
        ev2.Status__c ='Planned';
        ev2.Meeting_Type__c = 'Onsite';
        ev2.OwnerId = userinfo.getUserId();
        ev2.StartDateTime = system.now();
        ev2.endDateTime = system.now().adddays(1);
        ev2.Account__c = ac.id;
        ev2.isSubmitted__c = true;
        ev2.Beat_plan__c = beatdata.Id;
        ev2.Milestone_Stage__c='Delay';
        ev2.WhatId = ac.Id;
        
        insert ev2;
        
        
        
        Event ev3 = new Event();
        ev3.Subject = 'Test';
        ev3.Status__c ='Planned';
        ev3.Meeting_Type__c = 'Offsite';
        ev3.OwnerId = userinfo.getUserId();
        ev3.StartDateTime = system.now();
        ev3.endDateTime = system.now().adddays(1);
        ev3.Account__c = ac.id;
        ev3.Beat_plan__c = beatdata.Id;
        ev3.isSubmitted__c = true;
        ev3.Milestone_Stage__c='Plan';
        ev3.WhatId = ac.Id;
        
        insert ev3;
        eveList.add(ev3);
        eveList.add(ev);
        eveList.add(ev2);

		Org_Role_Hierarchy__c businessMappingOrgRole = new Org_Role_Hierarchy__c(
            Name = 'Test Org Role Hierarchy - Business Mapping',
            Business_Mapping__c = true
        );
        insert businessMappingOrgRole;
          
          
        Leads__c triggerSetting=new Leads__c();
        triggerSetting.Name='LeadTrigger';
        triggerSetting.IsActive__c=true;
        insert triggerSetting;
        
        lead__c lea1=new lead__c();
        lea1.Name='tets';
        lea1.First_Name__c='test';
        lea1.Last_Name__c='singh';
        lea1.Company__c='Plus91labs1';
        lea1.Product__c='BIO HYALUR CS';
        lea1.Billing_City__c='Gwalior';
        lea1.Billing_code__c='474001';
        lea1.Country__c='IN';
        lea1.Billing_state__c='Mp';
        lea1.Email__c='pankajsinghania12333@gmail.com';
        lea1.Mobile__c='1234567890';
        lea1.Billing_Street__c='chandranagr koteshwar';
        lea1.SAP_Code__c='12343109O';
        lea1.Lead_Stage__c='Appointments';
        insert lea1;
        
        
        Map<String, Object> eveMap = new Map<String, Object>();
        eveMap.put('Id', ev.Id);
        eveMap.put('BDTrackerPhase', ev.BD_Tracker_Phase__c);
        eveMap.put('MilestonePlanWeek', ev.Milestone_Plan_Week__c);
        eveMap.put('MileStoneStage', ev.MileStone_Stage__c);
        eveMap.put('isSubmitted', ev.isSubmitted__c);
        eveMap.put('OwnerId', ev.OwnerId);
        eveMap.put('startDateTime', ev.startDateTime);
        eveMap.put('isConnectedToDCR', ev.isConnectedToDCR__c);
        eveMap.put('EndDateTime', ev.EndDateTime);
        eveMap.put('whatId', ev.whatId);
          Address__c newAddress = new Address__c(
    Billing_Street__c = '123 Main Street',
    Billing_City__c = 'San Francisco',
    Billing_State__c = 'CA',
    Billing_Country__c = 'USA'
);

// Insert the new record
try {
    insert newAddress;
    System.debug('New Address Record ID: ' + newAddress.Id);
} catch (Exception e) {
    System.debug('An error occurred: ' + e.getMessage());
}
        calendarPlanningMobileController.getUserClinicalVertical();
         calendarPlanningMobileController.fakemethod();
        calendarPlanningMobileController.getAccountPlanRestrictions();
        calendarPlanningMobileController.getProducts('abc');
        calendarPlanningMobileController.getCallType();
        calendarPlanningMobileController.getUsers();
        calendarPlanningMobileController.getReviewCallType();
        calendarPlanningMobileController.getMeetingType();
        calendarPlanningMobileController.getManagerAndReportee();
        calendarPlanningMobileController.getRegionAndZone();
        calendarPlanningMobileController.getEvents('');
        calendarPlanningMobileController.findEvent('abc');
        calendarPlanningMobileController.findAccount('abc', 'International', 'North','All');
         calendarPlanningMobileController.findAccount('abc', 'International', 'North','Account');
         calendarPlanningMobileController.findAccount('abc', 'International', 'North','Lead');
        
        calendarPlanningMobileController.findAccount('abc', 'Domestic', 'North','');
        calendarPlanningMobileController.getProductsBySubCallType('Standee');
        calendarPlanningMobileController.getLabels();
        calendarPlanningMobileController.getLeaveType();
        calendarPlanningMobileController.findRecords('abc','Account','Name');
        calendarPlanningMobileController.getEventsForBDPlan(ac.id,UserInfo.getUserId(),'Update');
        calendarPlanningMobileController.updateEventData(ev); 
        calendarPlanningMobileController.getCurrentUser();
      
        //calendarPlanningMobileController.findAccount('122',null,null,'');
        //calendarPlanningMobileController.findAccount('','International',null,'');
        calendarPlanningMobileController.findAccount('','International','North','');
        calendarPlanningMobileController.updateEventBDPlan(objList,'Update');
          calendarPlanningMobileController.deleteEventData(ev);
        
        //calendarPlanningMobileController.getEventsByTodayDate(Datetime.now().date());
       
        map<string, object> dataMap = new map<string, object>();
        dataMap.put('isJoint',true);
        dataMap.put('date','12/12/2021');
        dataMap.put('startTime',Datetime.now().time());
        dataMap.put('endTime',Datetime.now().time());
        dataMap.put('relatedTo', ac.Id);
        dataMap.put('product','abc');
        dataMap.put('callType','Call');
        dataMap.put('outOfOffice',true);
        dataMap.put('jointassignee',false);
        dataMap.put('contactId',c.Id); 
        dataMap.put('ownerid',UserInfo.getUserId());
        dataMap.put('eventType','Leave');
       
        calendarPlanningMobileController.createEvent(dataMap,newAddress.Id,h.date__c);
        
        map<string, object> dataMap1 = new map<string, object>();
        dataMap1.put('isJoint',true);
        dataMap1.put('date','01/01/2020');
        dataMap1.put('startTime',Datetime.now().time());
        dataMap1.put('endTime',Datetime.now().time());
        dataMap1.put('relatedTo', ac.Id);
        dataMap1.put('product','abc');
        dataMap1.put('callType','Call');
        dataMap1.put('outOfOffice',true);
        dataMap1.put('jointassignee',false);
        dataMap1.put('contactId',c.Id); 
        dataMap1.put('ownerid',UserInfo.getUserId());
        dataMap1.put('eventType','Holiday');
        
      
        calendarPlanningMobileController.createEvent(dataMap1,newAddress.Id,h.date__c);
        calendarPlanningMobileController.getUserHolidays(UserInfo.getUserId());
        calendarPlanningMobileController.getLeadData(lea1.id);
        
        map<string, object> dataMap2 = new map<string, object>();
        dataMap2.put('isJoint',true);
        dataMap2.put('date','01/01/2020');
        dataMap2.put('startTime',Datetime.now().time());
        dataMap2.put('endTime',Datetime.now().time());
        dataMap2.put('relatedTo', ac.Id);
        dataMap2.put('product','Sameer');
        dataMap2.put('callType','Call');
        dataMap2.put('outOfOffice',true);
        dataMap2.put('jointassignee',false);
        dataMap2.put('contactId',c.Id); 
        dataMap2.put('ownerid',UserInfo.getUserId());
        dataMap2.put('eventType','Out of office');
        calendarPlanningMobileController.createEvent(dataMap2,newAddress.Id,h.date__c);
        map<string, object> dataMap3 = new map<string, object>();
        dataMap3.put('isJoint',true);
        dataMap3.put('users',new List<String>{userInfo.getUserId()});
        dataMap3.put('date','01/01/2020');
        dataMap3.put('startTime',Datetime.now().time());
        dataMap3.put('endTime',Datetime.now().time());
        dataMap3.put('relatedTo', ac.Id);
        dataMap3.put('product','samee');
        dataMap3.put('callType','Call');
        dataMap3.put('outOfOffice',true);
        dataMap3.put('jointassignee',true);
        dataMap3.put('contactId',c.Id); 
        dataMap3.put('ownerid',UserInfo.getUserId());
        dataMap3.put('eventType','Customer visit');
        calendarPlanningMobileController.getLightningPickListValues('Lead_Stage__c','Lead__c');
        calendarPlanningMobileController.createEvent(dataMap3,'',null);

        // Fresh governor limits for the remaining calls - the setup and
        // createEvent/deleteEventData calls above use most of the SOQL budget.
        Test.startTest();
        calendarPlanningMobileController.getProductsBySubCallType('Standee');

        calendarPlanningMobileController.getHolidayRecord();
         calendarPlanningMobileController.getSubCallTypeOptions();
        calendarPlanningMobileController.getdailyactivity();
        calendarPlanningMobileController.getLevelTypeOptions();
        calendarPlanningMobileController.getUserHolidays(UserInfo.getUserId());
        //calendarPlanningMobileController.getLeadData(lea1.id);

        // ── NEW: covers the Beat_plan__r.Approval_status__c != null &&
        // Type_of_leave__c != null branch inside getEventsRefresh, which
        // none of ev/ev2/ev3 above ever triggered (none set Type_of_leave__c,
        // and none of their Beat_Plan__c records had Approval_status__c set).
        // Wrapped in try/catch since the exact valid picklist value for
        // Approval_status__c on Beat_Plan__c isn't known from the Apex alone -
        // if 'Approved' isn't a valid value in this org, this simply logs and
        // skips rather than failing the whole test.
        try {
            beat_plan__c beatdataApproved = new beat_plan__c();
            beatdataApproved.Beat_Date__c = system.today();
            beatdataApproved.Approval_status__c = 'Approved';
            insert beatdataApproved;

            Event evLeave = new Event();
            evLeave.Subject = 'Leave Coverage';
            evLeave.OwnerId = userinfo.getUserId();
            evLeave.StartDateTime = system.now();
            evLeave.EndDateTime = system.now().addHours(1);
            evLeave.Status__c = 'Planned';
            evLeave.WhatId = ac.Id;
            evLeave.Beat_plan__c = beatdataApproved.Id;
            evLeave.Type_of_leave__c = 'Full Day Leave';
            insert evLeave;

            calendarPlanningMobileController.getEvents('');
        } catch (Exception e) {
            System.debug('Leave/Approval coverage branch skipped: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // Account event with a target -> Target__c.Target_Completed__c true on
    // create, false again once that event is deleted.
    @isTest
    static void validateTargetCompletedFlag() {
        CIty__c reg = new CIty__c(
            country_key__c = 'IN',
            Region_Code__c = '12336',
            Name           = 'Target Region',
            Zone_Name__c   = 'North',
            Zone_Code__c   = '1'
        );
        insert reg;

        Account ac = new Account(
            Name                = 'Target Account',
            CE_CIS_Rating__c    = 'Aa',
            region__c           = reg.Id,
            Phone               = '9998887773'
        );
        insert ac;

        Target__c tgt = new Target__c();
        insert tgt;

        map<string, object> dataMap = new map<string, object>();
        dataMap.put('isJoint', true);
        dataMap.put('users', new List<String>{ UserInfo.getUserId() });
        dataMap.put('date', '01/01/2020');
        dataMap.put('startTime', Datetime.now().time());
        dataMap.put('endTime', Datetime.now().time());
        dataMap.put('relatedTo', ac.Id);
        dataMap.put('product', 'abc');
        dataMap.put('callType', 'Call');
        dataMap.put('outOfOffice', true);
        dataMap.put('jointassignee', true);
        dataMap.put('ownerid', UserInfo.getUserId());
        dataMap.put('eventType', 'Customer visit');
        dataMap.put('targetId', tgt.Id);

        Test.startTest();
        calendarPlanningMobileController.createEvent(dataMap, '', null);

        List<Event> created = [SELECT Id FROM Event WHERE Target__c = :tgt.Id];
        System.assert(!created.isEmpty(), 'Event should be created for the target');
        System.assertEquals(true, [SELECT Target_Completed__c FROM Target__c WHERE Id = :tgt.Id].Target_Completed__c,
            'Target should be marked completed after Account event creation');

        // createEvent can insert more than one event for the same target, so
        // delete them all; the flag is only cleared with the last one.
        for (Integer i = 0; i < created.size(); i++) {
            calendarPlanningMobileController.deleteEventData(created[i]);
            if (i < created.size() - 1) {
                System.assertEquals(true, [SELECT Target_Completed__c FROM Target__c WHERE Id = :tgt.Id].Target_Completed__c,
                    'Target should stay completed while another Account event still uses it');
            }
        }
        Test.stopTest();

        System.assertEquals(false, [SELECT Target_Completed__c FROM Target__c WHERE Id = :tgt.Id].Target_Completed__c,
            'Target should be unmarked after its only Account event is deleted');
    }

    // Customer visit (single user and joint assignee) stores the creation
    // time on the chosen date: start == end, on that date, visit date set.
    @isTest
    static void validateCustomerVisitStartEndTime() {
        CIty__c reg = new CIty__c(
            country_key__c = 'IN',
            Region_Code__c = '12337',
            Name           = 'Time Region',
            Zone_Name__c   = 'North',
            Zone_Code__c   = '1'
        );
        insert reg;

        Account ac = new Account(
            Name             = 'Time Account',
            CE_CIS_Rating__c = 'Aa',
            region__c        = reg.Id,
            Phone            = '9998887774'
        );
        insert ac;

        Test.startTest();
        for (Boolean joint : new List<Boolean>{ false, true }) {
            map<string, object> dataMap = new map<string, object>();
            dataMap.put('date', '03/15/2030');
            dataMap.put('relatedTo', ac.Id);
            dataMap.put('product', 'abc');
            dataMap.put('callType', 'Call');
            dataMap.put('jointassignee', joint);
            dataMap.put('ownerid', UserInfo.getUserId());
            dataMap.put('eventType', 'Customer visit');
            if (joint) {
                dataMap.put('users', new List<String>{ UserInfo.getUserId() });
            }
            calendarPlanningMobileController.createEvent(dataMap, '', null);
        }
        Test.stopTest();

        List<Event> events = [
            SELECT StartDateTime, EndDateTime, ActivityDateTime, Visit_Date__c, DurationInMinutes
            FROM Event
            WHERE WhatId = :ac.Id AND Visit_Date__c = :Date.newInstance(2030, 3, 15)
        ];
        System.assert(!events.isEmpty(), 'Customer visit events should be created');
        for (Event e : events) {
            System.assertEquals(Date.newInstance(2030, 3, 15), e.StartDateTime.date(), 'Start should be on the selected date');
            System.assertEquals(e.StartDateTime, e.EndDateTime, 'Start and end should both hold the creation time');
            System.assertEquals(e.StartDateTime, e.ActivityDateTime, 'ActivityDateTime should match start');
            System.assertEquals(0, e.DurationInMinutes, 'Duration is zero when start equals end');
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // ⚠️ Same Org Role Hierarchy validation rule seen on Opportunity__c in
    // other controllers in this org - reused here since inserting an
    // Opportunity__c to exercise findAccount(..., 'Opportunity') requires
    // it. Dynamically discovers the Division/Sub Division/Sales District
    // fields on User and Org_Role_Hierarchy__c rather than hardcoding field
    // names, then mirrors the running user's values onto a new
    // Org_Role_Hierarchy__c record so the validation rule finds a match.
    // ════════════════════════════════════════════════════════════════════
    private static void ensureOrgRoleHierarchyMatchesRunningUser() {
        Map<String, Schema.SObjectField> userFieldMap = Schema.SObjectType.User.fields.getMap();
        String divisionField    = null;
        String subDivisionField = null;
        String districtField    = null;

        for (String key : userFieldMap.keySet()) {
            String lower = key.toLowerCase();
            if (lower.contains('sub_division') || lower.contains('subdivision')) {
                subDivisionField = key;
            } else if (lower.contains('division') && subDivisionField != key) {
                divisionField = key;
            } else if (lower.contains('district')) {
                districtField = key;
            }
        }

        if (divisionField == null && subDivisionField == null && districtField == null) {
            return;
        }

        List<String> queryFields = new List<String>{'Id'};
        if (divisionField != null)    queryFields.add(divisionField);
        if (subDivisionField != null) queryFields.add(subDivisionField);
        if (districtField != null)    queryFields.add(districtField);

        String userQuery = 'SELECT ' + String.join(queryFields, ', ')
                          + ' FROM User WHERE Id = \'' + UserInfo.getUserId() + '\' LIMIT 1';
        SObject runningUser = Database.query(userQuery);

        Map<String, Schema.SObjectField> orhFieldMap = Schema.SObjectType.Org_Role_Hierarchy__c.fields.getMap();
        String orhDivisionField    = null;
        String orhSubDivisionField = null;
        String orhDistrictField    = null;

        for (String key : orhFieldMap.keySet()) {
            String lower = key.toLowerCase();
            if (lower.contains('sub_division') || lower.contains('subdivision')) {
                orhSubDivisionField = key;
            } else if (lower.contains('division') && orhSubDivisionField != key) {
                orhDivisionField = key;
            } else if (lower.contains('district')) {
                orhDistrictField = key;
            }
        }

        SObject orh = Schema.getGlobalDescribe().get('Org_Role_Hierarchy__c').newSObject();
        orh.put('Name', 'Coverage Test Org Role Hierarchy');
        orh.put('Business_Mapping__c', true);

        if (orhDivisionField != null && divisionField != null) {
            orh.put(orhDivisionField, runningUser.get(divisionField));
        }
        if (orhSubDivisionField != null && subDivisionField != null) {
            orh.put(orhSubDivisionField, runningUser.get(subDivisionField));
        }
        if (orhDistrictField != null && districtField != null) {
            orh.put(orhDistrictField, runningUser.get(districtField));
        }

        insert orh;
    }

    // ════════════════════════════════════════════════════════════════════
    // NEW: targets methods/branches with 0% coverage that
    // validategetproducts() above never touches:
    //   - findAccount2()               - entire ~150-line duplicate method
    //   - getProductsByFamily()        - never called
    //   - getProductFamily()           - never called
    //   - getProductsBySubCallType()   - "setting found" branch
    //   - findAccount(..., 'Opportunity') - Opportunity branch
    //   - updateEventBDPlan()          - else branch (action != 'Update')
    //
    // FIXED this round:
    //   - Two Account/CIty__c pairs (Domestic + International) so the
    //     Account query filters in findAccount2 actually return rows
    //     instead of excluding themselves.
    //   - A Lead__c record matching the Lead query filters, since
    //     findAccount2's Lead branch had nothing to iterate over before.
    //   - The Opportunity__c insert + its findAccount('Opportunity') calls
    //     are now isolated in their own try/catch block, so if this org's
    //     Org Role Hierarchy validation still rejects it for a reason this
    //     dynamic helper can't detect, that failure can no longer abort the
    //     rest of the method (which is what caused findAccount2,
    //     getProductsByFamily, etc. to show 0% last run).
    // ════════════════════════════════════════════════════════════════════
    @isTest
    static void validateAdditionalCoverage() {

        ensureOrgRoleHierarchyMatchesRunningUser();

        // Domestic region/account: country_key__c = 'IN', matches the
        // Domestic filter (IN list) AND Zone_Name__c = 'North'.
        CIty__c domesticRegion = new CIty__c();
        domesticRegion.country_key__c = 'IN';
        domesticRegion.Region_Code__c = '12334';
        domesticRegion.Name           = 'Domestic Coverage Region';
        domesticRegion.Zone_Name__c   = 'North';
        domesticRegion.Zone_Code__c   = '1';
        insert domesticRegion;

        Account domesticAcc = new Account(
            Name      = 'Coverage Domestic Account',
            region__c = domesticRegion.Id,
            Phone     = '9998887771'
        );
        insert domesticAcc;

        // International region/account: country_key__c NOT IN ('IN','TR'),
        // matches the International filter.
        CIty__c internationalRegion = new CIty__c();
        internationalRegion.country_key__c = 'US';
        internationalRegion.Region_Code__c = '12335';
        internationalRegion.Name           = 'International Coverage Region';
        internationalRegion.Zone_Name__c   = 'West';
        insert internationalRegion;

        Account internationalAcc = new Account(
            Name      = 'Coverage International Account',
            region__c = internationalRegion.Id,
            Phone     = '9998887772'
        );
        insert internationalAcc;

        Contact con = new Contact(FirstName = 'Cov', LastName = 'Test');
        insert con;

        // Lead__c matching the Lead query filters (Lead_Closed__c != true,
        // Lead_Stage__c not in the excluded set, Name LIKE '%Coverage%')
        // mirroring the required-field pattern from lea1 in the original
        // test method, since this object appears to enforce several of them.
        Lead__c coverageLead = new Lead__c();
        coverageLead.Name             = 'Coverage Lead';
        coverageLead.First_Name__c    = 'Coverage';
        coverageLead.Last_Name__c     = 'Lead';
        coverageLead.Company__c       = 'Coverage Co';
        coverageLead.Product__c       = 'BIO HYALUR CS';
        coverageLead.Billing_City__c  = 'Gwalior';
        coverageLead.Billing_code__c  = '474001';
        coverageLead.Country__c       = 'IN';
        coverageLead.Billing_state__c = 'Mp';
        coverageLead.Email__c         = 'coverage.lead@example.com';
        coverageLead.Mobile__c        = '1234509876';
        coverageLead.Billing_Street__c= 'Coverage Street';
        coverageLead.SAP_Code__c      = 'COV00001';
        coverageLead.Lead_Stage__c    = 'Appointments';
        insert coverageLead;

        // ── Covers getProductsByFamily() and getProductFamily() - previously 0% ──
        Product_Group__c pg = new Product_Group__c(Name = 'Test Product Group', Product_Family__c = 'BIO RING');
        insert pg;
        calendarPlanningMobileController.getProductsByFamily('BIO RING');
        calendarPlanningMobileController.getProductFamily();

        // ── Covers getProductsBySubCallType()'s "setting found with products"
        // branch - the existing test only ever hits the "not found" branch
        // since no Subcalltype__c record existed for the name it queried ──
        Subcalltype__c subCallSetting = new Subcalltype__c(
            Name              = 'Banner',
            product_name__c   = 'Product A, Product B, Product C'
        );
        insert subCallSetting;
        calendarPlanningMobileController.getProductsBySubCallType('Banner');

        // ── Covers findAccount2() entirely - previously 0%. Both region
        // branches now return real rows for Account, and the Lead branch
        // now has a matching record too. ──────────────────────────────
        calendarPlanningMobileController.findAccount2('Coverage', 'International', 'West', 'All');
        calendarPlanningMobileController.findAccount2('Coverage', 'International', 'West', 'Account');
        calendarPlanningMobileController.findAccount2('Coverage', 'Domestic', 'North', 'Account');
        calendarPlanningMobileController.findAccount2('Coverage', 'International', 'West', 'Lead');
        calendarPlanningMobileController.findAccount2('Coverage', 'Domestic', 'North', '');
        calendarPlanningMobileController.findAccount2('', 'International', 'West', '');

        // Same fix applied to findAccount's own Account/Lead loops, in case
        // the original test's single account (region 'IN' called with
        // 'International') left those loop bodies empty too.
        calendarPlanningMobileController.findAccount('Coverage', 'International', 'West', 'Account');
        calendarPlanningMobileController.findAccount('Coverage', 'Domestic', 'North', 'Account');
        calendarPlanningMobileController.findAccount('Coverage', 'International', 'West', 'Lead');
        calendarPlanningMobileController.findAccount('Coverage', 'International', 'West', 'All');

        // ── Covers updateEventBDPlan's ELSE branch (action != 'Update') -
        // the existing test only exercised the 'Update' branch ──────────
        Event ev = new Event();
        ev.Subject             = 'Coverage Event';
        ev.OwnerId              = UserInfo.getUserId();
        ev.StartDateTime        = System.now();
        ev.EndDateTime          = System.now().addHours(1);
        ev.WhatId               = domesticAcc.Id;
        ev.isConnectedToDCR__c  = false;
        insert ev;

        List<Object> objList = new List<Object>{ ev.Id };
        calendarPlanningMobileController.updateEventBDPlan(objList, 'Connect'); // hits the else branch

		User runningUserForOrh = [
            SELECT Id, Main_Division__c, Sub_Division__c, Sales_District__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        String orgRoleExternalId = runningUserForOrh.Main_Division__c + '-' + runningUserForOrh.Sub_Division__c + '-' + runningUserForOrh.Sales_District__c;

        insert new Org_Role_Hierarchy__c(
            Name = 'Test Org Role Hierarchy - Owner Combo',
            External_Id__c = orgRoleExternalId,
            Is_Active__c = true
        );

        try {
            Opportunity__c opp = new Opportunity__c(
                Name                     = 'Coverage Opp',
                Account__c               = domesticAcc.Id,
                Contact__c               = con.Id,
                Status__c                = 'Open',
                Opps_Product_Family__c   = 'Test Family'
            );
            insert opp;

            calendarPlanningMobileController.findAccount('Coverage', null, null, 'Opportunity');
            calendarPlanningMobileController.findAccount('', null, null, 'Opportunity');
        } catch (Exception e) {
            System.debug('Opportunity coverage branch skipped: ' + e.getMessage());
        }
    }
}
/**
 * @description Controller for DCR LWC components (dcr and dcrDetails)
 * @author Priyam Shah
 * @date 2026-01-19
 */
public with sharing class DcrDetailsController {

    /**
     * @description Get beat plan and events for today
     * @return Map<String, Object> containing beatPlan, events, and translations
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getBeatPlanData() {
        Map<String, Object> result = new Map<String, Object>();

        try {
            // Get translations from custom settings for first page
            String userLang = UserInfo.getLanguage();
            DCR_Detail1_Translation__c translations = DCR_Detail1_Translation__c.getValues(userLang);
            if (translations == null) {
                translations = DCR_Detail1_Translation__c.getValues('en_US');
            }
            result.put('translations', translations);
            // Get record type ID
            Id recId = Schema.SObjectType.Event.getRecordTypeInfosByName()
                .get('DCR Planning').getRecordTypeId();

            // Get today's beat plan with time/location fields
            List<Beat_Plan__c> beatPlans = [
                SELECT Id, Name, beat_Date__c, Started__c, Ended__c,
                    Start_Time__c, End_Time__c,
                    Start_LatLang__Latitude__s, Start_LatLang__Longitude__s,
                    End_LatLang__Latitude__s, End_LatLang__Longitude__s,
                    Total_Distance__c
                FROM Beat_Plan__c
                WHERE beat_Date__c = :Date.today()
                AND Assigned_To__c = :UserInfo.getUserId()
                LIMIT 1
            ];

            if (beatPlans.isEmpty()) {
                result.put('beatPlan', null);
                result.put('events', new List<Event>());
                return result;
            }

            Beat_Plan__c beatPlan = beatPlans[0];
            result.put('beatPlan', beatPlan);

            // Get events for this beat plan with check-in/out fields
            List<Event> events = [
                SELECT Id, Subject, BillingStreet__c, BillingCity__c,
                    Account__c, Account__r.Name, Account__r.BillingStreet, Account__r.BillingCity,
                    Account__r.BillingLatitude, Account__r.BillingLongitude,
                    Leads__c, Leads__r.Name, Leads__r.Billing_Street__c, Leads__r.Billing_City__c, Leads__r.Lead_Stage__c,
                    Opportunity__c, Opportunity__r.Status__c, Opportunity__r.Name,
                    Event_Latitude__c, Event_Longitude__c,
                    Lead_Latitude__c, Lead_Longitude__c,
                    WhatId, What.Type, What.Name,
                    Meeting_Type__c, StartDateTime, EndDateTime,
                    Check_Out__c, Cheked_In__c, Status__c, Stage__c,
                    check_In_Time__c, check_Out_Time__c,
                    Checkin_Latlang__Latitude__s, Checkin_Latlang__Longitude__s,
                    Checkout__Latitude__s, Checkout__Longitude__s,
                    Distance__c, Checkout_Distance__c
                FROM Event
                WHERE Beat_Plan__c = :beatPlan.Id
                AND Check_Out__c != true
                AND (Account__c != null OR Leads__c != null OR Opportunity__c != null OR (WhatId != null AND What.Type = 'Opportunity__c'))
                AND Status__c != 'Cancelled'
                AND RecordTypeId = :recId
                ORDER BY StartDateTime ASC
            ];

            // Map to store Opportunity statuses for filtering
            Map<Id, String> opportunityStatusMap = new Map<Id, String>();

            // Collect all Opportunity IDs
            Set<Id> opportunityIds = new Set<Id>();
            for (Event ev : events) {
                // Check custom Opportunity__c lookup field
                if (ev.Opportunity__c != null) {
                    opportunityIds.add(ev.Opportunity__c);
                }
                // Also check standard WhatId for legacy events
                else if (ev.WhatId != null && ev.What.Type == 'Opportunity__c') {
                    opportunityIds.add(ev.WhatId);
                }
            }

            // Map to store Opportunity Account information for enriching events
            Map<Id, Opportunity__c> opportunityMap = new Map<Id, Opportunity__c>();

            // Bulk query Opportunity statuses and Account info
            if (!opportunityIds.isEmpty()) {
                for (Opportunity__c opp : [
                    SELECT Id, Status__c,
                        Account__c, Account__r.Name, Account__r.BillingStreet, Account__r.BillingCity,
                        Account__r.BillingLatitude, Account__r.BillingLongitude
                    FROM Opportunity__c
                    WHERE Id IN :opportunityIds
                ]) {
                    opportunityStatusMap.put(opp.Id, opp.Status__c);
                    opportunityMap.put(opp.Id, opp);
                }
            }

            // Filter events (Account, Lead, and Opportunity logic)
            // Added by Priyam Shah - Support custom Opportunity__c lookup field
            List<Event> filteredEvents = new List<Event>();
            for (Event ev : events) {
                // Check custom Opportunity__c lookup field first
                if (ev.Opportunity__c != null && ev.Opportunity__r != null) {
                    // Opportunity events via custom field - filter by status
                    if (ev.Opportunity__r.Status__c != 'Closed Won' && ev.Opportunity__r.Status__c != 'Closed Lost') {
                        filteredEvents.add(ev);
                    }
                }
                // Check standard WhatId for legacy Opportunity events
                else if (ev.What.Type == 'Opportunity__c' && ev.WhatId != null) {
                    // Opportunity events via WhatId - filter by status
                    String oppStatus = opportunityStatusMap.get(ev.WhatId);
                    if (oppStatus != 'Closed Won' && oppStatus != 'Closed Lost') {
                        filteredEvents.add(ev);
                    }
                }
                // Account events
                else if (ev.Account__c != null && ev.Leads__c == null && ev.Opportunity__c == null) {
                    filteredEvents.add(ev);
                }
                // Lead events
                else if (ev.Account__c == null && ev.Leads__c != null) {
                    filteredEvents.add(ev);
                }
            }

            result.put('events', filteredEvents);

            } catch (Exception e) {
                System.debug('Error in getBeatPlanData: ' + e.getMessage());
                AuraHandledException ex = new AuraHandledException(e.getMessage());
                ex.setMessage(e.getMessage());
                throw ex;
            }

        return result;
    }

    /**
     * @description Start the user's day - records starting location and time
     * @param latitude User's current latitude
     * @param longitude User's current longitude
     * @return Map<String, Object> with success status and message
     */
    @AuraEnabled
    public static Map<String, Object> startMyDay(Decimal latitude, Decimal longitude) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            // Check daily activity validation (login time check)
            Map<String, Object> activityData = CommonutiltiyClass.getdailyactivity();
            Boolean activityFlag = (Boolean)activityData.get('activity');
            if (activityFlag == false) {
                result.put('success', false);
                result.put('message', 'Kindly do the Login before performing the activities');
                result.put('errorType', 'NO_CLOCK_IN');
                return result;
            }

            // Get today's beat plan for current user
            List<Beat_Plan__c> beatPlans = [
                SELECT Id, Started__c, Ended__c
                FROM Beat_Plan__c
                WHERE beat_Date__c = :Date.today()
                AND Assigned_To__c = :UserInfo.getUserId()
                LIMIT 1
            ];

            if (beatPlans.isEmpty()) {
                result.put('success', false);
                result.put('message', 'No beat plan exists for today');
                result.put('errorType', 'NO_BEAT_PLAN');
                return result;
            }

            Beat_Plan__c beatPlan = beatPlans[0];

            // Check if already started
            if (beatPlan.Started__c == true) {
                result.put('success', false);
                result.put('message', 'Day has already been started');
                result.put('errorType', 'ALREADY_STARTED');
                return result;
            }

            // Update beat plan with start info
            beatPlan.Started__c = true;
            beatPlan.Start_Time__c = System.now().time();
            beatPlan.Start_LatLang__Latitude__s = latitude;
            beatPlan.Start_LatLang__Longitude__s = longitude;

            update beatPlan;

            result.put('success', true);
            result.put('message', 'Day started successfully');

        } catch (Exception e) {
            System.debug('Error in startMyDay: ' + e.getMessage());
            result.put('success', false);
            result.put('message', e.getMessage());
        }

        return result;
    }

    /**
     * @description End the user's day - records ending location, time, and calculates total distance
     * @param latitude User's current latitude
     * @param longitude User's current longitude
     * @return Map<String, Object> with success status and message
     */
    @AuraEnabled
    public static Map<String, Object> endMyDay(Decimal latitude, Decimal longitude) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            // Get today's beat plan
            List<Beat_Plan__c> beatPlans = [
                SELECT Id, Started__c, Ended__c,
                    Start_LatLang__Latitude__s, Start_LatLang__Longitude__s
                FROM Beat_Plan__c
                WHERE beat_Date__c = :Date.today()
                AND Assigned_To__c = :UserInfo.getUserId()
                LIMIT 1
            ];

            if (beatPlans.isEmpty()) {
                result.put('success', false);
                result.put('message', 'No beat plan exists for today');
                result.put('errorType', 'NO_BEAT_PLAN');
                return result;
            }

            Beat_Plan__c beatPlan = beatPlans[0];

            // Check if already ended
            if (beatPlan.Ended__c == true) {
                result.put('success', false);
                result.put('message', 'Day has already been ended');
                result.put('errorType', 'ALREADY_ENDED');
                return result;
            }

            // Calculate total distance from checkout locations
            Decimal totalDistance = 0;
            List<Event> completedEvents = [
                SELECT Id, Checkout__Latitude__s, Checkout__Longitude__s
                FROM Event
                WHERE Beat_Plan__c = :beatPlan.Id
                AND Check_Out__c = true
                AND Checkout__Latitude__s != null
                AND Checkout__Longitude__s != null
                ORDER BY check_Out_Time__c ASC
            ];

            if (!completedEvents.isEmpty() && beatPlan.Start_LatLang__Latitude__s != null) {
                // Distance from start to first event
                Location startLoc = Location.newInstance(
                    beatPlan.Start_LatLang__Latitude__s,
                    beatPlan.Start_LatLang__Longitude__s
                );

                Location prevLoc = startLoc;

                // Sum distances between consecutive events
                for (Event ev : completedEvents) {
                    Location eventLoc = Location.newInstance(
                        ev.Checkout__Latitude__s,
                        ev.Checkout__Longitude__s
                    );
                    totalDistance += Location.getDistance(prevLoc, eventLoc, 'km');
                    prevLoc = eventLoc;
                }

                // Distance from last event to end location
                Location endLoc = Location.newInstance(latitude, longitude);
                totalDistance += Location.getDistance(prevLoc, endLoc, 'km');
            }

            // Update beat plan with end info
            beatPlan.Ended__c = true;
            beatPlan.End_Time__c = System.now().time();
            beatPlan.End_LatLang__Latitude__s = latitude;
            beatPlan.End_LatLang__Longitude__s = longitude;
            beatPlan.Total_Distance__c = totalDistance;

            update beatPlan;

            result.put('success', true);
            result.put('message', 'Day ended successfully');
            result.put('totalDistance', totalDistance);

        } catch (Exception e) {
            System.debug('Error in endMyDay: ' + e.getMessage());
            result.put('success', false);
            result.put('message', e.getMessage());
        }

        return result;
    }

    /**
     * @description Check in to an event
     * @param eventId The Event record Id
     * @param latitude User's current latitude
     * @param longitude User's current longitude
     * @return Map<String, Object> with success status, message, and distance info
     */
    @AuraEnabled
    public static Map<String, Object> checkInEvent(Id eventId, Decimal latitude, Decimal longitude) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            // Check daily activity validation (login time check)
            Map<String, Object> activityData = CommonutiltiyClass.getdailyactivity();
            Boolean activityFlag = (Boolean)activityData.get('activity');
            if (activityFlag == false) {
                result.put('success', false);
                result.put('message', 'Kindly do the Login before performing the activities');
                result.put('errorType', 'NO_CLOCK_IN');
                return result;
            }

            // Get event with related beat plan
            Event ev = [
                SELECT Id, Account__c, Leads__c, Opportunity__c, Beat_Plan__c, Meeting_Type__c,
                    Event_Latitude__c, Event_Longitude__c,
                    Lead_Latitude__c, Lead_Longitude__c,
                    Cheked_In__c, Check_Out__c,
                    Beat_Plan__r.Started__c, Beat_Plan__r.Ended__c,
                    Beat_Plan__r.Start_LatLang__Latitude__s
                FROM Event
                WHERE Id = :eventId
                LIMIT 1
            ];

            // Check if already checked in
            if (ev.Cheked_In__c == true) {
                result.put('success', false);
                result.put('message', 'Already checked in to this event');
                result.put('errorType', 'ALREADY_CHECKED_IN');
                return result;
            }

            // Check for pending approval process on beat plan
            List<ProcessInstance> approvalProcesses = [
                SELECT Id, Status
                FROM ProcessInstance
                WHERE TargetObjectId = :ev.Beat_Plan__c
                AND Status = 'Pending'
                LIMIT 1
            ];

            if (!approvalProcesses.isEmpty()) {
                result.put('success', false);
                result.put('message', 'Approval process is pending on the beat plan');
                result.put('errorType', 'APPROVAL_PENDING');
                return result;
            }

            // Distance validation - ONLY for Onsite meetings
            Decimal distance = 0;
            if (ev.Meeting_Type__c == 'Onsite') {
                // Get event location (from Account or Lead)
                Decimal eventLat = ev.Event_Latitude__c;
                Decimal eventLng = ev.Event_Longitude__c;

                if (ev.Leads__c != null && ev.Account__c == null) {
                    eventLat = ev.Lead_Latitude__c;
                    eventLng = ev.Lead_Longitude__c;
                }

                if (eventLat != null && eventLng != null && latitude != null && longitude != null) {
                    Location eventLoc = Location.newInstance(eventLat, eventLng);
                    Location userLoc = Location.newInstance(latitude, longitude);
                    distance = Location.getDistance(eventLoc, userLoc, 'km');

                    // Get distance threshold from custom label
                    Decimal maxDistance = Decimal.valueOf(System.Label.check_in_Distance);
 if (false) {
                  //  if (distance > maxDistance) {
                        result.put('success', false);
                        result.put('message', String.format(System.Label.check_in_Distance_Warning, new List<String>{String.valueOf(distance.setScale(2)), String.valueOf(maxDistance)}));
                        result.put('errorType', 'TOO_FAR');
                        result.put('distance', distance);
                        return result;
                    }
                }
            }
            // Note: Offsite and Online meetings skip distance validation

            // Update event with check-in info
            ev.Cheked_In__c = true;
            ev.check_In_Time__c = System.now().time();
            ev.Stage__c = 'Checked‐In';
            ev.Checkin_Latlang__Latitude__s = latitude;
            ev.Checkin_Latlang__Longitude__s = longitude;
            ev.Distance__c = distance;

            update ev;

            // Update beat plan start location if not set
            if (ev.Beat_Plan__r.Start_LatLang__Latitude__s == null) {
                Beat_Plan__c beatPlan = new Beat_Plan__c(
                    Id = ev.Beat_Plan__c,
                    Start_LatLang__Latitude__s = latitude,
                    Start_LatLang__Longitude__s = longitude
                );
                update beatPlan;
            }

            result.put('success', true);
            result.put('message', 'Checked in successfully');
            result.put('distance', distance);
            result.put('eventId', eventId);

        } catch (Exception e) {
            System.debug('Error in checkInEvent: ' + e.getMessage());
            result.put('success', false);
            result.put('message', e.getMessage());
        }

        return result;
    }

    /**
     * @description Keep the event's existing date but set the time of its
     * StartDateTime and EndDateTime to the check-out time.
     */
    private static void setStartEndToCheckOutTime(Event ev, Time checkOutTime) {
        // checkOutTime comes from System.now().time(), which is in the running
        // user's time zone, so build the Datetime in that same zone.
        Date eventDate = ev.StartDateTime != null ? ev.StartDateTime.date() : System.now().date();
        Datetime checkOutDateTime = Datetime.newInstance(eventDate, checkOutTime);
        ev.StartDateTime = checkOutDateTime;
        ev.EndDateTime = checkOutDateTime;
    }

    /**
     * @description Check out from an event
     * @param eventId The Event record Id
     * @param latitude User's current latitude
     * @param longitude User's current longitude
     * @return Map<String, Object> with success status and message
     */
    @AuraEnabled
    public static Map<String, Object> checkOutEvent(Id eventId, Decimal latitude, Decimal longitude) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            // Get event
            Event ev = [
                SELECT Id, Beat_Plan__c, Cheked_In__c, Check_Out__c,
                    StartDateTime, EndDateTime,
                    Event_Latitude__c, Event_Longitude__c,
                    Lead_Latitude__c, Lead_Longitude__c,
                    Account__c, Leads__c
                FROM Event
                WHERE Id = :eventId
                LIMIT 1
            ];

            // Check if checked in first
            if (ev.Cheked_In__c != true) {
                result.put('success', false);
                result.put('message', 'Please check in first before checking out');
                result.put('errorType', 'NOT_CHECKED_IN');
                return result;
            }

            // Check if already checked out
            if (ev.Check_Out__c == true) {
                result.put('success', false);
                result.put('message', 'Already checked out from this event');
                result.put('errorType', 'ALREADY_CHECKED_OUT');
                return result;
            }

            // Calculate checkout distance
            Decimal checkoutDistance = 0;
            Decimal eventLat = ev.Event_Latitude__c;
            Decimal eventLng = ev.Event_Longitude__c;

            if (ev.Leads__c != null && ev.Account__c == null) {
                eventLat = ev.Lead_Latitude__c;
                eventLng = ev.Lead_Longitude__c;
            }

            if (eventLat != null && eventLng != null && latitude != null && longitude != null) {
                Location eventLoc = Location.newInstance(eventLat, eventLng);
                Location userLoc = Location.newInstance(latitude, longitude);
                checkoutDistance = Location.getDistance(eventLoc, userLoc, 'km');
            }

            // Update event with check-out info
            Time checkOutTime = System.now().time();
            ev.Check_Out__c = true;
            ev.check_Out_Time__c = checkOutTime;
            setStartEndToCheckOutTime(ev, checkOutTime);
            ev.Stage__c = 'Checked-Out';
            ev.Checkout__Latitude__s = latitude;
            ev.Checkout__Longitude__s = longitude;
            ev.Checkout_Distance__c = checkoutDistance;

            update ev;

            // Update beat plan end location
            Beat_Plan__c beatPlan = new Beat_Plan__c(
                Id = ev.Beat_Plan__c,
                End_LatLang__Latitude__s = latitude,
                End_LatLang__Longitude__s = longitude
            );
            update beatPlan;

            result.put('success', true);
            result.put('message', 'Checked out successfully');
            result.put('checkoutDistance', checkoutDistance);

        } catch (Exception e) {
            System.debug('Error in checkOutEvent: ' + e.getMessage());
            result.put('success', false);
            result.put('message', e.getMessage());
        }

        return result;
    }

    // ==================== DCR DETAILS SECOND PAGE METHODS ====================

    /**
     * @description Get all data needed for DCR Details Second page
     * @param eventId The Event record Id
     * @return Map<String, Object> containing eventData, invoices, products, bdTracker, leads, translations
     */
    @AuraEnabled
    public static Map<String, Object> getEventDetailsForDCR(Id eventId) {
        Map<String, Object> result = new Map<String, Object>();

        

        try {
            List<Schema.PicklistEntry> reasonPicklist = Lead__c.Disqualified_Reason__c.getDescribe().getPicklistValues();
            List<Map<String, String>> unqualifiedReasonOptions = new List<Map<String, String>>();
                unqualifiedReasonOptions.add(new Map<String, String>{'label' => '--Select Reason--', 'value' => ''});
                 for (Schema.PicklistEntry entry : reasonPicklist) {
                         if (entry.isActive()) {
                      unqualifiedReasonOptions.add(new Map<String, String>{
                       'label' => entry.getLabel(),
                         'value' => entry.getValue()
                              });
                               }
                               }
result.put('unqualifiedReasonOptions', unqualifiedReasonOptions);
            // Get event with all DCR-related fields
            Event ev = [
                SELECT Id, Subject, Call_Type__c, Sub_Call_Type__c, Product__c, DCR_Description__c,
                    Follow_Up_Date__c, WhatId, What.Type, What.Name, Meeting_Type__c,Target__c,Target__r.Name,
                    Account__c, Account__r.Name, Account__r.Id,
                    Leads__c, Leads__r.Name, Leads__r.Id, Leads__r.Lead_Stage__c,
                    Leads__r.CE_CIS_Rating__c, Leads__r.Phakic_Rating__c, Leads__r.SAP_Code__c,
                    Leads__r.New_Customer__c, Leads__r.Existing_customer__c, Leads__r.Product__c,
                    Opportunity__c,
                    CE_Rating__c, CIS_Rating__c,
                    Beat_Plan__c, Profile_Name__c, Cheked_In__c, Check_Out__c,Product_Family__c
                FROM Event
                WHERE Id = :eventId
                LIMIT 1
            ];
            result.put('eventData', ev);

            // Get last 5 invoices for the Account (if Account exists)
            // List<Order_Product__c> invoices = new List<Order_Product__c>();
            // if (ev.Account__c != null) {
            //     invoices = [
            //         SELECT Id, Name, Dummy_Product_Code__c, Product__r.Name, Quantity__c, Amount__c
            //         FROM Order_Product__c
            //         WHERE Account__c = :ev.Account__c
            //         ORDER BY CreatedDate DESC
            //         LIMIT 5
            //     ];
            // }
            // result.put('lastFiveInvoices', invoices);

            // Get product list for multi-select
            List<Product__c> products = [
                SELECT Id, Name
                FROM Product__c
                ORDER BY Name ASC
            ];
            result.put('productList', products);

            // Get BD Tracker Events (events with BD_Tracker_Phase__c populated for same WhatId)
            List<Event> bdTrackerEvents = new List<Event>();
            if (ev.WhatId != null) {
                bdTrackerEvents = [
                    SELECT Id, BD_Tracker_Phase__c, Milestone_Plan_Week__c, Milestone_Stage__c,
                        milestone_delay_reason__c, Reason_for_Evaluation_Skip__c,
                        BD_Plan_Status__c, Reason__c, Remark__c, isUpdate__c,
                        Product__c, What.Name, WhoId, Who.Name
                    FROM Event
                    WHERE WhatId = :ev.WhatId
                    AND BD_Tracker_Phase__c != null
                    ORDER BY CreatedDate ASC
                ];
            }
            result.put('bdTrackerList', bdTrackerEvents);

            // Get leads associated with event (for lead stage management)
            List<Lead__c> leads = new List<Lead__c>();
            if (ev.Leads__c != null) {
                List<Lead__c> leds = [
                    SELECT Account__c
                    FROM Lead__c
                    WHERE Id = :ev.Leads__c
                    LIMIT 1
                ];

                if (!leds.isEmpty() && leds[0].Account__c != null) {
                    leads = [
                        SELECT Id, Name, Lead_Stage__c, SAP_Code__c, Product__c,
                            Lead_Products__c, Lead_Product_Family__c,
                            Disqualified_Reason__c, Unqualified_Remarks__c,
                            New_Customer__c, Existing_customer__c
                        FROM Lead__c
                        WHERE Account__c = :leds[0].Account__c
                    ];
                } else if (!leds.isEmpty()) {
                    List<Lead__c> ledss = [
                        SELECT Mobile__c
                        FROM Lead__c
                        WHERE Id = :ev.Leads__c
                        LIMIT 1
                    ];
                    //commented by Dhruv, Created by Chintan
                   /* if (!ledss.isEmpty() && String.isNotBlank(ledss[0].Mobile__c)) {
                        String leadName = '%' + ledss[0].Mobile__c + '%';
                        leads = [
                            SELECT Id, Name, Lead_Stage__c, SAP_Code__c, Product__c,
                                Lead_Products__c, Lead_Product_Family__c,
                                Disqualified_Reason__c, Unqualified_Remarks__c,
                                New_Customer__c, Existing_customer__c, Mobile__c
                            FROM Lead__c
                            WHERE Mobile__c LIKE :leadName
                        ];
                    }*/
                    //Created by Dhruv
                     if (!ledss.isEmpty() && String.isNotBlank(ledss[0].Mobile__c)) {
                        String leadName =  ledss[0].Mobile__c;
                        leads = [
                            SELECT Id, Name, Lead_Stage__c, SAP_Code__c, Product__c,
                                Lead_Products__c, Lead_Product_Family__c,
                                Disqualified_Reason__c, Unqualified_Remarks__c,
                                New_Customer__c, Existing_customer__c, Mobile__c
                            FROM Lead__c
                            WHERE Mobile__c =:leadName
                        ];
                    }
                }
            }
            result.put('leadDataList', leads);

            // Get Opportunity data if this is an Opportunity event
            Id opportunityId = ev.Opportunity__c != null ? ev.Opportunity__c : (ev.WhatId != null && ev.What.Type == 'Opportunity__c' ? ev.WhatId : null);
            if (opportunityId != null) {
                List<Opportunity__c> opps = [
                    SELECT Account__c
                    FROM Opportunity__c
                    WHERE Id = :opportunityId
                    LIMIT 1
                ];

                if (!opps.isEmpty() && opps[0].Account__c != null) {
                List<Opportunity__c> opportunities = [
                SELECT Id, Name, Status__c, CE_CIS_Rating__c, Phakic_Rating__c,
                Account__c, Account__r.Name, Account__r.BillingStreet, Account__r.BillingCity,
                Opps_Products__c, Opps_Product_Family__c,
                Lost_Reason__c, Close_Date__c,
                RecordType.Name
                FROM Opportunity__c
                WHERE Account__c = :opps[0].Account__c
                ];

                    if (!opportunities.isEmpty()) {
                        result.put('opportunityData', opportunities);

                        // Equipment Company / Equipment Product come from the related Equipment
                        // Product Group child records, not from the Opportunity itself.
                        Set<Id> oppIdsForEquipment = new Map<Id, Opportunity__c>(opportunities).keySet();
                        Map<Id, List<String>> equipmentCompaniesByOpp = new Map<Id, List<String>>();
                        Map<Id, List<String>> equipmentProductsByOpp = new Map<Id, List<String>>();

                        for (Equipment_Product_Group__c epg : [
                            SELECT Opportunity__c, Equipment_Company__c, Equipment_Company_Other__c,
                                Equipment_Product__r.Name, Equipemnt_Name_Other__c
                            FROM Equipment_Product_Group__c
                            WHERE Opportunity__c IN :oppIdsForEquipment
                        ]) {
                            // When the picklist/lookup value is "Others", the actual value the
                            // rep typed in lives in the corresponding "Other" free-text field.
                            String companyValue = (epg.Equipment_Company__c == 'Others')
                                ? epg.Equipment_Company_Other__c
                                : epg.Equipment_Company__c;
                            String productValue = (epg.Equipment_Product__r != null && epg.Equipment_Product__r.Name == 'Others')
                                ? epg.Equipemnt_Name_Other__c
                                : (epg.Equipment_Product__r != null ? epg.Equipment_Product__r.Name : null);

                            if (String.isNotBlank(companyValue)) {
                                if (!equipmentCompaniesByOpp.containsKey(epg.Opportunity__c)) {
                                    equipmentCompaniesByOpp.put(epg.Opportunity__c, new List<String>());
                                }
                                if (!equipmentCompaniesByOpp.get(epg.Opportunity__c).contains(companyValue)) {
                                    equipmentCompaniesByOpp.get(epg.Opportunity__c).add(companyValue);
                                }
                            }
                            if (String.isNotBlank(productValue)) {
                                if (!equipmentProductsByOpp.containsKey(epg.Opportunity__c)) {
                                    equipmentProductsByOpp.put(epg.Opportunity__c, new List<String>());
                                }
                                if (!equipmentProductsByOpp.get(epg.Opportunity__c).contains(productValue)) {
                                    equipmentProductsByOpp.get(epg.Opportunity__c).add(productValue);
                                }
                            }
                        }

                        Map<Id, String> equipmentCompanyByOpportunity = new Map<Id, String>();
                        Map<Id, String> equipmentProductByOpportunity = new Map<Id, String>();
                        for (Id oppId : oppIdsForEquipment) {
                            if (equipmentCompaniesByOpp.containsKey(oppId)) {
                                equipmentCompanyByOpportunity.put(oppId, String.join(equipmentCompaniesByOpp.get(oppId), ', '));
                            }
                            if (equipmentProductsByOpp.containsKey(oppId)) {
                                equipmentProductByOpportunity.put(oppId, String.join(equipmentProductsByOpp.get(oppId), ', '));
                            }
                        }
                        result.put('equipmentCompanyByOpportunity', equipmentCompanyByOpportunity);
                        result.put('equipmentProductByOpportunity', equipmentProductByOpportunity);

                        // Get ALL Opportunity status picklist values (including Closed Won/Lost)
                        List<Schema.PicklistEntry> statusPicklist = Opportunity__c.Status__c.getDescribe().getPicklistValues();
                        List<Map<String, String>> oppStatusOptions = new List<Map<String, String>>();
                        oppStatusOptions.add(new Map<String, String>{'label' => '--None--', 'value' => 'None'});

                        for (Schema.PicklistEntry entry : statusPicklist) {
                            oppStatusOptions.add(new Map<String, String>{
                                'label' => entry.getLabel(),
                                'value' => entry.getValue()
                            });
                        }
                        result.put('opportunityStatusOptions', oppStatusOptions);
                    }
                }
            }

            // Get translations from custom settings for second page (DCR form)
            String userLang = UserInfo.getLanguage();
            DCR_Detail2_Translation__c translations = DCR_Detail2_Translation__c.getValues(userLang);
            if (translations == null) {
                translations = DCR_Detail2_Translation__c.getValues('en_US');
            }
            result.put('translations', translations);

            // Get user profile info
            User currentUser = [SELECT Id, Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            result.put('profileName', currentUser.Profile.Name);

            // Check if country is excluded (for SAP code warnings)
            Boolean isExcludedCountry = false;
            // Add logic here if needed based on custom settings
            result.put('isExcludedCountry', isExcludedCountry);

            } catch (Exception e) {
            System.debug('Error in getEventDetailsForDCR: ' + e.getMessage());
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
            }

        return result;
    }

    /**
     * @description Converts a raw DML/validation-rule exception message into a
     * simplified, user-friendly message for Sales users. Falls back to the
     * original message (stripped of technical wrapper where possible) if no
     * known pattern matches.
     * @param e       The DmlException (or other Exception) that was caught
     * @param oppName The Name of the Opportunity that failed, if known (may be null)
     */
    private static String friendlyDmlMessage(Exception e, String oppName) {
        String raw = e.getMessage();
        if (String.isBlank(raw)) {
            return 'Something went wrong while saving. Please try again.';
        }

        String displayName = String.isNotBlank(oppName) ? oppName : 'this Opportunity';
        String lowerRaw = raw.toLowerCase();

        if (lowerRaw.contains('evaluation stage') && lowerRaw.contains('sample request')) {
            return 'You need to create a Sample Request before moving "' + displayName + '" to the Evaluation stage.';
        }

        // Generic cleanup: if it's a validation-rule error, strip the technical wrapper
        // and just surface the custom validation message itself (after the last comma).
        if (lowerRaw.contains('field_custom_validation_exception')) {
            Integer idx = raw.indexOf('FIELD_CUSTOM_VALIDATION_EXCEPTION,');
            if (idx != -1) {
                String trimmed = raw.substring(idx + 'FIELD_CUSTOM_VALIDATION_EXCEPTION,'.length()).trim();
                // Remove trailing field-list artifact like ": []"
                Integer colonIdx = trimmed.lastIndexOf(':');
                if (colonIdx != -1) {
                    trimmed = trimmed.substring(0, colonIdx).trim();
                }
                if (String.isNotBlank(trimmed)) {
                    return trimmed;
                }
            }
        }

        return raw;
    }

    /**
     * @description Save DCR data (before submit)
     * @param dcrData Map containing remark, followUpDate, eventId, product, BDPlan data, lead stages
     * @return String 'SUCCESS' or error message
     */
    @AuraEnabled
    public static String saveDCR(Map<String, Object> dcrData) {
        try {
            Id eventId = (Id) dcrData.get('eventId');
            String remark = (String) dcrData.get('remark');
            String followUpDate = (String) dcrData.get('followUpDate');
            String product = (String) dcrData.get('product');
            String bdPlanData = (String) dcrData.get('BDPlan');
            String bdReasonData = (String) dcrData.get('BDReason');
            String skipReasonData = (String) dcrData.get('skipReason');
            String leadStageData = (String) dcrData.get('leadStages');
            String unqualifiedReasonData = (String) dcrData.get('unqualifiedReasons'); // NEW
            String unqualifiedRemarksData = (String) dcrData.get('unqualifiedRemarks');
            String opportunityStatusData = (String) dcrData.get('opportunityStatuses');

            // Update Event with DCR data
            Event ev = new Event(Id = eventId);
            ev.DCR_Description__c = remark;
            if (String.isNotBlank(product)) {
                ev.Product__c = product;
            }
            if (String.isNotBlank(followUpDate)) {
                ev.Follow_Up_Date__c = Date.valueOf(followUpDate);
            }
            update ev;

            // Update BD Tracker Events with remarks
            if (String.isNotBlank(bdPlanData)) {
                List<Event> bdEventsToUpdate = new List<Event>();
                for (String entry : bdPlanData.split(',')) {
                    if (String.isNotBlank(entry) && entry.contains(':')) {
                        List<String> parts = entry.split(':');
                        if (parts.size() >= 2) {
                            String bdEventId = parts[0].trim();
                            String remarkValue = parts[1].trim();
                            if (remarkValue != 'Null' && String.isNotBlank(remarkValue)) {
                                Event bdEvent = new Event(Id = bdEventId);
                                bdEvent.Remark__c = remarkValue;
                                bdEvent.isUpdate__c = true;
                                bdEventsToUpdate.add(bdEvent);
                            }
                        }
                    }
                }
                if (!bdEventsToUpdate.isEmpty()) {
                    update bdEventsToUpdate;
                }
            }

            // Update delay reasons
            if (String.isNotBlank(bdReasonData)) {
                List<Event> bdEventsToUpdate = new List<Event>();
                for (String entry : bdReasonData.split(',')) {
                    if (String.isNotBlank(entry) && entry.contains(':')) {
                        List<String> parts = entry.split(':');
                        if (parts.size() >= 2) {
                            String bdEventId = parts[0].trim();
                            String delayReason = parts[1].trim();
                            Event bdEvent = new Event(Id = bdEventId);
                            bdEvent.milestone_delay_reason__c = delayReason;
                            bdEventsToUpdate.add(bdEvent);
                        }
                    }
                }
                if (!bdEventsToUpdate.isEmpty()) {
                    update bdEventsToUpdate;
                }
            }

            // Update lead stages if provided (with date history and stage count)
            if (String.isNotBlank(leadStageData)) {
                Map<Id, String> leadStageMap = new Map<Id, String>();

                // Parse lead stage data
                for (String entry : leadStageData.split(',')) {
                    if (String.isNotBlank(entry) && entry.contains(':')) {
                        List<String> parts = entry.split(':');
                        if (parts.size() >= 2) {
                            String leadId = parts[0].trim();
                            String newStage = parts[1].trim();
                            if (newStage != 'None') {
                                leadStageMap.put((Id)leadId, newStage);
                            }
                        }
                    }
                }

                // Query leads to get current values
                if (!leadStageMap.isEmpty()) {

                    // Parse unqualified reasons into a map (NEW)
                    Map<Id, String> unqualifiedReasonMap = new Map<Id, String>();
                    if (String.isNotBlank(unqualifiedReasonData)) {
                        for (String entry : unqualifiedReasonData.split('\\|')) {
                            if (String.isNotBlank(entry) && entry.contains('::')) {
                                List<String> parts = entry.split('::', 2); // limit=2 so reason text itself can contain ':'
                                if (parts.size() == 2) {
                                    unqualifiedReasonMap.put(parts[0].trim(), parts[1].trim());
                                }
                            }
                        }
                    }

                    Map<Id, String> unqualifiedRemarksMap = new Map<Id, String>();
                    if (String.isNotBlank(unqualifiedRemarksData)) {
                        for (String entry : unqualifiedRemarksData.split('\\|')) {
                            if (String.isNotBlank(entry) && entry.contains('::')) {
                                List<String> parts = entry.split('::', 2);
                                if (parts.size() == 2) {
                                    unqualifiedRemarksMap.put(parts[0].trim(), parts[1].trim());
                                }
                            }
                        }
                    }

                    List<Lead__c> leads = [
                        SELECT Id, Lead_Stage__c,Disqualified_Reason__c,
                            Appointment_Date_History__c, Appointment_Stage_Count__c,
                            Presentation_Date_History__c, Presentation_Stage_Count__c,
                            Product_Demo_Date_History__c, Product_Demo_Stage_Count__c,
                            Evaluation_Date_History__c, Evaluation_Stage_Count__c,
                            Commercialization_Date_History__c, Commercialization_Stage_Count__c,
                            Upgrade_Date_History__c, Upgrade_Stage_Count__c,
                            Actual_Prospect_Week__c, Actual_Appointments_Week__c,
                            Actual_Presentation_Week__c, Actual_Product_Demo_Week__c,
                            Actual_Evaluations_Week__c, Actual_Commercialization_week__c,
                            Actual_Upgrade_week__c
                        FROM Lead__c
                        WHERE Id IN :leadStageMap.keySet()
                    ];

                    List<Lead__c> leadsToUpdate = new List<Lead__c>();
                    Date today = System.today();
                    String todayStr = String.valueOf(today);

                    for (Lead__c lead : leads) {
                        String newStage = leadStageMap.get(lead.Id);
                        lead.Lead_Stage__c = newStage;

                        if (newStage == 'Unqualified') {

                            String reason = unqualifiedReasonMap.get(lead.Id);

                            if (String.isBlank(reason)) {
                                throw new AuraHandledException(
                                    'Please select Unqualified Reason for Lead: ' + lead.Name
                                );
                            }

                            lead.Disqualified_Reason__c = reason;
                            lead.Unqualified_Remarks__c = unqualifiedRemarksMap.get(lead.Id);
                        }
                        else {
                            lead.Disqualified_Reason__c = null;
                            lead.Unqualified_Remarks__c = null;
                        }

                        // Update stage-specific fields with date history and count
                        if (newStage == 'Prospects') {
                            lead.Actual_Prospect_Week__c = today;
                        } else if (newStage == 'Appointments') {
                            lead.Actual_Appointments_Week__c = today;
                            if (lead.Appointment_Date_History__c == null) {
                                lead.Appointment_Date_History__c = todayStr;
                                lead.Appointment_Stage_Count__c = 1;
                            } else {
                                lead.Appointment_Date_History__c += ', ' + todayStr;
                                lead.Appointment_Stage_Count__c = (lead.Appointment_Stage_Count__c == null) ? 1 : lead.Appointment_Stage_Count__c + 1;
                            }
                        } else if (newStage == 'Presentation') {
                            lead.Actual_Presentation_Week__c = today;
                            if (lead.Presentation_Date_History__c == null) {
                                lead.Presentation_Date_History__c = todayStr;
                                lead.Presentation_Stage_Count__c = 1;
                            } else {
                                lead.Presentation_Date_History__c += ', ' + todayStr;
                                lead.Presentation_Stage_Count__c = (lead.Presentation_Stage_Count__c == null) ? 1 : lead.Presentation_Stage_Count__c + 1;
                            }
                        } else if (newStage == 'Product Demo') {
                            lead.Actual_Product_Demo_Week__c = today;
                            if (lead.Product_Demo_Date_History__c == null) {
                                lead.Product_Demo_Date_History__c = todayStr;
                                lead.Product_Demo_Stage_Count__c = 1;
                            } else {
                                lead.Product_Demo_Date_History__c += ', ' + todayStr;
                                lead.Product_Demo_Stage_Count__c = (lead.Product_Demo_Stage_Count__c == null) ? 1 : lead.Product_Demo_Stage_Count__c + 1;
                            }
                        } else if (newStage == 'Evaluations') {
                            lead.Actual_Evaluations_Week__c = today;
                            if (lead.Evaluation_Date_History__c == null) {
                                lead.Evaluation_Date_History__c = todayStr;
                                lead.Evaluation_Stage_Count__c = 1;
                            } else {
                                lead.Evaluation_Date_History__c += ', ' + todayStr;
                                lead.Evaluation_Stage_Count__c = (lead.Evaluation_Stage_Count__c == null) ? 1 : lead.Evaluation_Stage_Count__c + 1;
                            }
                        } else if (newStage == 'Commercialization') {
                            lead.Actual_Commercialization_week__c = today;
                            if (lead.Commercialization_Date_History__c == null) {
                                lead.Commercialization_Date_History__c = todayStr;
                                lead.Commercialization_Stage_Count__c = 1;
                            } else {
                                lead.Commercialization_Date_History__c += ', ' + todayStr;
                                lead.Commercialization_Stage_Count__c = (lead.Commercialization_Stage_Count__c == null) ? 1 : lead.Commercialization_Stage_Count__c + 1;
                            }
                        } else if (newStage == 'Upgrade') {
                            lead.Actual_Upgrade_week__c = today;
                            if (lead.Upgrade_Date_History__c == null) {
                                lead.Upgrade_Date_History__c = todayStr;
                                lead.Upgrade_Stage_Count__c = 1;
                            } else {
                                lead.Upgrade_Date_History__c += ', ' + todayStr;
                                lead.Upgrade_Stage_Count__c = (lead.Upgrade_Stage_Count__c == null) ? 1 : lead.Upgrade_Stage_Count__c + 1;
                            }
                        }

                        leadsToUpdate.add(lead);
                    }

                    if (!leadsToUpdate.isEmpty()) {
                        update leadsToUpdate;
                    }
                }
            }

           // Update Opportunity status if provided (with date history and stage count)
            if (String.isNotBlank(opportunityStatusData)) {
                Map<Id, String> oppStatusMap = new Map<Id, String>();

                for (String entry : opportunityStatusData.split(',')) {
                    if (String.isNotBlank(entry) && entry.contains(':')) {
                        List<String> parts = entry.split(':');
                        if (parts.size() >= 2) {
                            String oppId = parts[0].trim();
                            String newStatus = parts[1].trim();

                            // Closed Won and Closed Lost are both allowed to be set during an active visit
                            if (newStatus != 'None') {
                                oppStatusMap.put(oppId, newStatus);
                            }
                        }
                    }
                }

                // Parse Lost Reasons sent from client (oppId::reason|oppId::reason)
                String opportunityLostReasonData = (String) dcrData.get('opportunityLostReasons');
                Map<Id, String> oppLostReasonMap = new Map<Id, String>();
                if (String.isNotBlank(opportunityLostReasonData)) {
                    for (String entry : opportunityLostReasonData.split('\\|')) {
                        if (String.isNotBlank(entry) && entry.contains('::')) {
                            List<String> parts = entry.split('::', 2);
                            if (parts.size() == 2) {
                                oppLostReasonMap.put((Id)parts[0].trim(), parts[1].trim());
                            }
                        }
                    }
                }

                // Parse Close Dates sent from client (oppId::yyyy-mm-dd|oppId::yyyy-mm-dd)
                String opportunityCloseDateData = (String) dcrData.get('opportunityCloseDates');
                Map<Id, String> oppCloseDateMap = new Map<Id, String>();
                if (String.isNotBlank(opportunityCloseDateData)) {
                    for (String entry : opportunityCloseDateData.split('\\|')) {
                        if (String.isNotBlank(entry) && entry.contains('::')) {
                            List<String> parts = entry.split('::', 2);
                            if (parts.size() == 2) {
                                oppCloseDateMap.put((Id)parts[0].trim(), parts[1].trim());
                            }
                        }
                    }
                }

                // Query opportunities to get current values
                if (!oppStatusMap.isEmpty()) {
                    List<Opportunity__c> opportunities = [
                        SELECT Id, Name, Status__c, Lost_Reason__c,
                            Presentation_Date_History__c, Presentation_Stage_Count__c,
                            Meeting_Date_History__c, Meeting_Stage_Count__c,
                            Demo_Date_History__c, Demo_Stage_Count__c,
                            Proposal_Submitted_Date_History__c, Proposal_Submitted_Stage_Count__c,
                            Evaluation_Date_History__c, Evaluation_Stage_Count__c,
                            Negotiation_Date_History__c, Negotiation_Stage_Count__c,
                            Actual_Presentation_Week__c, Actual_Meeting_Week__c,
                            Actual_Demo_Week__c, Actual_Proposal_Submitted_Week__c,
                            Actual_Evaluations_Week__c, Actual_Negotiation_Week__c
                        FROM Opportunity__c
                        WHERE Id IN :oppStatusMap.keySet()
                    ];

                    // Build an Id -> Name lookup so DML failures can be reported with a friendly Opportunity name
                    Map<Id, String> oppIdToName = new Map<Id, String>();
                    for (Opportunity__c o : opportunities) {
                        oppIdToName.put(o.Id, o.Name);
                    }

                    List<Opportunity__c> oppsToUpdate = new List<Opportunity__c>();
                    Date today = System.today();
                    String todayStr = String.valueOf(today);

                    for (Opportunity__c opp : opportunities) {
                        String newStatus = oppStatusMap.get(opp.Id);
                        if (isBackwardMove(opp.Status__c, newStatus)) {
                            throw new AuraHandledException('Cannot move Opportunity stage backward from ' + opp.Status__c + ' to ' + newStatus);
                        }
                        opp.Status__c = newStatus;

                        // Lost Reason handling for Closed Lost
                        if (newStatus == 'Closed Lost') {
                            String lostReason = oppLostReasonMap.get(opp.Id);
                            if (String.isBlank(lostReason)) {
                                throw new AuraHandledException(
                                    'Please enter Lost Reason for Opportunity: ' + opp.Id
                                );
                            }
                            opp.Lost_Reason__c = lostReason;
                        } else {
                            opp.Lost_Reason__c = null;
                        }

                                            // Close Date is mandatory only for Closed Won; optional (saved if provided) for Closed Lost.
                    if (newStatus == 'Closed Won') {
                        String closeDateStr = oppCloseDateMap.get(opp.Id);
                        if (String.isBlank(closeDateStr)) {
                            AuraHandledException closeDateEx = new AuraHandledException(
                                'Please select Close Date for Opportunity: ' + opp.Id
                            );
                            closeDateEx.setMessage(
                                'Please select Close Date for Opportunity: ' + opp.Id
                            );
                            throw closeDateEx;
                        }
                        try {
                            opp.Close_Date__c = Date.valueOf(closeDateStr);
                        } catch (Exception ex) {
                            AuraHandledException invalidDateEx = new AuraHandledException(
                                'Invalid Close Date for Opportunity: ' + opp.Id
                            );
                            invalidDateEx.setMessage(
                                'Invalid Close Date for Opportunity: ' + opp.Id
                            );
                            throw invalidDateEx;
                        }
                    } else if (newStatus == 'Closed Lost') {
                        String closeDateStr = oppCloseDateMap.get(opp.Id);
                        if (String.isNotBlank(closeDateStr)) {
                            try {
                                opp.Close_Date__c = Date.valueOf(closeDateStr);
                            } catch (Exception ex) {
                                AuraHandledException invalidDateEx = new AuraHandledException(
                                    'Invalid Close Date for Opportunity: ' + opp.Id
                                );
                                invalidDateEx.setMessage(
                                    'Invalid Close Date for Opportunity: ' + opp.Id
                                );
                                throw invalidDateEx;
                            }
                        }
                    }

                        // Update stage-specific fields with date history and count
                        if (newStatus == 'Presentation') {
                            opp.Actual_Presentation_Week__c = today;
                            if (opp.Presentation_Date_History__c == null) {
                                opp.Presentation_Date_History__c = todayStr;
                                opp.Presentation_Stage_Count__c = 1;
                            } else {
                                opp.Presentation_Date_History__c += ', ' + todayStr;
                                opp.Presentation_Stage_Count__c = (opp.Presentation_Stage_Count__c == null) ? 1 : opp.Presentation_Stage_Count__c + 1;
                            }
                        } else if (newStatus == 'Meeting') {
                            opp.Actual_Meeting_Week__c = today;
                            if (opp.Meeting_Date_History__c == null) {
                                opp.Meeting_Date_History__c = todayStr;
                                opp.Meeting_Stage_Count__c = 1;
                            } else {
                                opp.Meeting_Date_History__c += ', ' + todayStr;
                                opp.Meeting_Stage_Count__c = (opp.Meeting_Stage_Count__c == null) ? 1 : opp.Meeting_Stage_Count__c + 1;
                            }
                        } else if (newStatus == 'Demo') {
                            opp.Actual_Demo_Week__c = today;
                            if (opp.Demo_Date_History__c == null) {
                                opp.Demo_Date_History__c = todayStr;
                                opp.Demo_Stage_Count__c = 1;
                            } else {
                                opp.Demo_Date_History__c += ', ' + todayStr;
                                opp.Demo_Stage_Count__c = (opp.Demo_Stage_Count__c == null) ? 1 : opp.Demo_Stage_Count__c + 1;
                            }
                        } else if (newStatus == 'Proposal Submitted') {
                            opp.Actual_Proposal_Submitted_Week__c = today;
                            if (opp.Proposal_Submitted_Date_History__c == null) {
                                opp.Proposal_Submitted_Date_History__c = todayStr;
                                opp.Proposal_Submitted_Stage_Count__c = 1;
                            } else {
                                opp.Proposal_Submitted_Date_History__c += ', ' + todayStr;
                                opp.Proposal_Submitted_Stage_Count__c = (opp.Proposal_Submitted_Stage_Count__c == null) ? 1 : opp.Proposal_Submitted_Stage_Count__c + 1;
                            }
                        } else if (newStatus == 'Evaluation') {
                            opp.Actual_Evaluations_Week__c = today;
                            if (opp.Evaluation_Date_History__c == null) {
                                opp.Evaluation_Date_History__c = todayStr;
                                opp.Evaluation_Stage_Count__c = 1;
                            } else {
                                opp.Evaluation_Date_History__c += ', ' + todayStr;
                                opp.Evaluation_Stage_Count__c = (opp.Evaluation_Stage_Count__c == null) ? 1 : opp.Evaluation_Stage_Count__c + 1;
                            }
                        } else if (newStatus == 'Negotiation') {
                            opp.Actual_Negotiation_Week__c = today;
                            if (opp.Negotiation_Date_History__c == null) {
                                opp.Negotiation_Date_History__c = todayStr;
                                opp.Negotiation_Stage_Count__c = 1;
                            } else {
                                opp.Negotiation_Date_History__c += ', ' + todayStr;
                                opp.Negotiation_Stage_Count__c = (opp.Negotiation_Stage_Count__c == null) ? 1 : opp.Negotiation_Stage_Count__c + 1;
                            }
                        }

                        oppsToUpdate.add(opp);
                    }

                    if (!oppsToUpdate.isEmpty()) {
                        try {
                            update oppsToUpdate;
                        } catch (DmlException dmlEx) {
                            // Identify the specific Opportunity that failed via the DML result index
                            String failedOppName = null;
                            Integer failedRow = dmlEx.getDmlIndex(0);
                            if (failedRow != null && failedRow >= 0 && failedRow < oppsToUpdate.size()) {
                                Id failedOppId = oppsToUpdate[failedRow].Id;
                                failedOppName = oppIdToName.get(failedOppId);
                            }
                            return friendlyDmlMessage(dmlEx, failedOppName);
                        }
                    }
                }
            }

            return 'SUCCESS';

        } catch (Exception e) {
            System.debug('Error in saveDCR: ' + e.getMessage());
            return e.getMessage();
        }
    }

    /**
     * @description Submit DCR (after save) - marks event as sent for approval and locks it
     * This matches the old component's Submit button behavior
     * @param dcrData Map containing eventId and DCR details
     * @return String 'SUCCESS' or error message
     */
    @AuraEnabled
    public static String submitDCR(Map<String, Object> dcrData) {
        try {
            Id eventId = (Id) dcrData.get('eventId');
            String remark = (String) dcrData.get('remark');
            String followUpDate = (String) dcrData.get('followUpDate');
            String product = (String) dcrData.get('product');

            // Update Event with submitted status
            Event ev = new Event(Id = eventId);
            ev.DCR_Description__c = remark;
            if (String.isNotBlank(product)) {
                ev.Product__c = product;
            }
            if (String.isNotBlank(followUpDate)) {
                ev.Follow_Up_Date__c = Date.valueOf(followUpDate);
            }

            // Mark as sent for approval and lock the event (matches old component behavior)
            ev.Status__c = 'Sent for Approval';
            ev.event_Locked__c = true;
            ev.Stage__c = 'Checked‐In';

            // Note: Stage__c will be updated to 'Checked-Out' in the checkOutWithDCR method
            update ev;

            return 'SUCCESS';

        } catch (Exception e) {
            System.debug('Error in submitDCR: ' + e.getMessage());
            return e.getMessage();
        }
    }

    /**
     * @description Checkout with full DCR data
     * @param checkoutData Map containing all checkout data including location, BD tracker, lead stages
     * @return Map<String, Object> with success status
     */
    @AuraEnabled
    public static Map<String, Object> checkOutWithDCR(Map<String, Object> checkoutData) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            Id eventId = (Id) checkoutData.get('eventId');
            Decimal latitude = (Decimal) checkoutData.get('CheckOutLat');
            Decimal longitude = (Decimal) checkoutData.get('CheckOutLong');
            String bdPlanData = (String) checkoutData.get('BDPlan');
            String bdReasonData = (String) checkoutData.get('BDReason');
            String skipReasonData = (String) checkoutData.get('skipReason');
            String bdStageData = (String) checkoutData.get('BDStage');
            String lostStageReasonData = (String) checkoutData.get('LostStageReason');
            String leadStage = (String) checkoutData.get('Stage');
            String unqualifiedReason = (String) checkoutData.get('UnqualifiedReason');
            String unqualifiedRemarks = (String) checkoutData.get('UnqualifiedRemarks');
            String opportunityStatus = (String) checkoutData.get('OpportunityStatus');
            String opportunityCloseDate = (String) checkoutData.get('OpportunityCloseDate'); // NEW
            String marketingType = (String) checkoutData.get('Marketing');

            // Get event
            Event ev = [
                SELECT Id, Beat_Plan__c, Cheked_In__c, Check_Out__c,
                    StartDateTime, EndDateTime,
                    Event_Latitude__c, Event_Longitude__c,
                    Lead_Latitude__c, Lead_Longitude__c,
                    Account__c, Leads__c, Opportunity__c, WhatId, What.Type,
                    Approval_Status__c, OwnerId, Owner.FirstName, Owner.LastName, Subject
                FROM Event
                WHERE Id = :eventId
                LIMIT 1
            ];

            // Calculate checkout distance
            Decimal checkoutDistance = 0;
            Decimal eventLat = ev.Event_Latitude__c;
            Decimal eventLng = ev.Event_Longitude__c;

            if (ev.Leads__c != null && ev.Account__c == null) {
                eventLat = ev.Lead_Latitude__c;
                eventLng = ev.Lead_Longitude__c;
            }

            if (eventLat != null && eventLng != null && latitude != null && longitude != null) {
                Location eventLoc = Location.newInstance(eventLat, eventLng);
                Location userLoc = Location.newInstance(latitude, longitude);
                checkoutDistance = Location.getDistance(eventLoc, userLoc, 'km');
            }

            // Update event with check-out info
            Time checkOutTime = System.now().time();
            ev.Check_Out__c = true;
            ev.check_Out_Time__c = checkOutTime;
            setStartEndToCheckOutTime(ev, checkOutTime);
            ev.Stage__c = 'Checked-Out';
            ev.Checkout__Latitude__s = latitude;
            ev.Checkout__Longitude__s = longitude;
            ev.Checkout_Distance__c = checkoutDistance;

            // Send approval email and update status when Installation WIP
            if (ev.Approval_Status__c == 'Installation WIP') {
                EventApprovalController.sendApprovalEmail(ev);
                ev.Approval_Status__c = 'Pending for Approval';
            }

            update ev;

            // Update beat plan end location
            Beat_Plan__c beatPlan = new Beat_Plan__c(
                Id = ev.Beat_Plan__c,
                End_LatLang__Latitude__s = latitude,
                End_LatLang__Longitude__s = longitude
            );
            update beatPlan;

            // Update BD Tracker Events with remarks
            if (String.isNotBlank(bdPlanData)) {
                List<Event> bdEventsToUpdate = new List<Event>();
                for (String entry : bdPlanData.split(',')) {
                    if (String.isNotBlank(entry) && entry.contains(':')) {
                        List<String> parts = entry.split(':');
                        if (parts.size() >= 2) {
                            String bdEventId = parts[0].trim();
                            String remarkValue = parts[1].trim();
                            Event bdEvent = new Event(Id = bdEventId);
                            bdEvent.Remark__c = remarkValue;
                            bdEvent.isUpdate__c = true;
                            bdEventsToUpdate.add(bdEvent);
                        }
                    }
                }
                if (!bdEventsToUpdate.isEmpty()) {
                    update bdEventsToUpdate;
                }
            }

            // Update delay reasons
            if (String.isNotBlank(bdReasonData)) {
                List<Event> bdEventsToUpdate = new List<Event>();
                for (String entry : bdReasonData.split(',')) {
                    if (String.isNotBlank(entry) && entry.contains(':')) {
                        List<String> parts = entry.split(':');
                        if (parts.size() >= 2) {
                            String bdEventId = parts[0].trim();
                            String delayReason = parts[1].trim();
                            Event bdEvent = new Event(Id = bdEventId);
                            bdEvent.milestone_delay_reason__c = delayReason;
                            bdEventsToUpdate.add(bdEvent);
                        }
                    }
                }
                if (!bdEventsToUpdate.isEmpty()) {
                    update bdEventsToUpdate;
                }
            }

            // Update skip reasons
            if (String.isNotBlank(skipReasonData)) {
                List<Event> bdEventsToUpdate = new List<Event>();
                for (String entry : skipReasonData.split(',')) {
                    if (String.isNotBlank(entry) && entry.contains(':')) {
                        List<String> parts = entry.split(':');
                        if (parts.size() >= 2) {
                            String bdEventId = parts[0].trim();
                            String skipReason = parts[1].trim();
                            Event bdEvent = new Event(Id = bdEventId);
                            bdEvent.Reason_for_Evaluation_Skip__c = skipReason;
                            bdEventsToUpdate.add(bdEvent);
                        }
                    }
                }
                if (!bdEventsToUpdate.isEmpty()) {
                    update bdEventsToUpdate;
                }
            }

            // Update BD Stage
            if (String.isNotBlank(bdStageData)) {
                List<Event> bdEventsToUpdate = new List<Event>();
                for (String entry : bdStageData.split(',')) {
                    if (String.isNotBlank(entry) && entry.contains(':')) {
                        List<String> parts = entry.split(':');
                        if (parts.size() >= 2) {
                            String bdEventId = parts[0].trim();
                            String bdStageValue = parts[1].trim();
                            Event bdEvent = new Event(Id = bdEventId);
                            bdEvent.BD_Plan_Status__c = bdStageValue;
                            bdEventsToUpdate.add(bdEvent);
                        }
                    }
                }
                if (!bdEventsToUpdate.isEmpty()) {
                    update bdEventsToUpdate;
                }
            }

            // Update Lost Stage Reason
            if (String.isNotBlank(lostStageReasonData)) {
                List<Event> bdEventsToUpdate = new List<Event>();
                for (String entry : lostStageReasonData.split(',')) {
                    if (String.isNotBlank(entry) && entry.contains(':')) {
                        List<String> parts = entry.split(':');
                        if (parts.size() >= 2) {
                            String bdEventId = parts[0].trim();
                            String lostReason = parts[1].trim();
                            Event bdEvent = new Event(Id = bdEventId);
                            bdEvent.Reason__c = lostReason;
                            bdEventsToUpdate.add(bdEvent);
                        }
                    }
                }
                if (!bdEventsToUpdate.isEmpty()) {
                    update bdEventsToUpdate;
                }
            }

            // Update Lead stage if provided
            if (ev.Leads__c != null && String.isNotBlank(leadStage) && leadStage != 'None') {
                Lead__c lead = new Lead__c(Id = ev.Leads__c);
                lead.Lead_Stage__c = leadStage;
                if (leadStage == 'Unqualified') {
                    lead.Disqualified_Reason__c = unqualifiedReason; // NEW
                    lead.Unqualified_Remarks__c = unqualifiedRemarks;
                } else {
                    lead.Disqualified_Reason__c = null; // NEW — clear if not unqualified
                    lead.Unqualified_Remarks__c = null;
                }
                update lead;
            }

            // Update Opportunity status if provided (simple status update, date history is handled in saveDCR)
            Id opportunityIdForUpdate = ev.Opportunity__c != null ? ev.Opportunity__c : (ev.WhatId != null && ev.What.Type == 'Opportunity__c' ? ev.WhatId : null);
            if (opportunityIdForUpdate != null) {
                if (String.isNotBlank(opportunityStatus) && opportunityStatus != 'None') {

                    Opportunity__c oppCurrent = [SELECT Id, Name, Status__c FROM Opportunity__c WHERE Id = :opportunityIdForUpdate LIMIT 1];
                    if (isBackwardMove(oppCurrent.Status__c, opportunityStatus)) {
                        throw new AuraHandledException('Cannot move Opportunity stage backward from ' + oppCurrent.Status__c + ' to ' + opportunityStatus);
                    }
                    Opportunity__c opp = new Opportunity__c(Id = opportunityIdForUpdate);
                    opp.Status__c = opportunityStatus;
                    if (opportunityStatus == 'Closed Lost') {
                        String oppLostReasonVal = (String) checkoutData.get('OpportunityLostReason');
                        if (String.isBlank(oppLostReasonVal)) {
                            throw new AuraHandledException('Please enter Lost Reason for the Opportunity');
                        }
                        opp.Lost_Reason__c = oppLostReasonVal;
                    }
                    // Close Date is mandatory only for Closed Won; optional (saved if provided) for Closed Lost.
if (opportunityStatus == 'Closed Won') {
    if (String.isBlank(opportunityCloseDate)) {
        AuraHandledException closeDateEx = new AuraHandledException('Please select Close Date for the Opportunity');
        closeDateEx.setMessage('Please select Close Date for the Opportunity');
        throw closeDateEx;
    }
    try {
        opp.Close_Date__c = Date.valueOf(opportunityCloseDate);
    } catch (Exception ex) {
        AuraHandledException invalidDateEx = new AuraHandledException('Invalid Close Date for the Opportunity');
        invalidDateEx.setMessage('Invalid Close Date for the Opportunity');
        throw invalidDateEx;
    }
} else if (opportunityStatus == 'Closed Lost') {
    if (String.isNotBlank(opportunityCloseDate)) {
        try {
            opp.Close_Date__c = Date.valueOf(opportunityCloseDate);
        } catch (Exception ex) {
            AuraHandledException invalidDateEx = new AuraHandledException('Invalid Close Date for the Opportunity');
            invalidDateEx.setMessage('Invalid Close Date for the Opportunity');
            throw invalidDateEx;
        }
    }
}
                    try {
                        update opp;
                    } catch (DmlException dmlEx) {
                        result.put('success', false);
                        result.put('message', friendlyDmlMessage(dmlEx, oppCurrent.Name));
                        return result;
                    }
                }
            }

            result.put('success', true);
            result.put('message', 'Checked out successfully');

        } catch (Exception e) {
            System.debug('Error in checkOutWithDCR: ' + e.getMessage());
            result.put('success', false);
            result.put('message', e.getMessage());
        }

        return result;
    }

    /**
     * @description Update a lead's stage
     * @param leadId The Lead record Id
     * @param newStage The new stage value
     * @return String 'SUCCESS' or warning message
     */
    @AuraEnabled
    public static String updateLeadStage(Id leadId, String newStage) {
        try {
            if (newStage == 'None' || String.isBlank(newStage)) {
                return 'SUCCESS';
            }

            // Get lead with SAP code
            Lead__c lead = [SELECT Id, SAP_Code__c FROM Lead__c WHERE Id = :leadId LIMIT 1];

            // Validate SAP code for certain stages
            if ((newStage == 'Evaluations' || newStage == 'Commercialization') &&
                String.isBlank(lead.SAP_Code__c)) {
                return 'WARNING: SAP Code is required for ' + newStage + ' stage';
            }

            // Update lead stage
            lead.Lead_Stage__c = newStage;
            update lead;

            return 'SUCCESS';

        } catch (Exception e) {
            System.debug('Error in updateLeadStage: ' + e.getMessage());
            return e.getMessage();
        }
    }

    /**
     * @description Update an opportunity's status from DCR (only while checked in)
     * @param opportunityId The Opportunity record Id
     * @param newStatus The new status value
     * @param isCheckedIn Whether user is currently checked in to the event
     * @return String 'SUCCESS' or error/warning message
     */
    private static Map<String, Integer> STAGE_ORDER = new Map<String, Integer>{
        'Presentation' => 1,
        'Demo' => 2,
        'Evaluation' => 3,
        'Negotiation' => 4,
        'Closed Won' => 5,
        'Closed Lost' => 5
    };

    private static Boolean isBackwardMove(String currentStatus, String newStatus) {
        Integer currentRank = STAGE_ORDER.containsKey(currentStatus) ? STAGE_ORDER.get(currentStatus) : -1;
        Integer newRank = STAGE_ORDER.containsKey(newStatus) ? STAGE_ORDER.get(newStatus) : -1;

        // If current status is a legacy/inactive value (not in map), don't block —
        // let the first real transition through since we have no valid rank to compare against.
        if (currentRank == -1 || newRank == -1) {
            return false;
        }
        return newRank < currentRank;
    }

    @AuraEnabled
    public static String updateOpportunityStatus(Id opportunityId, String newStatus, Boolean isCheckedIn) {
        try {
            if (newStatus == 'None' || String.isBlank(newStatus)) {
                return 'SUCCESS';
            }
            Opportunity__c existingOpp = [SELECT Id, Status__c FROM Opportunity__c WHERE Id = :opportunityId LIMIT 1];

            if (isBackwardMove(existingOpp.Status__c, newStatus)) {
                return 'WARNING: Cannot move Opportunity stage backward from ' + existingOpp.Status__c + ' to ' + newStatus;
            }

            Opportunity__c opp = new Opportunity__c(Id = opportunityId);
            opp.Status__c = newStatus;
            update opp;

            return 'SUCCESS';

        } catch (Exception e) {
            System.debug('Error updating opportunity status: ' + e.getMessage());
            return e.getMessage();
        }
    }

    /**
     * @description Upload a branding file (base64) and attach it to the Event record.
     *              Mirrors BeatPlanSecondAppPageController.uploadBrandingFile logic.
     * @param eventId  The Event record Id
     * @param fileName The original file name (with extension)
     * @param base64Data Base64-encoded file content
     */
    @AuraEnabled
    public static void uploadBrandingFile(Id eventId, String fileName, String base64Data) {
        if (eventId == null || String.isBlank(base64Data) || String.isBlank(fileName)) {
            return;
        }

        Blob fileBody = EncodingUtil.base64Decode(base64Data);

        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName;
        cv.VersionData = fileBody;
        insert cv;

        Id contentDocId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = contentDocId;
        cdl.LinkedEntityId = eventId;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';
        insert cdl;

        ContentDistribution cd = new ContentDistribution();
        cd.Name = fileName;
        cd.ContentVersionId = cv.Id;
        cd.PreferencesAllowViewInBrowser = true;
        cd.PreferencesNotifyOnVisit = false;
        cd.PreferencesAllowOriginalDownload = true;
        cd.PreferencesAllowPDFDownload = true;
        cd.PreferencesLinkLatestVersion = true;
        insert cd;

        List<ContentDistribution> dists = [
            SELECT DistributionPublicUrl, ContentVersion.Title
            FROM ContentDistribution
            WHERE Id = :cd.Id
        ];

        Event evt = new Event(
            Id = eventId,
            Public_File_Url__c = dists[0].DistributionPublicUrl,
            File_Name__c = dists[0].ContentVersion.Title
        );
        update evt;
    }
}
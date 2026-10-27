public with sharing class loginlogoutcontroller {
    @AuraEnabled(cacheable=true)
    public static UserAndCountrySetting getCurrentUserAndSettings() {
        // Query current user details
        User currentUser = [
            SELECT Id, SmallPhotoUrl, FullPhotoUrl, Country__c, Name 
            FROM User 
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        
        // Query custom setting records
        // 
        Leavepolicy__c lvc=Leavepolicy__c.getInstance(currentUser.Country__c);
        /*  List<Leavepolicy__c> leavepolicysetting = [
SELECT Id, Name,Past_days__c // Add relevant fields here
FROM Leavepolicy__c
WHERE Name = :currentUser.Country__c // Match with user's country
];*/
        
        // Prepare the wrapper response
        UserAndCountrySetting result = new UserAndCountrySetting();
        result.currentUser = currentUser;
        result.dtDiff = Integer.valueOf(lvc!=null ? lvc.Past_days__c : 0);
        
        return result;
    }
    
    public class UserAndCountrySetting {
        @AuraEnabled
        public User currentUser;
        @AuraEnabled
        public Integer dtDiff;
    }
    @AuraEnabled(cacheable=true)
    public static Beat_Plan__c getBeatPlanStatus() {
        // Get the current logged-in user ID
        Id currentUserId = UserInfo.getUserId();
        system.debug('Fetching Beat Plan for User ID: ' + currentUserId);
        
        try {
            // Query Beat_Plan__c records for today and assigned to the logged-in user
            Beat_Plan__c beatPlan = [
                SELECT Id, Name, Beat_Date__c, Login_Time__c,Assigned_To__c,Logout_Time__c,Event_type_Name__c,Approval_status__c,
                Login_Latitude__c, Login_Longitude__c, Event_Type__c
                FROM Beat_Plan__c 
                WHERE Beat_Date__c =: System.today() AND Assigned_To__c = :currentUserId limit 1
            ];
            
            system.debug('Beat Plan fetched successfully: ' + beatPlan);
            return beatPlan;
        } catch (QueryException qe) {
            // Handle cases where no record is found or other query issues
            system.debug('No Beat Plan found for today or query error: ' + qe.getMessage());
            return null;
        } catch (Exception ex) {
            // Handle any unexpected errors
            system.debug('Unexpected error while fetching Beat Plan: ' + ex.getMessage());
            return null;
        }
    }
    
    @AuraEnabled
    public static void insertDailyActivity(Decimal latitude, Decimal longitude) {
        // Convert latitude and longitude to strings
        String latitudeStr = String.valueOf(latitude);
        String longitudeStr = String.valueOf(longitude);
        System.debug('Latitude: ' + latitudeStr);
        System.debug('Longitude: ' + longitudeStr);
        
        // Get the current logged-in user and today's date
        Id currentUserId = UserInfo.getUserId();
        System.debug('Current User ID: ' + currentUserId);
        Date today = System.today();
        
        try {
            // Query existing Beat Plan for the logged-in user for today
            List<Beat_Plan__c> records = [
                SELECT Approval_status__c, Assigned_To__c, BUI__c, BeatMonth__c, BeatYr__c, Beat_Date__c, 
                Conpansation_Off_rejection__c, Country__c, Description__c, Duration__c, End_LatLang__Latitude__s,
                End_LatLang__Longitude__s, End_LatLang__c, End_Time__c, Ended__c, Event_Type__c, Event_type_Name__c,
                Final_Approved__c, Id, IsDeleted, Joint_User__c, L1_Manager__c,Leave_rejection__c, Login_Time__c, Logout_Latitude__c,
                Logout_Longitude__c, Logout_Time__c, Name, No_reporting__c, Out_of_office_rejection__c, OwnerId, Start_LatLang__Latitude__s,
                Start_LatLang__Longitude__s, Start_LatLang__c, Start_Time__c, Started__c, State__c,Total_Distance__c, login_Longitude__c,
                login_latitude__c FROM Beat_Plan__c
                WHERE Beat_Date__c = :today 
                AND Assigned_To__c = :currentUserId
                LIMIT 1
            ];
            
            if (!records.isEmpty()) {
                // Record exists, so update it
                Beat_Plan__c dailyActivity = records[0];
                dailyActivity.Login_Time__c = System.now();
                dailyActivity.Login_Latitude__c = latitudeStr;
                dailyActivity.Login_Longitude__c = longitudeStr;
                
                // Determine Event_Type__c based on conditions
                if (dailyActivity.Approval_status__c == 'Approved' && 
                    dailyActivity.Event_type_Name__c == 'First Half Leave' && 
                    dailyActivity.Login_Time__c != null) {
                        dailyActivity.Event_Type__c = '1/2PL+1/2P';
                    } else if (dailyActivity.Approval_status__c == 'Approved' && 
                               dailyActivity.Event_type_Name__c == 'Second Half Leave' && 
                               dailyActivity.Login_Time__c != null) {
                                   dailyActivity.Event_Type__c = '1/2P+1/2PL';
                               } else if (dailyActivity.Approval_status__c == 'Rejected' && 
                                          dailyActivity.Event_type_Name__c == 'Full Day Leave' && 
                                          dailyActivity.Login_Time__c != null) {
                                              dailyActivity.Event_Type__c = 'P';
                                          } else if (dailyActivity.Login_Time__c != null && 
                                                     (String.isBlank(dailyActivity.Approval_status__c) || 
                                                      dailyActivity.Approval_status__c == 'Rejected')) {
                                                          dailyActivity.Event_Type__c = 'P';
                                                      }
                
                // Update the record
                update dailyActivity;
            } else {
                // No record exists, so create a new one
                Beat_Plan__c newActivity = new Beat_Plan__c();
                newActivity.Login_Time__c = System.now();
                newActivity.Beat_Date__c = today;
                newActivity.Login_Latitude__c = latitudeStr;
                newActivity.Login_Longitude__c = longitudeStr;
                newActivity.Assigned_To__c = currentUserId;
                newActivity.Event_Type__c = 'P';
                
                // Insert the new record
                insert newActivity;
            }
        } catch (DmlException e) {
            System.debug('DML Exception: ' + e.getMessage());
            throw new AuraHandledException('An error occurred while logging your activity.');
        } catch (Exception ex) {
            System.debug('Unexpected Exception: ' + ex.getMessage());
            throw new AuraHandledException('An unexpected error occurred.');
        }
    }
    
    @AuraEnabled
    public static void logoutActivity(Decimal latitude, Decimal longitude) {
        // Convert latitude and longitude to strings
        String latitudeStr = String.valueOf(latitude);
        String longitudeStr = String.valueOf(longitude);
        System.debug('Logout Latitude: ' + latitudeStr);
        System.debug('Logout Longitude: ' + longitudeStr);
        
        // Get the current logged-in user and today's date
        Id currentUserId = UserInfo.getUserId();
        System.debug('Current User ID: ' + currentUserId);
        Date today = System.today();
        
        try {
            // Query Beat_Plan__c records for the current user and today's date
            List<Beat_Plan__c> records = [
                SELECT Id, Assigned_To__c, Logout_Time__c, Beat_Date__c, 
                Logout_Latitude__c, Logout_Longitude__c, Event_Type__c
                FROM Beat_Plan__c
                WHERE Beat_Date__c = :today
                AND Assigned_To__c = :currentUserId
                LIMIT 1
            ];
            
            if (!records.isEmpty()) {
                // Record exists, so update it
                Beat_Plan__c dailyActivity = records[0];
                dailyActivity.Logout_Time__c = System.now();
                dailyActivity.Logout_Latitude__c = latitudeStr;
                dailyActivity.Logout_Longitude__c = longitudeStr;
                
                // Update the record
                update dailyActivity;
                System.debug('Logout activity updated successfully for record ID: ' + dailyActivity.Id);
            } else {
                // No record exists for the user on today's date
                System.debug('No Beat Plan record found for today. Logout activity not recorded.');
            }
        } catch (DmlException e) {
            // Handle DML exceptions
            System.debug('DML Exception: ' + e.getMessage());
            throw new AuraHandledException('An error occurred while recording your logout activity.');
        } catch (Exception ex) {
            // Handle unexpected exceptions
            System.debug('Unexpected Exception: ' + ex.getMessage());
            throw new AuraHandledException('An unexpected error occurred.');
        }
    }
    
    
    @AuraEnabled
    public static String applyLeave(String reason, String leaveType) {
        System.debug('Reason: ' + reason);
        System.debug('Leave Type: ' + leaveType);
        
        // Get current user ID and today's date
        Id currentUserId = UserInfo.getUserId();
        System.debug('Current User ID: ' + currentUserId);
        Date today = System.today();
        
        try {
            // Query Beat_Plan__c records for the current user and today's date
            List<Beat_Plan__c> records = [
                SELECT Id, Login_Time__c, Event_type_Name__c, Assigned_To__c, Approval_status__c, 
                Beat_Date__c, Login_Latitude__c, Login_Longitude__c, Event_Type__c 
                FROM Beat_Plan__c 
                WHERE Beat_Date__c = :today 
                AND Assigned_To__c = :currentUserId 
                LIMIT 1
            ];
            
            // Check if a leave request has already been approved
            for (Beat_Plan__c btpl : records) {
                if (String.isNotBlank(btpl.Approval_status__c) && btpl.Approval_status__c !='Rejected') {
                    return 'Already';
                }
            }
            
            if (!records.isEmpty()) {
                // Record exists, update it and create a related Event
                Beat_Plan__c beatPlanData = records[0];
                beatPlanData.Event_type_Name__c = leaveType;
                update beatPlanData;
                // Create the Event
                Event leaveEvent = new Event();
                leaveEvent.Beat_plan__c = beatPlanData.Id;
                leaveEvent.Type_of_leave__c = leaveType;
                leaveEvent.Status__c = 'Planned';
                leaveEvent.Stage__c = 'Planned';
                leaveEvent.Event_Locked__c = true;
                leaveEvent.RecordTypeId = Schema.SObjectType.Event
                    .getRecordTypeInfosByName()
                    .get('DCR Planning')
                    .getRecordTypeId();
                leaveEvent.OwnerId = UserInfo.getUserId();
                leaveEvent.Other_Type__c = true;
                leaveEvent.Subject = 'Leave';
                leaveEvent.Description = reason;
                leaveEvent.DCR_Description__c = reason;
                
                // Set start and end times
                Datetime startDT = System.now();
                Datetime endDT = startDT.addHours(5);
                
                leaveEvent.StartDateTime = startDT;
                leaveEvent.EndDateTime = endDT;
                leaveEvent.Visit_Date__c = startDT.dateGMT();
                leaveEvent.ActivityDateTime = startDT;
                
                // Duration in minutes
                Long milliseconds = endDT.getTime() - startDT.getTime();
                Long seconds = milliseconds / 1000;
                Long durationMinutes = seconds / 60;
                leaveEvent.DurationInMinutes = Integer.valueOf(durationMinutes);
                
                insert leaveEvent;
                
                // Update the Beat_Plan__c record
                
                
                return 'Success';
            } else {
                // No record exists, so create a new Beat_Plan__c and a related Event
                Beat_Plan__c newBeatPlan = new Beat_Plan__c();
                newBeatPlan.Beat_Date__c = today;
                newBeatPlan.Event_type_Name__c = leaveType;
                newBeatPlan.Assigned_To__c = currentUserId;
                insert newBeatPlan;
                
                // Create the Event
                Event leaveEvent = new Event();
                leaveEvent.Beat_plan__c = newBeatPlan.Id;
                leaveEvent.Type_of_leave__c = leaveType;
                leaveEvent.Status__c = 'Planned';
                leaveEvent.Stage__c = 'Planned';
                leaveEvent.Event_Locked__c = true;
                leaveEvent.RecordTypeId = Schema.SObjectType.Event
                    .getRecordTypeInfosByName()
                    .get('DCR Planning')
                    .getRecordTypeId();
                leaveEvent.OwnerId = UserInfo.getUserId();
                leaveEvent.Other_Type__c = true;
                leaveEvent.Subject = 'Leave';
                leaveEvent.Description = reason;
                leaveEvent.DCR_Description__c = reason;
                
                // Set start and end times
                Datetime startDT = System.now();
                Datetime endDT = startDT.addHours(5);
                
                leaveEvent.StartDateTime = startDT;
                leaveEvent.EndDateTime = endDT;
                leaveEvent.Visit_Date__c = startDT.dateGMT();
                leaveEvent.ActivityDateTime = startDT;
                
                // Duration in minutes
                Long milliseconds = endDT.getTime() - startDT.getTime();
                Long seconds = milliseconds / 1000;
                Long durationMinutes = seconds / 60;
                leaveEvent.DurationInMinutes = Integer.valueOf(durationMinutes);
                
                insert leaveEvent;
                
                
                return 'Success';
            }
        } catch (DmlException e) {
            System.debug('DML Exception: ' + e.getMessage());
            throw new AuraHandledException('An error occurred while applying for leave.');
        } catch (Exception ex) {
            System.debug('Unexpected Exception: ' + ex.getMessage());
            throw new AuraHandledException('An unexpected error occurred.');
        }
    }
    
    @AuraEnabled
    public static String applyLeavefuturedate(String reason, String leaveType, Date futureDate,Date holidayDate) {
        System.debug('Reason: ' + reason);
        System.debug('Leave Type: ' + leaveType);
        System.debug('Future Date: ' + futureDate);
        System.debug('holiday Date: ' + holidayDate);
        
        Id currentUserId = UserInfo.getUserId();
        System.debug('Current User ID: ' + currentUserId);
        
        try {
            // Query Beat_Plan__c records for the current user and the specified future date
            List<Beat_Plan__c> records = [
                SELECT Id, Login_Time__c, Assigned_To__c, Assigned_To__r.Name, Approval_status__c, 
                Event_type_Name__c, Beat_Date__c, Login_Latitude__c, Login_Longitude__c, Event_Type__c
                FROM Beat_Plan__c 
                WHERE Beat_Date__c = :futureDate
                AND Assigned_To__c = :currentUserId
                LIMIT 1
            ];
            
            System.debug('Retrieved Records: ' + records);
            
            // Check if any record already has an approval status
            for (Beat_Plan__c btpl : records) {
                if (String.isNotBlank(btpl.Approval_status__c) && btpl.Approval_status__c !='Rejected') {
                    return 'Already';
                }
            }
            
            if (!records.isEmpty()) {
                // Record exists, update it and create a related Event
                Beat_Plan__c existingBeatPlan = records[0];
                existingBeatPlan.Event_type_Name__c = leaveType;
                
                //-------------------Added Start by Yogi------------------//
                if (leaveType == 'Compensation off') {
                    existingBeatPlan.Compensation_Off_Date__c = holidayDate;
                    System.debug('Set Compensation_Off__c = ' + holidayDate);
                }
                System.debug('Beat_Plan before update: ' + existingBeatPlan);
                update existingBeatPlan;
                //-------------------Added End by Yogi------------------//
                
                // Create the Event
                Event leaveEvent = new Event();
                leaveEvent.Beat_plan__c = existingBeatPlan.Id;
                leaveEvent.Type_of_leave__c = leaveType;
                leaveEvent.Status__c = 'Planned';
                leaveEvent.Stage__c = 'Planned';
                leaveEvent.Event_Locked__c = true;
                leaveEvent.RecordTypeId = Schema.SObjectType.Event
                    .getRecordTypeInfosByName()
                    .get('DCR Planning')
                    .getRecordTypeId();
                leaveEvent.OwnerId = UserInfo.getUserId();
                leaveEvent.Other_Type__c = true;
                leaveEvent.Subject = 'Leave';
                leaveEvent.Description = reason;
                leaveEvent.DCR_Description__c = reason;
                
                // Set start and end times
                Datetime startDT = futureDate;
                Datetime endDT = startDT.addHours(5);
                
                leaveEvent.StartDateTime = startDT;
                leaveEvent.EndDateTime = endDT;
                leaveEvent.Visit_Date__c = startDT.dateGMT();
                leaveEvent.ActivityDateTime = startDT;
                
                // Duration in minutes
                Long milliseconds = endDT.getTime() - startDT.getTime();
                Long seconds = milliseconds / 1000;
                Long durationMinutes = seconds / 60;
                leaveEvent.DurationInMinutes = Integer.valueOf(durationMinutes);
                
                insert leaveEvent;
                
                // Update the Beat_Plan__c record
                
                
                return 'Success';
            } else {
                // No record exists, create a new Beat_Plan__c and a related Event
                Beat_Plan__c newBeatPlan = new Beat_Plan__c();
                newBeatPlan.Beat_Date__c = futureDate;
                newBeatPlan.Event_type_Name__c = leaveType;
                newBeatPlan.Assigned_To__c = currentUserId;
                //-------------------Added start by Yogi------------------//
                if (leaveType == 'Compensation off') {
                    newBeatPlan.Compensation_Off_Date__c = holidayDate;
                    System.debug('Set Compensation_Off__c = ' + holidayDate);
                }      
                insert newBeatPlan;
                //-------------------Added End by Yogi------------------//
                
                // Create the Event
                Event leaveEvent = new Event();
                
                
                //Event leaveEvent = new Event();
                leaveEvent.Beat_plan__c = newBeatPlan.Id;
                leaveEvent.Type_of_leave__c = leaveType;
                leaveEvent.Status__c = 'Planned';
                leaveEvent.Stage__c = 'Planned';
                leaveEvent.Event_Locked__c = true;
                leaveEvent.RecordTypeId = Schema.SObjectType.Event
                    .getRecordTypeInfosByName()
                    .get('DCR Planning')
                    .getRecordTypeId();
                leaveEvent.OwnerId = UserInfo.getUserId();
                leaveEvent.Other_Type__c = true;
                leaveEvent.Subject = 'Leave';
                leaveEvent.Description = reason;
                leaveEvent.DCR_Description__c = reason;
                
                // Set start and end times
                Datetime startDT = futureDate;
                Datetime endDT = startDT.addHours(5);
                
                leaveEvent.StartDateTime = startDT;
                leaveEvent.EndDateTime = endDT;
                leaveEvent.Visit_Date__c = startDT.dateGMT();
                leaveEvent.ActivityDateTime = startDT;
                
                // Duration in minutes
                Long milliseconds = endDT.getTime() - startDT.getTime();
                Long seconds = milliseconds / 1000;
                Long durationMinutes = seconds / 60;
                leaveEvent.DurationInMinutes = Integer.valueOf(durationMinutes);
                
                insert leaveEvent;
                
                return 'Success';
            }
        } catch (DmlException e) {
            System.debug('DML Exception: ' + e.getMessage());
            throw new AuraHandledException('An error occurred while applying for leave.');
        } catch (Exception ex) {
            System.debug('Unexpected Exception: ' + ex.getMessage());
            throw new AuraHandledException('An unexpected error occurred.');
        }
    }
    
     public class BeatPlanWrapper {
        @AuraEnabled public List<Beat_Plan__c> beatPlans;
        @AuraEnabled public String managerName;
        @AuraEnabled public String managerId;
        @AuraEnabled public String managerEmail;
    }
    
    @AuraEnabled(cacheable=true)
    public static Loginlogoutlabels__c getCustomLabels() {
        String language=UserInfo.getLanguage();
        Loginlogoutlabels__c leadTranslationLabel=Loginlogoutlabels__c.getValues(language);
        return leadTranslationLabel;
        
    }
      @AuraEnabled(cacheable=true)
    public static BeatPlanWrapper getUpcomingBeatPlans() {
        Id currentUserId = UserInfo.getUserId();
        Date today = Date.today();

        // ✅ Get current user's manager info
        User currentUser = [
            SELECT Id, ManagerId, Manager.Name, Manager.Email
            FROM User
            WHERE Id = :currentUserId
            LIMIT 1
        ];

        // ✅ Get upcoming beat plans
        List<Beat_Plan__c> beatPlans = [
            SELECT Id, Name, Beat_Date__c, Approval_Status__c, CreatedDate, Event_type_Name__c
            FROM Beat_Plan__c
            WHERE Assigned_To__c = :currentUserId
            AND Beat_Date__c >= :today
            AND Approval_Status__c != null
            ORDER BY Beat_Date__c ASC
        ];

        // ✅ Prepare wrapper
        BeatPlanWrapper response = new BeatPlanWrapper();
        response.beatPlans = beatPlans;
        response.managerId = currentUser.ManagerId;
        response.managerName = (currentUser.Manager != null) ? currentUser.Manager.Name : 'No Manager';
        response.managerEmail = (currentUser.Manager != null) ? currentUser.Manager.Email : '';

        return response;
    }
}